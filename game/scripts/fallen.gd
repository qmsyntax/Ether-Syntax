class_name Fallen
extends Node3D
## An enemy's body where it fell, as Death's skills see it (2026-10-22 drafts): it lies `life`
## seconds (balance.combat.corpse_lie_s, or the Death affinity's corpse_lie_s while someone in the
## fight holds Death), and a Death skill can spend it once. It is only a place and a kind; the body
## you see is the enemy's own model, lying where it fell.

var kind := ""
var life := 8.0
var spent := false
var age := 0.0


func _ready() -> void:
	add_to_group("fallen")


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	age += delta
	life -= delta
	if life <= 0.0:
		spend()


## Used up by a skill (or gone to dust).
func spend() -> void:
	spent = true
	remove_from_group("fallen")
	queue_free()


## The nearest unspent body within `reach` of `point`, or null.
static func nearest(tree: SceneTree, point: Vector3, reach: float) -> Fallen:
	var best: Fallen = null
	if tree == null:
		return best
	for node: Node in tree.get_nodes_in_group("fallen"):
		var f := node as Fallen
		if f == null or f.spent:
			continue
		var d: float = Vector2(f.global_position.x - point.x, f.global_position.z - point.z).length()
		if d <= reach and (best == null or d < Vector2(best.global_position.x - point.x, best.global_position.z - point.z).length()):
			best = f
	return best
