class_name W3DCine
extends RefCounted
## CUTSCENE GENERICHE guidate da dati (data/cutscenes.json; l'editor salva in user://cutscenes.json, che ha la precedenza).
## Una cutscene = durata + ancore (punti calcolati nel mondo) + attori con tracce di keyframe + traccia camera + traccia ambiente + eventi.
##  - posizione di una chiave = posizione dell'ancora/attore "a" + offset "o" ruotato come l'ancora; rotazione "r" = euler + yaw dell'ancora
##  - camera m=0 dall'alto (o.y = altezza), m=1 libera (r = pitch,yaw,roll); "cut":1 = taglio secco, "e" = curva (0 lineare,1 morbida,2 accelera,3 frena)
##  - eventi: flash{c,a} shake{v} snd{n} burst{a,c,n,sp} say{x} fx{a,f:smoke|fire,on}
## Editor: F6 (W3DCineEdit). Rivedere la sequenza: F10. Saltare: INVIO/SPAZIO/ESC.

const FLAG := "ufo_cine"
const DEFAULT_RATE := 0.85       # velocita' di tutte le cutscene (1 = tempi della timeline); ognuna puo' avere la sua "velocita"
const FILES := ["user://cutscenes.json", "res://data/cutscenes.json"]
const BASE_SC := {"ufo": 0.8, "device": 1.5, "hero": 1.0}
static var ufo_mesh_cache: ArrayMesh

var sk                      # W3DSkin
var gm                      # Main
var id := "ufo"
var cut: Dictionary = {}
var active := false
var edit := false
var playing := true
var ed                      # W3DCineEdit
var t := 0.0
var tp := 0.0
var anchors: Dictionary = {}
var acts: Dictionary = {}
var Dv := Vector2.ZERO
var wreck_ok := false
var layer: CanvasLayer
var flash: ColorRect
var bar_t: ColorRect
var bar_b: ColorRect
var flash_a := 0.0
var flash_col := Color.WHITE
var shk := 0.0
var saved := {}
var edit_pos := Vector2.ZERO
var frame_n := 0
var cam_xz := Vector2.ZERO
var waited: Array = []
var preview := false
var dlg: PanelContainer
var dlg_lab: Label
var dlg_t0 := 0.0
var dlg_until := 0.0
var mus: AudioStreamPlayer
var loadlab: Label
var end_spot := Vector2.ZERO
var step_dt := 0.0
var hold := 0.0
var stage: W3DUfoShow           # cutscene con "scena": "radura": si gira nella Radura Temporale, con i suoi effetti
var own_stage := false          # radura allestita solo per l'editor (fuori dallo scontro)
var fxs: W3DUfoShow             # effetti nelle cutscene normali ("effetti": 1): cielo, fulmini, vortice, onde
var on_done: Callable


# ------------------------------------------------------------------ dati
static func load_all() -> Dictionary:
	# si uniscono cutscene per cutscene: quelle modificate (user://) valgono su quelle del gioco,
	# quelle nuove del gioco compaiono anche se esiste gia' un file salvato dall'editor
	var out := {}
	for i in range(FILES.size() - 1, -1, -1):
		var path: String = FILES[i]
		if FileAccess.file_exists(path):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Dictionary:
				out.merge(d, true)
	return out


static func save_all(d: Dictionary) -> String:
	var txt := JSON.stringify(d, " ")
	var out := ""
	for path in FILES:
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_string(txt)
			out += path + " "
	return out


func _sort_all() -> void:
	for arr in _tracks().values():
		(arr as Array).sort_custom(func(a, b): return float(a["t"]) < float(b["t"]))


## tutte le tracce modificabili: nome -> array di chiavi
func _tracks() -> Dictionary:
	var o := {"cam": cut["cam"]}
	for n in cut["act"]:
		o[n] = cut["act"][n]
	for n in cut.get("fx", {}):
		o[n] = cut["fx"][n]
	if str(cut.get("scena", "")) != "radura":
		o["env"] = cut["env"]
	o["ev"] = cut["ev"]
	if not cut.has("mus"):
		cut["mus"] = []
	o["musica"] = cut["mus"]
	return o


# ------------------------------------------------------------------ partenza / fine
func start(skin, cid := "ufo", editing := false) -> bool:
	if active or skin == null or not skin.world_on:
		return false
	sk = skin
	gm = skin.gm
	id = cid
	var all := load_all()
	if not all.has(id):
		return false
	cut = all[id]
	_sort_all()
	edit = editing
	playing = not editing
	if str(cut.get("scena", "")) == "radura":
		return _start_stage()
	_plan()
	# "G" = l'inquadratura di gioco al momento della partenza (chiavi della camera con "auto" = 1)
	anchors["G"] = {"p": sk.cam.position, "yaw": 0.0, "rot": sk.cam.rotation, "fov": sk.cam.fov}
	_set_pins()
	saved = {"curve": sk.curve, "fixed": sk.fixed_cam, "cam_h": sk.cam_h}
	edit_pos = gm.player.position
	active = true
	t = 0.0
	tp = 0.0
	flash_a = 0.0
	gm.state = "cine"
	if gm.hud != null:
		gm.hud.set("visible", false)
	sk.stream_margin = 24.0
	sk.fixed_cam = true
	_build()
	if int(cut.get("effetti", 0)) == 1:
		fxs = W3DUfoShow.new()
		fxs.setup_free(self)
	if gm.hud != null:
		gm.hud.set("visible", false)
	if edit:
		ed = W3DCineEdit.new()
		ed.setup(self)
	else:
		_eval(0.0)
	return true


## cutscene girata nella Radura Temporale: l'eroe resta dov'e' e la scena usa l'ufo dello scontro.
## Fuori dallo scontro (editor) la radura si allestisce attorno all'eroe e si toglie alla chiusura.
func _start_stage() -> bool:
	own_stage = false
	if not is_instance_valid(sk.side_scroll_temporal_ufo):
		if gm.side_scroll_active:
			return false
		sk.side_scroll_temporal_begin(gm.player.position / 16.0)
		own_stage = true
	saved = {"curve": sk.curve, "fixed": sk.fixed_cam, "cam_h": sk.cam_h}
	stage = W3DUfoShow.new()
	if not stage.setup(self):
		stage = null
		return false
	anchors = stage.anchors
	edit_pos = gm.player.position
	active = true
	t = 0.0
	tp = 0.0
	flash_a = 0.0
	gm.state = "cine"
	gm.shake_v = 0.0
	sk.fixed_cam = true
	_build()
	if gm.hud != null:
		gm.hud.set("visible", false)
	if edit:
		ed = W3DCineEdit.new()
		ed.setup(self)
	else:
		_eval(0.0)
	return true


func _finish_stage(apply_end: bool) -> void:
	active = false
	_music_stop(1.0)
	gm.state = "play"
	stage.cleanup(id)
	for n in acts.keys():
		if is_instance_valid(acts[n]):
			(acts[n] as Node).queue_free()
	acts.clear()
	if ed != null:
		ed.close()
		ed = null
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	sk.fixed_cam = bool(saved["fixed"])
	sk.curve = float(saved["curve"])
	sk.cam_h = float(saved["cam_h"])
	sk.cam.near = 2.0
	sk.cam.far = 120.0
	sk.cam.rotation_degrees = Vector3(-90, 0, 0)
	if gm.hud != null:
		gm.hud.set("visible", true)
	if own_stage:
		sk.side_scroll_temporal_clear()
	if apply_end and not edit and on_done.is_valid():
		on_done.call()


func _plan() -> void:
	anchors.clear()
	var P0: Vector2 = gm.player.position / 16.0
	var V := Vector2(gm.SEEDS[0])
	var best := 1e9
	var bdir: Vector2 = (V - Vector2(Game.MW, Game.MH) * 0.5).normalized()
	for k in 12:
		var d := Vector2.from_angle(TAU * k / 12.0)
		var s := 8
		while s < 150:
			var c := Vector2i(V + d * float(s))
			gm.ensure_area(gm.cell_pos(c), 1)
			if gm.inb(c) and gm.outside[gm.idx(c)] == 1:
				if s < best:
					best = s
					bdir = d
				break
			s += 5
	if best > 1e8:
		best = 40.0
	var edge: Vector2 = V + bdir * float(best)
	var Bw := edge - bdir * 1.5
	var hc: Vector2i = gm.free_near(Vector2i(edge - bdir * 12.0))
	var H := Vector2(hc) + Vector2(0.5, 0.5)
	var side := Vector2(-bdir.y, bdir.x)
	var dc: Vector2i = gm.free_near(Vector2i(H + side * 3.5 + bdir * 1.5))
	var D := Vector2(dc) + Vector2(0.5, 0.5)
	var F1 := Bw - bdir * 16.0
	var F0 := F1 - bdir * 62.0
	var hd := (F1 - P0)
	if hd.length() < 1.0:
		hd = bdir
	hd = hd.normalized()
	var fy := atan2(-hd.x, -hd.y)       # il volo va da dove sei stato rapito verso il villaggio
	Dv = D
	var pts := {"P0": P0, "V": V, "F0": F0, "F1": F1, "Bw": Bw, "H": H, "Dv": D, "M": (H + Bw) * 0.5}
	for n in pts:
		var q: Vector2 = pts[n]
		anchors[n] = {"p": Vector3(q.x, sk.elev_at(q.x, q.y), q.y), "yaw": fy if n in ["P0", "F0", "F1"] else 0.0}
	print("CINE piano: bordo a ", best, " celle; ancore: ", pts, " quote: ", pts.keys().map(func(n): return [n, snappedf(anchors[n]["p"].y, 0.01)]))


## precarica in background il terreno lungo il percorso scriptato (volo, schianto, atterraggio): chiamata un po' prima del rapimento
func prewarm(skin) -> void:
	sk = skin
	gm = skin.gm
	_plan()
	_set_pins()


func _set_pins() -> void:
	var pts: Array = []
	var a: Vector3 = anchors["P0"]["p"]
	var b: Vector3 = anchors["F1"]["p"]
	var nseg := clampi(int(ceil(Vector2(a.x - b.x, a.z - b.z).length() / 25.0)), 2, 14)
	for i in nseg + 1:
		pts.append(a.lerp(b, float(i) / nseg))
	for n in ["Bw", "H", "Dv", "M"]:
		pts.append(anchors[n]["p"])
	sk.pins.clear()
	for q in pts:
		sk.pins.append(Vector2(q.x, q.z) - sk.world_off)
	print("CINE precarico: ", sk.pins.size(), " zone lungo il percorso")


func _safe_spot(c: Vector2) -> Vector2:
	# primo punto libero (anche dai solidi del mondo 3D) attorno a c: l'eroe non deve restare incastrato
	for ring in range(0, 21):
		for a in (1 if ring == 0 else 16):
			var p := c * 16.0 + Vector2.from_angle(TAU * a / 16.0) * (ring * 8.0)
			if gm.free_at(p, 5.0):
				return p
	return c * 16.0


func finish(apply_end := true) -> void:
	if not active:
		return
	if stage != null:
		_finish_stage(apply_end)
		return
	var en: Dictionary = cut.get("end", {})
	if apply_end:
		_eval(float(cut["dur"]), false)
	active = false
	_music_stop(2.0)
	if fxs != null:
		fxs.cleanup(id)
		fxs = null
		sk._mp("near_cut", 0.0)
	Engine.time_scale = 1.0
	gm.state = "play"
	if apply_end and en.has("at"):
		var q: Vector3 = anchors[str(en["at"])]["p"]
		gm.player.position = _safe_spot(Vector2(q.x, q.z))
		end_spot = gm.player.position
	else:
		gm.player.position = edit_pos
	gm.player.cam.reset_smoothing()
	sk.stream_margin = 30.0
	sk.pins.clear()
	sk.job_boost = false
	sk.fixed_cam = bool(saved["fixed"])
	sk.curve = float(saved["curve"])
	sk.cam_h = float(saved["cam_h"])
	sk.cam.fov = 38.6
	sk.cam.near = 2.0
	sk.cam.far = 120.0
	sk.cam.rotation_degrees = Vector3(-90, 0, 0)
	var keep: Array = cut.get("end", {}).get("keep", []) if apply_end else []
	for n in acts.keys():
		if not keep.has(n) and is_instance_valid(acts[n]):
			(acts[n] as Node).queue_free()
			acts.erase(n)
	if ed != null:
		ed.close()
		ed = null
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	if gm.hud != null:
		gm.hud.set("visible", true)
	if not apply_end:
		return
	var f: Dictionary = Story.flags(gm)
	f[FLAG] = true
	if en.has("fire"):
		gm.last_fire = {"area": "world", "cell": Vector2i(floori(end_spot.x / 16.0), floori(end_spot.y / 16.0))}      # se muori ora ti svegli dove sei caduto
	if en.has("dev"):
		var dq: Vector3 = anchors[str(en["dev"])]["p"]
		f["dev_x"] = dq.x
		f["dev_y"] = dq.z
	if en.has("say"):
		gm.say(str(en["say"]))
	gm.save_game()


## rimette in scena i resti (ufo nel bordo + apparecchio) quando si ricarica una partita dopo la sequenza
func wreck_alive() -> bool:
	return acts.has("ufo") and is_instance_valid(acts["ufo"]) and (acts["ufo"] as Node).is_inside_tree()


func restore_wreck(skin) -> void:
	if wreck_alive():
		return
	var all := load_all()
	if not all.has(id):
		return
	sk = skin
	gm = skin.gm
	cut = all[id]
	_sort_all()
	_plan()
	var keep: Array = cut.get("end", {}).get("keep", [])
	acts.clear()
	for n in keep:
		acts[n] = _make_actor(str(cut["actors"].get(n, n)))
	_eval(float(cut["dur"]), false)
	if acts.has("device"):
		acts["device"].visible = not Story.is_done(gm, Story.CHRONO)
		acts["pillar"].visible = acts["device"].visible
	wreck_ok = true


## l'eroe ha preso l'apparecchio: sparisce insieme al pilastro di luce
func take_device() -> void:
	for n in ["device", "pillar"]:
		if acts.has(n) and is_instance_valid(acts[n]):
			acts[n].visible = false


func skip() -> void:
	if active and not edit and (stage == null or t > 0.8):      # nello scontro non si salta per sbaglio col tasto appena premuto
		finish()


static func ufo_mesh() -> ArrayMesh:
	if ufo_mesh_cache != null:
		return ufo_mesh_cache
	var b := W3DBuilder.new()
	var hull := Color(0.50, 0.55, 0.62)
	var dark := Color(0.20, 0.22, 0.27)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -0.9, 0)), 1.9, 5.0, 0.9, 18, dark, 0.05)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), 5.0, 3.2, 0.75, 18, hull, 0.05)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -1.15, 0)), 1.35, 1.35, 0.3, 12, Color(0.45, 1.0, 0.6, 0.15), 0.0)
	b.blob(Vector3(0, 0.75, 0), Vector3(1.9, 1.15, 1.9), Color(0.45, 0.9, 1.0, 0.4), 10, 5, 0.03, 0.0)
	for i in 14:
		var a := TAU * i / 14.0
		var lc := Color(1.0, 0.75, 0.25, 0.18) if i % 2 == 0 else Color(0.4, 1.0, 0.7, 0.18)
		b.box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 4.75, 0.1, sin(a) * 4.75)), Vector3(0.55, 0.4, 0.55), lc, 0.0)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0.6, 1.8, 0.3)), 0.06, 0.04, 1.4, 5, hull, 0.0)
	ufo_mesh_cache = b.mesh()
	return ufo_mesh_cache


func _mk_device_mesh() -> ArrayMesh:
	var b := W3DBuilder.new()
	var metal := Color(0.30, 0.31, 0.36)
	var gold := Color(0.85, 0.65, 0.22)
	b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), Vector3(0.9, 0.5, 0.7), metal, 0.04)
	b.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), 0.45, 0.3, 0.12, 10, gold, 0.03)
	b.blob(Vector3(0, 0.78, 0), Vector3(0.28, 0.28, 0.28), Color(0.75, 0.45, 1.0, 0.12), 8, 4, 0.02, 0.0)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		b.box(Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 0.52, 0.28, sin(a) * 0.4)), Vector3(0.14, 0.14, 0.14), Color(0.5, 0.9, 1.0, 0.2), 0.0)
	b.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(1.1, 0.1, 0.9), gold, 0.03)
	return b.mesh()


func _glow(col: Color, add := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.albedo_color = col
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	return m


func _emitter(col0: Color, col1: Color, amount: int, life: float, vmin: float, vmax: float, s0: float, s1: float, add: bool, grav: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, grav, 0)
	p.scale_amount_min = s0
	p.scale_amount_max = s1
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	sm.material = _glow(Color.WHITE, add)
	p.mesh = sm
	var g := Gradient.new()
	g.set_color(0, col0)
	g.set_color(1, col1)
	p.color_ramp = g
	p.emitting = false
	return p


## sostituisce le palline piene con sbuffi morbidi sempre rivolti alla camera
static func soften(e: CPUParticles3D, add: bool, grow: float) -> void:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var tx := GradientTexture2D.new()
	tx.gradient = g
	tx.fill = GradientTexture2D.FILL_RADIAL
	tx.fill_from = Vector2(0.5, 0.5)
	tx.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if add else BaseMaterial3D.BLEND_MODE_MIX
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tx
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	var q := QuadMesh.new()
	q.size = Vector2.ONE * grow
	q.material = m
	e.mesh = q
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _make_actor(kind: String) -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"ufo":
			mi.mesh = W3DCine.ufo_mesh()
			mi.material_override = sk.mat_prop
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			n.add_child(mi)
			var sm := _emitter(Color(0.12, 0.12, 0.14, 0.85), Color(0.2, 0.2, 0.22, 0.0), 70, 2.6, 1.0, 3.0, 1.0, 2.8, false, 1.4)
			soften(sm, false, 1.5)
			sm.name = "smoke"
			n.add_child(sm)
			var fr := _emitter(Color(1.0, 0.75, 0.3, 0.9), Color(1.0, 0.2, 0.05, 0.0), 60, 0.9, 1.0, 3.5, 0.7, 1.6, true, 2.0)
			soften(fr, true, 1.3)
			fr.name = "fire"
			n.add_child(fr)
		"device":
			mi.mesh = _mk_device_mesh()
			mi.material_override = sk.mat_prop
			n.add_child(mi)
		"pillar":
			mi.free()
			var pil := MeshInstance3D.new()      # pilastro di luce viola: si vede da lontano, l'apparecchio non va perso
			var pm := CylinderMesh.new()
			pm.top_radius = 0.12
			pm.bottom_radius = 0.35
			pm.height = 30.0
			pm.radial_segments = 8
			pm.cap_top = false
			pm.cap_bottom = false
			pil.mesh = pm
			pil.position = Vector3(0, 15.0, 0)
			pil.material_override = _glow(Color(0.7, 0.45, 1.0, 0.22))
			pil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(pil)
		"hero":
			mi.free()
			var nm: String = sk._td_name(gm.player, true)
			n = sk._make_td(nm) if nm != "" else sk._make_exact(gm.player.spr)
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
		"beam":
			var cm := CylinderMesh.new()
			cm.top_radius = 1.6
			cm.bottom_radius = 2.8
			cm.height = 1.0
			cm.radial_segments = 20
			cm.rings = 1
			cm.cap_top = false
			cm.cap_bottom = false
			mi.mesh = cm
			mi.material_override = _glow(Color(0.45, 1.0, 0.7, 0.28))
			n.add_child(mi)
		"ufo_scena", "bolla", "anelli", "vortice", "bagliore", "luce", "faro":
			mi.free()       # radura: solo punti che si muovono, il disegno e' di W3DUfoShow
		"shadow":
			var dm := CylinderMesh.new()
			dm.top_radius = 1.0
			dm.bottom_radius = 1.0
			dm.height = 0.02
			dm.radial_segments = 24
			mi.mesh = dm
			mi.material_override = _glow(Color(0.0, 0.0, 0.0, 0.55), false)
			n.add_child(mi)
		_:
			mi.free()       # "cart" e simili: solo un punto che si muove
	n.visible = false
	sk.vp.add_child(n)
	return n


func _build() -> void:
	for n in cut["actors"]:
		acts[n] = _make_actor(str(cut["actors"][n]))
	layer = CanvasLayer.new()
	layer.layer = 90
	gm.add_child(layer)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	layer.add_child(flash)
	loadlab = Label.new()
	loadlab.text = "CARICAMENTO DEL TERRENO..."
	loadlab.add_theme_font_size_override("font_size", 10)
	loadlab.add_theme_color_override("font_color", Color(0.6, 1, 0.8))
	loadlab.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	loadlab.position = Vector2(-70, -60)
	loadlab.visible = false
	layer.add_child(loadlab)
	bar_t = ColorRect.new()
	bar_b = ColorRect.new()
	for b in [bar_t, bar_b]:
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(b)
	bar_t.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_b.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)


# ------------------------------------------------------------------ valutazione
static func _ease(x: float, e := 1) -> float:
	x = clampf(x, 0.0, 1.0)
	match e:
		0:
			return x
		2:
			return x * x
		3:
			return 1.0 - (1.0 - x) * (1.0 - x)
	return x * x * (3.0 - 2.0 * x)


static func v3(a: Variant) -> Vector3:
	if a is Array and (a as Array).size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


## chiave attiva + successiva + peso (con curva) all'istante T
func seg(keys: Array, T: float) -> Array:
	var n := keys.size()
	if n == 0:
		return [null, null, 0.0]
	var i := -1
	for j in n:
		if float(keys[j]["t"]) <= T:
			i = j
	if i < 0:
		return [keys[0], null, 0.0]
	if i == n - 1:
		return [keys[i], null, 0.0]
	var a: Dictionary = keys[i]
	var b: Dictionary = keys[i + 1]
	var w := clampf((T - float(a["t"])) / maxf(float(b["t"]) - float(a["t"]), 0.0001), 0.0, 1.0)
	return [a, b, _ease(w, int(b.get("e", 1)))]


func ref(n: String) -> Dictionary:
	if anchors.has(n):
		return anchors[n]
	if acts.has(n):
		var a: Node3D = acts[n]
		return {"p": a.position, "yaw": a.rotation.y}
	return {"p": Vector3.ZERO, "yaw": 0.0}


## posizione assoluta, yaw e offset di una chiave
func kpos(k: Dictionary) -> Dictionary:
	var r := ref(str(k.get("a", "P0")))
	var o := v3(k.get("o", [0, 0, 0]))
	var yaw: float = r["yaw"]
	return {"p": (r["p"] as Vector3) + Basis(Vector3.UP, yaw) * o, "yaw": yaw, "o": o}


func eval_act(name: String, T: float) -> void:
	var node: Node3D = acts[name]
	var s := seg(cut["act"].get(name, []), T)
	if s[0] == null:
		return
	var a: Dictionary = s[0]
	var pa := kpos(a)
	var p: Vector3 = pa["p"]
	var rot := v3(a.get("r", [0, 0, 0])) + Vector3(0, pa["yaw"], 0)
	var sc := float(a.get("s", 1.0))
	if s[1] != null:
		var b: Dictionary = s[1]
		var pb := kpos(b)
		var w: float = s[2]
		p = p.lerp(pb["p"], w)
		rot = rot.lerp(v3(b.get("r", [0, 0, 0])) + Vector3(0, pb["yaw"], 0), w)
		sc = lerpf(sc, float(b.get("s", 1.0)), w)
	node.position = p
	node.rotation = rot
	node.visible = bool(a.get("v", 1))
	var kind := str(cut["actors"].get(name, name))
	if kind == "shadow":
		node.scale = Vector3(sc, 1.0, sc)
	else:
		node.scale = Vector3.ONE * float(BASE_SC.get(kind, 1.0)) * sc


func eval_cam(T: float) -> Dictionary:
	var s := seg(cut["cam"], T)
	var a: Dictionary = s[0]
	var m := int(a.get("m", 0))
	var pa := kpos(a)
	var p: Vector3 = pa["p"]
	var oy: float = (pa["o"] as Vector3).y
	var rot := v3(a.get("r", [0, 0, 0])) + Vector3(0, pa["yaw"], 0)
	var f := float(a.get("f", 38.6 if m == 0 else 80.0))
	var nc := float(a.get("taglio", 0.0))
	var au := _auto_cam(a)
	if not au.is_empty():
		rot = au["rot"]
		f = au["fov"]
	if s[1] != null and int(s[1].get("m", 0)) == m and not bool(s[1].get("cut", false)):
		var b: Dictionary = s[1]
		var pb := kpos(b)
		var w: float = s[2]
		p = p.lerp(pb["p"], w)
		oy = lerpf(oy, (pb["o"] as Vector3).y, w)
		var rb := v3(b.get("r", [0, 0, 0])) + Vector3(0, pb["yaw"], 0)
		var fb := float(b.get("f", 38.6 if m == 0 else 80.0))
		var bu := _auto_cam(b)
		if not bu.is_empty():
			rb = bu["rot"]
			fb = bu["fov"]
		if au.is_empty() and bu.is_empty():
			rot = rot.lerp(rb, w)
		else:      # verso o da una camera del gioco: si gira per la via piu' corta
			rot = Vector3(lerp_angle(rot.x, rb.x, w), lerp_angle(rot.y, rb.y, w), lerp_angle(rot.z, rb.z, w))
		f = lerpf(f, fb, w)
		nc = lerpf(nc, float(b.get("taglio", 0.0)), w)
	var gz := _gaze(a, p, rot)
	if s[1] != null and int(s[1].get("m", 0)) == m and not bool(s[1].get("cut", false)) and (str(a.get("mira", "")) != "" or str((s[1] as Dictionary).get("mira", "")) != ""):
		# con "guarda verso" si punta ogni volta dal punto in cui la camera e' adesso, cosi' il bersaglio resta inquadrato
		var b2: Dictionary = s[1]
		var w2: float = s[2]
		var ra := _gaze(a, p, v3(a.get("r", [0, 0, 0])) + Vector3(0, pa["yaw"], 0))
		var rb2 := _gaze(b2, p, v3(b2.get("r", [0, 0, 0])) + Vector3(0, kpos(b2)["yaw"], 0))
		rot = Vector3(lerp_angle(ra.x, rb2.x, w2), lerp_angle(ra.y, rb2.y, w2), lerp_angle(ra.z, rb2.z, w2))
	else:
		rot = gz
	return {"m": m, "p": p, "oy": oy, "rot": rot, "f": f, "taglio": nc}


## chiave con "mira" (guarda verso un'ancora o un attore, spostato di "mira_o"): angolo calcolato, resta il rollio della chiave
func _gaze(k: Dictionary, p: Vector3, rot: Vector3) -> Vector3:
	var g := str(k.get("mira", ""))
	if g == "" or not (anchors.has(g) or acts.has(g)):
		return rot
	var q: Vector3 = ref(g)["p"]
	if acts.has(g):
		q.y += sk.elev_at(q.x, q.z)
	q += v3(k.get("mira_o", [0, 0, 0]))
	var d := q - p
	if d.length() < 0.2:
		return rot
	return Vector3(atan2(d.y, Vector2(d.x, d.z).length()), atan2(-d.x, -d.z), v3(k.get("r", [0, 0, 0])).z)


## chiave con "auto" = 1: angolo e zoom sono quelli dell'inquadratura del gioco a cui si riferisce
func _auto_cam(k: Dictionary) -> Dictionary:
	if int(k.get("auto", 0)) != 1:
		return {}
	var an: Dictionary = ref(str(k.get("a", "P0")))
	return an if an.has("rot") else {}


## stato complessivo all'istante T (con_cam false: solo attori, per il ripristino del relitto)
func _eval(T: float, with_cam := true) -> void:
	for n in acts:
		eval_act(n, T)
	_attach(T)
	_fx(T)
	if stage != null:
		var sc := eval_cam(T)
		_apply_cam(sc)
		stage.apply(T, step_dt)
		return
	if with_cam:
		var c := eval_cam(T)
		_apply_cam(c)
		_env(T)
		if fxs != null:
			fxs.apply(T, step_dt)


## i blocchi di terreno attorno alle ancore indicate sono tutti caricati?
func _ready_at(names: Array, r: float) -> bool:
	for n in names:
		var q: Vector3 = anchors[str(n)]["p"]
		var g: Vector2 = Vector2(q.x, q.z) - (sk.world_off as Vector2)
		var rad := int(ceil(r / float(sk.CHS)))
		var pk := Vector2i(floori(g.x / float(sk.CHS)), floori(g.y / float(sk.CHS)))
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var k := pk + Vector2i(dx, dz)
				var ctr := Vector2((k.x + 0.5) * float(sk.CHS), (k.y + 0.5) * float(sk.CHS))
				if ctr.distance_to(g) < r and not sk.chunks.has(k):
					return false
	return true


## valore numerico di un campo di una traccia attore all'istante T
func _track_value(track: String, key: String, T: float, dflt: float) -> float:
	var sg := seg(cut["act"].get(track, []), T)
	if sg[0] == null:
		return dflt
	var v := float((sg[0] as Dictionary).get(key, dflt))
	if sg[1] != null:
		v = lerpf(v, float((sg[1] as Dictionary).get(key, v)), float(sg[2]))
	return v


func _attach(_T: float) -> void:
	if acts.has("beam") and acts.has("ufo"):
		var u: Node3D = acts["ufo"]
		var b: Node3D = acts["beam"]
		var g: float = sk.elev_at(u.position.x, u.position.z)
		var h := maxf(u.position.y - 0.6 - g, 0.5)
		b.position = Vector3(u.position.x, g + h * 0.5, u.position.z)
		var fl := 0.8 + 0.2 * sin(t * 40.0)
		b.scale = Vector3(1.0 + 0.04 * sin(t * 25.0), h, 1.0 + 0.04 * sin(t * 25.0))
		var mi: MeshInstance3D = b.get_child(0)
		(mi.material_override as StandardMaterial3D).albedo_color = Color(0.45, 1.0, 0.7, 0.30 * fl * _track_value("beam", "al", _T, 1.0))


func _fx(T: float) -> void:
	var st := {}
	for ev in cut["ev"]:
		if str(ev.get("k", "")) == "fx" and float(ev["t"]) <= T:
			st[str(ev["a"]) + "/" + str(ev["f"])] = bool(ev.get("on", 1))
	for n in acts:
		for f in ["smoke", "fire"]:
			var e: Node = (acts[n] as Node).get_node_or_null(f)
			if e != null:
				(e as CPUParticles3D).emitting = bool(st.get(n + "/" + f, false)) and (acts[n] as Node3D).visible


func _env(T: float) -> void:
	var s := seg(cut["env"], T)
	if s[0] == null:
		return
	var a: Dictionary = s[0]
	var w := float(a.get("w", 0.0))
	var col := v3(a.get("c", [0.5, 0.5, 0.5]))
	var e := float(a.get("e", sk.env.ambient_light_energy))
	var su := float(a.get("sun", sk.sun.light_energy))
	var fg := float(a.get("fog", sk.env.fog_density))
	if s[1] != null:
		var b: Dictionary = s[1]
		var q: float = s[2]
		w = lerpf(w, float(b.get("w", 0.0)), q)
		col = col.lerp(v3(b.get("c", a.get("c", [0.5, 0.5, 0.5]))), q)
		e = lerpf(e, float(b.get("e", sk.env.ambient_light_energy)), q)
		su = lerpf(su, float(b.get("sun", sk.sun.light_energy)), q)
		fg = lerpf(fg, float(b.get("fog", sk.env.fog_density)), q)
	if w <= 0.001:
		return
	sk.env.ambient_light_color = sk.env.ambient_light_color.lerp(Color(col.x, col.y, col.z), w)
	sk.env.ambient_light_energy = lerpf(sk.env.ambient_light_energy, e, w)
	sk.sun.light_energy = lerpf(sk.sun.light_energy, su, w)
	sk.env.fog_density = lerpf(sk.env.fog_density, fg, w)


func _apply_cam(c: Dictionary) -> void:
	var cm: Camera3D = sk.cam
	var p: Vector3 = c["p"]
	if stage != null:
		var jit := Vector3(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6), randf_range(-1.0, 1.0)) * shk * 0.16
		p.y = maxf(p.y, sk.elev_at(p.x, p.z) + 1.6)
		var rs: Vector3 = c["rot"]
		sk.curve = 0.0
		sk.fade_a = 62.0
		cm.projection = Camera3D.PROJECTION_PERSPECTIVE
		cm.near = 0.15
		cm.far = 220.0
		cm.fov = float(c["f"])
		cm.position = p + jit
		cm.rotation = Vector3(rs.x, rs.y, rs.z + sin(t * 37.0) * 0.012 * shk)
		sk._mp("near_cut", float(c.get("taglio", 0.0)))
		sk._mp("near_cut_y", stage.ground + 2.3)
		return
	if fxs != null:
		sk._mp("near_cut", float(c.get("taglio", 0.0)) if int(c["m"]) == 1 else 0.0)
		sk._mp("near_cut_y", 2.4)
	var jx := randf_range(-1.0, 1.0) * shk * 0.12
	var jz := randf_range(-1.0, 1.0) * shk * 0.12
	if int(c["m"]) == 1:
		sk.curve = 0.0
		cm.fov = float(c["f"])
		cm.near = 0.12
		cm.far = 260.0
		cm.position = p + Vector3(jx, jz * 0.6, jz)
		var r: Vector3 = c["rot"]
		cm.rotation = Vector3(r.x + jx * 0.02, r.y + jz * 0.02, r.z)
		sk.fade_a = 56.0
		cam_xz = Vector2(p.x, p.z)
	else:
		sk.curve = float(saved["curve"])
		cm.fov = 38.6
		cm.near = 2.0
		cm.far = 160.0
		cm.position = Vector3(p.x + jx, float(c["oy"]) + sk.elev_y, p.z + jz)
		cm.rotation = Vector3(-PI * 0.5, 0.0, (c["rot"] as Vector3).z + sin(t * 11.0) * 0.012 * shk)
		sk.cam_h = float(c["oy"])
		sk.fade_a = maxf(sk.fade_a, 30.0)
		cam_xz = Vector2(p.x, p.z)
	gm.player.position = cam_xz * 16.0      # il mondo si genera dove guarda la camera


# ------------------------------------------------------------------ eventi
## musica di sottofondo della cutscene (file in godot/audio, indicato nell'evento "music": f = percorso, v = volume in dB, fade = secondi)
func _music_play(path: String, vol_pct: float, fade: float, from := 0.0) -> void:
	_music_stop(0.2)
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	if st == null and FileAccess.file_exists(path):
		st = AudioStreamMP3.load_from_file(path)
	if st == null:
		print("CINE musica non trovata: ", path)
		return
	mus = AudioStreamPlayer.new()
	mus.stream = st
	mus.volume_db = -60.0
	gm.add_child(mus)
	mus.play(clampf(from, 0.0, maxf(st.get_length() - 0.1, 0.0)))
	var target := linear_to_db(clampf(vol_pct / 100.0, 0.0, 1.0)) if vol_pct > 0.0 else -80.0
	mus.create_tween().tween_property(mus, "volume_db", maxf(target, -80.0), maxf(fade, 0.05))
	print("CINE musica: ", path, " durata ", snappedf(st.get_length(), 0.1), " s, parte da ", snappedf(from, 0.1), " s, volume ", int(vol_pct), "%")


## anteprima da un istante qualsiasi: riparte la musica dal punto giusto del brano
func music_sync(T: float) -> void:
	var best: Dictionary = {}
	for ev in cut.get("mus", []):
		if float(ev["t"]) <= T and (best.is_empty() or float(ev["t"]) > float(best["t"])):
			best = ev
	if not best.is_empty() and str(best.get("k", "")) == "music":
		_music_play(str(best.get("f", "")), float(best.get("vol", 70.0)), 0.2, float(best.get("from", 0.0)) + (T - float(best["t"])))
	else:
		_music_stop(0.2)


## esplosione in aria (particelle 3D): fiamme e fumo scuro
## finestra di dialogo (stile del gioco) con un testo che compare lettera per lettera
func _dialog_show(txt: String, dur: float) -> void:
	if dlg == null:
		dlg = PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.03, 0.1, 0.93)
		sb.border_color = Color(0.75, 0.55, 0.2)
		sb.set_border_width_all(2)
		sb.set_content_margin_all(10)
		dlg.add_theme_stylebox_override("panel", sb)
		dlg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		dlg.grow_horizontal = Control.GROW_DIRECTION_BOTH
		dlg.grow_vertical = Control.GROW_DIRECTION_BEGIN
		dlg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dlg_lab = Label.new()
		dlg_lab.add_theme_font_override("font", Game.font())
		dlg_lab.add_theme_font_size_override("font_size", 24)
		dlg_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dlg.custom_minimum_size = Vector2(220, 0)
		dlg_lab.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
		dlg.add_child(dlg_lab)
		layer.add_child(dlg)
	dlg_lab.text = txt
	dlg_t0 = t
	dlg_until = t + dur


func explosion3d(p: Vector3, n: int, label: String = "CinematicExplosion", size_scale: float = 1.0) -> void:
	var emitters := [
		[Color(1.0, 0.85, 0.4, 1.0), Color(0.6, 0.1, 0.04, 0.0), 1.3, 7.0, 17.0, 0.8, 2.4, true],
		[Color(0.15, 0.13, 0.14, 0.9), Color(0.2, 0.2, 0.22, 0.0), 2.4, 3.0, 9.0, 1.2, 3.2, false],
	]
	for index in emitters.size():
		var cfg: Array = emitters[index]
		var e := _emitter(cfg[0], cfg[1], n, cfg[2], cfg[3] * size_scale, cfg[4] * size_scale, cfg[5] * size_scale, cfg[6] * size_scale, cfg[7], -1.5)
		e.name = "%s_%s" % [label, "Fire" if index == 0 else "Smoke"]
		e.one_shot = true
		e.explosiveness = 1.0
		e.spread = 180.0
		e.position = p
		sk.vp.add_child(e)
		e.emitting = true
		sk.get_tree().create_timer(4.0).timeout.connect(e.queue_free)
func _music_stop(fade: float) -> void:
	if mus == null or not is_instance_valid(mus):
		return
	var m := mus
	mus = null
	var tw := m.create_tween()
	tw.tween_property(m, "volume_db", -60.0, maxf(fade, 0.05))
	tw.tween_callback(m.queue_free)


func _fire(ev: Dictionary) -> void:
	match str(ev.get("k", "")):
		"flash":
			var c := v3(ev.get("c", [1, 1, 1]))
			flash_a = maxf(flash_a, float(ev.get("a", 1.0)))
			flash_col = Color(c.x, c.y, c.z)
		"shake":
			shk = maxf(shk, float(ev.get("v", 1.0)))
		"snd":
			if gm.sfx_node != null:
				gm.sfx_node.play(str(ev.get("n", "hit")), float(ev.get("vol", 0.0)))
		"fulmini", "fulmine_gigante", "anello", "onda", "esplosione", "scintille":
			var lib: W3DUfoShow = stage if stage != null else fxs
			if lib != null:
				lib.event(ev)
		"music":
			_music_play(str(ev.get("f", "")), float(ev.get("vol", 70.0)), float(ev.get("fade", 1.5)), float(ev.get("from", 0.0)))
		"text":
			_dialog_show(str(ev.get("x", "????")), float(ev.get("d", 3.0)))
		"boom":
			var bq: Vector3 = ref(str(ev.get("a", "ufo")))["p"]
			explosion3d(bq, int(ev.get("n", 100)))
		"musicstop":
			_music_stop(float(ev.get("fade", 1.5)))
		"say":
			gm.say(str(ev.get("x", "")))
		"burst":
			var q: Vector3 = ref(str(ev.get("a", "P0")))["p"]
			var c2 := v3(ev.get("c", [1, 0.8, 0.5]))
			gm.burst(Vector2(q.x, q.z) * 16.0, Color(c2.x, c2.y, c2.z), int(ev.get("n", 30)), float(ev.get("sp", 90.0)), 1.0)


func rate() -> float:
	return clampf(float(cut.get("velocita", DEFAULT_RATE)), 0.3, 2.0)


func update(dt: float) -> void:
	if not active:
		return
	var dur := float(cut["dur"])
	if stage != null:
		dt = minf(dt, 0.05)
	dt *= rate()
	step_dt = dt
	shk = lerpf(shk, 0.0, minf(1.0, dt * 3.0))
	flash_a = maxf(0.0, flash_a - dt * (2.1 if stage != null else 1.6))
	gm.shake_v = 0.0
	if playing:
		var nt := t + dt
		# prima di un taglio verso una zona lontana si aspetta che il terreno sia caricato (al massimo 30 s)
		for g in cut.get("wait", []):
			var wt: float = float(g["t"]) if g is Dictionary else float(g)
			if t < wt and nt >= wt and not waited.has(wt):
				var need: Array = g.get("need", ["H"]) if g is Dictionary else ["H"]
				if _ready_at(need, 40.0) or hold > 6.0:
					print("CINE terreno al taglio ", wt, ": ", "pronto" if hold <= 6.0 else "NON completo, si prosegue", " dopo ", snappedf(hold, 0.1), " s")
					waited.append(wt)
					hold = 0.0
					sk.job_boost = false
				else:
					hold += dt
					sk.job_boost = true      # durante l'attesa il gioco dedica piu' tempo a generare il terreno
					nt = wt - 0.001
		t = nt
		if t >= dur:
			if edit:
				t = dur
				playing = false
				_music_stop(1.5)
			else:
				finish()
				return
		var lo := tp if tp > 0.0 else -1.0       # al primo passo scattano anche gli eventi a tempo 0
		for ev in cut["ev"] + cut.get("mus", []):
			if float(ev["t"]) > lo and float(ev["t"]) <= t:
				_fire(ev)
	tp = t
	_eval(t)
	if ed != null:
		ed.update()
	_overlay(dur)


func _overlay(dur: float) -> void:
	var vs: Vector2 = gm.get_viewport().get_visible_rect().size
	var bh := vs.y * 0.115
	var k := minf(_ease(t / 0.8), 1.0 - _ease((t - (dur - 1.4)) / 1.2))
	if stage != null:
		k = minf(_ease(t / float(cut.get("barre", 0.7))), 1.0 - _ease((t - (dur - 1.1)) / 1.0))
	if edit and not preview:
		k = 0.0
	if loadlab != null:
		loadlab.visible = hold > 0.4
	if dlg != null:
		dlg.visible = t >= dlg_t0 and t < dlg_until
		dlg_lab.visible_characters = int((t - dlg_t0) / 0.14) + 1
		dlg.offset_top = -bh - 14.0
		dlg.offset_bottom = -bh - 14.0
	bar_t.offset_bottom = bh * k
	bar_b.offset_top = -bh * k
	var fa := clampf(flash_a, 0.0, 1.0)
	var fc := flash_col
	if stage == null and t < 0.7 and (not edit or preview):       # apertura: dal nero
		fc = Color.BLACK
		fa = maxf(fa, 1.0 - t / 0.7)
	flash.color = Color(fc.r, fc.g, fc.b, fa)


## salta a un istante (editor): niente eventi, solo stato
func seek(T: float) -> void:
	t = clampf(T, 0.0, float(cut["dur"]))
	tp = t
	flash_a = 0.0
	if stage != null:
		stage.reset()
	if fxs != null:
		fxs.reset()
