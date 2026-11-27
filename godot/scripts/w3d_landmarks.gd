class_name W3DLandmarks
extends RefCounted
## Un solo mondo, una zona alla volta. In una zona unificata:
##  - il 3D disegna cio' che la logica piazza (stesse celle, collisioni e porte);
##  - nelle aree riservate (cimitero, cattedrale) non vi aggiunge case, alberi o massi propri;
##  - intorno la sua natura resta, e le sue collisioni vengono segnate anche nella logica.
## Una zona si aggiunge a ZONES dopo averne confrontato l'aspetto prima e dopo.

## zone unificate: nome, indice della regione (SEEDS) e rettangolo di celle relativo al suo centro
const ZONES := [
	{"name": "cimitero e cattedrale", "seed": 1, "rect": Rect2i(-32, -12, 47, 35)},
]
## edifici della mappa che hanno una porta (le case del villaggio ricevono la loro dal 3D)
const DOORED := ["chapel_top", "mausoleum_top"]

const STONE := Color(0.29, 0.28, 0.31)
const DARK := Color(0.02, 0.015, 0.025)
const IRON := Color(0.11, 0.11, 0.13)
const SLATE := Color(0.14, 0.15, 0.19)


## area in cui esiste solo cio' che piazza la logica: il recinto del cimitero e la cattedrale con il suo sagrato
static func reserved_for_map(m, cell: Vector2i, margin := 0) -> bool:
	var yard := Rect2i((m.SEEDS[1] as Vector2i) + Vector2i(-10, -8), Vector2i(21, 20))
	return yard.grow(margin).has_point(cell) or (m.cathedral_rect() as Rect2i).grow(2 + margin).has_point(cell)


static func in_zone(m, cell: Vector2i, margin := 0) -> bool:
	for z in ZONES:
		var r: Rect2i = z["rect"]
		if Rect2i((m.SEEDS[int(z["seed"])] as Vector2i) + r.position, r.size).grow(margin).has_point(cell):
			return true
	return false


## arredo che lascia libere le vie principali: dove una via attraversa il recinto resta un varco
const CLEARS_ROAD := ["fence_", "grave_", "skullpile", "boulder", "lamp_top", "top_dead", "top_sick", "tbig_", "tree"]


static func would_block_road(m, name: String, cell: Vector2i, footprint: Vector2i) -> bool:
	if not in_zone(m, cell):
		return false
	var movable := false
	for prefix: String in CLEARS_ROAD:
		movable = movable or name.begins_with(prefix)
	if not movable:
		return false
	# tombe, massi e alberi in 3D sporgono dalla propria cella; la cancellata no
	var reach := 0 if name.begins_with("fence_") else 1
	for y in range(cell.y - reach, cell.y + footprint.y + reach):
		for x in range(cell.x - reach, cell.x + footprint.x + reach):
			var q := Vector2i(x, y)
			# road_keep sono i sentieri secondari, gia' protetti; qui contano le vie principali
			if m.inb(q) and m.road[m.idx(q)] == 1 and not m.road_keep.has(q) and m.on_main_road(q):
				return true
	return false


## annota un oggetto che la logica sta piazzando in una zona unificata
static func record(m, name: String, cell: Vector2i, footprint: Vector2i) -> void:
	if not in_zone(m, cell):
		return
	m.landmarks.append({"n": name, "c": cell, "f": footprint})
	for prefix: String in DOORED:
		if name.begins_with(prefix):
			m.register_door(name, cell, footprint)
			m.map_doors.append(m.doors.back())


## righe dei muri laterali in cui passa una via principale: li' si aprono i portali del transetto.
## Restituisce due insiemi (muro ovest, muro est) di righe relative all'ingombro.
static func transept_rows(m, cell: Vector2i, footprint: Vector2i) -> Array:
	var out: Array = [{}, {}]
	for side in 2:
		var x := 0 if side == 0 else footprint.x - 1
		for y in range(-1, footprint.y - 4):
			if m.on_main_road(cell + Vector2i(x, y)):
				for dy in range(-1, 2):
					if y + dy >= 1:
						out[side][y + dy] = true
	return out


## la cattedrale e' una rovina in cui si entra: nella logica restano occupati i muri e le colonne, come nel 3D
static func cathedral_cells(cell: Vector2i, footprint: Vector2i, openings: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var w := footprint.x
	var h := footprint.y
	for y in h:
		for x in w:
			var side: bool = (x == 0 and not openings[0].has(y)) or (x == w - 1 and not openings[1].has(y))
			var apse := y == 0
			var facade := y == h - 1 and absi(x - w / 2) > 1          # il portale resta aperto
			var tower := y >= h - 4 and (x <= 2 or x >= w - 3)
			var column := (x == 3 or x == w - 4) and y >= 4 and y <= h - 7 and (y - 4) % 3 == 0
			if side or apse or facade or tower or column:
				out.append(cell + Vector2i(x, y))
	return out


## centro dell'ingombro in coordinate del motore 3D: decide in quale blocco 3D viene costruito
static func anchor(entry: Dictionary, world_off: Vector2) -> Vector2:
	return Vector2(entry["c"]) + Vector2(entry["f"]) * 0.5 - world_off


static func build(sk, entry: Dictionary, o: W3DBuilder, cols: Array, lamps: Array) -> void:
	var name := str(entry["n"])
	var cell: Vector2i = entry["c"]
	var foot: Vector2i = entry["f"]
	var p := anchor(entry, sk.world_off)
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector3i(cell.x, cell.y, foot.x * 31 + foot.y))
	o.rn.seed = r.seed + 1
	if name.begins_with("cathedral_top"):
		_cathedral(o, Vector2(cell) - sk.world_off, Vector2(foot), transept_rows(sk.gm, cell, foot), r, cols, lamps)
	elif name.begins_with("chapel_top"):
		# la facciata cade sul lato sud dell'ingombro, dove si trova la porta; il campanile sta a nord
		sk._chapel(o, p + Vector2(0.0, foot.y * 0.5 - 4.4), 0.0, r, cols, lamps)
	elif name.begins_with("mausoleum_top"):
		_scaled(sk, o, p + Vector2(0.0, -0.4), 0.7, r, cols, lamps)
	elif name.begins_with("grave_"):
		sk._grave_item(o, p + Vector2(r.randf_range(-0.12, 0.12), r.randf_range(-0.2, 0.2)), r, cols, lamps)
	elif name.begins_with("fence_"):
		_railing(o, p, name.begins_with("fence_h"), name.contains("iron"), r, cols)
	elif name.begins_with("top_dead") or name.begins_with("top_sick") or name.begins_with("tbig_") or name == "tree":
		sk._dead_tree(o, p, r, cols)
	elif name.begins_with("lamp_top"):
		sk._ed_make("lamp", o, p, 0.0, r, cols, lamps)
	elif name.begins_with("boulder"):
		var s := 0.42 * maxf(foot.x, foot.y)
		o.rock(Vector3(p.x, s * 0.55, p.y), Vector3(s * 1.9, s * 1.25, s * 1.7), STONE * r.randf_range(0.75, 1.1), 0.18, 0.45, r.randf() * TAU)
		cols.append(["c", p, s * 0.85])
	elif name.begins_with("skullpile"):
		for i in r.randi_range(7, 11):
			sk._bone(o, Vector3(p.x + r.randf_range(-0.55, 0.55), 0.08 + r.randf() * 0.2, p.y + r.randf_range(-0.55, 0.55)))
		o.rock(Vector3(p.x, 0.22, p.y), Vector3(0.45, 0.38, 0.4), Color(0.6, 0.57, 0.48), 0.1, 0.25, r.randf() * TAU)
		cols.append(["c", p, 0.4])
	else:
		# oggetti senza modello dedicato: un cumulo di macerie grande quanto l'ingombro
		for i in 3 + foot.x * foot.y:
			var q := p + Vector2(r.randf_range(-0.4, 0.4) * foot.x, r.randf_range(-0.4, 0.4) * foot.y)
			var s := r.randf_range(0.25, 0.6)
			o.rock(Vector3(q.x, s * 0.4, q.y), Vector3(s * 1.4, s, s * 1.2), STONE * r.randf_range(0.6, 1.0), 0.16, 0.4, r.randf() * TAU)
		cols.append(["b", p, Vector2(foot) * 0.42, 0.0])


## il mausoleo del motore e' piu' largo dell'ingombro della mappa: si costruisce a parte e si rimpicciolisce
static func _scaled(sk, o: W3DBuilder, p: Vector2, k: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var part := W3DBuilder.new()
	part.rn = o.rn
	part.sat = o.sat
	part.con = o.con
	part.gain = o.gain
	var own_cols: Array = []
	var own_lamps: Array = []
	sk._mausoleum(part, p, 0.0, r, own_cols, own_lamps)
	var centre := Vector3(p.x, 0.0, p.y)
	for v in part.v:
		o.v.append(centre + (v - centre) * k)
	o.c.append_array(part.c)
	for cl: Array in own_cols:
		var at: Vector2 = p + ((cl[1] as Vector2) - p) * k
		cols.append(["b", at, (cl[2] as Vector2) * k, cl[3]])
	for l: Vector4 in own_lamps:
		var at3 := centre + (Vector3(l.x, l.y, l.z) - centre) * k
		lamps.append(Vector4(at3.x, at3.y, at3.z, l.w))


## una cella di cancellata: pali con punte, due correnti e sbarre, qualcuna storta o mancante
static func _railing(o: W3DBuilder, p: Vector2, horizontal: bool, iron: bool, r: RandomNumberGenerator, cols: Array) -> void:
	var along := Vector3(1, 0, 0) if horizontal else Vector3(0, 0, 1)
	var basis := Basis.IDENTITY if horizontal else Basis(Vector3.UP, PI * 0.5)
	var centre := Vector3(p.x, 0.0, p.y)
	var tone: Color = (IRON if iron else Color(0.23, 0.15, 0.09)) * r.randf_range(0.85, 1.2)
	var post := centre - along * 0.5
	o.box(Transform3D(basis, post + Vector3(0, 0.62, 0)), Vector3(0.18, 1.24, 0.18), tone * 1.25, 0.1, 8)
	o.cyl(Transform3D(Basis(Vector3.UP, PI * 0.25), post + Vector3(0, 1.24, 0)), 0.13, 0.0, 0.26, 4, tone * 1.5, 0.1, false)
	for rail_y in [0.34, 0.9]:
		o.box(Transform3D(basis, centre + Vector3(0, rail_y, 0)), Vector3(1.04, 0.09, 0.08), tone, 0.1, 8)
	for i in 3:
		if r.randf() < 0.1:
			continue
		var lean := Basis(Vector3.FORWARD, r.randf_range(-0.22, 0.22)) if r.randf() < 0.18 else Basis.IDENTITY
		var base := centre + along * (-0.26 + 0.3 * i)
		var top := r.randf_range(1.02, 1.14)
		o.box(Transform3D(basis * lean, base + Vector3(0, top * 0.5, 0)), Vector3(0.07, top, 0.07), tone, 0.1, 8)
		o.cyl(Transform3D(basis * lean, base + Vector3(0, top, 0)), 0.07, 0.0, 0.18, 4, tone * 1.7, 0.1, false)
	cols.append(["b", p, Vector2(0.5, 0.16) if horizontal else Vector2(0.16, 0.5), 0.0])


## cattedrale in rovina sull'ingombro della mappa: navata a cielo aperto, contrafforti, finestre ogivali, colonne,
## abside, due torri di altezza diversa e il portale a sud davanti all'ingresso del campanile
static func _cathedral(o: W3DBuilder, origin: Vector2, size: Vector2, openings: Array, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var w := size.x
	var h := size.y
	var at := func(x: float, y: float, z: float) -> Vector3: return Vector3(origin.x + x, y, origin.y + z)
	# pavimento di lastre sconnesse
	for zi in int(h) - 1:
		for xi in int(w) - 1:
			if r.randf() < 0.86:
				o.box(Transform3D(Basis(Vector3.UP, r.randf_range(-0.05, 0.05)), at.call(xi + 1.0, 0.03, zi + 1.0)),
					Vector3(0.92, 0.07, 0.92), STONE * r.randf_range(0.42, 0.66), 0.1, 8)
	# muri laterali e abside: blocchi di pietra a corsi, con altezze spezzate
	for side_x in [0.5, w - 0.5]:
		var gap: Dictionary = openings[0 if side_x < 1.0 else 1]
		var row := 0
		while row < int(h) - 4:
			if gap.has(row):
				row += 1
				continue
			var span := 1 if (gap.has(row + 1) or row + 1 >= int(h) - 4) else 2
			var high := r.randf_range(3.0, 6.4) if r.randf() < 0.34 else r.randf_range(5.8, 7.0)
			_masonry(o, at.call(side_x, 0.0, row + span * 0.5), Vector2(0.82, span), high, r)
			row += span
		if not gap.is_empty():
			var first: int = gap.keys().min()
			var last: int = gap.keys().max() + 1
			var middle := (first + last) * 0.5
			for jamb in [first - 0.2, last + 0.2]:
				_masonry(o, at.call(side_x, 0.0, jamb), Vector2(1.15, 0.5), 4.4, r)
			for sgn in [-1.0, 1.0]:      # arco a sesto acuto sopra il passaggio
				o.box(Transform3D(Basis(Vector3.RIGHT, -sgn * 0.62), at.call(side_x, 5.0, middle + sgn * (last - first) * 0.25)),
					Vector3(0.9, 0.46, (last - first) * 0.66), STONE * 1.14, 0.1, 0)
		for i in 5:      # contrafforti esterni
			var bz := 2.0 + i * 3.1
			if gap.has(int(bz)) or gap.has(int(bz) - 1) or gap.has(int(bz) + 1):
				continue
			var out := -0.34 if side_x < 1.0 else 0.34
			for step in 3:
				o.box(Transform3D(Basis.IDENTITY, at.call(side_x + out * (1.9 - step * 0.45), 0.9 + step * 1.5, bz)),
					Vector3(0.72 - step * 0.12, 1.8, 0.66), STONE * (0.84 + step * 0.07), 0.12, 8)
		for i in 4:      # finestre ogivali sulle due facce del muro
			var wz := 3.55 + i * 3.1
			if gap.has(int(wz)) or gap.has(int(wz) - 1) or gap.has(int(wz) + 1):
				continue
			for face in [-0.45, 0.45]:
				var lit := r.randf() < 0.45
				_lancet(o, at.call(side_x + face, 2.7, wz), Basis(Vector3.UP, PI * 0.5), 0.8, 2.2, lit)
				if lit and absf(face) > 0.0 and r.randf() < 0.4:
					lamps.append(Vector4(origin.x + side_x + face * 2.2, 2.4, origin.y + wz, 0.5))
	var x := 0.5
	while x < w - 0.5:
		var arch := 7.8 - absf(x + 0.65 - w * 0.5) * 0.42
		_masonry(o, at.call(x + 0.65, 0.0, 0.5), Vector2(1.3, 0.82), arch * r.randf_range(0.86, 1.0), r)
		x += 1.3
	for i in 3:
		_lancet(o, at.call(w * 0.5 + (i - 1) * 2.0, 4.0 - absf(i - 1) * 0.5, 0.96), Basis.IDENTITY, 0.9, 3.0 - absf(i - 1) * 0.6, i == 1)
	lamps.append(Vector4(origin.x + w * 0.5, 3.2, origin.y + 2.2, 0.9))
	# altare sotto l'abside
	o.box(Transform3D(Basis.IDENTITY, at.call(w * 0.5, 0.18, 2.3)), Vector3(4.2, 0.36, 2.0), STONE * 0.8, 0.12, 8)
	o.box(Transform3D(Basis.IDENTITY, at.call(w * 0.5, 0.78, 2.1)), Vector3(2.4, 0.84, 0.8), STONE * 1.15, 0.12, 8)
	for cx in [-0.85, 0.85]:
		o.box(Transform3D(Basis.IDENTITY, at.call(w * 0.5 + cx, 1.45, 2.1)), Vector3(0.1, 0.5, 0.1), Color(0.55, 0.5, 0.38), 0.1, 8)
		o.box(Transform3D(Basis.IDENTITY, at.call(w * 0.5 + cx, 1.78, 2.1)), Vector3(0.12, 0.17, 0.12), Color(1.0, 0.78, 0.42, 0.15), 0.0, 8)
	# colonne della navata, alcune spezzate; stesse celle occupate nella logica
	for col_x in [3.5, w - 3.5]:
		var cy := 4
		while cy <= int(h) - 7:
			var broken := r.randf() < 0.34
			var high := r.randf_range(1.2, 2.6) if broken else 4.6
			o.cyl(Transform3D(Basis.IDENTITY, at.call(col_x, 0.0, cy + 0.5)), 0.55, 0.5, 0.35, 8, STONE * 0.78, 0.08)
			o.cyl(Transform3D(Basis.IDENTITY, at.call(col_x, 0.35, cy + 0.5)), 0.38, 0.33, high, 8, STONE * 1.08, 0.1)
			if broken:
				o.rock(at.call(col_x + r.randf_range(-0.6, 0.6), 0.25, cy + 1.4), Vector3(0.8, 0.45, 0.5), STONE, 0.15, 0.35, r.randf() * TAU)
			else:
				o.box(Transform3D(Basis.IDENTITY, at.call(col_x, high + 0.5, cy + 0.5)), Vector3(0.95, 0.3, 0.95), STONE * 0.9, 0.08, 8)
			cy += 3
	# facciata: due torri, portale ad arco, rosone e frontone
	for t in 2:
		var tx := 1.55 if t == 0 else w - 1.55
		var th := 11.5 if t == 0 else 8.4        # la torre destra e' crollata a meta'
		var tz := h - 2.0
		_masonry(o, at.call(tx, 0.0, tz), Vector2(2.9, 3.8), th, r)
		for band in [th * 0.42, th * 0.74]:
			o.box(Transform3D(Basis.IDENTITY, at.call(tx, band, tz)), Vector3(3.15, 0.22, 4.05), STONE * 0.72, 0.1, 8)
		for level in [2.6, th * 0.58, th * 0.86]:
			_lancet(o, at.call(tx, level, h - 0.06), Basis.IDENTITY, 0.8, 1.7, level > 5.0 and t == 0)
		if t == 0:
			o.cyl(Transform3D(Basis(Vector3.UP, PI * 0.25), at.call(tx, th, tz)), 2.05, 0.0, 4.6, 4, SLATE * 1.15, 0.16, false)
			o.box(Transform3D(Basis.IDENTITY, at.call(tx, th + 5.0, tz)), Vector3(0.14, 1.0, 0.14), STONE * 1.3, 0.1, 8)
			o.box(Transform3D(Basis.IDENTITY, at.call(tx, th + 5.1, tz)), Vector3(0.62, 0.14, 0.14), STONE * 1.3, 0.1, 8)
		else:
			for i in 9:
				o.rock(at.call(tx + r.randf_range(-1.2, 1.2), th + r.randf_range(0.0, 0.5), tz + r.randf_range(-1.6, 1.6)),
					Vector3(0.7, r.randf_range(0.4, 1.3), 0.7), STONE * r.randf_range(0.75, 1.0), 0.2, 0.45, r.randf() * TAU)
	# tratti di facciata ai lati del portale (aperto per tre celle al centro)
	var half := w * 0.5
	for sgn in [-1.0, 1.0]:
		var inner: float = half + sgn * 1.55
		var outer: float = 3.0 if sgn < 0.0 else w - 3.0
		_masonry(o, at.call((inner + outer) * 0.5, 0.0, h - 0.5), Vector2(absf(outer - inner), 0.82), 5.6, r)
		_lancet(o, at.call((inner + outer) * 0.5, 2.7, h - 0.06), Basis.IDENTITY, 0.75, 2.2, true)
		for k in 3:      # strombatura del portale
			o.box(Transform3D(Basis.IDENTITY, at.call(half + sgn * (1.62 + k * 0.16), 1.5 - k * 0.1, h - 0.1 + k * 0.1)),
				Vector3(0.18, 3.0 - k * 0.2, 0.2), STONE * (1.25 - k * 0.15), 0.08, 8)
	for sgn in [-1.0, 1.0]:      # arco a sesto acuto e frontone sopra il portale
		o.box(Transform3D(Basis(Vector3(0, 0, 1), sgn * 0.72), at.call(half + sgn * 0.85, 3.55, h - 0.35)), Vector3(0.42, 2.45, 0.8), STONE * 1.12, 0.1, 0)
		o.box(Transform3D(Basis(Vector3(0, 0, 1), sgn * 0.9), at.call(half + sgn * 1.65, 6.35, h - 0.5)), Vector3(0.4, 4.3, 0.7), STONE * 0.95, 0.1, 0)
	_masonry(o, at.call(half, 4.35, h - 0.55), Vector2(3.4, 0.7), 2.3, r)
	for k in 12:      # rosone illuminato
		var a := TAU * k / 12.0
		o.box(Transform3D(Basis(Vector3(0, 0, 1), a), at.call(half + cos(a) * 0.92, 5.55 + sin(a) * 0.92, h - 0.12)), Vector3(0.2, 0.52, 0.16), STONE * 1.3, 0.08, 0)
		if k % 2 == 0:
			o.box(Transform3D(Basis(Vector3(0, 0, 1), a), at.call(half, 5.55, h - 0.14)), Vector3(1.75, 0.07, 0.07), STONE * 1.15, 0.08, 0)
	o.box(Transform3D(Basis(Vector3(0, 0, 1), PI * 0.25), at.call(half, 5.55, h - 0.22)), Vector3(1.15, 1.15, 0.08), Color(0.72, 0.45, 0.85, 0.2), 0.0, 8)
	lamps.append(Vector4(origin.x + half, 4.6, origin.y + h + 1.0, 0.8))
	for i in 28:      # macerie
		var q := Vector2(r.randf_range(1.4, w - 1.4), r.randf_range(3.5, h - 5.0))
		if absf(q.x - 3.5) < 0.9 or absf(q.x - (w - 3.5)) < 0.9 or absf(q.x - half) < 1.2:
			continue
		var s := r.randf_range(0.18, 0.46)
		o.rock(at.call(q.x, s * 0.3, q.y), Vector3(s * 1.5, s * 0.75, s * 1.2), STONE * r.randf_range(0.6, 1.0), 0.18, 0.4, r.randf() * TAU)
	# collisioni: coincidono con le celle di cathedral_cells()
	var box := func(x0: float, z0: float, x1: float, z1: float) -> void:
		cols.append(["b", origin + Vector2(x0 + x1, z0 + z1) * 0.5, Vector2(x1 - x0, z1 - z0) * 0.5, 0.0])
	for side in 2:      # muri laterali, interrotti dai portali del transetto
		var x0 := 0.0 if side == 0 else w - 1.0
		var start := 0
		for row in int(h) + 1:
			if row == int(h) or openings[side].has(row):
				if row > start:
					box.call(x0, float(start), x0 + 1.0, float(row))
				start = row + 1
	box.call(0.0, 0.0, w, 1.0)
	box.call(0.0, h - 1.0, floorf(half) - 1.0, h)
	box.call(floorf(half) + 2.0, h - 1.0, w, h)
	box.call(0.0, h - 4.0, 3.0, h)
	box.call(w - 3.0, h - 4.0, w, h)
	for col_x in [3.5, w - 3.5]:
		var cz := 4
		while cz <= int(h) - 7:
			cols.append(["c", origin + Vector2(col_x, cz + 0.5), 0.45])
			cz += 3


## blocco di muratura a corsi sfalsati, con la malta scura nelle fughe; base al centro
static func _masonry(o: W3DBuilder, base: Vector3, foot: Vector2, high: float, r: RandomNumberGenerator) -> void:
	o.box(Transform3D(Basis.IDENTITY, base + Vector3(0, high * 0.5, 0)), Vector3(foot.x - 0.12, high, foot.y - 0.12), STONE * 0.42, 0.04, 8)
	var long_x := foot.x >= foot.y
	var length := foot.x if long_x else foot.y
	var y := 0.0
	var row := 0
	while y < high - 0.05:
		var rise := minf(0.72, high - y)
		var parts := maxi(1, roundi(length / 1.1)) + (row % 2)
		var step := length / parts
		for i in parts:
			var shift := -length * 0.5 + step * (i + 0.5)
			var size := Vector3(step - 0.07, rise - 0.07, foot.y) if long_x else Vector3(foot.x, rise - 0.07, step - 0.07)
			var offset := Vector3(shift, 0, 0) if long_x else Vector3(0, 0, shift)
			o.box(Transform3D(Basis.IDENTITY, base + offset + Vector3(0, y + rise * 0.5, 0)), size, STONE * r.randf_range(0.82, 1.18), 0.1, 8)
		y += rise
		row += 1


## finestra a sesto acuto: vano, vetro (acceso o spento), montante, punta e davanzale. basis volge la normale verso z
static func _lancet(o: W3DBuilder, centre: Vector3, basis: Basis, width: float, high: float, lit: bool) -> void:
	var glass: Color = Color(0.9, 0.72, 0.46, 0.2) if lit else Color(0.05, 0.06, 0.1)
	var tip := centre + Vector3(0, high * 0.5, 0)
	o.box(Transform3D(basis, centre), Vector3(width + 0.22, high, 0.12), DARK, 0.0, 8)
	o.box(Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.25), tip), Vector3((width + 0.22) * 0.72, (width + 0.22) * 0.72, 0.11), DARK, 0.0, 8)
	o.box(Transform3D(basis, centre), Vector3(width - 0.12, high - 0.14, 0.15), glass, 0.0, 8)
	o.box(Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.25), tip), Vector3(width * 0.58, width * 0.58, 0.14), glass, 0.0, 8)
	o.box(Transform3D(basis, centre), Vector3(0.08, high, 0.19), STONE * 1.2, 0.08, 8)
	o.box(Transform3D(basis, centre - Vector3(0, high * 0.5 + 0.08, 0)), Vector3(width + 0.42, 0.16, 0.26), STONE * 1.25, 0.08, 8)
