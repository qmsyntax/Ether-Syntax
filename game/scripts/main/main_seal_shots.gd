class_name MainSealShots
extends RefCounted
## The screenshot setups for test characters, the v2 role shots, the seal board and the level lock
## (--shot-ui=test-*, role-*, seal-*, runes-*): part of the test harness (MainHarness.seal_shots), built only
## by a shot run. Moved out of main.gd as it was (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


## For screenshots: a closed four-rune word on the first skill (Water Bolt), locked. Rune ids are
## the 2026-10-22 workbook's.
## Test-character shots (2026-10-22 build): "ethercosm" (a water test character's soul: eighteen
## skills), "runes" (an ice skill's word), "statuses" (enemies carrying the new statuses, the HUD over
## them), or an affinity id: that test character fighting in the arena, casting its skills.
func _setup_test_shot(what: String) -> void:
	main.forced_biome = "scrubland"
	if what.begins_with("ethercosm-"):
		main.start_test_character(what.trim_prefix("ethercosm-"))       # an affinity's own (test-ethercosm-holy: a hybrid's)
		main.open_ethercosm()
		return
	match what:
		"ethercosm":
			main.start_test_character("water")
			main.open_ethercosm()
			return
		"detail-mask", "detail-water", "detail-chain", "detail-sealed", "status-tip", "status-glossary":
			# the ethercosm's skill details (Brent 2026-10-23): a skill's numbers and its statuses
			var spec: Array = {"detail-mask": ["dream", "changeling_mask"], "detail-water": ["water", "riptide_lash"],
				"detail-chain": ["lightning", "forked_path"], "detail-sealed": ["water", "tsunami_strike"],
				"status-tip": ["dream", "shattered_dream"], "status-glossary": ["dream", "changeling_mask"]}[what]
			main.start_test_character(str(spec[0]))
			if what == "detail-sealed":
				_shot_lock_word()                      # Breaker sealed through two rings: base beside sealed
			main.open_ethercosm()
			var at: int = (main.player.get("abilities") as Array).map(func(s: Dictionary) -> String: return str(s["id"])).find(str(spec[1]))
			main.screen.call("select", maxi(0, at))
			if what == "status-glossary":
				main.screen.call("show_glossary", true)
			if what == "status-tip":
				# a status named on the panel, its definition open in place and as a tooltip: the pointer
				# rests on the chip until the tooltip shows
				main._harness()._shot_countdown = 90
				main.get_tree().create_timer(0.25).timeout.connect(func() -> void:
					var chip: Control = main.screen.find_child("StatusTerm_asleep", true, false) as Control
					if chip == null:
						print("shot: no Asleep chip")
						return
					(chip as Button).emit_signal("pressed")
					var p: Vector2 = chip.get_global_rect().get_center()
					var mv := InputEventMouseMotion.new()
					mv.position = p
					mv.global_position = p
					main.get_viewport().push_input(mv)
					Input.warp_mouse(p))
			return
		"skilltree":
			# a new water character a few skills in: its thirteen-skill tree, three tiers deep
			main._select_talent(0)
			main.player.call("set_affinities", ["water"])
			for id: String in ["riptide_lash", "tsunami_strike", "drench", "seepage"]:
				main.player.call("learn", id)
			main.player.set("skill_points", 2)
			main._enter_town()
			main.open_skill_tree(false)
			return
		"runes":
			# a test character at its first level lock (no free edit since Brent 2026-10-23): ring 1 of
			# an ice skill being built, a vestige chosen in the panel
			main.start_test_character("ice")
			main.open_ethercosm()
			main.screen.call("open_runes")
			main.player.call("word_add", 0, "ICE-5a", 0)       # Brittle on Frost (Hoarline)
			main.player.call("word_add", 0, "UNI-11a", 0)      # Persist
			main.screen.call("pick_node", 1)
			return
		"statuses":
			main.start_test_character("ice")
			main._show_screen(null, false)
			main.enter_arena()
			main.rest_timer = 9999.0
			var put: Array = [[Vector3(-2.2, 0, -2.6), "grunt", [["chilled", 3], ["bleeding", 2]]],
				[Vector3(1.0, 0, -3.4), "brute", [["dosed", 4], ["lit", 1], ["rusting", 1]]],
				[Vector3(3.6, 0, -1.4), "grunt", [["infected", 3], ["sick", 1], ["exposed", 1]]],
				[Vector3(-4.4, 0, -0.6), "archer", [["blinded", 1], ["shackled", 1]]],
				[Vector3(-0.6, 0, -5.6), "pavise", [["frozen", 1], ["corroded", 2]]]]
			for row: Array in put:
				main.factory_part._spawn_enemy(str(row[1]), row[0], 1.0)
			var all: Array = main.get_tree().get_nodes_in_group("enemies")
			for i: int in mini(all.size(), put.size()):
				for st: Array in put[i][2]:
					all[i].call("add_status", str(st[0]), int(st[1]), main.player)
				(all[i].get("body") as Body).apply_damage(20.0 * float(i + 1))
			main.state = "arena_fight"                          # no rest prompt over the picture
			for e: Node in all:
				e.set_physics_process(false)
			main.player.set_physics_process(false)
			return
	# an affinity: its test character in the arena, three skills in the air
	main.start_test_character(what)
	main._show_screen(null, false)
	main.enter_arena()
	main.rest_timer = 9999.0
	for at: Vector3 in [Vector3(-1.5, 0, -4.0), Vector3(1.2, 0, -4.8), Vector3(3.0, 0, -2.5), Vector3(-3.5, 0, -6.0)]:
		main.factory_part._spawn_enemy("grunt", at, 1.0)
	main.factory_part._spawn_enemy("brute", Vector3(0.5, 0, -7.0), 1.0)
	main.player.call("start_fight")
	main.state = "arena_fight"
	var first: Node3D = main.get_tree().get_nodes_in_group("enemies")[0]
	main.player.set("cursor_fixed", first.global_position)
	main.player.set("hovered", first)
	main.player.set("_facing", (first.global_position - main.player.global_position).normalized())
	main._harness()._shot_countdown = 75
	var order: Array = [0, 1, 3, 4, 2]
	for k: int in order.size():
		var slot: int = int(order[k])
		SkillTimer.after(main.level, 0.05 + 0.32 * float(k), func(_i: int) -> void:
			main.player.set("_recover_t", 0.0)
			main.player.set("_held", {})
			var live: Array = main.get_tree().get_nodes_in_group("enemies")
			if not live.is_empty():
				main.player.set("cursor_fixed", (live[k % live.size()] as Node3D).global_position)
				main.player.set("hovered", live[k % live.size()])
			main.player.call("cast_slot", slot))


## The v2 role shots (`--shot-ui=role-<affinity>`): a test character in the arena using the skill its role turns on -
## Earth's Millstone (the taunt), Poison's Venom Edge (the coat) and a bare strike that carries it, Blood's Thirsting
## Glaive (the conjured weapon), Dark's Ambush out of its own Blot, Death's thralls raised from the fallen.
const ROLE_SHOTS := {
	"earth": [["millstone", 0.1]],
	"poison": [["venom_edge", 0.1], ["sting_dart", 0.5]],
	"blood": [["red_lancet", 0.1], ["thirsting_glaive", 0.4]],
	"dark": [["hungry_dark", 0.5]],
	"death": [["rise_again", 0.1], ["rise_again", 0.35], ["rise_again", 0.6]],
}


func _setup_role_shot(aff: String) -> void:
	main.forced_biome = "scrubland"
	main.start_test_character(aff)
	main._show_screen(null, false)
	main.enter_arena()
	main.rest_timer = 9999.0
	for at: Vector3 in [Vector3(-1.2, 0, -2.6), Vector3(1.4, 0, -3.0), Vector3(3.0, 0, -1.6), Vector3(-3.2, 0, -4.4)]:
		main.factory_part._spawn_enemy("grunt", at, 1.0)
	main.factory_part._spawn_enemy("brute", Vector3(0.4, 0, -5.4), 1.0)
	main.player.call("start_fight")
	main.state = "arena_fight"
	var foes: Array = main.get_tree().get_nodes_in_group("enemies")
	var first: Node3D = foes[0]
	main.player.set("_facing", ((first.global_position - main.player.global_position) * Vector3(1, 0, 1)).normalized())
	if aff == "death":
		# three of them fall where they stood, for the thralls to rise from
		for i: int in 3:
			var e: Node = foes[foes.size() - 1 - i]
			(e.get("body") as Body).apply_damage(9999.0)
			e.call("take_hit", 1.0, false, main.player)
	if aff == "dark":
		# you stand in a Dark of your own (a Blot's ground), Unseen, for the Ambush
		var dz := GroundZone.new()
		dz.shape = "circle"
		dz.radius = 3.0
		dz.life = 30.0
		dz.dark = true
		dz.kind = "dark_ground"
		dz.caster = main.player
		dz.from = main.player.global_position
		main.level.add_child(dz)
	main._harness()._shot_countdown = 70
	for step: Array in ROLE_SHOTS.get(aff, []):
		var id: String = str(step[0])
		SkillTimer.after(main.level, float(step[1]), func(_i: int) -> void:
			main.player.set("_recover_t", 0.0)
			main.player.set("_held", {})
			var dead_spots: Array = main.get_tree().get_nodes_in_group("fallen").filter(func(f: Node) -> bool: return not bool(f.get("spent")))
			var live: Array = main.get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return not bool(e.call("is_dead")))
			if id == "rise_again" and not dead_spots.is_empty():
				main.player.set("cursor_fixed", (dead_spots[0] as Node3D).global_position)
			elif not live.is_empty():
				main.player.set("cursor_fixed", (live[0] as Node3D).global_position)
				main.player.set("hovered", live[0])
			var list: Array = main.player.get("abilities")
			for i: int in list.size():
				if str(list[i]["id"]) == id:
					main.player.set("essence", float(main.player.get("essence_max")))
					main.player.call("cast_ability", i)
					break)


func _shot_lock_word() -> void:
	# Heave and Drown on ring 1, Dry on Heave on ring 2: sealed through two rings, on Breaker (Surge)
	_shot_surge_first()
	_shot_seal(0, 2, [["WAT-4a", 0], ["WAT-4b", 0], ["WAT-3b", 1]])


## For the water seal shots: the skill built on Surge (Breaker; Water Bolt before v2) is put first, so a
## shot's rows (given against Surge) mean what they say. The hotbar follows the swap.
func _shot_surge_first() -> void:
	if not bool(main.player.call("knows", "tsunami_strike")) and str(main.player.call("can_learn", "tsunami_strike")) == "":
		main.player.call("learn", "tsunami_strike")
	var list: Array = main.player.get("abilities")
	var k: int = list.map(func(st: Dictionary) -> String: return str(st["id"])).find("tsunami_strike")
	if k <= 0:
		return
	var first: Dictionary = list[0]
	list[0] = list[k]
	list[k] = first
	var bar: Array = main.player.get("hotbar")
	for i: int in bar.size():
		if int(bar[i]) == 0:
			bar[i] = k
		elif int(bar[i]) == k:
			bar[i] = 0


## For screenshots: seal a word on skill `index` as if it had been bound in, lock by lock (the skill
## is raised to `stage` first). Rows are [rune, joined to row (0 = the skill's own rune, 1 = the first
## row ...), ring (optional)], inside out; `links` are extra [row a, row b] bonds. Each ring gets a
## keystone (`concepts`, else the concepts in turn). Only where the rule set still asks for full rings
## (bond_v2 seal_needs_full_rings; false since Brent 2026-11-03) are the empty places filled with
## SHOT_FILLER runes, set alone. Shot setup only: the rules are asked for every rune and bond; no
## screen reaches this.
const SHOT_FILLER := "UNI-19a"


func _shot_seal(index: int, stage: int, rows: Array, links: Array = [], concepts: Array = []) -> void:
	var st: Dictionary = (main.player.get("abilities") as Array)[index]
	st["stage"] = maxi(stage, int(st["stage"]))
	var w: Dictionary = RuneWord.make(GameData.skill_anchor(str(st["id"])), Runes.active().id)
	var rules: RuneRules = Runes.active()
	var rr: RingRules = rules as RingRules
	var ctx: RuneContext = main.player.call("rune_context", index)
	var at: Dictionary = {0: 0}               # row -> node
	for ri: int in rows.size():
		var row: Array = rows[ri]
		var to: int = int(at.get(int(row[1]), -1))
		var k: int = int(row[2]) if row.size() > 2 else _shot_ring(w, ctx, to)
		_shot_fill(w, ctx, k - 1)
		var r: Dictionary = rules.add(w, str(row[0]), ctx, to, k)
		if not bool(r["ok"]):
			print("shot seal: %s refused: %s" % [str(row[0]), str(r["text"])])
		else:
			at[ri + 1] = int(r["node"])
	for l: Array in links:
		var r2: Dictionary = rules.link(w, int(at.get(int(l[0]), -1)), int(at.get(int(l[1]), -1)), ctx)
		if not bool(r2["ok"]):
			print("shot seal: link %s refused: %s" % [str(l), str(r2["text"])])
	_shot_fill(w, ctx, int(st["stage"]))
	if rr != null:
		for k2: int in range(1, int(st["stage"]) + 1):
			var olds: Array = GameData.construct_legacy.keys()          # else the six old concepts in turn, as their words of the tier
			var cid: String = str(concepts[k2 - 1]) if k2 - 1 < concepts.size() else GameData.construct_word_id(GameData.tier_for_stage(k2 - 1), str(olds[(k2 - 1) % olds.size()]))
			RuneWord.set_keystone(w, k2, GameData.tier_for_stage(k2 - 1), cid)
	var sealed: Dictionary = rules.seal(w, ctx, int(st["stage"]))
	if bool(sealed["ok"]):
		st["word"] = w
	else:
		print("shot seal: refused: %s" % str(sealed["text"]))
	for rid: Variant in RuneWord.nodes(w):
		main.player.call("_know", str(rid))


## The ring a shot row joined to node `to` goes on: one further out where the skill has it and there is
## room, else the same ring, else the one inside (ring 1 for a rune joined to nothing or the skill).
func _shot_ring(w: Dictionary, ctx: RuneContext, to: int) -> int:
	var rr: RingRules = Runes.active() as RingRules
	if to <= 0 or rr == null:
		return 1
	var tr: int = RuneWord.ring(w, to)
	for k: int in [tr + 1, tr, tr - 1]:
		if k >= 1 and k <= ctx.rings and RuneWord.ring_nodes(w, k).size() < rr.ring_capacity(k):
			return k
	return tr


## Fill every empty place of rings 1..`upto` with the shot filler, set alone - only where the rules
## still ask for full rings.
func _shot_fill(w: Dictionary, ctx: RuneContext, upto: int) -> void:
	var rr: RingRules = Runes.active() as RingRules
	if rr == null or not rr.needs_full_rings():
		return
	for k: int in range(1, upto + 1):
		while RuneWord.ring_nodes(w, k).size() < rr.ring_capacity(k):
			if not bool(rr.add(w, SHOT_FILLER, ctx, -1, k)["ok"]):
				print("shot seal: ring %d could not be filled" % k)
				break


## The seal board in the middle of an action, for a shot (the draft of "seal-drag" and friends):
## "seal-drag" Drown dragged onto Flood (an ionic bond: Drown would take Flood's effect), "seal-refused"
## Drown dragged onto Dry (full), "seal-bond" the Drown - Flood bond made and selected.
func _shot_board_state(which: String) -> void:
	if not (main.screen is Main.EthercosmScreen):
		return
	var board: RuneBoard = null
	for n: Node in main.screen.find_children("RuneBoard", "Control", true, false):
		board = n as RuneBoard
	if board == null:
		return
	var word: Dictionary = main.player.call("ability_word", 0)
	var idx := {}
	for i: int in RuneWord.size(word):
		idx[RuneWord.node_id(word, i)] = i
	match which:
		"seal-drag":
			board.show_drag(int(idx["WAT-4b"]), board.node_global(int(idx["WAT-1a"])) + Vector2(4.0, 3.0))
		"seal-refused":
			board.show_drag(int(idx["WAT-4b"]), board.node_global(int(idx["WAT-3b"])) + Vector2(4.0, 3.0))
		"seal-bond":
			main.screen.call("finish_bond", int(idx["WAT-4b"]), int(idx["WAT-1a"]))


## The index of ability `id` on the player, learning it first if need be.
func _shot_skill(id: String) -> int:
	if not bool(main.player.call("knows", id)):
		main.player.call("learn", id)
	var list: Array = main.player.get("abilities")
	for i: int in list.size():
		if str(list[i]["id"]) == id:
			return i
	return 0


## The seal screen's shots (design/14 section 8). Rune ids are the 2026-10-22 workbook's.
##   seal-forming       a water + fire Breaker sealed through ring 1, its bar full and a remnant
##                      carried: the seal screen forming ring 2 over ring 1, part-built (also "runes")
##   runes-locking      the same seal bound through the screen (a sure roll), caught mid-animation
##   runes-locked       a two-ring seal on Breaker, looked at (no binding)
##   seal-traits        a three-ring Breaker: a closed ring 1, a spoke out to ring 3, two branch runes
##   seal-drown-*       Overboard's three Drown words (on Heave): Drown on the skill itself, Drown hung off Flood,
##                      Drown hung off Surge (each carries what it took over its ionic bond)
##   seal-drag          the seal-forming draft with a bond being dragged onto a rune that takes it: the
##                      live bond, its kind and dominant side in words, valid runes glowing, the rest dimmed
##   seal-refused       the same, dragged onto a rune that refuses it: the reason under it and at the cursor
##   seal-bond          the same draft with a bond selected: its gold sheath, its x, the panel's bond section
##   seal-convert       Drown takes Wave on Sluice Step (sealed, looked at, Drown selected): the converted
##                      strength 1.5 -> 2.5 and where it came from, the silence and the longer Dazed
##   seal-discovered    a new water character reading the waystone's runes: the "Rune discovered" card
##   seal-palette       the palette of a new character: what it knows, and the "?" it has yet to find
##   seal-lock-main     a water test character's ethercosm (Brent 2026-10-23): Breaker's bar full, "ready
##                      for its level 1 lock", one "Open the seal" button and no bind buttons
##   seal-lock-first    its seal at the first lock: ring 1 part-filled (2 of 3 places), the vestige set
##                      over it and Bind live all the same (Brent 2026-11-03: "let them bind and close no
##                      matter what"; it was disabled under the full-ring rule of 2026-10-24)
##   seal-lock-keystone the first lock with every place of ring 1 filled, the word closed and the vestige
##                      set over it as the keystone: Bind live
##   seal-lock-second   the second lock, by the real flow (ring 1 full, closed and bound under a vestige,
##                      the bar refilled - a test override): ring 1 reworked, ring 2 full and closed, the
##                      remnant set over it
##   seal-lock-open     the second lock under Brent's 2026-11-03 rules: ring 1 bound 2 of 3 with open
##                      bonds, then ring 2 only 2 of 5 - Drown bonded straight to the skill's own rune
##                      (its third bond, gained with ring 2), Settle off Heave - the remnant set, Bind live
##   seal-lock-missing  a new character's main page: the bar full, no vestige carried - what is missing,
##                      and no way into the lock
##   seal-lock-fit      a water test character's first lock (Brent 2026-11-04): the keystone list - water
##                      vestiges, universal ones, and two fire and an ice vestige that do not fit, greyed
##   seal-lock-tip      the same, the pointer resting on the vestige of Flood: its runes and what it does
##   seal-lock-nofit    the main page of a fire character carrying only water vestiges: the lock does not open
func _setup_seal_shot(which: String) -> void:
	if which.begins_with("seal-lock-"):
		_setup_lock_shot(which.trim_prefix("seal-lock-"))
		return
	if which.begins_with("seal-palette-"):
		# an affinity's own runes in the palette of its test character's first lock (Holy's Old Turkic glyphs)
		var aff: String = which.trim_prefix("seal-palette-")
		main.start_test_character(aff)
		main._enter_town()
		main.open_seal(0, 0)
		main.screen.call("set_palette_tab", aff)
		return
	main._select_talent(0)
	(main.player.get("constructs") as Array).clear()          # the other UI shots hand out two vestiges first
	match which:
		"seal-drag", "seal-refused", "seal-bond":
			# ring 1 sealed: Flood and Heave on Surge, Dry on Heave; forming ring 2: Drown and Settle set, not bonded
			main.player.call("set_affinities", ["water"])
			_shot_surge_first()
			_shot_seal(0, 1, [["WAT-1a", 0], ["WAT-4a", 0], ["WAT-3b", 2]])
			for rid2: String in ["WAT-6b", "WAT-4b", "WAT-7b", "UNI-05a"]:
				main.player.call("_know", rid2)
			(main.player.get("abilities") as Array)[0]["progress"] = 100.0
			(main.player.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
			main._enter_town()
			main.open_seal(0, 0)
			main.screen.call("place_rune", "WAT-4b", 2, 1)          # Drown, ring 2
			main.screen.call("place_rune", "WAT-6b", 2, 3)          # Settle, ring 2
			main.screen.call("deselect")
			main._harness()._shot_countdown = 60
			main.get_tree().create_timer(0.4, true).timeout.connect(_shot_board_state.bind(which))
		"seal-forming", "runes", "runes-locking":
			main.player.call("set_affinities", ["water", "fire"])
			_shot_surge_first()
			_shot_seal(0, 1, [["WAT-1a", 0], ["WAT-4a", 0], ["WAT-3b", 1]], [[1, 2]])     # Flood, Heave (joined), Dry
			for rid: String in ["WAT-6b", "WAT-4b", "WAT-7b", "UNI-05a", "UNI-11a", "FIR-1b", "WAT-2b"]:
				main.player.call("_know", rid)
			var own: Array = main.player.get("abilities")
			own[0]["progress"] = 100.0
			(main.player.get("constructs") as Array).append({"tier": "remnant", "concept": "tension"})
			main._enter_town()
			main.open_seal(0, 0)
			# rework ring 1: part Flood and Heave, so each has a bond for the new ring
			main.player.call("word_toggle_link", 0, 1, 2)
			main.player.call("word_add", 0, "WAT-6b", 2)        # Settle off Heave, out on ring 2
			main.player.call("word_add", 0, "WAT-4b", 4)        # Drown off Settle, ring 2
			main.player.call("word_add", 0, "WAT-3b", 4)        # a second Dry off Settle, ring 2 (Slack before v2)
			main.player.call("word_add", 0, "UNI-05a", 1)       # Expand off Flood, ring 2
			if which == "runes-locking":
				main.player.call("word_toggle_link", 0, 4, 7)   # Expand joins Settle: the word closes
				main.screen.call("bind_and_seal", 0.0)
				main._harness()._shot_countdown = 38
			else:
				main.screen.call("pick_node", 7)                # Expand picked: one bond still open
		"seal-convert":
			main.player.call("set_affinities", ["water"])
			var tb: int = _shot_skill("hydraulic_flex")
			_shot_seal(tb, 1, [["WAT-4b", 0]])                # Drown on Wave: ionic, Drown takes it
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("select", tb)
			main.screen.call("open_runes")
			main.screen.call("pick_node", 1)
		"runes-locked":
			main.player.call("set_affinities", ["water", "fire"])
			_shot_surge_first()
			_shot_seal(0, 2, [["WAT-6b", 0], ["WAT-4b", 0], ["WAT-3b", 1], ["WAT-4a", 1, 2], ["WAT-3b", 1, 2], ["FIR-1b", 4, 2]])
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("open_runes")
		"seal-traits":
			main.player.call("set_affinities", ["water"])
			_shot_surge_first()
			# ring 1: Flood, Settle, Soak round a triangle; Settle -> Heave (ring 2) -> Drown (ring 3)
			_shot_seal(0, 3, [["WAT-1a", 0], ["WAT-6b", 0], ["WAT-3a", 1, 1], ["WAT-4a", 2, 2], ["WAT-4b", 4, 3]], [[1, 2], [2, 3]])
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("open_runes")
		"seal-drown-self", "seal-drown-flood", "seal-drown-surge":
			main.player.call("set_affinities", ["water"])
			var pj: int = _shot_skill("overboard")
			match which:
				"seal-drown-self":
					_shot_seal(pj, 2, [["WAT-4b", 0]])
				"seal-drown-flood":
					_shot_seal(pj, 2, [["WAT-1a", 0], ["WAT-4b", 1]])
				"seal-drown-surge":
					_shot_seal(pj, 2, [["WAT-2a", 0], ["WAT-4b", 1]])
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("select", pj)
			main.screen.call("open_runes")
		"seal-discovered":
			main.player.call("set_affinities", ["water"])
			main.player.call("start_with_skills", main.player.call("default_start_skills"))
			main._show_screen(null, false)
			main.enter_zone("the_stubble", "dross_gate")
			var stone: RuneStone = null
			for n: Node in main.get_tree().get_nodes_in_group("rune_stones"):
				stone = n as RuneStone
				if stone.stone_id == "stubble_waystone_runes":
					break
			if stone != null:
				main.player.global_position = stone.global_position + Vector3(2.2, 0.0, 0.0)
				main.player.set("rng", RandomNumberGenerator.new())
				main._read_stone(stone)
			main._harness()._shot_countdown = 40
		"seal-palette":
			main.player.call("set_affinities", ["water"])
			main.player.call("start_with_skills", main.player.call("default_start_skills"))
			var mine: Array = main.player.get("abilities")
			mine[0]["progress"] = 100.0
			(main.player.get("constructs") as Array).append({"tier": "vestige", "concept": "reach"})
			main.player.call("discover_rune", "UNI-05a", "")
			main._enter_town()
			main.open_seal(0, 0)
			main.screen.call("set_palette_tab", "universal")


## For a shot: set the carried construct of the open lock's tier and `concept` as its keystone (a word
## id, or one of the six old concept ids - the word it now is at that tier).
func _shot_keystone(concept: String) -> void:
	var need: String = str(main.player.call("pending_tier", (main.player.get("abilities") as Array)[int(main.player.call("sealing_index"))]))
	var wid: String = GameData.construct_word_id(need, concept)
	for g: Dictionary in main.player.call("construct_groups", need):
		if str(g["concept"]) == wid:
			main.screen.call("choose_construct", int(g["index"]))
			return
	print("shot: no %s of %s carried" % [need, concept])


## The level lock's shots (design/14 sections 11-12); see _setup_seal_shot.
func _setup_lock_shot(what: String) -> void:
	main.forced_biome = "scrubland"
	match what:
		"fit", "tip":
			# Brent 2026-11-04: a construct carries a word; the ones that do not fit are listed, greyed
			main.start_test_character("water")
			_shot_surge_first()
			for cid: String in ["FIR-1a", "FIR-6b", "ICE-1a"]:
				(main.player.get("constructs") as Array).append({"tier": "vestige", "concept": cid})
			main.open_seal(0)
			main.screen.call("place_rune", "WAT-1a", 1, 0)        # Flood, ring 1
			main.screen.call("finish_bond", 0, 1)
			_shot_keystone("WAT-4a")                         # the vestige of Heave chosen
			main.screen.call("deselect")
			if what == "fit":
				# the list scrolled to its end: the universal vestiges and the three that do not fit, greyed
				main._harness()._shot_countdown = 60
				main.get_tree().create_timer(0.3).timeout.connect(func() -> void:
					var sc: ScrollContainer = main.screen.find_child("KeystoneScroll", true, false) as ScrollContainer
					if sc != null:
						sc.scroll_vertical = 100000)
			if what == "tip":
				main._harness()._shot_countdown = 110
				main.get_tree().create_timer(0.3).timeout.connect(func() -> void:
					var b: Control = main.screen.find_child("LockConstruct_WAT-1a", true, false) as Control
					if b == null:
						print("shot: no Flood button")
						return
					var p: Vector2 = b.get_global_rect().get_center()
					var mv := InputEventMouseMotion.new()
					mv.position = p
					mv.global_position = p
					main.get_viewport().push_input(mv)
					Input.warp_mouse(p))
		"nofit":
			main.player.call("set_affinities", ["fire"])
			main.player.call("start_with_skills", main.player.call("default_start_skills"))
			((main.player.get("abilities") as Array)[0] as Dictionary)["progress"] = 100.0
			(main.player.get("constructs") as Array).clear()
			for cid2: String in ["WAT-1a", "WAT-4b"]:
				(main.player.get("constructs") as Array).append({"tier": "vestige", "concept": cid2})
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("select", 0)
		"main":
			main.start_test_character("water")
			_shot_surge_first()
			main.open_ethercosm()
			main.screen.call("select", 0)
		"open":
			# Brent 2026-11-03: lock 1 bound with ring 1 part-filled and open bonds, then lock 2 with the
			# skill's own rune bonded straight to a ring 2 rune and ring 2 far from full: Bind live
			main.start_test_character("water")
			_shot_surge_first()
			main.open_seal(0)
			main.player.call("word_add", 0, "WAT-1a", 0, 1)       # Flood on ring 1, joined to the skill
			main.player.call("word_add", 0, "WAT-4a", 0, 1)       # Heave on ring 1, joined to the skill
			_shot_keystone("acceleration")
			main.screen.call("bind_and_seal", 0.0)                # ring 1 binds 2 of 3, Flood's bonds open
			main.player.call("word_add", 0, "WAT-4b", 0, 2)       # Drown on ring 2, bonded straight to the skill
			main.player.call("word_add", 0, "WAT-6b", 2, 2)       # Settle on ring 2, off Heave
			_shot_keystone("reach")
			main.screen.call("deselect")
			main._harness()._shot_countdown = 70
		"first":
			# ring 1 part-filled (2 of 3 places), the vestige chosen and set: Bind live (Brent 2026-11-03)
			main.start_test_character("water")
			_shot_surge_first()
			main.open_seal(0)
			main.screen.call("place_rune", "WAT-1a", 1, 0)        # Flood, ring 1
			main.screen.call("place_rune", "WAT-4a", 1, 1)        # Heave, ring 1
			main.screen.call("finish_bond", 0, 1)                 # Flood joined to the skill
			main.screen.call("finish_bond", 0, 2)                 # Gush joined to the skill
			_shot_keystone("acceleration")
			main.screen.call("deselect")
		"keystone":
			# every place of ring 1 filled, the word closed, the vestige set over it: ready to bind
			main.start_test_character("water")
			_shot_surge_first()
			main.open_seal(0)
			main.screen.call("place_rune", "WAT-1a", 1, 0)        # Flood
			main.screen.call("place_rune", "WAT-4a", 1, 1)        # Heave
			main.screen.call("place_rune", "WAT-3b", 1, 2)        # Dry
			for pair: Array in [[0, 1], [0, 2], [1, 3], [1, 2]]:
				main.screen.call("finish_bond", int(pair[0]), int(pair[1]))
			_shot_keystone("acceleration")
			main.screen.call("deselect")
		"second":
			# lock 1 bound by the real flow (ring 1 full and closed, the vestige of Acceleration over it;
			# the bar refills - a test override), then lock 2: ring 1 reworked, all five places of ring 2
			# filled and the word closed, the remnant of Reach set over ring 2
			main.start_test_character("water")
			_shot_surge_first()
			main.open_seal(0)
			main.player.call("word_add", 0, "WAT-1a", 0)          # Flood
			main.player.call("word_add", 0, "WAT-4a", 0)          # Heave
			main.player.call("word_add", 0, "WAT-3b", 1)          # Dry on Flood
			main.player.call("word_toggle_link", 0, 1, 2)         # Flood - Heave: closed, ring 1 full
			_shot_keystone("acceleration")
			main.screen.call("bind_and_seal", 0.0)                # the vestige binds; the bar refills (test override)
			main.player.call("word_toggle_link", 0, 1, 2)         # rework ring 1: part Flood and Heave
			main.player.call("word_remove", 0, 3)                 # Dry out
			main.player.call("word_add", 0, "WAT-4b", 1, 1)       # Drown in its place, on ring 1, off Flood (Slack before v2)
			main.player.call("word_add", 0, "WAT-6b", 2)          # Settle off Heave, ring 2
			main.player.call("word_add", 0, "WAT-4b", 4)          # Drown off Settle, ring 2
			main.player.call("word_add", 0, "WAT-3b", 4)          # Dry off Settle, ring 2
			main.player.call("word_add", 0, "UNI-05a", 1)         # Expand off Flood, ring 2
			main.player.call("word_add", 0, "UNI-05a", 7)         # a second Expand off the first: ring 2 full
			main.player.call("word_toggle_link", 0, 4, 8)         # it and Settle: the word closes
			_shot_keystone("reach")
			main.screen.call("deselect")
			main._harness()._shot_countdown = 70
		"missing":
			# a new character's full skill and no vestige carried: the main page says what is missing,
			# and there is no way into the lock
			main._select_talent(0)
			main.player.call("set_affinities", ["water"])
			main.player.call("start_with_skills", main.player.call("default_start_skills"))
			(main.player.get("abilities") as Array)[0]["progress"] = 100.0
			(main.player.get("constructs") as Array).clear()
			main._enter_town()
			main.open_ethercosm()
			main.screen.call("select", 0)
