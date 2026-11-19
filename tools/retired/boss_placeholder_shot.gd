extends SceneTree
## Boss stand-in look, one frame mid-telegraph.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/boss_placeholder_shot.gd -- <out.png>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Node2D = arena.get_node("Boss")
	var player: Node2D = arena.get_node("Player")
	for _f in 20:
		await process_frame
	player.global_position = boss.global_position + Vector2(150, 0)
	player.get_node("Camera").global_position = boss.global_position
	player.get_node("Camera").reset_smoothing()
	boss.force_next("slam")
	for _f in 25:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit(0)
