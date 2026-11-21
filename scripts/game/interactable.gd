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

var _label: Label3D
var _status: Label3D
var _top := 1.0

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Looks := preload("res://scripts/characters/looks.gd")


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


## A short line spoken or noticed in the world, floating above the object for a few seconds.
func bark(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.outline_size = 12
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.92, 0.7)
	l.position = Vector3(0, _top + 0.8, 0)
	add_child(l)
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)


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


## Plays a one-off animation on a person, e.g. "emote-yes".
func act(animation: String) -> void:
	if character:
		character.act(animation)


func _build_character(look: Dictionary, people: Dictionary) -> void:
	character = CharacterModel.new()
	add_child(character)
	if character.build(Looks.resolve(look, people, "npc:" + id)):
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
