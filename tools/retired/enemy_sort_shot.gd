extends SceneTree
## W5 check: a slime north of a tree trunk must be hidden by the canopy, one south must be in front.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/enemy_sort_shot.gd -- <out.png>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("EnemySpawner").enabled = false
	var player: Node2D = arena.get_node("Player")
	for _f in 20:
		await process_frame
	var best: ResourceNode
	for n: ResourceNode in get_nodes_in_group("resource_node"):
		if str(n.data.id).begins_with("tree") and (best == null or n.data.radius > best.data.radius) and n.global_position.distance_to(player.global_position) < 500.0:
			best = n
	if best == null:
		print("no tree near the player")
		quit(1)
		return
	var base := best.global_position
	print("tree ", best.data.id, " at ", base, " parent ", best.get_parent().get_path(), " z ", best.z_index)
	var d: EnemyData = load("res://data/enemies/slime.tres")
	for off in [Vector2(0, -20), Vector2(26, 22)]:
		var e: Enemy = d.scene.instantiate()
		e.data = d
		arena.get_node("EnemySpawner").add_child(e)
		e.global_position = base + off
		e.set_physics_process(false)
	player.global_position = base + Vector2(0, 60)
	player.get_node("Camera").global_position = base
	player.get_node("Camera").reset_smoothing()
	arena.get_node("DebugOverlay").set("enabled", false)
	for _f in 6:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit(0)
