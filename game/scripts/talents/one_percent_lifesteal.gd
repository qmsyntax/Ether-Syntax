extends TalentEffect
## 1% Lifesteal: 1% of damage dealt to anything alive comes back as heal points.
## 1-star: Supreme quality only. 2-star: Dynamic (the player's _spend_heal_points knows the grade).

const RATE := 0.01

## Health returned since the last number was shown: one swing can pay on several targets, and
## several small "+1" floats on top of each other read as nothing at all.
var _shown_pending := 0.0


func on_dealt(ctx: HitContext) -> void:
	if ctx.applied <= 0.0 or not ctx.is_living:
		return
	var points: float = ctx.applied * RATE
	owner.set("heal_points_total", float(owner.get("heal_points_total")) + points)
	var before: float = (owner.get("body") as Body).total()
	var used: float = owner.call("_spend_heal_points", points)
	_shown_pending += (owner.get("body") as Body).total() - before
	if used > 0.0:
		owner.call("discover", "Pays on plants: YES" if ctx.is_scenery else "Pays on monsters: YES")


func on_tick(_delta: float) -> void:
	if _shown_pending >= 0.05:
		owner.call("_float", "+%.1f" % _shown_pending, Color(0.45, 1.0, 0.55))
	_shown_pending = 0.0
