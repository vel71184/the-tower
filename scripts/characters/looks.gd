extends RefCounted
## Turns a partial look into a complete one using the floor's palette.
##
## Each floor dresses its people in its own colours, like a faction ("floor palettes as
## factions" in the design doc). Anything a character's look doesn't say is picked from the
## floor's palette, seeded by the character's id, so the same person always looks the same.
## The climber's reserved colours never appear on anyone else.

const CharacterModel := preload("res://scripts/characters/character_model.gd")
const COLOR_SLOTS := ["skin", "hair", "shirt", "pants", "shoes", "accent"]


static func reserved_colors() -> Array:
	return CharacterModel.parts().get("reserved", {}).get("climber_colors", [])


static func climber_look() -> Dictionary:
	return (CharacterModel.parts().get("climber", {}) as Dictionary).duplicate(true)


## look: what the level says about this person (may be empty).
## people: the floor palette, e.g. {"shirt": ["slate", "sand"], "pants": [...], "bodies": [...]}.
## seed_key: stable id for this person, so picks never change between runs.
static func resolve(look: Dictionary, people: Dictionary, seed_key: String, is_climber: bool = false) -> Dictionary:
	var p := CharacterModel.parts()
	var out := look.duplicate(true)
	var cols: Dictionary = (out.get("colors", {}) as Dictionary).duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)

	if not out.has("body"):
		out["body"] = _pick(rng, people.get("bodies", (p.get("bodies", {}) as Dictionary).keys()))
	if not out.has("head"):
		out["head"] = _pick(rng, people.get("heads", (p.get("heads", {}) as Dictionary).keys()))
	for slot in COLOR_SLOTS:
		if cols.has(slot):
			continue
		var options: Array = people.get(slot, [])
		if slot == "skin" and options.is_empty():
			options = p.get("skin_tones", [])
		if not options.is_empty():
			cols[slot] = _pick(rng, options)

	if not is_climber:
		var reserved := reserved_colors()
		for slot in cols.keys():
			if reserved.has(cols[slot]):
				var safe: Array = (people.get(slot, ["slate"]) as Array).filter(func(c): return not reserved.has(c))
				push_warning("'%s' wears the climber's reserved colour %s; using %s instead" % [seed_key, cols[slot], safe[0] if not safe.is_empty() else "slate"])
				cols[slot] = safe[0] if not safe.is_empty() else "slate"
	out["colors"] = cols
	return out


static func _pick(rng: RandomNumberGenerator, options: Array) -> Variant:
	return options[rng.randi_range(0, options.size() - 1)]
