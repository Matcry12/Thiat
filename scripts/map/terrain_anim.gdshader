shader_type canvas_item;
// Pixel Plains animated foam (docs/wiki/ground-tileset-algorithm.md). The texture is the baked animation mask (PixelPlainsBaker "anim"):
// R = 1 marks a foam pixel, G / B = x / y of that pixel in frame 0 of foam.png. The colour is read from foam.png at x + frame * 64
// (8 frames of 4 x 4 slots of 16 px): a pixel there = lit, no pixel = the sand below shows. No numbers here: redraw foam.png.

uniform sampler2D foam_pic : filter_nearest, repeat_disable;
uniform float fps = 8.0;

const int FRAME_W = 64;   // 4 slots of 16 px: the layout of foam.png

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	COLOR = vec4(0.0);
	if (int(round(m.r * 255.0)) == 1) {
		int f = int(floor(TIME * fps)) % 8;
		ivec2 g = ivec2(int(round(m.g * 255.0)), int(round(m.b * 255.0)));
		vec4 c = texelFetch(foam_pic, ivec2(g.x + f * FRAME_W, g.y), 0);
		if (c.a > 0.0) {
			COLOR = vec4(c.rgb, 1.0);
		}
	}
}
