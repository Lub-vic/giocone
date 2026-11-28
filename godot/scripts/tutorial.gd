extends RefCounted
## Tutorial mentre si gioca: un suggerimento alla volta in basso, senza fermare il gioco. Compare quando serve e
## sparisce appena si fa l'azione (o dopo un po'). Chi l'azione la fa prima non lo vede. In cella solo le basi; i
## comandi che servono all'aperto (prima persona, zoom, mappa) arrivano solo una volta usciti. Il Cronotone non c'e':
## lo presenta "POWER UP!". I tasti sono quelli del dispositivo in uso, anche se rimappati.

const SHOW_MAX := 12.0     # dopo tanto il suggerimento se ne va da solo
const DONE_HOLD := 0.8     # azione fatta: resta ancora un attimo, in verde
const GAP := 2.5           # respiro fra un suggerimento e l'altro
const NEAR := 150.0        # "c'e' un nemico vicino"

# in ordine di precedenza
const BASE := ["move", "aim", "attack", "dash", "parry", "heavy", "spell", "lock", "flask", "interact", "swap", "item", "bag", "pause"]
const OUT := ["view", "zoom", "rally", "camera", "map"]

static var cur := ""
static var cur_t := 0.0
static var done_t := -1.0
static var gap_t := 1.5
static var moved_t := 0.0
static var out_t := 0.0


## l'eroe sta facendo l'azione del suggerimento?
static func _did(m, id: String, dt: float) -> bool:
	match id:
		"move":
			if m.state == "play" and Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.4:
				moved_t += dt
			return moved_t > 1.2
		"aim":
			if m.use_pad:
				return Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down").length() > 0.5
			return cur == "aim" and cur_t > 4.0
		"attack":
			return Input.is_action_just_pressed("attack")
		"heavy":
			return Input.is_action_just_pressed("heavy")
		"dash":
			return Input.is_action_just_pressed("dash")
		"parry":
			return Input.is_action_just_pressed("parry")
		"spell":
			return Input.is_action_just_pressed("spell1") or Input.is_action_just_pressed("spell2")
		"lock":
			return Input.is_action_just_pressed("lock")
		"flask":
			return Input.is_action_just_pressed("flask")
		"interact":
			return Input.is_action_just_pressed("interact")
		"swap":
			return m.state == "play" and Input.is_action_just_released("swap")
		"bag":
			return m.inv_open
		"item":
			return Input.is_action_just_pressed("item_use")
		"pause":
			return m.state == "pause"
		"camera":
			return Input.is_action_just_pressed("camera_zoom")
		"rally":
			return m.player.zmode == 2 and Input.is_action_just_pressed("attack")
		"view":
			return m.skin is W3DSkin and m.skin.fpv
		"zoom":
			return m.player.zmode > 0
		"map":
			return m.state == "map"
	return false


static func _enemies_near(m) -> int:
	var n := 0
	for e in m.enemies:
		if is_instance_valid(e) and e.awake and not e.dying and e.position.distance_to(m.player.position) < NEAR:
			n += 1
	return n


## e' il momento di suggerirlo?
static func _wanted(m, id: String, near: int) -> bool:
	var p = m.player
	match id:
		"move":
			return true
		"aim":
			return m.manual_aim() and near > 0
		"attack", "dash", "parry":
			return near > 0
		"heavy", "spell":
			return near > 0 and m.persist["tuto"].has("attack")
		"lock":
			return m.manual_aim() and near > 0 and m.persist["tuto"].has("attack")
		"flask":
			return p.flasks > 0 and p.hp < p.max_hp * 0.65
		"interact":
			return str(m.prompt) != ""
		"swap":
			return p.wslots[1 - p.wcur] != null
		"bag":
			return near == 0 and p.kills >= 3
		"view":
			return near == 0 and out_t > 3.0
		"zoom":
			return near >= 4
		"map":
			return near == 0 and m.persist["tuto"].has("view")
		"item":
			return not m.item_ids().is_empty()
		"pause":
			return near == 0 and m.persist["tuto"].has("move") and m.persist["tuto"].has("attack")
		"camera":
			return near == 0 and m.persist["tuto"].has("map") and _key(m, "camera_zoom") != "-"
		"rally":
			return p.zmode == 2
	return false


## i suggerimenti possibili dove si trova l'eroe
static func _pool(m) -> Array:
	if m.side_scroll_active:
		return []
	var sk = m.skin
	if sk is W3DSkin:
		if sk.ufo_show_active() or (sk.cine != null and sk.cine.active):
			return []
		if m.area == "world" and sk.world_on:
			return OUT + BASE      # le basi restano valide per chi non le ha ancora usate
	return BASE if m.area == "d0" else []


static func tick(m, dt: float) -> void:
	if m.testing and not OS.get_cmdline_user_args().has("--tutotest"):
		return
	if m.player == null or not m.state in ["play", "map", "pause"]:
		return
	if not m.persist.has("tuto"):
		m.persist["tuto"] = {}
		cur = ""
		gap_t = 1.5
		moved_t = 0.0
		out_t = 0.0
	var seen: Dictionary = m.persist["tuto"]
	var pool := _pool(m)
	if m.area == "world" and m.state == "play" and not pool.is_empty():
		out_t += dt
	# chi usa un comando prima del suggerimento non lo vedra'
	for id in pool:
		if id != cur and not seen.has(id) and not id in ["move", "aim", "interact", "swap"] and _did(m, id, dt):
			seen[id] = true
	if cur != "":
		cur_t += dt
		if done_t >= 0.0:
			done_t -= dt
			if done_t < 0.0:
				cur = ""
				gap_t = GAP
		elif _did(m, cur, dt):
			seen[cur] = true
			done_t = DONE_HOLD
		elif cur_t > SHOW_MAX:
			seen[cur] = true
			cur = ""
			gap_t = GAP
		elif not pool.has(cur):
			cur = ""      # cambiata scena: tornera' quando serve
		return
	if pool.is_empty():
		return
	gap_t -= dt
	if gap_t > 0.0 or m.state != "play":
		return
	var near := _enemies_near(m)
	# appena usciti, la prima persona ha la precedenza: gli altri suggerimenti aspettano
	if pool.has("view") and not seen.has("view") and near == 0 and out_t <= 3.0:
		return
	for id in pool:
		if not seen.has(id) and _wanted(m, id, near):
			cur = id
			cur_t = 0.0
			done_t = -1.0
			return


## tasto di un'azione per il dispositivo in uso
static func _key(m, action: String) -> String:
	return Keybinds.pad_text(action) if m.use_pad else Keybinds.key_text(action)


## [tasti, che cosa fa]: ogni tasto va in un suo cerchio
static func tip(m, id: String) -> Array:
	var pad: bool = m.use_pad
	match id:
		"move":
			if pad:
				return [["LS"], "MUOVITI"]
			return [["%s%s%s%s" % [_key(m, "move_up"), _key(m, "move_left"), _key(m, "move_down"), _key(m, "move_right")]], "MUOVITI"]
		"aim":
			return [["RS" if pad else "MOUSE"], "MIRA"]
		"attack":
			return [[_key(m, "attack")] if pad else ["CLICK"], "COLPISCI"]
		"heavy":
			return [[_key(m, "heavy")] if pad else ["CLICK DX"], "COLPO PESANTE"]
		"dash":
			return [[_key(m, "dash")], "ROTOLA PER SCHIVARE"]
		"parry":
			return [[_key(m, "parry")], "PARA AL MOMENTO GIUSTO"]
		"spell":
			return [[_key(m, "spell1"), _key(m, "spell2")], "MAGIE"]
		"lock":
			return [[_key(m, "lock")], "AGGANCIA IL NEMICO"]
		"flask":
			return [[_key(m, "flask")], "BEVI LA FIALA PER CURARTI"]
		"interact":
			return [[_key(m, "interact")], "INTERAGISCI"]
		"swap":
			return [[_key(m, "swap")], "CAMBIA ARMA"]
		"bag":
			return [["SELECT" if pad else "I"], "TIENI PREMUTO: BORSA" if pad else "APRI LA BORSA"]
		"item":
			return [[_key(m, "item_next"), _key(m, "item_use")], "OGGETTI: SCEGLI E USA"]
		"pause":
			return [["START" if pad else "ESC"], "PAUSA"]
		"camera":
			return [[_key(m, "camera_zoom")], "ZOOM DELLA CAMERA"]
		"rally":
			return [[_key(m, "attack"), _key(m, "heavy")], "ORDINI: MANDA / RICHIAMA"]
		"view":
			return [[_key(m, "view")], "PRIMA PERSONA (E RITORNO)"]
		"zoom":
			return [[_key(m, "zoom")], "ZOOM ORDA / TATTICA"]
		"map":
			return [["START" if pad else "M"], "POI SCEGLI MAPPA" if pad else "GUARDA LA MAPPA"]
	return [[], ""]


## cerchio col tasto (si allunga solo se il nome non ci sta), sfondo nero
static func _badge(hud, x: float, cy: float, w: float, edge: Color, a: float) -> void:
	var r := 9.0
	var left := Vector2(x + r, cy)
	var right := Vector2(x + w - r, cy)
	for step in [[r + 1.0, Color(edge, a)], [r - 0.5, Color(0, 0, 0, a)]]:
		var rr: float = step[0]
		hud.draw_circle(left, rr, step[1])
		hud.draw_circle(right, rr, step[1])
		hud.draw_rect(Rect2(left.x, cy - rr, right.x - left.x, rr * 2.0), step[1])


static func draw(hud) -> void:
	var m = hud.main
	if cur == "" or m.state != "play" or m.inv_open or m.side_scroll_active:
		return
	var t := tip(m, cur)
	var keys: Array = t[0]
	var font: Font = hud.font
	var widths: Array = []
	var total := 0.0
	for k in keys:
		var kw := font.get_string_size(str(k).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
		var bw := maxf(18.0, roundf(kw) + 10.0)
		widths.append(bw)
		total += bw + 4.0
	total += 3.0 + font.get_string_size(str(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var size: Vector2 = hud.size
	var a := clampf(cur_t * 4.0, 0.0, 1.0)
	var x := roundf((size.x - total) / 2.0)
	var cy := roundf(size.y * 0.82 + (1.0 - a) * 6.0)
	var done := done_t >= 0.0
	var edge := Color(0.45, 1.0, 0.55) if done else Color(1.0, 0.82, 0.35).lerp(Color.WHITE, 0.35 + 0.35 * sin(cur_t * 6.0))
	for i in keys.size():
		var bw: float = widths[i]
		_badge(hud, x, cy, bw, edge, a)
		hud._txt(str(keys[i]), Vector2(x, cy + 3.0), Color(1, 1, 1, a), 8, HORIZONTAL_ALIGNMENT_CENTER, bw)
		x += bw + 4.0
	hud._txt(str(t[1]), Vector2(x + 3.0, cy + 3.0), Color(1, 1, 1, a))
