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
	"Z = INQUADRA l'oggetto della riga (camera libera su di lui)",
	"X = PORTA l'oggetto della riga DAVANTI alla camera attuale",
	"SPAZIO = play/pausa dal punto attuale (con audio)",
	"P = ANTEPRIMA pulita dall'inizio, con audio (un tasto la ferma)",
	"F camera libera (WASD QE, tasto dx) | C = cattura la camera",
	"PAG SU / PAG GIU' = velocita' della cutscene (dura di meno / di piu')",
	"ESC esci | Ctrl+Backspace = ripristina l'originale del gioco"]
const LBL := {"mira": "GUARDA VERSO", "chiarore": "CHIARORE (0-1)", "t": "TEMPO (s)", "a": "RIFERIMENTO", "f": "ZOOM (fov)", "m": "MODO (0 alto, 1 libera)", "e": "CURVA (0-3)",
	"cut": "TAGLIO (1 = secco)", "v": "VISIBILE (1/0)", "s": "SCALA", "al": "INTENSITA' (0-1)", "giro": "ROTAZIONE (rad)", "forza": "ENERGIA BOLLA", "alto": "ALLUNGAMENTO",
	"taglio": "DISSOLVI DAVANTI (dist.)", "auto": "CAMERA DEL GIOCO (1/0)", "vol": "VOLUME (dB)", "g": "SPESSORE", "raggio": "RAGGIO", "dove": "DOVE",
	"tempesta": "TEMPESTA (0-1)", "tempo_fermo": "TEMPO FERMO (0-1)", "lente": "LENTE (0-1)", "pietre": "PIETRE IN ARIA (0-1)", "caduta": "PIETRE CADONO (0-1)",
	"risucchio": "PIETRE RISUCCHIATE", "impronta": "IMPRONTA A TERRA", "terra": "FULMINI A TERRA /s", "dal_cielo": "SAETTE DAL CIELO /s",
	"di_lato": "SCARICHE DI LATO /s", "sulla_bolla": "ARCHI SULLA BOLLA", "nel_punto": "SCINTILLE NEL PUNTO /s", "sullo_scafo": "ARCHI SULLO SCAFO /s",
	"sull_impronta": "ARCHI A TERRA /s", "echi": "ECHI DELL'UFO (0-1)", "eco_scala": "ECHI CHE SI ALLARGANO", "sfarfallio": "SFARFALLIO (0-1)",
	"tremito": "TREMITO", "fumo": "FUMO (1/0)", "fuoco": "FUOCO (1/0)", "luce_risucchiata": "LUCE RISUCCHIATA (1/0)", "braci": "BRACI (1/0)", "w": "PESO (0-1)", "sun": "LUCE SOLE", "fog": "NEBBIA", "k": "TIPO", "n": "NUMERO", "d": "DURATA (s)", "x": "TESTO"}
const L3 := {"mira_o": ["MIRA SPOSTATA X", "MIRA ALTEZZA", "MIRA SPOSTATA Z"], "o": ["POSIZIONE X", "ALTEZZA", "POSIZIONE Z"], "r": ["PITCH su/giu", "YAW gira", "ROLLIO"], "c": ["COLORE R", "COLORE G", "COLORE B"]}
const TOP := 11.0
const COL_W := 158.0

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
var f0 := 0                    # primo valore visibile nel pannello (scorre col valore scelto)
var msg := ""
var drag := false
var preview := false
var ui_hp := false


func setup(cine: W3DCine) -> void:
	c = cine
	layer = CanvasLayer.new()
	layer.layer = 95
	c.gm.add_child(layer)
	var vs: Vector2 = c.gm.get_viewport().get_visible_rect().size
	pn = Control.new()
	pn.position = Vector2(3, 3)
	var tl_h := maxf(86.0, TOP + c._tracks().size() * 6.2 + 2.0)      # piu' righe = timeline piu' alta
	pn.size = Vector2(COL_W * 2.0 + 4.0, vs.y - tl_h - 6.0)      # i valori stanno su due colonne
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
	tl.offset_top = -tl_h
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
	if names()[tr] == "cam" and int(k.get("m", 0)) == 1 and not k.has("mira"):
		k["mira"] = ""       # ogni inquadratura libera puo' puntare un bersaglio
		ks.append("mira")
	for n in ks:
		var v: Variant = k[n]
		if v is Array:
			for i in (v as Array).size():
				out.append([n, i])
		elif v is float or v is int or (n == "a" and v is String) or (n == "f" and v is String) or (n == "x" and v is String) or (n == "n" and v is String) or (n == "mira" and v is String):
			out.append([n, -1])
	return out


func _label(n: String, i: int) -> String:
	if names()[tr] == "musica":
		return {"f": "FILE AUDIO", "vol": "VOLUME (0-100 %)", "from": "PARTI DAL SECONDO (brano)", "fade": "DISSOLVENZA (s)"}.get(n, LBL.get(n, n))
	if i >= 0 and n == "c":
		return L3["c"][i]
	if n == "a" and cur() != null and str((cur() as Dictionary).get("k", "")) == "flash":
		return "FORZA DEL LAMPO"
	if n == "n" and cur() != null and str((cur() as Dictionary).get("k", "")) == "snd":
		return "SUONO"
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
	if n == "mira":
		var tg: Array = [""] + c.anchors.keys() + c.acts.keys()
		k["mira"] = tg[(tg.find(str(k["mira"])) + int(dir) + tg.size()) % tg.size()]
		if str(k["mira"]) != "" and not k.has("mira_o"):
			k["mira_o"] = [0.0, 0.0, 0.0]
	elif n == "n" and k[n] is String:
		var snds: Array = c.gm.sfx_node.cache.keys()
		snds.sort()
		k[n] = snds[(snds.find(str(k[n])) + int(dir) + snds.size()) % snds.size()]
	elif n == "x" and k[n] is String:
		var tx: Array = ["????", "?!", "...", "!!!", "??"]
		var jx: int = tx.find(str(k["x"]))
		k["x"] = tx[(jx + int(dir) + tx.size()) % tx.size()]
	elif n == "f" and k[n] is String:
		var opts2: Array = []
		for fn in DirAccess.get_files_at("res://audio"):
			if fn.get_extension() in ["mp3", "ogg", "wav"]:
				opts2.append("res://audio/" + fn)
		if not opts2.is_empty():
			var j2: int = opts2.find(str(k["f"]))
			k["f"] = opts2[(j2 + int(dir) + opts2.size()) % opts2.size()]
	elif n == "a":
		var opts: Array = c.anchors.keys() + c.acts.keys()
		var j: int = opts.find(str(k["a"]))
		k["a"] = opts[(j + int(dir) + opts.size()) % opts.size()]
	else:
		var stp := 0.1
		if names()[tr] == "musica" and n in ["vol", "from", "fade"]:
			stp = 5.0 if n == "vol" else (1.0 if n == "from" else 0.5)
		elif n in ["m", "v", "e", "cut", "on", "auto", "fumo", "fuoco", "braci", "luce_risucchiata"] and not (n == "e" and names()[tr] == "env"):
			stp = 1.0
		elif n in ["terra", "dal_cielo", "di_lato", "sulla_bolla", "nel_punto", "sullo_scafo", "sull_impronta", "taglio", "raggio"]:
			stp = 1.0
		elif n in ["o", "mira_o"]:
			stp = 0.5
		elif n in ["r", "c"]:
			stp = 0.05
		elif n == "f":
			stp = 2.0
		var cv: float = float(k[n][i]) if i >= 0 else float(k[n])
		var nv := snappedf(cv + dir * stp * mult, 0.001)
		if n in ["m", "v", "cut", "on"]:
			nv = maxf(nv, 0.0)
		if names()[tr] == "musica":
			nv = maxf(nv, 0.0)
			if n == "vol":
				nv = minf(nv, 100.0)
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
	if preview:
		_stop_preview()
		return
	var sh: float = 10.0 if ev.shift_pressed else (0.1 if ev.ctrl_pressed else 1.0)
	var key: int = ev.keycode
	match key:
		KEY_PAGEUP, KEY_PAGEDOWN:
			c.cut["velocita"] = snappedf(clampf(c.rate() + (0.05 if key == KEY_PAGEUP else -0.05), 0.3, 2.0), 0.01)
			_touch()
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
			if c.playing and c.t > 0.01:
				c.music_sync(c.t)
			elif not c.playing:
				c._music_stop(0.2)
		KEY_P:
			_start_preview()
		KEY_Z:
			_frame_actor()
		KEY_X:
			_bring_actor()
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


func _start_preview() -> void:
	preview = true
	c.preview = true
	ui_hp = hp.visible
	pn.visible = false
	hp.visible = false
	tl.visible = false
	fly = false
	c.seek(0.0)
	c.playing = true


func _stop_preview() -> void:
	preview = false
	c.preview = false
	c.playing = false
	c._music_stop(0.3)
	pn.visible = true
	tl.visible = true
	hp.visible = ui_hp


func _cam_xf() -> Transform3D:
	if fly:
		return Transform3D(Basis.from_euler(fr), fp)
	return c.sk.cam.global_transform


func _actor_sel() -> Variant:
	var nm: String = names()[tr]
	return c.acts[nm] if c.acts.has(nm) else null


## Z: la camera libera si mette davanti all'oggetto della riga scelta, guardandolo
func _frame_actor() -> void:
	var n: Variant = _actor_sel()
	if n == null:
		msg = "Z/X: scegli con TAB la riga di un attore (ufo, hero...)"
		return
	var xf := _cam_xf()
	var target: Vector3 = (n as Node3D).position + Vector3(0, 1.5, 0)
	fly = true
	fr = xf.basis.get_euler()
	fp = target + xf.basis.z * 16.0
	msg = "OGGETTO INQUADRATO" + ("" if (n as Node3D).visible else " (ma a questo tempo e' invisibile: usa X)")


## X: il keyframe scelto dell'attore viene spostato 14 unita' davanti alla camera attuale (e reso visibile)
func _bring_actor() -> void:
	var n: Variant = _actor_sel()
	if n == null or cur() == null:
		msg = "Z/X: scegli con TAB la riga di un attore e un keyframe"
		return
	var xf := _cam_xf()
	var target: Vector3 = xf.origin - xf.basis.z * 14.0
	var k: Dictionary = cur()
	var rf := c.ref(str(k.get("a", "P0")))
	var off := Basis(Vector3.UP, float(rf["yaw"])).inverse() * (target - (rf["p"] as Vector3))
	k["o"] = [snappedf(off.x, 0.01), snappedf(off.y, 0.01), snappedf(off.z, 0.01)]
	k["v"] = 1
	_touch()
	msg = "OGGETTO PORTATO DAVANTI ALLA CAMERA"


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
	elif (c.stage != null or c.fxs != null) and nm != "env" and nm != "ev" and nm != "musica":
		k = _copy_key(arr)
	elif nm == "env":
		k = {"t": snappedf(c.t, 0.01), "w": 1.0, "c": [0.5, 0.5, 0.7], "e": 0.2}
	elif nm == "musica":
		k = {"t": snappedf(c.t, 0.01), "k": "music", "f": "res://audio/Midnight_Landing.mp3", "vol": 70.0, "from": 0.0, "fade": 2.0}
		if cur() != null:
			k = (cur() as Dictionary).duplicate(true)
			k["t"] = snappedf(c.t, 0.01)
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


## radura: il nuovo keyframe e' lo stato attuale della traccia (tutti i valori interpolati)
func _copy_key(arr: Array) -> Dictionary:
	var s: Array = c.seg(arr, c.t)
	if s[0] == null:
		return {"t": snappedf(c.t, 0.01), "a": "T", "o": [0, 0, 0], "r": [0, 0, 0], "s": 1.0, "v": 1}
	var a: Dictionary = s[0]
	var k := a.duplicate(true)
	k["t"] = snappedf(c.t, 0.01)
	k.erase("cut")
	if s[1] != null:
		var b: Dictionary = s[1]
		var w: float = s[2]
		for n in k:
			if n in ["t", "e", "v", "m", "auto"] or not b.has(n):
				continue
			if k[n] is float or k[n] is int:
				k[n] = snappedf(lerpf(float(a[n]), float(b[n]), w), 0.001)
			elif k[n] is Array and n == "r":
				k[n] = [lerpf(a[n][0], b[n][0], w), lerpf(a[n][1], b[n][1], w), lerpf(a[n][2], b[n][2], w)]
			elif k[n] is Array and n == "o":
				# la posizione si interpola fra le due ancore e si riporta in quella della chiave precedente
				var rf := c.ref(str(a.get("a", "P0")))
				var p: Vector3 = (c.kpos(a)["p"] as Vector3).lerp(c.kpos(b)["p"], w)
				var off := Basis(Vector3.UP, float(rf["yaw"])).inverse() * (p - (rf["p"] as Vector3))
				k[n] = [snappedf(off.x, 0.01), snappedf(off.y, 0.01), snappedf(off.z, 0.01)]
	return k


func _capture() -> void:
	if names()[tr] != "cam" or cur() == null or not fly:
		msg = "C: scegli la riga cam, un keyframe e attiva F"
		return
	var k: Dictionary = cur()
	if int(k.get("auto", 0)) == 1:       # la chiave smette di seguire la camera del gioco
		k["auto"] = 0
		k["a"] = "C"
	var rf := c.ref(str(k.get("a", "P0")))
	var off := Basis(Vector3.UP, float(rf["yaw"])).inverse() * (fp - (rf["p"] as Vector3))
	if int(k.get("m", 0)) == 0:
		off = Vector3(off.x, fp.y - c.sk.elev_y, off.z)
	else:
		k["r"] = [fr.x, fr.y - float(rf["yaw"]), fr.z]
	k["o"] = [snappedf(off.x, 0.01), snappedf(off.y, 0.01), snappedf(off.z, 0.01)]
	_touch()


func update() -> void:
	if preview and not c.playing:
		_stop_preview()
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
		if c.stage == null:
			c.gm.player.position = Vector2(fp.x, fp.z) * 16.0
		else:
			c.sk._mp("near_cut", 0.0)
	var nm: String = names()[tr]
	hdr = "CUTSCENE '%s'   tempo %.2f / %.1f s\nVELOCITA' %d%% (Pag su/giu): dura %.1f s\n%s%s\nRIGA: %s   KEYFRAME %d di %d
H = aiuto | V = nascondi valori" % [c.id, c.t, float(c.cut["dur"]), int(round(c.rate() * 100.0)), float(c.cut["dur"]) / c.rate(), "PLAY" if c.playing else "PAUSA", "   CAMERA LIBERA" if fly else "", nm, ki + 1, keys().size()]
	fi = clampi(fi, 0, maxi(fields().size() - 1, 0))
	pn.queue_redraw()
	hp.queue_redraw()
	tl.queue_redraw()


func _rows() -> int:
	return maxi(int((pn.size.y - fy0 - 14.0) / 10.0), 3)


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
	var rows := _rows()
	var shown := rows * 2
	f0 = clampi(f0, maxi(fi - shown + 1, 0), mini(fi, maxi(fl.size() - shown, 0)))
	if fl.size() > shown:
		pn.draw_string(f, Vector2(pn.size.x - 62, fy0 - 10.0), "su/giu: altri", HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(1, 0.8, 0.4))
	for i in range(f0, mini(fl.size(), f0 + shown)):
		var n: String = fl[i][0]
		var j: int = fl[i][1]
		var val: Variant = k[n][j] if j >= 0 else k[n]
		var x := COL_W * float((i - f0) / rows)
		var ry := y + 10.0 * float((i - f0) % rows)
		if i == fi:
			pn.draw_rect(Rect2(x + 2, ry - 8, COL_W - 4, 10), Color(0.9, 0.7, 0.1, 0.45))
		pn.draw_string(f, Vector2(x + 5, ry), _label(n, j), HORIZONTAL_ALIGNMENT_LEFT, 104, 6, Color.WHITE)
		pn.draw_string(f, Vector2(x + 112, ry), ("%.2f" % float(val)) if (val is float or val is int) else str(val), HORIZONTAL_ALIGNMENT_LEFT, 44, 7, Color(0.6, 1, 0.7))
	if k != null and (k as Dictionary).has("k"):
		pn.draw_string(f, Vector2(5, pn.size.y - 15), "evento: " + str((k as Dictionary)["k"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.8, 0.6))
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
			var idx := f0 + row + (_rows() if ev.position.x >= COL_W else 0)
			if row >= 0 and row < _rows() and idx < fields().size():
				fi = idx
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
				tl.draw_string(f, Vector2(maxf(x2 + 4, 44.0), y + rh - 2), "%.2fs" % float(arr[j]["t"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color(1, 0.7, 0.7))
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
