class_name Projectile
extends Node2D
## Proiettile dei nemici. Lo stile dipende da chi lo lancia: frecce, coltelli, sfere d'ombra, schegge di gelo...

var main
var vel := Vector2.ZERO
var dmg := 1.0
var slow := 0.0
var life := 3.5
var t := 0.0
var style := "fire"
var spin := 0.0

const LIGHT := {"fire": Color(1.0, 0.35, 0.2), "arrow": Color(0.9, 0.8, 0.5), "knife": Color(0.8, 0.85, 0.95), "dark": Color(0.6, 0.25, 0.9),
	"ice": Color(0.6, 0.9, 1.0), "poison": Color(0.45, 0.9, 0.3), "web": Color(0.9, 0.9, 0.95), "soul": Color(0.5, 0.95, 1.0), "blood": Color(0.8, 0.1, 0.15),
	"bazooka_rocket": Color(1.0, 0.5, 0.15), "shotgun_pellet": Color(1.0, 0.85, 0.6), "plasma_bolt": Color(0.3, 0.7, 1.0)}


func setup(m, dir: Vector2, spd: float, d: float, sl := 0.0, st := "fire") -> void:
	slow = sl
	main = m
	vel = dir * spd
	dmg = d * 0.75
	style = st if LIGHT.has(st) else "fire"
	rotation = dir.angle()
	Game.make_light(self, Vector2.ZERO, LIGHT[style], 0.45, 0.8 if style in ["fire", "dark", "ice", "poison", "soul", "blood"] else 0.3)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	life -= dt
	position += vel * dt
	if style == "knife":
		spin += dt * 18.0
	if life <= 0.0 or main.solid_at(position):
		main.burst(position, LIGHT[style], 4, 30.0, 0.25)
		queue_free()
		return
	if position.distance_to(main.player.position + Vector2(0, -4)) < 6.0:
		main.player.hurt(dmg, vel.normalized(), slow)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	match style:
		"arrow":
			draw_line(Vector2(-8, 0), Vector2(1, 0), Color(0.5, 0.36, 0.22), 1.0)
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(1, -1.6), Vector2(1, 1.6)]), Color(0.85, 0.87, 0.92))
			draw_line(Vector2(-8, -1.5), Vector2(-6, 0), Color(0.9, 0.85, 0.75), 1.0)
			draw_line(Vector2(-8, 1.5), Vector2(-6, 0), Color(0.9, 0.85, 0.75), 1.0)
		"knife":
			draw_set_transform(Vector2.ZERO, spin - rotation, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(5, 0), Vector2(0, -1.8), Vector2(-1, 0), Vector2(0, 1.8)]), Color(0.78, 0.82, 0.9))
			draw_line(Vector2(-1, 0), Vector2(-5, 0), Color(0.45, 0.3, 0.18), 2.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"dark":
			for i in 3:
				draw_circle(Vector2(-3.0 - i * 3.0, sin(t * 14.0 + i) * 1.2), 2.4 - i * 0.6, Color(0.4, 0.1, 0.6, 0.45 - i * 0.12))
			draw_circle(Vector2.ZERO, 3.6, Color(0.5, 0.2, 0.8, 0.8))
			draw_circle(Vector2.ZERO, 2.4, Color(0.08, 0.03, 0.14))
			draw_arc(Vector2.ZERO, 3.2, t * 10.0, t * 10.0 + 3.6, 8, Color(0.85, 0.6, 1.0), 1.0)
		"ice":
			draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(0, -2.6), Vector2(-4, 0), Vector2(0, 2.6)]), Color(0.55, 0.82, 1.0))
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(0, -1.2), Vector2(-2, 0), Vector2(0, 1.2)]), Color(0.92, 0.98, 1.0))
		"poison":
			draw_circle(Vector2(-4, 1), 1.4, Color(0.3, 0.7, 0.2, 0.6))
			draw_circle(Vector2(-6, -1), 1.0, Color(0.3, 0.7, 0.2, 0.4))
			draw_circle(Vector2.ZERO, 3.2, Color(0.28, 0.65, 0.2))
			draw_circle(Vector2(-0.8, -0.8), 1.2, Color(0.7, 1.0, 0.5))
		"web":
			draw_circle(Vector2.ZERO, 3.2, Color(0.85, 0.85, 0.9, 0.85))
			draw_line(Vector2(-3, 0), Vector2(3, 0), Color(0.45, 0.45, 0.5), 1.0)
			draw_line(Vector2(0, -3), Vector2(0, 3), Color(0.45, 0.45, 0.5), 1.0)
			draw_line(Vector2(-2, -2), Vector2(2, 2), Color(0.45, 0.45, 0.5), 1.0)
			draw_line(Vector2(-2, 2), Vector2(2, -2), Color(0.45, 0.45, 0.5), 1.0)
		"soul":
			for i in 4:
				draw_circle(Vector2(-2.0 - i * 2.5, sin(t * 12.0 + i * 1.5) * 1.5), 2.6 - i * 0.55, Color(0.5, 0.9, 1.0, 0.55 - i * 0.12))
			draw_circle(Vector2.ZERO, 2.6, Color(0.85, 1.0, 1.0))
		"blood":
			draw_colored_polygon(PackedVector2Array([Vector2(5, 0), Vector2(0, -2.8), Vector2(-3, 0), Vector2(0, 2.8)]), Color(0.55, 0.05, 0.1))
			draw_circle(Vector2(0, 0), 1.4, Color(0.95, 0.3, 0.3))
		"bazooka_rocket":
			# Razzo con scia
			draw_colored_polygon(PackedVector2Array([Vector2(8, 0), Vector2(0, -3), Vector2(-6, 0), Vector2(0, 3)]), Color(0.4, 0.25, 0.15))
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(0, -1.5), Vector2(-2, 0), Vector2(0, 1.5)]), Color(1.0, 0.6, 0.1))
			# Scia
			for i in 5:
				draw_circle(Vector2(-4 - i * 3, sin(t * 20.0 + i) * 0.8), 2.0 - i * 0.3, Color(1.0, 0.5, 0.1, 0.6 - i * 0.1))
		"shotgun_pellet":
			# Pallino shotgun
			draw_circle(Vector2.ZERO, 2.5, Color(1.0, 0.85, 0.6))
			draw_circle(Vector2.ZERO, 1.5, Color(1.0, 0.95, 0.8))
		"plasma_bolt":
			# Bolt al plasma
			draw_colored_polygon(PackedVector2Array([Vector2(6, 0), Vector2(0, -3), Vector2(-4, 0), Vector2(0, 3)]), Color(0.4, 0.7, 1.0))
			draw_colored_polygon(PackedVector2Array([Vector2(4, 0), Vector2(0, -1.5), Vector2(-2, 0), Vector2(0, 1.5)]), Color(0.8, 0.95, 1.0))
			draw_circle(Vector2(1, 0), 0.8, Color(1.0, 1.0, 1.0, 0.8))
			for i in 3:
				draw_circle(Vector2(-2 - i * 2, sin(t * 15.0 + i) * 1.0), 1.5 - i * 0.4, Color(0.3, 0.7, 1.0, 0.5 - i * 0.15))
		_:
			draw_circle(Vector2.ZERO, 3.0, Color(0.6, 0.1, 0.15))
			draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.45, 0.15))
			draw_circle(Vector2.ZERO, 1.0, Color(1.0, 0.95, 0.6))
