shader_type canvas_item;
// Swimming: everything of the body below the waterline (world y) is tinted water-blue and see-through. Runs on the Body sprite itself,
// so the body keeps its place in the y-sort (trees and the boss in front still hide it). Set by WaterFx.
uniform float waterline = 1.0e9;
uniform vec4 water_color : source_color = vec4(0.30, 0.62, 0.85, 0.55);
varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	if (world_y > waterline) {
		c.rgb = mix(c.rgb, water_color.rgb, water_color.a);
		c.a *= 1.0 - 0.35 * water_color.a;
	}
	COLOR = c;
}
