class_name NetherEchoes
extends RefCounted
## The Netherecho's version of a place's landmarks (design/07: landmarks are Netherecho sites;
## design/01 LAW 5: the echo shows only what stands still, or moves the same way again and again).
## Each is a painted caricature of the real thing - too tall, too crooked, its one telling feature
## blown up - drawn in the spirit look (translucent, self-lit, bright at the edges), so it reads
## as the same place seen wrongly. Built from MeshKit shapes on a ghost ModelRig; original designs.
##
##   var well: Node3D = NetherEchoes.build("well")

static var _snaps: Dictionary = {}


## An echo of `kind`: well, hanging_tree, heap, waystone, pole, ruin, sinkhole. Unknown kinds get
## a plain glowing cairn.
static func build(kind: String) -> Node3D:
	var key: String = "echo:" + kind
	if _snaps.has(key):
		return ModelRig.from_snapshot(_snaps[key])
	var r := ModelRig.new()
	r.name = "Echo_" + kind
	r.ao_strength = 0.3
	r.set_ghost(0.55, 1.4, 0.65)
	match kind:
		"well":
			_well(r)
		"hanging_tree":
			_hanging_tree(r)
		"heap":
			_heap(r)
		"waystone":
			_waystone(r)
		"pole":
			_pole(r)
		"ruin":
			_ruin(r)
		"sinkhole":
			_sinkhole(r)
		_:
			r.add_shape("body", EnvKit.rock_mesh(0.8, 5), Color(0.5, 0.45, 0.8), Vector3(0, 0.6, 0), Vector3.ZERO, Vector3(1, 1.4, 1), 0.0, 0.0, true)
	r.finish()
	_snaps[key] = r.snapshot()
	return r


## The dry well: a ring of stones as tall as a man and leaning, a winch twice the size it should
## be, and a rope that hangs down into a pale, bottomless shine - the well remembers water.
static func _well(r: ModelRig) -> void:
	var stone := Color(0.55, 0.6, 0.95)
	var wood := Color(0.6, 0.45, 0.85)
	var water := Color(0.45, 0.85, 1.0)
	r.add_part("body")
	r.add_shape("body", Models.lathe([1.5, 0.0, 1.6, 0.3, 1.4, 1.9, 1.55, 2.1, 1.25, 2.1, 1.2, 0.0], 18), stone, Vector3.ZERO, Vector3(0, 0, 4), Vector3.ONE, 0.0, 0.0, true)
	r.add_shape("body", Models.cyl(1.2, 1.2, 0.05, 20), water, Vector3(0, 0.6, 0), Vector3.ZERO, Vector3.ONE, 1.8)
	r.add_shape("body", Models.cyl(0.4, 1.1, 0.02, 20), water.lightened(0.3), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3.ONE, 2.4)
	for side: int in [-1, 1]:
		r.add_shape("body", Models.tube([1.35 * float(side), 1.9, 0, 1.5 * float(side), 3.6, 0.2, 1.3 * float(side), 4.6, 0.0], [0.12, 0.1, 0.08], 6), wood)
	r.add_shape("body", Models.tube([-1.4, 4.4, 0, 0.0, 4.9, 0.1, 1.4, 4.4, 0], [0.09, 0.12, 0.09], 6), wood)
	r.add_shape("body", Models.tube([0.1, 4.6, 0.1, 0.0, 3.0, -0.05, 0.05, 1.4, 0.0, 0.0, 0.2, 0.0], [0.025, 0.025, 0.02, 0.01], 4), wood.lightened(0.2))
	r.add_shape("body", Models.lathe([0.25, 0.0, 0.35, 0.5, 0.3, 0.55], 10), wood, Vector3(0.0, 2.2, 0.0), Vector3(0, 0, 18))
	r.add_shape("body", Models.ball(0.3, 10, 6), water, Vector3(0.0, 2.75, 0.0), Vector3.ZERO, Vector3(1, 0.4, 1), 1.6)


## The hanging tree: the dead tree three times its height, its branches curling over into hooks,
## one long limb reaching out with a noose that does not move in any wind.
static func _hanging_tree(r: ModelRig) -> void:
	var bark := Color(0.5, 0.42, 0.78)
	var rope := Color(0.9, 0.75, 0.6)
	r.add_part("body")
	r.add_shape("body", Models.tube([0, 0, 0, 0.3, 2.0, 0.1, -0.2, 4.0, -0.2, 0.2, 6.0, 0.1, 0.0, 7.4, 0.0], [0.6, 0.42, 0.3, 0.2, 0.06], 9), bark)
	var limbs: Array = [[3.2, 0.0, 1.0], [4.4, 2.1, 1.3], [5.4, 4.0, 1.1], [6.3, 1.0, 0.9], [4.0, 5.0, 1.2]]
	for l: Array in limbs:
		var y: float = float(l[0])
		var a: float = float(l[1])
		var reach: float = float(l[2]) * 2.4
		var tip := Vector3(cos(a) * reach, y + 0.8, sin(a) * reach)
		r.add_shape("body", Models.tube([0, y, 0, tip.x * 0.5, y + 1.0, tip.z * 0.5, tip.x, tip.y, tip.z, tip.x * 1.05, tip.y - 0.6, tip.z * 1.05], [0.2, 0.12, 0.06, 0.0], 6), bark)
	# the reaching limb and the noose
	r.add_shape("body", Models.tube([0, 3.6, 0, 1.8, 4.2, 0.2, 3.6, 4.4, 0.4, 4.2, 4.2, 0.4], [0.24, 0.16, 0.1, 0.05], 7), bark.lightened(0.1))
	r.add_shape("body", Models.tube([3.9, 4.3, 0.4, 3.9, 2.6, 0.4], [0.03, 0.03], 4), rope, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.8)
	r.add_shape("body", Models.torus(0.22, 0.28, 16, 5), rope, Vector3(3.9, 2.35, 0.4), Vector3(90, 0, 0), Vector3.ONE, 1.2)
	for k: int in 6:
		var a2: float = TAU * float(k) / 6.0
		r.add_shape("body", Models.tube([0, 0.3, 0, cos(a2) * 1.2, 0.0, sin(a2) * 1.2, cos(a2) * 2.0, -0.2, sin(a2) * 2.0], [0.25, 0.12, 0.0], 5), bark.darkened(0.15))


## The dross heap: a mound swollen into a hill, with the things thrown on it - a bed frame, a
## wheel, ribs - jutting out of it at angles, each outlined in light.
static func _heap(r: ModelRig) -> void:
	var muck := Color(0.55, 0.5, 0.8)
	var scrap := Color(0.85, 0.7, 0.55)
	r.add_part("body")
	r.add_shape("body", EnvKit.rock_mesh(2.6, 77, 0.35, 12, 7), muck, Vector3(0, 0.8, 0), Vector3.ZERO, Vector3(1.4, 0.6, 1.1), 0.0, 0.0, true)
	r.add_shape("body", EnvKit.rock_mesh(1.4, 78, 0.35, 10, 6), muck.lightened(0.1), Vector3(1.6, 1.8, -0.5), Vector3.ZERO, Vector3(1.0, 0.8, 1.0), 0.0, 0.0, true)
	r.add_shape("body", Models.torus(0.7, 0.85, 18, 5), scrap, Vector3(-1.4, 2.0, 0.6), Vector3(70, 20, 0), Vector3.ONE, 0.9)
	for k: int in 5:
		r.add_shape("body", Models.tube([0.6 + 0.3 * float(k), 1.4, -1.6, 0.8 + 0.3 * float(k), 2.8, -1.2, 0.5 + 0.3 * float(k), 3.6, -0.6], [0.07, 0.05, 0.0], 5), scrap.lightened(0.2), Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 0.5)
	r.add_shape("body", Models.bbox(2.2, 0.12, 1.0, 0.03), scrap.darkened(0.2), Vector3(-0.5, 2.6, -0.8), Vector3(10, 30, 50), Vector3.ONE, 0.4)


## The waystone: a monolith three times as tall, leaning out over the track, its carved marks
## cut so deep they glow straight through.
static func _waystone(r: ModelRig) -> void:
	var stone := Color(0.5, 0.55, 0.9)
	var mark := Color(0.7, 0.95, 1.0)
	r.add_part("body")
	r.add_shape("body", Models.bbox(1.0, 4.8, 0.7, 0.12, 0.6, 0.7), stone, Vector3(0, 2.3, 0), Vector3(0, 0, 9), Vector3.ONE, 0.0, 0.0, true)
	for k: int in 5:
		var y: float = 1.2 + 0.7 * float(k)
		r.add_shape("body", Models.bbox(0.6 - 0.06 * float(k), 0.08, 0.76, 0.02), mark, Vector3(-0.35 * sin(deg_to_rad(9)) * y, y, 0.0), Vector3(0, 0, 9), Vector3.ONE, 2.0)
	r.add_shape("body", EnvKit.rock_mesh(1.3, 12), stone.darkened(0.2), Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.2, 0.25, 1.2), 0.0, 0.0, true)


## A power pole: twice too tall and bent like a reed, its wires swooping off in great loops.
static func _pole(r: ModelRig) -> void:
	var wood := Color(0.6, 0.5, 0.85)
	var wire := Color(0.75, 0.95, 1.0)
	r.add_part("body")
	r.add_shape("body", Models.tube([0, 0, 0, 0.2, 4.0, 0, -0.3, 8.0, 0, 0.4, 11.0, 0], [0.25, 0.2, 0.15, 0.1], 6), wood)
	r.add_shape("body", Models.bbox(3.4, 0.2, 0.2, 0.04), wood, Vector3(0.4, 10.6, 0), Vector3(0, 0, -6))
	for x: float in [-1.4, 0.4, 2.0]:
		r.add_shape("body", Models.tube([x, 10.6, 0, x + 0.4, 8.0, -3.0, x + 0.2, 7.0, -7.0, x, 9.0, -11.0], [0.04, 0.04, 0.04, 0.03], 4), wire, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.4)
		r.add_shape("body", Models.tube([x, 10.6, 0, x - 0.4, 8.0, 3.0, x - 0.2, 7.0, 7.0, x, 9.0, 11.0], [0.04, 0.04, 0.04, 0.03], 4), wire, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, 1.4)


## The burnt steading: its broken wall stands whole again in the echo, but as a row of teeth.
static func _ruin(r: ModelRig) -> void:
	var brick := Color(0.75, 0.5, 0.75)
	r.add_part("body")
	for k: int in 7:
		var h: float = 2.0 + 2.2 * absf(sin(float(k) * 1.7))
		r.add_shape("body", Models.cyl(0.05, 0.45, h, 5), brick.lightened(0.05 * float(k % 3)), Vector3(-3.0 + float(k), h * 0.5, 0.0), Vector3(0, 0, 6.0 * sin(float(k))), Vector3.ONE, 0.0, 0.0, true)
	r.add_shape("body", Models.bbox(7.2, 0.5, 0.6, 0.05), brick.darkened(0.2), Vector3(0.0, 0.25, 0.0))


## The Swallow: the sinkhole's echo is a slow whirl of rings going down into light.
static func _sinkhole(r: ModelRig) -> void:
	var ring := Color(0.55, 0.5, 0.95)
	r.add_part("body")
	for k: int in 6:
		var rad: float = 2.6 - 0.35 * float(k)
		r.add_shape("body", Models.torus(rad - 0.08, rad, 28, 5), ring.lightened(0.08 * float(k)), Vector3(0, 0.2 - 0.25 * float(k), 0), Vector3(0, 15.0 * float(k), 4.0 * float(k % 2)), Vector3.ONE, 0.6 + 0.3 * float(k))
	r.add_shape("body", Models.ball(0.4, 10, 6), Color(0.9, 0.95, 1.0), Vector3(0, -1.4, 0), Vector3.ZERO, Vector3.ONE, 3.0)
