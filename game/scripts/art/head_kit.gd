class_name HeadKit
extends RefCounted
## A sculpted human head for the hero: a dense sphere grid pushed into a skull, jaw, brow
## ridge, eye sockets, nose, lips and chin by analytic "brushes", plus the things that sit on
## that surface - shells that follow the scalp or jaw (hair, stubble, beard) and points to
## hang brows, lids, locks and bands from. Everything is relative to the head's centre, face
## toward -Z; the head is about 0.24 tall.
##
## Tuning (all optional floats, 1.0 = the neutral male head): "jaw" width, "chin", "brow"
## ridge, "nose", "lips", "cheekbone", "hollow" (sunken cheeks), "socket" depth, and
## "soft" (0..1, rounds and narrows the lower face).

const RX := 0.076
const RY := 0.118
const RZ := 0.097
const RINGS := 60
const SIDES := 68

var tune: Dictionary = {}

var _pos := PackedVector3Array()
var _nrm := PackedVector3Array()
var _uw := PackedVector2Array()
var _az := PackedFloat32Array()
var _front := PackedFloat32Array()
var _lip := PackedFloat32Array()
var _socket := PackedFloat32Array()


func _init(tuning: Dictionary = {}) -> void:
	tune = tuning
	var row: int = SIDES + 1
	for i: int in RINGS + 1:
		var t: float = float(i) / float(RINGS)
		var phi: float = PI * (t + 0.42 * sin(TAU * t) / TAU)
		for j: int in row:
			var s: float = float(j) / float(SIDES) * 2.0 - 1.0
			var az: float = PI * (0.5 * s + 0.5 * s * s * s)
			var d := Vector3(sin(phi) * sin(az), cos(phi), -sin(phi) * cos(az))
			_pos.append(surface(d))
			_az.append(az)
			_uw.append(Vector2(_last_u, _last_w))
			_front.append(_last_f)
			_lip.append(_last_lip)
			_socket.append(_last_socket)
	_nrm = MeshKit._smooth_normals(_pos, _grid_indices())
	# Close the seam at the back of the head and the two poles.
	for i: int in RINGS + 1:
		var a: int = i * row
		var b: int = a + SIDES
		var n: Vector3 = (_nrm[a] + _nrm[b]).normalized()
		_nrm[a] = n
		_nrm[b] = n
	for j: int in row:
		_nrm[j] = Vector3.UP
		_nrm[RINGS * row + j] = (Vector3.DOWN + Vector3.FORWARD * 0.3).normalized()


var _last_u: float = 0.0
var _last_w: float = 0.0
var _last_f: float = 0.0
var _last_lip: float = 0.0
var _last_socket: float = 0.0


func _t(key: String, fallback: float = 1.0) -> float:
	return float(tune.get(key, fallback))


static func _g(u: float, w: float, u0: float, w0: float, su: float, sw: float) -> float:
	var a: float = (u - u0) / su
	var b: float = (w - w0) / sw
	return exp(-a * a - b * b)


## The head surface in the direction `d` (unit vector from the head's centre).
func surface(d: Vector3) -> Vector3:
	var front: float = clampf(-d.z, 0.0, 1.0)
	var back: float = clampf(d.z, 0.0, 1.0)
	var low: float = clampf(-d.y, 0.0, 1.0)
	var soft: float = _t("soft", 0.0)
	var px: float = d.x * RX
	var py: float = d.y * RY
	var pz: float = d.z * RZ
	pz *= 1.0 + 0.1 * back * (1.0 - low)
	pz *= 1.0 - 0.42 * back * smoothstep(0.25, 0.95, low)
	px *= 1.0 - 0.22 * back * smoothstep(0.4, 1.0, low)
	px *= 1.0 - (1.0 - 0.8 * _t("jaw")) * smoothstep(0.2, 0.9, low) * (1.0 - 0.5 * back)
	pz *= 1.0 - 0.08 * front
	pz -= 0.017 * smoothstep(0.5, 1.0, low) * (1.0 - back)
	py -= 0.007 * (_t("chin") - 0.4 * soft) * smoothstep(0.7, 1.0, low)
	var u: float = px / RX
	var w: float = py / RY
	var au: float = absf(u)
	var f: float = smoothstep(0.05, 0.45, front)
	var nose: float = _t("nose")
	var lips: float = _t("lips")
	var dz: float = 0.0
	dz -= 0.008 * _t("brow") * exp(-pow((w - 0.2) / 0.075, 2.0)) * smoothstep(0.98, 0.5, au)
	var socket: float = _g(au, w, 0.43, 0.085, 0.2, 0.085)
	dz += 0.0105 * _t("socket") * socket
	var tw: float = clampf((0.16 - w) / 0.36, 0.0, 1.0)
	var nose_fade: float = smoothstep(-0.31, -0.2, w) * smoothstep(0.32, 0.16, w)
	var nose_w: float = lerpf(0.085, 0.15, tw)
	dz -= lerpf(0.005, 0.026 * nose, pow(tw, 1.4)) * nose_fade * exp(-pow(u / nose_w, 2.0))
	dz -= 0.0055 * nose * _g(au, w, 0.14, -0.19, 0.07, 0.05)
	var cheek: float = _g(au, w, 0.6, -0.03, 0.2, 0.13)
	dz -= 0.005 * _t("cheekbone") * cheek
	px += signf(u) * 0.003 * _t("cheekbone") * cheek * f
	dz -= 0.005 * _g(u, w, 0.0, -0.42, 0.33, 0.14)
	var upper: float = _g(u, w, 0.0, -0.375, 0.2, 0.04)
	var lower: float = _g(u, w, 0.0, -0.465, 0.16, 0.045)
	dz -= 0.0022 * lips * upper + 0.0028 * lips * lower
	dz += 0.0035 * _g(u, w, 0.0, -0.42, 0.25, 0.016)
	dz += 0.003 * _g(u, w, 0.0, -0.56, 0.2, 0.05)
	dz -= 0.009 * (_t("chin") - 0.3 * soft) * _g(u, w, 0.0, -0.74, 0.24, 0.13)
	dz += 0.007 * _t("hollow", 0.0) * _g(au, w, 0.5, -0.36, 0.2, 0.2)
	px += signf(u) * 0.004 * (_t("jaw") - 0.6 * soft) * _g(au, w, 0.8, -0.5, 0.2, 0.18)
	pz += dz * f
	_last_u = u
	_last_w = w
	_last_f = f
	_last_lip = maxf(upper, lower) * f
	_last_socket = socket * f
	return Vector3(px, py, pz)


## A point on the head in direction `d`, pushed `lift` metres out along the surface normal.
func on(d: Vector3, lift: float = 0.0) -> Vector3:
	d = d.normalized()
	var p: Vector3 = surface(d)
	if lift == 0.0:
		return p
	var side: Vector3 = d.cross(Vector3.UP)
	if side.length() < 0.05:
		side = d.cross(Vector3.RIGHT)
	side = side.normalized()
	var up: Vector3 = side.cross(d).normalized()
	var n: Vector3 = (surface((d + up * 0.04).normalized()) - p).cross(surface((d + side * 0.04).normalized()) - p)
	if n.dot(d) < 0.0:
		n = -n
	return p + n.normalized() * lift


## The unit direction at azimuth `az` (0 = straight ahead, + toward the model's right,
## PI = the back) whose surface point sits at height `w` (-1 chin .. 1 crown).
func dir_at(az: float, w: float) -> Vector3:
	var y: float = clampf(w, -0.98, 0.98)
	var d := Vector3.UP
	for k: int in 3:
		var ring: float = sqrt(maxf(1.0 - y * y, 0.0001))
		d = Vector3(ring * sin(az), y, -ring * cos(az))
		y = clampf(y + (w - surface(d).y / RY), -0.98, 0.98)
	return d


## A point on the face at normalised face coordinates (u across -1..1, w up -1..1).
func face(u: float, w: float, lift: float = 0.0) -> Vector3:
	var az: float = asin(clampf(u / sqrt(maxf(1.0 - w * w, 0.05)), -0.98, 0.98))
	for k: int in 2:
		var p: Vector3 = surface(dir_at(az, w))
		az += (u - p.x / RX) * 0.9
	return on(dir_at(az, w), lift)


## Height (w) of the hairline at azimuth `az`. `sideburn` 0..1 adds the dip in front of the ear.
static func hairline(az: float, sideburn: float = 1.0) -> float:
	var a: float = absf(az)
	return 0.64 - 0.5 * smoothstep(0.5, 1.25, a) - 0.74 * smoothstep(1.7, 2.7, a) - 0.28 * sideburn * exp(-pow((a - 1.2) / 0.13, 2.0))


## The skin mesh. Vertex colours are multipliers for the skin tone (shaded sockets, flushed
## lips and cheeks), so add it with the skin colour.
func skin_mesh() -> ArrayMesh:
	var colors := PackedColorArray()
	for i: int in _pos.size():
		var u: float = _uw[i].x
		var w: float = _uw[i].y
		var f: float = _front[i]
		var c := Color(1, 1, 1)
		var lip: float = clampf(_lip[i] * 1.4, 0.0, 1.0) * 0.75
		c = c.lerp(Color(0.9, 0.66, 0.64), lip)
		c = c.lerp(Color(0.8, 0.74, 0.74), clampf(_socket[i], 0.0, 1.0) * 0.6)
		c = c.lerp(Color(1.04, 0.93, 0.91), _g(absf(u), w, 0.5, -0.16, 0.25, 0.15) * f * 0.6)
		c = c.lerp(Color(1.03, 0.92, 0.9), _g(u, w, 0.0, -0.16, 0.12, 0.08) * f * 0.5)
		colors.append(c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _pos
	arrays[Mesh.ARRAY_NORMAL] = _nrm
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = _grid_indices()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## A layer lying on the head: `mode` picks where ("hair", "sides", "top", "beard"),
## `thick` its depth in metres, `stripes` > 0 combs ridges into it (that many round the
## head, `stripe_depth` as a fraction). `sideburn` shapes the hairline (see hairline()).
func shell(mode: String, thick: float, stripes: float = 0.0, stripe_depth: float = 0.2, sideburn: float = 1.0) -> ArrayMesh:
	var row: int = SIDES + 1
	var depth := PackedFloat32Array()
	depth.resize(_pos.size())
	for i: int in _pos.size():
		var m: float = _mask(mode, i, sideburn)
		if stripes > 0.0 and m > 0.0:
			m *= 1.0 + stripe_depth * sin(_az[i] * stripes + _uw[i].y * 2.0)
		depth[i] = m * thick
	var remap := PackedInt32Array()
	remap.resize(_pos.size())
	remap.fill(-1)
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for i: int in RINGS:
		for j: int in SIDES:
			var a: int = i * row + j
			var corners: Array[int] = [a, a + 1, a + row, a + row + 1]
			if maxf(maxf(depth[corners[0]], depth[corners[1]]), maxf(depth[corners[2]], depth[corners[3]])) < 0.0002:
				continue
			for c: int in 4:
				var v: int = corners[c]
				if remap[v] < 0:
					remap[v] = verts.size()
					verts.append(_pos[v] + _nrm[v] * (depth[v] + 0.0005))
				corners[c] = remap[v]
			indices.append_array([corners[0], corners[2], corners[1], corners[1], corners[2], corners[3]])
	if verts.is_empty():
		return null
	return MeshKit._commit(verts, MeshKit._smooth_normals(verts, indices), indices)


func _mask(mode: String, i: int, sideburn: float) -> float:
	var u: float = _uw[i].x
	var w: float = _uw[i].y
	var az: float = _az[i]
	var a: float = absf(az)
	match mode:
		"hair", "sides", "top":
			var line: float = hairline(az, sideburn)
			var m: float = smoothstep(line, line + 0.1, w)
			var crown: float = smoothstep(0.5, 0.68, w + 0.1 * cos(az))
			if mode == "sides":
				return m * (1.0 - crown)
			if mode == "top":
				return m * crown
			return m
		"beard":
			var top: float = -0.25 + 0.34 * smoothstep(0.75, 1.5, a)
			var m: float = smoothstep(top, top - 0.09, w) * smoothstep(1.85, 1.55, a)
			m *= 1.0 - 0.95 * _g(u, w, 0.0, -0.42, 0.2, 0.055)
			m = maxf(m, _g(u, w, 0.0, -0.335, 0.3, 0.04) * (1.0 - 0.6 * exp(-pow(u / 0.05, 2.0))) * _front[i])
			return m * lerpf(0.4, 1.0, smoothstep(-0.35, -0.8, w))
	return 0.0


func _grid_indices() -> PackedInt32Array:
	var row: int = SIDES + 1
	var indices := PackedInt32Array()
	for i: int in RINGS:
		for j: int in SIDES:
			var a: int = i * row + j
			indices.append_array([a, a + row, a + 1, a + 1, a + row, a + row + 1])
	return indices
