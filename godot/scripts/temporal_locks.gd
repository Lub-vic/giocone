class_name TemporalLocks
extends RefCounted
## Gli oggetti dal futuro servono ad andare avanti. Due lucchetti:
##  1. il sigillo sulla porta della cripta del cimitero: si spezza con un'evocazione fatta li' accanto;
##  2. lo scudo del primo custode: cade per un po' a ogni evocazione fatta vicino a lui.
## Regola: mai bloccati per sfortuna. Vale qualunque evocazione, e la carica necessaria viene garantita.

const SEALED_DOOR := "d1"
const SEAL_FLAG := "sigillo_cripta"
const SEAL_GIFT_FLAG := "sigillo_carica"
const SEAL_RANGE := 7.0 * 16.0
const SHIELDED_BOSS := "boss_wraith"
const SHIELD_RANGE := 260.0
const SHIELD_DOWN := 18.0          # secondi senza scudo dopo un'evocazione
const SHIELD_FACTOR := 0.12        # danno che passa attraverso lo scudo


static func active(m) -> bool:
	return not m.run_mode and Story.has_chrono(m)


static func door_sealed(m, dest: String) -> bool:
	# chi ha gia' sconfitto il custode (salvataggi avanzati) non trova il sigillo
	return dest == SEALED_DOOR and active(m) and not Story.is_done(m, SEAL_FLAG) and not m.persist["bosses"].has(SHIELDED_BOSS)


## interazione con la porta sigillata: spiega cosa fare; la prima volta riempie il Cronotone
static func touch_door(m) -> void:
	if m.player.chrono < Chrono.COST and not Story.is_done(m, SEAL_GIFT_FLAG):
		Story.flags(m)[SEAL_GIFT_FLAG] = true
		m.player.chrono = Chrono.COST
		m.say("IL SIGILLO RISUONA E CARICA IL CRONOTONE. EVOCA QUI ACCANTO (%s)" % Keybinds.key_text("summon"))
	elif m.player.chrono >= Chrono.COST:
		m.say("UN SIGILLO FUORI DAL TEMPO: EVOCA QUI ACCANTO (%s)" % Keybinds.key_text("summon"))
	else:
		m.say("IL SIGILLO CHIEDE UN OGGETTO DAL TEMPO: RICARICA IL CRONOTONE UCCIDENDO E TORNA")
	m.snd("page")


static func on_summon(m) -> void:
	if not active(m):
		return
	if m.area == "world" and not Story.is_done(m, SEAL_FLAG) and not m.persist["bosses"].has(SHIELDED_BOSS) and m.ENTR.has(SEALED_DOOR):
		var door: Vector2 = m.cell_pos(m.ENTR[SEALED_DOOR])
		if m.player.position.distance_to(door) <= SEAL_RANGE:
			Story.flags(m)[SEAL_FLAG] = true
			m.burst(door, Color(0.7, 0.5, 1.0), 50, 110.0, 0.9)
			m.shake(6.0)
			m.say("IL SIGILLO TEMPORALE SI SPEZZA: LA CRIPTA E' APERTA")
			m.save_game()
	for e in m.enemies:
		if is_instance_valid(e) and e.shield_state > 0 and e.position.distance_to(m.player.position) <= SHIELD_RANGE:
			e.shield_state = 2
			e.shield_t = SHIELD_DOWN
			m.burst(e.position, Color(0.5, 0.9, 1.0), 40, 90.0, 0.7)
			m.shake(5.0)
			m.say("LO SCUDO TEMPORALE E' CADUTO: COLPISCI ORA!")


## chiamata dal custode quando e' sveglio; shield_state: 0 nessuno scudo, 1 alzato, 2 abbassato
static func boss_tick(e, delta: float) -> void:
	var m = e.main
	if e.shield_state == 1 and not e.shield_told:
		e.shield_told = true
		m.player.chrono = Chrono.MAX_E      # la prima evocazione e' sempre disponibile
		m.say("UNO SCUDO FUORI DAL TEMPO LO PROTEGGE: EVOCA VICINO A LUI (%s)" % Keybinds.key_text("summon"))
	elif e.shield_state == 2:
		e.shield_t -= delta
		if e.shield_t <= 0.0:
			e.shield_state = 1
			m.player.chrono = Chrono.MAX_E      # e anche le successive: lo scudo non puo' diventare un vicolo cieco
			m.say("LO SCUDO SI RIFORMA. IL CRONOTONE E' DI NUOVO CARICO")
