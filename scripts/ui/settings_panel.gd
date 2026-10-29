class_name SettingsPanel
extends Control
## The settings page shared by the title screen and the pause menu (W8, decision 0040; looks = Island Workshop, README
## "Pause and Settings"). A baked panel at real size + rows at mock coordinates (art px, relative to the panel box).
## Volume and fullscreen live in GameSettings; shake lives on the live CameraShake node (GameSettings.current_shake / set_shake).
## Changing a control applies it at once and saves the file.

signal back_pressed

@export_group("Layout (art px)")
@export var panel_art_size := Vector2i(256, 146)   ## panel_settings.png (box 240x128 + 8 px pad)
@export var header_y := 4   ## "Settings" top, from the box top
@export var label_x := 16
@export var row_y := Vector3i(37, 58, 79)   ## label tops: volume, shake, fullscreen
@export var groove_x := 86
@export var groove_size := Vector2i(100, 9)
@export var value_dx := 112   ## value text, from the groove left
@export var checkbox_y := 76
@export var back_pos := Vector2i(70, 99)
@export var back_art_size := Vector2i(100, 20)
@export var shake_max := 2.0

var _volume: HSlider
var _shake: HSlider
var _fullscreen: Button
var _back: Button
var _vol_label: Label
var _shake_label: Label
var _syncing := false
var _sk: InventorySkin
var _sc := 2
var _groove: StyleBoxTexture   ## slider parts, 9-sliced with the margins from slices.json
var _fill: StyleBoxTexture
var _fill_hover: StyleBoxTexture

func _init() -> void:
	_sk = MenuScreen.skin()
	_sc = _sk.art_scale
	_groove = PixelArt.box(_sk.slider_groove_tex, "slider_groove", _sc, PixelArt.GAME, Vector4i.ZERO)
	_fill = PixelArt.box(_sk.slider_fill_tex, "slider_fill", _sc, PixelArt.GAME, Vector4i.ZERO)
	_fill_hover = PixelArt.box(_sk.slider_fill_hover_tex, "slider_fill_hover", _sc, PixelArt.GAME, Vector4i.ZERO)
	size = Vector2(panel_art_size) * _sc
	custom_minimum_size = size

func _ready() -> void:
	var sk := _sk
	var sc := _sc
	add_child(PixelArt.pic(sk.panel_settings_tex, sc))
	var h := PixelArt.label("Settings", sk, "bold", sk.pal_cream, true, false, Color(0, 0, 0, 0), 2)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(8, 8 + header_y) * sc
	h.size = Vector2(240 * sc, PixelArt.font_px(sk, "bold", 2))
	add_child(h)
	var rows := [["Volume", 0.0, 1.0], ["Shake", 0.0, shake_max]]
	var sliders := []
	for i in 2:
		var y: int = row_y[i]
		add_child(_name_label(rows[i][0], y))
		var s := _slider(Vector2(8 + groove_x, 8 + y), rows[i][1], rows[i][2])
		var v := PixelArt.label("", sk, "bold", sk.pal_cream)
		v.position = Vector2(8 + groove_x + value_dx, 8 + y) * sc
		add_child(v)
		sliders.append([s, v])
	_volume = sliders[0][0]
	_vol_label = sliders[0][1]
	_shake = sliders[1][0]
	_shake_label = sliders[1][1]
	_volume.value_changed.connect(func(x: float): _changed(func(): GameSettings.master_volume = x))
	_shake.value_changed.connect(func(x: float): _changed(func(): GameSettings.set_shake(get_tree(), x)))
	add_child(_name_label("Fullscreen", row_y.z))
	_fullscreen = Button.new()
	_fullscreen.toggle_mode = true
	_fullscreen.focus_mode = Control.FOCUS_ALL
	_fullscreen.position = Vector2(8 + groove_x, 8 + checkbox_y) * sc
	_fullscreen.size = Vector2(14, 14) * sc
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		_fullscreen.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_fullscreen.draw.connect(_draw_checkbox)
	_fullscreen.toggled.connect(func(on: bool): _changed(func(): GameSettings.fullscreen = on))
	add_child(_fullscreen)
	_back = MenuScreen.make_button("Back", back_art_size)
	_back.position = Vector2(8 + back_pos.x, 8 + back_pos.y) * sc
	_back.pressed.connect(func(): back_pressed.emit())
	add_child(_back)
	refresh()

func _name_label(text: String, y: int) -> Label:
	var l := PixelArt.label(text, _sk, "bold", _sk.pal_out, false)
	l.position = Vector2(8 + label_x, 8 + y) * _sc
	return l

## Slider: a real HSlider (keys, mouse drag) drawn with the baked groove / fill / knob.
func _slider(art_pos: Vector2, lo: float, hi: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.focus_mode = Control.FOCUS_ALL
	s.position = art_pos * _sc
	s.size = Vector2(groove_size) * _sc
	s.custom_minimum_size = s.size
	for st in ["slider", "grabber_area", "grabber_area_highlight"]:
		s.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var none := ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(ic, none)
	s.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	s.draw.connect(func(): _draw_slider(s))
	for sig in [s.mouse_entered, s.mouse_exited, s.focus_entered, s.focus_exited]:
		sig.connect(s.queue_redraw)
	add_child(s)
	return s

func _draw_slider(s: HSlider) -> void:
	var sk := _sk
	var sc := _sc
	var hot: bool = s.has_focus() or Rect2(Vector2.ZERO, s.size).has_point(s.get_local_mouse_position())
	var w := groove_size.x * sc
	s.draw_style_box(_groove, Rect2(0, 0, w, groove_size.y * sc))
	var frac := inverse_lerp(s.min_value, s.max_value, s.value)
	var fill_w := (groove_size.x - 4) * frac
	if fill_w > 0.0:
		s.draw_style_box(_fill_hover if hot and sk.slider_fill_hover_tex != null else _fill, Rect2(2 * sc, 2 * sc, roundf(fill_w) * sc, 4 * sc))
	PixelArt.draw_pic(s, sk.slider_knob_tex, Vector2(2 + roundf(fill_w) - 4, -3) * sc, sc)

func _draw_checkbox() -> void:
	var sk := _sk
	var t: Texture2D = sk.checkbox_on_tex if _fullscreen.button_pressed else sk.checkbox_off_tex
	if (_fullscreen.is_hovered() or _fullscreen.has_focus()) and sk.checkbox_hover_tex != null and not _fullscreen.button_pressed:
		t = sk.checkbox_hover_tex
	PixelArt.draw_pic(_fullscreen, t, Vector2.ZERO, _sc)

func _changed(set_value: Callable) -> void:
	if _syncing:
		return
	set_value.call()
	GameSettings.save_file(get_tree())
	GameSettings.apply()
	_labels()

func _labels() -> void:
	_vol_label.text = "%d%%" % roundi(GameSettings.master_volume * 100.0)
	_shake_label.text = "%d%%" % roundi(_shake.value / shake_max * 100.0)
	for s in [_volume, _shake, _fullscreen]:
		s.queue_redraw()

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
