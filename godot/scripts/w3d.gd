class_name W3D
extends Node
static var gp_added := false
## Prova del motore 3D "top-down verticale, tutto poligoni": il villaggio nasce a blocchi attorno a chi cammina,
## i bordi della bolla sprofondano nel buio, il mondo si piega come un pianetino.
## Il mondo e' fatto di campi di densita' (erba, sassi, cespugli, alberi) e di lotti allineati alle strade:
## niente e' messo a caso, tutto segue le stesse regole della natura e del villaggio.
## Comandi: WASD muovi Â· F2/F3 curvatura Â· F4/F5 bolla Â· F6 filtro Â· F7 nuovo villaggio Â· F8 pixel Â· C personaggi Â· Esc esci.

const CHS := 24                 # lato di un blocco (unita' = 16 px del vecchio gioco)
const GS := 0.4                 # lato di una cella del terreno
const LC := 8.0                 # lato di un lotto (3x3 lotti per blocco)
const CAM_H := 48.0
const RES := [Vector2i(640, 360), Vector2i(960, 540), Vector2i(480, 270), Vector2i(320, 180)]
const SPEED := 9.6              # il gioco 2D va a 82 px/s = 5,1 unita/s; nel 3D sembrava al rallentatore (x1,4), e con la camera piu' lontana (x1,2) si compensa
const NPC_KINDS := ["goblin", "skeleton", "ghoul", "kobold", "orc", "wolf", "goblin_archer", "skel_archer"]
const WOOD := Color(0.17, 0.115, 0.085)
const STONE := Color(0.24, 0.235, 0.25)

var seed_v := 1337
var mega_cols: Dictionary = {}  # collisioni delle grandi strutture, per posizione
var megas: Array = []           # grandi strutture pianificate: [tipo, posizione, rotazione] (le costruisce il blocco che contiene il centro)
var clear_pts: Array = []        # Vector3(x, z, raggio): zone da tenere libere (falo', portali, oggetti di gioco)
var no_base_fires := false
var plain_house := false        # casa senza recinto e cataste (le case dei luoghi della mappa)
var field_n := 0
var pier_n := 0
var first_pier := Vector2(-9999, -9999)
var first_field := Vector2(-9999, -9999)
var edge_fn := Callable()        # (Vector2 punto) -> true se e' fuori dalla mappa di gioco (vuoto)
var house_doors: Dictionary = {}     # chiave arrotondata -> Vector3(x, z, yaw della facciata)
var bio_cache: Dictionary = {}
var stream_margin := 30.0
var stream_drop := 56.0
var step_us: Dictionary = {}
var step_n: Dictionary = {}
var grid_road_fn := Callable()    # se valido: le strade vengono dalla mappa di gioco (p -> {d, nearest, tan, w})
var no_base_houses := false
var bio_fn := Callable()          # (Vector2 punto) -> indice di bioma (0 = villaggio)
var vp: SubViewport
var sheet := false
var extra_mats: Array = []
var shadow_disc := false
var env: Environment
var cam: Camera3D
var sun: DirectionalLight3D
var mat: ShaderMaterial
var mat_chr: ShaderMaterial
var mat_prop: ShaderMaterial
var mat_ground: ShaderMaterial     # suolo disegnato per pixel (solo nel gioco: lo crea la pelle)
var patterns := false
var post_rect: TextureRect
var post_mat: ShaderMaterial
var hud: Label
var hero: Node3D
var hero_body: Node3D
var pos := Vector2.ZERO
var facing := Vector2(0, -1)
var bob_t := 0.0
var curve := 0.014
var fade_a := 54.0
var chunks: Dictionary = {}     # Vector2i -> {node, cols, lamps}
var jobs: Array = []
var job_keys: Dictionary = {}
var plans: Dictionary = {}
var zones: Dictionary = {}
var segs_a := PackedVector2Array()
var segs_b := PackedVector2Array()
var segs_w := PackedFloat32Array()
var n_soil := FastNoiseLite.new()
var n_veg := FastNoiseLite.new()
var n_veg2 := FastNoiseLite.new()
var n_shrub := FastNoiseLite.new()
var n_rock := FastNoiseLite.new()
var n_tree := FastNoiseLite.new()
var n_stain := FastNoiseLite.new()
var n_h := FastNoiseLite.new()
var lamp_t := 0.0
var shots: Array = []
var shot_i := 0
var shot_wait := 0
var nofx := false
var no_shadow := false
var gen_ms := 0.0
var res_i := 0
var npcs: Array = []
var char_style := 0
var vox_cache: Dictionary = {}
const TD_VOX := 0.0625 * 0.95
const TD_STEP := 2          # cubetti piu' grossi = personaggi meno definiti
var hero_kind := "necro"
var omni_pos: Array = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var omni_en: Array = [0.0, 0.0, 0.0]
var omnis: Array = []              # luci vere con ombre: le 3 piu' vicine tra torce, finestre e lanterna dell'eroe
var disc_mesh: ArrayMesh
var demo := true                 # demo giocabile: combattimento, nemici, boss, falo'
var combat: W3DCombat
var shake := 0.0
var bonfires: Array = []
var boss_pos := Vector2.ZERO
var lineup := false
var cam_h := CAM_H
# UFO Camera System
var ufo_cam_active := false          # true quando fase UFO attiva
var ufo_cam_target_rot_x := -90.0    # rotazione X target (gradi)
var ufo_cam_target_h := 48.0         # altezza target
var ufo_cam_target_fov := 38.6       # FOV target
var ufo_cam_transition_speed := 3.0  # velocitÃ  transizione (lerp factor)


## parametri globali degli shader: giocatore, quote del terreno (texture + scala), curvatura
static func add_globals() -> void:
	if gp_added:
		return
	RenderingServer.global_shader_parameter_add("w3d_player", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
	var img := Image.create(1, 1, false, Image.FORMAT_RH)
	RenderingServer.global_shader_parameter_add("w3d_elev", RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2D, ImageTexture.create_from_image(img))
	RenderingServer.global_shader_parameter_add("w3d_elev_info", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4(0, 0, 0, 0))
	RenderingServer.global_shader_parameter_add("w3d_curve", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3(0.014, 27.0, 45.0))
	RenderingServer.global_shader_parameter_add("w3d_side_cut", RenderingServer.GLOBAL_VAR_TYPE_VEC4, Vector4.ZERO)
	gp_added = true


func _ready() -> void:
	add_globals()
	# Ensure w3d_side_cut is initialized to zero to prevent black screen on startup
	RenderingServer.global_shader_parameter_set("w3d_side_cut", Vector4.ZERO)
	get_window().content_scale_size = Vector2i(960, 540)   # piu' pixel logici: meno pixellato (l'interfaccia viene scalata x2)
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("--shots="):
			for s in str(arg).substr(8).split(";"):
				var xy := s.split(",")
				shots.append(Vector2(float(xy[0]), float(xy[1])))
		if str(arg).begins_with("--seed="):
			seed_v = int(str(arg).substr(7))
		if str(arg).begins_with("--camh="):
			cam_h = float(str(arg).substr(7))
		if str(arg) == "--lineup":
			lineup = true
		if str(arg) == "--sheet":
			lineup = true
			sheet = true
		if str(arg) == "--nofx":
			nofx = true
		if str(arg) == "--noshadow":
			no_shadow = true
		if str(arg).begins_with("--bubble="):
			fade_a = float(str(arg).substr(9))
		if str(arg).begins_with("--style="):
			char_style = int(str(arg).substr(8))
	if sheet:
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_size = Vector2i(480, 270)
		fade_a = 400.0
		curve = 0.0
	_build_view()
	if sheet:
		vp.size = Vector2i(1440, 810)
		post_mat.set_shader_parameter("px", Vector2(1440, 810))
	_new_world()
	if not lineup and shots.is_empty():
		combat = W3DCombat.new()
		combat.w = self
		add_child(combat)
		combat.setup()
	hud = Label.new()
	hud.add_theme_font_override("font", Game.font())
	hud.add_theme_font_size_override("font_size", 9)
	hud.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	hud.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 1)
	hud.position = Vector2(6, 250)
	var cl := CanvasLayer.new()
	cl.layer = 5
	cl.scale = Vector2(2, 2)
	cl.add_child(hud)
	add_child(cl)


func _exit_tree() -> void:
	get_window().content_scale_size = Vector2i(480, 270)


func _build_view() -> void:
	vp = SubViewport.new()
	vp.size = RES[res_i]
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED   # niente antialiasing: bordi netti
	add_child(vp)
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.46, 0.5) if lineup else Color(0.42, 0.44, 0.6)
	env.ambient_light_energy = (0.85 if sheet else 1.5) if lineup else 1.35
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.62, 0.68, 0.98)
	sun.light_energy = (0.7 if sheet else 1.0) if lineup else 0.66
	sun.rotation_degrees = Vector3(-36, -35, 0)
	sun.shadow_enabled = not no_shadow
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	vp.add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 38.6
	cam.near = 2.0
	cam.far = 120.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	# Set initial camera position above ground to avoid near-plane clipping on first frame
	cam.position = Vector3(pos.x, cam_h, pos.y)
	vp.add_child(cam)
	cam.current = true
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/w3d.gdshader")
	mat_chr = ShaderMaterial.new()
	mat_chr.shader = mat.shader
	mat_chr.set_shader_parameter("gamma_in", 2.0 if sheet else 1.0)
	mat_chr.set_shader_parameter("boost", 1.35 if sheet else 1.9)
	mat_chr.set_shader_parameter("sat_k", 1.3 if sheet else 1.7)
	mat_chr.set_shader_parameter("side_cut_exempt", 1.0)
	mat_prop = ShaderMaterial.new()
	mat_prop.shader = mat.shader
	mat_prop.set_shader_parameter("gamma_in", 1.0)
	mat_prop.set_shader_parameter("boost", 1.7)
	mat_prop.set_shader_parameter("sat_k", 1.35)
	mat_prop.set_shader_parameter("side_cut_exempt", 1.0)
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	post_rect = TextureRect.new()
	post_rect.texture = vp.get_texture()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	post_rect.stretch_mode = TextureRect.STRETCH_SCALE
	post_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/w3d_post.gdshader")
	post_mat.set_shader_parameter("px", Vector2(RES[res_i]))
	post_rect.material = post_mat
	cl.add_child(post_rect)


func _new_world() -> void:
	for k in chunks:
		(chunks[k]["node"] as Node3D).queue_free()
	chunks.clear()
	jobs.clear()
	job_keys.clear()
	plans.clear()
	zones.clear()
	if hero != null:
		hero.queue_free()
	for nn in [[n_soil, 0, 0.05], [n_veg, 31, 0.045], [n_veg2, 32, 0.19], [n_shrub, 41, 0.06], [n_rock, 51, 0.05], [n_tree, 61, 0.03], [n_stain, 23, 0.03], [n_h, 5, 0.11]]:
		var fn: FastNoiseLite = nn[0]
		fn.seed = seed_v + int(nn[1])
		fn.frequency = float(nn[2])
	_gen_roads()
	if OS.get_cmdline_user_args().has("--graves"):
		for gz in range(-8, 9):
			for gx in range(-8, 9):
				if _zone_grave(gx, gz):
					print("GRAVE ", (gx * 3 + 1.5) * LC, " ", (gz * 3 + 1.5) * LC)
	pos = (bonfires[1] as Vector2) + Vector2(0, 2.6)
	if sheet:
		pos = Vector2.ZERO
	_build_hero()
	if lineup:
		var gb := W3DBuilder.new()
		var gr := 45 if sheet else 20
		for gz in range(-gr, gr):
			for gx in range(-gr, gr):
				var x := pos.x + gx
				var z := pos.y + gz
				gb.quad(Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1), gb.shade(Color(0.17, 0.155, 0.14), 0.08))
		var gm := MeshInstance3D.new()
		gm.mesh = gb.mesh()
		gm.material_override = mat
		vp.add_child(gm)
	if sheet:
		_build_sheet()
	_stream(true)
	_update_cam()
	if combat != null:
		combat.reset_world()


# ------------------------------------------------------------------ strade
func _gen_roads() -> void:
	segs_a.clear()
	segs_b.clear()
	segs_w.clear()
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var p := Vector2(-130, r.randf_range(-14, 14))
	var hd := r.randf_range(-0.2, 0.2)
	var main_pts: Array = []
	for i in 27:
		main_pts.append(p)
		hd += r.randfn(0.0, 0.2) - hd * 0.14
		p += Vector2.from_angle(hd) * 10.0
	_add_poly(main_pts, 2.6)
	bonfires.clear()
	for bi in [4, 10, 16, 21]:
		var mp: Vector2 = main_pts[bi]
		var tn: Vector2 = ((main_pts[bi + 1] as Vector2) - mp).normalized()
		bonfires.append(mp + tn.orthogonal() * 4.2)
	boss_pos = main_pts[25]
	for b in 6:
		var base: Vector2 = main_pts[r.randi_range(5, main_pts.size() - 6)]
		var h2 := (1.0 if r.randf() < 0.5 else -1.0) * r.randf_range(0.8, 2.2)
		var pts: Array = []
		var q := base
		for i in 6:
			pts.append(q)
			h2 += r.randfn(0.0, 0.22)
			q += Vector2.from_angle(h2) * 10.0
		_add_poly(pts, 1.9)


func _add_poly(pts: Array, w: float) -> void:
	for i in pts.size() - 1:
		segs_a.append(pts[i])
		segs_b.append(pts[i + 1])
		segs_w.append(w)


func _road_near(p: Vector2) -> Dictionary:
	if grid_road_fn.is_valid():
		return grid_road_fn.call(p)
	var best := 1e9
	var bn := p
	var bt := Vector2.RIGHT
	var bw := 2.0
	for i in segs_a.size():
		var a := segs_a[i]
		var ab := segs_b[i] - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var q := a + ab * t
		var d := p.distance_to(q)
		if d < best:
			best = d
			bn = q
			bt = ab.normalized()
			bw = segs_w[i]
	return {"d": best, "nearest": bn, "tan": bt, "w": bw}


func _road_dist_sub(p: Vector2, sub: Array) -> Vector2:
	if grid_road_fn.is_valid():
		var gd: Dictionary = grid_road_fn.call(p)
		return Vector2(gd["d"], gd["w"])
	var best := 1e9
	var bw := 2.0
	for s in sub:
		var a: Vector2 = s[0]
		var ab: Vector2 = s[1]
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			bw = s[2]
	return Vector2(best, bw)


# ------------------------------------------------------------------ blocchi (generati a fette di tempo)
var pins: Array = []            # Vector2 (coordinate del generatore): zone da tenere caricate (percorso di una cutscene)
const PIN_R := 40.0


func _pinned(c: Vector2) -> bool:
	for p in pins:
		if c.distance_to(p) < PIN_R + CHS * 0.7:
			return true
	return false


func _stream(all: bool) -> void:
	if lineup:
		return
	var pc := Vector2i(floori(pos.x / CHS), floori(pos.y / CHS))
	var want: Array = []
	var rad := int(ceil((fade_a + stream_margin) / CHS))
	for dz in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var k := pc + Vector2i(dx, dz)
			var ctr := Vector2((k.x + 0.5) * CHS, (k.y + 0.5) * CHS)
			var d := ctr.distance_to(pos)
			if d < fade_a + stream_margin and not chunks.has(k) and not job_keys.has(k):
				want.append([d, k])
	for pn in pins:
		var pk := Vector2i(floori(pn.x / CHS), floori(pn.y / CHS))
		var pr := int(ceil(PIN_R / CHS)) + 1
		for dz in range(-pr, pr + 1):
			for dx in range(-pr, pr + 1):
				var k2 := pk + Vector2i(dx, dz)
				var c2 := Vector2((k2.x + 0.5) * CHS, (k2.y + 0.5) * CHS)
				if c2.distance_to(pn) < PIN_R and not chunks.has(k2) and not job_keys.has(k2):
					want.append([1000.0 + c2.distance_to(pn), k2])
	want.sort_custom(func(a, b): return a[0] < b[0])
	for w in want:
		if not chunks.has(w[1]) and not job_keys.has(w[1]):
			_enqueue(w[1])
	if all:
		_run_jobs(1e9)
	for k in chunks.keys():
		var ctr2 := Vector2((k.x + 0.5) * CHS, (k.y + 0.5) * CHS)
		if ctr2.distance_to(pos) > fade_a + stream_drop and not _pinned(ctr2):
			(chunks[k]["node"] as Node3D).queue_free()
			chunks.erase(k)
	for i in range(jobs.size() - 1, -1, -1):
		var jk: Vector2i = jobs[i]["k"]
		var jc := Vector2((jk.x + 0.5) * CHS, (jk.y + 0.5) * CHS)
		if jc.distance_to(pos) > fade_a + stream_drop and not _pinned(jc):
			job_keys.erase(jk)
			jobs.remove_at(i)


func _enqueue(k: Vector2i) -> void:
	var x0 := float(k.x * CHS)
	var z0 := float(k.y * CHS)
	var sub: Array = []
	for i in segs_a.size():
		var a := segs_a[i]
		var b := segs_b[i]
		if maxf(a.x, b.x) < x0 - 12.0 or minf(a.x, b.x) > x0 + CHS + 12.0 or maxf(a.y, b.y) < z0 - 12.0 or minf(a.y, b.y) > z0 + CHS + 12.0:
			continue
		sub.append([a, b - a, segs_w[i]])
	var g := W3DBuilder.new()
	var o := W3DBuilder.new()
	var v := W3DBuilder.new()
	g.rn.seed = hash(Vector3i(k.x, k.y, seed_v))
	o.rn.seed = hash(Vector3i(k.x, k.y, seed_v + 1))
	v.rn.seed = hash(Vector3i(k.x, k.y, seed_v + 2))
	o.sat = 1.55
	o.con = 1.45
	v.sat = 1.3
	v.con = 1.2
	g.gain = 0.82
	jobs.append({"k": k, "x0": x0, "z0": z0, "g": g, "o": o, "v": v, "cols": [], "lamps": [], "sub": sub, "hs": [], "step": 0, "us": 0})
	job_keys[k] = true


func _run_jobs(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not jobs.is_empty():
		var j: Dictionary = jobs[0]
		var t1 := Time.get_ticks_usec()
		var st: int = j["step"]
		var done := _job_step(j)
		var dus := Time.get_ticks_usec() - t1
		j["us"] = int(j["us"]) + dus
		step_us[st] = int(step_us.get(st, 0)) + dus
		step_n[st] = int(step_n.get(st, 0)) + 1
		if done:
			gen_ms = lerpf(gen_ms, float(j["us"]) / 1000.0, 0.2)
			jobs.pop_front()
			job_keys.erase(j["k"])
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break


func _job_step(j: Dictionary) -> bool:
	var s: int = j["step"]
	var n := int(CHS / GS)
	if s == 0:
		# altezze del terreno ai vertici, a fette di 8 righe
		if not j.has("vc"):
			j["vc"] = 0
			j["hs"] = []
		var hs: Array = j["hs"]
		var cur: int = j["vc"]
		for jj in range(cur, mini(cur + 8, n + 1)):
			for ii in n + 1:
				var p := Vector2(float(j["x0"]) + ii * GS, float(j["z0"]) + jj * GS)
				var rdv := _road_dist_sub(p, j["sub"])
				hs.append(_height(p, maxf(rdv.x - rdv.y * 0.5, 0.0) + 1.5))
		j["vc"] = cur + 8
		if cur + 8 <= n:
			return false
		j["gc"] = 0
	elif s == 1:
		var gc: int = j["gc"]
		_ground_rows(j, gc, mini(gc + 6, n))
		j["gc"] = gc + 6
		if gc + 6 < n:
			return false
	elif s <= 4:
		var k: Vector2i = j["k"]
		for q in 3:
			var li := (s - 2) * 3 + q
			_lot(j, k.x * 3 + li % 3, k.y * 3 + li / 3)
	elif s <= 6:
		_grass(j, s - 5)
	elif s == 7:
		_big_things(j)
	else:
		_finalize(j)
		return true
	j["step"] = s + 1
	return false


## mappa globale delle distanze dai sentieri (la riempie la pelle: serve al suolo disegnato per pixel)
func _gmap_fill(_j: Dictionary) -> void:
	pass


func _finalize(j: Dictionary) -> void:
	var k: Vector2i = j["k"]
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var lamps: Array = j["lamps"]
	var cols: Array = j["cols"]
	var o: W3DBuilder = j["o"]
	for i in segs_a.size():
		var mid := (segs_a[i] + segs_b[i]) * 0.5
		if mid.x < x0 or mid.x >= x0 + CHS or mid.y < z0 or mid.y >= z0 + CHS:
			continue
		var hh := fposmod(sin(float(i) * 12.9898 + float(seed_v) * 0.37) * 43758.5453, 1.0)
		if hh < 0.8 and mid.length() < 170.0 and not grid_road_fn.is_valid():
			var tn := (segs_b[i] - segs_a[i]).normalized().orthogonal()
			var lp := mid + tn * (segs_w[i] * 0.5 + 1.0) * (1.0 if hh < 0.4 else -1.0)
			if edge_fn.is_valid() and bool(edge_fn.call(lp)):
				continue
			_obj("lamp", o, lp, 0.0, o.rn, cols, lamps)
	for bp in ([] if no_base_fires else bonfires):
		var bv: Vector2 = bp
		if edge_fn.is_valid() and bool(edge_fn.call(bv)):
			continue
		if bv.x >= x0 and bv.x < x0 + CHS and bv.y >= z0 and bv.y < z0 + CHS:
			_obj("pyre", o, bv, 0.0, o.rn, cols, lamps)
			for q in 5:
				var a := TAU * q / 5.0
				o.rock(Vector3(bv.x + cos(a) * 1.0, 0.18, bv.y + sin(a) * 1.0), Vector3(0.5, 0.36, 0.5), Color(0.22, 0.22, 0.24), 0.14, 0.4, a)
	for mg in megas:
		var mp: Vector2 = mg[1]
		if mp.x >= x0 and mp.x < x0 + CHS and mp.y >= z0 and mp.y < z0 + CHS:
			var c0 := cols.size()
			_obj(str(mg[0]), o, mp, float(mg[2]), o.rn, cols, lamps)
			mega_cols[str(mp)] = {"c": mp, "r": W3DStructs.radius(str(mg[0])), "cols": cols.slice(c0)}
	_ed_apply(j)
	_gmap_fill(j)
	var node := Node3D.new()
	node.name = "C%d_%d" % [k.x, k.y]
	var parts := [["g", false], ["v", false], ["o", true]]
	for pt in parts:
		var bld: W3DBuilder = j[pt[0]]
		if bld.v.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bld.mesh()
		mi.material_override = mat_ground if (pt[0] == "g" and mat_ground != null) else mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pt[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	for sp in o.smokes:
		node.add_child(_make_smoke(sp))
	if chunks.has(k):
		(chunks[k]["node"] as Node3D).queue_free()    # blocco rigenerato (editor): il vecchio resta visibile fino a questo momento
	vp.add_child(node)
	chunks[k] = {"node": node, "cols": cols, "lamps": lamps, "reg": o.reg, "breakables": o.breakables}


# ------------------------------------------------------------------ terreno
func _height(p: Vector2, rd: float) -> float:
	if edge_fn.is_valid() and bool(edge_fn.call(p)):
		return -0.5
	return n_h.get_noise_2d(p.x, p.y) * 0.2 * smoothstep(1.4, 3.4, rd)


func _bio_at(p: Vector2) -> int:
	return int(bio_fn.call(p)) if bio_fn.is_valid() else 0


## aspetto del suolo di ogni bioma: tinta di base + disegno (muschio, lettiera, fango, lastricato, neve, lava)
func _bio_pattern(p: Vector2, bio: int, c: Color) -> Color:
	var a := n_soil.get_noise_2d(p.x * 1.3, p.y * 1.3)
	var v := n_veg.get_noise_2d(p.x, p.y)
	var s := n_stain.get_noise_2d(p.x + 400.0, p.y - 300.0)
	var out := c
	match bio:
		1:        # cimitero: terra grigio-blu, muschio e licheni pallidi
			out = Color(0.10, 0.115, 0.15)
			if v > 0.22:
				out = out.lerp(Color(0.085, 0.15, 0.11), 0.7)
			if a > 0.42:
				out = out.lerp(Color(0.2, 0.22, 0.25), 0.6)
		2:        # foresta: sottobosco scuro, lettiera di aghi e muschio
			out = Color(0.055, 0.1, 0.05)
			if a < -0.1:
				out = out.lerp(Color(0.13, 0.09, 0.055), 0.8)
			if v > 0.3:
				out = out.lerp(Color(0.035, 0.15, 0.06), 0.7)
		3:        # palude: fango verdastro e pozze scure
			out = Color(0.055, 0.1, 0.085)
			if a < -0.15:
				out = out.lerp(Color(0.085, 0.065, 0.05), 0.8)
			if s > 0.45 or n_veg2.get_noise_2d(p.x, p.y) > 0.5:
				out = Color(0.03, 0.08, 0.1)
		4:        # cattedrale: lastricato a scacchi di marmo, crepe, erba che avanza
			var cx := floori(p.x / 1.7)
			var cz := floori(p.y / 1.7)
			out = Color(0.2, 0.185, 0.23) if (cx + cz) % 2 == 0 else Color(0.11, 0.1, 0.14)
			var fx := fposmod(p.x / 1.7, 1.0)
			var fz := fposmod(p.y / 1.7, 1.0)
			if fx < 0.05 or fz < 0.05:
				out = Color(0.04, 0.035, 0.05)
			if v > 0.28:
				out = out.lerp(Color(0.07, 0.11, 0.06), 0.75)
		5:        # vetta: neve con ombre azzurre e chiazze di ghiaccio
			out = Color(0.78, 0.84, 0.91)
			if a < -0.2:
				out = out.lerp(Color(0.6, 0.7, 0.84), 0.7)
			if s > 0.42:
				out = out.lerp(Color(0.5, 0.74, 0.9), 0.7)
		6:        # fonderie: cenere nera, lastroni di roccia e crepe di lava
			out = Color(0.065, 0.055, 0.06)
			if a > 0.3:
				out = out.lerp(Color(0.11, 0.09, 0.095), 0.8)
			if absf(n_h.get_noise_2d(p.x * 1.6 + 70.0, p.y * 1.6)) < 0.045:
				out = Color(0.95, 0.32, 0.06)
	return c.lerp(out, 0.92)


func _rock_col(bio: int) -> Color:
	match bio:
		1:
			return Color(0.2, 0.21, 0.25)
		2:
			return Color(0.13, 0.17, 0.12)
		3:
			return Color(0.12, 0.16, 0.14)
		4:
			return Color(0.36, 0.34, 0.4)
		5:
			return Color(0.6, 0.7, 0.82)
		6:
			return Color(0.065, 0.055, 0.065)
	return Color(0.19, 0.19, 0.21)


const BIO_GROUND := [Color(0, 0, 0, 0), Color(0.10, 0.12, 0.17, 0.55), Color(0.05, 0.12, 0.06, 0.6), Color(0.06, 0.14, 0.12, 0.65),
		Color(0.20, 0.18, 0.25, 0.5), Color(0.50, 0.58, 0.68, 0.75), Color(0.16, 0.06, 0.04, 0.6)]


func _near_edge(p: Vector2, d: float) -> bool:
	return bool(edge_fn.call(p + Vector2(d, 0))) or bool(edge_fn.call(p - Vector2(d, 0))) or bool(edge_fn.call(p + Vector2(0, d))) or bool(edge_fn.call(p - Vector2(0, d)))


func _ground_col(p: Vector2, rd: float, rw: float) -> Color:
	if edge_fn.is_valid() and not bool(edge_fn.call(p)) and _near_edge(p, 1.3):
		# riva: sabbia scura e ciottoli bagnati
		var sn := n_soil.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.5 + 0.5
		return Color(0.2, 0.18, 0.15).lerp(Color(0.12, 0.11, 0.1), sn)
	if edge_fn.is_valid() and bool(edge_fn.call(p)):
		# oltre la costa dell'isola: acqua scura
		var wn := n_soil.get_noise_2d(p.x * 2.0, p.y * 2.0) * 0.5 + 0.5
		var wv := sin(p.x * 3.1 + p.y * 1.7) * sin(p.y * 2.3 - p.x * 1.1) * 0.5 + 0.5
		return Color(0.02, 0.05, 0.08).lerp(Color(0.06, 0.12, 0.17), wn * 0.6 + wv * 0.4)
	var c0 := _ground_col0(p, rd, rw)
	if bio_fn.is_valid() and rd > rw * 0.5 + 0.6:
		# il bioma cambia con un confine netto ma irregolare (deformato dal rumore): niente sfumature
		var wp := Vector2(n_soil.get_noise_2d(p.x * 0.7 + 300.0, p.y * 0.7), n_soil.get_noise_2d(p.x * 0.7, p.y * 0.7 - 300.0)) * 2.2
		var bi2 := clampi(_bio_at(p + wp), 0, 6)
		var bg: Color = BIO_GROUND[bi2]
		if bg.a > 0.0:
			c0 = c0.lerp(Color(bg.r, bg.g, bg.b), bg.a)
		if bi2 > 0:
			c0 = _bio_pattern(p, bi2, c0)
	return c0


func _ground_col0(p: Vector2, rd: float, rw: float) -> Color:
	var a := n_soil.get_noise_2d(p.x, p.y)
	var col := Color(0.115, 0.1, 0.092)
	# macchie di terreno a gradini: bordi netti (come pixel art) invece di sfumature
	var dk := 0.6 if a < -0.42 else (0.3 if a < -0.18 else 0.0)
	if dk > 0.0:
		col = col.lerp(Color(0.06, 0.05, 0.05), dk)
	var lt := 0.4 if a > 0.5 else (0.22 if a > 0.3 else 0.0)
	if lt > 0.0:
		col = col.lerp(Color(0.16, 0.14, 0.12), lt)
	var vg := n_veg.get_noise_2d(p.x, p.y)
	var vl := 0.75 if vg > 0.4 else (0.35 if vg > 0.12 else 0.0)
	if vl > 0.0:
		col = col.lerp(Color(0.08, 0.105, 0.07), vl)
	var st := n_stain.get_noise_2d(p.x + 400.0, p.y - 300.0)
	if st > 0.62:
		col = col.lerp(Color(0.11, 0.05, 0.045), 0.3)
	# sentiero: bordo netto leggermente irregolare, con un orlo scuro definito
	var edge := rw * 0.5
	var wob := n_soil.get_noise_2d(p.x * 5.0 + 90.0, p.y * 5.0) * 0.09
	if rd < edge + wob:
		var tone := n_soil.get_noise_2d(p.x * 8.0, p.y * 8.0)
		col = Color(0.185, 0.16, 0.14) if tone > 0.15 else (Color(0.15, 0.13, 0.115) if tone < -0.25 else Color(0.17, 0.15, 0.135))
	elif rd < edge + wob + 0.12:
		col = col.lerp(Color(0.045, 0.04, 0.036), 0.65)
	return col


func _edge_col(g: W3DBuilder, sub: Array, px: float, pz: float) -> Color:
	var pp := Vector2(px, pz)
	var rd := _road_dist_sub(pp, sub)
	var col := _ground_col(pp, rd.x, rd.y)
	var ed := rd.x - rd.y * 0.5
	var bump := clampf(1.0 - absf(ed - 0.1) / 0.28, 0.0, 1.0)
	col = Color(col.r * (1.0 - 0.35 * bump), col.g * (1.0 - 0.35 * bump), col.b * (1.0 - 0.35 * bump), col.a)
	return g.shade(col, 0.06)


func _hbil(h00: float, h10: float, h11: float, h01: float, u: float, w: float) -> float:
	return lerpf(lerpf(h00, h10, u), lerpf(h01, h11, u), w)


func _ground_rows(j: Dictionary, r0: int, r1: int) -> void:
	var g: W3DBuilder = j["g"]
	var sub: Array = j["sub"]
	var hs: Array = j["hs"]
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var n := int(CHS / GS)
	var rrow: Array = []
	rrow.resize(n)
	for jj in range(r0, r1):
		for ii in n:
			var p := Vector2(x0 + (ii + 0.5) * GS, z0 + (jj + 0.5) * GS)
			# distanza dalla strada calcolata a blocchi 2x2 (varia lentamente): molto piu' veloce
			if (jj & 1) == 0 and (ii & 1) == 0:
				var pc := Vector2(x0 + (ii + 1.0) * GS, z0 + (jj + 1.0) * GS)
				rrow[ii] = _road_dist_sub(pc, sub)
			elif (ii & 1) == 1:
				rrow[ii] = rrow[ii - 1]
			var rdv: Vector2 = rrow[ii]
			# il colore base non conosce i sentieri: li disegna lo shader per pixel (bordo netto e curvo)
			var col: Color = _ground_col(p, 99.0, 2.0)
			var h00: float = hs[jj * (n + 1) + ii]
			var h10: float = hs[jj * (n + 1) + ii + 1]
			var h11: float = hs[(jj + 1) * (n + 1) + ii + 1]
			var h01: float = hs[(jj + 1) * (n + 1) + ii]
			var a := Vector3(x0 + ii * GS, h00, z0 + jj * GS)
			var b := Vector3(x0 + (ii + 1) * GS, h10, z0 + jj * GS)
			var d := Vector3(x0 + (ii + 1) * GS, h11, z0 + (jj + 1) * GS)
			var e := Vector3(x0 + ii * GS, h01, z0 + (jj + 1) * GS)
			if (ii + jj) % 2 == 0:
				g.tri(a, b, d, g.shade(col, 0.04))
				g.tri(a, d, e, g.shade(col, 0.04))
			else:
				g.tri(a, b, e, g.shade(col, 0.04))
				g.tri(b, d, e, g.shade(col, 0.04))
			# ciottoli della strada principale: un sasso piatto per cella
			if rdv.x < rdv.y * 0.5 + 0.1 and rdv.y > 2.3 and (p.length() < 130.0 or grid_road_fn.is_valid()) and g.rn.randf() < 0.92 and not (edge_fn.is_valid() and bool(edge_fn.call(p))):
				var sp := Vector3(p.x + g.rn.randf_range(-0.1, 0.1), _height(p, 3.0) + 0.03, p.y + g.rn.randf_range(-0.15, 0.15))
				# ciottolo: un rombo piatto (2 triangoli) invece di un sasso intero
				var cw := g.rn.randf_range(0.12, 0.2)
				var cd := g.rn.randf_range(0.1, 0.18)
				var cy := g.rn.randf() * TAU
				var cx := Vector3(cos(cy) * cw, 0.0, sin(cy) * cw)
				var cz := Vector3(-sin(cy) * cd, 0.0, cos(cy) * cd)
				var ccol := g.shade(Color(0.19, 0.19, 0.2), 0.25)
				g.quad(sp - cx - cz, sp + cx - cz, sp + cx + cz, sp - cx + cz, ccol)


## erba secca: ciuffi di lame lungo un campo di densita', piu' fitti e alti dove l'erba e' folta
func _grass(j: Dictionary, half: int) -> void:
	var v: W3DBuilder = j["v"]
	var sub: Array = j["sub"]
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var st := 0.55
	var n := int(CHS / st)
	var r0 := half * (n / 2)
	var r1 := r0 + n / 2
	for jj in range(r0, r1):
		for ii in n:
			var p := Vector2(x0 + (ii + v.rn.randf()) * st, z0 + (jj + v.rn.randf()) * st)
			var rdv := _road_dist_sub(p, sub)
			var rdd: float = rdv.x - rdv.y * 0.5
			if rdd < 0.3:
				continue
			var vg := n_veg.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var dens := smoothstep(0.32, 0.78, vg + n_veg2.get_noise_2d(p.x, p.y) * 0.12)
			dens *= smoothstep(0.3, 2.2, rdd)
			dens *= [1.0, 0.85, 1.25, 1.4, 0.15, 0.4, 0.1][clampi(_bio_at(p), 0, 6)]
			if v.rn.randf() > dens:
				continue
			_tuft(v, Vector3(p.x, _height(p, 3.0), p.y), dens, n_veg2.get_noise_2d(p.x + 50.0, p.y) * 0.5 + 0.5)


func _tuft(o: W3DBuilder, p: Vector3, dens: float, tone: float) -> void:
	var pal := [Color(0.07, 0.10, 0.055), Color(0.10, 0.13, 0.07), Color(0.17, 0.15, 0.09), Color(0.13, 0.09, 0.06), Color(0.09, 0.11, 0.10), Color(0.20, 0.17, 0.10)]
	var tb := _bio_at(Vector2(p.x, p.z)) if bio_fn.is_valid() else 0
	if tb == 1:
		pal = [Color(0.10, 0.13, 0.13), Color(0.14, 0.17, 0.15), Color(0.2, 0.2, 0.2), Color(0.08, 0.1, 0.12), Color(0.16, 0.18, 0.2), Color(0.12, 0.14, 0.1)]
	elif tb == 2:
		pal = [Color(0.04, 0.12, 0.05), Color(0.06, 0.17, 0.07), Color(0.10, 0.2, 0.08), Color(0.05, 0.1, 0.06), Color(0.08, 0.15, 0.09), Color(0.12, 0.2, 0.1)]
	elif tb == 3:
		pal = [Color(0.05, 0.14, 0.10), Color(0.08, 0.18, 0.13), Color(0.12, 0.22, 0.12), Color(0.06, 0.1, 0.09), Color(0.1, 0.2, 0.16), Color(0.16, 0.24, 0.12)]
	elif tb == 5:
		pal = [Color(0.6, 0.7, 0.8), Color(0.7, 0.78, 0.86), Color(0.5, 0.62, 0.74), Color(0.8, 0.86, 0.9), Color(0.55, 0.7, 0.8), Color(0.65, 0.75, 0.85)]
	elif tb == 6:
		pal = [Color(0.2, 0.08, 0.05), Color(0.28, 0.1, 0.06), Color(0.14, 0.07, 0.06), Color(0.3, 0.16, 0.08), Color(0.18, 0.1, 0.1), Color(0.35, 0.12, 0.06)]
	var i0 := int(tone * 5.99)
	var col: Color = (pal[i0] as Color).lerp(pal[(i0 + 1 + o.rn.randi() % 2) % 6], o.rn.randf_range(0.0, 0.6))
	col.a = 0.9
	var nb := 3 + int(dens * 2.5)
	var h0 := lerpf(0.4, 1.1, dens) * o.rn.randf_range(0.65, 1.3)
	var lean := o.rn.randf() * TAU
	for i in nb:
		var a := lean + o.rn.randf_range(-1.2, 1.2) + i * 2.1
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP) * 0.075
		var hgt := h0 * o.rn.randf_range(0.6, 1.1)
		o.tri(p - side, p + side, p + dir * (0.1 + hgt * 0.35) + Vector3(0, hgt, 0), o.shade(col, 0.3))


func _bone(o: W3DBuilder, p: Vector3) -> void:
	var yaw := o.rn.randf() * TAU
	o.box(Transform3D(Basis(Vector3.UP, yaw), p), Vector3(0.5, 0.07, 0.09), Color(0.62, 0.59, 0.5), 0.1)
	if o.rn.randf() < 0.4:
		o.rock(p + Vector3(0.3, 0.1, 0.1), Vector3(0.2, 0.2, 0.2), Color(0.66, 0.63, 0.55), 0.08, 0.2, yaw)


func _clear_at(p: Vector2, r: float) -> bool:
	for cp in clear_pts:
		var cv: Vector3 = cp
		if p.distance_to(Vector2(cv.x, cv.y)) < cv.z + r:
			return true
	return false


func _free(p: Vector2, r: float, cols: Array) -> bool:
	if not clear_pts.is_empty() and _clear_at(p, r):
		return false
	if edge_fn.is_valid() and bool(edge_fn.call(p)):
		return false
	for cl in cols:
		if cl[0] == "c":
			if p.distance_to(cl[1]) < cl[2] + r:
				return false
		else:
			var c: Vector2 = cl[1]
			var half: Vector2 = cl[2]
			var yw: float = cl[3]
			var dx := p.x - c.x
			var dz := p.y - c.y
			var lx := dx * cos(yw) - dz * sin(yw)
			var lz := dx * sin(yw) + dz * cos(yw)
			if absf(lx) < half.x + r and absf(lz) < half.y + r:
				return false
	return true


## sassi, cespugli e alberi morti secondo campi di densita': a gruppi, mai isolati a caso
func _big_things(j: Dictionary) -> void:
	var o: W3DBuilder = j["o"]
	var v: W3DBuilder = j["v"]
	var sub: Array = j["sub"]
	var cols: Array = j["cols"]
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var rr: RandomNumberGenerator = o.rn
	var st := 1.25
	for jj in int(CHS / st):
		for ii in int(CHS / st):
			var p := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var rf := n_rock.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			if rf < 0.5 or rr.randf() > (rf - 0.45) * 1.4:
				continue
			var rdv := _road_dist_sub(p, sub)
			if rdv.x - rdv.y * 0.5 < 0.5:
				continue
			v.rock(Vector3(p.x, 0.07, p.y), Vector3(rr.randf_range(0.14, 0.4), rr.randf_range(0.1, 0.24), rr.randf_range(0.14, 0.4)), _rock_col(_bio_at(p)).lerp(Color.WHITE, 0.05), 0.14, 0.4, rr.randf() * TAU)
	st = 5.5
	for jj in int(ceil(CHS / st)):
		for ii in int(ceil(CHS / st)):
			var p2 := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var rf2 := n_rock.get_noise_2d(p2.x, p2.y) * 0.5 + 0.5
			if rf2 < 0.55 or rr.randf() > (rf2 - 0.5) * 2.2:
				continue
			var rdv2 := _road_dist_sub(p2, sub)
			if rdv2.x - rdv2.y * 0.5 < 2.2 or not _free(p2, 1.4, cols):
				continue
			var s := rr.randf_range(0.9, 2.1)
			var rc2 := _rock_col(_bio_at(p2))
			o.rock(Vector3(p2.x, s * 0.4, p2.y), Vector3(s * 1.3, s * 0.85, s * 1.1), rc2, 0.14, 0.45, rr.randf() * TAU)
			cols.append(["c", p2, s * 0.62])
			for q in rr.randi_range(3, 7):
				var a := rr.randf() * TAU
				var rad2 := s * rr.randf_range(0.8, 1.7)
				o.rock(Vector3(p2.x + cos(a) * rad2, 0.1, p2.y + sin(a) * rad2), Vector3(rr.randf_range(0.18, 0.5), rr.randf_range(0.14, 0.3), rr.randf_range(0.18, 0.5)), rc2.lerp(Color.WHITE, 0.04), 0.14, 0.45, rr.randf() * TAU)
	st = 3.0
	for jj in int(CHS / st):
		for ii in int(CHS / st):
			var p3 := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var sf := n_shrub.get_noise_2d(p3.x, p3.y) * 0.5 + 0.5
			if sf < 0.5 or rr.randf() > (sf - 0.42) * 2.4:
				continue
			var rdv3 := _road_dist_sub(p3, sub)
			if rdv3.x - rdv3.y * 0.5 < 1.8 or not _free(p3, 0.9, cols):
				continue
			var bb := _bio_at(p3)
			if bb == 3 and rr.randf() < 0.6:
				_obj("reed_clump", o, p3, rr.randf() * TAU, rr, cols, [])
			elif bb == 4 or bb == 6 or bb == 5:
				continue
			else:
				_bush(o, p3, rr, cols)
	st = 7.0
	for jj in int(ceil(CHS / st)):
		for ii in int(ceil(CHS / st)):
			var p4 := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var core := clampf(1.0 - p4.length() / 150.0, 0.0, 1.0)
			var tf := n_tree.get_noise_2d(p4.x, p4.y) * 0.5 + 0.5
			var tb := _bio_at(p4)
			var dmul: float = [1.0, 0.45, 2.3, 0.95, 0.12, 0.95, 0.3][clampi(tb, 0, 6)]
			if rr.randf() > (0.15 + 0.7 * (1.0 - core)) * smoothstep(0.25, 0.6, tf) * dmul:
				continue
			var rdv4 := _road_dist_sub(p4, sub)
			if rdv4.x - rdv4.y * 0.5 < 2.4 or not _free(p4, 1.0, cols):
				continue
			var tkind := "tree"
			var tr := rr.randf()
			match tb:
				2:      # foresta fitta e rigogliosa: querce dalla chioma larga, pini appuntiti, cipressi, qualche albero morto
					tkind = "oak" if tr < 0.42 else ("pine" if tr < 0.78 else ("cypress" if tr < 0.9 else "tree"))
				3:      # palude: salici, mangrovie, alberi spogli
					tkind = "willow" if tr < 0.4 else ("mangrove" if tr < 0.72 else "tree")
				4:      # cattedrale: solo qualche cipresso, come in un giardino abbandonato
					tkind = "cypress"
				5:      # vetta: pini innevati, ogni tanto un albero spoglio
					tkind = "snow_pine" if tr < 0.85 else "tree"
				6:      # fonderie: tronchi carbonizzati
					tkind = "charred_tree"
			_obj(tkind, o, p4, rr.randf() * TAU, rr, cols, [])
			if tb <= 3:
				for q in rr.randi_range(0, 2):
					var a2 := rr.randf() * TAU
					var q2 := p4 + Vector2.from_angle(a2) * rr.randf_range(1.3, 2.6)
					if _free(q2, 0.6, cols):
						_bush(o, q2, rr, cols)
				if rr.randf() < 0.4:
					_fallen_log(o, p4 + Vector2.from_angle(rr.randf() * TAU) * rr.randf_range(2.0, 3.4), rr)
	# elementi tipici dove gli alberi mancano: rovine di marmo, guglie di basalto, blocchi di ghiaccio, pozze di fango
	st = 9.0
	for jj in int(ceil(CHS / st)):
		for ii in int(ceil(CHS / st)):
			var pf := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var fb := _bio_at(pf)
			var fkind := ""
			var fch := 0.0
			match fb:
				3:
					fkind = "mud_pool"
					fch = 0.35
				4:
					fkind = "marble_rubble"
					fch = 0.45
				5:
					fkind = "ice_boulder"
					fch = 0.3
				6:
					fkind = "basalt_spire" if rr.randf() < 0.6 else "ash_mound"
					fch = 0.5
			if fkind == "" or rr.randf() > fch:
				continue
			var rdv5 := _road_dist_sub(pf, sub)
			if rdv5.x - rdv5.y * 0.5 < 2.6 or not _free(pf, 1.8, cols):
				continue
			_obj(fkind, o, pf, rr.randf() * TAU, rr, cols, [])
	for q in 6:
		var pb := Vector2(x0 + rr.randf() * CHS, z0 + rr.randf() * CHS)
		if n_stain.get_noise_2d(pb.x + 400.0, pb.y - 300.0) > 0.42:
			_bone(v, Vector3(pb.x, 0.05, pb.y))


func _bush(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var dry := r.randf() < 0.45
	var base := Color(0.20, 0.17, 0.10) if dry else Color(0.10, 0.15, 0.085)
	for i in r.randi_range(3, 5):
		var q := p + Vector2(r.randf_range(-0.75, 0.75), r.randf_range(-0.75, 0.75))
		var s := r.randf_range(0.7, 1.3)
		o.rock(Vector3(q.x, s * 0.42, q.y), Vector3(s * 1.1, s * 0.85, s * 1.1), base, 0.2, 0.45, r.randf() * TAU)
	for i in 4:
		var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.6, 1.1)), Vector3(p.x, 0.5, p.y))
		o.cyl(t, 0.035, 0.012, r.randf_range(0.8, 1.4), 3, Color(0.2, 0.15, 0.1), 0.15, false)
	if r.randf() < 0.5:
		cols.append(["c", p, 0.55])


func _fallen_log(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator) -> void:
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.FORWARD, PI * 0.5), Vector3(p.x, 0.22, p.y))
	o.cyl(t, 0.24, 0.17, r.randf_range(1.8, 3.2), 5, Color(0.16, 0.115, 0.09), 0.14)


# ------------------------------------------------------------------ lotti
## piano di un lotto (stesso risultato ovunque venga chiesto): tipo, orientamento rispetto alla strada
func _plan(ix: int, iz: int) -> Dictionary:
	var key := Vector2i(ix, iz)
	if plans.has(key):
		return plans[key]
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(ix, iz, seed_v * 7 + 3))
	var cp := Vector2((ix + 0.5 + r.randf_range(-0.12, 0.12)) * LC, (iz + 0.5 + r.randf_range(-0.12, 0.12)) * LC)
	var rn_ := _road_near(cp)
	var d: float = rn_["d"]
	var rw: float = rn_["w"]
	var core := clampf(1.0 - cp.length() / 150.0, 0.0, 1.0)
	var roll := r.randf()
	var kind := "wild"
	if d < rw * 0.5 + 2.0:
		kind = "road"
	elif _zone_grave(floori(float(ix) / 3.0), floori(float(iz) / 3.0)):
		kind = "grave"
	elif d < rw * 0.5 + 3.4:
		kind = "edge"
	elif d < 11.5 and roll < 0.1 + 0.9 * core:
		kind = "house"
	elif d < 14.0 and roll < 0.62 + 0.2 * core:
		kind = "yard"
	var pl := {"cp": cp, "d": d, "rw": rw, "kind": kind, "seed": r.randi(), "road": rn_, "core": core}
	plans[key] = pl
	return pl


func _zone_grave(gx: int, gz: int) -> bool:
	var key := Vector2i(gx, gz)
	if zones.has(key):
		return zones[key]
	var h := fposmod(sin(float(gx) * 12.9898 + float(gz) * 78.233 + float(seed_v)) * 43758.5453, 1.0)
	var res := false
	var gthr := 0.13
	if bio_fn.is_valid() and _bio_at(Vector2((gx * 3 + 1.5) * LC, (gz * 3 + 1.5) * LC)) == 1:
		gthr = 0.55
	if h < gthr:
		var ctr := Vector2((gx * 3 + 1.5) * LC, (gz * 3 + 1.5) * LC)
		res = float(_road_near(ctr)["d"]) > 13.0
	zones[key] = res
	return res


func _lot(j: Dictionary, ix: int, iz: int) -> void:
	var o: W3DBuilder = j["o"]
	var cols: Array = j["cols"]
	var lamps: Array = j["lamps"]
	var pl := _plan(ix, iz)
	var r := RandomNumberGenerator.new()
	r.seed = int(pl["seed"])
	o.rn.seed = r.randi()
	var cp: Vector2 = pl["cp"]
	var kind: String = pl["kind"]
	if kind != "road" and not clear_pts.is_empty() and _clear_at(cp, 3.0):
		return
	if edge_fn.is_valid() and bool(edge_fn.call(cp)):
		return
	if edge_fn.is_valid() and kind != "road":
		var wdr := _water_dir(cp)
		if wdr.z > 0.0 and r.randf() < 0.55 and _water_wide(cp, wdr):
			_pier(o, cp, wdr, r, cols, lamps)
	if no_base_houses and kind == "house":
		kind = "yard"
	var rn_: Dictionary = pl["road"]
	var tan_: Vector2 = rn_["tan"]
	var toward: Vector2 = (rn_["nearest"] - cp).normalized()
	if kind == "house":
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var np := _plan(ix + dx, iz + dz)
				if np["kind"] == "house" and hash(Vector2i(ix + dx, iz + dz)) < hash(Vector2i(ix, iz)) and cp.distance_to(np["cp"]) < 7.6:
					kind = "yard"
		if kind == "house":
			var yaw := atan2(-toward.y, toward.x) + r.randf_range(-0.2, 0.2)
			_obj("house", o, cp, yaw, r, cols, lamps)
			return
	match kind:
		"edge":
			_roadside(o, cp, tan_, toward, r, cols, float(pl["rw"]))
		"yard":
			_yard(o, cp, tan_, toward, r, cols, float(pl["core"]))
		"grave":
			_grave_lot(o, ix, iz, r, cols, lamps)
		"wild":
			# strutture e meraviglie naturali del bioma, isolate: sempre qualcosa di nuovo da scoprire
			var sr := RandomNumberGenerator.new()
			sr.seed = hash(Vector3i(ix, iz, seed_v + 99))
			if sr.randf() < 0.045 and float(pl["d"]) > 10.0:
				var nk := W3DStructs.pick(_bio_at(cp), sr)
				if nk != "" and _free(cp, W3DStructs.radius(nk), cols):
					_obj(nk, o, cp, sr.randf() * TAU, r, cols, lamps)
					return
			var roll := r.randf()
			if roll > 0.985:
				_obj("gallows", o, cp, 0.0, r, cols, lamps)
			elif roll > 0.955:
				_obj("pyre", o, cp, 0.0, r, cols, lamps)
			elif roll > 0.9:
				_obj("ruin", o, cp, 0.0, r, cols, lamps)


func _offset_from_road(p: Vector2, dist: float) -> Vector2:
	var rn_ := _road_near(p)
	var nr: Vector2 = rn_["nearest"]
	return nr + (p - nr).normalized() * dist


func _roadside(o: W3DBuilder, cp: Vector2, tan_: Vector2, toward: Vector2, r: RandomNumberGenerator, cols: Array, rw: float) -> void:
	var yaw := atan2(-tan_.y, tan_.x)
	var roll := r.randf()
	if roll < 0.35:
		var fa := _offset_from_road(cp - tan_ * 3.4, rw * 0.5 + 2.1)
		var fb := _offset_from_road(cp + tan_ * 3.4, rw * 0.5 + 2.1)
		_fence_run(o, fa, fb, r, cols, false)
	elif roll < 0.55:
		_cart(o, cp, yaw + r.randf_range(-0.2, 0.2), r, cols)
	elif roll < 0.7:
		_bench(o, cp, yaw, r, cols)
	elif roll < 0.85:
		for i in r.randi_range(2, 4):
			var q := cp + tan_ * (i * 0.9 - 1.2) + toward * r.randf_range(-0.3, 0.3)
			if r.randf() < 0.55:
				_obj("barrel", o, q, 0.0, r, cols, [])
			else:
				_obj("crate", o, q, 0.0, r, cols, [])
	else:
		_sign(o, cp, yaw, r, cols)



## campo di grano: file di spighe dorate su terra arata, con staccionata e spaventapasseri
## direzione (e distanza) dell'acqua piu' vicina entro 7 unita'; Vector3(dx, dz, dist) oppure z = -1 se non c'e'
func _water_dir(cp: Vector2) -> Vector3:
	var best := Vector3(0, 0, -1)
	var bd := 99.0
	for k in 12:
		var a := TAU * k / 12.0
		var dv := Vector2(cos(a), sin(a))
		for dist in [1.5, 2.5, 3.5, 4.5, 5.5, 6.5]:
			if bool(edge_fn.call(cp + dv * dist)):
				if dist < bd:
					bd = dist
					best = Vector3(dv.x, dv.y, dist)
				break
	return best


## molo di assi con pali, lanterna in fondo e una barca ormeggiata
func _pier(o: W3DBuilder, cp: Vector2, wd: Vector3, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	pier_n += 1
	if OS.get_cmdline_user_args().has("--hold"):
		print("PIER ", cp)
	if first_pier.x < -9000.0 or cp.length() < first_pier.length():
		first_pier = cp
	var dv := Vector2(wd.x, wd.y)
	var sp := cp + dv * maxf(wd.z - 0.9, 0.0)
	var ang := -atan2(dv.y, dv.x)
	var t := Transform3D(Basis(Vector3.UP, ang), Vector3(sp.x, 0, sp.y))
	var ln := r.randf_range(4.5, 6.5)
	var wood := Color(0.26, 0.17, 0.1)
	var n := int((ln + 1.8) / 0.38)
	for i in n:
		var x := -1.8 + i * 0.38
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(x, 0.1, 0)), Vector3(0.34, 0.07, 1.25), wood.lerp(Color(0.34, 0.22, 0.12), r.randf()), 0.1, 8)
	for sz in [-1, 1]:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(ln * 0.5 - 0.9, 0.04, sz * 0.58)), Vector3(ln + 1.8, 0.08, 0.1), Color(0.18, 0.11, 0.07), 0.08, 8)
		for q in range(1, 4):
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(q * ln / 3.5, -0.7, sz * 0.58)), 0.1, 0.09, 0.95, 5, Color(0.15, 0.1, 0.07), 0.1)
	var lpv: Vector3 = t * Vector3(ln, 0.0, -0.55)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(ln, 0.1, -0.55)), 0.06, 0.05, 1.3, 5, Color(0.14, 0.1, 0.07), 0.08)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(ln, 1.5, -0.55)), Vector3(0.24, 0.3, 0.24), Color(0.95, 0.8, 0.6, 0.15), 0.0, 8)
	lamps.append(Vector4(lpv.x, 1.6, lpv.z, 1.1))
	var side := 1.0 if r.randf() < 0.5 else -1.0
	var bt := t * Transform3D(Basis(Vector3.UP, r.randf_range(-0.1, 0.1)), Vector3(ln * 0.55, -0.3, side * 1.45))
	o.box(bt * Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), Vector3(2.3, 0.28, 0.95), Color(0.22, 0.14, 0.09), 0.1, 8)
	o.box(bt * Transform3D(Basis.IDENTITY, Vector3(0, 0.26, 0.4)), Vector3(2.1, 0.12, 0.1), Color(0.3, 0.2, 0.12), 0.08, 8)
	o.box(bt * Transform3D(Basis.IDENTITY, Vector3(0, 0.26, -0.4)), Vector3(2.1, 0.12, 0.1), Color(0.3, 0.2, 0.12), 0.08, 8)
	o.box(bt * Transform3D(Basis.IDENTITY, Vector3(1.2, 0.2, 0.0)), Vector3(0.1, 0.1, 0.8), Color(0.3, 0.2, 0.12), 0.08, 8)
	o.box(bt * Transform3D(Basis.IDENTITY, Vector3(0.0, 0.16, 0.0)), Vector3(1.5, 0.05, 0.7), Color(0.1, 0.07, 0.05), 0.0, 8)
	o.shard(bt * Vector3(-0.8, 0.1, 0.0), bt * Vector3(-1.5, 0.35, 0.0), 0.2, 0.05, Color(0.22, 0.14, 0.09), 0.3, 0.05, 0.03)
	o.shard(bt * Vector3(1.0, 0.1, 0.0), bt * Vector3(1.7, 0.45, 0.0), 0.2, 0.04, Color(0.22, 0.14, 0.09), 0.3, 0.05, 0.03)
	for k in 6:
		var qp := sp + Vector2(-dv.y, dv.x) * r.randf_range(-3.5, 3.5) - dv * r.randf_range(0.3, 1.2)
		if bool(edge_fn.call(qp)):
			continue
		for j in 4:
			var b0 := Vector3(qp.x + r.randf_range(-0.15, 0.15), 0.0, qp.y + r.randf_range(-0.15, 0.15))
			o.shard(b0, b0 + Vector3(r.randf_range(-0.1, 0.1), r.randf_range(0.5, 0.9), r.randf_range(-0.1, 0.1)), 0.06, 0.01, Color(0.12, 0.2, 0.1).lerp(Color(0.25, 0.25, 0.12), r.randf()), 0.3, 0.1, 0.05)


func _wheat_field(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	field_n += 1
	if field_n == 1:
		first_field = p
	if field_n == 1 and OS.get_cmdline_user_args().has("--hold"):
		print("FIELD at ", p, " off=", house_doors.size())
	var w := r.randf_range(5.2, 6.6)
	var d := r.randf_range(4.2, 5.4)
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	var rows := int(d / 0.5)
	for i in rows:
		var z := -d * 0.5 + (i + 0.5) * 0.5
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, z)), Vector3(w, 0.05, 0.3), Color(0.12, 0.085, 0.055), 0.12, 8)
		var n := int(w / 0.3)
		for j in n:
			var x := -w * 0.5 + (j + r.randf()) * 0.3
			var base: Vector3 = t * Vector3(x, 0.0, z + r.randf_range(-0.05, 0.05))
			var tip: Vector3 = t * Vector3(x + r.randf_range(-0.08, 0.08), 0.65 + r.randf() * 0.4, z + r.randf_range(-0.08, 0.08))
			var wc := Color(0.66, 0.5, 0.16).lerp(Color(0.82, 0.66, 0.26), r.randf())
			o.shard(base, tip, 0.13, 0.02, wc, 0.35, 0.12, 0.06)
			# la spiga: un grano piu' chiaro in punta
			o.shard(tip - (tip - base) * 0.25, tip + Vector3(0, 0.1, 0), 0.08, 0.015, Color(0.92, 0.76, 0.32), 0.3, 0.05, 0.03)
	var hx := w * 0.5 + 0.5
	var hz := d * 0.5 + 0.5
	var cs := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
	var wc2: Array = []
	for c2 in cs:
		var wv: Vector3 = t * Vector3(c2.x, 0, c2.y)
		wc2.append(Vector2(wv.x, wv.z))
	if _fence_ok(p):
		for si in 4:
			_fence_run(o, wc2[si], wc2[(si + 1) % 4], r, cols, si == 1)
	if r.randf() < 0.7:
		_scarecrow(o, p + Vector2(r.randf_range(-1.0, 1.0), r.randf_range(-0.8, 0.8)), r, cols)


## orto: aiuole di cavoli e zucche con un cespuglio di bacche
func _veg_patch(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	for i in 4:
		var z := -1.6 + i * 1.05
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.07, z)), Vector3(4.6, 0.14, 0.7), Color(0.14, 0.09, 0.06), 0.12, 8)
		for j in 7:
			var x := -2.0 + j * 0.66 + r.randf_range(-0.08, 0.08)
			var q: Vector3 = t * Vector3(x, 0.2, z)
			if i % 2 == 0:
				o.blob(q, Vector3(0.24, 0.2, 0.24), Color(0.18, 0.3, 0.12).lerp(Color(0.26, 0.38, 0.16), r.randf()), 6, 3, 0.12, 0.05)
			else:
				o.blob(q + Vector3(0, 0.05, 0), Vector3(0.22, 0.18, 0.22), Color(0.7, 0.32, 0.08).lerp(Color(0.8, 0.45, 0.1), r.randf()), 6, 3, 0.1, 0.04)
	var a := cp_corner(t, -2.7, -2.4)
	var b := cp_corner(t, 2.7, -2.4)
	var c := cp_corner(t, 2.7, 2.0)
	var d := cp_corner(t, -2.7, 2.0)
	if _fence_ok(p):
		_fence_run(o, a, b, r, cols, false)
		_fence_run(o, b, c, r, cols, false)
		_fence_run(o, c, d, r, cols, true)
		_fence_run(o, d, a, r, cols, false)


func cp_corner(t: Transform3D, x: float, z: float) -> Vector2:
	var v: Vector3 = t * Vector3(x, 0, z)
	return Vector2(v.x, v.z)


func _yard(o: W3DBuilder, cp: Vector2, tan_: Vector2, toward: Vector2, r: RandomNumberGenerator, cols: Array, core: float) -> void:
	var roll := r.randf()
	var yaw := atan2(-tan_.y, tan_.x)
	# vicino al paese: campi di grano e orti
	if core > 0.12 and roll < 0.34:
		_wheat_field(o, cp, yaw, r, cols)
		return
	if core > 0.12 and roll < 0.46:
		_veg_patch(o, cp, yaw, r, cols)
		return
	if roll < 0.2 and core > 0.15:
		_obj("well", o, cp, 0.0, r, cols, [])
	elif roll < 0.42:
		_obj("hay", o, cp, 0.0, r, cols, [])
		for i in r.randi_range(0, 2):
			_obj("hay", o, cp + Vector2(r.randf_range(-2.5, 2.5), r.randf_range(-2.5, 2.5)), 0.0, r, cols, [])
	elif roll < 0.62:
		_woodpile(o, cp, yaw, r, cols)
		for i in r.randi_range(1, 3):
			_obj("barrel", o, cp + Vector2(r.randf_range(-2.5, 2.5), r.randf_range(-2.5, 2.5)), 0.0, r, cols, [])
	elif roll < 0.78:
		var a := cp - tan_ * 2.6 - toward * 2.6
		var b := cp + tan_ * 2.6 - toward * 2.6
		var c := cp + tan_ * 2.6 + toward * 2.6
		var d := cp - tan_ * 2.6 + toward * 2.6
		if _fence_ok(cp):
			_fence_run(o, a, b, r, cols, false)
			_fence_run(o, b, c, r, cols, false)
			_fence_run(o, c, d, r, cols, true)
			_fence_run(o, d, a, r, cols, false)
		_obj("hay", o, cp, 0.0, r, cols, [])
		_bone(o, Vector3(cp.x + 1.0, 0.05, cp.y - 0.8))
	elif roll < 0.9 and core < 0.5:
		_scarecrow(o, cp, r, cols)
	else:
		for i in r.randi_range(2, 5):
			var q := cp + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3))
			if r.randf() < 0.5:
				_obj("crate", o, q, 0.0, r, cols, [])
			else:
				_obj("barrel", o, q, 0.0, r, cols, [])


## cimitero: caotico e vissuto. Lapidi grandi e storte, croci enormi, obelischi, sarcofagi, tombe aperte, tumuli, ossa;
## al centro una cappella o un mausoleo, a volte un secondo mausoleo. Cancellata rotta e piena di buchi, alberi morti.
func _grave_lot(o: W3DBuilder, ix: int, iz: int, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var ox := ix * LC
	var oz := iz * LC
	var zx := posmod(ix, 3)
	var zz := posmod(iz, 3)
	var gx := floori(float(ix) / 3.0)
	var gz := floori(float(iz) / 3.0)
	var hz := fposmod(sin(float(gx) * 7.13 + float(gz) * 31.7 + float(seed_v) * 0.7) * 43758.5453, 1.0)
	var hz2 := fposmod(sin(float(gx) * 3.9 + float(gz) * 17.3 + float(seed_v) * 0.31) * 43758.5453, 1.0)
	var center := Vector2(ox + LC * 0.5, oz + LC * 0.5)
	var built := false
	if zx == 1 and zz == 1:
		if hz > 0.38:
			_obj("chapel", o, center + Vector2(r.randf_range(-0.6, 0.6), 0), r.randf_range(-0.12, 0.12), r, cols, lamps)
		else:
			_obj("mausoleum", o, center, r.randf_range(-0.1, 0.1), r, cols, lamps)
		built = true
	elif ((zx == 0 and zz == 2) or (zx == 2 and zz == 0)) and hz2 > 0.55 and ((zx == 0) == (hz2 > 0.78)):
		_obj("mausoleum", o, center + Vector2(r.randf_range(-0.8, 0.8), r.randf_range(-0.8, 0.8)), r.randf_range(-0.7, 0.7), r, cols, lamps)
		built = true
	# lapidi: gruppi disordinati, raggruppate attorno a 1-2 centri (famiglie), qualche isolata
	var clusters: Array = []
	for i in r.randi_range(1, 2):
		clusters.append(Vector2(ox + r.randf_range(1.5, LC - 1.5), oz + r.randf_range(1.5, LC - 1.5)))
	var n := r.randi_range(3, 6) if built else r.randi_range(5, 9)
	for i in n:
		var q: Vector2
		if r.randf() < 0.7:
			var cc: Vector2 = clusters[r.randi() % clusters.size()]
			q = cc + Vector2(r.randfn(0.0, 1.5), r.randfn(0.0, 1.5))
		else:
			q = Vector2(ox + r.randf_range(0.6, LC - 0.6), oz + r.randf_range(0.6, LC - 0.6))
		if float(_road_near(q)["d"]) < 2.4 or not _free(q, 0.9, cols):
			continue
		_grave_item(o, q, r, cols, lamps)
	# cancellata rotta lungo il perimetro: pezzi con molti buchi, qualche palo piegato
	var edges: Array = []
	if zx == 0:
		edges.append([Vector2(ox + 0.1, oz), Vector2(ox + 0.1, oz + LC)])
	if zx == 2:
		edges.append([Vector2(ox + LC - 0.1, oz), Vector2(ox + LC - 0.1, oz + LC)])
	if zz == 0:
		edges.append([Vector2(ox, oz + 0.1), Vector2(ox + LC, oz + 0.1)])
	if zz == 2:
		edges.append([Vector2(ox, oz + LC - 0.1), Vector2(ox + LC, oz + LC - 0.1)])
	for ed in edges:
		var a: Vector2 = ed[0]
		var b2: Vector2 = ed[1]
		var parts := 4
		for pi in parts:
			if r.randf() < 0.32:
				continue
			var pa := a.lerp(b2, float(pi) / parts)
			var pb := a.lerp(b2, float(pi + 1) / parts - r.randf_range(0.0, 0.07))
			_fence_run(o, pa, pb, r, cols, false)
	if (zx == 0 or zx == 2) and (zz == 0 or zz == 2) and r.randf() < 0.8:
		_obj("tree", o, Vector2(ox + (1.4 if zx == 0 else LC - 1.4), oz + (1.4 if zz == 0 else LC - 1.4)), 0.0, r, cols, lamps)
	for i in r.randi_range(0, 2):
		_bush(o, Vector2(ox + r.randf_range(1, LC - 1), oz + r.randf_range(1, LC - 1)), r, cols)
	for i in r.randi_range(1, 4):
		_bone(o, Vector3(ox + r.randf_range(0.5, LC - 0.5), 0.05, oz + r.randf_range(0.5, LC - 0.5)))


func _grave_item(o: W3DBuilder, q: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var stone := Color(0.30, 0.30, 0.32).lerp(Color(0.24, 0.30, 0.25), r.randf() * 0.5)
	var yaw := r.randf() * TAU if r.randf() < 0.3 else r.randf_range(-0.6, 0.6)
	var lean := Basis(Vector3.FORWARD, r.randf_range(-0.28, 0.28)) * Basis(Vector3.RIGHT, r.randf_range(-0.2, 0.2))
	var t := Transform3D(Basis(Vector3.UP, yaw) * lean, Vector3(q.x, 0, q.y))
	var kind := r.randf()
	if kind < 0.28:
		# lapide alta con cima arrotondata o a punta
		var h := r.randf_range(1.5, 2.3)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Vector3(r.randf_range(0.95, 1.3), h, 0.3), stone, 0.16, 8)
		o.box(t * Transform3D(Basis(Vector3.FORWARD, 0.785), Vector3(0, h + 0.05, 0)), Vector3(0.78, 0.78, 0.3), stone, 0.16, 8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.55, -0.17)), Vector3(0.5, 0.09, 0.06), stone * 0.6, 0.1, 8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.38, -0.17)), Vector3(0.36, 0.07, 0.06), stone * 0.6, 0.1, 8)
		cols.append(["c", q, 0.6])
	elif kind < 0.5:
		# croce grande, di pietra o di legno
		var wood := r.randf() < 0.4
		var cc := Color(0.27, 0.19, 0.14) if wood else stone * 1.08
		var h2 := r.randf_range(2.0, 3.0)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h2 * 0.5, 0)), Vector3(0.28, h2, 0.28), cc, 0.15, 8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h2 * 0.72, 0)), Vector3(1.35, 0.26, 0.26), cc, 0.15, 8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)), Vector3(0.9, 0.34, 0.9), stone * 0.8, 0.15, 8)
		cols.append(["c", q, 0.55])
	elif kind < 0.62:
		# obelisco
		var h3 := r.randf_range(2.6, 3.8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Vector3(1.2, 0.56, 1.2), stone * 0.85, 0.15, 8)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), 0.5, 0.17, h3, 4, stone * 1.1, 0.16)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.55 + h3, 0)), 0.17, 0.0, 0.5, 4, stone * 1.2, 0.16, false)
		cols.append(["c", q, 0.7])
	elif kind < 0.74:
		# sarcofago con coperchio storto
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), Vector3(1.3, 0.8, 2.5), stone * 0.9, 0.16, 8)
		o.box(t * Transform3D(Basis(Vector3.UP, r.randf_range(-0.1, 0.1)), Vector3(0.12, 0.88, 0.1)), Vector3(1.45, 0.2, 2.65), stone * 1.12, 0.16, 8)
		cols.append(["b", q, Vector2(0.78, 1.38), yaw])
	elif kind < 0.84:
		# tomba aperta: buca scura, terra smossa, assi
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), Vector3(1.15, 0.06, 2.3), Color(0.015, 0.012, 0.02), 0.0, 8)
		for si in 2:
			var sd := -1.0 if si == 0 else 1.0
			o.rock(t * Vector3(sd * 0.95, 0.2, r.randf_range(-0.5, 0.5)), Vector3(0.7, 0.42, 1.8), Color(0.19, 0.14, 0.11), 0.16, 0.35, yaw)
		o.box(t * Transform3D(Basis(Vector3.FORWARD, r.randf_range(0.3, 0.5)), Vector3(0.1, 0.35, 0.3)), Vector3(0.14, 0.05, 1.5), WOOD, 0.14, 8)
		o.box(t * Transform3D(Basis(Vector3.UP, 0.2) * Basis(Vector3.FORWARD, -0.2), Vector3(0.3, 0.15, -0.5)), Vector3(0.14, 0.05, 1.2), WOOD, 0.14, 8)
		cols.append(["b", q, Vector2(0.6, 1.2), yaw])
	elif kind < 0.93:
		# tumulo di terra con piccola croce e fiori secchi
		o.rock(Vector3(q.x, 0.25, q.y), Vector3(1.0, 0.5, 2.0), Color(0.2, 0.15, 0.11), 0.16, 0.3, yaw)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.75, -1.0)), Vector3(0.1, 1.0, 0.1), WOOD, 0.15, 8)
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -1.0)), Vector3(0.55, 0.1, 0.1), WOOD, 0.15, 8)
		if r.randf() < 0.5:
			o.box(Transform3D(Basis.IDENTITY, Vector3(q.x + 0.4, 0.14, q.y - 0.7)), Vector3(0.1, 0.2, 0.1), Color(0.95, 0.82, 0.55, 0.15), 0.0, 8)
			lamps.append(Vector4(q.x + 0.4, 0.4, q.y - 0.7, 0.45))
		cols.append(["b", q, Vector2(0.55, 1.0), yaw])
	else:
		# lapide spezzata e frammenti
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(1.0, 1.1, 0.3), stone, 0.16, 8)
		o.rock(t * Vector3(0.9, 0.2, 0.5), Vector3(0.6, 0.4, 0.5), stone * 0.9, 0.16, 0.4, yaw)
		o.rock(t * Vector3(-0.7, 0.15, 0.9), Vector3(0.5, 0.3, 0.4), stone * 0.85, 0.16, 0.4, yaw)
		cols.append(["c", q, 0.6])


func _mausoleum(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var stone := Color(0.30, 0.30, 0.33)
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	var w := 4.6
	var d := 4.2
	var h := 3.4
	for i in 3:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.15 + i * 0.0, d * 0.5 + 0.5 + i * 0.5)), Vector3(w + 0.4, 0.3 - 0.0, 0.6), stone * (0.8 + 0.06 * i), 0.14, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Vector3(w, h, d), stone, 0.16, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5 + 0.05, 0)), Vector3(w + 0.25, 0.22, d + 0.25), stone * 0.75, 0.12, 8)
	# frontone triangolare e tetto
	var a: Vector3 = t * Vector3(-w * 0.5 - 0.3, h + 0.1, d * 0.5 + 0.3)
	var b: Vector3 = t * Vector3(w * 0.5 + 0.3, h + 0.1, d * 0.5 + 0.3)
	var c: Vector3 = t * Vector3(0, h + 1.5, d * 0.5 + 0.3)
	o.tri(a, b, c, o.shade(stone * 1.05, 0.15))
	o.tri(b, a, c, o.shade(stone * 0.8, 0.15))
	var e0: Vector3 = t * Vector3(-w * 0.5 - 0.3, h + 0.1, -d * 0.5 - 0.3)
	var e1: Vector3 = t * Vector3(w * 0.5 + 0.3, h + 0.1, -d * 0.5 - 0.3)
	var rf0: Vector3 = t * Vector3(0, h + 1.5, -d * 0.5 - 0.3)
	o.lattice(a, a + (e0 - a), c, rf0, 1, 1, stone * 0.7, 0.05, 0.0, Vector3.UP)
	o.lattice(b, e1, c, rf0, 1, 1, stone * 0.75, 0.05, 0.0, Vector3.UP)
	# colonne davanti, porta scura, cancelletto, statue e croce
	for sx in [-1.7, -0.6, 0.6, 1.7]:
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(sx, 0.3, d * 0.5 + 0.55)), 0.26, 0.22, h - 0.3, 6, stone * 1.1, 0.14)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.25, d * 0.5 + 0.06)), Vector3(1.5, 2.5, 0.2), Color(0.02, 0.015, 0.025), 0.0, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, d * 0.5 + 0.2)), Vector3(1.0, 2.0, 0.07), Color(0.12, 0.1, 0.1), 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h + 1.9, d * 0.5 + 0.3)), Vector3(0.18, 0.9, 0.18), stone * 1.1, 0.14, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h + 2.1, d * 0.5 + 0.3)), Vector3(0.7, 0.16, 0.18), stone * 1.1, 0.14, 8)
	for sx in [-1.0, 1.0]:
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(sx * 3.2, 0.0, d * 0.5 + 0.6)), 0.4, 0.3, 1.3, 5, stone * 0.9, 0.14)
		o.rock(t * Vector3(sx * 3.2, 1.7, d * 0.5 + 0.6), Vector3(0.55, 0.8, 0.55), stone * 1.1, 0.14, 0.3, 0.0)
	var lp: Vector3 = t * Vector3(-1.2, 1.6, d * 0.5 + 0.9)
	o.box(Transform3D(Basis.IDENTITY, lp), Vector3(0.22, 0.34, 0.22), Color(0.9, 0.85, 0.6, 0.15), 0.0, 8)
	lamps.append(Vector4(lp.x, lp.y, lp.z, 0.9))
	cols.append(["b", p, Vector2(w * 0.5 + 0.3, d * 0.5 + 0.3), yaw])
	cols.append(["b", p + Vector2(sin(yaw), cos(yaw)) * (d * 0.5 + 0.9), Vector2(w * 0.5, 0.35), yaw])


func _chapel(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var wall := Color(0.27, 0.26, 0.28)
	var slate := Color(0.14, 0.15, 0.19)
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	var w := 4.4
	var d := 6.6
	var h := 3.0
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), Vector3(w + 0.5, 0.4, d + 0.5), wall * 0.75, 0.12, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Vector3(w, h, d), wall, 0.16, 8)
	# tetto a falde (con buchi) e frontone
	var ov := 0.5
	for sgn in [1.0, -1.0]:
		var e0: Vector3 = t * Vector3(sgn * (w * 0.5 + ov), h - 0.1, -(d * 0.5 + ov))
		var e1: Vector3 = t * Vector3(sgn * (w * 0.5 + ov), h - 0.1, d * 0.5 + ov)
		var rr0: Vector3 = t * Vector3(0, h + 2.0, -(d * 0.5 + ov))
		var rr1: Vector3 = t * Vector3(0, h + 2.0, d * 0.5 + ov)
		var nrm: Vector3 = (t.basis * Vector3(sgn * 2.0, w * 0.5 + ov, 0)).normalized()
		o.lattice(e0, e1, rr0, rr1, 1, 1, slate, 0.05, 0.0, nrm, 0.0, 0.0)
		o.quad(e0 - nrm * 0.18, e1 - nrm * 0.18, rr1 - nrm * 0.18, rr0 - nrm * 0.18, Color(0.04, 0.035, 0.04))
	var fa: Vector3 = t * Vector3(-w * 0.5, h, d * 0.5)
	var fb: Vector3 = t * Vector3(w * 0.5, h, d * 0.5)
	var fc: Vector3 = t * Vector3(0, h + 2.0, d * 0.5)
	o.tri(fa, fb, fc, o.shade(wall * 1.05, 0.15))
	o.tri(fb, fa, fc, o.shade(wall * 0.8, 0.15))
	# campanile
	var tw := Transform3D(t.basis, t * Vector3(0, 0, -d * 0.5 - 0.6))
	o.box(tw * Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 0)), Vector3(2.0, 6.0, 2.0), wall * 1.05, 0.16, 8)
	o.box(tw * Transform3D(Basis.IDENTITY, Vector3(0, 6.1, 0)), Vector3(2.3, 0.3, 2.3), wall * 0.7, 0.12, 8)
	o.cyl(tw * Transform3D(Basis(Vector3.UP, 0.785), Vector3(0, 6.25, 0)), 1.6, 0.0, 2.6, 4, slate * 1.2, 0.2, false)
	o.box(tw * Transform3D(Basis.IDENTITY, Vector3(0, 5.2, 1.02)), Vector3(0.7, 1.1, 0.1), Color(0.02, 0.015, 0.025), 0.0, 8)
	o.box(tw * Transform3D(Basis.IDENTITY, Vector3(0, 8.9, 0)), Vector3(0.14, 0.8, 0.14), wall * 1.2, 0.14, 8)
	o.box(tw * Transform3D(Basis.IDENTITY, Vector3(0, 9.0, 0)), Vector3(0.55, 0.14, 0.14), wall * 1.2, 0.14, 8)
	# porta ad arco, vetrate accese, scalini
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, d * 0.5 + 0.06)), Vector3(1.4, 2.2, 0.16), Color(0.03, 0.02, 0.03), 0.0, 8)
	o.box(t * Transform3D(Basis(Vector3.FORWARD, 0.785), Vector3(0, 2.25, d * 0.5 + 0.06)), Vector3(1.0, 1.0, 0.16), Color(0.03, 0.02, 0.03), 0.0, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, d * 0.5 + 0.6)), Vector3(2.4, 0.24, 1.0), wall * 0.8, 0.12, 8)
	for sz in [-1.7, 0.2, 2.0]:
		for sd in [-1.0, 1.0]:
			var wp: Vector3 = t * Vector3(sd * (w * 0.5 + 0.05), 1.7, sz)
			o.box(Transform3D(t.basis * Basis(Vector3.UP, 0.0), wp), Vector3(0.14, 1.3, 0.6), Color(0.95, 0.8, 0.5, 0.2), 0.0, 8)
			lamps.append(Vector4(wp.x + sd * t.basis.x.x * 0.7, 1.7, wp.z + sd * t.basis.x.z * 0.7, 0.5))
	cols.append(["b", p, Vector2(w * 0.5 + 0.3, d * 0.5 + 0.3), yaw])
	cols.append(["b", p + Vector2(sin(yaw), cos(yaw)) * (-d * 0.5 - 0.6), Vector2(1.2, 1.2), yaw])


# ------------------------------------------------------------------ casa
func _house(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var w := r.randf_range(3.6, 4.9)
	var d := r.randf_range(4.2, 6.0)
	var wh := r.randf_range(2.1, 2.9)
	var rh := w * r.randf_range(0.45, 0.7)
	var dr := RandomNumberGenerator.new()      # dettagli: generatore a parte, cosi' la forma delle case non cambia
	dr.seed = hash(Vector2i(roundi(p.x * 8.0), roundi(p.y * 8.0)))
	var style := r.randi() % 3
	var base_col: Color = [Color(0.25, 0.235, 0.235), Color(0.21, 0.15, 0.11), Color(0.30, 0.27, 0.24)][style]
	var roof_col: Color = [Color(0.22, 0.14, 0.12), Color(0.15, 0.155, 0.17), Color(0.19, 0.16, 0.13), Color(0.15, 0.18, 0.145)][r.randi() % 4]
	var lean := Basis.from_euler(Vector3(r.randf_range(-0.05, 0.05), 0, r.randf_range(-0.05, 0.05)))
	var t0 := Transform3D(Basis(Vector3.UP, yaw) * lean, Vector3(p.x, 0, p.y))
	var sx := [-1.0, 1.0, 1.0, -1.0]
	var sz := [-1.0, -1.0, 1.0, 1.0]
	var bc: Array = []
	var tc: Array = []
	for i in 4:
		var bx: float = sx[i] * w * 0.5 + r.randf_range(-0.3, 0.3)
		var bz: float = sz[i] * d * 0.5 + r.randf_range(-0.3, 0.3)
		bc.append(t0 * Vector3(bx, 0, bz))
		tc.append(t0 * Vector3(bx * 0.96, wh + r.randf_range(-0.3, 0.3), bz * 0.96))
	# anima scura che chiude le fessure. Gli angoli rientrano fino a 0.3 (e in cima di un altro 4%): deve restarci
	# dentro, altrimenti buca le pareti e in prima persona si vedono grandi macchie nere.
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(0, (wh - 0.36) * 0.5, 0)), Vector3(w - 0.86, wh - 0.36, d - 0.9), Color(0.04, 0.035, 0.04), 0.0, 0)
	var apex_a: Vector3 = t0 * Vector3(0, wh + rh, -d * 0.5)
	var apex_b: Vector3 = t0 * Vector3(0, wh + rh, d * 0.5)
	for i in 4:
		var j2 := (i + 1) % 4
		var nrm := Vector3.UP.cross((bc[j2] - bc[i]).normalized()).normalized()
		var ln: float = (bc[i] - bc[j2]).length()
		o.lattice(bc[i], bc[j2], tc[i], tc[j2], 1, 1, base_col, 0.06, 0.0, nrm)
		if i == 0 or i == 2:
			var ap: Vector3 = apex_a if i == 0 else apex_b
			var cen: Vector3 = (tc[i] + tc[j2] + ap) / 3.0
			o.tri(tc[i], tc[j2], cen, o.shade(base_col, 0.2))
			o.tri(tc[j2], ap, cen, o.shade(base_col, 0.2))
			o.tri(ap, tc[i], cen, o.shade(base_col, 0.2))
	var ov := 0.6
	var holes := r.randf_range(0.0, 0.14)
	for sgn in [1.0, -1.0]:
		var e0: Vector3 = t0 * Vector3(sgn * (w * 0.5 + ov), wh - 0.1, -(d * 0.5 + ov))
		var e1: Vector3 = t0 * Vector3(sgn * (w * 0.5 + ov), wh - 0.1, d * 0.5 + ov)
		var r0: Vector3 = t0 * Vector3(0, wh + rh + 0.06, -(d * 0.5 + ov))
		var r1: Vector3 = t0 * Vector3(0, wh + rh + 0.06, d * 0.5 + ov)
		var nrm2: Vector3 = (t0.basis * Vector3(sgn * rh, w * 0.5 + ov, 0)).normalized()
		o.lattice(e0, e1, r0, r1, 1, 1, roof_col, 0.05, 0.0, nrm2, 0.0, 0.0)
		o.quad(e0 - nrm2 * 0.18, e1 - nrm2 * 0.18, r1 - nrm2 * 0.18, r0 - nrm2 * 0.18, Color(0.04, 0.035, 0.04))
		# file di tegole scure e chiazze (muschio, tegole nuove, buchi): il tetto non e' piu' una superficie uniforme
		var ridge_dir: Vector3 = (e1 - e0).normalized()
		var slope_dir: Vector3 = (r0 - e0).normalized()
		var lift: Vector3 = nrm2 * 0.05
		for rowv in [0.34, 0.67]:
			var q0: Vector3 = e0.lerp(r0, rowv) + lift
			var q1: Vector3 = e1.lerp(r1, rowv) + lift
			o.quad(q0, q1, q1 + slope_dir * 0.08, q0 + slope_dir * 0.08, roof_col * 0.55)
		for pq in dr.randi_range(1, 2):
			var pu := dr.randf_range(0.15, 0.85)
			var pv := dr.randf_range(0.2, 0.8)
			var pc: Vector3 = e0.lerp(e1, pu).lerp(r0.lerp(r1, pu), pv) + lift * 1.5
			var ph := dr.randf_range(0.2, 0.4)
			var pcol: Color = roof_col * (0.62 if dr.randf() < 0.5 else 1.35)       # tegole piu' scure o piu' chiare, poco contrasto
			var pax: Vector3 = ridge_dir * ph * 1.4
			var pay: Vector3 = slope_dir * ph * 0.6
			o.quad(pc - pax - pay, pc + pax - pay, pc + pax + pay, pc - pax + pay, o.shade(pcol, 0.08))
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(0, wh + rh + 0.06, 0)), Vector3(0.34, 0.26, d + 2.0 * ov), roof_col * 0.7, 0.12, 8)
	var cxl := r.randf_range(-w * 0.22, w * 0.22)
	var czl := r.randf_range(-d * 0.3, d * 0.3)
	var roof_y := wh + rh * (1.0 - absf(cxl) / (w * 0.5 + ov))
	o.cyl(t0 * Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(cxl, wh * 0.4, czl)), 0.5, 0.42, roof_y + 1.0 - wh * 0.4, 5, Color(0.22, 0.2, 0.2), 0.16)
	# camino: cappello, brace accesa e fumo (particelle animate, vedi _make_smoke)
	var chy := roof_y + 1.0
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(cxl, chy + 0.06, czl)), Vector3(0.95, 0.14, 0.95), Color(0.12, 0.11, 0.11), 0.1, 8)
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(cxl, chy + 0.14, czl)), Vector3(0.5, 0.05, 0.5), Color(0.02, 0.02, 0.02), 0.0, 8)
	if dr.randf() < 0.7:
		var cpw: Vector3 = t0 * Vector3(cxl, chy + 0.2, czl)
		lamps.append(Vector4(cpw.x, cpw.y + 0.3, cpw.z, 0.5))
		o.smokes.append(Vector3(cpw.x, cpw.y + 0.25, cpw.z))
	var dz := r.randf_range(-d * 0.5 + 1.3, d * 0.5 - 1.3)
	var ab := t0.basis
	var dwp: Vector3 = t0 * Vector3(w * 0.5 + 0.8, 0, dz)
	house_doors[Vector2i(roundi(dwp.x * 2.0), roundi(dwp.z * 2.0))] = Vector3(dwp.x, dwp.z, yaw)
	o.box(Transform3D(ab, t0 * Vector3(w * 0.5 + 0.1, 1.0, dz)), Vector3(0.42, 2.1, 1.2), Color(0.05, 0.035, 0.035), 0.1, 8)
	o.box(Transform3D(ab, t0 * Vector3(w * 0.5 + 0.55, 0.12, dz)), Vector3(0.9, 0.24, 1.6), Color(0.24, 0.23, 0.23), 0.12, 8)
	if r.randf() < 0.85:
		var lp := t0 * Vector3(w * 0.5 + 0.5, 2.3, dz + 0.95)
		o.box(Transform3D(ab, lp), Vector3(0.24, 0.36, 0.24), Color(0.95, 0.8, 0.55, 0.2), 0.0, 8)
		lamps.append(Vector4(lp.x, lp.y, lp.z, 1.0))
	var lit := r.randf() < 0.6
	var front_windows: Array = []
	for k in 2:
		var wz := (-d * 0.25 if k == 0 else d * 0.25)
		if absf(wz - dz) < 1.5:
			continue
		var on := lit and r.randf() < 0.8
		front_windows.append([wz, on])
		# la vecchia finestra si disegna a vuoto: consuma le stesse estrazioni, quindi tutto il resto del mondo resta identico
		var discard := W3DBuilder.new()
		discard.rn = o.rn
		_window(discard, t0, Vector3(w * 0.5, wh * 0.58, wz), 0, on, r)
		if on:
			var wp := t0 * Vector3(w * 0.5 + 0.9, 1.4, wz)
			lamps.append(Vector4(wp.x, wp.y, wp.z, 0.55))
	W3DFacade.decorate(o, bc, tc, [apex_a, apex_b], d, dz, front_windows, style, base_col, roof_col, dr.seed + 977)
	# abbaino con finestra, vialetto di lastre dalla porta e insegna appesa
	if dr.randf() < 0.65:
		var ds := -1.0 if dr.randf() < 0.5 else 1.0
		var dvv := 0.4
		var dzc := dr.randf_range(-d * 0.25, d * 0.25)
		var dxl: float = ds * (w * 0.5 + ov) * (1.0 - dvv)
		var dyl: float = wh - 0.1 + (rh + 0.16) * dvv
		o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(dxl, dyl + 0.5, dzc)), Vector3(0.95, 1.0, 1.0), base_col * 1.1, 0.1, 8)
		for sg2 in [-1.0, 1.0]:
			o.box(t0 * Transform3D(Basis(Vector3.RIGHT, sg2 * 0.6), Vector3(dxl, dyl + 1.2, dzc + sg2 * 0.3)), Vector3(1.2, 0.1, 0.8), roof_col * 1.3, 0.1, 8)
		var dlit := dr.randf() < 0.6
		o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(dxl + ds * 0.5, dyl + 0.5, dzc)), Vector3(0.1, 0.5, 0.5), Color(0.95, 0.82, 0.58, 0.2) if dlit else Color(0.03, 0.03, 0.05), 0.0, 8)
		if dlit:
			var dwq: Vector3 = t0 * Vector3(dxl + ds * 0.9, dyl + 0.5, dzc)
			lamps.append(Vector4(dwq.x, dwq.y, dwq.z, 0.45))
	for si in 5:
		var spl := Vector3(w * 0.5 + 1.3 + si * 0.8, 0.07, dz + sin(float(si) * 1.9) * 0.18)
		var swp: Vector3 = t0 * spl
		var srd := _road_near(Vector2(swp.x, swp.z))
		if float(srd["d"]) < float(srd["w"]) * 0.5 + 1.2:     # il vialetto finisce prima della strada, mai sopra
			break
		o.box(Transform3D(ab, swp), Vector3(0.55, 0.12, 0.5 + dr.randf() * 0.15), Color(0.27, 0.26, 0.26), 0.14, 8)
	if dr.randf() < 0.35:
		var sx0 := w * 0.5
		var sz0 := clampf(dz - 1.15 if dz > 0.0 else dz + 1.15, -d * 0.5 + 0.3, d * 0.5 - 0.3)
		o.box(Transform3D(ab, t0 * Vector3(sx0 + 0.55, 2.5, sz0)), Vector3(1.1, 0.07, 0.07), WOOD, 0.1, 8)
		o.box(Transform3D(ab, t0 * Vector3(sx0 + 1.0, 2.1, sz0)), Vector3(0.07, 0.55, 0.7), Color(0.30, 0.2, 0.12), 0.1, 8)
		o.box(Transform3D(ab, t0 * Vector3(sx0 + 1.0, 2.1, sz0)), Vector3(0.09, 0.3, 0.4), [Color(0.6, 0.15, 0.1), Color(0.65, 0.5, 0.15), Color(0.15, 0.35, 0.5)][dr.randi() % 3], 0.05, 8)
	if not plain_house and r.randf() < 0.5 and _fence_ok(p):
		var m := r.randf_range(1.4, 2.4)
		var hx := w * 0.5 + m
		var hz := d * 0.5 + m
		var cs := [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]
		var wc: Array = []
		for c2 in cs:
			var wv: Vector3 = t0 * Vector3(c2.x, 0, c2.y)
			wc.append(Vector2(wv.x, wv.z))
		for si in 4:
			_fence_run(o, wc[si], wc[(si + 1) % 4], r, cols, si == 1)
	for i in (0 if plain_house else r.randi_range(0, 3)):
		var q := Vector2(p.x, p.y) + Vector2(cos(yaw) * (w * 0.5 + 1.4), -sin(yaw) * (w * 0.5 + 1.4)) + Vector2(sin(yaw), cos(yaw)) * r.randf_range(-d * 0.45, d * 0.45) + Vector2(r.randf_range(-0.8, 0.8), r.randf_range(-0.8, 0.8))
		var kk := r.randf()
		if kk < 0.4:
			_obj("barrel", o, q, 0.0, r, cols, [])
		elif kk < 0.7:
			_obj("crate", o, q, 0.0, r, cols, [])
		else:
			_woodpile(o, q, yaw, r, cols)
	cols.append(["b", p, Vector2(w * 0.5 + 0.4, d * 0.5 + 0.4), yaw])


func _window(o: W3DBuilder, t0: Transform3D, lp: Vector3, face: int, lit: bool, r: RandomNumberGenerator) -> void:
	var bas := t0.basis
	if face == 1:
		bas = bas * Basis(Vector3.UP, PI * 0.5)
	elif face == 2:
		bas = bas * Basis(Vector3.UP, PI)
	var wp: Vector3 = t0 * lp
	o.box(Transform3D(bas, wp), Vector3(0.2, 0.95, 0.85), Color(0.10, 0.075, 0.06), 0.1, 8)
	var pane := Color(0.95, 0.82, 0.58, 0.2) if lit else Color(0.03, 0.03, 0.05)
	o.box(Transform3D(bas, wp + bas * Vector3(0.07, 0, 0)), Vector3(0.12, 0.65, 0.55), pane, 0.0, 8)
	if r.randf() < 0.55:
		var tilt := Basis(Vector3.FORWARD, r.randf_range(-0.35, 0.35))
		o.box(Transform3D(bas * tilt, wp + bas * Vector3(0.12, 0, 0.5)), Vector3(0.07, 0.9, 0.3), Color(0.18, 0.12, 0.08), 0.1, 8)


# ------------------------------------------------------------------ alberi morti e oggetti del villaggio
func _dead_tree(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var h := r.randf_range(3.2, 5.6)
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, 0, p.y))
	var bark := Color(0.15, 0.11, 0.09)
	o.cyl(t, 0.5, 0.18, h, 5, bark, 0.14)
	for i in 3:
		var rt := t * Transform3D(Basis(Vector3.UP, TAU * i / 3.0 + r.randf()) * Basis(Vector3.RIGHT, 1.15), Vector3(0, 0.1, 0))
		o.cyl(rt, 0.2, 0.06, 1.0, 4, bark, 0.12, false)
	for k in 3:
		var at := t * Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.55, 1.0)), Vector3(0, h * r.randf_range(0.5, 0.95), 0))
		_branch(o, at, r.randf_range(1.6, 2.7), 0.15, 2, r, bark)
	cols.append(["c", p, 0.5])


func _branch(o: W3DBuilder, t: Transform3D, len: float, rad: float, depth: int, r: RandomNumberGenerator, col: Color) -> void:
	o.cyl(t, rad, rad * 0.5, len, 4, col, 0.12, false)
	if depth <= 0:
		return
	for k in r.randi_range(2, 3):
		var ct := t * Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(0.5, 1.1)), Vector3(0, len * r.randf_range(0.55, 1.0), 0))
		_branch(o, ct, len * 0.66, rad * 0.58, depth - 1, r, col)


func _fence_run(o: W3DBuilder, a: Vector2, b: Vector2, r: RandomNumberGenerator, cols: Array, gate: bool) -> void:
	var ln := a.distance_to(b)
	if ln < 0.6:
		return
	for si in 5:
		var rn2 := _road_near(a + (b - a) * float(si) / 4.0)
		if float(rn2["d"]) - float(rn2["w"]) * 0.5 < 0.9:
			return   # una staccionata non attraversa mai la strada
		if edge_fn.is_valid() and bool(edge_fn.call(a + (b - a) * float(si) / 4.0)):
			return   # niente recinti nel vuoto fuori dall'isola
	var center := (a + b) * 0.5
	var hide_key := Vector2i(roundi(center.x * 100.0), roundi(center.y * 100.0))
	if ed_hide_keys.has(hide_key):
		var tmp := W3DBuilder.new()
		tmp.rn = o.rn
		tmp.sat = o.sat
		tmp.con = o.con
		tmp.gain = o.gain
		_fence_build(tmp, a, b, r, [], gate, ln)
		return
	o.breakables.append({"kind": "fence", "a": a, "b": b, "pos": center})
	_fence_build(o, a, b, r, cols, gate, ln)


func _fence_build(o: W3DBuilder, a: Vector2, b: Vector2, r: RandomNumberGenerator, cols: Array, gate: bool, ln: float) -> void:
	var dir := (b - a) / ln
	var yaw := atan2(-dir.y, dir.x)
	var n := maxi(1, int(ln / 1.6))
	var gate_i := n / 2
	for i in n + 1:
		var q := a + dir * ln * float(i) / n
		var hgt := r.randf_range(1.2, 1.8)
		var tl := Basis(Vector3.FORWARD, r.randf_range(-0.1, 0.1)) * Basis(Vector3.RIGHT, r.randf_range(-0.1, 0.1))
		o.box(Transform3D(Basis(Vector3.UP, yaw) * tl, Vector3(q.x, hgt * 0.5, q.y)), Vector3(0.22, hgt, 0.22), Color(0.29, 0.2, 0.15), 0.14, 8)
	var seg := ln / n
	for i in n:
		if gate and i == gate_i:
			continue
		var mid := a + dir * ln * (float(i) + 0.5) / n
		for yy in [0.5, 0.95]:
			if r.randf() < 0.14:
				continue
			var tl2 := Basis(Vector3(0, 0, 1), r.randf_range(-0.07, 0.07))
			o.box(Transform3D(Basis(Vector3.UP, yaw) * tl2, Vector3(mid.x, yy, mid.y)), Vector3(seg, 0.13, 0.1), Color(0.33, 0.23, 0.17), 0.14, 8)
	if gate and n >= 2:
		var l1 := ln * float(gate_i) / n
		var l2 := ln * float(n - gate_i - 1) / n
		cols.append(["b", a + dir * l1 * 0.5, Vector2(maxf(l1 * 0.5, 0.2), 0.15), yaw])
		cols.append(["b", b - dir * l2 * 0.5, Vector2(maxf(l2 * 0.5, 0.2), 0.15), yaw])
	else:
		cols.append(["b", (a + b) * 0.5, Vector2(ln * 0.5, 0.15), yaw])


func _barrel(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, 0, p.y))
	o.cyl(t, 0.42, 0.42, 0.95, 6, Color(0.27, 0.18, 0.11), 0.14)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.44, 0.44, 0.08, 6, Color(0.13, 0.12, 0.13), 0.05, false)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0)), 0.44, 0.44, 0.08, 6, Color(0.13, 0.12, 0.13), 0.05, false)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.93, 0)), 0.37, 0.37, 0.05, 6, Color(0.38, 0.26, 0.16), 0.1)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.99, 0)), Vector3(0.66, 0.03, 0.07), Color(0.2, 0.13, 0.08), 0.08, 8)
	o.box(t * Transform3D(Basis(Vector3.UP, 1.57), Vector3(0, 0.99, 0)), Vector3(0.66, 0.03, 0.07), Color(0.2, 0.13, 0.08), 0.08, 8)
	cols.append(["c", p, 0.45])


func _crate(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var s := r.randf_range(0.7, 1.1)
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, s * 0.5, p.y))
	o.box(t, Vector3(s, s, s), Color(0.28, 0.2, 0.13), 0.14, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, s * 0.5 + 0.02, 0)), Vector3(s * 1.04, 0.06, s * 0.2), Color(0.17, 0.12, 0.085), 0.1, 8)
	for dg in [0.785, -0.785]:
		o.box(t * Transform3D(Basis(Vector3.UP, dg), Vector3(0, s * 0.5 + 0.06, 0)), Vector3(s * 1.1, 0.05, s * 0.13), Color(0.16, 0.11, 0.08), 0.08, 8)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			o.box(t * Transform3D(Basis.IDENTITY, Vector3(cx * s * 0.5, s * 0.5, cz * s * 0.5)), Vector3(0.11, 0.11, 0.11), Color(0.13, 0.13, 0.14), 0.05, 8)
	cols.append(["c", p, s * 0.7])


func _hay(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, 0, p.y))
	o.cyl(t, 1.0, 0.25, 1.35, 6, Color(0.34, 0.28, 0.14), 0.16)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), 1.03, 1.03, 0.07, 6, Color(0.2, 0.15, 0.1), 0.1, false)
	cols.append(["c", p, 1.0])


func _woodpile(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	for row in 3:
		for i in 4 - row:
			var q := Vector3(p.x + (i - (3 - row) * 0.5 + 0.5) * 0.36, 0.18 + row * 0.3, p.y)
			var t := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5), q)
			o.cyl(t, 0.17, 0.15, 1.5, 5, Color(0.2, 0.14, 0.1), 0.16)
	cols.append(["c", p, 0.9])


func _cart(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), Vector3(2.2, 0.5, 1.3), Color(0.22, 0.15, 0.1), 0.14, 8)
	for sz in [-0.75, 0.75]:
		o.cyl(t * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(-0.2, 0.5, sz - 0.07)), 0.5, 0.5, 0.14, 6, Color(0.14, 0.1, 0.07), 0.1)
	o.box(t * Transform3D(Basis(Vector3.FORWARD, 0.2), Vector3(1.9, 0.65, 0)), Vector3(1.6, 0.1, 0.12), Color(0.2, 0.14, 0.09), 0.1, 8)
	var ch := hash(Vector2i(roundi(p.x * 8.0), roundi(p.y * 8.0)))
	for cs in 3:
		var csf := float(cs)
		o.rock(t * Vector3(-0.6 + csf * 0.55, 1.15, sin(csf * 2.3) * 0.25), Vector3(0.55, 0.45, 0.5), Color(0.36, 0.31, 0.2) * (0.85 + 0.1 * csf), 0.14, 0.3, csf * 1.3)
	if ch % 2 == 0:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0.55, 1.36, 0)), Vector3(1.0, 0.08, 1.1), Color(0.32, 0.14, 0.11), 0.1, 8)
	cols.append(["b", p, Vector2(1.3, 0.8), yaw])


func _bench(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(1.8, 0.1, 0.5), WOOD * 1.2, 0.12, 8)
	for sx in [-0.7, 0.7]:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(sx, 0.25, 0)), Vector3(0.1, 0.5, 0.4), WOOD, 0.12, 8)
	cols.append(["b", p, Vector2(0.95, 0.3), yaw])


func _sign(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0)), Vector3(0.14, 2.2, 0.14), WOOD, 0.12, 8)
	o.box(t * Transform3D(Basis(Vector3.FORWARD, r.randf_range(-0.15, 0.15)), Vector3(0.45, 1.9, 0)), Vector3(1.1, 0.4, 0.08), WOOD * 1.3, 0.12, 8)
	cols.append(["c", p, 0.3])


func _scarecrow(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.RIGHT, r.randf_range(-0.1, 0.1)), Vector3(p.x, 0, p.y))
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), Vector3(0.12, 2.0, 0.12), WOOD, 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.55, 0)), Vector3(1.6, 0.1, 0.1), WOOD, 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)), Vector3(0.5, 0.7, 0.3), Color(0.2, 0.13, 0.1), 0.2, 8)
	o.rock(Vector3(p.x, 2.2, p.y), Vector3(0.45, 0.45, 0.45), Color(0.45, 0.4, 0.3), 0.12, 0.25)
	cols.append(["c", p, 0.4])


func _well(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		var q := Vector3(p.x + cos(a) * 0.95, 0.4, p.y + sin(a) * 0.95)
		o.box(Transform3D(Basis(Vector3.UP, -a), q), Vector3(0.5, 0.8, 0.7), Color(0.27, 0.265, 0.28), 0.16, 8)
	o.cyl(Transform3D(Basis.IDENTITY, Vector3(p.x, 0.5, p.y)), 0.8, 0.8, 0.02, 8, Color(0.02, 0.03, 0.05), 0.0)
	for sx in [-1.0, 1.0]:
		o.box(Transform3D(Basis.IDENTITY, Vector3(p.x + sx * 1.0, 1.3, p.y)), Vector3(0.14, 2.6, 0.14), WOOD, 0.1, 8)
	o.box(Transform3D(Basis.IDENTITY, Vector3(p.x, 2.55, p.y)), Vector3(2.3, 0.14, 0.14), WOOD, 0.1, 8)
	for sg in [-1.0, 1.0]:
		o.box(Transform3D(Basis(Vector3.RIGHT, sg * 0.55), Vector3(p.x, 2.95, p.y + sg * 0.5)), Vector3(2.8, 0.1, 1.2), Color(0.2, 0.13, 0.1), 0.12, 8)
	o.box(Transform3D(Basis.IDENTITY, Vector3(p.x, 3.3, p.y)), Vector3(2.8, 0.1, 0.1), Color(0.14, 0.1, 0.08), 0.08, 8)
	o.cyl(Transform3D(Basis.IDENTITY, Vector3(p.x + 1.5, 0.0, p.y + 1.0)), 0.22, 0.17, 0.32, 6, Color(0.3, 0.21, 0.13), 0.12)
	cols.append(["c", p, 1.25])


func _gallows(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, 0, p.y))
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), Vector3(3.2, 0.5, 2.4), Color(0.2, 0.14, 0.1), 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(-1.2, 2.2, 0)), Vector3(0.28, 4.0, 0.28), WOOD, 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(-0.1, 4.05, 0)), Vector3(2.6, 0.26, 0.26), WOOD, 0.1, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0.7, 3.2, 0)), Vector3(0.05, 1.6, 0.05), Color(0.4, 0.35, 0.26), 0.1, 8)
	o.box(t * Transform3D(Basis(Vector3.FORWARD, 0.15), Vector3(0.7, 2.2, 0)), Vector3(0.4, 0.9, 0.25), Color(0.24, 0.2, 0.18), 0.14, 8)
	cols.append(["b", p, Vector2(1.7, 1.3), 0.0])


func _pyre(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for i in 7:
		var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3.FORWARD, r.randf_range(0.4, 1.2)), Vector3(p.x, 0.2, p.y))
		o.cyl(t, 0.12, 0.1, 1.7, 4, Color(0.13, 0.09, 0.07), 0.15)
	o.cyl(Transform3D(Basis.IDENTITY, Vector3(p.x, 0.25, p.y)), 0.55, 0.05, 1.4, 5, Color(0.95, 0.62, 0.3, 0.1), 0.2)
	o.cyl(Transform3D(Basis.IDENTITY, Vector3(p.x, 0.3, p.y)), 0.3, 0.02, 1.9, 4, Color(0.95, 0.82, 0.55, 0.05), 0.2)
	lamps.append(Vector4(p.x, 1.0, p.y, 1.9))
	cols.append(["c", p, 0.9])


func _ruin(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var yaw := r.randf() * TAU
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0, p.y))
	for i in r.randi_range(2, 4):
		var len := r.randf_range(2.0, 4.2)
		var hh := r.randf_range(0.9, 2.8)
		var off := Vector3(r.randf_range(-3, 3), 0, r.randf_range(-3, 3))
		var rot := Basis(Vector3.UP, r.randf_range(0, PI))
		var y := 0.0
		while y < hh:
			var lw := len * (1.0 - y / (hh + 1.0)) * r.randf_range(0.7, 1.0)
			o.box(t * Transform3D(rot, off + Vector3(r.randf_range(-0.2, 0.2), y + 0.2, 0)), Vector3(lw, 0.4, 0.55), Color(0.28, 0.27, 0.27), 0.16, 8)
			y += 0.4
		cols.append(["b", p + Vector2(off.x, off.z).rotated(-yaw), Vector2(len * 0.5, 0.35), yaw + rot.get_euler().y])


func _lamp_post(o: W3DBuilder, p: Vector2, lamps: Array, cols: Array) -> void:
	var t := Transform3D(Basis.IDENTITY, Vector3(p.x, 0, p.y))
	o.cyl(t, 0.11, 0.08, 2.7, 5, Color(0.12, 0.1, 0.08), 0.1)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 2.85, 0)), Vector3(0.38, 0.4, 0.38), Color(0.95, 0.8, 0.55, 0.15), 0.0, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 3.1, 0)), Vector3(0.5, 0.1, 0.5), Color(0.1, 0.08, 0.08), 0.0, 8)
	o.cyl(t, 0.24, 0.2, 0.4, 6, Color(0.24, 0.23, 0.24), 0.12)
	o.cyl(t * Transform3D(Basis(Vector3.UP, 0.785), Vector3(0, 3.15, 0)), 0.42, 0.03, 0.42, 4, Color(0.1, 0.08, 0.08), 0.0)
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			o.box(t * Transform3D(Basis.IDENTITY, Vector3(lx * 0.2, 2.85, lz * 0.2)), Vector3(0.05, 0.44, 0.05), Color(0.08, 0.07, 0.07), 0.0, 8)
	lamps.append(Vector4(p.x, 2.7, p.y, 1.5))
	cols.append(["c", p, 0.3])


# ------------------------------------------------------------------ personaggi: schegge taglienti, vista dall'alto
# Ogni personaggio e' un gruppo di schegge triangolari (come intagliate nel vetro o nella carta): silhouette espressiva,
# occhi che brillano, e una parte "fluente" (mantello, orecchie, coda, stracci) che ondeggia mentre cammina.
# Davanti = -Z (su, sullo schermo). Unita' = 16 px.
func _sh(b: W3DBuilder, a: Array, c: Array, w1: float, w2: float, col: Color, t := 0.4) -> void:
	b.shard(Vector3(a[0], a[1], a[2]), Vector3(c[0], c[1], c[2]), w1, w2, col, t)


func _shm(b: W3DBuilder, a: Array, c: Array, w1: float, w2: float, col: Color, t := 0.4) -> void:
	_sh(b, a, c, w1, w2, col, t)
	_sh(b, [-a[0], a[1], a[2]], [-c[0], c[1], c[2]], w1, w2, col, t)


func _glow(b: W3DBuilder, x: float, y: float, z: float, s: float, col: Color) -> void:
	b.shard(Vector3(x, y, z + 0.06), Vector3(x, y + 0.02, z - 0.1), s, s * 0.5, col, 0.5, 0.0, 0.0)


func _sword(b: W3DBuilder, x: float, y: float, blade: Color) -> void:
	_sh(b, [x, y, -0.35], [x + 0.06, y, -2.3], 0.1, 0.035, blade, 0.12)
	_sh(b, [x - 0.4, y, -0.35], [x + 0.4, y, -0.35], 0.07, 0.04, Color(0.55, 0.45, 0.2), 0.5)
	_sh(b, [x, y, -0.3], [x, y, 0.45], 0.06, 0.06, Color(0.25, 0.17, 0.1), 0.5)


func _sword_side(b: W3DBuilder, x: float, y: float, blade: Color) -> void:
	_sh(b, [x - 0.1, y, 0.0], [x + 1.9, y, 0.5], 0.1, 0.035, blade, 0.12)
	_sh(b, [x + 0.18, y, -0.38], [x + 0.3, y, 0.42], 0.07, 0.04, Color(0.55, 0.45, 0.2), 0.5)
	_sh(b, [x - 0.1, y, 0.0], [x - 0.65, y, -0.05], 0.06, 0.06, Color(0.25, 0.17, 0.1), 0.5)


func _bow(b: W3DBuilder, x: float, col: Color) -> void:
	for i in 4:
		var z0 := -1.2 + i * 0.6
		var z1 := z0 + 0.6
		var o0 := (1.0 - pow(z0 / 1.2, 2.0)) * 0.45
		var o1 := (1.0 - pow(z1 / 1.2, 2.0)) * 0.45
		_sh(b, [x - o0, 0.85, z0], [x - o1, 0.85, z1], 0.05, 0.05, col, 0.5)
	_sh(b, [x + 0.02, 0.85, -1.2], [x + 0.02, 0.85, 1.2], 0.012, 0.012, Color(0.8, 0.76, 0.65, 0.5), 0.5)


func _m_hero(b: W3DBuilder, f: W3DBuilder) -> void:
	var steel := Color(0.46, 0.47, 0.52)
	var hood := Color(0.36, 0.36, 0.40)
	_sh(b, [0, 0.1, 0.05], [0, 1.2, 0.0], 0.46, 0.36, Color(0.17, 0.16, 0.19), 0.55)
	_sh(b, [0, 0.95, 0.0], [0.12, 2.35, 0.18], 0.5, 0.5, hood, 0.3)
	_sh(b, [0, 1.25, -0.1], [0, 1.4, -0.7], 0.24, 0.22, Color(0.04, 0.04, 0.05), 0.5)
	_glow(b, -0.1, 1.38, -0.55, 0.06, Color(0.95, 0.8, 0.55, 0.2))
	_glow(b, 0.1, 1.38, -0.55, 0.06, Color(0.95, 0.8, 0.55, 0.2))
	_shm(b, [0.15, 1.12, 0.0], [0.82, 0.98, -0.02], 0.22, 0.17, steel, 0.5)
	_sh(b, [-0.7, 1.0, 0.0], [-0.55, 0.78, -0.55], 0.12, 0.1, steel * 0.8, 0.4)
	_sh(b, [0.7, 1.0, 0.0], [0.82, 0.92, -0.5], 0.13, 0.1, steel * 0.8, 0.4)
	_sword_side(b, 0.78, 0.92, Color(0.72, 0.74, 0.82, 0.8))
	# mantello e sciarpa: parte fluente
	_sh(f, [0, 1.15, 0.12], [0, 0.35, 2.0], 0.85, 0.05, Color(0.27, 0.08, 0.09), 0.3)
	_sh(f, [-0.3, 1.1, 0.12], [-1.0, 0.3, 1.55], 0.32, 0.04, Color(0.2, 0.07, 0.08), 0.35)
	_sh(f, [0.3, 1.1, 0.12], [1.0, 0.3, 1.55], 0.32, 0.04, Color(0.2, 0.07, 0.08), 0.35)
	_sh(f, [0.0, 1.2, 0.0], [0.3, 0.8, 1.1], 0.14, 0.03, Color(0.5, 0.11, 0.11), 0.4)


func _m_goblin(b: W3DBuilder, f: W3DBuilder, archer: bool) -> void:
	var skin := Color(0.40, 0.46, 0.31)
	var leather := Color(0.2, 0.16, 0.12)
	_sh(b, [0, 0.15, 0.15], [0, 1.0, -0.1], 0.42, 0.32, leather, 0.5)
	_sh(b, [0, 0.95, 0.05], [0, 1.6, -0.15], 0.66, 0.54, skin, 0.45)
	_sh(b, [0, 1.2, -0.3], [0, 1.12, -0.85], 0.1, 0.1, skin * 0.85, 0.4)
	_glow(b, -0.24, 1.4, -0.4, 0.1, Color(0.95, 0.82, 0.2, 0.2))
	_glow(b, 0.22, 1.4, -0.4, 0.08, Color(0.95, 0.82, 0.2, 0.2))
	for i in 3:
		_sh(b, [-0.16 + i * 0.16, 1.02, -0.45], [-0.16 + i * 0.16, 0.98, -0.62], 0.04, 0.03, Color(0.9, 0.87, 0.75), 0.5)
	_shm(b, [0.3, 0.85, 0.0], [0.58, 0.6, -0.5], 0.1, 0.08, skin, 0.4)
	_shm(b, [0.18, 0.0, 0.0], [0.2, 0.12, -0.6], 0.13, 0.08, skin * 0.8, 0.4)
	if archer:
		_bow(b, -0.7, Color(0.34, 0.26, 0.17))
		_sh(b, [0.15, 0.9, 0.3], [0.35, 1.55, 0.65], 0.16, 0.13, Color(0.28, 0.2, 0.13), 0.4)
		_sh(b, [0.3, 1.5, 0.6], [0.4, 1.75, 0.7], 0.05, 0.03, Color(0.72, 0.7, 0.62), 0.5)
	else:
		_sh(b, [0.58, 0.66, -0.45], [0.64, 0.72, -1.25], 0.07, 0.03, Color(0.66, 0.68, 0.72, 0.85), 0.2)
	# orecchie enormi e perizoma: parti fluenti
	_sh(f, [0.4, 1.38, 0.0], [1.9, 1.15, 0.35], 0.3, 0.05, skin, 0.35)
	_sh(f, [-0.4, 1.38, 0.0], [-1.9, 1.15, 0.35], 0.3, 0.05, skin, 0.35)
	_sh(f, [0, 0.5, 0.15], [0, 0.05, 0.65], 0.24, 0.03, leather, 0.4)


func _m_skel(b: W3DBuilder, f: W3DBuilder, archer: bool) -> void:
	var bone := Color(0.76, 0.74, 0.68)
	_sh(b, [0, 0.1, 0.1], [0, 1.25, 0.1], 0.07, 0.07, bone * 0.8, 0.5)
	for i in 4:
		_sh(b, [-0.5 + i * 0.03, 0.55 + i * 0.16, 0.05], [0.5 - i * 0.03, 0.55 + i * 0.16, 0.05], 0.24, 0.035, bone, 0.5)
	_sh(b, [0, 1.18, 0.0], [0, 1.85, -0.2], 0.52, 0.46, bone, 0.45)
	_sh(b, [0, 1.05, -0.15], [0, 1.0, -0.62], 0.26, 0.08, bone * 0.88, 0.5)
	_shm(b, [0.18, 1.58, -0.2], [0.18, 1.62, -0.55], 0.13, 0.09, Color(0.04, 0.03, 0.04), 0.5)
	_glow(b, -0.18, 1.62, -0.45, 0.05, Color(0.7, 0.88, 0.98, 0.2))
	_glow(b, 0.18, 1.62, -0.45, 0.05, Color(0.7, 0.88, 0.98, 0.2))
	_shm(b, [0.5, 1.05, 0.0], [0.62, 0.72, -0.55], 0.06, 0.06, bone, 0.4)
	_shm(b, [0.16, 0.0, 0.0], [0.18, 0.1, -0.55], 0.1, 0.06, bone * 0.85, 0.4)
	if archer:
		_bow(b, -0.8, Color(0.4, 0.34, 0.26))
		_sh(b, [0.2, 0.9, 0.3], [0.4, 1.6, 0.7], 0.17, 0.14, Color(0.42, 0.13, 0.13), 0.4)
	else:
		_sh(b, [-0.9, 0.8, -0.2], [-0.9, 0.98, -0.2], 0.6, 0.6, Color(0.54, 0.47, 0.32), 0.5)
		_sh(b, [-0.9, 0.95, -0.2], [-0.9, 1.15, -0.2], 0.12, 0.12, Color(0.4, 0.34, 0.22), 0.5)
		_sword(b, 0.82, 0.92, Color(0.55, 0.57, 0.63, 0.9))
	_sh(f, [0, 1.3, 0.12], [0, 0.2, 1.5], 0.55, 0.04, Color(0.17, 0.16, 0.2), 0.3)
	_sh(f, [-0.3, 1.2, 0.12], [-0.95, 0.15, 1.1], 0.25, 0.03, Color(0.15, 0.14, 0.18), 0.35)
	_sh(f, [0.3, 1.2, 0.12], [0.95, 0.15, 1.1], 0.25, 0.03, Color(0.15, 0.14, 0.18), 0.35)


func _m_ghoul(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := Color(0.5, 0.5, 0.49)
	_sh(b, [0, 0.2, 0.55], [0, 1.45, -0.05], 0.78, 0.66, skin * 0.85, 0.45)
	_sh(b, [0, 0.85, -0.2], [0, 1.05, -1.0], 0.46, 0.4, skin * 1.1, 0.45)
	_sh(b, [0, 0.88, -0.55], [0, 0.75, -1.0], 0.24, 0.08, Color(0.05, 0.03, 0.03), 0.5)
	for i in 5:
		_sh(b, [-0.2 + i * 0.1, 0.92, -0.8], [-0.2 + i * 0.1, 0.8, -1.02], 0.035, 0.03, Color(0.9, 0.88, 0.8), 0.5)
	_glow(b, -0.2, 1.08, -0.78, 0.08, Color(0.95, 0.85, 0.35, 0.2))
	_glow(b, 0.2, 1.08, -0.78, 0.08, Color(0.95, 0.85, 0.35, 0.2))
	_shm(b, [0.5, 0.95, 0.0], [0.85, 0.4, -1.5], 0.13, 0.1, skin * 0.9, 0.4)
	for sx in [-1.0, 1.0]:
		for k in 3:
			_sh(b, [sx * (0.85 + k * 0.08), 0.4, -1.45], [sx * (0.95 + k * 0.12), 0.3, -1.9], 0.04, 0.03, Color(0.82, 0.8, 0.72), 0.4)
	_shm(b, [0.25, 0.0, 0.2], [0.28, 0.14, -0.5], 0.16, 0.1, skin * 0.7, 0.4)
	_sh(f, [0, 1.2, 0.5], [0, 0.2, 1.7], 0.6, 0.04, Color(0.26, 0.26, 0.27), 0.3)
	_sh(f, [-0.4, 1.1, 0.4], [-1.1, 0.2, 1.3], 0.26, 0.03, Color(0.22, 0.22, 0.23), 0.35)
	_sh(f, [0.4, 1.1, 0.4], [1.1, 0.2, 1.3], 0.26, 0.03, Color(0.22, 0.22, 0.23), 0.35)


func _m_kobold(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := Color(0.38, 0.28, 0.2)
	_sh(b, [0, 0.1, 0.1], [0, 0.85, -0.05], 0.34, 0.28, Color(0.3, 0.22, 0.17), 0.5)
	_sh(b, [0, 0.8, 0.0], [0, 1.4, -0.1], 0.55, 0.46, skin, 0.45)
	_sh(b, [0, 0.98, -0.25], [0, 0.9, -0.8], 0.22, 0.16, skin * 1.15, 0.4)
	_shm(b, [0.2, 1.3, 0.0], [0.5, 2.05, 0.35], 0.09, 0.09, Color(0.84, 0.8, 0.68), 0.25)
	_glow(b, -0.22, 1.2, -0.38, 0.09, Color(0.95, 0.82, 0.25, 0.2))
	_glow(b, 0.2, 1.2, -0.38, 0.07, Color(0.95, 0.82, 0.25, 0.2))
	_shm(b, [0.35, 0.7, 0.0], [0.5, 0.5, -0.45], 0.08, 0.07, skin, 0.4)
	_shm(b, [0.14, 0.0, 0.0], [0.15, 0.1, -0.45], 0.1, 0.06, skin * 0.8, 0.4)
	_sh(b, [-0.55, 0.75, 0.5], [-0.6, 0.85, -2.3], 0.05, 0.05, Color(0.36, 0.26, 0.16), 0.5)
	_sh(b, [-0.6, 0.85, -2.1], [-0.62, 0.85, -2.7], 0.11, 0.04, Color(0.7, 0.72, 0.78, 0.9), 0.2)
	_sh(f, [0, 0.4, 0.2], [0.4, 0.15, 1.6], 0.14, 0.1, skin * 0.9, 0.3)
	_sh(f, [0, 0.5, 0.2], [-0.3, 0.3, 1.0], 0.1, 0.08, skin * 0.8, 0.4)


func _m_orc(b: W3DBuilder, f: W3DBuilder) -> void:
	var skin := Color(0.33, 0.40, 0.28)
	_sh(b, [0, 0.1, 0.1], [0, 1.45, -0.05], 0.92, 0.62, Color(0.2, 0.17, 0.14), 0.5)
	_sh(b, [0, 0.9, -0.2], [0, 1.1, -0.55], 0.5, 0.3, Color(0.32, 0.32, 0.28), 0.5)
	_sh(b, [0, 1.3, -0.05], [0, 1.75, -0.65], 0.42, 0.42, skin, 0.4)
	_glow(b, -0.17, 1.58, -0.45, 0.07, Color(0.95, 0.85, 0.3, 0.2))
	_glow(b, 0.17, 1.58, -0.45, 0.07, Color(0.95, 0.85, 0.3, 0.2))
	_shm(b, [0.17, 1.35, -0.45], [0.2, 1.82, -0.5], 0.06, 0.05, Color(0.92, 0.9, 0.82), 0.3)
	_shm(b, [0.8, 1.2, 0.0], [1.5, 1.75, -0.15], 0.17, 0.13, skin * 0.75, 0.25)
	_shm(b, [0.85, 1.0, 0.0], [1.0, 0.7, -0.7], 0.2, 0.17, skin, 0.4)
	_sh(b, [-1.15, 0.85, -0.3], [-1.15, 1.05, -0.3], 0.65, 0.65, Color(0.5, 0.5, 0.52), 0.5)
	for i in 6:
		var a := TAU * i / 6.0
		_sh(b, [-1.15 + cos(a) * 0.5, 1.0, -0.3 + sin(a) * 0.5], [-1.15 + cos(a) * 0.85, 1.12, -0.3 + sin(a) * 0.85], 0.07, 0.06, Color(0.6, 0.6, 0.62), 0.4)
	_sh(b, [1.1, 0.95, 0.4], [1.12, 0.98, -1.5], 0.07, 0.07, Color(0.3, 0.22, 0.14), 0.5)
	_sh(b, [1.1, 0.98, -1.2], [1.14, 0.98, -1.95], 0.5, 0.05, Color(0.6, 0.62, 0.67), 0.4)
	_shm(b, [0.3, 0.0, 0.0], [0.32, 0.15, -0.7], 0.22, 0.12, Color(0.12, 0.11, 0.1), 0.4)
	_sh(f, [0, 1.1, 0.4], [0, 0.4, 1.6], 0.5, 0.05, Color(0.18, 0.14, 0.12), 0.3)


func _m_wolf(b: W3DBuilder, f: W3DBuilder) -> void:
	var fur := Color(0.40, 0.40, 0.43)
	_sh(b, [0, 0.7, 1.0], [0, 0.78, -0.55], 0.4, 0.38, fur, 0.5)
	_sh(b, [0, 0.8, -0.4], [0, 0.62, -1.45], 0.32, 0.28, fur * 1.1, 0.4)
	_sh(b, [0, 0.62, -1.3], [0, 0.6, -1.75], 0.14, 0.1, Color(0.08, 0.07, 0.07), 0.5)
	_shm(b, [0.17, 0.95, -0.7], [0.3, 1.6, -0.6], 0.1, 0.05, fur * 0.8, 0.3)
	_glow(b, -0.14, 0.9, -1.15, 0.06, Color(0.95, 0.72, 0.4, 0.2))
	_glow(b, 0.14, 0.9, -1.15, 0.06, Color(0.95, 0.72, 0.4, 0.2))
	for i in 5:
		_sh(b, [0, 0.95, 0.7 - i * 0.28], [0, 1.4, 0.55 - i * 0.28], 0.06, 0.05, fur * 0.7, 0.3)
	for sx in [-0.28, 0.28]:
		_sh(b, [sx, 0.0, -0.55], [sx, 0.65, -0.5], 0.1, 0.08, fur * 0.7, 0.5)
		_sh(b, [sx, 0.0, 0.75], [sx, 0.65, 0.7], 0.1, 0.08, fur * 0.7, 0.5)
	_sh(f, [0, 0.8, 0.85], [0, 1.2, 2.4], 0.2, 0.12, fur * 0.85, 0.35)
	_sh(f, [0, 0.7, 0.85], [0.35, 0.85, 2.0], 0.12, 0.08, fur * 0.7, 0.4)


func _m_necro(b: W3DBuilder, f: W3DBuilder) -> void:
	var robe := Color(0.20, 0.15, 0.27)
	var trim := Color(0.34, 0.28, 0.42)
	_sh(b, [0, 0.1, 0.1], [0, 1.25, 0.0], 0.5, 0.4, robe, 0.55)
	_sh(b, [0, 0.95, 0.0], [0.1, 2.3, 0.15], 0.5, 0.5, Color(0.16, 0.12, 0.22), 0.3)
	_sh(b, [0, 1.25, -0.1], [0, 1.4, -0.72], 0.24, 0.22, Color(0.03, 0.03, 0.05), 0.5)
	_glow(b, -0.1, 1.38, -0.58, 0.07, Color(0.55, 0.95, 0.65, 0.2))
	_glow(b, 0.1, 1.38, -0.58, 0.07, Color(0.55, 0.95, 0.65, 0.2))
	_shm(b, [0.15, 1.1, 0.0], [0.78, 0.95, -0.1], 0.2, 0.15, trim, 0.5)
	_sh(b, [0.7, 0.95, 0.0], [0.8, 0.9, -0.55], 0.1, 0.08, Color(0.8, 0.78, 0.7), 0.4)
	# bastone con teschio
	_sh(b, [0.82, 0.9, 1.1], [0.84, 0.95, -1.6], 0.06, 0.05, Color(0.28, 0.2, 0.14), 0.5)
	_sh(b, [0.84, 1.0, -1.45], [0.86, 1.2, -2.1], 0.22, 0.2, Color(0.8, 0.78, 0.68), 0.45)
	_glow(b, 0.78, 1.28, -1.9, 0.05, Color(0.55, 0.95, 0.65, 0.2))
	_glow(b, 0.94, 1.28, -1.9, 0.05, Color(0.55, 0.95, 0.65, 0.2))
	_sh(b, [0.85, 1.1, -2.0], [0.85, 1.4, -2.6], 0.12, 0.12, Color(0.45, 0.95, 0.6, 0.15), 0.4)
	_sh(f, [0, 1.15, 0.12], [0, 0.3, 2.1], 0.9, 0.05, Color(0.16, 0.11, 0.23), 0.3)
	_sh(f, [-0.3, 1.1, 0.12], [-1.1, 0.25, 1.6], 0.34, 0.04, Color(0.13, 0.09, 0.19), 0.35)
	_sh(f, [0.3, 1.1, 0.12], [1.1, 0.25, 1.6], 0.34, 0.04, Color(0.13, 0.09, 0.19), 0.35)
	_sh(f, [0, 0.9, 0.2], [0.3, 0.5, 1.2], 0.12, 0.03, Color(0.4, 0.8, 0.5, 0.3), 0.4)


func _char_mesh(kind: String) -> ArrayMesh:
	var key := "model_" + kind
	if vox_cache.has(key):
		return vox_cache[key]
	_char_build(kind)
	return vox_cache[key]


func _char_flow(kind: String) -> ArrayMesh:
	_char_mesh(kind)
	return vox_cache["flow_" + kind]


func _char_build(kind: String) -> void:
	if W3DChars.has(kind):
		var mm: Array = W3DChars.build(kind)
		vox_cache["model_" + kind] = mm[0]
		vox_cache["flow_" + kind] = mm[1]
		return
	var b := W3DBuilder.new()
	var f := W3DBuilder.new()
	b.rn.seed = hash(kind)
	f.rn.seed = hash(kind) + 7
	match kind:
		"hero":
			_m_hero(b, f)
		"necro":
			_m_necro(b, f)
		"goblin":
			_m_goblin(b, f, false)
		"goblin_archer":
			_m_goblin(b, f, true)
		"skeleton":
			_m_skel(b, f, false)
		"skel_archer":
			_m_skel(b, f, true)
		"ghoul":
			_m_ghoul(b, f)
		"kobold":
			_m_kobold(b, f)
		"orc":
			_m_orc(b, f)
		"wolf":
			_m_wolf(b, f)
		_:
			_m_goblin(b, f, false)
	f.shift(-_pivot(kind))
	vox_cache["model_" + kind] = b.mesh()
	vox_cache["flow_" + kind] = f.mesh()


func _pivot(kind: String) -> Vector3:
	if W3DChars.has(kind):
		return W3DChars.pivot(kind)
	return Vector3(0, 0.8, 0.8) if kind == "wolf" else Vector3(0, 1.0, 0.1)


func _flow_anim(nd: Node3D, speed01: float, t: float) -> void:
	if not nd.has_meta("flow"):
		return
	var fl: Node3D = nd.get_meta("flow")
	fl.rotation.x = -0.32 * speed01 + sin(t * 6.0) * 0.1 * speed01 + sin(t * 1.7) * 0.05
	fl.rotation.y = sin(t * 4.3) * 0.14 * (0.3 + speed01)
	fl.rotation.z = sin(t * 5.1) * 0.06 * speed01


func _vox_mesh(sname: String, vox: float) -> ArrayMesh:
	if char_style == 0:
		return _char_mesh(sname)
	var key := "%s_%d" % [sname, char_style]
	if vox_cache.has(key):
		return vox_cache[key]
	var img: Image = Game.tex(sname).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var b := W3DBuilder.new()
	if char_style == 1:
		b.inflate(img, vox)
	else:
		b.voxel(img, vox)
	var m := b.mesh()
	vox_cache[key] = m
	return m


func _disc() -> ArrayMesh:
	if disc_mesh == null:
		var b := W3DBuilder.new()
		for i in 10:
			var a0 := TAU * i / 10.0
			var a1 := TAU * (i + 1) / 10.0
			b.tri(Vector3(0, 0.04, 0), Vector3(cos(a0) * 0.9, 0.04, sin(a0) * 0.8), Vector3(cos(a1) * 0.9, 0.04, sin(a1) * 0.8), Color(0.012, 0.01, 0.018))
		disc_mesh = b.mesh()
	return disc_mesh


func _vox_node(sname: String, vox: float) -> Node3D:
	var n := Node3D.new()
	var sd := MeshInstance3D.new()
	sd.visible = shadow_disc
	sd.mesh = _disc()
	sd.material_override = mat_chr
	sd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := Node3D.new()
	n.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = _vox_mesh(sname, vox)
	mi.material_override = mat_chr
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mi)
	if char_style == 0:
		var fm := _char_flow(sname)
		if fm.get_surface_count() > 0:
			var fl := Node3D.new()
			fl.position = _pivot(sname)
			var fi := MeshInstance3D.new()
			fi.mesh = fm
			fi.material_override = mat_chr
			fi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			fl.add_child(fi)
			body.add_child(fl)
			n.set_meta("flow", fl)
	n.add_child(sd)
	vp.add_child(n)
	return n


func _build_hero() -> void:
	if hero != null and is_instance_valid(hero):
		hero.queue_free()
	hero = _vox_node(hero_kind, 0.075)
	hero_body = hero.get_child(0)
	for n in npcs:
		(n["node"] as Node3D).queue_free()
	npcs.clear()
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_v + 99
	if lineup and not sheet:
		var kinds := ["hero", "goblin", "goblin_archer", "skeleton", "skel_archer", "ghoul", "kobold", "orc", "wolf"]
		for i in kinds.size():
			var nd := _vox_node(kinds[i], 0.075)
			var q := pos + Vector2(-6.6 + i * 1.65, 1.2)
			nd.position = Vector3(q.x, 0, q.y)
			npcs.append({"node": nd, "pos": q, "dir": Vector2.ZERO, "t": 999.0, "spd": 0.0, "ph": 0.0})
		return
	if not demo:
		for i in 14:
			_spawn_npc(rr)


func _spawn_npc(rr: RandomNumberGenerator) -> void:
	var ang := rr.randf() * TAU
	var rad := rr.randf_range(10.0, fade_a - 8.0)
	var q := pos + Vector2.from_angle(ang) * rad
	if _blocked(q, 0.5):
		return
	var kind: String = NPC_KINDS[rr.randi() % NPC_KINDS.size()]
	var nd := _vox_node(kind, 0.075)
	npcs.append({"node": nd, "pos": q, "dir": Vector2.from_angle(rr.randf() * TAU), "t": rr.randf_range(0.5, 3.0), "spd": rr.randf_range(1.4, 3.2), "ph": rr.randf() * 6.0})


func _face(nd: Node3D, dv: Vector2, dt: float, moving: bool) -> void:
	if char_style == 0:
		if moving:
			if nd == hero:
				nd.rotation.y = atan2(-dv.x, -dv.y)   # l'eroe gira all'istante
			else:
				nd.rotation.y = lerp_angle(nd.rotation.y, atan2(-dv.x, -dv.y), 1.0 - exp(-12.0 * dt))
	elif absf(dv.x) > 0.2:
		nd.scale.x = -1.0 if dv.x < 0.0 else 1.0
		nd.rotation.y = 0.0


func _npc_update(dt: float) -> void:
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	for i in range(npcs.size() - 1, -1, -1):
		var n: Dictionary = npcs[i]
		n["t"] = float(n["t"]) - dt
		if float(n["t"]) <= 0.0:
			n["t"] = rr.randf_range(0.8, 3.0)
			n["dir"] = Vector2.from_angle(rr.randf() * TAU) if rr.randf() < 0.75 else Vector2.ZERO
		var dv: Vector2 = n["dir"]
		var np: Vector2 = n["pos"]
		if dv.length() > 0.1:
			var st := dv * float(n["spd"]) * dt
			if not _blocked(np + Vector2(st.x, 0), 0.4):
				np.x += st.x
			else:
				n["t"] = 0.0
			if not _blocked(np + Vector2(0, st.y), 0.4):
				np.y += st.y
			n["pos"] = np
			n["ph"] = float(n["ph"]) + dt * 9.0
		var nd: Node3D = n["node"]
		nd.position = Vector3(np.x, _height(np, 3.0), np.y)
		_face(nd, dv, dt, dv.length() > 0.1)
		_flow_anim(nd, 1.0 if dv.length() > 0.1 else 0.0, lamp_t + float(n["ph"]))
		(nd.get_child(0) as Node3D).position.y = absf(sin(float(n["ph"]))) * 0.06 if dv.length() > 0.1 else 0.0
		if np.distance_to(pos) > fade_a + 6.0:
			nd.queue_free()
			npcs.remove_at(i)
	if not lineup and npcs.size() < 14 and rr.randf() < 0.05:
		_spawn_npc(rr)


# ------------------------------------------------------------------ sprite dall'alto (assets/topdown)
var td_cells: Dictionary = {}


func td_has(name: String) -> bool:
	return ResourceLoader.exists("res://assets/topdown/%s.png" % name) and ResourceLoader.exists("res://assets/topdown/%s_h.png" % name)


func td_get(name: String) -> Dictionary:
	if td_cells.has(name):
		return td_cells[name]
	var im: Image = (load("res://assets/topdown/%s.png" % name) as Texture2D).get_image()
	var hm: Image = (load("res://assets/topdown/%s_h.png" % name) as Texture2D).get_image()
	for q in [im, hm]:
		if (q as Image).is_compressed():
			(q as Image).decompress()
		(q as Image).convert(Image.FORMAT_RGBA8)
	var b := W3DBuilder.new()
	var cells := b.hcells(im, hm, TD_STEP)
	var res := {"cells": cells, "w": im.get_width() / TD_STEP}
	td_cells[name] = res
	return res


func td_mesh(name: String) -> ArrayMesh:
	var key := "tdm_" + name
	if vox_cache.has(key):
		return vox_cache[key]
	var d := td_get(name)
	var b := W3DBuilder.new()
	b.build_cells(d["cells"], int(d["w"]), TD_VOX * TD_STEP)
	var m := b.mesh()
	vox_cache[key] = m
	return m


# ------------------------------------------------------------------ mockup: sprite originale | 3D esatto | modello stilizzato
func _exact_mesh(kind: String) -> ArrayMesh:
	var key := "exact_" + kind
	if vox_cache.has(key):
		return vox_cache[key]
	var img: Image = Game.tex(kind).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var b := W3DBuilder.new()
	b.voxel(img, 0.078, 2, 3)
	var m := b.mesh()
	vox_cache[key] = m
	return m


func _topdown_mesh(kind: String) -> ArrayMesh:
	var key := "td_" + kind
	if vox_cache.has(key):
		return vox_cache[key]
	var img: Image = Game.tex(kind).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var b := W3DBuilder.new()
	b.topdown(img, 1.0 / 16.0 * 1.1)
	var m := b.mesh()
	vox_cache[key] = m
	return m


func _build_sheet() -> void:
	var kinds: Array = W3DChars.KINDS
	for i in kinds.size():
		var kind: String = kinds[i]
		var col := i % 3
		var row := i / 3
		var x0 := col * 9.4 - 9.4
		var z0 := row * 4.4
		# sprite originale, disteso a terra
		var sp := Sprite3D.new()
		sp.texture = Game.tex(kind)
		sp.pixel_size = 0.078
		sp.rotation_degrees = Vector3(-90, 0, 0)
		sp.position = Vector3(x0 - 3.3, 0.06, z0 - 0.5)
		sp.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sp.shaded = false
		vp.add_child(sp)
		# 3D esatto: ogni pixel un cubetto
		var ex := Node3D.new()
		var mi := MeshInstance3D.new()
		mi.mesh = _exact_mesh(kind)
		mi.material_override = mat_chr
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		ex.add_child(mi)
		ex.position = Vector3(x0 - 1.1, 0, z0 - 0.5)
		vp.add_child(ex)
		# 3D esatto DALL'ALTO: lo stesso sprite ricostruito come solido e letto dall'alto
		var td := Node3D.new()
		var tmi := MeshInstance3D.new()
		tmi.mesh = td_mesh(kind) if td_has(kind) else _topdown_mesh(kind)
		tmi.material_override = mat_chr
		tmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		td.add_child(tmi)
		td.position = Vector3(x0 + 1.1, 0, z0)
		vp.add_child(td)
		# modello stilizzato
		var nd := _vox_node(kind, 0.075)
		nd.position = Vector3(x0 + 3.3, 0, z0)
		nd.scale = Vector3.ONE * 0.8
		# etichetta
		var lb := Label3D.new()
		lb.text = kind.to_upper()
		lb.font = Game.font()
		lb.font_size = 36
		lb.pixel_size = 0.016
		lb.rotation_degrees = Vector3(-90, 0, 0)
		lb.modulate = Color(1, 0.9, 0.5)
		lb.outline_size = 8
		lb.no_depth_test = true
		lb.position = Vector3(x0, 0.2, z0 + 1.8)
		vp.add_child(lb)
	hero.visible = false


# ------------------------------------------------------------------ gioco
func _col_hit(cl: Array, p: Vector2, rr: float) -> bool:
	if cl[0] == "c":
		return p.distance_to(cl[1]) < cl[2] + rr
	var c: Vector2 = cl[1]
	var half: Vector2 = cl[2]
	var yw: float = cl[3]
	var dx2 := p.x - c.x
	var dz2 := p.y - c.y
	var lx := dx2 * cos(yw) - dz2 * sin(yw)
	var lz := dx2 * sin(yw) + dz2 * cos(yw)
	var qx := clampf(lx, -half.x, half.x)
	var qz := clampf(lz, -half.y, half.y)
	return Vector2(lx - qx, lz - qz).length() < rr


func _blocked(p: Vector2, rr: float) -> bool:
	var pc := Vector2i(floori(p.x / CHS), floori(p.y / CHS))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := pc + Vector2i(dx, dz)
			if not chunks.has(k):
				continue
			for cl in chunks[k]["cols"]:
				if _col_hit(cl, p, rr):
					return true
	# grandi strutture: le collisioni stanno in una lista a parte, perche' si estendono oltre i blocchi vicini
	for mc in mega_cols.values():
		if p.distance_to(mc["c"]) > float(mc["r"]) + 4.0:
			continue
		for cl in mc["cols"]:
			if _col_hit(cl, p, rr):
				return true
	return false


func _process(dt: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	var moving := dir.length() > 0.1
	if moving:
		dir = dir.normalized()
	var step := dir * SPEED * dt
	if combat != null:
		combat.w_dir = dir
		step = combat.hero_step(dir, dt)
	if moving and (combat == null or combat.free_turn()):
		facing = dir
	if step.length() > 0.0001:
		if not _blocked(pos + Vector2(step.x, 0), 0.34):
			pos.x += step.x
		if not _blocked(pos + Vector2(0, step.y), 0.34):
			pos.y += step.y
	if moving:
		bob_t += dt * 11.0
	if combat != null:
		combat.update(dt)
	hero.position = Vector3(pos.x, _height(pos, 3.0), pos.y)
	if sheet:
		hero.visible = false
	_face(hero, facing, dt, moving or (combat != null and not combat.free_turn()))
	if combat != null and char_style == 0:
		hero.rotation.y += combat.swing_offset()
	hero_body.position.y = absf(sin(bob_t)) * 0.07 if moving else 0.0
	hero_body.rotation.z = sin(bob_t) * 0.05 if moving else 0.0
	_flow_anim(hero, 1.0 if moving else 0.0, lamp_t)
	_npc_update(dt)
	_update_cam()
	RenderingServer.global_shader_parameter_set("w3d_player", Vector3(pos.x, 0, pos.y))
	if shots.is_empty():
		if Engine.get_process_frames() % 2 == 0:
			_stream(false)
		_run_jobs(5.0)
	lamp_t += dt
	if Engine.get_process_frames() % 90 == 0:
		print("W3D fps=", Engine.get_frames_per_second(), " blocchi=", chunks.size(), " coda=", jobs.size(), " gen_ms=", snappedf(gen_ms, 0.1))
	_update_lamps()
	_mp("curve", curve)
	_mp("fade_a", fade_a)
	_mp("fade_b", fade_a + 18.0)
	_mp("hero_glow", 0.0 if lineup else 1.0)
	mat.set_shader_parameter("patt", 1.0 if patterns else 0.0)
	mat_chr.set_shader_parameter("patt", 0.0)
	post_rect.material = null if nofx else post_mat
	hud.text = "WASD muovi  SPAZIO colpo  L pesante  SHIFT rotolata  Q fiala  E falo'  ESC esci   |   F2/F3 curva %.3f  F4/F5 bolla  F6 filtro  F7 nuovo  F8 pixel  F9 UFO-cam  T trame  C personaggi   %d FPS" % [curve, Engine.get_frames_per_second()]
	if not shots.is_empty():
		_shot_step()


func _mp(k: String, v: Variant) -> void:
	mat.set_shader_parameter(k, v)
	mat_chr.set_shader_parameter(k, v)
	mat_prop.set_shader_parameter(k, v)
	if mat_ground != null:
		mat_ground.set_shader_parameter(k, v)
	if k in ["curve", "fade_a", "fade_b"]:
		for om in extra_mats:
			(om as ShaderMaterial).set_shader_parameter(k, v)


var elev_y := 0.0          # quota del terreno sotto il giocatore (la camera la segue)


func _update_cam() -> void:
	# UFO Camera Transition System
	if ufo_cam_active:
		ufo_cam_target_rot_x = -75.0
		ufo_cam_target_h = 55.0
		ufo_cam_target_fov = 45.0
	else:
		ufo_cam_target_rot_x = -90.0
		ufo_cam_target_h = cam_h
		ufo_cam_target_fov = 38.6

	# Smooth interpolation
	cam.rotation_degrees.x = lerp(cam.rotation_degrees.x, ufo_cam_target_rot_x, 1.0 - exp(-get_process_delta_time() * ufo_cam_transition_speed))
	cam.position.y = lerp(cam.position.y, ufo_cam_target_h + elev_y, 1.0 - exp(-get_process_delta_time() * ufo_cam_transition_speed))
	cam.fov = lerp(cam.fov, ufo_cam_target_fov, 1.0 - exp(-get_process_delta_time() * ufo_cam_transition_speed))

	cam.position.x = pos.x + randf_range(-shake, shake) * 0.25

	cam.position.z = pos.y + randf_range(-shake, shake) * 0.25


func _update_lamps() -> void:
	var cand: Array = []
	for k in chunks:
		for l in chunks[k]["lamps"]:
			var lv: Vector4 = l
			cand.append([Vector2(lv.x, lv.z).distance_squared_to(pos), lv])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var arr := PackedVector4Array()
	for i in 16:
		if i < cand.size():
			var lv: Vector4 = cand[i][1]
			var fl := 1.0 + sin(lamp_t * 11.0 + lv.x * 3.1) * 0.09 + sin(lamp_t * 23.0 + lv.z) * 0.05
			arr.append(Vector4(lv.x, lv.y, lv.z, lv.w * fl))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	_mp("lamps", arr)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/main.tscn")
			KEY_F2:
				curve = minf(curve + 0.002, 0.04)
			KEY_F3:
				curve = maxf(curve - 0.002, 0.0)
			KEY_F4:
				fade_a = minf(fade_a + 6.0, 90.0)
			KEY_F5:
				fade_a = maxf(fade_a - 6.0, 24.0)
			KEY_F6:
				nofx = not nofx
			KEY_F7:
				seed_v = randi() % 100000
				_new_world()
			KEY_F8:
				res_i = (res_i + 1) % RES.size()
				vp.size = RES[res_i]
				post_mat.set_shader_parameter("px", Vector2(RES[res_i]))
			KEY_F9:
				ufo_cam_active = not ufo_cam_active
				print("UFO Camera Mode: ", "ON" if ufo_cam_active else "OFF")
			KEY_F10:
				if combat and not combat.ufo_wave_active:
					combat.start_ufo_wave()
				elif combat and combat.ufo_wave_active:
					combat._end_ufo_wave()
			KEY_T:
				patterns = not patterns
			KEY_C:
				char_style = (char_style + 1) % 3
				_build_hero()


func _shot_step() -> void:
	if shot_i >= shots.size():
		get_tree().quit()
		return
	shot_wait += 1
	if shot_wait == 1:
		if not lineup or sheet:
			pos = shots[shot_i]
		_stream(true)
		_update_cam()
	elif shot_wait == 8:
		get_viewport().get_texture().get_image().save_png("user://w3d_%d.png" % shot_i)
		shot_i += 1
		shot_wait = 0


# ------------------------------------------------------------------ editor del mondo (F12 nel gioco)
## Le modifiche sono in coordinate del mondo 3D (non cambiano se si sposta world_off) e si applicano a ogni blocco quando nasce:
## prima la gomma toglie i triangoli, le collisioni, le luci e le porte generate nelle zone cancellate, poi si aggiungono gli oggetti piazzati.
const ED_CAT := [["house", "Casa", true], ["chapel", "Cappella", true], ["mausoleum", "Mausoleo", true], ["tree", "Albero morto", false],
		["bush", "Cespuglio", false], ["rock", "Masso", true], ["log", "Tronco caduto", false], ["barrel", "Botte", false],
		["crate", "Cassa", false], ["hay", "Fieno", false], ["woodpile", "Legna", true], ["cart", "Carro", true], ["bench", "Panca", true],
		["sign", "Cartello", true], ["scarecrow", "Spaventapasseri", false], ["well", "Pozzo", false], ["gallows", "Forca", false],
		["pyre", "Pira", false], ["ruin", "Rovina", false], ["lamp", "Lampione", false], ["grave", "Tomba", false],
		["field", "Campo di grano", true], ["veg", "Vegetazione", true]]
var ed_adds: Array = []      # {k, x, z, yaw, s}
var ed_erase: Array = []     # [x, z, raggio]
var ed_hide: Array = []      # oggetti del gioco nascosti: [x*100, z*100] arrotondati
var ed_hide_keys: Dictionary = {}
var ed_props: Array = []     # oggetti-nodo dei dungeon/case: {t:"mv",k,ox,oy,dx,dy} sposta, {t:"del",k,ox,oy} nasconde, {t:"add",k,cx,cy} aggiunge
var ed_loaded := false
var ed_areas: Dictionary = {}
var ed_area_key := ""


func ed_load() -> void:
	if ed_loaded:
		return
	ed_loaded = true
	ed_areas.clear()
	var paths: Array = ["res://data/w3d_edits.json"]
	if not OS.has_feature("editor"):
		paths.append("user://w3d_edits.json")
	for path in paths:
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				if d.get("areas") is Dictionary:
					for key in d["areas"]:
						if d["areas"][key] is Dictionary:
							ed_areas[key] = d["areas"][key]
				elif d.has("add") or d.has("erase") or d.has("hide"):
					ed_areas["world"] = d


func ed_set_area(area_key: String) -> void:
	if not ed_loaded:
		ed_load()
	if ed_area_key == area_key:
		return
	ed_area_key = area_key
	var d: Dictionary = ed_areas.get(area_key, {})
	ed_adds = (d.get("add", []) as Array).duplicate(true)
	ed_erase = (d.get("erase", []) as Array).duplicate(true)
	ed_hide = (d.get("hide", []) as Array).duplicate(true)
	ed_props = (d.get("props", []) as Array).duplicate(true)
	ed_hide_sync()


## tutte le modifiche (anche delle altre aree) come testo JSON
func ed_json() -> String:
	if ed_area_key == "":
		ed_area_key = "world"
	ed_areas[ed_area_key] = {"add": ed_adds, "erase": ed_erase, "hide": ed_hide, "props": ed_props}
	return JSON.stringify({"areas": ed_areas}, "	")


## dal gioco lanciato dall'editor Godot scrive in godot/data (finisce nel progetto), dall'exe in user://
func ed_save() -> String:
	var path := "user://w3d_edits.json"
	if OS.has_feature("editor"):
		path = ProjectSettings.globalize_path("res://data/w3d_edits.json")
	if ed_area_key == "":
		ed_area_key = "world"
	ed_areas[ed_area_key] = {"add": ed_adds, "erase": ed_erase, "hide": ed_hide, "props": ed_props}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	var txt := JSON.stringify({"areas": ed_areas}, "	")
	f.store_string(txt)
	f.close()
	# dall'exe (build/CryptOfEmbers.exe) scrive anche nel progetto (godot/data), cosi' le prossime compilazioni includono le modifiche
	if not OS.has_feature("editor"):
		var pd := OS.get_executable_path().get_base_dir().path_join("../godot/data").simplify_path()
		if DirAccess.dir_exists_absolute(pd):
			var f2 := FileAccess.open(pd.path_join("w3d_edits.json"), FileAccess.WRITE)
			if f2 != null:
				f2.store_string(txt)
				f2.close()
				return pd.path_join("w3d_edits.json")
	return path


const ED_NATIVE_YAW := ["house", "chapel", "mausoleum", "woodpile", "cart", "bench", "sign", "field", "veg", "dec:sarc", "dec:coffin", "dec:altar", "dec:rack",
		"dec:chest", "dec:statue", "dec:barrels", "dec:beam", "dec:w_pillar", "dec:w_skulls", "dec:w_niche", "dec:w_banner", "dec:w_chains", "dec:w_web"]
const ED_NATIVE_SC := ["dec:sarc", "dec:coffin", "dec:altar", "dec:rack", "dec:chest", "dec:statue", "dec:barrels", "dec:brazier", "dec:cage", "house", "chapel", "mausoleum"]


## costruisce un oggetto piazzato/adottato: rotazione e scala valgono per qualsiasi tipo (quelli che non le gestiscono da soli vengono trasformati dopo la costruzione)
## y0 = rotazione con cui il gioco aveva generato l'oggetto (per gli oggetti adottati dall'editor)
func _ed_place(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array, sc := 1.0, y0 := 0.0) -> void:
	if k.begins_with("model:"):
		_ed_make(k, o, p, yaw, r, cols, lamps, sc)
		return
	var native := ED_NATIVE_YAW.has(k) or W3DStructs.KINDS.has(k)
	var extra := 0.0 if native else yaw - y0
	var post_sc := 1.0 if ED_NATIVE_SC.has(k) else sc
	if absf(extra) < 0.0001 and absf(post_sc - 1.0) < 0.0001:
		_ed_make(k, o, p, yaw if native else y0, r, cols, lamps, sc if ED_NATIVE_SC.has(k) else 1.0)
		return
	var n0 := o.v.size()
	var c0 := cols.size()
	_ed_make(k, o, p, yaw if native else y0, r, cols, lamps, sc if ED_NATIVE_SC.has(k) else 1.0)
	var rot := Basis(Vector3.UP, extra)
	for i in range(n0, o.v.size()):
		var q: Vector3 = o.v[i]
		var rel: Vector3 = (rot * Vector3(q.x - p.x, q.y, q.z - p.y)) * post_sc
		o.v[i] = Vector3(p.x + rel.x, rel.y, p.y + rel.z)
	for i in range(c0, cols.size()):
		var cc: Array = cols[i]
		var cp: Vector2 = cc[1]
		var rp: Vector3 = (rot * Vector3(cp.x - p.x, 0.0, cp.y - p.y)) * post_sc
		cc[1] = Vector2(p.x + rp.x, p.y + rp.z)
		if str(cc[0]) == "c":
			cc[2] = float(cc[2]) * post_sc
		elif str(cc[0]) == "b":
			cc[2] = (cc[2] as Vector2) * post_sc
			cc[3] = float(cc[3]) + extra


func _ed_make(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array, sc := 1.0) -> void:
	if k.begins_with("model:"):
		_ed_make_model(k.substr(6), o, p, yaw, sc, cols)
		return
	if k.begins_with("dec:"):
		_ed_decor(k.substr(4), o, p, yaw, r, sc, lamps)
		return
	match k:
		"house":
			_house(o, p, yaw, r, cols, lamps)
		"chapel":
			_chapel(o, p, yaw, r, cols, lamps)
		"mausoleum":
			_mausoleum(o, p, yaw, r, cols, lamps)
		"tree":
			_dead_tree(o, p, r, cols)
		"bush":
			_bush(o, p, r, cols)
		"rock":
			o.rock(Vector3(p.x, 0.32, p.y), Vector3(1.3, 0.75, 1.0), Color(0.22, 0.22, 0.24), 0.14, 0.4, yaw)
			cols.append(["c", p, 0.6])
		"log":
			_fallen_log(o, p, r)
		"barrel":
			_barrel(o, p, r, cols)
		"crate":
			_crate(o, p, r, cols)
		"hay":
			_hay(o, p, r, cols)
		"woodpile":
			_woodpile(o, p, yaw, r, cols)
		"cart":
			_cart(o, p, yaw, r, cols)
		"bench":
			_bench(o, p, yaw, r, cols)
		"sign":
			_sign(o, p, yaw, r, cols)
		"scarecrow":
			_scarecrow(o, p, r, cols)
		"well":
			_well(o, p, r, cols)
		"gallows":
			_gallows(o, p, r, cols)
		"pyre":
			_pyre(o, p, r, cols, lamps)
		"ruin":
			_ruin(o, p, r, cols)
		"lamp":
			_lamp_post(o, p, lamps, cols)
		"grave":
			_grave_item(o, p, r, cols, lamps)
		"field":
			_wheat_field(o, p, yaw, r, cols)
		"veg":
			_veg_patch(o, p, yaw, r, cols)
		_:
			W3DStructs.build(k, o, p, yaw, r, cols, lamps)


func _ed_cut(b: W3DBuilder, ex: float, ez: float, er: float) -> void:
	var nv := PackedVector3Array()
	var nc := PackedColorArray()
	var e2 := er * er
	for i in range(0, b.v.size() - 2, 3):
		var a := b.v[i]
		var bb := b.v[i + 1]
		var d := b.v[i + 2]
		var cx := (a.x + bb.x + d.x) / 3.0 - ex
		var cz := (a.z + bb.z + d.z) / 3.0 - ez
		if cx * cx + cz * cz < e2:
			continue
		nv.append(a)
		nv.append(bb)
		nv.append(d)
		nc.append(b.c[i])
		nc.append(b.c[i + 1])
		nc.append(b.c[i + 2])
	b.v = nv
	b.c = nc


func _ed_apply(j: Dictionary) -> void:
	if ed_adds.is_empty() and ed_erase.is_empty():
		return
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var o: W3DBuilder = j["o"]
	var cols: Array = j["cols"]
	var lamps: Array = j["lamps"]
	for e in ed_erase:
		var ex := float(e[0])
		var ez := float(e[1])
		var er := float(e[2])
		if ex + er < x0 or ex - er > x0 + CHS or ez + er < z0 or ez - er > z0 + CHS:
			continue
		_ed_cut(o, ex, ez, er)
		_ed_cut(j["v"], ex, ez, er)
		var ec := Vector2(ex, ez)
		for i in range(cols.size() - 1, -1, -1):
			if (cols[i][1] as Vector2).distance_to(ec) < er:
				cols.remove_at(i)
		for i in range(lamps.size() - 1, -1, -1):
			var lv: Vector4 = lamps[i]
			if Vector2(lv.x, lv.z).distance_to(ec) < er:
				lamps.remove_at(i)
		for key in house_doors.keys():
			var dv: Vector3 = house_doors[key]
			if Vector2(dv.x, dv.y).distance_to(ec) < er:
				house_doors.erase(key)
		for i in range(o.reg.size() - 1, -1, -1):
			if (o.reg[i][1] as Vector2).distance_to(ec) < er:
				o.reg.remove_at(i)
		for i in range(o.breakables.size() - 1, -1, -1):
			if (o.breakables[i]["pos"] as Vector2).distance_to(ec) < er:
				o.breakables.remove_at(i)
		for i in range(o.smokes.size() - 1, -1, -1):
			var sv: Vector3 = o.smokes[i]
			if Vector2(sv.x, sv.z).distance_to(ec) < er:
				o.smokes.remove_at(i)
	fence_rule = false       # gli oggetti piazzati a mano non seguono il vincolo dei recinti
	for a in ed_adds:
		var ax := float(a["x"])
		var az := float(a["z"])
		if ax < x0 or ax >= x0 + CHS or az < z0 or az >= z0 + CHS:
			continue
		var r := RandomNumberGenerator.new()
		if a.has("st"):         # oggetto generato dal gioco e poi adottato: stessa forma di prima
			r.state = int(str(a["st"]))
			o.rn.state = int(str(a["os"]))
		else:
			r.seed = int(a["s"])
			o.rn.seed = r.randi()
		var added_kind := str(a["k"])
		var added_pos := Vector2(ax, az)
		if ed_hide_keys.has(Vector2i(roundi(ax * 100.0), roundi(az * 100.0))):
			continue
		if added_kind in ["barrel", "crate", "hay"]:
			o.breakables.append({"kind": added_kind, "pos": added_pos})
		_ed_place(added_kind, o, added_pos, float(a["yaw"]), r, cols, lamps, float(a.get("sc", 1.0)), float(a.get("y0", float(a["yaw"]) if a.has("st") else 0.0)))
	fence_rule = true


## editor degli interni: le geometrie statiche vengono ricostruite quando si salva o si cambia oggetto
func _ed_decor(_item: String, _o: W3DBuilder, _p: Vector2, _yaw: float, _r: RandomNumberGenerator, _sc: float, _lamps: Array) -> void:
	pass


func _ed_apply_static(builders: Array, target: W3DBuilder, lamps := []) -> void:
	if ed_adds.is_empty() and ed_erase.is_empty():
		return
	for e in ed_erase:
		for b in builders:
			_ed_cut(b, float(e[0]), float(e[1]), float(e[2]))
	var saved_house_doors := house_doors.duplicate(true)
	var saved_fence_rule := fence_rule
	fence_rule = false
	for a in ed_adds:
		var added := W3DBuilder.new()
		added.sat = 1.55
		added.con = 1.45
		var r := RandomNumberGenerator.new()
		if a.has("st"):
			r.state = int(str(a["st"]))
			added.rn.state = int(str(a["os"]))
		else:
			r.seed = int(a["s"])
			added.rn.seed = r.randi()
		_ed_place(str(a["k"]), added, Vector2(float(a["x"]), float(a["z"])), float(a["yaw"]), r, [], lamps, float(a.get("sc", 1.0)), float(a.get("y0", float(a["yaw"]) if a.has("st") else 0.0)))
		target.v.append_array(added.v)
		target.c.append_array(added.c)
	fence_rule = saved_fence_rule
	house_doors = saved_house_doors


# ------------------------------------------------------------------ modelli 3D importati (.glb / .gltf in res://assets/models)
## Ogni triangolo prende un solo colore (colore del materiale x colore dei vertici x texture nel centro del triangolo),
## cosi' il modello si comporta come gli altri oggetti del mondo: luci finte, ombre, nebbia e bolla di visibilita'.
const ED_MODEL_DIR := "res://assets/models"
const ED_USER_MODELS := "user://models"       # modelli importati dall'editor: funzionano anche dall'exe, senza reimportare il progetto
var ed_model_cache: Dictionary = {}


func ed_model_names() -> Array:
	var out: Array = []
	var seen := {}
	for dir in [ED_MODEL_DIR, ED_USER_MODELS]:
		for f in DirAccess.get_files_at(dir):
			var n := f.trim_suffix(".import").trim_suffix(".remap")
			var ext := n.get_extension().to_lower()
			if (ext == "glb" or ext == "gltf") and not seen.has(n):
				seen[n] = true
				out.append(n)
	out.sort()
	return out


func ed_model(name: String) -> Dictionary:
	if ed_model_cache.has(name):
		return ed_model_cache[name]
	var res := {}
	var path := ED_MODEL_DIR + "/" + name
	var ps = load(path) if ResourceLoader.exists(path) else null
	var user_path := ED_USER_MODELS + "/" + name
	if ps == null and FileAccess.file_exists(user_path):
		# file .glb/.gltf copiato in user://models: si legge a runtime, senza passare dall'importazione di Godot
		var doc := GLTFDocument.new()
		var gst := GLTFState.new()
		if doc.append_from_file(ProjectSettings.globalize_path(user_path), gst) == OK:
			ps = doc.generate_scene(gst)
	if ps is Node:
		var rn: Node = ps
		var vs0 := PackedVector3Array()
		var cs0 := PackedColorArray()
		_ed_collect(rn, Transform3D.IDENTITY, vs0, cs0)
		rn.free()
		if vs0.size() >= 3:
			var miny0 := 1e9
			for q0 in vs0:
				miny0 = minf(miny0, q0.y)
			for i0 in vs0.size():
				vs0[i0] = Vector3(vs0[i0].x, vs0[i0].y - miny0, vs0[i0].z)
			res = {"v": vs0, "c": cs0}
	elif ps is PackedScene:
		var root: Node = (ps as PackedScene).instantiate()
		var vs := PackedVector3Array()
		var cs := PackedColorArray()
		_ed_collect(root, Transform3D.IDENTITY, vs, cs)
		root.free()
		if vs.size() >= 3:
			var miny := 1e9
			for q in vs:
				miny = minf(miny, q.y)
			for i in vs.size():
				vs[i] = Vector3(vs[i].x, vs[i].y - miny, vs[i].z)    # il modello poggia sul terreno
			res = {"v": vs, "c": cs}
	else:
		print("MODELLO non caricabile: ", path)
	ed_model_cache[name] = res
	return res


func _ed_collect(n: Node, parent_t: Transform3D, vs: PackedVector3Array, cs: PackedColorArray) -> void:
	var t := parent_t
	if n is Node3D:
		t = parent_t * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var m: Mesh = mi.mesh
		for sidx in m.get_surface_count():
			var arr := m.surface_get_arrays(sidx)
			var pv = arr[Mesh.ARRAY_VERTEX]
			if pv == null:
				continue
			var pp: PackedVector3Array = pv
			var idx = arr[Mesh.ARRAY_INDEX]
			var col = arr[Mesh.ARRAY_COLOR]
			var uv = arr[Mesh.ARRAY_TEX_UV]
			var base := Color.WHITE
			var img: Image = null
			var mat: Material = mi.get_active_material(sidx)
			if mat is BaseMaterial3D:
				var bm := mat as BaseMaterial3D
				base = bm.albedo_color
				if bm.albedo_texture != null:
					img = bm.albedo_texture.get_image()
					if img != null:
						if img.is_compressed():
							img.decompress()
						img.convert(Image.FORMAT_RGBA8)
			var has_idx: bool = idx != null and (idx as PackedInt32Array).size() > 0
			var ntri: int = ((idx as PackedInt32Array).size() if has_idx else pp.size()) / 3
			var has_col: bool = col != null and (col as PackedColorArray).size() == pp.size()
			var has_uv: bool = img != null and uv != null and (uv as PackedVector2Array).size() == pp.size()
			for ti in ntri:
				var i0: int = idx[ti * 3] if has_idx else ti * 3
				var i1: int = idx[ti * 3 + 1] if has_idx else ti * 3 + 1
				var i2: int = idx[ti * 3 + 2] if has_idx else ti * 3 + 2
				var c := base
				if has_col:
					var cc: PackedColorArray = col
					c = Color((cc[i0].r + cc[i1].r + cc[i2].r) / 3.0, (cc[i0].g + cc[i1].g + cc[i2].g) / 3.0, (cc[i0].b + cc[i1].b + cc[i2].b) / 3.0) * base
				if has_uv:
					var uu: PackedVector2Array = uv
					var uc := (uu[i0] + uu[i1] + uu[i2]) / 3.0
					var px := clampi(int(fposmod(uc.x, 1.0) * img.get_width()), 0, img.get_width() - 1)
					var py := clampi(int(fposmod(uc.y, 1.0) * img.get_height()), 0, img.get_height() - 1)
					c = c * img.get_pixel(px, py)
				c.a = 1.0
				vs.append(t * pp[i0])
				vs.append(t * pp[i1])
				vs.append(t * pp[i2])
				cs.append(c)
				cs.append(c)
				cs.append(c)
	for ch in n.get_children():
		_ed_collect(ch, t, vs, cs)


## copia un modello (.glb/.gltf) scelto dall'utente tra quelli dell'editor: in user://models (subito utilizzabile) e, se trova il progetto
## accanto all'exe, anche in godot/assets/models (cosi' finisce nelle prossime compilazioni). Ritorna il nome o "" se non riesce.
func ed_import_model(src: String) -> String:
	var ext := src.get_extension().to_lower()
	if ext != "glb" and ext != "gltf":
		return ""
	var name := src.get_file()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ED_USER_MODELS))
	if DirAccess.copy_absolute(src, ProjectSettings.globalize_path(ED_USER_MODELS) + "/" + name) != OK:
		return ""
	if ext == "gltf":      # i .gltf hanno file accanto (.bin e texture): si copiano anche quelli
		for f in DirAccess.get_files_at(src.get_base_dir()):
			if f.get_basename() == name.get_basename() and f != name:
				DirAccess.copy_absolute(src.get_base_dir() + "/" + f, ProjectSettings.globalize_path(ED_USER_MODELS) + "/" + f)
	if not OS.has_feature("editor"):
		var pd := OS.get_executable_path().get_base_dir().path_join("../godot/assets/models").simplify_path()
		if DirAccess.dir_exists_absolute(pd):
			DirAccess.copy_absolute(src, pd + "/" + name)
	else:
		DirAccess.copy_absolute(src, ProjectSettings.globalize_path(ED_MODEL_DIR) + "/" + name)
	ed_model_cache.erase(name)
	return name


## ingombro per la collisione: scatola orientata sulla parte bassa del modello (sotto 1 unita'), cosi' la chioma di un albero non blocca ma il tronco si'
func _ed_make_model(name: String, o: W3DBuilder, p: Vector2, yaw: float, sc: float, cols: Array) -> void:
	var m := ed_model(name)
	if m.is_empty():
		return
	var vs: PackedVector3Array = m["v"]
	var cs: PackedColorArray = m["c"]
	var rot := Basis(Vector3.UP, yaw)
	var bs := rot * Basis.from_scale(Vector3(sc, sc, sc))
	var org := Vector3(p.x, 0.0, p.y)
	var lo := Vector2(1e9, 1e9)
	var hi := Vector2(-1e9, -1e9)
	for i in vs.size():
		var q := vs[i]
		o.v.append(bs * q + org)
		o.c.append(o.shade(cs[i], 0.0))
		if q.y * sc < 1.0:
			lo = Vector2(minf(lo.x, q.x * sc), minf(lo.y, q.z * sc))
			hi = Vector2(maxf(hi.x, q.x * sc), maxf(hi.y, q.z * sc))
	if hi.x > lo.x:
		var half := Vector2(maxf((hi.x - lo.x) * 0.5, 0.2), maxf((hi.y - lo.y) * 0.5, 0.2))
		var cw: Vector3 = rot * Vector3((lo.x + hi.x) * 0.5, 0.0, (lo.y + hi.y) * 0.5)
		cols.append(["b", Vector2(p.x + cw.x, p.y + cw.z), half, yaw])


func ed_hide_sync() -> void:
	ed_hide_keys.clear()
	for h in ed_hide:
		ed_hide_keys[Vector2i(int(h[0]), int(h[1]))] = true


## ogni oggetto principale generato passa da qui: viene registrato (cosi' l'editor lo puo' selezionare) oppure, se l'utente
## l'ha nascosto o sostituito, generato in un contenitore di scarto: i generatori casuali avanzano come prima e il resto non cambia
func _obj(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var st := r.state
	var ost := o.rn.state
	if not ed_hide_keys.is_empty() and ed_hide_keys.has(Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))):
		var tmp := W3DBuilder.new()
		tmp.rn = o.rn
		tmp.sat = o.sat
		tmp.con = o.con
		tmp.gain = o.gain
		var hd := house_doors.duplicate()
		_ed_make(k, tmp, p, yaw, r, [], [])
		house_doors = hd
		return
	o.reg.append([k, p, yaw, st, ost])
	if k in ["barrel", "crate", "hay"]:
		o.breakables.append({"kind": k, "pos": p})
	_ed_make(k, o, p, yaw, r, cols, lamps)


# ------------------------------------------------------------------ fumo dei camini
var smoke_mat: ShaderMaterial
var smoke_mesh: PlaneMesh
var smoke_curve: Curve
var smoke_ramp: Gradient


func _make_smoke(p: Vector3, one_shot: bool = false) -> CPUParticles3D:
	if smoke_mat == null:
		smoke_mat = ShaderMaterial.new()
		smoke_mat.shader = load("res://shaders/w3d_smoke.gdshader")
		extra_mats.append(smoke_mat)
		smoke_mesh = PlaneMesh.new()
		smoke_mesh.size = Vector2(1.0, 1.0)
		smoke_mesh.material = smoke_mat
		smoke_curve = Curve.new()
		smoke_curve.add_point(Vector2(0.0, 0.4))
		smoke_curve.add_point(Vector2(1.0, 1.7))
		smoke_ramp = Gradient.new()
		smoke_ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
		smoke_ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.22), Color(1, 1, 1, 0.0)])
	var ps := CPUParticles3D.new()
	ps.mesh = smoke_mesh
	ps.amount = 6 if one_shot else 9
	ps.lifetime = 1.8 if one_shot else 4.5
	ps.preprocess = 0.0 if one_shot else 4.5
	ps.one_shot = one_shot
	ps.local_coords = true
	ps.randomness = 0.6
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.18
	ps.direction = Vector3(0.3, 1.0, 0.1)
	ps.spread = 14.0
	ps.initial_velocity_min = 0.8
	ps.initial_velocity_max = 1.3
	ps.gravity = Vector3(0.22, 0.05, 0.03)           # vento: il fumo si piega
	ps.damping_min = 0.15
	ps.damping_max = 0.3
	ps.scale_amount_min = 0.9
	ps.scale_amount_max = 1.5
	ps.scale_amount_curve = smoke_curve
	ps.color_ramp = smoke_ramp
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.position = p
	ps.emitting = true
	return ps


# ------------------------------------------------------------------ vincoli
var fence_rule := true


## c'e' acqua vera davanti alla riva: il molo (fino a 6,5 + barca) e i lati devono stare su uno specchio abbastanza grande, non in una pozza
func _water_wide(cp: Vector2, wd: Vector3) -> bool:
	var dv := Vector2(wd.x, wd.y)
	var sd := Vector2(-dv.y, dv.x)
	var hits := 0
	var tot := 0
	for k in 7:
		var dist := wd.z + 1.0 + k * 1.4
		for lat in [-4.0, 0.0, 4.0]:
			tot += 1
			if bool(edge_fn.call(cp + dv * dist + sd * lat)):
				hits += 1
	return hits >= tot - 1


func _lot_fence_flag(ix: int, iz: int) -> bool:
	return posmod(hash(Vector3i(ix, iz, seed_v + 99)), 100) < 65


## i recinti di lotti vicini non si compenetrano: fra due lotti vicini che vorrebbero un recinto vince quello con l'hash piu' basso
## (la scelta dipende solo dai piani dei lotti, quindi e' identica in qualsiasi ordine di generazione dei blocchi)
func _fence_ok(cp: Vector2) -> bool:
	if not fence_rule:
		return true
	var ix := floori(cp.x / LC)
	var iz := floori(cp.y / LC)
	if not _lot_fence_flag(ix, iz):
		return false
	var h := hash(Vector2i(ix, iz))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if dx == 0 and dz == 0:
				continue
			var np := _plan(ix + dx, iz + dz)
			if np["kind"] != "house" and np["kind"] != "yard":
				continue
			if cp.distance_to(np["cp"]) > 11.5:
				continue
			if _lot_fence_flag(ix + dx, iz + dz) and hash(Vector2i(ix + dx, iz + dz)) < h:
				return false
	return true
