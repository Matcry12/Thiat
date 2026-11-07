extends SceneTree
## Before / after sheet for decision 0061: godot --rendering-driver opengl3 --resolution 1152x648 --script tools/weapon_hit_fit_shots.gd -- <out_dir>
## Rows: stone_axe, stone_pickaxe, copper_sword. Columns: old (hit_auto_fit off = hand Tip + hand hit shape) @ frame 8 and new @ 8, old @ 14, new @ 14.
## F1 is on: the hit shape (red outline), grip cross and Tip dot are drawn by the DebugOverlay.
var _out := "tools/art_tests/weapon_hit_fit"

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
	await _frames(10)
	arena.get_node("DebugOverlay").enabled = true
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var names := ["stone_axe", "stone_pickaxe", "copper_sword"]
	var sheet := Image.create(4 * 400, names.size() * 400, false, Image.FORMAT_RGBA8)
	for row in names.size():
		var w: WeaponData = load("res://data/weapons/%s.tres" % names[row])
		for auto in [false, true]:
			w.hit_auto_fit = auto
			player._on_swap_finished(w)
			wv.set_aim_angle(0.0)
			await _frames(100)   # idle: next swing is the first way
			holder.try_attack()
			var at := 0
			for shot in [[8, 0], [14, 2]]:
				await _frames(int(shot[0]) - at)
				at = int(shot[0])
				var img := root.get_texture().get_image()
				var c := Vector2i(wv.get_global_transform_with_canvas().origin)
				var crop := img.get_region(Rect2i(c - Vector2i(100, 100), Vector2i(200, 200)))
				crop.resize(400, 400, Image.INTERPOLATE_NEAREST)
				sheet.blit_rect(crop, Rect2i(0, 0, 400, 400), Vector2i((int(shot[1]) + (1 if auto else 0)) * 400, row * 400))
			print("%s auto=%s  %s" % [names[row], auto, wv.status_text().right(60)])
			await _frames(60)
		w.hit_auto_fit = true
	sheet.save_png("%s/sheet.png" % _out)
	quit()
