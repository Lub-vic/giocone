class_name Upgrades
extends RefCounted
## Potenziamenti selezionabili al falo'. Ogni livello = una scelta fra 3.
## Somma dei gradi massimi = 88 livelli di progressione.

const LIST := [
	{"id": "vigor", "n": "VIGORE", "d": "+15 vita massima", "max": 10},
	{"id": "endur", "n": "RESISTENZA", "d": "+12 stamina massima", "max": 10},
	{"id": "forza", "n": "FORZA", "d": "+12% danno", "max": 10},
	{"id": "destr", "n": "DESTREZZA", "d": "-6% costo stamina", "max": 6},
	{"id": "ritmo", "n": "RESPIRO", "d": "+15% recupero stamina", "max": 6},
	{"id": "armor", "n": "CORAZZA", "d": "-5% danni subiti", "max": 8},
	{"id": "fiale", "n": "FIALA EXTRA", "d": "+1 carica di fiala", "max": 4},
	{"id": "elisir", "n": "ELISIR", "d": "+10 cura per sorso", "max": 6},
	{"id": "crit", "n": "OCCHIO DI FALCO", "d": "+4% colpi critici", "max": 8},
	{"id": "fortuna", "n": "AVIDITA", "d": "+10% anime dai nemici", "max": 6},
	{"id": "sangue", "n": "SETE DI SANGUE", "d": "+3 vita per uccisione", "max": 6},
	{"id": "agile", "n": "PASSO FANTASMA", "d": "+0.03s invulnerabilita' rotolata", "max": 4},
	{"id": "lama", "n": "LAMA LUNGA", "d": "+3 portata dell'arma", "max": 4},
	{"id": "mente", "n": "MENTE ACUTA", "d": "+12 mana, +10% magie", "max": 8},
	{"id": "incanto", "n": "INCANTESIMO", "d": "+12% potenza magica", "max": 8},
]


static func cost(lv: int) -> int:
	return int(130.0 * pow(float(lv), 1.7))


static func total_max() -> int:
	var n := 0
	for u in LIST:
		n += int(u["max"])
	return n


static func roll(rk: Dictionary) -> Array:
	var pool: Array = []
	for u in LIST:
		if int(rk.get(u["id"], 0)) < int(u["max"]):
			pool.append(u)
	pool.shuffle()
	return pool.slice(0, 3)
