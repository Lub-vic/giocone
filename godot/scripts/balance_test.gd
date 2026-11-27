class_name BalanceTest
extends RefCounted
## Prova di sviluppo (--balancetest): cosa puo' uscire dal Cronotone e cosa si puo' forgiare a ogni grado di storia.


static func run(m) -> void:
	var errors: Array[String] = []
	for i in 5:
		await m.get_tree().process_frame
	seed(1234)
	for mode in [0, 1, 2, 3, "singolarita"]:
		var sing: bool = mode is String
		Chrono.story_tier = 0 if sing else int(mode)
		Chrono.singularity = sing
		var seen := {}
		for k in 6000:
			var r := Chrono.roll(30, k % 4)        # livello alto: resta solo il limite della storia
			seen["%s:%s" % [r["cls"], r["id"]]] = true
			if str(r["cls"]) == "gun" and not Chrono.gun_allowed(r["id"]):
				errors.append("arma fuori grado %s a %s" % [r["id"], str(mode)])
			if str(r["cls"]) == "jackpot" and not Chrono.jackpot_allowed(r["id"]):
				errors.append("alleato fuori grado %s a %s" % [r["id"], str(mode)])
			if sing and str(r["cls"]) == "junk":
				errors.append("materiale da forgia durante la singolarita'")
		var guns: Array = seen.keys().filter(func(x): return x.begins_with("gun:"))
		var allies: Array = seen.keys().filter(func(x): return x.begins_with("jackpot:"))
		var forgeable: Array = Chrono.JUNK.keys().filter(func(id): return Chrono.forge_tier(id) <= Chrono.story_tier)
		print("BILANCIO grado ", mode, ": armi=", guns.size(), " alleati=", allies.size(), " ricette anacronistiche=", forgeable.size(), "/", Chrono.JUNK.size())
	Chrono.story_tier = 3
	Chrono.singularity = false
	var total := 0
	var line := ""
	for lv in range(1, 10):
		total += Upgrades.cost(lv)
		if lv + 1 in [3, 6, 10]:
			line += " livello %d=%d anime in totale;" % [lv + 1, total]
	print("BILANCIO costi:", line)
	await _locks(m, errors)
	print("BILANCIO ESITO=", "OK" if errors.is_empty() else "FALLITO " + str(errors.slice(0, 5)))
	m.get_tree().quit(0 if errors.is_empty() else 1)


## i due lucchetti temporali: chiusi senza evocazione, aperti con un'evocazione qualsiasi
static func _locks(m, errors: Array[String]) -> void:
	m.build_area("world")
	m.persist["bosses"]["boss_jailer"] = true
	Story.flags(m)[Story.INV] = true
	Story.flags(m)[Story.CHRONO] = true
	for i in 10:
		m.state = "play"
		await m.get_tree().process_frame
	if not TemporalLocks.door_sealed(m, "d1"):
		errors.append("la cripta non e' sigillata")
	m.player.chrono = 0.0
	TemporalLocks.touch_door(m)
	if m.player.chrono < Chrono.COST:
		errors.append("la carica per il sigillo non e' garantita")
	m.player.position = m.cell_pos(m.ENTR["d1"]) + Vector2(0, 150)
	m.state = "play"
	TemporalLocks.on_summon(m)
	if not TemporalLocks.door_sealed(m, "d1"):
		errors.append("il sigillo si spezza anche da lontano")
	m.player.position = m.cell_pos(m.ENTR["d1"]) + Vector2(0, 24)
	m.state = "play"
	m.summon()
	if TemporalLocks.door_sealed(m, "d1"):
		errors.append("evocando accanto il sigillo resta")
	var boss: Enemy = m.spawn_enemy("boss_wraith", m.player.position + Vector2(60, 0), 1.0, false, Color.WHITE)
	boss.awake = true
	if boss.shield_state != 1:
		errors.append("il custode non ha lo scudo")
	var before := boss.hp
	boss.hurt(200.0, Vector2.RIGHT, 0.0, false)
	var through := before - boss.hp
	TemporalLocks.boss_tick(boss, 0.1)
	if m.player.chrono < Chrono.COST:
		errors.append("la carica per lo scudo non e' garantita")
	TemporalLocks.on_summon(m)
	before = boss.hp
	boss.hurt(200.0, Vector2.RIGHT, 0.0, false)
	var open := before - boss.hp
	if not (boss.shield_state == 2 and open > through * 4.0):
		errors.append("lo scudo non cade: %.0f / %.0f" % [through, open])
	TemporalLocks.boss_tick(boss, TemporalLocks.SHIELD_DOWN + 1.0)
	if boss.shield_state != 1 or m.player.chrono < Chrono.COST:
		errors.append("lo scudo non si riforma con la carica garantita")
	print("BILANCIO lucchetti: danno con scudo=", int(through), " senza scudo=", int(open), " vita custode=", int(boss.max_hp))
