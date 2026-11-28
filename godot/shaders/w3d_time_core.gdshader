shader_type spatial;
// Interno della bolla: un velo scuro color notte che stacca la sfera dal cielo e rende spettrale cio' che contiene.
render_mode blend_mix, unshaded, cull_front, depth_draw_never, fog_disabled;

uniform float alpha = 1.0;

void fragment() {
	float nv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = mix(vec3(0.05, 0.02, 0.16), vec3(0.01, 0.015, 0.06), nv);
	ALPHA = (0.35 + 0.4 * nv) * alpha;
}
