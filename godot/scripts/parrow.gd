class_name PArrow
extends Node2D
## Proiettile del giocatore: frecce, dardi magici, colpi di bastone.

var main
var vel := Vector2.ZERO
var dmg := 10.0
var life := 0.9
var pierce := 0
var col := Color(1, 1, 1)
var weapon: Dictionary = {}
var aoe := 0.0
var hit: Array = []
var magic := false


func setup(m, dir: Vector2, spd: float, d: float, lf: float, pr: int, c: Color, w: Dictionary, area: float, mg: bool) -> void:
	main = m
	vel = dir * spd
	dmg = d
	life = lf
	pierce = pr
	col = c
	weapon = w
	aoe = area
	magic = mg
	rotation = dir.angle()
	if mg:
		Game.make_light(self, Vector2.ZERO, c, 0.6, 0.8)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	life -= dt
	position += vel * dt
	if life <= 0.0 or main.solid_at(position):
		_end()
		return
	if main.light_break(position, 4.0):
		if aoe > 0.0:
			_explode()
			return
		if pierce <= 0:
			_end()
			return
		pierce -= 1
	for e in main.enemies.duplicate():
		if hit.has(e):
			continue
		if e.position.distance_to(position + Vector2(0, 4)) < e.radius + 4.0:
			hit.append(e)
			_hurt(e)
			if aoe > 0.0:
				_explode()
				return
			if pierce <= 0:
				_end()
				return
			pierce -= 1
	for cr in main.critters.duplicate():
		if cr.position.distance_to(position + Vector2(0, 4)) < 8.0:
			cr.hurt(dmg, vel.normalized(), 70.0, false)
			_end()
			return
	queue_redraw()


func _hurt(e: Enemy) -> void:
	e.hurt(dmg, vel.normalized(), 70.0, false)
	main.player.on_hit(e, dmg, weapon)


func _explode() -> void:
	main.burst(position, col, 16, 60.0, 0.4)
	main.light_break(position, aoe, 4)
	for e in main.enemies.duplicate():
		if not hit.has(e) and e.position.distance_to(position) < aoe + e.radius:
			e.hurt(dmg * 0.7, (e.position - position).normalized(), 90.0, false)
	queue_free()


func _end() -> void:
	main.burst(position, col, 5, 30.0, 0.25)
	queue_free()


func _draw() -> void:
	if magic:
		draw_circle(Vector2.ZERO, 3.0, Color(col.r, col.g, col.b, 0.5))
		draw_circle(Vector2.ZERO, 1.8, Color(1, 1, 1))
	else:
		draw_line(Vector2(-8, 0), Vector2(0, 0), Color(0.55, 0.4, 0.25), 1.0)
		draw_line(Vector2(0, 0), Vector2(3, 0), Color(0.85, 0.85, 0.9), 2.0)
		draw_line(Vector2(-8, -1), Vector2(-6, 0), col, 1.0)
		draw_line(Vector2(-8, 1), Vector2(-6, 0), col, 1.0)
