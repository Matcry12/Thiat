# UI fonts (Island Workshop)

Baked by `python3 tools/ui_bake/bake_fonts.py` (deterministic, $0) from the glyph tables in
`tools/ui_mock/index.html` (fallback `tools/f3_mock/workshop.html`). Never edit the PNG/.fnt by hand.
Fonts: `body` (native 9 px line), `bold` (9), `small` (5). White glyphs, 1 art px = 1 texel.
`<name>_ring.png` = same layout, 1 px 8-neighbour dilation (the OUT outline incl. diagonals).
Missing ASCII (`$ \ ^ ` { }`) falls back to `?` like the mock.

## Use (2x, crisp)
Fonts import with `fixed_size` = native + integer-only scaling, project filter is nearest.
So `font_size = 2 * native` is an exact 2x (18 / 18 / 10); other sizes snap to whole multiples.

```gdscript
var l := Label.new()
l.add_theme_font_override("font", UiFonts.get_font("bold"))   # scripts/ui/ui_fonts.gd
l.add_theme_font_size_override("font_size", UiFonts.NATIVE["bold"] * 2)
l.add_theme_color_override("font_color", Color8(252, 242, 222))        # CREAM
l.add_theme_constant_override("outline_size", 1)                      # OUT ring, scales with the font
l.add_theme_color_override("font_outline_color", Color8(62, 36, 39))  # OUT
```

## Outline
Plain `load("res://assets/ui/fonts/bold.fnt")` has NO outline (Godot only outlines vector fonts).
`UiFonts.get_font()` returns a copy with the `_ring.png` registered as outline size 1, so
`outline_size = 1` draws the exact mock outline (one art px = 2 screen px at 2x). Use
`outline_size = 0` for no outline. Check: `tests/test_ui_fonts.gd`, shot `tools/f3_mock/game_shots/fonts.png`.
