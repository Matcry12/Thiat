class_name F3WatchCard
extends PanelContainer
## Click-through card at the top of the screen: the pinned status blocks + "N F3 overrides".
## The parent places it (set_span); it never takes the mouse.

@export var top := 8.0
@export var min_left := 480.0           # right of the hotbar
@export var max_width := 268.0
@export var font_size := 11
@export var name_color := "#8fb8ff"
@export var override_color := "#e6b450"
@export var bg_color := Color(0.047, 0.055, 0.07, 0.82)
@export var border_color := Color("2a303b")
@export var text_color := Color("c4cdd9")
@export var max_lines_per_block := 3

var _label := RichTextLabel.new()
var _blocks: Array = []
var _overrides := 0

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = border_color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	add_theme_stylebox_override("panel", sb)
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("normal_font_size", font_size)
	_label.add_theme_font_size_override("bold_font_size", font_size)
	_label.add_theme_color_override("default_color", text_color)
	_label.custom_minimum_size.x = max_width - 18
	add_child(_label)
	_ignore_mouse(self)
	_redraw()

## Place between the hotbar and the dock: left edge at max(min_left, ...), never past `right_limit`.
func set_span(right_limit: float) -> void:
	var w := minf(max_width, right_limit - min_left - 8.0)
	position = Vector2(min_left, top)
	custom_minimum_size.x = w
	size.x = w
	_label.custom_minimum_size.x = w - 18

func set_blocks(blocks: Array) -> void:   # [{name, text}]
	_blocks = blocks
	_redraw()

func set_override_count(n: int) -> void:
	_overrides = n
	_redraw()

func shown_text() -> String:
	return _label.get_parsed_text()

func _redraw() -> void:
	if not is_node_ready():
		return
	var t := ""
	for b in _blocks:
		var lines: PackedStringArray = str(b.text).split("\n")
		t += "[color=%s][b]%s[/b][/color] %s\n" % [name_color, b.name, "\n  ".join(lines.slice(0, max_lines_per_block))]
	if _overrides > 0:
		t += "[color=%s]● %d F3 overrides[/color]\n" % [override_color, _overrides]
	t = t.strip_edges()
	_label.text = t
	visible = t != ""
	reset_size.call_deferred()

func _ignore_mouse(n: Node) -> void:
	if n is Control:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		_ignore_mouse(c)
