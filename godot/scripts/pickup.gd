class_name Pickup
extends Node2D

var main
var kind := "coin"
var value := 1
var vel := Vector2.ZERO
var age := 0.0
var spr: Sprite2D


func setup(m, k: String, v: int) -> void:
	main = m
	kind = k
	value = v
	vel = Vector2.from_angle(randf() * TAU) * randf_range(20.0, 55.0)
	spr = Sprite2D.new()
	spr.texture = Game.tex(k)
	add_child(spr)
	if k == "soul":
		Game.make_light(self, Vector2.ZERO, Color(0.35, 1.0, 0.7), 0.5, 0.7)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	age += dt
	var p: Player = main.player
	var d := p.position.distance_to(position)
	if age > 0.35 and d < 48.0:
		position += (p.position - position).normalized() * 150.0 * dt
	else:
		main.move_body(self, vel * dt, 2.0)
		vel *= pow(0.02, dt)
	spr.position.y = -4.0 + sin(age * 6.0) * 1.5
	if d < 8.0 and age > 0.2:
		p.add_souls(value)
		main.snd("soul")
		queue_free()
