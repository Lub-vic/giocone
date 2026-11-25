class_name W3DBig
extends RefCounted
## Grandi strutture del mondo 3D, visitabili a cielo aperto (niente caricamento di interni): castelli, monasteri, forti, anfiteatri,
## villaggi abbandonati, miniere, templi... Hanno mura con brecce, porte e cortili: si entra a piedi dai varchi, le collisioni sono pezzo per pezzo.
## Coordinate locali (x, z) centrate sul punto della struttura; t e' la trasformazione (posizione + rotazione) nel mondo.

const WOOD := Color(0.25, 0.17, 0.11)
const WOOD_L := Color(0.36, 0.25, 0.15)
const WOOD_D := Color(0.15, 0.1, 0.07)
const STONE := Color(0.27, 0.265, 0.285)
const STONE_L := Color(0.35, 0.34, 0.36)
const STONE_D := Color(0.2, 0.195, 0.21)

# tipo: [nome nel catalogo, raggio occupato, biomi]
const KINDS := {
	"castle_ruin": ["Castello in rovina", 40.0, [0, 1, 2, 4, 5]],
	"monastery_ruin": ["Monastero in rovina", 17.0, [1, 4]],
	"palisade_fort": ["Forte di palizzata", 16.0, [0, 2]],
	"arena_ruin": ["Anfiteatro in rovina", 15.0, [4, 6]],
	"ghost_village": ["Villaggio abbandonato", 19.0, [0, 1, 3]],
	"mine_entrance": ["Ingresso di miniera", 11.0, [5, 6]],
	"ice_temple": ["Tempio nel ghiaccio", 12.0, [5]],
	"bandit_camp": ["Accampamento di banditi", 10.0, [0, 2, 3, 6]],
}


## dove sta il tesoro dentro la struttura (coordinate locali)
static func loot_spot(k: String) -> Vector2:
	match k:
		"castle_ruin":
			return Vector2(3.5, -19.3)
		"monastery_ruin":
			return Vector2(2.0, -19.4)
		"palisade_fort":
			return Vector2(3.0, -8.0)
		"arena_ruin":
			return Vector2(0.0, 3.0)
		"ghost_village":
			return Vector2(5.0, 0.0)
		"mine_entrance":
			return Vector2(3.0, 6.5)
		"ice_temple":
			return Vector2(0.0, -3.4)
	return Vector2(-1.0, -3.0)


static func build(k: String, o: W3DBuilder, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y))
	var pal := _palette(k)
	match k:
		"castle_ruin":
			_castle(o, t, p, yaw, r, cols, lamps, pal)
		"monastery_ruin":
			_monastery(o, t, p, yaw, r, cols, lamps, pal)
		"palisade_fort":
			_fort(o, t, p, yaw, r, cols, lamps)
		"arena_ruin":
			_arena(o, t, p, yaw, r, cols, lamps, pal)
		"ghost_village":
			_village(o, t, p, yaw, r, cols, lamps)
		"mine_entrance":
			_mine(o, t, p, yaw, r, cols, lamps)
		"ice_temple":
			_ice_temple(o, t, p, yaw, r, cols, lamps)
		"bandit_camp":
			_camp(o, t, p, yaw, r, cols, lamps)


static func _palette(k: String) -> Array:
	return [STONE, STONE_L, STONE_D]


# ------------------------------------------------------------------ attrezzi
static func _lw(t: Transform3D, p: Vector2, yaw: float, local: Vector2) -> Vector2:
	var w := Basis(Vector3.UP, yaw) * Vector3(local.x, 0.0, local.y)
	return p + Vector2(w.x, w.z)


static func _bx(o: W3DBuilder, t: Transform3D, pos: Vector3, rot: Basis, size: Vector3, col: Color, j := 0.1) -> void:
	o.box(t * Transform3D(rot, pos), size, col, j, 8)


## muro da a a b (coordinate locali), con brecce (gaps = frazioni [da, a] della lunghezza), merli e altezza irregolare (rovina)
static func _wall(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, a: Vector2, b: Vector2, h: float, th: float, col: Color, r: RandomNumberGenerator, cols: Array, gaps: Array, broke := 0.3, merlons := true, spikes := false) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var dir := (b - a) / len
	var ang := -atan2(dir.y, dir.x)
	var n := maxi(1, roundi(len / 1.5))
	var seg := len / n
	var rot := Basis(Vector3.UP, ang)
	var run0 := -1
	for i in n + 1:
		var solid := false
		if i < n:
			var f := (i + 0.5) / n
			solid = true
			for g in gaps:
				if f >= float(g[0]) and f <= float(g[1]):
					solid = false
		if solid:
			var hh := h if r.randf() > broke else h * r.randf_range(0.4, 0.85)
			var c2 := a + dir * (seg * (i + 0.5))
			var cc := col.lerp(Color.WHITE, r.randf() * 0.1).lerp(Color.BLACK, r.randf() * 0.15)
			_bx(o, t, Vector3(c2.x, hh * 0.5, c2.y), rot, Vector3(seg + 0.05, hh, th), cc, 0.12)
			if merlons and hh >= h * 0.99 and i % 2 == 0:
				_bx(o, t, Vector3(c2.x, hh + 0.28, c2.y), rot, Vector3(seg * 0.62, 0.56, th * 0.85), cc, 0.1)
			if spikes:
				var tp := t * Vector3(c2.x, hh, c2.y)
				o.shard(tp, tp + Vector3(0, 0.8, 0), th * 0.5, 0.02, WOOD_L, 0.5, 0.0, 0.0)
			if run0 < 0:
				run0 = i
		elif run0 >= 0:
			var i1 := i - 1
			var cen := a + dir * (seg * (run0 + i1 + 1) * 0.5)
			cols.append(["b", _lw(t, p, yaw, cen), Vector2(seg * (i1 - run0 + 1) * 0.5 + 0.1, th * 0.5 + 0.1), yaw + ang])
			run0 = -1


## rettangolo di mura: lato 0 N, 1 E, 2 S, 3 O. gaps_by_side: {lato: [[da, a], ...]}
static func _rect_walls(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, ctr: Vector2, half: Vector2, h: float, th: float, col: Color, r: RandomNumberGenerator, cols: Array, gaps_by_side: Dictionary, broke := 0.3, merlons := true) -> void:
	var c0 := ctr + Vector2(-half.x, -half.y)
	var c1 := ctr + Vector2(half.x, -half.y)
	var c2 := ctr + Vector2(half.x, half.y)
	var c3 := ctr + Vector2(-half.x, half.y)
	_wall(o, t, p, yaw, c0, c1, h, th, col, r, cols, gaps_by_side.get(0, []), broke, merlons)
	_wall(o, t, p, yaw, c1, c2, h, th, col, r, cols, gaps_by_side.get(1, []), broke, merlons)
	_wall(o, t, p, yaw, c2, c3, h, th, col, r, cols, gaps_by_side.get(2, []), broke, merlons)
	_wall(o, t, p, yaw, c3, c0, h, th, col, r, cols, gaps_by_side.get(3, []), broke, merlons)


static func _round_tower(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, pos: Vector2, rad: float, h: float, col: Color, r: RandomNumberGenerator, cols: Array, broken: bool) -> void:
	var rings := maxi(2, int(h / 1.5))
	var rh := h / rings
	for i in rings:
		var k1 := 1.0 - 0.012 * i
		var k2 := 1.0 - 0.012 * (i + 1)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, i * rh, pos.y)), rad * k1, rad * k2, rh + 0.02, 10, col.lerp(Color.BLACK, 0.06 * (i % 2)).lerp(Color.WHITE, r.randf() * 0.06), 0.1)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, 0, pos.y)), rad + 0.25, rad + 0.25, 0.5, 10, STONE_D, 0.08)
	for q in 5:       # feritoie
		var a := TAU * q / 5.0 + 0.4
		_bx(o, t, Vector3(pos.x + cos(a) * (rad - 0.02), h * 0.62, pos.y + sin(a) * (rad - 0.02)), Basis(Vector3.UP, -a), Vector3(0.18, 0.9, 0.3), Color(0.03, 0.03, 0.04), 0.0)
	if broken:
		for q in 10:      # sommita' sbriciolata: merli di altezze diverse
			var a2 := TAU * q / 10.0
			var hh := r.randf_range(0.0, 1.6)
			if hh > 0.3:
				_bx(o, t, Vector3(pos.x + cos(a2) * (rad - 0.25), h + hh * 0.5, pos.y + sin(a2) * (rad - 0.25)), Basis(Vector3.UP, -a2 + PI * 0.5), Vector3(1.5, hh, 0.7), col, 0.14)
		for q in 4:
			var s := r.randf_range(0.5, 1.1)
			var a3 := r.randf() * TAU
			o.rock(t * Vector3(pos.x + cos(a3) * (rad + 1.2), s * 0.4, pos.y + sin(a3) * (rad + 1.2)), Vector3(s, s * 0.7, s), col, 0.16, 0.4, a3)
	else:
		for q in 10:
			var a4 := TAU * q / 10.0
			if q % 2 == 0:
				_bx(o, t, Vector3(pos.x + cos(a4) * (rad - 0.1), h + 0.35, pos.y + sin(a4) * (rad - 0.1)), Basis(Vector3.UP, -a4 + PI * 0.5), Vector3(1.4, 0.7, 0.55), col, 0.1)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, h, pos.y)), rad * 0.95, 0.12, 3.2, 10, Color(0.2, 0.14, 0.13), 0.1)
	var wp := _lw(t, p, yaw, pos)
	cols.append(["c", wp, rad + 0.1])


static func _bx2(o: W3DBuilder, t: Transform3D, pos: Vector3, rot: Basis, size: Vector3, col: Color, j := 0.1) -> void:
	o.box(t * Transform3D(rot, pos), size, col, j, 8)


static func _torch(o: W3DBuilder, t: Transform3D, pos: Vector3, lamps: Array, power := 1.8) -> void:
	_bx(o, t, pos, Basis.IDENTITY, Vector3(0.1, 0.8, 0.1), Color(0.18, 0.15, 0.13), 0.05)
	o.shard(t * (pos + Vector3(0, 0.4, 0)), t * (pos + Vector3(0, 1.1, 0)), 0.17, 0.03, Color(1.0, 0.55, 0.18, 0.08), 0.4, 0.0, 0.05)
	var wp := t * (pos + Vector3(0, 0.9, 0))
	lamps.append(Vector4(wp.x, pos.y + 0.9, wp.z, power))


static func _rubble(o: W3DBuilder, t: Transform3D, center: Vector2, rad: float, n: int, col: Color, r: RandomNumberGenerator) -> void:
	for q in n:
		var a := r.randf() * TAU
		var d := sqrt(r.randf()) * rad
		var s := r.randf_range(0.3, 0.9)
		o.rock(t * Vector3(center.x + cos(a) * d, s * 0.35, center.y + sin(a) * d), Vector3(s, s * 0.65, s * 0.9), col.lerp(Color.BLACK, r.randf() * 0.2), 0.16, 0.4, r.randf() * TAU)


static func _floor(o: W3DBuilder, t: Transform3D, ctr: Vector2, half: Vector2, col: Color, y := 0.04) -> void:
	o.quad(t * Vector3(ctr.x - half.x, y, ctr.y - half.y), t * Vector3(ctr.x + half.x, y, ctr.y - half.y), t * Vector3(ctr.x + half.x, y, ctr.y + half.y), t * Vector3(ctr.x - half.x, y, ctr.y + half.y), col)


# ------------------------------------------------------------------ castello in rovina (grande, a blocchi di pietra, esplorabile)
## muro di pietra a corsi di blocchi sfalsati, con malta scura fra i blocchi, camminamento di ronda coi merli sul lato esterno, brecce e crolli.
## Direzione a->b in senso orario (visto dall'alto): il lato esterno e' a sinistra di chi cammina da a verso b.
static func _stone_wall(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, a: Vector2, b: Vector2, h: float, th: float, col: Color, r: RandomNumberGenerator, cols: Array, gaps: Array, broke := 0.22, walk := true) -> void:
	var len := a.distance_to(b)
	if len < 0.5:
		return
	var dir := (b - a) / len
	var ang := -atan2(dir.y, dir.x)
	var rot := Basis(Vector3.UP, ang)
	var outw := Vector2(dir.y, -dir.x)
	var n := maxi(1, roundi(len / 3.6))
	var seg := len / n
	var ch := 1.9
	var run0 := -1
	for i in n + 1:
		var solid := false
		if i < n:
			var f := (i + 0.5) / n
			solid = true
			for g in gaps:
				if f >= float(g[0]) and f <= float(g[1]):
					solid = false
		if solid:
			var hh := h
			var br := r.randf()
			var ruined := false
			if br < broke:
				hh = h * r.randf_range(0.3, 0.8)
				ruined = true
			elif br < broke + 0.12:
				hh = h * r.randf_range(0.85, 0.97)
			var c2 := a + dir * (seg * (i + 0.5))
			o.box(t * Transform3D(rot, Vector3(c2.x, hh * 0.5, c2.y)), Vector3(seg + 0.02, hh, th * 0.8), col.lerp(Color.BLACK, 0.6), 0.03, 8)       # nucleo (la malta)
			var rows := maxi(1, ceili(hh / ch))
			for row in rows:
				var y0 := row * ch
				var rh := minf(ch, hh - y0)
				var offs: Array = [-0.25, 0.25] if row % 2 == 0 else [-0.375, 0.0, 0.375]
				var wids: Array = [0.5, 0.5] if row % 2 == 0 else [0.25, 0.5, 0.25]
				for q in offs.size():
					var bw := seg * float(wids[q])
					var bc := c2 + dir * (seg * float(offs[q]))
					var tone: Color = col.lerp(Color.WHITE, r.randf() * 0.16).lerp(Color.BLACK, r.randf() * 0.2)
					for face in [1.0, -1.0]:
						var fp: Vector2 = bc + outw * (face * (th * 0.5 - 0.1))
						o.box(t * Transform3D(rot, Vector3(fp.x, y0 + rh * 0.5, fp.y)), Vector3(bw - 0.08, rh - 0.08, 0.32), tone, 0.1, 8)
			# camminamento (blocchi di copertura chiari) e merli sul lato esterno
			var slab := col.lerp(Color.WHITE, 0.14 + r.randf() * 0.08)
			o.box(t * Transform3D(rot, Vector3(c2.x, hh + 0.18, c2.y)), Vector3(seg - 0.05, 0.36, th - 0.05), slab, 0.08, 8)
			if walk and not ruined:
				var mp := c2 + outw * (th * 0.5 - 0.3)
				o.box(t * Transform3D(rot, Vector3(mp.x, hh + 0.36 + 0.5, mp.y)), Vector3(seg * 0.46, 1.0, 0.55), col.lerp(Color.WHITE, 0.06), 0.1, 8)
				var lp := c2 - outw * (th * 0.5 - 0.15)
				o.box(t * Transform3D(rot, Vector3(lp.x, hh + 0.36 + 0.2, lp.y)), Vector3(seg - 0.05, 0.4, 0.3), col, 0.08, 8)
			elif ruined and r.randf() < 0.7:
				for q in 2:
					var s := r.randf_range(0.4, 0.8)
					o.rock(t * Vector3(c2.x + r.randf_range(-1.0, 1.0) + outw.x * 1.4, s * 0.4, c2.y + r.randf_range(-1.0, 1.0) + outw.y * 1.4), Vector3(s, s * 0.7, s), col.lerp(Color.BLACK, 0.1), 0.16, 0.4, r.randf() * TAU)
			if run0 < 0:
				run0 = i
		elif run0 >= 0:
			var i1 := i - 1
			var cen := a + dir * (seg * (run0 + i1 + 1) * 0.5)
			cols.append(["b", _lw(t, p, yaw, cen), Vector2(seg * (i1 - run0 + 1) * 0.5 + 0.1, th * 0.5 + 0.1), yaw + ang])
			run0 = -1


static func _stone_rect(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, ctr: Vector2, half: Vector2, h: float, th: float, col: Color, r: RandomNumberGenerator, cols: Array, gaps_by_side: Dictionary, broke := 0.22, walk := true) -> void:
	var c0 := ctr + Vector2(-half.x, -half.y)
	var c1 := ctr + Vector2(half.x, -half.y)
	var c2 := ctr + Vector2(half.x, half.y)
	var c3 := ctr + Vector2(-half.x, half.y)
	_stone_wall(o, t, p, yaw, c0, c1, h, th, col, r, cols, gaps_by_side.get(0, []), broke, walk)
	_stone_wall(o, t, p, yaw, c1, c2, h, th, col, r, cols, gaps_by_side.get(1, []), broke, walk)
	_stone_wall(o, t, p, yaw, c2, c3, h, th, col, r, cols, gaps_by_side.get(2, []), broke, walk)
	_stone_wall(o, t, p, yaw, c3, c0, h, th, col, r, cols, gaps_by_side.get(3, []), broke, walk)


## torre quadrata piena: facce a blocchi, terrazza con merli, eventualmente sventrata
static func _sq_tower(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, ctr: Vector2, half: Vector2, h: float, col: Color, r: RandomNumberGenerator, cols: Array, broken: bool) -> void:
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(ctr.x, h * 0.5, ctr.y)), Vector3(half.x * 2.0 - 0.2, h, half.y * 2.0 - 0.2), col.lerp(Color.BLACK, 0.55), 0.03, 8)
	var c0 := ctr + Vector2(-half.x, -half.y)
	var c1 := ctr + Vector2(half.x, -half.y)
	var c2 := ctr + Vector2(half.x, half.y)
	var c3 := ctr + Vector2(-half.x, half.y)
	var sub: Array = []
	_stone_wall(o, t, p, yaw, c0, c1, h, 1.0, col, r, sub, [], 0.0 if not broken else 0.4, true)
	_stone_wall(o, t, p, yaw, c1, c2, h, 1.0, col, r, sub, [], 0.0 if not broken else 0.4, true)
	_stone_wall(o, t, p, yaw, c2, c3, h, 1.0, col, r, sub, [], 0.0 if not broken else 0.4, true)
	_stone_wall(o, t, p, yaw, c3, c0, h, 1.0, col, r, sub, [], 0.0 if not broken else 0.4, true)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(ctr.x, h + 0.15, ctr.y)), Vector3(half.x * 2.0 - 1.0, 0.3, half.y * 2.0 - 1.0), col.lerp(Color.WHITE, 0.12), 0.08, 8)
	for q in 3:        # feritoie illuminate
		var wx := ctr.x - half.x * 0.5 + q * half.x * 0.5
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(wx, h * 0.7, ctr.y + half.y + 0.02)), Vector3(0.28, 1.1, 0.12), Color(1.0, 0.78, 0.4, 0.15) if r.randf() < 0.35 else Color(0.02, 0.02, 0.03), 0.0, 8)
	if broken:
		_rubble(o, t, ctr + Vector2(half.x + 2.0, half.y + 1.0), 3.0, 8, col, r)
	cols.append(["b", _lw(t, p, yaw, ctr), half + Vector2(0.2, 0.2), yaw])


## torre tonda a corsi di pietra: fasce chiare e scure alternate, feritoie, merli o sommita' crollata
static func _stone_tower(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, pos: Vector2, rad: float, h: float, col: Color, r: RandomNumberGenerator, cols: Array, broken: bool, roof: bool) -> void:
	var rh := 1.5
	var rings := maxi(2, ceili(h / rh))
	for i in rings:
		var k1 := 1.0 - 0.006 * i
		var tone := col.lerp(Color.WHITE, 0.07 * (i % 2)).lerp(Color.BLACK, r.randf() * 0.1)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, i * rh, pos.y)), rad * k1, rad * k1 - 0.04, rh - 0.1, 12, tone, 0.1)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, i * rh + rh - 0.1, pos.y)), rad * k1 + 0.02, rad * k1 + 0.02, 0.1, 12, col.lerp(Color.BLACK, 0.5), 0.02)     # malta
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, 0, pos.y)), rad + 0.5, rad + 0.4, 1.0, 12, col.lerp(Color.BLACK, 0.2), 0.08)         # basamento
	for q in 6:
		var a := TAU * q / 6.0 + 0.3
		var lit := r.randf() < 0.3
		o.box(t * Transform3D(Basis(Vector3.UP, -a), Vector3(pos.x + cos(a) * (rad + 0.02), h * (0.55 + 0.2 * (q % 2)), pos.y + sin(a) * (rad + 0.02))), Vector3(0.14, 1.2, 0.3), Color(1.0, 0.78, 0.4, 0.15) if lit else Color(0.02, 0.02, 0.03), 0.0, 8)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, h, pos.y)), rad + 0.5, rad + 0.3, 0.45, 12, col.lerp(Color.WHITE, 0.12), 0.08)      # cornicione di ronda
	if broken:
		for q in 12:
			var a2 := TAU * q / 12.0
			var hh := r.randf_range(-0.2, 2.0)
			if hh > 0.4:
				o.box(t * Transform3D(Basis(Vector3.UP, -a2 + PI * 0.5), Vector3(pos.x + cos(a2) * (rad + 0.2), h + 0.4 + hh * 0.5, pos.y + sin(a2) * (rad + 0.2))), Vector3(1.8, hh, 0.7), col, 0.14, 8)
		for q in 7:
			var s := r.randf_range(0.5, 1.3)
			var a3 := r.randf() * TAU
			o.rock(t * Vector3(pos.x + cos(a3) * (rad + 1.8), s * 0.4, pos.y + sin(a3) * (rad + 1.8)), Vector3(s, s * 0.7, s), col, 0.16, 0.4, a3)
	else:
		for q in 12:
			var a4 := TAU * q / 12.0
			if q % 2 == 0:
				o.box(t * Transform3D(Basis(Vector3.UP, -a4 + PI * 0.5), Vector3(pos.x + cos(a4) * (rad + 0.1), h + 0.45 + 0.55, pos.y + sin(a4) * (rad + 0.1))), Vector3(1.6, 1.1, 0.6), col.lerp(Color.WHITE, 0.08), 0.1, 8)
		if roof:
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, h + 0.4, pos.y)), rad * 0.95, 0.12, 4.2, 12, Color(0.19, 0.15, 0.17), 0.1)
	cols.append(["c", _lw(t, p, yaw, pos), rad + 0.15])


static func _stairs(o: W3DBuilder, t: Transform3D, start: Vector3, dir: Vector2, steps: int, width: float, rise: float, col: Color) -> void:
	var rot := Basis(Vector3.UP, -atan2(dir.y, dir.x))
	for i in steps:
		var pos := start + Vector3(dir.x, 0, dir.y) * (0.5 * (i + 0.5)) + Vector3(0, rise * (i + 0.5) * 0.5, 0)
		o.box(t * Transform3D(rot, pos), Vector3(0.55, rise * (i + 1), width), col.lerp(Color.WHITE, 0.04 * (i % 2)), 0.08, 8)


static func _column(o: W3DBuilder, t: Transform3D, pos: Vector2, h: float, col: Color) -> void:
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, 0, pos.y)), 0.75, 0.7, 0.5, 8, col.lerp(Color.BLACK, 0.15), 0.06)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, 0.5, pos.y)), 0.56, 0.5, h, 8, col.lerp(Color.WHITE, 0.08), 0.08)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(pos.x, 0.5 + h, pos.y)), 0.72, 0.68, 0.3, 8, col, 0.06)


static func _castle(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array, pal: Array) -> void:
	var col: Color = pal[0]
	var X := 30.0
	var Z := 24.0
	var cs := cols
	# pavimentazione: lastricato di cortile con chiazze d'erba
	_floor(o, t, Vector2(0, 0), Vector2(X, Z), Color(0.12, 0.115, 0.12), 0.03)
	for q in 26:
		var qc := Vector2(r.randf_range(-X + 3.0, X - 3.0), r.randf_range(-Z + 3.0, Z - 3.0))
		_floor(o, t, qc, Vector2(r.randf_range(1.5, 4.0), r.randf_range(1.2, 3.0)), Color(0.19, 0.18, 0.18).lerp(Color(0.1, 0.18, 0.1), r.randf() * 0.8), 0.05)
	# fossato asciutto attorno ai tre lati (nord, est, ovest)
	for sg in [-1.0, 1.0]:
		_floor(o, t, Vector2(sg * (X + 4.0), 0), Vector2(3.0, Z + 7.0), Color(0.05, 0.05, 0.055), 0.025)
	_floor(o, t, Vector2(0, -Z - 4.0), Vector2(X + 7.0, 3.0), Color(0.05, 0.05, 0.055), 0.025)
	# ---- mura esterne: portone a sud, tre grandi brecce a nord, est e ovest
	var bn := 0.18 + r.randf() * 0.5
	var be := 0.15 + r.randf() * 0.55
	var bw := 0.15 + r.randf() * 0.55
	var c0 := Vector2(-X, -Z)
	var c1 := Vector2(X, -Z)
	var c2 := Vector2(X, Z)
	var c3 := Vector2(-X, Z)
	_stone_wall(o, t, p, yaw, c0, c1, 7.5, 2.2, col, r, cs, [[bn, bn + 0.13]], 0.16)
	_stone_wall(o, t, p, yaw, c1, c2, 7.5, 2.2, col, r, cs, [[be, be + 0.16]], 0.16)
	_stone_wall(o, t, p, yaw, c2, c3, 7.5, 2.2, col, r, cs, [[0.435, 0.565]], 0.16)
	_stone_wall(o, t, p, yaw, c3, c0, 7.5, 2.2, col, r, cs, [[bw, bw + 0.14]], 0.16)
	# ---- torri d'angolo (due crollate) e torri quadrate a meta' dei lati est e ovest
	var rt := [Vector2(-X, -Z), Vector2(X, -Z), Vector2(X, Z), Vector2(-X, Z)]
	var rh := [13.5, 11.0, 12.5, 9.0]
	for q in 4:
		_stone_tower(o, t, p, yaw, rt[q], 4.4, rh[q], col, r, cs, q % 2 == 1, q == 0)
	_sq_tower(o, t, p, yaw, Vector2(-X, 0), Vector2(3.4, 3.4), 10.5, col, r, cs, false)
	_sq_tower(o, t, p, yaw, Vector2(X, 0), Vector2(3.4, 3.4), 9.0, col, r, cs, true)
	# ---- porta fortificata a sud: due torri quadrate, arco spezzato, saracinesca, barbacane
	_sq_tower(o, t, p, yaw, Vector2(-7.4, Z), Vector2(3.6, 3.6), 12.0, col, r, cs, false)
	_sq_tower(o, t, p, yaw, Vector2(7.4, Z), Vector2(3.6, 3.6), 11.0, col, r, cs, true)
	o.box(t * Transform3D(Basis(Vector3(0, 0, 1), 0.04), Vector3(-1.9, 8.8, Z)), Vector3(5.2, 1.3, 2.6), col.lerp(Color.WHITE, 0.1), 0.1, 8)       # architrave dell'arco
	for q in 7:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(-2.2 + q * 0.7, 6.4, Z + 0.15)), Vector3(0.12, 3.8, 0.12), Color(0.17, 0.12, 0.1), 0.05, 8)    # sbarre della saracinesca
	_stone_wall(o, t, p, yaw, Vector2(-3.6, Z + 3.7), Vector2(-3.6, Z + 12.0), 5.0, 1.6, col, r, cs, [], 0.3, false)
	_stone_wall(o, t, p, yaw, Vector2(3.6, Z + 12.0), Vector2(3.6, Z + 3.7), 5.0, 1.6, col, r, cs, [], 0.3, false)
	for q in 5:        # ponte levatoio: assi marcite
		o.box(t * Transform3D(Basis(Vector3.UP, r.randf_range(-0.05, 0.05)), Vector3(r.randf_range(-1.4, 1.4), 0.12, Z + 3.0 + q * 1.4)), Vector3(3.8, 0.18, 1.2), WOOD, 0.1, 8)
	_torch(o, t, Vector3(-3.0, 0.0, Z + 5.5), lamps, 2.0)
	_torch(o, t, Vector3(3.0, 0.0, Z + 5.5), lamps, 2.0)
	var bp := t * Vector3(-1.2, 9.5, Z + 1.5)
	o.quad(bp, bp + t.basis * Vector3(1.6, 0, 0), bp + t.basis * Vector3(1.6, -4.0, 0), bp + t.basis * Vector3(0.0, -4.8, 0), Color(0.42, 0.08, 0.1))
	# ---- muro interno tra cortile esterno e cortile interno (nord), con porta e una breccia, scale di accesso al camminamento
	var iz := -6.0
	_stone_wall(o, t, p, yaw, Vector2(-X + 3.0, iz), Vector2(X - 3.0, iz), 8.5, 2.0, col, r, cs, [[0.43, 0.57], [0.78, 0.86]], 0.14, false)
	_sq_tower(o, t, p, yaw, Vector2(-5.5, iz), Vector2(2.2, 2.2), 11.0, col, r, cs, false)
	_sq_tower(o, t, p, yaw, Vector2(5.5, iz), Vector2(2.2, 2.2), 10.0, col, r, cs, true)
	_stairs(o, t, Vector3(-X + 6.0, 0, iz + 2.0), Vector2(1, 0), 11, 1.6, 0.74, col)
	_stairs(o, t, Vector3(X - 6.0, 0, Z - 2.0), Vector2(0, -1), 9, 1.6, 0.8, col)
	# ---- mastio nel cortile interno: tre sale, torrette d'angolo, finestre illuminate, trono
	var kc := Vector2(0, -15.0)
	var kh := Vector2(9.5, 6.5)
	_floor(o, t, kc, kh, Color(0.2, 0.19, 0.21), 0.06)
	for q in 5:       # mattonelle del pavimento del mastio
		_floor(o, t, kc + Vector2(r.randf_range(-7.0, 7.0), r.randf_range(-4.5, 4.5)), Vector2(r.randf_range(0.8, 2.0), r.randf_range(0.8, 1.6)), Color(0.14, 0.13, 0.15), 0.065)
	_stone_rect(o, t, p, yaw, kc, kh, 14.0, 2.4, pal[1], r, cs, {2: [[0.42, 0.58]], 3: [[0.3, 0.4]]}, 0.2, true)
	_stone_wall(o, t, p, yaw, Vector2(-2.5, kc.y - kh.y + 1.0), Vector2(-2.5, kc.y + 1.5), 9.0, 1.3, pal[1], r, cs, [[0.4, 0.62]], 0.3, false)       # tramezzo: sala del trono / sale laterali
	for q in 4:
		_column(o, t, Vector2(kc.x - 6.5 + q * 4.2, kc.y + 3.2), r.randf_range(4.5, 9.0) if q % 2 == 1 else 9.5, pal[1])
		cs.append(["c", _lw(t, p, yaw, Vector2(kc.x - 6.5 + q * 4.2, kc.y + 3.2)), 0.8])
	for q in 5:        # finestre lungo la facciata sud del mastio
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(kc.x - 7.0 + q * 3.5, 8.0, kc.y + kh.y + 0.04)), Vector3(0.8, 2.0, 0.14), Color(1.0, 0.78, 0.4, 0.18) if q != 2 else Color(0.02, 0.02, 0.03), 0.0, 8)
	var kt := [Vector2(-kh.x, -kh.y + 0.0) + kc, Vector2(kh.x, -kh.y) + kc, Vector2(kh.x, kh.y) + kc, Vector2(-kh.x, kh.y) + kc]
	var kth := [17.0, 15.0, 17.5, 12.5]
	for q in 4:
		_stone_tower(o, t, p, yaw, kt[q], 2.9, kth[q], pal[1], r, cs, q == 3, q % 2 == 0)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(kc.x + 3.5, 0.55, kc.y - kh.y + 2.2)), Vector3(7.0, 1.1, 2.6), pal[2], 0.08, 8)       # pedana del trono
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(kc.x + 3.5, 1.9, kc.y - kh.y + 1.4)), Vector3(1.4, 1.7, 0.8), pal[1], 0.1, 8)
	cs.append(["b", _lw(t, p, yaw, Vector2(kc.x + 3.5, kc.y - kh.y + 2.2)), Vector2(3.6, 1.4), yaw])
	_torch(o, t, Vector3(kc.x - 1.0, 0.0, kc.y + kh.y - 1.6), lamps, 1.9)
	_torch(o, t, Vector3(kc.x + 1.0, 0.0, kc.y + kh.y - 1.6), lamps, 1.9)
	_torch(o, t, Vector3(kc.x + 3.5, 0.0, kc.y - kh.y + 3.4), lamps, 1.8)
	_bx2(o, t, Vector3(kc.x - 5.5, 12.5, kc.y - 2.0), Basis(Vector3(0, 0, 1), -0.3), Vector3(7.0, 0.5, 0.6), WOOD_D, 0.08)      # travi del tetto crollato
	_bx2(o, t, Vector3(kc.x + 5.0, 11.0, kc.y + 2.0), Basis(Vector3(1, 0, 0), 0.4), Vector3(0.6, 0.5, 7.0), WOOD_D, 0.08)
	# ---- grande sala (est del cortile esterno): colonne e finestre, tetto crollato
	var hc := Vector2(16.0, 12.0)
	var hh2 := Vector2(10.0, 5.2)
	_floor(o, t, hc, hh2, Color(0.17, 0.16, 0.17), 0.06)
	_stone_rect(o, t, p, yaw, hc, hh2, 8.5, 1.5, col, r, cs, {3: [[0.4, 0.6]], 0: [[0.2, 0.33]], 1: [[0.5, 0.6]]}, 0.28, true)
	for q in 4:
		for sg in [-1.0, 1.0]:
			_column(o, t, hc + Vector2(-6.5 + q * 4.4, sg * 2.2), r.randf_range(3.0, 7.0) if r.randf() < 0.5 else 7.2, col)
			cs.append(["c", _lw(t, p, yaw, hc + Vector2(-6.5 + q * 4.4, sg * 2.2)), 0.75])
	for q in 4:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(hc.x - 7.5 + q * 5.0, 5.0, hc.y + hh2.y + 0.05)), Vector3(1.0, 2.2, 0.14), Color(0.35, 0.5, 0.9, 0.14) if q % 2 == 0 else Color(0.02, 0.02, 0.03), 0.0, 8)
	_torch(o, t, Vector3(hc.x - 9.0, 0.0, hc.y), lamps, 1.7)
	# ---- cappella con abside (ovest del cortile esterno)
	var cc := Vector2(-17.0, 13.0)
	var ch := Vector2(7.0, 4.6)
	_floor(o, t, cc, ch, Color(0.18, 0.17, 0.19), 0.06)
	_stone_rect(o, t, p, yaw, cc, ch, 8.0, 1.4, pal[1], r, cs, {2: [[0.42, 0.58]], 3: [[0.4, 0.6]]}, 0.25, true)
	var ap0 := Vector2(cc.x - ch.x, cc.y - ch.y)
	var ap1 := Vector2(cc.x - ch.x - 3.4, cc.y - ch.y * 0.45)
	var ap2 := Vector2(cc.x - ch.x - 3.4, cc.y + ch.y * 0.45)
	var ap3 := Vector2(cc.x - ch.x, cc.y + ch.y)
	_stone_wall(o, t, p, yaw, ap3, ap2, 8.0, 1.4, pal[1], r, cs, [], 0.3, false)
	_stone_wall(o, t, p, yaw, ap2, ap1, 8.0, 1.4, pal[1], r, cs, [], 0.3, false)
	_stone_wall(o, t, p, yaw, ap1, ap0, 8.0, 1.4, pal[1], r, cs, [], 0.3, false)
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(cc.x - ch.x - 1.8, 0.6, cc.y)), Vector3(1.4, 1.2, 2.4), pal[2], 0.08, 8)       # altare
	_torch(o, t, Vector3(cc.x - ch.x - 0.5, 0.0, cc.y - 1.5), lamps, 1.5)
	for q in 3:
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(cc.x - 3.0 + q * 2.8, 4.8, cc.y + ch.y + 0.05)), Vector3(0.9, 2.4, 0.14), Color(0.35, 0.5, 0.9, 0.14), 0.0, 8)
	# ---- scuderia a cielo aperto, pozzo, bancarelle, carri e rovine nel cortile
	for q in 4:
		_bx2(o, t, Vector3(-9.0 + q * 2.0, 1.2, 21.0), Basis.IDENTITY, Vector3(0.26, 2.4, 0.26), WOOD_D, 0.08)
	_bx2(o, t, Vector3(-6.0, 2.55, 21.0), Basis(Vector3(0, 0, 1), 0.04), Vector3(8.4, 0.2, 2.6), Color(0.28, 0.2, 0.12), 0.1)
	for q in 3:
		_bx2(o, t, Vector3(-8.0 + q * 2.6, 0.4, 22.3), Basis.IDENTITY, Vector3(1.4, 0.4, 0.5), WOOD_L, 0.1)
	cs.append(["b", _lw(t, p, yaw, Vector2(-6.0, 21.4)), Vector2(4.4, 1.5), yaw])
	for i in 10:
		var a5 := TAU * i / 10.0
		_bx2(o, t, Vector3(cos(a5) * 1.4, 0.45, 8.0 + sin(a5) * 1.4), Basis(Vector3.UP, -a5), Vector3(0.7, 0.9, 0.9), col, 0.14)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.82, 8.0)), 1.1, 1.1, 0.04, 8, Color(0.02, 0.03, 0.05), 0.0)
	cs.append(["c", _lw(t, p, yaw, Vector2(0, 8.0)), 1.7])
	for sx in [-5.0, 5.0]:        # bancarelle marcite
		_bx2(o, t, Vector3(sx, 1.0, 14.0), Basis.IDENTITY, Vector3(0.18, 2.0, 0.18), WOOD_D, 0.08)
		_bx2(o, t, Vector3(sx + 2.0, 1.0, 14.0), Basis.IDENTITY, Vector3(0.18, 2.0, 0.18), WOOD_D, 0.08)
		_bx2(o, t, Vector3(sx + 1.0, 2.05, 14.0), Basis(Vector3(0, 0, 1), 0.1 * sx / 5.0), Vector3(2.8, 0.14, 1.8), Color(0.38, 0.12, 0.1), 0.1)
		_bx2(o, t, Vector3(sx + 1.0, 0.85, 14.0), Basis.IDENTITY, Vector3(2.0, 0.14, 0.9), WOOD_L, 0.08)
	_bx2(o, t, Vector3(10.0, 0.6, -1.0), Basis(Vector3.UP, 0.5) * Basis(Vector3(0, 0, 1), 0.18), Vector3(2.6, 0.2, 1.4), WOOD, 0.1)
	cs.append(["b", _lw(t, p, yaw, Vector2(10.0, -1.0)), Vector2(1.5, 0.9), yaw + 0.5])
	o.cyl(t * Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3(0, 0, 1), PI * 0.5), Vector3(-22.0, 1.4, -17.0)), 1.5, 1.45, 7.0, 10, col, 0.1)       # tronco di torre caduto
	cs.append(["b", _lw(t, p, yaw, Vector2(-19.0, -16.0)), Vector2(3.6, 1.5), yaw + 0.6])
	_rubble(o, t, Vector2(-X + 4.0, -iz), 4.0, 8, col, r)
	_rubble(o, t, Vector2(X - 5.0, -14.0), 4.0, 9, col, r)
	_rubble(o, t, Vector2(0, 18.0), 3.0, 6, col, r)
	for q in 10:      # alberelli e arbusti che si riprendono il castello
		var a6 := r.randf() * TAU
		var d6 := r.randf_range(4.0, 22.0)
		var tp := t * Vector3(cos(a6) * d6 * 1.2, 0, sin(a6) * d6 * 0.9)
		if absf(cos(a6) * d6 * 1.2) < X - 3.0 and absf(sin(a6) * d6 * 0.9) < Z - 3.0:
			o.shard(tp, tp + Vector3(r.randf_range(-0.2, 0.2), r.randf_range(1.6, 3.0), r.randf_range(-0.2, 0.2)), 0.16, 0.03, Color(0.12, 0.09, 0.07), 0.5, 0.05, 0.0)


# ------------------------------------------------------------------ monastero in rovina
static func _monastery(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array, pal: Array) -> void:
	var H := 8.0
	_floor(o, t, Vector2.ZERO, Vector2(H + 1.5, H + 1.5), Color(0.15, 0.15, 0.16))
	# chiostro: portici di colonne con archi spezzati, aperti verso il cortile
	for side in 4:
		var a := Vector2(-H, -H)
		var b := Vector2(H, -H)
		match side:
			1:
				a = Vector2(H, -H)
				b = Vector2(H, H)
			2:
				a = Vector2(H, H)
				b = Vector2(-H, H)
			3:
				a = Vector2(-H, H)
				b = Vector2(-H, -H)
		var n := 7
		for i in n + 1:
			if side == 2 and (i == 3 or i == 4):
				continue      # ingresso a sud
			var c := a.lerp(b, float(i) / n)
			var h := 3.6 if r.randf() > 0.25 else r.randf_range(1.0, 2.8)
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)), 0.42, 0.36, h, 8, pal[1], 0.1)
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 0, c.y)), 0.55, 0.5, 0.35, 8, pal[2], 0.08)
			cols.append(["c", _lw(t, p, yaw, c), 0.5])
			if i < n and h > 3.0 and r.randf() > 0.2:
				var c2 := a.lerp(b, (float(i) + 0.5) / n)
				var along := (b - a).normalized()
				_bx(o, t, Vector3(c2.x, 3.8, c2.y), Basis(Vector3.UP, -atan2(along.y, along.x)), Vector3(a.distance_to(b) / n + 0.3, 0.5, 0.7), pal[0], 0.1)
	# cappella a nord con navata scoperchiata e abside
	var cc := Vector2(0, -H - 7.0)
	_rect_walls(o, t, p, yaw, cc, Vector2(4.2, 6.0), 7.0, 1.0, pal[0], r, cols, {2: [[0.38, 0.62]]}, 0.28, false)
	for sg in [-1.0, 1.0]:
		for q in 3:
			_bx(o, t, Vector3(cc.x + sg * 4.2, 4.2, cc.y - 3.5 + q * 3.5), Basis.IDENTITY, Vector3(0.14, 2.2, 1.2), Color(0.35, 0.5, 0.9, 0.12), 0.0)      # vetrate
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(cc.x, 0, cc.y - 5.5)), 0.9, 0.9, 1.0, 6, pal[1], 0.08)       # altare
	_torch(o, t, Vector3(cc.x - 1.4, 0.0, cc.y - 5.0), lamps, 1.5)
	_torch(o, t, Vector3(cc.x + 1.4, 0.0, cc.y - 5.0), lamps, 1.5)
	# fontana al centro e giardino incolto
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.9, 1.9, 0.7, 10, pal[1], 0.08)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), 1.55, 1.55, 0.05, 10, Color(0.06, 0.1, 0.16), 0.0)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3.ZERO), 0.3, 0.2, 1.8, 6, pal[1], 0.08)
	cols.append(["c", p, 2.0])
	_rubble(o, t, Vector2(-4.5, 4.0), 2.5, 5, pal[0], r)
	for q in 8:
		var a2 := r.randf() * TAU
		var d := r.randf_range(2.8, 6.0)
		var b := t * Vector3(cos(a2) * d, 0, sin(a2) * d)
		o.shard(b, b + Vector3(r.randf_range(-0.2, 0.2), r.randf_range(0.5, 1.1), r.randf_range(-0.2, 0.2)), 0.08, 0.01, Color(0.18, 0.28, 0.12), 0.3, 0.0, 0.0)
	# refettorio in rovina a est
	_rect_walls(o, t, p, yaw, Vector2(H + 7.0, 0), Vector2(5.0, 4.0), 5.0, 1.0, pal[0], r, cols, {3: [[0.4, 0.6]], 0: [[0.2, 0.34]]}, 0.4, false)


# ------------------------------------------------------------------ forte di palizzata
static func _fort(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var R := 12.0
	var n := 14
	_floor(o, t, Vector2.ZERO, Vector2(R, R), Color(0.17, 0.14, 0.1))
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var gap: Array = []
		if i == 0:
			gap = [[0.2, 0.8]]       # cancello
		_wall(o, t, p, yaw, Vector2(cos(a0), sin(a0)) * R, Vector2(cos(a1), sin(a1)) * R, 3.6, 0.5, WOOD, r, cols, gap, 0.2, false, true)
	for q in 2:      # torrette di guardia
		var a := PI * q + PI * 0.5
		var c := Vector2(cos(a), sin(a)) * (R - 0.2)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_bx(o, t, Vector3(c.x + sx * 0.9, 2.6, c.y + sz * 0.9), Basis.IDENTITY, Vector3(0.28, 5.2, 0.28), WOOD_D, 0.08)
		_bx(o, t, Vector3(c.x, 5.2, c.y), Basis.IDENTITY, Vector3(2.4, 0.22, 2.4), WOOD_L, 0.08)
		o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 6.4, c.y)), 1.9, 0.05, 1.2, 4, Color(0.22, 0.15, 0.1), 0.08)
		cols.append(["c", _lw(t, p, yaw, c), 1.3])
	# casa lunga, fuoco centrale, tende e casse
	_bx(o, t, Vector3(-5.5, 1.2, -4.0), Basis.IDENTITY, Vector3(5.5, 2.4, 3.2), WOOD, 0.1)
	for sg in [-1.0, 1.0]:
		_bx(o, t, Vector3(-5.5, 3.0, -4.0 + sg * 0.85), Basis(Vector3.RIGHT, sg * 0.55), Vector3(5.8, 0.14, 2.2), Color(0.22, 0.17, 0.1), 0.1)
	_bx(o, t, Vector3(-5.5, 1.0, -2.35), Basis.IDENTITY, Vector3(0.9, 1.8, 0.1), WOOD_D, 0.05)
	cols.append(["b", _lw(t, p, yaw, Vector2(-5.5, -4.0)), Vector2(2.9, 1.7), yaw])
	for q in 5:
		var a2 := TAU * q / 5.0
		o.rock(t * Vector3(cos(a2) * 1.1, 0.2, sin(a2) * 1.1), Vector3(0.5, 0.36, 0.5), STONE, 0.14, 0.4, a2)
	for q in 5:
		var a3 := r.randf() * TAU
		o.cyl(t * Transform3D(Basis(Vector3.UP, a3) * Basis(Vector3.FORWARD, r.randf_range(0.5, 1.1)), Vector3(0, 0.2, 0)), 0.1, 0.09, 1.2, 4, Color(0.13, 0.09, 0.07), 0.1)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.5, 0.04, 1.2, 5, Color(0.95, 0.62, 0.3, 0.1), 0.2)
	var fp := t * Vector3(0, 1.0, 0)
	lamps.append(Vector4(fp.x, 1.0, fp.z, 2.4))
	cols.append(["c", p, 0.9])
	for q in 3:
		var c3 := Vector2(5.0 + (q % 2) * 2.6, -3.0 + q * 3.4)
		o.cyl(t * Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(c3.x, 0, c3.y)), 1.7, 0.08, 2.4, 4, Color(0.4, 0.34, 0.24).lerp(Color(0.3, 0.12, 0.1), r.randf() * 0.6), 0.1)
		cols.append(["c", _lw(t, p, yaw, c3), 1.3])
	for q in 4:
		_bx(o, t, Vector3(-2.0 + q * 0.7, 0.35 + (q % 2) * 0.35, 6.5), Basis(Vector3.UP, r.randf_range(-0.3, 0.3)), Vector3(0.65, 0.65, 0.65), WOOD_L, 0.1)


# ------------------------------------------------------------------ anfiteatro in rovina
static func _arena(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array, pal: Array) -> void:
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), 8.2, 8.2, 0.06, 20, Color(0.36, 0.3, 0.2), 0.05)
	var tiers := [[9.2, 1.6], [10.8, 2.8], [12.4, 4.0]]
	for tr in tiers:
		var rad: float = tr[0]
		var h: float = tr[1]
		var n := int(rad * 2.2)
		for i in n:
			var a := TAU * (i + 0.5) / n
			# quattro ingressi (nord, est, sud, ovest) e pezzi mancanti
			var near_gate := false
			for g in 4:
				if absf(angle_difference(a, g * PI * 0.5)) < 0.2:
					near_gate = true
			if near_gate or r.randf() < 0.14:
				continue
			var hh := h if r.randf() > 0.3 else h * r.randf_range(0.4, 0.8)
			var c := Vector2(cos(a), sin(a)) * rad
			var sl := TAU * rad / n + 0.1
			_bx(o, t, Vector3(c.x, hh * 0.5, c.y), Basis(Vector3.UP, -a + PI * 0.5), Vector3(sl, hh, 1.6), pal[0].lerp(Color.WHITE, r.randf() * 0.1), 0.12)
			cols.append(["b", _lw(t, p, yaw, c), Vector2(sl * 0.5, 0.85), yaw - a + PI * 0.5])
	# archi esterni spezzati e colonne
	for i in 12:
		var a2 := TAU * i / 12.0 + 0.13
		if r.randf() < 0.3:
			continue
		var c2 := Vector2(cos(a2), sin(a2)) * 14.0
		var h2 := r.randf_range(3.0, 6.5)
		_bx(o, t, Vector3(c2.x, h2 * 0.5, c2.y), Basis(Vector3.UP, -a2), Vector3(1.0, h2, 1.4), pal[1], 0.12)
		cols.append(["c", _lw(t, p, yaw, c2), 0.9])
	# pilastro e tracce di combattimento al centro
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)), 0.55, 0.45, 2.6, 6, pal[1], 0.1)
	cols.append(["c", p, 0.6])
	for q in 5:
		var a3 := r.randf() * TAU
		var d := r.randf_range(2.0, 6.5)
		o.quad(t * Vector3(cos(a3) * d - 0.4, 0.07, sin(a3) * d), t * Vector3(cos(a3) * d + 0.4, 0.07, sin(a3) * d - 0.3), t * Vector3(cos(a3) * d + 0.5, 0.07, sin(a3) * d + 0.4), t * Vector3(cos(a3) * d - 0.3, 0.07, sin(a3) * d + 0.3), Color(0.28, 0.04, 0.05))
	_torch(o, t, Vector3(0.0, 0.0, 8.8), lamps, 1.6)
	_torch(o, t, Vector3(8.8, 0.0, 0.0), lamps, 1.6)


# ------------------------------------------------------------------ villaggio abbandonato
static func _village(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var n := 6
	for i in n:
		var a := TAU * i / n + r.randf_range(-0.2, 0.2)
		var d := r.randf_range(11.0, 14.0)
		var c := Vector2(cos(a), sin(a)) * d
		var hy := a + PI * 0.5 + r.randf_range(-0.3, 0.3)
		var hw := r.randf_range(2.6, 3.4)
		var hd := r.randf_range(2.0, 2.8)
		var wall_col := Color(0.3, 0.26, 0.2).lerp(Color(0.22, 0.2, 0.17), r.randf())
		# pareti di una casa senza tetto: la ricavo con un trasformatore locale
		var ht := t * Transform3D(Basis(Vector3.UP, hy), Vector3(c.x, 0, c.y))
		var hp := _lw(t, p, yaw, c)
		var hyaw := yaw + hy
		_floor(o, ht, Vector2.ZERO, Vector2(hw, hd), Color(0.16, 0.12, 0.09), 0.05)
		_rect_walls(o, ht, hp, hyaw, Vector2.ZERO, Vector2(hw, hd), 2.7, 0.35, wall_col, r, cols, {2: [[0.4, 0.6]], [0, 1, 3][r.randi() % 3]: [[0.15, 0.4]]}, 0.5, false)
		for q in 2:        # travi del tetto crollato
			_bx(o, ht, Vector3(r.randf_range(-hw * 0.5, hw * 0.5), 2.2 + q * 0.3, r.randf_range(-hd * 0.5, hd * 0.5)), Basis(Vector3.UP, r.randf() * PI) * Basis(Vector3(0, 0, 1), r.randf_range(-0.3, 0.3)), Vector3(hw * 1.6, 0.14, 0.18), WOOD_D, 0.08)
		if r.randf() < 0.4:
			_bx(o, ht, Vector3(0, 1.0, -hd * 0.5), Basis.IDENTITY, Vector3(1.1, 1.0, 0.8), WOOD_L, 0.1)       # tavolo rimasto
	# pozzo centrale, carro rotto, recinti storti
	for i in 8:
		var a2 := TAU * i / 8.0
		_bx(o, t, Vector3(cos(a2) * 0.95, 0.4, sin(a2) * 0.95), Basis(Vector3.UP, -a2), Vector3(0.5, 0.8, 0.7), STONE, 0.14)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), 0.8, 0.8, 0.02, 8, Color(0.02, 0.03, 0.05), 0.0)
	cols.append(["c", p, 1.25])
	_bx(o, t, Vector3(4.0, 0.55, 3.0), Basis(Vector3.UP, 0.5) * Basis(Vector3(0, 0, 1), 0.2), Vector3(2.4, 0.2, 1.3), WOOD, 0.1)
	for sg in [-1.0, 1.0]:
		o.cyl(t * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(4.0, 0.5, 3.0 + sg * 0.7)), 0.5, 0.5, 0.12, 8, WOOD_D, 0.08)
	cols.append(["b", _lw(t, p, yaw, Vector2(4.0, 3.0)), Vector2(1.3, 0.8), yaw + 0.5])
	for q in 6:
		var a3 := r.randf() * TAU
		var d3 := r.randf_range(5.0, 9.0)
		_bx(o, t, Vector3(cos(a3) * d3, 0.5, sin(a3) * d3), Basis(Vector3.UP, r.randf() * TAU) * Basis(Vector3(0, 0, 1), r.randf_range(-0.4, 0.4)), Vector3(0.1, 1.0, 0.1), WOOD_D, 0.06)
	var lp := t * Vector3(0, 1.5, 3.0)
	lamps.append(Vector4(lp.x, 1.5, lp.z, 0.9))


# ------------------------------------------------------------------ ingresso di miniera
static func _mine(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var rock := Color(0.2, 0.19, 0.21)
	# parete rocciosa con apertura al centro (verso +z)
	for q in 9:
		var x := -8.0 + q * 2.0
		if absf(x) < 2.2:
			continue
		var h := r.randf_range(4.0, 7.5)
		o.rock(t * Vector3(x, h * 0.5, 0), Vector3(2.8, h, 3.0), rock.lerp(Color.WHITE, r.randf() * 0.12), 0.16, 0.42, r.randf() * TAU)
		cols.append(["c", _lw(t, p, yaw, Vector2(x, 0)), 1.5])
	o.rock(t * Vector3(0, 6.5, -0.4), Vector3(5.5, 2.5, 3.0), rock, 0.16, 0.4, 0.5)
	for sg in [-1.0, 1.0]:
		_bx(o, t, Vector3(sg * 1.7, 1.7, 1.2), Basis.IDENTITY, Vector3(0.35, 3.4, 0.35), WOOD, 0.1)
	_bx(o, t, Vector3(0, 3.55, 1.2), Basis.IDENTITY, Vector3(4.0, 0.4, 0.5), WOOD, 0.1)
	_bx(o, t, Vector3(0, 1.6, -0.6), Basis.IDENTITY, Vector3(3.2, 3.2, 0.3), Color(0.01, 0.01, 0.015), 0.0)         # galleria buia
	cols.append(["b", _lw(t, p, yaw, Vector2(0, -0.4)), Vector2(1.8, 0.6), yaw])
	# binari, traversine e carrello
	for q in 9:
		_bx(o, t, Vector3(0, 0.05, 2.0 + q * 0.85), Basis.IDENTITY, Vector3(1.6, 0.08, 0.2), WOOD_D, 0.05)
	for sg in [-0.6, 0.6]:
		_bx(o, t, Vector3(sg, 0.12, 5.7), Basis.IDENTITY, Vector3(0.07, 0.07, 8.0), Color(0.22, 0.2, 0.2), 0.03)
	_bx(o, t, Vector3(0, 0.62, 5.0), Basis.IDENTITY, Vector3(1.0, 0.7, 1.5), Color(0.28, 0.2, 0.17), 0.1)
	for q in 4:
		o.rock(t * Vector3(r.randf_range(-0.3, 0.3), 1.05, 4.6 + q * 0.3), Vector3(0.4, 0.3, 0.4), Color(0.5, 0.32, 0.18) if q % 2 == 0 else Color(0.3, 0.38, 0.5), 0.12, 0.3, q)
	cols.append(["b", _lw(t, p, yaw, Vector2(0, 5.0)), Vector2(0.6, 0.85), yaw])
	for q in 3:        # cumuli di minerale
		var sx := 1.0 if q % 2 == 0 else -1.0
		var c := Vector2((4.5 + r.randf() * 2.0) * sx, 3.0 + r.randf() * 3.0)
		for k in 5:
			o.rock(t * Vector3(c.x + r.randf_range(-0.8, 0.8), 0.25, c.y + r.randf_range(-0.8, 0.8)), Vector3(0.7, 0.5, 0.7), Color(0.34, 0.3, 0.27).lerp(Color(0.2, 0.3, 0.4), r.randf()), 0.14, 0.4, q + k)
		cols.append(["c", _lw(t, p, yaw, c), 1.1])
	_torch(o, t, Vector3(-2.4, 0.0, 1.8), lamps, 1.6)
	_torch(o, t, Vector3(2.4, 0.0, 1.8), lamps, 1.6)


# ------------------------------------------------------------------ tempio nel ghiaccio
static func _ice_temple(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	var ice := Color(0.62, 0.78, 0.9)
	var snow := Color(0.85, 0.9, 0.96)
	for q in 3:
		var s := 9.0 - q * 1.5
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, q * 0.3 + 0.15, 0)), Vector3(s, 0.3, s * 1.3), Color(0.55, 0.62, 0.7).lerp(snow, q * 0.2), 0.1, 8)
	for sz in [-1.0, 1.0]:
		for q in 4:
			var x := -3.4 + q * 2.3
			var broken := r.randf() < 0.3
			var h := r.randf_range(1.5, 3.0) if broken else 4.6
			var c := Vector2(x, sz * 4.0)
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 0.9, c.y)), 0.55, 0.45, h, 8, ice, 0.1)
			o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 0.9, c.y)), 0.75, 0.7, 0.3, 8, snow, 0.08)
			if not broken:
				o.box(t * Transform3D(Basis.IDENTITY, Vector3(c.x, 5.65, c.y)), Vector3(1.4, 0.4, 1.4), snow, 0.1, 8)
			cols.append(["c", _lw(t, p, yaw, c), 0.65])
	for q in 2:        # architravi rimasti
		o.box(t * Transform3D(Basis.IDENTITY, Vector3(-2.2 + q * 4.6, 5.9, 4.0)), Vector3(4.4, 0.5, 1.2), snow, 0.1, 8)
	# altare con cristallo luminoso
	o.box(t * Transform3D(Basis.IDENTITY, Vector3(0, 1.1, -1.0)), Vector3(2.2, 0.9, 1.4), ice.lerp(snow, 0.3), 0.1, 8)
	o.shard(t * Vector3(0, 1.5, -1.0), t * Vector3(0.1, 3.4, -1.0), 0.45, 0.02, Color(0.6, 0.9, 1.0, 0.15), 0.55, 0.05, 0.0)
	var lp := t * Vector3(0, 2.2, -1.0)
	lamps.append(Vector4(lp.x, 2.2, lp.z, 2.4))
	cols.append(["b", _lw(t, p, yaw, Vector2(0, -1.0)), Vector2(1.2, 0.8), yaw])
	for q in 10:      # ghiaccio e neve
		var a := r.randf() * TAU
		var d := r.randf_range(6.0, 9.0)
		var b := t * Vector3(cos(a) * d, 0, sin(a) * d)
		o.shard(b, b + Vector3(r.randf_range(-0.3, 0.3), r.randf_range(0.8, 2.6), r.randf_range(-0.3, 0.3)), r.randf_range(0.25, 0.5), 0.03, ice.lerp(Color.WHITE, r.randf() * 0.3), 0.5, 0.05, 0.0)


# ------------------------------------------------------------------ accampamento di banditi
static func _camp(o: W3DBuilder, t: Transform3D, p: Vector2, yaw: float, r: RandomNumberGenerator, cols: Array, lamps: Array) -> void:
	for q in 7:
		var a := TAU * q / 7.0
		o.rock(t * Vector3(cos(a) * 1.0, 0.18, sin(a) * 1.0), Vector3(0.45, 0.34, 0.45), STONE, 0.14, 0.4, a)
	for q in 5:
		var a2 := r.randf() * TAU
		o.cyl(t * Transform3D(Basis(Vector3.UP, a2) * Basis(Vector3.FORWARD, r.randf_range(0.5, 1.1)), Vector3(0, 0.2, 0)), 0.1, 0.09, 1.2, 4, Color(0.13, 0.09, 0.07), 0.1)
	o.cyl(t * Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), 0.5, 0.04, 1.2, 5, Color(0.95, 0.62, 0.3, 0.1), 0.2)
	var fp := t * Vector3(0, 1.0, 0)
	lamps.append(Vector4(fp.x, 1.0, fp.z, 2.4))
	cols.append(["c", p, 0.8])
	for q in 4:
		var a3 := TAU * q / 4.0 + 0.6
		var c := Vector2(cos(a3), sin(a3)) * 5.0
		o.cyl(t * Transform3D(Basis(Vector3.UP, -a3 + PI * 0.25), Vector3(c.x, 0, c.y)), 1.8, 0.08, 2.5, 4, Color(0.38, 0.3, 0.2).lerp(Color(0.32, 0.1, 0.09), r.randf() * 0.7), 0.1)
		cols.append(["c", _lw(t, p, yaw, c), 1.3])
		var lc := Vector2(cos(a3 + 0.7), sin(a3 + 0.7)) * 2.4      # tronchi per sedersi
		o.cyl(t * Transform3D(Basis(Vector3(0, 0, 1), PI * 0.5) * Basis(Vector3.UP, a3), Vector3(lc.x + 0.6, 0.3, lc.y)), 0.28, 0.28, 1.2, 6, WOOD_L, 0.1)
	# barricata di pali appuntiti ad arco, con un varco
	for q in 12:
		var a4 := 0.9 + q * 0.34
		if q == 5 or q == 6:
			continue
		var b := t * Vector3(cos(a4) * 8.5, 0, sin(a4) * 8.5)
		o.shard(b, b + Vector3(r.randf_range(-0.1, 0.1), r.randf_range(1.4, 2.0), r.randf_range(-0.1, 0.1)), 0.16, 0.02, WOOD_L, 0.5, 0.05, 0.0)
		cols.append(["c", Vector2(b.x, b.z), 0.3])
	for q in 3:
		o.box(t * Transform3D(Basis(Vector3.UP, r.randf() * TAU), Vector3(-2.0 + q * 0.8, 0.35 + (q % 2) * 0.4, -4.0)), Vector3(0.7, 0.7, 0.7), WOOD_L, 0.1, 8)
	var pole := t * Vector3(3.0, 0, -5.5)
	o.shard(pole, pole + Vector3(0, 3.6, 0), 0.1, 0.07, WOOD_D, 0.6, 0.0, 0.0)
	o.quad(pole + Vector3(0, 3.5, 0), pole + t.basis * Vector3(1.0, 3.4, 0), pole + t.basis * Vector3(1.0, 2.5, 0), pole + Vector3(0, 2.6, 0), Color(0.35, 0.05, 0.06))
	o.rock(pole + Vector3(0, 3.8, 0), Vector3(0.3, 0.3, 0.3), Color(0.72, 0.69, 0.6), 0.08, 0.2, 0.0)
