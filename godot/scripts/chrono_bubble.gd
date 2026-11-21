class_name ChronoBubble
extends Node2D
## Bolla spazio-temporale: si apre a qualche passo dal giocatore, mostra l'oggetto che c'e' dentro,
## poi si richiude e l'oggetto vola al giocatore, dove fa effetto.
## Passato = oro, le lancette girano all'indietro. Futuro = azzurro, girano in avanti.

const T_OPEN := 0.7
const T_HOLD := 0.6
const T_FLY := 0.5

var main
var res: Dictionary = {}
var col := Color(0.5, 0.85, 1.0)
var fwd := 1.0
var t := 0.0
var radius := 17.0
var spr: Sprite2D
var light: PointLight2D
var done := false


## posizione casuale a 55-105 px dal giocatore, su terreno libero
static func pick_pos(m) -> Vector2:
	var pl: Player = m.player
	for i in 24:
		var p: Vector2 = pl.position + Vector2.from_angle(randf() * TAU) * randf_range(55.0, 105.0)
		if m.free_at(p, 8.0):
			return p
	return pl.position + pl.face * 40.0


static func spawn(m, r: Dictionary, big: bool) -> void:
	var b := ChronoBubble.new()
	b.main = m
	b.res = r
	var f: bool = Chrono.era_of(r) == "f"
	b.fwd = 1.0 if f else -1.0
	b.col = Color(0.5, 0.85, 1.0) if f else Color(1.0, 0.8, 0.4)
	b.radius = 21.0 if big else 17.0
	b.position = pick_pos(m)
	b.z_index = 40
	b.spr = Sprite2D.new()
	b.spr.texture = Game.tex("ch_" + str(r["id"]))
	b.spr.visible = false
	var mx := maxf(b.spr.texture.get_width(), b.spr.texture.get_height())
	b.spr.set_meta("k", (30.0 if big else 22.0) / mx)
	b.add_child(b.spr)
	b.light = Game.make_light(b, Vector2.ZERO, b.col, 0.1, 0.0)
	m.fx.add_child(b)
	m.burst(b.position, b.col, 20, 60.0, 0.5)
	m.snd("level")


func _process(dt: float) -> void:
	if main.state != "play" or main.player == null:
		queue_free()
		return
	t += dt
	var pl: Player = main.player
	var kopen := clampf(t / T_OPEN, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - kopen, 3.0)
	var tf := t - T_OPEN - T_HOLD
	var kfly := clampf(tf / T_FLY, 0.0, 1.0)
	var k := float(spr.get_meta("k"))
	if t > T_OPEN * 0.6:
		spr.visible = true
		var appear := clampf((t - T_OPEN * 0.6) / 0.4, 0.0, 1.0)
		if tf <= 0.0:
			spr.position = Vector2(0, -2.0 + sin(t * 5.0) * 1.5)
			spr.scale = Vector2(k, k) * appear
		else:
			# l'oggetto esce dalla bolla e vola verso il giocatore
			var target := pl.position + Vector2(0, -8) - position
			spr.position = Vector2(0, -2.0).lerp(target, kfly * kfly)
			spr.scale = Vector2(k, k) * (1.0 - 0.5 * kfly)
	light.texture_scale = (0.9 * grow) * (1.0 - kfly)
	light.energy = 1.1 * (1.0 - kfly) * (0.8 + 0.2 * sin(t * 12.0))
	if tf > 0.0 and int(t * 40.0) % 2 == 0:
		main.burst(position + spr.position, col, 1, 20.0, 0.25)
	if tf >= T_FLY and not done:
		done = true
		Chrono.apply(main, res)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var tf := t - T_OPEN - T_HOLD
	var kfly := clampf(tf / T_FLY, 0.0, 1.0)
	var grow := 1.0 - pow(1.0 - clampf(t / T_OPEN, 0.0, 1.0), 3.0)
	var r := radius * grow * (1.0 - 0.85 * kfly * kfly)
	if r < 0.5:
		return
	var a := 1.0 - kfly * 0.6
	# alone e interno: piu' scuro al centro, l'oggetto spicca
	draw_circle(Vector2.ZERO, r * 1.35, Color(col.r, col.g, col.b, 0.10 * a))
	draw_circle(Vector2.ZERO, r * 1.1, Color(col.r, col.g, col.b, 0.16 * a))
	draw_circle(Vector2.ZERO, r, Color(0.04, 0.03, 0.1, 0.78 * a))
	# vortice: bracci a spirale che girano (avanti nel futuro, indietro nel passato)
	for arm in 3:
		var pts := PackedVector2Array()
		for i in 14:
			var u := i / 13.0
			var ang := fwd * (t * 3.2) + arm * TAU / 3.0 + u * 3.2
			pts.append(Vector2.from_angle(ang) * (r * (0.18 + 0.78 * u)))
		draw_polyline(pts, Color(col.r, col.g, col.b, 0.55 * a), 1.0)
	# anelli distorti
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, Color(col.r, col.g, col.b, 0.95 * a), 1.5)
	draw_arc(Vector2.ZERO, r * 0.82, fwd * t * 2.0, fwd * t * 2.0 + 4.2, 20, Color(1, 1, 1, 0.6 * a), 1.0)
	draw_arc(Vector2.ZERO, r * 1.18, -fwd * t * 1.5, -fwd * t * 1.5 + 2.4, 16, Color(col.r, col.g, col.b, 0.5 * a), 1.0)
	# onda d'urto che si allarga a intervalli
	var w := fmod(t * 1.4, 1.0)
	draw_arc(Vector2.ZERO, r * (1.0 + 0.9 * w), 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.5 * (1.0 - w) * a), 1.0)
	# lancette dell'orologio: passato indietro, futuro avanti
	var hand := fwd * t * 4.0 - 1.57
	draw_line(Vector2.ZERO, Vector2.from_angle(hand) * r * 0.95, Color(1, 1, 1, 0.5 * a), 1.0)
	draw_line(Vector2.ZERO, Vector2.from_angle(hand * 0.25) * r * 0.6, Color(col.r, col.g, col.b, 0.6 * a), 1.0)
	for i in 12:
		var ang := i * TAU / 12.0
		var rr := r * 1.05
		draw_line(Vector2.from_angle(ang) * rr, Vector2.from_angle(ang) * (rr + (3.0 if i % 3 == 0 else 1.5)), Color(1, 1, 1, 0.55 * a), 1.0)
	# scintille che orbitano
	for i in 6:
		var ang := fwd * t * 2.4 + i * TAU / 6.0
		var rr := r * (1.15 + 0.2 * sin(t * 3.0 + i))
		draw_circle(Vector2.from_angle(ang) * rr, 1.2, Color(1, 1, 1, 0.8 * a))
