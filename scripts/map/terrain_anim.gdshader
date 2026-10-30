shader_type canvas_item;
// Pixel Plains animated foam (decision 0046). The texture is the baked animation mask (PixelPlainsBaker "foam"): R = kind,
// G = j * 8 + length, B = phase. Kind 1 = beach foam: 6 of every 8 pixels along x + y are lit, the lit part moves 1 px per frame.
// Kind 3 = shore water: flat water colour (hides the open-water marks near land). Kind 2 = foam dash (flat water when not lit): shifts / shortens on a 4 step cycle. 8 frames at `fps`. Mirrors PixelPlainsBaker.beach_lit / dash_lit.

uniform vec4 foam_colour : source_color = vec4(0.855, 0.965, 0.988, 1.0);
uniform vec4 shallow : source_color = vec4(0.439, 0.824, 0.894, 1.0);
uniform float fps = 8.0;
uniform float beach_lit = 6.0;

void fragment() {
	vec4 m = texture(TEXTURE, UV);
	int kind = int(round(m.r * 255.0));
	int f = int(floor(TIME * fps)) % 8;
	bool lit = false;
	if (kind == 1) {
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE));
		int a = (p.x + p.y - f) % 8;
		if (a < 0) {
			a += 8;
		}
		lit = float(a) < beach_lit;
	} else if (kind == 2) {
		int g = int(round(m.g * 255.0));
		int j = g / 8;
		int ln = g % 8;
		int q = ((f + 1) / 2 + int(round(m.b * 255.0))) % 4;
		int sft = (q == 1 || q == 2) ? 1 : 0;
		int cut = (q == 2 || q == 3) ? 1 : 0;
		lit = j >= sft && j - sft < ln - cut;
	}
	if (lit) {
		COLOR = vec4(foam_colour.rgb, 1.0);
	} else if (kind >= 2) {
		COLOR = vec4(shallow.rgb, 1.0);
	} else {
		COLOR = vec4(0.0);
	}
}
