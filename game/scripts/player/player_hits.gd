class_name PlayerHits
extends RefCounted
## The player's part for what a hit does: apply_hit (the hit payload) and the affinity rules as data.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const FloatText := preload("res://scripts/float_text.gd")

var player: Player


func _init(of: Player) -> void:
	player = of


## The v2 role rules that tick on you: Nature's In the Green, Embalm's held corpses, Red Frenzy's upkeep.
func _tick_roles(delta: float) -> void:
	player._clock += delta
	if in_the_green():
		var green: Dictionary = green_rule()
		player.combat_part.life_heal(float(green.get("heal_per_s", 0.0)) * delta * player.casting_part.buff_num("green_heal_mult"))
	for bid: String in player.buffs.keys():
		if not player.buffs.has(bid):
			continue
		var b: Dictionary = player.buffs[bid]
		if bool(b.get("corpse_hold", false)) and player.is_inside_tree():
			for node: Node in player.get_tree().get_nodes_in_group("fallen"):
				if (node as Node3D).global_position.distance_to(player.global_position) <= float(b.get("radius", 12.0)):
					node.set("life", float(node.get("life")) + delta)          # Embalm: the dead near you do not age
		if float(b.get("upkeep_blood_per_s", 0.0)) > 0.0:
			b["upkeep_t"] = float(b.get("upkeep_t", 0.0)) + delta
			if float(b["upkeep_t"]) >= float(b.get("upkeep_grace_s", 0.0)):
				b["upkeep_acc"] = float(b.get("upkeep_acc", 0.0)) + float(b["upkeep_blood_per_s"]) * delta
				while float(b["upkeep_acc"]) >= 1.0:
					b["upkeep_acc"] = float(b["upkeep_acc"]) - 1.0
					if spend_blood(1) < 1:
						player.buffs.erase(bid)                  # Red Frenzy: no blood left to drink, it ends
						break


## The In the Green numbers of an affinity you hold that has them (Nature's), else {}.
func green_rule() -> Dictionary:
	for aff: String in player.affinities:
		var g: Dictionary = GameData.affinity(aff).get("in_the_green", {})
		if not g.is_empty():
			return g
	return {}


## True while you stand on your own growth (Nature's rule, In the Green).
func in_the_green() -> bool:
	if not player.is_inside_tree() or green_rule().is_empty():
		return false
	for node: Node in player.get_tree().get_nodes_in_group("growth"):
		var g := node as GrowthPatch
		if g != null and g.caster == player and g.has_point(player.global_position):
			return true
	return false
var _blood_thin_t := 0.0


## The sear_bonus of lamps of yours whose light reaches `at` (Still Lamp).
func _lamp_sear(at: Vector3) -> float:
	var b := 0.0
	if not player.is_inside_tree():
		return b
	for l: Node in player.get_tree().get_nodes_in_group("lamps"):
		if l.get("caster") == player and float(l.get("sear_bonus")) > 0.0 and Vector2(at.x - (l as Node3D).global_position.x, at.z - (l as Node3D).global_position.z).length() <= float(l.get("light_radius")):
			b += float(l.get("sear_bonus"))
	return b


## How much an affinity's own reflux multiplies its damage right now (1.0 for most affinities).
func heat_mult(aff: String) -> float:
	return 1.0 + float(GameData.affinity(aff).get("damage_per_reflux", 0.0)) * player.casting_part.reflux_of(aff) / 100.0


# --- the hit payload (design/05 Appendix B) ---------------------------------------------------

## A skill's payload for one of its touches ("on_hit", "on_pass", "on_arrive"), with the skill's
## own damage folded in when the payload does not carry any.
func _payload(ab: Dictionary, key: String) -> Dictionary:
	var p: Dictionary = (ab.get(key, {}) as Dictionary).duplicate()
	if key == "on_hit" and not p.has("damage") and not p.has("damage_mult"):
		if ab.has("damage"):
			p["damage"] = ab["damage"]
		elif ab.has("damage_mult"):
			p["damage_mult"] = ab["damage_mult"]
	return p


## Everything a skill does to one target, in one place: what it spends on the target first
## (`consume`), damage (through the talent pipeline), then statuses, stun, poise (and a Shatter),
## interrupts, turning, shove or pull, Live marks, and arcs on to more enemies (`jumps`). `dir` is
## the way a shove goes; zero means straight away from you. Scenery only takes the damage. `once`
## is a ticking payload's memo (a zone, a channel, a cloud, a growth patch): through it a hold (a
## status marked control, a stun, an interrupt) lands at most once per target per cast.
## The affinities' rules gate it first: Life does nothing to the unliving, Dream nothing to a mind
## that cannot see you (unless it sleeps).
func apply_hit(target: Node, payload: Dictionary, tags: Array = [], stage_mult: float = 1.0, dir: Vector3 = Vector3.ZERO, once: Variant = null) -> HitContext:
	var ctx: HitContext = null
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		return ctx
	if not _affinity_reaches(target, tags):
		return ctx
	var memo: Variant = once if once is Dictionary else null
	var key: int = target.get_instance_id()
	var held_before: bool = memo != null and (memo as Dictionary).has(key)
	if bool(payload.get("through", false)):
		tags = tags + ["through"]
	if payload.has("consume") and target.has_method("status_stacks"):
		_consume_on(target, payload["consume"], tags, stage_mult)
		if not is_instance_valid(target) or bool(target.call("is_dead")):
			return ctx
	# bonus_vs {status: fraction}: more damage to a target that already carries that status
	var bonus := 1.0
	var flat := 0.0
	if target.has_method("has_status"):
		for st: String in (payload.get("bonus_vs", {}) as Dictionary):
			if bool(target.call("has_status", st)):
				bonus += float((payload["bonus_vs"] as Dictionary)[st])
		for st2: String in (payload.get("bonus_flat_vs", {}) as Dictionary):
			if bool(target.call("has_status", st2)):
				flat = maxf(flat, float((payload["bonus_flat_vs"] as Dictionary)[st2]))
	if payload.has("unliving_mult") and not bool(target.get("is_living")):
		bonus *= float(payload["unliving_mult"])
	# Cataract (against_wall_mult): a body already pressed against a wall, stone or another body takes more, and it is
	# a Crush where it stands (Water's rule, its Ward included)
	if float(payload.get("against_wall_mult", 0.0)) > 0.0 and _against_something(target as Node3D):
		bonus *= float(payload["against_wall_mult"])
		on_crush(target, 0.0, null)
		if not is_instance_valid(target) or bool(target.call("is_dead")):
			return ctx
	if float(payload.get("warded_mult", 0.0)) > 0.0 and player.combat_part.ward() > 0.0:
		bonus *= float(payload["warded_mult"])        # Rebuke: harder while you are warded (it spends no ward)
	var dopts: Dictionary = {"heat_scale": float(payload["heat_scale"])} if payload.has("heat_scale") else {}
	if payload.has("damage"):
		ctx = player.combat_part.deal_damage(target, (float(payload["damage"]) + flat) * stage_mult * bonus, tags, dopts)
	elif payload.has("damage_mult"):
		ctx = player.combat_part.deal_damage(target, (player.combat_part.strike_damage() * float(payload["damage_mult"]) + flat) * stage_mult * bonus, tags, dopts)
	elif flat > 0.0:
		ctx = player.combat_part.deal_damage(target, flat * stage_mult * bonus, tags, dopts)
	if ctx != null and ctx.applied > 0.0:
		var dfrac: float = float(payload.get("drain_frac", 0.0)) + _rule_drain_frac(target, tags)
		var dmax: float = _rule_drain_max(tags)
		if dmax > 0.0:
			dfrac = minf(dfrac, dmax)
		if dfrac > 0.0:
			_drain(ctx, dfrac, float(payload.get("drain_cap", INF)), tags)
	if ctx != null and ctx.killed and payload.get("on_kill") is Dictionary:
		_kill_reward(payload["on_kill"], target, ctx)
	if not is_instance_valid(target) or bool(target.call("is_dead")) or not target.has_method("add_status"):
		return ctx
	var foe: Enemy = target as Enemy         # only an enemy takes statuses (enemy.gd): from here the target is one
	if bool(payload.get("purge", false)) and target.has_method("purge_boons"):
		foe.purge_boons()          # Guardbreaker: every boon on it is stripped (balance.json enemy_boons)
	if payload.has("execute_below") and foe.body is Body:
		var b: Body = foe.body
		var excluded: bool = (payload.get("execute_excludes", []) as Array).has("elite") and target.has_method("is_elite") and bool(foe.is_elite())
		# Last Draught (execute_needs): the execute only if it carried that status when the blow landed (before the
		# strike drank it: execute_had)
		if str(payload.get("execute_needs", "")) != "" and not bool(payload.get("execute_had", false)) and not bool(foe.has_status(str(payload["execute_needs"]))):
			excluded = true
		if not excluded and b.total() < b.total_max() * float(payload["execute_below"]):
			FloatText.spawn(player.get_parent(), (target as Node3D).global_position + Vector3.UP * 0.7, "ENDED", Color(0.9, 0.86, 0.72))
			player.combat_part.deal_damage(target, b.total() * 10.0 + 1.0, tags + ["execute"])
			if not is_instance_valid(target) or bool(foe.is_dead()):
				return ctx
	var stun_marks: int = int(foe.status_stacks("live")) if payload.has("stun_per_mark") else 0
	var opts: Dictionary = _status_opts(target, payload, tags)
	if not bool(payload.get("needs_facing", false)) or bool(foe.is_in_front(player.global_position)):
		var time_of: Dictionary = payload.get("status_time_of", {})
		if payload.has("status"):
			_give_status(target, str(payload["status"]), int(payload.get("stacks", 1)), _status_time(opts, time_of, str(payload["status"]), {}), memo, held_before)
		# further statuses, as a list [{id, stacks, lasts?}] (rune words add them here)
		for extra: Variant in payload.get("statuses", []):
			var e: Dictionary = extra as Dictionary
			_give_status(target, str(e.get("id", "")), int(e.get("stacks", 1)), _status_time(opts, time_of, str(e.get("id", "")), e), memo, held_before)
		if bool(payload.get("blind_if_dark", false)) and Light.is_dark(player.get_tree(), (target as Node3D).global_position):
			_give_status(target, "blinded", 1, opts, memo, held_before)
		_bonus_stacks(target, payload, tags)
	if not is_instance_valid(target) or bool(foe.is_dead()):
		return ctx
	if payload.has("stun_per_mark") and not held_before:
		var secs: float = float(payload["stun_per_mark"]) * float(stun_marks) if stun_marks > 0 else float(payload.get("stun_min", 0.2))
		if target.has_method("is_elite") and bool(foe.is_elite()):
			secs *= float(payload.get("elite_stun_mult", 0.5))
		foe.stun(secs)
	var poise_hit: float = 0.0
	if target.has_method("take_poise") and (payload.has("damage") or payload.has("damage_mult") or payload.has("poise") or flat > 0.0):
		poise_hit = float(payload.get("poise", GameData.num("combat", "skill_poise")))
		for st3: String in (payload.get("poise_vs", {}) as Dictionary):
			if bool(foe.has_status(st3)):
				poise_hit = maxf(poise_hit, float((payload["poise_vs"] as Dictionary)[st3]))
		foe.take_poise(poise_hit)
	_try_shatter(target, poise_hit, float(payload.get("shatter_radius", -1.0)))
	if not is_instance_valid(target) or bool(foe.is_dead()):
		return ctx
	if not held_before:
		if bool(payload.get("hard_interrupt", false)):
			foe.interrupt()
			FloatText.spawn(player.get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "SNUFFED", Color(1, 1, 1))
		elif bool(payload.get("interrupts_moving", false)):
			if target.has_method("is_lunging") and bool(foe.is_lunging()):
				foe.interrupt()
				FloatText.spawn(player.get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "STALLED", Color(1, 1, 1))
		elif bool(payload.get("interrupts", false)):
			if bool(foe.interrupt_attack()):
				FloatText.spawn(player.get_parent(), (target as Node3D).global_position + Vector3.UP * 0.5, "INTERRUPTED", Color(1, 1, 1))
		if memo != null:
			if bool(payload.get("interrupts", false)) or bool(payload.get("hard_interrupt", false)) or payload.has("stun_per_mark"):
				(memo as Dictionary)[key] = true
	if float(payload.get("turn_s", 0.0)) > 0.0 and target.has_method("turn_away_from"):
		foe.turn_away_from(player.global_position, float(payload["turn_s"]))
	if bool(payload.get("quells_censer", false)):
		foe.quelled = true
	# a shove pushes away; a pull is a shove toward you. Both on one hit: the difference wins.
	var push: float = float(payload.get("shove", 0.0)) - float(payload.get("pull", 0.0))
	if push > 0.0:
		var away: Vector3 = dir
		if away.length() < 0.001:
			away = (target as Node3D).global_position - player.global_position
		away.y = 0.0
		if away.length() < 0.001:
			away = player._facing
		foe.shover = player
		foe.shove(away, push)
	elif push < 0.0 and target.has_method("pull_toward"):
		foe.pull_toward(player.global_position, -push)
	if int(payload.get("marks", 0)) > 0:
		_add_marks(target, int(payload["marks"]), true)
	# jumps (2026-10-22): the hit arcs on to that many more enemies, for less
	if int(payload.get("jumps", 0)) > 0 and is_instance_valid(target):
		var arc: Dictionary = payload.duplicate()
		arc.erase("jumps")
		var cut: float = GameData.num("skills", "jump_damage_mult")
		for k: String in ["damage", "damage_mult"]:
			if arc.has(k):
				arc[k] = float(arc[k]) * cut
		_arc_on(target as Node3D, arc, tags + ["arc"], stage_mult, int(payload["jumps"]), float(payload.get("jump_radius", GameData.num("skills", "jump_radius"))))
	return ctx


## Ice's rule (affinity key bonus_stacks_vs {status, vs {st: extra}, ends_vs}): a hit of the affinity that lays its
## status on a target carrying st (or counting as it) adds extra more, and the st ends (the water is now ice).
func _bonus_stacks(target: Node, payload: Dictionary, tags: Array) -> void:
	for aff: String in player.affinities:
		if not tags.has(aff):
			continue
		var rule: Dictionary = GameData.affinity(aff).get("bonus_stacks_vs", {})
		if rule.is_empty():
			continue
		var sid: String = str(rule.get("status", ""))
		var lays: bool = str(payload.get("status", "")) == sid or (payload.get("statuses", []) as Array).any(func(e: Variant) -> bool: return str((e as Dictionary).get("id", "")) == sid)
		if not lays:
			continue
		for vs: String in (rule.get("vs", {}) as Dictionary):
			if bool(target.call("has_status", vs)):
				target.call("add_status", sid, int((rule["vs"] as Dictionary)[vs]), player)
				if bool(rule.get("ends_vs", true)):
					target.call("clear_status", vs)
					for other: String in (target.get("statuses") as Dictionary).keys():
						if (GameData.status(other).get("counts_as", []) as Array).has(vs):
							target.call("clear_status", other)


## True if `t` is already within 0.5 m of a wall, stone or another body (Cataract's against_wall_mult).
func _against_something(t: Node3D) -> bool:
	if t == null or not player.is_inside_tree():
		return false
	var r: float = float(t.get("radius")) + 0.5
	for e: Enemy in player.casting_part._enemies_near(t.global_position, r + 0.6):
		if e != t and e.global_position.distance_to(t.global_position) <= r + float(e.radius):
			return true
	for i: int in 8:
		var d := Vector3(cos(TAU * float(i) / 8.0), 0.0, sin(TAU * float(i) / 8.0))
		if not player.casting_part._ray(t.global_position + Vector3.UP * 0.6, t.global_position + Vector3.UP * 0.6 + d * r).is_empty():
			return true
	return false



## Lift every condition a cleanse list names (balance.json "cleanse": binds, afflictions) from you; returns how
## many were on you. The player carries no enemy statuses: the conditions are your own (staggered, winded, shoved).
func cleanse(list: String) -> int:
	var n := 0
	for c: Variant in (GameData.balance.get("cleanse", {}) as Dictionary).get(list, []):
		match str(c):
			"staggered":
				if player._stagger_t > 0.0:
					player._stagger_t = 0.0
					n += 1
			"winded":
				if player._winded_t > 0.0:
					player._winded_t = 0.0
					n += 1
			"shoved":
				if player._shoved_left > 0.0:
					player._shoved_left = 0.0
					n += 1
	return n


## True if skill `ab` is a cleanse whose list (balance.json cleanse) lifts `condition` (Absolution lifts a stagger, so
## it can be cast while you are staggered).
func _lifts(ab: Dictionary, condition: String) -> bool:
	var c: Variant = ab.get("cleanse")
	if not (c is String):
		return false
	return ((GameData.balance.get("cleanse", {}) as Dictionary).get(str(c), []) as Array).has(condition)


## A zone of yours with an ally_payload (Hallowed Ground) ticks on you and your summons inside it: ward_per_s for
## the tick, never more than ward_max from that zone.
func zone_ally_tick(zone: GroundZone) -> void:
	var ap: Dictionary = zone.ally_payload
	var amount: float = float(ap.get("ward_per_s", 0.0)) * zone.tick_s
	if amount <= 0.0:
		return
	var cap: float = float(ap.get("ward_max", GameData.num("ward", "cap")))
	if zone.has_point(player.global_position):
		player.combat_part.add_ward(amount, -1.0, {"from": "zone_%d" % zone.get_instance_id(), "source_cap": cap})
	for s: Node3D in player.world_part.summons_near(zone.from, zone.radius + 1.0):
		if zone.has_point(s.global_position):
			s.call("add_ward", minf(amount, maxf(0.0, cap - float(s.get("ward")))), GameData.num("ward", "default_lasts"))


## What blows on `who` (you or a summon of yours) are multiplied by while it stands in a zone of yours with an
## ally_payload damage_taken_mult (Hallowed Ground): the strongest one.
func ally_zone_mult(who: Node3D) -> float:
	var m := 1.0
	if not player.is_inside_tree():
		return m
	for node: Node in player.get_tree().get_nodes_in_group("ground_zones"):
		var z := node as GroundZone
		if z != null and z.caster == player and z.ally_payload.has("damage_taken_mult") and z.has_point(who.global_position):
			m = minf(m, float(z.ally_payload["damage_taken_mult"]))
	return m


## An affinity's own drain on every hit tagged with it (Unholy's rule, affinity drain_frac): times the largest of its
## drain_mult_vs that applies - a status the target carries (Dying), or "in_dark" for a target standing in Dark.
func _rule_drain_frac(target: Node, tags: Array) -> float:
	var total := 0.0
	for aff: String in player.affinities:
		var a: Dictionary = GameData.affinity(aff)
		if not tags.has(aff) or float(a.get("drain_frac", 0.0)) <= 0.0:
			continue
		var m := 1.0
		var vs: Dictionary = a.get("drain_mult_vs", {})
		for key: String in vs:
			var applies := false
			if key == "in_dark":
				applies = player.is_inside_tree() and target is Node3D and Light.is_dark(player.get_tree(), (target as Node3D).global_position)
			elif target.has_method("has_status"):
				applies = bool(target.call("has_status", key))
			if applies:
				m = maxf(m, float(vs[key]))
		total += float(a["drain_frac"]) * m
	return total


## The most of a hit a drain may take back (affinity drain_max_frac; 0 = no cap).
func _rule_drain_max(tags: Array) -> float:
	var cap := 0.0
	for aff: String in player.affinities:
		if tags.has(aff):
			cap = maxf(cap, float(GameData.affinity(aff).get("drain_max_frac", 0.0)))
	return cap


func _drain(ctx: HitContext, frac: float, cap: float, tags: Array) -> void:
	if not ctx.is_living:
		return
	var amount: float = minf(ctx.applied * frac, maxf(0.0, cap - player._drain_cast))
	if amount <= 0.0:
		return
	player._drain_cast += amount
	var bar_only := false
	for aff: String in player.affinities:
		if tags.has(aff) and str(GameData.affinity(aff).get("drain_heals", "")) == "bar":
			bar_only = true
	if bar_only:
		player.combat_part.drain_heal(amount, ctx.target, true)
	else:
		player.combat_part.life_heal(amount)


## What a skill pays you when its hit kills (on_kill: Hungry Dark, Last Draught, Reaping Blow): essence back (never
## more than the cost), swallowed light, a Vanish, held blood (per stack the hit spent too), the life it had (stolen).
func _kill_reward(k: Dictionary, target: Node, ctx: HitContext) -> void:
	if float(k.get("essence", 0.0)) > 0.0:
		player.essence = minf(player.essence_max, player.essence + float(k["essence"]))
	if int(k.get("swallow", 0)) > 0:
		store_add("swallowed", int(k["swallow"]), 5, 12.0)
	if float(k.get("self_unseen_s", 0.0)) > 0.0:
		player.casting_part._take_state("vanished", float(k["self_unseen_s"]))
	if int(k.get("blood", 0)) > 0:
		gain_blood(int(k["blood"]))
	if bool(k.get("steals", false)):
		for aff: String in player.affinities:
			var st: Dictionary = GameData.affinity(aff).get("stolen", {})
			if not st.is_empty():
				store_add("stolen", int(round(ctx.applied)), int(st.get("max", 100)), float(st.get("fade_s", 12.0)))


## One status's own timing on a hit (2026-10-23, rune strength): the payload's `status_time_of`
## {id: multiple} lengthens that status alone; a `statuses` entry with its own "lasts" lasts exactly
## that (a silence's seconds), whatever the payload's other statuses do. Data only - no ids here.
static func _status_time(opts: Dictionary, time_of: Dictionary, id: String, entry: Dictionary) -> Dictionary:
	var m: float = float(time_of.get(id, 1.0))
	if not entry.has("lasts") and absf(m - 1.0) < 0.000001:
		return opts
	var o: Dictionary = opts.duplicate()
	if entry.has("lasts"):
		o["lasts"] = float(entry["lasts"])
		o.erase("time_mult")
	if absf(m - 1.0) >= 0.000001:
		o["time_mult"] = float(o.get("time_mult", 1.0)) * m
	return o


## A status from a hit: once per target per cast through a ticking payload if it is a hold.
func _give_status(target: Node, id: String, stacks: int, opts: Dictionary, memo: Variant, held_before: bool) -> void:
	if id == "":
		return
	var def: Dictionary = GameData.status(id)
	if def.has("alias_of"):
		def = GameData.status(str(def["alias_of"]))
	var hold: bool = bool(def.get("control", false))
	if hold and held_before:
		return
	# a buff of yours may set how long one of your statuses runs (Bitter Tonic: doses come due sooner)
	for bid: String in player.buffs:
		var sl: Dictionary = (player.buffs[bid] as Dictionary).get("status_lasts", {})
		if sl.has(id):
			opts = opts.duplicate()
			opts["lasts"] = float(sl[id])
	target.call("add_status", id, stacks, player, opts)
	if hold and memo != null:
		(memo as Dictionary)[target.get_instance_id()] = true


## How long and with what a payload's statuses land: its own status_s (more per metal class worn,
## more per point of heat, longer in the Dark, shorter unless the target already has something),
## its time multiplier (the rune Duration), the affinity's longer hold on some targets (Dream on the
## Dazed and the Asleep), and the data the status reads from the skill.
func _status_opts(target: Node, payload: Dictionary, tags: Array) -> Dictionary:
	var opts: Dictionary = {}
	if payload.has("status_s"):
		var lasts: float = float(payload["status_s"])
		if payload.has("status_s_per_class") and target.has_method("metal_class"):
			lasts += float(payload["status_s_per_class"]) * float(int(target.call("metal_class")))
		if payload.has("status_s_per_heat"):
			var heat := 0.0
			for aff: String in player.affinities:
				if tags.has(aff):
					heat = maxf(heat, player.casting_part.reflux_of(aff))
			lasts = minf(float(payload.get("status_s_max", 99.0)), lasts + float(payload["status_s_per_heat"]) * heat)
		opts["lasts"] = lasts
	if payload.has("dark_status_s") and Light.is_dark(player.get_tree(), (target as Node3D).global_position):
		opts["lasts"] = float(payload["dark_status_s"])
	if payload.has("status_s_if_not"):
		var cond: Dictionary = payload["status_s_if_not"]
		if not bool(target.call("has_status", str(cond.get("status", "")))):
			opts["lasts"] = float(opts.get("lasts", GameData.status(str(payload.get("status", ""))).get("lasts", 1.0))) * float(cond.get("frac", 1.0))
	var mult: float = float(payload.get("status_time_mult", 1.0)) * player.casting_part.buff_num("status_time_mult")      # Lucid: yours last longer
	for aff2: String in player.affinities:
		if not tags.has(aff2):
			continue
		# twilight (Dream's rule): its statuses last status_time_dim longer on a target standing in Dim light
		if GameData.affinity(aff2).has("status_time_dim") and player.is_inside_tree() and Light.level_at(player.get_tree(), (target as Node3D).global_position) == "dim":
			mult *= float(GameData.affinity(aff2)["status_time_dim"])
		var vs: Dictionary = GameData.affinity(aff2).get("status_time_vs", {})
		for st: String in vs:
			if bool(target.call("has_status", st)):
				mult *= float(vs[st])
	if mult != 1.0:
		opts["time_mult"] = mult
	var data: Dictionary = (payload.get("status_data", {}) as Dictionary).duplicate()
	if payload.has("release_shove"):
		data["release_shove"] = payload["release_shove"]
	if not data.is_empty():
		opts["data"] = data
	return opts


## Spend what is already on the target (consume: {status, per_stack_damage, per_stack_poise,
## stun_per_stack, stun_max, counts {status: stacks it counts as}, vent_per_stack}).
func _consume_on(target: Node, c: Dictionary, tags: Array, stage_mult: float) -> int:
	var id: String = str(c.get("status", ""))
	var n: int = int(target.call("status_stacks", id)) if bool(target.call("has_status", id)) else 0
	var counts: Dictionary = c.get("counts", {})
	for alt: String in counts:
		if bool(target.call("has_status", alt)):
			n = maxi(n, int(counts[alt]))
			target.call("clear_status", alt)
	if n <= 0:
		return 0
	target.call("clear_status", id)
	if float(c.get("per_stack_damage", 0.0)) > 0.0:
		player.combat_part.deal_damage(target, float(c["per_stack_damage"]) * float(n) * stage_mult, tags + ["burst"])
	if is_instance_valid(target) and not bool(target.call("is_dead")):
		if float(c.get("per_stack_poise", 0.0)) > 0.0:
			target.call("take_poise", float(c["per_stack_poise"]) * float(n))
		if float(c.get("stun_per_stack", 0.0)) > 0.0:
			target.call("stun", minf(float(c.get("stun_max", 99.0)), float(c["stun_per_stack"]) * float(n)))
	if float(c.get("vent_per_stack", 0.0)) > 0.0:
		for aff: String in player.affinities:
			if tags.has(aff):
				player.reflux_by[aff] = maxf(0.0, player.casting_part.reflux_of(aff) - float(c["vent_per_stack"]) * float(n))
	return n


## The hit arcs on from `from`: to the nearest enemy not yet struck within `reach`, `n` times.
func _arc_on(from: Node3D, payload: Dictionary, tags: Array, stage_mult: float, n: int, reach: float) -> void:
	var struck: Array = [from]
	var cur: Node3D = from
	for i: int in n:
		if not is_instance_valid(cur):
			return
		var at: Vector3 = cur.global_position
		var next: Node3D = null
		for e: Enemy in player.casting_part._enemies_near(at, reach):
			if not struck.has(e) and (next == null or e.global_position.distance_to(at) < next.global_position.distance_to(at)):
				next = e
		if next == null:
			return
		struck.append(next)
		player.casting_part._line_visual(at + Vector3.UP, next.global_position + Vector3.UP, Color(0.9, 0.9, 1.0))
		apply_hit(next, payload, tags, stage_mult)
		cur = next


## A hard hit on something Brittle (or Frozen, which counts as Brittle) Shatters it: the shatter's
## damage, not halved, and shards on everyone near it (statuses.json brittle.shatter).
func _try_shatter(target: Node, poise_hit: float, radius_override: float = -1.0) -> void:
	if not is_instance_valid(target) or not target.has_method("has_status") or bool(target.call("is_dead")):
		return
	if not bool(target.call("has_status", "brittle")):
		return
	var cfg: Dictionary = GameData.status("brittle").get("shatter", {})
	if poise_hit < float(cfg.get("hard_poise", 40.0)):
		return
	var at: Vector3 = (target as Node3D).global_position
	for id: Variant in cfg.get("ends", ["frozen", "brittle"]):
		target.call("clear_status", str(id))
	FloatText.spawn(player.get_parent(), at + Vector3.UP * 0.8, "SHATTER", Color(0.85, 0.97, 1.0))
	player.combat_part.deal_damage(target, float(cfg.get("damage", 100.0)), ["ice", "shatter", "ability"])
	var r: float = radius_override if radius_override > 0.0 else float(cfg.get("radius", 2.5))
	for e: Enemy in player.casting_part._enemies_near(at, r):
		if e != target:
			apply_hit(e, cfg.get("shard", {}), ["ice", "shatter", "ability", "shard"])


## A payload on everyone within its burst_radius (or radius) of `at`.
func _burst_at(at: Vector3, payload: Dictionary, tags: Array, stage_mult: float = 1.0, skip: Node = null) -> void:
	if payload.is_empty():
		return
	var p: Dictionary = payload.duplicate()
	var r: float = float(p.get("burst_radius", p.get("radius", 2.0)))
	p.erase("burst_radius")
	p.erase("radius")
	for e: Enemy in player.casting_part._enemies_near(at, r):
		if e != skip:
			apply_hit(e, p, tags, stage_mult)


# --- affinity rules as data (2026-10-22) ---------------------------------------------------------

## True if the hit can touch this target at all: Life does nothing to the unliving; Dream needs
## a mind that sees you - in its front arc, a clear line, not blinded - or one that is asleep.
func _affinity_reaches(target: Node, tags: Array) -> bool:
	for aff: String in player.affinities:
		if not tags.has(aff):
			continue
		var a: Dictionary = GameData.affinity(aff)
		if bool(a.get("living_only", false)) and not bool(target.get("is_living")):
			return false
		if bool(a.get("needs_seen", false)) and target.has_method("sees_point"):
			if not bool(target.call("has_status", "asleep")) and not bool(target.call("sees_point", player.global_position)):
				return false
	return true


## Attacker-side affinity rules on one hit, by the affinities it is tagged with: Dark by the light
## where the target stands; Metal by the metal it wears; Life on the hale, Death on the dying; Dream
## on the dazed and asleep; Disease by flesh; those that go through guards; then the buffs that change
## a hit (an unaware target, a first hit from behind, gaps in Lit armour, corded muscle).
func _affinity_rules(ctx: HitContext, target: Node) -> void:
	var at: Vector3 = (target as Node3D).global_position
	if player.held_blood > 0 and not ctx.has_tag("dot"):
		# Bloodrush (Blood's rule): every hit you deal, of any affinity, is x (1 + damage_per_held_blood x held blood)
		var rush := 0.0
		for aff: String in player.affinities:
			rush = maxf(rush, float(GameData.affinity(aff).get("damage_per_held_blood", 0.0)))
		ctx.mult *= 1.0 + rush * float(player.held_blood)
	for aff: String in player.affinities:
		if not ctx.has_tag(aff):
			continue
		var a: Dictionary = GameData.affinity(aff)
		if a.has("light_mult") and player.is_inside_tree():
			ctx.mult *= float((a["light_mult"] as Dictionary).get(Light.level_at(player.get_tree(), at), 1.0))
		if float(a.get("per_metal_class", 0.0)) > 0.0 and target.has_method("metal_class"):
			ctx.mult *= 1.0 + float(a["per_metal_class"]) * float(int(target.call("metal_class")))
		if bool(a.get("through", false)) and not ctx.has_tag("through"):
			ctx.tags.append("through")
		if bool(a.get("living_only", false)) and not bool(target.get("is_living")):
			ctx.cancelled = true
			return
		if a.has("hale_mult") and target.has_method("has_status") and bool(target.call("has_status", "hale")):
			ctx.mult *= float(a["hale_mult"])
		if a.has("dying_mult") and target.has_method("has_status") and bool(target.call("has_status", "dying")):
			ctx.mult *= float(a["dying_mult"])
		if a.has("sear_vs_lit") and target.has_method("has_status") and bool(target.call("has_status", "lit")):
			# Sear: a light hit on a target already Lit does more (a lamp of yours lighting it adds its sear_bonus)
			ctx.mult *= 1.0 + float(a["sear_vs_lit"]) + _lamp_sear(at)
			ctx.set_meta("seared", true)
		if a.has("focus_max") and target == player._focus_target and player.combat_part._edge_counts(ctx):
			ctx.mult *= 1.0 + float(a.get("focus_mult", 0.08)) * float(player.focus)
		if bool(a.get("times_flesh", false)) and target.has_method("flesh"):
			ctx.mult *= float(target.call("flesh"))
		if target.has_method("has_status"):
			for st: String in (a.get("bonus_vs_status", {}) as Dictionary):
				if bool(target.call("has_status", st)):
					ctx.mult *= 1.0 + float(a["bonus_vs_status"][st])
	if ctx.has_tag("dot"):
		return
	# a zone of yours that sharpens your hits on what stands in it carrying a status (Dusk Well's lit_bonus), for
	# hits of the zone's own affinity
	if player.is_inside_tree() and target.has_method("has_status"):
		for z: Node in player.get_tree().get_nodes_in_group("ground_zones"):
			var bv: Variant = z.get("bonus_vs")
			if z.get("caster") != player or not (bv is Dictionary) or (bv as Dictionary).is_empty():
				continue
			var ztags: Array = z.get("tags")
			if ztags.size() < 2 or not ctx.has_tag(str(ztags[1])) or not bool(z.call("has_point", at)):
				continue
			for st: String in (bv as Dictionary):
				if bool(target.call("has_status", st)):
					ctx.mult *= 1.0 + float((bv as Dictionary)[st])
	for bid: String in player.buffs:
		var b: Dictionary = player.buffs[bid]
		if b.has("unaware_mult") and target.has_method("is_in_front") and not bool(target.call("is_in_front", player.global_position)):
			ctx.mult *= float(b["unaware_mult"])
		if bool(b.get("first_hit_rear", false)) and not ctx.has_tag("rear"):
			ctx.tags.append("rear")
		if b.has("lit_front_armour_mult") and target.has_method("has_status") and bool(target.call("has_status", "lit")) and not ctx.has_tag("through"):
			ctx.tags.append("through")
	if player._rear_window_t > 0.0 and not ctx.has_tag("rear"):
		ctx.tags.append("rear")
	if ctx.has_tag("melee") and not ctx.has_tag("ability"):
		ctx.mult *= player.casting_part.buff_num("strike_mult")
	# a buff's damage dealt (Red Frenzy, Benediction, Overgrowth), and In the Green's under Greening
	ctx.mult *= player.casting_part.buff_num("damage_mult")
	if in_the_green():
		ctx.mult *= player.casting_part.buff_num("green_damage_mult")


## After a hit has landed (not a burn): you are seen for a moment; a buff that ends on your first
## hit ends; Festering Hands adds to an infected wound.
func _after_landing(ctx: HitContext, target: Node) -> void:
	var cfg: Dictionary = GameData.affinity("dark")
	var muffled := false
	for bid: String in player.buffs.keys():
		var b: Dictionary = player.buffs[bid]
		if b.has("unaware_mult"):
			muffled = true
		if bool(b.get("ends_on_hit", false)):
			player.buffs.erase(bid)
		elif b.has("on_infected_hit") and is_instance_valid(target) and target.has_method("has_status") and bool(target.call("has_status", "infected")) and not ctx.has_tag("festering"):
			for extra: Variant in (b["on_infected_hit"] as Dictionary).get("statuses", []):
				target.call("add_status", str((extra as Dictionary)["id"]), int((extra as Dictionary).get("stacks", 1)), player)
			if float(b.get("spread_radius", 0.0)) > 0.0:
				# Festering Hands: and to the nearest other enemy within spread_radius of it
				var other: Node3D = null
				for e: Enemy in player.casting_part._enemies_near((target as Node3D).global_position, float(b["spread_radius"])):
					if e != target and (other == null or e.global_position.distance_to((target as Node3D).global_position) < other.global_position.distance_to((target as Node3D).global_position)):
						other = e
				if other != null:
					other.call("add_status", "infected", int(b.get("spread_stacks", 1)), player)
	player._rear_window_t = 0.0
	if not muffled:
		player._unseen_reveal_t = float(cfg.get("reveal_s", 1.0))


## True while you are Unseen for an Ambush (Dark's rule): you have not struck or cast a moment ago, and you stand in
## Dark holding Dark, or a buff of yours hides you (Vanished, unseen_beyond). [The Unseen rule's 4 m is for being
## seen; an Ambush reads the state, as Dark's rule text says: "your first hit out of Unseen".]
func _hidden() -> bool:
	if player._unseen_reveal_t > 0.0 or not player.is_inside_tree():
		return false
	for bid: String in player.buffs:
		if bool((player.buffs[bid] as Dictionary).get("unseen_anywhere", false)) or (player.buffs[bid] as Dictionary).has("unseen_beyond"):
			return true
	for aff: String in player.affinities:
		if bool(GameData.affinity(aff).get("unseen_in_dark", false)) and Light.is_dark(player.get_tree(), player.global_position):
			return true
	return false


## Muffle (hush_radius): while it lasts a kill of yours raises no alarm - nobody within the radius is woken or calls.
func hush_radius() -> float:
	var r := 0.0
	for bid: String in player.buffs:
		r = maxf(r, float((player.buffs[bid] as Dictionary).get("hush_radius", 0.0)))
	return r


## True if no enemy at `from` can see you: Bent Light hides you beyond its reach; Dark hides you
## beyond its own while you stand in the Dark - unless you struck or cast a moment ago.
func unseen_from(from: Vector3) -> bool:
	if player._unseen_reveal_t > 0.0 or not player.is_inside_tree():
		return false
	var d: float = Vector2(from.x - player.global_position.x, from.z - player.global_position.z).length()
	for bid: String in player.buffs:
		if (player.buffs[bid] as Dictionary).has("unseen_beyond") and d > float(player.buffs[bid]["unseen_beyond"]):
			return true
		if bool((player.buffs[bid] as Dictionary).get("unseen_anywhere", false)) and d > float(GameData.affinity("dark").get("unseen_beyond", 4.0)):
			return true                           # Vanished: unseen anywhere, with the Unseen rule's reach
	for aff: String in player.affinities:
		var a: Dictionary = GameData.affinity(aff)
		if bool(a.get("unseen_in_dark", false)) and d > float(a.get("unseen_beyond", 4.0)) and Light.is_dark(player.get_tree(), player.global_position):
			return true
	return false


## How long a body lies for you: longer if you hold Death.
func corpse_lie_s() -> float:
	var out: float = GameData.num("combat", "corpse_lie_s")
	for aff: String in player.affinities:
		out = maxf(out, float(GameData.affinity(aff).get("corpse_lie_s", 0.0)))
	return out


## True if you hold an affinity with this rule key set.
func holds_rule(key: String) -> bool:
	for aff: String in player.affinities:
		if bool(GameData.affinity(aff).get(key, false)):
			return true
	return false


## The most held blood you can carry (0 without Blood).
func held_blood_max() -> int:
	return int(GameData.affinity("blood").get("held_blood_max", 10)) if holds_rule("held_blood") else 0


## Held blood comes in (drinking, a bleeding kill). Never health.
func gain_blood(n: int) -> void:
	if held_blood_max() <= 0 or n <= 0:
		return
	player.held_blood = mini(held_blood_max(), player.held_blood + n)
	_blood_thin_t = 0.0


## Spend up to `n` held blood (n < 0: all of it). Returns how much was spent.
func spend_blood(n: int) -> int:
	var took: int = player.held_blood if n < 0 else mini(player.held_blood, n)
	player.held_blood -= took
	return took


## How many measures the blood pools within `r` of you hold (0 when r is 0).
func _pools_within(r: float) -> int:
	if r <= 0.0 or not player.is_inside_tree():
		return 0
	var n := 0
	for node: Node in player.get_tree().get_nodes_in_group("blood_pools"):
		if (node as Node3D).global_position.distance_to(player.global_position) <= r:
			n += int(node.get("measures"))
	return n


## Spend `n` blood, the pools within `r` first (drunk one measure each, as Drink), then held blood (Tourniquet, Long
## Breath: pool_radius). Returns how much was spent.
func _spend_blood_first_pools(n: int, r: float) -> int:
	var spent := 0
	if r > 0.0 and player.is_inside_tree():
		for node: Node in player.get_tree().get_nodes_in_group("blood_pools").duplicate():
			while spent < n and (node as Node3D).global_position.distance_to(player.global_position) <= r and int(node.get("measures")) > 0:
				spent += int(node.call("drink"))
	return spent + spend_blood(maxi(0, n - spent))


## Blood spills on the floor at `at` (a bleeding body, a beat of the heart, Outpour).
func spill_blood(at: Vector3, measures: int = 1, big: bool = false) -> void:
	if player.is_inside_tree():
		BloodPool.spill(player.get_parent(), at, measures, big)


## A sick cloud at `at` (a body that died Infected): a GroundZone of kind "cloud".
func lay_cloud(at: Vector3, cfg: Dictionary, tags: Array) -> Node3D:
	if not player.is_inside_tree():
		return null
	var zone := GroundZone.new()
	zone.shape = "circle"
	zone.kind = "cloud"
	zone.radius = float(cfg.get("radius", 2.0))
	zone.life = float(cfg.get("life", 4.0))
	zone.tick_s = float(cfg.get("tick_s", 1.0))
	zone.payload = cfg.get("payload", {"status": "infected"})
	zone.tags = tags + ["zone"]
	zone.caster = player
	zone.bright = false
	# a left zone may be Dark ground (Forsaken Ground) rather than a cloud; it takes its skill's colour
	zone.dark = bool(cfg.get("dark", false))
	if zone.dark:
		zone.kind = "dark_ground"
	zone.color = GameData.affinity_color(_tag_affinity(tags, "disease"))
	zone.from = Vector3(at.x, player.global_position.y, at.z)
	zone.to = zone.from
	var drift: float = float(cfg.get("drift_speed", 0.0))
	if drift > 0.0:
		var way: Vector3 = zone.from - player.global_position
		if str(cfg.get("drift_dir", "away")) == "aim":
			way = player._facing
		way.y = 0.0
		zone.drift_vel = (way.normalized() if way.length() > 0.05 else player._facing) * drift
	player.get_parent().add_child(zone)
	return zone


## The first affinity id among a hit's tags (whose skill it is), else `fallback`.
func _tag_affinity(tags: Array, fallback: String) -> String:
	for tg: Variant in tags:
		if GameData.affinity_ids().has(str(tg)):
			return str(tg)
	return fallback


## A patch of your growth at `at` (Nature): {kind, radius}. You keep growth.max of them.
func plant_growth(at: Vector3, cfg: Dictionary) -> Node3D:
	if not player.is_inside_tree():
		return null
	var gcfg: Dictionary = GameData.affinity("nature").get("growth", {})
	var mine: Array = player.get_tree().get_nodes_in_group("growth").filter(func(g: Node) -> bool: return g.get("caster") == player)
	if mine.size() >= int(gcfg.get("max", 12)):
		return null
	var patch := GrowthPatch.new()
	patch.caster = player
	patch.kind = str(cfg.get("kind", "bramble"))
	patch.radius = float(cfg.get("radius", gcfg.get("radius", 1.0)))
	patch.color = GameData.affinity_color("nature")
	player.get_parent().add_child(patch)
	patch.global_position = Vector3(at.x, player.global_position.y, at.z)
	return patch


## A water shove or pull you started has ended on `e`: it is Adrift for a moment (Siltfall).
func on_shove_ended(e: Node) -> void:
	if holds_rule("marks_adrift") and is_instance_valid(e) and not bool(e.call("is_dead")):
		e.call("add_status", "adrift", 1, player)
	# a thrown body has landed (Overboard): what it lands among takes on_land
	var key: int = e.get_instance_id()
	if player._landings.has(key):
		var l: Dictionary = player._landings[key]
		player._landings.erase(key)
		if is_instance_valid(e):
			var p: Dictionary = (l["payload"] as Dictionary).duplicate()
			if str(p.get("shove_dir", "")) == "from_point":
				p.erase("shove_dir")
				var at: Vector3 = (e as Node3D).global_position
				for o: Enemy in player.casting_part._enemies_near(at, float(p.get("burst_radius", 1.5))):
					if o != e:
						var q: Dictionary = p.duplicate()
						q.erase("burst_radius")
						apply_hit(o, q, l["tags"], float(l["stage_mult"]), o.global_position - at)
			else:
				_burst_at((e as Node3D).global_position, p, l["tags"], float(l["stage_mult"]), e)


## A zone of yours you stand in carries this flag (freeze_pips, shed_standing).
func _zone_flag(key: String) -> bool:
	if not player.is_inside_tree():
		return false
	for zone: Node in player.get_tree().get_nodes_in_group("ground_zones"):
		if zone.get("caster") == player and bool(zone.get(key)) and bool(zone.call("has_point", player.global_position)):
			return true
	return false


## True while healing is refused (Embalm).
func _heal_blocked() -> bool:
	for bid: String in player.buffs:
		if bool((player.buffs[bid] as Dictionary).get("blocks_healing", false)):
			return true
	return false


## Inured Blood: less damage for each Infected enemy near you.
func _inured_mult() -> float:
	var out := 1.0
	for bid: String in player.buffs:
		var b: Dictionary = player.buffs[bid]
		if float(b.get("dr_per_infected", 0.0)) <= 0.0:
			continue
		var n := 0
		for e: Enemy in player.casting_part._enemies_near(player.global_position, float(b.get("radius", 8.0))):
			if bool(e.has_status("infected")):
				n += 1
		out *= 1.0 - minf(float(b.get("dr_max", 0.3)), float(b["dr_per_infected"]) * float(n))
	return out


## Take `amount` off your hottest affinity's reflux (Long Breath).
func _vent_hottest(amount: float) -> void:
	var hottest := ""
	for aff: String in player.reflux_by:
		if hottest == "" or float(player.reflux_by[aff]) > float(player.reflux_by[hottest]):
			hottest = aff
	if hottest != "":
		player.reflux_by[hottest] = maxf(0.0, float(player.reflux_by[hottest]) - amount)


## Stores run down: swallowed light after a while; held blood thins out of a fight.
func _tick_stores(delta: float) -> void:
	for id: String in player.stores.keys():
		var s: Dictionary = player.stores[id]
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			player.stores.erase(id)
	if player.held_blood > 0 and not player.in_combat:
		_blood_thin_t += delta
		if _blood_thin_t >= float(GameData.affinity("blood").get("held_blood_thin_s", 5.0)):
			_blood_thin_t = 0.0
			player.held_blood -= 1


## Add to a store (`swallowed`): up to `cap`, lasting `life` from the last gain.
func store_add(id: String, n: int, cap: int, life: float) -> void:
	var s: Dictionary = player.stores.get(id, {"n": 0, "t": 0.0})
	s["n"] = mini(cap, int(s["n"]) + n)
	s["t"] = life
	player.stores[id] = s


## How much a store holds now (the HUD's stolen life, a test).
func store_count(id: String) -> int:
	return int((player.stores.get(id, {}) as Dictionary).get("n", 0))


## Take everything in a store. Returns how much there was.
func store_take(id: String) -> int:
	var n: int = int((player.stores.get(id, {}) as Dictionary).get("n", 0))
	player.stores.erase(id)
	return n


## A shove ended against something with `metres_left` still to go (water's Crush): the shoved
## body takes base + per-metre, and a body it ran into takes a share. Both lose what they were doing.
func on_crush(enemy: Node, metres_left: float, hit: Node) -> void:
	var cfg: Dictionary = GameData.balance["shove"]
	var dmg: float = float(cfg["crush_base"]) + float(cfg["crush_per_m"]) * metres_left
	_crush_ward()
	if is_instance_valid(enemy) and not bool(enemy.call("is_dead")):
		FloatText.spawn(player.get_parent(), (enemy as Node3D).global_position + Vector3.UP * 0.4, "CRUSH", Color(0.55, 0.8, 1.0))
		player.combat_part.deal_damage(enemy, dmg, ["crush", "water"])
		if is_instance_valid(enemy) and not bool(enemy.call("is_dead")):
			enemy.call("interrupt")
	if is_instance_valid(hit) and hit.is_in_group("enemies") and not bool(hit.call("is_dead")):
		player.combat_part.deal_damage(hit, dmg * float(cfg["crush_other_frac"]), ["crush", "water"])
		if is_instance_valid(hit) and not bool(hit.call("is_dead")):
			hit.call("interrupt")


## Water's rule (v2 crush_ward): each Crush you cause shores you up - per_crush Ward, at most cap from Crushes.
func _crush_ward() -> void:
	for aff: String in player.affinities:
		var cw: Dictionary = GameData.affinity(aff).get("crush_ward", {})
		if not cw.is_empty():
			player.combat_part.add_ward(float(cw.get("per_crush", 15.0)), float(cw.get("lasts", 6.0)), {"from": "crush", "source_cap": float(cw.get("cap", 60.0))})


## Lightning's Live marks. The third is an Overload. A hit on a Soaked target also marks every
## other Soaked enemy nearby (wet things conduct) - but conducted marks do not conduct again.
func _add_marks(target: Node, marks: int, conduct: bool) -> void:
	var live: Dictionary = GameData.status("live")
	var soaked: Dictionary = GameData.status("soaked")
	var others: Array[Node] = []
	if conduct and bool(target.call("has_status", "soaked")) and not (target.has_method("no_conduct") and bool(target.call("no_conduct"))):
		for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
			if node != target and bool(node.has_status("soaked")) and not (node.has_method("no_conduct") and bool(node.no_conduct())) \
					and (node as Node3D).global_position.distance_to((target as Node3D).global_position) <= float(soaked.get("conduct_radius", 4.0)):
				others.append(node)
	if int(target.call("add_status", "live", marks)) >= int(live.get("stacks", 3)):
		_overload(target)
	for node: Node in others:
		if is_instance_valid(node) and not bool(node.call("is_dead")):
			_add_marks(node, int(soaked.get("conduct_marks", 1)), false)


## The third mark: the target takes the big hit and is stunned, every other marked enemy in range
## takes the arc, and your lightning reflux is grounded a little. The others keep their marks.
func _overload(target: Node) -> void:
	var live: Dictionary = GameData.status("live")
	var at: Vector3 = (target as Node3D).global_position
	var arc_to: Array[Node] = []
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		if node != target and int(node.status_stacks("live")) > 0 \
				and (node as Node3D).global_position.distance_to(at) <= float(live.get("arc_radius", 12.0)):
			arc_to.append(node)
	target.call("clear_status", "live")
	FloatText.spawn(player.get_parent(), at + Vector3.UP * 0.6, "OVERLOAD", Color(0.85, 0.78, 1.0))
	player.combat_part.deal_damage(target, float(live.get("overload_damage", 150.0)), ["overload", "lightning"])
	if is_instance_valid(target) and not bool(target.call("is_dead")):
		target.call("stun", float(live.get("stun", 1.0)))
	for node: Node in arc_to:
		if is_instance_valid(node) and not bool(node.call("is_dead")):
			player.casting_part._line_visual(at + Vector3.UP, (node as Node3D).global_position + Vector3.UP, Color(0.85, 0.78, 1.0))
			player.combat_part.deal_damage(node, float(live.get("arc_damage", 60.0)), ["overload", "arc", "lightning"])
	if player.affinities.has("lightning"):
		player.reflux_by["lightning"] = maxf(0.0, player.casting_part.reflux_of("lightning") - float(live.get("grounds", 0.0)))
	for aff: String in player.affinities:
		var q: float = float(GameData.affinity(aff).get("quicken_on_overload", 0.0))
		if q > 0.0:
			player.casting_part._take_state("quickened", q)             # Lightning's rule: an Overload leaves you Quickened (a new one refreshes it)
