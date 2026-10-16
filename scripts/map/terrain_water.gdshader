shader_type canvas_item;
// Island water: the pack's water tiles plus slow, pixel-sized glints and a very gentle light drift.
// Everything runs in art pixels (UV / TEXTURE_PIXEL_SIZE), so the glints are as chunky as the tiles.
// Numbers come from ArenaMap (F3 Map section): shimmer_*, wave_*.

uniform float shimmer_speed = 0.35;
uniform float shimmer_strength = 0.18;
uniform float shimmer_scale = 0.09;
uniform float shimmer_amount = 0.3;
uniform float wave_strength = 0.05;
uniform float drift_scale = 0.03;
uniform float drift_speed = 0.05;
uniform vec4 shimmer_color : source_color = vec4(0.85, 0.95, 1.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 px = floor(UV / TEXTURE_PIXEL_SIZE);
	float a = vnoise(px * shimmer_scale + vec2(TIME * shimmer_speed, TIME * shimmer_speed * 0.6));
	float b = vnoise(px * shimmer_scale * 2.3 + vec2(-TIME * shimmer_speed * 0.7, 3.7));
	// a glint = where both noises are high at once; `shimmer_amount` is the share of water that can glint
	float glint = smoothstep(1.0 - shimmer_amount, 1.0 - shimmer_amount * 0.55, a * 0.55 + b * 0.45);
	float drift = (vnoise(px * drift_scale + vec2(TIME * drift_speed, 0.0)) - 0.5) * 2.0;
	base.rgb *= 1.0 + wave_strength * drift;
	base.rgb = mix(base.rgb, shimmer_color.rgb, glint * shimmer_strength);
	COLOR = base;
}
