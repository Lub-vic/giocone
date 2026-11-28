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
# volo in 3D (prima persona): quota assoluta in unita' del mondo 3D e velocita' verticale
var aimed3d := false
var alt := 0.0
var valt := 0.0
var pitch := 0.0
var height := 1.0          # altezza sul terreno nel punto in cui si trova


## lanciato in prima persona: parte dalla punta dell'arma e va verso il punto del mirino; "spread" e' la
## deviazione di lato che il colpo aveva nel piano (rosa del fucile, raffiche)
func aim3d(skin, muzzle: Vector3, target: Vector3, spread: float) -> void:
	aimed3d = true
	var speed := vel.length()
	var dir := (target - muzzle).normalized().rotated(Vector3.UP, -spread)
	pitch = asin(clampf(dir.y, -1.0, 1.0))
	vel = Vector2(dir.x, dir.z) * speed
	valt = speed * dir.y / 16.0
	rotation = vel.angle()
	position = Vector2(muzzle.x, muzzle.z) * 16.0
	alt = muzzle.y
	height = alt - float(skin.elev_at(muzzle.x, muzzle.z))


## il colpo attraversa qualcosa alto "top" unita'? (nella vista dall'alto conta solo la pianta)
func at_height(top: float) -> bool:
	return not aimed3d or (height > -0.25 and height < top + 0.35)



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
	if aimed3d:
		alt += valt * dt
		var q := position / 16.0
		height = alt - float((main.skin as W3DSkin).elev_at(q.x, q.y))
		if height <= 0.05:        # finito a terra
			height = 0.05
			if aoe > 0.0:
				_explode()
			else:
				_end()
			return
	if life <= 0.0 or (at_height(4.2) and main.solid_at(position)):      # sopra i tetti si passa
		_end()
		return
	if at_height(2.0) and main.light_break(position, 4.0):
		if aoe > 0.0:
			_explode()
			return
		if pierce <= 0:
			_end()
			return
		pierce -= 1
	for e in main.enemies.duplicate():
		if hit.has(e) or not at_height((3.8 if e.is_boss else 2.0) * maxf(e.scl, 1.0)):
			continue
		if e.position.distance_to(position + _body_offset()) < e.radius + 4.0:
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
		if at_height(1.2) and cr.position.distance_to(position + _body_offset()) < 8.0:
			cr.hurt(dmg, vel.normalized(), 70.0, false)
			_end()
			return
	queue_redraw()


## dall'alto il colpo e' disegnato un po' sopra i piedi; in 3D la posizione e' quella vera
func _body_offset() -> Vector2:
	return Vector2.ZERO if aimed3d else Vector2(0, 4)


func _hurt(e: Enemy) -> void:
	e.hurt(dmg, vel.normalized(), 70.0, false)
	main.player.on_hit(e, dmg, weapon)


func _explode() -> void:
	main.burst(position, col, 16, 60.0, 0.4)
	if aimed3d and height > aoe / 16.0 + 2.0:      # scoppio alto in aria: a terra non arriva
		queue_free()
		return
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
