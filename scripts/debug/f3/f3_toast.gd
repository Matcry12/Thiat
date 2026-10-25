class_name F3Toast
extends PanelContainer
## Short message, top-centre of the game area (left of the dock). Mouse passes through.
## Sits below the watch card row and far above the bottom-centre boss bar.

@export var default_seconds := 4.0
@export var top := 112.0                # below the watch card (top 8 + ~90)
@export var max_width := 420.0
@export var font_size := 12
@export var bg_color := Color("12141a")
@export var border_color := Color("e6b450")
@export var text_color := Color("e6e9ef")

var _label := Label.new()
var _left := 0.0

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	add_theme_stylebox_override("panel", sb)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", text_color)
	_label.custom_minimum_size.x = max_width - 20
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_toast(text: String, seconds := -1.0, dock_width := 0.0) -> void:
	_label.text = text
	_label.custom_minimum_size.x = minf(max_width, get_viewport_rect().size.x - dock_width - 40.0) - 20.0
	size = Vector2.ZERO
	var area := get_viewport_rect().size.x - dock_width
	reset_size()
	position = Vector2((area - size.x) * 0.5, top)
	_left = default_seconds if seconds < 0.0 else seconds
	visible = true

func _process(delta: float) -> void:
	if visible:
		_left -= delta
		if _left <= 0.0:
			visible = false
