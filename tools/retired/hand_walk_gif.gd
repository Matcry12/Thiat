extends SceneTree
## Saves the 4 run frames with both hands (0065), for a moving proof. 4x crop, no F1. Facing right.
## timeout 60 godot --rendering-driver opengl3 --resolution 1152x648 --script tools/retired/hand_walk_gif.gd -- <out_prefix>   (writes <out_prefix>0..3.png)
func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await _frames(10)
	for n in arena.find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/debug/debug_overlay.gd"):
			n.enabled = false
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.get_node("WeaponVisual").visible = false
	var body: AnimatedSprite2D = player.get_node("Visual/Body")
	for f in 4:
		body.play(&"run")
		body.pause()
		body.frame = f
		await _frames(4)
		var c := Vector2i(player.get_global_transform_with_canvas().origin)
		var crop := root.get_texture().get_image().get_region(Rect2i(c - Vector2i(40, 60), Vector2i(80, 80)))
		crop.resize(320, 320, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s%d.png" % [OS.get_cmdline_user_args()[0], f])
	quit()
