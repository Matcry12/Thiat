class_name F3WatchCard
extends PanelContainer
## Click-through card at the top of the screen: the pinned status blocks + "N F3 overrides".
## The parent places it (set_span); it never takes the mouse.

@export var top := 8.0
@export var min_left := 480.0           # right of the hotbar
@export var max_width := 268.0
@export var name_color := "#f4c84c"     # GOLDTXT: the block name
@export var override_color := "#f4c84c"
@export var text_color := Color8(252, 242, 222)
@export var max_lines_per_block := 3
@export var text_size := 14

var _label := RichTextLabel.new()
var _blocks: Array = []
var _overrides := 0

func _ready() -> void:
	theme_type_variation = "F3Note"   # a dark note pinned with a nail (the dock's theme is set by the TuningPanel)
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for f in ["normal_font_size", "bold_font_size"]:
		_label.add_theme_font_size_override(f, text_size)
	_label.add_theme_color_override("default_color", text_color)
	_label.add_theme_constant_override("line_separation", 4)
	_label.custom_minimum_size.x = max_width - 44
	add_child(_label)
	_ignore_mouse(self)
	_redraw()

func _draw() -> void:
	F3Theme.draw_nail(self)

## Place between the hotbar and the dock: left edge at max(min_left, ...), never past `right_limit`.
func set_span(right_limit: float) -> void:
	var w := minf(max_width, right_limit - min_left - 8.0)
	position = Vector2(min_left, top)
	custom_minimum_size.x = w
	size.x = w
	_label.custom_minimum_size.x = w - 44

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
