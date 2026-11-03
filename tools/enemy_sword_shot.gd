extends SceneTree
## W5 check: the sword and slash draw ABOVE a slime just south of the player.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/enemy_sword_shot.gd -- <out.png>
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
	for n in get_nodes_in_group("map_obstacle"):
		if n.global_position.distance_to(player.global_position) < 300.0:
			n.free()
	var d: EnemyData = load("res://data/enemies/slime.tres")
	var e: Enemy = d.scene.instantiate()
	e.data = d
	arena.get_node("EnemySpawner").add_child(e)
	e.global_position = player.global_position + Vector2(0, 25)
	e.set_physics_process(false)
	player.get_node("Camera").reset_smoothing()
	arena.get_node("DebugOverlay").set("enabled", false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	player.set_physics_process(false)
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var img: Array[Image] = []
	for aim in [Vector2.DOWN, Vector2.UP]:
		for _f in 90:
			await process_frame
		wv.set_aim_angle(aim.angle())
		for _f in 2:
			await process_frame
		holder.try_attack()
		for _f in int(Engine.get_main_loop().get_meta("hit_frame", 12)):
			await process_frame
		img.append(root.get_texture().get_image())
	img[0].save_png(out)
	img[1].save_png(out.replace(".png", "_up.png"))
	# origin markers + one slime 15 px north (behind the player) and one 15 px south (in front)
	var sp: Node = arena.get_node("EnemySpawner")
	var marks := Node2D.new()
	marks.top_level = true
	marks.z_index = 200
	arena.add_child(marks)
	var pts: Array[Vector2] = [player.global_position]
	e.global_position = player.global_position + Vector2(0, 15)
	var e2: Enemy = d.scene.instantiate()
	e2.data = d
	sp.add_child(e2)
	e2.global_position = player.global_position + Vector2(0, -15)
	e2.set_physics_process(false)
	pts.append_array([e.global_position, e2.global_position])
	marks.draw.connect(func():
		for q in pts:
			marks.draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color.RED))
	wv.set_aim_angle(Vector2.RIGHT.angle())
	for _f in 4:
		await process_frame
	marks.queue_redraw()
	await process_frame
	root.get_texture().get_image().save_png(out.replace(".png", "_feet.png"))
	quit(0)
