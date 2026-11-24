class_name Keybinds
extends RefCounted
## Rimappatura dei tasti. Ogni azione ha un tasto PRIMARIO di tastiera (il primo evento tasto) e un comando PRIMARIO del
## controller (primo pulsante o grilletto). Gli altri tasti alternativi (es. le frecce) restano com'erano.
## Se il nuovo tasto e' gia' usato da un'altra azione, i due vengono scambiati: niente azioni rimaste senza comando.

const PATH := "user://keybinds.cfg"
const ACTIONS := [
	["move_up", "MUOVI SU", false], ["move_down", "MUOVI GIU", false], ["move_left", "MUOVI SINISTRA", false], ["move_right", "MUOVI DESTRA", false],
	["attack", "COLPO LEGGERO", true], ["heavy", "COLPO PESANTE", true], ["dash", "ROTOLATA", true], ["parry", "PARATA", true],
	["flask", "FIALA", true], ["interact", "INTERAGISCI", true], ["swap", "CAMBIA ARMA", true],
	["spell1", "MAGIA 1", true], ["spell2", "MAGIA 2", true], ["item_next", "OGGETTO: CAMBIA", false], ["item_use", "OGGETTO: USA", true],
	["summon", "CRONOTONE: BOLLA", true], ["zoom", "ZOOM ORDA / TATTICA", true], ["camera_zoom", "ZOOM CAMERA", true], ["lock", "AGGANCIA NEMICO", true],
]
const RESERVED := [KEY_ESCAPE, KEY_F2, KEY_F3, KEY_F9, KEY_F10, KEY_F11, KEY_F12, KEY_M, KEY_B, KEY_I, KEY_T]
const PAD_NAMES := {0: "A", 1: "B", 2: "X", 3: "Y", 4: "SELECT", 6: "START", 7: "L3", 8: "R3", 9: "LB", 10: "RB", 11: "CROCE SU", 12: "CROCE GIU", 13: "CROCE SX", 14: "CROCE DX"}

static var defaults: Dictionary = {}


## da chiamare dopo Game.setup_input(): ricorda i comandi predefiniti e applica quelli salvati
static func init() -> void:
	defaults.clear()
	for a in ACTIONS:
		var evs: Array = []
		for e in InputMap.action_get_events(a[0]):
			evs.append(e.duplicate())
		defaults[a[0]] = evs
	_load()


static func _is_pad(e: InputEvent) -> bool:
	return e is InputEventJoypadButton or (e is InputEventJoypadMotion and (e.axis == JOY_AXIS_TRIGGER_LEFT or e.axis == JOY_AXIS_TRIGGER_RIGHT))


static func _first(action: String, pad: bool) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if pad and _is_pad(e):
			return e
		if not pad and e is InputEventKey:
			return e
	return null


static func key_text(action: String) -> String:
	var e := _first(action, false)
	return (e as InputEventKey).as_text_physical_keycode().to_upper() if e != null else "-"


static func pad_text(action: String) -> String:
	var e := _first(action, true)
	if e is InputEventJoypadButton:
		return str(PAD_NAMES.get(e.button_index, "TASTO %d" % e.button_index))
	if e is InputEventJoypadMotion:
		return "LT" if e.axis == JOY_AXIS_TRIGGER_LEFT else "RT"
	return "-"


static func can_pad(action: String) -> bool:
	for a in ACTIONS:
		if a[0] == action:
			return bool(a[2])
	return false


## true se l'evento e' adatto a essere assegnato (tasto non riservato, pulsante o grilletto)
static func accepts(ev: InputEvent, pad: bool) -> bool:
	if not pad:
		return ev is InputEventKey and ev.pressed and not ev.echo and not RESERVED.has(ev.physical_keycode) and ev.physical_keycode != KEY_NONE
	if ev is InputEventJoypadButton:
		return ev.pressed
	return ev is InputEventJoypadMotion and _is_pad(ev) and absf(ev.axis_value) > 0.7


static func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis
	return false


## assegna ev come comando primario di action; restituisce il nome dell'azione con cui si e' scambiato ("" se nessuna)
static func assign(action: String, ev: InputEvent, pad: bool) -> String:
	var new_e: InputEvent
	if ev is InputEventKey:
		new_e = InputEventKey.new()
		new_e.physical_keycode = ev.physical_keycode
	elif ev is InputEventJoypadButton:
		new_e = InputEventJoypadButton.new()
		new_e.device = -1
		new_e.button_index = ev.button_index
	else:
		new_e = InputEventJoypadMotion.new()
		new_e.device = -1
		new_e.axis = ev.axis
		new_e.axis_value = 1.0
	var swapped := ""
	var mine := _list(action, pad)
	var old: InputEvent = mine[0] if not mine.is_empty() else null
	if old != null and _same(old, new_e):
		return ""
	# chi usa gia' questo comando prende quello che stavamo lasciando
	for a in ACTIONS:
		var other: String = a[0]
		var lst := _list(other, pad)
		var changed := false
		var i := 0
		while i < lst.size():
			if _same(lst[i], new_e) and not (other == action and i == 0):
				if old != null:
					lst[i] = old.duplicate()
					i += 1
				else:
					lst.remove_at(i)
				changed = true
				if other != action:
					swapped = str(a[1])
			else:
				i += 1
		if changed:
			_write(other, pad, lst)
	mine = _list(action, pad)
	if mine.is_empty():
		mine.append(new_e)
	else:
		mine[0] = new_e
	_write(action, pad, mine)
	save()
	return swapped


static func _list(action: String, pad: bool) -> Array:
	var out: Array = []
	for e in InputMap.action_get_events(action):
		if (pad and _is_pad(e)) or (not pad and e is InputEventKey):
			out.append(e)
	return out


static func _write(action: String, pad: bool, lst: Array) -> void:
	for e in _list(action, pad):
		InputMap.action_erase_event(action, e)
	for e in lst:
		InputMap.action_add_event(action, e)


static func reset_all() -> void:
	for a in ACTIONS:
		var act: String = a[0]
		for e in InputMap.action_get_events(act):
			if e is InputEventKey or _is_pad(e):
				InputMap.action_erase_event(act, e)
		for e in defaults.get(act, []):
			if e is InputEventKey or _is_pad(e):
				InputMap.action_add_event(act, e.duplicate())
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func save() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		return
	var cfg := ConfigFile.new()
	for a in ACTIONS:
		var keys: Array = []
		var pads: Array = []
		for e in InputMap.action_get_events(a[0]):
			if e is InputEventKey:
				keys.append(int(e.physical_keycode))
			elif e is InputEventJoypadButton:
				pads.append(int(e.button_index))
			elif _is_pad(e):
				pads.append(1000 + int(e.axis))
		cfg.set_value("keys", a[0], keys)
		cfg.set_value("pad", a[0], pads)
	cfg.save(PATH)


static func _load() -> void:
	if OS.get_cmdline_user_args().size() > 0:
		return
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for a in ACTIONS:
		var act: String = a[0]
		if cfg.has_section_key("keys", act):
			for e in InputMap.action_get_events(act):
				if e is InputEventKey:
					InputMap.action_erase_event(act, e)
			for k in cfg.get_value("keys", act):
				var ke := InputEventKey.new()
				ke.physical_keycode = int(k)
				InputMap.action_add_event(act, ke)
		if bool(a[2]) and cfg.has_section_key("pad", act):
			for e in InputMap.action_get_events(act):
				if _is_pad(e):
					InputMap.action_erase_event(act, e)
			for p in cfg.get_value("pad", act):
				if int(p) >= 1000:
					var me := InputEventJoypadMotion.new()
					me.device = -1
					me.axis = int(p) - 1000
					me.axis_value = 1.0
					InputMap.action_add_event(act, me)
				else:
					var be := InputEventJoypadButton.new()
					be.device = -1
					be.button_index = int(p)
					InputMap.action_add_event(act, be)
