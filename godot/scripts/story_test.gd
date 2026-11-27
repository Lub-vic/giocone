class_name StoryTest
extends RefCounted
## Prova di sviluppo (--sequencetest): percorre tutta la sequenza della storia nel mondo 3D. Il giocatore viene portato sui
## bersagli indicati dalla freccia; si controllano ordine, bersagli raggiungibili, fienile, radura, riposo e rinascita.

static var errors: Array[String] = []


static func check(ok: bool, what: String) -> void:
	if not ok:
		errors.append(what)
		print("STORIA ERRORE ", what)


static func frames(m, n: int) -> void:
	for i in n:
		if m.state in ["dialog", "story", "pick", "menu"]:
			m.state = "play"
		m.player.hp = m.player.max_hp
		await m.get_tree().process_frame


static func go(m, at: Vector2, wait := 12) -> void:
	m.ensure_area(at, 2)
	m.player.position = at
	await frames(m, wait)


## il bersaglio della freccia deve avere un punto libero entro tre celle, con la scena 3D costruita
static func reachable(m, at: Vector2) -> bool:
	var sk: W3DSkin = m.skin
	var ep: Vector2 = at / 16.0 - sk.world_off
	var k := Vector2i(floori(ep.x / sk.CHS), floori(ep.y / sk.CHS))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var kk: Vector2i = k + Vector2i(dx, dz)
			if not sk.chunks.has(kk) and not sk.job_keys.has(kk):
				sk._enqueue(kk)
	sk._run_jobs(1e12)
	for ring in range(0, 4):
		for a in 16:
			if sk.world_free(at + Vector2.from_angle(TAU * a / 16.0) * ring * 16.0, 5.0):
				return true
	return false


static func village_rect_has(m, cell: Vector2) -> bool:
	var d: Vector2 = cell - Vector2(m.SEEDS[0])
	return absf(d.x) <= W3DSkin.VILLAGE_KEEP.x and absf(d.y) <= W3DSkin.VILLAGE_KEEP.y


static func run(m) -> void:
	errors.clear()
	await frames(m, 20)
	m.build_area("world")
	m.persist["bosses"]["boss_jailer"] = true
	m.state = "play"
	await go(m, m.cell_pos(m.SEEDS[0] + Vector2i(0, 6)), 30)

	# --- prima della liberazione: niente riposo, rinascita al falo' del villaggio
	check(not Story.village_free(m), "il villaggio doveva essere invaso")
	var far_fire: Prop = null
	for p in m.props:
		if p.kind == "bonfire" and Vector2(p.cell).distance_to(Vector2(m.SEEDS[0])) > 20.0:
			far_fire = p
			break
	if far_fire != null:
		var before: Dictionary = m.last_fire.duplicate()
		m.rest(far_fire)
		check(m.last_fire == before and m.state != "fade", "si puo' riposare prima della liberazione")
	await go(m, m.cell_pos(m.SEEDS[0] + Vector2i(60, 30)), 5)
	m.game_over(false)
	m.respawn()
	var fire: Vector2 = m.cell_pos(m.SEEDS[0] + Story.FIRE_OFF)
	var dist: float = m.player.position.distance_to(fire) / 16.0
	check(dist <= 6.0, "rinascita lontana dal falo' del villaggio: %.1f celle" % dist)
	print("STORIA prima della liberazione: rinascita a ", snappedf(dist, 0.1), " celle dal falo'")

	# --- liberazione e sequenza
	Story.flags(m)[Story.INV] = true
	Story.flags(m)[W3DCine.FLAG] = true
	Story.flags(m)[Story.CHRONO] = true
	m.persist["journey"] = 0
	m.persist["journey_v"] = Missions.VERSION
	m.player.lv = 1
	await go(m, m.cell_pos(m.SEEDS[0] + Vector2i(4, 8)), 20)
	var guard := 0
	while m.journey_step() < Missions.STAGES.size() and guard < 40:
		guard += 1
		var step: int = m.journey_step()
		var st: Dictionary = Missions.STAGES[step]
		var id := str(st["id"])
		print("STORIA tappa ", step, " [", id, "] ", m.objective())
		match id:
			"elder", "page", "pages", "scout", "bell":
				for attempt in 12:
					if m.journey_step() != step:
						break
					var tg: Variant = m.journey_target()
					check(tg != null, "tappa %d (%s): la freccia non ha bersaglio" % [step, id])
					if tg == null:
						break
					m.ensure_area(tg, 2)
					check(reachable(m, tg), "tappa %d (%s): bersaglio non raggiungibile %s" % [step, id, str((tg as Vector2) / 16.0)])
					check(not m.obj_targets().is_empty(), "tappa %d: nessuna freccia a schermo" % step)
					await go(m, (tg as Vector2) + (Vector2(0, 18) if id == "elder" else Vector2.ZERO), 15)
					if id == "page" or id == "pages":
						m.collect_pages()
						await frames(m, 4)
			"level":
				m.player.lv = int(st["n"])
				await frames(m, 8)
			"supplies":
				m.player.mats["erba"] = int(m.player.mats.get("erba", 0)) + int(st["n"])
				await frames(m, 8)
			"barn":
				await _barn(m, step)
			"radura":
				await _clearing(m, step)
		check(m.journey_step() == step + 1, "tappa %d (%s): avanzamento a %d" % [step, id, m.journey_step()])
		if m.journey_step() != step + 1:
			break
		await frames(m, 4)
	check(m.journey_step() == Missions.STAGES.size(), "la sequenza si e' fermata alla tappa %d" % m.journey_step())

	# --- conversione dei salvataggi con la vecchia numerazione
	var old := {"journey": 2}
	Missions.migrate(old)
	check(int(old["journey"]) == Missions.BARN_STAGE, "salvataggio vecchio: il fienile non coincide")
	print("STORIA ESITO=", "OK" if errors.is_empty() else "FALLITO (%d errori)" % errors.size())
	m.get_tree().quit(0 if errors.is_empty() else 1)


static func _barn(m, step: int) -> void:
	await go(m, m.cell_pos(m.SEEDS[0] + Vector2i(0, 6)), 10)
	check(m.barn_pos.x >= 0.0, "nessun fienile nel mondo")
	check(not village_rect_has(m, m.barn_pos), "il fienile e' dentro la cinta del villaggio")
	Story.update(m, Story.BARN_DELAY + 1.0)
	await frames(m, 30)
	for i in 600:
		if Story.barn_status(m) != "approach":
			break
		if is_instance_valid(Story.barn_runner):
			Story.talk_barn_farmer(m, Story.barn_runner)
		await frames(m, 1)
	await frames(m, 10)
	check(Story.barn_status(m) == "march", "dopo il contadino l'assalto non deve partire subito: stato=" + Story.barn_status(m))
	check(m.player.zmode == 0, "la modalita' orda e' partita nel villaggio")
	check(reachable(m, m.barn_pos * 16.0), "fienile non raggiungibile")
	await go(m, m.barn_pos * 16.0 + Vector2(0, 7 * 16), 20)
	check(Story.barn_status(m) == "active", "l'assalto non parte arrivando al fienile: stato=" + Story.barn_status(m))
	var left: float = Story.barn_t
	await go(m, m.barn_pos * 16.0 + Vector2(0, 60 * 16), 20)
	check(absf(Story.barn_t - left) < 1.0, "lontano dal fienile il tempo continua a scorrere")
	print("STORIA fienile a ", snappedf(m.barn_pos.distance_to(Vector2(m.SEEDS[0])), 0.1), " celle dal villaggio, tempo fermo lontano=", absf(Story.barn_t - left) < 1.0)
	await go(m, m.barn_pos * 16.0 + Vector2(0, 7 * 16), 10)
	Story.update(m, Story.BARN_TIME + 1.0)
	await frames(m, 20)
	check(Story.barn_done(m) or m.journey_step() == step + 1, "assalto al fienile non concluso")


static func _clearing(m, step: int) -> void:
	await go(m, m.cell_pos(m.SEEDS[0]), 10)
	var spot := Missions.radura_cell(m)
	check(spot.x >= 0, "nessun posto per la radura")
	if spot.x < 0:
		return
	var from_village := Vector2(spot - m.SEEDS[0]).length()
	check(from_village >= 70.0, "radura troppo vicina al villaggio: %.0f" % from_village)
	var sk: W3DSkin = m.skin
	var low := INF
	var high := -INF
	for dy in range(-14, 15, 2):
		for dx in range(-14, 15, 2):
			var h: float = sk.elev_at(spot.x + dx, spot.y + dy)
			low = minf(low, h)
			high = maxf(high, h)
	check(reachable(m, m.cell_pos(spot)), "radura non raggiungibile")
	print("STORIA radura a ", int(from_village), " celle dal villaggio, dislivello nell'arena=", snappedf(high - low, 0.01))
	check(not m.side_scroll_active, "la radura parte prima di arrivarci")
	await go(m, m.cell_pos(spot + Vector2i(0, 3)), 20)
	check(m.side_scroll_active and m.side_scroll_mode == "temporal_clearing", "arrivando alla radura il combattimento non parte")
	if not m.side_scroll_active:
		return
	for i in m.TEMPORAL_UFO_HITS_TO_ESCAPE:
		m._side_scroll_register_ufo_hit()
	for i in 1200:
		if not m.side_scroll_active:
			break
		await frames(m, 1)
	await frames(m, 10)
	check(Story.is_done(m, "radura_done"), "la vittoria nella radura non viene registrata")
