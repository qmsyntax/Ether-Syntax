class_name ZoneBuilder
extends RefCounted
## Builds an overland zone from data/zones.json (design/07 section 6): the floor, the four edges
## with their zone lines cut into them, the road, the landmarks, the Cut House round a dungeon
## door, and the scatter. It draws through the main scene's own level helpers so a zone is a
## level like the passage and the arena. Coordinates in the data are the zone's map frame
## (origin north-west, x east, y south); `to_local` turns them into the level's frame, which has
## its origin at the zone's centre and north along -Z.

var main: Node
var def: Dictionary = {}
var size := Vector2.ZERO


func _init(owner_main: Node, zone_def: Dictionary) -> void:
	main = owner_main
	def = zone_def
	var s: Array = def.get("size", [100, 100])
	size = Vector2(float(s[0]), float(s[1]))


## A map-frame point (x east, y south) in the level's frame.
func to_local(x: float, y: float) -> Vector3:
	return Vector3(x - size.x * 0.5, 0.0, y - size.y * 0.5)


## Where a zone line is, in the level's frame: its middle on the edge.
func line_centre(line: Dictionary) -> Vector3:
	var at: float = float(line["at"])
	match str(line["edge"]):
		"north":
			return to_local(at, 0.0)
		"south":
			return to_local(at, size.y)
		"east":
			return to_local(size.x, at)
	return to_local(0.0, at)


func build() -> void:
	var level: Node3D = main.get("level")
	var bcfg: Dictionary = GameData.balance["biomes"]
	main.call("_biome_floor", Vector3.ZERO, size)
	_road(level)
	_tracks(level)
	var heights: Dictionary = {"north": float(bcfg["wall_height_far"]), "south": float(bcfg["wall_height_near"]),
		"east": float(bcfg["wall_height_side"]), "west": float(bcfg["wall_height_side"])}
	for edge: String in ["north", "south", "east", "west"]:
		_edge(level, edge, heights[edge])
	_cut_house(level)
	var keep_clear: Array = _landmarks(level)
	keep_clear.append_array(_inscriptions(level))
	keep_clear.append_array(_features(level))
	keep_clear.append_array(_power_line(level))
	keep_clear.append_array(_entrances(level))
	keep_clear.append_array(_camp_grounds())
	_nether()
	_scatter(level, keep_clear)
	_decor(level, keep_clear)


## One edge: wall runs with the zone lines on that edge cut out of them. An open line is a gate
## standing open; a shut one is a gate drawn closed with a barrier across it.
func _edge(level: Node3D, edge: String, height: float) -> void:
	var kit: String = str((def.get("edge_kits", {}) as Dictionary).get(edge, def.get("biome", "scrubland")))
	var along: float = size.x if (edge == "north" or edge == "south") else size.y
	var gaps: Array = []
	for line: Dictionary in def.get("lines", []):
		if str(line["edge"]) == edge:
			gaps.append([float(line["at"]) - float(line["width"]) * 0.5, float(line["at"]) + float(line["width"]) * 0.5, line])
	gaps.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var from := 0.0
	for gap: Array in gaps + [[along, along, {}]]:
		_wall_run(level, edge, kit, from, float(gap[0]), height)
		from = float(gap[1])
		var line: Dictionary = gap[2]
		if line.is_empty():
			continue
		var centre: Vector3 = line_centre(line)
		var gate: Node3D = Biomes.gate(kit, float(line["width"]))
		gate.position = centre
		gate.rotation_degrees.y = 90.0 if (edge == "east" or edge == "west") else 0.0
		level.add_child(gate)
		gate.call("set_open", bool(line.get("open", false)), true)
		if not bool(line.get("open", false)):
			var bar: StaticBody3D = main.call("_static_box", Vector3(centre.x, 1.0, centre.z), Vector3(float(line["width"]), 2.0, 0.6), Color.BLACK, false)
			bar.rotation_degrees.y = gate.rotation_degrees.y


## A stretch of wall along `edge` from `a` to `b` metres, in pieces no longer than 24 m.
func _wall_run(level: Node3D, edge: String, kit: String, a: float, b: float, height: float) -> void:
	var length: float = b - a
	if length < 0.5:
		return
	var pieces: int = maxi(1, ceili(length / 24.0))
	var each: float = length / float(pieces)
	for i: int in pieces:
		var mid: float = a + each * (float(i) + 0.5)
		var centre: Vector3
		var yaw := 0.0
		match edge:
			"north":
				centre = to_local(mid, -0.5)
			"south":
				centre = to_local(mid, size.y + 0.5)
				yaw = 180.0
			"east":
				centre = to_local(size.x + 0.5, mid)
				yaw = -90.0
			_:
				centre = to_local(-0.5, mid)
				yaw = 90.0
		var sb: StaticBody3D = main.call("_static_box", Vector3(centre.x, 1.0, centre.z), Vector3(each, 2.0, 1.0), Color.BLACK, false)
		sb.rotation_degrees.y = yaw
		var wall: Node3D = Biomes.wall(kit, each, height)
		wall.position = centre
		wall.rotation_degrees.y = yaw
		level.add_child(wall)


## The road: a worn strip a shade darker than the ground. Nothing is scattered on it.
func _road(level: Node3D) -> void:
	var road: Dictionary = def.get("road", {})
	var pts: Array = road.get("points", [])
	var mat := StandardMaterial3D.new()
	var rc: Array = road.get("color", [0.0, 0.0, 0.0, 0.22])           # a zone may give its road a colour of its own
	mat.albedo_color = Color(float(rc[0]), float(rc[1]), float(rc[2]), float(rc[3]))
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if road.get("color") == null else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 1.0
	for i: int in pts.size() - 1:
		var a: Vector3 = to_local(float(pts[i][0]), float(pts[i][1]))
		var b: Vector3 = to_local(float(pts[i + 1][0]), float(pts[i + 1][1]))
		var strip := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(float(road.get("width", 8.0)), 0.02, a.distance_to(b) + float(road.get("width", 8.0)) * 0.5)
		strip.mesh = box
		strip.material_override = mat
		level.add_child(strip)
		strip.position = (a + b) * 0.5 + Vector3.UP * 0.015
		strip.look_at(level.to_global(b) + Vector3.UP * 0.015, Vector3.UP)


## True if a level-frame point is on the road or a track (with `margin` to spare).
func on_road(local: Vector3, margin: float) -> bool:
	var ways: Array = [def.get("road", {})]
	ways.append_array(def.get("tracks", []))
	var p := Vector2(local.x, local.z)
	for road: Dictionary in ways:
		var pts: Array = road.get("points", [])
		for i: int in pts.size() - 1:
			var a: Vector3 = to_local(float(pts[i][0]), float(pts[i][1]))
			var b: Vector3 = to_local(float(pts[i + 1][0]), float(pts[i + 1][1]))
			if Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(p) <= float(road.get("width", 8.0)) * 0.5 + margin:
				return true
	return false


## The Cut House: a walled yard open toward the field, the dungeon door in its back wall.
func _cut_house(level: Node3D) -> void:
	var ch: Dictionary = def.get("cut_house", {})
	if ch.is_empty():
		return
	var y: Array = ch["yard"]
	var x0: float = float(y[0])
	var y0: float = float(y[1])
	var x1: float = float(y[2])
	var y1: float = float(y[3])
	var h: float = float(GameData.balance["biomes"]["wall_height_divider"])
	var door: Array = ch["door"]
	var dw: float = float(ch.get("door_width", 4.0))
	_house_wall(level, to_local(x0, y0), to_local(x1, y0), h)                      # north side of the yard
	_house_wall(level, to_local(x0, y1), to_local(x1, y1), h)                      # south side
	_house_wall(level, to_local(x1, y0), to_local(x1, float(door[1]) - dw * 0.5), h)      # the back, either side of the door
	_house_wall(level, to_local(x1, float(door[1]) + dw * 0.5), to_local(x1, y1), h)
	var gate: Node3D = Biomes.gate("dungeon", dw)
	gate.position = to_local(float(door[0]), float(door[1]))
	gate.rotation_degrees.y = 90.0
	level.add_child(gate)
	gate.call("set_open", false, true)
	var bar: StaticBody3D = main.call("_static_box", gate.position + Vector3.UP, Vector3(dw, 2.0, 0.6), Color.BLACK, false)
	bar.rotation_degrees.y = 90.0


func _house_wall(level: Node3D, a: Vector3, b: Vector3, height: float) -> void:
	var length: float = a.distance_to(b)
	if length < 0.5:
		return
	var centre: Vector3 = (a + b) * 0.5
	var yaw: float = rad_to_deg(atan2(-(b - a).z, (b - a).x))
	var sb: StaticBody3D = main.call("_static_box", centre + Vector3.UP, Vector3(length, 2.0, 0.8), Color.BLACK, false)
	sb.rotation_degrees.y = yaw
	var wall: Node3D = Biomes.wall("city", length, height)
	wall.position = centre
	wall.rotation_degrees.y = yaw
	level.add_child(wall)


## Landmarks: their props, a collider where they are solid, a Netherecho site. Returns the
## places the scatter must keep away from, as [local position, radius].
func _landmarks(level: Node3D) -> Array:
	var clear: Array = []
	var nether: Node = main.get("nether")
	for mark: Dictionary in def.get("landmarks", []):
		var at: Array = mark["at"]
		var centre: Vector3 = to_local(float(at[0]), float(at[1]))
		for p: Array in mark.get("props", []):
			# ["model", id, dx, dy, scale] is a real model; anything else is [kit, kind, dx, dy]
			var prop: Node3D = RealProps.model(str(p[1]), float(p[4]) if p.size() > 4 else 1.0) if str(p[0]) == "model" else Biomes.prop(str(p[0]), str(p[1]))
			prop.position = centre + Vector3(float(p[2]), 0.0, float(p[3]))
			prop.rotation.y = float(hash(str(mark["id"]) + str(p[1]))) * 0.001
			level.add_child(prop)
		if float(mark.get("solid", 0.0)) > 0.0:
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = float(mark["solid"])
			shape.height = 2.0
			col.shape = shape
			sb.add_child(col)
			sb.position = centre + Vector3.UP
			level.add_child(sb)
		if bool(mark.get("site", false)) and nether != null and not def.has("nether"):
			nether.call("populate_site", centre, Vector2(4.0, 4.0))     # a zone without its own echo data: rolled sites
		clear.append([centre, 5.0])
	var ch: Dictionary = def.get("cut_house", {})
	if not ch.is_empty():
		var y: Array = ch["yard"]
		clear.append([to_local((float(y[0]) + float(y[2])) * 0.5, (float(y[1]) + float(y[3])) * 0.5), 14.0])
	for line: Dictionary in def.get("lines", []):
		clear.append([line_centre(line), float(line["width"]) + 4.0])
	return clear


## Rune stones (design/14 section 8): each reveals one rune when read. Dim if already read.
func _inscriptions(level: Node3D) -> Array:
	var clear: Array = []
	var player: Node = main.get("player")
	var read: Array = player.get("read_inscriptions") if player != null else []
	for ins: Dictionary in def.get("inscriptions", []):
		var at: Array = ins["at"]
		var stone := RuneStone.new()
		stone.setup(str(ins["id"]), str(ins.get("name", "A rune stone")), str(ins.get("pool", "base")))
		stone.position = to_local(float(at[0]), float(at[1]))
		stone.rotation.y = float(hash(str(ins["id"])) % 628) * 0.01
		level.add_child(stone)
		stone.set_read(read.has(str(ins["id"])))
		clear.append([stone.position, 3.0])
	return clear


## The scatter: decoration everywhere off the road; things that block only along the edges,
## where nothing can be trapped behind them; grass to cut. Nothing near a landmark or a line.
func _scatter(level: Node3D, keep_clear: Array) -> void:
	var rng: RandomNumberGenerator = main.get("rng")
	var kit: String = str(def.get("biome", "scrubland"))
	var table: Array = Biomes.info(kit).get("scatter", [])
	var total := 0.0
	for e: Dictionary in table:
		total += float(e["weight"])
	var count: int = int(size.x * size.y / 100.0 * float(def.get("props_per_100m2", 1.0)))
	var edge_blockers: int = int(def.get("edge_blockers", 0))
	var placed := 0
	for i: int in count * 4:
		if placed >= count:
			break
		var roll: float = rng.randf() * total
		var kind: String = str((table[0] as Dictionary)["kind"])
		for e: Dictionary in table:
			roll -= float(e["weight"])
			if roll < 0.0:
				kind = str(e["kind"])
				break
		var meta: Dictionary = Biomes.prop_meta(kit, kind)
		if bool(meta.get("cuttable", false)) or bool(meta.get("light", false)):
			continue                                # living scrub is placed below, as things you can cut
		var blocks: bool = bool(meta.get("blocks", false))
		if blocks:
			if edge_blockers <= 0:
				continue
		var pos: Vector3 = _free_spot(rng, keep_clear, float(meta.get("radius", 0.5)), blocks)
		if pos == Vector3.INF:
			continue
		var prop: Node3D = Biomes.prop(kit, kind)
		prop.position = pos
		prop.rotation.y = rng.randf() * TAU
		level.add_child(prop)
		placed += 1
		if blocks:
			edge_blockers -= 1
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = minf(float(meta.get("radius", 0.5)), float(GameData.balance["biomes"]["blocker_collider_max"]))
			shape.height = 2.0
			col.shape = shape
			sb.add_child(col)
			sb.position = pos + Vector3.UP
			level.add_child(sb)
	for i: int in int(def.get("tufts", 0)):
		var spot: Vector3 = _free_spot(rng, keep_clear, 0.6, false)
		if spot != Vector3.INF:
			main.call("_spawn_cuttable", i, spot)


## Real models scattered over the zone as the data lists them ("decor"): bushes, trees, dead
## wood. With pathfinding, something solid may stand in the open; it gets a trunk collider.
func _decor(level: Node3D, keep_clear: Array) -> void:
	var rng: RandomNumberGenerator = main.get("rng")
	for d: Dictionary in def.get("decor", []):
		var id: String = str(d["model"])
		if not RealProps.exists(id):
			continue
		var range_s: Array = d.get("scale", [1.0, 1.0])
		var solid: float = float(d.get("solid", 0.0))
		for i: int in int(d.get("count", 0)):
			var spot: Vector3 = _free_spot(rng, keep_clear, maxf(solid, 0.5) + 0.5, false)
			if spot == Vector3.INF:
				continue
			var node: Node3D = RealProps.model(id, rng.randf_range(float(range_s[0]), float(range_s[1])), rng.randf() * TAU)
			node.position = spot
			level.add_child(node)
			if solid > 0.0:
				var sb := StaticBody3D.new()
				var col := CollisionShape3D.new()
				var shape := CylinderShape3D.new()
				shape.radius = solid
				shape.height = 2.0
				col.shape = shape
				sb.add_child(col)
				sb.position = spot + Vector3.UP
				level.add_child(sb)
				keep_clear.append([spot, solid + 1.5])


## A random spot for something of `radius`: off the road and clear of the given places; hard
## against an edge if it blocks. Vector3.INF if none was found in a few tries.
func _free_spot(rng: RandomNumberGenerator, keep_clear: Array, radius: float, at_edge: bool) -> Vector3:
	for attempt: int in 8:
		var pos: Vector3
		if at_edge:
			var side: int = rng.randi() % 3                     # north, east or west: never the near edge
			var inset: float = radius + 0.4
			match side:
				0:
					pos = to_local(rng.randf_range(4.0, size.x - 4.0), inset)
				1:
					pos = to_local(size.x - inset, rng.randf_range(4.0, size.y - 4.0))
				_:
					pos = to_local(inset, rng.randf_range(4.0, size.y - 4.0))
		else:
			pos = to_local(rng.randf_range(radius + 1.0, size.x - radius - 1.0), rng.randf_range(radius + 1.0, size.y - radius - 1.0))
		if on_road(pos, radius + 0.5):
			continue
		var ok := true
		for c: Array in keep_clear:
			if Vector2(pos.x - (c[0] as Vector3).x, pos.z - (c[0] as Vector3).z).length() < float(c[1]) + radius:
				ok = false
				break
		if ok:
			return pos
	return Vector3.INF


# --- New Earth's countryside: tracks, the power line, ruins, dungeon mouths (Brent 2026-10-23) ----

## Tracks: narrower, fainter ways than the road (the Cut track from the waystone to the Cut House).
func _tracks(level: Node3D) -> void:
	for track: Dictionary in def.get("tracks", []):
		var pts: Array = track.get("points", [])
		var mat := StandardMaterial3D.new()
		var tc: Array = track.get("color", [0.0, 0.0, 0.0, float(track.get("shade", 0.14))])
		mat.albedo_color = Color(float(tc[0]), float(tc[1]), float(tc[2]), float(tc[3]))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		var w: float = float(track.get("width", 4.0))
		for i: int in pts.size() - 1:
			var a: Vector3 = to_local(float(pts[i][0]), float(pts[i][1]))
			var b: Vector3 = to_local(float(pts[i + 1][0]), float(pts[i + 1][1]))
			var strip := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(w, 0.02, a.distance_to(b) + w * 0.5)
			strip.mesh = box
			strip.material_override = mat
			level.add_child(strip)
			strip.position = (a + b) * 0.5 + Vector3.UP * 0.012
			strip.look_at(level.to_global(b) + Vector3.UP * 0.012, Vector3.UP)


## Single props from the field kit (FieldProps) or a biome kit: ["field" | kit, kind, x, y, yaw, size].
## Blocking ones get a collider (a box along a wall, a cylinder otherwise). Returns keep-clear spots.
func _features(level: Node3D) -> Array:
	var clear: Array = []
	for f: Array in def.get("features", []):
		var kit: String = str(f[0])
		var kind: String = str(f[1])
		var at: Vector3 = to_local(float(f[2]), float(f[3]))
		var yaw: float = float(f[4]) if f.size() > 4 else 0.0
		var sz: float = float(f[5]) if f.size() > 5 else 0.0
		var node: Node3D = FieldProps.prop(kind, sz) if kit == "field" else Biomes.prop(kit, kind)
		node.position = at
		node.rotation.y = deg_to_rad(yaw)
		level.add_child(node)
		var r: float = float(node.get_meta("radius", 1.0))
		if bool(node.get_meta("blocks", false)):
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			if kind == "ruin_wall":
				var box := BoxShape3D.new()
				box.size = Vector3(r * 2.0, 2.0, 0.5)
				col.shape = box
			elif kind == "car_hulk":
				var box2 := BoxShape3D.new()
				box2.size = Vector3(1.8, 2.0, 4.6)
				col.shape = box2
			else:
				var cyl := CylinderShape3D.new()
				cyl.radius = minf(r, 1.6)
				cyl.height = 2.0
				col.shape = cyl
			sb.add_child(col)
			sb.position = at + Vector3.UP
			sb.rotation.y = deg_to_rad(yaw)
			level.add_child(sb)
		clear.append([at, r + 1.0])
	return clear


## The power line along the road: poles at the listed points, three wires sagging from crossarm to
## crossarm. A pole marked "down" lies in the scrub and the wires stop either side of it.
func _power_line(level: Node3D) -> Array:
	var clear: Array = []
	var line: Dictionary = def.get("power_line", {})
	var poles: Array = line.get("poles", [])
	var tops: Array = []
	var dir := Vector3.FORWARD
	if poles.size() >= 2:
		var p0: Vector3 = to_local(float(poles[0][0]), float(poles[0][1]))
		var p1: Vector3 = to_local(float(poles[poles.size() - 1][0]), float(poles[poles.size() - 1][1]))
		dir = (p1 - p0).normalized()
	var yaw: float = atan2(dir.x, dir.z)                         # turns the crossarm (local X) across the line
	for p: Array in poles:
		var at: Vector3 = to_local(float(p[0]), float(p[1]))
		var down: bool = p.size() > 2 and str(p[2]) == "down"
		var pole: Node3D = FieldProps.prop("power_pole")
		pole.position = at
		pole.rotation.y = yaw
		if down:
			pole.rotation = Vector3(0.0, yaw, deg_to_rad(84.0))      # fell across the scrub
		level.add_child(pole)
		clear.append([at, 1.2])
		if down:
			tops.append(null)
			continue
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.25
		cyl.height = 2.0
		col.shape = cyl
		sb.add_child(col)
		sb.position = at + Vector3.UP
		level.add_child(sb)
		tops.append(at)
	var across: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.06, 0.06)
	mat.roughness = 0.6
	for i: int in tops.size() - 1:
		if tops[i] == null or tops[i + 1] == null:
			continue
		for k: int in [-1, 0, 1]:
			var a: Vector3 = (tops[i] as Vector3) + across * FieldProps.POLE_ARM * float(k) + Vector3.UP * (FieldProps.POLE_TOP - 0.12)
			var b: Vector3 = (tops[i + 1] as Vector3) + across * FieldProps.POLE_ARM * float(k) + Vector3.UP * (FieldProps.POLE_TOP - 0.12)
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			for j: int in 13:
				var t: float = float(j) / 12.0
				pts.append(a.lerp(b, t) - Vector3.UP * float(line.get("sag", 1.1)) * 4.0 * t * (1.0 - t))
				radii.append(0.018)
			var wire := MeshInstance3D.new()
			wire.mesh = MeshKit.tube(pts, radii, 3)
			wire.material_override = mat
			wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			level.add_child(wire)
	return clear


## Dungeon mouths that are not open yet (FieldEntrance): a name, a line, sealed for now.
func _entrances(level: Node3D) -> Array:
	var clear: Array = []
	for e: Dictionary in def.get("entrances", []):
		var at: Array = e["at"]
		var node := FieldEntrance.new()
		node.setup(e)
		node.position = to_local(float(at[0]), float(at[1]))
		node.rotation.y = deg_to_rad(float(e.get("yaw", 0.0)))
		level.add_child(node)
		clear.append([node.position, float(e.get("clear", 4.0))])
	return clear


## The ground round each camp is kept clear of blocking clutter, so a fight there has room.
func _camp_grounds() -> Array:
	var clear: Array = []
	for c: Dictionary in def.get("camps", []):
		var at: Array = c["at"]
		clear.append([to_local(float(at[0]), float(at[1])), float(c.get("clear", 5.0))])
	for p: Dictionary in def.get("lurker_patches", []):
		var at2: Array = p["at"]
		clear.append([to_local(float(at2[0]), float(at2[1])), float(p.get("radius", 2.2)) + 0.5])
	return clear


## The zone's own Netherecho (zones.json "nether"): echoes of its landmarks, and its sites.
func _nether() -> void:
	var nether: Node = main.get("nether")
	if nether == null or not def.has("nether"):
		return
	nether.call("populate_zone", def["nether"], to_local)
