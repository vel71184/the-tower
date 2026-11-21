extends Node
## Headless checks, run in CI with:  godot --headless --path . res://tests/test_runner.tscn
## Exits 0 when everything passes, 1 on any failure.

var _failures := 0
var _checks := 0


func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		push_error("Tests timed out")
		get_tree().quit(2))
	Baseline.delete_save()
	_test_baseline()
	_test_characters()
	await _test_level_one()
	Baseline.delete_save()
	print("\n%d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _test_baseline() -> void:
	print("Baseline")
	Baseline.reset()
	Baseline.nudge("patience")
	Baseline.nudge("speed", 3.0)
	check(is_equal_approx(Baseline.value("speed_patience"), -2.0), "nudges move an axis toward a pole")
	check(Baseline.lean("speed_patience") == "speed", "lean reports the stronger pole")
	Baseline.apply_once("k", {"nudge": {"others": 1}})
	Baseline.apply_once("k", {"nudge": {"others": 1}})
	check(is_equal_approx(Baseline.value("others_self"), -1.0), "apply_once can't be farmed")
	Baseline.learn("fact")
	check(Baseline.knows("fact"), "learned facts are remembered")
	check(Baseline.save(), "save writes")
	Baseline.reset()
	check(Baseline.load_save(), "save loads")
	check(is_equal_approx(Baseline.value("speed_patience"), -2.0) and Baseline.knows("fact"), "save round-trips")
	Baseline.delete_save()
	check(not Baseline.has_save(), "save deletes")


func _test_characters() -> void:
	print("Characters")
	var CM = load("res://scripts/characters/character_model.gd")
	var Looks = load("res://scripts/characters/looks.gd")
	var parts: Dictionary = CM.parts()
	check(parts.get("bodies", {}).size() == 20 and parts.get("heads", {}).size() == 20, "20 bodies and 20 heads")
	for color in CM.color_names():
		var r: Rect2 = CM.color_rect(color)
		check(r.size.x > 0.0 and r.end.x <= 1.0 and r.end.y <= 1.0, "colour %s has a palette cell" % color)
	for kind in ["bodies", "heads"]:
		for model in parts[kind]:
			for slot in parts[kind][model]:
				check(CM.is_color(parts[kind][model][slot]), "%s %s %s is a known colour" % [kind, model, slot])
	for item in parts.get("items", {}):
		check(CM.scene_for(parts["items"][item]) != null, "item %s has a model" % item)
	for chair in parts.get("wheelchairs", {}):
		check(CM.scene_for(parts["wheelchairs"][chair]) != null, "wheelchair %s has a model" % chair)

	var needed := ["idle", "walk", "interact-right", "emote-yes", "emote-no", "pick-up", "die", "attack-melee-right"]
	for body in parts["bodies"]:
		var c = CM.new()
		add_child(c)
		var ok: bool = c.build({"body": body})
		var anims_ok := ok and needed.all(func(a): return c.has_animation(a))
		check(ok and c.skeleton != null and c.body_mesh != null and c.head_mesh != null and anims_ok,
			"%s builds with a skeleton, both meshes and the key animations" % body)
		check(ok and c.swap_count(c.body_mesh) == 0, "%s with no colours changes nothing" % body)
		c.free()

	var donor = CM.scene_for("character-knight").instantiate()
	var knight_head: Mesh = null
	for mi in CM._find_all_type(donor, "MeshInstance3D"):
		if String(mi.name).to_lower().contains("head"):
			knight_head = mi.mesh
	donor.free()
	var mix = CM.new()
	add_child(mix)
	check(mix.build({"body": "worker", "head": "knight"}), "a knight head builds on a worker body")
	check(mix.head_mesh.mesh == knight_head and knight_head != null, "the head mesh comes from the knight")
	mix.free()

	var red = CM.new()
	add_child(red)
	red.build({"body": "male-a", "colors": {"shirt": "red", "pants": "charcoal", "hair": "gold", "skin": "brown"}})
	check(red.swap_count(red.body_mesh) == 2, "shirt and pants swap; skin already brown doesn't")
	check(red.swap_count(red.head_mesh) == 1, "hair swaps on the head")
	red.set_moving(true)
	check(red.current_animation() == "walk", "moving plays walk")
	red.set_moving(false)
	check(red.current_animation() == "idle", "stopping plays idle")
	red.free()

	var armed = CM.new()
	add_child(armed)
	armed.build({"body": "knight", "item": "sword", "item_left": "shield_round"})
	check(armed.skeleton.get_node_or_null("Holding_Sword") != null and armed.skeleton.get_node_or_null("Holding_ShieldRound") != null, "items attach to the hands")
	check(armed.current_animation() == "holding-both", "holding both hands plays holding-both")
	armed.free()

	var seated = CM.new()
	add_child(seated)
	seated.build({"body": "male-b", "wheelchair": "power"})
	check(seated.wheelchair != null and seated.current_animation() == "wheelchair-sit", "wheelchair users sit in their chair")
	seated.free()

	var people := {"shirt": ["gold", "slate"], "pants": ["ink"]}
	var a: Dictionary = Looks.resolve({}, people, "npc:same")
	var b: Dictionary = Looks.resolve({}, people, "npc:same")
	check(a == b, "the same person always gets the same look")
	var gold_npc: Dictionary = Looks.resolve({"colors": {"shirt": "gold"}}, people, "npc:gold")
	check(gold_npc["colors"]["shirt"] != "gold", "NPCs never wear the climber's reserved gold")
	var climber: Dictionary = Looks.resolve(Looks.climber_look(), {}, "climber", true)
	check(climber["colors"]["shirt"] == "gold", "the climber wears gold")
	var floor1: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/floors/floor_01/floor.json"))
	var reserved: Array = Looks.reserved_colors()
	var clean := true
	for slot in floor1["people"]:
		for v in floor1["people"][slot]:
			if reserved.has(v) or not (CM.is_color(v) or parts["bodies"].has(v)):
				clean = false
	check(clean, "floor 1's palette is valid and has no reserved colours")


func _test_level_one() -> void:
	print("Floor 1, Level 9 (the Waiting Hall)")
	Baseline.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.first_built_level() == Vector2i(1, 9), "the first built level is 1-9")
	check(main.start_level(1, 9), "level 1-9 loads")
	var level = main.level
	check(level.width == 14 and level.height == 11, "map size is 14x11")
	check(level.is_walkable(level.spawn_cell), "spawn is walkable")
	for obj in level.objects:
		check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	check(not main.start_level(1, 10), "unbuilt level 1-10 reports not built")
	main.start_level(1, 9)
	level = main.level

	check(main.climber.character != null and main.climber.character.body_name == "raider", "the climber is a built character")
	var tobin_model = main.find_object("tobin").character
	check(tobin_model != null and tobin_model.head_name == "male-e", "Tobin is a built character with his own look")

	var board = main.find_object("loose_board")
	check(board != null and not board.revealed, "the loose floorboard starts hidden")
	main.interact(board)
	check(not main.is_talking() and not Baseline.knows("marta_motive"), "hidden things can't be used before they're found")
	main._on_entered_cell(board.cell)
	check(board.revealed, "standing near the floorboard reveals it")
	main.interact(board)
	for i in 5:
		if main.is_talking():
			main.choose(0)
	check(Baseline.knows("marta_motive") and Baseline.has_flag("found_letter"), "reading the letter teaches Marta's motive")

	var tobin = main.find_object("tobin")
	main._on_entered_cell(tobin.cell + Vector2i(1, 0))
	check(Baseline.has_flag("heard_tobin"), "Tobin calls out when the climber comes near")
	main.interact(tobin)
	check(main.choose_text("Why are you climbing"), "can ask Tobin why he's climbing")
	main.choose(0)
	check(main.choose_text("carry it"), "can agree to carry the bird")
	main.choose(0)
	check(not main.is_talking(), "conversation ends")
	check(Baseline.value("others_self") < 0.0, "helping Tobin leans toward others")
	main.interact(tobin)
	check(main.is_talking(), "talking again works")
	main.choose(0)
	check(is_equal_approx(Baseline.value("others_self"), -1.0), "repeat conversations don't nudge again")

	main.interact(main.find_object("notice_board"))
	while main.is_talking():
		main.choose(0)
	main.interact(main.find_object("campfire"))
	while main.is_talking():
		main.choose(0)
	check(main.examined_count() == 4, "four distinct things examined")

	main.interact(main.find_object("passage"))
	check(main.choose_text("Go on"), "the exit offers to go on")
	check(Baseline.level_num == 10, "finishing the level advances to level 10")
	check(Baseline.resume.is_empty(), "finishing the level clears the mid-level resume point")
	check(Baseline.has_save(), "finishing the level saves")
	check(is_equal_approx(Baseline.value("speed_patience"), 1.0), "a careful look around leans toward patience")

	print("Floor 1, Level 9: walking past Tobin")
	Baseline.reset()
	main.start_level(1, 9)
	main._on_entered_cell(main.find_object("tobin").cell + Vector2i(0, 1))
	main.interact(main.find_object("passage"))
	main.choose_text("Go on")
	check(is_equal_approx(Baseline.value("others_self"), 2.0), "ignoring a call for help leans toward self")
	check(is_equal_approx(Baseline.value("speed_patience"), -1.0), "rushing through leans toward speed")

	print("Autosave and resume")
	main.new_climb()
	check(Baseline.floor_num == 1 and Baseline.level_num == 9, "a new climb starts at the first built level")
	var hidden = main.find_object("loose_board")
	main._on_entered_cell(hidden.cell)
	main.climber.place(Vector2i(4, 7))
	main.interact(main.find_object("tobin"))
	main.choose_text("Who says")
	main.choose(0)
	main.choose_text("That's all")
	check(not main.is_talking(), "conversation closed")
	main.autosave()
	var saved_others := Baseline.value("others_self")
	Baseline.reset()
	check(Baseline.load_save(), "the mid-level save loads")
	check(main.resume_climb(), "resuming reopens the level")
	check(main.climber.cell == Vector2i(4, 7), "the climber is back where they stopped")
	check(main.find_object("loose_board").revealed, "found hidden things stay found")
	check(Baseline.knows("marta_name") and Baseline.has_flag("talked_tobin"), "what the climber learned is kept")
	check(is_equal_approx(Baseline.value("others_self"), saved_others), "the baseline is kept")

	main.queue_free()
	await get_tree().process_frame
