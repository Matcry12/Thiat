extends SceneTree
## Water edge shots: the player on drawn sand 2 px from the water line (dry look) and in the shallow water past it (wet look).
##   godot --resolution 1152x648 --script tools/water_edge_shots.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	var m: ArenaMap = arena.get_node("ArenaMap")
	m.map_seed = 11
	m.map_cols = 200
	m.map_rows = 120
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var res := m.result
	var pp := m.style.pixel_plains
	var ps := float(m.style.pixel_scale)
	var t := pp.tile_size
	var sand := Vector2.ZERO
	for i in res.land.size():   # same pick as tests/test_water_edge.gd: a shallow cell whose drawn sand reaches >= 2 art px into it
		var c := Vector2i(i % res.cols, i / res.cols)
		if c.x < 4 or c.y < 4 or c.x > res.cols - 5 or c.y > res.rows - 5 or res.shallow[i] != 1 or res.land[i - 1] != 1 or res.shallow[i + 1] != 1 or res.ground[i - 1] != MapGen.Ground.SAND:
			continue
		var ay := c.y * t + t / 2
		var edge := -1
		for ax in range(c.x * t, (c.x + 2) * t):
			if not PixelPlainsBaker.drawn_land_at(res, pp, Vector2i(ax, ay)):
				break
			edge = ax
		if edge < c.x * t + 1 or edge >= (c.x + 1) * t - 4:
			continue
		var s := Vector2((edge + 1) * ps - 2.0, (ay + 0.5) * ps)
		var clear := true
		for o in res.obstacles:
			if s.distance_to(o["pos"]) < 120.0:
				clear = false
				break
		if clear:
			sand = s
			break
	var player: Node2D = arena.get_node("Player")
	arena.get_node("DebugOverlay").set("enabled", false)
	var cam: Camera2D = player.get_node("Camera")
	m.zoom_max = 3.0
	m.camera_zoom = 3.0
	for shot in [["water_edge_dry.png", sand], ["water_edge_wet.png", sand + Vector2(12, 0)]]:
		player.global_position = shot[1]
		cam.reset_smoothing()
		for _f in 20:
			await process_frame
		var sw: Swimmer = player.get_node("Swimmer")
		print("%s at %s: %s" % [shot[0], shot[1], sw.status_text()])
		root.get_texture().get_image().save_png("%s/%s" % [out, shot[0]])
	quit(0)
