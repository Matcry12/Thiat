extends SceneTree
## F3 dock shots: xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/f3_shots.gd -- <out_dir>
## Saves 1_default, 2_bodyrig, 3_search_hand, 4_actions, 5_status, 6_watch_only, 7_map_rebuilt (pinned rows + overrides come from a throw-away cfg file).
var _out := "tools/f3_mock/game_shots"

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name_: String) -> void:
	await _frames(4)
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("DebugOverlay").enabled = false
	await _frames(8)
	var panel = arena.get_node("TuningPanel")
	var dock: F3Dock = panel.dock
	var cfg := "user://f3_shots.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	panel.use_overrides(F3Overrides.new(cfg))
	panel.visible = true
	panel.apply_value("Player.speed", 330.0)          # scene-only override
	panel.apply_value("BodyRig.hand_radius", 5.5)     # can go to .tres
	dock.toggle_pin("BodyRig.hand_radius")
	dock.toggle_pin("Player.speed")
	dock.toggle_pin("BodyRig.hand_idle_front")
	await _frames(60)
	await _shot("1_default")
	dock.open_section("BodyRig")
	await _frames(10)
	await _shot("2_bodyrig")
	dock.set_search("hand")
	await _frames(10)
	await _shot("3_search_hand")
	dock.set_search("")
	dock.show_tab("Actions")
	await _frames(10)
	await _shot("4_actions")
	dock.show_tab("Status")
	panel.status_view.toggle_pin("Engine")
	panel.status_view.toggle_pin("Weapon")
	panel.status_view.toggle_open("Player")
	await _frames(40)
	await _shot("5_status")
	panel.cycle()   # full -> watch only
	await _frames(60)
	await _shot("6_watch_only")
	panel.cycle()
	panel.cycle()   # off -> full
	dock.show_tab("Tune")
	dock.open_section("Map")
	await _frames(10)
	await panel.request_value("Map.land_share", 0.5)
	await _shot("7_map_rebuilt")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
	quit(0)
