extends Node
## The hidden, running record of who the climber is becoming (design doc: "The baseline").
##
## It is never shown to the player as numbers ("No popups"): the world reacting is the only
## feedback. It also remembers what the climber learned and did, so floor 100 can hand it back.

signal changed

const SAVE_PATH := "user://climb.json"
const SAVE_VERSION := 1

## Axis id -> [low pole, high pole]. The design doc's four draft axes. These are not good vs evil.
const AXES := {
	"force_persuasion": ["force", "persuasion"],
	"honesty_deception": ["honesty", "deception"],
	"speed_patience": ["speed", "patience"],
	"others_self": ["others", "self"],
}

## Axes the first prototype actually exercises (design doc: "a two-axis baseline").
const PROTOTYPE_AXES := ["speed_patience", "others_self"]

## Small actions are nudges; boss resolutions are shoves.
const NUDGE := 1.0
const SHOVE := 5.0

var axes: Dictionary = {}
var flags: Dictionary = {}
var knowledge: Dictionary = {}
var history: Array = []
var floor_num := 1
var level_num := 1
## Where to pick up inside a level after the app was closed mid-level:
## {"floor": int, "level": int, "cell": [x, y]}. Empty between levels.
var resume: Dictionary = {}
## The climber's wounds. A hit takes one; at zero they fall. Wounds last until rest.
## Starts at 3; armor and other gear can raise the maximum later.
var max_wounds := 3
var wounds := 3
## How the climber fights, for floor 100: {"openers": {action: n}, "actions": {action: n},
## "fights": n, "spared": n, "killed": n, "talked_down": n, "fled": n, "lost": n}
var habits: Dictionary = {}


func _ready() -> void:
	reset()


func reset() -> void:
	axes.clear()
	for id in AXES:
		axes[id] = 0.0
	flags.clear()
	knowledge.clear()
	history.clear()
	floor_num = 1
	level_num = 1
	resume = {}
	max_wounds = 3
	wounds = 3
	habits = {}
	changed.emit()


## Moves the climber toward a pole by name, e.g. nudge("patience") or nudge("self", 2.0).
func nudge(pole: String, amount: float = NUDGE) -> void:
	for id in AXES:
		var poles: Array = AXES[id]
		if poles[0] == pole:
			axes[id] = float(axes[id]) - amount
			changed.emit()
			return
		if poles[1] == pole:
			axes[id] = float(axes[id]) + amount
			changed.emit()
			return
	push_warning("Baseline: unknown pole '%s'" % pole)


func value(axis: String) -> float:
	return float(axes.get(axis, 0.0))


## The pole the climber leans toward on an axis, or "" while roughly balanced.
func lean(axis: String, threshold: float = 1.0) -> String:
	if not AXES.has(axis):
		return ""
	var v := value(axis)
	if absf(v) < threshold:
		return ""
	var poles: Array = AXES[axis]
	return String(poles[1]) if v > 0.0 else String(poles[0])


func set_flag(flag: String, on: bool = true) -> void:
	if on:
		flags[flag] = true
	else:
		flags.erase(flag)
	changed.emit()


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func learn(fact: String) -> void:
	if knowledge.has(fact):
		return
	knowledge[fact] = {"floor": floor_num, "level": level_num}
	record("learned", fact)
	changed.emit()


func knows(fact: String) -> bool:
	return knowledge.has(fact)


## Appends to the climb's history, which the final boss will draw on.
func record(kind: String, id: String) -> void:
	history.append({"floor": floor_num, "level": level_num, "kind": kind, "id": id})


## Applies an effects block from level content:
## {"nudge": {"others": 1}, "set_flags": [...], "clear_flags": [...], "learn": [...]}
func apply(effects: Dictionary) -> void:
	var nudges: Dictionary = effects.get("nudge", {})
	for pole in nudges:
		nudge(String(pole), float(nudges[pole]))
	for f in effects.get("set_flags", []):
		set_flag(String(f))
	for f in effects.get("clear_flags", []):
		set_flag(String(f), false)
	for fact in effects.get("learn", []):
		learn(String(fact))
	if effects.get("heal", false):
		rest()


## Applies effects only the first time a given key is seen, so repeating a choice can't farm it.
func apply_once(key: String, effects: Dictionary) -> void:
	if effects.is_empty():
		return
	var k := "once:" + key
	if has_flag(k):
		return
	set_flag(k)
	apply(effects)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Writes a new copy beside the old one, then swaps it in, so a phone closing the app halfway
## through a save never leaves a broken file behind.
func save() -> bool:
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Baseline: could not write save (%s)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))
	if err == OK:
		return true
	# Couldn't swap it in: write it in place rather than not saving at all.
	push_warning("Baseline: could not swap in the save (%s); writing it directly" % error_string(err))
	f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	return true


func load_save() -> bool:
	if not has_save():
		return false
	var json := JSON.new()
	var parsed: Variant = json.data if json.parse(FileAccess.get_file_as_string(SAVE_PATH)) == OK else null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Baseline: save file is unreadable")
		return false
	from_dict(parsed)
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"floor": floor_num,
		"level": level_num,
		"axes": axes.duplicate(),
		"flags": flags.duplicate(),
		"knowledge": knowledge.duplicate(true),
		"history": history.duplicate(true),
		"resume": resume.duplicate(true),
		"wounds": wounds,
		"max_wounds": max_wounds,
		"habits": habits.duplicate(true),
	}


func from_dict(d: Dictionary) -> void:
	reset()
	var saved_axes: Dictionary = d.get("axes", {})
	for id in saved_axes:
		if axes.has(id):
			axes[id] = float(saved_axes[id])
	flags = (d.get("flags", {}) as Dictionary).duplicate()
	knowledge = (d.get("knowledge", {}) as Dictionary).duplicate(true)
	history = (d.get("history", []) as Array).duplicate(true)
	floor_num = int(d.get("floor", 1))
	level_num = int(d.get("level", 1))
	resume = (d.get("resume", {}) as Dictionary).duplicate(true)
	max_wounds = int(d.get("max_wounds", 3))
	wounds = clampi(int(d.get("wounds", max_wounds)), 0, max_wounds)
	habits = (d.get("habits", {}) as Dictionary).duplicate(true)
	changed.emit()


## Counts a fighting habit: habit("actions", "strike"), habit("openers", "shove"),
## or a plain counter: habit("spared").
func habit(group: String, key: String = "") -> void:
	if key == "":
		habits[group] = int(habits.get(group, 0)) + 1
	else:
		var g: Dictionary = habits.get(group, {})
		g[key] = int(g.get(key, 0)) + 1
		habits[group] = g
	changed.emit()


## The climber's most used entry in a habit group, e.g. their usual opener.
func favorite(group: String) -> String:
	var g: Dictionary = habits.get(group, {})
	var best := ""
	for k in g:
		if best == "" or int(g[k]) > int(g[best]):
			best = k
	return best


func rest() -> void:
	wounds = max_wounds
	changed.emit()


## Developer overlay text. Players never see this.
func debug_text() -> String:
	var lines: Array[String] = ["BASELINE (dev only)  F%d L%d" % [floor_num, level_num]]
	for id in AXES:
		var poles: Array = AXES[id]
		var mark := "*" if PROTOTYPE_AXES.has(id) else " "
		lines.append("%s %-9s %+5.1f %s" % [mark, poles[0], value(id), poles[1]])
	lines.append("wounds %d/%d  habits %s" % [wounds, max_wounds, JSON.stringify(habits)])
	lines.append("knows: " + ", ".join(PackedStringArray(knowledge.keys())))
	var shown: Array[String] = []
	for f in flags:
		if not String(f).begins_with("once:"):
			shown.append(String(f))
	lines.append("flags: " + ", ".join(PackedStringArray(shown)))
	return "\n".join(PackedStringArray(lines))
