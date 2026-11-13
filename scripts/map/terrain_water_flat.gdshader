shader_type canvas_item;
// Pixel Plains water (docs/wiki/ground-tileset-algorithm.md): every pixel comes from water.png. Cell (0,0) is flat water (all 16 x 16 px, tiled); below it each row
// is one wave mark variant, 8 frames of 32 x 32. Per 32 px block (aligned to the tile grid) a hash picks: mark or not (`chance`),
// the variant and a phase. Add a row to the picture = one more variant. Nothing about the marks is in this file but the choosing.

uniform sampler2D water_pic : filter_nearest, repeat_disable;
uniform float fps = 8.0;
uniform float chance = 0.85;

const int BLOCK = 32;   // size of a mark picture and of the block that picks it
const int TOP = 16;     // height of the flat water strip on top of water.png (its first cell is TILE x TILE)
const int TILE = 16;

varying vec2 art_px;   // art pixels from the map's top left corner (the sprite sits at the map origin, its scale is the art scale)

uint hash2(ivec2 b) {
	uint h = uint(b.x) * 73856093u ^ uint(b.y) * 19349663u;
	h ^= h >> 13u;
	h *= 1274126177u;
	h ^= h >> 16u;
	return h;
}

void vertex() {
	art_px = VERTEX;
}

void fragment() {
	ivec2 px = ivec2(floor(art_px));
	ivec2 b = ivec2(floor(vec2(px) / float(BLOCK)));
	ivec2 cell = ((px % TILE) + ivec2(TILE)) % ivec2(TILE);   // the whole flat 16 x 16 cell, tiled like the shore water
	vec4 c = texelFetch(water_pic, cell, 0);
	int variants = (textureSize(water_pic, 0).y - TOP) / BLOCK;
	uint h = hash2(b);
	if (variants > 0 && int(h % 1000u) < int(chance * 1000.0)) {
		int v = int((h >> 10u) % uint(variants));
		int phase = int((h >> 20u) & 3u);
		int f = (int(floor(TIME * fps)) + 2 * phase) % 8;
		ivec2 l = px - b * BLOCK;
		c = texelFetch(water_pic, ivec2(f * BLOCK + l.x, TOP + v * BLOCK + l.y), 0);
	}
	COLOR = vec4(c.rgb, 1.0);
}
