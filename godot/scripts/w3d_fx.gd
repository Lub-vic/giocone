class_name W3DFx
extends RefCounted
## Effetti di luce del mondo 3D: scie luminose dei proiettili magici e aree degli incantesimi nemici.
## Tutto e' additivo e senza ombre: si somma alla luce della scena come una vera fonte luminosa.

static var _mats := {}
static var _meshes := {}
static var _tex: Texture2D


static func halo_tex() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_tex = t
	return _tex


## materiale additivo senza luce: i colori dei vertici (alfa compresa) decidono l'intensita'. E' uno shader che segue
## le quote del terreno e la curvatura del mondo come tutto il resto; ogni istanza che sfuma ne ha una copia sua.
static func glow_mat(col := Color.WHITE, textured := false) -> ShaderMaterial:
	var key := "%s|%s" % [col.to_html(true), textured]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/w3d_glow.gdshader")
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("use_tex", textured)
	if textured:
		m.set_shader_parameter("tex", halo_tex())
	_mats[key] = m
	return m


## macchia scura a mescola normale (bruciato, sangue, pece): segue il terreno
static func dark_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/w3d_stain.gdshader")
	return m


## quadratino luminoso che guarda sempre la camera (particelle)
static func particle_mat(col: Color) -> StandardMaterial3D:
	var key := "p|" + col.to_html(true)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.albedo_texture = halo_tex()
	_mats[key] = m
	return m


static func set_fade(mi: MeshInstance3D, a: float) -> void:
	var m := mi.material_override as ShaderMaterial
	if m != null:
		m.set_shader_parameter("fade", clampf(a, 0.0, 1.0))


## alone morbido piatto (visto dall'alto), centrato sull'origine
static func halo(col: Color, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	mi.mesh = pm
	mi.material_override = glow_mat(col, true).duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [d, cd]]:
		st.set_color(v[1])
		st.add_vertex(v[0])


## guglia di luce / lingua di fuoco (piramide a 4 facce, base di raggio 1 e altezza 1): intensa alla base, sfuma in punta
static func spike_mesh(col: Color) -> ArrayMesh:
	var key := "spike|" + col.to_html(false)
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cb := Color(col.r, col.g, col.b, 0.9)
	var ct := Color(1, 1, 1, 0.0)
	var tip := Vector3(0, 1, 0)
	for i in 4:
		var a0 := TAU * i / 4.0 + PI * 0.25
		var a1 := TAU * (i + 1) / 4.0 + PI * 0.25
		for v in [[Vector3(cos(a0), 0, sin(a0)), cb], [Vector3(cos(a1), 0, sin(a1)), cb], [tip, ct]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var m := st.commit()
	_meshes[key] = m
	return m


## chiazza irregolare (bordo frastagliato), raggio ~1: macchia di terreno bruciato o magia
static func blot_mesh(col: Color, a_center: float, a_edge: float, seed_v: int) -> ArrayMesh:
	var key := "blot|%s|%s|%s|%d" % [col.to_html(false), a_center, a_edge, seed_v]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 48
	var cc := Color(col.r, col.g, col.b, a_center)
	var ce := Color(col.r, col.g, col.b, a_edge)
	for i in n:
		var u0 := TAU * i / n
		var u1 := TAU * (i + 1) / n
		var r0 := 0.86 + 0.09 * sin(3.0 * u0 + p1) + 0.06 * sin(7.0 * u0 + p2) + 0.04 * sin(13.0 * u0 + p3)
		var r1 := 0.86 + 0.09 * sin(3.0 * u1 + p1) + 0.06 * sin(7.0 * u1 + p2) + 0.04 * sin(13.0 * u1 + p3)
		for v in [[Vector3.ZERO, cc], [Vector3(cos(u0), 0, sin(u0)) * r0, ce], [Vector3(cos(u1), 0, sin(u1)) * r1, ce]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
	var m := st.commit()
	_meshes[key] = m
	return m


## cerchio rituale tracciato a mano: raggio e spessore che ondeggiano, qualche interruzione
static func ritual_ring_mesh(col: Color, seed_v: int) -> ArrayMesh:
	var key := "rring|%s|%d" % [col.to_html(false), seed_v]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 72
	var pr := rng.randf() * TAU
	var gap_left := 0
	for i in n:
		if gap_left > 0:
			gap_left -= 1
			continue
		if rng.randf() < 0.05:
			gap_left = rng.randi_range(1, 3)
			continue
		var u0 := TAU * i / n
		var u1 := TAU * (i + 1) / n
		var w0 := 0.035 + 0.03 * (0.5 + 0.5 * sin(5.0 * u0 + pr))
		var w1 := 0.035 + 0.03 * (0.5 + 0.5 * sin(5.0 * u1 + pr))
		var r0 := 0.97 + 0.025 * sin(4.0 * u0 + pr * 2.0)
		var r1 := 0.97 + 0.025 * sin(4.0 * u1 + pr * 2.0)
		var al := 0.65 + 0.35 * rng.randf()
		var c := Color(col.r, col.g, col.b, al)
		var ce := Color(col.r, col.g, col.b, 0.1)
		_quad(st, Vector3(cos(u0), 0, sin(u0)) * (r0 - w0), Vector3(cos(u0), 0, sin(u0)) * (r0 + w0), Vector3(cos(u1), 0, sin(u1)) * (r1 + w1), Vector3(cos(u1), 0, sin(u1)) * (r1 - w1), c, ce, ce, c)
	var m := st.commit()
	_meshes[key] = m
	return m


## segno a mano libera tra due punti (linea spezzata con piccoli sbandamenti)
static func _stroke(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color, rng: RandomNumberGenerator, jitter: float) -> void:
	var steps := 7
	var nrm := Vector3(-(b - a).z, 0, (b - a).x).normalized()
	var prev := a
	var prev_w := w * 0.6
	for i in range(1, steps + 1):
		var t := float(i) / steps
		var q := a.lerp(b, t) + nrm * rng.randf_range(-jitter, jitter) * (1.0 if i < steps else 0.0)
		var wi := w * (0.6 + 0.8 * sin(t * PI))
		var d := q - prev
		var nn := Vector3(-d.z, 0, d.x).normalized()
		var al := 0.55 + 0.45 * rng.randf()
		var c := Color(col.r, col.g, col.b, al)
		var ce := Color(col.r, col.g, col.b, 0.0)
		_quad(st, prev - nn * prev_w, prev + nn * prev_w, q + nn * wi, q - nn * wi, ce, ce, ce, ce)
		_quad(st, prev - nn * prev_w * 0.45, prev + nn * prev_w * 0.45, q + nn * wi * 0.45, q - nn * wi * 0.45, c, c, c, c)
		prev = q
		prev_w = wi


## pentagramma irregolare con un cerchietto al centro e segni agli apici
static func sigil_mesh(col: Color, seed_v: int) -> ArrayMesh:
	var key := "sigil|%s|%d" % [col.to_html(false), seed_v]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array = []
	var rot := rng.randf() * TAU
	for i in 5:
		var a := rot + TAU * i / 5.0
		pts.append(Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.74, 0.8))
	for i in 5:
		_stroke(st, pts[i], pts[(i + 2) % 5], 0.05, col, rng, 0.02)
	for i in 14:
		var u0 := TAU * i / 14.0
		var u1 := TAU * (i + 1) / 14.0
		var c := Color(col.r, col.g, col.b, 0.8)
		_quad(st, Vector3(cos(u0), 0, sin(u0)) * 0.11, Vector3(cos(u0), 0, sin(u0)) * 0.16, Vector3(cos(u1), 0, sin(u1)) * 0.16, Vector3(cos(u1), 0, sin(u1)) * 0.11, c, c, c, c)
	for i in 5:
		var p: Vector3 = pts[i]
		var out := p.normalized()
		_stroke(st, p * 1.06, p * 1.2 + Vector3(-out.z, 0, out.x) * 0.05, 0.035, col, rng, 0.01)
	var m := st.commit()
	_meshes[key] = m
	return m


## crepe incandescenti che si aprono dal centro (rami irregolari)
static func cracks_mesh(col: Color, seed_v: int) -> ArrayMesh:
	var key := "cracks|%s|%d" % [col.to_html(false), seed_v]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hot := Color(minf(col.r + 0.5, 1.0), minf(col.g + 0.5, 1.0), minf(col.b + 0.5, 1.0))
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf_range(-0.25, 0.25)
		var p := Vector3.ZERO
		var len_k := rng.randf_range(0.7, 1.05)
		var s_ := 0.0
		var w := 0.06
		while s_ < len_k:
			a += rng.randf_range(-0.4, 0.4)
			var step := rng.randf_range(0.08, 0.15)
			var q := p + Vector3(cos(a), 0, sin(a)) * step
			var nn := Vector3(-sin(a), 0, cos(a))
			var f := 1.0 - s_ / len_k
			var c := Color(hot.r, hot.g, hot.b, 0.95 * f + 0.05)
			var w2 := w * (0.35 + 0.65 * f)
			_quad(st, p - nn * w, p + nn * w, q + nn * w2, q - nn * w2, c, c, c, c)
			if rng.randf() < 0.22 and s_ > 0.2:
				var ba := a + rng.randf_range(0.6, 1.2) * (1.0 if rng.randf() < 0.5 else -1.0)
				var bq := q + Vector3(cos(ba), 0, sin(ba)) * rng.randf_range(0.12, 0.3)
				var bn := Vector3(-sin(ba), 0, cos(ba))
				var c0 := Color(c.r, c.g, c.b, 0.0)
				_quad(st, q - bn * w2 * 0.6, q + bn * w2 * 0.6, bq + bn * 0.01, bq - bn * 0.01, c, c, c0, c0)
			p = q
			w = w2
			s_ += step
	var m := st.commit()
	_meshes[key] = m
	return m


static func _inst(mesh: Mesh, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = glow_mat().duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## ---------------------------------------------------------------- scia luminosa
## nastro piatto che segue il proiettile: largo e luminoso alla testa, sottile e trasparente in coda
class Trail extends RefCounted:
	var mi: MeshInstance3D
	var im := ImmediateMesh.new()
	var pts: Array = []
	var col: Color
	var width := 0.34
	var count := 20

	func _init(parent: Node, c: Color, w := 0.34, n := 20) -> void:
		col = c
		width = w
		count = n
		mi = MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = W3DFx.glow_mat().duplicate()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 40.0
		parent.add_child(mi)

	func push(p: Vector3) -> void:
		if pts.is_empty() or (pts[0] as Vector3).distance_to(p) > 0.03:
			pts.push_front(p)
			if pts.size() > count:
				pts.pop_back()
		_rebuild()

	func _rebuild() -> void:
		im.clear_surfaces()
		var n := pts.size()
		if n < 2:
			return
		im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var prev_l := Vector3.ZERO
		var prev_c := Vector3.ZERO
		var prev_r := Vector3.ZERO
		var prev_a := 0.0
		for i in n:
			var p: Vector3 = pts[i]
			var q: Vector3 = pts[i + 1] if i + 1 < n else p
			var o: Vector3 = pts[i - 1] if i > 0 else p
			var tg := o - q
			tg.y = 0.0
			if tg.length() < 0.0001:
				tg = Vector3(0, 0, -1)
			tg = tg.normalized()
			var nr := Vector3(-tg.z, 0, tg.x)
			var k := 1.0 - float(i) / float(n)
			var hw := width * 0.5 * pow(k, 0.7)
			var a := pow(k, 1.6) * 0.9
			var l := p - nr * hw
			var r := p + nr * hw
			if i > 0:
				_seg(prev_l, prev_c, l, p, prev_a, a, 0.0)
				_seg(prev_c, prev_r, p, r, prev_a, a, 1.0)
			prev_l = l
			prev_c = p
			prev_r = r
			prev_a = a
		im.surface_end()

	## due triangoli tra la sezione precedente e quella corrente; il lato esterno e' trasparente, il centro luminoso
	func _seg(a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3, al0: float, al1: float, side: float) -> void:
		var e0 := Color(col.r, col.g, col.b, 0.0)
		var m0 := Color(minf(col.r * 1.3 + 0.25, 1.0), minf(col.g * 1.3 + 0.25, 1.0), minf(col.b * 1.3 + 0.25, 1.0), al0)
		var m1 := Color(m0.r, m0.g, m0.b, al1)
		var ca0 := e0 if side == 0.0 else m0
		var cb0 := m0 if side == 0.0 else e0
		var ca1 := e0 if side == 0.0 else m1
		var cb1 := m1 if side == 0.0 else e0
		for v in [[a0, ca0], [b0, cb0], [b1, cb1], [a0, ca0], [b1, cb1], [a1, ca1]]:
			im.surface_set_color(v[1])
			im.surface_add_vertex(v[0])

	## la scia si spegne piano invece di sparire di colpo
	func release() -> void:
		if mi == null or not is_instance_valid(mi):
			return
		var mat := mi.material_override as ShaderMaterial
		var tw := mi.create_tween()
		tw.tween_property(mat, "shader_parameter/fade", 0.0, 0.28)
		tw.tween_callback(mi.queue_free)
		mi = null


## ---------------------------------------------------------------- area degli incantesimi nemici
## aspetto rituale: macchia scura che si allarga sul terreno, cerchio tracciato a mano, pentagramma irregolare e lingue di fuoco
## che salgono instabili; al colpo il terreno si squarcia in crepe incandescenti e le fiamme eruttano
class HazardFx extends Node3D:
	var col: Color
	var hot: Color
	var stain: MeshInstance3D
	var glow: MeshInstance3D
	var ring: MeshInstance3D
	var sigil: MeshInstance3D
	var cracks: MeshInstance3D
	var flash: MeshInstance3D
	var bloom: MeshInstance3D
	var flames: Array = []
	var parts: CPUParticles3D
	var clock := 0.0
	var seed_v := 1
	const NF := 16

	func _init(c: Color) -> void:
		col = c
		seed_v = int(c.r * 97.0 + c.g * 57.0 + c.b * 31.0) + 11
		hot = Color(minf(c.r * 1.15 + 0.2, 1.0), minf(c.g * 1.15 + 0.2, 1.0), minf(c.b * 1.15 + 0.2, 1.0))
		stain = MeshInstance3D.new()
		stain.mesh = W3DFx.blot_mesh(Color(0.03, 0.01, 0.03), 0.7, 0.0, seed_v)
		stain.material_override = W3DFx.dark_mat()
		stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(stain)
		bloom = W3DFx.halo(Color(c.r, c.g, c.b, 0.9), 1.0)
		bloom.position.y = 0.03
		add_child(bloom)
		glow = W3DFx._inst(W3DFx.blot_mesh(c, 0.75, 0.05, seed_v + 5), self)
		cracks = W3DFx._inst(W3DFx.cracks_mesh(c, seed_v + 9), self)
		ring = W3DFx._inst(W3DFx.ritual_ring_mesh(hot, seed_v + 1), self)
		sigil = W3DFx._inst(W3DFx.sigil_mesh(hot, seed_v + 2), self)
		flash = W3DFx._inst(W3DFx.blot_mesh(hot.lerp(Color(1, 0.9, 0.7), 0.5), 1.0, 0.1, seed_v + 7), self)
		for i in NF:
			flames.append(W3DFx._inst(W3DFx.spike_mesh(hot), self))
		cracks.visible = false
		flash.visible = false
		parts = CPUParticles3D.new()
		parts.amount = 28
		parts.lifetime = 1.3
		parts.local_coords = false
		parts.direction = Vector3.UP
		parts.spread = 18.0
		parts.gravity = Vector3(0, 0.4, 0)
		parts.initial_velocity_min = 1.0
		parts.initial_velocity_max = 2.6
		parts.scale_amount_min = 0.35
		parts.scale_amount_max = 1.1
		parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		parts.emission_ring_axis = Vector3.UP
		parts.emission_ring_radius = 1.0
		parts.emission_ring_inner_radius = 0.0
		parts.emission_ring_height = 0.1
		var qm := QuadMesh.new()
		qm.size = Vector2(0.32, 0.32)
		qm.material = W3DFx.particle_mat(Color(hot.r, hot.g, hot.b, 0.9))
		parts.mesh = qm
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		parts.color_ramp = ramp
		add_child(parts)

	func _fade(mi: MeshInstance3D, a: float) -> void:
		W3DFx.set_fade(mi, a)

	## fiamma instabile: intermittenza irregolare (somma di onde sfasate)
	func _flick(i: int, speed: float) -> float:
		return 0.6 + 0.25 * sin(clock * speed + i * 2.3) + 0.15 * sin(clock * speed * 2.7 + i * 5.1)

	func _place_flames(r: float, height: float, a_mul: float, sway: float, spin: float) -> void:
		var hs := clampf(r * 0.5, 0.6, 1.7)
		for i in NF:
			var a := TAU * i / NF + spin + 0.2 * sin(i * 3.1)
			var rad := r * (0.88 + 0.1 * sin(i * 1.9))
			var fl: MeshInstance3D = flames[i]
			var hgt := height * hs * (0.55 + 0.45 * absf(sin(i * 4.3 + 1.0))) * _flick(i, 9.0)
			fl.position = Vector3(cos(a) * rad + sin(clock * 7.0 + i) * sway, 0.0, sin(a) * rad + cos(clock * 6.0 + i * 1.3) * sway)
			fl.scale = Vector3(0.12 + 0.05 * sin(i * 2.0 + clock * 5.0), maxf(hgt, 0.02), 0.12)
			fl.rotation.y = i * 1.3
			fl.visible = hgt > 0.03
			_fade(fl, a_mul * _flick(i, 8.0))

	## t: secondi dalla creazione; delay: durata dell'avviso; life: durata dell'effetto; tick > 0: pozza che dura
	func update_fx(t: float, delay: float, life: float, tick: float, r: float, dt: float, lift := 0.0) -> void:
		clock += dt
		parts.position.y = lift
		var rr := Vector3(r, 1.0, r)
		parts.emission_ring_radius = r * 0.9
		parts.amount = clampi(int(r * 12.0), 12, 34)
		if t < delay:
			var k := clampf(t / maxf(delay, 0.01), 0.0, 1.0)
			var nz := _flick(3, 6.0)
			stain.scale = rr * (0.55 + 0.5 * k)
			_fade(stain, 0.45 + 0.4 * k)
			glow.scale = rr * (0.3 + 0.7 * k)
			_fade(glow, (0.3 + 0.55 * k) * nz)
			bloom.scale = Vector3(r * (2.4 + 0.3 * sin(clock * 5.0)), 1.0, r * (2.4 + 0.3 * sin(clock * 5.0)))
			_fade(bloom, (0.12 + 0.35 * k) * nz)
			ring.scale = rr
			ring.rotation.y += dt * 0.12
			_fade(ring, (0.55 + 0.4 * k) * (0.8 + 0.2 * nz))
			sigil.scale = rr
			sigil.rotation.y -= dt * (0.25 + 0.5 * k)
			_fade(sigil, (0.4 + 0.55 * k) * (0.75 + 0.25 * _flick(7, 10.0)))
			cracks.visible = false
			flash.visible = false
			parts.emitting = true
			_place_flames(r, 0.15 + 1.1 * k, 0.45 + 0.5 * k, 0.03, clock * 0.2)
		elif tick <= 0.0:
			var f := clampf((t - delay) / (life + 0.3), 0.0, 1.0)
			var inv := 1.0 - f
			var burst := 1.0 - pow(inv, 3.0)
			stain.scale = rr * (1.0 + 0.15 * f)
			_fade(stain, 0.9 * (1.0 - 0.4 * f))
			glow.scale = rr * (1.0 + 0.1 * f)
			_fade(glow, 0.95 * inv)
			flash.visible = true
			flash.scale = rr * (0.7 + 0.4 * f)
			flash.position.y = 0.05
			_fade(flash, pow(inv, 1.3))
			bloom.scale = Vector3(r * (3.0 + 1.6 * f), 1.0, r * (3.0 + 1.6 * f))
			_fade(bloom, 0.9 * pow(inv, 1.4))
			cracks.visible = true
			cracks.position.y = 0.06
			cracks.scale = rr * (0.25 + 0.85 * burst)
			_fade(cracks, 0.5 + 0.5 * inv)
			ring.scale = rr * (1.0 + 0.1 * f)
			_fade(ring, inv)
			sigil.rotation.y += dt * 3.0
			_fade(sigil, inv * 0.9)
			parts.emitting = f < 0.45
			_place_flames(r, 0.3 + 3.2 * inv * (0.4 + 0.6 * burst), 0.95 * (0.3 + 0.7 * inv), 0.06, clock * 0.5)
		else:
			var fade := clampf((delay + life - t) * 2.0, 0.0, 1.0)
			var pulse := 0.55 + 0.15 * sin(clock * 3.0) + 0.1 * sin(clock * 7.3)
			stain.scale = rr
			_fade(stain, 0.8 * fade)
			glow.scale = rr
			_fade(glow, pulse * fade)
			bloom.scale = Vector3(r * 2.3, 1.0, r * 2.3)
			_fade(bloom, (0.25 + 0.08 * sin(clock * 4.0)) * fade)
			ring.scale = rr
			ring.rotation.y += dt * 0.08
			_fade(ring, 0.7 * fade)
			sigil.scale = rr
			sigil.rotation.y -= dt * 0.2
			_fade(sigil, 0.5 * fade)
			cracks.visible = false
			flash.visible = false
			parts.emitting = fade > 0.2
			_place_flames(r, 0.35, 0.65 * fade, 0.05, -clock * 0.3)
