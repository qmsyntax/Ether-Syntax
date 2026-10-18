class_name NavPath
extends RefCounted
## One walker's path to one goal, kept between frames: asked for again every `repath_s` (balance
## "navigation"), sooner if the goal has moved `repath_moved` or the level's mesh was rebaked, and
## followed corner to corner. A walker keeps one per thing it walks to (the player, a vantage spot).

var points := PackedVector3Array()
var index := 0
var goal := Vector3.INF
var age := 0.0
var version := -1
## True when the path's end falls short of the goal: it cannot be reached from here.
var blocked := false


func _init() -> void:
	age = randf() * GameData.num("navigation", "repath_s")     # walkers spread their queries out


## Forget the path (the walker was moved, or wants something else).
func reset() -> void:
	points = PackedVector3Array()
	index = 0
	goal = Vector3.INF
	blocked = false


## The flat direction to walk from `from` to get to `to` along `nav`, for a walker of `radius`,
## `delta` seconds after the last call. Zero once there (within the last corner), or when `to`
## cannot be reached and the walker already stands at the nearest point it can.
func steer(nav: LevelNav, from: Vector3, to: Vector3, radius: float, delta: float) -> Vector3:
	age += delta
	var moved: float = Vector2(to.x - goal.x, to.z - goal.z).length() if goal != Vector3.INF else INF
	if points.is_empty() or version != nav.version or age >= GameData.num("navigation", "repath_s") or moved > GameData.num("navigation", "repath_moved"):
		points = nav.path(from, to, radius)
		index = 0
		goal = to
		age = 0.0
		version = nav.version
		blocked = not points.is_empty() and flat(points[points.size() - 1], to) > GameData.num("navigation", "unreachable_slack")
	if points.is_empty():
		return _dir(from, to)
	var reached: float = GameData.num("navigation", "corner_reached")
	while index < points.size() and flat(points[index], from) < reached:
		index += 1
	if index >= points.size():
		# at the last corner: the goal itself is a step away, unless it is out of reach
		return Vector3.ZERO if blocked else _dir(from, to)
	return _dir(from, points[index])


## The corner it is walking to now, or `fallback` if it has none.
func next_point(fallback: Vector3) -> Vector3:
	return points[index] if index < points.size() else fallback


## Distance between two points, ignoring height.
static func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _dir(from: Vector3, to: Vector3) -> Vector3:
	var d := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return d.normalized() if d.length() > 0.05 else Vector3.ZERO
