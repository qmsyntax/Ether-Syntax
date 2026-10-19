extends Label3D
## Rising, fading combat text, in the interface's serif with a dark outline. A number pops in a
## little large and settles; a word (OPENING, INTERRUPTED) is set smaller than a number, so the
## damage reads first.

const LIFETIME := 0.9
const POP_S := 0.12

var life := LIFETIME


static func spawn(parent: Node, pos: Vector3, txt: String, color: Color) -> void:
	var script: GDScript = load("res://scripts/float_text.gd")
	var f: Label3D = script.new()
	f.text = txt
	f.modulate = color
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	f.font = UiTheme.font(true)
	f.font_size = 60 if txt.is_valid_int() else 40
	f.outline_size = 16
	f.outline_modulate = Color(0.04, 0.02, 0.01, 0.9)
	f.pixel_size = 0.01
	f.render_priority = 10
	f.outline_render_priority = 9
	parent.add_child(f)
	f.global_position = pos + Vector3(randf_range(-0.4, 0.4), 2.2, randf_range(-0.4, 0.4))


func _process(delta: float) -> void:
	life -= delta
	position.y += delta * 1.5
	var age: float = LIFETIME - life
	var pop: float = 1.0 + 0.3 * clampf(1.0 - age / POP_S, 0.0, 1.0)
	scale = Vector3.ONE * pop
	var a: float = clampf(life / (LIFETIME * 0.5), 0.0, 1.0)      # hold, then fade over the second half
	modulate.a = a
	outline_modulate.a = 0.9 * a
	if life <= 0.0:
		queue_free()
