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
	p.queue_free()
