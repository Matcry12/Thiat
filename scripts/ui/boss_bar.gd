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
var _frame: StyleBox
var _applied: InventorySkin

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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

func _apply_skin() -> void:
	var sk := get_skin()
	if sk.boss_bg_texture:
		var t := StyleBoxTexture.new()
		t.texture = sk.boss_bg_texture
		t.set_texture_margin_all(sk.bar_frame_patch_margin)
		_frame = t
	else:
		var f := StyleBoxFlat.new()
		f.bg_color = sk.boss_bg_color
		f.set_border_width_all(sk.boss_border_width)
		f.border_color = sk.boss_border_color
		_frame = f

func _process(delta: float) -> void:
	var sk := get_skin()
	if sk != _applied:
		if _applied != null:
			_applied.changed.disconnect(_apply_skin)
		_applied = sk
		sk.changed.connect(_apply_skin)
		_apply_skin()
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
	var sk := get_skin()
	draw_set_transform(Vector2(0, (1.0 - _shown) * sk.boss_slide_px))
	var w := size.x
	var h := size.y
	draw_style_box(_frame, Rect2(0, 0, w, h))
	var m := float(sk.boss_inset)
	var inner := Rect2(m, m, w - 2 * m, h - 2 * m)
	var frac := clampf(_boss.health.hp / maxf(_boss.health.max_hp, 1.0), 0.0, 1.0)
	var r := Rect2(inner.position, Vector2(roundf(inner.size.x * frac), inner.size.y))
	if r.size.x > 0.0:
		if sk.boss_fill_texture:
			draw_texture_rect(sk.boss_fill_texture, r, false, fill_color())
		else:
			draw_rect(r, fill_color())
	var mx := roundf(w * _boss.phase2_threshold - sk.boss_marker_width * 0.5)
	draw_rect(Rect2(mx, 0, sk.boss_marker_width, h), sk.boss_marker_color)
