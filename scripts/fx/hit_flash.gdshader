shader_type canvas_item;
// Tints everything it is drawn on toward flash_color. amount 0 = untouched, 1 = solid colour (alpha kept).
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, flash_color.rgb, amount);
}
