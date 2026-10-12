class_name ModelRig
extends Node3D
## A procedural low-poly model: named pivots ("parts") holding flat-shaded meshes baked from
## Godot primitives, plus the small look/animation API gameplay code drives.
##
## Builders (see Models) call add_part() / add_shape() and then finish(). Gameplay calls
## set_highlight(), flash(), set_windup(), set_part_visible(), set_dead_look() and animate().
## Models face -Z at rotation 0. There are no physics nodes in here.
##
## Each part is baked into ONE mesh (vertex-coloured matte surface + one surface per glow
## colour), so a whole character costs roughly a dozen draw calls. Materials are owned by
## this rig and never shared between rigs.

## Emission colour used for hover / target highlight.
const HIGHLIGHT_GLOW := Color(1.0, 0.8, 0.42)
## Colour the model is pulled toward while an attack is being telegraphed.
const WINDUP_GLOW := Color(1.0, 0.5, 0.08)

## Top of the model above its origin, in metres (health-bar placement, picking).
var height: float = 1.8
## Horizontal half-extent of the body, in metres (picking).
var radius: float = 0.4

## Movement speed (m/s) at which the limbs swing at full amplitude.
var stride_speed: float = 3.0
## Radians of walk-cycle phase per metre travelled.
var stride_rate: float = 3.4
## Peak thigh/arm swing in radians.
var swing: float = 0.7
## Idle breathing bob in metres.
var bob: float = 0.025
## Extra bob per step, in metres.
var step_bob: float = 0.05
## Forward lean (radians) at full speed.
var lean: float = 0.14
## True when both arms take part in the wind-up / strike pose.
var strike_both_arms: bool = false
## Upper-arm / forearm pitch (radians) while winding up and while striking.
var raise_arm: float = 2.5
var raise_forearm: float = 0.8
var strike_arm: float = 1.35
var strike_forearm: float = 0.1
## Parts that trail and flutter (cloaks, banners): part name -> radians of pitch at full speed.
var sway_parts: Dictionary[String, float] = {}

var _parts: Dictionary[String, Node3D] = {}
var _rest_rot: Dictionary[String, Vector3] = {}
var _rest_pos: Dictionary[String, Vector3] = {}
var _shapes: Dictionary[String, Array] = {}
var _meshes: Dictionary[String, MeshInstance3D] = {}
var _matte: StandardMaterial3D
var _glow_mats: Dictionary[String, StandardMaterial3D] = {}
var _glow_color: Dictionary[String, Color] = {}
var _glow_energy: Dictionary[String, float] = {}

var _highlight: int = 0
var _windup: bool = false
var _dead: bool = false
var _flash_left: float = 0.0

var _time: float = 0.0
var _phase: float = 0.0
var _move: float = 0.0
var _raise: float = 0.0
var _strike: float = 0.0


func _init() -> void:
	_matte = StandardMaterial3D.new()
	_matte.vertex_color_use_as_albedo = true
	_matte.vertex_color_is_srgb = true
	_matte.roughness = 1.0
	_matte.metallic_specular = 0.15
	_matte.emission_enabled = true
	_matte.emission = Color.BLACK
	_time = randf() * 10.0
	set_process(false)


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_flash_left = 0.0
			set_process(false)
			_refresh()


# ---------------------------------------------------------------- building

## Creates a named pivot. `parent` is another part's name, or "" for the model root.
## The pivot's position is where the part rotates from (a shoulder, a hip...).
func add_part(part: String, parent: String = "", pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = part
	node.position = pos
	node.rotation = rot
	var parent_node: Node3D = _parts.get(parent, self) as Node3D
	parent_node.add_child(node)
	_parts[part] = node
	_shapes[part] = []
	return node


## Adds a primitive to a part, in the part's local space. `glow` > 0 makes it an emissive
## accent of that energy. Nothing is visible until finish() is called.
func add_shape(part: String, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scale_by: Vector3 = Vector3.ONE, glow: float = 0.0) -> void:
	if not _parts.has(part):
		add_part(part)
	var r := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var xform := Transform3D(Basis.from_euler(r) * Basis.from_scale(scale_by), pos)
	_shapes[part].append({"mesh": mesh, "xform": xform, "color": color, "glow": glow})


## Bakes every part's shapes into meshes and records the rest pose. Call once after building.
func finish() -> void:
	for part: String in _parts:
		_bake(part)
		var node: Node3D = _parts[part]
		_rest_rot[part] = node.rotation
		_rest_pos[part] = node.position
	_refresh()


## Returns the pivot node of a part, or null. Useful for attaching effects to a hand or head.
func get_part(part: String) -> Node3D:
	return _parts.get(part, null) as Node3D


## True if the model has a part of that name.
func has_part(part: String) -> bool:
	return _parts.has(part)


# ---------------------------------------------------------------- look

## 0 none, 1 hovered (bright warm glow), 2 targeted (dimmer glow).
func set_highlight(level: int) -> void:
	if level == _highlight:
		return
	_highlight = level
	_refresh()


## White hit flash for `seconds`, then back to the current look.
func flash(seconds: float = 0.12) -> void:
	_flash_left = maxf(seconds, 0.01)
	set_process(true)
	_refresh()


## Attack telegraph: the whole model burns amber while on, and animate() raises the weapon arm.
func set_windup(on: bool) -> void:
	if on == _windup:
		return
	_windup = on
	_refresh()


## Shows or hides a part and everything attached to it. If a "<part>_stump" part exists it is
## shown while the part is hidden (the player has "arm_right" / "arm_right_stump").
func set_part_visible(part: String, on: bool) -> void:
	var node: Node3D = _parts.get(part, null) as Node3D
	if node != null:
		node.visible = on
	var stump: Node3D = _parts.get(part + "_stump", null) as Node3D
	if stump != null:
		stump.visible = not on


## Greys the model out permanently (corpse look) and switches its glow accents off.
func set_dead_look() -> void:
	if _dead:
		return
	_dead = true
	_windup = false
	for part: String in _parts:
		_bake(part)
	_refresh()


# ---------------------------------------------------------------- animation

## Drives the whole procedural animation. Call every frame with the model's horizontal speed
## in m/s and whether it is striking right now. Idle breathing, limb swing proportional to
## speed, a raised-weapon pose while set_windup(true), and a strike pose while `attacking`.
func animate(delta: float, speed: float, attacking: bool) -> void:
	if _dead:
		return
	_time += delta
	var want_move: float = clampf(speed / maxf(stride_speed, 0.01), 0.0, 1.0)
	_move = lerpf(_move, want_move, minf(1.0, delta * 10.0))
	_phase += delta * speed * stride_rate
	_raise = move_toward(_raise, 1.0 if (_windup and not attacking) else 0.0, delta * 7.0)
	_strike = move_toward(_strike, 1.0 if attacking else 0.0, delta * (16.0 if attacking else 5.0))

	var s: float = sin(_phase)
	var walk: float = s * swing * _move
	var breathe: float = sin(_time * 2.2)

	# Legs: thighs swing opposite each other, the trailing knee bends.
	_pose("leg_left", Vector3(walk, 0.0, 0.0))
	_pose("leg_right", Vector3(-walk, 0.0, 0.0))
	_pose("shin_left", Vector3(-maxf(0.0, -s) * swing * 1.1 * _move, 0.0, 0.0))
	_pose("shin_right", Vector3(-maxf(0.0, s) * swing * 1.1 * _move, 0.0, 0.0))

	# Body: breathing, step bounce, lean into the run, twist into the blow.
	var twist: float = 0.0 if strike_both_arms else (0.5 * _strike - 0.35 * _raise)
	var pitch: float = -lean * _move - 0.28 * _strike + 0.14 * _raise
	if _parts.has("body"):
		var body: Node3D = _parts["body"]
		body.position = _rest_pos["body"] + Vector3(0.0, breathe * bob + absf(s) * step_bob * _move - 0.06 * _strike, 0.0)
		body.rotation = _rest_rot["body"] + Vector3(pitch * 0.5, twist * 0.4, 0.0)
	_pose("torso", Vector3(pitch * 0.5 + breathe * 0.012, twist * 0.6 + walk * 0.12, 0.0))
	_pose("head", Vector3(-pitch * 0.5 - breathe * 0.02, -twist * 0.7 - walk * 0.1, 0.0))

	# Arms: counter-swing to the legs, then blend into wind-up and strike.
	var act: float = maxf(_raise, _strike)
	var arm_r: float = lerpf(lerpf(-walk * 0.8, raise_arm, _raise), strike_arm, _strike)
	var fore_r: float = lerpf(lerpf(0.25 * _move, raise_forearm, _raise), strike_forearm, _strike)
	_pose("arm_right", Vector3(arm_r, 0.0, 0.0), 1.0 - act)
	_pose("forearm_right", Vector3(fore_r, 0.0, 0.0), 1.0 - act)
	if strike_both_arms:
		_pose("arm_left", Vector3(lerpf(lerpf(walk * 0.8, raise_arm, _raise), strike_arm, _strike), 0.0, 0.0), 1.0 - act)
		_pose("forearm_left", Vector3(fore_r, 0.0, 0.0), 1.0 - act)
	else:
		_pose("arm_left", Vector3(walk * 0.8 - 0.5 * _strike, 0.0, 0.0))
		_pose("forearm_left", Vector3(0.25 * _move + 0.5 * _strike, 0.0, 0.0))

	# Cloth: trails with speed, flutters always.
	var i: int = 0
	for part: String in sway_parts:
		var amount: float = sway_parts[part]
		_pose(part, Vector3(amount * (_move + 0.12 * sin(_time * 2.6 + float(i) * 1.7) + 0.1 * _move * sin(_phase * 2.0)), 0.0, 0.03 * sin(_time * 1.9 + float(i))))
		i += 1


# ---------------------------------------------------------------- internals

## Sets a part's rotation to its rest rotation (scaled by `rest_weight` on the X axis only,
## so a bent-at-rest elbow can straighten for a strike) plus an offset.
func _pose(part: String, offset: Vector3, rest_weight: float = 1.0) -> void:
	var node: Node3D = _parts.get(part, null) as Node3D
	if node == null:
		return
	var rest: Vector3 = _rest_rot.get(part, Vector3.ZERO)
	rest.x *= rest_weight
	node.rotation = rest + offset


func _glow_key(color: Color, glow: float) -> String:
	return "%s|%.2f" % [color.to_html(false), glow]


func _bake(part: String) -> void:
	var list: Array = _shapes.get(part, [])
	var old: MeshInstance3D = _meshes.get(part, null) as MeshInstance3D
	if list.is_empty():
		return
	var tools: Dictionary[String, SurfaceTool] = {}
	for shape: Dictionary in list:
		var color: Color = shape["color"]
		var glow: float = shape["glow"]
		var key: String = "matte"
		if glow > 0.0:
			key = _glow_key(color, glow)
			if not _glow_mats.has(key):
				var gm := StandardMaterial3D.new()
				gm.roughness = 1.0
				gm.emission_enabled = true
				_glow_mats[key] = gm
				_glow_color[key] = color
				_glow_energy[key] = glow
		if not tools.has(key):
			var fresh := SurfaceTool.new()
			fresh.begin(Mesh.PRIMITIVE_TRIANGLES)
			fresh.set_smooth_group(-1)
			tools[key] = fresh
		var st: SurfaceTool = tools[key]
		st.set_color(_grey(color) if _dead else color)
		var arrays: Array = (shape["mesh"] as Mesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var xform: Transform3D = shape["xform"]
		if arrays[Mesh.ARRAY_INDEX] != null:
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for index: int in indices:
				st.add_vertex(xform * verts[index])
		else:
			for v: Vector3 in verts:
				st.add_vertex(xform * v)
	var baked := ArrayMesh.new()
	for key: String in tools:
		var st: SurfaceTool = tools[key]
		st.generate_normals()
		st.commit(baked)
		var surface: int = baked.get_surface_count() - 1
		baked.surface_set_material(surface, _matte if key == "matte" else _glow_mats[key])
	if old == null:
		old = MeshInstance3D.new()
		old.name = "Mesh"
		(_parts[part] as Node3D).add_child(old)
		_meshes[part] = old
	old.mesh = baked


func _grey(color: Color) -> Color:
	var lum: float = color.get_luminance()
	var v: float = 0.16 + lum * 0.42
	return Color(v, v, v * 1.04)


func _refresh() -> void:
	var albedo := Color.WHITE
	var add := Color.BLACK
	if _highlight == 1:
		add += HIGHLIGHT_GLOW * 0.42
	elif _highlight == 2:
		add += HIGHLIGHT_GLOW * 0.17
	if _windup:
		albedo = Color(1.0, 0.74, 0.5)
		add += WINDUP_GLOW * 0.5
	var flashing: bool = _flash_left > 0.0
	if flashing:
		add = Color(1.0, 1.0, 1.0) * 1.4
	_matte.albedo_color = albedo
	_matte.emission = add
	for key: String in _glow_mats:
		var gm: StandardMaterial3D = _glow_mats[key]
		var base: Color = _glow_color[key]
		if _dead:
			gm.albedo_color = _grey(base)
			gm.emission = add
		else:
			gm.albedo_color = base * albedo
			gm.emission = base * _glow_energy[key] + add
