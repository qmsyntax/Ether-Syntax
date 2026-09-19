extends Label3D
## Rising, fading combat text.

const LIFETIME := 0.9

var life := LIFETIME


static func spawn(parent: Node, pos: Vector3, txt: String, color: Color) -> void:
	var script: GDScript = load("res://scripts/float_text.gd")
	var f: Label3D = script.new()
	f.text = txt
	f.modulate = color
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	f.font_size = 56
	f.outline_size = 14
	f.pixel_size = 0.01
	parent.add_child(f)
	f.global_position = pos + Vector3(randf_range(-0.4, 0.4), 2.2, randf_range(-0.4, 0.4))


func _process(delta: float) -> void:
	life -= delta
	position.y += delta * 1.5
	modulate.a = clampf(life / LIFETIME, 0.0, 1.0)
	if life <= 0.0:
		queue_free()
