extends RefCounted
## Rete secondaria deterministico: collega i luoghi senza spostare i POI ne' creare ponti.

const MAX_CANDIDATES := 48
const DETOUR_CANDIDATES := 12
const BUCKET := 64
const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


static func generate(m) -> void:
	var started := Time.get_ticks_msec()
	m.road_links.clear()
	m.road_keep.clear()
	_special_access(m)
	var targets := _targets(m)
	# Un solo lookup per cella: luoghi protetti, acqua, ponti e costa esterna.
	var protected := _protection(m, targets)
	var prepared := Time.get_ticks_msec()
	# Celle gia' stradali: maschera per la ricerca costiera, bucket per i candidati vicini.
	var known := PackedByteArray()
	known.resize(Game.MW * Game.MH)
	known.fill(0)
	var known_count := 0
	var buckets := {}
	var road_index: int = m.road.find(1)
	while road_index >= 0:
		_add_known(Vector2i(road_index % Game.MW, road_index / Game.MW), known, buckets)
		known_count += 1
		road_index = m.road.find(1, road_index + 1)
	var existing_count := 0
	var new_count := 0
	var failed_count := 0
	var total_length := 0
	for target in targets:
		var c: Vector2i = target["cell"]
		var radius := int(target["r"])
		var candidates := _nearby_candidates(c, buckets)
		if not candidates.is_empty() and Vector2(candidates[0]).distance_squared_to(Vector2(c)) <= float(radius + 3) * float(radius + 3):
			var access: Vector2i = candidates[0]
			m.road_links[target["id"]] = _link_data(target, "existing", access, access, [])
			existing_count += 1
			continue
		var best: Array = []
		var best_anchor := Vector2i(-1, -1)
		for i in mini(MAX_CANDIDATES, candidates.size()):
			var anchor: Vector2i = candidates[i]
			if m.water[m.idx(anchor)] == 1 or m.bridge[m.idx(anchor)] == 1:
				continue
			var route := _direct_route(m, _access_cell(c, anchor, radius), anchor, protected)
			if not route.is_empty():
				best = route
				best_anchor = anchor
				break
		if best.is_empty():
			for i in mini(DETOUR_CANDIDATES, candidates.size()):
				var anchor: Vector2i = candidates[i]
				if m.water[m.idx(anchor)] == 1 or m.bridge[m.idx(anchor)] == 1:
					continue
				var route := _detour_route(m, _access_cell(c, anchor, radius), anchor, protected)
				if not route.is_empty():
					best = route
					best_anchor = anchor
					break
		if best.is_empty():
			best = _coastal_route(m, c, radius, known, protected)
			if not best.is_empty():
				best_anchor = best[best.size() - 1]
		if best.is_empty():
			m.road_links[target["id"]] = _link_data(target, "failed", Vector2i(-1, -1), Vector2i(-1, -1), [])
			failed_count += 1
			continue
		_carve(m, best, str(target["kind"]) != "poi", protected)
		m.road_paths[target["id"]] = best.duplicate()
		for cell in best:
			m.road_keep[cell] = true
			var index: int = cell.y * Game.MW + cell.x
			if known[index] == 0:
				_add_known(cell, known, buckets)
				known_count += 1
		m.road_links[target["id"]] = _link_data(target, "new", best[0], best_anchor, best)
		new_count += 1
		total_length += best.size() - 1
	if m.testing:
		print("ROADS collegamenti esistenti=", existing_count, " nuovi=", new_count, " falliti=", failed_count,
			" celle nuove=", total_length, " agganci=", known_count, " preparazione ms=", prepared - started,
			" percorsi ms=", Time.get_ticks_msec() - prepared)


## true se l'ingombro di un oggetto coprirebbe l'asse di un sentiero secondario.
static func blocks_path(m, c: Vector2i, footprint: Vector2i) -> bool:
	if m.road_keep.is_empty():
		return false
	for dy in footprint.y:
		for dx in footprint.x:
			if m.road_keep.has(c + Vector2i(dx, dy)):
				return true
	return false


static func _add_known(c: Vector2i, known: PackedByteArray, buckets: Dictionary) -> void:
	known[c.y * Game.MW + c.x] = 1
	var key := Vector2i(c.x / BUCKET, c.y / BUCKET)
	if not buckets.has(key):
		buckets[key] = []
	(buckets[key] as Array).append(c)


static func _special_access(m) -> void:
	# Il cimitero ha gia' un'apertura sud: la strada deve arrivare fino ad essa.
	if m.SEEDS.size() < 2:
		return
	var empty := PackedByteArray()
	empty.resize(Game.MW * Game.MH)
	empty.fill(0)
	var start: Vector2i = m.SEEDS[1] + Vector2i(0, 10)
	# Il centro e' occupato dalla cappella: il sentiero finisce davanti alla sua porta.
	var door: Vector2i = m.SEEDS[1] + Vector2i(0, 3)
	var path := _direct_route(m, start, door, empty)
	if not path.is_empty():
		_carve(m, path, false, empty)
		m.road_paths["access:cemetery"] = path


static func _targets(m) -> Array:
	var out: Array = []
	for si in m.SEEDS.size():
		var radius := 28 if si == 0 else (24 if si == 6 else 16)
		out.append({"id": "biome:%d" % si, "kind": "biome", "cell": m.SEEDS[si], "r": radius})
	for id in m.ENTR:
		out.append({"id": "entrance:%s" % id, "kind": "entrance", "cell": m.ENTR[id], "r": 5})
	for arena in m.ARENAS:
		out.append({"id": "arena:%s" % arena["id"], "kind": "arena", "cell": m.SEEDS[int(arena["si"])] + arena["off"], "r": int(arena["r"]) + 3})
	for po in m.pois:
		var tpl: Dictionary = PoiData.by_id(str(po.get("tpl", "")))
		out.append({"id": "poi:%d" % int(po["id"]), "kind": "poi", "cell": po["cell"], "r": int(tpl.get("r", 15))})
	return out


static func _protection(m, targets: Array) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(Game.MW * Game.MH)
	mask.fill(0)
	for target in targets:
		mask = _protect_disc(m, mask, target["cell"], int(target["r"]) + 1)
	# La cattedrale viene piazzata dopo le strade: un sentiero nel suo ingombro la farebbe sparire.
	var cathedral: Rect2i = m.cathedral_rect().grow(1)
	for y in range(cathedral.position.y, cathedral.end.y):
		for x in range(cathedral.position.x, cathedral.end.x):
			if m.inb(Vector2i(x, y)):
				mask[y * Game.MW + x] = 1
	for gate in m.gate_cell.values():
		mask = _protect_disc(m, mask, gate, 7)
	for passage in m.PASSAGES:
		mask = _protect_disc(m, mask, passage["a"], 6)
		mask = _protect_disc(m, mask, passage["b"], 6)
	for layer: PackedByteArray in [m.water, m.bridge]:
		var index := layer.find(1)
		while index >= 0:
			mask[index] = 1
			index = layer.find(1, index + 1)
	return mask


static func _protect_disc(m, mask: PackedByteArray, c: Vector2i, radius: int) -> PackedByteArray:
	for y in range(c.y - radius, c.y + radius + 1):
		for x in range(c.x - radius, c.x + radius + 1):
			var q := Vector2i(x, y)
			if m.inb(q) and (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= radius * radius:
				mask[m.idx(q)] = 1
	return mask


static func _link_data(target: Dictionary, status: String, access: Vector2i, anchor: Vector2i, path: Array) -> Dictionary:
	return {"kind": target["kind"], "target": target["cell"], "r": target["r"], "status": status,
		"access": access, "anchor": anchor, "path": path, "length": maxi(0, path.size() - 1)}


static func _nearby_candidates(c: Vector2i, buckets: Dictionary) -> Array:
	var center := Vector2i(c.x / BUCKET, c.y / BUCKET)
	var out: Array = []
	for radius in 16:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var key := center + Vector2i(dx, dy)
				if buckets.has(key):
					out.append_array(buckets[key])
		# Include sempre gli otto bucket adiacenti: basta per ogni accesso vicino.
		if radius >= 1 and out.size() >= MAX_CANDIDATES:
			break
	# Chiavi intere (distanza al quadrato, poi ordine di raccolta): l'ordinamento nativo evita una lambda per confronto.
	var keys := PackedInt64Array()
	keys.resize(out.size())
	for i in out.size():
		var delta: Vector2i = out[i] - c
		keys[i] = ((delta.x * delta.x + delta.y * delta.y) << 32) | i
	keys.sort()
	var nearest: Array = []
	for i in mini(keys.size(), MAX_CANDIDATES * 2):
		nearest.append(out[keys[i] & 0xffffffff])
	return nearest


static func _access_cell(c: Vector2i, anchor: Vector2i, radius: int) -> Vector2i:
	var direction := Vector2(anchor - c).normalized()
	if direction.length_squared() < 0.1:
		direction = Vector2.RIGHT
	return c + Vector2i(roundi(direction.x * float(radius + 3)), roundi(direction.y * float(radius + 3)))


static func _direct_route(m, start: Vector2i, anchor: Vector2i, protected: PackedByteArray) -> Array:
	var path: Array = [start]
	path.append_array(m.carve_path_peek(start, anchor))
	return path if _route_safe(m, path, protected) else []


static func _detour_route(m, start: Vector2i, anchor: Vector2i, protected: PackedByteArray) -> Array:
	var direction := Vector2(anchor - start).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var best: Array = []
	for offset in [20.0, -20.0, 40.0, -40.0, 64.0, -64.0, 96.0, -96.0, 128.0, -128.0]:
		var midf := Vector2(start).lerp(Vector2(anchor), 0.5) + perpendicular * float(offset)
		var middle := Vector2i(roundi(midf.x), roundi(midf.y))
		if middle == start or middle == anchor:
			continue
		var cells := absi(middle.x - start.x) + absi(middle.y - start.y) + absi(anchor.x - middle.x) + absi(anchor.y - middle.y) + 1
		if not best.is_empty() and cells >= best.size():
			continue
		var path: Array = [start]
		path.append_array(m.carve_path_peek(start, middle))
		path.append_array(m.carve_path_peek(middle, anchor))
		if _route_safe(m, path, protected):
			best = path
	return best


static func _coastal_route(m, c: Vector2i, radius: int, known: PackedByteArray, protected: PackedByteArray) -> Array:
	# BFS dalla radura alla prima cella della rete: visita soltanto il terreno necessario.
	var started := Time.get_ticks_msec()
	# Solo indici interi e coda preallocata: e' il ciclo piu' caldo della generazione.
	var width: int = Game.MW
	var height: int = Game.MH
	var start_index := c.y * width + c.x
	var previous := PackedInt32Array()
	previous.resize(width * height)
	previous.fill(-1)
	previous[start_index] = start_index
	var queue := PackedInt32Array()
	queue.resize(width * height)
	queue[0] = start_index
	var tail := 1
	var head := 0
	var goal := -1
	var reach_squared := (radius + 2) * (radius + 2)
	var own_squared := (radius + 1) * (radius + 1)
	var min_x := maxi(3, c.x - 256)
	var max_x := mini(width - 4, c.x + 256)
	var min_y := maxi(3, c.y - 256)
	var max_y := mini(height - 4, c.y + 256)
	var steps_x := PackedInt32Array()
	var steps_y := PackedInt32Array()
	for direction: Vector2i in DIRS:
		steps_x.append(direction.x)
		steps_y.append(direction.y)
	while head < tail:
		var current_index := queue[head]
		head += 1
		var current_x := current_index % width
		var current_y := current_index / width
		if known[current_index] != 0 and (current_x - c.x) * (current_x - c.x) + (current_y - c.y) * (current_y - c.y) > reach_squared:
			goal = current_index
			break
		for d in 4:
			var x := current_x + steps_x[d]
			var y := current_y + steps_y[d]
			if x < min_x or x > max_x or y < min_y or y > max_y:
				continue
			var index := y * width + x
			if previous[index] != -1:
				continue
			if protected[index] != 0 and (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) > own_squared:
				continue
			if _outside_fast(m, x, y):
				continue
			previous[index] = current_index
			queue[tail] = index
			tail += 1
	if m.testing:
		print("ROADS ricerca costiera target=", c, " celle visitate=", head, " ms=", Time.get_ticks_msec() - started)
	if goal < 0:
		return []
	var full: Array = []
	var at := goal
	while true:
		full.append(Vector2i(at % Game.MW, at / Game.MW))
		if at == start_index:
			break
		at = previous[at]
	full.reverse()
	var last_inside := -1
	for i in full.size():
		if Vector2(full[i]).distance_squared_to(Vector2(c)) <= float(radius + 2) * float(radius + 2):
			last_inside = i
	var path: Array = full.slice(last_inside + 1)
	return path if _route_safe(m, path, protected) else []


static func _outside_fast(m, x: int, y: int) -> bool:
	if x < 3 or y < 3 or x >= Game.MW - 3 or y >= Game.MH - 3:
		return true
	var nx := (float(x) - 480.0) / 538.0
	var ny := (float(y) - 352.0) / 397.0
	var distance_squared := nx * nx + ny * ny
	# Il rumore costiero pesa al massimo 0.30: lontano dal bordo non serve calcolarlo.
	if distance_squared <= 0.49:
		return false
	if distance_squared >= 1.69:
		return true
	return m.is_outside_xy(x, y)


static func _route_safe(m, path: Array, protected: PackedByteArray) -> bool:
	if path.is_empty():
		return false
	for i in path.size():
		var c: Vector2i = path[i]
		if i > 0:
			var previous: Vector2i = path[i - 1]
			if absi(c.x - previous.x) + absi(c.y - previous.y) != 1:
				return false
		if not m.inb(c) or c.x < 3 or c.y < 3 or c.x >= Game.MW - 3 or c.y >= Game.MH - 3:
			return false
		if protected[c.y * Game.MW + c.x] != 0 or _outside_fast(m, c.x, c.y):
			return false
	return true


static func _carve(m, path: Array, major: bool, protected: PackedByteArray) -> void:
	for i in path.size():
		var c: Vector2i = path[i]
		_paint_cell(m, c, protected, true)
		if major:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var q := c + Vector2i(dx, dy)
					_paint_cell(m, q, protected, Game.hh(q.x, q.y, 701) < 0.42)
		else:
			var previous: Vector2i = path[maxi(0, i - 1)]
			var following: Vector2i = path[mini(path.size() - 1, i + 1)]
			var direction := following - previous
			var side := Vector2i(-direction.y, direction.x)
			if side != Vector2i.ZERO:
				var q := c + side
				_paint_cell(m, q, protected, Game.hh(q.x, q.y, 702) < 0.22)


static func _paint_cell(m, c: Vector2i, protected: PackedByteArray, paint_road: bool) -> void:
	if not m.inb(c) or c.x < 3 or c.y < 3 or c.x >= Game.MW - 3 or c.y >= Game.MH - 3:
		return
	var index := c.y * Game.MW + c.x
	if protected[index] != 0 or _outside_fast(m, c.x, c.y):
		return
	m.grid[index] = 1
	m.reach[index] = 1
	m.ovr[index] = 1
	if paint_road:
		m.road[index] = 1



## Verifica sia la copertura sia le celle effettivamente dipinte, non solo i metadati.
static func test(m) -> int:
	var errors: Array[String] = []
	# Gli oggetti nascono quando un blocco viene completato: senza tutti i blocchi gli ingombri non si vedono.
	_finalize_all(m)
	var targets := _targets(m)
	var protected := _protection(m, targets)
	if m.road_links.size() != targets.size():
		errors.append("copertura %d/%d" % [m.road_links.size(), targets.size()])
	var cemetery: Array = m.road_paths.get("access:cemetery", [])
	if cemetery.is_empty():
		errors.append("accesso sud del cimitero mancante")
	else:
		if not _walkable(m, cemetery):
			errors.append("accesso sud del cimitero interrotto da ostacoli")
	if not m.world_has_cathedral:
		errors.append("la cattedrale non e' stata piazzata")
	var counts := {"existing": 0, "new": 0, "failed": 0}
	var by_kind := {}
	var total_length := 0
	for target in targets:
		var id := str(target["id"])
		var kind := str(target["kind"])
		if not by_kind.has(kind):
			by_kind[kind] = {"total": 0, "existing": 0, "new": 0, "failed": 0}
		by_kind[kind]["total"] += 1
		if not m.road_links.has(id):
			errors.append(id + ": collegamento mancante")
			continue
		var link: Dictionary = m.road_links[id]
		var status := str(link["status"])
		if not counts.has(status):
			errors.append(id + ": stato sconosciuto " + status)
			continue
		counts[status] += 1
		by_kind[kind][status] += 1
		if status == "failed":
			errors.append("%s @%s: nessun percorso sicuro" % [id, str(target["cell"])])
			continue
		var access: Vector2i = link["access"]
		if not m.inb(access):
			errors.append(id + ": accesso fuori mappa")
			continue
		if m.road[m.idx(access)] != 1:
			errors.append(id + ": accesso non dipinto come strada")
		if Vector2(access).distance_to(Vector2(target["cell"])) > float(target["r"]) + 4.0:
			errors.append(id + ": accesso troppo distante dal luogo")
		var path: Array = link["path"]
		if status == "new":
			total_length += int(link["length"])
			if not _route_safe(m, path, protected):
				errors.append(id + ": percorso discontinuo, protetto o non sicuro")
			if not m.road_paths.has(id):
				errors.append(id + ": percorso non registrato")
			if not _walkable(m, path):
				errors.append(id + ": sentiero interrotto da ostacoli")
			var anchor: Vector2i = link["anchor"]
			if not m.inb(anchor) or m.road[m.idx(anchor)] != 1:
				errors.append(id + ": aggancio alla rete non valido")
	for kind in by_kind:
		print("ROADTEST ", kind, " ", by_kind[kind])
	print("ROADTEST totali=", targets.size(), " esistenti=", counts["existing"], " nuovi=", counts["new"],
		" falliti=", counts["failed"], " celle nuove=", total_length)
	for i in mini(20, errors.size()):
		print("ROADTEST ERRORE ", errors[i])
	print("ROADTEST ESITO=", "OK" if errors.is_empty() else "FALLITO (%d errori)" % errors.size())
	return errors.size()


## Si cammina da un capo all'altro restando entro 2 celle dal sentiero: un falo' aggirabile va bene.
static func _walkable(m, path: Array) -> bool:
	if path.is_empty():
		return false
	var corridor := {}
	for c in path:
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var q: Vector2i = c + Vector2i(dx, dy)
				if m.is_floor(q) and not m.block.has(q):
					corridor[q] = true
	var start: Vector2i = path[0]
	var finish: Vector2i = path[path.size() - 1]
	if not corridor.has(start):
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		# L'aggancio puo' stare sotto un oggetto della rete principale: basta arrivargli accanto.
		if absi(current.x - finish.x) + absi(current.y - finish.y) <= (0 if corridor.has(finish) else 2):
			return true
		for direction in DIRS:
			var q: Vector2i = current + direction
			if corridor.has(q) and not seen.has(q):
				seen[q] = true
				queue.append(q)
	return false


static func _finalize_all(m) -> void:
	for cy in int(ceil(Game.MH / 32.0)):
		for cx in int(ceil(Game.MW / 32.0)):
			m.gen_chunk(cx, cy)
			m.finalize_chunk(Vector2i(cx, cy))


## Cattura di sviluppo: terreno completo e rete, senza finalizzare nemici o decorazioni.
static func reveal_map(m) -> void:
	for cy in int(ceil(Game.MH / 32.0)):
		for cx in int(ceil(Game.MW / 32.0)):
			m.gen_chunk(cx, cy)
	for y in Game.MH:
		for x in Game.MW:
			var c := Vector2i(x, y)
			var index := y * Game.MW + x
			m.seen[index] = 1
			m.mm_img.set_pixel(x, y, m.mm_color(c))
	m.mm_tex.update(m.mm_img)
	var path := "user://roadmap_pixels.png"
	m.mm_img.save_png(path)
	print("ROADSHOT PIXELS ", ProjectSettings.globalize_path(path))
	m.open_map()
