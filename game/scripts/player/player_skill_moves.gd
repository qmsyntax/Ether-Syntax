class_name PlayerSkillMoves
extends RefCounted
## The player's part for skill kinds done with the body: bursts, dashes, beams, blinks, projectiles, chains, smites, grapples, streaks, held skills.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")

var player: Player


func _init(of: Player) -> void:
	player = of


## A dash that does not pass through people has met one: it is thrown, or - if it is heavy - it
## holds, and only loses its footing.
func _dash_met(e: Node3D) -> void:
	if player._dash_on_stop.is_empty():
		return
	if float(e.get("shove_resist")) < 1.0 and player._dash_heavy_poise > 0.0:
		e.call("take_poise", player._dash_heavy_poise)
		return
	player.hits_part.apply_hit(e, player._dash_on_stop, player._dash_tags, 1.0, player._dash_vel.normalized())


## displace: move enemies instead of hurting them. See abilities.json for the three modes.
func _displace(point: Vector3, target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var chest: Vector3 = player.global_position + Vector3.UP
	player._strike_t = 0.2
	if str(ab.get("mode", "")) == "throw_target":
		_throw(target, point, ab, stage_mult, tags)
		return
	if str(ab.get("mode", "")) == "pull_target":
		if target == null:
			return
		player.casting_part._line_visual(chest, target.global_position + Vector3.UP, color)
		player.hits_part.apply_hit(target, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if is_instance_valid(target) and not bool(target.call("is_dead")):
			target.set("shover", player)
			target.call("pull_toward", player.global_position, float(ab.get("pull", 10.0)), float(ab.get("keep", 1.5)) + float(target.get("radius")))
			target.call("turn_away_from", player.global_position, float(ab.get("turn_s", 1.0)))
		return
	player.casting_part._line_visual(chest, point + Vector3.UP * 0.3, color)
	var burned: int = player.motion_part.spend_pips(int(ab["spend_pips"])) if ab.has("spend_pips") else 0
	var from_point: bool = str((ab.get("on_hit", {}) as Dictionary).get("shove_dir", "")) == "from_point"
	for e: Node3D in player.casting_part._enemies_near(point, float(ab.get("radius", 3.0))):
		player.hits_part.apply_hit(e, player.hits_part._payload(ab, "on_hit"), tags, stage_mult, (e.global_position - point) if from_point else Vector3.ZERO)
		if not is_instance_valid(e) or bool(e.call("is_dead")):
			continue
		if str(ab.get("mode", "")) == "pull_area":
			e.set("shover", player)
			e.call("pull_toward", point, float(ab.get("pull", 4.0)))
		elif burned > 0 and bool(e.call("has_status", "aloft")):
			var up: Dictionary = (e.get("statuses") as Dictionary)["aloft"]
			up["t"] = float(up["t"]) + float(ab.get("pip_seconds", 0.2)) * float(burned)



func _throw(target: Node3D, point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	if target == null or not is_instance_valid(target):
		return
	player.casting_part._line_visual(player.global_position + Vector3.UP, target.global_position + Vector3.UP * 1.5, GameData.affinity_color(str(ab.get("affinity", ""))))
	player.hits_part.apply_hit(target, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return
	if target.has_method("is_elite") and bool(target.call("is_elite")):
		target.call("stagger", float(GameData.status("staggered").get("lasts", 1.5)))
		return
	if point == Vector3.ZERO:
		point = player.motion_part._cursor_ground()                 # a targeted cast has no aimed point of its own: where you point
	var way: Vector3 = point - target.global_position
	way.y = 0.0
	if way.length() < 0.3:
		way = player._facing
	var land: Dictionary = (ab.get("on_land", {}) as Dictionary).duplicate()
	if not land.is_empty():
		land["burst_radius"] = float(land.get("radius", 1.5))
		player._landings[target.get_instance_id()] = {"payload": land, "tags": tags, "stage_mult": stage_mult}
	target.set("shover", player)
	target.call("shove", way, minf(float(ab.get("throw", 6.0)), way.length()))


## Venom Spur (clock_to): every enemy in range carrying needs_status has that status's time cut to clock_to (never
## lengthened), and what its on_expire pays is x bill_mult this once (status data, read by the status engine).
func _spur(ab: Dictionary) -> void:
	var sid: String = str(ab.get("needs_status", "dosed"))
	for e: Node3D in player.casting_part._enemies_near(player.global_position, float(ab.get("range", 8.0))):
		var entry: Dictionary = (e.get("statuses") as Dictionary).get(sid, {})
		if entry.is_empty():
			continue
		entry["t"] = minf(float(entry["t"]), float(ab["clock_to"]))
		var data: Dictionary = entry.get("data", {})
		data["bill_mult"] = float(ab.get("bill_mult", 1.0))
		entry["data"] = data
		player.casting_part._line_visual(player.global_position + Vector3.UP, e.global_position + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))


## chain: the target, then the nearest enemy to it not yet struck, and on, `jumps` times. A chain
## that fans (Contagion) jumps from each body to every unstruck enemy near it, `depth` generations.
func _chain(target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var struck: Array = []
	var from: Vector3 = player.global_position + Vector3.UP
	var cur: Node3D = target
	player._strike_t = 0.2
	if bool(ab.get("fan", false)):
		var wave: Array = [target]
		struck.append(target)
		player.casting_part._line_visual(from, target.global_position + Vector3.UP, color)
		player.hits_part.apply_hit(target, ab.get("first_hit", player.hits_part._payload(ab, "on_hit")), tags, stage_mult)
		for gen: int in int(ab.get("depth", 2)):
			var next_wave: Array = []
			for w: Variant in wave:
				if not is_instance_valid(w):
					continue
				var from_dying: bool = int(ab.get("dying_stacks", 0)) > 0 and bool((w as Node).call("has_status", "dying"))
				for e: Node3D in player.casting_part._enemies_near((w as Node3D).global_position, float(ab.get("jump_radius", 3.0))):
					if struck.has(e) or struck.size() > int(ab.get("jumps", 7)):
						continue
					struck.append(e)
					next_wave.append(e)
					player.casting_part._line_visual((w as Node3D).global_position + Vector3.UP, e.global_position + Vector3.UP, color)
					var jp: Dictionary = player.hits_part._payload(ab, "on_hit")
					if from_dying:
						jp["stacks"] = int(ab["dying_stacks"])      # Contagion: the Dying pass on more
					player.hits_part.apply_hit(e, jp, tags, stage_mult)
			wave = next_wave
		return
	var hit_tags: Array = tags + (["rear"] if bool(ab.get("force_rear", false)) else [])
	for jump: int in int(ab.get("jumps", 3)) + 1:
		var at: Vector3 = cur.global_position
		if bool(ab.get("carries_caster", false)):
			# Forked Path takes you with it: you appear behind each one as it is struck; a wall or stone between ends it
			if jump > 0 and not player.casting_part._ray(player.global_position + Vector3.UP, at + Vector3.UP).is_empty():
				return
			var back: Vector3 = -(cur.get("facing") as Vector3) if cur.get("facing") is Vector3 else (at - player.global_position).normalized()
			back.y = 0.0
			var spot: Vector3 = at + back.normalized() * (float(cur.get("radius")) + 0.9)
			player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
			var face: Vector3 = at - player.global_position
			face.y = 0.0
			if face.length() > 0.1:
				player._facing = face.normalized()
			player.has_move_goal = false
		struck.append(cur)
		player.casting_part._line_visual(from, at + Vector3.UP, color)
		from = at + Vector3.UP
		player.hits_part.apply_hit(cur, player.hits_part._payload(ab, "on_hit"), hit_tags, stage_mult)
		var next: Node3D = null
		for e: Node3D in player.casting_part._enemies_near(at, float(ab.get("jump_radius", 5.0))):
			if not struck.has(e) and (next == null or e.global_position.distance_to(at) < next.global_position.distance_to(at)):
				next = e
		if next == null:
			return
		cur = next


# --- skill behaviours (design/05 Appendix A) ---------------------------------------------------

## melee_burst: everything in the arc takes the payload at once, shoved straight away from you.
## It may first draw them in (pull_before_blast), spend something you carry (held blood, swallowed
## light, pips) for more, spend a status on each target (consume_status), throw spall off armour,
## cut your growth back for more, put fires out, blow clouds and shots away, and leave ground behind.
func _burst(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var reach: float = player.melee_range + float(ab.get("reach_bonus", 0.0))
	var half: float = deg_to_rad(float(ab["arc_deg"]) * 0.5) if ab.has("arc_deg") else player.melee_arc
	player._strike_t = 0.25
	player.combat_part._swing_visual(reach, true, false)
	var payload: Dictionary = player.hits_part._payload(ab, "on_hit")
	if ab.has("damage_from_heat"):
		# the heat is the damage, and it is spent: what you carry above the floor goes into the blow
		var own: String = str(ab["affinity"])
		var carried: float = player.casting_part.reflux_of(own)
		var floor_at: float = float(ab.get("heat_floor", 0.0))
		payload["damage"] = float(ab["damage_from_heat"]) * maxf(0.0, carried - floor_at)
		player.reflux_by[own] = minf(carried, floor_at)
		tags = tags + ["cold"]
	# a store spent for more: held blood (Outpour), swallowed light (Night Spill)
	var store: String = str(ab.get("consume", ""))
	if store != "":
		var n: int = player.hits_part.spend_blood(-1 if str(ab.get("spend_blood", "all")) == "all" else int(ab.get("spend_blood", 0))) if store == "held_blood" else player.hits_part.store_take(store)
		payload["damage"] = float(payload.get("damage", ab.get("damage", 0.0))) + float(ab.get("per_stack_damage", 0.0)) * float(n)
		if float(ab.get("per_stack_poise", 0.0)) > 0.0:
			var extra: float = float(ab["per_stack_poise"]) * float(n)
			if ab.has("poise_max"):
				extra = minf(extra, float(ab["poise_max"]))          # Black Reckoning: that much poise too, up to 60
			payload["poise"] = float(payload.get("poise", GameData.num("combat", "skill_poise"))) + extra
		if ab.has("daze_at") and n >= int(ab["daze_at"]):
			var dazes: Array = (payload.get("statuses", []) as Array).duplicate()
			dazes.append({"id": "dazed", "stacks": 1})
			payload["statuses"] = dazes
		if int(ab.get("pools_per_two_spent", 0)) > 0:
			for i: int in int(n / 2) * int(ab["pools_per_two_spent"]):
				player.hits_part.spill_blood(player.global_position + player._facing.rotated(Vector3.UP, randf_range(-half, half)) * randf_range(1.0, reach), 1)
	# pips spent for more (Blowout)
	if ab.has("spend_pips") and player.motion_part.has_slipstream():
		var burned: int = player.motion_part.spend_pips(int(ab["spend_pips"]))
		payload["damage"] = float(payload.get("damage", 0.0)) + float(ab.get("pip_damage", 0.0)) * float(burned)
		payload["shove"] = float(payload.get("shove", 0.0)) + float(ab.get("pip_shove", 0.0)) * float(burned)
	# your growth in the arc is cut back to a sprout, each patch adding to the blow (Reaping Sweep)
	if float(ab.get("patch_bonus", 0.0)) > 0.0:
		var cut := 0
		for g: Node in player.get_tree().get_nodes_in_group("growth"):
			var patch := g as GrowthPatch
			if patch == null or patch.caster != player:
				continue
			var to_g: Vector3 = patch.global_position - player.global_position
			to_g.y = 0.0
			if to_g.length() <= reach + patch.radius and (to_g.length() < 0.3 or player._facing.angle_to(to_g.normalized()) <= half):
				patch.cut_back()
				cut += 1
		var more: float = minf(float(ab.get("patch_bonus_max", 0.6)), float(ab["patch_bonus"]) * float(cut))
		if payload.has("damage_mult"):
			payload["damage_mult"] = float(payload["damage_mult"]) * (1.0 + more)
		elif payload.has("damage"):
			payload["damage"] = float(payload["damage"]) * (1.0 + more)
		player.essence = minf(player.essence_max, player.essence + float(ab.get("per_patch_essence", 0.0)) * float(cut))
		if float(ab.get("per_patch_heal", 0.0)) > 0.0 and cut > 0:
			player.combat_part.heal_over(float(ab["per_patch_heal"]) * float(cut), 2.0)                # Reaping Sweep regrows you
	# drawn in first (Backdraft)
	if bool(ab.get("pull_before_blast", false)) and float(ab.get("pull", 0.0)) > 0.0:
		for e: Node3D in player.casting_part._enemies_near(player.global_position, reach + 2.0):
			e.set("shover", player)
			e.call("pull_toward", player.global_position, float(ab["pull"]), float(e.get("radius")) + 0.6)
	var hits := 0
	var gained := 0
	for t: Node3D in player.combat_part._in_arc(reach, half):
		if bool(ab.get("needs_clear_line", false)) and not player.casting_part._ray(player.global_position + Vector3.UP, t.global_position + Vector3.UP).is_empty():
			continue
		if bool(ab.get("douses", false)) and bool(t.call("has_status", "alight")):
			t.call("clear_status", "alight")
			gained += 1
		var p: Dictionary = payload
		if ab.has("consume_status"):
			# each target's own stacks are spent on it (Clotblade)
			var c_id: String = str(ab["consume_status"])
			var n2: int = int(t.call("status_stacks", c_id)) if bool(t.call("has_status", c_id)) else 0
			if n2 > 0:
				t.call("clear_status", c_id)
				p = payload.duplicate()
				p["damage"] = float(p.get("damage", 0.0)) + float(ab.get("per_stack_damage", 0.0)) * float(n2)
				p["poise"] = float(p.get("poise", GameData.num("combat", "skill_poise"))) + float(ab.get("per_stack_poise", 0.0)) * float(n2)
		var metal: int = int(t.call("metal_class")) if t.has_method("metal_class") else 0
		var where: Vector3 = t.global_position
		if player.hits_part.apply_hit(t, p, tags, stage_mult) != null or p.has("status") or p.has("statuses"):
			hits += 1
		if ab.has("spall") and metal > 0:
			var sp: Dictionary = ab["spall"]
			for o: Node3D in player.casting_part._enemies_near(where, float(sp.get("radius", 2.5))):
				if o != t:
					player.combat_part.deal_damage(o, float(sp.get("damage_per_class", 30.0)) * float(metal) * stage_mult, tags + ["spall"])
	if hits > 0:
		if float(ab.get("heal_per_target", 0.0)) > 0.0:
			# Wearying Sweep: you regrow for every living one it wearies
			player.combat_part.heal_over(float(ab["heal_per_target"]) * float(mini(hits, int(ab.get("heal_targets_max", 99)))), float(ab.get("heal_over_s", 3.0)))
		if float(ab.get("essence_per_hit", 0.0)) > 0.0:
			player.essence = minf(player.essence_max, player.essence + float(ab["essence_per_hit"]) * float(mini(hits, int(ab.get("essence_max_hits", 99)))))
		if int(ab.get("swallow_per_hit", 0)) > 0:
			player.hits_part.store_add("swallowed", int(ab["swallow_per_hit"]) * hits + gained, 5, 12.0)
		if int(ab.get("gain_pips_per_hit", 0)) > 0 and player.motion_part.has_slipstream():
			player.pips = mini(GameData.inum("slipstream", "max"), player.pips + mini(int(ab.get("gain_pips_max", 99)), int(ab["gain_pips_per_hit"]) * hits))
	if bool(ab.get("douses", false)):
		for z: Node in player.get_tree().get_nodes_in_group("ground_zones"):
			if bool(z.get("bright")) and z.get("caster") == player and bool(z.call("has_point", player.global_position, reach)):
				z.call("end")
	if bool(ab.get("clears_clouds", false)):
		for z2: Node in player.get_tree().get_nodes_in_group("ground_zones"):
			if str(z2.get("kind")) == "cloud" and bool(z2.call("has_point", player.global_position, reach)):
				z2.call("end")
	if bool(ab.get("kill_projectiles", false)):
		for node: Node in player.get_tree().get_nodes_in_group("enemy_shots"):
			var shot := node as Node3D
			if shot != null and shot.global_position.distance_to(player.global_position) <= reach:
				shot.queue_free()
	if ab.has("zone"):
		player.world_part._lay_ground(ab["zone"], reach, ab, tags)
	if ab.has("leave_zone"):
		player.hits_part.lay_cloud(player.global_position, ab["leave_zone"], tags + ["cloud"])
	if bool(ab.get("shatters_all_stone", false)):
		for s: Variant in player.stones.duplicate():
			if is_instance_valid(s):
				(s as Stone).shatter((s as Stone).global_position - player.global_position, player)
	if bool(ab.get("shatters_stone", false)):
		for s: Variant in player.stones.duplicate():
			if is_instance_valid(s) and player.world_part._stone_in_arc(s as Stone, reach, half):
				(s as Stone).shatter(player._facing, player)


## True if the next `step` metres along `dir` would run into an enemy. A dash that punches through
## armour (Breakthrough) is only stopped by a bare body.
func _body_ahead(dir: Vector3, step: float) -> Node3D:
	if not player.is_inside_tree():
		return null
	var a := Vector2(player.global_position.x, player.global_position.z)
	var b: Vector2 = a + Vector2(dir.x, dir.z) * step
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null or bool(e.is_dead()):
			continue
		if player._dash_pass_armoured and e.has_method("metal_class") and int(e.metal_class()) >= 1:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		# only bodies in front count - one you are already past or beside does not stop you
		if (p - a).dot(Vector2(dir.x, dir.z)) > 0.0 and Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.4 + float(e.radius):
			return e
	return null


## A dash is over: what it does where it arrives (Burrow, a grapple), and the trail it leaves.
func _end_dash() -> void:
	if not player.is_inside_tree():
		return
	if not player._dash_on_arrive.is_empty():
		for e: Node3D in player.casting_part._enemies_near(player.global_position, player._dash_arrive_radius):
			player.hits_part.apply_hit(e, player._dash_on_arrive, player._dash_tags, player._dash_stage_mult)
		if bool(player._dash_ab.get("shatters_stone", false)):
			for s: Variant in player.stones.duplicate():
				if is_instance_valid(s) and (s as Stone).global_position.distance_to(player.global_position) <= player._dash_arrive_radius + 1.5:
					(s as Stone).shatter((s as Stone).global_position - player.global_position, player)
		player._dash_on_arrive = {}
	if player._dash_ab.has("leave_growth"):
		player.hits_part.plant_growth(player.global_position, player._dash_ab["leave_growth"])
	if float(player._dash_ab.get("arrive_ward", 0.0)) > 0.0:
		player.combat_part.add_ward(float(player._dash_ab["arrive_ward"]), -1.0, {"from": str(player._dash_ab.get("name", "dash"))})     # Zealous Charge
	player._dash_ab = {}
	player._dash_pass_armoured = false
	if player._dash_trail.is_empty():
		return
	var zone := GroundZone.new()
	zone.from = player._dash_start
	zone.to = player.global_position
	zone.width = float(player._dash_trail.get("width", 1.0))
	zone.life = float(player._dash_trail.get("life", 3.0))
	zone.tick_s = float(player._dash_trail.get("tick_s", 1.0))
	zone.payload = player._dash_trail.get("payload", {})
	zone.dark = bool(player._dash_trail.get("dark", false))      # Night Charge: the ground you crossed stays Dark
	if zone.dark:
		zone.kind = "dark_ground"
	zone.tags = player._dash_tags + ["zone"]
	zone.caster = player
	zone.color = player._dash_color
	player.get_parent().add_child(zone)
	player._dash_trail = {}


## dash: touch each enemy the dash passes, once. The whole stretch covered since the last check
## counts, not just where you ended up - a long step must not jump clean over someone.
func _dash_touch() -> void:
	if player._dash_pass.is_empty() or not player.is_inside_tree():
		return
	var from := Vector2(player._dash_from.x, player._dash_from.z)
	var to := Vector2(player.global_position.x, player.global_position.z)
	player._dash_from = player.global_position
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null or player._dash_passed.has(e):
			continue
		var at := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(at, from, to).distance_to(at) <= player._dash_pass_radius + float(e.radius):
			player._dash_passed.append(e)
			if player._dash_pass_armoured and int(e.metal_class()) < 1:
				continue                          # a bare body stops it instead (on_stop)
			# a shove "along" goes the way the dash goes, not away from you
			var way: Vector3 = player._dash_vel.normalized() if str(player._dash_pass.get("shove_dir", "")) == "along" else Vector3.ZERO
			player.hits_part.apply_hit(e, player._dash_pass, player._dash_tags, player._dash_stage_mult, way)


## beam: an instant line along the facing. Walls and blocks stop it; it lands on the first enemy,
## or on every enemy along it if it pierces. It may jump on from the first (Arc Lash) and glance off
## walls and stone (bounces).
func _fire_beam(ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var origin: Vector3 = player.global_position + Vector3.UP * 0.9
	var dir: Vector3 = player._facing
	var left: float = float(ab.get("range", 9.0))
	var legs: int = int(ab.get("bounces", 0)) + 1
	var first: Node3D = null
	for leg: int in legs:
		var hit: Dictionary = _beam_leg(origin, dir, left, ab, stage_mult, color, tags)
		if first == null and hit.get("first") != null:
			first = hit["first"]
		left -= float(hit["length"])
		if hit.get("normal") == null or left <= 0.2 or leg == legs - 1:
			break
		var n: Vector3 = hit["normal"]
		n.y = 0.0
		if n.length() < 0.01:
			break
		origin = (hit["end"] as Vector3) + n.normalized() * 0.05
		dir = dir.bounce(n.normalized())
		dir.y = 0.0
		dir = dir.normalized()
	if first != null and int(ab.get("jumps", 0)) > 0:
		player.hits_part._arc_on(first, player.hits_part._payload(ab, "on_hit"), tags + ["arc"], stage_mult, int(ab["jumps"]), float(ab.get("jump_radius", 4.0)))


## One straight stretch of a beam: {length, end, normal (where it met a wall, or null), first}.
func _beam_leg(origin: Vector3, dir: Vector3, reach_in: float, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> Dictionary:
	var reach: float = reach_in
	var normal: Variant = null
	# your own standing stone lets your beam through (combat review R4c) unless the skill asks to stop at it, or
	# glances off stone (bounces)
	var own_through: bool = not bool(ab.get("stops_at_own_stone", false)) and int(ab.get("bounces", 0)) <= 0
	var wall: Dictionary = player.casting_part._ray(origin, origin + dir * reach, own_through)
	if not wall.is_empty():
		reach = origin.distance_to(wall["position"])
		normal = wall["normal"]
	var on_line: Array = []
	for node: Node in player.get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null or bool(t.get("is_scenery")):
			continue
		var to: Vector3 = t.global_position - origin
		to.y = 0.0
		var along: float = to.dot(dir)
		var r: float = float(t.get("radius"))
		if along < 0.0 or along > reach + r:
			continue
		if (to - dir * along).length() <= float(ab.get("width", ab.get("line_width", 0.6))) * 0.5 + r:
			on_line.append([along, t])
	on_line.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var first: Node3D = null
	var stop: float = reach
	for row: Array in on_line:
		var t2: Node3D = row[1]
		if first == null:
			first = t2
		player.hits_part.apply_hit(t2, player.hits_part._payload(ab, "on_hit"), tags, stage_mult, dir)
		if not bool(ab.get("pierce", false)) or (t2.has_method("blocks_shot") and bool(t2.call("blocks_shot", origin))):
			stop = float(row[0])
			normal = null
			break
	player._strike_t = 0.2
	player.casting_part._line_visual(origin, origin + dir * stop, color)
	return {"length": stop, "end": origin + dir * stop, "normal": normal, "first": first}


## Where a blink would land: toward the cursor, at most `reach` away. Null if that spot is off
## the floor, inside a wall or block, or has one in the way.
func _blink_point(reach: float) -> Variant:
	var want: Vector3 = player.motion_part._cursor_ground() - player.global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = player._facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	if want.length() > reach:
		want = want.normalized() * reach
	var spot: Vector3 = player.global_position + want
	var floor_hit: Dictionary = player.casting_part._ray(spot + Vector3.UP * 4.0, spot + Vector3.DOWN * 2.0)
	if floor_hit.is_empty() or (floor_hit["position"] as Vector3).y > player.global_position.y + 0.5:
		return null
	if not player.casting_part._ray(player.global_position + Vector3.UP, spot + Vector3.UP).is_empty():
		return null
	return spot


## blink: you are simply there. Everything beside where you land takes the arrival payload.
## Arriving behind an enemy (Shadow Slip) you face its back, and your next hit is from behind.
var _swap_with: Node3D = null

func _blink(spot: Vector3, ab: Dictionary, stage_mult: float, color: Color, tags: Array) -> void:
	var from: Vector3 = player.global_position
	if _swap_with != null and is_instance_valid(_swap_with):
		_swap_with.global_position = Vector3(from.x, _swap_with.global_position.y, from.z)
		_swap_with.call("heal", float(ab.get("swap_heal", 0.0)))
		_swap_with.set("hp", minf(float(_swap_with.get("hp_max")), float(_swap_with.get("hp")) + float(ab.get("swap_heal", 0.0))))
	_swap_with = null
	player.casting_part._line_visual(from + Vector3.UP, spot + Vector3.UP, color)
	var step: Vector3 = spot - from
	step.y = 0.0
	if step.length() > 0.2:
		player._facing = step.normalized()
	if float(ab.get("rear_window", 0.0)) > 0.0:
		player._rear_window_t = float(ab["rear_window"])
	var foe: Node3D = player.casting_part._nearest_enemy_to(spot, 2.0)
	if bool(ab.get("arrive_behind", false)) and foe != null:
		var to_foe: Vector3 = foe.global_position - spot
		to_foe.y = 0.0
		if to_foe.length() > 0.1:
			player._facing = to_foe.normalized()
	player.global_position = Vector3(spot.x, from.y, spot.z)
	player.velocity = Vector3.ZERO
	player.has_move_goal = false
	var payload: Dictionary = ab.get("on_arrive", {})
	if payload.is_empty():
		return
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null:
			continue
		var to: Vector3 = e.global_position - player.global_position
		to.y = 0.0
		if to.length() <= float(ab.get("arrive_radius", 1.5)) + float(e.radius):
			player.hits_part.apply_hit(e, payload, tags, stage_mult)


func _fire_projectile(ab: Dictionary, stage_mult: float, color: Color, tags: Array = ["projectile"]) -> void:
	var bolt: Node3D = Projectile.new()
	bolt.set("color", color)
	bolt.set("tags", tags)
	var payload: Dictionary = player.hits_part._payload(ab, "on_hit")
	if ab.has("spend_pips") and payload.has("damage"):
		payload["damage"] = float(payload["damage"]) + float(ab.get("pip_damage", 0.0)) * float(player.motion_part.spend_pips(int(ab["spend_pips"])))
	if payload.has("damage"):
		payload["damage"] = float(payload["damage"]) * stage_mult        # carried on the bolt, already scaled
	if ab.has("on_hit"):
		bolt.set("payload", payload)
	bolt.set("pierce", bool(ab.get("pierce", false)))
	bolt.set("shatters_stone", bool(ab.get("shatters_stone", false)))
	bolt.set("hit_radius", maxf(0.35, float(ab.get("width", 0.0)) * 0.5))
	bolt.set("ab", ab)
	bolt.set("stage_mult", stage_mult)
	bolt.set("dir", player.casting_part.lead_aim(ab, player._facing))          # a slow shot leads its foe a little (combat review R4b)
	bolt.set("damage", float(ab["damage"]) * stage_mult)
	bolt.set("speed", float(ab["speed"]))
	bolt.set("life", float(ab["life"]))
	if bool(ab.get("shot", false)):
		# a shot (poison.json): loosed from your ranged weapon when one is worn - its damage on the dart, a ranged
		# shot for the coat - and it flies as far as your shots do (Bitter Tonic's shot_range_mult)
		bolt.set("tags", tags + ["ranged"])
		bolt.set("life", float(ab["life"]) * player.casting_part.buff_num("shot_range_mult"))
		if not player.combat_part.ranged_weapon().is_empty():
			var rm: float = player.combat_part.ranged_stat("ranged_damage_mult", 1.0)
			bolt.set("damage", float(bolt.get("damage")) * rm)
			if payload.has("damage"):
				payload["damage"] = float(payload["damage"]) * rm
				bolt.set("payload", payload)
	bolt.set("shooter", player)
	player.get_parent().add_child(bolt)
	bolt.global_position = player.casting_part._muzzle()


## Where a movement skill lands when it has a special landing: onto a corpse further off
## (Gravestep's corpse_range), or into the shadow behind an enemy (Shadow Slip). Null otherwise.
func _special_landing(ab: Dictionary) -> Variant:
	var cursor: Vector3 = player.motion_part._cursor_ground()
	if bool(ab.get("swap_thrall", false)):
		# Gravestep: a point on one of your thralls swaps the two of you (it lands where you stood)
		for s: Node3D in player.world_part.summons_near(cursor, 1.5):
			if s.global_position.distance_to(player.global_position) <= float(ab.get("thrall_range", 14.0)):
				_swap_with = s
				return Vector3(s.global_position.x, player.global_position.y, s.global_position.z)
	if float(ab.get("corpse_range", 0.0)) > 0.0:
		var f: Fallen = Fallen.nearest(player.get_tree(), cursor, 1.5)
		if f != null and f.global_position.distance_to(player.global_position) <= float(ab["corpse_range"]):
			return Vector3(f.global_position.x, player.global_position.y, f.global_position.z)
	if bool(ab.get("arrive_behind", false)):
		var foe: Node3D = player.casting_part._nearest_enemy_to(cursor, 1.5)
		if foe == null:
			foe = player.casting_part._skill_target(float(ab.get("range", 10.0)))
		if foe != null and foe.global_position.distance_to(player.global_position) <= float(ab.get("range", 10.0)) + 1.0:
			var back: Vector3 = -(foe.get("facing") as Vector3) if foe.get("facing") is Vector3 else (foe.global_position - player.global_position).normalized()
			var spot: Vector3 = foe.global_position + back.normalized() * (float(foe.get("radius")) + 1.0)
			spot.y = player.global_position.y
			if player.casting_part._ray(foe.global_position + Vector3.UP, spot + Vector3.UP).is_empty():
				return spot
	return null


## smite (hex, seize, gaze): an instant effect on one enemy - no travel. It may go off a moment
## later wherever the target has moved (delay), send it walking to where you pointed (Errand), or
## leave growth when it dies (Dwindling Gall).
func _smite(target: Node3D, point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	if target == null or not is_instance_valid(target):
		return
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	var payload: Dictionary = player.hits_part._payload(ab, "on_hit")
	if bool(ab.get("nearest_to_point", false)):
		var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
		data["goal"] = Vector3(point.x, target.global_position.y, point.z)
		payload["status_data"] = data
		# Errand: long enough to walk there, then stand stand_s
		var walk: float = Vector2(point.x - target.global_position.x, point.z - target.global_position.z).length() / maxf(0.5, float(target.get("speed")))
		payload["status_s"] = walk + float(data.get("stand_s", 2.0))
	player._strike_t = 0.2
	var from_sky: bool = bool(payload.get("through", false))
	player.casting_part._line_visual((target.global_position + Vector3.UP * 7.0) if from_sky else (player.global_position + Vector3.UP), target.global_position + Vector3.UP, color)
	if str(ab.get("on_death_growth", "")) != "":
		var kind_g: String = str(ab["on_death_growth"])
		target.tree_exiting.connect(func() -> void:
			if is_instance_valid(player) and bool(target.call("is_dead")):
				player.hits_part.plant_growth(target.global_position, {"kind": kind_g}))
	# Brushfire (spread_stacks): every enemy near the target gains as many stacks as the target carries, up to spread_max
	if str(ab.get("spread_stacks", "")) != "":
		var sid: String = str(ab["spread_stacks"])
		var n: int = int(target.call("status_stacks", sid)) if bool(target.call("has_status", sid)) else 0
		if n > 0:
			for e: Node3D in player.casting_part._enemies_near(target.global_position, float(ab.get("spread_radius", 4.0))):
				if e != target:
					player.casting_part._line_visual(target.global_position + Vector3.UP, e.global_position + Vector3.UP, color)
					var sopts: Dictionary = {"lasts": float(ab["status_s"])} if ab.has("status_s") else {}
					e.call("add_status", sid, mini(n, int(ab.get("spread_max", n))), player, sopts)
	if float(ab.get("command_radius", 0.0)) > 0.0:
		# Unleash the Pack: every summon of yours within command_radius leaps to the target, lands summon_hit, and is Unleashed
		for s: Node3D in player.world_part.summons_near(player.global_position, float(ab["command_radius"])):
			var to_t: Vector3 = target.global_position - s.global_position
			to_t.y = 0.0
			var land: Vector3 = target.global_position - to_t.normalized() * (float(target.get("radius")) + 0.8)
			player.casting_part._line_visual(s.global_position + Vector3.UP, land + Vector3.UP, color)
			s.global_position = Vector3(land.x, s.global_position.y, land.z)
			if ab.get("summon_hit") is Dictionary:
				player.hits_part.apply_hit(target, ab["summon_hit"], tags + ["thrall"], stage_mult)
			if ab.get("summon_buff") is Dictionary:
				var sb: Dictionary = (ab["summon_buff"] as Dictionary).duplicate()
				sb["t"] = float(sb.get("duration", 6.0))
				(s.get("buffs") as Dictionary)[str(sb.get("buff", "unleashed"))] = sb
	var delay: float = float(ab.get("delay", 0.0))
	if delay > 0.0:
		var mark := target
		SkillTimer.after(player.get_parent(), delay, func(_i: int) -> void:
			if is_instance_valid(mark) and not bool(mark.call("is_dead")):
				player.hits_part.apply_hit(mark, payload, tags, stage_mult))
		return
	player.hits_part.apply_hit(target, payload, tags, stage_mult)


## grapple: hauled to the point by exact distance at dash_speed (a dash for recovery and Winded);
## what is beside you when you land takes the arrival payload.
func _grapple(to: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var way: Vector3 = to - player.global_position
	way.y = 0.0
	if way.length() < 0.2:
		return
	player.casting_part._line_visual(player.global_position + Vector3.UP, to + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	player._facing = way.normalized()
	var speed: float = float(ab.get("dash_speed", 24.0))
	player._dash_vel = way.normalized() * speed
	player._dash_time = way.length() / speed
	player._dash_pass = {}
	player._dash_tags = tags
	player._dash_passed.clear()
	player._dash_from = player.global_position
	player._dash_start = player.global_position
	player._dash_trail = {}
	player._dash_stops = false
	player._dash_braced = false
	player._dash_on_stop = {}
	player._dash_on_arrive = ab.get("on_arrive", {})
	player._dash_arrive_radius = float(ab.get("arrive_radius", 1.5))
	player._dash_ab = ab
	player._dash_stage_mult = stage_mult
	player._dash_color = GameData.affinity_color(str(ab.get("affinity", "")))


## streak: along your aim in one step, up to range, through bodies (on_pass to each by the line),
## stopping short of the first wall, stone or raised shield.
func _streak(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var from: Vector3 = player.global_position
	var dir: Vector3 = player._facing
	var reach: float = float(ab.get("range", 7.0))
	var wall: Dictionary = player.casting_part._ray(from + Vector3.UP, from + Vector3.UP + dir * (reach + 0.5))
	if not wall.is_empty():
		reach = maxf(0.0, (from + Vector3.UP).distance_to(wall["position"]) - 0.6)
	var a := Vector2(from.x, from.z)
	var passed: Array = []
	for e: Node3D in player.casting_part._enemies_near(from, reach + 1.0):
		var to: Vector3 = e.global_position - from
		to.y = 0.0
		var along: float = to.dot(dir)
		if along < 0.0 or along > reach:
			continue
		if (to - dir * along).length() > float(ab.get("pass_radius", 1.1)) + float(e.get("radius")):
			continue
		if e.has_method("blocks_shot") and bool(e.call("blocks_shot", from)):
			reach = minf(reach, maxf(0.0, along - float(e.get("radius")) - 0.6))      # a raised shield stops you short
			continue
		passed.append([along, e])
	var b: Vector2 = a + Vector2(dir.x, dir.z) * reach
	var end := Vector3(b.x, from.y, b.y)
	player.casting_part._line_visual(from + Vector3.UP, end + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	player.global_position = end
	player.velocity = Vector3.ZERO
	player.has_move_goal = false
	for row: Array in passed:
		if float(row[0]) <= reach:
			player.hits_part.apply_hit(row[1], ab.get("on_pass", {}), tags, stage_mult, dir)


## A held skill begins: a channel does its work every tick while held; a charge builds while held.
## Held from a key, it ends when the key is let go; started any other way (a click on the bar, a
## test, the bot) it runs its duration, or skills.channel_max_s, or its full charge.
func _start_held(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, target: Node3D, point: Vector3, state: Dictionary) -> void:
	player._held = {"ab": ab, "kind": kind, "aff": aff, "stage_mult": stage_mult, "tags": tags, "target": target, "point": point,
		"t": 0.0, "tick": 0.0, "action": player._cast_action, "memo": {}, "state": state, "pip_t": 0.0}
	player._float("hold" if kind == "channel" else "charging", GameData.affinity_color(aff).lightened(0.3))
	if kind == "channel":
		_channel_pulse()


func _tick_held(delta: float) -> void:
	var h: Dictionary = player._held
	var ab: Dictionary = h["ab"]
	h["t"] = float(h["t"]) + delta
	var action: String = str(h["action"])
	var let_go: bool = action != "" and not Input.is_action_pressed(action)
	if player._stagger_t > 0.0 or player.dead:
		player._held = {}
		return
	if str(h["kind"]) == "charge_release":
		if let_go or float(h["t"]) >= float(ab.get("charge_max", 1.0)):
			_release_charge()
		return
	var max_t: float = float(ab.get("duration", GameData.num("skills", "channel_max_s")))
	var pay: float = float(ab.get("cost", 0.0)) * delta
	if let_go or float(h["t"]) >= max_t or player.essence < pay:
		_end_held()
		return
	player.essence -= pay
	var aff: String = str(h["aff"])
	player.reflux_by[aff] = player.casting_part.reflux_of(aff) + pay * float(ab.get("reflux_per_cost", 1.0))
	player.casting_part._advance(h["state"], pay)
	if float(ab.get("pip_cost_per_s", 0.0)) > 0.0:
		h["pip_t"] = float(h["pip_t"]) + delta * float(ab["pip_cost_per_s"])
		while float(h["pip_t"]) >= 1.0:
			h["pip_t"] = float(h["pip_t"]) - 1.0
			if player.motion_part.spend_pips(1) < 1:
				_end_held()                      # Spindrift runs on your pips
				return
	h["tick"] = float(h["tick"]) - delta
	h["paused"] = float(h.get("paused", 0.0)) - delta
	if float(h["tick"]) <= 0.0:
		h["tick"] = float(ab.get("tick", 0.5))
		if float(h["paused"]) <= 0.0:
			_channel_pulse()


## One tick of a channel, along its shape.
func _channel_pulse() -> void:
	var h: Dictionary = player._held
	var ab: Dictionary = h["ab"]
	var tags: Array = h["tags"]
	var stage_mult: float = float(h["stage_mult"])
	var payload: Dictionary = player.hits_part._payload(ab, "on_hit")
	var memo: Dictionary = h["memo"]
	var color: Color = GameData.affinity_color(str(h["aff"]))
	player._strike_t = 0.15
	match str(ab.get("shape", "self")):
		"line":
			var origin: Vector3 = player.global_position + Vector3.UP * 0.9
			var reach: float = float(ab.get("range", 8.0))
			var wall: Dictionary = player.casting_part._ray(origin, origin + player._facing * reach)
			if not wall.is_empty():
				reach = origin.distance_to(wall["position"])
			var best: Node3D = null
			for e: Node3D in player.casting_part._enemies_near(player.global_position, reach + 1.0):
				var to: Vector3 = e.global_position - player.global_position
				to.y = 0.0
				var along: float = to.dot(player._facing)
				if along >= 0.0 and along <= reach and (to - player._facing * along).length() <= float(ab.get("width", 1.0)) * 0.5 + float(e.get("radius")):
					if best == null or along < (best.global_position - player.global_position).dot(player._facing):
						best = e
			player.casting_part._line_visual(origin, (best.global_position + Vector3.UP * 0.9) if best != null else origin + player._facing * reach, color)
			if best != null:
				player.hits_part.apply_hit(best, payload, tags, stage_mult, player._facing, memo)
		"cone":
			var half: float = deg_to_rad(float(ab.get("arc_deg", 60.0)) * 0.5)
			player.combat_part._swing_visual(float(ab.get("range", 5.0)), false, false)
			for e: Node3D in player.combat_part._in_arc(float(ab.get("range", 5.0)), half):
				player.hits_part.apply_hit(e, payload, tags, stage_mult, Vector3.ZERO, memo)
		"nearest":
			var near: Node3D = player.casting_part._nearest_enemy_to(player.global_position, float(ab.get("radius", 3.0)))
			if near != null:
				player.casting_part._line_visual(player.global_position + Vector3.UP, near.global_position + Vector3.UP, color)
				player.hits_part.apply_hit(near, payload, tags, stage_mult, Vector3.ZERO, memo)
		"tether":
			var t: Variant = h["target"]
			if t == null or not is_instance_valid(t) or bool((t as Node).call("is_dead")) \
					or (t as Node3D).global_position.distance_to(player.global_position) > float(ab.get("break_range", 9.0)) \
					or not player.casting_part._ray(player.global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP).is_empty():
				player._held = {}
				return
			player.casting_part._line_visual(player.global_position + Vector3.UP, (t as Node3D).global_position + Vector3.UP, color)
			player.hits_part.apply_hit(t, payload, tags, stage_mult, Vector3.ZERO, memo)
		_:
			# self: everything round you (Deep Draught draws blood out; Regrowth mends you)
			if float(ab.get("summon_heal_per_s", 0.0)) > 0.0:
				for s: Node3D in player.world_part.summons_near(player.global_position, float(ab.get("radius", 6.0))):
					s.call("heal", float(ab["summon_heal_per_s"]) * float(ab.get("tick", 0.5)))      # Regrowth mends your living summons
			if float(ab.get("sink_per_s", 0.0)) > 0.0:
				var pts: float = float(ab["sink_per_s"]) * float(ab.get("tick", 0.5))
				var filled: Dictionary = player.body.fill_sinks(pts, true)
				player.combat_part._wounds_closed(filled["closed"])
				if player.body.has_wound("lost_arm") and float(ab.get("arm_rate", 0.0)) > 0.0:
					var arm_fill: Dictionary = player.body.fill_one("lost_arm", pts * float(ab["arm_rate"]))     # a lost arm mends too, slower
					player.combat_part._wounds_closed(arm_fill["closed"])
				return
			var taken := 0
			for e: Node3D in player.casting_part._enemies_near(player.global_position, float(ab.get("radius", 5.0))):
				var take: Dictionary = payload.get("consume_stacks", {})
				var had := true
				for st: String in take:
					had = had and bool(e.call("has_status", st))
				if not had:
					continue
				player.casting_part._line_visual(e.global_position + Vector3.UP, player.global_position + Vector3.UP, color)
				for st2: String in take:
					var left: int = int(e.call("status_stacks", st2)) - int(take[st2])
					var entry: Dictionary = (e.get("statuses") as Dictionary).get(st2, {})
					if left <= 0:
						e.call("clear_status", st2)
					elif not entry.is_empty():
						entry["stacks"] = left
					taken += int(take[st2])
				var p2: Dictionary = payload.duplicate()
				p2.erase("consume_stacks")
				player.hits_part.apply_hit(e, p2, tags, stage_mult, Vector3.ZERO, memo)
			for i: int in int(ab.get("pools_per_tick", 0)):
				var pool: BloodPool = null
				for node: Node in player.get_tree().get_nodes_in_group("blood_pools"):
					if (node as Node3D).global_position.distance_to(player.global_position) <= float(ab.get("radius", 5.0)):
						pool = node as BloodPool
						break
				if pool == null:
					break
				taken += pool.drink()
			player.hits_part.gain_blood(taken * int(ab.get("blood_per_take", 1)))


## Let go of a held skill: a charge goes off; a channel simply stops.
func _end_held() -> void:
	if player._held.is_empty():
		return
	if str(player._held["kind"]) == "charge_release":
		_release_charge()
		return
	player._held = {}
	player._recover_t = maxf(player._recover_t, GameData.num("abilities", "cast_recovery"))


## A charge is let go: the longer it was held, the harder it lands (damage toward damage_full, or
## from damage_min; damage_mult from damage_mult_min; more marks by charge).
func _release_charge() -> void:
	var h: Dictionary = player._held
	player._held = {}
	var ab: Dictionary = (h["ab"] as Dictionary).duplicate(true)
	var frac: float = clampf(float(h["t"]) / maxf(0.01, float(ab.get("charge_max", 1.0))), 0.0, 1.0)
	if bool(ab.get("focus_spend", false)) and player.focus > 0:
		# Whetted Cut: every stack of Edge Heat spent adds per_focus_mult to its damage_mult
		var add: float = float(ab.get("per_focus_mult", 0.0)) * float(player.focus)
		ab["damage_mult"] = float(ab.get("damage_mult", 1.0)) + add
		if ab.has("damage_mult_min"):
			ab["damage_mult_min"] = float(ab["damage_mult_min"]) + add
		player._float("edge spent x%d" % player.focus, Color(1.0, 0.7, 0.4))
		player.focus = 0
	if ab.has("damage_full"):
		ab["damage"] = lerpf(float(ab["damage"]), float(ab["damage_full"]), frac)
	elif ab.has("damage_min"):
		ab["damage"] = lerpf(float(ab["damage_min"]), float(ab["damage"]), frac)
	if ab.has("damage_mult_min"):
		ab["damage_mult"] = lerpf(float(ab["damage_mult_min"]), float(ab["damage_mult"]), frac)
	if ab.has("marks_by_charge"):
		var steps: Array = ab["marks_by_charge"]
		var hit: Dictionary = (ab.get("on_hit", {}) as Dictionary).duplicate()
		hit["marks"] = int(steps[clampi(int(frac * float(steps.size()) - 0.001), 0, steps.size() - 1)])
		ab["on_hit"] = hit
	var stage_mult: float = float(h["stage_mult"])
	var tags: Array = h["tags"]
	player._float("release", GameData.affinity_color(str(h["aff"])).lightened(0.3))
	match str(ab.get("release", "")):
		"delayed_blast":
			if ab.has("on_hit") and not (ab["on_hit"] as Dictionary).has("damage"):
				var hit2: Dictionary = (ab["on_hit"] as Dictionary).duplicate()
				hit2["damage"] = float(ab["damage"])
				ab["on_hit"] = hit2
			player.world_part._start_blast(player.casting_part._aim_point(float(ab.get("range", 12.0))), ab, stage_mult, tags)
		"beam":
			ab["width"] = float(ab.get("line_width", ab.get("width", 1.0)))
			_fire_beam(ab, stage_mult, GameData.affinity_color(str(h["aff"])), tags)
		"streak":
			# Stored Bolt: you cross range_min at a tap to range at a full hold, in an instant, through bodies
			ab["range"] = lerpf(float(ab.get("range_min", ab.get("range", 6.0))), float(ab.get("range", 8.0)), frac)
			var pass_hit: Dictionary = (ab.get("on_pass", {}) as Dictionary).duplicate()
			if not pass_hit.has("damage") and ab.has("damage"):
				pass_hit["damage"] = float(ab["damage"])
			if (ab.get("on_hit", {}) as Dictionary).has("marks"):
				pass_hit["marks"] = int((ab["on_hit"] as Dictionary)["marks"])      # marks by charge
			ab["on_pass"] = pass_hit
			_streak(ab, stage_mult, tags)
		_:
			_burst(ab, stage_mult, tags + ["melee"])
	player._recover_t = maxf(player._recover_t, GameData.num("abilities", "cast_recovery"))


## A bolt has stopped (a wall, its range, its last body): what it leaves there - a trail behind it,
## dark ground, a burst on a corpse it struck.
func projectile_landed(from: Vector3, at: Vector3, ab: Dictionary, tags: Array) -> void:
	if not player.is_inside_tree() or ab.is_empty():
		return
	if ab.get("split") is Dictionary:
		# Prism Bolt: where it ends it splits into count straight lines of light fanned over arc_deg round its flight
		var sp: Dictionary = ab["split"]
		var fly: Vector3 = at - from
		fly.y = 0.0
		fly = fly.normalized() if fly.length() > 0.05 else player._facing
		var n: int = int(sp.get("count", 3))
		var arc: float = deg_to_rad(float(sp.get("arc_deg", 60.0)))
		var line: Dictionary = {"width": float(sp.get("width", 0.4)), "on_hit": (sp.get("on_hit", {}) as Dictionary).duplicate(), "affinity": ab.get("affinity", "")}
		(line["on_hit"] as Dictionary)["damage"] = float(sp.get("damage", 20.0))
		var origin: Vector3 = Vector3(at.x, player.global_position.y + 0.9, at.z) + fly * 0.9
		for i: int in n:
			var ang: float = -arc * 0.5 + arc * (float(i) / maxf(1.0, float(n - 1)))
			_beam_leg(origin, fly.rotated(Vector3.UP, ang), float(sp.get("range", 7.0)), line, 1.0, GameData.affinity_color(str(ab.get("affinity", ""))), tags + ["split"])
	if ab.has("trail"):
		var cfg: Dictionary = ab["trail"]
		var zone := GroundZone.new()
		zone.from = Vector3(from.x, player.global_position.y, from.z)
		zone.to = Vector3(at.x, player.global_position.y, at.z)
		zone.width = float(cfg.get("width", 1.0))
		zone.life = float(cfg.get("life", 3.0))
		zone.tick_s = float(cfg.get("tick_s", 1.0))
		zone.payload = cfg.get("payload", {})
		zone.tags = tags + ["zone"]
		zone.caster = player
		zone.bright = false
		zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
		player.get_parent().add_child(zone)
	if ab.has("zone"):
		var cfg2: Dictionary = ab["zone"]
		var dz := GroundZone.new()
		dz.shape = "circle"
		dz.caster = player
		dz.dark = bool(cfg2.get("dark", false))
		dz.kind = "dark_ground" if dz.dark else ""
		dz.radius = float(cfg2.get("radius", 2.5))
		dz.life = float(cfg2.get("life", 6.0))
		dz.bright = false
		dz.tags = tags + ["zone"]
		dz.color = GameData.affinity_color(str(ab.get("affinity", "")))
		dz.from = Vector3(at.x, player.global_position.y, at.z)
		dz.to = dz.from
		player.get_parent().add_child(dz)


## A bolt that may strike corpses met one (Rotting Bolt): it bursts and is spent.
func projectile_hit_corpse(f: Fallen, ab: Dictionary, tags: Array, stage_mult: float) -> void:
	if f == null or f.spent:
		return
	var at: Vector3 = f.global_position
	f.spend()
	FloatText.spawn(player.get_parent(), at + Vector3.UP * 0.5, "BURST", GameData.affinity_color(str(ab.get("affinity", ""))))
	var burst: Dictionary = (ab.get("corpse_burst", {}) as Dictionary).duplicate()
	burst["burst_radius"] = float(burst.get("radius", 2.5))
	player.hits_part._burst_at(at, burst, tags + ["corpse"], stage_mult)
