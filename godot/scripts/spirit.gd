class_name Spirit
extends Node2D
## Anima legata: lo spirito di un nemico potente sconfitto che combatte al tuo fianco per tutta la partita.
## Ogni tipo attacca in modo diverso; riprendere un'anima dello stesso tipo la potenzia.

const DATA := {
	"knight_fallen": {"n": "CAVALIERE CADUTO", "mode": "melee", "dmg": 1.6, "cd": 1.1, "spr": "knight_fallen"},
	"berserker": {"n": "BERSERKER", "mode": "melee", "dmg": 0.9, "cd": 0.5, "spr": "berserker"},
	"reaper": {"n": "MIETITORE", "mode": "arc", "dmg": 1.3, "cd": 1.5, "spr": "reaper"},
	"boss_wraith": {"n": "FALCIATORE", "mode": "arc", "dmg": 1.9, "cd": 1.3, "spr": "wraith"},
	"frost_mage": {"n": "MAGO DEL GELO", "mode": "range", "dmg": 1.0, "cd": 1.1, "spr": "frost_mage"},
	"summoner": {"n": "EVOCATORE", "mode": "range", "dmg": 1.2, "cd": 0.9, "spr": "summoner"},
	"plague_doc": {"n": "MEDICO DELLA PESTE", "mode": "aura", "dmg": 0.35, "cd": 1.0, "spr": "plague_doc"},
	"abomination": {"n": "ABOMINIO", "mode": "slam", "dmg": 2.1, "cd": 2.4, "spr": "abomination"},
	"boss_gargoyle": {"n": "GARGOYLE", "mode": "slam", "dmg": 2.6, "cd": 2.2, "spr": "gargoyle"},
	"boss_forge": {"n": "COLOSSO DI BRACE", "mode": "slam", "dmg": 2.8, "cd": 2.0, "spr": "skeleton"},
}

var main
var kind := ""
var lv := 1
var idx := 0
var count := 1
var cd := 0.5
var t := randf() * 6.0
var spr: Sprite2D
var aim := Vector2.RIGHT


func setup(m, k: String, level: int) -> void:
	main = m
	kind = k
	lv = level
	spr = Sprite2D.new()
	spr.texture = Game.tex(str(DATA[k]["spr"]))
	spr.offset = Vector2(0, -8)
	spr.modulate = Color(0.55, 0.95, 1.4, 0.82)
	add_child(spr)
	Game.make_light(self, Vector2(0, -6), Color(0.5, 0.85, 1.0), 0.9, 0.5)


func power() -> float:
	return main.player.bd() * (1.0 + 0.3 * (lv - 1))


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	cd -= dt
	var pl: Player = main.player
	var goal: Vector2 = pl.position + Vector2.from_angle(TAU * idx / maxf(1.0, count) + t * 0.45) * (30.0 + 4.0 * count)
	position = position.lerp(goal, 1.0 - exp(-dt * 7.0))
	spr.offset.y = -8.0 - sin(t * 3.0 + idx) * 1.5
	spr.flip_h = aim.x < 0.0
	if cd <= 0.0:
		_attack()


func _nearest(max_d: float) -> Enemy:
	var best: Enemy = null
	var bd := max_d * max_d
	for e in main.enemies:
		if not e.awake:
			continue
		var d2: float = e.position.distance_squared_to(position)
		if d2 < bd:
			bd = d2
			best = e
	return best


func _attack() -> void:
	var d: Dictionary = DATA[kind]
	var pw := power()
	match str(d["mode"]):
		"melee":
			var tg := _nearest(110.0)
			if tg == null:
				cd = 0.2
				return
			cd = float(d["cd"])
			aim = tg.position - position
			position = tg.position - aim.normalized() * 10.0
			tg.hurt(pw * float(d["dmg"]), aim.normalized(), 110.0, false)
			main.player.on_hit(tg, pw, {})
			main.burst(tg.position, Color(0.6, 0.95, 1.0), 8, 50.0, 0.3)
			main.snd("hit")
		"arc":
			var rr := 36.0 + 4.0 * lv
			var hit := false
			for e in main.enemies.duplicate():
				if e.awake and e.position.distance_squared_to(position) < (rr + e.radius) * (rr + e.radius):
					e.hurt(pw * float(d["dmg"]), (e.position - position).normalized(), 90.0, false)
					main.player.on_hit(e, pw, {})
					hit = true
			if hit:
				cd = float(d["cd"])
				main.add_ring(position, rr, Color(0.6, 0.95, 1.0))
			else:
				cd = 0.25
		"range":
			var tg2 := _nearest(230.0)
			if tg2 == null:
				cd = 0.25
				return
			cd = float(d["cd"])
			aim = tg2.position - position
			var wpn := {"a": ["gelo"]} if kind == "frost_mage" else {}
			main.spawn_parrow(position + Vector2(0, -6), aim.normalized(), 230.0, pw * float(d["dmg"]), 0.9, 0 + lv / 3, Color(0.6, 0.9, 1.0), wpn, 0.0, true)
		"aura":
			var ra := 46.0 + 5.0 * lv
			var any := false
			for e in main.enemies.duplicate():
				if e.awake and e.position.distance_squared_to(position) < (ra + e.radius) * (ra + e.radius):
					e.apply_status("burn", 3.0, pw * float(d["dmg"]))
					e.hurt(pw * 0.2, (e.position - position).normalized(), 20.0, false)
					any = true
			cd = float(d["cd"])
			if any:
				main.burst(position, Color(0.4, 0.9, 0.3), 10, 40.0, 0.5)
		"slam":
			var rs := 42.0 + 5.0 * lv
			var tg3 := _nearest(120.0)
			if tg3 == null:
				cd = 0.3
				return
			cd = float(d["cd"])
			var center: Vector2 = tg3.position
			position = center - (center - position).normalized() * 18.0
			for e in main.enemies.duplicate():
				if e.awake and e.position.distance_squared_to(center) < (rs + e.radius) * (rs + e.radius):
					e.hurt(pw * float(d["dmg"]), (e.position - center).normalized(), 170.0, false)
					main.player.on_hit(e, pw, {})
			main.add_ring(center, rs, Color(0.7, 0.9, 1.0))
			main.burst(center, Color(0.6, 0.85, 1.0), 16, 70.0, 0.4)
			main.snd("slam")
			main.shake(2.0)
