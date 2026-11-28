shader_type spatial;
// Lo squarcio nel cielo dietro la bolla: nubi a spirale che si avvitano verso il centro.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float alpha = 0.0;
uniform float spin = 0.0;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		s += vn(p) * a;
		p = p * 2.07 + vec2(11.3, 5.9);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x) + spin * 0.55 + 2.2 / (r + 0.22);
	vec2 s = vec2(cos(a), sin(a)) * (r * 4.2);
	float n = fbm(s + vec2(0.0, spin * 0.35));
	float band = smoothstep(0.42, 0.78, n);
	vec3 col = mix(vec3(0.035, 0.02, 0.11), vec3(0.2, 0.13, 0.5), band);
	col += vec3(0.2, 0.6, 0.9) * pow(band, 3.0) * (1.0 - smoothstep(0.1, 0.8, r));
	col += vec3(0.35, 0.2, 0.7) * pow(max(1.0 - r, 0.0), 3.0);
	float edge = 1.0 - smoothstep(0.35, 1.0, r + (fbm(q * 3.0 + vec2(spin * 0.2)) - 0.5) * 0.35);
	ALBEDO = col;
	ALPHA = edge * (0.45 + 0.5 * band) * alpha;
}
