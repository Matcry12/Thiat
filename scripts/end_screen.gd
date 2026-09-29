extends CanvasLayer
class_name EndScreen
## Throwaway "you died / boss defeated" label + R to retry (prototype-v0 §4:
## UI is disposable). One of the only two places that reads Input (with
## player.gd); it reloads the arena.

signal retry_requested

@export var player_path: NodePath
@export var boss_path: NodePath
@export var lose_text := "You died — R to retry"
@export var win_text := "Boss defeated — R to retry"

var _label: Label

func _ready() -> void:
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 40)
	_label.visible = false
	add_child(_label)
	var ph := get_node_or_null(player_path)
	if ph and ph.get_node_or_null("Health"):
		ph.get_node("Health").died.connect(func(): _show(lose_text))
	var bh := get_node_or_null(boss_path)
	if bh and bh.get_node_or_null("Health"):
		bh.get_node("Health").died.connect(func(): _show(win_text))

func _show(text: String) -> void:
	# The first ending wins: a boss that dies after you did is still your death.
	if not _label.visible:
		_label.text = text
		_label.visible = true

func is_showing() -> bool:
	return _label.visible

func label_text() -> String:
	return _label.text

func _process(_delta: float) -> void:
	if _label.visible and Input.is_action_just_pressed("restart"):
		retry_requested.emit()
		if get_tree().current_scene != null:   # null in a headless test
			get_tree().reload_current_scene()
