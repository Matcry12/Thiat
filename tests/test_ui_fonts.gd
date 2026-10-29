extends SceneTree
# Island Workshop fonts (assets/ui/fonts, baked by tools/ui_bake/bake_fonts.py): advances / heights match the
# glyph tables, 2x is an exact integer scale, outline ring exists. Run: godot --headless --script tests/test_ui_fonts.gd
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _w(n: String, s: String, size: int) -> float:
	return UiFonts.get_font(n).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x

func _init() -> void:
	for n in ["body", "bold", "small"]:
		_check(UiFonts.get_font(n).get_supported_chars().length() >= 114, "%s: glyph count" % n)
	# Body: advance = glyph width + 1 (T,h,e = 5 each -> 6*3)
	_check(_w("body", "The", 9) == 18.0, "body 'The' = 18")
	_check(_w("body", "ml", 9) == 9.0, "body 'ml' = m(5)+1 + l(2)+1 = 9")
	# Bold: doubled strokes -> +1 per normal glyph; wide m/w/M/W keep table width 7 (+1)
	_check(_w("bold", "The", 9) == 21.0, "bold 'The' = 21")
	_check(_w("bold", "m", 9) == 8.0, "bold 'm' wide = 8")
	# Small: 3 px glyphs, advance 4; star icon 3 wide
	_check(_w("small", "0123", 5) == 16.0, "small digits = 4 each")
	# icons: body star 7 wide -> 8
	_check(_w("body", "★", 9) == 8.0, "body star = 8")
	# heights
	_check(UiFonts.get_font("body").get_height(9) == 9.0, "body height 9")
	_check(UiFonts.get_font("small").get_height(5) == 5.0, "small height 5")
	# 2x = exact integer scale
	_check(_w("bold", "Settings", 18) == 2.0 * _w("bold", "Settings", 9), "bold 2x width exact")
	_check(UiFonts.get_font("body").get_height(18) == 18.0, "body 2x height 18")
	# outline ring registered at outline size 1
	var f := UiFonts.get_font("body")
	_check(f.get_glyph_uv_rect(0, Vector2i(9, 1), f.get_glyph_index(9, 65, 0)).size == Vector2(7, 9), "outline ring 'A' = 5x7 + 2")
	print("PASS" if _ok else "FAILED")
	quit(0 if _ok else 1)
