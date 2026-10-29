class_name PixelArt
extends RefCounted
## The ONE owner of pixel-art plumbing for every screen (game UI and F3 dock): nearest upscale with one cache, 9-slice
## builders that read the slice / content margins from a bake's slices.json, pixel-font labels and the few draw helpers.
## Parts are baked at art scale 1 (assets/ui/game/README.md); here they are enlarged ONCE by a whole number so every
## part lands on whole screen pixels. Holds no state but caches. Every entry point accepts a null texture and then draws nothing.

const GAME := "res://assets/ui/game/"
const F3 := "res://assets/ui/f3/"

static var _up_cache := {}     ## "instance_id:scale" -> ImageTexture
static var _parts_cache := {}  ## dir -> {part: {...}} from <dir>slices.json
static var _grey: ShaderMaterial

# ------------------------------------------------------------------ slices.json

static func parts(dir := GAME) -> Dictionary:
	if not _parts_cache.has(dir):
		_parts_cache[dir] = JSON.parse_string(FileAccess.get_file_as_string(dir + "slices.json"))["parts"]
	return _parts_cache[dir]

static func _sides(d: Dictionary) -> Vector4i:
	return Vector4i(d.get("left", 0), d.get("top", 0), d.get("right", 0), d.get("bottom", 0))

## 9-slice margins of a part in art px (left, top, right, bottom); zero when the part has none.
static func slice(part: String, dir := GAME) -> Vector4i:
	return _sides(parts(dir).get(part, {}).get("slice", {}))

## Content margins of a part in art px.
static func content(part: String, dir := GAME) -> Vector4i:
	return _sides(parts(dir).get(part, {}).get("content", {}))

# ------------------------------------------------------------------ pictures

## True when the skin carries the baked parts (slot_idle_tex...) and no legacy slot_texture overrides them.
static func art_mode(sk: InventorySkin) -> bool:
	return sk != null and sk.slot_idle_tex != null and sk.slot_texture == null

## `tex` enlarged `s` times with nearest sampling (cached). s <= 1 or null returns the texture itself.
static func up(tex: Texture2D, s: int) -> Texture2D:
	if tex == null or s <= 1:
		return tex
	var k := "%d:%d" % [tex.get_instance_id(), s]
	if _up_cache.has(k):
		return _up_cache[k]
	var img := tex.get_image()
	img.resize(img.get_width() * s, img.get_height() * s, Image.INTERPOLATE_NEAREST)
	var t := ImageTexture.create_from_image(img)
	_up_cache[k] = t
	return t

## A picture at its real size x s (an organic panel: never stretched).
static func pic(tex: Texture2D, s: int, art_pos := Vector2.ZERO) -> TextureRect:
	var r := TextureRect.new()
	r.texture = up(tex, s)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.stretch_mode = TextureRect.STRETCH_KEEP
	r.position = art_pos * s
	if r.texture != null:
		r.size = r.texture.get_size()
	return r

## A texture rect already holding `up(tex, s)` and sized to it (zero size when null).
static func set_pic(r: TextureRect, tex: Texture2D, s: int) -> void:
	r.texture = up(tex, s)
	r.size = r.texture.get_size() if r.texture else Vector2.ZERO

## 9-slice margins of `part` (art px) onto a NinePatchRect.
static func set_nine(r: NinePatchRect, tex: Texture2D, part: String, s: int, dir := GAME) -> void:
	var p := slice(part, dir)
	r.texture = up(tex, s)
	r.patch_margin_left = p.x * s
	r.patch_margin_top = p.y * s
	r.patch_margin_right = p.z * s
	r.patch_margin_bottom = p.w * s

static func nine(tex: Texture2D, part: String, s: int, dir := GAME) -> NinePatchRect:
	var r := NinePatchRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_nine(r, tex, part, s, dir)
	return r

## A 9-slice StyleBoxTexture: slice from slices.json, content margins from slices.json unless `content_art` (Vector4i art px) is given.
static func box(tex: Texture2D, part: String, s: int, dir := GAME, content_art = null) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = up(tex, s)
	var p := slice(part, dir)
	b.texture_margin_left = p.x * s
	b.texture_margin_top = p.y * s
	b.texture_margin_right = p.z * s
	b.texture_margin_bottom = p.w * s
	var c: Vector4i = content_art if content_art is Vector4i else content(part, dir)
	b.content_margin_left = c.x * s
	b.content_margin_top = c.y * s
	b.content_margin_right = c.z * s
	b.content_margin_bottom = c.w * s
	return b

## Four button states from `states` {"normal": [tex, part], ...} onto `b` (null texture = that state draws nothing).
static func style_button(b: Button, states: Dictionary, s: int, content_art = null) -> void:
	for k in states:
		b.add_theme_stylebox_override(k, box(states[k][0], states[k][1], s, GAME, content_art))

## Grey-out shader for "you cannot craft this" icons.
static func grey_material() -> ShaderMaterial:
	if _grey == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float amount : hint_range(0.0, 1.0) = 1.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(mix(c.rgb, vec3(g), amount), c.a);\n}\n"
		_grey = ShaderMaterial.new()
		_grey.shader = sh
	return _grey

# ------------------------------------------------------------------ text

## Pixel-font size for `kind` at the skin's art scale (x `mult`): always a whole multiple of the native size.
static func font_px(sk: InventorySkin, kind: String, mult := 1) -> int:
	return UiFonts.NATIVE[kind] * sk.art_scale * mult

## Text in a baked pixel font. `outline` = the ring in the skin's text_outline_color (`out_col` overrides). clean = the readable
## default font instead (long, dense text). `mult` scales the size by a whole number (headers).
static func style_label(l: Label, sk: InventorySkin, kind: String, col: Color, outline := true, clean := false, out_col := Color(0, 0, 0, 0), mult := 1) -> void:
	if clean:
		l.add_theme_font_override("font", sk.font if sk.font != null else ThemeDB.fallback_font)
		l.add_theme_font_size_override("font_size", font_px(sk, kind, mult) - 2)
	else:
		l.add_theme_font_override("font", sk.ui_font(kind))
		l.add_theme_font_size_override("font_size", font_px(sk, kind, mult))
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", sk.text_outline_size if outline else 0)
	l.add_theme_color_override("font_outline_color", out_col if out_col.a > 0.0 else sk.text_outline_color)
	l.add_theme_constant_override("line_spacing", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE

static func label(text: String, sk: InventorySkin, kind: String, col: Color, outline := true, clean := false, out_col := Color(0, 0, 0, 0), mult := 1) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, sk, kind, col, outline, clean, out_col, mult)
	return l

## Width of `text` in the pixel font `kind` at the skin's art scale.
static func text_w(text: String, sk: InventorySkin, kind: String) -> float:
	return sk.ui_font(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px(sk, kind)).x

## `text` cut with ".." so it fits `max_w` screen px in the pixel font `kind` (a long name never leaves its box).
static func fit_text(text: String, sk: InventorySkin, kind: String, max_w: float) -> String:
	if text_w(text, sk, kind) <= max_w:
		return text
	var t := text
	while t.length() > 1 and text_w(t + "..", sk, kind) > max_w:
		t = t.substr(0, t.length() - 1)
	return t + ".."

# ------------------------------------------------------------------ drawing (call from a _draw())

## `tex` at its real size x s with its top-left at `pos` (screen px). Draws the cached whole-number copy, so it is crisp
## whatever the control's texture filter is.
static func draw_pic(ci: CanvasItem, tex: Texture2D, pos: Vector2, s: int, mod := Color.WHITE) -> void:
	var t := up(tex, s)
	if t != null:
		ci.draw_texture(t, pos, mod)

## A bar fill / plate: left cap + stretched middle + right cap, caps `cap` art px wide. `r` = screen rect. Short rects crop.
static func draw_h3(ci: CanvasItem, tex: Texture2D, r: Rect2, cap: int, s: int, mod := Color.WHITE) -> void:
	if tex == null or r.size.x <= 0.0:
		return
	var ts := tex.get_size()
	var c := float(cap * s)
	if r.size.x <= c * 2.0:
		ci.draw_texture_rect_region(tex, r, Rect2(0, 0, r.size.x / s, ts.y), mod)
		return
	ci.draw_texture_rect_region(tex, Rect2(r.position, Vector2(c, r.size.y)), Rect2(0, 0, cap, ts.y), mod)
	ci.draw_texture_rect_region(tex, Rect2(r.position + Vector2(c, 0), Vector2(r.size.x - 2.0 * c, r.size.y)), Rect2(cap, 0, ts.x - 2 * cap, ts.y), mod)
	ci.draw_texture_rect_region(tex, Rect2(r.position + Vector2(r.size.x - c, 0), Vector2(c, r.size.y)), Rect2(ts.x - cap, 0, cap, ts.y), mod)

## Text centred on `centre` (screen px): fill colour, optional 1 px ring.
static func text_centered(ci: CanvasItem, font: Font, text: String, size: int, centre: Vector2, col: Color, ring: Color = Color(0, 0, 0, 0)) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var base := Vector2(roundf(centre.x - w * 0.5), roundf(centre.y + (font.get_ascent(size) - font.get_descent(size)) * 0.5))
	if ring.a > 0.0:
		ci.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 1, ring)
	ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
