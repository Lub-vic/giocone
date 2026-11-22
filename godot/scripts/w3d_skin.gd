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
	fwd = RenderingServer.get_current_rendering_method() == "forward_plus"
	shadow_disc = not fwd
	if fwd:
		sun.visible = false
		_make_pool()
		env.glow_enabled = true
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
	for y in mh:
		for x in mw:
			var c := Vector2i(x, y)
			var hv := _hash2(x, y)
			var hv2 := _hash2(x, y, 5)
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
		ol.light_color = Color(1.0, 0.72, 0.42)
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
	hero_light.light_color = Color(1.0, 0.82, 0.6)
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
		cand.append([gp.distance_squared_to(pos), Vector3(gp.x, 1.9, gp.y), minf(4.2, float(f[1]) * 3.4), Color(1.0, 0.7, 0.4)])
	for dl in decor_lights:
		var dv: Vector3 = dl
		cand.append([Vector2(dv.x, dv.z).distance_squared_to(pos), dv, 3.0, Color(1.0, 0.62, 0.32)])
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
	var d := td_get(name)
	var cells: Dictionary = d["cells"]
	if cells.is_empty() or booms.size() > 6:
		return
	var vox := TD_VOX * scl
	var keys := cells.keys()
	var step := 1 if keys.size() <= 260 else 2
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
	elif n is Ally:
		nm = "skeleton"
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
		var chr := n is Enemy or n is Villager or n is Ally or n is Critter or is_player
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
			node3.visible = p.spr.visible
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
		elif n is Projectile or n is PArrow or n is Pickup:
			if not dyn.has(id):
				var pm := MeshInstance3D.new()
				pm.mesh = shard_m
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
		elif n is Label and not n.has_meta("tracked"):
			n.set_meta("tracked", true)
			var l3 := Label3D.new()
			var lb := n as Label
			l3.text = lb.text
			l3.font = Game.font()
			l3.font_size = 40
			l3.pixel_size = 0.014
			l3.modulate = lb.get_theme_color("font_color")
			l3.outline_size = 10
			l3.no_depth_test = true
			l3.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l3.position = Vector3(lb.position.x / 16.0 + 0.5, 2.6, lb.position.y / 16.0 + 0.3)
			vp.add_child(l3)
			var tw := create_tween()
			tw.tween_property(l3, "position:y", 4.2, 0.7)
			tw.parallel().tween_property(l3, "modulate:a", 0.0, 0.7).set_delay(0.25)
			tw.tween_callback(l3.queue_free)


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
func _process(dt: float) -> void:
	if gm == null or gm.player == null:
		return
	if want_shot and str(gm.state) == "story":
		gm.state = "play"
	var want: bool = str(gm.area) != "" and str(gm.area) != "world" and gm.state != "title"
	if want != active:
		active = want
		post_rect.visible = active
		_show_2d(not active)
		if not active:
			for k in dyn.keys():
				_drop_dyn(k)
	if not active:
		return
	if built_area != str(gm.area) or built_grid_id != gm.grid.size():
		_rebuild_static()
		for l in gm.fx.get_children():
			if l is Label:
				l.set_meta("tracked", true)
	lamp_t += dt
	_show_2d(false)
	pos = gm.player.position / 16.0
	# aggiorna gli oggetti del gioco
	for n in gm.ents.get_children():
		_sync_node2d(n, n == gm.player)
	_sync_fx()
	_sync_slash()
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
	if fwd:
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
	_mp("floor_min", 0.34 if not fwd else 0.0)
	mat_chr.set_shader_parameter("gamma_in", 2.0)
	mat_chr.set_shader_parameter("boost", 1.8)
	mat_chr.set_shader_parameter("sat_k", 1.35)
	if not fwd:
		_mp("hero_glow", 0.55)
	mat.set_shader_parameter("patt", 0.0)
	mat_chr.set_shader_parameter("patt", 0.0)
	if want_shot:
		_shot(dt)


func _skin_lamps() -> void:
	var cand: Array = []
	for f in gm.flick:
		var l = f[0]
		if not is_instance_valid(l):
			continue
		var gp: Vector2 = (l as Node2D).global_position / 16.0
		cand.append([gp.distance_squared_to(pos), Vector4(gp.x, 1.8, gp.y, minf(2.4, float(f[1]) * 1.6)), Vector3(0.98, 0.72, 0.42)])
	for dl in decor_lights:
		var dv: Vector3 = dl
		cand.append([Vector2(dv.x, dv.z).distance_squared_to(pos), Vector4(dv.x, dv.y, dv.z, 1.6), Vector3(0.98, 0.72, 0.42)])
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
