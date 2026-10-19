// Hair meshes on the real character bodies (MakeHuman CC0 hair, fitted by
// tools/assets/blender_mh_hair.py): the style's own painted texture gives the strands, their light
// and dark and the cut-out (alpha); its colour is replaced by hair_color, keeping the texture's
// brightness pattern. Alpha-hashed so the edges dither instead of sorting; both sides drawn.
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.07);
uniform sampler2D tex : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform float mean_luma = 0.3;          // the texture's average brightness where it is opaque

void fragment() {
	vec4 t = texture(tex, UV);
	float l = dot(t.rgb, vec3(0.3, 0.59, 0.11)) / max(mean_luma, 0.004);
	vec3 c = hair_color * clamp(pow(l, 1.25), 0.15, 2.2);
	if (!FRONT_FACING) {
		c *= 0.6;
	}
	ALBEDO = c;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.3;
	ROUGHNESS = 0.72;
	SPECULAR = 0.18;
	ANISOTROPY = 0.45;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
}
