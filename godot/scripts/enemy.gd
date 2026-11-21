class_name Enemy
extends Node2D

# tipo: [sprite, hp, velocita', ia, raggio, anime, danno, (boss: scala, nome)]
const DEFS := {
	"skeleton": ["skeleton", 30.0, 38.0, "duelist", 5.0, 12, 16],
	"ghoul": ["ghoul", 50.0, 44.0, "pouncer", 5.0, 20, 24],
	"spider": ["spider", 24.0, 62.0, "ambusher", 5.0, 10, 12],
	"gargoyle": ["gargoyle", 90.0, 30.0, "diver", 6.0, 50, 34],
	"ooze": ["ooze", 40.0, 30.0, "chase", 6.0, 14, 14],
	"bat": ["bat", 20.0, 68.0, "bat", 4.0, 8, 10],
	"cultist": ["cultist", 30.0, 34.0, "caster", 5.0, 18, 18],
	"wraith": ["wraith", 40.0, 34.0, "phaser", 5.0, 25, 22],
	"zombie": ["zombie", 70.0, 22.0, "tank", 6.0, 16, 26],
	"skel_archer": ["skel_archer", 28.0, 32.0, "archer", 5.0, 15, 14],
	"rat": ["rat", 8.0, 60.0, "chase", 4.0, 3, 6],
	"imp": ["imp", 26.0, 46.0, "skirmish", 5.0, 16, 16],
	"wisp": ["wisp", 22.0, 52.0, "bat", 4.0, 14, 12],
	"toad": ["toad", 34.0, 38.0, "lunge", 6.0, 14, 18],
	"wolf": ["wolf", 30.0, 66.0, "flank", 5.0, 14, 16],
	"ooze_small": ["ooze", 14.0, 46.0, "chase", 4.0, 4, 8],
	"crow": ["crow", 10.0, 72.0, "bat", 4.0, 5, 8],
	# nemici fantasy classici
	"goblin": ["goblin", 22.0, 56.0, "skirmish", 5.0, 9, 12],
	"goblin_archer": ["goblin_archer", 20.0, 38.0, "archer", 5.0, 11, 11],
	"goblin_shaman": ["goblin_shaman", 24.0, 34.0, "caster", 5.0, 16, 14],
	"kobold": ["kobold", 12.0, 66.0, "chase", 4.0, 4, 8],
	"orc": ["orc", 62.0, 40.0, "duelist", 6.0, 24, 24],
	"troll": ["troll", 150.0, 26.0, "tank", 8.0, 60, 32],
	"ogre": ["ogre", 185.0, 23.0, "tank", 9.0, 70, 40],
	"harpy": ["harpy", 34.0, 60.0, "diver", 5.0, 18, 16],
	"lizardman": ["lizardman", 44.0, 52.0, "flank", 5.0, 18, 18],
	"vampire": ["vampire", 650.0, 30.0, "boss", 11.0, 2000, 34, 1.5, "IL SIGNORE DELLA CRIPTA"],
	"boss_jailer": ["knight_fallen", 260.0, 36.0, "boss", 9.0, 700, 17, 1.8, "IL CARCERIERE"],
	"boss_wraith": ["wraith", 380.0, 34.0, "boss", 10.0, 900, 26, 2.2, "IL FALCIATORE"],
	"boss_gargoyle": ["gargoyle", 520.0, 28.0, "boss", 12.0, 1400, 32, 2.4, "GARGOYLE COLOSSALE"],
	"boss_hanged": ["ghoul", 420.0, 40.0, "boss", 10.0, 1500, 28, 2.2, "L'IMPICCATO"],
	"boss_ooze": ["ooze", 520.0, 26.0, "boss", 12.0, 1500, 26, 2.6, "MADRE DELLE MELME"],
	"boss_yeti": ["ghoul", 600.0, 34.0, "boss", 11.0, 1800, 30, 2.7, "IL GIGANTE DI GHIACCIO"],
	"boss_forge": ["skeleton", 640.0, 32.0, "boss", 12.0, 1900, 36, 2.8, "COLOSSO DI BRACE"],
	# il Campanaro: la testa porta la vita del boss, il resto lo gestisce Colossus
	"boss_campanaro": ["camp_rest", 900.0, 0.0, "part", 14.0, 2600, 30, 1.0, "IL CAMPANARO"],
	"camp_part": ["camp_rest", 999.0, 0.0, "part", 10.0, 0, 0],
}
# nemici speciali: attacchi unici, nome, barra della vita
const CHAMPS := {
	"knight_fallen": {"spr": "knight_fallen", "hp": 230.0, "spd": 40.0, "r": 8.0, "souls": 120, "dmg": 30.0, "scale": 1.35,
		"name": "CAVALIERE CADUTO", "atk": ["charge", "slam"], "kite": false},
	"reaper": {"spr": "reaper", "hp": 190.0, "spd": 44.0, "r": 8.0, "souls": 110, "dmg": 26.0, "scale": 1.35,
		"name": "MIETITORE", "atk": ["blink", "spin"], "kite": false},
	"summoner": {"spr": "summoner", "hp": 160.0, "spd": 34.0, "r": 7.0, "souls": 130, "dmg": 20.0, "scale": 1.25,
		"name": "EVOCATORE", "atk": ["summon", "fan"], "kite": true},
	"abomination": {"spr": "abomination", "hp": 340.0, "spd": 26.0, "r": 11.0, "souls": 180, "dmg": 34.0, "scale": 1.4,
		"name": "ABOMINIO", "atk": ["slam", "slam", "charge"], "kite": false},
	"frost_mage": {"spr": "frost_mage", "hp": 170.0, "spd": 34.0, "r": 7.0, "souls": 130, "dmg": 22.0, "scale": 1.25,
		"name": "STREGONE DEL GELO", "atk": ["nova", "fan"], "kite": true},
	"berserker": {"spr": "berserker", "hp": 210.0, "spd": 52.0, "r": 8.0, "souls": 140, "dmg": 26.0, "scale": 1.3,
		"name": "BERSERKER DI BRACE", "atk": ["charge", "charge", "spin"], "kite": false},
	"plague_doc": {"spr": "plague_doc", "hp": 180.0, "spd": 34.0, "r": 7.0, "souls": 130, "dmg": 18.0, "scale": 1.25,
		"name": "MEDICO DELLA PESTE", "atk": ["poison", "fan"], "kite": true},
}
# varianti: stesso comportamento di un tipo base ma con statistiche, taglia, colore e tratto diversi
const VARIANTS := {
	"skel_brute": {"b": "skeleton", "hp": 2.6, "spd": 0.75, "dmg": 1.4, "sc": 1.3, "tint": Color(1.0, 0.78, 0.7), "trait": ""},
	"skel_runner": {"b": "skeleton", "hp": 0.7, "spd": 1.7, "dmg": 0.8, "sc": 0.9, "tint": Color(0.8, 1.0, 0.8), "trait": ""},
	"ghoul_pale": {"b": "ghoul", "hp": 0.8, "spd": 1.4, "dmg": 1.0, "sc": 0.95, "tint": Color(1.25, 1.25, 1.3), "trait": ""},
	"cult_zealot": {"b": "cultist", "hp": 1.6, "spd": 1.0, "dmg": 1.2, "sc": 1.1, "tint": Color(1.4, 0.7, 0.7), "trait": ""},
	"wolf_dire": {"b": "wolf", "hp": 2.2, "spd": 0.9, "dmg": 1.4, "sc": 1.35, "tint": Color(0.75, 0.75, 0.9), "trait": ""},
	"bat_blood": {"b": "bat", "hp": 1.6, "spd": 1.1, "dmg": 1.3, "sc": 1.15, "tint": Color(1.5, 0.6, 0.6), "trait": ""},
	"zombie_bloated": {"b": "zombie", "hp": 1.2, "spd": 1.0, "dmg": 1.0, "sc": 1.2, "tint": Color(0.8, 1.3, 0.6), "trait": "esplosivo"},
	"spider_brood": {"b": "spider", "hp": 1.3, "spd": 0.9, "dmg": 1.0, "sc": 1.25, "tint": Color(0.9, 0.7, 1.3), "trait": "prolifico"},
	"gargoyle_obs": {"b": "gargoyle", "hp": 1.7, "spd": 0.9, "dmg": 1.2, "sc": 1.15, "tint": Color(0.6, 0.6, 0.75), "trait": ""},
	"orc_warlord": {"b": "orc", "hp": 2.1, "spd": 0.9, "dmg": 1.45, "sc": 1.25, "tint": Color(1.25, 0.85, 0.8), "trait": ""},
	"goblin_boss": {"b": "goblin", "hp": 2.4, "spd": 1.0, "dmg": 1.5, "sc": 1.3, "tint": Color(1.2, 1.1, 0.7), "trait": ""},
	"troll_frost": {"b": "troll", "hp": 1.2, "spd": 1.0, "dmg": 1.1, "sc": 1.0, "tint": Color(0.75, 0.95, 1.4), "trait": ""},
	"imp_cinder": {"b": "imp", "hp": 1.2, "spd": 1.2, "dmg": 1.1, "sc": 1.0, "tint": Color(1.6, 0.8, 0.4), "trait": "esplosivo"},
}
const TRAITS := {
	"veloce": Color(0.75, 1.25, 1.0), "corazzato": Color(0.8, 0.85, 1.05),
	"esplosivo": Color(1.5, 0.85, 0.5), "prolifico": Color(1.1, 0.8, 1.3),
}
var trait_ := ""
const TEL := {"charge": 0.75, "slam": 0.85, "spin": 0.7, "summon": 0.9, "nova": 0.75, "fan": 0.55, "poison": 0.85, "blink": 0.5}
const LUNGE := {"wolf": [0.3, 200.0], "toad": [0.4, 230.0]}

var main
var kind := ""
var ai := "chase"
var hp := 3.0
var max_hp := 3.0
var speed := 30.0
var radius := 5.0
var xp := 3
var dmg := 1.0
var stun := 0.0
var touch_cd := 0.0
var lunge_hit := false
var awake := false
var kb := Vector2.ZERO
var flash := 0.0
var last_hp := -1.0
var tint_state := 0
var cd := 1.0
var tel := 0.0
var lunge := 0.0
var lunge_dir := Vector2.ZERO
var phase := randf() * 6.0
var t := randf() * 10.0
var is_boss := false
var champ := false
var elite := false
var souls_mult := 1.0
var pattern := 0
var atk := ""
var summoner: Enemy = null
var spr: Sprite2D
var nm := ""
var scl := 1.0
var tel_wait := 0.5
var lunge_spd := 165.0
var base_speed := 30.0
var slow_t := 0.0
var burn_t := 0.0
var burn_dps := 0.0
var dying := false
var horde := false
var sref: Dictionary = {}
var combo := 0
var orb := 1.0
var recover_t := 0.0
var blink_cd := 3.0
var dive_pos := Vector2.ZERO
var phase_n := 0
var pat_seen := {}
var col = null   # Colossus a cui appartiene questa parte (null per i nemici normali)
var last_hit_t := -99.0   # il troll si rigenera se non lo colpisci per un po'


func setup(m, k: String, hp_mult := 1.0, is_elite := false, tint := Color.WHITE) -> void:
	main = m
	var vr: Dictionary = VARIANTS.get(k, {})
	if not vr.is_empty():
		k = str(vr["b"])
	kind = k
	var cyc: int = m.cycle
	var sprite_name := ""
	if CHAMPS.has(k):
		var c: Dictionary = CHAMPS[k]
		champ = true
		ai = "champ"
		hp = c["hp"] * hp_mult * 1.6
		speed = c["spd"]
		radius = c["r"]
		xp = c["souls"]
		dmg = c["dmg"] * 1.2
		scl = c["scale"]
		nm = c["name"]
		sprite_name = c["spr"]
		souls_mult = hp_mult
	else:
		var d: Array = DEFS[k]
		ai = d[3]
		hp = d[1] * hp_mult * 1.2
		speed = d[2]
		radius = d[4]
		xp = d[5]
		dmg = float(d[6]) * 1.3
		sprite_name = d[0]
		souls_mult = hp_mult
		is_boss = d.size() > 7
		if is_boss:
			scl = d[7]
			nm = d[8]
			souls_mult = 1.0
			var bmul := 2.1 if kind == "boss_jailer" else 1.5
			hp *= bmul
			dmg *= 1.25 if kind == "boss_jailer" else 1.15
			speed *= 1.12
	if LUNGE.has(k):
		tel_wait = LUNGE[k][0]
		lunge_spd = LUNGE[k][1]
	hp *= 1.0 + 0.6 * cyc
	dmg *= 1.0 + 0.3 * cyc
	souls_mult *= 1.0 + 0.5 * cyc
	# difficolta' proporzionale al livello solo in parte: i nemici crescono piu' piano di te.
	# All'inizio colpiscono meno forte (si impara senza essere puniti), poi tornano a pieno danno.
	# la forza dipende soprattutto dalla ZONA (hp_mult): i nemici crescono con il livello solo un poco,
	# cosi' ad alto livello quelli delle zone iniziali si sconfiggono subito
	var lvf := float(maxi(0, m.player.lv - 1))
	var lsc := 0.6 if (is_boss or champ) else 1.0
	hp *= 1.0 + 0.016 * lvf * lsc
	dmg *= (0.97 + 0.03 * minf(1.0, lvf / 10.0)) * (1.0 + 0.008 * lvf * lsc)
	dmg *= 1.0 + 0.5 * (hp_mult - 1.0)   # le zone avanzate colpiscono anche piu' forte
	souls_mult *= 1.0 + 0.02 * lvf
	spr = Sprite2D.new()
	spr.texture = Game.tex(sprite_name)
	if k == "ooze_small":
		spr.scale = Vector2(0.62, 0.62)
	orb = 1.0 if randf() < 0.5 else -1.0
	spr.offset = Vector2(0, -8)
	if k in ["skeleton", "skel_archer", "boss_forge", "orc", "troll", "ogre"]:
		spr.offset.y -= (spr.texture.get_height() - 20) * 0.5
	add_child(spr)
	spr.modulate = tint
	if is_boss:
		spr.scale = Vector2(scl, scl)
		spr.offset = Vector2(0, -12)
		if k == "boss_forge":
			spr.modulate = Color(1.5, 0.8, 0.5)
	elif champ:
		spr.scale = Vector2(scl, scl)
	if is_elite and not is_boss and not champ:
		elite = true
		hp *= 2.2
		xp *= 3
		dmg *= 1.25
		spr.modulate = tint * Color(1.5, 1.25, 0.6)
		spr.scale = Vector2(1.25, 1.25)
	if not vr.is_empty():
		hp *= float(vr["hp"])
		speed *= float(vr["spd"])
		dmg *= float(vr["dmg"])
		xp = int(xp * (1.0 + 0.5 * (float(vr["hp"]) - 1.0)))
		spr.scale *= float(vr["sc"])
		spr.modulate = spr.modulate * (vr["tint"] as Color)
		trait_ = str(vr["trait"])
	elif not (is_boss or champ or elite) and k != "rat" and k != "ooze_small" and randf() < 0.22:
		trait_ = (TRAITS.keys() as Array).pick_random()
		match trait_:
			"veloce":
				speed *= 1.4
				hp *= 0.85
				spr.scale *= 0.92
			"corazzato":
				hp *= 1.9
				speed *= 0.85
				spr.scale *= 1.12
		spr.modulate = spr.modulate * (TRAITS[trait_] as Color)
		xp = int(xp * 1.4)
	max_hp = hp
	base_speed = speed
	cd = randf_range(0.6, 1.8)
	set_process(false)  # dorme finche' il giocatore non e' vicino (lo risveglia main)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	if col != null:
		flash = maxf(0.0, flash - dt)
		return
	if kind == "troll" and hp < max_hp and t - last_hit_t > 3.0 and not dying:
		hp = minf(max_hp, hp + max_hp * 0.04 * dt)        # rigenerazione: va inseguito e abbattuto in fretta
		if int(t * 4.0) % 8 == 0:
			main.burst(position + Vector2(0, -10), Color(0.4, 0.9, 0.4), 1, 15.0, 0.4)
	t += dt
	flash = max(0.0, flash - dt)
	if slow_t > 0.0:
		slow_t -= dt
	speed = base_speed * (0.5 if slow_t > 0.0 else 1.0)
	if burn_t > 0.0:
		burn_t -= dt
		hp -= burn_dps * dt
		if hp <= 0.0 and not dying:
			dying = true
			main.enemy_died(self)
			return
	spr.position.x = randf_range(-0.8, 0.8) if flash > 0.0 else 0.0   # al colpo trema, senza cambiare colore
	var tint_now := 0
	if slow_t > 0.0:
		tint_now = 1
	elif burn_t > 0.0:
		tint_now = 2
	if tint_now != tint_state:
		tint_state = tint_now
		spr.self_modulate = [Color.WHITE, Color(0.6, 0.85, 1.4), Color(1.5, 0.85, 0.55)][tint_now]
	var tgt: Node2D = main.pick_target(position)
	var to: Vector2 = tgt.position - position
	var d := to.length()
	var u: Vector2 = to / maxf(d, 0.001)
	spr.flip_h = to.x < 0.0
	if not awake:
		if d < 110.0:
			awake = true
			main.beast_note(kind)
		return
	if d > 280.0 and not is_boss:
		awake = false
		set_process(false)
		return
	if kb.length_squared() > 1.0:
		main.move_body(self, kb * dt, radius)
		kb = kb.move_toward(Vector2.ZERO, 500.0 * dt)
	touch_cd -= dt
	if stun > 0.0:
		stun -= dt
		return
	cd -= dt
	match ai:
		"chase":
			main.move_body(self, u * speed * dt, radius)
		"lunge":
			if tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					lunge = 0.25
					lunge_dir = u
					lunge_hit = false
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * lunge_spd * dt, radius)
			else:
				main.move_body(self, u * speed * dt, radius)
				if d < 46.0 and cd <= 0.0:
					tel = tel_wait
					cd = 1.9
		"bat":
			phase += dt * 7.0
			var a := to.angle() + sin(phase) * 1.2
			main.move_body(self, Vector2.from_angle(a) * speed * dt, radius)
		"range":
			var s := -1.0 if d < 70.0 else (1.0 if d > 105.0 else 0.0)
			main.move_body(self, (u * s * speed + u.orthogonal() * 10.0) * dt, radius)
			if tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					main.spawn_projectile(position + Vector2(0, -6), u, 98.0, dmg)
			elif cd <= 0.0 and d < 170.0:
				tel = 0.4
				cd = 2.2
		"archer":
			var s2 := -1.0 if d < 85.0 else (1.0 if d > 125.0 else 0.0)
			main.move_body(self, (u * s2 * speed + u.orthogonal() * 8.0) * dt, radius)
			if tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					for i in range(-1, 2):
						main.spawn_projectile(position + Vector2(0, -6), u.rotated(i * 0.22), 118.0, dmg)
			elif cd <= 0.0 and d < 190.0:
				tel = 0.5
				cd = 2.1
		"duelist":
			if recover_t > 0.0:
				recover_t -= dt
				main.move_body(self, -u * speed * 0.35 * dt, radius)
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					lunge = 0.13
					lunge_dir = u
					lunge_hit = false
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 150.0 * dt, radius)
				if lunge <= 0.0:
					combo -= 1
					if combo > 0:
						tel = 0.3
					else:
						recover_t = 0.8
						cd = 1.3
			else:
				if d > 36.0:
					main.move_body(self, u * speed * dt, radius)
				else:
					main.move_body(self, u.orthogonal() * orb * speed * 0.5 * dt, radius)
				if d < 46.0 and cd <= 0.0:
					combo = 2
					tel = 0.45
		"flank":
			if recover_t > 0.0:
				recover_t -= dt
				main.move_body(self, -u * speed * 0.3 * dt, radius)
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					lunge = 0.3
					lunge_dir = u
					lunge_hit = false
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 215.0 * dt, radius)
				if lunge <= 0.0:
					recover_t = 0.75
					cd = 1.2 + randf() * 1.2
			else:
				phase += dt
				if fmod(phase, 2.4) < dt:
					orb = -orb
				var radial: Vector2 = (u * (d - 64.0) * 0.9).limit_length(speed)
				main.move_body(self, (radial + u.orthogonal() * orb * speed * 0.85) * dt, radius)
				if cd <= 0.0 and d < 100.0:
					tel = 0.32
		"caster":
			blink_cd -= dt
			var sc := -1.0 if d < 80.0 else (1.0 if d > 125.0 else 0.0)
			main.move_body(self, (u * sc * speed + u.orthogonal() * orb * 10.0) * dt, radius)
			if tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					for i in range(-1, 2):
						main.spawn_projectile(position + Vector2(0, -6), u.rotated(i * 0.3), 90.0, dmg)
					recover_t = 0.5
			elif recover_t > 0.0:
				recover_t -= dt
			elif d < 50.0 and blink_cd <= 0.0:
				blink_cd = 4.5
				var np: Vector2 = tgt.position + Vector2.from_angle(randf() * TAU) * 115.0
				if main.free_at(np, radius):
					main.burst(position, Color(0.5, 0.15, 0.6), 12, 40.0, 0.4)
					position = np
					main.burst(position, Color(0.5, 0.15, 0.6), 12, 40.0, 0.4)
			elif cd <= 0.0 and d < 190.0:
				tel = 0.55
				cd = 2.3
		"diver":
			if recover_t > 0.0:
				recover_t -= dt
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					lunge = 0.28
					lunge_dir = (dive_pos - position).normalized()
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 280.0 * dt, radius)
				if lunge <= 0.0:
					recover_t = 1.1
					cd = 1.6
			else:
				phase += dt
				if fmod(phase, 3.0) < dt:
					orb = -orb
				var radial2: Vector2 = (u * (d - 88.0) * 0.9).limit_length(speed)
				main.move_body(self, (radial2 + u.orthogonal() * orb * speed * 0.9) * dt, radius)
				if cd <= 0.0 and d < 140.0:
					dive_pos = tgt.position
					tel = 0.85
					main.spawn_hazard(dive_pos, 30.0, 0.85, 0.15, dmg, 0.0, Color(0.9, 0.3, 0.2))
		"ambusher":
			if recover_t > 0.0:
				recover_t -= dt
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					if atk == "web":
						main.spawn_projectile(position + Vector2(0, -4), u, 105.0, dmg * 0.5, 1.5)
						recover_t = 0.45
						cd = 1.4
					else:
						lunge = 0.22
						lunge_dir = u
						lunge_hit = false
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 220.0 * dt, radius)
				if lunge <= 0.0:
					recover_t = 0.7
					cd = 1.1
			else:
				phase += dt * 6.0
				var sa := to.angle() + sin(phase) * 0.9
				main.move_body(self, Vector2.from_angle(sa) * speed * dt, radius)
				if cd <= 0.0:
					if d > 75.0 and d < 150.0:
						atk = "web"
						tel = 0.4
					elif d <= 75.0:
						atk = "bite"
						tel = 0.28
		"skirmish":
			if recover_t > 0.0:
				recover_t -= dt
				main.move_body(self, -u * speed * 1.6 * dt, radius)
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					main.spawn_projectile(position + Vector2(0, -6), u.rotated(-0.12), 100.0, dmg)
					main.spawn_projectile(position + Vector2(0, -6), u.rotated(0.12), 100.0, dmg)
					recover_t = 0.7
					cd = 1.7
			else:
				var s3 := -1.0 if d < 75.0 else (1.0 if d > 115.0 else 0.0)
				main.move_body(self, (u * s3 * speed + u.orthogonal() * orb * speed * 0.7) * dt, radius)
				if cd <= 0.0 and d < 170.0:
					tel = 0.4
		"phaser":
			if recover_t > 0.0:
				recover_t -= dt
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					recover_t = 0.9
					cd = 1.8
			else:
				main.move_body(self, u * speed * 0.7 * dt, radius)
				if cd <= 0.0 and d < 170.0:
					var behind: Vector2 = tgt.position - (main.player.face if tgt == main.player else u) * 38.0
					if main.free_at(behind, radius):
						main.burst(position, Color(0.4, 0.8, 1.0), 12, 40.0, 0.4)
						position = behind
						main.burst(position, Color(0.4, 0.8, 1.0), 12, 40.0, 0.4)
					var dv: Vector2 = (tgt.position - position).normalized()
					main.spawn_hazard(position + dv * 18.0, 32.0, 0.55, 0.15, dmg, 0.0, Color(0.5, 0.9, 1.0))
					tel = 0.6
		"pouncer":
			if recover_t > 0.0:
				recover_t -= dt
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					lunge = 0.34
					lunge_dir = u
					lunge_hit = false
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 250.0 * dt, radius)
				if lunge <= 0.0:
					recover_t = 1.0
					cd = 1.5
			else:
				if d > 100.0:
					main.move_body(self, u * speed * dt, radius)
				else:
					main.move_body(self, (-u * speed * 0.5 + u.orthogonal() * orb * speed * 0.5) * dt, radius)
				if cd <= 0.0 and d < 125.0 and d > 60.0:
					tel = 0.5
		"tank":
			if tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					recover_t = 1.0
			elif recover_t > 0.0:
				recover_t -= dt
			else:
				main.move_body(self, u * speed * dt, radius)
				if d < 40.0 and cd <= 0.0:
					tel = 0.8
					cd = 2.4
					main.spawn_hazard(position, 32.0, 0.8, 0.15, dmg, 0.0, Color(0.9, 0.3, 0.2))
		"champ":
			_champ_ai(dt, u, d)
		"boss":
			if recover_t > 0.0:
				recover_t -= dt
			elif tel > 0.0:
				tel -= dt
				if tel <= 0.0:
					_boss_attack(u)
					if lunge <= 0.0:
						recover_t = maxf(recover_t, 0.55)
			elif lunge > 0.0:
				lunge -= dt
				main.move_body(self, lunge_dir * 170.0 * dt, radius)
				if lunge <= 0.0:
					if combo > 0:
						combo -= 1
						tel = 0.35
						pattern = 2
					else:
						recover_t = 0.9
			else:
				main.move_body(self, u * speed * dt, radius)
				if cd <= 0.0:
					var pn := 0 if hp > max_hp * 0.66 else (1 if hp > max_hp * 0.33 else 2)
					if pn > phase_n:
						phase_n = pn
						main.say("%s: FURIA!" % nm)
						main.shake(9.0)
						main.snd("roar")
					pattern = randi() % (3 + pn * 1 + (1 if pn >= 1 else 0))
					if randf() < (0.3 + 0.2 * pn):
						pattern = 6   # mossa firma del boss
					pat_seen[pattern] = int(pat_seen.get(pattern, 0)) + 1
					tel = 0.6 if pn == 0 else 0.5
					cd = 1.8 if pn == 0 else (1.4 if pn == 1 else 1.05)
	var bob_base := -12.0 if is_boss else -8.0
	if kind == "skeleton" or kind == "skel_archer" or kind == "boss_forge":
		bob_base -= (spr.texture.get_height() - 20) * 0.5  # sprite piu' alti: i piedi restano allo stesso punto
	spr.offset.y = bob_base - (abs(sin(t * 9.0)) * 1.0 if ai != "bat" else sin(t * 12.0) * 2.0 - 4.0)
	if d < radius + 5.0 + (4.0 if is_boss else 0.0):
		if ai == "lunge" or ai == "boss" or ai == "champ" or ai == "duelist" or ai == "flank" or ai == "ambusher" or ai == "pouncer":
			if lunge > 0.0 and not lunge_hit:
				lunge_hit = true
				_hit_target(tgt, u, 3.0 if kind == "wisp" else 0.0)
		elif touch_cd <= 0.0:
			touch_cd = 0.75
			_hit_target(tgt, u, 2.5 if kind == "wisp" else 0.0)
	if hp != last_hp or tel > 0.0 or recover_t > 0.0:
		last_hp = hp
		queue_redraw()


# ---------------- nemici speciali
func _champ_ai(dt: float, u: Vector2, d: float) -> void:
	var c: Dictionary = CHAMPS[kind]
	if tel > 0.0:
		tel -= dt
		if tel <= 0.0:
			_champ_exec(u)
	elif lunge > 0.0:
		lunge -= dt
		main.move_body(self, lunge_dir * 210.0 * dt, radius)
		if lunge <= 0.0 and atk == "charge":
			main.spawn_hazard(position, 30.0, 0.12, 0.12, dmg, 0.0, Color(1.0, 0.5, 0.2))
	else:
		if c["kite"]:
			var s := -1.0 if d < 95.0 else (1.0 if d > 135.0 else 0.0)
			main.move_body(self, (u * s * speed + u.orthogonal() * 14.0) * dt, radius)
		else:
			main.move_body(self, u * speed * dt, radius)
		if cd <= 0.0 and d < (200.0 if c["kite"] else 120.0):
			_champ_start()


func _champ_start() -> void:
	var c: Dictionary = CHAMPS[kind]
	var list: Array = c["atk"]
	atk = list[randi() % list.size()]
	tel = TEL[atk]
	cd = 2.2 + randf() * 0.8
	var rr := 38.0 * scl / 1.3
	match atk:
		"slam":
			main.spawn_hazard(position, rr + 4.0, tel, 0.15, dmg, 0.0, Color(0.9, 0.25, 0.2))
		"spin":
			main.spawn_hazard(position, rr, tel, 0.12, dmg, 0.0, Color(0.95, 0.5, 0.2))
			main.spawn_hazard(position, rr, tel + 0.5, 0.12, dmg, 0.0, Color(0.95, 0.5, 0.2))
		"poison":
			main.spawn_hazard(main.player.position, 28.0, tel, 4.2, dmg * 0.3, 0.5, Color(0.4, 0.9, 0.3))


func _champ_exec(u: Vector2) -> void:
	var slow_f := 3.0 if kind == "frost_mage" else 0.0
	match atk:
		"charge":
			lunge = 0.5
			lunge_dir = u
			lunge_hit = false
		"summon":
			var alive := 0
			for e in main.enemies:
				if e.summoner == self:
					alive += 1
			if alive < 6:
				for i in 3:
					var a := TAU * i / 3.0 + randf()
					var pos := position + Vector2.from_angle(a) * 20.0
					if main.free_at(pos, 5.0):
						var m: Enemy = main.spawn_enemy("skeleton", pos, 0.6)
						m.awake = true
						m.set_process(true)
						m.summoner = self
			main.burst(position, Color(0.8, 0.3, 1.0), 20, 50.0, 0.5)
		"nova":
			for i in 16:
				main.spawn_projectile(position + Vector2(0, -6), Vector2.from_angle(i * TAU / 16.0), 62.0, dmg * 0.8, slow_f)
			main.snd("roar")
		"fan":
			for i in range(-2, 3):
				main.spawn_projectile(position + Vector2(0, -6), u.rotated(i * 0.24), 92.0, dmg * 0.8, slow_f)
		"blink":
			var tp: Vector2 = main.player.position - main.player.face * 26.0
			if main.free_at(tp, radius):
				main.burst(position, Color(0.5, 1.0, 0.8), 14, 40.0, 0.4)
				position = tp
				main.burst(position, Color(0.5, 1.0, 0.8), 14, 40.0, 0.4)
			main.spawn_hazard(position, 36.0, 0.35, 0.12, dmg, 0.0, Color(0.5, 1.0, 0.8))


func _boss_attack(u: Vector2) -> void:
	main.snd("roar")
	var p := position + Vector2(0, -8)
	match pattern:
		0:
			for i in 14:
				main.spawn_projectile(p, Vector2.from_angle(i * TAU / 14.0 + t), 70.0, dmg)
			main.shake(5.0)
		1:
			var n := 3 if hp > max_hp * 0.5 else 5
			for i in range(-n, n + 1):
				main.spawn_projectile(p, u.rotated(i * 0.24), 85.0, dmg)
		2:
			lunge = 0.3
			lunge_dir = u
			lunge_hit = false
		3:
			# pioggia di colpi: cerchi di danno attorno al giocatore, scaglionati
			for i in 6:
				var off := Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0)
				main.spawn_hazard(main.player.position + off, 22.0, 0.7 + i * 0.16, 0.12, dmg, 0.0, Color(0.9, 0.25, 0.2))
		4:
			# richiamo: due servitori
			var cnt := 0
			for en in main.enemies:
				if en.horde == false and en.kind == "skeleton":
					cnt += 1
			if cnt < 6:
				for i in 2:
					var sp: Enemy = main.spawn_enemy("skeleton", position + Vector2.from_angle(randf() * TAU) * 26.0, 1.0, false, Color.WHITE)
					sp.awake = true
					sp.set_process(true)
		6:
			_boss_signature(u)
		5:
			# doppio ventaglio incrociato
			for i in range(-4, 5):
				main.spawn_projectile(p, u.rotated(i * 0.2), 80.0, dmg)
				main.spawn_projectile(p, u.rotated(i * 0.2 + 0.1), 105.0, dmg)


## mossa firma: ogni boss ha un attacco tutto suo
func _boss_signature(u: Vector2) -> void:
	var pl: Node2D = main.player
	match kind:
		"boss_jailer":
			combo = 2   # tre cariche di fila
			lunge = 0.3
			lunge_dir = u
			lunge_hit = false
		"boss_wraith":
			var behind: Vector2 = pl.position - main.player.face * 40.0
			if main.free_at(behind, radius):
				main.burst(position, Color(0.4, 0.8, 1.0), 16, 50.0, 0.4)
				position = behind
				main.burst(position, Color(0.4, 0.8, 1.0), 16, 50.0, 0.4)
			for i in 3:
				main.spawn_hazard(position + Vector2.from_angle(i * TAU / 3.0 + t) * 34.0, 24.0, 0.5 + i * 0.2, 0.15, dmg, 0.0, Color(0.5, 0.9, 1.0))
			main.spawn_hazard(position, 40.0, 0.7, 0.15, dmg, 0.0, Color(0.5, 0.9, 1.0))
		"boss_gargoyle":
			main.spawn_hazard(pl.position, 52.0, 1.0, 0.2, dmg * 1.4, 0.0, Color(0.9, 0.3, 0.2))
			dive_pos = pl.position
			recover_t = 1.5
		"boss_hanged":
			var n := 0
			for en in main.enemies:
				if en.kind == "crow":
					n += 1
			if n < 6:
				for i in 3:
					var cw: Enemy = main.spawn_enemy("crow", position + Vector2.from_angle(randf() * TAU) * 24.0, 1.0, false, Color.WHITE)
					cw.awake = true
					cw.set_process(true)
		"boss_ooze":
			for i in 3:
				var os: Enemy = main.spawn_enemy("ooze_small", position + Vector2.from_angle(i * TAU / 3.0) * 22.0, 1.0, false, Color.WHITE)
				os.awake = true
				os.set_process(true)
			for i in 3:
				main.spawn_hazard(pl.position + Vector2.from_angle(randf() * TAU) * 40.0, 26.0, 0.6, 4.0, dmg * 0.25, 0.5, Color(0.4, 0.9, 0.3), 0.5)
		"boss_yeti":
			for i in 16:
				main.spawn_projectile(position + Vector2(0, -8), Vector2.from_angle(i * TAU / 16.0), 62.0, dmg * 0.7, 1.5)
			main.spawn_hazard(position, 60.0, 0.8, 0.2, dmg, 0.0, Color(0.6, 0.85, 1.0))
		"boss_forge":
			for i in 6:
				main.spawn_hazard(position + u * (28.0 * (i + 1)), 22.0, 0.45 + i * 0.14, 0.15, dmg, 0.0, Color(1.0, 0.5, 0.15))
		"vampire":
			var nb := 0
			for en in main.enemies:
				if en.kind == "bat":
					nb += 1
			if nb < 8:
				for i in 4:
					var bt: Enemy = main.spawn_enemy("bat", position + Vector2.from_angle(randf() * TAU) * 28.0, 1.0, false, Color.WHITE)
					bt.awake = true
					bt.set_process(true)
			var bh: Vector2 = pl.position - main.player.face * 44.0
			if main.free_at(bh, radius):
				position = bh
			main.spawn_hazard(position, 44.0, 0.6, 0.15, dmg, 0.0, Color(0.8, 0.1, 0.2))
		_:
			lunge = 0.3
			lunge_dir = u
			lunge_hit = false


func _draw() -> void:
	if col != null:
		return
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.4))
	var sh := radius + (8.0 if is_boss else 2.0) * (1.0 if not elite else 1.2) + (4.0 if champ else 0.0)
	draw_circle(Vector2.ZERO, sh, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if tel > 0.0 and int(t * 20.0) % 2 == 0:
		var y := -34.0 if is_boss else (-28.0 if champ else -22.0)
		draw_rect(Rect2(-1, y, 2, 5), Color(1, 0.2, 0.2))
		draw_rect(Rect2(-1, y + 7, 2, 2), Color(1, 0.2, 0.2))
	if recover_t > 0.0:
		for i in 3:
			var a := t * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 6.0, -22.0 + sin(a) * 2.0), 1.1, Color(1.0, 0.9, 0.4))
	if champ and awake:
		var w := 26.0
		draw_rect(Rect2(-w / 2 - 1, -30, w + 2, 4), Color(0, 0, 0, 0.85))
		draw_rect(Rect2(-w / 2, -29, w * clampf(hp / max_hp, 0.0, 1.0), 2), Color(0.85, 0.5, 0.15))


func hurt(d: float, dir: Vector2, force: float, heavy := false) -> void:
	if col != null:
		d = col.part_hurt(self, d)
		if d <= 0.0:
			return
	last_hit_t = t
	var crit: bool = randf() < main.player.crit_now()
	if crit:
		d *= 2.0
	if recover_t > 0.0:
		d *= 1.5 if not is_boss else 1.25
		main.popup(position + Vector2(0, -24), "PUNITO", Color(1.0, 0.85, 0.35))
	hp -= d
	flash = 0.1
	awake = true
	set_process(true)
	kb = dir * force * (0.2 if is_boss else (0.4 if champ else 1.0))
	if not (is_boss or champ):
		if heavy:
			stun = 0.55
			tel = 0.0
			lunge = 0.0
		elif tel <= 0.0 and lunge <= 0.0:
			stun = 0.18
	main.snd("hit")
	main.popup(position + Vector2(0, -14), str(int(round(d))) + ("!" if crit else ""),
		Color(1, 0.82, 0.3) if crit else Color(1, 1, 1))
	main.burst(position, Color(0.75, 0.15, 0.3) if kind != "skeleton" else Color(0.85, 0.82, 0.7), 6, 45.0, 0.35)
	if hp <= 0.0 and not dying:
		dying = true
		main.enemy_died(self)


func death_trait() -> void:
	match trait_:
		"esplosivo":
			main.burst(position, Color(1.0, 0.55, 0.2), 22, 90.0, 0.5)
			main.shake(3.0)
			main.snd("kill")
			var pl: Node2D = main.player
			if pl.position.distance_to(position) < 34.0:
				pl.hurt(dmg * 0.8, (pl.position - position).normalized(), 0.0)
		"prolifico":
			for i in 2:
				var sp: Enemy = main.spawn_enemy("rat", position + Vector2(randf_range(-8, 8), randf_range(-5, 5)), 1.0, false, Color.WHITE)
				sp.awake = true
				sp.set_process(true)


func apply_status(kind_: String, dur: float, val: float) -> void:
	if kind_ == "slow":
		slow_t = maxf(slow_t, dur * (0.4 if is_boss else 1.0))
	elif kind_ == "burn":
		burn_t = maxf(burn_t, dur)
		burn_dps = maxf(burn_dps, val)


func _hit_target(tgt: Node2D, u: Vector2, slow: float) -> void:
	if tgt == main.player and main.player.try_parry(self):
		return
	if tgt == main.player:
		main.player.hurt(dmg, u, slow)
		var th: float = main.player.arm("th")
		if th > 0.0 and not dying:
			hurt(dmg * th, -u, 30.0)   # spine dell'armatura
	else:
		(tgt as Ally).hurt(dmg * 0.8)
