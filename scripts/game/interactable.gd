extends Node3D
## Anything the climber can tap to examine, talk to, or use. Built from a level's object entry.
##
## kinds: "examine" (things to look at), "npc" (people), "hidden" (unseen until the climber is
## close), "exit" (leaves the level). Art is placeholder geometry until the Kenney packs go in.

var def: Dictionary = {}
var id := ""
var kind := "examine"
var display_name := ""
var cell := Vector2i.ZERO
var blocking := true
var revealed := true

## For people: their CharacterModel (scripts/characters/character_model.gd).
var character = null
## The look the person was built from (for their portrait in conversations).
var resolved_look: Dictionary = {}

var _label: Label3D
var _status: Label3D
var _lock_mark: Label3D
var _top := 1.0

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Models := preload("res://scripts/game/models.gd")
const Looks := preload("res://scripts/characters/looks.gd")
const Pop := preload("res://scripts/ui/pop.gd")


func setup(d: Dictionary, at_cell: Vector2i, world_pos: Vector3, material_for: Callable, people: Dictionary = {}) -> void:
	def = d
	id = String(d.get("id", "object"))
	kind = String(d.get("kind", "examine"))
	display_name = String(d.get("name", id))
	cell = at_cell
	blocking = bool(d.get("blocking", kind != "hidden"))
	revealed = kind != "hidden"
	position = world_pos
	name = id.to_pascal_case()

	if kind == "npc" and not d.has("shape"):
		_build_character(d.get("look", {}), people)
	elif d.has("model"):
		_build_model(d)
		if d.has("sign"):
			_build_sign(d["sign"])
	else:
		var color := Color(String(d.get("color", "#b8a48a")))
		_build_shape(String(d.get("shape", "box")), d.get("size", []), material_for.call(color))

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 48
	_label.outline_size = 14
	_label.pixel_size = 0.006
	_label.position = Vector3(0, _top + 0.35, 0)
	_label.visible = false
	add_child(_label)

	visible = revealed


func top_height() -> float:
	return _top


func world_center() -> Vector3:
	return global_position + Vector3(0, _top * 0.5, 0)


func set_near(near: bool) -> void:
	_label.visible = near and revealed


func reveal() -> void:
	if revealed:
		return
	revealed = true
	visible = true
	scale = Vector3(0.6, 0.6, 0.6)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)


## Someone speaking in a scene: shown at once, ahead of anything waiting.
func say(text: String, seconds: float = 2.5) -> void:
	var sp = _speech()
	if sp:
		sp.say(self, _top + 0.25, text, seconds, "line", true)


## A line spoken in passing (a call-out, a reply mid-fight). Queued behind other lines.
func bark(text: String) -> void:
	var sp = _speech()
	if sp:
		sp.say(self, _top + 0.25, text, 2.8, "line")


## Something the climber notices about this thing ("Something pale in the grass.").
func notice(text: String) -> void:
	var sp = _speech()
	if sp:
		sp.say(self, _top + 0.2, text, 2.8, "notice")


## A quick word or number popping off someone (a hit, a stagger). Not queued.
func pop(text: String) -> void:
	Pop.spawn(self, text, _top + 0.3)


func _speech():
	return get_tree().get_first_node_in_group("speech") if is_inside_tree() else null


## Turns a person to face a point in the world.
func face(world_pos: Vector3) -> void:
	if character == null:
		return
	var flat := Vector3(world_pos.x, global_position.y, world_pos.z)
	if flat.distance_to(global_position) > 0.01:
		character.look_at(flat, Vector3.UP)


## A short status shown over someone, e.g. their wounds in a fight. Empty hides it.
func set_status(text: String) -> void:
	if _status == null:
		_status = Label3D.new()
		_status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_status.no_depth_test = true
		_status.font_size = 44
		_status.outline_size = 12
		_status.pixel_size = 0.006
		_status.modulate = Color(1.0, 0.55, 0.45)
		_status.position = Vector3(0, _top + 0.62, 0)
		add_child(_status)
	_status.text = text
	_status.visible = text != ""


## Shows or hides the lock-on marker over someone.
func set_locked(on: bool) -> void:
	if _lock_mark == null:
		_lock_mark = Label3D.new()
		_lock_mark.text = "▼"
		_lock_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_lock_mark.no_depth_test = true
		_lock_mark.font_size = 56
		_lock_mark.outline_size = 12
		_lock_mark.pixel_size = 0.006
		_lock_mark.modulate = Color(1.0, 0.8, 0.3)
		_lock_mark.position = Vector3(0, _top + 0.95, 0)
		add_child(_lock_mark)
	_lock_mark.visible = on


## Plays a one-off animation on a person, e.g. "emote-yes".
func act(animation: String) -> void:
	if character:
		character.act(animation)


## A Kenney model as this object's look, e.g. "model": "fantasy-town/cart", "rot": 70.
## Hidden things don't know their height until shown, so it's measured from the mesh data.
func _build_model(d: Dictionary) -> void:
	var node := Models.make(String(d["model"]))
	if node == null:
		_build_shape("box", [], StandardMaterial3D.new())
		return
	node.rotation_degrees = Vector3(float(d.get("tilt", 0.0)), float(d.get("rot", 0.0)), 0.0)
	var sc := float(d.get("scale", 1.0))
	node.scale = Vector3(sc, sc, sc)
	add_child(node)
	Models.outline(node)
	var top := 0.0
	for mi in Models._meshes(node, []):
		var b: AABB = mi.get_aabb()
		top = maxf(top, (b.position.y + b.size.y) * sc)
	_top = maxf(top, 0.3)


## A board with readable words on it, on top of a post: {"text": "THE TOWER →", "height": 1.1}
func _build_sign(spec: Dictionary) -> void:
	var y := float(spec.get("height", _top - 0.25))
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.95, 0.34, 0.06)
	board.mesh = box
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(String(spec.get("color", "#9c6b3f")))
	wood.roughness = 0.9
	board.material_override = wood
	board.position = Vector3(0.18, y, 0)
	board.rotation_degrees.y = float(spec.get("rot", 45.0))
	add_child(board)
	var words := Label3D.new()
	words.text = String(spec.get("text", ""))
	words.font_size = 44
	words.pixel_size = 0.0045
	words.outline_size = 0
	words.modulate = Color(String(spec.get("ink", "#2b1d12")))
	words.position = Vector3(0, 0, 0.035)
	words.double_sided = false
	board.add_child(words)
	_top = maxf(_top, y + 0.2)


func _build_character(look: Dictionary, people: Dictionary) -> void:
	character = CharacterModel.new()
	add_child(character)
	resolved_look = Looks.resolve(look, people, "npc:" + id)
	if character.build(resolved_look):
		Models.outline(character, 0.012)
		_top = character.height
		character.rotation.y = deg_to_rad(float(def.get("facing_deg", -135.0)))
	else:
		character.queue_free()
		character = null
		_build_shape("npc", [], StandardMaterial3D.new())


func _size(raw: Variant, fallback: Vector3) -> Vector3:
	if raw is Array and (raw as Array).size() == 3:
		var a: Array = raw
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return fallback


func _add_mesh(mesh: Mesh, mat: Material, pos: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)


func _build_shape(shape: String, raw_size: Variant, mat: Material) -> void:
	match shape:
		"npc":
			var body := CapsuleMesh.new()
			body.radius = 0.28
			body.height = 1.4
			_add_mesh(body, mat, Vector3(0, 0.7, 0))
			_top = 1.4
		"cylinder":
			var s := _size(raw_size, Vector3(0.7, 0.3, 0.7))
			var cyl := CylinderMesh.new()
			cyl.top_radius = s.x * 0.5
			cyl.bottom_radius = s.x * 0.5
			cyl.height = s.y
			_add_mesh(cyl, mat, Vector3(0, s.y * 0.5, 0))
			_top = s.y
		"plank":
			var p := BoxMesh.new()
			p.size = _size(raw_size, Vector3(0.9, 0.03, 0.3))
			_add_mesh(p, mat, Vector3(0, 0.015, 0))
			_top = 0.2
		"arch":
			var post := BoxMesh.new()
			post.size = Vector3(0.2, 1.8, 0.3)
			_add_mesh(post, mat, Vector3(-0.4, 0.9, 0))
			_add_mesh(post, mat, Vector3(0.4, 0.9, 0))
			var lintel := BoxMesh.new()
			lintel.size = Vector3(1.0, 0.25, 0.3)
			_add_mesh(lintel, mat, Vector3(0, 1.9, 0))
			_top = 2.0
		_:
			var b := BoxMesh.new()
			b.size = _size(raw_size, Vector3(0.8, 0.8, 0.8))
			_add_mesh(b, mat, Vector3(0, b.size.y * 0.5, 0))
			_top = b.size.y
