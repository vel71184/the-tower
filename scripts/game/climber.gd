extends Node3D
## The player character. Walks a grid path one cell at a time.

signal arrived
signal entered_cell(cell: Vector2i)

const SPEED := 3.5

## The current level (level.gd); left untyped so its helpers are called dynamically.
var level
var cell := Vector2i.ZERO
var _path: Array = []


func _ready() -> void:
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.25
	capsule.height = 1.3
	body.mesh = capsule
	body.position = Vector3(0, 0.65, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d9a441")
	body.material_override = mat
	add_child(body)

	# A small pack on the back, so facing reads from above.
	var pack := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.35, 0.15)
	pack.mesh = box
	pack.position = Vector3(0, 0.8, 0.27)
	var pack_mat := StandardMaterial3D.new()
	pack_mat.albedo_color = Color("#6b4a2b")
	pack.material_override = pack_mat
	add_child(pack)


func place(at: Vector2i) -> void:
	_path.clear()
	cell = at
	position = level.cell_to_world(at)


func is_moving() -> bool:
	return not _path.is_empty()


## The cell a new path should start from: where the climber is heading next, or where it stands.
func path_start() -> Vector2i:
	return _path[0] if is_moving() else cell


func walk(path: Array) -> void:
	_path = path.duplicate()
	if _path.is_empty():
		return
	if _path.size() == 1 and _path[0] == cell and position.distance_to(level.cell_to_world(cell)) < 0.01:
		_path.clear()
		arrived.emit()


func stop() -> void:
	_path.clear()


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
			arrived.emit()
