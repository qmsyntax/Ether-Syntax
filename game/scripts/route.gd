class_name Route
extends RefCounted
## The one piece of steering this game has: getting through a doorway.
##
## The passage is a row of chambers along -Z, each `ch_len` long, divided by walls with a gap of
## `gap_half` either side of x = 0. Nothing here can path around an obstacle, so anything that
## walks straight at a target in another chamber walks into the dividing wall and stands there.
## That never happened while every enemy simply charged the player; it does now that pouncers
## circle and archers hold their distance, and it stalled the passage bot (2026-10-12).
##
## Positions are in the level's own frame. Everything is flat (y is ignored).


## Which chamber a point is in: 0 is the antechamber, then 1, 2, ... going down the passage.
static func chamber_of(local: Vector3, ch_len: float) -> int:
	return maxi(0, int(floor(-local.z / ch_len)))


## Where to walk next to get from `from` to `to`: `to` itself if they are in the same chamber,
## otherwise a point that takes you through the doorway between this chamber and the next one
## on the way. `radius` is the walker's own, so it lines up clear of the wall's edge.
static func step_toward(from: Vector3, to: Vector3, ch_len: float, gap_half: float, radius: float) -> Vector3:
	var a: int = chamber_of(from, ch_len)
	var b: int = chamber_of(to, ch_len)
	if a == b:
		return to
	var deeper: bool = b > a
	# the dividing wall on the way: between chamber a and the next one toward b
	var wall_z: float = -float(a + 1) * ch_len if deeper else -float(a) * ch_len
	var side: float = -1.0 if deeper else 1.0            # which way through: -Z is deeper
	var clear: float = maxf(0.2, gap_half - radius - 0.25)
	var lined_up: bool = absf(from.x) <= clear
	if lined_up:
		# in line with the gap: straight through to a little past the wall
		return Vector3(clampf(from.x, -clear, clear), from.y, wall_z + side * 1.6)
	# off to one side: first to a spot in front of the gap, then through
	return Vector3(clampf(from.x, -clear, clear) * 0.5, from.y, wall_z - side * 1.4)
