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
	"1-1": "res://content/floors/floor_01/level_01.json",
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
var _focus_ring: MeshInstance3D
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
	ui.combat_action.connect(_on_combat_button)
	combat = Combat.new()
	add_child(combat)
	combat.setup(self)
	Baseline.changed.connect(_refresh_dev)
	show_title()


func _process(delta: float) -> void:
	_refresh_dev()
	if level == null or _ended:
		return
	var free := not ui.is_busy() and not _note_open
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down") if free else Vector2.ZERO
	climber.move_free(screen_to_world(v), delta)
	combat.set_blocking(free and (Input.is_action_pressed("block") or ui.block_held()))
	_update_focus()


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
	combat.reset(level)
	ui.touch_actions_enabled = true
	_focus = null
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
	if data.has("hint"):
		var hint := String(data["hint"])
		get_tree().create_timer(3.2).timeout.connect(func() -> void:
			if level and level.data == data:
				ui.toast(hint, 4.0))
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
	var body := "Your climb is saved."
	var next := next_built_level(Vector2i(Baseline.floor_num, Baseline.level_num))
	if next.x > 0 and next != Vector2i(Baseline.floor_num, Baseline.level_num):
		body += "\nThe next levels aren't built yet, so you'll skip ahead to level %d." % next.y
		Baseline.floor_num = next.x
		Baseline.level_num = next.y
	Baseline.resume = {}
	Baseline.save()
	var title := "Level %d complete" % int(level.data.get("level", 0))
	_card(title, body, ["Climb on"], func(_i: int) -> void:
		start_level(Baseline.floor_num, Baseline.level_num))


## The first built level at or after a floor/level, or (-1, -1) if none.
func next_built_level(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	for key in LEVELS:
		var parts := String(key).split("-")
		var at := Vector2i(int(parts[0]), int(parts[1]))
		var after := at.x > from.x or (at.x == from.x and at.y >= from.y)
		var earlier := best.x < 0 or at.x < best.x or (at.x == best.x and at.y < best.y)
		if after and earlier:
			best = at
	return best


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
	if event.is_action_pressed("dev_overlay"):
		ui.toggle_dev()
	elif level == null or ui.is_busy() or _ended:
		pass
	elif event.is_action_pressed("interact"):
		pad_interact()
	elif event.is_action_pressed("attack"):
		combat.strike()
	elif event.is_action_pressed("kick"):
		combat.kick()
	elif event.is_action_pressed("lock_on"):
		combat.toggle_lock()
	elif event.is_action_pressed("lock_next"):
		combat.cycle_lock()
	elif event.is_action_pressed("zoom_in"):
		cam.zoom_by(0.85)
	elif event.is_action_pressed("zoom_out"):
		cam.zoom_by(1.15)
	if event is InputEventMouseButton and event.pressed:
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


func _on_combat_button(id: String) -> void:
	match id:
		"strike":
			combat.strike()
		"kick":
			combat.kick()
		"lock":
			combat.toggle_lock()
		"talk":
			if not combat.talk():
				pad_interact()


func _tap(screen_pos: Vector2) -> void:
	if level == null or ui.is_busy() or _ended or _touches.size() > 1:
		return
	var obj := _pick_object(screen_pos)
	if obj and combat.active and obj.kind == "npc":
		combat._set_lock(obj)
		return
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
	if obj.kind == "npc":
		obj.face(climber.global_position)
	elif obj.kind != "exit":
		climber.act("interact-right")
	interact(obj)


# --- Controller and keyboard ----------------------------------------------------------------

## What the interact button would use right now (highlighted in the world), or null.
var _focus: Interactable = null


## Converts a stick or key direction on screen into a flat world direction for walking.
## The camera looks from the +X/+Z corner, so screen-up is world (-1, 0, -1).
static func screen_to_world(v: Vector2) -> Vector3:
	if v.length() < 0.05:
		return Vector3.ZERO
	var up := Vector3(-1, 0, -1).normalized()
	var right := Vector3(1, 0, -1).normalized()
	return (right * v.x + up * -v.y).limit_length(1.0)


## Picks the thing the climber would interact with: close by, and mostly in front.
func focus_object() -> Interactable:
	var best: Interactable = null
	var best_score := INF
	for obj in level.objects:
		if not obj.revealed or obj.kind == "":
			continue
		var to: Vector3 = obj.global_position - climber.global_position
		to.y = 0.0
		var d := to.length()
		if d > 1.7:
			continue
		var facing := climber.facing_dir.dot(to.normalized()) if d > 0.05 else 1.0
		if d > 1.0 and facing < 0.3:
			continue
		var score := d - facing * 0.8
		if score < best_score:
			best_score = score
			best = obj
	return best


func _update_focus() -> void:
	var f := focus_object()
	if f != _focus:
		_focus = f
		_show_focus_ring(f)


## The interact button: talk to a foe mid-fight, or use whatever is highlighted.
func pad_interact() -> bool:
	if level == null or ui.is_busy() or _ended:
		return false
	if combat.active and (_focus == null or combat.is_foe(_focus)):
		return combat.talk()
	var obj := focus_object()
	if obj == null:
		return false
	climber.stop()
	_use(obj)
	return true


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
	if combat.handle_choice(index):
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
			var foe := obj
			var fight: Dictionary = level.data.get("fights", {}).get(id, {})
			if not fight.is_empty():
				foe = find_object(String((fight.get("opponents", [""]) as Array)[0]))
			if foe == null:
				push_error("No one to fight for '%s'" % action)
				return
			combat.start_from_dialogue(foe, parts[2] if parts.size() > 2 else "")
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


## A soft ring under whatever the interact button would use.
func _show_focus_ring(obj: Interactable) -> void:
	if _focus_ring == null:
		_focus_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.38
		ring.outer_radius = 0.46
		ring.rings = 24
		_focus_ring.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.45, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_focus_ring.material_override = mat
		add_child(_focus_ring)
	_focus_ring.visible = obj != null
	if obj:
		_focus_ring.global_position = obj.global_position + Vector3(0, 0.03, 0)
		obj.set_near(true)


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
