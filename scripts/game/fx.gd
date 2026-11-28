extends RefCounted
## Combat feedback: what makes a hit feel like a hit. A flash on whoever was struck, a tiny
## freeze on impact, a camera shake, a slash arc in front of the swing, and a warning tint
## while someone winds up.

const FLASH_SHADER := preload("res://shaders/flash.gdshader")

static var _flash_mats: Dictionary = {}


## Tints every mesh under a node for a moment, then puts its outline back.
static func flash(node: Node3D, color: Color = Color(1, 1, 1), seconds: float = 0.12) -> void:
	if node == null or not node.is_inside_tree():
		return
	var key := color.to_html()
	if not _flash_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = FLASH_SHADER
		m.set_shader_parameter("color", color)
		_flash_mats[key] = m
	var meshes: Array = _meshes(node, [])
	for mi in meshes:
		if not mi.has_meta("overlay_before"):
			mi.set_meta("overlay_before", mi.material_overlay)
		mi.material_overlay = _flash_mats[key]
	node.get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		for mi in meshes:
			if is_instance_valid(mi) and mi.has_meta("overlay_before"):
				mi.material_overlay = mi.get_meta("overlay_before")
				mi.remove_meta("overlay_before"))


## Freezes the action for a split second on impact (hitstop), in real time.
static func hitstop(tree: SceneTree, seconds: float = 0.06) -> void:
	if tree == null or Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	tree.create_timer(seconds, true, false, true).timeout.connect(func() -> void: Engine.time_scale = 1.0)


## A quick pale arc in front of someone swinging.
static func slash(who: Node3D, facing: Vector3, reach: float = 1.2) -> void:
	if who == null or not who.is_inside_tree():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 10
	var half := deg_to_rad(55.0)
	var inner := reach * 0.55
	for i in steps:
		var a0 := -half + 2.0 * half * float(i) / steps
		var a1 := -half + 2.0 * half * float(i + 1) / steps
		var p := [Vector3(sin(a0) * inner, 0, -cos(a0) * inner), Vector3(sin(a0) * reach, 0, -cos(a0) * reach),
			Vector3(sin(a1) * reach, 0, -cos(a1) * reach), Vector3(sin(a1) * inner, 0, -cos(a1) * inner)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(p[idx])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.97, 0.88, 0.55)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	who.get_parent().add_child(mi)
	mi.global_position = who.global_position + Vector3(0, 0.55, 0)
	var flat := Vector3(facing.x, 0, facing.z)
	if flat.length() > 0.01:
		mi.look_at(mi.global_position + flat, Vector3.UP)
	mi.rotation_degrees.z = -12.0
	var t := mi.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.tween_callback(mi.queue_free)


static func _meshes(node: Node, out: Array) -> Array:
	if node is MeshInstance3D:
		out.append(node)
	for c in node.get_children():
		_meshes(c, out)
	return out
