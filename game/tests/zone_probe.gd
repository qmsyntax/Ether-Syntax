extends Node
## The first overland zone, end to end (design/07 step 1; Brent 2026-10-18):
##   godot --headless --path game res://tests/zone_probe.tscn
## Walks out of the Dross Gate into the Stubble, checks the edges and lines, the fog of war, the
## Cut House door into the passage and back out to the yard, the gate home, and a death out in
## the field leaving a corpse there. Prints "ZONE: PASS" / "FAIL" and exits 0/1. Any script error
## on the way fails it (ErrorCatcher). Steps wait on game time, not frames.

var main: Node
var player: Node
var step := 0
var t := 0.0
var failed := false
var results: Array[String] = []
var errors: ErrorCatcher
var money_before := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	errors = ErrorCatcher.install()
	Engine.time_scale = 4.0
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s %s" % ["ok  " if ok else "FAIL", label, "" if ok else detail])
	if not ok:
		failed = true


func _next() -> void:
	step += 1
	t = 0.0


func _finish() -> void:
	_expect("no script error on the way", errors.count() == 0, "%d, first: %s" % [errors.count(), errors.first()])
	for line: String in results:
		print("ZONE: " + line)
	print("ZONE: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


## Put the player at a map-frame point of the current zone.
func _stand(x: float, y: float) -> void:
	var zb: ZoneBuilder = main.get("_zone")
	(player as Node3D).global_position = (main.get("level") as Node3D).to_global(zb.to_local(x, y))


func _ray_hits(ax: float, ay: float, bx: float, by: float) -> bool:
	var zb: ZoneBuilder = main.get("_zone")
	var lvl: Node3D = main.get("level")
	var q := PhysicsRayQueryParameters3D.create(lvl.to_global(zb.to_local(ax, ay)) + Vector3.UP, lvl.to_global(zb.to_local(bx, by)) + Vector3.UP, 1)
	return not (lvl.get_world_3d().direct_space_state.intersect_ray(q) as Dictionary).is_empty()


func _process(delta: float) -> void:
	t += delta
	player = main.get("player")
	match step:
		0:
			if t < 0.2:
				return
			main.call("start_new_character", 0)
			main.call("walk_out")
			_expect("walking out of the Dross Gate puts you in the Stubble", str(main.get("state")) == "field" and str(main.get("zone_id")) == "the_stubble")
			var zb: ZoneBuilder = main.get("_zone")
			_expect("it is 240 by 160 m", zb != null and zb.size == Vector2(240, 160))
			_next()
		1:
			if t < 0.3:
				return
			var at: Vector2 = main.call("zone_point", (player as Node3D).global_position)
			_expect("you stand just inside the gate", at.distance_to(Vector2(40, 4)) < 0.5, str(at))
			_expect("the east bank is solid", _ray_hits(236, 80, 244, 80))
			_expect("the Drove Stile is shut for now", _ray_hits(236, 36, 244, 36))
			_expect("the Wet Gap is shut for now", _ray_hits(150, 156, 150, 164))
			_expect("the north wall is solid away from the gate", _ray_hits(120, 4, 120, -4))
			var fog: FogMap = main.get("fog")
			_expect("the fog is lifted where you stand", fog != null and fog.is_seen(40, 4))
			_expect("and nowhere near the Cut House", not fog.is_seen(222, 112))
			_stand(120, 80)
			_next()
		2:
			if t < 0.3:
				return
			var fog2: FogMap = main.get("fog")
			_expect("walking somewhere lifts the fog there", fog2.is_seen(120, 80) and fog2.is_seen(128, 80) and not fog2.is_seen(160, 80))
			_expect("what you have seen is kept with the character", str((player.get("explored") as Dictionary).get("the_stubble", "")) != "")
			var info: Dictionary = main.call("minimap_info")
			_expect("the minimap has the zone, the fog and you", not info.is_empty() and (info["at"] as Vector2).distance_to(Vector2(120, 80)) < 0.5)
			_stand(228.5, 112)
			_next()
		3:
			if t < 0.2:
				return
			_expect("at the Cut House door the prompt offers the passage", str(main.get("_prompt")).contains("Tenwall Cut"), str(main.get("_prompt")))
			money_before = int(player.get("money"))
			main.call("_field_interact")
			_expect("the door takes you into the passage for a ticket", str(main.get("state")) == "dungeon"
				and int(player.get("money")) == money_before - int(main.get("ticket_price")))
			_next()
		4:
			if t < 0.3:
				return
			main.set("cleared", int(main.get("gate_at")))
			main.set("bank", 3000)                          # as if the walls had been cleared
			main.call("_extract")
			_expect("the passage's exit lets you out into the Cut House yard", str(main.get("state")) == "field"
				and (main.call("zone_point", (player as Node3D).global_position) as Vector2).distance_to(Vector2(227, 112)) < 0.5)
			var fog3: FogMap = main.get("fog")
			_expect("and the zone still remembers what you saw", fog3.is_seen(120, 80))
			_expect("carrying the spoils", (player.get("inventory") as Inventory).bag.has("spoils_strongbox"))
			_stand(40, 1.2)
			_next()
		5:
			if t < 0.3:
				return
			_expect("walking into the Dross Gate takes you home", str(main.get("state")) == "town")
			main.call("walk_out")
			_stand(100, 100)
			_next()
		6:
			if t < 0.3:
				return
			(player.get("body") as Body).apply_damage(99999.0)
			player.call("_check_death")
			_next()
		7:
			if t < 0.3:
				return
			_expect("dying out in the field wakes you in town, naked", str(main.get("state")) == "town" and (player.get("inventory") as Inventory).equipped.is_empty())
			var lying: Array = player.get("corpses")
			_expect("with your corpse left in the Stubble", lying.size() == 1 and str((lying[0] as Dictionary)["where"]) == "the_stubble")
			main.call("walk_out")
			_next()
		8:
			if t < 0.3:
				return
			var bodies: Array = get_tree().get_nodes_in_group("corpses")
			_expect("walk back out and it is lying there", bodies.size() == 1
				and (main.call("zone_point", (bodies[0] as Node3D).global_position) as Vector2).distance_to(Vector2(100, 100)) < 1.0)
			var info2: Dictionary = main.call("minimap_info")
			_expect("and marked on the minimap", (info2.get("corpses", []) as Array).size() == 1)
			if bodies.size() == 1:
				_expect("take it and you are dressed again", bool(player.call("take_pickup", bodies[0])) and not (player.get("inventory") as Inventory).equipped.is_empty())
			_finish()
