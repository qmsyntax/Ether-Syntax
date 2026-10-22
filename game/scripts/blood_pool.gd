class_name BloodPool
extends Node3D
## Spilled blood on the floor (Blood's rule, 2026-10-22 drafts): `measures` of blood in a pool of
## `radius`, drying after `life`. A new pool that touches one merges into it (up to 3 measures and
## twice the radius). At most affinities.blood.pool.max in a level: the oldest dries first. Pools do
## nothing on their own; blood skills drink them (Deep Draught) or ride them (Thinblood Rush).

var radius := 0.5
var life := 15.0
var measures := 1

var _mesh: MeshInstance3D
var _born := 0


## Spill `measures` at `at`, merging with a pool it touches. Returns the pool that holds it.
static func spill(parent: Node, at: Vector3, measures_in: int = 1, big: bool = false) -> BloodPool:
	var cfg: Dictionary = GameData.affinity("blood").get("pool", {})
	var r: float = float(cfg.get("death_radius" if big else "radius", 0.5))
	if parent == null or not parent.is_inside_tree():
		return null
	for node: Node in parent.get_tree().get_nodes_in_group("blood_pools"):
		var p := node as BloodPool
		if p != null and Vector2(p.global_position.x - at.x, p.global_position.z - at.z).length() <= p.radius + r:
			p.measures = mini(3, p.measures + measures_in)
			p.radius = minf(float(cfg.get("radius", 0.5)) * 2.0, maxf(p.radius, r) + 0.15)
			p.life = float(cfg.get("life", 15.0))
			p._resize()
			return p
	var pools: Array = parent.get_tree().get_nodes_in_group("blood_pools")
	if pools.size() >= int(cfg.get("max", 12)):
		var oldest: BloodPool = null
		for node: Node in pools:
			if oldest == null or (node as BloodPool)._born < oldest._born:
				oldest = node as BloodPool
		if oldest != null:
			oldest.remove_from_group("blood_pools")
			oldest.queue_free()
	var pool := BloodPool.new()
	pool.radius = r
	pool.measures = measures_in
	pool.life = float(cfg.get("life", 15.0))
	pool._born = Time.get_ticks_usec()
	parent.add_child(pool)
	pool.global_position = Vector3(at.x, at.y, at.z)
	return pool


func _ready() -> void:
	add_to_group("blood_pools")
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.03, 0.05, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.15
	_mesh.material_override = mat
	_mesh.position.y = 0.03
	add_child(_mesh)
	_resize()


func _resize() -> void:
	if _mesh == null:
		return
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.02
	disc.radial_segments = 20
	_mesh.mesh = disc


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		remove_from_group("blood_pools")
		queue_free()


## True if a body at `point` (radius `margin`) stands in it.
func has_point(point: Vector3, margin: float = 0.0) -> bool:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length() <= radius + margin


## Drink it: the pool is gone and its measures are returned.
func drink() -> int:
	remove_from_group("blood_pools")
	queue_free()
	return measures
