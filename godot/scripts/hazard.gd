class_name Hazard
extends Node2D
## Zona di pericolo a terra: prima si vede l'avviso che cresce, poi colpisce (una volta o a intervalli).
## Grafica in pixel art: le texture si generano una volta (per raggio, colore, fase) e si riusano.

var main
var radius := 30.0
var delay := 0.8
var life := 0.15
var dmg := 10.0
var tick := 0.0
var col := Color(1.0, 0.3, 0.2)
var slow := 0.0
var t := 0.0
var tick_t := 0.0
var fired := false

const BAYER := [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
const OUTL := Color(0.05, 0.02, 0.06, 0.9)
static var _tex := {}


func setup(m, r: float, dl: float, lf: float, d: float, tk: float, c: Color, sl := 0.0) -> void:
	main = m
	radius = r
	delay = dl
	life = lf
	dmg = d
	tick = tk
	col = c
	slow = sl


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	if t < delay:
		queue_redraw()
		return
	if tick <= 0.0:
		if not fired:
			fired = true
			_check()
			main.burst(position, col, 14, 40.0, 0.4)
	else:
		tick_t -= dt
		if tick_t <= 0.0:
			tick_t = tick
			_check()
	if t > delay + life + (0.3 if tick <= 0.0 else 0.0):
		queue_free()
		return
	queue_redraw()


func _check() -> void:
	var p: Player = main.player
	if p.position.distance_to(position) < radius + 3.0:
		if tick > 0.0:
			p.dot(dmg, slow)
		else:
			p.hurt(dmg, (p.position - position).normalized(), slow)


func _draw() -> void:
	var r := int(round(radius))
	if t < delay:
		var k := clampf(t / delay, 0.0, 1.0)
		var blink := 1.0 if k < 0.75 or int(t * 18.0) % 2 == 0 else 0.55   # all'ultimo lampeggia
		_put(tex(r, col, "fill", int(k * 7.0)), Color(1, 1, 1, blink))
		_put(tex(r, col, "ring", int(t * 6.0) % 4), Color(1, 1, 1, blink))
	elif tick > 0.0:
		_put(tex(r, col, "pool", int(t * 4.0) % 3), Color(1, 1, 1, clampf((delay + life - t) * 2.0, 0.0, 1.0)))
	else:
		var f := clampf((t - delay) / (life + 0.3), 0.0, 0.999)
		_put(tex(r, col, "blast", int(f * 6.0)), Color.WHITE)


func _put(tx: Texture2D, mod: Color) -> void:
	draw_texture(tx, -Vector2(tx.get_width(), tx.get_height()) * 0.5, mod)


## texture in pixel art di un'area: ring (bordo con rune, 4 fasi), fill (riempimento a retinatura, 8 livelli),
## blast (onda d'urto con crepe, 6 fotogrammi), pool (pozza che ribolle, 3 fotogrammi), shock (onda del giocatore)
static func tex(r: int, c: Color, kind: String, step: int) -> Texture2D:
	var key := "%s:%d:%s:%d" % [kind, r, c.to_html(false), step]
	if _tex.has(key):
		return _tex[key]
	var R := r + 3
	var n := R * 2 + 1
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var hi := c.lightened(0.45)
	var lo := c.darkened(0.45)
	var rng := RandomNumberGenerator.new()
	rng.seed = r * 131 + step * 7 + kind.hash()
	match kind:
		"ring":
			for y in n:
				for x in n:
					var d := Vector2(x - R, y - R).length()
					if absf(d - r) < 1.0:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.95))
					elif absf(d - (r + 1.4)) < 0.6 or absf(d - (r - 1.4)) < 0.6:
						img.set_pixel(x, y, OUTL)
			# rune: tacche a croce sul bordo, che girano lentamente (4 fasi)
			var nr := maxi(6, r / 5)
			for i in nr:
				var a := TAU * (float(i) + step * 0.25) / nr
				var p := Vector2(R, R) + Vector2.from_angle(a) * (r - 3.0)
				for o in [Vector2.ZERO, Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
					var q: Vector2 = p + o
					if q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
						img.set_pixelv(Vector2i(q), hi if o == Vector2.ZERO else Color(c.r, c.g, c.b, 0.8))
		"fill":
			var fr := r * (step + 1) / 8.0
			var thr := 3 + step       # densita' della retinatura che cresce
			for y in n:
				for x in n:
					var d := Vector2(x - R, y - R).length()
					if d > fr:
						continue
					if d > fr - 1.5:
						img.set_pixel(x, y, Color(hi.r, hi.g, hi.b, 0.85))      # fronte che avanza
					elif int(BAYER[y % 4][x % 4]) < thr:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.28 + 0.04 * step))
		"blast":
			var f := step / 5.0
			var wr := r * (0.55 + 0.55 * f)          # onda che si allarga oltre il bordo
			var wth := 3.0 - 2.0 * f
			for y in n:
				for x in n:
					var d := Vector2(x - R, y - R).length()
					if d > R:
						continue
					if absf(d - wr) < wth:
						img.set_pixel(x, y, hi if absf(d - wr) < wth * 0.45 else c)
					elif d < wr - wth and f < 0.8 and int(BAYER[y % 4][x % 4]) < int(10 - 12 * f):
						img.set_pixel(x, y, Color(lo.r, lo.g, lo.b, 0.55 * (1.0 - f)))
			# crepe radiali nel terreno
			for i in 7:
				var a := TAU * i / 7.0 + rng.randf() * 0.5
				var p := Vector2(R, R)
				var ln := r * (0.4 + 0.5 * rng.randf())
				var s := 0.0
				while s < ln:
					a += rng.randf_range(-0.35, 0.35)
					p += Vector2.from_angle(a) * 1.0
					s += 1.0
					if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
						img.set_pixelv(Vector2i(p), Color(0.06, 0.02, 0.04, 0.85 * (1.0 - f * 0.6)))
			# braci
			for i in int(r * 0.6):
				var p := Vector2(R, R) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * wr
				if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
					img.set_pixelv(Vector2i(p), hi if rng.randf() < 0.5 else Color(1, 1, 0.85))
		"pool":
			for y in n:
				for x in n:
					var d := Vector2(x - R, y - R).length()
					var wob := sin(atan2(y - R, x - R) * 5.0 + step) * 1.5
					if d > r + wob:
						continue
					if d > r + wob - 1.5:
						img.set_pixel(x, y, Color(lo.r, lo.g, lo.b, 0.9))
					elif int(BAYER[y % 4][x % 4]) < 7:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.42))
			for i in maxi(3, r / 4):     # bolle
				var p := Vector2(R, R) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * (r - 3)
				var br := 1 + rng.randi() % 2
				for oy in range(-br, br + 1):
					for ox in range(-br, br + 1):
						var q := Vector2i(p) + Vector2i(ox, oy)
						if ox * ox + oy * oy <= br * br and q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
							img.set_pixelv(q, hi if ox < 0 and oy < 0 else Color(c.r, c.g, c.b, 0.85))
		"shock":
			var f2 := step / 5.0
			var wr2 := r * (0.25 + 0.75 * f2)
			for y in n:
				for x in n:
					var d := Vector2(x - R, y - R).length()
					if absf(d - wr2) < 2.2 - f2:
						img.set_pixel(x, y, hi if absf(d - wr2) < 0.9 else Color(c.r, c.g, c.b, 0.9 - 0.5 * f2))
					elif absf(d - wr2 + 3.0) < 1.0 and int(BAYER[y % 4][x % 4]) < 8:
						img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.5 * (1.0 - f2)))
			for i in int(r * 0.5):
				var p := Vector2(R, R) + Vector2.from_angle(rng.randf() * TAU) * (wr2 + rng.randf_range(-3, 3))
				if p.x >= 0 and p.y >= 0 and p.x < n and p.y < n:
					img.set_pixelv(Vector2i(p), Color(1, 1, 0.9))
	var tx := ImageTexture.create_from_image(img)
	_tex[key] = tx
	return tx


## onda d'urto solo visiva (incantesimi del giocatore): 6 fotogrammi pixel art in ~0.35 s
class Shock extends Node2D:
	var r := 58
	var c := Color.WHITE
	var tt := 0.0
	func _process(dt: float) -> void:
		tt += dt
		if tt >= 0.36:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var tx: Texture2D = Hazard.tex(r, c, "shock", mini(5, int(tt / 0.06)))
		draw_texture(tx, -Vector2(tx.get_width(), tx.get_height()) * 0.5)
