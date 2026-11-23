class_name W3DFuture
extends Node
## Le intrusioni del futuro nel mondo 3D. Il livello tecnologico del mondo (Chrono.tech) sale con le evocazioni:
## dalla PRIMA evocazione il mondo cambia (glitch dello schermo, crepe nel tempo, oggetti che non appartengono a questo posto),
## e con le ere cambiano anche forma e quantita' di quello che compare: crepe e cristalli, alambicchi, tubi a vapore, ciminiere.
## Gli oggetti sono nodi dinamici (non fanno parte dei blocchi del mondo): si ricalcolano quando la tecnologia sale.

var sk                                  # W3DSkin
var props: Dictionary = {}              # blocco (Vector2i) -> Array di nodi
var colls: Dictionary = {}              # blocco -> Array di [chiave collisione, voce]
var anim: Array = []                    # nodi che ruotano o ondeggiano
var meshes: Dictionary = {}
var last_tech := -1.0
var last_step := -1
var pulse := 0.0
var spawn_near := false
var t := 0.0

const BLK := 20.0                       # lato di un blocco (unita' di gioco)


func _process(dt: float) -> void:
	t += dt
	var tech: float = Chrono.tech
	if sk == null or not sk.active or not sk.world_on or str(sk.gm.area) != "world":
		_clear_all()
		sk.post_mat.set_shader_parameter("glitch", 0.0)
		last_tech = tech
		return
	if last_tech < 0.0:
		last_tech = tech
	if tech > last_tech + 0.01:            # appena evocato qualcosa dal futuro: onda nel tempo
		pulse = 1.0
		spawn_near = true
		var pp: Vector2 = sk.gm.player.position
		sk.burst3d(pp, Color(0.5, 1.0, 1.0), 28, 150.0, 0.7)
		sk.gm.add_ring(pp, 60.0, Color(0.5, 1.0, 1.0))
		sk.gm.add_ring(pp, 36.0, Color(1.0, 0.45, 0.95))
	last_tech = tech
	pulse = maxf(0.0, pulse - dt * 0.7)
	var base := 0.0
	if tech > 0.0:
		base = 0.28 + 0.45 * clampf(tech / 10.0, 0.0, 1.0) if tech < 30.0 else 0.25
	var gl := clampf(base * (0.75 + 0.25 * sin(t * 2.3)) + pulse * 0.9, 0.0, 1.2)
	sk.post_mat.set_shader_parameter("glitch", gl)
	var step := int(floor(tech))
	if step != last_step:
		last_step = step
		_clear_all()
	if tech <= 0.0:
		return
	if spawn_near:       # ogni evocazione lascia un segno vicino a te, subito visibile
		spawn_near = false
		_spawn_near(tech)
	var ppos: Vector2 = sk.pos
	var b0 := Vector2i(floori(ppos.x / BLK), floori(ppos.y / BLK))
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var k := b0 + Vector2i(dx, dz)
			if not props.has(k):
				_build_block(k, tech)
	for k in props.keys():
		if k.x != -99999 and (absi(k.x - b0.x) > 3 or absi(k.y - b0.y) > 3):
			_free_block(k)
	for a in anim:
		if is_instance_valid(a):
			var kind := str(a.get_meta("kind"))
			if kind == "rift":
				a.rotation.y += dt * 0.9
				a.position.y = float(a.get_meta("y0")) + sin(t * 1.6 + float(a.get_meta("ph"))) * 0.18
			elif kind == "gear":
				a.rotation.y += dt * 0.6 * float(a.get_meta("dir"))


func _clear_all() -> void:
	for k in props.keys():
		_free_block(k)


func _free_block(k: Vector2i) -> void:
	for n in props.get(k, []):
		if is_instance_valid(n):
			anim.erase(n)
			n.queue_free()
	for ce in colls.get(k, []):
		var arr: Array = sk.gcols.get(ce[0], [])
		arr.erase(ce[1])
	props.erase(k)
	colls.erase(k)


func _density(tech: float) -> float:
	return clampf(0.5 + tech * 0.05, 0.0, 2.6)


func _spawn_near(tech: float) -> void:
	var key := Vector2i(-99999, int(floor(tech)))
	if props.has(key):
		return
	props[key] = []
	colls[key] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(floor(tech)), 31337))
	var pc: Vector2 = sk.gm.player.position / 16.0
	for attempt in 12:
		var a := rng.randf() * TAU
		var p := pc + Vector2.from_angle(a) * rng.randf_range(4.5, 8.0)
		if not sk.world_free(p * 16.0, 26.0):
			continue
		var kind := _kind_for(int(Chrono.era()), rng.randf())
		_place(key, kind, p, rng)
		return


func _kind_for(era: int, r: float) -> String:
	match era:
		0:
			return "rift"
		1:
			return "rift" if r < 0.35 else "alembic"
		2:
			return "alembic" if r < 0.2 else ("pipe" if r < 0.7 else "gear")
	return "pipe" if r < 0.25 else ("stack" if r < 0.7 else "girder")


func _build_block(k: Vector2i, tech: float) -> void:
	props[k] = []
	colls[k] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(k.x, k.y, 4242 + int(tech)))
	var dd := _density(tech)
	var cnt := int(dd) + (1 if rng.randf() < dd - floorf(dd) else 0)
	var era: int = Chrono.era()
	for i in cnt:
		var p := Vector2(k.x * BLK + rng.randf_range(2.0, BLK - 2.0), k.y * BLK + rng.randf_range(2.0, BLK - 2.0))
		var kind := _kind_for(era, rng.randf())
		if not sk.world_free(p * 16.0, 26.0):
			continue
		_place(k, kind, p, rng)


func _place(k: Vector2i, kind: String, p: Vector2, rng: RandomNumberGenerator) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = sk.mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "rift" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.position = Vector3(p.x, 0.0, p.y)
	mi.rotation.y = rng.randf() * TAU
	mi.set_meta("kind", kind)
	mi.set_meta("y0", 0.0)
	mi.set_meta("ph", rng.randf() * TAU)
	mi.set_meta("dir", 1.0 if rng.randf() < 0.5 else -1.0)
	if kind == "rift":
		mi.set_meta("y0", 0.35)
		mi.position.y = 0.35
	sk.vp.add_child(mi)
	(props[k] as Array).append(mi)
	if kind == "rift" or kind == "gear":
		anim.append(mi)
	if kind == "pipe":
		mi.add_child(sk._make_smoke(Vector3(0.0, 2.7, 0.0)))
	elif kind == "stack":
		mi.add_child(sk._make_smoke(Vector3(0.0, 5.7, 0.0)))
	var half := Vector2(0.45, 0.45)
	if kind == "rift":
		half = Vector2(0.3, 0.3)
	elif kind == "stack":
		half = Vector2(0.75, 0.75)
	elif kind == "girder":
		half = Vector2(1.0, 1.0)
	var ck := Vector2i(floori(p.x / 8.0), floori(p.y / 8.0))
	if not sk.gcols.has(ck):
		sk.gcols[ck] = []
	var entry := [p, half]
	(sk.gcols[ck] as Array).append(entry)
	(colls[k] as Array).append([ck, entry])


func _em(c: Color, k := 1.0) -> Color:
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 0.05)


func _mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind):
		return meshes[kind]
	var b := W3DBuilder.new()
	b.sat = 1.3
	b.con = 1.2
	var copper := Color(0.62, 0.36, 0.2)
	var iron := Color(0.2, 0.21, 0.24)
	match kind:
		"rift":     # cristallo che non appartiene a questo tempo, con anello di luce e schegge in orbita
			var c1 := Color(0.3, 0.95, 1.0)
			var c2 := Color(1.0, 0.35, 0.9)
			var top := Vector3(0, 2.1, 0)
			var bot := Vector3(0, 0.2, 0)
			for i in 4:
				var a0 := TAU * i / 4.0 + 0.4
				var a1 := a0 + TAU / 4.0
				var p0 := Vector3(cos(a0) * 0.42, 1.1, sin(a0) * 0.42)
				var p1 := Vector3(cos(a1) * 0.42, 1.1, sin(a1) * 0.42)
				b.tri(top, p0, p1, _em(c1 if i % 2 == 0 else c2, 1.1))
				b.tri(bot, p1, p0, _em(c2 if i % 2 == 0 else c1, 0.7))
			for q in 6:
				var qa := TAU * q / 6.0
				var qa1 := TAU * (q + 1) / 6.0
				var o0 := Vector3(cos(qa), -0.3, sin(qa)) * 0.95
				var o1 := Vector3(cos(qa1), -0.3, sin(qa1)) * 0.95
				b.quad(o0, o1, o1 * 0.86 + Vector3(0, 0.0, 0), o0 * 0.86, _em(c1 if q % 2 == 0 else c2, 0.9))
			for q in 3:
				var sa := TAU * q / 3.0
				b.shard(Vector3(cos(sa) * 0.8, 0.9 + q * 0.3, sin(sa) * 0.8), Vector3(cos(sa) * 0.8, 1.35 + q * 0.3, sin(sa) * 0.8), 0.1, 0.0, _em(c1 if q != 1 else c2, 1.0), 0.5, 0.0, 0.0)
		"alembic":      # alambicco di rame e vetro verde incandescente
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.55, 0.5, 0.35, 6, copper, 0.1)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), 0.36, 0.34, 1.5, 6, _em(Color(0.4, 0.95, 0.5), 0.85), 0.0, false)
			b.blob(Vector3(0, 1.95, 0), Vector3(0.4, 0.3, 0.4), copper, 6, 3, 0.05, 0.0)
			b.blob(Vector3(0, 0.9, 0), Vector3(0.25, 0.25, 0.25), _em(Color(0.7, 1.0, 0.6), 1.0), 5, 3, 0.0, 0.0)
			b.box(Transform3D(Basis(Vector3.FORWARD, -0.7), Vector3(0.55, 2.1, 0)), Vector3(0.7, 0.1, 0.1), copper * 0.9, 0.08, 8)
		"pipe":      # colonna di tubi di rame con valvola (sbuffa vapore)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Vector3(1.0, 0.2, 1.0), iron, 0.08, 8)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), 0.26, 0.24, 2.4, 6, copper, 0.1)
			b.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.2, 1.4, 0)), 0.14, 0.14, 0.9, 5, copper * 0.85, 0.1)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0.0, 2.6, 0.0)), 0.34, 0.3, 0.14, 6, Color(0.5, 0.3, 0.16), 0.05)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0.3)), Vector3(0.5, 0.06, 0.06), Color(0.7, 0.2, 0.15), 0.05, 8)
		"gear":      # ingranaggio gigante di ottone, in piedi
			var brass := Color(0.7, 0.55, 0.2)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.95, 0.95, 0.22, 10, brass, 0.1)
			for q in 10:
				var ga := TAU * q / 10.0
				b.box(Transform3D(Basis(Vector3.UP, -ga), Vector3(cos(ga) * 1.05, 0.36, sin(ga) * 1.05)), Vector3(0.3, 0.22, 0.28), brass * 0.92, 0.06, 8)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.22, 0.22, 0.34, 6, iron, 0.05)
		"stack":      # ciminiera di mattoni che vomita fumo
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.85, 0.65, 5.4, 7, Color(0.42, 0.2, 0.15), 0.12)
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 5.4, 0)), 0.78, 0.74, 0.25, 7, iron, 0.05)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), Vector3(1.9, 0.15, 1.9), iron, 0.08, 8)
		_:      # "girder": travi di ferro, struttura grezza
			for sx in [-0.8, 0.8]:
				for sz in [-0.8, 0.8]:
					b.box(Transform3D(Basis.IDENTITY, Vector3(sx, 1.3, sz)), Vector3(0.16, 2.6, 0.16), iron, 0.06, 8)
			for hy in [0.9, 1.8, 2.6]:
				b.box(Transform3D(Basis.IDENTITY, Vector3(0, hy, 0.8)), Vector3(1.7, 0.1, 0.1), iron * 1.2, 0.05, 8)
				b.box(Transform3D(Basis.IDENTITY, Vector3(0, hy, -0.8)), Vector3(1.7, 0.1, 0.1), iron * 1.2, 0.05, 8)
				b.box(Transform3D(Basis.IDENTITY, Vector3(0.8, hy, 0)), Vector3(0.1, 0.1, 1.7), iron * 1.2, 0.05, 8)
				b.box(Transform3D(Basis.IDENTITY, Vector3(-0.8, hy, 0)), Vector3(0.1, 0.1, 1.7), iron * 1.2, 0.05, 8)
	var m := b.mesh()
	meshes[kind] = m
	return m
