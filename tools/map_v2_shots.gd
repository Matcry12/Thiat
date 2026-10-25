extends SceneTree
## Map look shots (decision 0033): the whole island plus game-zoom views of the coast, a forest -> rocky
## border, home and the boss area. HUD hidden. Same seed = same island.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1920x1080 --script tools/map_v2_shots.gd -- <out_dir> <prefix> [seed] [style .tres] [--dim] [--ground-only] [--grass-only] [--biome-map]
## Flags: --dim (ground 0.8 / 0.85), --ground-only (no trees, rocks, plants, bushes, boss), --grass-only (no paths, no camp), --biome-map (the F3 biome colour layer on),
## The overview force-loads EVERY chunk first (m.load_all_chunks(), 0038 step 2): the island is chunks now, so the whole-island
## picture needs them all. At 512 x 512 that is 256 chunks (a few seconds, a few hundred MB): fine for a tool, never done in the game.
## --spot <name> (0038 step 4): only that view (coast border home boss river lake, or a biome: plains forest autumn taiga snowy rocky swamp = the
## cell of that biome nearest home whose 7x7 neighbourhood is all that biome), no overview. A biome spot is shot at the game zoom.
## Saves <prefix>_overview.png, <prefix>_coast.png, <prefix>_border.png, <prefix>_home.png, <prefix>_boss.png, <prefix>_river.png, <prefix>_lake.png (0038 step 3: the river / lake cell nearest to home)
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
	if args.size() > 3 and not args[3].begins_with("--"):
		m.style = load(args[3])   # a style file, e.g. res://data/maps/grass.tres
	if args.has("--dim"):   # the dimmer ground that was tried: 0.8 / 0.85
		m.ground_brightness = 0.8
		m.ground_saturation = 0.85
	if args.has("--grass-only"):   # no paths or camp (the area sliders are gone with 0038: the biomes decide the ground)
		m.path_on = false
		m.camp_radius = 0
	if args.has("--biome-map"):
		m.biome_map_on = true
	m.map_seed = seed_v
	m._apply_pending_now()
	var player: Node2D = arena.get_node("Player")
	player.set_physics_process(false)
	for _f in 8:
		await process_frame
	arena.get_node("HUD")._layer.visible = false   # the HUD builds its own CanvasLayer
	if args.has("--ground-only"):   # ground look alone: no trees, rocks, plants, bushes, boss
		for n in ["ArenaMap/Ground/Deco", "ArenaMap/Ground/Border", "ArenaMap/Obstacles", "Boss", "Dummy"]:
			arena.get_node(n).visible = false
	print("build_ms ", m.build_ms, " (world data ", m.gen_ms, ", first chunks ", m.bake_ms, ")")
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
		if r.land[i] == 1 and r.biome[i] == MapGen.Biome.ROCKY:
			border = Vector2i(x, home.y)
			break
	var wet := {1: Vector2i(-1, -1), 2: Vector2i(-1, -1)}   # fresh kind -> the cell of that kind nearest to home
	var wet_d := {1: INF, 2: INF}
	for i in r.fresh.size():
		var k: int = r.fresh[i]
		if k != 0:
			var c := Vector2i(i % r.cols, i / r.cols)
			if Vector2(c).distance_to(Vector2(home)) < wet_d[k]:
				wet_d[k] = Vector2(c).distance_to(Vector2(home))
				wet[k] = c
	var spots := {
		"coast": (Vector2(coast) + Vector2(0.5, 0.5)) * cell,
		"border": (Vector2(border) + Vector2(0.5, 0.5)) * cell,
		"home": m.home_point() + Vector2(60, 20),
		"boss": Vector2(m._zone.position.x + 60.0, m._zone.get_center().y),
	}
	if wet[1].x >= 0:
		spots["river"] = (Vector2(wet[1]) + Vector2(0.5, 0.5)) * cell
	if wet[2].x >= 0:
		spots["lake"] = (Vector2(wet[2]) + Vector2(0.5, 0.5)) * cell
	var want := args[args.find("--spot") + 1] if args.has("--spot") else ""
	var labels: Array[String] = ["plains", "forest", "autumn", "taiga", "snowy", "rocky", "swamp"]
	for bi in labels.size():   # the interior cell of each biome nearest home (stride 2 keeps it quick)
		if want != "" and want != labels[bi]:
			continue
		var best := Vector2i(-1, -1)
		var best_d := INF
		for y in range(3, r.rows - 3, 2):
			for x in range(3, r.cols - 3, 2):
				var d := Vector2(x, y).distance_to(Vector2(home))
				if d >= best_d or r.biome[y * r.cols + x] != bi or r.land[y * r.cols + x] == 0:
					continue
				var inside := true
				for dy in range(-3, 4):
					for dx in range(-3, 4):
						var j := (y + dy) * r.cols + x + dx
						inside = inside and r.land[j] == 1 and r.biome[j] == bi
				if inside:
					best = Vector2i(x, y)
					best_d = d
		if best.x >= 0:
			spots[labels[bi]] = (Vector2(best) + Vector2(0.5, 0.5)) * cell
	if want != "":
		var only: Vector2 = spots.get(want, Vector2.ZERO)
		spots = {want: only} if spots.has(want) else {}
	if args.has("--zoom"):   # camera zoom test (1.0 = game now)
		player.get_node("Camera").zoom = Vector2.ONE * float(args[args.find("--zoom") + 1])
	for k in spots:
		player.global_position = spots[k]
		player.get_node("Camera").reset_smoothing()
		for _f in 6:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s_%s.png" % [out, prefix, k])
	if want != "":
		quit(0)
		return
	var t_all := Time.get_ticks_msec()
	m.load_all_chunks()
	print("all %d chunks loaded in %d ms" % [m.streamer().chunk_count(), Time.get_ticks_msec() - t_all])
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
