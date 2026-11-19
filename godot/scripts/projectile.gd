class_name Projectile
extends Node2D

var main
var vel := Vector2.ZERO
var dmg := 1.0
var slow := 0.0
var life := 3.5
var t := 0.0


func setup(m, dir: Vector2, spd: float, d: float, sl := 0.0) -> void:
	slow = sl
	main = m
	vel = dir * spd
	dmg = d * 0.75
	Game.make_light(self, Vector2.ZERO, Color(1.0, 0.35, 0.2), 0.45, 0.8)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	life -= dt
	position += vel * dt
	if life <= 0.0 or main.solid_at(position):
		main.burst(position, Color(1, 0.5, 0.2), 4, 30.0, 0.25)
		queue_free()
		return
	if position.distance_to(main.player.position + Vector2(0, -4)) < 6.0:
		main.player.hurt(dmg, vel.normalized(), slow)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(0.6, 0.1, 0.15))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.45, 0.15))
	draw_circle(Vector2.ZERO, 1.0, Color(1.0, 0.95, 0.6))
