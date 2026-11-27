extends Node
## Plays a level's scripted scene (level JSON "cutscene": a list of steps), e.g. the climber
## walking The Road on their own at the start of a new climb.
##
## Steps (each may also carry "effects", applied when the step runs or is skipped past):
##   {"wait": seconds}
##   {"walk_to": "object id"}            walk until beside it
##   {"face": "object id"}
##   {"act": "animation"}                e.g. "interact-right", "pick-up"
##   {"say": "text", "time": seconds}    the climber speaks (floating text)
##   {"npc_say": "object id", "text": "...", "time": seconds}
##   {"reveal": "object id"}             a hidden thing appears
##   {"choice": "object id", "node": "dialogue node"}   hand the player that conversation
##   {"end": true}                       leave the level forward
## Skipping fast-forwards to the next "choice" the player hasn't made yet, then to the end.

signal finished

var main
var steps: Array = []
var playing := false
var skipping := false
## Speeds up waits and walking (tests).
var speed := 1.0


func setup(main_node) -> void:
	main = main_node


func play(list: Array) -> void:
	steps = list
	playing = true
	skipping = false
	main.ui.set_cinematic(true)
	for i in steps.size():
		if not playing:
			return
		var step: Dictionary = steps[i]
		Baseline.apply(step.get("effects", {}))
		await _run(step)
	if playing:
		_finish()


## Stops a scene without finishing it (a different level is starting).
func stop() -> void:
	if playing:
		playing = false
		skipping = false
		main.ui.set_cinematic(false)


func skip() -> void:
	if playing and not skipping:
		skipping = true


func _run(step: Dictionary) -> void:
	var level = main.level
	var climber = main.climber
	if step.has("wait"):
		await _wait(float(step["wait"]))
	elif step.has("walk_to"):
		var obj = main.find_object(String(step["walk_to"]))
		if obj == null:
			return
		var path: Array = level.path_to_object(climber.cell, obj)
		if path.is_empty():
			return
		if skipping:
			climber.place(path.back())
			main._on_entered_cell(climber.cell)
			return
		climber.walk(path)
		while climber.is_moving() and not skipping:
			await get_tree().process_frame
		if skipping:
			climber.place(path.back())
			main._on_entered_cell(climber.cell)
	elif step.has("face"):
		var obj = main.find_object(String(step["face"]))
		if obj:
			climber.face(obj.global_position)
	elif step.has("act"):
		if not skipping:
			climber.act(String(step["act"]))
	elif step.has("say"):
		if not skipping:
			climber.say(String(step["say"]), float(step.get("time", 2.5)) / speed)
			await _wait(float(step.get("time", 2.5)))
	elif step.has("npc_say"):
		var who = main.find_object(String(step["npc_say"]))
		if who and not skipping:
			who.face(climber.global_position)
			who.say(String(step.get("text", "")), float(step.get("time", 2.5)) / speed)
			await _wait(float(step.get("time", 2.5)))
	elif step.has("reveal"):
		var obj = main.find_object(String(step["reveal"]))
		if obj and not obj.revealed:
			obj.reveal()
			Baseline.set_flag("noticed:" + obj.id)
	elif step.has("choice"):
		var who = main.find_object(String(step["choice"]))
		if who == null:
			return
		var was_skipping := skipping
		if skipping:
			var path: Array = level.path_to_object(climber.cell, who)
			if not path.is_empty():
				climber.place(path.back())
			skipping = false
		climber.face(who.global_position)
		who.face(climber.global_position)
		main.ui.set_cinematic(false)
		main.talk_from(who, String(step.get("node", "")))
		while main.is_talking():
			await get_tree().process_frame
		main.ui.set_cinematic(true)
		skipping = was_skipping
	elif step.has("end"):
		_finish()
		main.end_level()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds / speed and not skipping:
		await get_tree().process_frame
		t += get_process_delta_time()


func _finish() -> void:
	if not playing:
		return
	playing = false
	skipping = false
	main.ui.set_cinematic(false)
	if main.level:
		Baseline.set_flag("cutscene_seen:" + String(main.level.data.get("id", "")))
		# A scene the player watched doesn't count toward how they handled the level.
		Baseline.set_flag("completed:" + String(main.level.data.get("id", "")))
	finished.emit()
