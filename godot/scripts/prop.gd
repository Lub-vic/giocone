class_name Prop
extends Node2D

var kind := ""
var cell := Vector2i.ZERO
var breakable := false
var opened := false
var lit := false
var rare := false
var dest := ""
var light: PointLight2D = null
var spr: Sprite2D
var scene := false
var npc_id := ""
var item: Dictionary = {}
var page_i := -1
var dkey := ""
var dm := ""
var dd := ""
var hp := 0.0
var hp_max := 0.0
var dcells: Array = []


func setup(k: String, c: Vector2i) -> void:
	kind = k
	cell = c
	breakable = k == "barrel" or k == "coffin"
	position = Vector2(c) * Game.TS + Vector2(8, 13)
	spr = Sprite2D.new()
	spr.texture = Game.tex("necro" if k == "elder" else ("grave_mound_0" if k == "dig" else k))
	spr.offset = Vector2(0, -6)
	add_child(spr)


func _draw() -> void:
	if scene:
		return
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 7.0, Color(0, 0, 0, 0.4))


func setup_scene(name: String, c: Vector2i, fp: Vector2i) -> void:
	kind = name
	cell = c
	scene = true
	var t: Texture2D = Game.tex(name)
	position = Vector2((c.x + fp.x / 2.0) * Game.TS, (c.y + 1) * Game.TS - 1)
	spr = Sprite2D.new()
	spr.texture = t
	spr.offset = Vector2(0, -t.get_height() / 2.0)
	add_child(spr)


func setup_top(name: String, c: Vector2i, fp: Vector2i, canopy := false) -> void:
	kind = name
	cell = c
	scene = true
	var t: Texture2D = Game.tex(name)
	# ordinamento in profondita': le chiome stanno sempre dietro a chi cammina
	var ybase := c.y if canopy else c.y + fp.y
	position = Vector2(c.x * Game.TS, ybase * Game.TS)
	spr = Sprite2D.new()
	spr.texture = t
	spr.centered = false
	spr.offset = Vector2(0, (c.y - ybase) * Game.TS)
	spr.modulate = Game.tint(c.x, c.y, 0.07)
	add_child(spr)
