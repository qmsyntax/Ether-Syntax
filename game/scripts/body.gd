class_name Body
extends RefCounted
## Three-layer wound model (spec section 1). Damage works down through the layers;
## healing works back up from the worst layer first.

const ORDER_DAMAGE: Array[String] = ["superficial", "structural", "catastrophic"]
const ORDER_HEAL: Array[String] = ["catastrophic", "structural", "superficial"]
const ORDER_SELF_HARM: Array[String] = ["structural", "catastrophic", "superficial"]

## Dynamic-quality healing: HP restored per heal point, by layer.
## Supreme-quality healing restores 1 HP per point in every layer.
const DYNAMIC_HP_PER_POINT := {"superficial": 100.0, "structural": 10.0, "catastrophic": 1.0}

var max_hp: Dictionary = {}
var hp: Dictionary = {}


func _init(superficial: float, structural: float = 0.0, catastrophic: float = 0.0) -> void:
	max_hp = {"superficial": superficial, "structural": structural, "catastrophic": catastrophic}
	hp = max_hp.duplicate()


func total() -> float:
	return float(hp["superficial"]) + float(hp["structural"]) + float(hp["catastrophic"])


func total_max() -> float:
	return float(max_hp["superficial"]) + float(max_hp["structural"]) + float(max_hp["catastrophic"])


func is_dead() -> bool:
	return total() <= 0.0


func missing(layer: String) -> float:
	return float(max_hp[layer]) - float(hp[layer])


## Returns the damage actually applied (never more than what was left - no overkill).
func apply_damage(amount: float, heavy: bool = false) -> float:
	var applied: float = minf(amount, total())
	var remaining: float = applied
	if heavy:
		remaining -= _drain("structural", remaining * 0.5)
	for layer: String in ORDER_DAMAGE:
		if remaining <= 0.0:
			break
		remaining -= _drain(layer, remaining)
	return applied


## Self-inflicted costs (overcharge, reflux burn) go straight to the deep layers.
func apply_self_harm(amount: float) -> float:
	var applied: float = minf(amount, total())
	var remaining: float = applied
	for layer: String in ORDER_SELF_HARM:
		if remaining <= 0.0:
			break
		remaining -= _drain(layer, remaining)
	return applied


## Spends heal points, worst layer first. Returns points actually used.
func heal(points: float, dynamic_quality: bool) -> float:
	var left: float = points
	for layer: String in ORDER_HEAL:
		if left <= 0.0:
			break
		var gap: float = missing(layer)
		if gap <= 0.0:
			continue
		var rate: float = float(DYNAMIC_HP_PER_POINT[layer]) if dynamic_quality else 1.0
		var healed: float = minf(gap, left * rate)
		hp[layer] = float(hp[layer]) + healed
		left -= healed / rate
	return points - left


func heal_layer(layer: String, amount: float) -> float:
	var healed: float = minf(amount, missing(layer))
	hp[layer] = float(hp[layer]) + healed
	return healed


func scale_max(factor: float) -> void:
	for layer: String in max_hp:
		max_hp[layer] = float(max_hp[layer]) * factor
	hp = max_hp.duplicate()


func _drain(layer: String, amount: float) -> float:
	var took: float = minf(amount, float(hp[layer]))
	hp[layer] = float(hp[layer]) - took
	return took
