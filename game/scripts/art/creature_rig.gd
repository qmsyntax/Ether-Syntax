class_name CreatureRig
extends ModelRig
## A procedural rig for beasts with four (or six, or two) legs - the unstarred monsters of the
## Stubble (design/07 5.4, Brent 2026-10-19). STAND-IN: there is no creature rig source yet (a
## rigged, animated four-legged body needs one, and that needs Brent's yes), so these are built
## from MeshKit shapes like the invaders and animated here by hand: a gait, a lunge, a flinch,
## a wind-up pose of each kind's own and a stagger. Same contract as ModelRig: set_highlight,
## flash, set_windup, set_staggered, set_dead_look, animate(delta, speed, attacking).
##
## Parts it drives: "body" (the trunk; legs, neck and tail hang from it), "neck", "head",
## "jaw", "tail", "wing_left" / "wing_right", and the legs listed in `legs`.

## The legs: {"upper": part, "lower": part, "phase": radians, "knee": +1 front-style / -1 hock}.
var legs: Array = []
## Peak swing of an upper leg (radians) at full stride, and how far the lower leg folds as it lifts.
var leg_swing: float = 0.55
var knee_fold: float = 0.7
## How far the head nods with each step, and how far it drops toward the ground while grazing.
var head_nod: float = 0.06
var graze_drop: float = 0.0
## Radians the tail swings side to side.
var tail_sway: float = 0.25
## Wing flap amplitude (birds), while moving or striking.
var wing_flap: float = 0.0
## Metres the body recoils on a hit (the flinch), decaying over about a fifth of a second.
var flinch_recoil: float = 0.07
## When true the wind-up and strike use the alternative poses (a second attack: the kick).
var use_alt: bool = false
var alt_windup_pose: Dictionary[String, Vector3] = {}
var alt_strike_pose: Dictionary[String, Vector3] = {}
## While true the head goes down to the ground now and then (a grazer that has not been angered).
var grazing: bool = false

## Extra tuning carried by stamp() besides ModelRig.SNAPSHOT_PROPS.
const CREATURE_PROPS: Array[String] = ["legs", "leg_swing", "knee_fold", "head_nod", "graze_drop", "tail_sway",
	"wing_flap", "flinch_recoil", "alt_windup_pose", "alt_strike_pose"]

var _flinch: float = 0.0
var _graze_t: float = 0.0


## White hit flash, and the body jerks back from the blow.
func flash(seconds: float = 0.12) -> void:
	super.flash(seconds)
	_flinch = 1.0


## Everything stamp() needs to make copies without rebuilding: ModelRig's snapshot plus the legs.
func creature_snapshot() -> Dictionary:
	var snap: Dictionary = snapshot()
	var extra: Dictionary = {}
	for prop: String in CREATURE_PROPS:
		var value: Variant = get(prop)
		extra[prop] = (value as Dictionary).duplicate() if value is Dictionary else ((value as Array).duplicate(true) if value is Array else value)
	snap["creature"] = extra
	return snap


## A new, independent creature from a creature_snapshot() (the mirror of ModelRig.from_snapshot).
static func stamp(snap: Dictionary) -> CreatureRig:
	var rig := CreatureRig.new()
	rig.name = str(snap["name"])
	var config: Dictionary = snap["config"]
	for prop: String in config:
		var value: Variant = config[prop]
		rig.set(prop, (value as Dictionary).duplicate() if value is Dictionary else value)
	var extra: Dictionary = snap.get("creature", {})
	for prop: String in extra:
		var v: Variant = extra[prop]
		rig.set(prop, (v as Dictionary).duplicate() if v is Dictionary else ((v as Array).duplicate(true) if v is Array else v))
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


## The beast's whole procedural animation. `speed` is its ground speed in m/s.
func animate(delta: float, speed: float, attacking: bool) -> void:
	if _dead:
		return
	_time += delta
	var want_move: float = clampf(speed / maxf(stride_speed, 0.01), 0.0, 1.0)
	_move = lerpf(_move, want_move, minf(1.0, delta * 10.0))
	_phase += delta * speed * stride_rate
	_raise = move_toward(_raise, 1.0 if (_windup and not attacking) else 0.0, delta * 7.0)
	_strike = move_toward(_strike, 1.0 if attacking else 0.0, delta * (16.0 if attacking else 5.0))
	_flinch = move_toward(_flinch, 0.0, delta * 5.0)
	_stag = move_toward(_stag, 1.0 if _staggered else 0.0, delta * 7.0)
	var breathe: float = sin(_time * 2.0)

	# the legs: each swings on its own phase; the lower leg folds while the foot is coming forward
	for leg: Dictionary in legs:
		var ph: float = _phase + float(leg["phase"])
		var s: float = sin(ph)
		_pose(str(leg["upper"]), Vector3(s * leg_swing * _move, 0.0, 0.0))
		var lift: float = maxf(0.0, cos(ph)) * knee_fold * _move
		_pose(str(leg["lower"]), Vector3(-lift * float(leg.get("knee", 1.0)), 0.0, 0.0))

	# grazing: every few seconds of standing about, the head goes down to the ground for a while
	var graze: float = 0.0
	if grazing and _move < 0.15 and not _windup:
		_graze_t += delta
		var cycle: float = fmod(_graze_t, 7.0)
		graze = smoothstep(0.0, 0.8, cycle - 2.0) * (1.0 - smoothstep(0.0, 0.8, cycle - 5.2))
	else:
		_graze_t = 0.0

	# the trunk: breathing, a bob on each step, a dart forward on the strike, a jerk back when hit
	var step_lift: float = absf(sin(_phase)) * step_bob * _move
	if _parts.has("body"):
		var body: Node3D = _parts["body"]
		body.position = _rest_pos["body"] + Vector3(0.0, breathe * bob + step_lift - 0.04 * _strike,
			(0.25 * _raise - _strike) * strike_lunge + flinch_recoil * _flinch)
		body.rotation = _rest_rot["body"] + Vector3(-lean * _move * 0.3 + 0.12 * _flinch, 0.0, 0.06 * _flinch * sin(_time * 40.0))
	_pose("neck", Vector3(-0.2 * _strike + graze * graze_drop * 0.6, 0.0, 0.0))
	_pose("head", Vector3(sin(_phase * 2.0) * head_nod * _move - breathe * 0.02 + graze * graze_drop * 0.4 - 0.15 * _flinch, 0.0, 0.0))
	_pose("jaw", Vector3(0.45 * maxf(_raise, _strike), 0.0, 0.0))
	_pose("tail", Vector3(0.1 * _move, sin(_time * 3.0 + _phase) * tail_sway * (0.4 + 0.6 * _move), 0.0))
	var flap: float = wing_flap * (sin(_time * 22.0) * maxf(_move, _strike) + 0.6 * _raise)
	_pose("wing_left", Vector3(0.0, 0.0, flap))
	_pose("wing_right", Vector3(0.0, 0.0, -flap))

	# sway parts (manes, rags) as on the invaders
	var i: int = 0
	for part: String in sway_parts:
		_pose(part, Vector3(sway_parts[part] * (_move + 0.12 * sin(_time * 2.6 + float(i) * 1.7)), 0.0, 0.03 * sin(_time * 1.9 + float(i))))
		i += 1

	# the kind's own wind-up and strike poses, layered on top
	var wpose: Dictionary[String, Vector3] = alt_windup_pose if use_alt else windup_pose
	var spose: Dictionary[String, Vector3] = alt_strike_pose if use_alt else strike_pose
	if _raise > 0.0:
		for part: String in wpose:
			var posed: Node3D = _parts.get(part, null) as Node3D
			if posed != null:
				posed.rotation += wpose[part] * _raise
	if _strike > 0.0:
		for part: String in spose:
			var struck: Node3D = _parts.get(part, null) as Node3D
			if struck != null:
				struck.rotation += spose[part] * _strike
	if _parts.has("body") and (_raise > 0.0 or _stag > 0.0):
		var trunk: Node3D = _parts["body"]
		trunk.position.y -= windup_drop * _raise + stagger_drop * _stag
		trunk.rotation += (stagger_tilt + Vector3(0.0, 0.0, 0.06 * sin(_time * 6.0))) * _stag
		var skull: Node3D = _parts.get("head", null) as Node3D
		if skull != null:
			skull.rotation.x += 0.35 * _stag
	var hurry: float = 1.0 + 2.0 * maxf(_raise, _strike)
	for part: String in spin_parts:
		var node: Node3D = _parts.get(part, null) as Node3D
		if node != null:
			node.rotation += spin_parts[part] * (delta * hurry)
