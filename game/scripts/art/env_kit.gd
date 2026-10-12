class_name EnvKit
extends RefCounted
## Shared machinery for environment art (see Biomes): the terse prop builder, the rock
## generator, and the three shared materials every environment piece draws with.
##
## A prop is built once through an EnvKit builder (which bakes through ModelRig, so it gets
## the same baked occlusion, vertex-colour palette and material kinds as the characters),
## reduced to ONE ArrayMesh, and from then on drawn with the single shared prop_material() -
## so any number of copies of a prop share mesh and material and can go in a MultiMesh.

const SURFACE_SHADER := "
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;
uniform int mode = 0;
uniform vec3 base = vec3(0.3);
uniform vec3 alt = vec3(0.2);
uniform vec3 line_color = vec3(0.05);
uniform float size = 1.0;
varying vec3 wpos;
varying vec3 wnrm;
float hash2(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}
float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	return noise2(p) * 0.55 + noise2(p * 2.7) * 0.3 + noise2(p * 7.1) * 0.15;
}
// x: distance to the nearest cell border (0 at the joint), y: a random value per cell.
vec2 tiles(vec2 uv, vec2 cell, float stagger) {
	vec2 q = uv / cell;
	q.x += stagger * floor(q.y);
	vec2 id = floor(q);
	vec2 f = fract(q);
	vec2 d = min(f, 1.0 - f) * cell;
	return vec2(min(d.x, d.y), hash2(id));
}
vec2 cells(vec2 uv, float cell) {
	vec2 q = uv / cell;
	vec2 id = floor(q);
	float d1 = 9.0;
	float d2 = 9.0;
	float pick = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = id + vec2(float(x), float(y));
			vec2 c = o + 0.15 + 0.7 * vec2(hash2(o), hash2(o + 31.7));
			float d = length(q - c);
			if (d < d1) { d2 = d1; d1 = d; pick = hash2(o + 5.3); } else if (d < d2) { d2 = d; }
		}
	}
	return vec2((d2 - d1) * cell, pick);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 an = abs(wnrm);
	bool flat_face = an.y > 0.6;
	vec2 uv = flat_face ? wpos.xz : (an.x > an.z ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y));
	float blotch = fbm(uv * 0.35 + 3.0);
	float grit = fbm(uv * 4.0);
	vec3 col = base;
	float rough = 0.95;
	float joint = 1.0;
	float lift = 0.0;
	if (mode == 1 || mode == 2 || mode == 7) {
		vec2 cell = mode == 1 ? vec2(1.15, 0.8) : (mode == 2 ? vec2(0.84, 0.4) : vec2(2.6, 0.24));
		vec2 t = tiles(uv / size, cell, mode == 7 ? 0.37 : 0.5);
		joint = smoothstep(0.0, mode == 7 ? 0.012 : 0.035, t.x);
		lift = joint;
		col = mix(alt, base, t.y) * mix(0.82, 1.08, grit);
		if (mode == 7) { col *= mix(0.85, 1.05, noise2(vec2(uv.x * 1.5, uv.y * 40.0))); }
		col *= mix(0.8, 1.0, smoothstep(0.0, 0.12, t.x));
	} else if (mode == 3 || mode == 6) {
		vec2 warped = mode == 6 ? uv + (vec2(fbm(uv * 0.45), fbm(uv * 0.45 + 7.3)) - 0.5) * 2.2 : uv;
		vec2 c = cells(warped / size, mode == 3 ? 0.3 : 1.9);
		joint = mode == 3 ? smoothstep(0.0, 0.03, c.x) : mix(0.55, 1.0, smoothstep(0.0, 0.035, c.x));
		lift = mode == 3 ? smoothstep(0.0, 0.1, c.x) : joint;
		col = mix(alt, base, c.y) * mix(0.8, 1.08, grit);
		if (mode == 6 && !flat_face) { col *= mix(0.78, 1.06, noise2(vec2(uv.x * 0.25, uv.y * 3.0))); }
	} else if (mode == 4) {
		float drift = fbm(uv * 0.22);
		col = mix(alt, base, smoothstep(0.25, 0.7, drift));
		col *= mix(0.94, 1.03, fbm(uv * 1.7));
		lift = drift * 0.5;
		rough = 0.75;
	} else if (mode == 5) {
		float wet = smoothstep(0.5, 0.62, fbm(uv * 0.3 + 9.0));
		col = mix(base * mix(0.75, 1.1, grit), alt, wet);
		rough = mix(0.9, 0.12, wet);
		lift = 1.0 - wet;
	} else {
		col = mix(alt, base, smoothstep(0.3, 0.7, blotch)) * mix(0.8, 1.1, grit);
		vec2 c = cells(uv, 0.55);
		float pebble = step(0.8, c.y) * smoothstep(0.22, 0.3, c.x);
		col = mix(col, base * 1.25, pebble * 0.5);
		lift = pebble;
	}
	col = mix(line_color, col, joint);
	col *= mix(0.86, 1.06, blotch);
	if (!flat_face) { col *= mix(0.62, 1.0, smoothstep(0.0, 1.4, wpos.y)); }
	vec3 n = normalize(NORMAL);
	vec3 dpx = dFdx(VERTEX);
	vec3 dpy = dFdy(VERTEX);
	vec3 r1 = cross(dpy, n);
	vec3 r2 = cross(n, dpx);
	float det = dot(dpx, r1);
	float h = lift * 0.012;
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(det) * n - grad);
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = rough;
	SPECULAR = 0.3;
}
"

const WATER_SHADER := "
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;
uniform vec3 tint = vec3(0.08, 0.1, 0.06);
uniform float alpha = 0.78;
varying vec3 wpos;
float hash2(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}
float noise2(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float scum = smoothstep(0.55, 0.75, noise2(wpos.xz * 0.6) * 0.6 + noise2(wpos.xz * 2.3) * 0.4);
	float ripple = noise2(wpos.xz * 3.0 + TIME * 0.15);
	ALBEDO = mix(tint, tint * 1.5 + vec3(0.01, 0.025, 0.0), scum);
	ROUGHNESS = mix(0.22, 0.7, scum);
	SPECULAR = 0.35;
	NORMAL = normalize(NORMAL + vec3(ripple - 0.5, 0.0, noise2(wpos.zx * 3.0 - TIME * 0.12) - 0.5) * 0.08);
	ALPHA = mix(alpha, 0.95, scum);
}
"

const FOG_SHADER := "
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_back, shadows_disabled;
uniform vec3 tint = vec3(0.5, 0.56, 0.5);
uniform float alpha = 0.3;
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	ALBEDO = tint;
	ALPHA = alpha * pow(facing, 2.2);
}
"

static var _prop_material: ShaderMaterial
static var _surface_shader: Shader
static var _water_shader: Shader
static var _fog_shader: Shader
static var _surfaces: Dictionary[String, ShaderMaterial] = {}


## The one material every prop mesh uses (the character shader with default state).
static func prop_material() -> ShaderMaterial:
	if _prop_material == null:
		var probe := ModelRig.new()
		_prop_material = ShaderMaterial.new()
		_prop_material.shader = probe.shared_shader()
		probe.free()
	return _prop_material


## A shared patterned ground / masonry material. `mode`: 0 earth, 1 flagstones, 2 block
## courses, 3 cobbles, 4 snow, 5 mud with wet patches, 6 cracked rock, 7 planks. The pattern
## is laid out in world space, so pieces of any size meet without seams.
static func surface(mode: int, base: Color, alt: Color, line: Color = Color(0.04, 0.04, 0.04), size: float = 1.0) -> ShaderMaterial:
	var key: String = "%d|%s|%s|%s|%.2f" % [mode, base.to_html(false), alt.to_html(false), line.to_html(false), size]
	if _surfaces.has(key):
		return _surfaces[key]
	if _surface_shader == null:
		_surface_shader = Shader.new()
		_surface_shader.code = SURFACE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _surface_shader
	mat.set_shader_parameter("mode", mode)
	mat.set_shader_parameter("base", Vector3(base.r, base.g, base.b))
	mat.set_shader_parameter("alt", Vector3(alt.r, alt.g, alt.b))
	mat.set_shader_parameter("line_color", Vector3(line.r, line.g, line.b))
	mat.set_shader_parameter("size", size)
	_surfaces[key] = mat
	return mat


## Translucent standing water / ice sheet material.
static func water(tint: Color, alpha: float = 0.78) -> ShaderMaterial:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = WATER_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("alpha", alpha)
	return mat


## Soft, shadowless mist material for fog banks.
static func fog(tint: Color, alpha: float = 0.17) -> ShaderMaterial:
	if _fog_shader == null:
		_fog_shader = Shader.new()
		_fog_shader.code = FOG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _fog_shader
	mat.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	mat.set_shader_parameter("alpha", alpha)
	return mat


## A box mesh instance with a material: floors, wall cores, water sheets.
static func slab(size: Vector3, centre: Vector3, material: Material, shadows: bool = true) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	inst.mesh = box
	inst.position = centre
	inst.material_override = material
	if not shadows:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


## A mesh instance drawn with the shared prop material.
static func instance(mesh: Mesh) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = prop_material()
	return inst


## A lumpy boulder: a coarse sphere pushed in and out by a repeatable hash. Add it flat-shaded.
static func rock_mesh(radius: float, seed_value: int, rough: float = 0.28, sides: int = 9, rings: int = 5) -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = sides
	ball.rings = rings
	var arrays: Array = ball.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var key: Vector3 = (v / radius * 3.0).round()
		var h: float = fmod(absf(sin(key.x * 12.9898 + key.y * 78.233 + key.z * 37.719 + float(seed_value) * 3.17) * 43758.5453), 1.0)
		verts[i] = v * (1.0 + (h - 0.5) * 2.0 * rough)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_INDEX] = arrays[Mesh.ARRAY_INDEX]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## A new builder. `seed_value` makes its random choices repeatable (one seed per variant).
static func builder(seed_value: int = 1) -> EnvBuilder:
	return EnvBuilder.new(seed_value)
