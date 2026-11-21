class_name Forge
extends RefCounted
## Artigianato componibile: armi, modifiche alle armi, armature e pozioni.
## Ogni scelta (materiale, parte, essenza, qualita', dose) somma i suoi modificatori: le combinazioni sono migliaia.

const TABS := ["ARMA", "MODIFICA", "ARMATURA", "POZIONI", "ANACRON."]
const MAT_N := {"": "NESSUNO", "erba": "ERBE", "fungo": "FUNGHI", "legna": "LEGNA", "minerale": "MINERALE", "pelle": "PELLE", "carne": "CARNE", "osso": "OSSA"}

# ------------------------------------------------------------------ armi
# modificatori: dm danno, sp velocita' (riduce l'attesa fra i colpi), cr critico, rc portata, st costo stamina
const FAMS := ["sword", "greatsword", "spear", "hammer", "dagger", "bow", "staff"]
const HEAD := {
	"minerale": {"n": "FERRO", "adj": "di Ferro", "dm": 0.18, "sp": -0.04},
	"osso": {"n": "OSSO", "adj": "d'Osso", "dm": 0.10, "cr": 0.05},
	"legna": {"n": "QUERCIA", "adj": "di Quercia", "dm": 0.04, "sp": 0.08},
	"pelle": {"n": "CUOIO", "adj": "di Cuoio", "dm": 0.02, "sp": 0.05, "st": -0.10},
}
const GRIP := {
	"legna": {"n": "LEGNO", "sp": 0.06},
	"osso": {"n": "OSSO", "cr": 0.03, "rc": 2.0},
	"pelle": {"n": "CUOIO", "st": -0.12},
	"minerale": {"n": "FERRO", "dm": 0.06, "sp": -0.03},
}
# essenze: aggiungono un affisso (si possono accumulare con le modifiche)
const ESS := {
	"": {"n": "NESSUNA", "cost": {}},
	"fuoco": {"n": "FUOCO", "cost": {"legna": 2, "minerale": 1}},
	"gelo": {"n": "GELO", "cost": {"fungo": 2, "osso": 1}},
	"sangue": {"n": "SANGUE", "cost": {"carne": 2, "osso": 1}},
	"acuta": {"n": "ACUMINATA", "cost": {"minerale": 2, "osso": 1}},
	"rapida": {"n": "RAPIDA", "cost": {"pelle": 2, "legna": 1}},
	"tuono": {"n": "TUONO", "cost": {"minerale": 1, "fungo": 2}},
	"veleno": {"n": "VELENO", "cost": {"fungo": 2, "erba": 2}},
}
const ESS_ADJ := {"fuoco": "di Fuoco", "gelo": "del Gelo", "sangue": "di Sangue", "acuta": "del Taglio", "rapida": "del Vento", "tuono": "del Tuono", "veleno": "del Veleno"}
const MODS := [
	{"id": "rinforza", "n": "RINFORZA", "d": "+6% danno", "cost": {"minerale": 3, "legna": 1}},
	{"id": "alleggerisci", "n": "ALLEGGERISCI", "d": "+5% velocita', -2% danno", "cost": {"legna": 2, "pelle": 1}},
	{"id": "allunga", "n": "ALLUNGA", "d": "+3 portata", "cost": {"legna": 2, "osso": 1}},
	{"id": "bilancia", "n": "BILANCIA", "d": "+3% critico", "cost": {"osso": 2, "minerale": 1}},
	{"id": "concia", "n": "CONCIA L'IMPUGNATURA", "d": "-8% costo stamina", "cost": {"pelle": 2, "erba": 1}},
	{"id": "infondi", "n": "INFONDI ESSENZA", "d": "aggiunge l'essenza scelta", "cost": {}},
	{"id": "purifica", "n": "PURIFICA", "d": "toglie l'ultima essenza", "cost": {"erba": 2}},
]

# ------------------------------------------------------------------ armature
# df difesa, hp vita, st stamina, mn mana, mv velocita' di movimento, rg rigenerazione/s, th spine (danno restituito), cr critico, sp potere magico
const PIECES := ["testa", "torso", "gambe"]
const PIECE_N := {"testa": "ELMO", "torso": "CORAZZA", "gambe": "SCHINIERI"}
const PIECE_M := {"testa": 0.6, "torso": 1.0, "gambe": 0.7}
const ARM_MAT := {
	"pelle": {"adj": "DI CUOIO", "df": 0.05, "st": 15.0, "mv": 0.03},
	"osso": {"adj": "D'OSSO", "df": 0.07, "th": 0.15, "cr": 0.02},
	"minerale": {"adj": "DI FERRO", "df": 0.12, "hp": 15.0, "mv": -0.05},
	"legna": {"adj": "DI LEGNO", "df": 0.06, "hp": 8.0, "rg": 0.3},
}
const PAD := {
	"": {"n": ""},
	"erba": {"n": "ALLE ERBE", "rg": 0.4},
	"fungo": {"n": "ALLE SPORE", "mn": 15.0, "sp": 0.06},
	"carne": {"n": "DEL VIGORE", "hp": 12.0},
	"pelle": {"n": "CON IMBOTTITURA", "st": 10.0},
	"osso": {"n": "CON SPUNTONI", "cr": 0.02, "th": 0.05},
	"minerale": {"n": "CON BORCHIE", "df": 0.03},
	"legna": {"n": "CON LISTELLI", "mv": 0.02},
}
const ASTAT_N := {"df": "DIFESA", "hp": "VITA", "st": "STAMINA", "mn": "MANA", "mv": "VELOCITA'", "rg": "RIGENERA", "th": "SPINE", "cr": "CRITICO", "sp": "MAGIA"}
const PCT := ["df", "mv", "th", "cr", "sp"]

# ------------------------------------------------------------------ pozioni
const BASES := {
	"erba": {"n": "INFUSO", "fx": "heal", "v": 0.25, "d": "cura il 25% della vita"},
	"carne": {"n": "STUFATO", "fx": "heal", "v": 0.45, "d": "cura il 45% della vita"},
	"fungo": {"n": "ELISIR", "fx": "mana", "v": 0.6, "d": "ridà il 60% del mana"},
	"osso": {"n": "POLVERE", "fx": "flask", "v": 1.0, "d": "+1 fiala"},
}
# additivi: un effetto a tempo; due uguali raddoppiano
const ADDS := {
	"erba": {"n": "SALVIA", "b": "b_rg", "v": 1.5, "d": "rigenera %.1f vita/s"},
	"fungo": {"n": "SPORE", "b": "b_sp", "v": 0.15, "d": "+%d%% potere magico"},
	"legna": {"n": "BRACE", "b": "fuoco", "v": 1.0, "d": "l'arma brucia"},
	"minerale": {"n": "FERRO", "b": "b_df", "v": 0.12, "d": "+%d%% difesa"},
	"pelle": {"n": "VENTO", "b": "b_mv", "v": 0.10, "d": "+%d%% velocita'"},
	"carne": {"n": "SANGUE", "b": "b_dm", "v": 0.15, "d": "+%d%% danno"},
	"osso": {"n": "OSSA", "b": "b_cr", "v": 0.08, "d": "+%d%% critico"},
}
const BUFF_N := {"b_rg": "RIGENERA", "b_sp": "MAGIA", "fuoco": "FUOCO", "b_df": "DIFESA", "b_mv": "VELOCITA", "b_dm": "DANNO", "b_cr": "CRITICO",
	"forza": "FORZA", "pelle": "PELLE"}
const DOSE_P := [0.7, 1.0, 1.4]
const DOSE_T := [90.0, 150.0, 240.0]
const DOSE_N := [" LEGGERO", "", " FORTE"]


static func buff_name(k: String) -> String:
	return str(BUFF_N.get(k, k.to_upper()))


## le scelte di ogni scheda: [etichetta, [[id, nome], ...]]
static func slots(tab: int) -> Array:
	match tab:
		0:
			var fams: Array = []
			for f in FAMS:
				fams.append([f, str(Rpg.FAM[f]["n"]).to_upper()])
			return [["TIPO", fams], ["LAMA / TESTA", _opts(HEAD.keys(), false)], ["IMPUGNATURA", _opts(GRIP.keys(), false)],
				["ESSENZA", _ess_opts()], ["QUALITA'", [[1, "1"], [2, "2"], [3, "3"], [4, "4"], [5, "5"]]]]
		1:
			var ms: Array = []
			for m in MODS:
				ms.append([m["id"], m["n"]])
			return [["OPERAZIONE", ms], ["ESSENZA", _ess_opts().slice(1)]]
		2:
			var ps: Array = []
			for pc in PIECES:
				ps.append([pc, PIECE_N[pc]])
			return [["PEZZO", ps], ["MATERIALE", _opts(ARM_MAT.keys(), false)], ["IMBOTTITURA", _opts(PAD.keys(), true)],
				["QUALITA'", [[1, "1"], [2, "2"], [3, "3"], [4, "4"], [5, "5"]]]]
		4:
			var js: Array = []
			for k in Chrono.JUNK:
				if int(Chrono.owned.get(k, 0)) > 0:
					js.append([k, "%s x%d" % [Chrono.JUNK[k]["n"], int(Chrono.owned[k])]])
			if js.is_empty():
				js.append(["", "NESSUNO"])
			return [["OGGETTO", js]]
		_:
			return [["BASE", _base_opts()], ["ADDITIVO 1", _opts([""] + ADDS.keys(), true)], ["ADDITIVO 2", _opts([""] + ADDS.keys(), true)],
				["DOSE", [[1, "LEGGERA"], [2, "NORMALE"], [3, "FORTE"]]]]


static func _opts(keys: Array, allow_none: bool) -> Array:
	var out: Array = []
	for k in keys:
		if k == "" and not allow_none:
			continue
		out.append([k, str(MAT_N[k])])
	return out


static func _ess_opts() -> Array:
	var out: Array = []
	for k in ESS:
		out.append([k, str(ESS[k]["n"])])
	return out


static func _base_opts() -> Array:
	var out: Array = []
	for k in BASES:
		out.append([k, "%s (%s)" % [BASES[k]["n"], MAT_N[k]]])
	return out


static func _add(cost: Dictionary, mat: String, n: int) -> void:
	if mat == "" or n <= 0:
		return
	cost[mat] = int(cost.get(mat, 0)) + n


## calcola costo, descrizione e risultato di una combinazione. roll=true aggiunge la piccola variazione casuale.
static func make(tab: int, v: Array, p, roll := false) -> Dictionary:
	match tab:
		0:
			return _make_weapon(v, roll)
		1:
			return _make_mod(v, p)
		2:
			return _make_armor(v, p)
		4:
			return _make_junk(v)
		_:
			return _make_brew(v)


## oggetto evocato dal passato/futuro -> arma, armatura o pozione in base a cosa e'
static func _make_junk(v: Array) -> Dictionary:
	var id := str(v[0])
	if id == "" or int(Chrono.owned.get(id, 0)) <= 0:
		return {"cost": {}, "lines": ["NESSUN OGGETTO ANACRONISTICO", "EVOCA CON N (SELECT)"], "item": {}, "err": "NESSUN OGGETTO"}
	var j: Dictionary = Chrono.JUNK[id]
	var o: Dictionary = j["out"]
	var lines: Array = ["%s -> %s" % [j["n"], str(o.get("nm", o.get("n", ""))).to_upper()]]
	var it := {}
	match str(o["t"]):
		"w":
			var mods: Dictionary = (o["mods"] as Dictionary).duplicate()
			it = {"k": "w", "f": o["f"], "r": 0, "b": float(o["b"]), "a": (o["a"] as Array).duplicate(), "adj": 0, "mods": mods, "u": 0, "nm": o["nm"], "rc": {}}
			it["r"] = rarity_of(it)
			it["ic"] = "ch_" + id                      # l'arma conserva l'icona dell'oggetto da cui nasce
			if o.has("hs"):
				it["hs"] = o["hs"]
			lines.append("ARMA: %s" % str(Rpg.FAM[o["f"]]["n"]).to_upper())
			lines.append_array(wlines(it))
		"a":
			it = {"slot": o["slot"], "n": o["n"], "st": (o["st"] as Dictionary).duplicate(), "q": 3, "m": o["m"], "rc": {}}
			lines.append("ARMATURA: %s" % str(PIECE_N[o["slot"]]))
			lines.append_array(alines(it["st"]))
		_:
			var bid := "b:junk:%s" % id
			it = {"id": bid, "n": o["n"], "fx": (o["fx"] as Dictionary).duplicate(true)}
			lines.append("POZIONE")
			lines.append_array(brew_lines(it["fx"]))
	it["t"] = str(o["t"])
	it["junk"] = id
	return {"cost": {}, "lines": lines, "item": it, "err": ""}


static func _make_weapon(v: Array, roll: bool) -> Dictionary:
	var fam: String = v[0]
	var hm: String = v[1]
	var gm: String = v[2]
	var es: String = v[3]
	var q: int = int(v[4])
	var qf := 0.6 + 0.2 * q
	var h: Dictionary = HEAD[hm]
	var g: Dictionary = GRIP[gm]
	var vr := randf_range(0.92, 1.08) if roll else 1.0
	var mods := {}
	for k in ["sp", "cr", "rc", "st"]:
		var x := (float(h.get(k, 0.0)) + float(g.get(k, 0.0))) * qf
		if absf(x) > 0.0001:
			mods[k] = x * vr
	var b := ((float(h.get("dm", 0.0)) + float(g.get("dm", 0.0))) * qf + 0.03 * q) * vr
	var aff: Array = [] if es == "" else [es]
	var w := {"k": "w", "f": fam, "r": 0, "b": b, "a": aff, "adj": 0, "mods": mods, "u": 0,
		"nm": "%s %s%s" % [Rpg.FAM[fam]["n"], h["adj"], ("" if es == "" else " " + str(ESS_ADJ[es]))]}
	w["r"] = rarity_of(w)
	var cost := {}
	w["rc"] = cost   # costo di creazione: smontando se ne recupera meta'
	_add(cost, hm, 2 * q)
	_add(cost, gm, q)
	if es != "":
		var ec: Dictionary = ESS[es]["cost"]
		for k in ec:
			_add(cost, k, int(ec[k]) * int(ceil(q / 2.0)))
	var lines: Array = ["%s  (%s)" % [str(w["nm"]).to_upper(), Rpg.RARITY[int(w["r"])]["n"]]]
	lines.append_array(wlines(w, roll == false))
	return {"cost": cost, "lines": lines, "item": w}


## rarita' (colore e nome) in base alla potenza totale dell'arma
static func rarity_of(w: Dictionary) -> int:
	var m: Dictionary = w.get("mods", {})
	var pw := float(w["b"]) + float(m.get("sp", 0.0)) + 2.0 * float(m.get("cr", 0.0)) + 0.01 * float(m.get("rc", 0.0)) - 0.5 * float(m.get("st", 0.0)) + 0.12 * (w["a"] as Array).size()
	if pw < 0.22:
		return 0
	if pw < 0.45:
		return 1
	if pw < 0.75:
		return 2
	return 3


static func wlines(w: Dictionary, approx := false) -> Array:
	var m: Dictionary = w.get("mods", {})
	var pre := "~" if approx else ""
	var out: Array = ["DANNO %s+%d%%" % [pre, int(round(float(w["b"]) * 100.0))]]
	if m.has("sp"):
		out.append("VELOCITA' %s%+d%%" % [pre, int(round(float(m["sp"]) * 100.0))])
	if m.has("cr"):
		out.append("CRITICO %s+%.1f%%" % [pre, float(m["cr"]) * 100.0])
	if m.has("rc"):
		out.append("PORTATA %s+%.1f" % [pre, float(m["rc"])])
	if m.has("st"):
		out.append("STAMINA %s%+d%%" % [pre, int(round(float(m["st"]) * 100.0))])
	var ess: Array = []
	for a in w["a"]:
		ess.append(str(Rpg.ASHORT.get(a, a)))
	if not ess.is_empty():
		out.append("ESSENZE: " + " ".join(ess))
	return out


static func mod_cost_mult(w: Dictionary) -> float:
	return 1.0 + 0.4 * float(w.get("u", 0))


static func _make_mod(v: Array, p) -> Dictionary:
	var w: Dictionary = (p.weapon() as Dictionary).duplicate(true)
	var op: String = v[0]
	var es: String = v[1]
	var md: Dictionary = {}
	for m in MODS:
		if m["id"] == op:
			md = m
	var cm := mod_cost_mult(w)
	var cost := {}
	var base_cost: Dictionary = md["cost"] if op != "infondi" else ESS[es]["cost"]
	for k in base_cost:
		_add(cost, k, int(ceil(float(base_cost[k]) * cm * (2.0 if op == "infondi" else 1.0))))
	if not w.has("mods"):
		w["mods"] = {}
	var mods: Dictionary = w["mods"]
	var err := ""
	match op:
		"rinforza":
			w["b"] = float(w["b"]) + 0.06
		"alleggerisci":
			mods["sp"] = float(mods.get("sp", 0.0)) + 0.05
			w["b"] = float(w["b"]) - 0.02
		"allunga":
			mods["rc"] = float(mods.get("rc", 0.0)) + 3.0
		"bilancia":
			mods["cr"] = float(mods.get("cr", 0.0)) + 0.03
		"concia":
			mods["st"] = float(mods.get("st", 0.0)) - 0.08
			if float(mods["st"]) < -0.6:
				err = "L'IMPUGNATURA NON PUO' ESSERE PIU' LEGGERA"
		"infondi":
			(w["a"] as Array).append(es)
		"purifica":
			if (w["a"] as Array).is_empty():
				err = "L'ARMA NON HA ESSENZE"
			else:
				(w["a"] as Array).pop_back()
	if op != "purifica":
		w["u"] = int(w.get("u", 0)) + 1
	w["r"] = maxi(int(w["r"]), rarity_of(w))
	var lines: Array = [str(md["n"]) + ": " + str(md["d"]), "SU: " + Rpg.wname(p.weapon()).to_upper(), "MODIFICHE FATTE: %d (COSTO x%.1f)" % [int(w.get("u", 0)) - (0 if op == "purifica" else 1), cm]]
	lines.append_array(wlines(w))
	return {"cost": cost, "lines": lines, "item": w, "err": err}


static func _make_armor(v: Array, p) -> Dictionary:
	var pc: String = v[0]
	var mm: String = v[1]
	var pd: String = v[2]
	var q: int = int(v[3])
	var qf := (0.6 + 0.2 * q) * float(PIECE_M[pc])
	var st := {}
	for src in [ARM_MAT[mm], PAD[pd]]:
		for k in src:
			if k in ["n", "adj"]:
				continue
			st[k] = float(st.get(k, 0.0)) + float(src[k]) * qf
	var nm: String = "%s %s%s" % [PIECE_N[pc], ARM_MAT[mm]["adj"], ("" if pd == "" else " " + str(PAD[pd]["n"]))]
	var cost := {}
	var piece := {"slot": pc, "n": nm, "st": st, "q": q, "m": mm, "rc": cost}
	_add(cost, mm, int(ceil(3.0 * float(PIECE_M[pc]) * q)))
	_add(cost, pd, q)
	var lines: Array = [nm]
	lines.append_array(alines(st))
	var old: Dictionary = p.armor.get(pc, {})
	if not old.is_empty():
		lines.append("SOSTITUISCE: " + str(old["n"]))
	return {"cost": cost, "lines": lines, "item": piece}


static func alines(st: Dictionary) -> Array:
	var out: Array = []
	for k in ASTAT_N:
		if not st.has(k):
			continue
		var x := float(st[k])
		if k in PCT:
			out.append("%s %+.1f%%" % [ASTAT_N[k], x * 100.0])
		elif k == "rg":
			out.append("%s %+.2f/s" % [ASTAT_N[k], x])
		else:
			out.append("%s %+d" % [ASTAT_N[k], int(round(x))])
	return out


static func _make_brew(v: Array) -> Dictionary:
	var bs: String = v[0]
	var a1: String = v[1]
	var a2: String = v[2]
	var d: int = int(v[3])
	var pm: float = DOSE_P[d - 1]
	var adds: Array = []
	for a in [a1, a2]:
		if a != "":
			adds.append(a)
	adds.sort()
	var b: Dictionary = BASES[bs]
	var fx := {"base": b["fx"], "v": float(b["v"]) * (pm if b["fx"] != "flask" else 1.0), "dur": DOSE_T[d - 1], "buffs": {}}
	if b["fx"] == "flask" and d == 3:
		fx["v"] = 2.0
	var bf: Dictionary = fx["buffs"]
	for a in adds:
		var ad: Dictionary = ADDS[a]
		bf[ad["b"]] = float(bf.get(ad["b"], 0.0)) + float(ad["v"]) * pm
	var names: Array = []
	for a in adds:
		if not names.has(ADDS[a]["n"]):
			names.append(ADDS[a]["n"])
	var nm: String = str(b["n"]) + ("" if names.is_empty() else " DI " + " E ".join(names)) + DOSE_N[d - 1]
	var id: String = "b:%s:%s:%d" % [bs, ",".join(adds), d]
	var cost := {}
	_add(cost, bs, 2 * d)
	for a in adds:
		_add(cost, a, d)
	var lines: Array = [nm]
	lines.append_array(brew_lines(fx))
	return {"cost": cost, "lines": lines, "item": {"id": id, "n": nm, "fx": fx}}


static func brew_lines(fx: Dictionary) -> Array:
	var out: Array = []
	match str(fx["base"]):
		"chrono":
			out.append(str(Chrono.USE[str(fx["cid"])]["d"]).to_upper())
		"heal":
			out.append("CURA %d%% DELLA VITA" % int(round(float(fx["v"]) * 100.0)))
		"mana":
			out.append("MANA +%d%%" % int(round(float(fx["v"]) * 100.0)))
		"flask":
			out.append("+%d FIALA" % int(fx["v"]))
	var bf: Dictionary = fx["buffs"]
	for k in bf:
		var x := float(bf[k])
		match k:
			"b_rg":
				out.append("RIGENERA %.1f VITA/S" % x)
			"fuoco":
				out.append("ARMA INFUOCATA")
			_:
				out.append("%s +%d%%" % [buff_name(k), int(round(x * 100.0))])
	if not bf.is_empty():
		out.append("DURATA %d:%02d" % [int(fx["dur"]) / 60, int(fx["dur"]) % 60])
	return out
