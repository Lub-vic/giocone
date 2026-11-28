class_name W3DUfoShow
extends RefCounted
## EFFETTI delle cutscene dell'ufo nella Radura Temporale (bolla, fulmini, vortice, quadranti, echi, faro...).
## La REGIA non e' qui: "ufo_entrata" e "ufo_uscita" sono linee del tempo in data/cutscenes.json, eseguite da W3DCine
## e modificabili con l'editor (F6), come la cinematica del rapimento. Qui ogni fotogramma si leggono le tracce:
##  attori: ufo, bolla (s = raggio), anelli (s = raggio, giro), vortice (s = grandezza, giro), bagliore, luce, faro
##  fx "cielo", "fulmini" (scariche al secondo), "ufo_fx"
##  eventi: fulmini, fulmine_gigante, anello, onda, esplosione, scintille (oltre a flash, shake, snd)

const C_CYAN := Color(0.35, 0.85, 1.0)
const C_VIOLET := Color(0.62, 0.38, 1.0)
const C_WHITE := Color(0.92, 0.98, 1.0)
const C_GOLD := Color(1.0, 0.78, 0.35)

var cine                    # W3DCine che dirige la scena
var sk                      # W3DSkin
var gm                      # Main
var t := 0.0                # orologio degli effetti: avanza anche con la timeline in pausa

var root: Node3D
var ufo: MeshInstance3D
var fx_helper: W3DCine
var center := Vector2.ZERO      # centro della radura (celle)
var ground := 0.0
var home := Vector3.ZERO        # dove l'ufo si vede durante lo scontro
var hero := Vector3.ZERO
var yaw := 0.0                  # orientamento della scena: dall'eroe verso il centro
var anchors: Dictionary = {}
var ufo_start := Vector3.ZERO
var from_cam := {}
var acc: Dictionary = {}
var free_mode := false          # effetti dentro una cutscene qualsiasi ("effetti": 1): l'ufo lo muove la timeline

var bubble: MeshInstance3D
var core: MeshInstance3D
var bubble_mat: ShaderMaterial
var core_mat: ShaderMaterial
var vortex: MeshInstance3D
var vortex_mat: ShaderMaterial
var rings: Array = []           # anelli d'orologio attorno alla bolla
var ring_mats: Array = []
var ghosts: Array = []
var ghost_mats: Array = []
var rocks: Array = []
var halo_tex: GradientTexture2D
var puff_tex: GradientTexture2D
var halo_core: MeshInstance3D
var halo_wide: MeshInstance3D
var flares: Array = []          # bagliori brevi dove cadono i fulmini
var bolt_mesh: ImmediateMesh
var bolt_node: MeshInstance3D
var bolts: Array = []           # {pts, w, col, born, life}
var shocks: Array = []          # onde d'urto sul terreno {t0, dur, r, col, w}
var strike_lights: Array = []
var core_light: OmniLight3D
var beam: MeshInstance3D
var beam_spot: MeshInstance3D
var beam_mat: StandardMaterial3D
var smoke: CPUParticles3D
var fire: CPUParticles3D
var embers: CPUParticles3D
var inflow: CPUParticles3D

var storm := 0.0
var lit := 0.0                  # lampo che schiarisce la scena
var mono := 0.0
var wave_t := -10.0
var wave_k := 0.0
var bubble_r := 0.0
var bubble_pos := Vector3.ZERO
var bubble_a := 1.0
var saved := {}
var rng := RandomNumberGenerator.new()


# ------------------------------------------------------------------ preparazione / chiusura
## serve la radura allestita (side_scroll_temporal_begin): calcola le ancore della scena e crea gli effetti
func setup(c) -> bool:
	cine = c
	sk = c.sk
	gm = c.gm
	if not is_instance_valid(sk.side_scroll_temporal_ufo):
		return false
	ufo = sk.side_scroll_temporal_ufo as MeshInstance3D
	rng.seed = 77
	fx_helper = W3DCine.new()
	fx_helper.sk = sk
	fx_helper.gm = gm
	# l'ufo usa una copia del materiale del mondo: niente curvatura, cosi' sta esattamente dove sono bolla, laser e fulmini
	var um := ufo.material_override as ShaderMaterial
	um.set_shader_parameter("curve", 0.0)
	um.set_shader_parameter("fade_a", 90.0)
	um.set_shader_parameter("fade_b", 110.0)
	center = sk.side_scroll_temporal_center
	ground = sk.elev_at(center.x, center.y)
	home = Vector3(center.x, ground * 2.0 + W3DSkin.TEMPORAL_UFO_HEIGHT, center.y)   # lo shader del mondo aggiunge la quota ai vertici
	var hp: Vector2 = gm.player.position / Game.TS
	hero = Vector3(hp.x, sk.elev_at(hp.x, hp.y), hp.y)
	var d := Vector3(center.x - hp.x, 0.0, center.y - hp.y)
	var side := d.normalized() if d.length() > 1.5 else Vector3(0, 0, -1)
	yaw = atan2(-side.x, -side.z)
	ufo_start = ufo.position
	var cm: Camera3D = sk.cam
	from_cam = {"p": cm.position, "rot": cm.rotation, "fov": cm.fov}
	var hh: float = (W3DSkin.CAM_H_WORLD_FAR if sk.world_zoom_far else W3DSkin.CAM_H_WORLD)
	var focus := center.lerp(Vector2(hero.x, hero.z), 0.5)
	var fg: float = sk.elev_at(focus.x, focus.y)
	var fight_p := Vector3(focus.x, fg + 20.0, focus.y + 24.0)
	var fight_rot := Basis.looking_at(Vector3(focus.x, fg + 3.5, focus.y) - fight_p, Vector3.UP).get_euler()
	anchors = {
		"C": {"p": Vector3(center.x, ground, center.y), "yaw": yaw},          # centro della radura, a terra
		"E": {"p": hero, "yaw": yaw},                                          # eroe
		"T": {"p": home, "yaw": yaw},                                          # posto dell'ufo in cielo
		# inquadrature del gioco (nelle chiavi della camera con "auto" = 1 danno anche angolo e zoom)
		"G": {"p": from_cam["p"], "yaw": 0.0, "rot": from_cam["rot"], "fov": from_cam["fov"]},    # quella di partenza
		"L": {"p": fight_p, "yaw": 0.0, "rot": fight_rot, "fov": 38.6},                            # quella dello scontro
		"R": {"p": Vector3(hero.x, hh + sk.elev_y, hero.z), "yaw": 0.0, "rot": Vector3(-PI * 0.5, 0, 0), "fov": 38.6},   # di nuovo sopra l'eroe
	}
	saved = {"bg": sk.env.background_color}
	_build()
	sk.dust.visible = false
	return true


## effetti per una cutscene qualsiasi: serve solo il centro (ancora "centro" della cutscene, di norma P0)
func setup_free(c) -> void:
	cine = c
	sk = c.sk
	gm = c.gm
	free_mode = true
	rng.seed = 131
	fx_helper = W3DCine.new()
	fx_helper.sk = sk
	fx_helper.gm = gm
	var an: Dictionary = cine.ref(str(cine.cut.get("centro", "P0")))
	var p: Vector3 = an["p"]
	center = Vector2(p.x, p.z)
	ground = p.y
	home = p + Vector3(0, 12.0, 0)
	saved = {"bg": sk.env.background_color}
	_build()
	sk.dust.visible = false


## outro = la scena finisce con l'ufo scomparso
func cleanup(cid: String) -> void:
	if not free_mode and is_instance_valid(ufo):
		ufo.position = ufo_start
		ufo.rotation = Vector3.ZERO
		ufo.scale = Vector3.ONE * 0.8
		ufo.visible = cid != "ufo_uscita"
	if is_instance_valid(root):
		root.queue_free()
	sk.env.background_color = saved["bg"]
	var pm: ShaderMaterial = sk.post_mat
	for k in ["storm", "lit", "mono", "warp_k", "wave_k"]:
		pm.set_shader_parameter(k, 0.0)
	pm.set_shader_parameter("fisheye", W3DSkin.TEMPORAL_FISHEYE if cid == "ufo_entrata" and not free_mode else 0.0)
	sk.cam.fov = 38.6
	sk._mp("near_cut", 0.0)
	sk.dust.visible = true


## salto sulla timeline (editor): via fulmini, onde e lampi rimasti a mezz'aria
func reset() -> void:
	bolts.clear()
	shocks.clear()
	acc.clear()
	wave_t = -10.0
	lit = 0.0
	for sl in strike_lights:
		sl["e"] = 0.0
	for fl in flares:
		fl["a"] = 0.0


# ------------------------------------------------------------------ costruzione
func _add_mat(col: Color, tex: Texture2D = null, billboard := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = col
	m.disable_fog = true
	if tex != null:
		m.albedo_texture = tex
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
	return m


func _mi(mesh: Mesh, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else root).add_child(mi)
	return mi


func _halo(col: Color) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	return _mi(q, _add_mat(col, halo_tex, true))


func _light(col: Color, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng_m
	l.omni_attenuation = 0.8
	l.light_energy = 0.0
	root.add_child(l)
	return l


func _shader_mat(path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	return m


func _build() -> void:
	root = Node3D.new()
	root.name = "UfoShow"
	sk.vp.add_child(root)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.22, 0.55, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0.0)])
	halo_tex = GradientTexture2D.new()
	halo_tex.gradient = g
	halo_tex.fill = GradientTexture2D.FILL_RADIAL
	halo_tex.fill_from = Vector2(0.5, 0.5)
	halo_tex.fill_to = Vector2(1.0, 0.5)
	halo_tex.width = 128
	halo_tex.height = 128

	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 64
	sph.rings = 40
	core_mat = _shader_mat("res://shaders/w3d_time_core.gdshader")
	core = _mi(sph, core_mat)
	bubble_mat = _shader_mat("res://shaders/w3d_time_bubble.gdshader")
	bubble = _mi(sph, bubble_mat)
	var vq := QuadMesh.new()
	vq.size = Vector2(1, 1)
	vortex_mat = _shader_mat("res://shaders/w3d_time_vortex.gdshader")
	vortex = _mi(vq, vortex_mat)

	# tre quadranti d'orologio che ruotano su assi diversi
	for i in 3:
		var holder := Node3D.new()
		root.add_child(holder)
		var col: Color = [C_CYAN, C_GOLD, C_VIOLET][i]
		var mat := _add_mat(Color(col.r, col.g, col.b, 0.75))
		var tor := TorusMesh.new()
		tor.inner_radius = 0.986
		tor.outer_radius = 1.0
		tor.rings = 128
		tor.ring_segments = 6
		_mi(tor, mat, holder)
		var tor2 := TorusMesh.new()
		tor2.inner_radius = 0.912
		tor2.outer_radius = 0.918
		tor2.rings = 128
		tor2.ring_segments = 4
		_mi(tor2, mat, holder)
		var n := 60
		for k in n:
			var a := TAU * k / n
			var bm := BoxMesh.new()
			var big := k % 5 == 0
			bm.size = Vector3(0.085 if big else 0.04, 0.006, 0.016 if big else 0.007)
			var tick := _mi(bm, mat, holder)
			tick.position = Vector3(cos(a) * 0.95, 0.0, sin(a) * 0.95)
			tick.rotation.y = -a
		rings.append(holder)
		ring_mats.append(mat)

	# echi: copie spettrali dell'ufo, sfasate nel tempo
	for i in 4:
		var gm2 := _add_mat(Color(0.3, 0.75, 1.0, 0.0) if i % 2 == 0 else Color(0.65, 0.35, 1.0, 0.0))
		gm2.vertex_color_use_as_albedo = false
		gm2.cull_mode = BaseMaterial3D.CULL_BACK
		var gh := _mi(W3DCine.ufo_mesh(), gm2)
		gh.visible = false
		ghosts.append(gh)
		ghost_mats.append(gm2)

	# pietre e zolle che si staccano da terra
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color(0.22, 0.2, 0.2)
	rock_mat.roughness = 1.0
	for i in 70:
		var bx := BoxMesh.new()
		var s := rng.randf_range(0.07, 0.3)
		bx.size = Vector3(s, s * rng.randf_range(0.6, 1.2), s * rng.randf_range(0.6, 1.3))
		var r := _mi(bx, rock_mat)
		var a := rng.randf() * TAU
		var dist := rng.randf_range(1.5, 11.0)
		var x := center.x + cos(a) * dist
		var z := center.y + sin(a) * dist
		var base := Vector3(x, sk.elev_at(x, z) + s * 0.3, z)
		r.position = base
		r.visible = false
		rocks.append({"n": r, "base": base, "h": rng.randf_range(1.0, 7.5), "d": rng.randf(), "sp": Vector3(rng.randf_range(-2, 2), rng.randf_range(-2, 2), rng.randf_range(-2, 2))})

	halo_wide = _halo(Color(0.3, 0.45, 1.0, 0.0))
	halo_core = _halo(Color(0.75, 0.95, 1.0, 0.0))
	bolt_mesh = ImmediateMesh.new()
	bolt_node = _mi(bolt_mesh, _add_mat(Color.WHITE))
	bolt_node.custom_aabb = AABB(Vector3(center.x - 80, -40, center.y - 80), Vector3(160, 120, 160))
	for i in 6:
		strike_lights.append({"l": _light(C_CYAN, 13.0), "e": 0.0})
		var fl := _halo(Color(0.55, 0.85, 1.0, 0.0))
		flares.append({"n": fl, "a": 0.0, "s": 3.0})
	core_light = _light(C_CYAN, 30.0)

	var bc := CylinderMesh.new()
	bc.top_radius = 0.18
	bc.bottom_radius = 1.0
	bc.height = 1.0
	bc.radial_segments = 32
	bc.cap_top = false
	bc.cap_bottom = false
	beam_mat = _add_mat(Color(0.55, 0.9, 1.0, 0.0))
	beam = _mi(bc, beam_mat)
	beam.visible = false
	beam_spot = _halo(Color(0.55, 0.9, 1.0, 0.0))
	beam_spot.visible = false

	var pg := Gradient.new()
	pg.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	pg.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	puff_tex = halo_tex.duplicate()
	puff_tex.gradient = pg
	smoke = _puffs(Color(0.07, 0.065, 0.09, 0.6), Color(0.16, 0.16, 0.2, 0.0), 90, 2.2, 0.6, 2.2, 1.4, 3.4, false, 1.2)
	fire = _puffs(Color(1.0, 0.72, 0.28, 0.75), Color(0.9, 0.18, 0.03, 0.0), 70, 0.55, 0.8, 3.0, 0.7, 1.6, true, 1.5)
	embers = fx_helper._emitter(Color(0.7, 0.95, 1.0, 0.9), Color(0.5, 0.3, 1.0, 0.0), 160, 3.4, 0.1, 1.2, 0.05, 0.14, true, -0.9)
	embers.spread = 180.0
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 8.0
	root.add_child(embers)
	inflow = fx_helper._emitter(Color(0.5, 0.75, 1.0, 0.0), Color(0.85, 0.97, 1.0, 0.95), 240, 0.8, 0.0, 0.0, 0.06, 0.16, true, 0.0)
	inflow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	inflow.emission_sphere_radius = 11.0
	inflow.radial_accel_min = -34.0
	inflow.radial_accel_max = -24.0
	inflow.local_coords = true
	root.add_child(inflow)


## particelle morbide sempre rivolte alla camera (fumo e fiamme)
func _puffs(col0: Color, col1: Color, amount: int, life: float, vmin: float, vmax: float, s0: float, s1: float, add: bool, grav: float) -> CPUParticles3D:
	var e := fx_helper._emitter(col0, col1, amount, life, vmin, vmax, s0, s1, add, grav)
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var m := _add_mat(Color.WHITE, puff_tex)
	if not add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	q.material = m
	e.mesh = q
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(e)
	return e


## schegge incandescenti allungate nella direzione di volo
func _sparks(col0: Color, col1: Color, amount: int, life: float, vmin: float, vmax: float, grav: float) -> CPUParticles3D:
	var e := fx_helper._emitter(col0, col1, amount, life, vmin, vmax, 0.5, 1.2, true, grav)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.55, 0.05)
	bm.material = _add_mat(Color.WHITE)
	e.mesh = bm
	e.particle_flag_align_y = true
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(e)
	return e


func _burst(e: CPUParticles3D, p: Vector3) -> void:
	e.position = p
	e.one_shot = true
	e.explosiveness = 0.95
	e.spread = 180.0
	e.emitting = true


func _boom(p: Vector3, s: float) -> void:
	_burst(_puffs(Color(1.0, 0.82, 0.42, 0.9), Color(0.8, 0.14, 0.03, 0.0), 26, 0.7, 3.0 * s, 11.0 * s, 1.6 * s, 3.8 * s, true, -1.0), p)
	_burst(_puffs(Color(0.1, 0.08, 0.09, 0.55), Color(0.16, 0.16, 0.2, 0.0), 18, 1.7, 1.5 * s, 5.0 * s, 2.0 * s, 4.4 * s, false, 0.8), p)
	_burst(_sparks(Color(1.0, 0.93, 0.65, 1.0), Color(1.0, 0.35, 0.05, 0.0), int(70.0 * s) + 20, 1.0, 9.0 * s, 24.0 * s, -15.0), p)
	_hit_fx(p, Color(1.0, 0.62, 0.3), 1.0)


## saetta che scende dallo squarcio nel cielo e colpisce la bolla
func _sky_bolt(c: Vector3, r: float, w := 0.2) -> void:
	var cm: Camera3D = sk.cam
	var from := c + cm.basis.x * rng.randf_range(-1.0, 1.0) * r * 3.0 + cm.basis.y * rng.randf_range(r * 1.6, r * 3.2) - cm.basis.z * rng.randf_range(0.0, 4.0)
	var to := c + (from - c).normalized() * r
	_add_bolt(from, to, w, C_CYAN if rng.randf() < 0.6 else C_VIOLET, rng.randf_range(0.14, 0.24), 3)


## scarica che schizza dal bordo della bolla verso l'esterno, sul piano dell'inquadratura
func _flare_bolt(c: Vector3, r: float) -> void:
	var cm: Camera3D = sk.cam
	var a := rng.randf() * TAU
	var dirv := cm.basis.x * cos(a) + cm.basis.y * sin(a)
	var from := c + dirv * r * 1.0
	var to := c + (dirv + _rv(0.35)).normalized() * r * rng.randf_range(1.7, 2.6)
	_add_bolt(from, to, rng.randf_range(0.07, 0.14), C_CYAN if rng.randf() < 0.55 else C_VIOLET, rng.randf_range(0.1, 0.18), 2)


# ------------------------------------------------------------------ utilita'
func _snd(n: String, vol := 0.0) -> void:
	if gm.sfx_node != null:
		gm.sfx_node.play(n, vol)


static func _ss(a: float, b: float, x: float) -> float:
	var q := clampf((x - a) / (b - a), 0.0, 1.0)
	return q * q * (3.0 - 2.0 * q)


func _wave(k := 1.0) -> void:
	wave_t = t
	wave_k = k


func _rv(r: float) -> Vector3:
	return Vector3(rng.randf_range(-r, r), rng.randf_range(-r, r), rng.randf_range(-r, r))


func _ground_at(x: float, z: float) -> Vector3:
	return Vector3(x, sk.elev_at(x, z) + 0.1, z)


func _jag(a: Vector3, b: Vector3, rough: float, levels: int) -> PackedVector3Array:
	var pts := PackedVector3Array([a, b])
	var amp := a.distance_to(b) * rough
	for lv in levels:
		var out := PackedVector3Array()
		for i in pts.size() - 1:
			out.append(pts[i])
			out.append((pts[i] + pts[i + 1]) * 0.5 + _rv(amp))
		out.append(pts[pts.size() - 1])
		pts = out
		amp *= 0.52
	return pts


func _add_bolt(a: Vector3, b: Vector3, w: float, col: Color, life: float, branches := 2) -> void:
	var pts := _jag(a, b, 0.14, 5)
	bolts.append({"pts": pts, "w": w, "col": col, "born": t, "life": life})
	var d := (b - a)
	for i in branches:
		var k := rng.randi_range(4, pts.size() - 8)
		var s: Vector3 = pts[k]
		var e := s + d.normalized() * d.length() * rng.randf_range(0.14, 0.34) + _rv(d.length() * 0.2)
		bolts.append({"pts": _jag(s, e, 0.16, 4), "w": w * 0.45, "col": col, "born": t, "life": life * 0.8})


## fulmine dalla superficie della bolla fino al terreno, con luce vera e bagliore nel punto colpito
func _strike(from: Vector3, rmin: float, rmax: float, w := 0.11, sound := false) -> void:
	var a := rng.randf() * TAU
	var d := rng.randf_range(rmin, rmax)
	var hit := _ground_at(from.x + cos(a) * d, from.z + sin(a) * d)
	var start_p := from + (hit - from).normalized() * bubble_r * 0.95
	var col := C_CYAN if rng.randf() < 0.65 else C_VIOLET
	_add_bolt(start_p, hit, w, col, rng.randf_range(0.14, 0.26))
	_hit_fx(hit, col, 1.0)
	if sound:
		_snd("zap", rng.randf_range(-6.0, 0.0))


func _hit_fx(hit: Vector3, col: Color, power: float) -> void:
	var slot := 0
	for i in strike_lights.size():
		if float(strike_lights[i]["e"]) < float(strike_lights[slot]["e"]):
			slot = i
	var sl: Dictionary = strike_lights[slot]
	sl["e"] = 5.0 * power
	(sl["l"] as OmniLight3D).position = hit + Vector3(0, 1.4, 0)
	(sl["l"] as OmniLight3D).light_color = col
	var fl: Dictionary = flares[slot]
	fl["a"] = 0.9
	fl["s"] = 3.2 * power
	(fl["n"] as MeshInstance3D).position = hit + Vector3(0, 0.35, 0)
	lit = maxf(lit, 0.22 * power)


## scariche che strisciano sulla superficie della bolla
func _arcs(r: float, n: int) -> void:
	for i in n:
		var a := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		var b := (a + Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized() * 0.9).normalized()
		var pts := PackedVector3Array()
		for k in 15:
			var q := a.slerp(b, float(k) / 14.0) if a.dot(b) > -0.98 else a
			pts.append(bubble_pos + (q * r * 1.02) + _rv(r * 0.045))
		bolts.append({"pts": pts, "w": 0.045, "col": C_CYAN if rng.randf() < 0.7 else C_WHITE, "born": t, "life": 0.09})


func _ribbon(pts: PackedVector3Array, w: float, col: Color, taper: bool, cam_p: Vector3, flat := false) -> void:
	var n := pts.size()
	if n < 2:
		return
	var sides := PackedVector3Array()
	for i in n:
		var dirv := pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		var look := Vector3.UP if flat else (cam_p - pts[i])
		var s := dirv.cross(look).normalized()
		var k := (1.0 - 0.75 * float(i) / float(n - 1)) if taper else 1.0
		sides.append(s * w * k * 0.5)
	for i in n - 1:
		var a := pts[i] + sides[i]
		var b := pts[i] - sides[i]
		var c := pts[i + 1] + sides[i + 1]
		var d := pts[i + 1] - sides[i + 1]
		for v in [a, b, c, c, b, d]:
			bolt_mesh.surface_set_color(col)
			bolt_mesh.surface_add_vertex(v)


func _circle(c: Vector3, r: float, n := 96) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(_ground_at(c.x + cos(a) * r, c.z + sin(a) * r))
	return pts


func _draw_bolts(scorch := 0.0) -> void:
	var cam_p: Vector3 = sk.cam.position
	bolt_mesh.clear_surfaces()
	for i in range(bolts.size() - 1, -1, -1):
		if t - float(bolts[i]["born"]) > float(bolts[i]["life"]):
			bolts.remove_at(i)
	for i in range(shocks.size() - 1, -1, -1):
		if t - float(shocks[i]["t0"]) > float(shocks[i]["dur"]):
			shocks.remove_at(i)
	if bolts.is_empty() and shocks.is_empty() and scorch <= 0.01:
		return
	bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in bolts:
		var k := 1.0 - (t - float(b["born"])) / float(b["life"])
		var fl := (0.55 + 0.45 * rng.randf()) * clampf(k * 1.6, 0.0, 1.0)
		var col: Color = b["col"]
		var w: float = b["w"]
		_ribbon(b["pts"], w * 9.0, Color(col.r, col.g, col.b, 0.13 * fl), true, cam_p)
		_ribbon(b["pts"], w * 3.4, Color(col.r, col.g, col.b, 0.5 * fl), true, cam_p)
		_ribbon(b["pts"], w * 1.3, Color(0.94, 0.98, 1.0, fl), true, cam_p)
	for s in shocks:
		var q := (t - float(s["t0"])) / float(s["dur"])
		var e := 1.0 - pow(1.0 - clampf(q, 0.0, 1.0), 3.0)
		var col2: Color = s["col"]
		var pts := _circle(s.get("at", Vector3(center.x, 0, center.y)), maxf(float(s["r"]) * e, 0.05))
		_ribbon(pts, float(s["w"]) * (1.0 - q * 0.6), Color(col2.r, col2.g, col2.b, 0.7 * (1.0 - q)), false, cam_p, true)
		_ribbon(pts, float(s["w"]) * 4.0, Color(col2.r, col2.g, col2.b, 0.16 * (1.0 - q)), false, cam_p, true)
	if scorch > 0.01:
		# l'impronta del tempo bruciata nell'erba: un quadrante con le lancette ferme
		var c := Vector3(center.x, 0, center.y)
		_ribbon(_circle(c, 6.2), 0.16, Color(0.4, 0.85, 1.0, 0.8 * scorch), false, cam_p, true)
		_ribbon(_circle(c, 5.3), 0.07, Color(0.65, 0.45, 1.0, 0.7 * scorch), false, cam_p, true)
		for h in 12:
			var a := TAU * h / 12.0
			var p0 := _ground_at(center.x + cos(a) * 5.35, center.y + sin(a) * 5.35)
			var p1 := _ground_at(center.x + cos(a) * (4.4 if h % 3 == 0 else 4.85), center.y + sin(a) * (4.4 if h % 3 == 0 else 4.85))
			_ribbon(PackedVector3Array([p0, p1]), 0.16, Color(0.5, 0.9, 1.0, 0.85 * scorch), false, cam_p, true)
		for hand in [[-1.5708, 3.9, 0.2], [0.55, 2.6, 0.28]]:
			var hp := PackedVector3Array()
			for k in 9:
				var rr: float = float(hand[1]) * k / 8.0
				hp.append(_ground_at(center.x + cos(float(hand[0])) * rr, center.y + sin(float(hand[0])) * rr))
			_ribbon(hp, float(hand[2]), Color(1.0, 0.85, 0.5, 0.85 * scorch), false, cam_p, true)
	bolt_mesh.surface_end()


## posizione "visibile" -> posizione del nodo dell'ufo (lo shader aggiunge la quota sotto di lui)
func _place_ufo(vis: Vector3, rot: Vector3, sc: Vector3) -> void:
	ufo.position = vis - Vector3(0, sk.elev_at(vis.x, vis.z), 0)
	ufo.basis = Basis.from_euler(rot) * Basis.from_scale(sc.max(Vector3.ONE * 0.001))


func _ghost(i: int, vis: Vector3, rot: Vector3, sc: Vector3, a: float) -> void:
	var gh: MeshInstance3D = ghosts[i]
	gh.visible = a > 0.01
	gh.position = vis
	gh.basis = Basis.from_euler(rot) * Basis.from_scale(sc.max(Vector3.ONE * 0.001))
	var m: StandardMaterial3D = ghost_mats[i]
	m.albedo_color.a = a


func _set_bubble(pos3: Vector3, r: float, a: float, power: float) -> void:
	bubble_pos = pos3
	bubble_r = r
	bubble_a = a
	var vis := r > 0.05 and a > 0.01
	bubble.visible = vis
	core.visible = vis
	bubble.position = pos3
	core.position = pos3
	bubble.scale = Vector3.ONE * maxf(r, 0.01)
	core.scale = Vector3.ONE * maxf(r * 0.97, 0.01)
	bubble_mat.set_shader_parameter("alpha", a)
	bubble_mat.set_shader_parameter("power", power)
	bubble_mat.set_shader_parameter("tm", t)
	core_mat.set_shader_parameter("alpha", a)


func _set_rings(pos3: Vector3, r: float, a: float, spin: float) -> void:
	for i in rings.size():
		var h: Node3D = rings[i]
		h.visible = a > 0.01 and r > 0.1
		var tilt := Basis(Vector3.RIGHT, [1.25, 0.35, -0.85][i] + sin(t * 0.9 + i) * 0.28)
		var prec := Basis(Vector3.UP, spin * [0.22, -0.31, 0.4][i] + i * 2.1)
		var turn := Basis(Vector3.UP, spin * [1.0, -1.5, 2.1][i])
		h.basis = prec * tilt * turn * Basis.from_scale(Vector3.ONE * maxf(r * [1.22, 1.42, 1.66][i], 0.01))
		h.position = pos3
		(ring_mats[i] as StandardMaterial3D).albedo_color.a = 0.7 * a


func _set_glow(pos3: Vector3, a: float, size: float) -> void:
	halo_core.position = pos3
	halo_wide.position = pos3
	halo_core.scale = Vector3.ONE * maxf(size, 0.01)
	halo_wide.scale = Vector3.ONE * maxf(size * 3.2, 0.01)
	(halo_core.material_override as StandardMaterial3D).albedo_color.a = clampf(a, 0.0, 1.0)
	(halo_wide.material_override as StandardMaterial3D).albedo_color.a = clampf(a * 0.5, 0.0, 1.0)


func _set_vortex(pos3: Vector3, size: float, a: float, spin: float) -> void:
	var cm: Camera3D = sk.cam
	vortex.visible = a > 0.01
	var away := (pos3 - cm.position).normalized()
	vortex.position = pos3 + away * 9.0
	vortex.basis = cm.basis * Basis.from_scale(Vector3.ONE * maxf(size, 0.01))
	vortex_mat.set_shader_parameter("alpha", a)
	vortex_mat.set_shader_parameter("spin", spin)


## k = quanto sono sollevate; suck = quanto sono risucchiate verso il punto "to"
func _set_rocks(k: float, fall: float, suck := 0.0, to := Vector3.ZERO) -> void:
	for r in rocks:
		var n: MeshInstance3D = r["n"]
		var lift := _ss(float(r["d"]) * 0.55, float(r["d"]) * 0.55 + 0.45, k)
		n.visible = lift > 0.01 and fall < 0.999
		var base: Vector3 = r["base"]
		var y := lift * float(r["h"]) * (1.0 - fall * fall) + sin(t * 2.2 + float(r["d"]) * 20.0) * 0.18 * lift * (1.0 - fall)
		var p := base + Vector3(0, maxf(y, 0.0), 0)
		var sq := _ss(float(r["d"]) * 0.4, float(r["d"]) * 0.4 + 0.6, suck)
		if sq > 0.0:
			p = p.lerp(to, sq * sq)
			n.visible = n.visible and sq < 0.97
		n.position = p
		n.rotation = (r["sp"] as Vector3) * (t * lift * (1.0 - fall) + sq * 3.0)


# ------------------------------------------------------------------ lettura delle tracce di W3DCine
## valori di una traccia "fx" all'istante T (i campi mancanti valgono 0)
func _values(track: String, T: float) -> Dictionary:
	var s: Array = cine.seg(cine.cut.get("fx", {}).get(track, []), T)
	var out := {}
	if s[0] == null:
		return out
	var a: Dictionary = s[0]
	if s[1] == null:
		if T < float(a["t"]):
			return out
		return a
	var b: Dictionary = s[1]
	for k in a:
		if a[k] is float or a[k] is int:
			out[k] = lerpf(float(a[k]), float(b.get(k, a[k])), float(s[2]))
	return out


## stato di un attore all'istante T: nodo (posizione, rotazione, scala gia' calcolate da W3DCine) + campi extra
func _actor(n: String, T: float) -> Dictionary:
	var s: Array = cine.seg(cine.cut["act"].get(n, []), T)
	if s[0] == null or not cine.acts.has(n):
		return {"on": false, "p": home, "s": 0.0, "al": 0.0, "giro": 0.0, "forza": 1.0, "alto": 1.0, "rot": Vector3.ZERO}
	var a: Dictionary = s[0]
	var node: Node3D = cine.acts[n]
	var out := {"on": node.visible and T >= float(a["t"]), "p": node.position, "rot": node.rotation}
	for k in ["s", "al", "giro", "forza", "alto"]:
		var dflt := 1.0 if k in ["s", "forza", "alto"] else 0.0
		var v := float(a.get(k, dflt))
		if s[1] != null:
			v = lerpf(v, float((s[1] as Dictionary).get(k, v)), float(s[2]))
		out[k] = v
	return out


## posizione, rotazione e scala di un attore in un istante qualsiasi (per gli echi nel passato)
func _pose(n: String, T: float) -> Dictionary:
	var s: Array = cine.seg(cine.cut["act"].get(n, []), T)
	var a: Dictionary = s[0]
	var pa: Dictionary = cine.kpos(a)
	var p: Vector3 = pa["p"]
	var rot := W3DCine.v3(a.get("r", [0, 0, 0])) + Vector3(0, pa["yaw"], 0)
	var sc := float(a.get("s", 1.0))
	if s[1] != null:
		var b: Dictionary = s[1]
		var pb: Dictionary = cine.kpos(b)
		var w: float = s[2]
		p = p.lerp(pb["p"], w)
		rot = rot.lerp(W3DCine.v3(b.get("r", [0, 0, 0])) + Vector3(0, pb["yaw"], 0), w)
		sc = lerpf(sc, float(b.get("s", 1.0)), w)
	return {"p": p, "rot": rot, "s": sc}


## quante scariche far partire in questo fotogramma, dato il numero al secondo
func _count(name: String, rate: float, dt: float) -> int:
	if rate <= 0.05:
		acc[name] = 0.7
		return 0
	acc[name] = float(acc.get(name, 0.7)) + rate * dt * rng.randf_range(0.4, 1.6)
	var n := int(acc[name])
	acc[name] -= n
	return mini(n, 4)


## nella radura l'ufo (quello vero dello scontro) e i suoi echi li muove la libreria
func _radura_ufo(T: float, ux: Dictionary) -> Vector3:
	var u := _actor("ufo", T)
	var shown: bool = u["on"]
	if shown and rng.randf() < float(ux.get("sfarfallio", 0.0)):
		shown = false
	var uv: Vector3 = (u["p"] as Vector3) + _rv(float(ux.get("tremito", 0.0)))
	var sc: float = 0.8 * float(u["s"])
	var scale3 := Vector3(sc, sc * float(u["alto"]), sc)
	ufo.visible = shown
	_place_ufo(uv, u["rot"], scale3)
	var echo := float(ux.get("echi", 0.0))
	var spread := float(ux.get("eco_scala", 0.0))
	for i in ghosts.size():
		if echo <= 0.01:
			_ghost(i, uv, u["rot"], scale3, 0.0)
			continue
		var past := _pose("ufo", T - (i + 1) * 0.13)
		var gs: float = 0.8 * float(past["s"]) * (1.0 + spread * (i + 1) * 0.24)
		_ghost(i, past["p"], past["rot"], Vector3(gs, gs * float(u["alto"]), gs), echo * 0.32 * (1.0 - i * 0.2))
	return uv


## chiamata da W3DCine a ogni fotogramma, dopo gli attori
func apply(T: float, dt: float) -> void:
	if not is_instance_valid(root) or (not free_mode and not is_instance_valid(ufo)):
		return
	t += dt
	lit = maxf(0.0, lit - dt * 2.8)
	var cl := _values("cielo", T)
	var fu := _values("fulmini", T)
	var ux := _values("ufo_fx", T)
	storm = float(cl.get("tempesta", 0.0))
	mono = float(cl.get("tempo_fermo", 0.0))
	sk.post_mat.set_shader_parameter("fisheye", W3DSkin.TEMPORAL_FISHEYE * float(cl.get("lente", 0.0)))

	var uv := home
	if free_mode:
		if cine.acts.has("ufo"):
			var un: Node3D = cine.acts["ufo"]
			uv = un.position + Vector3(0, sk.elev_at(un.position.x, un.position.z), 0)
	else:
		uv = _radura_ufo(T, ux)

	# --- bolla, quadranti, vortice, bagliore e luce
	var b := _actor("bolla", T)
	var r: float = float(b["s"]) if b["on"] else 0.0
	r *= 1.0 + sin(t * 13.0) * 0.012 + sin(t * 31.0) * 0.008
	_set_bubble(b["p"], r, float(b["al"]), float(b["forza"]))
	var an := _actor("anelli", T)
	_set_rings(an["p"], float(an["s"]), float(an["al"]) if an["on"] else 0.0, float(an["giro"]))
	var vo := _actor("vortice", T)
	_set_vortex(vo["p"], float(vo["s"]), float(vo["al"]) if vo["on"] else 0.0, float(vo["giro"]))
	var gl := _actor("bagliore", T)
	var ga: float = float(gl["al"]) if gl["on"] else 0.0
	_set_glow(gl["p"], ga * (0.82 + 0.18 * sin(t * 29.0)), float(gl["s"]))
	var lu := _actor("luce", T)
	core_light.position = bubble_pos + Vector3(0, -2.5, 0)
	core_light.light_energy = (float(lu["al"]) if lu["on"] else 0.0) * (1.0 + 0.3 * sin(t * 23.0))
	if r <= 0.05 and ga > 0.01:
		bubble_pos = gl["p"]

	lit = maxf(lit, float(cl.get("chiarore", 0.0)))
	_set_rocks(float(cl.get("pietre", 0.0)), float(cl.get("caduta", 0.0)), float(cl.get("risucchio", 0.0)), home)
	if not free_mode:
		_beam(T, uv)

	# --- fulmini (numeri al secondo)
	var anchor_p: Vector3 = b["p"]
	var side_r := r
	if free_mode and r <= 0.5:      # senza bolla le scariche partono dall'ufo
		anchor_p = uv
		side_r = 3.6
	for i in _count("terra", float(fu.get("terra", 0.0)), dt):
		_strike(anchor_p, 3.5, 12.0, rng.randf_range(0.07, 0.15), rng.randf() < 0.45)
		cine.shk = maxf(cine.shk, 0.35)
		if rng.randf() < 0.28:
			cine.flash_a = maxf(cine.flash_a, 0.15)
			cine.flash_col = Color(0.85, 0.95, 1.0)
	for i in _count("cielo", float(fu.get("dal_cielo", 0.0)), dt):
		_sky_bolt(anchor_p, maxf(side_r, 1.0))
	for i in _count("lato", float(fu.get("di_lato", 0.0)), dt):
		if side_r > 0.8:
			_flare_bolt(anchor_p, side_r)
	var arcs := float(fu.get("sulla_bolla", 0.0))
	if arcs >= 0.5 and r > 0.5:
		for i in _count("archi", 18.0, dt):
			_arcs(r, int(round(arcs)))
	for i in _count("punto", float(fu.get("nel_punto", 0.0)), dt):
		var pp: Vector3 = (gl["p"] as Vector3)
		_add_bolt(pp, pp + _rv(rng.randf_range(1.0, 5.0)), 0.055, C_CYAN, 0.11, 1)
		if rng.randf() < 0.25:
			_snd("zap", -12.0)
	for i in _count("scafo", float(fu.get("sullo_scafo", 0.0)), dt):
		var a0 := uv + Vector3(rng.randf_range(-3.6, 3.6), rng.randf_range(-0.6, 1.0), rng.randf_range(-3.6, 3.6))
		_add_bolt(a0, a0 + _rv(2.8), 0.045, C_CYAN, 0.09, 1)
		if rng.randf() < 0.45:
			_snd("zap", -8.0)
	for i in _count("residui", float(fu.get("sull_impronta", 0.0)), dt):
		var a1 := rng.randf() * TAU
		var p0 := _ground_at(center.x + cos(a1) * 6.2, center.y + sin(a1) * 6.2)
		var p1 := _ground_at(center.x + cos(a1 + 0.7) * 5.3, center.y + sin(a1 + 0.7) * 5.3)
		_add_bolt(p0 + Vector3(0, 0.15, 0), p1 + Vector3(0, 0.15, 0), 0.04, C_CYAN, 0.12, 1)

	if free_mode:
		_finish_frame(float(cl.get("impronta", 0.0)), dt)
		return
	# --- particelle
	smoke.position = uv + Vector3(0.9, 0.5, 0.4)
	fire.position = uv + Vector3(-1.1, 0.2, 1.3)
	smoke.emitting = float(ux.get("fumo", 0.0)) > 0.5
	fire.emitting = float(ux.get("fuoco", 0.0)) > 0.5
	inflow.position = home
	inflow.emitting = float(ux.get("luce_risucchiata", 0.0)) > 0.5
	inflow.visible = inflow.emitting
	embers.position = home + Vector3(0, -3.0, 0)
	embers.emitting = float(ux.get("braci", 0.0)) > 0.5
	_finish_frame(float(cl.get("impronta", 0.0)), dt)


func _finish_frame(scorch: float, dt: float) -> void:
	_draw_bolts(scorch)
	for sl in strike_lights:
		sl["e"] = maxf(0.0, float(sl["e"]) - dt * 22.0)
		(sl["l"] as OmniLight3D).light_energy = sl["e"]
	for fl in flares:
		fl["a"] = maxf(0.0, float(fl["a"]) - dt * 4.5)
		var fn: MeshInstance3D = fl["n"]
		fn.visible = float(fl["a"]) > 0.01
		fn.scale = Vector3.ONE * float(fl["s"])
		(fn.material_override as StandardMaterial3D).albedo_color.a = fl["a"]
	_post()


## il faro: l'attore "faro" e' il punto illuminato a terra, il cono parte dall'ufo
func _beam(T: float, uv: Vector3) -> void:
	var fa := _actor("faro", T)
	var a: float = float(fa["al"]) if fa["on"] else 0.0
	beam.visible = a > 0.01
	beam_spot.visible = beam.visible
	if not beam.visible:
		return
	var sweep: Vector3 = fa["p"]
	sweep.y = sk.elev_at(sweep.x, sweep.z) + 0.1
	var top := uv + Vector3(0, -0.9, 0)
	var v := top - sweep
	var len2 := maxf(v.length(), 0.1)
	beam.position = (top + sweep) * 0.5
	beam.basis = Basis(Quaternion(Vector3.UP, v / len2)) * Basis.from_scale(Vector3(1.9, len2, 1.9))
	var pulse := 0.85 + 0.15 * sin(t * 40.0)
	beam_mat.albedo_color.a = 0.15 * a * pulse
	beam_spot.position = sweep + Vector3(0, 0.5, 0)
	beam_spot.scale = Vector3.ONE * 5.0
	(beam_spot.material_override as StandardMaterial3D).albedo_color.a = 0.5 * a * pulse
	var sl: Dictionary = strike_lights[0]
	sl["e"] = maxf(float(sl["e"]), 3.0 * a)
	(sl["l"] as OmniLight3D).position = sweep + Vector3(0, 1.5, 0)


## eventi della timeline specifici di questa scena
func event(ev: Dictionary) -> void:
	var at: Vector3 = home
	var an := str(ev.get("a", ""))
	if an != "" and (cine.anchors.has(an) or cine.acts.has(an)):
		at = cine.ref(an)["p"]
	match str(ev.get("k", "")):
		"fulmini":
			bubble_pos = at
			var width := float(ev.get("g", 0.15))
			for i in int(ev.get("n", 5)):
				if str(ev.get("dove", "terra")) == "cielo":
					_sky_bolt(at, float(ev.get("raggio", 3.0)), width)
				else:
					bubble_r = maxf(bubble_r, 0.2)
					_strike(at, 2.0, float(ev.get("raggio", 10.0)), width)
		"fulmine_gigante":
			# dal cielo, attraverso il punto indicato, fino a terra
			var hit := _ground_at(at.x, at.z)
			var gw := float(ev.get("g", 0.55))
			_add_bolt(at + Vector3(1.5, 34.0, -4.0), at, gw * 0.9, C_CYAN, 0.55, 5)
			_add_bolt(at, hit, gw, C_WHITE, 0.6, 5)
			_hit_fx(hit, C_WHITE, 2.4)
		"anello":
			var c := W3DCine.v3(ev.get("c", [0.4, 0.85, 1.0]))
			shocks.append({"t0": t, "at": at if free_mode else Vector3(center.x, 0, center.y), "dur": float(ev.get("d", 1.4)), "r": float(ev.get("r", 18.0)), "col": Color(c.x, c.y, c.z), "w": float(ev.get("w", 0.4))})
		"onda":
			_wave(float(ev.get("v", 1.0)))
		"esplosione":
			_boom(at + W3DCine.v3(ev.get("o", [0, 0, 0])), float(ev.get("s", 0.6)))
		"scintille":
			_burst(_sparks(C_WHITE, Color(0.4, 0.45, 1.0, 0.0), int(ev.get("n", 220)), 1.4, 15.0, 38.0, -8.5), at)


func _post() -> void:
	var pm: ShaderMaterial = sk.post_mat
	var cm: Camera3D = sk.cam
	var vs := Vector2(sk.vp.size)
	var wc := Vector2(0.5, 0.45)
	var wr := 0.0
	var wk := 0.0
	if not cm.is_position_behind(bubble_pos):
		wc = cm.unproject_position(bubble_pos) / vs
		if bubble_r > 0.05:
			var edge := cm.unproject_position(bubble_pos + cm.basis.x * bubble_r) / vs
			wr = absf(edge.x - wc.x) * vs.x / vs.y
			wk = bubble_a
	pm.set_shader_parameter("warp_c", wc)
	pm.set_shader_parameter("warp_r", wr)
	pm.set_shader_parameter("warp_k", wk)
	var wa := t - wave_t
	pm.set_shader_parameter("wave_r", wa * 1.5)
	pm.set_shader_parameter("wave_k", wave_k * clampf(1.0 - wa / 0.9, 0.0, 1.0) if wa >= 0.0 else 0.0)
	pm.set_shader_parameter("storm", storm)
	pm.set_shader_parameter("lit", lit)
	pm.set_shader_parameter("mono", mono)
	sk.env.background_color = (saved["bg"] as Color).lerp(Color(0.035, 0.03, 0.09), storm).lerp(Color(0.3, 0.45, 0.7), lit * 0.45)
	sk.env.fog_light_color = Color(0.10, 0.11, 0.14).lerp(Color(0.09, 0.07, 0.2), storm)
	sk.env.ambient_light_color = sk.env.ambient_light_color.lerp(Color(0.34, 0.4, 0.85), storm)
	sk.env.ambient_light_energy += storm * 0.06 + lit * 0.35
