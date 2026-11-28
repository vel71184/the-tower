extends Node3D
## Builds one level from its JSON content: floor tiles, walls, objects, and the walk grid.
##
## Map rows run along +Z and columns along +X; each cell is 1 unit. The camera looks from the
## +X/+Z corner, so walls on those two edges are built low (a classic isometric cutaway).

const Interactable := preload("res://scripts/game/interactable.gd")
const Models := preload("res://scripts/game/models.gd")

const WALL_HEIGHT := 1.6
const LOW_WALL_HEIGHT := 0.3

## Ground types and their two checker colours.
const GROUND_COLORS := {
	"floor": ["#5b5148", "#544a42"],
	"grass": ["#5e8c46", "#5a8742"],
	"path": ["#a8916e", "#a28a68"],
	"dirt": ["#8d6c49", "#876746"],
	"stone": ["#8e877c", "#88817a"],
	"water": ["#4b7fb5", "#4878ad"],
	"wood": ["#8a6a48", "#846544"],
}

## What map characters mean unless a level's "legend" says otherwise. A legend entry can set:
## "ground" (a GROUND_COLORS key), "wall": true, "spawn": true, "prop" (a Kenney model, e.g.
## "fantasy-town/tree"), "solid", "rot" (degrees), "random_rot", "scale", "offset" [x, z].
const DEFAULT_LEGEND := {
	"#": {"wall": true},
	".": {},
	"S": {"spawn": true},
}

var data: Dictionary = {}
var width := 0
var height := 0
var spawn_cell := Vector2i.ZERO
## Set by a legend entry with "return": true; see return_cell().
var return_spawn := Vector2i(-1, -1)
var objects: Array = []
## Props tall enough to hide the climber: [node, height]. They fade when in the way.
var tall_props: Array = []
var astar := AStarGrid2D.new()

var _object_at: Dictionary = {}
## Fence cells: cell -> {"model": name, "arms": [Vector2 directions from the centre]}. A fence
## runs through the middle of its cell and joins any fence next to it; it blocks movement only
## along its own line, so you can walk right up to it.
var fences: Dictionary = {}
## Cells the map itself closes (walls, solid props, water), as opposed to people and things.
var _map_solid: Dictionary = {}
const FENCE_HALF := 0.06
const ARM_DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
var _materials: Dictionary = {}


## The floor this level is on: its name, era and "people" palette (floor.json).
var floor_data: Dictionary = {}


func build(level_data: Dictionary, floor_info: Dictionary = {}) -> void:
	data = level_data
	floor_data = floor_info
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
	var legend: Dictionary = DEFAULT_LEGEND.duplicate(true)
	legend.merge(data.get("legend", {}), true)
	var default_ground := String(data.get("ground", "floor"))
	var ground: Dictionary = {}
	for y in height:
		var row := String(rows[y])
		for x in width:
			var c: String = row[x] if x < row.length() else "#"
			var cell := Vector2i(x, y)
			var entry: Dictionary = legend.get(c, {})
			if entry.get("wall", false):
				_add_wall(cell, palette)
				astar.set_point_solid(cell, true)
				_map_solid[cell] = true
				continue
			if entry.has("fence"):
				fences[cell] = {"model": String(entry["fence"]), "arms": []}
				astar.set_point_solid(cell, true)
			var kind := String(entry.get("ground", defs[c].get("ground", default_ground) if defs.has(c) else default_ground))
			ground[cell] = kind
			if kind == "water":
				astar.set_point_solid(cell, true)
				_map_solid[cell] = true
			if entry.get("spawn", false):
				spawn_cell = cell
			if entry.get("return", false):
				return_spawn = cell
			if entry.has("prop"):
				_add_prop(entry, cell)
				if entry.get("solid", false):
					astar.set_point_solid(cell, true)
					_map_solid[cell] = true
			if defs.has(c):
				var obj := _add_object(defs[c], cell)
				if obj.blocking:
					astar.set_point_solid(cell, true)
			elif not legend.has(c):
				push_warning("Level %s: unknown map character '%s'" % [data.get("id", "?"), c])
	_build_fences()
	_build_ground(ground, palette)
	_add_surroundings(data.get("surround", {}))
	for item in data.get("backdrop", []):
		_add_backdrop(item)


## Fades tall props standing between the camera and the climber, so nothing hides them.
## Called a few times a second by the game.
func fade_occluders(cam: Camera3D, target: Vector3) -> void:
	var target_screen := cam.unproject_position(target + Vector3(0, 0.5, 0))
	var view: float = cam.get("view_height") if cam.get("view_height") != null else 8.0
	var reach := 110.0 * (cam.get_viewport().get_visible_rect().size.y / 720.0) * (8.0 / view)
	var cam_dir := -cam.global_transform.basis.z
	var target_depth := cam_dir.dot(target - cam.global_position)
	for entry in tall_props:
		var node: Node3D = entry[0]
		var h: float = entry[1]
		var base := node.global_position
		var depth := cam_dir.dot(base - cam.global_position)
		var in_way := false
		if depth < target_depth - 0.2:
			var top_screen := cam.unproject_position(base + Vector3(0, h, 0))
			var base_screen := cam.unproject_position(base)
			var closest := Geometry2D.get_closest_point_to_segment(target_screen, base_screen, top_screen)
			in_way = closest.distance_to(target_screen) < reach
		_set_faded(node, in_way)


func _set_faded(node: Node3D, faded: bool) -> void:
	if bool(node.get_meta("faded", false)) == faded:
		return
	node.set_meta("faded", faded)
	for mi in Models._meshes(node, []):
		(mi as GeometryInstance3D).transparency = 0.72 if faded else 0.0


## Where the climber appears when coming back from the next level: a cell marked "return" in
## the legend, or the open cell nearest the way forward.
func return_cell() -> Vector2i:
	if return_spawn.x >= 0:
		return return_spawn
	for obj in objects:
		if obj.kind == "exit" and String(obj.def.get("to", "next")) == "next":
			var best := Vector2i(-1, -1)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var c: Vector2i = obj.cell + Vector2i(dx, dy)
					if is_walkable(c) and (best.x < 0 or Vector2(c - spawn_cell).length() < Vector2(best - spawn_cell).length()):
						best = c
			if best.x >= 0:
				return best
	return spawn_cell


func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, 0.0, cell.y + 0.5)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_walkable(cell: Vector2i) -> bool:
	return in_bounds(cell) and not astar.is_point_solid(cell)


## Whether a round body (radius r) can stand at a world position. "own" is the cell the
## body already stands in, which never blocks it.
func can_stand(pos: Vector3, r: float, own: Vector2i = Vector2i(-99, -99)) -> bool:
	for corner in [Vector2(-r, -r), Vector2(r, -r), Vector2(-r, r), Vector2(r, r)]:
		var c := Vector2i(floori(pos.x + corner.x), floori(pos.z + corner.y))
		if c == own or fences.has(c):
			continue
		# People and things standing in a cell are round, not the whole square: checked below.
		var there: Interactable = _object_at.get(c, null)
		if there != null and there.blocking and not _wall_or_prop(c):
			continue
		if not is_walkable(c):
			return false
	var p2 := Vector2(pos.x, pos.z)
	for obj in objects:
		if not obj.blocking or obj.cell == own or _wall_or_prop(obj.cell):
			continue
		var op := Vector2(obj.position.x, obj.position.z)
		if op.distance_to(p2) < r + obj.body_radius():
			return false
	# Fences only block along their line.
	var p := Vector2(pos.x, pos.z)
	for y in range(floori(pos.z - r), floori(pos.z + r) + 1):
		for x in range(floori(pos.x - r), floori(pos.x + r) + 1):
			var f: Dictionary = fences.get(Vector2i(x, y), {})
			if f.is_empty():
				continue
			var centre := Vector2(x + 0.5, y + 0.5)
			for arm in f["arms"]:
				var end: Vector2 = centre + Vector2(arm) * 0.5
				if Geometry2D.get_closest_point_to_segment(p, centre, end).distance_to(p) < r + FENCE_HALF:
					return false
	return true


## True if a cell is closed by the map itself (a wall, a solid prop, water), regardless of
## anyone standing in it.
func _wall_or_prop(c: Vector2i) -> bool:
	return _map_solid.has(c)


## The open cell to start a path from when standing at a world position. Usually the cell
## underfoot; beside a fence (whose cell is closed to paths) it's the nearest open neighbour.
func path_cell_at(pos: Vector3) -> Vector2i:
	var c := world_to_cell(pos)
	if is_walkable(c):
		return c
	var best := c
	var best_d := INF
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if is_walkable(n):
				var d := cell_to_world(n).distance_to(Vector3(pos.x, 0, pos.z))
				if d < best_d:
					best_d = d
					best = n
	return best


## Joins each fence cell to its fence neighbours and builds the pieces: a straight run is one
## whole fence; corners and ends are half fences from the centre out to each joined side.
func _build_fences() -> void:
	for cell in fences:
		var arms: Array = []
		for d in ARM_DIRS:
			if fences.has(cell + d):
				arms.append(d)
		if arms.is_empty():
			arms = [Vector2i(1, 0), Vector2i(-1, 0)]
		elif arms.size() == 1:
			# The end of a run, beside a gap: carry on to the cell's far edge, so the gap is
			# exactly the open cell.
			arms.append(-(arms[0] as Vector2i))
		fences[cell]["arms"] = arms
		var straight: bool = arms.size() == 2 and (arms[0] as Vector2i) + (arms[1] as Vector2i) == Vector2i.ZERO
		var holder := Node3D.new()
		holder.position = cell_to_world(cell)
		add_child(holder)
		if straight:
			_add_fence_piece(holder, fences[cell]["model"], arms[0], 1.0)
		else:
			for a in arms:
				_add_fence_piece(holder, fences[cell]["model"], a, 0.5)
		Models.outline(holder)


## One fence model along a direction from the cell centre: full length (through the centre)
## or half (from the centre to the edge). Kenney's fence runs along Z at the +X edge of its tile.
func _add_fence_piece(holder: Node3D, model: String, dir: Vector2i, length: float) -> void:
	var node := Models.make(model)
	if node == null:
		return
	var arm := Node3D.new()
	arm.rotation_degrees.y = {Vector2i(0, 1): 0.0, Vector2i(1, 0): 90.0, Vector2i(0, -1): 180.0, Vector2i(-1, 0): 270.0}[dir]
	holder.add_child(arm)
	arm.add_child(node)
	node.scale = Vector3(1, 1, length)
	node.position = Vector3(-0.46, 0, 0.0 if length >= 1.0 else 0.25)


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


## Moves an object (e.g. someone in a fight) to another cell, keeping the walk grid right.
func move_object(obj: Interactable, to: Vector2i) -> void:
	_object_at.erase(obj.cell)
	if obj.blocking:
		astar.set_point_solid(obj.cell, false)
	obj.cell = to
	_object_at[to] = obj
	if obj.blocking:
		astar.set_point_solid(to, true)


## Takes an object out of the level (someone who leaves, or is carried off).
func remove_object(obj: Interactable) -> void:
	forget_object(obj)
	obj.queue_free()


## Takes something out of the level's bookkeeping (grid, lists) without freeing it yet, e.g.
## someone walking off who should no longer block the way or be talked to.
func forget_object(obj: Interactable) -> void:
	if _object_at.get(obj.cell) == obj:
		_object_at.erase(obj.cell)
		if obj.blocking:
			astar.set_point_solid(obj.cell, false)
	objects.erase(obj)
	for i in range(tall_props.size() - 1, -1, -1):
		if tall_props[i][0] == obj:
			tall_props.remove_at(i)


## Path for someone standing on a blocking cell, avoiding other cells (e.g. the climber).
func find_path_for(obj: Interactable, to: Vector2i, avoid: Array = []) -> Array:
	astar.set_point_solid(obj.cell, false)
	var restore: Array = []
	for c in avoid:
		if in_bounds(c) and not astar.is_point_solid(c):
			astar.set_point_solid(c, true)
			restore.append(c)
	var path: Array = []
	if is_walkable(to):
		path = Array(astar.get_id_path(obj.cell, to))
	for c in restore:
		astar.set_point_solid(c, false)
	if obj.blocking:
		astar.set_point_solid(obj.cell, true)
	return path


func chebyshev(a: Vector2i, b: Vector2i) -> int:
	return _chebyshev(a, b)


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


## All ground as one mesh (cheap to draw on phones), coloured per cell in a soft checker.
func _build_ground(cells: Dictionary, palette: Dictionary) -> void:
	if cells.is_empty():
		return
	# Indoors a level can lay Kenney floor tiles instead ("floor_tiles": [models], the first
	# most often).
	var tiles: Array = data.get("floor_tiles", [])
	if not tiles.is_empty():
		for cell in cells:
			var n := posmod(hash(cell * 17), 100)
			var pick: String = tiles[0] if n < 78 or tiles.size() == 1 else tiles[1 + n % (tiles.size() - 1)]
			var tile := Models.make(pick)
			if tile:
				tile.position = cell_to_world(cell)
				tile.rotation_degrees.y = 90.0 * float(posmod(hash(cell * 7), 4))
				add_child(tile)
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	var soft: bool = data.get("soft_ground", data.get("ground", "floor") != "floor")
	for cell in cells:
		var kind := String(cells[cell])
		var pair: Array = GROUND_COLORS.get(kind, GROUND_COLORS["floor"])
		if kind == "floor":
			pair = [palette.get("floor_a", pair[0]), palette.get("floor_b", pair[1])]
		var col := Color(String(pair[0] if (cell.x + cell.y) % 2 == 0 else pair[1]))
		if soft:
			# Outdoors: no checkerboard. Gentle per-cell variation, and grass worn where it
			# meets a path.
			col = Color(String(pair[0]))
			var n := float(posmod(hash(cell * 31), 1000)) / 1000.0
			col = col.lightened(0.025 * n) if n > 0.5 else col.darkened(0.03 * (1.0 - n))
			if kind == "grass":
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if cells.get(cell + d, "") == "path":
						col = col.lerp(Color(String(GROUND_COLORS["path"][0])), 0.28)
						break
		var y := -0.12 if kind == "water" else 0.0
		var a := Vector3(cell.x, y, cell.y)
		var b := Vector3(cell.x + 1, y, cell.y)
		var c := Vector3(cell.x + 1, y, cell.y + 1)
		var d := Vector3(cell.x, y, cell.y + 1)
		for v in [a, b, c, a, c, d]:
			st.set_color(col)
			st.add_vertex(v)
		# A river at the map's edge keeps flowing out past it.
		if kind == "water" and (cell.x == 0 or cell.y == 0 or cell.x == width - 1 or cell.y == height - 1):
			var out := Vector2i(-1 if cell.x == 0 else (1 if cell.x == width - 1 else 0),
				-1 if cell.y == 0 else (1 if cell.y == height - 1 else 0))
			for i in range(1, 12):
				var o: Vector2i = cell + out * i
				var oa := Vector3(o.x, y, o.y)
				for v in [oa, oa + Vector3(1, 0, 0), oa + Vector3(1, 0, 1), oa, oa + Vector3(1, 0, 1), oa + Vector3(0, 0, 1)]:
					st.set_color(col)
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Ground"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	if soft:
		# Outdoors the land carries on past the edge of the playable map.
		var around := MeshInstance3D.new()
		around.name = "Surroundings"
		var plane := PlaneMesh.new()
		plane.size = Vector2(width + 80, height + 80)
		around.mesh = plane
		# Below the water (-0.12), so rivers show.
		around.position = Vector3(width / 2.0, -0.2, height / 2.0)
		var am := StandardMaterial3D.new()
		var base_kind := String(data.get("ground", "grass"))
		am.albedo_color = Color(String(GROUND_COLORS.get(base_kind, GROUND_COLORS["grass"])[0])).darkened(0.08)
		am.roughness = 1.0
		around.material_override = am
		add_child(around)


## Scenery past the map's edge so the world carries on: tall things on the far sides, low things
## on the near (camera) sides. {"far": [models], "near": [models], "depth": cells, "density": 0-1}
func _add_surroundings(spec: Dictionary) -> void:
	if spec.is_empty():
		return
	var far: Array = spec.get("far", [])
	var near: Array = spec.get("near", [])
	var depth := int(spec.get("depth", 6))
	var density := float(spec.get("density", 0.4))
	for y in range(-depth, height + depth):
		for x in range(-depth, width + depth):
			if x >= 0 and y >= 0 and x < width and y < height:
				continue
			var cell := Vector2i(x, y)
			var n := float(posmod(hash(cell * 97), 1000)) / 1000.0
			if n > density:
				continue
			var is_near := x >= width or y >= height
			var pool := near if is_near else far
			if pool.is_empty():
				continue
			var node := Models.make(String(pool[posmod(hash(cell * 5), pool.size())]))
			if node == null:
				continue
			node.position = cell_to_world(cell) + Vector3(n - 0.5, 0, 0.5 - n) * 0.5
			node.rotation_degrees.y = float(posmod(hash(cell * 3), 360))
			var sc := 0.8 + n * 0.5
			node.scale = Vector3(sc, sc, sc)
			add_child(node)


## A Kenney model standing on a cell (trees, rocks, fences...).
func _add_prop(entry: Dictionary, cell: Vector2i) -> void:
	var node := Models.make(String(entry["prop"]))
	if node == null:
		return
	var off: Array = entry.get("offset", [0, 0])
	node.position = cell_to_world(cell) + Vector3(float(off[0]), 0, float(off[1]))
	var rot := float(entry.get("rot", 0.0))
	if entry.get("random_rot", false):
		rot += float(hash(cell) % 4) * 90.0 + float(hash(cell * 7) % 30) - 15.0
	node.rotation_degrees.y = rot
	var sc := float(entry.get("scale", 1.0))
	if entry.get("random_scale", false):
		sc *= 0.85 + float(hash(cell * 13) % 30) / 100.0
	node.scale = Vector3(sc, sc, sc)
	add_child(node)
	Models.outline(node)
	# "light": a warm glow from this prop (a lantern, a brazier).
	if entry.has("light"):
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(String(entry["light"]))
		lamp.light_energy = float(entry.get("light_energy", 1.4))
		lamp.omni_range = float(entry.get("light_range", 5.0))
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, float(entry.get("light_height", 1.0)), 0)
		node.add_child(lamp)
	var h := Models.bounds(node).size.y
	if h > 0.9:
		tall_props.append([node, h])


## Scenery outside the playable grid: a single model, or a "stack" of models piled up
## (e.g. the tower). {"model" | "stack": [...], "at": [x, z], "scale": s, "rot": deg}
func _add_backdrop(item: Dictionary) -> void:
	var at: Array = item.get("at", [0, 0])
	var holder := Node3D.new()
	holder.name = "Backdrop"
	holder.position = Vector3(float(at[0]), float(item.get("y", 0.0)), float(at[1]))
	holder.rotation_degrees.y = float(item.get("rot", 0.0))
	var sc := float(item.get("scale", 1.0))
	holder.scale = Vector3(sc, sc, sc)
	add_child(holder)
	var pieces: Array = item.get("stack", [item.get("model", "")])
	var top := 0.0
	for p in pieces:
		var node := Models.make(String(p))
		if node == null:
			continue
		holder.add_child(node)
		node.position.y = top
		var box := Models.bounds(node)
		top += box.size.y / sc if box.size.y > 0.0 else 1.0


func _add_wall(cell: Vector2i, palette: Dictionary) -> void:
	var near_camera := cell.x == width - 1 or cell.y == height - 1
	var h := LOW_WALL_HEIGHT if near_camera else WALL_HEIGHT
	# A level can build its walls from a Kenney piece ("wall_model"); the camera-side walls
	# are cut down low so the room stays visible.
	if data.has("wall_model"):
		var holder := Node3D.new()
		holder.position = cell_to_world(cell)
		add_child(holder)
		var node := Models.make(String(data["wall_model"]))
		if node:
			holder.add_child(node)
			var box := Models.bounds(node)
			var model_h: float = maxf(box.size.y, 0.01)
			node.scale = Vector3(1.0, h / model_h, 1.0)
			Models.outline(holder)
		if not near_camera:
			tall_props.append([holder, h])
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, h, 1.0)
	mi.mesh = mesh
	mi.material_override = _material(Color(String(palette.get("wall", "#8a7f72"))))
	mi.position = cell_to_world(cell) + Vector3(0, h * 0.5 - 0.1, 0)
	add_child(mi)
	if not near_camera:
		# Walls and pillars fade like tall props when they stand between camera and climber.
		var holder := Node3D.new()
		holder.position = cell_to_world(cell)
		add_child(holder)
		mi.reparent(holder)
		tall_props.append([holder, h])


func _add_object(def: Dictionary, cell: Vector2i) -> Interactable:
	var obj := Interactable.new()
	add_child(obj)
	obj.setup(def, cell, cell_to_world(cell), _material, floor_data.get("people", {}))
	objects.append(obj)
	_object_at[cell] = obj
	if obj.kind != "npc" and obj.top_height() > 0.9:
		tall_props.append([obj, obj.top_height()])
	return obj
