class_name PoiData
extends RefCounted
## Luoghi di interesse e micro-composizioni, descritti in file JSON (res://data/poi_templates.json).
## Si possono aggiungere o sostituire modelli con user://poi_custom.json (stesso formato): e' la base per un editor.

static var templates: Array = []
static var micro: Array = []
static var loaded := false


static func ensure_loaded() -> void:
	if loaded:
		return
	loaded = true
	_load("res://data/poi_templates.json")
	_load("res://data/poi_custom.json")
	_load("user://poi_custom.json")


static func _load(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_merge(d.get("templates", []), templates)
		_merge(d.get("micro", []), micro)


static func _merge(src: Array, dst: Array) -> void:
	for e in src:
		var found := -1
		for i in dst.size():
			if dst[i]["id"] == e["id"]:
				found = i
		if found >= 0:
			dst[found] = e
		else:
			dst.append(e)


static func by_id(id: String) -> Dictionary:
	ensure_loaded()
	for t in templates:
		if t["id"] == id:
			return t
	return {}


static func pick(list: Array, bi: int, rng: RandomNumberGenerator) -> Dictionary:
	ensure_loaded()
	var ok: Array = []
	var tot := 0.0
	for t in list:
		var bio: Array = t.get("bio", [])
		if bio.is_empty() or bio.has(bi):
			ok.append(t)
			tot += float(t.get("w", 1.0))
	if ok.is_empty():
		return {}
	var x := rng.randf() * tot
	for t in ok:
		x -= float(t.get("w", 1.0))
		if x <= 0.0:
			return t
	return ok[ok.size() - 1]
