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
	print("BILANCIO ESITO=", "OK" if errors.is_empty() else "FALLITO " + str(errors.slice(0, 5)))
	m.get_tree().quit(0 if errors.is_empty() else 1)
