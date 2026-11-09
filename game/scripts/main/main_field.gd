class_name MainField
extends MainLevel
## An overland zone (main.state "field"; design/07): walking out of the Dross Gate, building the zone (ZoneBuilder)
## and its living things (FieldCamps), the lines you walk through, the fog of war and the minimap's picture, the
## Cut House door into the passage, the stubbed dungeon entrances, the field's autosave and your place in the
## save. Moved out of main.gd as it was (docs/architecture/main-split.md).

## Seconds since the field's last autosave (balance.json camps.field_autosave_s).
var _field_save_t := 0.0


## Each frame in a zone: the lines you are standing at, and what the door ahead says.
func tick(_delta: float) -> void:
	main._prompt = ""
	_reveal()
	var here: Vector3 = main.level.to_local(main.player.global_position)
	for line: Dictionary in main._zone.def.get("lines", []):
		var c: Vector3 = main._zone.line_centre(line)
		var d: float = Vector2(here.x - c.x, here.z - c.z).length()
		if bool(line.get("open", false)) and d < 2.0:
			if str(line["to"]) == "town":
				main.player.note("You come back in through %s." % str(line.get("name", "the gate")))
				main._enter_town("dross_gate")
				return
		elif not bool(line.get("open", false)) and d < 7.0:
			main._prompt = str(line.get("sign", "Closed."))
	if _cut_door_in_reach():
		main._prompt = "%s the door into Tenwall Cut - an owned passage: ticket $%d, and a meter while you are inside." % [main._k("interact"), main.ticket_price]
	main._stone_prompt()
	_entrance_prompt()


## The keys in a zone: skills, ascend, the seal, and interact (a rune stone, the Cut House door, an entrance).
func handle_input(event: InputEvent) -> void:
	if main._cast_from_hotbar(event):
		pass
	elif event.is_action_pressed("ascend"):
		main.player.try_ascend()
	elif event.is_action_pressed("bind"):
		main.open_seal_first_ready()
	elif event.is_action_pressed("healer"):
		main.player.note("No healer out here. The town is back through the gate.")
	elif event.is_action_pressed("interact"):
		_field_interact()


func where() -> String:
	return str(GameData.zone(main.zone_id).get("name", main.zone_id))


## Out of the Dross Gate into the yard outside the city.
func walk_out() -> void:
	enter_zone("the_stubble", "dross_gate")


## Walk into an overland zone, arriving by the named line. No rent out here, no ticket, no meter.
func enter_zone(id: String, arrive: String) -> void:
	var def: Dictionary = GameData.zone(id)
	if def.is_empty():
		return
	main._show_screen(null, false)
	if main.nether.active:
		main.nether.exit("")
	main.factory_part._new_level(float(def.get("yaw", 0.0)))
	main.factory_part._use_biome(def.get("biome", "scrubland"), false)
	main.zone_id = id
	main._zone = ZoneBuilder.new(main, def)
	main._zone.build()
	_build_field_life()
	var spot: Array = (def.get("arrive", {}) as Dictionary).get(arrive, [main._zone.size.x * 0.5, main._zone.size.y * 0.5])
	main.player.global_position = main.level.to_global(main._zone.to_local(float(spot[0]), float(spot[1])))
	main.player.active = true
	main.player.has_move_goal = false
	main.player.end_fight()
	main.factory_part._place_corpses(id)
	main.fog = FogMap.new(main._zone.size, GameData.num("minimap", "fog_cell_m"))
	main.fog.from_text(str((main.player.explored as Dictionary).get(id, "")))
	main.state = "field"
	_reveal()
	main.player.note("You walk out into %s." % str(def.get("name", id)))
	main.save_now()


## Clear the fog round where you stand, and keep what you have seen with the character.
func _reveal() -> void:
	if main.fog == null or main._zone == null:
		return
	var at: Vector2 = zone_point(main.player.global_position)
	if main.fog.reveal(at.x, at.y, GameData.num("minimap", "sight_m")):
		(main.player.explored as Dictionary)[main.zone_id] = main.fog.to_text()
	main.fog.refresh_texture()


## A world position as a point in the current zone's map frame (x east, y south).
func zone_point(world: Vector3) -> Vector2:
	var l: Vector3 = main.level.to_local(world)
	return Vector2(l.x + main._zone.size.x * 0.5, l.z + main._zone.size.y * 0.5)


## What the minimap needs this frame, or {} when you are not out in a zone.
func minimap_info() -> Dictionary:
	if main.state != "field" or main._zone == null or main.fog == null:
		return {}
	var facing: Vector3 = main.level.global_transform.basis.inverse() * (main.player.facing_dir as Vector3)
	var lying: Array = []
	for c: Dictionary in main.player.corpses:
		if str(c.get("where", "")) == main.zone_id:
			var pos: Array = c.get("pos", [0.0, 0.0, 0.0])
			lying.append(Vector2(float(pos[0]) + main._zone.size.x * 0.5, float(pos[2]) + main._zone.size.y * 0.5))
	return {"def": main._zone.def, "size": main._zone.size, "fog": main.fog, "at": zone_point(main.player.global_position),
		"facing": Vector2(facing.x, facing.z), "corpses": lying,
		"camps": main.field_camps.minimap_marks() if main.field_camps != null and is_instance_valid(main.field_camps) else []}


func _cut_door_in_reach() -> bool:
	var ch: Dictionary = main._zone.def.get("cut_house", {}) if main._zone != null else {}
	if ch.is_empty():
		return false
	var door: Array = ch["door"]
	var at: Vector3 = main.level.to_global(main._zone.to_local(float(door[0]), float(door[1])))
	return Vector2(at.x - main.player.global_position.x, at.z - main.player.global_position.z).length() <= 5.0


## The interact key in a zone: the Cut House door, if you are at it.
func _field_interact() -> void:
	var stone: RuneStone = main._rune_stone_in_reach()
	if stone != null:
		main._read_stone(stone)
		return
	if _cut_door_in_reach():
		var from_zone: String = main.zone_id
		main.enter_passage()
		if main.state == "dungeon":
			main._return_to = {"zone": from_zone, "at": "cut_house_door"}
		return
	if _use_entrance():
		return
	main.player.note("Nothing here to use.")


## Put the zone's living things in it (zones.json "camps", "lurker_patches").
func _build_field_life() -> void:
	main.field_camps = FieldCamps.new()
	main.field_camps.setup(main, main._zone)
	main.level.add_child(main.field_camps)
	main.field_camps.build(OS.get_cmdline_user_args().has("--all-camps"))
	_field_save_t = 0.0


## The dungeon mouth you are standing at (FieldEntrance), or null. Name plates show near them.
func _entrance_in_reach() -> FieldEntrance:
	var best: FieldEntrance = null
	var best_d := INF
	for n: Node in main.get_tree().get_nodes_in_group("field_entrances"):
		var e := n as FieldEntrance
		if e == null or not e.is_inside_tree():
			continue
		var d: float = main._flat_dist(e.global_position, main.player.global_position)
		e.set_near(d <= e.reach * 3.0)
		if d <= e.reach and d < best_d:
			best = e
			best_d = d
	return best


func _entrance_prompt() -> void:
	var e: FieldEntrance = _entrance_in_reach()
	if e != null:
		main._prompt = "%s %s" % [main._k("interact"), e.entrance_name]
	_field_save_t += main.get_process_delta_time()
	if _field_save_t >= float((GameData.balance.get("camps", {}) as Dictionary).get("field_autosave_s", 30.0)):
		_field_save_t = 0.0
		main.save_now()                              # the save keeps your place out here


## Use the entrance you are at: it says what it is and that it is not open yet (stubbed).
func _use_entrance() -> bool:
	var e: FieldEntrance = _entrance_in_reach()
	if e == null:
		return false
	main.player.note(e.use_text())
	main.hud.announce(e.entrance_name.to_upper())
	return true


## Where the character is, for the save: the zone and the spot, or {} (town).
func _place_for_save() -> Dictionary:
	if main.state != "field" or main._zone == null:
		return {}
	var at: Vector2 = zone_point(main.player.global_position)
	return {"zone": main.zone_id, "at": [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]}


## Load into the zone and spot a save was made in. False if it was made in town (or the zone is gone).
func _resume_place(place: Variant) -> bool:
	if not (place is Dictionary) or str((place as Dictionary).get("zone", "")) == "" or GameData.zone(str(place["zone"])).is_empty():
		return false
	var where: Dictionary = place
	enter_zone(str(where["zone"]), "")
	var at: Array = where.get("at", [])
	if at.size() == 2 and main._zone != null:
		main.player.global_position = main.level.to_global(main._zone.to_local(float(at[0]), float(at[1])))
		_reveal()
		main.save_now()
	return main.state == "field"
