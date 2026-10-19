class_name TownBuilder
extends RefCounted
## Builds the town as a place (design/08 section 3) from data/town.json: a square of cobbles,
## street fronts with gateways cut into them, the stalls and lamps, and one Townsperson per
## service. Like ZoneBuilder it draws through main.gd's own level helpers, so the town is a level
## like any other (the same movement, camera, colliders and navigation mesh).
## Coordinates in the data are the level's frame: origin at the middle, x east, z south.

var main: Node
var def: Dictionary = {}
var size := Vector2.ZERO
## The people, in data order.
var folk: Array[Townsperson] = []
## The exits with where they are: each a copy of its data plus "centre" (a Vector3, level frame).
var exits: Array[Dictionary] = []


func _init(owner_main: Node, town_def: Dictionary) -> void:
	main = owner_main
	def = town_def
	var s: Array = def.get("size", [36.0, 30.0])
	size = Vector2(float(s[0]), float(s[1]))


func build() -> void:
	var level: Node3D = main.get("level")
	var margin: float = float(def.get("floor_margin", 6.0))
	main.call("_biome_floor", Vector3.ZERO, size + Vector2(margin, margin) * 2.0)
	for edge: String in ["north", "south", "east", "west"]:
		_edge(level, edge)
	_props(level)
	_stations(level)
	_folk(level)


## Where an exit's gateway is, in the level's frame.
func edge_point(edge: String, at: float) -> Vector3:
	match edge:
		"north":
			return Vector3(at, 0.0, -size.y * 0.5 - 0.5)
		"south":
			return Vector3(at, 0.0, size.y * 0.5 + 0.5)
		"east":
			return Vector3(size.x * 0.5 + 0.5, 0.0, at)
	return Vector3(-size.x * 0.5 - 0.5, 0.0, at)


## A point named in town.json "arrive", in the level's frame.
func arrival(where: String) -> Vector3:
	var spots: Dictionary = def.get("arrive", {})
	var at: Array = spots.get(where, spots.get("square", [0.0, 0.0]))
	return Vector3(float(at[0]), 0.0, float(at[1]))


## One side: wall runs with the exits on that side cut out of them, a gate standing in each gap.
func _edge(level: Node3D, edge: String) -> void:
	var height: float = float((def.get("walls", {}) as Dictionary).get(edge, 1.1))
	var along: float = size.x if (edge == "north" or edge == "south") else size.y
	var gaps: Array = []
	for ex: Dictionary in def.get("exits", []):
		if str(ex.get("edge", "")) == edge:
			gaps.append(ex)
	gaps.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["at"]) < float(b["at"]))
	var from: float = -along * 0.5 - 1.0
	for ex: Dictionary in gaps + [{}]:
		var to: float = along * 0.5 + 1.0 if ex.is_empty() else float(ex["at"]) - float(ex["width"]) * 0.5
		_wall_run(edge, from, to, height)
		if ex.is_empty():
			break
		from = float(ex["at"]) + float(ex["width"]) * 0.5
		var centre: Vector3 = edge_point(edge, float(ex["at"]))
		var yaw: float = 90.0 if (edge == "east" or edge == "west") else 0.0
		var gate: Node3D = Biomes.gate("city", float(ex["width"]))
		gate.position = centre
		gate.rotation_degrees.y = yaw
		level.add_child(gate)
		var open: bool = bool(ex.get("open", false))
		gate.call("set_open", open, true)
		# shut: a door you use, not walk through. Open: a backstop a little way out, so nobody
		# walks past the gateway without going through it.
		var out_dir: Vector3 = centre.normalized() if centre.length() > 0.01 else Vector3.FORWARD
		out_dir = Vector3(signf(out_dir.x), 0.0, 0.0) if yaw == 90.0 else Vector3(0.0, 0.0, signf(out_dir.z))
		var stop_at: Vector3 = centre if not open else centre + out_dir * 2.4
		var bar: StaticBody3D = main.call("_static_box", stop_at + Vector3.UP, Vector3(float(ex["width"]) + (0.0 if not open else 2.0), 2.0, 0.6), Color.BLACK, false)
		bar.rotation_degrees.y = yaw
		var placed: Dictionary = ex.duplicate(true)
		placed["centre"] = centre
		exits.append(placed)


## A run of wall along one side between two distances from that side's middle.
func _wall_run(edge: String, from: float, to: float, height: float) -> void:
	if to - from < 0.2:
		return
	var mid: float = (from + to) * 0.5
	var length: float = to - from
	match edge:
		"north":
			main.call("_biome_wall", Vector3(mid, 0, -size.y * 0.5 - 0.5), length, 0.0, height)
		"south":
			main.call("_biome_wall", Vector3(mid, 0, size.y * 0.5 + 0.5), length, 180.0, height)
		"east":
			main.call("_biome_wall", Vector3(size.x * 0.5 + 0.5, 0, mid), length, -90.0, height)
		_:
			main.call("_biome_wall", Vector3(-size.x * 0.5 - 0.5, 0, mid), length, 90.0, height)


## The stalls, lamps and clutter, each solid if the kit says it blocks.
func _props(level: Node3D) -> void:
	var cap: float = float(GameData.balance["biomes"]["blocker_collider_max"])
	var i := 0
	for p: Array in def.get("props", []):
		var kind: String = str(p[0])
		var prop: Node3D = Biomes.prop_variant("city", kind, i)
		i += 1
		prop.position = Vector3(float(p[1]), 0.0, float(p[2]))
		prop.rotation_degrees.y = float(p[3])
		level.add_child(prop)
		var meta: Dictionary = Biomes.prop_meta("city", kind, i - 1)
		if bool(meta.get("blocks", false)):
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = minf(float(meta.get("radius", 0.5)), cap)
			shape.height = 2.0
			col.shape = shape
			sb.add_child(col)
			sb.position = prop.position + Vector3.UP
			level.add_child(sb)


## The crafting stations (design/12): a model and a solid box, each worked by a townsperson whose
## folk entry names the station.
func _stations(level: Node3D) -> void:
	for st: Dictionary in def.get("stations", []):
		var at: Array = st.get("at", [0.0, 0.0])
		var model: Node3D = StationModels.build(str(st["id"]))
		model.position = Vector3(float(at[0]), 0.0, float(at[1]))
		model.rotation_degrees.y = float(st.get("yaw", 0.0))
		level.add_child(model)
		var solid: Array = st.get("solid", [2.0, 1.5])
		var sb: StaticBody3D = main.call("_static_box", model.position + Vector3.UP, Vector3(float(solid[0]), 2.0, float(solid[1])), Color.BLACK, false)
		sb.rotation_degrees.y = model.rotation_degrees.y


## One person per service, looking the same every visit (a fixed seed).
func _folk(level: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(def.get("look_seed", 1))
	for f: Dictionary in def.get("folk", []):
		var at: Array = f.get("at", [0.0, 0.0])
		var person := Townsperson.new()
		person.position = Vector3(float(at[0]), 0.0, float(at[1]))      # placed before it enters the tree
		level.add_child(person)
		person.setup(f, rng)
		folk.append(person)


## The person you could talk to from `world_pos`: the nearest within talk_reach, or null.
func folk_in_reach(world_pos: Vector3) -> Townsperson:
	var reach: float = float(def.get("talk_reach", 2.7))
	var best: Townsperson = null
	var best_d := INF
	for p: Townsperson in folk:
		if not is_instance_valid(p):
			continue
		var d: Vector3 = p.global_position - world_pos
		d.y = 0.0
		if d.length() <= reach and d.length() < best_d:
			best = p
			best_d = d.length()
	return best


## The townsperson with this role, or null.
func person(role: String) -> Townsperson:
	for p: Townsperson in folk:
		if is_instance_valid(p) and p.role == role:
			return p
	return null


## The exit whose gateway `world_pos` is at (within exit_reach of its middle), or {}.
func exit_at(world_pos: Vector3) -> Dictionary:
	var level: Node3D = main.get("level")
	var here: Vector3 = level.to_local(world_pos)
	for ex: Dictionary in exits:
		var c: Vector3 = ex["centre"]
		if Vector2(here.x - c.x, here.z - c.z).length() <= float(def.get("exit_reach", 2.1)):
			return ex
	return {}


## The person drawn under a screen point (their body widened by a margin), or null.
func pick_screen(screen_pos: Vector2, cam: Camera3D) -> Townsperson:
	if cam == null:
		return null
	var margin: float = GameData.num("player", "pick_margin_px")
	var best: Townsperson = null
	var best_d := INF
	for p: Townsperson in folk:
		if not is_instance_valid(p) or cam.is_position_behind(p.global_position):
			continue
		var base: Vector2 = cam.unproject_position(p.global_position)
		var top: Vector2 = cam.unproject_position(p.global_position + Vector3.UP * p.height)
		var side: Vector2 = cam.unproject_position(p.global_position + cam.global_transform.basis.x * p.radius)
		var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, base, top).distance_to(screen_pos)
		if d <= base.distance_to(side) + margin and d < best_d:
			best = p
			best_d = d
	return best
