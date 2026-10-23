class_name FieldProps
extends RefCounted
## New Earth's countryside, as procedural props (Brent 2026-10-18: New Earth is modern - ethertech,
## rebuilt towns - and the land round them has roads, wires and ruins). Built from the same
## EnvBuilder pieces as the biome kits and drawn with the shared prop material, so they sit with
## the scrubland kit: a power pole (the wires between poles are ZoneBuilder's), a broken wall of a
## farmhouse, a rusted pickup on blocks, a wire fence, a road sign, the turned earth over a
## Sod-Lurker, and two dungeon mouths - a sinkhole and a barred cellar hatch. All original.
##
##   var pole: Node3D = FieldProps.prop("power_pole")
##   pole.get_meta("height") / ("radius") / ("blocks")

const SOIL := Color(0.2, 0.16, 0.12)
const SOIL_D := Color(0.13, 0.1, 0.08)
const SOIL_L := Color(0.3, 0.25, 0.18)
const POLE := Color(0.25, 0.2, 0.15)
const CERAMIC := Color(0.62, 0.62, 0.58)
const BRICK := Color(0.4, 0.25, 0.19)
const BRICK_D := Color(0.28, 0.18, 0.14)
const CONCRETE := Color(0.46, 0.45, 0.42)
const CONCRETE_D := Color(0.32, 0.31, 0.29)
const RUST := Color(0.36, 0.2, 0.12)
const RUST_D := Color(0.22, 0.13, 0.09)
const IRON := Color(0.14, 0.14, 0.15)
const WIRE := Color(0.12, 0.12, 0.12)
const PAINT := Color(0.45, 0.42, 0.3)
const STRAW := Color(0.52, 0.46, 0.27)
const STEM := Color(0.2, 0.21, 0.11)
const ROCK := Color(0.4, 0.36, 0.3)
const ROCK_D := Color(0.27, 0.24, 0.21)
const VOID := Color(0.015, 0.012, 0.012)

## Height of a pole's crossarm (where the wires hang from), for ZoneBuilder's wires.
const POLE_TOP := 6.2
const POLE_ARM := 0.85

static var _meshes: Dictionary = {}
static var _metas: Dictionary = {}


## A finished prop node: origin on the ground, facing -Z. `size` is a length or radius where the
## kind takes one (wall length, fence length, earth radius); 0 means the kind's default.
static func prop(kind: String, size: float = 0.0) -> Node3D:
	var key: String = "%s|%.1f" % [kind, size]
	if not _meshes.has(key):
		var b: EnvBuilder = EnvKit.builder(hash(key) % 997 + 3)
		var meta: Dictionary = _build(b, kind, size)
		_meshes[key] = b.bake(float(meta.get("height", 1.0)))
		_metas[key] = meta
	var root := Node3D.new()
	root.name = "Field_" + kind
	var inst: MeshInstance3D = EnvKit.instance(_meshes[key])
	root.add_child(inst)
	var meta2: Dictionary = _metas[key]
	for k: String in meta2:
		root.set_meta(k, meta2[k])
	if kind == "sinkhole":
		# the throat of the hole: pure black, unlit, so it reads as a drop and not as a dark floor
		var throat := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		var r: float = float(meta2.get("throat", 1.6))
		disc.top_radius = r
		disc.bottom_radius = r * 0.7
		disc.height = 0.6
		disc.radial_segments = 24
		throat.mesh = disc
		var mat := StandardMaterial3D.new()
		mat.albedo_color = VOID
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		throat.material_override = mat
		throat.position.y = -0.28
		root.add_child(throat)
	return root


static func _meta(radius: float, height: float, blocks: bool) -> Dictionary:
	return {"radius": radius, "height": height, "blocks": blocks}


static func _build(b: EnvBuilder, kind: String, size: float) -> Dictionary:
	match kind:
		"turned_earth":
			# raked, heaped soil: darker than the plain, a little raised, with clods and furrows
			var r: float = size if size > 0.0 else 2.2
			b.m(SOIL_D).rock(r, 0, -r * 0.9, 0, 1.0, 0.1, 0.85, 0, 0.12)
			for i: int in 26:
				var a: float = b.rf(0, TAU)
				var d: float = sqrt(b.rf(0, 1)) * r * 0.9
				b.m(SOIL.lerp(SOIL_L, b.rf(0, 0.6))).rock(b.rf(0.08, 0.2), cos(a) * d, 0.03, sin(a) * d, 1.2, 0.5, 1.0, b.rf(0, 180))
			for k: int in 5:
				var z: float = lerpf(-r * 0.6, r * 0.6, float(k) / 4.0)
				var half: float = sqrt(maxf(0.0, r * r * 0.7 - z * z))
				b.m(SOIL_D.darkened(0.3)).box(half * 2.0, 0.03, 0.08, 0, 0.06, z, b.rf(-8, 8))
			b.tuft(4, 0.35, r * 0.7, STEM, STRAW, r * 0.8, 0.0, 0.03)
			return _meta(r, 0.25, false)
		"power_pole":
			# a creosoted wooden pole with a crossarm and three ceramic insulators, leaning a little
			b.m(POLE).cyl(0.13, 0.17, POLE_TOP, 0, POLE_TOP * 0.5, 0, 8, 0, 1.5)
			b.m(POLE.darkened(0.2)).box(POLE_ARM * 2.0 + 0.2, 0.14, 0.12, 0, POLE_TOP - 0.35, 0)
			b.m(POLE.darkened(0.25)).pole(Vector3(0, POLE_TOP - 1.2, 0), Vector3(0.7, POLE_TOP - 0.42, 0), 0.04, 0.04, 4).pole(Vector3(0, POLE_TOP - 1.2, 0), Vector3(-0.7, POLE_TOP - 0.42, 0), 0.04, 0.04, 4)
			for x: float in [-POLE_ARM, 0.0, POLE_ARM]:
				b.m(CERAMIC, false, ModelRig.METAL, 0.5).lathe([0.05, 0.0, 0.07, 0.06, 0.05, 0.1, 0.07, 0.15, 0.03, 0.22], x, POLE_TOP - 0.28, 0, 8)
			b.m(IRON).cyl(0.18, 0.18, 0.3, 0, 2.2, 0, 8)           # a band and a plate where a number was
			b.m(PAINT).box(0.2, 0.26, 0.02, 0, 2.6, -0.17)
			b.m(SOIL).rock(0.4, 0, 0.0, 0, 1.2, 0.2, 1.2)
			b.tuft(6, 0.6, 0.3, STEM, STRAW, 0.2, 0.2, 0.04)
			return _meta(0.3, POLE_TOP + 0.3, true)
		"ruin_wall":
			# what is left of a brick farmhouse wall: a ragged top, a window gap, rubble at its foot
			var length: float = size if size > 0.0 else 6.0
			var bricks: int = int(length / 0.5)
			for i: int in bricks:
				var x: float = -length * 0.5 + (float(i) + 0.5) * length / float(bricks)
				var h: float = 0.6 + 1.8 * absf(sin(float(i) * 0.9 + 1.3)) + b.rf(0, 0.5)
				if absf(x - length * 0.15) < 0.6:
					h = minf(h, 0.9)                                    # a window once
				b.m(BRICK.lerp(BRICK_D, b.rf(0, 0.6))).bev(length / float(bricks) + 0.02, h, 0.34, x, h * 0.5, 0, 0.02)
				if i % 3 == 1:
					b.m(CONCRETE_D).box(length / float(bricks), 0.08, 0.38, x, h - 0.04, 0)
			for i: int in 3:
				var x2: float = b.rf(-length * 0.4, length * 0.4)
				b.m(RUST_D).pole(Vector3(x2, 1.6, 0), Vector3(x2 + b.rf(-0.2, 0.2), 2.3, b.rf(-0.15, 0.15)), 0.015, 0.012, 4)
			b.stones(14, length * 0.45, 0.08, 0.22, BRICK, CONCRETE_D, 0.0, 0.7, 0.6)
			b.stones(8, length * 0.4, 0.06, 0.18, BRICK_D, CONCRETE, 0.0, -0.6, 0.6)
			b.tuft(8, 0.7, length * 0.3, STEM, STRAW, 0.0, 0.5, 0.05)
			return _meta(length * 0.5, 2.6, true)
		"ruin_slab":
			# a fallen floor slab, tilted, with the rebar showing
			b.m(CONCRETE).bev(3.2, 0.22, 2.2, 0, 0.3, 0, 0.04, 8, 1.0, 9, 4)
			b.m(CONCRETE_D).bev(1.0, 0.2, 0.9, 1.6, 0.12, 0.6, 0.04, -20)
			for i: int in 4:
				b.m(RUST_D).pole(Vector3(-1.4 + 0.7 * float(i), 0.3, 1.0), Vector3(-1.3 + 0.7 * float(i), 0.7, 1.4), 0.012, 0.012, 4)
			return _meta(1.8, 0.8, true)
		"car_hulk":
			# a rusted pickup on blocks, wheels long gone, the glass out
			b.m(RUST).bev(1.7, 0.6, 4.4, 0, 0.75, 0, 0.12)                  # the body
			b.m(RUST_D).bev(1.6, 0.7, 1.6, 0, 1.4, -0.4, 0.14, 0, 0.85)     # the cab
			b.m(VOID).box(1.45, 0.42, 0.04, 0, 1.45, -1.22).box(0.04, 0.38, 1.1, 0.8, 1.45, -0.45).box(0.04, 0.38, 1.1, -0.8, 1.45, -0.45)
			b.m(RUST_D.darkened(0.3)).box(1.5, 0.1, 2.0, 0, 1.06, 1.2)    # the bed
			for z: float in [-1.4, 1.4]:
				for x: float in [-0.75, 0.75]:
					b.m(CONCRETE_D).bev(0.4, 0.45, 0.4, x, 0.22, z, 0.03)
					b.m(SOIL_D).ring(0.18, 0.36, x * 1.02, 0.55, z, 0, 90, 10)
			b.m(IRON).box(1.8, 0.16, 0.16, 0, 0.6, -2.25).box(1.8, 0.16, 0.16, 0, 0.6, 2.25)
			b.m(PAINT).box(0.6, 0.14, 0.02, 0, 0.75, 2.22)
			b.tuft(10, 0.8, 1.2, STEM, STRAW, 0.9, 0.6, 0.05)
			return _meta(2.2, 2.0, true)
		"wire_fence":
			# a stock fence: posts and three sagging strands, a post or two leaning
			var length2: float = size if size > 0.0 else 10.0
			var posts: int = maxi(2, int(length2 / 2.6) + 1)
			for i: int in posts:
				var x3: float = -length2 * 0.5 + length2 * float(i) / float(posts - 1)
				var lean: float = b.rf(-6, 6) if i % 4 != 2 else 18.0
				b.m(POLE.lightened(0.05)).vary(0.1).box(0.09, 1.3, 0.09, x3, 0.6, 0, 0, lean, b.rf(-4, 4))
			for k: int in 3:
				var y: float = 0.4 + 0.33 * float(k)
				var pts: Array = []
				var radii: Array = []
				var n: int = posts * 3
				for j: int in n + 1:
					var t: float = float(j) / float(n)
					var sag: float = 0.06 * sin(t * float(posts - 1) * PI)
					pts.append_array([-length2 * 0.5 + length2 * t, y - absf(sag), 0.0])
					radii.append(0.008)
				b.m(WIRE, false, ModelRig.METAL, 0.3).tube(pts, radii, 3)
			return _meta(length2 * 0.5, 1.3, false)
		"road_sign":
			b.m(IRON).cyl(0.04, 0.04, 2.2, 0, 1.1, 0, 6, 0, 4)
			b.m(PAINT.lightened(0.15), true, ModelRig.METAL, 0.3).bev(0.9, 0.5, 0.04, 0.0, 2.0, 0.0, 0.02, 0, 1.0, 0, 8)
			b.m(RUST).box(0.86, 0.06, 0.05, 0, 1.82, 0.0)
			b.m(SOIL).rock(0.25, 0, 0.0, 0, 1.2, 0.2, 1.2)
			return _meta(0.3, 2.4, true)
		"sinkhole":
			# a sinkhole where the ground fell in: a ragged lip of tumbled earth and stone round a
			# black throat, roots hanging in, the crust cracked for a metre round it
			var r2: float = size if size > 0.0 else 2.2
			for i: int in 22:
				var a: float = TAU * float(i) / 22.0 + b.rf(-0.1, 0.1)
				var d: float = r2 + b.rf(-0.1, 0.35)
				b.m(ROCK.lerp(SOIL, b.rf(0, 0.8))).rock(b.rf(0.25, 0.5), cos(a) * d, 0.08, sin(a) * d, 1.2, 0.55, 1.0, b.rf(0, 180))
			for i: int in 8:
				var a2: float = b.rf(0, TAU)
				var d2: float = r2 + b.rf(0.6, 1.4)
				b.m(SOIL_D.darkened(0.2)).box(b.rf(0.6, 1.2), 0.02, 0.06, cos(a2) * d2, 0.02, sin(a2) * d2, rad_to_deg(-a2) + 90.0)
			for i: int in 6:
				var a3: float = b.rf(0, TAU)
				b.m(Color(0.18, 0.13, 0.09)).tube([cos(a3) * r2, 0.05, sin(a3) * r2, cos(a3) * (r2 - 0.4), -0.2, sin(a3) * (r2 - 0.4), cos(a3) * (r2 - 0.5), -0.6, sin(a3) * (r2 - 0.5)], [0.04, 0.025, 0.0], 4)
			b.m(ROCK_D).rock(0.7, r2 + 0.6, 0.3, -0.3, 1.2, 0.8, 1.0)
			b.tuft(10, 0.6, 0.6, STEM, STRAW, -r2 - 0.4, 0.4, 0.05)
			var meta: Dictionary = _meta(r2 + 0.3, 0.6, true)
			meta["throat"] = r2 - 0.25
			return meta
		"cellar_hatch":
			# a storm-cellar hatch in a concrete curb: two sloped steel doors, a bar across them
			# and a chain round the bar, the paint long gone to rust
			b.m(CONCRETE).bev(2.2, 0.35, 2.4, 0, 0.17, 0, 0.05)
			b.m(CONCRETE_D).bev(2.3, 0.08, 2.5, 0, 0.36, 0, 0.03)
			for side: int in [-1, 1]:
				b.m(RUST.lerp(RUST_D, 0.4 + 0.3 * float(side)), true, ModelRig.METAL, 0.25).bev(0.92, 0.06, 1.9, 0.48 * float(side), 0.62, 0.1, 0.02, 0, 1.0, -14, 12.0 * float(side))
				b.m(IRON).box(0.06, 0.06, 0.24, 0.12 * float(side), 0.72, -0.2)
			b.m(IRON, true, ModelRig.METAL, 0.4).box(2.3, 0.1, 0.12, 0, 0.84, -0.2)
			for k: int in 7:
				b.m(IRON.lightened(0.15), false, ModelRig.METAL, 0.5).ring(0.025, 0.05, -0.3 + 0.1 * float(k), 0.86, -0.2, 90.0 * float(k % 2), 0, 6)
			b.m(IRON.lightened(0.1), true, ModelRig.METAL, 0.5).bev(0.16, 0.2, 0.08, 0.15, 0.7, -0.28, 0.02)
			b.stones(8, 1.6, 0.06, 0.16, CONCRETE_D, BRICK, 0.0, 0.0, 0.6)
			b.tuft(8, 0.6, 0.5, STEM, STRAW, 1.3, 0.8, 0.05)
			return _meta(1.3, 0.9, true)
	return {}
