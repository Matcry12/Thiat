class_name UiFonts
## Island Workshop pixel fonts (baked by tools/ui_bake/bake_fonts.py). See assets/ui/fonts/README.md.
## UiFonts.get_font("body"|"bold"|"small") -> FontFile that supports outline_size = 1
## (the 1 px 8-neighbour ring, drawn in font_outline_color). Use at font_size = 2 * NATIVE[name].
const NATIVE := {"body": 9, "bold": 9, "small": 5}
static var _cache := {}

static func get_font(name: String) -> FontFile:
	if _cache.has(name):
		return _cache[name]
	var f: FontFile = load("res://assets/ui/fonts/%s.fnt" % name).duplicate()
	var native: int = NATIVE[name]
	var ring := (load("res://assets/ui/fonts/%s_ring.png" % name) as Texture2D).get_image()
	var base := Vector2i(native, 0)
	var o := Vector2i(native, 1)
	f.set_texture_image(0, o, 0, ring)
	for ch in f.get_supported_chars():
		var c := ch.unicode_at(0)
		var g := f.get_glyph_index(native, c, 0)
		f.set_glyph_texture_idx(0, o, g, 0)
		var uv := f.get_glyph_uv_rect(0, base, g)
		var off := f.get_glyph_offset(0, base, g)
		f.set_glyph_uv_rect(0, o, g, Rect2(uv.position - Vector2.ONE, uv.size + Vector2(2, 2)))
		f.set_glyph_size(0, o, g, uv.size + Vector2(2, 2))
		f.set_glyph_offset(0, o, g, off - Vector2.ONE)
	_cache[name] = f
	return f
