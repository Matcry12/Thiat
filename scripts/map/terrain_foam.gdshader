shader_type canvas_item;
// Shore foam: a baked 1-2 px mask along the coast, tinted and pulsed. The pulse runs in waves along the shore
// (a phase from the position), so the whole line never blinks at once. Numbers from ArenaMap (F3 Map).

uniform vec4 foam_color : source_color = vec4(0.96, 0.99, 1.0, 1.0);
uniform float foam_alpha = 0.85;
uniform float foam_pulse = 0.45;
uniform float foam_speed = 0.8;

void fragment() {
	float m = texture(TEXTURE, UV).r;
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float phase = (px.x + px.y) * 0.035 + sin(px.x * 0.021) * 2.0;
	float wave = 0.5 + 0.5 * sin(TIME * foam_speed + phase);
	COLOR = vec4(foam_color.rgb, m * foam_alpha * (1.0 - foam_pulse + foam_pulse * wave));
}
