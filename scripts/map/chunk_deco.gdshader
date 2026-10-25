shader_type canvas_item;
// Many small props in ONE draw: every instance is a unit quad scaled to its picture; INSTANCE_CUSTOM carries the picture's
// rectangle on the sheet (x, y, w, h in texels). One MultiMesh per prop sheet per map chunk (decision 0038, step 2).

uniform vec2 sheet_size = vec2(1.0);
varying vec4 region;
varying vec4 tint;

void vertex() {
	region = INSTANCE_CUSTOM;
	tint = COLOR;   // the node's modulate
}

void fragment() {
	// COLOR already holds the sheet sampled at the quad's own UV (the WHOLE sheet squeezed into the quad): replace it, do not multiply with it
	COLOR = texture(TEXTURE, (region.xy + vec2(UV.x, 1.0 - UV.y) * region.zw) / sheet_size) * tint;
}
