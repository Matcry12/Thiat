extends SceneTree
## The whole island as the game draws it (Pixel Plains ground + props, default map settings): the camera walks the map in
## VIEW-px steps, each screen is shrunk into one OUT_W-px picture, plus 1:1 crops at home, a forest edge and a coast.
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1024x1024 --script tools/ground_full_map.gd -- <out_dir> [suffix, e.g. _v2]
const VIEW := 1024
const OUT_W := 2048

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var suf: String = args[1] if args.size() > 1 else ""
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var player: CharacterBody2D = arena.get_node("Player")
	player.get_node("Health").immortal = true
	player.set_physics_process(false)
	for c in player.get_children():
		if c is CanvasItem:
			c.visible = false
	arena.get_node("Boss").passive = true
	var map: ArenaMap = arena.get_node("ArenaMap")
	map.chunks_per_frame = 8
	for _f in 12:
		await process_frame
	var res := map.result
	var cp := map.cell_px()
	var size := Vector2(res.cols, res.rows) * cp
	var n := Vector2i((size / VIEW).ceil())
	var small := int(OUT_W / n.x)
	var full := Image.create_empty(n.x * small, n.y * small, false, Image.FORMAT_RGB8)
	var cam: Camera2D = player.get_node("Camera")
	print("seed ", res.seed, " map px ", size, " screens ", n)
	for ty in n.y:
		for tx in n.x:
			var shot := await _shot(player, cam, Vector2(tx + 0.5, ty + 0.5) * VIEW)
			shot.convert(Image.FORMAT_RGB8)
			shot.resize(small, small, Image.INTERPOLATE_LANCZOS)
			full.blit_rect(shot, Rect2i(0, 0, small, small), Vector2i(tx, ty) * small)
	full.save_png("%s/full_map_seed%d%s.png" % [out, res.seed, suf])
	# 1:1 crops: home, the forest edge nearest home, the beach nearest home
	var home := Vector2i((map.home_point() / cp).floor())
	var G := MapGen.Ground
	var B := MapGen.Biome
	var spots := {
		"home": home,
		"forest_edge": _nearest(res, home, func(i: int, nb: Array) -> bool: return res.biome[i] == B.FOREST and nb.has(B.PLAINS)),
		"coast": _nearest(res, home, func(i: int, nb: Array) -> bool: return res.ground[i] == G.SAND and res.biome[i] == B.BEACH_SAND and nb.has(-1)),
	}
	for k in spots:
		print(k, " cell ", spots[k])
		if spots[k].x >= 0:
			(await _shot(player, cam, (Vector2(spots[k]) + Vector2(0.5, 0.5)) * cp)).save_png("%s/full_map_seed%d_%s%s.png" % [out, res.seed, k, suf])
	print("done")
	quit()

func _shot(player: Node2D, cam: Camera2D, at: Vector2) -> Image:
	player.global_position = at
	cam.reset_smoothing()
	await create_timer(0.6).timeout
	_hide_layers(root)
	await process_frame
	return root.get_texture().get_image()

func _nearest(res: MapGen.Result, from: Vector2i, ok: Callable) -> Vector2i:   # nb = biomes of the 7x7 around (-1 = water)
	var best := Vector2i(-1, -1)
	var bd := 1 << 30
	for y in range(4, res.rows - 4, 2):
		for x in range(4, res.cols - 4, 2):
			var d := (Vector2i(x, y) - from).length_squared()
			if d >= bd:
				continue
			var nb := []
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var j := (y + dy) * res.cols + x + dx
					nb.append(-1 if res.ground[j] == MapGen.Ground.WATER else res.biome[j])
			if ok.call(y * res.cols + x, nb):
				bd = d
				best = Vector2i(x, y)
	return best

func _hide_layers(n: Node) -> void:   # HUD, F3, toasts: anything on a CanvasLayer
	if n is CanvasLayer:
		n.visible = false
	for c in n.get_children():
		_hide_layers(c)
