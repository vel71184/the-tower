extends SubViewportContainer
## A head-and-shoulders portrait of a character, drawn live from their model in a small world
## of its own. Shown beside the text in conversations.

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Models := preload("res://scripts/game/models.gd")

const SIZE := 132

var _vp: SubViewport
var _cam: Camera3D
var _holder: Node3D
var _look_key := ""


func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = false
	_vp.size = Vector2i(SIZE * 2, SIZE * 2)
	_vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.26, 0.21, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 150, 0)
	key.light_energy = 1.1
	key.light_color = Color(1.0, 0.92, 0.8)
	_vp.add_child(key)
	_cam = Camera3D.new()
	_cam.fov = 24.0
	_vp.add_child(_cam)
	_holder = Node3D.new()
	_vp.add_child(_holder)


func show_look(look: Dictionary) -> void:
	var key := JSON.stringify(look)
	if key == _look_key:
		return
	_look_key = key
	for c in _holder.get_children():
		c.queue_free()
	var ch := CharacterModel.new()
	_holder.add_child(ch)
	if not ch.build(look):
		return
	Models.outline(ch, 0.01)
	# The model faces -Z; frame the head from slightly to one side.
	var h: float = ch.height
	_cam.position = Vector3(0.45 * h, 0.8 * h, -2.1 * h)
	_cam.look_at(Vector3(0, 0.6 * h, 0), Vector3.UP)
