shader_type canvas_item;
// Passaggio finale: niente retinatura. Contorni scuri, nessun riverbero (bordi netti), tono freddo nelle ombre e caldo nelle luci.
uniform float outline = 0.32;
uniform vec2 px = vec2(480.0, 270.0);
uniform float glitch = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec2 uv = UV;
	vec2 o = 1.0 / px;
	// intrusioni del futuro: bande che slittano e colori che si separano, a scatti
	float tk = floor(TIME * 7.0);
	float band = step(0.95 - glitch * 0.09, fract(sin(floor(uv.y * 48.0) * 12.9898 + tk * 78.233) * 43758.5453));
	uv.x += band * glitch * 0.08 * (fract(sin(tk * 91.7 + floor(uv.y * 48.0)) * 437.58) - 0.5);
	// blocchi larghi che si strappano di lato
	float blk = step(0.92 - glitch * 0.14, fract(sin(floor(uv.y * 11.0) * 41.3 + tk * 17.9) * 9371.7));
	uv.x += blk * glitch * 0.1 * (fract(sin(tk * 5.7 + floor(uv.y * 11.0) * 3.1) * 733.1) - 0.5);
	uv.x += (fract(sin(tk * 33.1) * 4375.8) - 0.5) * 0.012 * glitch;
	vec3 c = texture(TEXTURE, uv).rgb;
	if (glitch > 0.001) {
		// aberrazione cromatica marcata: i tre canali si separano in orizzontale e un po' in verticale
		float ca = glitch * 5.0;
		c.r = texture(TEXTURE, uv + vec2(o.x * ca, -o.y * ca * 0.3)).r;
		c.g = texture(TEXTURE, uv + vec2(0.0, o.y * ca * 0.5)).g;
		c.b = texture(TEXTURE, uv - vec2(o.x * ca * 1.2, 0.0)).b;
		c = mix(c, c * vec3(0.82, 1.04, 1.18), clamp(glitch, 0.0, 1.0) * 0.35);
		c += vec3(0.5, 0.0, 0.6) * band * glitch * 0.35;
		c += glitch * 0.06 * step(0.985, fract(sin(floor(uv.y * 270.0) * 7.77 + tk * 13.1) * 311.7));
	}
	float l = luma(c);
	float e = 0.0;
	e = max(e, abs(l - luma(texture(TEXTURE, uv + vec2(o.x, 0.0)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv - vec2(o.x, 0.0)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv + vec2(0.0, o.y)).rgb)));
	e = max(e, abs(l - luma(texture(TEXTURE, uv - vec2(0.0, o.y)).rgb)));
	c *= 1.0 - smoothstep(0.13, 0.32, e) * outline;
	float ll = luma(c);
	c = mix(vec3(ll), c, 0.85);
	c *= mix(vec3(0.88, 0.94, 1.12), vec3(1.03, 0.99, 0.95), smoothstep(0.08, 0.5, ll));
	vec2 q = uv - 0.5;
	c *= 1.0 - smoothstep(0.28, 0.82, length(q * vec2(1.0, 0.9))) * 0.75;
	c = floor(c * 40.0 + 0.5) / 40.0;
	COLOR = vec4(c, 1.0);
}
