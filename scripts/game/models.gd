extends RefCounted
## Loads Kenney models by short name, e.g. "fantasy-town/tree" or "castle-kit/tower-hexagon-mid",
## from res://assets/kenney/<pack>/<model>.glb. Scenes are cached.

const ROOT := "res://assets/kenney/"

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const RECOLOR_SHADER := preload("res://shaders/recolor.gdshader")

static var _recolor_mats: Dictionary = {}

static var _cache: Dictionary = {}
static var _outline_mats: Dictionary = {}


static func scene(name: String) -> PackedScene:
	if not _cache.has(name):
		var path := ROOT + name + ".glb"
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
		if _cache[name] == null:
			push_error("Missing model: %s" % path)
	return _cache[name]


static func exists(name: String) -> bool:
	return ResourceLoader.exists(ROOT + name + ".glb")


## A new instance of a model, or null.
static func make(name: String) -> Node3D:
	var s := scene(name)
	return s.instantiate() as Node3D if s else null


## Recolours every mesh under a node: {"#from": "#to", ...} in Kenney's shared palette, e.g.
## {"#ff7e44": "#7a5236"} turns Kenney orange into bark brown. Works on any pack's model.
static func recolor(root: Node, swaps: Dictionary) -> void:
	if swaps.is_empty():
		return
	var key_swaps := JSON.stringify(swaps)
	for mi in _meshes(root, []):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var base := mesh.surface_get_material(i) as BaseMaterial3D
			if base == null or base.albedo_texture == null:
				continue
			var key := "%d|%s" % [base.albedo_texture.get_instance_id(), key_swaps]
			if not _recolor_mats.has(key):
				var m := ShaderMaterial.new()
				m.shader = RECOLOR_SHADER
				m.set_shader_parameter("albedo_texture", base.albedo_texture)
				var froms: Array = []
				var tos: Array = []
				for f in swaps:
					froms.append(Vector3(Color(String(f)).r, Color(String(f)).g, Color(String(f)).b))
					var t := Color(String(swaps[f]))
					tos.append(Vector3(t.r, t.g, t.b))
				m.set_shader_parameter("swap_count", mini(froms.size(), 8))
				m.set_shader_parameter("swap_from", PackedVector3Array(froms))
				m.set_shader_parameter("swap_to", PackedVector3Array(tos))
				_recolor_mats[key] = m
			(mi as MeshInstance3D).set_surface_override_material(i, _recolor_mats[key])


## Gives every mesh under a node the thin dark outline (characters, props, things to use).
static func outline(root: Node, width: float = 0.014) -> void:
	var key := snappedf(width, 0.001)
	if not _outline_mats.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("width", width)
		_outline_mats[key] = mat
	for mi in _meshes(root, []):
		(mi as MeshInstance3D).material_overlay = _outline_mats[key]


## The world-space bounds of everything visible under a node (call after it's in the tree).
static func bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(root, []):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


static func _meshes(node: Node, out: Array) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_meshes(c, out)
	return out
