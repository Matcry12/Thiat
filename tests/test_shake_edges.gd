extends SceneTree
# Shake near the map edge: the camera view must never leave the Camera2D limits (decision 0023).
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var cam: Camera2D = player.get_node("Camera")
	var shake: CameraShake = arena.get_node("HitFx").shake
	var size: Vector2 = arena.get_node("ArenaMap").map_size()
	var ok := true
	var moved := false
	for pos in [Vector2(2, 2), Vector2(size.x - 2, 2), Vector2(2, size.y - 2), size - Vector2(2, 2), size * 0.5]:
		player.global_position = pos
		cam.reset_smoothing()
		cam.offset = Vector2.ZERO
		await process_frame
		shake.trauma = 1.0
		shake.decay = 0.0
		for i in 40:
			await process_frame
			var half: Vector2 = root.get_visible_rect().size / cam.zoom * 0.5
			var c: Vector2 = cam.get_screen_center_position()
			var out: bool = c.x - half.x < cam.limit_left - 0.01 or c.y - half.y < cam.limit_top - 0.01 \
				or c.x + half.x > cam.limit_right + 0.01 or c.y + half.y > cam.limit_bottom + 0.01
			if out:
				ok = false
				print("view left the map at ", pos, " centre ", c, " offset ", cam.offset)
				break
			if cam.offset != Vector2.ZERO:
				moved = true
	print("shake moved the camera somewhere: ", moved)
	print("PASS" if ok and moved else "FAIL")
	quit(0 if ok and moved else 1)
