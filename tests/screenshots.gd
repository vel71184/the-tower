extends Node3D
## Renders a few views of the real game to PNG, for checking looks without a device.
## CI runs it under a virtual display:  godot --path . res://tests/screenshots.tscn
## Writes to $SHOT_DIR (default user://shots).

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const Looks := preload("res://scripts/characters/looks.gd")

var _out := ""


func _ready() -> void:
	_out = OS.get_environment("SHOT_DIR")
	if _out == "":
		_out = "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(60.0).timeout.connect(func() -> void: get_tree().quit(2))
	Baseline.reset()

	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _frames(90)
	await _shot("00_title")
	main.start_level(0, 1)
	await _frames(40)
	await _shot("0_road_start")
	main.climber.place(Vector2i(8, 6))
	main.cam.snap()
	main._on_entered_cell(Vector2i(8, 6))
	await _frames(15)
	await _shot("0_road_cart_and_wil")
	main.start_level(1, 1)
	await _frames(40)
	await _shot("1_waiting_hall")
	main.climber.place(Vector2i(4, 6))
	main.cam.snap()
	main._on_entered_cell(Vector2i(4, 6))
	await _frames(10)
	await _shot("2_near_tobin")
	_talk(main)
	await _frames(20)
	await _shot("3_talking")
	main.queue_free()
	Baseline.delete_save()
	await _frames(2)

	await _lineup()
	get_tree().quit(0)


func _talk(main) -> void:
	var tobin = main.find_object("tobin")
	main.climber.face(tobin.global_position)
	tobin.face(main.climber.global_position)
	main.interact(tobin)


func _lineup() -> void:
	var stage := Node3D.new()
	add_child(stage)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2a2420")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8c8070")
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	stage.add_child(sun)

	var parts := CharacterModel.parts()
	var bodies: Array = (parts["bodies"] as Dictionary).keys()
	bodies.sort()
	var floor1: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/floors/floor_01/floor.json"))
	var looks: Array = []
	for b in bodies:
		looks.append({"body": b})
	looks.append(Looks.climber_look())
	for i in 9:
		looks.append(Looks.resolve({}, floor1["people"], "crowd:%d" % i))
	looks.append({"body": "knight", "item": "sword", "item_left": "shield_round"})
	looks.append({"body": "male-b", "wheelchair": "power"})
	for b in ["arena-soldier", "forest-archer", "shop-employee", "arcade-gamer", "skate-girl", "dungeon-orc"]:
		looks.append(Looks.resolve({"body": b, "head": b}, floor1["people"], "floor1:" + b))
	looks.append({"body": "dungeon-orc", "head": "male-e", "colors": {"species": "violet", "shirt": "red"}})
	looks.append({"body": "skate-boy", "head": "arena-soldier", "colors": {"shirt": "green", "pants": "white"}})
	var cols := 10
	for i in looks.size():
		var c = CharacterModel.new()
		stage.add_child(c)
		c.build(looks[i])
		c.position = Vector3((i % cols) * 1.3, 0, (i / cols) * 1.6)
		c.rotation.y = deg_to_rad(-135.0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.5
	cam.rotation_degrees = Vector3(-30, 0, 0)
	cam.position = Vector3((cols - 1) * 1.3 / 2.0, 6.0, 3.2 + 9.0)
	stage.add_child(cam)
	cam.make_current()
	await _frames(30)
	await _shot("4_lineup")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out, name]
	img.save_png(path)
	print("saved ", path)
