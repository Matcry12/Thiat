class_name F3DangerButton
extends Button
## Red button: the first click only asks "Sure? 2s"; a second one within `confirm_seconds` runs `cb`.
## Armed = the cream "Sure?" look (theme variation F3DangerArmed) + a red countdown bar inside the bottom lip.
## meta "armed": 0 = idle, else the arm number (a late timer from an earlier arm must not disarm a new one).

@export var bar_color := Color(222.0 / 255.0, 52.0 / 255.0, 52.0 / 255.0)
@export var bar_bottom := 9.0     # art px from the button bottom (slices.json note of button_danger_armed)
@export var bar_side := 6.0       # art px from the left / right edge
@export var bar_height := 2.0     # art px

var idle_text := ""
var seconds := 2.0
var _cb: Callable
var _bar: ColorRect
var _end_msec := 0
var _scale := 2


func _ready() -> void:
	set_process(false)   # a script with _process starts it by itself; only an armed button ticks


func setup(text_: String, cb: Callable, confirm_seconds: float, art_scale: int) -> F3DangerButton:
	idle_text = text_
	text = text_
	seconds = confirm_seconds
	_cb = cb
	_scale = art_scale
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = "F3Danger"
	set_meta("armed", 0)
	_bar = ColorRect.new()
	_bar.color = bar_color
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.anchor_right = 1.0
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -bar_bottom * art_scale
	_bar.offset_bottom = -(bar_bottom - bar_height) * art_scale
	_bar.offset_left = bar_side * art_scale
	_bar.visible = false
	add_child(_bar)
	set_process(false)
	pressed.connect(_on_pressed)
	return self


func is_armed() -> bool:
	return int(get_meta("armed")) != 0


func _on_pressed() -> void:
	if is_armed():
		_disarm()
		_cb.call()
		return
	var n := Time.get_ticks_msec() + 1
	set_meta("armed", n)
	_end_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
	theme_type_variation = "F3DangerArmed"
	_bar.visible = true
	set_process(true)
	_tick()
	get_tree().create_timer(seconds).timeout.connect(func():
		if is_instance_valid(self) and int(get_meta("armed")) == n:
			_disarm())


func _disarm() -> void:
	set_meta("armed", 0)
	text = idle_text
	theme_type_variation = "F3Danger"
	_bar.visible = false
	set_process(false)


func _process(_d: float) -> void:
	_tick()


func _tick() -> void:
	var left := maxf(0.0, (_end_msec - Time.get_ticks_msec()) / 1000.0)
	var t := "Sure? %ds" % ceili(left)
	if text != t:
		text = t
	var full := size.x - 2.0 * bar_side * _scale
	_bar.offset_right = -(bar_side * _scale) - full * (1.0 - clampf(left / seconds, 0.0, 1.0))
