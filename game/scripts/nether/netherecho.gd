class_name Netherecho
extends Node3D
## The Netherecho: a deeper layer of the same place, reached by projecting the soul out of a
## meditating body (design/01 LAW 5). This node owns what lives there for the current level -
## wisps and wild constructs - and the projection while one is out.
##
## Rules it enforces (canon where marked; numbers are ours, in balance.json "nether"):
##   - the projection is leashed to the body, further with more stars            [canon: range grows per star]
##   - wisps are gathered by touch; water wisps grow the star                      [canon: gathering]
##   - constructs are subdued, not killed, and can then be carried out and bound  [Brent 2026-09-18]
##   - the projection is fragile and its destruction is the character's death     [canon]
##   - hurting the body drags the soul back                                        [ours]

signal entered
signal exited(reason: String)
signal projection_destroyed

const ProjectionScript := preload("res://scripts/nether/projection.gd")
const ConstructScript := preload("res://scripts/nether/nether_construct.gd")
const WispScript := preload("res://scripts/nether/wisp.gd")

var player: Node3D
var projection: Node3D
var active := false
var rng := RandomNumberGenerator.new()
var gathered_this_trip := 0
var subdued_this_trip := 0

var _cfg: Dictionary
var _armed_return := false
var _foreign_note_cd := 0.0


func _init() -> void:
	rng.randomize()
	_cfg = GameData.balance["nether"]
	visible = false                 # nothing here can be seen from the waking world


## Remove everything (the level is being torn down).
func clear() -> void:
	if active:
		exit("the place is gone")
	for c: Node in get_children():
		c.queue_free()


## Seed one site: a patch of the level, in this node's local space, `half` metres across each way.
func populate_site(centre: Vector3, half: Vector2) -> void:
	for i: int in int(_cfg["wisps_per_site"]):
		var at := centre + Vector3(rng.randf_range(-half.x, half.x), 0.0, rng.randf_range(-half.y, half.y))
		spawn_wisp(at, _roll_wisp_affinity())
	if rng.randf() < float(_cfg["construct_chance_per_site"]):
		var ids: Array = GameData.concept_ids()
		var tier: String = "remnant" if rng.randf() < float(_cfg["remnant_chance"]) else "vestige"
		var at2 := centre + Vector3(rng.randf_range(-half.x, half.x) * 0.6, 0.0, rng.randf_range(-half.y, half.y) * 0.6)
		spawn_construct(at2, tier, str(ids[rng.randi() % ids.size()]), rng.randf() < float(_cfg["docile_chance"]))


## What a new wisp is: one of the traveller's own affinities, someone else's, or plain ether.
func _roll_wisp_affinity() -> String:
	var mine: Array = player.get("affinities") if player != null else []
	var roll: float = rng.randf()
	if not mine.is_empty() and roll < float(_cfg["attuned_wisp_chance"]):
		return str(mine[rng.randi() % mine.size()])
	if roll < float(_cfg["attuned_wisp_chance"]) + float(_cfg["foreign_wisp_chance"]):
		var others: Array = GameData.affinity_ids().filter(func(a: Variant) -> bool: return not mine.has(a))
		if not others.is_empty():
			return str(others[rng.randi() % others.size()])
	return "plain"


func spawn_wisp(local_pos: Vector3, affinity: String) -> Node3D:
	var w: Node3D = WispScript.new()
	w.call("setup", affinity)
	w.position = local_pos
	add_child(w)
	return w


func spawn_construct(local_pos: Vector3, tier: String, concept: String, docile: bool) -> Node3D:
	var c: Node3D = ConstructScript.new()
	c.call("setup", tier, concept, docile)
	c.position = local_pos
	add_child(c)
	c.connect("subdued", _on_subdued)
	return c


## Why the soul cannot leave the body right now, or "" if it can.
func cannot_enter_reason() -> String:
	if active:
		return "You are already out."
	if player == null or bool(player.get("dead")):
		return "No."
	if bool(player.get("in_combat")):
		return "You cannot still your mind while something is trying to kill you."
	return ""


func enter() -> bool:
	if cannot_enter_reason() != "":
		return false
	active = true
	visible = true
	gathered_this_trip = 0
	subdued_this_trip = 0
	_armed_return = false
	_foreign_note_cd = 0.0
	player.set("projecting", true)
	projection = ProjectionScript.new()
	add_child(projection)
	projection.global_position = player.global_position
	projection.call("setup", player.global_position, int(player.get("stars")))
	projection.connect("destroyed", _on_projection_destroyed)
	for c: Node in get_tree().get_nodes_in_group("nether_enemies"):
		c.set("target", projection)
	entered.emit()
	return true


func exit(reason: String = "") -> void:
	if not active:
		return
	active = false
	visible = false
	for c: Node in get_tree().get_nodes_in_group("nether_enemies"):
		c.set("target", null)
		c.set("hostile", false)
	if projection != null:
		projection.queue_free()
		projection = null
	if player != null and is_instance_valid(player):
		player.set("projecting", false)
	exited.emit(reason)


func tick(delta: float, cam: Camera3D) -> void:
	if not active or projection == null:
		return
	_foreign_note_cd -= delta
	projection.call("tick", delta, cam)
	for c: Node in get_tree().get_nodes_in_group("nether_enemies"):
		# a construct's blow can destroy the projection, which ends the trip (and may tear the
		# whole level down) in the middle of this loop - there is then nothing left to update
		if not active or projection == null:
			return
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			c.call("tick", delta)
	if not active or projection == null:
		return
	_gather_wisps()
	if not active or projection == null:
		return
	# walking back onto the body ends the trip - but only after having left it
	var d: Vector3 = projection.global_position - player.global_position
	d.y = 0.0
	if d.length() > float(_cfg["return_arm_distance"]):
		_armed_return = true
	elif _armed_return and d.length() <= float(_cfg["return_distance"]):
		exit("You settle back into your body.")


func _gather_wisps() -> void:
	for node: Node in get_tree().get_nodes_in_group("nether_wisps"):
		var w := node as Node3D
		var d: Vector3 = w.global_position - projection.global_position
		d.y = 0.0
		if d.length() > float(_cfg["wisp_reach"]):
			continue
		var kind: String = str(w.get("affinity"))
		var attuned: bool = (player.get("affinities") as Array).has(kind)
		if kind != "plain" and not attuned:
			# a wisp of an affinity you do not hold slides away from the touch
			if _foreign_note_cd <= 0.0:
				_foreign_note_cd = 4.0          # say it again if they keep trying, but not every frame
				player.call("note", "A %s wisp. It will not come to you - you have no such affinity." % str(GameData.affinity(kind).get("label", kind)).to_lower())
			continue
		var essence: float = float(_cfg["wisp_attuned_essence"]) if attuned else float(_cfg["wisp_plain_essence"])
		if attuned:
			player.call("grow_star", float(_cfg["wisp_attuned_star_pct"]))
		player.set("essence", minf(float(player.get("essence_max")), float(player.get("essence")) + essence))
		gathered_this_trip += 1
		w.call("gather")


func _on_subdued(construct: Node) -> void:
	subdued_this_trip += 1
	(player.get("constructs") as Array).append({"tier": str(construct.get("tier")), "concept": str(construct.get("concept"))})
	player.call("note", "The %s is subdued. It is yours to bind." % str(construct.get("display_name")))
	player.call("add_aura", 6.0 if str(construct.get("tier")) == "vestige" else 18.0)
	# subduing a construct reveals a rune of its concept (Brent 2026-10-23, design/14 section 8)
	player.call("on_construct_subdued", str(construct.get("tier")), str(construct.get("concept")))


func _on_projection_destroyed() -> void:
	exit("Your projection is torn apart.")
	projection_destroyed.emit()


## State for the HUD while a projection is out; {} otherwise.
func hud_info() -> Dictionary:
	if not active or projection == null:
		return {}
	var off: Vector3 = projection.global_position - player.global_position
	off.y = 0.0
	return {
		"hp": float(projection.get("hp")), "hp_max": float(projection.get("hp_max")),
		"leash": off.length() / float(projection.get("leash")), "at_leash": bool(projection.get("at_leash")),
		"gathered": gathered_this_trip, "subdued": subdued_this_trip,
		"hovered": projection.get("hovered"), "target": projection.get("attack_target"),
		"position": projection.global_position,
	}
