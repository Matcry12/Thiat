extends SceneTree
## W8 shots: title, pause menu, settings (from the pause menu).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/w8_frame_shots.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	GameSettings.path = "user://shots_settings.cfg"
	var title = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	for _f in 5:
		await process_frame
	root.get_texture().get_image().save_png("%s/title.png" % out)
	title.queue_free()
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for _f in 20:
		await process_frame
	var pm: PauseMenu = arena.get_node("PauseMenu")
	pm.pause()
	for _f in 5:
		await process_frame
	root.get_texture().get_image().save_png("%s/pause.png" % out)
	pm.screen().show_settings()
	for _f in 5:
		await process_frame
	root.get_texture().get_image().save_png("%s/settings.png" % out)
	DirAccess.remove_absolute(GameSettings.path)
	quit(0)
