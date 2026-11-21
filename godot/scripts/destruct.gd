class_name Destruct
extends RefCounted
## Distruttibilita' del mondo: ogni oggetto ha un materiale e una resistenza; ogni arma e' piu' o meno adatta.
## Un albero cade in pochi colpi, un muro ne chiede centinaia (migliaia con l'arma sbagliata).

# efficienza dell'arma (famiglia) contro il materiale
const EFF := {
	"legno": {"sword": 1.0, "greatsword": 1.6, "spear": 0.7, "hammer": 1.0, "dagger": 0.45, "bow": 0.1, "staff": 0.1, "pistol": 0.15, "smg": 0.2, "shotgun": 0.5, "chainsaw": 2.5, "laserpistol": 0.3, "lightsaber": 1.8, "rocket": 1.0, "plasma": 0.6},
	"molle": {"sword": 1.0, "greatsword": 1.2, "spear": 1.0, "hammer": 0.9, "dagger": 0.8, "bow": 0.1, "staff": 0.1, "pistol": 0.15, "smg": 0.2, "shotgun": 0.5, "chainsaw": 2.0, "laserpistol": 0.3, "lightsaber": 2.0, "rocket": 1.0, "plasma": 0.6},
	"pietra": {"sword": 0.12, "greatsword": 0.35, "spear": 0.10, "hammer": 1.0, "dagger": 0.05, "bow": 0.02, "staff": 0.02, "pistol": 0.03, "smg": 0.04, "shotgun": 0.1, "chainsaw": 0.4, "laserpistol": 0.1, "lightsaber": 0.5, "rocket": 2.0, "plasma": 0.5},
	"metallo": {"sword": 0.08, "greatsword": 0.15, "spear": 0.05, "hammer": 0.6, "dagger": 0.03, "bow": 0.01, "staff": 0.01, "pistol": 0.02, "smg": 0.03, "shotgun": 0.05, "chainsaw": 0.2, "laserpistol": 0.08, "lightsaber": 0.4, "rocket": 1.5, "plasma": 0.4},
}
const TOOL := {"legno": "UNA LAMA PESANTE", "molle": "QUALSIASI ARMA", "pietra": "UN MARTELLO", "metallo": "UN MARTELLO"}
const COL := {
	"legno": Color(0.45, 0.30, 0.18), "molle": Color(0.62, 0.55, 0.35),
	"pietra": Color(0.55, 0.53, 0.58), "metallo": Color(0.5, 0.45, 0.42),
}


## None se indistruttibile. Altrimenti {m: materiale, hp: resistenza, d: drop}
static func classify(name: String) -> Dictionary:
	if name.begins_with("top_") or name.begins_with("tree_") or name.begins_with("deadtree"):
		return {"m": "legno", "hp": 90.0, "d": "albero"}
	if name.begins_with("tbig_"):
		return {"m": "legno", "hp": 170.0, "d": "albero"}
	if name.begins_with("bush_") or name.begins_with("shrub_") or name.begins_with("tall_"):
		return {"m": "molle", "hp": 22.0, "d": "arbusto"}
	if name.begins_with("stump_big"):
		return {"m": "legno", "hp": 220.0, "d": "legna"}
	if name.begins_with("stump") or name.begins_with("log_"):
		return {"m": "legno", "hp": 45.0, "d": "legna"}
	if name.begins_with("barrel") or name.begins_with("crate") or name.begins_with("coffin"):
		return {"m": "legno", "hp": 24.0, "d": "legna"}
	if name.begins_with("hay") or name.begins_with("sack") or name.begins_with("tent_top"):
		return {"m": "molle", "hp": 20.0, "d": "erba"}
	if name.begins_with("fence_") and name.ends_with("wood"):
		return {"m": "legno", "hp": 40.0, "d": "legna"}
	if name.begins_with("fence_"):
		return {"m": "metallo", "hp": 130.0, "d": "ferro"}
	if name.begins_with("cart_top") or name.begins_with("wagon") or name.begins_with("table_top") or name.begins_with("chair_top") or name.begins_with("stall"):
		return {"m": "legno", "hp": 70.0, "d": "legna"}
	if name.begins_with("skullpile") or name.begins_with("bone_"):
		return {"m": "molle", "hp": 30.0, "d": "osso"}
	if name.begins_with("grave_") or name.begins_with("cross_") or name.begins_with("gravestone"):
		return {"m": "pietra", "hp": 90.0, "d": "pietra"}
	if name.begins_with("tomb"):
		return {"m": "pietra", "hp": 220.0, "d": "pietra"}
	if name.begins_with("menhir"):
		return {"m": "pietra", "hp": 320.0, "d": "pietra"}
	if name.begins_with("crystal"):
		return {"m": "pietra", "hp": 150.0, "d": "cristallo"}
	if name.begins_with("lamp"):
		return {"m": "metallo", "hp": 80.0, "d": "ferro"}
	if name.begins_with("column"):
		return {"m": "pietra", "hp": 520.0, "d": "pietra"}
	if name.begins_with("statue"):
		return {"m": "pietra", "hp": 760.0, "d": "pietra"}
	if name.begins_with("well_"):
		return {"m": "pietra", "hp": 450.0, "d": "pietra"}
	if name.begins_with("wall_top") or name.begins_with("ruinwall"):
		return {"m": "pietra", "hp": 1300.0, "d": "pietra"}
	if name.begins_with("arch_top") or name.begins_with("circle_top"):
		return {"m": "pietra", "hp": 1500.0, "d": "pietra"}
	if name.begins_with("ruin_tower"):
		return {"m": "pietra", "hp": 3200.0, "d": "pietra"}
	if name.begins_with("anvil"):
		return {"m": "metallo", "hp": 600.0, "d": "ferro"}
	return {}


## muro di roccia del terreno (dirupi, mura delle forge...): quasi inattaccabile senza martello
static func terrain(biome: int) -> Dictionary:
	if biome == 1 or biome == 2:
		return {"m": "legno", "hp": 90.0, "d": "albero"}
	return {"m": "pietra", "hp": 3000.0, "d": "roccia"}


static func eff(fam: String, mat: String) -> float:
	return float((EFF[mat] as Dictionary).get(fam, 0.1))
