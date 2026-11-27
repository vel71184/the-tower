extends Node3D
## The player character. Walks a grid path one cell at a time.

signal arrived
signal entered_cell(cell: Vector2i)

const SPEED := 3.5
## Free (stick/keyboard) walking.
const WALK_SPEED := 3.4
const RADIUS := 0.26

## The current level (level.gd); left untyped so its helpers are called dynamically.
var level
var cell := Vector2i.ZERO
## The CharacterModel (scripts/characters/character_model.gd).
var character
## World direction the climber faces (flat). Free movement, attacks and interactions use it.
var facing_dir := Vector3(1, 0, 1).normalized()
var _path: Array = []
var _free_moving := false
var _speech: Label3D

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Looks := preload("res://scripts/characters/looks.gd")


func _ready() -> void:
	character = CharacterModel.new()
	add_child(character)
	if not character.build(Looks.climber_look()):
		push_error("Could not build the climber")


func place(at: Vector2i) -> void:
	_path.clear()
	cell = at
	position = level.cell_to_world(at)


## Cells still to walk, counting the one currently being walked to.
func steps_left() -> int:
	return _path.size()


func is_moving() -> bool:
	return not _path.is_empty()


## The cell a new path should start from: where the climber is heading next, or where it stands.
func path_start() -> Vector2i:
	return _path[0] if is_moving() else cell


func walk(path: Array) -> void:
	_path = path.duplicate()
	character.set_moving(not _path.is_empty())
	if _path.is_empty():
		return
	if _path.size() == 1 and _path[0] == cell and position.distance_to(level.cell_to_world(cell)) < 0.01:
		_path.clear()
		character.set_moving(false)
		arrived.emit()


func stop() -> void:
	_path.clear()
	character.set_moving(false)


## The climber speaking: a line over their head for a few seconds (cutscenes, asides).
func say(text: String, seconds: float = 2.5) -> void:
	if _speech and is_instance_valid(_speech):
		_speech.queue_free()
	_speech = Label3D.new()
	_speech.text = text
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.font_size = 38
	_speech.outline_size = 12
	_speech.pixel_size = 0.006
	_speech.width = 520
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.position = Vector3(0, 1.75, 0)
	add_child(_speech)
	var l := _speech
	var t := create_tween()
	t.tween_interval(maxf(0.3, seconds - 0.4))
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)


## A short line floating over the climber (e.g. "-1 wound").
func bark(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.outline_size = 12
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.85, 0.5)
	l.position = Vector3(0, 1.5, 0)
	add_child(l)
	var t := create_tween()
	t.tween_interval(1.6)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


## Plays a one-off animation, e.g. "interact-right" when examining something.
func act(animation: String) -> void:
	character.act(animation)


func face(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x, position.y, world_pos.z)
	if flat.distance_to(position) > 0.01:
		look_at(flat, Vector3.UP)
		facing_dir = (flat - position).normalized()


## Smooth walking from a stick or keys. dir is a flat world direction; its length (0-1) is speed.
## Slides along walls and around people instead of stopping dead.
func move_free(dir: Vector3, delta: float) -> void:
	if dir.length() < 0.05:
		if _free_moving:
			_free_moving = false
			character.set_moving(false)
		return
	_path.clear()
	_free_moving = true
	character.set_moving(true)
	var step := dir.limit_length(1.0) * WALK_SPEED * delta
	var p := position
	var try_x := p + Vector3(step.x, 0, 0)
	if level.can_stand(try_x, RADIUS, cell):
		p = try_x
	var try_z := p + Vector3(0, 0, step.z)
	if level.can_stand(try_z, RADIUS, cell):
		p = try_z
	position = p
	face(position + dir)
	_update_cell()


## Pushed by a hit: slides back as far as the floor allows.
func knock_back(dir: Vector3, distance: float) -> void:
	_path.clear()
	var steps := 6
	for i in steps:
		var try := position + dir.normalized() * distance / steps
		if level.can_stand(try, RADIUS, cell):
			position = try
	_update_cell()


func _update_cell() -> void:
	var c: Vector2i = level.world_to_cell(position)
	if c != cell:
		cell = c
		entered_cell.emit(cell)


func _process(delta: float) -> void:
	if _path.is_empty():
		return
	var next: Vector2i = _path[0]
	var target: Vector3 = level.cell_to_world(next)
	face(target)
	position = position.move_toward(target, SPEED * delta)
	if position.distance_to(target) < 0.001:
		_path.pop_front()
		if next != cell:
			cell = next
			entered_cell.emit(cell)
		if _path.is_empty():
			character.set_moving(false)
			arrived.emit()
