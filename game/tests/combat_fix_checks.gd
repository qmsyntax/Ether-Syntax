class_name CombatFixChecks
extends RefCounted
## The self-test's checks for the combat review's approved fixes (design/combat-review-2026-11-03.md
## section 7; Brent 2026-11-03: "go ahead with 1, 3, 4, 5 and 6" = R1, Q1, Q2, R3, R4). One block per
## fix; each proves the rule as numbers and state, not how it feels. Called from selftest.gd
## (`-- --only=combat` runs it alone). It plays real physics frames where a rule runs over time.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const STEP := 1.0 / 60.0
const AT := Vector3(-1500, 0, 1500)           # well away from everything else the self-test builds

var t: Node                 # the self-test node (things are added under it)
var check: Callable         # its _check(label, ok, detail)
var _made: Array[Node] = []


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn


func run() -> void:
	print("the combat review's fixes (2026-11-03):")
	await t.get_tree().physics_frame
	await _gathering()
	await _shedding()
	_starters()
	for n: Node in _made:
		if is_instance_valid(n):
			n.queue_free()
	await t.get_tree().physics_frame


# --- helpers ------------------------------------------------------------------------------------

func _keep(n: Node) -> Node:
	_made.append(n)
	return n


## A character of one affinity with its whole kit, a baby tank (20) and `essence` in it.
func _player(aff: String, at: Vector3 = AT, essence: float = 0.0) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	p.position = at
	t.add_child(p)
	p.call("set_affinities", [aff])
	p.set("active", true)
	p.set("essence", essence)
	_keep(p)
	return p


func _foe(p: Node3D, offset: Vector3, hp: float = 100000.0) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", "grunt", p, 1.0)
	e.position = p.global_position + offset
	t.add_child(e)
	e.set("target", null)                    # never fights back
	e.set("poise_max", 100000.0)
	e.set("poise", 100000.0)
	(e.get("body") as Body).max_hp = hp
	(e.get("body") as Body).hp = hp
	_keep(e)
	return e


func _wait(seconds: float) -> void:
	for i: int in int(ceil(seconds / STEP)):
		await t.get_tree().physics_frame


func _lost(e: Node) -> float:
	return (e.get("body") as Body).max_hp - (e.get("body") as Body).hp


func _gone(n: Node) -> void:
	if n.get("active") != null:
		n.set("active", false)
	n.queue_free()


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


# --- R1: strikes gather essence -----------------------------------------------------------------

func _gathering() -> void:
	var c: Dictionary = GameData.balance["combat"]
	var gather: float = float(c.get("strike_gathers_essence", 0.0))
	check.call("balance.json combat has strike_gathers_essence, a small positive number, and its note says so",
		gather > 0.0 and gather <= 5.0 and str(c["_note"]).contains("strike_gathers_essence"))
	var p := _player("water", AT, 4.0)
	var e := _foe(p, Vector3(0, 0, -1.8))
	await _wait(STEP)
	p.call("_strike_target", e, 1.0, ["melee"])
	check.call("a landed bare strike gathers strike_gathers_essence", _lost(e) > 0.0 and _near(float(p.get("essence")), 4.0 + gather),
		"essence %f" % float(p.get("essence")))
	# a swing at nothing: the strike button with no foe in reach lands nothing and gathers nothing
	var before: float = float(p.get("essence"))
	e.global_position = p.global_position + Vector3(0, 0, -30)
	p.call("_release_overcharge")                # (no charge: does nothing - a guard that no stray swing gathers)
	p.set("_charge", float(GameData.num("player", "overcharge_min_charge")) + 0.01)
	p.set("_charging", true)
	p.call("_release_overcharge")                # an overcharged swing with nobody in reach
	check.call("a strike that misses gathers nothing", _near(float(p.get("essence")), before), "essence %f" % float(p.get("essence")))
	# scenery does not count, and a skill's melee hit is not a bare strike
	e.global_position = p.global_position + Vector3(0, 0, -1.8)
	var before2: float = float(p.get("essence"))
	p.call("deal_damage", e, 10.0, ["ability", "water", "tsunami_strike", "melee"])
	check.call("a skill's melee hit gathers nothing (only the bare strike does)", _near(float(p.get("essence")), before2))
	# never past the tank
	p.set("essence", float(p.get("essence_max")) - 0.5)
	p.call("_strike_target", e, 1.0, ["melee"])
	check.call("gathering never fills past the tank", _near(float(p.get("essence")), float(p.get("essence_max"))))
	_gone(p)
	_gone(e)


# --- Q1: cheaper, stronger starters -------------------------------------------------------------

## A starter's hit on its main target at stage 0, as Player._payload folds it.
static func starter_hit(ab: Dictionary) -> float:
	var oh: Dictionary = ab.get("on_hit", {})
	var strike: float = GameData.num("player", "melee_damage")
	if oh.has("damage"):
		return float(oh["damage"])
	if oh.has("damage_mult"):
		return float(oh["damage_mult"]) * strike
	if ab.has("damage"):
		return float(ab["damage"])
	return float(ab.get("damage_mult", 0.0)) * strike


## True when a skill's hit pulls its target in or taunts it: the role exception (ROLES-BRIEF: a tank's ranged
## starter can be a pull or a taunt), which may stay lighter than the damage floor.
static func pulls_or_taunts(ab: Dictionary) -> bool:
	var oh: Dictionary = ab.get("on_hit", {})
	if str(ab.get("mode", "")) == "pull_target" or float(oh.get("pull", 0.0)) > 0.0 or str(oh.get("status", "")) == "taunted":
		return true
	for st: Variant in oh.get("statuses", []):
		if st is Dictionary and str((st as Dictionary).get("id", "")) == "taunted":
			return true
	return false


func _starters() -> void:
	var floor_dmg: float = 1.5 * GameData.num("player", "melee_damage")
	var bad: Array[String] = []
	var light: Array[String] = []
	var n := 0
	for aff_v: Variant in GameData.affinity_ids():
		var aff: String = str(aff_v)
		var def: Dictionary = GameData.affinity(aff)
		if not def.has("kit"):
			continue
		var kit: Array = def["kit"]
		var ranged: Dictionary = GameData.ability(str(kit[0]))
		var close: Dictionary = GameData.ability(str(kit[1]))
		n += 1
		var rc: float = float(ranged["cost"])
		if rc < 4.0 or rc > 5.0:
			bad.append("%s ranged %s costs %s" % [aff, kit[0], rc])
		if starter_hit(ranged) < floor_dmg - 0.01:
			if pulls_or_taunts(ranged):
				light.append(str(kit[0]))
			else:
				bad.append("%s ranged %s hits for %s" % [aff, kit[0], starter_hit(ranged)])
		var cc: float = float(close["cost"])
		if cc < 6.0 or cc > 8.0:
			bad.append("%s close %s costs %s" % [aff, kit[1], cc])
	check.call("every affinity's ranged starter costs 4-5 and hits for at least 1.5x a bare strike, its close starter costs 6-8 (Q1, all %d)" % n,
		n == 18 and bad.is_empty(), str(bad))
	check.call("only a ranged starter whose hit pulls or taunts stays under the floor (the tank's exception)",
		light.size() <= 4 and not light.has("cinder_spit"), str(light))
	print("    lighter by role: %s" % ", ".join(light))


# --- Q2: reflux sheds faster in a fight ---------------------------------------------------------

func _shedding() -> void:
	var c: Dictionary = GameData.balance["combat"]
	var r: Dictionary = GameData.balance["reflux"]
	check.call("Q2's numbers: a landed strike sheds 3 reflux, a fight sheds 2 a second (were 1 and 0.5)",
		_near(float(c["strike_sheds_reflux"]), 3.0) and _near(float(r["shed_in_combat"]), 2.0) and str(r["_note"]).contains("shed_in_combat"))
	var p := _player("water", AT + Vector3(0, 0, 40), 10.0)
	var e := _foe(p, Vector3(0, 0, -1.8))
	await _wait(STEP)
	var mult: float = float((p.get("inventory") as Inventory).stat("reflux_shed_mult", true)) * float(p.call("temper_stat", "reflux_shed_mult"))
	p.call("start_fight")
	(p.get("reflux_by") as Dictionary)["water"] = 50.0
	var frames: int = 60
	for i: int in frames:
		await t.get_tree().physics_frame
	var want: float = 50.0 - float(r["shed_in_combat"]) * mult * float(frames) * STEP
	check.call("in a fight reflux sheds at reflux.shed_in_combat a second", _near(float(p.call("reflux_of", "water")), want, 0.15),
		"%f, want %f" % [float(p.call("reflux_of", "water")), want])
	var before: float = float(p.call("reflux_of", "water"))
	p.call("_strike_target", e, 1.0, ["melee"])
	check.call("a landed strike sheds combat.strike_sheds_reflux from the hottest affinity", _near(before - float(p.call("reflux_of", "water")), float(c["strike_sheds_reflux"]), 0.05),
		"shed %f" % (before - float(p.call("reflux_of", "water"))))
	p.call("end_fight")
	_gone(p)
	_gone(e)
