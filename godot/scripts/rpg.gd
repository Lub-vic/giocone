class_name Rpg
extends RefCounted
## Classi, famiglie di armi, rarita', affissi e magie.

const FAM := {
	"sword": {"n": "Spada", "reach": 29.0, "arc": 1.0, "lm": 1.0, "hm": 2.3, "lc": 18.0, "hc": 34.0, "lcd": 0.34, "hcd": 0.6, "hw": 0.38, "ranged": false, "icon": "w_sword"},
	"greatsword": {"n": "Spadone", "reach": 37.0, "arc": 1.3, "lm": 1.5, "hm": 3.0, "lc": 26.0, "hc": 42.0, "lcd": 0.5, "hcd": 0.8, "hw": 0.5, "ranged": false, "icon": "w_greatsword"},
	"spear": {"n": "Lancia", "reach": 42.0, "arc": 0.45, "lm": 1.0, "hm": 2.0, "lc": 18.0, "hc": 30.0, "lcd": 0.36, "hcd": 0.6, "hw": 0.34, "ranged": false, "icon": "w_spear"},
	"hammer": {"n": "Martello", "reach": 28.0, "arc": 1.1, "lm": 1.7, "hm": 3.2, "lc": 28.0, "hc": 44.0, "lcd": 0.55, "hcd": 0.85, "hw": 0.5, "ranged": false, "icon": "w_hammer"},
	"dagger": {"n": "Pugnali", "reach": 22.0, "arc": 1.2, "lm": 0.6, "hm": 1.4, "lc": 10.0, "hc": 24.0, "lcd": 0.18, "hcd": 0.45, "hw": 0.25, "ranged": false, "icon": "w_dagger"},
	"bow": {"n": "Arco", "reach": 0.0, "arc": 0.0, "lm": 1.0, "hm": 2.4, "lc": 14.0, "hc": 30.0, "lcd": 0.45, "hcd": 0.8, "hw": 0.5, "ranged": true, "icon": "w_bow"},
	"staff": {"n": "Bastone", "reach": 0.0, "arc": 0.0, "lm": 0.9, "hm": 2.0, "lc": 10.0, "hc": 26.0, "lcd": 0.42, "hcd": 0.8, "hw": 0.4, "ranged": true, "icon": "w_staff"},
}
const RARITY := [
	{"n": "COMUNE", "c": Color(0.78, 0.78, 0.84), "b": 0.0, "aff": 0},
	{"n": "RARA", "c": Color(0.4, 0.65, 1.0), "b": 0.12, "aff": 1},
	{"n": "EPICA", "c": Color(0.75, 0.45, 1.0), "b": 0.25, "aff": 2},
	{"n": "LEGGENDARIA", "c": Color(1.0, 0.75, 0.25), "b": 0.45, "aff": 3},
]
const AFF := {
	"fuoco": {"n": "di Fuoco", "d": "brucia"}, "gelo": {"n": "del Gelo", "d": "rallenta"},
	"sangue": {"n": "di Sangue", "d": "ruba vita"}, "acuta": {"n": "Acuminata", "d": "+8% critico"},
	"rapida": {"n": "Rapida", "d": "colpi piu' veloci"},
}
const ADJ := [["Semplice", "Pesante", "Comune", "Resistente"], ["Affilata", "Temprata", "Solida"], ["Maledetta", "Sacra", "Antica"],
	["dell'Eclissi", "del Re Pallido", "delle Ceneri"]]

const CLASSES := {
	"cavaliere": {"n": "CAVALIERE", "spr": "hero", "hp": 120.0, "st": 100.0, "mana": 30.0, "spd": 80.0, "regen": 1.0, "weapon": "sword",
		"spells": ["scudo", "nova"], "d": "Resistente e bilanciato. Spada, scudo sacro e nova di fuoco."},
	"cacciatore": {"n": "CACCIATORE", "spr": "hunter", "hp": 90.0, "st": 120.0, "mana": 50.0, "spd": 90.0, "regen": 1.0, "weapon": "bow",
		"spells": ["dardo", "rigenera"], "d": "Veloce, colpisce da lontano con l'arco e si rigenera."},
	"negromante": {"n": "NEGROMANTE", "spr": "necro", "hp": 80.0, "st": 90.0, "mana": 100.0, "spd": 82.0, "regen": 1.6, "weapon": "staff",
		"spells": ["dardo", "fulmine"], "d": "Fragile ma devastante: dardi d'ombra e catene di fulmini."},
	"chierico": {"n": "CHIERICO", "spr": "cleric", "hp": 110.0, "st": 100.0, "mana": 80.0, "spd": 80.0, "regen": 1.3, "weapon": "hammer",
		"spells": ["cura", "scudo"], "d": "Martello e fede: cura se stesso e si protegge."},
}
const SPELLS := {
	"dardo": {"n": "Dardo d'Ombra", "cost": 14.0, "cd": 0.6, "d": "proiettile che trapassa"},
	"nova": {"n": "Nova di Fuoco", "cost": 28.0, "cd": 2.5, "d": "esplosione attorno a te"},
	"fulmine": {"n": "Catena di Fulmini", "cost": 26.0, "cd": 2.0, "d": "colpisce fino a 4 nemici"},
	"gelo": {"n": "Raggio di Gelo", "cost": 22.0, "cd": 1.8, "d": "cono che rallenta"},
	"cura": {"n": "Guarigione", "cost": 50.0, "cd": 14.0, "d": "cura subito"},
	"rigenera": {"n": "Rigenerazione", "cost": 44.0, "cd": 16.0, "d": "cura nel tempo"},
	"scudo": {"n": "Scudo Sacro", "cost": 36.0, "cd": 10.0, "d": "assorbe danni"},
}


static func roll_rarity(w: Array) -> int:
	var tot := 0.0
	for x in w:
		tot += float(x)
	var r := randf() * tot
	for i in w.size():
		r -= float(w[i])
		if r <= 0.0:
			return i
	return 0


static func make_weapon(rar: int, fam := "") -> Dictionary:
	var fams := FAM.keys()
	var f: String = fam if fam != "" else fams[randi() % fams.size()]
	var b: float = RARITY[rar]["b"] * randf_range(0.8, 1.25)
	var pool := AFF.keys()
	pool.shuffle()
	var a: Array = []
	for i in int(RARITY[rar]["aff"]):
		a.append(pool[i])
	return {"k": "w", "f": f, "r": rar, "b": b, "a": a, "adj": randi() % 4}


static func random_weapon(weights: Array) -> Dictionary:
	return make_weapon(roll_rarity(weights))


static func wname(w: Dictionary) -> String:
	var r: int = int(w["r"])
	var adj: Array = ADJ[r]
	var s: String = FAM[w["f"]]["n"] + " " + adj[int(w.get("adj", 0)) % adj.size()]
	if r >= 1 and w["a"].size() > 0 and r < 3:
		s = FAM[w["f"]]["n"] + " " + AFF[w["a"][0]]["n"]
	return s


static func wdesc(w: Dictionary) -> String:
	var parts: Array = []
	parts.append("DANNO +%d%%" % int(round(float(w["b"]) * 100.0)))
	for a in w["a"]:
		parts.append(str(AFF[a]["d"]).to_upper())
	return "  ".join(parts)


const SHORT := {"dardo": "DARDO", "nova": "NOVA", "fulmine": "FULMINE", "gelo": "GELO", "cura": "CURA", "rigenera": "RIGENERA", "scudo": "SCUDO"}
const ASHORT := {"fuoco": "FUOCO", "gelo": "GELO", "sangue": "SANGUE", "acuta": "CRIT", "rapida": "VELOCE"}


static func wshort(w: Dictionary) -> String:
	var s := "+%d%%" % int(round(float(w["b"]) * 100.0))
	for a in w["a"]:
		s += " " + str(ASHORT[a])
	return s


static func cd_mult(w: Dictionary) -> float:
	var n := 0
	for a in w["a"]:
		if a == "rapida":
			n += 1
	return pow(0.88, n)


static func crit_bonus(w: Dictionary) -> float:
	var n := 0
	for a in w["a"]:
		if a == "acuta":
			n += 1
	return 0.08 * n


static func clean(w) -> Dictionary:
	# dopo il caricamento da JSON: tipi interi corretti
	var out := {"k": "w", "f": str(w["f"]), "r": int(w["r"]), "b": float(w["b"]), "a": [], "adj": int(w.get("adj", 0))}
	for a in w["a"]:
		out["a"].append(str(a))
	return out
