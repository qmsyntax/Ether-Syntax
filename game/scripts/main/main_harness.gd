class_name MainHarness
extends RefCounted
## The test and screenshot harness: what a run's test, shot and bot arguments ask for (--shot, --shot-ui=...,
## --shot-settings, --shot-dungeon, --bot-dungeon / --bot-full / --bot-die), the screenshot countdown, the
## passage bot's steering and report, and saving the shot. main.gd builds it only when a run needs it
## (Main._harness); a game being played never does. Moved out of main.gd (docs/architecture/main-split.md).

var main: Main
## The screenshot setups (MainShots) and the seal, test-character and role shots (MainSealShots).
var shots: MainShots
var seal_shots: MainSealShots


func _init(of: Main) -> void:
	main = of
	shots = MainShots.new(of)
	seal_shots = MainSealShots.new(of)


var _frames := 0
var _bot_scenario := ""             # "gate" = leave at the first exit, "full" = clear all walls, "die" = die inside
var _bot_money_before := 0
var _bot_started_ms := 0
var _shot_dungeon := false          # windowed bot run that screenshots wall 2 as it wakes
var _shot_countdown := 0


## A screenshot's last moment: run when _shot_countdown reaches SHOT_LATE_FRAMES (a refusal pressed just before the shot).
var _shot_late: Callable = Callable()
const SHOT_LATE_FRAMES := 8


## What the run's arguments ask for: a screenshot setup, the arena shot, the controls shot, a passage bot.
func start(args: PackedStringArray) -> void:
	var ui_shot := ""
	for a: String in args:
		if a.begins_with("--shot-ui="):
			ui_shot = a.trim_prefix("--shot-ui=")
		elif a.begins_with("--biome="):
			main.forced_biome = a.trim_prefix("--biome=")
	if ui_shot != "":
		shots._setup_ui_shot(ui_shot)
	elif args.has("--shot"):
		main._shot_mode = true
		main._select_talent(0)
		main.enter_arena()
		main.rest_timer = 0.5
	elif args.has("--shot-settings"):
		# Screenshot the controls menu over the town. Not paused, so the countdown can tick.
		main._shot_mode = true
		_frames = 1000
		main._select_talent(0)
		main._enter_town()
		main._open_settings()
		main.get_tree().paused = false
		_shot_countdown = 25
	elif args.has("--bot-dungeon") or args.has("--bot-full") or args.has("--bot-die") or args.has("--shot-dungeon"):
		_shot_dungeon = args.has("--shot-dungeon")
		_bot_scenario = "full" if args.has("--bot-full") else ("die" if args.has("--bot-die") else "gate")
		main._bot_mode = true
		_bot_started_ms = Time.get_ticks_msec()
		Engine.time_scale = 5.0
		main._select_talent(0)
		main.player.set("money", main.ticket_price)
		main._show_screen(null, false)
		main._enter_dungeon()
		main.player.set("bot", true)


## Each frame of a test run: the screenshot countdowns, then the passage bot's report.
func tick() -> void:
	if main._shot_mode:
		_frames += 1
		if _frames == 260:
			_save_shot()
	if _shot_countdown > 0:
		_shot_countdown -= 1
		if _shot_countdown == SHOT_LATE_FRAMES and _shot_late.is_valid():
			_shot_late.call()
		if _shot_countdown == 0:
			_save_shot()
	if main._bot_mode:
		_tick_bot_report()


## The passage bot (--bot-dungeon / --bot-full / --bot-die): leave, clear or die, and where to walk next.
func bot_dungeon_tick() -> void:
	if _bot_scenario == "die" and main.cleared >= 2 and not main._bot_died:
		# Kill the character outright to exercise the live death -> debt -> town path.
		_bot_money_before = int(main.player.get("money"))
		(main.player.get("body") as Body).apply_damage(99999.0)
		main.player.call("_check_death")
		return
	var leave_now: bool = _bot_scenario == "gate" or main.cleared >= main.chambers
	if leave_now and main.passage_part._pad_in_reach():
		main._extract()
		return
	# the bot paths there itself (player._bot_way): no lining up with the doorway first
	var goal_local: Vector3
	if leave_now and not main.pads.is_empty():
		goal_local = main.level.to_local(main.pads.back().global_position)
	else:
		goal_local = Vector3(0.0, 0.0, -(float(main.cleared + 1) * main.ch_len + 4.0))
	main.player.set("bot_goal", main.level.to_global(goal_local))


## --shot-dungeon: wall 2 woke; slow to real time and take the shot.
func shot_dungeon_wall(c: int) -> void:
	if _shot_dungeon and c == 2:
		Engine.time_scale = 1.0
		main.player.set("bot", false)
		_shot_countdown = 25


func _tick_bot_report() -> void:
	var elapsed: int = Time.get_ticks_msec() - _bot_started_ms
	if main._bot_finished and main.state == "town":
		var ok := false
		if _bot_scenario == "die":
			var money_now: int = int(main.player.get("money"))
			var inv: Inventory = main.player.get("inventory")
			var left_behind: Array = main.player.get("corpses")
			ok = not bool(main.player.get("dead")) and money_now == _bot_money_before and main._last_payout == 0 \
				and inv.equipped.is_empty() and left_behind.size() == 1 and str((left_behind[0] as Dictionary)["where"]) == "passage"
			print("BOT[die]: alive=%s money %d -> %d payout=%d naked=%s corpses=%d state=%s -> %s" % [
				str(not bool(main.player.get("dead"))), _bot_money_before, money_now, main._last_payout, str(inv.equipped.is_empty()), left_behind.size(), main.state, "PASS" if ok else "FAIL"])
		else:
			var walls: int = main.chambers if _bot_scenario == "full" else main.gate_at
			var banked: int = 0
			for c: int in range(1, walls + 1):
				banked += main.stage_value * c
			var expected: int = int(float(banked) * (main.full_clear_bonus if walls == main.chambers else 1.0))
			ok = main._last_sealed and main._last_cleared == walls and main._last_payout == expected
			print("BOT[%s]: sealed=%s walls=%d payout=%d expected=%d money=%d -> %s" % [
				_bot_scenario, str(main._last_sealed), main._last_cleared, main._last_payout, expected, int(main.player.get("money")), "PASS" if ok else "FAIL"])
		Engine.time_scale = 1.0
		main.get_tree().quit(0 if ok else 1)
	elif elapsed > 120000:
		print("BOT: TIMEOUT state=%s sealed=%s current=%d cleared=%d -> FAIL" % [main.state, str(main.sealed), main.current, main.cleared])
		# what was still standing, and what it was doing - a stall is an enemy that could not be killed
		var here: Vector3 = main.level.to_local(main.player.global_position)
		print("BOT:   bot at local (%.1f, %.1f) chamber %d  vel %s  target %s  melee_cd %.2f recover %.2f stagger %.2f" % [
			here.x, here.z, int(-here.z / main.ch_len), str((main.player as CharacterBody3D).velocity), str(main.player.get("attack_target")),
			float(main.player.get("_melee_cd")), float(main.player.get("_recover_t")), float(main.player.get("_stagger_t"))])
		for n: Node in main.get_tree().get_nodes_in_group("enemies"):
			var e := n as Node3D
			var at: Vector3 = main.level.to_local(e.global_position)
			print("BOT:   left: %s at local (%.1f, %.1f) chamber %d  %.1f m away  hp %d  windup %.2f  stuck %.2f  leap %.2f  retreat_t %.2f  statuses %s" % [
				str(e.get("kind")), at.x, at.z, int(-at.z / main.ch_len), e.global_position.distance_to(main.player.global_position), int((e.get("body") as Body).hp),
				float(e.get("_windup")), float(e.get("_stuck_t")), float(e.get("_leap_left")), float(e.get("_retreat_t")), str((e.get("statuses") as Dictionary).keys())])
		Engine.time_scale = 1.0
		main.get_tree().quit(1)


func _save_shot() -> void:
	var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
	DirAccess.make_dir_recursive_absolute(dir)
	print("shot: player at %s" % str(main.player.global_position))
	# The headless renderer has no framebuffer to read.
	if DisplayServer.get_name() == "headless":
		main.get_tree().quit()
		return
	# what it cost to draw: frame rate, draw calls and triangles in view
	print("render: %d fps, %d draw calls, %d objects, %d primitives in view" % [Engine.get_frames_per_second(),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	var img: Image = main.get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(dir.path_join("shot.png"))
		print("shot saved")
	main.get_tree().quit()
