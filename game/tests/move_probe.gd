extends Node
## Click-to-move probe (windowed run only - the cursor must be real):
##   godot --path game res://tests/move_probe.tscn
## Brent 2026-10-24: "When I click on screen the character sometimes runs the wrong way...and there
## is no way to make him run the right way." Clicks the ground all over the screen (every direction,
## the edges, the top, at zoom 0, 0.5 and 1) in town, in the Stubble and in the arena, and in the
## Stubble beside a camp asleep and awake, the herd, hounds at your back, a buried lurker and a hound
## held in the camera's own plane; also a second click straight after a first, a held and dragged
## button, a click after a dash, during and after a wind-up, and after clicking a townsperson. For
## every click: the player must head for the clicked ground point (direction within ANGLE_TOL,
## distance shrinking); a click that takes a target must have had it under the cursor (or its
## footprint under the clicked point); and the drawn body (shoulders and hips of the skeleton) must
## face the way it runs, averaged over the run.
## Regression test for (2026-10-24): a body straddling the camera's plane caught every click
## (Pick.standing_in_view); a click above the horizon went backwards (Pick.ground); a ground click
## in town was overridden by an earlier click on a townsperson (main._town_click).
## The cursor is moved with Input.warp_mouse (the game reads the real cursor, as in play) and the
## button goes through Input.parse_input_event, so this moves the OS cursor while it runs - do not
## touch the mouse. Waits on game time. `-- --only=<part>|<part>` runs the cases whose name has one
## of the parts; `--verbose` prints every case. Prints "MOVE: PASS" or the failing cases, exits 0/1.

const ANGLE_TOL := 35.0             # degrees between where it went and where it was sent
const FACE_TOL := 40.0              # degrees between where the body faces and where it went
const WATCH_S := 0.5                # how long a click is watched for
const TIMEOUT_MS := 600000

var main: Node
var player: Node3D
var cam: Camera3D
var _errors: ErrorCatcher
var _cases: Array[Dictionary] = []
var _i := 0
var _stage := "place"
var _t := 0.0
var _place := ""
var _base := {}                     # place -> where the player stands for each case
var _start := Vector3.ZERO
var _goal := Vector3.ZERO           # the ground point the click was aimed at
var _sent := Vector3.ZERO           # flat direction from the start to it
var _failures: Array[String] = []
var _ran := 0
var _skipped := 0
var _started_ms := 0
var _verbose := false
var _drag_k := 0
var _hover_at_press := ""
var _under := false                 # the thing hovered at the press really is under the cursor
var _took: Node3D = null            # what the click took as its target (attack or pickup), if anything
var _took_footprint := false        # ... and its footprint held the clicked ground point then
var _strikable: Array = []          # what the click may rightly strike (under the cursor or the point)
var _face_mid := -1.0               # degrees between the body's facing and its velocity, mid-run
var _face_sum := Vector3.ZERO
var _vel_sum := Vector3.ZERO
var _plane_beast: Node3D = null
var _target_after := ""
var _target_before := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_errors = ErrorCatcher.install()
	_started_ms = Time.get_ticks_msec()
	_verbose = OS.get_cmdline_user_args().has("--verbose")
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	main.set("_test_mode", true)
	add_child(main)
	_build_cases()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			var only: String = arg.get_slice("=", 1)
			_cases = _cases.filter(func(c: Dictionary) -> bool:
				for part: String in only.split("|"):
					if str(c["name"]).contains(part):
						return true
				return false)


# --- input -------------------------------------------------------------------------------------

func _px(frac: Vector2) -> Vector2:
	return frac * get_viewport().get_visible_rect().size


func _point(at: Vector2) -> void:
	Input.warp_mouse(at)


func _button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)


# --- geometry ----------------------------------------------------------------------------------

## Where the ray through a screen point meets the ground the player stands on; for a ray that never
## comes down (above the horizon) the far point straight out along it.
static func ground_under(c: Camera3D, at: Vector2, y: float) -> Vector3:
	var o: Vector3 = c.project_ray_origin(at)
	var n: Vector3 = c.project_ray_normal(at)
	if n.y < -0.0001:
		return o + n * ((y - o.y) / n.y)
	var flat := Vector3(n.x, 0.0, n.z).normalized()
	return Vector3(o.x, y, o.z) + flat * 1000.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _deg(a: Vector3, b: Vector3) -> float:
	if a.length() < 0.0001 or b.length() < 0.0001:
		return 180.0
	return rad_to_deg(_flat(a).angle_to(_flat(b)))


## Which way the drawn body faces, read off the real body's skeleton: square to the line from its
## right shoulder and hip to its left ones (the posed bones, so a clip or retarget that turned the
## body would show). Else the model's -Z.
func _body_facing() -> Vector3:
	var rig: Node = player.get("_rig")
	if rig != null:
		for n: Node in rig.find_children("*", "Skeleton3D", true, false):
			var sk := n as Skeleton3D
			var across := Vector3.ZERO
			for pair: Array in [["RightArm", "LeftArm"], ["RightUpLeg", "LeftUpLeg"]]:
				var r: int = _bone(sk, str(pair[0]))
				var l: int = _bone(sk, str(pair[1]))
				if r >= 0 and l >= 0:
					across += (sk.global_transform * sk.get_bone_global_pose(r).origin) - (sk.global_transform * sk.get_bone_global_pose(l).origin)
			var fwd: Vector3 = _flat(Vector3.UP.cross(across))
			if fwd.length() > 0.001:
				return fwd.normalized()
		if rig is Node3D:
			return _flat(-(rig as Node3D).global_transform.basis.z).normalized()
	return _flat(-player.global_transform.basis.z).normalized()


static func _bone(sk: Skeleton3D, suffix: String) -> int:
	for b: int in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with(suffix):
			return b
	return -1


# --- cases -------------------------------------------------------------------------------------

## A grid of screen points: every direction from the middle at two radii, the four edges, and the
## top of the screen where the ray is shallowest.
func _grid() -> Array[Vector2]:
	var pts: Array[Vector2] = []
	for k: int in 8:
		var a: float = TAU * float(k) / 8.0
		for r: float in [0.18, 0.36]:
			pts.append(Vector2(0.5 + cos(a) * r * 0.5625, 0.5 + sin(a) * r))
	for p: Vector2 in [Vector2(0.03, 0.5), Vector2(0.97, 0.5), Vector2(0.5, 0.03), Vector2(0.5, 0.97),
			Vector2(0.08, 0.04), Vector2(0.92, 0.04), Vector2(0.3, 0.1), Vector2(0.7, 0.1), Vector2(0.62, 0.38)]:
		pts.append(p)
	return pts


func _build_cases() -> void:
	for place: String in ["town", "field", "arena"]:
		for zoom: float in [0.0, 0.5, 1.0]:
			for p: Vector2 in _grid():
				_cases.append({"name": "%s z%.1f click (%.2f,%.2f)" % [place, zoom, p.x, p.y], "place": place, "zoom": zoom, "at": p})
	# a second click straight after a first, the opposite way
	for zoom: float in [0.0, 1.0]:
		_cases.append({"name": "field z%.1f re-click opposite" % zoom, "place": "field", "zoom": zoom, "pre": Vector2(0.3, 0.75), "at": Vector2(0.7, 0.3)})
		_cases.append({"name": "field z%.1f hold and drag" % zoom, "place": "field", "zoom": zoom, "at": Vector2(0.3, 0.3), "drag": [Vector2(0.7, 0.3), Vector2(0.7, 0.7), Vector2(0.25, 0.65)]})
	# beside the camps: the Stubble's beasts awake round the player, then ground clicks every way
	for zoom: float in [0.5, 1.0]:
		for p: Vector2 in [Vector2(0.62, 0.38), Vector2(0.7, 0.3), Vector2(0.3, 0.3), Vector2(0.3, 0.7), Vector2(0.7, 0.7), Vector2(0.5, 0.15), Vector2(0.5, 0.85)]:
			_cases.append({"name": "camp-awake z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "camp_awake"})
			_cases.append({"name": "camp-asleep z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "camp_asleep"})
			_cases.append({"name": "beast-behind z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "beast_behind"})
			_cases.append({"name": "lurker z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "lurker"})
			_cases.append({"name": "herd z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "herd"})
	# a beast standing in the camera's own plane, off to the side: out of sight, but a naive
	# unprojection of its body crosses the whole screen
	for zoom: float in [0.0, 0.5, 1.0]:
		for p: Vector2 in [Vector2(0.62, 0.38), Vector2(0.3, 0.3), Vector2(0.7, 0.7), Vector2(0.3, 0.7)]:
			_cases.append({"name": "beast-at-camera z%.1f click (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "field", "zoom": zoom, "at": p, "setup": "beast_at_camera"})
	# states that hold the feet
	# after the dash is over: a dash commits (dash_time + dash_recovery_s), and a click made inside it waits
	_cases.append({"name": "field after a dash", "place": "field", "zoom": 0.5, "at": Vector2(0.3, 0.3), "setup": "dash",
		"delay": float(GameData.ability("hydraulic_flex")["dash_time"]) + GameData.num("combat", "dash_recovery_s") + 0.1})
	# a wind-up roots you (design/05 2.3): a click during it is not acted on, one after it is
	# a click in a wind-up is kept (balance.json "feel"): you stay set until it goes off, then walk there
	_cases.append({"name": "field click during a wind-up", "place": "field", "zoom": 0.5, "at": Vector2(0.3, 0.3), "setup": "windup", "rooted": true, "watch": 0.15})
	_cases.append({"name": "field click during a wind-up is walked after it", "place": "field", "zoom": 0.5, "at": Vector2(0.3, 0.3), "setup": "windup", "watch": 1.2})
	_cases.append({"name": "field click after a wind-up", "place": "field", "zoom": 0.5, "at": Vector2(0.3, 0.3), "setup": "windup", "delay": 1.0})
	for zoom: float in [0.5, 1.0]:
		for p: Vector2 in [Vector2(0.5, 0.75), Vector2(0.2, 0.4), Vector2(0.8, 0.4)]:
			_cases.append({"name": "town z%.1f after clicking a townsperson (%.2f,%.2f)" % [zoom, p.x, p.y], "place": "town", "zoom": zoom, "at": p, "setup": "townsperson", "delay": 0.4})


# --- the run -----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if Time.get_ticks_msec() - _started_ms > TIMEOUT_MS:
		_failures.append("timed out at case %d" % _i)
		_finish()
		return
	player = main.get("player")
	cam = main.get("camera")
	if player == null or cam == null:
		return
	_t += delta
	if _i >= _cases.size():
		_finish()
		return
	var c: Dictionary = _cases[_i]
	_keep_alive()
	if str(c.get("setup", "")) == "beast_at_camera" and _stage != "place" and _stage != "arrive" and _stage != "reset":
		_hold_at_camera()
	match _stage:
		"place":
			if _t < 0.3:
				return
			if _place != str(c["place"]) or not _in_place(_place):
				_go(str(c["place"]))
				_t = 0.0
				_stage = "arrive"
				return
			_stage = "reset"
			_t = 0.0
		"arrive":
			if _t < 1.0:
				return
			_place = str(c["place"])
			if not _base.has(_place):
				_base[_place] = player.global_position
				if _place == "field":
					# open stubble, away from the Dross Gate and the camps
					var zb: ZoneBuilder = main.get("_zone")
					_base[_place] = (main.get("level") as Node3D).to_global(zb.to_local(60.0, 56.0))
			_stage = "reset"
			_t = 0.0
		"reset":
			_reset(c)
			_stage = "setup"
			_t = 0.0
		"setup":
			if _t < 0.25:
				return
			_setup(c)
			_t = 0.0
			_stage = "delay"
		"delay":
			if _t < float(c.get("delay", 0.0)):
				return
			_t = 0.0
			_stage = "pre" if c.has("pre") else "aim"
		"pre":
			var at: Vector2 = _px(c["pre"])
			if _t < 0.05:
				_point(at)
				return
			_button(at, true)
			_button(at, false)
			_t = 0.0
			_stage = "pre_wait"
		"pre_wait":
			if _t < 0.25:
				return
			_t = 0.0
			_stage = "aim"
		"aim":
			var at2: Vector2 = _px(c["at"])
			if bool(main.get("hud").call("ui_at", at2)):
				_skipped += 1
				_next()
				return
			_point(at2)
			_t = 0.0
			_stage = "press"
		"press":
			if _t < 0.06:
				return
			var at3: Vector2 = _px(c["at"])
			_start = player.global_position
			_goal = ground_under(cam, at3, player.global_position.y)
			_sent = _flat(_goal - _start)
			_hover_at_press = _describe(player.get("hovered"))
			_under = _under_cursor(player.get("hovered"), at3)
			# what the click could strike: the hovered thing if it is under the cursor, and anything
			# whose footprint holds the clicked ground point
			_strikable.clear()
			if _under:
				_strikable.append(player.get("hovered"))
			for n: Node in get_tree().get_nodes_in_group("hittable"):
				if _flat((n as Node3D).global_position - _goal).length() <= float(n.get("radius")) + 0.5:
					_strikable.append(n)
			_target_before = _describe(player.get("attack_target"))
			_target_after = "none"
			_took = null
			_face_mid = -1.0
			_face_sum = Vector3.ZERO
			_vel_sum = Vector3.ZERO
			_button(at3, true)
			_drag_k = 0
			_t = 0.0
			_stage = "hold" if c.has("drag") else "release"
		"release":
			_note_took()
			if _t < 0.05:
				return
			_button(_px(c["at"]), false)
			_stage = "watch"
		"hold":
			# drag the held button across the screen; the goal is where it ends
			var path: Array = c["drag"]
			if _t >= 0.25 * float(_drag_k + 1) and _drag_k < path.size():
				var to: Vector2 = _px(path[_drag_k])
				_point(to)
				_drag_k += 1
				if _drag_k == path.size():
					# measure from here: where it is now, towards where the button lets go
					_start = player.global_position
					_goal = ground_under(cam, to, player.global_position.y)
					_sent = _flat(_goal - _start)
				return
			if _drag_k >= path.size() and _t >= 0.25 * float(path.size()) + 0.06:
				var last: Vector2 = _px(path[path.size() - 1])
				_start = player.global_position
				_goal = ground_under(cam, last, player.global_position.y)
				_sent = _flat(_goal - _start)
				_button(last, false)
				_t = 0.0
				_stage = "watch"
		"watch":
			if _t < 0.15:
				_note_took()
			var vel: Vector3 = _flat(player.get("velocity"))
			if _t > 0.15 and vel.length() > 1.0:
				_face_sum += _body_facing()
				_vel_sum += vel.normalized()
				_face_mid = _deg(_face_sum, _vel_sum)
			if _t < float(c.get("watch", WATCH_S)):
				return
			_judge(c)
			_next()


## The first thing the click takes as its target (a bush cut in one blow is gone by the next frame).
func _note_took() -> void:
	if _took != null:
		return
	for key: String in ["attack_target", "pickup_target"]:
		var v: Variant = player.get(key)
		if v != null and is_instance_valid(v):
			_took = v as Node3D
	if _took != null:
		_target_after = _describe(_took)
		_took_footprint = _flat(_took.global_position - _goal).length() <= float(_took.get("radius")) + 0.5


func _next() -> void:
	_i += 1
	_t = 0.0
	_stage = "place"


func _in_place(place: String) -> bool:
	var st: String = str(main.get("state"))
	match place:
		"town":
			return st == "town"
		"field":
			return st == "field"
		"arena":
			return st == "arena_rest" or st == "arena_fight"
	return false


func _camps() -> FieldCamps:
	var v: Variant = main.get("field_camps")
	if v == null or not is_instance_valid(v) or str(main.get("state")) != "field":
		return null
	return v as FieldCamps


func _go(place: String) -> void:
	get_tree().paused = false
	match place:
		"town":
			if str(main.get("state")) == "select":
				main.call("start_new_character", 0)
			else:
				main.call("_enter_town")
		"field":
			if str(main.get("state")) == "select":
				main.call("start_new_character", 0)
			main.call("walk_out")
		"arena":
			if str(main.get("state")) == "select":
				main.call("start_new_character", 0)
			main.call("enter_arena")


## Nothing in the field should end a case early: no wounds that matter, no stagger, no death.
func _keep_alive() -> void:
	if str(main.get("state")) == "arena_rest":
		main.set("rest_timer", 999.0)          # no wave: the arena cases are about the ground
	var body: Variant = player.get("body")
	if body != null:
		(body as Object).call("heal", 1000.0)


func _reset(c: Dictionary) -> void:
	_button(Vector2.ZERO, false)
	player.global_position = _base.get(_place, player.global_position)
	player.set("has_move_goal", false)
	player.set("attack_target", null)
	player.set("pickup_target", null)
	player.set("velocity", Vector3.ZERO)
	player.set("_stagger_t", 0.0)
	player.set("_shoved_left", 0.0)
	main.set("_walk_to", null)
	main.set("_cam_zoom_target", float(c["zoom"]))
	main.set("cam_zoom", float(c["zoom"]))
	# beasts woken by an earlier case go back to where they were
	var camps: FieldCamps = _camps()
	if camps != null and _place == "field":
		for e: Node in camps.all_living():
			(e as Node3D).global_position = (e as Node3D).get_meta("probe_home", (e as Node3D).global_position)
			(e as Node3D).set_meta("probe_home", (e as Node3D).global_position)


func _setup(c: Dictionary) -> void:
	var camps: FieldCamps = _camps()
	if camps == null and _place == "field":
		_failures.append("%s: no camps in the field" % str(c["name"]))
		return
	match str(c.get("setup", "")):
		"camp_awake", "camp_asleep", "herd":
			var id: String = "the_herd" if str(c["setup"]) == "herd" else "tip_pickers"
			var members: Array = camps.members_of(id)
			if members.is_empty():
				return
			var centre := Vector3.ZERO
			for e: Node in members:
				centre += (e as Node3D).global_position
			centre /= float(members.size())
			# stand a few metres off the camp, down-screen of it (the camp up and to the right)
			player.global_position = centre + Vector3(-1.0, 0.0, 4.0)
			player.global_position.y = (_base["field"] as Vector3).y
			if str(c["setup"]) == "camp_awake":
				camps.wake_camp(id)
		"beast_behind":
			var hounds: Array = camps.members_of("the_ditch")
			if hounds.is_empty():
				return
			var back := Vector3(sin(deg_to_rad(GameData.num("camera", "yaw_deg"))), 0.0, cos(deg_to_rad(GameData.num("camera", "yaw_deg"))))
			var k := 0
			for e: Node in hounds:
				(e as Node3D).global_position = player.global_position + back * (1.6 + 0.9 * float(k)) + back.cross(Vector3.UP) * (0.8 * float(k - 1))
				k += 1
			camps.wake_camp("the_ditch")
		"beast_at_camera":
			var hs: Array = camps.members_of("the_ditch")
			_plane_beast = hs[0] as Node3D if not hs.is_empty() else null
			if _plane_beast == null:
				_failures.append("%s: no hound to place" % str(c["name"]))
			_hold_at_camera()
		"lurker":
			for patch: Variant in camps.patches:
				var d: Dictionary = patch
				var lurker: Node3D = d.get("lurker", null) as Node3D
				var at: Vector3 = lurker.global_position if lurker != null and is_instance_valid(lurker) else Vector3.ZERO
				if lurker == null:
					continue
				player.global_position = at + Vector3(-0.5, 0.0, 3.2)
				player.global_position.y = (_base["field"] as Vector3).y
				break
		"dash":
			player.call("set_affinities", ["water"])
			player.set("cursor_fixed", player.global_position + Vector3(4.0, 0.0, 0.0))
			_cast("hydraulic_flex")
			player.set("cursor_fixed", null)
		"windup":
			player.call("set_affinities", ["earth"])
			player.set("cursor_fixed", player.global_position + Vector3(4.0, 0.0, 0.0))
			_cast("landslide_blow")
			player.set("cursor_fixed", null)
		"townsperson":
			# click someone on screen and out of talking reach: the walk up to them begins
			var town: TownBuilder = main.get("_town")
			var who: Townsperson = null
			var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size).grow(-60.0)
			for p: Townsperson in town.folk:
				var d: float = _flat(p.global_position - player.global_position).length()
				if d > float(GameData.town.get("talk_reach", 2.7)) + 2.0 and not cam.is_position_behind(p.global_position) \
						and view.has_point(cam.unproject_position(p.global_position + Vector3.UP * 1.1)) \
						and (who == null or d < _flat(who.global_position - player.global_position).length()):
					who = p
			if who == null:
				_failures.append("%s: nobody on screen to click" % str(c["name"]))
				return
			var at: Vector2 = cam.unproject_position(who.global_position + Vector3.UP * 1.1)
			_point(at)
			_button(at, true)
			_button(at, false)


## Keep the hound just in front of the camera's plane, a little to the side and on the ground: its
## feet are (barely) in front of the camera, its back is behind it.
func _hold_at_camera() -> void:
	if _plane_beast == null or not is_instance_valid(_plane_beast):
		return
	var fwd: Vector3 = -cam.global_transform.basis.z
	var side: Vector3 = cam.global_transform.basis.x
	var feet := Vector3(player.global_position.x, player.global_position.y, player.global_position.z)
	var back := _flat(-fwd).normalized()
	# ground points feet + back * s + side * 3: their depth (p - cam) . fwd falls as s grows
	var lo := 0.0
	var hi := 200.0
	for k: int in 40:
		var mid: float = (lo + hi) * 0.5
		if (feet + back * mid + side * 3.0 - cam.global_position).dot(fwd) > cam.near + 0.05:
			lo = mid
		else:
			hi = mid
	_plane_beast.global_position = feet + back * lo + side * 3.0


func _cast(ability_id: String) -> void:
	player.set("essence", float(player.get("essence_max")))
	var list: Array = player.get("abilities")
	for i: int in list.size():
		if str(list[i]["id"]) == ability_id:
			player.call("cast_ability", i)
			return
	_failures.append("the character does not know %s" % ability_id)


func _judge(c: Dictionary) -> void:
	_ran += 1
	var moved: Vector3 = _flat(player.global_position - _start)
	var before: float = _flat(_goal - _start).length()
	var after: float = _flat(_goal - player.global_position).length()
	var turn: float = _deg(moved, _sent)
	var face: float = _face_mid
	var at: Vector2 = _px(c["at"])
	var target: Variant = player.get("attack_target")
	var detail := "moved %.2f m at %.0f deg off the click, %.2f -> %.2f m from it, body faces %.0f deg off, goal %s, target %s, ray.y %.3f, cursor %s; at the press hovered %s, target %s; after the click target %s" % [
		moved.length(), turn, before, after, face,
		str(player.get("move_goal")) if bool(player.get("has_move_goal")) else "none",
		_describe(target),
		cam.project_ray_normal(at).y, str(at), _hover_at_press, _target_before, _target_after]
	var why := ""
	var thing: Node3D = _took if _took != null and is_instance_valid(_took) else null
	var cut := false                            # something it may rightly strike was cut down at once
	for n: Variant in _strikable:
		if not is_instance_valid(n) or bool((n as Node).call("is_dead")):
			cut = true
	if (_took != null and thing == null) or (thing == null and cut and moved.length() < 0.25):
		pass                                    # struck what was clicked, in reach, and it fell
	elif bool(c.get("rooted", false)):
		if moved.length() > 0.25:
			why = "moved while rooted by a wind-up"
	elif thing != null:
		# the click took something: it must have been under the cursor (or its footprint under the
		# clicked ground point), and the player goes to it
		var to_thing: Vector3 = _flat(thing.global_position - _start)
		if not _under and not _took_footprint:
			why = "the click took something that is not under the cursor"
		elif to_thing.length() > 2.5 and moved.length() > 0.25 and _deg(moved, to_thing) > ANGLE_TOL:
			why = "ran the wrong way to what it clicked"
	elif before < 0.4:
		pass                                    # clicked at the feet: nothing to judge
	elif moved.length() < 0.25:
		if not _blocked(_sent):
			why = "did not move"
	elif turn > ANGLE_TOL:
		why = "ran the wrong way"
	elif after >= before:
		why = "got no closer"
	elif face > FACE_TOL:                       # measured mid-run (-1: it never ran)
		why = "faces away from where it runs"
	if why != "":
		_failures.append("%s: %s (%s)" % [str(c["name"]), why, detail])
	if _verbose or why != "":
		print("MOVE: %s %s - %s" % ["FAIL" if why != "" else "ok  ", str(c["name"]), detail])


func _describe(n: Variant) -> String:
	if n == null or not is_instance_valid(n):
		return "none"
	var t := n as Node3D
	var scr: Script = t.get_script()
	return "%s %s (%s) r %s h %s at %.1f m, groups %s" % [t.name, str(t.get("kind")) if t.get("kind") != null else "", scr.resource_path.get_file() if scr != null else t.get_class(),
		str(t.get("radius")), str(t.get("height")), _flat(t.global_position - player.global_position).length(), str(t.get_groups())]


## True when `n` (a hittable, pickup or townsperson) is drawn where the cursor is: its whole body in
## front of the camera, and the cursor within its drawn width of its base-to-top segment.
func _under_cursor(n: Variant, at: Vector2) -> bool:
	if n == null or not is_instance_valid(n):
		return false
	var t := n as Node3D
	var h: float = float(t.get("height")) if t.get("height") != null else 1.0
	var r: float = float(t.get("radius")) if t.get("radius") != null else 0.4
	if cam.is_position_behind(t.global_position) or cam.is_position_behind(t.global_position + Vector3.UP * h):
		return false
	var base: Vector2 = cam.unproject_position(t.global_position)
	var top: Vector2 = cam.unproject_position(t.global_position + Vector3.UP * h)
	var width: float = base.distance_to(cam.unproject_position(t.global_position + cam.global_transform.basis.x * r))
	var margin: float = GameData.num("player", "pick_margin_px")
	return Geometry2D.get_closest_point_to_segment(at, base, top).distance_to(at) <= width + margin + 1.0


## True when a wall or prop stands right in the way, so not moving is not the click's fault.
func _blocked(dir: Vector3) -> bool:
	var from: Vector3 = player.global_position + Vector3.UP * 0.6
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * 1.0, 1)
	return not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _finish() -> void:
	set_process(false)
	_button(Vector2.ZERO, false)
	if _errors.count() > 0:
		_failures.append("script errors: %d, first: %s" % [_errors.count(), _errors.first()])
	print("MOVE: %d clicks judged, %d skipped (on the interface)" % [_ran, _skipped])
	if _failures.is_empty():
		print("MOVE: PASS")
	else:
		for f: String in _failures:
			print("MOVE: FAIL " + f)
		print("MOVE: FAIL (%d)" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
