class_name TemporalClearing
## Modalità Radura Temporale: arena ampia, vista 3/4, UFO che fa cadere oggetti
## Il giocatore deve schivare e raccogliere armi per colpire l'UFO (6 colpi = fuga)

extends RefCounted

const ARENA_RADIUS := 200.0
const UFO_HEIGHT := 12.0 * 16.0
const DROP_HEIGHT := 14.0 * 16.0
const GRAVITY := 900.0
const MAX_DROPS_PER_WAVE := 4
const MIN_DROPS_PER_WAVE := 2
const WAVE_INTERVAL_MIN := 1.5
const WAVE_INTERVAL_MAX := 3.0
const UFO_HITS_TO_FLEE := 6

const DROP_TYPES := {
	"bazooka": {"weight": 3, "weapon": "rocket", "color": Color(0.4, 0.3, 0.2), "model": "bazooka"},
	"shotgun": {"weight": 4, "weapon": "shotgun", "color": Color(0.3, 0.25, 0.2), "model": "pompa"},
	"plasmarifle": {"weight": 3, "weapon": "plasma", "color": Color(0.2, 0.4, 0.6), "model": "fucileplasma"},
	"rock": {"weight": 15, "weapon": "", "color": Color(0.35, 0.3, 0.25), "model": ""},
	"crate": {"weight": 10, "weapon": "", "color": Color(0.4, 0.3, 0.2), "model": ""},
	"debris": {"weight": 12, "weapon": "", "color": Color(0.3, 0.3, 0.3), "model": ""},
	"anvil": {"weight": 4, "weapon": "", "color": Color(0.2, 0.2, 0.25), "model": ""},
	"bomb": {"weight": 5, "weapon": "", "color": Color(0.15, 0.1, 0.1), "model": ""},
}

var main
var ufo: Node2D
var drops: Array = []
var shadows: Array = []
var wave_timer := 0.0
var next_wave_time := 0.0
var ufo_hits := 0
var active := false
var rng: RandomNumberGenerator

static func start(m) -> void:
	var tc := TemporalClearing.new()
	tc.main = m
	tc.rng = RandomNumberGenerator.new()
	tc.rng.seed = m.world_seed + 9999
	tc.active = true
	tc.ufo_hits = 0
	m.build_area("temporal_clearing")
	tc._setup_arena()

func _setup_arena() -> void:
	if not active or main == null or main.player == null:
		return
	main.player.position = Vector2.ZERO
	main.player.cam.position = Vector2.ZERO
	main.player.cam.reset_smoothing()
	_create_ufo()
	next_wave_time = rng.randi_range(1.0, 2.0)
	main.say("RADURA TEMPORALE - SOPRAVVIVI E COLPISCI L'UFO!")
	main.snd("roar")

func _create_ufo() -> void:
	ufo = Node2D.new()
	ufo.name = "TemporalUFO"
	ufo.position = Vector2(0, -80)
	ufo.z_index = 50
	var spr := Sprite2D.new()
	spr.texture = Game.tex("ch_ufo")
	if spr.texture:
		spr.scale = Vector2(2.5, 2.5)
		spr.offset = Vector2(spr.texture.get_width() / 2, spr.texture.get_height())
	ufo.add_child(spr)
	var light = Game.make_light(ufo, Vector2(0, -40), Color(0.5, 0.8, 1.0), 1.5, 0.9)
	light.z_index = 49
	var bubble = Sprite2D.new()
	bubble.texture = Game.tex("circle_top_0")
	if bubble.texture:
		bubble.scale = Vector2(3.0, 1.5)
		bubble.modulate = Color(0.5, 0.85, 1.0, 0.4)
		bubble.offset = Vector2(bubble.texture.get_width() / 2, bubble.texture.get_height() / 2)
		bubble.position = Vector2(0, 20)
		bubble.z_index = 48
		ufo.add_child(bubble)
		var tw = main.create_tween()
		tw.set_loops()
		tw.tween_property(bubble, "modulate:a", 0.6, 1.0)
		tw.tween_property(bubble, "modulate:a", 0.3, 1.0)
		tw.tween_property(bubble, "scale", Vector2(3.2, 1.6), 1.0)
		tw.tween_property(bubble, "scale", Vector2(2.8, 1.4), 1.0)
	main.ents.add_child(ufo)

func _process(dt: float) -> void:
	if not active or main.state != "play" or main.player == null:
		return
	wave_timer += dt
	if wave_timer >= next_wave_time:
		_spawn_wave()
		wave_timer = 0.0
		next_wave_time = rng.randf_range(WAVE_INTERVAL_MIN, WAVE_INTERVAL_MAX)
	_update_drops(dt)
	_update_shadows()
	if ufo != null and is_instance_valid(ufo):
		ufo.position.y = -80 + sin(wave_timer * 1.5) * 8.0
		ufo.position.x = sin(wave_timer * 0.7) * 15.0

func _spawn_wave() -> void:
	var count = rng.randi_range(MIN_DROPS_PER_WAVE, MAX_DROPS_PER_WAVE)
	var drop_keys = DROP_TYPES.keys()
	var weights = []
	for k in drop_keys:
		weights.append(DROP_TYPES[k]["weight"])
	for i in count:
		var total = 0
		for w in weights:
			total += w
		var pick = rng.randf() * total
		var accum = 0
		var chosen = drop_keys[0]
		for j in drop_keys.size():
			accum += weights[j]
			if pick <= accum:
				chosen = drop_keys[j]
				break
		var dt = DROP_TYPES[chosen]
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(20.0, ARENA_RADIUS * 0.85)
		var spawn_pos = Vector2(cos(angle), sin(angle)) * dist
		var height = DROP_HEIGHT
		var velocity = Vector2.ZERO
		var drop := {
			"type": chosen,
			"data": dt,
			"position": spawn_pos,
			"velocity": velocity,
			"height": height,
			"shadow_pos": spawn_pos,
			"collected": false,
			"node": null,
			"shadow_node": null,
		}
		_create_drop_visual(drop)
		drops.append(drop)

func _create_drop_visual(drop: Dictionary) -> void:
	var dt = drop["data"]
	var pos = drop["position"]
	var shadow = Node2D.new()
	shadow.position = pos
	shadow.z_index = 5
	var shadow_spr = Sprite2D.new()
	shadow_spr.texture = Game.tex("circle_top_1")
	if shadow_spr.texture:
		shadow_spr.scale = Vector2(1.2, 0.6)
		shadow_spr.modulate = Color(0, 0, 0, 0.5)
		shadow_spr.offset = Vector2(shadow_spr.texture.get_width() / 2, shadow_spr.texture.get_height() / 2)
	shadow.add_child(shadow_spr)
	var tw = main.create_tween()
	tw.set_loops()
	tw.tween_property(shadow_spr, "modulate:a", 0.7, 0.5)
	tw.tween_property(shadow_spr, "modulate:a", 0.3, 0.5)
	shadow_spr.scale = Vector2(1.2, 0.6)
	main.fx.add_child(shadow)
	drop["shadow_node"] = shadow
	var node = Node2D.new()
	node.position = pos
	node.z_index = 30
	var spr = Sprite2D.new()
	if dt["model"] != "" and Game.tex("ch_" + dt["model"]) != null:
		spr.texture = Game.tex("ch_" + dt["model"])
		spr.scale = Vector2(1.5, 1.5)
	else:
		spr.texture = Game.tex("circle_top_0")
		spr.modulate = dt["color"]
		spr.scale = Vector2(0.8, 0.8)
	spr.offset = Vector2(spr.texture.get_width() / 2, spr.texture.get_height() / 2)
	node.add_child(spr)
	main.burst(pos + Vector2(0, -20), Color(0.5, 0.85, 1.0, 0.8), 8, 30.0, 0.4)
	main.ents.add_child(node)
	drop["node"] = node
	drop["sprite"] = spr

func _update_drops(dt: float) -> void:
	for i in range(drops.size() - 1, -1, -1):
		var drop = drops[i]
		if drop["collected"]:
			continue
		drop["height"] -= GRAVITY * dt
		drop["velocity"].y += GRAVITY * dt * 0.1
		var visual_y = drop["position"].y - drop["height"] * 0.7
		var visual_pos = Vector2(drop["position"].x + drop["velocity"].x * dt, visual_y)
		if drop["node"] != null and is_instance_valid(drop["node"]):
			drop["node"].position = visual_pos
			if drop["sprite"] != null and is_instance_valid(drop["sprite"]):
				drop["sprite"].rotation += dt * 3.0
		if drop["shadow_node"] != null and is_instance_valid(drop["shadow_node"]):
			var shadow_spr = drop["shadow_node"].get_child(0)
			if shadow_spr:
				var scale_factor = max(0.2, drop["height"] / DROP_HEIGHT)
				shadow_spr.scale = Vector2(1.2 * scale_factor, 0.6 * scale_factor)
				shadow_spr.modulate = Color(0, 0, 0, 0.5 * scale_factor)
		if drop["height"] <= 0:
			_on_drop_impact(drop, i)
			continue
		if main.player != null and is_instance_valid(main.player):
			var dist = main.player.position.distance_to(visual_pos)
			if dist < 20.0 and drop["data"]["weapon"] != "":
				_collect_weapon(drop)

func _on_drop_impact(drop: Dictionary, drop_index: int) -> void:
	var pos = drop["position"]
	var dt = drop["data"]
	main.burst(pos, dt["color"], 12, 40.0, 0.4)
	main.shake(1.5)
	main.snd("slam")
	if main.player != null and main.player.position.distance_to(pos) < 24.0:
		main.player.hurt(25.0, Vector2(0, -1), 0.0)
		main.burst(main.player.position, Color(1, 0.3, 0.3), 8, 30.0, 0.3)
	if drop["node"] != null and is_instance_valid(drop["node"]):
		drop["node"].queue_free()
	if drop["shadow_node"] != null and is_instance_valid(drop["shadow_node"]):
		drop["shadow_node"].queue_free()
	drops.remove_at(drop_index)

func _collect_weapon(drop: Dictionary) -> void:
	if drop["collected"]:
		return
	drop["collected"] = true
	var weapon_id = drop["data"]["weapon"]
	var w: Dictionary = Rpg.make_weapon(0, str(weapon_id))
	if w != null:
		main.player.pickup_weapon(w)
		main.say("RACCOLTO: " + w["n"])
		main.snd("level")
		main.burst(main.player.position, Color(0.5, 1.0, 0.5), 16, 50.0, 0.6)
	if drop["node"] != null and is_instance_valid(drop["node"]):
		drop["node"].queue_free()
	if drop["shadow_node"] != null and is_instance_valid(drop["shadow_node"]):
		drop["shadow_node"].queue_free()
	drops.erase(drop)

func _update_shadows() -> void:
	pass

func on_ufo_hit() -> void:
	if not active:
		return
	ufo_hits += 1
	main.burst(ufo.position, Color(1, 0.5, 0.2), 20, 60.0, 0.6)
	main.shake(3.0)
	main.snd("hit")
	if ufo_hits >= UFO_HITS_TO_FLEE:
		_ufo_flee()
	else:
		main.say("COLPO! " + str(UFO_HITS_TO_FLEE - ufo_hits) + " MANCANO")

func _ufo_flee() -> void:
	active = false
	main.say("L'UFO FUGGE!")
	main.snd("roar")
	if ufo != null and is_instance_valid(ufo):
		var tw = main.create_tween()
		tw.tween_property(ufo, "position:y", -400, 2.0)
		tw.tween_property(ufo, "position:x", 300, 2.0)
		tw.tween_property(ufo, "modulate:a", 0.0, 1.5)
		tw.chain().tween_callback(func(): ufo.queue_free())
	for d in drops:
		if d["node"] != null and is_instance_valid(d["node"]):
			d["node"].queue_free()
			if d["shadow_node"] != null and is_instance_valid(d["shadow_node"]):
				d["shadow_node"].queue_free()
	drops.clear()
	var tw2 = main.create_tween()
	tw2.tween_callback(func(): main.build_area("world")).set_delay(3.0)

func cleanup() -> void:
	active = false
	if ufo != null and is_instance_valid(ufo):
		ufo.queue_free()
	for d in drops:
		if d["node"] != null and is_instance_valid(d["node"]):
			d["node"].queue_free()
			if d["shadow_node"] != null and is_instance_valid(d["shadow_node"]):
				d["shadow_node"].queue_free()
	drops.clear()