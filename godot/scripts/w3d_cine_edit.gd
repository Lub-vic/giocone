class_name W3DCineEdit
extends RefCounted
## EDITOR DI CUTSCENE (F6 nel mondo aperto). Lavora su W3DCine. TUTTE le modifiche si salvano da sole in user://cutscenes.json.
## Timeline in basso: una riga per traccia (cam, ufo, hero...), i quadratini sono i KEYFRAME (chiavi), la barra rossa e' il tempo attuale.
## Pannello a sinistra: i valori della chiave scelta. Aiuto in alto a destra.

const HELP := ["TIMELINE (in basso): barra rossa = tempo attuale,",
	"ogni quadratino = un keyframe. Click = vai a quel tempo;",
	"click su un quadratino = sceglilo; TRASCINALO = sposta nel tempo",
	"TAB = cambia riga (cam, ufo, hero...) | , e . = keyframe prec/succ",
	"PANNELLO A SINISTRA = valori del keyframe scelto:",
	"click su una riga, poi ROTELLA (oppure - e +)",
	"Shift = x10, Ctrl = /10. Ogni modifica SI SALVA DA SOLA",
	"K = nuovo keyframe qui (copia lo stato) | CANC = elimina",
	"M = sposta il keyframe al tempo attuale",
	"FAR MUOVERE un attore: 2 keyframe a tempi diversi,",
	"con POSIZIONE/ALTEZZA diverse",
	"SPAZIO play | F camera libera (WASD QE, tasto dx)",
	"C = cattura la camera nel keyframe | ESC esci",
	"Ctrl+Backspace = ripristina l'originale del gioco"]
const LBL := {"t": "TEMPO (s)", "a": "RIFERIMENTO", "f": "ZOOM (fov)", "m": "MODO (0 alto, 1 libera)", "e": "CURVA (0-3)",
	"cut": "TAGLIO (1 = secco)", "v": "VISIBILE (1/0)", "s": "SCALA", "w": "PESO (0-1)", "sun": "LUCE SOLE", "fog": "NEBBIA", "k": "TIPO", "n": "NUMERO"}
const L3 := {"o": ["POSIZIONE X", "ALTEZZA", "POSIZIONE Z"], "r": ["PITCH su/giu", "YAW gira", "ROLLIO"], "c": ["COLORE R", "COLORE G", "COLORE B"]}
const TOP := 11.0

var c: W3DCine
var tr := 0                     # traccia selezionata
var ki := 0                     # chiave selezionata
var fi := 0                     # campo selezionato
var fly := false
var fp := Vector3.ZERO
var fr := Vector3.ZERO
var layer: CanvasLayer
var pn: Control
var hp: Control
var tl: Control
var hdr := ""
var fy0 := 0.0
var msg := ""
var drag := false


func setup(cine: W3DCine) -> void:
	c = cine
	layer = CanvasLayer.new()
	layer.layer = 95
	c.gm.add_child(layer)
	var vs: Vector2 = c.gm.get_viewport().get_visible_rect().size
	pn = Control.new()
	pn.position = Vector2(3, 3)
	pn.size = Vector2(196, vs.y - 92)
	pn.mouse_filter = Control.MOUSE_FILTER_STOP
	pn.draw.connect(_draw_pn)
	pn.gui_input.connect(_pn_input)
	layer.add_child(pn)
	hp = Control.new()
	hp.size = Vector2(vs.x - 205, HELP.size() * 9.0 + 8.0)
	hp.position = Vector2(202, 3)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.visible = false
	hp.draw.connect(_draw_hp)
	layer.add_child(hp)
	tl = Control.new()
	tl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	tl.offset_top = -86
	tl.mouse_filter = Control.MOUSE_FILTER_STOP
	tl.draw.connect(_draw_tl)
	tl.gui_input.connect(_tl_input)
	layer.add_child(tl)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if layer != null and is_instance_valid(layer):
		layer.queue_free()


func names() -> Array:
	return c._tracks().keys()


func keys() -> Array:
	return c._tracks()[names()[tr]]


func cur() -> Variant:
	var k := keys()
	return k[ki] if ki >= 0 and ki < k.size() else null


## modifica fatta: salva subito
func _touch() -> void:
	var all := W3DCine.load_all()
	all[c.id] = c.cut
	W3DCine.save_all(all)
	msg = "SALVATO AUTOMATICAMENTE"


func fields() -> Array:
	var out: Array = []
	var k: Variant = cur()
	if k == null:
		return out
	var ks: Array = (k as Dictionary).keys()
	ks.sort()
	ks.erase("t")
	ks.push_front("t")
	for n in ks:
		var v: Variant = k[n]
		if v is Array:
			for i in (v as Array).size():
				out.append([n, i])
		elif v is float or v is int or n == "a":
			out.append([n, -1])
	return out


func _label(n: String, i: int) -> String:
	if i >= 0 and L3.has(n):
		return L3[n][i]
	if n == "e" and names()[tr] == "env":
		return "LUCE AMBIENTE"
	return LBL.get(n, n)


func _adjust(dir: float, mult: float) -> void:
	var fl := fields()
	if fl.is_empty():
		return
	fi = clampi(fi, 0, fl.size() - 1)
	var k: Dictionary = cur()
	var n: String = fl[fi][0]
	var i: int = fl[fi][1]
	if n == "a":
		var opts: Array = c.anchors.keys() + c.acts.keys()
		var j: int = opts.find(str(k["a"]))
		k["a"] = opts[(j + int(dir) + opts.size()) % opts.size()]
	else:
		var stp := 0.1
		if n in ["m", "v", "e", "cut", "on"] and not (n == "e" and names()[tr] == "env"):
			stp = 1.0
		elif n == "o":
			stp = 0.5
		elif n in ["r", "c"]:
			stp = 0.05
		elif n == "f":
			stp = 2.0
		var cv: float = float(k[n][i]) if i >= 0 else float(k[n])
		var nv := snappedf(cv + dir * stp * mult, 0.001)
		if n in ["m", "v", "cut", "on"]:
			nv = maxf(nv, 0.0)
		if i >= 0:
			k[n][i] = nv
		else:
			k[n] = nv
	if n == "t":
		c._sort_all()
		ki = keys().find(k)
	_touch()


func input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and fly and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var m := ev as InputEventMouseMotion
		fr.y -= m.relative.x * 0.003
		fr.x = clampf(fr.x - m.relative.y * 0.003, -1.55, 1.55)
		return
	if ev is InputEventMouseButton and fly and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if ev.pressed else Input.MOUSE_MODE_VISIBLE
		return
	if not (ev is InputEventKey) or not ev.pressed:
		return
	var sh: float = 10.0 if ev.shift_pressed else (0.1 if ev.ctrl_pressed else 1.0)
	var key: int = ev.keycode
	match key:
		KEY_ESCAPE:
			c.finish(false)
		KEY_BACKSPACE:
			if ev.ctrl_pressed:
				DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cutscenes.json"))
				c.finish(false)
				c.gm.say("CUTSCENE RIPRISTINATE ALL'ORIGINALE: RIAPRI L'EDITOR")
		KEY_SPACE:
			if c.t >= float(c.cut["dur"]) - 0.01:
				c.seek(0.0)
			c.playing = not c.playing
		KEY_LEFT:
			c.seek(c.t - 0.1 * (1.0 if ev.ctrl_pressed else sh))
		KEY_RIGHT:
			c.seek(c.t + 0.1 * (1.0 if ev.ctrl_pressed else sh))
		KEY_HOME:
			c.seek(0.0)
		KEY_END:
			c.seek(float(c.cut["dur"]))
		KEY_TAB:
			tr = (tr + (-1 if ev.shift_pressed else 1) + names().size()) % names().size()
			ki = 0
			fi = 0
		KEY_COMMA, KEY_PERIOD:
			ki = clampi(ki + (-1 if key == KEY_COMMA else 1), 0, maxi(keys().size() - 1, 0))
			if cur() != null:
				c.seek(float((cur() as Dictionary)["t"]))
		KEY_UP:
			fi = maxi(fi - 1, 0)
		KEY_DOWN:
			fi = mini(fi + 1, maxi(fields().size() - 1, 0))
		KEY_MINUS, KEY_KP_SUBTRACT:
			_adjust(-1.0, sh)
		KEY_EQUAL, KEY_KP_ADD:
			_adjust(1.0, sh)
		KEY_K:
			_add_key()
		KEY_M:
			if cur() != null:
				var k: Dictionary = cur()
				k["t"] = snappedf(c.t, 0.01)
				c._sort_all()
				ki = keys().find(k)
				_touch()
		KEY_DELETE:
			if cur() != null and keys().size() > 1:
				keys().remove_at(ki)
				ki = clampi(ki, 0, keys().size() - 1)
				_touch()
		KEY_F:
			fly = not fly
			if fly:
				fp = c.sk.cam.position
				fr = c.sk.cam.rotation
		KEY_C:
			_capture()
		KEY_H:
			hp.visible = not hp.visible
		KEY_V:
			pn.visible = not pn.visible


func _add_key() -> void:
	var nm: String = names()[tr]
	var arr := keys()
	var k: Dictionary = {}
	if nm == "cam":
		var ev := c.eval_cam(c.t)
		var src: Dictionary = c.seg(arr, c.t)[0] if not arr.is_empty() else {"a": "P0", "m": 0}
		var rf := c.ref(str(src.get("a", "P0")))
		var pp: Vector3 = ev["p"]
		var off := Basis(Vector3.UP, float(rf["yaw"])).inverse() * (pp - (rf["p"] as Vector3))
		if int(ev["m"]) == 0:
			off = Vector3(off.x, float(ev["oy"]), off.z)
		var rr: Vector3 = ev["rot"]
		k = {"t": snappedf(c.t, 0.01), "m": int(ev["m"]), "a": src.get("a", "P0"), "o": [off.x, off.y, off.z], "r": [rr.x, rr.y - float(rf["yaw"]), rr.z], "f": float(ev["f"])}
	elif nm == "env":
		k = {"t": snappedf(c.t, 0.01), "w": 1.0, "c": [0.5, 0.5, 0.7], "e": 0.2}
	elif nm == "ev":
		k = {"t": snappedf(c.t, 0.01), "k": "shake", "v": 2.0}
		if cur() != null:
			k = (cur() as Dictionary).duplicate(true)
			k["t"] = snappedf(c.t, 0.01)
	else:
		var node: Node3D = c.acts[nm]
		var src2: Dictionary = c.seg(arr, c.t)[0] if not arr.is_empty() else {"a": "P0"}
		var rf2 := c.ref(str(src2.get("a", "P0")))
		var off2 := Basis(Vector3.UP, float(rf2["yaw"])).inverse() * (node.position - (rf2["p"] as Vector3))
		k = {"t": snappedf(c.t, 0.01), "a": src2.get("a", "P0"), "o": [off2.x, off2.y, off2.z],
			"r": [node.rotation.x, node.rotation.y - float(rf2["yaw"]), node.rotation.z], "v": 1 if node.visible else 0}
	arr.append(k)
	c._sort_all()
	ki = arr.find(k)
	_touch()


func _capture() -> void:
	if names()[tr] != "cam" or cur() == null or not fly:
		msg = "C: scegli la riga cam, un keyframe e attiva F"
		return
	var k: Dictionary = cur()
	var rf := c.ref(str(k.get("a", "P0")))
	var off := Basis(Vector3.UP, float(rf["yaw"])).inverse() * (fp - (rf["p"] as Vector3))
	if int(k.get("m", 0)) == 0:
		off = Vector3(off.x, fp.y - c.sk.elev_y, off.z)
	else:
		k["r"] = [fr.x, fr.y - float(rf["yaw"]), fr.z]
	k["o"] = [snappedf(off.x, 0.01), snappedf(off.y, 0.01), snappedf(off.z, 0.01)]
	_touch()


func update() -> void:
	if fly:
		var d := Vector3.ZERO
		var b := Basis.from_euler(fr)
		if Input.is_key_pressed(KEY_W):
			d -= b.z
		if Input.is_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL):
			d += b.z
		if Input.is_key_pressed(KEY_A):
			d -= b.x
		if Input.is_key_pressed(KEY_D):
			d += b.x
		if Input.is_key_pressed(KEY_E):
			d.y += 1.0
		if Input.is_key_pressed(KEY_Q):
			d.y -= 1.0
		fp += d * (30.0 if Input.is_key_pressed(KEY_SHIFT) else 8.0) / 60.0
		c.sk.cam.position = fp
		c.sk.cam.rotation = fr
		c.sk.cam.fov = 80.0
		c.sk.cam.near = 0.12
		c.sk.cam.far = 260.0
		c.sk.curve = 0.0
		c.gm.player.position = Vector2(fp.x, fp.z) * 16.0
	var nm: String = names()[tr]
	hdr = "CUTSCENE '%s'   tempo %.2f / %.1f s\n%s%s\nRIGA: %s   KEYFRAME %d di %d
H = aiuto | V = nascondi valori" % [c.id, c.t, float(c.cut["dur"]), "PLAY" if c.playing else "PAUSA", "   CAMERA LIBERA" if fly else "", nm, ki + 1, keys().size()]
	fi = clampi(fi, 0, maxi(fields().size() - 1, 0))
	pn.queue_redraw()
	hp.queue_redraw()
	tl.queue_redraw()


func _draw_pn() -> void:
	var f := ThemeDB.fallback_font
	pn.draw_rect(Rect2(Vector2.ZERO, pn.size), Color(0, 0, 0, 0.6))
	var y := 10.0
	for line in hdr.split("\n"):
		pn.draw_string(f, Vector2(4, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 1, 0.65))
		y += 10.0
	y += 3.0
	pn.draw_string(f, Vector2(4, y), "VALORI DEL KEYFRAME (click riga + ROTELLA)", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.7, 0.7, 0.7))
	y += 10.0
	fy0 = y
	var fl := fields()
	var k: Variant = cur()
	for i in fl.size():
		var n: String = fl[i][0]
		var j: int = fl[i][1]
		var val: Variant = k[n][j] if j >= 0 else k[n]
		if i == fi:
			pn.draw_rect(Rect2(2, y - 8, pn.size.x - 4, 10), Color(0.9, 0.7, 0.1, 0.45))
		pn.draw_string(f, Vector2(5, y), _label(n, j), HORIZONTAL_ALIGNMENT_LEFT, 118, 7, Color.WHITE)
		pn.draw_string(f, Vector2(128, y), ("%.2f" % float(val)) if (val is float or val is int) else str(val), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 1, 0.7))
		y += 10.0
	if k != null and (k as Dictionary).has("k"):
		pn.draw_string(f, Vector2(5, y), "evento: " + str((k as Dictionary)["k"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.6))
	pn.draw_string(f, Vector2(4, pn.size.y - 5), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1, 0.6))


func _draw_hp() -> void:
	hp.draw_rect(Rect2(Vector2.ZERO, hp.size), Color(0, 0, 0, 0.72))
	var hy := 10.0
	for h in HELP:
		hp.draw_string(ThemeDB.fallback_font, Vector2(4, hy), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.88, 0.88, 0.88))
		hy += 9.0


func _pn_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		var b: int = ev.button_index
		if b == MOUSE_BUTTON_LEFT:
			var row := int((ev.position.y - fy0 + 8.0) / 10.0)
			if row >= 0 and row < fields().size():
				fi = row
		elif b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust(1.0 if b == MOUSE_BUTTON_WHEEL_UP else -1.0, 10.0 if ev.shift_pressed else (0.1 if ev.ctrl_pressed else 1.0))


func _rh() -> float:
	return minf(8.0, (tl.size.y - TOP - 2.0) / maxf(names().size(), 1))


func _draw_tl() -> void:
	var w := tl.size.x
	var dur := float(c.cut["dur"])
	var f := ThemeDB.fallback_font
	tl.draw_rect(Rect2(0, 0, w, tl.size.y), Color(0, 0, 0, 0.75))
	for sec in int(dur) + 1:
		var x := w * sec / dur
		tl.draw_line(Vector2(x, TOP - 2), Vector2(x, tl.size.y), Color(1, 1, 1, 0.1))
		if sec % 2 == 0:
			tl.draw_string(f, Vector2(x + 1, 8), "%ds" % sec, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.6))
	var nms := names()
	var rh := _rh()
	for i in nms.size():
		var y := TOP + i * rh
		if i == tr:
			tl.draw_rect(Rect2(0, y, w, rh - 1), Color(1, 1, 0.5, 0.14))
		var col := Color(1, 0.8, 0.3) if nms[i] == "cam" else (Color(0.6, 0.9, 1.0) if nms[i] == "env" else (Color(1, 1, 1) if nms[i] == "ev" else Color(0.7, 1.0, 0.6)))
		var arr: Array = c._tracks()[nms[i]]
		for j in arr.size():
			var x2 := w * float(arr[j]["t"]) / dur
			var sel := i == tr and j == ki
			tl.draw_rect(Rect2(x2 - 2, y, 5 if sel else 4, rh - 2), Color.RED if sel else col)
			if sel:
				tl.draw_string(f, Vector2(x2 + 4, y + rh - 2), "%.2fs" % float(arr[j]["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.7, 0.7))
		tl.draw_string(f, Vector2(2, y + rh - 2), str(nms[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 1, 1, 0.7))
	var px := w * c.t / dur
	tl.draw_line(Vector2(px, 0), Vector2(px, tl.size.y), Color(1, 0.2, 0.2), 2.0)


func _t_at(x: float) -> float:
	return clampf(float(c.cut["dur"]) * x / tl.size.x, 0.0, float(c.cut["dur"]))


func _tl_input(ev: InputEvent) -> void:
	var rh := _rh()
	var nms := names()
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			var row := clampi(int((ev.position.y - TOP) / rh), 0, nms.size() - 1)
			var arr: Array = c._tracks()[nms[row]]
			var best := -1
			var bd := 6.0
			for j in arr.size():
				var dx := absf(tl.size.x * float(arr[j]["t"]) / float(c.cut["dur"]) - ev.position.x)
				if dx < bd:
					bd = dx
					best = j
			if best >= 0 and ev.position.y >= TOP:
				tr = row
				ki = best
				drag = true
				c.seek(float(arr[best]["t"]))
			else:
				c.seek(_t_at(ev.position.x))
		elif drag:
			drag = false
			_touch()
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if drag and cur() != null:
			var k: Dictionary = cur()
			k["t"] = snappedf(_t_at(ev.position.x), 0.05)
			c._sort_all()
			ki = keys().find(k)
			c.seek(float(k["t"]))
		else:
			c.seek(_t_at(ev.position.x))
