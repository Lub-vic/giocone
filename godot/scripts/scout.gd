class_name ScoutFx
extends Node2D
## Effetto collaterale dello zoom: con la vista allontanata si vedono segnalini su tesori, pagine, bottino e personaggi.

var main
var t := 0.0


func _process(dt: float) -> void:
	t += dt
	visible = main.player != null and main.player.cam.zoom.x < 0.9 and main.state == "play"
	if visible:
		queue_redraw()


func _draw() -> void:
	var pl: Vector2 = main.player.position
	var pulse := 0.65 + 0.35 * sin(t * 4.0)
	for p in main.props:
		if p.position.distance_squared_to(pl) > 640000.0:
			continue
		var col: Color = Color(0, 0, 0, 0)
		match p.kind:
			"chest":
				if not p.opened:
					col = Color(1.0, 0.8, 0.3)
			"page":
				col = Color(1.0, 1.0, 0.85)
			"loot":
				col = Color(0.8, 0.5, 1.0)
				if p.item.get("k", "") == "w":
					col = Rpg.RARITY[int(p.item["r"])]["c"]
			"npc":
				col = Color(0.4, 1.0, 0.6)
			"bonfire":
				if not p.lit:
					col = Color(0.5, 0.6, 1.0)
		if col.a <= 0.0:
			continue
		var c: Vector2 = p.position + (Vector2(8, -10) if p.scene else Vector2(0, -20))
		col.a = pulse
		var pts := PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0)])
		draw_colored_polygon(pts, col)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0, 0.8), 1.0)
