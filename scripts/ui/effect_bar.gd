class_name EffectBar
extends Control
## Active effects (regen, sick, ...) as small framed icons on the ability row, right of Q/E/F (decision 0072, food-algorithm.md
## HUD). One EffectIcon per effect: frame (red for a debuff) + the effect's own `icon` texture + seconds left under it + a gold
## roman level badge (none for level I). The last `blink_time` seconds the icon dims and flickers and the timer goes muted.
## Reads Effects.active() by polling timers; rebuilds the icons only when `Effects.changed` fires. Never changes the effects.
## Sits inside the AbilityBar (child), so it follows that row. Pictures: skin effect_frame_tex / effect_frame_bad_tex + EffectData.icon.

@export var skin: InventorySkin
@export var lead_art := 10                  ## art px gap from the last ability frame to the first effect icon
@export var top_art := 2                    ## art px down from the ability frame's top edge (frames are 20 vs 22 tall)
@export var pitch_art := 25                 ## art px from one effect icon to the next
@export var blink_time := 3.0               ## seconds left when the icon starts to blink
@export var blink_hz := 2.0                 ## blink flashes per second
@export_range(0.0, 1.0) var blink_alpha := 0.5   ## dark overlay strength on the "off" half of a blink
@export_group("Icon layout (art px)")
@export var frame_art := 20
@export var icon_x := 4                    ## the symbol inside the frame
@export var icon_y := 4
@export var well_x := 2                    ## the dark well the blink dims
@export var well_y := 2
@export var well_size := 16
@export var timer_y := 22                  ## timer text row, under the frame
@export var timer_pad := 6                 ## room reserved for the timer under the frame
@export var badge_right := 17              ## right edge of the level badge
@export var badge_y := 13
@export var text_mid := 2.5                ## half the small-font row: text centre below its row top

var anchor: AbilityBar   ## the ability row; the bar floats beside it so it never widens the bottom-left block
var _effects: Effects
var _tooltip: HudTooltip
var _icons: Array[EffectIcon] = []
var _clock := 0.0

func bind(effects: Effects, tooltip: HudTooltip = null) -> void:
	_tooltip = tooltip
	if _effects != null and _effects.changed.is_connected(_rebuild):
		_effects.changed.disconnect(_rebuild)
	_effects = effects
	if _effects != null:
		_effects.changed.connect(_rebuild)
	_rebuild()

func icons() -> Array[EffectIcon]:
	return _icons

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _rebuild() -> void:
	for i in _icons:
		i.queue_free()
		remove_child(i)
	_icons.clear()
	if _effects == null:
		return
	for d: Dictionary in _effects.active():
		var ic := EffectIcon.new()
		ic.bar = self
		ic.data = d
		add_child(ic)
		_icons.append(ic)
		if _tooltip != null:
			_tooltip.watch(ic, ic.tip_text)
	_layout()

func _layout() -> void:
	var sc := get_skin().art_scale
	for n in _icons.size():
		_icons[n].position = Vector2(lead_art + n * pitch_art, top_art) * sc

func _process(delta: float) -> void:
	_clock += delta
	if anchor != null:
		var last := anchor.slots().back() as Control   # right edge of the last ability frame (the bar itself is wider)
		global_position = Vector2(last.get_global_rect().end.x if last else anchor.global_position.x, anchor.global_position.y)
	if _effects == null or _icons.is_empty():
		return
	var live := {}
	for d: Dictionary in _effects.active():
		live[d["id"]] = d
	for i in _icons:
		if live.has(i.data["id"]):
			i.data = live[i.data["id"]]
		i.queue_redraw()

## True while this blink flash is on the dark half (the clock runs from 0, so a tiny blink_hz freezes it dark).
func blink_dark() -> bool:
	return fmod(_clock * blink_hz, 1.0) < 0.5

## 1 -> "I" ... (Regen II). Levels past 10 fall back to digits.
static func roman(n: int) -> String:
	if n < 1 or n > 10:
		return str(n)
	return ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][n - 1]


## One effect: frame + icon + seconds + level badge. Real size (art px * skin.art_scale), nearest.
class EffectIcon extends Control:
	var bar: EffectBar
	var data: Dictionary = {}

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func is_debuff() -> bool:
		return data.get("is_debuff", false)

	func level() -> int:
		return data.get("level", 1)

	func has_badge() -> bool:
		return level() > 1

	func is_blinking() -> bool:
		return bar != null and data.get("time_left", 0.0) <= bar.blink_time

	## Dark flash showing now (blinking and on the dark half of the cycle).
	func is_dim() -> bool:
		return is_blinking() and bar.blink_dark()

	func timer_text() -> String:
		return "%ds" % ceili(data.get("time_left", 0.0))

	func tip_text() -> String:
		return "%s %s - %d s" % [data.get("display_name", ""), EffectBar.roman(level()), ceili(data.get("time_left", 0.0))] if has_badge() \
			else "%s - %d s" % [data.get("display_name", ""), ceili(data.get("time_left", 0.0))]

	func _process(_d: float) -> void:
		if bar == null:
			return
		var sk := bar.get_skin()
		custom_minimum_size = Vector2(bar.frame_art, bar.timer_y + bar.timer_pad) * sk.art_scale
		size = custom_minimum_size

	func _draw() -> void:
		if bar == null or data.is_empty():
			return
		var sk := bar.get_skin()
		var sc := sk.art_scale
		var font := sk.ui_font("small")
		var fpx := PixelArt.font_px(sk, "small")
		PixelArt.draw_pic(self, sk.effect_frame_bad_tex if is_debuff() else sk.effect_frame_tex, Vector2.ZERO, sc)
		var tex := data.get("icon") as Texture2D
		if tex != null:
			var p := Vector2(bar.icon_x, bar.icon_y) * sc
			draw_texture_rect(tex, Rect2(p, tex.get_size() * sc), false)
		if has_badge():
			var t := EffectBar.roman(level())
			var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
			PixelArt.text_centered(self, font, t, fpx, Vector2(bar.badge_right * sc - w * 0.5, (bar.badge_y + bar.text_mid) * sc), sk.pal_goldtxt, sk.pal_out)
		if is_dim():
			draw_rect(Rect2(Vector2(bar.well_x, bar.well_y) * sc, Vector2(bar.well_size, bar.well_size) * sc), Color(sk.pal_shadow, bar.blink_alpha))
		PixelArt.text_centered(self, font, timer_text(), fpx, Vector2(bar.frame_art * 0.5 * sc, (bar.timer_y + bar.text_mid) * sc), sk.pal_muted if is_blinking() else sk.pal_cream, sk.pal_out)
