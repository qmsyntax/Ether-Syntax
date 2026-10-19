// Cloth and leather for the real character bodies. Two layers:
// - a tiling material (albedo / normal / roughness) tinted towards `color` by `tint` (1 = only the
//   texture's light and dark, in `color`; 0 = the texture as it is), tiled by UV * UV2.y (UV2.y is
//   how many fabric tiles the garment's own layout spans, from tools/assets/blender_character.py);
// - the garment's own baked maps: fold_tex (tangent normals of the cloth draped by simulation) and
//   detail_tex (R occlusion, G convexity of the folds - 0.5 flat, B hem band, A stitching).
// Optional diamond quilting. Both sides drawn, the inside darker. UV2.x is the body region a face
// came from: regions set in hidden_mask are not drawn (under other layers, a lost forearm).
shader_type spatial;
render_mode cull_disabled;

uniform vec3 color : source_color = vec3(0.5);
uniform float tint = 1.0;
uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D fold_tex : hint_normal, filter_linear_mipmap;
uniform sampler2D detail_tex : hint_default_white, filter_linear_mipmap;
uniform bool baked = false;
uniform float uv_scale = 1.0;
uniform float rough_bias = 0.0;
uniform float normal_depth = 1.0;
uniform float fold_depth = 1.0;
uniform float quilt = 0.0;
uniform float quilt_size = 0.2;
uniform float grime = 0.3;
uniform float wear = 0.35;
uniform float sheen = 0.0;
uniform int hidden_mask = 0;

varying flat int region;
varying float tiles;

void vertex() {
	region = int(UV2.x);
	tiles = UV2.y > 0.0 ? UV2.y : 1.0;
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
	vec2 fab = UV * tiles;                    // ~0.35 m of cloth per unit, like the old layouts
	vec2 uv = fab * uv_scale;
	vec3 t = texture(albedo_tex, uv).rgb;
	vec3 mean = textureLod(albedo_tex, vec2(0.5), 12.0).rgb;
	float l = dot(t, vec3(0.3, 0.59, 0.11)) / max(dot(mean, vec3(0.3, 0.59, 0.11)), 0.02);
	vec3 c = mix(t, color * l, tint);
	vec3 n = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	n.xy *= normal_depth;
	float rough = texture(rough_tex, uv).r + rough_bias;
	if (quilt > 0.0) {
		vec2 q = fab / quilt_size;
		vec2 r = vec2(q.x + q.y, q.x - q.y);
		vec2 f = abs(fract(r) - 0.5);
		float seam = smoothstep(0.40, 0.48, max(f.x, f.y));
		c *= 1.0 - seam * 0.45 * quilt;
		vec2 slope = (fract(r) - 0.5) * 0.9 * quilt;
		n = normalize(n + vec3(slope.x + slope.y, slope.x - slope.y, 0.0));
	}
	// large blotches of wear and dirt so no two patches of cloth look alike
	float g = vnoise(fab * 2.3) * 0.6 + vnoise(fab * 9.0) * 0.4;
	c *= 1.0 - grime * smoothstep(0.45, 0.95, g) * 0.5;
	if (baked) {
		vec4 d = texture(detail_tex, UV);
		vec3 fold = texture(fold_tex, UV).rgb * 2.0 - 1.0;
		fold.xy *= fold_depth;
		n = normalize(vec3(fold.xy + n.xy, fold.z * n.z));      // whiteout blend: folds, then weave
		float crest = clamp((d.g - 0.5) * 2.0, 0.0, 1.0);
		float valley = clamp((0.5 - d.g) * 2.0, 0.0, 1.0);
		c *= mix(1.0, d.r, 0.7);                                  // occlusion: armpits, under collars
		c *= 1.0 - valley * 0.35 - d.b * 0.12;                    // dirt in the fold valleys, a heavier hem
		vec3 worn = mix(c, vec3(dot(c, vec3(0.33))) * 1.35 + 0.03, 0.6);
		c = mix(c, worn, clamp(crest * wear + d.b * wear * 0.5, 0.0, 1.0));   // rubbed pale on crests and hems
		c = mix(c, c * 1.6 + vec3(0.04), d.a * 0.75);             // thread
		rough = mix(rough, rough + 0.1, valley) - d.a * 0.15;
	}
	if (!FRONT_FACING) {
		c *= 0.45;
	}
	ALBEDO = c;
	NORMAL_MAP = n * 0.5 + 0.5;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	SPECULAR = 0.35;
	RIM = sheen;
	RIM_TINT = 0.6;
}
