extends SceneTree
## W6 shot: a death bag on the ground beside the player (F1 on shows its pickup circle).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/w6_death_shots.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("ArenaMap").map_seed = 11
	arena.get_node("Boss").passive = true
	var player: Node2D = arena.get_node("Player")
	player.set_physics_process(false)
	for _f in 20:
		await process_frame
	var inv: Inventory = player.get_node("Inventory")
	inv.add(load("res://data/items/wood.tres"), 30)
	inv.add(load("res://data/items/stone.tres"), 12)
	var rs: Respawner = player.get_node("Respawner")
	rs.fade_time = 0.0
	player.global_position += Vector2(120, 40)   # step away from home so the bag is not on the campfire
	var spot: Vector2 = player.global_position
	rs.kill()
	rs.respawn_delay = 999.0
	await process_frame
	player.dead = false   # shot only: stand next to the bag without collecting it (Collector skips while dead)
	player.global_position = spot + Vector2(-70, 20)
	player.get_node("Collector").set_physics_process(false)
	player.get_node("Camera").reset_smoothing()
	arena.get_node("DebugOverlay").set("enabled", false)
	for _f in 15:
		await process_frame
	root.get_texture().get_image().save_png("%s/death_bag.png" % out)
	arena.get_node("DebugOverlay").set("enabled", true)
	for _f in 5:
		await process_frame
	root.get_texture().get_image().save_png("%s/death_bag_f1.png" % out)
	quit(0)
