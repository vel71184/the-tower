extends Node3D
## Game flow: title, loading levels, tap-to-walk, proximity reactions, dialogue, and level end.

const Level := preload("res://scripts/game/level.gd")
const Climber := preload("res://scripts/game/climber.gd")
const IsoCamera := preload("res://scripts/game/iso_camera.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")
const Interactable := preload("res://scripts/game/interactable.gd")

## "floor-level" -> content file. Levels not listed here aren't built yet.
const LEVELS := {
	"1-1": "res://content/floors/floor_01/level_01.json",
}

const NEAR_LABEL_RANGE := 2.5
const TAP_PICK_PIXELS := 48.0

var level: Level
var climber: Climber
var cam: IsoCamera
var ui: GameUI

var _pending: Interactable = null
var _talk_obj: Interactable = null
var _talk_nodes: Dictionary = {}
var _talk_node_id := ""
var _talk_choices: Array = []
var _card_handler: Callable
var _ended := false
var _marker: MeshInstance3D
var _touches: Dictionary = {}
var _pinch_dist := 0.0


func _ready() -> void:
	_build_world()
	climber = Climber.new()
	add_child(climber)
	climber.arrived.connect(_on_arrived)
	climber.entered_cell.connect(_on_entered_cell)
	cam = IsoCamera.new()
	add_child(cam)
	cam.target = climber
	cam.make_current()
	ui = GameUI.new()
	add_child(ui)
	ui.choice_made.connect(choose)
	ui.card_choice.connect(_on_card_choice)
	Baseline.changed.connect(_refresh_dev)
	show_title()


func _process(_delta: float) -> void:
	_refresh_dev()


# --- Title and level flow -------------------------------------------------------------------

func show_title() -> void:
	var body := "A hundred floors. Ten levels each.\nTap to walk. Tap things to look closer."
	if Baseline.has_save():
		_card("THE TOWER", body, ["Continue the climb", "Start a new climb"], func(i: int) -> void:
			if i == 0:
				Baseline.load_save()
			else:
				Baseline.reset()
				Baseline.delete_save()
			start_level(Baseline.floor_num, Baseline.level_num))
	else:
		_card("THE TOWER", body, ["Begin the climb"], func(_i: int) -> void:
			Baseline.reset()
			start_level(1, 1))


func start_level(floor_n: int, level_n: int) -> bool:
	ui.hide_card()
	ui.hide_page()
	var key := "%d-%d" % [floor_n, level_n]
	if not LEVELS.has(key):
		_card("Floor %d · Level %d" % [floor_n, level_n],
			"This part of the tower isn't built yet.\nYour climb so far is saved.",
			["Start a new climb"], func(_i: int) -> void:
				Baseline.reset()
				Baseline.delete_save()
				start_level(1, 1))
		return false

	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS[key]))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read level %s" % LEVELS[key])
		return false

	if level:
		remove_child(level)
		level.queue_free()
	level = Level.new()
	add_child(level)
	level.build(data)
	climber.level = level
	climber.place(level.spawn_cell)
	cam.snap()
	_pending = null
	_talk_obj = null
	_ended = false
	Baseline.record("entered", String(data.get("id", key)))
	ui.toast(String(data.get("title", key)), 3.0)
	_on_entered_cell(climber.cell)
	return true


func end_level() -> void:
	if _ended:
		return
	_ended = true
	climber.stop()
	_apply_end_rules()
	Baseline.record("completed", String(level.data.get("id", "")))
	Baseline.advance_level()
	Baseline.save()
	var title := "Level %d complete" % int(level.data.get("level", 0))
	_card(title, "Your climb is saved.", ["Climb on"], func(_i: int) -> void:
		start_level(Baseline.floor_num, Baseline.level_num))


## Applies the level's end rules: how the climber handled what they found, missed, or declined.
func _apply_end_rules() -> void:
	var looked := examined_count()
	for rule in level.data.get("end_rules", []):
		var ok := true
		for f in rule.get("if", []):
			ok = ok and Baseline.has_flag(String(f))
		for f in rule.get("unless", []):
			ok = ok and not Baseline.has_flag(String(f))
		if rule.has("min_examined"):
			ok = ok and looked >= int(rule["min_examined"])
		if rule.has("max_examined"):
			ok = ok and looked <= int(rule["max_examined"])
		if ok:
			Baseline.apply(rule.get("effects", {}))


## How many distinct things in this level the climber looked at or talked to.
func examined_count() -> int:
	var seen := {}
	for obj in level.objects:
		if obj.kind != "exit" and Baseline.has_flag("examined:" + obj.id):
			seen[obj.id] = true
	return seen.size()


# --- Input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F3:
		ui.toggle_dev()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				_tap(event.position)
			MOUSE_BUTTON_WHEEL_UP:
				cam.zoom_by(0.9)
			MOUSE_BUTTON_WHEEL_DOWN:
				cam.zoom_by(1.1)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() >= 3:
				ui.toggle_dev()
		else:
			_touches.erase(event.index)
		_pinch_dist = _touch_spread()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 2:
			var d := _touch_spread()
			if _pinch_dist > 0.0 and d > 0.0:
				cam.zoom_by(_pinch_dist / d)
			_pinch_dist = d


func _touch_spread() -> float:
	if _touches.size() != 2:
		return 0.0
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1])


func _tap(screen_pos: Vector2) -> void:
	if level == null or ui.is_busy() or _ended or _touches.size() > 1:
		return
	var obj := _pick_object(screen_pos)
	if obj:
		go_to_object(obj)
		return
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos))
	if hit == null:
		return
	var cell: Vector2i = level.world_to_cell(hit)
	var on_cell := level.object_at(cell)
	if on_cell and on_cell.revealed:
		go_to_object(on_cell)
	else:
		go_to_cell(cell)


## Finds the visible object nearest the tap on screen, so tall things are easy to hit by touch.
func _pick_object(screen_pos: Vector2) -> Interactable:
	var best: Interactable = null
	var best_d := TAP_PICK_PIXELS * (get_viewport().get_visible_rect().size.y / 720.0)
	for obj in level.objects:
		if not obj.revealed or cam.is_position_behind(obj.world_center()):
			continue
		var d := cam.unproject_position(obj.world_center()).distance_to(screen_pos)
		if d < best_d:
			best_d = d
			best = obj
	return best


func go_to_cell(cell: Vector2i) -> bool:
	var path := level.find_path(climber.path_start(), cell)
	if path.is_empty():
		return false
	_pending = null
	_show_marker(cell)
	climber.walk(path)
	return true


func go_to_object(obj: Interactable) -> bool:
	var path := level.path_to_object(climber.path_start(), obj)
	if path.is_empty():
		return false
	_pending = obj
	_show_marker(path[path.size() - 1])
	climber.walk(path)
	return true


func _on_arrived() -> void:
	_marker.visible = false
	if _pending:
		var obj := _pending
		_pending = null
		climber.face(obj.global_position)
		interact(obj)


func _on_entered_cell(cell: Vector2i) -> void:
	for obj in level.objects:
		var d := Vector2(cell).distance_to(Vector2(obj.cell))
		if obj.kind == "hidden" and not obj.revealed and d <= 1.5:
			obj.reveal()
			Baseline.set_flag("noticed:" + obj.id)
			var notice := String(obj.def.get("reveal_text", ""))
			if notice != "":
				obj.bark(notice)
		obj.set_near(d <= NEAR_LABEL_RANGE)
		var callout: Dictionary = obj.def.get("call_out", {})
		if not callout.is_empty():
			var flag := String(callout.get("flag", "heard:" + obj.id))
			if not Baseline.has_flag(flag) and d <= float(callout.get("radius", 3.0)):
				Baseline.set_flag(flag)
				obj.bark(String(callout.get("text", "")))


# --- Dialogue -------------------------------------------------------------------------------

func interact(obj: Interactable) -> void:
	if _ended or not obj.revealed:
		return
	if not Baseline.has_flag("examined:" + obj.id):
		Baseline.set_flag("examined:" + obj.id)
		Baseline.record("examined", obj.id)
	Baseline.apply_once(obj.id, obj.def.get("effects", {}))

	_talk_obj = obj
	_talk_nodes = _dialogue_nodes(obj.def)
	var start := String(obj.def.get("dialogue", {}).get("start", "l0"))
	for rule in obj.def.get("dialogue", {}).get("start_if", []):
		if Baseline.has_flag(String(rule.get("flag", ""))):
			start = String(rule.get("start", start))
			break
	_show_node(start)


## Plain "lines" become a chain of pages; "dialogue" holds branching nodes.
func _dialogue_nodes(def: Dictionary) -> Dictionary:
	if def.has("dialogue"):
		return def["dialogue"].get("nodes", {})
	var nodes := {}
	var lines: Array = def.get("lines", [])
	for i in lines.size():
		nodes["l%d" % i] = {"text": lines[i], "next": ("l%d" % (i + 1)) if i + 1 < lines.size() else ""}
	return nodes


func _show_node(node_id: String) -> void:
	if node_id == "" or not _talk_nodes.has(node_id):
		_end_talk()
		return
	_talk_node_id = node_id
	var node: Dictionary = _talk_nodes[node_id]
	Baseline.apply_once("%s/%s" % [_talk_obj.id, node_id], node.get("effects", {}))
	_talk_choices = []
	for c in node.get("choices", []):
		if c.has("requires") and not Baseline.has_flag(String(c["requires"])):
			continue
		if c.has("hide_if") and Baseline.has_flag(String(c["hide_if"])):
			continue
		_talk_choices.append(c)
	var labels: Array = []
	for c in _talk_choices:
		labels.append(String(c.get("text", "...")))
	var speaker := _talk_obj.display_name
	ui.show_page(speaker, String(node.get("text", "")), labels)


## Picks a dialogue option by index (0 also means "Continue" on pages without choices).
func choose(index: int) -> void:
	if _talk_obj == null:
		return
	var node: Dictionary = _talk_nodes.get(_talk_node_id, {})
	if _talk_choices.is_empty():
		_show_node(String(node.get("next", "")))
		return
	if index < 0 or index >= _talk_choices.size():
		return
	var c: Dictionary = _talk_choices[index]
	Baseline.apply_once("%s/%s/%s" % [_talk_obj.id, _talk_node_id, c.get("text", index)], c.get("effects", {}))
	if String(c.get("action", "")) == "end_level":
		_end_talk()
		end_level()
		return
	_show_node(String(c.get("next", "")))


## Picks the first visible option containing the given text. Used by tests.
func choose_text(fragment: String) -> bool:
	for i in _talk_choices.size():
		if String(_talk_choices[i].get("text", "")).contains(fragment):
			choose(i)
			return true
	return false


func is_talking() -> bool:
	return _talk_obj != null


func _end_talk() -> void:
	_talk_obj = null
	_talk_nodes = {}
	_talk_choices = []
	ui.hide_page()


# --- Helpers --------------------------------------------------------------------------------

func find_object(id: String) -> Interactable:
	for obj in level.objects:
		if obj.id == id:
			return obj
	return null


func _card(title: String, body: String, buttons: Array, handler: Callable) -> void:
	_card_handler = handler
	ui.show_card(title, body, buttons)


func _on_card_choice(i: int) -> void:
	var h := _card_handler
	ui.hide_card()
	if h.is_valid():
		h.call(i)


func _refresh_dev() -> void:
	ui.set_dev_text(Baseline.debug_text())


func _show_marker(cell: Vector2i) -> void:
	_marker.position = level.cell_to_world(cell) + Vector3(0, 0.02, 0)
	_marker.visible = true


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#15110f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8c8070")
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60.0, 30.0, 0.0)
	sun.light_color = Color("#ffe2b8")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_marker = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.3
	disc.bottom_radius = 0.3
	disc.height = 0.02
	_marker.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.8, 0.45, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker.material_override = mat
	_marker.visible = false
	add_child(_marker)
