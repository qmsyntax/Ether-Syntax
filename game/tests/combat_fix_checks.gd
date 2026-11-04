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
	await _sidestep()
	await _refusals()
	await _walk_in()
	await _lead()
	await _own_stone()
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


# --- R3: the free sidestep ----------------------------------------------------------------------

func _sidestep() -> void:
	var s: Dictionary = GameData.balance.get("sidestep", {})
	var dist: float = float(s.get("distance_m", 0.0))
	check.call("balance.json sidestep: a short step (2.5-3 m), priced in reflux, with a note",
		dist >= 2.5 and dist <= 3.0 and float(s.get("reflux", 0.0)) > 0.0 and str(s.get("_note", "")).contains("NOT invulnerable"))
	check.call("the sidestep has its own key, Space by default, and no other action shares it",
		Keybinds.binding_text("sidestep") == "Space" and _shared_defaults().is_empty(), str(_shared_defaults()))
	var p := _player("water", AT + Vector3(0, 0, 80), 10.0)
	var hitter := _foe(p, Vector3(40, 0, 0))
	await _wait(STEP)
	var from: Vector3 = p.global_position
	p.set("cursor_fixed", from + Vector3(8, 0, 0))     # step toward the cursor (no move key held)
	p.call("press_sidestep")
	check.call("pressed when free, the step starts at once", int(p.get("sidesteps")) == 1 and float(p.get("_dash_time")) > 0.0)
	check.call("it costs reflux, not essence", _near(float(p.get("essence")), 10.0) and _near(float(p.call("reflux_of", "water")), float(s["reflux"])),
		"essence %f reflux %f" % [float(p.get("essence")), float(p.call("reflux_of", "water"))])
	await _wait(STEP * 2.0)
	var hp0: float = (p.get("body") as Body).total()
	p.call("take_hit", 6.0, false, hitter)
	check.call("it is not invulnerable: a blow mid-step lands", float(p.get("_dash_time")) > 0.0 and (p.get("body") as Body).total() < hp0)
	await _wait(float(s["time_s"]) + STEP * 2.0)
	var moved: Vector3 = p.global_position - from
	check.call("it moves its distance, exactly, toward the cursor", _near(moved.length(), dist, 0.05) and moved.normalized().dot(Vector3(1, 0, 0)) > 0.99,
		"moved %s" % str(moved))
	check.call("one step does not wind you", float(p.get("_winded_t")) <= 0.0)
	# a second in quick succession: Winded; the third pays double
	await _wait(float(s["recovery_s"]) + STEP)
	p.call("press_sidestep")
	check.call("the second step in quick succession leaves you Winded", int(p.get("sidesteps")) == 2 and float(p.get("_winded_t")) > 0.0)
	await _wait(float(s["time_s"]) + float(s["recovery_s"]) + STEP * 2.0)
	var heat0: float = float(p.call("reflux_of", "water"))
	p.call("press_sidestep")
	check.call("... and a step taken Winded costs winded_cost_mult the heat", int(p.get("sidesteps")) == 3 and
		_near(float(p.call("reflux_of", "water")) - heat0, float(s["reflux"]) * GameData.num("combat", "winded_cost_mult"), 0.05),
		"heat %f" % (float(p.call("reflux_of", "water")) - heat0))
	# pressed while busy, it waits like a hotbar key
	await _wait(float(s["time_s"]) + float(s["recovery_s"]) + STEP * 2.0)
	p.set("_recover_t", 0.15)
	p.call("press_sidestep")
	check.call("pressed during a recovery it does not step yet", int(p.get("sidesteps")) == 3)
	await _wait(0.2)
	check.call("... and steps the moment you are free (feel.input_buffer_s)", int(p.get("sidesteps")) == 4)
	# every affinity locked: no step
	await _wait(float(s["time_s"]) + float(s["recovery_s"]) + STEP * 2.0)
	(p.get("locked_by") as Dictionary)["water"] = true
	check.call("with every affinity locked by reflux you cannot step", str(p.call("sidestep")) == "locked" and int(p.get("sidesteps")) == 4)
	(p.get("locked_by") as Dictionary)["water"] = false
	p.set("cursor_fixed", null)
	_gone(p)
	# two affinities: the coolest unlocked one takes the heat
	var d := _player("fire", AT + Vector3(0, 0, 120), 10.0)
	d.call("set_affinities", ["fire", "water"])
	(d.get("reflux_by") as Dictionary)["fire"] = 40.0
	await _wait(STEP)
	d.call("sidestep")
	check.call("with two affinities the step heats the cooler one", _near(float(d.call("reflux_of", "water")), float(s["reflux"]), 0.1) and float(d.call("reflux_of", "fire")) <= 40.0)
	_gone(d)
	# no affinity at all: the step is free, and Winded refuses it
	var n := _player("water", AT + Vector3(0, 0, 160), 10.0)
	n.set("affinities", [] as Array[String])
	await _wait(STEP)
	n.call("sidestep")
	await _wait(float(s["time_s"]) + float(s["recovery_s"]) + STEP * 2.0)
	n.call("sidestep")
	await _wait(float(s["time_s"]) + float(s["recovery_s"]) + STEP * 2.0)
	check.call("with no affinity held a step costs nothing, and once Winded it is refused", int(n.get("sidesteps")) == 2 and str(n.call("sidestep")) == "winded"
		and _near(float(n.get("essence")), 10.0))
	_gone(n)
	_gone(hitter)


# --- R4d: a refusal you can see -----------------------------------------------------------------

func _refusals() -> void:
	var h: Dictionary = GameData.balance["hud"]
	check.call("balance.json hud has refusal_show_s and refusal_flash_s, with a note",
		float(h.get("refusal_show_s", 0.0)) > 0.0 and float(h.get("refusal_flash_s", 0.0)) > 0.0 and str(h["_note"]).contains("refusal_show_s"))
	var p := _player("water", AT + Vector3(0, 0, 200), 0.0)
	p.call("set_talent", "one_percent_lifesteal")
	var heard: Array = []
	p.connect("cast_refused", func(slot: int, reason: String, text: String) -> void: heard.append([slot, reason, text]))
	var hud: Control = load("res://scripts/hud.gd").new()
	t.add_child(hud)
	_keep(hud)
	hud.call("refresh", p, "")
	hud.call("_process", STEP)
	await _wait(STEP)
	p.call("press_slot", 1)                       # Breaker with an empty tank
	var r: Dictionary = p.get("last_refusal")
	check.call("a refused cast records its slot and reason (no essence)", str(r.get("reason", "")) == "essence" and int(r.get("slot", -1)) == 1 and str(r.get("text", "")) != "",
		str(r))
	check.call("... and says so (the cast_refused signal)", heard.size() == 1 and int(heard[0][0]) == 1 and str(heard[0][1]) == "essence")
	hud.call("_process", STEP)
	check.call("the HUD takes it up: the slot flashes and the reason shows at the cursor", str((hud.get("_refusal") as Dictionary).get("reason", "")) == "essence"
		and float(hud.get("_refusal_age")) < float(h["refusal_flash_s"]))
	for i: int in int(ceil(float(h["refusal_show_s"]) / STEP)) + 2:
		hud.call("_process", STEP)
	check.call("... for refusal_show_s, then it is gone", float(hud.get("_refusal_age")) > float(h["refusal_show_s"]))
	# locked: the reason names the meditate key as it is bound now
	p.set("essence", 20.0)
	(p.get("locked_by") as Dictionary)["water"] = true
	p.call("press_slot", 0)
	r = p.get("last_refusal")
	check.call("locked by reflux: the reason names the meditate key (Keybinds-aware)", str(r.get("reason", "")) == "locked"
		and str(r.get("text", "")).contains("[%s]" % Keybinds.binding_text("meditate")), str(r))
	(p.get("locked_by") as Dictionary)["water"] = false
	# no target at all, and one out of reach
	p.call("cast_slot", 0)                         # Riptide Lash, nobody near (the rest of the self-test may leave foes far off)
	var anyone := false
	for n: Node in t.get_tree().get_nodes_in_group("enemies"):
		anyone = anyone or not bool(n.call("is_dead"))
	check.call("nobody to aim at: 'no target' (or 'out of reach' while another test's foe stands far off)",
		str((p.get("last_refusal") as Dictionary).get("reason", "")) == ("out_of_reach" if anyone else "no_target"))
	var far := _foe(p, Vector3(0, 0, -20))
	p.call("cast_slot", 0)                         # Riptide Lash reaches 10 m
	check.call("someone past the skill's reach: 'out of reach'", str((p.get("last_refusal") as Dictionary).get("reason", "")) == "out_of_reach")
	var serial: int = int((p.get("last_refusal") as Dictionary)["serial"])
	p.call("cast_slot", 0)
	check.call("each refusal is new to the HUD (its serial counts up)", int((p.get("last_refusal") as Dictionary)["serial"]) == serial + 1)
	_gone(far)
	_gone(p)


# --- R4a: close skills walk you in ----------------------------------------------------------------

func _full(p: Node) -> void:
	p.set("star_pct", [99.0] as Array[float])
	p.call("_recompute_essence_max")
	p.set("essence", float(p.get("essence_max")))


func _walk_in() -> void:
	var f: Dictionary = GameData.balance["feel"]
	check.call("balance.json feel has the walk-in knobs, with a note", float(f.get("skill_walk_in_max_m", 0.0)) > 3.0
		and float(f.get("skill_walk_in_max_s", 0.0)) > 0.0 and str(f["_note"]).contains("skill_walk_in_max_m"))
	# a targeted close skill (Kiln Fist) pressed with its foe 5 m off: walk, then cast
	var p := _player("fire", AT + Vector3(0, 0, 240))
	_full(p)
	var e := _foe(p, Vector3(0, 0, -5.0))
	p.set("cursor_fixed", e.global_position)
	await _wait(STEP)
	var e0: float = float(p.get("essence"))
	var at: Vector3 = p.global_position
	p.call("press_slot", 1)
	check.call("a close skill pressed out of reach is not refused: you walk in, and nothing is spent yet",
		bool(p.call("walking_to_cast")) and _near(float(p.get("essence")), e0) and str((p.get("last_refusal") as Dictionary).get("reason", "")) == "")
	for i: int in 120:
		await t.get_tree().physics_frame
		if not bool(p.call("walking_to_cast")):
			break
	check.call("... and it is cast the moment you are in reach (Kiln Fist lands)", _lost(e) > 0.0 and float(p.get("essence")) < e0
		and p.global_position.distance_to(at) > 1.0, "lost %f moved %f" % [_lost(e), p.global_position.distance_to(at)])
	_gone(p)
	_gone(e)
	# a melee burst (Breaker) with its foe out of the sweep: walk, then sweep
	var w := _player("water", AT + Vector3(0, 0, 280))
	_full(w)
	var g := _foe(w, Vector3(0, 0, -6.0))
	w.set("cursor_fixed", g.global_position)
	await _wait(STEP)
	w.call("press_slot", 1)
	var walking: bool = bool(w.call("walking_to_cast"))
	for i: int in 120:
		await t.get_tree().physics_frame
		if not bool(w.call("walking_to_cast")):
			break
	check.call("a melee burst whose foe is out of the sweep walks you in and then sweeps it", walking and _lost(g) > 0.0, "lost %f" % _lost(g))
	_gone(w)
	_gone(g)
	# any other input drops it: a move key, another press, the sidestep, a click
	var q := _player("fire", AT + Vector3(0, 0, 320))
	_full(q)
	var h := _foe(q, Vector3(0, 0, -6.0))
	q.set("cursor_fixed", h.global_position)
	await _wait(STEP)
	var e1: float = float(q.get("essence"))
	q.call("press_slot", 1)
	Input.action_press("move_left")
	await _wait(STEP * 2.0)
	Input.action_release("move_left")
	check.call("a move key drops the walk-in, and nothing is spent", not bool(q.call("walking_to_cast")) and _near(float(q.get("essence")), e1) and _lost(h) <= 0.0)
	await _wait(STEP * 2.0)
	h.global_position = q.global_position + Vector3(0, 0, -6.0)
	q.call("press_slot", 1)
	var was_walking: bool = bool(q.call("walking_to_cast"))
	q.call("press_sidestep")
	check.call("so does the sidestep", was_walking and not bool(q.call("walking_to_cast")))
	await _wait(0.4)
	h.global_position = q.global_position + Vector3(0, 0, -6.0)
	q.call("press_slot", 1)
	was_walking = bool(q.call("walking_to_cast"))
	q.call("_strike_clicked")
	check.call("so does a click", was_walking and not bool(q.call("walking_to_cast")))
	# beyond skill_walk_in_max_m it is refused as out of reach; cast_slot (tests, bots) never walks
	await _wait(0.2)
	h.global_position = q.global_position + Vector3(0, 0, -(float(f["skill_walk_in_max_m"]) + 2.0))
	q.call("press_slot", 1)
	check.call("a foe past skill_walk_in_max_m: refused, out of reach", not bool(q.call("walking_to_cast"))
		and str((q.get("last_refusal") as Dictionary).get("reason", "")) == "out_of_reach", "%s rec %.2f stag %.2f wind %.2f dash %.2f held %s" % [str(q.get("last_refusal")), float(q.get("_recover_t")), float(q.get("_stagger_t")), float(q.get("_windup_t")), float(q.get("_dash_time")), str(q.get("_held"))])
	h.global_position = q.global_position + Vector3(0, 0, -5.0)
	q.call("cast_slot", 1)
	check.call("cast_slot (tests, bots) still refuses outright and never walks", not bool(q.call("walking_to_cast"))
		and str((q.get("last_refusal") as Dictionary).get("reason", "")) == "out_of_reach", "%s rec %.2f stag %.2f wind %.2f dash %.2f held %s" % [str(q.get("last_refusal")), float(q.get("_recover_t")), float(q.get("_stagger_t")), float(q.get("_windup_t")), float(q.get("_dash_time")), str(q.get("_held"))])
	_gone(q)
	_gone(h)


# --- R4b: slow shots lead their foe ---------------------------------------------------------------

## Cast slot `slot` and fly its shot by hand while `foe` walks at `vel`; true if the shot hit it.
func _shot_hits(p: Node3D, slot: int, foe: CharacterBody3D, vel: Vector3) -> bool:
	foe.set_physics_process(false)
	foe.velocity = vel
	var before: Array[Node] = t.get_children()
	p.call("cast_slot", slot)
	var bolt: Node = null
	for n: Node in t.get_children():
		if not before.has(n) and n.get("shooter") == p:
			bolt = n
	if bolt == null:
		return false
	var hp0: float = (foe.get("body") as Body).hp
	for i: int in 180:
		if not is_instance_valid(bolt) or bolt.is_queued_for_deletion():
			break
		foe.global_position += vel * STEP
		bolt.call("tick", STEP)
	return (foe.get("body") as Body).hp < hp0


func _lead() -> void:
	var sk: Dictionary = GameData.balance["skills"]
	check.call("balance.json skills has the slow-shot lead knobs, with a note", float(sk.get("slow_shot_speed", 0.0)) > 0.0
		and float(sk.get("slow_shot_turn_max_deg", 0.0)) > 0.0 and str(sk["_note"]).contains("slow_shot_speed"))
	var blot: Dictionary = GameData.ability("blot")
	check.call("Blot (18 m/s) is a slow shot; Cinder Spit (24 m/s) is not", float(blot["speed"]) < float(sk["slow_shot_speed"])
		and float(GameData.ability("cinder_spit")["speed"]) >= float(sk["slow_shot_speed"]))
	var p := _player("dark", AT + Vector3(0, 0, 360))
	_full(p)
	var e := _foe(p, Vector3(0, 0, -9.0))
	p.set("cursor_fixed", e.global_position)
	await _wait(STEP)
	var walk := Vector3(3.0, 0, 0)                 # it walks across your line at 3 m/s
	check.call("a slow shot leads a foe walking across its line, and hits it", _shot_hits(p, 0, e, walk))
	# the same shot with the lead turned off misses: the lead is what made it land
	e.global_position = p.global_position + Vector3(0, 0, -9.0)
	p.set("_recover_t", 0.0)
	var keep: float = float(sk["slow_shot_speed"])
	sk["slow_shot_speed"] = 0.0
	var unled: bool = _shot_hits(p, 0, e, walk)
	sk["slow_shot_speed"] = keep
	check.call("... where the same shot, unled, flies past it", not unled)
	# a foe standing still: straight at it; a foe off to the side: not chased past the cone
	e.global_position = p.global_position + Vector3(0, 0, -9.0)
	e.velocity = Vector3.ZERO
	var dir: Vector3 = p.call("lead_aim", blot, Vector3(0, 0, -1))
	check.call("a still foe on the line: the shot goes straight", dir.angle_to(Vector3(0, 0, -1)) < 0.01)
	e.global_position = p.global_position + Vector3(6.0, 0, -6.0)
	e.velocity = Vector3(0, 0, 3.0)
	dir = p.call("lead_aim", blot, Vector3(0, 0, -1))
	check.call("a foe 45 degrees off your aim is not chased (slow_shot_cone_deg)", dir.angle_to(Vector3(0, 0, -1)) < 0.01)
	e.global_position = p.global_position + Vector3(0, 0, -9.0)
	e.velocity = Vector3(30.0, 0, 0)
	dir = p.call("lead_aim", blot, Vector3(0, 0, -1))
	check.call("the turn is at most slow_shot_turn_max_deg (a little)", rad_to_deg(dir.angle_to(Vector3(0, 0, -1))) <= float(sk["slow_shot_turn_max_deg"]) + 0.1)
	var fast: Vector3 = p.call("lead_aim", GameData.ability("cinder_spit"), Vector3(0, 0, -1))
	check.call("a fast shot is not led", fast.angle_to(Vector3(0, 0, -1)) < 0.01)
	p.set("cursor_fixed", null)
	_gone(p)
	_gone(e)


# --- R4c: your own stone does not stop your shots ------------------------------------------------

func _stone_at(owner: Node3D, at: Vector3) -> Node3D:
	var st: Node3D = owner.call("raise_stone", at, Vector3(0, 0, -1), GameData.ability("raise_slab"))
	st.call("tick", 0.6)                           # risen: solid, on layer 1
	return st


func _own_stone() -> void:
	var p := _player("dark", AT + Vector3(0, 0, 420))
	_full(p)
	var e := _foe(p, Vector3(0, 0, -9.0))
	e.set_physics_process(false)
	p.set("cursor_fixed", e.global_position)
	var mine: Node3D = _stone_at(p, p.global_position + Vector3(0, 0, -4.5))
	await _wait(STEP * 3.0)
	check.call("your own risen stone stands between you and the foe", is_instance_valid(mine) and bool(mine.call("is_up")))
	check.call("your shot passes your own stone and hits the foe behind it", _shot_hits(p, 0, e, Vector3.ZERO))
	check.call("... and the stone still stands (a plain shot does not break it)", is_instance_valid(mine) and not mine.is_queued_for_deletion())
	# a skill that asks to stop at your stone still does
	var blot: Dictionary = GameData.ability("blot")
	blot["stops_at_own_stone"] = true
	p.set("_recover_t", 0.0)
	var stopped: bool = not _shot_hits(p, 0, e, Vector3.ZERO)
	blot.erase("stops_at_own_stone")
	check.call("a skill with stops_at_own_stone is stopped by it, as before", stopped)
	# someone else's stone still blocks your shot
	mine.call("crumble")
	var other := _player("earth", AT + Vector3(30, 0, 420))
	var theirs: Node3D = _stone_at(other, p.global_position + Vector3(0, 0, -4.5))
	await _wait(STEP * 3.0)
	p.set("_recover_t", 0.0)
	check.call("a stone that is not yours still stops your shot", is_instance_valid(theirs) and not _shot_hits(p, 0, e, Vector3.ZERO))
	theirs.call("crumble")
	_gone(other)
	_gone(p)
	# a beam: Dayline through your own stone
	var l := _player("light", AT + Vector3(60, 0, 420))
	_full(l)
	var f := _foe(l, Vector3(0, 0, -9.0))
	f.set_physics_process(false)
	l.set("cursor_fixed", f.global_position)
	var ls: Node3D = _stone_at(l, l.global_position + Vector3(0, 0, -4.5))
	await _wait(STEP * 3.0)
	l.call("cast_slot", 0)
	check.call("a beam (Dayline) passes your own stone too", _lost(f) > 0.0, "lost %f" % _lost(f))
	ls.call("crumble")
	# Slingstone (asks to shatter your stone): it breaks it and flies on to the foe behind
	var s := _player("earth", AT + Vector3(90, 0, 420))
	_full(s)
	var g := _foe(s, Vector3(0, 0, -9.0))
	g.set_physics_process(false)
	s.set("cursor_fixed", g.global_position)
	var ss: Node3D = _stone_at(s, s.global_position + Vector3(0, 0, -4.5))
	await _wait(STEP * 3.0)
	s.call("cast_slot", 0)                          # 0.3 s wind-up, then the stone flies
	var hp0: float = (g.get("body") as Body).hp
	for i: int in 40:
		await t.get_tree().physics_frame
	check.call("Slingstone shatters your stone and flies on to hit the foe behind it",
		(not is_instance_valid(ss) or ss.is_queued_for_deletion() or not bool(ss.call("is_up"))) and (g.get("body") as Body).hp < hp0,
		"lost %f" % (hp0 - (g.get("body") as Body).hp))
	for n: Node in [l, f, s, g, e]:
		_gone(n)


## Actions whose default keys collide (each binding is meant to be one action's).
func _shared_defaults() -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for a: Array in Keybinds.ACTIONS:
		var key: String = "%s:%d" % [str(a[2]), int(a[3])]
		if seen.has(key):
			out.append("%s and %s" % [seen[key], a[0]])
		seen[key] = a[0]
	return out


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
