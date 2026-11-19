class_name PauseMenu
extends CanvasLayer
## `Esc` pause (W8, decision 0040). Pauses the whole tree; this layer keeps running (process_mode ALWAYS).
## Esc order: settings page -> back to the list; open bag / crafting window -> close it (no pause);
## otherwise pause / resume. Menu: Resume, Settings, Save & quit.

const TITLE := "res://scenes/title.tscn"

@export var title_text := "Paused"
## Seconds the "Not saved: ..." line shows on the button before quitting to the title.
@export var unsaved_notice_time := 1.2

var _screen: MenuScreen

func _ready() -> void:
	add_to_group("pause_menu")
	add_to_group("debug")
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	GameSettings.ensure_loaded()
	GameSettings.apply()   # an arena started directly still honours the saved settings
	_screen = MenuScreen.new()
	_screen.title_text = title_text
	_screen.style = MenuScreen.Style.PAUSE
	_screen.items = [
		{"text": "Resume", "cb": resume},
		{"text": "Settings", "settings": true},
		{"text": "Save & quit", "cb": quit_to_title},
	]
	_screen.visible = false
	add_child(_screen)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		handle_pause()
		get_viewport().set_input_as_handled()

func is_paused() -> bool:
	return get_tree().paused

func screen() -> MenuScreen:
	return _screen

## What one Esc press does.
func handle_pause() -> void:
	if is_paused():
		if not _screen.back():
			resume()
		return
	var bag := get_tree().get_first_node_in_group("bag_panel")
	if bag != null and bag.is_open():
		bag.close()   # the window closes first; the next Esc pauses
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()
		return
	pause()

func pause() -> void:
	get_tree().paused = true
	get_tree().call_group("hud", "set_paused_view", true)
	_screen.back()
	_screen.visible = true
	_screen.focus_first()

func resume() -> void:
	get_tree().call_group("hud", "set_paused_view", false)
	_screen.visible = false
	get_tree().paused = false

## Saves (when allowed: not dead, boss not engaged) and goes to the title.
func quit_to_title() -> void:
	var sg := get_tree().get_first_node_in_group("save_game") as SaveGame
	var why := sg.save() if sg else ""
	if why != "" and why != "test run" and _screen.button("Save & quit") != null:
		_screen.button("Save & quit").text = "Not saved: " + why   # quit anyway, but say so first
		await get_tree().create_timer(unsaved_notice_time, true, false, true).timeout
	get_tree().paused = false
	Engine.time_scale = 1.0   # F2 slow-mo must not follow you to the title
	if get_tree().current_scene != null:   # null in a headless test
		get_tree().change_scene_to_file(TITLE)

func status_text() -> String:
	return "paused: %s  page: %s\n%s" % ["YES" if is_paused() else "no", "settings" if _screen.on_settings_page() else ("menu" if _screen.visible else "-"), GameSettings.status_text(get_tree())]


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Frame"

func debug_category() -> String:
	return "Run"
