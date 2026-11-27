class_name W3DMapProps
extends RefCounted
## Modelli 3D per gli oggetti della mappa che il motore non aveva. build() restituisce false se il nome non e' suo.

const CANVAS := [Color(0.34, 0.27, 0.17), Color(0.27, 0.2, 0.16), Color(0.3, 0.29, 0.22), Color(0.25, 0.14, 0.12)]
const WOOD := Color(0.22, 0.145, 0.085)
const IRON := Color(0.09, 0.09, 0.1)
const STONE := Color(0.29, 0.29, 0.32)


static func build(name: String, o: W3DBuilder, p: Vector2, foot: Vector2, r: RandomNumberGenerator, cols: Array, lamps: Array) -> bool:
	var base := Vector3(p.x, 0.0, p.y)
	if name.begins_with("tent"):
		_tent(o, base, foot, r)
		cols.append(["b", p, foot * 0.38, 0.0])
	elif name.begins_with("menhir"):
		var high := r.randf_range(2.2, 3.4)
		var lean := Basis(Vector3.FORWARD, r.randf_range(-0.14, 0.14)) * Basis(Vector3.UP, r.randf() * TAU)
		var tone := STONE if not name.contains("ice") else Color(0.5, 0.62, 0.72)
		o.cyl(Transform3D(lean, base), 0.55, 0.32, high, 5, tone * r.randf_range(0.8, 1.15), 0.2)
		o.rock(base + lean * Vector3(0, high, 0), Vector3(0.66, 0.5, 0.6), tone, 0.18, 0.45, r.randf() * TAU)
		for i in 3:
			o.box(Transform3D(lean, base + lean * Vector3(0, high * (0.35 + i * 0.18), -0.45)), Vector3(0.34 - i * 0.07, 0.07, 0.05), Color(0.45, 0.75, 0.85, 0.35), 0.1, 8)
		cols.append(["c", p, 0.5])
	elif name.begins_with("crystal") or name.begins_with("ice_spikes"):
		var tone := Color(0.52, 0.74, 0.92, 0.55)
		for i in r.randi_range(5, 8):
			var a := TAU * i / 8.0 + r.randf() * 0.5
			var off := Vector3(cos(a), 0, sin(a)) * (0.0 if i == 0 else r.randf_range(0.25, 0.7))
			var tilt := Basis(Vector3(sin(a), 0, -cos(a)), 0.0 if i == 0 else r.randf_range(0.2, 0.55))
			var high := r.randf_range(1.4, 2.4) if i == 0 else r.randf_range(0.6, 1.4)
			o.cyl(Transform3D(tilt, base + off), 0.26 if i == 0 else 0.17, 0.0, high, 5, tone * r.randf_range(0.85, 1.2), 0.15, false)
		lamps.append(Vector4(p.x, 1.2, p.y, 0.35))
		cols.append(["c", p, 0.65])
	elif name.begins_with("coffin"):
		var yaw := Basis(Vector3.UP, r.randf_range(-0.6, 0.6))
		o.box(Transform3D(yaw, base + Vector3(0, 0.26, 0)), Vector3(0.78, 0.5, 1.75), WOOD * 0.8, 0.14, 8)
		var open := r.randf() < 0.4
		var lid := yaw * Basis(Vector3.FORWARD, 0.0 if not open else 0.5)
		o.box(Transform3D(lid, base + yaw * Vector3(0.5 if open else 0.0, 0.56, 0)), Vector3(0.84, 0.09, 1.82), WOOD * 1.1, 0.12, 0)
		for z in [-0.55, 0.55]:
			o.box(Transform3D(yaw, base + yaw * Vector3(0, 0.3, z)), Vector3(0.82, 0.54, 0.07), IRON, 0.1, 8)
		cols.append(["b", p, Vector2(0.45, 0.9), 0.0])
	elif name.begins_with("broken_pew"):
		var yaw := Basis(Vector3.UP, r.randf_range(-0.5, 0.5))
		var roll := yaw * Basis(Vector3.FORWARD, r.randf_range(-0.18, 0.18))
		o.box(Transform3D(roll, base + Vector3(0, 0.42, 0)), Vector3(foot.x * 0.85, 0.1, 0.45), WOOD, 0.14, 0)
		o.box(Transform3D(roll, base + yaw * Vector3(0, 0.82, 0.22)), Vector3(foot.x * 0.6, 0.55, 0.09), WOOD * 0.85, 0.14, 0)
		for x in [-0.38, 0.38]:
			o.box(Transform3D(yaw, base + yaw * Vector3(foot.x * x, 0.2, 0)), Vector3(0.1, 0.42, 0.45), WOOD * 0.7, 0.1, 8)
		cols.append(["b", p, Vector2(foot.x * 0.42, 0.3), 0.0])
	elif name.begins_with("rowboat"):
		var yaw := Basis(Vector3.UP, r.randf() * TAU)
		o.box(Transform3D(yaw, base + Vector3(0, 0.12, 0)), Vector3(0.9, 0.12, 2.3), WOOD * 0.65, 0.12, 8)
		for side in [-1.0, 1.0]:
			var flare := yaw * Basis(Vector3.FORWARD, -side * 0.35)
			o.box(Transform3D(flare, base + yaw * Vector3(side * 0.55, 0.36, 0)), Vector3(0.1, 0.5, 2.3), WOOD, 0.14, 0)
			o.box(Transform3D(yaw * Basis(Vector3.UP, side * 0.55), base + yaw * Vector3(side * 0.28, 0.36, -1.4)), Vector3(0.1, 0.46, 0.9), WOOD * 0.9, 0.12, 0)
		for z in [-0.4, 0.6]:
			o.box(Transform3D(yaw, base + yaw * Vector3(0, 0.46, z)), Vector3(1.0, 0.07, 0.24), WOOD * 1.2, 0.12, 8)
		cols.append(["c", p, 0.8])
	elif name.begins_with("ore_cart"):
		var yaw := Basis(Vector3.UP, r.randf_range(-0.4, 0.4))
		for x in [-0.42, 0.42]:
			o.box(Transform3D(yaw, base + yaw * Vector3(x, 0.05, 0)), Vector3(0.09, 0.09, 2.4), IRON * 1.6, 0.1, 8)
		o.box(Transform3D(yaw, base + Vector3(0, 0.55, 0)), Vector3(1.0, 0.62, 1.3), WOOD * 0.8, 0.14, 8)
		for z in [-0.66, 0.66]:
			o.box(Transform3D(yaw, base + yaw * Vector3(0, 0.6, z)), Vector3(1.08, 0.1, 0.07), IRON, 0.08, 8)
		for x in [-0.5, 0.5]:
			for z in [-0.42, 0.42]:
				o.cyl(Transform3D(yaw * Basis(Vector3.FORWARD, PI * 0.5), base + yaw * Vector3(x + 0.07, 0.24, z)), 0.2, 0.2, 0.13, 8, IRON, 0.08)
		for i in 7:
			o.rock(base + yaw * Vector3(r.randf_range(-0.32, 0.32), 0.92 + r.randf() * 0.12, r.randf_range(-0.45, 0.45)), Vector3(0.34, 0.26, 0.3),
				Color(0.2, 0.19, 0.2) if r.randf() < 0.8 else Color(0.55, 0.4, 0.2), 0.2, 0.45, r.randf() * TAU)
		cols.append(["b", p, Vector2(0.6, 0.75), 0.0])
	else:
		return false
	return true


## tenda a due falde con pali incrociati, lembo d'ingresso aperto e picchetti
static func _tent(o: W3DBuilder, base: Vector3, foot: Vector2, r: RandomNumberGenerator) -> void:
	var yaw := Basis(Vector3.UP, r.randf_range(-0.25, 0.25))
	var hw := maxf(foot.x * 0.46, 0.9)
	var hd := maxf(foot.y * 0.44, 0.9)
	var high := hw * 1.15
	var cloth: Color = CANVAS[r.randi() % CANVAS.size()] * r.randf_range(0.85, 1.15)
	var at := func(x: float, y: float, z: float) -> Vector3: return base + yaw * Vector3(x, y, z)
	var front_top: Vector3 = at.call(0.0, high, hd)
	var back_top: Vector3 = at.call(0.0, high * 0.92, -hd)
	for side in [-1.0, 1.0]:
		var low_front: Vector3 = at.call(side * hw, 0.03, hd)
		var low_back: Vector3 = at.call(side * hw, 0.03, -hd)
		o.quad(low_back, low_front, front_top, back_top, o.shade(cloth * (1.0 if side > 0 else 0.82), 0.1))
		o.tri(at.call(side * hw, 0.03, hd), front_top, at.call(side * hw * 0.28, 0.03, hd + 0.16), o.shade(cloth * 1.15, 0.1))
		o.box(Transform3D(yaw, at.call(side * (hw + 0.18), 0.1, hd * 0.7)), Vector3(0.07, 0.2, 0.07), WOOD, 0.1, 8)
		o.box(Transform3D(yaw, at.call(side * (hw + 0.18), 0.1, -hd * 0.7)), Vector3(0.07, 0.2, 0.07), WOOD, 0.1, 8)
	o.tri(at.call(-hw, 0.03, -hd), at.call(hw, 0.03, -hd), back_top, o.shade(cloth * 0.7, 0.1))
	o.tri(at.call(-hw * 0.72, 0.04, hd - 0.12), at.call(hw * 0.72, 0.04, hd - 0.12), at.call(0.0, high * 0.74, hd - 0.12), Color(0.025, 0.02, 0.02))
	o.box(Transform3D(yaw, at.call(0.0, high + 0.02, 0.0)), Vector3(0.1, 0.1, hd * 2.2), WOOD, 0.1, 0)
	for side in [-1.0, 1.0]:
		o.box(Transform3D(yaw * Basis(Vector3(0, 0, 1), side * 0.42), at.call(side * 0.1, high + 0.22, hd)), Vector3(0.09, 0.62, 0.09), WOOD * 1.2, 0.1, 0)
	for i in r.randi_range(1, 3):      # toppe
		var u := r.randf_range(0.2, 0.75)
		o.box(Transform3D(yaw * Basis(Vector3(0, 0, 1), 0.72), at.call(-hw * (1.0 - u) - 0.04, high * u, r.randf_range(-hd * 0.6, hd * 0.6))),
			Vector3(0.03, 0.34, 0.3), cloth * r.randf_range(0.55, 1.5), 0.1, 0)
