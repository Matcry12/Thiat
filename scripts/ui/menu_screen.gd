class_name MenuScreen
extends Control
## A full-screen menu page (W8, decision 0040): dim background, title, a list of buttons, and the shared
## SettingsPanel that swaps in when "Settings" is chosen. Used by the title screen and the pause menu.
## Placeholder look: plain controls, every size / colour an export, so a real skin is a swap (CLAUDE.md §5).
## `items`: Array of {text, cb (Callable), enabled (bool, default true)}; {text, settings: true} opens the settings page.

@export var title_text := "BossFight"
@export var title_size := 72
@export var font_size := 26
@export var button_min_size := Vector2(300, 52)
@export var button_gap := 12
@export var background_color := Color(0.06, 0.08, 0.12, 1.0)
@export var title_color := Color(1.0, 0.9, 0.55)
@export var column_gap := 28

var items: Array = []
var _list: VBoxContainer
var _settings: SettingsPanel
var _title: Label
var _buttons := {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = background_color
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", column_gap)
	center.add_child(col)
	_title = Label.new()
	_title.text = title_text
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", title_size)
	_title.add_theme_color_override("font_color", title_color)
	col.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", button_gap)
	col.add_child(_list)
	for it in items:
		_add_button(it["text"], show_settings if it.get("settings", false) else it["cb"], it.get("enabled", true))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.back_pressed.connect(back)
	col.add_child(_settings)
	if is_visible_in_tree():
		focus_first()

func _add_button(text: String, cb: Callable, enabled: bool) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = button_min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(cb)
	_list.add_child(b)
	_buttons[text] = b

func button(text: String) -> Button:
	return _buttons.get(text)

func show_settings() -> void:
	_list.visible = false
	_settings.visible = true
	_settings.refresh()

## Keyboard focus on the first enabled button (call when the list is shown).
func focus_first() -> void:
	for b in _list.get_children():
		if not (b as Button).disabled:
			b.grab_focus()
			return

## Settings page -> button list. Returns false when it was already on the list (nothing to go back from).
func back() -> bool:
	if not _settings.visible:
		return false
	_settings.visible = false
	_list.visible = true
	if is_visible_in_tree():
		focus_first()
	return true

func on_settings_page() -> bool:
	return _settings != null and _settings.visible

func settings_panel() -> SettingsPanel:
	return _settings
