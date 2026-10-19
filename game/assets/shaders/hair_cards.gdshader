// Hair cards for the real character bodies: each card (U across, V root to tip) is cut into a
// handful of strands of uneven length by alpha scissor, darker at the root. UV2.y is a random
// number per card. Both sides drawn.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.07);
uniform float strands = 16.0;
// a painted sheet of grey hair (MakeHuman, CC0): each card reads its own narrow slice of it, root at
// the top, for the strands' light and dark and the highlights; tinted to hair_color
uniform sampler2D strand_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

varying float card_rand;

void vertex() {
	card_rand = UV2.y;
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	float x = UV.x * strands + card_rand * 37.0;
	float id = floor(x);
	float f = fract(x);
	// strands of uneven length; near the root they crowd together (solid), towards the tip they
	// thin out to single hairs
	float len = 0.55 + 0.45 * hash(id * 1.7 + card_rand * 91.0);
	float width = mix(0.95, 0.45, smoothstep(0.1, 0.9, UV.y / len));
	// strands thinner than a pixel would alias into dots: as they shrink on screen they merge into
	// solid hair (the filter width of the strand coordinate decides)
	float aa = fwidth(x);
	width = mix(width, 1.2, smoothstep(0.25, 0.7, aa));
	float e = clamp(aa * 0.5, 0.04, 0.1);
	float profile = 1.0 - smoothstep(width * 0.5 - e, width * 0.5 + e, abs(f - 0.5));
	float aay = fwidth(UV.y);
	float alive = 1.0 - smoothstep(len - max(0.08, aay * 2.0), len, UV.y);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALPHA = profile * alive * mix(1.0, edge, 0.5 + 0.5 * UV.y);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec2 suv = vec2(fract(card_rand * 7.13) * 0.8 + UV.x * 0.2, UV.y * (0.35 + 0.6 * fract(card_rand * 3.7)));
	float sheet = texture(strand_tex, suv).r / max(textureLod(strand_tex, vec2(0.5), 10.0).r, 0.05);
	vec3 c = hair_color * sheet * (0.8 + 0.35 * hash(id + card_rand * 13.0)) * mix(0.55, 1.0, smoothstep(0.0, 0.3, UV.y));
	if (!FRONT_FACING) {
		c *= 0.7;
	}
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	ANISOTROPY = 0.8;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
}
