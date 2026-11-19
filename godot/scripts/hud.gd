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
	var cp: Vector2 = get_viewport().get_canvas_transform() * p.aim_world
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
	if (main.state == "options" or main.state == "controls") and main.in_title_menu:
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
	# obiettivo compatto: pieno per qualche secondo quando cambia, poi attenuato; una sola missione
	var obj: String = main.objective()
	var obj_key := obj.substr(0, mini(obj.find("("), 28) if obj.find("(") > 0 else 28)
	if obj_key != _obj_last:
		_obj_last = obj_key
		_obj_t = 12.0
	_obj_t = maxf(0.0, _obj_t - get_process_delta_time())
	var oa := 1.0 if _obj_t > 0.0 else 0.55
	var oy := 49.0 if main.cycle > 0 else 39.0
	for ln in _wrap(obj, 30):
		_txt(ln, Vector2(5, oy + 7.0), Color(0.95, 0.8, 0.45, oa))
		oy += 9.0
	var ql: Array = main.quest_lines()
	if ql.size() > 0:
		var qs: Array = _wrap(str(ql[0]), 30)
		_txt(str(qs[0]), Vector2(5, oy + 9.0), Color(0.7, 0.92, 0.85, oa * 0.9))
		if ql.size() > 1 or qs.size() > 1:
			_txt("...", Vector2(5 + 6.0 * minf(30.0, str(qs[0]).length()), oy + 9.0), Color(0.7, 0.92, 0.85, oa * 0.9))
	if p.zmode > 0:
		_txt("MODALITA ORDA" if p.zmode == 1 else "MODALITA TATTICA", Vector2(0, 20), Color(1.0, 0.6, 0.9) if p.zmode == 1 else Color(0.6, 0.9, 1.0), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var overlay: bool = main.state in ["menu", "pick", "travel", "pause", "options", "controls", "dialog", "craft"]
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
		var ly := 56.0
		for ln in _wrap(main.msg, 54):
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
	match main.state:
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
	_txt("POTENZIAMENTI", Vector2(x, y + 149), GOLD_L)
	var yy := y + 161.0
	var col := 0
	for u in Upgrades.LIST:
		var n := p.r(u["id"])
		if n > 0:
			_txt("%s %d" % [u["n"], n], Vector2(x + col * 140, yy), Color(0.88, 0.85, 0.98))
			col += 1
			if col == 2:
				col = 0
				yy += 10.0
	_txt("Progresso: %d / %d" % [p.lv - 1, Upgrades.total_max()], Vector2(r.position.x, r.end.y - 9), Color(0.6, 0.55, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _pick(p: Player) -> void:
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
	if main.area != "world" or main.state != "play":
		return
	var jt: Variant = main.journey_target()
	if jt != null:
		_edge_arrow(jt as Vector2, Color(1.0, 0.85, 0.25))
	if main.ev_chest != null:
		_edge_arrow(main.ev_pos, Color(0.4, 0.9, 1.0))


## freccia sul bordo dello schermo verso un bersaglio fuori inquadratura, con la distanza in celle
func _edge_arrow(wp: Vector2, col: Color) -> void:
	var sp: Vector2 = main.get_canvas_transform() * wp
	var inner := Rect2(10, 10, size.x - 20, size.y - 20)
	if inner.has_point(sp):
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
	var jt: Variant = main.journey_target()
	if jt != null:
		var jc := Vector2(floori((jt as Vector2).x / Game.TS), floori((jt as Vector2).y / Game.TS))
		var jp := (dst.position + (jc - Vector2(ox, oy)) * sc).floor()
		jp = Vector2(clampf(jp.x, dst.position.x + 2, dst.end.x - 3), clampf(jp.y, dst.position.y + 2, dst.end.y - 3))
		if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.65:
			draw_rect(Rect2(jp - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
			draw_rect(Rect2(jp - Vector2(1, 1), Vector2(3, 3)), Color(1.0, 0.85, 0.25))
	if main.ev_chest != null:
		var ec := Vector2(floori(main.ev_pos.x / Game.TS), floori(main.ev_pos.y / Game.TS))
		var ep := (dst.position + (ec - Vector2(ox, oy)) * sc).floor()
		ep = Vector2(clampf(ep.x, dst.position.x + 2, dst.end.x - 3), clampf(ep.y, dst.position.y + 2, dst.end.y - 3))
		draw_rect(Rect2(ep - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
		draw_rect(Rect2(ep - Vector2(1, 1), Vector2(3, 3)), Color(0.4, 0.9, 1.0))
	var pp := (dst.position + (Vector2(pc) - Vector2(ox, oy)) * sc).floor()
	draw_rect(Rect2(pp - Vector2(2, 2), Vector2(5, 5)), OUTLINE)
	draw_rect(Rect2(pp - Vector2(1, 1), Vector2(3, 3)), Color(1, 1, 1))


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
	var x := 6.0
	var y := size.y - 72.0
	for sp in p.spirits:
		var d: Dictionary = Spirit.DATA[sp["k"]]
		draw_texture_rect(Game.tex(str(d["spr"])), Rect2(x, y, 16, 16), false, Color(0.6, 1.0, 1.4))
		_txt("%d" % int(sp["lv"]), Vector2(x + 11, y + 15), Color(0.7, 1.0, 1.0))
		x += 20.0


func _craft(p: Player) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var r := Rect2(size.x / 2 - 170, 14, 340, 244)
	_panel(r)
	_txt("ARTIGIANATO", Vector2(r.position.x, r.position.y + 26), Color(1, 0.78, 0.38), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x := r.position.x + 14
	var mx := x
	for mid in main.MAT_ORDER:
		draw_texture(Game.tex("mat_" + str(mid)) if mid in ["pelle", "carne", "osso"] else Game.tex("res_" + str(mid)), Vector2(mx, r.position.y + 36), Color.WHITE)
		_txt("%d" % int(p.mats.get(mid, 0)), Vector2(mx + 13, r.position.y + 48), Color(0.9, 0.95, 0.8))
		mx += 46.0
	draw_rect(Rect2(x, r.position.y + 56, r.size.x - 28, 1), GOLD_D)
	var y := r.position.y + 70.0
	for i in main.RECIPES.size():
		var rc: Dictionary = main.RECIPES[i]
		var sel: bool = i == main.craft_sel
		var ok: bool = main.can_craft(rc)
		_txt(("> " if sel else "  ") + str(rc["n"]), Vector2(x, y), (Color(1, 0.92, 0.5) if ok else Color(0.7, 0.55, 0.55)) if sel else (Color(0.9, 0.9, 1.0) if ok else Color(0.5, 0.48, 0.58)))
		var ctext := ""
		for k in rc["cost"]:
			ctext += "%d %s  " % [main.craft_cost(rc, str(k)), str(main.MAT_NAMES[k]).substr(0, 4)]
		_txt(ctext, Vector2(x + 150, y), Color(0.75, 0.9, 0.7) if ok else Color(0.55, 0.45, 0.45))
		y += 18.0
	var dsel: Dictionary = main.RECIPES[main.craft_sel]
	draw_rect(Rect2(x, y - 2, r.size.x - 28, 1), GOLD_D)
	_txt(str(dsel["d"]), Vector2(x, y + 11), Color(0.85, 0.82, 0.95))
	if str(dsel["id"]) == "affila":
		_txt("AFFILATURA ATTUALE: %d / 5" % int(p.weapon().get("u", 0)), Vector2(x, y + 23), Color(0.7, 0.8, 1.0))
	_txt(_k("SU/GIU SCEGLI   INVIO REALIZZA   ESC TORNA", "SU/GIU SCEGLI   A REALIZZA   B TORNA"), Vector2(r.position.x, r.end.y - 9), Color(0.6, 0.58, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


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
	var y := size.y - 86.0
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
		bt += "%s %d:%02d   " % [str(bk).to_upper(), int(p.buffs[bk]) / 60, int(p.buffs[bk]) % 60]
	if bt != "":
		_txt(bt, Vector2(0, size.y - 36), Color(0.7, 1.0, 0.85), 9, HORIZONTAL_ALIGNMENT_CENTER, size.x)


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


func _relic_row(p: Player) -> void:
	var x := 6.0
	var y := size.y - 68.0
	for rr in Relics.LIST:
		var n := p.rl(str(rr["id"]))
		if n <= 0:
			continue
		draw_texture(Game.tex("relic_" + str(rr["id"])), Vector2(x, y))
		if n > 1:
			_txt("x%d" % n, Vector2(x + 11, y + 14), Color(1.0, 0.9, 0.6))
		x += 26.0 if n > 1 else 16.0


func _item_line(p: Player) -> void:
	var id: String = main.item_current()
	if id == "":
		return
	var txt := "Z/X  NESSUN OGGETTO" if id == "" else "Z/X  %s  x%d" % [main.item_name(id), int(p.items.get(id, 0))]
	var n: int = main.item_ids().size()
	if n > 1:
		txt += "  (+%d)" % (n - 1)
	_txt(txt, Vector2(5, size.y - 40), Color(0.78, 0.95, 0.82, 0.55 if id == "" else 0.95))


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
	draw_texture(Game.tex(Rpg.FAM[w["f"]]["icon"]), Vector2(r.position.x + 5, r.position.y + 3), Color(1, 1, 1, 0.95))
	_txt(nm, Vector2(r.position.x + 24, r.position.y + 12), rc)
	if p.wslots[1 - p.wcur] != null:
		var w2: Dictionary = p.wslots[1 - p.wcur]
		draw_texture(Game.tex(Rpg.FAM[w2["f"]]["icon"]), Vector2(r.end.x - 17, r.position.y - 13), Color(1, 1, 1, 0.5))
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
		var t: Texture2D = Game.tex(c["spr"])
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
	var r := Rect2(size.x / 2 - 100, 62, 200, 150)
	_panel(r)
	_txt("PAUSA", Vector2(r.position.x, r.position.y + 30), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var items := ["RIPRENDI", "IMPOSTAZIONI", "CONTROLLI", "TORNA AL TITOLO", "ESCI DAL GIOCO"]
	for i in items.size():
		var sel: bool = i == main.pause_sel
		_txt(("> " if sel else "  ") + items[i], Vector2(r.position.x + 28, r.position.y + 54 + i * 14),
			Color(1, 0.92, 0.5) if sel else Color(0.78, 0.76, 0.88))
	_txt(_k("SU/GIU  INVIO  ESC", "SU/GIU  A  B"), Vector2(r.position.x, r.end.y - 10), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _options() -> void:
	if not main.in_title_menu:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.7))
	var r := Rect2(size.x / 2 - 160, 22, 320, 226)
	_panel(r)
	_txt("IMPOSTAZIONI", Vector2(r.position.x, r.position.y + 30), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	for i in main.OPTIONS.size():
		var o: Dictionary = main.OPTIONS[i]
		var y: float = r.position.y + 58.0 + i * 16.0
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
	var r := Rect2(size.x / 2 - 190, 4, 380, 264)
	_panel(r)
	_txt("COMANDI", Vector2(r.position.x, r.position.y + 28), Color(1, 0.8, 0.4), 18, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var x := r.position.x + 14
	_txt("AZIONE", Vector2(x, r.position.y + 46), GOLD_L)
	_txt("TASTIERA", Vector2(x + 96, r.position.y + 46), GOLD_L)
	_txt("CONTROLLER", Vector2(x + 262, r.position.y + 46), GOLD_L)
	var rows := [
		["MUOVERSI", "WASD / FRECCE", "STICK SX / CROCE"],
		["COLPO LEGGERO", "SPAZIO / J / CLICK", "RB"],
		["COLPO PESANTE", "L / CLICK DESTRO", "RT"],
		["ROTOLATA", "SHIFT / K", "B"],
		["PARATA (TEMPISMO)", "C", "L3 (STICK SX)"],
		["FIALA", "Q / F", "X"],
		["OGGETTO: CAMBIA / USA", "Z / X", "SELECT / LT"],
		["MAGIA 1 / 2", "1 / 2  (R / G)", "LB / LT"],
		["CAMBIA ARMA", "TAB", "Y"],
		["INTERAGISCI", "E", "A"],
		["PAUSA", "ESC", "START"],
		["SCHERMO INTERO", "F11 / ALT+INVIO", "-"],
		["MOSTRA FPS", "F3", "-"],
		["ZOOM: ORDA/TATTICA", "V", "R3"],
		["TATTICA: INVIA", "CLICK / SPAZIO", "RB"],
		["TATTICA: RICHIAMA", "L / CLICK DESTRO", "RT"],
		["CAMPO: MAGIE", "Z / X", "LB / RB"],
		["CAMPO: VIAGGIO", "T", "Y"],
	]
	for i in rows.size():
		var y: float = r.position.y + 60.0 + i * 11.0
		_txt(rows[i][0], Vector2(x, y), Color(0.85, 0.83, 0.95))
		_txt(rows[i][1], Vector2(x + 96, y), Color(0.7, 0.85, 1.0))
		_txt(rows[i][2], Vector2(x + 262, y), Color(0.7, 1.0, 0.8))
	_txt(_k("ESC / INVIO per tornare", "A / B per tornare"), Vector2(r.position.x, r.end.y - 9), Color(0.6, 0.6, 0.72), 9, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
