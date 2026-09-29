extends SceneTree
# The dodge must be a fast MOVE, not a teleport: it takes several frames and
# covers roughly burst_distance.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)          # headless mouse would re-aim every frame
	var dodge = player.get_node("Dodge")

	var start: Vector2 = player.global_position
	dodge.try_dodge(Vector2.RIGHT, Vector2.RIGHT)

	await physics_frame
	var after_one: float = player.global_position.distance_to(start)
	var not_teleport: bool = after_one < dodge.burst_distance * 0.6
	print("after 1 frame moved %.1f of %.1f -> not a teleport: %s" % [after_one, dodge.burst_distance, not_teleport])

	var frames := 0
	while dodge.is_dashing() and frames < 60:
		await physics_frame
		frames += 1
	var total: float = player.global_position.distance_to(start)
	var took_time: bool = frames >= 2
	var right_distance: bool = absf(total - dodge.burst_distance) < dodge.burst_distance * 0.25
	print("dash took %d frames, travelled %.1f (want ~%.1f)" % [frames, total, dodge.burst_distance])

	var ok: bool = not_teleport and took_time and right_distance
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
