class_name Crafting
extends RefCounted
## Crafting step 1 (design/12; the rules are design/11 section 4): recipes made at a station or on
## a field kit, with a skill per craft (0-300, no cap by stars - Brent 2026-10-18), a trivial, an
## attempt window, a chance of success, half the inputs back on a failure, skill-ups below trivial
## and tools that wear. Every number is in data/crafting.json "rules", read through GameData.
##
## The state lives on the player (craft_skill, craft_known, craft_made, tool_uses, all saved);
## this class holds the rules and changes that state. Where a combine is allowed (the station you
## stand at, the kit you carry) is main.gd's business: `ctx` is {station, grade, kit} and main
## builds it. A kit (kit != "") pays no fee and salvages only what the kit's own salvage says.


static func rule(key: String) -> float:
	return float((GameData.crafting.get("rules", {}) as Dictionary).get(key, 0.0))


static func recipe(id: String) -> Dictionary:
	return (GameData.crafting.get("recipes", {}) as Dictionary).get(id, {})


static func station(id: String) -> Dictionary:
	return (GameData.crafting.get("stations", {}) as Dictionary).get(id, {})


static func skill_name(skill: String) -> String:
	return str(((GameData.crafting.get("skills", {}) as Dictionary).get(skill, {}) as Dictionary).get("name", skill.capitalize()))


## Recipe ids made at this station (or on a kit standing in for it), easiest first.
static func recipes_at(station_id: String) -> Array[String]:
	var out: Array[String] = []
	var all: Dictionary = GameData.crafting.get("recipes", {})
	for id: String in all:
		if str((all[id] as Dictionary).get("station", "")) == station_id:
			out.append(id)
	return out


## Every recipe id of one skill.
static func recipes_of(skill: String) -> Array[String]:
	var out: Array[String] = []
	var all: Dictionary = GameData.crafting.get("recipes", {})
	for id: String in all:
		if str((all[id] as Dictionary).get("skill", "")) == skill:
			out.append(id)
	return out


static func skill_of(p: Node, skill: String) -> int:
	return int((p.get("craft_skill") as Dictionary).get(skill, 0))


static func knows(p: Node, rid: String) -> bool:
	return (p.get("craft_known") as Array).has(rid)


## Inside the attempt window: skill at least trivial - attempt_window (the recipe's min_skill).
static func in_window(p: Node, rid: String) -> bool:
	var r: Dictionary = recipe(rid)
	return skill_of(p, str(r.get("skill", ""))) >= int(r.get("min_skill", 0))


## How many of an item are in the pack.
static func count(p: Node, item_id: String) -> int:
	return (p.get("inventory") as Inventory).bag.count(item_id)


## The best tool of this kind in the pack (highest tier), or "".
static func best_tool(p: Node, kind: String) -> String:
	var best := ""
	var best_tier := -1
	for id: String in (p.get("inventory") as Inventory).bag:
		var t: Dictionary = GameData.item(id).get("tool", {})
		if str(t.get("kind", "")) == kind and int(t.get("tier", 0)) > best_tier:
			best = id
			best_tier = int(t.get("tier", 0))
	return best


static func tool_tier(item_id: String) -> int:
	return int((GameData.item(item_id).get("tool", {}) as Dictionary).get("tier", 0))


## Uses a fresh tool of this item has: rules.tool_uses_per_tier x its tier.
static func tool_uses_new(item_id: String) -> int:
	return int(rule("tool_uses_per_tier")) * maxi(1, tool_tier(item_id))


## Uses left on the tool of this item id in the pack (one is in use at a time).
static func tool_uses_left(p: Node, item_id: String) -> int:
	return int((p.get("tool_uses") as Dictionary).get(item_id, tool_uses_new(item_id)))


## The station fee for one combine: the recipe's fee, none on a kit.
static func fee(rid: String, ctx: Dictionary) -> int:
	return 0 if str(ctx.get("kit", "")) != "" else int(recipe(rid).get("fee", 0))


## Chance of success: clamp(floor, cap, at_trivial + (skill - trivial) x per_point + tool tiers
## above the one needed x tool_tier_bonus + station grades above the recipe's x
## station_grade_success); certain at trivial + certain_past_trivial.
static func chance(p: Node, rid: String, ctx: Dictionary) -> float:
	var r: Dictionary = recipe(rid)
	var skill: int = skill_of(p, str(r.get("skill", "")))
	var trivial: int = int(r.get("trivial", 0))
	if skill >= trivial + int(rule("certain_past_trivial")):
		return 1.0
	var c: float = rule("success_at_trivial") + float(skill - trivial) * rule("success_per_point")
	var tool_id: String = best_tool(p, str((r.get("tool", {}) as Dictionary).get("kind", "")))
	if tool_id != "":
		c += float(maxi(0, tool_tier(tool_id) - int((r.get("tool", {}) as Dictionary).get("tier", 1)))) * rule("tool_tier_bonus")
	c += float(maxi(0, int(ctx.get("grade", 1)) - int(r.get("grade", 1)))) * rule("station_grade_success")
	return clampf(c, rule("success_floor"), rule("success_cap"))


## Chance that each input comes back from a failure: rules.salvage + a grade bonus at a station,
## the kit's own salvage on a kit (none, for a Flensing Kit).
static func salvage_chance(rid: String, ctx: Dictionary) -> float:
	var kit: String = str(ctx.get("kit", ""))
	if kit != "":
		return float((GameData.item(kit).get("kit", {}) as Dictionary).get("salvage", 0.0))
	return clampf(rule("salvage") + float(maxi(0, int(ctx.get("grade", 1)) - int(recipe(rid).get("grade", 1)))) * rule("salvage_per_grade"), 0.0, 1.0)


## Chance of a skill-up on a combine that is not the recipe's first success: only below trivial.
static func skillup_chance(p: Node, rid: String, succeeded: bool) -> float:
	var r: Dictionary = recipe(rid)
	var gap: float = float(int(r.get("trivial", 0)) - skill_of(p, str(r.get("skill", ""))))
	if gap <= 0.0:
		return 0.0
	var c: float = minf(rule("skillup_cap"), rule("skillup_k") * sqrt(gap / rule("skillup_scale")))
	return c if succeeded else c * rule("skillup_fail_mult")


## What a success adds to the pack: {item id: n}, outputs and byproducts.
static func outputs(rid: String) -> Dictionary:
	var r: Dictionary = recipe(rid)
	var out: Dictionary = {str(r["output"]): int(r.get("makes", 1))}
	var by: Dictionary = r.get("byproducts", {}) if r.get("byproducts") != null else {}
	for id: String in by:
		out[id] = int(out.get(id, 0)) + int(by[id])
	return out


## Why this combine cannot be tried here and now, or "".
static func why_not(p: Node, rid: String, ctx: Dictionary) -> String:
	var r: Dictionary = recipe(rid)
	if r.is_empty():
		return "No such recipe."
	var kit: String = str(ctx.get("kit", ""))
	if str(r.get("station", "")) != str(ctx.get("station", "")):
		return "That is not made here."
	if kit != "" and count(p, kit) == 0:
		return "You do not have the kit."
	if not knows(p, rid):
		return "You have not learned it. The %s teaches the trade." % str(station(str(r["station"])).get("name", "station")).to_lower()
	if not in_window(p, rid):
		return "Beyond you yet: %s %d needed to try it." % [skill_name(str(r["skill"])), int(r.get("min_skill", 0))]
	var t: Dictionary = r.get("tool", {})
	var tool_id: String = best_tool(p, str(t.get("kind", "")))
	if tool_id == "" or tool_tier(tool_id) < int(t.get("tier", 1)):
		return "You need a %s (tier %d)." % [str(((GameData.crafting.get("tools", {}) as Dictionary).get(str(t.get("kind", "")), {}) as Dictionary).get("name", t.get("kind", "tool"))), int(t.get("tier", 1))]
	var ins: Dictionary = r.get("inputs", {})
	for id: String in ins:
		if count(p, id) < int(ins[id]):
			return "Not enough %s: %d of %d." % [str(GameData.item(id).get("name", id)), count(p, id), int(ins[id])]
	if not bool(p.call("can_afford", fee(rid, ctx))):
		return "Nobody rents a station on that much debt."
	# the pack must take what comes out, once the inputs are gone
	var inv: Inventory = p.get("inventory")
	var w: float = inv.weight()
	for id: String in ins:
		w -= float(GameData.item(id).get("weight", 0.0)) * float(ins[id])
	var outs: Dictionary = outputs(rid)
	for id: String in outs:
		w += float(GameData.item(id).get("weight", 0.0)) * float(outs[id])
	if w > inv.capacity() + 0.001:
		return "Your pack could not take what comes out."
	return ""


## One combine. Returns {ok, why, success, chance, made {id: n}, returned {id: n}, skill_up, broke}.
## The fee is paid and the inputs used either way; the tool loses a use either way.
static func combine(p: Node, rid: String, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var why: String = why_not(p, rid, ctx)
	if why != "":
		return {"ok": false, "why": why}
	var r: Dictionary = recipe(rid)
	var skill: String = str(r["skill"])
	var inv: Inventory = p.get("inventory")
	var p_success: float = chance(p, rid, ctx)
	p.call("charge", fee(rid, ctx))
	var ins: Dictionary = r.get("inputs", {})
	for id: String in ins:
		for i: int in int(ins[id]):
			inv.remove(id)
	# the tool comes back, a use the poorer; at none it breaks
	var tool_id: String = best_tool(p, str((r.get("tool", {}) as Dictionary).get("kind", "")))
	var uses: Dictionary = p.get("tool_uses")
	var left: int = tool_uses_left(p, tool_id) - 1
	var broke := ""
	if left <= 0:
		inv.remove(tool_id)
		uses.erase(tool_id)
		broke = tool_id
	else:
		uses[tool_id] = left
	var success: bool = p_success >= 1.0 or rng.randf() < p_success
	var made: Dictionary = {}
	var returned: Dictionary = {}
	if success:
		made = outputs(rid)
		for id: String in made:
			for i: int in int(made[id]):
				inv.bag.append(id)                 # room was checked before anything was used
	else:
		var back: float = salvage_chance(rid, ctx)
		for id: String in ins:
			for i: int in int(ins[id]):
				if rng.randf() < back:
					inv.bag.append(id)
					returned[id] = int(returned.get(id, 0)) + 1
	# skill: the first success of a recipe always teaches; after that only below trivial
	var up := 0
	var done: Array = p.get("craft_made")
	if success and not done.has(rid):
		done.append(rid)
		up = int(rule("first_success_up"))
	elif rng.randf() < skillup_chance(p, rid, success):
		up = 1
	var levels: Dictionary = p.get("craft_skill")
	var before: int = skill_of(p, skill)
	levels[skill] = mini(int(rule("skill_max")), before + up)
	up = int(levels[skill]) - before
	var item_name: String = str(GameData.item(str(r["output"])).get("name", r["output"]))
	if success:
		p.call("note", "Made %s%s." % [item_name, "" if int(r.get("makes", 1)) == 1 else " x%d" % int(r.get("makes", 1))])
	else:
		p.call("note", "The %s is spoiled. %s" % [item_name.to_lower(), "Some of it can be used again." if not returned.is_empty() else "Nothing is worth keeping."])
	if up > 0:
		p.call("note", "%s rises to %d." % [skill_name(skill), int(levels[skill])])
	if broke != "":
		p.call("note", "Your %s breaks." % str(GameData.item(broke).get("name", broke)).to_lower())
	return {"ok": true, "why": "", "success": success, "chance": p_success, "made": made, "returned": returned, "skill_up": up, "broke": broke}


## Learn every recipe of a skill from its craftsperson, for its teach_price. Returns "" or why not.
static func teach(p: Node, skill: String) -> String:
	var price: int = int(((GameData.crafting.get("skills", {}) as Dictionary).get(skill, {}) as Dictionary).get("teach_price", 0))
	var known: Array = p.get("craft_known")
	var new: Array[String] = []
	for rid: String in recipes_of(skill):
		if not known.has(rid):
			new.append(rid)
	if new.is_empty():
		return "You already know everything taught here."
	if not bool(p.call("can_afford", price)):
		return "Nobody teaches on that much debt."
	p.call("charge", price)
	known.append_array(new)
	p.call("note", "You learn the %s taught here: %d recipes." % [skill_name(skill).to_lower(), new.size()])
	return ""
