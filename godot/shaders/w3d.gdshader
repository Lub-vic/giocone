shader_type spatial;
// Mondo 3D low-poly: colori nei vertici, normali piatte, curvatura "pianetino", dissolvenza a bolla e luci finte.
render_mode cull_disabled, world_vertex_coords, specular_disabled, diffuse_lambert;

global uniform vec3 w3d_player;
uniform float curve = 0.017;       // quanto il mondo si piega verso il basso allontanandosi
uniform float fade_a = 54.0;       // inizio della bolla: gli oggetti iniziano a sprofondare
uniform float fade_b = 72.0;       // fine della bolla: spariti
uniform float gamma_in = 1.0;      // 2.2: converte i colori sRGB dei personaggi in lineare (evita il lavaggio)
uniform float boost = 1.0;         // luminosita' del materiale (personaggi piu' brillanti)
uniform float sat_k = 1.0;         // saturazione del materiale
uniform float patt = 1.0;          // trame calcolate: tegole sui tetti, blocchi sui muri (T per accenderle/spegnerle)
uniform float hero_glow = 1.0;
uniform float floor_min = 0.62;     // luminosita' minima (piu' bassa = piu' contrasto fra luce e buio)     // luminescenza continua attorno all'eroe, sempre presente
uniform vec4 lamps[16];
uniform vec3 lamp_col[16];         // colore di ogni luce; (0,0,0) = calda di default            // luci finte di torce, finestre e fuochi: xyz posizione, w intensita'

varying vec3 wpos;
varying vec4 vcol;

void vertex() {
	wpos = VERTEX;
	vcol = COLOR;
	vec2 d = VERTEX.xz - w3d_player.xz;
	float dist = length(d);
	float f = smoothstep(fade_a, fade_b, dist);
	VERTEX.y -= curve * dist * dist + f * 18.0;
}

float lum_mix(float l) {
	return mix(1.0, l, 0.55);
}

float hsh(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	vec3 col = vcol.rgb;
	{
		float ll = dot(col, vec3(0.3, 0.59, 0.11));
		col = pow(col, vec3(gamma_in));
		ll = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(vec3(ll), col, sat_k) * boost;
	}
	if (patt > 0.5 && vcol.a > 0.99) {
		// la trama e' ancorata al mondo: normale e direzione delle file dalla geometria NON piegata (niente scorrimento)
		vec3 wnw = normalize(cross(dFdx(wpos), dFdy(wpos)));
		float ny = abs(wnw.y);
		vec3 tg = cross(wnw, vec3(0.0, 1.0, 0.0));
		tg = length(tg) > 0.05 ? normalize(tg) : vec3(1.0, 0.0, 0.0);
		float s = dot(wpos, tg);
		bool roof = ny > 0.22 && ny < 0.9;
		bool wall = ny <= 0.22;
		if (roof || wall) {
			float ch = roof ? 0.72 : 0.9;
			float cs = roof ? 1.6 : 2.1;
			float yy = wpos.y / ch;
			float row = floor(yy);
			float fy = fract(yy);
			float su = s / cs + mod(row, 2.0) * 0.5;
			float fx = fract(su);
			float v = hsh(floor(su) + row * 17.0);
			col *= 0.93 + 0.14 * v;
			// giunti morbidi, senza spigoli: solo un velo piu' scuro, in armonia con le facce piatte
			float line = min(min(fy, 1.0 - fy) * 1.6, min(fx, 1.0 - fx) * 0.9);
			col *= 1.0 - (1.0 - smoothstep(0.0, 0.16, line)) * (roof ? 0.28 : 0.22);
		}
	}
	float em = (1.0 - vcol.a) * 2.6;
	vec3 add = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		vec4 L = lamps[i];
		if (L.w > 0.0) {
			vec3 dd = L.xyz - wpos;
			float len = max(length(dd), 0.01);
			float a = L.w * smoothstep(12.0, 1.5, len);
			a *= a;
			float nl = max(dot(wn, dd / len), 0.0) * 0.6 + 0.4;
			vec3 lc = dot(lamp_col[i], vec3(1.0)) > 0.01 ? lamp_col[i] : vec3(0.95, 0.80, 0.58);
			add += lc * a * nl;
		}
	}
	float dist = length(wpos.xz - w3d_player.xz);
	// alone dell'eroe: cuore caldo e pallido che sfuma dolcemente, per pixel (nessun blocco, nessun quadrato)
	float hg = 1.0 - smoothstep(0.0, 21.0, dist);
	hg = hg * (0.45 + 0.55 * hg);
	add += vec3(0.95, 0.86, 0.68) * hero_glow * hg * (0.6 + 0.4 * max(wn.y, 0.0)) * 2.3;
	float lum = 1.0 - smoothstep(fade_a * 0.45, fade_b, dist);
	float floor_l = floor_min + (1.0 - floor_min) * lum;   // il buio non e' mai totale: i colori restano leggibili anche lontano dalle luci
	ALBEDO = col * floor_l * lum_mix(lum);
	ROUGHNESS = 1.0;
	EMISSION = col * (vec3(em) + add * 0.62) * lum + col * 0.045 * (1.0 - smoothstep(fade_a * 0.5, fade_b, dist));
}
