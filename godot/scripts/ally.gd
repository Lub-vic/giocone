class_name Ally
extends Node2D
## Alleato evocato nella modalita' tattica: segue il giocatore o presidia un punto ordinato.

var main
var hp := 40.0
var max_hp := 40.0
var dmg := 8.0
var speed := 74.0
var radius := 4.0
var mode := "follow"
var rally := Vector2.ZERO
var cd := 0.0
var flash := 0.0
var idx := 0
var count := 1
var t := randf() * 5.0
var spr: Sprite2D
var ttl := -1.0     # > 0: alleato temporaneo (es. drone evocato)


func setup(m) -> void:
	main = m
	var lv: int = m.player.lv
	max_hp = 35.0 + 4.0 * lv
	hp = max_hp
	dmg = 5.0 + m.player.bd() * 0.9
	spr = Sprite2D.new()
	spr.texture = Game.tex("skeleton")
	spr.offset = Vector2(0, -8)
	spr.modulate = Color(0.55, 0.9, 1.5, 0.95)
	add_child(spr)
	Game.make_light(self, Vector2(0, -6), Color(0.5, 0.85, 1.0), 0.8, 0.5)


func heal(frac: float) -> void:
	hp = minf(max_hp, hp + max_hp * frac)
	main.burst(position, Color(0.4, 1.0, 0.6), 6, 25.0, 0.4)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	cd -= dt
	if ttl > 0.0:
		ttl -= dt
		if ttl <= 0.0:
			main.allies.erase(self)
			main.burst(position, Color(0.6, 0.85, 1.0), 16, 50.0, 0.5)
			queue_free()
			return
	flash = maxf(0.0, flash - dt)
	spr.self_modulate = Color(3, 3, 3) if flash > 0.0 else Color.WHITE
	var pl: Player = main.player
	# nemico piu' vicino (sveglio) entro il raggio d'azione
	var target: Enemy = null
	var bd2 := 8100.0
	for e in main.enemies:
		if not e.awake:
			continue
		var d2 := position.distance_squared_to(e.position)
		if d2 < bd2:
			if mode == "rally" and e.position.distance_squared_to(rally) > 14400.0:
				continue
			bd2 = d2
			target = e
	if target != null:
		var to := target.position - position
		spr.flip_h = to.x < 0.0
		if to.length() > target.radius + 8.0:
			main.move_body(self, to.normalized() * speed * dt, radius)
		elif cd <= 0.0:
			cd = 0.7
			target.hurt(dmg, to.normalized(), 90.0, false)
			pl.on_hit(target, dmg, {})
	else:
		var goal := rally if mode == "rally" else pl.position + Vector2.from_angle(TAU * idx / maxf(1.0, count) + t * 0.25) * 30.0
		var gv := goal - position
		if gv.length() > 12.0:
			spr.flip_h = gv.x < 0.0
			main.move_body(self, gv.normalized() * speed * (1.4 if gv.length() > 80.0 else 1.0) * dt, radius)
	spr.offset.y = -8.0 - abs(sin(t * 9.0)) * 0.8
	queue_redraw()


func hurt(d: float) -> void:
	hp -= d
	flash = 0.1
	main.burst(position, Color(0.5, 0.85, 1.0), 5, 30.0, 0.3)
	if hp <= 0.0:
		main.allies.erase(self)
		main.burst(position, Color(0.5, 0.85, 1.0), 14, 50.0, 0.5)
		queue_free()


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		draw_rect(Rect2(-8, -22, 16, 3), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(-7, -21, 14.0 * hp / max_hp, 1), Color(0.4, 0.9, 1.0))
