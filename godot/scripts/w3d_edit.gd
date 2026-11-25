class_name W3DEdit
extends Node
## Editor del mondo dentro il gioco 3D. F12 nel mondo aperto entra/esce (esce anche con Esc e salva da solo).
## Camera libera (WASD/frecce, rotella = zoom). Strumenti: 1 PIAZZA, 2 SELEZIONA/SPOSTA, 3 GOMMA, 4 NESSUNO.
## Le modifiche stanno in w3d_edits.json (oggetti aggiunti + zone cancellate) e vengono applicate dal motore 3D a ogni blocco.

var sk                              # W3DSkin
var on := false
var pos := Vector2.ZERO             # centro della camera (spazio di gioco)
var zoom_h := 30.0
var fade := 40.0
var tool := 0                       # 0 piazza, 1 seleziona, 2 gomma, 3 nessun oggetto
var kind_i := 0
var cat: Array = []                 # catalogo: oggetti del motore + modelli .glb trovati in assets/models
var scl := 1.0
var yaw := 0.0
var seed_i := 1
var erase_r := 3.0
var sel := -1
var sel_gen: Array = []             # oggetto generato dal gioco selezionato: [tipo, posizione, rotazione, stato rng, stato rng colori]
var undo: Array = []
var dirty := false
var prev_state := "play"
var hidden_layers: Array = []
var saved_curve := 0.0
var layer: CanvasLayer
var panel: PanelContainer
var lst: ItemList
var info: Label
var cat_opt: OptionButton           # filtro per categoria
var cat_search: LineEdit            # ricerca per nome
var cat_view: Array = []            # indici di cat mostrati nella lista
var sel_label: Label
var pv_vp: SubViewport              # anteprima 3D dell'oggetto scelto nel catalogo
var pv_mi: MeshInstance3D
var pv_piv: Node3D
var pv_cam: Camera3D
var pv_name: Label
const CATS := ["Tutti", "Mondo aperto", "Interni: arredi e decori", "Interni: oggetti veri", "I miei modelli 3D", "Strutture e natura (per bioma)"]
var tool_btns: Array = []
var ghost: MeshInstance3D
var ghost_key := ""
var ring: MeshInstance3D
var ring_sel: MeshInstance3D
var dragging := false
var drag_moved := false
var drag_start := Vector2.ZERO
var interior_erase_pending := false
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
	elif sk.active and str(sk.gm.area) != "" and str(sk.gm.state) == "play":
		_enter()
	else:
		sk.gm.say("L'EDITOR RICHIEDE UNA SCENA 3D ATTIVA")


func _enter() -> void:
	on = true
	prev_state = str(sk.gm.state)
	sk.gm.state = "edit"
	sk.ed_set_area(str(sk.gm.area))
	pos = sk.gm.player.position / 16.0 if not sk.world_on else sk.pos
	zoom_h = 30.0
	saved_curve = sk.curve
	sk.curve = 0.0                     # niente curvatura: il cursore coincide con il terreno
	sk.fixed_cam = true
	_reload_catalog()
	kind_i = clampi(kind_i, 0, cat.size() - 1)
	typing = false
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
	set_tool(3)
	undo.clear()
	sel = -1


func _exit() -> void:
	if dirty:
		_save()
	if interior_erase_pending:
		sk._rebuild_static()
		interior_erase_pending = false
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


func _cat_of(c: Array) -> int:
	var id := str(c[0])
	if id.begins_with("model:"):
		return 4
	if id.begins_with("dec:"):
		return 2
	if id.begins_with("prop:"):
		return 3
	if W3DStructs.KINDS.has(id):
		return 5
	return 1


func _build_ui() -> void:
	layer = CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	panel = PanelContainer.new()
	panel.position = Vector2(10, 10)
	var wh := float(sk.get_window().size.y)
	var fs := clampi(roundi(wh / 46.0), 15, 24)       # testo e pannello si adattano alla risoluzione dello schermo
	panel.custom_minimum_size = Vector2(fs * 22, 0)
	var th := Theme.new()
	th.default_font_size = fs
	panel.theme = th
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.09, 0.94)
	sb.border_color = Color(0.75, 0.6, 0.25)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	layer.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 7)
	panel.add_child(vb)
	var t := Label.new()
	t.text = "EDITOR 3D  -  " + str(sk.gm.area).to_upper()
	t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5))
	t.add_theme_font_size_override("font_size", fs + 2)
	vb.add_child(t)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	vb.add_child(hb)
	tool_btns.clear()
	for i in 4:
		var b := Button.new()
		b.text = ["1 Piazza", "2 Seleziona", "3 Gomma", "4 Niente"][i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(set_tool.bind(i))
		hb.add_child(b)
		tool_btns.append(b)
	if sk.world_on:
		# salto rapido alle regioni del mondo
		var hg := HBoxContainer.new()
		hg.add_theme_constant_override("separation", 4)
		vb.add_child(hg)
		var gl := Label.new()
		gl.text = "Vai a:"
		hg.add_child(gl)
		var go := OptionButton.new()
		go.focus_mode = Control.FOCUS_NONE
		go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		go.add_item("(scegli una regione)")
		for bi in sk.gm.SEEDS.size():
			go.add_item(str(Game.BIO[bi]["n"]).capitalize())
		go.item_selected.connect(func(i: int) -> void:
			if i > 0:
				pos = Vector2(sk.gm.SEEDS[i - 1]) + Vector2(4, 4)
			go.select(0))
		hg.add_child(go)
	vb.add_child(HSeparator.new())
	# catalogo: categoria + ricerca + lista
	var hf := HBoxContainer.new()
	hf.add_theme_constant_override("separation", 4)
	vb.add_child(hf)
	cat_opt = OptionButton.new()
	cat_opt.focus_mode = Control.FOCUS_NONE
	for cn in CATS:
		cat_opt.add_item(cn)
	cat_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_opt.item_selected.connect(func(_i: int) -> void: _fill_list())
	hf.add_child(cat_opt)
	cat_search = LineEdit.new()
	cat_search.placeholder_text = "cerca..."
	cat_search.custom_minimum_size = Vector2(120, 0)
	cat_search.text_changed.connect(func(_s: String) -> void: _fill_list())
	cat_search.focus_entered.connect(func() -> void: typing = true)
	cat_search.focus_exited.connect(func() -> void: typing = false)
	hf.add_child(cat_search)
	lst = ItemList.new()
	lst.custom_minimum_size = Vector2(0, wh * 0.2)
	lst.focus_mode = Control.FOCUS_NONE
	lst.allow_search = false
	lst.add_theme_constant_override("v_separation", 4)
	lst.item_selected.connect(func(i: int) -> void:
		kind_i = int(lst.get_item_metadata(i))
		yaw = 0.0
		seed_i = randi() % 100000
		set_tool(0)
		_update_preview())
	vb.add_child(lst)
	# anteprima 3D
	pv_name = Label.new()
	pv_name.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vb.add_child(pv_name)
	var pc := SubViewportContainer.new()
	pc.stretch = true
	pc.custom_minimum_size = Vector2(0, wh * 0.16)
	vb.add_child(pc)
	pv_vp = SubViewport.new()
	pv_vp.own_world_3d = true
	pv_vp.size = Vector2i(360, 190)
	pv_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pc.add_child(pv_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.095, 0.12)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.58, 0.58)
	env.ambient_light_energy = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	pv_vp.add_child(we)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-50, 35, 0)
	dl.light_energy = 1.1
	pv_vp.add_child(dl)
	pv_cam = Camera3D.new()
	pv_cam.fov = 40.0
	pv_vp.add_child(pv_cam)
	pv_mi = MeshInstance3D.new()
	var pm := StandardMaterial3D.new()
	pm.vertex_color_use_as_albedo = true
	pm.roughness = 1.0
	pm.cull_mode = BaseMaterial3D.CULL_DISABLED
	pv_mi.material_override = pm
	pv_piv = Node3D.new()
	pv_vp.add_child(pv_piv)
	pv_piv.add_child(pv_mi)
	vb.add_child(HSeparator.new())
	# azioni
	var hb2 := GridContainer.new()
	hb2.columns = 3
	hb2.add_theme_constant_override("h_separation", 4)
	hb2.add_theme_constant_override("v_separation", 4)
	vb.add_child(hb2)
	for nm in [["Salva", "_save"], ["Annulla", "do_undo"], ["Esporta", "_export"], ["Importa oggetto", "_import_model"], ["Esci", "_exit"]]:
		var b2 := Button.new()
		b2.text = nm[0]
		b2.focus_mode = Control.FOCUS_NONE
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.pressed.connect(Callable(self, nm[1]))
		hb2.add_child(b2)
	sel_label = Label.new()
	sel_label.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	sel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(sel_label)
	info = Label.new()
	info.custom_minimum_size = Vector2(fs * 21, 0)
	info.add_theme_font_size_override("font_size", maxi(fs - 3, 13))
	info.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(info)
	_fill_list()
	_update_preview()


var typing := false


## riempie la lista in base a categoria e ricerca
func _fill_list() -> void:
	lst.clear()
	cat_view.clear()
	var q := cat_search.text.strip_edges().to_lower()
	var cf := cat_opt.selected
	for i in cat.size():
		var c: Array = cat[i]
		if cf > 0 and _cat_of(c) != cf:
			continue
		if q != "" and not str(c[1]).to_lower().contains(q):
			continue
		cat_view.append(i)
		lst.add_item(str(c[1]).replace(" (3D)", "").replace(" (oggetto)", "").replace(" (interno)", "").replace(" (casa)", ""))
		lst.set_item_metadata(lst.item_count - 1, i)
	_sync_list()


func _sync_list() -> void:
	for r in lst.item_count:
		if int(lst.get_item_metadata(r)) == kind_i:
			lst.select(r)
			lst.ensure_current_is_visible()
			return
	lst.deselect_all()


## anteprima 3D dell'oggetto scelto nel catalogo
func _update_preview() -> void:
	if pv_mi == null or kind_i < 0 or kind_i >= cat.size():
		return
	var k := str(cat[kind_i][0])
	pv_name.text = "Anteprima: " + str(cat[kind_i][1])
	var m: Mesh = _mesh_for(k, 0.0, 7, 1.0)
	pv_mi.mesh = m
	if m == null:
		return
	var bb := m.get_aabb()
	var c := bb.get_center()
	var rad := maxf(bb.size.length() * 0.5, 0.4)
	pv_mi.position = -c
	pv_mi.rotation = Vector3.ZERO
	pv_cam.position = Vector3(0.0, rad * 1.5, rad * 2.2)
	pv_cam.look_at(Vector3.ZERO)


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
		sel_gen = []


func _over_panel() -> bool:
	return panel != null and panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func _edit_pos(p: Vector2) -> Vector2:
	return p - sk.world_off if sk.world_on else p


func _scene_pos(p: Vector2) -> Vector2:
	return p + sk.world_off if sk.world_on else p


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
	if pv_piv != null and is_instance_valid(pv_piv):
		pv_piv.rotation.y += dt * 0.8
	if not typing:
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
	if sk.world_on:
		pos = Vector2(clampf(pos.x, 4.0, float(Game.MW) - 4.0), clampf(pos.y, 4.0, float(Game.MH) - 4.0))
	elif sk.gm.rooms is Array and not sk.gm.rooms.is_empty():
		var lo := Vector2(float(Game.MW), float(Game.MH))
		var hi := Vector2.ZERO
		for room in sk.gm.rooms:
			var rr: Rect2i = room
			lo.x = minf(lo.x, float(rr.position.x))
			lo.y = minf(lo.y, float(rr.position.y))
			hi.x = maxf(hi.x, float(rr.end.x))
			hi.y = maxf(hi.y, float(rr.end.y))
		pos = Vector2(clampf(pos.x, lo.x - 3.0, hi.x + 3.0), clampf(pos.y, lo.y - 3.0, hi.y + 3.0))
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
	ring.visible = mvalid and tool != 3
	ghost.visible = false
	if mvalid:
		var rr := 0.5
		if tool == 2:
			rr = erase_r
		elif tool == 1:
			rr = 0.4
		ring.position = Vector3(mpos.x, 0.25, mpos.y)
		ring.scale = Vector3(rr, 0.4, rr)
		if tool != 3:
			(ring.material_override as StandardMaterial3D).albedo_color = [Color(1.0, 0.85, 0.3), Color(0.3, 0.9, 1.0), Color(1.0, 0.3, 0.25)][tool]
		if tool == 0:
			_ghost_for(str(cat[kind_i][0]), yaw, seed_i, scl)
			ghost.position = Vector3(mpos.x, 0.0, mpos.y)
			ghost.visible = true
		elif tool == 1 and dragging and sel >= 0:
			var a: Dictionary = sk.ed_adds[sel]
			_ghost_for(str(a["k"]), float(a["yaw"]), int(a.get("s", 0)), float(a.get("sc", 1.0)), str(a.get("st", "")), str(a.get("os", "")), float(a.get("y0", float(a["yaw"]) if a.has("st") else 0.0)))
			ghost.position = Vector3(mpos.x, 0.0, mpos.y)
			ghost.visible = true
		elif tool == 1 and dragging and sel < 0 and not sel_gen.is_empty():
			_ghost_for(str(sel_gen[0]), float(sel_gen[2]), 0, 1.0, str(sel_gen[3]), str(sel_gen[4]), float(sel_gen[2]))
			ghost.position = Vector3(mpos.x, 0.0, mpos.y)
			ghost.visible = true
	var gen_ok := sel < 0 and not sel_gen.is_empty()
	ring_sel.visible = (gen_ok or (sel >= 0 and sel < sk.ed_adds.size())) and not dragging
	if ring_sel.visible:
		var gp: Vector2
		var rs := 2.0
		if gen_ok:
			gp = _scene_pos(sel_gen[1] as Vector2)
			rs = _sel_radius(sel_gen)
		else:
			var a2: Dictionary = sk.ed_adds[sel]
			gp = _scene_pos(Vector2(float(a2["x"]), float(a2["z"])))
		(ring_sel.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.6, 0.2) if gen_ok else Color(0.3, 0.9, 1.0)
		ring_sel.position = Vector3(gp.x, 0.25, gp.y)
		ring_sel.scale = Vector3(rs, 0.4, rs)


## anteprima: stessa costruzione e stesso seme dell'oggetto vero, cosi' quello che vedi e' quello che piazzi
func _ghost_for(k: String, y: float, s: int, sc: float, st := "", ost := "", y0 := 0.0) -> void:
	if k.begins_with("prop:"):
		if ghost_key == k:
			return
		ghost_key = k
		ghost.mesh = sk.ed_prop_mesh(k.substr(5))
		return
	var key := "%s|%d|%d|%d|%s|%d" % [k, roundi(y * 100.0), s, roundi(sc * 100.0), st, roundi(y0 * 100.0)]
	if key == ghost_key:
		return
	ghost_key = key
	ghost.mesh = _mesh_for(k, y, s, sc, st, ost, y0)


## mesh di un oggetto del catalogo, costruita come quella vera (stesso seme, quindi quello che vedi e' quello che piazzi)
func _mesh_for(k: String, y: float, s: int, sc: float, st := "", ost := "", y0 := 0.0) -> Mesh:
	if k.begins_with("prop:"):
		return sk.ed_prop_mesh(k.substr(5))
	var b := W3DBuilder.new()
	b.sat = 1.55
	b.con = 1.45
	var r := RandomNumberGenerator.new()
	if st != "":
		r.state = int(st)
		b.rn.state = int(ost)
	else:
		r.seed = s
		b.rn.seed = r.randi()
	var hd: Dictionary = sk.house_doors.duplicate()      # la costruzione di una casa registrerebbe una porta in (0,0)
	sk.fence_rule = false
	sk._ed_place(k, b, Vector2.ZERO, y, r, [], [], sc, y0)
	sk.fence_rule = true
	sk.house_doors = hd
	if b.v.size() < 3:
		return null
	return b.mesh()


func _update_info() -> void:
	var cur := ""
	if mvalid:
		var pr: Vector2 = _edit_pos(mpos)
		cur = "  (%.0f, %.0f)" % [pr.x, pr.y]
	var tl: String = ["PIAZZA: clic sinistro mette l'oggetto, R lo ruota, V cambia variante, + e - cambiano la scala (%.1fx)" % scl, "SELEZIONA: clic su un oggetto (anche del gioco: case, alberi, pozzi...), trascina per spostare, R ruota, + e - scala, Canc elimina, Ctrl+C copia e Ctrl+V incolla sotto il mouse", "GOMMA: clic e trascina cancella tutto nel cerchio ([ ] cambiano il raggio: %.1f)" % erase_r, "NESSUNO: disattiva l'anteprima e non piazza oggetti"][tool]
	var s: String = tl + "\n\nAggiunti: %d   Zone cancellate: %d%s\nWASD muovi (Maiusc veloce), rotella zoom\nCtrl+Z annulla, Ctrl+S salva, F12 o Esc esce%s" % [sk.ed_adds.size(), sk.ed_erase.size(), cur, "\n*** modifiche non salvate ***" if dirty else ""]
	if msg_t > 0.0:
		s += "\n" + msg
	sel_label.text = _sel_text()
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
			if mb.pressed and typing:
				cat_search.release_focus()
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
			KEY_4:
				set_tool(3)
			KEY_R:
				if tool == 1 and _sel_is_prop():
					_prop_turn(-PI / 8.0 if k.shift_pressed else PI / 8.0, 1.0)
				elif tool == 1 and (sel >= 0 or not sel_gen.is_empty()):
					if _begin_edit():
						var a: Dictionary = sk.ed_adds[sel]
						a["yaw"] = float(a["yaw"]) + (-PI / 8.0 if k.shift_pressed else PI / 8.0)
						_rebuild_at(Vector2(float(a["x"]), float(a["z"])), 14.0)
						dirty = true
				else:
					yaw += -PI / 8.0 if k.shift_pressed else PI / 8.0
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT:
				var f := 1.1 if (k.keycode == KEY_EQUAL or k.keycode == KEY_PLUS or k.keycode == KEY_KP_ADD) else 1.0 / 1.1
				if tool == 1 and _sel_is_prop():
					_prop_turn(0.0, f)
				elif tool == 1 and (sel >= 0 or not sel_gen.is_empty()):
					if _begin_edit():
						var a3: Dictionary = sk.ed_adds[sel]
						a3["sc"] = clampf(float(a3.get("sc", 1.0)) * f, 0.2, 6.0)
						_rebuild_at(Vector2(float(a3["x"]), float(a3["z"])), 14.0)
						dirty = true
				else:
					scl = clampf(scl * f, 0.2, 6.0)
			KEY_C:
				if k.ctrl_pressed:
					_copy_sel()
			KEY_V:
				if k.ctrl_pressed:
					_paste()
				else:
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


func _kind_label(id: String) -> String:
	for c in cat:
		if str(c[0]) == id:
			return str(c[1])
	return id


func _sel_text() -> String:
	if tool != 1:
		return ""
	if sel >= 0 and sel < sk.ed_adds.size():
		var a: Dictionary = sk.ed_adds[sel]
		return "Selezionato: %s  (scala %.1fx, rotazione %d gradi)" % [_kind_label(str(a["k"])), float(a.get("sc", 1.0)), roundi(rad_to_deg(float(a["yaw"])))]
	if not sel_gen.is_empty():
		var kk := str(sel_gen[0])
		if kk.begins_with("prop:"):
			var n = sel_gen[3]
			if is_instance_valid(n) and (n as Node).has_meta("ed_yaw"):
				return "Selezionato: %s  (scala %.1fx, rotazione %d gradi)" % [_kind_label(kk), float((n as Node).get_meta("ed_sc", 1.0)), roundi(rad_to_deg(float((n as Node).get_meta("ed_yaw"))))]
		return "Selezionato: " + _kind_label(kk)
	return "Niente selezionato: clicca un oggetto"


## Importa oggetto: sceglie un modello .glb/.gltf (fatto con Blender), lo copia nelle cartelle dei modelli e lo aggiunge al catalogo
func _import_model() -> void:
	var cb := func(ok: bool, paths: PackedStringArray, _flt: int) -> void:
		if not ok or paths.is_empty():
			return
		var got := 0
		var last := ""
		for pth in paths:
			var nm: String = sk.ed_import_model(pth)
			if nm != "":
				got += 1
				last = nm
		if got == 0:
			msg = "Importazione non riuscita: serve un file .glb o .gltf"
		else:
			_reload_catalog()
			for i in cat.size():
				if str(cat[i][0]) == "model:" + last:
					kind_i = i
			cat_opt.select(4)
			cat_search.text = ""
			_fill_list()
			_update_preview()
			set_tool(0)
			msg = "Importato %d modello/i: scegli '%s' nella lista e clicca per piazzarlo" % [got, last]
		msg_t = 7.0
	var err := DisplayServer.file_dialog_show("Importa oggetto 3D", OS.get_environment("USERPROFILE"), "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILES, PackedStringArray(["*.glb, *.gltf ; Modelli 3D (Blender)"]), cb)
	if err != OK:
		msg = "Finestra di sistema non disponibile: copia il .glb in " + ProjectSettings.globalize_path(W3D.ED_USER_MODELS) + " e riapri l'editor"
		msg_t = 8.0


func _reload_catalog() -> void:
	cat = W3D.ED_CAT.duplicate()
	cat.append_array(W3DStructs.catalog())
	sk.ed_model_cache.clear()
	for mn in sk.ed_model_names():
		cat.append(["model:" + str(mn), str(mn).get_basename() + " (3D)", true])
	for dc in sk.ED_DEC_CAT:
		cat.append(dc)
	for pc in sk.ed_prop_names():
		cat.append(pc)


func _sel_is_prop() -> bool:
	return sel < 0 and not sel_gen.is_empty() and str(sel_gen[0]).begins_with("prop:") and is_instance_valid(sel_gen[3])


## ruota/scala l'oggetto-nodo selezionato e lo riseleziona (se e' uno piazzato dall'editor il nodo viene ricreato)
func _prop_turn(d_yaw: float, factor: float) -> void:
	_push_undo()
	var e: Dictionary = sk.ed_prop_turn(sel_gen[3] as Prop, d_yaw, factor)
	var node: Node = sel_gen[3]
	for ent in sk.reg_static:
		if not str(ent[0]).begins_with("prop:") or not is_instance_valid(ent[3]):
			continue
		var pn: Node = ent[3]
		if pn == node or (pn.has_meta("ed_entry") and is_same(pn.get_meta("ed_entry"), e)):
			sel_gen = ent
			break
	dirty = true


var clip: Dictionary = {}          # appunti: {"add": {...}} oggetto piazzato/generato, oppure {"prop": tipo}


## Ctrl+C: copia l'oggetto selezionato (piazzato, generato dal gioco o oggetto-nodo)
func _copy_sel() -> void:
	clip = {}
	if sel >= 0 and sel < sk.ed_adds.size():
		clip = {"add": (sk.ed_adds[sel] as Dictionary).duplicate(true)}
	elif not sel_gen.is_empty():
		var g: Array = sel_gen
		if str(g[0]).begins_with("prop:"):
			clip = {"prop": str(g[0]).substr(5)}
		else:
			clip = {"add": {"k": g[0], "yaw": g[2], "st": str(g[3]), "os": str(g[4]), "s": 0, "sc": 1.0}}
	if clip.is_empty():
		msg = "Niente da copiare: seleziona prima un oggetto (tasto 2)"
	else:
		msg = "Copiato: Ctrl+V lo incolla dove sta il mouse"
	msg_t = 3.0


## Ctrl+V: incolla la copia sotto il mouse (si puo' ripetere); l'oggetto incollato resta selezionato, quindi si sposta e ruota subito
func _paste() -> void:
	if clip.is_empty() or not mvalid:
		return
	var pr: Vector2 = _edit_pos(mpos)
	if clip.has("prop"):
		if sk.world_on:
			msg = "Gli oggetti-nodo si incollano solo dentro dungeon e case"
			msg_t = 4.0
			return
		_push_undo()
		var ne2 := {"t": "add", "k": str(clip["prop"]), "cx": floori(pr.x), "cy": floori(pr.y)}
		sk.ed_props.append(ne2)
		sk.ed_apply_props()
		if not sk.ed_entry_ok(ne2):
			sk.ed_props.erase(ne2)
			msg = "Qui non c'e' pavimento: oggetto non incollato"
			msg_t = 3.0
		dirty = true
		return
	_push_undo()
	var a: Dictionary = (clip["add"] as Dictionary).duplicate(true)
	a["x"] = snappedf(pr.x, 0.01)
	a["z"] = snappedf(pr.y, 0.01)
	sk.ed_adds.append(a)
	sel = sk.ed_adds.size() - 1
	sel_gen = []
	_rebuild_at(pr, 14.0)
	dirty = true


func _pick_kind(d: int) -> void:
	kind_i = posmod(kind_i + d, cat.size())
	if not cat_view.has(kind_i):
		cat_opt.select(0)
		cat_search.text = ""
		_fill_list()
	_sync_list()
	_update_preview()
	yaw = 0.0
	seed_i = randi() % 100000
	set_tool(0)


func _click() -> void:
	var pr: Vector2 = _edit_pos(mpos)
	match tool:
		0:
			if str(cat[kind_i][0]).begins_with("prop:"):
				if sk.world_on:
					msg = "Gli oggetti-nodo si piazzano solo dentro dungeon e case"
					msg_t = 4.0
					return
				_push_undo()
				var ne := {"t": "add", "k": str(cat[kind_i][0]).substr(5), "cx": floori(pr.x), "cy": floori(pr.y)}
				sk.ed_props.append(ne)
				sk.ed_apply_props()
				if not sk.ed_entry_ok(ne):
					sk.ed_props.erase(ne)
					msg = "Qui non c'e' pavimento: oggetto non piazzato"
					msg_t = 3.0
				dirty = true
				return
			_push_undo()
			sk.ed_adds.append({"k": cat[kind_i][0], "sc": scl, "x": snappedf(pr.x, 0.01), "z": snappedf(pr.y, 0.01), "yaw": yaw, "s": seed_i})
			_rebuild_at(pr, 14.0)
			seed_i = randi() % 100000
			dirty = true
		1:
			_pick(pr)
			dragging = sel >= 0 or not sel_gen.is_empty()
			drag_moved = false
			drag_start = mpos
		2:
			last_erase = mpos
			_do_erase(true)


func _release() -> void:
	if tool == 1 and dragging and sel < 0 and not sel_gen.is_empty() and str(sel_gen[0]).begins_with("prop:"):
		if mvalid and mpos.distance_to(drag_start) > 0.4 and is_instance_valid(sel_gen[3]):
			var dv: Vector2 = mpos - drag_start
			var dc := Vector2i(roundi(dv.x), roundi(dv.y))
			if dc != Vector2i.ZERO:
				_push_undo()
				if not sk.ed_prop_move(sel_gen[3] as Prop, dc):
					msg = "Qui non c'e' pavimento: l'oggetto resta dov'era"
					msg_t = 3.0
				sel_gen = []
				dirty = true
		dragging = false
		return
	if tool == 1 and dragging and mvalid and mpos.distance_to(drag_start) > 0.4 and _begin_edit():
		var a: Dictionary = sk.ed_adds[sel]
		var old := Vector2(float(a["x"]), float(a["z"]))
		var pr: Vector2 = _edit_pos(mpos)
		a["x"] = snappedf(pr.x, 0.01)
		a["z"] = snappedf(pr.y, 0.01)
		_rebuild_at(old, 14.0)
		_rebuild_at(pr, 14.0)
		dirty = true
	elif tool == 2 and interior_erase_pending:
		sk._rebuild_static()
		interior_erase_pending = false
	dragging = false


## raggio di selezione di un oggetto piazzato
func _add_radius(a: Dictionary) -> float:
	return maxf(0.9, _gen_radius(str(a["k"])) * float(a.get("sc", 1.0)))


## sceglie l'oggetto sotto il cursore fra TUTTI i candidati (piazzati, generati dal gioco, oggetti-nodo): vince il piu' vicino,
## con un leggero vantaggio per quelli piccoli, cosi' una sedia dentro una casa non viene scavalcata dalla casa
func _pick(pr: Vector2) -> void:
	var best_score := 1e9
	var best_sel := -1
	var best_gen: Array = []
	for i in sk.ed_adds.size():
		var a: Dictionary = sk.ed_adds[i]
		var rad := _add_radius(a)
		var d := Vector2(float(a["x"]), float(a["z"])).distance_to(pr)
		if d < rad and d + 0.25 * rad < best_score:
			best_score = d + 0.25 * rad
			best_sel = i
			best_gen = []
	for ent in _gen_candidates(pr):
		var rad2 := _sel_radius(ent)
		var d2: float = (ent[1] as Vector2).distance_to(pr)
		if d2 < rad2 and d2 + 0.25 * rad2 < best_score:
			best_score = d2 + 0.25 * rad2
			best_sel = -1
			best_gen = ent
	sel = best_sel
	sel_gen = best_gen


func _gen_candidates(pr: Vector2) -> Array:
	var out: Array = []
	if not sk.world_on:
		out.append_array(sk.reg_static)
		return out
	var c0 := Vector2i(floori(pr.x / W3D.CHS), floori(pr.y / W3D.CHS))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c0 + Vector2i(dx, dz)
			if sk.chunks.has(k):
				out.append_array(sk.chunks[k].get("reg", []))
	return out


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
	if sel < 0 and not sel_gen.is_empty() and str(sel_gen[0]).begins_with("prop:"):
		if is_instance_valid(sel_gen[3]):
			_push_undo()
			sk.ed_prop_delete(sel_gen[3] as Prop)
			dirty = true
		sel_gen = []
		return
	if sel < 0 and not sel_gen.is_empty():       # oggetto del gioco: si nasconde
		_push_undo()
		var gp: Vector2 = sel_gen[1]
		sk.ed_hide.append([roundi(gp.x * 100.0), roundi(gp.y * 100.0)])
		sk.ed_hide_sync()
		sel_gen = []
		_rebuild_at(gp, 14.0)
		dirty = true
		return
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
	var pr: Vector2 = _edit_pos(mpos)
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
	if not sk.world_on:
		interior_erase_pending = true
	_rebuild_at(pr, erase_r + 14.0)
	dirty = true


func _push_undo() -> void:
	undo.append([sk.ed_adds.duplicate(true), sk.ed_erase.duplicate(true), sk.ed_hide.duplicate(true), sk.ed_props.duplicate(true)])
	if undo.size() > 60:
		undo.pop_front()


func do_undo() -> void:
	if undo.is_empty():
		return
	var s: Array = undo.pop_back()
	sk.ed_adds = s[0]
	sk.ed_erase = s[1]
	sk.ed_hide = s[2]
	if s.size() > 3:
		sk.ed_props = s[3]
	sk.ed_hide_sync()
	sel = -1
	sel_gen = []
	if sk.world_on:
		for k in sk.chunks.keys():
			_rebuild_chunk(k)
	else:
		sk._rebuild_static()
	dirty = true


## rigenera i blocchi che toccano il cerchio (p in coordinate del mondo 3D)
func _rebuild_at(p: Vector2, r: float) -> void:
	if not sk.world_on:
		if not interior_erase_pending:
			sk._rebuild_static()
		return
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


## Esporta: salva le modifiche in un file a scelta (da mettere in godot/data/w3d_edits.json per includerle nelle prossime compilazioni)
func _export() -> void:
	var txt: String = sk.ed_json()
	var cb := func(ok: bool, paths: PackedStringArray, _flt: int) -> void:
		if not ok or paths.is_empty():
			return
		var f := FileAccess.open(paths[0], FileAccess.WRITE)
		if f == null:
			msg = "ERRORE: esportazione non riuscita"
		else:
			f.store_string(txt)
			f.close()
			msg = "Esportato in " + paths[0]
		msg_t = 6.0
	var err := DisplayServer.file_dialog_show("Esporta le modifiche", OS.get_executable_path().get_base_dir(), "w3d_edits.json", false, DisplayServer.FILE_DIALOG_MODE_SAVE_FILE, PackedStringArray(["*.json ; File JSON"]), cb)
	if err != OK:
		# niente finestra di sistema: copia accanto all'exe
		var alt := OS.get_executable_path().get_base_dir().path_join("w3d_edits_export.json")
		var f2 := FileAccess.open(alt, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(txt)
			f2.close()
			msg = "Esportato in " + alt
		else:
			msg = "ERRORE: esportazione non riuscita"
		msg_t = 6.0


func _save() -> void:
	var path: String = sk.ed_save()
	if path == "":
		msg = "ERRORE: salvataggio non riuscito"
	else:
		dirty = false
		msg = "Salvato in " + path
	msg_t = 4.0



## prepara la modifica dell'oggetto selezionato: se e' del gioco lo trasforma in uno piazzato (stessa forma) e nasconde l'originale
func _begin_edit() -> bool:
	if sel < 0 and not sel_gen.is_empty() and str(sel_gen[0]).begins_with("prop:"):
		return false
	if sel < 0 and not sel_gen.is_empty():
		_push_undo()
		var g: Array = sel_gen
		var gp: Vector2 = g[1]
		sk.ed_hide.append([roundi(gp.x * 100.0), roundi(gp.y * 100.0)])
		sk.ed_hide_sync()
		sk.ed_adds.append({"k": g[0], "x": gp.x, "z": gp.y, "yaw": g[2], "y0": g[2], "st": str(g[3]), "os": str(g[4]), "s": 0, "sc": 1.0})
		sel = sk.ed_adds.size() - 1
		sel_gen = []
		return true
	if sel >= 0 and sel < sk.ed_adds.size():
		_push_undo()
		return true
	return false


func _sel_radius(ent: Array) -> float:
	if str(ent[0]).begins_with("prop:"):
		return float(ent[4])
	return _gen_radius(str(ent[0]))


func _gen_radius(k: String) -> float:
	match k:
		"house", "chapel", "mausoleum":
			return 4.0
		"ruin", "gallows", "pyre", "well", "dec:sarc", "dec:altar", "dec:rack":
			return 2.0 if k.begins_with("dec:") else 2.5
		"dec:torch", "dec:candles", "dec:hlamp":
			return 1.0
		"dec:beam":
			return 1.3
	if k.begins_with("dec:w_"):
		return 1.1
	if W3DStructs.KINDS.has(k):
		return W3DStructs.radius(k) * 0.8
	return 1.5


func _nearest_gen(pr: Vector2) -> Array:
	var best: Array = []
	var bd := 1e9
	if not sk.world_on:
		for ent in sk.reg_static:
			var d2: float = (ent[1] as Vector2).distance_to(pr)
			if d2 < _sel_radius(ent) and d2 < bd:
				bd = d2
				best = ent
		return best
	var c0 := Vector2i(floori(pr.x / W3D.CHS), floori(pr.y / W3D.CHS))
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var k := c0 + Vector2i(dx, dz)
			if not sk.chunks.has(k):
				continue
			for ent in sk.chunks[k].get("reg", []):
				var d: float = (ent[1] as Vector2).distance_to(pr)
				if d < _gen_radius(str(ent[0])) and d < bd:
					bd = d
					best = ent
	return best
