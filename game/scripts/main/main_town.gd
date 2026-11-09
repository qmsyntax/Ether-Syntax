class_name MainTown
extends MainLevel
## The town (main.state "town"; design/08): building it (TownBuilder), arriving by the way you came, its people -
## who is close enough to talk to, a click that walks you up to someone, the gateways you walk through and the
## passage door - and what they do: the trainer (train and drill), crafting at a keeper's station or from a field
## kit (design/12), and the services the screens call (selling, buying, a room for the night). Moved out of
## main.gd as it was (docs/architecture/main-split.md).

## Each frame in town: who is close enough to talk to, the gateways you walk through, and the
## person you clicked being walked up to. Walking away from someone closes what they showed you.
func tick(_delta: float) -> void:
	main._prompt = ""
	if main._town == null:
		return
	var near: Townsperson = main._town.folk_in_reach(main.player.global_position)
	for p: Townsperson in main._town.folk:
		var on: bool = p == near and main.screen == null
		if is_instance_valid(p) and p.focused != on:
			p.set_focus(on)
	if main._talking_to != "":
		var who: Townsperson = main._town.person(main._talking_to)
		if main.screen == null:
			main._talking_to = ""
		elif who != null and main._flat_dist(who.global_position, main.player.global_position) > float(GameData.town.get("leave_reach", 4.5)):
			main._talking_to = ""
			main._show_screen(null, false)
	if main._walk_to != null:
		if not is_instance_valid(main._walk_to) or main.screen != null or not bool(main.player.get("has_move_goal")):
			main._walk_to = null
		elif main._flat_dist(main._walk_to.global_position, main.player.global_position) <= float(GameData.town.get("talk_reach", 2.7)):
			var role: String = main._walk_to.role
			main._walk_to = null
			main.player.set("has_move_goal", false)
			talk_to(role)
			return
		elif not Input.is_action_pressed("strike"):
			main.player.set("move_goal", main._walk_to.global_position)
	var ex: Dictionary = main._town.exit_at(main.player.global_position)
	if not ex.is_empty() and bool(ex.get("walk_through", false)):
		main.player.call("note", "You go through %s." % str(ex.get("name", "the gate")))
		main.call(str(ex["action"]))
		return
	if main.screen != null:
		return
	if near != null:
		main._prompt = "%s talk to %s, %s" % [main._k("interact"), near.folk_name, near.title]
		return
	var door: Dictionary = _town_door_in_reach()
	if not door.is_empty():
		main._prompt = "%s the door into %s - an owned passage: ticket $%d, and a meter while you are inside." % [main._k("interact"), str(door.get("prompt", "the passage")), main.ticket_price]
		return
	for gate: Dictionary in main._town.exits:
		if bool(gate.get("walk_through", false)) and main._flat_dist(main.level.to_global(gate["centre"]), main.player.global_position) < 6.0:
			main._prompt = str(gate.get("prompt", ""))


## The keys in town: no skills (nothing here to use them on; a test character may still turn its bar),
## interact, and a click on someone to walk up and talk.
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("hotbar_page") and bool(main.player.get("test_character")):
		main.player.call("next_hotbar_page")
	elif event.is_action_pressed("interact"):
		_town_interact()
	elif event.is_action_pressed("strike"):
		_town_click((event as InputEventMouseButton).position if event is InputEventMouseButton else main.get_viewport().get_mouse_position())


func where() -> String:
	return "Town  -  day %d" % main.day


## The town is a level (design/08): data/town.json built by TownBuilder - streets, gateways and
## the people who do what the old town menu did.
func _build_town() -> void:
	main.factory_part._new_level(0.0)
	var cfg: Dictionary = GameData.balance["biomes"]
	main.factory_part._use_biome(cfg["town"], false)            # the town is always the town
	main._town = TownBuilder.new(main, GameData.town)
	main._town.build()


func _enter_town(arrive: String = "square") -> void:
	if main.nether.active:
		main.nether.exit("")
	_build_town()
	main.player.call("end_fight")
	main.player.call("refill_endurance")             # the town gives you your wind back (balance.json endurance)
	main.player.global_position = main.level.to_global(main._town.arrival(arrive))
	main.player.set("attack_target", null)
	main.player.set("pickup_target", null)
	main.player.set("has_move_goal", false)
	main.player.set("active", true)                # the town is a place you walk round (design/08)
	main.state = "town"
	main._prompt = ""
	main._talking_to = ""
	main._walk_to = null
	main.save_now()
	main._show_screen(null, false)


## A shut door in town you are standing at (the passage), or {}.
func _town_door_in_reach() -> Dictionary:
	if main._town == null:
		return {}
	for ex: Dictionary in main._town.exits:
		if not bool(ex.get("walk_through", false)) and main._flat_dist(main.level.to_global(ex["centre"]), main.player.global_position) <= float(GameData.town.get("exit_reach", 1.5)) * 2.0:
			return ex
	return {}


## The interact key in town: stop talking, talk to whoever is close, or use the door you are at.
func _town_interact() -> void:
	if main.screen != null:
		main.close_screen()
		return
	var who: Townsperson = main._town.folk_in_reach(main.player.global_position) if main._town != null else null
	if who != null:
		talk_to(who.role)
		return
	var door: Dictionary = _town_door_in_reach()
	if not door.is_empty():
		main.call(str(door["action"]))
		return
	main.player.call("note", "Nobody close enough to talk to. Walk up to someone.")


## A click in town at a screen point: on a person, walk up to them and talk.
func _town_click(at: Vector2) -> void:
	if main.screen != null or main._town == null or bool(main.hud.call("ui_at", at)):
		return
	var who: Townsperson = main._town.pick_screen(at, main.camera)
	if who == null:
		main._walk_to = null                 # a click elsewhere is a new walk: _tick_town would steer back to them
		return
	if main._flat_dist(who.global_position, main.player.global_position) <= float(GameData.town.get("talk_reach", 2.7)):
		talk_to(who.role)
		return
	main._walk_to = who
	main.player.set("move_goal", who.global_position)
	main.player.set("has_move_goal", true)


## Talk to the townsperson who does `role` (data/town.json "folk"): their panel opens.
func talk_to(role: String) -> void:
	if main.state != "town" or GameData.town_folk(role).is_empty():
		return
	main._talking_to = role
	main._show_screen(TalkScreen.new(main, role), false)


## Learn a skill from the trainer: only in town, only while talking to them. Returns "" or why not.
func train_skill(ability_id: String) -> String:
	if main.state != "town" or main._talking_to != "trainer":
		return "Only a trainer can teach you a skill. Find one in town."
	var why: String = main.player.call("train_skill", ability_id)
	if why == "":
		main.save_now()
	return why


## Drill a known skill with the trainer: the same rule. Returns "" or why not.
func drill_skill(ability_id: String) -> String:
	if main.state != "town" or main._talking_to != "trainer":
		return "Only a trainer can drill you. Find one in town."
	var why: String = main.player.call("drill_skill", ability_id)
	if why == "":
		main.save_now()
	return why


# --- crafting (design/12) ------------------------------------------------------------------------

## The station of the craftsperson you are talking to, or "".
func _talking_station() -> String:
	return str(GameData.town_folk(main._talking_to).get("station", "")) if main.state == "town" and main._talking_to != "" else ""


## Work at a station: only in town, while talking to the person who keeps it.
func open_crafting(station_id: String) -> void:
	if _talking_station() != station_id or Crafting.station(station_id).is_empty():
		return
	main._show_screen(CraftScreen.new(main, {"station": station_id, "grade": int(Crafting.station(station_id).get("grade", 1)), "kit": ""}), false)


## The craftsperson's tools and supplies (data/crafting.json stations.<id>.sells).
func open_station_shop(station_id: String) -> void:
	if _talking_station() != station_id:
		return
	var st: Dictionary = Crafting.station(station_id)
	main._show_screen(Main.ShopScreen.new(main, st.get("sells", []), str(st.get("name", "Supplies"))), false)


## Pay the craftsperson you are talking to and learn every recipe of their skill.
func learn_trade(station_id: String) -> String:
	if _talking_station() != station_id:
		return "Only the keeper of that station can teach it."
	var why: String = Crafting.teach(main.player, str(Crafting.station(station_id).get("skill", "")))
	if why == "":
		main.save_now()
	return why


## Open a field kit from the pack: its station's recipes, anywhere, with no fee and no salvage.
## Out of town it pauses the game, like the pack itself.
func open_field_kit(kit_id: String) -> void:
	var kit: Dictionary = GameData.item(kit_id).get("kit", {})
	if kit.is_empty() or not (main.player.get("inventory") as Inventory).bag.has(kit_id) or main.state == "select" or main.state == "dead":
		return
	main._talking_to = ""
	main._show_screen(CraftScreen.new(main, {"station": str(kit["station"]), "grade": int(kit.get("grade", 1)), "kit": kit_id}), main.state != "town")


## One combine, if this is a place you may make it: the station of the person you are talking to,
## or a kit in your pack. Returns Crafting.combine's result ({ok, why, success, ...}).
func craft(recipe_id: String, ctx: Dictionary) -> Dictionary:
	var kit: String = str(ctx.get("kit", ""))
	var here: Dictionary
	if kit != "":
		var k: Dictionary = GameData.item(kit).get("kit", {})
		if k.is_empty() or not (main.player.get("inventory") as Inventory).bag.has(kit):
			return {"ok": false, "why": "You do not have that kit."}
		here = {"station": str(k["station"]), "grade": int(k.get("grade", 1)), "kit": kit}
	else:
		var station_id: String = _talking_station()
		if station_id == "" or station_id != str(ctx.get("station", "")):
			return {"ok": false, "why": "You can only work at a station whose keeper you are talking to."}
		here = {"station": station_id, "grade": int(Crafting.station(station_id).get("grade", 1)), "kit": ""}
	var res: Dictionary = Crafting.combine(main.player, recipe_id, here, main.player.get("rng"))
	main.player.call("refresh_gear")
	if bool(res.get("ok", false)):
		main.save_now()
	return res


# --- town services (logic only; the UI calls these) ------------------------------

## Sell every piece of loot in the bag. Returns what it fetched.
func town_sell_loot() -> int:
	var inv: Inventory = main.player.get("inventory")
	var got: int = inv.sell_loot()
	if got > 0:
		main.player.set("money", int(main.player.get("money")) + got)
		main.player.call("note", "Sold your loot for $%d." % got)
	else:
		main.player.call("note", "Nothing in your pack that anyone wants.")
	main.save_now()
	return got


## Sell one item from the bag (loot at full value, gear at a fraction).
func town_sell_item(item_id: String) -> int:
	var inv: Inventory = main.player.get("inventory")
	var got: int = inv.sell_item(item_id)
	if got > 0:
		main.player.set("money", int(main.player.get("money")) + got)
		main.player.call("note", "Sold %s for $%d." % [str(GameData.item(item_id).get("name", item_id)), got])
		main.save_now()
	return got


## Buy a shop item on credit (to the debt limit). Returns "" on success, else why not.
func town_buy(item_id: String) -> String:
	var def: Dictionary = GameData.item(item_id)
	if def.is_empty():
		return "no such item"
	var price: int = int(def.get("value", 0))
	if not bool(main.player.call("can_afford", price)):
		return "Nobody will lend you that much."
	var inv: Inventory = main.player.get("inventory")
	if not inv.can_add(item_id):
		return "You cannot carry it - %d of %d kg." % [int(inv.weight()), int(inv.capacity())]
	main.player.call("charge", price)
	inv.add(item_id)
	main.player.call("note", "Bought %s for $%d." % [str(def.get("name", item_id)), price])
	main.save_now()
	return ""


## A room at the inn for the night - the only rent there is (Brent 2026-10-18).
func town_rest_night() -> void:
	main.player.call("rest_night")
	main.player.call("charge", main.night_rent)
	main.day += 1
	main.save_now()
