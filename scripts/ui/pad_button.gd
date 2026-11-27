extends Control
## A round, see-through touch button (Kenney Mobile Controls) in the on-screen pad. Handles every finger on its own
## (ordinary Buttons only see the first finger), so you can hold the stick and press at once.
## Faint until it's useful; set `useful` to brighten it.

const BUTTON := preload("res://assets/kenney/mobile-controls/button_circle.png")

signal pressed_id(id: String)
signal released_id(id: String)

const FAINT := 0.4
const BRIGHT := 0.9

var id := ""
## The letter on the button (Kenney icon), matching the same button on a controller.
var icon: Texture2D
var radius := 44.0
## True while something makes this button worth pressing (someone to talk to, a fight).
var useful := false
var held := false
var _finger := -2


func setup(button_id: String, letter: Texture2D, r: float) -> void:
	id = button_id
	icon = letter
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
	# Kenney Mobile Controls: a dark round button with a white letter, like a real pad.
	var r := Rect2(Vector2.ZERO, size)
	if held:
		r = r.grow(-radius * 0.06)
	draw_texture_rect(BUTTON, r, false, Color(0.75, 0.75, 0.75) if held else Color.WHITE)
	if icon:
		var s := size.x * 0.46
		draw_texture_rect(icon, Rect2(size * 0.5 - Vector2(s, s) * 0.5, Vector2(s, s)), false)
