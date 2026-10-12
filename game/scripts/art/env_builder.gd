class_name EnvBuilder
extends RefCounted
## A terse way to assemble one environment prop from primitives and bake it to a single
## mesh. Set the current surface with m(), add shapes (positions are shape centres unless
## noted, angles in degrees), then call bake(height).
##
##   var b := EnvKit.builder(seed)
##   b.m(Color(0.3, 0.3, 0.32)).box(1, 0.5, 1, 0, 0.25, 0)
##   var mesh := b.bake(0.5)

var rng := RandomNumberGenerator.new()
## Degrees of yaw applied to everything added from now on (0 or 180: lets a piece that was
## authored facing -Z be baked facing +Z).
var turn_y: float = 0.0

var _rig: ModelRig
var _color := Color(0.5, 0.5, 0.5)
var _flat: bool = true
var _kind: int = 0
var _gloss: float = 0.0
var _glow: float = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rig != null and is_instance_valid(_rig):
		_rig.free()


func _init(seed_value: int = 1) -> void:
	rng.seed = seed_value * 7919 + 13
	_rig = ModelRig.new()
	_rig.add_part("body")


## Sets the surface for the shapes that follow. `kind` is a ModelRig kind (CLOTH, SKIN,
## LEATHER_KIND, METAL, HAIR); stone and wood use CLOTH (matte).
func m(color: Color, flat: bool = true, kind: int = 0, gloss: float = 0.0, glow: float = 0.0) -> EnvBuilder:
	_color = color
	_flat = flat
	_kind = kind
	_gloss = gloss
	_glow = glow
	return self


## Random float in a range, from the builder's seeded generator.
func rf(from: float, to: float) -> float:
	return rng.randf_range(from, to)


## The current colour nudged lighter or darker by up to `amount`, for per-piece variation.
func vary(amount: float = 0.08) -> EnvBuilder:
	var k: float = rng.randf_range(-amount, amount)
	_color = _color.lightened(k) if k > 0.0 else _color.darkened(-k)
	return self


## Any mesh, placed by hand.
func mesh(shape: Mesh, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> EnvBuilder:
	if turn_y != 0.0:
		pos = pos.rotated(Vector3.UP, deg_to_rad(turn_y))
		rot.y += turn_y
	_rig.add_shape("body", shape, _color, pos, rot, scale, _glow, _gloss, _flat, _kind)
	return self


## A plain box of size (x, y, z) centred at (px, py, pz).
func box(x: float, y: float, z: float, px: float, py: float, pz: float, ry: float = 0.0, rx: float = 0.0, rz: float = 0.0) -> EnvBuilder:
	var shape := BoxMesh.new()
	shape.size = Vector3(x, y, z)
	return mesh(shape, Vector3(px, py, pz), Vector3(rx, ry, rz))


## A chamfered box; `taper` scales its top face.
func bev(x: float, y: float, z: float, px: float, py: float, pz: float, bevel: float = 0.03, ry: float = 0.0, taper: float = 1.0, rx: float = 0.0, rz: float = 0.0) -> EnvBuilder:
	return mesh(MeshKit.bevel_box(Vector3(x, y, z), bevel, Vector2(taper, taper)), Vector3(px, py, pz), Vector3(rx, ry, rz))


## A cylinder or cone (top radius, bottom radius, height) centred at (px, py, pz).
func cyl(top: float, bottom: float, h: float, px: float, py: float, pz: float, sides: int = 8, rx: float = 0.0, rz: float = 0.0, ry: float = 0.0) -> EnvBuilder:
	return mesh(Models.cyl(top, bottom, h, sides), Vector3(px, py, pz), Vector3(rx, ry, rz))


## A sphere, optionally squashed.
func ball(radius: float, px: float, py: float, pz: float, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0, sides: int = 8) -> EnvBuilder:
	return mesh(Models.ball(radius, sides, maxi(sides / 2, 3)), Vector3(px, py, pz), Vector3.ZERO, Vector3(sx, sy, sz))


## A lumpy boulder (see EnvKit.rock_mesh), optionally squashed and turned.
func rock(radius: float, px: float, py: float, pz: float, sx: float = 1.0, sy: float = 1.0, sz: float = 1.0, ry: float = 0.0, rough: float = 0.28) -> EnvBuilder:
	return mesh(EnvKit.rock_mesh(radius, rng.randi() % 1000, rough), Vector3(px, py, pz), Vector3(rng.randf_range(-12.0, 12.0), ry, rng.randf_range(-12.0, 12.0)), Vector3(sx, sy, sz))


## A surface of revolution from a flat [radius, y, ...] profile.
func lathe(profile: Array, px: float, py: float, pz: float, sides: int = 10, rx: float = 0.0, rz: float = 0.0, ry: float = 0.0, scale: Vector3 = Vector3.ONE) -> EnvBuilder:
	return mesh(Models.lathe(profile, sides), Vector3(px, py, pz), Vector3(rx, ry, rz), scale)


## A tube through a flat [x, y, z, ...] path with a radius per point.
func tube(path: Array, radii: Array, sides: int = 5, flatten: float = 1.0, wide: Vector3 = Vector3.ZERO) -> EnvBuilder:
	return mesh(Models.tube(path, radii, sides, flatten, wide), Vector3.ZERO)


## A straight tapered pole from one point to another.
func pole(from: Vector3, to: Vector3, r_from: float, r_to: float, sides: int = 5) -> EnvBuilder:
	return tube([from.x, from.y, from.z, to.x, to.y, to.z], [r_from, r_to], sides)


## A torus lying flat (hole radius, rim radius).
func ring(inner: float, outer: float, px: float, py: float, pz: float, rx: float = 0.0, rz: float = 0.0, sides: int = 10) -> EnvBuilder:
	return mesh(Models.torus(inner, outer, sides, 4), Vector3(px, py, pz), Vector3(rx, 0, rz))


## A flat polygon ([x, y, ...] outline in the XY plane) given thickness along Z.
func plate(outline: Array, depth: float, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> EnvBuilder:
	return mesh(MeshKit.extrude(Models.poly(outline), depth), pos, rot)


## A scatter of `count` boulders within `spread` metres of (cx, cz), sizes r_min..r_max,
## each shaded somewhere between colours `a` and `b`.
func stones(count: int, spread: float, r_min: float, r_max: float, a: Color, b: Color, cx: float = 0.0, cz: float = 0.0, squash: float = 0.7) -> EnvBuilder:
	for i: int in count:
		var r: float = rf(r_min, r_max)
		var ang: float = rf(0.0, TAU)
		var d: float = sqrt(rng.randf()) * spread
		m(a.lerp(b, rng.randf())).rock(r, cx + cos(ang) * d, r * squash * 0.55, cz + sin(ang) * d, 1.0, squash, 1.0, rf(0.0, 180.0))
	return self


## A clump of `count` stiff blades up to `h` tall around (cx, cz), bending outward.
func tuft(count: int, h: float, spread: float, a: Color, b: Color, cx: float = 0.0, cz: float = 0.0, width: float = 0.05) -> EnvBuilder:
	for i: int in count:
		var ang: float = TAU * float(i) / float(count) + rf(-0.3, 0.3)
		var hh: float = h * rf(0.5, 1.0)
		var start: float = rf(0.0, spread * 0.4)
		var out: float = start + hh * rf(0.15, 0.6)
		var dir := Vector3(cos(ang), 0, sin(ang))
		var base: Vector3 = Vector3(cx, 0, cz) + dir * start
		var mid: Vector3 = Vector3(cx, hh * 0.55, cz) + dir * lerpf(start, out, 0.35)
		var tip: Vector3 = Vector3(cx, hh, cz) + dir * out
		m(a.lerp(b, rng.randf()))
		tube([base.x, base.y, base.z, mid.x, mid.y, mid.z, tip.x, tip.y, tip.z], [width, width * 0.8, 0.0], 3, 0.35)
	return self


## A bare branching tree: a leaning trunk `h` tall that forks into `limbs` boughs, each with
## twigs. `cap` (alpha > 0) lays that colour along the top of the boughs (snow, moss).
## Returns the bough tips so callers can hang foliage or moss from them.
func bare_tree(h: float, bark: Color, limbs: int = 4, girth: float = 0.16, lean: float = 0.25, cap: Color = Color(0, 0, 0, 0), cx: float = 0.0, cz: float = 0.0) -> Array[Vector3]:
	var tips: Array[Vector3] = []
	var bend: float = rf(0.0, TAU)
	var top := Vector3(cx + cos(bend) * lean * h * 0.3, h * 0.55, cz + sin(bend) * lean * h * 0.3)
	m(bark)
	tube([cx, 0.0, cz, lerpf(cx, top.x, 0.4), h * 0.28, lerpf(cz, top.z, 0.4), top.x, top.y, top.z], [girth * 1.35, girth, girth * 0.7], 6)
	for i: int in limbs:
		var ang: float = TAU * float(i) / float(limbs) + rf(-0.4, 0.4)
		var reach: float = h * rf(0.22, 0.4)
		var knee: Vector3 = top + Vector3(cos(ang) * reach * 0.5, h * rf(0.12, 0.22), sin(ang) * reach * 0.5)
		var tip: Vector3 = top + Vector3(cos(ang) * reach, h * rf(0.3, 0.46), sin(ang) * reach)
		m(bark).tube([top.x, top.y, top.z, knee.x, knee.y, knee.z, tip.x, tip.y, tip.z], [girth * 0.6, girth * 0.36, girth * 0.1], 5)
		var twig: Vector3 = knee + Vector3(cos(ang + 1.2) * reach * 0.4, h * 0.14, sin(ang + 1.2) * reach * 0.4)
		pole(knee, twig, girth * 0.25, girth * 0.06, 4)
		if cap.a > 0.0:
			m(Color(cap.r, cap.g, cap.b))
			var a: Vector3 = top.lerp(knee, 0.4) + Vector3(0, girth * 0.4, 0)
			var c: Vector3 = knee + Vector3(0, girth * 0.3, 0)
			tube([a.x, a.y, a.z, c.x, c.y, c.z, lerpf(c.x, tip.x, 0.6), lerpf(c.y, tip.y, 0.6) + girth * 0.1, lerpf(c.z, tip.z, 0.6)], [girth * 0.45, girth * 0.34, girth * 0.12], 4, 0.6, Vector3(cos(ang + 1.57), 0, sin(ang + 1.57)))
		tips.append(tip)
	return tips


## Bakes everything added so far into one mesh. `height` is the prop's height in metres
## (it sets how far up the baked ground shadow reaches). The builder is spent afterwards.
func bake(height: float) -> ArrayMesh:
	_rig.height = maxf(height, 0.3)
	_rig.ao_strength = 0.85
	_rig.finish()
	var out: ArrayMesh = _rig.part_mesh("body")
	_rig.free()
	_rig = null
	return out
