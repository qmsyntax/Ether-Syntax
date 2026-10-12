class_name ModelRig
extends Node3D
## A procedural model: named pivots ("parts") each holding ONE baked mesh, plus the small
## look/animation API gameplay code drives.
##
## Builders (see Models) call add_part() / add_shape() and then finish(). Gameplay calls
## set_highlight(), flash(), set_windup(), set_part_visible(), set_weapon(), set_dead_look()
## and animate(). Models face -Z at rotation 0. There are no physics nodes in here.
##
## Each part bakes to a single surface: colour (with a baked ground / under-side occlusion
## gradient) lives in the vertex colour, gloss and glow energy in UV, so matte cloth, metal
## and emissive accents share one draw call. One ShaderMaterial per rig carries the state
## (highlight, wind-up, flash, dead) as uniforms. snapshot() / from_snapshot() stamp out
## copies that share the baked meshes.

## Emission colour used for hover / target highlight.
const HIGHLIGHT_GLOW := Color(1.0, 0.8, 0.42)
## Colour the model is pulled toward while an attack is being telegraphed.
const WINDUP_GLOW := Color(1.0, 0.5, 0.08)

const SOLID_SHADER := "
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
uniform vec3 tint = vec3(1.0);
uniform vec3 add_glow = vec3(0.0);
uniform float dead = 0.0;
uniform float rim = 0.1;
uniform float wear = 1.0;
varying vec2 v_mat;
varying vec3 v_pos;
vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}
float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
void vertex() {
	v_mat = UV;
	v_pos = VERTEX;
}
void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	base = mix(base, vec3(0.02 + lum * 0.55, 0.02 + lum * 0.55, 0.025 + lum * 0.58), dead);
	float live = 1.0 - dead;
	float gloss = v_mat.x * live;
	float lit = step(0.01, v_mat.y);
	// Grime and wear: blotchy value variation plus fine grain, strongest on matte cloth.
	float grime = noise(v_pos * 7.0) * 0.55 + noise(v_pos * 23.0) * 0.3 + noise(v_pos * 71.0) * 0.15;
	float dirt = mix(1.0, mix(0.62, 1.12, grime), wear * (1.0 - lit));
	ALBEDO = base * tint * dirt;
	ROUGHNESS = clamp(mix(0.95, 0.42, gloss) + (0.5 - grime) * 0.3 * gloss, 0.05, 1.0);
	METALLIC = gloss * 0.55;
	SPECULAR = mix(0.2, 0.6, gloss);
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 3.0);
	ALBEDO *= 1.0 - 0.45 * edge;
	EMISSION = base * v_mat.y * live + add_glow + mix(base, vec3(0.75, 0.82, 0.9), 0.5) * edge * rim * live;
}
"

const GHOST_SHADER := "
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_back, diffuse_lambert, specular_disabled;
uniform vec3 tint = vec3(1.0);
uniform vec3 add_glow = vec3(0.0);
uniform float dead = 0.0;
uniform float rim = 1.0;
uniform float alpha = 0.6;
uniform float self_lit = 0.6;
uniform float pallor = 0.5;
varying vec2 v_mat;
vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}
void vertex() {
	v_mat = UV;
}
void fragment() {
	vec3 base = to_linear(COLOR.rgb);
	float lum = dot(base, vec3(0.2126, 0.7152, 0.0722));
	// Eerie rather than candy: bleed most of the hue out toward a cold grey, except the
	// white-hot accents (high glow), which keep their colour.
	base = mix(base, vec3(0.8, 0.95, 1.05) * lum, pallor * (1.0 - clamp(v_mat.y - 1.0, 0.0, 1.0)));
	base = mix(base, vec3(lum * 0.5), dead);
	float live = 1.0 - dead;
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float edge = pow(1.0 - facing, 2.0);
	ALBEDO = base * tint * 0.4;
	EMISSION = (base * tint * (self_lit + v_mat.y) + mix(base, vec3(1.0), 0.55) * edge * rim) * mix(1.0, 0.15, dead) + add_glow;
	ALPHA = clamp(alpha + edge * (1.0 - alpha) * 0.85 + v_mat.y * 0.3, 0.0, 1.0) * mix(1.0, 0.55, dead);
}
"

static var _solid_shader: Shader
static var _ghost_shader: Shader
## Tuning values carried over by snapshot() / from_snapshot().
const SNAPSHOT_PROPS: Array[String] = [
	"height", "radius", "stride_speed", "stride_rate", "swing", "bob", "step_bob", "lean",
	"strike_both_arms", "raise_arm", "raise_forearm", "strike_arm", "strike_forearm",
	"strike_lunge", "sway_parts", "spin_parts", "ao_strength",
]

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
## Metres the "body" part darts forward (-Z) at the peak of a strike (limbless models).
var strike_lunge: float = 0.0
## Parts that trail and flutter (cloaks, banners): part name -> radians of pitch at full speed.
var sway_parts: Dictionary[String, float] = {}
## Parts that turn continuously: part name -> radians per second around each local axis.
var spin_parts: Dictionary[String, Vector3] = {}
## Strength (0..1) of the baked darkening toward the ground and on downward-facing surfaces.
var ao_strength: float = 1.0

var _parts: Dictionary[String, Node3D] = {}
var _rest_rot: Dictionary[String, Vector3] = {}
var _rest_pos: Dictionary[String, Vector3] = {}
var _shapes: Dictionary[String, Array] = {}
var _meshes: Dictionary[String, MeshInstance3D] = {}
var _mat: ShaderMaterial
var _ghost: bool = false
var _ghost_params := Vector3(0.6, 1.0, 0.6)
var _weapon: Node3D

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
	if _solid_shader == null:
		_solid_shader = Shader.new()
		_solid_shader.code = SOLID_SHADER
		_ghost_shader = Shader.new()
		_ghost_shader.code = GHOST_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _solid_shader
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


## Adds a mesh to a part, in the part's local space. `glow` > 0 makes it an emissive accent
## of that energy; `gloss` 0..1 goes from matte cloth to polished metal; `flat` gives it
## faceted normals instead of the mesh's own. Nothing is visible until finish() is called.
func add_shape(part: String, mesh: Mesh, color: Color, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scale_by: Vector3 = Vector3.ONE, glow: float = 0.0, gloss: float = 0.0, flat: bool = false) -> void:
	if not _parts.has(part):
		add_part(part)
	var r := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	var xform := Transform3D(Basis.from_euler(r) * Basis.from_scale(scale_by), pos)
	_shapes[part].append({"mesh": mesh, "xform": xform, "color": color, "glow": glow, "gloss": gloss, "flat": flat})


## Bakes every part's shapes into meshes and records the rest pose. Call once after building.
func finish() -> void:
	for part: String in _parts:
		var node: Node3D = _parts[part]
		_rest_rot[part] = node.rotation
		_rest_pos[part] = node.position
		if not (_shapes[part] as Array).is_empty():
			_attach_mesh(part, _bake(part))
	_shapes.clear()
	_refresh()


## Everything needed to stamp out copies of this finished rig without rebuilding or
## re-baking it: the part tree, the shared baked meshes and the tuning values. Pass the
## result to ModelRig.from_snapshot(). Holds no nodes, so it is safe to keep in a static.
func snapshot() -> Dictionary:
	var parts: Array[Dictionary] = []
	for part: String in _parts:
		var node: Node3D = _parts[part]
		var parent: Node3D = node.get_parent() as Node3D
		parts.append({
			"name": part,
			"parent": "" if parent == self else String(parent.name),
			"pos": _rest_pos[part],
			"rot": _rest_rot[part],
			"scale": node.scale,
			"visible": node.visible,
			"mesh": _meshes[part].mesh if _meshes.has(part) else null,
		})
	var config: Dictionary = {}
	for prop: String in SNAPSHOT_PROPS:
		var value: Variant = get(prop)
		config[prop] = (value as Dictionary).duplicate() if value is Dictionary else value
	return {"parts": parts, "config": config, "ghost": _ghost, "ghost_params": _ghost_params, "name": String(name)}


## Builds a new, independent rig (own material, own pose) from a snapshot().
static func from_snapshot(snap: Dictionary) -> ModelRig:
	var rig := ModelRig.new()
	rig.name = str(snap["name"])
	var config: Dictionary = snap["config"]
	for prop: String in config:
		var value: Variant = config[prop]
		rig.set(prop, (value as Dictionary).duplicate() if value is Dictionary else value)
	if bool(snap["ghost"]):
		var gp: Vector3 = snap["ghost_params"]
		rig.set_ghost(gp.x, gp.y, gp.z)
	for entry: Dictionary in snap["parts"]:
		var part: String = entry["name"]
		var node: Node3D = rig.add_part(part, str(entry["parent"]), entry["pos"] as Vector3, entry["rot"] as Vector3)
		node.scale = entry["scale"]
		node.visible = entry["visible"]
		rig._rest_pos[part] = node.position
		rig._rest_rot[part] = node.rotation
		if entry["mesh"] != null:
			rig._attach_mesh(part, entry["mesh"] as ArrayMesh)
	rig._shapes.clear()
	rig._refresh()
	return rig


func _attach_mesh(part: String, mesh: ArrayMesh) -> void:
	var inst := MeshInstance3D.new()
	inst.name = "Mesh"
	inst.mesh = mesh
	inst.material_override = _mat
	if _ghost:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(_parts[part] as Node3D).add_child(inst)
	_meshes[part] = inst


## Returns the pivot node of a part, or null. Useful for attaching effects to a hand or head.
func get_part(part: String) -> Node3D:
	return _parts.get(part, null) as Node3D


## True if the model has a part of that name.
func has_part(part: String) -> bool:
	return _parts.has(part)


## Switches the rig to the translucent spirit look (Netherecho models): self-lit, bright at
## the silhouette, no shadow. `alpha` is the see-through level facing the camera, `rim` the
## edge brightness, `self_lit` how much of the base colour is emitted regardless of light.
## Call before finish().
func set_ghost(alpha: float = 0.6, rim: float = 1.0, self_lit: float = 0.6) -> void:
	_ghost = true
	_ghost_params = Vector3(alpha, rim, self_lit)
	_mat.shader = _ghost_shader
	_mat.set_shader_parameter("alpha", alpha)
	_mat.set_shader_parameter("rim", rim)
	_mat.set_shader_parameter("self_lit", self_lit)
	for part: String in _meshes:
		_meshes[part].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Number of triangles in the model (and its weapon), for budget checks.
func triangle_count() -> int:
	var total: int = 0
	for part: String in _meshes:
		var mesh: Mesh = _meshes[part].mesh
		total += mesh.surface_get_array_len(0) / 3
	if _weapon is ModelRig:
		total += (_weapon as ModelRig).triangle_count()
	return total


## Number of mesh surfaces drawn for the model in its current state (hidden parts excluded).
func draw_call_count() -> int:
	var total: int = 0
	for part: String in _meshes:
		if _meshes[part].is_visible_in_tree() or (not is_inside_tree() and _parts[part].visible):
			total += 1
	if _weapon is ModelRig:
		total += (_weapon as ModelRig).draw_call_count()
	return total


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


## Puts `weapon` (see Models.weapon) in the right hand, replacing and freeing any previous
## one; null just removes it. The weapon rides the "hand_right" part, so it follows the arm's
## animation and vanishes with set_part_visible("arm_right", false). A ModelRig weapon takes
## on this rig's highlight / flash / wind-up / dead look.
func set_weapon(weapon: Node3D) -> void:
	if weapon == _weapon:
		return
	if _weapon != null and is_instance_valid(_weapon):
		if _weapon.get_parent() != null:
			_weapon.get_parent().remove_child(_weapon)
		_weapon.queue_free()
	_weapon = weapon
	if weapon == null:
		return
	var hand: Node3D = self
	for candidate: String in ["hand_right", "forearm_right", "arm_right"]:
		if _parts.has(candidate):
			hand = _parts[candidate]
			break
	if weapon.get_parent() != null:
		weapon.get_parent().remove_child(weapon)
	weapon.transform = Transform3D.IDENTITY
	hand.add_child(weapon)
	if weapon is ModelRig:
		(weapon as ModelRig)._adopt_material(_mat)


## The node currently held through set_weapon(), or null.
func get_weapon() -> Node3D:
	return _weapon if _weapon != null and is_instance_valid(_weapon) else null


## Greys the model out permanently (corpse look) and switches its glow accents off.
func set_dead_look() -> void:
	if _dead:
		return
	_dead = true
	_windup = false
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
		var lift: float = breathe * bob + absf(s) * step_bob * _move - 0.06 * _strike
		body.position = _rest_pos["body"] + Vector3(0.0, lift, (0.35 * _raise - _strike) * strike_lunge)
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

	# Orbiting pieces turn steadily, faster while telegraphing or striking.
	var hurry: float = 1.0 + 2.0 * act
	for part: String in spin_parts:
		var node: Node3D = _parts.get(part, null) as Node3D
		if node != null:
			node.rotation += spin_parts[part] * (delta * hurry)


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


func _adopt_material(material: ShaderMaterial) -> void:
	_mat = material
	for part: String in _meshes:
		_meshes[part].material_override = material


## Rest-pose transform from a part's local space to the rig's space.
func _rest_xform(part: String) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var node: Node3D = _parts[part]
	while node != null and node != self:
		xform = node.transform * xform
		node = node.get_parent() as Node3D
	return xform


func _bake(part: String) -> ArrayMesh:
	var to_model: Transform3D = _rest_xform(part)
	var model_basis: Basis = to_model.basis
	var ao_span: float = clampf(height * 0.4, 0.25, 0.9)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for shape: Dictionary in _shapes[part]:
		var color: Color = shape["color"]
		var glow: float = shape["glow"]
		var flat: bool = shape["flat"]
		var uv := Vector2(float(shape["gloss"]), glow)
		var shade: float = 0.0 if glow > 0.0 else ao_strength
		var arrays: Array = (shape["mesh"] as Mesh).surface_get_arrays(0)
		var src_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var src_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		if src_n.size() != src_v.size():
			flat = true
		var xform: Transform3D = shape["xform"]
		var normal_basis: Basis = xform.basis.inverse().transposed()
		var indexed: bool = arrays[Mesh.ARRAY_INDEX] != null
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if indexed else PackedInt32Array()
		var count: int = indices.size() if indexed else src_v.size()
		var k: int = 0
		while k + 2 < count:
			var i0: int = indices[k] if indexed else k
			var i1: int = indices[k + 1] if indexed else k + 1
			var i2: int = indices[k + 2] if indexed else k + 2
			var p0: Vector3 = xform * src_v[i0]
			var p1: Vector3 = xform * src_v[i1]
			var p2: Vector3 = xform * src_v[i2]
			var n0: Vector3
			var n1: Vector3
			var n2: Vector3
			if flat:
				n0 = (p2 - p0).cross(p1 - p0).normalized()
				n1 = n0
				n2 = n0
			else:
				n0 = (normal_basis * src_n[i0]).normalized()
				n1 = (normal_basis * src_n[i1]).normalized()
				n2 = (normal_basis * src_n[i2]).normalized()
			verts.append(p0)
			verts.append(p1)
			verts.append(p2)
			normals.append(n0)
			normals.append(n1)
			normals.append(n2)
			colors.append(_shaded(color, shade, (to_model * p0).y, (model_basis * n0).normalized().y, ao_span))
			colors.append(_shaded(color, shade, (to_model * p1).y, (model_basis * n1).normalized().y, ao_span))
			colors.append(_shaded(color, shade, (to_model * p2).y, (model_basis * n2).normalized().y, ao_span))
			uvs.append(uv)
			uvs.append(uv)
			uvs.append(uv)
			k += 3
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = verts
	arrays_out[Mesh.ARRAY_NORMAL] = normals
	arrays_out[Mesh.ARRAY_COLOR] = colors
	arrays_out[Mesh.ARRAY_TEX_UV] = uvs
	var baked := ArrayMesh.new()
	baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	return baked


## Bakes fake ambient occlusion into a colour: darker near the ground and on faces that
## point down, a touch brighter on faces that point up.
func _shaded(color: Color, shade: float, y: float, ny: float, ao_span: float) -> Color:
	if shade <= 0.0:
		return color
	var f: float = lerpf(0.5, 1.0, smoothstep(0.0, ao_span, y))
	f *= lerpf(0.6, 1.0, clampf((ny + 1.0) / 1.25, 0.0, 1.0))
	f *= 1.0 + 0.07 * maxf(ny, 0.0)
	f = lerpf(1.0, f, shade)
	return Color(color.r * f, color.g * f, color.b * f)


func _refresh() -> void:
	var tint := Color.WHITE
	var add := Color.BLACK
	if _highlight == 1:
		add += HIGHLIGHT_GLOW * 0.36
	elif _highlight == 2:
		add += HIGHLIGHT_GLOW * 0.13
	if _windup:
		tint = Color(1.0, 0.74, 0.5)
		add += WINDUP_GLOW * 0.38
	if _flash_left > 0.0:
		add = Color(1.0, 1.0, 1.0)
	tint = tint.srgb_to_linear()
	add = add.srgb_to_linear()
	_mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_mat.set_shader_parameter("add_glow", Vector3(add.r, add.g, add.b))
	_mat.set_shader_parameter("dead", 1.0 if _dead else 0.0)
