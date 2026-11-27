class_name PlayLog
extends RefCounted
## Registro di partita per tarare il ritmo: user://registro_partita.csv. Una riga per evento (tappa, livello, evocazione,
## forgia, morte, custode) e una ogni cinque minuti di gioco. Il tempo conta solo mentre si gioca. Niente righe nelle prove.

const PATH := "user://registro_partita.csv"
const HEADER := "data;minuti_gioco;tappa;livello;anime;uccisioni;evento;dettaglio"
const EVERY := 300.0


static func note(m, event: String, detail := "") -> void:
	if m.testing or m.run_mode or m.mission_test_active or m.player == null:
		return
	var fresh := not FileAccess.file_exists(PATH)
	var f := FileAccess.open(PATH, FileAccess.WRITE if fresh else FileAccess.READ_WRITE)
	if f == null:
		return
	if fresh:
		f.store_line(HEADER)
	f.seek_end()
	f.store_line("%s;%.1f;%d;%d;%d;%d;%s;%s" % [Time.get_datetime_string_from_system(false, true),
		float(m.persist.get("play_t", 0.0)) / 60.0, m.journey_step(), m.player.lv, m.player.souls, m.player.kills,
		event, detail.replace(";", ",")])


static func tick(m, delta: float) -> void:
	if m.state != "play" or m.run_mode:
		return
	var before := float(m.persist.get("play_t", 0.0))
	m.persist["play_t"] = before + delta
	if int(before / EVERY) != int((before + delta) / EVERY):
		note(m, "intervallo")
