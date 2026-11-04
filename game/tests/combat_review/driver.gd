extends Node
## Combat-review probe (2026-11-03). Runs the REAL game (main.tscn, test mode, no save written) with a
## REAL, non-invulnerable character and a scripted "new player" at the controls, and measures the loop.
## It never changes game code or data: it reads state, sets the same fields a mouse would (attack_target,
## move_goal, cursor_fixed), presses hotbar keys through Player.press_slot (the real key path, with its
## input buffer), and meters damage with one extra read-only TalentEffect (meter.gd).
##
## Args (after --):
##   --scenario=stubble|arena|passage   --aff=<base affinity>   --skills=a,b (default: first two roots)
##   --tier=new|mid                     --meditate=0|1 (sit to full between fights)
##   --dodge=walk|dash|step             --minutes=<game minutes cap>   --waves=<arena waves>  --walls=<passage walls>
##   --tag=<label for the output line>
## Prints one "PROBE {json}" line at the end plus human-readable "PROBE:" lines.

const STEP := 1.0 / 60.0

var args := {}
var main: Node
var player: Node
var t := 0.0
var cap_s := 600.0
var done := false
var phase := "boot"
var tag := ""

# ---- tallies ----
var time_in := {"fight": 0.0, "walk": 0.0, "meditate": 0.0, "rest": 0.0, "loot": 0.0, "other": 0.0}
var fight_dry := 0.0                 # in a fight with too little essence for the cheapest skill on the bar
var fight_dry_all := 0.0             # ... for every skill on the bar (not one is castable)
var engaged_hist := {}               # number of engaged enemies -> seconds (in a fight)
var engaged_max := 0
var presses := 0
var press_outcomes := {}             # cast | refused:<reason> | busy_dropped
var casts_by := {}                   # ability id -> casts
var hits_by := {}                    # ability id -> casts that touched an enemy within the window
var dmg_by_src := {"strike": 0.0, "skill": 0.0, "sling": 0.0, "status_or_other": 0.0}
var dmg_by_skill := {}
var strikes_landed := 0
var sling_shots := 0
var kills := 0
var kills_by := {}
var ttk_by := {}                     # kind -> [seconds...]
var tracked := {}                    # enemy instance id -> {kind, first, hp}
var taken := 0.0
var taken_hits := 0
var healed_in_fight := 0.0
var wounds_got := 0
var deaths := 0
var fights := 0
var fight_lens: Array = []
var _fight_t0 := -1.0
var loot_value_picked := 0
var loot_value_left := 0
var aura0 := 0.0
var star0 := 0.0
var progress0 := 0.0
var _dmg_last := {}                  # ability id -> last time it hurt an enemy
var _pending: Array = []             # [{slot, id, t, essence}]
var _cast_watch: Array = []          # [{id, t, hit}]
var _last_press := {}                # slot -> time
var _last_hp := 0.0
var _last_wounds := 0
var _route: Array = []
var _path := NavPath.new()
var _goal := Vector3.ZERO
var _goal_kind := ""
var _visit: Array = []
var _scenario := "stubble"
var _walls_done := 0
var _arena_wave_cap := 6
var _wall_cap := 3
var _notes_seen := 0
var log_reasons := {}
var other_by := {}
var death_note := ""
var _last_in: Array = []
var _stuck_t := 0.0
var _loot_item: Variant = null
var _loot_t := 0.0
var _last_pos := Vector3.ZERO
var _last_step := -9.0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
			args[kv[0]] = kv[1]
	_scenario = str(args.get("scenario", "stubble"))
	cap_s = float(args.get("minutes", "10")) * 60.0
	_arena_wave_cap = int(args.get("waves", "6"))
	_wall_cap = int(args.get("walls", "3"))
	tag = str(args.get("tag", ""))
	# WHAT-IF knobs (in memory only - nothing is written to game/data): --whatif_hp=<mult> scales every
	# enemy kind's hp before anything spawns.
	if args.has("whatif_hp"):
		for k: String in GameData.enemies:
			var ed: Variant = GameData.enemies[k]
			if ed is Dictionary and (ed as Dictionary).has("hp"):
				ed["hp"] = float(ed["hp"]) * float(args["whatif_hp"])
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	main.set("_test_mode", true)
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_make_character()
	_enter()
	set_physics_process(true)


func _skills() -> Array:
	var aff: String = str(args.get("aff", "water"))
	if args.has("skills"):
		return Array(str(args["skills"]).split(","))
	return Array(GameData.skill_roots([aff]).slice(0, 2))


func _make_character() -> void:
	var aff: String = str(args.get("aff", "water"))
	var why: String = main.call("begin_character", {"talent_id": "one_percent_lifesteal", "affinities": [aff], "skills": _skills()})
	if why != "":
		push_error("begin_character: " + why)
	player = main.get("player")
	if str(args.get("tier", "new")) == "mid":
		# A mid character [MODEL for this probe]: two stars (99 + 40 = 139 essence), the whole kit plus the
		# first tier-2 skill of the tree, every skill at stage 2, a Dim Mote (1 essence/s) and Iron Knuckles.
		player.set("stars", 2)
		var sp: Array[float] = [99.0, 40.0]
		player.set("star_pct", sp)
		player.call("_recompute_essence_max")
		for id: String in GameData.affinity(aff).get("kit", []):
			player.call("learn", id)
		var tree: Array = []
		for id2: Variant in GameData.skill_tree_of(aff):
			tree.append(id2)
		for node_id: Variant in tree:
			var node: Dictionary = GameData.skill_node(str(node_id))
			if int(node.get("tier", 1)) == 2 and (player.get("abilities") as Array).size() < 4:
				player.call("learn", str(node_id))
		for st: Dictionary in player.get("abilities"):
			st["stage"] = 2
		var inv: Inventory = player.get("inventory")
		inv.bag.append("dim_mote")
		inv.equip("dim_mote", "satellite")
		inv.bag.append("iron_knuckles")
		inv.equip("iron_knuckles", "weapon")
		player.call("refresh_gear")
		player.set("essence", float(player.get("essence_max")))
	player.connect("died", _on_died)
	var m: TalentEffect = load(_here("meter.gd")).new()
	m.setup(player, "combat_review_meter")
	m.set("drv", self)
	(player.get("effects") as Array).append(m)
	aura0 = float(player.get("_latent_aura"))
	star0 = _star_total()
	progress0 = _progress_total()
	_last_hp = (player.get("body") as Body).total()


func _here(f: String) -> String:
	return (get_script() as Script).resource_path.get_base_dir().path_join(f)


func _star_total() -> float:
	var s := 0.0
	for p: float in player.get("star_pct"):
		s += p
	return s


func _progress_total() -> float:
	var s := 0.0
	for st: Dictionary in player.get("abilities"):
		s += float(st.get("progress", 0.0)) + 100.0 * float(st.get("stage", 0))
	return s


func _enter() -> void:
	match _scenario:
		"stubble":
			main.call("walk_out")
			var camps: FieldCamps = main.get("field_camps")
			for id: String in camps.camps:
				var c: Dictionary = camps.camps[id]
				if (c["members"] as Array).is_empty():
					continue                                   # a spare site that did not roll live
				_visit.append(id)
			phase = "walk"
		"arena":
			main.call("enter_arena")
			phase = "arena"
		"passage":
			main.call("enter_passage")
			phase = "passage"


# ---------------------------------------------------------------- the meter's callbacks

func on_dealt(ctx: HitContext) -> void:
	if ctx.is_scenery or ctx.applied <= 0.0:
		return
	var tags: Array = ctx.tags
	var src := "status_or_other"
	if tags.has("ability"):
		src = "skill"
		var id := ""
		if tags.size() >= 3:
			id = str(tags[2])
		dmg_by_skill[id] = float(dmg_by_skill.get(id, 0.0)) + ctx.applied
		_dmg_last[id] = t
	elif tags.has("ranged"):
		src = "sling"
	elif tags.has("melee") and not tags.has("dot"):
		src = "strike"
		strikes_landed += 1
		if args.has("whatif_strike_essence"):
			# a generator: every bare strike that lands gives essence back
			player.set("essence", minf(float(player.get("essence_max")), float(player.get("essence")) + float(args["whatif_strike_essence"])))
	if tags.has("dot") or tags.has("burst") or tags.has("arc") or tags.has("crush") or tags.has("coat"):
		if src == "skill":
			pass
		else:
			src = "status_or_other"
	dmg_by_src[src] = float(dmg_by_src[src]) + ctx.applied
	var tgt: Node = ctx.target
	if tgt != null and is_instance_valid(tgt):
		var key: int = tgt.get_instance_id()
		if not tracked.has(key):
			tracked[key] = {"kind": str(tgt.get("kind")), "first": t, "node": tgt}
		if ctx.killed:
			_credit_kill(key)


func on_incoming(ctx: HitContext) -> void:
	taken_hits += 1
	var src: Node = ctx.source
	var who: String = str(src.get("kind")) if src != null and is_instance_valid(src) and src.get("kind") != null else "?"
	_last_in.append("%s %.0f%s" % [who, ctx.amount(), " heavy" if ctx.heavy else ""])
	if _last_in.size() > 6:
		_last_in.pop_front()


func _on_died() -> void:
	if done:
		return
	deaths += 1
	var near := []
	for e: Node3D in _engaged():
		near.append("%s %.0f/%.0f at %.1f m" % [str(e.get("kind")), (e.get("body") as Body).total(), (e.get("body") as Body).total_max(), _flat(e.global_position, (player as Node3D).global_position)])
	death_note = "t=%.1f essence %.1f, last blows: %s; engaged: %s" % [t, float(player.get("essence")), ", ".join(_last_in), ", ".join(near)]
	_finish("died")


func _credit_kill(key: int) -> void:
	if not tracked.has(key) or bool(tracked[key].get("dead", false)):
		return
	var rec: Dictionary = tracked[key]
	rec["dead"] = true
	kills += 1
	var k: String = str(rec["kind"])
	kills_by[k] = int(kills_by.get(k, 0)) + 1
	if not ttk_by.has(k):
		ttk_by[k] = []
	(ttk_by[k] as Array).append(t - float(rec["first"]))


# ---------------------------------------------------------------- the loop

func _physics_process(delta: float) -> void:
	if done or player == null:
		return
	t += delta
	if args.has("whatif_sat"):
		player.set("satellite_rate", float(args["whatif_sat"]))       # essence/s, as a satellite gives
	_account(delta)
	if bool(player.get("dead")):
		deaths += 1
		_finish("died")
		return
	if t > cap_s:
		_finish("time cap")
		return
	_resolve_presses()
	var foes: Array = _engaged()
	var fighting: bool = bool(player.get("in_combat")) and not foes.is_empty()
	if fighting:
		if _fight_t0 < 0.0:
			_fight_t0 = t
			fights += 1
		_release_meditate()
		_fight(foes)
		return
	if _fight_t0 >= 0.0 and foes.is_empty():
		fight_lens.append(t - _fight_t0)
		_fight_t0 = -1.0
	match _scenario:
		"stubble":
			_tick_stubble(delta)
		"arena":
			_tick_arena(delta)
		"passage":
			_tick_passage(delta)


func _account(delta: float) -> void:
	var body: Body = player.get("body")
	var hp: float = body.total()
	var foes: Array = _engaged()
	var fighting: bool = bool(player.get("in_combat")) and not foes.is_empty()
	if hp < _last_hp:
		taken += _last_hp - hp
	elif hp > _last_hp and fighting:
		healed_in_fight += hp - _last_hp
	_last_hp = hp
	var wn: int = body.wounds.size() if body.get("wounds") != null else 0
	if wn > _last_wounds:
		wounds_got += wn - _last_wounds
	_last_wounds = wn
	if fighting:
		time_in["fight"] += delta
		var n: int = 0
		for e: Node3D in foes:
			if _flat(e.global_position, (player as Node3D).global_position) <= 10.0:
				n += 1
		engaged_hist[n] = float(engaged_hist.get(n, 0.0)) + delta
		engaged_max = maxi(engaged_max, n)
		var cheapest := INF
		var dearest := 0.0
		for i: int in (player.get("hotbar") as Array).size():
			var idx: int = int(player.get("hotbar")[i])
			if idx < 0:
				continue
			var ab: Dictionary = player.call("ability_stats", (player.get("abilities") as Array)[idx])
			cheapest = minf(cheapest, float(ab.get("cost", 0.0)))
			dearest = maxf(dearest, float(ab.get("cost", 0.0)))
		var ess: float = float(player.get("essence"))
		if ess < cheapest:
			fight_dry += delta
		if ess < dearest:
			fight_dry_all += delta
	elif bool(player.get("meditating")):
		time_in["meditate"] += delta
	elif phase == "loot":
		time_in["loot"] += delta
	elif phase == "rest":
		time_in["rest"] += delta
	elif bool(player.get("has_move_goal")) or phase == "walk":
		time_in["walk"] += delta
	else:
		time_in["other"] += delta
		var key: String = "%s/%s/combat=%s/foes=%d" % [str(main.get("state")), phase, str(player.get("in_combat")), foes.size()]
		other_by[key] = float(other_by.get(key, 0.0)) + delta
	# kills the meter did not see (a burst, a thrall): count anything tracked that died
	for key: Variant in tracked.keys():
		var rec: Dictionary = tracked[key]
		if bool(rec.get("dead", false)):
			continue
		var n2: Variant = rec["node"]
		if not is_instance_valid(n2) or bool((n2 as Node).call("is_dead")):
			_credit_kill(int(key))


## Enemies that are in the fight: awake, not walking home, not calm, not buried.
func _engaged() -> Array:
	var out: Array = []
	var me: Vector3 = (player as Node3D).global_position
	for n: Node in get_tree().get_nodes_in_group("enemies"):
		var e := n as Node3D
		if e == null or bool(e.call("is_dead")) or e.is_queued_for_deletion():
			continue
		if bool(e.get("asleep")) or bool(e.get("_going_home")):
			continue
		if e.has_method("is_calm") and bool(e.call("is_calm")):
			continue
		if e.get("buried") != null and bool(e.get("buried")):
			continue
		if _scenario == "stubble" and _flat(e.global_position, me) > 30.0:
			continue
		out.append(e)
	return out


# ---------------------------------------------------------------- fighting: a careful new player

func _fight(foes: Array) -> void:
	var me: Vector3 = (player as Node3D).global_position
	phase = "fight"
	# 1. step out of what is telegraphed (as tests/newbie_duels.gd does), by walking or by the movement skill
	var away := Vector3.ZERO
	for e: Node3D in foes:
		var tele: Dictionary = e.get("telegraph")
		if tele.is_empty():
			continue
		var at: Vector3 = e.global_position
		match str(tele.get("kind", "")):
			"circle", "cone":
				if _flat(me, at) < float(tele.get("radius", 2.5)) + 0.8:
					away += _dir(at, me)
			"lane":
				var to: Vector3 = tele.get("to", at)
				var c: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(me.x, me.z), Vector2(at.x, at.z), Vector2(to.x, to.z))
				if c.distance_to(Vector2(me.x, me.z)) < float(tele.get("width", 2.0)) * 0.5 + 1.0:
					var along: Vector3 = to - at
					along.y = 0.0
					var side := Vector3(-along.z, 0.0, along.x).normalized()
					away += side if side.dot(me - at) >= 0.0 else -side
			"line":
				# an archer's drawn aim: only with --lines=1 (a player who has learned to read it) steps off it
				if str(args.get("lines", "0")) == "1":
					var to2: Vector3 = tele.get("to", at)
					var c2: Vector2 = Geometry2D.get_closest_point_to_segment(Vector2(me.x, me.z), Vector2(at.x, at.z), Vector2(to2.x, to2.z))
					if c2.distance_to(Vector2(me.x, me.z)) < 1.4:
						var along2: Vector3 = to2 - at
						along2.y = 0.0
						var side2 := Vector3(-along2.z, 0.0, along2.x).normalized()
						away += side2 if side2.dot(me - at) >= 0.0 else -side2
	for b: Node in get_tree().get_nodes_in_group("scald_bursts"):
		if _flat(me, (b as Node3D).global_position) < float(b.get("radius")) + 0.6:
			away += _dir((b as Node3D).global_position, me)
	if away.length() > 0.01:
		var esc: Vector3 = me + away.normalized() * 4.0
		player.set("attack_target", null)
		player.set("move_goal", esc)
		player.set("has_move_goal", true)
		if str(args.get("dodge", "walk")) == "dash":
			player.set("cursor_fixed", esc)
			_try_press_kind(["dash", "blink", "streak"])
		elif str(args.get("dodge", "walk")) == "step" and player.has_method("press_sidestep") and t - _last_step >= 0.5:
			# the free sidestep (combat review R3), toward the way out, at most twice a second
			player.set("cursor_fixed", esc)
			_last_step = t
			player.call("press_sidestep")
		return
	player.set("has_move_goal", false)
	var near: Node3D = null
	for e2: Node3D in foes:
		if near == null or _flat(me, e2.global_position) < _flat(me, near.global_position):
			near = e2
	var d: float = _flat(me, near.global_position)
	player.set("attack_target", near)
	player.set("cursor_fixed", near.global_position)
	# 2. the sling at what keeps away (a runner, a darter, an archer)
	if d > float(player.call("reach_now")) + float(near.get("radius")) + 2.5 and str(near.get("behaviour")) in ["runner", "darter", "ranged"]:
		if bool(player.call("fire_ranged", near.global_position)):
			sling_shots += 1
	# 3. skills: a new player presses a skill when the foe "looks close enough" - melee skills within
	#    3.5 m, ranged ones within 12 m - and only when the orb shows enough essence (careful). A press
	#    that the game then refuses, or that hits nothing, is counted.
	var hb: Array = player.get("hotbar")
	for slot: int in hb.size():
		var idx: int = int(hb[slot])
		if idx < 0:
			continue
		var ab: Dictionary = player.call("ability_stats", (player.get("abilities") as Array)[idx])
		var kind: String = str(ab.get("kind", ""))
		if kind in ["dash", "blink", "grapple", "streak"] and kind != "streak":
			continue                                   # kept for dodging
		var close: bool = kind in ["melee_burst", "targeted_strike"] or str(ab.get("targeting", "")) == "self"
		if close and d > 3.5:
			continue
		if not close and d > 12.0:
			continue
		if float(player.get("essence")) < float(ab.get("cost", 0.0)):
			# eager: a player who does not watch the orb tries the key again once a second
			if str(args.get("press", "careful")) == "eager" and t - float(_last_press.get(slot, -9.0)) >= 1.0:
				_press(slot, str((player.get("abilities") as Array)[idx]["id"]))
				break
			continue
		if t - float(_last_press.get(slot, -9.0)) < 0.35:
			continue
		_press(slot, str((player.get("abilities") as Array)[idx]["id"]))
		break


func _try_press_kind(kinds: Array) -> void:
	var hb: Array = player.get("hotbar")
	for slot: int in hb.size():
		var idx: int = int(hb[slot])
		if idx < 0:
			continue
		var ab: Dictionary = player.call("ability_stats", (player.get("abilities") as Array)[idx])
		if str(ab.get("kind", "")) in kinds and float(player.get("essence")) >= float(ab.get("cost", 0.0)) and t - float(_last_press.get(slot, -9.0)) > 0.5:
			_press(slot, str((player.get("abilities") as Array)[idx]["id"]))
			return


func _press(slot: int, id: String) -> void:
	presses += 1
	_last_press[slot] = t
	_notes_seen = int(player.get("log_serial"))
	var before: float = float(player.get("essence"))
	player.call("press_slot", slot)
	_pending.append({"slot": slot, "id": id, "t": t, "essence": before, "serial": _notes_seen})
	_resolve_presses()


func _resolve_presses() -> void:
	var keep: Array = []
	for p: Dictionary in _pending:
		var ess: float = float(player.get("essence"))
		var serial: int = int(player.get("log_serial"))
		if ess < float(p["essence"]) - 0.01 or _just_cast(str(p["id"])):
			_outcome("cast")
			casts_by[str(p["id"])] = int(casts_by.get(str(p["id"]), 0)) + 1
			_cast_watch.append({"id": str(p["id"]), "t": float(p["t"]), "hit": false})
		elif serial > int(p["serial"]):
			var lines: Array = player.get("log_lines")
			var last: String = str(lines[lines.size() - 1]) if not lines.is_empty() else "?"
			var reason := "refused:other"
			if last.contains("essence"):
				reason = "refused:no essence"
			elif last.contains("within reach") or last.contains("near where"):
				reason = "refused:no target in reach"
			elif last.contains("shadow") or last.contains("no way"):
				reason = "refused:no landing"
			log_reasons[last] = int(log_reasons.get(last, 0)) + 1
			_outcome(reason)
		elif t - float(p["t"]) > 0.4:
			_outcome("silent:busy or dropped")
		else:
			keep.append(p)
	_pending = keep
	var keep2: Array = []
	for w: Dictionary in _cast_watch:
		if float(_dmg_last.get(str(w["id"]), -99.0)) >= float(w["t"]) - 0.001:
			w["hit"] = true
		if t - float(w["t"]) > 2.0:
			var id: String = str(w["id"])
			if bool(w["hit"]):
				hits_by[id] = int(hits_by.get(id, 0)) + 1
		else:
			keep2.append(w)
	_cast_watch = keep2


func _just_cast(_id: String) -> bool:
	return false


func _outcome(k: String) -> void:
	press_outcomes[k] = int(press_outcomes.get(k, 0)) + 1


# ---------------------------------------------------------------- between fights

func _between(delta: float) -> bool:
	## Returns true while it is still busy between fights (looting, sitting, resting).
	# loot: walk to every pickup within 14 m and take it, while it fits
	if phase == "fight":
		phase = "loot"
		_route.clear()
		for n: Node in get_tree().get_nodes_in_group("pickups"):
			var d: Node3D = n as Node3D
			if d.is_queued_for_deletion() or d.get("item_id") == null:
				continue
			if _flat(d.global_position, (player as Node3D).global_position) < 14.0:
				_route.append(d)
	if phase == "loot":
		while not _route.is_empty() and (not is_instance_valid(_route[0]) or (_route[0] as Node).is_queued_for_deletion()):
			_route.pop_front()
		if not _route.is_empty():
			var drop: Node3D = _route[0]
			if _loot_item != drop:
				_loot_item = drop
				_loot_t = t
			if t - _loot_t > 6.0:
				push_warning("PROBE could not reach a pickup %s at %s from %s" % [str(drop.get("item_id")), str(drop.global_position), str((player as Node3D).global_position)])
				loot_value_left += int(GameData.item(str(drop.get("item_id"))).get("value", 0))
				_route.pop_front()
				player.set("pickup_target", null)
				return true
			if player.get("pickup_target") != drop:
				var inv: Inventory = player.get("inventory")
				var id: String = str(drop.get("item_id"))
				if not inv.can_add(id):
					loot_value_left += int(GameData.item(id).get("value", 0))
					_route.pop_front()
					return true
				player.set("pickup_target", drop)
			if _flat(drop.global_position, (player as Node3D).global_position) < 1.2:
				var id2: String = str(drop.get("item_id"))
				if bool(player.call("take_pickup", drop)):
					loot_value_picked += (player.get("inventory") as Inventory).sale_price(id2)
				else:
					loot_value_left += int(GameData.item(id2).get("value", 0))
				_route.pop_front()
			return true
		phase = "rest"
	if phase == "rest":
		var body: Body = player.get("body")
		var want_med: bool = str(args.get("meditate", "0")) == "1" and float(player.get("essence")) < float(player.get("essence_max")) - 0.5
		if want_med:
			Input.action_press("meditate")
			return true
		_release_meditate()
		if body.total() < body.total_max() * float(args.get("rest", "0.7")) - 0.5:
			return true                              # stand and let the bar refill (natural healing)
		phase = "walk"
	return false


func _release_meditate() -> void:
	if Input.is_action_pressed("meditate"):
		Input.action_release("meditate")


func _walk_to(goal: Vector3, delta: float) -> bool:
	var here: Vector3 = (player as Node3D).global_position
	if _flat(goal, here) < 2.0:
		player.set("has_move_goal", false)
		return true
	var way: Vector3 = goal - here
	var nav: LevelNav = LevelNav.find(get_tree(), here)
	if nav != null:
		var stepped: Vector3 = _path.steer(nav, here, goal, 0.4, delta)
		if stepped != Vector3.ZERO:
			way = stepped
	way.y = 0.0
	if _scenario == "stubble":
		var zb: ZoneBuilder = main.get("_zone")
		for line: Dictionary in zb.def.get("lines", []):
			if str(line.get("to", "")) == "town":
				var gc: Vector3 = (main.get("level") as Node3D).to_global(zb.line_centre(line))
				var off := Vector3(here.x - gc.x, 0.0, here.z - gc.z)
				if off.length() < 7.0:
					way = way.normalized() + off.normalized() * 2.0      # keep off the Dross Gate's line
	player.set("attack_target", null)
	player.set("move_goal", here + way.normalized() * 1.5)
	player.set("has_move_goal", true)
	return false


func _tick_stubble(delta: float) -> void:
	if str(main.get("state")) != "field":
		_finish("walked into town by accident (state %s)" % str(main.get("state")))
		return
	if _between(delta):
		return
	var camps: FieldCamps = main.get("field_camps")
	# the next camp: the nearest one still asleep (the herd and the roaming wirehorns last)
	var me: Vector3 = (player as Node3D).global_position
	var best := ""
	var best_d := INF
	for id: String in _visit:
		var st: String = camps.state_of(id)
		if st == "cleared" or (camps.members_of(id) as Array).is_empty():
			continue
		var c: Dictionary = camps.camps[id]
		var at: Vector3 = (main.get("level") as Node3D).to_global(c["centre"])
		var dd: float = _flat(at, me) + (500.0 if bool((c["def"] as Dictionary).get("herd", false)) else 0.0)
		if dd < best_d:
			best_d = dd
			best = id
	if best == "":
		_finish("every camp cleared")
		return
	var c2: Dictionary = camps.camps[best]
	var goal: Vector3 = (main.get("level") as Node3D).to_global(c2["centre"])
	var members: Array = camps.members_of(best)
	if not members.is_empty() and is_instance_valid(members[0]):
		goal = (members[0] as Node3D).global_position
	phase = "walk"
	_walk_to(goal, delta)
	_unstick(delta, goal)


func _unstick(delta: float, goal: Vector3) -> void:
	var here: Vector3 = (player as Node3D).global_position
	if _flat(here, _last_pos) < 0.02:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	_last_pos = here
	if _stuck_t > 6.0:
		push_warning("PROBE stuck at %s on the way to %s" % [str(here), str(goal)])
		_finish("stuck")


func _tick_arena(delta: float) -> void:
	var st: String = str(main.get("state"))
	if st == "arena_fight":
		_release_meditate()
		var left: Array = get_tree().get_nodes_in_group("enemies")
		if not left.is_empty():
			if not bool(player.get("in_combat")):
				push_warning("PROBE arena fight with in_combat false")
			_fight(left)
		return
	if st == "arena_rest":
		if int(main.get("wave")) >= _arena_wave_cap:
			_finish("waves done")
			return
		if phase == "fight" or phase == "loot" or phase == "rest":
			if _between(delta):
				main.set("rest_timer", maxf(float(main.get("rest_timer")), 1.0))   # "rest longer" while sitting
				return
		phase = "arena"
		main.set("rest_timer", minf(float(main.get("rest_timer")), 0.5))           # "go now"
		time_in["other"] -= 0.0
	# in a wave with nobody near yet: walk at the nearest
	var foes: Array = get_tree().get_nodes_in_group("enemies")
	if not foes.is_empty():
		var near: Node3D = foes[0]
		player.set("attack_target", near)


func _tick_passage(delta: float) -> void:
	if _between(delta):
		return
	var cleared: int = int(main.get("cleared"))
	if cleared >= _wall_cap:
		_finish("walls done")
		return
	var ch_len: float = float(main.get("ch_len"))
	var goal: Vector3 = (main.get("level") as Node3D).to_global(Vector3(0.0, 0.0, -(float(cleared + 1) * ch_len + 4.0)))
	phase = "walk"
	_walk_to(goal, delta)
	_unstick(delta, goal)


# ---------------------------------------------------------------- report

func _finish(why: String) -> void:
	if done:
		return
	done = true
	_release_meditate()
	_resolve_presses()
	for w: Dictionary in _cast_watch:
		if bool(w["hit"]) or float(_dmg_last.get(str(w["id"]), -99.0)) >= float(w["t"]) - 0.001:
			hits_by[str(w["id"])] = int(hits_by.get(str(w["id"]), 0)) + 1
	if _fight_t0 >= 0.0:
		fight_lens.append(t - _fight_t0)
	var mins: float = maxf(0.001, t / 60.0)
	var fmins: float = maxf(0.001, float(time_in["fight"]) / 60.0)
	var casts := 0
	for k: Variant in casts_by:
		casts += int(casts_by[k])
	var hit_casts := 0
	for k2: Variant in hits_by:
		hit_casts += int(hits_by[k2])
	var dmg_total := 0.0
	for k3: Variant in dmg_by_src:
		dmg_total += float(dmg_by_src[k3])
	var ttk_avg := {}
	for k4: Variant in ttk_by:
		var arr: Array = ttk_by[k4]
		var s := 0.0
		for v: float in arr:
			s += v
		ttk_avg[k4] = [snappedf(s / maxf(1.0, arr.size()), 0.1), arr.size()]
	var eng_avg := 0.0
	var eng_tot := 0.0
	for n: Variant in engaged_hist:
		eng_avg += float(n) * float(engaged_hist[n])
		eng_tot += float(engaged_hist[n])
	var hist := {}
	for n2: Variant in engaged_hist:
		hist[str(n2)] = snappedf(float(engaged_hist[n2]) / maxf(0.001, eng_tot), 0.01)
	var out := {
		"tag": tag, "scenario": _scenario, "aff": str(args.get("aff", "water")), "skills": _skills(), "tier": str(args.get("tier", "new")),
		"meditate": str(args.get("meditate", "0")), "press": str(args.get("press", "careful")), "lines": str(args.get("lines", "0")), "rest": str(args.get("rest", "0.7")), "dodge": str(args.get("dodge", "walk")), "end": why,
		"game_s": snappedf(t, 0.1), "fight_s": snappedf(float(time_in["fight"]), 0.1), "walk_s": snappedf(float(time_in["walk"]), 0.1),
		"meditate_s": snappedf(float(time_in["meditate"]), 0.1), "rest_s": snappedf(float(time_in["rest"]), 0.1), "loot_s": snappedf(float(time_in["loot"]), 0.1),
		"other_s": snappedf(float(time_in["other"]), 0.1),
		"fights": fights, "fight_len_avg": snappedf(_avg(fight_lens), 0.1),
		"kills": kills, "kills_per_min": snappedf(kills / mins, 0.01), "kills_per_fight_min": snappedf(kills / fmins, 0.01),
		"kills_by": kills_by, "ttk_by": ttk_avg,
		"presses": presses, "press_outcomes": press_outcomes, "casts": casts, "casts_per_fight_min": snappedf(casts / fmins, 0.1),
		"casts_by": casts_by, "casts_hit": hits_by, "whiff_frac": snappedf(1.0 - float(hit_casts) / maxf(1.0, casts), 0.01),
		"strikes_landed": strikes_landed, "strikes_per_fight_min": snappedf(strikes_landed / fmins, 0.1), "sling_shots": sling_shots,
		"dry_frac": snappedf(fight_dry / maxf(0.001, float(time_in["fight"])), 0.01), "dry_any_frac": snappedf(fight_dry_all / maxf(0.001, float(time_in["fight"])), 0.01),
		"dmg_by_src": _round(dmg_by_src), "dmg_share_skill": snappedf(float(dmg_by_src["skill"]) / maxf(1.0, dmg_total), 0.01),
		"dmg_by_skill": _round(dmg_by_skill), "dps_fight": snappedf(dmg_total / maxf(0.001, float(time_in["fight"])), 0.1),
		"taken": snappedf(taken, 0.1), "taken_per_fight_min": snappedf(taken / fmins, 0.1), "hits_taken": taken_hits,
		"healed_in_fight": snappedf(healed_in_fight, 0.1), "wounds": wounds_got, "deaths": deaths,
		"sidesteps": int(player.get("sidesteps")) if player.get("sidesteps") != null else 0,
		"engaged_avg": snappedf(eng_avg / maxf(0.001, eng_tot), 0.01), "engaged_max": engaged_max, "engaged_hist": hist,
		"loot_value_picked": loot_value_picked, "loot_value_left": loot_value_left, "loot_per_min": snappedf(loot_value_picked / mins, 1.0),
		"aura_gained": snappedf(float(player.get("_latent_aura")) - aura0, 0.01), "star_pct_gained": snappedf(_star_total() - star0, 0.001),
		"skill_progress_gained": snappedf(_progress_total() - progress0, 0.1), "essence_max": snappedf(float(player.get("essence_max")), 0.1),
		"whatif": {"hp": str(args.get("whatif_hp", "")), "sat": str(args.get("whatif_sat", "")), "strike_essence": str(args.get("whatif_strike_essence", ""))}, "refusal_lines": log_reasons, "other_by": _round(other_by), "death_note": death_note,
		"arena_wave": int(main.get("wave")) if _scenario == "arena" else -1, "walls_cleared": int(main.get("cleared")) if _scenario == "passage" else -1,
	}
	print("PROBE " + JSON.stringify(out))
	get_tree().quit(0)


func _avg(a: Array) -> float:
	var s := 0.0
	for v: Variant in a:
		s += float(v)
	return s / maxf(1.0, a.size())


func _round(d: Dictionary) -> Dictionary:
	var o := {}
	for k: Variant in d:
		o[k] = snappedf(float(d[k]), 1.0)
	return o


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _dir(from: Vector3, to: Vector3) -> Vector3:
	var v := Vector3(to.x - from.x, 0.0, to.z - from.z)
	return v.normalized() if v.length() > 0.01 else Vector3(1, 0, 0)
