extends Node3D
## Game flow: title, loading levels, tap-to-walk, proximity reactions, dialogue, and level end.

const Level := preload("res://scripts/game/level.gd")
const Climber := preload("res://scripts/game/climber.gd")
const IsoCamera := preload("res://scripts/game/iso_camera.gd")
const GameUI := preload("res://scripts/ui/game_ui.gd")
const Interactable := preload("res://scripts/game/interactable.gd")
const Combat := preload("res://scripts/game/combat.gd")

## "floor-level" -> content file. Levels not listed here aren't built yet.
## Floor 1 is the tower's exterior and the way in: levels 1-8 are outside (not built yet),
## level 9 is the Waiting Hall just inside the gate, and level 10 is the Gatekeeper.
const LEVELS := {
	"1-9": "res://content/floors/floor_01/level_09.json",
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
var combat: Combat
var _note_open := false
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
	ui.combat_action.connect(func(id: String) -> void: combat.act(id))
	combat = Combat.new()
	add_child(combat)
	combat.setup(self)
	Baseline.changed.connect(_refresh_dev)
	show_title()


func _process(_delta: float) -> void:
	_refresh_dev()
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() >= 0.5:
		if combat.active:
			if combat.is_climber_turn():
				combat.step(screen_to_grid(v))
		else:
			pad_move(v)


# --- Title and level flow -------------------------------------------------------------------

func show_title() -> void:
	var body := "A hundred floors. Ten levels each.\nTap to walk. Tap things to look closer."
	if Baseline.has_save():
		_card("THE TOWER", body, ["Continue the climb", "Start a new climb"], func(i: int) -> void:
			if i == 0 and Baseline.load_save():
				resume_climb()
			else:
				new_climb())
	else:
		_card("THE TOWER", body, ["Begin the climb"], func(_i: int) -> void:
			new_climb())


## Starts over from the first level that exists so far.
func new_climb() -> void:
	Baseline.reset()
	Baseline.delete_save()
	var first := first_built_level()
	start_level(first.x, first.y)


## Picks up a loaded save: inside a level where the climber stopped, or at the next level.
func resume_climb() -> bool:
	var spot: Dictionary = Baseline.resume.duplicate()
	if not start_level(Baseline.floor_num, Baseline.level_num):
		return false
	if int(spot.get("floor", 0)) == Baseline.floor_num and int(spot.get("level", 0)) == Baseline.level_num:
		var c: Array = spot.get("cell", [])
		if c.size() == 2:
			var cell := Vector2i(int(c[0]), int(c[1]))
			if level.is_walkable(cell):
				climber.place(cell)
				cam.snap()
				_on_entered_cell(cell)
	return true


func first_built_level() -> Vector2i:
	var best := Vector2i(999, 999)
	for key in LEVELS:
		var parts := String(key).split("-")
		var at := Vector2i(int(parts[0]), int(parts[1]))
		if at.x < best.x or (at.x == best.x and at.y < best.y):
			best = at
	return best


func start_level(floor_n: int, level_n: int) -> bool:
	ui.hide_card()
	ui.hide_page()
	_note_open = false
	var key := "%d-%d" % [floor_n, level_n]
	if not LEVELS.has(key):
		_card("Floor %d · Level %d" % [floor_n, level_n],
			"This part of the tower isn't built yet.\nYour climb so far is saved.",
			["Start a new climb"], func(_i: int) -> void:
				new_climb())
		return false

	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEVELS[key]))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Could not read level %s" % LEVELS[key])
		return false

	if level:
		remove_child(level)
		level.queue_free()
	var floor_info: Dictionary = {}
	var floor_path := "res://content/floors/floor_%02d/floor.json" % floor_n
	if FileAccess.file_exists(floor_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(floor_path))
		if typeof(parsed) == TYPE_DICTIONARY:
			floor_info = parsed
	level = Level.new()
	add_child(level)
	level.build(data, floor_info)
	climber.level = level
	climber.place(level.spawn_cell)
	cam.snap()
	_pending = null
	_talk_obj = null
	_ended = false
	Baseline.floor_num = floor_n
	Baseline.level_num = level_n
	# Hidden things the climber already found stay found.
	for obj in level.objects:
		if obj.kind == "hidden" and Baseline.has_flag("noticed:" + obj.id):
			obj.reveal()
	Baseline.record("entered", String(data.get("id", key)))
	ui.toast(String(data.get("title", key)), 3.0)
	_on_entered_cell(climber.cell)
	autosave()
	return true


func end_level() -> void:
	if _ended:
		return
	_ended = true
	climber.stop()
	_apply_end_rules()
	Baseline.record("completed", String(level.data.get("id", "")))
	Baseline.advance_level()
	Baseline.resume = {}
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


## Saves mid-level, so closing the app never loses progress. Runs when the app is closed or
## sent to the background, when a level starts, and after every conversation.
func autosave() -> void:
	if level == null or _ended or (combat and combat.active):
		return
	var at := climber.cell
	Baseline.resume = {"floor": Baseline.floor_num, "level": Baseline.level_num, "cell": [at.x, at.y]}
	Baseline.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		autosave()


# --- Input ----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if combat.active and _combat_input(event):
		return
	if event.is_action_pressed("dev_overlay"):
		ui.toggle_dev()
	elif event.is_action_pressed("interact"):
		pad_interact()
	elif event.is_action_pressed("zoom_in"):
		cam.zoom_by(0.85)
	elif event.is_action_pressed("zoom_out"):
		cam.zoom_by(1.15)
	elif event.is_action_pressed("cancel"):
		if level and not ui.is_busy():
			_pending = null
			climber.stop()
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


## Fight controls: face buttons or 1-5 act; taps walk (or strike someone in reach).
func _combat_input(event: InputEvent) -> bool:
	var map := {"combat_strike": "strike", "combat_shove": "shove", "combat_guard": "guard",
		"combat_talk": "talk", "combat_end_turn": "wait"}
	for action in map:
		if event.is_action_pressed(action):
			if combat.is_climber_turn():
				combat.act(map[action])
			return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if ui.is_busy() or not combat.is_climber_turn():
			return true
		var obj := _pick_object(event.position)
		if obj and combat.foes.has(obj) and level.chebyshev(obj.cell, climber.cell) <= 1:
			combat.act("strike")
			return true
		var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
			cam.project_ray_origin(event.position), cam.project_ray_normal(event.position))
		if hit != null:
			combat.move_to(level.world_to_cell(hit))
		return true
	return event.is_action_pressed("interact") or event.is_action_pressed("cancel")


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
		_use(obj)


## Turns to face something and uses it: people turn back, things get an interact animation.
func _use(obj: Interactable) -> void:
	climber.face(obj.global_position)
	var d := obj.cell - climber.cell
	if d != Vector2i.ZERO:
		facing_step = Vector2i(signi(d.x), signi(d.y))
	if obj.kind == "npc":
		obj.face(climber.global_position)
	elif obj.kind != "exit":
		climber.act("interact-right")
	interact(obj)


# --- Controller and keyboard ----------------------------------------------------------------

## Grid direction the climber last moved or turned toward. Starts facing the camera.
var facing_step := Vector2i(1, 1)


## Converts a stick or d-pad direction on screen into a grid step (8 directions).
## The camera looks from the +X/+Z corner, so screen-up is grid (-1, -1) and
## screen-right is grid (+1, -1).
static func screen_to_grid(v: Vector2) -> Vector2i:
	var g := Vector2(v.x + v.y, v.y - v.x)
	if g.length() < 0.01:
		return Vector2i.ZERO
	g = g.normalized()
	return Vector2i(int(signf(g.x)) if absf(g.x) > 0.38 else 0,
		int(signf(g.y)) if absf(g.y) > 0.38 else 0)


## One step of stick/d-pad walking. Returns true if a step was queued.
func pad_move(v: Vector2) -> bool:
	if level == null or ui.is_busy() or _ended:
		return false
	if climber.steps_left() > 1:
		return false
	var step := screen_to_grid(v)
	if step == Vector2i.ZERO:
		return false
	var from := climber.path_start()
	var to := from + step
	facing_step = step
	if not _can_step(from, to):
		if not climber.is_moving():
			climber.face(level.cell_to_world(to))
		return false
	if climber.is_moving() and climber.steps_left() == 1 and from == to:
		return false
	_pending = null
	_marker.visible = false
	climber.walk([from, to])
	return true


func _can_step(from: Vector2i, to: Vector2i) -> bool:
	if not level.is_walkable(to):
		return false
	if from.x != to.x and from.y != to.y:
		return level.is_walkable(Vector2i(to.x, from.y)) and level.is_walkable(Vector2i(from.x, to.y))
	return true


## The interact button: use whatever the climber is facing, or the nearest thing in reach.
func pad_interact() -> bool:
	if level == null or ui.is_busy() or _ended or climber.is_moving():
		return false
	var obj := object_in_reach()
	if obj == null:
		return false
	_use(obj)
	return true


func object_in_reach() -> Interactable:
	var ahead := level.object_at(climber.cell + facing_step)
	if ahead and ahead.revealed:
		return ahead
	var under := level.object_at(climber.cell)
	if under and under.revealed:
		return under
	var best: Interactable = null
	var best_score := -INF
	var facing := Vector2(facing_step).normalized()
	for obj in level.objects:
		var d: Vector2i = obj.cell - climber.cell
		if not obj.revealed or maxi(absi(d.x), absi(d.y)) > 1:
			continue
		var score := Vector2(d).normalized().dot(facing)
		if score > best_score:
			best_score = score
			best = obj
	return best


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
		if Baseline.has_flag(String(rule.get("flag", ""))) \
				and not (rule.has("unless") and Baseline.has_flag(String(rule["unless"]))):
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
		if c.has("requires_knowledge") and not Baseline.knows(String(c["requires_knowledge"])):
			continue
		if c.get("requires_hurt", false) and Baseline.wounds >= Baseline.max_wounds:
			continue
		_talk_choices.append(c)
	var labels: Array = []
	for c in _talk_choices:
		labels.append(String(c.get("text", "...")))
	var speaker := _talk_obj.display_name
	ui.show_page(speaker, String(node.get("text", "")), labels)


## Picks a dialogue option by index (0 also means "Continue" on pages without choices).
func choose(index: int) -> void:
	if _note_open:
		_close_note()
		return
	if combat.active and combat.handle_choice(index):
		return
	if _talk_obj == null:
		return
	var node: Dictionary = _talk_nodes.get(_talk_node_id, {})
	if _talk_choices.is_empty():
		if node.has("action"):
			var obj := _talk_obj
			_end_talk()
			_do_action(String(node["action"]), obj)
			return
		_show_node(String(node.get("next", "")))
		return
	if index < 0 or index >= _talk_choices.size():
		return
	var c: Dictionary = _talk_choices[index]
	Baseline.apply_once("%s/%s/%s" % [_talk_obj.id, _talk_node_id, c.get("text", index)], c.get("effects", {}))
	if c.has("action"):
		var obj := _talk_obj
		_end_talk()
		_do_action(String(c["action"]), obj)
		return
	_show_node(String(c.get("next", "")))


## Things a dialogue choice can do besides talking:
##   end_level | rest | leave (the speaker walks off) | fight:<id>[:<opening action>]
func _do_action(action: String, obj: Interactable) -> void:
	var parts := action.split(":")
	match parts[0]:
		"end_level":
			end_level()
		"rest":
			Baseline.rest()
			ui.set_wounds(Baseline.wounds, Baseline.max_wounds, false)
			ui.toast("You rest until your wounds close.", 2.5)
			autosave()
		"leave":
			if obj and is_instance_valid(obj):
				level.remove_object(obj)
			autosave()
		"fight":
			var id := parts[1] if parts.size() > 1 else ""
			var data: Dictionary = level.data.get("fights", {}).get(id, {})
			if data.is_empty():
				push_error("No fight '%s' in this level" % id)
				return
			combat.start(id, data, parts[2] if parts.size() > 2 else "")
		_:
			push_warning("Unknown dialogue action '%s'" % action)


## A narration page with a Continue button (e.g. how a fight ended).
func show_note(text: String) -> void:
	_note_open = true
	ui.show_page("", text, [])


func _close_note() -> void:
	_note_open = false
	ui.hide_page()
	if climber.character and climber.character._held:
		climber.character.release()
	ui.set_wounds(Baseline.wounds, Baseline.max_wounds, false)
	autosave()


func climber_bark(text: String) -> void:
	climber.bark(text)


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
	autosave()


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
