extends TalentEffect
## Grudge: +2% damage against a specific enemy for every hit that enemy has landed on you.

var _hits_from: Dictionary = {}


func on_incoming(ctx: HitContext) -> void:
	if is_instance_valid(ctx.source):
		var key: int = ctx.source.get_instance_id()
		_hits_from[key] = int(_hits_from.get(key, 0)) + 1


func on_outgoing(ctx: HitContext) -> void:
	ctx.mult *= 1.0 + 0.02 * float(_hits_from.get(ctx.target.get_instance_id(), 0))
