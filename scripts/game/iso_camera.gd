extends Camera3D
## Fixed isometric camera that follows a target. Zoom with the wheel or a pinch.

const DISTANCE := 30.0
const MIN_SIZE := 5.0
const MAX_SIZE := 16.0

var target: Node3D


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = 7.0
	near = 0.1
	far = 100.0
	rotation_degrees = Vector3(-35.264, 45.0, 0.0)


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(_goal(), minf(1.0, delta * 6.0))


func snap() -> void:
	if target:
		global_position = _goal()


func zoom_by(factor: float) -> void:
	size = clampf(size * factor, MIN_SIZE, MAX_SIZE)


func _goal() -> Vector3:
	return target.global_position + Vector3(0, 0.5, 0) + global_transform.basis.z * DISTANCE
