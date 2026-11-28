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
	await _test_floor_zero()
	await _test_fight_fixes()
	await _test_consistency()
	await _test_polish()
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


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


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
	main.start_level(1, 1)
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
	main.start_level(1, 1)
	var body = main.find_object("brann")
	check(body != null and body.kind == "examine" and body.character._held, "he's still lying there when you come back")
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
	print("Title screen")
	Baseline.reset()
	Baseline.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.ui.is_title_visible(), "the game opens on the title screen")
	check(main.level != null and main.level.data.get("id") == "f00_l01" and not main.climber.visible, "The Road plays behind it, with no climber yet")
	check(Baseline.level_num == 1 and not Baseline.has_save(), "the title screen saves nothing")
	main._on_title_choice("new")
	check(not main.ui.is_title_visible() and main.climber.visible, "New climb starts the game")
	check(main.level.data.get("id") == "f00_l01" and Baseline.floor_num == 0, "on The Road, Floor 0")

	print("The opening scene")
	check(main.cutscene.playing and main.ui.is_cinematic(), "a new climb opens with The Road playing itself")
	var start_pos: Vector3 = main.climber.position
	await get_tree().create_timer(2.5).timeout
	check(main.climber.position.distance_to(start_pos) > 0.5, "the climber walks on their own")
	main._unhandled_input(_key(KEY_ESCAPE))
	check(await _until(func(): return main.is_talking()), "skipping jumps to Wil's question")
	check(main._talk_node_id == "need" and not main.ui.is_cinematic(), "the player's first input is Wil's request")
	check(Baseline.knows("signpost") and Baseline.knows("deliveries_stopped") and Baseline.knows("marta_name"), "what the climber saw along the way is still learned")
	check(main.find_object("torn_ledger") == null, "the ledger page was picked up, so it's gone")
	check(main.choose_text("I'll tell her"), "you can promise")
	main.choose(0)
	check(await _until(func(): return not main.cutscene.playing), "then the scene finishes by itself")
	check(Baseline.has_flag("carrying_wil_message") and Baseline.has_flag("cutscene_seen:f00_l01"), "the promise is kept, and the scene won't replay")
	check(main.level.data.get("id") == "f00_l02", "the road leads on to the bridge")
	check(not Baseline.has_flag("examined:wil") or Baseline.value("speed_patience") == 0.0, "watching the scene doesn't count toward how you play")

	print("Floor 0, Level 1: The Road (outdoors)")
	Baseline.reset()
	Baseline.set_flag("cutscene_seen:f00_l01")
	check(main.start_level(0, 1), "The Road (Floor 0) loads")
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
	check(main.level.data.get("id") == "f00_l02", "The Road leads to the Bridge")
	main.start_level(0, 4)
	main.interact(main.find_object("dunmore"))
	main.choose_text("I'll wait")
	main.choose(0)
	main.interact(main.find_object("tower_gate"))
	main.choose_text("Go in")
	check(Baseline.floor_num == 1 and Baseline.level_num == 1, "through the gate is Floor 1")
	check(main.ui.is_opening_visible() and not Baseline.has_flag("intro_seen:1"), "the tower's opening appears as you go in")
	check(main.level.data.get("id") == "f00_l04", "the Waiting Hall waits until you choose to climb")
	main.ui.finish_opening()
	check(main.level.data.get("id") == "f01_l01", "then the Waiting Hall")
	check(Baseline.has_flag("intro_seen:1"), "the opening counts as seen once read to the end")
	check(Baseline.has_flag("carrying_wil_message"), "promises carry over between levels")
	check(Baseline.has_flag("completed:f00_l01"), "The Road is marked done")

	print("Moving between levels")
	main.go_back()
	check(main._note_open and main.level.data.get("id") == "f01_l01", "no way back down past a floor's first level")
	main.choose(0)
	Baseline.level_num = 10
	main.end_level()
	check(main._note_open and not main._ended, "you can't leave a floor until its boss is faced")
	main.choose(0)
	Baseline.level_num = 1
	main.start_level(0, 1, "back")
	var exit_obj = main.find_object("road_on")
	check(main.level.chebyshev(main.climber.cell, exit_obj.cell) <= 1, "coming back, you appear by the way forward")
	main.start_level(1, 1)
	Baseline.learn("marta_motive")
	main.interact(main.find_object("brann"))
	main.choose_text("Marta's choosing")
	main.choose(0)
	main.start_level(1, 1)
	check(main.find_object("brann") == null, "someone who left stays gone when you return")
	main.queue_free()
	Baseline.delete_save()
	await get_tree().process_frame


func _test_level_one() -> void:
	print("Floor 1, Level 1: the Waiting Hall")
	Baseline.reset()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.first_built_level() == Vector2i(0, 1), "the first built level is Floor 0, The Road")
	check(main.start_level(1, 1), "level 1-9 loads")
	var level = main.level
	check(level.width == 14 and level.height == 11, "map size is 14x11")
	check(level.is_walkable(level.spawn_cell), "spawn is walkable")
	for obj in level.objects:
		check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	check(not main.start_level(1, 10), "unbuilt level 1-10 reports not built")
	main.start_level(1, 1)
	level = main.level

	check(main.climber.character != null and main.climber.character.body_name == "raider", "the climber is a built character")
	var tobin_model = main.find_object("tobin").character
	check(tobin_model != null and tobin_model.head_name == "male-e", "Tobin is a built character with his own look")

	var board = main.find_object("loose_board")
	check(board != null and not board.revealed, "the loose floorboard starts hidden")
	main.interact(board)
	check(not main.is_talking() and not Baseline.knows("marta_motive"), "hidden things can't be used before they're found")
	main._on_entered_cell(board.cell + Vector2i(1, 0))
	check(not board.revealed, "walking past the floorboard doesn't give it away")
	main._on_entered_cell(board.cell)
	check(board.revealed and String(main.ui.speech._current.get("kind", "")) != "notice", "stepping on it shows it, without a word")
	main.interact(board)
	for i in 5:
		if main.is_talking():
			main.choose(0)
	check(Baseline.knows("marta_motive") and Baseline.has_flag("found_letter"), "reading the letter teaches Marta's motive")
	check(board.opened and Baseline.has_flag("used:loose_board"), "the board stays pried open")
	main.interact(board)
	check(main.ui._body.text.contains("Nothing else"), "looking again finds it empty")
	while main.is_talking():
		main.choose(0)

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
	check(Baseline.floor_num == 1 and Baseline.level_num == 2, "going on heads to Floor 1, Level 2")
	check(Baseline.resume.is_empty(), "finishing the level clears the mid-level resume point")
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

	print("Walking and talking with a controller")
	main.start_level(1, 1)
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
	check(Baseline.floor_num == 0 and Baseline.level_num == 1, "a new climb starts on The Road (Floor 0)")
	main.start_level(1, 1)
	var hidden = main.find_object("loose_board")
	main._on_entered_cell(hidden.cell)
	main.interact(hidden)
	while main.is_talking():
		main.choose(0)
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
	check(main.find_object("loose_board").opened, "and opened things stay open")
	check(Baseline.knows("marta_name") and Baseline.has_flag("talked_tobin"), "what the climber learned is kept")
	check(is_equal_approx(Baseline.value("others_self"), saved_others), "the baseline is kept")

	main.queue_free()
	await get_tree().process_frame


func _test_polish() -> void:
	print("Speech, camera and fixes")
	Baseline.reset()
	Baseline.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	check(main.cam.projection == Camera3D.PROJECTION_PERSPECTIVE and main.cam.fov < 40.0, "the camera has a slight perspective")
	main._on_title_choice("how")
	check(main.ui._card.visible and main.ui._card_body.text.contains("walk"), "How to play explains the controls")
	main.ui._on_card(0)
	check(main.ui.is_title_visible(), "and goes back to the title")

	main._on_title_choice("new")
	await get_tree().process_frame
	check(main.cutscene.playing, "the road scene plays")
	var wil = main.find_object("wil")
	var callout := String(wil.def.get("call_out", {}).get("text", ""))
	main._on_entered_cell(wil.cell)
	check(callout == "" or main.ui.speech.current_text() != callout, "call-outs stay quiet during a scene")
	main.start_level(1, 1)
	for i in 30:
		await get_tree().process_frame
	check(not main.cutscene.playing and not main.ui.is_cinematic(), "a scene stopped by a level change leaves no letterbox behind")
	check(main.ui.speech.is_idle(), "and no leftover speech")

	var tobin = main.find_object("tobin")
	var brann = main.find_object("brann")
	main.ui.speech.clear()
	tobin.bark("First")
	brann.bark("Second")
	check(main.ui.speech.current_text() == "First" and main.ui.speech.waiting() == 1, "lines queue instead of overlapping")
	main.climber.say("Now")
	check(main.ui.speech.current_text() == "Now" and main.ui.speech.waiting() == 0, "a scene's line goes first")
	main.ui.speech.clear()

	var path: Array = main.level.find_path(main.climber.cell, main.level.spawn_cell + Vector2i(0, -2))
	main.climber.walk(path)
	main.climber.place(main.level.spawn_cell)
	check(not main.climber.character._moving, "placing the climber stops the walk")

	main.interact(tobin)
	check(main.ui._portrait_frame.visible, "people talk with their portrait beside the words")
	while main.is_talking():
		main.choose(main._talk_choices.size() - 1 if not main._talk_choices.is_empty() else 0)
	main.interact(main.find_object("bedrolls"))
	check(not main.ui._portrait_frame.visible, "things have no portrait")
	while main.is_talking() or main._note_open:
		main.choose(main._talk_choices.size() - 1 if not main._talk_choices.is_empty() else 0)

	print("Touch controls")
	main.ui.force_touch = true
	main.climber.place(Vector2i(6, 9))
	main.cam.snap()
	await get_tree().process_frame
	var pad: Dictionary = main.ui._pad_buttons
	check(main.ui._pad.visible and pad.size() == 5, "the on-screen pad shows its five buttons")
	check(not pad["strike"].useful and not pad["kick"].useful, "fight buttons stay faint outside a fight")
	main.combat._set_lock(brann)
	await get_tree().process_frame
	check(pad["strike"].useful and pad["block"].useful, "locking on brightens the fight buttons")
	check(main.climber.character.is_holding("sword"), "locking on draws the climber's sword")
	main.combat._set_lock(null)
	await get_tree().process_frame
	check(not main.climber.character.is_holding("sword"), "and letting go puts it away")
	var before_children: int = main.get_child_count()
	main.combat.strike()
	check(main.get_child_count() == before_children + 1, "a swing draws a slash in the world")
	await get_tree().create_timer(0.4, true, false, true).timeout
	check(Engine.time_scale == 1.0, "time runs normally again after a hit")

	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = Vector2(vp.x * 0.2, vp.y * 0.6)
	main._unhandled_input(down)
	check(main._stick_index == 0 and main.ui._stick.visible, "a thumb on the left becomes a stick")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = down.position + Vector2(0, -90)
	main._unhandled_input(drag)
	var before: Vector3 = main.climber.position
	await get_tree().create_timer(0.4).timeout
	check(main.climber.position.distance_to(before) > 0.3, "pushing the stick walks the climber")
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = drag.position
	main._unhandled_input(up)
	check(main._stick_index == -1 and not main.ui._stick.visible, "lifting the thumb lets go of the stick")

	var tap_at: Vector2 = main.cam.unproject_position(tobin.world_center())
	down.position = tap_at
	up.position = tap_at
	main._unhandled_input(down)
	main._unhandled_input(up)
	check(main._pending == tobin, "a quick tap on someone walks to them")
	main.climber.stop()
	main._pending = null
	var ground_at: Vector2 = main.cam.unproject_position(main.level.cell_to_world(Vector2i(2, 2)))
	down.position = ground_at
	up.position = ground_at
	main._unhandled_input(down)
	main._unhandled_input(up)
	check(not main.climber.is_moving(), "tapping empty ground doesn't walk (the stick does)")
	main.ui.force_touch = false

	print("Saves")
	Baseline.reset()
	Baseline.floor_num = 1
	Baseline.level_num = 1
	Baseline.resume = {}
	Baseline.save()
	Baseline.reset()
	check(Baseline.load_save() and main.resume_climb() and main.ui.is_opening_visible(), "closing the game on the opening shows it again next time")
	main.ui.finish_opening()
	check(main.level.data.get("id") == "f01_l01" and Baseline.has_flag("intro_seen:1"), "then into the Waiting Hall")
	var f := FileAccess.open(Baseline.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	main.show_title()
	main._on_title_choice("continue")
	check(main.ui._card.visible and Baseline.has_save(), "an unreadable save is kept, and the player is asked")
	main.ui._on_card(0)
	check(main.ui.is_title_visible(), "Back returns to the title")
	main.queue_free()
	await get_tree().process_frame


func _finish_talk(main) -> void:
	var guard := 0
	while (main.is_talking() or main._note_open) and guard < 20:
		main.choose(0)
		guard += 1


func _test_floor_zero() -> void:
	print("Floor 0, Level 2: The Bridge")
	Baseline.reset()
	Baseline.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._leave_title()
	Baseline.set_flag("talked_wil")
	Baseline.set_flag("carrying_wil_message")
	check(main.start_level(0, 2), "The Bridge loads")
	var level = main.level
	for obj in level.objects:
		if obj.kind != "hidden":
			check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	var pell = main.find_object("pell")
	check(pell.character.spec.get("idle") == "sit", "Pell sits nursing his leg")
	main.interact(pell)
	main.choose_text("What happened")
	check(not main.choose_text("Someone cut"), "you can't call out a lie you haven't caught")
	main.choose_text("Good luck")
	_finish_talk(main)
	main.interact(main.find_object("cut_plank"))
	_finish_talk(main)
	check(Baseline.knows("plank_cut"), "the broken plank was cut, if you look")
	main.interact(pell)
	check(main.choose_text("Someone cut"), "then you can say so")
	check(Baseline.knows("sorrel"), "and Pell names who did it")
	main.choose_text("Can you walk")
	main.choose_text("Good luck")
	_finish_talk(main)
	var saw = main.find_object("rival_saw")
	main._on_entered_cell(saw.cell + Vector2i(0, -1))
	check(not saw.revealed, "the saw in the reeds stays hidden unless you step on it")
	main._on_entered_cell(saw.cell)
	check(saw.revealed, "stepping on it shows it")
	var branch = main.find_object("branch")
	main.interact(branch)
	_finish_talk(main)
	check(Baseline.has_flag("has_branch"), "you can pick up the branch")
	await get_tree().create_timer(0.4).timeout
	check(main.find_object("branch") == null, "and it's gone from the ground")
	main.interact(pell)
	check(main.choose_text("bind it"), "with the branch you can splint Pell's leg")
	main.choose(0)
	check(main.choose_text("Take the coin"), "he offers his only coin")
	main.choose(0)
	_finish_talk(main)
	check(Baseline.has_flag("pell_helped") and Baseline.has_flag("has_coin"), "Pell is helped, and you have his coin")
	check(main.find_object("pell") == null, "Pell limps off")
	main.interact(main.find_object("road_back"))
	main.choose_text("Go back")
	check(main.level.data.get("id") == "f00_l01", "you can go back to the Road")
	main.interact(main.find_object("road_on"))
	main.choose_text("Go on")
	check(main.level.data.get("id") == "f00_l02" and main.find_object("pell") == null, "and the Bridge remembers")
	main.interact(main.find_object("camp_on"))
	main.choose_text("Go on")

	print("Floor 0, Level 3: The Climbers' Camp")
	level = main.level
	check(level.data.get("id") == "f00_l03", "the Bridge leads to the Camp")
	for obj in level.objects:
		check(not level.path_to_object(level.spawn_cell, obj).is_empty(), "%s is reachable" % obj.id)
	check(main.find_object("pell_at_camp") != null and main.find_object("bryn") != null, "the Pell you helped is at the camp, and Bryn is with him")
	main.interact(main.find_object("bryn"))
	check(main.ui._body.text.contains("bound his leg"), "and Bryn knows it was you")
	_finish_talk(main)
	main.interact(main.find_object("ada"))
	check(main.choose_text("He said to tell you"), "you can give Ada her father's message")
	main.choose(0)
	check(main.choose_text("I'll carry it"), "she asks you to carry something up")
	_finish_talk(main)
	check(Baseline.has_flag("wil_message_delivered") and Baseline.has_flag("carrying_ada_ribbon"), "message delivered, ribbon carried")
	var hesk = main.find_object("hesk")
	main.climber.place(hesk.cell + Vector2i(-1, 0))
	main.interact(hesk)
	main.choose_text("Teach me")
	main.choose_text("Ready")
	check(main.combat.active and main.combat.is_foe(hesk), "Hesk spars with you")
	main.combat.manual = true
	main.climber.face(hesk.global_position)
	for i in 2:
		main.combat._cooldown = 0.0
		main.combat.strike()
	check(main.combat._awaiting == "yield", "Hesk yields after two hits")
	main.choose(0)
	_finish_talk(main)
	main.combat.manual = false
	check(main.find_object("hesk") != null and Baseline.has_flag("spar_done"), "sparing your partner leaves him standing")
	check(not Baseline.has_flag("hesk_dead"), "and nobody died")
	main.interact(main.find_object("gate_on"))
	main.choose_text("Go on")

	print("Floor 0, Level 4: The Gate")
	level = main.level
	check(level.data.get("id") == "f00_l04", "the Camp leads to the Gate")
	main.interact(main.find_object("tower_gate"))
	check(not main.choose_text("Go in"), "the gate is shut")
	_finish_talk(main)
	var hatch = main.find_object("bread_hatch")
	check(hatch != null and not hatch.revealed, "the bread hatch is easy to miss")
	main._on_entered_cell(hatch.cell + Vector2i(-1, 1))
	check(hatch.revealed, "walk close and it's there")
	main.interact(main.find_object("dunmore"))
	check(main.choose_text("One coin"), "Pell's coin pays the toll")
	_finish_talk(main)
	check(Baseline.has_flag("gate_open"), "Dunmore opens the gate")
	main.interact(main.find_object("tower_gate"))
	main.choose_text("Go in")
	check(main.ui.is_opening_visible(), "going in shows the tower's opening")
	main.ui.finish_opening()
	check(main.level.data.get("id") == "f01_l01", "and then the Waiting Hall")

	print("Floor 0: other ways past the gate")
	Baseline.reset()
	main.start_level(0, 4)
	Baseline.learn("deliveries_stopped")
	main.interact(main.find_object("dunmore"))
	check(not main.choose_text("Marta stopped the bread"), "you have to ask about the toll first")
	main.choose_text("Who says")
	main.choose(0)
	check(main.choose_text("Marta stopped the bread"), "knowing about the bread lets you call his bluff")
	_finish_talk(main)
	check(Baseline.has_flag("gate_open") and Baseline.has_flag("talked_dunmore_down"), "and he lets you in")
	Baseline.reset()
	main.start_level(0, 4)
	hatch = main.find_object("bread_hatch")
	main._on_entered_cell(hatch.cell)
	main.interact(hatch)
	main.choose_text("Crawl through")
	check(Baseline.floor_num == 1 and Baseline.has_flag("sneaked_in"), "or crawl through the bread hatch")
	main.ui.finish_opening()
	main.queue_free()
	Baseline.delete_save()
	await get_tree().process_frame


func _run_fight(main, seconds: float) -> void:
	main.combat.manual = true
	var t := 0.0
	while t < seconds and main.combat.active:
		main.combat.tick(0.05)
		t += 0.05
	main.combat.manual = false


func _test_fight_fixes() -> void:
	print("Losing, resting, aiming and fences")
	Baseline.reset()
	Baseline.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._leave_title()
	Baseline.set_flag("cutscene_seen:f00_l01")
	main.start_level(0, 1)
	var wil = main.find_object("wil")
	main.climber.place(wil.cell + Vector2i(1, 0))
	main.combat.start_from_dialogue(wil, "")
	_run_fight(main, 30.0)
	var rock = main.find_object("road_rock")
	check(not main.combat.active and Baseline.wounds == 1, "losing a fight leaves you on your last wound")
	check(main.level.chebyshev(main.climber.cell, rock.cell) <= 1, "you come to by the level's resting spot, not where you fell")
	check(main.ui._body.text.contains("flat rock"), "and the text says where you are")
	check(wil.cell == wil.home_cell, "whoever beat you goes back to what they were doing")
	main.choose(0)
	main.interact(wil)
	check(main.ui._body.text.contains("won't say a word"), "someone you attacked won't chat as if nothing happened")
	main.choose(0)
	main.interact(rock)
	check(main.choose_text("Rest a while"), "you can rest by the rock when hurt")
	check(Baseline.wounds == Baseline.max_wounds, "and your wounds close")
	for lv in [[0, 1], [0, 2], [0, 3], [0, 4], [1, 1]]:
		main.start_level(lv[0], lv[1])
		var spots := {}
		for obj in main.level.objects:
			if obj.def.get("rest_spot", false):
				spots[obj.id] = true
		check(spots.size() == 1, "level %d-%d has a place to rest" % lv)

	Baseline.reset()
	main.start_level(0, 3)
	var ada = main.find_object("ada")
	main.climber.place(ada.cell + Vector2i(-1, 0))
	main.combat._set_lock(ada)
	main.climber.facing_dir = Vector3(-1, 0, 0)
	main.climber.rotation.y = 0.0
	main.combat._cooldown = 0.0
	check(main.combat.strike(), "a swing turns toward whoever you're locked on to")
	main.combat.reset(main.level)
	main.climber.lock_face = null

	var hesk = main.find_object("hesk")
	main.climber.place(hesk.cell + Vector2i(-2, 0))
	main.interact(hesk)
	main.choose_text("Teach me")
	main.choose_text("Ready")
	check(not Baseline.has_flag("attacked:hesk"), "a spar isn't an attack")
	_run_fight(main, 30.0)
	var c: Vector2i = main.climber.cell
	check(main.ui._body.text.contains("hauls you up") and c.x >= 16 and c.x <= 21 and c.y >= 8 and c.y <= 13, "lose a spar and Hesk helps you up where you fell, in the ring")
	check(Baseline.wounds == Baseline.max_wounds, "and patches you up")
	main.choose(0)
	main.interact(hesk)
	check(main.choose_text("Again"), "you can always spar again")
	main.combat.reset(main.level)

	var lvl = main.level
	var fence_cell := Vector2i(18, 8)
	check(lvl.fences.has(fence_cell), "the ring has a fence")
	var line: Vector3 = lvl.cell_to_world(fence_cell)
	check(not lvl.can_stand(line, 0.26), "you can't walk through a fence")
	check(lvl.can_stand(line + Vector3(0, 0, 0.36), 0.26), "but you can walk right up to it")
	check(lvl.fences.has(Vector2i(16, 9)) and not lvl.fences.has(Vector2i(16, 10)), "the ring's way in is one clear gap")
	main.queue_free()
	await get_tree().process_frame


func _test_consistency() -> void:
	print("Consistency: people, places and what they remember")
	Baseline.reset()
	Baseline.delete_save()
	var main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main._leave_title()
	Baseline.set_flag("cutscene_seen:f00_l01")
	main.start_level(0, 1)
	check(main.find_object("wil") != null, "Wil is on the road the first time")
	Baseline.set_flag("completed:f00_l01")
	main.start_level(0, 1, "back")
	check(main.find_object("wil") == null, "walk back later and he's long gone home")

	Baseline.reset()
	main.start_level(0, 2)
	main.interact(main.find_object("pell"))
	main.choose_text("Can you walk")
	main.choose_text("tell them at the camp")
	main.choose_text("Good luck")
	_finish_talk(main)
	main.start_level(0, 3)
	var bryn = main.find_object("bryn")
	main.interact(bryn)
	check(main.choose_text("He's hurt"), "you can tell Bryn where Pell is")
	_finish_talk(main)
	check(main.find_object("bryn") == null, "she runs off to find him")
	main.start_level(0, 2, "back")
	check(main.find_object("pell") == null, "Pell's no longer on the bridge")
	main.start_level(0, 3)
	bryn = main.find_object("bryn")
	check(main.find_object("pell_at_camp") != null and bryn != null, "both are at the camp afterwards")
	check(bryn.cell == Vector2i(8, 9), "Bryn sits with Pell")
	main.interact(bryn)
	check(main.ui._body.text.contains("right where you said"), "and thanks you for telling her")
	_finish_talk(main)

	print("Consistency: fights with people who can't or shouldn't")
	Baseline.reset()
	main.start_level(0, 2)
	var pell = main.find_object("pell")
	main.climber.place(pell.cell + Vector2i(2, 0))
	main.combat.start_from_dialogue(pell, "")
	var start_cell: Vector2i = pell.cell
	main.combat.manual = true
	for i in 40:
		main.combat.tick(0.05)
	main.combat.manual = false
	check(pell.cell == start_cell, "Pell can't chase you on a broken leg")
	main.climber.place(pell.cell + Vector2i(1, 0))
	for i in 2:
		main.combat._cooldown = 0.0
		main.combat.strike()
	main.choose(0)
	_finish_talk(main)
	check(Baseline.has_flag("robbed_pell") and Baseline.has_flag("has_coin"), "beat him and he gives up his coin")
	check(main.find_object("pell") != null, "and he's still sitting there")

	Baseline.reset()
	main.start_level(0, 3)
	var oda = main.find_object("oda")
	main.climber.place(oda.cell + Vector2i(1, 0))
	main.combat.start_from_dialogue(oda, "")
	main.combat.reset(main.level)
	main.interact(main.find_object("ada"))
	check(main.ui._body.text.contains("saw what you did") or main.find_object("ada").global_position.distance_to(oda.global_position) > 7.0, "people who saw an unprovoked attack keep their distance")
	_finish_talk(main)

	print("Consistency: the way in")
	Baseline.reset()
	Baseline.set_flag("sneaked_in")
	main.start_level(1, 1)
	main.interact(main.find_object("entry_gate"))
	check(main.ui._body.text.contains("bread hatch"), "come in through the hatch and the hall remembers it")
	_finish_talk(main)
	main.queue_free()
	await get_tree().process_frame
