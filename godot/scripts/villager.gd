class_name Villager
extends Node2D
## Abitante di un insediamento: di giorno lavora e passeggia, al tramonto rientra a casa, di notte non si vede.

const M_NAMES := ["OSWIN", "EDRIC", "GARETH", "TOMAS", "CEDRIC", "MAREK", "LEOFRIC", "ALDRIC", "BERTRAM", "HUGO"]
const F_NAMES := ["MARGOT", "HILDA", "BRYNN", "ALDA", "ROWENA", "ISOLDE", "WYNN", "EDITH", "MAUD", "GISELA"]
const K_NAMES := ["PIP", "NELL", "TOBY", "LIA", "FINN", "MIA"]

# ruolo -> sprite, genere, scala, titolo, battute proprie
const ROLES := {
	"contadino": {"spr": "villager_a", "g": "m", "sc": 1.0, "t": "CONTADINO", "lines": [
		"IL GRANO NON CRESCE PIU'. SOLO LE ERBACCE.", "HO LASCIATO UNA BOTTE NELLA CASA VICINO AL POZZO.", "SE TROVI UN FORZIERE NEI CAMPI, NON LASCIARLO LI'."]},
	"contadina": {"spr": "villager_b", "g": "f", "sc": 1.0, "t": "CONTADINA", "lines": [
		"MIO MARITO SI E' ADDENTRATO NEL BOSCO E NON E' PIU' TORNATO.", "LE CASE VUOTE SONO PIENE DI ROBA... E DI TOPI.", "LA PIAZZA ERA PIENA DI VITA, UNA VOLTA."]},
	"anziano": {"spr": "villager_c", "g": "m", "sc": 1.0, "t": "ANZIANO", "lines": [
		"MIO NONNO DICEVA: IL SIGNORE SENZA NOME DORME SOTTO LA CATTEDRALE.", "TRE CUSTODI TENGONO CHIUSA LA SUA CRIPTA: CIMITERO, CATTEDRALE E FORGE.", "CHI SI FA SORPRENDERE DAL BUIO, NON RIVEDE L'ALBA."]},
	"fabbro": {"spr": "smith", "g": "m", "sc": 1.0, "t": "FABBRO", "lines": [
		"UN'ARMA RARA VALE PIU' DI UNA CORAZZA. CERCA NEI FORZIERI DELLE ROVINE.", "COLPISCI DOPO CHE IL NEMICO HA ATTACCATO: E' QUANDO E' SCOPERTO.", "LE FONDERIE A EST SONO ANCORA ACCESE. QUALCOSA LE ALIMENTA."]},
	"guardia": {"spr": "guard", "g": "m", "sc": 1.0, "t": "GUARDIA", "lines": [
		"GLI SCHELETRI ATTACCANO IN COPPIA: PARA CON C O ROTOLA.", "I LUPI TI ACCERCHIANO. NON FARTI CIRCONDARE.", "SE VEDI UN CERCHIO ROSSO PER TERRA, SPOSTATI SUBITO.", "I FALCIATORI APPAIONO ALLE SPALLE. GUARDATI SEMPRE INTORNO."]},
	"monaco": {"spr": "monk", "g": "m", "sc": 1.0, "t": "MONACO", "lines": [
		"LE ANIME CHE RACCOGLI SONO FRAMMENTI DI CHI E' CADUTO. USALE PER CRESCERE.", "I CAMPIONI LASCIANO A VOLTE UN'ANIMA LEGATA: SI UNISCE A TE.", "NEL CHIOSTRO DEI SILENZI RIPOSA UNA CHIAVE ANTICA."]},
	"bambino": {"spr": "villager_b", "g": "k", "sc": 0.72, "t": "BAMBINO", "lines": [
		"HO VISTO UN CERVO VERO! TU L'HAI VISTO?", "I MOSTRI NELLE CASE SONO TUTTI NELLE VECCHIE CASE VUOTE, NON IN QUELLE DOVE ABITIAMO!", "MI HANNO DETTO DI NON ANDARE AL CIMITERO. CI VADO LO STESSO."]},
	"cacciatore": {"spr": "hunter", "g": "m", "sc": 0.95, "t": "CACCIATORE", "lines": [
		"I CERVI FUGGONO. USA L'ARCO, O COLPISCILI ALLE SPALLE.", "DI NOTTE LE VOLPI ESCONO. SONO FURBE.", "UN CORVO CHE SI ALZA IN VOLO SEGNALA UN PERICOLO."]},
}

const LINES := {
	0: [
		"NON AVVENTURARTI NEL BOSCO DI NOTTE: LI' VIVE CHI NON TORNA.",
		"IL CANCELLO SUL PONTE, A EST, SI APRE SOLO QUANDO CADE IL CUSTODE DEL CIMITERO.",
		"DICONO CHE UN VECCHIO ARCHIVIO NELLA PALUDE CONSERVI TOMI PROIBITI... MA E' CHIUSO A CHIAVE.",
		"HO VISTO DELLE SCALE SOTTO LE RADICI, NEL BOSCO. NON CI SONO SCESO.",
		"AL SANATORIO SI ENTRA SOLO CON UNA LEVA, LAGGIU' NELLE FONDERIE.",
		"LA CAMPANA NELLA PIAZZA RICHIAMA I CONDANNATI. SUONALA SOLO SE SEI PRONTO.",
		"QUANDO PIOVE I MORTI SI AGITANO. STAI ATTENTO.",
		"UN TEMPO QUESTA VALLE CANTAVA. ORA C'E' SOLO CENERE.",
	],
	2: [
		"I CERVI SI FIDANO POCO. CHI LI CACCIA CERCA LA CARNE... E LE ANIME.",
		"L'ALBERO DEGLI IMPICCATI E' LA' IN FONDO. I CORVI LO SANNO.",
		"UNA LAMPADA ACCESA TIENE LONTANI I LUPI, A VOLTE.",
	],
	3: [
		"IN PALUDE LE LANTERNE NON SONO MAI QUELLO CHE SEMBRANO.",
		"LE RANE CANTANO SOLO DI NOTTE. QUANDO SMETTONO, ARRIVA QUALCOSA.",
		"NON BERE L'ACQUA. NON GUARDARE LE LUCI.",
	],
	5: [
		"IL GELO CONSERVA TUTTO, ANCHE I MORTI.",
		"UNA VOLPE BIANCA MI SEGUE DA GIORNI. FORSE E' UN BUON SEGNO.",
	],
}
const NIGHT_LINES := ["E' TARDI. TORNO A CASA.", "CHIUDI BENE LA PORTA, STANOTTE."]

var main
var kind := "villager"
var nm := "OSWIN"
var role := "contadino"
var region := 0
var home_door := Vector2.ZERO
var pts: Array = []
var state := "work"
var st_t := 1.0
var goal := Vector2.ZERO
var spr: Sprite2D
var stuck_t := 0.0
var last_p := Vector2.ZERO
var radius := 4.0
var t := randf() * 10.0
var said := 0
var qid := ""
var last_qs := ""


func setup(m, role_id: String, pos: Vector2, door: Vector2, points: Array, reg: int) -> void:
	main = m
	role = role_id
	var rd: Dictionary = ROLES[role_id]
	position = pos
	home_door = door
	pts = points
	region = reg
	var names: Array = M_NAMES if rd["g"] == "m" else (F_NAMES if rd["g"] == "f" else K_NAMES)
	nm = names[randi() % names.size()]
	spr = Sprite2D.new()
	spr.texture = Game.tex(str(rd["spr"]))
	spr.offset = Vector2(0, -8)
	spr.scale = Vector2.ONE * float(rd["sc"])
	# abiti leggermente diversi per ognuno
	spr.modulate = Color.WHITE.lerp(Color.from_hsv(randf(), 0.55, 1.0), 0.28 if role_id != "guardia" else 0.1)
	add_child(spr)
	st_t = randf_range(0.5, 4.0)
	last_p = pos


func _draw() -> void:
	draw_set_transform(Vector2(0, 1), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var qs := last_qs
	if qs == "new" or qs == "ready":
		var col := Color(1.0, 0.85, 0.3) if qs == "new" else Color(0.5, 1.0, 0.6)
		var by := -26.0 + sin(t * 4.0) * 1.5
		draw_rect(Rect2(-1, by, 2, 5), col)
		draw_rect(Rect2(-1, by + 7, 2, 2), col)
		if qs == "ready":
			draw_rect(Rect2(1, by - 1, 2, 1), col)
			draw_rect(Rect2(3, by, 1, 2), col)


func _process(dt: float) -> void:
	if main.state != "play":
		return
	t += dt
	if qid != "":
		var qs: String = main.quest_state(qid)
		if qs != last_qs or qs == "new" or qs == "ready":
			last_qs = qs
			queue_redraw()
	var light: float = main.day_light()
	match state:
		"work":
			visible = true
			if light < 0.3:
				state = "home"
				goal = home_door
				stuck_t = 0.0
				return
			st_t -= dt
			if goal == Vector2.ZERO or position.distance_to(goal) < 4.0:
				if st_t <= 0.0 and not pts.is_empty():
					goal = pts[randi() % pts.size()]
					st_t = randf_range(2.0, 6.0)
				else:
					spr.offset.y = -8.0 + sin(t * 2.0) * 0.5
			else:
				_walk(dt)
		"home":
			_walk(dt)
			if position.distance_to(home_door) < 8.0 or stuck_t > 3.0:
				state = "inside"
				visible = false
				position = home_door
		"inside":
			visible = false
			if light > 0.4:
				state = "work"
				visible = true
				position = home_door
				goal = Vector2.ZERO
				st_t = 1.0


func _walk(dt: float) -> void:
	var to := goal - position
	if to.length() < 3.0:
		return
	var sp := 26.0
	main.move_body(self, to.normalized() * sp * dt, radius)
	spr.flip_h = to.x < 0.0
	spr.offset.y = -8.0 - abs(sin(t * 8.0)) * 0.9
	if position.distance_to(last_p) < 0.15 * dt * 60.0:
		stuck_t += dt
	else:
		stuck_t = maxf(0.0, stuck_t - dt)
	last_p = position
	if stuck_t > 2.5 and state == "work":
		stuck_t = 0.0
		goal = Vector2.ZERO
		st_t = 0.5


func chat_line() -> String:
	var rd: Dictionary = ROLES[role]
	var own: Array = rd["lines"]
	var pool: Array = LINES.get(region, LINES[0])
	var ln: String
	if main.day_light() < 0.4:
		ln = NIGHT_LINES[randi() % NIGHT_LINES.size()]
	else:
		# alterna le battute del proprio mestiere e le voci della zona
		ln = own[(said / 2) % own.size()] if said % 2 == 0 else pool[(said / 2) % pool.size()]
		said += 1
	return ln
