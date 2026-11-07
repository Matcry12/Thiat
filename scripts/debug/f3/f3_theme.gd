class_name F3Theme
extends RefCounted
## The ONE place that builds the F3 "Island Workshop" look: names the baked parts (assets/dev/ui/f3/slices.json; PixelArt does the
## nearest upscale + 9-slice) and returns a Theme with type variations. Widgets only set `theme_type_variation`.
## Swap the look = change the PNGs / this file. Nothing else in scripts/debug/f3 knows a part name or a colour of the art.
##
## Variations (base type): F3Tab F3Category F3Section F3Button F3Primary F3Danger F3DangerArmed F3Chip F3ChipOn F3Keycap
## F3Block F3Icon (Button) | F3Field F3FieldPending F3Search (LineEdit) | F3Toggle (CheckBox) | F3Slider (HSlider) |
## F3Dock F3Note (PanelContainer) | F3Name F3Dim F3Small F3Group F3Hint F3Banner F3Paper F3PaperDim F3Stale F3Gold (Label)

const DIR := "res://assets/dev/ui/f3/"
static var _box := {}


static func _parts() -> Dictionary:
	return PixelArt.parts(DIR)


## A part as a crisp `scale`x texture (PixelArt's nearest copy of the art-scale image).
static func tex(part: String, scale := 2) -> Texture2D:
	return PixelArt.up(load(DIR + _parts()[part]["file"]), scale)


## A 9-slice StyleBox of a part: margins and content margins from slices.json, in screen px (cached, shared: never edit it).
static func box(part: String, scale := 2) -> StyleBoxTexture:
	var k := "%s@%d" % [part, scale]
	if not _box.has(k):
		_box[k] = PixelArt.box(load(DIR + _parts()[part]["file"]), part, scale, DIR)
	return _box[k]


## Same as box() but with a few content margins changed (a copy, never the shared one).
static func box_with(part: String, scale: int, margins: Dictionary) -> StyleBoxTexture:
	var s: StyleBoxTexture = box(part, scale).duplicate()
	for side in margins:
		s.set("content_margin_" + side, margins[side])
	return s


static func empty() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Draws the nail of a pinned note at the top centre of `ci` (call from its _draw()).
static func draw_nail(ci: Control, scale := 2) -> void:
	var t := tex("icon_pin_nail", scale)
	ci.draw_texture(t, Vector2(roundf(ci.size.x * 0.5 - t.get_width() * 0.5), 4 * scale))


## `look`: colours + font sizes from the dock's @exports: out line cream gold muted dim page hp ok scale.
static func build(look: Dictionary) -> Theme:
	var sc: int = look.get("scale", 2)
	var t := Theme.new()
	# two fonts: TEXT (names, numbers, search, status lines, hints: clean and readable) and LABEL (the pixel Bold: tabs, headers, buttons)
	var tfont: Font = look.get("text_font") if look.get("text_font") != null else ThemeDB.fallback_font
	var lfont: Font = look.get("label_font") if look.get("label_font") != null else UiFonts.get_font("bold")
	var ts: int = look.get("text_size", 15)
	var ss: int = look.get("small_text_size", 13)
	var ls: int = look.get("label_size", UiFonts.NATIVE["bold"] * sc)
	var to: int = look.get("text_outline", 0)
	var bold := lfont
	var body := tfont
	var small := tfont
	var fs := ls
	var fs_small := ss
	t.default_font = tfont
	t.default_font_size = ts
	var out: Color = look["out"]   # outline colour (InventorySkin text_outline_color)
	var ink: Color = look.get("ink", out)   # text on paper
	var cream: Color = look["cream"]

	# --- labels (on dark leather: cream; on paper: OUT, no outline)
	_label(t, "Label", tfont, ts, cream, out, to)
	_label(t, "F3Name", tfont, ts, cream, out, to)
	_label(t, "F3Dim", tfont, ts, look["dim"], out, to)
	_label(t, "F3Small", tfont, ss, look["dim"], out, to)
	_label(t, "F3ChipText", tfont, ss, cream, out, to)
	_label(t, "F3Group", tfont, ss, look["gold"], out, to)
	_label(t, "F3Gold", lfont, ls, look["gold"], out, 1)
	_label(t, "F3Hint", tfont, ss, look["gold"], out, to)
	_label(t, "F3Title", lfont, ls, cream, out, 1)
	_label(t, "F3Changed", tfont, ts, look["gold"], out, to)
	_label(t, "F3Badge", tfont, ss, cream, out, to)
	t.set_stylebox("normal", "F3Badge", box("badge", sc))
	_label(t, "F3FieldLabel", tfont, ts, ink, out, 0)
	t.set_stylebox("normal", "F3FieldLabel", box_with("field", sc, {"top": 0, "bottom": 0}))
	_label(t, "F3Paper", tfont, ts, ink, out, 0)
	_label(t, "F3PaperDim", tfont, ts, look["line"], out, 0)
	_label(t, "F3Stale", tfont, ss, look["hp_dark"], out, 0)
	_label(t, "F3Banner", lfont, ls, ink, out, 0)
	t.set_stylebox("normal", "F3Banner", box_with("banner", sc, {"left": 8 * sc, "right": 8 * sc}))

	# --- buttons
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Button", bold, fs, ["button_idle", "button_hover", "button_pressed", "button_idle", "button_disabled"],
		[ink, ink, ink, ink, look["muted"]], out, 0)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Primary", bold, fs, ["button_primary", "button_primary_hover", "button_pressed", "button_primary", "button_disabled"],
		[cream, cream, cream, cream, look["muted"]], out, 1)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Danger", bold, fs, ["button_danger", "button_danger_hover", "button_danger_hover", "button_danger", "button_disabled"],
		[cream, cream, cream, cream, look["muted"]], out, 1)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3DangerArmed", bold, fs, ["button_danger_armed", "button_danger_armed", "button_danger_armed", "button_danger_armed", "button_disabled"],
		[look["hp_dark"], look["hp_dark"], look["hp_dark"], look["hp_dark"], look["muted"]], out, 0)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Chip", bold, fs, ["chip_idle", "chip_idle", "chip_idle", "chip_idle", "chip_idle"],
		[cream, cream, cream, cream, cream], out, 1)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3ChipOn", bold, fs, ["chip_on_game", "chip_on_game", "chip_on_game", "chip_on_game", "chip_on_game"],
		[ink, ink, ink, ink, ink], out, 0)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Keycap", bold, fs, ["keycap", "keycap", "keycap", "keycap", "keycap"],
		[ink, ink, ink, ink, ink], out, 0)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Tab", bold, fs, ["tab_idle", "tab_idle", "tab_active", "tab_active", "tab_idle"],
		[cream, cream, cream, cream, cream], out, 1)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Category", bold, fs, ["category_band", "category_band_hover", "category_band_hover", "category_band_hover", "category_band"],
		[cream, cream, cream, cream, cream], out, 1)
	_button(t, sc, look.get("button_pad", 4.0), look.get("button_pad_y", 3.0), "Button", "F3Section", bold, fs, ["section_header", "section_header_hover", "section_header_hover", "section_header_hover", "section_header"],
		[cream, cream, cream, cream, cream], out, 1)
	for v in ["F3Category", "F3Section"]:   # their text is drawn by child labels: no content margins, so the height is ours
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var b: StyleBoxTexture = t.get_stylebox(st, v).duplicate()
			b.content_margin_top = 0
			b.content_margin_bottom = 0
			b.content_margin_left = 0
			b.content_margin_right = 0
			t.set_stylebox(st, v, b)
	# a block / row header: nothing until the pointer is on it
	t.set_type_variation("F3Block", "Button")
	for st in ["normal", "pressed", "disabled", "focus"]:
		t.set_stylebox(st, "F3Block", empty())
	t.set_stylebox("hover", "F3Block", box("row_hover", sc))
	t.set_stylebox("hover_pressed", "F3Block", box("row_hover", sc))
	t.set_font("font", "F3Block", bold)
	t.set_font_size("font_size", "F3Block", fs)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "F3Block", cream)
	t.set_color("font_outline_color", "F3Block", out)
	t.set_constant("outline_size", "F3Block", 1)
	t.set_type_variation("F3Link", "Button")   # "Collapse all": text only, no art
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(st, "F3Link", empty())
	t.set_font("font", "F3Link", tfont)
	t.set_font_size("font_size", "F3Link", ts)
	t.set_color("font_color", "F3Link", look["dim"])
	t.set_color("font_hover_color", "F3Link", look["gold"])
	# an icon-only button (reset / copy / star / pin): no frame, the texture is the look
	t.set_type_variation("F3Icon", "Button")
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(st, "F3Icon", empty())

	# --- text fields
	_field(t, "LineEdit", "field", "field_focus", tfont, ts, look, sc)
	_field(t, "F3Field", "field", "field_focus", tfont, ts, look, sc)
	_field(t, "F3FieldPending", "field_pending", "field_pending", tfont, ts, look, sc)
	_field(t, "F3Search", "search_field", "search_field_focus", tfont, ts, look, sc)
	t.set_color("font_placeholder_color", "F3Search", look["line"])

	t.set_type_variation("F3Swatch", "ColorPickerButton")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "F3Swatch", box_with("field", sc, {"top": 3 * sc, "bottom": 3 * sc, "left": 3 * sc, "right": 3 * sc}))
	t.set_stylebox("focus", "F3Swatch", empty())

	# --- slider, toggle, scroll bar
	t.set_type_variation("F3Slider", "HSlider")
	t.set_stylebox("slider", "F3Slider", box_with("slider_groove", sc, {"top": 3 * sc, "bottom": 3 * sc}))   # HSlider draws the groove as tall as its content margins
	t.set_stylebox("grabber_area", "F3Slider", box_with("slider_fill", sc, {"top": 1.5 * sc, "bottom": 1.5 * sc}))
	t.set_stylebox("grabber_area_highlight", "F3Slider", box_with("slider_fill", sc, {"top": 1.5 * sc, "bottom": 1.5 * sc}))
	t.set_icon("grabber", "F3Slider", tex("slider_knob", sc))
	t.set_icon("grabber_highlight", "F3Slider", tex("slider_knob_hover", sc))
	t.set_icon("grabber_disabled", "F3Slider", tex("slider_knob", sc))
	t.set_type_variation("F3Toggle", "CheckBox")
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		t.set_stylebox(st, "F3Toggle", empty())
	t.set_icon("checked", "F3Toggle", tex("toggle_on", sc))
	t.set_icon("unchecked", "F3Toggle", tex("toggle_off", sc))
	t.set_icon("checked_disabled", "F3Toggle", tex("toggle_on", sc))
	t.set_icon("unchecked_disabled", "F3Toggle", tex("toggle_off", sc))
	t.set_stylebox("scroll", "VScrollBar", box("scroll_track", sc))
	t.set_stylebox("scroll_focus", "VScrollBar", box("scroll_track", sc))
	for g in ["grabber", "grabber_highlight", "grabber_pressed"]:
		t.set_stylebox(g, "VScrollBar", box("scroll_thumb", sc))

	# --- panels
	t.set_type_variation("F3Dock", "PanelContainer")
	t.set_stylebox("panel", "F3Dock", dock_frame_box(sc, look.get("search_lift", 10)))
	t.set_type_variation("F3Note", "PanelContainer")
	t.set_stylebox("panel", "F3Note", box("note", sc))
	return t


## The dock frame: texture drawn 8 art px bigger than the control (clips, moss, rope), content margins from slices.json.
static func dock_frame_box(sc: int, look_lift: float) -> StyleBoxTexture:
	var s: StyleBoxTexture = box("dock_frame", sc).duplicate()
	var p: Dictionary = _parts()["dock_frame"]
	var bx: Dictionary = p["box"]
	var c: Dictionary = p["content"]
	var tw: int = p["size"][0]
	var th: int = p["size"][1]
	s.expand_margin_left = bx["x"] * sc
	s.expand_margin_top = bx["y"] * sc
	s.expand_margin_right = (tw - bx["x"] - bx["w"]) * sc
	s.expand_margin_bottom = (th - bx["y"] - bx["h"]) * sc
	s.content_margin_left = (c["left"] - bx["x"]) * sc
	s.content_margin_top = (c["top"] - bx["y"] - look_lift) * sc
	s.content_margin_right = (c["right"] - (tw - bx["x"] - bx["w"])) * sc
	s.content_margin_bottom = (c["bottom"] - (th - bx["y"] - bx["h"])) * sc
	return s


static func _label(t: Theme, base_or_var: String, font: Font, size: int, col: Color, out: Color, outline: int) -> void:
	if base_or_var != "Label":
		t.set_type_variation(base_or_var, "Label")
	t.set_font("font", base_or_var, font)
	t.set_font_size("font_size", base_or_var, size)
	t.set_color("font_color", base_or_var, col)
	t.set_color("font_outline_color", base_or_var, out)
	t.set_constant("outline_size", base_or_var, outline)
	t.set_constant("line_spacing", base_or_var, 0)


## states: [normal, hover, pressed, hover_pressed, disabled] part names; colours in the same order.
static func _button(t: Theme, sc: int, pad: float, padv: float, base: String, name: String, font: Font, size: int, states: Array, cols: Array, out: Color, outline: int) -> void:
	t.set_type_variation(name, base)
	var keys := ["normal", "hover", "pressed", "hover_pressed", "disabled"]
	var ckeys := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_disabled_color"]
	for i in 5:   # text never runs past the art: content margins from slices.json + `pad` px each side
		t.set_stylebox(keys[i], name, box_with(states[i], sc, {"left": box(states[i], sc).content_margin_left + pad, "right": box(states[i], sc).content_margin_right + pad,
			"top": box(states[i], sc).content_margin_top + padv, "bottom": box(states[i], sc).content_margin_bottom + padv}))
		t.set_color(ckeys[i], name, cols[i])
	t.set_stylebox("focus", name, empty())
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	t.set_color("font_outline_color", name, out)
	t.set_constant("outline_size", name, outline)


static func _field(t: Theme, name: String, normal: String, focus: String, font: Font, size: int, look: Dictionary, sc: int) -> void:
	if name != "LineEdit":
		t.set_type_variation(name, "LineEdit")
	var mg := {"top": 0, "bottom": 0} if name != "F3Search" else {"top": 0, "bottom": 0}
	t.set_stylebox("normal", name, box_with(normal, sc, mg))
	t.set_stylebox("focus", name, box_with(focus, sc, mg))
	t.set_stylebox("read_only", name, box_with(normal, sc, mg))
	t.set_font("font", name, font)
	t.set_font_size("font_size", name, size)
	for c in ["font_color", "font_selected_color", "font_uneditable_color"]:
		t.set_color(c, name, look.get("ink", look["out"]))
	t.set_color("caret_color", name, look.get("ink", look["out"]))
	t.set_color("selection_color", name, Color(look["gold"], 0.55))
	t.set_color("font_placeholder_color", name, Color(look.get("ink", look["out"]), 0.6))
	t.set_constant("caret_width", name, 2)
