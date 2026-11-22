class_name W3DCombat
extends Node
## Demo giocabile del motore 3D: combattimento e sopravvivenza nel villaggio.
## I numeri vengono dal gioco 2D (vita 120, stamina 100, colpo leggero 18 st / pesante 34 / rotolata 22, danno base 10,
## nemici da enemy.gd). Le velocita' sono scalate come quella dell'eroe, cosi' i rapporti restano quelli di prima.
## Comandi: WASD muovi · SPAZIO/J/click colpo · L/click destro colpo pesante · SHIFT/K rotolata · Q fiala · E falo' · ESC esci.

const K := 1.68                  # fattore velocita' rispetto al 2D (82 px/s = 5,1 u/s -> 8,6 u/s)
const BASE_DMG := 10.0
const REACH := 2.4               # colpo leggero: 29 px nel 2D, piu' ampio per la camera lontana
const DEFS := {
	"goblin": {"hp": 26.0, "spd": 48.0, "dmg": 15.6, "rad": 0.5, "souls": 9, "ai": "melee", "wind": 0.45},
	"kobold": {"hp": 14.0, "spd": 56.0, "dmg": 10.4, "rad": 0.4, "souls": 4, "ai": "melee", "wind": 0.35},
	"skeleton": {"hp": 36.0, "spd": 38.0, "dmg": 20.8, "rad": 0.5, "souls": 12, "ai": "melee", "wind": 0.5},
	"orc": {"hp": 74.0, "spd": 40.0, "dmg": 31.0, "rad": 0.65, "souls": 24, "ai": "brute", "wind": 0.65},
	"ghoul": {"hp": 60.0, "spd": 44.0, "dmg": 31.0, "rad": 0.55, "souls": 20, "ai": "lunger", "wind": 0.5},
	"wolf": {"hp": 36.0, "spd": 66.0, "dmg": 21.0, "rad": 0.6, "souls": 14, "ai": "lunger", "wind": 0.4},
	"goblin_archer": {"hp": 24.0, "spd": 38.0, "dmg": 14.0, "rad": 0.5, "souls": 11, "ai": "archer", "wind": 0.45},
	"skel_archer": {"hp": 34.0, "spd": 32.0, "dmg": 18.0, "rad": 0.5, "souls": 15, "ai": "archer", "wind": 0.5},
}
const NEAR_KINDS := ["kobold", "kobold", "goblin", "goblin", "skeleton", "goblin_archer"]
const FAR_KINDS := ["skeleton", "ghoul", "orc", "wolf", "wolf", "skel_archer", "goblin_archer"]

var w: W3D
var w_dir := Vector2.ZERO
# eroe
var hp := 120.0
var max_hp := 120.0
var st := 100.0
var max_st := 100.0
var st_delay := 0.0
var flasks := 3
var souls := 0
var kills := 0
var inv := 0.0
var atk_t := 0.0
var atk_cd := 0.0
var combo := 0
var combo_t := 0.0
var heavy_t := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var drink_t := 0.0
var kb := Vector2.ZERO
var dead := false
var dead_t := 0.0
var respawn_pos := Vector2.ZERO
var t := 0.0
# mondo
var enemies: Array = []
var projs: Array = []
var fxs: Array = []
var boss: Dictionary = {}
var boss_dead := false
var spawn_t := 2.0
var prev: Dictionary = {}
var ring_mesh: ArrayMesh
var slash_mesh: ArrayMesh
var shard_mesh: ArrayMesh
var arrow_mesh: ArrayMesh
var msg := ""
var msg_t := 0.0
var shake := 0.0
var swing_t := 0.0
var swing_dur := 0.2
var swing_yaw := 0.8
var test := false
var test_shot := 0
# interfaccia
var ui: CanvasLayer
var bar_hp: ColorRect
var bar_st: ColorRect
var bar_boss: ColorRect
var bar_boss_bg: ColorRect
var lbl_info: Label
var lbl_obj: Label
var lbl_prompt: Label
var lbl_msg: Label
var lbl_boss: Label
var over: ColorRect
var lbl_dead: Label


func setup() -> void:
	test = OS.get_cmdline_user_args().has("--combattest")
	_make_meshes()
	_make_ui()
	reset_world()


func reset_world() -> void:
	for e in enemies:
		_free_enemy(e)
	enemies.clear()
	for p in projs:
		(p["node"] as Node3D).queue_free()
	projs.clear()
	boss = {}
	boss_dead = false
	hp = max_hp
	st = max_st
	flasks = 3
	souls = 0
	kills = 0
	dead = false
	inv = 0.5
	respawn_pos = w.pos
	_spawn_boss()
	say("SCONFIGGI IL CARCERIERE, FINO IN FONDO ALLA STRADA")


func _make_meshes() -> void:
	var b := W3DBuilder.new()
	for i in 28:
		var a0 := TAU * i / 28.0
		var a1 := TAU * (i + 1) / 28.0
		b.quad(Vector3(cos(a0) * 0.86, 0.06, sin(a0) * 0.86), Vector3(cos(a0), 0.06, sin(a0)), Vector3(cos(a1), 0.06, sin(a1)), Vector3(cos(a1) * 0.86, 0.06, sin(a1) * 0.86), Color(0.95, 0.25, 0.2, 0.12))
	ring_mesh = b.mesh()
	var s := W3DBuilder.new()
	# mezzaluna: spessa al centro, affilata alle punte; nucleo bianco e alone azzurro
	for i in 14:
		var u0 := -1.0 + 2.0 * i / 14.0
		var u1 := -1.0 + 2.0 * (i + 1) / 14.0
		var a0 := u0 * 0.75
		var a1 := u1 * 0.75
		var t0 := 0.34 * (1.0 - u0 * u0)
		var t1 := 0.34 * (1.0 - u1 * u1)
		s.quad(Vector3(sin(a0) * (1.0 - t0), 0.95, -cos(a0) * (1.0 - t0)), Vector3(sin(a0), 0.95, -cos(a0)), Vector3(sin(a1), 0.95, -cos(a1)), Vector3(sin(a1) * (1.0 - t1), 0.95, -cos(a1) * (1.0 - t1)), Color(0.55, 0.7, 1.0, 0.1))
		s.quad(Vector3(sin(a0) * (1.0 - t0 * 0.45), 0.97, -cos(a0) * (1.0 - t0 * 0.45)), Vector3(sin(a0) * 1.0, 0.97, -cos(a0)), Vector3(sin(a1) * 1.0, 0.97, -cos(a1)), Vector3(sin(a1) * (1.0 - t1 * 0.45), 0.97, -cos(a1) * (1.0 - t1 * 0.45)), Color(1.0, 1.0, 1.0, 0.0))
	slash_mesh = s.mesh()
	var sh := W3DBuilder.new()
	sh.shard(Vector3(0, 0, 0), Vector3(0, 0, -0.35), 0.06, 0.05, Color(0.9, 0.2, 0.18, 0.3), 0.4, 0.0, 0.0)
	shard_mesh = sh.mesh()
	var ar := W3DBuilder.new()
	ar.shard(Vector3(0, 0, 0.5), Vector3(0, 0, -0.5), 0.07, 0.04, Color(0.95, 0.85, 0.6, 0.2), 0.7, 0.0, 0.0)
	arrow_mesh = ar.mesh()


# ------------------------------------------------------------------ interfaccia
func _lbl(x: float, y: float, size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Game.font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.position = Vector2(x, y)
	ui.add_child(l)
	return l


func _bar(x: float, y: float, wd: float, h: float, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.position = Vector2(x - 1, y - 1)
	bg.size = Vector2(wd + 2, h + 2)
	ui.add_child(bg)
	var r := ColorRect.new()
	r.color = col
	r.position = Vector2(x, y)
	r.size = Vector2(wd, h)
	ui.add_child(r)
	return r


func _make_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 6
	w.add_child(ui)
	bar_hp = _bar(8, 8, 120, 8, Color(0.75, 0.12, 0.14))
	bar_st = _bar(8, 19, 100, 5, Color(0.25, 0.65, 0.3))
	lbl_info = _lbl(8, 27, 9, Color(0.95, 0.9, 0.75))
	lbl_obj = _lbl(0, 6, 9, Color(1.0, 0.85, 0.4))
	lbl_obj.size = Vector2(480, 12)
	lbl_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar_boss_bg = ColorRect.new()
	bar_boss_bg.color = Color(0, 0, 0, 0.75)
	bar_boss_bg.position = Vector2(119, 46)
	bar_boss_bg.size = Vector2(242, 8)
	bar_boss_bg.visible = false
	ui.add_child(bar_boss_bg)
	bar_boss = ColorRect.new()
	bar_boss.color = Color(0.7, 0.1, 0.1)
	bar_boss.position = Vector2(120, 47)
	bar_boss.size = Vector2(240, 6)
	bar_boss.visible = false
	ui.add_child(bar_boss)
	lbl_boss = _lbl(0, 56, 9, Color(0.95, 0.8, 0.8))
	lbl_boss.size = Vector2(480, 12)
	lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_boss.visible = false
	lbl_prompt = _lbl(0, 222, 9, Color(1.0, 0.95, 0.7))
	lbl_prompt.size = Vector2(480, 12)
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg = _lbl(0, 120, 12, Color(1.0, 0.9, 0.6))
	lbl_msg.size = Vector2(480, 16)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over = ColorRect.new()
	over.color = Color(0, 0, 0, 0)
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(over)
	lbl_dead = _lbl(0, 112, 26, Color(0.8, 0.12, 0.12))
	lbl_dead.size = Vector2(480, 30)
	lbl_dead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_dead.text = "SEI MORTO"
	lbl_dead.visible = false


func say(s: String) -> void:
	msg = s
	msg_t = 3.5


func _hud(dt: float) -> void:
	bar_hp.size.x = 120.0 * clampf(hp / max_hp, 0.0, 1.0)
	bar_st.size.x = 100.0 * clampf(st / max_st, 0.0, 1.0)
	lbl_info.text = "FIALE %d   ANIME %d   UCCISI %d" % [flasks, souls, kills]
	var bp: Vector2 = w.boss_pos
	var dist := bp.distance_to(w.pos)
	if boss_dead:
		lbl_obj.text = "CARCERIERE SCONFITTO - DEMO COMPLETATA"
	else:
		var d := (bp - w.pos).normalized()
		var dirn := "EST" if absf(d.x) > absf(d.y) and d.x > 0 else ("OVEST" if absf(d.x) > absf(d.y) else ("SUD" if d.y > 0 else "NORD"))
		lbl_obj.text = "SCONFIGGI IL CARCERIERE   %d m A %s" % [int(dist), dirn]
	var near_fire := _nearest_fire()
	lbl_prompt.text = "E   RIPOSA AL FALO'" if (near_fire < 3.4 and not dead) else ""
	msg_t -= dt
	lbl_msg.text = msg if msg_t > 0.0 else ""
	lbl_msg.modulate.a = clampf(msg_t, 0.0, 1.0)
	var show_boss := not boss.is_empty() and bool(boss["awake"]) and not boss_dead
	bar_boss.visible = show_boss
	bar_boss_bg.visible = show_boss
	lbl_boss.visible = show_boss
	if show_boss:
		bar_boss.size.x = 240.0 * clampf(float(boss["hp"]) / float(boss["max"]), 0.0, 1.0)
		lbl_boss.text = "IL CARCERIERE"
	over.color.a = lerpf(over.color.a, 0.78 if dead else 0.0, 1.0 - exp(-dt * 3.0))
	lbl_dead.visible = dead and dead_t > 0.6


func _nearest_fire() -> float:
	var best := 1e9
	for bp in w.bonfires:
		best = minf(best, (bp as Vector2).distance_to(w.pos))
	return best


# ------------------------------------------------------------------ ingressi
func _down() -> Dictionary:
	return {
		"attack": Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT),
		"heavy": Input.is_key_pressed(KEY_L) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT),
		"roll": Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_K),
		"use": Input.is_key_pressed(KEY_E),
		"flask": Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_F),
	}


func _spend(c: float) -> bool:
	if st <= 0.5:
		return false
	st = maxf(0.0, st - c)
	st_delay = 0.75
	return true


## spostamento dell'eroe in questo fotogramma (camminata, rotolata, contraccolpo)
func hero_step(dir: Vector2, dt: float) -> Vector2:
	if dead:
		return Vector2.ZERO
	var v := Vector2.ZERO
	if dash_t > 0.0:
		v = dash_dir * 11.6 * K
	else:
		var slow := 1.0
		if atk_t > 0.0 or heavy_t > 0.0:
			slow = 0.3
		if drink_t > 0.0:
			slow = 0.35
		v = dir * (82.0 / 16.0) * K * slow
	v += kb
	kb = kb.move_toward(Vector2.ZERO, 44.0 * dt)
	return v * dt


func free_turn() -> bool:
	return dash_t <= 0.0 and atk_t <= 0.0 and heavy_t <= 0.0 and not dead


# ------------------------------------------------------------------ aggiornamento
func update(dt: float) -> void:
	t += dt
	shake = maxf(0.0, shake - dt * 14.0)
	var dn := _down()
	var just := {}
	for k in dn:
		just[k] = bool(dn[k]) and not bool(prev.get(k, false))
	prev = dn
	if test:
		_selftest(just)
	if dead:
		dead_t += dt
		if dead_t > 3.0:
			_respawn()
	else:
		_hero(dt, dn, just)
	_enemies(dt)
	_projectiles(dt)
	_effects(dt)
	_spawner(dt)
	_hud(dt)
	w.shake = shake


func _hero(dt: float, dn: Dictionary, just: Dictionary) -> void:
	inv = maxf(0.0, inv - dt)
	atk_t = maxf(0.0, atk_t - dt)
	swing_t = maxf(0.0, swing_t - dt)
	atk_cd = maxf(0.0, atk_cd - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	combo_t = maxf(0.0, combo_t - dt)
	st_delay -= dt
	if st_delay <= 0.0:
		st = minf(max_st, st + 38.0 * dt)
	if dash_t > 0.0:
		dash_t -= dt
		w.facing = dash_dir
	var idle := atk_cd <= 0.0 and atk_t <= 0.0 and heavy_t <= 0.0 and dash_t <= 0.0 and drink_t <= 0.0
	if drink_t > 0.0:
		drink_t -= dt
		if drink_t <= 0.0:
			hp = minf(max_hp, hp + 40.0)
			flasks -= 1
			_popup(w.pos, "+40", Color(0.5, 1.0, 0.6))
			_burst(Vector3(w.pos.x, 1.2, w.pos.y), Color(0.9, 0.8, 0.3, 0.2), 10)
	if heavy_t > 0.0:
		heavy_t -= dt
		if heavy_t <= 0.0:
			_strike(REACH + 0.9, 1.15, BASE_DMG * 2.3, 9.0 * K, true)
			atk_t = 0.3
			atk_cd = 0.6
			_slash(REACH + 0.9, 1.15, true)
			shake = maxf(shake, 0.5)
	if bool(just["attack"]) and idle and st > 0.5 and _spend(18.0):
		_aim()
		combo = combo + 1 if combo_t > 0.0 else 1
		combo_t = 0.7
		var big := combo >= 3
		if big:
			combo = 0
		atk_t = 0.26 if big else 0.2
		atk_cd = 0.34 * (1.45 if big else 1.0)
		var reach := REACH * (1.28 if big else 1.0)
		var arc := 1.0 * (1.4 if big else 1.0)
		_strike(reach, arc, BASE_DMG * (1.7 if big else 1.0), 6.0 * K, false)
		_slash(reach, arc, big)
		kb += w.facing * (6.0 if big else 3.0)
	if bool(just["heavy"]) and idle and st > 0.5 and _spend(34.0):
		_aim()
		heavy_t = 0.38
	if bool(just["roll"]) and dash_cd <= 0.0 and dash_t <= 0.0 and drink_t <= 0.0 and _spend(22.0):
		dash_t = 0.28
		dash_cd = 0.35
		heavy_t = 0.0
		dash_dir = w_dir if w_dir.length() > 0.1 else w.facing
		dash_dir = dash_dir.normalized()
		inv = maxf(inv, 0.22)
		_burst(Vector3(w.pos.x, 0.3, w.pos.y), Color(0.6, 0.55, 0.8, 0.2), 6)
	if bool(just["flask"]) and idle and flasks > 0 and hp < max_hp - 1.0:
		drink_t = 0.85
	if bool(just["use"]) and _nearest_fire() < 3.4:
		_rest()
	# lampeggio mentre e' invulnerabile
	w.hero.visible = not (inv > 0.0 and inv < 0.4 and int(t * 20.0) % 2 == 0 and dash_t <= 0.0)


func _aim() -> void:
	var best = null
	var bd := 5.0
	for e in enemies:
		var d: float = (e["pos"] as Vector2).distance_to(w.pos)
		if d < bd:
			bd = d
			best = e
	if best != null:
		w.facing = ((best["pos"] as Vector2) - w.pos).normalized()
	elif w_dir.length() > 0.1:
		w.facing = w_dir


func _rest() -> void:
	hp = max_hp
	st = max_st
	flasks = 3
	respawn_pos = _nearest_fire_pos()
	for e in enemies:
		_free_enemy(e)
	enemies.clear()
	spawn_t = 3.0
	_burst(Vector3(w.pos.x, 1.0, w.pos.y), Color(1.0, 0.8, 0.45, 0.2), 14)
	say("TI RIPOSI AL FALO'. I NEMICI TORNANO")


func _nearest_fire_pos() -> Vector2:
	var best := w.pos
	var bd := 1e9
	for bp in w.bonfires:
		var d := (bp as Vector2).distance_to(w.pos)
		if d < bd:
			bd = d
			best = bp
	return best + Vector2(0, 2.4)


func _respawn() -> void:
	dead = false
	dead_t = 0.0
	hp = max_hp
	st = max_st
	flasks = 3
	souls = 0
	w.pos = respawn_pos
	kb = Vector2.ZERO
	inv = 1.0
	for e in enemies:
		_free_enemy(e)
	enemies.clear()
	spawn_t = 3.0
	say("TI RISVEGLI AL FALO'")


func hurt(d: float, dir: Vector2) -> void:
	if inv > 0.0 or dead:
		return
	hp -= d
	inv = 0.5
	kb = dir * 120.0 / 16.0 * K * 0.6
	drink_t = 0.0
	st_delay = maxf(st_delay, 0.5)
	shake = maxf(shake, 1.0)
	_popup(w.pos, "-%d" % int(round(d)), Color(1.0, 0.4, 0.4))
	_burst(Vector3(w.pos.x, 1.2, w.pos.y), Color(0.75, 0.1, 0.14, 0.3), 9)
	if hp <= 0.0:
		dead = true
		dead_t = 0.0
		hp = 0.0


# ------------------------------------------------------------------ colpi dell'eroe
func _strike(reach: float, arc: float, d: float, force: float, heavy: bool) -> void:
	var a0 := w.facing.angle()
	for e in enemies.duplicate():
		var v: Vector2 = (e["pos"] as Vector2) - w.pos
		if v.length() > reach + float(e["rad"]):
			continue
		if absf(angle_difference(a0, v.angle())) > arc:
			continue
		_hit_enemy(e, d, v.normalized(), force, heavy)


func _hit_enemy(e: Dictionary, d: float, dir: Vector2, force: float, heavy: bool) -> void:
	var crit := randf() < 0.06
	if crit:
		d *= 2.0
	if e.get("boss", false) and float(e["recover"]) > 0.0:
		d *= 1.25
	e["hp"] = float(e["hp"]) - d
	e["flash"] = 0.12
	e["awake"] = true
	var kbm := 0.2 if e.get("boss", false) else 1.0
	e["kb"] = dir * force * kbm
	if not e.get("boss", false):
		if heavy:
			e["stun"] = 0.55
			e["state"] = "move"
			e["ring"].visible = false
		elif e["state"] == "move":
			e["stun"] = 0.18
	_popup((e["pos"] as Vector2), str(int(round(d))) + ("!" if crit else ""), Color(1, 0.85, 0.35) if crit else Color(1, 1, 1))
	_burst(Vector3((e["pos"] as Vector2).x, 1.0, (e["pos"] as Vector2).y), Color(0.75, 0.15, 0.3, 0.3), 6)
	shake = maxf(shake, 0.6 if heavy else 0.25)
	if float(e["hp"]) <= 0.0 and not bool(e["dying"]):
		_kill_enemy(e)


func _kill_enemy(e: Dictionary) -> void:
	e["dying"] = true
	kills += 1
	var p: Vector2 = e["pos"]
	for i in clampi(int(e["souls"]) / 4, 1, 6):
		_soul(p, maxi(1, int(e["souls"]) / clampi(int(e["souls"]) / 4, 1, 6)))
	_burst(Vector3(p.x, 0.8, p.y), Color(0.6, 0.55, 0.65, 0.3), 12)
	if e.get("boss", false):
		boss_dead = true
		say("IL CARCERIERE E' CADUTO. DEMO COMPLETATA!")
		shake = 3.0
	enemies.erase(e)
	_free_enemy(e)


func _slash(reach: float, arc: float, big: bool) -> void:
	var yaw := atan2(-w.facing.x, -w.facing.y)
	var sweep := maxf(0.2, arc * 0.9 - 0.2)
	for q in 2:
		var n := MeshInstance3D.new()
		n.mesh = slash_mesh
		n.material_override = w.mat
		n.position = Vector3(w.pos.x, 0.0, w.pos.y)
		var sc := reach * (1.0 if q == 0 else 0.82)
		n.scale = Vector3(sc, 1.0, sc)
		n.rotation.y = yaw - sweep
		w.vp.add_child(n)
		fxs.append({"node": n, "t": 0.0, "life": (0.2 if not big else 0.28), "kind": "slash", "yaw": yaw, "sweep": sweep, "lag": 0.0 if q == 0 else 0.18, "base": n.scale})
	swing_dur = 0.2 if not big else 0.28
	swing_t = swing_dur
	swing_yaw = sweep


## rotazione del corpo durante il fendente: la spada tenuta a destra spazza davanti all'eroe
func swing_offset() -> float:
	if heavy_t > 0.0:
		return -1.3 * clampf(1.0 - heavy_t / 0.38, 0.0, 1.0)   # carica: porta la spada indietro a destra
	if swing_t > 0.0:
		var k := 1.0 - swing_t / swing_dur
		return lerpf(-swing_yaw, swing_yaw, k * k * (3.0 - 2.0 * k))
	return 0.0


# ------------------------------------------------------------------ nemici
func _spawn_boss() -> void:
	var p: Vector2 = w.boss_pos
	var nd := w._vox_node("orc", 0.075)
	nd.scale = Vector3.ONE * 1.9
	nd.position = Vector3(p.x, 0, p.y)
	var ring := _make_ring(4.4)
	boss = {"kind": "orc", "node": nd, "pos": p, "hp": 700.0, "max": 700.0, "spd": 38.0, "dmg": 34.0, "rad": 1.4, "souls": 400,
		"ai": "boss", "state": "idle", "t": 0.0, "cd": 2.0, "kb": Vector2.ZERO, "stun": 0.0, "dir": Vector2.ZERO, "ring": ring,
		"flash": 0.0, "awake": false, "dying": false, "boss": true, "recover": 0.0, "dash": Vector2.ZERO, "hit": false, "pattern": 0, "base_scale": 1.9}
	enemies.append(boss)


func _make_ring(radius: float) -> MeshInstance3D:
	var r := MeshInstance3D.new()
	r.mesh = ring_mesh
	r.material_override = w.mat
	r.scale = Vector3(radius, 1.0, radius)
	r.visible = false
	w.vp.add_child(r)
	return r


func _free_enemy(e: Dictionary) -> void:
	if e.get("boss", false) and not bool(e["dying"]):
		return
	if is_instance_valid(e["node"]):
		(e["node"] as Node3D).queue_free()
	if is_instance_valid(e["ring"]):
		(e["ring"] as Node3D).queue_free()


func _spawner(dt: float) -> void:
	spawn_t -= dt
	if spawn_t > 0.0 or dead:
		return
	spawn_t = 1.6
	var count := 0
	for e in enemies:
		if not e.get("boss", false):
			count += 1
	if count >= 11:
		return
	var ang := randf() * TAU
	var q := w.pos + Vector2.from_angle(ang) * randf_range(24.0, 36.0)
	if w._blocked(q, 0.8) or q.distance_to(_nearest_fire_pos()) < 12.0:
		return
	var far := q.distance_to(Vector2(0, 0)) / 90.0
	var pool: Array = FAR_KINDS if randf() < clampf(far, 0.1, 0.85) else NEAR_KINDS
	_spawn_enemy(str(pool[randi() % pool.size()]), q)


func _spawn_enemy(kind: String, p: Vector2) -> void:
	var d: Dictionary = DEFS[kind]
	var nd := w._vox_node(kind, 0.075)
	nd.position = Vector3(p.x, 0, p.y)
	var ring := _make_ring(2.6)
	enemies.append({"kind": kind, "node": nd, "pos": p, "hp": float(d["hp"]), "max": float(d["hp"]), "spd": float(d["spd"]), "dmg": float(d["dmg"]),
		"rad": float(d["rad"]), "souls": int(d["souls"]), "ai": str(d["ai"]), "wind": float(d["wind"]), "state": "move", "t": 0.0, "cd": randf_range(0.5, 1.5),
		"kb": Vector2.ZERO, "stun": 0.0, "dir": Vector2.from_angle(randf() * TAU), "ring": ring, "flash": 0.0, "awake": false, "dying": false,
		"boss": false, "recover": 0.0, "dash": Vector2.ZERO, "hit": false, "wt": randf() * 6.0, "base_scale": 1.0})


func _move_enemy(e: Dictionary, v: Vector2, dt: float) -> void:
	var p: Vector2 = e["pos"]
	var rad: float = e["rad"]
	var st2 := v * dt
	if not w._blocked(p + Vector2(st2.x, 0), rad * 0.8):
		p.x += st2.x
	if not w._blocked(p + Vector2(0, st2.y), rad * 0.8):
		p.y += st2.y
	e["pos"] = p


func _enemies(dt: float) -> void:
	for e in enemies.duplicate():
		if bool(e["dying"]):
			continue
		var p: Vector2 = e["pos"]
		var to: Vector2 = w.pos - p
		var dist := to.length()
		var u := to / maxf(dist, 0.001)
		e["flash"] = maxf(0.0, float(e["flash"]) - dt)
		e["cd"] = float(e["cd"]) - dt
		e["recover"] = maxf(0.0, float(e["recover"]) - dt)
		var spd: float = float(e["spd"]) / 16.0 * K
		# contraccolpo
		var kbv: Vector2 = e["kb"]
		if kbv.length() > 0.05:
			_move_enemy(e, kbv, dt)
			e["kb"] = kbv.move_toward(Vector2.ZERO, 40.0 * dt)
		if float(e["stun"]) > 0.0:
			e["stun"] = float(e["stun"]) - dt
		else:
			_enemy_ai(e, dt, dist, u, spd)
		_enemy_visual(e, dt, u)
		if dist > w.fade_a + 12.0 and not e.get("boss", false):
			enemies.erase(e)
			_free_enemy(e)


func _enemy_ai(e: Dictionary, dt: float, dist: float, u: Vector2, spd: float) -> void:
	var ai: String = e["ai"]
	var rad: float = e["rad"]
	if not bool(e["awake"]):
		var aggro := 26.0 if ai == "boss" else (13.0 if e["kind"] == "wolf" else 10.5)
		if dist < aggro:
			e["awake"] = true
			if ai == "boss":
				e["state"] = "move"
				say("IL CARCERIERE SI DESTA")
		else:
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["t"] = randf_range(1.0, 3.0)
				e["dir"] = Vector2.from_angle(randf() * TAU) if randf() < 0.7 else Vector2.ZERO
			_move_enemy(e, (e["dir"] as Vector2) * spd * 0.3, dt)
			return
	if dead:
		return
	match ai:
		"melee", "brute":
			_ai_melee(e, dt, dist, u, spd, 2.1 if ai == "melee" else 2.6, ai == "brute")
		"lunger":
			_ai_lunger(e, dt, dist, u, spd)
		"archer":
			_ai_archer(e, dt, dist, u, spd)
		"boss":
			_ai_boss(e, dt, dist, u, spd)


func _sep(e: Dictionary, dist: float, u: Vector2, dt: float) -> void:
	var min_d := float(e["rad"]) + 0.5
	if dist < min_d:
		_move_enemy(e, -u * 3.0, dt)


func _ai_melee(e: Dictionary, dt: float, dist: float, u: Vector2, spd: float, reach: float, brute: bool) -> void:
	match str(e["state"]):
		"move":
			if dist > reach * 0.85:
				_move_enemy(e, u * spd, dt)
			else:
				_sep(e, dist, u, dt)
			if dist < reach * 0.95 and float(e["cd"]) <= 0.0:
				e["state"] = "wind"
				e["t"] = float(e["wind"])
				e["dir"] = u
				(e["ring"] as Node3D).visible = true
		"wind":
			e["t"] = float(e["t"]) - dt
			(e["ring"] as Node3D).position = Vector3((e["pos"] as Vector2).x, 0.0, (e["pos"] as Vector2).y)
			(e["ring"] as Node3D).scale = Vector3.ONE * reach * 1.1 * (1.0 + 0.1 * sin(t * 30.0))
			if float(e["t"]) <= 0.0:
				(e["ring"] as Node3D).visible = false
				if dist < reach + 0.6:
					hurt(float(e["dmg"]), u)
				e["state"] = "recover"
				e["t"] = 0.55
				e["cd"] = 1.5 if not brute else 2.0
				_burst(Vector3((e["pos"] as Vector2).x + u.x, 1.0, (e["pos"] as Vector2).y + u.y), Color(0.9, 0.9, 0.9, 0.3), 5)
		"recover":
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["state"] = "move"


func _ai_lunger(e: Dictionary, dt: float, dist: float, u: Vector2, spd: float) -> void:
	match str(e["state"]):
		"move":
			if dist > 5.0:
				_move_enemy(e, u * spd, dt)
			else:
				var side: Vector2 = u.orthogonal() * (1.0 if int(e.get("wt", 0.0) * 3.0) % 2 == 0 else -1.0)
				_move_enemy(e, (u * 0.2 + side) * spd * 0.7, dt)
			_sep(e, dist, u, dt)
			if dist < 6.5 and dist > 1.6 and float(e["cd"]) <= 0.0:
				e["state"] = "wind"
				e["t"] = float(e["wind"])
				e["dir"] = u
				(e["ring"] as Node3D).visible = true
		"wind":
			e["t"] = float(e["t"]) - dt
			e["dir"] = u
			(e["ring"] as Node3D).position = Vector3((e["pos"] as Vector2).x, 0.0, (e["pos"] as Vector2).y)
			(e["ring"] as Node3D).scale = Vector3.ONE * (1.4 + 0.15 * sin(t * 30.0))
			if float(e["t"]) <= 0.0:
				(e["ring"] as Node3D).visible = false
				e["state"] = "lunge"
				e["t"] = 0.3
				e["hit"] = false
		"lunge":
			e["t"] = float(e["t"]) - dt
			_move_enemy(e, (e["dir"] as Vector2) * spd * 3.4, dt)
			if not bool(e["hit"]) and dist < float(e["rad"]) + 0.85:
				e["hit"] = true
				hurt(float(e["dmg"]), e["dir"])
			if float(e["t"]) <= 0.0:
				e["state"] = "recover"
				e["t"] = 0.8
				e["cd"] = 1.7
		"recover":
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["state"] = "move"


func _ai_archer(e: Dictionary, dt: float, dist: float, u: Vector2, spd: float) -> void:
	match str(e["state"]):
		"move":
			var side: Vector2 = u.orthogonal() * (1.0 if int(float(e["wt"]) * 2.0) % 2 == 0 else -1.0)
			if dist < 6.0:
				_move_enemy(e, (-u + side * 0.4) * spd, dt)
			elif dist > 10.0:
				_move_enemy(e, u * spd, dt)
			else:
				_move_enemy(e, side * spd * 0.5, dt)
			if dist < 13.0 and float(e["cd"]) <= 0.0:
				e["state"] = "wind"
				e["t"] = float(e["wind"])
		"wind":
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				_fire(e, u)
				e["state"] = "recover"
				e["t"] = 0.5
				e["cd"] = 2.2
		"recover":
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["state"] = "move"


func _fire(e: Dictionary, u: Vector2) -> void:
	var nd := MeshInstance3D.new()
	nd.mesh = arrow_mesh
	nd.material_override = w.mat
	var p: Vector2 = e["pos"]
	nd.position = Vector3(p.x, 1.1, p.y)
	nd.rotation.y = atan2(-u.x, -u.y)
	w.vp.add_child(nd)
	projs.append({"node": nd, "pos": p, "vel": u * 11.5, "dmg": float(e["dmg"]), "life": 3.2})


func _ai_boss(e: Dictionary, dt: float, dist: float, u: Vector2, spd: float) -> void:
	var ring := e["ring"] as Node3D
	match str(e["state"]):
		"idle":
			pass
		"move":
			if dist > 3.6:
				_move_enemy(e, u * spd, dt)
			else:
				_sep(e, dist, u, dt)
			if float(e["cd"]) <= 0.0:
				var pat := int(e["pattern"])
				e["pattern"] = pat + 1
				if pat % 2 == 0:
					e["state"] = "charge_wind"
					e["t"] = 0.85
					e["dir"] = u
				else:
					e["state"] = "slam_wind"
					e["t"] = 1.0
				ring.visible = true
		"charge_wind":
			e["t"] = float(e["t"]) - dt
			e["dir"] = u
			ring.position = Vector3((e["pos"] as Vector2).x, 0.0, (e["pos"] as Vector2).y)
			ring.scale = Vector3.ONE * (2.0 + 0.2 * sin(t * 28.0))
			if float(e["t"]) <= 0.0:
				ring.visible = false
				e["state"] = "charge"
				e["t"] = 0.5
				e["hit"] = false
		"charge":
			e["t"] = float(e["t"]) - dt
			_move_enemy(e, (e["dir"] as Vector2) * 15.0, dt)
			if not bool(e["hit"]) and dist < float(e["rad"]) + 0.9:
				e["hit"] = true
				hurt(float(e["dmg"]), e["dir"])
			if float(e["t"]) <= 0.0:
				e["state"] = "recover"
				e["t"] = 1.1
				e["recover"] = 1.1
				e["cd"] = 1.3
		"slam_wind":
			e["t"] = float(e["t"]) - dt
			ring.position = Vector3((e["pos"] as Vector2).x, 0.0, (e["pos"] as Vector2).y)
			ring.scale = Vector3.ONE * (4.6 * (1.0 - float(e["t"]) * 0.2) + 0.15 * sin(t * 30.0))
			if float(e["t"]) <= 0.0:
				ring.visible = false
				if dist < 4.6 + 0.4:
					hurt(float(e["dmg"]) * 0.9, u)
				shake = 2.5
				_burst(Vector3((e["pos"] as Vector2).x, 0.4, (e["pos"] as Vector2).y), Color(0.7, 0.65, 0.6, 0.3), 18)
				e["state"] = "recover"
				e["t"] = 1.0
				e["recover"] = 1.0
				e["cd"] = 1.4
		"recover":
			e["t"] = float(e["t"]) - dt
			if float(e["t"]) <= 0.0:
				e["state"] = "move"


func _enemy_visual(e: Dictionary, dt: float, u: Vector2) -> void:
	var nd := e["node"] as Node3D
	var p: Vector2 = e["pos"]
	nd.position = Vector3(p.x, w._height(p, 3.0), p.y)
	var moving := str(e["state"]) in ["move", "charge", "lunge"] and bool(e["awake"])
	var face: Vector2 = u if bool(e["awake"]) else (e["dir"] as Vector2)
	if face.length() > 0.1:
		nd.rotation.y = lerp_angle(nd.rotation.y, atan2(-face.x, -face.y), 1.0 - exp(-10.0 * dt))
	e["wt"] = float(e.get("wt", 0.0)) + dt * (9.0 if moving else 1.0)
	var bs: float = e["base_scale"]
	var pulse := 1.0 + float(e["flash"]) * 1.2
	if str(e["state"]) in ["wind", "charge_wind", "slam_wind"]:
		pulse += 0.06 * sin(t * 40.0)
	nd.scale = Vector3.ONE * bs * pulse
	(nd.get_child(0) as Node3D).position.y = absf(sin(float(e["wt"]))) * 0.06 if moving else 0.0
	w._flow_anim(nd, 1.0 if moving else 0.0, t + float(e["wt"]))


# ------------------------------------------------------------------ proiettili ed effetti
func _projectiles(dt: float) -> void:
	for pr in projs.duplicate():
		pr["life"] = float(pr["life"]) - dt
		var p: Vector2 = pr["pos"]
		p += (pr["vel"] as Vector2) * dt
		pr["pos"] = p
		var nd := pr["node"] as Node3D
		nd.position = Vector3(p.x, 1.1, p.y)
		var gone: bool = float(pr["life"]) <= 0.0 or w._blocked(p, 0.1)
		if not gone and not dead and p.distance_to(w.pos) < 0.75:
			hurt(float(pr["dmg"]), (pr["vel"] as Vector2).normalized())
			gone = true
		if gone:
			nd.queue_free()
			projs.erase(pr)


func _soul(p: Vector2, value: int) -> void:
	var n := MeshInstance3D.new()
	n.mesh = shard_mesh
	n.material_override = w.mat
	n.position = Vector3(p.x, 0.6, p.y)
	w.vp.add_child(n)
	fxs.append({"node": n, "t": 0.0, "life": 5.0, "kind": "soul", "pos": p + Vector2.from_angle(randf() * TAU) * randf_range(0.3, 1.3), "value": value, "h": 0.6})


func _burst(p: Vector3, col: Color, n: int) -> void:
	for i in n:
		var nd := MeshInstance3D.new()
		nd.mesh = shard_mesh
		nd.material_override = w.mat
		nd.position = p
		nd.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
		nd.scale = Vector3.ONE * randf_range(0.5, 1.0)
		w.vp.add_child(nd)
		var a := randf() * TAU
		fxs.append({"node": nd, "t": 0.0, "life": randf_range(0.3, 0.55), "kind": "burst", "vel": Vector3(cos(a) * randf_range(1.5, 4.5), randf_range(1.0, 3.5), sin(a) * randf_range(1.5, 4.5))})


func _popup(p: Vector2, s: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = s
	l.font = Game.font()
	l.font_size = 40
	l.pixel_size = 0.014
	l.modulate = col
	l.outline_size = 10
	l.no_depth_test = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(p.x, 2.6, p.y)
	w.vp.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", 4.2, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.tween_callback(l.queue_free)


func _effects(dt: float) -> void:
	for f in fxs.duplicate():
		f["t"] = float(f["t"]) + dt
		var nd := f["node"] as Node3D
		var k: float = float(f["t"]) / float(f["life"])
		match str(f["kind"]):
			"slash":
				var ease := clampf(k - float(f["lag"]), 0.0, 1.0)
				ease = ease * ease * (3.0 - 2.0 * ease)
				nd.rotation.y = float(f["yaw"]) + lerpf(-float(f["sweep"]), float(f["sweep"]), ease)
				var bs: Vector3 = f["base"]
				nd.scale = Vector3(bs.x, 1.0 - k * k, bs.z) * (1.0 + 0.12 * k)
			"burst":
				var v: Vector3 = f["vel"]
				v.y -= 9.0 * dt
				f["vel"] = v
				nd.position += v * dt
				nd.scale = nd.scale * (1.0 - dt * 2.0)
			"soul":
				if float(f["t"]) < 0.5:
					var sp: Vector2 = f["pos"]
					nd.position = nd.position.lerp(Vector3(sp.x, 0.5 + sin(float(f["t"]) * 8.0) * 0.1, sp.y), 1.0 - exp(-dt * 6.0))
				else:
					var tgt := Vector3(w.pos.x, 1.0, w.pos.y)
					nd.position = nd.position.move_toward(tgt, dt * (6.0 + float(f["t"]) * 10.0))
					if nd.position.distance_to(tgt) < 0.5:
						souls += int(f["value"])
						nd.queue_free()
						fxs.erase(f)
						continue
				nd.rotation.y += dt * 8.0
		if k >= 1.0:
			nd.queue_free()
			fxs.erase(f)


## prova automatica: l'eroe attacca da solo contro goblin, scheletro e arciere
func _selftest(just: Dictionary) -> void:
	if t > 1.0 and t - get_process_delta_time() <= 1.0:
		_spawn_enemy("goblin", w.pos + Vector2(4, 0))
		_spawn_enemy("skeleton", w.pos + Vector2(-4, 2))
		_spawn_enemy("skel_archer", w.pos + Vector2(0, -9))
		_spawn_enemy("wolf", w.pos + Vector2(6, 6))
		for e in enemies:
			e["awake"] = true
	if t > 1.0 and fmod(t, 0.55) < get_process_delta_time():
		just["attack"] = true
	if t > 4.0 and fmod(t, 3.0) < get_process_delta_time():
		just["roll"] = true
	if fmod(t, 1.0) < get_process_delta_time():
		print("COMBAT t=", snappedf(t, 0.1), " hp=", int(hp), " st=", int(st), " nemici=", enemies.size(), " uccisi=", kills, " anime=", souls, " morto=", dead)
	if t > 1.1 and test_shot < 4 and Engine.get_process_frames() % 3 == 0:
		get_viewport().get_texture().get_image().save_png("user://combat_s%d.png" % test_shot)
		test_shot += 1
	if t > 3.2 and test_shot == 99:
		test_shot = 1
		get_viewport().get_texture().get_image().save_png("user://combat_a.png")
	if t > 14.0:
		get_viewport().get_texture().get_image().save_png("user://combat_b.png")
		get_tree().quit()
