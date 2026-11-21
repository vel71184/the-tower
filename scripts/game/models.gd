extends RefCounted
## Loads Kenney models by short name, e.g. "fantasy-town/tree" or "castle-kit/tower-hexagon-mid",
## from res://assets/kenney/<pack>/<model>.glb. Scenes are cached.

const ROOT := "res://assets/kenney/"

static var _cache: Dictionary = {}


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
