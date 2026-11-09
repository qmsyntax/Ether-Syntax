class_name MainShots
extends RefCounted
## The screenshot setups (--shot-ui=<state>): each puts the game into a named state with representative
## data and lets the harness's countdown take shots/shot.png. Part of the test harness (MainHarness.shots), built
## only by a shot run. Moved out of main.gd as it was (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


## Put the game into a named UI state with representative data, then screenshot it.
## States: title, town, shop, inventory, inventory-abilities, hud (mid-fight, hurt), hud-low (near death, reflux locked).
func _setup_ui_shot(which: String) -> void:
	main._shot_mode = true
	main._harness()._frames = 1000                      # disable the arena auto-shot; _shot_countdown drives this one
	main._harness()._shot_countdown = 40
	if which == "title":
		return
	if which == "enemies4":
		# the step 4 kinds together: a shield pair, a censer, a drummer behind them, the commander mid-sweep
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		for spec: Array in [[Vector3(-1.6, 0, -3.5), "pavise"], [Vector3(-0.2, 0, -3.9), "pavise"], [Vector3(2.4, 0, -5.5), "censer"],
				[Vector3(-3.0, 0, -8.5), "drummer"], [Vector3(-4.0, 0, -4.5), "grunt"], [Vector3(4.5, 0, -1.5), "commander"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		for e: Node in main.get_tree().get_nodes_in_group("enemies"):
			if str(e.get("kind")) == "grunt":
				e.call("add_status", "roused")
				e.call("add_status", "frenzied")
			if str(e.get("kind")) == "commander":
				var aim: Vector3 = ((main.player.global_position - (e as Node3D).global_position) * Vector3(1, 0, 1)).normalized()
				e.set("facing", aim)
				e.set("telegraph", {"kind": "cone", "radius": 6.0, "arc_deg": 90.0, "dir": aim, "frac": 0.6})
				e.call("_apply_facing")
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		return
	if which.begins_with("test-"):
		main._harness().seal_shots._setup_test_shot(which.trim_prefix("test-"))
		return
	if which.begins_with("role-"):
		main._harness().seal_shots._setup_role_shot(which.trim_prefix("role-"))
		return
	if which.begins_with("seal-"):
		main._harness().seal_shots._setup_seal_shot(which)
		return
	if which == "icons":
		# every skill's glyph in a slot, by affinity, with its name
		var sheet := Control.new()
		sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
		sheet.draw.connect(func() -> void:
			sheet.draw_rect(Rect2(Vector2.ZERO, sheet.size), Color(0.08, 0.08, 0.1))
			var row := 0
			for aff: Variant in GameData.affinity_ids():
				var col := 0
				UiDraw.text(sheet, Vector2(40.0, 96.0 + row * 150.0), str(GameData.affinity(str(aff)).get("label", aff)), 22, GameData.affinity_color(str(aff)).lightened(0.3))
				for id: Variant in GameData.abilities.keys():
					var ab: Dictionary = GameData.ability(str(id))
					if str(ab.get("affinity", "")) != str(aff):
						continue
					var slot := Rect2(150.0 + col * 206.0, 60.0 + row * 150.0, 84.0, 84.0)
					sheet.draw_rect(slot, UiTheme.INSET)
					sheet.draw_rect(slot, UiTheme.BRONZE_DIM, false, 2.0)
					sheet.draw_line(Vector2(slot.get_center().x, slot.position.y), Vector2(slot.get_center().x, slot.end.y), Color(1, 1, 1, 0.08), 1.0)
					sheet.draw_line(Vector2(slot.position.x, slot.get_center().y), Vector2(slot.end.x, slot.get_center().y), Color(1, 1, 1, 0.08), 1.0)
					UiDraw.icon(sheet, str(ab.get("icon", "drop")), slot.get_center(), 42.0, GameData.affinity_color(str(aff)).lightened(0.3))
					UiDraw.text(sheet, Vector2(slot.position.x, slot.end.y + 18.0), str(ab.get("name", id)), 14, UiTheme.TEXT)
					UiDraw.text(sheet, Vector2(slot.position.x, slot.end.y + 34.0), str(ab.get("kind", "")), 11, UiTheme.TEXT_DIM)
					col += 1
				row += 1)
		var layer := CanvasLayer.new()
		layer.layer = 100
		main.add_child(layer)
		layer.add_child(sheet)
		return
	if which == "props":
		# every real model in a row on bare ground, for looking at them up close
		main.session_part._select_talent(0)
		main.walk_out()
		for n: Node in main.level.get_children():
			if n is MeshInstance3D or (n is Node3D and n.get_child_count() > 0 and not (n is StaticBody3D)):
				pass
		var spot: Vector3 = main._zone.to_local(120.0, 150.0)
		main.player.global_position = main.level.to_global(spot)
		var ids: PackedStringArray = DirAccess.get_files_at("res://assets/models/props/")
		var i := 0
		for f: String in ids:
			if not f.ends_with(".glb"):
				continue
			var id: String = f.get_basename()
			var node: Node3D = RealProps.model(id, 1.0)
			node.position = spot + Vector3(-7.5 + float(i % 6) * 3.0, 0.0, -6.0 + float(i / 6) * 3.4)
			main.level.add_child(node)
			i += 1
		main.camera.size = 26.0 if not OS.get_cmdline_user_args().has("--close") else 9.0
		main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		main._cam_debug = true
		main.player.set_physics_process(false)
		return
	if which.begins_with("stubble-") and _setup_stubble_shot(which):
		return
	if which == "stubble" or which == "stubble-cut":
		# out of the Dross Gate, a little way down the road: the tip, the wall behind, the field ahead
		main.session_part._select_talent(0)
		main.player.look = CharacterLook.default_look()
		main.walk_out()
		main.player.global_position = main.level.to_global(main._zone.to_local(56.0, 30.0) if which == "stubble" else main._zone.to_local(214.0, 108.0))
		if OS.get_cmdline_user_args().has("--settle"):
			main._harness()._shot_countdown = 420             # long enough for shaders to compile, so the frame rate means something
		main.player.set("_facing", Vector3(0, 0, 1))
		main.player.set_physics_process(false)
		return
	if which == "earth":
		# an earth character set for a blow, two of their stones standing
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["earth"])
		main.player.grow_star(70.0)
		main.player.essence = 50.0
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		for spec: Array in [[Vector3(-1.5, 0, -5.5), "grunt"], [Vector3(1.2, 0, -6.0), "grunt"], [Vector3(5.5, 0, -3.5), "archer"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		var slab_def: Dictionary = GameData.ability("raise_slab")
		for spot: Array in [[Vector3(0, 0, -3.0), Vector3(0, 0, -1)], [Vector3(3.4, 0, -1.6), Vector3(1, 0, -0.5)]]:
			var stone: Node = main.player.raise_stone(main.player.global_position + (spot[0] as Vector3), spot[1], slab_def)
			stone.call("tick", 0.6)
			stone.set_physics_process(false)
		main.player.set("_facing", Vector3(0, 0, -1))
		main.player.set("_windup", {"braced": true, "release": false, "facing": Vector3(0, 0, -1)})
		main.player.set("_windup_t", 0.25)
		main.player.set("_windup_total", 0.6)
		for e: Node in main.get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		main.player.rotation.y = 0.0
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		return
	if which == "wind":
		# a wind character on the move: pips over the bar, an enemy thrown aloft
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["wind"])
		main.player.grow_star(70.0)
		main.player.essence = 50.0
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		main.player.pips = 7
		for spec: Array in [[Vector3(-2.5, 0, -3.0), "grunt"], [Vector3(1.0, 0, -4.0), "grunt"], [Vector3(3.5, 0, -1.5), "archer"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = main.get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "aloft")
		main.player.hovered = foes[1]
		for e: Node in foes:
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		return
	if which == "fire":
		# a fire character running hot: burning enemies, a flame trail, the heat readout
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["fire"])
		main.player.grow_star(70.0)
		main.player.essence = 50.0
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		(main.player.reflux_by as Dictionary)["fire"] = 72.0
		for spec: Array in [[Vector3(-2.0, 0, -3.0), "grunt"], [Vector3(-0.6, 0, -3.4), "grunt"], [Vector3(3.0, 0, -2.0), "brute"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = main.get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "alight", 4, main.player)
		foes[1].call("add_status", "alight", 1, main.player)
		foes[2].call("add_status", "alight", 2, main.player)
		var trail := GroundZone.new()
		trail.from = main.player.global_position + Vector3(0, 0, 4.2)
		trail.to = main.player.global_position
		trail.life = 99.0
		trail.color = GameData.affinity_color("fire")
		main.level.add_child(trail)
		trail.set_physics_process(false)
		main.player.hovered = foes[0]
		# no tooltip here: it would sit on top of the heat readout this picture exists to show
		for e: Node in foes:
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		return
	if which == "refusal" or which == "refusal-locked":
		# a refused cast (combat review R4d): a water character presses Breaker at a grunt in reach with too
		# little essence (refusal), or with water locked by reflux (refusal-locked); the slot flashes and the
		# reason shows beside the cursor, which is said to be on the grunt
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["water"])
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		main.factory_part._spawn_enemy("grunt", Vector3(0.8, 0, -2.4), 1.0)
		var foe: Node3D = main.get_tree().get_nodes_in_group("enemies")[0]
		main.player.hovered = foe
		main.player.essence = 2.0 if which == "refusal" else 18.0
		if which == "refusal-locked":
			(main.player.reflux_by as Dictionary)["water"] = 100.0
			(main.player.locked_by as Dictionary)["water"] = true
		foe.set_physics_process(false)
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		main._harness()._shot_countdown = 60
		main._harness()._shot_late = func() -> void:
			main.hud.debug_cursor = main.camera.unproject_position(foe.global_position + Vector3.UP * 1.0)
			main.player.press_slot(1)
		return
	if which == "endurance" or which == "endurance-refused":
		# the endurance bar under the feet (Brent 2026-11-03, balance.json endurance): one step spent
		# (endurance), or short of a step with the step refused at the cursor (endurance-refused)
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["water"])
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		main.factory_part._spawn_enemy("grunt", Vector3(0.8, 0, -3.4), 1.0)
		var grunt: Node3D = main.get_tree().get_nodes_in_group("enemies")[0]
		grunt.set_physics_process(false)
		var most: float = float(main.player.endurance_max())
		main.player.endurance = most - GameData.num("endurance", "step_cost") if which == "endurance" else GameData.num("endurance", "step_cost") * 0.45
		main.player.set_physics_process(false)
		main._harness()._shot_countdown = 60
		main._harness()._shot_late = func() -> void:
			main.hud.debug_cursor = main.camera.unproject_position(main.player.global_position + Vector3(1.6, 0, 0.4))
			if which == "endurance-refused":
				main.player.sidestep()
		return
	if which == "combat":
		# the combat rules on one screen: a brute mid-slam, an archer aiming, a staggered grunt,
		# a crouched harrier, and a second rank waiting for a slot
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.grow_star(70.0)
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		for spec: Array in [[Vector3(2.6, 0, -1.2), "brute"], [Vector3(-7.0, 0, -8.0), "archer"], [Vector3(-2.2, 0, -1.6), "grunt"],
				[Vector3(5.0, 0, 4.5), "harrier"], [Vector3(-4.6, 0, 2.6), "grunt"], [Vector3(0.5, 0, -5.0), "grunt"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = main.get_tree().get_nodes_in_group("enemies")
		foes[0].set("_windup", 0.45)                       # the slam, most of the way through
		foes[0].call("_update_melee_telegraph")
		foes[0].call("take_poise", 60.0)
		foes[1].set("telegraph", {"kind": "line", "to": main.player.global_position, "locked": true, "frac": 0.8})
		foes[2].call("stagger", 5.0)
		(foes[2].get("body") as Body).apply_damage(120.0)
		foes[3].set("telegraph", {"kind": "swing", "interruptible": true})
		main.player.hovered = foes[2]
		for e: Node in foes:
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		return
	if which == "skills":
		# a water + lightning character in the arena: marks, a Soaked enemy, a stunned one, a block
		main.forced_biome = "scrubland"
		main.session_part._select_talent(0)
		main.player.set_affinities(["water", "lightning"])
		main.player.grow_star(70.0)
		main.player.essence = 60.0
		main._show_screen(null, false)
		main.enter_arena()
		main.rest_timer = 9999.0
		for spec: Array in [[Vector3(-3.0, 0, -3.5), "grunt"], [Vector3(0.5, 0, -4.5), "grunt"], [Vector3(3.5, 0, -2.5), "brute"], [Vector3(-1.0, 0, -7.0), "grunt"]]:
			main.factory_part._spawn_enemy(str(spec[1]), spec[0], 1.0)
		var foes: Array = main.get_tree().get_nodes_in_group("enemies")
		foes[0].call("add_status", "live", 2)
		foes[0].call("add_status", "soaked")
		foes[1].call("add_status", "live", 1)
		foes[2].call("stun", 5.0)
		foes[2].call("add_status", "soaked")
		(foes[1].get("body") as Body).apply_damage(90.0)
		main.player.hovered = foes[0]
		main.hud.debug_tip = "slot:3"
		for e: Node in foes:
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		main.player.call("_refresh_highlights")
		return
	if which == "nav" or which.begins_with("nav-"):
		# the common walker's navigation mesh drawn over the passage, at the first doorway: --shot-ui=nav-city
		main.forced_biome = which.trim_prefix("nav-") if which.begins_with("nav-") else "mountain"
		main.session_part._select_talent(0)
		main._show_screen(null, false)
		main._enter_dungeon()
		main.player.global_position = main.level.to_global(Vector3(0.0, 0.0, -main.ch_len - 2.0))
		(main.level.get_node("Nav") as LevelNav).show_debug(true)
		main.player.set_physics_process(false)
		return
	if which.begins_with("biome-"):
		# the passage in a given biome, two walls in: --shot-ui=biome-snow
		main.forced_biome = which.trim_prefix("biome-")
		main.session_part._select_talent(0)
		main._show_screen(null, false)
		main._enter_dungeon()
		main.sealed = true
		main.cleared = 1
		# as it would be after wall 1: the doorway behind you has opened, the one ahead is shut
		(main.barriers[2] as Node).queue_free()
		main.barriers.erase(2)
		(main.gates[2] as Node).call("set_open", true, true)
		main.player.global_position = main.level.to_global(Vector3(1.0, 0.0, -2.35 * main.ch_len))
		main._activate(2)
		for e: Node in main.get_tree().get_nodes_in_group("enemies"):
			e.set_physics_process(false)
		main.player.set_physics_process(false)
		return
	if which.begins_with("create"):
		# the creation screen at a given step: create-1 .. create-4
		# fixed offers so the picture does not depend on the dice: a common, a rare and a three-slot prime
		main.screen.set("offers", [{"talent_id": "grudge", "affinities": ["earth"]}, {"talent_id": "tenth_strike", "affinities": ["wind", "fire"]},
			{"talent_id": "one_percent_lifesteal", "affinities": ["water", "lightning", "earth"]}] as Array[Dictionary])
		main.screen.call("set_spec", {"name": "Maren", "identity": "woman", "look": CharacterLook.default_look(), "talent_id": "tenth_strike", "affinities": ["wind", "fire"],
			"skills": ["cutting_gust", "flashover"]})
		main.screen.call("_go", int(which.get_slice("-", 1)) - 1)
		if which.ends_with("-face"):
			main.screen.call("set_zoom", true)
			main._harness()._shot_countdown = 90                # let the camera ease in
		return
	main.session_part._select_talent(0)
	var inv: Inventory = main.player.inventory
	main.player.money = 1840
	for id: String in ["dim_mote", "river_stone", "serrated_dagger", "invader_cleaver", "brute_tusk", "brute_tusk", "husk_plate", "sinew_cord", "sinew_cord", "commander_sigil", "delver_frame"]:
		inv.add(id)
	inv.equip("dim_mote")
	inv.equip("serrated_dagger")
	main.player.refresh_gear()
	main.player.grow_star(38.0)
	(main.player.constructs as Array).append({"tier": "vestige", "concept": "acceleration"})
	(main.player.constructs as Array).append({"tier": "vestige", "concept": "tension"})
	var abilities: Array = main.player.abilities
	abilities[0]["progress"] = 100.0
	abilities[1]["progress"] = 64.0
	abilities[2]["progress"] = 23.0
	(main.player.body as Body).apply_damage(31.0)
	main.player.arm_right = 62.0
	main._last_payout = 3000
	main.delves = 2
	main.day = 4
	match which:
		"town":
			main._enter_town()
		"town-gate", "town-folk":
			# the north street from inside the Dross Gate, or the west side with the trainer and the passage door
			main._enter_town("dross_gate" if which == "town-gate" else "passage")
			if which == "town-folk":
				main.player.global_position = main.level.to_global(Vector3(-11.0, 0.0, -1.5))
			main.player.set("_facing", Vector3(0, 0, -1))
			if OS.get_cmdline_user_args().has("--settle"):
				main._harness()._shot_countdown = 300
		"stations":
			# the craft row along the south side: rendering block, tanning vats, forge
			main._enter_town()
			main.player.global_position = main.level.to_global(Vector3(3.0, 0.0, 12.8))
			main.player.set("_facing", Vector3(0, 0, 1))
			main._harness()._shot_countdown = 200
		"craft", "craft-done", "craft-item":
			# at the forge with what an iron knuckle needs: before the combine, after it, and the result worn
			main._enter_town()
			main.player.global_position = main._town.person("smith").global_position + Vector3(1.4, 0.0, -0.8)
			(main.player.craft_skill as Dictionary)["smithing"] = 9
			(main.player.craft_known as Array).append_array(Crafting.recipes_of("smithing"))
			for id: String in ["smiths_hammer", "steel_billet", "steel_billet", "barrow_fitting_mould", "barrow_quench_oil", "cured_hide_grip_wrap", "scrap_iron", "scrap_iron", "flux_salt"]:
				inv.add(id)
			main._harness()._shot_countdown = 120
			main.talk_to("smith")
			main.open_crafting("forge")
			main.screen.set("selected", "r_iron_knuckles")
			main.screen.call("rebuild")
			if which != "craft":
				# certain at this skill, so the picture does not depend on the dice
				(main.player.craft_skill as Dictionary)["smithing"] = 29
				main.screen.call("combine", "r_iron_knuckles")
			if which == "craft-item":
				main.close_screen()
				main.close_screen()
				main.open_inventory()
				main.screen.call("show_item", "iron_knuckles", "")
		"town-talk":
			main._enter_town()
			main.player.global_position = main._town.person("trainer").global_position + Vector3(1.6, 0.0, 0.5)
			main.player.skill_points = 3
			main._harness()._shot_countdown = 120                 # let the trainer turn to face you
			main.talk_to("trainer")
		"skill-tree", "skill-tree-field":
			# a water + lightning character: two roots picked, one tier-2 learned, points to spend
			main.player.set_affinities(["water", "lightning"])
			main.player.start_with_skills(["riptide_lash", "stepped_leader"])
			main.player.learn("drench")
			main.player.skill_points = 3
			if which == "skill-tree":
				main._enter_town()
				main.player.global_position = main._town.person("trainer").global_position + Vector3(1.6, 0.0, 0.5)
				main.talk_to("trainer")
				main.open_skill_tree(true)
			else:
				main._show_screen(null, false)
				main.enter_arena()
				main.rest_timer = 9999.0
				main.open_skill_tree(false)
				main.get_tree().paused = false         # it pauses out here; the shot countdown has to tick
			main.screen.call("select", "standing_pool")
		"shop":
			main._enter_town()
			main.open_shop()
		"saves":
			main._enter_town()
			main.open_saves()
		"menu-town", "menu-field", "menu-new", "menu-load", "menu-save", "menu-settings", "menu-confirm", "menu-test":
			_setup_menu_shot(which)
		"inventory", "inventory-abilities":
			# some of the new slots filled and some left empty, and a piece in the pack to compare
			for id: String in ["oilcloth_hood", "work_gloves", "chalk_slate", "hobnailed_boots", "cooling_coil"]:
				inv.add(id)
			for id: String in ["oilcloth_hood", "work_gloves", "river_stone", "cooling_coil"]:
				inv.equip(id)
			main.player.refresh_gear()
			main._enter_town()
			main.open_inventory()
			main.screen.call("show_item", "hobnailed_boots", "")     # the description has its own panel; it covers nothing
			if which == "inventory-abilities":
				main._harness().seal_shots._shot_lock_word()                          # its locked word shows on Breaker's row
				main.screen.set("_tab", "soul")
				main.screen.call("rebuild")
		"ethercosm", "ethercosm-2":
			if which == "ethercosm-2":
				# a later character: two stars, a bound vestige, a rearranged bar
				main.player.grow_star(99.0)
				main.player.set("_latent_aura", 1000.0)
				main.player.try_ascend()
				main.player.grow_star(33.0)
				# a vestige bound in the past (the word itself is set by _shot_lock_word below)
				var held: Array = main.player.constructs
				if not held.is_empty():
					abilities[0]["bound"] = [{"stage": 0, "tier": "vestige", "concept": str((held[0] as Dictionary)["concept"])}]
					held.remove_at(0)
				abilities[0]["stage"] = 1
				abilities[0]["progress"] = 45.0
				abilities[1]["progress"] = 100.0
				inv.add("paired_mote")
				inv.equip("paired_mote")
				main.player.refresh_gear()
				main.player.assign_slot(3, 2)
			main._harness().seal_shots._shot_lock_word()                              # Breaker's ring becomes its word's chain
			main._enter_town()
			main.open_ethercosm()
		"runes-locked", "runes-locking", "runes", "seal-forming", "seal-traits", "seal-drown-self", "seal-drown-flood", "seal-drown-surge", \
				"seal-drag", "seal-refused", "seal-bond", "seal-convert", \
				"seal-discovered", "seal-palette":
			main._harness().seal_shots._setup_seal_shot(which)
		"nether", "nether-words":
			main._show_screen(null, false)
			main._enter_dungeon()
			main.nether.clear()
			var base: Vector3 = Vector3(0.0, 0.0, -4.0)
			var first_c: Node = null
			# nether-words (Brent 2026-11-04): constructs carry words - a water vestige (Flood), a water remnant
			# (Undertow), a water spirit (Tidewrack) and a universal spirit (Vortex), in their colours
			var specs: Array = [[Vector3(3.5, 0, -4.5), "vestige", "tension"], [Vector3(-4.0, 0, -6.0), "vestige", "acceleration"], [Vector3(1.0, 0, -9.5), "remnant", "piercing"]] \
				if which == "nether" else [[Vector3(3.5, 0, -4.5), "vestige", "WAT-1a"], [Vector3(-4.0, 0, -5.5), "remnant", "undertow"],
					[Vector3(1.0, 0, -10.0), "spirit", "tidewrack"], [Vector3(6.0, 0, -9.0), "spirit", "vortex"]]
			for spec: Array in specs:
				var made: Node = main.nether.spawn_construct(base + (spec[0] as Vector3), str(spec[1]), str(spec[2]), false)
				if first_c == null:
					first_c = made
			for wpos: Vector3 in [Vector3(2, 0, 1), Vector3(-2.5, 0, -2), Vector3(5, 0, -2), Vector3(-5, 0, -8), Vector3(0.5, 0, -5)]:
				main.nether.spawn_wisp(base + wpos, "water" if int(wpos.x * 10.0) % 2 == 0 else "plain")
			main.toggle_projection()
			main.nether.projection.global_position = main.player.global_position + main.level.to_global(Vector3(1.5, 0, -3.5)) - main.level.global_position
			main.nether.projection.set("input_blocked", true)
			main.nether.projection.call("take_hit", 5.0, false, null)
			(first_c.get("body") as Body).apply_damage(35.0)
			main.nether.projection.set("hovered", first_c)
			first_c.call("set_highlight", 1)
		"temper":
			# a two-affinity character part-way through its tempering, a little the worse for it
			main.player.set_affinities(["water", "earth"])
			main._enter_town()
			var known: Dictionary = main.player.tempering
			known["callus"] = {"stage": 1, "progress": 43.75}
			known["slow_tide"] = {"stage": 0, "progress": 50.0}
			known["bedrock_bones"] = {"stage": 2, "progress": 0.0}
			(main.player.body as Body).add_wound("temper_strain", "Tempering strain", 20.0, 20.0, true, true)
			main.open_tempering()
		"ascend-offer", "ascend-boost", "ascend-ethercosm":
			# the ascension (Brent 2026-10-24): a fire character with four skills at stages 2/1/1/0
			# ascends; the offer (a hybrid with fire as a parent, and a random one), then the boosts,
			# then the ethercosm showing a boosted skill, base in brackets
			_shot_ascension(which)
		"hud-dual":
			# a two-affinity character mid-fight: both kits on the bar, one affinity running hot
			main.player.set_talent("furnace_gut")
			main.player.set_affinities(["fire", "earth"])
			main.player.grow_star(60.0)
			main.player.essence = 55.0
			main._show_screen(null, false)
			main._enter_dungeon()
			(main.player.reflux_by as Dictionary)["fire"] = 84.0
			(main.player.reflux_by as Dictionary)["earth"] = 31.0
			main.player.ui_blocked = true
		"hud", "hud-low":
			main._show_screen(null, false)
			main._enter_dungeon()
			main.sealed = true
			main.cleared = 2
			main.bank = 600
			main.player.global_position = main.level.to_global(Vector3(0.0, 0.0, -3.2 * main.ch_len))
			main._activate(3)
			main.player.essence = float(main.player.essence_max) * 0.55
			main.player.reflux = 63.0
			for id: String in ["brute_tusk", "serrated_dagger"]:
				Main.PlayerScript.spawn_pickup(main.level, id, main.player.global_position + Vector3(main.rng.randf_range(-3, 3), 0, main.rng.randf_range(1.5, 3.5)))
			var first: Node = main.get_tree().get_nodes_in_group("enemies")[0]
			(first.get("body") as Body).apply_damage(95.0)
			main.player.attack_target = first
			if which == "hud-low":
				(main.player.body as Body).add_wound("hit_1", "Cracked ribs", 14.0, 8.0)
				(main.player.body as Body).add_wound("lost_arm", "Lost arm", 25.0, 8.0, false)
				(main.player.body as Body).apply_damage(52.0)
				main.player.reflux = 100.0
				main.player.reflux_locked = true
				main.player.arm_right_lost = true
				main.player.essence = 6.0
			if which == "hud":
				main._harness().seal_shots._shot_lock_word()                          # the slot tooltip names what the locked word does
			main.hud.debug_tip = "slot:0" if which == "hud" else "health"
			# freeze the fight so the picture is stable
			for e: Node in main.get_tree().get_nodes_in_group("enemies"):
				e.set_physics_process(false)
			main.player.set_physics_process(false)
			main.player.call("_refresh_highlights")


## The game menu's screenshots (--shot-ui=menu-...): the menu in town and in the field (Save
## disabled out there), the new game view with the test characters, Load and Save (from a folder
## of shot saves, never the real ones), Settings, the question before leaving a real character, and
## the menu over a test character.
func _setup_menu_shot(which: String) -> void:
	main.player.char_name = "Maren"
	# a shot run is sandboxed (UserFiles.sandbox in _ready: an empty folder of its own), never the real saves
	main.save_to_slot(0)                         # an autosave and slot 2, so Load has something to list
	main.save_to_slot(2)
	if which == "menu-field":
		main.walk_out()
	elif which == "menu-test":
		main.start_test_character("fire")
	else:
		main._enter_town()
	match which:
		"menu-new":
			main.screens_part.open_game_menu("new")
		"menu-settings":
			main.screens_part.open_game_menu("settings")
		"menu-load", "menu-save":
			main.screens_part.open_game_menu()
			main.menu_open_saves(which.trim_prefix("menu-"))
		"menu-confirm":
			main.screens_part.open_game_menu()
			(main.screen as UiScreen).confirm_leave("Quit to title", main.quit_to_title)
		_:
			main.screens_part.open_game_menu()
	main.get_tree().paused = false               # the menu pauses; the shot countdown has to tick


## The ascension shots: "ascend-offer" (step 1), "ascend-boost" (step 2, an affinity chosen, one
## skill set to Reach), "ascend-ethercosm" (settled; the boosted skill selected in the ethercosm).
func _shot_ascension(which: String) -> void:
	main.session_part._select_talent(0)
	main.player.set_affinities(["fire"])
	var abilities: Array = main.player.abilities
	if abilities.size() < 4:
		for id: String in GameData.skill_tree_of("fire"):
			if abilities.size() >= 4:
				break
			main.player.learn(id)
	var stages: Array[int] = [2, 1, 1, 0]
	for i: int in mini(stages.size(), abilities.size()):
		(abilities[i] as Dictionary)["stage"] = stages[i]
	(main.player.rng as RandomNumberGenerator).seed = 20261024
	main._enter_town()
	main.player.grow_star(99.0)
	main.player.set("_latent_aura", 100000.0)
	main.player.try_ascend()                  # opens the ascension screen (_on_ascended)
	main.get_tree().paused = false                  # it pauses; the shot countdown has to tick
	if which == "ascend-offer":
		return
	var offer: Array = (main.player.ascension_pending as Dictionary).get("offer", [])
	main.screen.call("choose", str(offer[0]) if not offer.is_empty() else "")
	main.screen.call("set_aspect", 1, "reach")
	if which == "ascend-boost":
		return
	main.screen.call("confirm")
	main.open_ethercosm()
	main.screen.call("select", 1)


## Screenshot setups for the populated Stubble (windowed): --shot-ui=stubble-<what>. Each waits for
## the moment it exists to show (a wind-up, a charge, a rise) and then saves shots/shot.png.
##   overview, map, nether, swallow, cellar, herd, lurker, gleaner, scald, and fight-<kind>.
func _setup_stubble_shot(which: String) -> bool:
	var what: String = which.trim_prefix("stubble-")
	main._harness()._shot_countdown = 0                              # the watch below takes the shot, at its moment
	main.session_part._select_talent(0)
	main.player.look = CharacterLook.default_look()
	main.walk_out()
	main.player.bot = true                         # it is not the subject: nothing it takes counts
	main.player.set_physics_process(false)
	var stand := func(x: float, y: float) -> void:
		main.player.global_position = main.level.to_global(main._zone.to_local(x, y))
		main._reveal()
	var near_kind := func(kind: String) -> Node:
		for n: Node in main.get_tree().get_nodes_in_group("enemies"):
			if str(n.get("kind")) == kind:
				return n
		return null
	main._cam_zoom_target = 0.55
	main.cam_zoom = 0.55
	var until: Callable = func() -> bool: return false
	var go: Callable = func() -> void: pass         # what starts the moment, once the shaders have settled
	match what:
		"overview":
			# straight down on the whole zone, north up: the layout, not the look
			stand.call(120.0, 80.0)
			main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			main.camera.size = 168.0
			main.camera.far = 2000.0
			main._cam_debug = true
			main.player.visible = false
			main.hud.visible = false
			var north: Vector3 = main.level.global_transform.basis * Vector3(0, 0, -1)
			var mid: Vector3 = main.level.to_global(main._zone.to_local(120.0, 80.0))
			cam_shot = Transform3D.IDENTITY.looking_at(Vector3.DOWN, north).translated(mid + Vector3.UP * 150.0)
			main._env.fog_enabled = false                  # from this high the fog would hide everything
			# labels over the layout: camps (red), herds (green), lurker patches (brown), mouths and landmarks
			var tags: Array = []
			for c: Dictionary in main._zone.def.get("camps", []):
				tags.append([c["at"], str(c.get("name", "")), Color(0.55, 1.0, 0.5) if bool(c.get("herd", false)) else Color(1.0, 0.45, 0.35)])
			for p2: Dictionary in main._zone.def.get("lurker_patches", []):
				tags.append([p2["at"], "lurker", Color(0.85, 0.65, 0.4)])
			for e3: Dictionary in main._zone.def.get("entrances", []):
				tags.append([e3["at"], str(e3.get("name", "")), Color(1.0, 0.85, 0.4)])
			for m: Dictionary in main._zone.def.get("landmarks", []):
				tags.append([m["at"], str(m.get("name", "")), Color(0.9, 0.9, 1.0)])
			tags.append([[222, 112], "The Cut House", Color(1.0, 0.85, 0.4)])
			var labels := ShotLabels.new()
			for t: Array in tags:
				labels.items.append([main.level.to_global(main._zone.to_local(float(t[0][0]), float(t[0][1]))), t[1], t[2]])
			labels.camera = main.camera
			var lay := CanvasLayer.new()
			lay.layer = 90
			main.add_child(lay)
			lay.add_child(labels)
		"map":
			# a walk's worth of the zone seen: the road, the well, the herd, the tree, the Cut track
			for p: Array in [[40, 6], [70, 14], [100, 18], [130, 24], [160, 30], [188, 44], [200, 80], [212, 108], [98, 70], [120, 110], [150, 96], [170, 130], [72, 130], [52, 96]]:
				stand.call(float(p[0]), float(p[1]))
			stand.call(150.0, 96.0)
			main.field_camps.wake_camp("tree_camp")
			main.field_camps.tick(0.016)
		"nether":
			stand.call(96.0, 74.0)
			main.player.bot = false
			main.player.set_physics_process(true)
			main.nether.enter()
			main.nether.projection.global_position = main.level.to_global(main._zone.to_local(99.0, 68.0))
			main.nether.projection.set("hp_max", 1.0e6)            # the screenshot is of the place, not of a fight
			main.nether.projection.set("hp", 1.0e6)
			main.nether.projection.set("input_blocked", true)
			main._cam_zoom_target = 0.25
			main.cam_zoom = 0.25
		"lineup":
			# every beast in a row beside you, standing still, at the game's camera
			stand.call(140.0, 50.0)
			var i: int = 0
			for kind: String in ["chaff_wren", "kettle_beetle", "gleaner", "ditch_hound", "sod_lurker", "burr_hog", "wirehorn", "thornback"]:
				var e: Node3D = _spawn_shot_beast(kind, Vector3(-7.0 + 2.1 * float(i), 0, -3.0 - 0.6 * float(i)))
				e.set("target", null)
				e.set("calm", false)
				e.set("buried", false)
				if kind == "sod_lurker":
					e.call("rise")
					e.set("_rise_t", -1.0)
					((e.get("_rig")) as Node3D).position.y = 0.0
				i += 1
			main._cam_zoom_target = 0.35
			main.cam_zoom = 0.35
		"swallow":
			stand.call(169.0, 142.0)
		"cellar":
			stand.call(69.0, 137.0)
		"herd":
			stand.call(119.0, 131.0)
			main.player.set("_facing", Vector3(0, 0, 1))
			go = func() -> void: main.field_camps.wake_camp("the_herd")
			main._cam_zoom_target = 0.2
			main.cam_zoom = 0.2
			until = func() -> bool:
				for n: Node in main.field_camps.members_of("the_herd"):
					if str(n.get("_special")) == "charge" and float(n.get("_windup")) < 0.4:
						return true
				return false
		"lurker":
			stand.call(128.6, 72.0)
			main.player.bot = false
			go = func() -> void:
				stand.call(128.8, 79.2)
				main.player.set_physics_process(true)
			until = func() -> bool:
				for p: Dictionary in main.field_camps.patches:
					var l: Node = p["lurker"]
					if l != null and is_instance_valid(l) and bool(l.call("is_rising")) and float(l.get("_rise_t")) < 0.3:
						return true
				return false
		"gleaner":
			stand.call(112.0, 36.0)
			go = func() -> void:
				stand.call(108.0, 53.0)
				main.field_camps.tick(0.016)
			main._cam_zoom_target = 0.15
			main.cam_zoom = 0.15
			var gl_frames: Array = [0]
			until = func() -> bool:
				var g: Node = near_kind.call("gleaner")
				gl_frames[0] = int(gl_frames[0]) + 1
				return g != null and bool(g.call("is_running")) and int(gl_frames[0]) > 45
		"scald":
			stand.call(140.0, 50.0)
			var at: Array = [0]
			go = func() -> void:
				var b: Node3D = _spawn_shot_beast("kettle_beetle", Vector3(1.5, 0, -1.0))
				b.call("take_hit", 99999.0, false, null)
			until = func() -> bool:
				at[0] = int(at[0]) + 1
				return int(at[0]) > 25
		_:
			if not what.begins_with("fight-"):
				return false
			var kind: String = what.trim_prefix("fight-")
			stand.call(140.0, 50.0)
			main.player.set("_facing", Vector3(0, 0, -1))
			var offs: Array = [Vector3(0, 0, -5)]
			if kind == "chaff_wren":
				offs = [Vector3(-2, 0, -5), Vector3(2, 0, -5), Vector3(0, 0, -6), Vector3(3, 0, -3)]
			elif kind == "ditch_hound":
				offs = [Vector3(-3, 0, -4), Vector3(3, 0, -4)]
			elif kind == "burr_hog" or kind == "thornback":
				offs = [Vector3(0, 0, -9)]
			elif kind == "wirehorn":
				offs = [Vector3(0, 0, -1.9)]
			var made: Array = []
			go = func() -> void:
				for o: Vector3 in offs:
					var e: Node3D = _spawn_shot_beast(kind, o)
					made.append(e)
					if e.has_method("provoke"):
						e.call("provoke", main.player)
					if kind == "wirehorn":
						e.set("facing", Vector3(0, 0, -1))   # its back to you: the kick
			until = func() -> bool:
				for e2: Node in made:
					if not is_instance_valid(e2):
						continue
					if kind == "burr_hog" or kind == "thornback":
						if str(e2.get("_special")) == "charge" and float(e2.get("_windup")) < 0.6:
							return true
					elif kind == "ditch_hound":
						if float(e2.get("_windup")) >= 0.0 and bool(e2.call("is_at_targets_back")):
							return true
					elif kind == "wirehorn":
						if bool(e2.get("_kick")) and float(e2.get("_windup")) >= 0.0 and float(e2.get("_windup")) < 0.2:
							return true
					elif float(e2.get("_windup")) >= 0.0 and float(e2.get("_windup")) < 0.25:
						return true
				return false
	var watch := ShotWatch.new()
	watch.main_node = main
	watch.until = until
	watch.go = go
	watch.cam = cam_shot
	watch.settle = 420 if OS.get_cmdline_user_args().has("--settle") else 90
	main.add_child(watch)
	return true


## A camera a shot holds fixed (the overview), or null.
var cam_shot: Variant = null


## A beast for a screenshot, `offset` metres from the player (level frame), awake.
func _spawn_shot_beast(kind: String, offset: Vector3) -> Node3D:
	var e: CharacterBody3D = Beast.new()
	e.call("setup", kind, main.player, 0.8)
	e.position = main.level.to_local(main.player.global_position) + offset
	main.level.add_child(e)
	return e


## Text pinned to world points, for the overview shot.
class ShotLabels extends Control:
	var items: Array = []
	var camera: Camera3D

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		for it: Array in items:
			var p: Vector2 = camera.unproject_position(it[0])
			draw_circle(p, 5.0, Color(0, 0, 0, 0.8))
			draw_circle(p, 3.5, it[2])
			UiDraw.outlined(self, p + Vector2(8, 5), str(it[1]), 15, it[2])


## Waits (in frames) for a screenshot's moment, then takes it. At most `left` frames.
class ShotWatch extends Node:
	var main_node: Node
	var until: Callable
	var go: Callable
	var cam: Variant = null
	var settle := 90
	var left := 1500
	var _armed := -1

	func _process(_delta: float) -> void:
		if cam is Transform3D:
			(main_node.get("camera") as Camera3D).global_transform = cam
		settle -= 1
		left -= 1
		if settle == 0 and go.is_valid():
			go.call()
			return
		if _armed > 0:
			_armed -= 1
			if _armed == 0:
				main_node.call("_save_shot")
			return
		if settle <= 0 and (left <= 0 or bool(until.call())):
			_armed = 2
