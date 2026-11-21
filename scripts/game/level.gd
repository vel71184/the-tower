extends Node3D
## Builds one level from its JSON content: floor tiles, walls, objects, and the walk grid.
##
## Map rows run along +Z and columns along +X; each cell is 1 unit. The camera looks from the
## +X/+Z corner, so walls on those two edges are built low (a classic isometric cutaway).

const Interactable := preload("res://scripts/game/interactable.gd")

const WALL_HEIGHT := 1.6
const LOW_WALL_HEIGHT := 0.3

var data: Dictionary = {}
var width := 0
var height := 0
var spawn_cell := Vector2i.ZERO
var objects: Array = []
var astar := AStarGrid2D.new()

var _object_at: Dictionary = {}
var _materials: Dictionary = {}


func build(level_data: Dictionary) -> void:
	data = level_data
	var rows: Array = data.get("map", [])
	height = rows.size()
	width = 0
	for r in rows:
		width = maxi(width, String(r).length())

	astar.region = Rect2i(0, 0, width, height)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	var defs: Dictionary = {}
	for def in data.get("objects", []):
		defs[String(def["char"])] = def

	var palette: Dictionary = data.get("palette", {})
	for y in height:
		var row := String(rows[y])
		for x in width:
			var c: String = row[x] if x < row.length() else "#"
			var cell := Vector2i(x, y)
			if c == "#":
				_add_wall(cell, palette)
				astar.set_point_solid(cell, true)
				continue
			_add_floor(cell, palette)
			if c == "S":
				spawn_cell = cell
			elif defs.has(c):
				var obj := _add_object(defs[c], cell)
				if obj.blocking:
					astar.set_point_solid(cell, true)
			elif c != ".":
				push_warning("Level %s: unknown map character '%s'" % [data.get("id", "?"), c])


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not astar.is_point_solid(cell)


func object_at(cell: Vector2i) -> Interactable:
	return _object_at.get(cell, null)


func find_path(from: Vector2i, to: Vector2i) -> Array:
	if not is_walkable(from) or not is_walkable(to):
		return []
	return Array(astar.get_id_path(from, to))


## Shortest path to a cell from which the object can be used (beside it, or on it if walkable).
func path_to_object(from: Vector2i, obj: Interactable) -> Array:
	if not obj.blocking:
		return find_path(from, obj.cell)
	if _chebyshev(from, obj.cell) <= 1:
		return [from]
	var best: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var path := find_path(from, obj.cell + Vector2i(dx, dy))
			if not path.is_empty() and (best.is_empty() or path.size() < best.size()):
				best = path
	return best


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		_materials[key] = m
	return _materials[key]


func _add_floor(cell: Vector2i, palette: Dictionary) -> void:
	var a := Color(String(palette.get("floor_a", "#5b5148")))
	var b := Color(String(palette.get("floor_b", "#544a42")))
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.1, 1.0)
	mi.mesh = mesh
	mi.material_override = _material(a if (cell.x + cell.y) % 2 == 0 else b)
	mi.position = cell_to_world(cell) + Vector3(0, -0.05, 0)
	add_child(mi)


func _add_wall(cell: Vector2i, palette: Dictionary) -> void:
	var near_camera := cell.x == width - 1 or cell.y == height - 1
	var h := LOW_WALL_HEIGHT if near_camera else WALL_HEIGHT
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, h, 1.0)
	mi.mesh = mesh
	mi.material_override = _material(Color(String(palette.get("wall", "#8a7f72"))))
	mi.position = cell_to_world(cell) + Vector3(0, h * 0.5 - 0.1, 0)
	add_child(mi)


func _add_object(def: Dictionary, cell: Vector2i) -> Interactable:
	var obj := Interactable.new()
	add_child(obj)
	obj.setup(def, cell, cell_to_world(cell), _material)
	objects.append(obj)
	_object_at[cell] = obj
	return obj
