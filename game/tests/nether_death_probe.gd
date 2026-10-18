extends Node
## Death in the Netherecho, in the whole game (Brent 2026-10-12: "when I died in netherecho the
## game crashed"):
##   godot --headless --path game res://tests/nether_death_probe.tscn [-- --hardcore]
## Starts a character, walks into the passage, leaves the body, and lets a wild construct destroy
## the projection. Standard mode must end with the character alive in town, in debt, and out of
## the echo; hardcore must end on the death screen. Prints "NETHERDEATH: PASS" / "FAIL" and
## exits 0/1. Any script error on the way fails it (ErrorCatcher).
##
## Steps wait on game time, not frame counts: a headless run is unthrottled, so a few hundred
## frames can be a fraction of a second.

const KILL_TIMEOUT_S := 30.0

var main: Node
var step := 0
var t := 0.0
var failed := false
var results: Array[String] = []
var hardcore := false
var money_before := 0
var errors: ErrorCatcher


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hardcore = OS.get_cmdline_user_args().has("--hardcore")
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
	# the state can look right after a script error; the error itself is the crash
	_expect("no script error on the way", errors.count() == 0, "%d, first: %s" % [errors.count(), errors.first()])
	for line: String in results:
		print("NETHERDEATH: " + line)
	print("NETHERDEATH: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _process(delta: float) -> void:
	t += delta
	var player: Node = main.get("player")
	var nether: Netherecho = main.get("nether")
	match step:
		0:
			if t < 0.2:
				return
			main.call("start_new_character", 0)
			main.set("hardcore", hardcore)
			main.call("enter_passage")
			_expect("the character is in the passage", str(main.get("state")) == "dungeon")
			_next()
		1:
			if t < 0.3:
				return
			nether.clear()
			main.call("toggle_projection")
			_expect("the soul leaves the body", nether.active and nether.projection != null and bool(player.get("projecting")))
			money_before = int(player.get("money"))
			if nether.projection != null:
				var proj: Node3D = nether.projection
				proj.set("input_blocked", true)
				proj.set("hp", 1.0)
				var killer: Node3D = nether.spawn_construct(nether.to_local(proj.global_position + Vector3(1.0, 0, 0)), "vestige", "piercing", false)
				killer.set("target", proj)
				# things the echo's update touches after the blow lands
				nether.spawn_wisp(nether.to_local(proj.global_position + Vector3(0.3, 0, 0)), "plain")
				nether.spawn_construct(nether.to_local(proj.global_position + Vector3(-4.0, 0, 0)), "vestige", "reach", true)
			_next()
		2:
			# wait for the blow to land
			if nether.active and t < KILL_TIMEOUT_S:
				return
			_expect("a construct destroyed the projection", not nether.active, "still out after %.0f s" % t)
			_next()
		3:
			if t < 1.0:
				return
			_expect("the trip is over and the body is its own again", nether.projection == null and not bool(player.get("projecting")))
			if hardcore:
				_expect("hardcore: that is the end", str(main.get("state")) == "dead", str(main.get("state")))
				_finish()
				return
			_expect("standard: you wake in town", str(main.get("state")) == "town", str(main.get("state")))
			_expect("alive, naked, and your body left in the passage", not bool(player.get("dead")) and not (player.get("body") as Body).is_dead()
				and int(player.get("money")) == money_before and (player.get("inventory") as Inventory).equipped.is_empty()
				and (player.get("corpses") as Array).size() == 1, "money %d, corpses %d" % [int(player.get("money")), (player.get("corpses") as Array).size()])
			_expect("nothing of the echo is left behind", get_tree().get_nodes_in_group("nether_enemies").is_empty())
			# the game must still be running normally afterwards
			main.call("enter_passage")
			_expect("and you can go straight back in", str(main.get("state")) == "dungeon")
			var lying: Array = get_tree().get_nodes_in_group("corpses")
			_expect("your corpse is lying in the passage where you fell", lying.size() == 1)
			if lying.size() == 1:
				_expect("and taking it puts your things back on", bool(player.call("take_pickup", lying[0])) and not (player.get("inventory") as Inventory).equipped.is_empty()
					and (player.get("corpses") as Array).is_empty())
			_next()
		4:
			if t < 0.5:
				return
			main.call("toggle_projection")
			_expect("and leave the body again", nether.active and nether.projection != null)
			_next()
		5:
			if t < 1.0:
				return
			_expect("the echo is still running a second later", nether.active and nether.projection != null)
			_finish()
