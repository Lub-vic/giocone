class_name W3DSkin
extends W3D
## "Pelle 3D" del gioco vero: la logica, i nemici, le collisioni, i colpi, la vita, le missioni restano quelli del gioco 2D.
## Questo nodo legge lo stato del gioco ogni fotogramma e lo disegna con il motore 3D (muri e pavimenti dal reticolo del dungeon,
## oggetti e personaggi dai loro sprite, piu' i modelli a schegge per eroe e nemici noti). Al momento copre dungeon e interni;
## nel mondo aperto torna alla grafica 2D.
## F9 attiva/disattiva.  1 unita' 3D = 16 pixel del gioco 2D.

const FLOOR_COL := [Color(0.20, 0.19, 0.20), Color(0.17, 0.19, 0.14), Color(0.14, 0.17, 0.14), Color(0.14, 0.17, 0.15), Color(0.23, 0.22, 0.24), Color(0.40, 0.45, 0.52), Color(0.20, 0.10, 0.09)]
const WALL_COL := [Color(0.20, 0.19, 0.22), Color(0.17, 0.19, 0.15), Color(0.14, 0.17, 0.14), Color(0.14, 0.18, 0.16), Color(0.22, 0.21, 0.25), Color(0.38, 0.42, 0.50), Color(0.22, 0.11, 0.10)]
const KNOWN := ["goblin", "goblin_archer", "skeleton", "skel_archer", "ghoul", "kobold", "orc", "wolf"]

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


func _ready() -> void:
	if not W3D.gp_added:
		RenderingServer.global_shader_parameter_add("w3d_player", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
		W3D.gp_added = true
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
	cam_h = 22.0
	_build_view()
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
	var pb := W3DBuilder.new()
	pb.rn.seed = 14
	pb.sat = 1.75
	pb.con = 1.4
	pb.gain = 1.3
	if gm.rooms is Array and gm.rooms.size() > 0:
		_build_decor(pb, decor_lights)
	if wood and gm.rooms is Array:
		# case: una lampada a olio al centro di ogni stanza, luce calda e bassa
		for rw3 in gm.rooms:
			var rc3: Rect2i = rw3
			var cc3 := Vector2(rc3.position) + Vector2(rc3.size) * 0.5
			decor_lights.append(Vector3(cc3.x, 1.7, cc3.y))
			ob.cyl(Transform3D(Basis.IDENTITY, Vector3(cc3.x, 0.0, cc3.y)), 0.18, 0.12, 0.5, 6, Color(0.2, 0.12, 0.07), 0.08)
			ob.box(Transform3D(Basis.IDENTITY, Vector3(cc3.x, 0.62, cc3.y)), Vector3(0.16, 0.2, 0.16), Color(1.0, 0.75, 0.4, 0.15), 0.0, 8)
	for pr in [[fb, false], [wb, true], [ob, true], [pb, true]]:
		var bld: W3DBuilder = pr[0]
		if bld.v.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bld.mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pr[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		static_root.add_child(mi)


## elementi d'atmosfera: torce con fiamma, travi con lanterne sui corridoi, cerchi runici, candele
func _extras(fb: W3DBuilder, ob: W3DBuilder, wb: W3DBuilder, mw: int, mh: int) -> void:
	# torce: staffa di ferro, fiamma emissiva a schegge, anello di bagliore
	for f in gm.flick:
		var l = f[0]
		if not is_instance_valid(l):
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
		ob.box(Transform3D(Basis.IDENTITY, Vector3(gp.x, 1.2, gp.y)), Vector3(0.1, 0.9, 0.1), Color(0.18, 0.15, 0.13), 0.1, 8)
		ob.cyl(Transform3D(Basis.IDENTITY, Vector3(gp.x, 1.62, gp.y)), 0.13, 0.17, 0.2, 6, Color(0.2, 0.17, 0.15), 0.1)
		ob.shard(Vector3(gp.x, 1.7, gp.y), Vector3(gp.x, 2.45, gp.y), 0.17, 0.15, Color(1.0, 0.55, 0.18, 0.08), 0.35, 0.0, 0.1)
		ob.shard(Vector3(gp.x, 1.75, gp.y), Vector3(gp.x + 0.02, 2.2, gp.y), 0.09, 0.08, Color(1.0, 0.9, 0.55, 0.0), 0.4, 0.0, 0.1)
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
			if wl and wr and (y % 5 == 0):
				wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 3.15, y + 0.5)), Vector3(1.9, 0.3, 0.3), Color(0.20, 0.13, 0.09), 0.14, 8)
				wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 3.05, y + 0.5)), Vector3(0.3, 0.12, 0.5), Color(0.15, 0.1, 0.07), 0.1, 8)
				if _hash2(x, y, 90) < 0.5:
					ob.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 2.65, y + 0.5)), Vector3(0.04, 0.8, 0.04), Color(0.2, 0.2, 0.22), 0.1, 8)
					ob.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 2.15, y + 0.5)), Vector3(0.26, 0.34, 0.26), Color(1.0, 0.72, 0.4, 0.22), 0.0, 8)
			elif wu and wd and (x % 5 == 0):
				wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 3.15, y + 0.5)), Vector3(0.3, 0.3, 1.9), Color(0.20, 0.13, 0.09), 0.14, 8)
				wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, 3.05, y + 0.5)), Vector3(0.5, 0.12, 0.3), Color(0.15, 0.1, 0.07), 0.1, 8)
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
				for q in 3:
					var ox := 0.3 + _hash2(x, y, 60 + q) * 0.4
					var oz := 0.3 + _hash2(x, y, 70 + q) * 0.4
					ob.cyl(Transform3D(Basis.IDENTITY, Vector3(x + ox, 0.0, y + oz)), 0.05, 0.045, 0.16 + q * 0.04, 5, Color(0.8, 0.76, 0.65), 0.1)
					ob.shard(Vector3(x + ox, 0.2 + q * 0.04, y + oz), Vector3(x + ox, 0.34 + q * 0.04, y + oz), 0.04, 0.03, Color(1.0, 0.8, 0.4, 0.0), 0.4, 0.0, 0.0)


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


func _m_shelf(b: W3DBuilder, base: Vector3, nrm: Vector3, yaw: float, r: RandomNumberGenerator) -> void:
	# libreria addossata al muro (profondita' 0.28: dentro la fascia dove il giocatore non arriva)
	var tan := Vector3(-nrm.z, 0, nrm.x)
	b.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.14 + Vector3(0, 0.85, 0)), Vector3(0.28, 1.7, 0.95), _k(WOOD_D, 0.9), 0.14, 8)
	for row in 4:
		for q in 6:
			var h := r.randf_range(0.18, 0.3)
			var col := Color(r.randf_range(0.2, 0.5), r.randf_range(0.08, 0.2), r.randf_range(0.08, 0.2))
			b.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.18 + tan * (q - 2.5) * 0.14 + Vector3(0, 0.3 + row * 0.38 + h * 0.5, 0)), Vector3(0.2, h, 0.1), col, 0.2, 8)


func _decor_place(room: Rect2i, fw: int, fh: int, occ: Dictionary, r: RandomNumberGenerator, margin := 2) -> Dictionary:
	var inner := room.grow(-margin)
	if inner.size.x < fw or inner.size.y < fh:
		return {}
	for attempt in 30:
		var cx := r.randi_range(inner.position.x, inner.end.x - fw)
		var cy := r.randi_range(inner.position.y, inner.end.y - fh)
		var ok := true
		for dy in range(-1, fh + 1):
			for dx in range(-1, fw + 1):
				var c := Vector2i(cx + dx, cy + dy)
				if occ.has(c) or gm.block.has(c) or gm.reserved.has(c) or not gm.is_floor(c):
					ok = false
					break
				if dx >= 0 and dx < fw and dy >= 0 and dy < fh and gm.has_carpet(c):
					ok = false
					break
			if not ok:
				break
		if ok and Vector2(cx + fw * 0.5, cy + fh * 0.5).distance_to(gm.player.position / 16.0) < 3.5:
			ok = false
		if not ok:
			continue
		for dy in fh:
			for dx in fw:
				occ[Vector2i(cx + dx, cy + dy)] = true
				gm.block[Vector2i(cx + dx, cy + dy)] = true
		return {"x": cx, "y": cy}
	return {}


func _build_decor(b: W3DBuilder, lamps: Array) -> void:
	var occ: Dictionary = {}
	var ri := 0
	for room in gm.rooms:
		ri += 1
		var r := RandomNumberGenerator.new()
		r.seed = hash(Vector3i(room.position.x, room.position.y, int(gm.world_seed)))
		var theme := _theme_of(room)
		var plan: Array = []
		match theme:
			0:   # cripta: pochi grandi sarcofagi, una statua
				plan = ["sarc", "sarc", "statue"]
			1:   # tesoro: scrigni e fuochi
				plan = ["chest", "chest", "chest", "brazier"]
			2:   # prigione: cavalletti e barili, gabbie appese
				plan = ["rack", "rack", "barrels"]
			3:   # santuario: altare e due fuochi
				plan = ["altar", "brazier", "brazier"]
			_:   # magazzino: barili e un paio di casse
				plan = ["barrels", "barrels", "chest"]
		for item in plan:
			var yaw := 0.0 if r.randf() < 0.5 else PI * 0.5
			var fw := 1
			var fh := 1
			var sc := 1.4
			match item:
				"sarc":
					sc = 1.5
					fw = 3 if yaw == 0.0 else 2
					fh = 2 if yaw == 0.0 else 3
				"coffin":
					sc = 1.5
					fw = 3 if yaw == 0.0 else 1
					fh = 1 if yaw == 0.0 else 3
				"rack":
					sc = 1.5
					fw = 3 if yaw == 0.0 else 1
					fh = 1 if yaw == 0.0 else 3
				"altar":
					sc = 1.5
					fw = 4 if yaw == 0.0 else 3
					fh = 3 if yaw == 0.0 else 4
				"chest", "barrels":
					sc = 1.4 if item == "chest" else 1.3
					fw = 2 if yaw == 0.0 else 1
					fh = 1 if yaw == 0.0 else 2
				"brazier":
					sc = 1.3
				"statue":
					sc = 1.35
			var spot := _decor_place(room, fw, fh, occ, r)
			if spot.is_empty():
				continue
			var cx: float = float(spot["x"]) + fw * 0.5
			var cz: float = float(spot["y"]) + fh * 0.5
			var p := Vector3(cx, 0, cz)
			var ya := -yaw if yaw != 0.0 else 0.0
			dscale = sc
			b.sz = sc
			match item:
				"sarc":
					_m_sarcophagus(b, p, ya, r.randf() < 0.35)
				"coffin":
					_m_coffin(b, p, ya, r.randf() < 0.5)
				"altar":
					_m_altar(b, p, ya, lamps)
				"statue":
					_m_statue(b, p, r.randf() * TAU)
				"brazier":
					_m_brazier(b, p, lamps)
				"chest":
					_m_chest(b, p, r.randf_range(-0.4, 0.4) + (0.0 if yaw == 0.0 else PI * 0.5), r.randf() < 0.2)
				"barrels":
					_m_barrels(b, p, r.randf() * TAU, r)
				"rack":
					_m_rack(b, p, ya)
		# gabbie appese e ossa, senza collisione
		if theme == 2:
			for q in 2:
				var cx2 := r.randf_range(room.position.x + 2.0, room.end.x - 2.0)
				var cz2 := r.randf_range(room.position.y + 2.0, room.end.y - 2.0)
				dscale = 1.3
				b.sz = 1.3
				_m_cage(b, Vector3(cx2, 0, cz2), lamps)
		dscale = 1.0
		b.sz = 1.3
		if theme == 2:
			for q in 5:
				var bx := r.randf_range(room.position.x + 1.0, room.end.x - 1.0)
				var bz := r.randf_range(room.position.y + 1.0, room.end.y - 1.0)
				var rs := r.randf_range(0.5, 1.1)
				b.quad(Vector3(bx - rs, 0.026, bz - rs * 0.7), Vector3(bx + rs, 0.026, bz - rs * 0.5), Vector3(bx + rs * 0.8, 0.026, bz + rs), Vector3(bx - rs, 0.026, bz + rs * 0.6), Color(0.28, 0.03, 0.04))
		elif theme == 1:
			for q in 14:
				var cx3 := r.randf_range(room.position.x + 1.5, room.end.x - 1.5)
				var cz3 := r.randf_range(room.position.y + 1.5, room.end.y - 1.5)
				b.box(Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(cx3, 0.04, cz3)), Vector3(0.14, 0.03, 0.14), Color(1.0, 0.78, 0.25, 0.3), 0.0, 8)
		elif theme == 4:
			for q in 8:
				var sx := r.randf_range(room.position.x + 1.0, room.end.x - 1.0)
				var sz := r.randf_range(room.position.y + 1.0, room.end.y - 1.0)
				b.box(Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(sx, 0.03, sz)), Vector3(0.9, 0.04, 0.12), Color(0.42, 0.34, 0.15), 0.18, 8)
		for q in r.randi_range(0, 2):
			var sp := Vector3(r.randf_range(room.position.x + 1.5, room.end.x - 1.5), 0, r.randf_range(room.position.y + 1.5, room.end.y - 1.5))
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
		if hh > 0.3 and hh < 0.44:
			# pilastro addossato: base, fusto a sei lati, capitello (sporge solo 0.3: dentro la fascia dove il giocatore non arriva)
			var pb := base + nrm * 0.15
			wb.box(Transform3D(Basis(Vector3.UP, yaw), pb + Vector3(0, 0.15, 0)), Vector3(0.34, 0.3, 0.5), _k(wc, 0.8), 0.12, 8)
			wb.cyl(Transform3D(Basis.IDENTITY, pb + Vector3(0, 0.3, 0)), 0.2, 0.17, h - 0.8, 6, _k(wc, 1.2), 0.14)
			wb.box(Transform3D(Basis(Vector3.UP, yaw), pb + Vector3(0, h - 0.4, 0)), Vector3(0.36, 0.3, 0.5), _k(wc, 0.85), 0.12, 8)
		elif hh > 0.44 and hh < 0.5:
			for q in 5:
				ob.rock(base + nrm * 0.1 + tan * (q - 2) * 0.18 + Vector3(0, 0.95, 0), Vector3(0.17, 0.17, 0.17), Color(0.8, 0.76, 0.66), 0.08, 0.2, hh * 40.0 + q)
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.1 + tan * (q - 2) * 0.18 + Vector3(0, 0.85, 0)), Vector3(0.1, 0.06, 0.1), Color(0.05, 0.04, 0.05), 0.0, 8)
		if hh < 0.05:
			# nicchia con teschio e un lumicino
			wb.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.02 + Vector3(0, 1.4, 0)), Vector3(0.1, 0.8, 0.55), Color(0.02, 0.015, 0.02), 0.0, 8)
			ob.rock(base + nrm * 0.12 + Vector3(0, 1.2, 0), Vector3(0.3, 0.3, 0.3), Color(0.8, 0.76, 0.65), 0.08, 0.2, hh * 50.0)
			ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.12 + tan * 0.18 + Vector3(0, 1.1, 0)), Vector3(0.07, 0.12, 0.07), Color(1.0, 0.85, 0.5, 0.15), 0.0, 8)
		elif hh < 0.1:
			# stendardo di stoffa strappata, rosso o blu scuro
			var cc := Color(0.45, 0.08, 0.1) if _hash2(x, y, 7) > 0.5 else Color(0.12, 0.17, 0.4)
			ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.06 + Vector3(0, h - 0.5, 0)), Vector3(0.05, 0.08, 0.9), Color(0.2, 0.15, 0.1), 0.1, 8)
			var t0 := base + nrm * 0.08 + tan * -0.34 + Vector3(0, h - 0.55, 0)
			var t1 := base + nrm * 0.08 + tan * 0.34 + Vector3(0, h - 0.55, 0)
			ob.quad(t0, t1, t1 + Vector3(0, -1.5, 0), t0 + Vector3(0, -1.5, 0), cc)
			ob.tri(t0 + Vector3(0, -1.5, 0), t1 + Vector3(0, -1.5, 0), (t0 + t1) * 0.5 + Vector3(0, -1.95, 0), _k(cc, 0.8))
		elif hh < 0.16:
			# catene appese con anello
			for q in 3:
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.07 + tan * (q - 1) * 0.28 + Vector3(0, h - 0.9, 0)), Vector3(0.05, 1.5 - q * 0.3, 0.05), Color(0.2, 0.2, 0.22), 0.1, 8)
				ob.box(Transform3D(Basis(Vector3.UP, yaw), base + nrm * 0.08 + tan * (q - 1) * 0.28 + Vector3(0, h - 1.7 + q * 0.3, 0)), Vector3(0.14, 0.14, 0.14), Color(0.28, 0.28, 0.3), 0.1, 8)
		elif hh < 0.22:
			# ragnatela all'angolo alto
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
		if not is_instance_valid(l):
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
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
	hero_light.position = Vector3(pos.x, 3.0, pos.y)
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


func _sync_bubble(n: ChronoBubble) -> void:
	var id: int = n.get_instance_id()
	if not bub_nodes.has(id):
		var root := Node3D.new()
		vp.add_child(root)
		var col: Color = n.col
		var nd := {"root": root, "seen": 0.0, "src": weakref(n)}
		nd["disc"] = _bub_mi(root, "disc", col)
		nd["ring"] = _bub_mi(root, "ring", col)
		nd["ring2"] = _bub_mi(root, "arc", Color(1, 1, 1))
		nd["ring3"] = _bub_mi(root, "arc", col)
		nd["arms"] = _bub_mi(root, "arms", col)
		nd["hand"] = _bub_mi(root, "hand", Color(1, 1, 1))
		nd["hand2"] = _bub_mi(root, "hand", col)
		var ticks: Array = []
		for i in 12:
			ticks.append(_bub_mi(root, "tick", Color(1, 1, 1)))
		nd["ticks"] = ticks
		var sparks: Array = []
		for i in 6:
			sparks.append(_bub_mi(root, "spark", Color(1, 1, 1)))
		nd["sparks"] = sparks
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
	pr.position = Vector3(p2.x / 16.0, 0.9, p2.y / 16.0)
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


func _make_generic(n: Node2D, spr: Sprite2D) -> Node3D:
	var pk := str(n.get("kind")) if n.get("kind") != null else ""
	if pk != "" and not (n is Enemy or n is Villager or n is Ally or n is Critter) and W3DProps.ok(pk):
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
	mi.material_override = mat_chr if (n is Enemy or n is Villager or n is Ally or n is Critter) else mat
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
	var key := "exflat_%d" % spr.texture.get_rid().get_id()
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
		if iw >= 48:
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
	var func_prop: bool = n is Prop and not bool((n as Prop).scene)
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
		var chr := n is Enemy or n is Villager or n is Ally or n is Critter or is_player or (n is Prop and str((n as Prop).kind) == "elder")
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
			node = _make_generic(n2, spr)
		var okey := ""
		if is_player:
			okey = "hero"
		elif n is Enemy:
			okey = "enemy"
		elif n is Ally:
			okey = "ally"
		elif n is Villager:
			okey = "npc"
		if okey != "" and tdn == "":
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
			node3.visible = p.spr.visible or not (p.veh as Dictionary).is_empty()
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
				var rm := MeshInstance3D.new()
				rm.mesh = ring_m
				rm.material_override = mat_chr
				vp.add_child(rm)
				dyn[id] = {"node": rm, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "hazard"}
			var rn3: Node3D = dyn[id]["node"]
			var prog := clampf(h.t / maxf(h.delay, 0.01), 0.0, 1.0)
			rn3.position = Vector3(h.position.x / 16.0, 0.0, h.position.y / 16.0)
			rn3.scale = Vector3.ONE * (h.radius / 16.0) * (0.35 + 0.65 * prog if h.t < h.delay else 1.0)
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
				pm.mesh = _proj_mesh(n)
				pm.material_override = mat_chr
				var sc := 1.0
				if n is Pickup:
					sc = 0.6
				pm.scale = Vector3.ONE * sc
				vp.add_child(pm)
				dyn[id] = {"node": pm, "model": false, "seen": 0.0, "last": Vector2.ZERO, "ph": 0.0, "flow": 0.0, "kind": "fxm", "src": weakref(n), "lp": (n as Node2D).position, "imp": not (n is Pickup)}
			var pn: Node3D = dyn[id]["node"]
			var n2 := n as Node2D
			pn.position = Vector3(n2.position.x / 16.0, 0.9, n2.position.y / 16.0)
			if n is Projectile or n is PArrow:
				pn.rotation.y = atan2(-(n as Node2D).transform.x.x, (n as Node2D).transform.x.y) if false else -n2.rotation - PI * 0.5
			else:
				pn.rotation.y += 0.2
				pn.position.y = 0.6 + sin(lamp_t * 6.0 + float(id % 7)) * 0.1
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
	var wp := Vector3(lb.position.x / 16.0 + 0.5, 1.6 + lb.position.y * 0.0, lb.position.y / 16.0)
	var sp: Vector2 = cam.unproject_position(wp)
	var k := Vector2(960.0, 540.0) / Vector2(vp.size)
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
var wchunks: Dictionary = {}
var world_on := false


func _wtile_col(t: int) -> Color:
	match t:
		Game.T_TERRA: return Color(0.22, 0.18, 0.13)
		Game.T_CIMITERO: return Color(0.15, 0.19, 0.15)
		Game.T_PALUDE: return Color(0.11, 0.19, 0.14)
		Game.T_NEVE: return Color(0.46, 0.50, 0.58)
		Game.T_LAVA: return Color(0.55, 0.14, 0.04, 0.6)
		Game.T_ROCCIAG: return Color(0.24, 0.24, 0.27)
		Game.T_SENTIERO: return Color(0.30, 0.26, 0.21)
		Game.T_SANGUE: return Color(0.22, 0.07, 0.07)
	return Color(0.2, 0.19, 0.2)


## altezza del terreno: rilievo dolce, piatto vicino a strade, ponti e acqua
func _wh(vx: float, vz: float) -> float:
	var cx := floori(vx)
	var cz := floori(vz)
	var rd := 3.0
	for dz in range(-1, 1):
		for dx in range(-1, 1):
			var qx := cx + dx
			var qz := cz + dz
			if qx < 0 or qz < 0 or qx >= Game.MW or qz >= Game.MH:
				continue
			var qi := qz * Game.MW + qx
			if gm.road[qi] == 1 or gm.cobble[qi] == 1 or gm.water[qi] == 1 or gm.bridge[qi] == 1 or gm.grid[qi] == 0:
				rd = 0.5
	return n_h.get_noise_2d(vx, vz) * 0.2 * smoothstep(1.4, 3.4, rd)


func _world_clear() -> void:
	for k in wchunks.keys():
		(wchunks[k] as Node3D).queue_free()
	wchunks.clear()
	for c in static_root.get_children():
		c.queue_free()


var world_off := Vector2.ZERO
var fixed_cam := false
var ed: W3DEdit                  # editor del mondo (F12)
var fut: W3DFuture               # intrusioni del futuro (cambiano con Chrono.tech)
var near_props: Array = []       # prop funzionali vicini al giocatore (ricalcolati ogni pochi fotogrammi)
var near_props_t := 0
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
	_sync_doors()
	var sp := pos
	pos = sp - world_off
	wframe += 1
	if wframe % 5 == 1:
		_stream(false)
	_run_jobs(3.5)
	pos = sp
	for k in chunks:
		var nd: Node3D = chunks[k]["node"]
		if not nd.has_meta("off"):
			nd.position = Vector3(world_off.x, 0.0, world_off.y)
			nd.set_meta("off", true)


func _world_init() -> void:
	ed_load()
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
	stream_margin = 14.0
	stream_drop = 40.0
	seed_v = 1337
	no_base_houses = false
	grid_road_fn = Callable()
	bio_fn = Callable(self, "_bio_game")
	clear_pts.clear()
	clear_pts.append(Vector3(gm.player.position.x / 16.0 - world_off.x, gm.player.position.y / 16.0 - world_off.y, 2.5))
	for g in gm.props:
		if not is_instance_valid(g) or bool(g.scene) or not (str(g.kind) in ["portal", "bonfire", "elder"]):
			continue
		var gc := Vector2(g.cell) + Vector2(0.5, 0.5) - world_off
		clear_pts.append(Vector3(gc.x, gc.y, 4.5 if g.kind == "portal" else 2.4))
	var sp := pos
	pos = sp - world_off
	_stream(true)
	pos = sp
	_world_update()


## collisione del mondo aperto: i solidi sono quelli visibili in 3D
func world_free(p: Vector2, r: float) -> bool:
	var c := Vector2i(floori(p.x / 16.0), floori(p.y / 16.0))
	if not gm.inb(c) or (gm.outside[gm.idx(c)] == 1 and gm.grid[gm.idx(c)] == 0):
		return false
	if _gcol_hit(p / 16.0, r / 16.0 * 0.8):
		return false
	return not _blocked(p / 16.0 - world_off, r / 16.0 * 0.8)


const STRUCT_PFX := ["roof_", "cathedral_top", "chapel_top", "tower_top", "smithy_top", "archive_top", "sanatorium_top", "mill_top",
		"mausoleum_top", "arch_top", "ruin_tower", "pond_", "stump_big", "tbig_", "top_dead", "top_sick", "wall_top", "circle_top", "cart_top", "lamp_top"]
var gcols: Dictionary = {}


func _is_struct(kind: String) -> bool:
	for p in STRUCT_PFX:
		if kind.begins_with(p):
			return true
	return false


func _bio_game(p: Vector2) -> int:
	var c := Vector2i(floori(p.x + world_off.x), floori(p.y + world_off.y))
	if not gm.inb(c):
		return 0
	var b := int(gm.biome[gm.idx(c)])
	if b == 0 and not gm.gen_chunks.has(Vector2i(c.x / gm.CH, c.y / gm.CH)):
		return 0
	return b


func _register_structs() -> void:
	gcols.clear()
	for g in gm.ents.get_children():
		if not (g is Prop) or not bool(g.scene) or g.spr == null or g.spr.texture == null:
			continue
		var kd := str(g.kind)
		if not _is_struct(kd):
			continue
		var c := _sprite_center(g, g.spr) / 16.0
		var hs := Vector2(g.spr.texture.get_width(), g.spr.texture.get_height()) / 32.0
		var wk := not (kd.begins_with("pond_") or kd.begins_with("circle_") or kd.begins_with("arch_"))
		if kd.begins_with("top_") or kd.begins_with("tbig_") or kd.begins_with("stump_"):
			hs = Vector2(0.45, 0.45) if not kd.begins_with("tbig_") else Vector2(0.8, 0.8)
		elif kd.begins_with("roof_") or kd.begins_with("wall_") or kd.contains("_top"):
			hs *= 0.9
		if wk:
			var key := Vector2i(floori(c.x / 8.0), floori(c.y / 8.0))
			if not gcols.has(key):
				gcols[key] = []
			(gcols[key] as Array).append([c, hs])
		if hs.x > 0.9 or hs.y > 0.9:
			var cc := c - world_off
			clear_pts.append(Vector3(cc.x, cc.y, maxf(hs.x, hs.y) + 0.8))


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


var road_cache: Dictionary = {}


## strade del mondo di gioco viste dal motore 3D: distanza dal bordo piu' vicino delle celle di strada/selciato
func _grid_road(p: Vector2) -> Dictionary:
	var key := Vector2i(roundi(p.x * 2.0), roundi(p.y * 2.0))
	if road_cache.has(key):
		return road_cache[key]
	var gp := p + world_off
	var cx := floori(gp.x)
	var cz := floori(gp.y)
	var best := 99.0
	var bn := p
	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var c := Vector2i(cx + dx, cz + dz)
			if not gm.inb(c):
				continue
			var ci: int = gm.idx(c)
			if gm.road[ci] != 1 and gm.cobble[ci] != 1:
				continue
			var ex := maxf(absf(gp.x - (c.x + 0.5)) - 0.5, 0.0)
			var ez := maxf(absf(gp.y - (c.y + 0.5)) - 0.5, 0.0)
			var d := sqrt(ex * ex + ez * ez)
			if d < best:
				best = d
				bn = Vector2(c.x + 0.5, c.y + 0.5) - world_off
	var tg := (p - bn).orthogonal()
	var res := {"d": best + 1.0 if best < 98.0 else 99.0, "nearest": bn, "tan": tg.normalized() if tg.length() > 0.01 else Vector2.RIGHT, "w": 2.0}
	if road_cache.size() > 60000:
		road_cache.clear()
	road_cache[key] = res
	return res


var unstick_t := 0.0
var world_real := 0 if OS.get_cmdline_user_args().has("--noreal") else 4
var world_light_k := 30.0


## i nemici nati dentro un edificio 3D vengono spostati sul punto libero piu' vicino
func _unstick(dt: float) -> void:
	unstick_t -= dt
	if unstick_t > 0.0:
		return
	unstick_t = 0.8
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
			rl.position = Vector3(rv.x, 7.5, rv.z)      # sopra lanterne e fiamme: la luce non nasce dentro la geometria che la copre
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
			arr.append(Vector4(lv2.x, lv2.y, lv2.z, lv2.w * fl))
			lc.append(Vector3(0.92, 0.74, 0.60))
		else:
			arr.append(Vector4(0, 0, 0, 0))
			lc.append(Vector3(0, 0, 0))
	_mp("lamps", arr)
	_mp("lamp_col", lc)


func _world_chunk(k: Vector2i) -> void:
	var fb := W3DBuilder.new()
	var ob := W3DBuilder.new()
	var wb := W3DBuilder.new()
	fb.rn.seed = k.x * 31 + k.y
	ob.rn.seed = k.x * 17 + k.y * 5
	wb.rn.seed = k.x * 13 + k.y * 3
	ob.sat = 1.3
	ob.con = 1.2
	wb.sat = 1.55
	wb.con = 1.45
	var w: int = Game.MW
	for y in range(k.y * WSC, (k.y + 1) * WSC):
		for x in range(k.x * WSC, (k.x + 1) * WSC):
			if x >= w or y >= Game.MH:
				continue
			var i: int = y * w + x
			var hv := _hash2(x, y)
			var hv2 := _hash2(x, y, 5)
			var bio := int(gm.biome[i])
			var bd: Dictionary = Game.BIO[bio]
			if gm.water[i] == 1:
				fb.quad(Vector3(x, -0.12, y), Vector3(x + 1, -0.12, y), Vector3(x + 1, -0.12, y + 1), Vector3(x, -0.12, y + 1), Color(0.07 + hv * 0.02, 0.12 + hv * 0.03, 0.18 + hv * 0.04))
				continue
			if gm.bridge[i] == 1:
				fb.quad(Vector3(x, 0.02, y), Vector3(x + 1, 0.02, y), Vector3(x + 1, 0.02, y + 1), Vector3(x, 0.02, y + 1), Color(0.24, 0.16, 0.1).lerp(Color(0.34, 0.24, 0.15), hv))
				continue
			if gm.grid[i] == 1:
				var g: Array = bd["g"]
				var t: int = int(g[int(hv2 * 7.0) % g.size()])
				var col := _wtile_col(t)
				if gm.cobble[i] == 1:
					col = Color(0.27, 0.26, 0.28)
				elif gm.road[i] == 1:
					col = Color(0.30, 0.26, 0.21)
				# macchie di terreno a bassa frequenza: il suolo non e' uniforme
				var natural: bool = gm.road[i] == 0 and gm.cobble[i] == 0
				var base_col := col
				for sj in 2:
					for si in 2:
						var gp := Vector2(x + (si + 0.5) * 0.5, y + (sj + 0.5) * 0.5)
						var gc := _ground_col(gp, 50.0, 0.0) if natural else _ground_col(gp, 0.0, 3.0).lerp(Color(0.2, 0.19, 0.2), 0.35 if gm.cobble[i] == 1 else 0.0)
						if natural and t != Game.T_TERRA:
							gc = gc.lerp(_wtile_col(t), 0.45)
						if t == Game.T_NEVE and natural:
							gc = _wtile_col(t).lerp(gc, 0.25)
						gc = fb.shade(gc, 0.035)
						var x0 := x + si * 0.5
						var z0 := y + sj * 0.5
						var a := Vector3(x0, _wh(x0, z0), z0)
						var b := Vector3(x0 + 0.5, _wh(x0 + 0.5, z0), z0)
						var d := Vector3(x0 + 0.5, _wh(x0 + 0.5, z0 + 0.5), z0 + 0.5)
						var e := Vector3(x0, _wh(x0, z0 + 0.5), z0 + 0.5)
						if (si + sj + x + y) % 2 == 0:
							fb.tri(a, b, d, gc)
							fb.tri(a, d, e, gc)
						else:
							fb.tri(a, b, e, gc)
							fb.tri(b, d, e, gc)
				if natural and t != Game.T_LAVA and t != Game.T_NEVE:
					# erba secca come nel motore originale: ciuffi lungo i campi di densita'
					for q in 3:
						var gp2 := Vector2(x + _hash2(x, y, 60 + q), y + _hash2(x, y, 70 + q))
						var vg := n_veg.get_noise_2d(gp2.x, gp2.y) * 0.5 + 0.5
						var dens := smoothstep(0.32, 0.78, vg + n_veg2.get_noise_2d(gp2.x, gp2.y) * 0.12)
						if _hash2(x, y, 90 + q) < dens:
							_tuft(ob, Vector3(gp2.x, 0.0, gp2.y), dens, n_veg2.get_noise_2d(gp2.x + 50.0, gp2.y) * 0.5 + 0.5)
					if hv > 0.97:
						ob.rock(Vector3(x + 0.5, 0.1, y + 0.5), Vector3(0.3, 0.2, 0.28), Color(0.19, 0.19, 0.2), 0.1, 0.35, hv * 9.0)
			else:
				var bt: int = int(bd["b"])
				if gm.outside[i] == 1:
					fb.quad(Vector3(x, -0.3, y), Vector3(x + 1, -0.3, y), Vector3(x + 1, -0.3, y + 1), Vector3(x, -0.3, y + 1), Color(0.03, 0.03, 0.04))
					continue
				fb.quad(Vector3(x, 0, y), Vector3(x + 1, 0, y), Vector3(x + 1, 0, y + 1), Vector3(x, 0, y + 1), Color(0.07, 0.09, 0.07))
				if bt == Game.T_CHIOMA and _hash2(x, y, 4) < 0.5:
					var tcols: Array = []
					var tr := RandomNumberGenerator.new()
					tr.seed = x * 7919 + y
					_dead_tree(wb, Vector2(x + 0.5, y + 0.5), tr, tcols)
				elif bt == Game.T_CHIOMA:
					var th := 1.5 + hv * 1.6
					wb.box(Transform3D(Basis.IDENTITY, Vector3(x + 0.5, th * 0.5, y + 0.5)), Vector3(0.22, th, 0.22), Color(0.17, 0.11, 0.08), 0.1, 6)
					var gc := Color(0.08, 0.2, 0.1).lerp(Color(0.12, 0.28, 0.14), hv2)
					wb.rock(Vector3(x + 0.5, th + 0.35, y + 0.5), Vector3(1.5 + hv * 0.3, 1.1, 1.5 + hv2 * 0.3), gc, 0.22, 0.45, hv * 7.0)
				elif bt == Game.T_ACQUA:
					fb.quad(Vector3(x, -0.12, y), Vector3(x + 1, -0.12, y), Vector3(x + 1, -0.12, y + 1), Vector3(x, -0.12, y + 1), Color(0.07, 0.13, 0.18))
				else:
					var rh := 0.9 + hv * 1.5
					wb.rock(Vector3(x + 0.5, rh * 0.5, y + 0.5), Vector3(1.15, rh, 1.15), Color(0.2, 0.2, 0.23).lerp(Color(0.3, 0.29, 0.32), hv2), 0.2, 0.4, hv * 11.0)
	var root := Node3D.new()
	for pr in [[fb, false], [ob, false], [wb, true]]:
		var bld: W3DBuilder = pr[0]
		if bld.v.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bld.mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pr[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	static_root.add_child(root)
	wchunks[k] = root


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
		if not world_on or built_area != "world":
			_world_clear()
			for k in dyn.keys():
				_drop_dyn(k)
			room_lamps.clear()
			decor_lights.clear()
			room_theme.clear()
			built_area = "world"
			world_on = true
			vp.size = Vector2i(400, 225)      # mondo aperto: risoluzione piu' bassa = oggetti piu' pixellati (e piu' veloce)
			post_mat.set_shader_parameter("px", Vector2(400, 225))
			_world_clear()
			_world_init()
	elif built_area != str(gm.area) or built_grid_id != gm.grid.size() or world_on:
		if world_on:
			_world_clear()
			for k in chunks:
				(chunks[k]["node"] as Node3D).queue_free()
			chunks.clear()
			jobs.clear()
			job_keys.clear()
		world_on = false
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
				if is_instance_valid(gp) and not bool(gp.scene) and (gp as Node2D).position.distance_squared_to(ppx) <= 640000.0:
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
	_update_cam()
	dust.position = Vector3(pos.x, 3.0, pos.y)
	RenderingServer.global_shader_parameter_set("w3d_player", Vector3(pos.x, 0, pos.y))
	fade_a = lerpf(fade_a, ed.fade if (ed != null and ed.on) else (27.0 if world_on else 48.0), 0.15)
	if not fixed_cam:
		cam_h = lerpf(cam_h, 30.0 if world_on else 22.0, 0.08)
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
	_mp("curve", curve)
	_mp("fade_a", fade_a)
	_mp("fade_b", fade_a + 18.0)
	_mp("floor_min", (0.04 if world_on else 0.34) if (not fwd or world_on) else 0.0)
	mat_chr.set_shader_parameter("gamma_in", 2.0)
	mat_chr.set_shader_parameter("boost", 1.8)
	mat_chr.set_shader_parameter("sat_k", 1.35)
	if not fwd and not world_on:
		_mp("hero_glow", 0.55)
	mat.set_shader_parameter("patt", 1.0 if world_on else 0.0)
	mat.set_shader_parameter("boost", 0.27 if world_on else 1.0)
	mat.set_shader_parameter("sat_k", 1.25 if world_on else 1.0)
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
	for a in OS.get_cmdline_user_args():
		if str(a).begins_with("--skinroom=") and shot_t > 0.5 and shot_t < 0.6:
			var ri := int(str(a).substr(11))
			if ri < gm.rooms.size():
				var rr: Rect2i = gm.rooms[ri]
				gm.player.position = (Vector2(rr.position) + Vector2(rr.size) * 0.5) * 16.0
		if str(a).begins_with("--skincam="):
			cam_h = float(str(a).substr(10))
			fixed_cam = true
	if shot_t > 3.0 + shot_n * 2.0 and shot_n < 3:
		get_viewport().get_texture().get_image().save_png("user://skin_%d.png" % shot_n)
		shot_n += 1
	if shot_n >= 3:
		print("SKIN fps=", Engine.get_frames_per_second(), " dyn=", dyn.size(), " area=", gm.area, " enemies=", gm.enemies.size(), " props=", gm.props.size())
		get_tree().quit()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F8:
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
