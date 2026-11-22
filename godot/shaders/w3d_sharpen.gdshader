shader_type canvas_item;
// Filtro di nitidezza (unsharp mask) su tutto lo schermo, interfaccia compresa.
uniform sampler2D scr : hint_screen_texture, filter_nearest, repeat_disable;
uniform float amount = 1.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(scr, SCREEN_UV).rgb;
	vec3 b = texture(scr, SCREEN_UV + vec2(px.x, 0.0)).rgb + texture(scr, SCREEN_UV - vec2(px.x, 0.0)).rgb
		+ texture(scr, SCREEN_UV + vec2(0.0, px.y)).rgb + texture(scr, SCREEN_UV - vec2(0.0, px.y)).rgb;
	b *= 0.25;
	COLOR = vec4(clamp(c + (c - b) * amount, 0.0, 1.0), 1.0);
}
