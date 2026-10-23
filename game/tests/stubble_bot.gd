extends Node
## The Stubble's loop, end to end (Brent 2026-10-23):
##   godot --headless --path game res://tests/stubble_bot.tscn
## A scripted, invulnerable, overpowered player (the passage bots' `bot` flag) walks out of the
## Dross Gate, clears the first camp (the tip-pickers), picks up what they left, walks home along
## the road through the Dross Gate, and sells it in town. Prints "STUBBLEBOT: PASS" / "FAIL" and
## exits 0/1. Proves the loop holds together (camp, kills, remains, the gate, the sale); says nothing
## about difficulty or feel. Any script error fails it. Waits on game time, not frames.

var main: Node
var player: Node
var step := 0
var t := 0.0
var total := 0.0
var failed := false
var results: Array[String] = []
var errors: ErrorCatcher
var picked: Array[String] = []
var money_before := 0
var _path := NavPath.new()
var _waypoints: Array = [[66, 24], [58, 14], [44, 9], [40, 3], [40, -1]]


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
	Engine.time_scale = 1.0
	_expect("no script error on the way", errors.count() == 0, "%d, first: %s" % [errors.count(), errors.first()])
	for line: String in results:
		print("STUBBLEBOT: " + line)
	print("STUBBLEBOT: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _at(x: float, y: float) -> Vector3:
	var zb: ZoneBuilder = main.get("_zone")
	return (main.get("level") as Node3D).to_global(zb.to_local(x, y))


func _process(delta: float) -> void:
	t += delta
	total += delta
	player = main.get("player")
	if total > 240.0 and step < 9:
		_expect("finished in time", false, "stuck at step %d" % step)
		_finish()
		return
	match step:
		0:
			if t < 0.2:
				return
			main.call("start_new_character", 0)
			main.call("walk_out")
			_expect("out of the Dross Gate into the Stubble", str(main.get("state")) == "field")
			var camps: FieldCamps = main.get("field_camps")
			_expect("the Stubble has its camps", camps != null and camps.camps.has("tip_pickers") and camps.state_of("tip_pickers") == "asleep")
			# walk the bot to the edge of the first camp, then let it fight
			(player as Node3D).global_position = _at(70.0, 30.0)
			player.set("bot", true)
			player.set("bot_goal", _at(78.0, 40.0))
			_next()
		1:
			var camps2: FieldCamps = main.get("field_camps")
			if camps2.state_of("tip_pickers") == "awake" and t < 30.0:
				return
			if camps2.state_of("tip_pickers") != "cleared":
				if t < 30.0:
					return
				_expect("the bot clears the tip-pickers", false, camps2.state_of("tip_pickers"))
				_finish()
				return
			_expect("the bot woke the tip-pickers and cleared them", true)
			_next()
		2:
			if t < 1.0:
				return
			# take what they left: the remains of every kill (and anything else that dropped)
			player.set("bot", false)
			player.set("attack_target", null)
			for n: Node in get_tree().get_nodes_in_group("pickups"):
				var d: Node3D = n as Node3D
				if d.global_position.distance_to(_at(78.0, 40.0)) < 12.0 and not d.is_queued_for_deletion():
					var id: String = str(d.get("item_id"))
					if bool(player.call("take_pickup", d)):
						picked.append(id)
			_expect("their remains are on the ground and in the pack", picked.has("kettle_shell") and (player.get("inventory") as Inventory).bag.has("kettle_shell"), str(picked))
			_next()
		3:
			# walk home along the road: a path on the level's navigation, waypoint to waypoint
			if str(main.get("state")) == "town":
				_next()
				return
			if _waypoints.is_empty() or t > 90.0:
				_expect("walks home through the Dross Gate", false, "state %s at %s" % [str(main.get("state")), str(main.call("zone_point", (player as Node3D).global_position))])
				_finish()
				return
			var goal: Vector3 = _at(float(_waypoints[0][0]), float(_waypoints[0][1]))
			var here: Vector3 = (player as Node3D).global_position
			if Vector2(goal.x - here.x, goal.z - here.z).length() < 1.2:
				_waypoints.pop_front()
				return
			var way: Vector3 = goal - here
			var nav: LevelNav = LevelNav.find(get_tree(), here)
			if nav != null:
				var stepped: Vector3 = _path.steer(nav, here, goal, 0.4, delta)
				if stepped != Vector3.ZERO:
					way = stepped
			way.y = 0.0
			player.set("move_goal", here + way.normalized() * 1.5)
			player.set("has_move_goal", true)
		4:
			if t < 0.5:
				return
			_expect("walked home through the Dross Gate into town", str(main.get("state")) == "town")
			money_before = int(player.get("money"))
			var worth := 0
			var inv: Inventory = player.get("inventory")
			for id: String in inv.bag:
				if Inventory.is_loot(id):
					worth += inv.sale_price(id)
			var got: int = main.call("town_sell_loot")
			_expect("and sold what the camp left for its worth", got > 0 and got == worth and int(player.get("money")) == money_before + got and not inv.bag.has("kettle_shell"),
				"got %d worth %d money %d -> %d" % [got, worth, money_before, int(player.get("money"))])
			_finish()
			step = 99
