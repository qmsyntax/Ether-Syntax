class_name EnemyLooks
extends RefCounted
## Telegraphs and the rig. A part of the enemy (docs/architecture/enemy-split.md): the body it is drawn
## with (built in setup: the model, the collision capsule, an aura ring, the label), facing and posing
## the rig each frame, and the melee telegraph the HUD draws. `telegraph` and `_rig` stay on the node:
## the HUD, Beast and the tests read them.

var enemy: Enemy
var _label: Label3D
var _shown_highlight := 0
var _shown_windup := false
var _shown_down := false


func _init(of: Enemy) -> void:
	enemy = of


## Build the body it is drawn with: the model, the collision capsule, the aura ring if its kind
## has one, and the (hidden) health label. Called from setup, in the order the nodes are added.
func build(d: Dictionary) -> void:
	# The look: a real body when real bodies are on (Models.enemy), else a procedural model.
	# Gameplay size still comes from data.
	enemy._rig = Models.enemy(enemy.kind)
	enemy.add_child(enemy._rig)

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = enemy.radius
	shape.height = enemy.height
	col.shape = shape
	col.position.y = enemy.height * 0.5
	enemy.add_child(col)

	if d.has("aura_ring"):
		# a ring on the ground at the distance that matters for this one (design/05 6.1)
		var ring_def: Dictionary = d["aura_ring"]
		var rc: Array = ring_def.get("color", [1.0, 1.0, 1.0])
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.outer_radius = float(ring_def["radius"])
		torus.inner_radius = float(ring_def["radius"]) - 0.07
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		var ring_mat := StandardMaterial3D.new()
		ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_mat.albedo_color = Color(float(rc[0]), float(rc[1]), float(rc[2]), 0.4)
		ring.material_override = ring_mat
		ring.position.y = 0.06
		ring.scale.y = 0.2
		enemy.add_child(ring)

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 36
	_label.outline_size = 10
	_label.pixel_size = 0.01
	_label.position.y = enemy.height + 0.5
	_label.visible = false          # health is shown by the HUD's floating bars and target frame
	enemy.add_child(_label)
	_refresh_label()


func _update_melee_telegraph() -> void:
	if enemy._windup < 0.0:
		enemy.telegraph = {}
	elif str(enemy._def.get("attack_shape", "single")) == "circle":
		enemy.telegraph = {"kind": "circle", "radius": float(enemy._def.get("attack_radius", 3.0)), "frac": 1.0 - enemy._windup / maxf(0.001, enemy._windup_time),
			"interruptible": bool(enemy._def.get("interruptible", false))}
	else:
		enemy.telegraph = {"kind": "swing", "interruptible": bool(enemy._def.get("interruptible", false))}


func _apply_facing() -> void:
	if enemy._rig != null and is_instance_valid(enemy._rig):
		enemy._rig.rotation.y = atan2(-enemy.facing.x, -enemy.facing.z)


func _look(delta: float) -> void:
	if enemy._rig == null:
		return                                      # the body has been handed to the world to lie
	enemy._strike_t -= delta
	_apply_facing()
	var winding: bool = enemy._windup >= 0.0
	if winding != _shown_windup:
		_shown_windup = winding
		enemy._rig.set_windup(winding)
	var down: bool = enemy.status_part._st_any("cannot_act") or enemy.status_part._kneeling()
	if down != _shown_down:
		_shown_down = down
		if enemy._rig.has_method("set_staggered"):
			enemy._rig.set_staggered(down)                # slumped, head down: the moment for a bare strike
	if enemy.highlight != _shown_highlight:
		_shown_highlight = enemy.highlight
		enemy._rig.set_highlight(enemy.highlight)
	enemy._rig.animate(delta, enemy.velocity.length(), enemy._strike_t > 0.0)


func _refresh_label() -> void:
	_label.text = "%d" % int(ceil(enemy.body.total()))
