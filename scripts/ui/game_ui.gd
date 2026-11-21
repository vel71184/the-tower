extends CanvasLayer
## All on-screen UI, built in code: the dialogue panel, title and end cards, toasts, and a
## developer-only baseline overlay. Sized for phones first (large text and buttons).

signal choice_made(index: int)
signal card_choice(index: int)
signal combat_action(id: String)

const TEXT_SIZE := 24
const BUTTON_HEIGHT := 60

var _root: Control
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
var _combat: PanelContainer
var _combat_hint: Label
var _combat_buttons: HBoxContainer
var _wounds: Label
var _touch_bar: VBoxContainer
var _block_button: Button
## Set once a level is playing, so touch action buttons can show.
var touch_actions_enabled := false


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_build_dialogue()
	_build_card()
	_build_toast()
	_build_dev()
	_build_combat()
	_build_touch_bar()


# --- Dialogue -------------------------------------------------------------------------------

func show_page(speaker: String, text: String, choices: Array) -> void:
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
	return _panel.visible or _card.visible


# --- Combat ---------------------------------------------------------------------------------

## Shows the action bar for the climber's turn. options: [{"id", "label", "enabled"}].
## Buttons can't take focus, so the d-pad keeps walking; pads use face buttons instead.
func show_combat(options: Array, hint: String) -> void:
	_combat_hint.text = hint
	_clear(_combat_buttons)
	for o in options:
		var b := _button(String(o["label"]) + _pad_hint(String(o["id"])), _on_combat.bind(String(o["id"])))
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not bool(o.get("enabled", true))
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_combat_buttons.add_child(b)
	_combat.visible = true


func hide_combat() -> void:
	_combat.visible = false


func is_combat_bar_visible() -> bool:
	return _combat.visible


## The climber's wounds, top right. Shown in fights, or whenever they're hurt.
func set_wounds(current: int, maximum: int, in_fight: bool) -> void:
	var pips := ""
	for i in maximum:
		pips += "● " if i < current else "○ "
	_wounds.text = "Wounds  " + pips.strip_edges()
	_wounds.visible = in_fight or current < maximum


## True while the on-screen Block button is held down.
func block_held() -> bool:
	return _block_button != null and _block_button.button_pressed and _touch_bar.visible


func _process(_delta: float) -> void:
	if _touch_bar == null:
		return
	var controls := get_node_or_null("/root/Controls")
	var pad: bool = controls != null and controls.using_pad
	_touch_bar.visible = touch_actions_enabled and not pad and not is_busy()


func _build_touch_bar() -> void:
	_touch_bar = VBoxContainer.new()
	_touch_bar.anchor_left = 1.0
	_touch_bar.anchor_right = 1.0
	_touch_bar.anchor_top = 1.0
	_touch_bar.anchor_bottom = 1.0
	_touch_bar.offset_left = -170
	_touch_bar.offset_right = -20
	_touch_bar.offset_bottom = -20
	_touch_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_touch_bar.add_theme_constant_override("separation", 10)
	_touch_bar.visible = false
	_root.add_child(_touch_bar)
	for id in ["talk", "lock", "kick", "strike"]:
		var label: String = {"talk": "Talk", "lock": "Lock on", "kick": "Kick", "strike": "Attack"}[id]
		var b := _button(label, _on_combat.bind(id))
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(150, 64)
		_touch_bar.add_child(b)
	_block_button = _button("Block (hold)", func() -> void: pass)
	_block_button.focus_mode = Control.FOCUS_NONE
	_block_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_block_button.toggle_mode = false
	_block_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	_block_button.custom_minimum_size = Vector2(150, 64)
	_touch_bar.add_child(_block_button)


func _pad_hint(id: String) -> String:
	var controls := get_node_or_null("/root/Controls")
	if controls == null or not (controls.using_pad or controls.has_controller()):
		return ""
	return {"strike": "  (A)", "shove": "  (X)", "guard": "  (B)", "talk": "  (Y)", "wait": "  (Start)"}.get(id, "")


func _on_combat(id: String) -> void:
	combat_action.emit(id)


func _build_combat() -> void:
	_combat = PanelContainer.new()
	_combat.add_theme_stylebox_override("panel", _box(Color(0.12, 0.06, 0.05, 0.94)))
	_combat.anchor_left = 0.0
	_combat.anchor_right = 1.0
	_combat.anchor_top = 1.0
	_combat.anchor_bottom = 1.0
	_combat.offset_left = 20
	_combat.offset_right = -20
	_combat.offset_top = -20
	_combat.offset_bottom = -20
	_combat.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_combat.visible = false
	_root.add_child(_combat)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_combat.add_child(col)
	_combat_hint = _label(TEXT_SIZE - 2, Color(0.95, 0.75, 0.6))
	col.add_child(_combat_hint)
	_combat_buttons = HBoxContainer.new()
	_combat_buttons.add_theme_constant_override("separation", 8)
	col.add_child(_combat_buttons)

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
		(container.get_child(0) as Control).call_deferred("grab_focus")


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

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_panel.add_child(col)
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
