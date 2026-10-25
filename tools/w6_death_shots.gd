extends SceneTree
## W6 shot: the death spray (items popping out of the corpse, then lying on the ground).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/w6_death_shots.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	var player: Node2D = arena.get_node("Player")
	for _f in 20:
		await process_frame
	var inv: Inventory = player.get_node("Inventory")
	inv.give_dev_kit()
	for id in ["wood", "stone", "copper_ore", "copper_bar"]:
		inv.add(load("res://data/items/%s.tres" % id), 40)
	var rs: Respawner = player.get_node("Respawner")
	rs.respawn_delay = 999.0
	player.global_position += Vector2(120, 40)
	player.get_node("Camera").reset_smoothing()
	arena.get_node("DebugOverlay").set("enabled", false)
	for _f in 5:
		await process_frame
	rs.kill()
	for _f in 14:   # mid-air
		await process_frame
	root.get_texture().get_image().save_png("%s/death_spray_air.png" % out)
	for _f in 50:
		await process_frame
	root.get_texture().get_image().save_png("%s/death_spray_landed.png" % out)
	quit(0)
