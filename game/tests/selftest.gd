extends Node
## Headless rules self-test. Run:
##   godot --headless --path game res://tests/selftest.tscn
## Exercises wound maths, natural healing, arm loss/regrowth, healer credit and rent directly,
## because the auto-play smoke check never touches them. Proves the rules compute as specified;
## proves nothing about feel or balance.

const PlayerScript := preload("res://scripts/player.gd")

var _failed := 0
var _passed := 0


func _ready() -> void:
	_test_body()
	_test_natural_healing()
	_test_arm_loss_and_regrowth()
	_test_healer_credit_and_rent()
	_test_death_and_rest()
	_test_keybinds()
	_test_pipeline()
	print("SELFTEST: %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(1 if _failed > 0 else 0)


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		_passed += 1
		print("  ok   %s" % label)
	else:
		_failed += 1
		print("  FAIL %s %s" % [label, detail])


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func _new_player(talent: String = "") -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	add_child(p)
	if talent != "":
		p.call("set_talent", talent)
	p.set("active", true)
	return p


func _test_body() -> void:
	print("body:")
	var b := Body.new(60.0, 30.0, 10.0)
	var applied: float = b.apply_damage(70.0)
	_check("damage spills superficial -> structural", _near(float(b.hp["superficial"]), 0.0) and _near(float(b.hp["structural"]), 20.0))
	_check("reports damage applied", _near(applied, 70.0))
	applied = b.apply_damage(500.0)
	_check("no overkill: applied capped at remaining", _near(applied, 30.0), "got %f" % applied)
	_check("dead at zero", b.is_dead())

	var sup := Body.new(60.0, 30.0, 10.0)
	sup.apply_damage(80.0)  # superficial 0, structural 10, catastrophic 10
	var used: float = sup.heal(5.0, false)
	_check("supreme: 1 point = 1 HP, worst layer first", _near(float(sup.hp["structural"]), 15.0) and _near(used, 5.0))
	var dyn := Body.new(60.0, 30.0, 10.0)
	dyn.apply_damage(80.0)
	dyn.heal(3.0, true)     # 2 pts -> 20 structural (full), 1 pt -> up to 100 superficial (caps at 60)
	_check("dynamic: 10x structural, 100x superficial", _near(float(dyn.hp["structural"]), 30.0) and _near(float(dyn.hp["superficial"]), 60.0),
		"struct %f sup %f" % [float(dyn.hp["structural"]), float(dyn.hp["superficial"])])


func _test_natural_healing() -> void:
	print("natural healing:")
	var p := _new_player()
	var b: Body = p.get("body")
	b.apply_damage(85.0)                    # superficial 0, structural 5, catastrophic 10
	b.damage_layer("catastrophic", 6.0)     # catastrophic 4
	p.set("in_combat", true)
	for i: int in 5:
		p.call("_physics_process", 1.0)
	_check("none while in combat", _near(float(b.hp["superficial"]), 0.0) and _near(float(b.hp["structural"]), 5.0))
	p.set("in_combat", false)
	for i: int in 10:
		p.call("_physics_process", 1.0)
	_check("superficial recovers at rest", _near(float(b.hp["superficial"]), 30.0), "got %f" % float(b.hp["superficial"]))
	_check("structural recovers slowly at rest", _near(float(b.hp["structural"]), 9.0), "got %f" % float(b.hp["structural"]))
	_check("catastrophic never recovers naturally", _near(float(b.hp["catastrophic"]), 4.0), "got %f" % float(b.hp["catastrophic"]))
	p.queue_free()


func _overcharge(p: Node) -> void:
	p.set("_charge", 2.0)
	p.set("_charging", true)
	p.call("_release_overcharge")


func _test_arm_loss_and_regrowth() -> void:
	print("arm:")
	var p := _new_player("one_percent_lifesteal")
	p.set("in_combat", true)
	var b: Body = p.get("body")
	_overcharge(p)
	_check("one full overcharge wears the arm", float(p.get("arm_right")) < 100.0 and not bool(p.get("arm_right_lost")), "arm %f" % float(p.get("arm_right")))
	_overcharge(p)
	_check("repeated overcharge destroys the arm", bool(p.get("arm_right_lost")))
	_check("losing the arm is catastrophic damage", float(b.hp["catastrophic"]) < 10.0, "cat %f" % float(b.hp["catastrophic"]))

	p.set("in_combat", false)
	for i: int in 30:
		p.call("_physics_process", 1.0)
	_check("rest never regrows a lost arm", bool(p.get("arm_right_lost")))

	var cat_gap: float = b.missing("catastrophic")
	p.call("_spend_heal_points", cat_gap + 24.0)
	_check("talent heals catastrophic first, arm not yet regrown", _near(b.missing("catastrophic"), 0.0) and bool(p.get("arm_right_lost")))
	p.call("_spend_heal_points", 2.0)
	_check("talent regrows the arm once enough points are spent", not bool(p.get("arm_right_lost")) and float(p.get("arm_right")) > 0.0)
	p.queue_free()


func _test_healer_credit_and_rent() -> void:
	print("healer / debt / rent:")
	var p := _new_player()
	p.set("arm_right_lost", true)
	p.set("arm_right", 0.0)
	p.set("money", 0)
	p.call("buy_healing")
	_check("healer regrows an arm on credit", not bool(p.get("arm_right_lost")) and int(p.get("money")) == -1200, "money %d" % int(p.get("money")))
	p.set("arm_right_lost", true)
	p.call("buy_healing")
	_check("credit limit refuses a second arm", bool(p.get("arm_right_lost")) and int(p.get("money")) == -1200, "money %d" % int(p.get("money")))
	p.call("charge", 50)
	_check("rent pushes further into debt", int(p.get("money")) == -1250)
	_check("town refuses a ticket past the credit limit", not bool(p.call("can_afford", 800)) and bool(p.call("can_afford", 700)))
	p.queue_free()


const EnemyScript := preload("res://scripts/enemy.gd")


func _dummy_enemy(p: Node3D) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	add_child(e)
	e.call("setup", "brute", p, 1.0)
	e.set("target", null)      # never fights back on its own
	e.global_position = p.global_position + Vector3(0, 0, -1.5)
	return e


func _test_pipeline() -> void:
	print("hook pipeline:")
	for id: String in ["one_percent_lifesteal", "tenth_strike", "grudge", "glass_hour", "debt_of_pain", "furnace_gut"]:
		var q := _new_player(id)
		_check("effect loads for %s" % id, (q.get("effects") as Array).size() == 1)
		q.queue_free()

	var p := _new_player("tenth_strike")
	var e := _dummy_enemy(p)
	var eb: Body = e.get("body")
	for i: int in 10:
		p.call("deal_damage", e, 1.0, ["melee"])
	_check("tenth strike: 9 x1 + 1 x5 = 14", _near(eb.missing("superficial"), 14.0), "got %f" % eb.missing("superficial"))
	e.queue_free()
	p.queue_free()

	p = _new_player("glass_hour")
	e = _dummy_enemy(p)
	eb = e.get("body")
	p.call("start_fight")
	var ctx: HitContext = p.call("deal_damage", e, 10.0, ["melee"])
	_check("glass hour: x3 outgoing in the window", _near(ctx.applied, 30.0), "got %f" % ctx.applied)
	var pb: Body = p.get("body")
	p.call("take_hit", 5.0, false, e)
	_check("glass hour: x3 incoming in the window", _near(pb.missing("superficial"), 15.0), "got %f" % pb.missing("superficial"))
	p.set("fight_time", 10.0)
	ctx = p.call("deal_damage", e, 10.0, ["melee"])
	_check("glass hour: normal after the window", _near(ctx.applied, 10.0))
	e.queue_free()
	p.queue_free()

	p = _new_player("grudge")
	e = _dummy_enemy(p)
	for i: int in 3:
		p.call("take_hit", 1.0, false, e)
	ctx = p.call("deal_damage", e, 100.0, ["melee"])
	_check("grudge: +2% per hit taken from that enemy", _near(ctx.applied, 106.0), "got %f" % ctx.applied)
	e.queue_free()
	p.queue_free()

	p = _new_player("debt_of_pain")
	pb = p.get("body")
	p.call("start_fight")      # no natural healing while the debt is outstanding
	var returned: float = p.call("take_hit", 10.0, false, null)
	_check("debt: the hit is swallowed for now", _near(returned, 0.0) and _near(pb.missing("superficial"), 0.0))
	_check("debt: notebook shows what is owed", (p.call("status_lines") as Array).size() == 1)
	for i: int in 6:
		p.call("_physics_process", 1.0)
	_check("debt: 80% arrives after 5 s", _near(pb.missing("superficial"), 8.0), "got %f" % pb.missing("superficial"))
	p.queue_free()

	p = _new_player("furnace_gut")
	p.set("reflux", 99.0)
	p.set("essence", 100.0)
	p.call("cast_bolt")
	_check("furnace gut: cap vents to 50 instead of locking", not bool(p.get("reflux_locked")) and _near(float(p.get("reflux")), 50.0), "reflux %f" % float(p.get("reflux")))
	p.queue_free()

	p = _new_player("tenth_strike")
	p.set("reflux", 99.0)
	p.call("cast_bolt")
	_check("without furnace gut the cap locks the affinity", bool(p.get("reflux_locked")))
	p.queue_free()


func _test_keybinds() -> void:
	print("keybinds:")
	Keybinds.reset_defaults()
	_check("defaults registered", Keybinds.binding_text("bolt") == "Q" and Keybinds.binding_text("strike") == "LMB")
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	var displaced: String = Keybinds.rebind("bolt", g)
	_check("rebind changes the binding", Keybinds.binding_text("bolt") == "G" and displaced == "")
	var displaced2: String = Keybinds.rebind("ascend", g)
	_check("a key held by another action is taken from it", displaced2 == "bolt" and Keybinds.binding_text("bolt") == "(none)" and Keybinds.binding_text("ascend") == "G")
	var mmb := InputEventMouseButton.new()
	mmb.button_index = MOUSE_BUTTON_MIDDLE
	Keybinds.rebind("meditate", mmb)
	_check("mouse buttons bind too", Keybinds.binding_text("meditate") == "MMB")
	Keybinds.call("_load")
	_check("bindings survive a save/load round trip", Keybinds.binding_text("ascend") == "G" and Keybinds.binding_text("meditate") == "MMB")
	Keybinds.reset_defaults()
	_check("reset restores defaults", Keybinds.binding_text("bolt") == "Q" and Keybinds.binding_text("ascend") == "T" and Keybinds.binding_text("meditate") == "M")


func _test_death_and_rest() -> void:
	print("death into debt / night's rest:")
	var p := _new_player()
	var b: Body = p.get("body")
	p.set("money", 100)
	p.set("arm_right_lost", true)
	b.apply_damage(1000.0)
	p.set("dead", true)
	p.call("revive_in_debt", 600)
	_check("revived character is alive", not bool(p.get("dead")) and not b.is_dead())
	_check("the rescue fee is charged with no credit check", int(p.get("money")) == -500, "money %d" % int(p.get("money")))
	_check("patched up, not healed", _near(float(b.hp["superficial"]), 30.0) and _near(float(b.hp["structural"]), 12.0) and _near(float(b.hp["catastrophic"]), 2.0),
		"%f / %f / %f" % [float(b.hp["superficial"]), float(b.hp["structural"]), float(b.hp["catastrophic"])])
	_check("a lost arm stays lost through rescue", bool(p.get("arm_right_lost")))
	p.call("rest_night")
	_check("a night's rest closes cuts and knits some bone", _near(float(b.hp["superficial"]), 60.0) and _near(float(b.hp["structural"]), 27.0))
	_check("a night's rest restores nothing catastrophic, and no arm", _near(float(b.hp["catastrophic"]), 2.0) and bool(p.get("arm_right_lost")))
	p.queue_free()
