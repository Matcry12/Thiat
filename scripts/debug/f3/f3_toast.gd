class_name F3Toast
extends PanelContainer
## Short message, top-centre of the game area (left of the dock), as a dark note pinned with a nail. Mouse passes through.
## Sits below the watch card row and far above the bottom-centre boss bar. The look is the theme's (F3Note); `theme` is the dock's.

@export var default_seconds := 4.0
@export var top := 136.0                # below the watch card (top 8 + ~120)
@export var max_width := 420.0
@export var text_color := Color8(252, 242, 222)

var _label := Label.new()
var _left := 0.0

func _ready() -> void:
	theme_type_variation = "F3Note"
	_label.theme_type_variation = "F3Small"
	_label.add_theme_color_override("font_color", text_color)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = max_width - 44
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _draw() -> void:
	F3Theme.draw_nail(self)

func show_toast(text: String, seconds := -1.0, dock_width := 0.0) -> void:
	_label.text = text
	_label.custom_minimum_size.x = minf(max_width, get_viewport_rect().size.x - dock_width - 40.0) - 44.0
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
