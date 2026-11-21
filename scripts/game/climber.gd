extends Node3D
## The player character. Walks a grid path one cell at a time.

signal arrived
signal entered_cell(cell: Vector2i)

const SPEED := 3.5

## The current level (level.gd); left untyped so its helpers are called dynamically.
var level
var cell := Vector2i.ZERO
## The CharacterModel (scripts/characters/character_model.gd).
var character
var _path: Array = []

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


## Plays a one-off animation, e.g. "interact-right" when examining something.
func act(animation: String) -> void:
	character.act(animation)


func face(world_pos: Vector3) -> void:
	var flat := Vector3(world_pos.x, position.y, world_pos.z)
	if flat.distance_to(position) > 0.01:
		look_at(flat, Vector3.UP)


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
