shader_type spatial;
// Fumo dei camini: macchie morbide e trasparenti che salgono, con la stessa curvatura e bolla di visibilita' del mondo.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

global uniform vec3 w3d_player;
uniform float curve = 0.0;
uniform float fade_a = 54.0;
uniform float fade_b = 72.0;
uniform vec3 tint = vec3(0.30, 0.31, 0.35);

varying vec4 vcol;
varying float vf;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(wp.xz - w3d_player.xz);
	vf = smoothstep(fade_a, fade_b, dist);
	VERTEX.y -= curve * dist * dist + vf * 18.0;
	vcol = COLOR;
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = smoothstep(1.0, 0.2, r);
	ALBEDO = tint * (0.75 + 0.25 * (1.0 - r));
	ALPHA = a * vcol.a * (1.0 - vf);
}
