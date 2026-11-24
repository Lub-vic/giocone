shader_type spatial;
// Suolo del mondo aperto, disegnato per pixel: grana di terra, ciuffi d'erba, sassolini con contorno e sentieri dal bordo netto e curvo
// (la distanza dal sentiero viene da una mappa globale; il bordo e' irregolare ma sempre definito, mai sfumato).
render_mode cull_disabled, world_vertex_coords, specular_disabled, diffuse_lambert;

global uniform vec3 w3d_player;
global uniform sampler2D w3d_elev : filter_linear;
global uniform vec4 w3d_elev_info;

uniform float curve = 0.017;
uniform float fade_a = 54.0;
uniform float fade_b = 72.0;
uniform float boost = 1.0;
uniform float sat_k = 1.0;
uniform float hero_glow = 1.0;
uniform float floor_min = 0.62;
uniform vec4 lamps[16];
uniform vec3 lamp_col[16];
uniform sampler2D gmap : filter_linear, repeat_disable;   // R = distanza con segno dal bordo del sentiero (0.5 = bordo, scala 8 unita')
uniform vec2 gmap_inv = vec2(0.0005, 0.0007);              // 1 / dimensioni della mappa (celle)

varying vec3 wpos;
varying vec4 vcol;

float elev(vec2 p) {
	if (w3d_elev_info.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = clamp(p * w3d_elev_info.xy, vec2(0.0), vec2(1.0));
	return textureLod(w3d_elev, uv, 0.0).r * w3d_elev_info.z;
}

void vertex() {
	VERTEX.y += elev(VERTEX.xz);
	wpos = VERTEX;
	vcol = COLOR;
	vec2 d = VERTEX.xz - w3d_player.xz;
	float dist = length(d);
	float f = smoothstep(fade_a, fade_b, dist);
	VERTEX.y -= curve * dist * dist + f * 18.0;
}

float hsh(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hsh(i), hsh(i + vec2(1.0, 0.0)), f.x), mix(hsh(i + vec2(0.0, 1.0)), hsh(i + vec2(1.0, 1.0)), f.x), f.y);
}

// sassolino: ritorna x = copertura (1 dentro), y = contorno scuro (1 nel bordo)
vec2 pebble(vec2 w, float cell, float density, float rmin, float rmax, float seed) {
	vec2 c = floor(w / cell);
	vec2 f = fract(w / cell);
	float h = hsh(c + seed);
	if (h > density) {
		return vec2(0.0);
	}
	vec2 ctr = vec2(0.28 + 0.44 * hsh(c + seed + 4.4), 0.28 + 0.44 * hsh(c + seed + 5.5));
	float r = (rmin + (rmax - rmin) * hsh(c + seed + 6.6)) / cell;
	vec2 q = (f - ctr) * vec2(1.0, 1.0 + 0.5 * hsh(c + seed + 7.7));
	float dd = length(q);
	float aa = 1.6 / (cell * 27.0);
	return vec2(1.0 - smoothstep(r - aa, r + aa, dd), smoothstep(r - aa, r + aa, dd) * (1.0 - smoothstep(r + 0.03 / cell, r + 0.03 / cell + aa, dd)) * 0.6);
}

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	vec2 w = wpos.xz;
	vec3 col = vcol.rgb;

	// --- terra: grana a tre toni (pixel piccoli ma definiti)
	float gr = hsh(floor(w / 0.15));
	col *= gr < 0.2 ? 0.88 : (gr > 0.88 ? 1.13 : 1.0);
	// --- erba: ciuffi a trattini dove il suolo e' verdastro
	float green = clamp((col.g - max(col.r, col.b)) * 22.0, 0.0, 1.0);
	{
		vec2 bc = floor(w / 0.3);
		vec2 bf = fract(w / 0.3);
		float bh = hsh(bc + 7.3);
		if (bh < 0.35 + 0.4 * green) {
			vec2 c = vec2(0.3 + 0.4 * hsh(bc + 1.1), 0.3 + 0.4 * hsh(bc + 2.2));
			float ang = 1.57 + (hsh(bc + 3.3) - 0.5) * 1.3;
			vec2 dir = vec2(cos(ang), sin(ang));
			vec2 dv = (bf - c) * 0.3;
			float along = dot(dv, dir);
			float across = abs(dot(dv, vec2(-dir.y, dir.x)));
			if (abs(along) < 0.075 && across < 0.016) {
				col = mix(col * 0.55, col * (1.35 + 0.5 * green), step(0.0, along));
			}
		}
	}
	// --- sassolini sparsi, con contorno scuro
	vec2 pb = pebble(w, 0.55, 0.16, 0.05, 0.1, 9.1);
	col = mix(col, col * 0.4, pb.y);
	col = mix(col, vec3(0.2, 0.19, 0.2) * (0.9 + 0.3 * hsh(floor(w * 3.0))), pb.x * 0.7);

	// --- sentiero: bordo netto e irregolare, orlo scuro, terra battuta con pietre incastonate
	float sd = (texture(gmap, w * gmap_inv).r - 0.5) * 8.0;
	sd += (vnoise(w * 4.5) - 0.5) * 0.26 + (vnoise(w * 12.0) - 0.5) * 0.09;
	float aa = max(fwidth(sd), 0.11);
	float inside = 1.0 - smoothstep(-aa, aa, sd);
	float rim = (1.0 - smoothstep(-aa, aa * 2.0, sd - 0.14)) - inside;
	if (inside > 0.001) {
		float pg = hsh(floor(w / 0.11));
		vec3 pc = vec3(0.19, 0.165, 0.142) * (pg < 0.25 ? 0.82 : (pg > 0.85 ? 1.18 : 1.0));
		vec2 st = pebble(w + 3.7, 0.5, 0.5, 0.07, 0.15, 21.0);
		pc = mix(pc, pc * 0.45, st.y);
		pc = mix(pc, vec3(0.24, 0.225, 0.23) * (0.85 + 0.3 * hsh(floor(w * 2.5))), st.x * 0.75);
		col = mix(col, pc, inside);
	}
	col *= 1.0 - rim * 0.4;

	{
		float ll = dot(col, vec3(0.3, 0.59, 0.11));
		col = mix(vec3(ll), col, sat_k) * boost;
	}
	vec3 add = vec3(0.0);
	for (int i = 0; i < 16; i++) {
		vec4 L = lamps[i];
		if (L.w > 0.0) {
			vec3 dd = L.xyz - wpos;
			float len = max(length(dd), 0.01);
			float a = L.w * smoothstep(12.0, 1.5, len);
			a *= a;
			float nl = max(dot(wn, dd / len), 0.0) * 0.6 + 0.4;
			vec3 lc = dot(lamp_col[i], vec3(1.0)) > 0.01 ? lamp_col[i] : vec3(0.90, 0.76, 0.64);
			add += lc * a * nl;
		}
	}
	float dist = length(wpos.xz - w3d_player.xz);
	float hg = 1.0 - smoothstep(0.0, 21.0, dist);
	hg = hg * (0.45 + 0.55 * hg);
	add += vec3(0.90, 0.83, 0.74) * hero_glow * hg * (0.6 + 0.4 * max(wn.y, 0.0)) * 2.3;
	float lum = 1.0 - smoothstep(fade_a * 0.45, fade_b, dist);
	float floor_l = floor_min + (1.0 - floor_min) * lum;
	ALBEDO = col * floor_l * mix(1.0, lum, 0.55);
	ROUGHNESS = 1.0;
	EMISSION = col * add * 0.62 * lum + col * 0.045 * (1.0 - smoothstep(fade_a * 0.5, fade_b, dist));
}
