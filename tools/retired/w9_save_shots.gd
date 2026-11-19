extends SceneTree
## W9 shots: the same spot before saving and after a Continue-style load (a furnace, a death drop, a felled tree).
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/w9_save_shots.gd -- <out_dir>
func _frames(n: int) -> void:
	for _f in n:
		await process_frame

func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	SaveGame.path = "user://shots_save.json"
	SaveGame.force_io = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").map_seed = 11
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await _frames(20)
	var m: ArenaMap = arena.get_node("ArenaMap")
	var player: CharacterBody2D = arena.get_node("Player")
	player.set_physics_process(false)
	var spot := m.home_point() + Vector2(110, 60)
	m.teleport_player(spot)
	var it: ItemData = load("res://data/items/furnace.tres")
	var st: Station = it.placeable.instantiate()
	st.item = it
	arena.add_child(st)
	st.global_position = spot + Vector2(90, -20)
	var drop := Pickup.spawn(arena, load("res://data/items/wood.tres"), 6, spot + Vector2(-90, 10), spot + Vector2(-90, 10))
	drop.death_drop = true
	drop.despawn_left = 200.0
	var best := -1
	var best_d := 1e9
	for i in m.result.obstacles.size():
		var o: Dictionary = m.result.obstacles[i]
		if o["node"] >= 0 and m._streamer.node_of(i) != null and o["pos"].distance_to(spot) < best_d and o["pos"].distance_to(spot) > 60.0:
			best = i
			best_d = o["pos"].distance_to(spot)
	m.mark_broken(best)
	arena.get_node("DebugOverlay").set("enabled", false)
	await _frames(15)
	root.get_texture().get_image().save_png("%s/before_save.png" % out)
	print("save: '", arena.get_node("SaveGame").save(), "'")
	arena.queue_free()
	await _frames(3)
	SaveGame.begin_load(SaveGame.read_save())
	var arena2 = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena2)
	arena2.get_node("Boss").passive = true
	arena2.get_node("Player").set_physics_process(false)
	arena2.get_node("DebugOverlay").set("enabled", false)
	await _frames(30)
	root.get_texture().get_image().save_png("%s/after_load.png" % out)
	SaveGame.delete_save()
	quit(0)
