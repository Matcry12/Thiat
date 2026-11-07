extends Control
class_name BossBar
## Boss HP, bottom centre. Hidden until the boss WAKES, then it fades / slides in; hidden again when the
## boss goes back to sleep (leash, return) or after a short delay once it is defeated. No text.
## The ONE hook for "the boss is awake": `set_awake(bool)`. Today the HUD wires it to Boss.aggro_changed
## (engaged = awake); the W7 altar summon can call `set_awake(true)` itself and reuse everything else.
## Opaque dark background so full and empty differ at a glance; the fill changes colour in phase 2 and
## flashes once when it starts; a thin marker sits where phase 2 begins. Looks = InventorySkin (boss_*).

var skin: InventorySkin
var _boss: Boss
var _awake := false
var _shown := 0.0        # 0..1 fade/slide progress
var _hide_in := -1.0     # > 0: seconds until set_awake(false) (after a defeat)
var _flash_left := 0.0

func bind(b: Boss) -> void:
	_boss = b
	b.phase_changed.connect(func(p: int):   # only entering phase 2 flashes (a leash reset back to 1 does not)
		if p >= 2:
			_flash_left = get_skin().boss_flash_time)
	b.aggro_changed.connect(func(a: int): set_awake(a == Boss.Aggro.ENGAGED))
	b.defeated.connect(func(): _hide_in = get_skin().boss_hide_delay)
	set_awake(b.aggro == Boss.Aggro.ENGAGED)

func set_awake(on: bool) -> void:
	_awake = on
	if on:
		_hide_in = -1.0

func is_awake() -> bool:
	return _awake

func get_skin() -> InventorySkin:
	if skin == null:
		skin = load("res://data/ui/inventory_skin.tres")
	return skin

## The colour the fill is drawn in right now (phase colour, mixed toward the flash colour).
func fill_color() -> Color:
	var sk := get_skin()
	var c := sk.boss_phase2_color if _boss and _boss.phase >= 2 else sk.boss_fill_color
	if _flash_left > 0.0:
		var t := _flash_left / maxf(sk.boss_flash_time, 0.001)
		c = c.lerp(sk.boss_flash_color, t * (sk.boss_flash_mix + (1.0 - sk.boss_flash_mix) * sin(t * sk.boss_flash_speed)))
	return c

@export var title := "Orc Warlord"   ## name on the plate when the boss has no `boss_name`
@export_group("Frame layout (art px; the end caps come from assets/game/ui/skin/slices.json boss_fill / boss_plate)")
@export var fill_x := 14
@export var fill_y := 10
@export var fill_w := 256
@export var fill_h := 12
@export var plate_h := 16
@export var plate_gap := -5   ## art px between the plate bottom and the frame top (negative = the plate overlaps the frame)
@export var plate_pad := 26   ## plate width = name width + this

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

## Art px -> screen px: the skin's art_scale while `avail_w` holds the whole frame, else 1 (F3 dock / narrow window).
func scale_for(avail_w: float) -> int:
	var sk := get_skin()
	return sk.art_scale if avail_w >= _frame_size(sk).x * sk.art_scale else 1

## The frame picture's size (art px); a fixed fallback while the skin slot is empty.
func _frame_size(sk: InventorySkin) -> Vector2:
	return sk.boss_frame_tex.get_size() if sk.boss_frame_tex != null else Vector2(284, 28)

## Real size of the bar + name plate at the scale that fits `avail_w`. The HUD places the bar with this.
func natural_size(avail_w: float) -> Vector2:
	var sk := get_skin()
	var sc := scale_for(avail_w)
	var f := _frame_size(sk)
	return Vector2(f.x, plate_h + plate_gap + f.y) * sc

func boss_title() -> String:
	var n = _boss.get("boss_name") if _boss else null
	return str(n) if n != null and str(n) != "" else title

func _process(delta: float) -> void:
	var sk := get_skin()
	var dt := delta / maxf(Engine.time_scale, 0.0001)
	if _hide_in > 0.0:
		_hide_in -= dt
		if _hide_in <= 0.0:
			set_awake(false)
	_shown = move_toward(_shown, 1.0 if _awake else 0.0, dt / maxf(sk.boss_fade_time, 0.001))
	_flash_left = maxf(_flash_left - dt, 0.0)
	visible = _shown > 0.0
	modulate.a = _shown
	if visible:
		queue_redraw()

func _draw() -> void:
	if _boss == null:
		return
	var sk := get_skin()
	var sc := scale_for(size.x)
	draw_set_transform(Vector2(0, (1.0 - _shown) * sk.boss_slide_px))
	var top := (plate_h + plate_gap) * sc                      # bar frame starts below the name plate
	var fw := _frame_size(sk).x * sc
	var x0 := roundf((size.x - fw) * 0.5)
	PixelArt.draw_pic(self, sk.boss_frame_tex, Vector2(x0, top), sc)
	var fr := Rect2(Vector2(x0 + fill_x * sc, top + fill_y * sc), Vector2(fill_w, fill_h) * sc)
	var frac := clampf(_boss.health.hp / maxf(_boss.health.max_hp, 1.0), 0.0, 1.0)
	var w := roundf(fr.size.x * frac / sc) * sc
	if w > 0.0:
		PixelArt.draw_h3(self, sk.boss_fill_tex, Rect2(fr.position, Vector2(w, fr.size.y)), PixelArt.slice("boss_fill").x, sc, fill_color())   # grey gloss ramp x tint
	var mx := fr.position.x + roundf(fr.size.x / sc * _boss.phase2_threshold) * sc - sc
	PixelArt.draw_pic(self, sk.boss_mark_tex, Vector2(mx, fr.position.y), sc)
	# name plate: bold CREAM + OUT, width = name + 26 art px, centred, `plate_gap` above the bar
	var f := sk.ui_font("bold")
	var fs := UiFonts.NATIVE["bold"] * sc
	var name := boss_title()
	var tw := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pw := roundf(tw / sc) * sc + plate_pad * sc
	var pt := sk.boss_plate_tex
	var pr := Rect2(Vector2(roundf((size.x - pw) * 0.5), 0), Vector2(pw, (pt.get_size().y if pt != null else plate_h) * sc))
	PixelArt.draw_h3(self, pt, pr, PixelArt.slice("boss_plate").x, sc)
	PixelArt.text_centered(self, f, name, fs, pr.get_center(), sk.pal_cream, sk.text_outline_color)
