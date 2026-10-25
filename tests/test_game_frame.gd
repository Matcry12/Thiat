extends SceneTree
# W8 (decision 0040): settings file round trip, Esc order (settings page -> window -> pause), the pause menu,
# settings applied live (shake -> CameraShake), title screen (Continue greyed). Arena loaded directly still works.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _esc() -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame

func _init() -> void:
	GameSettings.path = "user://test_settings.cfg"
	GameSettings.force_io = true   # this test is about the file itself
	DirAccess.remove_absolute(GameSettings.path)
	GameSettings.master_volume = 0.35
	GameSettings.shake_strength = 0.4
	GameSettings.fullscreen = false
	GameSettings.save_file(self)
	GameSettings.master_volume = 1.0
	GameSettings.shake_strength = 1.0
	GameSettings.load_file()
	_check(is_equal_approx(GameSettings.master_volume, 0.35) and is_equal_approx(GameSettings.shake_strength, 0.4), "settings file round trip")

	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var pm: PauseMenu = arena.get_node("PauseMenu")
	var fx = arena.get_node("HitFx")
	_check(is_equal_approx(fx.shake.shake_strength, 0.4), "saved shake strength reaches CameraShake on arena start")
	_check(not paused and not pm.screen().visible, "arena starts unpaused")

	await _esc()
	_check(paused and pm.screen().visible, "Esc pauses and shows the menu")
	await _esc()
	_check(not paused and not pm.screen().visible, "Esc again resumes")

	var bag = arena.get_tree().get_first_node_in_group("bag_panel")
	bag.toggle()
	_check(bag.is_open(), "bag open")
	await _esc()
	_check(not bag.is_open() and not paused, "Esc closes an open window first, no pause")
	await _esc()
	_check(paused, "the next Esc pauses")

	pm.screen().show_settings()
	_check(pm.screen().on_settings_page(), "settings page open")
	await _esc()
	_check(paused and not pm.screen().on_settings_page(), "Esc on the settings page goes back to the list, still paused")
	pm.screen().show_settings()
	var sp: SettingsPanel = pm.screen().settings_panel()
	sp.shake_slider().value = 0.0
	sp.volume_slider().value = 0.5
	_check(fx.shake.shake_strength == 0.0, "shake slider writes the live CameraShake (0 = off)")
	_check(is_equal_approx(GameSettings.master_volume, 0.5), "volume slider -> setting")
	GameSettings.master_volume = 1.0
	GameSettings.load_file()
	_check(GameSettings.shake_strength == 0.0 and is_equal_approx(GameSettings.master_volume, 0.5), "slider changes were saved to the file")
	fx.shake.shake_strength = 0.7   # an F3 tune must survive moving another slider and reopening settings
	sp.volume_slider().value = 0.6
	pm.screen().back()
	pm.screen().show_settings()
	_check(is_equal_approx(fx.shake.shake_strength, 0.7) and is_equal_approx(sp.shake_slider().value, 0.7), "F3 shake tune survives a volume change and reopening settings")
	_check(pm.status_text().contains("paused: YES"), "F3 status shows paused")
	pm.screen().back()
	pm.screen().button("Resume").pressed.emit()
	_check(not paused, "Resume button unpauses")
	pm.pause()
	Engine.time_scale = 0.25
	pm.quit_to_title()
	_check(not paused and Engine.time_scale == 1.0, "Quit to title unpauses and resets time scale")

	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	_check(title.button("Continue").disabled and not title.button("Play").disabled and title.button("Settings") != null and title.button("Quit") != null, "title: Play / Settings / Quit enabled, Continue greyed")
	title.button("Settings").pressed.emit()
	_check(title.on_settings_page(), "title Settings opens the shared panel")

	DirAccess.remove_absolute(GameSettings.path)
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
