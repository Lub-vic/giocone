class_name W3DFacade
extends RefCounted
## Dettagli delle facciate delle case, pensati per la vista in prima persona. Tutto resta sotto la gronda (sporgenza
## massima 0.6) e dentro la collisione della casa: dall'alto la casa e' quella di prima.
## Le coordinate di una parete sono (u = metri dall'angolo sinistro, h = altezza, out = sporgenza dal muro).

const STONE_TONES := [Color(0.24, 0.23, 0.235), Color(0.19, 0.185, 0.19), Color(0.29, 0.275, 0.26)]
const BEAM := Color(0.13, 0.085, 0.06)
const PLANK := Color(0.24, 0.16, 0.095)
const IRON := Color(0.07, 0.07, 0.08)
const GLASS_DARK := Color(0.035, 0.045, 0.065)
const GLASS_LIT := Color(0.95, 0.82, 0.58, 0.2)       # alpha < 1: emissivo
const SHUTTERS := [Color(0.22, 0.14, 0.085), Color(0.12, 0.19, 0.15), Color(0.27, 0.11, 0.08), Color(0.13, 0.15, 0.21)]


## una parete: i quattro angoli veri (irregolari) e la sua normale verso l'esterno
class Wall:
	var a: Vector3
	var b: Vector3
	var ta: Vector3
	var tb: Vector3
	var n: Vector3
	var along: Vector3
	var width: float
	var height: float

	func _init(p0: Vector3, p1: Vector3, t_0: Vector3, t_1: Vector3) -> void:
		a = p0
		b = p1
		ta = t_0
		tb = t_1
		along = Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		n = Vector3.UP.cross(along).normalized()
		width = a.distance_to(b)
		height = minf(ta.y - a.y, tb.y - b.y)

	func at(u: float, h: float, out := 0.0) -> Vector3:
		var s := clampf(u / width, 0.0, 1.0)
		var low := a.lerp(b, s)
		var high := ta.lerp(tb, s)
		return low.lerp(high, h / maxf(high.y - low.y, 0.1)) + n * out

	func basis(roll := 0.0) -> Basis:
		return Basis(-along, Vector3.UP, n) * Basis(Vector3(0, 0, 1), roll)


static func _block(o: W3DBuilder, w: Wall, u: float, h: float, out: float, size: Vector3, col: Color, roll := 0.0, j := 0.08) -> void:
	o.box(Transform3D(w.basis(roll), w.at(u, h, out)), size, col, j, 8 if roll == 0.0 else 0)


## trave fra due punti della parete
static func _beam(o: W3DBuilder, w: Wall, from: Vector3, to: Vector3, thick: float, depth: float, col: Color) -> void:
	var axis := to - from
	if axis.length() < 0.05:
		return
	var x := axis.normalized()
	var y := w.n.cross(x).normalized()
	o.box(Transform3D(Basis(x, y, x.cross(y)), (from + to) * 0.5), Vector3(axis.length(), thick, depth), col, 0.1, 0)


## zoccolo di pietre irregolari; "gap" e' il vano da lasciare libero (centro u, semiampiezza)
static func plinth(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, gap := Vector2(-9.0, 0.0)) -> void:
	var u := 0.05
	while u < w.width - 0.2:
		var len := minf(r.randf_range(0.36, 0.72), w.width - u)
		var high := r.randf_range(0.26, 0.46)
		if absf(u + len * 0.5 - gap.x) > gap.y + len * 0.5:
			_block(o, w, u + len * 0.5, high * 0.5, 0.09, Vector3(len - 0.06, high, 0.2), STONE_TONES[r.randi() % 3])
		u += len


## struttura del muro secondo lo stile: 0 pietra, 1 assi di legno, 2 intonaco a graticcio
static func frame(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, style: int, wall_col: Color) -> void:
	var top := w.height - 0.1
	if style == 0:
		for end in [0.2, w.width - 0.2]:
			var h := 0.55
			var long := true
			while h < top:
				_block(o, w, end, h, 0.07, Vector3(0.46 if long else 0.3, 0.27, 0.16), STONE_TONES[2 if long else 0])
				h += 0.31
				long = not long
		for i in r.randi_range(12, 20):
			_block(o, w, r.randf_range(0.5, w.width - 0.5), r.randf_range(0.55, top - 0.2), 0.045,
				Vector3(r.randf_range(0.22, 0.46), r.randf_range(0.13, 0.22), 0.09), wall_col * r.randf_range(0.7, 1.35))
	else:
		for end in [0.09, w.width - 0.09]:
			_beam(o, w, w.at(end, 0.0, 0.07), w.at(end, top, 0.07), 0.17, 0.15, BEAM)
	if style == 1:
		var u := 0.55
		while u < w.width - 0.4:
			_beam(o, w, w.at(u, 0.35, 0.045), w.at(u + r.randf_range(-0.04, 0.04), top, 0.045), 0.07, 0.07, wall_col * r.randf_range(0.55, 0.8))
			u += r.randf_range(0.44, 0.6)
		_beam(o, w, w.at(0.1, 1.05, 0.08), w.at(w.width - 0.1, 1.05, 0.08), 0.1, 0.09, BEAM)
	elif style == 2:
		_beam(o, w, w.at(0.1, 0.9, 0.065), w.at(w.width - 0.1, 0.9, 0.065), 0.12, 0.1, BEAM)
		var bays := maxi(2, roundi(w.width / 1.35))
		for i in range(1, bays):
			var u := w.width * i / bays
			_beam(o, w, w.at(u, 0.4, 0.06), w.at(u, top, 0.06), 0.11, 0.1, BEAM)
		var bay := w.width / bays
		_beam(o, w, w.at(0.15, 0.95, 0.055), w.at(bay - 0.1, top - 0.1, 0.055), 0.1, 0.09, BEAM)
		_beam(o, w, w.at(w.width - 0.15, 0.95, 0.055), w.at(w.width - bay + 0.1, top - 0.1, 0.055), 0.1, 0.09, BEAM)
	_beam(o, w, w.at(0.0, top, 0.09), w.at(w.width, top, 0.09), 0.18, 0.17, BEAM)
	# teste delle travi del tetto che sporgono sopra l'architrave
	var s := 0.35
	while s < w.width - 0.25:
		_block(o, w, s, top + 0.02, 0.2, Vector3(0.13, 0.12, 0.2), BEAM * 1.25)
		s += 0.8


## finestra completa: vano, vetro, telaio a croce, architrave, davanzale e, a caso, scuri, assi o fioriera
static func window(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, u: float, h: float, lit: bool, ww := 0.78, wh := 0.92, kind := -1) -> void:
	var wood: Color = SHUTTERS[r.randi() % SHUTTERS.size()]
	if kind < 0:
		var roll := r.randf()
		kind = 0 if roll < 0.46 else (1 if roll < 0.64 else (2 if roll < 0.78 else 3))      # scuri aperti, chiusi, sbarrata, semplice
	_block(o, w, u, h, 0.075, Vector3(ww + 0.08, wh + 0.08, 0.13), Color(0.03, 0.025, 0.025), 0.0, 0.0)
	_block(o, w, u, h, 0.125, Vector3(ww - 0.1, wh - 0.1, 0.05), GLASS_LIT if lit else GLASS_DARK, 0.0, 0.0)
	if not lit:      # riflesso del cielo sul vetro spento
		_block(o, w, u - ww * 0.18, h + wh * 0.16, 0.155, Vector3(0.05, wh * 0.38, 0.012), Color(0.16, 0.2, 0.27), 0.6)
	_block(o, w, u, h, 0.17, Vector3(0.055, wh - 0.06, 0.05), BEAM * 1.3)
	_block(o, w, u, h + wh * 0.06, 0.175, Vector3(ww - 0.06, 0.055, 0.05), BEAM * 1.3)
	for side in [-1.0, 1.0]:
		_block(o, w, u + side * (ww * 0.5 + 0.02), h, 0.15, Vector3(0.1, wh + 0.06, 0.12), BEAM * 1.5)
	_block(o, w, u, h + wh * 0.5 + 0.08, 0.17, Vector3(ww + 0.3, 0.15, 0.18), BEAM * 1.2)
	_block(o, w, u, h - wh * 0.5 - 0.06, 0.2, Vector3(ww + 0.24, 0.11, 0.28), STONE_TONES[2])
	if kind == 0:
		for side in [-1.0, 1.0]:
			var roll: float = r.randf_range(0.16, 0.3) * side if r.randf() < 0.16 else 0.0        # uno scuro scardinato
			var cu: float = u + side * (ww * 0.5 + 0.27)
			if cu < 0.2 or cu > w.width - 0.2:
				continue
			_block(o, w, cu, h - absf(roll) * 0.3, 0.17, Vector3(0.34, wh, 0.07), wood, roll)
			for lv in [-0.3, 0.3]:
				_block(o, w, cu, h + wh * lv - absf(roll) * 0.3, 0.215, Vector3(0.31, 0.07, 0.03), wood * 0.6, roll)
	elif kind == 1:
		for side in [-1.0, 1.0]:
			_block(o, w, u + side * ww * 0.245, h, 0.2, Vector3(ww * 0.47, wh - 0.02, 0.07), wood)
			for lv in [-0.3, 0.3]:
				_block(o, w, u + side * ww * 0.245, h + wh * lv, 0.245, Vector3(ww * 0.44, 0.065, 0.03), IRON)
		if lit:      # la luce filtra dalla fessura
			_block(o, w, u, h, 0.238, Vector3(0.025, wh - 0.1, 0.012), GLASS_LIT, 0.0, 0.0)
	elif kind == 2:
		for i in r.randi_range(2, 3):
			_block(o, w, u + r.randf_range(-0.06, 0.06), h - wh * 0.3 + i * wh * 0.28, 0.21 + i * 0.012,
				Vector3(ww + 0.2, 0.15, 0.06), PLANK * r.randf_range(0.8, 1.2), r.randf_range(-0.28, 0.28))
	if kind != 1 and r.randf() < 0.22:
		var by := h - wh * 0.5 - 0.22
		_block(o, w, u, by, 0.27, Vector3(ww, 0.17, 0.2), PLANK * 0.85)
		for i in 7:
			var fu := u - ww * 0.4 + i * ww * 0.13
			_block(o, w, fu, by + 0.13 + r.randf_range(0.0, 0.06), 0.28, Vector3(0.1, 0.12, 0.12), Color(0.1, 0.19, 0.09) * r.randf_range(0.8, 1.4), r.randf_range(-0.5, 0.5))
			if r.randf() < 0.45:
				_block(o, w, fu, by + 0.24, 0.31, Vector3(0.065, 0.065, 0.065), [Color(0.55, 0.1, 0.09), Color(0.6, 0.5, 0.15), Color(0.4, 0.22, 0.5)][r.randi() % 3])


## porta di assi con stipiti, bandelle di ferro, anello e tettoia sulle mensole
static func door(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, u: float, face_out: float, roof_col: Color, canopy: bool) -> void:
	var wood := PLANK * r.randf_range(0.75, 1.15)
	for i in 5:
		_block(o, w, u - 0.44 + i * 0.22, 1.02, face_out + r.randf_range(0.0, 0.015), Vector3(0.205, 1.96, 0.05), wood * r.randf_range(0.82, 1.18))
	for lv in [0.42, 1.55]:
		_block(o, w, u, lv, face_out + 0.045, Vector3(1.02, 0.085, 0.03), IRON)
		for i in 5:
			_block(o, w, u - 0.42 + i * 0.21, lv, face_out + 0.07, Vector3(0.035, 0.035, 0.03), IRON * 2.6)
	for k in 8:      # anello per bussare
		var ang := TAU * k / 8.0
		_block(o, w, u + 0.3 + cos(ang) * 0.09, 1.08 + sin(ang) * 0.09, face_out + 0.065, Vector3(0.075, 0.034, 0.034), IRON * 2.2, ang + PI * 0.5)
	_block(o, w, u + 0.3, 1.19, face_out + 0.055, Vector3(0.1, 0.1, 0.045), IRON * 1.6)
	for side in [-1.0, 1.0]:
		_block(o, w, u + side * 0.65, 1.06, face_out - 0.02, Vector3(0.17, 2.14, 0.2), BEAM * 1.35)
	_block(o, w, u, 2.19, face_out - 0.01, Vector3(1.62, 0.2, 0.24), BEAM * 1.2)
	if canopy:
		var y := minf(2.5, w.height - 0.12)
		for side in [-1.0, 1.0]:
			_beam(o, w, w.at(u + side * 0.8, y - 0.6, 0.08), w.at(u + side * 0.8, y - 0.1, 0.54), 0.09, 0.09, BEAM)
		for i in 7:
			_beam(o, w, w.at(u - 0.84 + i * 0.28, y + 0.1, 0.04), w.at(u - 0.84 + i * 0.28, y - 0.12, 0.6), 0.26, 0.055, roof_col * r.randf_range(0.8, 1.3))


## frontone triangolare: finestrella di sottotetto, trave centrale e travi lungo gli spioventi
static func gable(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, apex: Vector3, style: int, lit: bool) -> void:
	var left := w.at(0.05, w.height - 0.05, 0.07)
	var right := w.at(w.width - 0.05, w.height - 0.05, 0.07)
	var peak := apex + w.n * 0.07
	_beam(o, w, left, peak, 0.15, 0.14, BEAM)
	_beam(o, w, right, peak, 0.15, 0.14, BEAM)
	var mid := (left + right) * 0.5
	var rise := peak.y - mid.y
	if style == 2:
		_beam(o, w, mid.lerp(peak, 0.62), peak, 0.12, 0.11, BEAM)
		for side: Vector3 in [left, right]:
			_beam(o, w, mid, side.lerp(peak, 0.5), 0.1, 0.09, BEAM)
	if rise < 1.1:
		return
	var centre := mid.lerp(peak, 0.34)
	var basis := w.basis()
	var size := minf(0.62, rise * 0.34)
	o.box(Transform3D(basis, centre + w.n * 0.03), Vector3(size + 0.16, size + 0.16, 0.14), BEAM * 1.4, 0.08, 8)
	o.box(Transform3D(basis, centre + w.n * 0.11), Vector3(size, size, 0.04), GLASS_LIT if lit else GLASS_DARK, 0.0, 8)
	o.box(Transform3D(basis * Basis(Vector3(0, 0, 1), PI * 0.25), centre + w.n * 0.145), Vector3(0.05, size * 1.3, 0.035), BEAM * 1.3, 0.08, 0)
	o.box(Transform3D(basis * Basis(Vector3(0, 0, 1), -PI * 0.25), centre + w.n * 0.145), Vector3(0.05, size * 1.3, 0.035), BEAM * 1.3, 0.08, 0)
	o.box(Transform3D(basis, centre - Vector3.UP * (size * 0.5 + 0.1) + w.n * 0.14), Vector3(size + 0.3, 0.09, 0.2), STONE_TONES[2], 0.08, 8)


## piccole cose appese o appoggiate al muro: una o due per parete, fra u0 e u1
static func clutter(o: W3DBuilder, w: Wall, r: RandomNumberGenerator, u0: float, u1: float) -> void:
	if u1 - u0 < 0.7:
		return
	var u := r.randf_range(u0 + 0.35, u1 - 0.35)
	match r.randi() % 6:
		0:      # panca
			_block(o, w, u, 0.52, 0.22, Vector3(minf(1.3, u1 - u0), 0.09, 0.3), PLANK)
			for side in [-0.45, 0.45]:
				_block(o, w, u + side * minf(1.0, u1 - u0 - 0.2), 0.25, 0.22, Vector3(0.1, 0.48, 0.24), PLANK * 0.7)
		1:      # erbe e trecce d'aglio ad essiccare
			_block(o, w, u, 1.9, 0.2, Vector3(0.9, 0.05, 0.05), BEAM * 1.6)
			for i in 5:
				var drop := r.randf_range(0.22, 0.42)
				var tone: Color = [Color(0.2, 0.22, 0.09), Color(0.33, 0.25, 0.1), Color(0.55, 0.5, 0.4), Color(0.28, 0.08, 0.06)][r.randi() % 4]
				_block(o, w, u - 0.36 + i * 0.18, 1.88 - drop * 0.5, 0.2, Vector3(0.09, drop, 0.09), tone, r.randf_range(-0.15, 0.15))
		2:      # catasta di legna contro il muro
			for row in 4:
				for i in 5 - row / 2:
					var lu := u - 0.4 + i * 0.19 + (row % 2) * 0.09
					_block(o, w, lu, 0.12 + row * 0.17, 0.2, Vector3(0.17, 0.16, 0.26), Color(0.2, 0.13, 0.075) * r.randf_range(0.75, 1.25))
					_block(o, w, lu, 0.12 + row * 0.17, 0.34, Vector3(0.1, 0.1, 0.015), Color(0.42, 0.31, 0.18))
		3:      # edera
			for i in r.randi_range(26, 44):
				var t := r.randf()
				_block(o, w, u + r.randf_range(-0.55, 0.55) * (1.0 - t * 0.6), 0.2 + t * minf(2.0, w.height - 0.4), 0.11 + r.randf() * 0.04,
					Vector3(r.randf_range(0.1, 0.22), r.randf_range(0.08, 0.17), 0.03), Color(0.07, 0.15, 0.08) * r.randf_range(0.8, 1.5), r.randf_range(-0.8, 0.8))
		4:      # scala a pioli appoggiata
			for side in [-0.24, 0.24]:
				_beam(o, w, w.at(u + side - 0.18, 0.02, 0.36), w.at(u + side + 0.18, 2.05, 0.14), 0.07, 0.06, PLANK)
			for i in 6:
				var t := (i + 0.5) / 6.0
				_beam(o, w, w.at(u - 0.42 + t * 0.36, t * 2.0, 0.36 - t * 0.21), w.at(u + 0.06 + t * 0.36, t * 2.0, 0.36 - t * 0.21), 0.05, 0.05, PLANK * 0.8)
		_:      # attrezzi appesi: ferro di cavallo, falce e secchio
			for k in 7:
				var ang := PI * 0.15 + PI * 1.7 * k / 6.0
				_block(o, w, u - 0.32 + sin(ang) * 0.11, 1.65 + cos(ang) * 0.12, 0.12, Vector3(0.08, 0.04, 0.04), IRON * 2.4, -ang)
			_beam(o, w, w.at(u + 0.05, 0.95, 0.14), w.at(u + 0.22, 1.85, 0.14), 0.05, 0.05, PLANK)
			_beam(o, w, w.at(u + 0.22, 1.85, 0.16), w.at(u + 0.52, 1.66, 0.16), 0.07, 0.03, IRON * 3.0)
			_block(o, w, u + 0.1, 0.62, 0.2, Vector3(0.28, 0.26, 0.2), PLANK * 0.75)
			_block(o, w, u + 0.1, 0.62, 0.31, Vector3(0.29, 0.045, 0.015), IRON * 1.8)


## veste le quattro pareti. bottom/top sono gli angoli della casa; il lato 1 (indice degli angoli 1-2) ha la porta.
## door_u e front_windows sono in coordinate locali della casa lungo la profondita'.
static func decorate(o: W3DBuilder, bottom: Array, top: Array, apexes: Array, depth: float, door_z: float,
		front_windows: Array, style: int, wall_col: Color, roof_col: Color, seed_value: int) -> void:
	# lo stato del generatore dei colori va ripristinato: lo usa anche il posizionamento di sassi e alberi
	var colour_state := o.rn.state
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	for i in 4:
		var j := (i + 1) % 4
		var w := Wall.new(bottom[i], bottom[j], top[i], top[j])
		if i == 1:
			var door_u := clampf((door_z / depth + 0.5) * w.width, 0.8, w.width - 0.8)
			plinth(o, w, r, Vector2(door_u, 0.75))
			frame(o, w, r, style, wall_col)
			door(o, w, r, door_u, 0.36, roof_col, r.randf() < 0.6)
			for fw: Array in front_windows:
				var wu := clampf((float(fw[0]) / depth + 0.5) * w.width, 0.7, w.width - 0.7)
				window(o, w, r, wu, minf(1.42, w.height - 0.75), bool(fw[1]), 0.74, 0.86)
		else:
			plinth(o, w, r)
			frame(o, w, r, style, wall_col)
			var slots: Array = []
			if i == 3:
				slots = [w.width * 0.26, w.width * 0.74] if r.randf() < 0.75 else [w.width * 0.68]
			elif w.width > 4.2 and r.randf() < 0.55:
				slots = [w.width * 0.26, w.width * 0.74]
			else:
				slots = [w.width * (0.5 if r.randf() < 0.6 else 0.3)]
			for slot: float in slots:
				window(o, w, r, slot, minf(1.4, w.height - 0.75), r.randf() < 0.3, r.randf_range(0.66, 0.82), r.randf_range(0.78, 0.94))
			# il pezzo di muro libero piu' largo ospita un oggetto appeso o appoggiato
			var edges: Array = [0.25]
			for slot: float in slots:
				edges.append(slot - 0.85)
				edges.append(slot + 0.85)
			edges.append(w.width - 0.25)
			var best := Vector2.ZERO
			for k in range(0, edges.size(), 2):
				if float(edges[k + 1]) - float(edges[k]) > best.y - best.x:
					best = Vector2(edges[k], edges[k + 1])
			if r.randf() < 0.85:
				clutter(o, w, r, best.x, best.y)
		if i == 0 or i == 2:
			gable(o, w, r, apexes[0 if i == 0 else 1], style, r.randf() < 0.25)
	o.rn.state = colour_state
