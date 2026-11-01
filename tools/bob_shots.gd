extends SceneTree
## Loose item float: the same pickups at the bottom and at the top of the bob.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/bob_shots.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	var player: Node2D = arena.get_node("Player")
	player.set_physics_process(false)
	for _f in 20:
		await process_frame
	var pos: Vector2 = player.global_position + Vector2(-120, 0)
	var ids := ["wood", "stone", "copper_ore", "copper_bar", "wooden_sword", "stone_axe"]
	for i in ids.size():
		var at := pos + Vector2(i * 36, 20)
		Pickup.spawn(arena, load("res://data/items/%s.tres" % ids[i]), 1, at, at).scale = Vector2.ONE * 2.0
	arena.get_node("DebugOverlay").set("enabled", false)
	player.get_node("Collector").magnet_radius = 0.0   # leave them lying
	player.get_node("Collector").pickup_radius = 0.0
	for _f in 40:
		await process_frame
	for p in get_nodes_in_group("pickup"):
		p._update_look(0.0)
		p.set_process(false)
	await process_frame
	root.get_texture().get_image().save_png("%s/bob_bottom.png" % out)
	for p in get_nodes_in_group("pickup"):
		p._update_look(1.0)
	await process_frame
	root.get_texture().get_image().save_png("%s/bob_top.png" % out)
	quit(0)
