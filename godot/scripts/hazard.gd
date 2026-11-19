class_name Hazard
extends Node2D
## Zona di pericolo a terra: prima si vede l'avviso che cresce, poi colpisce (una volta o a intervalli).

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
	if t > delay + life:
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
	if t < delay:
		var k := t / delay
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(col.r, col.g, col.b, 0.85), 1.0)
		draw_circle(Vector2.ZERO, radius * k, Color(col.r, col.g, col.b, 0.16 + 0.16 * k))
	else:
		draw_circle(Vector2.ZERO, radius, Color(col.r, col.g, col.b, 0.3 if tick > 0.0 else 0.55))
