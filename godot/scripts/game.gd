class_name Game
extends RefCounted
## Costanti e utilita' condivise.

const TS := 16
static var MW := 80
static var MH := 60

# righe dell'atlante tiles.png (4 varianti per riga)
const T_CRIPTA := 0
const T_RUNE := 1
const T_SANGUE := 2
const T_SCACCHI := 3
const T_MURO := 4
const T_CIMA := 5
const T_TAPPETO := 6
const T_CIMITERO := 7
const T_TERRA := 8
const T_PALUDE := 9
const T_NEVE := 10
const T_LAVA := 11
const T_CHIOMA := 12
const T_ACQUA := 13
const T_ROCCIA := 14
const T_ROCCIAG := 15
const T_MAGMA := 16
const T_SENTIERO := 17

# regioni del mondo: n nome, g terreni, b blocco, thr soglia rumore (alta = aperto), amb luce ambiente,
# pool nemici, tint colore nemici, dec decorazioni, tier pericolo
static var BIO: Array = _mk_bio()


static func _mk_bio() -> Array:
	return [
		{"n": "VILLAGGIO DI CENERE", "g": [T_TERRA], "b": T_ROCCIA, "thr": 0.9, "amb": Color(0.20, 0.19, 0.27),
			"pool": ["goblin", "goblin", "kobold", "kobold", "goblin_archer", "skeleton", "skel_runner", "rat", "wolf"], "tint": Color.WHITE, "dec": ["barrel", "deadtree", "gravestone"], "tier": 0},
		{"n": "CIMITERO PIANGENTE", "g": [T_CIMITERO], "b": T_CHIOMA, "thr": 0.42, "amb": Color(0.19, 0.22, 0.40),
			"pool": ["skeleton", "ghoul", "wraith", "bat", "zombie", "skel_archer", "crow", "ghoul_pale", "zombie_bloated", "goblin_shaman", "harpy"], "tint": Color(0.9, 0.95, 1.1),
			"dec": ["gravestone", "gravestone", "statue", "deadtree", "tomb"], "tier": 1},
		{"n": "FORESTA DEGLI IMPICCATI", "g": [T_TERRA, T_CIMITERO], "b": T_CHIOMA, "thr": 0.12, "amb": Color(0.16, 0.20, 0.21),
			"pool": ["goblin", "goblin", "goblin_archer", "goblin_shaman", "troll", "wolf", "wolf_dire", "spider", "spider_brood", "cultist", "orc", "goblin_boss"], "tint": Color(0.8, 0.95, 0.8),
			"dec": ["deadtree", "deadtree", "skullpile", "coffin"], "tier": 2},
		{"n": "PALUDE MARCESCENTE", "g": [T_PALUDE], "b": T_ACQUA, "thr": 0.14, "amb": Color(0.20, 0.32, 0.28),
			"pool": ["lizardman", "lizardman", "troll", "ooze", "toad", "spider", "zombie_bloated", "kobold", "ghoul", "harpy"], "tint": Color(0.85, 1.05, 0.85),
			"dec": ["deadtree", "skullpile", "deadtree"], "tier": 2},
		{"n": "CATTEDRALE IN ROVINA", "g": [T_SCACCHI, T_CRIPTA], "b": T_MURO, "thr": 0.28, "amb": Color(0.27, 0.19, 0.30),
			"pool": ["orc", "orc", "orc_warlord", "harpy", "gargoyle", "cultist", "wraith", "skel_archer", "gargoyle_obs", "cult_zealot", "ogre"], "tint": Color(1.1, 0.95, 1.1),
			"dec": ["pillar", "pillar", "statue", "candelabra", "tomb"], "tier": 3},
		{"n": "VETTA GELATA", "g": [T_NEVE], "b": T_ROCCIAG, "thr": 0.26, "amb": Color(0.21, 0.26, 0.40),
			"pool": ["troll_frost", "troll_frost", "ogre", "harpy", "wolf", "wolf_dire", "wisp", "wraith", "skel_brute", "gargoyle_obs"], "tint": Color(0.75, 0.9, 1.4),
			"dec": ["statue", "skullpile", "pillar"], "tier": 4},
		{"n": "QUARTIERE DELLE FONDERIE", "g": [T_LAVA], "b": T_MAGMA, "thr": 0.52, "amb": Color(0.30, 0.21, 0.19),
			"pool": ["orc", "orc_warlord", "ogre", "kobold", "kobold", "imp", "imp_cinder", "gargoyle", "cultist", "cult_zealot", "skel_brute"], "tint": Color(1.2, 0.9, 0.8),
			"dec": ["barrel", "brazier", "skullpile"], "tier": 4},
	]

static var _cache := {}
static var _tones := {}


## tono di colore del bioma per gli oggetti di scena (meta' strada tra bianco e la tinta del bioma)
static func tone(b: int) -> Color:
	if not _tones.has(b):
		var t: Color = BIO[clampi(b, 0, BIO.size() - 1)]["tint"]
		_tones[b] = Color.WHITE.lerp(t, 0.6)
	return _tones[b]
static var photo := false      # grafica FOTO (prova): sprite da assets/sprites_photo, se presenti
static var _light: Texture2D


## numero pseudo-casuale deterministico in [0,1): non consuma il generatore globale (i mondi salvati restano uguali)
static func hh(x: int, y: int, s := 0) -> float:
	var v: int = (x * 374761393 + y * 668265263 + s * 1274126177) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float((v ^ (v >> 16)) & 0xffff) / 65536.0


static func tint(x: int, y: int, amt: float) -> Color:
	return Color(1.0 + (hh(x, y, 1) - 0.5) * 2.0 * amt, 1.0 + (hh(x, y, 2) - 0.5) * 2.0 * amt, 1.0 + (hh(x, y, 3) - 0.5) * 2.0 * amt)


static var _font: Font


static func font() -> Font:
	if _font == null:
		var f = load("res://assets/ui/pixel.fnt")
		if f is FontFile:
			f.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
			_font = f
		else:
			_font = ThemeDB.fallback_font
	return _font


static func tex(n: String) -> Texture2D:
	if not _cache.has(n):
		var path := "res://assets/sprites/%s.png" % n
		var ph := "res://assets/sprites_photo/%s.png" % n
		if photo and ResourceLoader.exists(ph):
			_cache[n] = load(ph)
		elif ResourceLoader.exists(path):
			_cache[n] = load(path)
		else:
			# sprite aggiunti con l'editor: PNG grezzi in assets/custom (o user://sprites)
			var img: Image = null
			for base in ["res://assets/custom/", "user://sprites/"]:
				if FileAccess.file_exists(base + n + ".png"):
					img = Image.load_from_file(base + n + ".png")
					break
			_cache[n] = ImageTexture.create_from_image(img) if img != null else load(path)
	return _cache[n]


## parametri del terreno fotografico per lo shader del suolo
static func photo_ground(mat: ShaderMaterial) -> void:
	var on := photo and ResourceLoader.exists("res://assets/photo/ground_a.png")
	mat.set_shader_parameter("photo_on", on)
	if on:
		for k in [["photo_ga", "ground_a"], ["photo_ma", "ground_b"], ["photo_path", "path_cem"], ["photo_cob", "cobble"]]:
			var path := "res://assets/photo/%s.png" % k[1]
			if ResourceLoader.exists(path):
				mat.set_shader_parameter(k[0], load(path))


static func light_tex() -> Texture2D:
	if _light == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_light = t
	return _light


static func setup_input() -> void:
	var m := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_SPACE, KEY_J], "dash": [KEY_SHIFT, KEY_K], "restart": [KEY_R, KEY_ENTER], "heavy": [KEY_L], "flask": [KEY_Q, KEY_F], "interact": [KEY_E], "zoom": [KEY_V], "lock": [KEY_Y], "parry": [KEY_C], "swap": [KEY_TAB], "spell1": [KEY_1, KEY_R], "spell2": [KEY_2, KEY_G], "item_next": [KEY_Z], "item_use": [KEY_X],
		"aim_left": [], "aim_right": [], "aim_up": [], "aim_down": [],
	}
	for a in m:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in m[a]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(a, e)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	# --- controller (Xbox/PlayStation): stick sinistro e croce = movimento
	_jaxis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_jaxis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_jaxis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_jaxis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_jbtn("move_left", JOY_BUTTON_DPAD_LEFT)
	_jbtn("move_right", JOY_BUTTON_DPAD_RIGHT)
	# croce su: non muove piu' (c'e' lo stick) ma cambia modalita' Orda/Tattica
	_jbtn("move_down", JOY_BUTTON_DPAD_DOWN)
	_jaxis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_jaxis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_jaxis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_jaxis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_jbtn("attack", JOY_BUTTON_RIGHT_SHOULDER)
	_jaxis("heavy", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_jbtn("dash", JOY_BUTTON_B)
	_jbtn("interact", JOY_BUTTON_A)
	_jbtn("flask", JOY_BUTTON_X)
	_jbtn("swap", JOY_BUTTON_Y)
	_jbtn("spell1", JOY_BUTTON_LEFT_SHOULDER)
	_jaxis("spell2", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_jbtn("zoom", JOY_BUTTON_DPAD_UP)
	_jbtn("lock", JOY_BUTTON_RIGHT_STICK)   # R3: aggancia il nemico (mira manuale), premuto di nuovo passa al successivo
	_jbtn("parry", JOY_BUTTON_LEFT_STICK)
	_jaxis("item_use", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_jbtn("ui_accept", JOY_BUTTON_A)
	_jbtn("ui_cancel", JOY_BUTTON_B)
	_jbtn("restart", JOY_BUTTON_START)
	_jbtn("restart", JOY_BUTTON_A)
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		InputMap.action_set_deadzone(a, 0.25)
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(a, 0.25)
	InputMap.action_set_deadzone("heavy", 0.5)
	InputMap.action_set_deadzone("spell2", 0.5)
	var rb := InputEventMouseButton.new()
	rb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("heavy", rb)


static func _jbtn(action: String, idx: int) -> void:
	var e := InputEventJoypadButton.new()
	e.device = -1  # qualsiasi controller
	e.button_index = idx
	InputMap.action_add_event(action, e)


static func _jaxis(action: String, axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = -1  # qualsiasi controller
	e.axis = axis
	e.axis_value = value
	InputMap.action_add_event(action, e)


static func make_light(parent: Node, pos: Vector2, color: Color, scale_: float, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex()
	l.color = color
	l.texture_scale = scale_
	l.energy = energy
	l.position = pos
	parent.add_child(l)
	return l


static func make_fire(parent: Node, pos: Vector2, big := false) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = 10 if big else 6
	p.lifetime = 0.55
	p.direction = Vector2(0, -1)
	p.spread = 14.0
	p.gravity = Vector2(0, -14)
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 10.0
	p.scale_amount_min = 1.2
	p.scale_amount_max = 2.4 if big else 2.0
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.95, 0.5), Color(1, 0.45, 0.1), Color(0.5, 0.05, 0.05, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = g
	parent.add_child(p)
	return p
