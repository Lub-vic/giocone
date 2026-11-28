shader_type spatial;
// La bolla temporale: bordo luminoso (fresnel), venature di energia che scorrono e increspature concentriche.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, fog_disabled;

uniform float alpha = 1.0;
uniform float power = 1.0;
uniform float tm = 0.0;

varying vec3 lp;

float h3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float vn(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1, 0, 0)), f.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), f.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lp = VERTEX;
	float w = vn(VERTEX * 3.1 + vec3(0.0, tm * 2.3, tm * 1.1)) - 0.5;
	VERTEX += NORMAL * w * 0.07 * power;
}

void fragment() {
	float nv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float rim = pow(1.0 - nv, 2.6);
	float ang = tm * 0.9 + lp.y * 2.4;
	vec3 q = vec3(lp.x * cos(ang) - lp.z * sin(ang), lp.y, lp.x * sin(ang) + lp.z * cos(ang));
	float n1 = vn(q * 3.4 + vec3(0.0, -tm * 1.7, 0.0));
	float n2 = vn(q * 7.3 + vec3(tm * 2.1, 0.0, tm));
	float vein = pow(1.0 - abs(n1 + n2 * 0.5 - 0.75) * 1.7, 12.0);
	vein = clamp(vein, 0.0, 1.0);
	float ripple = pow(0.5 + 0.5 * sin(acos(clamp(lp.y, -1.0, 1.0)) * 26.0 - tm * 14.0), 16.0);
	vec3 deep = vec3(0.34, 0.16, 0.85);
	vec3 cyan = vec3(0.24, 0.74, 1.0);
	vec3 col = mix(deep, cyan, rim) * rim * 1.35;
	col += mix(cyan, vec3(0.9, 0.97, 1.0), vein) * vein * (0.2 + rim * 0.75) * power;
	col += cyan * ripple * (0.05 + rim * 0.35);
	col += vec3(0.85, 0.95, 1.0) * pow(1.0 - nv, 9.0) * 0.9;
	ALBEDO = col;
	ALPHA = alpha;
}
