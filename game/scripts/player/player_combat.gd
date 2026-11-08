class_name PlayerCombat
extends RefCounted
## The player's part for combat and hits taken and dealt: deal_damage / take_hit (the HitContext + TalentEffect pipeline), strikes, the ranged weapon, ward, coat, counters, wounds, healing.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

const FloatText := preload("res://scripts/float_text.gd")
const Projectile := preload("res://scripts/projectile.gd")

var player: Player

var bot_damage_mult := 25.0
var _regen: Array = []                  # heals over time [{per_s, t}] (life healing order; Life's after-hit rule)
var _hit_recent_t := 0.0                # since you last landed a hit (Life: heals run faster just after)
var _range_ring: MeshInstance3D


# --- the damage pipeline --------------------------------------------------------


func _init(of: Player) -> void:
	player = of


## Deal damage to a hittable node. Every effect sees the hit before and after it lands.
func deal_damage(target: Node, base: float, tags: Array = [], opts: Dictionary = {}) -> HitContext:
	var ctx := HitContext.new()
	ctx.source = player
	ctx.target = target
	ctx.base = base
	for t: String in tags:
		ctx.tags.append(t)
	if not is_instance_valid(target) or bool(target.call("is_dead")):
		ctx.cancelled = true
		return ctx
	ctx.is_living = bool(target.get("is_living"))
	ctx.is_scenery = bool(target.get("is_scenery"))

	for e: TalentEffect in player.effects:
		e.on_outgoing(ctx)
	if player.bot:
		ctx.mult *= bot_damage_mult

	# Heat (design/05 2.2): for an affinity with damage_per_reflux, its own reflux multiplies its damage
	for aff: String in player.affinities:
		if ctx.has_tag(aff):
			var per: float = float(GameData.affinity(aff).get("damage_per_reflux", 0.0))
			if per > 0.0 and not ctx.has_tag("cold"):       # a skill that spends the heat does not also ride it
				# White Heat (heat_scale): the Heat bonus on this hit counts heat_scale times
				ctx.mult *= 1.0 + (player.heat_mult(aff) - 1.0) * float(opts.get("heat_scale", 1.0))
	player._affinity_rules(ctx, target)
	if ctx.cancelled:
		return ctx
	var pos: Vector3 = (target as Node3D).global_position
	var combat: Dictionary = GameData.balance["combat"]
	var bare_strike: bool = ctx.has_tag("melee") and not ctx.has_tag("ability")
	var from_behind: bool = ctx.has_tag("rear") or (target.has_method("is_behind") and bool(target.call("is_behind", player.global_position)))
	if from_behind:
		# Lee (wind): a hit from this affinity on a back does more again
		for aff: String in player.affinities:
			if ctx.has_tag(aff):
				ctx.mult *= 1.0 + float(GameData.affinity(aff).get("rear_bonus", 0.0))
	# Ambush (Dark's rule, ambush_mult): your first hit out of Unseen counts as from behind and past the guard, and more
	if not ctx.has_tag("dot") and not ctx.is_scenery and (player._hidden() or player._cast_hidden_t > 0.0):
		var amb := 1.0
		for aff2: String in player.affinities:
			amb = maxf(amb, float(GameData.affinity(aff2).get("ambush_mult", 1.0)))
		if amb > 1.0:
			ctx.mult *= amb
			from_behind = true
			if not ctx.has_tag("through"):
				ctx.tags.append("through")
			FloatText.spawn(player.get_parent(), (target as Node3D).global_position + Vector3.UP * 0.9, "AMBUSH", GameData.affinity_color("dark").lightened(0.4))
			player._cast_hidden_t = 0.0
			for vid: String in player.buffs.keys():
				if bool((player.buffs[vid] as Dictionary).get("ends_on_hit", false)) and bool((player.buffs[vid] as Dictionary).get("unseen_anywhere", false)):
					player.buffs.erase(vid)              # Vanished: your hit ends it
	var opening: bool = bare_strike and target.has_method("has_status") and bool(target.call("has_status", "staggered"))
	if from_behind:
		ctx.mult *= float(combat["rear_mult"])           # where you stand matters, for every affinity
	if opening:
		ctx.mult *= float(combat["opening_mult"])        # the reason to click one enemy instead of casting again
	ctx.applied = target.call("take_hit", ctx.amount(), ctx.heavy, player, Array(ctx.tags))
	if not ctx.has_tag("dot"):
		player._after_landing(ctx, target)
	if ctx.applied <= 0.0:
		return ctx
	if not ctx.is_scenery and ctx.has_tag("melee") and not ctx.has_tag("dot"):
		player.motion_part._impact_feedback(target, ctx.has_tag("overcharge") or ctx.has_tag("ability") or bool(target.call("is_dead")))
	if not ctx.is_scenery:
		FloatText.spawn(player.get_parent(), pos, "%d" % int(ctx.applied), Color(1, 0.86, 0.45) if opening else (Color(0.75, 0.95, 1.0) if from_behind else Color(1, 1, 1)))
		if opening:
			FloatText.spawn(player.get_parent(), pos + Vector3.UP * 0.5, "OPENING", Color(1, 0.86, 0.45))
		elif from_behind:
			FloatText.spawn(player.get_parent(), pos + Vector3.UP * 0.5, "back", Color(0.75, 0.95, 1.0))
	_hit_recent_t = _after_hit_s()
	if not ctx.has_tag("dot"):
		var regrow: float = 0.0
		for bid: String in player.buffs:
			regrow += float((player.buffs[bid] as Dictionary).get("heal_per_hit", 0.0))       # Overgrowth
		for s: Node3D in player.summons_near(player.global_position, 999.0):
			regrow += float(s.get("heal_per_hit"))                                    # a Heartseed at your side
		if regrow > 0.0:
			life_heal(regrow)
	if ctx.has_meta("seared") and target.has_method("add_status") and not bool(target.call("is_dead")):
		target.call("add_status", "lit", 1, player)          # the Sear refreshes the Lit
	if _edge_counts(ctx):
		_edge_heat(target)
	if target.has_method("status_sum_by"):
		# what the target carries in your name pays you back on every hit you land (Tithed heals, Leeched drains)
		var tithe: float = float(target.call("status_sum_by", "heals_attacker_frac", player))
		if tithe > 0.0:
			life_heal(ctx.applied * tithe)
		var leech: float = float(target.call("status_sum_by", "drain_to_source", player))
		if leech > 0.0:
			drain_heal(ctx.applied * leech, target, true)
		# Condemned: every hit on it from you or yours adds to your ward, at most ward_from_one from one body
		var cond: Array = target.call("status_from", "ward_to_attacker", player)
		if not cond.is_empty() and not ctx.has_tag("dot"):
			var cdef: Dictionary = GameData.status(str(cond[0]))
			var entry: Dictionary = cond[1]
			var room: float = float(cdef.get("ward_from_one", INF)) - float(entry.get("warded", 0.0))
			var got: float = add_ward(minf(float(cdef["ward_to_attacker"]), room), -1.0, {"from": "condemned"})
			entry["warded"] = float(entry.get("warded", 0.0)) + got
	ctx.killed = bool(target.call("is_dead"))
	if bare_strike and not ctx.is_scenery:
		# working it off: every strike that lands bleeds a little heat from your hottest affinity
		var hottest := ""
		for aff: String in player.reflux_by:
			if hottest == "" or float(player.reflux_by[aff]) > float(player.reflux_by[hottest]):
				hottest = aff
		if hottest != "":
			player.reflux_by[hottest] = maxf(0.0, float(player.reflux_by[hottest]) - float(combat["strike_sheds_reflux"]))
		# gathering (combat review R1): raw essence manipulation - a landed strike draws a little in, never past the tank
		player.essence = minf(player.essence_max, player.essence + float(combat["strike_gathers_essence"]))
		if not ctx.killed and target.has_method("take_poise"):
			target.call("take_poise", float(combat["strike_poise"]) * (2.0 if ctx.has_tag("overcharge") else 1.0) * player.buff_num("strike_poise_mult") * float(conjured().get("melee_poise_mult", 1.0)))
		if not ctx.killed and conjured().get("on_strike") is Dictionary:
			_conjured_strike(target, conjured()["on_strike"])
		if not ctx.killed and target.has_method("add_status"):
			for bid: String in player.buffs:
				if str((player.buffs[bid] as Dictionary).get("strike_status", "")) != "":
					target.call("add_status", str(player.buffs[bid]["strike_status"]), 1, player)      # Benediction: your blows leave them Lit
			player._try_shatter(target, INF)                                  # a bare strike is a hard hit
	# a weapon coat (v2: Stoke, Red Iron, Static Coat, Venom Edge...): what lands with your weapon carries it -
	# a bare strike, a ranged-weapon shot, or a skill made with the weapon
	if not ctx.killed and not ctx.is_scenery and (bare_strike or ctx.has_tag("ranged") or ctx.has_tag("weapon")) \
			and not ctx.has_tag("coat") and not ctx.has_tag("dot") and not ctx.has_tag("burst") and not ctx.has_tag("arc"):
		_apply_coats(target)

	for e: TalentEffect in player.effects:
		e.on_dealt(ctx)
	if ctx.killed:
		player.progress_part._on_kill(target)
	return ctx


## Receive a hit. Effects may scale it or swallow it (ctx.cancelled).
func take_hit(amount: float, heavy: bool, source: Node, _tags: Array = []) -> float:
	if player.dead or player.bot:
		return 0.0
	var ctx := HitContext.new()
	ctx.source = source
	ctx.target = player
	# What the body and what it wears take off the blow comes first, so every talent works on
	# the same reduced number - including one that swallows the hit and delivers it later.
	ctx.base = amount * player.progress_part.temper_stat("incoming_mult") * (1.0 - armour() / 100.0) * player.buff_num("incoming_mult") * player._inured_mult()
	var braced: bool = player.is_braced()
	if braced:
		ctx.base *= GameData.num("braced", "damage_taken_mult")
	if _try_counter(source):
		return 0.0
	ctx.base *= player.ally_zone_mult(player)
	# a buff that softens blows and keeps what it softened (Kind Light's softened_return, paid back when it ends)
	var unsoftened: float = amount * player.progress_part.temper_stat("incoming_mult") * (1.0 - armour() / 100.0) * player._inured_mult()
	for sid: String in player.buffs:
		var sb: Dictionary = player.buffs[sid]
		if float(sb.get("softened_return", 0.0)) > 0.0:
			sb["softened"] = float(sb.get("softened", 0.0)) + unsoftened * maxf(0.0, 1.0 - float(sb.get("incoming_mult", 1.0)))
	# a blow thrown from arm's length, as against a shot that left its owner far behind
	var melee_from: Node3D = source as Node3D if (source is Node3D and (source as Node).is_in_group("enemies") and (source as Node3D).global_position.distance_to(player.global_position) <= 4.5) else null
	if melee_from != null and player.buffs.has("backwash"):
		var wash: Dictionary = player.buffs["backwash"]
		ctx.base *= float(wash.get("melee_taken_mult", 0.5))
		# the splash: whoever threw the blow, and everyone close to you, takes the payload
		var splash: Dictionary = wash.get("on_hit", {"shove": float(wash.get("shove", 3.0)), "status": "soaked"})
		var wet: Array[Node3D] = player._enemies_near(player.global_position, float(wash.get("radius", 0.0)))
		if not wet.has(melee_from):
			wet.append(melee_from)
		for e: Node3D in wet:
			player.apply_hit(e, splash, ["ability", "water", "backwash"], 1.0, e.global_position - player.global_position)
		wash["hits"] = int(wash.get("hits", 1)) - 1
		if int(wash["hits"]) <= 0:
			player.buffs.erase("backwash")
	if melee_from != null:
		for bid: String in player.buffs.keys():
			var b: Dictionary = player.buffs[bid]
			if str(b.get("attacker_status", "")) != "" and is_instance_valid(melee_from) \
					and melee_from.global_position.distance_to(player.global_position) <= float(b.get("attacker_reach", INF)) + float(melee_from.get("radius")):
				melee_from.call("add_status", str(b["attacker_status"]), 1, player, {"lasts": float(b.get("attacker_status_s", 3.0))})
	if melee_from != null:
		# a buff that answers a blow (Static Coat's retaliate): damage, and its coat's payload on whoever threw it
		for rid: String in player.buffs.keys():
			var rb: Dictionary = player.buffs.get(rid, {})
			if float(rb.get("retaliate", 0.0)) > 0.0 and is_instance_valid(melee_from) and not bool(melee_from.call("is_dead")):
				deal_damage(melee_from, float(rb["retaliate"]), ["ability", str(rb.get("affinity", "")), "retaliate"])
				var rcoat: Variant = rb.get("coat")
				if rcoat is Dictionary and is_instance_valid(melee_from) and not bool(melee_from.call("is_dead")):
					player.apply_hit(melee_from, _coat_payload(rcoat as Dictionary), ["coat", str(rb.get("affinity", ""))])
	ctx.heavy = heavy
	# the ward takes the blow first (after armour and tempering, before talents); a blow it wholly stops opens no
	# wound and costs no poise
	var shrouded: bool = _ward_flag("no_stagger")
	if ward() > 0.0 and ctx.base > 0.0:
		ctx.base = _ward_takes(ctx.base)
		if ctx.base <= 0.0:
			player._float("warded", Color(1.0, 0.95, 0.75))
			return 0.0
	if player.projecting:
		player.disturbed.emit()             # pain drags the soul back before the blow is even counted
	player._meditate_block = 1.0
	player.meditating = false
	if not player._held.is_empty() and bool((player._held["ab"] as Dictionary).get("breaks_on_hit", false)):
		player._end_held()
	elif not player._held.is_empty() and float((player._held["ab"] as Dictionary).get("pause_on_hit_s", 0.0)) > 0.0:
		player._held["paused"] = float((player._held["ab"] as Dictionary)["pause_on_hit_s"])        # Regrowth: a blow stops it a moment
	for e: TalentEffect in player.effects:
		e.on_incoming(ctx)
	if ctx.cancelled:
		return 0.0
	if heavy:
		player.motion_part._kick(Vector3.ZERO, GameData.num("feel", "camera_kick_hurt_m"), source)
	if heavy and not braced and not shrouded and not player._buff_flag("immovable"):   # set, shrouded or a millstone: nothing knocks you off it
		var combat: Dictionary = GameData.balance["combat"]
		var green_poise: float = float(player.green_rule().get("poise_loss_mult", 1.0)) if player.in_the_green() else 1.0
		player.poise -= float(combat["heavy_poise_damage"]) * player.buff_num("poise_loss_mult") * green_poise / maxf(0.01, player.buff_num("poise_mult"))
		if player.poise <= 0.0 and _turn_away():
			player.poise = float(combat["player_poise"])     # Absolution: the stagger is turned away
		if player.poise <= 0.0:
			player.poise = float(combat["player_poise"])
			player._stagger_t = float(combat["player_stagger_s"])
			player._dash_time = 0.0
			player.motion_part._end_step()                           # knocked off your feet mid-step: the step is over
			player._windup = {}                          # whatever you were winding up is lost
			player._windup_t = 0.0
			player._motion_started = false
			player.has_move_goal = false                 # and whatever you meant to do next
			player.attack_target = null
			player.pickup_target = null
			player._buffered_slot = -1
			player._float("STAGGERED", Color(1, 0.7, 0.3))
	return _apply_damage(ctx.amount(), heavy)


## What a conjured weapon adds to each bare strike (on_strike): its payload through apply_hit; consume_stacks takes
## that many stacks off and gives blood_per_take held blood for each (Thirsting Glaive drinks the Bleeding).
func _conjured_strike(target: Node, on_strike: Dictionary) -> void:
	var p: Dictionary = on_strike.duplicate()
	var take: Dictionary = p.get("consume_stacks", {})
	p.erase("consume_stacks")
	var per: int = int(p.get("blood_per_take", 0))
	p.erase("blood_per_take")
	for st: String in take:
		if bool(target.call("has_status", st)):
			var left: int = int(target.call("status_stacks", st)) - int(take[st])
			var entry: Dictionary = (target.get("statuses") as Dictionary).get(st, {})
			if left <= 0:
				target.call("clear_status", st)
			elif not entry.is_empty():
				entry["stacks"] = left
			player.gain_blood(per * int(take[st]))
	if not p.is_empty():
		player.apply_hit(target, p, ["ability", str(conjured().get("affinity", "")), "conjured"])


# --- Edge Heat (metal.json, Metal's rule; a player-side count like Slipstream's pips) -----------------------

func _focus_max() -> int:
	var m := 0
	for aff: String in player.affinities:
		m = maxi(m, int(GameData.affinity(aff).get("focus_max", 0)))
	return m


func _focus_cools() -> float:
	var s := 0.0
	for aff: String in player.affinities:
		s = maxf(s, float(GameData.affinity(aff).get("focus_cools_s", 0.0)))
	return s


## True if this hit is a metal blow that counts for Edge Heat: tagged with an affinity that has focus_max, and not a
## side-effect (spall, bursts, arcs, ticks, zones).
func _edge_counts(ctx: HitContext) -> bool:
	for t2: String in ["dot", "burst", "arc", "spall", "zone", "coat", "aura", "shard"]:
		if ctx.has_tag(t2):
			return false
	for aff: String in player.affinities:
		if ctx.has_tag(aff) and GameData.affinity(aff).has("focus_max"):
			return true
	return false


## A metal blow landed on `target`: on the same one as the last it adds one (up to focus_max), on another it starts
## again at 1 (or full, after Red Iron); the cooling clock starts over.
func _edge_heat(target: Node) -> void:
	if player._focus_fill_next:
		player._focus_fill_next = false
		player._focus_target = target
		player.focus = _focus_max()
	elif target == player._focus_target:
		player.focus = mini(_focus_max(), player.focus + 1)
	else:
		player._focus_target = target
		player.focus = 1
	player._focus_t = _focus_cools()


# --- the ward pool (v2, one mechanic: holy.json Dawnward, water.json crush_ward, ice.json Ice Shell, unholy.json Black Shroud) ---

## What the pool holds now.
func ward() -> float:
	var w := 0.0
	for p: Dictionary in player.ward_parts:
		w += float(p["amount"])
	return w


## Add up to `amount` of ward lasting `lasts` s (default balance.json ward.default_lasts), never above the one cap;
## `opts`: from (who gave it), source_cap (the most this source may hold at once: Water's Crush ward), on_break
## (a payload round you when a blow empties the pool), expire_heal_frac, no_stagger. Returns what was added.
func add_ward(amount: float, lasts: float = -1.0, opts: Dictionary = {}) -> float:
	var room: float = GameData.num("ward", "cap") - ward()
	if opts.has("source_cap"):
		var mine := 0.0
		for p: Dictionary in player.ward_parts:
			if str(p.get("from", "")) == str(opts.get("from", "")):
				mine += float(p["amount"])
		room = minf(room, float(opts["source_cap"]) - mine)
	var add: float = minf(amount, room)
	if add <= 0.0:
		return 0.0
	var part: Dictionary = opts.duplicate()
	part["amount"] = add
	part["t"] = lasts if lasts > 0.0 else GameData.num("ward", "default_lasts")
	player.ward_parts.append(part)
	return add


## True if a part of the pool carries flag `key` (Black Shroud's no_stagger).
func _ward_flag(key: String) -> bool:
	for p: Dictionary in player.ward_parts:
		if bool(p.get(key, false)):
			return true
	return false


## The pool takes `amount`, oldest part first; returns what is left for the bar. A blow that empties it sets off
## the spent parts' own on_break, or else your affinities' ward_break_payload (Holy's rule).
func _ward_takes(amount: float) -> float:
	var left: float = amount
	var breaks: Array = []
	while left > 0.0 and not player.ward_parts.is_empty():
		var p: Dictionary = player.ward_parts[0]
		var took: float = minf(left, float(p["amount"]))
		p["amount"] = float(p["amount"]) - took
		left -= took
		if float(p["amount"]) <= 0.0001:
			player.ward_parts.pop_front()
			if p.has("on_break"):
				breaks.append(p)
	if player.ward_parts.is_empty():
		if breaks.is_empty():
			for aff: String in player.affinities:
				var rule: Dictionary = GameData.affinity(aff).get("ward_break_payload", {})
				if not rule.is_empty():
					breaks.append({"on_break": rule, "on_break_tags": ["ability", aff, "ward"]})
		for b: Dictionary in breaks:
			FloatText.spawn(player.get_parent(), player.global_position + Vector3.UP * 1.2, "WARD BREAKS", Color(1.0, 0.95, 0.7))
			player._burst_at(player.global_position, b["on_break"], b.get("on_break_tags", ["ability", "ward"]))
	return left


## Ward parts run out; one that runs out unspent may give part of itself back as health (Dawnward).
func _tick_ward(delta: float) -> void:
	for p: Dictionary in player.ward_parts.duplicate():
		p["t"] = float(p["t"]) - delta
		if float(p["t"]) <= 0.0:
			player.ward_parts.erase(p)
			if float(p.get("expire_heal_frac", 0.0)) > 0.0:
				life_heal(float(p["amount"]) * float(p["expire_heal_frac"]))


## Heal by Life's order (balance.json life_healing): the bar up to what wounds allow, then a share of the rest into
## the oldest natural wound. Nothing while healing is refused. Returns what reached the bar.
func life_heal(points: float) -> float:
	if points <= 0.0 or player._heal_blocked():
		return 0.0
	var used: float = player.body.heal(points)
	if points - used > 0.0:
		var filled: Dictionary = player.body.fill_sinks((points - used) * GameData.num("life_healing", "sink_frac"), true)
		_wounds_closed(filled["closed"])
	var to_poise := 0.0
	for bid: String in player.buffs:
		to_poise = maxf(to_poise, float((player.buffs[bid] as Dictionary).get("heal_to_poise", 0.0)))
	if to_poise > 0.0:
		player.poise = minf(float(GameData.num("combat", "player_poise")), player.poise + used * to_poise)       # Corded Muscle
	return used


## Regrow `points` over `seconds` (Life's heals over time; faster just after you land a hit, Life's rule).
func heal_over(points: float, seconds: float) -> void:
	if points > 0.0 and seconds > 0.0:
		_regen.append({"per_s": points / seconds, "t": seconds})


## How much faster a heal over time runs now: Life's heal_mult_after_hit for after_hit_s after you land a hit.
func heal_rate_mult() -> float:
	if _hit_recent_t <= 0.0:
		return 1.0
	var m := 1.0
	for aff: String in player.affinities:
		m = maxf(m, float(GameData.affinity(aff).get("heal_mult_after_hit", 1.0)))
	return m


func _after_hit_s() -> float:
	var s := 0.0
	for aff: String in player.affinities:
		s = maxf(s, float(GameData.affinity(aff).get("after_hit_s", 0.0)))
	return s


func _tick_regen(delta: float) -> void:
	_hit_recent_t -= delta
	for r: Dictionary in _regen.duplicate():
		var step: float = minf(delta, float(r["t"]))
		r["t"] = float(r["t"]) - delta
		life_heal(float(r["per_s"]) * step * heal_rate_mult())
		if float(r["t"]) <= 0.0:
			_regen.erase(r)


## A drain (Unholy's rule, Leeched, Torment's ticks): heals the bar only - never a wound's sink, so it is not talent
## healing - and banks every point it heals or would have healed as stolen life (the affinity's "stolen" store).
func drain_heal(amount: float, _from: Node = null, _capped: bool = true) -> float:
	if amount <= 0.0:
		return 0.0
	var healed: float = 0.0 if player._heal_blocked() else player.body.heal(amount)
	for aff: String in player.affinities:
		var st: Dictionary = GameData.affinity(aff).get("stolen", {})
		if not st.is_empty():
			player.store_add("stolen", int(round(amount)), int(st.get("max", 100)), float(st.get("fade_s", 12.0)))
	return healed


# --- the weapon coat (v2, one mechanic: fire.json Stoke's coat, poison.json Venom Edge's strike_payload) ---------

## A coat's payload: {payload} or {strike_payload} (the drafts use both names for the one thing).
static func _coat_payload(coat: Dictionary) -> Dictionary:
	return coat.get("payload", coat.get("strike_payload", {}))


## Put a coat on your weapon from skill `ab` (its "coat" key). One coat per affinity: a new one replaces that
## affinity's old one (another affinity's coat is separate). A self buff carries its coat itself (it rides in
## the buff); any other skill puts on a coat of its own for coat.duration.
func _put_coat(ab: Dictionary, holder: String = "") -> void:
	var coat: Variant = ab.get("coat")
	if not (coat is Dictionary):
		return
	var aff: String = str(ab.get("affinity", ""))
	for bid: String in player.buffs.keys():
		var b: Dictionary = player.buffs[bid]
		if bid != holder and b.get("coat") is Dictionary and str(b.get("affinity", "")) == aff:
			if bool(b.get("coat_only", false)):
				player.buffs.erase(bid)
			else:
				b.erase("coat")
	var c: Dictionary = (coat as Dictionary).duplicate(true)
	if int(c.get("charges", 0)) > 0:
		c["charges_left"] = int(c["charges"])
	if holder != "" and player.buffs.has(holder):
		(player.buffs[holder] as Dictionary)["coat"] = c
		return
	player.buffs["coat_" + aff] = {"t": float(c.get("duration", ab.get("duration", 6.0))), "coat": c, "affinity": aff, "coat_only": true,
		"name": str(ab.get("name", ""))}


## What lands with your weapon carries every coat on it, through apply_hit; a coat with charges spends one
## (not while a buff with coat_free is on you) and is gone when they are.
func _apply_coats(target: Node) -> void:
	for bid: String in player.buffs.keys():
		if not player.buffs.has(bid):
			continue
		var b: Dictionary = player.buffs[bid]
		var coat: Variant = b.get("coat")
		if not (coat is Dictionary) or _coat_payload(coat as Dictionary).is_empty():
			continue
		if not is_instance_valid(target) or bool(target.call("is_dead")):
			return
		player.apply_hit(target, _coat_payload(coat as Dictionary), ["coat", str(b.get("affinity", ""))])
		var c: Dictionary = coat
		if c.has("charges_left") and not player._buff_flag("coat_free"):
			c["charges_left"] = int(c["charges_left"]) - 1
			if int(c["charges_left"]) <= 0:
				if bool(b.get("coat_only", false)):
					player.buffs.erase(bid)
				else:
					b.erase("coat")


## True while enemy shots turn aside from you.
func deflects_shots() -> bool:
	return deflect_radius() > 0.0


## How close a shot may pass before it curves away (Crosswind Veil's deflect_radius), 0 when none does.
func deflect_radius() -> float:
	var r := 0.0
	for id: String in player.buffs:
		r = maxf(r, float((player.buffs[id] as Dictionary).get("deflect_radius", 0.0)))
	return r


## A shot turned aside: a buff may pay pips for it (gain_pips_per_deflect).
func shot_deflected() -> void:
	var n := 0
	for id: String in player.buffs:
		n += int((player.buffs[id] as Dictionary).get("gain_pips_per_deflect", 0))
	if n > 0 and player.motion_part.has_slipstream():
		player.pips = mini(GameData.inum("slipstream", "max"), player.pips + n)


## A counter window (Abiding Guard, Turning Palm, Turn the Edge - one mechanic): the first blow from an enemy that
## would land while it is open is refused whole (no damage, poise or wound); one thrown from within counter_reach
## is answered - you move behind_dist behind the attacker first (Turning Palm), the counter payload lands (from
## behind with force_rear), a burst round you, Edge Heat on the attacker (focus_gain), pips, a ward
## (counter_ward). A shot from beyond reach is refused only by a counter with refuses_shots. Then the window ends.
func _try_counter(source: Node) -> bool:
	if not (source is Node3D) or not (source as Node).is_in_group("enemies"):
		return false
	for id: String in player.buffs.keys():
		var b: Dictionary = player.buffs[id]
		if not b.has("window_s") or not (b.get("counter") is Dictionary):
			continue
		var foe := source as Node3D
		var close: bool = foe.global_position.distance_to(player.global_position) <= float(b.get("counter_reach", 3.0)) + float(foe.get("radius"))
		if not close and not bool(b.get("refuses_shots", false)):
			continue
		b["countered"] = true
		player.buffs.erase(id)
		player._float("countered", Color(1.0, 0.95, 0.8))
		if not close:
			return true
		var aff: String = str(b.get("affinity", ""))
		var tags: Array = ["ability", aff, id, "counter"]
		if float(b.get("behind_dist", 0.0)) > 0.0:
			var back: Vector3 = -(foe.get("facing") as Vector3) if foe.get("facing") is Vector3 else (foe.global_position - player.global_position).normalized()
			back.y = 0.0
			var spot: Vector3 = foe.global_position + back.normalized() * (float(foe.get("radius")) + float(b["behind_dist"]))
			var way: Vector3 = spot - player.global_position
			way.y = 0.0
			player.move_and_collide(way)                # swept: as far as the space allows
			var face: Vector3 = foe.global_position - player.global_position
			face.y = 0.0
			if face.length() > 0.1:
				player._facing = face.normalized()
		if bool(b.get("force_rear", false)):
			tags.append("rear")
		player.apply_hit(foe, b["counter"], tags, 1.0)
		if b.get("burst") is Dictionary:
			var bb: Dictionary = (b["burst"] as Dictionary).duplicate()
			bb["burst_radius"] = float(b.get("burst_radius", 2.0))
			player._burst_at(player.global_position, bb, tags, 1.0, foe)
		if int(b.get("focus_gain", 0)) > 0 and is_instance_valid(foe):
			if player._focus_target != foe:
				player._focus_target = foe
				player.focus = 0
			player.focus = mini(_focus_max(), player.focus + int(b["focus_gain"]))
			player._focus_t = _focus_cools()
		if int(b.get("gain_pips", 0)) > 0 and player.motion_part.has_slipstream():
			player.pips = mini(GameData.inum("slipstream", "max"), player.pips + int(b["gain_pips"]))
		if float(b.get("counter_ward", 0.0)) > 0.0:
			add_ward(float(b["counter_ward"]), -1.0, {"from": id})
		return true
	return false


## --- wind-ups, Braced and standing stone (earth, design/05 2.3) ---------------------------------

## An enemy's blow throws you `metres` along `dir`. Not if you are Braced.
func shove(dir: Vector3, metres: float) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if player.dead or player.bot or player.is_braced() or player._buff_flag("immovable") or flat.length() < 0.001 or metres <= 0.0:
		return
	if _turn_away():
		return                                  # Absolution turns a hold away
	if player.in_the_green():
		metres *= float(player.green_rule().get("shove_mult", 1.0))
	player._shoved_dir = flat.normalized()
	player._shoved_left = metres
	player._dash_time = 0.0
	player.motion_part._end_step()
	player.has_move_goal = false


## Absolution (turns_away): a buff that refuses the next holds that would land on you. Spends one; true if it did.
func _turn_away() -> bool:
	for bid: String in player.buffs:
		var b: Dictionary = player.buffs[bid]
		if int(b.get("turns_away", 0)) > 0:
			b["turns_away"] = int(b["turns_away"]) - 1
			player._float("turned away", Color(1.0, 0.95, 0.8))
			return true
	return false


## True while a heavy blow has you off your feet: you cannot move, strike or cast.
func is_staggered() -> bool:
	return player._stagger_t > 0.0


# --- the slot ring (design/05 6.2) ----------------------------------------------------------

## An enemy asks for one of the places in striking range of you. Granted if it already has one
## or one is free; the rest must wait their turn a few metres out.
func claim_slot(enemy: Node) -> bool:
	for i: int in range(player._ring.size() - 1, -1, -1):
		var held: Variant = player._ring[i]
		if not is_instance_valid(held) or bool((held as Node).call("is_dead")):
			player._ring.remove_at(i)
	if player._ring.has(enemy):
		return true
	if player._ring.size() >= GameData.inum("combat", "ring_slots"):
		return false
	player._ring.append(enemy)
	return true


func release_slot(enemy: Node) -> void:
	player._ring.erase(enemy)


## The percent of each hit your worn armour takes off, capped so gear stays below the body.
func armour() -> float:
	return clampf(player.inventory.stat("armour"), 0.0, GameData.num("gear", "armour_cap"))


# --- the ranged weapon (design/06 3.2) -------------------------------------------------------

## The equipped ranged weapon's definition, or {} with none.
func ranged_weapon() -> Dictionary:
	var id: String = str(player.inventory.equipped.get("ranged", ""))
	return GameData.item(id) if id != "" else {}


func ranged_stat(key: String, fallback: float) -> float:
	return float((ranged_weapon().get("stats", {}) as Dictionary).get(key, fallback))


## What one shot does.
func ranged_damage() -> float:
	var cfg: Dictionary = GameData.balance["ranged"]
	return float(cfg["ranged_damage"]) * ranged_stat("ranged_damage_mult", 1.0) * (float(cfg["off_arm_damage_factor"]) if player.arm_right_lost else 1.0)


## Seconds between shots: the weapon's own interval, shortened by worn gear (a quiver belt).
func ranged_interval() -> float:
	return ranged_stat("ranged_interval", GameData.num("ranged", "default_interval")) * player.inventory.stat("ranged_interval_mult", true)


## Loose the ranged weapon toward a point on the ground. Costs nothing but the time between
## shots. Returns false if there is no weapon, it is not ready, or you are mid-skill.
func fire_ranged(toward: Vector3) -> bool:
	if ranged_weapon().is_empty() or player._ranged_cd > 0.0 or player._recover_t > 0.0 or not player.active or player.dead or player.meditating:
		return false
	var cfg: Dictionary = GameData.balance["ranged"]
	var aim: Vector3 = toward - player.global_position
	aim.y = 0.0
	if aim.length() > 0.2:
		player._facing = aim.normalized()
	var speed: float = float(cfg["projectile_speed"])
	var shot: Node3D = Projectile.new()
	shot.set("color", Color(0.74, 0.72, 0.68))
	shot.set("tags", ["ranged"])
	shot.set("dir", player._facing)
	shot.set("damage", ranged_damage())
	shot.set("speed", speed)
	shot.set("life", ranged_stat("ranged_range", float(cfg["default_range"])) / speed * player.buff_num("shot_range_mult"))
	shot.set("shooter", player)
	player.get_parent().add_child(shot)
	shot.global_position = player._muzzle()
	player._ranged_cd = ranged_interval()
	player.motion_part._rig_action("throw")
	player._strike_t = 0.18
	return true


## Where a shot is aimed: at the enemy under the cursor if there is one, else the ground there.
func _ranged_aim() -> Vector3:
	if player.hovered != null and is_instance_valid(player.hovered) and player.hovered.is_in_group("enemies"):
		return player.hovered.global_position
	return player.motion_part._cursor_ground()


## A thin ring on the ground showing how far a shot carries, while the stance is held.
func _show_range_ring(on: bool) -> void:
	if on and _range_ring == null and player.is_inside_tree():
		_range_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.985
		ring.outer_radius = 1.0
		ring.rings = 96
		ring.ring_segments = 4
		_range_ring.mesh = ring
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.86, 0.7, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_range_ring.material_override = mat
		_range_ring.position.y = 0.06
		player.add_child(_range_ring)
	if _range_ring != null:
		_range_ring.visible = on
		if on:
			var r: float = ranged_stat("ranged_range", GameData.num("ranged", "default_range"))
			_range_ring.scale = Vector3(r, 1.0, r)


## Damage that has passed the pipeline (or comes from an effect's own timer).
func _apply_damage(amount: float, heavy: bool) -> float:
	var floor_hp: float = 0.0
	for bid: String in player.buffs:
		floor_hp = maxf(floor_hp, float((player.buffs[bid] as Dictionary).get("floor_health", 0.0)))
	if floor_hp > 0.0:
		amount = minf(amount, maxf(0.0, player.body.hp - floor_hp))    # Embalm: you cannot die while it lasts
	var applied: float = player.body.apply_damage(amount, heavy)
	if player._rig != null and applied > 0.0:
		player._rig.flash(0.1)
	player._float("-%d" % int(applied), Color(1, 0.25, 0.25))
	_maybe_wound(applied)
	_check_death()
	return applied


# --- wounds -----------------------------------------------------------------------------

## A heavy enough blow, or one that leaves you nearly dead, leaves a wound behind.
func _maybe_wound(applied: float) -> void:
	var w: Dictionary = GameData.balance["wounds"]
	if applied <= 0.0 or player.body.is_dead() or player._wound_cd > 0.0:
		return
	var big: bool = applied >= player.body.max_hp * float(w["big_hit_frac"])
	var low: bool = player.body.hp <= player.body.max_hp * float(w["low_health_frac"])
	if not big and not low:
		return
	# Tourniquet: held blood closes the wound before it opens
	for bid: String in player.buffs:
		var need: int = int((player.buffs[bid] as Dictionary).get("blood_per_wound", 0))
		if need > 0 and player.held_blood + player._pools_within(float((player.buffs[bid] as Dictionary).get("pool_radius", 0.0))) >= need:
			player._spend_blood_first_pools(need, float((player.buffs[bid] as Dictionary).get("pool_radius", 0.0)))
			player._float("staunched", GameData.affinity_color("blood").lightened(0.3))
			return
	var names: Array = w["names_big_hit"] if big else w["names_low"]
	var wound_name: String = str(names[player.rng.randi() % names.size()])
	player._wound_seq += 1
	take_wound("hit_%d" % player._wound_seq, wound_name, maxf(float(w["sink_min"]), applied * float(w["sink_per_damage"])), player.body.max_hp * float(w["cut_frac"]))
	player._wound_cd = float(w["wound_cooldown_s"])


## Add a wound. Tempering can make every wound shallower. `merge` deepens an existing one.
func take_wound(id: String, wound_name: String, sink: float, cut: float, natural: bool = true, merge: bool = false) -> void:
	player.body.add_wound(id, wound_name, sink * player.progress_part.temper_stat("wound_sink_mult"), cut, natural, merge)
	player._float(wound_name.to_upper(), Color(1, 0.35, 0.2))
	player.note("%s. It will not close on its own." % wound_name if not natural else "%s. Rest alone will not close it in the field." % wound_name)


## Wounds that closed: tell the player, and a regrown arm comes back weak.
func _wounds_closed(ids: Array) -> void:
	for id: String in ids:
		if id == "lost_arm":
			player.arm_right_lost = false
			player.arm_right = float(player._arm["max"]) * float(player._arm["regrown_by_talent_integrity"])
			player._float("ARM REGROWN", Color(0.4, 1, 0.5))
			player.discover("Regrows lost limbs: YES")
		else:
			player._float("WOUND CLOSED", Color(0.5, 1, 0.6))


## Talent healing (Brent 2026-10-11). Supreme quality, one star: the wounds' hidden sinks first,
## then the health bar. Dynamic, two stars: the bar up to half, then the sinks, then the rest of
## the bar. A lost limb is a wound like any other here - this is what natural healing cannot do.
func _spend_heal_points(points: float) -> float:
	var left: float = points
	if player.stars >= 2:
		# Dynamic: keep the body on its feet first - the bar to half - then mend what is broken.
		left -= player.body.heal(left, player.body.total_max() * float(GameData.balance["talent_healing"]["dynamic_health_first_frac"]))
	if left > 0.0:
		var filled: Dictionary = player.body.fill_sinks(left)
		left -= float(filled["used"])
		_wounds_closed(filled["closed"])
	if left > 0.0:
		left -= player.body.heal(left)
	return points - left


## One blow on one target (Brent 2026-09-23: base attacks are single target).
func _strike_target(target: Node3D, multiplier: float, tags: Array) -> void:
	player._strike_t = 0.2
	player.motion_part._snap_body_now()
	player._face_hold_t = 0.0
	_swing_visual(player.economy_part.reach_now(), multiplier > 1.0, true)
	deal_damage(target, float(player._p["melee_damage"]) * player.economy_part.weapon_stat("melee_damage_mult", true) * multiplier, tags)


## The overcharged blow lands on the clicked target, else whatever is under the cursor, else the
## nearest enemy in front of you - but only within reach.
func _overcharge_target(reach: float) -> Node3D:
	var candidates: Array[Node3D] = []
	if player.attack_target != null and is_instance_valid(player.attack_target):
		candidates.append(player.attack_target)
	if not player.bot and player.is_inside_tree():
		var under: Node3D = player.hovered
		if under != null:
			candidates.append(under)
	var near: Node3D = player.bot_part._nearest_enemy()
	if near != null:
		candidates.append(near)
	for t: Node3D in candidates:
		var to: Vector3 = t.global_position - player.global_position
		to.y = 0.0
		if to.length() <= reach + float(t.get("radius")):
			return t
	return null


## Area melee - used by skills such as Tsunami Strike, never by the base attack.
func _swing(multiplier: float, reach: float, tags: Array) -> void:
	player._strike_t = 0.25
	_swing_visual(reach, multiplier > 1.0, false)
	for t: Node3D in _in_arc(reach, player.melee_arc):
		deal_damage(t, strike_damage() * multiplier, tags)


## What one bare strike does, before any skill or stage multiplies it.
func strike_damage() -> float:
	return float(player._p["melee_damage"]) * player.economy_part.weapon_stat("melee_damage_mult", true) * float(conjured().get("melee_damage_mult", 1.0))


## The weapon conjured in your hand, or {} (Blood's conjure_weapon: Clotblade, Thirsting Glaive). One at a time.
func conjured() -> Dictionary:
	var b: Dictionary = player.buffs.get("conjured", {})
	return b


## How fast your bare strikes come: Red Frenzy's attack_rate_mult, a conjured glaive's empty_rate_bonus (fullest
## with no held blood).
func strike_rate_mult() -> float:
	var m: float = player.buff_num("attack_rate_mult")
	var c: Dictionary = conjured()
	if c.has("empty_rate_bonus") and player.held_blood_max() > 0:
		m *= 1.0 + float(c["empty_rate_bonus"]) * (1.0 - float(player.held_blood) / float(player.held_blood_max()))
	return m


## Conjure a weapon (conjure_weapon {weapon, lasts, extend_per_blood, spend_blood_max, melee_* keys, on_strike}): your
## bare strikes use it for lasts s (+extend_per_blood for each held blood spent, up to spend_blood_max); the worn
## weapon is hidden until it ends. A new one replaces the old.
func _conjure(ab: Dictionary) -> void:
	var cw: Dictionary = (ab["conjure_weapon"] as Dictionary).duplicate(true)
	var lasts: float = float(cw.get("lasts", 8.0))
	if int(cw.get("spend_blood_max", 0)) > 0:
		lasts += float(cw.get("extend_per_blood", 0.0)) * float(player.spend_blood(int(cw["spend_blood_max"])))
	cw["t"] = lasts
	cw["affinity"] = ab.get("affinity", "")
	player.buffs["conjured"] = cw
	if player._rig != null:
		var model: Node3D = Models.weapon("invader_cleaver" if float(cw.get("melee_range", 0.0)) > 3.0 else "serrated_dagger")
		model = model.duplicate() if model.get_parent() != null else model
		var red := StandardMaterial3D.new()
		red.albedo_color = GameData.affinity_color(str(ab.get("affinity", ""))).darkened(0.3)
		red.emission_enabled = true
		red.emission = GameData.affinity_color(str(ab.get("affinity", "")))
		red.emission_energy_multiplier = 1.2
		for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = red
		player._rig.set_weapon(model)
		player._shown_weapon = "conjured"
	if str(ab.get("kind", "")) != "self_buff":          # a self buff floats its own name already
		player._float(str(cw.get("weapon", "weapon")).replace("_", " "), GameData.affinity_color(str(ab.get("affinity", ""))).lightened(0.3))


## Everything hittable within `reach` and within `half_angle` (radians) of where you face.
func _in_arc(reach: float, half_angle: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for node: Node in player.get_tree().get_nodes_in_group("hittable"):
		var t := node as Node3D
		if t == null:
			continue
		var to: Vector3 = t.global_position - player.global_position
		to.y = 0.0
		var dist: float = to.length()
		if dist > reach + float(t.get("radius")):
			continue
		if dist > 0.3 and player._facing.angle_to(to / dist) > half_angle:
			continue
		out.append(t)
	return out


func _release_overcharge() -> void:
	var c: float = player._charge
	player._charging = false
	player._charge = 0.0
	if c < float(player._p["overcharge_min_charge"]):
		return
	# Health as ammunition: the blow lands harder than the arm can bear.
	var self_cost: float = float(player._p["overcharge_self_cost_base"]) + c * float(player._p["overcharge_self_cost_per_charge"])
	var applied: float = player.body.apply_self_harm(self_cost)
	player._float("arm -%d" % int(applied), Color(1, 0.4, 0.3))
	player.motion_part._rig_action("heavy")
	var heavy_target: Node3D = _overcharge_target(player.economy_part.reach_now() + float(player._p["overcharge_reach_bonus"]))
	if heavy_target != null:
		_strike_target(heavy_target, 1.0 + c * float(player._p["overcharge_damage_per_charge"]), ["melee", "overcharge"])
	else:
		_swing_visual(player.melee_range, true, true)
	player._melee_cd = float(player._p["melee_cooldown"]) * float(player._p["overcharge_cooldown_factor"])

	player.arm_right -= self_cost * float(player._arm["cost_per_self_harm"])
	if player.arm_right <= 0.0:
		player.arm_right = 0.0
		player.arm_right_lost = true
		var arm_wound: Dictionary = GameData.balance["wounds"]["lost_arm"]
		player.body.remove_wound("lost_arm")
		player.body.add_wound("lost_arm", str(arm_wound["name"]), float(player._arm["regrow_heal_points"]), float(arm_wound["cut"]), false)
		FloatText.spawn(player.get_parent(), player.global_position + Vector3.UP * 0.6, "ARM LOST", Color(1, 0.1, 0.1))
		player.note("Your striking arm is destroyed. Rest will not bring it back.")
	_check_death()


func _enemy_nearby() -> bool:
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		if not bool(node.call("is_dead")):
			return true
	return false


func _check_death() -> void:
	if not player.dead and player.body.is_dead():
		player.dead = true
		if player._rig != null:
			player._rig.set_dead_look()
		player.died.emit()


func start_fight() -> void:
	player.in_combat = true
	player.fight_time = 0.0


func end_fight() -> void:
	player.in_combat = false


func _swing_visual(reach: float, heavy: bool, narrow: bool) -> void:
	# the strike's reach is not drawn (Brent 2026-10-18: "a hit box on attack that is visible ...
	# needs to be invisible"); the body's own swing shows it. --show-reach brings the box back to debug.
	if not player.is_inside_tree() or not OS.get_cmdline_user_args().has("--show-reach"):
		return
	var arc := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.5 if narrow else reach * 1.4, 0.08, reach)
	arc.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.5, 0.2, 0.6) if heavy else Color(1, 1, 1, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc.material_override = mat
	player.get_parent().add_child(arc)
	arc.global_position = player.global_position + player._facing * (reach * 0.5) + Vector3.UP * 0.9
	arc.rotation.y = player.rotation.y
	var tween: Tween = arc.create_tween()
	tween.tween_property(arc, "scale", Vector3(1.1, 1.0, 1.1), 0.12)
	tween.tween_callback(arc.queue_free)
