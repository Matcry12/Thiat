shader_type canvas_item;
// Island ground: a baked picture (one per map chunk) times two one-pixel-per-cell maps (dual grid: the picture starts half
// a tile up and left of its first cell). The maps cover the cells [first cell - map_margin, first cell - map_margin + map_cells).
//  tint_map  (LINEAR): area x biome colour x2 in rgb, saturation x2 in alpha (0..2). Soft: a biome change is a gradient over one cell, not a square block.
//  shade_map (LINEAR):  soft light / dark patches, x2 encoded. 0.5 = no change.

uniform sampler2D tint_map : filter_linear, repeat_disable;
uniform sampler2D shade_map : filter_linear, repeat_disable;
uniform vec2 tex_size = vec2(16.0);
uniform float half_tile = 8.0;
uniform float tile = 16.0;                       // art pixels per cell
uniform vec2 map_cells = vec2(1.0);              // size of tint_map / shade_map in cells
uniform vec2 map_margin = vec2(0.0);             // how many cells before the picture's first cell the maps start
uniform float ground_brightness = 1.0;   // master: every ground, after the area tint
uniform float ground_saturation = 1.0;
uniform bool neutral = false;                    // Pixel Plains: the pack's pixels unchanged, no tint / shade / brightness / saturation

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (neutral) {
		COLOR = c;
	} else {
	vec2 cell_uv = clamp(((UV * tex_size - vec2(half_tile)) / tile + map_margin) / map_cells, 0.0, 1.0);
	vec4 t = texture(tint_map, cell_uv);
	float shade = texture(shade_map, cell_uv).r * 2.0;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(lum), c.rgb, t.a * 2.0) * t.rgb * 2.0 * shade;
	float l2 = dot(rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(vec3(l2), rgb, ground_saturation) * ground_brightness, c.a);
	}
}
