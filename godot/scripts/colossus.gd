class_name Colossus
extends Node2D
## Boss colossale "Il Campanaro", animato a POSE disegnate (nessun pezzo stirato o ruotato):
## ogni attacco e' una sequenza carica -> colpo -> mano a terra, su zone fisse davanti a lui.
## A codice solo i piccoli movimenti (respiro, sollevamento, scossone), le catene fisiche (Verlet),
## i lucchetti, le onde del rintocco. Le parti colpibili sono Enemy invisibili che passano il danno qui.

const ANCHOR := Vector2(136.9, 170.2)        # base del corpo dentro i fotogrammi 274x273
# polsi (dove si aggancia la catena) per ogni posa: [sinistro, destro]
const WRISTS := {
	"rest": [Vector2(-63, 14), Vector2(63, 14)],
	"raise_l": [Vector2(-115, -76), Vector2(63, 14)],
	"slam_l": [Vector2(-82, 12), Vector2(63, 14)],
	"toll": [Vector2(-63, 14), Vector2(93, -80)],
	"slam_r": [Vector2(-63, 14), Vector2(85, 10)],
	"slam_c": [Vector2(-45, 10), Vector2(44, 10)],
}
const ZONES := {"l": [Vector2(-82, 26), 28.0], "r": [Vector2(85, 26), 28.0], "c": [Vector2(0, 30), 34.0]}
const SHOULDER := [Vector2(-50, -96), Vector2(50, -96)]
const HEAD_UP := Vector2(0, -88)
const HEAD_DOWN := Vector2(0, -60)
const LINK := 5.0
const GRAV := Vector2(0, 90.0)

var main
var spr: Sprite2D
var pose := "rest"
var head: Enemy
var hand_parts: Array = []
var locks: Array = []          # {"pos", "part", "alive", "chain"}
var chains: Array = []
var floor_fx: Node2D
var top_fx: Node2D
var phase := 1
var state := "sleep"
var st_t := 0.0
var cd := 2.5
var side := "l"                # zona dell'attacco in corso
var combo := 0
var head_open := 0.0
var bow := 0.0
var bob := 0.0                 # piccolo sollevamento del corpo (carica / impatto)
var t := 0.0
var rings: Array = []
var dead := false


class Drawer extends Node2D:
	var f: Callable
	func _draw() -> void:
		f.call(self)


func setup(m, lock_pos: Array) -> void:
	main = m
	y_sort_enabled = true
	spr = Sprite2D.new()
	spr.centered = false
	spr.offset = -ANCHOR
	add_child(spr)
	_set_pose("rest")
	floor_fx = Drawer.new()
	floor_fx.f = _draw_floor
	floor_fx.z_index = -1
	add_child(floor_fx)
	top_fx = Drawer.new()
	top_fx.f = _draw_top
	top_fx.z_index = 2
	add_child(top_fx)
	head = main.spawn_enemy("boss_campanaro", position + HEAD_UP, 1.0, false, Color.WHITE)
	head.col = self
	head.spr.visible = false
	for i in 2:
		var hp_: Enemy = main.spawn_enemy("camp_part", position + _wrist(i) + Vector2(0, 10), 1.0, false, Color.WHITE)
		hp_.col = self
		hp_.radius = 13.0
		hp_.spr.visible = false
		hp_.is_boss = true
		hand_parts.append(hp_)
	for i in mini(4, lock_pos.size()):
		var lp: Vector2 = to_local(lock_pos[i])
		var part: Enemy = main.spawn_enemy("camp_part", lock_pos[i], 1.0, false, Color.WHITE)
		part.col = self
		part.radius = 7.0
		part.hp = head.max_hp * 0.07
		part.max_hp = part.hp
		part.spr.visible = false
		part.is_boss = true
		locks.append({"pos": lp, "part": part, "alive": true, "chain": i})
		_make_chain(_anchor_a(i), lp, 1.15)


func _set_pose(p: String) -> void:
	pose = p
	spr.texture = Game.tex("camp_" + p)


func _wrist(i: int) -> Vector2:
	return (WRISTS[pose] as Array)[i]


func _make_chain(a: Vector2, b: Vector2, slack: float) -> void:
	var dist := a.distance_to(b)
	var n := maxi(3, int(dist * slack / LINK))
	var pts := PackedVector2Array()
	for k in n + 1:
		pts.append(a.lerp(b, float(k) / n) + Vector2(0, sin(PI * k / n) * 6.0))
	chains.append({"pts": pts, "old": pts.duplicate(), "len": dist * slack, "free_end": false, "stub": false})


func _anchor_a(i: int) -> Vector2:
	var y := -bob + bow * 0.4
	if i < 2:
		return _wrist(i) + Vector2(0, y)
	return SHOULDER[i - 2] + Vector2(0, y)


func _sim_chain(c: Dictionary, a: Vector2, b: Vector2, dt: float) -> void:
	var pts: PackedVector2Array = c["pts"]
	var old: PackedVector2Array = c["old"]
	var n := pts.size()
	var g := GRAV * dt * dt
	for k in n:
		var p := pts[k]
		var v := (p - old[k]) * 0.95
		old[k] = p
		pts[k] = p + v + g
	var seg := float(c["len"]) / (n - 1)
	var fixed_end: bool = not c["free_end"]
	for it in 8:
		pts[0] = a
		if fixed_end:
			pts[n - 1] = b
		for k in n - 1:
			var d := pts[k + 1] - pts[k]
			var l := d.length()
			if l < 0.001:
				continue
			var diff := (l - seg) / l * 0.5
			if k == 0:
				pts[k + 1] -= d * diff * 2.0
			elif k + 1 == n - 1 and fixed_end:
				pts[k] += d * diff * 2.0
			else:
				pts[k] += d * diff
				pts[k + 1] -= d * diff
	pts[0] = a
	if fixed_end:
		pts[n - 1] = b
	c["pts"] = pts
	c["old"] = old


func _process(dt: float) -> void:
	if main.state != "play" or dead:
		return
	t += dt
	var p: Node2D = main.player
	var pl := to_local(p.position)
	if state == "sleep":
		if pl.length() < 190.0:
			state = "idle"
			head.awake = true
			main.beast_note("boss_campanaro")
			main.say("IL CAMPANARO SI DESTA")
			main.snd("roar")
			main.shake(8.0)
		_visual(dt)
		return
	if not is_instance_valid(head) or head.dying:
		_die()
		return
	_push_player(p)
	head_open = maxf(0.0, head_open - dt)
	bow = move_toward(bow, 14.0 if head_open > 0.0 else 0.0, dt * 45.0)
	cd -= dt
	st_t += dt
	var spd := 1.0 if phase == 1 else 1.35
	match state:
		"idle":
			bob = move_toward(bob, sin(t * 1.6) * 1.0, dt * 20.0)     # respiro
			if cd <= 0.0 and head_open <= 0.0:
				_choose(pl)
		"raise":         # carica: posa con la mano alta, il corpo si solleva appena
			bob = move_toward(bob, 4.0, dt * 16.0)
			if st_t > 0.8 / spd:
				_set_pose({"l": "slam_l", "r": "slam_r", "c": "slam_c"}[side])
				bob = -3.0                       # scossone dell'impatto
				var z: Array = ZONES[side]
				main.shake(10.0 if side == "c" else 8.0)
				main.snd("slam")
				main.burst(to_global(z[0]), Color(0.55, 0.5, 0.6), 26, 80.0, 0.6)
				_go("down")
		"down":          # la mano resta a terra: e' il momento di colpirla
			bob = move_toward(bob, 0.0, dt * 20.0)
			if st_t > (1.2 if phase == 1 else 0.7):
				if combo > 0:
					combo -= 1
					_start_slam(["l", "r", "c"][randi() % 3])
				else:
					_set_pose("rest")
					if randf() < (0.5 if phase == 1 else 0.65):
						head_open = 2.2
						main.popup(to_global(HEAD_DOWN + Vector2(0, -12)), "IL VOLTO!", Color(1.0, 0.8, 0.4))
					_go("idle")
					cd = randf_range(1.1, 1.9) / spd
		"toll_tel":      # il batacchio si alza: sta per suonare
			bob = move_toward(bob, 3.0, dt * 12.0)
			if st_t > 0.85 / spd:
				_set_pose("rest")
				bob = -2.0
				rings.append([10.0, 125.0 * spd, false])
				if phase == 2:
					rings.append([-60.0, 125.0 * spd, false])
				main.snd("slam")
				main.shake(6.0)
				_go("toll")
		"toll":
			bob = move_toward(bob, 0.0, dt * 20.0)
			if st_t > 0.6:
				_go("idle")
				cd = 1.5 / spd
	for r in rings:
		r[0] += float(r[1]) * dt
		var o := Vector2(0, -30)
		var dd := Vector2(pl.x - o.x, (pl.y - o.y) / 0.62).length()
		if not r[2] and r[0] > 0.0 and absf(dd - float(r[0])) < 7.0:
			r[2] = true
			p.hurt(head.dmg * 0.8, (pl - o).normalized())
	rings = rings.filter(func(r): return float(r[0]) < 320.0)
	_visual(dt)


func _go(s: String) -> void:
	state = s
	st_t = 0.0


func _choose(pl: Vector2) -> void:
	var near := pl.length() < 150.0
	if near and randf() < 0.75:
		var s := "c"
		if pl.x < -40.0:
			s = "l"
		elif pl.x > 40.0:
			s = "r"
		combo = (1 + randi() % 2) if phase == 2 else 0
		_start_slam(s)
	else:
		_set_pose("toll")
		_go("toll_tel")
	if phase == 2 and randf() < 0.25:
		for k in 2:
			var b: Enemy = main.spawn_enemy("bat", to_global(Vector2(randf_range(-60, 60), -110)), 1.6, false, Color.WHITE)
			b.awake = true
			b.set_process(true)


func _start_slam(s: String) -> void:
	side = s
	_set_pose({"l": "raise_l", "r": "toll", "c": "rest"}[s])
	_go("raise")
	var z: Array = ZONES[s]
	var hz := Hazard.new()
	hz.setup(main, float(z[1]), 0.8 / (1.0 if phase == 1 else 1.35), 0.12, head.dmg * (1.25 if s == "c" else 1.1), 0.0, Color(1.0, 0.25, 0.2))
	hz.position = to_global(z[0])
	main.fx.add_child(hz)


func _push_player(p: Node2D) -> void:
	var c := Vector2(0, -60)
	var pl := to_local(p.position) - c
	var e := Vector2(pl.x / 72.0, pl.y / 54.0)
	if e.length() < 1.0:
		p.position = to_global(c + pl / maxf(e.length(), 0.05))


func _visual(dt: float) -> void:
	spr.position = Vector2(0, -bob + bow * 0.7)
	spr.scale = Vector2(1.0, 1.0 - bow * 0.004)
	for i in 2:
		if is_instance_valid(hand_parts[i]):
			var hp_pos := _wrist(i) + Vector2(0, 10)
			if state == "down" and ((side == "l" and i == 0) or (side == "r" and i == 1) or side == "c"):
				hp_pos = (ZONES[side] as Array)[0] + Vector2((i - 0.5) * 30.0 if side == "c" else 0.0, -6)
			hand_parts[i].position = to_global(hp_pos)
	if is_instance_valid(head):
		head.position = to_global(HEAD_UP.lerp(HEAD_DOWN, bow / 14.0))
	for i in chains.size():
		var c: Dictionary = chains[i]
		if c["stub"]:
			_sim_chain(c, c["anchor"], Vector2.ZERO, dt)
		else:
			_sim_chain(c, _anchor_a(i), locks[i]["pos"], dt)
	floor_fx.queue_redraw()
	top_fx.queue_redraw()


## danno a una parte: la testa prende il colpo pieno solo quando il volto e' scoperto
func part_hurt(e: Enemy, d: float) -> float:
	if e == head:
		if state == "sleep":
			return 0.0
		if head_open > 0.0:
			return d * 1.35
		main.popup(e.position + Vector2(0, -10), "PARATO", Color(0.7, 0.7, 0.8))
		return d * 0.15
	var hi := hand_parts.find(e)
	if hi >= 0:
		var grounded := state == "idle" or state == "down" or state == "toll"
		if not grounded or not is_instance_valid(head):
			return 0.0
		var dd := d * (0.6 if state == "down" else 0.3)
		head.hp -= dd
		head.flash = 0.1
		main.snd("hit")
		main.popup(e.position + Vector2(0, -12), str(int(round(dd))), Color(1, 1, 1))
		main.burst(e.position, Color(0.6, 0.55, 0.7), 5, 40.0, 0.3)
		if head.hp <= 0.0 and not head.dying:
			head.dying = true
			main.enemy_died(head)
		return 0.0
	for li in locks.size():
		var L: Dictionary = locks[li]
		if L["part"] == e and L["alive"]:
			e.hp -= d
			main.snd("hit")
			main.burst(e.position, Color(1.0, 0.6, 0.25), 6, 50.0, 0.3)
			main.popup(e.position + Vector2(0, -10), str(int(round(d))), Color(1.0, 0.75, 0.4))
			if e.hp <= 0.0:
				_break_lock(li)
			return 0.0
	return 0.0


func _break_lock(li: int) -> void:
	var L: Dictionary = locks[li]
	L["alive"] = false
	var e: Enemy = L["part"]
	main.enemies.erase(e)
	e.queue_free()
	var c: Dictionary = chains[L["chain"]]
	c["free_end"] = true
	c["len"] = float(c["len"]) * 0.5
	var pts: PackedVector2Array = c["pts"]
	var keep := maxi(3, int(pts.size() * 0.5))
	pts.resize(keep)
	var old: PackedVector2Array = c["old"]
	old.resize(keep)
	for k in keep:
		old[k] = pts[k] + Vector2(randf_range(-3, 3), -2.0)   # strattone
	c["pts"] = pts
	c["old"] = old
	var stub := PackedVector2Array()
	for k in 4:
		stub.append(L["pos"] + Vector2(0, k * LINK))
	chains.append({"pts": stub, "old": stub.duplicate(), "len": LINK * 3, "free_end": true, "stub": true, "anchor": L["pos"]})
	main.shake(10.0)
	main.hitstop(0.1)
	main.snd("slam")
	main.burst(to_global(L["pos"]), Color(1.0, 0.7, 0.3), 26, 90.0, 0.5)
	var left := 0
	for l2 in locks:
		if l2["alive"]:
			left += 1
	if left == 0:
		phase = 2
		main.say("IL CAMPANARO SI LIBERA!")
		main.snd("roar")
		main.shake(14.0)
		cd = 1.0
	else:
		main.say("CATENA SPEZZATA  (%d RIMASTE)" % left)


func _die() -> void:
	dead = true
	for e in hand_parts:
		if is_instance_valid(e):
			main.enemies.erase(e)
			e.queue_free()
	for L in locks:
		if L["alive"] and is_instance_valid(L["part"]):
			main.enemies.erase(L["part"])
			L["part"].queue_free()
	_set_pose("rest")
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 2.5)
	tw.tween_callback(queue_free)
	for k in 6:
		main.burst(to_global(Vector2(randf_range(-60, 60), randf_range(-110, 0))), Color(0.6, 0.4, 0.8), 20, 80.0, 0.9)


# ------------------------------------------------------------------ disegno
func _draw_floor(n: Node2D) -> void:
	n.draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.35))
	n.draw_circle(Vector2.ZERO, 84.0, Color(0, 0, 0, 0.4))
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for c in chains:
		_draw_chain(n, c)
	for L in locks:
		var lp: Vector2 = L["pos"]
		if L["alive"]:
			var glow := 0.8 + 0.2 * sin(t * 4.0)
			n.draw_arc(lp + Vector2(0, -4), 3.0, PI, TAU, 8, Color(0.06, 0.05, 0.09), 3.0)
			n.draw_arc(lp + Vector2(0, -4), 2.2, PI, TAU, 8, Color(0.5, 0.5, 0.56), 1.0)
			n.draw_rect(Rect2(lp + Vector2(-4, -3), Vector2(9, 8)), Color(0.06, 0.05, 0.09))
			n.draw_rect(Rect2(lp + Vector2(-3, -2), Vector2(7, 6)), Color(0.86 * glow, 0.47 * glow, 0.16))
			n.draw_rect(Rect2(lp + Vector2(-3, -2), Vector2(7, 1)), Color(1.0, 0.82, 0.5))
		else:
			n.draw_rect(Rect2(lp + Vector2(4, 6), Vector2(6, 4)), Color(0.28, 0.25, 0.3))


func _draw_chain(n: Node2D, c: Dictionary) -> void:
	var pts: PackedVector2Array = c["pts"]
	var dk := Color(0.06, 0.05, 0.09)
	var md := Color(0.43, 0.43, 0.5)
	var lt := Color(0.66, 0.65, 0.72)
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var mid := (a + b) * 0.5
		var ang := (b - a).angle()
		n.draw_set_transform(mid + Vector2(1, 2), ang, Vector2(1.0, 0.7))
		n.draw_arc(Vector2.ZERO, 3.2, 0.0, TAU, 10, Color(0, 0, 0, 0.35), 2.0)
		n.draw_set_transform(mid, ang, Vector2(1.0, 0.7))
		if k % 2 == 0:
			n.draw_arc(Vector2.ZERO, 3.2, 0.0, TAU, 10, dk, 3.0)
			n.draw_arc(Vector2.ZERO, 3.2, PI, TAU, 6, lt, 1.0)
			n.draw_arc(Vector2.ZERO, 3.2, 0.0, PI, 6, md, 1.0)
		else:
			n.draw_line(Vector2(-3.6, 0), Vector2(3.6, 0), dk, 3.5)
			n.draw_line(Vector2(-3.0, 0), Vector2(3.0, 0), md, 1.5)
			n.draw_line(Vector2(-2.6, -0.5), Vector2(2.6, -0.5), lt, 1.0)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if c["free_end"] and pts.size() > 0:
		var e := pts[pts.size() - 1]
		n.draw_arc(e, 3.0, 0.4, 5.2, 8, dk, 2.5)
		n.draw_arc(e, 3.0, 0.4, 5.2, 8, lt, 1.0)


func _draw_top(n: Node2D) -> void:
	# manette di ferro ai polsi (seguono la posa e il piccolo sollevamento del corpo)
	for i in 2:
		var w := _wrist(i) + Vector2(0, -bob + bow * 0.4 - 4)
		n.draw_rect(Rect2(w + Vector2(-8, -3), Vector2(16, 6)), Color(0.06, 0.05, 0.09))
		n.draw_rect(Rect2(w + Vector2(-7, -2), Vector2(14, 4)), Color(0.38, 0.38, 0.44))
		n.draw_rect(Rect2(w + Vector2(-7, -2), Vector2(14, 1)), Color(0.64, 0.63, 0.7))
	for r in rings:
		var rr: float = r[0]
		if rr <= 0.0:
			continue
		var a := clampf(1.0 - rr / 320.0, 0.0, 1.0)
		n.draw_set_transform(Vector2(0, -30), 0.0, Vector2(1.0, 0.62))
		n.draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(1.0, 0.85, 0.5, 0.9 * a), 3.0)
		n.draw_arc(Vector2.ZERO, rr - 4.0, 0.0, TAU, 64, Color(1.0, 0.5, 0.2, 0.4 * a), 2.0)
	n.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if head_open > 0.0 and int(t * 8.0) % 2 == 0:
		n.draw_arc(HEAD_UP.lerp(HEAD_DOWN, bow / 14.0), 15.0, 0.0, TAU, 24, Color(1.0, 0.8, 0.3, 0.8), 1.0)
