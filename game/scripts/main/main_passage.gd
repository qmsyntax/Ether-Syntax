class_name MainPassage
extends MainLevel
## The assault passage (main.state "dungeon"): its corridor of walls and gates, the seal behind you, each wall
## of enemies as you reach it, the exits that open past the gate wall, the rent while you stand inside, the
## spoils carried out and the exit's rewards, and the way through a doorway before the navigation mesh is baked
## (route). Rules follow design/01-systems-bible LAW 6b [C]; the numbers are on the node, read from balance.json
## "passage". Moved out of main.gd as it was (docs/architecture/main-split.md).

func tick(delta: float) -> void:
	var local: Vector3 = main.level.to_local(main.player.global_position)
	var depth: float = -local.z
	var fighting: bool = main.current > main.cleared

	if not fighting:
		var next_c: int = main.cleared + 1
		if next_c <= main.chambers and depth > float(next_c) * main.ch_len + 1.5:
			if not main.sealed:
				main.sealed = true
				_add_barrier(1)
				main.player.call("note", "Stone grinds shut behind you. The entrance is sealed.")
			_activate(next_c)
			_set_dungeon_banner()
			return
		if main.sealed:
			# The town clock does not stop because you are underground.
			_charge_rent(main.dungeon_rent_per_second, delta)
	elif main.get_tree().get_nodes_in_group("enemies").is_empty():
		_on_wall_cleared()

	_set_dungeon_banner()

	if main._bot_mode:
		main._harness().bot_dungeon_tick()


## The keys in the passage: skills, ascend, the seal, and interact (a rune stone, an exit).
func handle_input(event: InputEvent) -> void:
	if main._cast_from_hotbar(event):
		pass
	elif event.is_action_pressed("ascend"):
		main.player.call("try_ascend")
	elif event.is_action_pressed("bind"):
		main.open_seal_first_ready()
	elif event.is_action_pressed("healer"):
		main.player.call("note", "No healer in here. The entrance is sealed.")
	elif event.is_action_pressed("interact"):
		if main._rune_stone_in_reach() != null:
			main._read_stone(main._rune_stone_in_reach())
		elif _pad_in_reach():
			_extract()
		elif main.pads.is_empty():
			main.player.call("note", "No exit yet. %d more walls." % maxi(0, main.gate_at - main.cleared))
		else:
			main.player.call("note", "Stand on a glowing exit to leave.")


func where() -> String:
	return "The passage  -  wall %d of %d  -  spoils $%d" % [main.cleared, main.chambers, main.bank]


func enter_passage() -> void:
	main._return_to = {}
	if not bool(main.player.call("can_afford", main.ticket_price)):
		main.player.call("note", "No one will sell you a ticket on that much debt.")
		return
	main.player.call("charge", main.ticket_price)
	main._show_screen(null, false)
	_enter_dungeon()


func _enter_dungeon() -> void:
	# Rotated so the corridor runs straight "up" the isometric screen: W alone walks it.
	main.factory_part._new_level(45.0)
	var total: float = float(main.chambers + 1) * main.ch_len
	var mid_z: float = -total * 0.5
	var bcfg: Dictionary = GameData.balance["biomes"]
	main.factory_part._use_biome(bcfg["passage"])
	main._biome_floor(Vector3(0, 0, mid_z), Vector2(main.ch_half_w * 2.0 + 2.0, total + 2.0))
	# side walls in chamber-length runs (the kit reuses a run of the same length)
	for c: int in range(0, main.chambers + 1):
		var cz: float = -(float(c) + 0.5) * main.ch_len
		main._biome_wall(Vector3(-main.ch_half_w - 0.5, 0, cz), main.ch_len, 90.0, float(bcfg["wall_height_side"]))
		main._biome_wall(Vector3(main.ch_half_w + 0.5, 0, cz), main.ch_len, -90.0, float(bcfg["wall_height_side"]))
	main._biome_wall(Vector3(0, 0, 0.5), main.ch_half_w * 2.0, 180.0, float(bcfg["wall_height_near"]))
	main._biome_wall(Vector3(0, 0, -total - 0.5), main.ch_half_w * 2.0, 0.0, float(bcfg["wall_height_far"]))

	var side_w: float = main.ch_half_w - main.gap_half
	var side_x: float = main.gap_half + side_w * 0.5
	for c: int in range(1, main.chambers + 1):
		var z: float = -float(c) * main.ch_len
		main._biome_wall(Vector3(-side_x, 0, z), side_w, 0.0, float(bcfg["wall_height_divider"]))
		main._biome_wall(Vector3(side_x, 0, z), side_w, 0.0, float(bcfg["wall_height_divider"]))
		# every doorway has its gate; only the sealed ones are shut
		var gate: Node3D = Biomes.gate(main.biome, main.gap_half * 2.0)
		gate.position = Vector3(0, 0, z)
		main.level.add_child(gate)
		gate.call("set_open", true, true)
		main.gates[c] = gate
		if c >= 2:
			_add_barrier(c)

	for c: int in range(0, main.chambers + 1):
		var near_z: float = -float(c) * main.ch_len
		main.factory_part._scatter_props(Vector3(0, 0, near_z - main.ch_len * 0.5), Vector2(main.ch_half_w - 0.3, main.ch_len * 0.5 - 1.2), int(bcfg["props_per_chamber"]), [near_z, near_z - main.ch_len])
		var tufts: int = GameData.inum("passage", "antechamber_tufts") if c == 0 else GameData.inum("passage", "chamber_tufts")
		for i: int in tufts:
			var pos := Vector3(main.rng.randf_range(-main.ch_half_w + 1.0, main.ch_half_w - 1.0), 0.0,
				-float(c) * main.ch_len - main.rng.randf_range(1.5, main.ch_len - 1.5))
			main._spawn_cuttable(i, pos)

	# rune stones (design/14 section 8): one cut into the wall of each chamber the data names
	for ins: Dictionary in (GameData.rune_discovery.get("inscriptions", {}) as Dictionary).get("passage", []):
		var c2: int = int(ins.get("chamber", 1))
		if c2 < 0 or c2 > main.chambers:
			continue
		var stone := RuneStone.new()
		stone.setup(str(ins["id"]), str(ins.get("name", "A rune stone")), str(ins.get("pool", "base")))
		stone.position = Vector3(main.ch_half_w - 0.9, 0.0, -(float(c2) + 0.5) * main.ch_len)
		stone.rotation.y = -PI / 2.0
		main.level.add_child(stone)
		stone.set_read((main.player.get("read_inscriptions") as Array).has(str(ins["id"])))
	# the spirit layer: one site per chamber, antechamber included
	for c: int in range(0, main.chambers + 1):
		main.nether.populate_site(Vector3(0.0, 0.0, -(float(c) + 0.5) * main.ch_len), Vector2(main.ch_half_w - 1.5, main.ch_len * 0.5 - 1.5))
	main.player.global_position = main.level.to_global(Vector3(0.0, 0.0, -4.0))
	main.player.set("active", true)
	main.factory_part._place_corpses("passage")
	# everyone the passage can put up is loaded now, with the level, not the first time each kind wakes;
	# the first wall's bodies are built ahead (the rest after each wall falls - _on_wall_cleared)
	var roster: Array[String] = []
	for c3: int in range(1, main.chambers + 1):
		roster.append_array(_wall_kinds(c3))
	main.factory_part._warm_bodies(roster + main.factory_part._calls_of(roster))
	main._prebuild_bodies(_wall_kinds(1))
	main.state = "dungeon"
	main.player.call("note", "You step through into %s. Walk up the corridor (%s)." % [str(main._biome.get("label", main.biome)).to_lower(), Keybinds.binding_text("move_up")])


## Seal the doorway into chamber `c`: an unseen collider, and its gate shut.
func _add_barrier(c: int) -> void:
	var b: StaticBody3D = main._static_box(Vector3(0, 1.0, -float(c) * main.ch_len), Vector3(main.gap_half * 2.0, 2.0, 0.6), Color.BLACK, false)
	main.barriers[c] = b
	if main.gates.has(c):
		(main.gates[c] as Node).call("set_open", false, c >= 2 and not main.sealed)


## Who stands in wall `c`, in the order they are placed: the front line of grunts, the brutes, a
## commander at the gate and at the last wall, then the wall's recipe (design/05 6.2).
func _wall_kinds(c: int) -> Array[String]:
	var kinds: Array[String] = []
	for i: int in GameData.inum("passage", "grunts_base") + c / 2:
		kinds.append("grunt")
	for i: int in maxi(0, (c - GameData.inum("passage", "brute_offset")) / GameData.inum("passage", "brute_every")):
		kinds.append("brute")
	if c == main.gate_at or c == main.chambers:
		kinds.append("commander")
	# the wall's recipe: what stands behind the front line, and its one problem (design/05 6.2)
	var recipe: Dictionary = _wall_recipe(c)
	for kind: String in recipe:
		for i: int in int(recipe[kind]):
			kinds.append(kind)
	return kinds


## Extra enemies for wall `c`: its own recipe, or the nearest lower one that has one.
func _wall_recipe(c: int) -> Dictionary:
	var recipes: Dictionary = GameData.balance["passage"]["wall_recipes"]
	for n: int in range(c, 0, -1):
		if recipes.has(str(n)):
			return recipes[str(n)]
	return {}


func _activate(c: int) -> void:
	main.current = c
	var strength: float = main.late_strength if c > main.gate_at else 1.0
	var kinds: Array[String] = _wall_kinds(c)
	for kind: String in kinds:
		# archers start at the back of the chamber, where a back line belongs
		var back: bool = str(GameData.enemy(kind).get("behaviour", "melee")) == "ranged"
		var local := Vector3(main.rng.randf_range(-main.ch_half_w + 2.0, main.ch_half_w - 2.0), 0.0,
			main.rng.randf_range(-float(c + 1) * main.ch_len + 2.0, -float(c + 1) * main.ch_len + 4.0) if back
			else main.rng.randf_range(-float(c + 1) * main.ch_len + 2.0, -float(c) * main.ch_len - 7.0))
		main.factory_part._spawn_enemy(kind, local, strength)
	main._prebuild_bodies(main.factory_part._calls_of(kinds))         # a commander's call for help lands mid-fight: its bodies wait ready
	main.player.call("start_fight")
	main.player.call("note", "Wall %d of %d." % [c, main.chambers])
	main.hud.call("announce", "WALL %d" % c if c != main.chambers else "THE LAST WALL")
	if main._harness_part != null:
		main._harness().shot_dungeon_wall(c)


## Where something at `from` should walk next to reach `to` (both in world space). In the passage
## that may be a doorway first; anywhere else it is `to` itself. See Route. Only used until the
## level's navigation mesh is baked (LevelNav); after that everything follows paths.
func route(from: Vector3, to: Vector3, walker_radius: float) -> Vector3:
	if main.state != "dungeon" or main.level == null:
		return to
	var step: Vector3 = Route.step_toward(main.level.to_local(from), main.level.to_local(to), main.ch_len, main.gap_half, walker_radius)
	return main.level.to_global(step)


func _on_wall_cleared() -> void:
	main.cleared = main.current
	main.bank += main.stage_value * main.cleared
	main.player.call("end_fight")
	var next_c: int = main.cleared + 1
	if main.barriers.has(next_c):
		(main.barriers[next_c] as Node).queue_free()
		main.barriers.erase(next_c)
		if main.gates.has(next_c):
			(main.gates[next_c] as Node).call("set_open", true)
	if main.cleared < main.chambers:
		main._prebuild_bodies(_wall_kinds(main.cleared + 1))   # built while you walk to the next doorway
	if main.cleared >= main.gate_at:
		_spawn_pad(main.cleared)
	main.player.call("note", "Wall %d cleared. Spoils worth $%d waiting - yours only if you walk out with them." % [main.cleared, main.bank])
	if main.cleared == main.gate_at:
		main.hud.call("announce", "AN EXIT OPENS")


func _spawn_pad(c: int) -> void:
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.4
	disc.bottom_radius = 1.4
	disc.height = 0.1
	pad.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.4)
	pad.material_override = mat
	pad.position = Vector3(0.0, 0.06, -(float(c) + 0.5) * main.ch_len)
	main.level.add_child(pad)
	main.pads.append(pad)


func _pad_in_reach() -> bool:
	for pad: Node3D in main.pads:
		var d: Vector3 = pad.global_position - main.player.global_position
		d.y = 0.0
		if d.length() <= main.exit_reach:
			return true
	return false


func _payout_now() -> int:
	var bonus: float = main.full_clear_bonus if main.cleared == main.chambers else 1.0
	return int(float(main.bank) * _repeat_mult() * bonus)


func _extract() -> void:
	var owed: int = _payout_now()
	var carried: Array = grant_spoils(owed)
	main._last_payout = int(carried[0])
	main._last_cleared = main.cleared
	main._last_sealed = main.sealed
	main._bot_finished = main._bot_mode
	main.delves += 1
	main.player.call("note", "You walk out after %d walls carrying spoils worth $%d." % [main.cleared, int(carried[0])])
	if int(carried[1]) > 0:
		main.player.call("note", "You could not carry the rest - $%d of it stays at the exit." % int(carried[1]))
	var rewards: Array[String] = grant_exit_rewards(main.cleared, main.cleared == main.chambers)
	if main._return_to.is_empty():
		main._enter_town("passage")
	else:
		var back: Dictionary = main._return_to
		main._return_to = {}
		main.enter_zone(str(back["zone"]), str(back["at"]))
	if not rewards.is_empty():
		main.player.call("note", "At the exit: %s." % ", ".join(rewards))


## A delve's spoils as things to carry home and sell (nothing pays cash - Brent 2026-10-18): the
## most valuable kind first, as many as the pack will take. Returns [value carried, value left].
func grant_spoils(value: int) -> Array:
	var inv: Inventory = main.player.get("inventory")
	var left: int = value
	for id: Variant in GameData.items_file.get("spoils", []):
		var each: int = int(GameData.item(str(id)).get("value", 0))
		while each > 0 and left >= each and inv.add(str(id)):
			left -= each
	main.player.call("refresh_gear")
	return [value - left, left]


## Per-person reward at the exit, scaled to how far you got (canon: contribution-scaled loot).
## Whatever you cannot carry is left behind.
func grant_exit_rewards(walls_cleared: int, full_clear: bool) -> Array[String]:
	var cfg: Dictionary = GameData.items_file.get("exit_rewards", {})
	var rolls: int = int(float(walls_cleared) / float(cfg.get("walls_per_roll", 2.5)))
	if full_clear:
		rolls += int(cfg.get("bonus_rolls_full_clear", 0))
	var table: Array = GameData.items_file.get("exit_reward_table", [])
	var total := 0.0
	for entry: Dictionary in table:
		total += float(entry["weight"])
	var got: Array[String] = []
	var inv: Inventory = main.player.get("inventory")
	for i: int in rolls:
		var pick: float = main.rng.randf() * total
		for entry: Dictionary in table:
			pick -= float(entry["weight"])
			if pick <= 0.0:
				var id: String = str(entry["item"])
				if inv.add(id):
					got.append(str(GameData.item(id).get("name", id)))
				break
	main.player.call("refresh_gear")
	return got


func _set_dungeon_banner() -> void:
	if not main.sealed:
		main._prompt = "The antechamber. Walk up the corridor (%s) to begin - the entrance seals behind you.\nLast chance to cut grass in peace." % Keybinds.binding_text("move_up")
	elif main.current > main.cleared:
		main._prompt = ""
	elif main.cleared >= main.chambers:
		main._prompt = "All %d walls down.   %s on a glowing exit to leave with spoils worth $%d, full-clear bonus included - as much as you can carry." % [main.chambers, main._k("interact"), _payout_now()]
	elif main.cleared >= main.gate_at:
		main._prompt = "%s on a glowing exit to leave with spoils worth $%d   -   or push on: wall %d adds $%d more.\nRent is $%d a second while you stand here." % [main._k("interact"), _payout_now(), main.cleared + 1, main.stage_value * (main.cleared + 1), int(main.dungeon_rent_per_second)]
	else:
		main._prompt = "Spoils worth $%d waiting, but no exit until wall %d.   Rest if you need it - rent is $%d a second." % [main.bank, main.gate_at, int(main.dungeon_rent_per_second)]
	main._stone_prompt()


func repeat_mult() -> float:
	return _repeat_mult()


func _repeat_mult() -> float:
	return maxf(main.repeat_floor, pow(main.repeat_factor, float(main.delves)))


func _charge_rent(rate: float, delta: float) -> void:
	main._rent_accum += rate * delta
	if main._rent_accum >= 1.0:
		var due: int = int(main._rent_accum)
		main._rent_accum -= float(due)
		main.player.call("charge", due)
