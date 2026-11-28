class_name W3DEighties
extends Node
## ANNI OTTANTA (prima prova di "il futuro sostituisce il presente").
## Quanto se ne vede dipende da Chrono.eighties() (evocazioni + tempo di gioco). Ogni sostituzione ha una sua soglia fissa,
## cosi' il villaggio cambia a chiazze e cio' che e' cambiato resta (il valore cresce soltanto ed e' salvato).
## Sostituire = l'oggetto originale del villaggio sparisce (con la sua collisione) e al suo posto compare quello moderno:
##   lampioni di legno -> lampioni stradali    pozzo -> distributori di bibite    carri -> auto parcheggiate
##   cartelli -> cabine telefoniche            POCHE case -> insegna al neon verticale, in piedi sopra la porta
## Prova dal menu debug ("PROVA VILLAGGIO ANNI 80") o da riga di comando con --anni80.

const RADIUS := 34.0            # celle attorno al centro del villaggio
const SIGN_RADIUS := 52.0       # le insegne possono stare un po' piu' in la': solo certe case sono adatte
# solo qualche insegna: non ogni casa diventa un negozio
const SIGNS := [
	["SALA GIOCHI", Color(1.0, 0.18, 0.75)], ["BAR LUNA", Color(1.0, 0.75, 0.1)], ["VIDEO", Color(0.15, 0.9, 1.0)],
]
const SIGN_GAP := 14.0          # distanza minima fra due insegne
const SWAP := {"lamp": "lampione", "well": "distributori", "cart": "auto", "sign": "cabina"}
const THRESHOLD := {"lamp": [0.05, 0.75], "well": [0.35, 0.35], "cart": [0.2, 0.6], "sign": [0.15, 0.8]}
const CAR_COLORS := [Color(0.42, 0.05, 0.05), Color(0.05, 0.17, 0.32), Color(0.46, 0.43, 0.35), Color(0.07, 0.22, 0.12)]

const FONT := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [30, 17, 17, 17, 17, 17, 30], "E": [31, 16, 16, 30, 16, 16, 31], "G": [14, 17, 16, 23, 17, 17, 15],
	"H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14], "L": [16, 16, 16, 16, 16, 16, 31],
	"N": [17, 25, 21, 19, 17, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14], "P": [30, 17, 17, 30, 16, 16, 16],
	"R": [30, 17, 17, 30, 20, 18, 17], "S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4],
	"U": [17, 17, 17, 17, 17, 17, 14], "V": [17, 17, 17, 17, 17, 10, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"2": [14, 17, 1, 2, 4, 8, 31], "4": [2, 6, 10, 18, 31, 2, 2], " ": [0, 0, 0, 0, 0, 0, 0],
}

var sk                          # W3DSkin
var slots: Dictionary = {}      # chiave -> {kind, p (coordinate del motore), yaw, chunk, th}
var live: Dictionary = {}       # chiave -> {nodes, cols, lamp, node_id}
var meshes: Dictionary = {}
var lights: Array = []          # [luce, posizione senza curvatura]
var halo_tex: GradientTexture2D
var scan_t := 0.0
var t := 0.0
var neons: Array = []           # [label, luce, alone, fase]
var shown := 0.0


func _process(dt: float) -> void:
	if sk == null:
		return
	t += dt
	var amount := Chrono.eighties()
	if not sk.active or not sk.world_on or str(sk.gm.area) != "world" or amount <= 0.0 or sk.gm.side_scroll_active:
		if not live.is_empty():
			clear()
		return
	_flicker()
	_bend_lights()
	scan_t -= dt
	if scan_t > 0.0 and absf(amount - shown) < 0.001:
		return
	scan_t = 0.5
	shown = amount
	_scan()
	for key in slots:
		var s: Dictionary = slots[key]
		var want: bool = amount >= float(s["th"]) and sk.chunks.has(s["chunk"])
		if want and not live.has(key):
			_place(key, s)
		elif not want and live.has(key):
			_remove(key, true)
		elif want:
			_keep(key, s)


## raccoglie i posti da sostituire: oggetti registrati nei blocchi attorno al villaggio e porte di casa
func _scan() -> void:
	var village := Vector2(sk.gm.SEEDS[0]) - (sk.world_off as Vector2)
	var rng := RandomNumberGenerator.new()
	for ck in sk.chunks:
		for item in sk.chunks[ck].get("reg", []):
			var kind := str(item[0])
			if not SWAP.has(kind):
				continue
			var p: Vector2 = item[1]
			if p.distance_to(village) > RADIUS:
				continue
			var key := "%s:%d,%d" % [kind, roundi(p.x * 100.0), roundi(p.y * 100.0)]
			if slots.has(key):
				continue
			rng.seed = hash(key)
			var th: Array = THRESHOLD[kind]
			slots[key] = {"kind": SWAP[kind], "p": p, "yaw": float(item[2]), "chunk": ck, "th": rng.randf_range(th[0], th[1]), "hide": true, "n": rng.randi()}
	# insegne: sulle porte piu' vicine al centro, ognuna diversa
	var doors: Array = []
	for dk in sk.house_doors:
		var dv: Vector3 = sk.house_doors[dk]
		var dp := Vector2(dv.x, dv.y)
		# una scritta e' giusta per la casa (cima verso il colmo, rivolta a chi arriva alla porta) E dritta sullo schermo
		# solo se la porta guarda verso il basso, cioe' verso la telecamera
		if dp.distance_to(village) <= SIGN_RADIUS and sk.house_roofs.has(dk) and -sin(dv.z) > 0.75:
			doors.append([dp.distance_to(village) + 14.0 * (sk.house_roofs[dk]["busy"] as Array).size(), dk, dv])
	doors.sort_custom(func(a, b): return a[0] < b[0])
	for d in doors:
		var dv2: Vector3 = d[2]
		var key2 := "neon:%d,%d" % [d[1].x, d[1].y]
		if not slots.has(key2):
			var used := {}
			for s in slots.values():
				if s["kind"] == "neon":
					used[s["n"]] = true
			var idx := 0
			while used.has(idx):
				idx += 1
			if idx >= SIGNS.size():
				break
			var crowded := false
			for other in slots.values():
				if other["kind"] == "neon" and (other["p"] as Vector2).distance_to(Vector2(dv2.x, dv2.y)) < SIGN_GAP:
					crowded = true
			if crowded:
				continue
			var p3 := Vector2(dv2.x, dv2.y)
			slots[key2] = {"kind": "neon", "p": p3, "yaw": dv2.z, "chunk": Vector2i(floori(p3.x / float(sk.CHS)), floori(p3.y / float(sk.CHS))), "th": 0.1 + 0.2 * idx, "hide": false, "n": idx, "roof": sk.house_roofs[d[1]]}
	# auto, distributori e cabina ci sono sempre, anche se vicino al villaggio non c'e' niente da sostituire al loro posto
	var present := {}
	for s2 in slots.values():
		present[s2["kind"]] = true
	if not sk.chunks.is_empty():
		for extra in [["auto", 0.2, 0.35, 34.0, 4, 0.3], ["distributori", 0.35, 0.0, 30.0, 5, 2.4], ["cabina", 0.15, 0.0, 22.0, 5, 4.3]]:
			if not present.has(extra[0]) and not slots.has(str(extra[0]) + ":extra"):
				_place_extra(village, extra[0], extra[1], extra[2], extra[3], extra[4], extra[5])


## primo posto libero (non sulla strada, non addosso ad altre novita') cercando in cerchi attorno al villaggio
func _place_extra(village: Vector2, kind: String, th: float, yaw: float, room: float, from_ring: int, angle0: float) -> void:
	for ring in range(from_ring, 20):
		for a in 24:
			var p := village + Vector2.from_angle(TAU * a / 24.0 + angle0) * float(ring)
			var ck := Vector2i(floori(p.x / float(sk.CHS)), floori(p.y / float(sk.CHS)))
			if not sk.chunks.has(ck):
				continue
			var gp: Vector2 = p + (sk.world_off as Vector2)
			var c := Vector2i(floori(gp.x), floori(gp.y))
			if not sk.gm.inb(c) or sk.gm.road[sk.gm.idx(c)] == 1 or not sk.world_free(gp * 16.0, room):
				continue
			var edge: float = _road_at(p)["edge"]
			if ring < 16 and (edge < 1.0 or edge > 3.2):
				continue        # sul bordo della strada, non in mezzo a un prato
			var near := false
			for o in slots.values():
				if (o["p"] as Vector2).distance_to(p) < 3.5:
					near = true
			if near:
				continue
			slots[kind + ":extra"] = {"kind": kind, "p": p, "yaw": yaw, "chunk": ck, "th": th, "hide": false, "n": 0}
			return


## strada piu' vicina a un punto (coordinate del motore): direzione verso la strada, andamento della strada e distanza dal bordo
func _road_at(p: Vector2) -> Dictionary:
	var best := INF
	var q := p + Vector2(0, 1)
	var tg := Vector2(1, 0)
	var half := 1.0
	for i in sk.segs_a.size():
		var a: Vector2 = sk.segs_a[i]
		var ab: Vector2 = (sk.segs_b[i] as Vector2) - a
		if ab.length_squared() < 0.01:
			continue
		var k := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var c := a + ab * k
		var d := p.distance_to(c)
		if d < best:
			best = d
			q = c
			tg = ab.normalized()
			half = float(sk.segs_w[i]) * 0.5
	var toward := (q - p).normalized() if best > 0.15 else tg.orthogonal()
	# andamento preso su un tratto piu' lungo: i singoli segmenti della mappa sono corti e a zig-zag
	var sum := Vector2.ZERO
	for i in sk.segs_a.size():
		var a2: Vector2 = sk.segs_a[i]
		var b2: Vector2 = sk.segs_b[i]
		if ((a2 + b2) * 0.5).distance_to(q) < 3.5:
			var v := b2 - a2
			sum += v if v.dot(tg) >= 0.0 else -v
	if sum.length() > 0.5:
		tg = sum.normalized()
	return {"to": toward, "along": tg, "edge": best - half}


func _hide_key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))


func _place(key: String, s: Dictionary) -> void:
	var p: Vector2 = s["p"]
	if bool(s["hide"]):
		sk.ed_hide_keys[_hide_key(p)] = true
		sk._rebuild_world_chunk(s["chunk"])
	var w: Vector2 = p + (sk.world_off as Vector2)
	var rec := {"nodes": [], "cols": [], "lamp": Vector4.ZERO, "chunk_id": 0}
	var yaw: float = s["yaw"]
	match str(s["kind"]):
		"lampione":
			# il braccio sporge sopra la strada
			var rd := _road_at(p)
			var to: Vector2 = rd["to"]
			_mesh_node(rec, "lampione", w, atan2(-to.y, to.x))
			var head := w + to * 1.75
			_glow(rec, Vector3(head.x, 3.6, head.y), Color(0.7, 0.92, 1.0), 2.6, 1.4, 9.0)
			_collide(rec, w, Vector2(0.3, 0.3))
		"distributori":
			# il fronte guarda la strada
			var rd2 := _road_at(p)
			var to2: Vector2 = rd2["to"]
			var a2 := atan2(to2.x, to2.y)
			_mesh_node(rec, "distributori", w, a2)
			var front := w + to2 * 0.9
			_glow(rec, Vector3(front.x, 1.8, front.y), Color(1.0, 0.35, 0.3), 2.8, 1.5, 7.0)
			_collide(rec, w, _aabb(a2, Vector2(1.35, 0.55)))
		"auto":
			# parcheggiata parallela alla strada
			var along: Vector2 = _road_at(p)["along"]
			var a3 := atan2(along.x, along.y)
			_mesh_node(rec, "auto%d" % (int(s["n"]) % CAR_COLORS.size()), w, a3)
			_collide(rec, w, _aabb(a3, Vector2(1.1, 2.05)))
		"cabina":
			var to4: Vector2 = _road_at(p)["to"]
			_mesh_node(rec, "cabina", w, atan2(to4.x, to4.y))
			_glow(rec, Vector3(w.x, 2.9, w.y), Color(1.0, 0.95, 0.7), 2.2, 1.0, 5.0)
			_collide(rec, w, Vector2(0.55, 0.55))
		"neon":
			_neon(rec, w, yaw, int(s["n"]), s["roof"])
	live[key] = rec


## il blocco puo' essere rigenerato: le luci finte dei lampioni e l'oggetto nascosto vanno ripristinati
func _keep(key: String, s: Dictionary) -> void:
	if bool(s["hide"]):
		var hk := _hide_key(s["p"])
		if not sk.ed_hide_keys.has(hk):
			sk.ed_hide_keys[hk] = true
			sk._rebuild_world_chunk(s["chunk"])
	var rec: Dictionary = live[key]
	var lv: Vector4 = rec["lamp"]
	if lv == Vector4.ZERO or not sk.chunks.has(s["chunk"]):
		return
	var ch: Dictionary = sk.chunks[s["chunk"]]
	var nid: int = (ch["node"] as Node).get_instance_id()
	if int(rec["chunk_id"]) != nid:
		rec["chunk_id"] = nid
		(ch["lamps"] as Array).append(lv)


func _remove(key: String, restore: bool) -> void:
	var rec: Dictionary = live[key]
	for n in rec["nodes"]:
		if is_instance_valid(n):
			n.queue_free()
	for ce in rec["cols"]:
		(sk.gcols.get(ce[0], []) as Array).erase(ce[1])
	neons = neons.filter(func(x): return not (rec["nodes"] as Array).has(x[0]))
	live.erase(key)
	var s: Dictionary = slots.get(key, {})
	if restore and not s.is_empty() and bool(s["hide"]):
		sk.ed_hide_keys.erase(_hide_key(s["p"]))
		if sk.chunks.has(s["chunk"]):
			var ch: Dictionary = sk.chunks[s["chunk"]]
			(ch["lamps"] as Array).erase(rec["lamp"])
			sk._rebuild_world_chunk(s["chunk"])


func clear() -> void:
	for key in live.keys():
		_remove(key, true)
	slots.clear()
	neons.clear()
	lights.clear()
	shown = 0.0


## ingombro (allineato agli assi) di un rettangolo ruotato
func _aabb(a: float, half: Vector2) -> Vector2:
	return Vector2(absf(cos(a)) * half.x + absf(sin(a)) * half.y, absf(sin(a)) * half.x + absf(cos(a)) * half.y)


func _collide(rec: Dictionary, w: Vector2, half: Vector2) -> void:
	var local: Vector2 = w
	var ck := Vector2i(floori(local.x / 8.0), floori(local.y / 8.0))
	if not sk.gcols.has(ck):
		sk.gcols[ck] = []
	var entry := [local, half]
	(sk.gcols[ck] as Array).append(entry)
	(rec["cols"] as Array).append([ck, entry])


func _mesh_node(rec: Dictionary, kind: String, w: Vector2, yaw: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = sk.mat_prop
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	mi.position = Vector3(w.x, 0.0, w.y)
	mi.rotation.y = yaw
	sk.vp.add_child(mi)
	(rec["nodes"] as Array).append(mi)
	return mi


## luce colorata: pozza a terra (shader degli effetti del gioco: segue terreno e curvatura) e luce vera, abbassata
## ogni fotogramma quanto si abbassa il mondo in quel punto
func _glow(rec: Dictionary, at: Vector3, col: Color, pool: float, energy: float, reach: float) -> MeshInstance3D:
	if halo_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.0)])
		halo_tex = GradientTexture2D.new()
		halo_tex.gradient = g
		halo_tex.fill = GradientTexture2D.FILL_RADIAL
		halo_tex.fill_from = Vector2(0.5, 0.5)
		halo_tex.fill_to = Vector2(1.0, 0.5)
	var q := PlaneMesh.new()
	q.size = Vector2(pool * 2.0, pool * 2.0)
	q.subdivide_width = 10
	q.subdivide_depth = 10
	var st := SurfaceTool.new()
	st.create_from(q, 0)
	var arr := st.commit_to_arrays()
	var cols := PackedColorArray()
	cols.resize((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	cols.fill(Color.WHITE)
	arr[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/w3d_glow.gdshader")
	m.set_shader_parameter("tex", halo_tex)
	m.set_shader_parameter("use_tex", true)
	m.set_shader_parameter("tint", Color(col.r, col.g, col.b, 0.2))
	var halo := MeshInstance3D.new()
	halo.mesh = am
	halo.material_override = m
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = Vector3(at.x, 0.17, at.z)
	sk.vp.add_child(halo)
	(rec["nodes"] as Array).append(halo)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = reach
	l.position = at
	sk.vp.add_child(l)
	(rec["nodes"] as Array).append(l)
	lights.append([l, at])
	return halo


## di quanto lo shader del mondo sposta un punto in quota (terreno + curvatura "pianetino")
func world_lift(p: Vector3) -> float:
	var d := Vector2(p.x - (sk.pos as Vector2).x, p.z - (sk.pos as Vector2).y).length()
	return sk.elev_at(p.x, p.z) - float(sk.curve) * d * d


func _bend_lights() -> void:
	for i in range(lights.size() - 1, -1, -1):
		if not is_instance_valid(lights[i][0]):
			lights.remove_at(i)
			continue
		var base: Vector3 = lights[i][1]
		(lights[i][0] as OmniLight3D).position = base + Vector3(0.0, world_lift(base), 0.0)


## negozio anni '80: l'insegna sta IN PIEDI, verticale come il muro e rivolta come la facciata, sul bordo della
## grondaia sopra la porta (sotto il tetto che sporge non si vedrebbe). Sotto c'e' la tenda a strisce.
## E' tutta geometria con lo stesso materiale delle case (lettere comprese), cosi' segue la stessa prospettiva.
func _builder() -> W3DBuilder:
	var b := W3DBuilder.new()
	b.sat = 1.0
	b.con = 1.0
	return b


func _static_mesh(rec: Dictionary, b: W3DBuilder) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = b.mesh()
	mi.material_override = sk.mat_prop
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sk.vp.add_child(mi)
	(rec["nodes"] as Array).append(mi)
	return mi


func _bx(b: W3DBuilder, base: Transform3D, size: Vector3, pos: Vector3, col: Color) -> void:
	b.box(base * Transform3D(Basis.IDENTITY, pos), size, col, 0.0, 8)


## colore che brilla (nel materiale del mondo l'alfa sotto 1 e' luce propria)
func _lit(c: Color, a := 0.05) -> Color:
	return Color(c.r, c.g, c.b, a)


## scritta a pixel sul piano di "base": x = verso di lettura, -z = alto delle lettere, y = fuori dal piano
func _text(b: W3DBuilder, base: Transform3D, text: String, px: float, col: Color) -> void:
	var cols := text.length() * 6 - 1
	for i in text.length():
		var rows: Array = FONT.get(text[i], FONT[" "])
		for r in 7:
			var bits: int = rows[r]
			var c := 0
			while c < 5:
				if bits & (16 >> c) == 0:
					c += 1
					continue
				var run := 1
				while c + run < 5 and bits & (16 >> (c + run)) != 0:
					run += 1
				var x := (i * 6 + c + run * 0.5 - cols * 0.5) * px
				_bx(b, base, Vector3(run * px * 0.98, 0.05, px * 0.98), Vector3(x, 0.0, (r - 3) * px), col)
				c += run


func _neon(rec: Dictionary, door: Vector2, yaw: float, idx: int, roof: Dictionary) -> void:
	var text: String = SIGNS[idx][0]
	var col: Color = SIGNS[idx][1]
	var out := Vector2(cos(yaw), -sin(yaw))
	var t0: Transform3D = roof["t"]
	t0.origin += Vector3((sk.world_off as Vector2).x, 0.0, (sk.world_off as Vector2).y)
	var w: float = roof["w"]
	var d: float = roof["d"]
	var wh: float = roof["wh"]
	var ov: float = roof["ov"]
	var dz: float = roof["dz"]
	var bw := clampf(0.42 * text.length() + 0.6, 2.6, d + 2.0 * ov - 0.2)
	var bh := 1.5
	var room := maxf((d + 2.0 * ov - bw) * 0.5, 0.0)
	# piede dell'insegna: sul bordo della grondaia, sopra la porta
	var foot: Vector3 = t0 * Vector3(w * 0.5 + ov + 0.06, wh - 0.1, clampf(dz, -room, room))
	var face := Vector3(out.x, 0.0, out.y)
	var right := Vector3.UP.cross(face).normalized()
	# piano verticale: x = verso di lettura, y = fuori dalla facciata, -z = in alto
	var plane := Transform3D(Basis(right, face, -Vector3.UP), foot + Vector3(0.0, bh * 0.5 + 0.08, 0.0))
	rec["top"] = Vector3.UP
	rec["out"] = out
	rec["normal"] = face

	var body := _builder()
	_bx(body, plane, Vector3(bw, 0.16, bh), Vector3.ZERO, Color(0.07, 0.06, 0.12))
	_bx(body, plane, Vector3(bw - 0.18, 0.02, bh - 0.18), Vector3(0, 0.085, 0), Color(0.02, 0.015, 0.04))
	for side in [-1.0, 1.0]:       # due staffe che la reggono al tetto
		_bx(body, plane, Vector3(0.1, 0.5, 0.1), Vector3(side * (bw * 0.5 - 0.25), -0.28, bh * 0.35), Color(0.3, 0.31, 0.36))
	var px := minf((bh - 0.42) / 7.0, (bw - 0.4) / (text.length() * 6.0 - 1.0))
	_text(body, plane * Transform3D(Basis.IDENTITY, Vector3(0, 0.11, 0)), text, px, _lit(col.lightened(0.35)))
	# tenda a strisce sopra la porta, attaccata al muro
	var wall := Transform3D(Basis(Vector3.UP, atan2(out.x, out.y)), Vector3(door.x - out.x * 0.7, 0.0, door.y - out.y * 0.7))
	var dim := col.darkened(0.45)
	var aw := 2.2
	for i in 7:
		var x := -aw * 0.5 + aw / 7.0 * (i + 0.5)
		var sc := dim if i % 2 == 0 else Color(0.62, 0.58, 0.5)
		body.box(wall * Transform3D(Basis(Vector3.RIGHT, 0.26), Vector3(x, 2.05, 0.6)), Vector3(aw / 7.0, 0.07, 1.15), sc, 0.0, 8)
		_bx(body, wall, Vector3(aw / 7.0, 0.2, 0.05), Vector3(x, 1.8, 1.16), sc)
	_static_mesh(rec, body)

	# il tubo al neon attorno al cartello (maglia a parte: ogni tanto sfarfalla)
	var tubes := _builder()
	var glow_col := _lit(col, 0.12)
	for zz in [-bh * 0.5 + 0.045, bh * 0.5 - 0.045]:
		_bx(tubes, plane, Vector3(bw, 0.09, 0.09), Vector3(0, 0.11, zz), glow_col)
	for xx in [-bw * 0.5 + 0.045, bw * 0.5 - 0.045]:
		_bx(tubes, plane, Vector3(0.09, 0.09, bh - 0.18), Vector3(xx, 0.11, 0), glow_col)
	var tube_mi := _static_mesh(rec, tubes)
	var halo := _glow(rec, Vector3(door.x + out.x * 1.3, 2.0, door.y + out.y * 1.3), col, 2.6, 1.5, 7.0)
	var light: OmniLight3D = (rec["nodes"] as Array).back()
	neons.append([tube_mi, light, halo, float(idx) * 2.7, col])


## i neon ronzano: ogni tanto uno sfarfalla
func _flicker() -> void:
	for n in neons:
		if not is_instance_valid(n[0]):
			continue
		var ph: float = n[3]
		var off := sin(t * 0.9 + ph) > 0.93 and sin(t * 31.0 + ph * 3.0) > 0.0
		(n[0] as MeshInstance3D).visible = not off
		(n[1] as OmniLight3D).light_energy = 0.4 if off else 1.5 * (1.0 + 0.05 * sin(t * 37.0 + ph))
		var col: Color = n[4]
		((n[2] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("tint", Color(col.r, col.g, col.b, 0.05 if off else 0.2))


func _mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind):
		return meshes[kind]
	var b := W3DBuilder.new()
	b.sat = 1.3
	b.con = 1.2
	var steel := Color(0.42, 0.45, 0.5)
	var dark := Color(0.1, 0.1, 0.13)
	var glass := Color(0.16, 0.3, 0.42)
	var up := Basis.IDENTITY
	if kind.begins_with("auto"):
		var paint: Color = CAR_COLORS[int(kind.substr(4))]
		var hi := paint.lightened(0.16)
		var lo := paint.darkened(0.35)
		var tyre := Color(0.035, 0.035, 0.045)
		var rubber := Color(0.08, 0.08, 0.1)
		# ruote che sporgono dai fianchi, con cerchioni chiari e parafanghi
		for sx in [-1.0, 1.0]:
			for sz in [-1.28, 1.28]:
				b.cyl(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 1.04 - 0.17, 0.43, sz)), 0.43, 0.43, 0.34, 12, tyre, 0.03)
				b.cyl(Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(sx * 1.2 - 0.04, 0.43, sz)), 0.2, 0.2, 0.08, 10, steel, 0.03)
				b.box(Transform3D(up, Vector3(sx * 0.93, 0.9, sz)), Vector3(0.24, 0.14, 1.06), lo, 0.02, 8)
			b.box(Transform3D(up, Vector3(sx * 0.9, 0.55, 0)), Vector3(0.1, 0.16, 1.5), rubber, 0.02, 8)           # minigonna
			b.box(Transform3D(up, Vector3(sx * 1.05, 1.17, 0.62)), Vector3(0.26, 0.14, 0.16), rubber, 0.02, 8)     # specchietto
		b.box(Transform3D(up, Vector3(0, 0.62, 0)), Vector3(1.78, 0.46, 3.75), paint, 0.02, 8)
		b.box(Transform3D(Basis(Vector3.RIGHT, 0.09), Vector3(0, 0.9, 1.36)), Vector3(1.62, 0.14, 1.12), paint, 0.02, 8)   # cofano in discesa
		b.box(Transform3D(up, Vector3(0, 0.99, 1.35)), Vector3(0.5, 0.07, 0.95), hi, 0.02, 8)                       # nervatura del cofano
		b.box(Transform3D(up, Vector3(0, 0.99, -1.55)), Vector3(1.62, 0.2, 0.7), paint, 0.02, 8)
		b.box(Transform3D(up, Vector3(0, 1.2, -1.86)), Vector3(1.8, 0.07, 0.24), lo, 0.02, 8)                       # alettone
		b.box(Transform3D(Basis(Vector3.RIGHT, 0.62), Vector3(0, 1.22, 0.52)), Vector3(1.48, 0.1, 0.76), glass.lightened(0.18), 0.02, 8)    # parabrezza
		b.box(Transform3D(Basis(Vector3.RIGHT, -0.66), Vector3(0, 1.22, -1.05)), Vector3(1.46, 0.1, 0.66), glass, 0.02, 8)                  # lunotto
		b.box(Transform3D(up, Vector3(0, 1.2, -0.27)), Vector3(1.5, 0.44, 1.05), glass.darkened(0.3), 0.02, 8)     # finestrini
		b.box(Transform3D(up, Vector3(0, 1.48, -0.27)), Vector3(1.34, 0.12, 0.92), paint, 0.02, 8)                  # tetto, piu' stretto
		for rz in [-0.55, -0.27, 0.01]:
			b.box(Transform3D(up, Vector3(0, 1.56, rz)), Vector3(1.0, 0.04, 0.08), rubber, 0.0, 8)
		b.box(Transform3D(up, Vector3(0, 0.5, 1.97)), Vector3(1.9, 0.24, 0.22), rubber, 0.02, 8)
		b.box(Transform3D(up, Vector3(0, 0.5, -1.97)), Vector3(1.9, 0.24, 0.22), rubber, 0.02, 8)
		b.box(Transform3D(up, Vector3(0, 0.76, 1.89)), Vector3(0.62, 0.18, 0.05), rubber, 0.0, 8)                   # calandra
		for sx2 in [-0.6, 0.6]:
			b.box(Transform3D(up, Vector3(sx2, 0.78, 1.9)), Vector3(0.4, 0.2, 0.08), Color(1.0, 0.95, 0.75, 0.1), 0.0, 8)
			b.box(Transform3D(up, Vector3(sx2, 0.8, -1.9)), Vector3(0.52, 0.2, 0.08), Color(1.0, 0.12, 0.08, 0.3), 0.0, 8)
		b.box(Transform3D(up, Vector3(-0.55, 1.75, -1.3)), Vector3(0.04, 0.9, 0.04), steel, 0.0, 8)
	else:
		match kind:
			"lampione":
				b.cyl(Transform3D(up, Vector3.ZERO), 0.34, 0.28, 0.4, 8, dark, 0.04)
				b.cyl(Transform3D(up, Vector3(0, 0.35, 0)), 0.16, 0.12, 3.7, 8, steel, 0.03)
				b.box(Transform3D(up, Vector3(0.85, 4.05, 0)), Vector3(1.8, 0.2, 0.2), steel, 0.03, 8)
				b.box(Transform3D(Basis(Vector3.FORWARD, -0.75), Vector3(0.28, 3.72, 0)), Vector3(0.7, 0.09, 0.09), steel, 0.03, 8)
				b.box(Transform3D(up, Vector3(1.75, 4.05, 0)), Vector3(0.95, 0.3, 0.6), dark, 0.03, 8)
				b.box(Transform3D(up, Vector3(1.75, 4.24, 0)), Vector3(0.66, 0.1, 0.4), steel, 0.03, 8)
				b.box(Transform3D(up, Vector3(1.75, 3.87, 0)), Vector3(0.78, 0.1, 0.48), Color(0.8, 0.95, 1.0, 0.05), 0.0, 8)
				b.box(Transform3D(up, Vector3(0.0, 2.2, 0.17)), Vector3(0.62, 0.8, 0.05), Color(0.82, 0.75, 0.5), 0.05, 8)
				b.box(Transform3D(up, Vector3(0.0, 2.35, 0.21)), Vector3(0.46, 0.2, 0.02), Color(0.7, 0.1, 0.35), 0.0, 8)
			"distributori":
				for i in 2:
					var x := -0.68 + 1.36 * i
					var body := Color(0.7, 0.06, 0.07) if i == 0 else Color(0.08, 0.3, 0.62)
					b.box(Transform3D(up, Vector3(x, 1.15, 0)), Vector3(1.18, 2.3, 0.85), body, 0.03, 8)
					b.box(Transform3D(up, Vector3(x, 2.34, 0)), Vector3(1.24, 0.12, 0.92), dark, 0.03, 8)
					b.box(Transform3D(up, Vector3(x, 2.42, 0.05)), Vector3(0.95, 0.05, 0.6), Color(0.95, 0.95, 1.0, 0.3), 0.0, 8)   # pannello luminoso sul tetto
					b.box(Transform3D(up, Vector3(x - 0.16, 1.45, 0.45)), Vector3(0.68, 1.15, 0.05), Color(0.7, 0.92, 1.0, 0.35), 0.0, 8)
					b.box(Transform3D(up, Vector3(x + 0.38, 1.3, 0.45)), Vector3(0.2, 0.7, 0.05), steel, 0.03, 8)
					b.box(Transform3D(up, Vector3(x - 0.16, 0.45, 0.45)), Vector3(0.6, 0.2, 0.06), dark, 0.0, 8)
				b.box(Transform3D(up, Vector3(0.0, 0.1, 0.75)), Vector3(2.8, 0.2, 0.55), Color(0.22, 0.22, 0.24), 0.08, 8)
			"cabina":
				var red := Color(0.66, 0.07, 0.06)
				for sx in [-0.46, 0.46]:
					for sz in [-0.46, 0.46]:
						b.box(Transform3D(up, Vector3(sx, 1.25, sz)), Vector3(0.13, 2.5, 0.13), red, 0.03, 8)
				b.box(Transform3D(up, Vector3(0, 2.58, 0)), Vector3(1.16, 0.22, 1.16), red, 0.03, 8)
				b.box(Transform3D(up, Vector3(0, 2.72, 0)), Vector3(0.82, 0.08, 0.82), Color(1.0, 0.95, 0.75, 0.2), 0.0, 8)
				b.box(Transform3D(up, Vector3(0, 1.25, -0.46)), Vector3(0.8, 2.2, 0.04), glass, 0.04, 8)
				b.box(Transform3D(up, Vector3(0.1, 1.35, -0.34)), Vector3(0.34, 0.5, 0.16), dark, 0.03, 8)
	meshes[kind] = b.mesh()
	return meshes[kind]
