extends Control
## A round, see-through touch button in the on-screen pad. Handles every finger on its own
## (ordinary Buttons only see the first finger), so you can hold the stick and press at once.
## Faint until it's useful; set `useful` to brighten it.

signal pressed_id(id: String)
signal released_id(id: String)

const FAINT := 0.32
const BRIGHT := 0.85

var id := ""
var label := ""
var radius := 44.0
## True while something makes this button worth pressing (someone to talk to, a fight).
var useful := false
var held := false
var _finger := -2


func setup(button_id: String, text: String, r: float) -> void:
	id = button_id
	label = text
	radius = r
	custom_minimum_size = Vector2(r * 2.0, r * 2.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = FAINT


func _process(delta: float) -> void:
	var goal := BRIGHT if (useful or held) else FAINT
	modulate.a = move_toward(modulate.a, goal, delta * 4.0)
	if not is_visible_in_tree() and held:
		_release()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _finger == -2 and _hit(event.position):
			_finger = event.index
			_press()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _finger:
			_release()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and _finger == -2 and _hit(event.position):
			_finger = -1
			_press()
			get_viewport().set_input_as_handled()
		elif not event.pressed and _finger == -1:
			_release()
			get_viewport().set_input_as_handled()


## For tests: a press and release from code.
func tap() -> void:
	_press()
	_release()


func _hit(p: Vector2) -> bool:
	var r := get_global_rect()
	return p.distance_to(r.get_center()) <= radius * 1.1


func _press() -> void:
	held = true
	queue_redraw()
	pressed_id.emit(id)


func _release() -> void:
	held = false
	_finger = -2
	queue_redraw()
	released_id.emit(id)


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius, Color(0.08, 0.07, 0.06, 0.75 if held else 0.55))
	draw_arc(c, radius - 1.5, 0.0, TAU, 48, Color(0.95, 0.88, 0.72, 0.9), 3.0, true)
	var font := get_theme_default_font()
	var fs := int(clampf(radius * 0.42, 16.0, 26.0))
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-w * 0.5, fs * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.97, 0.93, 0.85))
