extends SceneTree
## Proof for tools/add_weapon.py: the real player holds a new weapon, scale as made (0 = the scene's) and 3, side by side, 4x crop.
## godot --rendering-driver opengl3 --resolution 1152x648 --script tools/new_weapon_proof_shot.gd -- <weapon_id> <out.png>
func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var id := args[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await _frames(10)
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var w: WeaponData = load("res://data/weapons/%s.tres" % id)
	var sheet := Image.create(2 * 644, 440, false, Image.FORMAT_RGBA8)
	for col in 2:
		w.art_scale = [0.0, 3.0][col]
		player._on_swap_finished(w)
		wv.dev_hold_still = true
		wv.visible = true
		wv.dev_still_aim_deg = -20.0
		wv.set_aim_angle(deg_to_rad(-20.0))
		await _frames(30)
		var c := Vector2i(wv.get_global_transform_with_canvas().origin)
		var crop := root.get_texture().get_image().get_region(Rect2i(c - Vector2i(30, 85), Vector2i(160, 110)))
		crop.resize(640, 440, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(crop, Rect2i(0, 0, 640, 440), Vector2i(col * 644, 0))
		print(id, " art_scale=", w.art_scale, "  ", wv.status_text().right(80))
	w.art_scale = 0.0
	sheet.save_png(args[1])
	quit()
