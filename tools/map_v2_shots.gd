extends SceneTree
## Map look shots (decision 0033): the whole island plus game-zoom views of the coast, a forest -> rocky
## border, home and the boss area. HUD hidden. Same seed = same island.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/map_v2_shots.gd -- <out_dir> <prefix> [seed] [style .tres]
## Saves <prefix>_overview.png, <prefix>_coast.png, <prefix>_border.png, <prefix>_home.png, <prefix>_boss.png
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var prefix := args[1]
	var seed_v := int(args[2]) if args.size() > 2 else 11
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for n in ["HUD", "DebugOverlay", "TuningPanel", "EndScreen"]:
		var l = arena.get_node_or_null(n)
		if l:
			l.layer = -128   # behind the world: hidden (the HUD script toggles `visible` itself)
	var m: ArenaMap = arena.get_node("ArenaMap")
	if args.size() > 3 and args[3] != "--dim":
		m.style = load(args[3])   # a style file, e.g. res://data/maps/grass_pc.tres
	if args.has("--dim"):   # the dimmer ground that was tried: 0.8 / 0.85
		m.ground_brightness = 0.8
		m.ground_saturation = 0.85
	m.map_seed = seed_v
	m._apply_pending_now()
	var player: Node2D = arena.get_node("Player")
	player.set_physics_process(false)
	for _f in 8:
		await process_frame
	arena.get_node("HUD")._layer.visible = false   # the HUD builds its own CanvasLayer
	print("build_ms ", m.build_ms)
	var r := m.result
	var cell := m.cell_px()
	var home := Vector2i(m.home_point() / cell)
	# coast: walk west along home's row until water
	var coast := home
	for x in range(home.x, 0, -1):
		if r.land[home.y * r.cols + x] == 0:
			coast = Vector2i(x + 1, home.y)
			break
	# border: walk east along home's row until the forest ends
	var border := home
	for x in range(home.x, r.cols):
		var i := home.y * r.cols + x
		if r.land[i] == 1 and r.area[i] == MapGen.Area.ROCKY:
			border = Vector2i(x, home.y)
			break
	var spots := {
		"coast": (Vector2(coast) + Vector2(0.5, 0.5)) * cell,
		"border": (Vector2(border) + Vector2(0.5, 0.5)) * cell,
		"home": m.home_point() + Vector2(60, 20),
		"boss": Vector2(m._zone.position.x + 60.0, m._zone.get_center().y),
	}
	for k in spots:
		player.global_position = spots[k]
		player.get_node("Camera").reset_smoothing()
		for _f in 6:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, prefix, k])
	var cam := Camera2D.new()
	var size := m.map_size()
	cam.position = size * 0.5
	cam.zoom = Vector2.ONE * minf(root.size.x / size.x, root.size.y / size.y)
	arena.add_child(cam)
	cam.make_current()
	for _f in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s_overview.png" % [out, prefix])
	quit(0)
