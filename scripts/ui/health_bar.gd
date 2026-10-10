extends Control
class_name HealthBar
## Terraria-style life bar, no numbers (the hover tooltip shows them). Reads a Health node by polling;
## nothing in combat knows this exists (CLAUDE.md §5). The look (sizes, colours, frame / fill textures)
## comes from the InventorySkin; only the behaviour numbers (trail, pulse) are exported here.

@export_range(0.0, 1.0) var low_threshold := 0.3   ## below this fraction the bar pulses
@export var pulse_speed := 6.0
@export var trail_delay := 0.5                      ## seconds the "lost HP" chunk waits
@export var trail_speed := 0.6                      ## then drains this fraction of max HP per second

var skin: InventorySkin
var _health: Health
var _frame: StyleBox
var _applied: InventorySkin
var _frac := 1.0
var _trail := 1.0
var _since_hit := 0.0
var _time := 0.0

func bind(h: Health) -> void:
	_health = h
	_frac = _read_frac()
	_trail = _frac

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func fraction() -> float:
	return _frac

func trail_fraction() -> float:
	return _trail

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_skin()

## Hover text: "73 / 100".
func tip_text() -> String:
	return "%d / %d" % [roundi(_health.hp), roundi(_health.max_hp)] if _health else ""

## Skin -> frame style + size. Once, and again when the skin changes.
func _apply_skin() -> void:
	var sk := get_skin()
	if sk.bar_frame_texture:
		var t := StyleBoxTexture.new()
		t.texture = sk.bar_frame_texture
		t.set_texture_margin_all(sk.bar_frame_patch_margin)
		_frame = t
	else:
		var f := StyleBoxFlat.new()
		f.bg_color = sk.bar_frame_color
		f.set_border_width_all(2)
		f.border_color = sk.bar_frame_border
		_frame = f
	custom_minimum_size = Vector2(sk.health_bar_width, sk.health_bar_height)
	size = custom_minimum_size

func _read_frac() -> float:
	return clampf(_health.hp / maxf(_health.max_hp, 1.0), 0.0, 1.0) if _health else 0.0

func _process(delta: float) -> void:
	var sk := get_skin()
	if sk != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = sk
		sk.changed.connect(_apply_skin)
		_apply_skin()
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
	var sk := get_skin()
	var w := sk.health_bar_width
	var h := sk.health_bar_height
	draw_style_box(_frame, Rect2(0, 0, w, h))
	var m := sk.bar_frame_margin
	var inner := Rect2(m, m, w - 2 * m, h - 2 * m)
	_draw_part(inner, _trail, sk.health_trail_color, sk.bar_fill_texture)
	var c := sk.health_fill_color
	if _frac <= low_threshold and _frac > 0.0:
		c = c.lerp(sk.health_low_color, 0.5 + 0.5 * sin(_time * pulse_speed))
	_draw_part(inner, _frac, c, sk.bar_fill_texture)

## Left `frac` of `inner`, whole pixels (no blurry edges).
func _draw_part(inner: Rect2, frac: float, c: Color, tex: Texture2D) -> void:
	var w := roundi(inner.size.x * frac)
	if w <= 0:
		return
	var r := Rect2(inner.position, Vector2(w, inner.size.y))
	if tex:
		var tw := tex.get_size()
		draw_texture_rect_region(tex, r, Rect2(Vector2.ZERO, Vector2(tw.x * frac, tw.y)), c)
	else:
		draw_rect(r, c)
