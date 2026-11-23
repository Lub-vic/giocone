class_name W3DEdit
extends Node
## Editor del mondo dentro il gioco 3D. F12 nel mondo aperto entra/esce (esce anche con Esc e salva da solo).
## Camera libera (WASD/frecce, rotella = zoom). Strumenti: 1 PIAZZA, 2 SELEZIONA/SPOSTA, 3 GOMMA.
## Le modifiche stanno in w3d_edits.json (oggetti aggiunti + zone cancellate) e vengono applicate dal motore 3D a ogni blocco.

var sk                              # W3DSkin
var on := false
var pos := Vector2.ZERO             # centro della camera (spazio di gioco)
var zoom_h := 30.0
var fade := 40.0
var tool := 0                       # 0 piazza, 1 seleziona, 2 gomma
var kind_i := 0
var cat: Array = []                 # catalogo: oggetti del motore + modelli .glb trovati in assets/models
var scl := 1.0
var yaw := 0.0
var seed_i := 1
var erase_r := 3.0
var sel := -1
var undo: Array = []
var dirty := false
var prev_state := "play"
var hidden_layers: Array = []
var saved_curve := 0.0
var layer: CanvasLayer
var panel: PanelContainer
var lst: ItemList
var info: Label
var tool_btns: Array = []
var ghost: MeshInstance3D
var ghost_key := ""
var ring: MeshInstance3D
var ring_sel: MeshInstance3D
var dragging := false
var drag_moved := false
var drag_start := Vector2.ZERO
var last_erase := Vector2(1e9, 1e9)
var mpos := Vector2.ZERO            # cursore sul terreno (spazio di gioco)
var mvalid := false
var msg := ""
var msg_t := 0.0


func _input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F12:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if on:
		_exit()
	elif sk.world_on and str(sk.gm.state) == "play":
		_enter()
	else:
		sk.gm.say("L'EDITOR FUNZIONA NEL MONDO APERTO")


func _enter() -> void:
	on = true
	prev_state = str(sk.gm.state)
	sk.gm.state = "edit"
	pos = sk.pos
	zoom_h = 30.0
	saved_curve = sk.curve
	sk.curve = 0.0                     # niente curvatura: il cursore coincide con il terreno
	sk.fixed_cam = true
	cat = W3D.ED_CAT.duplicate()
	sk.ed_model_cache.clear()
	for mn in sk.ed_model_names():
		cat.append(["model:" + str(mn), str(mn).get_basename() + " (3D)", true])
	kind_i = clampi(kind_i, 0, cat.size() - 1)
	var w: Window = sk.get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED   # interfaccia nitida a risoluzione reale
	hidden_layers.clear()
	for ch in sk.gm.get_children():
		if ch is CanvasLayer and (ch as CanvasLayer).visible:
			(ch as CanvasLayer).visible = false
			hidden_layers.append(ch)
	_build_ui()
	ghost = MeshInstance3D.new()
	ghost.material_override = sk.mat
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sk.vp.add_child(ghost)
	ring = _make_ring(Color(1.0, 0.85, 0.3))
	ring_sel = _make_ring(Color(0.3, 0.9, 1.0))
	set_tool(0)
	undo.clear()
	sel = -1


func _exit() -> void:
	if dirty:
		_save()
	on = false
	sk.gm.state = prev_state
	sk.curve = saved_curve
	sk.fixed_cam = false
	var w: Window = sk.get_window()
	w.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	w.content_scale_size = Vector2i(480, 270)
	for ch in hidden_layers:
		if is_instance_valid(ch):
			(ch as CanvasLayer).visible = true
	hidden_layers.clear()
	for n in [layer, ghost, ring, ring_sel]:
		if is_instance_valid(n):
			n.queue_free()
	ghost_key = ""


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(290, 0)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var t := Label.new()
	t.text = "EDITOR MONDO 3D"
	vb.add_child(t)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	tool_btns.clear()
	for i in 3:
		var b := Button.new()
		b.text = ["1 Piazza", "2 Seleziona", "3 Gomma"][i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(set_tool.bind(i))
		hb.add_child(b)
		tool_btns.append(b)
	lst = ItemList.new()
	lst.custom_minimum_size = Vector2(0, 340)
	lst.focus_mode = Control.FOCUS_NONE
	lst.allow_search = false
	for c in cat:
		lst.add_item(str(c[1]))
	lst.item_selected.connect(func(i: int) -> void:
		kind_i = i
		yaw = 0.0
		seed_i = randi() % 100000
		set_tool(0))
	vb.add_child(lst)
	lst.select(kind_i)
	var hb2 := HBoxContainer.new()
	vb.add_child(hb2)
	for nm in [["Salva", "_save"], ["Annulla", "do_undo"], ["Esci", "_exit"]]:
		var b2 := Button.new()
		b2.text = nm[0]
		b2.focus_mode = Control.FOCUS_NONE
		b2.pressed.connect(Callable(self, nm[1]))
		hb2.add_child(b2)
	info = Label.new()
	info.custom_minimum_size = Vector2(270, 0)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)


func _make_ring(col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.93
	t.outer_radius = 1.0
	t.rings = 40
	t.ring_segments = 6
	m.mesh = t
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = col
	mt.no_depth_test = true
	mt.disable_fog = true
	m.material_override = mt
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	sk.vp.add_child(m)
	return m


func set_tool(i: int) -> void:
	tool = i
	for k in tool_btns.size():
		(tool_btns[k] as Button).set_pressed_no_signal(k == i)
	if i != 1:
		sel = -1


func _over_panel() -> bool:
	return panel != null and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


## punto del terreno sotto il mouse (spazio di gioco); la camera guarda dritta in basso e la curvatura e' a zero
func _ground_at() -> Variant:
	var m := get_viewport().get_mouse_position()
	var rc: Rect2 = sk.post_rect.get_global_rect()
	if not rc.has_point(m):
		return null
	var u := (m - rc.position) / rc.size
	var vpp := u * Vector2(sk.vp.size)
	var o: Vector3 = sk.cam.project_ray_origin(vpp)
	var n: Vector3 = sk.cam.project_ray_normal(vpp)
	if absf(n.y) < 0.001:
		return null
	var t := -o.y / n.y
	return Vector2(o.x + n.x * t, o.z + n.z * t)


func _process(dt: float) -> void:
	if not on:
		return
	msg_t -= dt
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		pos += dir.normalized() * zoom_h * (1.8 if Input.is_key_pressed(KEY_SHIFT) else 0.9) * dt
	pos = Vector2(clampf(pos.x, 4.0, float(Game.MW) - 4.0), clampf(pos.y, 4.0, float(Game.MH) - 4.0))
	sk.cam_h = zoom_h
	fade = clampf(zoom_h * 1.4, 27.0, 90.0)
	var g = _ground_at()
	mvalid = g != null and not _over_panel()
	if g != null:
		mpos = g
	_update_markers()
	if tool == 2 and mvalid and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and mpos.distance_to(last_erase) > erase_r * 0.6:
		last_erase = mpos
		_do_erase(false)
	if not sk.jobs.is_empty():
		sk._run_jobs(8.0)
	_update_info()


func _update_markers() -> void:
	ring.visible = mvalid
	ghost.visible = false
	if mvalid:
		var rr := 0.5
		if tool == 2:
			rr = erase_r
		elif tool == 1:
			rr = 0.4
		ring.position = Vector3(mpos.x, 0.25, mpos.y)
		ring.scale = Vector3(rr, 0.4, rr)
		(ring.material_override as StandardMaterial3D).albedo_color = [Color(1.0, 0.85, 0.3), Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.25)][tool]
		if tool == 0:
			_ghost_for(str(cat[kind_i][0]), yaw, seed_i, scl)
			ghost.position = Vector3(mpos.x, 0.0, mpos.y)
			ghost.visible = true
		elif tool == 1 and dragging and sel >= 0:
			var a: Dictionary = sk.ed_adds[sel]
			_ghost_for(str(a["k"]), float(a["yaw"]), int(a["s"]), float(a.get("sc", 1.0)))
			ghost.position = Vector3(mpos.x, 0.0, mpos.y)
			ghost.visible = true
	ring_sel.visible = sel >= 0 and sel < sk.ed_adds.size() and not dragging
	if ring_sel.visible:
		var a2: Dictionary = sk.ed_adds[sel]
		var gp: Vector2 = Vector2(float(a2["x"]), float(a2["z"])) + sk.world_off
		ring_sel.position = Vector3(gp.x, 0.25, gp.y)
		ring_sel.scale = Vector3(2.0, 0.4, 2.0)


## anteprima: stessa costruzione e stesso seme dell'oggetto vero, cosi' quello che vedi e' quello che piazzi
func _ghost_for(k: String, y: float, s: int, sc: float) -> void:
	var key := "%s|%d|%d|%d" % [k, roundi(y * 100.0), s, roundi(sc * 100.0)]
	if key == ghost_key:
		return
	ghost_key = key
	var b := W3DBuilder.new()
	b.sat = 1.55
	b.con = 1.45
	var r := RandomNumberGenerator.new()
	r.seed = s
	b.rn.seed = r.randi()
	var hd: Dictionary = sk.house_doors.duplicate()      # la costruzione di una casa registrerebbe una porta in (0,0)
	sk._ed_make(k, b, Vector2.ZERO, y, r, [], [], sc)
	sk.house_doors = hd
	ghost.mesh = b.mesh()


func _update_info() -> void:
	var cur := ""
	if mvalid:
		var pr: Vector2 = mpos - sk.world_off
		cur = "  (%.0f, %.0f)" % [pr.x, pr.y]
	var tl: String = ["PIAZZA: clic sinistro mette l'oggetto, R lo ruota, V cambia variante, + e - cambiano la scala (%.1fx)" % scl, "SELEZIONA: clic su un oggetto che hai piazzato, trascina per spostare, R ruota, + e - scala, Canc elimina", "GOMMA: clic e trascina cancella tutto nel cerchio ([ ] cambiano il raggio: %.1f)" % erase_r][tool]
	var s: String = tl + "\n\nOggetti aggiunti: %d   Zone cancellate: %d%s\nWASD muovi (Maiusc veloce), rotella zoom\nCtrl+Z annulla, Ctrl+S salva, F12 o Esc esce%s" % [sk.ed_adds.size(), sk.ed_erase.size(), cur, "\n*** modifiche non salvate ***" if dirty else ""]
	if msg_t > 0.0:
		s += "\n" + msg
	info.text = s


func _unhandled_input(ev: InputEvent) -> void:
	if not on:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			zoom_h = clampf(zoom_h * (0.9 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 10.0, 80.0)
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mvalid:
				_click()
			elif not mb.pressed:
				_release()
			get_viewport().set_input_as_handled()
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k := ev as InputEventKey
		match k.keycode:
			KEY_ESCAPE:
				_exit()
			KEY_1:
				set_tool(0)
			KEY_2:
				set_tool(1)
			KEY_3:
				set_tool(2)
			KEY_R:
				if tool == 1 and sel >= 0 and sel < sk.ed_adds.size():
					_push_undo()
					var a: Dictionary = sk.ed_adds[sel]
					a["yaw"] = float(a["yaw"]) + (-PI / 8.0 if k.shift_pressed else PI / 8.0)
					_rebuild_at(Vector2(float(a["x"]), float(a["z"])), 12.0)
					dirty = true
				else:
					yaw += -PI / 8.0 if k.shift_pressed else PI / 8.0
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT:
				var f := 1.1 if (k.keycode == KEY_EQUAL or k.keycode == KEY_PLUS or k.keycode == KEY_KP_ADD) else 1.0 / 1.1
				if tool == 1 and sel >= 0 and sel < sk.ed_adds.size():
					_push_undo()
					var a3: Dictionary = sk.ed_adds[sel]
					a3["sc"] = clampf(float(a3.get("sc", 1.0)) * f, 0.2, 6.0)
					_rebuild_at(Vector2(float(a3["x"]), float(a3["z"])), 14.0)
					dirty = true
				else:
					scl = clampf(scl * f, 0.2, 6.0)
			KEY_V:
				seed_i = randi() % 100000
			KEY_DELETE, KEY_BACKSPACE:
				_delete_sel()
			KEY_BRACKETLEFT:
				erase_r = maxf(1.0, erase_r - 0.5)
			KEY_BRACKETRIGHT:
				erase_r = minf(14.0, erase_r + 0.5)
			KEY_PAGEUP:
				_pick_kind(-1)
			KEY_PAGEDOWN:
				_pick_kind(1)
			KEY_Z:
				if k.ctrl_pressed:
					do_undo()
			KEY_S:
				if k.ctrl_pressed:
					_save()
		get_viewport().set_input_as_handled()


func _pick_kind(d: int) -> void:
	kind_i = posmod(kind_i + d, cat.size())
	lst.select(kind_i)
	lst.ensure_current_is_visible()
	yaw = 0.0
	seed_i = randi() % 100000
	set_tool(0)


func _click() -> void:
	var pr: Vector2 = mpos - sk.world_off
	match tool:
		0:
			_push_undo()
			sk.ed_adds.append({"k": cat[kind_i][0], "sc": scl, "x": snappedf(pr.x, 0.01), "z": snappedf(pr.y, 0.01), "yaw": yaw, "s": seed_i})
			_rebuild_at(pr, 14.0)
			seed_i = randi() % 100000
			dirty = true
		1:
			sel = _nearest_add(pr, 3.5)
			dragging = sel >= 0
			drag_moved = false
			drag_start = mpos
		2:
			last_erase = mpos
			_do_erase(true)


func _release() -> void:
	if tool == 1 and dragging and sel >= 0 and sel < sk.ed_adds.size() and mvalid and mpos.distance_to(drag_start) > 0.4:
		_push_undo()
		var a: Dictionary = sk.ed_adds[sel]
		var old := Vector2(float(a["x"]), float(a["z"]))
		var pr: Vector2 = mpos - sk.world_off
		a["x"] = snappedf(pr.x, 0.01)
		a["z"] = snappedf(pr.y, 0.01)
		_rebuild_at(old, 14.0)
		_rebuild_at(pr, 14.0)
		dirty = true
	dragging = false


func _nearest_add(pr: Vector2, maxd: float) -> int:
	var best := -1
	var bd := maxd
	for i in sk.ed_adds.size():
		var a: Dictionary = sk.ed_adds[i]
		var d := Vector2(float(a["x"]), float(a["z"])).distance_to(pr)
		if d < bd:
			bd = d
			best = i
	return best


func _delete_sel() -> void:
	if sel < 0 or sel >= sk.ed_adds.size():
		return
	_push_undo()
	var a: Dictionary = sk.ed_adds[sel]
	var p := Vector2(float(a["x"]), float(a["z"]))
	sk.ed_adds.remove_at(sel)
	sel = -1
	_rebuild_at(p, 14.0)
	dirty = true


func _do_erase(first: bool) -> void:
	var pr: Vector2 = mpos - sk.world_off
	if first:
		_push_undo()
	var i: int = sk.ed_adds.size() - 1
	while i >= 0:
		var a: Dictionary = sk.ed_adds[i]
		if Vector2(float(a["x"]), float(a["z"])).distance_to(pr) < erase_r:
			sk.ed_adds.remove_at(i)
		i -= 1
	sk.ed_erase.append([snappedf(pr.x, 0.01), snappedf(pr.y, 0.01), erase_r])
	sel = -1
	_rebuild_at(pr, erase_r + 14.0)
	dirty = true


func _push_undo() -> void:
	undo.append([sk.ed_adds.duplicate(true), sk.ed_erase.duplicate(true)])
	if undo.size() > 60:
		undo.pop_front()


func do_undo() -> void:
	if undo.is_empty():
		return
	var s: Array = undo.pop_back()
	sk.ed_adds = s[0]
	sk.ed_erase = s[1]
	sel = -1
	for k in sk.chunks.keys():
		_rebuild_chunk(k)
	dirty = true


## rigenera i blocchi che toccano il cerchio (p in coordinate del mondo 3D)
func _rebuild_at(p: Vector2, r: float) -> void:
	for kx in range(floori((p.x - r) / W3D.CHS), floori((p.x + r) / W3D.CHS) + 1):
		for kz in range(floori((p.y - r) / W3D.CHS), floori((p.y + r) / W3D.CHS) + 1):
			var k := Vector2i(kx, kz)
			if sk.chunks.has(k) or sk.job_keys.has(k):
				_rebuild_chunk(k)


func _rebuild_chunk(k: Vector2i) -> void:
	var rc := Rect2(float(k.x * W3D.CHS), float(k.y * W3D.CHS), float(W3D.CHS), float(W3D.CHS))
	# le porte delle case di questo blocco si ricreano da sole quando le case vengono rigenerate
	for key in sk.house_doors.keys():
		var dv: Vector3 = sk.house_doors[key]
		if rc.has_point(Vector2(dv.x, dv.y)):
			sk.house_doors.erase(key)
			sk.doors_seen.erase(key)
	for i in range(sk.gm.doors.size() - 1, -1, -1):
		var d: Dictionary = sk.gm.doors[i]
		if str(d.get("dest", "")).begins_with("int|house|") and rc.has_point(Vector2(d["pos"]) / 16.0 - sk.world_off):
			sk.gm.doors.remove_at(i)
	if not sk.job_keys.has(k):
		sk._enqueue(k)


func _save() -> void:
	var path: String = sk.ed_save()
	if path == "":
		msg = "ERRORE: salvataggio non riuscito"
	else:
		dirty = false
		msg = "Salvato in " + path
	msg_t = 4.0

