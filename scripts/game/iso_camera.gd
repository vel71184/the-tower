extends Camera3D
## Follows a target from a fixed corner with a slight perspective, so the view still reads as
## isometric but tall things (trees, the tower) have real depth. Zoom with the wheel or a pinch.

## Narrow field of view: close to isometric, with just enough perspective for depth.
const FOV := 30.0
const TILT := -48.0
const YAW := 45.0
## How much of the world shows top to bottom at the default zoom, on a 16:9 screen.
const VIEW_HEIGHT := 8.0
const MIN_VIEW := 5.0
const MAX_VIEW := 17.0

var target: Node3D
## Visible world height at the target; zoom changes this.
var view_height := VIEW_HEIGHT


func _ready() -> void:
	projection = PROJECTION_PERSPECTIVE
	fov = FOV
	near = 0.5
	far = 200.0
	rotation_degrees = Vector3(TILT, YAW, 0.0)
	view_height = default_view()


func _process(delta: float) -> void:
	if target:
		global_position = global_position.lerp(_goal(), minf(1.0, delta * 6.0))


func snap() -> void:
	if target:
		global_position = _goal()


func zoom_by(factor: float) -> void:
	view_height = clampf(view_height * factor, MIN_VIEW, MAX_VIEW)


## Wide phones (20:9 and up) are short; pull back a little so they don't feel cramped.
func default_view() -> float:
	var vp := get_viewport()
	if vp == null:
		return VIEW_HEIGHT
	var s := vp.get_visible_rect().size
	var aspect := s.x / maxf(1.0, s.y)
	return VIEW_HEIGHT * clampf(aspect / (16.0 / 9.0), 1.0, 1.2)


func distance() -> float:
	return view_height * 0.5 / tan(deg_to_rad(FOV * 0.5))


func _goal() -> Vector3:
	return target.global_position + Vector3(0, 0.6, 0) + global_transform.basis.z * distance()
