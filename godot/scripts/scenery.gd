class_name Scenery
extends RefCounted
## Regole di arredo del mondo (vista dall'alto): cosa spargere, dove e con che densita' (per regione).

const PAL := ["vil", "cem", "for", "swa", "cat", "ice", "frg"]
# oggetti che emettono luce: prefisso nome -> [colore, scala, energia]
const GLOW := {
	"menhir_top_cem": [Color(0.45, 0.6, 1.0), 1.4, 0.7], "menhir_top_ice": [Color(0.5, 0.95, 1.0), 1.4, 0.8],
	"menhir_top_cat": [Color(0.85, 0.5, 1.0), 1.4, 0.7], "crystal_top_ice": [Color(0.5, 0.8, 1.0), 1.3, 0.6],
	"crystal_top_cat": [Color(0.8, 0.45, 1.0), 1.3, 0.6], "spire_top": [Color(1.0, 0.4, 0.12), 1.6, 0.7],
	"lamp_top": [Color(1.0, 0.68, 0.32), 1.7, 0.55], "smithy_top": [Color(1.0, 0.45, 0.12), 2.6, 1.0],
	"hearth_top": [Color(1.0, 0.55, 0.2), 2.2, 0.9], "cauldron_top": [Color(0.4, 1.0, 0.5), 1.4, 0.6],
	"campfire_top": [Color(1.0, 0.55, 0.2), 2.4, 0.9], "circle_top": [Color(0.6, 0.35, 1.0), 2.0, 0.7],
}

static var CLUTTER: Array = _mk_clutter()
static var OBJECTS: Array = _mk_objects()


static func N(p: String, n: int) -> Array:
	var a: Array = []
	for i in n:
		a.append("%s_%d" % [p, i])
	return a


static func F(ids: Array) -> Array:
	var a: Array = []
	for i in ids:
		for j in 4:
			a.append("flower_%d_%d" % [i, j])
	return a


static func W() -> Array:
	var a: Array = []
	for nm in ["h2", "h3", "v2", "v3"]:
		for v in 4:
			a.append("wall_top_%s_%d" % [nm, v])
	return a


static func glow(name: String) -> Array:
	for k in GLOW:
		if name.begins_with(k):
			return GLOW[k]
	return []


static func _mk_clutter() -> Array:
	var bones: Array = N("bone_skull", 5) + N("bone_ribs", 5) + N("bone_bones", 5)
	return [
		[{"n": N("grass_vil", 10), "d": 0.09, "cf": 0.05, "ct": 0.25}, {"n": N("tall_vil", 8), "d": 0.035},
			{"n": N("pebble_vil", 10), "d": 0.04}, {"n": F([1, 2]), "d": 0.01, "cf": 0.08, "ct": 0.6},
			{"n": N("bone_bones", 5) + N("bone_skull", 5), "d": 0.003},
			{"n": ["pumpkins"], "d": 0.006, "cf": 0.06, "ct": 0.62}, {"n": ["broken_wheel"], "d": 0.0015}],
		[{"n": N("grass_cem", 10), "d": 0.12, "cf": 0.04, "ct": 0.25}, {"n": N("tall_cem", 8), "d": 0.05, "cf": 0.05, "ct": 0.45},
			{"n": N("shrub_cem", 8), "d": 0.03, "cf": 0.04, "ct": 0.5}, {"n": N("pebble_cem", 10), "d": 0.05},
			{"n": F([0, 2]), "d": 0.04, "cf": 0.07, "ct": 0.62}, {"n": bones, "d": 0.012}],
		[{"n": N("grass_for", 10), "d": 0.16, "cf": 0.04, "ct": 0.2}, {"n": N("tall_for", 8), "d": 0.09, "cf": 0.05, "ct": 0.4},
			{"n": N("shrub_for", 8), "d": 0.06, "cf": 0.05, "ct": 0.45}, {"n": N("pebble_for", 10), "d": 0.04},
			{"n": N("mush_purple", 6) + N("mush_glow", 6), "d": 0.03, "cf": 0.09, "ct": 0.6},
			{"n": bones, "d": 0.008}, {"n": ["fern"], "d": 0.05, "cf": 0.05, "ct": 0.5},
			{"n": ["mushroom_ring"], "d": 0.0012}, {"n": ["antler_skull"], "d": 0.0018}],
		[{"n": N("grass_swa", 10), "d": 0.13, "cf": 0.04, "ct": 0.25}, {"n": N("tall_swa", 8), "d": 0.08, "cf": 0.05, "ct": 0.4},
			{"n": N("reeds", 6), "d": 0.30, "edge": true}, {"n": N("shrub_swa", 8), "d": 0.03, "cf": 0.05, "ct": 0.5},
			{"n": N("mush_glow", 6) + N("mush_red", 6), "d": 0.04, "cf": 0.08, "ct": 0.58},
			{"n": N("pebble_swa", 10), "d": 0.03}, {"n": bones, "d": 0.006},
			{"n": ["lilypond"], "d": 0.006, "cf": 0.05, "ct": 0.55}],
		[{"n": N("pebble_cat", 10), "d": 0.09}, {"n": N("grass_cat", 10), "d": 0.06, "cf": 0.05, "ct": 0.4},
			{"n": N("shrub_cat", 8), "d": 0.012, "cf": 0.05, "ct": 0.55}, {"n": bones, "d": 0.012},
			{"n": F([0, 3]), "d": 0.008, "cf": 0.07, "ct": 0.65},
			{"n": ["rubble_small"], "d": 0.02, "cf": 0.06, "ct": 0.5}, {"n": ["statue_head"], "d": 0.002}],
		[{"n": N("grass_ice", 10), "d": 0.11, "cf": 0.05, "ct": 0.3}, {"n": N("tall_ice", 8), "d": 0.04, "cf": 0.06, "ct": 0.5},
			{"n": N("pebble_ice", 10), "d": 0.07}, {"n": N("shrub_ice", 8), "d": 0.035, "cf": 0.05, "ct": 0.5},
			{"n": ["snowdrift"], "d": 0.03, "cf": 0.04, "ct": 0.5}, {"n": ["frozen_body"], "d": 0.0015}],
		[{"n": N("grass_frg", 10), "d": 0.06, "cf": 0.05, "ct": 0.4}, {"n": N("tall_frg", 8), "d": 0.03, "cf": 0.06, "ct": 0.5},
			{"n": N("shrub_frg", 8), "d": 0.035, "cf": 0.05, "ct": 0.5}, {"n": N("pebble_frg", 10), "d": 0.09},
			{"n": bones, "d": 0.02}, {"n": ["slag_heap"], "d": 0.012, "cf": 0.05, "ct": 0.55}],
	]


# oggetti BLOCCANTI sparsi (tutti visti dall'alto)
static func _mk_objects() -> Array:
	var walls: Array = W()
	var base: Array = [
		[{"n": N("stump_top", 4), "d": 0.0046}, {"n": N("boulder_vil", 8), "d": 0.0046}, {"n": ["barrel_top", "crate_top", "hay_top"], "d": 0.0069},
			{"n": walls, "d": 0.004, "cf": 0.05, "ct": 0.5}, {"n": ["cart_top"], "d": 0.0015}, {"n": ["tomb"], "d": 0.0012}, {"n": N("bush_sick", 10), "d": 0.004},
			{"n": ["woodpile"], "d": 0.004, "cf": 0.05, "ct": 0.55}, {"n": ["signpost"], "d": 0.001}],
		[{"n": N("grave_cross", 5) + N("grave_mound", 5), "d": 0.023, "cf": 0.05, "ct": 0.5}, {"n": N("grave_slab", 5), "d": 0.0092, "cf": 0.05, "ct": 0.5},
			{"n": ["statue_top"], "d": 0.0034}, {"n": N("boulder_cem", 8), "d": 0.0092}, {"n": ["column_top"], "d": 0.0046, "cf": 0.06, "ct": 0.5},
			{"n": walls, "d": 0.0046, "cf": 0.06, "ct": 0.5}, {"n": ["menhir_top_cem"], "d": 0.0011}, {"n": ["tomb"], "d": 0.0069}],
		[{"n": N("stump_top", 4), "d": 0.0138}, {"n": N("log_top", 5), "d": 0.0138}, {"n": N("boulder_for", 8), "d": 0.0092},
			{"n": N("bush_sick", 10), "d": 0.023}, {"n": ["skullpile"], "d": 0.0046}, {"n": ["coffin"], "d": 0.0034},
			{"n": ["mossy_rock"], "d": 0.008, "cf": 0.05, "ct": 0.5}],
		[{"n": N("stump_top", 4), "d": 0.0138}, {"n": N("log_top", 5), "d": 0.0138}, {"n": N("boulder_swa", 8), "d": 0.0115},
			{"n": N("bush_sick", 10), "d": 0.0184}, {"n": ["skullpile"], "d": 0.0046},
			{"n": ["menhir_top_cem"], "d": 0.0006}, {"n": walls, "d": 0.002, "cf": 0.05, "ct": 0.6},
			{"n": ["rowboat"], "d": 0.0012}, {"n": ["gibbet"], "d": 0.0015, "cf": 0.04, "ct": 0.55}],
		[{"n": ["column_top"], "d": 0.0207, "cf": 0.06, "ct": 0.45}, {"n": walls, "d": 0.0138, "cf": 0.06, "ct": 0.45},
			{"n": ["statue_top"], "d": 0.0046}, {"n": N("boulder_cat", 8), "d": 0.0069}, {"n": ["menhir_top_cat"], "d": 0.0014},
			{"n": ["tomb"], "d": 0.0069}, {"n": ["broken_pew"], "d": 0.003, "cf": 0.05, "ct": 0.5}],
		[{"n": N("boulder_ice", 8), "d": 0.0207}, {"n": ["crystal_top_ice"], "d": 0.0138, "cf": 0.06, "ct": 0.5},
			{"n": ["menhir_top_ice"], "d": 0.0014}, {"n": N("log_top", 5), "d": 0.0046}, {"n": N("bush_frost", 10), "d": 0.0184},
			{"n": walls, "d": 0.003, "cf": 0.05, "ct": 0.55}, {"n": ["statue_top"], "d": 0.0012},
			{"n": ["ice_spikes"], "d": 0.007, "cf": 0.05, "ct": 0.55}],
		[{"n": ["barrel_top", "crate_top", "cart_top"], "d": 0.0092}, {"n": N("boulder_vil", 8), "d": 0.0069},
			{"n": ["column_top"], "d": 0.0046}, {"n": walls, "d": 0.0069}, {"n": ["skullpile"], "d": 0.0034},
			{"n": ["ore_cart"], "d": 0.003}, {"n": ["chain_post"], "d": 0.003, "cf": 0.05, "ct": 0.55}],
	]
	# strutture grandi per variare il paesaggio (vista dall'alto)
	var big: Array = [
		[[N("ruin_tower", 3), 0.0007], [N("arch_top", 2), 0.0006], [N("bone_pit", 2), 0.0004]],
		[[N("arch_top", 2), 0.0007], [N("circle_top", 2), 0.0005], [N("ruin_tower", 3), 0.0005]],
		[[N("stump_big", 3), 0.0008], [N("circle_top", 2), 0.0004], [N("pond_top", 3), 0.0006]],
		[[N("pond_swa", 3), 0.0014], [N("stump_big", 3), 0.0006]],
		[[N("arch_top", 2), 0.0008], [N("bone_pit", 2), 0.0005]],
		[[N("circle_top", 2), 0.0005], [N("ruin_tower", 3), 0.0004]],
		[[N("bone_pit", 2), 0.0004]],
	]
	for bi in big.size():
		for e in big[bi]:
			base[bi].append({"n": e[0], "d": e[1]})
	return base
