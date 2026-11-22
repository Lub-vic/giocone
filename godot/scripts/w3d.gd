class_name W3D
extends Node
## Prova del motore 3D "top-down verticale, tutto poligoni": il villaggio nasce a blocchi attorno a chi cammina,
## i bordi della bolla sprofondano nel buio, il mondo si piega come un pianetino.
## Il mondo e' fatto di campi di densita' (erba, sassi, cespugli, alberi) e di lotti allineati alle strade:
## niente e' messo a caso, tutto segue le stesse regole della natura e del villaggio.
## Comandi: WASD muovi · F2/F3 curvatura · F4/F5 bolla · F6 filtro · F7 nuovo villaggio · F8 pixel · C personaggi · Esc esci.

const CHS := 24                 # lato di un blocco (unita' = 16 px del vecchio gioco)
const GS := 0.4                 # lato di una cella del terreno
const LC := 8.0                 # lato di un lotto (3x3 lotti per blocco)
const CAM_H := 29.0
const RES := [Vector2i(480, 270), Vector2i(320, 180), Vector2i(240, 135)]
const SPEED := 8.6              # il gioco 2D va a 82 px/s = 5,1 unita/s; nel 3D sembrava al rallentatore (x1,4), e con la camera piu' lontana (x1,2) si compensa
const NPC_KINDS := ["goblin", "skeleton", "ghoul", "kobold", "orc", "wolf", "goblin_archer", "skel_archer"]
const WOOD := Color(0.17, 0.115, 0.085)
const STONE := Color(0.24, 0.235, 0.25)

var seed_v := 1337
var vp: SubViewport
var cam: Camera3D
var sun: DirectionalLight3D
var mat: ShaderMaterial
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
var res_i := 1
var npcs: Array = []
var char_style := 0
var vox_cache: Dictionary = {}
var omnis: Array = []              # luci vere con ombre: le 3 piu' vicine tra torce, finestre e lanterna dell'eroe
var disc_mesh: ArrayMesh
var demo := true                 # demo giocabile: combattimento, nemici, boss, falo'
var combat: W3DCombat
var shake := 0.0
var bonfires: Array = []
var boss_pos := Vector2.ZERO
var lineup := false
var cam_h := CAM_H


func _ready() -> void:
	RenderingServer.global_shader_parameter_add("w3d_player", RenderingServer.GLOBAL_VAR_TYPE_VEC3, Vector3.ZERO)
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
		if str(arg) == "--nofx":
			nofx = true
		if str(arg) == "--noshadow":
			no_shadow = true
		if str(arg).begins_with("--bubble="):
			fade_a = float(str(arg).substr(9))
		if str(arg).begins_with("--style="):
			char_style = int(str(arg).substr(8))
	_build_view()
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
	cl.add_child(hud)
	add_child(cl)


func _build_view() -> void:
	vp = SubViewport.new()
	vp.size = RES[res_i]
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.46, 0.5) if lineup else Color(0.30, 0.32, 0.48)
	env.ambient_light_energy = 1.5 if lineup else 0.62
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.62, 0.68, 0.98)
	sun.light_energy = 1.0 if lineup else 0.66
	sun.rotation_degrees = Vector3(-36, -35, 0)
	sun.shadow_enabled = not no_shadow
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 60.0
	vp.add_child(sun)
	for i in 3:
		var ol := OmniLight3D.new()
		ol.light_color = Color(0.95, 0.8, 0.58)
		ol.omni_range = 16.0
		ol.omni_attenuation = 1.1
		ol.light_energy = 1.2
		ol.shadow_enabled = not no_shadow
		ol.shadow_bias = 0.08
		vp.add_child(ol)
		omnis.append(ol)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 38.6
	cam.near = 2.0
	cam.far = 120.0
	cam.rotation_degrees = Vector3(-90, 0, 0)
	vp.add_child(cam)
	cam.current = true
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/w3d.gdshader")
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
	pos = (bonfires[1] as Vector2) + Vector2(0, 2.6)
	_build_hero()
	if lineup:
		var gb := W3DBuilder.new()
		for gz in range(-20, 20):
			for gx in range(-20, 20):
				var x := pos.x + gx
				var z := pos.y + gz
				gb.quad(Vector3(x, 0, z), Vector3(x + 1, 0, z), Vector3(x + 1, 0, z + 1), Vector3(x, 0, z + 1), gb.shade(Color(0.17, 0.155, 0.14), 0.08))
		var gm := MeshInstance3D.new()
		gm.mesh = gb.mesh()
		gm.material_override = mat
		vp.add_child(gm)
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
func _stream(all: bool) -> void:
	if lineup:
		return
	var pc := Vector2i(floori(pos.x / CHS), floori(pos.y / CHS))
	var want: Array = []
	var rad := int(ceil((fade_a + 30.0) / CHS))
	for dz in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var k := pc + Vector2i(dx, dz)
			var ctr := Vector2((k.x + 0.5) * CHS, (k.y + 0.5) * CHS)
			var d := ctr.distance_to(pos)
			if d < fade_a + 30.0 and not chunks.has(k) and not job_keys.has(k):
				want.append([d, k])
	want.sort_custom(func(a, b): return a[0] < b[0])
	for w in want:
		_enqueue(w[1])
	if all:
		_run_jobs(1e9)
	for k in chunks.keys():
		var ctr2 := Vector2((k.x + 0.5) * CHS, (k.y + 0.5) * CHS)
		if ctr2.distance_to(pos) > fade_a + 56.0:
			(chunks[k]["node"] as Node3D).queue_free()
			chunks.erase(k)
	for i in range(jobs.size() - 1, -1, -1):
		var jk: Vector2i = jobs[i]["k"]
		if Vector2((jk.x + 0.5) * CHS, (jk.y + 0.5) * CHS).distance_to(pos) > fade_a + 56.0:
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
	jobs.append({"k": k, "x0": x0, "z0": z0, "g": g, "o": o, "v": v, "cols": [], "lamps": [], "sub": sub, "hs": [], "step": 0, "us": 0})
	job_keys[k] = true


func _run_jobs(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not jobs.is_empty():
		var j: Dictionary = jobs[0]
		var t1 := Time.get_ticks_usec()
		var done := _job_step(j)
		j["us"] = int(j["us"]) + Time.get_ticks_usec() - t1
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
		var hs: Array = []
		for jj in n + 1:
			for ii in n + 1:
				var p := Vector2(float(j["x0"]) + ii * GS, float(j["z0"]) + jj * GS)
				var rdv := _road_dist_sub(p, j["sub"])
				hs.append(_height(p, maxf(rdv.x - rdv.y * 0.5, 0.0) + 1.5))
		j["hs"] = hs
	if s <= 3:
		_ground_rows(j, s * (n / 4), (s + 1) * (n / 4))
	elif s <= 6:
		var k: Vector2i = j["k"]
		for q in 3:
			var li := (s - 4) * 3 + q
			_lot(j, k.x * 3 + li % 3, k.y * 3 + li / 3)
	elif s <= 8:
		_grass(j, s - 7)
	elif s == 9:
		_big_things(j)
	else:
		_finalize(j)
		return true
	j["step"] = s + 1
	return false


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
		if hh < 0.8 and mid.length() < 170.0:
			var tn := (segs_b[i] - segs_a[i]).normalized().orthogonal()
			var lp := mid + tn * (segs_w[i] * 0.5 + 1.0) * (1.0 if hh < 0.4 else -1.0)
			_lamp_post(o, lp, lamps, cols)
	for bp in bonfires:
		var bv: Vector2 = bp
		if bv.x >= x0 and bv.x < x0 + CHS and bv.y >= z0 and bv.y < z0 + CHS:
			_pyre(o, bv, o.rn, cols, lamps)
			for q in 5:
				var a := TAU * q / 5.0
				o.rock(Vector3(bv.x + cos(a) * 1.0, 0.18, bv.y + sin(a) * 1.0), Vector3(0.5, 0.36, 0.5), Color(0.22, 0.22, 0.24), 0.14, 0.4, a)
	var node := Node3D.new()
	node.name = "C%d_%d" % [k.x, k.y]
	var parts := [["g", false], ["v", false], ["o", true]]
	for pt in parts:
		var bld: W3DBuilder = j[pt[0]]
		if bld.v.size() == 0:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = bld.mesh()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if pt[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	vp.add_child(node)
	chunks[k] = {"node": node, "cols": cols, "lamps": lamps}


# ------------------------------------------------------------------ terreno
func _height(p: Vector2, rd: float) -> float:
	return n_h.get_noise_2d(p.x, p.y) * 0.2 * smoothstep(1.4, 3.4, rd)


func _ground_col(p: Vector2, rd: float, rw: float) -> Color:
	var a := n_soil.get_noise_2d(p.x, p.y)
	var col := Color(0.098, 0.085, 0.078)
	col = col.lerp(Color(0.05, 0.042, 0.042), clampf(-a * 1.8, 0.0, 1.0))
	col = col.lerp(Color(0.14, 0.12, 0.105), clampf((a - 0.25) * 2.0, 0.0, 0.7))
	var vg := n_veg.get_noise_2d(p.x, p.y)
	if vg > 0.1:
		col = col.lerp(Color(0.065, 0.085, 0.055), clampf((vg - 0.1) * 2.2, 0.0, 0.85))
	var st := n_stain.get_noise_2d(p.x + 400.0, p.y - 300.0)
	if st > 0.5:
		col = col.lerp(Color(0.15, 0.035, 0.035), clampf((st - 0.5) * 3.0, 0.0, 0.7))
	var edge := rw * 0.5
	if rd < edge + 0.9:
		col = col.lerp(Color(0.17, 0.15, 0.135), smoothstep(edge + 0.9, edge - 0.3, rd))
	return col


func _ground_rows(j: Dictionary, r0: int, r1: int) -> void:
	var g: W3DBuilder = j["g"]
	var sub: Array = j["sub"]
	var hs: Array = j["hs"]
	var x0: float = j["x0"]
	var z0: float = j["z0"]
	var n := int(CHS / GS)
	for jj in range(r0, r1):
		for ii in n:
			var p := Vector2(x0 + (ii + 0.5) * GS, z0 + (jj + 0.5) * GS)
			var rdv: Vector2 = _road_dist_sub(p, sub)
			var col := _ground_col(p, rdv.x, rdv.y)
			var h00: float = hs[jj * (n + 1) + ii]
			var h10: float = hs[jj * (n + 1) + ii + 1]
			var h11: float = hs[(jj + 1) * (n + 1) + ii + 1]
			var h01: float = hs[(jj + 1) * (n + 1) + ii]
			var a := Vector3(x0 + ii * GS, h00, z0 + jj * GS)
			var b := Vector3(x0 + (ii + 1) * GS, h10, z0 + jj * GS)
			var d := Vector3(x0 + (ii + 1) * GS, h11, z0 + (jj + 1) * GS)
			var e := Vector3(x0 + ii * GS, h01, z0 + (jj + 1) * GS)
			if (ii + jj) % 2 == 0:
				g.tri(a, b, d, g.shade(col, 0.07))
				g.tri(a, d, e, g.shade(col, 0.07))
			else:
				g.tri(a, b, e, g.shade(col, 0.07))
				g.tri(b, d, e, g.shade(col, 0.07))
			# ciottoli della strada principale: un sasso piatto per cella
			if rdv.x < rdv.y * 0.5 + 0.1 and rdv.y > 2.3 and p.length() < 130.0 and g.rn.randf() < 0.92:
				var sp := Vector3(p.x + g.rn.randf_range(-0.1, 0.1), _height(p, 3.0) + 0.03, p.y + g.rn.randf_range(-0.15, 0.15))
				g.rock(sp, Vector3(g.rn.randf_range(0.24, 0.4), 0.09, g.rn.randf_range(0.2, 0.36)), Color(0.19, 0.19, 0.2), 0.18, 0.25, g.rn.randf() * TAU)


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
			if v.rn.randf() > dens:
				continue
			_tuft(v, Vector3(p.x, _height(p, 3.0), p.y), dens, n_veg2.get_noise_2d(p.x + 50.0, p.y) * 0.5 + 0.5)


func _tuft(o: W3DBuilder, p: Vector3, dens: float, tone: float) -> void:
	var col := Color(0.14, 0.18, 0.09).lerp(Color(0.34, 0.30, 0.16), tone)
	col.a = 0.9
	var nb := 3 + int(dens * 2.5)
	var h0 := lerpf(0.4, 1.1, dens) * o.rn.randf_range(0.75, 1.25)
	var lean := o.rn.randf() * TAU
	for i in nb:
		var a := lean + o.rn.randf_range(-1.2, 1.2) + i * 2.1
		var dir := Vector3(cos(a), 0, sin(a))
		var side := dir.cross(Vector3.UP) * 0.075
		var hgt := h0 * o.rn.randf_range(0.6, 1.1)
		o.tri(p - side, p + side, p + dir * (0.1 + hgt * 0.35) + Vector3(0, hgt, 0), o.shade(col, 0.25))


func _bone(o: W3DBuilder, p: Vector3) -> void:
	var yaw := o.rn.randf() * TAU
	o.box(Transform3D(Basis(Vector3.UP, yaw), p), Vector3(0.5, 0.07, 0.09), Color(0.62, 0.59, 0.5), 0.1)
	if o.rn.randf() < 0.4:
		o.rock(p + Vector3(0.3, 0.1, 0.1), Vector3(0.2, 0.2, 0.2), Color(0.66, 0.63, 0.55), 0.08, 0.2, yaw)


func _free(p: Vector2, r: float, cols: Array) -> bool:
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
			v.rock(Vector3(p.x, 0.07, p.y), Vector3(rr.randf_range(0.14, 0.4), rr.randf_range(0.1, 0.24), rr.randf_range(0.14, 0.4)), Color(0.21, 0.205, 0.215), 0.14, 0.4, rr.randf() * TAU)
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
			o.rock(Vector3(p2.x, s * 0.4, p2.y), Vector3(s * 1.3, s * 0.85, s * 1.1), Color(0.19, 0.19, 0.21), 0.14, 0.45, rr.randf() * TAU)
			cols.append(["c", p2, s * 0.62])
			for q in rr.randi_range(3, 7):
				var a := rr.randf() * TAU
				var rad2 := s * rr.randf_range(0.8, 1.7)
				o.rock(Vector3(p2.x + cos(a) * rad2, 0.1, p2.y + sin(a) * rad2), Vector3(rr.randf_range(0.18, 0.5), rr.randf_range(0.14, 0.3), rr.randf_range(0.18, 0.5)), Color(0.2, 0.2, 0.22), 0.14, 0.45, rr.randf() * TAU)
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
			_bush(o, p3, rr, cols)
	st = 7.0
	for jj in int(ceil(CHS / st)):
		for ii in int(ceil(CHS / st)):
			var p4 := Vector2(x0 + (ii + rr.randf()) * st, z0 + (jj + rr.randf()) * st)
			var core := clampf(1.0 - p4.length() / 150.0, 0.0, 1.0)
			var tf := n_tree.get_noise_2d(p4.x, p4.y) * 0.5 + 0.5
			if rr.randf() > (0.15 + 0.7 * (1.0 - core)) * smoothstep(0.25, 0.6, tf):
				continue
			var rdv4 := _road_dist_sub(p4, sub)
			if rdv4.x - rdv4.y * 0.5 < 2.4 or not _free(p4, 1.0, cols):
				continue
			_dead_tree(o, p4, rr, cols)
			for q in rr.randi_range(0, 2):
				var a2 := rr.randf() * TAU
				var q2 := p4 + Vector2.from_angle(a2) * rr.randf_range(1.3, 2.6)
				if _free(q2, 0.6, cols):
					_bush(o, q2, rr, cols)
			if rr.randf() < 0.4:
				_fallen_log(o, p4 + Vector2.from_angle(rr.randf() * TAU) * rr.randf_range(2.0, 3.4), rr)
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
	if h < 0.13:
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
			_house(o, cp, yaw, r, cols, lamps)
			return
	match kind:
		"edge":
			_roadside(o, cp, tan_, toward, r, cols, float(pl["rw"]))
		"yard":
			_yard(o, cp, tan_, toward, r, cols, float(pl["core"]))
		"grave":
			_grave_lot(o, ix, iz, r, cols)
		"wild":
			var roll := r.randf()
			if roll > 0.985:
				_gallows(o, cp, r, cols)
			elif roll > 0.955:
				_pyre(o, cp, r, cols, lamps)
			elif roll > 0.9:
				_ruin(o, cp, r, cols)


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
				_barrel(o, q, r, cols)
			else:
				_crate(o, q, r, cols)
	else:
		_sign(o, cp, yaw, r, cols)


func _yard(o: W3DBuilder, cp: Vector2, tan_: Vector2, toward: Vector2, r: RandomNumberGenerator, cols: Array, core: float) -> void:
	var roll := r.randf()
	var yaw := atan2(-tan_.y, tan_.x)
	if roll < 0.2 and core > 0.15:
		_well(o, cp, r, cols)
	elif roll < 0.42:
		_hay(o, cp, r, cols)
		for i in r.randi_range(0, 2):
			_hay(o, cp + Vector2(r.randf_range(-2.5, 2.5), r.randf_range(-2.5, 2.5)), r, cols)
	elif roll < 0.62:
		_woodpile(o, cp, yaw, r, cols)
		for i in r.randi_range(1, 3):
			_barrel(o, cp + Vector2(r.randf_range(-2.5, 2.5), r.randf_range(-2.5, 2.5)), r, cols)
	elif roll < 0.78:
		var a := cp - tan_ * 2.6 - toward * 2.6
		var b := cp + tan_ * 2.6 - toward * 2.6
		var c := cp + tan_ * 2.6 + toward * 2.6
		var d := cp - tan_ * 2.6 + toward * 2.6
		_fence_run(o, a, b, r, cols, false)
		_fence_run(o, b, c, r, cols, false)
		_fence_run(o, c, d, r, cols, true)
		_fence_run(o, d, a, r, cols, false)
		_hay(o, cp, r, cols)
		_bone(o, Vector3(cp.x + 1.0, 0.05, cp.y - 0.8))
	elif roll < 0.9 and core < 0.5:
		_scarecrow(o, cp, r, cols)
	else:
		for i in r.randi_range(2, 5):
			var q := cp + Vector2(r.randf_range(-3, 3), r.randf_range(-3, 3))
			if r.randf() < 0.5:
				_crate(o, q, r, cols)
			else:
				_barrel(o, q, r, cols)


func _grave_lot(o: W3DBuilder, ix: int, iz: int, r: RandomNumberGenerator, cols: Array) -> void:
	var ox := ix * LC
	var oz := iz * LC
	var zx := posmod(ix, 3)
	var zz := posmod(iz, 3)
	for i in 4:
		for jn in 3:
			if r.randf() > 0.86:
				continue
			var q := Vector2(ox + 1.0 + i * 2.0, oz + 1.3 + jn * 2.6)
			if float(_road_near(q)["d"]) < 2.2:
				continue
			var tilt := Basis(Vector3.FORWARD, r.randf_range(-0.16, 0.16)) * Basis(Vector3.RIGHT, r.randf_range(-0.1, 0.1))
			var t := Transform3D(Basis(Vector3.UP, r.randf_range(-0.12, 0.12)) * tilt, Vector3(q.x, 0, q.y))
			o.rock(Vector3(q.x, 0.1, q.y + 0.85), Vector3(0.75, 0.2, 1.6), Color(0.14, 0.11, 0.09), 0.1, 0.18)
			var kind := r.randi() % 8
			if kind < 3:
				o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Vector3(0.62, 1.0, 0.16), Color(0.30, 0.30, 0.32), 0.14, 8)
				o.box(t * Transform3D(Basis(Vector3.FORWARD, 0.785), Vector3(0, 1.08, 0)), Vector3(0.42, 0.42, 0.16), Color(0.30, 0.30, 0.32), 0.14, 8)
			elif kind < 5:
				o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.65, 0)), Vector3(0.14, 1.3, 0.14), Color(0.24, 0.19, 0.15), 0.14, 8)
				o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(0.7, 0.14, 0.14), Color(0.24, 0.19, 0.15), 0.14, 8)
			elif kind == 5:
				o.cyl(t, 0.32, 0.12, 1.7, 4, Color(0.27, 0.27, 0.29), 0.14)
			elif kind == 6:
				o.rock(Vector3(q.x, 0.38, q.y), Vector3(0.6, 0.76, 0.5), Color(0.27, 0.27, 0.3), 0.14, 0.4, r.randf() * TAU)
			else:
				o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(0.8, 0.6, 0.18), Color(0.26, 0.26, 0.28), 0.14, 8)
			if r.randf() < 0.14:
				o.box(Transform3D(Basis.IDENTITY, Vector3(q.x + 0.5, 0.15, q.y + 0.4)), Vector3(0.1, 0.22, 0.1), Color(0.9, 0.82, 0.6, 0.15), 0.0, 8)
			if r.randf() < 0.09:
				_bone(o, Vector3(q.x - 0.5, 0.05, q.y + 1.2))
			cols.append(["c", q, 0.42])
	if zx == 0:
		_fence_run(o, Vector2(ox + 0.1, oz), Vector2(ox + 0.1, oz + LC), r, cols, false)
	if zx == 2:
		_fence_run(o, Vector2(ox + LC - 0.1, oz), Vector2(ox + LC - 0.1, oz + LC), r, cols, false)
	if zz == 0:
		_fence_run(o, Vector2(ox, oz + 0.1), Vector2(ox + LC, oz + 0.1), r, cols, false)
	if zz == 2:
		_fence_run(o, Vector2(ox, oz + LC - 0.1), Vector2(ox + LC, oz + LC - 0.1), r, cols, zx == 1)
	if (zx == 0 or zx == 2) and (zz == 0 or zz == 2):
		_dead_tree(o, Vector2(ox + (1.2 if zx == 0 else LC - 1.2), oz + (1.2 if zz == 0 else LC - 1.2)), r, cols)
	elif r.randf() < 0.3:
		_bush(o, Vector2(ox + r.randf_range(1, LC - 1), oz + r.randf_range(1, LC - 1)), r, cols)


# ------------------------------------------------------------------ casa
func _house(o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var w := r.randf_range(3.6, 4.9)
	var d := r.randf_range(4.2, 6.0)
	var wh := r.randf_range(2.1, 2.9)
	var rh := w * r.randf_range(0.45, 0.7)
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
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(0, wh * 0.5, 0)), Vector3(w - 0.3, wh, d - 0.3), Color(0.04, 0.035, 0.04), 0.0, 0)
	var apex_a: Vector3 = t0 * Vector3(0, wh + rh, -d * 0.5)
	var apex_b: Vector3 = t0 * Vector3(0, wh + rh, d * 0.5)
	for i in 4:
		var j2 := (i + 1) % 4
		var nrm := Vector3.UP.cross((bc[j2] - bc[i]).normalized()).normalized()
		var ln: float = (bc[i] - bc[j2]).length()
		o.lattice(bc[i], bc[j2], tc[i], tc[j2], maxi(2, int(ln / 2.2)), 2, base_col, 0.3, 0.22, nrm)
		if i == 0 or i == 2:
			var ap: Vector3 = apex_a if i == 0 else apex_b
			var cen: Vector3 = (tc[i] + tc[j2] + ap) / 3.0 + nrm * r.randf_range(-0.05, 0.18)
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
		o.lattice(e0, e1, r0, r1, maxi(3, int((d + 2.0 * ov) / 2.2)), 3, roof_col, 0.34, 0.34, nrm2, holes, 0.3)
		o.quad(e0 - nrm2 * 0.18, e1 - nrm2 * 0.18, r1 - nrm2 * 0.18, r0 - nrm2 * 0.18, Color(0.04, 0.035, 0.04))
	o.box(t0 * Transform3D(Basis.IDENTITY, Vector3(0, wh + rh + 0.06, 0)), Vector3(0.34, 0.26, d + 2.0 * ov), roof_col * 0.7, 0.12, 8)
	var cxl := r.randf_range(-w * 0.22, w * 0.22)
	var czl := r.randf_range(-d * 0.3, d * 0.3)
	var roof_y := wh + rh * (1.0 - absf(cxl) / (w * 0.5 + ov))
	o.cyl(t0 * Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(cxl, wh * 0.4, czl)), 0.5, 0.42, roof_y + 1.0 - wh * 0.4, 5, Color(0.22, 0.2, 0.2), 0.16)
	var dz := r.randf_range(-d * 0.5 + 1.3, d * 0.5 - 1.3)
	var ab := t0.basis
	o.box(Transform3D(ab, t0 * Vector3(w * 0.5 + 0.1, 1.0, dz)), Vector3(0.42, 2.1, 1.2), Color(0.05, 0.035, 0.035), 0.1, 8)
	o.box(Transform3D(ab, t0 * Vector3(w * 0.5 + 0.55, 0.12, dz)), Vector3(0.9, 0.24, 1.6), Color(0.24, 0.23, 0.23), 0.12, 8)
	if r.randf() < 0.85:
		var lp := t0 * Vector3(w * 0.5 + 0.5, 2.3, dz + 0.95)
		o.box(Transform3D(ab, lp), Vector3(0.24, 0.36, 0.24), Color(0.95, 0.8, 0.55, 0.2), 0.0, 8)
		lamps.append(Vector4(lp.x, lp.y, lp.z, 1.0))
	var lit := r.randf() < 0.6
	for k in 2:
		var wz := (-d * 0.25 if k == 0 else d * 0.25)
		if absf(wz - dz) < 1.5:
			continue
		var on := lit and r.randf() < 0.8
		_window(o, t0, Vector3(w * 0.5, wh * 0.58, wz), 0, on, r)
		if on:
			var wp := t0 * Vector3(w * 0.5 + 0.9, 1.4, wz)
			lamps.append(Vector4(wp.x, wp.y, wp.z, 0.55))
	if r.randf() < 0.5:
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
	for i in r.randi_range(0, 3):
		var q := Vector2(p.x, p.y) + Vector2(cos(yaw) * (w * 0.5 + 1.4), -sin(yaw) * (w * 0.5 + 1.4)) + Vector2(sin(yaw), cos(yaw)) * r.randf_range(-d * 0.45, d * 0.45) + Vector2(r.randf_range(-0.8, 0.8), r.randf_range(-0.8, 0.8))
		var kk := r.randf()
		if kk < 0.4:
			_barrel(o, q, r, cols)
		elif kk < 0.7:
			_crate(o, q, r, cols)
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
	cols.append(["c", p, 0.45])


func _crate(o: W3DBuilder, p: Vector2, r: RandomNumberGenerator, cols: Array) -> void:
	var s := r.randf_range(0.7, 1.1)
	var t := Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(p.x, s * 0.5, p.y))
	o.box(t, Vector3(s, s, s), Color(0.28, 0.2, 0.13), 0.14, 8)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, s * 0.5 + 0.02, 0)), Vector3(s * 1.04, 0.06, s * 0.2), Color(0.17, 0.12, 0.085), 0.1, 8)
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
	_sword(b, 0.82, 0.92, Color(0.72, 0.74, 0.82, 0.8))
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
	var b := W3DBuilder.new()
	var f := W3DBuilder.new()
	b.rn.seed = hash(kind)
	f.rn.seed = hash(kind) + 7
	match kind:
		"hero":
			_m_hero(b, f)
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
	sd.mesh = _disc()
	sd.material_override = mat
	sd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var body := Node3D.new()
	n.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = _vox_mesh(sname, vox)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	body.add_child(mi)
	if char_style == 0:
		var fm := _char_flow(sname)
		if fm.get_surface_count() > 0:
			var fl := Node3D.new()
			fl.position = _pivot(sname)
			var fi := MeshInstance3D.new()
			fi.mesh = fm
			fi.material_override = mat
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
	hero = _vox_node("hero", 0.075)
	hero_body = hero.get_child(0)
	for n in npcs:
		(n["node"] as Node3D).queue_free()
	npcs.clear()
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_v + 99
	if lineup:
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


# ------------------------------------------------------------------ gioco
func _blocked(p: Vector2, rr: float) -> bool:
	var pc := Vector2i(floori(p.x / CHS), floori(p.y / CHS))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := pc + Vector2i(dx, dz)
			if not chunks.has(k):
				continue
			for cl in chunks[k]["cols"]:
				if cl[0] == "c":
					if p.distance_to(cl[1]) < cl[2] + rr:
						return true
				else:
					var c: Vector2 = cl[1]
					var half: Vector2 = cl[2]
					var yw: float = cl[3]
					var dx2 := p.x - c.x
					var dz2 := p.y - c.y
					var lx := dx2 * cos(yw) - dz2 * sin(yw)
					var lz := dx2 * sin(yw) + dz2 * cos(yw)
					var qx := clampf(lx, -half.x, half.x)
					var qz := clampf(lz, -half.y, half.y)
					if Vector2(lx - qx, lz - qz).length() < rr:
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
		facing = facing.lerp(dir, 1.0 - exp(-14.0 * dt)).normalized()
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
	mat.set_shader_parameter("curve", curve)
	mat.set_shader_parameter("fade_a", fade_a)
	mat.set_shader_parameter("fade_b", fade_a + 18.0)
	post_rect.material = null if nofx else post_mat
	hud.text = "WASD muovi  SPAZIO colpo  L pesante  SHIFT rotolata  Q fiala  E falo'  ESC esci   |   F2/F3 curva %.3f  F4/F5 bolla  F6 filtro  F7 nuovo  F8 pixel  C personaggi   %d FPS" % [curve, Engine.get_frames_per_second()]
	if not shots.is_empty():
		_shot_step()


func _update_cam() -> void:
	cam.position = Vector3(pos.x + randf_range(-shake, shake) * 0.25, cam_h, pos.y + randf_range(-shake, shake) * 0.25)


func _update_lamps() -> void:
	var cand: Array = []
	for k in chunks:
		for l in chunks[k]["lamps"]:
			var lv: Vector4 = l
			cand.append([Vector2(lv.x, lv.z).distance_squared_to(pos), lv])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	if not lineup:
		cand.push_front([0.0, Vector4(pos.x, 3.2, pos.y, 0.55)])   # alone di luce attorno all'eroe
	var arr := PackedVector4Array()
	for i in 16:
		if i < cand.size():
			var lv: Vector4 = cand[i][1]
			var fl := 1.0 + sin(lamp_t * 11.0 + lv.x * 3.1) * 0.09 + sin(lamp_t * 23.0 + lv.z) * 0.05
			arr.append(Vector4(lv.x, lv.y, lv.z, lv.w * fl))
		else:
			arr.append(Vector4(0, 0, 0, 0))
	mat.set_shader_parameter("lamps", arr)
	for i in omnis.size():
		var ol: OmniLight3D = omnis[i]
		if i < cand.size():
			var lv2: Vector4 = cand[i][1]
			ol.position = Vector3(lv2.x, maxf(lv2.y, 2.0), lv2.z)
			ol.light_energy = lv2.w * 2.2 * (1.0 + sin(lamp_t * 11.0 + lv2.x * 3.1) * 0.07)
			ol.visible = true
		else:
			ol.visible = false


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
			KEY_C:
				char_style = (char_style + 1) % 3
				_build_hero()


func _shot_step() -> void:
	if shot_i >= shots.size():
		get_tree().quit()
		return
	shot_wait += 1
	if shot_wait == 1:
		if not lineup:
			pos = shots[shot_i]
		_stream(true)
		_update_cam()
	elif shot_wait == 8:
		get_viewport().get_texture().get_image().save_png("user://w3d_%d.png" % shot_i)
		shot_i += 1
		shot_wait = 0
