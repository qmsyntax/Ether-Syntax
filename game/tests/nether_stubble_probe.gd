extends Node
## The Stubble's own Netherecho (Brent 2026-10-23):
##   godot --headless --path game res://tests/nether_stubble_probe.tscn
## A new character walks out to the dry well, projects, and finds the echo of the place: the
## landmarks' echoes, wisps placed by the zone's features (water at the well), and the well's
## constructs scaled for a new projection. It gathers a wisp of its own affinity, beats a vestige
## down until it is subdued, and comes away with the construct and a rune it did not know. Prints
## "NETHERSTUBBLE: PASS" / "FAIL". Any script error fails it. Waits on game time.

var main: Node
var player: Node
var step := 0
var t := 0.0
var failed := false
var results: Array[String] = []
var errors: ErrorCatcher
var runes_before := 0
var constructs_before := 0
var gathered_before := 0
var target_wisp: Node3D
var target_vestige: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	errors = ErrorCatcher.install()
	Engine.time_scale = 2.0
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
		print("NETHERSTUBBLE: " + line)
	print("NETHERSTUBBLE: %s" % ("FAIL" if failed else "PASS"))
	get_tree().quit(1 if failed else 0)


func _site_of(n: Node) -> String:
	return str(n.get_meta("site", ""))


func _process(_delta: float) -> void:
	t += _delta
	player = main.get("player")
	var nether: Netherecho = main.get("nether")
	match step:
		0:
			if t < 0.2:
				return
			main.call("start_new_character", 0)
			main.call("walk_out")
			var zb: ZoneBuilder = main.get("_zone")
			(player as Node3D).global_position = (main.get("level") as Node3D).to_global(zb.to_local(96.0, 74.0))
			_next()
		1:
			if t < 0.5:
				return
			_expect("the Stubble's echo is built from its data: the landmarks' echoes", get_tree().get_nodes_in_group("nether_echoes").size() == (GameData.zone("the_stubble")["nether"]["echoes"] as Array).size())
			var at_well: Array = get_tree().get_nodes_in_group("nether_wisps").filter(func(w: Node) -> bool: return _site_of(w) == "the_well")
			_expect("water wisps lie by the dry well", at_well.any(func(w: Node) -> bool: return str(w.get("affinity")) == "water"))
			var heap: Array = get_tree().get_nodes_in_group("nether_wisps").filter(func(w: Node) -> bool: return _site_of(w) == "the_heap")
			_expect("earth wisps at the dross heap", heap.any(func(w: Node) -> bool: return str(w.get("affinity")) == "earth"))
			var mine: Array = player.get("affinities")
			for w2: Node in at_well:
				if mine.has(str(w2.get("affinity"))):
					target_wisp = w2
			_expect("and one of your own there to gather", target_wisp != null, str(mine))
			for c: Node in get_tree().get_nodes_in_group("nether_enemies"):
				if _site_of(c) == "the_well" and str(c.get("tier")) == "vestige":
					target_vestige = c
			var wild: float = float(GameData.wild_construct("vestige")["hp"])
			_expect("the well's vestige is scaled for a new projection", target_vestige != null and (target_vestige.get("body") as Body).total_max() < wild,
				"%s" % str((target_vestige.get("body") as Body).total_max()) if target_vestige else "none")
			runes_before = (player.get("known_runes") as Array).size()
			constructs_before = (player.get("constructs") as Array).size()
			main.call("toggle_projection")
			_expect("you can project here (nothing awake near the well)", nether.active)
			gathered_before = nether.gathered_this_trip
			_next()
		2:
			if not nether.active:
				_expect("the trip lasts long enough to gather", false, "active %s, last note: %s" % [str(nether.active), str((player.get("log_lines") as Array).back())])
				_finish()
				return
			var proj: Node3D = nether.projection
			proj.set("input_blocked", true)
			if is_instance_valid(target_wisp) and target_wisp.is_in_group("nether_wisps"):
				proj.set("move_goal", target_wisp.global_position)
				proj.set("has_move_goal", true)
				if t < 8.0:
					return
			_expect("touch the wisp and it is gathered", nether.gathered_this_trip > gathered_before)
			_next()
		3:
			var proj2: Node3D = nether.projection
			if proj2 == null:
				_expect("the projection lives to fight the vestige", false, "projection %s vestige %s active %s note %s" % [str(proj2), str(target_vestige), str(nether.active), str((player.get("log_lines") as Array).back())])
				_finish()
				return
			if is_instance_valid(target_vestige) and not bool(target_vestige.call("is_dead")) and t < 20.0:
				proj2.set("attack_target", target_vestige)
				proj2.set("hp", float(proj2.get("hp_max")))       # keep it alive: this is about the reward, not the fight
				return
			_expect("beat the vestige down and it is subdued, yours to bind", (player.get("constructs") as Array).size() == constructs_before + 1)
			_expect("and it shows you a rune you did not know", (player.get("known_runes") as Array).size() > runes_before,
				"%d -> %d" % [runes_before, (player.get("known_runes") as Array).size()])
			main.call("toggle_projection")
			_expect("and you return to your body", not nether.active)
			_finish()
