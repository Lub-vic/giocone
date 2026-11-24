shader_type spatial;
// Contorno colorato per i personaggi: guscio rovesciato appena piu' grande, disegnato solo sul retro (nessuna luce).
render_mode unshaded, cull_disabled, world_vertex_coords;

global uniform vec3 w3d_player;
global uniform sampler2D w3d_elev : filter_linear;
global uniform vec4 w3d_elev_info;   // xy = 1 / dimensioni della mappa (celle), z = scala delle quote (0 = spente: interni)

float elev(vec2 p) {
	if (w3d_elev_info.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = clamp(p * w3d_elev_info.xy, vec2(0.0), vec2(1.0));
	return textureLod(w3d_elev, uv, 0.0).r * w3d_elev_info.z;
}
uniform float curve = 0.014;
uniform float fade_a = 48.0;
uniform float fade_b = 66.0;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.15, 1.0);
uniform float grow = 0.09;

void vertex() {
	vec3 c = MODEL_MATRIX[3].xyz;
	vec3 off = VERTEX - c;
	// il guscio sta SOTTO il personaggio (y piu' basso) e un po' piu' largo: dall'alto si vede solo il bordo
	VERTEX = c + vec3(off.x * (1.0 + grow), off.y * (1.0 + grow * 0.3) - 0.45, off.z * (1.0 + grow));
	VERTEX.y += elev(VERTEX.xz);
	vec2 d = VERTEX.xz - w3d_player.xz;
	float dist = length(d);
	float f = smoothstep(fade_a, fade_b, dist);
	VERTEX.y -= curve * dist * dist + f * 18.0;
}

void fragment() {
	float dist = length(NODE_POSITION_WORLD.xz - w3d_player.xz);
	float lum = 1.0 - smoothstep(fade_a * 0.45, fade_b, dist);
	ALBEDO = color.rgb * (0.35 + 0.65 * lum) * 0.8;
}
