extends Node2D
## Mondo esterno vasto (7 regioni) + dungeon, tutto generato da codice.

# dimensioni del mondo (tile) e fattore di scala del disegno originale (300 x 220)
const WORLD_W := 960
const WORLD_H := 704
const WS := 3.2
const CH := 32
# centri delle regioni nel disegno originale (indice = id bioma in Game.BIO)
const BASE_SEEDS := [Vector2i(45, 185), Vector2i(130, 170), Vector2i(55, 105), Vector2i(140, 100),
	Vector2i(245, 115), Vector2i(245, 45), Vector2i(245, 190)]
const BASE_RIVERS := [
	[Vector2i(95, 4), Vector2i(90, 50), Vector2i(94, 100), Vector2i(88, 150), Vector2i(92, 216)],
	[Vector2i(195, 4), Vector2i(190, 60), Vector2i(196, 110), Vector2i(192, 160), Vector2i(198, 216)],
]
var SEEDS: Array[Vector2i] = []
var ENTR := {}
var RIVERS: Array = []
var PASSAGES: Array = []


func init_layout() -> void:
	SEEDS.clear()
	for v in BASE_SEEDS:
		SEEDS.append(Vector2i(roundi(v.x * WS), roundi(v.y * WS)))
	# gli ingressi restano alla stessa distanza dal proprio centro regione
	ENTR = {"d0": SEEDS[2] + Vector2i(-3, 45), "d1": SEEDS[1] + Vector2i(22, -22), "d2": SEEDS[4] + Vector2i(27, -17),
		"d3": SEEDS[6] + Vector2i(35, 15), "dF": SEEDS[3] + Vector2i(10, -72), "d4": SEEDS[2] + Vector2i(-25, -37),
		"d5": SEEDS[3] + Vector2i(25, -34), "d6": SEEDS[5] + Vector2i(25, -27),
		"d7": SEEDS[1] + Vector2i(-22, 18)}
	RIVERS = []
	for rv in BASE_RIVERS:
		var pts: Array = []
		for pt in rv:
			pts.append(Vector2i(roundi(pt.x * WS), roundi(pt.y * WS)))
		RIVERS.append(pts)
	bio_w = BIO_W.duplicate()
	var lay: Dictionary = edits_data().get("layout", {})
	if lay.has("seeds") and (lay["seeds"] as Array).size() == SEEDS.size():
		for i in SEEDS.size():
			SEEDS[i] = Vector2i(int(lay["seeds"][i][0]), int(lay["seeds"][i][1]))
		ENTR = {"d0": SEEDS[2] + Vector2i(-3, 45), "d1": SEEDS[1] + Vector2i(22, -22), "d2": SEEDS[4] + Vector2i(27, -17),
			"d3": SEEDS[6] + Vector2i(35, 15), "dF": SEEDS[3] + Vector2i(10, -72), "d4": SEEDS[2] + Vector2i(-25, -37),
			"d5": SEEDS[3] + Vector2i(25, -34), "d6": SEEDS[5] + Vector2i(25, -27),
		"d7": SEEDS[1] + Vector2i(-22, 18)}
	if lay.has("weights") and (lay["weights"] as Array).size() == bio_w.size():
		bio_w = (lay["weights"] as Array).duplicate()
	if lay.has("rivers"):
		RIVERS = []
		for rv in lay["rivers"]:
			var pts2: Array = []
			for pt in rv:
				pts2.append(Vector2i(int(pt[0]), int(pt[1])))
			RIVERS.append(pts2)
	PASSAGES = [
		{"id": "p_bosco", "a": SEEDS[2] + Vector2i(-17, -17), "b": SEEDS[3] + Vector2i(-16, -40), "msg": "UN PASSAGGIO SOTTO IL FIUME"},
		{"id": "p_est", "a": SEEDS[4] + Vector2i(-13, 25), "b": SEEDS[6] + Vector2i(-17, -22), "msg": "UNA GALLERIA FRA LE ROVINE E LE FONDERIE"},
	]


# collegamenti fra le regioni (indici di SEEDS). I fiumi dividono il mondo in ovest / centro / est.
# peso di ciascuna regione (la vetta gelata e' solo una sacca a nord)
const BIO_W := [1.0, 1.1, 1.1, 1.1, 1.15, 0.55, 0.95]
var bio_w: Array = BIO_W.duplicate()
var bio_ovr := PackedByteArray()
# luoghi "firma": una sfida unica per regione (ondate di nemici; premio alla fine)
const ARENAS := [
	{"id": "a_vil", "n": "LA CAMPANA DEI CONDANNATI", "si": 0, "off": Vector2i(-2, -30), "mode": "bell", "r": 6.0, "ring": ["barrel_top", "crate_top", "skullpile"], "rn": 8,
		"waves": [[["skeleton", 5]], [["zombie", 3], ["skel_archer", 3]], [["berserker", 1], ["skeleton", 3]]], "rel": 1, "wpn": 2, "souls": 400},
	{"id": "a_cim", "n": "IL VEGLIONE DEI MORTI", "si": 1, "off": Vector2i(-16, -22), "mode": "enter", "r": 7.0, "ring": ["tomb", "statue_top", "tomb"], "rn": 10,
		"waves": [[["skeleton", 5]], [["ghoul", 3], ["skel_archer", 2]], [["wraith", 2], ["knight_fallen", 1]]], "rel": 1, "wpn": 3, "souls": 500},
	{"id": "a_bosco", "n": "L'ALBERO DEGLI IMPICCATI", "si": 2, "off": Vector2i(-14, 22), "mode": "enter", "r": 7.0, "ring": ["top_dead_0", "skullpile", "coffin", "top_dead_1"], "rn": 9,
		"waves": [[["ghoul", 3], ["wolf", 2]], [["cultist", 4], ["wolf", 2]], [["reaper", 1], ["ghoul", 2]]], "rel": 2, "wpn": 2, "souls": 600},
	{"id": "a_gelo", "n": "L'ARENA DEL GELO", "si": 5, "off": Vector2i(-14, 16), "mode": "enter", "r": 7.0, "ring": ["crystal_top_ice", "menhir_top_ice"], "rn": 8,
		"waves": [[["wraith", 3], ["wisp", 2]], [["frost_mage", 1], ["gargoyle", 2]], [["frost_mage", 1], ["wraith", 3]]], "rel": 1, "wpn": 3, "souls": 800},
	{"id": "a_fond", "n": "LA FOSSA DELLE CALDAIE", "si": 6, "off": Vector2i(0, -36), "mode": "enter", "r": 7.0, "ring": ["brazier", "anvil_top", "barrel_top"], "rn": 8,
		"waves": [[["imp", 4], ["ooze", 2]], [["berserker", 1], ["imp", 3]], [["abomination", 1], ["gargoyle", 2]]], "rel": 2, "wpn": 3, "souls": 900},
]
# missioni date dagli abitanti, in base al mestiere
const QT := {
	"contadina": {"type": "poi_find", "poi": ["family", "church", "altar", "well", "gallows", "mounds", "witch", "crossroads", "obelisks"], "n": 1, "txt": "MIO MARITO E' SPARITO. DICONO SIA ANDATO A: %s", "rs": 220, "rr": 0, "rw": 0},
	"cacciatore": {"type": "hunt", "kind": "deer", "n": 2, "txt": "CACCIA 2 CERVI NEL BOSCO", "rs": 220, "rr": 1, "rw": 0},
	"guardia": {"type": "poi_clear", "poi": ["bandits", "tower", "cave", "toll", "caravan", "quarry"], "n": 1, "txt": "LIBERA: %s", "rs": 340, "rr": 1, "rw": 0},
	"contadino": {"type": "poi_fetch", "poi": ["farm", "mill", "hamlet", "barn", "orchard", "scarecrow", "hermit"], "n": 1, "txt": "RITROVA IL MIO FAGOTTO: %s", "rs": 240, "rr": 0, "rw": 0},
	"fabbro": {"type": "poi_fetch", "poi": ["mine", "ruin", "tower", "quarry"], "n": 1, "txt": "RECUPERA I MIEI ATTREZZI: %s", "rs": 280, "rr": 0, "rw": 2},
	"monaco": {"type": "poi_clear", "poi": ["church", "altar", "family", "witch", "gallows", "mounds", "obelisks"], "n": 1, "txt": "PURIFICA: %s", "rs": 320, "rr": 1, "rw": 0},
	"anziano": {"type": "visit", "n": 1, "txt": "RAGGIUNGI IL VEGLIONE DEI MORTI", "rs": 260, "rr": 1, "rw": 0},
}
# materiali raccoglibili e ricette (facoltative) per il crafting ai campi
const MAT_ORDER := ["erba", "fungo", "legna", "minerale", "pelle", "carne", "osso"]
const MAT_NAMES := {"erba": "ERBE", "fungo": "FUNGHI", "legna": "LEGNA", "minerale": "MINERALE", "pelle": "PELLE", "carne": "CARNE", "osso": "OSSA"}
const RECIPES := [
	{"id": "infuso", "n": "INFUSO CURATIVO", "d": "+1 FIALA (FINO AL MASSIMO)", "cost": {"erba": 2}},
	{"id": "arrosto", "n": "ARROSTO", "d": "RECUPERI IL 45% DELLA VITA SUBITO", "cost": {"carne": 1, "legna": 1}},
	{"id": "forza", "n": "TONICO DI FORZA", "d": "+25% DANNO PER 4 MINUTI", "cost": {"erba": 2, "fungo": 1}},
	{"id": "pelle", "n": "CONCIA DI PELLE", "d": "-20% DANNI SUBITI PER 4 MINUTI", "cost": {"pelle": 2, "osso": 1}},
	{"id": "fuoco", "n": "OLIO INFUOCATO", "d": "L'ARMA BRUCIA I NEMICI PER 4 MINUTI", "cost": {"legna": 2, "osso": 1}},
	{"id": "affila", "n": "AFFILA L'ARMA", "d": "+6% DANNO ALL'ARMA (MAX 5 VOLTE)", "cost": {"minerale": 3, "legna": 1}},
	{"id": "reliquia", "n": "AMULETO D'OSSA", "d": "UNA RELIQUIA CASUALE", "cost": {"osso": 5, "erba": 3, "minerale": 2}},
]
const ROADS := [[0, 1], [1, 3], [0, 2], [3, 4], [4, 5], [4, 6], [1, 6], [2, 3]]
# cancelli sui ponti: "req" = boss da sconfiggere, "side" = lato da cui si apre ("E" = solo da est)
const GATE_DEF := [
	{"id": "g_cat", "road": 3, "req": "boss_wraith", "side": "", "msg": "SIGILLATO: SCONFIGGI IL CUSTODE DEL CIMITERO"},
	{"id": "g_bosco", "road": 7, "req": "", "side": "E", "msg": "SI APRE SOLO DALL'ALTRO LATO"},
	{"id": "g_forge", "road": 6, "req": "", "side": "E", "msg": "SI APRE SOLO DALL'ALTRO LATO"},
]
const LORE := [
	"ANZIANO: La cenere cadde sulla valle, e i morti si destarono.",
	"ANZIANO: Tre custodi sorvegliano i sigilli: nel cimitero, nella cattedrale, nelle forge.",
	"ANZIANO: Solo chi li abbatte potra' aprire la cripta del Signore.",
	"ANZIANO: Dormi negli accampamenti. Le anime perse si recuperano, se hai coraggio.",
	"ANZIANO: Cerca nei luoghi nascosti: ci sono grazie dimenticate.",
]

const STORY := [
	"LA CENERE E' CADUTA SULLA VALLE DI VESPRA.",
	"I MORTI SI SONO DESTATI, E UN SIGNORE SENZA NOME",
	"REGNA NELLA CRIPTA SOTTO LA CATTEDRALE.",
	"",
	"TRE CUSTODI SIGILLANO LA SUA TOMBA:",
	"IL CIMITERO, LA CATTEDRALE E LE FORGE.",
	"",
	"ESCI DALLE CELLE. ABBATTI I CUSTODI.",
	"APRI LA CRIPTA E METTI FINE AL SUO REGNO.",
	"",
	"DORMI NEGLI ACCAMPAMENTI PER CRESCERE. ESPLORA:",
	"RELIQUIE E ALTARI SONO NASCOSTI OVUNQUE.",
]

var DUNS := {
	"d0": {"n": "LE CELLE DEL RISVEGLIO", "rows": [0, 0, 1], "boss": "boss_jailer", "rooms": 6, "mult": 0.85, "bio": 0,
		"amb": Color(0.17, 0.15, 0.22)},
	"d1": {"n": "CRIPTA DEL CIMITERO", "rows": [0, 0, 1], "boss": "boss_wraith", "rooms": 12, "mult": 1.3, "bio": 1,
		"amb": Color(0.14, 0.15, 0.30)},
	"d2": {"n": "CATTEDRALE SOMMERSA", "rows": [3, 0, 3], "boss": "boss_gargoyle", "rooms": 14, "mult": 2.0, "bio": 4,
		"amb": Color(0.20, 0.14, 0.26)},
	"d3": {"n": "LE FORGE PROFONDE", "rows": [11, 11, 0], "boss": "boss_forge", "rooms": 14, "mult": 2.7, "bio": 6,
		"amb": Color(0.26, 0.13, 0.12)},
	"d4": {"n": "IL COVO DELL'IMPICCATO", "rows": [0, 2, 0], "boss": "boss_hanged", "rooms": 12, "mult": 1.9, "bio": 2,
		"amb": Color(0.10, 0.15, 0.13), "tint": Color(0.8, 1.0, 0.8)},
	"d5": {"n": "LE CAVERNE DELLA MELMA", "rows": [0, 1, 0], "boss": "boss_ooze", "rooms": 12, "mult": 2.0, "bio": 3,
		"amb": Color(0.11, 0.18, 0.15), "tint": Color(0.6, 1.0, 0.7)},
	"d6": {"n": "IL TRONO DI GHIACCIO", "rows": [3, 0, 3], "boss": "boss_yeti", "rooms": 14, "mult": 2.8, "bio": 5,
		"amb": Color(0.14, 0.18, 0.28), "tint": Color(0.7, 0.9, 1.4)},
	"d7": {"n": "IL CAMPANILE CADUTO", "rows": [0], "boss": "boss_campanaro", "rooms": 2, "mult": 1.6, "bio": 1,
		"amb": Color(0.17, 0.14, 0.26), "arena": true},
	"dF": {"n": "LA CRIPTA DEL SIGNORE", "rows": [2, 1, 0], "boss": "vampire", "rooms": 18, "mult": 3.5, "bio": 1,
		"amb": Color(0.16, 0.10, 0.22)},
}

var grid := PackedByteArray()      # 0 bloccato, 1 percorribile
var room_of := PackedInt32Array()
var biome := PackedByteArray()
var road := PackedByteArray()
var cobble := PackedByteArray()
var water := PackedByteArray()
var bridge := PackedByteArray()
var reach := PackedByteArray()
var outside := PackedByteArray()
var arenas: Array = []
var passages := {}                  # id scala -> cella dell'altra estremita'
var ovr := PackedByteArray()             # 0 nessuna, 1 forza terreno libero, 2 forza ostacolo/acqua
var gen_chunks := {}                     # chunk -> false = solo terreno, true = completo
var eager_chunks: Array = []
var gn_nz: FastNoiseLite
var gn_wz: FastNoiseLite
var gn_cz: FastNoiseLite
var spawn_buckets := {}
var spawn_indexed := 0
var stream_pc := Vector2i(-9999, -9999)
var world_cache := {}
var fin_prof := [0, 0, 0, 0]
var stream_i := 0
var stream_path: Array = []
var stream_max := 0
var stream_last := 0
var pois: Array = []
var poi_buckets := {}
var poi_t := 0.0
var micro_rng := RandomNumberGenerator.new()
var nook_count := 0
var spawn_t := 0.0
var gate_cell := {}                 # id cancello -> cella centrale sul ponte
var road_paths := {}
var block := {}                    # Vector2i -> true (oggetti solidi)
var rooms: Array[Rect2i] = []
var themes: Array[int] = []
var player: Player
var enemies: Array = []
var props: Array = []
var boss: Enemy = null
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var ents: Node2D
var fx: Node2D
var hud: Hud
var cm: CanvasModulate
var fog_rect: ColorRect
var fog_mat: ShaderMaterial
var fog_d := 0.3
const FOG_BIO := [0.30, 0.52, 0.42, 0.58, 0.32, 0.26, 0.10]
var fade: ColorRect
var area_nodes: Array = []
var flick: Array = []              # [luce, energia base, fase]
var state := "play"
var over_t := 0.0
var msg := ""
var msg_t := 0.0
var shake_v := 0.0
var hitstop_t := 0.0
var last_ms := 0
var t := 0.0
var world_seed := 1
var area := ""
var dun: Dictionary = {}
var persist := {"fires": {}, "opened": {}, "broken": {}, "bosses": {}}
var guardians := 0
var last_fire := {}
var returns := {}                  # area -> cella del portale d'ingresso (nel mondo)
var spawns: Array = []
var boss_pos := Vector2.ZERO
var boss_kind := ""
var camp_locks: Array = []     # posizioni dei lucchetti delle catene del Campanaro
var colossus: Colossus = null
var world_has_cathedral := false
var boss_tint := Color.WHITE
var sfx_node: Sfx = null
var pages_found := 0
var travel_list: Array = []
var travel_sel := 0
var mm_img: Image
var mm_tex: ImageTexture
var seen := PackedByteArray()
var mm_t := 0.0
var cycle := 0
var class_sel := 0
var class_ids := ["cavaliere", "cacciatore", "negromante", "chierico"]
var prompt2 := ""
var exit_cell := Vector2i.ZERO
var reserved := {}
var furn: Array = []
var stuck_t := 0.0
var doors: Array = []
var carved: Array = []
var use_pad := false
var show_fps := false
var settings := {"full": false, "master": 8, "sfx": 8, "amb": 8, "shake": true, "bright": 2, "fps": false, "aim_manual": false, "photo": false, "auto_fire": false}
var opt_sel := 0
var pause_sel := 0
var beast_sel := 0            # bestiario: scheda selezionata
var map_zoom := 0              # mappa del mondo: 0 intera, 1 ingrandita attorno al giocatore
var map_pan := Vector2.ZERO
var seen_load := PackedByteArray()   # esplorazione del mondo letta dal salvataggio
var opt_from := "pause"
var ctrl_from := "options"
var in_title_menu := false
const BRIGHT := [0.8, 0.9, 1.0, 1.12, 1.25, 1.4]
const OPTIONS := [
	{"k": "full", "n": "SCHERMO INTERO", "t": "toggle"},
	{"k": "master", "n": "VOLUME GENERALE", "t": "slider", "max": 10},
	{"k": "sfx", "n": "VOLUME EFFETTI", "t": "slider", "max": 10},
	{"k": "amb", "n": "VOLUME AMBIENTE", "t": "slider", "max": 10},
	{"k": "shake", "n": "SCUOTIMENTO SCHERMO", "t": "toggle"},
	{"k": "bright", "n": "LUMINOSITA", "t": "slider", "max": 5},
	{"k": "fps", "n": "MOSTRA FPS", "t": "toggle"},
	{"k": "aim_manual", "n": "MIRA MANUALE", "t": "toggle"},
	{"k": "auto_fire", "n": "FUOCO AUTOMATICO", "t": "toggle"},
	{"k": "photo", "n": "GRAFICA FOTO (PROVA)", "t": "toggle"},
	{"k": "ctrl", "n": "CONTROLLI", "t": "action"},
	{"k": "back", "n": "INDIETRO", "t": "action"},
]
var wake_t := 0.0
var allies: Array = []
var horde_t := 0.0
var horde_age := 0.0      # da quanto dura l'orda: le ondate crescono
var scout: ScoutFx = null
const INTERACT := {"res_erba": 1, "res_fungo": 1, "res_legna": 1, "res_minerale": 1, "bed_top": 1, "qitem": 1, "villager": 1, "bell": 1, "shrine": 1, "key": 1, "lever": 1, "stairs_top": 1, "gate_top": 1, "bonfire": 1, "portal": 1, "elder": 1, "npc": 1, "loot": 1, "dig": 1}
var pick_sel := 0
var lock_pos := Vector2(-9999.0, -9999.0)
var chain := 0
var chain_t := 0.0
var testing := false
var run_mode := true                 # partita a ondate con progressione salvata fuori dalla partita
var run_t := 0.0
var run_stage := 0
var run_revives := 1
var run_acc := 0.0
var run_boss_alive := false
var run_souls_total := 0
var run_result := {}
var run_elite_t := 0.0
var meta := {"ceneri": 0, "runs": 0, "best": 0.0, "wins": 0}
const RUN_BOSSES := ["boss_wraith", "boss_gargoyle", "boss_forge", "vampire"]
const RUN_BOSS_T := [420.0, 900.0, 1500.0, 2160.0]
var title_sel := 0
var title_save: Dictionary = {}
const SAVE_PATH := "user://crypt_save.json"
const CHAMP_POOL := [[], ["reaper", "knight_fallen", "plague_doc"], ["plague_doc", "summoner", "knight_fallen"],
	["plague_doc", "abomination", "summoner"], ["reaper", "summoner", "abomination"],
	["frost_mage", "knight_fallen", "abomination"], ["berserker", "abomination", "knight_fallen"]]
var stain: Node2D = null
var stain_data := {}
var death_t := 0.0
var prompt := ""
var picks: Array = []
var near_obj = null
var quest_defs := {}
var quest_items := {}
var critters: Array = []
var villagers: Array = []
var day_t := 0.3
const DAY_LEN := 600.0
var weather := ""
var weather_t := 15.0
var rain_fx: CPUParticles2D
var snow_fx: CPUParticles2D
var cur_bio := -1
var amb_target := Color(0.3, 0.25, 0.4)
var elder_i := 0
var tf := 0
var wr_node: WorldRender = null


func _ready() -> void:
	Game.setup_input()
	if OS.get_cmdline_user_args().size() == 0:
		load_settings()
	if OS.has_feature("mobile") and not FileAccess.file_exists("user://settings.cfg"):
		settings["auto_fire"] = true   # col touch il fuoco automatico e' molto piu' comodo
	if OS.get_cmdline_user_args().has("--photo"):   # prove della grafica FOTO
		settings["photo"] = true
	randomize()
	world_seed = new_seed()
	pop_salt = randi()
	last_ms = Time.get_ticks_msec()
	sfx_node = Sfx.new()
	add_child(sfx_node)
	apply_settings()
	cm = CanvasModulate.new()
	cm.color = Color(0.2, 0.18, 0.3)
	add_child(cm)
	var fgl := CanvasLayer.new()
	fgl.layer = 1
	add_child(fgl)
	setup_weather()
	fog_rect = ColorRect.new()
	fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fsh := Shader.new()
	fsh.code = """shader_type canvas_item;
uniform vec2 cam = vec2(0.0);
uniform float zoom = 1.0;
uniform float dens = 0.3;
uniform vec3 tint = vec3(0.55, 0.6, 0.72);
float h21(vec2 p){ p = mod(p, 61.0); return fract(sin(dot(p, vec2(12.9898, 78.233))) * 4375.5453); }
float vn(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(h21(i), h21(i + vec2(1,0)), f.x), mix(h21(i + vec2(0,1)), h21(i + vec2(1,1)), f.x), f.y); }
void fragment(){
  vec2 w = cam + (UV - 0.5) * vec2(480.0, 270.0) / zoom;
  vec2 q = w / 150.0;
  float n = vn(q + vec2(TIME * 0.035, TIME * 0.012)) * 0.55 + vn(q * 2.3 - vec2(TIME * 0.05, -TIME * 0.02)) * 0.3 + vn(q * 5.0 + vec2(TIME * 0.02)) * 0.15;
  float a = smoothstep(0.38, 0.85, n) * dens;
  COLOR = vec4(tint, a);
}"""
	fog_mat = ShaderMaterial.new()
	fog_mat.shader = fsh
	fog_rect.material = fog_mat
	fgl.add_child(fog_rect)
	ents = Node2D.new()
	ents.y_sort_enabled = true
	add_child(ents)
	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)
	player = Player.new()
	player.setup(self)
	ents.add_child(player)
	build_ui()
	testing = OS.get_cmdline_user_args().size() > 0
	run_mode = OS.get_cmdline_user_args().has("--run")
	load_meta()
	if OS.get_cmdline_user_args().has("--cls"):
		state = "class"
		return
	if has_save() and not testing:
		title_save = load_save()
		state = "title"
		return
	if not testing:
		state = "class"
		return
	start_game({}, "cavaliere")
	if OS.get_cmdline_user_args().has("--zoom"):
		player.zmode = 1
		player.cam.zoom = Vector2(0.55, 0.55)
	if OS.get_cmdline_user_args().has("--bridge"):
		for i in bridge.size():
			if bridge[i] == 1 and i % 7 == 0:
				player.position = cell_pos(Vector2i(i % Game.MW, i / Game.MW))
				break
	if OS.get_cmdline_user_args().has("--door"):
		for pr in props:
			if pr.kind == "door" and pr.dest.begins_with("int|house"):
				player.position = pr.position + Vector2(8, 40)
				break
	say("LA VALLE DI CENERE")


# ------------------------------------------------------------------ salvataggio e nuovo ciclo
func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	f = null
	if d is Dictionary and int(d.get("v", 1)) < 3:
		# il mondo e' stato ridisegnato: il vecchio salvataggio non e' piu' compatibile, lo conserviamo
		DirAccess.rename_absolute(SAVE_PATH, SAVE_PATH.replace(".json", "_v1.json"))
		return false
	return true


func load_save() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func save_game() -> void:
	if run_mode or testing or area == "" or player == null or last_fire.is_empty():
		return
	var lc: Vector2i = last_fire["cell"]
	var d := {"v": 3, "seed": world_seed, "pop": pop_salt, "cycle": cycle, "guardians": guardians, "pages": pages_found, "elder": elder_i,
		"last_fire": {"area": last_fire["area"], "cell": [lc.x, lc.y]}, "persist": persist,
		"player": {"lv": player.lv, "souls": player.souls, "rk": player.rk, "attr": player.attr, "kills": player.kills},
		"cls": player.cls, "wslots": player.wslots, "wcur": player.wcur, "spells": player.spells, "known": player.known, "relics": player.relics, "mats": player.mats, "items": player.items, "armor": player.armor, "brews": player.brews, "bag": player.bag, "belt": player.belt, "relic_eq": player.relic_eq,
		"chrono": {"e": player.chrono, "pity": player.pity, "tech": Chrono.tech, "junk": Chrono.owned}}
	var ws: PackedByteArray = world_seen()
	if ws.size() == WORLD_W * WORLD_H:
		d["seen"] = Marshalls.raw_to_base64(ws.compress(FileAccess.COMPRESSION_DEFLATE))
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


## legge l'esplorazione salvata (base64 compresso); viene applicata quando il mondo viene costruito
func load_seen(d: Dictionary) -> void:
	seen_load = PackedByteArray()
	if d.has("seen"):
		var raw: PackedByteArray = Marshalls.base64_to_raw(str(d["seen"]))
		var dec: PackedByteArray = raw.decompress(WORLD_W * WORLD_H, FileAccess.COMPRESSION_DEFLATE)
		if dec.size() == WORLD_W * WORLD_H:
			seen_load = dec


func load_meta() -> void:
	var f := FileAccess.open("user://meta.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in meta.keys():
			if d.has(k):
				meta[k] = d[k]


func save_meta() -> void:
	if testing:
		return
	var f := FileAccess.open("user://meta.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(meta))


func start_run(cls_id: String) -> void:
	world_seed = new_seed()
	pop_salt = randi()
	persist = {"fires": {}, "opened": {}, "broken": {}, "bosses": {}}
	cut_idx_n = -1
	guardians = 0
	pages_found = 0
	cycle = 0
	stain_data = {}
	player.rk = {}
	player.attr = {}
	player.armor = {}
	player.brews = {}
	player.relics = {}
	Chrono.reset()
	player.chrono = 60.0
	player.pity = 0
	player.veh = {}
	player.lv = 1
	player.souls = 0
	player.kills = 0
	player.set_class(cls_id)
	player.run_w = {str(RunW.START.get(cls_id, "lame")): 1}
	player.spirits = []
	player.rw_t = {}
	run_t = 0.0
	run_stage = 0
	run_revives = 1
	run_acc = 0.0
	run_boss_alive = false
	run_souls_total = 0
	run_elite_t = 90.0
	player.apply_stats()
	player.hp = player.max_hp
	player.st = player.max_st
	player.flasks = player.max_flasks
	build_area("world")
	var sc: Vector2i = SEEDS[1]
	player.position = cell_pos(free_near(sc + Vector2i(9, 6)))
	last_fire = {"area": "world", "cell": sc + Vector2i(3, 0)}
	player.cam.reset_smoothing()
	state = "story"
	say("LA VALLE DI VESPRA")


func run_need(lv: int) -> int:
	return int(90.0 + 62.0 * lv + 5.0 * lv * lv)


func add_ring(pos: Vector2, r: float, col: Color) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = col
	var pts := PackedVector2Array()
	for i in 33:
		pts.append(Vector2.from_angle(TAU * i / 32.0) * r)
	l.points = pts
	l.position = pos
	l.scale = Vector2(0.25, 0.25)
	fx.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.35)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- anime legate
var spirit_nodes: Array = []


func drop_shard(pos: Vector2, kind: String) -> void:
	if not Spirit.DATA.has(kind):
		return
	drop_loot(pos + Vector2(randf_range(-6, 6), randf_range(2, 8)), {"k": "shard", "id": kind})


func bind_spirit(kind: String) -> void:
	var found := false
	for s in player.spirits:
		if s["k"] == kind:
			s["lv"] = mini(5, int(s["lv"]) + 1)
			found = true
			say("ANIMA POTENZIATA: %s  (liv %d)" % [Spirit.DATA[kind]["n"], int(s["lv"])])
	if not found:
		if player.spirits.size() >= 4:
			var wi := 0
			for i in player.spirits.size():
				if int(player.spirits[i]["lv"]) < int(player.spirits[wi]["lv"]):
					wi = i
			player.spirits.remove_at(wi)
		player.spirits.append({"k": kind, "lv": 1})
		say("ANIMA LEGATA: %s" % Spirit.DATA[kind]["n"])
	snd("level")
	burst(player.position, Color(0.5, 0.95, 1.0), 24, 60.0, 0.6)
	sync_spirits()


func sync_spirits() -> void:
	for n in spirit_nodes:
		if is_instance_valid(n):
			n.queue_free()
	spirit_nodes.clear()
	var cnt: int = player.spirits.size()
	for i in cnt:
		var sp := Spirit.new()
		sp.setup(self, str(player.spirits[i]["k"]), int(player.spirits[i]["lv"]))
		sp.idx = i
		sp.count = cnt
		sp.position = player.position
		ents.add_child(sp)
		spirit_nodes.append(sp)


## schivata perfetta: rotolare nell'istante del colpo rallenta il tempo e scatena una risposta
func riposta() -> void:
	player.riposta_cd = 2.2
	hitstop(0.5)
	player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.05)
	player.mana = minf(player.max_mana, player.mana + 12.0)
	popup(player.position + Vector2(0, -22), "RIPOSTA!", Color(1.0, 0.85, 0.4))
	add_ring(player.position, 58.0, Color(1.0, 0.85, 0.4))
	snd("level")
	shake(3.0)
	for e in enemies.duplicate():
		if e.awake and e.position.distance_squared_to(player.position) < 3600.0:
			e.hurt(player.bd() * 1.8, (e.position - player.position).normalized(), 170.0, false)
			player.on_hit(e, player.bd() * 1.8, {})
	for s in spirit_nodes:
		if is_instance_valid(s):
			s.cd = 0.0


func run_boss_time() -> float:
	return RUN_BOSS_T[mini(run_stage, RUN_BOSS_T.size() - 1)]


func run_roll() -> Array:
	var pool_w: Array = []
	var pool_u: Array = []
	for w in RunW.LIST:
		var lv: int = int(player.run_w.get(w["id"], 0))
		if lv < int(w["max"]):
			pool_w.append({"id": "w_" + str(w["id"]), "wid": w["id"], "kind": "w", "rank": lv + 1, "max": w["max"],
				"n": ("NUOVA ARMA: " if lv == 0 else "") + str(w["n"]), "d": w["d"] if lv == 0 else w["up"]})
	for u in Upgrades.LIST:
		if int(player.rk.get(u["id"], 0)) < int(u["max"]):
			pool_u.append({"id": u["id"], "kind": "u", "rank": int(player.rk.get(u["id"], 0)) + 1, "max": u["max"], "n": u["n"], "d": u["d"]})
	pool_w.shuffle()
	pool_u.shuffle()
	var out: Array = []
	if not pool_w.is_empty():
		out.append(pool_w.pop_back())
	var rest_pool: Array = pool_w + pool_u
	rest_pool.shuffle()
	while out.size() < 3 and not rest_pool.is_empty():
		out.append(rest_pool.pop_back())
	out.shuffle()
	return out


func pick_rank(u: Dictionary) -> int:
	return int(u.get("rank", 1))


func run_apply_pick(u: Dictionary) -> void:
	if u["kind"] == "w":
		player.run_w[u["wid"]] = int(player.run_w.get(u["wid"], 0)) + 1
	else:
		player.rk[u["id"]] = player.r(u["id"]) + 1
	player.apply_stats()
	player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.3)
	player.flasks = player.max_flasks


func run_spawn_pos(dmin: float, dmax: float) -> Vector2:
	for k in 10:
		var pos: Vector2 = player.position + Vector2.from_angle(randf() * TAU) * randf_range(dmin, dmax)
		var c := Vector2i(floori(pos.x / Game.TS), floori(pos.y / Game.TS))
		if inb(c) and is_floor(c) and not block.has(c):
			return pos
	return Vector2(-1, -1)


func run_update(real: float) -> void:
	run_t += real
	# livello: le anime sono esperienza
	var need := run_need(player.lv)
	if player.souls >= need and state == "play":
		player.souls -= need
		player.lv += 1
		picks = run_roll()
		if not picks.is_empty():
			pick_sel = 0
			snd("level")
			state = "pick"
		return
	# regista: ondate sempre piu' fitte
	var alive := enemies.size()
	var cap := mini(150, 28 + int(run_t / 9.0))
	run_acc += real
	var interval := maxf(0.45, 1.2 - run_t / 900.0)
	if run_acc >= interval and alive < cap:
		run_acc = 0.0
		var bi: int = biome[idx(Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS)))]
		var b: Dictionary = Game.BIO[bi]
		var pool: Array = b["pool"]
		var g := 1 + int(run_t / 100.0) + (1 if randf() < 0.35 else 0)
		g = mini(g, 9)
		var kind: String = pool[randi() % pool.size()]
		var mult := (1.0 + run_t / 420.0 + run_stage * 0.3) * (1.0 + int(b["tier"]) * 0.06)
		for i in g:
			var pos := run_spawn_pos(170.0, 240.0)
			if pos.x < 0.0:
				continue
			var kk: String = kind if (kind == "rat" or randf() < 0.6) else pool[randi() % pool.size()]
			var e := spawn_enemy(kk, pos, mult, randf() < 0.04, b["tint"])
			e.dmg *= 1.0 + run_t / 1100.0 + run_stage * 0.2
			e.awake = true
			e.set_process(true)
	# campioni: speciali con attacchi propri
	run_elite_t -= real
	if run_elite_t <= 0.0 and run_t > 120.0:
		run_elite_t = maxf(35.0, 90.0 - run_t / 40.0)
		var bi2: int = biome[idx(Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS)))]
		var cp: Array = CHAMP_POOL[bi2]
		var pos2 := run_spawn_pos(190.0, 250.0)
		if not cp.is_empty() and pos2.x >= 0.0:
			var ec := spawn_enemy(cp[randi() % cp.size()], pos2, (1.0 + run_t / 600.0 + run_stage * 0.3) * 1.2, false, Color.WHITE)
			ec.awake = true
			ec.set_process(true)
			say("UN CAMPIONE SI AVVICINA")
	# custode di fine tappa
	if not run_boss_alive and run_t >= run_boss_time() and run_stage < RUN_BOSSES.size():
		var bp := run_spawn_pos(150.0, 200.0)
		if bp.x >= 0.0:
			var bk: String = RUN_BOSSES[run_stage]
			var be := spawn_enemy(bk, bp, 1.0 + run_stage * 0.35, false, Color.WHITE)
			be.awake = true
			be.set_process(true)
			run_boss_alive = true
			say("UN CUSTODE SI RISVEGLIA!")
			snd("roar")
			shake(6.0)
	# nemici troppo lontani: rimossi per tenere il gioco fluido
	if Engine.get_process_frames() % 30 == 0:
		for e in enemies.duplicate():
			if not e.is_boss and not e.champ and e.position.distance_squared_to(player.position) > 160000.0:
				enemies.erase(e)
				e.queue_free()


func end_run(win: bool) -> void:
	if state == "results":
		return
	Engine.time_scale = 1.0
	var ceneri := int(run_souls_total / 8.0) + int(player.kills / 12.0) + run_stage * 60 + (400 if win else 0)
	meta["ceneri"] = int(meta["ceneri"]) + ceneri
	meta["runs"] = int(meta["runs"]) + 1
	meta["best"] = maxf(float(meta["best"]), run_t)
	if win:
		meta["wins"] = int(meta["wins"]) + 1
	save_meta()
	run_result = {"win": win, "t": run_t, "kills": player.kills, "lv": player.lv, "souls": run_souls_total, "ceneri": ceneri, "stage": run_stage}
	state = "results"


func start_game(ld: Dictionary, cls_id := "cavaliere") -> void:
	if not testing:
		state = "loading"
		await get_tree().process_frame
		await get_tree().process_frame
	drop_world_cache()
	if run_mode:
		start_run(cls_id)
		return
	if ld.is_empty():
		world_seed = new_seed()
		pop_salt = randi()
		player.rk = {}
		player.attr = {}
		player.armor = {}
		player.brews = {}
		player.relics = {}
		player.mats = {}
		player.items = {}
		player.lv = 1
		player.souls = 0
		player.kills = 0
		player.set_class(cls_id)
	else:
		player.set_class(str(ld.get("cls", "cavaliere")))
		world_seed = int(ld["seed"])
		if int(edits_data().get("seed", 0)) > 0:
			world_seed = int(edits_data()["seed"])  # mondo fisso: il seme dell'editor vale anche per i salvataggi
		if int(edits_data().get("seed", 0)) > 0:
			world_seed = int(edits_data()["seed"])  # mondo fisso: il seme dell'editor vale anche per i salvataggi
		pop_salt = int(ld.get("pop", 0))
		cycle = int(ld.get("cycle", 0))
		guardians = int(ld.get("guardians", 0))
		pages_found = int(ld.get("pages", 0))
		elder_i = int(ld.get("elder", 0))
		var ps: Dictionary = ld["persist"]
		for k in ["fires", "opened", "broken", "bosses", "npc", "quests", "bestiary"]:
			if not ps.has(k):
				ps[k] = {}
		persist = ps
		load_seen(ld)
		cut_idx_n = -1
		var pd: Dictionary = ld["player"]
		player.lv = int(pd["lv"])
		player.souls = int(pd["souls"])
		player.kills = int(pd["kills"])
		player.rk = {}
		player.attr = {}
		player.armor = {}
		player.brews = {}
		for k in pd["rk"]:
			player.rk[k] = int(pd["rk"][k])
		if pd.has("attr"):
			for k in pd["attr"]:
				player.attr[k] = int(pd["attr"][k])
		player.mats = {}
		if ld.has("mats"):
			for mk2 in ld["mats"]:
				player.mats[str(mk2)] = int(ld["mats"][mk2])
		player.items = {}
		if ld.has("items"):
			for ik in ld["items"]:
				player.items[str(ik)] = int(ld["items"][ik])
		player.armor = {}
		if ld.has("armor"):
			for sk in ld["armor"]:
				var pc: Dictionary = ld["armor"][sk]
				var st := {}
				for k in pc["st"]:
					st[str(k)] = float(pc["st"][k])
				player.armor[str(sk)] = Rpg.clean_piece(pc)
		player.brews = {}
		if ld.has("brews"):
			for bk in ld["brews"]:
				player.brews[str(bk)] = ld["brews"][bk]
		player.bag = []
		if ld.has("bag"):
			for be in ld["bag"]:
				if str(be["k"]) == "w":
					player.bag.append({"k": "w", "w": Rpg.clean(be["w"])})
				elif str(be["k"]) == "a":
					player.bag.append({"k": "a", "a": Rpg.clean_piece(be["a"])})
		player.item_sel = 0
		Chrono.reset()
		player.chrono = 60.0
		player.pity = 0
		player.veh = {}
		if ld.has("chrono"):
			var cd: Dictionary = ld["chrono"]
			player.chrono = float(cd.get("e", 60.0))
			player.pity = int(cd.get("pity", 0))
			Chrono.tech = float(cd.get("tech", 0.0))
			for jk in cd.get("junk", {}):
				if Chrono.JUNK.has(str(jk)):
					Chrono.owned[str(jk)] = int(cd["junk"][jk])
		player.relics = {}
		if ld.has("relics"):
			for k in ld["relics"]:
				player.relics[str(k)] = int(ld["relics"][k])
		player.relic_eq = []
		if ld.has("relic_eq"):
			for k in ld["relic_eq"]:
				player.relic_eq.append(str(k))
		else:   # salvataggi vecchi: indossa le prime reliquie possedute
			for k in player.relics:
				if player.relic_eq.size() < player.RELIC_MAX:
					player.relic_eq.append(str(k))
		player.belt = []
		if ld.has("belt"):
			for k in ld["belt"]:
				player.belt.append(str(k))
		else:
			for k in player.items:
				if player.belt.size() < player.BELT_MAX:
					player.belt.append(str(k))
		if ld.has("wslots"):
			player.wslots = [null, null]
			for i in 2:
				var wv = ld["wslots"][i]
				player.wslots[i] = Rpg.clean(wv) if wv != null else null
			player.wcur = int(ld.get("wcur", 0))
			player.spells = [str(ld["spells"][0]), str(ld["spells"][1])]
			player.known = []
			for sp in ld["known"]:
				player.known.append(str(sp))
		player.apply_stats()
		player.hp = player.max_hp
		player.st = player.max_st
		player.flasks = player.max_flasks
	var d0_start: bool = ld.is_empty() and (not testing or OS.get_cmdline_user_args().has("--startd0"))
	if d0_start:
		build_area("d0")
		player.position = Vector2(center(rooms[0])) * Game.TS + Vector2(8, 36)
		for pr in props:
			if pr.kind == "bonfire":
				last_fire = {"area": "d0", "cell": pr.cell}
				break
	else:
		build_area("world")
	if d0_start:
		pass
	elif ld.is_empty():
		player.position = Vector2(SEEDS[0] + Vector2i(0, 4)) * Game.TS + Vector2(8, 8)
	else:
		var lf: Dictionary = ld["last_fire"]
		var c := Vector2i(int(lf["cell"][0]), int(lf["cell"][1]))
		last_fire = {"area": lf["area"], "cell": c}
		if lf["area"] != "world":
			build_area(lf["area"])
		player.position = cell_pos(c) + Vector2(0, 18)
	player.cam.reset_smoothing()
	state = "story" if d0_start else "play"
	say("LE CELLE DEL RISVEGLIO" if ld.is_empty() else "BENTORNATO")


func new_cycle() -> void:
	drop_world_cache()
	cycle += 1
	persist = {"fires": {}, "opened": {}, "broken": {}, "bosses": {}}
	cut_idx_n = -1
	guardians = 0
	pages_found = 0
	stain_data = {}
	elder_i = 0
	Engine.time_scale = 1.0
	world_seed = new_seed()
	pop_salt = randi()
	player.apply_stats()
	player.hp = player.max_hp
	player.st = player.max_st
	player.flasks = player.max_flasks
	build_area("world")
	player.position = Vector2(SEEDS[0] + Vector2i(0, 4)) * Game.TS + Vector2(8, 8)
	player.cam.reset_smoothing()
	state = "play"
	say("CICLO %d: LA VALLE SI E' RIGENERATA" % (cycle + 1))
	save_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


# ------------------------------------------------------------------ utilita'
func idx(c: Vector2i) -> int:
	return c.y * Game.MW + c.x


func center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2


func inb(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < Game.MW and c.y < Game.MH


func is_floor(c: Vector2i) -> bool:
	return inb(c) and grid[idx(c)] == 1


func key(c: Vector2i) -> String:
	return "%s:%d,%d" % [area, c.x, c.y]


func has_carpet(c: Vector2i) -> bool:
	if area == "world":
		return false
	if area.begins_with("int|") and str(dun.get("type", "")) != "chapel":
		return false
	var ri := room_of[idx(c)]
	if ri < 0:
		return false
	var r := rooms[ri]
	return r.size.x >= 9 and (c.x == center(r).x or c.x == center(r).x - 1)


func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c) * Game.TS + Vector2(8, 8)


# ------------------------------------------------------------------ costruzione aree
func clear_area() -> void:
	for c in ents.get_children():
		if c != player:
			c.queue_free()
	if area == "world" and world_cache.is_empty() and wr_node != null and is_instance_valid(wr_node):
		wr_node.queue_free()
	for c in fx.get_children():
		c.queue_free()
	for n in area_nodes:
		if is_instance_valid(n):
			n.queue_free()
	area_nodes.clear()
	flick.clear()
	critters.clear()
	villagers.clear()
	props.clear()
	enemies.clear()
	spawns.clear()
	block.clear()
	rooms.clear()
	themes.clear()
	boss = null
	boss_kind = ""
	stain = null
	wr_node = null
	reserved.clear()
	tent_cells.clear()
	dest_cells.clear()
	terr_dmg.clear()
	cut_idx_n = -1
	furn.clear()
	doors.clear()
	allies.clear()
	if player != null:
		player.zmode = 0
	burst_pool = {8: [], 20: [], 48: []}


const WORLD_KEYS := ["grid", "biome", "road", "cobble", "water", "bridge", "outside", "reach", "ovr", "room_of", "gen_chunks",
	"eager_chunks", "gn_nz", "gn_wz", "gn_cz", "spawn_buckets", "spawn_indexed", "props", "enemies", "block", "spawns", "critters",
	"villagers", "arenas", "quest_items", "doors", "reserved", "furn", "flick", "area_nodes", "ents", "wr_node", "mm_img", "mm_tex",
	"seen", "gate_cell", "road_paths", "passages", "nook_count", "pois", "poi_buckets", "dest_cells", "terr_dmg", "tent_cells"]


func drop_world_cache() -> void:
	if world_cache.is_empty():
		return
	for k in ["ents", "wr_node"]:
		var n = world_cache.get(k)
		if n != null and is_instance_valid(n):
			n.queue_free()
	world_cache = {}


## mette da parte il mondo (invisibile e fermo) per entrare in un edificio o in un dungeon
func stash_world() -> void:
	world_cache = {"MW": Game.MW, "MH": Game.MH}
	for k in WORLD_KEYS:
		world_cache[k] = get(k)
	grid = PackedByteArray()
	biome = PackedByteArray()
	road = PackedByteArray()
	cobble = PackedByteArray()
	water = PackedByteArray()
	bridge = PackedByteArray()
	outside = PackedByteArray()
	reach = PackedByteArray()
	ovr = PackedByteArray()
	room_of = PackedInt32Array()
	seen = PackedByteArray()
	gen_chunks = {}
	eager_chunks = []
	spawn_buckets = {}
	spawn_indexed = 0
	props = []
	enemies = []
	block = {}
	spawns = []
	critters = []
	villagers = []
	arenas = []
	quest_items = {}
	pois = []
	poi_buckets = {}
	doors = []
	reserved = {}
	dest_cells = {}
	terr_dmg = {}
	tent_cells = []
	furn = []
	flick = []
	area_nodes = []
	mm_img = null
	mm_tex = null
	var old_ents: Node2D = ents
	old_ents.remove_child(player)
	old_ents.visible = false
	old_ents.process_mode = Node.PROCESS_MODE_DISABLED
	if wr_node != null:
		wr_node.visible = false
		wr_node.process_mode = Node.PROCESS_MODE_DISABLED
	wr_node = null
	ents = Node2D.new()
	ents.y_sort_enabled = true
	add_child(ents)
	ents.add_child(player)


func restore_world() -> void:
	var interior_ents: Node2D = ents
	interior_ents.remove_child(player)
	interior_ents.queue_free()
	for k in WORLD_KEYS:
		set(k, world_cache[k])
	Game.MW = int(world_cache["MW"])
	Game.MH = int(world_cache["MH"])
	ents.visible = true
	ents.process_mode = Node.PROCESS_MODE_INHERIT
	if wr_node != null:
		wr_node.visible = true
		wr_node.process_mode = Node.PROCESS_MODE_INHERIT
	ents.add_child(player)
	world_cache = {}


func build_area(a: String) -> void:
	var t0 := Time.get_ticks_msec()
	var prev := area
	area = a
	var restoring: bool = (a == "world" and not world_cache.is_empty())
	if prev == "world" and a != "world" and wr_node != null and world_cache.is_empty():
		stash_world()
	clear_area()
	if restoring:
		restore_world()
		cur_bio = -1
		make_stain()
		player.set_limits()
		sync_spirits()
		scout = ScoutFx.new()
		scout.main = self
		fx.add_child(scout)
		randomize()
		return
	var sd := world_seed if a == "world" else world_seed * 7 + absi(a.hash()) % 1000
	if a.begins_with("int|"):
		sd = world_seed * 13 + absi(a.hash()) % 100000
	seed(sd)
	cur_bio = -1
	if a == "world":
		gen_world()
		build_tiles_world()
		populate_world()
	elif a.begins_with("int|"):
		dun = interior_def(a)
		gen_dungeon()
		build_tiles()
		populate_interior()
		amb_target = dun["amb"]
		sfx_node.ambient("dun")
	else:
		dun = DUNS[a]
		gen_dungeon()
		build_tiles()
		populate_dungeon()
		amb_target = dun["amb"]
		sfx_node.ambient("dun")
	make_stain()
	player.set_limits()
	sync_spirits()
	scout = ScoutFx.new()
	scout.main = self
	fx.add_child(scout)
	init_minimap()
	randomize()
	if testing:
		print("BUILD ", a, " ms=", Time.get_ticks_msec() - t0)


func make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	var src := TileSetAtlasSource.new()
	var tex: Texture2D = load("res://assets/tiles/tiles.png")
	if Game.photo and ResourceLoader.exists("res://assets/photo/tiles_photo.png"):
		tex = load("res://assets/photo/tiles_photo.png")   # caselle fotografiche (interni)
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	for x in 4:
		for y in tex.get_height() / 16:
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)
	return ts


func new_layers(z: int) -> void:
	var ts := make_tileset()
	floor_layer = TileMapLayer.new()
	floor_layer.tile_set = ts
	floor_layer.z_index = z
	add_child(floor_layer)
	area_nodes.append(floor_layer)
	wall_layer = TileMapLayer.new()
	wall_layer.tile_set = ts
	wall_layer.z_index = z + 1
	add_child(wall_layer)
	area_nodes.append(wall_layer)


# ------------------------------------------------------------------ MONDO ESTERNO
const POI_NAMES := {
	"farm": "FATTORIA BRUCIATA", "church": "CHIESA ABBANDONATA", "mill": "VECCHIO MULINO", "altar": "ALTARE NEL BOSCO",
	"bandits": "ACCAMPAMENTO DI BRIGANTI", "tower": "TORRE DI GUARDIA", "family": "CIMITERO DI FAMIGLIA", "cave": "COVO DEL CACCIATORE",
	"well": "POZZO MALEDETTO", "ruin": "ROVINE ANTICHE", "hamlet": "VILLAGGIO ABBANDONATO", "mine": "VECCHIA MINIERA",
}
const POI_BY_BIO := [
	["farm", "mill", "bandits", "well", "ruin", "hamlet"],
	["family", "church", "well", "ruin", "tower", "family"],
	["altar", "cave", "bandits", "farm", "tower", "altar"],
	["ruin", "well", "bandits", "hamlet", "altar", "mill"],
	["church", "ruin", "tower", "family", "church", "well"],
	["cave", "tower", "ruin", "altar", "cave", "well"],
	["mine", "ruin", "tower", "bandits", "mine", "well"],
]


func is_outside_xy(x: int, y: int) -> bool:
	var nxc := (x - 480.0) / 538.0
	var nyc := (y - 352.0) / 397.0
	return x < 3 or y < 3 or x >= Game.MW - 3 or y >= Game.MH - 3 or sqrt(nxc * nxc + nyc * nyc) + 0.30 * gn_cz.get_noise_2d(x, y) > 1.0


func poi_ok(c: Vector2i) -> bool:
	if c.x < 30 or c.y < 30 or c.x > Game.MW - 30 or c.y > Game.MH - 30 or is_outside_xy(c.x, c.y):
		return false
	if water[idx(c)] == 1 or ovr[idx(c)] == 2 or road[idx(c)] == 1:
		return false
	for a in 8:
		var q := c + Vector2i(roundi(cos(a * TAU / 8.0) * 12.0), roundi(sin(a * TAU / 8.0) * 12.0))
		if inb(q) and (water[idx(q)] == 1 or is_outside_xy(q.x, q.y)):
			return false
	if not far_from_sites(c, 46.0, 22.0):
		return false
	for po in pois:
		if Vector2(c).distance_to(Vector2(po["cell"])) < 36.0:
			return false
	return true


## luoghi di interesse: lungo le strade e sparsi nelle zone selvagge (posizioni fisse per ogni seme)
func gen_pois() -> void:
	pois.clear()
	poi_buckets.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 4242
	var cands: Array = []
	for ri in road_paths.keys():
		var pth: Array = road_paths[ri]
		var i := rng.randi_range(25, 45)
		while i < pth.size() - 25:
			var p0: Vector2i = pth[i]
			var p1: Vector2i = pth[mini(i + 4, pth.size() - 1)]
			var p2: Vector2i = pth[maxi(i - 4, 0)]
			var dv := Vector2(p1 - p2)
			if dv.length() > 0.1:
				dv = dv.normalized()
				var perp := Vector2(-dv.y, dv.x) * (1.0 if rng.randf() < 0.5 else -1.0)
				cands.append(Vector2i(Vector2(p0) + perp * rng.randf_range(10.0, 24.0)))
			i += rng.randi_range(32, 50)
	for k in 170:
		cands.append(Vector2i(rng.randi_range(40, Game.MW - 40), rng.randi_range(40, Game.MH - 40)))
	for c in cands:
		if pois.size() >= 96:
			break
		if not poi_ok(c):
			continue
		var bi := biome_at(c.x, c.y)
		var tpl: Dictionary = PoiData.pick(PoiData.templates, bi, rng)
		if tpl.is_empty():
			continue
		var po := {"id": pois.size(), "type": str(tpl["type"]), "tpl": str(tpl["id"]), "cell": c, "n": str(tpl["name"])}
		pois.append(po)
		var key := Vector2i(c.x / CH, c.y / CH)
		if not poi_buckets.has(key):
			poi_buckets[key] = []
		(poi_buckets[key] as Array).append(po)


func poi_enemies(c: Vector2i, kinds: Array, n: int, spread := 5, champ := true) -> void:
	var bi := biome_at(c.x, c.y)
	var dist := Vector2(c).distance_to(Vector2(SEEDS[0])) / WS
	var mult: float = 1.0 + int(Game.BIO[bi]["tier"]) * 0.28 + 0.08
	for k in n:
		var cc := c + Vector2i(pop_rng.randi_range(-spread, spread), pop_rng.randi_range(-spread, spread))
		if is_floor(cc) and not block.has(cc):
			spawns.append({"k": kinds[pop_rng.randi() % kinds.size()], "pos": cell_pos(cc), "mult": mult, "elite": pop_rng.randf() < 0.1, "tint": Game.BIO[bi]["tint"]})
	if champ:
		add_champion(c + Vector2i(2, 2), 1.15)


var cur_poi_type := ""


func poi_chest(c: Vector2i, rare := false) -> void:
	# meno scrigni nei luoghi: quelli comuni compaiono meta' delle volte, i preziosi non sono garantiti
	if not rare and randf() < 0.5:
		return
	if rare and randf() < 0.45:
		rare = false
	var cc := free_spot(c, Vector2i(1, 1))
	if cc.x < 0:
		return
	var ch := add_prop("chest", cc)
	if ch != null:
		ch.set_meta("poi", cur_poi_type)
		ch.rare = rare
		if rare:
			ch.spr.modulate = Color(1.6, 1.3, 0.6)
			Game.make_light(ch, Vector2(0, -8), Color(1.0, 0.85, 0.4), 1.0, 0.8)


func poi_scatter(names: Array, c: Vector2i, n: int, rx: int, ry: int) -> void:
	for i in n:
		try_place(names[randi() % names.size()], c + Vector2i(randi_range(-rx, rx), randi_range(-ry, ry)))


func poi_trees(c: Vector2i, n: int, rx: int, ry: int) -> void:
	for i in n:
		place_tree("top_dead_%d" % (randi() % 4), c + Vector2i(randi_range(-rx, rx), randi_range(-ry, ry)))


func build_poi(po: Dictionary) -> void:
	var c: Vector2i = po["cell"]
	seed(world_seed * 131 + int(po["id"]) * 977)
	var tpl: Dictionary = PoiData.by_id(str(po.get("tpl", "")))
	var rad := int(tpl.get("r", 15))
	clear_disc(c, rad)
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var q := c + Vector2i(dx, dy)
			if inb(q) and grid[idx(q)] == 1:
				reach[idx(q)] = 1
	var rare := randf() < 0.4
	var s_first := spawns.size()
	cur_poi_type = str(po["type"])
	if tpl.is_empty():
		legacy_build(str(po["type"]), c, rare)
	else:
		run_ops(c, tpl["ops"], randf() < 0.5, rare)
		if tpl.get("champ", true):
			add_champion(c + Vector2i(2, 2), 1.15)
	cur_poi_type = ""
	# nemici del luogo: servono alle missioni "libera"
	var mine: Array = []
	for i in range(s_first, spawns.size()):
		spawns[i]["poi"] = int(po["id"])
		mine.append(spawns[i])
	po["spawns"] = mine
	po["built"] = true
	for qid in quest_defs:
		var qd: Dictionary = quest_defs[qid]
		if qd.get("poi_id", -1) == int(po["id"]) and qd["type"] == "poi_fetch" and quest_state(qid) == "active":
			spawn_quest_item(qid, true)
	if wr_node != null:
		wr_node.refresh_cells(Rect2i(c.x - rad - 2, c.y - rad - 2, rad * 2 + 5, rad * 2 + 5))


func legacy_build(t: String, c: Vector2i, rare: bool) -> void:
	match t:
		"farm":
			try_place("roof_4x3_ash", c + Vector2i(-5, -5), true)
			try_place("roof_3x2_ash", c + Vector2i(3, -4), true)
			fence_line(c + Vector2i(-10, -8), c + Vector2i(10, -8), 7, 10, false)
			fence_line(c + Vector2i(-10, 7), c + Vector2i(10, 7), 3, 6, false)
			fence_line(c + Vector2i(-10, -7), c + Vector2i(-10, 6), 9, 12, false)
			try_place("well_top", c + Vector2i(1, 1))
			try_place("cart_top", c + Vector2i(-6, 3))
			poi_scatter(["hay_top"], c, 4, 9, 4)
			poi_scatter(["barrel_top", "crate_top", "sack_top"], c, 4, 8, 4)
			poi_trees(c, 4, 11, 8)
			try_place("skullpile", c + Vector2i(5, 3))
			poi_enemies(c, ["zombie", "ghoul", "skeleton"], 5)
			poi_chest(c + Vector2i(6, 2), rare)
		"church":
			try_place("chapel_top_ash", c + Vector2i(-2, -7), true)
			fence_line(c + Vector2i(-12, -9), c + Vector2i(12, -9), 11, 14, true)
			fence_line(c + Vector2i(-12, 10), c + Vector2i(12, 10), 11, 14, true)
			poi_scatter(["grave_cross_0", "grave_mound_1", "grave_slab_0", "grave_cross_1", "grave_mound_0"], c, 11, 10, 7)
			try_place("statue_top", c + Vector2i(4, 4))
			try_place("lamp_top", c + Vector2i(-4, 2), true)
			try_place("lamp_top", c + Vector2i(4, 2), true)
			poi_enemies(c, ["cultist", "skeleton", "wraith"], 5)
			poi_chest(c + Vector2i(-6, 3), true)
		"mill":
			try_place("mill_top", c + Vector2i(-3, -3), true)
			poi_scatter(["hay_top"], c, 3, 9, 8)
			try_place("cart_top", c + Vector2i(6, 4))
			try_place("well_top", c + Vector2i(-7, 4))
			poi_scatter(["barrel_top", "crate_top", "sack_top"], c, 5, 9, 8)
			poi_trees(c, 3, 11, 9)
			poi_enemies(c, ["ghoul", "bat", "zombie"], 4)
			poi_chest(c + Vector2i(5, -6), rare)
		"altar":
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				try_place("menhir_top_cem", c + Vector2i(roundi(cos(a) * 7.0), roundi(sin(a) * 7.0)))
			add_prop("altar", c)
			for i in 4:
				add_prop("candelabra", c + Vector2i(roundi(cos(i * TAU / 4.0 + 0.8) * 3.0), roundi(sin(i * TAU / 4.0 + 0.8) * 3.0)))
			poi_scatter(["skullpile", "bone_skull_0", "bone_ribs_1"], c, 4, 6, 6)
			poi_enemies(c, ["wraith", "cultist", "ghoul"], 5)
			poi_chest(c + Vector2i(0, 5), true)
		"bandits":
			try_place("tent_top_0", c + Vector2i(-6, -3))
			try_place("tent_top_1", c + Vector2i(4, -4))
			try_place("tent_top_2", c + Vector2i(-2, 4))
			try_place("campfire_top", c, true)
			try_place("cart_top", c + Vector2i(7, 3))
			poi_scatter(["crate_top", "barrel_top", "sack_top"], c, 6, 9, 6)
			poi_enemies(c, ["cultist", "skel_archer", "imp", "wolf"], 7)
			poi_chest(c + Vector2i(-5, 2), rare)
			poi_chest(c + Vector2i(5, 3), false)
		"tower":
			try_place("tower_top", c + Vector2i(-2, -4), true)
			fence_line(c + Vector2i(-8, -7), c + Vector2i(8, -7), 7, 10, false)
			fence_line(c + Vector2i(-8, 6), c + Vector2i(8, 6), 7, 10, false)
			poi_scatter(["barrel_top", "crate_top"], c, 4, 7, 5)
			try_place("lamp_top", c + Vector2i(-3, 3), true)
			poi_enemies(c, ["skel_archer", "skel_archer", "gargoyle", "skeleton"], 5)
			poi_chest(c + Vector2i(5, 3), rare)
		"family":
			graveyard(c + Vector2i(-7, -5), 14, 11, "", 1)
			poi_enemies(c, ["ghoul", "skeleton", "wraith"], 5)
			poi_chest(c + Vector2i(0, 7), true)
		"cave":
			build_ruin(c + Vector2i(-8, -6), 16, 12, "cem")
			try_place("campfire_top", c + Vector2i(0, 2), true)
			poi_scatter(["log_top_0", "log_top_2", "sack_top", "bone_ribs_0", "bone_skull_2"], c, 6, 6, 4)
			poi_enemies(c, ["wolf", "wolf", "skeleton"], 6)
			poi_chest(c + Vector2i(3, -3), rare)
		"well":
			try_place("well_top", c + Vector2i(-1, -1))
			for i in 6:
				try_place("skullpile", c + Vector2i(roundi(cos(i * TAU / 6.0) * 5.0), roundi(sin(i * TAU / 6.0) * 4.0)))
			poi_scatter(["bone_skull_1", "bone_ribs_2", "bone_bones_3"], c, 5, 6, 5)
			poi_trees(c, 3, 8, 7)
			poi_enemies(c, ["wraith", "wisp", "wraith"], 6)
			poi_chest(c + Vector2i(0, 4), true)
		"ruin":
			build_ruin(c + Vector2i(-11, -8), 22, 16, "cat")
			poi_scatter(["tomb", "statue_top", "column_top"], c, 4, 9, 6)
			poi_enemies(c, ["gargoyle", "skeleton", "skel_archer"], 6)
			poi_chest(c + Vector2i(0, 1), true)
		"hamlet":
			build_hamlet(c, 4, "village")
			poi_enemies(c, ["zombie", "ghoul", "skeleton", "rat"], 7)
			poi_chest(c + Vector2i(2, 5), rare)
		"mine":
			try_place("smithy_top", c + Vector2i(-3, -4), true)
			try_place("anvil_top", c + Vector2i(4, 2))
			try_place("cart_top", c + Vector2i(-6, 4))
			poi_scatter(["crate_top", "barrel_top", "sack_top"], c, 6, 9, 6)
			poi_enemies(c, ["imp", "ooze", "gargoyle"], 5)
			poi_chest(c + Vector2i(5, -4), true)


var dest_cells := {}      # cella -> Prop distruttibile
var terr_dmg := {}        # cella di terreno -> resistenza rimasta
var dest_warn_t := 0.0
var cut_idx := {}
var cut_idx_n := -1


func register_dest(p: Prop, name: String, cells: Array, dk: String) -> void:
	if area != "world":
		return
	var info := Destruct.classify(name)
	if info.is_empty():
		return
	p.dkey = dk
	p.dm = str(info["m"])
	p.dd = str(info["d"])
	p.hp = float(info["hp"])
	p.hp_max = p.hp
	p.dcells = cells
	for cc in cells:
		dest_cells[cc] = p


func terrain_breakable(c: Vector2i) -> bool:
	if not inb(c) or grid[idx(c)] != 0 or outside[idx(c)] == 1 or water[idx(c)] == 1:
		return false
	if c.x < 8 or c.y < 8 or c.x > Game.MW - 9 or c.y > Game.MH - 9:
		return false
	return biome[idx(c)] != 3


## un colpo dell'arma contro l'oggetto o il muro piu' vicino davanti al giocatore
func world_strike(pos: Vector2, face: Vector2, reach: float, arc: float, mult: float, fam: String) -> void:
	if area != "world":
		return
	var a0 := face.angle()
	var pc := Vector2i(floori(pos.x / Game.TS), floori(pos.y / Game.TS))
	var rr := int(ceil(reach / Game.TS)) + 1
	var best := 1e9
	var bc := Vector2i(-1, -1)
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var c := pc + Vector2i(dx, dy)
			if not inb(c):
				continue
			if dest_cells.has(c) and not is_instance_valid(dest_cells[c]):
				dest_cells.erase(c)   # l'oggetto e' stato rimosso da altro (es. area ripulita)
			if not dest_cells.has(c) and not terrain_breakable(c):
				continue
			var v := Vector2(c) * Game.TS + Vector2(8, 8) - pos
			var d := v.length()
			if d > reach + 7.0 or d >= best or abs(angle_difference(a0, v.angle())) > arc + 0.2:
				continue
			best = d
			bc = c
	if bc.x < 0:
		return
	var p: Prop = null
	if dest_cells.has(bc):
		p = dest_cells[bc]
	var mat := ""
	var left := 0.0
	var tot := 0.0
	var drop_kind := ""
	if p != null:
		mat = p.dm
		tot = p.hp_max
		left = p.hp
		drop_kind = p.dd
	else:
		var ti := Destruct.terrain(biome[idx(bc)])
		mat = str(ti["m"])
		tot = float(ti["hp"])
		left = float(terr_dmg.get(bc, tot))
		drop_kind = str(ti["d"])
	var e := Destruct.eff(fam, mat)
	left -= 10.0 * mult * e * (1.0 + 0.04 * player.a("for"))
	var cp := Vector2(bc) * Game.TS + Vector2(8, 8)
	burst(cp, Destruct.COL[mat], 6, 38.0, 0.35)
	snd("hit")
	shake(1.2)
	var now := Time.get_ticks_msec() / 1000.0
	if e < 0.3 and now > dest_warn_t:
		dest_warn_t = now + 3.5
		say("TROPPO DURO: SERVE %s" % Destruct.TOOL[mat])
	if left <= 0.0:
		destroy_at(bc, p, mat, drop_kind)
		return
	if p != null:
		p.hp = left
		p.spr.self_modulate = Color(1.6, 1.6, 1.6)
		var tw := p.spr.create_tween()
		tw.tween_property(p.spr, "self_modulate", Color.WHITE, 0.14)
	else:
		terr_dmg[bc] = left
	popup(cp + Vector2(0, -14), "%d%%" % int(ceil(100.0 * left / tot)), Color(1.0, 0.9, 0.7))


func destroy_at(c: Vector2i, p: Prop, mat: String, kind: String, loot := true) -> void:
	var cp := Vector2(c) * Game.TS + Vector2(8, 8)
	if p != null:
		for cc in p.dcells:
			block.erase(cc)
			dest_cells.erase(cc)
		persist["broken"][p.dkey] = true
		cp = p.position + Vector2(0, -8)
		p.queue_free()
	else:
		grid[idx(c)] = 1
		reach[idx(c)] = 1
		terr_dmg.erase(c)
		persist["broken"]["cut:" + key(c)] = true
		cut_idx_n = -1
		if wr_node != null:
			wr_node.cut_cell(c.x, c.y)
	burst(cp, Destruct.COL[mat], 18, 70.0, 0.55)
	snd("kill")
	shake(2.5)
	if not loot:
		return
	match kind:
		"albero":
			add_mat("legna", randi_range(2, 4))
			if randf() < 0.3:
				add_mat("erba", 1)
		"arbusto":
			add_mat("erba", randi_range(1, 2))
			if randf() < 0.3:
				add_mat("fungo", 1)
		"legna":
			add_mat("legna", randi_range(1, 2))
		"erba":
			add_mat("erba", randi_range(1, 2))
		"osso":
			add_mat("osso", randi_range(1, 2))
		"ferro":
			add_mat("minerale", randi_range(2, 3))
		"cristallo":
			add_mat("minerale", randi_range(2, 4))
			player.add_souls(40)
		"roccia":
			add_mat("minerale", randi_range(3, 6))
			player.add_souls(120)
		_:
			add_mat("minerale", randi_range(1, 3))
	if randf() < 0.08:
		player.add_souls(randi_range(20, 60))


## muri e alberi del bosco gia' abbattuti: li ripristina come tagliati quando il blocco viene creato
func apply_cuts(cx: int, cy: int) -> void:
	if cut_idx_n != persist["broken"].size():
		cut_idx.clear()
		for k in persist["broken"]:
			var ks := str(k)
			if ks.begins_with("cut:world:"):
				var xy := ks.substr(10).split(",")
				var cc := Vector2i(int(xy[0]), int(xy[1]))
				var ck := Vector2i(cc.x / CH, cc.y / CH)
				if not cut_idx.has(ck):
					cut_idx[ck] = []
				(cut_idx[ck] as Array).append(cc)
		cut_idx_n = persist["broken"].size()
	var lst: Array = cut_idx.get(Vector2i(cx, cy), [])
	for cc in lst:
		if inb(cc) and grid[idx(cc)] == 0:
			grid[idx(cc)] = 1
			reach[idx(cc)] = 1
			wr_node.cut_cell(cc.x, cc.y)


func fp_w(nm: String) -> int:
	if nm.begins_with("roof_"):
		return int(nm.split("_")[1].split("x")[0])
	return tex_fp(nm).x


## esegue le istruzioni di un modello (luogo o micro-composizione) attorno alla cella c
func run_ops(c: Vector2i, ops: Array, flip: bool, rare: bool) -> void:
	for op in ops:
		match str(op[0]):
			"p", "pf":
				var nm: String = op[1]
				var dx := int(op[2])
				var dy := int(op[3])
				if flip:
					dx = -dx - (fp_w(nm) - 1)
				try_place(nm, c + Vector2i(dx, dy), str(op[0]) == "pf")
			"t":
				var dxt := int(op[2])
				place_tree(str(op[1]), c + Vector2i(-dxt if flip else dxt, int(op[3])))
			"a":
				var dxa := int(op[2])
				add_prop(str(op[1]), c + Vector2i(-dxa if flip else dxa, int(op[3])))
			"f":
				var x0 := int(op[1])
				var x1 := int(op[3])
				var g0 := int(op[5])
				var g1 := int(op[6])
				if flip and int(op[2]) == int(op[4]):
					var ln := x1 - x0
					var nx0 := -x1
					var nx1 := -x0
					x0 = nx0
					x1 = nx1
					var ng0 := ln - g1
					var ng1 := ln - g0
					g0 = ng0
					g1 = ng1
				fence_line(c + Vector2i(x0, int(op[2])), c + Vector2i(x1, int(op[4])), g0, g1, bool(op[7]))
			"r":
				poi_scatter(op[1], c, int(op[2]), int(op[3]), int(op[4]))
			"tr":
				poi_trees(c, int(op[1]), int(op[2]), int(op[3]))
			"ring":
				var rr := float(op[2])
				var nn := int(op[3])
				var ph := float(op[4]) if op.size() > 4 else 0.2
				for i in nn:
					var a := TAU * i / float(nn) + ph
					try_place(str(op[1]), c + Vector2i(roundi(cos(a) * rr), roundi(sin(a) * rr)))
			"grid":
				for ix in int(op[4]):
					for iy in int(op[5]):
						place_tree(str(op[1]) + str(randi() % 4), c + Vector2i(int(op[2]) + ix * int(op[6]), int(op[3]) + iy * int(op[6])))
			"c":
				var rv = op[3]
				var is_rare: bool = (rare if str(rv) == "r" else bool(rv))
				var dxc := int(op[1])
				poi_chest(c + Vector2i(-dxc if flip else dxc, int(op[2])), is_rare)
			"e":
				poi_enemies(c, op[1], int(op[2]), int(op[3]), false)
			"k":
				add_champion(c + Vector2i(2, 2), 1.15)
			"gy":
				graveyard(c + Vector2i(int(op[1]), int(op[2])), int(op[3]), int(op[4]), "", int(op[5]))
			"ru":
				build_ruin(c + Vector2i(int(op[1]), int(op[2])), int(op[3]), int(op[4]), str(op[5]))
			"ha":
				build_hamlet(c, int(op[1]), str(op[2]))
			"legacy":
				legacy_build(str(op[1]), c, rare)
			"at":
				run_ops(c + Vector2i(int(op[1]), int(op[2])), [op[3]], false, rare)


## dettagli sparsi: piccole composizioni (cumuli di sassi, tombe isolate, carri, ossa...) in ogni blocco
func micro_chunk(key: Vector2i, eager: bool) -> void:
	PoiData.ensure_loaded()
	var r0 := chunk_cells(key)
	var n := 2 + (1 if randf() < 0.5 else 0)
	for k in n:
		var c := Vector2i(randi_range(r0.position.x + 4, r0.end.x - 5), randi_range(r0.position.y + 4, r0.end.y - 5))
		if not inb(c) or reach[idx(c)] != 1 or road[idx(c)] == 1 or block.has(c) or outside[idx(c)] == 1:
			continue
		if not far_from_sites(c, 36.0 if eager else 20.0, 12.0):
			continue
		var tpl: Dictionary = PoiData.pick(PoiData.micro, biome[idx(c)], micro_rng)
		if tpl.is_empty():
			continue
		run_ops(c, tpl["ops"], randf() < 0.5, randf() < 0.4)


## oggetti piazzati a mano con l'editor (godot/data/world_edits.json): coordinate assolute, applicati chunk per chunk
var edit_buckets := {}
var edits_loaded := false


var edits_cache := {}
var edits_cached := false


## contenuto di world_edits.json (res:// poi user://), letto una volta sola
func edits_data() -> Dictionary:
	if not edits_cached:
		edits_cached = true
		var paths: Array = ["res://data/world_edits.json", "user://world_edits.json"]
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--edits="):
				paths = [a.substr(8)]
		for path in paths:
			if FileAccess.file_exists(path):
				var d = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
				if d is Dictionary:
					edits_cache = d
	return edits_cache


## correzioni dipinte a mano: terreno (1 pavimento, 2 ostacolo, 3 acqua, 4 strada) e bioma, a tratti [y, x0, x1, valore]
func apply_paint() -> void:
	var pa: Dictionary = edits_data().get("paint", {})
	bio_ovr.resize(Game.MW * Game.MH)
	bio_ovr.fill(255)
	for run in pa.get("t", []):
		var y := int(run[0])
		for x in range(int(run[1]), int(run[2]) + 1):
			var p := Vector2i(x, y)
			if not inb(p) or x < 3 or y < 3 or x >= Game.MW - 3 or y >= Game.MH - 3:
				continue
			var i := idx(p)
			match int(run[3]):
				1:
					grid[i] = 1
					ovr[i] = 1
					water[i] = 0
				2:
					grid[i] = 0
					ovr[i] = 2
					water[i] = 0
					road[i] = 0
				3:
					grid[i] = 0
					ovr[i] = 2
					water[i] = 1
					road[i] = 0
				4:
					if water[i] == 1:
						water[i] = 0
						bridge[i] = 1
					grid[i] = 1
					ovr[i] = 1
					road[i] = 1
	for run in pa.get("b", []):
		var yb := int(run[0])
		for xb in range(int(run[1]), int(run[2]) + 1):
			if xb >= 0 and yb >= 0 and xb < Game.MW and yb < Game.MH:
				bio_ovr[yb * Game.MW + xb] = int(run[3])


## con world_edits.json che contiene "seed" il mondo e' sempre lo stesso: gli oggetti piazzati a mano restano al loro posto
func new_seed() -> int:
	if int(edits_data().get("seed", 0)) > 0:
		return int(edits_data()["seed"])
	return randi() % 100000


func edit_anchor(op: Array) -> Vector2i:
	match str(op[0]):
		"p", "pf", "t", "a", "grid":
			return Vector2i(int(op[2]), int(op[3]))
		"c", "f", "gy", "ru", "at":
			return Vector2i(int(op[1]), int(op[2]))
	return Vector2i(-1, -1)


func load_world_edits() -> void:
	edits_loaded = true
	for op in edits_data().get("ops", []):
		var a := edit_anchor(op)
		if a.x < 0 or a.y < 0:
			continue
		var key := Vector2i(a.x / CH, a.y / CH)
		if not edit_buckets.has(key):
			edit_buckets[key] = []
		(edit_buckets[key] as Array).append(op)


## popolazione (nemici, campioni, animali): il seme del mondo e' fisso, questo sale cambia a ogni nuova partita
var pop_salt := 0
var pop_rng := RandomNumberGenerator.new()
var dump_objects := false
var rem_buckets := {}
var rem_built := false


## oggetti generati dal gioco che l'editor ha tolto: [tipo, x, y]; si cancellano a fine blocco, prima del disegno
func apply_removals(key: Vector2i) -> void:
	if dump_objects:
		return
	if not rem_built:
		rem_built = true
		for r in edits_data().get("remove", []):
			var k := Vector2i(int(r[1]) / CH, int(r[2]) / CH)
			if not rem_buckets.has(k):
				rem_buckets[k] = []
			(rem_buckets[k] as Array).append(r)
	if not rem_buckets.has(key):
		return
	for r in rem_buckets[key]:
		var rc := Vector2i(int(r[1]), int(r[2]))
		for n in ents.get_children():
			if n is Prop and n.scene and n.kind == str(r[0]) and n.cell == rc:
				var f := tex_fp(n.kind)
				for dy in f.y:
					for dx in f.x:
						block.erase(Vector2i(rc.x + dx, rc.y + dy))
				n.queue_free()
				break


func apply_world_edits(key: Vector2i) -> void:
	if dump_objects:
		return
	if not edits_loaded:
		load_world_edits()
	if edit_buckets.has(key):
		run_ops(Vector2i.ZERO, edit_buckets[key], false, false)


func road_detail_chunk(key: Vector2i) -> void:
	var r0 := chunk_cells(key)
	var det := {
		0: ["cart_top", "hay_top", "barrel_top", "grave_cross_0", "lamp_top"],
		1: ["grave_cross_1", "grave_mound_0", "skullpile", "grave_slab_0"],
		2: ["log_top_0", "stump_top", "skullpile", "log_top_3"],
		3: ["log_top_1", "stump_top", "bone_ribs_1"],
		4: ["column_top", "statue_top", "grave_cross_0"],
		5: ["crystal_top_ice", "menhir_top_ice", "log_top_2"],
		6: ["barrel_top", "crate_top", "cart_top", "lamp_top"],
	}
	for y in range(maxi(6, r0.position.y), mini(Game.MH - 6, r0.end.y)):
		for x in range(maxi(6, r0.position.x), mini(Game.MW - 6, r0.end.x)):
			var i := y * Game.MW + x
			if road[i] != 1 or cobble[i] == 1 or randf() >= 0.018:
				continue
			var offs: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, -4), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(3, 3), Vector2i(-3, -3)]
			var off: Vector2i = offs[randi() % 6]
			var lst: Array = det[biome[i]]
			var nm: String = lst[randi() % lst.size()]
			try_place(nm, Vector2i(x, y) + off, nm == "lamp_top")


func mm_mark_poi(cell: Vector2i) -> void:
	if mm_img == null:
		return
	for ddy in range(-2, 3):
		for ddx in range(-2, 3):
			var q := cell + Vector2i(ddx, ddy)
			if inb(q):
				mm_img.set_pixelv(q, Color(0.85, 0.5, 1.0))
	mm_tex.update(mm_img)


func poi_tick() -> void:
	if area != "world" or player == null:
		return
	var pc := Vector2i(floori(player.position.x / (CH * Game.TS)), floori(player.position.y / (CH * Game.TS)))
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var k := pc + Vector2i(dx, dy)
			if not poi_buckets.has(k):
				continue
			for po in poi_buckets[k]:
				var key_p := "poi:%d" % int(po["id"])
				if persist["opened"].has(key_p):
					continue
				if cell_pos(po["cell"]).distance_to(player.position) < 340.0:
					persist["opened"][key_p] = true
					say("LUOGO SCOPERTO: %s" % po["n"])
					snd("page")
					mm_mark_poi(po["cell"])

func biome_at(x: int, y: int) -> int:
	var wx := x + 90.0 * gn_wz.get_noise_2d(x, y)
	var wy := y + 90.0 * gn_wz.get_noise_2d(x + 500, y + 500)
	var best := 0
	var bd := 1e12
	for si in SEEDS.size():
		var d: float = ((wx - SEEDS[si].x) * (wx - SEEDS[si].x) + (wy - SEEDS[si].y) * (wy - SEEDS[si].y)) / (float(bio_w[si]) * float(bio_w[si]))
		if d < bd:
			bd = d
			best = si
	return best


## genera il terreno di un blocco: bioma, ostacoli, costa (usa le strade e i fiumi gia' tracciati)
func gen_chunk(cx: int, cy: int) -> void:
	var key := Vector2i(cx, cy)
	if gen_chunks.has(key) or cx < 0 or cy < 0 or cx * CH >= Game.MW or cy * CH >= Game.MH:
		return
	gen_chunks[key] = false
	var w := Game.MW
	for y in range(cy * CH, mini((cy + 1) * CH, Game.MH)):
		for x in range(cx * CH, mini((cx + 1) * CH, w)):
			var i := y * w + x
			var best: int
			if (x & 1) == 0 and (y & 1) == 0:
				best = biome_at(x, y)
			elif (y & 1) == 0:
				best = biome[i - 1]
			elif (x & 1) == 0:
				best = biome[i - w]
			else:
				best = biome[i - w - 1]
			if bio_ovr.size() > i and bio_ovr[i] != 255:
				best = bio_ovr[i]
			biome[i] = best
			var thr: float = Game.BIO[best]["thr"]
			var nxc := (x - 480.0) / 538.0
			var nyc := (y - 352.0) / 397.0
			var edge := x < 3 or y < 3 or x >= w - 3 or y >= Game.MH - 3 or sqrt(nxc * nxc + nyc * nyc) + 0.30 * gn_cz.get_noise_2d(x, y) > 1.0
			outside[i] = 1 if edge else 0
			var g := 1 if (not edge and gn_nz.get_noise_2d(x, y) <= thr) else 0
			var o := ovr[i]
			if o == 1:
				g = 1
			elif o == 2:
				g = 0
			grid[i] = g
			reach[i] = g


var prof_t := 0


func prof(label: String) -> void:
	if testing and OS.get_cmdline_user_args().has("--prof"):
		var n := Time.get_ticks_msec()
		print("PROF ", label, " ", n - prof_t, " ms")
		prof_t = n


func gen_world() -> void:
	prof_t = Time.get_ticks_msec()
	init_layout()
	Game.MW = WORLD_W
	Game.MH = WORLD_H
	var n := Game.MW * Game.MH
	for arr in [grid, room_of, biome, outside, road, cobble, water, bridge, reach, ovr]:
		arr.resize(n)
	grid.fill(0)
	room_of.fill(-1)
	biome.fill(0)
	outside.fill(1)
	road.fill(0)
	cobble.fill(0)
	water.fill(0)
	bridge.fill(0)
	reach.fill(0)
	ovr.fill(0)
	gen_chunks.clear()
	spawn_buckets.clear()
	spawn_indexed = 0
	gn_nz = FastNoiseLite.new()
	gn_nz.seed = world_seed
	gn_nz.frequency = 0.055
	gn_nz.fractal_octaves = 2
	gn_wz = FastNoiseLite.new()
	gn_wz.seed = world_seed + 7
	gn_wz.frequency = 0.011
	gn_wz.fractal_octaves = 3
	gn_cz = FastNoiseLite.new()
	gn_cz.seed = world_seed + 33
	gn_cz.frequency = 0.012
	gn_cz.fractal_octaves = 3
	# radure, strade e luoghi d'interesse (tracciati sul mondo intero: costano poco)
	clear_rect(SEEDS[0], Vector2i(27, 21))
	for si in range(1, SEEDS.size()):
		clear_disc(SEEDS[si], 15)
	clear_rect(SEEDS[6], Vector2i(31, 23))
	for e in ENTR.values():
		clear_disc(e, 4)
	prof("alloc+clear")
	for rv in RIVERS:
		carve_river(rv)
	prof("fiumi")
	for ri in ROADS.size():
		road_paths[ri] = carve_path(SEEDS[ROADS[ri][0]], SEEDS[ROADS[ri][1]])
	carve_path(SEEDS[3], ENTR["dF"])
	carve_path(SEEDS[2], ENTR["d0"])
	carve_path(SEEDS[1], ENTR["d1"])
	carve_path(SEEDS[4], ENTR["d2"])
	carve_path(SEEDS[6], ENTR["d3"])
	carve_path(SEEDS[2], ENTR["d4"])
	carve_path(SEEDS[3], ENTR["d5"])
	carve_path(SEEDS[5], ENTR["d6"])
	find_cathedral_spot()
	carve_path(SEEDS[1], ENTR["d7"] + Vector2i(9, 5))      # il sentiero arriva alla facciata da sud
	carve_path(ENTR["d7"] + Vector2i(9, 5), ENTR["d7"] + Vector2i(0, 1))
	prof("strade")
	apply_paint()
	# cancelli: al centro del ponte della strada indicata
	gate_cell.clear()
	for gd in GATE_DEF:
		var bc: Array = []
		for pc in road_paths.get(int(gd["road"]), []):
			if bridge[idx(pc)] == 1:
				bc.append(pc)
		if bc.size() > 0:
			gate_cell[gd["id"]] = bc[bc.size() / 2]
	gen_pois()
	# zone "eager": intorno ai centri regione il terreno e' generato subito (li' ci sono le strutture pianificate)
	var zones: Array = []
	for sc in SEEDS:
		zones.append([sc, Vector2i(40, 36)])
	zones.append([ENTR["dF"], Vector2i(16, 16)])
	var core := {}
	for z in zones:
		var c0: Vector2i = z[0]
		var h: Vector2i = z[1]
		for cy in range(maxi(0, (c0.y - h.y) / CH), mini((Game.MH - 1) / CH, (c0.y + h.y) / CH) + 1):
			for cx in range(maxi(0, (c0.x - h.x) / CH), mini((Game.MW - 1) / CH, (c0.x + h.x) / CH) + 1):
				core[Vector2i(cx, cy)] = true
	eager_chunks = core.keys()
	var ring := {}
	for k in core:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				ring[Vector2i(k.x + dx, k.y + dy)] = true
	for k in ring:
		gen_chunk(k.x, k.y)
	prof("terreno zone (%d blocchi)" % ring.size())


func river_protected(c: Vector2i) -> bool:
	if absi(c.x - SEEDS[0].x) < 29 and absi(c.y - SEEDS[0].y) < 23:
		return true
	for si in range(1, SEEDS.size()):
		if Vector2(c).distance_to(Vector2(SEEDS[si])) < 17.0:
			return true
	for e in ENTR.values():
		if Vector2(c).distance_to(Vector2(e)) < 7.0:
			return true
	return false


func carve_river(pts: Array) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = world_seed + 91
	nz.frequency = 0.012
	for i in range(pts.size() - 1):
		var a: Vector2 = Vector2(pts[i])
		var b: Vector2 = Vector2(pts[i + 1])
		var steps := int(a.distance_to(b))
		var dirv := (b - a).normalized()
		var perp := Vector2(-dirv.y, dirv.x)
		for s in steps:
			var t := float(s) / steps
			var meander := sin((i + t) * 2.4) * 16.0 + sin((i + t) * 7.0) * 7.0 + nz.get_noise_2d(a.x + dirv.x * s, a.y + dirv.y * s) * 18.0
			var p := a.lerp(b, t) + perp * meander
			var r := 3.0 + 1.0 * sin((i * 40 + s) * 0.09) + nz.get_noise_2d(p.x * 3, p.y * 3) * 0.6
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					if dx * dx + dy * dy > r * r:
						continue
					var c := Vector2i(roundi(p.x) + dx, roundi(p.y) + dy)
					if not inb(c) or c.x < 3 or c.y < 3 or c.x >= Game.MW - 3 or c.y >= Game.MH - 3 or river_protected(c):
						continue
					grid[idx(c)] = 0
					ovr[idx(c)] = 2
					water[idx(c)] = 1


func clear_rect(c: Vector2i, half: Vector2i) -> void:
	for y in range(c.y - half.y, c.y + half.y + 1):
		for x in range(c.x - half.x, c.x + half.x + 1):
			var p := Vector2i(x, y)
			if inb(p) and x > 2 and y > 2 and x < Game.MW - 3 and y < Game.MH - 3 and water[idx(p)] == 0:
				grid[idx(p)] = 1
				ovr[idx(p)] = 1


func clear_disc(c: Vector2i, r: int) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var p := Vector2i(x, y)
			if inb(p) and x > 2 and y > 2 and x < Game.MW - 3 and y < Game.MH - 3 and (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r * r and water[idx(p)] == 0:
				grid[idx(p)] = 1
				ovr[idx(p)] = 1


func carve_path(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var x := a.x
	var y := a.y
	while x != b.x or y != b.y:
		if randf() < 0.5 and x != b.x:
			x += 1 if x < b.x else -1
		elif y != b.y:
			y += 1 if y < b.y else -1
		else:
			x += 1 if x < b.x else -1
		out.append(Vector2i(x, y))
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var p := Vector2i(x + dx, y + dy)
				if inb(p) and p.x > 2 and p.y > 2 and p.x < Game.MW - 3 and p.y < Game.MH - 3:
					if water[idx(p)] == 1:
						water[idx(p)] = 0
						bridge[idx(p)] = 1
					grid[idx(p)] = 1
					ovr[idx(p)] = 1
					if (dx == 0 and dy == 0) or randf() < 0.4:
						road[idx(p)] = 1
	return out


func build_tiles_world() -> void:
	pass  # il terreno del mondo e' disegnato da WorldRender (shader) a fine populate_world


func populate_world() -> void:
	var v0 := SEEDS[0]
	# villaggio: falo', anziano, ingresso della cripta finale
	persist["fires"][key(v0 + Vector2i(3, 0))] = true
	add_prop("bonfire", v0 + Vector2i(3, 0))
	if not run_mode and last_fire.is_empty():
		last_fire = {"area": "world", "cell": v0 + Vector2i(3, 0)}
	var el := add_prop("elder", v0 + Vector2i(-3, -1))
	if el != null:
		el.spr.modulate = Color(0.75, 0.75, 0.85)
	place_gates()
	add_gate("d0", ENTR["d0"], Color(0.7, 0.7, 0.95))
	add_gate("dF", ENTR["dF"], Color(0.7, 0.2, 0.9))
	add_gate("d1", ENTR["d1"], Color(0.4, 0.5, 1.0))
	add_gate("d2", ENTR["d2"], Color(1.0, 0.5, 0.8))
	add_gate("d3", ENTR["d3"], Color(1.0, 0.45, 0.15))
	add_gate("d4", ENTR["d4"], Color(0.3, 0.9, 0.4))
	add_gate("d5", ENTR["d5"], Color(0.3, 0.9, 0.8))
	add_gate("d6", ENTR["d6"], Color(0.6, 0.9, 1.0))
	add_gate("d7", ENTR["d7"], Color(1.0, 0.75, 0.4))
	place_cathedral()
	# falo' agli altri centri regione e lungo le strade
	var fires: Array[Vector2i] = []
	for si in range(1, SEEDS.size()):
		fires.append(SEEDS[si] + Vector2i(3, 0))
	for rd in ROADS:
		var pth := carve_path_peek(SEEDS[rd[0]], SEEDS[rd[1]])
		for k in range(45, pth.size(), 55):
			fires.append(pth[k])
	for fc in fires:
		var ok := true
		for g in props:
			if g.kind == "bonfire" and Vector2(g.cell).distance_to(Vector2(fc)) < 18.0:
				ok = false
		if ok:
			add_prop("bonfire", fc)
	prof("camp/cancelli")
	# arredo: strutture, poi oggetti sparsi per regione
	place_structures()
	prof("strutture")
	place_passages()
	build_cloister(SEEDS[4] + Vector2i(16, 10))
	place_landmarks()
	place_shrines()
	place_arenas()
	quest_defs.clear()
	place_villagers()
	for qid2 in quest_defs:
		if quest_state(qid2) == "active" and (quest_defs[qid2]["type"] == "fetch" or quest_defs[qid2]["type"] == "poi_fetch"):
			spawn_quest_item(qid2)
	place_fauna()
	prof("luoghi/abitanti/fauna")
	place_npcs_and_pages()
	wr_node = WorldRender.new()
	add_child(wr_node)
	area_nodes.append(wr_node)
	wr_node.init_stream(self, Game.MW, Game.MH)
	for k in eager_chunks:
		finalize_chunk(k, true)
	wr_node.s_tex.update(wr_node.s_img)
	prof("finalizza %d blocchi (scatter %d ms, nook/camp %d ms, render %d ms di cui veg+alberi %d ms)" % [eager_chunks.size(), fin_prof[0] / 1000, fin_prof[1] / 1000, fin_prof[2] / 1000, fin_prof[3] / 1000])
	if run_mode:
		spawns.clear()
	index_spawns()
	spawn_all()


## completa un blocco: oggetti sparsi, luoghi nascosti, accampamenti nemici, fauna, disegno del terreno
func finalize_chunk(key: Vector2i, eager := false) -> void:
	if gen_chunks.get(key, false):
		return
	seed(world_seed * 7919 + key.x * 131 + key.y * 9973)
	pop_rng.seed = hash([world_seed, key.x, key.y, pop_salt])
	var tA := Time.get_ticks_usec()
	if poi_buckets.has(key):
		for po in poi_buckets[key]:
			build_poi(po)
	road_detail_chunk(key)
	res_chunk(key)
	micro_rng.seed = world_seed * 53 + key.x * 977 + key.y * 31
	micro_chunk(key, eager)
	apply_world_edits(key)
	scatter_chunk(key)
	var tB := Time.get_ticks_usec()
	nook_chunk(key)
	secret_chunk(key)
	seed(hash([world_seed, key.x, key.y, pop_salt, 1]))
	camp_chunk(key)
	apply_removals(key)
	if not eager:
		fauna_chunk(key)
	var tC := Time.get_ticks_usec()
	wr_node.add_chunk(key.x, key.y, not eager)
	var tD := Time.get_ticks_usec()
	fin_prof[0] += tB - tA
	fin_prof[1] += tC - tB
	fin_prof[2] += tD - tC
	gen_chunks[key] = true
	index_spawns()
	randomize()


func chunk_cells(key: Vector2i) -> Rect2i:
	return Rect2i(key.x * CH, key.y * CH, CH, CH)


var scatter_cum: Array = []


func scatter_chunk(key: Vector2i) -> void:
	var noises := {}
	var glows := 0
	if scatter_cum.is_empty():
		for bb in Scenery.OBJECTS.size():
			var acc := 0.0
			for rr in Scenery.OBJECTS[bb]:
				acc += float(rr["d"]) * 1.8
			scatter_cum.append(acc)
	var r0 := chunk_cells(key)
	for y in range(maxi(5, r0.position.y), mini(Game.MH - 5, r0.end.y)):
		for x in range(maxi(5, r0.position.x), mini(Game.MW - 5, r0.end.x)):
			var i := y * Game.MW + x
			if reach[i] != 1 or road[i] == 1 or cobble[i] == 1:
				continue
			if absi(x - SEEDS[0].x) < 28 and absi(y - SEEDS[0].y) < 22:
				continue
			var b: int = biome[i]
			var rules: Array = Scenery.OBJECTS[b]
			var roll0 := randf()
			if roll0 >= float(scatter_cum[b]):
				continue
			for ri in rules.size():
				var r: Dictionary = rules[ri]
				var dens: float = r["d"]
				var roll := randf()
				if roll >= dens * 1.8:
					continue
				if r.has("cf"):
					var nk := b * 16 + ri
					if not noises.has(nk):
						var nz := FastNoiseLite.new()
						nz.seed = world_seed + nk * 17
						nz.frequency = r["cf"]
						noises[nk] = nz
					var n := (((noises[nk] as FastNoiseLite).get_noise_2d(x, y)) + 1.0) * 0.5
					dens *= smoothstep(r["ct"], r["ct"] + 0.15, n) * 1.8
				if roll >= dens:
					continue
				var names: Array = r["n"]
				var nm: String = names[randi() % names.size()]
				var want_fx := false
				if not Scenery.glow(nm).is_empty():
					if glows >= 2:
						continue
					want_fx = true
					glows += 1
				var pr: Prop = null
				if nm.begins_with("bush_") or nm.begins_with("circle_top"):
					place_tree(nm, Vector2i(x, y))
				else:
					pr = try_place(nm, Vector2i(x, y), want_fx)
				if pr != null:
					break


func far_from_sites(c: Vector2i, d_seed: float, d_entr: float) -> bool:
	for sc in SEEDS:
		if Vector2(c).distance_to(Vector2(sc)) < d_seed:
			return false
	for e in ENTR.values():
		if Vector2(c).distance_to(Vector2(e)) < d_entr:
			return false
	return true


func nook_chunk(key: Vector2i) -> void:
	if randf() >= 0.62:
		return
	var r0 := chunk_cells(key)
	for att in 10:
		var c := Vector2i(randi_range(r0.position.x + 5, r0.end.x - 6), randi_range(r0.position.y + 5, r0.end.y - 6))
		if not inb(c) or c.x < 12 or c.y < 12 or c.x > Game.MW - 12 or c.y > Game.MH - 12:
			continue
		if reach[idx(c)] != 1 or road[idx(c)] == 1 or not far_from_sites(c, 24.0, 14.0):
			continue
		clear_disc(c, 4)
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var p := c + Vector2i(dx, dy)
				if inb(p) and grid[idx(p)] == 1 and reach[idx(p)] == 0:
					reach[idx(p)] = 1
		nook_count += 1
		decorate_nook(c, biome[idx(c)])
		var rare := nook_count % 4 == 0
		if not rare and pop_rng.randf() < 0.5:
			continue   # non ogni angolo nascosto ha un tesoro
		var ch := add_prop("chest", c)
		if ch != null:
			ch.rare = rare
			if rare:
				ch.spr.modulate = Color(1.6, 1.3, 0.6)
				Game.make_light(ch, Vector2(0, -8), Color(1.0, 0.85, 0.4), 1.0, 0.8)
		add_group(c + Vector2i(3, 1), 2 + randi() % 2)
		if randf() < 0.6:
			add_champion(c + Vector2i(-3, 1))
		return


func camp_chunk(key: Vector2i) -> void:
	var r0 := chunk_cells(key)
	for att in 4:
		var c := Vector2i(randi_range(r0.position.x + 3, r0.end.x - 4), randi_range(r0.position.y + 3, r0.end.y - 4))
		if not inb(c) or c.x < 8 or c.y < 8 or c.x > Game.MW - 8 or c.y > Game.MH - 8:
			continue
		if reach[idx(c)] != 1 or road[idx(c)] == 1 or block.has(c):
			continue
		if Vector2(c).distance_to(Vector2(SEEDS[0])) < 30.0:
			continue
		var near_camp := false
		for g in props:
			if g.kind == "bonfire" and Vector2(g.cell).distance_to(Vector2(c)) < 9.0:
				near_camp = true
				break
		if near_camp:
			continue
		add_group(c, 1 + randi() % 4)


func fauna_chunk(key: Vector2i) -> void:
	var r0 := chunk_cells(key)
	var cfg := {
		0: [["rat", 0.5], ["bird", 0.5], ["rabbit", 0.4]],
		1: [["bird", 0.9], ["rat", 0.4]],
		2: [["deer", 1.6], ["rabbit", 1.2], ["bird", 0.8], ["fox", 0.4]],
		3: [["frog", 1.8], ["bird", 0.4]],
		4: [["bird", 0.8], ["rat", 0.4]],
		5: [["fox", 0.8], ["rabbit", 0.5]],
		6: [["rat", 0.8], ["bird", 0.5]],
	}
	var tints := {"fox": Color(1, 0.7, 0.4)}
	for att in 2:
		var c0 := Vector2i(randi_range(r0.position.x + 2, r0.end.x - 3), randi_range(r0.position.y + 2, r0.end.y - 3))
		if not inb(c0) or reach[idx(c0)] != 1:
			continue
		var bi: int = biome[idx(c0)]
		for entry in cfg[bi]:
			var cnt := int(entry[1] * 0.5) + (1 if randf() < fmod(entry[1] * 0.5, 1.0) else 0)
			for k in cnt:
				var c := c0 + Vector2i(randi_range(-6, 6), randi_range(-6, 6))
				if not inb(c) or not is_floor(c) or block.has(c) or outside[idx(c)] == 1 or water[idx(c)] == 1:
					continue
				var tn := Color.WHITE
				if bi == 5:
					tn = Color(1.6, 1.7, 1.9)
				elif tints.has(entry[0]):
					tn = tints[entry[0]]
				var cr := Critter.new()
				cr.setup(self, str(entry[0]), cell_pos(c), tn)
				ents.add_child(cr)
				critters.append(cr)


## caricamento in corsa: il terreno intorno al giocatore viene generato a blocchi, con un piccolo budget per fotogramma
func stream_update() -> void:
	if area != "world" or player == null or wr_node == null:
		return
	var t0 := Time.get_ticks_usec()
	var pc := Vector2i(floori(player.position.x / (CH * Game.TS)), floori(player.position.y / (CH * Game.TS)))
	var cand: Array = []
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var k := pc + Vector2i(dx, dy)
			if k.x < 0 or k.y < 0 or k.x * CH >= Game.MW or k.y * CH >= Game.MH:
				continue
			if gen_chunks.get(k, false):
				continue
			cand.append(k)
	cand.sort_custom(func(a, b): return (a - pc).length_squared() < (b - pc).length_squared())
	for k: Vector2i in cand:
		if Time.get_ticks_usec() - t0 > 9000:
			break
		if not gen_chunks.has(k):
			gen_chunk(k.x, k.y)
			continue
		# completo il blocco solo quando i vicini hanno il terreno
		if (k - pc).length_squared() > 9:
			continue
		var ready := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var nk: Vector2i = k + Vector2i(dx, dy)
				if nk.x >= 0 and nk.y >= 0 and nk.x * CH < Game.MW and nk.y * CH < Game.MH and not gen_chunks.has(nk):
					ready = false
		if ready:
			finalize_chunk(k)


## genera subito (in modo sincrono) l'area attorno a un punto: per viaggi rapidi, riprese, passaggi
func ensure_area(pos: Vector2, rad := 2) -> void:
	if area != "world" or wr_node == null:
		return
	var pc := Vector2i(floori(pos.x / (CH * Game.TS)), floori(pos.y / (CH * Game.TS)))
	for dy in range(-rad - 1, rad + 2):
		for dx in range(-rad - 1, rad + 2):
			gen_chunk(pc.x + dx, pc.y + dy)
	for dy in range(-rad, rad + 1):
		for dx in range(-rad, rad + 1):
			var k := pc + Vector2i(dx, dy)
			if k.x >= 0 and k.y >= 0 and k.x * CH < Game.MW and k.y * CH < Game.MH:
				finalize_chunk(k)


# ---------------------------------------------------------------- nemici fissi: compaiono solo vicino al giocatore
func index_spawns() -> void:
	for i in range(spawn_indexed, spawns.size()):
		var e: Dictionary = spawns[i]
		var pos: Vector2 = e["pos"]
		var k := Vector2i(floori(pos.x / (CH * Game.TS)), floori(pos.y / (CH * Game.TS)))
		if not spawn_buckets.has(k):
			spawn_buckets[k] = []
		(spawn_buckets[k] as Array).append(e)
		e["alive"] = true
		e["node"] = null
	spawn_indexed = spawns.size()


func spawn_tick() -> void:
	if area != "world" or player == null:
		return
	var pc := Vector2i(floori(player.position.x / (CH * Game.TS)), floori(player.position.y / (CH * Game.TS)))
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var k := pc + Vector2i(dx, dy)
			if not spawn_buckets.has(k):
				continue
			for e in spawn_buckets[k]:
				var node = e.get("node")
				var d2: float = (e["pos"] as Vector2).distance_squared_to(player.position)
				if node != null and is_instance_valid(node):
					if d2 > 1000000.0 and not node.is_boss and not node.champ:
						enemies.erase(node)
						node.queue_free()
						e["node"] = null
				elif e["alive"] and d2 < 490000.0 and spawn_present(e):
					var en := spawn_enemy(e["k"], e["pos"], e["mult"], e["elite"], e["tint"])
					en.sref = e
					e["node"] = en


## quanti nemici popolano il mondo cresce col livello: all'inizio circa la meta', poi tutti (dal livello ~14).
## La scelta e' fissa per ogni posto (non cambia avvicinandosi e allontanandosi).
func spawn_present(e: Dictionary) -> bool:
	if run_mode:
		return true
	var keep := clampf(0.5 + 0.04 * float(player.lv - 1), 0.5, 1.0)
	var p: Vector2 = e["pos"]
	var h := absi(int(p.x) * 73856093 ^ int(p.y) * 19349663) % 1000
	return h < int(keep * 1000.0)


## ferocia dei nemici: piu' lenti e meno aggressivi ai primi livelli, a pieno regime verso il livello 13
func ferocity(boss: bool) -> float:
	if run_mode or player == null:
		return 1.0
	var lvf := float(player.lv - 1)
	return clampf(0.85 + 0.0125 * lvf, 0.85, 1.0) if boss else clampf(0.68 + 0.027 * lvf, 0.68, 1.0)


func spawn_all() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for k in spawn_buckets:
		for e in spawn_buckets[k]:
			e["alive"] = true
			e["node"] = null
	for c in fx.get_children():
		if c is Projectile:
			c.queue_free()
	if area == "world":
		index_spawns()
		spawn_tick()
		return
	for s in spawns:
		spawn_enemy(s["k"], s["pos"], s["mult"], s["elite"], s["tint"])
	if boss_kind == "boss_campanaro":
		if not persist["bosses"].has(boss_kind):
			colossus = Colossus.new()
			colossus.position = boss_pos
			ents.add_child(colossus)
			colossus.setup(self, camp_locks)
	elif boss_kind != "" and not persist["bosses"].has(boss_kind):
		spawn_enemy(boss_kind, boss_pos, 1.0, false, boss_tint)


## cerca vicino al cimitero un'area tutta calpestabile per la cattedrale; l'ingresso va davanti alla sua porta
func find_cathedral_spot() -> void:
	var f := tex_fp("cathedral_top")
	var want: Vector2i = SEEDS[1] + Vector2i(-22, 18)
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for dy in range(-30, 31, 2):
		for dx in range(-30, 31, 2):
			var g := want + Vector2i(dx, dy)
			var c := g + Vector2i(-f.x / 2, -f.y)
			var ok := true
			for y in range(-1, f.y + 2):
				for x in range(-1, f.x + 1):
					var cc := c + Vector2i(x, y)
					if not is_floor(cc) or reserved.has(cc):
						ok = false
						break
				if not ok:
					break
			if ok:
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best_d = d
					best = g
	if best.x >= 0:
		ENTR["d7"] = best


## la cattedrale in rovina sopra l'ingresso del Campanile: il portale e' davanti alla porta del campanile
func place_cathedral() -> void:
	var g: Vector2i = ENTR["d7"]
	var f := tex_fp("cathedral_top")
	var c := g + Vector2i(-f.x / 2, -f.y)
	for y in f.y:
		for x in f.x:
			var cc := c + Vector2i(x, y)
			if is_floor(cc):
				reserved.erase(cc)
				block.erase(cc)
	world_has_cathedral = try_place("cathedral_top", c) != null
	if not world_has_cathedral:
		print("CATTEDRALE: spazio occupato a ", c)


## navata del Campanaro: colonne con i lucchetti delle catene, bracieri, macerie
func arena_props(r: Rect2i) -> void:
	var cx := center(r).x
	var base := Vector2i(cx, r.position.y + 11)
	boss_pos = cell_pos(base) + Vector2(0, -8)
	camp_locks.clear()
	for c in [base + Vector2i(-10, 3), base + Vector2i(10, 3), base + Vector2i(-9, -6), base + Vector2i(9, -6)]:
		add_prop("column_top", c)
		camp_locks.append(cell_pos(c) + Vector2(0, 10))
	for y in range(r.position.y + 2, r.end.y - 2, 5):
		for x in [r.position.x + 1, r.end.x - 2]:
			if randf() < 0.6:
				try_place("column_top", Vector2i(x, y))
	for c in [Vector2i(cx - 3, r.end.y - 3), Vector2i(cx + 3, r.end.y - 3), Vector2i(r.position.x + 2, r.position.y + 1),
			Vector2i(r.end.x - 3, r.position.y + 1)]:
		add_prop("brazier", c)
	try_place("camp_bellfall", Vector2i(cx - 15, r.position.y + 2))      # la campana caduta dal campanile
	try_place("camp_rubble", Vector2i(cx + 11, r.position.y + 1))        # le macerie della torre crollata
	for k in 14:
		var c2 := Vector2i(randi_range(r.position.x + 2, r.end.x - 3), randi_range(r.position.y + 15, r.end.y - 2))
		if absi(c2.x - cx) > 2:
			try_place(["skullpile", "boulder_cem_%d" % (randi() % 8), "candelabra"][randi() % 3], c2)


func carve_path_peek(a: Vector2i, b: Vector2i) -> Array:
	var out: Array = []
	var x := a.x
	var y := a.y
	while x != b.x or y != b.y:
		if x != b.x and (absi(b.x - x) > absi(b.y - y) or y == b.y):
			x += 1 if x < b.x else -1
		else:
			y += 1 if y < b.y else -1
		out.append(Vector2i(x, y))
	return out


func add_group(c: Vector2i, n: int) -> void:
	var bi: int = biome[idx(c)]
	var b: Dictionary = Game.BIO[bi]
	var pool: Array = b["pool"]
	var dist := Vector2(c).distance_to(Vector2(SEEDS[0])) / WS
	var mult: float = 1.0 + int(b["tier"]) * 0.38
	var kind0: String = pool[pop_rng.randi() % pool.size()]
	if kind0 == "rat":
		n = pop_rng.randi_range(4, 6)
	if kind0 != "rat" and pop_rng.randf() < 0.6:
		n += 1
	for k in n:
		var cc := c + Vector2i(pop_rng.randi_range(-2, 2), pop_rng.randi_range(-2, 2))
		if is_floor(cc) and not block.has(cc):
			var kk: String = kind0 if (kind0 == "rat" or pop_rng.randf() < 0.5) else pool[pop_rng.randi() % pool.size()]
			spawns.append({"k": kk, "pos": cell_pos(cc), "mult": mult, "elite": pop_rng.randf() < 0.12, "tint": b["tint"]})
	if b["tier"] > 0 and pop_rng.randf() < 0.16:
		add_champion(c + Vector2i(1, 1))


func free_spot(c: Vector2i, f: Vector2i) -> Vector2i:
	for r in range(0, 8):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var cc := c + Vector2i(dx, dy)
				if area_free(cc, f):
					return cc
	return Vector2i(-1, -1)


func place_passages() -> void:
	passages.clear()
	for pd in PASSAGES:
		var ends: Array = []
		for key_e in ["a", "b"]:
			var c0: Vector2i = pd[key_e]
			clear_disc(c0, 4)
			for dy in range(-4, 5):
				for dx in range(-4, 5):
					var cc := c0 + Vector2i(dx, dy)
					if inb(cc) and grid[idx(cc)] == 1 and reach[idx(cc)] == 0:
						reach[idx(cc)] = 1
			var sp := free_spot(c0, Vector2i(2, 2))
			if sp.x < 0:
				break
			var pr := try_place("stairs_top", sp, true)
			if pr == null:
				break
			pr.dest = pd["id"] + key_e
			ends.append(pr)
		if ends.size() == 2:
			passages[ends[0].dest] = ends[1].cell
			passages[ends[1].dest] = ends[0].cell
			for pr in ends:
				props.append(pr)
				Game.make_light(pr, Vector2(16, 16), Color(0.55, 0.5, 0.95), 1.4, 0.55)


func use_stairs(p: Prop) -> void:
	if state != "play" or not passages.has(p.dest):
		return
	var dest_c: Vector2i = passages[p.dest]
	state = "fade"
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.3)
	tw.tween_callback(func():
		ensure_area(cell_pos(dest_c), 2)
		player.position = cell_pos(dest_c + Vector2i(2, 3))
		player.cam.reset_smoothing()
		snd("slam")
		for pd in PASSAGES:
			if p.dest.begins_with(pd["id"]):
				say(str(pd["msg"])))
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): if state == "fade": state = "play")


## Chiostro dei Silenzi: cortile quadrato con portico di colonne, statua centrale, falo' nascosto e un tesoro custodito
func build_cloister(c: Vector2i) -> void:
	var hw := 11
	var hh := 7
	for dy in range(-hh - 2, hh + 3):
		for dx in range(-hw - 2, hw + 3):
			var cc := c + Vector2i(dx, dy)
			if inb(cc) and cc.x > 3 and cc.y > 3 and cc.x < Game.MW - 4 and cc.y < Game.MH - 4 and water[idx(cc)] == 0:
				grid[idx(cc)] = 1
				reach[idx(cc)] = 1
				cobble[idx(cc)] = 1 if (absi(dx) <= hw and absi(dy) <= hh) else cobble[idx(cc)]
	for dx in range(-hw, hw + 1, 2):
		if absi(dx) > 1:
			try_place("column_top", c + Vector2i(dx, -hh))
			try_place("column_top", c + Vector2i(dx, hh))
	for dy in range(-hh + 2, hh - 1, 2):
		if absi(dy) > 1:
			try_place("column_top", c + Vector2i(-hw, dy))
			try_place("column_top", c + Vector2i(hw, dy))
	try_place("statue_top", c + Vector2i(-1, -1), true)
	for p in [Vector2i(-6, -3), Vector2i(-6, 3), Vector2i(6, -3), Vector2i(6, 3), Vector2i(-8, 0), Vector2i(8, 0)]:
		try_place("tomb", c + p)
	add_prop("bonfire", c + Vector2i(0, 4))
	var ch := add_prop("chest", c + Vector2i(0, -5))
	if ch != null:
		ch.rare = true
		ch.spr.modulate = Color(1.6, 1.3, 0.6)
		Game.make_light(ch, Vector2(0, -8), Color(1.0, 0.85, 0.4), 1.0, 0.8)
	add_champion(c + Vector2i(-4, 1), 1.4)
	add_champion(c + Vector2i(4, 1), 1.4)
	add_group(c + Vector2i(0, -2), 3)


func objective() -> String:
	if run_mode:
		if run_boss_alive:
			return "SCONFIGGI IL CUSTODE!"
		if run_stage >= RUN_BOSSES.size():
			return "LA VALLE E' LIBERA"
		var left := maxi(0, int(run_boss_time() - run_t))
		return "CUSTODE IN ARRIVO %d:%02d" % [left / 60, left % 60]
	if not persist["bosses"].has("boss_jailer"):
		return "ESCI DALLE CELLE: SCONFIGGI IL CARCERIERE"
	if journey_step() < JOURNEY_N:
		return journey_text()
	if guardians >= 3:
		return "ENTRA NELLA CRIPTA DEL SIGNORE (A NORD) E SCONFIGGILO"
	if not persist["bosses"].has("boss_wraith"):
		return "SCONFIGGI IL CUSTODE DEL CIMITERO (EST DEL VILLAGGIO)"
	if not persist["bosses"].has("boss_gargoyle"):
		return "OLTRE IL CANCELLO A EST: SCONFIGGI IL CUSTODE DELLA CATTEDRALE"
	return "ENTRA NELLE FORGE PROFONDE E SCONFIGGI L'ULTIMO CUSTODE"


## SEGRETI: tumuli di terra smossa con un debole bagliore, da scavare (ricompensa varia, a volte una brutta sorpresa)
func secret_chunk(key: Vector2i) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 31 + key.x * 7919 + key.y * 104729 + 55
	if rng.randf() >= 0.4:
		return
	var r0 := chunk_cells(key)
	for att in 12:
		var c := Vector2i(rng.randi_range(r0.position.x + 3, r0.end.x - 4), rng.randi_range(r0.position.y + 3, r0.end.y - 4))
		if not inb(c) or c.x < 10 or c.y < 10 or c.x > Game.MW - 10 or c.y > Game.MH - 10:
			continue
		if reach[idx(c)] != 1 or road[idx(c)] == 1 or cobble[idx(c)] == 1 or outside[idx(c)] == 1 or in_settlement(c):
			continue
		var pr := add_prop("dig", c)
		if pr == null:
			continue
		pr.spr.texture = Game.tex("grave_mound_%d" % rng.randi_range(0, 4))
		pr.spr.offset = Vector2(0, -4)
		pr.spr.modulate = Color(0.9, 0.95, 1.0)
		var l := Game.make_light(pr, Vector2(0, -4), Color(0.5, 0.9, 1.0), 0.45, 0.55)
		flick.append([l, 0.55, rng.randf() * 10.0])
		return


func add_item(id: String, n: int) -> bool:
	var have := int(player.items.get(id, 0))
	if have >= 9:
		return false
	player.items[id] = mini(9, have + n)
	belt_auto(id)
	if item_ids().size() == 1:
		player.item_sel = 0
	return true


## ogni tipo di luogo ha una ricompensa propria nello scrigno: vale la pena sceglierli
func poi_bonus(t: String, pos: Vector2) -> void:
	var bi: int = biome_at(int(pos.x / Game.TS), int(pos.y / Game.TS)) if area == "world" else 0
	var tier: int = int(Game.BIO[bi]["tier"])
	var txt := ""
	match t:
		"farm", "barn", "orchard", "mill":
			add_item("arrosto", 2)
			add_mat("erba", 4)
			txt = "DISPENSA: 2 ARROSTI E ERBE"
		"church", "family", "mounds", "hermit":
			add_item("infuso", 2)
			player.add_souls(120 + 80 * tier)
			txt = "OFFERTE DEI FEDELI: 2 INFUSI E ANIME"
		"altar", "obelisks", "witch":
			add_item("forza", 1)
			add_item("fuoco", 1)
			drop_relic(pos + Vector2(10, 8))
			txt = "RITO ANTICO: UNA RELIQUIA E DUE ELISIR"
		"bandits", "toll", "caravan", "crossroads":
			var n := int(randi_range(150, 300) * (1.0 + tier * 0.5))
			player.add_souls(n)
			drop_loot(pos + Vector2(0, 12), Rpg.make_weapon(clampi(tier / 2, 0, 2)))
			txt = "BOTTINO: %d ANIME E UN'ARMA" % n
		"tower", "gallows", "scarecrow":
			drop_loot(pos + Vector2(0, 12), Rpg.make_weapon(clampi(1 + tier / 3, 1, 2)))
			add_item("pelle", 1)
			txt = "ARSENALE: UN'ARMA SCELTA E UN TONICO"
		"cave", "quarry", "mine":
			add_mat("minerale", randi_range(5, 8))
			add_mat("osso", randi_range(3, 5))
			add_mat("pelle", 3)
			txt = "FILONE: MINERALE, OSSA E PELLI"
		"well", "ruin":
			grant_grace()
			txt = "BENEDIZIONE DEI SEPOLTI"
		_:
			add_item("pelle", 1)
			player.add_souls(100 + 60 * tier)
			txt = "PICCOLO TESORO"
	popup(pos + Vector2(0, -22), txt, Color(1.0, 0.9, 0.5))
	msg_t = 5.0


func dir_name(v: Vector2) -> String:
	var a := fposmod(rad_to_deg(atan2(v.y, v.x)) + 22.5, 360.0)
	return ["EST", "SUD-EST", "SUD", "SUD-OVEST", "OVEST", "NORD-OVEST", "NORD", "NORD-EST"][int(a / 45.0) % 8]


## una pagina di diario svela un luogo non ancora scoperto, oppure un tumulo luminoso vicino
func page_hint() -> String:
	if area != "world":
		return ""
	var best: Dictionary = {}
	var bd := 1e12
	for po in pois:
		if persist["opened"].has("poi:%d" % int(po["id"])):
			continue
		var d := cell_pos(po["cell"]).distance_to(player.position)
		if d > 340.0 and d < bd:
			bd = d
			best = po
	var digs: Array = []
	for p in props:
		if p.kind == "dig" and p.position.distance_to(player.position) < 900.0:
			digs.append(p)
	if not digs.is_empty() and (best.is_empty() or randf() < 0.4):
		var dp: Prop = digs[0]
		for p in digs:
			if p.position.distance_to(player.position) < dp.position.distance_to(player.position):
				dp = p
		return "  ...  Una luce azzurra brilla sotto la terra, a %s." % dir_name(dp.position - player.position)
	if not best.is_empty():
		mm_mark_poi(best["cell"])
		return "  ...  Segni sulla mappa: %s, a %s." % [str(best["n"]).to_upper(), dir_name(cell_pos(best["cell"]) - player.position)]
	return ""


func dig_up(p: Prop) -> void:
	props.erase(p)
	block.erase(p.cell)
	persist["broken"][key(p.cell)] = true
	var bi: int = biome[idx(p.cell)] if area == "world" else 0
	var tier: int = int(Game.BIO[bi]["tier"])
	var pos := p.position
	burst(pos, Color(0.55, 0.45, 0.35), 14, 40.0, 0.5)
	snd("page")
	p.queue_free()
	var r := randf()
	if r < 0.45:
		var n := int(randi_range(60, 180) * (1.0 + tier * 0.4))
		player.add_souls(n)
		popup(pos + Vector2(0, -16), "+%d ANIME" % n, Color(0.6, 1.0, 0.85))
		say("SOTTO LA TERRA: ANIME INTRAPPOLATE")
	elif r < 0.72:
		var mid: String = MAT_ORDER[randi() % 4]
		add_mat(mid, randi_range(3, 6))
		say("SOTTO LA TERRA: MATERIALI NASCOSTI")
	elif r < 0.85:
		drop_relic(pos + Vector2(0, 10))
		say("SOTTO LA TERRA: UNA RELIQUIA!")
	elif r < 0.93:
		drop_loot(pos + Vector2(0, 10), Rpg.make_weapon(clampi(tier / 2, 0, 2)))
		say("SOTTO LA TERRA: UN'ARMA DIMENTICATA")
	else:
		say("UN'ANIMA INQUIETA SI RISVEGLIA!")
		var info := event_pool(p.cell)
		var pool: Array = info["pool"]
		for i in 2 + tier / 2:
			var c := event_cell(p.cell, 2, 4)
			if c.x >= 0:
				spawn_enemy(str(pool[randi() % pool.size()]), cell_pos(c), float(info["mult"]), false, info["tint"])
	save_game()


## EVENTI DEL MONDO: imboscate lungo il cammino e "luci nel buio" (tesoro sorvegliato da cercare)
var ev_t := 75.0
var ev_chest: Prop = null
var ev_pos := Vector2.ZERO
var ev_guards: Array = []


func event_cell(near: Vector2i, rmin: int, rmax: int) -> Vector2i:
	for att in 40:
		var a := randf() * TAU
		var c := near + Vector2i(Vector2.from_angle(a) * randf_range(rmin, rmax))
		if inb(c) and is_floor(c) and reach[idx(c)] == 1 and not block.has(c) and road[idx(c)] == 0 and outside[idx(c)] == 0 and not in_settlement(c):
			return c
	return Vector2i(-1, -1)


func event_pool(c: Vector2i) -> Dictionary:
	var bi: int = biome[idx(c)]
	var b: Dictionary = Game.BIO[bi]
	return {"pool": b["pool"], "mult": 1.0 + int(b["tier"]) * 0.38, "tint": b["tint"], "bi": bi, "tier": int(b["tier"])}


func event_ambush(pc: Vector2i) -> void:
	var info := event_pool(pc)
	var n := 3 + int(info["tier"]) / 2 + randi() % 2
	var pool: Array = info["pool"]
	var made := 0
	for i in n:
		var c := event_cell(pc, 7, 11)
		if c.x < 0:
			continue
		spawn_enemy(str(pool[randi() % pool.size()]), cell_pos(c), float(info["mult"]), randf() < 0.15, info["tint"])
		made += 1
	if made > 0:
		say("IMBOSCATA!")
		snd("hurt")
		shake(3.0)


func event_treasure(pc: Vector2i) -> void:
	var c := event_cell(pc, 26, 44)
	if c.x < 0:
		return
	ensure_area(cell_pos(c), 2)
	var sp := free_spot(c, Vector2i(1, 1))
	if sp.x < 0:
		return
	var ch := add_prop("chest", sp)
	if ch == null:
		return
	ch.rare = true
	ch.spr.modulate = Color(1.6, 1.3, 0.6)
	Game.make_light(ch, Vector2(0, -8), Color(1.0, 0.85, 0.4), 1.4, 0.9)
	ev_chest = ch
	ev_pos = ch.position
	ev_guards.clear()
	var info := event_pool(sp)
	var pool: Array = info["pool"]
	for i in 3 + int(info["tier"]) / 2:
		var gc := event_cell(sp, 2, 5)
		if gc.x >= 0:
			ev_guards.append(spawn_enemy(str(pool[randi() % pool.size()]), cell_pos(gc), float(info["mult"]) * 1.1, false, info["tint"]))
	var cp: Array = CHAMP_POOL[int(info["bi"])]
	if not cp.is_empty():
		var cc := event_cell(sp, 2, 4)
		if cc.x >= 0:
			ev_guards.append(spawn_enemy(str(cp[randi() % cp.size()]), cell_pos(cc), float(info["mult"]), false, Color.WHITE))
	say("UNA LUCE NEL BUIO, A %s: CHI LA VEGLIA?" % dir_hint(ev_pos))
	snd("page")


func world_event_update(dt: float) -> void:
	if ev_chest != null and (not is_instance_valid(ev_chest) or ev_chest.opened or ev_chest.position.distance_to(player.position) > 1100.0):
		ev_chest = null
	ev_t -= dt
	if ev_t > 0.0 :
		return
	ev_t = randf_range(80.0, 140.0)
	var pc := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
	if not inb(pc) or in_settlement(pc) or outside[idx(pc)] == 1:
		return
	for pr in props:
		if pr.kind == "bonfire" and pr.position.distance_to(player.position) < 150.0:
			return  # vicino a un accampamento si e' al sicuro
	if randf() < 0.55 or ev_chest != null:
		event_ambush(pc)
	else:
		event_treasure(pc)


## IL CAMMINO: catena di tappe guidate dopo le Celle (parlare, scoprire, liberare, crescere, raggiungere un luogo)
const JOURNEY_N := 5


func journey_step() -> int:
	if not persist.has("journey") and (persist["bosses"].has("boss_wraith") or guardians > 0):
		return JOURNEY_N  # salvataggi gia' avanzati: niente tappe iniziali
	return int(persist.get("journey", 0))


func journey_target() -> Variant:
	if area != "world" or journey_step() >= JOURNEY_N or not persist["bosses"].has("boss_jailer"):
		return null
	match journey_step():
		0:
			for p in props:
				if p.kind == "elder":
					return p.position
			return cell_pos(SEEDS[0] + Vector2i(-3, -1))
		1:
			var best: Variant = null
			for p in props:
				if p.kind == "page" and (best == null or p.position.distance_to(player.position) < (best as Vector2).distance_to(player.position)):
					best = p.position
			return best
		2:
			var pi := int(persist.get("journey_poi", -1))
			if pi >= 0 and pi < pois.size():
				return cell_pos(pois[pi]["cell"])
		3:
			var bb: Variant = null
			for p in props:
				if p.kind == "bonfire" and (bb == null or p.position.distance_to(player.position) < (bb as Vector2).distance_to(player.position)):
					bb = p.position
			return bb
		4:
			for a in arenas:
				if a["def"]["id"] == "a_vil":
					return a["pos"]
	return null


func journey_text() -> String:
	var t := ""
	match journey_step():
		0:
			t = "PARLA CON L'ANZIANO DEL VILLAGGIO"
		1:
			t = "CERCA UNA PAGINA DI DIARIO NEL VILLAGGIO"
		2:
			var pi := int(persist.get("journey_poi", -1))
			t = "LIBERA: %s" % (str(pois[pi]["n"]) if pi >= 0 and pi < pois.size() else "UN LUOGO VICINO")
		3:
			t = "SALI A LIVELLO 3 AI FALO'"
		4:
			t = "RAGGIUNGI LA CAMPANA DEI CONDANNATI"
	var tg: Variant = journey_target()
	if tg != null:
		t += " (%s, %d M)" % [dir_hint(tg), int((tg as Vector2).distance_to(player.position) / 16.0)]
	return t


func journey_pick_poi() -> void:
	var best := -1
	var bd := 1e9
	var v0 := Vector2(SEEDS[0])
	for po in pois:
		if not (str(po["type"]) in ["bandits", "tower", "cave", "farm", "ruin", "hamlet", "barn"]):
			continue
		var d := Vector2(po["cell"]).distance_to(v0)
		if d > 40.0 and d < bd:
			bd = d
			best = int(po["id"])
	persist["journey_poi"] = best


func journey_advance(msg: String, souls: int, relics: int, weapon: int) -> void:
	persist["journey"] = journey_step() + 1
	player.add_souls(souls)
	popup(player.position + Vector2(0, -22), "+%d ANIME" % souls, Color(0.6, 1.0, 0.85))
	for i in relics:
		drop_relic(player.position + Vector2(randf_range(-8, 8), 14))
	if weapon > 0:
		drop_loot(player.position + Vector2(10, 14), Rpg.make_weapon(weapon))
	if journey_step() == 2 and int(persist.get("journey_poi", -1)) < 0:
		journey_pick_poi()
	say(msg)
	snd("level")
	burst(player.position, Color(1.0, 0.85, 0.4), 24, 60.0, 0.6)
	save_game()


func journey_update() -> void:
	if journey_step() >= JOURNEY_N or area != "world" or not persist["bosses"].has("boss_jailer"):
		return
	if journey_step() == 2 and int(persist.get("journey_poi", -1)) < 0:
		journey_pick_poi()
	match journey_step():
		0:
			var tg: Variant = journey_target()
			if tg != null and (tg as Vector2).distance_to(player.position) < 30.0:
				persist["journey_poi"] = -1
				journey_advance("L'ANZIANO: FUORI C'E' PIU' DI QUEL CHE VEDI. CERCA I DIARI: RACCONTANO COME FINI' TUTTO", 60, 0, 0)
		1:
			if pages_found >= 1:
				journey_advance("UNA PAGINA RITROVATA. ORA SERVE FORZA: LIBERA UN LUOGO DAI NEMICI", 80, 1, 0)
		2:
			var pi := int(persist.get("journey_poi", -1))
			if pi >= 0 and pi < pois.size():
				var po: Dictionary = pois[pi]
				if po.get("built", false):
					var left := 0
					for en in po.get("spawns", []):
						if en.get("alive", true) and spawn_present(en):
							left += 1
					if left == 0:
						journey_advance("LUOGO LIBERATO! HAI TROVATO UN'ARMA NEL BOTTINO", 120, 0, 2)
		3:
			if player.lv >= 3:
				journey_advance("PIU' FORTE. ORA ANDRAI ANCORA PIU' LONTANO", 100, 1, 0)
		4:
			var tg2: Variant = journey_target()
			if tg2 != null and (tg2 as Vector2).distance_to(player.position) < 110.0:
				journey_advance("LA CAMPANA TACE. IL CUSTODE DEL CIMITERO TI ASPETTA A EST", 150, 1, 2)


func door_lock_msg(dest: String) -> String:
	if dest.begins_with("int|archive") and not persist["opened"].has("key:sigilli"):
		return "SERRATO: SERVE LA CHIAVE DEI SIGILLI"
	if dest.begins_with("int|sanatorium") and not persist["opened"].has("lever:sanat"):
		return "CANCELLI DI FERRO CHIUSI: CERCA UNA LEVA"
	return ""


func make_room_for(name: String, c: Vector2i) -> Prop:
	var f := tex_fp(name)
	clear_rect(c + Vector2i(f.x / 2, f.y / 2), Vector2i(f.x / 2 + 3, f.y / 2 + 3))
	for dy in range(-3, f.y + 4):
		for dx in range(-3, f.x + 4):
			var cc := c + Vector2i(dx, dy)
			if inb(cc) and grid[idx(cc)] == 1:
				reach[idx(cc)] = 1
	var sp := free_spot(c, f)
	if sp.x < 0:
		return null
	return try_place(name, sp, true)


func place_landmarks() -> void:
	# Archivio dei Sigilli: nella palude, chiuso a chiave (la chiave e' nel Chiostro, a est)
	make_room_for("archive_top", SEEDS[3] + Vector2i(14, -18))
	# Sanatorio di Vetro: nelle terre della cattedrale, si apre con una leva nelle fonderie
	make_room_for("sanatorium_top", SEEDS[4] + Vector2i(-24, -26))
	var lv := free_spot(SEEDS[6] + Vector2i(24, -16), Vector2i(1, 1))
	if lv.x >= 0:
		clear_disc(lv, 2)
		add_prop("lever", lv)
	var kc := free_spot(SEEDS[4] + Vector2i(16, 10) + Vector2i(3, -4), Vector2i(1, 1))
	if kc.x >= 0:
		var kp := add_prop("key", kc)
		if kp != null:
			Game.make_light(kp, Vector2(0, -6), Color(1.0, 0.85, 0.4), 1.0, 0.9)


func qp() -> Dictionary:
	if not persist.has("quests"):
		persist["quests"] = {}
	return persist["quests"]


func quest_complete(qid: String) -> bool:
	var d: Dictionary = quest_defs[qid]
	var st: Dictionary = qp()[qid]
	return int(st["p"]) >= int(d["n"])


func quest_state(qid: String) -> String:
	if qid == "" or not quest_defs.has(qid):
		return "none"
	var q: Dictionary = qp()
	if not q.has(qid):
		return "new"
	if q[qid]["st"] == "done":
		return "done"
	return "ready" if quest_complete(qid) else "active"


func dir_hint(to: Vector2) -> String:
	var dv := to - player.position
	var a := fposmod(rad_to_deg(dv.angle()) + 22.5, 360.0)
	var names := ["EST", "SUD-EST", "SUD", "SUD-OVEST", "OVEST", "NORD-OVEST", "NORD", "NORD-EST"]
	return names[int(a / 45.0) % 8]


func quest_progress_text(qid: String) -> String:
	var d: Dictionary = quest_defs[qid]
	var st: Dictionary = qp()[qid]
	var t := str(d["txt"])
	match d["type"]:
		"hunt", "kill", "champ":
			return "%s  %d/%d" % [t, int(st["p"]), int(d["n"])]
		"fetch", "poi_fetch", "poi_find", "poi_clear":
			if area == "world":
				return "%s  (%s)" % [t, dir_hint(cell_pos(d["tcell"]))]
			return t
		"clear":
			if area == "world":
				return "%s  (%s)" % [t, dir_hint(d["tpos"])]
			return t
		"visit":
			for a in arenas:
				if a["def"]["id"] == d["target"] and area == "world":
					return "%s  (%s)" % [t, dir_hint(a["pos"])]
	return t


func quest_lines() -> Array:
	var out: Array = []
	var q: Dictionary = qp()
	for qid in q:
		if q[qid]["st"] == "active" and quest_defs.has(qid):
			var ready := quest_complete(qid)
			out.append(("FATTO - TORNA DA %s" % quest_defs[qid]["giver"]) if ready else quest_progress_text(qid))
	return out


func spawn_quest_item(qid: String, force := false) -> void:
	var d: Dictionary = quest_defs[qid]
	if quest_items.has(qid) and is_instance_valid(quest_items[qid]):
		return
	var tc: Vector2i = d["tcell"]
	if not force and not gen_chunks.get(Vector2i(tc.x / CH, tc.y / CH), false):
		return
	var sp := free_spot(tc, Vector2i(1, 1))
	if sp.x < 0:
		return
	var pr := add_prop("qitem", sp)
	if pr != null:
		pr.item = {"qid": qid}
		Game.make_light(pr, Vector2(0, -6), Color(1.0, 0.85, 0.4), 1.0, 0.8)
		quest_items[qid] = pr


func quest_event(typ: String, kind: String, champ: bool) -> void:
	var q: Dictionary = qp()
	for qid in q:
		if q[qid]["st"] != "active" or not quest_defs.has(qid):
			continue
		var d: Dictionary = quest_defs[qid]
		var hit := false
		if typ == "kill" and d["type"] == "kill" and d["kind"] == kind:
			hit = true
		elif typ == "hunt" and d["type"] == "hunt" and d["kind"] == kind:
			hit = true
		elif typ == "kill" and d["type"] == "champ" and champ:
			hit = true
		if hit and int(q[qid]["p"]) < int(d["n"]):
			q[qid]["p"] = int(q[qid]["p"]) + 1
			if quest_complete(qid):
				say("MISSIONE COMPLETATA: TORNA DA %s" % d["giver"])
				snd("level")
			else:
				popup(player.position + Vector2(0, -26), "%d/%d" % [int(q[qid]["p"]), int(d["n"])], Color(0.7, 1.0, 0.85))


## nemici ancora vivi di un luogo (solo quelli che compaiono davvero al livello attuale)
func poi_left(po: Dictionary) -> int:
	var left := 0
	for en in po.get("spawns", []):
		if en.get("alive", true) and spawn_present(en):
			left += 1
	return left


func quest_update() -> void:
	var q: Dictionary = qp()
	for qid in q:
		if q[qid]["st"] != "active" or not quest_defs.has(qid) or int(q[qid]["p"]) >= 1:
			continue
		var d: Dictionary = quest_defs[qid]
		if d["type"] == "visit" and area == "world":
			for a in arenas:
				if a["def"]["id"] == d["target"] and (a["pos"] as Vector2).distance_to(player.position) < 110.0:
					q[qid]["p"] = 1
					say("MISSIONE COMPLETATA: TORNA DA %s" % d["giver"])
					snd("level")
		elif d["type"] == "poi_find":
			if persist["opened"].has("poi:%d" % int(d["poi_id"])):
				q[qid]["p"] = 1
				say("MISSIONE COMPLETATA: TORNA DA %s" % d["giver"])
				snd("level")
		elif d["type"] == "poi_clear" and area == "world":
			var po2: Dictionary = pois[int(d["poi_id"])]
			if po2.get("built", false):
				var left := 0
				for en in po2["spawns"]:
					if en.get("alive", true) and spawn_present(en):
						left += 1
				if left == 0:
					q[qid]["p"] = 1
					say("LUOGO LIBERATO! TORNA DA %s" % d["giver"])
					snd("level")
		elif d["type"] == "clear" and area == d["dest"] and enemies.is_empty() and state == "play":
			q[qid]["p"] = 1
			say("EDIFICIO LIBERATO! TORNA DA %s" % d["giver"])
			snd("level")


func quest_accept(qid: String) -> void:
	var d: Dictionary = quest_defs.get(qid, {})
	if d.is_empty():
		return
	qp()[qid] = {"st": "active", "p": 0}
	if d["type"] == "fetch" or d["type"] == "poi_fetch":
		spawn_quest_item(qid)
	save_game()
	snd("page")
	say("MISSIONE ACCETTATA: %s" % d["txt"])


func quest_claim(qid: String) -> void:
	var d: Dictionary = quest_defs.get(qid, {})
	if d.is_empty():
		return
	qp()[qid]["st"] = "done"
	player.add_souls(int(d["rs"]))
	popup(player.position + Vector2(0, -22), "+%d ANIME" % int(d["rs"]), Color(0.6, 1.0, 0.85))
	for i in int(d["rr"]):
		drop_relic(player.position + Vector2(randf_range(-8, 8), 14))
	if int(d["rw"]) > 0:
		drop_loot(player.position + Vector2(10, 14), Rpg.make_weapon(int(d["rw"])))
	snd("level")
	burst(player.position, Color(1.0, 0.85, 0.4), 24, 60.0, 0.6)
	save_game()


## compatibilita' per i test: accetta o consegna senza dialogo
func quest_talk(v) -> String:
	var st := quest_state(v.qid)
	if st == "new":
		quest_accept(v.qid)
		return "MISSIONE: %s" % quest_defs[v.qid]["txt"]
	if st == "ready":
		quest_claim(v.qid)
		return "GRAZIE"
	return ""


var dlg := {}


func open_dialog(v) -> void:
	var rd: Dictionary = Villager.ROLES[v.role]
	var head := "%s  (%s)" % [v.nm, rd["t"]]
	var qs: String = quest_state(v.qid)
	var text := ""
	var opts: Array = ["CHIUDI"]
	if day_light() < 0.4:
		text = Villager.NIGHT_LINES[randi() % Villager.NIGHT_LINES.size()]
		qs = "night"
	else:
		match qs:
			"new":
				var d: Dictionary = quest_defs[v.qid]
				text = "MI SERVE UN AIUTO, STRANIERO.  %s.  CI PENSI TU?  (RICOMPENSA: %d ANIME%s%s)" % [d["txt"], int(d["rs"]), " + RELIQUIA" if int(d["rr"]) > 0 else "", " + ARMA RARA" if int(d["rw"]) > 0 else ""]
				opts = ["ACCETTO", "NON ORA"]
			"active":
				text = "ANCORA NIENTE? %s" % quest_progress_text(v.qid)
			"ready":
				text = "ECCOLO! SAPEVO CHE CE L'AVRESTI FATTA. PRENDI LA TUA RICOMPENSA."
				opts = ["RICEVI"]
			_:
				text = v.chat_line()
	v.spr.flip_h = player.position.x < v.position.x
	dlg = {"v": v, "head": head, "text": text, "opts": opts, "sel": 0, "qs": qs, "qid": v.qid}
	snd("page")
	state = "dialog"


func dialog_confirm() -> void:
	var qs: String = dlg["qs"]
	var sel: int = dlg["sel"]
	if qs == "new" and sel == 0:
		quest_accept(dlg["qid"])
	elif qs == "ready":
		quest_claim(dlg["qid"])
	dialog_close()


func dialog_close() -> void:
	dlg = {}
	state = "play"


func day_light() -> float:
	var x := 0.5 - 0.5 * cos(TAU * day_t)
	return smoothstep(0.12, 0.88, x)


func day_name() -> String:
	var h := day_t * 24.0
	if h >= 5.0 and h < 8.0:
		return "ALBA"
	if h >= 8.0 and h < 17.0:
		return "GIORNO"
	if h >= 17.0 and h < 20.0:
		return "TRAMONTO"
	return "NOTTE"


func day_clock() -> String:
	var h := day_t * 24.0
	return "%02d:%02d" % [int(h), int((h - floor(h)) * 60.0)]


func make_px_tex(w: int, h: int, col: Color) -> ImageTexture:
	var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
	im.fill(col)
	return ImageTexture.create_from_image(im)


func setup_weather() -> void:
	var wl := CanvasLayer.new()
	wl.layer = 1
	add_child(wl)
	rain_fx = CPUParticles2D.new()
	rain_fx.texture = make_px_tex(1, 6, Color(0.75, 0.85, 1.0, 0.65))
	rain_fx.amount = 150
	rain_fx.lifetime = 0.8
	rain_fx.preprocess = 0.8
	rain_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain_fx.emission_rect_extents = Vector2(270, 2)
	rain_fx.position = Vector2(240, -8)
	rain_fx.direction = Vector2(0.12, 1.0)
	rain_fx.spread = 2.0
	rain_fx.gravity = Vector2.ZERO
	rain_fx.initial_velocity_min = 310.0
	rain_fx.initial_velocity_max = 350.0
	rain_fx.emitting = false
	wl.add_child(rain_fx)
	snow_fx = CPUParticles2D.new()
	snow_fx.texture = make_px_tex(2, 2, Color(1, 1, 1, 0.85))
	snow_fx.amount = 110
	snow_fx.lifetime = 8.5
	snow_fx.preprocess = 8.5
	snow_fx.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	snow_fx.emission_rect_extents = Vector2(270, 2)
	snow_fx.position = Vector2(240, -8)
	snow_fx.direction = Vector2(0.15, 1.0)
	snow_fx.spread = 28.0
	snow_fx.gravity = Vector2.ZERO
	snow_fx.initial_velocity_min = 20.0
	snow_fx.initial_velocity_max = 36.0
	snow_fx.emitting = false
	wl.add_child(snow_fx)


func set_weather(w: String) -> void:
	weather = w
	if rain_fx != null:
		rain_fx.emitting = w == "rain"
		snow_fx.emitting = w == "snow"


func update_weather(real: float) -> void:
	if rain_fx == null:
		return
	if area != "world" or player == null:
		if weather != "":
			set_weather("")
		return
	weather_t -= real
	var rain_p := [0.08, 0.22, 0.2, 0.35, 0.15, 0.0, 0.06]
	if weather_t <= 0.0 or (weather == "snow" and cur_bio != 5) or (cur_bio == 5 and weather == "rain"):
		weather_t = randf_range(70.0, 150.0)
		var nw := ""
		var r := randf()
		if cur_bio == 5:
			nw = "snow" if r < 0.75 else ""
		elif cur_bio >= 0 and cur_bio < rain_p.size():
			nw = "rain" if r < rain_p[cur_bio] else ""
		if nw != weather:
			set_weather(nw)


func add_mat(id: String, n: int) -> void:
	player.mats[id] = int(player.mats.get(id, 0)) + n
	popup(player.position + Vector2(randf_range(-6, 6), -26), "+%d %s" % [n, MAT_NAMES[id]], Color(0.8, 1.0, 0.75))
	snd("page")


func gather(p) -> void:
	var id := str(p.kind).substr(4)
	var n := randi_range(2, 3) if (id == "erba" or id == "legna") else randi_range(1, 2)
	add_mat(id, n)
	persist["broken"][key(p.cell)] = true
	props.erase(p)
	block.erase(p.cell)
	burst(p.position, Color(0.7, 1.0, 0.6), 8, 30.0, 0.35)
	p.queue_free()


func res_chunk(key: Vector2i) -> void:
	var r0 := chunk_cells(key)
	var cfg := {
		0: [["erba", 1.4], ["legna", 0.8], ["fungo", 0.3]],
		1: [["erba", 1.0], ["fungo", 1.2], ["legna", 0.4]],
		2: [["erba", 2.0], ["fungo", 1.4], ["legna", 2.2]],
		3: [["fungo", 2.4], ["erba", 1.2], ["legna", 0.6]],
		4: [["minerale", 1.2], ["erba", 0.8], ["legna", 0.4]],
		5: [["minerale", 2.0], ["erba", 0.3]],
		6: [["minerale", 2.4], ["legna", 0.8]],
	}
	var bi: int = biome[idx(Vector2i((r0.position.x + r0.end.x) / 2, (r0.position.y + r0.end.y) / 2))]
	for entry in cfg[bi]:
		var cnt := int(entry[1]) + (1 if randf() < fmod(float(entry[1]), 1.0) else 0)
		for k in cnt:
			var c := Vector2i(randi_range(r0.position.x + 3, r0.end.x - 4), randi_range(r0.position.y + 3, r0.end.y - 4))
			if not inb(c) or reach[idx(c)] != 1 or road[idx(c)] == 1 or cobble[idx(c)] == 1 or block.has(c) or outside[idx(c)] == 1:
				continue
			add_prop("res_" + str(entry[0]), c)


func mat_drops(kind: String, champ: bool) -> void:
	var drops := {}
	match kind:
		"deer":
			drops = {"carne": 2, "pelle": 1}
		"rabbit":
			drops = {"carne": 1}
			if randf() < 0.4:
				drops["pelle"] = 1
		"fox":
			drops = {"pelle": 1, "carne": 1}
		"bird":
			if randf() < 0.4:
				drops = {"osso": 1}
		"skeleton", "skel_archer", "ghoul", "zombie", "wraith":
			if randf() < 0.28:
				drops = {"osso": 1}
		"goblin", "goblin_archer", "goblin_shaman", "kobold", "lizardman":
			if randf() < 0.35:
				drops = {"pelle": 1}
			if randf() < 0.2:
				drops["osso"] = 1
		"orc", "troll", "ogre":
			drops = {"carne": 1 + randi() % 2}
			if randf() < 0.5:
				drops["pelle"] = 1
			if randf() < 0.4:
				drops["osso"] = 1
		"harpy":
			if randf() < 0.4:
				drops = {"osso": 1}
		"wolf":
			if randf() < 0.55:
				drops = {"pelle": 1}
			if randf() < 0.45:
				drops["carne"] = 1
		"spider", "bat", "ooze":
			if randf() < 0.18:
				drops = {"fungo": 1}
	if champ:
		drops["osso"] = int(drops.get("osso", 0)) + 2
		drops["minerale"] = int(drops.get("minerale", 0)) + 1
	for k in drops:
		add_mat(k, int(drops[k]))


func can_craft(rc: Dictionary) -> bool:
	for k in rc["cost"]:
		if int(player.mats.get(k, 0)) < craft_cost(rc, k):
			return false
	return true


## CONSUMABILI: si creano al campo, restano in borsa e si usano a piacere (Z cambia oggetto, X usa)
const ITEM_ORDER := ["infuso", "arrosto", "forza", "pelle", "fuoco"]


## oggetti usabili con Z/X: quelli nella cintura
func item_ids() -> Array:
	var out: Array = []
	for id in player.belt:
		if int(player.items.get(id, 0)) > 0:
			out.append(id)
	return out


## un oggetto nuovo va nella cintura se c'e' posto
func belt_auto(id: String) -> void:
	if not player.belt.has(id) and player.belt.size() < player.BELT_MAX:
		player.belt.append(id)


func relic_gain(rid: String, n: int) -> void:
	player.relics[rid] = player.relic_own(rid) + n
	if not player.relic_eq.has(rid) and player.relic_eq.size() < player.RELIC_MAX:
		player.relic_eq.append(rid)


func item_name(id: String) -> String:
	if player.brews.has(id):
		return str(player.brews[id]["n"])
	for rc in RECIPES:
		if rc["id"] == id:
			return str(rc["n"])
	return id


func item_current() -> String:
	var ids := item_ids()
	if ids.is_empty():
		return ""
	return str(ids[clampi(player.item_sel, 0, ids.size() - 1)])


func item_cycle() -> void:
	var ids := item_ids()
	if ids.is_empty():
		say("NON HAI OGGETTI: CREALI AL CAMPO (C)")
		return
	player.item_sel = (clampi(player.item_sel, 0, ids.size() - 1) + 1) % ids.size()
	snd("page")
	say(item_name(str(ids[player.item_sel])))


func item_use() -> void:
	var id := item_current()
	if id == "":
		say("NON HAI OGGETTI: CREALI AL CAMPO (C)")
		return
	if player.brews.has(id) and not use_brew(player.brews[id]["fx"]):
		return
	match id:
		"infuso":
			if player.flasks >= player.max_flasks:
				say("LE FIALE SONO GIA' PIENE")
				return
			player.flasks += 1
		"arrosto":
			if player.hp >= player.max_hp - 1.0:
				say("SEI GIA' IN SALUTE")
				return
			player.hp = minf(player.max_hp, player.hp + player.max_hp * 0.45)
		"forza", "pelle", "fuoco":
			if player.buffs.has(id) and float(player.buffs[id]) > 60.0:
				say("EFFETTO GIA' ATTIVO")
				return
			player.buffs[id] = 240.0
	player.items[id] = int(player.items[id]) - 1
	if int(player.items[id]) <= 0:
		player.items.erase(id)
		player.belt.erase(id)
	player.item_sel = clampi(player.item_sel, 0, maxi(0, item_ids().size() - 1))
	snd("drink")
	burst(player.position, Color(1.0, 0.85, 0.5), 12, 35.0, 0.5)
	popup(player.position + Vector2(0, -22), item_name(id), Color(0.8, 1.0, 0.8))


## effetto di una pozione creata alla forgia; false se non servirebbe a nulla
func use_brew(fx: Dictionary) -> bool:
	var base := str(fx["base"])
	var v := float(fx["v"])
	var bf: Dictionary = fx.get("buffs", {})
	match base:
		"chrono":
			Chrono._use(self, str(fx["cid"]))
		"heal":
			if player.hp >= player.max_hp - 1.0 and bf.is_empty():
				say("SEI GIA' IN SALUTE")
				return false
			player.hp = minf(player.max_hp, player.hp + player.max_hp * v)
		"mana":
			if player.mana >= player.max_mana - 1.0 and bf.is_empty():
				say("IL MANA E' GIA' PIENO")
				return false
			player.mana = minf(player.max_mana, player.mana + player.max_mana * v)
		"flask":
			if player.flasks >= player.max_flasks and bf.is_empty():
				say("LE FIALE SONO GIA' PIENE")
				return false
			player.flasks = mini(player.max_flasks, player.flasks + int(v))
	for k in bf:
		var cur := float(player.bval.get(k, 0.0)) if player.buffs.has(k) else 0.0
		player.buffs[k] = maxf(float(player.buffs.get(k, 0.0)), float(fx["dur"]))
		player.bval[k] = maxf(cur, float(bf[k]))
	return true


# ------------------------------------------------------------------ forgia (artigianato componibile)
var craft_tab := 0
var craft_row := 0
var craft_vals: Array = [[0, 0, 0, 0, 1], [0, 0], [1, 0, 0, 1], [0, 0, 0, 1], [0]]


func craft_ids() -> Array:
	var sl := Forge.slots(craft_tab)
	var out: Array = []
	for i in sl.size():
		var opts: Array = sl[i][1]
		var vi: int = clampi(int(craft_vals[craft_tab][i]), 0, opts.size() - 1)
		out.append(opts[vi][0])
	return out


func craft_preview() -> Dictionary:
	return Forge.make(craft_tab, craft_ids(), player)


func craft_afford(cost: Dictionary) -> bool:
	for k in cost:
		if int(player.mats.get(k, 0)) < int(cost[k]):
			return false
	return true


## cambia scheda o scelta nella forgia (riga 0 = schede, ultima = CREA)
func craft_step(dx: int) -> void:
	if craft_row == 0:
		craft_tab = (craft_tab + dx + Forge.TABS.size()) % Forge.TABS.size()
		snd("page")
		return
	var sl := Forge.slots(craft_tab)
	var i := craft_row - 1
	if i >= sl.size():
		return
	var n: int = (sl[i][1] as Array).size()
	craft_vals[craft_tab][i] = (int(craft_vals[craft_tab][i]) + dx + n) % n
	snd("page")


func craft_make() -> void:
	var res := Forge.make(craft_tab, craft_ids(), player, true)
	if str(res.get("err", "")) != "":
		say(str(res["err"]))
		return
	var cost: Dictionary = res["cost"]
	if not craft_afford(cost):
		say("MATERIALI INSUFFICIENTI")
		snd("hurt")
		return
	var it: Dictionary = res["item"]
	match craft_tab:
		0:
			if player.wslots[1] == null:
				player.wslots[1] = it
				player.wcur = 1
				say("FORGIATA E IMPUGNATA: %s" % str(it["nm"]).to_upper())
			elif player.bag_free() > 0:
				player.bag.append({"k": "w", "w": it})
				say("FORGIATA, IN BORSA: %s   (I PER EQUIPAGGIARE)" % str(it["nm"]).to_upper())
			else:
				say("BORSA PIENA: LIBERA SPAZIO CON I")
				return
		1:
			var rc: Dictionary = (it.get("rc", {}) as Dictionary).duplicate()
			for k in cost:
				rc[k] = int(rc.get(k, 0)) + int(cost[k])
			it["rc"] = rc
			player.wslots[player.wcur] = it
			say("MODIFICATA: %s" % Rpg.wname(it).to_upper())
		2:
			var sl := str(it["slot"])
			if not player.armor.has(sl):
				player.armor[sl] = it
				say("INDOSSI: %s" % str(it["n"]))
			elif player.bag_free() > 0:
				player.bag.append({"k": "a", "a": it})
				say("IN BORSA: %s   (I PER INDOSSARE)" % str(it["n"]))
			else:
				say("BORSA PIENA: LIBERA SPAZIO CON I")
				return
		4:
			var jid := str(it["junk"])
			var given := false
			match str(it["t"]):
				"w":
					given = _give_weapon(it)
				"a":
					given = _give_armor(it)
				_:
					given = _give_brew(it)
			if not given:
				return
			Chrono.owned[jid] = int(Chrono.owned.get(jid, 0)) - 1
			if int(Chrono.owned[jid]) <= 0:
				Chrono.owned.erase(jid)
		_:
			if not _give_brew(it):
				return
	for k in cost:
		player.mats[k] = int(player.mats[k]) - int(cost[k])
		if int(player.mats[k]) <= 0:
			player.mats.erase(k)
	player.apply_stats()
	snd("buy")
	burst(player.position, Color(1.0, 0.85, 0.5), 14, 40.0, 0.5)
	save_game()


## consegna al giocatore gli oggetti ottenuti dagli anacronismi (false se la borsa e' piena)
func _give_weapon(w: Dictionary, how := "TRASFORMATO") -> bool:
	w.erase("t")
	w.erase("junk")
	if player.wslots[1] == null:
		player.wslots[1] = w
		player.wcur = 1
		say("%s E IMPUGNATO: %s" % [how, str(w["nm"]).to_upper()])
	elif player.bag_free() > 0:
		player.bag.append({"k": "w", "w": w})
		say("%s, IN BORSA: %s   (I PER EQUIPAGGIARE)" % [how, str(w["nm"]).to_upper()])
	else:
		say("BORSA PIENA: LIBERA SPAZIO CON I")
		return false
	return true


func _give_armor(a: Dictionary) -> bool:
	a.erase("t")
	a.erase("junk")
	var sl := str(a["slot"])
	if not player.armor.has(sl):
		player.armor[sl] = a
		say("INDOSSI: %s" % str(a["n"]))
	elif player.bag_free() > 0:
		player.bag.append({"k": "a", "a": a})
		say("IN BORSA: %s   (I PER INDOSSARE)" % str(a["n"]))
	else:
		say("BORSA PIENA: LIBERA SPAZIO CON I")
		return false
	return true


func _give_brew(it: Dictionary) -> bool:
	var id := str(it["id"])
	if int(player.items.get(id, 0)) >= 9:
		say("SCORTA PIENA (MAX 9)")
		return false
	if int(player.items.get(id, 0)) == 0 and player.bag_free() <= 0:
		say("BORSA PIENA: LIBERA SPAZIO CON I")
		return false
	player.brews[id] = {"n": it["n"], "fx": it["fx"]}
	player.items[id] = int(player.items.get(id, 0)) + 1
	belt_auto(id)
	say("%s IN BORSA%s" % [str(it["n"]), ": Z CAMBIA, X USA" if player.belt.has(id) else " (CINTURA PIENA: AGGIUNGILA CON I)"])
	return true


## oggetto utile evocato: va in borsa come consumabile (stesso sistema delle pozioni); false se non c'e' posto
func stock_chrono(cid: String, nm: String) -> bool:
	var id := "b:chrono:%s" % cid
	if int(player.items.get(id, 0)) >= 9:
		return false
	if int(player.items.get(id, 0)) == 0 and player.bag_free() <= 0:
		return false
	player.brews[id] = {"n": nm, "fx": {"base": "chrono", "cid": cid, "v": 0.0, "dur": 0.0, "buffs": {}}}
	player.items[id] = int(player.items.get(id, 0)) + 1
	belt_auto(id)
	say("%s IN BORSA%s" % [nm, ": Z CAMBIA, X USA" if player.belt.has(id) else " (CINTURA PIENA: AGGIUNGILA CON I)"])
	return true


## bolla spazio-temporale: un tasto, un oggetto a caso dal passato o dal futuro
func summon() -> void:
	if state != "play" or player == null:
		return
	if player.chrono < Chrono.COST:
		say("CRONOTONE: %d%%" % int(player.chrono))
		snd("hurt")
		return
	player.chrono -= Chrono.COST
	var r := Chrono.roll(player.lv, player.pity)
	player.pity = player.pity + 1 if str(r["cls"]) == "junk" else 0
	ChronoBubble.spawn(self, r, str(r["cls"]) != "junk" and str(r["cls"]) != "use")   # la bolla si apre vicino a te; l'effetto parte quando l'oggetto ti raggiunge


## ricarica del Cronotone uccidendo
func chrono_gain(n: float) -> void:
	player.chrono = minf(Chrono.MAX_E, player.chrono + n)


# ------------------------------------------------------------------ borsa ed equipaggiamento (il mondo non si ferma)
const INV_TABS := ["TUTTO", "ARMI", "ARMAT.", "POZIONI", "MATER.", "RELIQ."]
const ITEM_COL := {"infuso": "erba", "arrosto": "carne", "forza": "fungo", "pelle": "osso", "fuoco": "carne"}
var inv_open := false
var inv_tab := 0
var inv_cell := 0
var inv_side := 1          # 0 = personaggio (slot), 1 = borsa
var inv_slot := 0          # 0-1 armi, 2-4 armatura, 5-8 cintura, 9-11 reliquie
var inv_scroll := 0
var inv_confirm := ""
var inv_confirm_t := 0.0
var inv_back_t := -1.0
var inv_back_used := false


## voci mostrate nella borsa per la scheda scelta
func inv_list(tab: int) -> Array:
	var out: Array = []
	if tab in [0, 1]:
		for i in player.bag.size():
			if str(player.bag[i]["k"]) == "w":
				out.append({"k": "w", "w": player.bag[i]["w"], "bi": i})
	if tab in [0, 2]:
		for i in player.bag.size():
			if str(player.bag[i]["k"]) == "a":
				out.append({"k": "a", "a": player.bag[i]["a"], "bi": i})
	if tab in [0, 3]:
		var ids: Array = []
		for id in ITEM_ORDER:
			if int(player.items.get(id, 0)) > 0:
				ids.append(id)
		for id in player.items:
			if not ids.has(id) and int(player.items[id]) > 0:
				ids.append(id)
		for id in ids:
			out.append({"k": "b", "id": id, "n": int(player.items[id]), "eq": player.belt.has(id)})
	if tab in [0, 5]:
		for rr in Relics.LIST:
			var rid := str(rr["id"])
			if player.relic_own(rid) > 0:
				out.append({"k": "r", "id": rid, "n": player.relic_own(rid), "eq": player.relic_eq.has(rid)})
	if tab in [0, 4]:
		for mid in MAT_ORDER:
			if int(player.mats.get(mid, 0)) > 0:
				out.append({"k": "m", "id": mid, "n": int(player.mats[mid])})
	return out


## colore della fiala di una pozione (base della ricetta)
func brew_base(id: String) -> String:
	if id.begins_with("b:"):
		return id.split(":")[1]
	return str(ITEM_COL.get(id, "erba"))


## cosa c'e' nello slot n del personaggio (null se vuoto)
func inv_slot_entry(n: int):
	if n <= 1:
		return null if player.wslots[n] == null else {"k": "w", "w": player.wslots[n]}
	if n <= 4:
		var sl: String = Forge.PIECES[n - 2]
		return {"k": "a", "a": player.armor[sl]} if player.armor.has(sl) else null
	if n <= 8:
		var bi := n - 5
		if bi < player.belt.size():
			var id: String = player.belt[bi]
			return {"k": "b", "id": id, "n": int(player.items.get(id, 0)), "eq": true}
		return null
	var ri := n - 9
	if ri < player.relic_eq.size():
		var rid: String = player.relic_eq[ri]
		return {"k": "r", "id": rid, "n": player.relic_own(rid), "eq": true}
	return null


func inv_selected():
	if inv_side == 0:
		return inv_slot_entry(inv_slot)
	var lst := inv_list(inv_tab)
	return lst[inv_cell] if inv_cell < lst.size() else null


func inv_toggle() -> void:
	inv_open = not inv_open
	inv_confirm = ""
	if inv_open:
		inv_side = 1
		inv_cell = clampi(inv_cell, 0, maxi(0, inv_list(inv_tab).size() - 1))
	snd("page")


## confronto con il pezzo indossato: [nome, segno, testo]
func inv_compare(e: Dictionary) -> Array:
	var out: Array = []
	if str(e["k"]) == "w":
		var cur: Dictionary = player.weapon()
		var a := _wvals(e["w"])
		var b := _wvals(cur)
		for k in [["DANNO", "b", 100.0, "%"], ["VELOCITA'", "sp", 100.0, "%"], ["CRITICO", "cr", 100.0, "%"], ["PORTATA", "rc", 1.0, ""], ["STAMINA", "st", -100.0, "%"]]:
			var d := (float(a[k[1]]) - float(b[k[1]])) * float(k[2])
			if absf(d) >= 0.5:
				out.append([k[0], d, "%+d%s" % [int(round(d * (1.0 if float(k[2]) > 0.0 else -1.0))), k[3]]])
	elif str(e["k"]) == "a":
		var sl := str(e["a"]["slot"])
		var cur_st: Dictionary = player.armor[sl]["st"] if player.armor.has(sl) else {}
		var new_st: Dictionary = e["a"]["st"]
		for k in Forge.ASTAT_N:
			var d := float(new_st.get(k, 0.0)) - float(cur_st.get(k, 0.0))
			var pct: bool = k in Forge.PCT
			if absf(d) < (0.004 if pct else 0.05):
				continue
			var good := d if k != "mv" or true else d
			out.append([Forge.ASTAT_N[k], good, ("%+.1f%%" % (d * 100.0)) if pct else ("%+.2f/s" % d if k == "rg" else "%+d" % int(round(d)))])
		if cur_st.is_empty():
			out.push_front(["SLOT VUOTO", 1.0, ""])
	return out


func _wvals(w: Dictionary) -> Dictionary:
	var m: Dictionary = w.get("mods", {})
	return {"b": float(w["b"]), "sp": float(m.get("sp", 0.0)), "cr": float(m.get("cr", 0.0)) + 0.08 * (w["a"] as Array).count("acuta"),
		"rc": float(m.get("rc", 0.0)), "st": float(m.get("st", 0.0))}


## materiali restituiti smontando: meta' del costo di creazione (o in base alla rarita' per gli oggetti trovati)
func salvage_of(e: Dictionary) -> Dictionary:
	var src: Dictionary = {}
	if str(e["k"]) == "w":
		src = e["w"].get("rc", {})
		if src.is_empty():
			var r := int(e["w"]["r"])
			return {"minerale": 1 + r, "legna": 1, "osso": r} if r > 0 else {"minerale": 1, "legna": 1}
	elif str(e["k"]) == "a":
		src = e["a"].get("rc", {"pelle": 2})
	var out := {}
	for k in src:
		var n := int(src[k]) / 2
		if n > 0:
			out[k] = n
	return out


func inv_action(kind: String) -> void:
	var e = inv_selected()
	if e == null:
		return
	var k := str(e["k"])
	match kind:
		"equip":
			if inv_side == 0:
				_inv_unequip(e)
			else:
				_inv_equip(e)
		"smonta":
			if inv_side == 0 or not (k in ["w", "a"]):
				say("SI SMONTANO SOLO ARMI E ARMATURE IN BORSA")
				return
			var sv := salvage_of(e)
			player.bag.remove_at(int(e["bi"]))
			var parts: Array = []
			for mk in sv:
				player.mats[mk] = int(player.mats.get(mk, 0)) + int(sv[mk])
				parts.append("%d %s" % [int(sv[mk]), MAT_NAMES[mk]])
			say("SMONTATO: " + (", ".join(parts) if not parts.is_empty() else "NULLA DI UTILE"))
			snd("buy")
		"getta":
			var tag := "%s:%s:%d" % [k, str(e.get("id", "")), int(e.get("bi", -1))]
			if inv_confirm != tag or inv_confirm_t <= 0.0:
				inv_confirm = tag
				inv_confirm_t = 2.5
				say("PREMI DI NUOVO PER GETTARE")
				return
			inv_confirm = ""
			if inv_side == 0:
				say("TOGLILO PRIMA DI GETTARLO")
				return
			match k:
				"w":
					player.bag.remove_at(int(e["bi"]))
					drop_loot(player.position + Vector2(0, 12), e["w"])
				"a":
					player.bag.remove_at(int(e["bi"]))
					drop_loot(player.position + Vector2(0, 12), {"k": "a", "a": e["a"]})
				"r":
					var rid := str(e["id"])
					player.relics[rid] = player.relic_own(rid) - 1
					if player.relic_own(rid) <= 0:
						player.relics.erase(rid)
						player.relic_eq.erase(rid)
					drop_loot(player.position + Vector2(0, 12), {"k": "relic", "id": rid})
				"b":
					var id := str(e["id"])
					player.items[id] = int(player.items[id]) - 1
					if int(player.items[id]) <= 0:
						player.items.erase(id)
						player.belt.erase(id)
				"m":
					player.mats.erase(str(e["id"]))
			say("GETTATO")
			snd("page")
	player.apply_stats()
	player.hp = minf(player.hp, player.max_hp)
	inv_cell = clampi(inv_cell, 0, maxi(0, inv_list(inv_tab).size() - 1))


func _inv_equip(e: Dictionary) -> void:
	match str(e["k"]):
		"w":
			var bi := int(e["bi"])
			if player.wslots[1] == null:
				player.wslots[1] = e["w"]
				player.bag.remove_at(bi)
				player.wcur = 1
			else:
				var old: Dictionary = player.wslots[player.wcur]
				player.wslots[player.wcur] = e["w"]
				player.bag[bi] = {"k": "w", "w": old}
			say("IMPUGNI: %s" % Rpg.wname(player.weapon()).to_upper())
		"a":
			var bi := int(e["bi"])
			var sl := str(e["a"]["slot"])
			if player.armor.has(sl):
				player.bag[bi] = {"k": "a", "a": player.armor[sl]}
			else:
				player.bag.remove_at(bi)
			player.armor[sl] = e["a"]
			say("INDOSSI: %s" % str(e["a"]["n"]))
		"b":
			var id := str(e["id"])
			if player.belt.has(id):
				player.belt.erase(id)
				say("TOLTA DALLA CINTURA")
			elif player.belt.size() >= player.BELT_MAX:
				say("CINTURA PIENA (4): TOGLINE UNA")
				return
			else:
				player.belt.append(id)
				say("NELLA CINTURA: Z CAMBIA, X USA")
		"r":
			var rid := str(e["id"])
			if player.relic_eq.has(rid):
				player.relic_eq.erase(rid)
				say("RELIQUIA TOLTA: %s" % Relics.info(rid)["n"])
			elif player.relic_eq.size() >= player.RELIC_MAX:
				say("PUOI INDOSSARE SOLO 3 RELIQUIE: TOGLINE UNA")
				return
			else:
				player.relic_eq.append(rid)
				say("RELIQUIA INDOSSATA: %s" % Relics.info(rid)["n"])
		"m":
			say("MATERIALE PER LA FORGIA (AL FALO', C)")
			return
	snd("page")


func _inv_unequip(e: Dictionary) -> void:
	var n := inv_slot
	if n <= 1:
		if player.wslots[1 - n] == null:
			say("TI SERVE ALMENO UN'ARMA")
			return
		if player.bag_free() <= 0:
			say("BORSA PIENA")
			return
		player.bag.append({"k": "w", "w": player.wslots[n]})
		player.wslots[n] = null
		if n == 0:
			player.wslots[0] = player.wslots[1]
			player.wslots[1] = null
		player.wcur = 0
		say("ARMA RIPOSTA IN BORSA")
	elif n <= 4:
		if player.bag_free() <= 0:
			say("BORSA PIENA")
			return
		var sl: String = Forge.PIECES[n - 2]
		player.bag.append({"k": "a", "a": player.armor[sl]})
		player.armor.erase(sl)
		say("ARMATURA RIPOSTA IN BORSA")
	elif n <= 8:
		player.belt.erase(str(e["id"]))
		say("TOLTA DALLA CINTURA")
	else:
		player.relic_eq.erase(str(e["id"]))
		say("RELIQUIA TOLTA")
	snd("page")


func inv_move(dx: int, dy: int) -> void:
	if inv_side == 0:
		if dx > 0:
			inv_side = 1
			return
		if dy != 0:
			inv_slot = (inv_slot + dy + 12) % 12
		elif dx < 0:
			inv_slot = (inv_slot + 11) % 12
		return
	var n := inv_list(inv_tab).size()
	var col := inv_cell % 12
	if dx < 0 and col == 0:
		inv_side = 0
		return
	var nc := inv_cell + dx + dy * 12
	if n > 0:
		inv_cell = clampi(nc, 0, n - 1) if (dy == 0 or (nc >= 0 and nc < n)) else inv_cell
	var row := inv_cell / 12
	if row < inv_scroll:
		inv_scroll = row
	elif row > inv_scroll + 2:
		inv_scroll = row - 2


func inv_input(ev: InputEvent) -> bool:
	var key: bool = ev is InputEventKey and ev.pressed
	var pad: bool = ev is InputEventJoypadButton and ev.pressed
	if (key and not ev.echo and (ev.keycode == KEY_I or ev.keycode == KEY_ESCAPE)) or (pad and ev.button_index == JOY_BUTTON_B):
		inv_toggle()
		return true
	if ev.is_action_pressed("ui_left", true) or (key and ev.keycode in [KEY_A]) or (pad and ev.button_index == JOY_BUTTON_DPAD_LEFT):
		inv_move(-1, 0)
	elif ev.is_action_pressed("ui_right", true) or (key and ev.keycode in [KEY_D]) or (pad and ev.button_index == JOY_BUTTON_DPAD_RIGHT):
		inv_move(1, 0)
	elif ev.is_action_pressed("ui_up", true) or (key and ev.keycode in [KEY_W]) or (pad and ev.button_index == JOY_BUTTON_DPAD_UP):
		inv_move(0, -1)
	elif ev.is_action_pressed("ui_down", true) or (key and ev.keycode in [KEY_S]) or (pad and ev.button_index == JOY_BUTTON_DPAD_DOWN):
		inv_move(0, 1)
	elif (key and not ev.echo and ev.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]) or (pad and ev.button_index == JOY_BUTTON_A):
		inv_action("equip")
	elif (key and not ev.echo and ev.keycode == KEY_X) or (pad and ev.button_index == JOY_BUTTON_X):
		inv_action("smonta")
	elif (key and not ev.echo and ev.keycode == KEY_G) or (pad and ev.button_index == JOY_BUTTON_Y):
		inv_action("getta")
	elif key and not ev.echo and ev.keycode == KEY_TAB:
		inv_side = 1 - inv_side
	elif (key and not ev.echo and ev.keycode == KEY_Q) or (pad and ev.button_index == JOY_BUTTON_LEFT_SHOULDER):
		inv_tab = (inv_tab + INV_TABS.size() - 1) % INV_TABS.size()
		inv_cell = 0
		inv_scroll = 0
		inv_side = 1
	elif (key and not ev.echo and ev.keycode == KEY_E) or (pad and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER):
		inv_tab = (inv_tab + 1) % INV_TABS.size()
		inv_cell = 0
		inv_scroll = 0
		inv_side = 1
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var hit: Array = hud.inv_hit(ev.position - hud.position)
		if hit.is_empty():
			return true
		match str(hit[0]):
			"tab":
				inv_tab = int(hit[1])
				inv_cell = 0
				inv_scroll = 0
				inv_side = 1
			"slot":
				if inv_side == 0 and inv_slot == int(hit[1]):
					inv_action("equip")
				inv_side = 0
				inv_slot = int(hit[1])
			"cell":
				var ci := int(hit[1]) + inv_scroll * 12
				if ci < inv_list(inv_tab).size():
					if inv_side == 1 and inv_cell == ci:
						inv_action("equip")
					inv_side = 1
					inv_cell = ci
	else:
		return (ev is InputEventKey) or (ev is InputEventJoypadButton)   # gli altri tasti non arrivano al personaggio
	return true


## Back del pad: tocco = cambia oggetto, tenuto = apre/chiude la borsa
func inv_pad_update(real: float) -> void:
	if inv_confirm_t > 0.0:
		inv_confirm_t -= real
	if inv_back_t < 0.0:
		return
	inv_back_t += real
	if inv_back_t >= 0.45 and not inv_back_used:
		inv_back_used = true
		inv_toggle()


func craft_cost(rc: Dictionary, mat: String) -> int:
	var n: int = int(rc["cost"][mat])
	if rc["id"] == "affila" and mat == "minerale":
		n += int(player.weapon().get("u", 0))
	return n


func craft_do(i: int) -> void:
	var rc: Dictionary = RECIPES[i]
	if not can_craft(rc):
		say("MATERIALI INSUFFICIENTI")
		return
	match str(rc["id"]):
		"infuso", "arrosto", "forza", "pelle", "fuoco":
			if int(player.items.get(str(rc["id"]), 0)) >= 9:
				say("SCORTA PIENA (MAX 9)")
				return
			player.items[str(rc["id"])] = int(player.items.get(str(rc["id"]), 0)) + 1
			if item_ids().size() == 1:
				player.item_sel = 0
		"affila":
			var w: Dictionary = player.weapon()
			if int(w.get("u", 0)) >= 5:
				say("L'ARMA E' GIA' AL MASSIMO")
				return
			w["b"] = float(w["b"]) + 0.06
			w["u"] = int(w.get("u", 0)) + 1
		"reliquia":
			var rid := Relics.roll()
			relic_gain(rid, 1)
			player.apply_stats()
			say("RELIQUIA: %s" % Relics.info(rid)["n"])
	for k in rc["cost"]:
		player.mats[k] = int(player.mats[k]) - craft_cost(rc, k)
		if int(player.mats[k]) <= 0:
			player.mats.erase(k)
	snd("buy")
	burst(player.position, Color(1.0, 0.85, 0.5), 14, 40.0, 0.5)
	if str(rc["id"]) in ITEM_ORDER:
		say("%s IN BORSA: Z CAMBIA OGGETTO, X USA" % rc["n"])
	elif str(rc["id"]) != "reliquia":
		say("REALIZZATO: %s" % rc["n"])
	save_game()


var craft_sel := 0


func critter_died(c) -> void:
	critters.erase(c)
	mat_drops(str(c.kind), false)
	quest_event("hunt", c.kind, false)
	snd("hit")
	burst(c.position, Color(0.75, 0.15, 0.3), 10, 50.0, 0.4)
	drop(c.position, "soul", int(c.d["souls"]))
	c.queue_free()


func place_fauna() -> void:
	# animali e abitanti dipendono dalla regione: la vita del mondo
	var cfg := {
		0: [["rat", 8, Color.WHITE], ["bird", 6, Color.WHITE], ["rabbit", 4, Color.WHITE]],
		1: [["bird", 10, Color.WHITE], ["rat", 6, Color.WHITE]],
		2: [["deer", 14, Color.WHITE], ["rabbit", 12, Color.WHITE], ["bird", 8, Color.WHITE], ["fox", 3, Color(1, 0.7, 0.4)]],
		3: [["frog", 18, Color(0.9, 1.0, 0.8)], ["bird", 4, Color.WHITE]],
		4: [["bird", 8, Color.WHITE], ["rat", 4, Color.WHITE]],
		5: [["fox", 8, Color(1.6, 1.7, 1.9)], ["rabbit", 5, Color(1.5, 1.6, 1.8)]],
		6: [["rat", 12, Color.WHITE], ["bird", 6, Color.WHITE]],
	}
	for si in cfg:
		for entry in cfg[si]:
			var placed := 0
			var tries := 0
			while placed < int(entry[1]) and tries < 300:
				tries += 1
				var c: Vector2i = SEEDS[si] + Vector2i(randi_range(-34, 34), randi_range(-28, 28))
				if not inb(c) or biome[idx(c)] != si or not is_floor(c) or block.has(c) or outside[idx(c)] == 1 or water[idx(c)] == 1 or reach[idx(c)] != 1:
					continue
				var cr := Critter.new()
				cr.setup(self, str(entry[0]), cell_pos(c) + Vector2(randf_range(-6, 6), randf_range(-6, 6)), entry[2])
				ents.add_child(cr)
				critters.append(cr)
				placed += 1


func place_villagers() -> void:
	var qgiven := {}
	var sets := [[0, 9, 22], [2, 3, 9], [3, 4, 10], [5, 3, 8]]
	var rosters := {
		0: ["contadino", "contadina", "anziano", "fabbro", "guardia", "guardia", "bambino", "monaco", "cacciatore"],
		2: ["cacciatore", "cacciatore", "contadina"],
		3: ["contadino", "anziano", "contadina", "contadino"],
		5: ["cacciatore", "anziano", "contadina"],
	}
	for se in sets:
		var si: int = se[0]
		var center: Vector2i = SEEDS[si]
		var door := cell_pos(center)
		var best := 1e9
		for dd in doors:
			var dp: Vector2 = dd["pos"]
			var dist := dp.distance_to(cell_pos(center))
			if dist < best and dist < 28.0 * Game.TS:
				best = dist
				door = dp + Vector2(0, 12)
		var pts: Array = []
		for k in 200:
			if pts.size() >= 8:
				break
			var c := center + Vector2i(randi_range(-int(se[2]), int(se[2])), randi_range(-int(se[2]), int(se[2])))
			if not inb(c) or not is_floor(c) or block.has(c) or reserved.has(c):
				continue
			if si == 0 and cobble[idx(c)] != 1:
				continue
			pts.append(cell_pos(c))
		if pts.is_empty():
			continue
		for i in int(se[1]):
			var v := Villager.new()
			var sp: Vector2 = pts[randi() % pts.size()]
			var vdoor := door
			var best2 := 1e9
			for dd in doors:
				var dp2: Vector2 = dd["pos"]
				var d2 := dp2.distance_to(sp)
				if d2 < best2 and d2 < 30.0 * Game.TS and randf() < 0.5:
					best2 = d2
					vdoor = dp2 + Vector2(0, 12)
			var ros: Array = rosters[si]
			var role_id: String = str(ros[i % ros.size()])
			v.setup(self, role_id, sp, vdoor, pts, si)
			if QT.has(role_id) and not qgiven.has("%d_%s" % [si, role_id]):
				qgiven["%d_%s" % [si, role_id]] = true
				var qid := "%d_%s_%d" % [si, role_id, i]
				var qd: Dictionary = (QT[role_id] as Dictionary).duplicate()
				qd["giver"] = v.nm
				qd["center"] = center
				if qd["type"] == "fetch":
					for k in 300:
						var tc := center + Vector2i(randi_range(-60, 60), randi_range(-50, 50))
						if inb(tc) and is_floor(tc) and not block.has(tc) and reach[idx(tc)] == 1 and road[idx(tc)] == 0 and not in_settlement(tc) and outside[idx(tc)] == 0:
							qd["tcell"] = tc
							break
					if not qd.has("tcell"):
						qd = {}
				elif qd["type"] == "clear":
					var cands: Array = []
					for dd in doors:
						var pr: PackedStringArray = str(dd["dest"]).split("|")
						var dc := Vector2i(int(pr[2]), int(pr[3]))
						if not (pr[1] == "house" and in_settlement(dc)) and Vector2(dc).distance_to(Vector2(center)) < 95.0:
							cands.append(dd)
					if cands.is_empty():
						qd = {}
					else:
						var pick: Dictionary = cands[randi() % cands.size()]
						qd["dest"] = pick["dest"]
						qd["tpos"] = pick["pos"]
				elif qd["type"] == "visit":
					qd["target"] = "a_cim"
				elif str(qd["type"]).begins_with("poi_"):
					var allowed: Array = qd["poi"]
					var cands2: Array = pois.filter(func(x): return allowed.has(x["type"]))
					cands2.sort_custom(func(a, b): return Vector2(a["cell"]).distance_squared_to(Vector2(center)) < Vector2(b["cell"]).distance_squared_to(Vector2(center)))
					if cands2.is_empty():
						qd = {}
					else:
						var chosen: Dictionary = cands2[randi() % mini(3, cands2.size())]
						qd["poi_id"] = int(chosen["id"])
						qd["txt"] = str(qd["txt"]) % str(chosen["n"])
						qd["tcell"] = (chosen["cell"] as Vector2i) + Vector2i(3, 3)
						qd["tpos"] = cell_pos(chosen["cell"])
				if not qd.is_empty():
					quest_defs[qid] = qd
					v.qid = qid
			ents.add_child(v)
			villagers.append(v)


func place_arenas() -> void:
	arenas.clear()
	for ad in ARENAS:
		var c: Vector2i = SEEDS[int(ad["si"])] + ad["off"]
		if not inb(c) or water[idx(c)] == 1:
			continue
		var rr: int = int(ad["r"]) + 3
		clear_disc(c, rr)
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				var cc := c + Vector2i(dx, dy)
				if inb(cc) and grid[idx(cc)] == 1:
					reach[idx(cc)] = 1
					cobble[idx(cc)] = 1 if dx * dx + dy * dy <= int(ad["r"] * ad["r"]) - 6 and ad["id"] != "a_bosco" else cobble[idx(cc)]
		var done: bool = persist["opened"].has("arena:" + str(ad["id"]))
		var cp := cell_pos(c)
		var ring: Array = ad["ring"]
		for i in int(ad["rn"]):
			var ang := TAU * i / float(ad["rn"]) + 0.3
			var rc := c + Vector2i(roundi(cos(ang) * ad["r"]), roundi(sin(ang) * ad["r"]))
			var nm: String = ring[i % ring.size()]
			if nm == "brazier":
				add_prop("brazier", rc)
			elif nm.begins_with("top_dead"):
				place_tree(nm, rc)
			else:
				try_place(nm, rc, nm == "crystal_top_ice")
		if ad["mode"] == "bell":
			var bp := add_prop("bell", c)
			if bp != null:
				cp = bp.position
				if done:
					bp.spr.modulate = Color(0.55, 0.55, 0.6)
		else:
			var core := add_prop("arena_core", c)
			if core != null:
				core.spr.offset = Vector2(0, -2)
				if done:
					core.spr.modulate = Color(0.5, 0.5, 0.55)
				else:
					Game.make_light(core, Vector2(0, -4), Color(1.0, 0.35, 0.25), 1.6, 0.7)
		arenas.append({"def": ad, "center": c, "pos": cp, "done": done, "active": false, "wave": 0, "t": 0.0, "alive": []})


func arena_start(a: Dictionary) -> void:
	a["active"] = true
	a["wave"] = 0
	a["t"] = 1.8
	a["alive"] = []
	say("%s: LA SFIDA HA INIZIO" % a["def"]["n"])
	snd("roar")
	shake(4.0)


func arena_wave(a: Dictionary) -> void:
	var d: Dictionary = a["def"]
	var waves: Array = d["waves"]
	var w: Array = waves[int(a["wave"])]
	var tier: int = Game.BIO[int(d["si"])]["tier"]
	var n_tot := 0
	for ent in w:
		n_tot += int(ent[1])
	var k := 0
	for ent in w:
		for j in int(ent[1]):
			var ang := TAU * k / float(maxi(1, n_tot)) + randf() * 0.4
			var pos: Vector2 = a["pos"] + Vector2.from_angle(ang) * (float(d["r"]) * Game.TS * 0.85)
			var mult := 1.0 + tier * 0.14 + int(a["wave"]) * 0.08
			var kind: String = ent[0]
			var e := spawn_enemy(kind, pos, mult, false, Color.WHITE)
			e.awake = true
			e.set_process(true)
			(a["alive"] as Array).append(e)
			burst(pos, Color(0.8, 0.2, 0.2), 8, 40.0, 0.4)
			k += 1
	a["wave"] = int(a["wave"]) + 1
	say("%s  -  ONDATA %d / %d" % [d["n"], a["wave"], waves.size()])
	snd("hit")
	if str(d["id"]) == "a_fond":
		for hz in 3:
			var hp: Vector2 = a["pos"] + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 70.0)
			spawn_hazard(hp, 20.0, 1.2, 4.0, 10.0, 0.5, Color(1.0, 0.45, 0.1))


func arena_finish(a: Dictionary) -> void:
	var d: Dictionary = a["def"]
	a["done"] = true
	a["active"] = false
	persist["opened"]["arena:" + str(d["id"])] = true
	var pos: Vector2 = a["pos"]
	for i in int(d["rel"]):
		drop_relic(pos + Vector2(randf_range(-10, 10), 14))
	if int(d["wpn"]) > 0:
		drop_loot(pos + Vector2(randf_range(-14, 14), 18), Rpg.make_weapon(int(d["wpn"])))
	for i in 6:
		drop(pos + Vector2(randf_range(-10, 10), 10), "soul", int(d["souls"]) / 6)
	burst(pos, Color(1.0, 0.8, 0.35), 40, 80.0, 0.8)
	snd("level")
	say("%s: SFIDA SUPERATA" % d["n"])
	save_game()


func arena_update(real: float) -> void:
	for a in arenas:
		if a["done"]:
			continue
		if not a["active"]:
			if a["def"]["mode"] == "enter" and (a["pos"] as Vector2).distance_to(player.position) < 46.0:
				arena_start(a)
			continue
		var live: Array = []
		for e in a["alive"]:
			if is_instance_valid(e) and enemies.has(e):
				live.append(e)
		a["alive"] = live
		if live.is_empty():
			a["t"] = float(a["t"]) - real
			if float(a["t"]) <= 0.0:
				if int(a["wave"]) >= (a["def"]["waves"] as Array).size():
					arena_finish(a)
				else:
					arena_wave(a)
					a["t"] = 2.2


func arena_cancel() -> void:
	for a in arenas:
		if a["active"]:
			for e in a["alive"]:
				if is_instance_valid(e):
					enemies.erase(e)
					e.queue_free()
			a["alive"] = []
			a["active"] = false


func place_shrines() -> void:
	for si in range(1, SEEDS.size()):
		var tier: int = Game.BIO[si]["tier"]
		for n in 2:
			var c0: Vector2i = SEEDS[si] + Vector2i(randi_range(-24, 24), randi_range(-20, 20))
			if not inb(c0) or outside[idx(c0)] == 1 or water[idx(c0)] == 1:
				continue
			clear_disc(c0, 2)
			var sp := free_spot(c0, Vector2i(1, 1))
			if sp.x < 0:
				continue
			var sh := add_prop("shrine", sp)
			if sh != null:
				sh.item = {"cost": 150 + 130 * tier}
				reach[idx(sp)] = 1
				Game.make_light(sh, Vector2(0, -6), Color(0.5, 0.7, 1.0), 1.0, 0.7)


func place_gates() -> void:
	for gd in GATE_DEF:
		var gid: String = gd["id"]
		if not gate_cell.has(gid) or persist["opened"].has("gate:" + gid):
			continue
		var g: Vector2i = gate_cell[gid]
		var cells: Array = []
		for dy in range(-4, 5):
			var cc := Vector2i(g.x, g.y + dy)
			if inb(cc) and bridge[idx(cc)] == 1:
				cells.append(cc)
				block[cc] = true
		var pr := Prop.new()
		pr.setup_top("gate_top", g + Vector2i(0, -1), Vector2i(1, 3))
		pr.dest = gid
		pr.item = {"cells": cells}
		ents.add_child(pr)
		props.append(pr)
		Game.make_light(pr, Vector2(8, -24), Color(1.0, 0.7, 0.35), 1.2, 0.6)


func gate_try(p: Prop) -> void:
	var gd: Dictionary = {}
	for d in GATE_DEF:
		if d["id"] == p.dest:
			gd = d
	var req: String = gd.get("req", "")
	if req != "" and not persist["bosses"].has(req):
		say(str(gd["msg"]))
		return
	var side: String = gd.get("side", "")
	var gx: float = (p.cell.x + 0.5) * Game.TS
	if side == "E" and player.position.x < gx:
		say(str(gd["msg"]))
		return
	if side == "W" and player.position.x > gx:
		say(str(gd["msg"]))
		return
	for cc in p.item["cells"]:
		block.erase(cc)
	persist["opened"]["gate:" + p.dest] = true
	props.erase(p)
	snd("slam")
	say("IL CANCELLO SI APRE")
	p.queue_free()
	save_game()


func add_gate(dest: String, c: Vector2i, col: Color) -> void:
	var p := add_prop("portal", c)
	if p == null:
		return
	p.dest = dest
	returns[dest] = c
	Game.make_light(p, Vector2(0, -8), col, 4.5, 0.9)
	Game.make_fire(p, Vector2(0, -14), false)


# ------------------------------------------------------------------ arredo del mondo (vista dall'alto)
func tex_fp(name: String) -> Vector2i:
	var t: Texture2D = Game.tex(name)
	return Vector2i(maxi(1, ceili((t.get_width() - 4) / 16.0)), maxi(1, ceili((t.get_height() - 4) / 16.0)))


func area_free(c: Vector2i, f: Vector2i) -> bool:
	for dy in f.y:
		for dx in f.x:
			var cc := Vector2i(c.x + dx, c.y + dy)
			if not is_floor(cc) or block.has(cc) or reserved.has(cc):
				return false
	return true


func try_place(name: String, c: Vector2i, fx := false) -> Prop:
	if name.begins_with("roof_") and name.count("_") == 2:
		name += "_%d" % int(Game.hh(c.x, c.y) * 3.0)
	var f := tex_fp(name)
	if name == "cart_top":
		for tcell in tent_cells:
			if absi((tcell as Vector2i).x - c.x) < 7 and absi((tcell as Vector2i).y - c.y) < 7:
				return null   # niente carri accanto alle tende
	if not area_free(c, f):
		return null
	if area == "world" and persist["broken"].has(key(c)):
		return null   # distrutto dal giocatore
	if name.begins_with("tent"):
		tent_cells.append(c)
	var p := Prop.new()
	p.setup_top(name, c, f)
	if area == "world" and inb(c):
		p.spr.modulate *= Game.tone(biome[idx(c)])
	var cells: Array = []
	for dy in f.y:
		for dx in f.x:
			block[Vector2i(c.x + dx, c.y + dy)] = true
			cells.append(Vector2i(c.x + dx, c.y + dy))
	ents.add_child(p)
	register_dest(p, name, cells, key(c))
	if area.begins_with("int|"):
		furn.append([p, cells])
	add_fx(p, name, f, fx)
	register_door(name, c, f)
	return p


func register_door(name: String, c: Vector2i, f: Vector2i) -> void:
	if area != "world":
		return
	var ty := ""
	if name.begins_with("roof_"):
		ty = "house"
	elif name.begins_with("chapel_top"):
		ty = "chapel"
	elif name.begins_with("mausoleum_top"):
		ty = "mausoleum"
	elif name.begins_with("tower_top"):
		ty = "tower"
	elif name.begins_with("smithy_top"):
		ty = "smithy"
	elif name.begins_with("archive_top"):
		ty = "archive"
	elif name.begins_with("sanatorium_top"):
		ty = "sanatorium"
	if ty == "":
		return
	if ty == "house":
		randf()  # mantiene invariata la sequenza casuale (compatibilita' coi salvataggi)
	# ingresso invisibile al centro del lato anteriore: basta avvicinarsi
	var pos := Vector2(c.x * Game.TS + f.x * 8, (c.y + f.y) * Game.TS)
	doors.append({"pos": pos, "hw": float(f.x * 8 - 3), "dest": "int|%s|%d|%d" % [ty, c.x, c.y], "cell": Vector2i(floori(pos.x / Game.TS), c.y + f.y)})


## albero/cespuglio visto dall'alto: la chioma e' grande ma solo il tronco (cella centrale) blocca
# alberi a dimensione doppia: disattivati (gli sprite generati dall'AI avevano contorni brutti); da rifare a codice
const BIG_TREES := true
var tent_cells: Array = []


func big_tree_ok(c: Vector2i) -> bool:
	# la chioma grande occupa ~3 celle per lato: serve spazio libero attorno (niente oggetti/recinti/muri)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var cc := c + Vector2i(dx, dy)
			if block.has(cc) or reserved.has(cc):
				return false
			if absi(dx) <= 2 and absi(dy) <= 2 and not is_floor(cc):
				return false
	return true


func place_tree(name: String, center_c: Vector2i) -> void:
	if BIG_TREES and (name.begins_with("top_dead_") or name.begins_with("top_sick_")) and is_floor(center_c) and big_tree_ok(center_c):
		name = "tbig_" + name.substr(4)
		name = name.substr(0, name.length() - 1) + str(int(Game.hh(center_c.x, center_c.y) * 10.0) % 10)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				reserved[center_c + Vector2i(dx, dy)] = true
	var f := tex_fp(name)
	var c := center_c - f / 2
	if not is_floor(center_c) or block.has(center_c):
		return
	if area == "world" and persist["broken"].has(key(center_c)):
		return   # abbattuto dal giocatore
	var p := Prop.new()
	p.setup_top(name, c, f, true)
	block[center_c] = true
	ents.add_child(p)
	register_dest(p, name, [center_c], key(center_c))


func add_fx(p: Prop, name: String, f: Vector2i, fx: bool) -> void:
	if not fx:
		return
	var g := Scenery.glow(name)
	var sz := Vector2(f.x, f.y) * Game.TS * 0.5
	if not g.is_empty():
		var l := Game.make_light(p, Vector2(sz.x, -sz.y), g[0], g[1], g[2])
		flick.append([l, g[2], randf() * 10.0])
	if name.begins_with("roof_") or name.begins_with("smithy") or name.begins_with("chapel"):
		var sm := Game.make_fire(p, Vector2(randf_range(sz.x * 0.4, sz.x * 1.6), -sz.y * randf_range(0.6, 1.4)), false)
		sm.color_ramp = null
		sm.color = Color(0.4, 0.38, 0.45, 0.3)
		sm.gravity = Vector2(3, -8)
		sm.lifetime = 2.4
		sm.amount = 4
		sm.scale_amount_max = 3.0


func scatter_objects() -> void:
	var noises := {}
	var glows := 0
	for y in range(5, Game.MH - 5):
		for x in range(5, Game.MW - 5):
			var i := y * Game.MW + x
			if reach[i] != 1 or road[i] == 1 or cobble[i] == 1:
				continue
			if absi(x - SEEDS[0].x) < 28 and absi(y - SEEDS[0].y) < 22:
				continue
			var b: int = biome[i]
			var rules: Array = Scenery.OBJECTS[b]
			for ri in rules.size():
				var r: Dictionary = rules[ri]
				var dens: float = r["d"]
				if r.has("cf"):
					var nk := b * 16 + ri
					if not noises.has(nk):
						var nz := FastNoiseLite.new()
						nz.seed = world_seed + nk * 17
						nz.frequency = r["cf"]
						noises[nk] = nz
					var n := (((noises[nk] as FastNoiseLite).get_noise_2d(x, y)) + 1.0) * 0.5
					dens *= smoothstep(r["ct"], r["ct"] + 0.15, n) * 1.8
				if randf() >= dens:
					continue
				var names: Array = r["n"]
				var nm: String = names[randi() % names.size()]
				var want_fx := false
				if not Scenery.glow(nm).is_empty():
					if glows >= 60:
						continue
					want_fx = true
					glows += 1
				var pr: Prop = null
				if nm.begins_with("bush_") or nm.begins_with("circle_top"):
					place_tree(nm, Vector2i(x, y))
				else:
					pr = try_place(nm, Vector2i(x, y), want_fx)
				if pr != null:
					break


# ---------------- composizioni pianificate
func roof_name(w: int, h: int, theme: String) -> String:
	var pools := {
		"village": ["slate", "slate", "rust", "rust", "wood", "thatch", "moss"],
		"swamp": ["thatch", "moss", "wood"], "ice": ["ice", "ice", "slate"],
		"forge": ["ash", "ash", "rust"], "cem": ["slate", "ash"],
	}
	var pl: Array = pools[theme]
	return "roof_%dx%d_%s" % [w, h, pl[randi() % pl.size()]]


const SIZES := [[3, 3], [4, 3], [5, 3], [4, 4], [3, 4], [4, 2], [3, 2], [2, 3], [2, 2]]


func fence_line(a: Vector2i, b: Vector2i, gap_from: int, gap_to: int, iron: bool) -> void:
	# recinto lungo una linea orizzontale o verticale, con un varco (indici lungo la linea)
	var horiz := a.y == b.y
	var n := (b.x - a.x) if horiz else (b.y - a.y)
	var nm := "fence_%s_%s" % ["h" if horiz else "v", "iron" if iron else "wood"]
	for k in range(0, n + 1):
		if k >= gap_from and k <= gap_to:
			continue
		var c := Vector2i(a.x + k, a.y) if horiz else Vector2i(a.x, a.y + k)
		try_place(nm, c)


func fenced_rect(o: Vector2i, w: int, h: int, gate_side: int, iron: bool) -> void:
	# gate_side: 0 = sud, 1 = nord
	var gx := w / 2 - 1
	var gy := 0 if gate_side == 1 else h - 1
	fence_line(o, o + Vector2i(w - 1, 0), gx if gate_side == 1 else -1, gx + 2 if gate_side == 1 else -2, iron)
	fence_line(o + Vector2i(0, h - 1), o + Vector2i(w - 1, h - 1), gx if gate_side == 0 else -1, gx + 2 if gate_side == 0 else -2, iron)
	fence_line(o + Vector2i(0, 1), o + Vector2i(0, h - 2), -1, -2, iron)
	fence_line(o + Vector2i(w - 1, 1), o + Vector2i(w - 1, h - 2), -1, -2, iron)


func graveyard(o: Vector2i, w: int, h: int, chapel_roof: String, mausoleums: int) -> void:
	fenced_rect(o, w, h, 0, true)
	var top := 1
	if chapel_roof != "":
		try_place(chapel_roof, o + Vector2i(w / 2 - 2, 1), true)
		top = 9
	for k in mausoleums:
		try_place("mausoleum_top", o + Vector2i(2 + k * (w - 7), 1), false)
	var kinds := ["grave_mound_0", "grave_mound_1", "grave_slab_0", "grave_slab_1", "grave_cross_0", "grave_cross_1", "grave_mound_0", "grave_cross_0"]
	for gy in range(o.y + top + 1, o.y + h - 3, 3):
		for gx in range(o.x + 2, o.x + w - 2, 2):
			if randf() < 0.28:
				continue
			try_place(kinds[randi() % kinds.size()], Vector2i(gx, gy))
	place_tree("top_dead_%d" % (randi() % 4), o + Vector2i(1, h - 2))
	place_tree("top_dead_%d" % (randi() % 4), o + Vector2i(w - 2, h - 2))
	try_place("lamp_top", o + Vector2i(w / 2 - 2, h), true)
	try_place("lamp_top", o + Vector2i(w / 2 + 2, h), true)


func build_village() -> void:
	var v := SEEDS[0]
	# strade acciottolate e piazza
	for x in range(-24, 25):
		for dy in range(-1, 2):
			cobble[idx(v + Vector2i(x, dy))] = 1
	for y in range(-19, 20):
		for dx in range(-1, 2):
			cobble[idx(v + Vector2i(dx, y))] = 1
	for dy in range(-6, 7):
		for dx in range(-6, 7):
			if dx * dx + dy * dy <= 30:
				cobble[idx(v + Vector2i(dx, dy))] = 1
	# case allineate lungo il viale (file nord e sud)
	for side in [-1, 1]:
		var x := -23
		while x < 22:
			var sz: Array = SIZES[randi() % SIZES.size()]
			var w: int = sz[0]
			var h: int = mini(sz[1], 4)
			if x + w > -7 and x < 6:
				x = 6
				continue
			var by := -2 - h if side < 0 else 3
			if x + w >= 23:
				break
			try_place(roof_name(w, h, "village"), v + Vector2i(x, by), true)
			x += w + randi_range(1, 2)
	# case lungo il viale verticale
	for side in [-1, 1]:
		for yr in [[-17, -8], [8, 17]]:
			if yr[0] < 0 and side > 0:
				continue  # il cimitero occupa l'angolo nord-est
			var y: int = yr[0]
			while y < yr[1]:
				var sz: Array = SIZES[randi() % SIZES.size()]
				var w: int = sz[0]
				var h: int = sz[1]
				var bx := -2 - w if side < 0 else 3
				if y + h > yr[1] + 4:
					break
				try_place(roof_name(w, h, "village"), v + Vector2i(bx, y), true)
				y += h + randi_range(1, 2)
	# cimitero e cappella nell'angolo nord-est
	graveyard(v + Vector2i(7, -18), 17, 10, "", 1)
	try_place("chapel_top_slate", v + Vector2i(-24, -18), true)
	# piazza: pozzo, bancarelle, lampioni
	try_place("well_top", v + Vector2i(-2, -3))
	try_place("stall_top_0", v + Vector2i(-8, -3))
	try_place("stall_top_1", v + Vector2i(5, -4))
	try_place("stall_top_2", v + Vector2i(-8, 3))
	try_place("stall_top_0", v + Vector2i(5, 4))
	for x in [-22, -18, -15, -12, -9, -7, 7, 9, 12, 15, 18, 22]:
		try_place("lamp_top", v + Vector2i(x, -2), true)
		try_place("lamp_top", v + Vector2i(x, 2), true)
	for y in [-14, -8, 8, 14]:
		try_place("lamp_top", v + Vector2i(-2, y), true)
		try_place("lamp_top", v + Vector2i(2, y), true)
	try_place("cart_top", v + Vector2i(-21, 2))
	try_place("cart_top", v + Vector2i(15, -2))
	# recinto del villaggio con quattro cancelli
	var o := v + Vector2i(-26, -20)
	fence_line(o, o + Vector2i(52, 0), 24, 28, true)
	fence_line(o + Vector2i(0, 40), o + Vector2i(52, 40), 24, 28, true)
	fence_line(o + Vector2i(0, 1), o + Vector2i(0, 39), 18, 22, true)
	fence_line(o + Vector2i(52, 1), o + Vector2i(52, 39), 18, 22, true)
	# cortili: alberi secchi, cespugli, botti, casse e fieno
	for y in range(-19, 20):
		for x in range(-25, 26):
			var c := v + Vector2i(x, y)
			if cobble[idx(c)] == 1 or block.has(c) or not is_floor(c):
				continue
			var r := randf()
			if r < 0.012:
				place_tree("top_dead_%d" % (randi() % 4) if randf() < 0.7 else "top_sick_%d" % (randi() % 4), c)
			elif r < 0.03:
				place_tree("bush_sick_%d" % (randi() % 4), c)
			elif r < 0.04:
				try_place(["barrel_top", "crate_top", "hay_top"][randi() % 3], c)


## quartiere industriale: griglia di vie acciottolate, isolati di case, fonderie e una piazza con statua
func build_district(c: Vector2i) -> void:
	var hy := [-12, 0, 11]
	var vx := [-20, -1, 18]
	for x in range(-31, 32):
		for y0 in hy:
			for dy in 3:
				var cc := c + Vector2i(x, y0 + dy)
				if inb(cc) and grid[idx(cc)] == 1:
					cobble[idx(cc)] = 1
	for y in range(-22, 23):
		for x0 in vx:
			for dx in 3:
				var cc := c + Vector2i(x0 + dx, y)
				if inb(cc) and grid[idx(cc)] == 1:
					cobble[idx(cc)] = 1
	# fonderie (edifici con interno) agli incroci principali
	try_place("smithy_top", c + Vector2i(-15, -8), true)
	try_place("smithy_top", c + Vector2i(5, 4), true)
	# isolati
	var bands_y := [[-21, -13], [-9, -1], [3, 10], [14, 21]]
	var bands_x := [[-30, -21], [-17, -2], [2, 17], [21, 30]]
	for by in bands_y:
		var bh: int = by[1] - by[0] + 1
		for bx in bands_x:
			var x: int = bx[0]
			while x < bx[1] - 1:
				var sz: Array = SIZES[randi() % SIZES.size()]
				var w: int = sz[0]
				var h: int = mini(sz[1], bh)
				if x + w > bx[1] + 1:
					w = bx[1] + 1 - x
					if w < 2:
						break
				var placed := try_place(roof_name(w, h, "forge"), c + Vector2i(x, by[0] + bh - h), true)
				x += w + (1 if placed != null else 2)
	# piazza con statua e lampioni lungo le vie
	try_place("statue_top", c + Vector2i(-4, -4))
	try_place("well_top", c + Vector2i(4, -5))
	for x in range(-28, 30, 6):
		for y0 in hy:
			try_place("lamp_top", c + Vector2i(x, y0 - 1), true)
	for y in range(-20, 21, 6):
		for x0 in vx:
			try_place("lamp_top", c + Vector2i(x0 - 1, y), true)
	for i in 10:
		try_place(["barrel_top", "crate_top", "cart_top"][randi() % 3], c + Vector2i(randi_range(-29, 29), randi_range(-21, 21)))


func build_camp(c: Vector2i, n_tents: int, with_cart: bool) -> void:
	try_place("campfire_top", c, true)
	for k in n_tents:
		var a := TAU * k / n_tents + 0.5
		try_place("tent_top_%d" % (k % 3), c + Vector2i(roundi(cos(a) * 5.0) - 1, roundi(sin(a) * 4.0) - 1))
	if with_cart:
		try_place("cart_top", c + Vector2i(-7, 5))
	for k in 3:
		try_place(["barrel_top", "crate_top", "hay_top"][k], c + Vector2i(randi_range(-3, 3), randi_range(-3, 3)))
	for k in 2:
		var bc := c + Vector2i(randi_range(-4, 4), randi_range(-4, 4))
		if area_free(bc, Vector2i(1, 1)):
			var pt := Prop.new()
			pt.setup_top(["bone_skull_0", "bone_ribs_0"][k], bc, Vector2i(1, 1))
			ents.add_child(pt)


func build_ring(c: Vector2i, name: String, radius: float, n: int, center_name: String) -> void:
	for k in n:
		var a := TAU * k / n
		try_place(name, c + Vector2i(roundi(cos(a) * radius), roundi(sin(a) * radius)), true)
	if center_name != "":
		try_place(center_name, c, true)


func build_ruin(o: Vector2i, w: int, h: int, pal: String) -> void:
	# muri perimetrali spezzati con varchi e colonne all'interno
	for x in range(0, w, 3):
		if randf() < 0.75:
			try_place("wall_top_h3", o + Vector2i(x, 0))
		if randf() < 0.75:
			try_place("wall_top_h3", o + Vector2i(x, h - 1))
	for y in range(1, h - 1, 3):
		if randf() < 0.7:
			try_place("wall_top_v3", o + Vector2i(0, y))
		if randf() < 0.7:
			try_place("wall_top_v3", o + Vector2i(w - 1, y))
	for x in range(3, w - 3, 3):
		try_place("column_top", o + Vector2i(x, 3))
		try_place("column_top", o + Vector2i(x, h - 4))
	try_place("statue_top", o + Vector2i(w / 2 - 1, h / 2 - 1), true)


func build_hamlet(c: Vector2i, n: int, theme: String) -> void:
	try_place("well_top", c + Vector2i(-1, -1))
	for k in n:
		var a := TAU * k / n + 0.3
		var sz: Array = SIZES[randi() % SIZES.size()]
		var w: int = sz[0]
		var h: int = sz[1]
		var pc := c + Vector2i(roundi(cos(a) * 8.0) - w / 2, roundi(sin(a) * 6.5) - h / 2)
		try_place(roof_name(w, h, theme), pc, true)
	for k in 3:
		place_tree("bush_sick_%d" % (randi() % 4), c + Vector2i(randi_range(-5, 5), randi_range(-4, 4)))
	try_place("lamp_top", c + Vector2i(2, 0), true)


func place_structures() -> void:
	build_village()
	graveyard(SEEDS[1] + Vector2i(-9, -7), 19, 15, "chapel_top_slate", 2)
	build_camp(SEEDS[2] + Vector2i(0, 0), 4, true)
	build_hamlet(SEEDS[3], 4, "swamp")
	build_ruin(SEEDS[4] + Vector2i(-11, -9), 23, 18, "cat")
	try_place("chapel_top_ash", SEEDS[4] + Vector2i(-2, -8), true)
	try_place("tower_top", SEEDS[4] + Vector2i(10, -5), true)
	try_place("tower_top", SEEDS[4] + Vector2i(-13, 5), true)
	build_ring(SEEDS[5] + Vector2i(2, 2), "menhir_top_ice", 6.0, 8, "crystal_top_ice")
	build_hamlet(SEEDS[5] + Vector2i(-2, -2), 3, "ice")
	build_district(SEEDS[6])
	for si in range(1, SEEDS.size()):
		add_champion(SEEDS[si] + Vector2i(randi_range(-9, 9), randi_range(7, 12)), 1.2)


func decorate_nook(c: Vector2i, b: int) -> void:
	var p: String = Scenery.PAL[b]
	match randi() % 4:
		0:
			try_place("wall_top_h3", c + Vector2i(-4, -3))
			try_place("wall_top_v3", c + Vector2i(-4, -2))
			try_place("wall_top_h3", c + Vector2i(1, 4))
			try_place("column_top", c + Vector2i(4, 2))
			try_place("column_top", c + Vector2i(-3, 3))
		1:
			build_camp(c + Vector2i(0, 5), 2, false)
		2:
			for k in 4:
				try_place(["grave_mound_0", "grave_slab_0", "grave_cross_0", "grave_mound_1"][k], c + Vector2i(-4 + k * 2, 3))
			try_place("statue_top", c + Vector2i(-1, -4), true)
		_:
			build_ring(c, "boulder_%s_%d" % [p, randi() % 3], 4.0, 5, "")
			try_place("lamp_top", c + Vector2i(-2, -2), true)


# ------------------------------------------------------------------ personaggi, diari, minimappa, viaggio
const NPCS := {
	"becchino": {"n": "IL BECCHINO", "spr": "necro", "tint": Color(0.7, 0.85, 0.7), "cost": 350, "up": "vigor",
		"lines": ["BECCHINO: Scavo tombe da una vita. Ora scavo solo per chi non si rialza.",
			"BECCHINO: Il Falciatore dorme sotto la cappella. Non svegliarlo senza una fiala in tasca.",
			"BECCHINO: Per 350 anime ti insegno a incassare i colpi. Torna a trovarmi."]},
	"eremita": {"n": "L'EREMITA", "spr": "hunter", "tint": Color(0.75, 0.9, 0.75), "cost": 400, "up": "fiale",
		"lines": ["EREMITA: Gli alberi qui hanno occhi. Non fermarti sotto i rami.",
			"EREMITA: L'Impiccato vive nel covo a ovest. Era un uomo, un tempo.",
			"EREMITA: Ho una fiala in piu' per chi sa pagare: 400 anime."]},
	"strega": {"n": "LA STREGA", "spr": "cultist", "tint": Color(0.6, 1.0, 0.7), "cost": 300, "up": "elisir",
		"lines": ["STREGA: La melma ricorda ogni volto che ha inghiottito.",
			"STREGA: Nelle caverne a sud vive la Madre. Non e' cattiva: ha solo fame.",
			"STREGA: Un elisir piu' forte, per 300 anime. Non fare domande sugli ingredienti."]},
	"sacerdote": {"n": "IL SACERDOTE", "spr": "necro", "tint": Color(1.2, 1.0, 1.3), "cost": 500, "up": "armor",
		"lines": ["SACERDOTE: La cattedrale crollo' il giorno della benedizione sbagliata.",
			"SACERDOTE: Il gargoyle custode non e' di pietra: e' un voto spezzato.",
			"SACERDOTE: Posso benedire la tua armatura per 500 anime."]},
	"eremita_ghiaccio": {"n": "L'ANACORETA", "spr": "hunter", "tint": Color(0.7, 0.9, 1.4), "cost": 450, "up": "ritmo",
		"lines": ["ANACORETA: Il gelo rallenta tutto, tranne i rimpianti.",
			"ANACORETA: Il Gigante siede sul trono di ghiaccio. Nessuno e' tornato a raccontarlo.",
			"ANACORETA: Insegno a respirare nel freddo: 450 anime."]},
	"fabbro": {"n": "IL FABBRO", "spr": "hero", "tint": Color(1.3, 0.9, 0.7), "cost": 600, "up": "forza",
		"lines": ["FABBRO: Le forge non si spengono mai. Qualcosa sotto di loro le nutre.",
			"FABBRO: Il Colosso di Brace fu forgiato per custodire il secondo sigillo.",
			"FABBRO: Affilo la tua lama per 600 anime. Il ferro non mente."]},
}
const PAGES := [
	"DIARIO DEL CUSTODE: Il Signore non volle morire, e la cenere fu il suo debito.",
	"PAGINA STRAPPATA: Hanno sigillato la cripta con tre chiavi di sangue.",
	"DIARIO: I morti non dormono nel cimitero; ascoltano la campana spezzata.",
	"LETTERA: Mia amata, la foresta ha preso i nostri figli. Gli alberi hanno occhi.",
	"CACCIATORE: L'Impiccato non e' un uomo: e' il peso di chi fu condannato.",
	"DIARIO: Nella palude la melma ricorda i volti di chi vi e' annegato.",
	"PAGINA: La strega non mente mai, ma non dice mai tutto.",
	"CRONACA: La cattedrale crollo' quando il vescovo benedisse il Signore.",
	"PREGHIERA INCISA: Dio, se ci ascolti, perdona chi dorme fra i morti.",
	"FABBRO: Le forge non si spengono. Qualcosa sotto di loro le alimenta.",
	"APPUNTI: Il Colosso di Brace custodisce il secondo sigillo.",
	"LETTERA DAL GHIACCIO: Il Gigante veglia il trono. Nessuno e' tornato.",
	"PAGINA BRUCIATA: ...il Signore conosceva il tuo nome prima che nascessi...",
	"ULTIMA PAGINA: Chi legge ha gia' perso piu' di quanto creda. Brucia, ma non fermarti.",
]
const BIOC := [Color(0.40, 0.33, 0.30), Color(0.25, 0.38, 0.40), Color(0.20, 0.30, 0.20), Color(0.25, 0.38, 0.28),
	Color(0.40, 0.35, 0.45), Color(0.70, 0.78, 0.90), Color(0.50, 0.25, 0.20)]


func free_near(c: Vector2i) -> Vector2i:
	for r in range(0, 7):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if is_floor(cc) and not block.has(cc) and (area != "world" or (cobble[idx(cc)] == 0 and road[idx(cc)] == 0)):
					return cc
	return c


func add_npc(id: String, c: Vector2i) -> void:
	var d: Dictionary = NPCS[id]
	var cc := free_near(c)
	var p := Prop.new()
	p.setup(d["spr"], cc)
	p.kind = "npc"
	p.npc_id = id
	p.spr.modulate = d["tint"]
	block[cc] = true
	ents.add_child(p)
	props.append(p)


func souls_ok(n: int) -> bool:
	return player.souls >= n


func talk(p: Prop) -> void:
	var d: Dictionary = NPCS[p.npc_id]
	var st: Dictionary = persist.get("npc", {})
	persist["npc"] = st
	var step: int = st.get(p.npc_id, 0)
	var bought: bool = persist["opened"].has("npc:" + p.npc_id)
	var lines: Array = d["lines"]
	if bought:
		var stock: Dictionary = persist.get("stock", {})
		persist["stock"] = stock
		if not stock.has(p.npc_id):
			stock[p.npc_id] = Rpg.make_weapon(randi_range(1, 2))
		if persist["opened"].has("npcw:" + p.npc_id):
			say(lines[step % 2])
			st[p.npc_id] = step + 1
			return
		var wp: Dictionary = Rpg.clean(stock[p.npc_id])
		var price := 400 + 350 * int(wp["r"])
		var ws: int = int(st.get(p.npc_id + "_w", 0))
		if ws == 0:
			say("%s: Ho %s [%s] per %d anime.  %s" % [d["n"], Rpg.wname(wp), Rpg.RARITY[int(wp["r"])]["n"], price, Rpg.wdesc(wp)])
			st[p.npc_id + "_w"] = 1
		elif souls_ok(price):
			player.souls -= price
			persist["opened"]["npcw:" + p.npc_id] = true
			drop_loot(player.position + Vector2(0, 12), wp)
			snd("buy")
			say("%s: Eccola. Prendila da terra." % d["n"])
			save_game()
		else:
			say("%s: Servono %d anime." % [d["n"], price])
		return
	if step < lines.size():
		say(lines[step])
		st[p.npc_id] = step + 1
		return
	if player.souls >= int(d["cost"]):
		player.souls -= int(d["cost"])
		player.rk[d["up"]] = player.r(d["up"]) + 1
		player.apply_stats()
		persist["opened"]["npc:" + p.npc_id] = true
		snd("buy")
		save_game()
		say("%s: ACQUISTATO  (%s)" % [d["n"], str(d["up"]).to_upper()])
	else:
		say("%s: Servono %d anime." % [d["n"], int(d["cost"])])


func place_npcs_and_pages() -> void:
	add_npc("becchino", SEEDS[1] + Vector2i(2, 10))
	add_npc("eremita", SEEDS[2] + Vector2i(-1, 4))
	add_npc("strega", SEEDS[3] + Vector2i(3, 2))
	add_npc("sacerdote", SEEDS[4] + Vector2i(0, 11))
	add_npc("eremita_ghiaccio", SEEDS[5] + Vector2i(-4, 7))
	add_npc("fabbro", SEEDS[6] + Vector2i(-3, 3))
	# pagine di diario: due per regione
	var i := 0
	for si in SEEDS.size():
		for k in 2:
			for att in 40:
				var c: Vector2i = SEEDS[si] + Vector2i(randi_range(-14, 14), randi_range(-14, 14))
				if not is_floor(c) or reach[idx(c)] != 1 or block.has(c) or cobble[idx(c)] == 1 or road[idx(c)] == 1:
					continue
				if persist["opened"].has(key(c)):
					break
				var pr := Prop.new()
				pr.setup_top("page_top", c, Vector2i(1, 1))
				pr.kind = "page"
				pr.page_i = i
				ents.add_child(pr)
				props.append(pr)
				Game.make_light(pr, Vector2(6, -6), Color(1.0, 0.9, 0.6), 0.5, 0.5)
				break
			i += 1


func collect_pages() -> void:
	for p in props.duplicate():
		if p.kind == "page" and p.position.distance_to(player.position) < 14.0:
			props.erase(p)
			persist["opened"][key(p.cell)] = true
			pages_found += 1
			snd("page")
			say(PAGES[p.page_i % PAGES.size()] + page_hint())
			msg_t = 9.0
			p.queue_free()


func init_minimap() -> void:
	seen.resize(Game.MW * Game.MH)
	seen.fill(0)
	mm_img = Image.create(Game.MW, Game.MH, false, Image.FORMAT_RGBA8)
	mm_img.fill(Color(0, 0, 0, 0))
	# il mondo ricorda le zone gia' esplorate (anche dopo aver ricaricato la partita)
	if area == "world" and seen_load.size() == Game.MW * Game.MH:
		seen = seen_load.duplicate()
		seen_load = PackedByteArray()
		for y in Game.MH:
			for x in Game.MW:
				if seen[y * Game.MW + x] != 0:
					mm_img.set_pixel(x, y, mm_color(Vector2i(x, y)))
	mm_tex = ImageTexture.create_from_image(mm_img)


## esplorazione del mondo, anche mentre si e' in un dungeon (il mondo e' messo da parte)
func world_seen() -> PackedByteArray:
	if area == "world":
		return seen
	if not world_cache.is_empty():
		return world_cache.get("seen", PackedByteArray())
	return seen_load


## BERSAGLI DA SEGUIRE: obiettivo principale (oro) e missioni dei paesani (verde), nell'area attuale
func obj_targets() -> Array:
	var out: Array = []
	if run_mode or area == "" or area.begins_with("int|"):
		return out
	var gold := Color(1.0, 0.85, 0.25)
	var green := Color(0.45, 1.0, 0.7)
	if area == "world":
		var jt: Variant = journey_target()
		if jt != null:
			out.append({"p": jt, "c": gold, "n": "OBIETTIVO"})
		else:
			var g := main_gate()
			if g != "" and ENTR.has(g):
				out.append({"p": cell_pos(ENTR[g]), "c": gold, "n": str(DUNS[g]["n"])})
		var q: Dictionary = qp()
		for qid in q:
			if q[qid]["st"] != "active" or not quest_defs.has(qid):
				continue
			var d: Dictionary = quest_defs[qid]
			var tp: Variant = null
			if quest_complete(qid):
				for v in villagers:
					if is_instance_valid(v) and v.qid == qid:
						tp = v.position
				if tp == null and d.has("gpos"):
					tp = d["gpos"]
			else:
				match str(d["type"]):
					"fetch", "poi_fetch", "poi_find", "poi_clear":
						tp = cell_pos(d["tcell"])
					"clear":
						tp = d["tpos"]
					"visit":
						for a in arenas:
							if a["def"]["id"] == d["target"]:
								tp = a["pos"]
			if tp != null:
				var tn := str(d["giver"]) if quest_complete(qid) else str(d["txt"])
				if not quest_complete(qid) and d["type"] == "poi_clear" and pois[int(d["poi_id"])].get("built", false):
					tn += " (RIMASTI %d)" % poi_left(pois[int(d["poi_id"])])
				out.append({"p": tp, "c": green, "n": tn})
	elif DUNS.has(area):
		if boss_kind != "" and not persist["bosses"].has(boss_kind):
			out.append({"p": boss_pos, "c": gold, "n": "CUSTODE"})
	return out


## il dungeon dell'obiettivo principale (stesso ordine del testo dell'obiettivo)
func main_gate() -> String:
	if not persist["bosses"].has("boss_jailer"):
		return "d0"
	if guardians >= 3:
		return "dF"
	if not persist["bosses"].has("boss_wraith"):
		return "d1"
	if not persist["bosses"].has("boss_gargoyle"):
		return "d2"
	if not persist["bosses"].has("boss_forge"):
		return "d3"
	return ""


## BESTIARIO: un nemico entra nelle schede quando lo incontri; si contano anche le uccisioni
func beast_note(kind: String, killed := false) -> void:
	if run_mode or kind == "camp_part" or kind == "ooze_small":
		return
	if not persist.has("bestiary"):
		persist["bestiary"] = {}
	var b: Dictionary = persist["bestiary"]
	if not b.has(kind):
		b[kind] = 0
		if kind != "rat":
			popup(player.position + Vector2(0, -30), "BESTIARIO: NUOVA SCHEDA", Color(0.85, 0.75, 1.0))
	if killed:
		b[kind] = int(b[kind]) + 1


func open_bestiary() -> void:
	state = "bestiary"
	snd("page")


func open_map() -> void:
	if mm_tex == null:
		return
	map_zoom = 0
	map_pan = Vector2.ZERO
	state = "map"
	snd("page")


func mm_color(c: Vector2i) -> Color:
	var i := idx(c)
	if area == "world":
		if water[i] == 1:
			return Color(0.12, 0.25, 0.38)
		if bridge[i] == 1:
			return Color(0.5, 0.35, 0.2)
		if grid[i] == 0:
			return Color(0.07, 0.07, 0.09)
		if cobble[i] == 1:
			return Color(0.45, 0.43, 0.5)
		if road[i] == 1:
			return Color(0.38, 0.28, 0.2)
		return BIOC[biome[i]]
	if grid[i] == 0:
		return Color(0.07, 0.06, 0.09)
	return Color(0.32, 0.29, 0.38)


func update_minimap(real: float) -> void:
	mm_t -= real
	if mm_t > 0.0 or mm_img == null:
		return
	mm_t = 0.2
	var pc := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
	var dirty := false
	for dy in range(-10, 11):
		for dx in range(-10, 11):
			if dx * dx + dy * dy > 100:
				continue
			var c := pc + Vector2i(dx, dy)
			if inb(c) and seen[idx(c)] == 0:
				seen[idx(c)] = 1
				mm_img.set_pixelv(c, mm_color(c))
				dirty = true
	if dirty:
		mm_tex.update(mm_img)


func open_travel() -> void:
	travel_list = []
	for k in persist["fires"].keys():
		var ks: String = k
		if ks.begins_with("world:"):
			var parts := ks.substr(6).split(",")
			travel_list.append(Vector2i(int(parts[0]), int(parts[1])))
	if travel_list.size() < 2:
		say("NON CONOSCI ALTRI ACCAMPAMENTI")
		return
	travel_sel = 0
	state = "travel"


func travel_label(c: Vector2i) -> String:
	return "%s  (%d, %d)" % [Game.BIO[biome[idx(c)]]["n"] if area == "world" else "ACCAMPAMENTO", c.x, c.y]


func travel_to(c: Vector2i) -> void:
	state = "fade"
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(_do_travel.bind(c))
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): if state == "fade": state = "play")


func _do_travel(c: Vector2i) -> void:
	ensure_area(cell_pos(c), 2)
	if area != "world":
		build_area("world")
	last_fire = {"area": "world", "cell": c}
	player.position = cell_pos(c) + Vector2(0, 18)
	player.cam.reset_smoothing()
	spawn_all()
	say(Game.BIO[biome[idx(c)]]["n"])


# ------------------------------------------------------------------ INTERNI DEGLI EDIFICI
const INTERIORS := {
	"house": {"n": "CASA ABBANDONATA", "rows": [12], "rooms": 2, "rw": [7, 10], "rh": [6, 8], "amb": Color(0.22, 0.16, 0.14),
		"pool": ["zombie", "rat", "skeleton", "ghoul"]},
	"chapel": {"n": "CAPPELLA IN ROVINA", "rows": [3], "rooms": 2, "rw": [8, 11], "rh": [9, 12], "amb": Color(0.18, 0.13, 0.24),
		"pool": ["cultist", "skeleton", "wraith"]},
	"mausoleum": {"n": "MAUSOLEO", "rows": [0, 1], "rooms": 3, "rw": [6, 8], "rh": [5, 7], "amb": Color(0.13, 0.14, 0.2),
		"pool": ["skeleton", "ghoul", "wraith"]},
	"tower": {"n": "TORRE", "rows": [0], "rooms": 3, "rw": [6, 7], "rh": [6, 7], "amb": Color(0.17, 0.15, 0.2),
		"pool": ["skel_archer", "gargoyle", "skeleton"]},
	"archive": {"n": "ARCHIVIO DEI SIGILLI", "rows": [12], "rooms": 3, "rw": [9, 11], "rh": [7, 9], "amb": Color(0.2, 0.15, 0.12),
		"pool": ["wraith", "cultist", "summoner", "skeleton"]},
	"sanatorium": {"n": "SANATORIO DI VETRO", "rows": [3], "rooms": 3, "rw": [9, 11], "rh": [7, 9], "amb": Color(0.17, 0.2, 0.26),
		"pool": ["plague_doc", "zombie", "ghoul", "wraith"]},
	"smithy": {"n": "FUCINA", "rows": [0], "rooms": 2, "rw": [7, 9], "rh": [6, 7], "amb": Color(0.26, 0.14, 0.1),
		"pool": ["imp", "skeleton", "ooze"]},
}
const INT_CHAMP := {"archive": ["summoner", "reaper"], "sanatorium": ["plague_doc", "abomination"], "house": ["reaper", "summoner"], "chapel": ["reaper", "summoner", "knight_fallen"],
	"mausoleum": ["reaper", "abomination", "knight_fallen"], "tower": ["knight_fallen", "frost_mage"], "smithy": ["berserker"]}


func in_settlement(c: Vector2i) -> bool:
	for pr in [[0, 31.0], [2, 14.0], [3, 14.0], [5, 12.0]]:
		if Vector2(c).distance_to(Vector2(SEEDS[int(pr[0])])) < float(pr[1]):
			return true
	return false


func interior_def(a: String) -> Dictionary:
	var parts := a.split("|")
	var base: Dictionary = (INTERIORS[parts[1]] as Dictionary).duplicate()
	if parts.size() >= 4 and parts[1] == "house" and in_settlement(Vector2i(int(parts[2]), int(parts[3]))):
		base["safe"] = true
		base["n"] = "CASA DEL VILLAGGIO"
	base["type"] = parts[1]
	base["boss"] = ""
	base["mult"] = 1.3
	base["bio"] = 0
	base["mw"] = 46
	base["mh"] = 36
	return base


func room_kind(ty: String, i: int) -> String:
	match ty:
		"house":
			if i == 0:
				return "cucina"
			if i == 1:
				return "camera"
			return ["dispensa", "studio", "laboratorio"][randi() % 3]
		"chapel":
			return "navata" if i == 0 else "sacrestia"
		"mausoleum":
			return ["cripta", "ossario", "cripta"][i % 3]
		"tower":
			return ["guardia", "alloggio", "vedetta"][i % 3]
	if ty == "archive":
		return ["sala_lettura", "scrittorio", "sala_lettura"][i % 3]
	if ty == "sanatorium":
		return ["camerata", "sala_cure", "camerata"][i % 3]
	return "fucina" if i == 0 else "alloggio"


## oggetto addossato a una parete (N, S, W, E) alla posizione `along`
func wp(name: String, inner: Rect2i, side: String, along: int) -> Prop:
	var f := tex_fp(name)
	var c := Vector2i.ZERO
	match side:
		"N":
			c = Vector2i(inner.position.x + along, inner.position.y)
		"S":
			c = Vector2i(inner.position.x + along, inner.end.y - f.y)
		"W":
			c = Vector2i(inner.position.x, inner.position.y + along)
		_:
			c = Vector2i(inner.end.x - f.x, inner.position.y + along)
	return try_place(name, c)


## distribuisce fino a `count` oggetti lungo una parete, uno accanto all'altro
func spread(name: String, inner: Rect2i, side: String, count: int) -> void:
	var f := tex_fp(name)
	var horiz := side == "N" or side == "S"
	var length: int = inner.size.x if horiz else inner.size.y
	var step: int = f.x if horiz else f.y
	var slots: Array = []
	for a in range(0, length - step + 1, step):
		slots.append(a)
	slots.shuffle()
	var n := 0
	for a in slots:
		if n >= count:
			break
		if wp(name, inner, side, a) != null:
			n += 1


func decor(name: String, c: Vector2i) -> void:
	var p := Prop.new()
	p.setup_top(name, c, tex_fp(name), true)
	p.z_index = -2
	ents.add_child(p)


func table_set(cx: int, cy: int) -> void:
	try_place("table_top", Vector2i(cx - 1, cy))
	try_place("chair_top", Vector2i(cx - 1, cy - 1))
	try_place("chair_top", Vector2i(cx, cy + 1))
	try_place("chair_top", Vector2i(cx - 2, cy))


func corner_lamps(inner: Rect2i, both := true) -> void:
	try_place("lamp_top", inner.position, true)
	if both:
		try_place("lamp_top", Vector2i(inner.end.x - 1, inner.position.y), true)


func place_chest(inner: Rect2i) -> void:
	for att in 30:
		var c := Vector2i(inner.position.x + randi() % inner.size.x, inner.position.y if randf() < 0.7 else inner.end.y - 1)
		if is_floor(c) and not block.has(c) and not reserved.has(c):
			add_prop("chest", c)
			return
	var cc := rand_cell(inner)
	if cc != Vector2i(-1, -1):
		add_prop("chest", cc)


func furnish(ty: String, i: int, r: Rect2i, inner: Rect2i) -> void:
	var kind := room_kind(ty, i)
	var cx := center(r).x
	var cy := center(r).y
	var iw := inner.size.x
	var rug := "rug_top_%d" % (randi() % 3)
	match kind:
		"sala_lettura":
			spread("shelf_top", inner, "N", 4)
			spread("shelf_top", inner, "W", 2)
			spread("shelf_top", inner, "E", 2)
			table_set(cx, cy)
			decor(rug, Vector2i(cx - 2, cy - 1))
			corner_lamps(inner)
		"scrittorio":
			spread("shelf_top", inner, "N", 3)
			table_set(cx, cy - 1)
			wp("table_top", inner, "W", 2)
			wp("table_top", inner, "E", 2)
			corner_lamps(inner)
			if i == rooms.size() - 1 or i == 1:
				drop_loot(cell_pos(Vector2i(cx, cy + 2)), loot_tome())
		"camerata":
			spread("bed_top", inner, "N", 3)
			spread("bed_top", inner, "S", 2)
			wp("table_top", inner, "E", 2)
			corner_lamps(inner, false)
		"sala_cure":
			try_place("cauldron_top", Vector2i(cx - 1, cy), true)
			table_set(cx + 2, cy)
			spread("shelf_top", inner, "N", 3)
			spread("wardrobe_top", inner, "W", 1)
			corner_lamps(inner)
			if randf() < 0.35:
				drop_loot(cell_pos(Vector2i(cx, cy + 3)), Rpg.random_weapon([40, 45, 14, 1]))
		"cucina":
			wp("hearth_top", inner, "N", clampi(iw / 2 - 1, 0, maxi(iw - 2, 0)))
			spread("shelf_top", inner, "N", 1)
			wp("cauldron_top", inner, "N", 0)
			table_set(cx, cy)
			decor(rug, Vector2i(cx - 2, cy - 1))
			spread("barrel_top", inner, "S", 2)
			spread("crate_top", inner, "S", 1)
			spread("sack_top", inner, "W", 2)
		"camera":
			var bed := wp("bed_top", inner, "N", randi() % maxi(1, iw - 1))
			if bed != null:
				decor(rug, bed.cell + Vector2i(-1, 2))
			spread("wardrobe_top", inner, "N", 1)
			wp("table_top", inner, "W" if randf() < 0.5 else "E", 1 + randi() % 2)
			corner_lamps(inner, false)
			spread("sack_top", inner, "S", 1)
		"dispensa":
			spread("barrel_top", inner, "N", 4)
			spread("crate_top", inner, "W", 3)
			spread("sack_top", inner, "E", 3)
			spread("shelf_top", inner, "S", 1)
		"studio":
			spread("shelf_top", inner, "N", 3)
			table_set(cx, cy)
			decor(rug, Vector2i(cx - 2, cy - 1))
			corner_lamps(inner)
		"laboratorio":
			try_place("cauldron_top", Vector2i(cx - 1, cy), true)
			try_place("cauldron_top", Vector2i(cx + 1, cy - 1), true)
			spread("shelf_top", inner, "N", 2)
			wp("table_top", inner, "E", 1)
			try_place("skullpile", Vector2i(inner.position.x, inner.end.y - 1))
			corner_lamps(inner, false)
		"navata":
			try_place("altar", Vector2i(cx, inner.position.y))
			try_place("lamp_top", Vector2i(cx - 2, inner.position.y), true)
			try_place("lamp_top", Vector2i(cx + 2, inner.position.y), true)
			for y in range(inner.position.y + 3, inner.end.y - 2, 2):
				try_place("pew_top", Vector2i(inner.position.x + 1, y))
				try_place("pew_top", Vector2i(inner.end.x - 4, y))
			spread("statue_top", inner, "W", 1)
			spread("statue_top", inner, "E", 1)
		"sacrestia":
			spread("shelf_top", inner, "N", 2)
			spread("wardrobe_top", inner, "N", 1)
			table_set(cx, cy)
			spread("crate_top", inner, "S", 2)
			corner_lamps(inner, false)
		"cripta":
			for y in range(inner.position.y + 1, inner.end.y - 1, 2):
				try_place("tomb", Vector2i(inner.position.x + 1, y))
				try_place("tomb", Vector2i(inner.end.x - 2, y))
			corner_lamps(inner)
		"ossario":
			spread("skullpile", inner, "N", 3)
			spread("coffin", inner, "W", 2)
			spread("coffin", inner, "E", 2)
			corner_lamps(inner, false)
		"guardia":
			wp("rack_top", inner, "N", 0)
			wp("rack_top", inner, "N", maxi(0, iw - 2))
			table_set(cx, cy)
			spread("barrel_top", inner, "S", 2)
			corner_lamps(inner, false)
		"alloggio":
			spread("bed_top", inner, "N", 2)
			spread("wardrobe_top", inner, "N", 1)
			wp("table_top", inner, "E", 1)
			decor(rug, Vector2i(cx - 1, cy))
			corner_lamps(inner, false)
		"vedetta":
			try_place("column_top", Vector2i(cx, cy - 1))
			spread("crate_top", inner, "S", 2)
			spread("barrel_top", inner, "E", 2)
			corner_lamps(inner)
		_:  # fucina
			wp("hearth_top", inner, "N", clampi(iw / 2 - 1, 0, maxi(iw - 2, 0)))
			try_place("anvil_top", Vector2i(cx, inner.position.y + 2))
			wp("rack_top", inner, "N", 0)
			if i == 0 and randf() < 0.5:
				drop_loot(cell_pos(Vector2i(inner.position.x + 1, inner.position.y + 2)), Rpg.random_weapon([30, 50, 18, 2]))
			spread("barrel_top", inner, "E", 2)
			spread("sack_top", inner, "W", 2)
			corner_lamps(inner, false)


func interior_ratio() -> float:
	var start := exit_cell + Vector2i(0, -1)
	var seen := {start: true}
	var q: Array = [start]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + dv
			if is_floor(nc) and not block.has(nc) and not seen.has(nc):
				seen[nc] = true
				q.append(nc)
	var total := 0
	for y in Game.MH:
		for x in Game.MW:
			var cc := Vector2i(x, y)
			if is_floor(cc) and not block.has(cc):
				total += 1
	return float(seen.size()) / maxf(1.0, float(total))


## nessuna tasca irraggiungibile: se l'arredo chiude zone, toglie i mobili piazzati per ultimi
func fix_interior() -> void:
	for it in 60:
		if interior_ratio() >= 0.98 or furn.is_empty():
			return
		var f: Array = furn.pop_back()
		for c in f[1]:
			block.erase(c)
		(f[0] as Node).queue_free()


func populate_interior() -> void:
	var ty: String = dun["type"]
	var start := rooms[0]
	exit_cell = Vector2i(center(start).x, start.end.y - 1)
	for ry in range(-3, 1):
		for rx in range(-1, 2):
			reserved[exit_cell + Vector2i(rx, ry)] = true
	for cc0 in carved:
		reserved[cc0] = true
	var ex := Prop.new()
	ex.setup_top("door_top", exit_cell, Vector2i(1, 1))
	ex.kind = "exit"
	ex.cell = exit_cell
	ents.add_child(ex)
	props.append(ex)
	Game.make_light(ex, Vector2(8, -6), Color(1.0, 0.8, 0.5), 1.6, 0.7)
	var pool: Array = dun["pool"]
	for i in rooms.size():
		var r := rooms[i]
		var inner := r.grow(-1)
		furnish(ty, i, r, inner)
		if i == rooms.size() - 1:
			place_chest(inner)
		var n := randi_range(1, 3) if i > 0 else (1 if randf() < 0.5 else 0)
		if dun.get("safe", false):
			n = 0
		for k in n:
			var cc2 := rand_cell(inner)
			if cc2 != Vector2i(-1, -1) and (i > 0 or cc2.y < r.end.y - 4):
				spawns.append({"k": pool[randi() % pool.size()], "pos": cell_pos(cc2), "mult": 1.3, "elite": false, "tint": Color.WHITE})
	fix_interior()
	if dun.get("safe", false):
		for fe in furn:
			var bp: Prop = fe[0]
			if bp.kind == "bed_top":
				props.append(bp)
	var cl: Array = INT_CHAMP[ty]
	if (ty != "house" or randf() < 0.3) and not dun.get("safe", false):
		var cc3 := rand_cell(rooms[rooms.size() - 1].grow(-1))
		if cc3 != Vector2i(-1, -1):
			spawns.append({"k": cl[randi() % cl.size()], "pos": cell_pos(cc3), "mult": 1.2, "elite": false, "tint": Color.WHITE})
	spawn_all()


# ------------------------------------------------------------------ DUNGEON
func gen_dungeon() -> void:
	carved.clear()
	Game.MW = int(dun.get("mw", 80))
	Game.MH = int(dun.get("mh", 60))
	var n := Game.MW * Game.MH
	grid.resize(n)
	grid.fill(0)
	room_of.resize(n)
	room_of.fill(-1)
	biome.resize(n)
	biome.fill(dun["bio"])
	var tries := 0
	if dun.get("arena", false):
		rooms.append(Rect2i(Game.MW / 2 - 6, Game.MH - 14, 12, 9))
		rooms.append(Rect2i(Game.MW / 2 - 18, 4, 36, 28))
		tries = 9999
	while rooms.size() < int(dun["rooms"]) and tries < 800:
		tries += 1
		var rw: Array = dun.get("rw", [8, 15])
		var rh: Array = dun.get("rh", [6, 11])
		var w := randi_range(rw[0], rw[1])
		var h := randi_range(rh[0], rh[1])
		var r := Rect2i(randi_range(3, Game.MW - w - 4), randi_range(3, Game.MH - h - 4), w, h)
		var bad := false
		for o in rooms:
			if r.grow(3).intersects(o):
				bad = true
				break
		if not bad:
			rooms.append(r)
	for i in rooms.size():
		var r := rooms[i]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				grid[idx(Vector2i(x, y))] = 1
				room_of[idx(Vector2i(x, y))] = i
	for i in range(1, rooms.size()):
		carve(center(rooms[i - 1]), center(rooms[i]))
		if randf() < 0.3:
			carve(center(rooms[i]), center(rooms[randi() % i]))
	var rows: Array = dun["rows"]
	for i in rooms.size():
		themes.append(rows[randi() % rows.size()])


func carve(a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		grid[idx(Vector2i(x, y))] = 1
		grid[idx(Vector2i(x, y + 1))] = 1
		carved.append(Vector2i(x, y))
		carved.append(Vector2i(x, y + 1))
		x += 1 if x < b.x else -1
	while y != b.y:
		grid[idx(Vector2i(x, y))] = 1
		grid[idx(Vector2i(x + 1, y))] = 1
		carved.append(Vector2i(x, y))
		carved.append(Vector2i(x + 1, y))
		y += 1 if y < b.y else -1


func build_tiles() -> void:
	var n := Game.MW * Game.MH
	var theme := PackedByteArray()
	theme.resize(n)
	var carpet := PackedByteArray()
	carpet.resize(n)
	var codes := {Game.T_CRIPTA: 0, Game.T_RUNE: 2, Game.T_SANGUE: 1, Game.T_SCACCHI: 3, Game.T_LAVA: 5, 12: 6}
	for y in Game.MH:
		for x in Game.MW:
			var c := Vector2i(x, y)
			var i := idx(c)
			if grid[i] == 1:
				var ri := room_of[i]
				if ri < 0 and area.begins_with("int|"):
					theme[i] = codes.get(int(dun["rows"][0]), 0)
				if ri >= 0:
					theme[i] = codes.get(themes[ri], 0)
					if themes[ri] == Game.T_RUNE or themes[ri] == Game.T_SANGUE:
						pass
				if has_carpet(c):
					carpet[i] = 1
			elif is_floor(c + Vector2i(0, 1)) and randf() < 0.13 and not is_floor(c + Vector2i(-1, 0)) and not is_floor(c + Vector2i(1, 0)):
				add_torch(c)
	wr_node = WorldRender.new()
	add_child(wr_node)
	area_nodes.append(wr_node)
	var zero := PackedByteArray()
	zero.resize(n)
	var fb := 6 if str(dun["rows"][0]) == str(Game.T_LAVA) else 4
	wr_node.build(grid, biome, zero, zero, zero, zero, Game.MW, Game.MH, theme, carpet, fb)


func add_torch(c: Vector2i) -> void:
	var n := Node2D.new()
	n.position = Vector2(c) * Game.TS + Vector2(8, 10)
	Game.make_fire(n, Vector2(0, -4))
	var l := Game.make_light(n, Vector2(0, 12), Color(1.0, 0.62, 0.3), 1.5, 1.0)
	flick.append([l, 1.0, randf() * 10.0])
	n.z_index = -8
	add_child(n)
	area_nodes.append(n)


func populate_dungeon() -> void:
	var start := rooms[0]
	var far := 1
	var fd := 0.0
	for i in range(1, rooms.size()):
		var d := Vector2(center(rooms[i])).distance_to(Vector2(center(start)))
		if d > fd:
			fd = d
			far = i
	themes[far] = Game.T_SANGUE
	boss_kind = dun["boss"]
	boss_tint = dun.get("tint", Color.WHITE)
	var fires := {0: true, far - 1: true}
	for i in range(2, rooms.size()):
		if i % 4 == 2 and i != far:
			fires[i] = true
	var pool: Array = Game.BIO[dun["bio"]]["pool"]
	var tint: Color = Game.BIO[dun["bio"]]["tint"]
	for i in rooms.size():
		var r := rooms[i]
		var inner := r.grow(-1)
		var corners := [inner.position, Vector2i(inner.end.x - 1, inner.position.y),
			Vector2i(inner.position.x, inner.end.y - 1), Vector2i(inner.end.x - 1, inner.end.y - 1)]
		for c in corners:
			if i == far:
				add_prop("brazier", c)
			elif randf() < 0.55:
				try_place("lamp_top", c, true)
			elif r.size.x >= 10 and randf() < 0.5:
				try_place("column_top", c)
		if fires.has(i) and i != far:
			var fc := center(r) + Vector2i(2, 0)
			if i == 0:
				persist["fires"][key(fc)] = true
			var bp := add_prop("bonfire", fc)
			if bp != null and i == 0 and last_fire.get("area", "") == "world" and not persist["bosses"].has("_x"):
				pass
		if i == 0:
			var ex := add_prop("portal", center(r) + Vector2i(-2, 0))
			if ex != null:
				ex.dest = "world"
				Game.make_light(ex, Vector2(0, -8), Color(0.7, 0.4, 1.0), 1.6, 0.7)
			continue
		if i == far and dun.get("arena", false):
			arena_props(r)
			continue
		if i == far:
			add_prop("altar", center(r) + Vector2i(0, -2))
			boss_pos = cell_pos(center(r))
			continue
		for k in randi_range(2, 5):
			var c := rand_cell(inner)
			if c != Vector2i(-1, -1):
				var pick: String = ["grave_slab_0", "tomb", "skullpile", "barrel_top", "crate_top", "coffin", "statue_top", "column_top"][randi() % 8]
				try_place(pick, c)
		if randf() < 0.18:
			var cc := rand_cell(inner)
			if cc != Vector2i(-1, -1):
				add_prop("chest", cc)
		var n: int = min(2 + randi() % 3 + i / 4, 8)
		for k in n:
			var cc := rand_cell(inner)
			if cc != Vector2i(-1, -1):
				spawns.append({"k": pool[randi() % pool.size()], "pos": cell_pos(cc),
					"mult": float(dun["mult"]) + i * 0.05, "elite": randf() < 0.08, "tint": tint})
	for ri in range(2, rooms.size()):
		if ri != far and randf() < 0.35:
			var cc := rand_cell(rooms[ri].grow(-1))
			if cc != Vector2i(-1, -1):
				add_champion(cc, float(dun["mult"]) / 1.5)
	spawn_all()


func rand_cell(r: Rect2i) -> Vector2i:
	for k in 30:
		var c := Vector2i(randi_range(r.position.x, r.end.x - 1), randi_range(r.position.y, r.end.y - 1))
		if is_floor(c) and not block.has(c) and not has_carpet(c) and c.distance_to(center(rooms[room_of[idx(c)]])) > 1.5:
			return c
	return Vector2i(-1, -1)


# ------------------------------------------------------------------ oggetti ed entita'
func add_prop(k: String, c: Vector2i) -> Prop:
	if not is_floor(c) or block.has(c) or has_carpet(c):
		return null
	var ky := key(c)
	if persist["broken"].has(ky):
		return null
	var p := Prop.new()
	p.setup(k, c)
	if k == "elder":
		p.spr.texture = Game.tex("necro")
	block[c] = true
	if k == "candelabra" or k == "brazier":
		var big := k == "brazier"
		Game.make_fire(p, Vector2(0, -16) if not big else Vector2(0, -9), big)
		var l := Game.make_light(p, Vector2(0, -10), Color(1.0, 0.3, 0.2) if big else Color(1.0, 0.68, 0.35),
			2.0 if big else 1.6, 1.1)
		flick.append([l, 1.1, randf() * 10.0])
	if k == "bonfire":
		var cs := "bedroll"
		if area == "world":
			cs = "hut_camp" if biome[idx(c)] in [2, 3, 5] else "tent_camp"
		p.spr.texture = Game.tex(cs)
		p.spr.offset = Vector2(0, -9)
		p.light = Game.make_light(p, Vector2(0, -8), Color(0.45, 0.5, 1.0), 0.8, 0.5)
	if k == "key" and persist["opened"].has("key:sigilli"):
		return null
	if k == "shrine" and persist["opened"].has(ky):
		p.opened = true
		p.spr.modulate = Color(0.5, 0.5, 0.6)
	if k == "lever" and persist["opened"].has("lever:sanat"):
		p.spr.modulate = Color(0.6, 0.6, 0.7)
		p.spr.flip_h = true
	if k == "chest" and persist["opened"].has(ky):
		p.opened = true
		p.spr.modulate = Color(0.5, 0.45, 0.55)
	ents.add_child(p)
	props.append(p)
	if k == "bonfire" and persist["fires"].has(ky):
		light_bonfire(p)
	return p


func light_bonfire(p: Prop) -> void:
	if p.lit:
		return
	p.lit = true
	persist["fires"][key(p.cell)] = true
	if p.light != null:
		p.light.energy = 1.15
		p.light.texture_scale = 1.9
		p.light.color = Color(1.0, 0.8, 0.5)
		flick.append([p.light, 1.15, randf() * 10.0])


func __unused_spawn_all() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for s in spawns:
		spawn_enemy(s["k"], s["pos"], s["mult"], s["elite"], s["tint"])
	if boss_kind != "" and not persist["bosses"].has(boss_kind):
		spawn_enemy(boss_kind, boss_pos, 1.0, false, boss_tint)
	for c in fx.get_children():
		if c is Projectile:
			c.queue_free()


func spawn_enemy(k: String, pos: Vector2, mult := 1.0, elite := false, tint := Color.WHITE) -> Enemy:
	var e := Enemy.new()
	e.setup(self, k, mult, elite, tint)
	e.position = pos
	ents.add_child(e)
	enemies.append(e)
	return e


func spawn_projectile(pos: Vector2, dir: Vector2, spd: float, d: float, slow := 0.0) -> void:
	var p := Projectile.new()
	p.setup(self, dir, spd, d, slow)
	p.position = pos
	fx.add_child(p)


func drop(pos: Vector2, k: String, v: int) -> void:
	var p := Pickup.new()
	p.setup(self, k, v)
	p.position = pos
	ents.add_child(p)


func make_stain() -> void:
	if stain_data.is_empty() or stain_data["area"] != area:
		return
	stain = Node2D.new()
	stain.position = stain_data["pos"]
	var s := Sprite2D.new()
	s.texture = Game.tex("soul")
	s.scale = Vector2(2, 2)
	s.offset = Vector2(0, -6)
	stain.add_child(s)
	Game.make_light(stain, Vector2(0, -6), Color(0.3, 1.0, 0.7), 1.2, 1.0)
	ents.add_child(stain)


func build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	var vg := ColorRect.new()
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){vec2 uv=UV-0.5;float v=smoothstep(0.36,0.85,length(uv*vec2(1.0,0.85)));COLOR=vec4(0.03,0.0,0.07,v*0.5);}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	vg.material = mat
	cl.add_child(vg)
	hud = Hud.new()
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hud)
	# comandi touch: solo su telefoni/tablet (o con --touch per provarli sul PC)
	if DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch"):
		# telefono piu' largo del 16:9: la finestra si allarga e i comandi vanno nelle bande laterali
		get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var tl := CanvasLayer.new()
		tl.layer = 9
		add_child(tl)
		var tc := TouchControls.new()
		tc.main = self
		tl.add_child(tc)
	var fl := CanvasLayer.new()
	fl.layer = 10
	add_child(fl)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade)


# ------------------------------------------------------------------ fisica
func solid(c: Vector2i) -> bool:
	return not is_floor(c) or block.has(c)


func solid_at(p: Vector2) -> bool:
	return solid(Vector2i(floori(p.x / Game.TS), floori(p.y / Game.TS)))


func free_at(p: Vector2, r: float) -> bool:
	return not (solid_at(p + Vector2(-r, -r + 3)) or solid_at(p + Vector2(r, -r + 3))
		or solid_at(p + Vector2(-r, r)) or solid_at(p + Vector2(r, r)))


func move_body(o: Node2D, d: Vector2, r: float) -> void:
	if free_at(o.position + Vector2(d.x, 0), r):
		o.position.x += d.x
	if free_at(o.position + Vector2(0, d.y), r):
		o.position.y += d.y


## movimento dei mezzi evocati nel mondo aperto: l'ufo vola sopra tutto, il carrarmato abbatte gli ostacoli
func move_vehicle(o: Node2D, d: Vector2, r: float, kind: String) -> void:
	if area == "world":
		if kind == "ufo":
			var lim := Vector2(Game.MW, Game.MH) * Game.TS - Vector2(10, 10)
			o.position = (o.position + d).clamp(Vector2(10, 10), lim)
			return
		if kind == "tank" and d.length_squared() > 0.0:
			var ahead := o.position + d.normalized() * (r + 5.0)
			var probes: Array = [ahead, ahead + d.normalized().orthogonal() * (r + 3.0), ahead - d.normalized().orthogonal() * (r + 3.0),
				o.position + Vector2(d.x, 0) + Vector2(sign(d.x) * (r + 3.0), 0), o.position + Vector2(0, d.y) + Vector2(0, sign(d.y) * (r + 3.0))]
			for pp in probes:
				_tank_crush(Vector2i(floori(pp.x / Game.TS), floori(pp.y / Game.TS)))
	move_body(o, d, r)


func _tank_crush(c: Vector2i) -> void:
	if not inb(c):
		return
	if dest_cells.has(c) and is_instance_valid(dest_cells[c]):
		var pr: Prop = dest_cells[c]
		destroy_at(c, pr, pr.dm, pr.dd, false)
	elif terrain_breakable(c) and solid(c):
		var ti := Destruct.terrain(biome[idx(c)])
		destroy_at(c, null, str(ti["m"]), str(ti["d"]), false)   # anche montagne e muri, ma senza bottino


## il mezzo e' finito sopra un ostacolo (l'ufo vola): rimetti il personaggio sul terreno libero piu' vicino
func unstick(o: Node2D, r: float) -> void:
	if free_at(o.position, r):
		return
	for ring in range(1, 14):
		for i in 16:
			var p: Vector2 = o.position + Vector2.from_angle(i * TAU / 16.0) * (ring * 8.0)
			if free_at(p, r):
				o.position = p
				return


# ------------------------------------------------------------------ eventi di gioco
func say(s: String) -> void:
	msg = s
	msg_t = 3.0


func shake(v: float) -> void:
	if not bool(settings["shake"]):
		return
	shake_v = max(shake_v, v)


func hitstop(s: float) -> void:
	hitstop_t = max(hitstop_t, s * 0.5)


func popup(pos: Vector2, s: String, c: Color) -> void:
	var l := Label.new()
	l.text = s
	l.text = s.to_upper()
	l.add_theme_font_override("font", Game.font())
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0.02, 0, 0.05))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 1)
	l.position = pos - Vector2(8, 4)
	fx.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14.0, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


var burst_pool := {8: [], 20: [], 48: []}


func burst(pos: Vector2, c: Color, n: int, speed: float, life: float) -> void:
	var cls := 8 if n <= 8 else (20 if n <= 20 else 48)
	var pool: Array = burst_pool[cls]
	var p: CPUParticles2D = null
	for q in pool:
		if is_instance_valid(q) and not q.emitting:
			p = q
			break
	if p == null:
		if pool.size() >= 14:
			return
		p = CPUParticles2D.new()
		p.amount = cls
		p.one_shot = true
		p.explosiveness = 1.0
		p.spread = 180.0
		p.gravity = Vector2.ZERO
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.4
		p.damping_min = 40.0
		p.damping_max = 80.0
		p.emitting = false
		fx.add_child(p)
		pool.append(p)
	p.position = pos + Vector2(0, -4)
	p.lifetime = life
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.color = c
	p.restart()
	p.emitting = true


func break_prop(p: Prop) -> void:
	props.erase(p)
	block.erase(p.cell)
	persist["broken"][key(p.cell)] = true
	burst(p.position, Color(0.45, 0.28, 0.18), 12, 55.0, 0.5)
	drop(p.position, "soul", randi_range(3, 8))
	p.queue_free()


func enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	beast_note(e.kind, true)
	if not (e.is_boss and e.kind == "vampire"):
		mat_drops(str(e.kind), e.champ)
	if not e.sref.is_empty():
		e.sref["alive"] = false
		e.sref["node"] = null
	quest_event("kill", e.kind, e.champ)
	e.death_trait()
	if e.kind == "ooze" and not e.is_boss:
		for i in 2:
			var sp := spawn_enemy("ooze_small", e.position + Vector2(randf_range(-9, 9), randf_range(-6, 6)), 1.0, false, Color.WHITE)
			sp.awake = true
			sp.set_process(true)
	player.kills += 1
	chrono_gain(60.0 if e.is_boss else (18.0 if e.champ else 8.0))
	snd("kill")
	burst(e.position, Color(0.9, 0.85, 0.75), 18 if not e.is_boss else 70, 70.0, 0.6)
	burst(e.position, Color(0.7, 0.1, 0.2), 12, 50.0, 0.7)
	shake(10.0 if e.is_boss else 3.0)
	hitstop(0.12 if e.is_boss else 0.04)
	chain += 1
	chain_t = 5.5
	if chain == 5 or chain == 10 or chain == 20:
		say("SERIE x%d!" % chain)
		burst(player.position, Color(1.0, 0.75, 0.3), 24, 60.0, 0.6)
		snd("level")
	var gain0 := int(round(e.xp * e.souls_mult * (1.0 + 0.1 * player.r("fortuna") + 0.02 * player.a("fort") + 0.06 * player.rl("moneta")) * chain_mult() * (2.0 if player.zmode == 1 else 1.0)))
	run_souls_total += gain0
	drop(e.position, "soul", gain0)
	if true:
		if e.is_boss:
			drop_shard(e.position, e.kind)
		elif e.champ and randf() < 0.4:
			drop_shard(e.position, e.kind)
		elif e.elite and randf() < 0.08 and Spirit.DATA.has(e.kind):
			drop_shard(e.position, e.kind)
	player.mana = min(player.max_mana, player.mana + 2.5)
	player.focus = minf(100.0, player.focus + (3.0 if player.zmode > 0 else 0.5))
	if e.is_boss:
		maybe_drop(e.position, 1.0, [0, 0, 65, 35], 0.5)
		drop_relic(e.position)
		drop_relic(e.position)
	elif e.champ:
		maybe_drop(e.position, 0.2, [25, 50, 20, 5], 0.12)
		if randf() < 0.22:
			drop_relic(e.position)
	elif randf() < 0.012:
		maybe_drop(e.position, 1.0, [80, 17, 3, 0], 0.0)
	if not e.is_boss and not e.champ and randf() < 0.014:
		drop_relic(e.position)
	if player.rl("cenere") > 0 and randf() < 0.08 * player.rl("cenere"):
		burst(e.position, Color(0.95, 0.5, 0.2), 26, 80.0, 0.5)
		snd("slam")
		for en in enemies.duplicate():
			if en != e and en.position.distance_squared_to(e.position) < 2000.0:
				en.hurt(player.dmg() * 0.7, (en.position - e.position).normalized(), 90.0, false)
	if e.champ:
		burst(e.position, Color(1.0, 0.7, 0.3), 30, 70.0, 0.7)
		if randf() < 0.25:
			grant_graces(1, "BOTTINO: " + e.nm)
	player.hp = min(player.max_hp, player.hp + 0.4 + 2.0 * player.r("sangue") + 0.8 * player.rl("nodo"))
	if e.is_boss:
		persist["bosses"][e.kind] = true
		save_game()
		if run_mode:
			run_boss_alive = false
			run_stage += 1
			run_souls_total += 500
			player.hp = player.max_hp
			drop_relic(e.position)
			drop_relic(e.position)
			if e.kind == "vampire":
				end_run(true)
			else:
				say("CUSTODE SCONFITTO: LA VALLE TREMA")
		if e.kind == "vampire" and not run_mode:
			state = "win"
			over_t = 2.0
		elif e.kind in ["boss_wraith", "boss_gargoyle", "boss_forge"]:
			guardians += 1
			say("CUSTODE SCONFITTO  %d / 3" % guardians)
			if guardians >= 3:
				say("I TRE SIGILLI SI SPEZZANO: LA CRIPTA E' APERTA")
		else:
			grant_graces(2, "TROFEO: " + e.nm)
			for i in 6:
				drop(e.position, "soul", randi_range(60, 110))
	e.queue_free()


func game_over(_win: bool) -> void:
	if state == "dying":
		return
	state = "dying"
	arena_cancel()
	player.set_zmode(0)
	snd("death")
	death_t = 2.6
	player.spr.visible = false
	burst(player.position, Color(0.7, 0.05, 0.12), 40, 70.0, 0.9)
	shake(8.0)
	if stain != null:
		stain.queue_free()
		stain = null
	stain_data = {}
	if player.souls > 0 or player.relics.size() > 0:
		stain_data = {"area": area, "pos": player.position, "souls": player.souls, "relics": player.relics.duplicate()}
		make_stain()
	player.souls = 0
	player.relics = {}


func respawn() -> void:
	var lf_area: String = last_fire["area"]
	if lf_area != area:
		build_area(lf_area)
	state = "play"
	player.apply_stats()
	player.hp = player.max_hp
	player.st = player.max_st
	player.flasks = player.max_flasks
	player.inv = 1.2
	player.kb = Vector2.ZERO
	player.atk_t = 0.0
	player.heavy_t = 0.0
	player.dash_t = 0.0
	player.drink_t = 0.0
	player.spr.visible = true
	ensure_area(cell_pos(last_fire["cell"]), 2)
	player.position = cell_pos(last_fire["cell"]) + Vector2(0, 18)
	player.cam.reset_smoothing()
	spawn_all()
	say("TI SVEGLI ALL'ACCAMPAMENTO" if stain_data.get("relics", {}).size() == 0 else "TI SVEGLI ALL'ACCAMPAMENTO: LE RELIQUIE SONO NELLA MACCHIA")


func sleep_skip() -> void:
	if day_light() < 0.5:
		day_t = 0.27
	else:
		day_t = fposmod(day_t + 0.25, 1.0)
	set_weather("")
	weather_t = randf_range(60.0, 120.0)


func rest(p: Prop) -> void:
	if p.kind == "bonfire":
		light_bonfire(p)
	last_fire = {"area": area, "cell": p.cell}
	player.apply_stats()
	player.hp = player.max_hp
	player.st = player.max_st
	player.flasks = player.max_flasks
	if not run_mode:
		spawn_all()
	burst(p.position, Color(1, 0.8, 0.5), 14, 40.0, 0.7)
	snd("bonfire")
	state = "fade"
	var tws := create_tween()
	tws.tween_property(fade, "color:a", 1.0, 0.7)
	tws.tween_callback(sleep_skip)
	tws.tween_property(fade, "color:a", 0.0, 0.9)
	tws.tween_callback(func():
		state = "menu"
		say("HAI DORMITO: ORE %s" % day_clock()))
	save_game()


func try_level_up() -> void:
	if run_mode:
		say("SI SALE DI LIVELLO RACCOGLIENDO ANIME")
		return
	var c := Upgrades.cost(player.lv)
	if player.souls < c:
		say("ANIME INSUFFICIENTI")
		return
	picks = Stats.options(player.attr)
	if picks.is_empty():
		say("HAI RAGGIUNTO LA VETTA")
		return
	pick_sel = 0
	state = "pick"


func choose(i: int) -> void:
	if i >= picks.size():
		return
	if run_mode:
		run_apply_pick(picks[i])
		picks = []
		state = "play"
		snd("page")
		return
	var u: Dictionary = picks[i]
	player.souls -= Upgrades.cost(player.lv)
	player.lv += 1
	player.attr[u["id"]] = player.a(u["id"]) + 1
	player.apply_stats()
	player.hp = player.max_hp
	player.st = player.max_st
	player.flasks = player.max_flasks
	state = "menu"
	snd("level")
	picks = []
	save_game()
	if player.souls >= Upgrades.cost(player.lv):
		var keep := pick_sel
		try_level_up()
		pick_sel = clampi(keep, 0, maxi(0, picks.size() - 1))


func grant_grace() -> void:
	var l := Upgrades.roll(player.rk)
	if l.is_empty():
		drop(player.position, "soul", 500)
		return
	var u: Dictionary = l[0]
	player.rk[u["id"]] = player.r(u["id"]) + 1
	player.apply_stats()
	say("GRAZIA: %s  (%s)" % [u["n"], u["d"]])


func grant_graces(n: int, title: String) -> void:
	var names: Array = []
	for i in n:
		var l := Upgrades.roll(player.rk)
		if l.is_empty():
			drop(player.position, "soul", 500)
			continue
		var u: Dictionary = l[0]
		player.rk[u["id"]] = player.r(u["id"]) + 1
		names.append(u["n"])
	player.apply_stats()
	say(title + "  +  " + ", ".join(names))


func spawn_parrow(pos: Vector2, dir: Vector2, spd: float, d: float, lf: float, pr: int, col: Color, w: Dictionary, aoe: float, magic: bool) -> void:
	var a := PArrow.new()
	a.setup(self, dir, spd, d, lf, pr, col, w, aoe, magic)
	a.position = pos
	fx.add_child(a)


func add_bolt(a: Vector2, b: Vector2) -> void:
	var l := Line2D.new()
	l.width = 2.0
	l.default_color = Color(0.8, 0.9, 1.0)
	var pts := PackedVector2Array()
	pts.append(a)
	for i in range(1, 5):
		pts.append(a.lerp(b, i / 5.0) + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
	pts.append(b)
	l.points = pts
	fx.add_child(l)
	burst(b, Color(0.8, 0.9, 1.0), 8, 40.0, 0.3)
	var tw := create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.tween_callback(l.queue_free)


func drop_loot(pos: Vector2, item: Dictionary) -> void:
	if item.is_empty():
		return
	var icon: String = "w_tome"
	if item["k"] == "relic":
		icon = "relic_" + str(item["id"])
	elif item["k"] == "shard":
		icon = "soul"
	elif item["k"] == "a":
		icon = "ai_" + str(item["a"]["slot"])
	elif item["k"] != "tome":
		icon = Rpg.wicon(item)
	var p := Prop.new()
	var cc := Vector2i(floori(pos.x / Game.TS), floori(pos.y / Game.TS))
	p.setup_top(icon, cc, Vector2i(1, 1))
	p.position = Vector2(pos.x - 8.0, pos.y + 8.0)
	p.kind = "loot"
	p.item = item
	var col := Color(0.7, 0.4, 1.0)
	if item["k"] == "w":
		col = Rpg.RARITY[int(item["r"])]["c"]
	elif item["k"] == "relic":
		col = Color(1.0, 0.75, 0.35)
	elif item["k"] == "shard":
		col = Color(0.5, 0.95, 1.0)
		p.spr.scale = Vector2(1.7, 1.7)
		p.spr.modulate = Color(0.7, 1.0, 1.4)
	if item["k"] == "tome" or item["k"] == "relic" or item["k"] == "shard" or int(item.get("r", 0)) >= 1:
		Game.make_light(p, Vector2(8, -8), col, 0.9, 0.8)
	ents.add_child(p)
	props.append(p)


func drop_relic(pos: Vector2) -> void:
	drop_loot(pos + Vector2(randf_range(-8, 8), randf_range(2, 10)), {"k": "relic", "id": Relics.roll()})


func loot_tome() -> Dictionary:
	var pool: Array = []
	for s in Rpg.SPELLS.keys():
		if not player.known.has(s):
			pool.append(s)
	if pool.is_empty():
		return {}
	return {"k": "tome", "s": pool[randi() % pool.size()]}


## contenuto di uno scrigno: di solito anime e materiali; armi, reliquie e tomi sono rari
func chest_loot(p: Prop) -> void:
	var tier := 0
	if area == "world":
		tier = int(Game.BIO[biome_at(int(p.position.x / Game.TS), int(p.position.y / Game.TS))]["tier"])
	elif not dun.is_empty():
		tier = int(Game.BIO[int(dun.get("bio", 1))]["tier"])
	var gold: bool = p.rare
	var got: Array = []
	# anime (la moneta del gioco)
	var souls := int(randi_range(150, 300) if gold else randi_range(40, 90)) * (1.0 + 0.5 * tier)
	var parts := 5 if gold else 3
	for i in parts:
		drop(p.position + Vector2(randf_range(-6, 6), randf_range(2, 8)), "soul", maxi(1, int(souls) / parts))
	got.append("%d ANIME" % int(souls))
	# materiali per l'artigianato
	var kinds: Array = ["erba", "fungo", "legna", "minerale", "pelle", "osso"]
	kinds.shuffle()
	for i in (3 if gold else randi_range(1, 2)):
		var n := randi_range(2, 4) if gold else randi_range(1, 3)
		add_mat(str(kinds[i]), n)
		got.append("%d %s" % [n, str(kinds[i]).to_upper()])
	# a volte un consumabile
	if randf() < (0.5 if gold else 0.25):
		var it: String = ["arrosto", "infuso", "pelle", "forza", "fuoco"][randi() % 5]
		add_item(it, 1)
		got.append(it.to_upper())
	# oggetti rari
	if randf() < (0.4 if gold else 0.07):
		drop_loot(p.position + Vector2(randf_range(-6, 6), randf_range(2, 8)), Rpg.random_weapon([0, 70, 27, 3] if gold else [65, 30, 5, 0]))
		got.append("UN'ARMA")
	if randf() < (0.3 if gold else 0.04):
		drop_relic(p.position)
		got.append("UNA RELIQUIA")
	if randf() < (0.15 if gold else 0.03):
		var tm := loot_tome()
		if not tm.is_empty():
			drop_loot(p.position + Vector2(randf_range(-8, 8), randf_range(2, 10)), tm)
			got.append("UN TOMO")
	if gold and randf() < 0.25:
		grant_grace()
		return   # la grazia ha gia' il suo messaggio
	say(("SCRIGNO PREZIOSO: " if gold else "SCRIGNO: ") + ", ".join(got))


func maybe_drop(pos: Vector2, w_chance: float, weights: Array, tome_chance: float) -> void:
	if randf() < w_chance:
		drop_loot(pos + Vector2(randf_range(-6, 6), randf_range(2, 8)), Rpg.random_weapon(weights))
	if randf() < tome_chance:
		drop_loot(pos + Vector2(randf_range(-8, 8), randf_range(2, 10)), loot_tome())


func take_item(p: Prop) -> void:
	var it: Dictionary = p.item
	if it["k"] == "shard":
		bind_spirit(str(it["id"]))
	elif it["k"] == "relic":
		var rid: String = it["id"]
		relic_gain(rid, 1)
		var inf: Dictionary = Relics.info(rid)
		player.apply_stats()
		say("RELIQUIA: %s  x%d   %s%s" % [inf["n"], player.relic_own(rid), inf["d"], "" if player.relic_eq.has(rid) else "   (IN BORSA: INDOSSALA CON I)"])
		snd("level")
		save_game()
	elif it["k"] == "tome":
		var sp: String = it["s"]
		if not player.known.has(sp):
			player.known.append(sp)
		say("MAGIA APPRESA: %s   (al campo: Z / X per assegnarla)" % Rpg.SPELLS[sp]["n"])
		snd("level")
	elif it["k"] == "a":
		if player.bag_free() <= 0:
			say("BORSA PIENA: LIBERA SPAZIO CON I")
			return
		player.bag.append({"k": "a", "a": it["a"]})
		say("IN BORSA: %s" % str(it["a"]["n"]))
		snd("page")
	else:
		if player.wslots[1] == null:
			player.wslots[1] = it
			player.wcur = 1
			say("EQUIPAGGIATO: %s  [%s]" % [Rpg.wname(it), Rpg.RARITY[int(it["r"])]["n"]])
		elif player.bag_free() > 0:
			player.bag.append({"k": "w", "w": it})
			say("IN BORSA: %s  [%s]   (I PER EQUIPAGGIARE)" % [Rpg.wname(it), Rpg.RARITY[int(it["r"])]["n"]])
		else:
			say("BORSA PIENA: LIBERA SPAZIO CON I")
			return
		player.refresh_weapon()
		snd("page")
	props.erase(p)
	p.queue_free()


func cycle_spell(slot: int) -> void:
	var k: Array = player.known
	if k.size() < 2:
		return
	var other: String = player.spells[1 - slot]
	var i := k.find(player.spells[slot])
	for n in k.size():
		i = (i + 1) % k.size()
		if k[i] != other:
			player.spells[slot] = k[i]
			break
	snd("page")


# ------------------------------------------------------------------ modalita' Orda e Tattica
func spawn_allies() -> void:
	clear_allies()
	var n := mini(8, 2 + player.lv / 6)
	for i in n:
		var a := Ally.new()
		a.setup(self)
		a.idx = i
		a.count = n
		a.position = player.position + Vector2.from_angle(TAU * i / n) * 26.0
		ents.add_child(a)
		allies.append(a)
	burst(player.position, Color(0.5, 0.85, 1.0), 20, 60.0, 0.5)


func clear_allies() -> void:
	for a in allies:
		if is_instance_valid(a):
			burst(a.position, Color(0.5, 0.85, 1.0), 8, 40.0, 0.4)
			a.queue_free()
	allies.clear()


func order_rally(pos: Vector2) -> void:
	for a in allies:
		a.mode = "rally"
		a.rally = pos + Vector2(randf_range(-14, 14), randf_range(-14, 14))
	burst(pos, Color(0.6, 0.9, 1.0), 12, 40.0, 0.4)
	snd("page")


func order_follow() -> void:
	for a in allies:
		a.mode = "follow"
	snd("page")


## chi attaccano i nemici: il giocatore, o un alleato vicino
func pick_target(pos: Vector2) -> Node2D:
	if allies.is_empty():
		return player
	var best: Node2D = player
	var bd2 := pos.distance_squared_to(player.position)
	for a in allies:
		var d2 := pos.distance_squared_to(a.position)
		if d2 < bd2 and d2 < 4900.0:
			best = a
			bd2 = d2
	return best


func clear_horde() -> void:
	horde_age = 0.0
	for e in enemies.duplicate():
		if e.horde:
			burst(e.position, Color(0.8, 0.2, 0.3), 8, 40.0, 0.4)
			enemies.erase(e)
			e.queue_free()


func horde_update(real: float) -> void:
	if player.zmode != 1:
		return
	horde_age += real
	horde_t -= real
	if horde_t > 0.0:
		return
	horde_t = maxf(0.7, 1.6 - horde_age / 60.0)   # ondate sempre piu' fitte
	var alive := 0
	for e in enemies:
		if e.horde:
			alive += 1
	var cap := mini(110, 45 + int(horde_age / 3.0))
	if alive >= cap:
		return
	var pool: Array = []
	var tint := Color.WHITE
	if area == "world":
		var pc := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
		var b: Dictionary = Game.BIO[biome[idx(pc)] if inb(pc) else 1]
		pool = b["pool"]
		tint = b["tint"]
	else:
		pool = Game.BIO[int(dun.get("bio", 1))]["pool"]
	# a gruppi: ogni ondata arriva da una o due direzioni, appena fuori dallo schermo
	var n := mini(cap - alive, 6 + player.lv / 6 + int(horde_age / 15.0))
	var dirs: Array = [randf() * TAU]
	if n > 8:
		dirs.append(dirs[0] + PI + randf_range(-0.8, 0.8))
	for i in n:
		var a0: float = dirs[i % dirs.size()]
		for att in 12:
			var pos := player.position + Vector2.from_angle(a0 + randf_range(-0.6, 0.6)) * randf_range(250.0, 330.0)
			if att >= 8:
				pos = player.position + Vector2.from_angle(randf() * TAU) * randf_range(220.0, 320.0)
			if free_at(pos, 5.0):
				var e := spawn_enemy(pool[randi() % pool.size()], pos, 0.55, false, tint)
				e.horde = true
				e.dmg *= 0.75
				e.awake = true
				e.set_process(true)
				break


func spawn_hazard(pos: Vector2, r: float, delay: float, life: float, d: float, tick: float, col: Color, slow := 0.0) -> void:
	var h := Hazard.new()
	h.setup(self, r, delay, life, d, tick, col, slow)
	h.position = pos
	fx.add_child(h)


func chain_mult() -> float:
	return minf(3.0, 1.0 + 0.1 * chain)


func chain_break() -> void:
	chain = 0
	chain_t = 0.0


func add_champion(c: Vector2i, extra := 1.0) -> void:
	var bi: int = biome[idx(c)] if area == "world" else int(dun["bio"])
	var pool: Array = CHAMP_POOL[bi]
	if pool.is_empty():
		return
	var cc := free_near(c)
	var dist := Vector2(cc).distance_to(Vector2(SEEDS[0])) / WS if area == "world" else 20.0
	spawns.append({"k": pool[pop_rng.randi() % pool.size()], "pos": cell_pos(cc),
		"mult": (1.0 + int(Game.BIO[bi]["tier"]) * 0.2) * extra, "elite": false, "tint": Color.WHITE})


func snd(n: String) -> void:
	if sfx_node != null:
		sfx_node.play(n)


func interact(p) -> void:
	match p.kind:
		"res_erba", "res_fungo", "res_legna", "res_minerale":
			gather(p)
		"villager":
			open_dialog(p)
		"qitem":
			var qq: String = p.item.get("qid", "")
			if quest_state(qq) == "active":
				qp()[qq]["p"] = 1
				props.erase(p)
				p.queue_free()
				snd("page")
				say("HAI RITROVATO L'OGGETTO: TORNA DA CHI TE L'HA CHIESTO")
				save_game()
			else:
				say("UN FAGOTTO ABBANDONATO. NON SAI COSA FARNE")
		"bonfire":
			rest(p)
		"dig":
			dig_up(p)
		"bed_top":
			rest(p)
		"elder":
			say(LORE[elder_i % LORE.size()])
			elder_i += 1
			if journey_step() == 0 and persist["bosses"].has("boss_jailer"):
				journey_advance("L'ANZIANO: FUORI C'E' PIU' DI QUEL CHE VEDI. CERCA I DIARI: RACCONTANO COME FINI' TUTTO", 60, 0, 0)
		"npc":
			talk(p)
		"loot":
			take_item(p)
		"door":
			returns[p.dest] = p.cell
			change_area(p.dest)
		"exit":
			change_area("world")
		"gate_top":
			gate_try(p)
		"stairs_top":
			use_stairs(p)
		"bell":
			for a in arenas:
				if a["def"]["mode"] == "bell" and (a["pos"] as Vector2).distance_to(p.position) < 40.0:
					if a["done"]:
						say("LA CAMPANA TACE")
					elif a["active"]:
						say("LA SFIDA E' GIA' IN CORSO")
					else:
						arena_start(a)
		"shrine":
			var cost: int = int(p.item.get("cost", 200))
			if p.opened:
				say("L'ALTARE E' GIA' SAZIO")
			elif player.souls < cost:
				say("OFFERTA INSUFFICIENTE: SERVONO %d ANIME" % cost)
			else:
				player.souls -= cost
				p.opened = true
				persist["opened"][key(p.cell)] = true
				p.spr.modulate = Color(0.5, 0.5, 0.6)
				snd("buy")
				burst(p.position, Color(0.5, 0.7, 1.0), 24, 60.0, 0.6)
				drop_relic(p.position + Vector2(0, 8))
				say("L'ALTARE ACCETTA L'OFFERTA")
				save_game()
		"key":
			persist["opened"]["key:sigilli"] = true
			props.erase(p)
			block.erase(p.cell)
			p.queue_free()
			snd("level")
			say("HAI TROVATO LA CHIAVE DEI SIGILLI")
			save_game()
		"lever":
			if not persist["opened"].has("lever:sanat"):
				persist["opened"]["lever:sanat"] = true
				p.spr.modulate = Color(0.6, 0.6, 0.7)
				p.spr.flip_h = true
				snd("slam")
				say("UN CLANGORE LONTANO: I CANCELLI DEL SANATORIO SI APRONO")
				save_game()
			else:
				say("LA LEVA E' GIA' ABBASSATA")
		"portal":
			if p.dest == "world" and area == "d0" and not persist["bosses"].has("boss_jailer"):
				say("LA PORTA E' SBARRATA: IL CARCERIERE TIENE LA CHIAVE")
				return
			if p.dest == "dF" and guardians < 3:
				say("SIGILLATO: SCONFIGGI I TRE CUSTODI  (%d / 3)" % guardians)
			else:
				change_area(p.dest)


func change_area(dest: String) -> void:
	if state != "play":
		return
	state = "fade"
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.35)
	tw.tween_callback(_do_change.bind(dest))
	tw.tween_property(fade, "color:a", 0.0, 0.4)
	tw.tween_callback(func(): if state == "fade": state = "play")


func _do_change(dest: String) -> void:
	var prev := area
	build_area(dest)
	if dest == "world":
		if prev == "d0":
			last_fire = {"area": "world", "cell": SEEDS[0] + Vector2i(3, 0)}
		var c: Vector2i = returns.get(prev, SEEDS[0])
		ensure_area(cell_pos(c), 2)
		player.position = cell_pos(free_near(c + Vector2i(0, 1)))
		for d in doors:
			if d["dest"] == prev:
				lock_pos = d["pos"]
		say(Game.BIO[biome[idx(c)]]["n"])
	elif dest.begins_with("int|"):
		player.position = cell_pos(exit_cell) + Vector2(0, -20)
		say(dun["n"])
	else:
		player.position = Vector2(center(rooms[0])) * Game.TS + Vector2(8, 36)
		say(dun["n"])
	player.cam.reset_smoothing()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	for k in settings.keys():
		if cfg.has_section_key("game", k):
			settings[k] = cfg.get_value("game", k)
	if cfg.has_section_key("video", "fullscreen"):
		settings["full"] = bool(cfg.get_value("video", "fullscreen"))


func save_settings() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		return
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("game", k, settings[k])
	cfg.save("user://settings.cfg")


func apply_settings() -> void:
	if OS.get_cmdline_user_args().size() == 0:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings["full"] else DisplayServer.WINDOW_MODE_WINDOWED)
	var mv: float = float(settings["master"]) / 10.0
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(mv, 0.0001)))
	AudioServer.set_bus_mute(0, mv <= 0.0)
	if sfx_node != null:
		sfx_node.set_levels(float(settings["sfx"]) / 10.0, float(settings["amb"]) / 10.0)
	show_fps = bool(settings["fps"])
	if Game.photo != bool(settings.get("photo", false)):
		Game.photo = bool(settings.get("photo", false))
		Game._cache.clear()


func set_fullscreen(on: bool) -> void:
	settings["full"] = on
	apply_settings()
	save_settings()


func opt_change(dir: int) -> void:
	var o: Dictionary = OPTIONS[opt_sel]
	var k: String = o["k"]
	if o["t"] == "toggle":
		settings[k] = not bool(settings[k])
	elif o["t"] == "slider":
		settings[k] = clampi(int(settings[k]) + dir, 0, int(o["max"]))
	else:
		return
	apply_settings()
	save_settings()
	if k == "photo" and area != "" and player != null:
		# la grafica cambia ricaricando: si salva e si torna al titolo (CONTINUA riprende da qui)
		save_game()
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return
	if k == "sfx" or k == "master":
		snd("hit")
	else:
		snd("page")


func opt_activate() -> void:
	var o: Dictionary = OPTIONS[opt_sel]
	match o["k"]:
		"ctrl":
			ctrl_from = "options"
			state = "controls"
		"back":
			state = opt_from
			if opt_from == "title":
				in_title_menu = false
		_:
			opt_change(1)


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		if ev.keycode == KEY_F11 or (ev.keycode == KEY_ENTER and ev.alt_pressed):
			set_fullscreen(not fs)
			get_viewport().set_input_as_handled()
			return
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F3:
		show_fps = not show_fps
		settings["fps"] = show_fps
		save_settings()
	if ev is InputEventJoypadButton or (ev is InputEventJoypadMotion and absf(ev.axis_value) > 0.25):
		use_pad = true
	elif ev is InputEventKey or ev is InputEventMouseButton or ev is InputEventMouseMotion:
		use_pad = false


func _activate_pause_selection() -> void:
	match pause_sel:
		0:
			state = "play"
		1:
			state = "play"
			open_map()
		2:
			open_bestiary()
		3:
			opt_from = "pause"
			opt_sel = 0
			in_title_menu = false
			state = "options"
		4:
			ctrl_from = "pause"
			state = "controls"
		5:
			save_game()
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		_:
			save_game()
			get_tree().quit()


func _activate_title_selection() -> void:
	if run_mode:
		match title_sel:
			0:
				state = "class"
			1:
				opt_from = "title"
				opt_sel = 0
				in_title_menu = true
				state = "options"
			_:
				get_tree().quit()
	else:
		match title_sel:
			0:
				start_game(title_save)
			1:
				state = "class"
			3:
				launch_editor()
			_:
				opt_from = "title"
				opt_sel = 0
				in_title_menu = true
				state = "options"


func _handle_menu_click(pos: Vector2) -> bool:
	if state == "options":
		if pos.x < 80.0 or pos.x > 400.0:
			return false
		var row := floori((pos.y - 63.0) / 14.0)
		if row < 0 or row >= OPTIONS.size() or pos.y >= 75.0 + row * 14.0:
			return false
		opt_sel = row
		var option: Dictionary = OPTIONS[row]
		if option["t"] == "slider":
			var max_value := int(option["max"])
			var x0 := 80.0 + (320.0 - 20.0 - max_value * 8.0)
			var value := clampi(floori((pos.x - x0) / 8.0) + 1, 0, max_value)
			settings[option["k"]] = value
			apply_settings()
			save_settings()
			snd("page")
		elif option["t"] == "toggle":
			opt_change(1)
		else:
			opt_activate()
		return true
	if state == "pause":
		var row := floori((pos.y - 106.0) / 14.0)
		if pos.x < 130.0 or pos.x > 350.0 or row < 0 or row >= 7 or pos.y >= 122.0 + row * 14.0:
			return false
		pause_sel = row
		_activate_pause_selection()
		return true
	if state == "title":
		var count := 3 if run_mode else 4
		var row := floori((pos.y - 135.0) / 16.0)
		if pos.x < 90.0 or pos.x > 390.0 or row < 0 or row >= count or pos.y >= 151.0 + row * 16.0:
			return false
		title_sel = row
		_activate_title_selection()
		return true
	if state == "class":
		if pos.y < 36.0 or pos.y > 252.0 or pos.x < 8.0 or pos.x >= 472.0:
			return false
		class_sel = clampi(floori((pos.x - 8.0) / 116.0), 0, 3)
		start_game({}, class_ids[class_sel])
		return true
	if state == "pick" and not run_mode:
		var ri := floori((pos.y - 46.0) / 20.0)
		if pos.x < 20.0 or pos.x > 300.0 or ri < 0 or ri >= picks.size():
			return false
		pick_sel = ri
		choose(ri)
		return true
	if state == "pick":
		if pos.y < 52.0 or pos.y > 202.0 or pos.x < 14.0 or pos.x > 466.0:
			return false
		var row := floori((pos.x - 14.0) / 154.0)
		if row < 0 or row >= picks.size() or pos.x >= 160.0 + row * 154.0:
			return false
		choose(row)
		return true
	if state == "travel":
		if pos.x < 90.0 or pos.x > 390.0 or pos.y < 70.0 or pos.y >= 214.0:
			return false
		var first := clampi(travel_sel - 6, 0, maxi(0, travel_list.size() - 12))
		var row := floori((pos.y - 70.0) / 12.0)
		var index := first + row
		if index < 0 or index >= travel_list.size():
			return false
		travel_sel = index
		travel_to(travel_list[index])
		return true
	if state == "craft":
		# schede in alto; righe delle scelte a sinistra (meta' sinistra = indietro, destra = avanti); CREA sotto
		if pos.y >= 70.0 and pos.y < 84.0 and pos.x >= 84.0 and pos.x < 84.0 + 62.0 * Forge.TABS.size():
			craft_tab = clampi(floori((pos.x - 84.0) / 62.0), 0, Forge.TABS.size() - 1)
			craft_row = 0
			return true
		var nsl: int = Forge.slots(craft_tab).size()
		var ri := floori((pos.y - 86.0) / 14.0)
		if pos.x >= 84.0 and pos.x < 250.0 and ri >= 0 and ri < nsl:
			craft_row = ri + 1
			craft_step(1 if pos.x >= 190.0 else -1)
			return true
		if pos.x >= 84.0 and pos.x < 250.0 and ri == nsl:
			craft_row = nsl + 1
			craft_make()
			return true
		return false
	if state == "controls":
		state = ctrl_from
		return true
	if state == "dialog":
		if pos.y < 230.0 or pos.y > 254.0:
			return false
		var option_index := floori((pos.x - 32.0) / 120.0)
		var dialog_options: Array = dlg.get("opts", [])
		if option_index < 0 or option_index >= dialog_options.size():
			return false
		dlg["sel"] = option_index
		dialog_confirm()
		return true
	if state == "menu":
		if pos.x < 90.0 or pos.x > 390.0:
			return false
		if pos.y >= 108.0 and pos.y < 126.0:
			try_level_up()
		elif pos.y >= 126.0 and pos.y < 137.0:
			if pos.x < 250.0:
				state = "play"
			else:
				craft_sel = 0
				state = "craft"
				snd("page")
		elif pos.y >= 137.0 and pos.y < 148.0:
			open_travel()
		elif pos.y >= 148.0 and pos.y < 160.0:
			cycle_spell(0 if pos.x < 240.0 else 1)
		else:
			return false
		return true
	if state == "results":
		Engine.time_scale = 1.0
		get_tree().reload_current_scene()
		return true
	return false


## apre l'editor di sviluppo (CryptEditor.exe accanto al gioco). Voce nascosta: F10 in qualsiasi momento, e voce nel menu del titolo
func launch_editor() -> void:
	var exe_dir := OS.get_executable_path().get_base_dir()
	for c in [exe_dir.path_join("CryptEditor.exe"), exe_dir.path_join("editor/CryptEditor.exe"), exe_dir.path_join("../build/CryptEditor.exe")]:
		if FileAccess.file_exists(c):
			OS.create_process(c, ["--", "--gameexe=" + OS.get_executable_path()])
			return
	OS.alert("CryptEditor.exe non trovato accanto al gioco.", "Editor")


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F10:
		launch_editor()
		return
	if ev is InputEventJoypadButton and ev.button_index == JOY_BUTTON_BACK and state == "play":
		if ev.pressed:
			inv_back_t = 0.0
			inv_back_used = false
		else:
			if not inv_back_used:
				if inv_open:
					inv_toggle()
				else:
					item_cycle()
			inv_back_t = -1.0
		return
	if inv_open:
		if state != "play":
			inv_open = false
		elif inv_input(ev):
			get_viewport().set_input_as_handled()
			return
	if state == "play" and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_I:
		inv_toggle()
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _handle_menu_click(ev.position - hud.position):
			get_viewport().set_input_as_handled()
			return
	if state == "dialog":
		var n: int = (dlg["opts"] as Array).size()
		if ev.is_action_pressed("ui_left") or ev.is_action_pressed("ui_up"):
			dlg["sel"] = (int(dlg["sel"]) + n - 1) % n
		elif ev.is_action_pressed("ui_right") or ev.is_action_pressed("ui_down"):
			dlg["sel"] = (int(dlg["sel"]) + 1) % n
		elif (ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton)) or ev.is_action_pressed("interact"):
			dialog_confirm()
		elif ev.is_action_pressed("ui_cancel"):
			dialog_close()
		return
	if state == "results":
		if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventJoypadButton and ev.pressed):
			Engine.time_scale = 1.0
			get_tree().reload_current_scene()
		return
	if state == "story":
		if (ev is InputEventKey and ev.pressed and not ev.echo) or (ev is InputEventJoypadButton and ev.pressed) or (ev is InputEventMouseButton and ev.pressed):
			state = "play"
			snd("page")
		return
	if state == "bestiary":
		var n := Bestiary.ENTRIES.size()
		if ev.is_action_pressed("ui_right"):
			beast_sel = (beast_sel + 1) % n
		elif ev.is_action_pressed("ui_left"):
			beast_sel = (beast_sel + n - 1) % n
		elif ev.is_action_pressed("ui_down"):
			beast_sel = mini(n - 1, beast_sel + 8)
		elif ev.is_action_pressed("ui_up"):
			beast_sel = maxi(0, beast_sel - 8)
		elif (ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_B or ev.keycode == KEY_ESCAPE)) or ev.is_action_pressed("ui_cancel") \
				or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START):
			state = "play"
			snd("page")
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			var cp: Vector2 = hud.get_local_mouse_position()
			var ci := floori((cp.x - 14.0) / 27.0)
			var ri := floori((cp.y - 34.0) / 27.0)
			if ci >= 0 and ci < 8 and ri >= 0 and ri * 8 + ci < n:
				beast_sel = ri * 8 + ci
		return
	if state == "map":
		if (ev is InputEventKey and ev.pressed and not ev.echo and (ev.keycode == KEY_M or ev.keycode == KEY_ESCAPE)) or ev.is_action_pressed("ui_cancel") \
				or (ev is InputEventJoypadButton and ev.pressed and ev.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK]):
			state = "play"
			snd("page")
		elif ev.is_action_pressed("interact") or (ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton)) \
				or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			map_zoom = 1 - map_zoom
			map_pan = Vector2.ZERO
			snd("page")
		return
	if state == "play":
		if (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE) or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START):
			state = "pause"
			pause_sel = 0
			snd("page")
		elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_M and not inv_open:
			open_map()
		elif ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_B and not inv_open:
			open_bestiary()
		return
	if state == "pause":
		if ev.is_action_pressed("ui_down"):
			pause_sel = (pause_sel + 1) % 7
		elif ev.is_action_pressed("ui_up"):
			pause_sel = (pause_sel + 6) % 7
		elif ev.is_action_pressed("ui_cancel") or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_START):
			state = "play"
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			_activate_pause_selection()
		return
	if state == "options":
		if ev.is_action_pressed("ui_down"):
			opt_sel = (opt_sel + 1) % OPTIONS.size()
		elif ev.is_action_pressed("ui_up"):
			opt_sel = (opt_sel + OPTIONS.size() - 1) % OPTIONS.size()
		elif ev.is_action_pressed("ui_left"):
			opt_change(-1)
		elif ev.is_action_pressed("ui_right"):
			opt_change(1)
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			opt_activate()
		elif ev.is_action_pressed("ui_cancel"):
			state = opt_from
			if opt_from == "title":
				in_title_menu = false
		return
	if state == "controls":
		if ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("ui_accept"):
			state = ctrl_from
		return
	if state == "title":
		if ev.is_action_pressed("ui_down"):
			title_sel = (title_sel + 1) % (3 if run_mode else 4)
		elif ev.is_action_pressed("ui_up"):
			title_sel = (title_sel + (2 if run_mode else 3)) % (3 if run_mode else 4)
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton) and run_mode:
			_activate_title_selection()
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			_activate_title_selection()
		return
	if state == "class":
		if ev.is_action_pressed("ui_right"):
			class_sel = (class_sel + 1) % 4
		elif ev.is_action_pressed("ui_left"):
			class_sel = (class_sel + 3) % 4
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			start_game({}, class_ids[class_sel])
		elif ev.is_action_pressed("ui_cancel") and has_save():
			state = "title"
		return
	if state == "travel":
		if ev.is_action_pressed("ui_down") or ev.is_action_pressed("move_down"):
			travel_sel = (travel_sel + 1) % travel_list.size()
		elif ev.is_action_pressed("ui_up") or ev.is_action_pressed("move_up"):
			travel_sel = (travel_sel - 1 + travel_list.size()) % travel_list.size()
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			travel_to(travel_list[travel_sel])
		elif ev.is_action_pressed("ui_cancel"):
			state = "menu"
		return
	if state == "craft":
		var nrow: int = Forge.slots(craft_tab).size() + 2
		if ev.is_action_pressed("ui_up"):
			craft_row = (craft_row + nrow - 1) % nrow
		elif ev.is_action_pressed("ui_down"):
			craft_row = (craft_row + 1) % nrow
		elif ev.is_action_pressed("ui_left"):
			craft_step(-1)
		elif ev.is_action_pressed("ui_right"):
			craft_step(1)
		elif (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_Q) or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_LEFT_SHOULDER):
			craft_tab = (craft_tab + Forge.TABS.size() - 1) % Forge.TABS.size()
			craft_row = mini(craft_row, Forge.slots(craft_tab).size() + 1)
		elif (ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_E) or (ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_RIGHT_SHOULDER):
			craft_tab = (craft_tab + 1) % Forge.TABS.size()
			craft_row = mini(craft_row, Forge.slots(craft_tab).size() + 1)
		elif ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			# si crea solo sulla riga CREA; sulle altre righe A/INVIO scorre la scelta
			if craft_row == Forge.slots(craft_tab).size() + 1:
				craft_make()
			else:
				craft_step(1)
		elif ev.is_action_pressed("ui_cancel"):
			state = "menu"
		return
	if state == "menu":
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_C:
			craft_row = 0
			state = "craft"
			snd("page")
			return
		if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_X:
			craft_row = 0
			state = "craft"
			snd("page")
			return
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_T:
			open_travel()
			return
		if ev is InputEventJoypadButton and ev.pressed:
			if ev.button_index == JOY_BUTTON_Y:
				open_travel()
			elif ev.button_index == JOY_BUTTON_LEFT_SHOULDER:
				cycle_spell(0)
			elif ev.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				cycle_spell(1)
			if ev.button_index in [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
				return
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_Z:
			cycle_spell(0)
			return
		if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_X:
			cycle_spell(1)
			return
		if ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			try_level_up()
		elif ev.is_action_pressed("ui_cancel") or ev.is_action_pressed("interact"):
			state = "play"
	elif state == "pick":
		if ev.is_action_pressed("ui_left") or (not run_mode and ev.is_action_pressed("ui_up")):
			pick_sel = (pick_sel + picks.size() - 1) % picks.size()
			return
		if ev.is_action_pressed("ui_right") or (not run_mode and ev.is_action_pressed("ui_down")):
			pick_sel = (pick_sel + 1) % picks.size()
			return
		if ev.is_action_pressed("ui_accept") and not (ev is InputEventMouseButton):
			choose(pick_sel)
			return
		if ev.is_action_pressed("ui_cancel"):
			if not run_mode:
				state = "menu"
			return
		if ev is InputEventKey and ev.pressed and not ev.echo:
			if ev.keycode >= KEY_1 and ev.keycode <= KEY_7 and ev.keycode - KEY_1 < picks.size():
				choose(ev.keycode - KEY_1)
			elif ev.keycode == KEY_ESCAPE and not run_mode:
				state = "menu"


func nearest_enemy(pos: Vector2, max_d: float) -> Enemy:
	var best: Enemy = null
	var bd := max_d
	for e in enemies:
		var d: float = e.position.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best


# ------------------------------------------------------------------ ciclo
func _selftest() -> void:
	tf += 1
	match tf:
		30:
			print("T world props=", props.size(), " spawns=", spawns.size(), " enemies=", enemies.size())
			player.position = cell_pos(SEEDS[1] + Vector2i(0, 3))
		60:
			player.position = cell_pos(SEEDS[2] + Vector2i(-3, 1))
		90:
			player.position = cell_pos(SEEDS[3] + Vector2i(0, 2))
		120:
			player.position = cell_pos(SEEDS[4] + Vector2i(0, 1))
		150:
			player.position = cell_pos(SEEDS[5] + Vector2i(4, 5))
		180:
			state = "play"
			change_area("d1")
		260:
			print("T dungeon area=", area, " rooms=", rooms.size(), " enemies=", enemies.size(), " state=", state)
			var pc: Prop = null
			for p in props:
				if p.kind == "portal":
					pc = p
			interact(pc)
		340:
			print("T back area=", area, " state=", state)
			get_tree().quit()


var t2 := 0


func _selftest2() -> void:
	t2 += 1
	match t2:
		10:
			var kinds := {}
			for p in props:
				kinds[p.kind] = kinds.get(p.kind, 0) + 1
			print("T2 props ", kinds)
		20:
			player.souls = 2000
			for p in props:
				if p.kind == "npc" and p.npc_id == "becchino":
					for i in 4:
						talk(p)
			print("T2 npc rk=", player.rk, " souls=", player.souls)
		30:
			for p in props:
				if p.kind == "page":
					player.position = p.position
					break
		40:
			print("T2 pagine=", pages_found)
		50:
			var fires: Array = []
			for p in props:
				if p.kind == "bonfire":
					fires.append(p)
			rest(fires[1])
			state = "play"
			print("T2 falo accesi=", persist["fires"].size())
		60:
			state = "menu"
			open_travel()
			print("T2 viaggio state=", state, " voci=", travel_list.size())
			state = "play"
			travel_to(travel_list[1])
		120:
			print("T2 dopo viaggio state=", state, " area=", area)
			change_area("d4")
		200:
			print("T2 area=", area, " boss=", boss_kind, " nemici=", enemies.size())
			for e in enemies.duplicate():
				if e.is_boss:
					enemy_died(e)
		210:
			print("T2 dopo boss rk=", player.rk, " msg=", msg)
			get_tree().quit()


var t3 := 0


func _selftest3() -> void:
	t3 += 1
	match t3:
		10:
			var kinds := {}
			var champs := 0
			for s in spawns:
				kinds[s["k"]] = kinds.get(s["k"], 0) + 1
			for e in enemies:
				if e.champ:
					champs += 1
			print("T3 tipi=", kinds.size(), " campioni=", champs, " ", kinds)
		20:
			player.max_hp = 99999.0
			player.hp = 99999.0
			var all := ["knight_fallen", "reaper", "summoner", "abomination", "frost_mage", "berserker", "plague_doc",
				"zombie", "skel_archer", "rat", "imp", "wisp", "toad", "wolf", "crow"]
			for i in all.size():
				var e: Enemy = spawn_enemy(all[i], player.position + Vector2.from_angle(i * 0.42) * 60.0, 1.0)
				e.awake = true
			print("T3 spawnati ", enemies.size())
		150:
			print("T3 hazard attivi=", fx.get_children().size(), " hp=", int(player.hp))
		200:
			player.lv = 7
			player.rk = {"vigor": 2, "forza": 1}
			player.souls = 123
			testing = false
			save_game()
			var d := load_save()
			print("T3 salvato lv=", d["player"]["lv"], " seed=", d["seed"], " fires=", d["persist"]["fires"].size())
			player.lv = 1
			player.rk = {}
			player.attr = {}
			player.armor = {}
			player.brews = {}
			start_game(d)
			print("T3 ricaricato lv=", player.lv, " rk=", player.rk, " souls=", player.souls, " area=", area)
			testing = true
		230:
			new_cycle()
			print("T3 ciclo=", cycle, " lv=", player.lv, " stato=", state, " nemici=", enemies.size())
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			get_tree().quit()


var t4 := 0
var t4ms := 0


func _selftest4() -> void:
	t4 += 1
	match t4:
		10:
			for id in class_ids:
				player.set_class(id)
				print("T4 classe ", id, " arma=", Rpg.wname(player.weapon()), " spell=", player.spells, " hp=", int(player.max_hp), " mana=", int(player.max_mana))
			player.set_class("negromante")
			player.max_hp = 99999.0
			player.hp = 99999.0
			player.mana = 999.0
			player.max_mana = 999.0
		20:
			for i in 8:
				var e: Enemy = spawn_enemy("skeleton", player.position + Vector2.from_angle(i * 0.8) * 40.0, 1.0)
				e.awake = true
			for id in Rpg.SPELLS.keys():
				player.known.append(id)
				player.spells[0] = id
				player.spell_cd[0] = 0.0
				player.cast(0)
			print("T4 magie lanciate, nemici=", enemies.size(), " mana=", int(player.mana))
		60:
			drop_loot(player.position + Vector2(0, 14), Rpg.make_weapon(3, "greatsword"))
			drop_loot(player.position + Vector2(8, 14), {"k": "tome", "s": "gelo"})
		70:
			var n := 0
			for p in props.duplicate():
				if p.kind == "loot":
					take_item(p)
					n += 1
			print("T4 loot presi=", n, " slots=", player.wslots, " known=", player.known.size())
			player.wcur = 0
			Input.action_press("swap")
		75:
			Input.action_release("swap")
			player.fire(player.weapon(), Rpg.FAM[player.weapon()["f"]], true)
			print("T4 arma attuale=", Rpg.wname(player.weapon()), " desc=", Rpg.wdesc(player.weapon()))
		80:
			var door: Prop = null
			for p in props:
				if p.kind == "door":
					door = p
					if p.dest.begins_with("int|chapel") or p.dest.begins_with("int|smithy"):
						break
			print("T4 porta ", door.dest if door != null else "nessuna")
			player.position = door.position + Vector2(0, 8)
			state = "play"
			t4ms = Time.get_ticks_msec()
			interact(door)
		160:
			print("T4 interno area=", area, " stanze=", rooms.size(), " nemici=", enemies.size(), " props=", props.size(), " state=", state)
			var kinds := {}
			for p in props:
				kinds[p.kind] = kinds.get(p.kind, 0) + 1
			print("T4 interno props ", kinds)
		170:
			t4ms = Time.get_ticks_msec()
			state = "play"
			interact(props.filter(func(p): return p.kind == "exit")[0])
		260:
			print("T4 uscito area=", area, " state=", state)
			get_tree().quit()


var t5 := 0


func _selftest5() -> void:
	t5 += 1
	if t5 == 10:
		var dests: Array = []
		for p in props:
			if p.kind == "door":
				dests.append(p.dest)
		var worst := 1.0
		var ok := 0
		for d in dests:
			build_area(d)
			var r := interior_ratio()
			worst = minf(worst, r)
			if r >= 0.98:
				ok += 1
		print("T5 interni=", dests.size(), " raggiungibili>=98%=", ok, " peggiore=", snappedf(worst, 0.01))
		get_tree().quit()


var t6 := 0


func _selftest6() -> void:
	t6 += 1
	if t6 == 10:
		player.souls = 9999
		player.rk = {"vigor": 2, "forza": 1, "mente": 1}
		for p in props:
			if p.kind == "bonfire":
				rest(p)
				break
	if t6 == 40:
		try_level_up()
	if t6 == 70:
		get_tree().quit()


var t7 := 0


func _selftest7() -> void:
	t7 += 1
	match t7:
		10:
			print("T7 ingressi=", doors.size())
			var d: Dictionary = doors[3]
			player.position = (d["pos"] as Vector2) + Vector2(0, 6)
		70:
			print("T7 dopo contatto area=", area, " state=", state)
			player.position = cell_pos(exit_cell) + Vector2(0, 2)
		150:
			print("T7 dopo uscita area=", area, " state=", state)
		230:
			print("T7 ancora fuori area=", area)
			get_tree().quit()


var t8 := 0


func _selftest8() -> void:
	t8 += 1
	if t8 == 10:
		var dests: Array = []
		for d in doors:
			dests.append(d["dest"])
		var worst := 1.0
		var ok := 0
		var furn_n := 0
		for dn in dests:
			build_area(dn)
			var rr := interior_ratio()
			worst = minf(worst, rr)
			furn_n += furn.size()
			if rr >= 0.98:
				ok += 1
		print("T8 pad: sinistra=", InputMap.action_get_events("move_left").size(), " attacco=", InputMap.action_get_events("attack").size(), " pesante=", InputMap.action_get_events("heavy").size(), " rotola=", InputMap.action_get_events("dash").size(), " magia2=", InputMap.action_get_events("spell2").size())
		print("T8 interni=", dests.size(), " ok=", ok, " peggiore=", snappedf(worst, 0.01), " mobili medi=", furn_n / maxi(1, dests.size()))
		var tipi := {}
		for dn in dests:
			var tp: String = str(dn).split("|")[1]
			tipi[tp] = tipi.get(tp, 0) + 1
		print("T8 tipi ", tipi)
		var pick: String = ""
		for dn in dests:
			if str(dn).begins_with("int|house") and pick == "":
				pick = dn
		build_area(pick)
		player.position = cell_pos(exit_cell) + Vector2(0, -20)
	if t8 == 40:
		get_tree().quit()


var pf_nofog := false
var tpf := 0
var pf_t0 := 0
var pf_lights: Array = []
var pf_parts: Array = []
var pf_ground: Array = []


func _set_cfg(lights_on: bool, parts_on: bool, ground_on: bool) -> void:
	for l in pf_lights:
		if is_instance_valid(l) and l != player.light:
			l.visible = lights_on
	for p in pf_parts:
		if is_instance_valid(p):
			p.visible = parts_on
			p.emitting = parts_on
	for g in pf_ground:
		if is_instance_valid(g):
			g.visible = ground_on


func _perf() -> void:
	tpf += 1
	if tpf == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		pf_lights = get_tree().root.find_children("*", "PointLight2D", true, false)
		pf_parts = get_tree().root.find_children("*", "CPUParticles2D", true, false)
		if wr_node != null:
			pf_ground = wr_node.get_children().filter(func(c): return c is ColorRect)
		print("PERF luci=", pf_lights.size(), " particelle=", pf_parts.size(), " chunk terreno=", pf_ground.size(), " nodi=", get_tree().get_node_count(), " nemici=", enemies.size())
	var phases := [
		["villaggio", 0, true, true, true],
		["foresta", 2, true, true, true],
		["cattedrale", 4, true, true, true],
		["forge (magma)", 6, true, true, true],
		["palude", 3, true, true, true],
		["vetta", 5, true, true, true],
	]
	var seg := 150
	var idx_p := (tpf - 1) / seg
	var local := (tpf - 1) % seg
	if idx_p >= phases.size():
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("--perfdiag"):
		phases = [["base", 0, true, true, true], ["senza luci", 0, false, true, true], ["senza particelle", 0, true, false, true],
			["senza terreno", 0, true, true, false], ["senza nebbia", 0, true, true, true], ["tutto spento", 0, false, false, false]]
	var ph: Array = phases[idx_p] if idx_p < phases.size() else phases[0]
	pf_nofog = str(ph[0]) == "senza nebbia" or str(ph[0]) == "tutto spento"
	if local == 0:
		_set_cfg(ph[2], ph[3], ph[4])
		pf_t0 = 0
		player.position = cell_pos(SEEDS[int(ph[1])] + Vector2i(0, 3))
		player.cam.reset_smoothing()
	if local == 40:
		pf_t0 = Time.get_ticks_usec()
	if local == seg - 1 and pf_t0 > 0:
		var ms := (Time.get_ticks_usec() - pf_t0) / 1000.0 / float(seg - 40)
		print("PERF ", ph[0], ": ", snappedf(ms, 0.01), " ms/frame = ", int(1000.0 / maxf(ms, 0.01)), " fps  drawcalls=", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), " process=", snappedf(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01), "ms")


var tsp := 0
var sp_last := 0
var sp_times: Array = []


func _spike() -> void:
	tsp += 1
	var now := Time.get_ticks_usec()
	if tsp == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = 0
		player.max_hp = 99999.0
		player.hp = 99999.0
		player.mana = 9999.0
		player.max_mana = 9999.0
		player.position = cell_pos(SEEDS[4] + Vector2i(0, 3))
		player.cam.reset_smoothing()
	if tsp == 30:
		for i in 14:
			var kinds := ["skeleton", "ghoul", "bat", "wraith", "reaper", "summoner", "knight_fallen"]
			var e: Enemy = spawn_enemy(kinds[i % kinds.size()], player.position + Vector2.from_angle(i * 0.45) * 55.0, 1.0)
			e.awake = true
			e.set_process(true)
	if tsp > 30 and tsp % 15 == 0:
		player.spells = ["nova", "fulmine"]
		player.spell_cd = [0.0, 0.0]
		player.cast(tsp / 15 % 2)
	if tsp > 30 and tsp % 7 == 0:
		player.atk_cd = 0.0
		player.st = player.max_st
		player.attack()
	if sp_last > 0 and tsp > 10:
		sp_times.append((now - sp_last) / 1000.0)
	sp_last = now
	if tsp == 60 or tsp == 160 or tsp == 260 or tsp == 360 or tsp == 460:
		sp_times.clear()
		sp_last = 0
		if tsp == 160:
			hud.visible = false
		if tsp == 260:
			hud.visible = true
			for en in enemies:
				en.set_process(false)
		if tsp == 360:
			for en in enemies:
				if en.awake:
					en.set_process(true)
			for l in get_tree().root.find_children("*", "PointLight2D", true, false):
				if l != player.light:
					l.visible = false
		if tsp == 460:
			for l in get_tree().root.find_children("*", "PointLight2D", true, false):
				l.visible = true
			hud.visible = false
			for en in enemies:
				en.set_process(false)
	if tsp in [159, 259, 359, 459, 559]:
		sp_times.sort()
		var n2 := sp_times.size()
		var sum2 := 0.0
		for v in sp_times:
			sum2 += v
		print("SPIKE cfg@", tsp, " medio=", snappedf(sum2 / n2, 0.01), " p95=", snappedf(sp_times[int(n2 * 0.95)], 0.01), " max=", snappedf(sp_times[n2 - 1], 0.01))
	if tsp == 560:
		get_tree().quit()
	if tsp == 400000:
		sp_times.sort()
		var n := sp_times.size()
		var sum := 0.0
		for v in sp_times:
			sum += v
		print("SPIKE frame medio=", snappedf(sum / n, 0.01), "ms  p95=", snappedf(sp_times[int(n * 0.95)], 0.01), "ms  p99=", snappedf(sp_times[int(n * 0.99)], 0.01), "ms  max=", snappedf(sp_times[n - 1], 0.01), "ms  nemici=", enemies.size(), " fx=", fx.get_child_count())
		var t0 := Time.get_ticks_msec()
		spawn_all()
		print("SPIKE spawn_all (riposo al falo) ms=", Time.get_ticks_msec() - t0)
		get_tree().quit()


var tsc := 0


func _scale_test() -> void:
	tsc += 1
	if tsc == 5:
		for lvl in [1, 3, 6, 10, 15, 25, 40]:
			player.lv = lvl
			player.apply_stats()
			var e: Enemy = spawn_enemy("skeleton", player.position + Vector2(200, 0), 1.0)
			var g: Enemy = spawn_enemy("ghoul", player.position + Vector2(220, 0), 1.0)
			print("SCALA lv", lvl, ": giocatore vita=", int(player.max_hp), " danno=", snappedf(player.dmg(), 0.1), "  scheletro vita=", int(e.hp), " danno=", snappedf(e.dmg, 0.1), "  ghoul danno=", snappedf(g.dmg, 0.1), " colpi per ucciderlo=", ceili(e.hp / player.dmg()), " colpi che reggi=", int(player.max_hp / e.dmg))
		get_tree().quit()


var tmn := 0


func _menus_test() -> void:
	tmn += 1
	match tmn:
		10:
			state = "pause"
		30:
			opt_from = "pause"
			state = "options"
			opt_sel = 1
		45:
			opt_sel = 1
			opt_change(-1)
			opt_sel = 5
			opt_change(1)
			opt_sel = 4
			opt_change(1)
			print("MENU impostazioni dopo modifiche: ", settings)
		60:
			ctrl_from = "options"
			state = "controls"
		80:
			opt_from = "title"
			in_title_menu = true
			state = "options"
		100:
			title_save = {}
			in_title_menu = false
			state = "title"
		120:
			get_tree().quit()


var tz := 0
var tz_souls := 0


func _zoom_test() -> void:
	tz += 1
	match tz:
		5:
			player.lv = 10
			player.apply_stats()
			player.max_hp = 99999.0
			player.hp = 99999.0
			player.position = cell_pos(SEEDS[2] + Vector2i(0, 4))
			player.cam.reset_smoothing()
			tz_souls = player.souls
			player.cycle_zoom()
			print("Z orda: zmode=", player.zmode, " focus=", int(player.focus))
		200:
			var h := 0
			for e in enemies:
				if e.horde:
					h += 1
			print("Z dopo 6s: orda viva=", h, " nemici tot=", enemies.size(), " anime guadagnate=", player.souls - tz_souls, " kills=", player.kills, " focus=", int(player.focus))
		205:
			player.cycle_zoom()
			print("Z tattica: zmode=", player.zmode, " alleati=", allies.size())
		215:
			order_rally(player.position + Vector2(90, 0))
		330:
			var near := 0
			for a in allies:
				if a.position.distance_to(player.position + Vector2(90, 0)) < 70.0:
					near += 1
			print("Z ordine: alleati vicini al punto=", near, "/", allies.size(), " nemici=", enemies.size())
		335:
			player.cycle_zoom()
			var h2 := 0
			for e in enemies:
				if e.horde:
					h2 += 1
			print("Z ritorno: zmode=", player.zmode, " orda=", h2, " alleati=", allies.size())
		360:
			get_tree().quit()


var tpad := 0


func _pad_test() -> void:
	tpad += 1
	var items := [
		["attack", "b", JOY_BUTTON_RIGHT_SHOULDER], ["dash", "b", JOY_BUTTON_B], ["flask", "b", JOY_BUTTON_X],
		["swap", "b", JOY_BUTTON_Y], ["spell1", "b", JOY_BUTTON_LEFT_SHOULDER], ["interact", "b", JOY_BUTTON_A],
		["zoom", "b", JOY_BUTTON_DPAD_UP], ["lock", "b", JOY_BUTTON_RIGHT_STICK], ["restart", "b", JOY_BUTTON_START],
		["heavy", "a", JOY_AXIS_TRIGGER_RIGHT], ["spell2", "a", JOY_AXIS_TRIGGER_LEFT],
		["move_left", "a", JOY_AXIS_LEFT_X], ["move_up", "a", JOY_AXIS_LEFT_Y],
		["ui_accept", "b", JOY_BUTTON_A], ["ui_cancel", "b", JOY_BUTTON_B], ["ui_down", "b", JOY_BUTTON_DPAD_DOWN],
		["move_right", "b", JOY_BUTTON_DPAD_RIGHT],
	]
	var step := 6
	var k := (tpad - 1) / step
	var local := (tpad - 1) % step
	if k < items.size():
		var it: Array = items[k]
		var neg: bool = it[0] in ["move_left", "move_up"]
		if local == 1:
			if it[1] == "b":
				var e := InputEventJoypadButton.new()
				e.device = 2
				e.button_index = it[2]
				e.pressed = true
				Input.parse_input_event(e)
			else:
				var m := InputEventJoypadMotion.new()
				m.device = 2
				m.axis = it[2]
				m.axis_value = -1.0 if neg else 1.0
				Input.parse_input_event(m)
		elif local == 3:
			print("PAD ", it[0], " -> ", Input.is_action_pressed(it[0]))
		elif local == 4:
			if it[1] == "b":
				var r := InputEventJoypadButton.new()
				r.device = 2
				r.button_index = it[2]
				r.pressed = false
				Input.parse_input_event(r)
			else:
				var m2 := InputEventJoypadMotion.new()
				m2.device = 2
				m2.axis = it[2]
				m2.axis_value = 0.0
				Input.parse_input_event(m2)
	if tpad == 6 * items.size() + 4:
		get_tree().quit()


var tmd := 0


func _mapdump() -> void:
	tmd += 1
	if tmd != 3:
		return
	var out := "C:/Users/VINCIN~1/AppData/Local/Temp/claude/cea0f73972c190b5/f0bdea24-4d3b-4caf-a462-67170e2f77cd/scratchpad"
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--out="):
			out = a2.substr(6)
	var forced := 0
	for a3 in OS.get_cmdline_user_args():
		if a3.begins_with("--seed="):
			forced = int(a3.substr(7))
	if forced > 0:
		world_seed = forced
		build_area("world")
	elif has_save():
		var sd := load_save()
		world_seed = int(sd["seed"])
		build_area("world")
	for gy in range(0, (Game.MH + CH - 1) / CH):
		for gx in range(0, (Game.MW + CH - 1) / CH):
			gen_chunk(gx, gy)
	if forced > 0 and OS.get_cmdline_user_args().has("--objects"):
		# genera tutto il mondo (oggetti, nemici, luoghi) e lo scrive per l'editor, senza gli oggetti messi a mano
		dump_objects = true
		for gy2 in range(0, (Game.MH + CH - 1) / CH):
			for gx2 in range(0, (Game.MW + CH - 1) / CH):
				finalize_chunk(Vector2i(gx2, gy2))
		var od := {"props": [], "pois": [], "enemies": []}
		for pr in ents.get_children():
			if pr is Prop and pr.scene and pr.kind != "":
				od["props"].append([str(pr.kind), pr.cell.x, pr.cell.y])
		for po in pois:
			od["pois"].append([str(po["type"]), str(po["n"]), (po["cell"] as Vector2i).x, (po["cell"] as Vector2i).y])
		for sp in spawns:
			var spc := Vector2i(int(sp["pos"].x / 16), int(sp["pos"].y / 16))
			od["enemies"].append([str(sp["k"]), spc.x, spc.y])
		var of := FileAccess.open(out + "/world_objects.json", FileAccess.WRITE)
		of.store_string(JSON.stringify(od))
		of.close()
		print("OGGETTI scritti: props=", od["props"].size(), " luoghi=", od["pois"].size(), " nemici=", od["enemies"].size())
	var S := 2
	var W := Game.MW
	var H := Game.MH
	var img := Image.create(W * S, H * S, false, Image.FORMAT_RGB8)
	var ground := [Color(0.42, 0.33, 0.28), Color(0.22, 0.34, 0.34), Color(0.13, 0.2, 0.13), Color(0.24, 0.34, 0.2), Color(0.34, 0.3, 0.42), Color(0.72, 0.8, 0.9), Color(0.28, 0.14, 0.12)]
	var block_c := [Color(0.2, 0.17, 0.17), Color(0.07, 0.13, 0.1), Color(0.05, 0.1, 0.07), Color(0.08, 0.18, 0.26), Color(0.16, 0.13, 0.2), Color(0.55, 0.62, 0.75), Color(0.8, 0.28, 0.08)]
	for y in H:
		for x in W:
			var i := y * W + x
			var c: Color
			if outside[i] == 1 and grid[i] == 0 and water[i] == 0:
				c = Color(0.03, 0.03, 0.05)
			elif water[i] == 1:
				c = Color(0.1, 0.22, 0.36)
			elif bridge[i] == 1:
				c = Color(0.6, 0.42, 0.22)
			elif grid[i] == 0:
				c = block_c[biome[i]]
			elif cobble[i] == 1:
				c = Color(0.5, 0.48, 0.52)
			elif road[i] == 1:
				c = Color(0.5, 0.4, 0.25)
			else:
				c = ground[biome[i]]
			var k := 0.92 + 0.16 * Game.hh(x, y, 5)
			img.fill_rect(Rect2i(x * S, y * S, S, S), Color(c.r * k, c.g * k, c.b * k))
	var mk := {"seed": world_seed, "w": W, "h": H, "bonfires": [], "portals": [], "npcs": [], "chests": [], "pages": [], "buildings": [], "seeds": [], "entr": {}}
	for sdv in SEEDS:
		mk["seeds"].append([sdv.x, sdv.y])
	mk["gates"] = []
	for gk in gate_cell.keys():
		mk["gates"].append([gate_cell[gk].x, gate_cell[gk].y, gk])
	for kk in ENTR.keys():
		mk["entr"][kk] = [ENTR[kk].x, ENTR[kk].y]
	for d in doors:
		var dp: Vector2 = d["pos"]
		mk["buildings"].append([int(dp.x / 16), int(dp.y / 16), str(d["dest"]).split("|")[1]])
	for pr in props:
		var cc: Vector2i = pr.cell
		match pr.kind:
			"bonfire":
				mk["bonfires"].append([cc.x, cc.y])
			"portal":
				mk["portals"].append([cc.x, cc.y, pr.dest])
			"npc":
				mk["npcs"].append([cc.x, cc.y, pr.npc_id])
			"chest":
				mk["chests"].append([cc.x, cc.y, pr.rare])
			"page":
				mk["pages"].append([cc.x, cc.y])
	img.save_png(out + "/map_raw.png")
	if forced > 0:
		img.save_png(out + "/world_preview.png")
		var lj := {"seeds": [], "weights": bio_w, "rivers": []}
		for sdv2 in SEEDS:
			lj["seeds"].append([sdv2.x, sdv2.y])
		for rv2 in RIVERS:
			var rl: Array = []
			for pt2 in rv2:
				rl.append([pt2.x, pt2.y])
			lj["rivers"].append(rl)
		var lf := FileAccess.open(out + "/layout_current.json", FileAccess.WRITE)
		lf.store_string(JSON.stringify(lj))
		lf.close()
	var f := FileAccess.open(out + "/map_data.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(mk))
	f.close()
	print("MAPPA salvata seed=", world_seed, " bonfires=", mk["bonfires"].size(), " edifici=", mk["buildings"].size(), " forzieri=", mk["chests"].size())
	get_tree().quit()


var tpg := 0
var pg_p0 := Vector2.ZERO


func _pg_btn(idx: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 1
	e.button_index = idx
	e.pressed = down
	Input.parse_input_event(e)


func _pg_axis(ax: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 1
	e.axis = ax
	e.axis_value = v
	Input.parse_input_event(e)


func _padgame() -> void:
	tpg += 1
	match tpg:
		5:
			pg_p0 = player.position
			_pg_axis(JOY_AXIS_LEFT_X, 1.0)
		30:
			print("PG stick destro: spostamento x=", snappedf(player.position.x - pg_p0.x, 0.1), " state=", state)
			_pg_axis(JOY_AXIS_LEFT_X, 0.0)
		35:
			player.st = player.max_st
			_pg_btn(JOY_BUTTON_RIGHT_SHOULDER, true)
		38:
			print("PG RB: atk_t=", snappedf(player.atk_t, 0.01), " atk_cd=", snappedf(player.atk_cd, 0.01), " stamina=", int(player.st))
			_pg_btn(JOY_BUTTON_RIGHT_SHOULDER, false)
		60:
			_pg_btn(JOY_BUTTON_B, true)
		62:
			print("PG B rotolata: dash_t=", snappedf(player.dash_t, 0.01))
			_pg_btn(JOY_BUTTON_B, false)
		90:
			player.mana = player.max_mana
			_pg_btn(JOY_BUTTON_LEFT_SHOULDER, true)
		92:
			print("PG LB magia1: mana=", int(player.mana), "/", int(player.max_mana), " cd=", snappedf(player.spell_cd[0], 0.1))
			_pg_btn(JOY_BUTTON_LEFT_SHOULDER, false)
		120:
			player.st = player.max_st
			_pg_axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
		124:
			print("PG RT pesante: heavy_t=", snappedf(player.heavy_t, 0.01), " stamina=", int(player.st))
			_pg_axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
		160:
			player.hp = 50.0
			_pg_btn(JOY_BUTTON_X, true)
		162:
			print("PG X fiala: drink_t=", snappedf(player.drink_t, 0.01))
			_pg_btn(JOY_BUTTON_X, false)
		200:
			_pg_btn(JOY_BUTTON_START, true)
		202:
			print("PG Start: state=", state)
			_pg_btn(JOY_BUTTON_START, false)
		210:
			_pg_btn(JOY_BUTTON_B, true)
		212:
			print("PG B in pausa: state=", state)
			_pg_btn(JOY_BUTTON_B, false)
		230:
			for pr in props:
				if pr.kind == "bonfire":
					player.position = pr.position + Vector2(0, 12)
					break
		250:
			_pg_btn(JOY_BUTTON_A, true)
		252:
			print("PG A al falo: state=", state, " prompt=", prompt)
			_pg_btn(JOY_BUTTON_A, false)
		260:
			_pg_btn(JOY_BUTTON_B, true)
		262:
			print("PG B nel menu falo: state=", state)
			_pg_btn(JOY_BUTTON_B, false)
		280:
			get_tree().quit()


var tgt_n := 0


func near_seen(seen: Dictionary, c: Vector2i) -> bool:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			if seen.has(c + Vector2i(dx, dy)):
				return true
	return false


func _gatetest() -> void:
	tgt_n += 1
	if tgt_n != 3:
		return
	var open_ids: Array = []
	for step in 4:
		var seen := {}
		var q: Array[Vector2i] = [SEEDS[0] + Vector2i(0, 4)]
		seen[SEEDS[0] + Vector2i(0, 4)] = true
		var qi := 0
		while qi < q.size():
			var c: Vector2i = q[qi]
			qi += 1
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nc: Vector2i = c + dv
				if inb(nc) and is_floor(nc) and not block.has(nc) and not seen.has(nc):
					seen[nc] = true
					q.append(nc)
		var res := ""
		for k in ENTR.keys():
			res += "%s=%s " % [k, "SI" if near_seen(seen, ENTR[k]) else "no"]
		for si in SEEDS.size():
			res += "R%d=%s " % [si, "SI" if near_seen(seen, SEEDS[si]) else "no"]
		print("GATETEST aperti=", open_ids, " -> ", res)
		if step < GATE_DEF.size():
			var gid: String = GATE_DEF[step]["id"]
			open_ids.append(gid)
			for pr in props:
				if pr.kind == "gate_top" and pr.dest == gid:
					for cc in pr.item["cells"]:
						block.erase(cc)
	get_tree().quit()


var tgs := 0
var ai_stats := {}
var ai_hp := 0.0
var ai_base := Vector2.ZERO
var run_test_base := Vector2.ZERO


func _process(_dt: float) -> void:
	if state == "map":   # la mappa si scorre con il movimento (stick, croce, WASD)
		map_pan += Input.get_vector("move_left", "move_right", "move_up", "move_down") * _dt * (260.0 if map_zoom == 1 else 120.0)
	if OS.get_cmdline_user_args().has("--gateshot"):
		tgs += 1
		if OS.get_cmdline_user_args().has("--stairs"):
			if tgs == 20:
				for pr in props:
					if pr.kind == "stairs_top":
						print("STAIRS da=", pr.cell, " verso=", passages.get(pr.dest, "?"))
						use_stairs(pr)
						break
			if tgs == 70:
				print("STAIRS giocatore ora in cella ", Vector2i(floori(player.position.x / 16.0), floori(player.position.y / 16.0)), " stato=", state)
			if tgs == 75:
				var n_st := 0
				for pr in props:
					if pr.kind == "stairs_top":
						n_st += 1
				print("STAIRS totali=", n_st)
		if tgs == 6 and OS.get_cmdline_user_args().has("--edge"):
			for k in range(0, 140):
				var ec := Vector2i(int(285 - k * 1.2), int(10 + k * 0.7))
				if inb(ec) and is_floor(ec) and outside[idx(ec)] == 0:
					player.position = cell_pos(ec + Vector2i(1, 0))
					break
		elif tgs == 6 and (OS.get_cmdline_user_args().has("--archive") or OS.get_cmdline_user_args().has("--sana") or OS.get_cmdline_user_args().has("--archive-in")):
			var want := "int|sanatorium" if OS.get_cmdline_user_args().has("--sana") else "int|archive"
			for d in doors:
				if str(d["dest"]).begins_with(want):
					if OS.get_cmdline_user_args().has("--archive-in"):
						returns[d["dest"]] = d["cell"]
						change_area(d["dest"])
					else:
						player.position = d["pos"] + Vector2(0, 14)
					print("LM porta ", d["dest"], " blocco=", door_lock_msg(str(d["dest"])))
					break
		elif tgs == 6 and OS.get_cmdline_user_args().has("--cloister"):
			player.position = cell_pos(SEEDS[4] + Vector2i(16, 10) + Vector2i(0, 8))
		elif tgs == 6 and OS.get_cmdline_user_args().has("--stairs"):
			for pr in props:
				if pr.kind == "stairs_top":
					player.position = cell_pos(pr.cell + Vector2i(1, 3))
					print("STAIRS partner=", passages.get(pr.dest, "?"))
					break
		elif tgs == 6 and OS.get_cmdline_user_args().has("--dist"):
			player.position = cell_pos(SEEDS[6] + Vector2i(-10, 1))
		elif tgs == 6 and gate_cell.has("g_cat"):
			player.position = cell_pos(gate_cell["g_cat"] + Vector2i(-3, 0))
	if OS.get_cmdline_user_args().has("--relictest"):
		tgs += 1
		if tgs == 5:
			for rid in ["corvo", "cenere", "brace", "lanterna", "nodo", "catena", "moneta", "pietra", "corvo", "corvo"]:
				drop_loot(player.position + Vector2(randf_range(-30, 30), 18 + randf_range(0, 12)), {"k": "relic", "id": rid})
			print("RELIC base: hp=", player.max_hp, " vel=", snappedf(player.speed, 0.1))
		if tgs == 8:
			var got := 0
			for pr in props.duplicate():
				if pr.kind == "loot" and pr.item.get("k", "") == "relic":
					take_item(pr)
					got += 1
			print("RELIC raccolte=", got, " ", player.relics)
			print("RELIC dopo: hp=", player.max_hp, " vel=", snappedf(player.speed, 0.1))
			var sv := {"relics": player.relics}
			print("RELIC json=", JSON.stringify(sv))
			# prova effetti: uccisione e colpo
			for k2 in 5:
				spawn_enemy("skeleton", player.position + Vector2(24, 0))
			for en in enemies:
				en.awake = true
			print("RELIC nemici=", enemies.size())
		if tgs == 12:
			for en in enemies.duplicate():
				if en.position.distance_to(player.position) < 60.0:
					player.on_hit(en, 20.0, {"a": []})
					en.hurt(9999.0, Vector2.RIGHT, 0.0, false)
		if tgs == 40:
			print("RELIC dopo uccisioni: kills=", player.kills, " hp=", int(player.hp), " nemici=", enemies.size())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--d0test"):
		tgs += 1
		if tgs == 5:
			print("D0 area=", area, " stato=", state, " obiettivo=", objective(), " nemici=", enemies.size(), " boss=", boss_kind)
			state = "play"
			var ex: Prop = null
			for pr in props:
				if pr.kind == "portal" and pr.dest == "world":
					ex = pr
			interact(ex)
			print("D0 uscita senza boss: area=", area, " msg=", msg)
			persist["bosses"]["boss_jailer"] = true
			interact(ex)
		if tgs == 60:
			var pc := Vector2i(floori(player.position.x / 16.0), floori(player.position.y / 16.0))
			print("D0 dopo boss: area=", area, " cella=", pc, " ingresso=", ENTR["d0"], " obiettivo=", objective())
			player.relics = {"corvo": 2, "pietra": 1}
			player.souls = 120
			game_over(false)
			print("D0 morte: macchia=", stain_data.get("relics", {}), " relics ora=", player.relics)
			death_t = 0.0
		if tgs == 75:
			respawn()
			print("D0 respawn: area=", area, " msg=", msg)
			stain.position = player.position
		if tgs == 90:
			print("D0 recupero: relics=", player.relics, " anime=", player.souls)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--arenatest"):
		tgs += 1
		var ai := 0
		for ua in OS.get_cmdline_user_args():
			if ua.begins_with("--arena="):
				ai = int(ua.substr(8))
		if tgs == 5:
			print("ARENA totali=", arenas.size(), " ", arenas.map(func(x): return x["def"]["id"]))
			if ai >= arenas.size():
				get_tree().quit()
				return
			var a0: Dictionary = arenas[ai]
			player.max_hp = 99999.0
			player.hp = 99999.0
			player.position = a0["pos"] + Vector2(0, 30)
			if a0["def"]["mode"] == "bell":
				for pr in props:
					if pr.kind == "bell":
						interact(pr)
			print("ARENA ", a0["def"]["id"], " centro=", a0["center"], " pos=", a0["pos"])
		if tgs > 5 and tgs % 10 == 0 and ai < arenas.size():
			var a1: Dictionary = arenas[ai]
			if not a1["active"] and not a1["done"] and a1["def"]["mode"] == "enter":
				player.position = a1["pos"]
			for e in (a1["alive"] as Array):
				if is_instance_valid(e):
					e.hurt(99999.0, Vector2.RIGHT, 0.0, false)
		if tgs == 1500 and ai < arenas.size():
			var a2: Dictionary = arenas[ai]
			var rel := 0
			var wp := 0
			for pr in props:
				if pr.kind == "loot":
					if pr.item.get("k", "") == "relic":
						rel += 1
					else:
						wp += 1
			print("ARENA risultato: fatta=", a2["done"], " ondata=", a2["wave"], " reliquie a terra=", rel, " armi/tomi=", wp, " persist=", persist["opened"].has("arena:" + str(a2["def"]["id"])))
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--runtest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 600.0
			player.hp = 600.0
			run_test_base = player.position
			print("RUN inizio: stato=", state, " lv=", player.lv, " armi=", player.run_w, " pos=", Vector2i(player.position / 16.0))
		if state == "pick":
			choose(0)
		if tgs > 3 and tgs % 10 == 0 and state == "play":
			player.hp = player.max_hp
			# il giocatore si muove in cerchio, come in una partita vera
			player.position = run_test_base + Vector2(cos(tgs * 0.02), sin(tgs * 0.02)) * 40.0
		if tgs == 700:
			run_t = 900.0
		if tgs % 300 == 0:
			print("RUN f=", tgs, " t=", int(run_t), " lv=", player.lv, " nemici=", enemies.size(), " uccisi=", player.kills, " anime=", run_souls_total, " armi=", player.run_w, " rk=", player.rk.size(), " boss=", run_boss_alive, " stage=", run_stage, " fps=", Engine.get_frames_per_second())
		if tgs == 2400 or state == "results":
			print("RUN fine: stato=", state, " risultato=", run_result)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--spirittest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 9999.0
			player.hp = 9999.0
			for k in ["reaper", "frost_mage", "abomination", "plague_doc", "berserker", "reaper"]:
				drop_shard(player.position + Vector2(10, 14), k)
			print("SPIRIT shard a terra=", props.filter(func(x): return x.kind == "loot").size())
		if tgs == 6:
			print("SPIRIT legate=", player.spirits.map(func(x): return str(x["k"]) + ":" + str(x["lv"])), " nodi=", spirit_nodes.size())
			for i in 12:
				spawn_enemy("skeleton", player.position + Vector2.from_angle(i * 0.52) * 70.0, 1.0, false, Color.WHITE)
			for en in enemies:
				en.awake = true
		if tgs == 12:
			player.dash_t = 0.2
			player.inv = 0.2
			player.hurt(10.0, Vector2.RIGHT)
			print("SPIRIT riposta cd=", snappedf(player.riposta_cd, 0.1))
		if tgs == 240:
			print("SPIRIT nemici rimasti=", enemies.size(), " uccisi=", player.kills)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--forgetest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for k in MAT_ORDER:
				player.mats[k] = 999
			var d0 := player.dmg()
			var hp0 := player.max_hp
			# tutte le combinazioni d'arma: quante sono?
			var combos := 1
			for t in 4:
				var c := 1
				for sl in Forge.slots(t):
					c *= (sl[1] as Array).size()
				print("FORGE scheda ", Forge.TABS[t], " combinazioni=", c)
				combos *= c
			# forgia un'arma a caso per famiglia
			craft_tab = 0
			for i in 7:
				craft_vals[0] = [i, randi() % 4, randi() % 4, randi() % 8, 1 + randi() % 5]
				craft_make()
				var w: Dictionary = player.weapon()
				print("FORGE arma: ", Rpg.wname(w), " r=", w["r"], " b=", snappedf(float(w["b"]), 0.01), " mods=", w.get("mods", {}), " a=", w["a"], " danno=", snappedf(player.dmg(), 0.1))
			# modifiche ripetute
			craft_tab = 1
			for op in [0, 0, 1, 2, 3, 4, 5, 5, 6]:
				craft_vals[1] = [op, randi() % 7]
				craft_make()
			var wm: Dictionary = player.weapon()
			print("FORGE dopo 9 modifiche: ", Rpg.wdesc(wm), " u=", wm.get("u", 0), " costo x", Forge.mod_cost_mult(wm))
			# armatura completa
			craft_tab = 2
			for pc in 3:
				craft_vals[2] = [pc, randi() % 4, randi() % 8, 3 + randi() % 3]
				craft_make()
			player.apply_stats()
			print("FORGE armatura: ", player.armor.keys(), " difesa=", snappedf(player.arm("df"), 0.01), " vita ", hp0, ">", player.max_hp, " spine=", snappedf(player.arm("th"), 0.01))
			# pozioni
			craft_tab = 3
			craft_vals[3] = [0, 6, 6, 2]   # infuso di carne x2
			craft_make()
			craft_make()
			craft_vals[3] = [2, 1, 3, 1]
			craft_make()
			print("FORGE borsa: ", item_ids(), " nomi=", item_ids().map(func(x): return item_name(x)))
			player.hp = player.max_hp * 0.5
			player.item_sel = item_ids().find("b:erba:carne,carne:3") if item_ids().has("b:erba:carne,carne:3") else 0
			var dd := player.dmg()
			item_use()
			print("FORGE pozione usata: vita=", int(player.hp), "/", int(player.max_hp), " buffs=", player.buffs, " bval=", player.bval, " danno ", snappedf(dd, 0.1), ">", snappedf(player.dmg(), 0.1))
			# salvataggio: le armi create e l'armatura sopravvivono al JSON
			var js: Variant = JSON.parse_string(JSON.stringify({"w": player.wslots, "a": player.armor}))
			var w2 := Rpg.clean(js["w"][player.wcur])
			print("FORGE json arma: ", Rpg.wname(w2), " mods=", w2.get("mods", {}), " u=", w2.get("u", 0))
			print("FORGE danno iniziale ", snappedf(d0, 0.1), " totale combinazioni (prodotto) ~", combos)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--invtest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for k in MAT_ORDER:
				player.mats[k] = 200
			# forgia: due armi (la seconda va in borsa), armature (la seconda dello stesso pezzo in borsa), pozioni
			craft_tab = 0
			craft_vals[0] = [1, 0, 2, 1, 4]
			craft_make()
			craft_vals[0] = [4, 1, 1, 7, 5]
			craft_make()
			craft_vals[0] = [3, 0, 3, 0, 3]
			craft_make()
			craft_tab = 2
			for v in [[0, 2, 1, 3], [1, 1, 1, 4], [2, 0, 7, 4], [0, 0, 2, 2]]:
				craft_vals[2] = v
				craft_make()
			craft_tab = 3
			for v in [[1, 6, 6, 3], [2, 2, 0, 2], [0, 0, 0, 2], [3, 5, 0, 1], [0, 4, 4, 1]]:
				craft_vals[3] = v
				craft_make()
			for rid in ["pietra", "brace", "catena", "lanterna", "moneta"]:
				relic_gain(rid, 1)
			print("INV dopo forgia: armi=", player.wslots.map(func(w): return Rpg.wname(w) if w != null else "-"), " borsa=", player.bag.size(), " usate=", player.bag_used(), "/36 cintura=", player.belt, " reliquie indossate=", player.relic_eq)
			print("INV rl(moneta) senza indossarla=", player.rl("moneta"), " rl(pietra)=", player.rl("pietra"))
			inv_toggle()
			var lst := inv_list(0)
			print("INV voci TUTTO=", lst.size(), " tipi=", lst.map(func(e): return e["k"]))
			# equipaggia la prima arma in borsa
			inv_tab = 1
			inv_cell = 0
			var d0 := player.dmg()
			var w_before := Rpg.wname(player.weapon())
			inv_action("equip")
			print("INV equip arma: ", w_before, " -> ", Rpg.wname(player.weapon()), " danno ", snappedf(d0, 0.1), ">", snappedf(player.dmg(), 0.1), " borsa armi=", inv_list(1).size())
			# armatura: scambio con quella indossata
			inv_tab = 2
			inv_cell = 0
			var df0 := player.arm("df")
			print("INV confronto armatura: ", inv_compare(inv_list(2)[0]))
			inv_action("equip")
			print("INV equip armatura: difesa ", snappedf(df0, 0.01), ">", snappedf(player.arm("df"), 0.01))
			# reliquie: la quarta non entra
			inv_tab = 5
			inv_cell = inv_list(5).map(func(e): return e["id"]).find("moneta")
			inv_action("equip")
			print("INV 4a reliquia: indossate=", player.relic_eq, " msg=", msg)
			inv_cell = 0
			inv_action("equip")   # toglie la prima
			inv_cell = inv_list(5).map(func(e): return e["id"]).find("moneta")
			inv_action("equip")
			print("INV scambio reliquia: indossate=", player.relic_eq, " rl(moneta)=", player.rl("moneta"))
			# cintura: la quinta pozione non entra
			inv_tab = 3
			print("INV pozioni=", inv_list(3).map(func(e): return [e["id"], e["eq"]]), " cintura=", player.belt)
			# smonta un'armatura in borsa
			inv_tab = 2
			inv_cell = 0
			var m0 := player.mats.duplicate()
			print("INV smonta prevede: ", salvage_of(inv_list(2)[0]))
			inv_action("smonta")
			var gained := {}
			for k in player.mats:
				if int(player.mats[k]) != int(m0.get(k, 0)):
					gained[k] = int(player.mats[k]) - int(m0.get(k, 0))
			print("INV smontato: ", gained, " msg=", msg)
			# getta: serve la conferma
			inv_tab = 1
			inv_cell = 0
			var nb := player.bag.size()
			inv_action("getta")
			var nb1 := player.bag.size()
			inv_action("getta")
			print("INV getta: borsa ", nb, " > dopo 1 pressione ", nb1, " > dopo 2 ", player.bag.size())
			# riempi la borsa e prova a raccogliere
			while player.bag_free() > 0:
				player.bag.append({"k": "w", "w": Rpg.make_weapon(0)})
			var pr := Prop.new()
			pr.item = Rpg.make_weapon(1)
			props.append(pr)
			take_item(pr)
			print("INV borsa piena: usate=", player.bag_used(), " msg=", msg, " ancora a terra=", props.has(pr))
			# salvataggio: borsa, cintura e reliquie sopravvivono al JSON
			var js: Variant = JSON.parse_string(JSON.stringify({"bag": player.bag, "belt": player.belt, "relic_eq": player.relic_eq}))
			print("INV json: borsa=", (js["bag"] as Array).size(), " cintura=", js["belt"], " reliquie=", js["relic_eq"])
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--foestest") or OS.get_cmdline_user_args().has("--foesshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			var kinds := ["goblin", "goblin_archer", "goblin_shaman", "kobold", "orc", "troll", "ogre", "harpy", "lizardman", "orc_warlord", "goblin_boss", "troll_frost"]
			for i in kinds.size():
				var e := spawn_enemy(kinds[i], player.position + Vector2.from_angle(TAU * i / kinds.size()) * 70.0, 1.0, false, Color.WHITE)
				e.awake = true
				e.set_process(true)
			print("FOES comparsi=", kinds.size())
		if tgs == 60:
			for e in enemies:
				if e.kind == "troll":
					e.hurt(60.0, Vector2.UP, 0.0)
					print("FOES troll colpito hp=", int(e.hp), "/", int(e.max_hp))
		if tgs == 700:
			for e in enemies:
				if e.kind == "troll":
					print("FOES troll dopo ", snappedf(e.t - e.last_hit_t, 0.1), "s senza colpi hp=", int(e.hp))
			print("FOES vivi=", enemies.size(), " danno al giocatore=", int(99999 - player.hp))
			if not OS.get_cmdline_user_args().has("--foesshot"):
				get_tree().quit()
	if OS.get_cmdline_user_args().has("--beastshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for k in ["rat", "goblin", "goblin_archer", "kobold", "skeleton", "zombie", "ghoul", "wolf", "troll", "orc", "harpy", "knight_fallen", "boss_jailer", "boss_campanaro"]:
				beast_note(k)
				for i in randi_range(1, 30):
					beast_note(k, true)
			for i in Bestiary.ENTRIES.size():
				if Bestiary.ENTRIES[i][0] == "troll":
					beast_sel = i
			open_bestiary()
			print("BEAST schede=", persist["bestiary"].size(), " stato=", state, " voci=", Bestiary.ENTRIES.size())
			for en in Bestiary.ENTRIES:
				if Bestiary.stats(en[0]).is_empty():
					print("BEAST senza dati: ", en[0])
	if OS.get_cmdline_user_args().has("--aoeshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			spawn_hazard(player.position + Vector2(-80, 0), 32.0, 1.2, 0.15, 1.0, 0.0, Color(0.9, 0.3, 0.2))
			spawn_hazard(player.position + Vector2(80, 0), 28.0, 0.3, 4.0, 0.1, 0.5, Color(0.4, 0.9, 0.3))
			spawn_hazard(player.position + Vector2(0, -70), 44.0, 0.6, 0.15, 1.0, 0.0, Color(0.5, 0.9, 1.0))
		if tgs == 20 or tgs == 21:
			player.mana = 999.0
			player.spells = ["nova", "gelo"]
			player.spell_cd = [0.0, 0.0]
			player.cast(0)
			print("AOE mana=", int(player.mana), " cd=", player.spell_cd, " shock=", fx.get_children().filter(func(x): return x is Hazard.Shock).size(), " drink=", player.drink_t, " dash=", player.dash_t, " heavy=", player.heavy_t)
	if OS.get_cmdline_user_args().has("--optsnap") and Engine.get_process_frames() == 60:
		state = "options"
		settings["auto_fire"] = true
	if OS.get_cmdline_user_args().has("--snap") and Engine.get_process_frames() == 90:
		get_viewport().get_texture().get_image().save_png("user://snap.png")
		print("SNAP ", get_viewport().get_visible_rect().size)
		get_tree().quit()
	if OS.get_cmdline_user_args().has("--locktest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			settings["aim_manual"] = true
			player.max_hp = 99999.0
			player.hp = 99999.0
			for i in 3:
				var e := spawn_enemy("goblin", player.position + Vector2(40 + i * 30, 0), 1.0, false, Color.WHITE)
				e.awake = true
		if tgs == 5:
			var seq: Array = []
			for k in 4:
				player.cycle_lock()
				seq.append(int(player.lock.position.distance_to(player.position)) if player.lock != null else -1)
			print("LOCK distanze in ordine=", seq, " face verso bersaglio=", player.face.dot((player.lock.position - player.position).normalized()) > 0.9 if player.lock else false)
		if tgs == 8:
			print("LOCK face=", snappedf(player.face.dot((player.lock.position - player.position).normalized()), 0.01), " zoom tasto=", InputMap.action_get_events("zoom").size(), " lock tasto=", InputMap.action_get_events("lock").size())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--difftest"):
		tgs += 1
		if tgs == 3:
			for lv in [1, 5, 10, 15]:
				player.lv = lv
				var tot := 0
				var pres := 0
				for k in spawn_buckets:
					for e in spawn_buckets[k]:
						tot += 1
						pres += int(spawn_present(e))
				var g := spawn_enemy("goblin", player.position, 1.0, false, Color.WHITE)
				print("DIFF lv=", lv, " nemici presenti=", pres, "/", tot, " ferocia=", snappedf(ferocity(false), 0.01), " goblin vel=", int(g.speed), " danno=", snappedf(g.dmg, 0.1))
				enemies.erase(g)
				g.queue_free()
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--maptest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			# esplora un po' di mondo: attorno al villaggio, verso il cimitero e la cattedrale
			for pt in [SEEDS[0], SEEDS[1], ENTR["d7"], ENTR["d1"]]:
				for dy in range(-30, 31):
					for dx in range(-30, 31):
						var c: Vector2i = pt + Vector2i(dx, dy)
						if inb(c) and dx * dx + dy * dy < 900 and seen[idx(c)] == 0:
							seen[idx(c)] = 1
							mm_img.set_pixelv(c, mm_color(c))
			mm_tex.update(mm_img)
			var n0 := 0
			for v in seen:
				n0 += int(v != 0)
			# salvataggio e ricarica dell'esplorazione
			var b64 := Marshalls.raw_to_base64(seen.compress(FileAccess.COMPRESSION_DEFLATE))
			load_seen({"seen": b64})
			var n1 := 0
			for v in seen_load:
				n1 += int(v != 0)
			seen_load = PackedByteArray()
			print("MAP esplorate=", n0, " dopo ricarica=", n1, " byte salvati=", b64.length(), " bersagli=", obj_targets().map(func(x): return str(x["n"])))
			open_map()
			print("MAP stato=", state)
		if tgs == 20:
			map_zoom = 1
		if tgs == 21:
			print("MAP zoom=", map_zoom)
		if tgs == 40 and not OS.get_cmdline_user_args().has("--shot"):
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--cathshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var g: Vector2i = ENTR["d7"]
			ensure_area(cell_pos(g), 3)
			player.position = cell_pos(g + Vector2i(26, -14))
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--seed="):
					var sd: Vector2i = SEEDS[int(arg.substr(7))]
					ensure_area(cell_pos(sd), 3)
					player.position = cell_pos(sd + Vector2i(8, 9))
			if OS.get_cmdline_user_args().has("--vil"):
				ensure_area(cell_pos(SEEDS[0]), 3)
				player.position = cell_pos(SEEDS[0] + Vector2i(5, 7))
			player.cam.reset_smoothing()
			player.zmode = 0
			print("CATH ingresso=", g, " cattedrale=", world_has_cathedral, " villaggio=", SEEDS[0])
	if OS.get_cmdline_user_args().has("--belltest") or OS.get_cmdline_user_args().has("--bellshot"):
		tgs += 1
		var shot := OS.get_cmdline_user_args().has("--bellshot")
		if tgs == 3:
			state = "play"
			_do_change("d7")
			player.max_hp = 99999.0
			player.hp = 99999.0
			print("BELL cattedrale nel mondo=", world_has_cathedral)
			print("BELL area=", area, " colosso=", colossus != null, " lucchetti=", camp_locks.size(), " stanze=", rooms.size())
		if shot and colossus != null and tgs % 15 == 0:
			print("BELL t=", tgs, " stato=", colossus.state, " vita giocatore=", int(player.hp), " fase=", colossus.phase)
		if shot and tgs == 200 and colossus != null:
			for L in colossus.locks.slice(0, 2):
				L["part"].hurt(L["part"].max_hp + 1.0, Vector2.UP, 0.0)
		if tgs == 6 and colossus != null:
			player.position = colossus.position + Vector2(-20, 70)
		if tgs == 30 and colossus != null:
			print("BELL stato=", colossus.state, " boss=", boss != null and boss == colossus.head, " hp=", int(colossus.head.hp))
			var hp0 := colossus.head.hp
			colossus.head.hurt(100.0, Vector2.UP, 0.0)
			print("BELL colpo alla testa chiusa: ", int(hp0 - colossus.head.hp), " (deve essere poco)")
		if tgs >= 40 and tgs < 400 and not shot and colossus != null and tgs % 40 == 0:
			for L in colossus.locks:
				if L["alive"]:
					L["part"].hurt(L["part"].max_hp + 1.0, Vector2.UP, 0.0)
					print("BELL lucchetto rotto, fase=", colossus.phase, " stato=", colossus.state)
					break
		if tgs == 420 and not shot and colossus != null:
			var c: Dictionary = colossus.chains[0]
			print("BELL catena0 punti=", (c["pts"] as PackedVector2Array).size(), " libera=", c["free_end"], " catene totali=", colossus.chains.size())
			colossus.head_open = 2.0
			var hp1 := colossus.head.hp
			colossus.head.hurt(100.0, Vector2.UP, 0.0)
			print("BELL colpo al volto scoperto: ", int(hp1 - colossus.head.hp))
			colossus.head.hurt(999999.0, Vector2.UP, 0.0)
		if tgs == 470 and not shot:
			print("BELL sconfitto=", persist["bosses"].has("boss_campanaro"), " colosso valido=", is_instance_valid(colossus) and not colossus.dead)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--invshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for k in MAT_ORDER:
				player.mats[k] = 60
			craft_tab = 0
			for v in [[1, 0, 2, 1, 4], [4, 1, 1, 7, 5], [3, 0, 3, 0, 3], [5, 2, 0, 5, 3]]:
				craft_vals[0] = v
				craft_make()
			craft_tab = 2
			for v in [[0, 2, 1, 3], [1, 1, 1, 4], [2, 0, 7, 4], [0, 0, 2, 2]]:
				craft_vals[2] = v
				craft_make()
			craft_tab = 3
			for v in [[1, 6, 6, 3], [2, 2, 0, 2], [0, 0, 0, 2], [3, 5, 0, 1], [0, 4, 4, 1]]:
				craft_vals[3] = v
				craft_make()
			for rid in ["pietra", "brace", "catena", "lanterna", "moneta"]:
				relic_gain(rid, 1)
			player.apply_stats()
			inv_toggle()
			inv_cell = 3
	if OS.get_cmdline_user_args().has("--uishot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for rid in ["pietra", "brace", "catena", "lanterna", "moneta"]:
				player.relics[rid] = 1 + randi() % 2
			for k in MAT_ORDER:
				player.mats[k] = randi_range(1, 9)
			add_item("arrosto", 2)
			add_item("infuso", 1)
			player.buffs["forza"] = 90.0
			bind_spirit(str(Spirit.DATA.keys()[0]))
		if tgs == 40:
			player.mats["legna"] = int(player.mats["legna"]) + 2
			player.relics["nodo"] = 1
			say("SCRIGNO: 64 ANIME, 2 LEGNA, 3 OSSO, ARROSTO")
		if tgs == 45 and OS.get_cmdline_user_args().has("--forgeshot"):
			for k in MAT_ORDER:
				player.mats[k] = randi_range(2, 14)
			craft_tab = int(OS.get_cmdline_user_args()[-1]) if OS.get_cmdline_user_args()[-1].is_valid_int() else 0
			craft_row = 2
			craft_vals[0] = [1, 0, 2, 1, 3]
			state = "craft"
		if tgs == 50 and OS.get_cmdline_user_args().has("--chests"):
			var cnt := 0
			for pr in props:
				if pr.kind == "chest":
					cnt += 1
			print("CHEST scrigni nel mondo caricato=", cnt)
			var c0 := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
			for rr in [false, true, false]:
				var ch := add_prop("chest", free_spot(c0 + Vector2i(3, 0), Vector2i(1, 1)))
				ch.rare = rr
				chest_loot(ch)
				print("CHEST prezioso=", rr, " msg=", msg)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--lvtest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.souls = 5000
			var lv0 := player.lv
			var fires: Array = props.filter(func(x): return x.kind == "bonfire")
			interact(fires[0])
			print("LV falo: stato=", state, " lv=", lv0)
			try_level_up()
			print("LV dopo try: stato=", state, " scelte=", picks.size())
			if OS.get_cmdline_user_args().has("--shot"):
				get_tree().create_timer(2.5).timeout.connect(func():
					try_level_up()
					pick_sel = 3)
				return
			choose(0)
			print("LV dopo scelta: lv=", player.lv, " anime=", player.souls, " stato=", state, " costo prossimo=", Upgrades.cost(player.lv))
			var d0 := player.dmg()
			var h0 := player.max_hp
			player.souls = 999999
			for k in 6:
				try_level_up()
				choose(2)   # forza
			print("ATTR ", player.attr, " vita ", h0, ">", player.max_hp, " danno ", d0, ">", player.dmg(), " stato=", state, " scelte=", picks.size())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--aitest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			player.inv = 0.0
			for e in enemies.duplicate():
				enemies.erase(e)
				e.queue_free()
			var kinds := ["skeleton", "wolf", "cultist", "gargoyle", "ooze"]
			for ua in OS.get_cmdline_user_args():
				if ua.begins_with("--kinds="):
					kinds = ua.substr(8).split(",")
			for i in kinds.size():
				var e2 := spawn_enemy(kinds[i], player.position + Vector2.from_angle(i * TAU / kinds.size() + 0.3) * 110.0, 1.0, false, Color.WHITE)
				e2.hp = 5000.0
				e2.max_hp = 5000.0
				e2.awake = true
				e2.set_process(true)
				ai_stats[kinds[i]] = {"att": 0, "rec": 0, "tel_prev": false, "rec_prev": false, "dmg": 0.0}
			ai_hp = player.hp
		if tgs > 3:
			player.inv = 0.0
			player.position = ai_base
			for e3 in enemies:
				if ai_stats.has(e3.kind):
					var st: Dictionary = ai_stats[e3.kind]
					var tl: bool = e3.tel > 0.0
					if tl and not st["tel_prev"]:
						st["att"] += 1
					st["tel_prev"] = tl
					var rc: bool = e3.recover_t > 0.0
					if rc and not st["rec_prev"]:
						st["rec"] += 1
					st["rec_prev"] = rc
			ai_stats["_dmg"] = ai_hp - player.hp
		if tgs == 3:
			ai_base = player.position
		if tgs == 1200:
			print("AI danno subito=", ai_stats.get("_dmg"))
			for k in ai_stats:
				if k != "_dmg":
					print("AI ", k, " attacchi=", ai_stats[k]["att"], " finestre di recupero=", ai_stats[k]["rec"])
			var oz := 0
			for e4 in enemies:
				if e4.kind == "ooze_small":
					oz += 1
			var ob: Enemy = null
			for e5 in enemies:
				if e5.kind == "ooze":
					ob = e5
			if ob != null:
				ob.hurt(99999.0, Vector2.RIGHT, 0.0, false)
			print("AI ooze_small prima=", oz)
		if tgs == 1230:
			var oz2 := 0
			for e6 in enemies:
				if e6.kind == "ooze_small":
					oz2 += 1
			print("AI ooze_small dopo la morte dell'ooze=", oz2)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--bosstest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			for e in enemies.duplicate():
				enemies.erase(e)
				e.queue_free()
			var bk := "boss_wraith"
			for ua in OS.get_cmdline_user_args():
				if ua.begins_with("--boss="):
					bk = ua.substr(7)
			var b := spawn_enemy(bk, player.position + Vector2(90, 0), 1.0, false, Color.WHITE)
			b.awake = true
			b.set_process(true)
			b.hp = 3000.0
			b.max_hp = 3000.0
			ai_base = player.position
		if tgs > 3:
			player.position = ai_base
			player.inv = 0.0
			for e in enemies:
				if e.is_boss:
					if tgs == 300:
						e.hp = e.max_hp * 0.5
					if tgs == 700:
						e.hp = e.max_hp * 0.2
					if tgs % 200 == 0:
						print("BOSS f=", tgs, " fase=", e.phase_n, " pattern visti=", e.pat_seen, " nemici=", enemies.size())
		if tgs == 1100:
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--parrytest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 500.0
			player.hp = 500.0
			var e := spawn_enemy("skeleton", player.position + Vector2(20, 0), 1.0, false, Color.WHITE)
			e.awake = true
			ai_base = player.position
			# senza parata
			var hp0 := player.hp
			player.inv = 0.0
			e._hit_target(player, Vector2.RIGHT, 0.0)
			print("PARRY senza parata: danno=", snappedf(hp0 - player.hp, 0.1), " recover=", e.recover_t)
			player.inv = 0.0
			player.hp = 500.0
			player.parry_t = 0.2
			e.tel = 0.4
			e.lunge = 0.2
			hp0 = player.hp
			e._hit_target(player, Vector2.RIGHT, 0.0)
			print("PARRY con parata: danno=", snappedf(hp0 - player.hp, 0.1), " recover=", e.recover_t, " stun=", e.stun, " tel=", e.tel, " lunge=", e.lunge)
			player.parry_t = 0.0
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--lifetest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			var by := {}
			for c in critters:
				by[c.kind] = int(by.get(c.kind, 0)) + 1
			print("LIFE fauna=", critters.size(), " ", by)
			var bv := {}
			for v in villagers:
				bv[v.region] = int(bv.get(v.region, 0)) + 1
			print("LIFE abitanti=", villagers.size(), " ", bv)
			player.position = villagers[0].position + Vector2(10, 12)
			day_t = 0.5
		if tgs == 20:
			print("LIFE mezzogiorno: luce=", snappedf(day_light(), 0.01), " ", day_name(), " ", day_clock(), " ambiente=", cm.color)
			var near := 0
			for v in villagers:
				if v.visible:
					near += 1
			print("LIFE abitanti visibili=", near)
			interact(villagers[0])
			print("LIFE dialogo: ", msg)
			day_t = 0.8
		if tgs == 60:
			print("LIFE ora=", day_clock(), " luce=", snappedf(day_light(), 0.01), " abitanti rientrati=", villagers.filter(func(x): return x.state != "work").size(), "/", villagers.size())
		if tgs == 600:
			var inside := villagers.filter(func(x): return x.state == "inside").size()
			print("LIFE notte: dentro=", inside, "/", villagers.size(), " visibili=", villagers.filter(func(x): return x.visible).size(), " ambiente=", cm.color, " luce=", snappedf(day_light(), 0.01))
			var asleep := critters.filter(func(x): return not x.visible and not x.d["night"]).size()
			print("LIFE animali diurni a dormire=", asleep)
			day_t = 0.55
			set_weather("rain")
		if tgs == 700:
			print("LIFE pioggia: emit=", rain_fx.emitting, " neve=", snow_fx.emitting, " ambiente=", cm.color)
			# caccia: colpisco un cervo
			var dr: Critter = null
			for c in critters:
				if c.kind == "deer":
					dr = c
					break
			if dr != null:
				player.position = dr.position + Vector2(-14, 0)
				player.face = Vector2.RIGHT
				print("LIFE cervo hp=", dr.hp)
				dr.hurt(99.0, Vector2.RIGHT, 0.0)
				print("LIFE cervo ucciso: restano=", critters.size())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--lifeshot"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var mode := ""
			for ua in OS.get_cmdline_user_args():
				if ua.begins_with("--mode="):
					mode = ua.substr(7)
			if mode == "forest":
				for c in critters:
					if c.kind == "deer":
						player.position = c.position + Vector2(60, 20)
						break
				day_t = 0.5
			elif mode == "lineup":
				player.position = villagers[0].position + Vector2(0, 40)
				day_t = 0.5
				for i in mini(9, villagers.size()):
					villagers[i].position = player.position + Vector2(-64 + i * 16, -24)
					villagers[i].goal = villagers[i].position
					villagers[i].st_t = 99.0
			elif mode == "dialog":
				var vv: Villager = null
				for x in villagers:
					if x.qid != "" and x.role == "cacciatore" and x.region == 0:
						vv = x
				player.position = vv.position + Vector2(0, 14)
				day_t = 0.5
				interact(vv)
			elif mode == "camp" or mode == "hut":
				for pr in props:
					if pr.kind == "bonfire":
						var want_hut: bool = biome[idx(pr.cell)] in [2, 3, 5]
						if (mode == "hut") == want_hut:
							light_bonfire(pr)
							player.position = pr.position + Vector2(0, 30)
							break
				day_t = 0.78
			elif mode == "wild":
				var pth: Array = road_paths.get(0, [])
				var wc: Vector2i = pth[pth.size() / 2]
				ensure_area(cell_pos(wc), 2)
				player.position = cell_pos(wc)
				day_t = 0.5
			elif mode.begins_with("land:"):
				for sdc in SEEDS:
					ensure_area(cell_pos(sdc), 3)
				for pr in ents.get_children():
					if pr is Prop and str(pr.kind).begins_with(mode.substr(5)):
						player.position = pr.position + Vector2(pr.spr.texture.get_width() * 0.5, 24)
						break
				day_t = 0.5
			elif mode.begins_with("bio:"):
				var wb := int(mode.substr(4))
				var bc := Vector2i(-1, -1)
				var wk := 0
				for yy in range(10, Game.MH - 10):
					for xx in range(10, Game.MW - 10):
						var ii := yy * Game.MW + xx
						if biome[ii] == wb and reach[ii] == 1 and road[ii] == 0 and cobble[ii] == 0 and outside[ii] == 0 and (xx * 7 + yy * 13) % 997 == 0:
							bc = Vector2i(xx, yy)
							wk += 1
							if wk >= 3:
								break
					if wk >= 3:
						break
				ensure_area(cell_pos(bc), 2)
				player.position = cell_pos(bc)
				day_t = 0.5
			elif mode.begins_with("poi:"):
				var want := mode.substr(4)
				for po in pois:
					if po["type"] == want:
						var pc: Vector2i = po["cell"]
						ensure_area(cell_pos(pc), 2)
						player.position = cell_pos(pc + Vector2i(0, 7))
						break
				day_t = 0.5
			elif mode.begins_with("tpl:"):
				PoiData.ensure_loaded()
				var tt := PoiData.by_id(mode.substr(4))
				var tc: Vector2i = SEEDS[3] + Vector2i(-60, 70)
				ensure_area(cell_pos(tc), 2)
				build_poi({"id": 700, "type": tt["type"], "tpl": tt["id"], "cell": tc, "n": tt["name"]})
				wr_node.refresh_cells(Rect2i(tc.x - 20, tc.y - 20, 40, 40))
				player.position = cell_pos(tc + Vector2i(0, 8))
				day_t = 0.5
			elif mode == "rain":
				player.position = villagers[0].position + Vector2(0, 14)
				day_t = 0.45
				set_weather("rain")
			elif mode == "night":
				player.position = villagers[0].position + Vector2(0, 14)
				day_t = 0.02
			else:
				player.position = villagers[0].position + Vector2(0, 14)
				day_t = 0.55
			cm.color = Color(0.3, 0.3, 0.45)
	if OS.get_cmdline_user_args().has("--safetest"):
		tgs += 1
		if tgs == 5:
			var ds: Array = []
			for d in doors:
				ds.append(d["dest"])
			var safe_n := 0
			var safe_en := 0
			var wild_n := 0
			var wild_en := 0
			for dn in ds:
				var pr: PackedStringArray = str(dn).split("|")
				var is_safe: bool = pr[1] == "house" and in_settlement(Vector2i(int(pr[2]), int(pr[3])))
				build_area(dn)
				if is_safe:
					safe_n += 1
					safe_en += enemies.size()
				else:
					wild_n += 1
					wild_en += enemies.size()
			print("SAFE case del villaggio=", safe_n, " nemici dentro=", safe_en, " | altri edifici=", wild_n, " nemici dentro=", wild_en)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--questtest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var types := {}
			for qid in quest_defs:
				var tp: String = quest_defs[qid]["type"]
				types[tp] = int(types.get(tp, 0)) + 1
			print("QUEST definite=", quest_defs.size(), " tipi=", types)
			for v in villagers:
				if v.qid != "":
					quest_accept(v.qid)
			print("QUEST esempi: ", quest_lines().slice(0, 6))
			# costruisco i luoghi coinvolti (come se il giocatore ci arrivasse)
			for qid in quest_defs:
				var d: Dictionary = quest_defs[qid]
				if d.has("poi_id"):
					ensure_area(cell_pos(pois[int(d["poi_id"])]["cell"]), 2)
			var items := 0
			for qid in quest_defs:
				var d2: Dictionary = quest_defs[qid]
				if d2["type"] == "fetch" or d2["type"] == "poi_fetch":
					var pr: Node = quest_items.get(qid)
					if pr != null and is_instance_valid(pr):
						items += 1
						interact(pr)
				elif d2["type"] == "poi_clear":
					for en in pois[int(d2["poi_id"])]["spawns"]:
						en["alive"] = false
				elif d2["type"] == "poi_find":
					persist["opened"]["poi:%d" % int(d2["poi_id"])] = true
				elif d2["type"] == "visit":
					for a2 in arenas:
						if a2["def"]["id"] == d2["target"]:
							player.position = a2["pos"]
			print("QUEST oggetti trovati=", items)
			quest_update()
			for i in 2:
				quest_event("hunt", "deer", false)
			var st_list := []
			for qid in quest_defs:
				st_list.append(quest_state(qid))
			print("QUEST stati=", st_list)
			var souls0 := player.souls
			for v in villagers:
				if v.qid != "" and quest_state(v.qid) == "ready":
					quest_claim(v.qid)
			print("QUEST consegnate: anime +", player.souls - souls0)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--dlgtest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var v: Villager = null
			for x in villagers:
				if x.qid != "" and x.role == "guardia":
					v = x
			player.position = v.position + Vector2(0, 14)
			day_t = 0.5
			interact(v)
			print("DLG stato=", state, " testa=", dlg["head"], " opzioni=", dlg["opts"], " quest=", quest_state(v.qid))
			dlg["sel"] = 1
			dialog_confirm()
			print("DLG dopo NON ORA: stato=", state, " quest=", quest_state(v.qid))
			interact(v)
			dlg["sel"] = 0
			dialog_confirm()
			print("DLG dopo ACCETTO: stato=", state, " quest=", quest_state(v.qid))
			interact(v)
			print("DLG riparla: ", dlg["text"], " opzioni=", dlg["opts"])
			dialog_close()
			qp()[v.qid]["p"] = 1
			print("DLG pronta: quest=", quest_state(v.qid))
			interact(v)
			var s0 := player.souls
			print("DLG consegna: ", dlg["text"], " opzioni=", dlg["opts"])
			dialog_confirm()
			print("DLG ricompensa: anime +", player.souls - s0, " quest=", quest_state(v.qid), " stato=", state)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--camptest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var by := {}
			for pr in props:
				if pr.kind == "bonfire":
					var tn: String = str(pr.spr.texture.resource_path.get_file())
					by[tn] = int(by.get(tn, 0)) + 1
			print("CAMP accampamenti nel mondo: ", by)
			player.max_hp = 500.0
			player.hp = 50.0
			day_t = 0.05
			var cp: Prop = null
			for pr in props:
				if pr.kind == "bonfire":
					cp = pr
					break
			player.position = cp.position + Vector2(0, 14)
			interact(cp)
			print("CAMP dormo: stato=", state, " ora prima=", day_clock())
		if tgs == 150:
			print("CAMP dopo il sonno: stato=", state, " ora=", day_clock(), " luce=", snappedf(day_light(), 0.01), " vita=", int(player.hp), "/", int(player.max_hp), " ripresa=", last_fire["area"], last_fire["cell"])
			# letto in una casa del villaggio
			var dst := ""
			for d in doors:
				var pr2: PackedStringArray = str(d["dest"]).split("|")
				if pr2[1] == "house" and in_settlement(Vector2i(int(pr2[2]), int(pr2[3]))):
					build_area(d["dest"])
					var beds: Array = props.filter(func(x): return x.kind == "bed_top")
					if beds.size() > 0:
						dst = d["dest"]
						break
			print("CAMP casa=", dst, " letti usabili=", props.filter(func(x): return x.kind == "bed_top").size())
			var bd: Prop = null
			for pr3 in props:
				if pr3.kind == "bed_top":
					bd = pr3
					break
			if bd != null:
				player.position = bd.position + Vector2(16, 6)
				state = "play"
				interact(bd)
				print("CAMP letto: ripresa=", last_fire["area"])
		if tgs == 300:
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--cachetest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var np := props.size()
			var nd0 := dest_cells.size()
			var ng := gen_chunks.size()
			print("CACHE mondo: props=", np, " blocchi=", ng, " MW=", Game.MW)
			var dst := ""
			for d in doors:
				if str(d["dest"]).begins_with("int|house"):
					dst = d["dest"]
					break
			var t0 := Time.get_ticks_msec()
			build_area(dst)
			print("CACHE dentro: area=", area, " MW=", Game.MW, " props=", props.size(), " (", Time.get_ticks_msec() - t0, " ms) cache=", not world_cache.is_empty())
			t0 = Time.get_ticks_msec()
			build_area("world")
			print("CACHE ritorno: area=", area, " MW=", Game.MW, " props=", props.size(), " blocchi=", gen_chunks.size(), " (", Time.get_ticks_msec() - t0, " ms) ents visibili=", ents.visible, " wr=", wr_node != null and wr_node.visible, " giocatore nel nodo=", player.get_parent() == ents)
			print("CACHE uguale: ", props.size() == np and gen_chunks.size() == ng, " dest_cells=", dest_cells.size(), " (prima ", nd0, ")")
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--streamtest"):
		tgs += 1
		var nowu := Time.get_ticks_usec()
		if tgs == 3:
			state = "play"
			player.max_hp = 99999.0
			player.hp = 99999.0
			print("STREAM inizio: blocchi=", gen_chunks.size(), " completi=", gen_chunks.values().count(true))
			stream_i = 0
			stream_path = road_paths.get(1, [])
			print("STREAM strada cemetery-palude: celle=", stream_path.size())
		if tgs > 3 and stream_path.size() > 0:
			# cammino lungo la strada a ~5 tile/s
			stream_i = mini(stream_path.size() - 1, stream_i + 1)
			var cc: Vector2i = stream_path[stream_i]
			player.position = cell_pos(cc)
			if tgs > 5:
				stream_max = maxi(stream_max, nowu - stream_last)
			stream_last = nowu
			if tgs % 120 == 0:
				print("STREAM f=", tgs, " cella=", cc, " blocchi=", gen_chunks.size(), " completi=", gen_chunks.values().count(true), " fps=", Engine.get_frames_per_second(), " frame max ms=", stream_max / 1000)
		if tgs == 900:
			print("STREAM fine: blocchi=", gen_chunks.size(), " completi=", gen_chunks.values().count(true), " nemici attivi=", enemies.size(), " critters=", critters.size())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--poitest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			var by := {}
			for po in pois:
				by[po["type"]] = int(by.get(po["type"], 0)) + 1
			print("POI totali=", pois.size(), " ", by)
			var seen_t := {}
			for po in pois:
				if seen_t.has(po["type"]):
					continue
				seen_t[po["type"]] = true
				var c: Vector2i = po["cell"]
				var p0 := block.size()
				var s0 := spawns.size()
				ensure_area(cell_pos(c), 2)
				var near_p := 0
				for pr in props:
					if Vector2(pr.cell).distance_to(Vector2(c)) < 16.0:
						near_p += 1
				var near_s := 0
				for sp in spawns:
					if (sp["pos"] as Vector2).distance_to(cell_pos(c)) < 16.0 * 16.0:
						near_s += 1
				print("POI ", po["type"], " ", c, " oggetti interattivi vicini=", near_p, " nemici fissi vicini=", near_s)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--diffscale"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for tier in [0, 2, 4]:
				var zm: float = 1.0 + tier * 0.28
				for lv in [1, 10, 20, 30]:
					player.lv = lv
					var e := Enemy.new()
					e.setup(self, "skeleton", zm, false, Color.WHITE)
					var c := Enemy.new()
					c.setup(self, "reaper", 1.0 + tier * 0.2, false, Color.WHITE)
					var b := Enemy.new()
					b.setup(self, "boss_wraith", 1.0, false, Color.WHITE)
					print("DIFF zona %d  lv%2d  scheletro hp=%3d dmg=%2d | campione hp=%3d dmg=%2d | boss hp=%4d dmg=%2d" % [tier, lv, int(e.hp), int(e.dmg), int(c.hp), int(c.dmg), int(b.hp), int(b.dmg)])
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--poidata"):
		tgs += 1
		if tgs == 3:
			PoiData.ensure_loaded()
			var bad := {}
			var all_ops: Array = []
			for t in PoiData.templates:
				all_ops.append_array(t["ops"])
			for t in PoiData.micro:
				all_ops.append_array(t["ops"])
			for op in all_ops:
				var names: Array = []
				match str(op[0]):
					"p", "pf", "t", "a", "ring":
						names = [str(op[1])]
					"r":
						names = op[1]
					"grid":
						names = [str(op[1]) + "0"]
				for nm in names:
					var nn := str(nm)
					if nn.begins_with("roof_") and nn.count("_") == 2:
						nn += "_0"
					var path := "res://assets/sprites/%s.png" % nn
					if not ResourceLoader.exists(path):
						bad[nn] = true
			print("POIDATA modelli=", PoiData.templates.size(), " micro=", PoiData.micro.size(), " sprite mancanti=", bad.keys())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--tpltest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			PoiData.ensure_loaded()
			var base: Vector2i = SEEDS[3] + Vector2i(-60, 70)
			ensure_area(cell_pos(base), 4)
			var rows := []
			var i := 0
			for t in PoiData.templates:
				var c := base + Vector2i((i % 6) * 36 - 90, (i / 6) * 36 - 60)
				ensure_area(cell_pos(c), 1)
				var p0 := block.size()
				var s0 := spawns.size()
				build_poi({"id": 500 + i, "type": t["type"], "tpl": t["id"], "cell": c, "n": t["name"]})
				rows.append("%s: celle occupate+%d nemici+%d" % [t["id"], block.size() - p0, spawns.size() - s0])
				i += 1
			print("TPL ", rows.size(), " modelli costruiti senza errori")
			print("TPL ", rows.slice(0, 12))
			print("TPL ", rows.slice(12, 24))
			print("TPL ", rows.slice(24, 36))
			print("TPL ", rows.slice(36))
			var mk := 0
			var micro_rows := []
			for mt in PoiData.micro:
				var mc := base + Vector2i((mk % 8) * 20 - 80, 150 + (mk / 8) * 20)
				ensure_area(cell_pos(mc), 1)
				var q0 := block.size()
				run_ops(mc, mt["ops"], false, true)
				micro_rows.append("%s+%d" % [mt["id"], block.size() - q0])
				mk += 1
			print("TPL micro ", micro_rows)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--editstest"):
		tgs += 1
		if tgs == 3:
			var cs0: Vector2i = SEEDS[0]
			edit_buckets.clear()
			edits_loaded = true
			var lst: Array = []
			for ddx in range(-12, 13, 3):
				for ddy in range(-12, 13, 3):
					lst.append(["p", "zz_test", cs0.x + ddx, cs0.y + ddy])
			lst.append(["at", cs0.x + 2, cs0.y + 2, ["e", ["skeleton"], 3, 2]])
			var kk := Vector2i(cs0.x / CH, cs0.y / CH)
			for op in lst:
				var an := edit_anchor(op)
				var ck := Vector2i(an.x / CH, an.y / CH)
				if not edit_buckets.has(ck):
					edit_buckets[ck] = []
				edit_buckets[ck].append(op)
			for ck in edit_buckets.keys():
				run_ops(Vector2i.ZERO, edit_buckets[ck], false, false)
			var n := 0
			for pr in ents.get_children():
				if pr is Prop and pr.kind == "zz_test":
					n += 1
			print("EDITS seme=", new_seed(), " sprite nuovi piazzati=", n, " (su ", lst.size() - 1, ")")
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--remtest"):
		tgs += 1
		if tgs == 3:
			var left := 0
			var tot := 0
			for r in edits_data().get("remove", []):
				tot += 1
				for n in ents.get_children():
					if n is Prop and n.kind == str(r[0]) and n.cell == Vector2i(int(r[1]), int(r[2])):
						left += 1
			print("REMTEST richiesti=", tot, " ancora presenti=", left)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--poptest"):
		tgs += 1
		if tgs == 3:
			var h1 := hash(spawns.map(func(x): return "%s%s" % [x["k"], x["pos"]]))
			var nb := block.size()
			var np := 0
			for n in ents.get_children():
				if n is Prop and n.scene:
					np += 1
			print("POPTEST seme=", world_seed, " sale=", pop_salt, " scenari(blocchi=", nb, ", oggetti=", np, ") nemici=", spawns.size(), " hash_nemici=", h1)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--desttest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			print("DEST oggetti=", dest_cells.size())
			var seen := {}
			for cc in dest_cells.keys():
				if not is_instance_valid(dest_cells[cc]):
					continue
				var pp: Prop = dest_cells[cc]
				if seen.has(pp.dd):
					continue
				seen[pp.dd] = true
				var line := "DEST %s (%s, hp %d):" % [pp.dd, pp.dm, int(pp.hp_max)]
				for fam in ["sword", "greatsword", "hammer", "dagger"]:
					var hits := int(ceil(pp.hp_max / (10.0 * 1.0 * Destruct.eff(fam, pp.dm))))
					line += " %s=%d" % [fam, hits]
				print(line)
			# prova reale: abbatti un albero e un muro di roccia
			var tc := Vector2i(-1, -1)
			for cc in dest_cells.keys():
				if is_instance_valid(dest_cells[cc]) and (dest_cells[cc] as Prop).dd == "albero":
					tc = cc
					break
			if tc.x >= 0:
				player.position = Vector2(tc) * Game.TS + Vector2(8 - 20, 8)
				var n := 0
				while dest_cells.has(tc) and n < 500:
					player.face = Vector2.RIGHT
					player.strike(29.0, 1.0, 1.0, 95.0, false)
					n += 1
				print("DEST albero abbattuto con spada in ", n, " colpi; broken=", persist["broken"].size(), " block=", block.has(tc))
			var rc := Vector2i(-1, -1)
			for y in range(20, Game.MH - 20):
				for x in range(20, Game.MW - 20):
					var cv := Vector2i(x, y)
					if terrain_breakable(cv) and biome[idx(cv)] in [0, 4, 5, 6] and is_floor(cv + Vector2i(-1, 0)):
						rc = cv
						break
				if rc.x >= 0:
					break
			if rc.x >= 0:
				player.position = Vector2(rc) * Game.TS + Vector2(8 - 20, 8)
				var n2 := 0
				while grid[idx(rc)] == 0 and n2 < 5000:
					world_strike(player.position, Vector2.RIGHT, 29.0, 1.0, 1.7, "hammer")
					n2 += 1
				print("DEST roccia bioma ", biome[idx(rc)], " col martello in ", n2, " colpi; grid=", grid[idx(rc)])
				grid[idx(rc)] = 0   # simula il ricaricamento del blocco: il taglio deve ripristinarsi
				apply_cuts(rc.x / CH, rc.y / CH)
				print("DEST persistenza taglio: grid dopo ricarica=", grid[idx(rc)])
			var tcv := Vector2i(-1, -1)
			for y in range(20, Game.MH - 20):
				for x in range(20, Game.MW - 20):
					var cv2 := Vector2i(x, y)
					if terrain_breakable(cv2) and biome[idx(cv2)] in [1, 2]:
						tcv = cv2
						break
				if tcv.x >= 0:
					break
			if tcv.x >= 0:
				var wp2 := Vector2(tcv) * Game.TS + Vector2(8, 8)
				var okp := false
				for dd in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					if is_floor(tcv + dd) and not okp:
						okp = true
						player.position = wp2 + Vector2(dd) * 18.0
						var dirv := (wp2 - player.position).normalized()
						var n3 := 0
						while grid[idx(tcv)] == 0 and n3 < 500:
							world_strike(player.position, dirv, 29.0, 1.0, 1.0, "greatsword")
							n3 += 1
						print("DEST albero del bosco bioma ", biome[idx(tcv)], " col spadone in ", n3, " colpi; grid=", grid[idx(tcv)])
			print("DEST mats=", player.mats)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--bonustest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			for t in ["farm", "church", "altar", "bandits", "tower", "cave", "well", "hamlet", "boh"]:
				poi_bonus(t, player.position)
				print("BONUS ", t, " souls=", player.souls)
			print("BONUS borsa=", player.items, " souls=", player.souls)
			var chests := 0
			var tagged := 0
			for po in pois:
				if po.get("built", false):
					pass
			for pr in props:
				if pr.kind == "chest":
					chests += 1
					if pr.has_meta("poi") and str(pr.get_meta("poi")) != "":
						tagged += 1
			print("BONUS scrigni=", chests, " di luogo=", tagged)
			var n := 0
			for pr in props:
				if pr.kind == "page" and n < 3:
					n += 1
					player.position = pr.position
			print("BONUS hint=", page_hint())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--crafttest"):
		tgs += 1
		if tgs == 3:
			state = "play"
			player.max_hp = 200.0
			player.hp = 60.0
			var nres := 0
			var kinds := {}
			for pr in props:
				if str(pr.kind).begins_with("res_"):
					nres += 1
					kinds[pr.kind] = int(kinds.get(pr.kind, 0)) + 1
			print("CRAFT nodi di raccolta nel mondo iniziale=", nres, " ", kinds)
			var node: Prop = null
			for pr in props:
				if str(pr.kind).begins_with("res_"):
					node = pr
					break
			player.position = node.position + Vector2(0, 8)
			var k0 := str(node.kind)
			interact(node)
			print("CRAFT raccolto ", k0, ": ", player.mats)
			for e in 12:
				mat_drops("deer", false)
				mat_drops("skeleton", false)
				mat_drops("wolf", true)
			for k in ["erba", "fungo", "legna", "minerale", "pelle", "carne", "osso"]:
				player.mats[k] = int(player.mats.get(k, 0)) + 14
			print("CRAFT materiali: ", player.mats)
			player.flasks = 1
			var w0: float = float(player.weapon()["b"])
			var d0 := player.dmg()
			for i in RECIPES.size():
				var before := int(player.mats.get("osso", 0))
				craft_do(i)
			print("CRAFT borsa dopo la creazione: ", player.items, " fiale=", player.flasks, " buffs=", player.buffs.keys())
			player.hp = 10.0
			var cyc: Array = []
			for k in 12:
				cyc.append(item_current())
				item_cycle()
			print("CRAFT ciclo oggetti: ", cyc)
			for k in 30:
				item_use()
				if item_ids().is_empty():
					break
			print("CRAFT borsa dopo l'uso: ", player.items)
			print("CRAFT dopo tutte le ricette: fiale=", player.flasks, " vita=", int(player.hp), " buffs=", player.buffs.keys(), " arma +", snappedf(float(player.weapon()["b"]) - w0, 0.01), " affilature=", player.weapon().get("u", 0), " reliquie=", player.relics)
			print("CRAFT danno: ", snappedf(d0, 0.1), " -> ", snappedf(player.dmg(), 0.1), " (con tonico di forza e affilatura)")
			# l'affilatura ha un tetto
			for i in 8:
				player.mats["minerale"] = 20
				player.mats["legna"] = 20
				craft_do(5)
			print("CRAFT affilatura massima: ", player.weapon().get("u", 0), " (tetto 5)")
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--keytest"):
		tgs += 1
		if tgs == 5:
			print("KEY prima: archivio=", door_lock_msg("int|archive|1|1"), " | sanatorio=", door_lock_msg("int|sanatorium|1|1"))
			var nk := 0
			var nl := 0
			for pr in props:
				if pr.kind == "key":
					nk += 1
					interact(pr)
					break
			for pr in props:
				if pr.kind == "lever":
					nl += 1
					interact(pr)
					break
			print("KEY trovati chiave=", nk, " leva=", nl)
			print("KEY dopo: archivio=[", door_lock_msg("int|archive|1|1"), "] sanatorio=[", door_lock_msg("int|sanatorium|1|1"), "]")
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--journeytest"):
		tgs += 1
		if tgs == 5:
			persist["bosses"]["boss_jailer"] = true
			for k in JOURNEY_N + 1:
				print("JOURNEY tappa ", journey_step(), " | ", objective(), " | souls=", player.souls)
				match journey_step():
					0:
						player.position = journey_target()
					1:
						pages_found = 1
					2:
						var po: Dictionary = pois[int(persist["journey_poi"])]
						po["built"] = true
						for en in po.get("spawns", []):
							en["alive"] = false
					3:
						player.lv = 3
					4:
						player.position = journey_target()
				journey_update()
			print("JOURNEY fine: ", objective())
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--eventtest"):
		tgs += 1
		if tgs == 5:
			var pc0 := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
			var n0 := enemies.size()
			event_ambush(pc0 + Vector2i(40, 0))
			print("EVENT imboscata: nemici +", enemies.size() - n0)
			var n1 := enemies.size()
			event_treasure(pc0)
			print("EVENT tesoro: cassa=", ev_chest != null, " guardiani +", enemies.size() - n1, " msg=", msg)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--secrettest"):
		tgs += 1
		if tgs == 5:
			var nd := 0
			for pr in props:
				if pr.kind == "dig":
					nd += 1
			print("SECRET tumuli nel mondo caricato=", nd)
			var made := 0
			for pr in props.duplicate():
				if pr.kind == "dig" and made < 20:
					player.position = pr.position
					var s0 := player.souls
					dig_up(pr)
					made += 1
			print("SECRET scavati=", made, " anime ora=", player.souls, " messaggio=", msg)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--landtest"):
		tgs += 1
		if tgs == 5:
			var cnt := {}
			for sdc in SEEDS:
				ensure_area(cell_pos(sdc), 3)
			for pr in ents.get_children():
				if not (pr is Prop):
					continue
				for pf in ["ruin_tower", "circle_top", "pond_top", "pond_swa", "arch_top", "stump_big", "bone_pit"]:
					if str(pr.kind).begins_with(pf):
						cnt[pf] = int(cnt.get(pf, 0)) + 1
			print("LAND strutture nuove nel mondo caricato: ", cnt, " (props totali ", props.size(), ")")
			var pc1 := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS)) + Vector2i(0, 12)
			for nm1 in ["ruin_tower_0", "circle_top_0", "pond_top_0", "pond_swa_0", "arch_top_0", "stump_big_0", "bone_pit_0"]:
				var f1 := tex_fp(nm1)
				var sp1 := free_spot(pc1, f1)
				print("LAND ", nm1, " fp=", f1, " spot=", sp1)
				pc1 += Vector2i(8, 0)
			get_tree().quit()
	if OS.get_cmdline_user_args().has("--gatetest"):
		_gatetest()
	if OS.get_cmdline_user_args().has("--padgame"):
		_padgame()
	if OS.get_cmdline_user_args().has("--mapdump"):
		_mapdump()
	if OS.get_cmdline_user_args().has("--padtest"):
		_pad_test()
	if OS.get_cmdline_user_args().has("--zoomtest"):
		_zoom_test()
	if OS.get_cmdline_user_args().has("--menus"):
		_menus_test()
	if OS.get_cmdline_user_args().has("--scale"):
		_scale_test()
	if OS.get_cmdline_user_args().has("--spike"):
		_spike()
	if OS.get_cmdline_user_args().has("--perf"):
		_perf()
	if OS.get_cmdline_user_args().has("--selftest8"):
		_selftest8()
	if OS.get_cmdline_user_args().has("--selftest7"):
		_selftest7()
	if OS.get_cmdline_user_args().has("--selftest6"):
		_selftest6()
	if OS.get_cmdline_user_args().has("--selftest5"):
		_selftest5()
	if OS.get_cmdline_user_args().has("--selftest4"):
		_selftest4()
	if OS.get_cmdline_user_args().has("--selftest3"):
		_selftest3()
	if OS.get_cmdline_user_args().has("--selftest2"):
		_selftest2()
	if OS.get_cmdline_user_args().has("--selftest"):
		_selftest()
	var now := Time.get_ticks_msec()
	var real := (now - last_ms) / 1000.0
	last_ms = now
	t += real
	if hitstop_t > 0.0:
		hitstop_t -= real
		Engine.time_scale = 0.2
	else:
		Engine.time_scale = 1.0
	msg_t -= real
	if over_t > 0.0:
		over_t -= real
	if state == "dying":
		death_t -= real
		if death_t <= 0.0:
			if run_mode and run_revives <= 0:
				end_run(false)
			else:
				if run_mode:
					run_revives -= 1
				respawn()
	if state == "win" and over_t <= 0.0 and Input.is_action_just_pressed("restart") and not run_mode:
		new_cycle()
	if run_mode and player != null and state == "play" and area == "world":
		run_update(real)
	if chain > 0 and state == "play":
		chain_t -= real
		if chain_t <= 0.0:
			chain = 0
	# ambiente per regione
	if player != null and area == "world":
		var pc := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
		if inb(pc):
			var bi: int = biome[idx(pc)]
			if bi != cur_bio:
				cur_bio = bi
				sfx_node.ambient(str(bi))
				amb_target = Game.BIO[bi]["amb"]
				if state == "play":
					say(Game.BIO[bi]["n"])
	if player != null and state == "play" and area != "":
		if not free_at(player.position, player.radius):
			stuck_t += real
			if stuck_t > 0.4:
				var pc2 := Vector2i(floori(player.position.x / Game.TS), floori(player.position.y / Game.TS))
				player.position = cell_pos(free_near(pc2))
				stuck_t = 0.0
		else:
			stuck_t = 0.0
	if fog_mat != null and player != null:
		var ft := 0.0
		if area == "world" and cur_bio >= 0 and cur_bio < FOG_BIO.size():
			ft = FOG_BIO[cur_bio]
		elif area != "" and area != "world":
			ft = 0.12
		fog_d = lerpf(fog_d, ft, 1.0 - exp(-real * 1.2))
		fog_mat.set_shader_parameter("dens", fog_d)
		fog_mat.set_shader_parameter("cam", player.cam.get_screen_center_position())
		fog_mat.set_shader_parameter("zoom", player.cam.zoom.x)
		fog_rect.visible = fog_d > 0.01 and not pf_nofog
	if player != null and state == "play" and area == "world":
		day_t = fposmod(day_t + real / DAY_LEN, 1.0)
	update_weather(real)
	var bk: float = BRIGHT[clampi(int(settings["bright"]), 0, 5)]
	var tgt := Color(minf((amb_target.r * 1.32 + 0.035) * bk, 1.0), minf((amb_target.g * 1.34 + 0.04) * bk, 1.0), minf((amb_target.b * 1.45 + 0.05) * bk, 1.0))
	if area == "world":
		var dl := day_light()
		var dk := lerpf(0.52, 1.08, dl)
		if weather == "rain":
			dk *= 0.88
		var nt := Color(0.8, 0.87, 1.2).lerp(Color.WHITE, dl)
		tgt = Color(minf(tgt.r * dk * nt.r, 1.0), minf(tgt.g * dk * nt.g, 1.0), minf(tgt.b * dk * nt.b, 1.0))
	if area == "world":
		tgt = tgt * Chrono.world_tint()   # l'era cambia il colore del mondo
	cm.color = cm.color.lerp(tgt, 1.0 - exp(-real * 1.6))
	if wr_node != null and is_instance_valid(wr_node):
		wr_node.set_boost(cm.color)
	if player != null and state == "play":
		prompt = ""
		prompt2 = ""
		near_obj = null
		var bd := 22.0
		for p in props:
			var pp: Vector2 = p.position
			if p.kind == "gate_top":
				pp = cell_pos(p.cell + Vector2i(0, 1))
			elif p.kind == "stairs_top":
				pp = cell_pos(p.cell + Vector2i(1, 1))
			elif p.kind == "bed_top":
				pp = p.position + Vector2(16, -10)
			if INTERACT.has(p.kind) and pp.distance_to(player.position) < bd:
				bd = pp.distance_to(player.position)
				near_obj = p
		for v in villagers:
			if v.visible and v.position.distance_to(player.position) < bd:
				bd = v.position.distance_to(player.position)
				near_obj = v
		if near_obj != null:
			match near_obj.kind:
				"bonfire":
					prompt = "E  DORMI QUI" if near_obj.lit else "E  ALLESTISCI IL CAMPO"
				"dig":
					prompt = "E  SCAVA"
				"bed_top":
					prompt = "E  DORMI NEL LETTO"
				"elder", "npc":
					prompt = "E  PARLA"
				"door":
					prompt = "E  ENTRA"
				"exit":
					prompt = "E  ESCI"
				"loot":
					var it: Dictionary = near_obj.item
					if it["k"] == "shard":
						prompt = ""
					elif it["k"] == "relic":
						prompt = "E  PRENDI  RELIQUIA: %s" % Relics.info(str(it["id"]))["n"]
						prompt2 = str(Relics.info(str(it["id"]))["d"])
					elif it["k"] == "tome":
						prompt = "E  IMPARA  Tomo: %s" % Rpg.SPELLS[it["s"]]["n"]
						prompt2 = str(Rpg.SPELLS[it["s"]]["d"]).to_upper()
					else:
						prompt = "E  PRENDI  %s  [%s]" % [Rpg.wname(it), Rpg.RARITY[int(it["r"])]["n"]]
						prompt2 = Rpg.wdesc(it)
				"res_erba", "res_fungo", "res_legna", "res_minerale":
					prompt = "E  RACCOGLI " + str(MAT_NAMES[str(near_obj.kind).substr(4)])
				"villager":
					prompt = "E  PARLA"
				"qitem":
					prompt = "E  RACCOGLI"
				"gate_top":
					prompt = "E  APRI IL CANCELLO"
				"stairs_top":
					prompt = "E  SCENDI LA SCALA"
				"bell":
					prompt = "E  SUONA LA CAMPANA (SFIDA)"
				"shrine":
					prompt = "E  L'ALTARE E' SAZIO" if near_obj.opened else "E  OFFRI %d ANIME (RELIQUIA)" % int(near_obj.item.get("cost", 200))
				"key":
					prompt = "E  PRENDI LA CHIAVE DEI SIGILLI"
				"lever":
					prompt = "E  TIRA LA LEVA"
				"portal":
					prompt = "E  ESCI" if near_obj.dest == "world" else ("E  ENTRA" if near_obj.dest != "dF" or guardians >= 3 else "E  SIGILLATO")
			if use_pad and prompt.begins_with("E  "):
				prompt = "A  " + prompt.substr(3)
			if Input.is_action_just_pressed("interact"):
				interact(near_obj)
		if lock_pos.x > -9000.0 and lock_pos.distance_to(player.position) > 30.0:
			lock_pos = Vector2(-9999.0, -9999.0)
		if lock_pos.x < -9000.0:
			if area == "world":
				for d in doors:
					var dp: Vector2 = d["pos"]
					var dy: float = player.position.y - dp.y
					if absf(player.position.x - dp.x) < float(d["hw"]) and dy > 0.0 and dy < 15.0:
						var lk := door_lock_msg(str(d["dest"]))
						if lk != "":
							say(lk)
							lock_pos = dp
							break
						returns[d["dest"]] = d["cell"]
						change_area(d["dest"])
						break
			elif area.begins_with("int|"):
				if player.position.distance_to(cell_pos(exit_cell)) < 9.0:
					change_area("world")
		if stain != null and stain.position.distance_to(player.position) < 12.0:
			var sg: int = stain_data["souls"]
			player.souls += sg
			popup(player.position + Vector2(0, -18), "+%d" % sg, Color(0.5, 1, 0.8))
			var lost: Dictionary = stain_data.get("relics", {})
			if lost.size() > 0:
				for rk2 in lost:
					relic_gain(rk2, int(lost[rk2]))
				player.apply_stats()
				say("RIPRENDI LE ANIME E LE RELIQUIE PERDUTE")
			stain.queue_free()
			stain = null
			stain_data = {}
		boss = null
		for e in enemies:
			if e.awake and (e.is_boss or (e.champ and e.position.distance_to(player.position) < 170.0)):
				boss = e
				break
	if player != null:
		shake_v *= pow(0.02, real)
		# la telecamera si allinea ai pixel interi: terreno e oggetti restano fermi l'uno rispetto all'altro
		# contro il Campanaro la visuale si sposta verso di lui, cosi' il corpo resta in quadro
		var cam_t := Vector2.ZERO
		if colossus != null and is_instance_valid(colossus) and not colossus.dead and colossus.state != "sleep":
			cam_t = ((colossus.position + Vector2(0, -60)) - player.position) * 0.5
			cam_t = cam_t.limit_length(110.0)
		player.cam.position = player.cam.position.lerp(cam_t, 1.0 - pow(0.08, real))
		var cam_base: Vector2 = player.cam.get_screen_center_position() - player.cam.offset
		var cam_snap: Vector2 = cam_base.round() - cam_base
		var cam_shk := (Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_v).round() if shake_v > 0.4 else Vector2.ZERO
		player.cam.offset = cam_snap + cam_shk
		for p in props.duplicate():
			if p.kind == "loot" and p.item.get("k", "") == "shard" and p.position.distance_to(player.position) < 34.0:
				take_item(p)
				continue
			if p.kind == "chest" and not p.opened and p.position.distance_to(player.position) < 14.0:
				p.opened = true
				persist["opened"][key(p.cell)] = true
				if p.has_meta("poi") and str(p.get_meta("poi")) != "":
					poi_bonus(str(p.get_meta("poi")), p.position)
				p.spr.modulate = Color(0.5, 0.45, 0.55)
				burst(p.position, Color(1, 0.8, 0.3), 20, 60.0, 0.6)
				chest_loot(p)
	if player != null and state == "play" and area == "world":
		stream_update()
		spawn_t -= real
		if spawn_t <= 0.0:
			spawn_t = 0.5
			spawn_tick()
			poi_tick()
			world_event_update(0.5)
	if player != null and state == "play":
		quest_update()
		journey_update()
	if player != null and state == "play" and area == "world":
		arena_update(real)
	if player != null and state == "play":
		wake_t -= real
		if wake_t <= 0.0:
			wake_t = 0.15
			for en in enemies:
				if not en.awake and en.position.distance_squared_to(player.position) < 12100.0 * (1.0 + 0.5 * (1.0 - day_light())) / (player.cam.zoom.x * player.cam.zoom.x):
					en.awake = true
					en.set_process(true)
			for cr in critters:
				cr.set_process(cr.position.distance_squared_to(player.position) < 160000.0)
		collect_pages()
		update_minimap(real)
		horde_update(real)
		inv_pad_update(real)
	if Engine.get_process_frames() % 2 == 0:
		for f in flick:
			f[2] += real * 22.0
			(f[0] as PointLight2D).energy = f[1] * (1.0 + sin(f[2]) * 0.07 + sin(f[2] * 2.7) * 0.05 + randf() * 0.04)
