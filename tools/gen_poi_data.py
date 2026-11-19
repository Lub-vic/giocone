"""Genera godot/data/poi_templates.json: luoghi di interesse e micro-composizioni (formato modificabile/editor)."""
import json, sys, os
OUT = sys.argv[1] if len(sys.argv) > 1 else "../godot/data/poi_templates.json"
T, M = [], []


def t(id, typ, name, ops, bio=None, r=15, w=1.0, k=True):
    T.append({"id": id, "type": typ, "name": name, "bio": bio or [], "r": r, "w": w, "champ": k, "ops": ops})


def m(id, ops, bio=None, w=1.0):
    M.append({"id": id, "bio": bio or [], "w": w, "ops": ops})


# ---- luoghi legacy (costruttori nel codice)
for lid, typ, nm in [("farm_a", "farm", "FATTORIA BRUCIATA"), ("church_a", "church", "CHIESA ABBANDONATA"), ("mill_a", "mill", "VECCHIO MULINO"),
                     ("altar_a", "altar", "ALTARE NEL BOSCO"), ("bandits_a", "bandits", "ACCAMPAMENTO DI BRIGANTI"), ("tower_a", "tower", "TORRE DI GUARDIA"),
                     ("family_a", "family", "CIMITERO DI FAMIGLIA"), ("cave_a", "cave", "COVO DEL CACCIATORE"), ("well_a", "well", "POZZO MALEDETTO"),
                     ("ruin_a", "ruin", "ROVINE ANTICHE"), ("hamlet_a", "hamlet", "VILLAGGIO ABBANDONATO"), ("mine_a", "mine", "VECCHIA MINIERA")]:
    t(lid, typ, nm, [["legacy", typ]], k=False)

# ---- varianti
t("farm_b", "farm", "FATTORIA IN ROVINA", [["p", "roof_3x3_ash", -7, -5], ["p", "roof_5x3_ash", 1, -2], ["f", -11, -8, 11, -8, 8, 11, False], ["f", -11, 7, 11, 7, 2, 5, False],
    ["r", ["hay_top"], 6, 10, 5], ["p", "cart_top", -4, 4], ["p", "well_top", -1, 2], ["tr", 3, 11, 8], ["r", ["barrel_top", "crate_top", "sack_top"], 5, 9, 6],
    ["e", ["zombie", "ghoul", "skeleton"], 5, 5], ["c", 7, 4, "r"]])
t("farm_c", "farm", "CASOLARE ABBANDONATO", [["p", "roof_4x3_wood", -3, -4], ["r", ["hay_top", "sack_top", "barrel_top"], 6, 8, 6], ["t", "bush_sick_0", -6, 3],
    ["t", "bush_sick_1", 6, 4], ["t", "bush_sick_2", -5, -6], ["tr", 4, 10, 8], ["p", "well_top", 5, 2], ["e", ["skeleton", "rat", "zombie"], 4, 5], ["c", -5, 3, "r"]], r=12)
t("church_b", "church", "CAPPELLA NEL BOSCO", [["p", "chapel_top_slate", -2, -7], ["tr", 6, 12, 9], ["r", ["grave_cross_0", "grave_mound_1", "grave_slab_1"], 8, 9, 6],
    ["pf", "lamp_top", -4, 2], ["e", ["cultist", "skeleton", "ghoul"], 4, 5], ["c", -5, 3, True]], bio=[1, 2, 3])
t("church_c", "church", "CHIESA GHIACCIATA", [["p", "chapel_top_ice", -2, -7], ["r", ["crystal_top_ice", "menhir_top_ice"], 7, 10, 8], ["r", ["grave_cross_0", "grave_slab_0"], 6, 8, 5],
    ["e", ["wraith", "skeleton", "wisp"], 5, 5], ["c", 5, 3, True]], bio=[4, 5])
t("mill_b", "mill", "MULINO IN ROVINA", [["p", "mill_top", -3, -3], ["p", "roof_3x2_rust", 5, -2], ["r", ["wall_top_h2", "wall_top_v2"], 3, 8, 6],
    ["r", ["hay_top", "barrel_top", "sack_top"], 5, 9, 7], ["tr", 3, 11, 9], ["e", ["ghoul", "bat", "zombie"], 4, 5], ["c", -6, 5, "r"]])
t("altar_b", "altar", "CERCHIO DI PIETRE", [["ring", "menhir_top_cem", 7, 7], ["p", "column_top", 0, 0], ["r", ["skullpile", "bone_skull_0"], 3, 5, 5],
    ["e", ["wraith", "cultist"], 4, 5], ["c", 0, 5, True]])
t("altar_c", "altar", "ALTARE DEL GELO", [["ring", "menhir_top_ice", 8, 7], ["a", "altar", 0, 0], ["r", ["crystal_top_ice"], 6, 6, 6],
    ["e", ["wraith", "wisp"], 5, 5], ["c", 0, 5, True]], bio=[5])
t("bandits_b", "bandits", "NIDO DI BRIGANTI", [["p", "tent_top_0", -5, -2], ["p", "tent_top_2", 4, -3], ["pf", "campfire_top", 0, 1], ["p", "stall_top_1", -2, -6], ["p", "cart_top", 7, 3],
    ["r", ["crate_top", "barrel_top", "sack_top"], 5, 8, 5], ["r", ["wall_top_h2", "wall_top_v2"], 3, 9, 6], ["e", ["cultist", "skel_archer", "imp", "wolf"], 6, 6],
    ["c", -4, 3, "r"], ["c", 4, 4, False]])
t("bandits_c", "bandits", "COVO DEI RAZZIATORI", [["ru", -8, -6, 16, 12, "cem"], ["pf", "campfire_top", 0, 1], ["p", "tent_top_1", -3, -2],
    ["r", ["crate_top", "barrel_top"], 5, 7, 5], ["e", ["cultist", "skel_archer", "wolf", "imp"], 7, 6], ["c", 3, -3, "r"], ["c", -4, 3, False]])
t("tower_b", "tower", "TORRE CROLLATA", [["p", "tower_top", -2, -4], ["r", ["wall_top_h2", "wall_top_v2", "wall_top_h3"], 5, 8, 6],
    ["r", ["boulder_cem_0", "boulder_cem_3", "boulder_vil_2"], 4, 8, 6], ["e", ["gargoyle", "skel_archer", "bat"], 5, 5], ["c", 5, 3, "r"]])
t("tower_c", "tower", "AVAMPOSTO", [["p", "tower_top", -2, -5], ["p", "roof_3x2_slate", 4, -1], ["f", -9, -8, 9, -8, 8, 11, False], ["f", -9, 6, 9, 6, 8, 11, False],
    ["pf", "lamp_top", -3, 3], ["pf", "lamp_top", 3, 3], ["r", ["barrel_top", "crate_top"], 4, 7, 5], ["e", ["skel_archer", "skeleton", "skel_archer"], 6, 5], ["c", -5, 2, "r"]])
t("mounds_a", "mounds", "TUMULI ANTICHI", [["ring", "grave_mound_0", 7, 12], ["ring", "grave_mound_1", 4, 6, 0.3], ["p", "tomb", 0, 0], ["ring", "menhir_top_cem", 9, 4],
    ["e", ["ghoul", "wraith", "skeleton"], 5, 5], ["c", 0, 3, True]])
t("family_c", "family", "CRIPTA SEPOLTA", [["p", "mausoleum_top", -5, -3], ["p", "mausoleum_top", 2, -3], ["f", -9, -6, 9, -6, 8, 11, True], ["f", -9, 6, 9, 6, 8, 11, True],
    ["r", ["grave_cross_0", "grave_slab_0", "grave_mound_0", "grave_cross_1"], 9, 8, 5], ["p", "statue_top", 0, 3], ["e", ["ghoul", "skeleton", "wraith"], 5, 5], ["c", 0, 5, True]])
t("cave_b", "cave", "RIFUGIO DEL CACCIATORE", [["p", "roof_2x2_wood", -2, -4], ["pf", "campfire_top", 3, 1], ["r", ["log_top_0", "log_top_3", "hay_top", "sack_top"], 6, 7, 5],
    ["r", ["bone_ribs_0", "bone_skull_2"], 4, 6, 5], ["e", ["wolf", "wolf", "skeleton"], 5, 5], ["c", -3, 2, "r"]])
t("cave_c", "cave", "TANA DEI LUPI", [["ring", "boulder_cem_1", 7, 9], ["r", ["bone_ribs_1", "bone_skull_0", "bone_bones_2"], 7, 6, 5], ["e", ["wolf", "wolf", "wolf"], 7, 6], ["c", 0, 0, True]])
t("well_b", "well", "POZZO DEI SUSSURRI", [["p", "well_top", -1, -1], ["ring", "menhir_top_cem", 5, 6], ["p", "statue_top", 4, 3], ["e", ["wraith", "wisp"], 5, 5], ["c", 0, 4, True]])
t("well_c", "well", "FONTANA SPENTA", [["p", "well_top", -1, -1], ["ring", "column_top", 5, 4, 0.78], ["p", "statue_top", -5, 3], ["p", "statue_top", 5, 3],
    ["e", ["wraith", "wisp", "gargoyle"], 5, 5], ["c", 0, 5, True]])
t("ruin_b", "ruin", "TEMPIO IN ROVINA", [["ru", -10, -7, 20, 14, "cat"], ["r", ["statue_top", "tomb", "column_top"], 4, 8, 6], ["e", ["gargoyle", "skeleton", "wraith"], 6, 6], ["c", 0, 0, True]])
t("ruin_c", "ruin", "AVAMPOSTO CROLLATO", [["r", ["wall_top_h3", "wall_top_v3", "column_top", "boulder_cat_2"], 12, 10, 8], ["p", "statue_top", 0, 0],
    ["e", ["skeleton", "skel_archer", "gargoyle"], 6, 6], ["c", 2, 2, True]])
t("hamlet_b", "hamlet", "BORGATA SACCHEGGIATA", [["ha", 5, "village"], ["r", ["cart_top", "hay_top", "barrel_top"], 5, 9, 7], ["e", ["zombie", "ghoul", "skeleton", "rat"], 8, 7], ["c", 3, 5, "r"]])
t("hamlet_c", "hamlet", "CASOLARI VUOTI", [["ha", 3, "village"], ["f", -10, -8, 10, -8, 8, 11, False], ["e", ["zombie", "rat"], 6, 6], ["c", 0, 5, "r"]], r=13)
t("quarry_a", "quarry", "CAVA DI PIETRA", [["r", ["boulder_for_0", "boulder_for_2", "boulder_cem_4", "boulder_vil_5"], 14, 11, 9], ["p", "anvil_top", 3, 2], ["p", "cart_top", -5, 3],
    ["r", ["crate_top", "barrel_top"], 5, 8, 6], ["e", ["imp", "ooze", "gargoyle", "skeleton"], 5, 6], ["c", 5, -4, True]])
t("mine_b", "mine", "FORNACE SPENTA", [["p", "smithy_top", -3, -4], ["a", "brazier", 3, 2], ["p", "anvil_top", 5, 2], ["r", ["crate_top", "barrel_top", "sack_top"], 5, 8, 6],
    ["e", ["imp", "ooze"], 5, 5], ["c", -5, -3, True]])
t("gallows_a", "gallows", "LA FORCA DEI CORVI", [["t", "top_dead_1", 0, -2], ["t", "top_dead_2", -5, 1], ["t", "top_dead_0", 5, 2], ["p", "coffin", -2, 3], ["p", "coffin", 2, 4],
    ["r", ["skullpile", "bone_skull_1", "bone_ribs_2"], 6, 6, 6], ["e", ["ghoul", "wraith", "crow", "crow"], 6, 6], ["c", 0, 3, True]])
t("scarecrow_a", "scarecrow", "CAMPO DEGLI SPAVENTAPASSERI", [["r", ["hay_top"], 9, 10, 7], ["tr", 7, 9, 7], ["f", -12, -9, 12, -9, 10, 13, False], ["f", -12, 8, 12, 8, 10, 13, False],
    ["e", ["zombie", "crow", "ghoul", "crow"], 7, 8], ["c", 0, 0, "r"]])
t("hermit_a", "hermit", "EREMITAGGIO", [["p", "roof_2x2_thatch", -2, -3], ["p", "well_top", 4, 1], ["r", ["hay_top", "sack_top", "barrel_top"], 4, 6, 5], ["t", "bush_sick_0", -5, 2],
    ["t", "bush_sick_1", 5, -3], ["t", "bush_sick_3", 0, 5], ["p", "tomb", -6, -4], ["e", ["skeleton", "rat"], 3, 4], ["c", -4, 3, True]], r=11)
t("witch_a", "witch", "CERCHIO DELLA STREGA", [["ring", "menhir_top_cem", 7, 7], ["pf", "cauldron_top", 0, 0], ["r", ["bone_skull_3", "bone_ribs_3", "skullpile"], 5, 5, 5],
    ["t", "bush_sick_2", 3, 4], ["t", "bush_sick_1", -4, -3], ["e", ["cultist", "wisp", "wraith"], 6, 6], ["c", 0, 4, True]], bio=[2, 3])
t("orchard_a", "orchard", "FRUTTETO MORTO", [["grid", "top_sick_", -8, -6, 5, 4, 4], ["r", ["hay_top", "cart_top"], 3, 9, 7], ["e", ["zombie", "crow", "ghoul"], 6, 7], ["c", 0, 8, "r"]])
t("toll_a", "toll", "CASELLO ABBANDONATO", [["p", "roof_3x2_slate", -2, -4], ["f", -9, 0, 9, 0, 7, 10, False], ["pf", "lamp_top", -3, 2], ["pf", "lamp_top", 3, 2], ["p", "cart_top", 6, 3],
    ["r", ["barrel_top", "crate_top"], 4, 7, 5], ["e", ["skeleton", "skel_archer", "skeleton"], 5, 5], ["c", -5, 3, "r"]])
t("caravan_a", "caravan", "CAROVANA DISTRUTTA", [["p", "cart_top", -6, 0], ["p", "cart_top", 0, 2], ["p", "cart_top", 6, -1], ["r", ["crate_top", "barrel_top", "sack_top"], 10, 9, 5],
    ["r", ["bone_ribs_0", "bone_skull_4", "skullpile"], 5, 8, 5], ["e", ["skeleton", "cultist", "wolf"], 6, 7], ["c", -3, 3, True], ["c", 4, 3, "r"]])
t("crossroads_a", "crossroads", "BIVIO DEL SANTUARIO", [["p", "statue_top", 0, -1], ["pf", "lamp_top", -3, 1], ["pf", "lamp_top", 3, 1],
    ["r", ["grave_cross_0", "grave_cross_2", "grave_slab_2"], 4, 5, 4], ["a", "candelabra", -2, 2], ["a", "candelabra", 2, 2], ["e", ["wraith", "skeleton"], 4, 4], ["c", 0, 4, True]], r=10)
t("barn_a", "barn", "VECCHIO FIENILE", [["p", "roof_5x3_wood", -3, -3], ["r", ["hay_top"], 8, 9, 8], ["p", "cart_top", -6, 4], ["tr", 3, 10, 8],
    ["e", ["rat", "zombie", "rat", "ghoul"], 6, 6], ["c", 5, 5, "r"]])
t("obelisks_a", "obelisks", "CAMPO DI OBELISCHI", [["ring", "grave_obelisk_0", 8, 8], ["ring", "grave_obelisk_2", 4, 4, 0.4], ["r", ["crystal_top_cat"], 3, 6, 6],
    ["e", ["wraith", "gargoyle", "wisp"], 5, 6], ["c", 0, 0, True]])

# ---- micro-composizioni (dettagli sparsi ovunque)
m("cairn", [["r", ["boulder_cem_0", "boulder_cem_1", "boulder_vil_0"], 4, 2, 2]])
m("log_funghi", [["p", "log_top_1", 0, 0], ["p", "log_top_3", 2, 1]], [2, 3])
m("tomba_sola", [["p", "grave_cross_1", 0, 0], ["p", "grave_mound_2", 1, 1], ["t", "top_dead_1", -2, 0]])
m("ossa", [["r", ["bone_ribs_0", "bone_skull_0", "bone_bones_1", "skullpile"], 4, 2, 2]])
m("resti_falo", [["pf", "campfire_top", 0, 0], ["p", "log_top_0", -2, 1], ["p", "log_top_2", 2, 1], ["p", "sack_top", 1, -2]])
m("carro_vecchio", [["p", "cart_top", 0, 0], ["r", ["crate_top", "barrel_top"], 3, 3, 2]])
m("spaventapasseri", [["t", "top_dead_0", 0, 0], ["p", "hay_top", 1, 1], ["p", "hay_top", -2, 1]], [0, 2])
m("cerchio_pietre", [["ring", "boulder_vil_3", 3, 6]])
m("alberi_secchi", [["tr", 5, 4, 4]])
m("recinto_rotto", [["f", -4, 0, 4, 0, 2, 4, False]], [0, 2, 3])
m("pozzo_solo", [["p", "well_top", 0, 0], ["r", ["barrel_top", "sack_top"], 2, 2, 2]], [0, 2, 3])
m("lampione", [["pf", "lamp_top", 0, 0]], [0, 1, 4, 6])
m("tombe", [["r", ["grave_cross_0", "grave_mound_0", "grave_slab_3", "grave_cross_3"], 6, 4, 3]], [0, 1, 4])
m("ceppi", [["ring", "stump_top", 3, 5]], [2, 3])
m("tenda_abbandonata", [["p", "tent_top_0", 0, 0], ["r", ["sack_top", "log_top_0"], 2, 3, 2]])
m("macerie", [["r", ["wall_top_h2", "wall_top_v2", "boulder_for_0", "boulder_cat_3"], 5, 3, 3]], [0, 1, 4, 6])
m("obelisco", [["p", "grave_obelisk_1", 0, 0], ["r", ["bone_skull_2"], 2, 2, 2]], [1, 4])
m("cristalli", [["r", ["crystal_top_ice", "crystal_top_cat"], 4, 3, 3]], [4, 5])
m("fieno", [["r", ["hay_top"], 4, 3, 2]], [0, 2])
m("appostamento", [["p", "roof_2x2_wood", 0, 0], ["p", "log_top_1", 3, 1]], [2, 5])
m("statua_sola", [["p", "statue_top", 0, 0], ["pf", "lamp_top", 2, 1]], [1, 4])
m("colonne", [["r", ["column_top", "wall_top_h2"], 3, 3, 2]], [1, 4, 6])
m("ossa_palude", [["r", ["bone_ribs_3", "bone_skull_3", "log_top_2"], 4, 4, 3]], [3])
m("viandante_gelato", [["p", "grave_cross_2", 0, 0], ["r", ["crystal_top_ice"], 2, 2, 2], ["p", "sack_top", 1, 1]], [5])
m("rottami_fucina", [["p", "anvil_top", 0, 0], ["r", ["crate_top", "barrel_top"], 3, 3, 2]], [6])
m("capanna_bruciata", [["p", "roof_2x2_ash", 0, 0], ["tr", 2, 3, 3]], [0, 6])
m("mausoleo", [["p", "mausoleum_top", 0, 0], ["r", ["grave_cross_0", "grave_slab_1"], 2, 4, 3]], [1, 4], 0.5)
m("bare", [["p", "coffin", 0, 0], ["p", "coffin", 2, 0], ["p", "coffin", 4, 0]], [1, 2])
m("bancarella", [["p", "stall_top_0", 0, 0], ["r", ["crate_top", "sack_top"], 2, 3, 2]], [0, 6])
m("pattuglia", [["r", ["skullpile"], 1, 2, 2], ["e", ["skeleton", "skeleton", "skel_archer"], 3, 4]], [], 0.7)
m("tana_lupi", [["r", ["bone_ribs_1", "boulder_for_2"], 3, 3, 3], ["e", ["wolf", "wolf"], 3, 4]], [2, 5], 0.7)
m("nascondiglio", [["r", ["boulder_cem_2", "skullpile"], 2, 3, 3], ["c", 0, 0, True]], [], 0.35)
m("baule_perso", [["c", 0, 0, "r"], ["p", "cart_top", 3, 0]], [], 0.4)
m("forca", [["t", "top_dead_2", 0, 0], ["p", "coffin", 2, 2], ["p", "skullpile", -2, 2]], [1, 2, 3])
m("camposanto", [["gy", -4, -3, 9, 7, 0]], [0, 1, 4], 0.5)
m("croce_santuario", [["p", "grave_cross_4", 0, 0], ["pf", "lamp_top", -2, 1], ["a", "candelabra", 2, 1]], [0, 1, 2, 4])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
json.dump({"templates": T, "micro": M}, open(OUT, "w", encoding="utf8"), ensure_ascii=False, indent=1)
print(len(T), "luoghi,", len(M), "micro-composizioni")
