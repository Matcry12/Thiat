shader_type canvas_item;
// Island ground: the baked picture times two one-pixel-per-cell maps (dual grid: the picture is one tile bigger than
// the map).
//  tint_map  (NEAREST): area colour x2 in rgb, saturation in alpha. Crisp, so a tint never smears over an area border.
//  shade_map (LINEAR):  soft light / dark patches, x2 encoded. 0.5 = no change.

uniform sampler2D tint_map : filter_nearest, repeat_disable;
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(16.0);
uniform float half_tile = 8.0;
uniform float ground_brightness = 1.0;   // master: every ground, after the area tint
uniform float ground_saturation = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 cell_uv = clamp((UV * tex_size - vec2(half_tile)) / (tex_size - vec2(2.0 * half_tile)), 0.0, 1.0);
	vec4 t = texture(tint_map, cell_uv);
	float shade = texture(shade_map, cell_uv).r * 2.0;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(lum), c.rgb, t.a) * t.rgb * 2.0 * shade;
	float l2 = dot(rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(l2), rgb, ground_saturation) * ground_brightness, c.a);
}
