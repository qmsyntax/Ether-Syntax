class_name Wisp
extends Node3D
## A drifting mote of essence for the Netherecho: a soft additive glow ball about 0.25 across
## with a white-hot centre and a few orbiting sparks. It bobs, pulses and turns by itself.
## Build one with Models.wisp(affinity). The glow floats `hover_height` above the node's
## origin so the node can be placed on the floor like every other model.

const GLOW_SHADER := "
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint = vec3(1.0);
uniform float power = 1.0;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = (tint * pow(facing, 2.5) * 0.7 + vec3(0.9, 0.97, 1.0) * pow(facing, 14.0) * 1.2) * power;
}
"

static var _shader: Shader
static var _glow_mesh: SphereMesh
static var _spark_mesh: ArrayMesh

## Height of the glow's centre above the node's origin, in metres.
var hover_height: float = 0.5
## Peak-to-centre bob, in metres.
var bob: float = 0.07
## Glow colour.
var color: Color = Color(0.9, 0.95, 1.0)

var _mat: ShaderMaterial
var _glow: MeshInstance3D
var _sparks: MeshInstance3D
var _time: float = 0.0


func _init() -> void:
	_time = randf() * 20.0


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = GLOW_SHADER
		_glow_mesh = SphereMesh.new()
		_glow_mesh.radius = 0.125
		_glow_mesh.height = 0.25
		_glow_mesh.radial_segments = 16
		_glow_mesh.rings = 8
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var spark := SphereMesh.new()
		spark.radius = 0.022
		spark.height = 0.044
		spark.radial_segments = 6
		spark.rings = 3
		for i: int in 3:
			var a: float = TAU * float(i) / 3.0
			st.append_from(spark, 0, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.17, 0.05 * float(i - 1), sin(a) * 0.17)))
		_spark_mesh = st.commit()
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	_glow = MeshInstance3D.new()
	_glow.mesh = _glow_mesh
	_glow.material_override = _mat
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_sparks = MeshInstance3D.new()
	_sparks.mesh = _spark_mesh
	_sparks.material_override = _mat
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow.add_child(_sparks)
	_apply()


func _process(delta: float) -> void:
	_time += delta
	_apply()


func _apply() -> void:
	var pulse: float = sin(_time * 3.1)
	_glow.position = Vector3(sin(_time * 0.9) * 0.03, hover_height + sin(_time * 1.7) * bob, cos(_time * 0.7) * 0.03)
	_glow.scale = Vector3.ONE * (1.0 + 0.12 * pulse)
	_sparks.rotation = Vector3(0.3 * sin(_time * 0.8), _time * 2.4, 0.0)
	_mat.set_shader_parameter("power", 1.0 + 0.25 * pulse)
