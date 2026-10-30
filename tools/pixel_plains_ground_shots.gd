extends SceneTree
## Pixel Plains ground in the real game: the start spot, a spot where dark grass, light grass and dirt meet, and a 4x crop of that border.
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/pixel_plains_ground_shots.gd -- <out_dir>
var _out := ""

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var player: CharacterBody2D = arena.get_node("Player")
	player.get_node("Health").immortal = true
	arena.get_node("Boss").passive = true
	var map: ArenaMap = arena.get_node("ArenaMap")
	for _f in 12:
		await process_frame
	await _wait(0.8)
	await _shot("start")
	# a spot with dark grass, light grass and dirt within a few cells (needs the whole-map materials, once)
	var res := map.result
	var pp := map.style.pixel_plains
	var mats := PixelPlainsBaker.cell_materials(res, pp, 0, 0, res.cols, res.rows)   # (cols + 1)^2 cells starting at cell -1
	var pw := res.cols + 1
	var best := Vector2i(-1, -1)
	var home := Vector2i((map.home_point() / map.cell_px()).floor())
	var best_d := 1 << 30
	for y in range(3, res.rows - 3):
		for x in range(3, res.cols - 3):
			var m := mats[(y + 1) * pw + x + 1]
			if m != PixelPlainsGround.Mat.LIGHT + 1:
				continue
			var has_dark := false
			var has_dirt := false
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					var n := mats[(y + dy + 1) * pw + x + dx + 1]
					has_dark = has_dark or n == PixelPlainsGround.Mat.DARK + 1
					has_dirt = has_dirt or n == PixelPlainsGround.Mat.DIRT + 1
			if has_dark and has_dirt:
				var d := (Vector2i(x, y) - home).length_squared()
				if d < best_d:
					best_d = d
					best = Vector2i(x, y)
	print("border spot cell ", best)
	if best.x >= 0:
		player.global_position = (Vector2(best) + Vector2(0.5, 0.5)) * map.cell_px()
		player.get_node("Camera").reset_smoothing()
		await _wait(1.5)
		await _shot("border")
		var img := root.get_texture().get_image()
		var c := img.get_size() / 2
		var crop := img.get_region(Rect2i(c - Vector2i(144, 81), Vector2i(288, 162)))
		crop.resize(1152, 648, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/border_zoom4x.png" % _out)
	quit()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
