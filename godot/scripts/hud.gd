class_name Hud
extends Control
## Interfaccia in pixel art: font a pixel 5x7, cornici smussate con rivetti, barre a segmenti.

var main
var font: Font = Game.font()
var shown_hp := 100.0

const OUTLINE := Color(0.03, 0.0, 0.05, 1.0)
const GOLD := Color(0.72, 0.54, 0.18)
const GOLD_D := Color(0.38, 0.27, 0.09)
const GOLD_L := Color(0.95, 0.8, 0.4)


func _process(dt: float) -> void:
	if main != null and main.player != null:
		shown_hp = move_toward(shown_hp, main.player.hp, 60.0 * dt)
	queue_redraw()


func _k(k: String, p: String) -> String:
	return p if main.use_pad else k


# ---------------------------------------------------------------- testo
func _fs(sz: int) -> int:
	return 9 if sz <= 11 else (18 if sz <= 19 else 27)


func _txt(s: String, pos: Vector2, c: Color, sz := 8, al := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	var t := s.to_upper()
	var fs := _fs(sz)
	var x := roundf(pos.x)
	var y := roundf(pos.y)
	if w > 0.0 and al != HORIZONTAL_ALIGNMENT_LEFT:
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if al == HORIZONTAL_ALIGNMENT_CENTER:
			x += roundf((w - tw) / 2.0)
		else:
			x += roundf(w - tw)
	var p := Vector2(x, y)
	for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1), Vector2(1, 1)]:
		draw_string(font, p + o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, OUTLINE)
	draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _wrap(s: String, n: int) -> Array:
	var lines: Array = []
	var cur := ""
	for wd in s.split(" "):
		if cur != "" and (cur + " " + wd).length() > n:
			lines.append(cur)
			cur = wd
		else:
			cur = wd if cur == "" else cur + " " + wd
	if cur != "":
		lines.append(cur)
	return lines


# ---------------------------------------------------------------- elementi
func _frame(r: Rect2, hot := true, dark := 0.96) -> void:
	var x := int(r.position.x)
	var y := int(r.position.y)
	var w := int(r.size.x)
	var h := int(r.size.y)
	var gold := GOLD if hot else GOLD_D
	draw_rect(Rect2(x + 2, y + 2, w, h), Color(0, 0, 0, 0.45))                    # ombra
	draw_rect(Rect2(x + 1, y + 1, w - 2, h - 2), Color(0.055, 0.03, 0.1, dark))     # fondo
	draw_rect(Rect2(x + 1, y, w - 2, 1), OUTLINE)                                   # contorno con angoli smussati
	draw_rect(Rect2(x + 1, y + h - 1, w - 2, 1), OUTLINE)
	draw_rect(Rect2(x, y + 1, 1, h - 2), OUTLINE)
	draw_rect(Rect2(x + w - 1, y + 1, 1, h - 2), OUTLINE)
	draw_rect(Rect2(x + 2, y + 1, w - 4, 1), gold)                                  # filo d'oro
	draw_rect(Rect2(x + 2, y + h - 2, w - 4, 1), gold.darkened(0.4))
	draw_rect(Rect2(x + 1, y + 2, 1, h - 4), gold)
	draw_rect(Rect2(x + w - 2, y + 2, 1, h - 4), gold.darkened(0.4))
	draw_rect(Rect2(x + 3, y + 2, w - 6, 1), Color(1, 1, 1, 0.07))                  # luce interna
	for c in [Vector2(x + 3, y + 3), Vector2(x + w - 5, y + 3), Vector2(x + 3, y + h - 5), Vector2(x + w - 5, y + h - 5)]:
		draw_rect(Rect2(c.x, c.y, 2, 2), gold if hot else gold.darkened(0.2))       # rivetti
		draw_rect(Rect2(c.x, c.y, 1, 1), GOLD_L if hot else gold)


func _panel(r: Rect2) -> void:
	_frame(r, true, 0.97)


func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, ghost := -1.0) -> void:
	var x := int(pos.x)
	var y := int(pos.y)
	var wi := int(w)
	var hi := int(h)
	draw_rect(Rect2(x - 1, y - 1, wi + 2, hi + 2), OUTLINE)
	draw_rect(Rect2(x, y, wi, hi), Color(0.1, 0.05, 0.09))
	if ghost > frac:
		draw_rect(Rect2(x, y, int(wi * clampf(ghost, 0.0, 1.0)), hi), Color(0.8, 0.6, 0.22))
	var fw := int(round(wi * clampf(frac, 0.0, 1.0)))
	if fw > 0:
		draw_rect(Rect2(x, y, fw, hi), col)
		draw_rect(Rect2(x, y, fw, 1), col.lightened(0.45))
		if hi > 3:
			draw_rect(Rect2(x, y + hi - 1, fw, 1), col.darkened(0.35))
	for sx in range(x + 8, x + wi, 8):                                                # tacche a segmenti
		draw_rect(Rect2(sx, y, 1, hi), Color(0, 0, 0, 0.35))


func _crosshair(p: Player) -> void:
	var cp: Vector2 = get_viewport().get_canvas_transform() * p.aim_world - position
	if p.lock != null and is_instance_valid(p.lock):   # nemico agganciato: parentesi rosse attorno
		var lc: Vector2 = get_viewport().get_canvas_transform() * (p.lock.position + Vector2(0, -8)) - position
		var r := 11.0 + p.lock.radius * 0.6 + sin(Time.get_ticks_msec() / 120.0)
		var lcol := Color(1.0, 0.3, 0.25)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var c := lc + Vector2(sx, sy) * r
				draw_line(c, c - Vector2(sx * 4, 0), Color(0, 0, 0, 0.8), 3.0)
				draw_line(c, c - Vector2(0, sy * 4), Color(0, 0, 0, 0.8), 3.0)
				draw_line(c, c - Vector2(sx * 4, 0), lcol, 1.0)
				draw_line(c, c - Vector2(0, sy * 4), lcol, 1.0)
	if cp.x < -10.0 or cp.x > size.x + 10.0 or cp.y < -10.0 or cp.y > size.y + 10.0:
		return
	var col := Color(1.0, 0.82, 0.42, 0.95)
	var shadow := Color(0.03, 0.01, 0.04, 0.9)
	draw_arc(cp, 5.0, 0.0, TAU, 16, shadow, 3.0)
	draw_arc(cp, 5.0, 0.0, TAU, 16, col, 1.0)
	draw_line(cp + Vector2(-9, 0), cp + Vector2(-3, 0), shadow, 3.0)
	draw_line(cp + Vector2(3, 0), cp + Vector2(9, 0), shadow, 3.0)
	draw_line(cp + Vector2(0, -9), cp + Vector2(0, -3), shadow, 3.0)
	draw_line(cp + Vector2(0, 3), cp + Vector2(0, 9), shadow, 3.0)
	draw_line(cp + Vector2(-9, 0), cp + Vector2(-3, 0), col, 1.0)
	draw_line(cp + Vector2(3, 0), cp + Vector2(9, 0), col, 1.0)
	draw_line(cp + Vector2(0, -9), cp + Vector2(0, -3), col, 1.0)
	draw_line(cp + Vector2(0, 3), cp + Vector2(0, 9), col, 1.0)


# ---------------------------------------------------------------- schermata principale
func _draw() -> void:
	if main == null or main.player == null:
		return
	if main.state == "loading":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 1.0))
		_txt("CRYPT OF EMBERS", Vector2(0, 110), Color(0.95, 0.72, 0.3), 18, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_txt("GENERAZIONE DEL MONDO" + ".".repeat(int(Time.get_ticks_msec() / 300) % 4), Vector2(0, 150), Color(0.8, 0.78, 0.92), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_txt("LA VALLE DI VESPRA SI RISVEGLIA", Vector2(0, 170), Color(0.55, 0.55, 0.68), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	if main.state == "story":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 0.96))
		_txt("CRYPT OF EMBERS", Vector2(0, 38), Color(0.95, 0.72, 0.3), 18, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		var sy := 66.0
		for ln in main.STORY:
			_txt(ln, Vector2(0, sy), Color(0.88, 0.84, 0.95), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			sy += 12.0
		_txt("PREMI UN TASTO PER INIZIARE", Vector2(0, size.y - 22), Color(1, 0.85, 0.5), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	if main.state == "results":
		var rr: Dictionary = main.run_result
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 0.97))
		_txt("LA VALLE E' LIBERA" if rr["win"] else "SEI CADUTO", Vector2(0, 60), Color(0.95, 0.72, 0.3) if rr["win"] else Color(0.85, 0.15, 0.2), 22, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		var tt := int(rr["t"])
		var ys := 96.0
		for ln in ["TEMPO  %d:%02d" % [tt / 60, tt % 60], "LIVELLO  %d" % int(rr["lv"]), "NEMICI UCCISI  %d" % int(rr["kills"]), "CUSTODI SCONFITTI  %d" % int(rr["stage"]), "ANIME RACCOLTE  %d" % int(rr["souls"])]:
			_txt(ln, Vector2(0, ys), Color(0.88, 0.84, 0.95), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			ys += 14.0
		_txt("CENERI GUADAGNATE  +%d" % int(rr["ceneri"]), Vector2(0, ys + 8), Color(1, 0.8, 0.4), 12, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_txt("PREMI UN TASTO", Vector2(0, size.y - 24), Color(0.7, 0.68, 0.8), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	if main.state == "class":
		_class_select()
		return
	if main.state == "title":
		_title()
		return
	if (main.state == "options" or main.state == "controls" or main.state == "remap") and main.in_title_menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 1.0))
		if main.state == "options":
			_options()
		else:
			_controls()
		return
	var p: Player = main.player
	var hw: float = min(100.0, 30.0 + p.max_hp * 0.33)
	var sw: float = min(86.0, 26.0 + p.max_st * 0.33)
	var msw: float = min(74.0, 22.0 + p.max_mana * 0.27)
	_bar(Vector2(5, 5), hw, 5, p.hp / p.max_hp, Color(0.78, 0.1, 0.16), shown_hp / p.max_hp)
	_bar(Vector2(5, 12), sw, 3, p.st / p.max_st, Color(0.3, 0.75, 0.38))
	_bar(Vector2(5, 17), msw, 3, p.mana / p.max_mana, Color(0.3, 0.5, 0.98))
	_bar(Vector2(5, 22), 46, 3, p.focus / 100.0, Color(0.72, 0.42, 0.98))
	var cr_full: bool = p.chrono >= Chrono.COST
	_bar(Vector2(54, 22), 40, 3, p.chrono / Chrono.MAX_E, Color(0.4, 1.0, 1.0) if cr_full else Color(0.25, 0.55, 0.7))
	if not p.veh.is_empty():
		_bar(Vector2(54, 27), 40, 3, float(p.veh["hp"]) / float(p.veh["max"]), Color(1.0, 0.6, 0.25))
		_txt("%s %ds" % [str(Chrono.JACKPOT[p.veh["id"]]["n"]), int(ceil(float(p.veh["t"])))], Vector2(98, 30), Color(1.0, 0.8, 0.5))
	elif cr_full and main.state == "play":
		_txt("N: EVOCA", Vector2(98, 25), Color(0.5, 1.0, 1.0))
	draw_texture(Game.tex("flask"), Vector2(4, 26), Color(1, 1, 1, 0.95))
	_txt("x%d" % p.flasks, Vector2(16, 34), Color(1, 0.82, 0.4))
	_txt("LV %d" % p.lv, Vector2(36, 34), Color(0.85, 0.82, 0.95))
	if not main.run_mode and p.souls >= Upgrades.cost(p.lv) and main.state == "play" and main.area != "":
		_txt("PRONTO AL FALO'", Vector2(62, 34), Color(0.62, 1.0, 0.86))
	if main.run_mode:
		_bar(Vector2(7, 53), 100, 3, clampf(float(p.souls) / float(main.run_need(p.lv)), 0.0, 1.0), Color(0.55, 1.0, 0.85))
		var tm := int(main.run_t)
		_txt("%d:%02d" % [tm / 60, tm % 60], Vector2(0, 10), Color(0.95, 0.85, 0.6), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if main.cycle > 0:
		_txt("CICLO %d" % (main.cycle + 1), Vector2(5, 44), Color(1, 0.62, 0.3))
	if Chrono.era() > 0:
		_txt("ERA: " + Chrono.era_name(), Vector2(5, 52 if main.cycle > 0 else 44), Color(0.95, 0.8, 0.5))
	# obiettivo compatto: pieno per qualche secondo quando cambia, poi attenuato; una sola missione
	var obj: String = main.objective()
	var obj_key := obj.substr(0, mini(obj.find("("), 28) if obj.find("(") > 0 else 28)
	if obj_key != _obj_last:
		_obj_last = obj_key
		_obj_t = 12.0
	_obj_t = maxf(0.0, _obj_t - get_process_delta_time())
	var oa := 1.0 if _obj_t > 0.0 else 0.5
	var oy := 49.0 if main.cycle > 0 else 39.0
	var olines: Array = _wrap(obj, 30)
	if _obj_t <= 0.0 and olines.size() > 1:
		olines = [str(olines[0]) + "..."]
	for ln in olines:
		_txt(ln, Vector2(5, oy + 7.0), Color(0.95, 0.8, 0.45, oa))
		oy += 9.0
	var ql: Array = main.quest_lines()
	if ql.size() > 0 and _obj_t > 0.0:
		var qs: Array = _wrap(str(ql[0]), 30)
		_txt(str(qs[0]), Vector2(5, oy + 9.0), Color(0.7, 0.92, 0.85, oa * 0.9))
		if ql.size() > 1 or qs.size() > 1:
			_txt("...", Vector2(5 + 6.0 * minf(30.0, str(qs[0]).length()), oy + 9.0), Color(0.7, 0.92, 0.85, oa * 0.9))
	if p.zmode > 0:
		_txt("MODALITA ORDA" if p.zmode == 1 else "MODALITA TATTICA", Vector2(0, 20), Color(1.0, 0.6, 0.9) if p.zmode == 1 else Color(0.6, 0.9, 1.0), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var overlay: bool = main.inv_open or main.state in ["menu", "pick", "travel", "pause", "options", "controls", "remap", "dialog", "craft", "map", "bestiary", "debug"]
	if not overlay:
		_equip_panel(p)
		_item_line(p)
		_relic_row(p)
		_spirit_row(p)
		_mat_row(p)
		_minimap()
		_clock()
		_edge_markers()
		if bool(main.settings["aim_manual"]) and main.state == "play":
			_crosshair(p)
	if main.chain >= 2:
		_txt("SERIE x%d   ANIME x%.1f" % [main.chain, main.chain_mult()], Vector2(0, 78), Color(1, 0.78, 0.3), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_bar(Vector2(size.x / 2 - 40, 82), 80, 3, clampf(main.chain_t / 4.5, 0.0, 1.0), Color(1, 0.62, 0.2))
	if main.show_fps:
		_txt("%d FPS" % Engine.get_frames_per_second(), Vector2(size.x - 60, size.y - 26), Color(0.7, 1, 0.7))
	# anime
	draw_texture(Game.tex("soul"), Vector2(size.x - 50, size.y - 15), Color(1, 1, 1, 0.9))
	_txt("%d" % p.souls, Vector2(size.x - 38, size.y - 6), Color(0.62, 1.0, 0.86))
	if main.msg_t > 0.0 and main.state == "play":
		var ly := 96.0   # sotto l'obiettivo, sopra il personaggio
		for ln in _wrap(main.msg, 54).slice(0, 2):
			_txt(ln, Vector2(0, ly), Color(0.98, 0.88, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			ly += 10.0
	if main.prompt != "" and main.state == "play":
		_txt(main.prompt, Vector2(0, size.y - 68), Color(1, 0.92, 0.6), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if main.prompt2 != "":
			_txt(main.prompt2, Vector2(0, size.y - 58), Color(0.82, 0.8, 0.92), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if main.boss != null and main.boss.awake:
		var bx := size.x / 2 - 100
		_txt(main.boss.nm, Vector2(0, 21), Color(1, 0.82, 0.82), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_bar(Vector2(bx, 25), 200, 7, main.boss.hp / main.boss.max_hp, Color(0.7, 0.08, 0.14))
	if main.inv_open and main.state == "play":
		_inv(p)
	match main.state:
		"map":
			_map()
		"bestiary":
			_bestiary()
		"craft":
			_craft(p)
		"dialog":
			_dialog()
		"dying":
			var a: float = clamp((2.6 - main.death_t) / 1.2, 0.0, 1.0)
			draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0, 0.01, 0.78 * a))
			_txt("SEI MORTO", Vector2(0, 142), Color(0.85, 0.12, 0.16, a), 26, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		"win":
			draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.82))
			_txt("IL SIGNORE E' CADUTO", Vector2(0, 112), Color(1, 0.82, 0.3), 18, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			_txt("Nemici: %d    Livello: %d" % [p.kills, p.lv], Vector2(0, 138), Color.WHITE, 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
			if main.over_t <= 0.0:
				_txt("PREMI %s PER INIZIARE IL CICLO %d" % [_k("R", "A"), main.cycle + 2], Vector2(0, 168), Color(0.85, 0.8, 0.95), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
				_txt("Tieni livello e potenziamenti: mappa nuova, nemici piu' forti", Vector2(0, 182), Color(1, 0.7, 0.4), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		"pause":
			_pause()
		"debug":
			_debug()
		"options":
			_options()
		"controls":
			_controls()
		"menu":
			_menu(p)
		"travel":
			_travel()
		"pick":
			_pick(p)


# ---------------------------------------------------------------- pannelli
var td_ui: Dictionary = {}


## sprite dall'alto (usato dalla grafica 3D) se esiste, altrimenti nil
func _td_tex(name: String) -> Texture2D:
	if main.skin != null and is_instance_valid(main.skin) and ResourceLoader.exists("res://assets/topdown/%s.png" % name):
		if td_ui.has(name):
			return td_ui[name]
		var im: Image = (load("res://assets/topdown/%s.png" % name) as Texture2D).get_image()
		if im.is_compressed():
			im.decompress()
		im.convert(Image.FORMAT_RGBA8)
		var it := ImageTexture.create_from_image(im)
		td_ui[name] = it
		return it
	return null


func _ui_tex(name: String) -> Texture2D:
	var t := _td_tex(name)
	return t if t != null else Game.tex(name)


func _debug() -> void:
	var r := Rect2(110, 20, size.x - 220, size.y - 40)
	_frame(r, true, 0.95)
	_txt("DEBUG - SALTA A UN'AREA", Vector2(0, 28), GOLD_L, 11, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt("SU/GIU SCEGLI   INVIO VAI   F2 CHIUDI", Vector2(0, size.y - 34), Color(0.7, 0.7, 0.8), 8, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var n: int = main.debug_list.size()
	var first := clampi(main.debug_sel - 6, 0, maxi(0, n - 13))
	for i in range(first, mini(n, first + 13)):
		var y := 48.0 + (i - first) * 14.0
		var sel: bool = i == main.debug_sel
		if sel:
			draw_rect(Rect2(r.position.x + 8, y - 12, r.size.x - 16, 14), Color(0.4, 0.28, 0.1, 0.8))
		_txt(str(main.debug_list[i][1]), Vector2(r.position.x + 14, y), GOLD_L if sel else Color(0.75, 0.73, 0.85), 9)
		_txt(str(main.debug_list[i][0]).to_upper(), Vector2(r.end.x - 60, y), Color(0.55, 0.55, 0.7), 8)


func _menu(p: Player) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var r := Rect2(size.x / 2 - 150, 22, 300, 244)
	_panel(r)
	var x := r.position.x + 16
	var y := r.position.y
	_txt("ACCAMPAMENTO", Vector2(r.position.x, y + 26), Color(1, 0.78, 0.38), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_txt("Vita e fiale ripristinate.", Vector2(r.position.x, y + 40), Color(0.72, 0.68, 0.84), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_txt("I nemici sono tornati.", Vector2(r.position.x, y + 50), Color(0.72, 0.68, 0.84), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var c := Upgrades.cost(p.lv)
	var ok: bool = p.souls >= c
	_txt("Anime: %d" % p.souls, Vector2(x, y + 68), Color(0.62, 1, 0.86))
	_txt("Livello %d: %d anime" % [p.lv + 1, c], Vector2(x, y + 80), Color(1, 0.92, 0.5) if ok else Color(0.78, 0.4, 0.4))
	_txt(_k("INVIO", "A") + "  Sali di livello", Vector2(x, y + 96), Color(1, 1, 1) if ok else Color(0.5, 0.5, 0.58))
	_txt(_k("ESC / E", "B") + "  Lascia il campo      " + _k("C", "X") + "  Artigianato", Vector2(x, y + 107), Color(0.88, 0.88, 0.98))
	_txt(_k("T", "Y") + "  Viaggio rapido", Vector2(x, y + 118), Color(0.88, 0.88, 0.98))
	_txt(_k("Z/X", "LB/RB") + "  Magie: %s | %s" % [Rpg.SPELLS[p.spells[0]]["n"], Rpg.SPELLS[p.spells[1]]["n"]], Vector2(x, y + 129), Color(0.62, 0.82, 1.0))
	draw_rect(Rect2(x, y + 137, r.size.x - 32, 1), GOLD_D)
	_txt("ATTRIBUTI", Vector2(x, y + 149), GOLD_L)
	var yy := y + 161.0
	var col := 0
	for u in Stats.LIST:
		_txt("%s" % u["n"], Vector2(x + col * 140, yy), Color(0.88, 0.85, 0.98))
		_txt("%d" % p.a(u["id"]), Vector2(x + col * 140, yy), Color(0.62, 1.0, 0.86), 8, HORIZONTAL_ALIGNMENT_RIGHT, 124.0)
		col += 1
		if col == 2:
			col = 0
			yy += 10.0
	var gr := 0
	for u in Upgrades.LIST:
		gr += p.r(u["id"])
	yy += 14.0
	_txt("Danno arma %d   Critico %.0f%%   Grazie %d" % [int(round(p.dmg())), p.crit * 100.0, gr], Vector2(x, yy), Color(0.72, 0.68, 0.84))
	_txt("Livello %d" % p.lv, Vector2(r.position.x, r.end.y - 9), Color(0.6, 0.55, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## valori del personaggio da mostrare (per l'anteprima dell'attributo scelto)
func _sheet(p: Player) -> Array:
	return [
		["VITA", "%d" % int(p.max_hp)],
		["STAMINA", "%d" % int(p.max_st)],
		["MANA", "%d" % int(p.max_mana)],
		["DANNO ARMA", "%.1f" % p.dmg()],
		["POTERE MAGICO", "%d%%" % int(round(p.spell_pow() * 100.0))],
		["CRITICO", "%.1f%%" % (p.crit * 100.0)],
		["FIALE", "%d" % p.max_flasks],
	]


func _attr_pick(p: Player) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78))
	var c := Upgrades.cost(p.lv)
	_txt("LIVELLO %d  >  %d      COSTO %d ANIME      ANIME %d" % [p.lv, p.lv + 1, c, p.souls], Vector2(0, 30), Color(1, 0.82, 0.3), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for i in main.picks.size():
		var u: Dictionary = main.picks[i]
		var r := Rect2(20, 46 + i * 20, 280, 18)
		_frame(r, i == main.pick_sel, 0.97)
		var v := p.a(u["id"])
		_txt("%d  %s" % [i + 1, u["n"]], Vector2(r.position.x + 8, r.position.y + 12), Color(1, 0.86, 0.5) if i == main.pick_sel else Color(0.86, 0.84, 0.95))
		_txt("%d  >  %d" % [v, v + 1], Vector2(r.position.x, r.position.y + 12), Color(0.62, 1.0, 0.86) if i == main.pick_sel else Color(0.7, 0.7, 0.8), 8, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
	if main.picks.is_empty():
		return
	var sel: Dictionary = main.picks[clampi(main.pick_sel, 0, main.picks.size() - 1)]
	var pr := Rect2(310, 46, 154, 196)
	_panel(pr)
	_txt(sel["n"], Vector2(pr.position.x, pr.position.y + 14), GOLD_L, 9, HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	var ly := pr.position.y + 28.0
	for ln in _wrap(sel["d"], 26):
		_txt(ln, Vector2(pr.position.x + 8, ly), Color(0.86, 0.86, 0.96))
		ly += 9.0
	# anteprima: valori attuali e dopo il punto
	var before := _sheet(p)
	var id: String = sel["id"]
	p.attr[id] = p.a(id) + 1
	p.apply_stats()
	var after := _sheet(p)
	p.attr[id] = p.a(id) - 1
	if p.a(id) <= 0:
		p.attr.erase(id)
	p.apply_stats()
	ly = maxf(ly + 4.0, pr.position.y + 100.0)
	draw_rect(Rect2(pr.position.x + 8, ly - 7, pr.size.x - 16, 1), GOLD_D)
	for k in before.size():
		var changed: bool = before[k][1] != after[k][1]
		_txt(before[k][0], Vector2(pr.position.x + 8, ly + 4), Color(0.7, 0.68, 0.82))
		_txt(before[k][1] + ("  >  " + after[k][1] if changed else ""), Vector2(pr.position.x, ly + 4),
			Color(0.62, 1.0, 0.86) if changed else Color(0.86, 0.86, 0.96), 8, HORIZONTAL_ALIGNMENT_RIGHT, pr.size.x - 8)
		ly += 11.0
	_txt(_k("SU/GIU + INVIO  oppure  1-7", "SU/GIU  +  A"), Vector2(0, size.y - 22), Color(0.8, 0.78, 0.9), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt(_k("ESC", "B") + "  indietro", Vector2(0, size.y - 11), Color(0.65, 0.65, 0.75), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _pick(p: Player) -> void:
	if not main.run_mode:
		_attr_pick(p)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	_txt("SCEGLI UN POTENZIAMENTO", Vector2(0, 36), Color(1, 0.82, 0.3), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for i in main.picks.size():
		var u: Dictionary = main.picks[i]
		var r := Rect2(14 + i * 154, 52, 146, 150)
		_frame(r, i == main.pick_sel, 0.97)
		_txt("%d" % (i + 1), Vector2(r.position.x, r.position.y + 28), Color(1, 1, 1), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		_txt(u["n"], Vector2(r.position.x, r.position.y + 50), Color(1, 0.86, 0.5), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_rect(Rect2(r.position.x + 14, r.position.y + 56, r.size.x - 28, 1), GOLD_D)
		var ly := r.position.y + 70.0
		for ln in _wrap(u["d"], 20):
			_txt(ln, Vector2(r.position.x, ly), Color(0.88, 0.88, 0.98), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			ly += 10.0
		_txt("grado %d / %d" % [main.pick_rank(u) if main.run_mode else p.r(u["id"]) + 1, u["max"]], Vector2(r.position.x, r.end.y - 11), Color(0.65, 0.6, 0.78), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	_txt(_k("1 2 3  oppure  SINISTRA/DESTRA + INVIO", "SINISTRA/DESTRA  +  A"), Vector2(0, size.y - 26), Color(0.8, 0.78, 0.9), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt(_k("ESC", "B") + "  indietro", Vector2(0, size.y - 14), Color(0.65, 0.65, 0.75), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _edge_markers() -> void:
	if main.state != "play":
		return
	var n := 0
	for tg in main.obj_targets():
		if n >= 3:
			break
		_edge_arrow(tg["p"] as Vector2, tg["c"] as Color)
		n += 1
	if main.area == "world" and main.ev_chest != null:
		_edge_arrow(main.ev_pos, Color(0.4, 0.9, 1.0))


## freccia sul bordo dello schermo verso un bersaglio fuori inquadratura, con la distanza in celle
func _edge_arrow(wp: Vector2, col: Color) -> void:
	var sp: Vector2 = main.get_canvas_transform() * wp
	var inner := Rect2(10, 10, size.x - 20, size.y - 20)
	if inner.has_point(sp):
		if wp.distance_to(main.player.position) > 36.0:
			var bob := sin(Time.get_ticks_msec() / 180.0) * 2.0
			var m := sp + Vector2(0, -22 + bob)
			var dia := PackedVector2Array([m + Vector2(0, -4), m + Vector2(3, 0), m + Vector2(0, 4), m + Vector2(-3, 0)])
			var big := PackedVector2Array([m + Vector2(0, -6), m + Vector2(5, 0), m + Vector2(0, 6), m + Vector2(-5, 0)])
			draw_colored_polygon(big, OUTLINE)
			draw_colored_polygon(dia, col)
		return
	var cen := size / 2.0
	var dv := sp - cen
	if dv.length() < 1.0:
		return
	var dir := dv.normalized()
	var tx := (size.x / 2.0 - 14.0) / maxf(absf(dir.x), 0.001)
	var ty := (size.y / 2.0 - 14.0) / maxf(absf(dir.y), 0.001)
	var pt := cen + dir * minf(tx, ty)
	var perp := Vector2(-dir.y, dir.x)
	var a := pt + dir * 6.0
	var b := pt + perp * 4.0 - dir * 3.0
	var c := pt - perp * 4.0 - dir * 3.0
	var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() / 250.0)
	draw_colored_polygon(PackedVector2Array([a + dir * 1.5, b + perp * 1.5, c - perp * 1.5]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([a, b, c]), Color(col.r, col.g, col.b, pulse))
	var dist := int(wp.distance_to(main.player.position) / 16.0)
	var lbl := "%d" % dist
	var lp := pt - dir * 12.0 - Vector2(font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8)).x / 2.0, -3.0)
	_txt(lbl, lp, Color(col.r, col.g, col.b, 0.9))


func _clock() -> void:
	if main.area != "world":
		return
	var nm: String = main.day_name()
	var col := Color(0.95, 0.85, 0.55) if nm == "GIORNO" else (Color(1.0, 0.7, 0.5) if nm == "TRAMONTO" or nm == "ALBA" else Color(0.6, 0.7, 1.0))
	var w := ""
	if main.weather == "rain":
		w = "  PIOGGIA"
	elif main.weather == "snow":
		w = "  NEVE"
	_txt("%s  %s%s" % [main.day_clock(), nm, w], Vector2(0, 70), col, 9, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6)


var _obj_last := ""
var _obj_t := 0.0
var _mat_sig := ""
var _mat_t := 0.0


func _minimap() -> void:
	if main.mm_tex == null:
		return
	var W: int = Game.MW
	var H: int = Game.MH
	var cw := mini(70, W)
	var ch := mini(50, H)
	var pc := Vector2i(floori(main.player.position.x / Game.TS), floori(main.player.position.y / Game.TS))
	var ox := clampi(pc.x - cw / 2, 0, W - cw)
	var oy := clampi(pc.y - ch / 2, 0, H - ch)
	var sc := 1.0
	var dst := Rect2(int(size.x - cw * sc - 6), 6, int(cw * sc), int(ch * sc))
	_frame(dst.grow(4), true, 0.9)
	if main.mm3d != null and main.area == "world":
		draw_texture_rect(main.mm3d, dst, false)
	else:
		draw_texture_rect_region(main.mm_tex, dst, Rect2(ox, oy, cw, ch))
	for pr in main.props:
		var cc: Vector2i = pr.cell
		if cc.x < ox or cc.y < oy or cc.x >= ox + cw or cc.y >= oy + ch:
			continue
		if main.seen.size() == 0 or main.seen[cc.y * W + cc.x] == 0:
			continue
		var pos := (dst.position + (Vector2(cc) - Vector2(ox, oy)) * sc).floor()
		if pr.kind == "bonfire":
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.62, 0.2) if pr.lit else Color(0.5, 0.5, 0.85))
		elif pr.kind == "portal":
			draw_rect(Rect2(pos - Vector2(1, 1), Vector2(3, 3)), Color(0.85, 0.45, 1.0))
		elif pr.kind == "npc":
			draw_rect(Rect2(pos, Vector2(2, 2)), Color(0.4, 1.0, 0.6))
	for tg in main.obj_targets():
		var tw: Vector2 = tg["p"]
		var jc := Vector2(floori(tw.x / Game.TS), floori(tw.y / Game.TS))
		var jp := (dst.position + (jc - Vector2(ox, oy)) * sc).floor()
		jp = Vector2(clampf(jp.x, dst.position.x + 2, dst.end.x - 3), clampf(jp.y, dst.position.y + 2, dst.end.y - 3))
		if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.65:
			draw_rect(Rect2(jp - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
			draw_rect(Rect2(jp - Vector2(1, 1), Vector2(3, 3)), tg["c"] as Color)
	if main.ev_chest != null:
		var ec := Vector2(floori(main.ev_pos.x / Game.TS), floori(main.ev_pos.y / Game.TS))
		var ep := (dst.position + (ec - Vector2(ox, oy)) * sc).floor()
		ep = Vector2(clampf(ep.x, dst.position.x + 2, dst.end.x - 3), clampf(ep.y, dst.position.y + 2, dst.end.y - 3))
		draw_rect(Rect2(ep - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
		draw_rect(Rect2(ep - Vector2(1, 1), Vector2(3, 3)), Color(0.4, 0.9, 1.0))
	var pp := (dst.position + (Vector2(pc) - Vector2(ox, oy)) * sc).floor()
	draw_rect(Rect2(pp - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
	draw_rect(Rect2(pp - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 1))


## BESTIARIO: griglia dei nemici (sagome scure se non ancora incontrati) e scheda del selezionato
func _bestiary() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.95))
	var book: Dictionary = main.persist.get("bestiary", {})
	var E: Array = Bestiary.ENTRIES
	var found := 0
	for en in E:
		if book.has(en[0]):
			found += 1
	_txt("BESTIARIO", Vector2(14, 18), Color(1, 0.82, 0.4), 9)
	_txt("SCOPERTI %d / %d" % [found, E.size()], Vector2(0, 18), Color(0.75, 0.7, 0.85), 9, HORIZONTAL_ALIGNMENT_RIGHT, 228)
	for i in E.size():
		var cell := Rect2(14 + (i % 8) * 27, 34 + (i / 8) * 27, 25, 25)
		var sel: bool = i == main.beast_sel
		draw_rect(cell, Color(0.10, 0.08, 0.14) if not sel else Color(0.28, 0.2, 0.1))
		draw_rect(cell, GOLD if sel else GOLD_D, false, 1.0)
		var st: Dictionary = Bestiary.stats(E[i][0])
		if st.is_empty():
			continue
		var t: Texture2D = _ui_tex(str(st["spr"]))
		var k := minf(1.0, 21.0 / maxf(t.get_width(), t.get_height()))
		var sz := Vector2(t.get_width(), t.get_height()) * k
		draw_texture_rect(t, Rect2(cell.position + (cell.size - sz) / 2.0, sz), false,
			Color.WHITE if book.has(E[i][0]) else Color(0, 0, 0, 0.85))
	# scheda
	var en: Array = E[main.beast_sel]
	var known: bool = book.has(en[0])
	var r := Rect2(244, 30, size.x - 256, size.y - 50)
	_frame(r, true, 0.92)
	var st2: Dictionary = Bestiary.stats(en[0])
	if not st2.is_empty():
		var t2: Texture2D = _ui_tex(str(st2["spr"]))
		var k2 := minf(3.0, 64.0 / maxf(t2.get_width(), t2.get_height()))
		var sz2 := Vector2(t2.get_width(), t2.get_height()) * k2
		draw_texture_rect(t2, Rect2(Vector2(r.position.x + r.size.x / 2.0 - sz2.x / 2.0, r.position.y + 8), sz2), false,
			Color.WHITE if known else Color(0, 0, 0, 0.9))
	var y := r.position.y + 80.0
	_txt(str(en[1]) if known else "???", Vector2(r.position.x, y), Color(1, 0.86, 0.5), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	y += 13.0
	if not known:
		_txt("NON ANCORA INCONTRATO", Vector2(r.position.x, y), Color(0.6, 0.58, 0.7), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	for ln in _wrap(str(en[2]), 34):
		_txt(ln, Vector2(r.position.x + 8, y), Color(0.86, 0.84, 0.95))
		y += 9.5
	y += 4.0
	_txt("DOVE: " + str(en[3]), Vector2(r.position.x + 8, y), Color(0.7, 0.85, 1.0))
	y += 12.0
	var lines := [
		["VITA", "%d" % int(st2["hp"])], ["DANNO", "%d" % int(st2["dmg"])], ["VELOCITA'", Bestiary.speed_txt(float(st2["spd"]))],
		["STILE", str(Bestiary.AI_TXT.get(str(st2["ai"]), ""))], ["ANIME", "%d" % int(st2["souls"])], ["UCCISI", "%d" % int(book[en[0]])]]
	for ln2 in lines:
		_txt(str(ln2[0]), Vector2(r.position.x + 8, y), Color(0.75, 0.7, 0.85))
		_txt(str(ln2[1]), Vector2(r.position.x + 8, y), Color(0.95, 0.92, 0.8), 9, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 16)
		y += 10.0
	_txt(_k("FRECCE SCEGLI   B / ESC CHIUDI", "CROCE SCEGLI   B CHIUDI"), Vector2(0, size.y - 8), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


## MAPPA: solo le zone gia' esplorate; intera oppure ingrandita attorno al giocatore (si scorre col movimento)
func _map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.01, 0.04, 0.95))
	var W: int = Game.MW
	var H: int = Game.MH
	var box := Rect2(14, 24, size.x - 28, size.y - 50)
	var title := "MAPPA DEL MONDO" if main.area == "world" else (str(main.dun["n"]) if main.dun.has("n") else "MAPPA")
	_txt(title, Vector2(0, 16), Color(1, 0.82, 0.4), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var pc: Vector2 = main.player.position / Game.TS
	var fit := minf(box.size.x / W, box.size.y / H)
	var sc := fit
	var src := Rect2(0, 0, W, H)
	if main.map_zoom == 1:
		sc = maxf(1.0, fit * 3.0)
		var vw := box.size / sc
		var cen: Vector2 = pc + main.map_pan / sc
		cen.x = clampf(cen.x, vw.x / 2.0, maxf(vw.x / 2.0, W - vw.x / 2.0))
		cen.y = clampf(cen.y, vw.y / 2.0, maxf(vw.y / 2.0, H - vw.y / 2.0))
		main.map_pan = (cen - pc) * sc
		src = Rect2(cen - vw / 2.0, vw).intersection(Rect2(0, 0, W, H))
	var dst := Rect2(box.position + (box.size - src.size * sc) / 2.0, src.size * sc)
	_frame(dst.grow(4), true, 0.9)
	draw_rect(dst, Color(0.05, 0.04, 0.07))
	draw_texture_rect_region(main.mm_tex, dst, src)
	var to_s := func(cell: Vector2) -> Vector2:
		return (dst.position + (cell - src.position) * sc).floor()
	var inside := func(v: Vector2) -> bool:
		return dst.grow(-1).has_point(v)
	var seen_at := func(c: Vector2i) -> bool:
		if c.x < 0 or c.y < 0 or c.x >= W or c.y >= H or main.seen.size() != W * H:
			return false
		return main.seen[c.y * W + c.x] != 0
	if main.area == "world":
		# nomi delle regioni gia' visitate
		for i in main.SEEDS.size():
			var sd: Vector2i = main.SEEDS[i]
			var bi: int = main.biome_at(sd.x, sd.y)
			if seen_at.call(sd):
				var sp: Vector2 = to_s.call(Vector2(sd))
				if inside.call(sp):
					var nm := str(Game.BIO[bi]["n"])
					_txt(nm, sp + Vector2(-font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8)).x / 2.0, 0), Color(0.86, 0.82, 0.95, 0.85))
		# ingressi dei dungeon scoperti
		for g in main.ENTR:
			var gc: Vector2i = main.ENTR[g]
			if seen_at.call(gc):
				var gp: Vector2 = to_s.call(Vector2(gc))
				if inside.call(gp):
					draw_rect(Rect2(gp - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
					draw_rect(Rect2(gp - Vector2(1, 1), Vector2(3, 3)), Color(0.85, 0.45, 1.0))
					if main.map_zoom == 1 and main.DUNS.has(g):
						_map_label(str(main.DUNS[g]["n"]), gp, Color(0.85, 0.65, 1.0), dst)
		# falo' accesi (viaggio rapido)
		for k in main.persist["fires"].keys():
			var ks := str(k)
			if not ks.begins_with("world:"):
				continue
			var xy := ks.substr(6).split(",")
			var fp: Vector2 = to_s.call(Vector2(int(xy[0]), int(xy[1])))
			if inside.call(fp):
				draw_rect(Rect2(fp - Vector2(2, 2), Vector2(4, 4)), OUTLINE)
				draw_rect(Rect2(fp - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.62, 0.2))
	# obiettivi: sempre visibili (anche in zone non ancora esplorate), bloccati al bordo della mappa
	var blink := fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.7
	for tg in main.obj_targets():
		var tp: Vector2 = to_s.call((tg["p"] as Vector2) / Game.TS)
		tp = Vector2(clampf(tp.x, dst.position.x + 3, dst.end.x - 4), clampf(tp.y, dst.position.y + 3, dst.end.y - 4))
		var c: Color = tg["c"]
		var dia := PackedVector2Array([tp + Vector2(0, -4), tp + Vector2(4, 0), tp + Vector2(0, 4), tp + Vector2(-4, 0)])
		draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -6), tp + Vector2(6, 0), tp + Vector2(0, 6), tp + Vector2(-6, 0)]), OUTLINE)
		draw_colored_polygon(dia, c if blink else c.darkened(0.4))
		if main.map_zoom == 1:
			var lbl := str(tg["n"])
			if lbl.length() > 26:
				lbl = lbl.substr(0, 26) + "..."
			_map_label(lbl, tp, c, dst)
	var pp: Vector2 = to_s.call(pc)
	if inside.call(pp):
		draw_rect(Rect2(pp - Vector2(3, 3), Vector2(7, 7)), OUTLINE)
		draw_rect(Rect2(pp - Vector2(2, 2), Vector2(5, 5)), Color(1, 1, 1) if blink else Color(0.7, 0.9, 1.0))
	# legenda
	var ly := size.y - 14.0
	draw_rect(Rect2(14, ly - 6, 5, 5), Color(1.0, 0.85, 0.25))
	_txt("OBIETTIVO", Vector2(22, ly), Color(0.85, 0.8, 0.7))
	draw_rect(Rect2(80, ly - 6, 5, 5), Color(0.45, 1.0, 0.7))
	_txt("MISSIONI", Vector2(88, ly), Color(0.85, 0.8, 0.7))
	draw_rect(Rect2(140, ly - 6, 5, 5), Color(1.0, 0.62, 0.2))
	_txt("FALO'", Vector2(148, ly), Color(0.85, 0.8, 0.7))
	draw_rect(Rect2(180, ly - 6, 5, 5), Color(0.85, 0.45, 1.0))
	_txt("INGRESSI", Vector2(188, ly), Color(0.85, 0.8, 0.7))
	_txt(_k("E INGRANDISCI   WASD SCORRI   M CHIUDI", "A INGRANDISCI   STICK SCORRI   B CHIUDI"), Vector2(0, ly), Color(0.65, 0.65, 0.75), 9, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14)


## scritta accanto a un segno della mappa: a destra, oppure a sinistra se uscirebbe dal riquadro
func _map_label(t: String, at: Vector2, col: Color, box: Rect2) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, _fs(8)).x
	var x := at.x + 7.0
	if x + w > box.end.x - 2.0:
		x = at.x - 7.0 - w
	_txt(t, Vector2(x, clampf(at.y + 3.0, box.position.y + 8.0, box.end.y - 2.0)), col)


func _travel() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	var r := Rect2(size.x / 2 - 150, 24, 300, 222)
	_panel(r)
	_txt("VIAGGIO RAPIDO", Vector2(r.position.x, r.position.y + 28), Color(1, 0.82, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var n: int = main.travel_list.size()
	var first := clampi(main.travel_sel - 6, 0, maxi(0, n - 12))
	for k in range(first, mini(n, first + 12)):
		var y := r.position.y + 54.0 + (k - first) * 12.0
		var sel: bool = k == main.travel_sel
		_txt(("> " if sel else "  ") + main.travel_label(main.travel_list[k]), Vector2(r.position.x + 18, y),
			Color(1, 0.92, 0.5) if sel else Color(0.78, 0.74, 0.88))
	_txt(_k("SU/GIU scegli  INVIO viaggia  ESC indietro", "SU/GIU scegli  A viaggia  B indietro"), Vector2(r.position.x, r.end.y - 10), Color(0.65, 0.65, 0.75), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _title() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 1.0))
	_txt("CRYPT OF EMBERS", Vector2(0, 96), Color(1, 0.72, 0.3), 24, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	draw_rect(Rect2(size.x / 2 - 130, 108, 260, 1), GOLD_D)
	var opts := ["CONTINUA", "NUOVA PARTITA", "IMPOSTAZIONI"]
	if main.run_mode:
		opts = ["NUOVA PARTITA", "IMPOSTAZIONI", "ESCI"]
	if not main.run_mode:
		opts.append("EDITOR (SVILUPPO)")
	for i in opts.size():
		var sel: bool = i == main.title_sel
		_txt(("> " if sel else "  ") + opts[i], Vector2(0, 144 + i * 16), Color(1, 0.92, 0.5) if sel else Color(0.72, 0.7, 0.82), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var s: Dictionary = main.title_save
	if main.run_mode:
		var bt := int(main.meta["best"])
		_txt("Ceneri %d     Partite %d     Record %d:%02d" % [int(main.meta["ceneri"]), int(main.meta["runs"]), bt / 60, bt % 60],
			Vector2(0, 204), Color(0.64, 0.62, 0.76), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	elif not s.is_empty():
		var pd: Dictionary = s["player"]
		_txt("Livello %d   Ciclo %d   Diari %d" % [int(pd["lv"]), int(s.get("cycle", 0)) + 1, int(s.get("pages", 0))],
			Vector2(0, 204), Color(0.64, 0.62, 0.76), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt("F11  Schermo intero", Vector2(0, 236), Color(0.55, 0.55, 0.65), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	_txt(_k("SU/GIU scegli    INVIO conferma", "SU/GIU scegli    A conferma"), Vector2(0, 252), Color(0.55, 0.55, 0.65), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _spirit_row(p: Player) -> void:
	var x := size.x - 18.0
	var y := size.y - 32.0
	for sp in p.spirits:
		var d: Dictionary = Spirit.DATA[sp["k"]]
		draw_texture_rect(Game.tex(str(d["spr"])), Rect2(x, y, 12, 12), false, Color(0.6, 1.0, 1.4, 0.85))
		_txt("%d" % int(sp["lv"]), Vector2(x + 8, y + 13), Color(0.7, 1.0, 1.0, 0.85))
		x -= 16.0


func _craft(p: Player) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.74))
	var r := Rect2(size.x / 2 - 170, 14, 340, 246)
	_panel(r)
	_txt("FORGIA", Vector2(r.position.x, r.position.y + 20), Color(1, 0.78, 0.38), 12, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x := r.position.x + 14
	var mx := x
	for mid in main.MAT_ORDER:
		draw_texture(Game.tex("mat_" + str(mid)) if mid in ["pelle", "carne", "osso"] else Game.tex("res_" + str(mid)), Vector2(mx, r.position.y + 26), Color.WHITE)
		_txt("%d" % int(p.mats.get(mid, 0)), Vector2(mx + 13, r.position.y + 38), Color(0.9, 0.95, 0.8))
		mx += 46.0
	# schede
	var ty := r.position.y + 66.0
	for i in Forge.TABS.size():
		var on: bool = i == main.craft_tab
		var tx := r.position.x + 14 + i * 62.0
		if on:
			draw_rect(Rect2(tx - 2, ty - 10, 60, 13), Color(0.35, 0.22, 0.08, 0.9 if main.craft_row == 0 else 0.55))
		_txt(Forge.TABS[i], Vector2(tx, ty), GOLD_L if on else Color(0.6, 0.58, 0.7), 8, HORIZONTAL_ALIGNMENT_CENTER, 56)
	draw_rect(Rect2(x, ty + 5, r.size.x - 28, 1), GOLD_D)
	# scelte (sinistra)
	var sl: Array = Forge.slots(main.craft_tab)
	var ids: Array = main.craft_ids()
	var y := r.position.y + 82.0
	for i in sl.size():
		var sel: bool = main.craft_row == i + 1
		var opts: Array = sl[i][1]
		var vi: int = clampi(int(main.craft_vals[main.craft_tab][i]), 0, opts.size() - 1)
		var dim: bool = main.craft_tab == 1 and i == 1 and str(ids[0]) != "infondi"
		if sel:
			draw_rect(Rect2(x - 3, y - 9, 168, 12), Color(0.3, 0.2, 0.08, 0.8))
		_txt(str(sl[i][0]), Vector2(x, y), Color(0.7, 0.68, 0.82) if not dim else Color(0.4, 0.4, 0.48))
		var val := str(opts[vi][1])
		_txt(("< %s >" % val) if sel else val, Vector2(x + 66, y), (Color(1, 0.92, 0.5) if sel else Color(0.92, 0.9, 1.0)) if not dim else Color(0.4, 0.4, 0.48), 8, HORIZONTAL_ALIGNMENT_CENTER, 100)
		y += 14.0
	var pv: Dictionary = main.craft_preview()
	var cost: Dictionary = pv["cost"]
	var ok: bool = main.craft_afford(cost) and str(pv.get("err", "")) == ""
	var csel: bool = main.craft_row == sl.size() + 1
	y += 4.0
	_frame(Rect2(x, y - 9, 162, 14), csel, 0.9)
	_txt("CREA" if ok else "CREA (MANCANO MATERIALI)", Vector2(x, y + 1), (Color(1, 0.92, 0.5) if ok else Color(0.8, 0.45, 0.45)) if csel else (Color(0.85, 0.85, 0.95) if ok else Color(0.6, 0.4, 0.4)), 8, HORIZONTAL_ALIGNMENT_CENTER, 162)
	# costo
	y += 20.0
	_txt("COSTO", Vector2(x, y), GOLD_L)
	y += 10.0
	var col := 0
	for k in cost:
		var have := int(p.mats.get(k, 0))
		var need := int(cost[k])
		_txt("%d %s" % [need, str(main.MAT_NAMES[k])], Vector2(x + col * 82, y), Color(0.75, 0.9, 0.7) if have >= need else Color(0.9, 0.45, 0.45))
		col += 1
		if col == 2:
			col = 0
			y += 10.0
	if cost.is_empty():
		_txt("NESSUNO", Vector2(x, y), Color(0.6, 0.6, 0.7))
	# anteprima (destra)
	var rx := r.position.x + 188
	var ry := r.position.y + 82.0
	draw_rect(Rect2(rx - 8, ry - 10, 1, 160), GOLD_D)
	var lines: Array = pv["lines"]
	for li in lines.size():
		for ln in _wrap(str(lines[li]), 24):
			if ry > r.end.y - 22:
				break
			_txt(ln, Vector2(rx, ry), GOLD_L if li == 0 else Color(0.86, 0.86, 0.96))
			ry += 10.0
	if str(pv.get("err", "")) != "":
		_txt(str(pv["err"]), Vector2(rx, ry + 4), Color(0.9, 0.45, 0.45))
	if main.craft_tab == 2 and p.armor.size() > 0:
		ry += 6.0
		_txt("INDOSSATI: %d / 3" % p.armor.size(), Vector2(rx, ry), Color(0.6, 0.8, 1.0))
	_txt(_k("Q/E SCHEDA  SU/GIU RIGA  SIN/DES SCEGLI  INVIO CREA", "LB/RB SCHEDA  SU/GIU  SIN/DES  A CREA  B ESCI"), Vector2(r.position.x, r.end.y - 6), Color(0.6, 0.58, 0.72), 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


# ---------------------------------------------------------------- borsa ed equipaggiamento
const ARM_COL := {"pelle": Color(0.78, 0.56, 0.36), "osso": Color(0.92, 0.9, 0.78), "minerale": Color(0.72, 0.78, 0.9), "legna": Color(0.62, 0.44, 0.28)}
const BREW_COL := {"erba": Color(0.5, 1.0, 0.55), "carne": Color(1.0, 0.45, 0.45), "fungo": Color(0.6, 0.6, 1.2), "osso": Color(1.0, 0.95, 0.8)}
const QCOL := [Color(0.78, 0.78, 0.84), Color(0.78, 0.78, 0.84), Color(0.4, 0.65, 1.0), Color(0.4, 0.65, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.75, 0.25)]


## posizioni condivise fra disegno e clic: slot del personaggio, schede, caselle della borsa
func inv_layout() -> Dictionary:
	var lx := 14.0
	var slots: Array = [Rect2(lx + 4, 40, 22, 22), Rect2(lx + 4, 68, 22, 22),
		Rect2(lx + 122, 30, 22, 22), Rect2(lx + 122, 56, 22, 22), Rect2(lx + 122, 82, 22, 22)]
	for i in 4:
		slots.append(Rect2(lx + 4 + i * 26, 124, 22, 22))
	for i in 3:
		slots.append(Rect2(lx + 4 + i * 26, 220, 22, 22))
	var bx := lx + 170.0
	var tabs: Array = []
	for i in main.INV_TABS.size():
		tabs.append(Rect2(bx + i * 47.0 - 2, 11, 45, 12))
	var cells: Array = []
	for i in 36:
		cells.append(Rect2(bx + (i % 12) * 23.0, 28 + (i / 12) * 23.0, 21, 21))
	return {"lx": lx, "bx": bx, "slots": slots, "tabs": tabs, "cells": cells}


func inv_hit(pos: Vector2) -> Array:
	var L := inv_layout()
	for i in (L["tabs"] as Array).size():
		if (L["tabs"][i] as Rect2).has_point(pos):
			return ["tab", i]
	for i in (L["slots"] as Array).size():
		if (L["slots"][i] as Rect2).grow(1).has_point(pos):
			return ["slot", i]
	for i in (L["cells"] as Array).size():
		if (L["cells"][i] as Rect2).has_point(pos):
			return ["cell", i]
	return []


func _icon(e: Dictionary, r: Rect2, a := 1.0) -> void:
	match str(e["k"]):
		"w":
			draw_texture_rect(Game.tex(Rpg.wicon(e["w"])), r, false, Color(1, 1, 1, a))
		"a":
			draw_texture_rect(Game.tex("ai_" + str(e["a"]["slot"])), r, false, ARM_COL.get(str(e["a"].get("m", "pelle")), Color.WHITE) * Color(1, 1, 1, a))
		"b":
			if str(e["id"]).begins_with("b:chrono:"):
				draw_texture_rect(Game.tex("ch_" + str(e["id"]).substr(9)), r, false, Color(1, 1, 1, a))
				return
			draw_texture_rect(Game.tex("flask"), r, false, BREW_COL.get(main.brew_base(str(e["id"])), Color.WHITE) * Color(1, 1, 1, a))
		"m":
			var mid := str(e["id"])
			draw_texture_rect(Game.tex("mat_" + mid) if mid in ["pelle", "carne", "osso"] else Game.tex("res_" + mid), r, false, Color(1, 1, 1, a))
		"r":
			draw_texture_rect(Game.tex("relic_" + str(e["id"])), r, false, Color(1, 1, 1, a))


func _rcol(e: Dictionary) -> Color:
	match str(e["k"]):
		"w":
			return Rpg.RARITY[int(e["w"]["r"])]["c"]
		"a":
			return QCOL[clampi(int(e["a"].get("q", 1)), 0, 5)]
		"r":
			return Color(1.0, 0.75, 0.25)
	return Color(0.86, 0.86, 0.96)


func _slot(r: Rect2, label: String, e, sel := false) -> void:
	draw_rect(r.grow(1), OUTLINE)
	draw_rect(r, Color(0.09, 0.06, 0.13, 0.95))
	if e == null:
		_txt(label, Vector2(r.position.x, r.position.y + r.size.y / 2 + 3), Color(0.36, 0.33, 0.45), 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	else:
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), _rcol(e) * Color(1, 1, 1, 0.8))
		_icon(e, Rect2(r.position + (r.size - Vector2(16, 16)) / 2, Vector2(16, 16)))
		if e.has("n") and str(e["k"]) == "b":
			_txt("%d" % int(e["n"]), Vector2(r.position.x + 14, r.end.y - 1), Color(1, 0.9, 0.6))
	if sel:
		draw_rect(r.grow(2), GOLD_L, false, 1.0)


func _inv(p: Player) -> void:
	var L := inv_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.0, 0.03, 0.72))   # il mondo resta visibile: non e' una pausa
	var r := Rect2(6, 6, size.x - 12, size.y - 12)
	_panel(r)
	var lx: float = L["lx"]
	var sl: Array = L["slots"]
	var s0: bool = main.inv_side == 0
	# ---- personaggio
	_txt("EQUIPAGGIAMENTO", Vector2(lx, 18), GOLD_L)
	var cx := lx + 74.0
	var td_hero: Texture2D = _td_tex(str(Rpg.CLASSES[p.cls]["spr"]))
	if td_hero != null:
		# con la grafica 3D il personaggio e' mostrato come in gioco (visto dall'alto, con la sua arma)
		draw_texture_rect(td_hero, Rect2(cx - 40, 24, 80, 80), false)
	else:
		draw_texture_rect(Game.tex(str(Rpg.CLASSES[p.cls]["spr"]) + "_b"), Rect2(cx - 30, 34, 60, 60), false)
		draw_set_transform(Vector2(cx + 16, 73), 0.18, Vector2(2.4, 2.4))
		draw_texture(Game.tex(str(p.weapon().get("hs", "hw_" + str(p.weapon()["f"])))), Vector2(-12, -18))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var labels := ["ARMA", "ARMA", "ELMO", "TORSO", "GAMBE", "-", "-", "-", "-", "-", "-", "-"]
	for i in 12:
		_slot(sl[i], labels[i], main.inv_slot_entry(i), s0 and main.inv_slot == i)
	_txt("1" if p.wcur != 0 else ">", Vector2(lx - 4, 54), Color(0.6, 0.58, 0.7) if p.wcur != 0 else GOLD_L)
	_txt("2" if p.wcur != 1 else ">", Vector2(lx - 4, 82), Color(0.6, 0.58, 0.7) if p.wcur != 1 else GOLD_L)
	_txt("CINTURA  (Z / X)", Vector2(lx, 119), Color(0.7, 0.68, 0.82))
	_txt("RELIQUIE  (MAX 3)", Vector2(lx, 215), Color(0.7, 0.68, 0.82))
	var sy := 160.0
	draw_rect(Rect2(lx, sy - 6, 150, 1), GOLD_D)
	var stats: Array = [["VITA", "%d" % int(p.max_hp)], ["STAMINA", "%d" % int(p.max_st)], ["MANA", "%d" % int(p.max_mana)],
		["DIFESA", "%d%%" % int(round(p.arm("df") * 100.0))], ["DANNO", "%.1f" % p.dmg()], ["CRITICO", "%.0f%%" % (p.crit * 100.0)],
		["VELOCITA'", "%+d%%" % int(round(p.arm("mv") * 100.0))], ["SPINE", "%d%%" % int(round(p.arm("th") * 100.0))]]
	for i in stats.size():
		var px := lx + (i % 2) * 78.0
		_txt(stats[i][0], Vector2(px, sy + 4 + (i / 2) * 11), Color(0.66, 0.64, 0.78))
		_txt(stats[i][1], Vector2(px, sy + 4 + (i / 2) * 11), Color(0.92, 0.92, 1.0), 8, HORIZONTAL_ALIGNMENT_RIGHT, 72)
	draw_rect(Rect2(lx + 160, r.position.y + 6, 1, r.size.y - 12), GOLD_D)
	# ---- borsa
	var bx: float = L["bx"]
	for i in main.INV_TABS.size():
		var tr: Rect2 = L["tabs"][i]
		var on: bool = i == main.inv_tab
		if on:
			draw_rect(tr, Color(0.35, 0.22, 0.08, 0.9))
		_txt(main.INV_TABS[i], Vector2(tr.position.x, tr.position.y + 9), GOLD_L if on else Color(0.6, 0.58, 0.7), 8, HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)
	var lst: Array = main.inv_list(main.inv_tab)
	for i in 36:
		var cr: Rect2 = L["cells"][i]
		var li: int = i + main.inv_scroll * 12
		draw_rect(cr, Color(0.07, 0.05, 0.11, 0.9))
		draw_rect(cr, Color(0.25, 0.19, 0.3, 0.8), false, 1.0)
		if li < lst.size():
			var e: Dictionary = lst[li]
			draw_rect(Rect2(cr.position.x, cr.end.y - 2, cr.size.x, 2), _rcol(e) * Color(1, 1, 1, 0.7))
			_icon(e, Rect2(cr.position + Vector2(2.5, 2), Vector2(16, 16)), 0.55 if str(e["k"]) == "m" else 1.0)
			if e.has("n") and int(e["n"]) > 1:
				_txt("%d" % int(e["n"]), Vector2(cr.position.x + 1, cr.end.y - 1), Color(1, 0.95, 0.8), 8, HORIZONTAL_ALIGNMENT_RIGHT, 19)
			if e.get("eq", false):
				_txt("E", Vector2(cr.position.x + 2, cr.position.y + 8), Color(0.55, 1.0, 0.7))
		if li == main.inv_cell and not s0:
			draw_rect(cr.grow(1), GOLD_L, false, 1.0)
	var dy: float = (L["cells"][35] as Rect2).end.y + 9.0
	var more: int = lst.size() - (main.inv_scroll + 3) * 12
	_txt(("ALTRO SOTTO (%d)   " % more if more > 0 else "") + "BORSA %d / %d" % [p.bag_used(), p.BAG_MAX], Vector2(bx, dy - 1),
		Color(0.9, 0.5, 0.45) if p.bag_free() <= 0 else Color(0.5, 0.48, 0.6), 8, HORIZONTAL_ALIGNMENT_RIGHT, r.end.x - bx - 8)
	dy += 4
	var dr := Rect2(bx - 2, dy, r.end.x - bx - 6, r.end.y - dy - 18)
	_frame(dr, true, 0.92)
	var sel = main.inv_selected()
	if sel != null:
		_detail(p, sel, dr)
	var hint := "INVIO EQUIPAGGIA" if not s0 else "INVIO TOGLI"
	_txt(_k(hint + "  X SMONTA  G GETTA  Q/E SCHEDA  TAB LATO  I CHIUDI",
		"A EQUIPAGGIA  X SMONTA  Y GETTA  LB/RB SCHEDA  B CHIUDI"), Vector2(r.position.x, r.end.y - 5), Color(0.62, 0.6, 0.74), 8, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _detail(p: Player, e: Dictionary, dr: Rect2) -> void:
	_icon(e, Rect2(dr.position + Vector2(6, 6), Vector2(16, 16)))
	var lines: Array = []
	var title := ""
	var sub := ""
	match str(e["k"]):
		"w":
			title = Rpg.wname(e["w"]).to_upper()
			sub = "%s  -  %s" % [str(Rpg.FAM[e["w"]["f"]]["n"]).to_upper(), Rpg.RARITY[int(e["w"]["r"])]["n"]]
			lines = Forge.wlines(e["w"])
		"a":
			title = str(e["a"]["n"])
			sub = "%s  -  QUALITA' %d" % [Forge.PIECE_N[e["a"]["slot"]], int(e["a"].get("q", 1))]
			lines = Forge.alines(e["a"]["st"])
		"b":
			var id := str(e["id"])
			title = main.item_name(id)
			sub = "POZIONE  x%d%s" % [int(e["n"]), "   (NELLA CINTURA)" if e.get("eq", false) else ""]
			if p.brews.has(id):
				lines = Forge.brew_lines(p.brews[id]["fx"])
			else:
				for rc in main.RECIPES:
					if rc["id"] == id:
						lines = [str(rc["d"])]
		"r":
			var inf: Dictionary = Relics.info(str(e["id"]))
			title = str(inf["n"]).to_upper()
			sub = "RELIQUIA  x%d   %s" % [int(e["n"]), "INDOSSATA" if e.get("eq", false) else "NON ATTIVA"]
			lines = _wrap(str(inf["d"]).to_upper(), 40)
		"m":
			title = str(main.MAT_NAMES[e["id"]])
			sub = "MATERIALE  x%d" % int(e["n"])
			lines = ["SI USA ALLA FORGIA DEL FALO' (C)", "NON OCCUPA SPAZIO NELLA BORSA"]
	_txt(title, Vector2(dr.position.x + 28, dr.position.y + 12), _rcol(e))
	_txt(sub, Vector2(dr.position.x + 28, dr.position.y + 22), Color(0.6, 0.58, 0.72))
	var ly := dr.position.y + 36.0
	for ln in lines:
		if ly > dr.end.y - 4:
			break
		_txt(str(ln), Vector2(dr.position.x + 8, ly), Color(0.88, 0.88, 0.98))
		ly += 10.0
	if main.inv_side == 1 and str(e["k"]) in ["w", "a"]:
		var cmp: Array = main.inv_compare(e)
		var cxx := dr.position.x + 140
		_txt("RISPETTO ALL'INDOSSATO", Vector2(cxx, dr.position.y + 36), Color(0.6, 0.58, 0.72))
		var cy := dr.position.y + 46.0
		if cmp.is_empty():
			_txt("UGUALE", Vector2(cxx, cy), Color(0.7, 0.7, 0.8))
		for c in cmp:
			if cy > dr.end.y - 4:
				break
			var up: bool = float(c[1]) >= 0.0
			_txt(str(c[0]) + "  " + str(c[2]), Vector2(cxx, cy), Color(0.5, 1.0, 0.6) if up else Color(1.0, 0.45, 0.45))
			cy += 10.0
		var sv: Dictionary = main.salvage_of(e)
		var parts: Array = []
		for k in sv:
			parts.append("%d %s" % [int(sv[k]), str(main.MAT_NAMES[k])])
		_txt("SMONTANDO: " + (", ".join(parts) if not parts.is_empty() else "NULLA"), Vector2(dr.position.x + 8, dr.end.y - 4), Color(0.6, 0.75, 0.6))


func _mat_row(p: Player) -> void:
	var sig := ""
	for mid2 in main.MAT_ORDER:
		sig += "%s%d," % [str(mid2), int(p.mats.get(mid2, 0))]
	if sig != _mat_sig:
		if _mat_sig != "":
			_mat_t = 4.0
		_mat_sig = sig
	_mat_t = maxf(0.0, _mat_t - get_process_delta_time())
	var ma := clampf(_mat_t / 1.0, 0.0, 1.0)
	var x := 6.0
	var y := size.y - 66.0
	for mid in main.MAT_ORDER:
		if ma <= 0.0:
			break
		var n := int(p.mats.get(mid, 0))
		if n <= 0:
			continue
		draw_texture(Game.tex("mat_" + str(mid)) if mid in ["pelle", "carne", "osso"] else Game.tex("res_" + str(mid)), Vector2(x, y), Color(1, 1, 1, 0.95 * ma))
		_txt("%d" % n, Vector2(x + 12, y + 12), Color(0.9, 0.95, 0.8, ma))
		x += 24.0
	var bx := 0.0
	var bt := ""
	for bk in p.buffs:
		bt += "%s %d:%02d   " % [Forge.buff_name(str(bk)), int(p.buffs[bk]) / 60, int(p.buffs[bk]) % 60]
	if bt != "":
		_txt(bt.strip_edges(), Vector2(0, 81), Color(0.7, 1.0, 0.85), 8, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6)


func _dialog() -> void:
	var d: Dictionary = main.dlg
	if d.is_empty():
		return
	var r := Rect2(20, 158, size.x - 40, 96)
	_frame(r, true, 0.97)
	_txt(str(d["head"]), Vector2(r.position.x + 12, r.position.y + 15), Color(1, 0.82, 0.4))
	draw_rect(Rect2(r.position.x + 10, r.position.y + 19, r.size.x - 20, 1), GOLD_D)
	var ly := r.position.y + 32.0
	for ln in _wrap(str(d["text"]), 66):
		_txt(ln, Vector2(r.position.x + 12, ly), Color(0.9, 0.88, 0.98))
		ly += 10.0
	var opts: Array = d["opts"]
	var ox := r.position.x + 12.0
	for i in opts.size():
		var sel: bool = i == int(d["sel"])
		_txt(("> " if sel else "  ") + str(opts[i]), Vector2(ox, r.end.y - 12), Color(1, 0.92, 0.5) if sel else Color(0.65, 0.63, 0.78))
		ox += 120.0
	_txt(_k("INVIO CONFERMA  ESC CHIUDI", "A CONFERMA  B CHIUDI"), Vector2(r.end.x - 150, r.end.y - 12), Color(0.55, 0.55, 0.68))


var _rel_sig := ""
var _rel_t := 0.0


func _relic_row(p: Player, y := -1.0, always := false) -> void:
	var sig := str(p.relics)
	if sig != _rel_sig:
		if _rel_sig != "":
			_rel_t = 4.0
		_rel_sig = sig
	_rel_t = maxf(0.0, _rel_t - get_process_delta_time())
	var ra := 1.0 if always else clampf(_rel_t, 0.0, 1.0)
	if ra <= 0.0:
		return
	var x := 6.0
	if y < 0.0:
		y = size.y - 86.0
	for rr in Relics.LIST:
		var n := p.rl(str(rr["id"]))
		if n <= 0:
			continue
		draw_texture(Game.tex("relic_" + str(rr["id"])), Vector2(x, y), Color(1, 1, 1, ra))
		if n > 1:
			_txt("x%d" % n, Vector2(x + 11, y + 14), Color(1.0, 0.9, 0.6, ra))
		x += 26.0 if n > 1 else 16.0


func _item_line(p: Player) -> void:
	var id: String = main.item_current()
	if id == "":
		return
	var txt := "Z/X  NESSUN OGGETTO" if id == "" else "Z/X  %s  x%d" % [main.item_name(id), int(p.items.get(id, 0))]
	var n: int = main.item_ids().size()
	if n > 1:
		txt += "  (+%d)" % (n - 1)
	_txt(txt, Vector2(5, size.y - 39), Color(0.78, 0.95, 0.82, 0.8))


func _equip_panel(p: Player) -> void:
	var w: Dictionary = p.weapon()
	var rc: Color = Rpg.RARITY[int(w["r"])]["c"]
	var fs := _fs(8)
	var nm: String = Rpg.wname(w).to_upper()
	var labels: Array = []
	var bw := 40.0
	for i in 2:
		var id0: String = p.spells[i]
		var lb := "%d %s %d" % [i + 1, Rpg.SHORT[id0], int(Rpg.SPELLS[id0]["cost"])]
		labels.append(lb)
		bw = maxf(bw, font.get_string_size(lb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0)
	var pw := maxf(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 28.0, bw * 2.0 + 9.0)
	bw = (pw - 9.0) / 2.0
	var r := Rect2(3, size.y - 35, pw + 4.0, 32)
	_frame(r, true, 0.6)
	draw_texture(Game.tex(Rpg.wicon(w)), Vector2(r.position.x + 5, r.position.y + 3), Color(1, 1, 1, 0.95))
	_txt(nm, Vector2(r.position.x + 24, r.position.y + 12), rc)
	if p.wslots[1 - p.wcur] != null:
		var w2: Dictionary = p.wslots[1 - p.wcur]
		draw_texture(Game.tex(Rpg.wicon(w2)), Vector2(r.end.x - 17, r.position.y - 13), Color(1, 1, 1, 0.5))
	for i in 2:
		var id: String = p.spells[i]
		var sd: Dictionary = Rpg.SPELLS[id]
		var bx := r.position.x + 4.0 + i * (bw + 3.0)
		var by := r.end.y - 15.0
		draw_rect(Rect2(bx - 1, by - 1, bw + 2, 12), OUTLINE)
		draw_rect(Rect2(bx, by, bw, 10), Color(0.07, 0.05, 0.15, 0.8))
		var ready: bool = p.spell_cd[i] <= 0.0 and p.mana >= float(sd["cost"])
		var frac: float = 1.0 - clampf(p.spell_cd[i] / float(sd["cd"]), 0.0, 1.0)
		draw_rect(Rect2(bx, by + 8, int(bw * frac), 2), Color(0.45, 0.65, 1.0) if ready else Color(0.32, 0.32, 0.45))
		_txt(str(labels[i]), Vector2(bx + 3, by + 7), Color(0.88, 0.92, 1.0) if ready else Color(0.5, 0.5, 0.62))


func _class_select() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.0, 0.04, 1.0))
	_txt("SCEGLI LA TUA CLASSE", Vector2(0, 26), Color(1, 0.78, 0.3), 18, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	for i in 4:
		var id: String = main.class_ids[i]
		var c: Dictionary = Rpg.CLASSES[id]
		var r := Rect2(8 + i * 116, 36, 110, 216)
		var sel: bool = i == main.class_sel
		_frame(r, sel, 0.97 if sel else 0.85)
		var t: Texture2D = _ui_tex(str(c["spr"]))
		draw_texture_rect(t, Rect2(r.position.x + 35, r.position.y + 10, 40, 40), false)
		_txt(c["n"], Vector2(r.position.x, r.position.y + 66), Color(1, 0.92, 0.6) if sel else Color(0.72, 0.7, 0.82), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_rect(Rect2(r.position.x + 12, r.position.y + 71, r.size.x - 24, 1), GOLD_D)
		var lx := r.position.x + 7
		var ly := r.position.y + 83.0
		for ln in _wrap(c["d"], 16):
			_txt(ln, Vector2(lx, ly), Color(0.78, 0.76, 0.88))
			ly += 9.0
		ly += 3.0
		_txt("VITA %d" % int(c["hp"]), Vector2(lx, ly), Color(0.95, 0.5, 0.5))
		_txt("STAMINA %d" % int(c["st"]), Vector2(lx, ly + 9), Color(0.5, 0.9, 0.55))
		_txt("MANA %d" % int(c["mana"]), Vector2(lx, ly + 18), Color(0.55, 0.72, 1.0))
		_txt("ARMA: " + str(Rpg.FAM[c["weapon"]]["n"]), Vector2(lx, ly + 29), Color(0.88, 0.88, 0.94))
		var sy := ly + 40.0
		for k in 2:
			for ln in _wrap("%d: %s" % [k + 1, Rpg.SPELLS[c["spells"][k]]["n"]], 16):
				_txt(ln, Vector2(lx, sy), Color(0.62, 0.86, 1.0))
				sy += 9.0
	_txt(_k("SINISTRA/DESTRA scegli    INVIO conferma", "SINISTRA/DESTRA scegli    A conferma"), Vector2(0, 268), Color(0.55, 0.55, 0.65), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


func _pause() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62))
	var r := Rect2(size.x / 2 - 100, 58, 200, 178)
	_panel(r)
	_txt("PAUSA", Vector2(r.position.x, r.position.y + 30), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var items := ["RIPRENDI", "MAPPA", "BESTIARIO", "IMPOSTAZIONI", "CONTROLLI", "TORNA AL TITOLO", "ESCI DAL GIOCO"]
	for i in items.size():
		var sel: bool = i == main.pause_sel
		_txt(("> " if sel else "  ") + items[i], Vector2(r.position.x + 28, r.position.y + 54 + i * 14),
			Color(1, 0.92, 0.5) if sel else Color(0.78, 0.76, 0.88))
	_txt(_k("SU/GIU  INVIO  ESC", "SU/GIU  A  B"), Vector2(r.position.x, r.end.y - 10), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	if main.player != null:
		_relic_row(main.player, size.y - 48.0, true)
		var x := 6.0
		for mid in main.MAT_ORDER:
			var n := int(main.player.mats.get(mid, 0))
			if n <= 0:
				continue
			draw_texture(Game.tex("mat_" + str(mid)) if mid in ["pelle", "carne", "osso"] else Game.tex("res_" + str(mid)), Vector2(x, size.y - 26.0))
			_txt("%d" % n, Vector2(x + 12, size.y - 14.0), Color(0.9, 0.95, 0.8))
			x += 26.0


func _options() -> void:
	if not main.in_title_menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var r := Rect2(size.x / 2 - 160, 8, 320, 256)
	_panel(r)
	_txt("IMPOSTAZIONI", Vector2(r.position.x, r.position.y + 30), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	for i in main.OPTIONS.size():
		var o: Dictionary = main.OPTIONS[i]
		var y: float = r.position.y + 50.0 + i * 14.0
		var sel: bool = i == main.opt_sel
		var col := Color(1, 0.92, 0.5) if sel else Color(0.78, 0.76, 0.88)
		_txt(("> " if sel else "  ") + str(o["n"]), Vector2(r.position.x + 14, y), col)
		if o["t"] == "toggle":
			_txt("SI" if bool(main.settings[o["k"]]) else "NO", Vector2(r.position.x + r.size.x - 40, y), col)
		elif o["t"] == "slider":
			var n: int = int(o["max"])
			var v: int = int(main.settings[o["k"]])
			var x0 := r.position.x + (r.size.x - 20 - n * 8)
			for s in n:
				var on: bool = s < v
				draw_rect(Rect2(x0 + s * 8, y - 7, 7, 8), OUTLINE)
				draw_rect(Rect2(x0 + s * 8 + 1, y - 6, 5, 6), (Color(1, 0.82, 0.35) if sel else Color(0.7, 0.55, 0.25)) if on else Color(0.14, 0.1, 0.2))
	_txt(_k("SU/GIU scegli  SINISTRA/DESTRA cambia  ESC indietro", "SU/GIU  SX/DX cambia  B indietro"),
		Vector2(r.position.x, r.end.y - 10), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _controls() -> void:
	if not main.in_title_menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78))
	var r := Rect2(size.x / 2 - 230, 4, 460, 264)
	_panel(r)
	_txt("COMANDI PREDEFINITI", Vector2(r.position.x, r.position.y + 28), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x := r.position.x + 14
	_txt("AZIONE", Vector2(x, r.position.y + 46), GOLD_L)
	_txt("TASTIERA", Vector2(x + 152, r.position.y + 46), GOLD_L)
	_txt("CONTROLLER", Vector2(x + 290, r.position.y + 46), GOLD_L)
	var rows := [
		["MUOVERSI", "WASD / FRECCE", "STICK SX / CROCE"],
		["COLPO LEGGERO", "SPAZIO / J / CLICK", "RB"],
		["COLPO PESANTE", "L / CLICK DESTRO", "RT"],
		["ROTOLATA", "SHIFT / K", "B"],
		["PARATA (TEMPISMO)", "C", "L3 (STICK SX)"],
		["FIALA", "Q / F", "X"],
		["OGGETTO: CAMBIA / USA", "Z / X", "SELECT / LT"], ["BORSA ED EQUIPAGGIAMENTO", "I", "SELECT (TIENI)"],
		["MAGIA 1 / 2", "1 / 2  (R / G)", "LB / LT"],
		["CAMBIA ARMA", "TAB", "Y"],
		["INTERAGISCI", "E", "A"],
		["PAUSA", "ESC", "START"],
		["MAPPA / BESTIARIO", "M / B", "START > MAPPA"],
		["SCHERMO INTERO / FPS", "F11 / F3", "-"],
		["ZOOM ESTERNO 3D", "U", "-"],
		["ZOOM: ORDA/TATTICA", "V", "CROCE SU"],
		["AGGANCIA NEMICO", "Y", "R3"],
		["TATTICA: INVIA", "CLICK / SPAZIO", "RB"],
		["TATTICA: RICHIAMA", "L / CLICK DESTRO", "RT"],
		["CAMPO: MAGIE / VIAGGIO", "Z / X / T", "LB / RB / Y"],
		["CRONOTONE: BOLLA", "N", "SELECT"],
	]
	for i in rows.size():
		var y: float = r.position.y + 58.0 + i * 8.9
		_txt(rows[i][0], Vector2(x, y), Color(0.85, 0.83, 0.95))
		_txt(rows[i][1], Vector2(x + 152, y), Color(0.7, 0.85, 1.0))
		_txt(rows[i][2], Vector2(x + 290, y), Color(0.7, 1.0, 0.8))
	_txt(_k("ESC / INVIO per tornare", "A / B per tornare"), Vector2(r.position.x, r.end.y - 9), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _remap() -> void:
	if not main.in_title_menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.78))
	var r := Rect2(size.x / 2 - 230, 4, 460, 264)
	_panel(r)
	_txt("RIMAPPA TASTI", Vector2(r.position.x, r.position.y + 28), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x := r.position.x + 14
	_txt("AZIONE", Vector2(x, r.position.y + 46), GOLD_L)
	_txt("TASTIERA", Vector2(x + 170, r.position.y + 46), GOLD_L)
	_txt("CONTROLLER", Vector2(x + 320, r.position.y + 46), GOLD_L)
	var n: int = Keybinds.ACTIONS.size()
	for i in n + 1:
		var y := 65.0 + i * 9.6
		var sel: bool = i == main.remap_sel
		if sel:
			draw_rect(Rect2(r.position.x + 6, y - 9, r.size.x - 12, 9), Color(0.4, 0.28, 0.1, 0.55))
		if i == n:
			_txt("> RIPRISTINA I COMANDI PREDEFINITI" if sel else "  RIPRISTINA I COMANDI PREDEFINITI", Vector2(x, y), Color(1, 0.6, 0.5) if sel else Color(0.8, 0.5, 0.45))
			continue
		var act: String = Keybinds.ACTIONS[i][0]
		_txt(("> " if sel else "  ") + str(Keybinds.ACTIONS[i][1]), Vector2(x, y), Color(1, 0.92, 0.5) if sel else Color(0.85, 0.83, 0.95))
		var kc := Color(0.7, 0.85, 1.0)
		var pc := Color(0.7, 1.0, 0.8)
		var kt := Keybinds.key_text(act)
		var pt := Keybinds.pad_text(act) if Keybinds.can_pad(act) else "STICK"
		if sel:
			if main.remap_col == 0:
				kc = Color(1, 0.92, 0.5)
			else:
				pc = Color(1, 0.92, 0.5)
			if main.remap_wait:
				if main.remap_col == 0:
					kt = "PREMI UN TASTO..."
				else:
					pt = "PREMI UN PULSANTE..."
		_txt(kt, Vector2(x + 170, y), kc)
		_txt(pt, Vector2(x + 320, y), pc)
	var foot := _k("SU/GIU scegli  SX/DX colonna  INVIO cambia  ESC indietro", "SU/GIU  SX/DX colonna  A cambia  B indietro")
	if main.remap_wait:
		foot = "PREMI IL NUOVO COMANDO  (ESC ANNULLA)"
	elif main.remap_msg != "":
		foot = main.remap_msg
	_txt(foot, Vector2(r.position.x, r.end.y - 9), Color(1, 0.85, 0.5) if (main.remap_wait or main.remap_msg != "") else Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
