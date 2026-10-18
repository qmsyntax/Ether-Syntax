// Hair cards for the real character bodies: each card (U across, V root to tip) is cut into a
// handful of strands of uneven length by alpha scissor, darker at the root. UV2.y is a random
// number per card. Both sides drawn.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.07);
uniform float strands = 16.0;

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
	float profile = 1.0 - smoothstep(width * 0.5 - 0.08, width * 0.5, abs(f - 0.5));
	float alive = 1.0 - smoothstep(len - 0.08, len, UV.y);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x);
	ALPHA = profile * alive * mix(1.0, edge, 0.5 + 0.5 * UV.y);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 c = hair_color * (0.72 + 0.5 * hash(id + card_rand * 13.0)) * mix(0.5, 1.0, smoothstep(0.0, 0.35, UV.y));
	if (!FRONT_FACING) {
		c *= 0.7;
	}
	ALBEDO = c;
	ROUGHNESS = 0.55;
	SPECULAR = 0.3;
	ANISOTROPY = 0.8;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
}
