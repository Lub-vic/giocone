shader_type canvas_item;
// Passaggio finale: niente retinatura. Contorni scuri, nessun riverbero (bordi netti), tono freddo nelle ombre e caldo nelle luci.
uniform float outline = 0.32;
uniform vec2 px = vec2(480.0, 270.0);
uniform float glitch = 0.0;
uniform float fisheye = 0.0;
// cutscene dell'ufo: lente della bolla temporale, onda d'urto, cielo in tempesta, lampi e tempo fermo
uniform vec2 warp_c = vec2(0.5);
uniform float warp_r = 0.0;
uniform float warp_k = 0.0;
uniform float wave_r = 0.0;
uniform float wave_k = 0.0;
uniform float storm = 0.0;
uniform float lit = 0.0;
uniform float mono = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.3, 0.59, 0.11));
}

void fragment() {
	vec2 uv = UV;
	vec2 fish_q = uv - 0.5;
	uv = 0.5 + fish_q * (1.0 + fisheye * dot(fish_q, fish_q) * 2.0);
	vec2 o = 1.0 / px;
	float split = 0.0;
	if (warp_k > 0.001 && warp_r > 0.001) {
		// la bolla piega lo spazio: l'immagine si torce e si gonfia lungo il bordo
		vec2 dv = (uv - warp_c) * vec2(px.x / px.y, 1.0);
		float len = max(length(dv), 0.0001);
		float rim = exp(-pow((len - warp_r * 1.04) / (warp_r * 0.2 + 0.012), 2.0));
		float tw = rim * 0.09 * warp_k * sin(TIME * 3.0 + len * 24.0);
		vec2 nv = vec2(dv.x * cos(tw) - dv.y * sin(tw), dv.x * sin(tw) + dv.y * cos(tw));
		nv -= dv / len * rim * min(warp_r, 0.35) * 0.11 * warp_k;
		uv = warp_c + nv / vec2(px.x / px.y, 1.0);
		split += rim * warp_k * 2.6;
	}
	if (wave_k > 0.001) {
		vec2 dw = (uv - warp_c) * vec2(px.x / px.y, 1.0);
		float lw = max(length(dw), 0.0001);
		float ring = exp(-pow((lw - wave_r) / 0.07, 2.0));
		uv -= dw / lw * ring * 0.045 * wave_k / vec2(px.x / px.y, 1.0);
		split += ring * wave_k * 4.0;
	}
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
	if (split > 0.05) {
		vec2 sd = normalize(uv - warp_c + vec2(0.0001)) * o * split;
		c.r = texture(TEXTURE, uv + sd).r;
		c.b = texture(TEXTURE, uv - sd).b;
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
	if (storm > 0.001) {
		// la luce se ne va: ombre blu violette, le fonti di energia restano accese
		float sl = luma(c);
		vec3 night = c * vec3(0.62, 0.68, 1.08);
		c = mix(c, mix(night, c, smoothstep(0.35, 0.85, sl)), storm);
	}
	if (lit > 0.001) {
		c = c * (1.0 + lit * 1.3 * vec3(0.7, 0.9, 1.2)) + vec3(0.02, 0.035, 0.06) * lit;
	}
	if (mono > 0.001) {
		float ml = luma(c);
		c = mix(c, clamp((vec3(ml) - 0.18) * 1.5 + 0.18, 0.0, 1.0) * vec3(0.85, 0.95, 1.15), mono);
	}
	c = floor(c * 40.0 + 0.5) / 40.0;
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	c *= inside.x * inside.y;
	COLOR = vec4(c, 1.0);
}
