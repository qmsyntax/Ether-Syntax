class_name FigureView
extends SubViewportContainer
## A character model on a small turntable inside a UI screen: its own 3D world, three lights
## and a long lens, the same set-up as the creation screen's preview. Drag to turn it. The
## inventory uses it for the figure in the middle of the paper doll.

var _viewport: SubViewport
var _pivot: Node3D
var _rig: ModelRig
var _spin := PI - 0.4                   # three-quarter on, facing the camera
var _dragging := false


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.46, 0.52, 0.66)
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	# a warm key from the upper left, a dim cool fill, a cold rim to lift the silhouette
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-34.0, 38.0, 0.0)
	key.light_color = Color(1.0, 0.88, 0.74)
	key.light_energy = 1.55
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-12.0, -48.0, 0.0)
	fill.light_color = Color(0.6, 0.7, 0.9)
	fill.light_energy = 0.38
	_viewport.add_child(fill)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-24.0, -158.0, 0.0)
	rim.light_color = Color(0.6, 0.76, 1.0)
	rim.light_energy = 1.1
	_viewport.add_child(rim)

	var cam := Camera3D.new()
	cam.fov = 20.0
	cam.near = 0.2
	cam.position = Vector3(0.0, 1.1, 7.3)
	_viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.96, 0.0), Vector3.UP)

	var plinth := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.44
	disc.bottom_radius = 0.48
	disc.height = 0.06
	disc.radial_segments = 48
	plinth.mesh = disc
	plinth.position.y = -0.03
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.035, 0.033, 0.032)
	mat.roughness = 0.85
	plinth.material_override = mat
	_viewport.add_child(plinth)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)


## Stand a model wearing `look` on the turntable, replacing any that was there.
func show_look(look: Dictionary) -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = CharacterLook.build(look)
	_pivot.add_child(_rig)


## The model on the turntable (null before show_look), so the owner can dress it.
func rig() -> ModelRig:
	return _rig


func _process(delta: float) -> void:
	_pivot.rotation.y = _spin
	if _rig != null:
		_rig.animate(delta, 0.0, false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _dragging:
		_spin += (event as InputEventMouseMotion).relative.x * 0.012
