extends Node
## The performance probe (finish plan Phase 0): one busy scene of the real game, measured, windowed,
## at a fixed resolution with vsync off, judged against data/perf_budget.json.
##   godot --path game res://tests/perf_probe.tscn -- --scene=wall|stubble|town|nether|skills
##       [--zoom=default|far|<0..1>] [--seconds=12] [--warmup=4] [--wall=10] [--res=1920x1080] [--perf-shot] [--trace=<ms>] [--no-hud]
## Scenes (each the whole game - main.tscn - with a scripted, invulnerable player, the `bot` flag):
##   wall    the assault passage's densest wall (wall 10: 13 real bodies, commander and archers), awake and
##           fighting; enemies are made too tough to die, so the fight lasts the whole measurement. The
##           player waits at the doorway and steps in a second into the warm-up, when the wall wakes as it
##           does in play: the frame its bodies are built in is "spawn_ms" (and counts as a startup hitch)
##   stubble the Stubble by the tree camp, it and two more camps awake and fighting
##   town    the town, the player walking a loop through the townsfolk
##   nether  the Stubble's Netherecho at the dry well, the projection out, extra constructs fighting it
##   skills  wall 10's pack hit by six area skills of six affinities in turn (zones, a cloud, chains,
##           delayed blasts) - statuses, zones and numbers all at once
## Prints ONE machine-readable line, "PERF scene=... key=value ...", then "PERF: PASS" or "PERF: FAIL <why>",
## and exits 0 / 1. Frame time is wall-clock between frames; cpu_render_ms and gpu_ms are the renderer's
## own measurements (RenderingServer.viewport_get_measured_render_time_*); process_ms / physics_ms are the
## frame's _process and _physics_process steps (every script and what it calls), timed between a node that
## runs first and one that runs last (Performance.TIME_PROCESS is a per-second maximum, not this). The warm-up's
## frames (from the scene's build on) are counted for hitches separately: "startup_hitches". `--perf-shot`
## saves the last frame to shots/perf-<scene>-<zoom>.png. It moves nothing on the desktop, but other
## programs running at the same time skew it - run each scene a few times and take the median
## (tools/perf/perf_all.sh does).


const SKILL_SET: Array[String] = ["slag_pool", "whiteout", "forked_path", "teeming_fog", "cave_in", "drench"]
const SKILL_AFFS: Array[String] = ["fire", "ice", "lightning", "disease", "earth", "water"]
const TOWN_LOOP: Array = [[2.5, 5.5], [-6.0, -6.0], [-12.0, 2.0], [-6.0, 8.0], [4.0, 8.0], [6.0, -2.0]]

var main: Node
var player: Node3D
var errors: ErrorCatcher
var budget: Dictionary = {}

var scene := "wall"
var zoom_name := "default"
var zoom := 0.5
var seconds := 12.0
var warmup := 4.0
var wall := 10
var res := Vector2i(1920, 1080)
var shot := false
var trace_ms := 0.0                        # --trace=<ms>: print every measured frame slower than this
var _last_event := ""

var _phase := "boot"
var _boot_frames := 0
var _t := 0.0
var _last_us := 0
var _startup_ms: Array[float] = []
var _ms: Array[float] = []
var _cpu_render := 0.0
var _gpu := 0.0
var _proc_ms := 0.0
var _phys_ms := 0.0
var _nav := 0.0
var _draws := 0.0
var _draws_max := 0
var _objects := 0.0
var _prims := 0.0
var _samples := 0
var _actors := 0
var _town_i := 0
var _town_t := 0.0
var _cast_t := 0.0
var _cast_i := 0
var _skill_index: Array[int] = []
var _wake_frame := -1                      # wall / skills: the warm-up frame the wall woke in
var _spawn_ms := 0.0
var _setup_ms := 0.0                       # building the scene (the level load, a loading moment)
var _tail: Tail
var proc_start_us := 0
var phys_start_us := 0
var _prev_proc_start := 0
var no_hud := false


## Runs after every other node's _process / _physics_process: with the probe running first, the
## difference is what every script (and the engine work they call) took this frame.
class Tail extends Node:
	var head: Node
	var last_proc_ms := 0.0
	var phys_ms_frame := 0.0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	var proc_end_us := 0
	var phys_end_us := 0

	func _process(_delta: float) -> void:
		proc_end_us = Time.get_ticks_usec()
		last_proc_ms = float(proc_end_us - int(head.get("proc_start_us"))) / 1000.0

	func _physics_process(_delta: float) -> void:
		phys_end_us = Time.get_ticks_usec()
		phys_ms_frame += float(phys_end_us - int(head.get("phys_start_us"))) / 1000.0


func _physics_process(_delta: float) -> void:
	phys_start_us = Time.get_ticks_usec()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000000            # first in the frame, so the clock reads frame to frame
	process_physics_priority = -1000000
	_tail = Tail.new()                     # last in the frame: what the scripts took is the time between
	_tail.process_priority = 1000000
	_tail.process_physics_priority = 1000000
	_tail.head = self
	add_child(_tail)
	errors = ErrorCatcher.install()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
		elif a.begins_with("--zoom="):
			zoom_name = a.trim_prefix("--zoom=")
		elif a.begins_with("--seconds="):
			seconds = float(a.trim_prefix("--seconds="))
		elif a.begins_with("--warmup="):
			warmup = float(a.trim_prefix("--warmup="))
		elif a.begins_with("--wall="):
			wall = int(a.trim_prefix("--wall="))
		elif a.begins_with("--res="):
			var wh: PackedStringArray = a.trim_prefix("--res=").split("x")
			res = Vector2i(int(wh[0]), int(wh[1]))
		elif a == "--perf-shot":
			shot = true
		elif a.begins_with("--trace="):
			trace_ms = float(a.trim_prefix("--trace="))
		elif a == "--no-hud":
			no_hud = true                          # diagnosis: what the HUD's drawing costs
	var f: FileAccess = FileAccess.open("res://data/perf_budget.json", FileAccess.READ)
	budget = JSON.parse_string(f.get_as_text()) if f != null else {}
	var cam: Dictionary = GameData.balance["camera"]
	zoom = float(cam["zoom_default"]) if zoom_name == "default" else (0.0 if zoom_name == "far" else (1.0 if zoom_name == "near" else clampf(float(zoom_name), 0.0, 1.0)))
	_window()
	seed(20261108)
	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	main.set("_test_mode", true)
	add_child(main)


## A fixed size, vsync off, no frame cap. A screen exactly the size asked for gets a borderless window
## over it (a decorated one would not fit); a bigger screen a centred window.
func _window() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if DisplayServer.get_name() == "headless":
		return
	var screen: Vector2i = DisplayServer.screen_get_size()
	var size: Vector2i = Vector2i(mini(res.x, screen.x), mini(res.y, screen.y))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, size == screen)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - size) / 2)
	res = size


func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	_prev_proc_start = proc_start_us
	proc_start_us = now
	var frame_ms: float = float(now - _last_us) / 1000.0 if _last_us > 0 else 0.0
	_last_us = now
	match _phase:
		"boot":
			_boot_frames += 1
			if _boot_frames >= 3:
				var s0: int = Time.get_ticks_usec()
				_setup()
				_setup_ms = float(Time.get_ticks_usec() - s0) / 1000.0
				_phase = "warm"
				_t = 0.0
		"warm":
			if trace_ms > 0.0 and frame_ms > trace_ms:
				print("PERF trace warm t=%.2f frame_ms=%.1f process_ms=%.1f physics_ms=%.1f nodes=%d last=%s" % [_t, frame_ms,
					_tail.last_proc_ms, _tail.phys_ms_frame, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _last_event])
			_tail.phys_ms_frame = 0.0
			_drive(delta)
			_startup_ms.append(frame_ms)
			if _wake_frame >= 0 and _startup_ms.size() - 1 >= _wake_frame and _startup_ms.size() - 1 <= _wake_frame + 1:
				_spawn_ms = maxf(_spawn_ms, frame_ms)      # the frame the wall's bodies were built in (and the next)
			_t += delta
			if _wake_frame < 0 and (scene == "wall" or scene == "skills") and _t >= minf(1.0, warmup * 0.5):
				_wake_wall()
				_toughen()
				_actors = _count_actors()
				_wake_frame = _startup_ms.size()
			if _t >= warmup:
				_phase = "measure"
				_t = 0.0
				RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		"measure":
			if trace_ms > 0.0 and frame_ms > trace_ms:
				# after_physics: from the last physics callback to now (the physics server's step and what is
				# flushed after it); after_process: from the end of last frame's callbacks to now (deferred
				# calls, canvas redraws, skeleton updates, the renderer and the present)
				var after_phys: float = float(now - _tail.phys_end_us) / 1000.0 if _tail.phys_end_us > _prev_proc_start else 0.0
				print("PERF trace t=%.2f frame_ms=%.1f process_ms=%.1f physics_ms=%.1f after_physics_ms=%.1f after_process_ms=%.1f nodes=%d last=%s" % [_t, frame_ms,
					_tail.last_proc_ms, _tail.phys_ms_frame, after_phys, float(now - _tail.proc_end_us) / 1000.0 - after_phys - _tail.phys_ms_frame,
					int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), _last_event])
			_drive(delta)
			_ms.append(frame_ms)
			_sample()
			_t += delta
			if _t >= seconds:
				_phase = "done"
				_finish()


func _setup() -> void:
	main.call("_show_screen", null, false)
	main.call("start_new_character", 0)
	player = main.get("player")
	(main.get("rng") as RandomNumberGenerator).seed = 20261108
	match scene:
		"wall":
			_enter_wall()
		"skills":
			player.call("set_affinities", SKILL_AFFS)
			for id: String in SKILL_SET:
				player.call("learn", id)
			var list: Array = player.get("abilities")
			for id2: String in SKILL_SET:
				for i: int in list.size():
					if str(list[i]["id"]) == id2:
						_skill_index.append(i)
			_enter_wall()
		"stubble":
			main.call("walk_out")
			_stand(150.0, 100.0)
			var camps: FieldCamps = main.get("field_camps")
			var here: Vector3 = (main.get("level") as Node3D).to_local(player.global_position)
			for id: String in ["tree_camp", "the_sounder", "the_herd"]:
				camps.wake_camp(id, here)
			player.set("bot", true)
		"town":
			main.call("_enter_town", "square")
			player.set("bot", true)
			_town_goal()
		"nether":
			main.call("walk_out")
			_stand(96.0, 74.0)
			main.call("toggle_projection")
			var nether: Netherecho = main.get("nether")
			var level: Node3D = main.get("level")
			var zb: ZoneBuilder = main.get("_zone")
			nether.projection.global_position = level.to_global(zb.to_local(99.0, 68.0))
			nether.projection.set("hp_max", 1.0e9)
			nether.projection.set("hp", 1.0e9)
			nether.projection.set("input_blocked", true)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var spots: Array = [[95.0, 63.0, "vestige"], [104.0, 66.0, "vestige"], [101.0, 73.0, "remnant"], [93.0, 70.0, "remnant"]]
			for s: Array in spots:
				var wid: String = ConstructWords.pick_wild(str(s[2]), player.get("affinities"), rng)
				nether.spawn_construct(nether.to_local(level.to_global(zb.to_local(float(s[0]), float(s[1])))), str(s[2]), wid, false)
			for i: int in 8:
				var at: Vector3 = level.to_global(zb.to_local(99.0 + rng.randf_range(-7.0, 7.0), 68.0 + rng.randf_range(-7.0, 7.0)))
				nether.spawn_wisp(nether.to_local(at), "plain")
			for c: Node in get_tree().get_nodes_in_group("nether_enemies"):
				c.set("body", Body.new(1.0e9))
				c.set("target", nether.projection)
		_:
			push_error("perf_probe: unknown scene " + scene)
	_toughen()
	if no_hud:
		(main.get("hud") as CanvasItem).visible = false
	main.set("_cam_zoom_target", zoom)
	main.set("cam_zoom", zoom)
	_actors = _count_actors()


func _enter_wall() -> void:
	main.call("_enter_dungeon")
	var level: Node3D = main.get("level")
	var ch_len: float = float(main.get("ch_len"))
	main.set("sealed", true)
	# the walls before it are behind you; you stand at the doorway, and step through when it wakes (_wake_wall)
	main.set("cleared", wall - 1)
	main.set("current", wall - 1)
	if main.has_method("_prebuild_bodies"):
		main.call("_prebuild_bodies", main.call("_wall_kinds", wall))   # as clearing the wall before does
	player.global_position = level.to_global(Vector3(0.0, 0.0, -float(wall) * ch_len + 3.0))
	player.set("bot", true)


## You step into the wall's chamber and it wakes - the frame the game builds its bodies in.
func _wake_wall() -> void:
	main.call("_activate", wall)
	var level: Node3D = main.get("level")
	player.global_position = level.to_global(Vector3(0.0, 0.0, -float(wall) * float(main.get("ch_len")) - 3.0))


func _stand(x: float, y: float) -> void:
	var zb: ZoneBuilder = main.get("_zone")
	player.global_position = (main.get("level") as Node3D).to_global(zb.to_local(x, y))
	main.call("_reveal")


## Nothing dies while it is measured: the fight goes on for the whole run, the same each time.
func _toughen() -> void:
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		e.set("body", Body.new(1.0e9))


func _count_actors() -> int:
	var n: int = get_tree().get_nodes_in_group("enemies").size() + get_tree().get_nodes_in_group("nether_enemies").size()
	var town: TownBuilder = main.get("_town")
	if scene == "town" and town != null:
		n += town.folk.size()
	return n + 1


func _town_goal() -> void:
	var p: Array = TOWN_LOOP[_town_i % TOWN_LOOP.size()]
	var level: Node3D = main.get("level")
	player.set("bot_goal", level.to_global(Vector3(float(p[0]), 0.0, float(p[1]))))
	_town_i += 1


## What keeps the scene busy while it runs.
func _drive(delta: float) -> void:
	match scene:
		"town":
			_town_t += delta
			var goal: Vector3 = player.get("bot_goal")
			if _town_t > 4.0 or Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z).length() < 1.0:
				_town_t = 0.0
				_town_goal()
		"skills":
			_cast_t -= delta
			if _cast_t > 0.0 or _skill_index.is_empty():
				return
			_cast_t = 0.45
			var foes: Array[Node] = get_tree().get_nodes_in_group("enemies")
			if foes.is_empty():
				return
			var centre := Vector3.ZERO
			for e: Node in foes:
				centre += (e as Node3D).global_position
			centre /= float(foes.size())
			var near: Node3D = null
			for e2: Node in foes:
				if near == null or (e2 as Node3D).global_position.distance_to(centre) < near.global_position.distance_to(centre):
					near = e2
			player.set("essence", float(player.get("essence_max")))
			player.call("clear_reflux")
			player.set("_recover_t", 0.0)
			player.set("cursor_fixed", centre)
			player.set("hovered", near)
			var c0: int = Time.get_ticks_usec()
			player.call("cast_ability", _skill_index[_cast_i % _skill_index.size()])
			_last_event = "%s@%.2f(cast %.1f ms)" % [SKILL_SET[_cast_i % SKILL_SET.size()], _t, float(Time.get_ticks_usec() - c0) / 1000.0]
			_cast_i += 1


func _sample() -> void:
	var rid: RID = get_viewport().get_viewport_rid()
	_cpu_render += RenderingServer.viewport_get_measured_render_time_cpu(rid) + RenderingServer.get_frame_setup_time_cpu()
	_gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	_proc_ms += _tail.last_proc_ms
	_phys_ms += _tail.phys_ms_frame
	_tail.phys_ms_frame = 0.0
	_nav += Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0
	var d: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	_draws += float(d)
	_draws_max = maxi(_draws_max, d)
	_objects += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	_prims += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	_samples += 1


## The process's working set in MB (what Task Manager shows), or -1 where it cannot be read.
func _working_set_mb() -> float:
	if OS.get_name() != "Windows":
		return -1.0
	var out: Array = []
	OS.execute("powershell", ["-NoProfile", "-Command", "(Get-Process -Id %d).WorkingSet64" % OS.get_process_id()], out)
	return float(str(out[0]).strip_edges()) / 1048576.0 if not out.is_empty() and str(out[0]).strip_edges().is_valid_int() else -1.0


func _finish() -> void:
	var n: int = maxi(1, _ms.size())
	var total := 0.0
	for m: float in _ms:
		total += m
	var sorted: Array[float] = _ms.duplicate()
	sorted.sort()
	var worst: int = maxi(1, int(ceil(float(n) * 0.01)))
	var worst_sum := 0.0
	for i: int in worst:
		worst_sum += sorted[n - 1 - i]
	var avg_ms: float = total / float(n)
	var low1_ms: float = worst_sum / float(worst)
	var hitch_ms: float = float(budget.get("hitch_ms", 33.3))
	var hitches := 0
	for m2: float in _ms:
		if m2 > hitch_ms:
			hitches += 1
	var skip: int = int(budget.get("startup_skip_frames", 3))
	var startup_hitches := 0
	var startup_max := 0.0
	for i2: int in range(skip, _startup_ms.size()):
		startup_max = maxf(startup_max, _startup_ms[i2])
		if _startup_ms[i2] > hitch_ms:
			startup_hitches += 1
	var s: float = float(maxi(1, _samples))
	var ws: float = _working_set_mb()
	var r := {
		"scene": scene, "zoom": "%s(%.2f)" % [zoom_name, zoom], "res": "%dx%d" % [res.x, res.y], "frames": _ms.size(),
		"fps_avg": 1000.0 / avg_ms, "fps_low1": 1000.0 / low1_ms, "ms_avg": avg_ms, "ms_p99": sorted[clampi(int(float(n) * 0.99), 0, n - 1)],
		"ms_max": sorted[n - 1], "cpu_render_ms": _cpu_render / s, "gpu_ms": _gpu / s, "process_ms": _proc_ms / s, "physics_ms": _phys_ms / s,
		"nav_ms": _nav / s, "draw_calls": _draws / s, "draw_calls_max": _draws_max, "objects": _objects / s, "primitives": _prims / s,
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "mem_static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"vmem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, "ws_mb": ws, "hitches": hitches,
		"startup_hitches": startup_hitches, "startup_max_ms": startup_max, "spawn_ms": _spawn_ms, "setup_ms": _setup_ms, "actors": _actors, "errors": errors.count(),
	}
	var parts: Array[String] = []
	for k: String in r:
		var v: Variant = r[k]
		parts.append("%s=%s" % [k, ("%.2f" % v) if v is float else str(v)])
	print("PERF " + " ".join(parts))
	var why: Array[String] = []
	if float(r["fps_avg"]) < float(budget.get("fps_avg_min", 60.0)):
		why.append("fps_avg %.1f < %.1f" % [r["fps_avg"], float(budget.get("fps_avg_min", 60.0))])
	if float(r["fps_low1"]) < float(budget.get("fps_low1_min", 60.0)):
		why.append("fps_low1 %.1f < %.1f" % [r["fps_low1"], float(budget.get("fps_low1_min", 60.0))])
	if _draws_max > int(budget.get("draw_calls_max", 2000)):
		why.append("draw calls %d > %d" % [_draws_max, int(budget.get("draw_calls_max", 2000))])
	if ws > float(budget.get("memory_mb_max", 2048.0)):
		why.append("working set %.0f MB > %.0f" % [ws, float(budget.get("memory_mb_max", 2048.0))])
	if hitches > int(budget.get("hitches_max", 0)):
		why.append("%d hitches > %d" % [hitches, int(budget.get("hitches_max", 0))])
	if startup_hitches > int(budget.get("startup_hitches_max", 0)):
		why.append("%d startup hitches (worst %.0f ms) > %d" % [startup_hitches, startup_max, int(budget.get("startup_hitches_max", 0))])
	if errors.count() > 0:
		why.append("%d script errors, first: %s" % [errors.count(), errors.first()])
	print("PERF: PASS" if why.is_empty() else "PERF: FAIL " + "; ".join(why))
	if shot and DisplayServer.get_name() != "headless":
		var dir: String = ProjectSettings.globalize_path("res://").path_join("../shots")
		DirAccess.make_dir_recursive_absolute(dir)
		var img: Image = get_viewport().get_texture().get_image()
		var file: String = dir.path_join("perf-%s-%s.png" % [scene, zoom_name])
		if img != null:
			img.save_png(file)
			print("PERF shot: " + file)
	get_tree().quit(0 if why.is_empty() else 1)
