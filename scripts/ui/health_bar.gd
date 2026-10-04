extends Control
class_name HealthBar
## Terraria-style life readout: a text line ("Life 80/100") above a bar. Reads a
## Health node by polling; nothing in combat knows this exists (CLAUDE.md §5).
## Looks are slots: `frame_style` (any StyleBox, e.g. a StyleBoxTexture) and
## `fill_texture` can be dropped in later with no code change.

@export var bar_width := 220
@export var bar_height := 18
@export var text_gap := 2
@export var font_size := 14
@export var label_format := "Life %d/%d"
@export var frame_margin := 2
@export var frame_style: StyleBox            ## null = built-in flat frame
@export var fill_texture: Texture2D          ## null = flat colour; tinted by the colours below
@export var fill_color := Color(0.82, 0.14, 0.14)
@export var low_color := Color(1.0, 0.5, 0.4)
@export var trail_color := Color(1.0, 0.78, 0.7, 0.9)
@export_range(0.0, 1.0) var low_threshold := 0.3   ## below this fraction the bar pulses
@export var pulse_speed := 6.0
@export var trail_delay := 0.5                      ## seconds the "lost HP" chunk waits
@export var trail_speed := 0.6                      ## then drains this fraction of max HP per second

var width_override := 0      ## set by the HUD while F3 is open (0 = use bar_width); code-owned, not an export
var _health: Health
var _layout_key := []
var _frac := 1.0
var _trail := 1.0
var _since_hit := 0.0
var _time := 0.0
var _text_h := 0
var _font: Font

func bind(h: Health) -> void:
	_health = h
	_frac = _read_frac()
	_trail = _frac

func fraction() -> float:
	return _frac

func trail_fraction() -> float:
	return _trail

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_relayout()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if frame_style == null:
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.08, 0.02, 0.02, 0.85)
		f.set_border_width_all(2)
		f.border_color = Color(0.0, 0.0, 0.0, 0.95)
		frame_style = f

func label_text() -> String:
	return label_format % [roundi(_health.hp), roundi(_health.max_hp)] if _health else ""

func _bar_w() -> int:
	return width_override if width_override > 0 else bar_width

## Re-measure when a size export (or the F3 width override) changed.
func _relayout() -> void:
	_layout_key = [font_size, text_gap, _bar_w(), bar_height]
	_text_h = int(ceilf(_font.get_height(font_size)))
	custom_minimum_size = Vector2(_bar_w(), _text_h + text_gap + bar_height)
	size = custom_minimum_size

func _read_frac() -> float:
	return clampf(_health.hp / maxf(_health.max_hp, 1.0), 0.0, 1.0) if _health else 0.0

func _process(delta: float) -> void:
	if _font and _layout_key != [font_size, text_gap, _bar_w(), bar_height]:
		_relayout()
	delta /= maxf(Engine.time_scale, 0.0001)   # real seconds, like camera_shake.gd
	_time += delta
	var f := _read_frac()
	if f < _frac:
		_since_hit = 0.0          # fresh damage: the trail waits, then drains
	_frac = f
	if _trail <= f:
		_trail = f
	else:
		_since_hit += delta
		if _since_hit >= trail_delay:
			_trail = maxf(f, _trail - trail_speed * delta)
	queue_redraw()

func _draw() -> void:
	if _font == null:
		return
	var bar_top := _text_h + text_gap
	var txt := label_text()
	var tp := Vector2(0, _text_h - 3)
	draw_string(_font, tp + Vector2(1, 1), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.8))
	draw_string(_font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	draw_style_box(frame_style, Rect2(0, bar_top, _bar_w(), bar_height))
	var inner := Rect2(frame_margin, bar_top + frame_margin, _bar_w() - 2 * frame_margin, bar_height - 2 * frame_margin)
	_draw_part(inner, _trail, trail_color)
	var c := fill_color
	if _frac <= low_threshold and _frac > 0.0:
		c = fill_color.lerp(low_color, 0.5 + 0.5 * sin(_time * pulse_speed))
	_draw_part(inner, _frac, c)

## Left `frac` of `inner`, whole pixels (no blurry edges).
func _draw_part(inner: Rect2, frac: float, c: Color) -> void:
	var w := roundi(inner.size.x * frac)
	if w <= 0:
		return
	var r := Rect2(inner.position, Vector2(w, inner.size.y))
	if fill_texture:
		var tw := fill_texture.get_size()
		draw_texture_rect_region(fill_texture, r, Rect2(Vector2.ZERO, Vector2(tw.x * frac, tw.y)), c)
	else:
		draw_rect(r, c)
