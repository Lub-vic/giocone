class_name W3DProps
extends RefCounted
## Oggetti del mondo come vere geometrie 3D (case, alberi, rocce, recinti...), dimensionati sull'impronta dello sprite.
## Le unita' sono 1 = 16 px; il modello e' centrato sull'origine (x,z) e poggia su y = 0.

static func ok(kind: String) -> bool:
	for p in ["roof_", "top_dead", "top_sick", "tbig_", "boulder_", "bush_", "fence_", "lamp_top", "crate_top", "barrel_top", "hay_top",
			"sack_top", "woodpile", "wall_top", "grave_", "column_top", "skullpile", "cart_top", "bonfire", "well_top", "stall_top",
			"table_top", "hearth_top", "bed_top", "cauldron_top", "rack_top", "shelf_top", "chair_top", "rug_top", "anvil_top", "pew_top", "door_top", "stairs_top", "campfire_top", "portal", "brazier", "altar", "shrine", "res_", "qitem", "lever", "key", "dig", "candelabra", "bell", "arena_core", "mausoleum_top", "ruin_tower", "tower_top", "chapel_top", "smithy_top", "archive_top", "sanatorium_top", "mill_top", "cathedral_top", "pond_", "circle_top", "arch_top", "stump_", "log_top", "chest", "tomb", "statue_top", "signpost", "bone_"]:
		if kind.begins_with(p):
			return true
	return false


static func _lin(c: Color, k := 1.0) -> Color:
	return Color(pow(c.r, 1.1) * k * 1.25, pow(c.g, 1.1) * k * 1.25, pow(c.b, 1.1) * k * 1.25, 1.0)


static func _dk(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func build(kind: String, w: float, h: float, avg: Color, seed_v: int) -> ArrayMesh:
	var b := W3DBuilder.new()
	b.rn.seed = seed_v
	b.sat = 1.3
	b.con = 1.2
	var c := _lin(avg, 1.0)
	var rn := RandomNumberGenerator.new()
	rn.seed = seed_v
	var ident := Transform3D.IDENTITY
	if kind.begins_with("roof_"):
		_house(b, kind, w, h, c, rn)
	elif kind.begins_with("top_dead") or kind.begins_with("tbig_dead"):
		_tree(b, w, h, Color(0.14, 0.10, 0.08), c, rn, true, kind.begins_with("tbig"))
	elif kind.begins_with("top_sick") or kind.begins_with("tbig_sick"):
		_tree(b, w, h, Color(0.16, 0.12, 0.09), Color(0.10, 0.20, 0.10).lerp(c, 0.4), rn, false, kind.begins_with("tbig"))
	elif kind.begins_with("boulder_") or kind.begins_with("stump_big"):
		b.rock(Vector3(0, w * 0.2, 0), Vector3(w * 0.9, w * 0.42, h * 0.85), _dk(c, 0.9), 0.2, 0.35, rn.randf() * 6.0)
		b.rock(Vector3(w * 0.18, w * 0.1, h * 0.2), Vector3(w * 0.45, w * 0.22, h * 0.4), _dk(c, 1.2), 0.2, 0.35, rn.randf() * 6.0)
	elif kind.begins_with("bush_"):
		for i in 3:
			b.rock(Vector3((i - 1) * w * 0.22, 0.2 + i * 0.03, rn.randf_range(-0.12, 0.12)), Vector3(w * 0.5, 0.42, h * 0.5), _dk(c.lerp(Color(0.09, 0.2, 0.09), 0.4), 0.8 + 0.25 * i), 0.2, 0.4, rn.randf() * 6.0)
	elif kind.begins_with("table_top"):
		var wd := Color(0.34, 0.21, 0.12)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0)), Vector3(w * 0.9, 0.12, h * 0.78), wd, 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0)), Vector3(w * 0.84, 0.06, h * 0.7), _dk(wd, 0.6), 0.05, 0)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.38, 0.36, sz * h * 0.3)), Vector3(0.12, 0.72, 0.12), _dk(wd, 0.8), 0.05, 0)
		# sopra: una candela, un piatto e una brocca
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(-w * 0.2, 0.84, 0.05)), 0.05, 0.05, 0.22, 6, Color(0.85, 0.82, 0.7), 0.05)
		b.blob(Vector3(-w * 0.2, 1.1, 0.05), Vector3(0.04, 0.08, 0.04), Color(1.0, 0.8, 0.4, 0.1), 4, 3, 0.0, 0.0)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(w * 0.15, 0.84, -0.1)), 0.2, 0.17, 0.04, 8, Color(0.55, 0.5, 0.42), 0.05)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(w * 0.3, 0.84, 0.15)), 0.09, 0.07, 0.3, 6, Color(0.35, 0.25, 0.18), 0.05)
	elif kind.begins_with("hearth_top"):
		var st := Color(0.3, 0.29, 0.32)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, -h * 0.1)), Vector3(w, 1.9, h * 0.8), st, 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, h * 0.28)), Vector3(w * 0.62, 0.9, h * 0.4), Color(0.04, 0.03, 0.03), 0.0, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, h * 0.3)), Vector3(w * 0.8, 0.12, h * 0.5), _dk(st, 0.7), 0.08, 0)
		for q in 3:
			b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.25, 0.1 + q * 0.04, h * 0.3 + (q - 1) * 0.1)), 0.06, 0.06, 0.5, 5, Color(0.2, 0.12, 0.07), 0.06)
		b.shard(Vector3(0, 0.15, h * 0.3), Vector3(0.02, 0.85, h * 0.3), 0.32, 0.03, Color(1.0, 0.5, 0.15, 0.05), 0.4, 0.0, 0.1)
		b.shard(Vector3(0.1, 0.2, h * 0.3), Vector3(0.1, 0.6, h * 0.3), 0.18, 0.02, Color(1.0, 0.85, 0.4, 0.0), 0.4, 0.0, 0.1)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 1.9, -h * 0.1)), w * 0.3, w * 0.22, 0.6, 6, st, 0.1)
	elif kind.begins_with("bed_top"):
		var wd2 := Color(0.3, 0.19, 0.11)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(w * 0.9, 0.3, h * 0.9), wd2, 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0.05)), Vector3(w * 0.82, 0.18, h * 0.82), Color(0.62, 0.58, 0.5), 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.62, h * 0.18)), Vector3(w * 0.82, 0.12, h * 0.5), Color(0.4, 0.1, 0.12), 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.68, -h * 0.3)), Vector3(w * 0.5, 0.14, h * 0.2), Color(0.75, 0.72, 0.66), 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.7, -h * 0.47)), Vector3(w * 0.92, 0.9, 0.1), _dk(wd2, 0.85), 0.08, 0)
	elif kind.begins_with("cauldron_top"):
		for q in 3:
			var ac := TAU * q / 3.0
			b.rock(Vector3(cos(ac) * 0.35, 0.12, sin(ac) * 0.35), Vector3(0.3, 0.24, 0.3), Color(0.28, 0.27, 0.3), 0.1, 0.3, ac)
		b.shard(Vector3(0, 0.1, 0), Vector3(0, 0.6, 0), 0.28, 0.03, Color(1.0, 0.45, 0.12, 0.05), 0.4, 0.0, 0.1)
		b.blob(Vector3(0, 0.62, 0), Vector3(0.45, 0.38, 0.45), Color(0.08, 0.08, 0.1), 9, 4, 0.05, 0.02)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), 0.38, 0.38, 0.03, 9, Color(0.3, 0.95, 0.4, 0.1), 0.0)
	elif kind.begins_with("rack_top"):
		var wd3 := Color(0.26, 0.17, 0.1)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -h * 0.35)), Vector3(w * 0.95, 0.12, 0.14), wd3, 0.06, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, -h * 0.35)), Vector3(w * 0.95, 0.12, 0.14), wd3, 0.06, 0)
		for sx in [-1, 1]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.45, 0.6, -h * 0.35)), Vector3(0.12, 1.3, 0.14), wd3, 0.06, 0)
		for q in 4:
			var xx := -w * 0.32 + q * w * 0.21
			b.box(Transform3D(Basis(Vector3(0, 0, 1), 0.08 * (q - 1.5)), Vector3(xx, 0.8, -h * 0.28)), Vector3(0.08, 1.3, 0.05), Color(0.55, 0.55, 0.6), 0.06, 0)
			b.box(Transform3D(Basis.IDENTITY, Vector3(xx, 0.2, -h * 0.28)), Vector3(0.2, 0.06, 0.08), Color(0.35, 0.24, 0.14), 0.05, 0)
	elif kind.begins_with("shelf_top"):
		var wd4 := Color(0.28, 0.18, 0.1)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(w * 0.95, 1.9, h * 0.8), wd4, 0.08, 0)
		for lv in 4:
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3 + lv * 0.45, h * 0.36)), Vector3(w * 0.9, 0.05, h * 0.12), _dk(wd4, 0.6), 0.05, 0)
			for q in 5:
				var cc2 := Color(0.5, 0.2, 0.15).lerp(Color(0.2, 0.3, 0.5), float((lv * 5 + q) % 4) / 3.0)
				b.box(Transform3D(Basis.IDENTITY, Vector3(-w * 0.36 + q * w * 0.18, 0.43 + lv * 0.45, h * 0.37)), Vector3(0.12, 0.28, 0.1), cc2, 0.08, 0)
	elif kind.begins_with("chair_top"):
		var wd5 := Color(0.3, 0.19, 0.11)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(w * 0.7, 0.1, h * 0.7), wd5, 0.08, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.85, -h * 0.3)), Vector3(w * 0.7, 0.8, 0.08), _dk(wd5, 0.85), 0.08, 0)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.28, 0.2, sz * h * 0.28)), Vector3(0.08, 0.4, 0.08), _dk(wd5, 0.7), 0.05, 0)
	elif kind.begins_with("rug_top"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.015, 0)), Vector3(w * 0.94, 0.03, h * 0.94), _dk(avg, 0.55), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.035, 0)), Vector3(w * 0.8, 0.02, h * 0.8), _lin(avg, 1.1), 0.08, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(w * 0.5, 0.02, h * 0.3), _dk(avg, 0.8), 0.06, 0)
	elif kind.begins_with("anvil_top"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.3, 0.26, 0.55, 8, Color(0.3, 0.2, 0.12), 0.1)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0)), Vector3(0.9, 0.2, 0.34), Color(0.16, 0.16, 0.19), 0.06, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.55, 0.7, 0)), Vector3(0.3, 0.1, 0.2), Color(0.18, 0.18, 0.21), 0.06, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(0.5, 0.14, 0.3), Color(0.14, 0.14, 0.17), 0.06, 0)
	elif kind.begins_with("pew_top"):
		var wd6 := Color(0.27, 0.17, 0.1)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0.05)), Vector3(w * 0.95, 0.1, h * 0.5), wd6, 0.08, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.85, -h * 0.28)), Vector3(w * 0.95, 0.8, 0.08), _dk(wd6, 0.85), 0.08, 0)
		for sx in [-1, 1]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.46, 0.4, 0)), Vector3(0.1, 0.8, h * 0.7), _dk(wd6, 0.7), 0.06, 0)
	elif kind.begins_with("door_top"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), Vector3(w * 0.95, 2.0, 0.3), Color(0.2, 0.12, 0.07), 0.06, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0.17)), Vector3(w * 0.7, 1.8, 0.06), Color(0.32, 0.2, 0.11), 0.06, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(w * 0.22, 0.9, 0.22)), Vector3(0.08, 0.08, 0.06), Color(0.8, 0.65, 0.2), 0.0, 0)
	elif kind.begins_with("stairs_top"):
		for q in 5:
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.1 - q * 0.0, -h * 0.4 + q * h * 0.2)), Vector3(w * 0.9, 0.12 + (4 - q) * 0.0, h * 0.2), Color(0.26, 0.25, 0.28).lerp(Color(0.12, 0.12, 0.14), q / 4.0), 0.1, 0)
	elif kind.begins_with("campfire_top"):
		for q in 6:
			var a4 := TAU * q / 6.0
			b.cyl(Transform3D(Basis(Vector3.UP, a4) * Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(cos(a4) * 0.15, 0.1, sin(a4) * 0.15)), 0.07, 0.07, 0.6, 5, Color(0.2, 0.12, 0.07), 0.1)
		b.shard(Vector3(0, 0.15, 0), Vector3(0, 1.0, 0), 0.3, 0.04, Color(1.0, 0.5, 0.15, 0.05), 0.4, 0.0, 0.1)
	elif kind == "portal":
		for sx in [-1, 1]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(sx * 0.62, 0.9, 0)), Vector3(0.36, 1.8, 0.4), Color(0.22, 0.21, 0.25), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.95, 0)), Vector3(1.6, 0.4, 0.42), Color(0.26, 0.25, 0.3), 0.14, 0)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), 0.6, 0.6, 0.04, 14, Color(0.55, 0.35, 0.95, 0.1), 0.0)
		b.shard(Vector3(0, 0.1, 0), Vector3(0, 1.8, 0), 0.5, 0.2, Color(0.6, 0.4, 1.0, 0.04), 0.4, 0.0, 0.1)
	elif kind == "brazier":
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.1, 0.07, 0.8, 6, Color(0.14, 0.12, 0.12), 0.08)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), 0.34, 0.42, 0.24, 8, Color(0.16, 0.14, 0.14), 0.08)
		b.shard(Vector3(0, 0.95, 0), Vector3(0, 1.5, 0), 0.3, 0.03, Color(1.0, 0.5, 0.15, 0.06), 0.4, 0.0, 0.1)
	elif kind == "altar":
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Vector3(1.6, 0.9, 0.9), Color(0.24, 0.23, 0.27), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.96, 0)), Vector3(1.8, 0.12, 1.05), Color(0.3, 0.29, 0.33), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.06, 0)), Vector3(0.9, 0.04, 0.4), Color(0.5, 0.1, 0.12), 0.1, 0)
	elif kind == "shrine":
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(0.9, 0.6, 0.9), Color(0.25, 0.24, 0.28), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Vector3(0.5, 0.8, 0.5), Color(0.3, 0.29, 0.33), 0.14, 0)
		b.blob(Vector3(0, 1.55, 0), Vector3(0.22, 0.22, 0.22), Color(0.6, 0.9, 1.0, 0.1), 6, 3, 0.0, 0.0)
	elif kind.begins_with("res_"):
		if kind == "res_legna":
			for i in 3:
				b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-0.35, 0.1 + (i / 2) * 0.17, (i % 2) * 0.2 - 0.1)), 0.09, 0.09, 0.7, 6, Color(0.3, 0.2, 0.12), 0.1)
		elif kind == "res_fungo":
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.05, 0.06, 0.3, 5, Color(0.7, 0.7, 0.6), 0.08)
			b.blob(Vector3(0, 0.34, 0), Vector3(0.28, 0.16, 0.28), Color(0.45, 0.3, 0.7), 7, 3, 0.1, 0.04)
		else:
			for i in 6:
				var a := TAU * i / 6.0
				b.shard(Vector3(cos(a) * 0.08, 0, sin(a) * 0.08), Vector3(cos(a) * 0.25, 0.5, sin(a) * 0.25), 0.1, 0.01, Color(0.12, 0.3, 0.1), 0.2, 0.1, 0.1)
	elif kind == "qitem":
		b.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.25, 0)), Vector3(0.4, 0.4, 0.4), Color(1.0, 0.85, 0.4, 0.1), 0.0, 0)
		b.shard(Vector3(0, 0.4, 0), Vector3(0, 1.4, 0), 0.25, 0.02, Color(1.0, 0.85, 0.4, 0.06), 0.4, 0.0, 0.1)
	elif kind == "lever":
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)), Vector3(0.5, 0.3, 0.4), Color(0.2, 0.2, 0.23), 0.1, 0)
		b.cyl(Transform3D(Basis(Vector3(0, 0, 1), -0.5), Vector3(0, 0.3, 0)), 0.05, 0.05, 0.7, 5, Color(0.4, 0.28, 0.16), 0.08)
		b.blob(Vector3(0.3, 0.95, 0), Vector3(0.1, 0.1, 0.1), Color(0.7, 0.15, 0.1), 5, 3, 0.0, 0.0)
	elif kind == "key":
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(-0.2, 0.1, 0)), 0.14, 0.14, 0.05, 8, Color(1.0, 0.85, 0.3, 0.1), 0.0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.15, 0.12, 0)), Vector3(0.5, 0.05, 0.07), Color(1.0, 0.85, 0.3, 0.1), 0.0, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.32, 0.12, 0.08)), Vector3(0.07, 0.05, 0.12), Color(1.0, 0.85, 0.3, 0.1), 0.0, 0)
	elif kind == "dig":
		b.rock(Vector3(0, 0.13, 0.1), Vector3(0.9, 0.26, 1.1), Color(0.18, 0.13, 0.09), 0.2, 0.3, 0.0)
		b.cyl(Transform3D(Basis(Vector3(1, 0, 0), 0.5), Vector3(0.3, 0.1, -0.4)), 0.03, 0.03, 0.9, 5, Color(0.3, 0.2, 0.12), 0.08)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.3, 0.1, -0.1)), Vector3(0.2, 0.04, 0.25), Color(0.4, 0.4, 0.44), 0.08, 0)
	elif kind == "candelabra":
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.2, 0.08, 0.15, 6, Color(0.5, 0.4, 0.15), 0.08)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)), 0.05, 0.05, 1.1, 5, Color(0.5, 0.4, 0.15), 0.08)
		for q in 3:
			var a2 := TAU * q / 3.0
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(cos(a2) * 0.3, 1.1, sin(a2) * 0.3)), 0.04, 0.04, 0.25, 5, Color(0.8, 0.78, 0.7), 0.08)
			b.blob(Vector3(cos(a2) * 0.3, 1.45, sin(a2) * 0.3), Vector3(0.05, 0.1, 0.05), Color(1.0, 0.8, 0.4, 0.1), 4, 3, 0.0, 0.0)
	elif kind == "bell":
		b.box(Transform3D(Basis.IDENTITY, Vector3(-0.5, 0.9, 0)), Vector3(0.14, 1.8, 0.14), Color(0.22, 0.14, 0.09), 0.08, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.5, 0.9, 0)), Vector3(0.14, 1.8, 0.14), Color(0.22, 0.14, 0.09), 0.08, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.8, 0)), Vector3(1.2, 0.14, 0.14), Color(0.22, 0.14, 0.09), 0.08, 0)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), 0.4, 0.15, 0.7, 8, Color(0.6, 0.45, 0.15), 0.08)
	elif kind == "arena_core":
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.8, 0.7, 0.3, 10, Color(0.2, 0.18, 0.24), 0.1)
		b.blob(Vector3(0, 0.9, 0), Vector3(0.4, 0.5, 0.4), Color(0.9, 0.3, 0.2, 0.1), 7, 4, 0.0, 0.0)
		for q in 4:
			var a3 := TAU * q / 4.0 + 0.4
			b.box(Transform3D(Basis(Vector3.UP, -a3), Vector3(cos(a3) * 0.9, 0.6, sin(a3) * 0.9)), Vector3(0.18, 1.2, 0.18), Color(0.24, 0.22, 0.28), 0.1, 0)
	elif kind.begins_with("fence_h"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(w, 0.07, 0.07), Color(0.12, 0.11, 0.13), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(w, 0.07, 0.07), Color(0.12, 0.11, 0.13), 0.05, 0)
		for i in 3:
			var x := (i - 1) * (w * 0.5 - 0.05)
			b.box(Transform3D(Basis.IDENTITY, Vector3(x, 0.38, 0)), Vector3(0.09, 0.76, 0.09), Color(0.15, 0.14, 0.16), 0.05, 0)
			b.shard(Vector3(x, 0.74, 0), Vector3(x, 0.92, 0), 0.07, 0.01, Color(0.2, 0.19, 0.22), 0.2, 0.0, 0.0)
	elif kind.begins_with("fence_v"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(0.07, 0.07, h), Color(0.12, 0.11, 0.13), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(0.07, 0.07, h), Color(0.12, 0.11, 0.13), 0.05, 0)
		for i in 3:
			var z := (i - 1) * (h * 0.5 - 0.05)
			b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.38, z)), Vector3(0.09, 0.76, 0.09), Color(0.15, 0.14, 0.16), 0.05, 0)
			b.shard(Vector3(0, 0.74, z), Vector3(0, 0.92, z), 0.07, 0.01, Color(0.2, 0.19, 0.22), 0.2, 0.0, 0.0)
	elif kind.begins_with("lamp_top"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.09, 0.06, 1.35, 6, Color(0.14, 0.12, 0.12), 0.05)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), Vector3(0.3, 0.32, 0.3), Color(1.0, 0.7, 0.35, 0.1), 0.0, 0)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 1.66, 0)), 0.22, 0.04, 0.12, 6, Color(0.14, 0.12, 0.12), 0.05)
	elif kind.begins_with("crate_top"):
		b.box(Transform3D(Basis(Vector3.UP, rn.randf_range(-0.3, 0.3)), Vector3(0, 0.3, 0)), Vector3(w * 0.85, 0.6, h * 0.8), Color(0.24, 0.16, 0.10), 0.12, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.62, 0)), Vector3(w * 0.9, 0.05, 0.1), Color(0.14, 0.09, 0.06), 0.05, 0)
	elif kind.begins_with("barrel_top"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), w * 0.38, w * 0.42, 0.7, 8, Color(0.26, 0.17, 0.10), 0.1)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), w * 0.43, w * 0.43, 0.06, 8, Color(0.12, 0.11, 0.12), 0.04, false)
	elif kind.begins_with("hay_top"):
		b.rock(Vector3(0, 0.3, 0), Vector3(w * 0.9, 0.6, h * 0.85), Color(0.46, 0.38, 0.14), 0.18, 0.2, rn.randf() * 3.0)
	elif kind.begins_with("sack_top"):
		b.blob(Vector3(0, 0.22, 0), Vector3(w * 0.4, 0.28, h * 0.4), Color(0.30, 0.25, 0.16), 6, 3, 0.1, 0.04)
	elif kind.begins_with("woodpile"):
		for i in 4:
			b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-h * 0.1, 0.1 + (i / 2) * 0.17, (i % 2) * 0.2 - 0.1 + (i / 2) * 0.1)), 0.09, 0.09, w * 0.8, 6, Color(0.20, 0.13, 0.08), 0.1)
	elif kind.begins_with("wall_top"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(w, 1.1, h), _dk(c, 0.85), 0.14, 0)
		for i in int(maxf(w, h) * 1.6):
			var along := (i / (maxf(w, h) * 1.6) - 0.5) * maxf(w, h)
			var p := Vector3(along if w >= h else 0.0, 1.2, 0.0 if w >= h else along)
			if rn.randf() > 0.4:
				b.box(Transform3D(Basis(Vector3.UP, rn.randf() * 0.6), p), Vector3(0.24, 0.2 + rn.randf() * 0.2, 0.24), _dk(c, 1.1), 0.18, 0)
	elif kind.begins_with("grave_cross"):
		b.rock(Vector3(0, 0.05, 0.3), Vector3(0.7, 0.14, 0.9), Color(0.13, 0.10, 0.07), 0.15, 0.3, 0.0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(0.12, 1.0, 0.1), Color(0.34, 0.32, 0.33), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0)), Vector3(0.52, 0.12, 0.1), Color(0.34, 0.32, 0.33), 0.14, 0)
	elif kind.begins_with("grave_mound"):
		b.rock(Vector3(0, 0.13, 0.25), Vector3(0.9, 0.28, 1.2), Color(0.14, 0.11, 0.08), 0.2, 0.3, rn.randf())
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.34, -0.4)), Vector3(0.5, 0.7, 0.12), Color(0.33, 0.32, 0.34), 0.14, 0)
		b.rock(Vector3(0, 0.74, -0.4), Vector3(0.5, 0.14, 0.14), Color(0.33, 0.32, 0.34), 0.1, 0.2, 0.0)
	elif kind.begins_with("grave_slab"):
		b.box(Transform3D(Basis(Vector3.UP, rn.randf_range(-0.1, 0.1)), Vector3(0, 0.07, 0)), Vector3(w * 0.8, 0.14, h * 0.85), Color(0.30, 0.29, 0.31), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -h * 0.28)), Vector3(w * 0.7, 0.07, 0.09), Color(0.2, 0.19, 0.21), 0.05, 0)
	elif kind.begins_with("column_top") or kind.begins_with("statue_top"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), w * 0.42, w * 0.42, 0.22, 8, Color(0.28, 0.27, 0.30), 0.1)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.22, 0)), w * 0.3, w * 0.26, 1.7, 8, Color(0.34, 0.33, 0.36), 0.1)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 1.9, 0)), w * 0.4, w * 0.4, 0.2, 8, Color(0.30, 0.29, 0.32), 0.1)
		if kind.begins_with("statue_top"):
			b.blob(Vector3(0, 2.3, 0), Vector3(0.3, 0.38, 0.3), Color(0.32, 0.31, 0.34), 6, 4, 0.1, 0.05)
	elif kind.begins_with("skullpile") or kind.begins_with("bone_"):
		for i in 5:
			b.blob(Vector3(rn.randf_range(-w * 0.3, w * 0.3), 0.1 + (i / 3) * 0.12, rn.randf_range(-h * 0.3, h * 0.3)), Vector3(0.14, 0.12, 0.14), Color(0.62, 0.58, 0.5), 5, 3, 0.1, 0.05)
		b.box(Transform3D(Basis(Vector3.UP, rn.randf() * 3.0), Vector3(0, 0.05, 0)), Vector3(w * 0.7, 0.07, 0.08), Color(0.6, 0.57, 0.5), 0.1, 0)
	elif kind.begins_with("cart_top"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.42, 0)), Vector3(w * 0.85, 0.34, h * 0.7), Color(0.22, 0.14, 0.09), 0.1, 0)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.cyl(Transform3D(Basis(Vector3(1, 0, 0), PI * 0.5), Vector3(sx * w * 0.3, 0.3, sz * h * 0.4)), 0.3, 0.3, 0.07, 8, Color(0.12, 0.09, 0.07), 0.08)
		b.box(Transform3D(Basis.IDENTITY, Vector3(w * 0.5, 0.35, 0)), Vector3(w * 0.3, 0.06, 0.08), Color(0.2, 0.13, 0.08), 0.05, 0)
	elif kind.begins_with("bonfire"):
		for i in 5:
			var a := TAU * i / 5.0
			b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, a), Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15)), 0.07, 0.07, 0.6, 5, Color(0.2, 0.12, 0.07), 0.1)
		b.shard(Vector3(0, 0.15, 0), Vector3(0, 1.1, 0), 0.34, 0.05, Color(1.0, 0.5, 0.15, 0.04), 0.4, 0.0, 0.1)
		b.shard(Vector3(0, 0.2, 0), Vector3(0.03, 0.8, 0), 0.2, 0.03, Color(1.0, 0.85, 0.45, 0.0), 0.4, 0.0, 0.1)
	elif kind.begins_with("well_top"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), w * 0.42, w * 0.42, 0.6, 10, Color(0.26, 0.25, 0.27), 0.1)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.58, 0)), w * 0.28, w * 0.28, 0.03, 10, Color(0.03, 0.05, 0.08), 0.0)
		for sx in [-1, 1]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.38, 0.9, 0)), Vector3(0.1, 0.9, 0.1), Color(0.2, 0.13, 0.08), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.4, 0)), Vector3(w * 0.9, 0.1, 0.3), Color(0.2, 0.13, 0.08), 0.05, 0)
	elif kind.begins_with("stall_top"):
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.box(Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.42), 0.75, sz * (h * 0.4))), Vector3(0.1, 1.5, 0.1), Color(0.2, 0.13, 0.08), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(w * 0.8, 0.12, h * 0.55), Color(0.26, 0.17, 0.1), 0.08, 0)
		_gable(b, w, h, 1.5, 0.5, _dk(c, 0.9), 0.0)
	elif kind.begins_with("pond_"):
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), w * 0.46, w * 0.46, 0.04, 12, Color(0.05, 0.1, 0.13, 1.0), 0.04)
		for i in 9:
			var a2 := TAU * i / 9.0
			b.rock(Vector3(cos(a2) * w * 0.47, 0.08, sin(a2) * h * 0.47), Vector3(0.35, 0.18, 0.3), Color(0.22, 0.22, 0.24), 0.14, 0.3, a2)
	elif kind.begins_with("circle_top"):
		for i in 8:
			var a3 := TAU * i / 8.0
			b.box(Transform3D(Basis(Vector3.UP, a3), Vector3(cos(a3) * w * 0.4, 0.7, sin(a3) * h * 0.4)), Vector3(0.3, 1.4 - (i % 3) * 0.3, 0.24), Color(0.26, 0.25, 0.28), 0.16, 0)
		b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), w * 0.2, w * 0.2, 0.06, 10, Color(0.5, 0.25, 0.8, 0.2), 0.0)
	elif kind.begins_with("arch_top"):
		for sx in [-1, 1]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(sx * w * 0.36, 1.4, 0)), Vector3(0.7, 2.8, 0.7), Color(0.26, 0.25, 0.28), 0.14, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 2.9, 0)), Vector3(w * 0.9, 0.55, 0.8), Color(0.28, 0.27, 0.3), 0.14, 0)
	elif kind.begins_with("mausoleum_top") or kind.begins_with("ruin_tower") or kind.begins_with("tower_top"):
		var hh := 2.2 if kind.begins_with("mausoleum") else 3.6
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, hh * 0.5, 0)), Vector3(w * 0.8, hh, h * 0.8), Color(0.24, 0.23, 0.26), 0.14, 0)
		for i in 6:
			var a := TAU * i / 6.0
			b.box(Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * w * 0.33, hh + 0.12 + rn.randf() * 0.2, sin(a) * h * 0.33)), Vector3(0.3, 0.3 + rn.randf() * 0.4, 0.3), Color(0.28, 0.27, 0.3), 0.18, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, h * 0.4)), Vector3(0.7, 1.1, 0.06), Color(0.02, 0.02, 0.03), 0.0, 0)
	elif kind.begins_with("stump_") or kind.begins_with("log_top"):
		if kind.begins_with("log_top"):
			b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-w * 0.45, 0.2, 0)), 0.2, 0.18, w * 0.9, 7, Color(0.19, 0.12, 0.08), 0.12)
		else:
			b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), w * 0.4, w * 0.3, 0.5, 8, Color(0.19, 0.12, 0.08), 0.12)
	elif kind.begins_with("chest"):
		# baule vero: corpo di legno, coperchio ARCUATO, fasce di ferro, serratura d'oro luminosa (non una scatola)
		var wood := Color(0.30, 0.17, 0.08)
		var iron := Color(0.15, 0.15, 0.18)
		var bw := w * 0.86
		var bd := h * 0.62
		var r := bd * 0.5
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), Vector3(bw, 0.4, bd), wood, 0.1, 0)
		b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(bw * 0.5, 0.4, 0)), r, r, bw, 8, _dk(wood, 1.25), 0.1)
		for x in [-0.34, 0.0, 0.34]:
			b.box(Transform3D(Basis.IDENTITY, Vector3(x * bw, 0.2, 0)), Vector3(0.08, 0.42, bd + 0.04), iron, 0.05, 0)
			b.cyl(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(x * bw + 0.04, 0.4, 0)), r + 0.025, r + 0.025, 0.08, 8, iron, 0.05)
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				b.box(Transform3D(Basis.IDENTITY, Vector3(sx * bw * 0.5, 0.06, sz * bd * 0.5)), Vector3(0.1, 0.12, 0.1), iron, 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.38, bd * 0.5 + 0.03)), Vector3(0.14, 0.18, 0.06), Color(1.0, 0.78, 0.25, 0.3), 0.0, 0)
	elif kind.begins_with("tomb"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Vector3(w * 0.8, 0.55, h * 0.7), Color(0.26, 0.25, 0.27), 0.1, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.62, 0)), Vector3(w * 0.84, 0.14, h * 0.74), Color(0.3, 0.29, 0.31), 0.1, 0)
	elif kind.begins_with("signpost"):
		b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Vector3(0.1, 1.2, 0.1), Color(0.2, 0.13, 0.08), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(0.2, 1.0, 0)), Vector3(0.8, 0.28, 0.06), Color(0.26, 0.18, 0.1), 0.05, 0)
	var m := b.mesh()
	return m


## tetto a due falde con colmo lungo l'asse piu' lungo
static func _gable(b: W3DBuilder, w: float, h: float, y0: float, rise: float, col: Color, over: float) -> void:
	var hw := w * 0.5 + over
	var hd := h * 0.5 + over
	var rc := _dk(col, 0.6)
	if w >= h:
		var yr := y0 + rise
		b.quad(Vector3(-hw, y0, -hd), Vector3(hw, y0, -hd), Vector3(hw, yr, 0), Vector3(-hw, yr, 0), col)
		b.quad(Vector3(-hw, yr, 0), Vector3(hw, yr, 0), Vector3(hw, y0, hd), Vector3(-hw, y0, hd), rc)
		b.tri(Vector3(-hw, y0, -hd), Vector3(-hw, yr, 0), Vector3(-hw, y0, hd), _dk(col, 0.6))
		b.tri(Vector3(hw, y0, hd), Vector3(hw, yr, 0), Vector3(hw, y0, -hd), _dk(col, 0.6))
	else:
		var yr2 := y0 + rise
		b.quad(Vector3(-hw, y0, -hd), Vector3(0, yr2, -hd), Vector3(0, yr2, hd), Vector3(-hw, y0, hd), col)
		b.quad(Vector3(0, yr2, -hd), Vector3(hw, y0, -hd), Vector3(hw, y0, hd), Vector3(0, yr2, hd), rc)
		b.tri(Vector3(-hw, y0, -hd), Vector3(0, yr2, -hd), Vector3(hw, y0, -hd), _dk(col, 0.6))
		b.tri(Vector3(hw, y0, hd), Vector3(0, yr2, hd), Vector3(-hw, y0, hd), _dk(col, 0.6))


static func _house(b: W3DBuilder, kind: String, w: float, h: float, c: Color, rn: RandomNumberGenerator) -> void:
	var ident := Transform3D.IDENTITY
	var wall_h := 1.5 + 0.12 * minf(w, h)
	var wc := Color(0.30, 0.25, 0.21)
	if kind.contains("slate") or kind.contains("rust"):
		wc = Color(0.27, 0.26, 0.29)
	b.box(Transform3D(Basis.IDENTITY, Vector3(0, wall_h * 0.5, 0)), Vector3(w - 0.3, wall_h, h - 0.3), wc, 0.1, 0)
	# travi a vista sulle pareti
	var hw := (w - 0.3) * 0.5
	var hd := (h - 0.3) * 0.5
	for i in 4:
		var x := lerpf(-hw + 0.2, hw - 0.2, i / 3.0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(x, wall_h * 0.5, hd + 0.02)), Vector3(0.1, wall_h, 0.05), Color(0.10, 0.07, 0.05), 0.05, 0)
		b.box(Transform3D(Basis.IDENTITY, Vector3(x, wall_h * 0.5, -hd - 0.02)), Vector3(0.1, wall_h, 0.05), Color(0.10, 0.07, 0.05), 0.05, 0)
	# finestre che brillano tenui e porta
	for i in maxi(1, int(w / 1.8)):
		var xw := lerpf(-hw + 0.7, hw - 0.7, (i + 0.5) / maxf(1.0, int(w / 1.8)))
		b.box(Transform3D(Basis.IDENTITY, Vector3(xw, wall_h * 0.55, hd + 0.03)), Vector3(0.3, 0.32, 0.05), Color(1.0, 0.72, 0.38, 0.3), 0.0, 0)
	b.box(Transform3D(Basis.IDENTITY, Vector3(hw * 0.4, 0.45, -hd - 0.03)), Vector3(0.42, 0.9, 0.05), Color(0.08, 0.05, 0.04), 0.0, 0)
	var rise := 0.5 + 0.2 * minf(w, h)
	var rcol := _dk(c, 0.95)
	_gable(b, w, h, wall_h, rise, rcol, 0.0)
	# comignolo
	var cx := rn.randf_range(-w * 0.25, w * 0.25)
	b.box(Transform3D(Basis.IDENTITY, Vector3(cx, wall_h + rise * 0.8 + 0.25, 0)), Vector3(0.34, 0.9, 0.34), Color(0.17, 0.15, 0.16), 0.1, 0)


static func _tree(b: W3DBuilder, w: float, h: float, trunk: Color, leaf: Color, rn: RandomNumberGenerator, dead: bool, big: bool) -> void:
	var ident := Transform3D.IDENTITY
	var th := (2.2 if not big else 3.4) + rn.randf() * 0.6
	b.cyl(Transform3D(Basis.IDENTITY, Vector3.ZERO), 0.2 if not big else 0.34, 0.1 if not big else 0.16, th, 7, trunk, 0.1)
	var n := 7 if not big else 12
	if dead:
		# rami nudi: schegge storte che partono dal tronco
		for i in n:
			var a := rn.randf() * TAU
			var l := w * (0.3 + rn.randf() * 0.3)
			var y0 := th * (0.55 + rn.randf() * 0.4)
			var p1 := Vector3(cos(a) * l, y0 + rn.randf_range(0.0, 0.7), sin(a) * l)
			b.shard(Vector3(0, y0, 0), p1, 0.12, 0.02, trunk, 0.4, 0.1, 0.1)
			var mid := Vector3(p1.x * 0.6, p1.y, p1.z * 0.6)
			b.shard(mid, mid + Vector3(cos(a + 0.8) * l * 0.4, 0.4, sin(a + 0.8) * l * 0.4), 0.06, 0.01, trunk, 0.4, 0.1, 0.1)
	else:
		for i in n:
			var a2 := rn.randf() * TAU
			var r := w * 0.22 * rn.randf()
			b.blob(Vector3(cos(a2) * r, th + 0.3 + rn.randf() * 0.9, sin(a2) * r), Vector3(w * 0.28, 0.6 + rn.randf() * 0.3, w * 0.28), _dk(leaf, 0.75 + rn.randf() * 0.5), 6, 3, 0.15, 0.1)
