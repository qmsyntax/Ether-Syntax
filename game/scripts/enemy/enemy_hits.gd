class_name EnemyHits
extends RefCounted
## Being hit, and being moved by force. A part of the enemy (docs/architecture/enemy-split.md): its back
## and front arcs, `take_hit` (the defender's side: statuses, the front guard, a floor, death and what
## it leaves), poise and the stagger, stuns and interrupts, shoves, pulls and nudges and the crush at
## the end of one. Beast overrides take_hit and guards_front, so they are always called through the node.

var enemy: Enemy
var _shove_dir := Vector3.ZERO


func _init(of: Enemy) -> void:
	enemy = of


## True if `point` is within the back arc: a hit from there is a rear hit. An Exposed body is all back.
func is_behind(point: Vector3) -> bool:
	if enemy.status_part._st_any("counts_rear"):
		return true
	var from: Vector3 = point - enemy.global_position
	from.y = 0.0
	if from.length() < 0.05:
		return false
	return (-enemy.facing).angle_to(from.normalized()) <= deg_to_rad(float(enemy._cfg["rear_arc_deg"]) * 0.5)


## True if `point` is within the front arc (the same width as the back one).
func is_in_front(point: Vector3) -> bool:
	var from: Vector3 = point - enemy.global_position
	from.y = 0.0
	if from.length() < 0.05:
		return true
	return enemy.facing.angle_to(from.normalized()) <= deg_to_rad(float(enemy._cfg["rear_arc_deg"]) * 0.5)


## `tags` are the hit's (HitContext tags): "through" passes the front guard; a status's
## damage_taken_except / damage_taken_from read them.
func take_hit(amount: float, _heavy: bool, source: Node, tags: Array = []) -> float:
	var mult := 1.0
	for id: String in enemy.statuses:
		var def: Dictionary = enemy.status_part._sdef(id)
		var excepted := false
		for t: Variant in def.get("damage_taken_except", []):
			if tags.has(t):
				excepted = true
		if not excepted:
			mult *= float(GameData.opt(def, "status", "damage_taken_mult"))
		var from_aff: Dictionary = def.get("damage_taken_from", {})
		for aff: String in from_aff:
			if tags.has(aff):
				mult *= float(from_aff[aff])
	# hide, plate or a shield in front: it shrugs off part of anything that does not come round the side
	if source is Node3D and not tags.has("through") and enemy.guards_front((source as Node3D).global_position):
		mult *= 1.0 - enemy.status_part.front_armour()
		_answer_block()
	var want: float = amount * mult
	# Spared: nothing takes it below its floor
	var floor_hp: float = 0.0
	for id: String in enemy.statuses:
		floor_hp = maxf(floor_hp, float(GameData.opt(enemy.status_part._sdef(id), "status", "floor_health")))
	if floor_hp > 0.0:
		want = minf(want, maxf(0.0, enemy.body.total() - floor_hp))
	var winding: bool = enemy._windup >= 0.0
	var applied: float = enemy.body.apply_damage(want)
	enemy._flash = 0.12
	if enemy._rig != null:
		enemy._rig.flash(0.12)
	enemy.looks_part._refresh_label()
	var hushed: bool = enemy.body.is_dead() and source != null and is_instance_valid(source) and source.has_method("hush_radius") and float(source.call("hush_radius")) > 0.0
	if applied > 0.0 and not hushed:
		enemy.hurt.emit(enemy, source)                 # its camp wakes; a herd answers (FieldCamps)
	if hushed:
		# Muffle: a kill raises no alarm - those near it cannot call for help a while
		for node: Enemy in enemy.get_tree().get_nodes_in_group("enemies"):
			if node != enemy and (node as Node3D).global_position.distance_to(enemy.global_position) <= float(source.call("hush_radius")):
				node.add_status("muted", 1, source)
	if applied > 0.0 and not enemy.body.is_dead():
		enemy.status_part._after_hurt(applied, winding)
		for id: String in enemy.statuses.keys():
			if enemy.statuses.has(id) and bool(enemy.status_part._sdef(id).get("ends_on_source_hit", false)) and (enemy.statuses[id] as Dictionary).get("by") == source and source != null:
				enemy.statuses.erase(id)                     # Charmed: a hit from whoever charmed it snaps it out
	if enemy.body.is_dead():
		enemy._release_slot()
		enemy.telegraph = {}
		var quiet: bool = enemy.status_part._st_any("no_death_effects")
		if enemy._def.has("death_burst") and str((enemy._def["death_burst"] as Dictionary).get("kind", "")) == "scald" and enemy.is_inside_tree() and not quiet:
			ScaldBurst.leave(enemy.get_parent(), enemy.global_position, enemy._def["death_burst"], enemy._strength, enemy._player)
		elif enemy._def.has("death_burst") and enemy.is_inside_tree() and not enemy.quelled and not quiet and not enemy.status_part._in_zone_flag("no_heal"):
			var cfg: Dictionary = enemy._def["death_burst"]
			var burst := CenserBurst.new()
			burst.radius = float(GameData.opt(cfg, "enemy.death_burst", "radius", "take_hit"))
			burst.delay = float(GameData.opt(cfg, "enemy.death_burst", "delay", "take_hit"))
			burst.heal_frac = float(GameData.opt(cfg, "enemy.death_burst", "heal_frac"))
			burst.status = str(cfg.get("status", "frenzied"))
			enemy.get_parent().add_child(burst)
			burst.global_position = enemy.global_position
		if not quiet:
			enemy.status_part._death_effects()
		_leave_fallen()
		enemy.remove_from_group("hittable")
		enemy.remove_from_group("enemies")
		enemy.killed.emit(enemy)
		if enemy._rig != null and enemy._rig.has_method("lie_and_fade") and enemy.get_parent() != null:
			var at: Transform3D = enemy._rig.global_transform
			enemy.remove_child(enemy._rig)
			enemy.get_parent().add_child(enemy._rig)
			enemy._rig.global_transform = at
			enemy._rig.call("lie_and_fade", GameData.num("combat", "corpse_lie_s"))
			enemy._rig = null
		enemy.queue_free()
		return applied
	# a pouncer struck while it is crouched or in the air comes down hard
	if enemy.behaviour == "pouncer" and applied > 0.0 and (enemy._windup >= 0.0 or enemy._leap_left > 0.0):
		_knock_down()
	return applied


## Take poise damage. At zero the enemy is Staggered: its attack is lost and it stands open.
## Returns true if this broke it.
func take_poise(amount: float) -> bool:
	if enemy.body.is_dead() or amount <= 0.0 or enemy.status_part.has_status("staggered"):
		return false
	enemy._poise_idle = 0.0
	for id: String in enemy.statuses:
		amount /= float(GameData.opt(GameData.status(id), "status", "poise_mult"))      # a drum behind it steadies it
	enemy.poise = maxf(0.0, enemy.poise - amount)
	if enemy.poise > 0.0:
		return false
	stagger(float(enemy._def.get("stagger_s", GameData.opt(GameData.status("staggered"), "status", "lasts"))))
	return true


## True if a hit from `point` meets this enemy's guard: it has front armour, the hit comes from
## its front arc, it is on its feet, and (for a commander) it is still in the phase where it blocks.
## A status with front_block_off (Exposed, Stripped, Seeped) takes the guard away.
func guards_front(point: Vector3) -> bool:
	if float(GameData.opt(enemy._def, "enemy", "front_armour")) <= 0.0 or enemy.status_part.has_status("staggered") or enemy.status_part.has_status("stunned") or enemy.status_part._st_any("front_block_off"):
		return false
	if enemy._def.has("front_armour_until_frac") and enemy.body.total() / enemy.body.total_max() <= float(enemy._def["front_armour_until_frac"]):
		return false
	return is_in_front(point)


## True if a shot coming from `point` stops on this enemy's shield instead of passing through.
func blocks_shot(point: Vector3) -> bool:
	return bool(enemy._def.get("blocks_shots", false)) and enemy.guards_front(point)


## A blocked hit is answered: a quick swing, if whoever struck is still in reach.
func _answer_block() -> void:
	if not enemy._def.has("counter") or enemy._windup >= 0.0 or enemy._special != "" or enemy._charge_left > 0.0 or float(enemy._special_cd["counter"]) > 0.0:
		return
	if not is_instance_valid(enemy.target) or enemy.global_position.distance_to(enemy.target.global_position) > enemy._reach + enemy.radius + 0.5:
		return
	var cfg: Dictionary = enemy._def["counter"]
	enemy._windup = float(GameData.opt(cfg, "enemy.counter", "windup"))
	enemy._special_cd["counter"] = float(GameData.opt(cfg, "enemy.counter", "cooldown"))
	enemy.looks_part._update_melee_telegraph()


## Cannot act for `seconds` and takes more damage; a bare strike on it is an Opening.
func stagger(seconds: float) -> void:
	interrupt()
	enemy._leap_left = 0.0
	enemy._stuck_t = 0.0
	enemy.statuses["staggered"] = {"stacks": 1, "t": maxf(seconds, float((enemy.statuses.get("staggered", {}) as Dictionary).get("t", 0.0)))}
	enemy.poise = enemy.poise_max                       # it gets its footing back when it gets up


func _knock_down() -> void:
	stagger(float(GameData.opt(enemy._def, "enemy", "knockdown_s")))
	enemy._attack_cd = enemy._cooldown


## Where it fell stays a body for a while, for Death's skills (Fallen).
func _leave_fallen() -> void:
	if not enemy.is_inside_tree():
		return
	var f := Fallen.new()
	f.kind = enemy.kind
	var lie: float = GameData.num("combat", "corpse_lie_s")
	if is_instance_valid(enemy._player) and enemy._player.has_method("corpse_lie_s"):
		lie = float(enemy._player.call("corpse_lie_s"))
	f.life = lie
	enemy.get_parent().add_child(f)
	f.global_position = enemy.global_position


## Cannot move or act for `seconds`; whatever it was doing is lost.
func stun(seconds: float) -> void:
	interrupt()
	enemy._leap_left = 0.0
	enemy.statuses["stunned"] = {"stacks": 1, "t": maxf(seconds, float((enemy.statuses.get("stunned", {}) as Dictionary).get("t", 0.0)))}


## Break off a wind-up. The attack is spent, not postponed.
func interrupt() -> void:
	if enemy._windup >= 0.0:
		enemy._windup = -1.0
		enemy._attack_cd = enemy._cooldown
	enemy._special = ""
	enemy._charge_left = 0.0
	enemy.telegraph = {}


## A skill that interrupts landed. Any wind-up is broken; an attack flagged interruptible (the
## one shown with a white flash, or any attack of a Read enemy) also leaves its owner staggered.
## Returns true if it staggered.
func interrupt_attack() -> bool:
	if enemy._special == "charge" or enemy._charge_left > 0.0:
		return false                            # only a stun or a poise break stops the charge
	var was_winding: bool = enemy._windup >= 0.0
	var flagged: bool = bool(enemy._def.get("interruptible", false)) or enemy.status_part._st_any("makes_interruptible")
	interrupt()
	if was_winding and flagged:
		stagger(float(enemy._cfg["interrupt_stagger_s"]))
		return true
	return false


## True while it is winding up an attack that an interrupting skill would punish.
func is_interruptible() -> bool:
	return enemy._windup >= 0.0 and (bool(enemy._def.get("interruptible", false)) or enemy.status_part._st_any("makes_interruptible"))


## True while it is moving itself in an attack: a charge, a pounce, a leap (Headwind stops those).
func is_lunging() -> bool:
	return enemy._charge_left > 0.0 or enemy._leap_left > 0.0 or enemy._special == "charge"


## Throw this enemy `metres` along `dir`. Heavier enemies go less far; Soaked ones go farther.
## It slides at the shove speed until the distance is spent or it meets something (see crushed).
func shove(dir: Vector3, metres: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.001 or metres <= 0.0 or enemy.body.is_dead():
		return
	if enemy._special == "charge" or enemy._charge_left > 0.0 or enemy.status_part._st_any("immovable"):
		return                                  # nothing moves it once it has set itself to charge
	var mult: float = enemy.status_part._shove_class()
	if enemy.status_part.has_status("soaked"):
		mult *= float(GameData.opt(GameData.status("soaked"), "status", "shove_mult"))
	for id: String in enemy.statuses.keys():
		var def: Dictionary = enemy.status_part._sdef(id)
		if id != "soaked" and def.has("shove_mult"):
			mult *= float(def["shove_mult"])
			if bool(def.get("ends_on_shove", false)):
				enemy.statuses.erase(id)              # Stilled: the next shove goes twice as far, once
	if enemy.is_inside_tree():
		for zone: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
			if float(zone.get("shove_mult")) != 1.0 and bool(zone.call("has_point", enemy.global_position, enemy.radius)):
				mult *= float(zone.get("shove_mult"))            # standing water: everything slides farther
	_shove_dir = flat.normalized()
	enemy._shove_left = metres * mult
	enemy._leap_left = 0.0
	interrupt()


## Drag this enemy toward `point`: at most `metres` (heavier ones come less far), stopping `keep`
## short of it. The same slide as a shove, so it can end in a Crush.
func pull_toward(point: Vector3, metres: float, keep: float = 0.3) -> void:
	var to: Vector3 = point - enemy.global_position
	to.y = 0.0
	var go: float = minf(metres * enemy.status_part._shove_class(), to.length() - keep)
	if go <= 0.05 or enemy.body.is_dead() or enemy._special == "charge" or enemy._charge_left > 0.0 or enemy.status_part._st_any("immovable"):
		return
	_shove_dir = to.normalized()
	enemy._shove_left = go
	enemy._leap_left = 0.0
	interrupt()


## Moved a little by something on the ground (a lane of wind). It does not interrupt anything.
func nudge(step: Vector3) -> void:
	if enemy.body.is_dead() or enemy._shove_left > 0.0 or enemy._charge_left > 0.0 or enemy._leap_left > 0.0 or enemy.status_part._st_any("immovable"):
		return
	enemy.move_and_collide(Vector3(step.x, 0.0, step.z))


## Face directly away from `point` and stay that way for `seconds`.
func turn_away_from(point: Vector3, seconds: float) -> void:
	var away: Vector3 = enemy.global_position - point
	away.y = 0.0
	if away.length() < 0.05:
		return
	enemy.facing = away.normalized()
	enemy._turned_t = seconds
	enemy.looks_part._apply_facing()


func is_shoved() -> bool:
	return enemy._shove_left > 0.0


## One physics step of a shove. The body is moved an exact distance (not by velocity, whose time
## step the engine chooses), so the budget and the ground covered always agree. Meeting anything
## solid ends the shove; if distance was still owed, that is a crush.
func _tick_shove(delta: float) -> void:
	var cfg: Dictionary = GameData.balance["shove"]
	var step: float = minf(enemy._shove_left, float(cfg["speed"]) * delta)
	enemy.velocity = Vector3.ZERO
	var col: KinematicCollision3D = enemy.move_and_collide(_shove_dir * step)
	if col == null:
		enemy._shove_left -= step
		if enemy._shove_left <= 0.0001:
			enemy._shove_left = 0.0
			_shove_ended()                         # it ran its full distance: that is the end of the shove too
		return
	var left: float = enemy._shove_left - col.get_travel().length()
	enemy._shove_left = 0.0
	_shove_ended()
	if left >= float(cfg["min_left"]):
		var hit: Node = col.get_collider() as Node
		enemy.crushed.emit(enemy, left, hit)
		if is_instance_valid(enemy.shover) and enemy.shover.has_method("on_crush"):
			enemy.shover.call("on_crush", enemy, left, hit)


## A shove or a pull is over: whoever did it may mark that (Water's Adrift, for Siltfall).
func _shove_ended() -> void:
	if is_instance_valid(enemy.shover) and enemy.shover.has_method("on_shove_ended"):
		enemy.shover.call("on_shove_ended", enemy)
