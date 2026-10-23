class_name Beast
extends "res://scripts/enemy.gd"
## An unstarred beast of the countryside (design/07 5.4; Brent 2026-10-19: the early levels are
## spent hunting monsters with no star). Everything an enemy is - poise, facing, statuses, slots,
## the field's sleep / leash / walk home - plus the beasts' own behaviours, each asking the player
## one question (numbers in enemies.json; the camps that hold them are FieldCamps):
##   runner   - the Gleaner: never fights; when its camp wakes it runs for the next camp and brings
##              it. Any hit makes it stumble. Can you stop it before it gets there?
##   lurker   - the Sod-Lurker: lies under turned earth; step on the patch and it heaves up under you.
##              It will not follow past its tether. Were you reading the ground, or running?
##   grazer   - the Thornback: neutral, grazing; hit one and the herd charges in straight lines.
##              Is this worth it?
##   flanker  - the Ditch Hound: circles to your back and bites there. Can you keep them in front?
##   charger  - the Burr-Hog: scrapes, then charges a lane; armoured in front, open after a miss.
##              Can you make it miss?
##   skittish - the Wirehorn: shies away, and its back end kicks. Where is it safe to stand?
##   darter   - the Chaff Wren: pecks and scatters, in flocks. An answer for many small things?
##   melee + a scald death_burst - the Kettle Beetle: it bursts when it dies. Where do you finish it?

## A Gleaner reached the camp it ran for (FieldCamps wakes that camp).
signal fetched(beast: Node, camp_id: String)

## Neutral: grazing, ignoring you until something makes it angry (grazer, skittish).
var calm := false
## Runner: where it is running to (world), and which camp that is.
var run_to: Variant = null
var run_camp := ""
## Lurker: under the ground, unseen and untouchable, until you step on its patch.
var buried := false

var _rise_t := -1.0
var _burrow_t := 0.0
var _angry_t := 0.0
var _flank_wait := 0.0
var _scatter_t := 0.0
var _swollen := false
var _kick := false
var _graze_goal := Vector3.ZERO
var _graze_t := 0.0
var _base_speed := 0.0
var _last_hit_by: Node = null
var _charge_len := 12.0              # this charge's run: its length, or far enough to carry it past you


func setup(enemy_kind: String, player: Node3D, strength: float = 1.0) -> void:
	super.setup(enemy_kind, player, strength)
	_base_speed = speed
	add_to_group("beasts")
	if behaviour == "grazer" or behaviour == "skittish":
		calm = true
	if _rig is CreatureRig:
		(_rig as CreatureRig).grazing = calm


func _ready() -> void:
	super._ready()
	if home == Vector3.ZERO:
		home = global_position
	_graze_goal = home
	if behaviour == "lurker" and not buried:
		bury()


# --- being hit ------------------------------------------------------------------------------

func take_hit(amount: float, heavy_hit: bool, source: Node, tags: Array = []) -> float:
	if buried:
		return 0.0                                  # nothing to hit under the ground
	_last_hit_by = source
	var applied: float = super.take_hit(amount, heavy_hit, source, tags)
	if applied <= 0.0 or body.is_dead():
		return applied
	_swell()
	if calm:
		provoke(source as Node3D)
	elif behaviour == "skittish":
		_angry_t = float(_def.get("angry_s", 10.0))
	if behaviour == "runner" and not has_status("staggered"):
		stagger(float(_def.get("stagger_s", 0.7)))       # it stumbles: the way to catch a runner
	return applied


## Burr-Hog: its burr mantle guards the front - but not while it stands stuck after a charge.
func guards_front(point: Vector3) -> bool:
	if behaviour == "charger" and _stuck_t > 0.0:
		return false
	return super.guards_front(point)


## Something made a neutral beast angry: it fights `who` (the herd answers through FieldCamps).
func provoke(who: Node3D = null) -> void:
	if body.is_dead():
		return
	calm = false
	asleep = false
	_going_home = false
	_angry_t = float(_def.get("angry_s", 12.0))
	var foe: Node3D = who if (who != null and is_instance_valid(who) and who.has_method("take_hit") and not who.is_in_group("enemies")) else _player
	if foe != null:
		target = foe
		_player = foe if _player == null else _player
	if _rig is CreatureRig:
		(_rig as CreatureRig).grazing = false


## Calm again: graze where it stands (a herd calms together, through FieldCamps).
func pacify() -> void:
	calm = true
	interrupt()
	_release_slot()
	telegraph = {}
	speed = _base_speed
	if _rig is CreatureRig:
		(_rig as CreatureRig).grazing = true


func is_calm() -> bool:
	return calm


func _arrived_home() -> void:
	if behaviour == "grazer" or behaviour == "skittish":
		pacify()
	elif behaviour == "lurker":
		bury()
	else:
		asleep = true


# --- the field states -------------------------------------------------------------------------

func _field_tick(delta: float, pace: float) -> bool:
	if behaviour == "lurker" and _lurker_tick(delta, pace):
		return true
	if super._field_tick(delta, pace):
		return true
	if calm:
		_graze(delta, pace)
		return true
	if behaviour == "runner":
		_runner_tick(delta, pace)
		return true
	return false


## Neutral grazing: amble between spots near home; a skittish one walks off from you.
func _graze(delta: float, pace: float) -> void:
	telegraph = {}
	var down: bool = _st_any("cannot_act") or _st_any("cannot_move")
	var want := Vector3.ZERO
	if behaviour == "skittish" and is_instance_valid(_player) and not bool(_player.get("dead")):
		var away: Vector3 = global_position - _player.global_position
		away.y = 0.0
		if away.length() < float(_def.get("shy_radius", 9.0)):
			want = away.normalized() * speed * 0.8           # it shies off - and shows you its back
	if want == Vector3.ZERO:
		_graze_t -= delta
		if _graze_t <= 0.0:
			_graze_t = randf_range(4.0, 9.0)
			var a: float = randf() * TAU
			_graze_goal = home + Vector3(cos(a), 0.0, sin(a)) * randf() * float(_def.get("graze_radius", 5.0))
		var to: Vector3 = _graze_goal - global_position
		to.y = 0.0
		if to.length() > 0.6:
			want = to.normalized() * speed * 0.45
	if down:
		want = Vector3.ZERO
	if want != Vector3.ZERO:
		_turn_toward(want.normalized(), delta)
	velocity = want * pace
	move_and_slide()
	_look(delta)


## The Gleaner: run for the camp it was sent to; there, bring it; otherwise keep away from you.
func _runner_tick(delta: float, pace: float) -> void:
	telegraph = {}
	if _st_any("cannot_act") or _st_any("cannot_move"):
		velocity = Vector3.ZERO
		_look(delta)
		return
	var want := Vector3.ZERO
	if run_to is Vector3:
		var goal: Vector3 = run_to
		var to: Vector3 = goal - global_position
		to.y = 0.0
		if to.length() <= float(_def.get("fetch_reach", 5.0)):
			var camp_id: String = run_camp
			run_to = null
			run_camp = ""
			fetched.emit(self, camp_id)
		else:
			want = to.normalized()
			var nav: LevelNav = _level_nav()
			if nav != null:
				var stepped: Vector3 = _errand.steer(nav, global_position, goal, radius, delta)
				if stepped != Vector3.ZERO:
					want = stepped
	elif is_instance_valid(_player) and not bool(_player.get("dead")):
		var away: Vector3 = global_position - _player.global_position
		away.y = 0.0
		if away.length() < float(_def.get("keep_away", 10.0)):
			want = away.normalized()
	if want != Vector3.ZERO:
		_turn_toward(want, delta)
		facing = want                           # it does not look back
	velocity = want * speed * pace
	move_and_slide()
	_look(delta)


## Send a runner off to fetch the camp `camp_id` that stands at `point` (world).
func run_for(point: Vector3, camp_id: String) -> void:
	run_to = point
	run_camp = camp_id
	asleep = false
	_going_home = false
	if is_inside_tree():
		FloatText.spawn(get_parent(), global_position + Vector3.UP * (height + 0.4), "IT RUNS", Color(1.0, 0.85, 0.4))


func is_running() -> bool:
	return run_to is Vector3


# --- the Sod-Lurker ---------------------------------------------------------------------------

## Go under: unseen, untouchable, healed, waiting on its patch.
func bury() -> void:
	buried = true
	asleep = false
	_going_home = false
	_rise_t = -1.0
	_burrow_t = 0.0
	telegraph = {}
	interrupt()
	_release_slot()
	body.heal(body.total_max())
	poise = poise_max
	statuses.clear()
	collision_layer = 0
	if is_in_group("hittable"):
		remove_from_group("hittable")
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if _rig != null:
		_rig.visible = false
	if is_inside_tree():
		global_position = Vector3(home.x, global_position.y, home.z)


func is_rising() -> bool:
	return _rise_t >= 0.0


## Heave out of the ground under whoever stepped on the patch.
func rise() -> void:
	var cfg: Dictionary = _def.get("rise", {})
	buried = false
	_rise_t = float(cfg.get("windup", 0.7))
	collision_layer = 4
	add_to_group("hittable")
	add_to_group("enemies")
	if _rig != null:
		_rig.visible = true
		_rig.position.y = -height
	if is_instance_valid(_player):
		var to: Vector3 = _player.global_position - global_position
		to.y = 0.0
		if to.length() > 0.1:
			facing = to.normalized()
	_apply_facing()


func _lurker_tick(delta: float, pace: float) -> bool:
	var cfg: Dictionary = _def.get("rise", {})
	if buried:
		velocity = Vector3.ZERO
		if is_instance_valid(_player) and not bool(_player.get("dead")) and not bool(_player.get("projecting")):
			var d: Vector3 = _player.global_position - home
			d.y = 0.0
			if d.length() <= float(cfg.get("trigger_radius", 2.2)):
				rise()
				return true
		return true
	if _rise_t >= 0.0:
		var total: float = maxf(0.01, float(cfg.get("windup", 0.7)))
		_rise_t -= delta
		var frac: float = clampf(1.0 - _rise_t / total, 0.0, 1.0)
		telegraph = {"kind": "circle", "radius": float(cfg.get("radius", 2.4)), "frac": frac, "interruptible": false}
		if _rig != null:
			_rig.position.y = lerpf(-height * 0.9, 0.0, frac * frac)
			_rig.set_windup(true)
		if _rise_t < 0.0:
			_rise_t = -1.0
			telegraph = {}
			if _rig != null:
				_rig.position.y = 0.0
				_rig.set_windup(false)
			_strike_t = 0.3
			_attack_cd = _cooldown
			if is_instance_valid(_player):
				var to: Vector3 = _player.global_position - global_position
				to.y = 0.0
				if to.length() <= float(cfg.get("radius", 2.4)) and not bool(_player.get("dead")):
					_player.call("take_hit", float(cfg.get("damage", 26.0)) * _strength, true, self)
					if _player.has_method("shove") and float(cfg.get("shove", 0.0)) > 0.0:
						_player.call("shove", to, float(cfg["shove"]))
			if is_instance_valid(_player):
				target = _player
		_look(delta)
		return true
	# up and fighting: it will not follow past its tether, and goes back under once you have gone
	if _going_home:
		return false
	var off := Vector3.ZERO
	if is_instance_valid(target):
		off = target.global_position - home
		off.y = 0.0
	var gone: bool = not is_instance_valid(target) or bool(target.get("dead")) or off.length() > float(_def.get("tether", 8.0))
	if gone:
		var at_home: Vector3 = global_position - home
		at_home.y = 0.0
		if at_home.length() > 1.2:
			go_home()
			return false
		_burrow_t += delta
		velocity = Vector3.ZERO
		telegraph = {}
		_look(delta)
		if _burrow_t >= float(_def.get("burrow_s", 4.0)):
			bury()
		return true
	_burrow_t = 0.0
	return false


# --- fighting -----------------------------------------------------------------------------

func _think_behaviour(delta: float, dir: Vector3, dist: float) -> void:
	_swell()
	match behaviour:
		"grazer", "charger":
			if behaviour == "grazer":
				speed = float(_def.get("angry_speed", _base_speed))
			_think_charging(delta, dir, dist)
		"flanker":
			_think_flanker(delta, dir, dist)
		"skittish":
			_think_skittish(delta, dir, dist)
		"darter":
			_think_darter(delta, dir, dist)
		"runner":
			velocity = Vector3.ZERO
		_:
			_think_melee(delta, dir, dist)


## Kettle Beetle: badly hurt, it swells and hurries (and its burst is near).
func _swell() -> void:
	var cfg: Dictionary = _def.get("swell", {})
	if cfg.is_empty() or _swollen:
		return
	if body.total() <= body.total_max() * float(cfg.get("below_frac", 0.5)):
		_swollen = true
		speed = _base_speed * float(cfg.get("speed_mult", 1.5))
		if _rig != null:
			_rig.scale = Vector3(1.12, 1.18, 1.12)


## Thornback and Burr-Hog: the charge down a marked lane (the Wall Commander's charge, smaller),
## else a gore at close quarters. A Burr-Hog that misses stands stuck with its guard down.
func _think_charging(delta: float, dir: Vector3, dist: float) -> void:
	var cfg: Dictionary = _def.get("charge", {})
	if _charge_left > 0.0:
		var was_hit: bool = _charge_hit
		collision_mask = 1                       # a charging beast runs through its own herd, not into it
		_tick_charge(delta)
		if _charge_left <= 0.0:
			collision_mask = 1 | 4
		if not was_hit and _charge_hit and is_instance_valid(target) and target.has_method("shove"):
			target.call("shove", _charge_dir, float(cfg.get("shove", 0.0)))
		if _charge_left <= 0.0 and _charge_hit:
			_stuck_t = minf(_stuck_t, 0.5)          # it found you: it does not stand there gaping
		return
	if _special == "charge":
		_windup -= delta
		var filled: float = 1.0 - maxf(0.0, _windup) / maxf(0.001, float(cfg.get("windup", 1.0)))
		telegraph = {"kind": "lane", "to": global_position + _charge_dir * _charge_len, "width": float(cfg.get("width", 2.0)), "frac": filled}
		if _windup < 0.0:
			_special = ""
			telegraph = {}
			_charge_left = _charge_len
			_charge_hit = false
		return
	if _windup < 0.0 and not _no_attack() and not cfg.is_empty() and float(_special_cd["charge"]) <= 0.0 \
			and dist >= float(cfg.get("min_dist", 5.0)) and dist <= float(cfg.get("max_dist", 14.0)) and _sees_target():
		_release_slot()
		_special = "charge"
		_windup = float(cfg.get("windup", 1.0))
		_special_cd["charge"] = float(cfg.get("cooldown", 6.0))
		_charge_dir = dir
		_charge_len = maxf(float(cfg.get("length", 12.0)), dist + 3.0)
		facing = dir
		return
	if behaviour == "grazer" and _windup < 0.0 and dist < float(cfg.get("min_dist", 5.0)) + 1.0 and float(_special_cd["charge"]) > 1.0:
		# a herd beast is no brawler: after a charge it wheels away to run at you again, goring
		# only whoever crowds it as it turns
		if dist <= _reach + radius and _attack_cd <= 0.0 and not _no_attack():
			_think_melee(delta, dir, dist)
			return
		_release_slot()
		_turn_toward(-dir, delta)
		velocity = -dir * speed * 0.8
		return
	_think_melee(delta, dir, dist)


## Where the player is looking, flat (their facing), or forward if unknown.
func _target_facing() -> Vector3:
	if not is_instance_valid(target):
		return Vector3.FORWARD
	var f: Variant = target.get("_facing")
	if f is Vector3 and (f as Vector3).length() > 0.01:
		var flat := Vector3((f as Vector3).x, 0.0, (f as Vector3).z)
		return flat.normalized()
	return -target.global_transform.basis.z


## True if this beast stands behind `target` (in the target's rear arc).
func is_at_targets_back() -> bool:
	if not is_instance_valid(target):
		return false
	var from: Vector3 = global_position - target.global_position
	from.y = 0.0
	if from.length() < 0.05:
		return false
	return (-_target_facing()).angle_to(from.normalized()) <= deg_to_rad(float(_cfg["rear_arc_deg"]) * 0.5)


## Ditch Hound: work round to your back, then bite there. It loses patience after a while and
## comes straight in. Its bite on your back is worse.
func _think_flanker(delta: float, dir: Vector3, dist: float) -> void:
	if _windup >= 0.0:
		_windup -= delta
		_update_melee_telegraph()
		if _windup < 0.0:
			telegraph = {}
			var hit: bool = dist <= _reach + radius and is_in_front(target.global_position) and _sees_target()
			if hit:
				var rear: bool = is_at_targets_back()
				_strike(damage * (float(_def.get("rear_bite_mult", 1.5)) if rear else 1.0), heavy)
				if rear and is_inside_tree():
					FloatText.spawn(get_parent(), target.global_position + Vector3.UP * 1.9, "BITTEN FROM BEHIND", Color(1.0, 0.5, 0.4))
			_attack_cd = _cooldown
			_strike_t = 0.22
			_flank_wait = 0.0
		return
	var f: Vector3 = _target_facing()
	var from: Vector3 = global_position - target.global_position
	from.y = 0.0
	var seen: bool = from.length() > 0.05 and f.angle_to(from.normalized()) <= deg_to_rad(float(_def.get("front_arc_deg", 110.0)) * 0.5)
	var strike_dist: float = _reach + radius - 0.2
	if not is_at_targets_back() and _flank_wait < float(_def.get("patience_s", 3.5)):
		# not at your back yet: circle round toward it
		_flank_wait += delta
		var behind: Vector3 = target.global_position - f * float(_def.get("flank_distance", 2.6))
		var side := Vector3(-f.z, 0.0, f.x) * _circle_sign
		var goal: Vector3 = behind + (side * 1.5 if seen else Vector3.ZERO)
		var to: Vector3 = goal - global_position
		to.y = 0.0
		var want: Vector3 = to.normalized() if to.length() > 0.3 else Vector3.ZERO
		# never run straight through you: bend out sideways while close and in your sight
		if dist < 2.6 and seen:
			want = (want + side * 0.8 - dir * 0.3).normalized()
		_turn_toward(want if want != Vector3.ZERO else dir, delta)
		velocity = want * speed
		return
	_turn_toward(_walk_dir, delta)
	if dist > strike_dist:
		velocity = _walk_dir * speed if _has_slot() else Vector3.ZERO
	elif _has_slot() and _attack_cd <= 0.0 and not _no_attack():
		facing = dir
		_windup = _windup_len()
		_update_melee_telegraph()


## Wirehorn: an antler toss if you stand in front, a kick if you stand behind - and the kick is
## the one to fear. Struck, it stays angry for a while; then it calms if you have gone.
func _think_skittish(delta: float, dir: Vector3, dist: float) -> void:
	_angry_t -= delta
	var kick: Dictionary = _def.get("kick", {})
	if _windup >= 0.0:
		_windup -= delta
		telegraph = {"kind": "cone", "radius": float(kick.get("reach", 2.3)) + radius, "arc_deg": float(kick.get("arc_deg", 110.0)), "dir": -facing,
			"frac": 1.0 - _windup / maxf(0.01, float(kick.get("windup", 0.4)))} if _kick else {"kind": "swing", "interruptible": false}
		if _windup < 0.0:
			telegraph = {}
			_strike_t = 0.3
			if _kick:
				_special_cd["counter"] = float(kick.get("cooldown", 2.6))
				if dist <= float(kick.get("reach", 2.3)) + radius and is_behind(target.global_position):
					_strike(float(kick.get("damage", 24.0)) * _strength, true)
					if target.has_method("shove"):
						target.call("shove", -facing, float(kick.get("shove", 3.0)))
			else:
				if dist <= _reach + radius and is_in_front(target.global_position):
					_strike(damage, heavy)
				_attack_cd = _cooldown
			if _rig is CreatureRig:
				(_rig as CreatureRig).use_alt = false
		return
	if _angry_t <= 0.0 and dist > float(_def.get("calm_distance", 14.0)):
		pacify()
		return
	if not kick.is_empty() and float(_special_cd["counter"]) <= 0.0 and not _no_attack() \
			and dist <= float(kick.get("reach", 2.3)) + radius and is_behind(target.global_position):
		_kick = true
		_windup = float(kick.get("windup", 0.4))
		if _rig is CreatureRig:
			(_rig as CreatureRig).use_alt = true
		return
	_kick = false
	_think_melee(delta, dir, dist)


## Chaff Wren: in, one peck, and away; back again in a moment.
func _think_darter(delta: float, dir: Vector3, dist: float) -> void:
	if _scatter_t > 0.0:
		_scatter_t -= delta
		var away: Vector3 = -dir
		var want: float = float(_def.get("retreat_distance", 5.0))
		if dist < want:
			_turn_toward(away, delta)
			velocity = (away + Vector3(-dir.z, 0.0, dir.x) * _circle_sign * 0.5).normalized() * speed
		else:
			_turn_toward(dir, delta)
			velocity = Vector3.ZERO
		return
	var was: bool = _windup >= 0.0
	_think_melee(delta, dir, dist)
	if was and _windup < 0.0:
		_scatter_t = float(_def.get("retreat_s", 1.3))
		_release_slot()
