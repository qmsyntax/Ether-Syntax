extends Node
## The combat timeline probe (Brent 2026-10-24: "make [the combat mechanics] feel more fluid. It feels
## a bit clunky right now"). Headless; run it with a fixed frame rate so the animation clock and the
## physics clock agree:
##   godot --headless --fixed-fps 60 --path game res://tests/combat_timeline_probe.tscn   (-- --only=<seq> --trace)
##   godot --fixed-fps 60 --path game res://tests/combat_timeline_probe.tscn -- --sheet=<seq> [--every=4] [--tag=after]
##       (windowed) one sequence as a contact sheet, shots/timeline-<seq>-<tag>.png, a cell every 4 frames
## Plays the common sequences through the player's real input path - the strike button (Input
## actions + a fixed cursor, as the click handler reads it) and the hotbar (what main.gd's
## _cast_from_hotbar calls) - and logs, for every input, when it was pressed, when it took effect,
## and whether it was dropped. Also: how long the body plays a one-off clip while it is sliding
## along (skating), the largest turn in one frame (a snap), how far a bolt cast while walking flies
## from where the cursor points, and the clips' lengths and impact moments.
## It is a REPORT: the numbers before and after a change are compared by hand. It prints
## "TIMELINE: PASS" when there were no script errors and the rules that must hold still hold
## (a dash commits; a second dash too soon is winded; a skill that needs a target spends nothing
## without one; a buffered press never fires after its window; an interrupted wind-up is lost).
## It proves timing, not feel - feel needs Brent.
##
## The clunk it found before the 2026-10-24 fluidity pass, ranked by how often a player meets it
## and how bad it feels (the numbers are this probe's, before the pass):
##  1. A skill pressed while busy is DROPPED, silently: in a recovery (1-2-3 at 0.1 s apart loses the
##     2nd), in a dash (0.43 s), in a wind-up, while staggered. 7 of the 12 drops.
##  2. A skill cast while walking (click-to-move) flies the way you walk, not at the cursor: a bolt
##     106 deg off. Casting toward an attack target likewise ignores the cursor.
##  3. The cast's body motion lags the cast: an instant bolt spawns at once but the cast clip's thrust
##     comes 0.48 s later; the clip runs 1.3 s (cast_area 1.7 s, dodge 1.0 s for a 0.18 s dash) while
##     the recovery is 0.12 s, and the body skates in it when you walk off (0.2-0.65 s a cast).
##     A strike's damage lands 0.33 s before its slash swings. A wind-up shows no motion at all, and a
##     stagger plays no reaction.
##  4. Clicks made during a wind-up or a stagger are DROPPED (move and strike alike).
##  5. A basic strike after a melee skill waits 0.68 s (melee_cooldown x overcharge_cooldown_factor).
##  6. Clicking: one click on a foe in reach swings twice; three quick clicks swing twice.
##  7. Holding strike stops dead when the foe dies; it does not carry on to the next.
##  8. No impact: a landed hit is a white flash and a number - no hit-stop, no camera, no sound hook.
##  9. The body snaps round up to 90-180 deg in one frame (visual only).

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const STEP := 1.0 / 60.0
const TAP_S := 0.06                      # how long a click or a key tap is held down
const GIVE_UP_S := 1.5                   # an input that has not taken effect by then was dropped


## Sees every hit the player lands (the hook pipeline's on_dealt).
class Spy extends TalentEffect:
	var hits: Array = []
	var clock := 0.0

	func on_dealt(ctx: HitContext) -> void:
		hits.append({"t": clock, "bare": ctx.tags.has("melee") and not ctx.tags.has("ability"), "applied": ctx.applied})


var errors: ErrorCatcher
var only := ""
var trace := false
var rules_ok := true
var rule_notes: Array[String] = []
var _world: Node3D
var sheet := ""                          # --sheet=<sequence>: windowed, a contact sheet of it
var sheet_every := 4                     # --every=<frames> between cells
var sheet_tag := "now"                   # --tag=<before|after>, for the file name
var _cells: Array[Image] = []
var _cam: Camera3D
var _totals := {"inputs": 0, "dropped": 0, "delay_sum": 0.0, "delayed": 0, "skate_s": 0.0, "snap_max": 0.0}


func _ready() -> void:
	errors = ErrorCatcher.install()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.trim_prefix("--only=")
		elif a.begins_with("--sheet="):
			sheet = a.trim_prefix("--sheet=")
			only = sheet
		elif a.begins_with("--every="):
			sheet_every = int(a.trim_prefix("--every="))
		elif a.begins_with("--tag="):
			sheet_tag = a.trim_prefix("--tag=")
		elif a == "--trace":
			trace = true
	await get_tree().physics_frame
	_clip_report()
	await _seq("strike_x3", "water", [
		{"t": 0.0, "do": "strike_enemy", "label": "click 1"},
		{"t": 0.2, "do": "strike_enemy", "label": "click 2"},
		{"t": 0.4, "do": "strike_enemy", "label": "click 3"}], 1.6)
	await _seq("strike_hold", "water", [
		{"t": 0.0, "do": "strike_enemy", "hold": 1.4, "label": "hold strike 1.4 s"}], 1.6, {"count_strikes": true})
	await _seq("cast_during_strike", "water", [
		{"t": 0.0, "do": "strike_enemy", "label": "strike"},
		{"t": 0.1, "do": "slot", "slot": 0, "label": "bolt"}], 1.0)
	await _seq("cast_during_recovery", "water", [
		{"t": 0.0, "do": "slot", "slot": 0, "label": "bolt"},
		{"t": 0.07, "do": "slot", "slot": 1, "label": "tsunami strike"}], 1.0)
	await _seq("strike_after_skill", "water", [
		{"t": 0.0, "do": "slot", "slot": 1, "label": "tsunami strike"},
		{"t": 0.2, "do": "strike_enemy", "label": "strike"}], 1.2)
	await _seq("strike_after_burst", "nature", [
		{"t": 0.0, "do": "slot", "slot": 1, "label": "reaping sweep (0.15 s wind-up)"},
		{"t": 0.2, "do": "strike_enemy", "label": "strike"}], 1.2)
	await _seq("dash_then_cast", "water", [
		{"t": 0.0, "do": "slot", "slot": 2, "label": "dash"},
		{"t": 0.2, "do": "slot", "slot": 0, "label": "bolt"}], 1.2, {"no_enemy_near": true})
	await _seq("move_during_windup", "earth", [
		{"t": 0.0, "do": "slot", "slot": 0, "label": "slingstone (0.3 s wind-up)"},
		{"t": 0.1, "do": "ground", "at": Vector3(6, 0, 0), "label": "move click"}], 1.2)
	await _seq("strike_during_windup", "earth", [
		{"t": 0.0, "do": "slot", "slot": 1, "label": "landslide blow (0.6 s wind-up)"},
		{"t": 0.3, "do": "strike_enemy", "label": "strike click"}], 1.8)
	await _seq("staggered_mid_cast", "fire", [
		{"t": 0.0, "do": "slot", "slot": 3, "label": "backdraft (0.3 s wind-up, not braced)"},
		{"t": 0.15, "do": "heavy_hit", "label": "heavy blow lands"},
		{"t": 0.3, "do": "slot", "slot": 0, "label": "cinder spit while staggered"},
		{"t": 0.35, "do": "strike_enemy", "label": "strike click while staggered"}], 1.8, {"check_lost_windup": true, "extra_skill": "backdraft"})
	await _seq("chain_3_fast", "water", [
		{"t": 0.0, "do": "slot", "slot": 0, "label": "1 bolt"},
		{"t": 0.1, "do": "slot", "slot": 1, "label": "2 tsunami strike"},
		{"t": 0.2, "do": "slot", "slot": 2, "label": "3 dash"}], 1.5)
	await _seq("chain_3_earth", "earth", [
		{"t": 0.0, "do": "slot", "slot": 0, "label": "1 slingstone"},
		{"t": 0.12, "do": "slot", "slot": 2, "label": "2 raise slab"},
		{"t": 0.24, "do": "slot", "slot": 1, "label": "3 landslide blow"}], 2.4)
	await _seq("two_dashes", "water", [
		{"t": 0.0, "do": "slot", "slot": 2, "label": "dash"},
		{"t": 0.6, "do": "slot", "slot": 2, "label": "dash again (winded)"}], 1.4, {"no_enemy_near": true, "check_winded": true})
	await _seq("held_strike_next_enemy", "water", [
		{"t": 0.0, "do": "strike_enemy", "hold": 3.0, "label": "hold strike on a weak foe"}], 3.2, {"weak_enemy": true, "second_enemy": true, "count_strikes": true})
	await _seq("bolt_while_walking", "water", [
		{"t": 0.0, "do": "ground", "at": Vector3(8, 0, 0), "label": "walk east"},
		{"t": 0.3, "do": "aim", "at": Vector3(0.5, 0, -6), "label": "cursor on a foe to the north"},
		{"t": 0.32, "do": "slot", "slot": 0, "label": "bolt"}], 1.0, {"no_enemy_near": true, "aim_check": true})
	await _seq("needs_target", "wind", [
		{"t": 0.0, "do": "slot", "slot": 1, "label": "crosscut with no one in reach"}], 0.6, {"no_enemy_near": true, "check_no_spend": true})
	await _seq("buffer_expires", "water", [
		{"t": 0.0, "do": "slot", "slot": 2, "label": "dash"},
		{"t": 0.05, "do": "slot", "slot": 0, "label": "bolt pressed early in the dash"}], 1.2, {"no_enemy_near": true, "check_window": true})
	_report()


## The clips the player's body plays, how long each lasts at its playback rate, and when in it the
## right hand moves fastest (roughly where a swing lands).
func _clip_report() -> void:
	var p: CharacterBody3D = PlayerScript.new()
	add_child(p)
	var rig: Node = p.get("_rig")
	if not (rig is RealCharacter):
		print("TIMELINE: clips - no real body (procedural rig), skipped")
		p.queue_free()
		return
	var ap: AnimationPlayer = rig.get("_player")
	var sk: Skeleton3D = rig.get("_skeleton")
	var speeds: Dictionary = (GameData.wardrobe.get("action_speed", {}) as Dictionary)
	var hand: int = sk.find_bone("mixamorig_RightHand")
	if hand < 0:
		hand = sk.find_bone("mixamorig:RightHand")
	for clip: String in ["slash_in", "slash_out", "heavy", "cast", "cast_area", "dodge", "hit"]:
		if not ap.has_animation(clip):
			print("TIMELINE: clip %-10s missing" % clip)
			continue
		var length: float = ap.get_animation(clip).length
		var rate: float = float(speeds.get(clip, 1.0))
		var peak_t := 0.0
		var peak_v := 0.0
		var last := Vector3.ZERO
		var n := 60
		for i: int in n + 1:
			var at: float = length * float(i) / float(n)
			ap.play(clip, 0.0)
			ap.seek(at, true)
			var pos: Vector3 = sk.get_bone_global_pose(hand).origin if hand >= 0 else Vector3.ZERO
			if i > 0:
				var v: float = pos.distance_to(last) / (length / float(n))
				if v > peak_v:
					peak_v = v
					peak_t = at
			last = pos
		print("TIMELINE: clip %-10s %.2f s long, rate %.1f -> plays %.2f s; hand fastest at %.2f s played" % [clip, length, rate, length / rate, peak_t / rate])
	p.queue_free()
	await get_tree().physics_frame


func _floor() -> void:
	_world = Node3D.new()
	add_child(_world)
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 1, 80)
	col.shape = shape
	sb.add_child(col)
	sb.position = Vector3(0, -0.5, 0)
	_world.add_child(sb)


func _enemy(p: Node3D, at: Vector3, hp: float, fights: bool) -> CharacterBody3D:
	var e: CharacterBody3D = EnemyScript.new()
	e.call("setup", "grunt", p, 1.0)
	e.position = at
	_world.add_child(e)
	if not fights:
		e.set("target", null)
	e.set("poise_max", 100000.0)
	e.set("poise", 100000.0)
	(e.get("body") as Body).max_hp = hp
	(e.get("body") as Body).hp = hp
	return e


## What main.gd does with a hotbar key: the player's press handler if it has one, else cast_slot.
func _press_slot(p: Node, slot: int) -> void:
	Input.action_press("ability_%d" % (slot + 1))
	if p.has_method("press_slot"):
		p.call("press_slot", slot)
	else:
		p.call("cast_slot", slot)


func _seq(name: String, aff: String, inputs: Array, duration: float, opts: Dictionary = {}) -> void:
	if only != "" and not name.contains(only):
		return
	if sheet != "" and name != sheet:
		return
	_floor()
	if sheet != "":
		_stage()
	var p: CharacterBody3D = PlayerScript.new()
	_world.add_child(p)
	p.global_position = Vector3.ZERO
	p.call("set_talent", "one_percent_lifesteal")
	p.call("set_affinities", [aff])               # the whole kit on slots 1-3 (the sandbox loadout)
	p.set("active", true)
	if sheet != "":
		p.set("cursor_fixed", Vector3(0, 0, -3))   # windowed: aim ahead, not wherever the real mouse is
	if opts.has("extra_skill"):                    # a fourth skill on slot 4, outside the kit
		(p.get("abilities") as Array).append({"id": str(opts["extra_skill"]), "stage": 0, "progress": 0.0})
		p.get("hotbar")[3] = (p.get("abilities") as Array).size() - 1
	var spy := Spy.new()
	spy.setup(p, "spy")
	(p.get("effects") as Array).append(spy)
	var foe: Node3D = null
	var second: Node3D = null
	if not bool(opts.get("no_enemy_near", false)):
		foe = _enemy(p, Vector3(0, 0, -1.9), 60.0 if bool(opts.get("weak_enemy", false)) else 100000.0, false)
	if bool(opts.get("second_enemy", false)):
		second = _enemy(p, Vector3(1.6, 0, -3.2), 100000.0, false)
	var far_foe: Node3D = null
	if bool(opts.get("aim_check", false)):
		far_foe = _enemy(p, Vector3(0.5, 0, -6), 100000.0, false)
	var hitter: Node3D = _enemy(p, Vector3(-30, 0, 30), 100000.0, false)    # throws the heavy blow
	p.call("start_fight")
	await get_tree().physics_frame
	await get_tree().physics_frame

	var abilities: Array = p.get("abilities")
	for st: Dictionary in abilities:
		st["progress"] = 0.0
	var rig: Node = p.get("_rig")
	var ap: AnimationPlayer = rig.get("_player") if rig is RealCharacter else null
	var pending: Array = []                       # inputs pressed and not yet matched to an effect
	var results: Array = []
	var releases: Array = []                      # [t, action]
	var last_anim := ""
	var anims: Array[String] = []
	var skate := 0.0
	var snap := 0.0
	var last_rot: float = p.rotation.y
	var last_hits := 0
	var was_held := false
	var essence_before := 0.0
	var winded_cost := {}
	var bolt_err := -1.0
	var dash_t := -1.0
	var dash_end := -1.0
	var cast_in_dash := false
	var t := 0.0
	var inputs_left: Array = inputs.duplicate(true)
	var strike_count := 0
	var held_until := -1.0
	while t < duration:
		await get_tree().physics_frame
		var seen: float = t - STEP                # what the player did in the frame just processed
		spy.clock = t
		# --- observe the frame just processed
		var held_now: bool = not (p.get("_held") as Dictionary).is_empty()
		var acted := false                       # a cast or a blow this frame: its turn is a snap by design
		for i: int in abilities.size():
			var st: Dictionary = abilities[i]
			if float(st["progress"]) > 0.0:
				if not (was_held and held_now):
					acted = true
					_effect(pending, results, "slot", i, seen)
					if str(GameData.ability(str(st["id"])).get("kind", "")) == "dash":
						if dash_t >= 0.0:
							winded_cost["second"] = essence_before - float(p.get("essence"))
						else:
							winded_cost["first"] = essence_before - float(p.get("essence"))
						dash_t = seen
					elif dash_end > seen or (dash_t >= 0.0 and float(p.get("_dash_time")) > 0.0):
						cast_in_dash = true
				st["progress"] = 0.0
		was_held = held_now
		if dash_t >= 0.0 and dash_end < 0.0 and float(p.get("_dash_time")) <= 0.0:
			dash_end = seen
		var hits: Array = spy.hits
		for k: int in range(last_hits, hits.size()):
			acted = true
			if bool((hits[k] as Dictionary)["bare"]):
				strike_count += 1
				_effect(pending, results, "strike", -1, seen)
		last_hits = hits.size()
		if p.velocity.length() > 0.3:
			_effect(pending, results, "move", -1, seen)
		if ap != null:
			var now: String = String(ap.current_animation)
			if now != last_anim:
				anims.append("%.2f %s" % [seen, now])
				last_anim = now
			if str(rig.get("_one_shot")) != "" and p.velocity.length() > 1.0:
				skate += STEP
		var shown_yaw: float = p.rotation.y + ((rig as Node3D).rotation.y if rig is Node3D else 0.0)     # the body as drawn
		var dr: float = absf(wrapf(shown_yaw - last_rot, -PI, PI))
		if not acted:
			snap = maxf(snap, rad_to_deg(dr))
		last_rot = shown_yaw
		if bolt_err < 0.0 and far_foe != null:
			for node: Node in _world.get_children():
				if node.get_script() == ProjectileScript:
					var want: Vector3 = far_foe.global_position - p.global_position
					want.y = 0.0
					bolt_err = rad_to_deg((node.get("dir") as Vector3).angle_to(want.normalized()))
		# --- keep the run clean: full essence, no heat, so nothing is refused for reasons not timing
		essence_before = float(p.get("essence_max"))
		p.set("essence", essence_before)
		(p.get("reflux_by") as Dictionary).clear()
		(p.get("locked_by") as Dictionary).clear()
		# --- releases due
		for r: int in range(releases.size() - 1, -1, -1):
			if float(releases[r][0]) <= t + 0.0001:
				Input.action_release(str(releases[r][1]))
				releases.remove_at(r)
		if held_until >= 0.0 and foe != null and is_instance_valid(foe) and not bool(foe.call("is_dead")):
			p.set("cursor_fixed", foe.global_position)
		elif held_until >= 0.0 and second != null and is_instance_valid(second):
			p.set("cursor_fixed", second.global_position)
		# --- inputs due this frame
		while not inputs_left.is_empty() and float((inputs_left[0] as Dictionary)["t"]) <= t + 0.0001:
			var inp: Dictionary = inputs_left.pop_front()
			var rec: Dictionary = {"label": str(inp["label"]), "pressed": t, "took": -1.0, "type": "", "slot": -1}
			match str(inp["do"]):
				"strike_enemy":
					p.set("cursor_fixed", foe.global_position if foe != null else p.global_position + Vector3(0, 0, -2))
					Input.action_press("strike")
					var hold: float = float(inp.get("hold", TAP_S))
					releases.append([t + hold, "strike"])
					if inp.has("hold"):
						held_until = t + hold
					rec["type"] = "strike"
				"ground":
					p.set("cursor_fixed", inp["at"])
					Input.action_press("strike")
					releases.append([t + TAP_S, "strike"])
					rec["type"] = "move"
				"aim":
					p.set("cursor_fixed", inp["at"])
					rec["type"] = "none"
				"slot":
					_press_slot(p, int(inp["slot"]))
					releases.append([t + TAP_S, "ability_%d" % (int(inp["slot"]) + 1)])
					rec["type"] = "slot"
					rec["slot"] = p.get("hotbar")[int(inp["slot"])]
				"heavy_hit":
					var w_before: float = float(p.get("_windup_t"))
					p.call("take_hit", 1.0, true, hitter)
					rec["type"] = "none"
					rec["took"] = t
					if bool(opts.get("check_lost_windup", false)):
						var lost: bool = w_before > 0.0 and float(p.get("_windup_t")) <= 0.0 and bool(p.call("is_staggered"))
						_rule("a heavy blow staggers you and the wind-up is lost", lost)
			if str(rec["type"]) != "none":
				pending.append(rec)
			results.append(rec)
		if sheet != "":
			await _snap_cell(p, int(round(t / STEP)))
		t += STEP
	for a: String in ["strike", "ability_1", "ability_2", "ability_3", "move_up"]:
		Input.action_release(a)
	p.set("cursor_fixed", null)
	# --- the sequence's lines
	print("TIMELINE: --- %s (%s)" % [name, aff])
	for rec: Dictionary in results:
		if str(rec["type"]) == "none":
			print("TIMELINE:   %-36s at %.2f" % [rec["label"], rec["pressed"]])
			continue
		_totals["inputs"] = int(_totals["inputs"]) + 1
		if float(rec["took"]) < 0.0:
			_totals["dropped"] = int(_totals["dropped"]) + 1
			print("TIMELINE:   %-36s pressed %.2f  DROPPED" % [rec["label"], rec["pressed"]])
		else:
			var delay: float = float(rec["took"]) - float(rec["pressed"])
			_totals["delay_sum"] = float(_totals["delay_sum"]) + delay
			_totals["delayed"] = int(_totals["delayed"]) + 1
			print("TIMELINE:   %-36s pressed %.2f  took effect %.2f  (+%.2f s)" % [rec["label"], rec["pressed"], rec["took"], delay])
	if bool(opts.get("count_strikes", false)):
		print("TIMELINE:   bare strikes landed: %d in %.1f s" % [strike_count, duration])
	if bool(opts.get("second_enemy", false)):
		var moved_on: bool = second != null and is_instance_valid(second) and (second.get("body") as Body).hp < (second.get("body") as Body).max_hp
		print("TIMELINE:   held strike carried on to the next foe: %s" % ("yes" if moved_on else "no"))
	if bool(opts.get("aim_check", false)):
		print("TIMELINE:   bolt flew %.0f deg away from the cursor" % bolt_err)
	if dash_t >= 0.0:
		_rule("%s: nothing is cast while the dash is under way" % name, not cast_in_dash)
	if bool(opts.get("check_winded", false)):
		var first: float = float(winded_cost.get("first", 0.0))
		var second_cost: float = float(winded_cost.get("second", 0.0))
		print("TIMELINE:   dash cost %.1f, second dash %.1f" % [first, second_cost])
		_rule("a second dash too soon is winded (costs more)", second_cost > first * 1.5)
	if bool(opts.get("check_no_spend", false)):
		_rule("a skill that needs a target spends nothing without one", float((results[0] as Dictionary)["took"]) < 0.0)
	if bool(opts.get("check_window", false)):
		var bolt: Dictionary = results[1]
		var window: float = float((GameData.balance.get("feel", {}) as Dictionary).get("input_buffer_s", 0.0))
		var fired_late: bool = float(bolt["took"]) >= 0.0 and float(bolt["took"]) - float(bolt["pressed"]) > window + STEP * 1.5
		print("TIMELINE:   buffer window %.2f s; a press older than that is dropped: %s" % [window, "yes" if not fired_late else "NO"])
		_rule("a buffered press never fires after its window", not fired_late)
	print("TIMELINE:   skating (a one-off clip while sliding) %.2f s; largest turn in one frame (not at a cast or blow) %.0f deg" % [skate, snap])
	if trace:
		print("TIMELINE:   clips: %s" % ", ".join(anims))
	_totals["skate_s"] = float(_totals["skate_s"]) + skate
	_totals["snap_max"] = maxf(float(_totals["snap_max"]), snap)
	if sheet != "":
		_save_sheet(name)
	_world.queue_free()
	await get_tree().physics_frame


## --sheet: light, a ground to stand on, and a camera at the game's angle on the player.
func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.19)
	env.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	sun.shadow_enabled = true
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.33, 0.30, 0.25)
	ground.material_override = gm
	_world.add_child(ground)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_world.add_child(_cam)
	_cam.current = true
	_cells.clear()


## --sheet: every sheet_every frames, the view around the player becomes a cell.
func _snap_cell(p: Node3D, frame: int) -> void:
	if frame % sheet_every != 0:
		return
	var at: Vector3 = p.global_position
	_cam.global_position = at + Vector3(4.2, 4.6, 4.2)
	_cam.look_at(at + Vector3(0, 0.9, -0.4), Vector3.UP)
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var size: Vector2i = img.get_size()
	var side: int = mini(size.x, size.y) * 3 / 4
	var cell: Image = img.get_region(Rect2i((size.x - side) / 2, (size.y - side) / 2, side, side))
	cell.resize(240, 240)
	cell.convert(Image.FORMAT_RGBA8)
	for x: int in 240:                           # a strip along the top, darker the later the frame, to read the order
		for y: int in 3:
			cell.set_pixel(x, y, Color(1, 1, 1) if x < int(240.0 * float(_cells.size() % 10 + 1) / 10.0) else Color(0, 0, 0))
	_cells.append(cell)


func _save_sheet(name: String) -> void:
	if _cells.is_empty():
		return
	var cols := 10
	var rows: int = int(ceil(float(_cells.size()) / float(cols)))
	var out := Image.create(240 * mini(cols, _cells.size()), 240 * rows, false, Image.FORMAT_RGBA8)
	for i: int in _cells.size():
		out.blit_rect(_cells[i], Rect2i(0, 0, 240, 240), Vector2i((i % cols) * 240, (i / cols) * 240))
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir.path_join("timeline-%s-%s.png" % [name, sheet_tag])
	print("TIMELINE: sheet saved %s (%d cells, every %d frames = %.2f s, left to right)" % [path, _cells.size(), sheet_every, float(sheet_every) / 60.0])
	out.save_png(path)


## The first pending input of `type` (and for a slot, that ability) takes effect at `at`.
func _effect(pending: Array, _results: Array, type: String, ability: int, at: float) -> void:
	for i: int in pending.size():
		var rec: Dictionary = pending[i]
		if str(rec["type"]) != type or (type == "slot" and int(rec["slot"]) != ability):
			continue
		if at + 0.0001 < float(rec["pressed"]) or at - float(rec["pressed"]) > GIVE_UP_S:
			continue
		rec["took"] = at
		pending.remove_at(i)
		return


func _rule(what: String, ok: bool) -> void:
	print("TIMELINE:   rule: %s - %s" % [what, "ok" if ok else "BROKEN"])
	if not ok:
		rules_ok = false
		rule_notes.append(what)


func _report() -> void:
	var n: int = int(_totals["delayed"])
	print("TIMELINE: === %d inputs, %d dropped, mean delay of the rest %.2f s; skating %.2f s in all; largest one-frame turn %.0f deg" % [
		int(_totals["inputs"]), int(_totals["dropped"]), float(_totals["delay_sum"]) / maxf(1.0, float(n)), float(_totals["skate_s"]), float(_totals["snap_max"])])
	var ok: bool = rules_ok and errors.count() == 0
	if not rules_ok:
		print("TIMELINE: broken rules: %s" % "; ".join(rule_notes))
	print("TIMELINE: script errors %d" % errors.count())
	print("TIMELINE: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
