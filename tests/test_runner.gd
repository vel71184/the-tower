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


func _test_level_one() -> void:
	print("Floor 1, Level 1")
	Baseline.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.start_level(1, 1), "level 1-1 loads")
	var level = main.level
	check(level.width == 14 and level.height == 11, "map size is 14x11")
	check(level.is_walkable(level.spawn_cell), "spawn is walkable")
	for obj in level.objects:
		check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	check(not main.start_level(1, 2), "unbuilt level 1-2 reports not built")
	main.start_level(1, 1)
	level = main.level

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
	check(Baseline.level_num == 2, "finishing the level advances to level 2")
	check(Baseline.has_save(), "finishing the level saves")
	check(is_equal_approx(Baseline.value("speed_patience"), 1.0), "a careful look around leans toward patience")

	print("Floor 1, Level 1: walking past Tobin")
	Baseline.reset()
	main.start_level(1, 1)
	main._on_entered_cell(main.find_object("tobin").cell + Vector2i(0, 1))
	main.interact(main.find_object("passage"))
	main.choose_text("Go on")
	check(is_equal_approx(Baseline.value("others_self"), 2.0), "ignoring a call for help leans toward self")
	check(is_equal_approx(Baseline.value("speed_patience"), -1.0), "rushing through leans toward speed")

	main.queue_free()
	await get_tree().process_frame
