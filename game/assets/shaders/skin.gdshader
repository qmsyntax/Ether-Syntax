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
// an optional photographic skin baked onto this body: RGB = variation around the average skin
// (0.5 = average), A = where it is valid; photo_mix blends it in over the painted tone
uniform sampler2D photo_tex : hint_default_black, filter_linear_mipmap;
uniform float photo_mix = 0.0;
// a generated face is stored as RGB (JPEG) with the coverage in a separate one-channel mask
uniform sampler2D photo_mask : hint_default_white, filter_linear_mipmap;
uniform bool photo_has_mask = false;
// pores and fine wrinkles: a seamless tile (tools/assets/make_skin_micro.py) repeated finely over the
// body's layout, on top of the sculpt's normals
uniform sampler2D micro_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float micro_scale = 48.0;
uniform float micro_depth = 0.45;
uniform int photo_regions = -1;         // regions the photo is used on (all of the body)
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
	if (photo_mix > 0.0 && ((photo_regions >> region) & 1) == 1) {
		vec4 p = texture(photo_tex, UV);
		float pa = photo_has_mask ? texture(photo_mask, UV).r : p.a;
		// keep the photo's light and dark fully but only some of its colour shifts, so a face
		// photographed in one tone takes any chosen skin colour without casts
		float pl = dot(p.rgb, vec3(0.3, 0.59, 0.11));
		vec3 photo = skin_color * mix(vec3(pl), p.rgb, 0.45) * 2.0;
		base = mix(base, photo, photo_mix * smoothstep(0.3, 0.9, pa));
	}
	float photo_cover = 0.0;
	if (photo_mix > 0.0 && ((photo_regions >> region) & 1) == 1) {
		photo_cover = photo_mix * smoothstep(0.3, 0.9, photo_has_mask ? texture(photo_mask, UV).r : texture(photo_tex, UV).a);
	}
	// painted brows only where no photo with brows of its own covers the skin
	base = mix(base, hair_color * 0.85, clamp(a.b * 1.15, 0.0, 1.0) * 0.9 * brow_weight * (1.0 - photo_cover * 0.85));
	base = mix(base, mix(base, hair_color, 0.6), b.r * stubble);
	base = mix(base, hair_color * 0.55, clamp(b.g * 1.2, 0.0, 1.0) * scalp_shade);
	base = mix(base, base * vec3(1.18, 0.88, 0.86) + vec3(0.03), b.b * scar);
	ALBEDO = base * mix(1.0, d.g, 0.45);
	ROUGHNESS = clamp(0.6 - a.g * 0.22 + (0.5 - d.b) * 0.4, 0.28, 0.9);
	SPECULAR = 0.38;
	vec3 big = texture(normal_tex, UV).rgb * 2.0 - 1.0;
	vec3 fine = texture(micro_tex, UV * micro_scale).rgb * 2.0 - 1.0;
	fine.xy *= micro_depth;
	NORMAL_MAP = normalize(vec3(big.xy + fine.xy, big.z * fine.z)) * 0.5 + 0.5;
	AO = mix(1.0, d.g, 0.6);
	AO_LIGHT_AFFECT = 0.3;
	SSS_STRENGTH = 0.25;
}
