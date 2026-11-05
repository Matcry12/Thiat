shader_type canvas_item;
// "Soft edges" for turned pixel art: every art pixel stays a solid square, only its border is blended
// over ~edge_width SCREEN pixels. Reads the 4 nearest texels itself (texelFetch, so the sprite filter does not matter)
// and mixes them premultiplied, so a transparent pixel with any colour never leaves a dark/light fringe.
uniform float edge_width = 1.0;      // screen pixels of blend at each art-pixel border; set by WeaponVisual from BodyRig.soft_edge_width
uniform vec4 tint : source_color = vec4(1.0);   // ghosts: silhouette colour
uniform float amount = 0.0;                      // ghosts: 1 = pure tint, 0 = real colours

varying vec4 node_modulate;

void vertex() {
	node_modulate = COLOR;   // the node's modulate
}

vec4 texel(sampler2D t, ivec2 i, ivec2 sz) {
	vec4 c = texelFetch(t, clamp(i, ivec2(0), sz - ivec2(1)), 0);
	if (i.x < 0 || i.y < 0 || i.x >= sz.x || i.y >= sz.y) c = vec4(0.0);
	return vec4(c.rgb * c.a, c.a);
}

void fragment() {
	ivec2 sz = textureSize(TEXTURE, 0);
	vec2 p = UV * vec2(sz);
	vec2 seam = floor(p + 0.5);
	p = seam + clamp((p - seam) / max(fwidth(p), vec2(0.0001)) / max(edge_width, 0.01), -0.5, 0.5);
	vec2 q = p - 0.5;
	ivec2 i = ivec2(floor(q));
	vec2 f = q - floor(q);
	vec4 c = mix(mix(texel(TEXTURE, i, sz), texel(TEXTURE, i + ivec2(1, 0), sz), f.x),
		mix(texel(TEXTURE, i + ivec2(0, 1), sz), texel(TEXTURE, i + ivec2(1, 1), sz), f.x), f.y);
	vec3 rgb = c.a > 0.0001 ? c.rgb / c.a : vec3(0.0);
	// COLOR already holds the sprite's own nearest sample: replace it, do not multiply with it. Ghosts (amount 1) stay the pure tint.
	COLOR = vec4(mix(rgb * node_modulate.rgb, tint.rgb, amount), c.a * node_modulate.a);
}
