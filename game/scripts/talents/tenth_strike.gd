extends TalentEffect
## Tenth Strike: every 10th hit on the same target deals x5.

var _counts: Dictionary = {}


func on_outgoing(ctx: HitContext) -> void:
	var key: int = ctx.target.get_instance_id()
	var count: int = int(_counts.get(key, 0)) + 1
	_counts[key] = count
	if count % 10 == 0:
		ctx.mult *= 5.0
		ctx.tags.append("tenth")
		owner.call("_text", ctx.target, "TENTH", Color(1, 0.85, 0.2))
