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
## While locked on, the climber keeps facing this person, even while walking (strafing).
var lock_face: Node3D = null
var _path: Array = []
var _free_moving := false

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Looks := preload("res://scripts/characters/looks.gd")
const Models := preload("res://scripts/game/models.gd")
const Pop := preload("res://scripts/ui/pop.gd")


func _ready() -> void:
	character = CharacterModel.new()
	add_child(character)
	if not character.build(Looks.climber_look()):
		push_error("Could not build the climber")
	Models.outline(character, 0.012)


func place(at: Vector2i) -> void:
	_path.clear()
	_free_moving = false
	if character:
		character.set_moving(false)
	cell = at
	position = level.cell_to_world(at)


## Cells still to walk, counting the one currently being walked to.
func is_moving() -> bool:
	return not _path.is_empty()


## The cell a new path should start from: where the climber is heading next, or where it stands.
func path_start() -> Vector2i:
	if is_moving():
		return _path[0]
	return cell if level.is_walkable(cell) else level.path_cell_at(position)


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


## The climber speaking (scenes, asides): shown at once, ahead of anything waiting.
func say(text: String, seconds: float = 2.5) -> void:
	var sp = get_tree().get_first_node_in_group("speech") if is_inside_tree() else null
	if sp:
		sp.say(self, 1.25, text, seconds, "line", true)


## A quick word or number popping off the climber (e.g. "-1 wound").
func bark(text: String) -> void:
	Pop.spawn(self, text, 1.4)


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
	if level.can_stand(try_x, RADIUS, cell, null, p):
		p = try_x
	var try_z := p + Vector3(0, 0, step.z)
	if level.can_stand(try_z, RADIUS, cell, null, p):
		p = try_z
	position = p
	if lock_face and is_instance_valid(lock_face) and lock_face.is_inside_tree():
		face(lock_face.global_position)
	else:
		face(position + dir)
	_update_cell()


## Pushed by a hit: slides back as far as the floor allows.
func knock_back(dir: Vector3, distance: float) -> void:
	_path.clear()
	var steps := 6
	for i in steps:
		var try := position + dir.normalized() * distance / steps
		if level.can_stand(try, RADIUS, cell, null, position):
			position = try
	_update_cell()


func _update_cell() -> void:
	var c: Vector2i = level.world_to_cell(position)
	if c != cell:
		cell = c
		entered_cell.emit(cell)


func _process(delta: float) -> void:
	if _path.is_empty():
		if lock_face and is_instance_valid(lock_face) and lock_face.is_inside_tree() and not _free_moving:
			face(lock_face.global_position)
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
