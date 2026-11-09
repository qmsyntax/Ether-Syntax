class_name PlayerSkillWorld
extends RefCounted
## The player's part for skill kinds that leave something in the world: zones, rods, stones, blasts, corpses, clouds, summons, seeds, props.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const FloatText := preload("res://scripts/float_text.gd")

var player: Player


func _init(of: Player) -> void:
	player = of


## A number from the zones of your own you are standing in (1 if none).
func _zone_num(key: String) -> float:
	var out := 1.0
	if not player.is_inside_tree():
		return out
	for zone: Node in player.get_tree().get_nodes_in_group("ground_zones"):
		if zone.get("caster") == player and float(zone.get(key)) != 1.0 and bool(zone.call("has_point", player.global_position)):
			out *= float(zone.get(key))
	return out


## ground_zone: a pool at the aimed point, or a lane from your feet along your aim. A zone may last
## longer for your heat (life_per_heat) or for the pips you spend; drift; hold the dark; block sight.
func _lay_zone(point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> Node3D:
	var cfg: Dictionary = ab.get("zone", {})
	var zone := GroundZone.new()
	zone.shape = str(cfg.get("shape", "circle"))
	zone.radius = float(cfg.get("radius", 3.0))
	zone.width = float(cfg.get("width", 2.0))
	zone.life = float(cfg.get("life", 6.0))
	zone.tick_s = float(cfg.get("tick_s", 1.0))
	if cfg.has("life_per_heat"):
		zone.life = minf(float(cfg.get("life_max", 99.0)), zone.life + float(cfg["life_per_heat"]) * player.casting_part.reflux_of(str(ab.get("affinity", ""))))
	if float(ab.get("pip_seconds", 0.0)) > 0.0 and player.motion_part.has_slipstream():
		var burned: int = player.motion_part.spend_pips(-1 if bool(ab.get("spend_all_pips", false)) else int(ab.get("spend_pips", 0)))
		zone.life += float(ab["pip_seconds"]) * float(burned)
	var payload: Dictionary = (cfg.get("payload", {}) as Dictionary).duplicate()
	if payload.has("damage"):
		payload["damage"] = float(payload["damage"]) * stage_mult
	zone.payload = payload
	zone.on_enter = cfg.get("on_enter", {})
	zone.pull_per_s = float(cfg.get("pull_per_s", 0.0))
	zone.kind = str(cfg.get("kind", "dark_ground" if bool(cfg.get("dark", false)) else ""))
	zone.dark = bool(cfg.get("dark", false))
	zone.dark_extra_ticks = int(cfg.get("dark_extra_ticks", 0))
	zone.blocks_sight = bool(cfg.get("blocks_sight", false))
	zone.hides = bool(cfg.get("hides", false))
	zone.banks = str(cfg.get("banks", ""))
	zone.no_heal = bool(cfg.get("no_heal", false))
	zone.blocks_status = cfg.get("blocks_status", [])
	zone.ends_status = cfg.get("ends_status", [])
	zone.kill_projectiles = bool(cfg.get("kill_projectiles", false))
	zone.freeze_pips = bool(cfg.get("freeze_pips", false))
	zone.shed_standing = bool(cfg.get("shed_standing", false))
	zone.ends_if_left = bool(cfg.get("ends_if_left", false))
	zone.overrun_at = int(cfg.get("overrun_at", 0))
	zone.dps_mult = cfg.get("dps_mult", {})
	zone.bill_bonus = float(cfg.get("dose_bonus", 0.0))
	zone.ally_payload = cfg.get("ally_payload", {})
	if cfg.has("lit_bonus"):
		zone.bonus_vs = {"lit": float(cfg["lit_bonus"])}
	if bool(zone.bright) and bool(cfg.get("bright", false)):
		zone.light_radius = zone.radius
	if float(cfg.get("drift_speed", 0.0)) > 0.0:
		var way: Vector3 = player.velocity if str(cfg.get("drift", "")) == "caster_motion" else (Vector3(point.x, 0, point.z) - Vector3(player.global_position.x, 0, player.global_position.z))
		way.y = 0.0
		if way.length() > 0.05:
			zone.drift_vel = way.normalized() * float(cfg["drift_speed"])
	# a status that sends them out of the zone needs to know where the zone is
	if payload.has("status") and str(GameData.status(str(payload["status"])).get("flees", "")) == "zone":
		var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
		data["from"] = Vector3(point.x, player.global_position.y, point.z)
		payload["status_data"] = data
	zone.extra_status = str(cfg.get("extra_status", ""))
	zone.shove_mult = float(cfg.get("shove_mult", 1.0))
	zone.push_per_s = float(cfg.get("push_per_s", 0.0))
	zone.caster_speed_mult = float(cfg.get("caster_speed_mult", 1.0))
	zone.pip_gain_mult = float(cfg.get("pip_gain_mult", 1.0))
	zone.bright = bool(cfg.get("bright", false))
	zone.tags = tags + ["zone"]
	zone.caster = player
	zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
	if str(ab.get("at", "point")) == "feet":
		zone.from = player.global_position
		zone.to = player.global_position + player._facing * float(cfg.get("length", 10.0))
	else:
		zone.from = Vector3(point.x, player.global_position.y, point.z)
		zone.to = zone.from
	player.get_parent().add_child(zone)
	player._strike_t = 0.2
	return zone


## rod: the one Ground Rod. A new one replaces the old.
func _plant_rod(point: Vector3, ab: Dictionary) -> void:
	if is_instance_valid(player.rod):
		player.rod.queue_free()
	var r := GroundRod.new()
	r.life = float(ab.get("life", 10.0))
	r.set_meta("relay", ab)
	player.get_parent().add_child(r)
	r.global_position = Vector3(point.x, player.global_position.y, point.z)
	player.rod = r
	player._strike_t = 0.2


## A lightning skill was cast near the rod: the rod answers with an arc of its own.
func _rod_relay(aff: String, stage_mult: float) -> void:
	if aff != "lightning" or not is_instance_valid(player.rod) or player.rod.is_queued_for_deletion():
		return
	var ab: Dictionary = player.rod.get_meta("relay", {})
	if player.rod.global_position.distance_to(player.global_position) > float(ab.get("relay_radius", 8.0)):
		return
	var pick: Node3D = null
	for e: Node3D in player.casting_part._enemies_near(player.rod.global_position, float(ab.get("relay_range", 5.0))):
		if pick == null or e.global_position.distance_to(player.rod.global_position) < pick.global_position.distance_to(player.rod.global_position):
			pick = e
	if pick == null:
		return
	player.casting_part._line_visual(player.rod.global_position + Vector3.UP * 2.0, pick.global_position + Vector3.UP, GameData.affinity_color("lightning"))
	player.hits_part.apply_hit(pick, ab.get("relay_hit", {}), ["ability", "lightning", "ground_rod"], stage_mult)


## delayed_blast: mark the ground now; land_blast() does the rest when the mark comes due.
func _start_blast(point: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var blast := DelayedBlast.new()
	blast.caster = player
	blast.ab = ab
	blast.stage_mult = stage_mult
	blast.tags = tags
	blast.radius = float(ab.get("radius", 2.0))
	blast.delay = float(ab.get("delay", 0.5))
	blast.color = GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3)
	player.get_parent().add_child(blast)
	blast.global_position = Vector3(point.x, player.global_position.y, point.z)
	if bool(ab.get("follows_lit", false)):
		# Burning Glass: cast on a Lit enemy it tracks it, landing where that enemy is when the delay ends
		var lit_t: Node3D = player.casting_part._nearest_enemy_to(point, 1.5)
		if lit_t != null and bool(lit_t.call("has_status", "lit")):
			blast.follow = lit_t
	player._strike_t = 0.2


## A delayed blast goes off at `at` (called by the DelayedBlast). It may leave a cloud or a patch.
func land_blast(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var radius: float = float(ab.get("radius", 2.0))
	for e: Node3D in player.casting_part._enemies_near(at, radius):
		var marked: bool = ab.has("bonus_vs_status") and bool(e.call("has_status", str(ab["bonus_vs_status"])))
		player.hits_part.apply_hit(e, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if marked and is_instance_valid(e) and not bool(e.call("is_dead")):
			player.combat_part.deal_damage(e, float(ab.get("bonus_damage", 0.0)) * stage_mult, tags + ["bonus"])
	if ab.has("leave_zone"):
		player.hits_part.lay_cloud(at, ab["leave_zone"], tags + ["cloud"])
	if ab.has("leave_growth"):
		player.hits_part.plant_growth(at, ab["leave_growth"])
	if bool(ab.get("kill_projectiles", false)):
		for node: Node in player.get_tree().get_nodes_in_group("enemy_shots"):
			var shot := node as Node3D
			if shot != null and Vector2(shot.global_position.x - at.x, shot.global_position.z - at.z).length() <= radius:
				shot.queue_free()
	if bool(ab.get("shatters_stone", false)):
		for s: Variant in player.stones.duplicate():
			if is_instance_valid(s) and Vector2((s as Stone).global_position.x - at.x, (s as Stone).global_position.z - at.z).length() <= radius + (s as Stone).size.x * 0.5:
				(s as Stone).shatter((s as Stone).global_position - at, player)
	if ab.has("leave_prop"):
		var away: Vector3 = at - player.global_position
		raise_stone(at, away if away.length() > 0.1 else player._facing, ab["leave_prop"], stage_mult, tags)


## detonate: everything near you carrying the status loses it, and pays for it. A status list
## wakes every spell of yours at once; consume_zone lifts your own dark ground instead; keep_stacks
## reads the stacks without spending them, on every beat; gather_into pours them all into one target.
func _detonate(ab: Dictionary, stage_mult: float, tags: Array, strike_target: Node3D = null) -> void:
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	player._strike_t = 0.25
	if str(ab.get("consume_zone", "")) != "":
		_lift_zones(ab, stage_mult, tags)
		return
	if str(ab.get("gather_into", "")) == "target" and strike_target != null:
		_gather(strike_target, ab, stage_mult, tags)
		return
	if bool(ab.get("keep_stacks", false)) and int(ab.get("beats", 0)) > 0:
		_beats(ab, stage_mult, tags)
		return
	if ab.has("clock_to"):
		player.moves_part._spur(ab)
		return
	if bool(ab.get("consume_thralls", false)):
		# Bone Burst: every thrall of yours in range ends at once, each bursting for damage + hp_frac of its health
		for s: Node3D in summons_near(player.global_position, float(ab.get("range", 12.0))):
			var burst: Dictionary = player.hits_part._payload(ab, "on_hit")
			burst["damage"] = (float(ab.get("damage", 70.0)) + float(ab.get("hp_frac", 0.0)) * float(s.get("hp"))) * stage_mult
			burst["burst_radius"] = float(ab.get("burst_radius", 2.5))
			player.casting_part._line_visual(player.global_position + Vector3.UP, s.global_position + Vector3.UP, color)
			player.hits_part._burst_at(s.global_position, burst, tags + ["burst"])
			s.call("_fall")
		return
	if int(ab.get("max_sites", 0)) > 0:
		_exhume(ab, stage_mult, tags)
		return
	var ids: Array = ab["consume_status"] if ab.get("consume_status") is Array else [str(ab.get("consume_status", ""))]
	var status: String = str(ids[0])
	var carrying: Array = []
	for e: Node3D in player.casting_part._enemies_near(player.global_position, float(ab.get("range", 10.0))):
		var n := 0
		var asleep: bool = bool(e.call("has_status", "asleep"))
		for id: Variant in ids:
			var counts: int = int(e.call("status_stacks", str(id))) if bool(e.call("has_status", str(id))) else 0
			if counts > 0:
				n += counts
				e.call("clear_status", str(id))
		if n > 0:
			carrying.append([e, n, e.global_position, asleep])
	var refund := 0.0
	for row: Array in carrying:
		var stacks: int = row[1]
		var where: Vector3 = row[2]
		var carrier: Node3D = row[0]
		if bool(ab.get("needs_clear_line", false)) and not player.casting_part._ray(player.global_position + Vector3.UP, where + Vector3.UP).is_empty():
			continue                             # no clear line home: its light stays where it is
		player.casting_part._line_visual(player.global_position + Vector3.UP, where + Vector3.UP, color)
		refund += float(ab.get("refund_per_stack", 0.0)) * float(stacks)
		if ab.has("per_stack_damage") and is_instance_valid(carrier):
			player.combat_part.deal_damage(carrier, float(ab["per_stack_damage"]) * float(stacks) * stage_mult, tags + ["burst"])
		if int(ab.get("stagger_at", 0)) > 0 and stacks >= int(ab["stagger_at"]) and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			carrier.call("stagger", float(GameData.status("staggered").get("lasts", 1.5)))     # Crisis: a full fever breaks it
		if ab.has("per_target_damage") and is_instance_valid(carrier):
			player.combat_part.deal_damage(carrier, (float(ab["per_target_damage"]) + (float(ab.get("bonus_vs_asleep", 0.0)) if bool(row[3]) else 0.0)) * stage_mult, tags + ["burst"])
		if ab.has("on_hit") and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			if ab.has("burst_radius"):
				player.hits_part._burst_at(where, player.hits_part._payload(ab, "on_hit").merged({"burst_radius": float(ab["burst_radius"])}, true), tags + ["burst"], stage_mult, carrier)
			else:
				player.hits_part.apply_hit(carrier, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
		if str(ab.get("after_status", "")) != "" and is_instance_valid(carrier) and not bool(carrier.call("is_dead")):
			carrier.call("add_status", str(ab["after_status"]), 1, player)
		if float(ab.get("ray_damage", 0.0)) > 0.0:
			_home_ray(where, carrier, float(ab["ray_damage"]) * stage_mult, tags)
		if ab.has("per_stack_burst"):
			for near: Node3D in player.casting_part._enemies_near(where, float(ab.get("burst_radius", 2.0))):
				player.combat_part.deal_damage(near, float(ab["per_stack_burst"]) * float(stacks) * stage_mult, tags + ["burst"])
		if ab.has("overload_fracs"):
			var fracs: Array = ab["overload_fracs"]
			var frac: float = float(fracs[mini(stacks, fracs.size()) - 1])
			var live: Dictionary = GameData.status("live")
			var e: Node3D = row[0]
			if is_instance_valid(e) and not bool(e.call("is_dead")):
				FloatText.spawn(player.get_parent(), where + Vector3.UP * 0.6, "OVERLOAD", Color(0.85, 0.78, 1.0))
				player.combat_part.deal_damage(e, float(live.get("overload_damage", 150.0)) * frac * stage_mult, tags + ["overload"])
				if is_instance_valid(e) and not bool(e.call("is_dead")):
					e.call("stun", float(live.get("stun", 1.0)) * frac)
	if refund > 0.0:
		player.essence = minf(player.essence_max, player.essence + minf(refund, float(ab.get("cost", 0.0))))
	if ab.has("decoy_burst"):
		var db: Dictionary = ab["decoy_burst"]
		for l: Node in player.get_tree().get_nodes_in_group("lures"):
			if l is Lure and (l as Lure).caster == player and (l as Node3D).global_position.distance_to(player.global_position) <= float(ab.get("range", 10.0)):
				player.hits_part._burst_at((l as Node3D).global_position, {"damage": float(db.get("damage", 40.0)), "burst_radius": float(db.get("radius", 2.0))}, tags + ["burst"], stage_mult)
				(l as Lure).call("_break")


## Exhume: every corpse in range (spent if spends_corpse) and every point where an Infected enemy died within
## recent_infected_death_s count as sites, nearest first, up to max_sites; each bursts on_hit and leaves leave_zone.
var _death_sites: Dictionary = {}         # status id -> [{at, t}]: where bodies died carrying it (enemy.gd, status_death)

func status_death(id: String, at: Vector3) -> void:
	var list: Array = _death_sites.get(id, [])
	list.append({"at": at, "t": player._clock})
	_death_sites[id] = list


func _exhume(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var sites: Array = []
	var now: float = player._clock
	var site_status: String = str(player.hits_part._payload(ab, "on_hit").get("status", "infected"))
	for node: Node in player.get_tree().get_nodes_in_group("fallen"):
		var f := node as Fallen
		if f != null and not f.spent and f.global_position.distance_to(player.global_position) <= float(ab.get("range", 10.0)):
			sites.append([f.global_position.distance_to(player.global_position), f.global_position, f])
	var deaths: Array = _death_sites.get(site_status, [])
	for d: Dictionary in deaths.duplicate():
		if now - float(d["t"]) > float(ab.get("recent_infected_death_s", 15.0)):
			deaths.erase(d)
		elif (d["at"] as Vector3).distance_to(player.global_position) <= float(ab.get("range", 10.0)):
			sites.append([(d["at"] as Vector3).distance_to(player.global_position), d["at"], null])
	sites.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i: int in mini(sites.size(), int(ab.get("max_sites", 4))):
		var at: Vector3 = sites[i][1]
		if sites[i][2] != null and bool(ab.get("spends_corpse", true)):
			(sites[i][2] as Fallen).spend()
		var burst: Dictionary = player.hits_part._payload(ab, "on_hit")
		burst["burst_radius"] = float(ab.get("burst_radius", 2.5))
		player.hits_part._burst_at(at, burst, tags + ["burst"], stage_mult)
		if ab.get("leave_zone") is Dictionary:
			player.hits_part.lay_cloud(at, ab["leave_zone"], tags + ["cloud"])


## True if the character holds an affinity that raises standing stone.
func has_stone() -> bool:
	for aff: String in player.affinities:
		if bool(GameData.affinity(aff).get("stone", false)):
			return true
	return false


## How many of your stones are standing (or rising).
func stone_count() -> int:
	for s: Variant in player.stones.duplicate():
		if not is_instance_valid(s) or (s as Node).is_queued_for_deletion():
			player.stones.erase(s)
	return player.stones.size()


## A stone of yours fell (called by the stone).
func stone_gone(s: Node) -> void:
	player.stones.erase(s)


## Every stone of yours crumbles: a new character, or a new place.
func drop_stones() -> void:
	for s: Variant in player.stones.duplicate():
		if is_instance_valid(s):
			(s as Stone).crumble()
	player.stones.clear()


## Raise a slab at `at`, lying across `away` (the way you are looking at it). You keep only so
## many: one more crumbles the oldest.
func raise_stone(at: Vector3, away: Vector3, ab: Dictionary, stage_mult: float = 1.0, tags: Array = []) -> Node3D:
	var cfg: Dictionary = GameData.balance["stone"]
	stone_count()
	while player.stones.size() >= int(cfg["max_count"]):
		var old: Variant = player.stones.pop_front()
		if is_instance_valid(old):
			(old as Stone).crumble()
	var s := Stone.new()
	s.caster = player
	s.size = Vector3(float(ab.get("width", 3.0)), float(ab.get("height", 1.8)), float(ab.get("thickness", 0.6)))
	s.hp = float(ab.get("hp", cfg["hp"]))
	s.life = float(ab.get("life", cfg["life_s"]))
	s.rise_s = float(ab.get("rise_time", 0.35))
	s.on_rise = ab.get("on_rise", {})
	if str(ab.get("shape", "")) == "ice_wall":
		# Rime Wall: a stone of ice - as long as its length, melting when its life is out, bursting if broken early
		s.size.x = float(ab.get("length", s.size.x))
		s.shatter_burst = ab.get("shatter_burst", {})
		s.color = GameData.affinity_color(str(ab.get("affinity", ""))).darkened(0.2)
	s.tags = tags
	s.stage_mult = stage_mult
	player.get_parent().add_child(s)
	s.global_position = Vector3(at.x, player.global_position.y, at.z)
	var flat := Vector3(away.x, 0.0, away.z)
	if flat.length() > 0.01:
		s.rotation.y = atan2(-flat.x, -flat.z)
	player.stones.append(s)
	return s


## Where a slab would stand: toward the cursor, no nearer than the skill's `min_range` (so it does
## not come up under you) and no farther than its `range`; short of a wall if one is in the way.
## Null if there is no room at all.
func _prop_point(ab: Dictionary) -> Variant:
	var reach: float = float(ab.get("range", 8.0))
	var near: float = float(ab.get("min_range", 1.5))
	var want: Vector3 = player.motion_part._cursor_ground() - player.global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = player._facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	var dist: float = clampf(want.length(), near, reach)
	var dir: Vector3 = want.normalized()
	var chest: Vector3 = player.global_position + Vector3.UP
	var wall: Dictionary = player.casting_part._ray(chest, chest + dir * (dist + 0.6))
	if not wall.is_empty():
		dist = chest.distance_to(wall["position"]) - 0.6
		if dist < near:
			return null
	return player.global_position + dir * dist


## True if any part of the slab lies inside a swing of `reach` and `half_angle` from where you face.
func _stone_in_arc(s: Stone, reach: float, half_angle: float) -> bool:
	var across: Vector3 = s.global_transform.basis.x * (s.size.x * 0.5)
	for i: int in 5:
		var to: Vector3 = s.global_position + across * ((float(i) - 2.0) / 2.0) - player.global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist <= reach + s.size.z * 0.5 and (dist < 0.3 or player._facing.angle_to(to / dist) <= half_angle):
			return true
	return false


## How many blood pools lie along the stretch a-b.
func _pools_along(a: Vector3, b: Vector3) -> int:
	var n := 0
	if not player.is_inside_tree():
		return n
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	for node: Node in player.get_tree().get_nodes_in_group("blood_pools"):
		var p := node as BloodPool
		var c := Vector2(p.global_position.x, p.global_position.z)
		if Geometry2D.get_closest_point_to_segment(c, pa, pb).distance_to(c) <= p.radius + 0.4:
			n += 1
	return n


## A phantom or likeness of you that enemies take for you (a Lure).
func _leave_lure(at: Vector3, cfg: Dictionary, aff: String, tags: Array) -> Lure:
	var l := Lure.new()
	l.caster = player
	l.life = float(cfg.get("life", 3.0))
	l.hp = float(cfg.get("hp", 1.0))
	l.lure_radius = float(cfg.get("lure_radius", cfg.get("radius", 8.0)))
	l.breaks_on_hits = int(cfg.get("breaks_on_hits", 0))
	if l.breaks_on_hits > 0:
		for bid: String in player.buffs:
			l.breaks_on_hits += int((player.buffs[bid] as Dictionary).get("phantom_extra_hits", 0))      # Lucid: your phantoms last longer
	l.collapse = cfg.get("collapse", {})
	l.collapse_radius = float(cfg.get("collapse_radius", 0.0))
	l.color = GameData.affinity_color(aff).lightened(0.25)
	l.tags = tags
	player.get_parent().add_child(l)
	l.global_position = Vector3(at.x, player.global_position.y, at.z)
	return l


## summon: the body at the point gets up and fights for you (a Thrall). A body is spent; the
## oldest of more than max_count falls.
func _summon(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var needs: String = str(ab.get("needs", ""))
	var scale := 1.0
	var count := 1
	if needs.begins_with("corpse"):
		var f: Fallen = Fallen.nearest(player.get_tree(), at, 1.5)
		if f != null:
			f.spend()
	elif needs == "growth":
		# Call the Brake: a beast out of your growth - stronger for an older patch, two from a bloom; the patch is cut back
		var g: GrowthPatch = _growth_at(at, 1.5)
		if g != null:
			var age_name: String = ["sprout", "grown", "bloom"][g.age()]
			scale = float((ab.get("age_scales", {}) as Dictionary).get(age_name, 1.0))
			if g.age() >= 2:
				count = int(ab.get("bloom_count", 1))
			if bool(ab.get("spends_patch_age", false)):
				g.cut_back()
			at = g.global_position
	elif needs == "":
		at = player.global_position + player._facing * 1.2           # Heartseed: at your side
	var cap: int = int(ab.get("max_count", 2))
	var from_aff: String = str(ab.get("max_count_from", ""))
	if from_aff.begins_with("affinity."):
		cap = int(GameData.affinity(str(ab.get("affinity", ""))).get(from_aff.get_slice(".", 1), cap))     # Death's thrall_cap
	var cfg: Dictionary = ab.get("thrall", {})
	for i: int in count:
		var mine: Array = player.get_tree().get_nodes_in_group("thralls").filter(func(t: Node) -> bool: return t.get("caster") == player and str(t.get("skill")) == str(ab.get("name", "")))
		while mine.size() >= cap:
			var old: Node = mine.pop_front()
			old.call("_fall")
		var t := Thrall.new()
		t.caster = player
		t.skill = str(ab.get("name", ""))
		t.life = float(ab.get("duration", 15.0))
		t.hp = float(cfg.get("hp", 120.0)) * scale
		t.hp_max = t.hp
		t.damage = float(cfg.get("damage", 15.0)) * stage_mult * scale
		t.attack_s = float(cfg.get("attack_s", 1.2))
		t.speed = float(cfg.get("speed", 5.0))
		t.is_living = bool(cfg.get("living", false))
		t.behaviour = str(cfg.get("behaviour", "fight"))
		t.model = str(cfg.get("model", "grunt"))
		t.on_hit = cfg.get("on_hit", {})
		t.heal_per_s = float(cfg.get("heal_per_s", 0.0))
		t.heal_per_hit = float(cfg.get("heal_per_hit", 0.0))
		t.heal_radius = float(ab.get("radius", 6.0))
		t.strikable_within = float(cfg.get("strikable_within", -1.0))
		t.tags = tags
		var off := Vector3(0.7 * float(i), 0.0, 0.0)
		t.position = Vector3(at.x, player.global_position.y, at.z) + off
		player.get_parent().add_child(t)
	player.casting_part._line_visual(player.global_position + Vector3.UP, at + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))


## A body for a Death skill near `point`: a corpse, or - Last Mercy's captures - a Spared enemy of yours that kneels
## (not an elite), which is killed at once for it (the kill is yours) and leaves its body.
func _corpse_near(point: Vector3, reach: float) -> Fallen:
	var f: Fallen = Fallen.nearest(player.get_tree(), point, reach)
	if f != null:
		return f
	for e: Node3D in player.casting_part._enemies_near(point, reach):
		if e.has_method("is_elite") and bool(e.call("is_elite")):
			continue
		var st: Array = e.call("status_from", "kneels_below", player)
		if st.is_empty() or not bool(e.call("_kneeling")):
			continue
		e.call("clear_status", str(st[0]))
		var b: Body = e.get("body")
		player.combat_part.deal_damage(e, b.total() * 10.0 + 1.0, ["ability", "death", "execute", "captured"])
		return Fallen.nearest(player.get_tree(), point, reach + 1.0)
	return null


## Your growth patch nearest `at`, within `reach`, or null.
func _growth_at(at: Vector3, reach: float) -> GrowthPatch:
	var best: GrowthPatch = null
	for node: Node in player.get_tree().get_nodes_in_group("growth"):
		var g := node as GrowthPatch
		if g == null or g.caster != player:
			continue
		var d: float = Vector2(g.global_position.x - at.x, g.global_position.z - at.z).length()
		if d <= reach + g.radius and (best == null or d < Vector2(best.global_position.x - at.x, best.global_position.z - at.z).length()):
			best = g
	return best


## Your summons (any kind) within `radius` of `at`.
func summons_near(at: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not player.is_inside_tree():
		return out
	for node: Node in player.get_tree().get_nodes_in_group("thralls"):
		var t := node as Node3D
		if t != null and t.get("caster") == player and not bool(t.call("is_dead")) and t.global_position.distance_to(at) <= radius:
			out.append(t)
	return out


## A summon of yours heals (Heartseed's heal_per_s): you, and your living summons within its radius.
func summon_heals(from: Node3D, points: float, radius: float) -> void:
	if from.global_position.distance_to(player.global_position) <= radius:
		player.combat_part.life_heal(points)
	for s: Node3D in summons_near(from.global_position, radius):
		if s != from:
			s.call("heal", points)


## A self buff with a radius is shared with your summons within it (Life, Nature, Holy, Death's thrall_ keys,
## Dream's buff_targets: one mechanic): each gets the buff for the same time; an affinity with shares_living_only
## shares with living summons only. A summon_ward goes over each too.
func _share_buff(ab: Dictionary, bid: String, lasts: float) -> void:
	var aff: Dictionary = GameData.affinity(str(ab.get("affinity", "")))
	var shares: bool = bool(aff.get("shares_buffs", false)) or (ab.get("buff_targets", []) as Array).has("summons")
	if not shares or float(ab.get("radius", 0.0)) <= 0.0:
		return
	for s: Node3D in summons_near(player.global_position, float(ab["radius"])):
		if bool(aff.get("shares_living_only", false)) and not bool(s.get("is_living")):
			continue
		var copy: Dictionary = ab.duplicate(true)
		copy["t"] = lasts
		(s.get("buffs") as Dictionary)[bid] = copy
		if float(ab.get("summon_ward", 0.0)) > 0.0:
			s.call("add_ward", float(ab["summon_ward"]), lasts)


## seed: hidden seeds spread round the point, each bursting when stepped on or after a while.
func _sow(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var n: int = int(ab.get("seeds", 5))
	var spread: float = float(ab.get("radius", 2.5))
	for i: int in n:
		var a: float = TAU * float(i) / float(n)
		var r: float = spread * (0.35 + 0.65 * float(i % 2))
		var s := SeedTrap.new()
		s.caster = player
		s.payload = player.hits_part._payload(ab, "on_hit")
		s.tags = tags
		s.stage_mult = stage_mult
		s.trigger_radius = float(ab.get("trigger_radius", 0.6))
		s.burst_radius = float(ab.get("burst_radius", 1.2))
		s.delay = float(ab.get("delay", 6.0))
		s.life = float(ab.get("duration", 20.0))
		s.growth = ab.get("leave_growth", {})
		s.color = GameData.affinity_color(str(ab.get("affinity", "")))
		player.get_parent().add_child(s)
		s.global_position = Vector3(at.x + cos(a) * r, player.global_position.y, at.z + sin(a) * r)
	player._strike_t = 0.2


## field_pulse: acts on your own field pieces - corpses (Lay to Rest) or growth patches (Sere
## Ground wilts them for a burst each; Greening grows them on).
func _field_pulse(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	player._strike_t = 0.25
	var centre: Vector3 = at if ab.has("range") else player.global_position
	var radius: float = float(ab.get("radius", 6.0))
	var color: Color = GameData.affinity_color(str(ab.get("affinity", "")))
	if ab.has("max_take"):
		# Deep Draught: every blood pool within pool_radius and a Bleeding stack from every bleeder within radius, one
		# measure each (blood_per_take), at most max_take; the bleeders take on_hit
		var took := 0
		var cap_t: int = int(ab["max_take"])
		for node: Node in player.get_tree().get_nodes_in_group("blood_pools").duplicate():
			if took >= cap_t:
				break
			if (node as Node3D).global_position.distance_to(player.global_position) <= float(ab.get("pool_radius", 4.0)):
				took += int(node.call("drink"))
		var hit: Dictionary = player.hits_part._payload(ab, "on_hit")
		var take: Dictionary = hit.get("consume_stacks", {})
		hit.erase("consume_stacks")
		for e: Node3D in player.casting_part._enemies_near(player.global_position, radius):
			if took >= cap_t:
				break
			for st: String in take:
				if bool(e.call("has_status", st)):
					var entry: Dictionary = (e.get("statuses") as Dictionary).get(st, {})
					var left: int = int(e.call("status_stacks", st)) - int(take[st])
					if left <= 0:
						e.call("clear_status", st)
					elif not entry.is_empty():
						entry["stacks"] = left
					took += int(take[st])
					player.casting_part._line_visual(e.global_position + Vector3.UP, player.global_position + Vector3.UP, color)
					player.hits_part.apply_hit(e, hit, tags, stage_mult)
		player.hits_part.gain_blood(mini(took, cap_t) * int(ab.get("blood_per_take", 1)))
		return
	if ab.has("max_corpses"):
		var n := 0
		for node: Node in player.get_tree().get_nodes_in_group("fallen").duplicate():
			var f := node as Fallen
			if f == null or f.spent or f.global_position.distance_to(centre) > radius or n >= int(ab["max_corpses"]):
				continue
			n += 1
			player.casting_part._line_visual(player.global_position + Vector3.UP, f.global_position + Vector3.UP * 0.3, color)
			player.essence = minf(player.essence_max, player.essence + float(ab.get("per_corpse_essence", 0.0)))
			var aff: String = str(ab.get("affinity", ""))
			player.reflux_by[aff] = maxf(0.0, player.casting_part.reflux_of(aff) - float(ab.get("per_corpse_reflux", 0.0)))
			for e: Node3D in player.casting_part._enemies_near(f.global_position, float(ab.get("drag_radius", 2.0))):
				player.hits_part.apply_hit(e, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
			f.spend()
		return
	for node: Node in player.get_tree().get_nodes_in_group("growth").duplicate():
		var g := node as GrowthPatch
		if g == null or g.caster != player or g.global_position.distance_to(centre) > radius:
			continue
		if int(ab.get("ages_added", 0)) > 0:
			g.grow(int(ab["ages_added"]))
			for i: int in int(ab.get("spreads", 0)):
				g.spread()
			g.boost = float(ab.get("effect_mult", 1.0))
			g.boost_t = float(ab.get("duration", 6.0))
			if ab.has("green_heal_mult") or ab.has("green_damage_mult"):
				player.buffs["greening"] = {"t": float(ab.get("duration", 6.0)), "green_heal_mult": float(ab.get("green_heal_mult", 1.0)),
					"green_damage_mult": float(ab.get("green_damage_mult", 1.0)), "affinity": ab.get("affinity", "")}
			continue
		var p: Dictionary = player.hits_part._payload(ab, "on_hit")
		p["damage"] = float(ab.get("per_stack_damage", 30.0)) * (g.mult() if bool(ab.get("age_scales", false)) else 1.0)
		for e: Node3D in g.inside():
			player.hits_part.apply_hit(e, p, tags + ["growth"], stage_mult)
		g.wilt()


## Lift every zone of yours of that kind in range (Daybreak): on_hit to everyone standing in one.
func _lift_zones(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var want: String = str(ab["consume_zone"])
	for node: Node in player.get_tree().get_nodes_in_group("ground_zones").duplicate():
		var z := node as GroundZone
		if z == null or z.caster != player or z.kind != want or z.from.distance_to(player.global_position) > float(ab.get("range", 12.0)):
			continue
		for e: Node3D in z.inside():
			player.hits_part.apply_hit(e, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
		z.end()


## Pour every other dosed enemy's doses into one (Funnel).
func _gather(target: Node3D, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("consume_status", "dosed"))
	var total := 0
	for e: Node3D in player.casting_part._enemies_near(target.global_position, float(ab.get("gather_radius", 6.0))):
		if e == target or not bool(e.call("has_status", id)):
			continue
		total += int(e.call("status_stacks", id))
		e.call("clear_status", id)
		player.casting_part._line_visual(e.global_position + Vector3.UP, target.global_position + Vector3.UP, GameData.affinity_color(str(ab.get("affinity", ""))))
	var cap: int = int(ab.get("gather_cap", 20))
	var have: int = int(target.call("status_stacks", id)) if bool(target.call("has_status", id)) else 0
	var add: int = mini(total, cap - have)
	if add > 0:
		target.call("add_status", id, 0, player)
		var entry: Dictionary = (target.get("statuses") as Dictionary).get(id, {})
		if not entry.is_empty():
			entry["stacks"] = have + add            # above the usual cap: gathered doses may go to gather_cap
	if ab.has("on_hit"):
		player.hits_part.apply_hit(target, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)


## The heart hammers: `beats` times, beat_s apart, every enemy near you carrying the status pays
## per stack it holds then, and the stacks stay (Hammering Heart).
func _beats(ab: Dictionary, stage_mult: float, tags: Array) -> void:
	var id: String = str(ab.get("needs_status", ab.get("consume_status", "bleeding")))
	var reach: float = float(ab.get("range", 10.0))
	SkillTimer.after(player.get_parent(), 0.0, func(_i: int) -> void:
		if not is_instance_valid(player):
			return
		for e: Node3D in player.casting_part._enemies_near(player.global_position, reach):
			var n: int = int(e.call("status_stacks", id)) if bool(e.call("has_status", id)) else 0
			if n <= 0:
				continue
			player.combat_part.deal_damage(e, float(ab.get("per_stack_damage", 8.0)) * float(n) * stage_mult, tags + ["beat"])
			if is_instance_valid(e) and not bool(e.call("is_dead")) and ab.has("on_hit"):
				player.hits_part.apply_hit(e, ab["on_hit"], tags, stage_mult)
			if int(ab.get("pool_per_beat", 0)) > 0 and is_instance_valid(e):
				player.hits_part.spill_blood(e.global_position, int(ab["pool_per_beat"])), int(ab.get("beats", 3)) - 1, float(ab.get("beat_s", 0.5)))


## The light comes home (Gathered Light): every other enemy on the straight line from it to you
## takes the ray; walls and stone end it.
func _home_ray(from: Vector3, skip: Node3D, damage: float, tags: Array) -> void:
	var to: Vector3 = player.global_position
	var hit: Dictionary = player.casting_part._ray(from + Vector3.UP, to + Vector3.UP)
	if not hit.is_empty():
		return
	player.casting_part._line_visual(from + Vector3.UP, to + Vector3.UP, GameData.affinity_color("light"))
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for e: Node3D in player.casting_part._enemies_near((from + to) * 0.5, from.distance_to(to) * 0.5 + 1.0):
		if e == skip:
			continue
		var p := Vector2(e.global_position.x, e.global_position.z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 0.6 + float(e.get("radius")):
			player.combat_part.deal_damage(e, damage, tags + ["ray"])


## prop: a slab of stone (raise_stone), or a lamp, or a likeness of you that draws enemies.
func _raise_prop(at: Vector3, ab: Dictionary, stage_mult: float, tags: Array) -> void:
	match str(ab.get("shape", "")):
		"echo":
			# Stray Echo: an unseen sound - every enemy within lure_radius turns to it and walks to it (a Lure); it cracks
			# on those right beside it as it is set
			var echo: Lure = _leave_lure(at, {"life": float(ab.get("turn_s", ab.get("life", 3.0))), "hp": 9999.0,
				"lure_radius": float(ab.get("lure_radius", 8.0)), "breaks_on_hits": 1}, str(ab.get("affinity", "")), tags)
			echo.visible = false
			for e: Node3D in player.casting_part._enemies_near(at, float(ab.get("crack_radius", 1.5))):
				player.hits_part.apply_hit(e, player.hits_part._payload(ab, "on_hit"), tags, stage_mult)
			return
		"lamp":
			for l: Node in player.get_tree().get_nodes_in_group("lamps"):
				if l.get("caster") == player:
					l.queue_free()                   # one lamp at a time
			var lamp := Lamp.new()
			lamp.caster = player
			lamp.life = float(ab.get("life", 12.0))
			lamp.light_radius = float(ab.get("light_radius", 5.0))
			lamp.tick_s = float(ab.get("tick_s", 0.5))
			lamp.payload = ab.get("payload", {})
			lamp.sear_bonus = float(ab.get("sear_bonus", 0.0))
			lamp.tags = tags
			lamp.color = GameData.affinity_color(str(ab.get("affinity", "")))
			player.get_parent().add_child(lamp)
			lamp.global_position = Vector3(at.x, player.global_position.y, at.z)
			return
	if ab.has("collapse_radius") or (ab.has("blocks") and not bool(ab["blocks"])):
		# a likeness of you: enemies within radius turn on it, and it falls apart when it breaks. Raised from a corpse
		# (Death Mask) it stands longer and tougher, and its collapse leaves collapse_status
		var life_l: float = float(ab.get("life", 5.0))
		var hp_l: float = float(ab.get("hp", 150.0))
		var collapse: Dictionary = {"damage": float(ab.get("damage", 40.0)) * stage_mult}
		if str(ab.get("collapse_status", "")) != "":
			collapse["status"] = str(ab["collapse_status"])
		var body_f: Fallen = Fallen.nearest(player.get_tree(), at, 1.5) if str(ab.get("needs", "")).begins_with("corpse") else null
		if body_f != null:
			body_f.spend()
			life_l = float(ab.get("corpse_life", life_l))
			hp_l *= float(ab.get("corpse_hp_mult", 1.0))
		_leave_lure(at, {"life": life_l, "hp": hp_l, "radius": float(ab.get("radius", 6.0)),
			"breaks_on_hits": 0, "collapse": collapse, "collapse_radius": float(ab.get("collapse_radius", 3.0))}, str(ab.get("affinity", "")), tags)
		return
	# heartwood: a growing stone that only one may stand of, and that puts out growth
	if int(ab.get("max_count", 0)) > 0:
		var count := 0
		for s: Variant in player.stones.duplicate():
			if is_instance_valid(s) and (s as Stone).get_meta("ability", "") == str(ab.get("name", "")):
				count += 1
				if count >= int(ab["max_count"]):
					(s as Stone).crumble()
	var stone: Node3D = raise_stone(at, player._facing, ab, stage_mult, tags)
	stone.set_meta("ability", str(ab.get("name", "")))
	if float(ab.get("decoy_s", 0.0)) > 0.0:
		# Heartwood: for decoy_s after it rises, enemies within decoy_radius go for it instead of you
		_leave_lure(at, {"life": float(ab["decoy_s"]), "hp": float(ab.get("hp", 300.0)), "lure_radius": float(ab.get("decoy_radius", 5.0)),
			"breaks_on_hits": 0}, str(ab.get("affinity", "")), tags).visible = false
	if float(ab.get("hp_per_s", 0.0)) > 0.0 or float(ab.get("spread_every", 0.0)) > 0.0:
		var grow_t := [0.0]
		var kind_g: String = str(ab.get("spread_kind", "bramble"))
		var every: float = float(ab.get("spread_every", 5.0))
		var per_s: float = float(ab.get("hp_per_s", 0.0))
		SkillTimer.after(player.get_parent(), 1.0, func(_i: int) -> void:
			if not is_instance_valid(stone) or stone.is_queued_for_deletion():
				return
			stone.set("hp", float(stone.get("hp")) + per_s)
			grow_t[0] = float(grow_t[0]) + 1.0
			if every > 0.0 and float(grow_t[0]) >= every:
				grow_t[0] = 0.0
				player.hits_part.plant_growth(stone.global_position + player._facing * 1.2, {"kind": kind_g}), int(ab.get("life", 30.0)), 1.0)


## Ground a burst leaves under you: dark ground round you (Hungry Dark), or along the cone (Night Spill).
func _lay_ground(cfg: Dictionary, reach: float, ab: Dictionary, tags: Array) -> void:
	var zone := GroundZone.new()
	zone.caster = player
	zone.dark = bool(cfg.get("dark", false))
	zone.kind = "dark_ground" if zone.dark else str(cfg.get("kind", ""))
	zone.life = float(cfg.get("life", 5.0))
	zone.bright = false
	zone.tags = tags + ["zone"]
	zone.color = GameData.affinity_color(str(ab.get("affinity", "")))
	if str(cfg.get("shape", "circle")) == "cone":
		zone.shape = "strip"
		zone.from = player.global_position
		zone.to = player.global_position + player._facing * reach
		zone.width = reach * 0.8
	else:
		zone.shape = "circle"
		zone.radius = float(cfg.get("radius", 3.0))
		zone.from = player.global_position
		zone.to = player.global_position
	player.get_parent().add_child(zone)
