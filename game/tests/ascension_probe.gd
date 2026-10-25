extends Node
## Ascension click test (windowed run only - needs real GUI hit-testing):
##   godot --path game res://tests/ascension_probe.tscn
## Starts a real water character (two picked skills, Riptide Lash at stage 1), forces an ascension
## (a full star and the latent aura, then try_ascend - the same call the ascend key makes), and
## checks the ascension screen opened from the `ascended` signal with two affinities, the first a
## hybrid with Water as a parent. Clicks that affinity, then on the boost step clicks Reach for
## Riptide Lash and Essence for the other skill, and clicks Ascend. Checks: the affinity is held, no
## skill was given, each boost is in its aspect at the formula's amount, ability_stats shows them
## (Riptide Lash's range x(1 + boost), the other's cost / (1 + boost)), stage and bar unchanged,
## nothing pending; then the ethercosm shows the boost on the skill and the base in brackets.
## Prints "ASCEND: PASS" / "ASCEND: FAIL" and exits 0/1.

var main: Node
var frames := 0
var results: Array[String] = []
var failed := false
var _errors: ErrorCatcher
var _offer: Array = []
var _amounts: Array = []
var _base0: Dictionary = {}
var _base1: Dictionary = {}
var _stage0 := 0
var _progress0 := 0.0


func _ready() -> void:
	_errors = ErrorCatcher.install()
	process_mode = Node.PROCESS_MODE_ALWAYS
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)


func _click(c: Control) -> void:
	if c == null:
		return
	var at: Vector2 = c.get_global_rect().get_center()
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	get_viewport().push_input(mv)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_viewport().push_input(ev)


func _expect(label: String, ok: bool, detail: String = "") -> void:
	results.append("%s %s %s" % ["ok  " if ok else "FAIL", label, "" if ok else detail])
	if not ok:
		failed = true


func _find(n: String) -> Control:
	return main.find_child(n, true, false) as Control


func _process(_delta: float) -> void:
	frames += 1
	var player: Node = main.get("player")
	match frames:
		30:
			var why: String = main.call("begin_character", {"talent_id": "grudge", "affinities": ["water"], "skills": ["riptide_lash", "tsunami_strike"],
				"name": "Probe", "look": {}})
			_expect("a real water character starts with its two picked skills", why == "" and (player.get("abilities") as Array).size() == 2, why)
			var abs0: Array = player.get("abilities")
			(abs0[0] as Dictionary)["stage"] = 1
			(abs0[0] as Dictionary)["progress"] = 40.0
			_stage0 = 1
			_progress0 = 40.0
			_base0 = player.call("ability_stats", abs0[0])
			_base1 = player.call("ability_stats", abs0[1])
			(player.get("rng") as RandomNumberGenerator).seed = 20261024
			player.call("grow_star", 500.0)
			player.set("_latent_aura", 999999.0)
			player.call("try_ascend")
		40:
			var s: Node = main.get("screen")
			var pend: Dictionary = player.get("ascension_pending")
			_offer = pend.get("offer", [])
			_amounts = (pend.get("skills", []) as Array).map(func(b: Dictionary) -> float: return float(b["amount"]))
			_expect("ascending opens the ascension screen (the ascended signal), paused", s != null and s.get_script() == load("res://scripts/ui/ascension_screen.gd")
				and get_tree().paused and int(player.get("stars")) == 2)
			_expect("it offers two affinities, the first a hybrid with Water as a parent (Ice or Poison)", _offer.size() == 2 and ["ice", "poison"].has(str(_offer[0]))
				and not _offer.has("water"), str(_offer))
			var card: Control = _find("Offer_" + str(_offer[0])) if not _offer.is_empty() else null
			_expect("each choice is a card on screen, the hybrid naming its parents", card != null and card.is_visible_in_tree()
				and _find("Offer_" + str(_offer[1])) != null and (card.find_child("Kind", true, false) as Control) != null
				and str((card.find_child("Kind", true, false) as Node).get_child(0).get("text")) == "HYBRID OF")
			_expect("the boosts follow the formula: (P / 2) x (1 + a x stage)", _amounts.size() == 2
				and is_equal_approx(float(_amounts[0]), Ascension.amount(Ascension.pool(2), 2, 1, float(Ascension.cfg()["stage_weight"])))
				and is_equal_approx(float(_amounts[1]), Ascension.amount(Ascension.pool(2), 2, 0, float(Ascension.cfg()["stage_weight"]))), str(_amounts))
			_click(card)
		50:
			var s2: Node = main.get("screen")
			_expect("clicking the card takes it and goes on to the boosts", s2 != null and str(s2.get("step")) == "boost" and str(s2.get("chosen")) == str(_offer[0])
				and _find("BoostRow_0") != null and _find("BoostRow_1") != null)
			var main1: String = Ascension.main_aspect(player.call("ability_stats", (player.get("abilities") as Array)[1]))
			_expect("each skill's main aspect is preselected", str((s2.get("aspects") as Dictionary).get(1, "")) == main1, str(s2.get("aspects")))
			var reach: Control = _find("Aspect_0_reach")
			var prev: Label = reach.find_child("Preview", true, false) as Label if reach != null else null
			_expect("the Reach button shows what it would change, before -> after", prev != null and prev.text.contains("->"), prev.text if prev != null else "none")
			_click(reach)
		56:
			var s3: Node = main.get("screen")
			_expect("clicking Reach sets Riptide Lash's aspect", str((s3.get("aspects") as Dictionary).get(0, "")) == "reach", str(s3.get("aspects")))
			_click(_find("Aspect_1_cost"))
		62:
			var s4: Node = main.get("screen")
			_expect("clicking Essence sets the other skill's", str((s4.get("aspects") as Dictionary).get(1, "")) == "cost", str(s4.get("aspects")))
			_click(_find("AscendConfirm"))
		72:
			var abs1: Array = player.get("abilities")
			var a0: Dictionary = abs1[0]
			var a1: Dictionary = abs1[1]
			_expect("Ascend settles it: the screen closes, nothing pending, the game runs again", not (main.get("screen") != null and main.get("screen").get_script() == load("res://scripts/ui/ascension_screen.gd"))
				and (player.get("ascension_pending") as Dictionary).is_empty() and not get_tree().paused)
			_expect("the chosen affinity is held, and no skill was given", (player.get("affinities") as Array) == ["water", str(_offer[0])] and abs1.size() == 2,
				"%s %d" % [str(player.get("affinities")), abs1.size()])
			_expect("each boost is saved on its skill in its aspect", is_equal_approx(float((a0.get("ascension", {}) as Dictionary).get("reach", 0.0)), float(_amounts[0]))
				and is_equal_approx(float((a1.get("ascension", {}) as Dictionary).get("cost", 0.0)), float(_amounts[1])), "%s %s" % [str(a0.get("ascension")), str(a1.get("ascension"))])
			var s0: Dictionary = player.call("ability_stats", a0)
			var s1: Dictionary = player.call("ability_stats", a1)
			_expect("ability_stats: Riptide Lash's range x(1 + boost), damage untouched", absf(float(s0["range"]) - float(_base0["range"]) * (1.0 + float(_amounts[0]))) < 0.0001
				and is_equal_approx(float(s0["on_hit"]["damage"]), float(_base0["on_hit"]["damage"])), "%s vs %s" % [str(s0["range"]), str(_base0["range"])])
			_expect("ability_stats: the other skill's cost / (1 + boost)", absf(float(s1["cost"]) - float(_base1["cost"]) / (1.0 + float(_amounts[1]))) < 0.0001,
				"%s vs %s" % [str(s1["cost"]), str(_base1["cost"])])
			_expect("not levelling: stage and bar unchanged", int(a0["stage"]) == _stage0 and is_equal_approx(float(a0["progress"]), _progress0))
			main.call("open_ethercosm")
			main.get("screen").call("select", 0)
		80:
			var boosts: Label = _find("AscensionBoosts") as Label
			_expect("the ethercosm shows the boost on the skill", boosts != null and boosts.text.begins_with("Ascension: +") and boosts.text.contains("reach"),
				boosts.text if boosts != null else "none")
			var rows: Node = _find("SkillDetailRows")
			var flight: Node = rows.find_child("Row_Range", true, false) if rows != null else null
			var idx: int = flight.get_index() if flight != null else -1
			var val_box: Node = rows.get_child(idx + 1) if idx >= 0 else null
			_expect("and its 'What it does' table shows the boosted range with the base in brackets", val_box != null and val_box.find_child("Base", true, false) != null)
			main.call("close_screen")
		86:
			_expect("no script error was raised", _errors.count() == 0, "%d, first: %s" % [_errors.count(), _errors.first()])
			for r: String in results:
				print("  " + r)
			print("ASCEND: %s" % ("FAIL" if failed else "PASS"))
			get_tree().quit(1 if failed else 0)
