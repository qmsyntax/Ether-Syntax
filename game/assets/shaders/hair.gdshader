// Hair shells for the real character bodies: strands along the UV's V direction (the build gives
// hair a top-down layout), a shifting highlight, darker roots. Both sides drawn.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 hair_color : source_color = vec3(0.17, 0.11, 0.07);
uniform float strand_scale = 260.0;
uniform float clump_scale = 30.0;
uniform sampler2D strand_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float stripes(float x, float seed) {
	float i = floor(x);
	float f = fract(x);
	float a = hash(i + seed);
	float b = hash(i + 1.0 + seed);
	return mix(a, b, smoothstep(0.0, 1.0, f));
}

void fragment() {
	float fine = stripes(UV.x * strand_scale + sin(UV.y * 40.0) * 0.8, 3.0);
	float clump = stripes(UV.x * clump_scale + sin(UV.y * 9.0) * 0.6, 11.0);
	float v = 0.62 + 0.38 * fine * (0.55 + 0.45 * clump);
	float sheet = texture(strand_tex, vec2(UV.x * 2.0, UV.y * 2.5)).r / max(textureLod(strand_tex, vec2(0.5), 10.0).r, 0.05);
	vec3 c = hair_color * v * 0.75 * mix(1.0, sheet, 0.7);
	if (!FRONT_FACING) {
		c *= 0.5;
	}
	ALBEDO = c;
	ROUGHNESS = 0.62 + 0.15 * (1.0 - fine);
	SPECULAR = 0.25;
	ANISOTROPY = 0.75;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	AO = 0.75 + 0.25 * fine;
}
