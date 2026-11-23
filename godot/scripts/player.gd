class_name Player
extends Node2D

var main
var cls := "cavaliere"
var rk := {}                 # gradi dei potenziamenti
var attr := {}               # attributi scelti ai livelli: vig, res, for, des, int, fed, fort
var hp := 100.0
var max_hp := 100.0
var st := 100.0
var max_st := 100.0
var st_delay := 0.0
var mana := 40.0
var max_mana := 40.0
var flasks := 3
var max_flasks := 3
var relics := {}
var drink_t := 0.0
var heavy_t := 0.0
var base_dmg := 10.0
var speed := 82.0
var radius := 5.0
var face := Vector2.RIGHT
var atk_t := 0.0
var atk_dur := 0.2
var atk_cd := 0.0
var combo := 0
var combo_t := 0.0
var big := false
var cur_reach := 29.0
var cur_arc := 1.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var inv := 0.0
var flash := 0.0
var kb := Vector2.ZERO
var souls := 0
var lv := 1
var kills := 0
var spr: Sprite2D
var slash: Node2D
var light: PointLight2D
var cam: Camera2D
var t := 0.0
var crit := 0.05
var slow_t := 0.0
var wslots: Array = [null, null]
var wcur := 0
var spells: Array = ["", ""]
var known: Array = []
var spell_cd: Array = [0.0, 0.0]
var shield := 0.0
var shield_t := 0.0
var regen_t := 0.0
var regen_rate := 0.0
var cast_t := 0.0
var zmode := 0           # 0 normale, 1 orda, 2 tattica
var focus := 100.0
const MAX_FOCUS := 100.0
const ZOOM_FAR := 0.82
var run_w := {}
var spirits: Array = []
var riposta_cd := 0.0
var parry_t := 0.0
var mats := {}
var buffs := {}
var bval := {}           # potenza degli effetti delle pozioni create (b_dm, b_df, ...)
var armor := {}          # pezzi d'armatura indossati: testa, torso, gambe
var bag: Array = []      # armi e armature trasportate: {"k": "w", "w": arma} / {"k": "a", "a": pezzo}
var belt: Array = []     # pozioni a portata di Z/X (max 4)
var relic_eq: Array = [] # reliquie indossate (max 3): solo queste hanno effetto
const BAG_MAX := 36
const BELT_MAX := 4
const RELIC_MAX := 3
var brews := {}          # ricette delle pozioni create: id -> {n, fx}
var items := {}         # consumabili creati, da usare a piacere: id -> quantita'
var item_sel := 0
var chrono := 60.0       # Cronotone: carica per evocare con la bolla spazio-temporale
var pity := 0            # oggetti inutili evocati di fila
var veh := {}            # mezzo evocato in uso: id, hp, max, t (tempo residuo), cd, crush
var parry_cd := 0.0
var rw_t := {}
var blade_ang := 0.0
var blade_hit: Dictionary = {}
var knife_t := 0.0
var aim_world := Vector2.ZERO
var lock: Enemy = null          # nemico agganciato (mira manuale)
var wspr: Sprite2D          # arma impugnata, cambia con l'arma in uso
var wspr_f := ""


## effetto di una reliquia: conta solo se indossata
func rl(id: String) -> int:
	return int(relics.get(id, 0)) if relic_eq.has(id) else 0


func relic_own(id: String) -> int:
	return int(relics.get(id, 0))


## caselle occupate nella borsa: armi, armature, pozioni e reliquie non indossate (i materiali hanno una sacca a parte)
func bag_used() -> int:
	var n := bag.size()
	for id in items:
		if int(items[id]) > 0:
			n += 1
	for id in relics:
		if int(relics[id]) > 0 and not relic_eq.has(id):
			n += 1
	return n


func bag_free() -> int:
	return BAG_MAX - bag_used()


## comandi del giocatore, bloccati mentre la borsa e' aperta (il mondo non si ferma)
func act(a: String) -> bool:
	return not main.inv_open and Input.is_action_just_pressed(a)


## FUOCO AUTOMATICO (impostazioni): attacca da solo quando un nemico e' a portata,
## lasciando sempre un po' di stamina per la rotolata
func auto_fire(f: Dictionary) -> bool:
	if not bool(main.settings.get("auto_fire", false)) or main.inv_open or st < max_st * 0.3:
		return false
	var reach := 150.0 if f["ranged"] else 30.0 + Rpg.reach_add(weapon())
	var near: Enemy = main.nearest_enemy(position, reach)
	if near == null or near.dying or not near.awake:
		return false
	if not bool(main.settings["aim_manual"]):
		face = (near.position - position).normalized()
	return true


func act_held(a: String) -> bool:
	return not main.inv_open and Input.is_action_pressed(a)


func r(id: String) -> int:
	return int(rk.get(id, 0))


## somma di una statistica su tutti i pezzi d'armatura
func arm(k: String) -> float:
	var s := 0.0
	for pc in armor.values():
		s += float((pc["st"] as Dictionary).get(k, 0.0))
	return s


## potenza di un effetto di pozione attivo (0 se non attivo)
func bv(k: String) -> float:
	return float(bval.get(k, 0.0)) if buffs.has(k) else 0.0


func crit_now() -> float:
	return crit + bv("b_cr")


func a(id: String) -> int:
	return int(attr.get(id, 0))


## punti di attributo che contano per l'arma impugnata
func wscale() -> float:
	var w: Array = Stats.SCALE.get(str(weapon()["f"]), [0.5, 0.5, 0.0, 0.0])
	return a("for") * float(w[0]) + a("des") * float(w[1]) + a("int") * float(w[2]) + a("fed") * float(w[3])


func weapon() -> Dictionary:
	if wslots[wcur] == null:
		wslots[wcur] = Rpg.make_weapon(0, Rpg.CLASSES[cls]["weapon"])
	return wslots[wcur]


func apply_stats() -> void:
	var c: Dictionary = Rpg.CLASSES[cls]
	max_hp = c["hp"] + 15.0 * r("vigor") + 9.0 * a("vig") + arm("hp") + 3.0 * float(lv - 1) + 6.0 * rl("pietra")
	max_st = c["st"] + 12.0 * r("endur") + 5.0 * a("res") + arm("st")
	max_mana = c["mana"] + 12.0 * r("mente") + 4.0 * a("int") + arm("mn")
	max_flasks = 3 + r("fiale") + a("fed") / 8
	speed = (c["spd"] + 2.0) * (1.0 + 0.04 * rl("lanterna") + arm("mv"))
	refresh_weapon()


func refresh_weapon() -> void:
	crit = 0.05 + 0.04 * r("crit") + 0.004 * a("des") + 0.005 * a("fort") + arm("cr") + Rpg.crit_bonus(weapon())


func set_class(id: String) -> void:
	cls = id
	var c: Dictionary = Rpg.CLASSES[id]
	spr.texture = Game.tex(str(c["spr"]) + "_b")
	wslots = [Rpg.make_weapon(0, c["weapon"]), null]
	wcur = 0
	spells = [c["spells"][0], c["spells"][1]]
	known = [c["spells"][0], c["spells"][1]]
	spell_cd = [0.0, 0.0]
	apply_stats()
	hp = max_hp
	st = max_st
	mana = max_mana
	flasks = max_flasks


func bd() -> float:
	return base_dmg + 0.25 * float(lv - 1)


func dmg() -> float:
	return bd() * (1.0 + 0.12 * r("forza")) * (1.0 + Stats.PER_POINT * wscale()) * (1.0 + float(weapon()["b"])) * (1.25 if buffs.has("forza") else 1.0) * (1.0 + bv("b_dm"))


func spell_pow() -> float:
	var p := 1.0 + 0.12 * r("incanto") + 0.10 * r("mente") + 0.035 * a("int")
	if str(weapon()["f"]) == "staff":
		p *= 1.2
	return p * (1.0 + arm("sp") + bv("b_sp"))


func setup(m) -> void:
	main = m
	spr = Sprite2D.new()
	spr.texture = Game.tex("hero")
	spr.offset = Vector2(0, -8)
	add_child(spr)
	wspr = Sprite2D.new()
	wspr.centered = false
	wspr.offset = Vector2(-12, -18)   # impugnatura dell'arma sull'origine: ruota attorno alla mano
	spr.add_child(wspr)
	apply_stats()
	hp = max_hp
	st = max_st
	mana = max_mana
	flasks = max_flasks
	slash = Node2D.new()
	slash.draw.connect(_draw_slash)
	add_child(slash)
	light = Game.make_light(self, Vector2(0, -6), Color(1.0, 0.84, 0.66), 2.3, 1.7)
	cam = Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 9.0
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = Game.MW * Game.TS
	cam.limit_bottom = Game.MH * Game.TS
	add_child(cam)
	var d := CPUParticles2D.new()
	d.amount = 40
	d.lifetime = 8.0
	d.preprocess = 8.0
	d.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	d.emission_rect_extents = Vector2(250, 140)
	d.gravity = Vector2(2, -3)
	d.initial_velocity_min = 1.0
	d.initial_velocity_max = 4.0
	d.scale_amount_min = 1.0
	d.scale_amount_max = 1.5
	d.color = Color(0.7, 0.62, 0.9, 0.35)
	d.local_coords = false
	add_child(d)
	set_class("cavaliere")


## arma in mano: segue la mano, si specchia con il personaggio e oscilla durante i colpi
func update_wspr() -> void:
	var f := str(weapon()["f"])
	var hs := str(weapon().get("hs", "hw_" + f))
	if hs != wspr_f:
		wspr_f = hs
		wspr.texture = Game.tex(hs)
	var sg := -1.0 if spr.flip_h else 1.0
	wspr.flip_h = spr.flip_h
	wspr.position = Vector2(5.5 * sg, spr.offset.y + 3.0)
	var rot := 0.18
	var ranged: bool = bool(Rpg.FAM[f]["ranged"])
	if heavy_t > 0.0 and not ranged:
		rot = -0.9   # carica il colpo pesante
	elif atk_t > 0.0 and atk_dur > 0.0:
		var pr := clampf(1.0 - atk_t / atk_dur, 0.0, 1.0)
		if ranged:
			rot = 0.18 - 0.35 * sin(pr * PI)   # rinculo
		elif f == "spear" or f == "dagger":
			rot = 1.4                           # affondo in avanti
			wspr.position += Vector2(sg * 4.0 * sin(pr * PI), 0)
		else:
			rot = lerpf(-1.3, 2.0, pr)          # fendente
	elif cast_t > 0.0:
		rot = -0.25
	wspr.rotation = rot * sg


func set_limits() -> void:
	cam.limit_right = Game.MW * Game.TS
	cam.limit_bottom = Game.MH * Game.TS
	cam.reset_smoothing()


func add_souls(n: int) -> void:
	souls += n


## Consuma stamina; ritorna false se esausto.
func spend(c: float) -> bool:
	if st <= 0.5:
		return false
	st = max(0.0, st - c * max(0.4, 1.0 - 0.06 * r("destr") - 0.015 * a("des")))
	st_delay = 0.75
	return true


func idle() -> bool:
	return atk_t <= 0.0 and atk_cd <= 0.0 and heavy_t <= 0.0 and dash_t <= 0.0 and drink_t <= 0.0


# ------------------------------------------------------------------ mezzi evocati (carro, carrarmato, ufo...)
## sali a bordo: il mezzo ha vita e tempo propri, i danni colpiscono lui finche' non esplode
func board(id: String) -> void:
	var d: Dictionary = Chrono.JACKPOT[id]
	if not veh.is_empty():
		veh_exit(false)
	var mh := float(d["hp"]) + float(d["hpl"]) * lv
	veh = {"id": id, "hp": mh, "max": mh, "t": float(d["t"]), "cd": 0.0, "cd2": 0.0, "crush": 0.0}
	z_index = 18 if id == "ufo" else 0   # l'ufo vola sopra alberi e muri
	inv = maxf(inv, 0.6)
	drink_t = 0.0
	heavy_t = 0.0
	main.burst(position, Color(0.6, 0.9, 1.0), 30, 80.0, 0.6)


func veh_spd() -> float:
	if veh.is_empty():
		return 1.0
	return float(Chrono.JACKPOT[veh["id"]]["spd"])


func veh_exit(boom: bool) -> void:
	if veh.is_empty():
		return
	veh = {}
	z_index = 0
	main.unstick(self, radius)
	inv = maxf(inv, 0.8)
	main.burst(position, Color(1.0, 0.6, 0.2), 40, 90.0, 0.6)
	if boom:
		for e in main.enemies.duplicate():
			if e.position.distance_to(position) < 50.0 + e.radius:
				e.hurt(bd() * 2.5, (e.position - position).normalized(), 160.0, true)
		shock(position, 50, Color(1.0, 0.6, 0.2))
		main.shake(6.0)
		main.snd("slam")
		main.say("IL MEZZO ESPLODE!")
	else:
		main.say("IL MEZZO SI DISSOLVE NELLA BOLLA")


## il mezzo incassa il danno al posto del personaggio; true se lo ha assorbito
func veh_absorb(d: float) -> bool:
	if veh.is_empty():
		return false
	veh["hp"] = float(veh["hp"]) - d
	flash = 0.1
	main.popup(position + Vector2(0, -18), "-%d" % int(round(d)), Color(1.0, 0.7, 0.3))
	if float(veh["hp"]) <= 0.0:
		veh_exit(true)
	return true


func veh_tick(dt: float) -> void:
	veh["t"] = float(veh["t"]) - dt
	if float(veh["t"]) <= 0.0:
		veh_exit(false)
		return
	var d: Dictionary = Chrono.JACKPOT[veh["id"]]
	veh["cd"] = float(veh["cd"]) - dt
	# speronamento: il peso del mezzo travolge i nemici a contatto
	if float(d.get("crush", 0.0)) > 0.0:
		veh["crush"] = float(veh["crush"]) - dt
		if float(veh["crush"]) <= 0.0:
			veh["crush"] = 0.4
			for e in main.enemies.duplicate():
				if e.position.distance_to(position) < 18.0 + e.radius:
					e.hurt(dmg() * float(d["crush"]), (e.position - position).normalized(), 170.0, false)
	veh["cd2"] = float(veh["cd2"]) - dt
	var id := str(veh["id"])
	var near: Enemy = main.nearest_enemy(position, 170.0)
	if act_held("attack") and float(veh["cd"]) <= 0.0 and not main.inv_open:
		if near != null and not bool(main.settings["aim_manual"]):
			face = (near.position - position).normalized()
		veh["cd"] = float(d["cd"])
		match id:
			"tank":    # mitragliatrice: raffica di proiettili rapidi
				var sp := randf_range(-0.09, 0.09)
				main.spawn_parrow(position + face * 16.0, face.rotated(sp), 360.0, dmg() * float(d["dm"]), 0.7, 1, Color(1.0, 0.9, 0.5), weapon(), 0.0, false)
				main.snd("swing")
			"ufo":     # raffica laser
				main.spawn_parrow(position + Vector2(0, -6), face.rotated(randf_range(-0.14, 0.14)), 300.0, dmg() * float(d["dm"]), 0.9, 0, Color(0.6, 0.95, 1.0), weapon(), 0.0, true)
				main.snd("swing")
			_:         # carro: balista perforante
				main.spawn_parrow(position + Vector2(0, -6), face, 300.0, dmg() * float(d["dm"]), 0.9, int(d.get("pr", 0)), Color(0.85, 0.7, 0.45), weapon(), 0.0, false)
				main.snd("swing")
	# arma secondaria dell'epoca (tasto colpo pesante): masso, cannonata, onda elettrica
	if act("heavy") and float(veh["cd2"]) <= 0.0:
		if near != null and not bool(main.settings["aim_manual"]):
			face = (near.position - position).normalized()
		veh["cd2"] = float(d["cd2"])
		match id:
			"carro":   # catapulta: masso lanciato, cade dopo un attimo sul nemico piu' vicino
				var tgt: Vector2 = near.position if near != null else position + face * 90.0
				Chrono.delayed(main, tgt, 0.7, 40.0, 4.0, Color(1.0, 0.75, 0.35))
				main.snd("swing")
			"tank":    # cannonata ad area
				main.spawn_parrow(position + face * 18.0, face, 280.0, dmg() * 3.5, 0.9, 0, Color(1.0, 0.8, 0.4), weapon(), 34.0, true)
				kb -= face * 80.0
				main.shake(3.0)
				main.snd("slam")
			"ufo":     # onda d'urto elettrica tutto intorno
				for e in main.enemies.duplicate():
					if e.position.distance_to(position) < 64.0 + e.radius:
						e.hurt(dmg() * 2.0, (e.position - position).normalized(), 120.0, true)
						e.stun = maxf(e.stun, 0.6)
				shock(position, 64, Color(0.6, 0.95, 1.0))
				main.burst(position, Color(0.6, 0.95, 1.0), 36, 90.0, 0.5)
				main.snd("slam")


func _veh_draw() -> void:
	var id := str(veh["id"])
	var tx: Texture2D = Game.tex("veh_" + id)
	var sz := tx.get_size()
	if id == "ufo":
		# il disco non ruota: ondeggia e fluttua
		draw_set_transform(Vector2(0, -12.0 + sin(t * 4.0) * 1.5), 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2(0, -5), face.angle(), Vector2.ONE)
	draw_texture(tx, -sz * 0.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var fr := clampf(float(veh["hp"]) / float(veh["max"]), 0.0, 1.0)
	draw_rect(Rect2(-9, -32, 18, 3), Color(0, 0, 0, 0.85))
	draw_rect(Rect2(-8, -31, 16.0 * fr, 1), Color(1.0, 0.6, 0.25))


func _process(dt: float) -> void:
	if main.state != "play":
		return
	riposta_cd -= dt
	if buffs.size() > 0:
		for bk in buffs.keys():
			buffs[bk] = float(buffs[bk]) - dt
			if float(buffs[bk]) <= 0.0:
				buffs.erase(bk)
				bval.erase(bk)
	var rgn := arm("rg") + bv("b_rg")
	if rgn > 0.0 and hp > 0.0:
		hp = minf(max_hp, hp + rgn * dt)
	parry_t -= dt
	parry_cd -= dt
	if act("parry") and parry_cd <= 0.0 and parry_t <= 0.0 and atk_t <= 0.0 and dash_t <= 0.0 and drink_t <= 0.0 and spend(10.0):
		parry_t = 0.26
		parry_cd = 0.75
		main.snd("swing")
	if main.run_mode:
		RunW.tick(self, dt)
	t += dt
	atk_t = max(0.0, atk_t - dt)
	atk_cd = max(0.0, atk_cd - dt)
	dash_cd = max(0.0, dash_cd - dt)
	inv = max(0.0, inv - dt)
	flash = max(0.0, flash - dt)
	slow_t = max(0.0, slow_t - dt)
	cast_t = max(0.0, cast_t - dt)
	combo_t -= dt
	if combo_t <= 0.0:
		combo = 0
	st_delay -= dt
	if st_delay <= 0.0:
		st = min(max_st, st + 38.0 * (1.0 + 0.15 * r("ritmo") + 0.02 * a("res")) * dt)
	mana = min(max_mana, mana + 1.3 * float(Rpg.CLASSES[cls]["regen"]) * (1.0 + 0.1 * r("mente") + 0.02 * a("int")) * dt)
	spell_cd[0] = max(0.0, spell_cd[0] - dt)
	spell_cd[1] = max(0.0, spell_cd[1] - dt)
	if shield_t > 0.0:
		shield_t -= dt
		if shield_t <= 0.0:
			shield = 0.0
	if regen_t > 0.0:
		regen_t -= dt
		hp = min(max_hp, hp + regen_rate * dt)
	var dir := Vector2.ZERO if main.inv_open else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if bool(main.settings["aim_manual"]):
		if act("lock"):
			cycle_lock()
		if lock != null and (not is_instance_valid(lock) or lock.dying or lock.position.distance_to(position) > 280.0):
			lock = null
	else:
		lock = null
	if bool(main.settings["aim_manual"]) and lock != null:
		face = (lock.position - position).normalized()
		aim_world = lock.position + Vector2(0, -8)
	elif bool(main.settings["aim_manual"]):
		if main.use_pad:
			var aim := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
			if aim.length() > 0.4:
				var strength := clampf((aim.length() - 0.4) / 0.6, 0.0, 1.0)
				var step := (1.5 + 3.5 * strength * strength) * dt
				face = Vector2.from_angle(face.angle() + clampf(angle_difference(face.angle(), aim.angle()), -step, step))
			aim_world = position + face * 80.0
		else:
			aim_world = get_global_mouse_position()
			var aim_delta: Vector2 = aim_world - position
			if aim_delta.length() > 4.0:
				face = aim_delta.normalized()
	else:
		aim_world = position + face * 80.0
	var free := atk_t <= 0.0 and dash_t <= 0.0 and heavy_t <= 0.0
	if dir.length() > 0.1 and free and not bool(main.settings["aim_manual"]):
		face = dir.normalized()
	# V / croce su cambia modalita' Orda/Tattica; U alterna lo zoom del mondo nella pelle 3D
	if act("zoom"):
		cycle_zoom()
	if act("camera_zoom") and main.state == "play" and main.area == "world" and main.skin is W3DSkin:
		(main.skin as W3DSkin).toggle_world_zoom()
	if zmode > 0 and main.area.begins_with("int|"):
		set_zmode(0)
	if zmode > 0:
		focus -= (5.0 if zmode == 1 else 3.0) * dt
		if focus <= 0.0:
			focus = 0.0
			set_zmode(0)
			main.say("CONCENTRAZIONE ESAURITA")
	else:
		focus = minf(MAX_FOCUS, focus + 2.5 * dt)
	var zt := ZOOM_FAR if zmode > 0 else 1.0
	var col = main.colossus
	if col != null and is_instance_valid(col) and not col.dead and col.state != "sleep":
		zt = minf(zt, 0.8)   # contro i colossi la visuale si allarga
	cam.zoom = cam.zoom.lerp(Vector2(zt, zt), 1.0 - exp(-dt * 7.0))
	if zmode == 1:
		auto_weapons(dt)
	elif zmode == 2:
		if act("attack"):
			var tp := position + face * 100.0
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				tp = get_global_mouse_position()
			main.order_rally(tp)
		if act("heavy"):
			main.order_follow()
	# cambio arma e magie
	if act("swap") and idle() and wslots[1 - wcur] != null:
		wcur = 1 - wcur
		refresh_weapon()
		main.snd("page")
		main.say("%s  [%s]" % [Rpg.wname(weapon()), Rpg.RARITY[int(weapon()["r"])]["n"]])
	if act("spell1"):
		cast(0)
	if act("spell2"):
		cast(1)
	# rotolata
	if act("dash") and dash_cd <= 0.0 and dash_t <= 0.0 and drink_t <= 0.0 and spend(22.0):
		dash_t = 0.28
		dash_cd = 0.35
		heavy_t = 0.0
		dash_dir = dir.normalized() if dir.length() > 0.1 else face
		inv = max(inv, 0.22 + 0.03 * r("agile") + 0.004 * a("des"))
		main.snd("roll")
		main.burst(position, Color(0.6, 0.55, 0.8), 8, 20.0, 0.3)
	# consumabili: Z cambia, X usa
	if act("item_next"):
		main.item_cycle()
	if act("item_use") and idle():
		main.item_use()
	# bolla spazio-temporale: un tasto, un oggetto a caso
	chrono = minf(Chrono.MAX_E, chrono + 0.6 * dt)
	if act("summon") and idle():
		main.summon()
	if not veh.is_empty():
		veh_tick(dt)
	# fiala
	if act("flask") and flasks > 0 and hp < max_hp and idle():
		drink_t = 0.85
	if drink_t > 0.0:
		drink_t -= dt
		if drink_t <= 0.0:
			flasks -= 1
			hp = min(max_hp, hp + 40.0 + 8.0 * r("elisir") + 2.5 * a("fed"))
			main.snd("drink")
			main.burst(position, Color(1.0, 0.7, 0.2), 14, 35.0, 0.6)
			main.popup(position + Vector2(0, -16), "+", Color(1, 0.8, 0.3))
	# attacchi
	var w := weapon()
	var f: Dictionary = Rpg.FAM[w["f"]]
	if (act_held("attack") or auto_fire(f)) and atk_cd <= 0.0 and idle() and st > 0.0 and zmode == 0 and veh.is_empty():
		attack()
	if act("heavy") and idle() and st > 0.0 and zmode == 0 and veh.is_empty() and spend(float(f["hc"]) * Rpg.st_mult(w)):
		heavy_t = f["hw"]
		var near: Enemy = main.nearest_enemy(position, 170.0 if f["ranged"] else 55.0)
		if near != null and not bool(main.settings["aim_manual"]):
			face = (near.position - position).normalized()
	if heavy_t > 0.0:
		heavy_t -= dt
		if heavy_t <= 0.0:
			main.snd("slam")
			big = true
			atk_dur = 0.3
			atk_t = 0.3
			atk_cd = float(f["hcd"]) * Rpg.cd_mult(w)
			if f["ranged"]:
				fire(w, f, true)
				main.world_strike(position, face, 27.0, 0.9, float(f["hm"]), str(w["f"]))
			else:
				cur_reach = float(f["reach"]) + 7.0 + Rpg.reach_add(w)
				cur_arc = float(f["arc"]) + 0.2
				strike(cur_reach, cur_arc, f["hm"], 190.0, true)
	var vel := Vector2.ZERO
	var rolling := dash_t > 0.0
	if rolling:
		dash_t -= dt
		vel = dash_dir * 185.0
	else:
		var slow := 1.0
		if atk_t > 0.0 or heavy_t > 0.0:
			slow = 0.3
		if drink_t > 0.0:
			slow = 0.35
		vel = dir * speed * slow * (1.0 + bv("b_mv")) * veh_spd()
	if slow_t > 0.0:
		vel *= 0.55
	vel += kb
	kb = kb.move_toward(Vector2.ZERO, 700.0 * dt)
	if veh.is_empty():
		main.move_body(self, vel * dt, radius)
	else:
		main.move_vehicle(self, vel * dt, radius, str(veh["id"]))
	if rolling:
		for p in main.props.duplicate():
			var to_prop: Vector2 = p.position - position
			if p.breakable and to_prop.length() < 22.0 and abs(angle_difference(dash_dir.angle(), to_prop.angle())) < 1.35:
				main.break_prop(p)
		main.world_strike(position, dash_dir, 16.0, 1.15, 1.0, "roll", true)
	var moving := dir.length() > 0.1
	spr.flip_h = face.x < 0.0
	spr.offset.y = -8.0 - (abs(sin(t * 12.0)) * 1.0 if moving else 0.0)
	var tintc := Color.WHITE
	if flash > 0.0:
		tintc = Color(3, 3, 3)
	elif drink_t > 0.0:
		tintc = Color(1.0, 0.8, 0.5)
	elif shield > 0.0:
		tintc = Color(0.8, 0.95, 1.4)
	elif cast_t > 0.0:
		tintc = Color(1.2, 1.1, 1.5)
	spr.self_modulate = tintc
	update_wspr()
	wspr.visible = veh.is_empty()
	spr.visible = veh.is_empty() and not (inv > 0.0 and inv < 0.4 and int(t * 20.0) % 2 == 0 and dash_t <= 0.0)
	if dash_t > 0.0:
		spr.modulate = Color(1, 1, 1, 0.55)
	else:
		spr.modulate = Color.WHITE
	light.energy = 1.7 + sin(t * 9.0) * 0.06
	slash.queue_redraw()
	queue_redraw()


func attack() -> void:
	var w := weapon()
	var f: Dictionary = Rpg.FAM[w["f"]]
	if not spend(float(f["lc"]) * Rpg.st_mult(w)):
		return
	main.snd("swing")
	var near: Enemy = main.nearest_enemy(position, 170.0 if f["ranged"] else 55.0)
	if near != null and not bool(main.settings["aim_manual"]):
		face = (near.position - position).normalized()
	var cdm := Rpg.cd_mult(w) / (1.0 + 0.07 * rl("corvo"))
	if main.run_mode and main.chain >= 5:
		cdm *= 0.87  # fervore: una serie lunga rende i colpi piu' rapidi
	if f["ranged"]:
		atk_dur = 0.18
		atk_t = atk_dur
		atk_cd = float(f["lcd"]) * cdm
		big = false
		fire(w, f, false)
		main.world_strike(position, face, 27.0, 0.9, float(f["lm"]), str(w["f"]))
		return
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 0.7
	big = combo >= 3
	if big:
		combo = 0
	atk_dur = 0.26 if big else 0.2
	atk_t = atk_dur
	atk_cd = float(f["lcd"]) * (1.45 if big else 1.0) * cdm
	kb += face * (110.0 if big else 60.0)
	cur_reach = float(f["reach"]) * (1.28 if big else 1.0) + Rpg.reach_add(w)
	cur_arc = float(f["arc"]) * (1.4 if big else 1.0)
	strike(cur_reach, cur_arc, float(f["lm"]) * (1.7 if big else 1.0), 150.0 if big else 95.0, false)


func fire(w: Dictionary, f: Dictionary, heavy: bool) -> void:
	if bool(f.get("mod", false)) and _fire_mod(w, f, heavy):
		return
	var magic: bool = str(w["f"]) == "staff"
	var col := Color(0.75, 0.5, 1.0) if magic else Color(0.95, 0.88, 0.6)
	var mult: float = float(f["hm"]) if heavy else float(f["lm"])
	var pr := 0
	var aoe := 0.0
	if heavy:
		pr = 5 if not magic else 0
		aoe = 26.0 if magic else 0.0
	var dirf := face
	if not magic:
		dirf = face.rotated(deg_to_rad(randf_range(-1.0, 1.0) * maxf(0.0, 6.0 - 0.4 * a("des")) * (0.5 if heavy else 1.0)))
	main.spawn_parrow(position + Vector2(0, -6), dirf, 270.0 if heavy else 230.0, dmg() * mult, 0.9, pr, col, w, aoe, magic)
	kb -= face * 30.0


## armi dal futuro a distanza: ognuna ha il suo colpo
func _fire_mod(w: Dictionary, f: Dictionary, heavy: bool) -> bool:
	var fam := str(w["f"])
	var mult: float = float(f["hm"]) if heavy else float(f["lm"])
	var d := dmg() * mult
	var o := position + Vector2(0, -6) + face * 8.0
	match fam:
		"pistol":
			main.spawn_parrow(o, face.rotated(randf_range(-0.03, 0.03)), 340.0, d, 0.8, 1 if heavy else 0, Color(1.0, 0.9, 0.55), w, 0.0, false)
			main.snd("swing")
		"smg":
			var n := 6 if heavy else 1
			for i in n:
				main.spawn_parrow(o, face.rotated(randf_range(-0.12, 0.12)), 330.0, d / (3.0 if heavy else 1.0), 0.7, 0, Color(1.0, 0.85, 0.45), w, 0.0, false)
			main.snd("swing")
		"shotgun":
			var pel := 9 if heavy else 6
			for i in pel:
				main.spawn_parrow(o, face.rotated(randf_range(-0.30, 0.30)), randf_range(240.0, 300.0), d / 3.0, 0.32, 1, Color(1.0, 0.8, 0.4), w, 0.0, false)
			kb -= face * (90.0 if heavy else 55.0)
			main.shake(2.5)
			main.snd("slam")
		"laserpistol":
			var sh := 3 if heavy else 1
			for i in sh:
				main.spawn_parrow(o, face.rotated((i - (sh - 1) * 0.5) * 0.12), 380.0, d / (1.5 if heavy else 1.0), 0.8, 2 if heavy else 0, Color(0.4, 0.95, 1.0), w, 0.0, true)
			main.snd("swing")
		"rocket":
			main.spawn_parrow(o, face, 190.0, d, 1.4, 0, Color(1.0, 0.6, 0.25), w, 44.0 if heavy else 34.0, true)
			kb -= face * 110.0
			main.shake(4.0)
			main.snd("slam")
		"plasma":
			main.spawn_parrow(o, face, 250.0, d, 1.0, 3 if heavy else 1, Color(0.55, 1.0, 0.5), w, 18.0 if heavy else 12.0, true)
			kb -= face * 35.0
			main.snd("swing")
		_:
			return false
	return true


func strike(reach: float, arc: float, mult: float, force: float, heavy: bool) -> void:
	reach += 3.0 * r("lama")
	var a0 := face.angle()
	var hit := false
	var w := weapon()
	for e in main.enemies.duplicate():
		var v: Vector2 = e.position - position
		if v.length() > reach + e.radius:
			continue
		if abs(angle_difference(a0, v.angle())) < arc:
			e.hurt(dmg() * mult, v.normalized(), force, heavy)
			on_hit(e, dmg() * mult, w)
			hit = true
	for cr in main.critters.duplicate():
		var vc: Vector2 = cr.position - position
		if vc.length() < reach + 6.0 and abs(angle_difference(a0, vc.angle())) < arc:
			cr.hurt(dmg() * mult, vc.normalized(), force, heavy)
	for p in main.props.duplicate():
		var v2: Vector2 = p.position - position
		if p.breakable and v2.length() < reach + 6.0 and abs(angle_difference(a0, v2.angle())) < arc:
			main.break_prop(p)
	main.world_strike(position, face, reach, arc, mult, str(w.get("f", "sword")))
	if hit:
		main.hitstop(0.06 if heavy else 0.03)
		main.shake(4.0 if heavy else 1.5)


## un fulmine salta dal nemico colpito al piu' vicino
func chain_from(e: Enemy, d: float) -> void:
	var best: Enemy = null
	var bd2 := 4900.0
	for t in main.enemies:
		if t != e and t.awake:
			var d2: float = t.position.distance_squared_to(e.position)
			if d2 < bd2:
				bd2 = d2
				best = t
	if best != null:
		best.hurt(d, (best.position - e.position).normalized(), 40.0, false)
		main.add_bolt(e.position + Vector2(0, -6), best.position + Vector2(0, -6))


## effetti degli affissi e mana per colpo a segno
func on_hit(e: Enemy, dealt: float, w: Dictionary) -> void:
	mana = min(max_mana, mana + 0.7)
	if buffs.has("fuoco") and randf() < 0.35:
		e.apply_status("burn", 3.0, dmg() * 0.22)
	if relics.size() > 0:
		if randf() < 0.10 * rl("brace"):
			e.apply_status("burn", 3.0, dmg() * 0.22)
		if randf() < 0.12 * rl("catena"):
			chain_from(e, dealt * 0.5)
	if w.is_empty():
		return
	for a in w["a"]:
		match a:
			"gelo":
				e.apply_status("slow", 2.0, 0.0)
			"fuoco":
				e.apply_status("burn", 3.0, dmg() * 0.22)
			"sangue":
				hp = min(max_hp, hp + dealt * 0.05)
			"veleno":
				e.apply_status("burn", 5.0, dmg() * 0.12)
			"tuono":
				if randf() < 0.25:
					chain_from(e, dealt * 0.5)


func cast(slot: int) -> void:
	var id: String = spells[slot]
	if id == "" or spell_cd[slot] > 0.0 or drink_t > 0.0 or dash_t > 0.0 or heavy_t > 0.0:
		return
	var sd: Dictionary = Rpg.SPELLS[id]
	if mana < float(sd["cost"]):
		main.say("MANA INSUFFICIENTE")
		return
	mana -= float(sd["cost"])
	spell_cd[slot] = float(sd["cd"])
	cast_t = 0.3
	var sp := spell_pow()
	var aim := face
	var near: Enemy = main.nearest_enemy(position, 170.0)
	if near != null and not bool(main.settings["aim_manual"]):
		aim = (near.position - position).normalized()
		face = aim
	match id:
		"dardo":
			main.spawn_parrow(position + Vector2(0, -6), aim, 210.0, bd() * 2.0 * sp, 0.9, 3, Color(0.7, 0.4, 1.0), {}, 0.0, true)
			main.snd("swing")
		"nova":
			for e in main.enemies.duplicate():
				if e.position.distance_to(position) < 58.0 + e.radius:
					e.hurt(bd() * 2.2 * sp, (e.position - position).normalized(), 130.0, false)
					e.apply_status("burn", 3.0, bd() * 0.25 * sp)
			main.burst(position, Color(1.0, 0.5, 0.15), 50, 95.0, 0.6)
			shock(position, 60, Color(1.0, 0.55, 0.2))
			shock(position, 40, Color(1.0, 0.85, 0.4))
			main.shake(3.0)
			main.snd("slam")
		"fulmine":
			var list: Array = main.enemies.duplicate()
			list.sort_custom(func(a, b): return a.position.distance_to(position) < b.position.distance_to(position))
			var n := 0
			var lightning_level := int(run_w.get("catena", 0))
			var targets := maxi(1, lightning_level)
			for e in list:
				if e.position.distance_to(position) > 150.0:
					break
				main.add_bolt(position + Vector2(0, -6), e.position + Vector2(0, -8))
				e.hurt(bd() * 1.8 * sp, (e.position - position).normalized(), 60.0, false)
				n += 1
				if n >= targets:
					break
			main.snd("roar" if n > 0 else "swing")
		"gelo":
			for e in main.enemies.duplicate():
				var v: Vector2 = e.position - position
				if v.length() < 72.0 and abs(angle_difference(aim.angle(), v.angle())) < 0.7:
					e.hurt(bd() * 1.2 * sp, v.normalized(), 40.0, false)
					e.apply_status("slow", 3.5, 0.0)
			main.burst(position + aim * 36.0, Color(0.6, 0.9, 1.0), 30, 60.0, 0.5)
			shock(position + aim * 36.0, 30, Color(0.6, 0.9, 1.0))
			main.snd("swing")
		"cura":
			for al in main.allies:
				al.heal(0.3)
			hp = min(max_hp, hp + max_hp * 0.24 * (0.8 + 0.2 * sp) * (1.0 + 0.03 * a("fed")))
			main.burst(position, Color(0.4, 1.0, 0.5), 24, 40.0, 0.6)
			main.popup(position + Vector2(0, -16), "+", Color(0.4, 1.0, 0.5))
			main.snd("drink")
		"rigenera":
			regen_t = 8.0
			regen_rate = max_hp * 0.2 * (0.8 + 0.2 * sp) * (1.0 + 0.03 * a("fed")) / 8.0
			main.burst(position, Color(0.4, 1.0, 0.5), 16, 30.0, 0.5)
			main.snd("drink")
		"scudo":
			shield = 30.0 * sp * (1.0 + 0.03 * a("fed")) + 2.0 * lv
			shield_t = 10.0
			main.burst(position, Color(0.7, 0.9, 1.0), 20, 40.0, 0.5)
			main.snd("bonfire")


## onda d'urto in pixel art degli incantesimi
func shock(pos: Vector2, r: int, c: Color) -> void:
	var s := Hazard.Shock.new()
	s.r = r
	s.c = c
	s.position = pos
	main.fx.add_child(s)


func _draw_slash() -> void:
	var nb := 0
	var brad := 30.0
	if main.run_mode:
		var ll := int(run_w.get("lame", 0))
		if ll > 0:
			nb = 1 + ll
			brad = 28.0 + 3.0 * ll
	elif zmode == 1:
		nb = mini(6, 2 + lv / 8)
	for i in nb:
		var a := blade_ang + i * TAU / nb
		var bp := Vector2(0, -4) + Vector2.from_angle(a) * brad
		var tg := Vector2.from_angle(a + 1.5708)
		var nrm := Vector2.from_angle(a)
		slash.draw_colored_polygon(PackedVector2Array([bp + tg * 7.0, bp + nrm * 2.2, bp - tg * 4.0, bp - nrm * 2.2]), Color(0.86, 0.9, 1.0))
		slash.draw_polyline(PackedVector2Array([bp + tg * 7.0, bp + nrm * 2.2, bp - tg * 4.0, bp - nrm * 2.2, bp + tg * 7.0]), Color(0.1, 0.08, 0.16), 1.0)
		slash.draw_line(bp - tg * 4.0, bp - tg * 11.0, Color(0.6, 0.75, 1.0, 0.5), 1.0)
	if heavy_t > 0.0:
		var k2 := 1.0 - heavy_t / maxf(0.2, float(Rpg.FAM[weapon()["f"]]["hw"]))
		slash.draw_circle(face * 14.0 + Vector2(0, -3), 2.0 + k2 * 5.0, Color(1, 0.5, 0.2, 0.35 + k2 * 0.4))
	if parry_t > 0.0:
		slash.draw_arc(Vector2(0, -4), 13.0, face.angle() - 1.1, face.angle() + 1.1, 14, Color(1.0, 0.9, 0.55, 0.9), 2.0)
	if shield > 0.0:
		slash.draw_arc(Vector2(0, -4), 11.0, 0.0, TAU, 24, Color(0.7, 0.9, 1.0, 0.5 + 0.2 * sin(t * 8.0)), 1.0)
	if atk_t <= 0.0 or Rpg.FAM[weapon()["f"]]["ranged"]:
		return
	var k := 1.0 - atk_t / atk_dur
	var a0 := face.angle()
	var arc := cur_arc
	var r_ := (cur_reach - 6.0) + 3.0 * r("lama")
	var rc: Color = Rpg.RARITY[int(weapon()["r"])]["c"]
	var cols: Array = [Color(1, 1, 1), Color(1, 0.55, 0.3) if big else rc.lightened(0.2), Color(0.55, 0.15, 0.3)]
	var ws: Array = [2.0, 4.0, 6.0]
	for i in range(2, -1, -1):
		var c: Color = cols[i]
		c.a = clamp((1.0 - k) * (1.0 - i * 0.25), 0.0, 1.0)
		var kk: float = min(1.0, k * 2.2)
		var from: float = a0 - arc + kk * arc * 0.5 * i
		var to: float = a0 - arc + kk * 2.0 * arc
		slash.draw_arc(Vector2(0, -3), r_, from, max(from + 0.01, to), 16, c, ws[i] * (1.3 if big else 1.0))


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 6.5 if veh.is_empty() else 15.0, Color(0, 0, 0, 0.5))
	if not veh.is_empty():
		_veh_draw()


## parata a tempo: annulla il colpo di un nemico, lo sbilancia e lo lascia scoperto
func try_parry(e: Enemy) -> bool:
	if parry_t <= 0.0:
		return false
	parry_t = 0.0
	parry_cd = 0.2
	e.tel = 0.0
	e.lunge = 0.0
	e.combo = 0
	e.stun = 1.0
	e.recover_t = maxf(e.recover_t, 1.4 if not e.is_boss else 1.1)
	e.kb = (e.position - position).normalized() * 150.0
	mana = min(max_mana, mana + 8.0)
	st = min(max_st, st + 14.0)
	main.popup(position + Vector2(0, -22), "PARATA!", Color(1.0, 0.9, 0.5))
	main.add_ring(position + face * 12.0, 24.0, Color(1.0, 0.9, 0.5))
	main.snd("level")
	main.hitstop(0.4)
	main.shake(3.0)
	return true


func hurt(d: float, dir: Vector2, slow := 0.0) -> void:
	if inv > 0.0 or main.state != "play":
		if main.state == "play" and dash_t > 0.0 and riposta_cd <= 0.0:
			main.riposta()
		return
	if slow > 0.0:
		slow_t = max(slow_t, slow)
	main.chain_break()
	d *= max(0.3, 1.0 - 0.05 * r("armor") - 0.006 * a("fed") - 0.025 * rl("pietra") - (0.2 if buffs.has("pelle") else 0.0) - arm("df") - bv("b_df"))
	if veh_absorb(d):
		inv = 0.3
		kb = dir * 60.0
		main.snd("hit")
		return
	if shield > 0.0:
		var ab := minf(shield, d)
		shield -= ab
		d -= ab
		main.popup(position + Vector2(0, -16), "ASSORBITO", Color(0.7, 0.9, 1.0))
		inv = 0.3
		if d <= 0.0:
			main.snd("hit")
			return
	hp -= d
	inv = 0.5
	flash = 0.12
	kb = dir * 120.0
	drink_t = 0.0
	st_delay = max(st_delay, 0.5)
	main.snd("hurt")
	main.shake(5.0)
	main.hitstop(0.06)
	main.burst(position, Color(0.8, 0.1, 0.15), 10, 50.0, 0.5)
	main.popup(position + Vector2(0, -16), "-%d" % int(round(d)), Color(1, 0.35, 0.35))
	if hp <= 0.0:
		main.game_over(false)


## danno continuo (nube velenosa): non da' invulnerabilita' ne' contraccolpo
func dot(d: float, slow := 0.0) -> void:
	if main.state != "play" or dash_t > 0.0:
		return
	d *= max(0.3, 1.0 - 0.05 * r("armor") - 0.006 * a("fed"))
	if veh_absorb(d):
		return
	if shield > 0.0:
		var ab := minf(shield, d)
		shield -= ab
		d -= ab
	hp -= d
	flash = 0.06
	if slow > 0.0:
		slow_t = max(slow_t, slow)
	if d > 0.0:
		main.popup(position + Vector2(0, -16), "-%d" % int(round(d)), Color(0.5, 1.0, 0.4))
	if hp <= 0.0:
		main.game_over(false)


## R3 / Y: aggancia il nemico piu' vicino; premuto di nuovo passa al successivo (dal piu' vicino al piu' lontano)
func cycle_lock() -> void:
	var list: Array = []
	for e in main.enemies:
		if is_instance_valid(e) and e.awake and not e.dying and e.kind != "camp_part" and e.position.distance_to(position) < 220.0:
			list.append(e)
	if list.is_empty():
		lock = null
		return
	list.sort_custom(func(a, b): return a.position.distance_to(position) < b.position.distance_to(position))
	var i := list.find(lock)
	lock = list[(i + 1) % list.size()]
	main.snd("page")


func cycle_zoom() -> void:
	if main.area.begins_with("int|") or main.state != "play":
		return
	var nz := (zmode + 1) % 3
	if nz == 1 and focus < 30.0:
		main.say("CONCENTRAZIONE INSUFFICIENTE")
		return
	set_zmode(nz)


func set_zmode(nz: int) -> void:
	if nz == zmode:
		return
	var old := zmode
	zmode = nz
	if old == 2:
		main.clear_allies()
	if old == 1:
		main.clear_horde()
	if nz == 2:
		main.spawn_allies()
		main.say("TATTICA: COLPO = INVIA GLI ALLEATI   PESANTE = RICHIAMA")
		main.snd("page")
	elif nz == 1:
		main.say("MODALITA ORDA: LE ARMI COLPISCONO DA SOLE")
		main.snd("roar")
	else:
		main.snd("page")


## armi automatiche della modalita' Orda: lame orbitanti e coltelli lanciati
func auto_weapons(dt: float) -> void:
	blade_ang += 3.2 * dt
	var n := mini(6, 2 + lv / 8)
	var w := weapon()
	var bdmg := bd() * 0.95
	if blade_hit.size() > 80:
		blade_hit.clear()
	for i in n:
		var a := blade_ang + i * TAU / n
		var bp := position + Vector2(0, -4) + Vector2.from_angle(a) * 30.0
		for e in main.enemies:
			if not e.awake:
				continue
			var rr: float = e.radius + 6.0
			if e.position.distance_squared_to(bp) < rr * rr:
				if t - float(blade_hit.get(e, -1.0)) > 0.3:
					blade_hit[e] = t
					e.hurt(bdmg, (e.position - position).normalized(), 80.0, false)
					on_hit(e, bdmg, w)
	knife_t -= dt
	if knife_t <= 0.0:
		var tg: Enemy = main.nearest_enemy(position, 230.0)
		if tg != null:
			knife_t = maxf(0.35, 0.8 - 0.01 * lv)
			var dirv := (tg.position - position).normalized()
			if bool(main.settings["aim_manual"]):
				dirv = face   # con la mira manuale i pugnali vanno dove punta il mirino
			var kn := mini(4, 1 + lv / 12)
			for k in kn:
				var off := (k - (kn - 1) * 0.5) * 0.2
				main.spawn_parrow(position + Vector2(0, -6), dirv.rotated(off), 240.0, bd() * 1.1, 0.9, 1, Color(0.92, 0.88, 0.62), w, 0.0, false)
