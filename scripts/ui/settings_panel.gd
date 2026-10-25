class_name SettingsPanel
extends PanelContainer
## The settings page shared by the title screen and the pause menu (W8, decision 0040).
## Placeholder look: plain Godot controls. Every size / colour is an export. Volume and fullscreen live in
## GameSettings; shake lives on the live CameraShake node (GameSettings.current_shake / set_shake).
## Changing a control applies it at once and saves the file.

signal back_pressed

@export var font_size := 22
@export var heading_extra_size := 8
@export var row_gap := 14
@export var slider_width := 260.0
@export var name_width := 170.0
@export var value_width := 70.0
@export var panel_color := Color(0.1, 0.11, 0.16, 0.95)
@export var padding := 24
@export var corner_radius := 6
@export var fullscreen_on_color := Color(0.55, 1.0, 0.55)
@export var fullscreen_off_color := Color(1.0, 0.6, 0.6)

var _volume: HSlider
var _shake: HSlider
var _fullscreen: Button
var _back: Button
var _vol_label: Label
var _shake_label: Label
var _syncing := false

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_color
	sb.set_content_margin_all(padding)
	sb.set_corner_radius_all(corner_radius)
	add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", row_gap)
	add_child(box)
	var heading := Label.new()
	heading.text = "Settings"
	heading.add_theme_font_size_override("font_size", font_size + heading_extra_size)
	box.add_child(heading)
	var v := _slider(box, 0.0, 1.0, 0.05, "Master volume")
	_volume = v[0]
	_vol_label = v[1]
	var sh := _slider(box, 0.0, 2.0, 0.05, "Screen shake")
	_shake = sh[0]
	_shake_label = sh[1]
	_volume.value_changed.connect(func(x: float): _changed(func(): GameSettings.master_volume = x))
	_shake.value_changed.connect(func(x: float): _changed(func(): GameSettings.set_shake(get_tree(), x)))
	_fullscreen = Button.new()
	_fullscreen.toggle_mode = true
	_fullscreen.add_theme_font_size_override("font_size", font_size)
	_fullscreen.toggled.connect(func(on: bool): _changed(func(): GameSettings.fullscreen = on))
	box.add_child(_fullscreen)
	_back = Button.new()
	_back.text = "Back"
	_back.add_theme_font_size_override("font_size", font_size)
	_back.pressed.connect(func(): back_pressed.emit())
	box.add_child(_back)
	refresh()

## One row: name, slider, value text. Returns [slider, value label].
func _slider(parent: Control, lo: float, hi: float, step: float, text: String) -> Array:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var name_l := Label.new()
	name_l.text = text
	name_l.custom_minimum_size.x = name_width
	name_l.add_theme_font_size_override("font_size", font_size)
	row.add_child(name_l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.custom_minimum_size.x = slider_width
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var val := Label.new()
	val.custom_minimum_size.x = value_width
	val.add_theme_font_size_override("font_size", font_size)
	row.add_child(val)
	return [s, val]

func _changed(set_value: Callable) -> void:
	if _syncing:
		return
	set_value.call()
	GameSettings.save_file(get_tree())
	GameSettings.apply()
	_labels()

func _labels() -> void:
	_vol_label.text = "%d%%" % roundi(GameSettings.master_volume * 100.0)
	_shake_label.text = "%.2f" % GameSettings.current_shake(get_tree())
	_fullscreen.text = "Fullscreen: %s" % ("ON" if GameSettings.fullscreen else "OFF")
	_fullscreen.add_theme_color_override("font_color", fullscreen_on_color if GameSettings.fullscreen else fullscreen_off_color)
	_fullscreen.add_theme_color_override("font_pressed_color", fullscreen_on_color)

## Shows the current values (the panel can be opened many times). Focus goes to the first control.
func refresh() -> void:
	_syncing = true
	_volume.value = GameSettings.master_volume
	_shake.value = GameSettings.current_shake(get_tree())
	_fullscreen.button_pressed = GameSettings.fullscreen
	_syncing = false
	_labels()
	if is_visible_in_tree():
		_volume.grab_focus()

func volume_slider() -> HSlider:
	return _volume

func shake_slider() -> HSlider:
	return _shake

func fullscreen_button() -> Button:
	return _fullscreen
