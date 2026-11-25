class_name SingFx
extends CanvasLayer
## Scritta gigante "POWER UP!" in stile anni '80 (cromo giallo, bordi magenta e ciano, righe di scansione) con il tasto da premere.

var ctl: Control
var t := 0.0
var key := "N"


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
	ctl.queue_redraw()


func _draw_fx() -> void:
	var vs: Vector2 = ctl.size
	var f: Font = Game.font()          # lo stesso font a pixel dell'interfaccia, ingrandito a blocchi (filtro nearest)
	ctl.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.25, 0.0, 0.3, 0.28))
	var txt := "POWER UP!"
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var k := floorf(vs.x * 0.66 / w * 2.0) / 2.0 if w > 0.0 else 8.0     # scala a passi: i pixel restano quadrati
	var pulse := 1.0 + 0.035 * sin(t * 7.0)
	var org := Vector2(vs.x * 0.5, vs.y * 0.46)
	ctl.draw_set_transform_matrix(Transform2D(Vector2(k * pulse, 0.0), Vector2(-0.28 * k * pulse, k * pulse), org))
	var p := Vector2(-w * 0.5, 3.0)
	ctl.draw_string(f, p + Vector2(1.0, 1.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 0.9, 1.0))
	ctl.draw_string(f, p + Vector2(0.5, 0.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.1, 0.75))
	for o in [Vector2(0, 0), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(0.5, 0.5)]:
		ctl.draw_string(f, p + o, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.93, 0.35))
	for i in 14:
		ctl.draw_rect(Rect2(-w * 0.55, -5.0 + i * 0.95, w * 1.1, 0.22), Color(0, 0, 0, 0.3))
	var hint := "PREMI %s PER EVOCARE OGGETTI DAL FUTURO" % key
	var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var kh := maxf(1.0, floorf(vs.x * 0.6 / hw))
	var a := 0.75 + 0.25 * sin(t * 5.0)
	ctl.draw_set_transform_matrix(Transform2D(Vector2(kh, 0.0), Vector2(0.0, kh), Vector2((vs.x - hw * kh) * 0.5, vs.y * 0.7)))
	ctl.draw_string(f, Vector2(0.5, 0.5), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0, 0, 0, a))
	ctl.draw_string(f, Vector2.ZERO, hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.6, 1.0, 1.0, a))
	ctl.draw_set_transform_matrix(Transform2D.IDENTITY)
