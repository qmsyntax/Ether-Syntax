class_name PlayerMotion
extends RefCounted
## The player's part for movement and feel: walking, click targeting, the input buffer, facing, hit-stop, the sidestep, endurance, Slipstream.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const ISO_YAW := deg_to_rad(45.0)

var player: Player

var _still_t := 0.0                  # how long you have been standing
var _pip_decay_t := 0.0
var _buffered_t := 0.0
var _fight_target_id := 0            # the attack target last step, by instance id (_target_fell)
var _hold_fights := false            # the strike button is held and began on a foe
var _body_yaw := 0.0                 # the body as drawn turns toward rotation.y
var _cam_kick := Vector3.ZERO
var _shown_stagger := false


func _init(of: Player) -> void:
	player = of


## The feet, each physics frame (moved out of _physics_process unchanged): click and stance input, what
## you walk toward or strike, the run or a shove, sidestep or dash moved by exact distance, Slipstream,
## facing and the model.
func _tick_move(delta: float) -> void:
	# Diablo-style: click something to walk to it and hit it; click ground to walk there.
	if player.bot:
		player.attack_target = player.bot_part._nearest_enemy()
		player._strike_once = false
	else:
		_update_hover()
	var was_stance: bool = player.ranged_stance
	player.ranged_stance = not player.bot and not player._sitting and not player.ui_blocked and Input.is_action_pressed("ranged_stance") and not player.combat_part.ranged_weapon().is_empty()
	if player.ranged_stance != was_stance:
		player.combat_part._show_range_ring(player.ranged_stance)
	if player.ranged_stance:
		# feet stay where they are: no walking to a click, no closing to strike
		player.attack_target = null
		player.pickup_target = null
		player.has_move_goal = false
		if Input.is_action_pressed("strike"):
			player.combat_part.fire_ranged(player.combat_part._ranged_aim())
	if not player.bot and not player.ranged_stance and Input.is_action_just_pressed("strike") and not player._sitting and not player.ui_blocked:
		_click_cursor()
		_strike_clicked()
	if not player.bot and not player.ranged_stance and Input.is_action_pressed("strike") and player.attack_target == null and player.has_move_goal:
		player.move_goal = _cursor_ground()          # holding on the ground keeps steering

	var input := Vector2.ZERO
	if not player._sitting and player._stagger_t <= 0.0 and player._windup_t <= 0.0:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# off your feet (_stagger_t): nowhere to go and nothing to swing until it passes - what you were
	# doing was dropped when it hit (take_hit); a click made meanwhile waits for you to get up
	var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	if input != Vector2.ZERO:
		player.has_move_goal = false                  # WASD takes over from click-to-move
		if not Input.is_action_pressed("strike"):
			player.attack_target = null
			player.pickup_target = null

	if player.attack_target != null and (not is_instance_valid(player.attack_target) or bool(player.attack_target.call("is_dead"))):
		player.attack_target = null
	_target_fell()
	_strike_spent()
	if player.attack_target != null and not player.meditating and not player._charging:
		var to: Vector3 = player.attack_target.global_position - player.global_position
		to.y = 0.0
		var reach: float = player.economy_part.reach_now() + float(player.attack_target.get("radius"))
		if to.length() > 0.2:
			player._facing = to.normalized()
		if to.length() <= reach:
			dir = Vector3.ZERO if input == Vector2.ZERO else dir
			if player._melee_cd <= 0.0 and player._stagger_t <= 0.0 and not stepping():
				player._strike_credit = maxi(0, player._strike_credit - 1)       # a click is one blow (_strike_spent)
				player.combat_part._strike_target(player.attack_target, float(player._p["off_hand_factor"]) if player.arm_right_lost else 1.0, ["melee"])
				player._melee_cd = float(player._p["melee_cooldown"]) * player.economy_part.weapon_stat("melee_cooldown_mult", true) * player.progress_part.temper_stat("melee_cooldown_mult") / maxf(0.1, player.combat_part.strike_rate_mult())
		elif input == Vector2.ZERO:
			dir = to.normalized()                  # walk into reach
			if player.bot and player._bot_dir != Vector3.ZERO:
				dir = player._bot_dir                     # a person steers round things by hand; the bot follows its path
	elif player.pickup_target != null and is_instance_valid(player.pickup_target) and not player.pickup_target.is_queued_for_deletion():
		var to_item: Vector3 = player.pickup_target.global_position - player.global_position
		to_item.y = 0.0
		if to_item.length() <= GameData.num("player", "pickup_reach"):
			player.economy_part.take_pickup(player.pickup_target)
			player.pickup_target = null
		elif input == Vector2.ZERO:
			dir = to_item.normalized()
			player._facing = dir
	elif player.has_move_goal and input == Vector2.ZERO:
		var to_goal: Vector3 = player.move_goal - player.global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.3:
			player.has_move_goal = false
		else:
			dir = to_goal.normalized()
			player._facing = dir

	if not _walk_cast.is_empty():
		var walk: Variant = _walk_cast_step(delta, input)
		if walk != null:
			dir = walk
	if player.bot:
		dir = player._bot_dir if player.attack_target == null else dir
	var speed: float = walk_speed()
	if player._windup_t > 0.0 or player._stagger_t > 0.0:
		dir = Vector3.ZERO                       # set: you do not move until it goes off (or you are up)
	player.velocity = dir * speed
	if player._shoved_left > 0.0:
		# knocked back: an exact distance, and nothing you were doing with your feet survives it
		var push: float = minf(player._shoved_left, GameData.num("combat", "player_shove_speed") * delta)
		player._shoved_left -= push
		player.velocity = Vector3.ZERO
		if player.move_and_collide(player._shoved_dir * push) != null:
			player._shoved_left = 0.0
	elif stepping():
		_tick_step_move(delta)                   # the sidestep: an eased run of its own (balance.json sidestep)
	elif player._dash_time > 0.0:
		# A dash covers an exact distance: it is moved by hand, not by velocity, whose time step
		# the engine chooses (that made a 4.2 m dash travel 23 m in a test, and would on a hitch).
		var step_t: float = minf(delta, player._dash_time)
		var step: Vector3 = player._dash_vel * step_t
		player._dash_time -= step_t
		player.velocity = Vector3.ZERO
		var met: Node3D = player._body_ahead(player._dash_vel.normalized(), step.length()) if player._dash_stops else null
		if met != null:
			player._dash_time = 0.0                     # this one does not go through people
			player._dash_met(met)
		elif player.move_and_collide(step) != null:
			player._dash_time = 0.0                     # a wall
		player._dash_touch()
		if player._dash_time <= 0.0:
			player._end_dash()
			player._dash_pass = {}
	else:
		ExactSlide.slide(player, delta)

	_tick_slipstream(delta)
	_hold_facing(delta)
	player.rotation.y = atan2(-player._facing.x, -player._facing.z)
	player._update_model(delta)

## How fast your feet carry you right now: the run, slowed by a charge, a held skill, a counter
## window or the shooting stance, quickened by buffs and Slipstream. Wind-ups and staggers stop you
## separately. The sidestep eases out into this.
func walk_speed() -> float:
	var speed: float = float(player._p["move_speed"]) * player.progress_part.temper_stat("move_speed_mult") * (float(player._p["charge_move_factor"]) if player._charging else 1.0) * player.casting_part.buff_num("move_speed_mult") * player._zone_num("caster_speed_mult")
	if not player._held.is_empty():
		speed *= float((player._held["ab"] as Dictionary).get("move_factor", 1.0))     # holding a skill: you walk slowly, or not at all
	speed *= player.casting_part.buff_num("move_factor")          # a counter window roots you (Abiding Guard, Turning Palm, Turn the Edge)
	if player.ranged_stance:
		speed *= GameData.num("ranged", "stance_move_factor")
	if player.pips >= GameData.inum("slipstream", "speed_pips"):
		speed *= GameData.num("slipstream", "speed_mult")
	return speed


## True if the character holds an affinity that runs on Slipstream.
func has_slipstream() -> bool:
	for aff: String in player.affinities:
		if bool(GameData.affinity(aff).get("slipstream", false)):
			return true
	return false


## Slipstream: a pip for every stretch travelled, by whatever means; they drain once you stand.
func _tick_slipstream(delta: float) -> void:
	var moved: Vector3 = player.global_position - player._last_pos
	moved.y = 0.0
	player._last_pos = player.global_position
	var dist: float = moved.length()
	if dist > 50.0:
		dist = 0.0                               # placed somewhere new (a level change), not travelled
	player._moving = dist > 0.001
	if not has_slipstream():
		player.pips = 0
		return
	var cfg: Dictionary = GameData.balance["slipstream"]
	if player._moving:
		_still_t = 0.0
		_pip_decay_t = 0.0
		player._pip_dist += dist * player._zone_num("pip_gain_mult")
		var per: float = float(cfg["metres_per_pip"])
		while player._pip_dist >= per:
			player._pip_dist -= per
			player.pips = mini(int(cfg["max"]), player.pips + 1)
	elif not player.buffs.has("veil") and not player.hits_part._zone_flag("freeze_pips"):     # behind the veil (or in dead air) the wind stays with you
		_still_t += delta
		if _still_t >= float(cfg["still_delay_s"]):
			_pip_decay_t += delta
			if _pip_decay_t >= float(cfg["decay_s"]):
				_pip_decay_t -= float(cfg["decay_s"])
				player.pips = maxi(0, player.pips - 1)


## Take up to `want` pips (all of them if negative). Returns how many were spent.
func spend_pips(want: int) -> int:
	var n: int = player.pips if want < 0 else mini(player.pips, want)
	player.pips -= n
	return n


# --- click targeting ------------------------------------------------------------

## Click at the cursor: the hovered thing if there is one, otherwise the floor under the cursor.
func _click_cursor() -> void:
	if player.hovered != null and is_instance_valid(player.hovered) and not bool(player.hovered.call("is_dead")):
		player.has_move_goal = false
		if player.hovered.get("is_pickup") != null:
			player.pickup_target = player.hovered
			player.attack_target = null
		else:
			player.attack_target = player.hovered
			player.pickup_target = null
			player._strike_once = true
	else:
		player.pickup_target = null
		_click(_cursor_ground())
	_refresh_highlights()


## Handle a click at a ground point: a hittable there becomes the attack target (enemies win
## over scenery), otherwise the point becomes a walk goal.
func _click(point: Vector3) -> void:
	var hit: Node3D = pick_at(point)
	if hit != null:
		player.attack_target = hit
		player.has_move_goal = false
		player._strike_once = true
	else:
		player.attack_target = null
		player.move_goal = point
		player.has_move_goal = true


## Screen-space pick: the hittable whose drawn body (base-to-top segment, widened by its radius
## and a margin) contains `screen_pos`. Enemies win over scenery; closest to the cursor wins.
func pick_screen(screen_pos: Vector2, cam: Camera3D) -> Node3D:
	if cam == null:
		return null
	var margin: float = GameData.num("player", "pick_margin_px")
	var best: Node3D = null
	var best_d := INF
	var best_rank := -1
	var candidates: Array[Node] = player.get_tree().get_nodes_in_group("hittable")
	candidates.append_array(player.get_tree().get_nodes_in_group("pickups"))
	for node: Node in candidates:
		var t := node as Node3D
		if t == null or bool(t.call("is_dead")):
			continue
		var h: float = float(t.get("height")) if t.get("height") != null else 1.0
		if not Pick.standing_in_view(cam, t.global_position, h):
			continue                            # beside or under the camera: see Pick.standing_in_view
		var r: float = float(t.get("radius"))
		var base: Vector2 = cam.unproject_position(t.global_position)
		var top: Vector2 = cam.unproject_position(t.global_position + Vector3.UP * h)
		var side: Vector2 = cam.unproject_position(t.global_position + cam.global_transform.basis.x * r)
		var r_px: float = base.distance_to(side)
		var d: float = Geometry2D.get_closest_point_to_segment(screen_pos, base, top).distance_to(screen_pos)
		# enemies beat loot, loot beats scenery
		var rank: int = 0 if bool(t.get("is_scenery")) else (1 if t.get("is_pickup") != null else 2)
		if d > r_px + (margin * 0.4 if rank == 0 else margin):
			continue
		if rank > best_rank or (rank == best_rank and d < best_d):
			best = t
			best_d = d
			best_rank = rank
	return best


func _update_hover() -> void:
	var cam: Camera3D = player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	var now: Node3D = pick_screen(player.get_viewport().get_mouse_position(), cam) if cam != null else null
	if now != player.hovered:
		player.hovered = now
	_refresh_highlights()


## Hovered = bright, locked attack target = dimmer; everything else plain.
func _refresh_highlights() -> void:
	var nodes: Array[Node] = player.get_tree().get_nodes_in_group("hittable")
	nodes.append_array(player.get_tree().get_nodes_in_group("pickups"))
	for node: Node in nodes:
		var level := 0
		if node == player.hovered:
			level = 1
		elif node == player.attack_target or node == player.pickup_target:
			level = 2
		if node.has_method("set_highlight"):
			if int(node.get("highlight")) != level:
				node.call("set_highlight", level)
		elif node.get("highlight") != null:
			node.set("highlight", level)


## The hittable whose footprint contains `point`, preferring enemies over scenery.
func pick_at(point: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var best_is_enemy := false
	for node: Node in player.get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null or bool(t.call("is_dead")):
			continue
		var d: Vector3 = t.global_position - point
		d.y = 0.0
		var dist: float = d.length()
		if dist > float(t.get("radius")) + 0.45:
			continue
		var is_enemy: bool = not bool(t.get("is_scenery"))
		if (is_enemy and not best_is_enemy) or (is_enemy == best_is_enemy and dist < best_d):
			best = t
			best_d = dist
			best_is_enemy = is_enemy
	return best


## A one-off motion on a real body (RealCharacter.play_action); the procedural body has none.
func _rig_action(motion: String) -> void:
	if player._rig != null and player._rig.has_method("play_action"):
		player._rig.call("play_action", motion)


## Where the mouse cursor meets the floor the player stands on.
func _cursor_ground() -> Vector3:
	if player.cursor_fixed != null:
		return player.cursor_fixed
	var cam: Camera3D = player.get_viewport().get_camera_3d() if player.is_inside_tree() else null
	if cam == null:
		return player.global_position
	return Pick.ground(cam, player.get_viewport().get_mouse_position(), player.global_position.y)


func _update_aim() -> void:
	if player.attack_target != null or player.has_move_goal:
		return                                 # facing follows the click target / walk goal
	var to: Vector3 = _cursor_ground() - player.global_position
	to.y = 0.0
	if to.length() > 0.2:
		player._facing = to.normalized()


# --- feel (Brent 2026-10-24: "make them feel more fluid. It feels a bit clunky right now") ----------
# How the controls answer; numbers in balance.json "feel", measured by tests/combat_timeline_probe.
# Responsiveness only: nothing here changes what a skill or a strike does, costs or commits you to.

## A hotbar key the player pressed (main.gd). Cast now if you can. While you are busy - a recovery,
## a wind-up, a dash, a stagger - the press is kept and cast the moment you are free, if that comes
## within "feel" input_buffer_s; the latest press wins. Pressed while holding a skill, it lets go of
## that first and then waits its turn. Tests and bots call cast_slot / cast_ability, which still
## refuse a cast while you are busy, outright.
func press_slot(slot: int) -> void:
	player._buffered_slot = -1
	cancel_walk_cast()                           # a new press is another input: the walk-in is dropped
	if not player._held.is_empty():
		if str(player._held.get("action", "")) == "ability_%d" % (slot + 1):
			return                               # its own key: the hold answers it
		player._end_held()
	if _cast_busy():
		var window: float = GameData.num("feel", "input_buffer_s")
		if window > 0.0:
			player._buffered_slot = slot
			_buffered_t = window
		return
	_pressed_cast(slot)


## A cast from a key press (press_slot, or its kept press): a close skill out of reach may walk you in.
func _pressed_cast(slot: int) -> void:
	_from_press = true
	player.casting_part.cast_slot(slot)
	_from_press = false


## True while a new cast would be refused for timing alone.
func _cast_busy() -> bool:
	return player._recover_t > 0.0 or player._stagger_t > 0.0 or player._windup_t > 0.0 or player._dash_time > 0.0 or stepping() or not player._held.is_empty()


## The kept press goes off as soon as you are free; it is forgotten when its window runs out.
func _tick_buffer(delta: float) -> void:
	if player._buffered_slot < 0:
		return
	_buffered_t -= delta
	if _buffered_t < 0.0 or player.meditating or player._sitting or player.ui_blocked or player.dead:
		player._buffered_slot = -1
		return
	if not _cast_busy():
		var slot: int = player._buffered_slot
		player._buffered_slot = -1
		_pressed_cast(slot)


## The strike button went down and the click handler chose (_click_cursor): a click on a foe is one
## more blow owed to it (up to "feel" strike_queue_max); any click ends a cast's facing hold.
func _strike_clicked() -> void:
	player._face_hold_t = 0.0
	cancel_walk_cast()                           # a click is another input: the walk-in is dropped
	if player.attack_target != null:
		player._strike_credit = mini(player._strike_credit + 1, GameData.inum("feel", "strike_queue_max"))
	else:
		player._strike_credit = 0


## A clicked foe is let go once the blows clicked for are swung, unless the button is still held
## (holding keeps swinging). Before 2026-10-24 this was asked at the swing, while the click that
## made it was still down, so one click swung twice and a third quick click was lost.
func _strike_spent() -> void:
	if player.attack_target == null:
		player._strike_credit = 0
		return
	if player._strike_once and not player.bot and player._strike_credit <= 0 and not Input.is_action_pressed("strike"):
		player.attack_target = null


## Which foe you are fighting, step to step (by instance id: a freed target compares equal to null).
## A new target, however it was chosen, is owed one blow. Holding strike that began on a foe fights
## on ("feel" held_strike_retargets): when the foe drops, the held button clicks again where the
## cursor is (the next foe there, else the ground to walk to), and while it is held with nobody to
## hit, a foe the cursor comes over is taken up - Diablo's held attack. Picking is the click
## handler's own (hovered, pick_at).
func _target_fell() -> void:
	var was: int = _fight_target_id
	_fight_target_id = player.attack_target.get_instance_id() if is_instance_valid(player.attack_target) else 0
	if _fight_target_id != 0 and _fight_target_id != was:
		player._strike_credit = maxi(player._strike_credit, 1)
	if not Input.is_action_pressed("strike") or player.bot:
		_hold_fights = false
		return
	if _fight_target_id != 0:
		_hold_fights = true                      # the held button has a foe: it fights until let go
		return
	if not _hold_fights or player.ranged_stance or player._sitting or player.ui_blocked or not bool(GameData.balance["feel"]["held_strike_retargets"]):
		return
	var old: Object = instance_from_id(was) if was != 0 else null
	var felled: bool = was != 0 and (old == null or (old.has_method("is_dead") and bool(old.call("is_dead"))))
	if felled:
		_click_cursor()                          # the held button clicks again
	if player.attack_target == null:
		var under: Node3D = player.hovered if player.hovered != null and is_instance_valid(player.hovered) else pick_at(_cursor_ground())
		if under != null and under.is_in_group("enemies") and not bool(under.call("is_dead")):
			player.attack_target = under                # the cursor came over a foe
			player.has_move_goal = false
			player._strike_once = true
	_fight_target_id = player.attack_target.get_instance_id() if is_instance_valid(player.attack_target) else 0


## A skill goes where you point: the moment it is cast you turn to the cursor ("feel"
## cast_faces_cursor), even while walking somewhere else or holding a foe. A skill aimed at a foe or
## a spot turns you to that itself; a dash with a direction key held goes that way; the bot, and a
## run with no cursor, keep the facing they have.
func _face_cast_aim(kind: String) -> void:
	if player.bot or not bool(GameData.balance["feel"]["cast_faces_cursor"]) or kind == "targeted_strike" or kind == "chain":
		return
	if kind == "dash" and Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		return
	if player.cursor_fixed == null and (not player.is_inside_tree() or player.get_viewport().get_camera_3d() == null):
		return
	var to: Vector3 = _cursor_ground() - player.global_position
	to.y = 0.0
	if to.length() >= 0.5:
		player._facing = to.normalized()
		_snap_body_now()


## Where you face this step, after the walk and the target have had their say: a wind-up keeps its
## aim, and for a moment after a cast you keep facing where it went ("feel" cast_face_hold_s).
func _hold_facing(delta: float) -> void:
	player._face_hold_t -= delta
	if player._windup_t > 0.0:
		player._facing = player._windup.get("facing", player._facing)
	elif player._face_hold_t > 0.0 and player._dash_time <= 0.0 and player._face_dir != Vector3.ZERO:
		player._facing = player._face_dir


## The body's motion for a skill, started so its swing lands `lands_in` seconds from now (each
## clip's swing moment is wardrobe.json action_impact_s). A melee skill with no wind-up is left to
## animate(), which slashes; one with a wind-up swings the heavy blow, timed to land as it ends.
## Returns true if a motion was started.
func _play_cast_motion(ab: Dictionary, kind: String, lands_in: float) -> bool:
	if player._rig == null or not player._rig.has_method("play_action"):
		return false
	var motion: String = {"dash": "dodge", "blink": "dodge", "detonate": "cast_area", "self_buff": "cast_area"}.get(kind, "cast")
	if kind == "melee_burst" and float(ab.get("arc_deg", 0.0)) >= 360.0:
		motion = "cast_area"
	var wound_up: bool = lands_in > GameData.num("feel", "anim_action_lead_s") + 0.001
	if kind == "targeted_strike" or (kind == "melee_burst" and motion == "cast"):
		if not wound_up:
			return false
		motion = "heavy"
	player._rig.call("play_action", motion, -1.0 if motion == "dodge" else lands_in)
	return true


## A strike or a cast turns the body as drawn to where you face, at once (the turn is not eased).
func _snap_body_now() -> void:
	_body_yaw = atan2(-player._facing.x, -player._facing.z)


## The body as drawn: the stagger reaction, the turn toward where you face (gameplay facing is
## instant; a strike or a cast snaps the body round), and the camera settling after a nudge.
func _feel_model(delta: float) -> void:
	var down: bool = player._stagger_t > 0.0
	if down != _shown_stagger:
		_shown_stagger = down
		player._rig.set_staggered(down)
	var rate: float = GameData.num("feel", "body_turn_rate")
	if player._snap_body or rate <= 0.0:
		_body_yaw = player.rotation.y
		player._snap_body = false
	else:
		_body_yaw = lerp_angle(_body_yaw, player.rotation.y, minf(1.0, rate * delta))
	player._rig.rotation.y = wrapf(_body_yaw - player.rotation.y, -PI, PI)
	_cam_kick = _cam_kick.lerp(Vector3.ZERO, minf(1.0, GameData.num("feel", "camera_kick_decay") * delta))


## A melee hit landed: a hair of hit-stop on both bodies at the moment the swing lands, the camera
## nudged along the blow, and the impact signal (nothing plays a sound yet).
func _impact_feedback(target: Node, strong: bool) -> void:
	if player.bot:
		return
	var f: Dictionary = GameData.balance["feel"]
	var stop: float = float(f["hit_stop_heavy_s"] if strong else f["hit_stop_s"])
	if stop > 0.0:
		var lead: float = float(f["anim_action_lead_s"])
		for r: Variant in [player._rig, target.get("_rig")]:
			if r is ModelRig and is_instance_valid(r):
				(r as ModelRig).hit_pause(stop, lead)
	var at: Vector3 = (target as Node3D).global_position
	_kick(at - player.global_position, float(f["camera_kick_heavy_m"] if strong else f["camera_kick_m"]), null)
	player.impact.emit(1 if strong else 0, at)


## Nudge the camera `metres` along `dir` (or, with no dir, away from `from`: a blow taken).
func _kick(dir: Vector3, metres: float, from: Variant) -> void:
	var d: Vector3 = dir
	if d == Vector3.ZERO and from is Node3D and is_instance_valid(from):
		d = player.global_position - (from as Node3D).global_position
		player.impact.emit(2, player.global_position)
	d.y = 0.0
	if d.length() < 0.01 or metres <= 0.0:
		return
	# blows in the same moment (a sweep through a crowd) add up to no more than one heavy nudge
	_cam_kick = (_cam_kick + d.normalized() * metres).limit_length(maxf(metres, GameData.num("feel", "camera_kick_heavy_m")))


## How far the camera is nudged right now (main._place_camera adds it).
func camera_kick() -> Vector3:
	return _cam_kick


# --- the sidestep (combat review R3, approved by Brent 2026-11-03; reworked per Brent 2026-11-03:
# "keep the motion smooth ... almost like a dash, but with the animation"; balance.json "sidestep") ------
# A short step on its own key (Keybinds "sidestep"): not invulnerable - you avoid a blow by not being
# there (design/05 6.3) - and priced in endurance (below), not essence, reflux or a cooldown [B]. It is
# its own eased run, not the dash movement: distance_m in time_s, fast at the start and easing out
# (ease_power) into your run speed when you are moving on (end_speed_frac) or nearly to a stand when you
# are not (end_speed_frac_still). Each frame moves the exact stretch of that curve with move_and_collide,
# so it stops at walls and bodies like a dash. A held move key, a click destination or a held-mouse walk
# carries on the moment it ends; a press while busy waits like a hotbar key. The dodge clip is fitted to
# the step (RealCharacter.play_for, wardrobe.json action_window_s) and hands over to the run as it ends.

var _step_buffer_t := 0.0            # a sidestep pressed while busy, taken the moment you are free
var _step_len := 0.0                 # the step under way: how long it lasts ...
var _step_el := 0.0                  # ... how far into it you are (seconds)
var _step_dir := Vector3.ZERO
var _step_v0 := 0.0                  # its speed at the start and at the end (m/s)
var _step_ve := 0.0
var _step_k := 2.0                   # the ease-out exponent


## The sidestep key (main.gd). Step now if you can; while you are busy (a recovery, a wind-up, a dash,
## a stagger, a step) the press is kept for "feel" input_buffer_s, as press_slot keeps a hotbar key. It
## lets go of a held skill, and the latest press wins over a kept hotbar key.
func press_sidestep() -> void:
	player._buffered_slot = -1
	cancel_walk_cast()
	if not player._held.is_empty():
		player._end_held()
	if _cast_busy():
		_step_buffer_t = GameData.num("feel", "input_buffer_s")
		return
	sidestep()


func _tick_step_buffer(delta: float) -> void:
	if _step_buffer_t <= 0.0:
		return
	_step_buffer_t -= delta
	if _step_buffer_t <= 0.0 or player.meditating or player._sitting or player.ui_blocked or player.dead:
		_step_buffer_t = 0.0
		return
	if not _cast_busy():
		_step_buffer_t = 0.0
		sidestep()


## True while a sidestep is carrying you.
func stepping() -> bool:
	return _step_el < _step_len


## Take the step now. Returns "" if you stepped, else why not: inactive, sitting, busy, endurance.
func sidestep() -> String:
	if not player.active or player.dead or player.projecting or player.ui_blocked:
		return "inactive"
	if player._sitting or player.meditating:
		return "sitting"
	if _cast_busy():
		return "busy"
	var cfg: Dictionary = GameData.balance["sidestep"]
	if not spend_endurance(GameData.num("endurance", "step_cost")):
		player.casting_part._refuse("endurance", "Not enough endurance to step")
		return "endurance"
	var dir: Vector3 = _sidestep_dir()
	var time: float = maxf(0.05, float(cfg["time_s"]))
	var dist: float = float(cfg["distance_m"])
	# the curve: v(u) = ve + (v0 - ve)(1 - u)^k over u = 0..1, with v0 chosen so it covers dist exactly
	var k: float = maxf(0.0, float(cfg.get("ease_power", 2.0)))
	var moving_on: bool = _moves_on()
	var ve: float = walk_speed() * float(cfg.get("end_speed_frac", 1.0) if moving_on else cfg.get("end_speed_frac_still", 0.0))
	ve = clampf(ve, 0.0, dist / time)           # never ends faster than it averages: it is a burst, then the run
	_step_k = k
	_step_ve = ve
	_step_v0 = ve + (dist / time - ve) * (k + 1.0)
	_step_dir = dir
	_step_len = time
	_step_el = 0.0
	player._facing = dir
	_snap_body_now()
	player.attack_target = null                        # a step drops the foe you were closing on ...
	player._strike_credit = 0
	player._face_hold_t = 0.0                          # ... but not where your feet were going (has_move_goal, pickup_target)
	if player._rig != null and player._rig.has_method("play_for"):
		player._rig.call("play_for", "dodge", time, float(cfg.get("anim_blend_out_s", 0.12)))
	elif player._rig != null and player._rig.has_method("play_action"):
		player._rig.call("play_action", "dodge", -1.0)
	player.sidesteps += 1
	player.sidestepped.emit(dir)
	return ""


## Whether you will be moving when the step ends: a move key held, a click destination or an item to
## walk to, or the strike button held on the ground. Decides the speed the step eases out into.
func _moves_on() -> bool:
	if player.bot:
		return player._bot_dir != Vector3.ZERO
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		return true
	return player.has_move_goal or (player.pickup_target != null and is_instance_valid(player.pickup_target))


## Distance covered by fraction u of the step (metres), along the curve sidestep() chose.
func _step_dist_at(u: float) -> float:
	var k1: float = _step_k + 1.0
	return _step_len * (_step_ve * u + (_step_v0 - _step_ve) * (1.0 - pow(1.0 - u, k1)) / k1)


## The step's speed at fraction u (m/s).
func _step_speed_at(u: float) -> float:
	return _step_ve + (_step_v0 - _step_ve) * pow(1.0 - u, _step_k)


## One physics frame of the step: the exact stretch of the curve, stopped by a body ahead or a wall.
func _tick_step_move(delta: float) -> void:
	var u0: float = _step_el / _step_len
	_step_el = minf(_step_len, _step_el + delta)
	var u1: float = _step_el / _step_len
	var metres: float = _step_dist_at(u1) - _step_dist_at(u0)
	player._facing = _step_dir
	player.velocity = _step_dir * _step_speed_at(u1)    # moved by hand below; this is what the body's animation reads
	if player._body_ahead(_step_dir, metres) != null:
		_end_step()                               # a step does not carry you through a body
	elif player.move_and_collide(_step_dir * metres) != null:
		_end_step()                               # a wall
	elif not stepping():
		_end_step()


## The step is over (its end, a wall, a body, a stagger, a shove): the body hands over to the run.
func _end_step() -> void:
	var was: bool = stepping() or _step_len > 0.0
	_step_el = 0.0
	_step_len = 0.0
	if was and player._rig != null and player._rig.has_method("end_timed"):
		player._rig.call("end_timed")
	if was:
		var lock: float = float((GameData.balance["sidestep"] as Dictionary).get("cast_lockout_s", 0.0))
		player._recover_t = maxf(player._recover_t, lock)       # a hair of lockout after, if the data asks (none for moving)
		player._melee_cd = maxf(player._melee_cd, lock)


## Which way a step goes: the way the move keys point, else toward the cursor, else the way you face.
func _sidestep_dir() -> Vector3:
	var input := Vector2.ZERO if player.bot else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		return Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
	if player.cursor_fixed != null or (player.is_inside_tree() and player.get_viewport().get_camera_3d() != null):
		var to: Vector3 = _cursor_ground() - player.global_position
		to.y = 0.0
		if to.length() > 0.5:
			return to.normalized()
	return player._facing if player._facing.length() > 0.01 else Vector3(0, 0, -1)


# --- endurance (Brent 2026-11-03: "We need endurance to make sure its not cheesed"; balance.json
# "endurance") -------------------------------------------------------------------------------------
# A body's wind for quick movement. For now only the sidestep spends it (step_cost); it comes back at
# regen_per_s once regen_delay_s has passed since the last spend. Not saved: a character starts full, and
# waking after a death or walking into town fills it. The HUD shows a slim bar under your feet while it is
# not full.

var _endurance_wait := 0.0           # no regeneration until this runs out


## The most endurance you can hold.
func endurance_max() -> float:
	return GameData.num("endurance", "max")


## Endurance now (full until anything spends it).
func endurance_now() -> float:
	if player.endurance < 0.0:
		player.endurance = endurance_max()
	return player.endurance


## Spend `amount` if you have it all; true if it was spent.
func spend_endurance(amount: float) -> bool:
	if endurance_now() + 0.0001 < amount:
		return false
	player.endurance = maxf(0.0, player.endurance - amount)
	_endurance_wait = GameData.num("endurance", "regen_delay_s")
	return true


## Back to full (a death, the town).
func refill_endurance() -> void:
	player.endurance = endurance_max()
	_endurance_wait = 0.0


func _tick_endurance(delta: float) -> void:
	var now: float = endurance_now()
	_endurance_wait -= delta
	if _endurance_wait > 0.0:
		return
	player.endurance = minf(endurance_max(), now + GameData.num("endurance", "regen_per_s") * delta)


# --- close skills walk you in (combat review R4a, approved by Brent 2026-11-03) ---------------------
# A close skill (targeted_strike, melee_burst) pressed with its foe out of reach no longer fails: you walk
# to the foe and it is cast the moment you are in reach, as a click on a foe walks you in to strike it.
# Only a key press does this (press_slot and its kept press); cast_slot / cast_ability from tests and
# bots refuse as before. Nothing is spent until the cast. Any other input drops it: a move key, a click,
# another hotbar key, the sidestep, meditating, the shooting stance, a stagger. Numbers in balance.json
# "feel": skill_walk_in_max_m, skill_walk_in_max_s, skill_walk_in_margin_m.

var _walk_cast: Dictionary = {}      # {index, target, reach, slot, left}: walking in to cast
var _from_press := false             # the cast comes from a key press: it may walk in


## Start walking in for ability `index` if this is a key press, there is a foe to aim at within
## skill_walk_in_max_m and it is out of `reach` (plus its radius, less the margin). True if it started.
func _walk_in(index: int, reach: float) -> bool:
	if not _from_press or player.bot or player._forced_target != null:
		return false
	var foe: Node3D = player.casting_part._skill_candidate()
	if foe == null:
		return false
	var feel: Dictionary = GameData.balance["feel"]
	var d: float = Vector2(foe.global_position.x - player.global_position.x, foe.global_position.z - player.global_position.z).length()
	if d <= reach + float(foe.get("radius")) - float(feel["skill_walk_in_margin_m"]) or d > float(feel["skill_walk_in_max_m"]):
		return false
	_walk_cast = {"index": index, "target": foe, "reach": reach, "slot": player._casting_slot, "left": float(feel["skill_walk_in_max_s"])}
	player.attack_target = null                         # the walk is the order now
	player.has_move_goal = false
	player.pickup_target = null
	player._strike_credit = 0
	return true


## True while you are walking in to cast a close skill.
func walking_to_cast() -> bool:
	return not _walk_cast.is_empty()


## Drop a walk-in (any other input does).
func cancel_walk_cast() -> void:
	_walk_cast = {}


## One step of a walk-in: the way to walk, or null when it is over (cast, or dropped). Casts the moment
## the foe is in reach.
func _walk_cast_step(delta: float, input: Vector2) -> Variant:
	var foe_v: Variant = _walk_cast.get("target")
	if input != Vector2.ZERO or player._sitting or player.meditating or player.ranged_stance or player._charging or player._stagger_t > 0.0 or player.dead \
			or not is_instance_valid(foe_v) or bool((foe_v as Node).call("is_dead")):
		cancel_walk_cast()
		return null
	var foe: Node3D = foe_v
	_walk_cast["left"] = float(_walk_cast["left"]) - delta
	if float(_walk_cast["left"]) <= 0.0:
		var slot_was: int = player._casting_slot
		player._casting_slot = int(_walk_cast["slot"])
		player.casting_part._refuse("out_of_reach", "Out of reach")
		player._casting_slot = slot_was
		cancel_walk_cast()
		return null
	var to: Vector3 = foe.global_position - player.global_position
	to.y = 0.0
	if to.length() > 0.05:
		player._facing = to.normalized()
	if to.length() <= float(_walk_cast["reach"]) + float(foe.get("radius")) - GameData.num("feel", "skill_walk_in_margin_m"):
		var w: Dictionary = _walk_cast
		_walk_cast = {}
		player._forced_target = foe
		player._casting_slot = int(w["slot"])
		player.casting_part.cast_ability(int(w["index"]))
		player._casting_slot = -1
		player._forced_target = null
		return Vector3.ZERO
	return to.normalized()
