class_name Inventory
extends RefCounted
## What a character carries and wears. Carry weight is a hard limit (canon: carry capacity is an
## economic stat). Equipment slots: weapon (held in the striking arm), back (a backpack - no
## storage ring at the start), satellite, trinket. Equipped items do not count against the bag's capacity; they are worn.

const SLOTS: Array[String] = ["weapon", "back", "satellite", "trinket"]

var bag: Array[String] = []             # item ids, one entry per item
var equipped: Dictionary = {}           # slot -> item id


func _init(with_starting_kit: bool = true) -> void:
	if with_starting_kit:
		var start: Dictionary = GameData.items_file.get("starting_equipped", {})
		for slot: String in start:
			equipped[slot] = str(start[slot])
		for id: Variant in GameData.items_file.get("starting_bag", []):
			bag.append(str(id))


## Sum of a stat over equipped items. `multiplicative` stats start at 1 and multiply.
func stat(stat_name: String, multiplicative: bool = false) -> float:
	var total: float = 1.0 if multiplicative else 0.0
	for slot: String in equipped:
		var stats: Dictionary = GameData.item(str(equipped[slot])).get("stats", {})
		if stats.has(stat_name):
			if multiplicative:
				total *= float(stats[stat_name])
			else:
				total += float(stats[stat_name])
	return total


func capacity() -> float:
	return float(GameData.items_file.get("base_carry_capacity", 0.0)) + stat("carry_capacity")


func weight() -> float:
	var w := 0.0
	for id: String in bag:
		w += float(GameData.item(id).get("weight", 0.0))
	return w


func can_add(id: String) -> bool:
	return not GameData.item(id).is_empty() and weight() + float(GameData.item(id).get("weight", 0.0)) <= capacity() + 0.001


func add(id: String) -> bool:
	if not can_add(id):
		return false
	bag.append(id)
	return true


func remove(id: String) -> bool:
	var i: int = bag.find(id)
	if i < 0:
		return false
	bag.remove_at(i)
	return true


## Equip an item from the bag. Whatever was in the slot goes back into the bag. Refused if that
## would leave the bag over capacity (e.g. swapping to a smaller backpack while loaded).
func equip(id: String) -> String:
	var def: Dictionary = GameData.item(id)
	var slot: String = str(def.get("slot", ""))
	if slot == "" or not bag.has(id):
		return "cannot equip that"
	var old: String = str(equipped.get(slot, ""))
	bag.remove_at(bag.find(id))
	equipped[slot] = id
	if old != "":
		bag.append(old)
	if weight() > capacity() + 0.001:
		# undo
		if old != "":
			bag.remove_at(bag.find(old))
		bag.append(id)
		if old != "":
			equipped[slot] = old
		else:
			equipped.erase(slot)
		return "too heavy to carry what you would take off"
	return "equipped"


func unequip(slot: String) -> String:
	if not equipped.has(slot):
		return "nothing there"
	var id: String = str(equipped[slot])
	equipped.erase(slot)
	bag.append(id)
	if weight() > capacity() + 0.001:
		bag.remove_at(bag.find(id))
		equipped[slot] = id
		return "no room to carry it"
	return "unequipped"


## Loot = bag items with no equipment slot. Returns their total sale value.
func loot_value() -> int:
	var v := 0
	for id: String in bag:
		if str(GameData.item(id).get("slot", "")) == "":
			v += int(GameData.item(id).get("value", 0))
	return v


## What the merchant pays for one of these: loot at full value, gear at a fraction.
func sale_price(id: String) -> int:
	var def: Dictionary = GameData.item(id)
	var value: float = float(def.get("value", 0))
	if str(def.get("slot", "")) != "":
		value *= float(GameData.items_file.get("gear_sell_factor", 0.5))
	return int(value)


## Sell one item out of the bag. Returns what it fetched (0 if it was not there).
func sell_item(id: String) -> int:
	if not bag.has(id):
		return 0
	var price: int = sale_price(id)
	bag.remove_at(bag.find(id))
	return price


## Remove all loot from the bag and return what it sold for.
func sell_loot() -> int:
	var v: int = loot_value()
	var keep: Array[String] = []
	for id: String in bag:
		if str(GameData.item(id).get("slot", "")) != "":
			keep.append(id)
	bag = keep
	return v


func to_dict() -> Dictionary:
	return {"bag": bag.duplicate(), "equipped": equipped.duplicate()}


func from_dict(d: Dictionary) -> void:
	bag.clear()
	for id: Variant in d.get("bag", []):
		if not GameData.item(str(id)).is_empty():
			bag.append(str(id))
	equipped.clear()
	var eq: Dictionary = d.get("equipped", {})
	for slot: String in eq:
		if not GameData.item(str(eq[slot])).is_empty():
			equipped[slot] = str(eq[slot])
