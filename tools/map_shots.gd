extends SceneTree
## Saves one PNG of the arena per seed: xvfb-run -a godot --rendering-driver opengl3 \
##   --resolution 1152x648 --script tools/map_shots.gd -- <out_dir> <seed> [<seed> ...] [--behind]
## With --big it saves overview.png (the whole map, zoomed out, F1 zone visible) and ingame.png
## (the normal player camera, standing at the edge of the boss zone) for the first seed.
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	if args.has("--big"):
		await _big(arena, args)
		return
	var behind := args.has("--behind")   # stand the player just behind the first tall rock
	for i in range(1, args.size()):
		if args[i] == "--behind" or args[i] == "--big":
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


func _big(arena: Node, args: PackedStringArray) -> void:
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	var player: Node2D = arena.get_node("Player")
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_seed = int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 7
	for _f in 6:
		await process_frame
	# Overview: a camera that sees the whole map (the screen is 1152 wide, the map 2304).
	var cam := Camera2D.new()
	var size := m.map_size()
	cam.position = size * 0.5
	cam.zoom = Vector2.ONE * minf(1152.0 / size.x, 648.0 / size.y)
	arena.add_child(cam)
	cam.make_current()
	for _f in 4:
		await process_frame
	root.get_texture().get_image().save_png("%s/overview.png" % args[0])
	# Normal view: the player's own camera, at the edge of the zone with the boss in sight.
	cam.queue_free()
	player.get_node("Camera").make_current()
	player.global_position = Vector2(1330, 640)
	player.get_node("Camera").reset_smoothing()
	for _f in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/ingame.png" % args[0])
	quit(0)
