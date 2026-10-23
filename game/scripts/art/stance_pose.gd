class_name StancePose
extends RefCounted
## A standing clip made from a body's own skeleton (Brent 2026-10-23: "have it just stand with feet
## forward, apart, square on character creation"): the rest pose plus the bone turns listed in
## data/wardrobe.json "stances", with a breathing cycle on top. No download, no re-export: the
## turns are data, so the stance is tuned by editing the JSON and looking again
## (tests/character_preview.tscn ... anim=stand).
##
## Turns are in the BODY's frame, worked out from the skeleton (left, up, forward), so they read the
## same on any rig: [a, b, c] degrees about the left axis (+ tips a bone standing up forward, a
## bone hanging down backward), the up axis (+ turns a left-side bone's tip outward... toes out)
## and the forward axis (+ swings a left-side bone's tip up and out). A name without a side
## ("Arm") is used on both sides, mirrored, so + always means outward; "LeftArm" is that bone
## alone. Each turn is applied after the parent's, in the body's frame, so a forearm's bend is
## "more bend" whatever the upper arm did. An entry may be {"rot": [...], "twist": deg, "flat":
## true}: twist turns the bone about its own length (mirrored); flat keeps it at its rest
## orientation in the world (feet stay flat on the ground whatever the knees do). The hips drop
## by however much the legs' bend lifted the ankles, so the feet stay on the ground.

const PREFIXES: Array[String] = ["mixamorig_", "mixamorig:"]
const FINGERS: Array[String] = ["Index", "Middle", "Ring", "Pinky"]


## An Animation for `skeleton` (tracks addressed through `track_prefix`, e.g.
## "Character/Skeleton3D") from a stance definition, with `extra` turns added (per body, per build).
static func build(skeleton: Skeleton3D, track_prefix: String, cfg: Dictionary, extra: Array[Dictionary]) -> Animation:
	var pose: Dictionary = _merged(cfg.get("pose", {}), extra)
	var breath: Dictionary = cfg.get("breath", {})
	var length: float = float(cfg.get("length", 4.0))
	var keys: int = maxi(2, int(cfg.get("keys", 25)))
	var curl: Array = cfg.get("finger_curl", [0.0, 0.0, 0.0])
	var pinky_more: float = float(cfg.get("pinky_extra", 0.0))
	var close_by: Dictionary = cfg.get("finger_close", {})
	var frame: Basis = _body_frame(skeleton)
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR
	var n: int = skeleton.get_bone_count()
	var rot_track: PackedInt32Array = PackedInt32Array()
	rot_track.resize(n)
	for b: int in n:
		rot_track[b] = anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rot_track[b], NodePath("%s:%s" % [track_prefix, skeleton.get_bone_name(b)]))
		anim.track_set_interpolation_type(rot_track[b], Animation.INTERPOLATION_CUBIC)
	var root: int = _root(skeleton)
	var pos_track: int = anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(pos_track, NodePath("%s:%s" % [track_prefix, skeleton.get_bone_name(root)]))
	anim.track_set_interpolation_type(pos_track, Animation.INTERPOLATION_CUBIC)
	# how much the legs' bend lifts the ankles, from the pose without breath (breath leaves the legs)
	var still: Array[Transform3D] = _solve(skeleton, frame, pose, {}, 0.0, curl, pinky_more, close_by)
	var drop: float = 0.0
	var feet: int = 0
	for side: String in ["Left", "Right"]:
		var foot: int = _find(skeleton, side + "Foot")
		if foot >= 0:
			var rest_h: float = skeleton.get_bone_global_rest(foot).origin.dot(frame.y)
			drop += rest_h - still[foot].origin.dot(frame.y)
			feet += 1
	drop = drop / float(maxi(1, feet))
	for k: int in keys:
		var t: float = length * float(k) / float(keys - 1)
		var w: float = 0.5 - 0.5 * cos(TAU * float(k) / float(keys - 1))    # 0 -> 1 -> 0, seamless
		var g: Array[Transform3D] = _solve(skeleton, frame, pose, breath, w, curl, pinky_more, close_by)
		for b: int in n:
			var p: int = skeleton.get_bone_parent(b)
			var local: Transform3D = g[b] if p < 0 else g[p].affine_inverse() * g[b]
			anim.rotation_track_insert_key(rot_track[b], t, local.basis.get_rotation_quaternion())
		anim.position_track_insert_key(pos_track, t, g[root].origin + frame.y * drop)
	return anim


## Every bone's posed transform in skeleton space, parents first.
static func _solve(sk: Skeleton3D, frame: Basis, pose: Dictionary, breath: Dictionary, w: float, curl: Array, pinky_more: float, close_by: Dictionary) -> Array[Transform3D]:
	var n: int = sk.get_bone_count()
	var g: Array[Transform3D] = []
	g.resize(n)
	for b: int in _parents_first(sk):
		var p: int = sk.get_bone_parent(b)
		var base: Transform3D = sk.get_bone_rest(b) if p < 0 else g[p] * sk.get_bone_rest(b)
		var rest_g: Transform3D = sk.get_bone_global_rest(b)
		var name: String = _short(sk.get_bone_name(b))
		var side: String = "Left" if name.begins_with("Left") else ("Right" if name.begins_with("Right") else "")
		var bare: String = name.trim_prefix(side)
		var mirror: float = -1.0 if side == "Right" else 1.0
		var entry: Variant = pose.get(name, pose.get(bare, null))
		var rot := Vector3.ZERO
		var twist := 0.0
		var flat := false
		if entry is Array:
			rot = _vec(entry)
		elif entry is Dictionary:
			rot = _vec((entry as Dictionary).get("rot", [0, 0, 0]))
			twist = float((entry as Dictionary).get("twist", 0.0))
			flat = bool((entry as Dictionary).get("flat", false))
		var br: Variant = breath.get(name, breath.get(bare, null))
		if br is Array:
			rot += _vec(br) * w
		var start: Basis = rest_g.basis if flat else base.basis
		var delta := Basis.IDENTITY
		if twist != 0.0:
			delta = Basis(start.y.normalized(), deg_to_rad(twist * mirror))
		# body-frame turn, mirrored for the right side: the left axis keeps its sign, up and forward flip
		delta = Basis(frame.x, deg_to_rad(rot.x)) * delta
		delta = Basis(frame.y, deg_to_rad(rot.y * mirror)) * delta
		delta = Basis(frame.z, deg_to_rad(rot.z * mirror)) * delta
		# relaxed fingers: a curl about the line across the knuckles, toward the palm
		var digit: int = _finger_joint(bare)
		if digit > 0 and digit <= curl.size() and p >= 0:
			var hand: int = _find(sk, side + "Hand")
			var across: Vector3 = _knuckles(sk, side)
			if hand >= 0 and across != Vector3.ZERO:
				var axis: Vector3 = (g[hand].basis * (sk.get_bone_global_rest(hand).basis.inverse() * across)).normalized()
				var deg: float = float(curl[digit - 1]) + (pinky_more if bare.begins_with("HandPinky") else 0.0)
				delta = Basis(axis, deg_to_rad(deg * mirror)) * delta
		# fingers drawn together (a relaxed hand is not splayed): the first joints of the index, ring
		# and little finger and the thumb turn toward the middle finger (the thumb toward the index)
		var close: float = _closing(bare, close_by)
		if close > 0.0 and p >= 0:
			var toward: int = _find(sk, side + ("HandIndex1" if bare.begins_with("HandThumb") else "HandMiddle1"))
			var hand2: int = _find(sk, side + "Hand")
			if toward >= 0 and hand2 >= 0:
				var mine: Vector3 = rest_g.basis.y.normalized()
				var other: Vector3 = sk.get_bone_global_rest(toward).basis.y.normalized()
				var turn_axis: Vector3 = mine.cross(other)
				if turn_axis.length() > 0.001:
					var apart: float = rad_to_deg(mine.angle_to(other))
					var axis2: Vector3 = (g[hand2].basis * (sk.get_bone_global_rest(hand2).basis.inverse() * turn_axis.normalized())).normalized()
					delta = Basis(axis2, deg_to_rad(minf(close, apart))) * delta
		g[b] =Transform3D((delta * start).orthonormalized(), base.origin)
	return g


## The body's frame in skeleton space: x = the body's left, y = up, z = forward.
static func _body_frame(sk: Skeleton3D) -> Basis:
	var hips: int = _root(sk)
	var head: int = _find(sk, "Head")
	var l_leg: int = _find(sk, "LeftUpLeg")
	var r_leg: int = _find(sk, "RightUpLeg")
	var up: Vector3 = (sk.get_bone_global_rest(head).origin - sk.get_bone_global_rest(hips).origin).normalized()
	var left: Vector3 = sk.get_bone_global_rest(l_leg).origin - sk.get_bone_global_rest(r_leg).origin
	left = (left - up * left.dot(up)).normalized()
	return Basis(left, up, left.cross(up).normalized())


## The line across a hand's knuckles (index to little finger) in skeleton space, at rest.
static func _knuckles(sk: Skeleton3D, side: String) -> Vector3:
	var a: int = _find(sk, side + "HandIndex1")
	var b: int = _find(sk, side + "HandPinky1")
	if a < 0 or b < 0:
		return Vector3.ZERO
	return (sk.get_bone_global_rest(b).origin - sk.get_bone_global_rest(a).origin).normalized()


## How far a first finger joint (or the thumb's) turns toward its neighbour: wardrobe "finger_close"
## {"Index": deg, "Ring": deg, "Pinky": deg, "Thumb": deg}.
static func _closing(bare: String, close_by: Dictionary) -> float:
	for f: String in ["Index", "Ring", "Pinky", "Thumb"]:
		if bare == "Hand%s1" % f:
			return float(close_by.get(f, 0.0))
	return 0.0


## 1..3 for a finger's joints (Index1, Middle2, ...), 0 for anything else (thumbs, finger ends).
static func _finger_joint(bare: String) -> int:
	for f: String in FINGERS:
		if bare.begins_with("Hand" + f):
			var j: int = int(bare.trim_prefix("Hand" + f))
			return j if j >= 1 and j <= 3 else 0
	return 0


static func _merged(base: Dictionary, extra: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for add: Dictionary in extra:
		for key: Variant in add:
			if str(key).begins_with("_"):
				continue
			var v: Variant = add[key]
			var old: Variant = out.get(key, null)
			if v is Array and old is Array:
				out[key] = [float(old[0]) + float(v[0]), float(old[1]) + float(v[1]), float(old[2]) + float(v[2])]
			elif v is Array and old is Dictionary:
				var d: Dictionary = (old as Dictionary).duplicate()
				var r: Array = d.get("rot", [0, 0, 0])
				d["rot"] = [float(r[0]) + float(v[0]), float(r[1]) + float(v[1]), float(r[2]) + float(v[2])]
				out[key] = d
			else:
				out[key] = v
	return out


static func _vec(a: Variant) -> Vector3:
	var arr: Array = a
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func _short(bone: String) -> String:
	for p: String in PREFIXES:
		if bone.begins_with(p):
			return bone.substr(p.length())
	return bone


static func _find(sk: Skeleton3D, short: String) -> int:
	for p: String in PREFIXES:
		var i: int = sk.find_bone(p + short)
		if i >= 0:
			return i
	return sk.find_bone(short)


static func _root(sk: Skeleton3D) -> int:
	var hips: int = _find(sk, "Hips")
	return hips if hips >= 0 else sk.get_parentless_bones()[0]


static func _parents_first(sk: Skeleton3D) -> Array[int]:
	var out: Array[int] = []
	var todo: Array[int] = []
	for r: int in sk.get_parentless_bones():
		todo.append(r)
	while not todo.is_empty():
		var b: int = todo.pop_front()
		out.append(b)
		for c: int in sk.get_bone_children(b):
			todo.append(c)
	return out
