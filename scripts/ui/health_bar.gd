extends Control
class_name HealthBar
## Island Workshop life bar: rope frame + heart, gloss fill, damage trail, "cur/max" number (decision 0043). Reads a Health node by polling;
## nothing in combat knows this exists (CLAUDE.md §5). The look (sizes, colours, frame / fill textures)
## comes from the InventorySkin; only the behaviour numbers (trail, pulse) are exported here.

@export_range(0.0, 1.0) var low_threshold := 0.3   ## below this fraction the bar pulses
@export var fill_tint := Color(1.0, 0.26, 0.26)   ## modulate over the grey gloss ramp of hp_fill
@export var pulse_speed := 6.0
@export var trail_delay := 0.5                      ## seconds the "lost HP" chunk waits
@export var trail_speed := 0.6                      ## then drains this fraction of max HP per second
@export_range(0.0, 1.0) var low_tint := 0.6         ## how far the fill pulses toward health_low_color
@export_group("Frame layout (art px; the fill cap comes from assets/ui/game/slices.json hp_fill)")
@export var fill_x := 15
@export var fill_y := 5
@export var fill_w := 114
@export var fill_h := 14
@export var number_x := 108   ## HP number RIGHT edge (fixed, not tied to the fill end)
@export var number_y := 9

var skin: InventorySkin
var _health: Health
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

## Skin -> size: the rope frame at real size (art px * art_scale), never stretched.
func _apply_skin() -> void:
	var sk := get_skin()
	var t := sk.hp_frame_tex
	custom_minimum_size = (t.get_size() if t else Vector2(136, 26)) * sk.art_scale
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
	var sc := sk.art_scale
	PixelArt.draw_pic(self, sk.hp_frame_tex, Vector2.ZERO, sc)
	var fr := Rect2(Vector2(fill_x, fill_y) * sc, Vector2(fill_w, fill_h) * sc)
	_draw_part(fr, _trail, sk.hp_trail_tex, Color.WHITE)
	var c := fill_tint
	if _frac <= low_threshold and _frac > 0.0:
		c = c.lerp(sk.health_low_color, low_tint * (0.5 + 0.5 * sin(_time * pulse_speed)))
	_draw_part(fr, _frac, sk.hp_fill_tex, c)
	if _health:
		var txt := "%d/%d" % [roundi(_health.hp), roundi(_health.max_hp)]
		var f := sk.ui_font("bold")
		var fs := PixelArt.font_px(sk, "bold")
		var num_w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		PixelArt.text_centered(self, f, txt, fs, Vector2(number_x - num_w * 0.5 / sc, number_y) * sc, sk.pal_cream, sk.text_outline_color)

## Left `frac` of the fill area, caps kept (whole screen pixels).
func _draw_part(r: Rect2, frac: float, tex: Texture2D, mod: Color) -> void:
	var w := roundf(r.size.x * frac / get_skin().art_scale) * get_skin().art_scale
	if w > 0.0:
		PixelArt.draw_h3(self, tex, Rect2(r.position, Vector2(w, r.size.y)), PixelArt.slice("hp_fill").x, get_skin().art_scale, mod)
