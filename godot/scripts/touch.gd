class_name TouchControls
extends Control
## Comandi touch (solo su schermi touch, o con --touch per le prove).
## Su schermi piu' larghi del 16:9 i comandi stanno nelle due bande laterali, fuori dall'area di gioco;
## altrimenti si sovrappongono ai bordi del gioco. Nei menu i pulsanti si comportano come un controller.

var main
var stick_id := -1
var stick_c := Vector2.ZERO
var stick_v := Vector2.ZERO
var held := {}                     # dito -> indice del pulsante premuto
var side := 0.0                    # larghezza di ogni banda laterale (0 = nessuna banda)
var r_stick := 26.0
var play_btns: Array = []
var menu_btns: Array = []
const GAME_W := 480.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _layout() -> void:
	var vs := get_viewport_rect().size
	var s := floorf((vs.x - GAME_W) / 2.0)
	if s == side and not play_btns.is_empty():
		return
	side = s
	var panels := s >= 44.0
	# l'interfaccia del gioco resta nella parte centrale 480x270
	main.hud.set_anchors_preset(Control.PRESET_TOP_LEFT)
	main.hud.position = Vector2(maxf(s, 0.0), 0)
	main.hud.size = Vector2(GAME_W, vs.y)
	var lx := s * 0.5 if panels else 40.0                 # centro colonna sinistra
	var rx := vs.x - (s * 0.5 if panels else 40.0)       # centro colonna destra
	var big := clampf(s * 0.5 - 6.0, 13.0, 20.0) if panels else 20.0
	var med := big * 0.75
	var sm := big * 0.6
	r_stick = clampf(s * 0.5 - 4.0, 20.0, 30.0) if panels else 30.0
	# [testo, azione, centro, raggio, colore]
	play_btns = [
		["ATT", "attack", Vector2(rx, 222), big, Color(0.95, 0.75, 0.4)],
		["PES", "heavy", Vector2(rx, 178), med, Color(0.95, 0.5, 0.3)],
		["ROT", "dash", Vector2(rx, 140), med, Color(0.6, 0.85, 1.0)],
		["E", "interact", Vector2(rx, 104), med, Color(0.9, 0.9, 0.9)],
		["ARM", "swap", Vector2(rx, 72), sm, Color(0.85, 0.85, 0.7)],
		["II", "pad:START", Vector2(rx, 18), sm * 0.85, Color(0.8, 0.8, 0.9)],
		["BOR", "key:I", Vector2(rx, 44), sm * 0.85, Color(0.8, 0.8, 0.9)],
		["1", "spell1", Vector2(lx, 52), med, Color(0.7, 0.6, 1.0)],
		["2", "spell2", Vector2(lx, 90), med, Color(0.7, 0.6, 1.0)],
		["FIA", "flask", Vector2(lx, 126), sm, Color(1.0, 0.7, 0.3)],
		["OGG", "item_use", Vector2(lx, 156), sm, Color(0.6, 1.0, 0.7)],
		["MAP", "key:M", Vector2(lx, 18), sm * 0.85, Color(0.8, 0.8, 0.9)],
		["CRO", "summon", Vector2(lx, 188), sm, Color(0.5, 0.95, 1.0)],
	]
	if not panels:   # schermo 16:9: comandi sopra i bordi del gioco, piu' in basso
		play_btns = [
			["ATT", "attack", Vector2(440, 222), 20.0, Color(0.95, 0.75, 0.4)],
			["PES", "heavy", Vector2(402, 242), 14.0, Color(0.95, 0.5, 0.3)],
			["ROT", "dash", Vector2(400, 202), 14.0, Color(0.6, 0.85, 1.0)],
			["E", "interact", Vector2(442, 176), 13.0, Color(0.9, 0.9, 0.9)],
			["1", "spell1", Vector2(364, 230), 12.0, Color(0.7, 0.6, 1.0)],
			["2", "spell2", Vector2(366, 196), 12.0, Color(0.7, 0.6, 1.0)],
			["FIA", "flask", Vector2(458, 140), 11.0, Color(1.0, 0.7, 0.3)],
			["ARM", "swap", Vector2(428, 144), 11.0, Color(0.85, 0.85, 0.7)],
			["OGG", "item_use", Vector2(398, 162), 10.0, Color(0.6, 1.0, 0.7)],
			["CRO", "summon", Vector2(370, 162), 10.0, Color(0.5, 0.95, 1.0)],
			["II", "pad:START", Vector2(462, 96), 10.0, Color(0.8, 0.8, 0.9)],
			["BOR", "key:I", Vector2(436, 100), 10.0, Color(0.8, 0.8, 0.9)],
		]
	var dpx := lx if panels else 52.0
	var dr := clampf(s * 0.5 - 8.0, 12.0, 15.0) if panels else 15.0
	menu_btns = [
		["^", "pad:UP", Vector2(dpx, 170), dr, Color(0.85, 0.85, 0.95)],
		["v", "pad:DOWN", Vector2(dpx, 236), dr, Color(0.85, 0.85, 0.95)],
		["<", "pad:LEFT", Vector2(dpx - (dr * 1.5 if not panels else s * 0.28), 203), dr * (1.0 if not panels else 0.8), Color(0.85, 0.85, 0.95)],
		[">", "pad:RIGHT", Vector2(dpx + (dr * 1.5 if not panels else s * 0.28), 203), dr * (1.0 if not panels else 0.8), Color(0.85, 0.85, 0.95)],
		["OK", "pad:A", Vector2(rx, 222), big, Color(0.6, 1.0, 0.7)],
		["NO", "pad:B", Vector2(rx, 176), med, Color(1.0, 0.6, 0.6)],
	]


func _playing() -> bool:
	return main.state == "play" and not main.inv_open


func _btns() -> Array:
	return play_btns if _playing() else menu_btns


func _input(ev: InputEvent) -> void:
	if not (ev is InputEventScreenTouch or ev is InputEventScreenDrag):
		return
	var pos: Vector2 = ev.position
	var idx: int = ev.index
	if ev is InputEventScreenTouch and ev.pressed:
		var bs := _btns()
		for i in bs.size():
			if pos.distance_to(bs[i][2]) < float(bs[i][3]) + 6.0:
				held[idx] = i
				_send(str(bs[i][1]), true)
				get_viewport().set_input_as_handled()
				queue_redraw()
				return
		# schermate "premi un tasto" (storia, risultati): basta toccare
		if main.state in ["story", "results"]:
			_send("pad:A", true)
			_send("pad:A", false)
			get_viewport().set_input_as_handled()
			return
		var stick_zone := (pos.x < side) if side >= 44.0 else (pos.x < 240.0 and pos.y > 60.0)
		if _playing() and stick_zone and stick_id < 0:
			stick_id = idx
			stick_c = pos
			stick_v = Vector2.ZERO
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenTouch and not ev.pressed:
		if held.has(idx):
			var bs2 := _btns()
			var bi: int = held[idx]
			if bi < bs2.size():
				_send(str(bs2[bi][1]), false)
			held.erase(idx)
		if idx == stick_id:
			stick_id = -1
			stick_v = Vector2.ZERO
			_move(Vector2.ZERO)
	elif ev is InputEventScreenDrag and idx == stick_id:
		var v := pos - stick_c
		if v.length() > r_stick:
			stick_c = pos - v.normalized() * r_stick     # lo stick segue il dito
			v = v.normalized() * r_stick
		stick_v = v / r_stick
		_move(stick_v)
		get_viewport().set_input_as_handled()
	queue_redraw()


func _move(v: Vector2) -> void:
	for a in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		var s: float = a[1]
		if s > 0.2:
			Input.action_press(a[0], clampf(s, 0.0, 1.0))
		else:
			Input.action_release(a[0])


const PAD := {"START": JOY_BUTTON_START, "A": JOY_BUTTON_A, "B": JOY_BUTTON_B, "UP": JOY_BUTTON_DPAD_UP,
	"DOWN": JOY_BUTTON_DPAD_DOWN, "LEFT": JOY_BUTTON_DPAD_LEFT, "RIGHT": JOY_BUTTON_DPAD_RIGHT}


func _send(act: String, down: bool) -> void:
	if act.begins_with("key:"):
		var k := InputEventKey.new()
		k.keycode = OS.find_keycode_from_string(act.substr(4))
		k.physical_keycode = k.keycode
		k.pressed = down
		Input.parse_input_event(k)
	elif act.begins_with("pad:"):
		var j := InputEventJoypadButton.new()   # come un controller vero: tutti i menu lo capiscono
		j.button_index = PAD[act.substr(4)]
		j.pressed = down
		j.pressure = 1.0 if down else 0.0
		Input.parse_input_event(j)
	else:
		var e := InputEventAction.new()
		e.action = act
		e.pressed = down
		e.strength = 1.0 if down else 0.0
		Input.parse_input_event(e)


func _process(_dt: float) -> void:
	_layout()
	if not _playing() and stick_id >= 0:
		stick_id = -1
		_move(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var vs := get_viewport_rect().size
	if side >= 44.0:   # bande laterali scure, separate dal gioco da un filo dorato
		draw_rect(Rect2(0, 0, side, vs.y), Color(0.03, 0.02, 0.05))
		draw_rect(Rect2(vs.x - side, 0, side, vs.y), Color(0.03, 0.02, 0.05))
		draw_line(Vector2(side - 0.5, 0), Vector2(side - 0.5, vs.y), Color(0.38, 0.27, 0.09), 1.0)
		draw_line(Vector2(vs.x - side + 0.5, 0), Vector2(vs.x - side + 0.5, vs.y), Color(0.38, 0.27, 0.09), 1.0)
	var playing := _playing()
	if playing:
		var c := stick_c if stick_id >= 0 else Vector2(side * 0.5 if side >= 44.0 else 56.0, 214)
		var a := 0.6 if stick_id >= 0 else 0.35
		draw_arc(c, r_stick, 0.0, TAU, 32, Color(0.85, 0.85, 0.95, a), 2.0)
		draw_circle(c + stick_v * r_stick, r_stick * 0.4, Color(0.85, 0.85, 0.95, a * 0.8))
	var bs := _btns()
	var pressed := {}
	for k in held:
		pressed[held[k]] = true
	var f: Font = main.hud.font
	for i in bs.size():
		var b: Array = bs[i]
		var on := pressed.has(i)
		var col: Color = b[4]
		draw_circle(b[2], float(b[3]), Color(0.05, 0.03, 0.08, 0.6 if on else 0.4))
		draw_arc(b[2], float(b[3]), 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.95 if on else 0.65), 2.0)
		var tw := f.get_string_size(str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(f, b[2] + Vector2(-tw / 2.0, 3.0), str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col.r, col.g, col.b, 1.0 if on else 0.85))
