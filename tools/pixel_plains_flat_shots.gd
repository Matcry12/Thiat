extends SceneTree
## Real-map shots of one Pixel Plains look (all_flat on = default, or off with a 2nd arg "levels"): coast, river bank, snow edge, desert edge, home.
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/pixel_plains_flat_shots.gd -- <out_dir> [levels]
var _out := ""

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	var map: ArenaMap = arena.get_node("ArenaMap")
	if args.size() > 1 and args[1] == "levels":
		map.style.pixel_plains.all_flat = false
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var player: CharacterBody2D = arena.get_node("Player")
	player.get_node("Health").immortal = true
	arena.get_node("Boss").passive = true
	for _f in 12:
		await process_frame
	await _wait(0.8)
	await _shot("home")
	var res := map.result
	var G := MapGen.Ground
	var B := MapGen.Biome
	var home := Vector2i((map.home_point() / map.cell_px()).floor())
	var spots := {
		"coast": func(i: int, n: Array) -> bool: return res.ground[i] == G.SAND and res.biome[i] == B.BEACH_SAND and n.has(G.WATER) and n.has(G.GRASS),
		"river_bank": func(i: int, n: Array) -> bool: return res.ground[i] == G.SAND and not res.shore.is_empty() and res.shore[i] == 1 and n.has(G.GRASS),
		"snow_edge": func(i: int, n: Array) -> bool: return res.ground[i] == G.SNOW and n.has(G.GRASS),
		"desert_edge": func(i: int, n: Array) -> bool: return res.ground[i] == G.SAND and res.biome[i] != B.BEACH_SAND and (res.shore.is_empty() or res.shore[i] == 0) and n.has(G.GRASS) and not n.has(G.WATER),
	}
	for name_ in spots:
		var best := Vector2i(-1, -1)
		var best_d := 1 << 30
		for y in range(4, res.rows - 4, 2):
			for x in range(4, res.cols - 4, 2):
				var i := y * res.cols + x
				var n := []
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						n.append(res.ground[(y + dy) * res.cols + x + dx])
				if spots[name_].call(i, n):
					var d := (Vector2i(x, y) - home).length_squared()
					if d < best_d:
						best_d = d
						best = Vector2i(x, y)
		print(name_, " cell ", best)
		if best.x < 0:
			continue
		player.global_position = (Vector2(best) + Vector2(0.5, 0.5)) * map.cell_px()
		player.get_node("Camera").reset_smoothing()
		await _wait(2.0)
		await _shot(name_)
	quit()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
