class_name W3DSkin
extends W3D
## "Pelle 3D" del gioco vero: la logica, i nemici, le collisioni, i colpi, la vita, le missioni restano quelli del gioco 2D.
## Questo nodo legge lo stato del gioco ogni fotogramma e lo disegna con il motore 3D (muri e pavimenti dal reticolo del dungeon,
## oggetti e personaggi dai loro sprite, piu' i modelli a schegge per eroe e nemici noti).
## 1 unita' 3D = 16 pixel del gioco 2D.

const FLOOR_COL := [Color(0.20, 0.19, 0.20), Color(0.17, 0.19, 0.14), Color(0.14, 0.17, 0.14), Color(0.14, 0.17, 0.15), Color(0.23, 0.22, 0.24), Color(0.40, 0.45, 0.52), Color(0.20, 0.10, 0.09)]
const WALL_COL := [Color(0.20, 0.19, 0.22), Color(0.17, 0.19, 0.15), Color(0.14, 0.17, 0.14), Color(0.14, 0.18, 0.16), Color(0.22, 0.21, 0.25), Color(0.38, 0.42, 0.50), Color(0.22, 0.11, 0.10)]
const KNOWN := ["goblin", "goblin_archer", "skeleton", "skel_archer", "ghoul", "kobold", "orc", "wolf"]
const CAM_H_ROOM := 22.0
const CAM_H_WORLD := 28.0
const CAM_H_WORLD_FAR := 36.0
const TEMPORAL_UFO_HEIGHT := 12.0
const TEMPORAL_FISHEYE := 0.14

var gm                           # Main
var static_root: Node3D
var built_area := ""
var built_grid_id := 0
var dyn: Dictionary = {}         # id istanza -> {node, kind, last}
var tex_mesh: Dictionary = {}
var active := false
var prev_atk := 0.0
var crescent: ArrayMesh
var ring_m: ArrayMesh
var shard_m: ArrayMesh
var shot_t := 0.0
var fx_step := 0
var fx_last := -1
var shot_n := 0
var want_shot := false
var char_mode := 0               # 0 cubetti dall'alto (default), 1 cubetti piatti, 2 modelli stilizzati (F8 cicla)
var exact_chars := true
var killed_test := false
var fwd := false
var hero_light: OmniLight3D
var room_lamps: Array = []
var decor_lights: Array = []
var dust: CPUParticles3D
var side_scroll_prop_changes: Dictionary = {}
var side_scroll_dirty_chunks: Dictionary = {}


func _ready() -> void:
	W3D.add_globals()
	# Ensure w3d_side_cut is initialized to zero to prevent black screen on startup
	RenderingServer.global_shader_parameter_set("w3d_side_cut", Vector4.ZERO)
	# Ensure elevation starts flat (z=0) until _world_init() builds real terrain
	RenderingServer.global_shader_parameter_set("w3d_elev_info", Vector4(0, 0, 0, 0))
	want_shot = OS.get_cmdline_user_args().has("--skinshot")
	ed = W3DEdit.new()
	ed.sk = self
	add_child(ed)
	fut = W3DFuture.new()
	fut.sk = self
	add_child(fut)
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS   # il 3D si vede alla risoluzione reale, non a 480x270
	w.content_scale_size = Vector2i(480, 270)
	res_i = 0
	fade_a = 48.0
	cam_h = CAM_H_ROOM
	_build_view()
	# Position camera at player spawn to avoid black screen (camera starts at 0,0 inside terrain)
	if gm != null and gm.player != null:
		var player_position: Vector2 = gm.player.position
		var p3d: Vector2 = player_position / Game.TS
		cam.position = Vector3(p3d.x, cam_h + 10.0, p3d.y)  # well above ground
	vp.size = Vector2i(960, 540)
	post_mat.set_shader_parameter("px", Vector2(960, 540))
	static_root = Node3D.new()
	vp.add_child(static_root)
	_make_fx_meshes()
	post_rect.visible = false
	sharp_layer = CanvasLayer.new()
	sharp_layer.layer = 128
	var sr := ColorRect.new()
	sr.set_anchors_preset(Control.PRESET_FULL_RECT)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/w3d_sharpen.gdshader")
	sm.set_shader_parameter("amount", 1.35)
	sr.material = sm
	sharp_layer.add_child(sr)
	sharp_layer.visible = false
	add_child(sharp_layer)
	fwd = RenderingServer.get_current_rendering_method() == "forward_plus"
	shadow_disc = not fwd
	if fwd:
		sun.visible = false
		_make_pool()
		env.glow_enabled = false
		env.glow_intensity = 0.8
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.9
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 0.9
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 3.2
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.016
		env.volumetric_fog_albedo = Color(0.7, 0.66, 0.62)
		env.volumetric_fog_emission = Color(0.02, 0.014, 0.012)
		env.volumetric_fog_length = 30.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.08)
	env.fog_density = 0.012
	env.ambient_light_color = Color(0.36, 0.38, 0.52)
	env.ambient_light_energy = 0.62 if not fwd else 0.16
	env.background_color = Color(0.012, 0.01, 0.02)
	dust = CPUParticles3D.new()
	dust.amount = 90
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(15, 3.0, 10)
	dust.direction = Vector3(0.3, 0.1, 0.2)
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.1
	dust.initial_velocity_max = 0.45
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dm.albedo_color = Color(0.9, 0.85, 0.7, 0.35)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.material = dm
	dust.mesh = qm
	vp.add_child(dust)


func _exit_tree() -> void:
	var w := get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	w.content_scale_size = Vector2i(480, 270)
	_show_2d(true)


func _make_fx_meshes() -> void:
	var s := W3DBuilder.new()
	for i in 14:
		var u0 := -1.0 + 2.0 * i / 14.0
		var u1 := -1.0 + 2.0 * (i + 1) / 14.0
		var a0 := u0 * 0.75
		var a1 := u1 * 0.75
		var t0 := 0.34 * (1.0 - u0 * u0)
		var t1 := 0.34 * (1.0 - u1 * u1)
		s.quad(Vector3(sin(a0) * (1.0 - t0), 0.95, -cos(a0) * (1.0 - t0)), Vector3(sin(a0), 0.95, -cos(a0)), Vector3(sin(a1), 0.95, -cos(a1)), Vector3(sin(a1) * (1.0 - t1), 0.95, -cos(a1) * (1.0 - t1)), Color(0.7, 0.8, 1.0, 0.05))
	crescent = s.mesh()
	var r := W3DBuilder.new()
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := TAU * (i + 1) / 24.0
		r.quad(Vector3(cos(a0) * 0.9, 0.06, sin(a0) * 0.9), Vector3(cos(a0), 0.06, sin(a0)), Vector3(cos(a1), 0.06, sin(a1)), Vector3(cos(a1) * 0.9, 0.06, sin(a1) * 0.9), Color(0.95, 0.3, 0.25, 0.1))
	ring_m = r.mesh()
	var sh := W3DBuilder.new()
	sh.shard(Vector3(0, 0, 0.4), Vector3(0, 0, -0.4), 0.13, 0.1, Color(1.0, 0.6, 0.4, 0.05), 0.55, 0.0, 0.0)
	shard_m = sh.mesh()


# ------------------------------------------------------------------ nascondere / mostrare la grafica 2D
func _show_2d(on: bool) -> void:
	if gm == null:
		return
	if gm.ents != null:
		gm.ents.visible = on
	if gm.fx != null:
		gm.fx.visible = on
	if gm.fog_rect != null and on:
		gm.fog_rect.visible = true
	elif gm.fog_rect != null:
		gm.fog_rect.visible = false
	for n in gm.area_nodes:
		if is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = on


# ------------------------------------------------------------------ temi di stanza: ognuna con aspetto, luce e arredo suoi
## 0 cripta (fredda, azzurra) - 1 tesoro (oro caldo) - 2 prigione (ruggine e sangue) - 3 santuario (viola, runico) - 4 magazzino (legno)
const TH_TINT := [Vector3(0.82, 0.95, 1.3), Vector3(1.4, 1.1, 0.62), Vector3(1.2, 0.86, 0.78), Vector3(1.15, 0.8, 1.45), Vector3(1.15, 0.98, 0.78)]
const TH_LIGHT := [Color(0.45, 0.6, 1.0), Color(1.0, 0.72, 0.3), Color(1.0, 0.35, 0.22), Color(0.7, 0.4, 1.0), Color(0.95, 0.7, 0.4)]
var room_theme: Dictionary = {}


func _theme_of(room: Rect2i) -> int:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(room.position.x, room.position.y, int(gm.world_seed)))
	var t := r.randi() % 5
	if room.size.x < 7 or room.size.y < 6:
		t = 4
	return t


func _tint(c: Color, t: Vector3) -> Color:
	return Color(clampf(c.r * t.x, 0.0, 1.0), clampf(c.g * t.y, 0.0, 1.0), clampf(c.b * t.z, 0.0, 1.0), 1.0)


# ------------------------------------------------------------------ geometria statica: muri, pavimenti, dettagli
func _k(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)   # scurisce senza toccare l'alfa (alfa < 1 = emissivo)


func _hash2(x: int, y: int, s := 0) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(s) * 37.719) * 43758.5453, 1.0)


func ci_is_stone(_c: Vector2i) -> bool:
	return false


func _rebuild_static() -> void:
	ed_set_area(str(gm.area))
	ed_apply_props()
	for c in static_root.get_children():
		c.queue_free()
	for k in dyn.keys():
		_drop_dyn(k)
	built_area = gm.area
	built_grid_id = gm.grid.size()
	room_lamps.clear()
	room_theme.clear()
	for ri2 in gm.rooms.size():
		room_theme[ri2] = _theme_of(gm.rooms[ri2])
	var bio := clampi(int(gm.dun.get("bio", 0)) if gm.dun is Dictionary else 0, 0, 6)
	var fc: Color = FLOOR_COL[bio] * (0.8 if fwd else 1.0)
	var wc: Color = WALL_COL[bio] * (0.95 if fwd else 1.0)
	fc.a = 1.0
	wc.a = 1.0
	var fb := W3DBuilder.new()
	var wb := W3DBuilder.new()
	var ob := W3DBuilder.new()      # dettagli piccoli (ossa, macerie, catene)
	fb.rn.seed = 11
	wb.rn.seed = 12
	ob.rn.seed = 13
	wb.sat = 1.3
	wb.con = 1.25
	ob.sat = 1.2
	ob.con = 1.2
	var mw: int = Game.MW
	var mh: int = Game.MH
	var dark := _k(fc, 0.42)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var wood: bool = str(gm.dun.get("type", "")) == "house" if gm.dun is Dictionary else false
	for y in mh:
		for x in mw:
			var c := Vector2i(x, y)
			var hv := _hash2(x, y)
			var hv2 := _hash2(x, y, 5)
			if wood:
				if gm.is_floor(c):
					# pavimento di assi: tre strisce per cella, un po' diverse una dall'altra, con fessure scure
					var big := _hash2(x >> 1, y >> 1, 3)
					var base_wood := Color(0.42, 0.28, 0.16).lerp(Color(0.32, 0.21, 0.12), big)
					if (x + y) % 5 == 0 and ci_is_stone(c):
						base_wood = Color(0.26, 0.25, 0.26)
					for sj in 3:
						var pc := base_wood.lerp(_k(base_wood, 1.35), _hash2(x * 3 + sj, y, 7) * 0.7)
						var z0 := y + sj / 3.0
						fb.quad(Vector3(x, 0.0, z0), Vector3(x + 1, 0.0, z0), Vector3(x + 1, 0.0, z0 + 1.0 / 3.0), Vector3(x, 0.0, z0 + 1.0 / 3.0), _k(base_wood, 0.35))
						fb.quad(Vector3(x, 0.012, z0 + 0.012), Vector3(x + 1, 0.012, z0 + 0.012), Vector3(x + 1, 0.012, z0 + 0.32), Vector3(x, 0.012, z0 + 0.32), fb.shade(pc, 0.05))
				else:
					var near_w := false
					for dy2 in range(-1, 2):
						for dx2 in range(-1, 2):
							if gm.is_floor(Vector2i(x + dx2, y + dy2)):
								near_w = true
					if near_w:
						var wh := 2.7
						var wcol := Color(0.24, 0.15, 0.09).lerp(Color(0.18, 0.11, 0.07), hv)
						wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, wh * 0.5, y + 0.5)), Vector3(1.0, wh, 1.0), wcol, 0.08, 8)
						# travi di legno orizzontali a due altezze lungo le pareti
						for hy in [0.55, 1.5]:
							wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, hy, y + 0.5)), Vector3(1.04, 0.1, 1.04), _k(wcol, 0.68), 0.05, 8)
				continue
			if gm.is_floor(c):
				# fondo scuro (le fughe) e lastra leggermente rialzata, con tono diverso per ogni lastra
				fb.quad(Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1), dark)
				var ci: int = gm.room_of[gm.idx(c)]
				var th: int = room_theme.get(ci, -1)
				var fbase: Color = fc if th < 0 else _tint(fc, TH_TINT[th])
				var col := fbase.lerp(_k(fbase, 1.55), hv * 0.65)
				if hv2 < 0.12:
					col = col.lerp(Color(0.12, 0.2, 0.12), 0.45)      # lastra muschiosa
				if gm.has_carpet(c):
					col = Color(0.36, 0.09, 0.11).lerp(col, 0.18 + hv * 0.15)
				var e := 0.03
				var yy := 0.012 + hv2 * 0.02
				fb.quad(Vector3(x + e, yy, y + e), Vector3(x + 1 - e, yy, y + e), Vector3(x + 1 - e, yy, y + 1 - e), Vector3(x + e, yy, y + 1 - e), fb.shade(col, 0.07))
				# crepe
				if hv < 0.1:
					var a := hv2 * TAU
					ob.box(Transform3D(Basis(Vector3.UP, a), Vector3(x + 0.5, 0.03, y + 0.5)), Vector3(0.9, 0.012, 0.045), Color(0.03, 0.025, 0.03), 0.0, 8)
					ob.box(Transform3D(Basis(Vector3.UP, a + 0.9), Vector3(x + 0.5 + cos(a) * 0.3, 0.03, y + 0.5 + sin(a) * 0.3)), Vector3(0.5, 0.012, 0.04), Color(0.03, 0.025, 0.03), 0.0, 8)
				# pozze d'acqua scura
				elif hv > 0.965:
					fb.quad(Vector3(x + 0.12, 0.03, y + 0.2), Vector3(x + 0.85, 0.03, y + 0.1), Vector3(x + 0.9, 0.03, y + 0.8), Vector3(x + 0.1, 0.03, y + 0.75), Color(0.12, 0.2, 0.3, 0.86))
				# ossa, macerie, teschi sparsi
				elif hv > 0.92:
					ob.box(Transform3D(Basis(Vector3.UP, hv2 * TAU), Vector3(x + 0.3 + hv2 * 0.4, 0.05, y + 0.4)), Vector3(0.5, 0.08, 0.09), Color(0.68, 0.65, 0.55), 0.1, 8)
					if hv2 > 0.5:
						ob.rock(Vector3(x + 0.7, 0.1, y + 0.6), Vector3(0.22, 0.2, 0.22), Color(0.74, 0.7, 0.6), 0.08, 0.2, hv)
				elif hv > 0.86:
					for q in 3:
						ob.rock(Vector3(x + 0.2 + hv2 * 0.6 + q * 0.1, 0.1, y + 0.3 + q * 0.2), Vector3(0.28, 0.2, 0.26), Color(0.30, 0.29, 0.31), 0.14, 0.45, hv * 9.0 + q)
				# macerie addossate ai muri
				var nw := 0
				for d in dirs:
					if not gm.is_floor(c + d) and gm.inb(c + d):
						nw += 1
				if nw > 0 and hv2 > 0.62:
					ob.rock(Vector3(x + 0.5, 0.18, y + 0.5), Vector3(0.7, 0.34, 0.6), Color(0.28, 0.27, 0.29), 0.14, 0.4, hv * 7.0)
				if nw > 0 and hv2 < 0.18:
					ob.rock(Vector3(x + 0.5, 0.1, y + 0.5), Vector3(0.6, 0.18, 0.5), Color(0.12, 0.2, 0.1), 0.18, 0.35, hv * 5.0)   # muschio
			else:
				var near := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if gm.is_floor(Vector2i(x + dx, y + dy)):
							near = true
				if not near:
					continue
				var h := 2.8 + hv * 1.0
				wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, h * 0.5, y + 0.5)), Vector3(1.0, h, 1.0), _k(wc, 0.7), 0.1, 8)
				_wall_faces(wb, ob, x, y, h, wc, c)
				# merlatura rotta sulla cima
				for q in 3:
					if _hash2(x, y, 20 + q) > 0.45:
						wb.box(Transform3D(Basis(Vector3.UP, hv2 * 0.5), Vector3(x + 0.2 + q * 0.3, h + 0.12, y + 0.2 + _hash2(x, y, 30 + q) * 0.6)), Vector3(0.26, 0.28 + _hash2(x, y, 40 + q) * 0.3, 0.3), _k(wc, 1.15), 0.2, 8)
	# luci soffuse: un bagliore freddo al centro di ogni stanza (si somma alle torce calde)
	if gm.rooms is Array:
		for ri4 in gm.rooms.size():
			var r4: Rect2i = gm.rooms[ri4]
			var rc: Vector2 = Vector2(r4.position) + Vector2(r4.size) * 0.5
			room_lamps.append([rc, TH_LIGHT[int(room_theme.get(ri4, 4))]])
	_extras(fb, ob, wb, mw, mh)
	decor_lights.clear()
	reg_static.clear()
	_reg_props()
	if decor_blk != null and is_same(decor_blk, gm.block) and decor_area == str(gm.area) and decor_seed == str(gm.world_seed):
		for dc in decor_cells:
			gm.block.erase(dc)
	decor_cells.clear()
	decor_blk = gm.block
	decor_area = str(gm.area)
	decor_seed = str(gm.world_seed)
	var pb := W3DBuilder.new()
	pb.rn.seed = 14
	pb.sat = 1.75
	pb.con = 1.4
	pb.gain = 1.3
	if gm.rooms is Array and gm.rooms.size() > 0 and not wood:
		_build_decor(pb, decor_lights)
	if wood and gm.rooms is Array:
		# case: una lampada a olio al centro di ogni stanza, luce calda e bassa
		for rw3 in gm.rooms:
			var rc3: Rect2i = rw3
			var cc3 := Vector2(rc3.position) + Vector2(rc3.size) * 0.5
			if not ed_hide_keys.has(Vector2i(roundi(cc3.x * 100.0), roundi(cc3.y * 100.0))):
				reg_static.append(["dec:hlamp", cc3, 0.0, 0, 0])
				_hlamp_make(ob, cc3, decor_lights)
	_ed_apply_static([wb, ob, pb], ob, decor_lights)
	_ed_block_adds()
	for pr in [[fb, false], [wb, true], [ob, true], [pb, true]]:
		var bld: W3DBuilder = pr[0]
		if bld.v.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bld.mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pr[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		static_root.add_child(mi)


# ------------------------------------------------------------------ editor: oggetti-nodo (colonne, statue, tombe, tavoli...) dei dungeon e delle case
const ED_DEC_CAT := [["dec:sarc", "Sarcofago (interno)", true], ["dec:coffin", "Bara decorativa (interno)", true], ["dec:altar", "Altare con luce (interno)", true],
		["dec:statue", "Statua su piedistallo (interno)", true], ["dec:brazier", "Braciere con luce (interno)", true], ["dec:chest", "Scrigno decorativo (interno)", true],
		["dec:barrels", "Barili (interno)", true], ["dec:rack", "Cavalletto (interno)", true], ["dec:cage", "Gabbia appesa (interno)", true],
		["dec:torch", "Torcia a muro con luce (interno)", true], ["dec:beam", "Trave con lanterna (interno)", true], ["dec:candles", "Candele (interno)", true],
		["dec:hlamp", "Lampada a olio (casa)", true], ["dec:w_pillar", "Pilastro a muro (interno)", true], ["dec:w_skulls", "Fila di teschi (interno)", true],
		["dec:w_niche", "Nicchia con teschio (interno)", true], ["dec:w_banner", "Stendardo (interno)", true], ["dec:w_chains", "Catene (interno)", true],
		["dec:w_web", "Ragnatela (interno)", true]]
const ED_PROP_CAT := [["column_top", "Colonna"], ["statue_top", "Statua"], ["tomb", "Tomba"], ["skullpile", "Mucchio di teschi"], ["coffin", "Bara (rompibile)"],
		["barrel_top", "Botte"], ["crate_top", "Cassa"], ["sack_top", "Sacchi"], ["table_top", "Tavolo"], ["chair_top", "Sedia"], ["bed_top", "Letto"],
		["hearth_top", "Camino"], ["cauldron_top", "Calderone"], ["rack_top", "Rastrelliera"], ["shelf_top", "Scaffale"], ["anvil_top", "Incudine"],
		["pew_top", "Panca da chiesa"], ["lamp_top", "Lampione"], ["candelabra", "Candelabro"], ["brazier", "Braciere (prop)"], ["chest", "Scrigno (apribile)"]]
const ED_PROP_1X1 := ["chest", "brazier", "candelabra"]
var ed_made: Array = []        # props creati dall'editor


func ed_prop_names() -> Array:
	var out: Array = []
	for pc in ED_PROP_CAT:
		if ResourceLoader.exists("res://assets/sprites/%s.png" % str(pc[0])):
			out.append(["prop:" + str(pc[0]), str(pc[1]) + " (oggetto)", true])
	return out


func ed_prop_mesh(kind: String) -> ArrayMesh:
	if not W3DProps.ok(kind):
		return null
	var t := Game.tex(kind)
	var tw := float(t.get_width()) / 16.0
	var th := float(t.get_height()) / 16.0
	var m := _base_prop(kind, tw, th, hash(kind))
	if m == null:
		m = W3DProps.build(kind, tw, th, Color(0.45, 0.42, 0.4), hash(kind))
	return m


func _pfp(p: Prop) -> Vector2i:
	if not p.scene or p.spr == null or p.spr.texture == null:
		return Vector2i.ONE
	var t := p.spr.texture
	return Vector2i(maxi(1, ceili((t.get_width() - 4) / 16.0)), maxi(1, ceili((t.get_height() - 4) / 16.0)))


func _pcells(p: Prop, c: Vector2i) -> Array:
	var f := _pfp(p)
	var out: Array = []
	for dy in f.y:
		for dx in f.x:
			out.append(Vector2i(c.x + dx, c.y + dy))
	return out


func _pblock(p: Prop, c: Vector2i, on: bool) -> void:
	for cc in _pcells(p, c):
		if on:
			gm.block[cc] = true
		else:
			gm.block.erase(cc)


func _pset(p: Prop, c: Vector2i) -> void:
	var oc: Vector2i = p.get_meta("ed_c")
	var o: Vector2 = p.get_meta("ed_o")
	p.cell = c
	p.position = o + Vector2(c - oc) * 16.0
	for fe in gm.furn:
		if fe[0] == p:
			fe[1] = _pcells(p, c)


## applica le modifiche agli oggetti-nodo dell'area (spostamenti, nascosti, aggiunti); ritorna quante aggiunte non hanno trovato posto
func ed_apply_props() -> int:
	if world_on or gm.ents == null:
		return 0
	for n in ed_made:
		if is_instance_valid(n):
			var np: Prop = n
			_pblock(np, np.cell, false)
			gm.props.erase(np)
			for fi in range(gm.furn.size() - 1, -1, -1):
				if gm.furn[fi][0] == np:
					gm.furn.remove_at(fi)
			np.queue_free()
	ed_made.clear()
	var all: Array = gm.ents.get_children()
	for n in all:
		if not is_instance_valid(n) or not (n is Prop) or (n as Prop).spr == null or n.is_queued_for_deletion():
			continue
		var p: Prop = n
		if not p.has_meta("ed_o"):
			p.set_meta("ed_o", p.position)
			p.set_meta("ed_c", p.cell)
			p.set_meta("ed_bl", gm.block.has(p.cell))
			p.set_meta("ed_st", 0)
			p.set_meta("ed_ip", gm.props.has(p))
		var st := int(p.get_meta("ed_st"))
		var bl := bool(p.get_meta("ed_bl"))
		var oc: Vector2i = p.get_meta("ed_c")
		var o: Vector2 = p.get_meta("ed_o")
		var want := 0
		var wd := Vector2i.ZERO
		var wyaw := 0.0
		var wsc := 1.0
		for e in ed_props:
			if str(e.get("t", "")) != "add" and str(e.get("k", "")) == p.kind and int(e.get("ox", 0)) == roundi(o.x) and int(e.get("oy", 0)) == roundi(o.y):
				want = 2 if str(e["t"]) == "del" else 1
				wd = Vector2i(int(e.get("dx", 0)), int(e.get("dy", 0)))
				wyaw = float(e.get("yaw", 0.0))
				wsc = float(e.get("sc", 1.0))
		if wyaw != 0.0 or wsc != 1.0:
			p.set_meta("ed_yaw", wyaw)
			p.set_meta("ed_sc", wsc)
		elif p.has_meta("ed_yaw"):
			p.remove_meta("ed_yaw")
			p.remove_meta("ed_sc")
		if want == 0 and st == 0:
			continue
		if bl:
			_pblock(p, p.cell, false)
		p.visible = true
		if bool(p.get_meta("ed_ip")) and not gm.props.has(p):
			gm.props.append(p)
		_pset(p, oc)
		if want == 2:
			p.visible = false
			gm.props.erase(p)
		else:
			_pset(p, oc + wd)
			if bl:
				_pblock(p, p.cell, true)
		p.set_meta("ed_st", want)
	var failed := 0
	for e in ed_props.duplicate():
		if str(e.get("t", "")) != "add":
			continue
		var c := Vector2i(int(e["cx"]), int(e["cy"]))
		var kd := str(e["k"])
		var made: Prop = _ed_spawn_prop(kd, c)
		if made == null:
			failed += 1
			continue
		if float(e.get("yaw", 0.0)) != 0.0 or float(e.get("sc", 1.0)) != 1.0:
			made.set_meta("ed_yaw", float(e.get("yaw", 0.0)))
			made.set_meta("ed_sc", float(e.get("sc", 1.0)))
		made.set_meta("ed_entry", e)
		made.set_meta("ed_o", made.position)
		made.set_meta("ed_c", made.cell)
		made.set_meta("ed_bl", true)
		made.set_meta("ed_st", 0)
		ed_made.append(made)
	_reg_props()
	return failed


## crea un oggetto-nodo dell'editor: l'utente decide dove metterlo, quindi niente vincoli di spazio libero (serve solo che sia pavimento)
func _ed_spawn_prop(kd: String, c: Vector2i) -> Prop:
	if not gm.is_floor(c):
		return null
	if kd in ED_PROP_1X1:
		var had: bool = gm.block.has(c)
		gm.block.erase(c)
		var np: Prop = gm.add_prop(kd, c)
		if np == null and had:
			gm.block[c] = true
		return np
	var f: Vector2i = gm.tex_fp(kd)
	var p := Prop.new()
	p.setup_top(kd, c, f)
	var cells: Array = []
	for dy in f.y:
		for dx in f.x:
			var cc := Vector2i(c.x + dx, c.y + dy)
			gm.block[cc] = true
			cells.append(cc)
	gm.ents.add_child(p)
	if str(gm.area).begins_with("int|"):
		gm.furn.append([p, cells])
	gm.add_fx(p, kd, f, false)
	return p


func ed_entry_ok(e: Dictionary) -> bool:
	for n in ed_made:
		if is_instance_valid(n) and (n as Node).has_meta("ed_entry") and is_same((n as Node).get_meta("ed_entry"), e):
			return true
	return false


## registra i props vivi (visibili) cosi' l'editor li puo' selezionare: [tipo, centro, 0, nodo, raggio]
func _reg_props() -> void:
	for i in range(reg_static.size() - 1, -1, -1):
		if str(reg_static[i][0]).begins_with("prop:"):
			reg_static.remove_at(i)
	if world_on or gm.ents == null:
		return
	for n in gm.ents.get_children():
		if not is_instance_valid(n) or not (n is Prop) or n.is_queued_for_deletion():
			continue
		var p: Prop = n
		if p.kind == "" or p.spr == null or p.spr.texture == null or not p.visible:
			continue
		var f := _pfp(p)
		reg_static.append(["prop:" + p.kind, _sprite_center(p, p.spr) / 16.0, 0.0, p, maxf(1.0, float(maxi(f.x, f.y)) * 0.5 + 0.4)])


func _prop_entry(p: Prop, create: bool) -> Dictionary:
	var o: Vector2 = p.get_meta("ed_o")
	for e in ed_props:
		if str(e.get("t", "")) != "add" and str(e.get("k", "")) == p.kind and int(e.get("ox", 0)) == roundi(o.x) and int(e.get("oy", 0)) == roundi(o.y):
			return e
	if not create:
		return {}
	var ne := {"t": "mv", "k": p.kind, "ox": roundi(o.x), "oy": roundi(o.y), "dx": 0, "dy": 0}
	ed_props.append(ne)
	return ne


func ed_prop_move(p: Prop, d: Vector2i) -> bool:
	if p.has_meta("ed_entry"):
		var e: Dictionary = p.get_meta("ed_entry")
		var ox := int(e["cx"])
		var oy := int(e["cy"])
		e["cx"] = ox + d.x
		e["cy"] = oy + d.y
		ed_apply_props()
		if not ed_entry_ok(e):          # posto non valido: l'oggetto torna dov'era
			e["cx"] = ox
			e["cy"] = oy
			ed_apply_props()
			return false
		return true
	var e2 := _prop_entry(p, true)
	e2["t"] = "mv"
	e2["dx"] = int(e2.get("dx", 0)) + d.x
	e2["dy"] = int(e2.get("dy", 0)) + d.y
	ed_apply_props()
	return true


func ed_prop_turn(p: Prop, d_yaw: float, factor: float) -> Dictionary:
	var e: Dictionary
	if p.has_meta("ed_entry"):
		e = p.get_meta("ed_entry")
	else:
		e = _prop_entry(p, true)
	e["yaw"] = fposmod(float(e.get("yaw", 0.0)) + d_yaw, TAU)
	e["sc"] = clampf(float(e.get("sc", 1.0)) * factor, 0.3, 4.0)
	ed_apply_props()
	return e


func ed_prop_delete(p: Prop) -> void:
	if p.has_meta("ed_entry"):
		ed_props.erase(p.get_meta("ed_entry"))
	else:
		var e := _prop_entry(p, true)
		e["t"] = "del"
	ed_apply_props()


## elementi d'atmosfera: torce con fiamma, travi con lanterne sui corridoi, cerchi runici, candele
func _extras(fb: W3DBuilder, ob: W3DBuilder, wb: W3DBuilder, mw: int, mh: int) -> void:
	# torce: staffa di ferro, fiamma emissiva a schegge, anello di bagliore
	for f in gm.flick:
		var l = f[0]
		if not is_instance_valid(l) or not (l as CanvasItem).is_visible_in_tree():
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
		if ed_hide_keys.has(Vector2i(roundi(gp.x * 100.0), roundi(gp.y * 100.0))):
			continue
		reg_static.append(["dec:torch", gp, 0.0, 0, 0])
		_torch_make(ob, gp)
	# travi di legno sopra i corridoi stretti, con anelli e lanterne appese
	for y in range(1, mh - 1):
		for x in range(1, mw - 1):
			var c := Vector2i(x, y)
			if not gm.is_floor(c):
				continue
			var wl: bool = not gm.is_floor(Vector2i(x - 1, y))
			var wr: bool = not gm.is_floor(Vector2i(x + 1, y))
			var wu: bool = not gm.is_floor(Vector2i(x, y - 1))
			var wd: bool = not gm.is_floor(Vector2i(x, y + 1))
			var bkey := Vector2i(roundi((x + 0.5) * 100.0), roundi((y + 0.5) * 100.0))
			if wl and wr and (y % 5 == 0):
				if not ed_hide_keys.has(bkey):
					var lant := 1 if _hash2(x, y, 90) < 0.5 else 0
					reg_static.append(["dec:beam", Vector2(x + 0.5, y + 0.5), 0.0, lant, 0])
					_beam_make(wb, ob, Vector2(x + 0.5, y + 0.5), 0.0, lant == 1)
			elif wu and wd and (x % 5 == 0):
				if not ed_hide_keys.has(bkey):
					reg_static.append(["dec:beam", Vector2(x + 0.5, y + 0.5), PI * 0.5, 0, 0])
					_beam_make(wb, ob, Vector2(x + 0.5, y + 0.5), PI * 0.5, false)
	# cerchi runici luminosi al centro delle stanze grandi
	if gm.rooms is Array:
		for ri3 in gm.rooms.size():
			var r: Rect2i = gm.rooms[ri3]
			if r.size.x < 9 or r.size.y < 7 or int(room_theme.get(ri3, 4)) != 3:
				continue
			var cc := Vector2(r.position) + Vector2(r.size) * 0.5
			var rad := minf(3.0, minf(r.size.x, r.size.y) * 0.33)
			var col := Color(0.42, 0.22, 1.0, 0.5)
			for i in 28:
				var a0 := TAU * i / 28.0
				var a1 := TAU * (i + 0.7) / 28.0
				fb.quad(Vector3(cc.x + cos(a0) * rad, 0.034, cc.y + sin(a0) * rad), Vector3(cc.x + cos(a0) * (rad - 0.12), 0.034, cc.y + sin(a0) * (rad - 0.12)), Vector3(cc.x + cos(a1) * (rad - 0.12), 0.034, cc.y + sin(a1) * (rad - 0.12)), Vector3(cc.x + cos(a1) * rad, 0.034, cc.y + sin(a1) * rad), col)
			for i in 5:
				var a2 := TAU * i / 5.0 + 0.3
				var a3 := a2 + TAU * 2.0 / 5.0
				var p0 := Vector3(cc.x + cos(a2) * (rad - 0.2), 0.034, cc.y + sin(a2) * (rad - 0.2))
				var p1 := Vector3(cc.x + cos(a3) * (rad - 0.2), 0.034, cc.y + sin(a3) * (rad - 0.2))
				ob.box(Transform3D(Basis(Vector3.UP, -atan2(p1.z - p0.z, p1.x - p0.x)), (p0 + p1) * 0.5 + Vector3(0, 0.02, 0)), Vector3(p0.distance_to(p1), 0.012, 0.07), col, 0.0, 8)
	# candele sparse sul pavimento vicino ai muri
	for y in range(1, mh - 1):
		for x in range(1, mw - 1):
			if gm.is_floor(Vector2i(x, y)) and _hash2(x, y, 55) > 0.985:
				if not ed_hide_keys.has(Vector2i(roundi((x + 0.5) * 100.0), roundi((y + 0.5) * 100.0))):
					reg_static.append(["dec:candles", Vector2(x + 0.5, y + 0.5), 0.0, 0, 0])
					_candles_make(ob, Vector2(x + 0.5, y + 0.5))


# ------------------------------------------------------------------ arredi del dungeon (modelli poligonali)
const WOOD_D := Color(0.24, 0.15, 0.09)
const IRON := Color(0.17, 0.17, 0.19)
const GOLD := Color(0.78, 0.6, 0.2)
const BONE := Color(0.78, 0.74, 0.64)
const CLOTH_R := Color(0.38, 0.06, 0.09)


var dscale := 1.0


func _tr(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * dscale), p)


func _m_chest(b: W3DBuilder, p: Vector3, yaw: float, open: bool) -> void:
	var t := _tr(p, yaw)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Vector3(0.92, 0.56, 0.64), WOOD_D, 0.14, 8)
	b.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(0.46, 0.56, 0)), 0.32, 0.32, 0.92, 8, Color(0.3, 0.19, 0.11), 0.14)
	for x in [-0.3, 0.0, 0.3]:
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(x, 0.4, 0)), Vector3(0.07, 0.8, 0.7), IRON, 0.1, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.5, 0.34)), Vector3(0.14, 0.18, 0.05), GOLD, 0.1, 8)
	for sx in [-0.4, 0.4]:
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(sx, 0.05, 0.3)), Vector3(0.12, 0.1, 0.12), IRON, 0.1, 8)
	if open:
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.62, 0)), Vector3(0.7, 0.04, 0.4), Color(0.9, 0.7, 0.2, 0.2), 0.0, 8)


func _m_sarcophagus(b: W3DBuilder, p: Vector3, yaw: float, broken: bool) -> void:
	var t := _tr(p, yaw)
	var st := Color(0.34, 0.33, 0.35)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), Vector3(2.0, 0.5, 0.92), _k(st, 0.85), 0.16, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0)), Vector3(2.2, 0.14, 1.05), _k(st, 0.65), 0.12, 8)
	var off := Vector3(0.45, 0, 0.1) if broken else Vector3.ZERO
	var rot := Basis(Vector3.UP, 0.18 if broken else 0.0)
	b.box(t * Transform3D(rot, Vector3(0, 0.61, 0) + off), Vector3(2.05, 0.22, 1.0), st, 0.16, 8)
	b.box(t * Transform3D(rot, Vector3(0, 0.78, 0) + off), Vector3(1.8, 0.14, 0.56), _k(st, 1.12), 0.16, 8)
	b.rock(t * Vector3(-0.78, 0.88, 0) + off, Vector3(0.42, 0.28, 0.4), _k(st, 1.1), 0.14, 0.2, 0.0)
	b.box(t * Transform3D(rot, Vector3(0.1, 0.87, 0) + off), Vector3(0.1, 0.05, 0.5), _k(st, 0.6), 0.1, 8)
	b.box(t * Transform3D(rot, Vector3(0.1, 0.87, 0) + off), Vector3(0.7, 0.05, 0.09), _k(st, 0.6), 0.1, 8)
	if broken:
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(-0.6, 0.52, 0)), Vector3(0.7, 0.02, 0.6), Color(0.01, 0.01, 0.015), 0.0, 8)
		b.box(t * Transform3D(Basis(Vector3.UP, 0.6), Vector3(-0.55, 0.56, 0.1)), Vector3(0.45, 0.07, 0.09), BONE, 0.1, 8)


func _m_coffin(b: W3DBuilder, p: Vector3, yaw: float, ajar: bool) -> void:
	var t := _tr(p, yaw)
	var wd := WOOD_D
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.1, 0.2, 0)), Vector3(1.5, 0.4, 0.58), wd, 0.14, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(-0.72, 0.2, 0)), Vector3(0.52, 0.4, 0.78), _k(wd, 1.05), 0.14, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.98, 0.2, 0)), Vector3(0.34, 0.4, 0.4), _k(wd, 0.95), 0.14, 8)
	var rot := Basis(Vector3.UP, 0.22) if ajar else Basis.IDENTITY
	var off := Vector3(0.0, 0.0, 0.2) if ajar else Vector3.ZERO
	b.box(t * Transform3D(rot, Vector3(0.1, 0.43, 0) + off), Vector3(1.55, 0.07, 0.6), _k(wd, 1.2), 0.14, 8)
	b.box(t * Transform3D(rot, Vector3(-0.72, 0.43, 0) + off), Vector3(0.55, 0.07, 0.8), _k(wd, 1.15), 0.14, 8)
	b.box(t * Transform3D(rot, Vector3(-0.1, 0.48, 0) + off), Vector3(0.7, 0.04, 0.07), Color(0.4, 0.34, 0.28), 0.1, 8)
	b.box(t * Transform3D(rot, Vector3(0.0, 0.48, 0) + off), Vector3(0.07, 0.04, 0.35), Color(0.4, 0.34, 0.28), 0.1, 8)
	if ajar:
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.3, 0.3, -0.34)), Vector3(0.3, 0.05, 0.08), BONE, 0.1, 8)
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.5, 0.3, -0.38)), Vector3(0.06, 0.05, 0.2), BONE, 0.1, 8)


func _m_altar(b: W3DBuilder, p: Vector3, yaw: float, lamps: Array) -> void:
	var t := _tr(p, yaw)
	var st := Color(0.30, 0.28, 0.31)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)), Vector3(2.4, 0.18, 1.5), _k(st, 0.8), 0.14, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0)), Vector3(2.1, 0.18, 1.2), _k(st, 0.9), 0.14, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0)), Vector3(1.8, 0.6, 0.8), st, 0.16, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.99, 0)), Vector3(1.95, 0.08, 0.92), _k(st, 1.15), 0.14, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.04, 0)), Vector3(1.3, 0.03, 0.8), CLOTH_R, 0.1, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.01, 0.46)), Vector3(1.3, 0.3, 0.03), _k(CLOTH_R, 0.85), 0.1, 8)
	b.rock(t * Vector3(0.1, 1.2, 0), Vector3(0.3, 0.26, 0.28), BONE, 0.08, 0.2, 0.0)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(-0.5, 1.06, 0.05)), 0.09, 0.06, 0.2, 6, GOLD, 0.1)
	for cx in [-0.8, 0.75, 0.5]:
		b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(cx, 1.06, -0.2)), 0.045, 0.04, 0.22, 5, Color(0.82, 0.78, 0.66), 0.1)
		b.shard(t * Vector3(cx, 1.3, -0.2), t * Vector3(cx, 1.5, -0.2), 0.045, 0.035, Color(1.0, 0.75, 0.35, 0.0), 0.4, 0.0, 0.0)
	var lp: Vector3 = t * Vector3(0, 1.6, 0)
	lamps.append(lp)
	for q in 5:
		var a := TAU * q / 5.0
		b.box(t * Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 1.5, 0.02, sin(a) * 1.15)), Vector3(0.5, 0.012, 0.06), Color(0.42, 0.2, 1.0, 0.55), 0.0, 8)


func _m_brazier(b: W3DBuilder, p: Vector3, lamps: Array) -> void:
	var t := _tr(p, 0.0)
	for q in 3:
		var a := TAU * q / 3.0
		b.box(t * Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3(0, 0, 1), 0.28), Vector3(cos(a) * 0.2, 0.42, sin(a) * 0.2)), Vector3(0.06, 0.9, 0.06), IRON, 0.1, 8)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0)), 0.3, 0.44, 0.26, 8, Color(0.22, 0.2, 0.2), 0.12)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), 0.34, 0.2, 0.06, 8, Color(1.0, 0.4, 0.12, 0.5), 0.2)
	b.shard(t * Vector3(0, 1.0, 0), t * Vector3(0, 1.7, 0), 0.2, 0.17, Color(1.0, 0.45, 0.12, 0.45), 0.4, 0.0, 0.1)
	b.shard(t * Vector3(0.05, 1.05, 0), t * Vector3(0.05, 1.45, 0), 0.09, 0.07, Color(1.0, 0.8, 0.4, 0.3), 0.4, 0.0, 0.1)
	lamps.append(t * Vector3(0, 1.9, 0))


func _m_statue(b: W3DBuilder, p: Vector3, yaw: float) -> void:
	var t := _tr(p, yaw)
	var st := Color(0.33, 0.33, 0.36)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), Vector3(0.95, 0.44, 0.95), _k(st, 0.8), 0.14, 8)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.44, 0)), 0.36, 0.2, 1.15, 6, st, 0.16)
	b.rock(t * Vector3(0, 1.75, 0), Vector3(0.36, 0.4, 0.36), _k(st, 1.1), 0.14, 0.2, 0.0)
	b.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), 0.5), Vector3(0.18, 1.5, 0)), 0.08, 0.06, 0.55, 5, _k(st, 0.9), 0.14)
	b.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), -0.5), Vector3(-0.18, 1.5, 0)), 0.08, 0.06, 0.55, 5, _k(st, 0.9), 0.14)
	b.box(t * Transform3D(Basis(Vector3.RIGHT, 0.4), Vector3(0, 1.72, -0.2)), Vector3(0.5, 0.2, 0.12), _k(st, 0.7), 0.14, 8)


func _m_barrels(b: W3DBuilder, p: Vector3, yaw: float, r: RandomNumberGenerator) -> void:
	var t := _tr(p, yaw)
	for q in 3:
		var o := Vector3(-0.25 + q * 0.27, 0, r.randf_range(-0.2, 0.2))
		b.cyl(t * Transform3D(Basis.IDENTITY, o), 0.26, 0.26, 0.78, 7, _k(WOOD_D, 1.1), 0.14)
		b.cyl(t * Transform3D(Basis.IDENTITY, o + Vector3(0, 0.2, 0)), 0.275, 0.275, 0.05, 7, IRON, 0.05, false)
		b.cyl(t * Transform3D(Basis.IDENTITY, o + Vector3(0, 0.55, 0)), 0.275, 0.275, 0.05, 7, IRON, 0.05, false)
	b.box(t * Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.0, 0.2, 0.42)), Vector3(0.55, 0.4, 0.5), WOOD_D, 0.14, 8)
	b.box(t * Transform3D(Basis(Vector3.UP, 0.1), Vector3(0.05, 0.6, 0.4)), Vector3(0.4, 0.34, 0.4), _k(WOOD_D, 1.1), 0.14, 8)


func _m_rack(b: W3DBuilder, p: Vector3, yaw: float) -> void:
	# cavalletto di tortura / rastrelliera di legno con ferri
	var t := _tr(p, yaw)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(1.9, 0.12, 0.7), WOOD_D, 0.14, 8)
	for sx in [-0.9, 0.9]:
		for sz in [-0.3, 0.3]:
			b.box(t * Transform3D(Basis.IDENTITY, Vector3(sx, 0.22, sz)), Vector3(0.12, 0.44, 0.12), _k(WOOD_D, 0.85), 0.12, 8)
	b.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(1.05, 0.65, 0)), 0.1, 0.1, 0.2, 6, _k(WOOD_D, 1.2), 0.12)
	b.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.85, 0.65, 0)), 0.1, 0.1, 0.2, 6, _k(WOOD_D, 1.2), 0.12)
	for sx in [-0.5, 0.2]:
		b.box(t * Transform3D(Basis(Vector3.UP, 0.3), Vector3(sx, 0.55, 0.0)), Vector3(0.5, 0.08, 0.1), IRON, 0.1, 8)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0.45, 0.53, 0.0)), Vector3(0.55, 0.05, 0.12), BONE, 0.1, 8)


func _m_cage(b: W3DBuilder, p: Vector3, lamps: Array) -> void:
	# gabbia sospesa con scheletro, appesa a una catena (sopra la testa: nessuna collisione)
	var t := _tr(p, 0.0)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 0)), Vector3(0.04, 1.6, 0.04), IRON, 0.1, 8)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 2.2, 0)), 0.5, 0.5, 0.06, 8, IRON, 0.1)
	b.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0)), 0.5, 0.5, 0.06, 8, IRON, 0.1)
	for q in 8:
		var a := TAU * q / 8.0
		b.box(t * Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.48, 1.65, sin(a) * 0.48)), Vector3(0.04, 1.1, 0.04), IRON, 0.1, 8)
	b.rock(t * Vector3(0, 1.3, 0), Vector3(0.28, 0.26, 0.28), BONE, 0.08, 0.2, 0.0)
	b.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.18, 0)), Vector3(0.22, 0.2, 0.12), _k(BONE, 0.9), 0.1, 8)


var decor_cells: Array = []     # celle bloccate dagli arredi generati (si ricalcolano a ogni ricostruzione, cosi' spostare o togliere un arredo libera il passaggio)
var decor_area := ""
var decor_seed := ""
var decor_blk = null
const DEC_HALF := {"sarc": Vector2(1.5, 1.0), "coffin": Vector2(1.5, 0.5), "altar": Vector2(2.0, 1.5), "rack": Vector2(1.5, 0.5), "chest": Vector2(1.0, 0.5),
		"barrels": Vector2(0.5, 1.0), "statue": Vector2(0.5, 0.5), "brazier": Vector2(0.5, 0.5)}


func _ed_erased(c0: Vector2i, fw: int, fh: int) -> bool:
	for e in ed_erase:
		var ep := Vector2(float(e[0]), float(e[1]))
		for dy in fh:
			for dx in fw:
				if Vector2(c0.x + dx + 0.5, c0.y + dy + 0.5).distance_to(ep) < float(e[2]):
					return true
	return false


## gli arredi piazzati dall'editor bloccano il passaggio come quelli generati
func _ed_block_adds() -> void:
	for a in ed_adds:
		var kk := str(a["k"])
		if not kk.begins_with("dec:") or not DEC_HALF.has(kk.substr(4)):
			continue
		var h: Vector2 = DEC_HALF[kk.substr(4)] * float(a.get("sc", 1.0))
		if absf(sin(float(a["yaw"]))) > 0.7:
			h = Vector2(h.y, h.x)
		var px := float(a["x"])
		var pz := float(a["z"])
		for cy in range(floori(pz - h.y + 0.01), ceili(pz + h.y - 0.01)):
			for cx in range(floori(px - h.x + 0.01), ceili(px + h.x - 0.01)):
				gm.block[Vector2i(cx, cy)] = true
				decor_cells.append(Vector2i(cx, cy))


const DEC_SC := {"sarc": 1.5, "coffin": 1.5, "rack": 1.5, "altar": 1.5, "chest": 1.4, "barrels": 1.3, "brazier": 1.3, "statue": 1.35, "cage": 1.3}
var reg_static: Array = []      # arredi generati dell'interno: [tipo, posizione, rotazione, stato rng, 0]; l'editor li rende selezionabili


## costruisce un arredo dell'interno; i numeri casuali si consumano sempre nello stesso ordine
func _decor_make(item: String, b: W3DBuilder, p: Vector3, yaw: float, lamps: Array, r: RandomNumberGenerator, sc: float) -> void:
	var old_sz := b.sz
	dscale = sc
	b.sz = sc
	match item:
		"sarc":
			_m_sarcophagus(b, p, yaw, r.randf() < 0.35)
		"coffin":
			_m_coffin(b, p, yaw, r.randf() < 0.5)
		"altar":
			_m_altar(b, p, yaw, lamps)
		"statue":
			_m_statue(b, p, yaw + r.randf_range(-0.25, 0.25))
		"brazier":
			_m_brazier(b, p, lamps)
		"chest":
			_m_chest(b, p, r.randf_range(-0.08, 0.08) + yaw, r.randf() < 0.2)
		"barrels":
			_m_barrels(b, p, yaw + r.randf_range(-0.4, 0.4), r)
		"rack":
			_m_rack(b, p, yaw)
		"cage":
			_m_cage(b, p, lamps)
	dscale = 1.0
	b.sz = old_sz


func _torch_make(ob: W3DBuilder, gp: Vector2) -> void:
	ob.box(Transform3D(Basis.IDENTITY, Vector3(gp.x, 1.2, gp.y)), Vector3(0.1, 0.9, 0.1), Color(0.18, 0.15, 0.13), 0.1, 8)
	ob.cyl(Transform3D(Basis.IDENTITY, Vector3(gp.x, 1.62, gp.y)), 0.13, 0.17, 0.2, 6, Color(0.2, 0.17, 0.15), 0.1)
	ob.shard(Vector3(gp.x, 1.7, gp.y), Vector3(gp.x, 2.45, gp.y), 0.17, 0.15, Color(1.0, 0.55, 0.18, 0.08), 0.35, 0.0, 0.1)
	ob.shard(Vector3(gp.x, 1.75, gp.y), Vector3(gp.x + 0.02, 2.2, gp.y), 0.09, 0.08, Color(1.0, 0.9, 0.55, 0.0), 0.4, 0.0, 0.1)


func _beam_make(wb: W3DBuilder, ob: W3DBuilder, p: Vector2, yaw: float, lantern: bool) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y))
	wb.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 3.15, 0)), Vector3(1.9, 0.3, 0.3), Color(0.20, 0.13, 0.09), 0.14, 8)
	wb.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 3.05, 0)), Vector3(0.3, 0.12, 0.5), Color(0.15, 0.1, 0.07), 0.1, 8)
	if lantern:
		ob.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 2.65, 0)), Vector3(0.04, 0.8, 0.04), Color(0.2, 0.2, 0.22), 0.1, 8)
		ob.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 2.15, 0)), Vector3(0.26, 0.34, 0.26), Color(1.0, 0.72, 0.4, 0.22), 0.0, 8)


func _candles_make(ob: W3DBuilder, p: Vector2) -> void:
	var x := floori(p.x)
	var y := floori(p.y)
	for q in 3:
		var ox := p.x - x - 0.5 + 0.3 + _hash2(x, y, 60 + q) * 0.4
		var oz := p.y - y - 0.5 + 0.3 + _hash2(x, y, 70 + q) * 0.4
		ob.cyl(Transform3D(Basis.IDENTITY, Vector3(x + ox, 0.0, y + oz)), 0.05, 0.045, 0.16 + q * 0.04, 5, Color(0.8, 0.76, 0.65), 0.1)
		ob.shard(Vector3(x + ox, 0.2 + q * 0.04, y + oz), Vector3(x + ox, 0.34 + q * 0.04, y + oz), 0.04, 0.03, Color(1.0, 0.8, 0.4, 0.0), 0.4, 0.0, 0.0)


func _hlamp_make(ob: W3DBuilder, c: Vector2, lamps: Array) -> void:
	lamps.append(Vector3(c.x, 1.7, c.y))
	ob.cyl(Transform3D(Basis.IDENTITY, Vector3(c.x, 0.0, c.y)), 0.18, 0.12, 0.5, 6, Color(0.2, 0.12, 0.07), 0.08)
	ob.box(Transform3D(Basis.IDENTITY, Vector3(c.x, 0.62, c.y)), Vector3(0.16, 0.2, 0.16), Color(1.0, 0.75, 0.4, 0.15), 0.0, 8)


func _wall_col() -> Color:
	var bio := clampi(int(gm.dun.get("bio", 0)) if gm.dun is Dictionary else 0, 0, 6)
	return WALL_COL[bio] * (0.95 if fwd else 1.0)


## hook dell'editor: arredo dell'interno piazzato o spostato
func _ed_decor(item: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, sc: float, lamps: Array) -> void:
	match item:
		"torch":
			_torch_make(o, p)
			lamps.append(Vector3(p.x, 1.9, p.y))
			return
		"beam":
			_beam_make(o, o, p, yaw, r.state % 2 == 1)
			return
		"candles":
			_candles_make(o, p)
			return
		"hlamp":
			_hlamp_make(o, p, lamps)
			return
		"w_pillar", "w_skulls", "w_niche", "w_banner", "w_chains", "w_web":
			var hv := float(r.state / 2) / 100.0
			if hv < 2.0 or hv > 4.0:
				hv = 3.0
			_wall_deco(item, o, o, Vector3(p.x, 0.0, p.y), yaw, hv, int(r.state % 2), _wall_col())
			return
	_decor_make(item, o, Vector3(p.x, 0.0, p.y), yaw, lamps, r, float(DEC_SC.get(item, 1.4)) * sc)


const DEC_FACE := {"N": 0.0, "S": PI, "W": PI * 0.5, "E": -PI * 0.5}      # rotazione che rivolge l'oggetto verso la stanza


## ingombro (in celle) di un arredo addossato a un muro: la lunghezza corre lungo il muro
func _dec_dims(item: String, side: String) -> Vector2i:
	var horiz := side == "N" or side == "S"
	var d := Vector2i(1, 1)
	match item:
		"sarc":
			d = Vector2i(3, 2)
		"coffin", "rack":
			d = Vector2i(3, 1)
		"altar":
			d = Vector2i(4, 3)
		"chest", "barrels":
			d = Vector2i(2, 1)
	return d if horiz else Vector2i(d.y, d.x)


## spazio libero per un arredo contro un muro: pavimento, niente altro sopra, e mai davanti a una porta o a un corridoio
func _dec_free(room: Rect2i, cx: int, cy: int, fw: int, fh: int, occ: Dictionary) -> bool:
	for dy in fh:
		for dx in fw:
			var c := Vector2i(cx + dx, cy + dy)
			if occ.has(c) or gm.block.has(c) or gm.reserved.has(c) or not gm.is_floor(c) or gm.has_carpet(c):
				return false
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + dv
				if gm.is_floor(n) and not room.has_point(n):
					return false      # apertura verso un altro locale
	if Vector2(cx + fw * 0.5, cy + fh * 0.5).distance_to(gm.player.position / 16.0) < 3.0:
		return false
	return true


## posto contro il muro `side`, a `frac` (0..1) della lunghezza; se occupato prova poco piu' in la
func _wall_spot(room: Rect2i, item: String, side: String, frac: float, occ: Dictionary) -> Dictionary:
	var d := _dec_dims(item, side)
	var horiz := side == "N" or side == "S"
	var span := (room.size.x - d.x) if horiz else (room.size.y - d.y)
	if span < 0:
		return {}
	var base := roundi(frac * span)
	for sh in [0, 1, -1, 2, -2, 3, -3]:
		var a := clampi(base + sh, 0, span)
		var cx := room.position.x + a if horiz else (room.position.x if side == "W" else room.end.x - d.x)
		var cy := (room.position.y if side == "N" else room.end.y - d.y) if horiz else room.position.y + a
		if _dec_free(room, cx, cy, d.x, d.y, occ):
			for dy in d.y:
				for dx in d.x:
					occ[Vector2i(cx + dx, cy + dy)] = true
					gm.block[Vector2i(cx + dx, cy + dy)] = true
					decor_cells.append(Vector2i(cx + dx, cy + dy))
			return {"x": cx, "y": cy, "w": d.x, "h": d.y}
	return {}


## piano di una stanza: [arredo, muro, posizione lungo il muro]; coppie e file simmetriche
func _decor_plan(theme: int, room: Rect2i) -> Array:
	var tall := room.size.y >= 9
	var wide := room.size.x >= 9
	match theme:
		0:   # cripta: sarcofagi in fila lungo i lati, statua in fondo fra due bracieri
			var p0: Array = [["statue", "N", 0.5], ["brazier", "N", 0.12], ["brazier", "N", 0.88], ["sarc", "W", 0.2 if tall else 0.5], ["sarc", "E", 0.2 if tall else 0.5]]
			if tall:
				p0.append(["sarc", "W", 0.8])
				p0.append(["sarc", "E", 0.8])
			return p0
		1:   # tesoro: scrigni in fila contro il muro, bracieri ai lati
			return [["chest", "N", 0.3], ["chest", "N", 0.5], ["chest", "N", 0.7], ["brazier", "N", 0.0], ["brazier", "N", 1.0]]
		2:   # prigione: cavalletti lungo i lati, barili in un angolo
			var p2: Array = [["rack", "W", 0.25], ["rack", "E", 0.25], ["barrels", "S", 1.0]]
			if tall:
				p2.append(["rack", "W", 0.8])
				p2.append(["rack", "E", 0.8])
			return p2
		3:   # santuario: altare in fondo, due bracieri ai lati, due statue davanti
			var p3: Array = [["altar", "N", 0.5], ["brazier", "N", 0.0], ["brazier", "N", 1.0]]
			if wide:
				p3.append(["statue", "S", 0.1])
				p3.append(["statue", "S", 0.9])
			return p3
		_:   # magazzino: barili e casse raggruppati negli angoli
			return [["barrels", "N", 0.0], ["barrels", "S", 1.0], ["chest", "E", 0.5], ["barrels", "N", 1.0]]


## un punto a pochi passi da un muro: il disordine (ossa, paglia, macchie) sta lungo i muri, non in mezzo alla stanza
func _edge_point(room: Rect2i, r: RandomNumberGenerator, depth: float) -> Vector3:
	var side := r.randi() % 4
	var t := r.randf()
	match side:
		0:
			return Vector3(room.position.x + 0.8 + t * (room.size.x - 1.6), 0, room.position.y + depth)
		1:
			return Vector3(room.position.x + 0.8 + t * (room.size.x - 1.6), 0, room.end.y - depth)
		2:
			return Vector3(room.position.x + depth, 0, room.position.y + 0.8 + t * (room.size.y - 1.6))
	return Vector3(room.end.x - depth, 0, room.position.y + 0.8 + t * (room.size.y - 1.6))


func _build_decor(b: W3DBuilder, lamps: Array) -> void:
	var occ: Dictionary = {}
	for room in gm.rooms:
		var r := RandomNumberGenerator.new()
		r.seed = hash(Vector3i(room.position.x, room.position.y, int(gm.world_seed)))
		var theme := _theme_of(room)
		for entry in _decor_plan(theme, room):
			var item := str(entry[0])
			var side := str(entry[1])
			var sc := float(DEC_SC.get(item, 1.4))
			var spot := _wall_spot(room, item, side, float(entry[2]), occ)
			if spot.is_empty():
				continue
			var fw: int = spot["w"]
			var fh: int = spot["h"]
			var cx: float = float(spot["x"]) + fw * 0.5
			var cz: float = float(spot["y"]) + fh * 0.5
			var base_yaw: float = DEC_FACE[side] if item != "brazier" else 0.0
			var pv := Vector2(cx, cz)
			var st := r.state
			if ed_hide_keys.has(Vector2i(roundi(cx * 100.0), roundi(cz * 100.0))) or _ed_erased(Vector2i(int(spot["x"]), int(spot["y"])), fw, fh):
				# nascosto o spostato dall'editor: si genera in un contenitore di scarto (i numeri casuali avanzano uguale) e si libera lo spazio
				var tmp := W3DBuilder.new()
				_decor_make(item, tmp, Vector3(cx, 0, cz), base_yaw, [], r, sc)
				for dy3 in fh:
					for dx3 in fw:
						gm.block.erase(Vector2i(int(spot["x"]) + dx3, int(spot["y"]) + dy3))
			else:
				reg_static.append(["dec:" + item, pv, base_yaw, st, 0])
				_decor_make(item, b, Vector3(cx, 0, cz), base_yaw, lamps, r, sc)
		# gabbie appese in fila lungo il muro nord
		if theme == 2:
			for q in 2:
				var cx2: float = room.position.x + room.size.x * (0.3 + 0.4 * q)
				var cz2: float = room.position.y + 1.6
				if ed_hide_keys.has(Vector2i(roundi(cx2 * 100.0), roundi(cz2 * 100.0))):
					continue
				reg_static.append(["dec:cage", Vector2(cx2, cz2), 0.0, r.state, 0])
				_decor_make("cage", b, Vector3(cx2, 0, cz2), 0.0, lamps, r, 1.3)
		dscale = 1.0
		b.sz = 1.3
		if theme == 2:
			for q in 4:
				var bp := _edge_point(room, r, 1.5)
				var rs := r.randf_range(0.5, 0.9)
				b.quad(Vector3(bp.x - rs, 0.026, bp.z - rs * 0.7), Vector3(bp.x + rs, 0.026, bp.z - rs * 0.5), Vector3(bp.x + rs * 0.8, 0.026, bp.z + rs), Vector3(bp.x - rs, 0.026, bp.z + rs * 0.6), Color(0.28, 0.03, 0.04))
		elif theme == 1:
			for q in 14:
				var cp := _edge_point(room, r, 1.7)
				b.box(Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(cp.x, 0.04, cp.z)), Vector3(0.14, 0.03, 0.14), Color(1.0, 0.78, 0.25, 0.3), 0.0, 8)
		elif theme == 4:
			for q in 6:
				var sp2 := _edge_point(room, r, 1.2)
				b.box(Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(sp2.x, 0.03, sp2.z)), Vector3(0.9, 0.04, 0.12), Color(0.42, 0.34, 0.15), 0.18, 8)
		for q in r.randi_range(0, 2):
			var sp := _edge_point(room, r, 0.9)
			for k in 5:
				b.rock(sp + Vector3(r.randf_range(-0.3, 0.3), 0.12 + k * 0.03, r.randf_range(-0.3, 0.3)), Vector3(0.24, 0.2, 0.24), BONE * r.randf_range(0.8, 1.05), 0.1, 0.25, r.randf() * TAU)
	b.sz = 1.0
	dscale = 1.0


## dettagli sulle facce dei muri rivolte verso le stanze: blocchi di pietra, zoccolo, cornice, nicchie, stendardi, catene
func _wall_faces(wb: W3DBuilder, ob: W3DBuilder, x: int, y: int, h: float, wc: Color, c: Vector2i) -> void:
	var sides := [[Vector2i(1, 0), 0.0], [Vector2i(-1, 0), PI], [Vector2i(0, 1), -PI * 0.5], [Vector2i(0, -1), PI * 0.5]]
	var k := 0
	for sd in sides:
		var d: Vector2i = sd[0]
		k += 1
		if not gm.is_floor(c + d):
			continue
		var yaw: float = sd[1]
		var nrm := Vector3(d.x, 0, d.y)
		var tan := Vector3(-d.y, 0, d.x)
		var base := Vector3(x + 0.5, 0, y + 0.5) + nrm * 0.5
		var hh := _hash2(x, y, 100 + k)
		# zoccolo e cornice
		wb.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.07 + Vector3(0, 0.22, 0)), Vector3(0.16, 0.44, 1.06), _k(wc, 0.72), 0.12, 8)
		wb.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.05 + Vector3(0, h - 0.18, 0)), Vector3(0.12, 0.26, 1.04), _k(wc, 0.8), 0.12, 8)
		# blocchi di pietra in due file, sfalsati e di tonalita' diversa
		for row in 2:
			var yy := 0.72 + row * 0.8
			for q in 3:
				var off := (q - 1.0 + (0.18 if row == 1 else -0.18)) * 0.33
				var bh := _hash2(x * 3 + q, y * 5 + row, 200 + k)
				wb.rock(base + nrm * (0.05 + bh * 0.04) + tan * off + Vector3(0, yy, 0), Vector3(0.3 + bh * 0.1, 0.5, 0.2 + bh * 0.06), _k(wc, (0.85 + bh * 0.5)), 0.2, 0.28, yaw + bh)
		var dk := ""
		if hh > 0.3 and hh < 0.44:
			dk = "w_pillar"
		elif hh > 0.44 and hh < 0.5:
			dk = "w_skulls"
		elif hh < 0.05:
			dk = "w_niche"
		elif hh < 0.1:
			dk = "w_banner"
		elif hh < 0.16:
			dk = "w_chains"
		elif hh < 0.22:
			dk = "w_web"
		if dk != "":
			var bx := roundi(base.x * 100.0)
			var bz := roundi(base.z * 100.0)
			var extra := 1 if _hash2(x, y, 7) > 0.5 else 0
			if ed_hide_keys.has(Vector2i(bx, bz)):
				pass
			else:
				reg_static.append(["dec:" + dk, Vector2(base.x, base.z), yaw, int(h * 100.0) * 2 + extra, 0])
				_wall_deco(dk, wb, ob, base, yaw, h, extra, wc)


## decorazioni appese ai muri (registrate: l'editor le sposta); base = centro della faccia del muro, yaw = direzione verso la stanza
func _wall_deco(kind: String, wb: W3DBuilder, ob: W3DBuilder, base: Vector3, yaw: float, h: float, extra: int, wc: Color) -> void:
	var nrm := Vector3(cos(yaw), 0, -sin(yaw))
	var tan := Vector3(-nrm.z, 0, nrm.x)
	match kind:
		"w_pillar":
			# pilastro addossato: base, fusto a sei lati, capitello (sporge solo 0.3: dentro la fascia dove il giocatore non arriva)
			var pb := base + nrm * 0.15
			wb.box(Transform3D(Basis(Vector3.UP, yaw), pb + Vector3(0, 0.15, 0)), Vector3(0.34, 0.3, 0.5), _k(wc, 0.8), 0.12, 8)
			wb.cyl(Transform3D(Basis.IDENTITY, pb + Vector3(0, 0.3, 0)), 0.2, 0.17, h - 0.8, 6, _k(wc, 1.2), 0.14)
			wb.box(Transform3D(Basis(Vector3.UP, yaw), pb + Vector3(0, h - 0.4, 0)), Vector3(0.36, 0.3, 0.5), _k(wc, 0.85), 0.12, 8)
		"w_skulls":
			for q in 5:
				ob.rock(base + nrm * 0.1 + tan * (q - 2) * 0.18 + Vector3(0, 0.95, 0), Vector3(0.17, 0.17, 0.17), Color(0.8, 0.76, 0.66), 0.08, 0.2, 17.0 + q)
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.1 + tan * (q - 2) * 0.18 + Vector3(0, 0.85, 0)), Vector3(0.1, 0.06, 0.1), Color(0.05, 0.04, 0.05), 0.0, 8)
		"w_niche":
			wb.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.02 + Vector3(0, 1.4, 0)), Vector3(0.1, 0.8, 0.55), Color(0.02, 0.015, 0.02), 0.0, 8)
			ob.rock(base + nrm * 0.12 + Vector3(0, 1.2, 0), Vector3(0.3, 0.3, 0.3), Color(0.8, 0.76, 0.65), 0.08, 0.2, 3.0)
			ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.12 + tan * 0.18 + Vector3(0, 1.1, 0)), Vector3(0.07, 0.12, 0.07), Color(1.0, 0.85, 0.5, 0.15), 0.0, 8)
		"w_banner":
			var cc := Color(0.45, 0.08, 0.1) if extra == 1 else Color(0.12, 0.17, 0.4)
			ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.06 + Vector3(0, h - 0.5, 0)), Vector3(0.05, 0.08, 0.9), Color(0.2, 0.15, 0.1), 0.1, 8)
			var t0 := base + nrm * 0.08 + tan * -0.34 + Vector3(0, h - 0.55, 0)
			var t1 := base + nrm * 0.08 + tan * 0.34 + Vector3(0, h - 0.55, 0)
			ob.quad(t0, t1, t1 + Vector3(0, -1.5, 0), t0 + Vector3(0, -1.5, 0), cc)
			ob.tri(t0 + Vector3(0, -1.5, 0), t1 + Vector3(0, -1.5, 0), (t0 + t1) * 0.5 + Vector3(0, -1.95, 0), _k(cc, 0.8))
		"w_chains":
			for q in 3:
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.07 + tan * (q - 1) * 0.28 + Vector3(0, h - 0.9, 0)), Vector3(0.05, 1.5 - q * 0.3, 0.05), Color(0.2, 0.2, 0.22), 0.1, 8)
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.08 + tan * (q - 1) * 0.28 + Vector3(0, h - 1.7 + q * 0.3, 0)), Vector3(0.14, 0.14, 0.14), Color(0.28, 0.28, 0.3), 0.1, 8)
		"w_web":
			var a0 := base + nrm * 0.04 + tan * -0.5 + Vector3(0, h - 0.1, 0)
			var a1 := base + nrm * 0.04 + tan * 0.0 + Vector3(0, h - 0.1, 0)
			ob.tri(a0, a1, a0 + Vector3(0, -1.0, 0) + nrm * 0.02, Color(0.7, 0.7, 0.75, 0.9))


# ------------------------------------------------------------------ luci vere (Forward+): torce con ombre portate
var pool: Array = []
var pool_pos: Array = []
var pool_en: Array = []
const POOL_N := 10
const SHADOWED := 3


func _make_pool() -> void:
	for i in POOL_N:
		var ol := OmniLight3D.new()
		ol.light_color = Color(0.96, 0.77, 0.62)
		ol.omni_range = 12.0
		ol.omni_attenuation = 1.35
		ol.shadow_enabled = i < SHADOWED
		ol.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
		ol.shadow_bias = 0.06
		ol.shadow_blur = 1.6
		ol.light_energy = 0.0
		ol.visible = false
		vp.add_child(ol)
		pool.append(ol)
		pool_pos.append(Vector3.ZERO)
		pool_en.append(0.0)
	hero_light = OmniLight3D.new()
	hero_light.light_color = Color(0.95, 0.85, 0.74)
	hero_light.omni_range = 9.0
	hero_light.omni_attenuation = 1.5
	hero_light.light_energy = 0.7
	hero_light.shadow_enabled = false
	vp.add_child(hero_light)


func _real_lights(dt: float) -> void:
	var cand: Array = []
	for f in gm.flick:
		var l = f[0]
		if not is_instance_valid(l) or not (l as CanvasItem).is_visible_in_tree():
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
		if not world_on and ed_hide_keys.has(Vector2i(roundi(gp.x * 100.0), roundi(gp.y * 100.0))):
			continue
		cand.append([gp.distance_squared_to(pos), Vector3(gp.x, 1.9, gp.y), minf(4.2, float(f[1]) * 3.4) * (0.55 if world_on else 1.0), Color(0.96, 0.76, 0.62)])
	for dl in decor_lights:
		var dv: Vector3 = dl
		cand.append([Vector2(dv.x, dv.z).distance_squared_to(pos), dv, 3.0, Color(0.96, 0.72, 0.56)])
	for rl in room_lamps:
		var rp: Vector2 = rl[0]
		cand.append([rp.distance_squared_to(pos) * 1.6, Vector3(rp.x, 3.6, rp.y), 0.55, rl[1]])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var ease := 1.0 - exp(-dt * 6.0)
	for i in POOL_N:
		var ol: OmniLight3D = pool[i]
		var want_pos := Vector3.ZERO
		var te := 0.0
		if i < cand.size():
			want_pos = cand[i][1]
			te = cand[i][2]
			ol.light_color = cand[i][3]
		var cur: Vector3 = pool_pos[i]
		var ce: float = pool_en[i]
		if te > 0.0 and cur.distance_to(want_pos) > 1.2:
			ce = lerpf(ce, 0.0, 1.0 - exp(-dt * 12.0))
			if ce < 0.05:
				cur = want_pos
		else:
			cur = cur.lerp(want_pos, ease)
			ce = lerpf(ce, te, ease)
		pool_pos[i] = cur
		pool_en[i] = ce
		ol.position = cur
		var fl := 1.0 + sin(lamp_t * 11.0 + cur.x * 3.1) * 0.07 + sin(lamp_t * 23.0 + cur.z) * 0.04
		ol.light_energy = ce * fl
		ol.visible = ce > 0.02
	hero_light.position = Vector3(pos.x, 3.0 + elev_y, pos.y)
	# nel mondo aperto: luce piu' fredda e desaturata, lampade piu' piccole (niente dominante arancione)
	hero_light.light_color = Color(0.78, 0.84, 1.0) if world_on else Color(0.95, 0.85, 0.74)
	hero_light.light_energy = 0.55 if world_on else 0.7
	env.ambient_light_energy = 0.30 if world_on else 0.16
	env.ambient_light_color = Color(0.40, 0.44, 0.58) if world_on else Color(0.36, 0.38, 0.52)


# ------------------------------------------------------------------ bolla spazio-temporale (Cronotone) in 3D
var bub_nodes: Dictionary = {}
var bub_meshes: Dictionary = {}


func _bub_mesh(key: String) -> ArrayMesh:
	if bub_meshes.has(key):
		return bub_meshes[key]
	var b := W3DBuilder.new()
	b.rn.seed = 77
	match key:
		"disc":
			b.cyl(Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.0, 1.0, 0.02, 24, Color(0.02, 0.015, 0.05), 0.0)
		"ring":
			for i in 36:
				var a0 := TAU * i / 36.0
				var a1 := TAU * (i + 1) / 36.0
				var p0 := Vector3(cos(a0), 0, sin(a0))
				var p1 := Vector3(cos(a1), 0, sin(a1))
				b.quad(p0 * 0.96, p1 * 0.96, p1 * 1.04, p0 * 1.04, Color(1, 1, 1, 0.0))
		"arc":
			for i in 14:
				var a0 := i * 0.3
				var a1 := a0 + 0.3
				var p0 := Vector3(cos(a0), 0, sin(a0))
				var p1 := Vector3(cos(a1), 0, sin(a1))
				b.quad(p0 * 0.95, p1 * 0.95, p1 * 1.03, p0 * 1.03, Color(1, 1, 1, 0.0))
		"arms":
			for arm in 3:
				for i in 13:
					var u0 := i / 13.0
					var u1 := (i + 1) / 13.0
					var a0 := arm * TAU / 3.0 + u0 * 3.2
					var a1 := arm * TAU / 3.0 + u1 * 3.2
					var r0 := 0.18 + 0.78 * u0
					var r1 := 0.18 + 0.78 * u1
					var p0 := Vector3(cos(a0), 0, sin(a0)) * r0
					var p1 := Vector3(cos(a1), 0, sin(a1)) * r1
					b.quad(p0, p1, p1 + Vector3(0.03, 0.0, 0.03), p0 + Vector3(0.03, 0.0, 0.03), Color(1, 1, 1, 0.05))
		"hand":
			b.box(Transform3D(Basis.IDENTITY, Vector3(0.45, 0.0, 0)), Vector3(0.9, 0.02, 0.05), Color(1, 1, 1, 0.0), 0.0, 0)
		"tick":
			b.box(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(0.1, 0.03, 0.04), Color(1, 1, 1, 0.0), 0.0, 0)
		"spark":
			b.blob(Vector3.ZERO, Vector3(0.07, 0.07, 0.07), Color(1, 1, 1, 0.0), 5, 3, 0.0, 0.0)
	var m: ArrayMesh = b.mesh()
	bub_meshes[key] = m
	return m


func _bub_mi(parent: Node3D, key: String, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _bub_mesh(key)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col if key != "disc" else Color(0.03, 0.02, 0.08)
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _make_bubble_rig(parent: Node3D, col: Color) -> Dictionary:
	var d := {}
	d["disc"] = _bub_mi(parent, "disc", col)
	d["ring"] = _bub_mi(parent, "ring", col)
	d["ring2"] = _bub_mi(parent, "arc", Color(1, 1, 1))
	d["ring3"] = _bub_mi(parent, "arc", col)
	d["arms"] = _bub_mi(parent, "arms", col)
	d["hand"] = _bub_mi(parent, "hand", Color(1, 1, 1))
	d["hand2"] = _bub_mi(parent, "hand", col)
	var ticks: Array = []
	for i in 12:
		ticks.append(_bub_mi(parent, "tick", Color(1, 1, 1)))
	d["ticks"] = ticks
	var sparks: Array = []
	for i in 6:
		sparks.append(_bub_mi(parent, "spark", Color(1, 1, 1)))
	d["sparks"] = sparks
	return d


func _animate_bubble_rig(d: Dictionary, r: float, t: float, fw: float) -> void:
	(d["disc"] as Node3D).scale = Vector3(r, 1, r)
	(d["ring"] as Node3D).scale = Vector3(r, 1, r)
	(d["ring"] as Node3D).position.y = 0.04
	(d["arms"] as Node3D).scale = Vector3(r, 1, r)
	(d["arms"] as Node3D).rotation.y = fw * t * 3.2
	(d["arms"] as Node3D).position.y = 0.05
	(d["ring2"] as Node3D).scale = Vector3(r * 0.82, 1, r * 0.82)
	(d["ring2"] as Node3D).rotation.y = fw * t * 2.0
	(d["ring2"] as Node3D).position.y = 0.06
	(d["ring3"] as Node3D).scale = Vector3(r * 1.18, 1, r * 1.18)
	(d["ring3"] as Node3D).rotation.y = -fw * t * 1.5
	(d["ring3"] as Node3D).position.y = 0.06
	var hand := fw * t * 4.0
	(d["hand"] as Node3D).scale = Vector3(r, 1, r)
	(d["hand"] as Node3D).rotation.y = -hand
	(d["hand"] as Node3D).position.y = 0.07
	(d["hand2"] as Node3D).scale = Vector3(r * 0.65, 1, r * 0.65)
	(d["hand2"] as Node3D).rotation.y = -hand * 0.25
	(d["hand2"] as Node3D).position.y = 0.07
	var tks: Array = d["ticks"]
	for i in tks.size():
		var a := i * TAU / 12.0
		var tk: Node3D = tks[i]
		tk.position = Vector3(cos(a), 0.06, sin(a)) * r * 1.08
		tk.rotation.y = -a
		tk.scale = Vector3(1.0 if i % 3 == 0 else 0.6, 1, 1)
	var sps: Array = d["sparks"]
	for i in sps.size():
		var a2 := fw * t * 2.4 + i * TAU / 6.0
		var rr := r * (1.15 + 0.2 * sin(t * 3.0 + i))
		(sps[i] as Node3D).position = Vector3(cos(a2) * rr, 0.3 + 0.25 * sin(t * 4.0 + i), sin(a2) * rr)


func _sync_bubble(n: ChronoBubble) -> void:
	var id: int = n.get_instance_id()
	if not bub_nodes.has(id):
		var root := Node3D.new()
		vp.add_child(root)
		var col: Color = n.col
		var nd := _make_bubble_rig(root, col)
		nd["root"] = root
		nd["seen"] = 0.0
		nd["src"] = weakref(n)
		var item := Node3D.new()
		var imi := MeshInstance3D.new()
		var iid := str(n.res["id"])
		imi.mesh = W3DChrono.mesh(iid) if W3DChrono.has(iid) else W3DChrono.mesh("generic")
		imi.material_override = mat_prop
		item.add_child(imi)
		root.add_child(item)
		nd["item"] = item
		bub_nodes[id] = nd
	var d: Dictionary = bub_nodes[id]
	d["seen"] = lamp_t
	var root3: Node3D = d["root"]
	root3.position = Vector3(n.position.x / 16.0, 0.12, n.position.y / 16.0)
	var t: float = n.t
	var grow := 1.0 - pow(1.0 - clampf(t / ChronoBubble.T_OPEN, 0.0, 1.0), 3.0)
	var tf := t - ChronoBubble.T_OPEN - ChronoBubble.T_HOLD
	var kfly := clampf(tf / ChronoBubble.T_FLY, 0.0, 1.0)
	var r := n.radius / 16.0 * grow * (1.0 - 0.85 * kfly * kfly) * 1.15
	var fw: float = n.fwd
	root3.visible = r > 0.03
	_animate_bubble_rig(d, r, t, fw)
	var item3: Node3D = d["item"]
	item3.visible = t > ChronoBubble.T_OPEN * 0.6
	var k := float(n.spr.get_meta("k")) * 16.0 / 22.0 * 1.15
	var appear := clampf((t - ChronoBubble.T_OPEN * 0.6) / 0.4, 0.0, 1.0)
	if tf <= 0.0:
		item3.position = Vector3(0, 0.6 + sin(t * 5.0) * 0.08, 0)
		item3.scale = Vector3.ONE * k * appear
	else:
		var tgt := Vector3((gm.player.position.x - n.position.x) / 16.0, 0.9, (gm.player.position.y - n.position.y) / 16.0)
		item3.position = Vector3(0, 0.6, 0).lerp(tgt, kfly * kfly)
		item3.scale = Vector3.ONE * k * (1.0 - 0.5 * kfly)
	item3.rotation.y = t * 1.6 * fw


func _bubbles_cleanup() -> void:
	for id in bub_nodes.keys():
		var d: Dictionary = bub_nodes[id]
		var sr = (d["src"] as WeakRef).get_ref()
		if sr == null or not is_instance_valid(sr) or float(d["seen"]) < lamp_t - 0.2:
			(d["root"] as Node3D).queue_free()
			bub_nodes.erase(id)


# ------------------------------------------------------------------ effetti 3D: scintille, impatti, lampi di colpo, contorni
var out_mats: Dictionary = {}
var flash_mat: StandardMaterial3D
var bursts_live := 0


func _outline_mat(key: String) -> ShaderMaterial:
	if out_mats.has(key):
		return out_mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/w3d_outline.gdshader")
	var col := Color(0.42, 0.05, 0.04)
	if key == "hero":
		col = Color(0.5, 0.33, 0.07)
	elif key == "ally":
		col = Color(0.08, 0.38, 0.2)
	elif key == "npc":
		col = Color(0.38, 0.34, 0.18)
	m.set_shader_parameter("color", col)
	extra_mats.append(m)
	out_mats[key] = m
	return m


func _add_outline(node: Node3D, key: String) -> void:
	if OS.get_cmdline_user_args().has("--nooutline"):
		return
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null or mi.mesh == disc_mesh:
			continue
		var ol := MeshInstance3D.new()
		ol.mesh = mi.mesh
		ol.material_override = _outline_mat(key)
		ol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.add_child(ol)


func _flash(node: Node3D, on: bool) -> void:
	if flash_mat == null:
		flash_mat = StandardMaterial3D.new()
		flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flash_mat.albedo_color = Color(0.7, 0.62, 0.58, 0.4)
		flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader.resource_path.ends_with("w3d_outline.gdshader"):
			continue
		mi.material_overlay = flash_mat if on else null


func burst3d(p2: Vector2, col: Color, n: int, speed: float, life: float) -> void:
	if not active or bursts_live > 16 or OS.get_cmdline_user_args().has("--noburst"):
		return
	var pr := CPUParticles3D.new()
	pr.one_shot = true
	pr.explosiveness = 1.0
	pr.amount = clampi(n, 4, 28)
	pr.lifetime = clampf(life * 1.2, 0.25, 0.9)
	pr.direction = Vector3.UP
	pr.spread = 180.0
	pr.gravity = Vector3(0, -5.0, 0)
	pr.initial_velocity_min = speed / 16.0 * 0.5
	pr.initial_velocity_max = speed / 16.0 * 1.4
	pr.scale_amount_min = 0.6
	pr.scale_amount_max = 1.4
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 0.1, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col.lightened(0.25)
	bm.material = m
	pr.mesh = bm
	pr.position = Vector3(p2.x / 16.0, 0.9 + elev_at(p2.x / 16.0, p2.y / 16.0), p2.y / 16.0)
	vp.add_child(pr)
	pr.emitting = true
	bursts_live += 1
	var tm := get_tree().create_timer(pr.lifetime + 0.2)
	tm.timeout.connect(func():
		bursts_live -= 1
		if is_instance_valid(pr):
			pr.queue_free())


# ------------------------------------------------------------------ morte: i cubetti si scompongono
var booms: Array = []
var cell_cache: Dictionary = {}


func _explode(spr: Sprite2D, base: Vector3, scl: float, tdn := "") -> void:
	if tdn != "":
		_explode_td(tdn, base, scl)
		return
	var tex := spr.texture
	var key := tex.get_rid().get_id()
	var cells: Dictionary
	if cell_cache.has(key):
		cells = cell_cache[key]
	else:
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var tb := W3DBuilder.new()
		cells = tb.topcells(img)
		cell_cache[key] = cells
	if cells.is_empty() or booms.size() > 6:
		return
	var vox := 1.0 / 16.0 * 1.1 * scl
	var keys := cells.keys()
	var step := 1 if keys.size() <= 230 else 2
	var items: Array = []
	for i in range(0, keys.size(), step):
		items.append(keys[i])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(vox, vox, vox) * 1.15
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mt
	mm.mesh = bm
	mm.instance_count = items.size()
	var w := float(spr.texture.get_width())
	var pos: Array = []
	var vel: Array = []
	var spin: Array = []
	for i in items.size():
		var k: Vector2i = items[i]
		var c: Color = cells[k]["c"]
		c = Color(minf(c.r * 1.5 + 0.05, 1.0), minf(c.g * 1.5 + 0.05, 1.0), minf(c.b * 1.5 + 0.05, 1.0), 1.0)
		mm.set_instance_color(i, c)
		var p := base + Vector3((k.x - w * 0.5) * vox, int(cells[k]["h"]) * vox, k.y * vox)
		var out := Vector3(p.x - base.x, 0.0, p.z - base.z)
		var dirv := out.normalized() if out.length() > 0.01 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
		pos.append(p)
		vel.append(dirv * randf_range(1.8, 5.5) + Vector3(0, randf_range(2.5, 7.0), 0))
		spin.append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	booms.append({"mi": mi, "mm": mm, "pos": pos, "vel": vel, "spin": spin, "rot": items.map(func(_i): return Vector3.ZERO), "t": 0.0, "vox": vox})


func _explode_td(name: String, base: Vector3, scl: float) -> void:
	if name.begins_with("ch:"):
		burst3d(Vector2(base.x, base.z) * 16.0, Color(1.0, 0.7, 0.3), 26, 90.0, 0.7)
		return
	var d := td_get(name)
	var cells: Dictionary = d["cells"]
	if cells.is_empty() or booms.size() > 6:
		return
	var vox := TD_VOX * TD_STEP * scl
	var keys := cells.keys()
	var step := 1
	var items: Array = []
	for i in range(0, keys.size(), step):
		items.append(keys[i])
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(vox, vox, vox) * 1.15
	var mt := StandardMaterial3D.new()
	mt.vertex_color_use_as_albedo = true
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mt
	mm.mesh = bm
	mm.instance_count = items.size()
	var w := float(d["w"])
	var pos: Array = []
	var vel: Array = []
	var spin: Array = []
	for i in items.size():
		var k: Vector2i = items[i]
		var c: Color = cells[k]["c"]
		mm.set_instance_color(i, Color(minf(c.r * 1.5 + 0.05, 1.0), minf(c.g * 1.5 + 0.05, 1.0), minf(c.b * 1.5 + 0.05, 1.0), 1.0))
		var p := base + Vector3((k.x - w * 0.5 + 0.5) * vox, int(cells[k]["h"]) * vox, (k.y + 0.5) * vox)
		var out := Vector3(p.x - base.x, 0.0, p.z - base.z)
		var dirv := out.normalized() if out.length() > 0.01 else Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
		pos.append(p)
		vel.append(dirv * randf_range(1.8, 5.8) + Vector3(0, randf_range(2.8, 7.5), 0))
		spin.append(Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)))
		mm.set_instance_transform(i, Transform3D(Basis(), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vp.add_child(mi)
	booms.append({"mi": mi, "mm": mm, "pos": pos, "vel": vel, "spin": spin, "rot": items.map(func(_i): return Vector3.ZERO), "t": 0.0, "vox": vox})


func _booms_update(dt: float) -> void:
	for bm in booms.duplicate():
		bm["t"] = float(bm["t"]) + dt
		var t: float = bm["t"]
		var mm: MultiMesh = bm["mm"]
		var pos: Array = bm["pos"]
		var vel: Array = bm["vel"]
		var spin: Array = bm["spin"]
		var rot: Array = bm["rot"]
		var vox: float = bm["vox"]
		var sc := clampf((1.6 - t) / 0.5, 0.0, 1.0)
		for i in pos.size():
			var v: Vector3 = vel[i]
			v.y -= 16.0 * dt
			var p: Vector3 = (pos[i] as Vector3) + v * dt
			if p.y < vox * 0.6:
				p.y = vox * 0.6
				v.y = absf(v.y) * 0.32
				v.x *= 0.72
				v.z *= 0.72
				if absf(v.y) < 0.6:
					v.y = 0.0
			vel[i] = v
			pos[i] = p
			var r: Vector3 = (rot[i] as Vector3) + (spin[i] as Vector3) * dt * (1.0 if p.y > vox else 0.15)
			rot[i] = r
			mm.set_instance_transform(i, Transform3D(Basis.from_euler(r).scaled(Vector3.ONE * sc), p))
		if t > 1.7:
			(bm["mi"] as Node).queue_free()
			booms.erase(bm)


# ------------------------------------------------------------------ oggetti dinamici
func _drop_dyn(id) -> void:
	if dyn.has(id):
		if dyn[id].has("trail"):
			(dyn[id]["trail"] as W3DFx.Trail).release()
		var n: Node3D = dyn[id]["node"]
		if is_instance_valid(n):
			n.queue_free()
		dyn.erase(id)


func _tex_mesh(tex: Texture2D, k: float) -> ArrayMesh:
	var key := "%d_%.2f" % [tex.get_rid().get_id(), k]
	if tex_mesh.has(key):
		return tex_mesh[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var b := W3DBuilder.new()
	b.inflate(img, 1.0 / 16.0, k)
	var m := b.mesh()
	tex_mesh[key] = m
	return m


func _sprite_center(n: Node2D, spr: Sprite2D) -> Vector2:
	var t := spr.texture
	var sz := Vector2(t.get_width(), t.get_height())
	var off := spr.position + spr.offset
	if spr.centered:
		return n.position + off
	return n.position + off + sz * 0.5


func _make_generic(n: Node2D, spr: Sprite2D, is_player := false) -> Node3D:
	var pk := str(n.get("kind")) if n.get("kind") != null else ""
	if pk != "" and not is_player and not (n is Enemy or n is Villager or n is Ally or n is Critter) and W3DProps.ok(pk):
		var tw := float(spr.texture.get_width()) / 16.0
		var th := float(spr.texture.get_height()) / 16.0
		var mkey := "p3_%s_%d" % [pk, n.get_instance_id() % 3]
		var pmesh: ArrayMesh
		var from_base := false
		if vox_cache.has(mkey):
			pmesh = vox_cache[mkey]
			from_base = bool(vox_cache.get(mkey + "_b", false))
		else:
			pmesh = _base_prop(pk, tw, th, hash(mkey))
			if pmesh != null:
				from_base = true
				vox_cache[mkey] = pmesh
				vox_cache[mkey + "_b"] = true
		if pmesh == null:
			var im: Image = spr.texture.get_image()
			if im.is_compressed():
				im.decompress()
			im.convert(Image.FORMAT_RGBA8)
			var sr := 0.0
			var sg := 0.0
			var sb := 0.0
			var cnt := 0
			for yy in range(0, im.get_height(), 2):
				for xx in range(0, im.get_width(), 2):
					var pc := im.get_pixel(xx, yy)
					if pc.a > 0.5:
						sr += pc.r
						sg += pc.g
						sb += pc.b
						cnt += 1
			var av := Color(sr / maxf(cnt, 1), sg / maxf(cnt, 1), sb / maxf(cnt, 1))
			pmesh = W3DProps.build(pk, tw, th, av, hash(mkey))
			vox_cache[mkey] = pmesh
		var proot := Node3D.new()
		var pmi := MeshInstance3D.new()
		pmi.mesh = pmesh
		pmi.material_override = mat if from_base else mat_prop
		pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		proot.add_child(pmi)
		vp.add_child(proot)
		return proot
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _tex_mesh(spr.texture, 0.12)
	mi.material_override = mat_chr if (is_player or n is Enemy or n is Villager or n is Ally or n is Critter) else mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	vp.add_child(root)
	return root


## personaggio "esatto": lo sprite originale, ogni pixel un cubetto (stessi colori e stessa silhouette)
func _td_name(n: Node, is_player: bool) -> String:
	var nm := ""
	if is_player and not (gm.player.veh as Dictionary).is_empty():
		return "ch:" + str(gm.player.veh["id"])
	if is_player:
		nm = {"cavaliere": "hero", "cacciatore": "hunter", "negromante": "necro", "chierico": "cleric"}.get(str(gm.player.cls), "")
	elif n is Enemy:
		var k := str((n as Enemy).kind)
		if Enemy.CHAMPS.has(k):
			nm = str(Enemy.CHAMPS[k]["spr"])
		elif Enemy.DEFS.has(k):
			nm = str(Enemy.DEFS[k][0])
		else:
			nm = k
	elif n is Prop and str((n as Prop).kind) == "elder":
		nm = "necro"
	elif n is Prop and str((n as Prop).kind) == "npc" and gm.NPCS.has((n as Prop).npc_id):
		nm = str(gm.NPCS[(n as Prop).npc_id]["spr"])        # il fuggiasco e gli altri personaggi fissi: modello visto dall'alto
	elif n is Ally:
		nm = "skeleton"
		if str((n as Ally).kind) != "":
			return "ch:" + str((n as Ally).kind)
	elif n is Villager:
		var rid := str((n as Villager).role)
		if Villager.ROLES.has(rid):
			nm = str(Villager.ROLES[rid]["spr"])
	elif n is Critter:
		nm = str(Critter.KINDS[(n as Critter).kind]["spr"])
	if nm != "" and td_has(nm):
		return nm
	return ""


func _make_td(name: String) -> Node3D:
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	if name.begins_with("ch:"):
		mi.mesh = W3DChrono.mesh(name.substr(3))
		mi.material_override = mat_prop
		mi.rotation.y = PI * 0.5
	else:
		mi.mesh = td_mesh(name)
		mi.material_override = mat_chr
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	vp.add_child(root)
	return root


func _make_exact(spr: Sprite2D) -> Node3D:
	var key := ("exsolid_%d" if fpv else "exflat_%d") % spr.texture.get_rid().get_id()
	var mesh: ArrayMesh
	if vox_cache.has(key):
		mesh = vox_cache[key]
	else:
		var img: Image = spr.texture.get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var b := W3DBuilder.new()
		var iw := img.get_width()
		if fpv:
			# retro: lo sprite posteriore (nome_b.png) se esiste
			var back: Image = null
			var tp := spr.texture.resource_path
			if tp.ends_with(".png"):
				var bp := tp.trim_suffix(".png") + "_b.png"
				if not ResourceLoader.exists(bp):
					bp = "res://assets/back/" + tp.get_file().get_basename() + "_b.png"      # retri derivati o generati, per i personaggi senza sprite posteriore
				if ResourceLoader.exists(bp):
					back = (load(bp) as Texture2D).get_image()
					if back.is_compressed():
						back.decompress()
					back.convert(Image.FORMAT_RGBA8)
			# vista dall'alto (colori + altezze) se disponibile: da lì vengono impronta e sagome laterali
			var tdn2 := tp.get_file().get_basename()
			if tp.begins_with("res://assets/sprites/") and td_has(tdn2):
				var tci: Image = (load("res://assets/topdown/%s.png" % tdn2) as Texture2D).get_image()
				var thi: Image = (load("res://assets/topdown/%s_h.png" % tdn2) as Texture2D).get_image()
				for q in [tci, thi]:
					if (q as Image).is_compressed():
						(q as Image).decompress()
					(q as Image).convert(Image.FORMAT_RGBA8)
				var sidei: Image = null
				var sp2 := "res://assets/side/" + tdn2 + "_s.png"
				if ResourceLoader.exists(sp2):
					sidei = (load(sp2) as Texture2D).get_image()
					if sidei.is_compressed():
						sidei.decompress()
					sidei.convert(Image.FORMAT_RGBA8)
				b.hull(img, back, tci, thi, 1.0 / 16.0 * 1.1, sidei)
			else:
				b.solid(img, back, 1.0 / 16.0 * 1.1)
		elif iw >= 48:
			b.voxel(img, 1.0 / 16.0 * 1.1, 24, 7)      # edifici: blocchi alti con tetto a scalini
		elif iw >= 26:
			b.voxel(img, 1.0 / 16.0 * 1.1, 7, 4)
		else:
			b.voxel(img, 1.0 / 16.0 * 1.1, 4, 3)
		mesh = b.mesh()
		vox_cache[key] = mesh
	var root := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat_chr
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(mi)
	vp.add_child(root)
	return root


func _make_char(kind: String) -> Node3D:
	var nd := _vox_node(kind, 0.075)
	return nd


func _sync_node2d(n: Node, is_player := false) -> void:
	if not (n is Node2D) or not is_instance_valid(n) or not (n as Node2D).visible:
		return
	var id := n.get_instance_id()
	if gm.side_scroll_active and not is_player and not gm.side_scroll_enemies.has(n) and not gm.side_scroll_pickups.has(n):
		if dyn.has(id):
			_drop_dyn(id)
		return
	var spr: Sprite2D = null
	if n.get("spr") != null:
		spr = n.get("spr")
	if spr == null or spr.texture == null:
		return
	var n2 := n as Node2D
	if n is Pickup:
		if world_on and (n2.position / 16.0).distance_squared_to(pos) > 54.0 * 54.0:
			if dyn.has(id):
				_drop_dyn(id)
			return
		_sync_pickup(n as Pickup, id)
		return
	# pagine, bottino e cancelli sono creati come arredo (setup_top) ma servono al gioco: vanno disegnati
	var func_prop: bool = n is Prop and _is_game_prop(n as Prop)
	if world_on and not (is_player or func_prop or n is Enemy or n is Villager or n is Ally or n is Critter or n is Pickup):
		if dyn.has(id):
			_drop_dyn(id)
		return
	if not is_player and world_on and (n2.position / 16.0).distance_squared_to(pos) > 54.0 * 54.0:
		if dyn.has(id):
			_drop_dyn(id)
		return
	if not dyn.has(id):
		var node: Node3D
		var kind := ""
		var model := false
		if is_player:
			var pc: String = str(gm.player.cls)
			if pc == "cavaliere":
				kind = "hero"
			elif pc == "negromante":
				kind = "necro"
		elif n is Enemy:
			var ek := str((n as Enemy).kind)
			if KNOWN.has(ek) and (n as Enemy).scl <= 1.01:
				kind = ek
		var chr := n is Enemy or n is Villager or n is Ally or n is Critter or is_player or (n is Prop and str((n as Prop).kind) in ["elder", "npc"])
		var tdn := ""
		if char_mode == 0 and chr:
			tdn = _td_name(n, is_player)
		if tdn != "":
			kind = ""
			node = _make_td(tdn)
			model = true
		elif char_mode < 2 and chr:
			kind = ""
			node = _make_exact(spr)
		elif kind != "":
			node = _make_char(kind)
			model = true
		elif world_on and n is Prop and not W3DProps.ok(str((n as Prop).kind)):
			node = _make_exact(spr)
		else:
			node = _make_generic(n2, spr, is_player)
		var okey := ""
		if is_player:
			okey = "hero"
		elif n is Enemy:
			okey = "enemy"
		elif n is Ally:
			okey = "ally"
		elif n is Villager:
			okey = "npc"
		if okey != "" and tdn == "" and char_mode == 2:      # i personaggi a blocchi (cubetti) non hanno contorno nero
			_add_outline(node, okey)
		dyn[id] = {"node": node, "kind": kind, "model": model, "last": n2.position, "ph": randf() * 6.0, "flow": 0.0, "td": tdn}
	var d: Dictionary = dyn[id]
	if is_player and char_mode == 0 and str(d.get("td", "")) != _td_name(n, true):
		_drop_dyn(id)       # sceso o salito da un mezzo: il modello cambia
		return
	var node3: Node3D = d["node"]
	var c := _sprite_center(n2, spr)
	var is_model: bool = d["model"]
	var moving := (n2.position - (d["last"] as Vector2)).length() > 0.05
	var dirv: Vector2 = n2.position - (d["last"] as Vector2)
	d["last"] = n2.position
	if is_model:
		# i modelli stanno in piedi sul punto di terra (position), non al centro dello sprite
		node3.position = Vector3(n2.position.x / 16.0, 0.0, n2.position.y / 16.0)
		var face := Vector2.ZERO
		if is_player:
			face = gm.player.face
		elif n is Enemy:
			var tp: Vector2 = gm.player.position - n2.position
			face = tp if tp.length() > 1.0 else dirv
		if face.length() > 0.1:
			var yaw := atan2(-face.x, -face.y)
			node3.rotation.y = yaw if is_player else lerp_angle(node3.rotation.y, yaw, 0.35)
		var sc := 1.0
		if n is Enemy:
			sc = (n as Enemy).scl
		node3.scale = Vector3.ONE * sc * (1.0 if str(d.get("td", "")) != "" else 0.8) * (1.0 + (0.1 if (n is Enemy and float((n as Enemy).flash) > 0.0) else 0.0))
		d["flow"] = lerpf(float(d["flow"]), 1.0 if moving else 0.0, 0.2)
		d["ph"] = float(d["ph"]) + (0.15 if moving else 0.02)
		(node3.get_child(0) as Node3D).position.y = absf(sin(float(d["ph"]))) * 0.06 if moving else 0.0
		_flow_anim(node3, float(d["flow"]), lamp_t + float(d["ph"]))
		if is_player:
			var p: Player = gm.player
			node3.visible = (p.spr.visible or not (p.veh as Dictionary).is_empty()) and not fpv and not (cine != null and cine.active)
			if p.atk_t > 0.0 and p.atk_dur > 0.0 and str(Rpg.FAM[p.weapon()["f"]]["ranged"]) == "false":
				var k := 1.0 - p.atk_t / p.atk_dur
				node3.rotation.y += lerpf(-0.9, 0.9, k * k * (3.0 - 2.0 * k))
	else:
		node3.position = Vector3(c.x / 16.0, 0.0, c.y / 16.0)
		var sc2 := spr.scale
		node3.scale = Vector3(sc2.x * (-1.0 if spr.flip_h else 1.0), (sc2.x + sc2.y) * 0.5, sc2.y)
		if char_mode == 1 and (n is Enemy or n is Villager or n is Ally or n is Critter or is_player):
			var bob := absf(sin(float(d["ph"]))) * 0.05 if moving else 0.0
			node3.position.y = bob
			d["ph"] = float(d["ph"]) + (0.2 if moving else 0.02)
		elif n is Enemy or n is Villager or n is Ally:
			node3.scale *= 0.9
			node3.scale *= 1.0 + (0.12 if (n is Enemy and float((n as Enemy).flash) > 0.0) else 0.0)
		node3.visible = spr.visible and n2.visible
		if fpv and char_mode == 1 and (n is Enemy or n is Villager or n is Ally or n is Critter):
			# prima persona: personaggio a blocchi completo che guarda dove si muove (i nemici verso di te): si vedono fianchi e schiena
			node3.position = Vector3(n2.position.x / 16.0, node3.position.y, n2.position.y / 16.0)
			var fdir := Vector2.ZERO
			if n is Enemy:
				fdir = gm.player.position - n2.position
			elif moving:
				fdir = dirv
			if fdir.length() > 0.5:
				var want := atan2(-fdir.x, -fdir.y)
				node3.rotation.y = lerp_angle(node3.rotation.y, want, 0.25)
		if n is Prop and n.has_meta("ed_yaw"):
			node3.rotation.y = float(n.get_meta("ed_yaw"))
			node3.scale *= float(n.get_meta("ed_sc", 1.0))
	var hit := false
	if n is Enemy:
		hit = float((n as Enemy).flash) > 0.0
	elif is_player:
		hit = float(gm.player.flash) > 0.0
	if hit != bool(d.get("hit", false)):
		d["hit"] = hit
		_flash(node3, hit)
	if n is Enemy and bool((n as Enemy).dying) and not bool(d.get("boom", false)):
		d["boom"] = true
		var esc := float((n as Enemy).scl)
		var bw := Vector3(n2.position.x / 16.0, 0.0, n2.position.y / 16.0)
		if char_mode == 1 or char_mode == 2 or true:
			_explode(spr, bw, maxf(esc, 0.6), str(d.get("td", "")))
		node3.visible = false
		gm.burst(n2.position, Color(1.0, 0.75, 0.4), 10, 60.0, 0.3)
	if bool(d.get("boom", false)):
		node3.visible = false
	d["seen"] = lamp_t


func _sync_fx() -> void:
	for n in gm.fx.get_children():
		if not is_instance_valid(n):
			continue
		if n is ChronoBubble:
			_sync_bubble(n)
			continue
		var id: int = n.get_instance_id()
		if n is Hazard:
			var h: Hazard = n
			if not dyn.has(id):
				var hfx := W3DFx.HazardFx.new(h.col)
				vp.add_child(hfx)
				dyn[id] = {"node": hfx, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "hazard", "struck": false}
			var rn3: W3DFx.HazardFx = dyn[id]["node"]
			rn3.position = Vector3(h.position.x / 16.0, 0.04, h.position.y / 16.0)
			rn3.update_fx(h.t, h.delay, h.life, h.tick, h.radius / 16.0, get_process_delta_time(), elev_at(h.position.x / 16.0, h.position.y / 16.0))
			if h.t >= h.delay and h.tick <= 0.0 and not bool(dyn[id]["struck"]):
				dyn[id]["struck"] = true
				gm.shake(clampf(h.radius / 20.0, 1.0, 3.5))
			dyn[id]["seen"] = lamp_t
		elif n is Hazard.Shock:
			var sh := n as Hazard.Shock
			if not dyn.has(id):
				var rmi := MeshInstance3D.new()
				rmi.mesh = _ring_mesh(sh.c)
				rmi.material_override = mat_chr
				rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				vp.add_child(rmi)
				dyn[id] = {"node": rmi, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "fxm", "src": weakref(n), "lp": sh.position, "imp": false}
			var rn4: Node3D = dyn[id]["node"]
			var kk := clampf(sh.tt / 0.36, 0.0, 1.0)
			var rr := float(sh.r) / 16.0 * (0.25 + 0.75 * (1.0 - pow(1.0 - kk, 2.0)))
			rn4.position = Vector3(sh.position.x / 16.0, 0.2, sh.position.y / 16.0)
			rn4.scale = Vector3(rr, 1.0, rr)
			dyn[id]["seen"] = lamp_t
		elif n is Line2D:
			var ln := n as Line2D
			if not dyn.has(id):
				var lmi := MeshInstance3D.new()
				lmi.mesh = _ribbon_mesh(ln)
				lmi.material_override = mat_chr
				lmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				vp.add_child(lmi)
				dyn[id] = {"node": lmi, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "fxm", "src": weakref(n), "lp": ln.position, "imp": false}
			var rn5: Node3D = dyn[id]["node"]
			rn5.position = Vector3(ln.position.x / 16.0, 0.85, ln.position.y / 16.0)
			rn5.scale = Vector3(ln.scale.x, 1.0, ln.scale.y)
			rn5.visible = ln.modulate.a > 0.5 or randf() < 0.55       # dissolvenza a scatti, come una scarica
			dyn[id]["seen"] = lamp_t
		elif n is Projectile or n is PArrow or n is Pickup:
			if not dyn.has(id):
				var pm := MeshInstance3D.new()
				var lcol: Variant = _light_proj_col(n)
				if lcol != null:
					pm.mesh = _core_mesh()
					pm.add_child(W3DFx.halo(lcol as Color, 1.6))
				else:
					pm.mesh = _proj_mesh(n)
				pm.material_override = mat_chr
				var sc := 1.0
				if n is Pickup:
					sc = 0.6
				pm.scale = Vector3.ONE * sc
				vp.add_child(pm)
				dyn[id] = {"node": pm, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "fxm", "src": weakref(n), "lp": (n as Node2D).position, "imp": not (n is Pickup)}
				if lcol != null:
					dyn[id]["trail"] = W3DFx.Trail.new(vp, lcol as Color)
			var pn: Node3D = dyn[id]["node"]
			var n2 := n as Node2D
			pn.position = Vector3(n2.position.x / 16.0, 0.9, n2.position.y / 16.0)
			if n is Projectile or n is PArrow:
				pn.rotation.y = atan2(-(n as Node2D).transform.x.x, (n as Node2D).transform.x.y) if false else -n2.rotation - PI * 0.5
			else:
				pn.rotation.y += 0.2
				pn.position.y = 0.6 + sin(lamp_t * 6.0 + float(id % 7)) * 0.1
			if dyn[id].has("trail"):
				(dyn[id]["trail"] as W3DFx.Trail).push(pn.position)
			dyn[id]["seen"] = lamp_t
			dyn[id]["lp"] = n2.position
		elif n is Label:
			_sync_popup(n as Label)


## scritte fluttuanti (danni, popup): restano le etichette 2D del gioco (stesso font nitido dell'interfaccia),
## ma vengono posizionate sullo schermo proiettando il punto del mondo 3D
var pop_layer: CanvasLayer
var pop_nodes: Dictionary = {}


func _sync_popup(lb: Label) -> void:
	if pop_layer == null:
		pop_layer = CanvasLayer.new()
		pop_layer.layer = 6
		add_child(pop_layer)
	var id := lb.get_instance_id()
	var ov: Label
	if pop_nodes.has(id):
		ov = pop_nodes[id]["l"]
	else:
		ov = Label.new()
		ov.text = lb.text
		ov.theme = lb.theme
		ov.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for th in ["font", "font_size", "font_color", "font_outline_color", "outline_size", "line_spacing"]:
			pass
		ov.add_theme_font_override("font", lb.get_theme_font("font"))
		ov.add_theme_font_size_override("font_size", lb.get_theme_font_size("font_size"))
		ov.add_theme_color_override("font_color", lb.get_theme_color("font_color"))
		ov.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		ov.add_theme_constant_override("outline_size", 2)
		ov.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pop_layer.add_child(ov)
		pop_nodes[id] = {"l": ov, "src": weakref(lb)}
	var wp := Vector3(lb.position.x / 16.0 + 0.5, 1.6 + elev_at(lb.position.x / 16.0, lb.position.y / 16.0), lb.position.y / 16.0)
	var sp: Vector2 = cam.unproject_position(wp)
	# lo schermo dei livelli canvas e' 480x270 (scala del contenuto), non la risoluzione del 3D
	var k := pop_layer.get_viewport().get_visible_rect().size / Vector2(vp.size)
	ov.position = (sp * k - ov.size * 0.5).floor()
	ov.modulate.a = lb.modulate.a
	ov.visible = not cam.is_position_behind(wp)


func _popups_cleanup() -> void:
	for id in pop_nodes.keys():
		var d: Dictionary = pop_nodes[id]
		var sr = (d["src"] as WeakRef).get_ref()
		if sr == null or not is_instance_valid(sr):
			(d["l"] as Label).queue_free()
			pop_nodes.erase(id)


func _sync_slash() -> void:
	var p: Player = gm.player
	if p.atk_t > 0.0 and prev_atk <= 0.0 and p.atk_dur > 0.0:
		if not bool(Rpg.FAM[p.weapon()["f"]]["ranged"]):
			var reach := p.cur_reach / 16.0
			var arc := p.cur_arc
			var yaw := atan2(-p.face.x, -p.face.y)
			var sweep := maxf(0.2, arc * 0.9 - 0.2)
			for q in 2:
				var mi := MeshInstance3D.new()
				mi.mesh = crescent
				mi.material_override = mat_chr
				var sc := reach * (1.0 if q == 0 else 0.82)
				mi.scale = Vector3(sc, 1.0, sc)
				mi.position = Vector3(p.position.x / 16.0, 0.0, p.position.y / 16.0)
				mi.rotation.y = yaw - sweep
				vp.add_child(mi)
				var tw := create_tween()
				tw.tween_interval(0.0 if q == 0 else 0.04)
				tw.tween_property(mi, "rotation:y", yaw + sweep, 0.16)
				tw.parallel().tween_property(mi, "scale", Vector3(sc * 1.1, 0.0, sc * 1.1), 0.18)
				tw.tween_callback(mi.queue_free)
	prev_atk = p.atk_t


# ------------------------------------------------------------------ ciclo principale
## oggetti costruiti con le stesse funzioni del motore 3D originale (stesso stile del mondo che piaceva)
func _base_prop(kind: String, tw: float, th: float, sd: int) -> ArrayMesh:
	var o := W3DBuilder.new()
	var r := RandomNumberGenerator.new()
	r.seed = sd
	o.rn.seed = sd
	o.sat = 1.55
	o.con = 1.45
	var cols: Array = []
	var lamps: Array = []
	var z := Vector2.ZERO
	var sx := 1.0
	var sz2 := 1.0
	if kind.begins_with("roof_") or kind.begins_with("chapel_top") or kind.begins_with("smithy_top") or kind.begins_with("archive_top") 			or kind.begins_with("sanatorium_top") or kind.begins_with("mill_top") or kind.begins_with("cathedral_top"):
		_house(o, z, 0.0, r, cols, lamps)
		sx = tw / 4.5
		sz2 = th / 5.1
		if kind.begins_with("cathedral_top"):
			for q in 2:
				o.box(Transform3D(Basis.IDENTITY, Vector3((q * 2 - 1) * 2.2, 3.4, 2.6)), Vector3(1.2, 6.8, 1.2), Color(0.2, 0.19, 0.22), 0.1, 0)
				o.cyl(Transform3D(Basis.IDENTITY, Vector3((q * 2 - 1) * 2.2, 6.8, 2.6)), 0.9, 0.0, 2.2, 4, Color(0.12, 0.11, 0.14), 0.1)
	elif kind.begins_with("top_dead") or kind.begins_with("top_sick") or kind.begins_with("tbig_"):
		_dead_tree(o, z, r, cols)
		if kind.begins_with("tbig_"):
			sx = 1.35
			sz2 = 1.35
	elif kind.begins_with("barrel_top"):
		_barrel(o, z, r, cols)
	elif kind.begins_with("crate_top"):
		_crate(o, z, r, cols)
	elif kind.begins_with("hay_top"):
		_hay(o, z, r, cols)
	elif kind.begins_with("woodpile"):
		_woodpile(o, z, 0.0, r, cols)
	elif kind.begins_with("cart_top"):
		_cart(o, z, 0.0, r, cols)
	elif kind.begins_with("well_top"):
		_well(o, z, r, cols)
	elif kind.begins_with("lamp_top"):
		_lamp_post(o, z, lamps, cols)
	elif kind.begins_with("bonfire"):
		_pyre(o, z, r, cols, lamps)
	elif kind.begins_with("signpost"):
		_sign(o, z, 0.0, r, cols)
	elif kind.begins_with("bush_"):
		_bush(o, z, r, cols)
	elif kind.begins_with("log_top"):
		_fallen_log(o, z, r)
	elif kind.begins_with("ruin_tower"):
		_ruin(o, z, r, cols)
	elif kind.begins_with("mausoleum_top"):
		_mausoleum(o, z, 0.0, r, cols, lamps)
	elif kind.begins_with("grave_"):
		_grave_item(o, z, r, cols, lamps)
	else:
		return null
	if o.v.size() == 0:
		return null
	if sx != 1.0 or sz2 != 1.0:
		o.scale_xz(sx, sz2)
	return o.mesh()


# ------------------------------------------------------------------ mondo aperto: blocchi da 16x16 creati attorno al giocatore
const WSC := 16
var world_on := false
var world_zoom_far := false


func toggle_world_zoom() -> void:
	world_zoom_far = not world_zoom_far
	gm.say("VISUALE AMPIA" if world_zoom_far else "VISUALE VICINA")


## ------------------------------------------------------------------ quote del terreno
## Il suolo ha vere altezze: ogni bioma ha una quota di base (il cimitero e' su una collina, la cattedrale su un altopiano...), sfumata
## fra una regione e l'altra, con ondulazioni; piatta (a quota fissa) per villaggi e ingressi, scavata a valle lungo i fiumi.
## La mappa delle quote va alla GPU: lo shader solleva ogni vertice (terreno, case, alberi, personaggi) in base alla sua posizione.
const ELEV_BASE := [0.0, 1.6, 1.0, 0.0, 2.0, 5.0, 1.0]       # quota di base di ogni regione (sfumata)
const ELEV_ROUGH := [1.6, 7.5, 8.0, 0.8, 9.0, 17.0, 10.0]     # altezza dei rilievi (colline) di ogni regione
const EG := 8                      # passo della griglia grossa (celle)
const ET := 4                      # passo dei texel della mappa delle quote (celle)
var elev := PackedFloat32Array()
var elev_tw := 0
var elev_th := 0
var elev_ok := false
var elev_seed := -1
var elev_tex: ImageTexture
var g_w := 0
var g_h := 0
var g_base := PackedFloat32Array()
var g_rough := PackedFloat32Array()
var g_river := PackedFloat32Array()
var g_coast := PackedFloat32Array()
var elev_sites: Array = []
var n_elev := FastNoiseLite.new()


func _blur_grid(src: PackedFloat32Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(src.size())
	for j in g_h:
		for i in g_w:
			var s := 0.0
			var wsum := 0.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var qi := i + di
					var qj := j + dj
					if qi < 0 or qj < 0 or qi >= g_w or qj >= g_h:
						continue
					var wt := (2.0 - absf(di)) * (2.0 - absf(dj))
					s += src[qj * g_w + qi] * wt
					wsum += wt
			out[j * g_w + i] = s / wsum
	return out


func _gs(arr: PackedFloat32Array, cx: float, cz: float) -> float:
	var fx := clampf(cx / EG, 0.0, g_w - 1.001)
	var fz := clampf(cz / EG, 0.0, g_h - 1.001)
	var i0 := floori(fx)
	var j0 := floori(fz)
	var tx := smoothstep(0.0, 1.0, fx - i0)
	var tz := smoothstep(0.0, 1.0, fz - j0)
	var a := lerpf(arr[j0 * g_w + i0], arr[j0 * g_w + i0 + 1], tx)
	var b := lerpf(arr[(j0 + 1) * g_w + i0], arr[(j0 + 1) * g_w + i0 + 1], tx)
	return lerpf(a, b, tz)


func _elev_flatten_h(cx: float, cz: float) -> float:
	var rough := _gs(g_rough, cx, cz)
	# colline: cupole dove il rumore e' alto (a bassa frequenza: 25-40 celle di diametro), pianura altrove
	var shape := smoothstep(-0.05, 0.7, n_elev.get_noise_2d(cx, cz))
	var h := _gs(g_base, cx, cz) + shape * rough
	h *= _gs(g_river, cx, cz) * _gs(g_coast, cx, cz)
	return h


func _elev_build() -> void:
	if elev_ok and elev_seed == int(gm.world_seed):
		return
	var t0 := Time.get_ticks_msec()
	var W := Game.MW
	var H := Game.MH
	g_w = ceili(float(W) / EG) + 2
	g_h = ceili(float(H) / EG) + 2
	g_base.resize(g_w * g_h)
	g_rough.resize(g_w * g_h)
	g_river.resize(g_w * g_h)
	g_coast.resize(g_w * g_h)
	n_elev.seed = int(gm.world_seed) + 77
	n_elev.frequency = 0.03
	n_elev.fractal_octaves = 2
	n_elev.fractal_gain = 0.4
	var segs: Array = []
	for rv in gm.RIVERS:
		for k in (rv as Array).size() - 1:
			segs.append([Vector2((rv as Array)[k]), Vector2((rv as Array)[k + 1])])
	for j in g_h:
		for i in g_w:
			var cx := i * EG
			var cz := j * EG
			var b := clampi(gm.biome_at(mini(cx, W - 1), mini(cz, H - 1)), 0, ELEV_BASE.size() - 1)
			g_base[j * g_w + i] = ELEV_BASE[b]
			g_rough[j * g_w + i] = ELEV_ROUGH[b]
			# fiumi: a valle (quota 0) con sponde che salgono dolcemente
			var dr := 999.0
			var p := Vector2(cx, cz)
			for sg in segs:
				var a: Vector2 = sg[0]
				var bb: Vector2 = sg[1]
				var ab := bb - a
				var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				dr = minf(dr, p.distance_to(a + ab * tt))
			g_river[j * g_w + i] = smoothstep(8.0, 24.0, dr)
			# costa: l'isola scende a livello del mare
			var nxc := (cx - 480.0) / 538.0
			var nyc := (cz - 352.0) / 397.0
			g_coast[j * g_w + i] = 1.0 - smoothstep(0.78, 0.93, sqrt(nxc * nxc + nyc * nyc))
	for pass_i in 2:
		g_base = _blur_grid(g_base)
		g_rough = _blur_grid(g_rough)
	g_river = _blur_grid(g_river)
	elev_sites.clear()
	for pr in [[0, 31.0], [2, 14.0], [3, 14.0], [5, 12.0]]:
		var sc := Vector2(gm.SEEDS[int(pr[0])])
		elev_sites.append([sc, float(pr[1]), float(pr[1]) + 10.0, _elev_flatten_h(sc.x, sc.y)])
	for e in gm.ENTR.values():
		var ec := Vector2(e)
		elev_sites.append([ec, 5.0, 14.0, _elev_flatten_h(ec.x, ec.y)])
	elev_tw = ceili(float(W) / ET)
	elev_th = ceili(float(H) / ET)
	elev.resize(elev_tw * elev_th)
	for tj in elev_th:
		for ti in elev_tw:
			var cx2 := (ti + 0.5) * ET
			var cz2 := (tj + 0.5) * ET
			var h := _elev_flatten_h(cx2, cz2)
			for st in elev_sites:
				var sc2: Vector2 = st[0]
				var dx := cx2 - sc2.x
				var dz := cz2 - sc2.y
				var rb: float = st[2]
				if absf(dx) > rb or absf(dz) > rb:
					continue
				var f := 1.0 - smoothstep(float(st[1]), rb, sqrt(dx * dx + dz * dz))
				if f > 0.0:
					h = lerpf(h, float(st[3]), f)
			elev[tj * elev_tw + ti] = h
	var img := Image.create_from_data(elev_tw, elev_th, false, Image.FORMAT_RF, elev.to_byte_array())
	img.convert(Image.FORMAT_RH)
	elev_tex = ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("w3d_elev", elev_tex)
	elev_ok = true
	elev_seed = int(gm.world_seed)
	var mx := -99.0
	var mn := 99.0
	for hv in elev:
		mx = maxf(mx, hv)
		mn = minf(mn, hv)
	print("QUOTE: mappa %dx%d, quota %.2f..%.2f, calcolata in %d ms" % [elev_tw, elev_th, mn, mx, Time.get_ticks_msec() - t0])


## accende/spegne le quote negli shader (spente negli interni)
func _elev_set(on: bool) -> void:
	var s := 1.0 if (on and elev_ok) else 0.0
	RenderingServer.global_shader_parameter_set("w3d_elev_info", Vector4(1.0 / maxf(elev_tw * ET, 1.0), 1.0 / maxf(elev_th * ET, 1.0), s, 0.0))


## quota del terreno nel punto (coordinate in celle; 0 negli interni)
func elev_at(cx: float, cz: float) -> float:
	if not elev_ok or not world_on:
		return 0.0
	var fx := clampf(cx / ET - 0.5, 0.0, elev_tw - 1.001)
	var fz := clampf(cz / ET - 0.5, 0.0, elev_th - 1.001)
	var i0 := floori(fx)
	var j0 := floori(fz)
	var tx := fx - i0
	var tz := fz - j0
	var a := lerpf(elev[j0 * elev_tw + i0], elev[j0 * elev_tw + i0 + 1], tx)
	var b := lerpf(elev[(j0 + 1) * elev_tw + i0], elev[(j0 + 1) * elev_tw + i0 + 1], tx)
	return lerpf(a, b, tz)


## ------------------------------------------------------------------ suolo per pixel: mappa globale delle distanze dai sentieri
const GRES := 2                    # texel per cella
const GAME_ROAD_W := 1.9           # larghezza dichiarata al 3D: sotto 2.3, quindi senza i ciottoli della via principale
const GAME_ROAD_RANGE := 2.5       # oltre questa distanza dal bordo la strada non influisce piu' su suolo e natura
# aspetto delle vie: semilarghezza media, ondulazione laterale (celle) e pavimentazione
# (0 terra battuta, 0.6 selciato vecchio a chiazze, 1 selciato pieno: solo nel villaggio)
const MAIN_HALF := 1.2
const MAIN_WOBBLE := 0.3
const MAIN_PAVED := 0.6
const TRAIL_HALF := 0.74
const TRAIL_WOBBLE := 0.55
const VILLAGE_PAVED := 1.0
var game_road_sd := PackedFloat32Array()    # per texel: distanza con segno dal bordo delle strade della mappa di gioco
var game_road_paved := PackedByteArray()     # per texel: pavimentazione della via piu' vicina (0-255)
var n_road := FastNoiseLite.new()


## ------------------------------------------------------------------ oggetti 3D e strade della mappa
## Il motore 3D non conosce le strade di gioco quando dispone case e arredi. Le collisioni 3D sono quelle che fermano
## il giocatore: un oggetto che copre una cella stradale viene annullato per intero (mai visibile ma attraversabile).
## Il generatore casuale avanza comunque, quindi tutto il resto del mondo resta identico.
const GAME_ROAD_CLEAR := 0.4       # spazio libero attorno al centro di una cella strada (il giocatore ha raggio 0.25)
var road_guard := true
const LOGIC_PROBE := 0.15               # lo stesso raggio con cui il movimento saggia il centro di una cella
var landmarks_seen := 0                  # quanti oggetti delle zone unificate sono gia' noti al 3D
var landmarks_dirty: Dictionary = {}     # blocchi 3D da rifare perche' la logica vi ha aggiunto qualcosa dopo


## nelle aree riservate alla mappa il motore non mette lotti, alberi, cespugli o massi suoi
func _in_reserved(p: Vector2, margin := 0) -> bool:
	return world_on and not grid_road_fn.is_valid() and W3DLandmarks.reserved_for_map(gm, Vector2i((p + world_off).floor()), margin)


## nelle zone unificate le collisioni del blocco appena costruito valgono anche per la logica (nemici, oggetti, percorsi)
func _mirror_into_logic(k: Vector2i) -> void:
	var origin := Vector2(k * CHS) + world_off
	# tumuli e lapidi basse si scavalcano: dell'ingombro di un oggetto resta occupato solo cio' che ferma davvero
	var area_rect := Rect2(Vector2(k * CHS), Vector2(CHS, CHS))
	for entry: Dictionary in gm.landmarks:
		if not area_rect.has_point(W3DLandmarks.anchor(entry, world_off)):
			continue
		var footprint: Vector2i = entry["f"]
		for dy in footprint.y:
			for dx in footprint.x:
				var covered: Vector2i = (entry["c"] as Vector2i) + Vector2i(dx, dy)
				if gm.block.has(covered) and not _blocked(Vector2(covered) + Vector2(0.5, 0.5) - world_off, LOGIC_PROBE):
					gm.block.erase(covered)
	for y in range(floori(origin.y), floori(origin.y + CHS)):
		for x in range(floori(origin.x), floori(origin.x + CHS)):
			var cell := Vector2i(x, y)
			if gm.inb(cell) and W3DLandmarks.in_zone(gm, cell) and not gm.block.has(cell) and _blocked(Vector2(x + 0.5, y + 0.5) - world_off, LOGIC_PROBE):
				gm.block[cell] = true


func _free(p: Vector2, r: float, cols: Array) -> bool:
	if _in_reserved(p, 1):
		return false
	return super(p, r, cols)


## aggiunge al blocco in costruzione gli oggetti della logica che vi ricadono
func _finalize(j: Dictionary) -> void:
	if world_on and not grid_road_fn.is_valid():
		var o: W3DBuilder = j["o"]
		var area_rect := Rect2(float(j["x0"]), float(j["z0"]), CHS, CHS)
		var colour_state := o.rn.state
		var was_guarding := road_guard
		road_guard = false
		for entry: Dictionary in gm.landmarks:
			if area_rect.has_point(W3DLandmarks.anchor(entry, world_off)):
				W3DLandmarks.build(self, entry, o, j["cols"], j["lamps"])
		road_guard = was_guarding
		o.rn.state = colour_state
	var built: Vector2i = j["k"]
	super(j)
	if world_on and not grid_road_fn.is_valid():
		_mirror_into_logic(built)


## la logica completa le zone mentre si gioca: i blocchi 3D gia' costruiti vengono rifatti, uno per fotogramma
func _landmarks_update() -> void:
	if gm.landmarks.size() != landmarks_seen:
		for i in range(mini(landmarks_seen, gm.landmarks.size()), gm.landmarks.size()):
			var at := W3DLandmarks.anchor(gm.landmarks[i], world_off)
			landmarks_dirty[Vector2i(floori(at.x / CHS), floori(at.y / CHS))] = true
		landmarks_seen = gm.landmarks.size()
	for key: Vector2i in landmarks_dirty.keys():
		if job_keys.has(key):
			continue
		landmarks_dirty.erase(key)
		if chunks.has(key):
			_enqueue(key)
			break
const RELOCATE_STEPS := [2.0, 3.5, 5.0]     # di quanto si prova a spostare un oggetto che copre una strada (celle)
var relocated_count := 0
var removed_count := 0


## un oggetto spostato non deve compenetrare quelli gia' costruiti nello stesso blocco
func _overlaps_earlier(cols: Array, from: int) -> bool:
	for i in range(from, cols.size()):
		var center: Vector2 = cols[i][1]
		for j in from:
			if _col_hit(cols[j], center, 0.35):
				return true
	return false
const PLAYABLE_SCENE_PROPS := ["page", "loot", "gate_top"]


## oggetti di gioco da disegnare in 3D; pagine, bottino e cancelli sono creati come arredo (setup_top) ma servono al gioco
func _is_game_prop(p: Prop) -> bool:
	return not bool(p.scene) or str(p.kind) in PLAYABLE_SCENE_PROPS
## Il villaggio e' quello disegnato dal motore 3D, con le sue vie: qui dentro le strade della mappa (che seguono il
## vecchio schema 2D a croce) non vengono disegnate e non tolgono oggetti. Semiassi della cinta, in celle.
const VILLAGE_KEEP := Vector2i(28, 22)


## L'uscita dalle celle resta una collina senza strade. Oltre il raggio la strada della mappa affiora a tratti,
## sempre piu' fitta, come un sentiero che si perde.
const EXIT_KEEP := 24.0
const EXIT_FADE := 10.0


## celle in cui il 3D resta com'e': le strade della mappa non si vedono e non tolgono oggetti
func _road_hidden(cell: Vector2i) -> bool:
	if _in_village(cell):
		return true
	var from_exit := Vector2(cell - (gm.ENTR["d0"] as Vector2i)).length()
	if from_exit >= EXIT_KEEP + EXIT_FADE:
		return false
	return from_exit < EXIT_KEEP or _hash2(cell.x / 2, cell.y / 2, 91) > (from_exit - EXIT_KEEP) / EXIT_FADE


func _in_village(cell: Vector2i) -> bool:
	var d: Vector2i = cell - gm.SEEDS[0]
	return absi(d.x) <= VILLAGE_KEEP.x and absi(d.y) <= VILLAGE_KEEP.y


func _covers_game_road(cols: Array, from: int) -> bool:
	for i in range(from, cols.size()):
		var cl: Array = cols[i]
		var center: Vector2 = cl[1]
		var reach: float = (float(cl[2]) if cl[0] == "c" else (cl[2] as Vector2).length()) + GAME_ROAD_CLEAR
		var gc := center + world_off
		for y in range(floori(gc.y - reach), floori(gc.y + reach) + 1):
			for x in range(floori(gc.x - reach), floori(gc.x + reach) + 1):
				var cell := Vector2i(x, y)
				if not gm.inb(cell) or gm.road[y * Game.MW + x] == 0 or gm.bridge[y * Game.MW + x] == 1 or _road_hidden(cell):
					continue
				if _col_hit(cl, Vector2(x + 0.5, y + 0.5) - world_off, GAME_ROAD_CLEAR):
					return true
	return false


func _build_mark(builders: Array, cols: Array, lamps: Array) -> Dictionary:
	var sizes: Array = []
	for b: W3DBuilder in builders:
		sizes.append([b.v.size(), b.reg.size(), b.breakables.size(), b.smokes.size()])
	return {"builders": sizes, "cols": cols.size(), "lamps": lamps.size(), "doors": house_doors.keys()}


func _build_rollback(mark: Dictionary, builders: Array, cols: Array, lamps: Array) -> void:
	for n in builders.size():
		var b: W3DBuilder = builders[n]
		var sizes: Array = mark["builders"][n]
		b.v.resize(sizes[0])
		b.c.resize(sizes[0])
		b.reg.resize(sizes[1])
		b.breakables.resize(sizes[2])
		b.smokes.resize(sizes[3])
	cols.resize(mark["cols"])
	lamps.resize(mark["lamps"])
	var before: Array = mark["doors"]
	for key in house_doors.keys():
		if not before.has(key):
			house_doors.erase(key)


func _guarding_roads() -> bool:
	return road_guard and world_on and not grid_road_fn.is_valid()


func _obj(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	if not _guarding_roads():
		super(k, o, p, yaw, r, cols, lamps)
		return
	var mark := _build_mark([o], cols, lamps)
	var state_before := r.state
	var colour_before := o.rn.state
	super(k, o, p, yaw, r, cols, lamps)
	if not _covers_game_road(cols, mark["cols"]):
		return
	# le estrazioni successive devono restare quelle della prima costruzione, ovunque finisca l'oggetto
	var state_after := r.state
	var colour_after := o.rn.state
	_build_rollback(mark, [o], cols, lamps)
	for shift: float in RELOCATE_STEPS:
		for a in 8:
			var q := p + Vector2.from_angle(TAU * a / 8.0) * shift
			if (edge_fn.is_valid() and bool(edge_fn.call(q))) or _clear_at(q, 1.0):
				continue
			r.state = state_before
			o.rn.state = colour_before
			super(k, o, q, yaw, r, cols, lamps)
			if not _covers_game_road(cols, mark["cols"]) and not _overlaps_earlier(cols, mark["cols"]):
				r.state = state_after
				o.rn.state = colour_after
				relocated_count += 1
				return
			_build_rollback(mark, [o], cols, lamps)
	r.state = state_after
	o.rn.state = colour_after
	removed_count += 1


## recinti, cataste e campi non passano da _obj: se coprono una strada si rinuncia all'intero lotto
func _lot(j: Dictionary, ix: int, iz: int) -> void:
	if _in_reserved(Vector2((ix + 0.5) * LC, (iz + 0.5) * LC), 3):
		return
	if not _guarding_roads():
		super(j, ix, iz)
		return
	var builders: Array = [j["o"], j["v"]]
	var cols: Array = j["cols"]
	var mark := _build_mark(builders, cols, j["lamps"])
	super(j, ix, iz)
	if _covers_game_road(cols, mark["cols"]):
		_build_rollback(mark, builders, cols, j["lamps"])


func _ed_apply(j: Dictionary) -> void:
	road_guard = false      # gli oggetti messi a mano con l'editor restano dove sono
	super(j)
	road_guard = true


var village_links: Array[Vector2i] = []     # celle dei raccordi fra le strade della mappa e le vie del villaggio


## le strade della mappa si fermano alla cinta: da li' un breve raccordo raggiunge la via del villaggio piu' vicina
func _village_link_paths() -> Array:
	var out: Array = []
	for id in gm.road_paths:
		if id is String:
			continue                # solo le vie principali (indici di ROADS)
		var path: Array = gm.road_paths[id]
		if path.is_empty():
			continue
		if _in_village(path[path.size() - 1]):
			path = path.duplicate()
			path.reverse()
		if not _in_village(path[0]):
			continue
		for cell: Vector2i in path:
			if _in_village(cell):
				continue
			var from := Vector2(cell) + Vector2(0.5, 0.5) - world_off
			var target := from
			var best := INF
			for n in segs_a.size():
				var point := Geometry2D.get_closest_point_to_segment(from, segs_a[n], segs_b[n])
				if from.distance_squared_to(point) < best:
					best = from.distance_squared_to(point)
					target = point
			var end := Vector2i((target + world_off).floor())
			var link: Array = [cell]
			link.append_array(gm.carve_path_peek(cell, end))
			out.append(link)
			break
	return out


## strade e sentieri della mappa di gioco, calcolati una volta sola. Si disegnano dagli ASSI delle vie, lisciati e resi
## irregolari: le celle della logica (a scalini, con celle sparse ai lati) darebbero bordi a quadretti.
func _game_roads_build() -> void:
	var t0 := Time.get_ticks_msec()
	var texels: int = Game.MW * GRES * Game.MH * GRES
	game_road_sd.resize(texels)
	game_road_sd.fill(99.0)
	game_road_paved.resize(texels)
	game_road_paved.fill(0)
	n_road.seed = int(gm.world_seed) + 211
	n_road.frequency = 0.09
	n_road.fractal_octaves = 2
	var links := _village_link_paths()
	village_links = []
	for link in links:
		village_links.append_array(link)
	var count := 0
	# prima i sentieri, poi le vie principali: agli incroci la pavimentazione e' quella della via principale
	for id in gm.road_paths:
		if id is String:
			count += _road_ribbon(gm.road_paths[id], TRAIL_HALF, TRAIL_WOBBLE, 0.0)
	for trail: Array in gm.trails:
		count += _road_ribbon(trail, TRAIL_HALF * 1.1, TRAIL_WOBBLE, 0.0)
	for id in gm.road_paths:
		if id is int:
			count += _road_ribbon(gm.road_paths[id], MAIN_HALF, MAIN_WOBBLE, MAIN_PAVED)
	for link: Array in links:
		count += _road_ribbon(link, MAIN_HALF * 0.9, MAIN_WOBBLE, MAIN_PAVED)
	if gm.testing:
		print("W3D strade della mappa: tratti=", count, " ms=", Time.get_ticks_msec() - t0)


## asse morbido di una via: media mobile sugli scalini, un punto ogni tre celle, ondulazione e angoli arrotondati
func _road_axis(cells: Array, wobble: float) -> PackedVector2Array:
	var n := cells.size()
	var coarse := PackedVector2Array()
	var i := 0
	while true:
		var reach := mini(4, mini(i, n - 1 - i))
		var total := Vector2.ZERO
		for d in range(-reach, reach + 1):
			total += Vector2(cells[i + d])
		coarse.append(total / (reach * 2 + 1) + Vector2(0.5, 0.5))
		if i == n - 1:
			break
		i = mini(i + 3, n - 1)
	for k in range(1, coarse.size() - 1):
		var side := (coarse[k + 1] - coarse[k - 1]).orthogonal().normalized()
		coarse[k] += side * n_road.get_noise_2d(coarse[k].x * 1.7, coarse[k].y * 1.7) * wobble * 2.0
	if coarse.size() < 3:
		return coarse
	var out := PackedVector2Array([coarse[0]])
	for k in coarse.size() - 1:
		out.append(coarse[k].lerp(coarse[k + 1], 0.25))
		out.append(coarse[k].lerp(coarse[k + 1], 0.75))
	out.append(coarse[coarse.size() - 1])
	return out


## stampa una via nel campo delle distanze; la larghezza varia lungo il percorso
func _road_ribbon(cells: Array, half: float, wobble: float, paved: float) -> int:
	if cells.size() < 2:
		return 0
	var axis := _road_axis(cells, wobble)
	var w: int = Game.MW
	var tw := w * GRES
	var th: int = Game.MH * GRES
	var paint := int(paved * 255.0)
	var stamped := 0
	for s in axis.size() - 1:
		var a := axis[s]
		var b := axis[s + 1]
		var mid := Vector2i(((a + b) * 0.5).floor())
		# sui ponti e sull'acqua non si disegna (i ponti hanno le loro assi); villaggio e collina restano del 3D
		if not gm.inb(mid) or gm.water[gm.idx(mid)] == 1 or gm.bridge[gm.idx(mid)] == 1 or _road_hidden(mid):
			continue
		var wide_a := half * (1.0 + 0.45 * n_road.get_noise_2d(a.x * 2.3 + 90.0, a.y * 2.3))
		var wide_b := half * (1.0 + 0.45 * n_road.get_noise_2d(b.x * 2.3 + 90.0, b.y * 2.3))
		var reach := maxf(wide_a, wide_b) + GAME_ROAD_RANGE
		var ab := b - a
		var len2 := maxf(ab.length_squared(), 0.0001)
		var x0 := maxi(0, floori((minf(a.x, b.x) - reach) * GRES))
		var x1 := mini(tw - 1, ceili((maxf(a.x, b.x) + reach) * GRES))
		var z0 := maxi(0, floori((minf(a.y, b.y) - reach) * GRES))
		var z1 := mini(th - 1, ceili((maxf(a.y, b.y) + reach) * GRES))
		for tz in range(z0, z1 + 1):
			var row := tz * tw
			for tx in range(x0, x1 + 1):
				var q := Vector2((tx + 0.5) / GRES, (tz + 0.5) / GRES)
				var t := clampf((q - a).dot(ab) / len2, 0.0, 1.0)
				var sd := q.distance_to(a + ab * t) - lerpf(wide_a, wide_b, t)
				if sd >= GAME_ROAD_RANGE:
					continue
				var ti := row + tx
				if sd < game_road_sd[ti]:
					game_road_sd[ti] = sd
					game_road_paved[ti] = paint
				elif paint > game_road_paved[ti] and sd < 0.2:
					game_road_paved[ti] = paint
		stamped += 1
	return stamped


## distanza con segno dal bordo della strada di gioco piu' vicina (99 se lontana); p in coordinate del motore 3D
func _game_road_dist(p: Vector2) -> float:
	var tx := floori((p.x + world_off.x) * GRES)
	var tz := floori((p.y + world_off.y) * GRES)
	var tw: int = Game.MW * GRES
	if tx < 0 or tz < 0 or tx >= tw or tz >= Game.MH * GRES or game_road_sd.is_empty():
		return 99.0
	return game_road_sd[tz * tw + tx]


## suolo, erba, sassi, alberi e rilievi evitano sia le vie del motore 3D sia le strade della mappa di gioco.
## Case e lotti usano _road_near e restano disposti come prima.
func _road_dist_sub(p: Vector2, sub: Array) -> Vector2:
	var base := super(p, sub)
	if not world_on or grid_road_fn.is_valid():
		return base
	if base.y > 2.3 and not _in_village(Vector2i((p + world_off).floor())):
		base = Vector2(base.x - base.y * 0.5 + 1.125, 2.25)      # stesso bordo, senza i ciottoli in rilievo
	var sd := _game_road_dist(p)
	if sd < base.x - base.y * 0.5:
		return Vector2(sd + GAME_ROAD_W * 0.5, GAME_ROAD_W)
	return base
var gmap_img: Image
var gmap_tex: ImageTexture
var gmap_w := 0
var gmap_h := 0
var gmap_dirty := false


func _gmap_init() -> void:
	gmap_w = Game.MW * GRES
	gmap_h = Game.MH * GRES
	gmap_img = Image.create(gmap_w, gmap_h, false, Image.FORMAT_RG8)
	gmap_img.fill(Color(1, 0, 0, 1))
	gmap_tex = ImageTexture.create_from_image(gmap_img)
	if mat_ground == null:
		mat_ground = ShaderMaterial.new()
		mat_ground.shader = load("res://shaders/w3d_ground.gdshader")
	mat_ground.set_shader_parameter("gmap", gmap_tex)
	mat_ground.set_shader_parameter("gmap_inv", Vector2(1.0 / Game.MW, 1.0 / Game.MH))
	mat_ground.set_shader_parameter("boost", 0.27)
	mat_ground.set_shader_parameter("sat_k", 1.25)


func _gmap_fill(j: Dictionary) -> void:
	if gmap_img == null or not world_on:
		return
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var sub: Array = j["sub"]
	var tx0 := ceili((x0 + world_off.x) * GRES - 0.5)
	var tx1 := ceili((x0 + CHS + world_off.x) * GRES - 0.5)
	var tz0 := ceili((z0 + world_off.y) * GRES - 0.5)
	var tz1 := ceili((z0 + CHS + world_off.y) * GRES - 0.5)
	for tz in range(tz0, tz1):
		if tz < 0 or tz >= gmap_h:
			continue
		for tx in range(tx0, tx1):
			if tx < 0 or tx >= gmap_w:
				continue
			var pe := Vector2((tx + 0.5) / GRES - world_off.x, (tz + 0.5) / GRES - world_off.y)
			if edge_fn.is_valid() and bool(edge_fn.call(pe)):
				gmap_img.set_pixel(tx, tz, Color(1.0, 0, 0, 1))      # fuori dall'isola (il vuoto scuro): niente sentiero
				continue
			var rdv := _road_dist_sub(pe, sub)
			var sd: float = rdv.x - rdv.y * 0.5
			var paved := VILLAGE_PAVED if _in_village(Vector2i(floori((tx + 0.5) / GRES), floori((tz + 0.5) / GRES))) else 0.0
			var ti := tz * gmap_w + tx
			if not game_road_sd.is_empty() and game_road_sd[ti] <= sd + 0.001:
				paved = game_road_paved[ti] / 255.0
			gmap_img.set_pixel(tx, tz, Color(clampf(sd / 8.0 + 0.5, 0.0, 1.0), paved, 0, 1))
	gmap_dirty = true


func _world_clear() -> void:
	for c in static_root.get_children():
		c.queue_free()


var world_off := Vector2.ZERO
var fixed_cam := false
var ed: W3DEdit                  # editor del mondo (F12)
var fut: W3DFuture               # intrusioni del futuro (cambiano con Chrono.tech)
var near_props: Array = []       # prop funzionali vicini al giocatore (ricalcolati ogni pochi fotogrammi)
var near_props_t := 0
var side_scroll_temporal_root: Node3D
var side_scroll_temporal_ufo: Node3D
var side_scroll_temporal_bubble: Node3D
var side_scroll_temporal_drops: Array[Node3D] = []
var side_scroll_temporal_center := Vector2.ZERO
var side_scroll_temporal_ground := 0.0
var side_scroll_temporal_smoke_next := 0.0
var side_scroll_temporal_laser_root: Node3D
var side_scroll_temporal_laser_parts: Dictionary = {}
var perf_on := OS.get_cmdline_user_args().has("--perf")
var perf_n := 0
var lamp_n := 0.0
var perf_proc := 0.0
var steady_clock := 0.0
var steady_n := 0
var steady_sum := 0.0
var perf_phys := 0.0
var no2d_done := false
var sharp_layer: CanvasLayer
var test_done := false
var bub_shot_t := -1.0
var bub_shot_n := 0
var perf_t := 0.0
var perf_max := 0.0
var wframe := 0


## il mondo aperto e' generato dal motore 3D originale (stesse strade, case, cimiteri, erba), spostato sul mondo di gioco
var doors_seen: Dictionary = {}
var mm_t := 0.0


## true se il punto (coordinate del motore 3D) cade fuori dall'isola di gioco
func _edge_game(p: Vector2) -> bool:
	var c := Vector2i(floori(p.x + world_off.x), floori(p.y + world_off.y))
	if not gm.inb(c):
		return true
	var ei: int = gm.idx(c)
	return gm.outside[ei] == 1 and gm.grid[ei] == 0 and gm.gen_chunks.has(Vector2i(c.x / gm.CH, c.y / gm.CH))


## minimappa del mondo 3D: strade, case e bordo dell'isola nella finestra di 70x50 celle attorno al giocatore
func _update_minimap() -> void:
	var W: int = Game.MW
	var H: int = Game.MH
	var cw := mini(70, W)
	var ch := mini(50, H)
	var pc := Vector2i(floori(gm.player.position.x / 16.0), floori(gm.player.position.y / 16.0))
	var ox := clampi(pc.x - cw / 2, 0, W - cw)
	var oy := clampi(pc.y - ch / 2, 0, H - ch)
	var im := Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.07, 0.065, 0.07))
	for y in ch:
		for x in cw:
			var c := Vector2i(ox + x, oy + y)
			if gm.outside[gm.idx(c)] == 1 and gm.grid[gm.idx(c)] == 0 and gm.gen_chunks.has(Vector2i(c.x / gm.CH, c.y / gm.CH)):
				im.set_pixel(x, y, Color(0.02, 0.05, 0.08))
	for i in segs_a.size():
		var a: Vector2 = segs_a[i] + world_off - Vector2(ox, oy)
		var b: Vector2 = segs_b[i] + world_off - Vector2(ox, oy)
		if maxf(a.x, b.x) < -2 or minf(a.x, b.x) > cw + 2 or maxf(a.y, b.y) < -2 or minf(a.y, b.y) > ch + 2:
			continue
		var steps := int(a.distance_to(b) * 1.5) + 1
		var hw := maxi(0, int(segs_w[i] * 0.5))
		for q in steps + 1:
			var pt := a.lerp(b, float(q) / steps)
			for dy in range(-hw, hw + 1):
				for dx in range(-hw, hw + 1):
					var px := int(pt.x) + dx
					var py := int(pt.y) + dy
					if px >= 0 and py >= 0 and px < cw and py < ch and not (gm.outside[gm.idx(Vector2i(ox + px, oy + py))] == 1 and gm.grid[gm.idx(Vector2i(ox + px, oy + py))] == 0):
						im.set_pixel(px, py, Color(0.5, 0.45, 0.36))
	for y in ch:
		for x in cw:
			var ri: int = gm.idx(Vector2i(ox + x, oy + y))
			if gm.road[ri] == 1 and gm.water[ri] == 0 and not _road_hidden(Vector2i(ox + x, oy + y)):
				im.set_pixel(x, y, Color(0.5, 0.45, 0.36))
	for key in house_doors:
		var dv: Vector3 = house_doors[key]
		var hp := Vector2(dv.x, dv.y) + world_off - Vector2(ox, oy)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var px2 := int(hp.x) + dx
				var py2 := int(hp.y) + dy
				if px2 >= 0 and py2 >= 0 and px2 < cw and py2 < ch:
					im.set_pixel(px2, py2, Color(0.55, 0.32, 0.2))
	gm.mm3d = ImageTexture.create_from_image(im)


## le case generate dal motore 3D hanno una porta vera: diventa un ingresso per l'interno
func _sync_doors() -> void:
	for key in house_doors:
		if doors_seen.has(key):
			continue
		doors_seen[key] = true
		var dv: Vector3 = house_doors[key]
		var gp := Vector2(dv.x, dv.y) + world_off
		var dest := "int|house|%d|%d" % [roundi(gp.x), roundi(gp.y)]
		var out := gp + Vector2(cos(dv.z), -sin(dv.z)) * 2.4
		gm.doors.append({"pos": gp * 16.0, "hw": 0.0, "dest": dest, "cell": Vector2i(floori(out.x), floori(out.y)), "r": true})


func _world_update() -> void:
	_landmarks_update()
	if gmap_dirty and gmap_tex != null:
		gmap_tex.update(gmap_img)
		gmap_dirty = false
	_sync_doors()
	var sp := pos
	pos = sp - world_off
	wframe += 1
	if wframe % 5 == 1:
		_stream(false)
	_run_jobs(45.0 if job_boost else (12.0 if fpv else (6.0 if not pins.is_empty() else 3.5)))
	pos = sp
	for k in chunks:
		var nd: Node3D = chunks[k]["node"]
		if not nd.has_meta("off"):
			nd.position = Vector3(world_off.x, 0.0, world_off.y)
			nd.set_meta("off", true)


func _world_prop_key(p: Vector2) -> String:
	return "w3d:%d,%d" % [roundi(p.x * 100.0), roundi(p.y * 100.0)]


func side_scroll_props_begin() -> void:
	side_scroll_prop_changes.clear()
	side_scroll_dirty_chunks.clear()


func side_scroll_props_restore() -> void:
	if side_scroll_prop_changes.is_empty():
		return
	var broken: Dictionary = gm.persist.get("broken", {})
	var hp_map: Dictionary = gm.persist.get("w3d_hp", {})
	for key in side_scroll_prop_changes:
		var saved: Dictionary = side_scroll_prop_changes[key]
		if bool(saved["broken"]):
			broken[key] = true
		else:
			broken.erase(key)
		if bool(saved["has_hp"]):
			hp_map[key] = saved["hp"]
		else:
			hp_map.erase(key)
		var hidden_key: Vector2i = saved["hidden_key"]
		if bool(saved["hidden"]):
			ed_hide_keys[hidden_key] = true
		else:
			ed_hide_keys.erase(hidden_key)
	gm.persist["broken"] = broken
	gm.persist["w3d_hp"] = hp_map
	for ck in side_scroll_dirty_chunks:
		_rebuild_world_chunk(ck)
	if not side_scroll_dirty_chunks.is_empty():
		_run_jobs(3.0)
	side_scroll_prop_changes.clear()
	side_scroll_dirty_chunks.clear()


func side_scroll_temporal_begin(center: Vector2) -> void:
	side_scroll_temporal_clear()
	side_scroll_temporal_center = center
	side_scroll_temporal_ground = elev_at(center.x, center.y)
	side_scroll_temporal_root = Node3D.new()
	side_scroll_temporal_root.name = "TemporalClearing"
	vp.add_child(side_scroll_temporal_root)
	side_scroll_temporal_bubble = null
	side_scroll_temporal_smoke_next = 0.0
	post_mat.set_shader_parameter("fisheye", TEMPORAL_FISHEYE)
	var ufo_mesh_instance := MeshInstance3D.new()
	ufo_mesh_instance.mesh = W3DCine.ufo_mesh()
	ufo_mesh_instance.material_override = _side_scroll_temporal_material(mat_prop)
	ufo_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	ufo_mesh_instance.scale = Vector3.ONE * 0.8
	ufo_mesh_instance.position = Vector3(center.x, side_scroll_temporal_ground + TEMPORAL_UFO_HEIGHT, center.y)
	side_scroll_temporal_root.add_child(ufo_mesh_instance)
	side_scroll_temporal_ufo = ufo_mesh_instance


func _side_scroll_temporal_material(source: ShaderMaterial) -> ShaderMaterial:
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("side_cut_exempt", 1.0)
	return material


func side_scroll_temporal_add_drop(kind: String, target: Vector2, is_weapon: bool) -> Dictionary:
	if side_scroll_temporal_root == null or not W3DChrono.has(kind):
		return {}
	var visual := Node3D.new()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = W3DChrono.mesh(kind)
	mesh_instance.material_override = _side_scroll_temporal_material(mat_prop)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(mesh_instance)
	visual.position = Vector3(side_scroll_temporal_center.x, 8.2, side_scroll_temporal_center.y)
	side_scroll_temporal_root.add_child(visual)
	side_scroll_temporal_drops.append(visual)
	var bubble := Node3D.new()
	bubble.name = "TemporalDropBubble"
	bubble.position = visual.position
	bubble.visible = false
	bubble.set_meta("rig", _make_bubble_rig(bubble, Color(0.5, 0.85, 1.0)))
	side_scroll_temporal_root.add_child(bubble)
	side_scroll_temporal_drops.append(bubble)
	var shadow := Node3D.new()
	var shadow_color := Color(0.25, 1.0, 0.5) if is_weapon else Color(1.0, 0.14, 0.1)
	var fill_mesh := CylinderMesh.new()
	fill_mesh.top_radius = 1.6
	fill_mesh.bottom_radius = 1.6
	fill_mesh.height = 0.025
	fill_mesh.radial_segments = 96
	var fill := MeshInstance3D.new()
	fill.mesh = fill_mesh
	var fill_material := StandardMaterial3D.new()
	fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	fill_material.albedo_color = Color(shadow_color.r, shadow_color.g, shadow_color.b, 0.035)
	fill_material.emission_enabled = true
	fill_material.emission = shadow_color
	fill_material.emission_energy_multiplier = 0.08
	fill.material_override = fill_material
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.add_child(fill)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.08
	ring_mesh.outer_radius = 2.25
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 96
	var ring := MeshInstance3D.new()
	ring.mesh = ring_mesh
	var ring_material := fill_material.duplicate() as StandardMaterial3D
	ring_material.albedo_color = Color(shadow_color.r, shadow_color.g, shadow_color.b, 0.16)
	ring_material.emission_energy_multiplier = 0.18
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.add_child(ring)
	shadow.set_meta("fill_material", fill_material)
	shadow.set_meta("ring_material", ring_material)
	shadow.set_meta("is_weapon", is_weapon)
	shadow.position = Vector3(target.x, elev_at(target.x, target.y) + 0.05, target.y)
	shadow.visible = false
	side_scroll_temporal_root.add_child(shadow)
	side_scroll_temporal_drops.append(shadow)
	return {"visual": visual, "shadow": shadow, "bubble": bubble}


func side_scroll_temporal_update_bubble(bubble: Node3D, at: Vector3, radius: float, time: float, shown: bool) -> void:
	if not is_instance_valid(bubble):
		return
	bubble.position = at
	bubble.visible = shown and radius > 0.03
	var rig: Dictionary = bubble.get_meta("rig", {})
	if not rig.is_empty():
		_animate_bubble_rig(rig, radius, time, 1.0)


func side_scroll_temporal_remove_drop(visual: Node3D, shadow: Node3D, bubble: Node3D = null) -> void:
	for node in [visual, shadow, bubble]:
		side_scroll_temporal_drops.erase(node)
		if is_instance_valid(node):
			node.queue_free()


func side_scroll_temporal_update_shadow(shadow: Node3D, target: Vector2, warning: float, time: float) -> void:
	if not is_instance_valid(shadow):
		return
	shadow.position = Vector3(target.x, elev_at(target.x, target.y) + 0.05, target.y)
	shadow.visible = warning >= 0.3
	var pulse := 0.55 + absf(sin(time * 8.0)) * 0.45
	var alpha := lerpf(0.03, 0.22, warning) * pulse
	var fill_material := shadow.get_meta("fill_material") as StandardMaterial3D
	var ring_material := shadow.get_meta("ring_material") as StandardMaterial3D
	var color := Color(0.25, 1.0, 0.5) if bool(shadow.get_meta("is_weapon")) else Color(1.0, 0.14, 0.1)
	fill_material.albedo_color = Color(color.r, color.g, color.b, alpha * 0.2)
	ring_material.albedo_color = Color(color.r, color.g, color.b, alpha)
	shadow.scale = Vector3.ONE * (1.05 + pulse * 0.15)


func side_scroll_temporal_add_shot(family: String, start: Vector3) -> Node3D:
	if side_scroll_temporal_root == null:
		return null
	var shot := Node3D.new()
	shot.position = start
	var body_material := _temporal_projectile_material(Color(0.24, 0.29, 0.22), Color(0.0, 0.0, 0.0))
	var metal_material := _temporal_projectile_material(Color(0.75, 0.7, 0.47), Color(0.0, 0.0, 0.0))
	match family:
		"rocket":
			_temporal_projectile_piece(shot, _temporal_cylinder(0.18, 0.9), Vector3.ZERO, Vector3(-PI * 0.5, 0.0, 0.0), body_material)
			_temporal_projectile_piece(shot, _temporal_cone(0.19, 0.35), Vector3(0.0, 0.0, -0.61), Vector3(-PI * 0.5, 0.0, 0.0), metal_material)
			_temporal_projectile_piece(shot, _temporal_cone(0.11, 0.42), Vector3(0.0, 0.0, 0.62), Vector3(PI * 0.5, 0.0, 0.0), _temporal_projectile_material(Color(1.0, 0.34, 0.08), Color(1.0, 0.16, 0.025)))
			for side in [-1.0, 1.0]:
				_temporal_projectile_piece(shot, _temporal_box(Vector3(0.32, 0.035, 0.22)), Vector3(side * 0.18, 0.0, 0.28), Vector3.ZERO, body_material)
		"shotgun":
			_temporal_projectile_piece(shot, _temporal_cylinder(0.13, 0.52), Vector3.ZERO, Vector3(-PI * 0.5, 0.0, 0.0), _temporal_projectile_material(Color(0.68, 0.12, 0.08), Color(0.32, 0.025, 0.01)))
			_temporal_projectile_piece(shot, _temporal_cylinder(0.14, 0.12), Vector3(0.0, 0.0, -0.24), Vector3(-PI * 0.5, 0.0, 0.0), metal_material)
			_temporal_projectile_piece(shot, _temporal_cylinder(0.11, 0.09), Vector3(0.0, 0.0, 0.29), Vector3(-PI * 0.5, 0.0, 0.0), metal_material)
		"plasma":
			var plasma_material := _temporal_projectile_material(Color(0.28, 0.24, 0.72), Color(0.28, 0.12, 1.0))
			var core_material := _temporal_projectile_material(Color(0.75, 0.96, 1.0), Color(0.24, 0.9, 1.0))
			_temporal_projectile_piece(shot, _temporal_cylinder(0.16, 0.72), Vector3.ZERO, Vector3(-PI * 0.5, 0.0, 0.0), plasma_material)
			_temporal_projectile_piece(shot, _temporal_cone(0.2, 0.38), Vector3(0.0, 0.0, -0.48), Vector3(-PI * 0.5, 0.0, 0.0), core_material)
			_temporal_projectile_piece(shot, _temporal_box(Vector3(0.56, 0.045, 0.055)), Vector3.ZERO, Vector3.ZERO, core_material)
			_temporal_projectile_piece(shot, _temporal_box(Vector3(0.045, 0.56, 0.055)), Vector3.ZERO, Vector3.ZERO, core_material)
		_:
			return null
	side_scroll_temporal_root.add_child(shot)
	side_scroll_temporal_drops.append(shot)
	return shot


func _temporal_projectile_piece(parent: Node3D, mesh: Mesh, position: Vector3, rotation: Vector3, material: StandardMaterial3D) -> void:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = position
	piece.rotation = rotation
	piece.material_override = material
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(piece)


func _temporal_projectile_material(color: Color, emission: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	if emission != Color(0.0, 0.0, 0.0):
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.7
	return material


func _temporal_cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _temporal_cone(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = 0.0
	mesh.height = height
	mesh.radial_segments = 8
	return mesh


func _temporal_box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func side_scroll_temporal_update_shot(shot: Node3D, position: Vector3, direction: Vector3) -> void:
	if is_instance_valid(shot):
		shot.position = position
		if direction.length_squared() > 0.001:
			var up := Vector3.FORWARD if absf(direction.normalized().dot(Vector3.UP)) > 0.95 else Vector3.UP
			shot.look_at(position + direction, up)


func side_scroll_temporal_remove_shot(shot: Node3D) -> void:
	side_scroll_temporal_drops.erase(shot)
	if is_instance_valid(shot):
		shot.queue_free()


func _temporal_laser_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b)
	material.emission_energy_multiplier = 1.8
	return material


func side_scroll_temporal_update_laser(start: Vector3, end: Vector3, time: float, charge: float, active: bool) -> void:
	if not is_instance_valid(side_scroll_temporal_root):
		return
	if not is_instance_valid(side_scroll_temporal_laser_root):
		side_scroll_temporal_laser_root = Node3D.new()
		side_scroll_temporal_laser_root.name = "TemporalLaser"
		side_scroll_temporal_root.add_child(side_scroll_temporal_laser_root)
		var unit_beam := CylinderMesh.new()
		unit_beam.top_radius = 1.0
		unit_beam.bottom_radius = 1.0
		unit_beam.height = 1.0
		unit_beam.radial_segments = 48
		for key in ["outer", "core"]:
			var beam := MeshInstance3D.new()
			beam.mesh = unit_beam
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var material := _temporal_laser_material(Color(0.3, 0.85, 1.0, 0.7))
			beam.material_override = material
			side_scroll_temporal_laser_root.add_child(beam)
			side_scroll_temporal_laser_parts[key] = beam
			side_scroll_temporal_laser_parts[key + "_material"] = material
		var impact := Node3D.new()
		side_scroll_temporal_laser_root.add_child(impact)
		side_scroll_temporal_laser_parts["impact"] = impact
		var impact_material := _temporal_laser_material(Color(0.3, 0.85, 1.0, 0.35))
		side_scroll_temporal_laser_parts["impact_material"] = impact_material
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = 0.75
		disc_mesh.bottom_radius = 0.75
		disc_mesh.height = 0.025
		disc_mesh.radial_segments = 48
		var disc := MeshInstance3D.new()
		disc.mesh = disc_mesh
		disc.material_override = impact_material
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.add_child(disc)
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.06
		ring_mesh.outer_radius = 1.1
		ring_mesh.rings = 32
		ring_mesh.ring_segments = 64
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = impact_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		impact.add_child(ring)
		var light := OmniLight3D.new()
		light.omni_range = 4.0
		impact.add_child(light)
		side_scroll_temporal_laser_parts["light"] = light
	side_scroll_temporal_laser_root.visible = true
	var direction := end - start
	var length := direction.length()
	if length < 0.05:
		side_scroll_temporal_laser_root.visible = false
		return
	var pulse := 0.9 + sin(time * 31.0) * 0.1
	var outer_width := (0.20 * pulse) if active else lerpf(0.018, 0.045, charge)
	var core_width := (0.065 * pulse) if active else lerpf(0.006, 0.014, charge)
	var beam_color := Color(0.25, 0.85, 1.0) if active else Color(1.0, 0.38, 0.10)
	for key in ["outer", "core"]:
		var beam := side_scroll_temporal_laser_parts[key] as MeshInstance3D
		beam.position = (start + end) * 0.5
		beam.quaternion = Quaternion(Vector3.UP, direction / length)
		var width := outer_width if key == "outer" else core_width
		beam.scale = Vector3(width, length, width)
		var material := side_scroll_temporal_laser_parts[key + "_material"] as StandardMaterial3D
		var color := beam_color if key == "outer" or not active else Color(0.82, 0.98, 1.0)
		material.albedo_color = Color(color.r, color.g, color.b, (0.28 if key == "outer" else 0.5) if active else 0.12 + charge * 0.28)
		material.emission = color
	var impact := side_scroll_temporal_laser_parts["impact"] as Node3D
	impact.position = end
	impact.scale = Vector3.ONE * ((0.55 + charge * 0.45) if not active else 1.0 + sin(time * 18.0) * 0.12)
	var impact_material := side_scroll_temporal_laser_parts["impact_material"] as StandardMaterial3D
	impact_material.albedo_color = Color(beam_color.r, beam_color.g, beam_color.b, 0.35 if active else 0.12 + charge * 0.3)
	impact_material.emission = beam_color
	var light := side_scroll_temporal_laser_parts["light"] as OmniLight3D
	light.light_color = beam_color
	light.light_energy = 2.2 * pulse if active else 0.3 + charge * 0.7


func side_scroll_temporal_hide_laser() -> void:
	if is_instance_valid(side_scroll_temporal_laser_root):
		side_scroll_temporal_laser_root.visible = false


func side_scroll_temporal_impact(position: Vector3, size_scale: float = 1.0) -> void:
	if not is_instance_valid(side_scroll_temporal_root):
		return
	var explosion := W3DCine.new()
	explosion.sk = self
	explosion.explosion3d(position, 100, "TemporalUfoImpact", size_scale)
	if gm != null:
		gm.shake(2.5)


func side_scroll_temporal_update(time: float, escaping := false, escape_progress := 0.0) -> void:
	if is_instance_valid(side_scroll_temporal_ufo):
		var progress := clampf(escape_progress, 0.0, 1.0) if escaping else 0.0
		side_scroll_temporal_ufo.position = Vector3(
			side_scroll_temporal_center.x + sin(time * 7.0) * progress * 3.2,
			side_scroll_temporal_ground + TEMPORAL_UFO_HEIGHT + progress * 20.0 + sin(time * 9.0) * progress * 0.7,
			side_scroll_temporal_center.y + progress * 12.0 + cos(time * 6.0) * progress * 1.8
		)
		side_scroll_temporal_ufo.rotation = Vector3(
			cos(time * 5.0) * progress * 0.16,
			time * 0.3 + progress * TAU,
			sin(time * 7.0) * progress * 0.2
		)
		side_scroll_temporal_ufo.scale = Vector3.ONE * 0.8 * (1.0 - progress * 0.75)
		if escaping and time >= side_scroll_temporal_smoke_next:
			side_scroll_temporal_smoke_next = time + 0.2
			var smoke := _make_smoke(Vector3.ZERO, true)
			smoke.name = "TemporalEscapeSmoke"
			smoke.position = side_scroll_temporal_ufo.position + Vector3(randf_range(-0.2, 0.2), -0.5, -0.7)
			side_scroll_temporal_root.add_child(smoke)
			smoke.finished.connect(smoke.queue_free)


func side_scroll_temporal_clear() -> void:
	if is_instance_valid(side_scroll_temporal_root):
		side_scroll_temporal_root.queue_free()
	side_scroll_temporal_root = null
	side_scroll_temporal_ufo = null
	side_scroll_temporal_bubble = null
	side_scroll_temporal_drops.clear()
	side_scroll_temporal_center = Vector2.ZERO
	side_scroll_temporal_ground = 0.0
	side_scroll_temporal_smoke_next = 0.0
	side_scroll_temporal_laser_root = null
	side_scroll_temporal_laser_parts.clear()
	post_mat.set_shader_parameter("fisheye", 0.0)
	if mat_chr != null:
		mat_chr.set_shader_parameter("side_cut_exempt", 0.0)


func _rebuild_world_chunk(k: Vector2i) -> void:
	if not chunks.has(k):
		return
	for i in range(jobs.size() - 1, -1, -1):
		if jobs[i]["k"] == k:
			jobs.remove_at(i)
	job_keys.erase(k)
	_enqueue(k)


func hit_world_prop(hit_pos: Vector2, face: Vector2, reach: float, arc: float, mult: float, fam: String, rolling: bool) -> bool:
	if not world_on:
		return false
	var player_pos := hit_pos / Game.TS - world_off
	var max_dist := reach / Game.TS + 7.0 / Game.TS
	var best := INF
	var target_pos := Vector2.ZERO
	var target_key_pos := Vector2.ZERO
	var target_chunk := Vector2i.ZERO
	var target_kind := ""
	var a0 := face.angle()
	var broken: Dictionary = gm.persist.get("broken", {})
	for ck in chunks:
		for item in chunks[ck].get("breakables", []):
			var kind := str(item["kind"])
			var key_pos: Vector2 = item["pos"]
			if broken.has(_world_prop_key(key_pos)):
				continue
			var p := key_pos
			if kind == "fence":
				var a: Vector2 = item["a"]
				var b: Vector2 = item["b"]
				var ab := b - a
				var t := clampf((player_pos - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				p = a + ab * t
			elif kind not in ["barrel", "crate", "hay"]:
				continue
			var v := p - player_pos
			var d := v.length()
			if d > max_dist or d >= best or absf(angle_difference(a0, v.angle())) > arc + 0.2:
				continue
			best = d
			target_pos = p
			target_key_pos = key_pos
			target_chunk = ck
			target_kind = kind
	if target_kind.is_empty():
		return false
	var key := _world_prop_key(target_key_pos)
	var hp_map: Dictionary = gm.persist.get("w3d_hp", {})
	var hide_key := Vector2i(roundi(target_key_pos.x * 100.0), roundi(target_key_pos.y * 100.0))
	if gm.side_scroll_active and not side_scroll_prop_changes.has(key):
		side_scroll_prop_changes[key] = {
			"broken": broken.has(key),
			"has_hp": hp_map.has(key),
			"hp": hp_map.get(key, 0.0),
			"hidden_key": hide_key,
			"hidden": ed_hide_keys.has(hide_key),
		}
	var left := float(hp_map.get(key, 16.0))
	if rolling:
		left = 0.0
	else:
		left -= maxf(16.0, 10.0 * mult * Destruct.eff(fam, "molle") * (1.0 + 0.04 * gm.player.a("for")))
	var cp := (target_pos + world_off) * Game.TS + Vector2(8, 8)
	gm.burst(cp, Destruct.COL["molle"], 6, 38.0, 0.35)
	gm.snd("hit")
	gm.shake(1.2)
	if left <= 0.0:
		gm.persist["broken"][key] = true
		hp_map.erase(key)
		gm.persist["w3d_hp"] = hp_map
		ed_hide_keys[hide_key] = true
		if gm.side_scroll_active:
			side_scroll_dirty_chunks[target_chunk] = true
		_rebuild_world_chunk(target_chunk)
		gm.burst(cp, Destruct.COL["molle"], 18, 70.0, 0.55)
		gm.snd("kill")
		gm.shake(2.5)
		if randf() < 0.35:
			gm.add_mat("erba" if target_kind == "hay" else "legna", 1)
	else:
		hp_map[key] = left
		gm.persist["w3d_hp"] = hp_map
		gm.popup(cp + Vector2(0, -14), "%d%%" % int(ceil(100.0 * left / 16.0)), Color(1.0, 0.9, 0.7))
	return true


func side_scroll_breakable_at(point: Vector2, radius: float) -> bool:
	var local := point / Game.TS - world_off
	var reach := radius / Game.TS
	var broken: Dictionary = gm.persist.get("broken", {})
	for ck in chunks:
		for item in chunks[ck].get("breakables", []):
			var kind := str(item["kind"])
			var key_pos: Vector2 = item["pos"]
			if broken.has(_world_prop_key(key_pos)):
				continue
			if kind == "fence":
				var a: Vector2 = item["a"]
				var b: Vector2 = item["b"]
				var ab := b - a
				var t := clampf((local - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
				if local.distance_to(a + ab * t) <= reach + 0.25:
					return true
			elif kind in ["barrel", "crate", "hay"] and local.distance_to(key_pos) <= reach + 0.8:
				return true
	return false


func _world_init() -> void:
	_elev_build()
	_gmap_init()
	ed_load()
	ed_set_area("world")
	ed_hide_sync()
	for k in chunks:
		(chunks[k]["node"] as Node3D).queue_free()
	chunks.clear()
	jobs.clear()
	job_keys.clear()
	plans.clear()
	zones.clear()
	seed_v = 1337
	for nn in [[n_soil, 0, 0.05], [n_veg, 31, 0.045], [n_veg2, 32, 0.19], [n_shrub, 41, 0.06], [n_rock, 51, 0.05], [n_tree, 61, 0.03], [n_stain, 23, 0.03], [n_h, 5, 0.11]]:
		var fn: FastNoiseLite = nn[0]
		fn.seed = seed_v + int(nn[1])
		fn.frequency = float(nn[2])
	_gen_roads()
	# il falo' del villaggio di gioco coincide con il primo falo' del motore: stesse strade organiche, stessa partenza
	world_off = Vector2(gm.SEEDS[0]) + Vector2(3.5, 0.5) - (bonfires[1] as Vector2)
	_game_roads_build()
	_merge_broken_keys()
	if OS.get_cmdline_user_args().has("--listkinds"):
		var cnt := {}
		for g in gm.ents.get_children():
			if g is Prop and g.spr != null and g.spr.texture != null and g.spr.texture.get_width() >= 40:
				cnt[g.kind] = int(cnt.get(g.kind, 0)) + 1
		print("KINDS ", cnt)
	no_base_fires = false
	edge_fn = Callable(self, "_edge_game")
	house_doors.clear()
	doors_seen.clear()
	gm.doors.clear()
	gm.doors.append_array(gm.map_doors)
	landmarks_seen = gm.landmarks.size()
	landmarks_dirty.clear()
	stream_margin = 14.0
	stream_drop = 40.0
	seed_v = 1337
	no_base_houses = false
	grid_road_fn = Callable()
	bio_fn = Callable(self, "_bio_game")
	megas.clear()
	_rebuild_clear_pts()
	_plan_megas()
	pos = gm.player.position / 16.0      # la posizione dell'ultimo fotogramma e' ancora quella dell'interno
	fade_a = 27.0       # visibilita' del mondo aperto (negli interni e' piu' ampia: costruire quell'anello sarebbe 3 volte piu' lento)
	var sp := pos
	pos = sp - world_off
	_stream(true)
	pos = sp
	_world_update()


## le cose distrutte dal giocatore nel mondo restano nascoste
func _merge_broken_keys() -> void:
	for key in gm.persist.get("broken", {}):
		var broken_key := str(key)
		if not broken_key.begins_with("w3d:"):
			continue
		var coords := broken_key.substr(4).split(",")
		if coords.size() == 2:
			ed_hide_keys[Vector2i(int(coords[0]), int(coords[1]))] = true


## zone da tenere libere nei blocchi nuovi: falo', portali, anziano, grandi strutture. Sono tutti punti fissi: la posizione
## del giocatore non deve entrarci, altrimenti la casa da cui si e' appena usciti non verrebbe ricostruita (la porta si').
func _rebuild_clear_pts() -> void:
	clear_pts.clear()
	for g in gm.props:
		if not is_instance_valid(g) or bool(g.scene) or not (str(g.kind) in ["portal", "bonfire", "elder"]):
			continue
		var gc := Vector2(g.cell) + Vector2(0.5, 0.5) - world_off
		clear_pts.append(Vector3(gc.x, gc.y, 4.5 if g.kind == "portal" else 2.4))
	for mg in megas:
		clear_pts.append(Vector3((mg[1] as Vector2).x, (mg[1] as Vector2).y, W3DStructs.radius(str(mg[0]))))


var world_stashed := false
var world_stash_seed := -1


## accoda i blocchi mancanti e costruisce subito solo quelli sotto i piedi del giocatore: gli altri arrivano a poco a poco durante il gioco
func _stream_near() -> void:
	_stream(false)
	var guard := 0
	while not jobs.is_empty() and guard < 80:
		var jk: Vector2i = jobs[0]["k"]
		var ctr := Vector2((jk.x + 0.5) * CHS, (jk.y + 0.5) * CHS)
		if ctr.distance_to(pos) > CHS * 0.95:
			break
		_run_jobs(0.0)
		guard += 1


## uscendo nel mondo verso un interno i blocchi gia' costruiti non si buttano: si nascondono, cosi' al ritorno il mondo e' li' subito
func _world_stash() -> void:
	_world_clear()
	for k in chunks:
		var nd := chunks[k]["node"] as Node3D
		nd.visible = false
		nd.process_mode = Node.PROCESS_MODE_DISABLED
	jobs.clear()
	job_keys.clear()
	world_stashed = true
	world_stash_seed = int(gm.world_seed)


func _world_unstash() -> void:
	world_stashed = false
	for c in static_root.get_children():
		c.queue_free()
	for k in dyn.keys():
		_drop_dyn(k)
	room_lamps.clear()
	decor_lights.clear()
	room_theme.clear()
	built_area = "world"
	world_on = true
	_elev_set(true)
	vp.size = Vector2i(960, 540)
	post_mat.set_shader_parameter("px", Vector2(960, 540))
	edge_fn = Callable(self, "_edge_game")
	bio_fn = Callable(self, "_bio_game")
	grid_road_fn = Callable()
	ed_set_area("world")
	ed_hide_sync()
	_merge_broken_keys()
	_rebuild_clear_pts()
	for k in chunks:
		var nd := chunks[k]["node"] as Node3D
		nd.visible = true
		nd.process_mode = Node.PROCESS_MODE_INHERIT
	pos = gm.player.position / 16.0
	fade_a = 27.0
	var sp := pos
	pos = sp - world_off
	_stream_near()
	pos = sp
	_world_update()


var mega_seed := -1


## pianifica le grandi strutture del mondo: una zona di 5x5 blocchi su ~2.4 ne ha una, lontana da villaggi, ingressi, luoghi del gioco, strade, acqua e dal bordo.
## Dentro ci sono guardiani e un tesoro (aggiunti una volta sola per partita).
func _plan_megas() -> void:
	megas.clear()
	var ZC := 4
	var zone := float(CHS * ZC)
	var W := float(Game.MW)
	var H := float(Game.MH)
	var avoid: Array = []
	for s in gm.SEEDS:
		avoid.append([Vector2(s), 30.0])
	for e in gm.ENTR.values():
		avoid.append([Vector2(e), 14.0])
	for po in gm.pois:
		avoid.append([Vector2(po["cell"]), 16.0])
	for a in gm.arenas:
		avoid.append([(a["pos"] as Vector2) / 16.0, 16.0])
	var add_ents: bool = mega_seed != int(gm.world_seed)
	for zx in range(floori(-world_off.x / zone) - 1, ceili((W - world_off.x) / zone) + 1):
		for zz in range(floori(-world_off.y / zone) - 1, ceili((H - world_off.y) / zone) + 1):
			var zr := RandomNumberGenerator.new()
			zr.seed = hash(Vector3i(zx, zz, seed_v + 4242))
			if zr.randf() > 0.55:
				continue
			var mp := Vector2((zx + 0.15 + zr.randf() * 0.7) * zone, (zz + 0.15 + zr.randf() * 0.7) * zone)
			var yaw := zr.randf() * TAU
			var mg := mp + world_off
			if mg.x < 20.0 or mg.y < 20.0 or mg.x > W - 20.0 or mg.y > H - 20.0:
				continue
			var kind := W3DStructs.pick_big(_bio_at(mp), zr)
			if kind == "":
				continue
			var rad := W3DStructs.radius(kind)
			var ok := true
			for q in avoid:
				if mg.distance_to(q[0]) < float(q[1]) + rad:
					ok = false
			if not ok:
				continue
			if float(_road_near(mp)["d"]) < rad * 0.45:
				continue
			var pts: Array = [Vector2.ZERO]
			for ang in 8:
				pts.append(Vector2.from_angle(ang * PI * 0.25) * rad * 0.7)
			for pt in pts:
				var c := Vector2i(floori(mg.x + pt.x), floori(mg.y + pt.y))
				if not gm.inb(c) or bool(edge_fn.call(mp + pt)) or gm.water[gm.idx(c)] == 1:
					ok = false
			if not ok:
				continue
			megas.append([kind, mp, yaw])
			clear_pts.append(Vector3(mp.x, mp.y, rad))
			if add_ents:
				_mega_guardians(kind, mg, yaw, zr)
	# il granaio del villaggio: fuori dalle case, verso l'interno dell'isola, sempre nello stesso posto
	var vc := Vector2(gm.SEEDS[0])
	var inward := (Vector2(W, H) * 0.5 - vc).normalized()
	gm.barn_pos = Vector2(-1, -1)
	var best_bg := Vector2(-1, -1)
	var best_score := 1e9
	for k in 30:
		var ang := inward.angle() + ceili(k / 2.0) * 0.25 * (1.0 if k % 2 == 1 else -1.0)
		var dist := 38.0 + float(k / 6) * 7.0
		var bg := vc + Vector2.from_angle(ang) * dist
		var bmp := bg - world_off
		var ok2 := true
		for pt in [Vector2.ZERO, Vector2(5.5, 0.0), Vector2(-5.5, 0.0), Vector2(0.0, 5.5), Vector2(0.0, -5.5)]:
			var c2 := Vector2i(floori(bg.x + pt.x), floori(bg.y + pt.y))
			if not gm.inb(c2) or bool(edge_fn.call(bmp + pt)) or gm.water[gm.idx(c2)] == 1:
				ok2 = false
		if not ok2 or float(_road_near(bmp)["d"]) < 2.5:
			continue
		var lx := floori(bmp.x / LC)
		var lz := floori(bmp.y / LC)
		var bad := 0
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if str(_plan(lx + dx, lz + dz).get("kind", "")) in ["house", "yard"]:
					bad += 1
		var score := float(bad) * 20.0 + dist       # poche case attorno, e il piu' vicino possibile al villaggio
		if score < best_score:
			best_score = score
			best_bg = bg
	if best_bg.x >= 0.0:
		var toward := (vc - best_bg).normalized()
		var bmp2 := best_bg - world_off
		megas.append(["barn", bmp2, atan2(-toward.y, toward.x)])
		clear_pts.append(Vector3(bmp2.x, bmp2.y, W3DStructs.radius("barn")))
		gm.barn_pos = best_bg
	mega_seed = int(gm.world_seed)


func _mega_guardians(kind: String, mg: Vector2, yaw: float, r: RandomNumberGenerator) -> void:
	var bi := int(gm.biome[gm.idx(Vector2i(floori(mg.x), floori(mg.y)))])
	var pool: Array = Game.BIO[bi]["pool"]
	var tint: Color = Game.BIO[bi]["tint"]
	var rad := W3DStructs.radius(kind)
	var n: int = {"castle_ruin": 12, "monastery_ruin": 5, "palisade_fort": 5, "arena_ruin": 6, "ghost_village": 5, "mine_entrance": 4, "ice_temple": 4, "bandit_camp": 6}.get(kind, 4)
	var mult := (1.0 + int(Game.BIO[bi]["tier"]) * 0.2) * 1.15
	for i in n:
		var a := r.randf() * TAU
		var c := Vector2i(floori(mg.x + cos(a) * rad * 0.45 * r.randf()), floori(mg.y + sin(a) * rad * 0.45 * r.randf()))
		var cc: Vector2i = gm.free_near(c)
		gm.spawns.append({"k": pool[r.randi() % pool.size()], "pos": gm.cell_pos(cc), "mult": mult, "elite": r.randf() < 0.15, "tint": tint})
	for i in 1 + int(n >= 6) + int(n >= 12) * 2:
		gm.add_champion(Vector2i(floori(mg.x), floori(mg.y)) + Vector2i(r.randi_range(-3, 3), r.randi_range(-3, 3)), 1.2)
	var spot: Vector2 = W3DBig.loot_spot(kind)
	var wl := Basis(Vector3.UP, yaw) * Vector3(spot.x, 0, spot.y)
	var lc: Vector2i = gm.free_near(Vector2i(floori(mg.x + wl.x), floori(mg.y + wl.z)))
	gm.add_prop("chest", lc)
	gm.index_spawns()


## collisione del mondo aperto: i solidi sono quelli visibili in 3D
## i cancelli sigillati occupano celle di ponte nella logica (block): in 3D devono fermare allo stesso modo
func _sealed_gate_hit(p: Vector2, r: float) -> bool:
	for off in [Vector2(-r, 0.0), Vector2(r, 0.0), Vector2(0.0, -r), Vector2(0.0, r), Vector2.ZERO]:
		var c := Vector2i(((p + off) / 16.0).floor())
		if gm.inb(c) and gm.bridge.size() > gm.idx(c) and gm.bridge[gm.idx(c)] == 1 and gm.block.has(c):
			return true
	return false


func world_free(p: Vector2, r: float) -> bool:
	var c := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
	if gm.outside.size() != Game.MW * Game.MH:
		return gm.is_floor(c)      # dati di un interno: vale il suo reticolo
	if not gm.inb(c) or (gm.outside[gm.idx(c)] == 1 and gm.grid[gm.idx(c)] == 0):
		return false
	if _gcol_hit(p / 16.0, r / 16.0 * 0.8):
		return false
	if _sealed_gate_hit(p, r):
		return false
	if gm.water.size() > gm.idx(c) and gm.water[gm.idx(c)] == 1 and gm.bridge[gm.idx(c)] == 0:
		return false      # il fiume si passa solo sui ponti (e dai passaggi sotterranei): altrimenti i cancelli non servono
	return not _blocked(p / 16.0 - world_off, r / 16.0 * 0.8)


var gcols: Dictionary = {}


func _bio_game(p: Vector2) -> int:
	var c := Vector2i(floori(p.x + world_off.x), floori(p.y + world_off.y))
	if not gm.inb(c):
		return 0
	var b := int(gm.biome[gm.idx(c)])
	if b == 0 and not gm.gen_chunks.has(Vector2i(c.x / gm.CH, c.y / gm.CH)):
		return 0
	return b


func _gcol_hit(p: Vector2, r: float) -> bool:
	var k := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var kk := k + Vector2i(dx, dz)
			if not gcols.has(kk):
				continue
			for e in gcols[kk]:
				var c: Vector2 = e[0]
				var hs: Vector2 = e[1]
				if absf(p.x - c.x) < hs.x + r and absf(p.y - c.y) < hs.y + r:
					return true
	return false


var unstick_t := 0.0
var world_real := 0 if OS.get_cmdline_user_args().has("--noreal") else 4
var world_light_k := 30.0


## i nemici nati dentro un edificio 3D vengono spostati sul punto libero piu' vicino
func _unstick(dt: float) -> void:
	if gm.side_scroll_active:
		return
	unstick_t -= dt
	if unstick_t > 0.0:
		return
	unstick_t = 0.8
	# una partita salvata (o un vecchio mondo) puo' lasciare il giocatore in acqua: lo si riporta sulla riva
	var pc: Vector2i = Vector2i((gm.player.position / 16.0).floor())
	if gm.inb(pc) and gm.water.size() > gm.idx(pc) and gm.water[gm.idx(pc)] == 1 and gm.bridge[gm.idx(pc)] == 0:
		for step in 240:
			var bank: Vector2 = gm.player.position + Vector2.from_angle(TAU * (step % 12) / 12.0) * (step / 12 + 1) * 16.0
			if world_free(bank, 5.0):
				gm.player.position = bank
				break
	for pr in gm.props:
		if not is_instance_valid(pr) or not (str(pr.kind) in ["page", "loot", "qitem", "dig", "shrine"] or str(pr.kind).begins_with("res_")):
			continue
		var centre: Vector2 = (pr as Node2D).position + Vector2(8, -8)
		if centre.distance_to(gm.player.position) > 500.0 or world_free(centre, 4.0):
			continue
		for step in 96:
			var shift := Vector2.from_angle(TAU * (step % 12) / 12.0) * (step / 12 + 1) * 16.0
			if world_free(centre + shift, 4.0):
				(pr as Node2D).position += shift
				_drop_dyn((pr as Node2D).get_instance_id())
				break
	for e in gm.enemies:
		if not is_instance_valid(e):
			continue
		var ep: Vector2 = (e as Node2D).position
		if ep.distance_to(gm.player.position) > 900.0 or world_free(ep, 5.0):
			continue
		var done := false
		for ring in range(1, 9):
			for a in 12:
				var q := ep + Vector2.from_angle(TAU * a / 12.0) * ring * 16.0
				if world_free(q, 5.0):
					(e as Node2D).position = q
					done = true
					break
			if done:
				break


func _world_lamps() -> void:
	var cand: Array = []
	for k in chunks:
		for l in chunks[k]["lamps"]:
			var lv: Vector4 = l
			var wp := Vector2(lv.x, lv.z) + world_off
			cand.append([wp.distance_squared_to(pos), Vector4(wp.x, lv.y, wp.y, lv.w)])
	for f in gm.flick:
		var fl2 = f[0]
		if not is_instance_valid(fl2):
			continue
		var fp: Vector2 = (fl2 as Node2D).global_position / 16.0
		cand.append([fp.distance_squared_to(pos), Vector4(fp.x, 1.6, fp.y, minf(1.4, float(f[1]) * 0.6))])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	# le luci piu' vicine sono vere (con ombre proiettate da case, alberi e personaggi); le altre restano finte
	var nreal := mini(world_real, cand.size())
	for ri in pool.size():
		var rl: OmniLight3D = pool[ri]
		if ri < nreal:
			var rv: Vector4 = cand[ri][1]
			var rfl := 1.0 + sin(lamp_t * 11.0 + rv.x * 3.1) * 0.07 + sin(lamp_t * 23.0 + rv.z) * 0.04
			rl.position = Vector3(rv.x, 7.5 + elev_at(rv.x, rv.z), rv.z)      # sopra lanterne e fiamme: la luce non nasce dentro la geometria che la copre
			rl.shadow_normal_bias = 2.0
			rl.shadow_bias = 0.3
			rl.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
			rl.shadow_enabled = ri < 2
			rl.light_color = Color(0.96, 0.76, 0.62)
			rl.omni_range = 14.0
			rl.light_energy = rv.w * world_light_k * rfl
			rl.visible = true
		else:
			rl.visible = false
	cand = cand.slice(nreal)
	var arr := PackedVector4Array()
	var lc := PackedVector3Array()
	for i in 16:
		if i < cand.size():
			var lv2: Vector4 = cand[i][1]
			var fl := 1.0 + sin(lamp_t * 11.0 + lv2.x * 3.1) * 0.09 + sin(lamp_t * 23.0 + lv2.z) * 0.05
			arr.append(Vector4(lv2.x, lv2.y + elev_at(lv2.x, lv2.z), lv2.z, lv2.w * fl))
			lc.append(Vector3(0.92, 0.74, 0.60))
		else:
			arr.append(Vector4(0, 0, 0, 0))
			lc.append(Vector3(0, 0, 0))
	_mp("lamps", arr)
	_mp("lamp_col", lc)


var skin_us := 0
var wu_us := 0
var fx_us := 0
var lamp_us := 0
var sync_us := 0


func _process(dt: float) -> void:
	var tt := Time.get_ticks_usec()
	_process_inner(dt)
	skin_us += Time.get_ticks_usec() - tt


func _process_inner(dt: float) -> void:
	if gm == null or gm.player == null:
		return
	if want_shot and str(gm.state) == "story":
		gm.state = "play"
	if OS.get_cmdline_user_args().has("--skinitems") and lamp_t > 1.0 and not test_done:
		test_done = true
		var ids: Array = W3DChrono.MODELS.keys()
		for i in ids.size():
			var mi3 := MeshInstance3D.new()
			mi3.mesh = W3DChrono.mesh(str(ids[i]))
			mi3.material_override = mat_prop
			mi3.position = Vector3(pos.x - 11.0 + (i % 9) * 2.9, 0.0, pos.y - 7.5 + (i / 9) * 3.0)
			vp.add_child(mi3)
		bub_shot_t = lamp_t + 1.0
	for ua in OS.get_cmdline_user_args():
		if str(ua).begins_with("--skinui=") and lamp_t > 1.5 and not test_done:
			test_done = true
			if str(ua).substr(9) == "bestiary":
				for be in Bestiary.ENTRIES:
					if not gm.persist.has("bestiary"):
						gm.persist["bestiary"] = {}
					gm.persist["bestiary"][be[0]] = 3
				gm.beast_sel = 4
				gm.open_bestiary()
			else:
				gm.inv_toggle()
			bub_shot_t = lamp_t + 0.8
	if OS.get_cmdline_user_args().has("--skindoor") and world_on and lamp_t > 4.0 and not test_done and gm.doors.size() > 0:
		test_done = true
		var dd0: Dictionary = gm.doors[0]
		print("DOOR n=", gm.doors.size(), " dest=", dd0["dest"], " pos=", dd0["pos"])
		gm.player.position = (dd0["pos"] as Vector2) + Vector2(3, 3)
		bub_shot_t = lamp_t + 6.0
	if OS.get_cmdline_user_args().has("--skindoor") and test_done and lamp_t > 6.0 and lamp_t < 6.05:
		print("DOOR area now=", gm.area)
	if OS.get_cmdline_user_args().has("--dbgmenu") and lamp_t > 2.0 and not test_done:
		test_done = true
		var ke := InputEventKey.new()
		ke.keycode = KEY_F2
		ke.pressed = true
		Input.parse_input_event(ke)
		bub_shot_t = lamp_t + 0.8
		print("DBG state before=", gm.state)
	if OS.get_cmdline_user_args().has("--skinfield") and world_on and lamp_t > 3.0 and not test_done and first_field.x > -9000.0:
		test_done = true
		gm.player.position = (first_field + Vector2(0, 3.0) + world_off) * 16.0
		bub_shot_t = lamp_t + 3.0
	if OS.get_cmdline_user_args().has("--pierdbg") and world_on and lamp_t > 3.0 and not test_done:
		test_done = true
		var cnt := 0
		var wat := 0
		for lz in range(-8, 9):
			for lx in range(-20, 3):
				var q := Vector2(lx * 8.0 + 4.0, lz * 8.0 + 4.0)
				var wdv := _water_dir(q)
				var ed: bool = _edge_game(q)
				if ed:
					wat += 1
				elif wdv.z > 0.0:
					cnt += 1
		print("PIERDBG water_lots=", wat, " lots_near_water=", cnt, " off=", world_off)
	if OS.get_cmdline_user_args().has("--skinpier") and world_on and lamp_t > 3.0 and not test_done:
		test_done = true
		var target := Vector2(-9999, -9999)
		for lx in range(-3, 3):
			for lz in range(-8, 9):
				var q := Vector2(lx * 8.0 + 4.0, lz * 8.0 + 4.0)
				if not _edge_game(q) and _water_dir(q).z > 0.0 and target.x < -9000.0:
					target = q
		if target.x < -9000.0:
			for lx in range(-24, -3):
				for lz in range(-8, 9):
					var q2 := Vector2(lx * 8.0 + 4.0, lz * 8.0 + 4.0)
					if not _edge_game(q2) and _water_dir(q2).z > 0.0 and target.x < -9000.0:
						target = q2
		print("PIERTARGET ", target)
		gm.player.position = (target + world_off) * 16.0
		gm.ensure_area(gm.player.position, 3)
		var sp0 := target
		pos = sp0
		_stream(true)
		pos = target + world_off
		bub_shot_t = lamp_t + 2.0
	if OS.get_cmdline_user_args().has("--skinedge") and world_on and lamp_t > 3.0 and not test_done:
		test_done = true
		var ex := 60
		while ex < 400 and gm.outside[gm.idx(Vector2i(ex, 592))] == 1:
			ex += 2
		gm.player.position = Vector2(float(ex + 4), 592.0) * 16.0
		print("EDGE first inside x=", ex)
		bub_shot_t = lamp_t + 3.0
	if bub_shot_t > 0.0 and lamp_t > bub_shot_t:
		get_viewport().get_texture().get_image().save_png("user://bub_%d.png" % bub_shot_n)
		bub_shot_n += 1
		bub_shot_t = lamp_t + 0.25 if bub_shot_n < 3 else -1.0
	for ta in OS.get_cmdline_user_args():
		if str(ta).begins_with("--skinbubble=") and lamp_t > 1.2 and not test_done:
			test_done = true
			var tid := str(ta).substr(13)
			var cls := "jackpot" if Chrono.JACKPOT.has(tid) else ("gun" if Chrono.GUN.has(tid) else ("use" if Chrono.USE.has(tid) else "junk"))
			ChronoBubble.spawn(gm, {"id": tid, "cls": cls}, false)
			bub_shot_t = lamp_t + 0.95
		if str(ta).begins_with("--skinveh=") and lamp_t > 2.0 and not test_done:
			test_done = true
			gm.player.board(str(ta).substr(10))
	if OS.get_cmdline_user_args().has("--noshadow"):
		sun.shadow_enabled = false
	if OS.get_cmdline_user_args().has("--no2d") and world_on and not no2d_done:
		no2d_done = true
		for g in gm.ents.get_children():
			if g is Prop and bool(g.scene):
				g.process_mode = Node.PROCESS_MODE_DISABLED
		print("NO2D done")
	if (perf_on or OS.get_cmdline_user_args().has("--hold")) and (str(gm.state) == "story" or str(gm.state) == "title"):
		gm.state = "play"
	var want: bool = str(gm.area) != "" and gm.state != "title"
	if want != active:
		active = want
		post_rect.visible = active
		sharp_layer.visible = active
		_show_2d(not active)
		if not active:
			for k in dyn.keys():
				_drop_dyn(k)
	if not active:
		return
	if str(gm.area) == "world":
		if not world_on and built_area != "world" and world_stashed and world_stash_seed == int(gm.world_seed) and not chunks.is_empty() and not OS.get_cmdline_user_args().has("--nocache"):
			_world_unstash()
		elif not world_on or built_area != "world":
			_world_clear()
			for k in dyn.keys():
				_drop_dyn(k)
			room_lamps.clear()
			decor_lights.clear()
			room_theme.clear()
			built_area = "world"
			world_on = true
			_elev_build()
			_elev_set(true)
			vp.size = Vector2i(960, 540)      # stessa risoluzione degli interni: stesso aspetto grafico
			post_mat.set_shader_parameter("px", Vector2(960, 540))
			_world_clear()
			_world_init()
	elif built_area != str(gm.area) or built_grid_id != gm.grid.size() or world_on:
		if world_on:
			if OS.get_cmdline_user_args().has("--nocache"):
				_world_clear()
				for k in chunks:
					(chunks[k]["node"] as Node3D).queue_free()
				chunks.clear()
				jobs.clear()
				job_keys.clear()
			else:
				_world_stash()
		world_on = false
		_elev_set(false)
		gm.mm3d = null
		edge_fn = Callable()
		grid_road_fn = Callable()
		vp.size = Vector2i(960, 540)
		post_mat.set_shader_parameter("px", Vector2(960, 540))
		_rebuild_static()
		for l in gm.fx.get_children():
			if l is Label:
				l.set_meta("tracked", true)
	lamp_t += dt
	lamp_n += 1.0
	if perf_on:
		if int(lamp_t * 2.0) != int((lamp_t - dt) * 2.0):
			print("T ", snappedf(lamp_t, 0.1), " fps=", Engine.get_frames_per_second(), " chunks=", chunks.size(), " jobs=", jobs.size(), " pos=", pos, " fade=", snappedf(fade_a, 0.1))
		if jobs.is_empty() and chunks.size() >= 6:
			steady_clock += dt
		else:
			steady_clock = 0.0
		if steady_clock > 2.0:
			steady_n += 1
			steady_sum += dt
			if steady_sum >= 6.0:
				print("STEADY fps=", snappedf(steady_n / steady_sum, 0.1), " frame_ms=", snappedf(steady_sum / steady_n * 1000.0, 0.1), " chunks=", chunks.size(), " lamp_t=", snappedf(lamp_t, 0.1))
				get_tree().quit()
		if lamp_t > 90.0:
			print("STEADY non raggiunto, chunks=", chunks.size(), " jobs=", jobs.size())
			get_tree().quit()
		if lamp_t > 6.0:
			perf_n += 1
			perf_t += dt
			perf_max = maxf(perf_max, dt)
			perf_proc += Performance.get_monitor(Performance.TIME_PROCESS)
			perf_phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			if dt > 0.07:
				print("HITCH ", snappedf(lamp_t, 0.1), " ", snappedf(dt * 1000.0, 1.0), "ms jobs=", jobs.size(), " chunks=", chunks.size())
		if lamp_t > 200.0:
			var tot := {}
			for kk in step_us:
				tot[kk] = [int(step_us[kk]) / 1000, step_n[kk]]
			print("STEPS(ms,n) ", tot)
			print("SKIN ms/frame=", snappedf(float(skin_us) / 1000.0 / maxf(lamp_n, 1.0), 0.1), " world_update=", snappedf(float(wu_us) / 1000.0 / maxf(lamp_n, 1.0), 0.1), " sync=", snappedf(float(sync_us) / 1000.0 / maxf(lamp_n, 1.0), 0.1), " fx=", snappedf(float(fx_us) / 1000.0 / maxf(lamp_n, 1.0), 0.1), " lamps=", snappedf(float(lamp_us) / 1000.0 / maxf(lamp_n, 1.0), 0.1))
			print("PROC ms/frame=", snappedf(perf_proc / maxf(perf_n, 1) * 1000.0, 0.1), " phys=", snappedf(perf_phys / maxf(perf_n, 1) * 1000.0, 0.1), " draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
			print("PERF fps=", snappedf(perf_n / maxf(perf_t, 0.001), 0.1), " worst_ms=", snappedf(perf_max * 1000.0, 1.0), " chunks=", chunks.size(), " jobs=", jobs.size(), " gen_ms=", snappedf(gen_ms, 1.0), " fade_a=", snappedf(fade_a, 0.1), " state=", gm.state, " world=", world_on, " area=", gm.area)
			get_tree().quit()
	_show_2d(false)
	pos = ed.pos if (ed != null and ed.on) else gm.player.position / 16.0
	if world_on:
		var tw := Time.get_ticks_usec()
		_world_update()
		_unstick(dt)
		mm_t -= dt
		if mm_t <= 0.0:
			mm_t = 0.35
			_update_minimap()
		wu_us += Time.get_ticks_usec() - tw
	# aggiorna gli oggetti del gioco
	var ts0 := Time.get_ticks_usec()
	if world_on:
		_sync_node2d(gm.player, true)
		var ppx: Vector2 = gm.player.position
		if Engine.get_process_frames() % 60 == 0:
			gm.pickups = gm.pickups.filter(func(x): return is_instance_valid(x))
		near_props_t -= 1
		if near_props_t <= 0:
			near_props_t = 12
			near_props.clear()
			for gp in gm.props:
				if is_instance_valid(gp) and _is_game_prop(gp) and (gp as Node2D).position.distance_squared_to(ppx) <= 640000.0:
					near_props.append(gp)
		for lst in [gm.enemies, gm.villagers, gm.allies, gm.critters, near_props, gm.pickups]:
			for n in lst:
				if not is_instance_valid(n):
					continue
				var np2: Vector2 = (n as Node2D).position
				if np2.distance_squared_to(ppx) > 640000.0:      # oltre ~50 unita': non serve nemmeno controllarlo
					var nid: int = n.get_instance_id()
					if dyn.has(nid):
						_drop_dyn(nid)
					continue
				if lst == gm.props and bool(n.scene):
					continue
				_sync_node2d(n, false)
	else:
		for n in gm.ents.get_children():
			_sync_node2d(n, n == gm.player)
	sync_us += Time.get_ticks_usec() - ts0
	var tf0 := Time.get_ticks_usec()
	_sync_fx()
	_bubbles_cleanup()
	_popups_cleanup()
	_sync_slash()
	fx_us += Time.get_ticks_usec() - tf0
	# elimina cio' che non esiste piu'; i proiettili spariscono subito e lasciano scintille d'impatto
	for id in dyn.keys():
		var dd: Dictionary = dyn[id]
		if dd.has("src"):
			var sr = (dd["src"] as WeakRef).get_ref()
			if sr == null or not is_instance_valid(sr):
				if bool(dd.get("imp", false)):
					burst3d(dd["lp"], Color(1.0, 0.75, 0.4), 8, 55.0, 0.3)
				_drop_dyn(id)
				continue
		if float(dd.get("seen", 0.0)) < lamp_t - 0.12:
			_drop_dyn(id)
	shake = float(gm.shake_v) * 0.45
	_booms_update(dt)
	if world_on:
		# la camera sale un po' quando davanti c'e' un rilievo molto piu' alto, cosi' le montagne non ti finiscono addosso
		var e0 := elev_at(pos.x, pos.y)
		var ahead := e0
		for q in 6:
			ahead = maxf(ahead, elev_at(pos.x + cos(q * PI / 3.0) * 13.0, pos.y + sin(q * PI / 3.0) * 13.0))
		elev_y = lerpf(elev_y, e0 + minf(ahead - e0, 22.0) * 0.7, 0.12)
	else:
		elev_y = 0.0
	if gm.side_scroll_active:
		if fpv:
			fpv_set(false)
		curve = 0.0
		var temporal_clearing := str(gm.side_scroll_mode) == "temporal_clearing"
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE if temporal_clearing else Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 10.0
		cam.fov = 38.6
		cam.near = 0.1
		cam.far = 120.0
		if temporal_clearing:
			var center: Vector2 = gm.side_scroll_temporal_center
			var player_center: Vector2 = gm.player.position / Game.TS
			var focus := center.lerp(player_center, 0.5)
			var side_ground := elev_at(focus.x, focus.y)
			mat_chr.set_shader_parameter("side_cut_exempt", 1.0)
			RenderingServer.global_shader_parameter_set("w3d_side_cut", Vector4.ZERO)
			cam.position = Vector3(focus.x, side_ground + 20.0, focus.y + 24.0)
			cam.look_at(Vector3(focus.x, side_ground + 3.5, focus.y), Vector3.UP)
		else:
			mat_chr.set_shader_parameter("side_cut_exempt", 0.0)
			var side_ground := elev_at(pos.x, pos.y)
			RenderingServer.global_shader_parameter_set("w3d_side_cut", Vector4(side_ground + 0.9, pos.y, 1.0, 0.12))
			cam.position = Vector3(pos.x, side_ground + 6.0, pos.y + 24.0)
			cam.look_at(Vector3(pos.x, side_ground + 0.9, pos.y), Vector3.UP)
	else:
		mat_chr.set_shader_parameter("side_cut_exempt", 0.0)
		RenderingServer.global_shader_parameter_set("w3d_side_cut", Vector4.ZERO)
		if cam.projection == Camera3D.PROJECTION_ORTHOGONAL:
			cam.projection = Camera3D.PROJECTION_PERSPECTIVE
			cam.rotation_degrees = Vector3(-90, 0, 0)
			cam.near = 2.0
			cam.far = 120.0
		_update_cam()
	if fpv:
		_fpv_look(dt)
		_fpv_cam()
	if OS.get_cmdline_user_args().has("--skintilt"):      # prova: camera inclinata per vedere il rilievo
		cam.rotation_degrees = Vector3(-42, 0, 0)
		cam.position.z += cam.position.y * 0.95
	dust.position = Vector3(pos.x, 3.0 + elev_y, pos.y)
	RenderingServer.global_shader_parameter_set("w3d_player", Vector3(pos.x, 0, pos.y))
	fade_a = lerpf(fade_a, ed.fade if (ed != null and ed.on) else ((46.0 if fpv else 27.0 + cam_extra * 0.9) if world_on else 48.0), 0.15)
	if not fixed_cam:
		var target_cam_h := CAM_H_ROOM
		if world_on:
			target_cam_h = (CAM_H_WORLD_FAR if world_zoom_far else CAM_H_WORLD) + cam_extra
		cam_h = lerpf(cam_h, target_cam_h, 0.08)
	if fwd:
		env.ssao_enabled = not world_on
		env.volumetric_fog_enabled = not world_on
		env.glow_enabled = false   # niente alone sfumato
		# nel mondo aperto: luce del motore originale (sole freddo con ombre + ambiente), niente tonemapping cinematografico
		sun.visible = world_on
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR if world_on else Environment.TONE_MAPPER_FILMIC
		env.tonemap_exposure = 1.0 if world_on else 0.9
		env.fog_enabled = true
		env.fog_density = 0.0035 if world_on else 0.012
		env.fog_light_color = Color(0.10, 0.11, 0.14) if world_on else Color(0.05, 0.05, 0.08)
	if world_on:
		# mondo aperto: stesse luci finte del motore originale (pozze calde sotto lampioni e falo')
		hero_light.visible = false
		var tl0 := Time.get_ticks_usec()
		_world_lamps()
		lamp_us += Time.get_ticks_usec() - tl0
		_mp("hero_glow", 0.34)
		env.ambient_light_energy = 0.07
		sun.light_energy = 0.14
		env.ambient_light_color = Color(0.42, 0.44, 0.6) * Chrono.world_tint()
	elif fwd:
		hero_light.visible = true
		_real_lights(dt)
		var zl := PackedVector4Array()
		zl.resize(16)
		_mp("lamps", zl)
		_mp("hero_glow", 0.0)
	else:
		_skin_lamps()
	_cine_tick(dt)
	_mp("curve", curve)
	_mp("fade_a", fade_a)
	_mp("fade_b", fade_a + 18.0)
	RenderingServer.global_shader_parameter_set("w3d_curve", Vector3(curve, fade_a, fade_a + 18.0))
	_mp("floor_min", (0.04 if world_on else 0.34) if (not fwd or world_on) else 0.0)
	mat_chr.set_shader_parameter("gamma_in", 2.0)
	mat_chr.set_shader_parameter("boost", 1.8)
	mat_chr.set_shader_parameter("sat_k", 1.35)
	if not fwd and not world_on:
		_mp("hero_glow", 0.55)
	mat.set_shader_parameter("patt", 1.0 if world_on else 0.0)
	mat.set_shader_parameter("boost", 0.27 if world_on else 1.0)
	mat.set_shader_parameter("sat_k", 1.25 if world_on else 1.0)
	if mat_ground != null:
		mat_ground.set_shader_parameter("boost", 0.27)
		mat_ground.set_shader_parameter("sat_k", 1.25)
	mat_chr.set_shader_parameter("patt", 0.0)
	mat_prop.set_shader_parameter("patt", 0.0)
	mat_prop.set_shader_parameter("boost", 0.42 if world_on else 0.9)
	mat_prop.set_shader_parameter("sat_k", 1.1)
	mat_prop.set_shader_parameter("floor_min", (0.04 if world_on else 0.34) if (not fwd or world_on) else 0.0)
	if want_shot:
		_shot(dt)


func _skin_lamps() -> void:
	var cand: Array = []
	for f in gm.flick:
		var l = f[0]
		if not is_instance_valid(l):
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
		cand.append([gp.distance_squared_to(pos), Vector4(gp.x, 1.8, gp.y, minf(2.4, float(f[1]) * 1.6)), Vector3(0.92, 0.74, 0.60)])
	for dl in decor_lights:
		var dv: Vector3 = dl
		cand.append([Vector2(dv.x, dv.z).distance_squared_to(pos), Vector4(dv.x, dv.y, dv.z, 1.6), Vector3(0.92, 0.74, 0.60)])
	for rl in room_lamps:
		var rp: Vector2 = rl[0]
		var lc: Color = rl[1]
		cand.append([rp.distance_squared_to(pos) * 1.4, Vector4(rp.x, 4.0, rp.y, 0.5), Vector3(lc.r, lc.g, lc.b)])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var arr := PackedVector4Array()
	var cols := PackedVector3Array()
	for i in 16:
		if i < cand.size():
			var lv: Vector4 = cand[i][1]
			var fl := 1.0 + sin(lamp_t * 11.0 + lv.x * 3.1) * 0.09 + sin(lamp_t * 23.0 + lv.z) * 0.05
			if (cand[i][2] as Vector3).z > 0.9:
				fl = 1.0 + sin(lamp_t * 1.3 + lv.x) * 0.06     # il bagliore freddo respira lentamente
			arr.append(Vector4(lv.x, lv.y, lv.z, lv.w * fl))
			cols.append(cand[i][2])
		else:
			arr.append(Vector4(0, 0, 0, 0))
			cols.append(Vector3(0, 0, 0))
	_mp("lamps", arr)
	_mp("lamp_col", cols)


func _shot(dt: float) -> void:
	shot_t += dt
	if OS.get_cmdline_user_args().has("--skinkill") and shot_t > 2.6 and not killed_test:
		killed_test = true
		for e in gm.enemies.duplicate():
			if e.position.distance_to(gm.player.position) < 260.0:
				e.hurt(99999.0, Vector2.RIGHT, 0.0, false)
	if OS.get_cmdline_user_args().has("--elevslope"):
		gm.player.hp = gm.player.max_hp
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--elevxy=") and shot_t > 0.5 and shot_t < 0.6 and world_on:
			var xy := str(a).substr(9).split(",")
			gm.player.position = Vector2(float(xy[0]), float(xy[1])) * 16.0
			print("QUOTA nel punto: ", elev_at(float(xy[0]), float(xy[1])))
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--elevseed=") and shot_t > 0.5 and shot_t < 0.6 and world_on:
			var sv: Vector2i = gm.SEEDS[int(str(a).substr(11))]
			var off := Vector2.ZERO
			if OS.get_cmdline_user_args().has("--elevoff"):
				off = Vector2(22, 0)
			if OS.get_cmdline_user_args().has("--elevslope"):
				var bestg := 0.0
				for dz in range(-60, 61, 2):
					for dx in range(-60, 61, 2):
						var qx := sv.x + dx
						var qz := sv.y + dz
						if not gm.inb(Vector2i(qx, qz)) or gm.grid[gm.idx(Vector2i(qx, qz))] == 0 or gm.road[gm.idx(Vector2i(qx, qz))] == 1:
							continue
						var gr := absf(elev_at(qx + 1.0, qz) - elev_at(qx - 1.0, qz)) + absf(elev_at(qx, qz + 1.0) - elev_at(qx, qz - 1.0))
						if gr > bestg:
							bestg = gr
							off = Vector2(dx, dz)
				print("PENDIO max=", bestg / 4.0, " a ", off)
			gm.player.position = (Vector2(sv) + off) * 16.0
			print("QUOTA nel punto: ", elev_at(sv.x + off.x, sv.y + off.y))
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--skinroom=") and shot_t > 0.5 and shot_t < 0.6:
			var ri := int(str(a).substr(11))
			if ri < gm.rooms.size():
				var rr: Rect2i = gm.rooms[ri]
				gm.player.position = (Vector2(rr.position) + Vector2(rr.size) * 0.5) * 16.0
		if str(a).begins_with("--skincam="):
			cam_h = float(str(a).substr(10))
			fixed_cam = true
	if OS.get_cmdline_user_args().has("--fxtest"):
		var pp: Vector2 = gm.player.position
		if fx_step == 0 and shot_t > 1.0:
			fx_step = 1
			gm.spawn_hazard(pp + Vector2(-70, -20), 40.0, 3.9, 0.3, 0.0, 0.0, Color(1.0, 0.3, 0.2))
			gm.spawn_hazard(pp + Vector2(60, -30), 30.0, 0.8, 9.0, 0.0, 0.5, Color(0.55, 0.9, 0.3))
			gm.spawn_hazard(pp + Vector2(0, -75), 34.0, 2.4, 0.3, 0.0, 0.0, Color(0.7, 0.35, 1.0))
		if shot_t > 2.4 + fx_step * 0.0 and fx_step >= 1 and int(shot_t * 2.0) != fx_last:
			fx_last = int(shot_t * 2.0)
			if shot_t < 8.0:
				gm.spawn_parrow(pp + Vector2(-20, 30), Vector2.from_angle(-0.9 + randf() * 0.3), 70.0, 1.0, 2.5, 3, Color(0.7, 0.4, 1.0), {}, 0.0, true)
				gm.spawn_parrow(pp + Vector2(20, 40), Vector2.from_angle(-2.2 + randf() * 0.3), 70.0, 1.0, 2.5, 3, Color(0.5, 0.8, 1.0), {"f": "staff", "a": ["gelo"]}, 0.0, true)
	if shot_t > 3.0 + shot_n * 2.0 and shot_n < 3:
		get_viewport().get_texture().get_image().save_png("user://skin_%d.png" % shot_n)
		shot_n += 1
	if shot_n >= 3:
		print("SKIN fps=", Engine.get_frames_per_second(), " dyn=", dyn.size(), " area=", gm.area, " enemies=", gm.enemies.size(), " props=", gm.props.size())
		get_tree().quit()


# ------------------------------------------------------------------ prima persona (prova): F7 nel mondo aperto
var fpv := false
var fpv_yaw := 0.0
var fpv_pitch := -0.04
var fpv_curve_saved := 0.017
var fpv_char_saved := 0


func fpv_set(on: bool) -> void:
	if on == fpv:
		return
	if on and (not world_on or (ed != null and ed.on) or str(gm.state) != "play"):
		return
	fpv = on
	if on:
		var fc: Vector2 = gm.player.face
		fpv_yaw = atan2(-fc.x, -fc.y)
		fpv_pitch = -0.04
		fpv_curve_saved = curve
		fpv_char_saved = char_mode
		char_mode = 1            # in prima persona i personaggi sono a blocchi (pixel dello sprite -> cubi), in piedi e di fronte
		exact_chars = true
		for k in dyn.keys():
			_drop_dyn(k)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		gm.say("PRIMA PERSONA (F7 PER TORNARE)")
	else:
		curve = fpv_curve_saved
		char_mode = fpv_char_saved
		exact_chars = char_mode < 2
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		cam.fov = 38.6
		cam.near = 2.0
		cam.far = 120.0
		cam.rotation_degrees = Vector3(-90, 0, 0)
		for k in dyn.keys():
			_drop_dyn(k)


## la camera diventa gli occhi dell'eroe: altezza 1.75, direzione dal mouse, niente curvatura del mondo
func _fpv_cam() -> void:
	if not world_on or str(gm.state) != "play" or (ed != null and ed.on):
		fpv_set(false)
		return
	curve = 0.0
	cam.fov = 78.0
	cam.near = 0.12
	cam.far = 260.0
	cam.position = Vector3(pos.x, elev_at(pos.x, pos.y) + 1.75, pos.y)
	cam.rotation = Vector3(fpv_pitch, fpv_yaw, 0.0)
	env.fog_density = 0.011
	env.fog_light_color = Color(0.07, 0.08, 0.12)


func _fpv_look(dt: float) -> void:
	var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var target: Enemy = gm.player.lock
	if target != null and is_instance_valid(target) and not target.dying and aim.length() <= 0.25:
		var delta: Vector2 = target.position - gm.player.position
		var target_yaw := atan2(-delta.x, -delta.y)
		fpv_yaw += clampf(angle_difference(fpv_yaw, target_yaw), -5.0 * dt, 5.0 * dt)
		var target_pos := target.position / Game.TS
		var target_height := elev_at(target_pos.x, target_pos.y) + 0.9
		var eye_height := elev_at(pos.x, pos.y) + 1.75
		var target_pitch := atan2(target_height - eye_height, delta.length() / Game.TS)
		fpv_pitch = move_toward(fpv_pitch, clampf(target_pitch, -1.2, 1.2), 5.0 * dt)
		return
	if target != null and aim.length() > 0.25:
		gm.player.lock = null
	if aim.length() <= 0.25:
		return
	fpv_yaw -= aim.x * 2.4 * dt
	fpv_pitch = clampf(fpv_pitch - aim.y * 1.8 * dt, -1.2, 1.2)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F6:
		open_cine_editor(ev.shift_pressed)
		return
	if cine != null and cine.active:
		get_viewport().set_input_as_handled()
		if cine.edit:
			if cine.ed != null:
				cine.ed.input(ev)
		elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]:
			cine.skip()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F10 and world_on and str(gm.state) == "play":
		start_cine("liberazione" if ev.shift_pressed else "ufo")      # scorciatoia per rivedere la sequenza dell'ufo (Shift = la liberazione) da qualunque partita (non serve rigiocare dall'inizio)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F7:
		fpv_set(not fpv)
		return
	if fpv and ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		fpv_yaw -= mm.relative.x * 0.0026
		fpv_pitch = clampf(fpv_pitch - mm.relative.y * 0.0026, -1.2, 1.2)
		return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F8:
		cycle_char_mode()


func cycle_char_mode() -> void:
	char_mode = (char_mode + 1) % 3
	exact_chars = char_mode < 2
	for k in dyn.keys():
		_drop_dyn(k)
	gm.say(["CUBETTI DALL'ALTO", "CUBETTI PIATTI (SPRITE ESATTI)", "PERSONAGGI STILIZZATI"][char_mode])


## anime e monete a terra: prismi luminosi che ruotano e ondeggiano (colore dal tipo, emissivi: non dipendono dalle luci)
var pick_mesh: Dictionary = {}


func _pickup_mesh(kind: String) -> ArrayMesh:
	if pick_mesh.has(kind):
		return pick_mesh[kind]
	var col := Color(0.9, 0.9, 0.9)
	if kind == "soul":
		col = Color(0.35, 1.0, 0.7)
	elif kind == "coin":
		col = Color(1.0, 0.82, 0.3)
	else:
		var tx = Game.tex(kind)
		if tx != null:
			var img: Image = (tx as Texture2D).get_image()
			if img != null:
				if img.is_compressed():
					img.decompress()
				var acc := Color(0, 0, 0, 0)
				var cnt := 0
				for yy in range(0, img.get_height(), 2):
					for xx in range(0, img.get_width(), 2):
						var px := img.get_pixel(xx, yy)
						if px.a > 0.5:
							acc += px
							cnt += 1
				if cnt > 0:
					col = Color(acc.r / cnt, acc.g / cnt, acc.b / cnt)
	var b := W3DBuilder.new()
	var top := Vector3(0, 0.5, 0)
	var bot := Vector3(0, -0.34, 0)
	for i in 4:
		var a0 := TAU * i / 4.0 + 0.4
		var a1 := a0 + TAU / 4.0
		var p0 := Vector3(cos(a0) * 0.26, 0.0, sin(a0) * 0.26)
		var p1 := Vector3(cos(a1) * 0.26, 0.0, sin(a1) * 0.26)
		var kt := 1.25 if i % 2 == 0 else 0.95
		b.tri(top, p0, p1, Color(minf(col.r * kt, 1.0), minf(col.g * kt, 1.0), minf(col.b * kt, 1.0), 0.05))
		b.tri(bot, p1, p0, Color(col.r * 0.65, col.g * 0.65, col.b * 0.65, 0.05))
	var m := b.mesh()
	pick_mesh[kind] = m
	return m


func _sync_pickup(n: Pickup, id: int) -> void:
	if not dyn.has(id):
		var pm := MeshInstance3D.new()
		pm.mesh = _pickup_mesh(n.kind)
		pm.material_override = mat_chr
		pm.scale = Vector3.ONE * 1.5
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		vp.add_child(pm)
		dyn[id] = {"node": pm, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "fxm", "src": weakref(n), "lp": n.position, "imp": false}
	var pn: Node3D = dyn[id]["node"]
	pn.position = Vector3(n.position.x / 16.0, 0.65 + sin(lamp_t * 5.0 + float(id % 7)) * 0.12, n.position.y / 16.0)
	pn.rotation.y = lamp_t * 2.5 + float(id % 7)
	dyn[id]["seen"] = lamp_t
	dyn[id]["lp"] = n.position


# ------------------------------------------------------------------ effetti di magie e armi in 3D
var fx_cache: Dictionary = {}


func _emis(c: Color, k := 1.0) -> Color:
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 0.05)


## anello piatto (onde d'urto degli incantesimi): raggio 1, si scala col raggio dell'effetto
func _ring_mesh(col: Color) -> ArrayMesh:
	var key := "ring|" + col.to_html(false)
	if fx_cache.has(key):
		return fx_cache[key]
	var b := W3DBuilder.new()
	var n := 40
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var o0 := Vector3(cos(a0), 0, sin(a0))
		var o1 := Vector3(cos(a1), 0, sin(a1))
		b.quad(o0, o1, o1 * 0.93, o0 * 0.93, _emis(col, 1.2))
		b.quad(o0 * 0.93, o1 * 0.93, o1 * 0.8, o0 * 0.8, _emis(col, 0.5))
	var m := b.mesh()
	fx_cache[key] = m
	return m


## nastro piatto lungo i punti di una linea 2D (fulmini, anelli): nucleo chiaro e alone piu' largo
func _ribbon_mesh(ln: Line2D) -> ArrayMesh:
	var b := W3DBuilder.new()
	var pts := ln.points
	var col := ln.default_color
	for pass_i in 2:
		var hw := 0.2 if pass_i == 0 else 0.07
		var c := _emis(col, 0.6) if pass_i == 0 else _emis(Color(1, 1, 1).lerp(col, 0.25), 1.0)
		var y := 0.0 if pass_i == 0 else 0.03
		for i in pts.size() - 1:
			var a := pts[i] / 16.0
			var d := pts[i + 1] / 16.0
			var dir := d - a
			if dir.length() < 0.001:
				continue
			var nrm := Vector2(-dir.y, dir.x).normalized() * hw
			b.quad(Vector3(a.x - nrm.x, y, a.y - nrm.y), Vector3(a.x + nrm.x, y, a.y + nrm.y), Vector3(d.x + nrm.x, y, d.y + nrm.y), Vector3(d.x - nrm.x, y, d.y - nrm.y), c)
	return b.mesh()


## proiettili fatti di luce (magie, bastoni, incantesimi nemici): niente coda a triangolo, ma nucleo + alone + scia luminosa
func _light_proj_col(n: Node) -> Variant:
	if n is PArrow:
		var pa := n as PArrow
		var fam := str(pa.weapon.get("f", ""))
		if not (pa.magic or fam == "staff"):
			return null
		for a in pa.weapon.get("a", []):
			match str(a):
				"fuoco": return Color(1.0, 0.5, 0.15)
				"gelo": return Color(0.6, 0.9, 1.0)
				"tuono": return Color(0.75, 0.88, 1.0)
				"veleno": return Color(0.45, 0.95, 0.3)
				"sangue": return Color(0.95, 0.12, 0.2)
		return pa.col
	if n is Projectile:
		var st := (n as Projectile).style
		if st in ["fire", "dark", "ice", "poison", "soul", "blood"]:
			return Projectile.LIGHT[st]
	return null


func _core_mesh() -> ArrayMesh:
	if fx_cache.has("core"):
		return fx_cache["core"]
	var b := W3DBuilder.new()
	b.blob(Vector3.ZERO, Vector3(0.13, 0.13, 0.13), _emis(Color(1, 1, 1), 1.0), 6, 3, 0.0, 0.0)
	var m := b.mesh()
	fx_cache["core"] = m
	return m


## ogni arma e ogni nemico ha il suo proiettile: asse lungo Z, la punta guarda verso -Z
func _proj_mesh(n: Node) -> ArrayMesh:
	var key := ""
	var col := Color(1.0, 0.8, 0.4)
	var fam := ""
	var aff := ""
	var magic := false
	if n is PArrow:
		var pa := n as PArrow
		col = pa.col
		magic = pa.magic
		fam = str(pa.weapon.get("f", ""))
		for a in pa.weapon.get("a", []):
			if str(a) in ["fuoco", "gelo", "tuono", "veleno", "sangue"]:
				aff = str(a)
				break
		key = "p|%s|%s|%s|%s" % [fam, aff, str(magic), col.to_html(false)]
	elif n is Projectile:
		var pj := n as Projectile
		col = Projectile.LIGHT[pj.style]
		fam = "e_" + pj.style
		key = "e|" + pj.style
	if fx_cache.has(key):
		return fx_cache[key]
	var b := W3DBuilder.new()
	var steel := Color(0.78, 0.8, 0.86)
	match fam:
		"bow":      # freccia: asta di legno, punta d'acciaio, impennaggio
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.35)), Vector3(0.05, 0.05, 0.95), Color(0.42, 0.3, 0.18), 0.05, 8)
			b.shard(Vector3(0, 0, -0.1), Vector3(0, 0, -0.42), 0.14, 0.0, steel, 0.5, 0.0, 0.0)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.78)), Vector3(0.22, 0.02, 0.18), Color(0.9, 0.85, 0.75), 0.05, 8)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.78)), Vector3(0.02, 0.22, 0.18), Color(0.9, 0.85, 0.75), 0.05, 8)
		"pistol", "smg":     # proiettile con scia incandescente
			b.shard(Vector3(0, 0, 0.55), Vector3(0, 0, -0.3), 0.07, 0.0, _emis(Color(1.0, 0.85, 0.4), 1.0), 0.5, 0.0, 0.0)
			b.shard(Vector3(0, 0, 0.1), Vector3(0, 0, -0.25), 0.04, 0.0, _emis(Color(1, 1, 0.9), 1.0), 0.5, 0.0, 0.0)
		"shotgun":      # pallini
			b.blob(Vector3.ZERO, Vector3(0.09, 0.09, 0.09), _emis(Color(1.0, 0.7, 0.3), 1.0), 5, 3, 0.0, 0.0)
		"laserpistol":    # raggio sottile
			b.shard(Vector3(0, 0, 1.0), Vector3(0, 0, -0.7), 0.1, 0.1, _emis(col, 0.9), 0.5, 0.0, 0.0)
			b.shard(Vector3(0, 0, 0.9), Vector3(0, 0, -0.6), 0.04, 0.04, _emis(Color(1, 1, 1), 1.0), 0.5, 0.0, 0.0)
		"rocket":      # razzo con fiamma di scarico
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0)), Vector3(0.2, 0.2, 0.7), Color(0.5, 0.52, 0.56), 0.05, 8)
			b.shard(Vector3(0, 0, -0.3), Vector3(0, 0, -0.65), 0.2, 0.0, Color(0.85, 0.2, 0.15), 0.5, 0.0, 0.0)
			b.shard(Vector3(0, 0, 0.35), Vector3(0, 0, 1.5), 0.26, 0.0, _emis(Color(1.0, 0.6, 0.2), 1.0), 0.5, 0.0, 0.0)
			b.shard(Vector3(0, 0, 0.35), Vector3(0, 0, 1.0), 0.13, 0.0, _emis(Color(1.0, 0.95, 0.6), 1.0), 0.5, 0.0, 0.0)
		"plasma":      # globo di plasma
			b.blob(Vector3.ZERO, Vector3(0.36, 0.36, 0.36), _emis(col, 0.8), 7, 4, 0.0, 0.04)
			b.blob(Vector3.ZERO, Vector3(0.2, 0.2, 0.2), _emis(Color(1, 1, 1).lerp(col, 0.3), 1.0), 6, 3, 0.0, 0.0)
		"staff":
			match aff:
				"fuoco":      # lingua di fuoco
					b.shard(Vector3(0, 0, 0.9), Vector3(0, 0, -0.45), 0.4, 0.05, _emis(Color(1.0, 0.45, 0.12), 1.0), 0.45, 0.0, 0.05)
					b.shard(Vector3(0, 0, 0.7), Vector3(0, 0, -0.3), 0.24, 0.02, _emis(Color(1.0, 0.8, 0.3), 1.0), 0.45, 0.0, 0.05)
					b.blob(Vector3(0, 0, -0.05), Vector3(0.14, 0.14, 0.2), _emis(Color(1.0, 0.95, 0.7), 1.0), 5, 3, 0.0, 0.0)
				"gelo":      # cristallo di ghiaccio
					b.shard(Vector3(0, 0, 0.5), Vector3(0, 0, -0.55), 0.26, 0.0, _emis(Color(0.7, 0.95, 1.0), 1.0), 0.6, 0.0, 0.0)
					b.shard(Vector3(0.12, 0, 0.3), Vector3(0.2, 0, -0.1), 0.1, 0.0, _emis(Color(0.5, 0.85, 1.0), 1.0), 0.6, 0.0, 0.0)
					b.shard(Vector3(-0.12, 0, 0.3), Vector3(-0.2, 0, -0.1), 0.1, 0.0, _emis(Color(0.5, 0.85, 1.0), 1.0), 0.6, 0.0, 0.0)
				"tuono":      # sfera elettrica con scintille
					b.blob(Vector3.ZERO, Vector3(0.22, 0.22, 0.22), _emis(Color(0.85, 0.92, 1.0), 1.0), 6, 3, 0.0, 0.0)
					for q in 5:
						var qa := TAU * q / 5.0
						b.shard(Vector3(0, 0, 0), Vector3(cos(qa) * 0.45, 0, sin(qa) * 0.45), 0.06, 0.0, _emis(Color(0.7, 0.85, 1.0), 1.0), 0.5, 0.0, 0.0)
				"veleno":      # goccia verde e velenosa
					b.blob(Vector3.ZERO, Vector3(0.24, 0.24, 0.3), _emis(Color(0.45, 0.95, 0.3), 0.9), 6, 4, 0.0, 0.05)
					b.shard(Vector3(0, 0, 0.2), Vector3(0, 0, 0.8), 0.18, 0.0, _emis(Color(0.35, 0.7, 0.2), 0.8), 0.5, 0.0, 0.0)
				"sangue":      # sfera rossa
					b.blob(Vector3.ZERO, Vector3(0.26, 0.26, 0.26), _emis(Color(0.85, 0.1, 0.15), 1.0), 6, 4, 0.0, 0.04)
					b.shard(Vector3(0, 0, 0.2), Vector3(0, 0, 0.8), 0.16, 0.0, _emis(Color(0.55, 0.05, 0.1), 1.0), 0.5, 0.0, 0.0)
				_:      # sfera d'ombra viola con coda
					b.blob(Vector3.ZERO, Vector3(0.26, 0.26, 0.26), _emis(col, 1.0), 6, 4, 0.0, 0.04)
					b.shard(Vector3(0, 0, 0.15), Vector3(0, 0, 0.95), 0.2, 0.0, _emis(col, 0.55), 0.5, 0.0, 0.0)
		"e_arrow":
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.3)), Vector3(0.05, 0.05, 0.8), Color(0.45, 0.32, 0.2), 0.05, 8)
			b.shard(Vector3(0, 0, -0.1), Vector3(0, 0, -0.38), 0.13, 0.0, steel, 0.5, 0.0, 0.0)
		"e_knife":
			b.shard(Vector3(0, 0, 0.3), Vector3(0, 0, -0.4), 0.16, 0.0, steel, 0.4, 0.0, 0.0)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.4)), Vector3(0.07, 0.07, 0.25), Color(0.4, 0.28, 0.16), 0.05, 8)
		"e_fire":
			b.shard(Vector3(0, 0, 0.7), Vector3(0, 0, -0.3), 0.3, 0.0, _emis(Color(1.0, 0.4, 0.12), 1.0), 0.45, 0.0, 0.05)
			b.blob(Vector3.ZERO, Vector3(0.14, 0.14, 0.14), _emis(Color(1.0, 0.85, 0.4), 1.0), 5, 3, 0.0, 0.0)
		"e_ice":
			b.shard(Vector3(0, 0, 0.4), Vector3(0, 0, -0.5), 0.2, 0.0, _emis(Color(0.7, 0.95, 1.0), 1.0), 0.6, 0.0, 0.0)
		_:      # magia generica: sfera luminosa con coda nel colore dell'effetto
			b.blob(Vector3.ZERO, Vector3(0.22, 0.22, 0.22), _emis(col, 1.0), 6, 3, 0.0, 0.03)
			b.shard(Vector3(0, 0, 0.1), Vector3(0, 0, 0.8), 0.16, 0.0, _emis(col, 0.55), 0.5, 0.0, 0.0)
	var m := b.mesh()
	fx_cache[key] = m
	return m


# ------------------------------------------------------------------ cinematica dell'ufo (w3d_cine.gd)
var cine: W3DCine
var job_boost := false
var cine_t0 := 0.0
var cam_extra := 0.0            # vista piu' alta (assalto al fienile)
var cine_test := 0


var sing_stage := 0


func _sing_test() -> void:
	if cine_test != 2 or not world_on or lamp_t < 5.0:
		if sing_stage == 0:
			return
	var f: Dictionary = Story.flags(gm)
	match sing_stage:
		0:
			sing_stage = 1
			f[W3DCine.FLAG] = true
			gm.player.position = gm.cell_pos(gm.free_near(Vector2i(gm.SEEDS[0]) + Vector2i(8, 0)))
			f["dev_x"] = gm.player.position.x / 16.0
			f["dev_y"] = gm.player.position.y / 16.0
			gm.add_npc("fuggiasco", Vector2i(gm.player.position / 16.0) + Vector2i(3, 1))
			cine_t0 = lamp_t + 3.0
			print("SING: flag ufo ok, eroe al villaggio, hp max prima=", gm.player.max_hp)
		1:
			if lamp_t > cine_t0:
				sing_stage = 2
				Story.update(gm, 0.1)
				print("SING dopo il recupero: sing=", Story.sing(gm), " chrono=", Story.is_done(gm, Story.CHRONO), " glitch=", snappedf(Story.glitch_level(gm), 0.01))
				cine_t0 = lamp_t + 3.0
		2:
			if lamp_t > cine_t0:
				sing_stage = 3
				Story.update(gm, 0.1)
				get_viewport().get_texture().get_image().save_png("user://sing_title.png")
				gm.summon()
				print("SING dopo il tasto: sing=", Story.sing(gm))
				Story.update(gm, 0.1)
				print("SING potenziato: boost=", gm.player.boost, " hp max=", gm.player.max_hp, " danno=", snappedf(gm.player.dmg(), 0.1), " vel=", snappedf(gm.player.speed, 0.1))
				cine_t0 = lamp_t + 12.0
		3:
			if lamp_t > cine_t0:
				sing_stage = 4
				print("SING oggetti nel villaggio: ", fut.props.get(W3DFuture.SK, []).size(), " glitch=", snappedf(Story.glitch_level(gm), 0.01))
				get_viewport().get_texture().get_image().save_png("user://sing_power.png")
				Story.complete_invasion(gm)
				Story.update(gm, 0.1)
				cine_t0 = lamp_t + 2.0
		4:
			if lamp_t > cine_t0:
				get_viewport().get_texture().get_image().save_png("user://sing_end.png")
				print("SING dopo la liberazione: sing=", Story.sing(gm), " boost=", gm.player.boost, " hp max=", gm.player.max_hp, " oggetti=", fut.props.get(W3DFuture.SK, []).size(), " glitch=", snappedf(Story.glitch_level(gm), 0.01))
				get_tree().quit()


var wreck_cine: W3DCine
var edit_id := "ufo"


func _edit_next(shift: bool) -> String:
	var ids: Array = W3DCine.load_all().keys()
	if ids.is_empty():
		return "ufo"
	if shift or not ids.has(edit_id):
		edit_id = ids[(ids.find(edit_id) + 1) % ids.size()]
	return edit_id


func open_cine_editor(next := false) -> bool:
	if cine != null and cine.active:
		if cine.edit:
			cine.finish(false)
			return true
		return false
	if not world_on or str(gm.state) != "play":
		return false
	return start_cine(_edit_next(next), true)


func cine_prewarm() -> void:
	var c := W3DCine.new()
	c.prewarm(self)


## avvia una cutscene (id nel file cutscenes.json); i resti dell'ufo vivono nella loro istanza (wreck_cine)
func start_cine(cid := "ufo", editing := false) -> bool:
	if cine != null and cine.active:
		return false
	var c := W3DCine.new()
	if not c.start(self, cid, editing):
		return false
	cine = c
	if cid == "ufo":
		wreck_cine = c
	return true


func _cine_tick(dt: float) -> void:
	if (cine == null or not cine.active) and str(gm.state) == "cine":
		gm.state = "play"      # rete di sicurezza: mai restare bloccati nello stato della sequenza
	if (cine == null or not cine.active) and world_on and Story.is_done(gm, W3DCine.FLAG) and (wreck_cine == null or not wreck_cine.wreck_alive()):
		if wreck_cine == null:
			wreck_cine = W3DCine.new()
		wreck_cine.restore_wreck(self)      # i resti ricompaiono se il mondo viene ricostruito (morte, cambio zona, nuova partita)
	if cine == null and not (OS.get_cmdline_user_args().has("--cinetest") or OS.get_cmdline_user_args().has("--cinereal") or OS.get_cmdline_user_args().has("--cineedit") or OS.get_cmdline_user_args().has("--singtest") or OS.get_cmdline_user_args().has("--barnshot")):
		return
	var real := OS.get_cmdline_user_args().has("--cinereal")
	var test := OS.get_cmdline_user_args().has("--cinetest") or OS.get_cmdline_user_args().has("--singtest") or OS.get_cmdline_user_args().has("--barnshot") or real or OS.get_cmdline_user_args().has("--cineedit")
	if test and (cine == null or not cine.active) and cine_test == 0 and lamp_t > 2.0:
		# prova: porta l'eroe lontano dal villaggio, nel mondo, e lancia la sequenza
		cine_test = 1
		DirAccess.make_dir_recursive_absolute("user://cine")
		if gm.area != "world":
			gm.persist["bosses"]["boss_jailer"] = true
			gm._do_change("world")
		var v: Vector2i = gm.SEEDS[0]
		gm.player.position = gm.cell_pos(gm.free_near(v + Vector2i(-100, 30)))
		gm.state = "play"
		cine = W3DCine.new()
		cine_test = 2
		return
	if real and cine_test == 2 and world_on and lamp_t > 5.0:
		# prova del trigger REALE: 70 s di cammino simulato verso il villaggio, attraverso Story.update
		cine_test = 3
		Story.flags(gm)[Story.ESCAPE_INTRO] = true
		var vp2: Vector2 = gm.cell_pos(gm.SEEDS[0])
		var steps := 0
		while steps < 1200 and not (cine != null and cine.active):
			gm.player.position += (vp2 - gm.player.position).normalized() * 4.0
			Story.update(gm, 0.1)
			steps += 1
		print("CINE reale: partita dopo ", steps * 0.1, " s di cammino simulato; attiva=", cine != null and cine.active, " distanza dal villaggio=", int(gm.player.position.distance_to(vp2) / 16.0))
	if OS.get_cmdline_user_args().has("--singtest"):
		_sing_test()
		return
	if OS.get_cmdline_user_args().has("--barnshot") and cine_test >= 2 and world_on and lamp_t > 5.0:
		if cine_test == 2:
			cine_test = 8
			print("BARN granaio a ", gm.barn_pos, " villaggio ", gm.SEEDS[0], " distanza ", snappedf(gm.barn_pos.distance_to(Vector2(gm.SEEDS[0])), 0.1))
			gm.player.max_hp = 99999.0
			gm.player.hp = 99999.0
			gm.player.position = (gm.barn_pos + Vector2(0.0, 9.0)) * 16.0
			cine_t0 = lamp_t + 7.0
		elif cine_test == 8 and lamp_t > cine_t0:
			get_viewport().get_texture().get_image().save_png("user://barn.png")
			get_tree().quit()
		return
	if test and cine_test == 2 and world_on and lamp_t > 5.0:
		cine_test = 6
		cine_prewarm()          # come nel gioco: il precarico parte ~30 s prima dell'ufo
		cine_t0 = lamp_t + 30.0
	if OS.get_cmdline_user_args().has("--cineedit") and cine_test == 6 and lamp_t > cine_t0 - 25.0:
		cine_test = 7
		cine.start(self, "ufo", true)
		cine.seek(8.5)
		cine_t0 = lamp_t + 5.0
	if cine_test == 7 and lamp_t > cine_t0:
		get_viewport().get_texture().get_image().save_png("user://cine_edit.png")
		get_tree().quit()
	if test and cine_test == 6 and lamp_t > cine_t0:
		cine_test = 3
		var tid := "ufo"
		for ua in OS.get_cmdline_user_args():
			if str(ua).begins_with("--cineid="):
				tid = str(ua).substr(9)
		start_cine(tid)
	if cine != null and cine.active:
		var step := 1.0 / 15.0 if test else dt
		cine.update(step)
		if test and not real and cine.active:
			var img := get_viewport().get_texture().get_image()
			img.resize(640, 360)
			img.save_png("user://cine/f_%05d.png" % cine.frame_n)
			cine.frame_n += 1
	elif test and cine_test == 3:
		print("CINE finita: frames=", cine.frame_n, " stato=", gm.state, " eroe=", gm.player.position / 16.0)
		if real:
			# senza apparecchio niente Cronotone; poi l'eroe lo raccoglie
			gm.summon()
			print("CINE senza apparecchio: ", gm.msg, " | obiettivo: ", gm.objective(), " | frecce: ", gm.obj_targets().map(func(q): return q["n"]))
			var dv: Variant = Story.device_cell(gm)
			gm.player.position = (dv as Vector2) * 16.0 + Vector2(40, 0)
			Story.update(gm, 0.1)
			print("CINE lontano (2.5 celle): chrono=", Story.is_done(gm, Story.CHRONO))
			gm.player.position = (dv as Vector2) * 16.0 + Vector2(10, 0)
			Story.update(gm, 0.1)
			print("CINE vicino: chrono=", Story.is_done(gm, Story.CHRONO), " msg=", gm.msg, " obiettivo=", gm.objective().substr(0, 40))
			cine_test = 4
			gm.persist["chrono"] = {}
			gm.summon()
			print("CINE evocazione dopo il recupero: energia=", gm.player.chrono)
		get_tree().quit()
