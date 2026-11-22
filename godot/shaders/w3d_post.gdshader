shader_type canvas_item;
// Passaggio finale: niente retinatura. Contorni scuri, riverbero leggero sulle luci, tono freddo nelle ombre e caldo nelle luci.
uniform float outline = 0.32;
uniform vec2 px = vec2(480.0, 270.0);

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec2 uv = UV;
	vec2 o = 1.0 / px;
	vec3 c = texture(TEXTURE, uv).rgb;
	float l = luma(c);
	float e = 0.0;
	e = max(e, abs(l - luma(texture(TEXTURE, uv + vec2(o.x, 0.0)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv - vec2(o.x, 0.0)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv + vec2(0.0, o.y)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv - vec2(0.0, o.y)).rgb)));
	c *= 1.0 - smoothstep(0.13, 0.32, e) * outline;
	// riverbero: la parte piu' luminosa si allarga un poco
	vec3 bl = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec3 s1 = texture(TEXTURE, uv + vec2(cos(a), sin(a)) * o * 2.5).rgb;
		vec3 s2 = texture(TEXTURE, uv + vec2(cos(a), sin(a)) * o * 6.0).rgb;
		bl += max(s1 - 0.5, 0.0) * 0.6 + max(s2 - 0.45, 0.0) * 0.4;
	}
	c += bl * 0.09 * vec3(1.0, 0.9, 0.78);
	float ll = luma(c);
	c = mix(vec3(ll), c, 0.85);
	c *= mix(vec3(0.88, 0.94, 1.12), vec3(1.03, 0.99, 0.95), smoothstep(0.08, 0.5, ll));
	vec2 q = uv - 0.5;
	c *= 1.0 - smoothstep(0.28, 0.82, length(q * vec2(1.0, 0.9))) * 0.75;
	c = floor(c * 40.0 + 0.5) / 40.0;
	COLOR = vec4(c, 1.0);
}
