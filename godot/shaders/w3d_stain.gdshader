shader_type spatial;
// Macchie scure a mescola normale (bruciato, pece): seguono il terreno come tutto il resto.
render_mode blend_mix, unshaded, cull_disabled, depth_draw_never, world_vertex_coords;

global uniform vec3 w3d_player;
global uniform vec3 w3d_curve;       // x = curvatura, y = inizio bolla, z = fine bolla
global uniform sampler2D w3d_elev : filter_linear;
global uniform vec4 w3d_elev_info;

uniform sampler2D tex : source_color, filter_linear;
uniform bool use_tex = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float fade = 1.0;

varying vec4 vc;

float elev(vec2 p) {
	if (w3d_elev_info.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = clamp(p * w3d_elev_info.xy, vec2(0.0), vec2(1.0));
	return textureLod(w3d_elev, uv, 0.0).r * w3d_elev_info.z;
}

void vertex() {
	vc = COLOR;
	VERTEX.y += elev(VERTEX.xz);
	vec2 d = VERTEX.xz - w3d_player.xz;
	float dist = length(d);
	float f = smoothstep(w3d_curve.y, w3d_curve.z, dist);
	VERTEX.y -= w3d_curve.x * dist * dist + f * 18.0;
}

void fragment() {
	vec4 t = use_tex ? texture(tex, UV) : vec4(1.0);
	vec4 c = vc * tint * t;
	ALBEDO = c.rgb;
	ALPHA = c.a * fade;
}
