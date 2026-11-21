extends Node
## Input setup for keyboard, touch and game controllers, made at startup so it lives in one
## readable place instead of project.godot.
##
## Controllers are matched by button POSITION, not label (Godot's standard layout):
##   bottom face = confirm / interact     right face = back
##   d-pad or left stick = walk           L1 / R1 = zoom
##   Select = dev overlay                 Start = (menu, later)
## In a fight: bottom = strike, left = shove, right = guard, top = talk, Start = end turn
## (keyboard 1-5), while the d-pad or stick still walks.
## The 8BitDo Pro 2 works in X-input mode (switch on the back set to X), which Android and
## Windows both treat as an Xbox pad. In Switch mode the printed letters are swapped (the
## bottom button is labelled B), but it still confirms, because position is what counts.

const DEADZONE := 0.45

## action -> list of events. Keys are physical keycodes; joypad entries are [button] or
## [axis, direction].
const ACTIONS := {
	"move_up": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_down": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	"interact": {"keys": [KEY_E, KEY_SPACE, KEY_ENTER], "buttons": [JOY_BUTTON_A]},
	"cancel": {"keys": [KEY_ESCAPE, KEY_Q], "buttons": [JOY_BUTTON_B]},
	"zoom_in": {"keys": [KEY_EQUAL, KEY_KP_ADD], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"zoom_out": {"keys": [KEY_MINUS, KEY_KP_SUBTRACT], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"dev_overlay": {"keys": [KEY_F3], "buttons": [JOY_BUTTON_BACK]},
	"menu": {"keys": [], "buttons": [JOY_BUTTON_START]},
	# In a fight. Face buttons by position: bottom strike, left shove, right guard, top talk.
	"combat_strike": {"keys": [KEY_1], "buttons": [JOY_BUTTON_A]},
	"combat_shove": {"keys": [KEY_2], "buttons": [JOY_BUTTON_X]},
	"combat_guard": {"keys": [KEY_3], "buttons": [JOY_BUTTON_B]},
	"combat_talk": {"keys": [KEY_4], "buttons": [JOY_BUTTON_Y]},
	"combat_end_turn": {"keys": [KEY_5, KEY_TAB], "buttons": [JOY_BUTTON_START]},
}

## Godot's built-in UI actions (menus, dialogue choices) get the same pad bindings.
const UI_PAD := {
	"ui_accept": [JOY_BUTTON_A],
	"ui_cancel": [JOY_BUTTON_B],
	"ui_up": [JOY_BUTTON_DPAD_UP],
	"ui_down": [JOY_BUTTON_DPAD_DOWN],
	"ui_left": [JOY_BUTTON_DPAD_LEFT],
	"ui_right": [JOY_BUTTON_DPAD_RIGHT],
}
const UI_STICK := {
	"ui_up": [JOY_AXIS_LEFT_Y, -1.0],
	"ui_down": [JOY_AXIS_LEFT_Y, 1.0],
	"ui_left": [JOY_AXIS_LEFT_X, -1.0],
	"ui_right": [JOY_AXIS_LEFT_X, 1.0],
}

## True after the last input came from a controller (or keyboard); false after touch or mouse.
var using_pad := false


func _ready() -> void:
	for action in ACTIONS:
		var spec: Dictionary = ACTIONS[action]
		if not InputMap.has_action(action):
			InputMap.add_action(action, DEADZONE)
		for key in spec.get("keys", []):
			var e := InputEventKey.new()
			e.physical_keycode = key
			_add(action, e)
		for button in spec.get("buttons", []):
			var b := InputEventJoypadButton.new()
			b.button_index = button
			_add(action, b)
		for axis in spec.get("axes", []):
			_add(action, _motion(axis))
	for action in UI_PAD:
		for button in UI_PAD[action]:
			var b := InputEventJoypadButton.new()
			b.button_index = button
			_add(action, b)
	for action in UI_STICK:
		_add(action, _motion(UI_STICK[action]))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventKey:
		using_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > DEADZONE:
		using_pad = true
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		using_pad = false


func has_controller() -> bool:
	return not Input.get_connected_joypads().is_empty()


func _motion(axis: Array) -> InputEventJoypadMotion:
	var m := InputEventJoypadMotion.new()
	m.axis = axis[0]
	m.axis_value = axis[1]
	return m


func _add(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	for existing in InputMap.action_get_events(action):
		if existing.is_match(event, true):
			return
	InputMap.action_add_event(action, event)
