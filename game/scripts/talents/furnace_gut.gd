extends TalentEffect
## Furnace Gut: reflux never locks the affinity. At the cap it vents as a burst around you,
## drops to 50, and wounds you.

const VENT_RADIUS := 4.5
const VENT_DAMAGE := 150.0
const VENT_TO := 50.0
const VENT_SELF_HARM := 8.0


func on_reflux_cap() -> bool:
	owner.call("_float", "VENT", Color(1, 0.6, 0.1))
	for node: Node in owner.get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e != null and e.global_position.distance_to((owner as Node3D).global_position) <= VENT_RADIUS:
			owner.call("deal_damage", e, VENT_DAMAGE, ["vent"])
	owner.set("reflux", VENT_TO)
	(owner.get("body") as Body).apply_self_harm(VENT_SELF_HARM)
	owner.call("discover", "Vent counts as your own damage: YES")
	return true
