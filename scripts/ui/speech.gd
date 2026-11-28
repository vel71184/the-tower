extends Control
## Speech bubbles in the world. Lines are anchored to whoever says them and queued, so two
## never overlap and it's always clear who spoke.
##
## kinds:
##   "line"    someone speaking: a light bubble with a tail pointing at the speaker
##   "notice"  something the climber notices: a dark, tail-less caption over the thing
## Scenes use interrupt, which clears anything waiting so the scripted line shows at once.

const MAX_WAITING := 4
const GAP := 0.15
const BUBBLE_WIDTH := 380.0
const EDGE := 12.0

const LINE_BG := Color(0.97, 0.94, 0.87, 0.97)
const LINE_INK := Color(0.16, 0.12, 0.1)
const NOTICE_BG := Color(0.1, 0.085, 0.075, 0.9)
const NOTICE_INK := Color(0.95, 0.88, 0.72)

var _queue: Array = []
var _current: Dictionary = {}
var _bubble: PanelContainer
var _text: Label
var _tail: Polygon2D
var _gap := 0.0


func _ready() -> void:
	add_to_group("speech")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = PanelContainer.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.visible = false
	add_child(_bubble)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.add_theme_font_size_override("font_size", 22)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.add_child(_text)
	_tail = Polygon2D.new()
	_tail.polygon = PackedVector2Array([Vector2(-11, 0), Vector2(11, 0), Vector2(0, 14)])
	_tail.visible = false
	add_child(_tail)


## Queues a line over a node. height: how far above the node's origin the bubble points.
func say(anchor: Node3D, height: float, text: String, seconds: float = 2.5, kind: String = "line", interrupt: bool = false) -> void:
	if anchor == null or text == "":
		return
	var item := {"anchor": anchor, "height": height, "text": text, "time": seconds, "kind": kind}
	if interrupt:
		_queue.clear()
		_current = {}
		_gap = 0.0
		_show(item)
		return
	for q in _queue:
		if q["anchor"] == anchor and q["text"] == text:
			return
	if not _current.is_empty() and _current["anchor"] == anchor and _current["text"] == text:
		return
	_queue.append(item)
	while _queue.size() > MAX_WAITING:
		_queue.pop_front()
	if _current.is_empty() and _gap <= 0.0:
		_next()


## Removes everything, shown or waiting (a level is changing, a scene stopped).
func clear() -> void:
	_queue.clear()
	_current = {}
	_bubble.visible = false
	_tail.visible = false


func is_idle() -> bool:
	return _current.is_empty() and _queue.is_empty()


## The line on screen now, or "".
func current_text() -> String:
	return String(_current.get("text", ""))


func waiting() -> int:
	return _queue.size()


func _next() -> void:
	while not _queue.is_empty():
		var item: Dictionary = _queue.pop_front()
		if is_instance_valid(item["anchor"]):
			_show(item)
			return
	_current = {}
	_bubble.visible = false
	_tail.visible = false


func _show(item: Dictionary) -> void:
	_current = item
	_current["left"] = float(item["time"])
	var notice: bool = item["kind"] == "notice"
	var sb := StyleBoxFlat.new()
	sb.bg_color = NOTICE_BG if notice else LINE_BG
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.25)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	_bubble.add_theme_stylebox_override("panel", sb)
	_text.add_theme_color_override("font_color", NOTICE_INK if notice else LINE_INK)
	_text.text = String(item["text"])
	_tail.color = sb.bg_color
	_tail.visible = not notice
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	# Short lines get a snug bubble; long ones wrap at a comfortable width.
	var font := _text.get_theme_font("font")
	var w := font.get_string_size(_text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 40.0
	_bubble.custom_minimum_size = Vector2(minf(BUBBLE_WIDTH, w), 0)
	_bubble.size = Vector2.ZERO
	_text.custom_minimum_size = Vector2(minf(BUBBLE_WIDTH, w) - 36.0, 0)


func _process(delta: float) -> void:
	if _current.is_empty():
		if _gap > 0.0:
			_gap -= delta
			if _gap <= 0.0:
				_next()
		return
	var anchor = _current["anchor"]
	if not is_instance_valid(anchor) or not (anchor as Node3D).is_inside_tree():
		_current = {}
		_next()
		return
	_current["left"] = float(_current["left"]) - delta
	var left: float = _current["left"]
	var shown := float(_current["time"]) - left
	_bubble.modulate.a = clampf(minf(shown / 0.15, left / 0.3), 0.0, 1.0)
	_tail.modulate.a = _bubble.modulate.a
	_place(anchor)
	if left <= 0.0:
		_current = {}
		_bubble.visible = false
		_tail.visible = false
		_gap = GAP
		if _queue.is_empty():
			_gap = 0.0


func _place(anchor: Node3D) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var point: Vector3 = anchor.global_position + Vector3(0, float(_current["height"]), 0)
	if cam.is_position_behind(point):
		_bubble.visible = false
		_tail.visible = false
		return
	_bubble.visible = true
	var notice: bool = _current["kind"] == "notice"
	_tail.visible = not notice
	var screen := get_viewport_rect().size
	var tip := cam.unproject_position(point)
	var box := _bubble.get_combined_minimum_size()
	var x := clampf(tip.x - box.x * 0.5, EDGE, screen.x - box.x - EDGE)
	var y := clampf(tip.y - box.y - 14.0, EDGE, screen.y - box.y - EDGE)
	_bubble.position = Vector2(x, y)
	_bubble.size = box
	_tail.position = Vector2(clampf(tip.x, x + 20.0, x + box.x - 20.0), y + box.y - 1.0)
