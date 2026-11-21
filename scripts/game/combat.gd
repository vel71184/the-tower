extends Node
## Turn-based fights on the level's own grid (design doc: "Combat").
##
## A climber turn: walk up to MOVES_PER_TURN cells, then one action. Actions:
##   strike  - a hit takes one wound; at zero wounds, someone falls
##   shove   - pushes the target back a cell without hurting them; if they can't move back,
##             they stagger and lose their next turn
##   guard   - the next strike against you this round is blocked
##   talk    - say something; with the right knowledge, a fight can end in words
##   wait    - end the turn
## Opponents then take their turns. Everything the climber does is counted as a habit for
## floor 100 (Baseline.habits).
##
## A fight is defined in level JSON under "fights":
##   "brann": {"opponents": ["brann"], "wounds": 3, "yield_at": 1,
##             "yield_text": "...", "talk": [...], "outcomes": {"killed": effects, ...}}

signal turn_started(who: String)
signal ended(outcome: String)

const MOVES_PER_TURN := 3
const ACTIONS := ["strike", "shove", "guard", "talk", "wait"]
const LABELS := {"strike": "Strike", "shove": "Shove", "guard": "Guard", "talk": "Talk", "wait": "End turn"}

var main
var level
var climber
var ui

var active := false
var fight_id := ""
var fight: Dictionary = {}
var foes: Array = []
var wounds: Dictionary = {}
var turn := ""
var moves_left := 0
var busy := false
## Seconds between beats. Tests set this to 0.
var pace := 0.45

var _guarding: Dictionary = {}
var _staggered: Dictionary = {}
var _acted_this_fight := false
var _awaiting := ""
var _talk_options: Array = []


func setup(main_node) -> void:
	main = main_node
	level = main.level
	climber = main.climber
	ui = main.ui


## Starts a fight. opener: an action the climber takes immediately (e.g. "strike" when they
## swing first from a conversation).
func start(id: String, data: Dictionary, opener: String = "") -> void:
	level = main.level
	fight_id = id
	fight = data
	foes.clear()
	wounds.clear()
	_guarding.clear()
	_staggered.clear()
	_acted_this_fight = false
	_awaiting = ""
	for foe_id in data.get("opponents", []):
		var obj = main.find_object(String(foe_id))
		if obj:
			foes.append(obj)
			wounds[obj] = int(data.get("wounds", 3))
	if foes.is_empty():
		push_warning("Fight '%s' has no opponents here" % id)
		return
	active = true
	climber.stop()
	Baseline.habit("fights")
	Baseline.record("fight", id)
	_show_wounds()
	ui.toast("Fight!", 1.5)
	_begin_climber_turn()
	if opener != "":
		await act(opener)


func is_climber_turn() -> bool:
	return active and turn == "climber" and not busy and _awaiting == ""


# --- Climber turn ---------------------------------------------------------------------------

func _begin_climber_turn() -> void:
	turn = "climber"
	_guarding.erase(climber)
	moves_left = 0 if _staggered.get(climber, false) else MOVES_PER_TURN
	_staggered.erase(climber)
	_refresh_bar()
	turn_started.emit("climber")


## Walks the climber toward a cell, using up moves. Returns true if they moved.
func move_to(cell: Vector2i) -> bool:
	if not is_climber_turn() or moves_left <= 0:
		return false
	var path: Array = level.find_path(climber.cell, cell)
	if path.size() < 2:
		return false
	path = path.slice(0, mini(path.size(), moves_left + 1))
	moves_left -= path.size() - 1
	busy = true
	climber.walk(path)
	while climber.is_moving():
		await get_tree().process_frame
	busy = false
	_refresh_bar()
	return true


## One grid step from the stick or d-pad.
func step(dir: Vector2i) -> bool:
	if not is_climber_turn():
		return false
	var to: Vector2i = climber.cell + dir
	if moves_left <= 0 or not main._can_step(climber.cell, to):
		var foe = _foe_at(to)
		if foe:
			climber.face(foe.global_position)
		return false
	return await move_to(to)


## Takes an action on the climber's turn. Returns true if it was used.
func act(action: String) -> bool:
	if not is_climber_turn() or not ACTIONS.has(action):
		return false
	var target = _adjacent_foe()
	if (action == "strike" or action == "shove") and target == null:
		ui.toast("No one in reach", 1.2)
		return false
	if action == "talk":
		_open_talk()
		return true
	if action != "wait":
		_count(action)
	busy = true
	match action:
		"strike":
			await _strike(climber, target)
		"shove":
			await _shove(climber, target)
		"guard":
			_guarding[climber] = true
			climber.act("interact-left")
			await _beat()
	busy = false
	if active and _awaiting == "":
		await _foes_turn()
	return true


func _count(action: String) -> void:
	if not _acted_this_fight:
		_acted_this_fight = true
		Baseline.habit("openers", action)
	Baseline.habit("actions", action)


# --- Talking mid-fight ----------------------------------------------------------------------

func _open_talk() -> void:
	_talk_options = []
	for t in fight.get("talk", []):
		if t.has("requires") and not Baseline.knows(String(t["requires"])):
			continue
		_talk_options.append(t)
	var labels: Array = []
	for t in _talk_options:
		labels.append(String(t.get("text", "...")))
	labels.append("Say nothing")
	_awaiting = "talk"
	ui.hide_combat()
	ui.show_page("You", "What do you say?", labels)


func _talk_chosen(index: int) -> void:
	_awaiting = ""
	ui.hide_page()
	if index >= _talk_options.size():
		_refresh_bar()
		return
	_count("talk")
	var t: Dictionary = _talk_options[index]
	Baseline.apply_once("fight/%s/talk/%d" % [fight_id, index], t.get("effects", {}))
	climber.act("emote-yes")
	if String(t.get("result", "")) == "yield":
		for foe in foes:
			foe.act("emote-no")
		_finish("talked_down", String(t.get("reply", "")))
		return
	if t.has("reply"):
		foes[0].bark(String(t["reply"]))
	busy = true
	await _beat()
	busy = false
	await _foes_turn()


## Routes a dialogue choice while a fight owns the dialogue panel. Returns true if handled.
func handle_choice(index: int) -> bool:
	match _awaiting:
		"talk":
			_talk_chosen(index)
			return true
		"yield":
			_yield_chosen(index)
			return true
	return false


# --- Opponents' turns -----------------------------------------------------------------------

func _foes_turn() -> void:
	if not active:
		return
	turn = "foes"
	ui.hide_combat()
	for foe in foes.duplicate():
		if not active:
			return
		await _foe_act(foe)
	if active:
		_begin_climber_turn()


func _foe_act(foe) -> void:
	_guarding.erase(foe)
	if _staggered.get(foe, false):
		_staggered.erase(foe)
		foe.bark("...")
		await _beat()
		return
	if level.chebyshev(foe.cell, climber.cell) > 1:
		var best: Array = []
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var spot: Vector2i = climber.cell + Vector2i(dx, dy)
				if spot == climber.cell or _foe_at(spot):
					continue
				var p: Array = level.find_path_for(foe, spot, [climber.cell])
				if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
					best = p
		if best.size() > 1:
			await _walk_foe(foe, best.slice(1, mini(best.size(), MOVES_PER_TURN + 1)))
	if level.chebyshev(foe.cell, climber.cell) <= 1:
		foe.face(climber.global_position)
		await _strike(foe, climber)
	else:
		await _beat()


func _walk_foe(foe, cells: Array) -> void:
	if foe.character:
		foe.character.set_moving(true)
	for c in cells:
		if _foe_at(c) or c == climber.cell:
			break
		level.move_object(foe, c)
		var to: Vector3 = level.cell_to_world(c)
		foe.face(to)
		if pace > 0.0:
			var tw: Tween = foe.create_tween()
			tw.tween_property(foe, "position", to, 0.28)
			await tw.finished
		else:
			foe.position = to
	if foe.character:
		foe.character.set_moving(false)


# --- Resolving actions ----------------------------------------------------------------------

func _strike(attacker, target) -> void:
	_face_each_other(attacker, target)
	_who(attacker).act("attack-melee-right")
	await _beat()
	if _guarding.get(target, false):
		_guarding.erase(target)
		_bark(target, "Blocked!")
		await _beat()
		return
	_hurt(target)
	await _beat()


func _shove(attacker, target) -> void:
	_face_each_other(attacker, target)
	_who(attacker).act("attack-kick-right")
	await _beat()
	var a: Vector2i = _cell_of(attacker)
	var t: Vector2i = _cell_of(target)
	var dir := Vector2i(signi(t.x - a.x), signi(t.y - a.y))
	var to := t + dir
	var free: bool = level.is_walkable(to) and _foe_at(to) == null and to != climber.cell
	if target == climber:
		free = level.is_walkable(to) and _foe_at(to) == null
	if free:
		if target == climber:
			climber.place(to)
		else:
			level.move_object(target, to)
			target.position = level.cell_to_world(to)
		_bark(target, "Shoved back")
	else:
		_staggered[target] = true
		_bark(target, "Staggered")
	await _beat()


func _hurt(target) -> void:
	if target == climber:
		Baseline.wounds = maxi(0, Baseline.wounds - 1)
		Baseline.changed.emit()
		_bark(climber, "-1 wound")
		_show_wounds()
		if Baseline.wounds <= 0:
			_finish("lost", "")
		return
	wounds[target] = int(wounds[target]) - 1
	_bark(target, "-1 wound")
	_show_wounds()
	if int(wounds[target]) <= 0:
		if target.character:
			target.character.hold("die")
		_finish("killed", "")
	elif int(wounds[target]) <= int(fight.get("yield_at", 0)) and not _awaiting == "yield":
		_offer_yield(target)


func _offer_yield(target) -> void:
	_awaiting = "yield"
	target.act("emote-no")
	ui.hide_combat()
	ui.show_page(target.display_name, String(fight.get("yield_text", "\"Enough! I yield.\"")), ["Let them go", "Finish it"])


func _yield_chosen(index: int) -> void:
	_awaiting = ""
	ui.hide_page()
	if index == 0:
		_finish("spared", "")
	else:
		_count("strike")
		var target = foes[0]
		climber.act("attack-melee-right")
		if target.character:
			target.character.hold("die")
		_finish("killed", "")


# --- Ending ---------------------------------------------------------------------------------

func _finish(outcome: String, line: String) -> void:
	if not active:
		return
	active = false
	busy = false
	turn = ""
	ui.hide_combat()
	for foe in foes:
		foe.set_status("")
	Baseline.habit(outcome)
	Baseline.record("fight_" + outcome, fight_id)
	var out: Dictionary = fight.get("outcomes", {}).get(outcome, {})
	Baseline.apply(out.get("effects", {}))
	if outcome == "lost":
		Baseline.wounds = 1
		climber.character.hold("die")
	var text := String(out.get("text", line))
	if text != "":
		main.show_note(text)
	if outcome != "lost":
		for foe in foes:
			if outcome == "killed":
				foe.kind = "examine"
				foe.display_name = String(out.get("body_name", foe.display_name))
				foe.def = {"lines": out.get("body_lines", ["They don't move."])}
			else:
				level.remove_object(foe)
	foes.clear()
	main.ui.set_wounds(Baseline.wounds, Baseline.max_wounds, false)
	ended.emit(outcome)


# --- Helpers --------------------------------------------------------------------------------

func _adjacent_foe():
	var best = null
	for foe in foes:
		if level.chebyshev(foe.cell, climber.cell) <= 1:
			best = foe
	return best


func _foe_at(cell: Vector2i):
	for foe in foes:
		if foe.cell == cell:
			return foe
	return null


func _cell_of(who) -> Vector2i:
	return climber.cell if who == climber else who.cell


func _who(who):
	return climber if who == climber else who


func _face_each_other(a, b) -> void:
	var pa: Vector3 = a.global_position
	var pb: Vector3 = b.global_position
	if a == climber:
		climber.face(pb)
	else:
		a.face(pb)
	if b == climber:
		climber.face(pa)
	else:
		b.face(pa)


func _bark(who, text: String) -> void:
	if who == climber:
		main.climber_bark(text)
	else:
		who.bark(text)


func _show_wounds() -> void:
	for foe in foes:
		var w := int(wounds.get(foe, 0))
		foe.set_status("● ".repeat(w).strip_edges())
	ui.set_wounds(Baseline.wounds, Baseline.max_wounds, active)


func _refresh_bar() -> void:
	if not active or _awaiting != "":
		return
	var near = _adjacent_foe()
	var opts: Array = []
	for a in ACTIONS:
		opts.append({"id": a, "label": LABELS[a], "enabled": not ((a == "strike" or a == "shove") and near == null)})
	ui.show_combat(opts, "Your turn · moves left: %d" % moves_left)


func _beat() -> void:
	if pace > 0.0:
		await get_tree().create_timer(pace).timeout
	else:
		await get_tree().process_frame
