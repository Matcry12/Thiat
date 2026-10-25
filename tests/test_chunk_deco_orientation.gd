extends SceneTree
# Floor props must be drawn the right way up: the top of the sprite on the sheet is the top on screen (ChunkDeco quad + UV).
# Needs a real renderer: run with `xvfb-run -a godot --rendering-driver opengl3 --script tests/test_chunk_deco_orientation.gd`; headless it skips.
func _init() -> void:
	if DisplayServer.get_name() == "headless":
		print("skip (headless has no renderer)")
		quit(0)
		return
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill_rect(Rect2i(0, 0, 8, 4), Color.RED)     # top half red
	img.fill_rect(Rect2i(0, 4, 8, 4), Color.BLUE)    # bottom half blue
	var set := PropSet.new()
	set.texture = ImageTexture.create_from_image(img)
	set.regions = [Rect2(0, 0, 8, 8)]
	var deco: Array[Dictionary] = [{"set": 0, "region": 0, "pos": Vector2(32, 48), "px": 0}]
	var sets: Array[PropSet] = [set]
	var vp := SubViewport.new()
	vp.size = Vector2i(64, 64)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(ChunkDeco.build(deco, sets, 4.0))   # 32 x 32 picture, bottom centre (32, 48): spans y 16..48
	for _i in 4:
		await process_frame
	var out := vp.get_texture().get_image()
	var top := out.get_pixel(32, 20)
	var bottom := out.get_pixel(32, 44)
	var ok := top.r > 0.8 and top.b < 0.2 and bottom.b > 0.8 and bottom.r < 0.2
	print(("ok   " if ok else "FAIL ") + "prop top is red, bottom is blue (top=%s bottom=%s)" % [top, bottom])
	quit(0 if ok else 1)
