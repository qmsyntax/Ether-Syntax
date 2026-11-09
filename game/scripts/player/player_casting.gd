class_name PlayerCasting
extends RefCounted
## The player's part for casting: the hotbar, cast_ability / _perform_cast, wind-ups, recovery, buffs, reflux, targeting helpers.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const ISO_YAW := deg_to_rad(45.0)

var player: Player


func _init(of: Player) -> void:
	player = of


## Start over with the kits of the current affinities, on the bar in order.
func _reset_loadout() -> void:
	player.world_part.drop_stones()
	player.buffs.clear()
	player._windup = {}
	player._windup_t = 0.0
	player.abilities.clear()
	for i: int in player.hotbar.size():
		player.hotbar[i] = -1
	var loadout: Array = GameData.ability_loadout(player.affinities)
	for i: int in loadout.size():
		player.abilities.append({"id": str(loadout[i]), "stage": 0, "progress": 0.0})
		if i < player.hotbar.size():
			player.hotbar[i] = i


func primary_affinity() -> String:
	return player.affinities[0] if not player.affinities.is_empty() else "water"


func reflux_of(aff: String) -> float:
	return float(player.reflux_by.get(aff, 0.0))


func is_locked(aff: String) -> bool:
	return bool(player.locked_by.get(aff, false))


## The affinity whose reflux just hit the cap (valid inside TalentEffect.on_reflux_cap).
var capping_affinity := ""


## Drop the capping affinity's reflux to `value` (a talent venting it).
func vent_reflux(value: float) -> void:
	player.reflux_by[capping_affinity if capping_affinity != "" else primary_affinity()] = value


func clear_reflux() -> void:
	player.reflux_by.clear()
	player.locked_by.clear()


## Every affinity cools at once; one that drops far enough unlocks.
func _shed_reflux(amount: float) -> void:
	var shed: float = amount * player.inventory.stat("reflux_shed_mult", true) * player.progress_part.temper_stat("reflux_shed_mult")
	for aff: String in player.reflux_by:
		var a_def: Dictionary = GameData.affinity(aff)
		var rate: float = float(a_def.get("reflux_shed_mult_combat", 1.0)) if player.in_combat else 1.0
		if player.in_combat and a_def.has("reflux_shed_mult_moving"):
			# wind: its heat blows off while you run and sits while you stand (unless you stand in Dead Air)
			rate = float(a_def["reflux_shed_mult_moving"]) if (player._moving or player.hits_part._zone_flag("shed_standing")) else float(a_def.get("reflux_shed_mult_standing", 1.0))
		rate *= float(a_def.get("reflux_shed_mult", 1.0))       # earth keeps what little it makes
		rate *= buff_num("shed_mult")                            # Long Breath
		player.reflux_by[aff] = maxf(0.0, float(player.reflux_by[aff]) - shed * rate)
		if is_locked(aff) and float(player.reflux_by[aff]) < float(player._reflux_cfg["unlock_below"]):
			player.locked_by[aff] = false
			player.note("%s affinity unlocks." % str(GameData.affinity(aff).get("label", aff)))


# --- zones, buffs, the rod (design/05 step 5b) -------------------------------------------------

## A number from whichever buffs are on you, multiplied together (1 if none carries it).
func buff_num(key: String) -> float:
	var out := 1.0
	for id: String in player.buffs:
		out *= float((player.buffs[id] as Dictionary).get(key, 1.0))
	return out


func _tick_buffs(delta: float) -> void:
	for id: String in player.buffs.keys():
		var b: Dictionary = player.buffs[id]
		b["t"] = float(b["t"]) - delta
		# Knit: health a second, up to the ceiling your wounds allow; then a trickle into the oldest wound
		if float(b.get("heal_per_s", 0.0)) > 0.0 and not player.hits_part._heal_blocked():
			var pts: float = float(b["heal_per_s"]) * delta * player.combat_part.heal_rate_mult()       # Life: faster just after you land a hit
			var used: float = player.body.heal(pts)
			if pts - used > 0.0:
				var filled: Dictionary = player.body.fill_sinks((pts - used) * float(b.get("overflow_to_sink", 0.0)))
				player.combat_part._wounds_closed(filled["closed"])
		if b.get("aura") is Dictionary:
			_tick_aura(b, delta)
		if float(b["t"]) <= 0.0:
			player.buffs.erase(id)
			_buff_ended(id, b)
			if id == "conjured":
				player._shown_weapon = ""                        # the worn weapon comes back
				player.economy_part._show_weapon()


## An aura (Stonehide's mud, Millstone's pull and taunt, Gloom Mantle's dark): every tick_s its payload lands on
## each enemy within radius of you (a hold once per target per cast, as zones do), and they are drawn toward you at
## pull_per_s. It moves with you; with dark it is Dark ground (a zone that follows you, laid when the buff starts).
func _tick_aura(b: Dictionary, delta: float) -> void:
	var aura: Dictionary = b["aura"]
	var r: float = float(aura.get("radius", 3.0))
	var near: Array[Node3D] = _enemies_near(player.global_position, r)
	if float(aura.get("pull_per_s", 0.0)) > 0.0:
		for e: Node3D in near:
			var inward: Vector3 = player.global_position - e.global_position
			inward.y = 0.0
			if inward.length() > float(e.get("radius")) + 0.9:
				e.call("nudge", inward.normalized() * minf(float(aura["pull_per_s"]) * delta, inward.length()))
	b["aura_t"] = float(b.get("aura_t", 0.0)) - delta
	if float(b["aura_t"]) > 0.0:
		return
	b["aura_t"] = float(aura.get("tick_s", 0.5))
	if not b.has("aura_memo"):
		b["aura_memo"] = {}
	var payload: Dictionary = aura.get("payload", {})
	if payload.is_empty():
		return
	for e2: Node3D in near:
		player.hits_part.apply_hit(e2, payload, ["ability", str(b.get("affinity", "")), "aura"], 1.0, Vector3.ZERO, b["aura_memo"])


## A buff has run out: its end payload (Millstone's on_end), a counter that was never used (patience_ward, or a
## share of the essence back: refund_unused), its following dark.
func _buff_ended(id: String, b: Dictionary) -> void:
	if float(b.get("softened", 0.0)) > 0.0 and float(b.get("softened_return", 0.0)) > 0.0:
		player.combat_part.life_heal(float(b["softened"]) * float(b["softened_return"]))         # Kind Light: what it softened comes back
	if b.get("on_end") is Dictionary:
		var oe: Dictionary = (b["on_end"] as Dictionary).duplicate()
		oe["burst_radius"] = float(oe.get("radius", 3.0))
		player.hits_part._burst_at(player.global_position, oe, ["ability", str(b.get("affinity", "")), id, "burst"])
	if b.has("window_s") and not bool(b.get("countered", false)):
		if float(b.get("patience_ward", 0.0)) > 0.0:
			player.combat_part.add_ward(float(b["patience_ward"]), -1.0, {"from": id})
		if float(b.get("refund_unused", 0.0)) > 0.0:
			player.essence = minf(player.essence_max, player.essence + float(b.get("cost", 0.0)) * float(b["refund_unused"]))


## self_buff: the skill's own numbers ride on you for its duration. Some do something at once too:
## breathe out held blood (Long Breath), light every enemy near you (Clear Eye), shake off what
## holds you (Fever Break).
func _take_buff(ab: Dictionary) -> void:
	var b: Dictionary = ab.duplicate(true)
	b["t"] = float(ab.get("duration", ab.get("window_s", 5.0)))      # a counter lasts its window
	var bid: String = str(ab.get("buff", ab.get("name", "buff")))
	b.erase("coat")
	player.buffs[bid] = b
	player.combat_part._put_coat(ab, bid)
	# an aura that is Dark ground goes with you as a zone of dark (Gloom Mantle)
	if b.get("aura") is Dictionary and bool((b["aura"] as Dictionary).get("dark", false)):
		var dz := GroundZone.new()
		dz.shape = "circle"
		dz.caster = player
		dz.dark = true
		dz.kind = "dark_ground"
		dz.bright = false
		dz.radius = float((b["aura"] as Dictionary).get("radius", 3.0))
		dz.life = float(b["t"])
		dz.tags = ["ability", str(ab.get("affinity", "")), "aura", "zone"]
		dz.color = GameData.affinity_color(str(ab.get("affinity", "")))
		dz.follow = player
		dz.from = player.global_position
		dz.to = player.global_position
		player.get_parent().add_child(dz)
	if str(ab.get("set_focus", "")) == "max":
		player._focus_fill_next = true                  # Red Iron: your next metal hit starts the edge white-hot
	player.world_part._share_buff(ab, bid, float(b["t"]))
	# what the buff does round you as it starts (Stoke's flare, Red Iron's heat): on_cast within its radius
	if ab.get("on_cast") is Dictionary:
		var oc: Dictionary = (ab["on_cast"] as Dictionary).duplicate()
		oc["burst_radius"] = float(oc.get("radius", ab.get("radius", 2.5)))
		player.hits_part._burst_at(player.global_position, oc, ["ability", str(ab.get("affinity", "")), str(bid), "burst"])
	# a buff's ward (Dawnward, Ice Shell, Black Shroud): into the one pool; ward_from spends a store of yours into it
	if float(ab.get("ward", 0.0)) > 0.0 or str(ab.get("ward_from", "")) != "":
		var amount: float = float(ab.get("ward", 0.0))
		if str(ab.get("ward_from", "")) != "":
			amount += float(player.hits_part.store_take(str(ab["ward_from"])))
		if ab.has("ward_max"):
			amount = minf(amount, float(ab["ward_max"]))
		var opts: Dictionary = {"from": bid}
		for k: String in ["on_break", "expire_heal_frac", "no_stagger"]:
			if ab.has(k):
				opts[k] = ab[k]
		if opts.has("on_break"):
			opts["on_break_tags"] = ["ability", str(ab.get("affinity", "")), "ward"]
		player.combat_part.add_ward(amount, float(ab.get("duration", -1.0)), opts)
	if float(ab.get("add_reflux", 0.0)) > 0.0:
		var aff: String = str(ab.get("affinity", ""))
		player.reflux_by[aff] = reflux_of(aff) + float(ab["add_reflux"])
	if ab.has("spend_blood") and float(ab.get("shed_per_blood", 0.0)) > 0.0:
		var spent: int = player.hits_part._spend_blood_first_pools(int(ab["spend_blood"]), float(ab.get("pool_radius", 0.0)))
		player.hits_part._vent_hottest(float(ab["shed_per_blood"]) * float(spent))
		player.poise = float(GameData.num("combat", "player_poise"))
	if float(ab.get("reveal_radius", 0.0)) > 0.0:
		for e: Node3D in _enemies_near(player.global_position, float(ab["reveal_radius"])):
			e.call("add_status", "lit", 1, player)
	if ab.get("cleanse") is String or (ab.get("cleanse") is bool and bool(ab["cleanse"])):
		# lift what the list names (balance.json cleanse: binds, afflictions), and pay per one lifted
		var lifted: int = player.hits_part.cleanse(str(ab["cleanse"]) if ab["cleanse"] is String else "binds")
		if float(ab.get("ward_per_cleansed", 0.0)) > 0.0 and lifted > 0:
			var w: float = float(ab["ward_per_cleansed"]) * float(lifted)
			if ab.has("ward_cleansed_max"):
				w = minf(w, float(ab["ward_cleansed_max"]))           # Absolution: up to 40 ward
			player.combat_part.add_ward(w, float(ab.get("duration", -1.0)), {"from": bid + "_cleansed"})
		if float(ab.get("heal_per_cleansed", 0.0)) > 0.0 and lifted > 0:
			var counted: int = mini(lifted, int(ab.get("heal_cleansed_max", lifted)))       # Fever Break: up to 4 of them
			player.combat_part.heal_over(float(ab["heal_per_cleansed"]) * float(counted), float(ab.get("heal_over_s", 2.0)))
	player._float(str(ab.get("name", "")).to_lower(), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))


# --- more skill behaviours (design/05 Appendix A) -------------------------------------------------

## The spot a point-aimed skill lands on: toward the cursor, at most `reach` away.
func _aim_point(reach: float) -> Vector3:
	var want: Vector3 = player.motion_part._cursor_ground() - player.global_position
	want.y = 0.0
	if want.length() < 0.5:
		want = player._facing * reach                    # no cursor to speak of (bot, headless): straight ahead
	if want.length() > reach:
		want = want.normalized() * reach
	return player.global_position + want


## Living enemies whose bodies reach within `radius` of `point`.
func _enemies_near(point: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not player.is_inside_tree():
		return out
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null or bool(e.is_dead()):
			continue
		var to: Vector3 = e.global_position - point
		to.y = 0.0
		if to.length() <= radius + float(e.radius):
			out.append(e)
	return out


## True while you are set for a braced skill: you take less and cannot be staggered.
func is_braced() -> bool:
	return (player._windup_t > 0.0 and bool(player._windup.get("braced", false))) or (player._dash_time > 0.0 and player._dash_braced) \
		or player._brace_t > 0.0 or (not player._held.is_empty() and bool((player._held["ab"] as Dictionary).get("braced", false)))


## True if any buff on you carries flag `key` (a braced buff, an immovable one...).
func _buff_flag(key: String) -> bool:
	for id: String in player.buffs:
		if bool((player.buffs[id] as Dictionary).get(key, false)):
			return true
	return false


## How far through a held skill you are (a channel's hold, a charge), 0 to 1; -1 when holding nothing.
func held_frac() -> float:
	if player._held.is_empty():
		return -1.0
	var ab: Dictionary = player._held["ab"]
	var full: float = float(ab.get("charge_max", ab.get("duration", GameData.num("skills", "channel_max_s"))))
	return clampf(float(player._held["t"]) / maxf(0.01, full), 0.0, 1.0)


## How far through a wind-up you are, 0 to 1; -1 when you are not winding anything up.
func windup_frac() -> float:
	if player._windup_t <= 0.0 or player._windup_total <= 0.0:
		return -1.0
	return clampf(1.0 - player._windup_t / player._windup_total, 0.0, 1.0)


## A wind-up holds you where you stood and where you aimed; when it ends, the skill goes off.
func _tick_windup(delta: float) -> void:
	player._facing = player._windup.get("facing", player._facing)     # a click made meanwhile is kept for when it goes off
	player._windup_t -= delta
	if player._windup_t > 0.0:
		return
	var w: Dictionary = player._windup
	player._windup = {}
	player._windup_t = 0.0
	if not bool(w.get("release", false)):
		return
	var target: Node3D = w["target"] if is_instance_valid(w["target"]) else null
	_perform_cast(w["ab"], str(w["kind"]), str(w["aff"]), float(w["stage_mult"]), w["tags"], target, w["point"])


## Where a shot leaves you: a little ahead, unless something solid is closer than that.
func _muzzle() -> Vector3:
	var chest: Vector3 = player.global_position + Vector3.UP * 1.0
	var out: Vector3 = chest + player._facing * 0.8
	return chest if not _ray(chest, out).is_empty() else out


## The enemy a single-target skill would land on, if it is within `reach`: the one under the
## cursor if you are pointing at one - and only that one, never a nearer bystander - else the one
## you are fighting, else the nearest.
func _skill_target(reach: float) -> Node3D:
	var pick: Node3D = _skill_candidate()
	if pick == null:
		return null
	var to: Vector3 = pick.global_position - player.global_position
	to.y = 0.0
	return pick if to.length() <= reach + float(pick.get("radius")) else null


## The enemy a single-target skill would be aimed at, near or far: the one under the cursor, else the
## one you are fighting, else the nearest (whether it is in reach is _skill_target's question).
func _skill_candidate() -> Node3D:
	if player._forced_target != null and is_instance_valid(player._forced_target) and not bool(player._forced_target.call("is_dead")):
		return player._forced_target                    # a walked-in cast lands on the foe it walked to
	for c: Variant in [player.hovered, player.attack_target, player.bot_part._nearest_enemy()]:
		if c != null and is_instance_valid(c) and (c as Node).is_in_group("enemies") and not bool((c as Node).call("is_dead")):
			return c
	return null


## First thing in the world (walls, blocks, floor - not bodies) between two points, or {}. With
## `past_own_stone` your own standing stone is not in the way (your shots pass it - combat review R4c).
func _ray(from: Vector3, to: Vector3, past_own_stone: bool = false) -> Dictionary:
	if not player.is_inside_tree():
		return {}
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	if past_own_stone:
		var own: Array[RID] = []
		for st: Variant in player.stones:
			if is_instance_valid(st):
				own.append((st as CollisionObject3D).get_rid())
		q.exclude = own
	return player.get_world_3d().direct_space_state.intersect_ray(q)


## A bright line that fades: beams, arcs and the trail of a blink.
func _line_visual(from: Vector3, to: Vector3, color: Color) -> void:
	if not player.is_inside_tree() or from.distance_to(to) < 0.05:
		return
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, from.distance_to(to))
	line.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color, 0.9)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = mat
	player.get_parent().add_child(line)
	line.global_position = (from + to) * 0.5
	line.look_at(to, Vector3.UP if absf((to - from).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "scale", Vector3(0.1, 0.1, 1.0), 0.14)
	tween.tween_callback(line.queue_free)


# --- abilities --------------------------------------------------------------------

## Cast whatever ability sits in hotbar slot `slot` (0-based).
func cast_slot(slot: int) -> void:
	if slot < 0 or slot >= player.hotbar.size() or player.hotbar[slot] < 0:
		return
	var action: String = "ability_%d" % (slot + 1)
	player._cast_action = action if InputMap.has_action(action) and Input.is_action_pressed(action) else ""
	player._casting_slot = slot
	cast_ability(player.hotbar[slot])
	player._casting_slot = -1
	player._cast_action = ""


## Test characters only: show the next six learned skills on the bar (a test-only "next page").
func next_hotbar_page() -> void:
	if not player.test_character or player.abilities.is_empty():
		return
	var per: int = player.hotbar.size()
	var pages: int = int(ceil(float(player.abilities.size()) / float(per)))
	player.hotbar_page = (player.hotbar_page + 1) % maxi(1, pages)
	for i: int in per:
		var idx: int = player.hotbar_page * per + i
		player.hotbar[i] = idx if idx < player.abilities.size() else -1
	player.note("Skill bar: page %d of %d." % [player.hotbar_page + 1, pages])


func cast_ability(index: int) -> void:
	if not player.active or player.dead or player.meditating or index < 0 or index >= player.abilities.size():
		return
	var state: Dictionary = player.abilities[index]
	var ab: Dictionary = player.runes_part.ability_stats(state)
	if ab.is_empty():
		return
	var aff: String = str(ab.get("affinity", ""))
	var aff_name: String = str(GameData.affinity(aff).get("label", aff))
	if not player.affinities.has(aff):
		_refuse("no_affinity", "No %s affinity" % aff_name.to_lower())
		player.note("You have no %s affinity." % aff_name.to_lower())
		return
	if is_locked(aff):
		_refuse("locked", "%s locked by reflux - meditate [%s]" % [aff_name, Keybinds.binding_text("meditate")])
		player.note("%s affinity is locked by reflux. Meditate (hold %s)." % [aff_name, Keybinds.binding_text("meditate")])
		return
	if player._recover_t > 0.0 or (player._stagger_t > 0.0 and not player.hits_part._lifts(ab, "staggered")):
		return                                   # still finishing the last one, or off your feet (a cleanse that lifts it may)
	if not player._held.is_empty():
		player.moves_part._end_held()                              # a new cast lets go of what you were holding
		return
	var heat: float = reflux_of(aff)
	var cost: float = float(ab["cost"]) * (float(player._reflux_cfg["pain_cost_mult"]) if heat >= float(player._reflux_cfg["pain_at"]) else 1.0)
	# Winded: the dash is not free. A second movement skill too soon costs double, in essence and heat.
	var kind: String = str(ab["kind"])
	var movement: bool = kind == "dash" or kind == "blink" or kind == "grapple" or kind == "streak"
	var winded: bool = movement and player._winded_t > 0.0 and not bool(ab.get("clears_winded", false))
	if winded:
		cost *= GameData.num("combat", "winded_cost_mult")
	var per_second: bool = bool(ab.get("cost_per_s", false)) or kind == "channel"
	if per_second:
		cost = 0.0                               # a channel pays as it is held (see _tick_held)
	if player.essence < cost or (per_second and player.essence < float(ab["cost"]) * 0.25):
		_refuse("essence", "Not enough essence")
		player.note("Not enough essence for %s." % str(ab["name"]))
		return
	if float(ab.get("heat_cost", 0.0)) > 0.0 and heat < float(ab["heat_cost"]):
		_refuse("heat", "Needs %d heat" % int(ab["heat_cost"]))
		player.note("%s needs %d heat." % [str(ab["name"]), int(ab["heat_cost"])])
		return
	# Some skills need something to point at; find out before anything is spent.
	var strike_target: Node3D = null
	var blink_to := Vector3.ZERO
	var reach: float = float(ab["range"]) if ab.has("range") else player.economy_part.reach_now() + float(ab.get("range_bonus", 0.0))
	if kind == "targeted_strike" or kind == "chain" or (kind == "displace" and ["pull_target", "throw_target"].has(str(ab.get("mode", "")))) \
			or (kind == "smite" and not bool(ab.get("nearest_to_point", false))) or (kind == "channel" and str(ab.get("shape", "")) == "tether") \
			or (kind == "detonate" and str(ab.get("gather_into", "")) == "target"):
		strike_target = _skill_target(reach)
		var no_line := false
		if strike_target != null and kind == "smite" and GameData.balance["skills"].get("smite_needs_line", true) \
				and not bool((ab.get("on_hit", {}) as Dictionary).get("through", false)) \
				and not _ray(player.global_position + Vector3.UP, strike_target.global_position + Vector3.UP).is_empty():
			strike_target = null                 # a wall or stone stands between
			no_line = true
		if strike_target == null and not no_line and kind == "targeted_strike" and player.motion_part._walk_in(index, reach):
			return                               # out of reach: walk in, then cast (nothing is spent yet)
		if strike_target == null:
			if no_line:
				_refuse("no_line", "No clear line")
			elif _skill_candidate() != null:
				_refuse("out_of_reach", "Out of reach")
			else:
				_refuse("no_target", "No target")
			player.note("%s needs someone within reach." % str(ab["name"]))
			return
		if str(ab.get("needs_status", "")) != "" and kind != "detonate" and not bool(strike_target.call("has_status", str(ab["needs_status"]))):
			_refuse("needs_status", "Needs a %s target" % StatusText.label(str(ab["needs_status"])))
			player.note("%s needs a target that is %s." % [str(ab["name"]), StatusText.label(str(ab["needs_status"]))])
			return
	elif kind == "smite":
		blink_to = _aim_point(reach)
		strike_target = _nearest_enemy_to(blink_to, reach)
		if strike_target == null:
			_refuse("no_target", "No target there")
			player.note("%s needs someone near where you point." % str(ab["name"]))
			return
	elif kind == "blink" or kind == "grapple":
		var spot: Variant = player.moves_part._blink_point(float(ab.get("range", 6.0)))
		var special: Variant = player.moves_part._special_landing(ab)
		if special != null:
			spot = special
		elif bool(ab.get("needs_shadow", false)) and spot != null and not Light.is_dark(player.get_tree(), spot):
			_refuse("no_landing", "No shadow there")
			player.note("There is no shadow there to rise from.")
			return
		if spot == null:
			_refuse("no_landing", "No way through")
			player.note("There is no way through to there.")
			return
		blink_to = spot
	elif kind == "prop" and str(ab.get("shape", "")) == "":
		var where: Variant = player.world_part._prop_point(ab)
		if where == null:
			_refuse("no_landing", "No room there")
			player.note("There is no room to raise stone there.")
			return
		blink_to = where
	elif kind == "displace" or kind == "delayed_blast" or kind == "ground_zone" or kind == "rod" or kind == "prop" or kind == "seed" \
			or kind == "summon" or (kind == "field_pulse" and ab.has("range")) or (kind == "charge_release" and str(ab.get("release", "")) == "delayed_blast"):
		blink_to = _aim_point(float(ab.get("range", 8.0)))
	if str(ab.get("needs", "")).begins_with("corpse"):
		var body_at: Fallen = player.world_part._corpse_near(blink_to, float(GameData.num("skills", "jump_radius")))
		if body_at == null and str(ab["needs"]) == "corpse":
			_refuse("no_target", "Needs a body there")
			player.note("%s needs a body where you point." % str(ab["name"]))
			return
		if body_at != null:
			blink_to = body_at.global_position
	elif kind == "summon" and str(ab.get("needs", "")) == "growth":
		if player.world_part._growth_at(blink_to, 1.5) == null:
			_refuse("no_target", "Needs your growth there")
			player.note("%s needs your growth where you point." % str(ab["name"]))
			return
	if kind == "melee_burst" and player.motion_part._walk_in(index, player.melee_range + float(ab.get("reach_bonus", 0.0))):
		return                                   # its foe is out of the sweep: walk in, then cast
	player.essence -= cost
	if float(ab.get("heat_cost", 0.0)) > 0.0:
		player.reflux_by[aff] = heat - float(ab["heat_cost"])          # paid in heat, not essence (Wickpinch)
	else:
		player.reflux_by[aff] = heat + cost * float(ab["reflux_per_cost"])
	if float(ab.get("vent_reflux", 0.0)) > 0.0:
		player.reflux_by[aff] = maxf(0.0, reflux_of(aff) - float(ab["vent_reflux"]))
	_advance(state, maxf(cost, float(ab["cost"]) * 0.5))
	if movement:
		if winded:
			player._float("winded", Color(0.8, 0.8, 0.9))
		if bool(ab.get("clears_winded", false)):
			player._winded_t = 0.0
		if not bool(ab.get("never_winds", false)):
			player._winded_t = GameData.num("combat", "winded_s")
	if player.hits_part._hidden():
		player._cast_hidden_t = GameData.num("skills", "ambush_cast_window_s")             # this cast's hits come out of Unseen
	if not _cast_is_quiet():
		player._unseen_reveal_t = float(GameData.affinity("dark").get("reveal_s", 1.0))     # casting shows you for a moment

	var stage_mult: float = ability_damage_mult(int(state["stage"])) * float(ab.get("damage_all", 1.0))
	var tags: Array = ["ability", aff, str(state["id"])]
	player._drain_cast = 0.0                           # a drain's cap is per cast
	if bool(ab.get("weapon", false)):
		tags.append("weapon")                    # made with your weapon: it carries your coat (poison.json)
	var windup: float = float(ab.get("windup", 0.0))
	if player._forced_target == null:
		player.motion_part._face_cast_aim(kind)                     # a walked-in cast already faces the foe it walked to
	if kind == "prop" or kind == "delayed_blast" or kind == "ground_zone" or kind == "rod" or kind == "seed" or kind == "summon" \
			or (kind == "displace" and strike_target == null) or (kind == "smite" and strike_target != null):
		var to_spot: Vector3 = (strike_target.global_position if (kind == "smite" and strike_target != null) else blink_to) - player.global_position
		to_spot.y = 0.0
		if to_spot.length() > 0.2:
			player._facing = to_spot.normalized()
	if bool(ab.get("breaks_aim", false)):
		for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
			if str(node.behaviour) == "ranged" and float(node.get("_windup")) >= 0.0:
				node.interrupt()           # everyone aiming at you loses the aim
	if bool(ab.get("frees_caster", false)):
		player._stagger_t = 0.0
		player._shoved_left = 0.0
	# held skills start now and do their work while held
	if kind == "channel" or kind == "charge_release":
		player.moves_part._start_held(ab, kind, aff, stage_mult, tags, strike_target, blink_to, state)
	# Stone starts rising at once; everything else with a wind-up goes off when it ends.
	elif windup <= 0.0 or kind == "prop" or kind == "delayed_blast":
		_perform_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)
	if kind != "rod":
		player.world_part._rod_relay(aff, stage_mult)
	if windup > 0.0:
		player._windup_t = windup
		player._windup_total = windup
		player._windup = {"ab": ab, "kind": kind, "aff": aff, "stage_mult": stage_mult, "tags": tags, "target": strike_target, "point": blink_to,
			"facing": player._facing, "braced": bool(ab.get("braced", false)), "release": kind != "prop" and kind != "delayed_blast"}
		player.has_move_goal = false
		player.attack_target = null
		player.pickup_target = null
		if bool(player._windup["release"]):
			player._motion_started = player.motion_part._play_cast_motion(ab, kind, windup)       # the motion lands as the wind-up ends
		if bool(ab.get("braced", false)):
			player._float("braced", GameData.affinity_color(aff).lightened(0.3))

	# A skill takes a moment to finish; running hot makes that moment longer (it no longer hurts).
	var recovery: float = float(ab.get("recovery", GameData.num("abilities", "cast_recovery"))) * buff_num("recovery_mult")
	if heat >= float(player._reflux_cfg["burn_at"]):
		recovery = recovery * float(player._reflux_cfg["burn_recovery_mult"]) + float(player._reflux_cfg["burn_recovery_add"])
		player._float("seizing", Color(1, 0.5, 0.2))
	if movement:
		# the recovery starts when the movement ends, so the dash itself is not eaten by it
		recovery = maxf(recovery, float(ab.get("dash_time", 0.0)) + (0.0 if bool(ab.get("no_recovery", false)) else GameData.num("combat", "dash_recovery_s")))
	player._recover_t = windup + recovery
	player._melee_cd = maxf(player._melee_cd, windup + recovery)
	# Braced on any skill (a braced word, or a braced skill with no wind-up): for the cast and its recovery
	if bool(ab.get("braced", false)) and windup <= 0.0 and kind != "dash":
		player._brace_t = recovery
	if str(ab.get("self_status", "")) != "":
		_take_state(str(ab["self_status"]), float(ab.get("self_status_s", 2.0)))
	if not movement:
		player._face_dir = player._facing                      # keep facing where it went for a moment, unless you click
		player._face_hold_t = GameData.num("feel", "cast_face_hold_s")

	_lock_if_capped(aff)
	player.combat_part._check_death()


## At reflux lock_at an affinity locks, unless a talent answers the cap (on_reflux_cap).
func _lock_if_capped(aff: String) -> void:
	if reflux_of(aff) < float(player._reflux_cfg["lock_at"]) or is_locked(aff):
		return
	capping_affinity = aff
	for e: TalentEffect in player.effects:
		if e.on_reflux_cap():
			return
	player.locked_by[aff] = true
	player.note("Reflux at %d - %s affinity LOCKED." % [int(player._reflux_cfg["lock_at"]), str(GameData.affinity(aff).get("label", aff)).to_lower()])


## What a skill does when it goes off: at once, or when its wind-up ends (see _tick_windup).
## `blink_to` is the point the skill was aimed at, for the kinds that have one.
func _perform_cast(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, strike_target: Node3D, blink_to: Vector3) -> void:
	if (kind == "targeted_strike" or kind == "chain") and strike_target == null:
		return                                   # whoever it was meant for is gone
	if player._motion_started:
		player._motion_started = false                  # its wind-up started the motion, timed to land now
	else:
		player.motion_part._play_cast_motion(ab, kind, GameData.num("feel", "anim_action_lead_s"))
	player.motion_part._snap_body_now()
	match kind:
		"projectile":
			player.moves_part._fire_projectile(ab, stage_mult, GameData.affinity_color(aff), tags + ["projectile"])
		"melee_burst":
			if float(ab.get("self_harm", 0.0)) > 0.0:     # only a build that earns it; no ability has it by default
				var hurt: float = player.body.apply_self_harm(float(ab["self_harm"]))
				player._float("-%d" % int(hurt), Color(1, 0.4, 0.3))
			player.moves_part._burst(ab, stage_mult, tags if bool(ab.get("not_melee", false)) else tags + ["melee"])
			player._melee_cd = GameData.num("feel", "strike_after_skill_s")      # a melee skill counts as one swing
		"dash":
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			var dir := Vector3(input.x, 0.0, input.y).normalized().rotated(Vector3.UP, ISO_YAW)
			if dir == Vector3.ZERO:
				dir = player._facing
			if bool(ab.get("leap", false)):
				# Downdraft's leap: over bodies to the aimed point (walls and standing stone still stop it), no further
				var aim_to: Vector3 = player.motion_part._cursor_ground() - player.global_position
				aim_to.y = 0.0
				var reach_l: float = minf(float(ab.get("range", 99.0)), float(ab["dash_speed"]) * float(ab["dash_time"]))
				if aim_to.length() > 0.3:
					dir = aim_to.normalized()
					reach_l = minf(reach_l, aim_to.length())
				player._facing = dir
				player._dash_vel = dir * float(ab["dash_speed"])
				player._dash_time = reach_l / float(ab["dash_speed"])
			else:
				player._dash_vel = dir * float(ab["dash_speed"])
				player._dash_time = float(ab["dash_time"])
			if float(ab.get("after_heal_per_s", 0.0)) > 0.0:
				player.combat_part.heal_over(float(ab["after_heal_per_s"]) * float(ab.get("duration", 2.0)), float(ab.get("duration", 2.0)))      # Fresh Stride
			if str(ab.get("dir", "")) == "back":
				player._dash_vel = -player._facing * float(ab["dash_speed"])                       # Forsaken Ground: away from where you aim
			player._dash_pass = ab.get("on_pass", {})
			player._dash_pass_radius = float(ab.get("pass_radius", 1.0))
			player._dash_tags = tags
			player._dash_passed.clear()
			player._dash_from = player.global_position
			player._dash_start = player.global_position
			player._dash_trail = ab.get("trail", {})
			player._dash_stops = bool(ab.get("stops_at_bodies", false))
			player._dash_braced = bool(ab.get("braced", false))
			player._dash_on_stop = ab.get("on_stop", {})
			player._dash_heavy_poise = float(ab.get("heavy_poise", 0.0))
			player._dash_color = GameData.affinity_color(aff)
			player._dash_on_arrive = ab.get("on_arrive", {})
			player._dash_arrive_radius = float(ab.get("arrive_radius", 1.5))
			player._dash_pass_armoured = bool(ab.get("pass_armoured", false))
			player._dash_ab = ab
			player._dash_stage_mult = stage_mult
			if bool(ab.get("pass_armoured", false)):
				player._dash_stops = true                     # bare bodies stop it; armoured ones it punches through (_body_ahead)
			# blood pools along the way carry you further (Thinblood Rush)
			if float(ab.get("pool_bonus_m", 0.0)) > 0.0:
				var crossed: int = player.world_part._pools_along(player.global_position, player.global_position + dir * float(ab["dash_speed"]) * float(ab["dash_time"]))
				crossed = mini(crossed, int(ab.get("pool_bonus_max", 2)))
				player._dash_time += float(ab["pool_bonus_m"]) * float(crossed) / float(ab["dash_speed"])
			# what it leaves where it started: a phantom of you, a little cloud
			if ab.has("leave_decoy"):
				player.world_part._leave_lure(player.global_position, ab["leave_decoy"], aff, tags)
			if ab.has("leave_zone") and str((ab["leave_zone"] as Dictionary).get("at", "start")) == "start":
				player.hits_part.lay_cloud(player.global_position, ab["leave_zone"], tags + ["cloud"])
			if float(ab.get("after_speed_mult", 0.0)) > 0.0:
				player.buffs["after_" + str(ab.get("name", "dash")).to_lower()] = {"t": float(ab.get("duration", 2.0)) + float(ab["dash_time"]), "move_speed_mult": float(ab["after_speed_mult"])}
			if player.motion_part.has_slipstream():
				player.pips = mini(GameData.inum("slipstream", "max"), player.pips + int(ab.get("gain_pips", 0)))
		"beam":
			player.moves_part._fire_beam(ab, stage_mult, GameData.affinity_color(aff), tags)
		"targeted_strike":
			var to_t: Vector3 = strike_target.global_position - player.global_position
			to_t.y = 0.0
			if to_t.length() > 0.2:
				player._facing = to_t.normalized()
			player._strike_t = 0.25
			player.combat_part._swing_visual(to_t.length() + 0.4, true, true)
			var strike_payload: Dictionary = player.hits_part._payload(ab, "on_hit")
			var strike_tags: Array = tags + ["melee"]
			if bool(ab.get("force_rear", false)):
				strike_tags.append("rear")              # it lands on the back whichever way they were facing
			if ab.has("pip_mult"):
				var burned: int = player.motion_part.spend_pips(-1 if bool(ab.get("spend_all_pips", false)) else int(ab.get("spend_pips", 0)))
				strike_payload["damage_mult"] = float(strike_payload.get("damage_mult", 1.0)) * (1.0 + float(ab["pip_mult"]) * float(burned))
			if bool(ab.get("through", false)):
				# cut through: you end up behind them, unless something solid is there
				var beyond: Vector3 = strike_target.global_position + player._facing * (float(ab.get("through_dist", 2.0)) + float(strike_target.get("radius")))
				beyond.y = player.global_position.y
				var blocked: Dictionary = _ray(player.global_position + Vector3.UP, beyond + Vector3.UP)
				_line_visual(player.global_position + Vector3.UP, (blocked["position"] if not blocked.is_empty() else beyond + Vector3.UP), GameData.affinity_color(aff))
				if blocked.is_empty():
					player.global_position = beyond
				player.has_move_goal = false
				player.attack_target = null
			var spent: int = 0
			if str(strike_payload.get("execute_needs", "")) != "":
				strike_payload["execute_had"] = bool(strike_target.call("has_status", str(strike_payload["execute_needs"])))
			if ab.has("consume_status") and strike_target.has_method("status_stacks"):
				# cash in what is already on the target: each stack spent adds to the blow, and it bursts
				spent = int(strike_target.call("status_stacks", str(ab["consume_status"]))) if bool(strike_target.call("has_status", str(ab["consume_status"]))) else 0
				for alt: String in (ab.get("consume_counts", {}) as Dictionary):
					if bool(strike_target.call("has_status", alt)):
						spent = maxi(spent, int(ab["consume_counts"][alt]))     # Waterlogged counts as two Soaks
						strike_target.call("clear_status", alt)
				if spent > 0:
					strike_target.call("clear_status", str(ab["consume_status"]))
					player.combat_part.deal_damage(strike_target, float(ab.get("per_stack_damage", 0.0)) * float(spent) * stage_mult, tags + ["melee", "burst"])
			var sp_metal: int = int(strike_target.call("metal_class")) if strike_target.has_method("metal_class") else 0
			var sp_at: Vector3 = strike_target.global_position
			if spent > 0 and strike_payload.get("on_kill") is Dictionary and int((strike_payload["on_kill"] as Dictionary).get("blood_per_stack", 0)) > 0:
				var ok2: Dictionary = (strike_payload["on_kill"] as Dictionary).duplicate()
				ok2["blood"] = int(ok2.get("blood", 0)) + int(ok2["blood_per_stack"]) * spent     # Last Draught: more for every stack it drank
				strike_payload["on_kill"] = ok2
			if is_instance_valid(strike_target) and not bool(strike_target.call("is_dead")):
				player.hits_part.apply_hit(strike_target, strike_payload, strike_tags, stage_mult)
			if ab.get("spall") is Dictionary and sp_metal > 0:
				# Splitting Blow: the armour it splits flies off into whoever stands near, per class of metal it wore
				var spl: Dictionary = ab["spall"]
				for o: Node3D in _enemies_near(sp_at, float(spl.get("radius", 2.5))):
					if o != strike_target:
						player.combat_part.deal_damage(o, float(spl.get("damage_per_class", 30.0)) * float(sp_metal) * stage_mult, tags + ["spall"])
			if int(ab.get("swallow_per_hit", 0)) > 0:
				player.hits_part.store_add("swallowed", int(ab["swallow_per_hit"]), 5, 12.0)       # Hungry Dark swallows the light it strikes
			if ab.get("zone") is Dictionary:
				player.world_part._lay_ground(ab["zone"], 2.0, ab, tags)                            # and leaves dark ground at your feet
			if (spent > 0 or bool(ab.get("burst_always", false))) and ab.has("burst"):
				var centre: Vector3 = strike_target.global_position if is_instance_valid(strike_target) else player.global_position + player._facing * 1.5
				for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
					var near: Enemy = node
					var self_too: bool = bool(ab.get("burst_always", false))      # Thunderclap's crack takes the target too
					if near != null and (near != strike_target or self_too) and near.global_position.distance_to(centre) <= float(ab.get("burst_radius", 2.0)) + float(near.radius):
						player.hits_part.apply_hit(near, ab["burst"], tags + ["burst"], stage_mult)
			if spent > 0 and ab.has("burst_zone"):
				var bz: Dictionary = (ab["burst_zone"] as Dictionary).duplicate()
				bz["payload"] = bz.get("payload", {"status": "infected"})
				player.hits_part.lay_cloud(strike_target.global_position if is_instance_valid(strike_target) else player.global_position, bz, tags + ["cloud"])
			player._melee_cd = float(player._p["melee_cooldown"])
		"blink":
			player.moves_part._blink(blink_to, ab, stage_mult, GameData.affinity_color(aff), tags)
		"prop":
			player.world_part._raise_prop(blink_to, ab, stage_mult, tags)
		"displace":
			player.moves_part._displace(blink_to, strike_target, ab, stage_mult, tags)
		"delayed_blast":
			player.world_part._start_blast(blink_to, ab, stage_mult, tags)
		"detonate":
			player.world_part._detonate(ab, stage_mult, tags, strike_target)
		"ground_zone":
			player.world_part._lay_zone(blink_to, ab, stage_mult, tags)
			if bool(ab.get("drops_aggro", false)):
				# Pall: everyone coming for you loses you (as when Unseen begins) and gives up its place at your side
				for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
					if node.target == player:
						node.interrupt()
						player.combat_part.release_slot(node)
		"self_buff":
			_take_buff(ab)
		"rod":
			player.world_part._plant_rod(blink_to, ab)
		"chain":
			player.moves_part._chain(strike_target, ab, stage_mult, tags)
		"smite":
			player.moves_part._smite(strike_target, blink_to, ab, stage_mult, tags)
		"summon":
			player.world_part._summon(blink_to, ab, stage_mult, tags)
		"seed":
			player.world_part._sow(blink_to, ab, stage_mult, tags)
		"grapple":
			player.moves_part._grapple(blink_to, ab, stage_mult, tags)
		"streak":
			player.moves_part._streak(ab, stage_mult, tags)
		"field_pulse":
			player.world_part._field_pulse(blink_to, ab, stage_mult, tags)
	if kind != "self_buff" and ab.get("coat") is Dictionary:
		player.combat_part._put_coat(ab)                            # the cast leaves its coat on your weapon (Venom Edge, Steeped Blade)
	if ab.get("conjure_weapon") is Dictionary:
		player.combat_part._conjure(ab)                             # Clotblade, Thirsting Glaive
	_repeat_cast(ab, kind, aff, stage_mult, tags, strike_target, blink_to)


## A sealed word's great ring (design/14 section 8) makes the skill come round again: the same cast,
## at "mult" of its strength, "delay_s" later ("times" in all). Generic: it is the rune patch's
## "rune_repeat" field, read here for any skill; which kinds may repeat is the rule set's data.
func _repeat_cast(ab: Dictionary, kind: String, aff: String, stage_mult: float, tags: Array, strike_target: Node3D, blink_to: Vector3) -> void:
	var rep: Variant = ab.get("rune_repeat")
	if typeof(rep) != TYPE_DICTIONARY or not player.is_inside_tree() or player.get_parent() == null:
		return
	var echo: Dictionary = ab.duplicate(true)
	echo.erase("rune_repeat")                    # the echo itself does not repeat
	var mult: float = float((rep as Dictionary).get("mult", 0.0))
	var delay: float = float((rep as Dictionary).get("delay_s", 0.4))
	var times: int = maxi(1, int((rep as Dictionary).get("times", 1)))
	var target: Node3D = strike_target
	SkillTimer.after(player.get_parent(), delay, func(n: int) -> void:
		if player.dead or not player.is_inside_tree():
			return
		var t: Node3D = target if target != null and is_instance_valid(target) and not bool(target.call("is_dead")) else null
		_perform_cast(echo, kind, aff, stage_mult * pow(mult, float(n + 1)), tags, t, blink_to), times - 1, delay)


## Put an ability on a skill slot. An ability lives on one slot at a time; whatever was in the
## target slot swaps to the slot the ability came from (or leaves the bar if it had none).
func assign_slot(slot: int, ability_index: int) -> void:
	if slot < 0 or slot >= player.hotbar.size() or ability_index < 0 or ability_index >= player.abilities.size():
		return
	var from: int = player.hotbar.find(ability_index)
	var displaced: int = player.hotbar[slot]
	player.hotbar[slot] = ability_index
	if from >= 0 and from != slot:
		player.hotbar[from] = displaced


## Take an ability off the skill bar.
func unassign_ability(ability_index: int) -> void:
	var at: int = player.hotbar.find(ability_index)
	if at >= 0:
		player.hotbar[at] = -1


## Damage multiplier an ability gets from its stage.
func ability_damage_mult(stage: int) -> float:
	return 1.0 + GameData.num("abilities", "stage_damage_bonus") * float(stage)


## Progress is bought with essence spent through the ability, and counts for more when
## something is actually trying to kill you (Brent 2026-09-23). The bar stops at 100: the stage
## only advances when a construct of the matching tier is bound into it (Brent 2026-09-23).
func _advance(state: Dictionary, essence_spent: float) -> void:
	var was_full: bool = float(state["progress"]) >= 100.0
	var use_mult: float = GameData.num("abilities", "use_mult_monster") if player.combat_part._enemy_nearby() else GameData.num("abilities", "use_mult_nothing")
	var gain: float = essence_spent * GameData.num("abilities", "progress_per_essence") * use_mult
	state["progress"] = minf(100.0, float(state["progress"]) + gain)
	if not was_full and float(state["progress"]) >= 100.0:
		player.note("%s is full. It needs a %s bound into it to advance." % [
			str(GameData.ability(str(state["id"])).get("name", "?")), GameData.tier_for_stage(int(state["stage"]))])


## What an ability needs next: "" if its bar is not full (or it is at the stage cap);
## otherwise the construct tier that advances it.
func pending_tier(state: Dictionary) -> String:
	if float(state["progress"]) < 100.0 or int(state["stage"]) >= player.stars + 1:
		return ""
	return GameData.tier_for_stage(int(state["stage"]))


# --- the 2026-10-22 skill kinds (build brief: smite, channel, charge_release, summon, seed, grapple,
# streak, field_pulse; clouds and lures). Every effect on an enemy still goes through apply_hit. ---

## True while a buff keeps your casting and striking quiet (Muffle).
func _cast_is_quiet() -> bool:
	for bid: String in player.buffs:
		if (player.buffs[bid] as Dictionary).has("unaware_mult"):
			return true
	return false


## One of your own short states (statuses.json player_states: Quickened), as a buff.
func _take_state(id: String, seconds: float) -> void:
	var def: Dictionary = GameData.player_state(id)
	var b: Dictionary = def.duplicate()
	b["t"] = seconds
	player.buffs[id] = b
	player._float(str(def.get("label", id)).to_lower(), Color(0.95, 0.95, 1.0))


## The living enemy nearest `point`, within `reach` of it; null if none.
func _nearest_enemy_to(point: Vector3, reach: float) -> Node3D:
	var best: Node3D = null
	for e: Node3D in _enemies_near(point, reach):
		if best == null or Vector2(e.global_position.x - point.x, e.global_position.z - point.z).length() < Vector2(best.global_position.x - point.x, best.global_position.z - point.z).length():
			best = e
	return best


# --- refusals the player can see (combat review R4d, approved by Brent 2026-11-03) -----------------
# A refused cast used to be one line in the corner log. Now it is also recorded here for the HUD, which
# flashes the slot it came from and shows the reason a moment at the cursor (balance.json "hud"
# refusal_show_s / refusal_flash_s). The log line stays as it was.



func _refuse(reason: String, text: String) -> void:
	player.last_refusal = {"serial": int(player.last_refusal.get("serial", 0)) + 1, "slot": player._casting_slot, "reason": reason, "text": text}
	player.cast_refused.emit(player._casting_slot, reason, text)


# --- slow shots lead their foe (combat review R4b, approved by Brent 2026-11-03) --------------------
# A slow projectile flew in a straight line to where the cursor was and missed anything walking (Slingstone
# hit 32% of the time). Now a shot slower than skills.slow_shot_speed is aimed, as it leaves, at where the
# foe nearest its line (within slow_shot_cone_deg of it) will be when it arrives - slow_shot_lead_frac of
# the way - turned at most slow_shot_turn_max_deg from where you aimed. It still flies straight.

## The direction a shot of skill `ab` leaves in, given the way it was aimed.
func lead_aim(ab: Dictionary, aim: Vector3) -> Vector3:
	var cfg: Dictionary = GameData.balance["skills"]
	var speed: float = float(ab.get("speed", 999.0))
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	if speed <= 0.0 or speed >= float(cfg["slow_shot_speed"]) or flat_aim.length() < 0.01 or not player.is_inside_tree():
		return aim
	flat_aim = flat_aim.normalized()
	var reach: float = speed * float(ab.get("life", 1.0))
	var cone: float = deg_to_rad(float(cfg["slow_shot_cone_deg"]))
	var foe: Node3D = null
	var best: float = cone
	for node: Enemy in player.get_tree().get_nodes_in_group("enemies"):
		var e: Enemy = node
		if e == null or bool(e.is_dead()):
			continue
		var to := Vector3(e.global_position.x - player.global_position.x, 0.0, e.global_position.z - player.global_position.z)
		if to.length() < 0.3 or to.length() > reach + float(e.radius):
			continue
		var ang: float = flat_aim.angle_to(to.normalized())
		if ang <= best:
			best = ang
			foe = e
	if foe == null:
		return aim
	var vel := Vector3.ZERO
	if foe is CharacterBody3D:
		vel = (foe as CharacterBody3D).velocity
		vel.y = 0.0
	var at := Vector3(foe.global_position.x, player.global_position.y, foe.global_position.z)
	var ahead: Vector3 = at
	for i: int in 2:                              # where it will be when the shot gets there (twice, to settle)
		ahead = at + vel * (Vector3(ahead.x - player.global_position.x, 0.0, ahead.z - player.global_position.z).length() / speed) * float(cfg["slow_shot_lead_frac"])
	var want := Vector3(ahead.x - player.global_position.x, 0.0, ahead.z - player.global_position.z)
	if want.length() < 0.05:
		return aim
	want = want.normalized()
	var turn: float = flat_aim.signed_angle_to(want, Vector3.UP)
	var cap: float = deg_to_rad(float(cfg["slow_shot_turn_max_deg"]))
	return flat_aim.rotated(Vector3.UP, clampf(turn, -cap, cap))
