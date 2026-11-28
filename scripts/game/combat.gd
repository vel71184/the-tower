extends Node
## Real-time fights, Zelda-style (design doc: "Combat").
##
## The climber can attack anyone, any time: killing is always possible, and always remembered.
## To avoid accidents, a swing only connects with people already fighting the climber, or with
## the person they've locked on to. Locking on and swinging at someone peaceful is a deliberate
## first strike: it starts a fight, witnesses react, and the baseline records it.
##
## Climber actions:
##   strike - a swing in a short arc in front; a hit takes one wound and knocks them back
##   kick   - knocks them back and stuns them, without a wound (the non-lethal option)
##   block  - while held, blocks hits from the front
##   lock   - lock on to the person in front (again to release); cycle switches target
##   talk   - say something mid-fight; with the right knowledge it can end the fight
## Anyone down to their last wounds may yield: let them go, or finish it.
##
## A level can describe a fight with someone under "fights" (talk lines, yield text,
## outcomes); anyone else uses the defaults.

signal ended(outcome: String)

const Fx := preload("res://scripts/game/fx.gd")
## What the climber draws when a fight starts or they lock on.
const WEAPON := "sword"

const SWING_RANGE := 1.3
const SWING_ARC := 0.3          # cosine of the half-angle in front that a swing covers
const SWING_COOLDOWN := 0.45
const KICK_COOLDOWN := 0.8
const KNOCKBACK := 0.9
const STUN := 1.0
const FOE_SPEED := 2.2
const FOE_REACH := 1.15
const FOE_WINDUP := 0.45
const FOE_COOLDOWN := 1.2
const LOCK_RANGE := 4.5
const WITNESS_RANGE := 7.0
const DEFAULT_FIGHT := {"wounds": 3, "yield_at": 1}

var main
var level
var climber
var ui

## Everyone currently fighting the climber: Interactable -> state Dictionary.
var foes: Dictionary = {}
var lock_target = null
var blocking := false
## What happened, in order, e.g. ["strike_hit:brann", "kick_moved:brann", "strike_blocked:climber"].
var events: Array[String] = []
## Tests drive time themselves with tick(); the game leaves this false.
var manual := false

var _cooldown := 0.0
var _first_in_encounter := true
var _awaiting := ""
var _talk_foe = null
var _talk_options: Array = []
var _yield_foe = null


func setup(main_node) -> void:
	main = main_node
	climber = main.climber
	ui = main.ui


## Clears every fight (a new level is starting).
func reset(new_level) -> void:
	level = new_level
	foes.clear()
	lock_target = null
	if climber:
		climber.lock_face = null
		if climber.character:
			climber.character.put_away(WEAPON)
	if ui:
		ui.set_wounds(Baseline.wounds, Baseline.max_wounds, false)
	blocking = false
	events.clear()
	_cooldown = 0.0
	_awaiting = ""
	_talk_foe = null
	_yield_foe = null
	_first_in_encounter = true


## True while anyone is fighting the climber.
var active: bool:
	get:
		return not foes.is_empty()


func _process(delta: float) -> void:
	if not manual:
		tick(delta)


## Advances fights by dt seconds. Paused while a dialogue or card is open.
func tick(dt: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	_update_weapon()
	if foes.is_empty() or ui.is_busy() or main._ended:
		return
	for foe in foes.keys():
		if is_instance_valid(foe) and foes.has(foe):
			_foe_tick(foe, foes[foe], dt)


# --- Climber actions ------------------------------------------------------------------------

## A swing in front. Returns true if it hit someone.
func strike() -> bool:
	if not _can_act():
		return false
	_cooldown = SWING_COOLDOWN
	_count("strike")
	_aim()
	climber.character.act("attack-melee-right")
	Fx.slash(climber, climber.facing_dir, SWING_RANGE)
	var target = _target_in_arc()
	if target == null:
		events.append("strike_miss")
		return false
	_start_if_peaceful(target)
	events.append("strike_hit:" + target.id)
	Fx.flash(target)
	Fx.hitstop(get_tree())
	main.cam.shake(0.1)
	_knock(target, climber.facing_dir, false)
	_hurt(target)
	return true


## A kick: knocks back and stuns, never wounds. Returns true if it connected.
func kick() -> bool:
	if not _can_act():
		return false
	_cooldown = KICK_COOLDOWN
	_count("kick")
	_aim()
	climber.character.act("attack-kick-right")
	var target = _target_in_arc()
	if target == null:
		events.append("kick_miss")
		return false
	_start_if_peaceful(target)
	Fx.flash(target)
	main.cam.shake(0.06)
	if _knock(target, climber.facing_dir, true):
		events.append("kick_moved:" + target.id)
	else:
		events.append("kick_staggered:" + target.id)
	foes[target]["stun"] = STUN
	foes[target]["windup"] = 0.0
	target.pop("Staggered")
	return true


func set_blocking(on: bool) -> void:
	if on == blocking:
		return
	blocking = on
	if on:
		climber.character.hold("holding-left")
	else:
		climber.character.release()


## Locks on to the nearest person in front, or releases the lock.
func toggle_lock() -> void:
	if lock_target != null:
		_set_lock(null)
		return
	_set_lock(_people_in_front(LOCK_RANGE, -0.2).front() if not _people_in_front(LOCK_RANGE, -0.2).is_empty() else null)


## Moves the lock to the next nearest person.
func cycle_lock() -> void:
	var people := _people_in_front(LOCK_RANGE, -1.0)
	if people.is_empty():
		return
	var i := people.find(lock_target)
	_set_lock(people[(i + 1) % people.size()])


## Mid-fight talk with the nearest foe. Opens their lines; returns false if no one is near.
func talk() -> bool:
	if foes.is_empty() or ui.is_busy():
		return false
	var nearest = null
	for foe in foes:
		if nearest == null or _dist(foe) < _dist(nearest):
			nearest = foe
	if nearest == null or _dist(nearest) > 3.0:
		return false
	_count("talk")
	_talk_foe = nearest
	_talk_options = []
	for t in foes[nearest]["data"].get("talk", []):
		if t.has("requires") and not Baseline.knows(String(t["requires"])):
			continue
		_talk_options.append(t)
	var labels: Array = []
	for t in _talk_options:
		labels.append(String(t.get("text", "...")))
	labels.append("Say nothing")
	_awaiting = "talk"
	ui.show_page("You", "What do you say?", labels)
	return true


## Starts a fight from a conversation ("fight:<id>[:<opening action>]").
func start_from_dialogue(foe, opener: String) -> void:
	_make_hostile(foe, true)
	_set_lock(foe)
	climber.face(foe.global_position)
	if opener == "strike":
		_cooldown = 0.0
		strike()
	elif opener == "kick":
		_cooldown = 0.0
		kick()


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


func is_foe(obj) -> bool:
	return foes.has(obj)


# --- Foes -----------------------------------------------------------------------------------

func _foe_tick(foe, st: Dictionary, dt: float) -> void:
	st["cd"] = maxf(0.0, float(st["cd"]) - dt)
	if float(st["stun"]) > 0.0:
		st["stun"] = maxf(0.0, float(st["stun"]) - dt)
		return
	if st.get("yielded", false):
		return
	var d := _dist(foe)
	if float(st["windup"]) > 0.0:
		st["windup"] = float(st["windup"]) - dt
		if float(st["windup"]) <= 0.0:
			st["windup"] = 0.0
			st["cd"] = FOE_COOLDOWN
			_foe_hits(foe, d)
		return
	if d > FOE_REACH:
		# Someone who can't walk (a broken leg) only swings at whoever comes close.
		if not st["data"].get("stationary", false):
			_foe_walk(foe, st, dt)
	elif float(st["cd"]) <= 0.0:
		foe.face(climber.global_position)
		foe.act("attack-melee-right")
		st["windup"] = FOE_WINDUP
		# A red warning while they wind up, so the hit can be read and dodged or blocked.
		Fx.flash(foe, Color(1.0, 0.25, 0.15), FOE_WINDUP * 0.8)


func _foe_hits(foe, d: float) -> void:
	if d > FOE_REACH + 0.25:
		events.append("strike_miss:" + foe.id)
		return
	var from_foe: Vector3 = (climber.global_position - foe.global_position).normalized()
	if blocking and climber.facing_dir.dot(-from_foe) > 0.3:
		events.append("strike_blocked:climber")
		main.climber_bark("Blocked!")
		Fx.flash(climber, Color(0.7, 0.8, 1.0), 0.08)
		main.cam.shake(0.05)
		return
	events.append("strike_hit:climber")
	Fx.flash(climber, Color(1.0, 0.35, 0.3), 0.15)
	Fx.hitstop(get_tree(), 0.05)
	main.cam.shake(0.18)
	Baseline.wounds = maxi(0, Baseline.wounds - 1)
	Baseline.changed.emit()
	main.climber_bark("-1 wound")
	climber.knock_back(from_foe, KNOCKBACK * 0.6)
	ui.set_wounds(Baseline.wounds, Baseline.max_wounds, true)
	if Baseline.wounds <= 0:
		_lost()


## Walks a foe one smooth step toward the climber along the grid.
func _foe_walk(foe, st: Dictionary, dt: float) -> void:
	if foe.character:
		foe.character.set_moving(true)
	var next = st.get("next", null)
	if next == null or not level.is_walkable(next) and next != foe.cell:
		next = _next_cell_toward_climber(foe)
		st["next"] = next
	if next == null:
		# Already beside the climber's cell, but the climber can stand anywhere in it: close
		# the last bit directly, or both sides end up just out of reach forever.
		if _close_in(foe, dt):
			return
		if foe.character:
			foe.character.set_moving(false)
		return
	var target: Vector3 = level.cell_to_world(next)
	foe.face(target)
	foe.position = foe.position.move_toward(target, FOE_SPEED * dt)
	if foe.position.distance_to(target) < 0.02:
		if next != foe.cell:
			level.move_object(foe, next)
		st["next"] = null


## Steps a foe straight toward the climber until within reach. Returns true if they moved.
func _close_in(foe, dt: float) -> bool:
	var to: Vector3 = climber.global_position - foe.global_position
	to.y = 0.0
	if to.length() <= FOE_REACH * 0.9:
		return false
	var step: Vector3 = to.normalized() * minf(FOE_SPEED * dt, to.length() - FOE_REACH * 0.85)
	var goal: Vector3 = foe.position + step
	if not level.can_stand(goal, 0.25, foe.cell, foe):
		return false
	foe.face(climber.global_position)
	foe.position = goal
	var c: Vector2i = level.world_to_cell(goal)
	if c != foe.cell and level.is_walkable(c) and level.object_at(c) == null and c != climber.cell:
		level.move_object(foe, c)
	if foe.character:
		foe.character.set_moving(true)
	return true


func _next_cell_toward_climber(foe):
	# Cells other foes are already stepping into are taken, so two fighters never overlap.
	var taken: Array = [climber.cell]
	for other in foes:
		if other != foe and is_instance_valid(other):
			var their_next = foes[other].get("next", null)
			if their_next != null and their_next != foe.cell:
				taken.append(their_next)
	var best: Array = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var spot: Vector2i = climber.cell + Vector2i(dx, dy)
			if spot in taken or (level.object_at(spot) != null and level.object_at(spot) != foe):
				continue
			var p: Array = level.find_path_for(foe, spot, taken)
			if not p.is_empty() and (best.is_empty() or p.size() < best.size()):
				best = p
	return best[1] if best.size() > 1 else null


# --- Starting, hurting, ending --------------------------------------------------------------

func _make_hostile(foe, by_climber: bool) -> void:
	if foes.has(foe):
		return
	var data: Dictionary = DEFAULT_FIGHT.duplicate(true)
	data.merge(_fight_for(foe), true)
	if foes.is_empty():
		_first_in_encounter = true
		Baseline.habit("fights")
		ui.toast("Fight!", 1.2)
	foes[foe] = {"wounds": int(data.get("wounds", 3)), "cd": 0.8, "windup": 0.0, "stun": 0.0, "data": data}
	Baseline.record("fight", foe.id)
	_show_hearts(foe)
	ui.set_wounds(Baseline.wounds, Baseline.max_wounds, true)
	# A spar both sides agreed to ("consensual": true) isn't an attack, and nobody's alarmed.
	if data.get("consensual", false):
		return
	if by_climber and not Baseline.has_flag("attacked:" + foe.id):
		Baseline.set_flag("attacked:" + foe.id)
	# An attack nobody provoked (no scripted fight for it) frightens whoever sees it.
	var unprovoked: bool = by_climber and _fight_for(foe).is_empty()
	for other in level.objects:
		if other != foe and other.kind == "npc" and other.character and not foes.has(other) \
				and other.global_position.distance_to(foe.global_position) <= WITNESS_RANGE:
			other.pop("!")
			Baseline.record("witnessed", other.id + ":" + foe.id)
			if unprovoked:
				Baseline.set_flag("saw_attack:" + other.id)


## A swing at someone peaceful is the climber's own first strike.
func _start_if_peaceful(target) -> void:
	if foes.has(target):
		return
	Baseline.nudge("force", 1.0)
	Baseline.record("first_strike", target.id)
	_make_hostile(target, true)


func _hurt(foe) -> void:
	var st: Dictionary = foes[foe]
	st["wounds"] = int(st["wounds"]) - 1
	st["windup"] = 0.0
	foe.pop("-1 wound")
	_show_hearts(foe)
	if int(st["wounds"]) <= 0:
		_end_foe(foe, "killed")
	elif int(st["wounds"]) <= int(st["data"].get("yield_at", 1)) and not st.get("yield_offered", false):
		st["yield_offered"] = true
		st["yielded"] = true
		_yield_foe = foe
		_awaiting = "yield"
		foe.act("emote-no")
		ui.show_page(foe.display_name, String(st["data"].get("yield_text", "\"Enough! I yield.\"")), ["Let them go", "Finish it"])


func _yield_chosen(index: int) -> void:
	_awaiting = ""
	ui.hide_page()
	var foe = _yield_foe
	_yield_foe = null
	if foe == null or not foes.has(foe):
		return
	if index == 0:
		_end_foe(foe, "spared")
	else:
		_count("strike")
		climber.character.act("attack-melee-right")
		_end_foe(foe, "killed")


func _talk_chosen(index: int) -> void:
	_awaiting = ""
	ui.hide_page()
	var foe = _talk_foe
	_talk_foe = null
	if foe == null or not foes.has(foe) or index >= _talk_options.size():
		return
	var t: Dictionary = _talk_options[index]
	Baseline.apply_once("fight/%s/talk/%d" % [foe.id, index], t.get("effects", {}))
	climber.character.act("emote-yes")
	if String(t.get("result", "")) == "yield":
		foe.act("emote-no")
		if t.has("reply"):
			foe.bark(String(t["reply"]))
		_end_foe(foe, "talked_down")
	elif t.has("reply"):
		foe.bark(String(t["reply"]))


## Ends one person's part in the fight: killed, spared, talked_down or lost.
func _end_foe(foe, outcome: String) -> void:
	var st: Dictionary = foes[foe]
	foes.erase(foe)
	if lock_target == foe:
		_set_lock(null)
	foe.set_status("")
	if foe.character:
		foe.character.set_moving(false)
	Baseline.habit(outcome)
	Baseline.record(outcome, foe.id)
	var out: Dictionary = st["data"].get("outcomes", {}).get(outcome, {})
	Baseline.apply(out.get("effects", {}))
	if foe.has_method("go_home") and outcome != "killed":
		foe.go_home(level)
	match outcome:
		"killed":
			Baseline.set_flag("killed:" + foe.id)
			lay_down(foe, out)
		"spared", "talked_down":
			Baseline.set_flag("spared:" + foe.id)
			# A sparring partner ("stays": true) is still there afterwards; anyone else leaves.
			if out.get("stays", false):
				if foe.character:
					foe.character.release()
			else:
				Baseline.set_flag("gone:" + foe.id)
				level.remove_object(foe)
	var text := String(out.get("text", ""))
	if text != "":
		main.show_note(text)
	if foes.is_empty():
		_end_encounter(outcome)


## Someone who has died: they lie where they fell and can be looked at, nothing more.
func lay_down(obj, out: Dictionary) -> void:
	if obj.character:
		obj.character.hold("die")
	obj.kind = "examine"
	obj.display_name = String(out.get("body_name", obj.display_name))
	obj.def = {"lines": out.get("body_lines", ["%s doesn't move." % obj.display_name])}
	obj.set_status("")


## The climber goes down. Nobody kills them for it (yet): they come to at the level's resting
## spot with one wound left, unless the fight says otherwise ("stay_put": a spar, where you're
## helped up where you fell). Whoever beat them goes back to what they were doing, or leaves.
func _lost() -> void:
	var notes: Array = []
	var stay_put := false
	Baseline.wounds = 1
	for foe in foes.keys():
		var st: Dictionary = foes[foe]
		foes.erase(foe)
		foe.set_status("")
		if foe.character:
			foe.character.set_moving(false)
		var out: Dictionary = st["data"].get("outcomes", {}).get("lost", {})
		Baseline.apply(out.get("effects", {}))
		stay_put = stay_put or bool(out.get("stay_put", false))
		if out.has("text"):
			notes.append(String(out["text"]))
		if out.get("leaves", true) and out.has("text"):
			Baseline.set_flag("gone:" + foe.id)
			level.remove_object(foe)
		elif foe.has_method("go_home"):
			foe.go_home(level)
	Baseline.habit("lost")
	Baseline.record("lost", "")
	_set_lock(null)
	set_blocking(false)
	# A "lost" outcome's text is what you find when you come to (who's gone, what's taken).
	if not stay_put:
		var place: String = main.wake_at_rest()
		notes.push_front("Everything goes dark. When you come to, you're %s, aching all over." % place)
	climber.character.hold("die")
	main.show_note("\n\n".join(PackedStringArray(notes)))
	_end_encounter("lost")


func _end_encounter(outcome: String) -> void:
	_awaiting = ""
	ui.set_wounds(Baseline.wounds, Baseline.max_wounds, false)
	ended.emit(outcome)


# --- Helpers --------------------------------------------------------------------------------

## The climber's sword is out while they're fighting or locked on, and away otherwise.
func _update_weapon() -> void:
	if climber == null or climber.character == null:
		return
	var want: bool = active or lock_target != null
	if want != climber.character.is_holding(WEAPON):
		if want:
			climber.character.draw_item(WEAPON)
		else:
			climber.character.put_away(WEAPON)


func _can_act() -> bool:
	return _cooldown <= 0.0 and not ui.is_busy() and not main._ended and level != null


func _count(action: String) -> void:
	if _first_in_encounter:
		_first_in_encounter = false
		Baseline.habit("openers", action)
	Baseline.habit("actions", action)


## Turns the climber toward whoever they mean to hit before a swing or kick: the person
## they're locked on to if close enough, otherwise the nearest foe roughly in front. Without
## this, a swing goes wherever the stick last pointed.
func _aim() -> void:
	var target = null
	if lock_target != null and is_instance_valid(lock_target) and _dist(lock_target) <= SWING_RANGE + 0.3:
		target = lock_target
	else:
		for p in _people_in_front(SWING_RANGE + 0.2, -0.3):
			if foes.has(p):
				target = p
				break
	if target:
		climber.face(target.global_position)


## Who a swing would connect with: in reach, in front, and either fighting the climber or the
## person they've locked on to. The closest wins.
func _target_in_arc():
	var best = null
	for p in _people_in_front(SWING_RANGE, SWING_ARC):
		if foes.has(p) or p == lock_target:
			if best == null or _dist(p) < _dist(best):
				best = p
	return best


## Living people within range whose direction from the climber is within the arc, nearest first.
func _people_in_front(reach: float, min_dot: float) -> Array:
	var out: Array = []
	for obj in level.objects:
		if obj.kind != "npc" or obj.character == null or not obj.revealed:
			continue
		var to: Vector3 = obj.global_position - climber.global_position
		to.y = 0.0
		if to.length() > reach:
			continue
		if to.length() > 0.2 and climber.facing_dir.dot(to.normalized()) < min_dot:
			continue
		out.append(obj)
	out.sort_custom(func(a, b): return _dist(a) < _dist(b))
	return out


## Pushes someone back a cell if there's room. Returns true if they moved.
func _knock(foe, dir: Vector3, hard: bool) -> bool:
	var step := Vector2i(int(round(dir.x)), int(round(dir.z)))
	if step == Vector2i.ZERO:
		return false
	var to: Vector2i = foe.cell + step
	if level.is_walkable(to) and to != climber.cell:
		level.move_object(foe, to)
		var tw: Tween = foe.create_tween()
		tw.tween_property(foe, "position", level.cell_to_world(to), 0.15)
		if foes.has(foe):
			foes[foe]["next"] = null
		return true
	if hard and foes.has(foe):
		foes[foe]["stun"] = STUN
	return false


func _set_lock(target) -> void:
	if lock_target != null and is_instance_valid(lock_target):
		lock_target.set_locked(false)
	lock_target = target
	climber.lock_face = target
	if target != null:
		target.set_locked(true)
		climber.face(target.global_position)


func _show_hearts(foe) -> void:
	if foes.has(foe):
		foe.set_status("● ".repeat(int(foes[foe]["wounds"])).strip_edges())


func _fight_for(foe) -> Dictionary:
	var fights: Dictionary = level.data.get("fights", {}) if level else {}
	for id in fights:
		if (fights[id].get("opponents", []) as Array).has(foe.id):
			return fights[id]
	return {}


func _dist(obj) -> float:
	var d: Vector3 = obj.global_position - climber.global_position
	d.y = 0.0
	return d.length()
