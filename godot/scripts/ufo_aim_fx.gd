class_name UfoAimFx
extends CanvasLayer
## Radura, quando si ha un'arma contro l'ufo: scritta cafona anni '80 che lampeggia (stesso stile di "POWER UP!")
## con in piccolo il tasto da premere. Dall'alto invita a passare in prima persona; in prima persona sta in alto per non
## coprire il mirino. In piu' l'avviso "SPOSTATI!" quando qualcosa sta per colpire l'eroe (mirando non si guarda a terra).

const WORDS := ["SHOOT HIM!", "FIRE!!!!", "GET HIM!", "BLAST IT!", "KILL THAT THING!", "NOW OR NEVER!", "BOOM BOOM BOOM!", "TAKE HIM DOWN!"]
const WORD_TIME := 0.62
# colori che si alternano: riempimento, ombra vicina, ombra lontana
const PALETTES := [
	[Color(1.0, 0.93, 0.35), Color(0.9, 0.1, 0.75), Color(0.1, 0.9, 1.0)],
	[Color(1.0, 0.35, 0.18), Color(1.0, 0.92, 0.3), Color(0.55, 0.1, 0.9)],
	[Color(0.45, 1.0, 0.95), Color(0.15, 0.25, 1.0), Color(1.0, 0.2, 0.7)],
	[Color(1.0, 0.45, 0.85), Color(0.35, 0.05, 0.6), Color(1.0, 0.85, 0.2)],
]

var main
var ctl: Control
var t := 0.0
var danger := false
var danger_was := false


func _ready() -> void:
	layer = 80
	ctl = Control.new()
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ctl.draw.connect(_draw_fx)
	add_child(ctl)


func _process(dt: float) -> void:
	t += dt
	var playing: bool = main != null and str(main.state) == "play"
	visible = playing
	danger = playing and main.side_scroll_danger()
	if danger and not danger_was:
		main.snd("cock")
	danger_was = danger
	ctl.queue_redraw()


## scritta cromata inclinata, centrata in "org", larga circa "wide" pixel
func _chrome(txt: String, org: Vector2, wide: float, pal: Array, pulse: float, tilt: float) -> void:
	var f: Font = Game.font()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	if w <= 0.0:
		return
	var k := maxf(1.0, floorf(wide / w * 2.0) / 2.0) * pulse
	var m := Transform2D(Vector2(k, 0.0), Vector2(-0.28 * k, k), Vector2.ZERO)
	ctl.draw_set_transform_matrix(Transform2D(tilt, org) * m)
	var p := Vector2(-w * 0.5, 3.0)
	ctl.draw_string(f, p + Vector2(1.1, 1.1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, pal[2])
	ctl.draw_string(f, p + Vector2(0.55, 0.55), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, pal[1])
	for o in [Vector2(0, 0), Vector2(0.45, 0), Vector2(0, 0.45), Vector2(0.45, 0.45)]:
		ctl.draw_string(f, p + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, pal[0])
	for i in 10:
		ctl.draw_rect(Rect2(-w * 0.55, -4.0 + i * 0.95, w * 1.1, 0.2), Color(0, 0, 0, 0.26))
	ctl.draw_set_transform_matrix(Transform2D.IDENTITY)


func _small(txt: String, center_x: float, y: float, wide: float, col: Color) -> void:
	var f: Font = Game.font()
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var k := maxf(1.0, floorf(wide / maxf(w, 1.0)))
	ctl.draw_set_transform_matrix(Transform2D(Vector2(k, 0.0), Vector2(0.0, k), Vector2(center_x - w * k * 0.5, y)))
	ctl.draw_rect(Rect2(-3.0, -8.0, w + 6.0, 11.0), Color(0.02, 0.0, 0.06, 0.62))
	ctl.draw_string(f, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)
	ctl.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_fx() -> void:
	if main == null:
		return
	var vs: Vector2 = ctl.size
	var fps: bool = main.skin is W3DSkin and (main.skin as W3DSkin).fpv
	var armed: bool = main.side_scroll_weapon_t > 0.0 and main.side_scroll_shots_left > 0
	if armed:
		var n := int(t / WORD_TIME)
		var local := fposmod(t, WORD_TIME) / WORD_TIME
		var word: String = WORDS[n % WORDS.size()]
		var pal: Array = PALETTES[n % PALETTES.size()]
		var punch := 1.0 + 0.35 * maxf(0.0, 1.0 - local * 5.0)      # ogni parola entra di botto
		var blink := local < 0.86 or fposmod(t * 24.0, 1.0) < 0.5
		var tilt := (-0.07 if n % 2 == 0 else 0.055) + sin(t * 31.0) * 0.006
		if blink:
			if fps:
				_chrome(word, Vector2(vs.x * 0.5, vs.y * 0.135), vs.x * 0.34, pal, punch, tilt)
			else:
				_chrome(word, Vector2(vs.x * 0.5, vs.y * 0.47), vs.x * 0.6, pal, punch, tilt)
		if fps:
			var fire: String = Keybinds.pad_text("attack") if main.use_pad else "CLICK O " + Keybinds.key_text("attack")
			_small("%s: SPARA    COLPI: %d" % [fire, main.side_scroll_shots_left], vs.x * 0.5, vs.y * 0.815, vs.x * 0.34, Color(0.75, 1.0, 1.0))
		else:
			var a := 0.75 + 0.25 * sin(t * 9.0)
			_small("PREMI %s: PRIMA PERSONA" % main.view_key(), vs.x * 0.5, vs.y * 0.62, vs.x * 0.34, Color(0.75, 1.0, 1.0, a))
	if danger and fposmod(t * 5.0, 1.0) < 0.65:
		_chrome("SPOSTATI!", Vector2(vs.x * 0.5, vs.y * 0.69), vs.x * 0.3, [Color(1.0, 0.18, 0.1), Color(0.35, 0.0, 0.0), Color(1.0, 0.85, 0.2)], 1.0, 0.0)
		ctl.draw_rect(Rect2(Vector2(2, 2), vs - Vector2(4, 4)), Color(1.0, 0.1, 0.05, 0.55), false, 4.0)
