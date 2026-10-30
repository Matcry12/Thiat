extends SceneTree
## Pixel Plains trees / flowers / tufts / hedges in the real arena, one labelled shot per biome at camera zoom 2 (pack pixel = 4 screen px).
## The spot = the cell of that biome with the most plants within 6 cells. CASE_OUT=<out_dir> BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/pixel_plains_veg_shots.gd
const WANT := ["plains", "forest", "autumn", "swamp", "snowy", "rocky"]

func _init() -> void:
	var out := OS.get_environment("CASE_OUT")
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var player: CharacterBody2D = arena.get_node("Player")
	player.get_node("Health").immortal = true
	arena.get_node("Boss").passive = true
	var map: ArenaMap = arena.get_node("ArenaMap")
	map.camera_zoom = 2.0
	for _f in 12:
		await process_frame
	var res := map.result
	var cell := map.cell_px()
	var score := {}   # biome -> {cell index -> plants} on a 6-cell grid
	for o in res.obstacles:
		if o["node"] >= 0 and String(map.style.resource_nodes[o["node"]].id).begins_with("treepp"):
			_count(res, cell, score, o["pos"], 3)
	for d in res.deco:
		_count(res, cell, score, d["pos"], 1)
	var best := {}   # biome -> centre of the busiest 6 x 6 block, px
	for b in score:
		var top := 0
		for key in score[b]:
			if score[b][key] > top:
				top = score[b][key]
				best[b] = (Vector2(key) * 6.0 + Vector2(3, 3)) * cell
	for i in WANT.size():
		var b := -1
		for k in map.style.biomes.size():
			if map.style.biomes[k].label == WANT[i]:
				b = k
		if not best.has(b):
			print("no spot for ", WANT[i])
			continue
		player.global_position = best[b]
		player.get_node("Camera").reset_smoothing()
		var l := Label.new()
		l.text = "9%s  %s: oaks, flowers, tufts, hedges (pack art, zoom 2)" % [char(97 + i), WANT[i]]
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(480, 8)
		var layer := CanvasLayer.new()
		layer.add_child(l)
		arena.add_child(layer)
		await create_timer(1.6).timeout
		root.get_texture().get_image().save_png("%s/09%s_veg_%s.png" % [out, char(97 + i), WANT[i]])
		layer.queue_free()
		if WANT[i] == "forest":   # 10: the same spot with every loaded oak chopped (show_remains = what a broken oak leaves)
			for n in arena.find_children("*", "ResourceNode", true, false):
				if String(n.data.id).begins_with("treepp"):
					n.get_node("Visual").show_remains(n.data)
			l.text = "10 stump: chopped oaks leave the pack stump (forest)"
			layer = CanvasLayer.new()
			layer.add_child(l.duplicate())
			arena.add_child(layer)
			await create_timer(0.5).timeout
			root.get_texture().get_image().save_png("%s/10_stump.png" % out)
			layer.queue_free()
	quit()

func _count(res: MapGen.Result, cell: float, score: Dictionary, pos: Vector2, w: int) -> void:
	var c := Vector2i(pos / cell)
	var ci := c.y * res.cols + c.x
	if ci < 0 or ci >= res.biome.size():
		return
	var s: Dictionary = score.get_or_add(int(res.biome[ci]), {})
	var key := Vector2i(c.x / 6, c.y / 6)
	s[key] = s.get(key, 0) + w
