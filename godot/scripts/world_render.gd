class_name WorldRender
extends Node2D
## Disegna il mondo esterno: terreno con shader (chunk) + alberi come sprite grandi sopra le entita'.

const CH := 32  # lato chunk in tile

var mat: ShaderMaterial
var trees: Array = []


class TreeChunk:
	extends Node2D
	var items: Array = []   # [texture, posizione, flip]

	func _draw() -> void:
		for it in items:
			var t: Texture2D = it[0]
			var p: Vector2 = it[1]
			var mode: int = it[2]
			var col: Color = it[3] if it.size() > 3 else Color.WHITE
			if mode == 0:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_texture(t, p - Vector2(t.get_width() / 2.0, t.get_height() / 2.0), col)
			elif mode == 1:
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				draw_texture(t, p - Vector2(t.get_width() / 2.0, t.get_height()), col)
			else:
				draw_set_transform(Vector2(p.x, p.y), 0.0, Vector2(-1, 1))
				draw_texture(t, Vector2(-t.get_width() / 2.0, -t.get_height()), col)


var outside_mask := PackedByteArray()


func build(grid: PackedByteArray, biome: PackedByteArray, road: PackedByteArray, cobble: PackedByteArray, water: PackedByteArray, bridge: PackedByteArray, w: int, h: int, theme := PackedByteArray(), carpet := PackedByteArray(), force_biome := -1) -> void:
	# texture dati: R bioma, G flag (bit0 blocco, bit1 strada)
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	for y in h:
		for x in w:
			var i := y * w + x
			var f := 0
			if grid[i] == 0:
				f |= 1
			if road[i] == 1:
				f |= 2
			if cobble[i] == 1:
				f |= 4
			if water[i] == 1:
				f |= 8
			if bridge[i] == 1:
				f |= 16
			if carpet.size() > 0 and carpet[i] == 1:
				f |= 32
			if outside_mask.size() > 0 and outside_mask[i] == 1:
				f |= 64
			img.set_pixel(x, y, Color8(biome[i], f, theme[i] if theme.size() > 0 else 0))
	var tex := ImageTexture.create_from_image(img)
	var sh: Shader = load("res://shaders/ground.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("data", tex)
	mat.set_shader_parameter("map_size", Vector2(w, h))
	mat.set_shader_parameter("force_biome", force_biome)
	Game.photo_ground(mat)
	var px := CH * Game.TS
	for cy in range(0, ceili(h / float(CH))):
		for cx in range(0, ceili(w / float(CH))):
			var r := ColorRect.new()
			r.position = Vector2(cx * px, cy * px)
			r.size = Vector2(px, px)
			r.material = mat
			r.z_index = -10
			add_child(r)
	if force_biome >= 0:
		return
	# alberi: cimitero (1) e foresta (2)
	var chunks := {}
	var sets := {
		"forest": [], "gloom": [], "sick": [], "dead": [],
	}
	for i in 10:
		sets["forest"].append(Game.tex("top_forest_%d" % i))
		sets["gloom"].append(Game.tex("top_gloom_%d" % i))
		sets["sick"].append(Game.tex("top_sick_%d" % i))
		sets["dead"].append(Game.tex("top_dead_%d" % i))
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var i := y * w + x
			var b := biome[i]
			if grid[i] != 0 or (b != 1 and b != 2) or water[i] == 1:
				continue
			var inner := true
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if grid[(y + d.y) * w + x + d.x] == 1:
					inner = false
			if inner and rng.randf() < 0.45:
				continue
			if b == 1 and rng.randf() < 0.30:
				continue
			var kind: String
			if b == 1:
				kind = "dead" if rng.randf() < 0.7 else "sick"
			else:
				var q := rng.randf()
				kind = "forest" if q < 0.5 else ("gloom" if q < 0.75 else ("sick" if q < 0.9 else "dead"))
			var arr: Array = sets[kind]
			var t: Texture2D = arr[rng.randi() % arr.size()]
			var tcol := Game.tint(x, y, 0.1)
			var pos := Vector2(x * Game.TS + 8 + rng.randf_range(-5, 5) - t.get_width() / 2.0, y * Game.TS + 8 + rng.randf_range(-5, 5) - t.get_height() / 2.0)
			var key := Vector2i(x / CH, y / CH)
			if not chunks.has(key):
				var tc := TreeChunk.new()
				tc.z_index = -4
				add_child(tc)
				chunks[key] = tc
			(chunks[key] as TreeChunk).items.append([t, pos + Vector2(t.get_width() / 2.0, t.get_height() / 2.0), 0, tcol])
	for k in chunks:
		var tc: TreeChunk = chunks[k]
		tc.items.sort_custom(func(a, b): return a[1].y < b[1].y)
		tc.queue_redraw()


func add_clutter(grid: PackedByteArray, biome: PackedByteArray, road: PackedByteArray, w: int, h: int, sd: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var noises := {}
	var chunks := {}
	var cache := {}
	for y in range(3, h - 3):
		for x in range(3, w - 3):
			var i := y * w + x
			if grid[i] != 1:
				continue
			var b := biome[i]
			var rules: Array = Scenery.CLUTTER[b]
			var near_block := false
			for d in [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if grid[(y + d.y) * w + x + d.x] == 0:
					near_block = true
					break
			for ri in rules.size():
				var r: Dictionary = rules[ri]
				if r.get("edge", false) and not near_block:
					continue
				if road[i] == 1:
					continue
				var dens: float = r["d"]
				if r.has("cf"):
					var nk := b * 16 + ri
					if not noises.has(nk):
						var nz := FastNoiseLite.new()
						nz.seed = sd + nk * 31
						nz.frequency = r["cf"]
						noises[nk] = nz
					var n := (((noises[nk] as FastNoiseLite).get_noise_2d(x, y)) + 1.0) * 0.5
					dens *= smoothstep(r["ct"], r["ct"] + 0.15, n) * 1.8
				if rng.randf() >= dens:
					continue
				var names: Array = r["n"]
				var nm: String = names[rng.randi() % names.size()]
				if not cache.has(nm):
					cache[nm] = Game.tex(nm)
				var pos := Vector2(x * Game.TS + rng.randf_range(2, 14), y * Game.TS + rng.randf_range(6, 15))
				var key := Vector2i(x / CH, y / CH)
				if not chunks.has(key):
					var tc := TreeChunk.new()
					tc.z_index = -6
					add_child(tc)
					chunks[key] = tc
				(chunks[key] as TreeChunk).items.append([cache[nm], pos, 2 if rng.randf() < 0.5 else 1, Game.tint(x, y, 0.14)])
	for k in chunks:
		var tc: TreeChunk = chunks[k]
		tc.items.sort_custom(func(a, b): return a[1].y < b[1].y)
		tc.queue_redraw()


# ---------------------------------------------------------------- mondo a blocchi
var m                      # riferimento al main (legge gli array del mondo)
var s_img: Image
var s_tex: ImageTexture
var s_trees: Dictionary = {}
var s_cache: Dictionary = {}
var s_cum: Array = []
var s_tchunk: Dictionary = {}


func init_stream(main_node, w: int, h: int) -> void:
	m = main_node
	s_img = Image.create(w, h, false, Image.FORMAT_RGB8)
	s_img.fill(Color8(0, 0, 0))
	s_tex = ImageTexture.create_from_image(s_img)
	var sh: Shader = load("res://shaders/ground.gdshader")
	mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("data", s_tex)
	mat.set_shader_parameter("map_size", Vector2(w, h))
	mat.set_shader_parameter("force_biome", -1)
	Game.photo_ground(mat)
	s_trees = {
		"forest": [], "gloom": [], "sick": [], "dead": [],
	}
	for i in 10:
		s_trees["forest"].append(Game.tex("top_forest_%d" % i))
		s_trees["gloom"].append(Game.tex("top_gloom_%d" % i))
		s_trees["sick"].append(Game.tex("top_sick_%d" % i))
		s_trees["dead"].append(Game.tex("top_dead_%d" % i))
	# densita' cumulative per bioma: una sola estrazione per cella
	s_cum = []
	for b in Scenery.CLUTTER.size():
		var acc := 0.0
		var cum := PackedFloat32Array()
		for r in Scenery.CLUTTER[b]:
			acc += float(r["d"]) * 1.8
			cum.append(acc)
		s_cum.append([acc, cum])


func refresh_cells(r: Rect2i) -> void:
	var w: int = Game.MW
	for y in range(maxi(0, r.position.y), mini(Game.MH, r.end.y)):
		for x in range(maxi(0, r.position.x), mini(w, r.end.x)):
			_px(x, y)
	s_tex.update(s_img)


func _px(x: int, y: int) -> void:
	var w: int = Game.MW
	var i := y * w + x
	var f := 0
	if m.grid[i] == 0:
		f |= 1
	if m.road[i] == 1:
		f |= 2
	if m.cobble[i] == 1:
		f |= 4
	if m.water[i] == 1:
		f |= 8
	if m.bridge[i] == 1:
		f |= 16
	if m.outside[i] == 1:
		f |= 64
	s_img.set_pixel(x, y, Color8(m.biome[i], f, 0))


## disegna un blocco: dati del terreno, rettangolo con lo shader, alberi e vegetazione
func add_chunk(cx: int, cy: int, upd := true) -> void:
	var w: int = Game.MW
	var h: int = Game.MH
	var x0 := cx * CH
	var y0 := cy * CH
	var x1 := mini(x0 + CH, w)
	var y1 := mini(y0 + CH, h)
	var g0: PackedByteArray = m.grid
	var b0: PackedByteArray = m.biome
	var r0: PackedByteArray = m.road
	var c0: PackedByteArray = m.cobble
	var w0: PackedByteArray = m.water
	var br0: PackedByteArray = m.bridge
	var o0: PackedByteArray = m.outside
	for y in range(y0, y1):
		for x in range(x0, x1):
			var i0 := y * w + x
			var f := 0
			if g0[i0] == 0:
				f |= 1
			if r0[i0] == 1:
				f |= 2
			if c0[i0] == 1:
				f |= 4
			if w0[i0] == 1:
				f |= 8
			if br0[i0] == 1:
				f |= 16
			if o0[i0] == 1:
				f |= 64
			s_img.set_pixel(x, y, Color8(b0[i0], f, 0))
	var tP := Time.get_ticks_usec()
	if upd:
		s_tex.update(s_img)
	var px := CH * Game.TS
	var rc := ColorRect.new()
	rc.position = Vector2(cx * px, cy * px)
	rc.size = Vector2(px, px)
	rc.material = mat
	rc.z_index = -10
	add_child(rc)
	var rng := RandomNumberGenerator.new()
	rng.seed = m.world_seed * 31 + cx * 7919 + cy * 104729
	var grid: PackedByteArray = m.grid
	var biome: PackedByteArray = m.biome
	var water: PackedByteArray = m.water
	var road: PackedByteArray = m.road
	var tchunk: TreeChunk = null
	var cchunk: TreeChunk = null
	for y in range(maxi(y0, 3), mini(y1, h - 3)):
		for x in range(maxi(x0, 3), mini(x1, w - 3)):
			var i := y * w + x
			var b := biome[i]
			# alberi (cimitero e foresta): sulle celle bloccate
			if grid[i] == 0 and (b == 1 or b == 2) and water[i] == 0:
				var inner := grid[i + 1] != 1 and grid[i - 1] != 1 and grid[i + w] != 1 and grid[i - w] != 1
				if not ((inner and rng.randf() < 0.45) or (b == 1 and rng.randf() < 0.30)):
					var kind: String
					if b == 1:
						kind = "dead" if rng.randf() < 0.7 else "sick"
					else:
						var q := rng.randf()
						kind = "forest" if q < 0.5 else ("gloom" if q < 0.75 else ("sick" if q < 0.9 else "dead"))
					var arr: Array = s_trees[kind]
					var t: Texture2D = arr[rng.randi() % arr.size()]
					var tcol := Game.tint(x, y, 0.1) * Game.tone(b)
					var pos := Vector2(x * Game.TS + 8 + rng.randf_range(-5, 5), y * Game.TS + 8 + rng.randf_range(-5, 5))
					if tchunk == null:
						tchunk = TreeChunk.new()
						tchunk.z_index = -4
						add_child(tchunk)
						s_tchunk[Vector2i(cx, cy)] = tchunk
					tchunk.items.append([t, pos, 0, tcol])
			# vegetazione (erba, pietre, funghi...)
			if grid[i] != 1 or road[i] == 1:
				continue
			var rules: Array = Scenery.CLUTTER[b]
			var cinfo: Array = s_cum[b]
			var roll := rng.randf()
			if roll >= float(cinfo[0]):
				continue
			var ccum: PackedFloat32Array = cinfo[1]
			var ri := 0
			while ri < ccum.size() - 1 and roll >= ccum[ri]:
				ri += 1
			var roll_in := roll - (ccum[ri - 1] if ri > 0 else 0.0)
			var nb_state := -1
			for _once in 1:
				var r: Dictionary = rules[ri]
				if r.get("edge", false):
					if nb_state < 0:
						nb_state = 1 if (grid[i + 1] == 0 or grid[i - 1] == 0 or grid[i + w] == 0 or grid[i - w] == 0 or grid[i + 2] == 0 or grid[i - 2] == 0 or grid[i + 2 * w] == 0 or grid[i - 2 * w] == 0) else 0
					if nb_state == 0:
						continue
				var dens: float = r["d"]
				if roll_in >= dens * 1.8:
					continue
				if r.has("cf"):
					var nk := b * 16 + ri
					if not s_cache.has(nk):
						var nz := FastNoiseLite.new()
						nz.seed = m.world_seed + nk * 31
						nz.frequency = r["cf"]
						s_cache[nk] = nz
					var nv := (((s_cache[nk] as FastNoiseLite).get_noise_2d(x, y)) + 1.0) * 0.5
					dens *= smoothstep(r["ct"], r["ct"] + 0.15, nv) * 1.8
				if roll_in >= dens:
					continue
				var names: Array = r["n"]
				var nm: String = names[rng.randi() % names.size()]
				var ck := "tex:" + nm
				if not s_cache.has(ck):
					s_cache[ck] = Game.tex(nm)
				var cpos := Vector2(x * Game.TS + rng.randf_range(2, 14), y * Game.TS + rng.randf_range(6, 15))
				if cchunk == null:
					cchunk = TreeChunk.new()
					cchunk.z_index = -6
					add_child(cchunk)
				cchunk.items.append([s_cache[ck], cpos, 2 if rng.randf() < 0.5 else 1, Game.tint(x, y, 0.14) * Game.tone(b)])
	m.fin_prof[3] += Time.get_ticks_usec() - tP
	for tc in [tchunk, cchunk]:
		if tc != null:
			tc.items.sort_custom(func(a, b): return a[1].y < b[1].y)
			tc.queue_redraw()
	m.apply_cuts(cx, cy)


## una cella di terreno bloccata e' stata abbattuta/scavata: aggiorna il terreno e toglie l'albero disegnato
func cut_cell(x: int, y: int) -> void:
	for yy in range(y - 1, y + 2):
		for xx in range(x - 1, x + 2):
			if xx >= 0 and yy >= 0 and xx < Game.MW and yy < Game.MH:
				_px(xx, yy)
	s_tex.update(s_img)
	var tc: TreeChunk = s_tchunk.get(Vector2i(x / CH, y / CH))
	if tc == null:
		return
	var r := Rect2(x * Game.TS, y * Game.TS, Game.TS, Game.TS)
	for i in range(tc.items.size() - 1, -1, -1):
		if r.has_point(tc.items[i][1]):
			tc.items.remove_at(i)
	tc.queue_redraw()


func set_boost(c: Color) -> void:
	if mat != null:
		mat.set_shader_parameter("boost", Vector3(0.55 / max(c.r, 0.12), 0.55 / max(c.g, 0.12), 0.55 / max(c.b, 0.12)))
