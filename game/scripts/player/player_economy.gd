class_name PlayerEconomy
extends RefCounted
## The player's part for economy and inventory: gear, loot, pickups, money, the healer, corpses, rest, consumables.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

var player: Player

var _corpse_seq := 0


# --- gear, loot, saving ----------------------------------------------------------


func _init(of: Player) -> void:
	player = of


## A stat of the weapon in hand. A weapon is held in the striking arm, so with that arm lost it
## counts for nothing (neutral value) until the arm is regrown.
func weapon_stat(stat_name: String, multiplicative: bool = false) -> float:
	var neutral: float = 1.0 if multiplicative else 0.0
	if player.arm_right_lost:
		return neutral
	var stats: Dictionary = GameData.item(str(player.inventory.equipped.get("weapon", ""))).get("stats", {})
	return float(stats.get(stat_name, neutral))


## How far a base strike reaches right now.
func reach_now() -> float:
	var r: float = player.melee_range + weapon_stat("melee_range_bonus")
	var c: Dictionary = player.combat_part.conjured()
	if c.has("melee_range"):
		r = float(c["melee_range"])                     # a conjured weapon's own reach (Thirsting Glaive)
	for bid: String in player.buffs:
		r += float((player.buffs[bid] as Dictionary).get("strike_reach_bonus", 0.0))       # Red Frenzy
	return r


## Re-read what equipment grants. Call after anything is equipped or removed.
func refresh_gear() -> void:
	player.satellite_rate = float(player._p["starter_satellite_rate"]) + player.inventory.stat("satellite_rate")
	_show_weapon()


## Put the equipped weapon in the model's hand (or take it away).
func _show_weapon() -> void:
	if player._rig == null:
		return
	if player._rig.has_method("set_outfit"):
		player._rig.call("set_outfit", player.inventory.equipped)       # a real body wears what is equipped
	var id: String = str(player.inventory.equipped.get("weapon", ""))
	if id == player._shown_weapon:
		return
	player._shown_weapon = id
	player._rig.set_weapon(Models.weapon(id) if id != "" else null)


## Kills leave items on the ground where the enemy fell.
func _roll_loot(target: Node) -> void:
	var kind_v: Variant = target.get("kind")
	if kind_v == null or str(kind_v) == "" or not player.is_inside_tree():
		return
	var parent: Node = target.get_parent()
	if parent == null:
		return
	# every kill leaves something to sell: the kind's remains (nothing pays cash - Brent 2026-10-18);
	# a beast may leave several (hide, bone, meat, fat - enemies.json "remains" as a list)
	if not bool(target.get("is_scenery")):
		var k: int = 0
		for remains: String in remains_of(str(kind_v)):
			var off := Vector3(0.45 * float(k), 0.0, -0.3 * float(k))
			spawn_pickup(parent, remains, (target as Node3D).global_position + off)
			k += 1
	for entry: Dictionary in GameData.enemy(str(kind_v)).get("loot", []):
		if player.rng.randf() < float(entry["chance"]):
			if bool(entry.get("learnable", false)):
				var scroll: String = player.progress_part.scroll_for_me()
				if scroll != "":
					spawn_pickup(parent, scroll, (target as Node3D).global_position + Vector3(player.rng.randf_range(-0.8, 0.8), 0.0, player.rng.randf_range(-0.8, 0.8)))
				continue
			var at: Vector3 = (target as Node3D).global_position + Vector3(player.rng.randf_range(-0.8, 0.8), 0.0, player.rng.randf_range(-0.8, 0.8))
			spawn_pickup(parent, str(entry["item"]), at)


static func spawn_pickup(parent: Node, item_id: String, at: Vector3) -> Node3D:
	var script: GDScript = load("res://scripts/pickup.gd")
	var drop: Node3D = script.new()
	drop.call("setup", item_id)
	parent.add_child(drop)
	drop.global_position = Vector3(at.x, 0.0, at.z)
	return drop


## Put a ground item in the bag, if there is room to carry it.
func take_pickup(drop: Node3D) -> bool:
	if drop.get("corpse_id") != null:
		var back: bool = recover_corpse(str(drop.get("corpse_id")))
		if back:
			drop.call("take")
		return back
	var id: String = str(drop.get("item_id"))
	var item_name: String = str(GameData.item(id).get("name", id))
	if not player.inventory.add(id):
		player.note("%s is too heavy - you are carrying %d of %d kg." % [item_name, int(player.inventory.weight()), int(player.inventory.capacity())])
		return false
	drop.call("take")
	player.motion_part._rig_action("pickup")
	player.note("Picked up %s." % item_name)
	return true


# --- between fights -----------------------------------------------------------

## Rent keeps ticking while you rest. Money may go negative: that is debt.
func charge(amount: int) -> void:
	player.money -= amount


func _can_afford(cost: int) -> bool:
	return player.money - cost >= int(player._p["debt_limit"])


## Public form for the town: will anyone extend this much credit?
func can_afford(cost: int) -> bool:
	return _can_afford(cost)


## What the healer would do next and what it would cost - for the town screen.
func next_healing() -> Dictionary:
	if player.arm_right_lost:
		return {"desc": "Regrow your striking arm. The only way without a talent.", "cost": int(player._arm["regrow_price"])}
	var w: Dictionary = _healer_wound()
	if not w.is_empty():
		var work: float = minf(float(player._heal_cfg["sink_per_visit"]), float(w["sink"]))
		return {"desc": "Work on your %s (%s). Slow, careful, and not cheap." % [str(w["name"]).to_lower(), Body.wound_state(w)],
			"cost": int(ceil(work * float(player._heal_cfg["price_per_sink_point"])))}
	var gap: float = player.body.missing()
	if gap > 0.5:
		var amount: float = minf(float(player._heal_cfg["health_per_visit"]), gap)
		return {"desc": "Patch you up: %d health now. A night's rest does it for the price of a bed." % int(ceil(amount)),
			"cost": int(ceil(amount * float(player._heal_cfg["price_per_health_point"])))}
	return {"desc": "Nothing to mend. You are whole.", "cost": 0}


## The wound the healer would work on next: the oldest that is not a lost limb.
func _healer_wound() -> Dictionary:
	for w: Dictionary in player.body.wounds:
		if str(w["id"]) != "lost_arm":
			return w
	return {}


## The healer sells speed, and the one thing rest cannot do: regrowth. Credit is extended to a limit.
func buy_healing() -> void:
	if player.arm_right_lost:
		var price: int = int(player._arm["regrow_price"])
		if not _can_afford(price):
			player.note("Healer: regrowing an arm is $%d. Your credit won't stretch that far." % price)
			return
		player.money -= price
		player.arm_right_lost = false
		player.arm_right = float(player._arm["max"])
		player.body.remove_wound("lost_arm")
		player.note("Healer: -$%d, arm regrown." % price)
		return
	var next: Dictionary = next_healing()
	var cost: int = int(next["cost"])
	if cost <= 0:
		player.note("Healer: nothing to mend.")
		return
	if not _can_afford(cost):
		player.note("Healer: that is $%d. You have $%d and no more credit." % [cost, player.money])
		return
	player.money -= cost
	var w: Dictionary = _healer_wound()
	if not w.is_empty():
		var wound_name: String = str(w["name"])
		var work: float = minf(float(player._heal_cfg["sink_per_visit"]), float(w["sink"]))
		w["sink"] = float(w["sink"]) - work
		if float(w["sink"]) <= 0.0001:
			player.body.remove_wound(str(w["id"]))
			player.note("Healer: -$%d. Your %s is closed." % [cost, wound_name.to_lower()])
		else:
			player.note("Healer: -$%d of work on your %s. It is %s." % [cost, wound_name.to_lower(), Body.wound_state(w)])
		return
	var healed: float = player.body.heal(float(player._heal_cfg["health_per_visit"]))
	player.note("Healer: -$%d, patched up %d health." % [cost, int(round(healed))])


## Standard-mode death (design/03 section 7b): dragged out, patched up, and billed for it.
## The fee is charged with no credit check - this is how a character ends up in debt.
## You wake in town with nothing (Brent 2026-10-18: corpse runs). Patched up, not healed: enough
## to stand, and nothing lost comes back. What you had is on your corpse (die_to_corpse).
func respawn_naked() -> void:
	var town: Dictionary = GameData.balance["town"]
	player.dead = false
	player.in_combat = false
	player.meditating = false
	player.effects.clear()
	player.set_talent(player.talent_id)
	player._charging = false
	player._charge = 0.0
	player.clear_reflux()
	player.buffs.clear()
	player.motion_part._end_step()
	player.motion_part.refill_endurance()
	player.body.hp = maxf(player.body.hp, player.body.total_max() * float(town["revive_health_frac"]))
	player._build_model()
	refresh_gear()
	player.note("You wake on a cot in town with nothing on you. Your body is where you fell.")


## Everything worn and carried stays with the body, where it fell: `where` is "passage" or "arena",
## `chamber` and `local_pos` place it in that level's own frame. Returns the corpse, or {} if
## there was nothing on you to leave.
func die_to_corpse(where: String, chamber: int, local_pos: Vector3) -> Dictionary:
	if player.inventory.equipped.is_empty() and player.inventory.bag.is_empty():
		return {}
	_corpse_seq += 1
	var c: Dictionary = {"id": "corpse_%d_%d" % [Time.get_unix_time_from_system(), _corpse_seq], "where": where, "chamber": chamber,
		"pos": [local_pos.x, local_pos.y, local_pos.z], "equipped": player.inventory.equipped.duplicate(), "bag": player.inventory.bag.duplicate()}
	player.corpses.append(c)
	player.inventory.equipped.clear()
	player.inventory.bag.clear()
	refresh_gear()
	return c


## Take back everything on one of your corpses. What you are wearing now stays on; anything that
## would have gone in a taken slot goes in the pack. It all comes back, however heavy.
func recover_corpse(id: String) -> bool:
	for i: int in player.corpses.size():
		var c: Dictionary = player.corpses[i]
		if str(c["id"]) != id:
			continue
		var gear: Dictionary = c.get("equipped", {})
		for slot: String in gear:
			if player.inventory.equipped.has(slot):
				player.inventory.bag.append(str(gear[slot]))
			else:
				player.inventory.equipped[slot] = str(gear[slot])
		for item: Variant in c.get("bag", []):
			player.inventory.bag.append(str(item))
		player.corpses.remove_at(i)
		refresh_gear()
		player.note("You take back everything that was on your corpse.")
		player._float("RECOVERED", Color(0.9, 0.85, 0.7))
		return true
	return false


## The price to have one corpse brought to you: flat, by how many stars you have.
func corpse_fee() -> int:
	return GameData.inum("town", "corpse_fee_per_star") * player.stars


## Pay to have the most recent corpse brought back. Returns "" or why not.
func buy_corpse_retrieval() -> String:
	if player.corpses.is_empty():
		return "You have no corpse lying anywhere."
	var fee: int = corpse_fee()
	if not can_afford(fee):
		return "The collectors will not go out on that much debt."
	player.money -= fee
	recover_corpse(str((player.corpses.back() as Dictionary)["id"]))
	return ""


## A night in town: the body does what bodies do. Rent for the night is charged by the caller.
func rest_night() -> void:
	var night: Dictionary = GameData.balance["night"]
	var mended: Dictionary = player.body.fill_sinks(float(night["sink_healed"]), true)      # never a lost limb
	player.combat_part._wounds_closed(mended["closed"])
	player.body.heal(player.body.total_max())
	if not player.arm_right_lost:
		player.arm_right = minf(float(player._arm["max"]), player.arm_right + float(night["arm_restored"]))
	player.clear_reflux()
	player.essence = player.essence_max
	player.note("You sleep. The body refills; wounds knit a little. What is gone stays gone.")


## Every remains item a kill of `kind` leaves ("remains" may be one id or a list).
static func remains_of(kind: String) -> Array[String]:
	var out: Array[String] = []
	var r: Variant = GameData.enemy(kind).get("remains", "")
	if r is Array:
		for id: Variant in r:
			out.append(str(id))
	elif str(r) != "":
		out.append(str(r))
	return out


## Use a consumable from the pack (items.json kind "consumable", "use"). Returns "" if it was used
## (and is gone), else why not. Only "heal" is built: a field dressing, out of a fight.
func use_consumable(item_id: String) -> String:
	var def: Dictionary = GameData.item(item_id)
	if str(def.get("kind", "")) != "consumable" or not player.inventory.bag.has(item_id):
		return "That is not something you can use."
	var use: Dictionary = def.get("use", {})
	if bool(use.get("out_of_combat", false)) and player.in_combat:
		return "Not in the middle of a fight."
	match str(use.get("effect", "")):
		"heal":
			if player.body.total() >= player.body.total_max():
				return "You are not hurt."
			player.body.heal(float(use.get("amount", 0.0)))
		_:
			return "Nothing comes of it."
	player.inventory.remove(item_id)
	player.note("You use the %s." % str(def.get("name", item_id)).to_lower())
	return ""
