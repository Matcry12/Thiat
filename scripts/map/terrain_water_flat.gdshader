shader_type canvas_item;
// Pixel Plains water (decision 0046): one flat shallow colour, plus light "wave mark" dashes on open water that drift 1 px and swap
// lightness in an 8 frame loop (8 fps). Marks are a function of the art pixel (blocks of `block` px, a hash picks place, length,
// phase), so they exist everywhere, need no baked picture and match the python prototype tools/art_tests/recolour/water.py.
// Numbers from PixelPlainsGround (F3 "Pixel Plains" > Water).

uniform vec4 shallow : source_color = vec4(0.439, 0.824, 0.894, 1.0);
uniform float fps = 8.0;
uniform float block = 32.0;
uniform float chance = 0.85;
uniform float len_min = 3.0;
uniform float len_max = 5.0;
uniform float light_a = 0.133;
uniform float light_b = 0.055;

varying vec2 art_px;   // art pixels from the map's top left corner (the sprite sits at the map origin, its scale is the art scale)

float h1(vec2 p, float s) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + s * 74.7) * 43758.5453);
}

void vertex() {
	art_px = VERTEX;
}

void fragment() {
	vec2 px = floor(art_px);
	vec2 b = floor(px / block);
	vec3 rgb = shallow.rgb;
	if (h1(b, 1.0) < chance) {
		vec2 m = b * block + vec2(2.0 + floor(h1(b, 2.0) * (block - 11.0)), 2.0 + floor(h1(b, 3.0) * (block - 5.0)));
		float ln = len_min + floor(h1(b, 4.0) * (len_max - len_min + 1.0));
		float ph = floor(h1(b, 5.0) * 4.0);
		float s = mod(floor(TIME * fps) + 2.0 * ph, 8.0);
		float shift = (s >= 2.0 && s < 6.0) ? 1.0 : 0.0;
		if (px.y == m.y && px.x >= m.x + shift && px.x < m.x + shift + ln) {
			rgb += (s < 4.0) ? light_a : light_b;
		}
	}
	COLOR = vec4(rgb, 1.0);
}
