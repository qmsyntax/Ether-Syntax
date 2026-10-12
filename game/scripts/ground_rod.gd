class_name GroundRod
extends Node3D
## Lightning's placed object (design/05 3.5, Ground Rod): a thin rod that blocks nothing. While
## it stands, every lightning skill its caster uses within reach of it also arcs from the rod to
## the nearest enemy (see Player._rod_relay). It only keeps time and draws itself.

var life := 10.0
var color := Color(0.85, 0.78, 1.0)


func _ready() -> void:
	add_to_group("ground_rods")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.37, 0.42)
	mat.metallic = 0.6
	mat.roughness = 0.5
	var shaft := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.05
	cyl.height = 2.0
	shaft.mesh = cyl
	shaft.material_override = mat
	shaft.position.y = 1.0
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.18
	tip.mesh = ball
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.0
	tip.material_override = glow
	tip.position.y = 2.05
	add_child(tip)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
