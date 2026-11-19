class_name Relics
extends RefCounted
## Reliquie: oggetti passivi che si accumulano (stack) e si combinano. Ogni copia aggiunge poco: la crescita e' graduale.

const LIST := [
	{"id": "corvo", "n": "DENTE DI CORVO", "d": "+7% VELOCITA' D'ATTACCO", "w": 10},
	{"id": "cenere", "n": "SIGILLO DI CENERE", "d": "8% UCCISIONE ESPLODE IN CENERE", "w": 7},
	{"id": "brace", "n": "BRACIERE SPEZZATO", "d": "10% COLPO BRUCIA IL NEMICO", "w": 9},
	{"id": "lanterna", "n": "LANTERNA A GAS", "d": "+4% VELOCITA' DI MOVIMENTO", "w": 10},
	{"id": "nodo", "n": "NODO FUNEBRE", "d": "+1 VITA PER UCCISIONE", "w": 9},
	{"id": "catena", "n": "CATENA D'OSSA", "d": "12% COLPO SALTA AL NEMICO VICINO", "w": 6},
	{"id": "moneta", "n": "MONETA D'ARGENTO", "d": "+6% ANIME DAI NEMICI", "w": 10},
	{"id": "pietra", "n": "CUORE DI PIETRA", "d": "+6 VITA, -2.5% DANNI SUBITI", "w": 8},
]


static func info(id: String) -> Dictionary:
	for r in LIST:
		if r["id"] == id:
			return r
	return {}


static func roll() -> String:
	var tot := 0
	for r in LIST:
		tot += int(r["w"])
	var x := randi() % tot
	for r in LIST:
		x -= int(r["w"])
		if x < 0:
			return str(r["id"])
	return "corvo"
