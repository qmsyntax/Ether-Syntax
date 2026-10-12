class_name BiomeCity
extends RefCounted
## Old town street: cobbles, timber-and-plaster fronts, lamps, a market and a gatehouse.
## Signs carry shapes, never writing.

const COBBLE := Color(0.31, 0.3, 0.29)
const COBBLE_D := Color(0.2, 0.2, 0.21)
const STONE := Color(0.36, 0.35, 0.33)
const STONE_D := Color(0.23, 0.22, 0.22)
const PLASTER := Color(0.5, 0.46, 0.38)
const PLASTER_D := Color(0.38, 0.34, 0.28)
const TIMBER := Color(0.19, 0.14, 0.1)
const WOOD := Color(0.3, 0.22, 0.14)
const ROOF := Color(0.22, 0.2, 0.22)
const TILE := Color(0.33, 0.17, 0.13)
const IRON := Color(0.11, 0.11, 0.13)
const AWNING := Color(0.4, 0.13, 0.11)
const AWNING_B := Color(0.5, 0.45, 0.36)
const GLOW := Color(1.0, 0.72, 0.36)
const KINDS: Array[String] = ["lamp_post", "stall", "cart", "well", "crate", "barrel", "signboard", "kerb", "bench", "sacks", "trough"]


static func info() -> Dictionary:
	return {
		"label": "Old town", "floor_color": COBBLE, "wall_color": PLASTER,
		"sky": Color(0.07, 0.08, 0.12), "ambient": Color(0.46, 0.5, 0.64), "ambient_energy": 0.55,
		"sun_color": Color(1.0, 0.8, 0.62), "sun_energy": 0.95, "sun_rotation": Vector3(-34, -38, 0),
		"fog_color": Color(0.12, 0.12, 0.16), "fog_density": 0.008,
		"props": KINDS,
		"scatter": [{"kind": "crate", "weight": 2.0}, {"kind": "barrel", "weight": 2.0}, {"kind": "sacks", "weight": 2.0}, {"kind": "bench", "weight": 1.0}],
		"stage": [
			["kerb", -12, -11.6, 0], ["kerb", -8, -11.6, 0], ["kerb", -4, -11.6, 0], ["kerb", 0, -11.6, 0], ["kerb", 4, -11.6, 0], ["kerb", 8, -11.6, 0], ["kerb", 12, -11.6, 0],
			["kerb", -11.6, -8, 90], ["kerb", -11.6, -4, 90], ["kerb", -11.6, 0, 90], ["kerb", -11.6, 4, 90], ["kerb", -11.6, 8, 90], ["kerb", -11.6, 12, 90],
			["lamp_post", -10.6, -10.6, 0], ["lamp_post", 2, -10.8, 0], ["lamp_post", -10.8, 5, 90], ["lamp_post", 11, 0, 0], ["lamp_post", 1, 12, 0],
			["stall", -4, -5, 180], ["stall", 1.5, -5.5, 180], ["stall", -7.5, 1, 90], ["well", 3, 2.5, 0], ["cart", -2, 4.5, 30], ["cart", 10, -6, 100],
			["signboard", 7, -10.6, 0], ["signboard", -10.6, -3, 90], ["trough", 8, 8, 20], ["bench", 5.5, 5.5, 200], ["sacks", -5.5, -3, 0], ["sacks", 2.5, -3.6, 0], ["barrel", -1.8, -6.4, 0], ["crate", -8.6, 3.2, 0],
		],
	}


static func floor_material() -> ShaderMaterial:
	return EnvKit.surface(3, COBBLE, COBBLE_D, Color(0.07, 0.07, 0.07))


static func build(b: EnvBuilder, kind: String) -> Dictionary:
	match kind:
		"lamp_post":
			b.m(STONE_D).bev(0.44, 0.3, 0.44, 0, 0.15, 0, 0.05)
			b.m(IRON, true, ModelRig.METAL, 0.7).lathe([0.09, 0.3, 0.06, 0.5, 0.045, 2.9, 0.07, 3.0], 0, 0, 0, 7)
			b.tube([0, 2.85, 0, 0, 3.25, -0.1, 0, 3.3, -0.45, 0, 3.2, -0.6], [0.03, 0.03, 0.025, 0.02], 4)
			b.box(0.3, 0.035, 0.3, 0, 3.2, -0.6).box(0.34, 0.03, 0.34, 0, 2.82, -0.6)
			b.cyl(0.0, 0.24, 0.18, 0, 3.3, -0.6, 4, 0, 0, 45)
			for sx: int in [-1, 1]:
				for sz: int in [-1, 1]:
					b.box(0.025, 0.38, 0.025, 0.14 * sx, 3.01, -0.6 + 0.14 * sz)
			b.m(GLOW, true, 0, 0.0, 1.8).box(0.2, 0.3, 0.2, 0, 3.0, -0.6)
			var made: Dictionary = Biomes.meta(0.3, 3.4, true, false, Vector3(0, 2.95, -0.6))
			made["light_range"] = 8.5
			return made
		"stall":
			# A market stall: counter, crates of goods, a striped awning on four posts.
			for sx: int in [-1, 1]:
				b.m(WOOD).box(0.1, 2.3, 0.1, 1.3 * sx, 1.15, -0.8).box(0.1, 2.7, 0.1, 1.3 * sx, 1.35, 0.8)
				b.box(0.07, 0.07, 1.7, 1.3 * sx, 2.42, 0.0, 0, 14)
			b.m(WOOD.darkened(0.12)).box(2.8, 0.1, 1.0, 0, 0.92, -0.35).box(2.7, 0.8, 0.06, 0, 0.5, -0.8).box(0.06, 0.8, 0.9, 1.3, 0.5, -0.35).box(0.06, 0.8, 0.9, -1.3, 0.5, -0.35)
			for i: int in 7:
				b.m(AWNING if i % 2 == 0 else AWNING_B, true, ModelRig.CLOTH).box(0.42, 0.03, 1.95, -1.26 + 0.42 * float(i), 2.52, -0.05, 0, 14)
				b.box(0.42, 0.22, 0.03, -1.26 + 0.42 * float(i), 2.2, -1.0)
			b.m(WOOD).vary().box(0.6, 0.25, 0.5, -0.8, 1.1, -0.35, 8).vary().box(0.55, 0.22, 0.5, 0.0, 1.08, -0.4, -5)
			for i: int in 6:
				b.m([Color(0.55, 0.2, 0.12), Color(0.5, 0.42, 0.18), Color(0.3, 0.36, 0.18)][i % 3], false).ball(0.08, -0.95 + 0.14 * float(i % 3) + 0.8 * float(i / 3), 1.26, -0.35 + b.rf(-0.1, 0.1), 1, 1, 1, 6)
			b.m(Color(0.5, 0.46, 0.36), false).lathe([0.12, 0.0, 0.18, 0.12, 0.14, 0.32, 0.08, 0.36], 0.85, 0.97, -0.3, 8)
			b.m(IRON, true, ModelRig.METAL, 0.7).pole(Vector3(1.0, 2.3, -0.8), Vector3(1.0, 1.9, -0.8), 0.01, 0.01, 3).ring(0.05, 0.07, 1.0, 1.82, -0.8, 90)
			b.m(WOOD.darkened(0.2)).box(0.5, 0.45, 0.5, 0.2, 0.225, 0.5, 20)
			return Biomes.meta(1.8, 2.8, true)
		"cart":
			b.m(WOOD).box(1.2, 0.08, 2.0, 0, 0.7, 0).vary().box(0.06, 0.4, 2.0, 0.6, 0.92, 0).box(0.06, 0.4, 2.0, -0.6, 0.92, 0).box(1.2, 0.4, 0.06, 0, 0.92, 1.0)
			b.m(WOOD.darkened(0.2)).box(0.07, 0.07, 1.5, 0.45, 0.72, -1.7, 0, -8).box(0.07, 0.07, 1.5, -0.45, 0.72, -1.7, 0, -8).box(1.0, 0.06, 0.06, 0, 0.62, -2.4)
			for sx: int in [-1, 1]:
				b.m(WOOD.darkened(0.3)).mesh(Models.torus(0.4, 0.5, 14, 4), Vector3(0.72 * sx, 0.5, 0.15), Vector3(0, 0, 90))
				for k: int in 4:
					b.box(0.05, 0.86, 0.05, 0.72 * sx, 0.5, 0.15, 0, 45.0 * float(k))
				b.m(IRON, true, ModelRig.METAL, 0.6).cyl(0.07, 0.07, 0.12, 0.72 * sx, 0.5, 0.15, 6, 0, 90)
			b.m(Color(0.45, 0.4, 0.3), false).rock(0.4, 0.1, 0.95, 0.3, 1.2, 0.6, 1.4, 0, 0.12).m(WOOD).vary().box(0.5, 0.4, 0.5, -0.2, 0.94, -0.5, 12)
			b.m(WOOD.darkened(0.2)).box(0.08, 0.6, 0.08, 0, 0.3, -0.9)
			return Biomes.meta(1.5, 1.2, true)
		"well":
			b.m(STONE_D).cyl(1.05, 1.1, 0.16, 0, 0.08, 0, 10)
			for i: int in 10:
				var a: float = TAU * float(i) / 10.0
				b.m(STONE.lerp(STONE_D, b.rf(0, 0.7))).bev(0.52, 0.8, 0.3, cos(a) * 0.75, 0.55, sin(a) * 0.75, 0.04, -rad_to_deg(a) + 90.0)
			b.m(Color(0.03, 0.04, 0.05)).cyl(0.62, 0.62, 0.05, 0, 0.6, 0, 10)
			for sx: int in [-1, 1]:
				b.m(WOOD).box(0.12, 2.0, 0.12, 0.85 * sx, 1.2, 0)
			b.m(WOOD.darkened(0.15)).cyl(0.08, 0.08, 1.9, 0, 1.75, 0, 6, 0, 90)
			b.m(TILE).box(2.1, 0.06, 0.8, 0, 2.42, -0.3, 0, 32).box(2.1, 0.06, 0.8, 0, 2.42, 0.3, 0, -32)
			b.m(Color(0.42, 0.36, 0.24)).cyl(0.11, 0.11, 0.5, 0, 1.75, 0, 6, 0, 90).pole(Vector3(0.1, 1.7, 0), Vector3(0.1, 1.05, 0), 0.015, 0.015, 3)
			b.m(WOOD, false).lathe([0.1, 0.0, 0.14, 0.24, 0.13, 0.25, 0.09, 0.03], 0.1, 0.82, 0, 8)
			b.m(IRON, true, ModelRig.METAL, 0.6).box(0.4, 0.03, 0.03, 0.95, 1.75, 0).box(0.03, 0.3, 0.03, 1.15, 1.6, 0)
			return Biomes.meta(1.2, 2.7, true)
		"crate":
			BiomeDungeon._crate(b, Vector3.ZERO, 0.8, b.rf(-8, 8))
			if b.rng.randf() < 0.5:
				BiomeDungeon._crate(b, Vector3(0.75, 0, b.rf(-0.2, 0.2)), 0.6, b.rf(10, 60))
			return Biomes.meta(0.8, 0.8, true, true)
		"barrel":
			b.m(WOOD, false).lathe([0.3, 0.0, 0.37, 0.25, 0.39, 0.5, 0.37, 0.75, 0.3, 1.0], 0, 0, 0, 12)
			b.m(WOOD.darkened(0.3)).cyl(0.28, 0.28, 0.02, 0, 0.97, 0, 12)
			b.m(IRON, false, ModelRig.METAL, 0.7)
			for y: float in [0.14, 0.5, 0.86]:
				var rr: float = 0.345 if y != 0.5 else 0.395
				b.lathe([rr, y - 0.03, rr + 0.012, y, rr, y + 0.03], 0, 0, 0, 12)
			return Biomes.meta(0.42, 1.0, true, true)
		"signboard":
			# A post with a hanging board: a pictograph, never lettering. Three trades.
			b.m(STONE_D).bev(0.4, 0.25, 0.4, 0, 0.125, 0, 0.04)
			b.m(TIMBER).box(0.14, 3.0, 0.14, 0, 1.7, 0).box(0.1, 0.1, 1.2, 0, 3.0, -0.5).pole(Vector3(0, 2.4, -0.05), Vector3(0, 2.95, -0.7), 0.035, 0.035, 4)
			b.m(IRON, true, ModelRig.METAL, 0.6).box(0.02, 0.2, 0.02, 0, 2.86, -0.3).box(0.02, 0.2, 0.02, 0, 2.86, -0.9)
			b.m(WOOD).bev(0.06, 0.7, 0.8, 0, 2.42, -0.6, 0.02)
			b.m(TIMBER).box(0.08, 0.76, 0.05, 0, 2.42, -0.2).box(0.08, 0.76, 0.05, 0, 2.42, -1.0).box(0.08, 0.05, 0.84, 0, 2.78, -0.6).box(0.08, 0.05, 0.84, 0, 2.06, -0.6)
			var shape: int = b.rng.randi() % 3
			for sx: int in [-1, 1]:
				var x: float = 0.04 * sx
				b.m(Color(0.62, 0.52, 0.3))
				if shape == 0:
					b.plate([-0.14, -0.2, 0.14, -0.2, 0.17, 0.16, -0.17, 0.16], 0.02, Vector3(x, 2.42, -0.62), Vector3(0, 90, 0)).mesh(Models.torus(0.07, 0.1, 8, 4), Vector3(x, 2.42, -0.4), Vector3(0, 0, 90))
				elif shape == 1:
					b.plate([-0.2, -0.22, 0.16, -0.22, 0.18, -0.08, 0.0, -0.04, -0.02, 0.22, -0.2, 0.22], 0.02, Vector3(x, 2.42, -0.6), Vector3(0, 90, 0))
				else:
					b.plate([-0.24, 0.02, -0.08, 0.12, 0.2, 0.12, 0.2, 0.0, 0.06, -0.02, 0.1, -0.2, -0.1, -0.2, -0.06, -0.04], 0.02, Vector3(x, 2.42, -0.6), Vector3(0, 90, 0))
			return Biomes.meta(0.3, 3.2, true)
		"kerb":
			# Four metres of raised pavement edge with a gutter in front (-Z is the street).
			b.m(STONE).box(4.0, 0.16, 1.1, 0, 0.08, 0.55)
			for i: int in 5:
				b.m(STONE.lerp(STONE_D, b.rf(0, 0.6))).bev(0.78, 0.2, 0.3, -1.6 + 0.8 * float(i), 0.1, -0.1, 0.03)
			b.m(COBBLE_D.darkened(0.3)).box(4.0, 0.02, 0.3, 0, 0.012, -0.42)
			b.m(Color(0.1, 0.12, 0.13), true, 0, 0.9).box(1.2, 0.012, 0.16, b.rf(-1.0, 1.0), 0.028, -0.42)
			return Biomes.meta(2.1, 0.2, false)
		"bench":
			b.m(WOOD).box(1.6, 0.07, 0.4, 0, 0.45, 0).box(1.6, 0.3, 0.05, 0, 0.8, 0.2, 0, 8)
			for sx: int in [-1, 1]:
				b.m(TIMBER).box(0.08, 0.45, 0.4, 0.68 * sx, 0.225, 0).box(0.07, 0.95, 0.07, 0.68 * sx, 0.5, 0.22)
			return Biomes.meta(0.9, 0.95, true)
		"sacks":
			for i: int in 5:
				var x: float = [-0.3, 0.3, 0.0, -0.1, 0.35][i]
				var z: float = [0.0, 0.1, -0.4, 0.3, -0.3][i]
				var y: float = 0.2 if i < 3 else 0.52
				b.m(Color(0.47, 0.41, 0.3).lerp(Color(0.36, 0.3, 0.22), b.rf(0, 1)), false).rock(0.3, x, y, z, 1.0, 0.75, 1.3, b.rf(0, 180), 0.1)
				b.cyl(0.03, 0.07, 0.1, x, y + 0.22, z + 0.3, 5, 60)
			return Biomes.meta(0.75, 0.8, true, true)
		"trough":
			b.m(STONE).bev(1.9, 0.5, 0.75, 0, 0.3, 0, 0.05).m(STONE_D).bev(0.5, 0.12, 0.85, -0.6, 0.06, 0, 0.03).bev(0.5, 0.12, 0.85, 0.6, 0.06, 0, 0.03)
			b.m(Color(0.07, 0.1, 0.11), true, 0, 0.95).box(1.7, 0.02, 0.55, 0, 0.52, 0)
			b.m(IRON, true, ModelRig.METAL, 0.6).ring(0.06, 0.09, 0.98, 0.35, 0, 0, 90)
			return Biomes.meta(1.1, 0.56, true)
	return {}


## A street front along the wall: timber-and-plaster houses in four-metre bays (door, window,
## shopfront, plain), one storey below 4.5 m and two above, each under a tiled roof edge.
static func wall(b: EnvBuilder, length: float, height: float) -> Dictionary:
	b.turn_y = 180.0
	var bays: int = maxi(int(round(length / 4.0)), 1)
	var bay: float = length / float(bays)
	var storeys: int = 1 if height < 4.5 else 2
	var floor_h: float = (height - 0.5) / float(storeys)
	for i: int in bays:
		var x: float = -length * 0.5 + bay * (float(i) + 0.5)
		var what: int = (i * 3 + 1) % 4
		var plaster: Color = PLASTER.lerp(PLASTER_D, b.rf(0, 1))
		var jut: float = -0.5 + (0.0 if i % 2 == 0 else -0.12)
		b.m(STONE_D).box(bay, 0.5, 0.9, x, 0.25, 0.0)
		b.m(plaster).box(bay - 0.04, height - 0.5, 0.8, x, 0.5 + (height - 0.5) * 0.5, 0.05)
		b.m(TIMBER)
		for edge: int in [-1, 1]:
			b.box(0.2, height - 0.3, 0.14, x + (bay * 0.5 - 0.1) * edge, 0.3 + (height - 0.3) * 0.5, jut + 0.1)
		for s: int in storeys + 1:
			b.box(bay, 0.18, 0.16, x, 0.5 + floor_h * float(s) - (0.09 if s == storeys else 0.0), jut + 0.1)
		for s: int in storeys:
			var base: float = 0.5 + floor_h * float(s)
			if s == 0 and what == 0:
				b.m(WOOD.darkened(0.2)).box(1.0, 2.0, 0.1, x, 1.5, jut + 0.1).m(TIMBER).box(1.24, 0.14, 0.16, x, 2.56, jut + 0.08).box(0.12, 2.1, 0.16, x - 0.56, 1.5, jut + 0.08).box(0.12, 2.1, 0.16, x + 0.56, 1.5, jut + 0.08)
				b.m(IRON, true, ModelRig.METAL, 0.6).box(0.9, 0.06, 0.02, x, 1.0, jut + 0.04).box(0.9, 0.06, 0.02, x, 2.0, jut + 0.04).ball(0.04, x + 0.34, 1.5, jut + 0.03)
				b.m(STONE).bev(1.5, 0.2, 0.5, x, 0.4, jut - 0.15, 0.03)
			elif s == 0 and what == 2:
				# Shopfront: a wide shuttered opening with a counter and a small awning.
				b.m(Color(0.05, 0.045, 0.04)).box(bay - 1.2, floor_h - 1.3, 0.1, x, 0.5 + 0.9 + (floor_h - 1.3) * 0.5, jut + 0.12)
				b.m(WOOD).box(bay - 1.0, 0.1, 0.5, x, 1.4, jut - 0.1).box(bay - 1.2, 0.9, 0.08, x, 0.95, jut + 0.1)
				for k: int in 5:
					b.m(AWNING if k % 2 == 0 else AWNING_B, true, ModelRig.CLOTH).box((bay - 0.8) / 5.0, 0.04, 0.9, x - (bay - 0.8) * 0.5 + (bay - 0.8) / 5.0 * (float(k) + 0.5), floor_h + 0.05, jut - 0.3, 0, 22)
				b.m(GLOW, true, 0, 0.0, 0.5).box(0.5, 0.5, 0.04, x + bay * 0.2, 2.0, jut + 0.16)
			elif what != 3 or s > 0:
				# A shuttered window, lit in some bays.
				var lit: bool = (i + s) % 3 == 0
				var wy: float = base + floor_h * 0.55
				b.m(GLOW if lit else Color(0.06, 0.07, 0.09), true, 0, 0.0 if lit else 0.8, 0.9 if lit else 0.0).box(0.9, 1.0, 0.06, x, wy, jut + 0.12)
				b.m(TIMBER).box(1.1, 0.1, 0.14, x, wy + 0.55, jut + 0.08).box(1.2, 0.12, 0.2, x, wy - 0.55, jut + 0.05).box(0.07, 1.0, 0.08, x, wy, jut + 0.07).box(0.9, 0.06, 0.08, x, wy, jut + 0.07)
				b.m(WOOD.darkened(0.1)).box(0.42, 1.0, 0.05, x - 0.68, wy, jut + 0.07, 12).box(0.42, 1.0, 0.05, x + 0.68, wy, jut + 0.07, -12)
			if what == 3 or s > 0:
				b.m(TIMBER).box(0.12, floor_h * 1.25, 0.1, x - bay * 0.3, base + floor_h * 0.5, jut + 0.09, 0, 0, 30).box(0.12, floor_h * 1.25, 0.1, x + bay * 0.3, base + floor_h * 0.5, jut + 0.09, 0, 0, -30)
		# Roof edge: a pitched slope of tile courses over the street, a ridge board behind.
		for course: int in 4:
			b.m(TILE.lerp(ROOF, b.rf(0, 0.5))).box(bay + 0.1, 0.07, 0.42, x, height + 0.12 + 0.22 * float(course), -0.85 + 0.36 * float(course), 0, -32)
		b.m(ROOF).box(bay + 0.1, 0.2, 0.3, x, height + 0.95, 0.55)
		if i % 3 == 1:
			b.m(STONE_D).box(0.5, 1.1, 0.5, x + bay * 0.25, height + 1.2, 0.3).m(STONE).box(0.6, 0.12, 0.6, x + bay * 0.25, height + 1.8, 0.3)
	return {"core": null, "thickness": 1.0}


## A gatehouse arch with an iron-bound timber drop gate. The gate lifts.
static func gate(frame: EnvBuilder, barrier: EnvBuilder, width: float) -> Dictionary:
	var h: float = 3.3
	for side: int in [-1, 1]:
		var x: float = (width * 0.5 + 0.6) * side
		frame.m(STONE_D).bev(1.4, 0.4, 1.6, x, 0.2, 0, 0.05)
		frame.m(STONE).bev(1.2, h + 1.4, 1.4, x, (h + 1.4) * 0.5 + 0.2, 0, 0.05)
		for k: int in 2:
			frame.m(STONE.lerp(STONE_D, 0.4)).bev(0.5, 0.5, 1.5, x + (0.35 if k == 0 else -0.35), h + 1.85, 0, 0.04)
		frame.m(GLOW, true, 0, 0.0, 0.9).box(0.16, 0.5, 0.04, x, 2.9, -0.71)
	frame.m(STONE).bev(width + 0.2, 1.2, 1.3, 0, h + 0.8, 0, 0.05)
	frame.m(STONE_D).bev(width + 2.6, 0.2, 1.5, 0, h + 1.5, 0, 0.04)
	for i: int in int(width / 1.0) + 1:
		frame.m(STONE.lerp(STONE_D, 0.4)).bev(0.5, 0.5, 1.5, -width * 0.5 + 0.25 + 1.0 * float(i), h + 1.85, 0, 0.04)
	var planks: int = maxi(int(width / 0.4), 3)
	for i: int in planks:
		barrier.m(WOOD.darkened(0.15)).vary(0.1).box(width / float(planks) - 0.02, h, 0.16, -width * 0.5 + width / float(planks) * (float(i) + 0.5), h * 0.5 + 0.05, 0)
	barrier.m(IRON, true, ModelRig.METAL, 0.7)
	for y: float in [0.45, 1.65, 2.85]:
		barrier.box(width, 0.16, 0.22, 0, y, 0)
		for i: int in planks:
			barrier.ball(0.045, -width * 0.5 + width / float(planks) * (float(i) + 0.5), y, -0.12, 1, 1, 1, 5)
	barrier.m(Color(0.75, 0.1, 0.06), true, 0, 0.0, 0.5).box(0.5, 0.5, 0.06, 0, 2.2, -0.14, 0, 0, 45)
	return {"height": h + 2.2, "shift": Vector3(0, h + 0.1, 0)}
