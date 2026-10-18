// Cloth and leather for the real character bodies. A tiling material (albedo / normal / roughness)
// tinted towards `color` by `tint` (1 = only the texture's light and dark, in `color`; 0 = the
// texture as it is). Optional diamond quilting. Both sides drawn, the inside darker. UV2.x is the
// body region a face came from: regions set in hidden_mask are not drawn (under other layers, a
// lost forearm).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.5);
uniform float tint = 1.0;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float uv_scale = 1.0;
uniform float rough_bias = 0.0;
uniform float normal_depth = 1.0;
uniform float quilt = 0.0;
uniform float quilt_size = 0.11;
uniform float grime = 0.3;
uniform float sheen = 0.0;
uniform int hidden_mask = 0;

varying flat int region;
varying vec3 rest_pos;

void vertex() {
	region = int(UV2.x);
	rest_pos = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	if (((hidden_mask >> region) & 1) == 1) {
		discard;
	}
	vec2 uv = UV * uv_scale;
	vec3 t = texture(albedo_tex, uv).rgb;
	vec3 mean = textureLod(albedo_tex, vec2(0.5), 12.0).rgb;
	float l = dot(t, vec3(0.3, 0.59, 0.11)) / max(dot(mean, vec3(0.3, 0.59, 0.11)), 0.02);
	vec3 c = mix(t, color * l, tint);
	vec3 n = texture(normal_tex, uv).rgb;
	if (quilt > 0.0) {
		vec2 q = UV / quilt_size;
		vec2 r = vec2(q.x + q.y, q.x - q.y);
		vec2 f = abs(fract(r) - 0.5);
		float edge = max(f.x, f.y);
		float seam = smoothstep(0.40, 0.48, edge);
		c *= 1.0 - seam * 0.45 * quilt;
		vec2 slope = (fract(r) - 0.5) * 0.9 * quilt;
		n = normalize(n * 2.0 - 1.0 + vec3(slope.x + slope.y, slope.x - slope.y, 0.0)) * 0.5 + 0.5;
	}
	float g = vnoise(UV * 7.0) * 0.6 + vnoise(UV * 23.0) * 0.4;
	c *= 1.0 - grime * smoothstep(0.45, 0.95, g) * 0.5;
	if (!FRONT_FACING) {
		c *= 0.45;
	}
	ALBEDO = c;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(texture(rough_tex, uv).r + rough_bias, 0.05, 1.0);
	SPECULAR = 0.35;
	RIM = sheen;
	RIM_TINT = 0.6;
}
