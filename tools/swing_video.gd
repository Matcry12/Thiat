extends SceneTree
## Swing video frames: xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --fixed-fps 60 --script tools/swing_video.gd -- <out_dir>
## Optional 2nd arg `f1` turns the F1 overlay on (real hit area). Saves f_00000.png... (every frame, cropped around the player, x2): 3 swings each aiming right, left, up, down.
## Optional 3rd arg = a SwingMotion .tres path (its values are copied onto the sword's motion before recording). Optional 4th arg `right` = aim right only, 2 swings (first way, reversed).
## Then: ffmpeg -framerate 60 -i <out_dir>/f_%05d.png -pix_fmt yuv420p swing.mp4
var _out := "tools/art_tests/swing_styles/video"
var _n := 0
var _wv: WeaponVisual
var _tall := false   ## 5th arg `tall`: crop 240x260 with 170 px above the player (trail tail of the first frames goes up)

func _rec(frames: int) -> void:
	for i in frames:
		await process_frame
		var img := root.get_texture().get_image()
		var c := Vector2i(_wv.get_global_transform_with_canvas().origin)
		var crop := img.get_region(Rect2i(c - Vector2i(120, 170), Vector2i(240, 260)) if _tall else Rect2i(c - Vector2i(120, 90), Vector2i(240, 180)))
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/f_%05d.png" % [_out, _n])
		_n += 1

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("DebugOverlay").enabled = args.size() > 1 and args[1] == "f1"   # 2nd arg "f1" = hitboxes on
	for i in 10:
		await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	_wv = player.get_node("WeaponVisual")
	if args.size() > 2 and args[2] != "":
		var src: SwingMotion = load(args[2])
		var dst: SwingMotion = _wv.weapon.swing_motion
		for pr in src.get_property_list():
			if pr.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				dst.set(pr.name, src.get(pr.name))
	_tall = args.size() > 4 and args[4] == "tall"
	var right_only := args.size() > 3 and args[3] == "right"
	for angle in ([0.0] if right_only else [0.0, PI, -PI / 2, PI / 2]):
		_wv.set_aim_angle(angle)
		await _rec(30)
		for s in (2 if right_only else 3):
			holder.try_attack()
			await _rec(44)   # one full sword swing (0.67 s) + a little
	await _rec(30)
	quit()
