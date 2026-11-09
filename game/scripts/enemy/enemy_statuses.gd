class_name EnemyStatuses
extends RefCounted
## The status engine (statuses.json: generic keys, read here and nowhere else). A part of the enemy
## (docs/architecture/enemy-split.md): every status on it, how one is added, refused, merged, ticked,
## what it leaves when it runs out or its body dies, and the numbers the rest of the enemy reads from
## them (`_st_any`, `_st_mult`, front armour, flesh, light). The statuses themselves stay on the node
## (`enemy.statuses`): the player, the HUD and the tests read them by name.

const FloatText := preload("res://scripts/float_text.gd")

var enemy: Enemy
var _burn_t := 0.0                   # alight: time toward the next tick of burning
var _spread_t := 0.0                 # alight: how long someone has stood close enough to catch
var _retch_t := 0.0                  # Sick: until the next retch


func _init(of: Enemy) -> void:
	enemy = of


## A status's definition, following alias_of (rooted is pinned).
func _sdef(id: String) -> Dictionary:
	var def: Dictionary = GameData.status(id)
	if def.has("alias_of"):
		return GameData.status(str(def["alias_of"]))
	return def


## The id a status is kept under (an alias is kept under what it stands for).
func _canon(id: String) -> String:
	var def: Dictionary = GameData.status(id)
	return str(def.get("alias_of", id))


## True if any status on it carries flag `key`.
func _st_any(key: String) -> bool:
	for id: String in enemy.statuses:
		if bool(_sdef(id).get(key, false)):
			return true
	return false


## The product of a number every status on it may carry (1 if none does). `alt` is an older name
## for the same key (speed_mult for move_mult, attack_rate_mult for attack_speed_mult).
func _st_mult(key: String, alt: String = "") -> float:
	var out := 1.0
	for id: String in enemy.statuses:
		var def: Dictionary = _sdef(id)
		out *= float(def.get(key, def.get(alt, 1.0)) if alt != "" else def.get(key, 1.0))
	return out


## Add `stacks` of a status (capped at its maximum) and refresh how long it lasts. `by` is who
## applied it: a status that does damage does it in their name. `opts` (a skill's payload) may set
## "lasts" (seconds), "time_mult", and "data" (numbers the status reads from the skill, such as
## Dripping's nudge, or where a Commanded body walks). Returns the stacks it now has.
func add_status(id: String, stacks: int = 1, by: Node = null, opts: Dictionary = {}) -> int:
	id = _canon(id)
	var def: Dictionary = _sdef(id)
	if def.is_empty() or enemy.body.is_dead() or bool(def.get("derived", "") != ""):
		return 0
	if bool(def.get("living_only", false)) and not enemy.is_living:
		return 0
	if bool(def.get("elites_immune", false)) and bool(enemy._def.get("elite", false)):
		return 0                                   # Exiled: an elite only takes the hit's shove
	# what is on it, or the ground it stands on, may refuse the status
	for other: String in enemy.statuses:
		if (_sdef(other).get("blocks", []) as Array).has(id):
			return 0
	if _in_zone_list("blocks_status", id):
		return 0
	# an elite shrugs some holds off into something lesser; a sleep needs a daze first; Wakeful refuses sleep
	if bool(enemy._def.get("elite", false)) and str(def.get("elite_status", "")) != "" and str(def["elite_status"]) != id:
		return add_status(str(def["elite_status"]), 1, by, opts)
	for blocker: Variant in def.get("blocked_by", []):
		if has_status(str(blocker)):
			return add_status(str(def.get("needs_first", "dazed")), 1, by) if def.has("needs_first") else 0
	if def.has("needs_first") and not has_status(str(def["needs_first"])):
		return add_status(str(def["needs_first"]), 1, by)
	if id == "aloft":
		if _shove_class() < 1.0:
			enemy.take_poise(float(def.get("heavy_poise", 50.0)))    # too heavy to leave the ground: it loses its footing instead
			return 0
		enemy.interrupt()
		enemy._leap_left = 0.0
	var cap: int = int(def.get("stacks", 1))
	for other: String in enemy.statuses:
		cap = maxi(cap, int((_sdef(other).get("cap_raise", {}) as Dictionary).get(id, 0)))
	var had: Dictionary = enemy.statuses.get(id, {})
	var now: int = mini(cap, int(had.get("stacks", 0)) + stacks)
	var who: Node = by if by != null else (had.get("by") as Node)
	var lasts: float = float(opts.get("lasts", def.get("lasts", 1.0)))
	lasts *= float(opts.get("time_mult", 1.0))
	if enemy.heavy and def.has("heavy_lasts_mult"):
		lasts *= float(def["heavy_lasts_mult"])
	if bool(def.get("no_refresh", false)) and not had.is_empty():
		lasts = float(had["t"])                  # Dosed: more doses, the same clock
	var entry: Dictionary = {"stacks": now, "t": maxf(lasts, 0.01), "by": who}
	var data: Dictionary = (had.get("data", {}) as Dictionary).duplicate()
	data.merge(opts.get("data", {}), true)
	if not data.is_empty():
		entry["data"] = data
	if had.has("taken"):
		entry["taken"] = had["taken"]
	enemy.statuses[id] = entry
	if had.is_empty():
		# the first time only: it changes another status's clock (Steeped: the dose clock runs longer, once)
		var more: Dictionary = def.get("adds_time", {})
		for other_id: String in more:
			if enemy.statuses.has(_canon(other_id)):
				var o: Dictionary = enemy.statuses[_canon(other_id)]
				o["t"] = float(o["t"]) + float(data.get("clock_add", more[other_id]))
		# turned round, its back to whoever did it (Turning Palm, Blowout, Deflect)
		if bool(def.get("turn_away", false)) and who is Node3D and is_instance_valid(who):
			enemy.turn_away_from((who as Node3D).global_position, float(entry["t"]))
	for gone: Variant in def.get("ends", []):
		if str(gone) != id:
			clear_status(str(gone))
	if bool(def.get("control", false)) or bool(def.get("cannot_act", false)) or bool(def.get("cannot_attack", false)):
		enemy.interrupt()                               # a hold breaks off whatever it was winding up
		enemy._leap_left = 0.0 if bool(def.get("cannot_act", false)) else enemy._leap_left
	# a status that fills up turns into another (Chill, at five, is Frozen)
	var on_cap: Dictionary = def.get("on_cap", {})
	if not on_cap.is_empty() and now >= int(def.get("stacks", 1)):
		if bool(on_cap.get("clear", false)):
			enemy.statuses.erase(id)
		var next: String = str(on_cap.get("elite_status", "")) if bool(enemy._def.get("elite", false)) and on_cap.has("elite_status") else str(on_cap.get("status", ""))
		if next != "":
			add_status(next, 1, who)
		return now
	return now


func status_stacks(id: String) -> int:
	id = _canon(id)
	if enemy.statuses.has(id):
		return int((enemy.statuses[id] as Dictionary).get("stacks", 0))
	return 1 if has_status(id) else 0


## Strip every boon on it (balance.json "enemy_boons": Frenzied, Drummed, Roused; Guardbreaker's purge).
func purge_boons() -> void:
	for id: Variant in GameData.balance.get("enemy_boons", []):
		if enemy.statuses.has(str(id)):
			clear_status(str(id))


## True if it carries the status, or one that counts as it (Waterlogged is Soaked, Frozen is
## Brittle), or - for a derived one - its health says so (Dying below half, Hale above).
func has_status(id: String) -> bool:
	id = _canon(id)
	if enemy.statuses.has(id):
		return true
	var def: Dictionary = _sdef(id)
	match str(def.get("derived", "")):
		"below_half":
			return enemy.is_living and enemy.body.total() < enemy.body.total_max() * 0.5
		"above_half":
			return enemy.is_living and enemy.body.total() > enemy.body.total_max() * 0.5
	for other: String in enemy.statuses:
		if (_sdef(other).get("counts_as", []) as Array).has(id):
			return true
	return false


func clear_status(id: String) -> void:
	enemy.statuses.erase(_canon(id))
	_end_with(_canon(id))


## Statuses that end with `id` (ends_with: a barb pulled when its doses are spent or paid).
func _end_with(id: String) -> void:
	for other: String in enemy.statuses.keys():
		if (_sdef(other).get("ends_with", []) as Array).has(id):
			enemy.statuses.erase(other)


## The sum of number `key` over the statuses on it that `who` put there (Tithed's heal, Leeched's drain for
## whoever applied it); 0 if none.
func status_sum_by(key: String, who: Node) -> float:
	var out := 0.0
	for id: String in enemy.statuses:
		var s: Dictionary = enemy.statuses[id]
		if s.get("by") == who and is_instance_valid(who):
			out += float(_sdef(id).get(key, 0.0))
	return out


## A status of its put there by `who` (or by a summon of theirs) carrying `key`, as [id, entry], or [].
func status_from(key: String, who: Node) -> Array:
	for id: String in enemy.statuses:
		var s: Dictionary = enemy.statuses[id]
		var by: Variant = s.get("by")
		if _sdef(id).has(key) and by != null and is_instance_valid(by) and (by == who or (who != null and who.get("caster") == by)):
			return [id, s]
	return []


## The data a skill left with a status (Dripping's nudge, a Commanded walk's goal), or {}.
func status_data(id: String) -> Dictionary:
	return (enemy.statuses.get(_canon(id), {}) as Dictionary).get("data", {})


## Its front armour after what is on it (Lit, Rotting, Rusting halve it; Corroded takes a third a stack).
func front_armour() -> float:
	var a: float = float(enemy._def.get("front_armour", 0.0)) * _st_mult("armour_mult")
	for id: String in enemy.statuses:
		var per: float = float(_sdef(id).get("armour_mult_per_stack", 1.0))
		if per != 1.0:
			a *= pow(per, float(int((enemy.statuses[id] as Dictionary)["stacks"])))
	return a


## How much metal it wears: 0 bare, 1 mailed, 2 plated (enemies.json "metal"); Stripped is bare.
func metal_class() -> int:
	return 0 if _st_any("metal_class_off") else int(enemy._def.get("metal", 0))


## The share of it not under worn armour (enemies.json "flesh"), raised by Corroded.
func flesh() -> float:
	var f: float = float(enemy._def.get("flesh", 1.0))
	for id: String in enemy.statuses:
		f += float(_sdef(id).get("flesh_per_stack", 0.0)) * float(int((enemy.statuses[id] as Dictionary)["stacks"]))
	return clampf(f, 0.0, 1.0)


## Nothing heals it (Arrested; standing in Clean Air).
func blocks_heal() -> bool:
	return _st_any("no_heal") or _in_zone_flag("no_heal")


## Lightning does not pass into or out of it (Insulated): no conducted marks.
func no_conduct() -> bool:
	return _st_any("no_conduct")


## How far a shove moves it: one weight class lighter while Waterlogged or Dwindled.
func _shove_class() -> float:
	if _st_any("lighter_class"):
		return 1.0 if enemy.shove_resist >= 0.5 else 0.5
	return enemy.shove_resist


## Light it gives off (Alight, Lit): Light.level_at reads it.
func light_radius() -> float:
	var r := 0.0
	for id: String in enemy.statuses:
		r = maxf(r, float(_sdef(id).get("light_radius", 0.0)))
	return r


func _blinded() -> Dictionary:
	for id: String in enemy.statuses:
		var b: Variant = _sdef(id).get("blinded")
		if b is Dictionary:
			return b
	return {}


## The product of the ground zones under it that tick status `id` harder (dps_mult {id: x}).
func _zone_dps_mult(id: String) -> float:
	var m := 1.0
	if not enemy.is_inside_tree():
		return m
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		var dm: Variant = z.get("dps_mult")
		if dm is Dictionary and (dm as Dictionary).has(id) and bool(z.call("has_point", enemy.global_position, enemy.radius)):
			m *= float((dm as Dictionary)[id])
	return m


## The largest bill bonus of the ground zones under it (Clean Air's dose_bonus).
func _zone_bill_bonus() -> float:
	var b := 0.0
	if not enemy.is_inside_tree():
		return b
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		if float(z.get("bill_bonus")) > 0.0 and bool(z.call("has_point", enemy.global_position, enemy.radius)):
			b = maxf(b, float(z.get("bill_bonus")))
	return b


## A ground zone of the caster's under it carries this flag (no_heal: Clean Air).
func _in_zone_flag(key: String) -> bool:
	if not enemy.is_inside_tree():
		return false
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		if bool(z.get(key)) and bool(z.call("has_point", enemy.global_position, enemy.radius)):
			return true
	return false


## A ground zone under it lists `id` under `key` (blocks_status).
func _in_zone_list(key: String, id: String) -> bool:
	if not enemy.is_inside_tree():
		return false
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		var list: Variant = z.get(key)
		if list is Array and (list as Array).has(id) and bool(z.call("has_point", enemy.global_position, enemy.radius)):
			return true
	return false


## It was hurt (and lives): what its statuses do about that.
func _after_hurt(applied: float, was_winding: bool) -> void:
	for id: String in enemy.statuses.keys():
		if not enemy.statuses.has(id):
			continue
		var def: Dictionary = _sdef(id)
		var s: Dictionary = enemy.statuses[id]
		if bool(def.get("wakes_on_hit", false)):
			enemy.statuses.erase(id)
			if str(def.get("then_status", "")) != "":
				add_status(str(def["then_status"]), 1, s.get("by") as Node)
			continue
		if def.has("ends_after_damage"):
			s["taken"] = float(s.get("taken", 0.0)) + applied
			if float(s["taken"]) >= float(def["ends_after_damage"]):
				_expire(id)
	if was_winding and _st_any("staggers_in_windup"):
		enemy.stagger(float(enemy._cfg["interrupt_stagger_s"]))


## A status ran out: what it leaves behind (Frozen leaves Chill; Dosed pays its bill; a hold that
## carries a release shove throws it away from whoever put it there).
func _expire(id: String) -> void:
	var s: Dictionary = enemy.statuses.get(id, {})
	enemy.statuses.erase(id)
	if s.is_empty() or enemy.body.is_dead():
		return
	var def: Dictionary = _sdef(id)
	var by: Variant = s.get("by")
	var who: Node = by if (by != null and is_instance_valid(by)) else null
	var ex: Dictionary = def.get("on_expire", {})
	if ex.has("status"):
		add_status(str(ex["status"]), int(ex.get("stacks", 1)), who)
	if ex.has("damage_per_stack"):
		var dmg: float = float(ex["damage_per_stack"]) * float(int(s.get("stacks", 1)))
		for other: String in enemy.statuses:
			var os: Dictionary = enemy.statuses[other]
			# Steeped: a bigger bill (the skill's own bill_mult, in its data, else the status's)
			var bm: Dictionary = _sdef(other).get("bill_mult", {})
			if bm.has(id):
				dmg *= float((os.get("data", {}) as Dictionary).get("bill_mult", bm[id]))
		dmg *= 1.0 + _zone_bill_bonus()                  # Clean Air: a bill paid inside costs more
		dmg *= float((s.get("data", {}) as Dictionary).get("bill_mult", 1.0))      # Venom Spur: this bill only
		if who != null and who.has_method("deal_damage"):
			who.call("deal_damage", enemy, dmg, ex.get("tags", ["dot"]))
		else:
			enemy.take_hit(dmg, false, null)
		if enemy.is_inside_tree() and not enemy.body.is_dead():
			FloatText.spawn(enemy.get_parent(), enemy.global_position + Vector3.UP * (enemy.height + 0.3), str(def.get("label", id)).to_upper(), Color(str(def.get("color", "ffffff"))))
	var data: Dictionary = s.get("data", {})
	if float(data.get("release_shove", 0.0)) > 0.0 and who is Node3D:
		enemy.shover = who
		enemy.shove(enemy.global_position - (who as Node3D).global_position, float(data["release_shove"]))
	_end_with(id)
	# a status that raised another's cap is gone: what is above the plain cap falls away (Contained's Infected)
	for other: String in enemy.statuses.keys():
		var cap: int = int(_sdef(other).get("stacks", 1))
		for o2: String in enemy.statuses:
			cap = maxi(cap, int((_sdef(o2).get("cap_raise", {}) as Dictionary).get(other, 0)))
		if int((enemy.statuses[other] as Dictionary).get("stacks", 1)) > cap:
			(enemy.statuses[other] as Dictionary)["stacks"] = cap


## What its statuses leave when it dies: a burning that jumps, a pool of blood, a sick cloud.
func _death_effects() -> void:
	for id: String in enemy.statuses:
		var def: Dictionary = _sdef(id)
		var s: Dictionary = enemy.statuses[id]
		var by: Variant = s.get("by")
		var who: Node = by if (by != null and is_instance_valid(by)) else null
		# a skill may leave word with its status of what its applier regrows if the body dies carrying it (Withering Needle)
		# a status that leaves something when its body dies tells its applier where (Exhume reads these grave sites)
		if not (def.get("on_death", {}) as Dictionary).is_empty() and who != null and who.has_method("status_death"):
			who.call("status_death", id, enemy.global_position)
		var okh: Variant = (s.get("data", {}) as Dictionary).get("on_kill_heal")
		if okh is Dictionary and who != null and who.has_method("heal_over"):
			who.call("heal_over", float((okh as Dictionary).get("heal", 0.0)), float((okh as Dictionary).get("over_s", 2.0)))
		if bool(def.get("jumps_on_death", false)):
			var heir: Node3D = _nearest_enemy_within(float(def.get("spread_radius", 1.2)))
			if heir != null:
				heir.call("add_status", id, 1, who)
		var od: Dictionary = def.get("on_death", {})
		if od.is_empty() or who == null:
			continue
		if bool(od.get("pool", false)) and who.has_method("spill_blood"):
			who.call("spill_blood", enemy.global_position, int(GameData.affinity("blood").get("pool", {}).get("death_measures", 3)), true)
		if int(od.get("held_blood", 0)) > 0 and who.has_method("gain_blood"):
			who.call("gain_blood", int(od["held_blood"]))
		if od.has("cloud") and who.has_method("lay_cloud"):
			who.call("lay_cloud", enemy.global_position, od["cloud"], ["disease", "cloud"])


## Every status's clock and what it does each tick: damage over time in the name of whoever put it
## there, spreading to whoever stands close, nudging, dripping blood, retching.
func _tick_statuses(delta: float) -> void:
	var frozen_by: Array = []
	var frozen_all := ""
	for id: String in enemy.statuses:
		var fz: Array = _sdef(id).get("freezes", [])
		frozen_by.append_array(fz)
		if fz.has("all"):
			frozen_all = id                       # Stasis: nothing else on it runs down
	for id: String in enemy.statuses.keys():
		if not enemy.statuses.has(id):
			continue
		var s: Dictionary = enemy.statuses[id]
		if frozen_by.has(id) or _in_zone_banking(id) or (frozen_all != "" and id != frozen_all):
			continue                              # Arrested, or banked in a pall of smoke: it does not run down
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			_expire(id)
	for id: String in enemy.statuses.keys():
		if not enemy.statuses.has(id) or enemy.body.is_dead():
			continue
		_tick_status(id, delta)
	if not enemy.statuses.has("alight"):
		_burn_t = 0.0
		_spread_t = 0.0


## True if a ground zone it stands in banks this status (Smokepall: burns do not run down inside).
func _in_zone_banking(id: String) -> bool:
	if not enemy.is_inside_tree():
		return false
	for z: Node in enemy.get_tree().get_nodes_in_group("ground_zones"):
		if str(z.get("banks")) == id and bool(z.call("has_point", enemy.global_position, enemy.radius)):
			return true
	return false


func _tick_status(id: String, delta: float) -> void:
	var def: Dictionary = _sdef(id)
	var s: Dictionary = enemy.statuses[id]
	var by: Variant = s.get("by")
	var who: Node = by if (by != null and is_instance_valid(by)) else null
	var data: Dictionary = s.get("data", {})
	# spread: one stack jumps to an enemy that has stood close for long enough
	if def.has("spread_radius") and not _st_any("no_death_effects"):
		var near: Node3D = _nearest_enemy_within(float(def.get("spread_radius", 1.2)))
		s["spread"] = float(s.get("spread", 0.0)) + delta if near != null else 0.0
		if near != null and float(s["spread"]) >= float(def.get("spread_time", 1.0)):
			s["spread"] = 0.0
			near.call("add_status", id, 1, who)
	var dps: float = float(def.get("dps_per_stack", 0.0)) * float(int(s["stacks"]))
	dps += float(def.get("dps_per_metal_class", 0.0)) * float(metal_class())
	if dps > 0.0:
		s["acc"] = float(s.get("acc", 0.0)) + delta
		var every: float = float(def.get("tick_s", 0.5))
		while float(s["acc"]) >= every and enemy.statuses.has(id) and not enemy.body.is_dead():
			s["acc"] = float(s["acc"]) - every
			var dmg: float = dps * every
			if def.has("moving_mult") and (enemy.velocity.length() > 0.2 or enemy._windup >= 0.0):
				dmg *= float(def["moving_mult"])          # Bleeding: twice as fast while it moves or swings
			if bool(def.get("times_flesh", false)):
				dmg *= flesh()
			for other: String in enemy.statuses:
				dmg *= float((_sdef(other).get("dps_mult", {}) as Dictionary).get(id, 1.0))
			dmg *= _zone_dps_mult(id)                    # Smokepall: the burning ticks harder in the smoke
			if who != null and who.has_method("deal_damage"):
				var dot: Variant = who.call("deal_damage", enemy, dmg, def.get("dot_tags", ["dot"]))
				# Tormented: part of every tick feeds whoever put it there
				if float(def.get("drain_frac", 0.0)) > 0.0 and dot is HitContext and who.has_method("drain_heal"):
					who.call("drain_heal", (dot as HitContext).applied * float(def["drain_frac"]), enemy, false)
			else:
				enemy.take_hit(dmg, false, null, def.get("dot_tags", ["dot"]))
		if id == "alight":
			_burn_t = float(s.get("acc", 0.0))
	if enemy.body.is_dead() or not enemy.statuses.has(id):
		return
	# Barbed: it works another status in every so often, in the name of whoever put it there
	var adds: Variant = def.get("adds_status")
	if adds is Dictionary:
		s["add_t"] = float(s.get("add_t", 0.0)) + delta
		if float(s["add_t"]) >= float(data.get("every", (adds as Dictionary).get("every", 1.0))):
			s["add_t"] = 0.0
			add_status(str((adds as Dictionary).get("status", "")), int((adds as Dictionary).get("stacks", 1)), who)
	# Bleeding drips a pool every so often
	if def.has("drips_pool_s") and who != null and who.has_method("spill_blood"):
		s["drip"] = float(s.get("drip", 0.0)) + delta
		if float(s["drip"]) >= float(def["drips_pool_s"]):
			s["drip"] = 0.0
			who.call("spill_blood", enemy.global_position, 1, false)
	# Dripping: nudged away from the caster and losing footing, a little every second
	var nudge_per: float = float(data.get("nudge_per_s", def.get("nudge_per_s", 0.0)))
	if nudge_per > 0.0 and who is Node3D:
		var away: Vector3 = enemy.global_position - (who as Node3D).global_position
		away.y = 0.0
		if away.length() > 0.05:
			enemy.nudge(away.normalized() * nudge_per * delta)
	var poise_per: float = float(data.get("poise_per_s", def.get("poise_per_s", 0.0)))
	if poise_per > 0.0:
		s["pacc"] = float(s.get("pacc", 0.0)) + delta
		if float(s["pacc"]) >= 1.0:
			s["pacc"] = 0.0
			enemy.take_poise(poise_per)
	# Sick: every so often it retches, loses what it was doing and stands still
	var retch_every: float = float(data.get("retch_every", def.get("retch_every", 0.0)))
	if retch_every > 0.0:
		_retch_t += delta
		if _retch_t >= retch_every:
			_retch_t = 0.0
			enemy.interrupt()
			enemy._held_t = float(data.get("retch_s", def.get("retch_s", 0.5)))


## Burning: kept for old callers; the status engine burns every status with dps_per_stack.
func _tick_alight(delta: float) -> void:
	if enemy.statuses.has("alight"):
		_tick_status("alight", delta)


## The closest other living enemy within `reach` of this one, or null.
func _nearest_enemy_within(reach: float) -> Node3D:
	if not enemy.is_inside_tree():
		return null
	var best: Node3D = null
	var best_d: float = reach
	for node: Node in enemy.get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or e == enemy or bool(e.call("is_dead")):
			continue
		var d: float = e.global_position.distance_to(enemy.global_position) - float(e.get("radius")) - enemy.radius
		if d <= best_d:
			best_d = d
			best = e
	return best


## How far its friends are drawn to it (Masked, Charmed: the largest lure_radius on it), 0 if none.
func lure_reach() -> float:
	var r := 0.0
	for id: String in enemy.statuses:
		r = maxf(r, float(_sdef(id).get("lure_radius", 0.0)))
	return r


## True while it fights for someone else (Charmed).
func _charmed() -> bool:
	return _st_any("fights_for_source")


## Spared and Dying: it kneels and does nothing.
func _kneeling() -> bool:
	for id: String in enemy.statuses:
		var below: float = float((enemy.statuses[id] as Dictionary).get("data", {}).get("kneels_below", _sdef(id).get("kneels_below", 0.0)))
		if below > 0.0 and enemy.body.total() < enemy.body.total_max() * below:
			return true
	return false
