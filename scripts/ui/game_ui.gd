extends CanvasLayer
## All on-screen UI, built in code: the dialogue panel, title and end cards, toasts, and a
## developer-only baseline overlay. Sized for phones first (large text and buttons).

signal choice_made(index: int)
signal card_choice(index: int)
signal combat_action(id: String)
signal title_choice(id: String)
signal skip_pressed
signal opening_done

const TITLE_FONT := preload("res://assets/fonts/cinzel-bold.woff")
const Speech := preload("res://scripts/ui/speech.gd")
const Portrait := preload("res://scripts/ui/portrait.gd")
const PadButton := preload("res://scripts/ui/pad_button.gd")
const STICK_PAD := preload("res://assets/kenney/mobile-controls/joystick_pad.png")
const STICK_NUB := preload("res://assets/kenney/mobile-controls/joystick_nub.png")

const TEXT_SIZE := 24
const BUTTON_HEIGHT := 60

## Full screen (letterbox bars); everything else sits in _root, inside the phone's safe area.
var _full: Control
var _root: Control
var speech: Speech
var _portrait: Portrait
var _portrait_frame: PanelContainer
var _safe_key := Rect2i()
var _panel: PanelContainer
var _speaker: Label
var _body: Label
var _choices: VBoxContainer
var _dim: ColorRect
var _card: PanelContainer
var _card_title: Label
var _card_body: Label
var _card_buttons: VBoxContainer
var _toast: Label
var _toast_tween: Tween
var _dev: Label
var _wounds: Label
var _bars: Array = []
var _skip: Button
var _cinematic := false
var _opening: Control
var _title: Control
var _title_menu: VBoxContainer
var _pad: Control
var _pad_buttons: Dictionary = {}
var _stick: Control
## Tests set this to get touch controls without a touch screen.
var force_touch := false
## Lock is active: pressing it would do something (someone in reach, or already locked on).
var lock_ready := false
## Set once a level is playing, so touch action buttons can show.
var touch_actions_enabled := false


func _ready() -> void:
	_full = Control.new()
	_full.set_anchors_preset(Control.PRESET_FULL_RECT)
	_full.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_full)
	speech = Speech.new()
	_full.add_child(speech)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_dialogue()
	_build_card()
	_build_toast()
	_build_dev()
	_build_wounds()
	_build_touch_bar()
	_build_title()
	_build_cinematic()


# --- Dialogue -------------------------------------------------------------------------------

## look: the speaker's character look, for a portrait beside the text ({} for none).
func show_page(speaker: String, text: String, choices: Array, look: Dictionary = {}) -> void:
	_portrait_frame.visible = not look.is_empty()
	if not look.is_empty():
		_portrait.show_look(look)
	_speaker.text = speaker
	_speaker.visible = speaker != ""
	_body.text = text
	_clear(_choices)
	var labels: Array = choices if not choices.is_empty() else ["Continue"]
	for i in labels.size():
		_choices.add_child(_button(String(labels[i]), _on_choice.bind(i)))
	_panel.visible = true
	_focus_first(_choices)


func hide_page() -> void:
	_panel.visible = false


func is_busy() -> bool:
	return _panel.visible or _card.visible or (_title != null and _title.visible) or _opening != null


# --- Cutscenes ---------------------------------------------------------------------------

## Letterbox bars and a Skip button while a scene plays.
func set_cinematic(on: bool) -> void:
	_cinematic = on
	for i in _bars.size():
		var bar: ColorRect = _bars[i]
		var h := letterbox_height() if on else 0.0
		var tw := create_tween()
		if i == 0:
			tw.tween_property(bar, "offset_bottom", h, 0.4)
		else:
			tw.tween_property(bar, "offset_top", -h, 0.4)
	_skip.visible = on


## Thin bars: a hint of film, not a third of a wide phone's height.
func letterbox_height() -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(1.0, size.y)
	return size.y * (0.06 if aspect < 1.9 else 0.04)


func is_cinematic() -> bool:
	return _cinematic


func _build_cinematic() -> void:
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color(0, 0, 0, 0.92)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		if i == 0:
			bar.anchor_top = 0.0
			bar.anchor_bottom = 0.0
		else:
			bar.anchor_top = 1.0
			bar.anchor_bottom = 1.0
		_full.add_child(bar)
		_bars.append(bar)
	_skip = _button("Skip  ▸", func() -> void: skip_pressed.emit())
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -150
	_skip.offset_right = -16
	_skip.offset_top = 8
	_skip.offset_bottom = 56
	_skip.modulate.a = 0.8
	_skip.visible = false
	_root.add_child(_skip)


# --- Opening screen ---------------------------------------------------------------------

## A black screen with lines fading in one at a time, then a single button. Used once, as the
## gate shuts between Floor 0 and Floor 1. Pressing anything early shows every line at once.
func show_opening(lines: Array, button_text: String) -> void:
	if _opening:
		_opening.queue_free()
	_opening = Control.new()
	_opening.set_anchors_preset(Control.PRESET_FULL_RECT)
	_opening.mouse_filter = Control.MOUSE_FILTER_STOP
	_opening.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			hurry_opening())
	_root.add_child(_opening)
	var black := ColorRect.new()
	black.color = Color(0.02, 0.015, 0.015, 1.0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(black)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_opening.add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(820, 0)
	col.add_theme_constant_override("separation", 26)
	center.add_child(col)
	var labels: Array = []
	for i in lines.size():
		var l := Label.new()
		l.text = String(lines[i])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", TITLE_FONT)
		l.add_theme_font_size_override("font_size", 52 if i == 0 else 27)
		l.add_theme_color_override("font_color", Color(0.86, 0.8, 0.7) if i == 0 else Color(0.72, 0.68, 0.62))
		l.modulate.a = 0.0
		col.add_child(l)
		labels.append(l)
	var go := _button(button_text, func() -> void:
		var o := _opening
		_opening = null
		var fade := create_tween()
		fade.tween_property(o, "modulate:a", 0.0, 0.8)
		fade.tween_callback(o.queue_free)
		opening_done.emit())
	go.alignment = HORIZONTAL_ALIGNMENT_CENTER
	go.add_theme_font_override("font", TITLE_FONT)
	go.custom_minimum_size = Vector2(260, 58)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.modulate.a = 0.0
	go.disabled = true
	col.add_child(go)
	var tw := create_tween()
	tw.tween_interval(0.8)
	for l in labels:
		tw.tween_property(l, "modulate:a", 1.0, 1.6)
		tw.tween_interval(0.9)
	tw.tween_callback(func() -> void: go.disabled = false)
	tw.tween_property(go, "modulate:a", 1.0, 0.8)
	tw.tween_callback(func() -> void: go.grab_focus())
	_opening.set_meta("tween", tw)
	_opening.set_meta("labels", labels)
	_opening.set_meta("button", go)


## Shows the whole opening at once (a player in a hurry pressed something).
func hurry_opening() -> void:
	if _opening == null:
		return
	var tw: Tween = _opening.get_meta("tween")
	if tw and tw.is_valid():
		tw.kill()
	for l in _opening.get_meta("labels"):
		l.modulate.a = 1.0
	var go: Button = _opening.get_meta("button")
	go.disabled = false
	go.modulate.a = 1.0
	go.grab_focus()


## Presses the opening's button (tests).
func finish_opening() -> void:
	if _opening:
		hurry_opening()
		(_opening.get_meta("button") as Button).pressed.emit()


func is_opening_visible() -> bool:
	return _opening != null


# --- Title screen ---------------------------------------------------------------------------

## Shows the title over whatever the camera is looking at. options: [[id, label], ...]
func show_title(options: Array) -> void:
	_clear(_title_menu)
	for o in options:
		var b := _button(String(o[1]), _on_title.bind(String(o[0])))
		b.custom_minimum_size = Vector2(300, 60)
		b.add_theme_font_override("font", TITLE_FONT)
		b.add_theme_font_size_override("font_size", 26)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		_title_menu.add_child(b)
	_title.visible = true
	_title.modulate.a = 0.0
	create_tween().tween_property(_title, "modulate:a", 1.0, 1.2)
	_focus_later(_title_menu.get_child(0) as Control)


func hide_title() -> void:
	if _title:
		_title.visible = false


func is_title_visible() -> bool:
	return _title != null and _title.visible


func _on_title(id: String) -> void:
	title_choice.emit(id)


func _build_title() -> void:
	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.visible = false
	_root.add_child(_title)

	# A soft dark vignette top and bottom, so the words read over the live scene.
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.65, 1.0])
	grad.colors = PackedColorArray([Color(0.05, 0.04, 0.04, 0.75), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0.05, 0.04, 0.04, 0.85)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	shade.texture = tex
	_title.add_child(shade)

	var name_label := Label.new()
	name_label.text = "THE TOWER"
	name_label.add_theme_font_override("font", TITLE_FONT)
	name_label.add_theme_font_size_override("font_size", 112)
	name_label.add_theme_color_override("font_color", Color(0.97, 0.9, 0.74))
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	name_label.add_theme_constant_override("shadow_offset_y", 5)
	name_label.add_theme_constant_override("shadow_offset_x", 0)
	name_label.add_theme_constant_override("shadow_outline_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.anchor_left = 0.0
	name_label.anchor_right = 1.0
	name_label.offset_top = 70
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_child(name_label)

	_title_menu = VBoxContainer.new()
	_title_menu.add_theme_constant_override("separation", 12)
	_title_menu.anchor_left = 0.5
	_title_menu.anchor_right = 0.5
	_title_menu.anchor_top = 1.0
	_title_menu.anchor_bottom = 1.0
	_title_menu.offset_left = -150
	_title_menu.offset_right = 150
	_title_menu.offset_bottom = -60
	_title_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_title.add_child(_title_menu)


# --- Combat ---------------------------------------------------------------------------------

## The climber's wounds, top right. Shown in fights, or whenever they're hurt.
func set_wounds(current: int, maximum: int, in_fight: bool) -> void:
	var pips := ""
	for i in maximum:
		pips += "● " if i < current else "○ "
	_wounds.text = "Wounds  " + pips.strip_edges()
	_wounds.visible = in_fight or current < maximum


## True while the on-screen Block button is held down.
func block_held() -> bool:
	return _pad_buttons.has("block") and _pad_buttons["block"].held


## True when touch controls are in use: a touch screen and no controller in hand.
func is_touch_mode() -> bool:
	if force_touch:
		return true
	var controls := get_node_or_null("/root/Controls")
	var pad: bool = controls != null and controls.using_pad
	return DisplayServer.is_touchscreen_available() and not pad


## The floating stick: shown where the thumb went down, knob where it is now.
func set_stick(active: bool, origin: Vector2 = Vector2.ZERO, knob: Vector2 = Vector2.ZERO) -> void:
	_stick.visible = active
	_stick.set_meta("origin", origin)
	_stick.set_meta("knob", knob)
	_stick.queue_redraw()


## How far a thumb can push the stick, in screen pixels.
func stick_radius() -> float:
	return 70.0


func _process(_delta: float) -> void:
	if _pad == null:
		return
	_pad.visible = touch_actions_enabled and is_touch_mode() and not is_busy() and not _cinematic
	if not _pad.visible and _stick.visible:
		set_stick(false)
	(_pad_buttons["lock"] as PadButton).active = lock_ready
	_fit_safe_area()


## Keeps buttons and text out of notches and rounded corners.
func _fit_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if safe == _safe_key or win.x <= 0 or win.y <= 0 or safe.size.x <= 0:
		return
	_safe_key = safe
	var vp := get_viewport().get_visible_rect().size
	var k := Vector2(vp.x / float(win.x), vp.y / float(win.y))
	var pos := DisplayServer.window_get_position()
	var left := maxf(0.0, float(safe.position.x - pos.x)) * k.x
	var top := maxf(0.0, float(safe.position.y - pos.y)) * k.y
	var right := maxf(0.0, float(pos.x + win.x - safe.end.x)) * k.x
	var bottom := maxf(0.0, float(pos.y + win.y - safe.end.y)) * k.y
	# Desktop windows report odd values; only trust small insets.
	if left > vp.x * 0.15 or right > vp.x * 0.15 or top > vp.y * 0.15 or bottom > vp.y * 0.15:
		return
	_root.offset_left = left
	_root.offset_top = top
	_root.offset_right = -right
	_root.offset_bottom = -bottom


## The on-screen pad: a gamepad-style cluster bottom right. Always there and always the same
## (only Lock dims with no one in reach), so buttons never move, thumbs learn where they are,
## and the pad never hints at what's nearby.
func _build_touch_bar() -> void:
	_pad = Control.new()
	_pad.anchor_left = 1.0
	_pad.anchor_right = 1.0
	_pad.anchor_top = 1.0
	_pad.anchor_bottom = 1.0
	_pad.offset_left = -330
	_pad.offset_top = -300
	_pad.offset_right = 0
	_pad.offset_bottom = 0
	_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pad.visible = false
	_root.add_child(_pad)
	# Laid out like a controller's face buttons, each doing what that button does on a pad:
	# A (bottom) use, X (left) hit, Y (top) kick, B (right) block; L lock on.
	# [id, letter, radius, centre measured from the pad's bottom-right corner]
	var layout := [
		["use", "a", 46.0, Vector2(-150, -70)],
		["strike", "x", 46.0, Vector2(-232, -152)],
		["kick", "y", 46.0, Vector2(-150, -234)],
		["block", "b", 46.0, Vector2(-68, -152)],
		["lock", "l", 36.0, Vector2(-290, -262)],
	]
	for spec in layout:
		var b := PadButton.new()
		b.setup(String(spec[0]), load("res://assets/kenney/mobile-controls/icon_button_%s.png" % spec[1]), float(spec[2]))
		var r: float = spec[2]
		var c: Vector2 = spec[3]
		b.position = Vector2(330, 300) + c - Vector2(r, r)
		b.pressed_id.connect(func(id: String) -> void:
			if id != "block":
				combat_action.emit(id))
		_pad.add_child(b)
		_pad_buttons[String(spec[0])] = b
	_stick = Control.new()
	_stick.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick.visible = false
	_stick.draw.connect(func() -> void:
		var o: Vector2 = _stick.get_meta("origin", Vector2.ZERO)
		var k: Vector2 = _stick.get_meta("knob", Vector2.ZERO)
		var pr := stick_radius() * 1.25
		_stick.draw_texture_rect(STICK_PAD, Rect2(o - Vector2(pr, pr), Vector2(pr, pr) * 2.0), false, Color(1, 1, 1, 0.55))
		_stick.draw_texture_rect(STICK_NUB, Rect2(k - Vector2(38, 38), Vector2(76, 76)), false, Color(1, 1, 1, 0.8)))
	_full.add_child(_stick)


func _build_wounds() -> void:
	_wounds = _label(26, Color(1.0, 0.6, 0.5))
	_wounds.autowrap_mode = TextServer.AUTOWRAP_OFF
	_wounds.anchor_left = 1.0
	_wounds.anchor_right = 1.0
	_wounds.offset_left = -260
	_wounds.offset_right = -20
	_wounds.offset_top = 16
	_wounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wounds.add_theme_color_override("font_outline_color", Color.BLACK)
	_wounds.add_theme_constant_override("outline_size", 8)
	_wounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wounds.visible = false
	_root.add_child(_wounds)


func _on_choice(i: int) -> void:
	choice_made.emit(i)


# --- Cards (title, level end) ---------------------------------------------------------------

func show_card(title: String, body: String, buttons: Array) -> void:
	_card_title.text = title
	_card_body.text = body
	_card_body.visible = body != ""
	_clear(_card_buttons)
	for i in buttons.size():
		_card_buttons.add_child(_button(String(buttons[i]), _on_card.bind(i)))
	_dim.visible = true
	_card.visible = true
	_focus_first(_card_buttons)


func is_card_visible() -> bool:
	return _card.visible


func hide_card() -> void:
	_dim.visible = false
	_card.visible = false


func _on_card(i: int) -> void:
	card_choice.emit(i)


# --- Toasts and dev overlay -----------------------------------------------------------------

func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.visible = true
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func toggle_dev() -> void:
	_dev.visible = not _dev.visible


func is_dev_visible() -> bool:
	return _dev.visible


func set_dev_text(text: String) -> void:
	if _dev.visible:
		_dev.text = text


# --- Construction ---------------------------------------------------------------------------

func _box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(22)
	return sb


func _label(size: int, color: Color = Color(0.93, 0.9, 0.85)) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", TEXT_SIZE)
	b.add_theme_stylebox_override("normal", _box(Color(0.22, 0.19, 0.17, 1.0)))
	b.add_theme_stylebox_override("hover", _box(Color(0.32, 0.27, 0.22, 1.0)))
	b.add_theme_stylebox_override("pressed", _box(Color(0.45, 0.36, 0.24, 1.0)))
	b.add_theme_stylebox_override("focus", _box(Color(0.32, 0.27, 0.22, 1.0)))
	b.pressed.connect(on_pressed)
	return b


## With a controller or keyboard, highlight the first choice so A / Enter picks it and the
## d-pad moves between choices. With touch, leave nothing highlighted.
func _focus_first(container: Node) -> void:
	if container.get_child_count() == 0:
		return
	var controls := get_node_or_null("/root/Controls")
	if controls and (controls.using_pad or controls.has_controller()):
		_focus_later(container.get_child(0) as Control)


## Focuses a control next frame, if it's still on screen by then.
func _focus_later(c: Control) -> void:
	var id := c.get_instance_id()
	(func() -> void:
		var ctl := instance_from_id(id) as Control
		if ctl and ctl.is_inside_tree() and ctl.is_visible_in_tree():
			ctl.grab_focus()).call_deferred()


func _clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _build_dialogue() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.08, 0.07, 0.06, 0.94)))
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 20
	_panel.offset_right = -20
	_panel.offset_top = -20
	_panel.offset_bottom = -20
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.visible = false
	_root.add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_panel.add_child(row)
	_portrait_frame = PanelContainer.new()
	var frame := _box(Color(0.2, 0.17, 0.14, 1.0))
	frame.set_content_margin_all(4)
	frame.border_color = Color(0.55, 0.43, 0.26)
	frame.set_border_width_all(2)
	_portrait_frame.add_theme_stylebox_override("panel", frame)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_portrait_frame.visible = false
	row.add_child(_portrait_frame)
	_portrait = Portrait.new()
	_portrait_frame.add_child(_portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_speaker = _label(TEXT_SIZE - 2, Color(0.88, 0.7, 0.36))
	col.add_child(_speaker)
	_body = _label(TEXT_SIZE)
	col.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	col.add_child(_choices)


func _build_card() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.55)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	_root.add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _box(Color(0.1, 0.085, 0.075, 0.97)))
	_card.custom_minimum_size = Vector2(560, 0)
	_card.visible = false
	center.add_child(_card)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	_card.add_child(col)
	_card_title = _label(40, Color(0.95, 0.82, 0.5))
	_card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_title)
	_card_body = _label(TEXT_SIZE)
	_card_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_card_body)
	_card_buttons = VBoxContainer.new()
	_card_buttons.add_theme_constant_override("separation", 10)
	col.add_child(_card_buttons)


func _build_toast() -> void:
	_toast = _label(28, Color(0.97, 0.9, 0.75))
	_toast.anchor_left = 0.0
	_toast.anchor_right = 1.0
	_toast.offset_top = 24
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override("outline_size", 10)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)


func _build_dev() -> void:
	_dev = _label(16, Color(0.6, 1.0, 0.7))
	_dev.autowrap_mode = TextServer.AUTOWRAP_OFF
	_dev.position = Vector2(12, 12)
	_dev.add_theme_color_override("font_outline_color", Color.BLACK)
	_dev.add_theme_constant_override("outline_size", 6)
	_dev.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dev.visible = false
	_root.add_child(_dev)
