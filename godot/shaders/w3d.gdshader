shader_type spatial;
// Mondo 3D low-poly: colori nei vertici, normali piatte, curvatura "pianetino", dissolvenza a bolla e luci finte.
render_mode cull_disabled, world_vertex_coords, specular_disabled, diffuse_lambert;

global uniform vec3 w3d_player;
uniform float curve = 0.017;       // quanto il mondo si piega verso il basso allontanandosi
uniform float fade_a = 54.0;       // inizio della bolla: gli oggetti iniziano a sprofondare
uniform float fade_b = 72.0;       // fine della bolla: spariti
uniform vec4 lamps[16];            // luci finte di torce, finestre e fuochi: xyz posizione, w intensita'

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

void fragment() {
	vec3 fn = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(fn, VIEW) < 0.0) {
		fn = -fn;
	}
	NORMAL = fn;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(fn, 0.0)).xyz);
	vec3 col = vcol.rgb;
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
			add += vec3(0.95, 0.80, 0.58) * a * nl;
		}
	}
	float dist = length(wpos.xz - w3d_player.xz);
	float lum = 1.0 - smoothstep(fade_a * 0.3, fade_b, dist);
	lum = lum * lum;
	ALBEDO = col * lum;
	ROUGHNESS = 1.0;
	EMISSION = col * (vec3(em) + add * 0.62) * lum;
}
