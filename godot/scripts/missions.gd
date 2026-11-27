class_name Missions
extends RefCounted
## La sequenza della storia dopo le celle: un'unica tabella ordinata. Ogni tappa ha testo, bersaglio della freccia e
## condizione di chiusura; la successiva comincia solo quando la precedente e' chiusa.
## Le prime tre MISSIONI (liberare il villaggio, fienile, radura) sono pensate per riempire circa un'ora: fra l'una e
## l'altra ci sono tappe in cui esplorare, raccogliere e crescere.

## version 2 della numerazione salvata in persist["journey"]
const VERSION := 2
const STAGES := [
	{"id": "elder", "txt": "PARLA CON L'ANZIANO DEL VILLAGGIO"},
	{"id": "page", "txt": "CERCA UNA PAGINA DI DIARIO NEL VILLAGGIO", "n": 1},
	{"id": "scout", "txt": "ESPLORA I DINTORNI: SCOPRI NUOVI LUOGHI", "n": 4},
	{"id": "level", "txt": "SALI A LIVELLO %d RIPOSANDO AL FALO'", "n": 3},
	{"id": "supplies", "txt": "RACCOGLI PROVVISTE PER L'INVERNO", "n": 18},
	{"id": "barn", "txt": "DIFENDI LE RISERVE DI CIBO AL FIENILE"},
	{"id": "scout", "txt": "STRANE LUCI DI NOTTE: BATTI LE TERRE LONTANE", "n": 6},
	{"id": "pages", "txt": "RACCOGLI ALTRE PAGINE DI DIARIO", "n": 5},
	{"id": "level", "txt": "SALI A LIVELLO %d RIPOSANDO AL FALO'", "n": 6},
	{"id": "radura", "txt": "RAGGIUNGI LA RADURA DOVE SONO CADUTE LE LUCI"},
	{"id": "bell", "txt": "RAGGIUNGI LA CAMPANA DEI CONDANNATI"},
]
const BARN_STAGE := 5
const RADURA_STAGE := 9
const BELL_STAGE := 10
## numerazione precedente (5 tappe) -> nuova
const FROM_V1 := [0, 1, BARN_STAGE, 6, BELL_STAGE, 11]
const EARLY_BIOMES := [0, 1, 2, 3]      # regioni raggiungibili con tutti i cancelli chiusi
const SEEN_RADIUS := 13.0               # celle: un luogo e' "scoperto" quando ci si arriva vicino
const RADURA_RADIUS := 18               # celle libere attorno al centro della radura
const RADURA_TRIGGER := 7.0


## grado raggiunto nella storia: decide cosa si puo' evocare e forgiare.
## 0 prima del fienile, 1 dopo il fienile, 2 dopo la radura, 3 dopo il primo custode.
static func tier(m) -> int:
	if m.run_mode or m.guardians > 0:
		return 3
	var s: int = m.journey_step()
	if s > RADURA_STAGE:
		return 2
	return 1 if s > BARN_STAGE else 0


static func migrate(persist: Dictionary) -> void:
	if persist.has("journey") and int(persist.get("journey_v", 1)) < VERSION:
		persist["journey"] = FROM_V1[clampi(int(persist["journey"]), 0, FROM_V1.size() - 1)]
		persist["journey_v"] = VERSION


static func stage(m) -> Dictionary:
	var s: int = m.journey_step()
	return STAGES[s] if s < STAGES.size() else {}


static func _seen_pois(m) -> Array:
	if not m.persist.has("poi_seen"):
		m.persist["poi_seen"] = []
	return m.persist["poi_seen"]


static func _mats_total(m) -> int:
	var total := 0
	for k in m.player.mats:
		total += int(m.player.mats[k])
	return total


## punto di partenza dei contatori della tappa in corso (salvato con la partita)
static func _base(m) -> Dictionary:
	var s: int = m.journey_step()
	var base: Dictionary = m.persist.get("stage_base", {})
	if int(base.get("stage", -1)) != s:
		base = {"stage": s, "pois": _seen_pois(m).size(), "pages": m.pages_found, "mats": _mats_total(m), "best": 0}
		m.persist["stage_base"] = base
	return base


## quanto manca: [fatto, richiesto]
static func progress(m) -> Vector2i:
	var st := stage(m)
	if st.is_empty():
		return Vector2i.ZERO
	var need := int(st.get("n", 1))
	var base := _base(m)
	var done := 0
	match str(st["id"]):
		"page":
			done = m.pages_found
		"scout":
			done = _seen_pois(m).size() - int(base["pois"])
		"pages":
			done = m.pages_found - int(base["pages"])
		"supplies":
			# conta il massimo raggiunto: spendere materiali non fa tornare indietro
			base["best"] = maxi(int(base["best"]), _mats_total(m) - int(base["mats"]))
			done = int(base["best"])
		"level":
			done = m.player.lv
	return Vector2i(clampi(done, 0, need), need)


static func text(m) -> String:
	var st := stage(m)
	if st.is_empty():
		return ""
	var t := str(st["txt"])
	match str(st["id"]):
		"level":
			t = t % int(st["n"])
		"scout", "pages", "supplies":
			var p := progress(m)
			t += " (%d/%d)" % [p.x, p.y]
	var tg: Variant = target(m)
	if tg != null:
		t += " (%s, %d M)" % [m.dir_hint(tg), int((tg as Vector2).distance_to(m.player.position) / 16.0)]
	return t


static func _nearest(m, points: Array) -> Variant:
	var best: Variant = null
	for p: Vector2 in points:
		if best == null or p.distance_squared_to(m.player.position) < (best as Vector2).distance_squared_to(m.player.position):
			best = p
	return best


## bersaglio della freccia in pixel di gioco (null se la tappa non ha un luogo)
static func target(m) -> Variant:
	if m.area != "world" or not m.persist["bosses"].has("boss_jailer"):
		return null
	var st := stage(m)
	if st.is_empty():
		return null
	match str(st["id"]):
		"elder":
			for p in m.props:
				if p.kind == "elder":
					return p.position
			return m.cell_pos(m.SEEDS[0] + Vector2i(-3, -1))
		"page", "pages":
			var near_village := str(st["id"]) == "page"
			var pages: Array = []
			for p in m.props:
				if p.kind == "page" and (near_village or EARLY_BIOMES.has(m.biome_at(p.cell.x, p.cell.y))):
					pages.append(p.position)
			return _nearest(m, pages)
		"scout":
			var seen := _seen_pois(m)
			var places: Array = []
			for po in m.pois:
				var c: Vector2i = po["cell"]
				if not seen.has(int(po["id"])) and EARLY_BIOMES.has(m.biome_at(c.x, c.y)):
					places.append(m.cell_pos(c))
			return _nearest(m, places)
		"supplies":
			var res: Array = []
			for p in m.props:
				if str(p.kind).begins_with("res_"):
					res.append(p.position)
			return _nearest(m, res)
		"level":
			var fires: Array = []
			for p in m.props:
				if p.kind == "bonfire":
					fires.append(p.position)
			return _nearest(m, fires)
		"barn":
			if m.barn_pos.x >= 0.0:
				return (m.barn_pos as Vector2) * 16.0
		"radura":
			var c := radura_cell(m)
			if c.x >= 0:
				return m.cell_pos(c)
		"bell":
			for a in m.arenas:
				if a["def"]["id"] == "a_vil":
					return a["pos"]
	return null


## il luogo del combattimento con l'ufo: lontano dal villaggio, ampio e il piu' pianeggiante possibile.
## Scelto una volta e salvato. Servono le quote del terreno, quindi la vista 3D del mondo deve esistere.
static func radura_cell(m) -> Vector2i:
	var saved: Array = m.persist.get("radura", [])
	if saved.size() == 2:
		return Vector2i(int(saved[0]), int(saved[1]))
	if not (m.skin is W3DSkin) or not (m.skin as W3DSkin).world_on or m.area != "world":
		return Vector2i(-1, -1)
	var sk: W3DSkin = m.skin
	var best := Vector2i(-1, -1)
	var best_score := INF
	var village: Vector2i = m.SEEDS[0]
	for ring in 9:
		for k in 40:
			var c: Vector2i = village + Vector2i((Vector2.from_angle(TAU * k / 40.0) * (80.0 + ring * 9.0)).round())
			if c.x < RADURA_RADIUS + 8 or c.y < RADURA_RADIUS + 8 or c.x > Game.MW - RADURA_RADIUS - 8 or c.y > Game.MH - RADURA_RADIUS - 8:
				continue
			if not EARLY_BIOMES.has(m.biome_at(c.x, c.y)):
				continue
			if m.barn_pos.x >= 0.0 and (m.barn_pos as Vector2).distance_to(Vector2(c)) < 40.0:
				continue
			var crowded := false
			for po in m.pois:
				if Vector2(po["cell"]).distance_to(Vector2(c)) < RADURA_RADIUS + 8.0:
					crowded = true
			for e in m.ENTR.values():
				if Vector2(e).distance_to(Vector2(c)) < RADURA_RADIUS + 12.0:
					crowded = true
			if crowded:
				continue
			var low := INF
			var high := -INF
			var wet := false
			for dy in range(-RADURA_RADIUS, RADURA_RADIUS + 1, 4):
				for dx in range(-RADURA_RADIUS, RADURA_RADIUS + 1, 4):
					var q := c + Vector2i(dx, dy)
					if m.water[m.idx(q)] == 1 or m.is_outside_xy(q.x, q.y):
						wet = true
					var h: float = sk.elev_at(q.x, q.y)
					low = minf(low, h)
					high = maxf(high, h)
			if wet:
				continue
			# prima di tutto il piano; a parita', il punto piu' vicino
			var score := (high - low) * 100.0 + ring
			if score < best_score:
				best_score = score
				best = c
	if best.x >= 0:
		m.persist["radura"] = [best.x, best.y]
		if m.testing:
			print("MISSIONI radura scelta ", best, " distanza dal villaggio=", int(Vector2(best - village).length()), " dislivello=", snappedf(floorf(best_score / 100.0 * 100.0) / 100.0, 0.01))
	return best


static func _note_places(m) -> void:
	if m.area != "world":
		return
	var seen := _seen_pois(m)
	var at: Vector2 = m.player.position / 16.0
	for po in m.pois:
		if not seen.has(int(po["id"])) and at.distance_to(Vector2(po["cell"])) <= SEEN_RADIUS:
			seen.append(int(po["id"]))
			m.popup(m.player.position + Vector2(0, -34), "LUOGO SCOPERTO: %s" % str(po.get("n", "")), Color(0.75, 0.9, 1.0))


## chiude la tappa in corso quando la sua condizione e' soddisfatta
static func update(m) -> void:
	_base(m)
	_note_places(m)
	var st := stage(m)
	if st.is_empty() or m.area != "world":
		return
	match str(st["id"]):
		"elder":
			var tg: Variant = target(m)
			if tg != null and Story.village_free(m) and (tg as Vector2).distance_to(m.player.position) < 30.0:
				m.journey_advance("L'ANZIANO: FUORI C'E' PIU' DI QUEL CHE VEDI. CERCA I DIARI: RACCONTANO COME FINI' TUTTO", 60, 0, 0)
		"page":
			if m.pages_found >= 1:
				m.journey_advance("UNA PAGINA PARLA DI LUOGHI DIMENTICATI. ESPLORA I DINTORNI", 60, 0, 0)
		"scout":
			var p := progress(m)
			if p.x >= p.y:
				var first: bool = m.journey_step() < BARN_STAGE
				m.journey_advance("ORA CONOSCI LA VALLE. TORNA PIU' FORTE" if first else "LE LUCI CADONO SEMPRE NELLO STESSO PUNTO. SERVONO ALTRE PAGINE", 120 if first else 200, 1, 0)
		"level":
			var p := progress(m)
			if p.x >= p.y:
				var first: bool = m.journey_step() < BARN_STAGE
				m.journey_advance("PIU' FORTE. IL VILLAGGIO HA BISOGNO DI PROVVISTE" if first else "SEI PRONTO. LE LUCI VENGONO DA UNA RADURA LONTANA", 100, 1, 0)
		"supplies":
			var p := progress(m)
			if p.x >= p.y:
				m.journey_advance("PROVVISTE AL SICURO NEL FIENILE. MA QUALCUNO LE HA VISTE", 120, 0, 0)
		"barn":
			if Story.barn_done(m):
				m.journey_advance("FIENILE SALVO! LE SCORTE BASTERANNO PER L'INVERNO", 160, 1, 0)
				m.add_item("arrosto", 2)
		"pages":
			var p := progress(m)
			if p.x >= p.y:
				m.journey_advance("I DIARI DICONO CHE LE LUCI TORNERANNO. PREPARATI", 150, 0, 1)
		"radura":
			if Story.is_done(m, "radura_done"):
				m.journey_advance("L'UFO E' FUGGITO. LA CAMPANA DEI CONDANNATI HA COMINCIATO A SUONARE", 300, 1, 2)
			else:
				var c := radura_cell(m)
				if c.x >= 0 and m.state == "play" and not m.side_scroll_active and m.player.position.distance_to(m.cell_pos(c)) < RADURA_TRIGGER * 16.0:
					m.start_story_clearing(m.cell_pos(c))
		"bell":
			var tg2: Variant = target(m)
			if tg2 != null and (tg2 as Vector2).distance_to(m.player.position) < 110.0:
				m.journey_advance("LA CAMPANA TACE. IL CUSTODE DEL CIMITERO TI ASPETTA A EST", 200, 1, 2)
