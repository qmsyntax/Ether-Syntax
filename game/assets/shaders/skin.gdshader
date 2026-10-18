// Skin for the real character bodies (scripts/art/real_character.gd). The body's baked maps are
// neutral: detail R is a tone around 0.5 (the chosen skin colour), G ambient occlusion, B cavity;
// mask_a R redness, G lips, B brows, A eye shadow; mask_b R beard area, G scalp, B scar.
// UV2.x carries a region id per vertex; a region whose bit is set in hidden_mask is not drawn
// (skin under clothes, a lost forearm).
shader_type spatial;
render_mode cull_back;

uniform vec3 skin_color : source_color = vec3(0.68, 0.52, 0.41);
uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.07);
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap;
uniform sampler2D mask_a : hint_default_black, filter_linear_mipmap;
uniform sampler2D mask_b : hint_default_black, filter_linear_mipmap;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float stubble = 0.0;
uniform float scalp_shade = 0.0;
uniform float scar = 0.0;
uniform float brow_weight = 1.0;
uniform int hidden_mask = 0;

varying flat int region;

void vertex() {
	region = int(UV2.x);
}

void fragment() {
	if (((hidden_mask >> region) & 1) == 1) {
		discard;
	}
	vec4 d = texture(detail_tex, UV);
	vec4 a = texture(mask_a, UV);
	vec4 b = texture(mask_b, UV);
	vec3 base = skin_color * (0.55 + 0.9 * d.r);
	base = mix(base, base * vec3(1.16, 0.80, 0.78), a.r * 0.6);
	base = mix(base, base * vec3(1.02, 0.66, 0.66), a.g * 0.8);
	base = mix(base, base * vec3(0.72, 0.66, 0.70), a.a * 0.5);
	base = mix(base, hair_color * 0.85, clamp(a.b * 1.15, 0.0, 1.0) * 0.9 * brow_weight);
	base = mix(base, mix(base, hair_color, 0.6), b.r * stubble);
	base = mix(base, hair_color * 0.55, clamp(b.g * 1.2, 0.0, 1.0) * scalp_shade);
	base = mix(base, base * vec3(1.18, 0.88, 0.86) + vec3(0.03), b.b * scar);
	ALBEDO = base * mix(1.0, d.g, 0.45);
	ROUGHNESS = clamp(0.6 - a.g * 0.22 + (0.5 - d.b) * 0.4, 0.28, 0.9);
	SPECULAR = 0.38;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	AO = mix(1.0, d.g, 0.6);
	AO_LIGHT_AFFECT = 0.3;
	SSS_STRENGTH = 0.25;
}
