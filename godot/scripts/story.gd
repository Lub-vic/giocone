class_name Story
extends RefCounted
## Eventi di storia: si svolgono una sola volta, in ordine, e creano urgenze che bloccano il resto del gioco.
## Ogni evento e' una "flag" salvata in persist["flags"] (finita = true). Le cose bloccate controllano la flag.
##
## 1. IL CARCERIERE   (gia' nel gioco)  - dalle Celle si esce solo sconfiggendo il carceriere
## 2. VILLAGGIO INVASO                  - il falo' del villaggio e' spento e l'anziano si nasconde finche' i mostri non sono morti
##
## Per aggiungere un evento: una flag, uno spawn (con "story": id, "force": true), un testo per objective() e un complete().

const INV := "villaggio_libero"
const ESCAPE_INTRO := "escape_intro"
const FIRE_OFF := Vector2i(3, 0)           # il falo' del villaggio e' a SEEDS[0] + questo
const ESCAPE_LINE := "IL VILLAGGIO E' STATO INVASO. I MOSTRI SONO OVUNQUE. NON C'E' PIU' SPERANZA."
static var left_n := 0
static var timer := 0.0
static var total := 0       # mostri dell'invasione (morti compresi)


static func flags(m) -> Dictionary:
	if not m.persist.has("flags"):
		m.persist["flags"] = {}
	return m.persist["flags"]


static func is_done(m, id: String) -> bool:
	return bool(flags(m).get(id, false))


static func village_free(m) -> bool:
	return m.run_mode or is_done(m, INV)


static func on_prison_exit(m) -> void:
	if is_done(m, ESCAPE_INTRO) or not m.persist["bosses"].has("boss_jailer"):
		return
	flags(m)[ESCAPE_INTRO] = true
	m.dlg = {"head": "IL FUGGIASCO", "text": ESCAPE_LINE, "opts": ["..."], "sel": 0, "qs": "story", "qid": ""}
	m.state = "dialog"
	m.snd("page")
	m.save_game()


## chiamata all'inizio di populate_world: decide se il villaggio e' invaso
static func init_world(m) -> void:
	var f := flags(m)
	if f.has(INV) or m.run_mode:
		return
	# salvataggi gia' avanzati (anziano incontrato, custode sconfitto...): il villaggio era in pace
	if m.journey_step() >= 1 or m.persist["bosses"].has("boss_wraith") or m.guardians > 0:
		f[INV] = true


## il falo' del villaggio non funziona finche' e' invaso
static func blocks_fire(m, p) -> bool:
	if village_free(m) or p == null or m.area != "world":
		return false
	return Vector2(p.cell).distance_to(Vector2(m.SEEDS[0] + FIRE_OFF)) < 3.0


## i mostri che hanno invaso il villaggio: tutti presenti a ogni livello, non solo il 50%.
## Le uccisioni sono salvate (persist flags.inv_dead): riposare ai falo' non li fa tornare.
static func world_setup(m) -> void:
	left_n = 0
	total = 0
	if village_free(m):
		return
	var v0: Vector2i = m.SEEDS[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = int(m.world_seed) * 977 + 31
	var dead: Array = flags(m).get("inv_dead", [])
	var pool := ["goblin", "goblin", "kobold", "skeleton", "goblin_archer", "wolf"]
	var made := 0
	for att in 600:
		if made >= 11:
			break
		var c := v0 + Vector2i(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(8.0, 22.0))
		var kind: String = pool[rng.randi() % pool.size()]
		var elite := rng.randf() < 0.18
		if not m.inb(c) or not m.is_floor(c) or m.block.has(c) or m.outside[m.idx(c)] == 1:
			continue
		if Vector2(c).distance_to(Vector2(v0 + FIRE_OFF)) < 7.0:
			continue   # il punto di risveglio resta sgombro
		var sid := made
		made += 1
		if dead.has(sid):
			continue
		var leader := sid == 0
		m.spawns.append({"k": "knight_fallen" if leader else kind, "pos": m.cell_pos(c),
			"mult": 1.3 if leader else 1.05, "elite": (not leader) and elite, "tint": Color.WHITE if leader else Color(0.95, 0.85, 0.85),
			"story": "invasione", "sid": sid, "force": true})
	total = made
	left_n = total - dead.size()


static func is_dead(m, sref: Dictionary) -> bool:
	return (flags(m).get("inv_dead", []) as Array).has(int(sref.get("sid", -1)))


## un mostro dell'invasione e' morto (chiamato da enemy_died)
static func on_kill(m, sref: Dictionary) -> void:
	if sref.get("story", "") != "invasione":
		return
	var f := flags(m)
	var dead: Array = f.get("inv_dead", [])
	if not dead.has(int(sref["sid"])):
		dead.append(int(sref["sid"]))
	f["inv_dead"] = dead
	left_n = maxi(0, total - dead.size())
	m.popup(m.player.position + Vector2(0, -26), "%d RIMASTI" % left_n if left_n > 0 else "VILLAGGIO LIBERO!", Color(1.0, 0.85, 0.5))


static func update(m, dt: float) -> void:
	if village_free(m) or m.area != "world" or total == 0:
		return
	var f := flags(m)
	if not f.get("inv_shown", false):
		f["inv_shown"] = true
		m.say("IL VILLAGGIO E' STATO INVASO! IL FALO' E' SPENTO")
		m.snd("roar")
		m.shake(3.0)
	if total - (f.get("inv_dead", []) as Array).size() <= 0:
		complete_invasion(m)


static func complete_invasion(m) -> void:
	flags(m)[INV] = true
	var fire_cell: Vector2i = m.SEEDS[0] + FIRE_OFF
	for p in m.props:
		if is_instance_valid(p) and p.kind == "bonfire" and Vector2(p.cell).distance_to(Vector2(fire_cell)) < 3.0:
			m.light_bonfire(p)
			m.burst(p.position, Color(1.0, 0.8, 0.4), 30, 70.0, 0.8)
	m.player.add_souls(150)
	m.popup(m.player.position + Vector2(0, -22), "+150 ANIME", Color(0.6, 1.0, 0.85))
	m.drop_relic(m.player.position + Vector2(0, 14))
	m.say("VILLAGGIO LIBERATO! IL FALO' BRUCIA DI NUOVO")
	m.snd("level")
	m.save_game()


## testo dell'obiettivo (vuoto se nessun evento di storia e' in corso)
static func objective(m) -> String:
	if village_free(m):
		return ""
	var t := "LIBERA IL VILLAGGIO DAI MOSTRI"
	if left_n > 0:
		t += " (%d RIMASTI)" % left_n
	if m.area == "world":
		var tg: Vector2 = m.cell_pos(m.SEEDS[0])
		t += " (%s, %d M)" % [m.dir_hint(tg), int(tg.distance_to(m.player.position) / 16.0)]
	return t


static func elder_line(m) -> String:
	return "L'ANZIANO (SPAVENTATO): SONO ENTRATI DURANTE LA NOTTE! LIBERA IL VILLAGGIO E IL FALO' TORNERA' A BRUCIARE"
