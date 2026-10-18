// Ground: two tileable PBR layers (bare earth, dead grass) mapped in world space and blended by a
// large soft mask, each sampled twice at different scales and turns so the repeat never shows.
// Normals are rebuilt in world space from the maps (OpenGL convention), so the floor can sit at
// any rotation without its relief being lit from the wrong side.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D a_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_normal : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_rough : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro_mask : filter_linear, repeat_enable;     // R tone, G layer-b mask, B damp

uniform float tile_m = 3.0;          // metres one tile covers
uniform float macro_m = 60.0;        // metres the macro mask covers
uniform float b_amount = 0.6;        // how much of the ground is layer b
uniform float normal_strength = 1.0;
uniform vec3 tint = vec3(1.0);
uniform float b_darken = 0.8;      // layer b is drawn this much darker (dead grass reads too light from above)
uniform float saturation = 0.8;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 turn(vec2 uv, float a) {
	return vec2(cos(a) * uv.x - sin(a) * uv.y, sin(a) * uv.x + cos(a) * uv.y);
}

// tangent-space map sample -> world normal for a floor lying in XZ
vec3 world_n(vec3 m, float a) {
	vec3 t = m * 2.0 - 1.0;
	vec2 xz = turn(vec2(t.x, -t.y), -a);
	return normalize(vec3(xz.x * normal_strength, t.z, xz.y * normal_strength));
}

void fragment() {
	vec2 p = world_pos.xz;
	vec4 macro = texture(macro_mask, p / macro_m);
	float swap = smoothstep(0.35, 0.65, texture(macro_mask, p / (macro_m * 0.41) + 0.37).r);
	float a1 = 0.0;
	float a2 = 1.9;
	vec2 uv1 = p / tile_m;
	vec2 uv2 = turn(p / (tile_m * 1.37), a2) + 0.29;

	vec3 alb_a = mix(texture(a_albedo, uv1).rgb, texture(a_albedo, uv2).rgb, swap);
	vec3 alb_b = mix(texture(b_albedo, uv1).rgb, texture(b_albedo, uv2).rgb, swap);
	vec3 n_a = normalize(mix(world_n(texture(a_normal, uv1).rgb, a1), world_n(texture(a_normal, uv2).rgb, a2), swap));
	vec3 n_b = normalize(mix(world_n(texture(b_normal, uv1).rgb, a1), world_n(texture(b_normal, uv2).rgb, a2), swap));
	float r_a = mix(texture(a_rough, uv1).r, texture(a_rough, uv2).r, swap);
	float r_b = mix(texture(b_rough, uv1).r, texture(b_rough, uv2).r, swap);

	float g = smoothstep(0.15, 0.95, macro.g) * b_amount;
	vec3 albedo = mix(alb_a, alb_b * b_darken, g);
	albedo *= mix(0.62, 1.08, macro.r);                 // broad light and dark ground
	float grey = dot(albedo, vec3(0.299, 0.587, 0.114));
	albedo = mix(vec3(grey), albedo, saturation);
	albedo *= mix(1.0, 0.72, macro.b);                  // damp hollows
	ALBEDO = albedo * tint;
	ROUGHNESS = mix(mix(r_a, r_b, g), 0.62, macro.b * 0.6);
	vec3 wn = normalize(mix(n_a, n_b, g));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
