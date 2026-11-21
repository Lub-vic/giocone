class_name Stats
extends RefCounted
## Attributi del personaggio: a ogni livello si sceglie quale aumentare (come in un souls-like).
## Il danno dell'arma scala con gli attributi che la favoriscono (SCALE: forza, destrezza, intelligenza, fede).

const MAXV := 25

const LIST := [
	{"id": "vig", "n": "VIGORE", "d": "+9 vita massima", "s": "VIT"},
	{"id": "res", "n": "RESISTENZA", "d": "+5 stamina massima, +2% recupero stamina", "s": "RES"},
	{"id": "for", "n": "FORZA", "d": "danno di spadoni, martelli e spade; piu' efficace contro muri e rocce", "s": "FOR"},
	{"id": "des", "n": "DESTREZZA", "d": "danno di pugnali, lance, archi e spade; mira piu' precisa; -1.5% costo stamina; +0.4% critici; rotolata piu' sicura", "s": "DES"},
	{"id": "int", "n": "INTELLIGENZA", "d": "+4 mana, +3.5% potenza magica, +2% recupero mana; danno del bastone", "s": "INT"},
	{"id": "fed", "n": "FEDE", "d": "+2.5 cura per sorso, +3% cure e scudi, -0.6% danni subiti; ogni 8: una fiala in piu'", "s": "FED"},
	{"id": "fort", "n": "FORTUNA", "d": "+0.5% colpi critici, +2% anime dai nemici", "s": "FRT"},
]

# peso di [forza, destrezza, intelligenza, fede] sul danno di ogni famiglia di armi
const SCALE := {
	"sword": [0.6, 0.4, 0.0, 0.0],
	"greatsword": [1.0, 0.0, 0.0, 0.0],
	"spear": [0.35, 0.65, 0.0, 0.0],
	"hammer": [0.75, 0.0, 0.0, 0.25],
	"dagger": [0.15, 0.85, 0.0, 0.0],
	"bow": [0.1, 0.9, 0.0, 0.0],
	"staff": [0.0, 0.0, 0.85, 0.15],
	"pistol": [0.0, 0.8, 0.2, 0.0], "smg": [0.0, 0.7, 0.3, 0.0], "shotgun": [0.3, 0.7, 0.0, 0.0],
	"chainsaw": [0.8, 0.2, 0.0, 0.0], "laserpistol": [0.0, 0.5, 0.5, 0.0], "lightsaber": [0.3, 0.4, 0.3, 0.0],
	"rocket": [0.3, 0.3, 0.4, 0.0], "plasma": [0.0, 0.3, 0.7, 0.0],
}
const PER_POINT := 0.035   # danno in piu' per ogni punto di attributo pesato


## attributi ancora aumentabili, nello stesso formato delle carte di scelta
static func options(attr: Dictionary) -> Array:
	var out: Array = []
	for u in LIST:
		var v := int(attr.get(u["id"], 0))
		if v < MAXV:
			out.append({"id": u["id"], "n": u["n"], "d": u["d"], "max": MAXV, "kind": "a", "rank": v + 1})
	return out


static func name_of(id: String) -> String:
	for u in LIST:
		if u["id"] == id:
			return str(u["n"])
	return id
