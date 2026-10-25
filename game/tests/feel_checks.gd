extends RefCounted
## The self-test's checks for how the controls answer (Brent 2026-10-24: "make them feel more fluid.
## It feels a bit clunky right now"; balance.json "feel", the "# --- feel" block of player.gd). Each
## knob gets a check, and so does each rule the pass had to keep: a dash commits, a second dash too
## soon is winded, a skill that needs a target spends nothing without one, cast_ability still
## refuses a busy cast, the buffer has a window, a wind-up is lost to a stagger. Called from
## selftest.gd (`-- --only=feel` runs it alone). It plays real physics frames, because the strike
## button is read through Input (just-pressed belongs to a frame). It proves timing, not feel.

const PlayerScript := preload("res://scripts/player.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const STEP := 1.0 / 60.0
const AT := Vector3(1500, 0, 1500)            # well away from everything else the self-test builds

var t: Node                 # the self-test node (things are added under it)
var check: Callable         # its _check(label, ok, detail)
var _made: Array[Node] = []
var _f: Dictionary


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn
	_f = GameData.balance.get("feel", {})


func run() -> void:
	print("how the controls answer (balance.json feel, 2026-10-24):")
	await t.get_tree().physics_frame
	_data()
	await _buffer()
	await _buffer_rules()
	await _clicks()
	await _held_strike()
	await _cast_aim()
	await _kept_orders()
	await _strike_after_skill()
	await _impact()
	_motions()
	await _body_turn()
	for a: String in ["strike", "ability_1", "ability_2", "ability_3"]:
		Input.action_release(a)
	for n: Node in _made:
		if is_instance_valid(n):
			n.queue_free()
	await t.get_tree().physics_frame


# --- helpers ------------------------------------------------------------------------------------

func _keep(n: Node) -> Node:
	_made.append(n)
	return n


func _player(aff: String, at: Vector3 = AT) -> CharacterBody3D:
	var p: CharacterBody3D = PlayerScript.new()
	p.position = at
	t.add_child(p)
	p.call("set_affinities", [aff])
	p.set("active", true)
	p.set("star_pct", [99.0] as Array[float])   # a deep tank, so nothing is refused for essence
	p.call("_recompute_essence_max")
	p.set("essence", float(p.get("essence_max")))
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


## Let `seconds` of game time pass, a physics frame at a time (the player runs its own frames).
func _wait(seconds: float) -> void:
	var n: int = int(ceil(seconds / STEP))
	for i: int in n:
		for m: Node in _made:                    # no heat: running hot would lengthen recoveries
			if is_instance_valid(m) and m.get("reflux_by") != null:
				(m.get("reflux_by") as Dictionary).clear()
				(m.get("locked_by") as Dictionary).clear()
		await t.get_tree().physics_frame


func _lost(e: Node) -> float:
	return (e.get("body") as Body).max_hp - (e.get("body") as Body).hp


func _cost(id: String) -> float:
	return float(GameData.ability(id)["cost"])


func _gone(p: Node) -> void:
	p.set("active", false)
	p.queue_free()


# --- the knobs ----------------------------------------------------------------------------------

func _data() -> void:
	var want: Array[String] = ["input_buffer_s", "strike_queue_max", "held_strike_retargets", "strike_after_skill_s", "cast_faces_cursor",
		"cast_face_hold_s", "body_turn_rate", "anim_action_lead_s", "anim_move_cancel_s", "anim_cancel_blend_s", "anim_action_blend_s",
		"anim_loop_blend_s", "hit_stop_s", "hit_stop_heavy_s", "camera_kick_m", "camera_kick_heavy_m", "camera_kick_hurt_m", "camera_kick_decay"]
	var missing: Array[String] = []
	for k: String in want:
		if not _f.has(k):
			missing.append(k)
	check.call("balance.json feel has every knob the controls read, and a note", missing.is_empty() and str(_f.get("_note", "")) != "", "missing %s" % str(missing))
	check.call("the input buffer is short: a press is kept for a moment, not for ever", float(_f["input_buffer_s"]) > 0.0 and float(_f["input_buffer_s"]) <= 0.5)
	check.call("hit-stop never touches the game clock: it is a fraction of a second on the bodies", float(_f["hit_stop_heavy_s"]) < 0.2 and float(_f["hit_stop_s"]) <= float(_f["hit_stop_heavy_s"]))
	var impact: Dictionary = GameData.wardrobe.get("action_impact_s", {})
	check.call("wardrobe.json says where each cast and swing clip lands (action_impact_s)", impact.has("cast") and impact.has("slash_in") and impact.has("heavy"))


# --- the input buffer ---------------------------------------------------------------------------

func _buffer() -> void:
	var p := _player("dream")
	await _wait(STEP)
	var e0: float = float(p.get("essence"))
	p.call("press_slot", 0)                      # Dozing Mote (dream: the v2 water kit has no free bolt)
	check.call("a hotbar press casts at once when you are free", _near(e0 - float(p.get("essence")), _cost("dozing_mote")))
	var e1: float = float(p.get("essence"))
	p.call("press_slot", 1)                      # Night Terror, inside the mote's recovery
	check.call("pressed during the recovery it does not go off yet", _near(float(p.get("essence")), e1) and int(p.get("_buffered_slot")) == 1)
	await _wait(float(GameData.num("abilities", "cast_recovery")) + STEP * 2.0)
	check.call("... and goes off the moment the recovery ends (input_buffer_s)", _near(e1 - float(p.get("essence")), _cost("night_terror")) and int(p.get("_buffered_slot")) == -1,
		"spent %f" % (e1 - float(p.get("essence"))))
	await _wait(0.5)
	var e2: float = float(p.get("essence"))
	p.call("cast_slot", 0)
	var e3: float = float(p.get("essence"))
	p.call("cast_ability", 1)
	check.call("cast_ability itself still refuses a cast while you are busy, and keeps nothing", _near(float(p.get("essence")), e3) and int(p.get("_buffered_slot")) == -1 and e2 > e3)
	# the latest press wins
	p.call("press_slot", 1)
	p.call("press_slot", 0)
	check.call("the latest press is the one kept", int(p.get("_buffered_slot")) == 0)
	_gone(p)


func _buffer_rules() -> void:
	# a dash commits: what is pressed during it waits until it is over
	var p := _player("dream")
	p.set("_facing", Vector3(0, 0, -1))
	await _wait(STEP)
	p.call("press_slot", 2)                      # Doubling Step
	var commit: float = float(GameData.ability("doubling_step")["dash_time"]) + GameData.num("combat", "dash_recovery_s")
	await _wait(commit - 0.25)
	var e0: float = float(p.get("essence"))
	p.call("press_slot", 0)
	await _wait(0.1)
	check.call("a dash still commits: a skill pressed in it is not cast while you are committed", _near(float(p.get("essence")), e0))
	await _wait(0.3)
	check.call("... and is cast as soon as the commitment ends", _near(e0 - float(p.get("essence")), _cost("dozing_mote")), "spent %f" % (e0 - float(p.get("essence"))))
	# a press older than the window is dropped
	await _wait(0.6)
	p.set("_winded_t", 0.0)
	p.call("press_slot", 2)
	var e1: float = float(p.get("essence"))
	p.call("press_slot", 0)                      # at once: the commitment outlasts the window
	await _wait(commit + 0.3)
	check.call("a press is forgotten when its window runs out before you are free", _near(float(p.get("essence")), e1) and commit > float(_f["input_buffer_s"]))
	# a second dash too soon is still winded, buffered or not
	var e2: float = float(p.get("essence"))
	p.call("press_slot", 2)
	check.call("a second dash too soon still costs double", _near(e2 - float(p.get("essence")), _cost("doubling_step") * GameData.num("combat", "winded_cost_mult")),
		"spent %f" % (e2 - float(p.get("essence"))))
	_gone(p)
	# a skill that needs a target spends nothing without one, even when it was kept for later
	var w := _player("wind")
	await _wait(STEP)
	w.call("press_slot", 0)                      # Cutting Gust: a recovery to wait out
	var e3: float = float(w.get("essence"))
	w.call("press_slot", 1)                      # Crosscut, nobody in reach
	await _wait(0.4)
	check.call("a kept skill that needs a target still spends nothing without one", _near(float(w.get("essence")), e3))
	_gone(w)
	# staggered: the wind-up is lost; a press made while you are down goes off when you are up
	var f := _player("fire")
	(f.get("abilities") as Array).append({"id": "backdraft", "stage": 0, "progress": 0.0})
	f.get("hotbar")[3] = (f.get("abilities") as Array).size() - 1
	var hitter := _foe(f, Vector3(40, 0, 40))
	await _wait(STEP)
	f.call("press_slot", 3)                      # Backdraft: a 0.3 s wind-up, not braced
	await _wait(0.1)
	f.call("take_hit", 1.0, true, hitter)
	check.call("a heavy blow mid-wind-up staggers you and the wind-up is lost", bool(f.call("is_staggered")) and float(f.get("_windup_t")) <= 0.0)
	var down: float = GameData.num("combat", "player_stagger_s")
	await _wait(maxf(0.0, down - float(_f["input_buffer_s"]) + 0.1))     # late enough in the stagger for the window
	var e4: float = float(f.get("essence"))
	f.call("press_slot", 0)                      # Cinder Spit while down
	check.call("nothing is cast while you are staggered", _near(float(f.get("essence")), e4) and bool(f.call("is_staggered")))
	await _wait(float(_f["input_buffer_s"]))
	check.call("... the press made while down goes off when you are up", _near(e4 - float(f.get("essence")), _cost("cinder_spit")))
	_gone(f)


# --- clicks on a foe ----------------------------------------------------------------------------

func _clicks() -> void:
	var p := _player("water", AT + Vector3(0, 0, 40))
	var e := _foe(p, Vector3(0, 0, -1.8))
	var blows: Array = []
	p.connect("impact", func(_strength: int, _at: Vector3) -> void: blows.append(1))     # one per melee hit landed
	p.set("cursor_fixed", e.global_position)
	await _wait(STEP)
	Input.action_press("strike")
	await _wait(STEP * 3.0)
	Input.action_release("strike")
	await _wait(1.2)
	check.call("one click on a foe in reach is one blow (it was two)", blows.size() == 1, "%d blows" % blows.size())
	blows.clear()
	for i: int in 3:                             # three quick clicks, a fifth of a second apart
		Input.action_press("strike")
		await _wait(STEP * 3.0)
		Input.action_release("strike")
		await _wait(0.15)
	await _wait(1.4)
	check.call("three quick clicks are three blows (one waits its turn: strike_queue_max)", blows.size() == 3, "%d blows" % blows.size())
	blows.clear()
	var cd: float = GameData.num("player", "melee_cooldown") * float(p.call("weapon_stat", "melee_cooldown_mult", true)) * float(p.call("temper_stat", "melee_cooldown_mult"))
	Input.action_press("strike")
	await _wait(1.0)
	Input.action_release("strike")
	await _wait(0.6)
	check.call("holding strike keeps swinging, one blow a melee_cooldown, and stops when let go", blows.size() == int(floor((1.0 - STEP) / cd)) + 1, "%d blows, cd %f" % [blows.size(), cd])
	p.set("cursor_fixed", null)
	_gone(p)


func _held_strike() -> void:
	var p := _player("water", AT + Vector3(0, 0, 80))
	var weak := _foe(p, Vector3(0, 0, -1.8), 1.0)
	var next := _foe(p, Vector3(1.5, 0, -3.0))
	p.set("cursor_fixed", weak.global_position)
	await _wait(STEP)
	Input.action_press("strike")
	await _wait(0.1)
	p.set("cursor_fixed", next.global_position)  # the cursor is on the next foe as the first falls
	await _wait(1.5)
	Input.action_release("strike")
	check.call("holding strike when your foe falls carries on to the foe under the cursor", _lost(next) > 0.0, "lost %f" % _lost(next))
	await _wait(0.2)
	p.set("cursor_fixed", null)
	_gone(p)


# --- facing ---------------------------------------------------------------------------------------

func _cast_aim() -> void:
	var p := _player("dream")
	p.set("move_goal", p.global_position + Vector3(0, 0, -20))      # walking north
	p.set("has_move_goal", true)
	await _wait(0.2)
	p.set("cursor_fixed", p.global_position + Vector3(6, 0, 0))     # pointing east
	var old: Array[Node] = t.get_children()
	p.call("press_slot", 0)
	var dir := Vector3.ZERO
	for n: Node in t.get_children():
		if n.get_script() == ProjectileScript and not old.has(n):
			dir = n.get("dir")
	check.call("a skill cast while walking goes where the cursor points, not the way you walk (cast_faces_cursor)", dir.angle_to(Vector3(1, 0, 0)) < deg_to_rad(5.0), "dir %s" % str(dir))
	await _wait(0.1)
	var facing: Vector3 = p.get("_facing")
	check.call("for a moment after the cast you keep facing where it went (cast_face_hold_s)", facing.angle_to(Vector3(1, 0, 0)) < deg_to_rad(5.0) and float(_f["cast_face_hold_s"]) > 0.1)
	await _wait(float(_f["cast_face_hold_s"]) + 0.1)
	facing = p.get("_facing")
	check.call("... then you face your walk again", facing.angle_to(Vector3(0, 0, -1)) < deg_to_rad(10.0), "facing %s" % str(facing))
	p.set("cursor_fixed", null)
	_gone(p)
	# no cursor to read (a test, the bot): the facing is left as it was
	var q := _player("dream")
	q.set("_facing", Vector3(0, 0, -1))
	await _wait(STEP)
	q.call("cast_slot", 0)
	check.call("with no cursor the cast keeps the facing it had", (q.get("_facing") as Vector3).angle_to(Vector3(0, 0, -1)) < 0.01)
	_gone(q)


func _kept_orders() -> void:
	# a click on the ground made during a wind-up is walked when it goes off; meanwhile you stay set
	var p := _player("earth")
	p.set("cursor_fixed", p.global_position + Vector3(0, 0, -6))
	await _wait(STEP)
	p.call("press_slot", 0)                      # Slingstone, 0.3 s wind-up
	var at: Vector3 = p.global_position
	await _wait(0.05)
	p.set("cursor_fixed", p.global_position + Vector3(6, 0, 0))
	Input.action_press("strike")
	await _wait(STEP * 3.0)
	Input.action_release("strike")
	check.call("a wind-up still holds you where you stood", p.global_position.distance_to(at) < 0.01 and float(p.get("_windup_t")) > 0.0)
	var aim: Vector3 = p.get("_facing")
	check.call("... and aimed where you aimed (a click meanwhile does not turn it)", aim.angle_to(Vector3(0, 0, -1)) < 0.05, "facing %s" % str(aim))
	await _wait(float(GameData.ability("slingstone")["windup"]) + 0.2)
	check.call("a click made during a wind-up is kept: you walk there when it goes off", p.global_position.x > at.x + 0.3, "moved %s" % str(p.global_position - at))
	p.set("cursor_fixed", null)
	_gone(p)
	# a click made while staggered waits for you to get up; you neither move nor swing meanwhile
	var q := _player("water", AT + Vector3(0, 0, 120))
	var e := _foe(q, Vector3(0, 0, -1.8))
	var hitter := _foe(q, Vector3(40, 0, 10))
	await _wait(STEP)
	q.call("take_hit", 1.0, true, hitter)
	q.set("cursor_fixed", e.global_position)
	Input.action_press("strike")
	await _wait(STEP * 3.0)
	Input.action_release("strike")
	check.call("staggered, a click on a foe does not swing", _lost(e) <= 0.0 and bool(q.call("is_staggered")))
	await _wait(GameData.num("combat", "player_stagger_s") + 0.1)
	check.call("... it lands once you are up", _lost(e) > 0.0)
	q.set("cursor_fixed", null)
	_gone(q)


func _strike_after_skill() -> void:
	var p := _player("water", AT + Vector3(0, 0, 160))
	var e := _foe(p, Vector3(0, 0, -1.8))
	await _wait(STEP)
	p.call("cast_slot", 1)                       # Tsunami Strike, a melee_burst
	check.call("after a melee skill a bare strike waits one ordinary swing (strike_after_skill_s)", _near(float(p.get("_melee_cd")), float(_f["strike_after_skill_s"])),
		"cd %f" % float(p.get("_melee_cd")))
	e.queue_free()
	_gone(p)


# --- impact ----------------------------------------------------------------------------------------

func _impact() -> void:
	var p := _player("water", AT + Vector3(0, 0, 200))
	var e := _foe(p, Vector3(0, 0, -1.8))
	await _wait(STEP)
	var scale: float = Engine.time_scale
	var heard: Array = []
	p.connect("impact", func(strength: int, _at: Vector3) -> void: heard.append(strength))
	p.call("_strike_target", e, 1.0, ["melee"])
	var rig: Variant = e.get("_rig")
	check.call("a landed strike holds the struck body still a moment (hit-stop), not the game clock",
		rig is ModelRig and float((rig as ModelRig).get("_pause_left")) > 0.0 and Engine.time_scale == scale)
	check.call("... and nudges the camera along the blow", (p.call("camera_kick") as Vector3).length() > 0.0 and (p.call("camera_kick") as Vector3).z < 0.0)
	check.call("... and says so (the impact signal, for a sound later)", heard.size() == 1 and int(heard[0]) == 0)
	await _wait(1.0)
	check.call("the camera settles again", (p.call("camera_kick") as Vector3).length() < 0.005)
	p.call("deal_damage", e, 5.0, ["ability", "water", "projectile"])
	check.call("a bolt that lands is not a melee hit: no hit-stop or nudge", (p.call("camera_kick") as Vector3).length() < 0.005 and heard.size() == 1)
	_gone(p)


# --- the body's motions -----------------------------------------------------------------------------

func _motions() -> void:
	if not RealCharacter.exists("body_male"):
		check.call("(real bodies missing: motion checks skipped)", true)
		return
	var rc: RealCharacter = RealCharacter.create("body_male")
	t.add_child(rc)
	_keep(rc)
	var ap: AnimationPlayer = rc.get("_player")
	var rate: float = float((GameData.wardrobe["action_speed"] as Dictionary)["cast"])
	var impact: float = float((GameData.wardrobe["action_impact_s"] as Dictionary)["cast"])
	var lead: float = float(_f["anim_action_lead_s"])
	rc.play_action("cast", lead)
	check.call("an instant skill's motion starts part-way, so its thrust lands anim_action_lead_s after the press",
		_near(ap.current_animation_position, impact - lead * rate, 0.02), "at %f want %f" % [ap.current_animation_position, impact - lead * rate])
	rc.play_action("cast", 2.0)
	check.call("a long wind-up draws the motion out so it lands as the wind-up ends", _near(ap.current_animation_position, 0.0, 0.02) and ap.speed_scale < rate)
	rc.play_action("cast", -1.0)
	for i: int in 3:
		rc.animate(STEP, 5.0, false)
	check.call("walking off does not cut a motion at once", str(rc.get("_one_shot")) == "cast")
	for i: int in int(ceil(float(_f["anim_move_cancel_s"]) / STEP)) + 1:
		rc.animate(STEP, 5.0, false)
	check.call("... it is cut for the run after anim_move_cancel_s (no skating to its end)", str(rc.get("_one_shot")) == "" and String(ap.current_animation) != "cast",
		"playing %s" % String(ap.current_animation))
	rc.play_action("cast", -1.0)
	for i: int in 30:
		rc.animate(STEP, 0.0, false)
	check.call("standing still, the motion plays on", str(rc.get("_one_shot")) == "cast")
	rc.hit_pause(0.05, 0.0)
	rc.call("_process", STEP)
	check.call("hit-stop freezes the clip", ap.speed_scale == 0.0)
	for i: int in 5:
		rc.call("_process", STEP)
	check.call("... and lets it go after hit_stop_s", ap.speed_scale > 0.0)


func _body_turn() -> void:
	var p := _player("water")
	p.set("_facing", Vector3(0, 0, -1))
	await _wait(0.2)
	p.set("move_goal", p.global_position + Vector3(0, 0, 20))       # turn right round and walk
	p.set("has_move_goal", true)
	await _wait(STEP * 2.0)
	var rig: Node3D = p.get("_rig")
	check.call("gameplay facing turns at once", absf(wrapf(p.rotation.y - PI, -PI, PI)) < 0.05)
	check.call("the body as drawn eases round (body_turn_rate), it does not snap", absf(rig.rotation.y) > 0.3)
	await _wait(0.5)
	check.call("... and has caught up a moment later", absf(rig.rotation.y) < 0.05)
	_gone(p)


func _near(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps
