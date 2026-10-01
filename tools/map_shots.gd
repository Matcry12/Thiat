extends SceneTree
## Saves one PNG of the arena per seed: xvfb-run -a godot --rendering-driver opengl3 \
##   --resolution 1152x648 --script tools/map_shots.gd -- <out_dir> <seed> [<seed> ...] [--behind]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	var behind := args.has("--behind")   # stand the player just behind the first tall rock
	for i in range(1, args.size()):
		if args[i] == "--behind":
			continue
		arena.get_node("ArenaMap").map_seed = int(args[i])
		for _f in 4:
			await process_frame
		if behind:
			arena.get_node("Player").set_physics_process(false)
			for r in get_nodes_in_group("map_obstacle"):
				if r.get_child(0).shape.radius >= 22.0:
					arena.get_node("Player").global_position = r.global_position + Vector2(0, -36)
					break
			await process_frame
			await process_frame
		root.get_texture().get_image().save_png("%s/map_%s.png" % [args[0], args[i]])
	quit(0)
