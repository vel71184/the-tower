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
	_test_controls()
	await _test_level_one()
	await _test_brawl()
	await _test_road()
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
	check(parts.get("bodies", {}).size() == 29 and parts.get("heads", {}).size() == 29, "29 bodies and 29 heads")
	for model in parts["models"]:
		check(CM.model_scene(model) != null, "model %s loads from %s" % [model, CM.family_of(model)])
	for color in CM.color_names():
		var r: Rect2 = CM.color_rect(color)
		check(r.size.x > 0.0 and r.end.x <= 1.0 and r.end.y <= 1.0, "colour %s has a palette cell" % color)
	for kind in ["bodies", "heads"]:
		for model in parts[kind]:
			var cells: Dictionary = CM.family_cells(CM.family_of(model))
			for slot in parts[kind][model]:
				var v: Variant = parts[kind][model][slot]
				var ok: bool = CM.is_color(v) if v is String else (v as Array).all(func(c): return cells.has(Vector2i(int(c[0]), int(c[1]))))
				check(ok, "%s %s %s points at real colours" % [kind, model, slot])
	for item in parts.get("items", {}):
		check(CM.scene_for(parts["items"][item]) != null, "item %s has a model" % item)
	for chair in parts.get("wheelchairs", {}):
		check(CM.scene_for(parts["wheelchairs"][chair]) != null, "wheelchair %s has a model" % chair)

	var needed := ["idle", "walk", "interact-right", "emote-yes", "emote-no", "pick-up", "die", "attack-melee-right", "attack-kick-right", "holding-right-shoot"]
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
	check(red.swap_count(red.body_mesh) == 4, "shirt and pants swap (light and dark cells); skin already brown doesn't")
	check(red.swap_count(red.head_mesh) == 2, "hair swaps on the head")
	red.free()
	red = CM.new()
	add_child(red)
	red.build({"body": "arena-soldier", "head": "dungeon-orc", "colors": {"shirt": "blue", "skin": "cream", "species": "violet"}})
	check(red.swap_count(red.body_mesh) >= 2, "another family's body recolours (Roman soldier, blue tunic, cream skin)")
	check(red.swap_count(red.head_mesh) >= 1, "another family's head recolours (orc species to violet)")
	check(CM.nearest_cell("mini-arena", Color("#e64d3e")) == Vector2i(9, 2), "nearest-colour lookup finds an exact cell")
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


func Main_screen(v: Vector2) -> Vector3:
	return load("res://scripts/game/main.gd").screen_to_world(v)


func _has_pad_button(action: String, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false


func _test_controls() -> void:
	print("Controls (controller and keyboard)")
	check(_has_pad_button("interact", JOY_BUTTON_A), "bottom face button interacts")
	check(_has_pad_button("ui_accept", JOY_BUTTON_A), "bottom face button confirms menu choices")
	check(_has_pad_button("attack", JOY_BUTTON_X), "left face button attacks")
	check(_has_pad_button("kick", JOY_BUTTON_Y), "top face button kicks")
	check(_has_pad_button("block", JOY_BUTTON_B), "right face button blocks")
	check(_has_pad_button("lock_on", JOY_BUTTON_LEFT_SHOULDER) and _has_pad_button("lock_next", JOY_BUTTON_RIGHT_SHOULDER), "shoulders lock on and switch targets")
	check(_has_pad_button("move_up", JOY_BUTTON_DPAD_UP) and _has_pad_button("move_left", JOY_BUTTON_DPAD_LEFT), "d-pad walks")
	var stick := false
	for e in InputMap.action_get_events("move_right"):
		stick = stick or (e is InputEventJoypadMotion and e.axis == JOY_AXIS_LEFT_X and e.axis_value > 0)
	check(stick, "left stick walks")
	check(_has_pad_button("dev_overlay", JOY_BUTTON_BACK), "Select toggles the dev overlay")
	var Main = load("res://scripts/game/main.gd")
	var up: Vector3 = Main.screen_to_world(Vector2(0, -1))
	check(up.x < -0.6 and up.z < -0.6, "stick up walks up the screen")
	var right: Vector3 = Main.screen_to_world(Vector2(1, 0))
	check(right.x > 0.6 and right.z < -0.6, "stick right walks right on screen")
	check(Main.screen_to_world(Vector2.ZERO) == Vector3.ZERO, "a centred stick stands still")


func _until(cond: Callable, frames: int = 600) -> bool:
	for i in frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## A fresh Waiting Hall with the climber next to Brann, facing him, with fight time driven by tick().
func _brawl_setup(main, climber_cell: Vector2i = Vector2i(5, 5)) -> void:
	main.start_level(1, 9)
	main.combat.manual = true
	main.climber.place(climber_cell)
	main.climber.face(main.find_object("brann").global_position)


## Lets the fight run for a while (Brann walks and swings on his own).
func _run(c, seconds: float) -> void:
	var t := 0.0
	while t < seconds and c.active and not c.ui.is_busy():
		c.tick(0.05)
		t += 0.05
		await get_tree().process_frame


func _test_brawl() -> void:
	print("The Waiting Hall brawl (real-time combat)")
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var c = main.combat
	var brann

	# Swing first, then spare him when he yields.
	Baseline.reset()
	_brawl_setup(main)
	brann = main.find_object("brann")
	main.interact(brann)
	check(main.choose_text("Hit him first"), "you can swing first from the conversation")
	check(c.active and c.is_foe(brann), "Brann is now fighting you")
	check(c.foes[brann]["wounds"] == 2, "the opening swing took one of Brann's 3 wounds")
	check(Baseline.habits.get("openers", {}).get("strike", 0) == 1, "the opener is recorded as a habit")
	check(c.lock_target == brann, "you're locked on to him")
	c.tick(1.0)
	main.climber.face(brann.global_position)
	c.strike()
	check(c._awaiting == "yield", "at one wound left, Brann yields")
	main.choose(0)
	check(not c.active and main.find_object("brann") == null, "letting him go ends the fight and he leaves")
	check(Baseline.has_flag("brann_spared") and Baseline.value("others_self") < 0.0, "sparing him is remembered and leans toward others")
	check(Baseline.value("force_persuasion") < 0.0, "swinging first leans toward force")
	main.choose(0)

	# Finish him instead.
	Baseline.reset()
	_brawl_setup(main)
	brann = main.find_object("brann")
	main.interact(brann)
	main.choose_text("Hit him first")
	c.tick(1.0)
	main.climber.face(brann.global_position)
	c.strike()
	main.choose(1)
	check(Baseline.has_flag("brann_dead") and Baseline.has_flag("killed:brann"), "finishing him is remembered")
	check(brann.kind == "examine", "his body stays where he fell")
	main.choose(0)
	main.interact(main.find_object("tobin"))
	check(main._talk_node_id == "after_kill", "Tobin reacts to the killing")
	while main.is_talking():
		main.choose(0)

	# Talk him down in the middle of the fight, using what the letter taught you.
	Baseline.reset()
	Baseline.learn("marta_motive")
	_brawl_setup(main)
	brann = main.find_object("brann")
	main.interact(brann)
	main.choose_text("Let him go")
	check(main.choose_text("Fight him"), "you can choose to fight him after he squares up")
	check(c.talk() and main.ui.is_busy(), "talking mid-fight opens your lines")
	main.choose(0)
	check(not c.active and Baseline.has_flag("talked_down_brann") and main.find_object("brann") == null, "the right words end the fight")
	check(Baseline.habits.get("actions", {}).get("talk", 0) == 1, "talking is counted as a fighting habit")
	main.choose(0)

	# Talk him down before any fight starts.
	Baseline.reset()
	Baseline.learn("marta_motive")
	_brawl_setup(main)
	main.interact(main.find_object("brann"))
	check(main.choose_text("Marta's choosing"), "knowing Marta's motive opens a new line")
	main.choose(0)
	check(main.find_object("brann") == null and Baseline.has_flag("talked_down_brann"), "he walks off without a fight")
	main.interact(main.find_object("tobin"))
	check(main._talk_node_id == "thanks", "Tobin thanks you")
	while main.is_talking():
		main.choose(main._talk_choices.size() - 1 if not main._talk_choices.is_empty() else 0)

	# Kick: knocks him back a cell, never wounds.
	Baseline.reset()
	_brawl_setup(main, Vector2i(4, 6))
	brann = main.find_object("brann")
	main.interact(brann)
	main.choose_text("Let him go")
	main.choose_text("Fight him")
	c.tick(1.0)
	main.climber.face(brann.global_position)
	check(c.kick(), "the kick connects")
	check(c.events.has("kick_moved:brann") and brann.cell == Vector2i(4, 4), "a kick knocks him back a cell")
	check(c.foes[brann]["wounds"] == 3, "a kick doesn't wound")

	# Block: hold it facing him and his swing glances off.
	c.set_blocking(true)
	for i in 40:
		if not c.active or not is_instance_valid(brann) or c.events.has("strike_blocked:climber"):
			break
		main.climber.face(brann.global_position)
		await _run(c, 0.25)
	check(c.events.has("strike_blocked:climber"), "blocking stops his swing")
	c.set_blocking(false)

	# Losing: at zero wounds the climber falls, and the world moves on.
	Baseline.reset()
	Baseline.wounds = 1
	_brawl_setup(main)
	main.interact(main.find_object("brann"))
	main.choose_text("Let him go")
	main.choose_text("Fight him")
	await _run(c, 8.0)
	check(not c.active, "the fight ends when you fall")
	check(Baseline.has_flag("lost_to_brann") and Baseline.has_flag("bird_stolen"), "losing has consequences")
	check(Baseline.wounds == 1, "you wake with one wound")
	main.choose(0)
	check(not main.climber.character._held, "you get back up")

	# Rest at the bedrolls.
	main.interact(main.find_object("bedrolls"))
	check(main.choose_text("Rest"), "the bedrolls offer rest when you're hurt")
	check(Baseline.wounds == Baseline.max_wounds, "resting closes your wounds")
	main.interact(main.find_object("bedrolls"))
	check(not main.choose_text("Rest"), "no rest offered when you're not hurt")
	while main.is_talking():
		main.choose(main._talk_choices.size() - 1 if not main._talk_choices.is_empty() else 0)

	# Anyone can be attacked, but only on purpose (design doc: residents, not enemies).
	Baseline.reset()
	_brawl_setup(main, Vector2i(3, 6))
	var tobin = main.find_object("tobin")
	main.climber.face(tobin.global_position)
	c._cooldown = 0.0
	check(not c.strike() and not c.is_foe(tobin), "a swing near a peaceful person doesn't hurt them")
	c.tick(1.0)
	c.toggle_lock()
	check(c.lock_target == tobin, "locking on picks the person you face")
	check(c.strike() and c.is_foe(tobin), "a locked-on swing is a deliberate first strike")
	check(Baseline.has_flag("attacked:tobin") and Baseline.value("force_persuasion") < 0.0, "attacking someone peaceful is remembered")
	check(c.foes[tobin]["wounds"] == 2, "it wounds them")

	main.queue_free()
	Baseline.delete_save()
	await get_tree().process_frame


func _test_road() -> void:
	print("Floor 1, Level 1: The Road (outdoors)")
	Baseline.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.start_level(1, 1), "The Road loads")
	var level = main.level
	check(level.get_node_or_null("Ground") != null, "the ground is one merged mesh")
	check(level.get_node_or_null("Backdrop") != null, "the tower looms in the backdrop")
	var props := 0
	for child in level.get_children():
		if child.scene_file_path.begins_with("res://assets/kenney/"):
			props += 1
	check(props > 40, "Kenney trees, rocks and plants dress the level (%d props)" % props)
	check(level.is_walkable(level.spawn_cell), "the climber starts on the path")
	for obj in level.objects:
		check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	check(not level.is_walkable(Vector2i(0, 0)), "trees block the way")
	main.interact(main.find_object("wil"))
	main.choose_text("Do you need anything")
	main.choose_text("I'll tell her")
	main.choose(0)
	check(Baseline.has_flag("carrying_wil_message") and Baseline.knows("ada"), "you can promise Wil to find his daughter")
	main.interact(main.find_object("road_on"))
	main.choose_text("Go on")
	check(Baseline.floor_num == 1 and Baseline.level_num == 9, "unbuilt levels 2-8 are skipped: next is the Waiting Hall")
	check(Baseline.has_flag("carrying_wil_message"), "promises carry over between levels")
	main.queue_free()
	Baseline.delete_save()
	await get_tree().process_frame


func _test_level_one() -> void:
	print("Floor 1, Level 9 (the Waiting Hall)")
	Baseline.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.first_built_level() == Vector2i(1, 1), "the first built level is 1-1, The Road")
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

	print("Walking and talking with a controller")
	main.start_level(1, 9)
	main.climber.place(Vector2i(6, 8))
	var before: Vector3 = main.climber.position
	for i in 20:
		main.climber.move_free(Main_screen(Vector2(1, 0)), 0.05)
	check(main.climber.position.distance_to(before) > 1.0, "the stick walks smoothly (no grid steps)")
	main.climber.place(Vector2i(1, 1))
	for i in 30:
		main.climber.move_free(Main_screen(Vector2(0, -1)), 0.05)
	check(main.climber.position.x > 1.0 and main.climber.position.z > 1.0, "walls stop you")
	main.climber.place(Vector2i(3, 6))
	main.climber.face(main.find_object("tobin").global_position)
	check(main.focus_object() == main.find_object("tobin"), "the person you face is highlighted")
	check(main.pad_interact() and main.is_talking(), "the interact button talks to them")
	while main.is_talking():
		main.choose(main._talk_choices.size() - 1 if not main._talk_choices.is_empty() else 0)

	print("Autosave and resume")
	main.new_climb()
	check(Baseline.floor_num == 1 and Baseline.level_num == 1, "a new climb starts on The Road")
	main.start_level(1, 9)
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
