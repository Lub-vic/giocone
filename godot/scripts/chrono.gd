class_name Chrono
extends RefCounted
## Bolle spazio-temporali: un tasto, un oggetto a caso dal passato o dal futuro.
## Utili (effetto immediato), inutili (vanno alla forgia, scheda ANACRONISMI) e jackpot (alleati/mezzi, via via piu' grandi).

const MAX_E := 100.0        # carica massima del Cronotone
const COST := 100.0         # costo di un'evocazione
const GUN_P := 0.12         # probabilita' fissa che esca un'arma dal futuro (se ce n'e' una sbloccata)
const PITY_MAX := 3         # dopo tanti oggetti inutili di fila, il prossimo e' garantito utile

static var owned := {}      # oggetti inutili in possesso: id -> quantita'
static var tech := 0.0      # livello tecnologico unico del mondo (sale con il futuro evocato)

# --- oggetti utili: effetto immediato. era: p passato, f futuro. lv = livello minimo, w = peso
const USE := {
	"fumo": {"n": "GRANATA FUMOGENA", "era": "f", "lv": 1, "w": 10, "d": "stordisce i nemici vicini"},
	"siringa": {"n": "SIRINGA NANOTECH", "era": "f", "lv": 1, "w": 8, "d": "cura il 45% della vita"},
	"greco": {"n": "FUOCO GRECO", "era": "p", "lv": 1, "w": 10, "d": "brucia i nemici vicini"},
	"plasma": {"n": "COLTELLINO A PLASMA", "era": "f", "lv": 1, "w": 8, "d": "+35% danno per 40s"},
	"oplita": {"n": "SCUDO D'OPLITA", "era": "p", "lv": 2, "w": 8, "d": "scudo che assorbe danni"},
	"mina": {"n": "MINA MAGNETICA", "era": "f", "lv": 3, "w": 8, "d": "esplode davanti a te"},
	"catapulta": {"n": "CATAPULTA TASCABILE", "era": "p", "lv": 5, "w": 7, "d": "masso sul nemico piu' vicino"},
	"ariete": {"n": "ARIETE D'ASSEDIO", "era": "p", "lv": 7, "w": 6, "d": "travolge i nemici davanti a te"},
}
# --- jackpot: alleati temporanei (i mezzi veri arriveranno dopo)
const JACKPOT := {
	"drone": {"n": "DRONE D'ATTACCO", "era": "f", "lv": 4, "w": 3, "d": "combatte per te per 25s"},
	"golem": {"n": "GOLEM DI PIETRA", "era": "p", "lv": 8, "w": 3, "d": "alleato corazzato per 30s"},
	# mezzi: ci sali a bordo. hp base + hpl per livello, t durata, spd velocita', dm danno del colpo (x danno base), cd attesa, pr perforazione, aoe area, crush speronamento
	"carro": {"n": "CARRO DA GUERRA", "era": "p", "lv": 10, "w": 3, "d": "balista perforante; COLPO PESANTE: catapulta", "hp": 120.0, "hpl": 8.0, "t": 35.0, "spd": 1.0, "dm": 2.4, "cd": 0.55, "cd2": 4.0, "pr": 4, "crush": 1.2},
	"tank": {"n": "CARRARMATO", "era": "f", "lv": 14, "w": 3, "d": "mitragliatrice; COLPO PESANTE: cannonata", "hp": 200.0, "hpl": 10.0, "t": 40.0, "spd": 0.75, "dm": 0.45, "cd": 0.09, "cd2": 1.2, "crush": 1.5},
	"ufo": {"n": "MINI-UFO", "era": "f", "lv": 20, "w": 2, "d": "laser a raffica; COLPO PESANTE: onda elettrica", "hp": 140.0, "hpl": 6.0, "t": 30.0, "spd": 1.5, "dm": 0.8, "cd": 0.13, "cd2": 6.0},
}

# --- armi dal futuro: si impugnano subito (come le armi forgiate). f famiglia (rpg.gd), b bonus, a affissi
const GUN := {
	"pistola": {"n": "PISTOLA", "era": "f", "lv": 1, "w": 5, "d": "colpi precisi", "f": "pistol", "b": 0.08, "a": []},
	"pompa": {"n": "FUCILE A POMPA", "era": "f", "lv": 6, "w": 4, "d": "rosa di pallini a bruciapelo", "f": "shotgun", "b": 0.14, "a": []},
	"mitra": {"n": "MITRA", "era": "f", "lv": 8, "w": 4, "d": "raffica rapidissima", "f": "smg", "b": 0.12, "a": []},
	"motosega": {"n": "MOTOSEGA", "era": "f", "lv": 9, "w": 4, "d": "taglia tutto, anche gli alberi", "f": "chainsaw", "b": 0.18, "a": ["sangue"]},
	"laserpistol": {"n": "PISTOLA LASER", "era": "f", "lv": 12, "w": 3, "d": "raggi veloci", "f": "laserpistol", "b": 0.16, "a": ["rapida"]},
	"spadalaser": {"n": "SPADA LASER", "era": "f", "lv": 15, "w": 3, "d": "lama di luce", "f": "lightsaber", "b": 0.24, "a": ["acuta"]},
	"bazooka": {"n": "LANCIARAZZI", "era": "f", "lv": 18, "w": 2, "d": "razzi esplosivi", "f": "rocket", "b": 0.22, "a": ["fuoco"]},
	"fucileplasma": {"n": "FUCILE AL PLASMA", "era": "f", "lv": 22, "w": 2, "d": "globi di plasma", "f": "plasma", "b": 0.30, "a": ["tuono"]},
}

# --- oggetti inutili: vanno alla forgia e diventano arma, armatura o pozione in base all'oggetto
# out.t: w arma, a armatura, b pozione
const JUNK := {
	"tostapane": {"n": "TOSTAPANE", "era": "f", "w": 8, "out": {"t": "w", "f": "staff", "b": 0.12, "a": ["fuoco"], "mods": {"sp": 0.04}, "nm": "Lanciafiamme Domestico"}},
	"racchetta": {"n": "RACCHETTA DA TENNIS", "era": "f", "w": 8, "out": {"t": "w", "f": "sword", "b": 0.10, "a": ["rapida"], "mods": {"cr": 0.04, "sp": 0.06}, "nm": "Racchetta Rimbalzante"}},
	"ombrello": {"n": "OMBRELLO", "era": "f", "w": 7, "out": {"t": "a", "slot": "torso", "n": "MANTELLO PARAPIOGGIA", "st": {"df": 0.09, "mv": 0.04}, "m": "pelle"}},
	"pentola": {"n": "PENTOLA", "era": "p", "w": 7, "out": {"t": "a", "slot": "testa", "n": "ELMO A PENTOLA", "st": {"df": 0.10, "hp": 10.0}, "m": "minerale"}},
	"mazza": {"n": "MAZZA DA BASEBALL", "era": "f", "w": 7, "out": {"t": "w", "f": "hammer", "b": 0.20, "a": [], "mods": {"st": -0.05}, "nm": "Mazza da Fuoricampo", "hs": "hw_bat"}},
	"frullatore": {"n": "FRULLATORE", "era": "f", "w": 6, "out": {"t": "w", "f": "dagger", "b": 0.10, "a": ["rapida", "sangue"], "mods": {}, "nm": "Sega Rotante"}},
	"batteria": {"n": "BATTERIA STILO", "era": "f", "w": 7, "out": {"t": "b", "n": "BATTERIA RICARICATA", "fx": {"base": "mana", "v": 0.5, "dur": 150.0, "buffs": {"b_sp": 0.2}}}},
	"cuscino": {"n": "CUSCINO", "era": "p", "w": 7, "out": {"t": "a", "slot": "gambe", "n": "SCHINIERI IMBOTTITI", "st": {"hp": 20.0, "df": 0.04}, "m": "pelle"}},
	"lampadario": {"n": "LAMPADARIO", "era": "p", "w": 6, "out": {"t": "w", "f": "staff", "b": 0.14, "a": ["tuono"], "mods": {}, "nm": "Lampadario Fulminante"}},
	"aspirapolvere": {"n": "ASPIRAPOLVERE", "era": "f", "w": 6, "out": {"t": "a", "slot": "torso", "n": "ZAINO ASPIRANTE", "st": {"rg": 0.5, "mn": 12.0}, "m": "minerale"}},
	"mattarello": {"n": "MATTARELLO", "era": "p", "w": 7, "out": {"t": "w", "f": "hammer", "b": 0.10, "a": [], "mods": {"sp": 0.06}, "nm": "Mattarello da Battaglia"}},
	"padella": {"n": "PADELLA", "era": "p", "w": 7, "out": {"t": "w", "f": "sword", "b": 0.12, "a": [], "mods": {"cr": 0.03}, "nm": "Padellone Maledetto"}},
	"ferrostiro": {"n": "FERRO DA STIRO", "era": "f", "w": 6, "out": {"t": "w", "f": "hammer", "b": 0.16, "a": ["fuoco"], "mods": {"st": 0.05}, "nm": "Ferro Rovente"}},
	"phon": {"n": "PHON", "era": "f", "w": 6, "out": {"t": "w", "f": "staff", "b": 0.12, "a": ["fuoco"], "mods": {"sp": 0.05}, "nm": "Phon Infernale"}},
	"chitarra": {"n": "CHITARRA ELETTRICA", "era": "f", "w": 5, "out": {"t": "w", "f": "staff", "b": 0.16, "a": ["tuono"], "mods": {}, "nm": "Chitarra Distorta"}},
	"asta_selfie": {"n": "ASTA PER SELFIE", "era": "f", "w": 6, "out": {"t": "w", "f": "spear", "b": 0.12, "a": [], "mods": {"cr": 0.03}, "nm": "Asta Telescopica"}},
	"candeliere": {"n": "CANDELIERE", "era": "p", "w": 6, "out": {"t": "w", "f": "staff", "b": 0.12, "a": ["fuoco"], "mods": {}, "nm": "Candelabro Ardente"}},
	"casco_moto": {"n": "CASCO DA MOTO", "era": "f", "w": 6, "out": {"t": "a", "slot": "testa", "n": "CASCO INTEGRALE", "st": {"df": 0.13, "mv": -0.02}, "m": "minerale"}},
	"giubbotto": {"n": "GIUBBOTTO DI PELLE", "era": "f", "w": 6, "out": {"t": "a", "slot": "torso", "n": "GIUBBOTTO BORCHIATO", "st": {"df": 0.11, "hp": 8.0}, "m": "pelle"}},
	"stivali": {"n": "STIVALI DI GOMMA", "era": "f", "w": 6, "out": {"t": "a", "slot": "gambe", "n": "STIVALI ANTIPIOGGIA", "st": {"df": 0.06, "mv": 0.05}, "m": "pelle"}},
	"skateboard": {"n": "SKATEBOARD", "era": "f", "w": 5, "out": {"t": "a", "slot": "gambe", "n": "SCHINIERI A ROTELLE", "st": {"df": 0.02, "mv": 0.12}, "m": "legna"}},
	"secchio": {"n": "SECCHIO", "era": "p", "w": 6, "out": {"t": "a", "slot": "testa", "n": "ELMO A SECCHIO", "st": {"df": 0.07, "hp": 6.0}, "m": "minerale"}},
	"caffe": {"n": "TAZZA DI CAFFE'", "era": "f", "w": 6, "out": {"t": "b", "n": "ESPRESSO DOPPIO", "fx": {"base": "mana", "v": 0.3, "dur": 120.0, "buffs": {"b_mv": 0.2}}}},
	"energy": {"n": "ENERGY DRINK", "era": "f", "w": 6, "out": {"t": "b", "n": "ENERGY DRINK", "fx": {"base": "heal", "v": 0.2, "dur": 120.0, "buffs": {"b_dm": 0.12}}}},
}


# --- ere del mondo: il livello tecnologico sale con le evocazioni (futuro +1, passato +0.4) e i nemici imparano.
# soglie di tech per l'inizio di ogni era
const ERA_AT := [0.0, 10.0, 30.0, 60.0]
const ERA_N := ["FANTASY", "ALCHIMIA", "STEAMPUNK", "PROTO-INDUSTRIALE"]
const ERA_MSG := [
	"",
	"I NEMICI HANNO RACCOLTO I TUOI RESTI: ORA MISCELANO ESPLOSIVI E ALCHIMIE.",
	"INGRANAGGI E VAPORE: I NEMICI INDOSSANO PIASTRE DI RAME E ARMI A PRESSIONE.",
	"FUMO E ACCIAIO: IL MONDO E' DIVENTATO UNA FONDERIA. NIENTE E' PIU' COME PRIMA.",
]
# tinta del mondo (moltiplica la luce ambiente) e dei nemici
const ERA_WORLD := [Color(1, 1, 1), Color(0.97, 1.04, 0.97), Color(1.08, 1.0, 0.88), Color(0.92, 0.93, 0.97)]
const ERA_FOE := [Color(1, 1, 1), Color(0.95, 1.1, 0.95), Color(1.15, 1.0, 0.8), Color(0.9, 0.92, 1.05)]


static func era() -> int:
	var e := 0
	for i in ERA_AT.size():
		if tech >= float(ERA_AT[i]):
			e = i
	return e


static func era_name() -> String:
	return str(ERA_N[era()])


static func world_tint() -> Color:
	return ERA_WORLD[era()]


## ritocca un nemico appena creato in base all'era: piu' vita e danno, tinta, e qualche tratto tecnologico
static func tune_enemy(e, strong: bool) -> void:
	var n := era()
	if n <= 0:
		return
	var f := 0.5 if strong else 1.0
	e.hp *= 1.0 + 0.08 * n * f
	e.dmg *= 1.0 + 0.06 * n * f
	e.spr.modulate = e.spr.modulate * (ERA_FOE[n] as Color)
	if strong or e.trait_ != "" or e.kind == "rat" or e.kind == "ooze_small":
		return
	var chance: float = [0.0, 0.12, 0.2, 0.3][n]
	if randf() >= chance:
		return
	var pool: Array = [["esplosivo"], ["esplosivo"], ["esplosivo", "corazzato"], ["corazzato", "veloce", "esplosivo"]][n]
	e.trait_ = str(pool.pick_random())
	match e.trait_:
		"veloce":
			e.speed *= 1.4
			e.hp *= 0.85
			e.spr.scale *= 0.92
		"corazzato":
			e.hp *= 1.9
			e.speed *= 0.85
			e.spr.scale *= 1.12
	e.spr.modulate = e.spr.modulate * (Enemy.TRAITS[e.trait_] as Color)
	e.xp = int(e.xp * 1.4)


static func era_lines() -> Array:
	match era():
		1:
			return ["I MOSTRI HANNO IMPARATO A MISCELARE POLVERI. ANDATE VIA, E' PERICOLOSO.", "DICONO CHE SIA COLPA TUA. IO DICO: SII CAUTO CON QUELLE BOLLE."]
		2:
			return ["HO VISTO UN GOBLIN CON UNA CORAZZA DI RAME E UN TUBO FUMANTE!", "IL VAPORE SI VEDE DA MIGLIA. DA DOVE VENGONO QUESTI INGEGNI?"]
		3:
			return ["IL CIELO E' GRIGIO DI FUMO. LE FONDERIE NON SI FERMANO PIU'.", "ABBIAMO IMPARATO TUTTO DA TE... E NON E' STATA UNA BUONA IDEA."]
	return []


static func reset() -> void:
	owned.clear()
	tech = 0.0


## estrazione pesata. pity = oggetti inutili usciti di fila
static func roll(lv: int, pity: int) -> Dictionary:
	# un'arma dal futuro ogni ~8 evocazioni, qualunque sia il resto del pool
	if randf() < GUN_P:
		var gp: Array = []
		var gt := 0.0
		for gid in GUN:
			if lv >= int(GUN[gid]["lv"]):
				gp.append([gid, float(GUN[gid]["w"])])
				gt += float(GUN[gid]["w"])
		var gr := randf() * gt
		for ge in gp:
			gr -= float(ge[1])
			if gr <= 0.0:
				return {"cls": "gun", "id": ge[0]}
	var pool: Array = []
	var tot := 0.0
	for id in USE:
		if lv >= int(USE[id]["lv"]):
			pool.append(["use", id, float(USE[id]["w"])])
	for id in JACKPOT:
		if lv >= int(JACKPOT[id]["lv"]):
			pool.append(["jackpot", id, float(JACKPOT[id]["w"]) + minf(4.0, 0.15 * lv)])
	for id in GUN:
		if lv >= int(GUN[id]["lv"]):
			pool.append(["gun", id, float(GUN[id]["w"])])
	if pity < PITY_MAX:
		for id in JUNK:
			pool.append(["junk", id, float(JUNK[id]["w"])])
	for e in pool:
		tot += float(e[2])
	var r := randf() * tot
	for e in pool:
		r -= float(e[2])
		if r <= 0.0:
			return {"cls": e[0], "id": e[1]}
	return {"cls": "use", "id": "fumo"}


static func name_of(r: Dictionary) -> String:
	match str(r["cls"]):
		"use":
			return str(USE[r["id"]]["n"])
		"jackpot":
			return str(JACKPOT[r["id"]]["n"])
		"gun":
			return str(GUN[r["id"]]["n"])
	return str(JUNK[r["id"]]["n"])


static func era_of(r: Dictionary) -> String:
	match str(r["cls"]):
		"use":
			return str(USE[r["id"]]["era"])
		"jackpot":
			return str(JACKPOT[r["id"]]["era"])
		"gun":
			return "f"
	return str(JUNK[r["id"]]["era"])


## esegue l'evocazione: effetto, bolla e messaggio
static func apply(main, r: Dictionary) -> void:
	var pl: Player = main.player
	var eraid := era_of(r)
	var col := Color(0.55, 0.85, 1.0) if eraid == "f" else Color(1.0, 0.8, 0.45)
	var at: Vector2 = pl.position + pl.face * 18.0
	main.burst(at, col, 26, 70.0, 0.6)
	pl.shock(at, 34, col)
	main.snd("level")
	var era_before := era()
	tech += 1.0 if eraid == "f" else 0.4
	if era() > era_before:
		main.popup(pl.position + Vector2(0, -40), "ERA: " + era_name(), Color(1.0, 0.85, 0.4))
		main.say("NUOVA ERA - %s. %s" % [era_name(), str(ERA_MSG[era()])])
		main.shake(6.0)
	var nm := name_of(r)
	match str(r["cls"]):
		"junk":
			var id := str(r["id"])
			owned[id] = int(owned.get(id, 0)) + 1
			main.popup(pl.position + Vector2(0, -26), nm, Color(0.8, 0.8, 0.85))
			main.say("EVOCATO: %s... FORSE SERVE ALLA FORGIA (ANACRONISMI)" % nm)
			return
		"gun":
			var gd: Dictionary = GUN[str(r["id"])]
			var it := {"k": "w", "f": gd["f"], "r": 0, "b": float(gd["b"]), "a": (gd["a"] as Array).duplicate(), "adj": 0, "mods": {}, "u": 0, "nm": str(gd["n"]).capitalize(), "rc": {}}
			it["r"] = maxi(1, Forge.rarity_of(it))
			main.popup(pl.position + Vector2(0, -26), nm + "!", Color(0.5, 0.95, 1.0))
			main.say("ARMA DAL FUTURO: %s - %s" % [nm, str(gd["d"])])
			main.shake(3.0)
			main._give_weapon(it, "EVOCATO")
			return
		"jackpot":
			_jackpot(main, str(r["id"]))
			main.popup(pl.position + Vector2(0, -26), nm + "!", Color(1.0, 0.85, 0.3))
			main.say("JACKPOT! %s" % nm)
			main.shake(4.0)
			return
	main.popup(pl.position + Vector2(0, -26), nm, col)
	# gli oggetti utili finiscono in borsa (Z cambia, X usa); se non c'e' posto fanno effetto subito
	if main.stock_chrono(str(r["id"]), nm):
		return
	main.say("EVOCATO: %s (BORSA PIENA: USATO SUBITO)" % nm)
	_use(main, str(r["id"]))


static func _near(main, pos: Vector2, rad: float) -> Array:
	var out: Array = []
	for e in main.enemies:
		if e.position.distance_to(pos) < rad + e.radius:
			out.append(e)
	return out


static func _closest(main, pos: Vector2, rad: float):
	var best = null
	var bd := rad
	for e in main.enemies:
		var d: float = e.position.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best


static func _use(main, id: String) -> void:
	var pl: Player = main.player
	match id:
		"fumo":
			for e in _near(main, pl.position, 75.0):
				e.stun = maxf(e.stun, 0.8 if (e.is_boss or e.champ) else 1.8)
				e.apply_status("slow", 4.0, 0.0)
			main.burst(pl.position, Color(0.7, 0.7, 0.75), 40, 60.0, 0.9)
			pl.shock(pl.position, 75, Color(0.7, 0.7, 0.8))
		"siringa":
			pl.hp = minf(pl.max_hp, pl.hp + pl.max_hp * 0.45)
			main.burst(pl.position, Color(0.4, 1.0, 0.7), 20, 40.0, 0.6)
		"greco":
			for e in _near(main, pl.position, 62.0):
				e.hurt(pl.bd() * 1.6, (e.position - pl.position).normalized(), 70.0, false)
				e.apply_status("burn", 4.0, pl.bd() * 0.3)
			main.burst(pl.position, Color(0.4, 1.0, 0.5), 40, 80.0, 0.7)
			pl.shock(pl.position, 62, Color(0.4, 1.0, 0.5))
		"plasma":
			pl.buffs["b_dm"] = maxf(float(pl.buffs.get("b_dm", 0.0)), 40.0)
			pl.bval["b_dm"] = maxf(float(pl.bval.get("b_dm", 0.0)), 0.35)
		"oplita":
			pl.shield = 35.0 + 3.0 * pl.lv
			pl.shield_t = 15.0
		"mina":
			delayed(main, pl.position + pl.face * 28.0, 1.2, 50.0, 3.2, Color(0.5, 0.85, 1.0))
		"catapulta":
			var t = _closest(main, pl.position, 170.0)
			var p: Vector2 = t.position if t != null else pl.position + pl.face * 70.0
			delayed(main, p, 0.9, 46.0, 4.5, Color(1.0, 0.75, 0.35))
		"ariete":
			for e in main.enemies.duplicate():
				var to: Vector2 = e.position - pl.position
				if to.length() < 95.0 and to.dot(pl.face) > 0.0:
					e.hurt(pl.bd() * 2.6, to.normalized(), 260.0, true)
			main.burst(pl.position + pl.face * 40.0, Color(0.85, 0.65, 0.35), 40, 110.0, 0.6)
			pl.shock(pl.position + pl.face * 45.0, 50, Color(0.85, 0.65, 0.35))
			main.shake(4.0)


## esplosione ritardata con avviso a terra
static func delayed(main, pos: Vector2, delay: float, rad: float, mult: float, col: Color) -> void:
	main.player.shock(pos, int(rad * 0.6), col)
	var tm: SceneTreeTimer = main.get_tree().create_timer(delay)
	tm.timeout.connect(func():
		if main.state != "play" or main.player == null:
			return
		for e in _near(main, pos, rad):
			e.hurt(main.player.bd() * mult, (e.position - pos).normalized(), 140.0, false)
		main.burst(pos, col, 44, 100.0, 0.6)
		main.player.shock(pos, int(rad), col)
		main.shake(3.0)
		main.snd("slam"))


static func _jackpot(main, id: String) -> void:
	var pl: Player = main.player
	match id:
		"drone":
			var a := Ally.new()
			a.setup(main)
			a.ttl = 25.0
			a.kind = "drone"
			a.dmg *= 2.0
			a.speed = 100.0
			a.mode = "follow"
			a.spr.modulate = Color(1.4, 0.9, 0.4, 0.95)
			a.position = pl.position + Vector2(0, -10)
			main.ents.add_child(a)
			main.allies.append(a)
		"golem":
			var g := Ally.new()
			g.setup(main)
			g.ttl = 30.0
			g.kind = "golem"
			g.max_hp *= 4.0
			g.hp = g.max_hp
			g.dmg *= 1.6
			g.speed = 60.0
			g.mode = "follow"
			g.spr.modulate = Color(0.75, 0.75, 0.7, 1.0)
			g.spr.scale = Vector2(1.5, 1.5)
			g.position = pl.position + Vector2(0, -10)
			main.ents.add_child(g)
			main.allies.append(g)
		_:
			pl.board(id)
