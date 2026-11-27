extends RefCounted
## Quick words that pop off someone and drift up: hits, staggers, "!" when a witness turns.

static func spawn(on: Node3D, text: String, height: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 40
	l.outline_size = 6
	l.outline_modulate = Color(0.12, 0.08, 0.06, 0.9)
	l.pixel_size = 0.006
	l.modulate = Color(1.0, 0.82, 0.5)
	l.position = Vector3(0, height, 0)
	on.add_child(l)
	var t := l.create_tween()
	t.tween_property(l, "position:y", height + 0.5, 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.8)
	t.tween_callback(l.queue_free)
