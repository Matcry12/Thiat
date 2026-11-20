extends Control
class_name FoodBar
## Island Workshop food bar under the life bar (food-algorithm.md HUD, decision 0071): rope frame + drumstick socket, warm gloss
## fill, no number (hover shows "55 / 100"). Reads a Hunger node by polling; nothing in combat knows this exists (CLAUDE.md §5).
## Look = skin textures (food_frame / food_frame_starving / food_fill); only behaviour numbers are exported here.
## Starving: the fill is empty and the red frame variant fades in and out over the normal one.

@export var starve_pulse_hz := 2.0                 ## red socket pulses this many times per second while starving
@export_range(0.0, 1.0) var starve_pulse_min := 0.35   ## weakest red (0 = fades fully out)
@export_group("Frame layout (art px; the fill cap comes from assets/game/ui/skin/slices.json food_fill)")
@export var fill_x := 15
@export var fill_y := 4
@export var fill_w := 114
@export var fill_h := 12

var skin: InventorySkin
var _hunger: Hunger
var _applied: InventorySkin
var _frac := 1.0
var _starving := false
var _time := 0.0

func bind(h: Hunger) -> void:
	_hunger = h
	_read()

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func fraction() -> float:
	return _frac

func is_starving() -> bool:
	return _starving

## 0..1 strength of the red frame now (1 when not pulsing is never used: only drawn while starving).
func starve_alpha() -> float:
	return lerpf(starve_pulse_min, 1.0, 0.5 + 0.5 * sin(_time * TAU * starve_pulse_hz))

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_skin()

## Hover text: "55 / 100".
func tip_text() -> String:
	return "%d / %d" % [roundi(_hunger.food), roundi(_hunger.max_food)] if _hunger else ""

func _apply_skin() -> void:
	var sk := get_skin()
	var t := sk.food_frame_tex
	custom_minimum_size = (t.get_size() if t else Vector2(136, 20)) * sk.art_scale
	size = custom_minimum_size

func _read() -> void:
	_frac = clampf(_hunger.fraction(), 0.0, 1.0) if _hunger else 0.0
	_starving = _hunger != null and _hunger.is_starving()

func _process(delta: float) -> void:
	var sk := get_skin()
	if sk != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = sk
		sk.changed.connect(_apply_skin)
		_apply_skin()
	_time += delta / maxf(Engine.time_scale, 0.0001)   # real seconds, like HealthBar
	_read()
	queue_redraw()

func _draw() -> void:
	var sk := get_skin()
	var sc := sk.art_scale
	PixelArt.draw_pic(self, sk.food_frame_tex, Vector2.ZERO, sc)
	if _starving:
		PixelArt.draw_pic(self, sk.food_frame_starving_tex, Vector2.ZERO, sc, Color(1, 1, 1, starve_alpha()))
		return   # empty bar: nothing to fill
	var w := roundf(fill_w * _frac) * sc
	if w > 0.0:
		PixelArt.draw_h3(self, sk.food_fill_tex, Rect2(Vector2(fill_x, fill_y) * sc, Vector2(w, fill_h * sc)), PixelArt.slice("food_fill").x, sc)
