extends SceneTree
## One screen around home exactly as the player sees it (default window 1152x648, camera_zoom from ArenaMap; HUD hidden).
## Extra args `name=value` set ArenaMap exports before the map is built (e.g. older map settings for a before / after pair);
## `biome=<label>` instead looks at the land cell of that biome nearest home (e.g. biome=rocky for the dry biome).
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/ground_home_view.gd -- <out.png> [name=value ...]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var arena = load("res://scenes/arena.tscn").instantiate()
	var map: ArenaMap = arena.get_node("ArenaMap")
	var biome := ""
	for kv in args.slice(1):
		var parts: PackedStringArray = kv.split("=")
		if parts[0] == "biome":
			biome = parts[1]
		else:
			map.set(parts[0], str_to_var(parts[1]))
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	arena.get_node("Player").get_node("Health").immortal = true
	arena.get_node("Boss").passive = true
	for _f in 12:
		await process_frame
	if biome != "":
		var res := map.result
		var home := Vector2i((map.home_point() / map.cell_px()).floor())
		var best := Vector2i(-1, -1)
		var bd := 1 << 30
		for y in range(6, res.rows - 6, 2):
			for x in range(6, res.cols - 6, 2):
				var i := y * res.cols + x
				var d := (Vector2i(x, y) - home).length_squared()
				if d < bd and res.land[i] == 1 and res.biomes[res.biome[i]].label == biome and res.biomes[res.biome[y * res.cols + x - 5]].label == biome and res.biomes[res.biome[y * res.cols + x + 5]].label == biome:
					bd = d
					best = Vector2i(x, y)
		print(biome, " cell ", best)
		var player: Node2D = arena.get_node("Player")
		player.global_position = (Vector2(best) + Vector2(0.5, 0.5)) * map.cell_px()
		player.get_node("Camera").reset_smoothing()
	await create_timer(1.5).timeout
	_hide_layers(root)
	await process_frame
	root.get_texture().get_image().save_png(args[0])
	quit()

func _hide_layers(n: Node) -> void:
	if n is CanvasLayer:
		n.visible = false
	for c in n.get_children():
		_hide_layers(c)
