extends SceneTree
## Natural swing proof: xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/swing_shots.gd -- <out_dir>
## Saves game_{right,left}_{1,2}.png: two swings in a row (alternating side), 6 frames each, cropped around the player.
var _out := "tools/art_tests/swing_styles"

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("DebugOverlay").enabled = false
	await _frames(10)
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	for side in [["right", 0.0], ["left", PI]]:
		await _frames(90)   # idle > alternate_reset_time: next swing is the first way
		for n in [1, 2]:
			wv.set_aim_angle(side[1])
			await _frames(2)
			holder.try_attack()
			var strip := Image.create(6 * 288, 288, false, Image.FORMAT_RGBA8)
			for f in 6:
				await _frames(2)
				var img := root.get_texture().get_image()
				var c := Vector2i(wv.get_global_transform_with_canvas().origin)
				var crop := img.get_region(Rect2i(c - Vector2i(72, 72), Vector2i(144, 144)))
				crop.resize(288, 288, Image.INTERPOLATE_NEAREST)
				strip.blit_rect(crop, Rect2i(0, 0, 288, 288), Vector2i(f * 288, 0))
				if f == 0:
					print("%s swing %d: %s" % [side[0], n, wv.status_text()])
			strip.save_png("%s/game_%s_%d.png" % [_out, side[0], n])
			await _frames(30)   # recovery done, still inside the reset time
	# One frame with F1 on: grip cross + blade tip dot, mid swing.
	arena.get_node("DebugOverlay").enabled = true
	wv.set_aim_angle(0.0)
	await _frames(40)
	holder.try_attack()
	await _frames(12)
	root.get_texture().get_image().get_region(Rect2i(Vector2i(wv.get_global_transform_with_canvas().origin) - Vector2i(120, 120), Vector2i(240, 240))).save_png("%s/game_f1_fit.png" % _out)
	quit()
