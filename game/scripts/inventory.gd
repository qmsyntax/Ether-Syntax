class_name Inventory
extends RefCounted
## What a character carries and wears. Carry weight is a hard limit (canon: carry capacity is an
## economic stat). The twelve equipment slots are design/06 section 2: weapon (the main hand - the
## id is kept so old saves load), offhand, ranged, head, body, hands, feet, back (a backpack - no
## storage ring at the start), belt, satellite and two trinkets. Equipped items do not count
## against the bag's capacity; they are worn.

const SLOTS: Array[String] = ["weapon", "offhand", "ranged", "head", "body", "hands", "feet", "back", "belt", "satellite", "trinket", "trinket2"]
## Slots that take another slot's items: the second trinket holds anything whose slot is "trinket".
const SLOT_ACCEPTS := {"trinket2": "trinket"}

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


## The kind of item a slot holds (its own id, except for the second trinket).
static func slot_kind(slot: String) -> String:
	return str(SLOT_ACCEPTS.get(slot, slot))


## Every slot an item with this `slot` value may go into, in the order they are tried.
static func slots_for(item_slot: String) -> Array[String]:
	var out: Array[String] = []
	if item_slot == "":
		return out
	for slot: String in SLOTS:
		if slot_kind(slot) == item_slot:
			out.append(slot)
	return out


## Where `id` would go if it were equipped with no slot named: the first empty slot that takes
## it, else the first such slot (whose item is swapped out). "" if it fits nowhere.
func slot_for(id: String) -> String:
	var fits: Array[String] = slots_for(str(GameData.item(id).get("slot", "")))
	for slot: String in fits:
		if not equipped.has(slot):
			return slot
	return fits[0] if not fits.is_empty() else ""


## Equip an item from the bag, into `into` or (by default) wherever slot_for() puts it. Whatever
## was in the slot goes back into the bag. Refused if that would leave the bag over capacity
## (e.g. swapping to a smaller backpack while loaded), and the same item is never worn twice.
func equip(id: String, into: String = "") -> String:
	var slot: String = into if into != "" else slot_for(id)
	if slot == "" or not bag.has(id) or not slots_for(str(GameData.item(id).get("slot", ""))).has(slot):
		return "cannot equip that"
	for other: String in equipped:
		if str(equipped[other]) == id:
			return "you already wear one"
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
## Loot is what is only good for selling: no slot to wear it in, and not something to read.
static func is_loot(id: String) -> bool:
	var def: Dictionary = GameData.item(id)
	return str(def.get("slot", "")) == "" and str(def.get("kind", "")) != "scroll"


func loot_value() -> int:
	var v := 0
	for id: String in bag:
		if is_loot(id):
			v += int(GameData.item(id).get("value", 0))
	return v


## What the merchant pays for one of these: loot at full value, gear at a fraction.
func sale_price(id: String) -> int:
	var def: Dictionary = GameData.item(id)
	var value: float = float(def.get("value", 0))
	if not is_loot(id):
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
		if not is_loot(id):
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
		# a save may name a slot or an item this build no longer has; drop it rather than wear it
		var def: Dictionary = GameData.item(str(eq[slot]))
		if not def.is_empty() and slots_for(str(def.get("slot", ""))).has(slot):
			equipped[slot] = str(eq[slot])
