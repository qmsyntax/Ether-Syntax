extends TalentEffect
## 1% Lifesteal: 1% of damage dealt to anything alive comes back as heal points.
## 1-star: Supreme quality only. 2-star: Dynamic (the player's _spend_heal_points knows the grade).

const RATE := 0.01


func on_dealt(ctx: HitContext) -> void:
	if ctx.applied <= 0.0 or not ctx.is_living:
		return
	var points: float = ctx.applied * RATE
	owner.set("heal_points_total", float(owner.get("heal_points_total")) + points)
	var used: float = owner.call("_spend_heal_points", points)
	if used > 0.0:
		owner.call("discover", "Pays on plants: YES" if ctx.is_scenery else "Pays on monsters: YES")
