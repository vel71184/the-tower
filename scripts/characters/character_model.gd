extends Node3D
## A person assembled from Kenney Mini Characters parts: any head on any body, recoloured
## slot by slot, optionally holding items or sitting in a wheelchair.
##
## A look (spec) is a Dictionary, usually from level JSON:
##   {"body": "male-f", "head": "female-c",
##    "colors": {"skin": "tan", "shirt": "slate", "pants": "ink", "hair": "coral"},
##    "item": "sword", "item_left": "shield_round", "wheelchair": "power", "scale": 1.0}
## Slots: skin, hair, shirt, pants, shoes, accent, species (what a robot/alien/zombie is made of).
## The data lives in content/characters/parts.json.

const PARTS_PATH := "res://content/characters/parts.json"
const SHADER := preload("res://shaders/palette_swap.gdshader")
const MAX_SWAPS := 8
## Where the hand is, in arm-bone space (model units). All Mini Characters share one rig.
const HAND_RIGHT := Vector3(-0.24, 0.0, 0.02)
const HAND_LEFT := Vector3(0.24, 0.0, 0.02)
const LOOPING := ["idle", "walk", "sprint", "sit", "drive", "crouch", "holding-right", "holding-left",
	"holding-both", "wheelchair-sit", "wheelchair-move-forward", "wheelchair-move-back"]

static var _parts: Dictionary = {}
static var _scenes: Dictionary = {}

var spec: Dictionary = {}
var body_name := ""
var head_name := ""
var colors: Dictionary = {}
var model: Node3D
var skeleton: Skeleton3D
var anim: AnimationPlayer
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var wheelchair: Node3D
var height := 1.0

var _moving := false
var _action := ""


static func parts() -> Dictionary:
	if _parts.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTS_PATH))
		if typeof(parsed) == TYPE_DICTIONARY:
			_parts = parsed
		else:
			push_error("Could not read %s" % PARTS_PATH)
	return _parts


static func scene_for(file_stem: String) -> PackedScene:
	if not _scenes.has(file_stem):
		var path := "%s/%s.glb" % [parts().get("model_dir", ""), file_stem]
		_scenes[file_stem] = load(path) if ResourceLoader.exists(path) else null
		if _scenes[file_stem] == null:
			push_error("Missing character model: %s" % path)
	return _scenes[file_stem]


static func color_names() -> Array:
	return parts().get("palette", {}).get("colors", [])


static func is_color(name: String) -> bool:
	return color_names().has(name)


## UV rectangle of a palette colour (its light/dark pair of cells) in the colormap.
static func color_rect(name: String) -> Rect2:
	var pal: Dictionary = parts().get("palette", {})
	var size := float(pal.get("size", 512))
	var rows: Array = pal.get("rows", [])
	for r in rows.size():
		var i := (rows[r] as Array).find(name)
		if i >= 0:
			var x := i * float(pal.get("pair_width", 64))
			var y := float(pal.get("first_row_y", 128)) + r * float(pal.get("row_height", 128))
			return Rect2(x / size, y / size, float(pal.get("pair_width", 64)) / size, float(pal.get("row_height", 128)) / size)
	return Rect2()


## Builds the character. Returns false if the parts don't exist.
func build(look: Dictionary) -> bool:
	spec = look.duplicate(true)
	var p := parts()
	body_name = String(spec.get("body", "male-a"))
	head_name = String(spec.get("head", body_name))
	if not p.get("bodies", {}).has(body_name) or not p.get("heads", {}).has(head_name):
		push_error("Unknown character parts: body '%s', head '%s'" % [body_name, head_name])
		return false
	colors = (spec.get("colors", {}) as Dictionary).duplicate()

	var scene := scene_for("character-" + body_name)
	if scene == null:
		return false
	model = scene.instantiate() as Node3D
	add_child(model)
	# Kenney characters face +Z; our nodes look down -Z, so turn the model around.
	model.rotation.y = PI
	var s := float(p.get("scale", 1.35)) * float(spec.get("scale", 1.0))
	model.scale = Vector3(s, s, s)

	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	anim = _find_type(model, "AnimationPlayer") as AnimationPlayer
	for mi in _find_all_type(model, "MeshInstance3D"):
		var n := String(mi.name).to_lower()
		if n.contains("head"):
			head_mesh = mi
		elif n.contains("body"):
			body_mesh = mi
	if body_mesh == null or head_mesh == null:
		push_error("Character '%s' is missing its body or head mesh" % body_name)
		return false

	if head_name != body_name:
		var donor_scene := scene_for("character-" + head_name)
		if donor_scene:
			var donor := donor_scene.instantiate()
			for mi in _find_all_type(donor, "MeshInstance3D"):
				if String(mi.name).to_lower().contains("head"):
					head_mesh.mesh = mi.mesh
					head_mesh.skin = mi.skin
			donor.free()

	_recolor(body_mesh, p["bodies"][body_name])
	_recolor(head_mesh, p["heads"][head_name])
	height = 0.85 * s

	if spec.has("item"):
		_attach_item(String(spec["item"]), "arm-right", HAND_RIGHT)
	if spec.has("item_left"):
		_attach_item(String(spec["item_left"]), "arm-left", HAND_LEFT)
	for face_item in spec.get("wearing", []):
		_attach_item(String(face_item), "head", Vector3.ZERO)
	if spec.has("wheelchair"):
		_add_wheelchair(String(spec["wheelchair"]))

	_setup_animations()
	_update_animation()
	return true


## Walking or standing still. Plays the matching animation.
func set_moving(moving: bool) -> void:
	if moving == _moving:
		return
	_moving = moving
	if _action == "":
		_update_animation()


## Plays a one-off animation (e.g. "interact-right", "emote-yes", "pick-up"), then returns to idle.
func act(animation: String) -> void:
	if anim == null or not anim.has_animation(animation):
		return
	_action = animation
	anim.play(animation, 0.1)


func has_animation(animation: String) -> bool:
	return anim != null and anim.has_animation(animation)


func current_animation() -> String:
	return anim.current_animation if anim else ""


func swap_count(mesh: MeshInstance3D) -> int:
	var mat := mesh.material_override as ShaderMaterial
	return int(mat.get_shader_parameter("swap_count")) if mat else 0


# --- Internals ------------------------------------------------------------------------------

func _recolor(mesh: MeshInstance3D, slots: Dictionary) -> void:
	var froms: Array = []
	var bys: Array = []
	for slot in slots:
		if not colors.has(slot):
			continue
		var src := String(slots[slot])
		var dst := String(colors[slot])
		if src == dst or not is_color(dst):
			if not is_color(dst):
				push_warning("Unknown colour '%s' for slot '%s'" % [dst, slot])
			continue
		if froms.size() >= MAX_SWAPS:
			break
		var a := color_rect(src)
		var b := color_rect(dst)
		froms.append(Vector4(a.position.x, a.position.y, a.end.x, a.end.y))
		bys.append(b.position - a.position)
	var count := froms.size()
	while froms.size() < MAX_SWAPS:
		froms.append(Vector4.ZERO)
		bys.append(Vector2.ZERO)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo_texture", _texture_of(mesh))
	mat.set_shader_parameter("swap_count", count)
	mat.set_shader_parameter("swap_from", PackedVector4Array(froms))
	mat.set_shader_parameter("swap_by", PackedVector2Array(bys))
	mesh.material_override = mat


func _texture_of(mesh: MeshInstance3D) -> Texture2D:
	if mesh.mesh and mesh.mesh.get_surface_count() > 0:
		var m := mesh.mesh.surface_get_material(0)
		if m is BaseMaterial3D and (m as BaseMaterial3D).albedo_texture:
			return (m as BaseMaterial3D).albedo_texture
	var path := String(parts().get("palette", {}).get("texture", ""))
	return load(path) if ResourceLoader.exists(path) else null


func _attach_item(item: String, bone: String, offset: Vector3) -> void:
	var file := String(parts().get("items", {}).get(item, ""))
	if file == "" or skeleton == null:
		push_warning("Unknown item '%s'" % item)
		return
	var scene := scene_for(file)
	if scene == null:
		return
	var holder := BoneAttachment3D.new()
	holder.name = "Holding_" + item.to_pascal_case()
	holder.bone_name = bone
	skeleton.add_child(holder)
	var thing := scene.instantiate() as Node3D
	thing.position = offset
	holder.add_child(thing)


func _add_wheelchair(kind: String) -> void:
	var file := String(parts().get("wheelchairs", {}).get(kind, ""))
	var scene := scene_for(file) if file != "" else null
	if scene == null:
		push_warning("Unknown wheelchair '%s'" % kind)
		return
	wheelchair = scene.instantiate() as Node3D
	model.add_child(wheelchair)


func _setup_animations() -> void:
	if anim == null:
		return
	for a in LOOPING:
		if anim.has_animation(a):
			anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	if not anim.animation_finished.is_connected(_on_animation_finished):
		anim.animation_finished.connect(_on_animation_finished)


func _update_animation() -> void:
	if anim == null:
		return
	var want: String
	if wheelchair:
		want = "wheelchair-move-forward" if _moving else "wheelchair-sit"
	elif _moving:
		want = "walk"
	elif spec.has("item") and not spec.has("item_left"):
		want = "holding-right"
	elif spec.has("item_left") and not spec.has("item"):
		want = "holding-left"
	elif spec.has("item") and spec.has("item_left"):
		want = "holding-both"
	else:
		want = String(spec.get("idle", "idle"))
	if anim.has_animation(want) and anim.current_animation != want:
		anim.play(want, 0.15)


func _on_animation_finished(_name: StringName) -> void:
	_action = ""
	_update_animation()


static func _find_type(root: Node, cls: String) -> Node:
	if root.is_class(cls):
		return root
	for c in root.get_children():
		var hit := _find_type(c, cls)
		if hit:
			return hit
	return null


static func _find_all_type(root: Node, cls: String, out: Array = []) -> Array:
	if root.is_class(cls):
		out.append(root)
	for c in root.get_children():
		_find_all_type(c, cls, out)
	return out
