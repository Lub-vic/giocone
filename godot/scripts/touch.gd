class_name TouchControls
extends Control
## Comandi touch (solo su schermi touch, o con --touch per le prove): stick a sinistra, pulsanti a destra.
## I pulsanti generano le stesse azioni di tastiera e controller, quindi tutto il gioco li capisce gia'.

var main
var stick_id := -1
var stick_c := Vector2.ZERO        # centro dello stick (dove hai appoggiato il dito)
var stick_v := Vector2.ZERO
var held := {}                     # dito -> indice del pulsante premuto
const R_STICK := 30.0
# [testo, azione, centro, raggio, colore]; azione "key:I" = tasto, "pad:START" = pulsante controller
var play_btns := [
	["ATT", "attack", Vector2(440, 214), 20.0, Color(0.95, 0.75, 0.4)],
	["PES", "heavy", Vector2(400, 238), 15.0, Color(0.95, 0.5, 0.3)],
	["ROT", "dash", Vector2(398, 194), 15.0, Color(0.6, 0.85, 1.0)],
	["E", "interact", Vector2(440, 168), 14.0, Color(0.9, 0.9, 0.9)],
	["1", "spell1", Vector2(360, 222), 13.0, Color(0.7, 0.6, 1.0)],
	["2", "spell2", Vector2(362, 186), 13.0, Color(0.7, 0.6, 1.0)],
	["FIA", "flask", Vector2(458, 128), 12.0, Color(1.0, 0.7, 0.3)],
	["ARM", "swap", Vector2(426, 132), 12.0, Color(0.85, 0.85, 0.7)],
	["OGG", "item_use", Vector2(394, 148), 11.0, Color(0.6, 1.0, 0.7)],
	["II", "pad:START", Vector2(462, 86), 10.0, Color(0.8, 0.8, 0.9)],
	["BOR", "key:I", Vector2(436, 92), 10.0, Color(0.8, 0.8, 0.9)],
]
var menu_btns := [
	["^", "ui_up", Vector2(52, 184), 15.0, Color(0.85, 0.85, 0.95)],
	["v", "ui_down", Vector2(52, 238), 15.0, Color(0.85, 0.85, 0.95)],
	["<", "ui_left", Vector2(24, 211), 15.0, Color(0.85, 0.85, 0.95)],
	[">", "ui_right", Vector2(80, 211), 15.0, Color(0.85, 0.85, 0.95)],
	["OK", "ui_accept", Vector2(440, 220), 20.0, Color(0.6, 1.0, 0.7)],
	["NO", "ui_cancel", Vector2(396, 238), 15.0, Color(1.0, 0.6, 0.6)],
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


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
		if _playing() and pos.x < 240.0 and pos.y > 60.0 and stick_id < 0:
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
			queue_redraw()
		if idx == stick_id:
			stick_id = -1
			stick_v = Vector2.ZERO
			_move(Vector2.ZERO)
	elif ev is InputEventScreenDrag and idx == stick_id:
		var v := pos - stick_c
		if v.length() > R_STICK:
			stick_c = pos - v.normalized() * R_STICK     # lo stick segue il dito
			v = v.normalized() * R_STICK
		stick_v = v / R_STICK
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


func _send(act: String, down: bool) -> void:
	if act.begins_with("key:"):
		var k := InputEventKey.new()
		k.keycode = OS.find_keycode_from_string(act.substr(4))
		k.physical_keycode = k.keycode
		k.pressed = down
		Input.parse_input_event(k)
	elif act.begins_with("pad:"):
		var j := InputEventJoypadButton.new()
		j.button_index = JOY_BUTTON_START
		j.pressed = down
		Input.parse_input_event(j)
	else:
		var e := InputEventAction.new()
		e.action = act
		e.pressed = down
		e.strength = 1.0 if down else 0.0
		Input.parse_input_event(e)


func _process(_dt: float) -> void:
	if not _playing() and stick_id >= 0:
		stick_id = -1
		_move(Vector2.ZERO)
	queue_redraw()


func _draw() -> void:
	var playing := _playing()
	if playing:
		var c := stick_c if stick_id >= 0 else Vector2(56, 214)
		var a := 0.55 if stick_id >= 0 else 0.28
		draw_arc(c, R_STICK, 0.0, TAU, 32, Color(0.85, 0.85, 0.95, a), 2.0)
		draw_circle(c + stick_v * R_STICK, 11.0, Color(0.85, 0.85, 0.95, a * 0.8))
	var bs := _btns()
	var pressed := {}
	for k in held:
		pressed[held[k]] = true
	for i in bs.size():
		var b: Array = bs[i]
		var on := pressed.has(i)
		var col: Color = b[4]
		draw_circle(b[2], float(b[3]), Color(0.05, 0.03, 0.08, 0.55 if on else 0.35))
		draw_arc(b[2], float(b[3]), 0.0, TAU, 28, Color(col.r, col.g, col.b, 0.95 if on else 0.6), 2.0)
		var f: Font = main.hud.font
		var tw := f.get_string_size(str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(f, b[2] + Vector2(-tw / 2.0, 3.0), str(b[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(col.r, col.g, col.b, 1.0 if on else 0.8))
