// The anatomy piece over the real character bodies (tools/assets/blender_anatomy.py): its own small
// texture (variation around the average skin, 0.5 = average) in the chosen skin colour, fading out
// towards its edge (vertex colour alpha) with dithered alpha, so it melts into the body under it.
shader_type spatial;
render_mode cull_back;

uniform vec3 skin_color : source_color = vec3(0.68, 0.52, 0.41);
uniform sampler2D tex : hint_default_white, filter_linear_mipmap;

void fragment() {
	ALBEDO = skin_color * texture(tex, UV).rgb * 2.0;
	ROUGHNESS = 0.55;
	SPECULAR = 0.38;
	SSS_STRENGTH = 0.25;
	ALPHA = COLOR.a;
	ALPHA_HASH_SCALE = 1.0;
}
