class_name Critter
extends Node2D
## Fauna del mondo: animali che pascolano, saltellano, fuggono quando ti avvicini e si possono cacciare.

const KINDS := {
	"deer": {"spr": "deer", "hp": 14.0, "spd": 26.0, "flee": 85.0, "fspd": 95.0, "souls": 8, "mode": "walk", "night": false, "scale": 1.0},
	"rabbit": {"spr": "rabbit", "hp": 4.0, "spd": 20.0, "flee": 60.0, "fspd": 115.0, "souls": 3, "mode": "hop", "night": false, "scale": 1.0},
	"bird": {"spr": "crow", "hp": 3.0, "spd": 14.0, "flee": 55.0, "fspd": 0.0, "souls": 2, "mode": "bird", "night": false, "scale": 0.8},
	"frog": {"spr": "toad", "hp": 3.0, "spd": 18.0, "flee": 38.0, "fspd": 80.0, "souls": 2, "mode": "hop", "night": true, "scale": 0.55},
	"fox": {"spr": "wolf", "hp": 12.0, "spd": 30.0, "flee": 90.0, "fspd": 105.0, "souls": 7, "mode": "walk", "night": true, "scale": 0.8},
	"rat": {"spr": "rat", "hp": 3.0, "spd": 24.0, "flee": 45.0, "fspd": 100.0, "souls": 1, "mode": "walk", "night": true, "scale": 1.0},
}

var main
var kind := ""
var d: Dictionary = {}
var home := Vector2.ZERO
var hp := 5.0
var state := "idle"
var st_t := 1.0
var goal := Vector2.ZERO
var vel := Vector2.ZERO
var t := randf() * 10.0
var spr: Sprite2D
var air := 0.0
var gone_t := 0.0
var flash := 0.0
var radius := 3.0


func setup(m, k: String, pos: Vector2, tint := Color.WHITE) -> void:
	main = m
	kind = k
	d = KINDS[k]
	home = pos
	position = pos
	hp = float(d["hp"])
	spr = Sprite2D.new()
	spr.texture = Game.tex(str(d["spr"]))
	spr.offset = Vector2(0, -6)
	spr.scale = Vector2.ONE * float(d["scale"])
	spr.modulate = tint
	add_child(spr)
	st_t = randf_range(0.5, 4.0)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	flash = maxf(0.0, flash - dt)
	var pl: Vector2 = main.player.position
	var dist := position.distance_to(pl)
	var asleep: bool = main.day_light() < 0.25 and not bool(d["night"])
	if asleep:
		visible = false
		return
	if gone_t > 0.0:
		gone_t -= dt
		if gone_t <= 0.0:
			position = home
			air = 0.0
			state = "idle"
			visible = true
			spr.modulate.a = 1.0
		return
	visible = true
	spr.position.x = randf_range(-0.6, 0.6) if flash > 0.0 else 0.0
	var mode: String = str(d["mode"])
	if mode == "bird":
		_bird(dt, dist, pl)
		return
	if state != "flee" and dist < float(d["flee"]):
		state = "flee"
		st_t = 2.2
	match state:
		"idle":
			vel = Vector2.ZERO
			spr.offset.y = -6.0 + sin(t * 1.5) * 0.4
			st_t -= dt
			if st_t <= 0.0:
				goal = home + Vector2.from_angle(randf() * TAU) * randf_range(8.0, 44.0)
				state = "wander"
				st_t = randf_range(1.2, 3.0)
		"wander":
			st_t -= dt
			var to := goal - position
			if to.length() < 3.0 or st_t <= 0.0:
				state = "idle"
				st_t = randf_range(1.5, 5.0)
			else:
				var s: float = float(d["spd"]) * (1.0 if mode == "walk" else 1.0)
				vel = to.normalized() * s
				if mode == "hop":
					vel *= maxf(0.0, sin(t * 7.0)) * 1.8
					spr.offset.y = -6.0 - maxf(0.0, sin(t * 7.0)) * 3.0
				spr.flip_h = vel.x < 0.0
				main.move_body(self, vel * dt, radius)
		"flee":
			st_t -= dt
			var away := (position - pl).normalized()
			vel = away * float(d["fspd"])
			if mode == "hop":
				vel *= maxf(0.25, sin(t * 11.0) * 0.5 + 0.7)
				spr.offset.y = -6.0 - maxf(0.0, sin(t * 11.0)) * 4.0
			spr.flip_h = vel.x < 0.0
			main.move_body(self, vel * dt, radius)
			if st_t <= 0.0 and dist > float(d["flee"]) * 1.6:
				state = "idle"
				st_t = randf_range(1.0, 3.0)
				home = position
	if position.distance_squared_to(home) > 160000.0:
		position = home


func _bird(dt: float, dist: float, pl: Vector2) -> void:
	if state == "flee":
		air += 70.0 * dt
		spr.offset.y = -6.0 - air
		position += Vector2(vel.x, 0.0) * dt
		spr.modulate.a = clampf(1.0 - air / 90.0, 0.0, 1.0)
		spr.position.x = sin(t * 18.0) * 1.2
		if air > 90.0:
			gone_t = randf_range(22.0, 40.0)
			visible = false
		return
	spr.offset.y = -6.0 + sin(t * 2.0) * 0.3
	if dist < float(d["flee"]):
		state = "flee"
		vel = (position - pl).normalized() * 55.0
		main.snd("page")
		return
	st_t -= dt
	if st_t <= 0.0:
		st_t = randf_range(1.5, 4.0)
		spr.flip_h = randf() < 0.5
		position += Vector2.from_angle(randf() * TAU) * 3.0


func hurt(dm: float, dir: Vector2, force: float, _heavy := false) -> void:
	hp -= dm
	flash = 0.12
	main.burst(position, Color(0.75, 0.15, 0.3), 5, 40.0, 0.3)
	if str(d["mode"]) != "bird":
		state = "flee"
		st_t = 2.5
		main.move_body(self, dir * force * 0.1, radius)
	if hp <= 0.0:
		main.critter_died(self)
