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
const CHRONO := "chrono_found"     # l'eroe ha raccolto l'apparecchio caduto dall'ufo: senza, niente Cronotone
const ESCAPE_INTRO := "escape_intro"
const FIRE_OFF := Vector2i(3, 0)           # il falo' del villaggio e' a SEEDS[0] + questo
const ESCAPE_LINE := "IL VILLAGGIO E' STATO INVASO DURANTE LA NOTTE. I MOSTRI SONO OVUNQUE E IL FALO' E' SPENTO. LIBERALO, TI PREGO: E' LA' DOVE INDICA LA FRECCIA"
static var runner = null    # il fuggiasco che corre incontro all'eroe appena uscito dalle celle
static var runner_done := false
static var left_n := 0
static var timer := 0.0
const UFO_AFTER := 60.0
static var ufo_last := Vector2.ZERO
static var ufo_log := -1
static var ufo_pre_t := -100.0
static var ufo_wait := 0.0   # secondi dalla fine del dialogo col fuggiasco: poi arriva l'ufo
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
	runner = null
	runner_done = false     # il fuggiasco arrivera' di corsa dal villaggio (vedi update)


## il fuggiasco parte lontano, fuori dallo schermo, in direzione del villaggio
static func _spawn_runner(m) -> void:
	var pc := Vector2i(floori(m.player.position.x / 16.0), floori(m.player.position.y / 16.0))
	var dir := Vector2(m.SEEDS[0] - pc)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	var sc: Vector2i = m.free_near(pc + Vector2i(dir * 26.0))
	var p: Prop = m.add_npc("fuggiasco", sc)
	if p != null:
		m.block.erase(p.cell)
		runner = p


static func _run_to_hero(m, dt: float) -> void:
	if not is_instance_valid(runner):
		_spawn_runner(m)
		return
	var p: Prop = runner
	var to: Vector2 = m.player.position - p.position
	if to.length() > 30.0:
		m.move_body(p, to.normalized() * 62.0 * dt, 4.0)
		p.spr.flip_h = to.x < 0.0
		p.spr.offset.y = -6.0 - absf(sin(Time.get_ticks_msec() / 90.0)) * 1.2
		return
	p.spr.offset.y = -6.0
	p.cell = Vector2i(floori(p.position.x / 16.0), floori(p.position.y / 16.0))
	m.block[p.cell] = true
	runner_done = true
	flags(m)[ESCAPE_INTRO] = true
	flags(m)["inv_shown"] = true
	m.dlg = {"head": "IL FUGGIASCO", "text": ESCAPE_LINE, "opts": ["..."], "sel": 0, "qs": "story", "qid": ""}
	m.state = "dialog"
	m.snd("roar")
	m.shake(2.0)
	m.save_game()


## chiamata all'inizio di populate_world: decide se il villaggio e' invaso
static func init_world(m) -> void:
	var f := flags(m)
	if f.has(INV) or m.run_mode:
		return
	# salvataggi gia' avanzati (anziano incontrato, custode sconfitto...): il villaggio era in pace
	if m.journey_step() >= 1 or m.persist["bosses"].has("boss_wraith") or m.guardians > 0:
		f[INV] = true
		f[W3DCine.FLAG] = true        # partite gia' avanzate: l'ufo non c'e' mai stato, il Cronotone e' gia' loro
		f[CHRONO] = true


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


## il Cronotone esiste solo dopo aver raccolto l'apparecchio caduto dall'ufo
static func has_chrono(m) -> bool:
	return m.run_mode or is_done(m, CHRONO)


static func device_cell(m) -> Variant:
	var f := flags(m)
	if is_done(m, W3DCine.FLAG) and not is_done(m, CHRONO) and f.has("dev_x"):
		return Vector2(float(f["dev_x"]), float(f["dev_y"]))
	return null


## l'apparecchio e' a terra: basta avvicinarsi per prenderlo
static func _device(m) -> void:
	var dc: Variant = device_cell(m)
	if dc == null or m.area != "world" or m.state != "play":
		return
	if m.player.position.distance_to((dc as Vector2) * 16.0) > 30.0:
		return
	flags(m)[CHRONO] = true
	if m.skin is W3DSkin and (m.skin as W3DSkin).cine != null:
		(m.skin as W3DSkin).cine.take_device()
	m.burst((dc as Vector2) * 16.0, Color(0.75, 0.5, 1.0), 40, 90.0, 1.0)
	m.player.chrono = Chrono.MAX_E
	m.snd("level")
	m.shake(3.0)
	var key: String = Keybinds.key_text("summon")
	m.dlg = {"head": "UNA VOCE NEL METALLO", "text": "L'OGGETTO PULSA TRA LE TUE MANI. SENTI IL TEMPO INCRINARSI: IERI E DOMANI TI SUSSURRANO, E CIO' CHE NON E' ANCORA, O NON E' PIU', PUO' ESSERE CHIAMATO. PREMI %s PER EVOCARE OGGETTI DA ALTRE EPOCHE. OGNI NEMICO CADUTO LO RICARICA" % key, "opts": ["..."], "sel": 0, "qs": "story", "qid": ""}
	m.state = "dialog"
	m.save_game()


static func update(m, dt: float) -> void:
	_device(m)
	if village_free(m) or m.area != "world":
		return
	if not is_done(m, ESCAPE_INTRO) and m.persist["bosses"].has("boss_jailer") and m.state == "play":
		_run_to_hero(m, dt)
	if is_done(m, ESCAPE_INTRO) and not is_done(m, W3DCine.FLAG) and m.state == "play":
		# l'ufo arriva dopo circa un minuto di cammino verso il villaggio (o appena si e' vicini al villaggio)
		ufo_wait += dt      # conta il tempo di gioco (non solo i passi: il rilevamento del movimento rallentava il conto)
		var near_v: bool = m.player.position.distance_to(m.cell_pos(m.SEEDS[0])) < 40.0 * 16.0
		if ufo_wait > 5.0 and ufo_wait - ufo_pre_t > 12.0 and m.skin is W3DSkin and (m.skin as W3DSkin).world_on:
			ufo_pre_t = ufo_wait      # il precarico segue il percorso dalla posizione attuale, aggiornato ogni 12 s
			(m.skin as W3DSkin).cine_prewarm()      # il terreno del volo si carica in background
		if int(ufo_wait) != ufo_log and int(ufo_wait) % 15 == 0:
			ufo_log = int(ufo_wait)
			print("UFO attesa cammino: ", ufo_log, "/", int(UFO_AFTER), " s, vicino al villaggio=", near_v)
		if (ufo_wait > UFO_AFTER or near_v) and ufo_wait > 6.0 and m.skin is W3DSkin and (m.skin as W3DSkin).start_cine():
			print("UFO: sequenza avviata")
			ufo_wait = 0.0
			ufo_pre_t = -100.0
	if total == 0:
		return
	var f := flags(m)
	if not f.get("inv_shown", false) and is_done(m, ESCAPE_INTRO):
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
	var dc: Variant = device_cell(m)
	if dc != null:
		var dv: Vector2 = (dc as Vector2) * 16.0
		return "RECUPERA L'APPARECCHIO CADUTO DALL'UFO (%s, %d M)" % [m.dir_hint(dv), int(dv.distance_to(m.player.position) / 16.0)]
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
