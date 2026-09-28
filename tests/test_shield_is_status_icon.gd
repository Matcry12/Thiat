extends SceneTree
# The shield is a STATUS icon: it stays upright wherever it was dragged, and
# the crack overlay sits exactly on it. Regression for the user report "the
# shield isnt rotate, it at the middle of player" — the cracks had their own
# position and floated 26px away from a shield dragged to the centre.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	var gv = player.get_node("GuardVisual")
	var shield: Sprite2D = gv.get_node("Shield")
	var cracks: Sprite2D = gv.get_node("Shield/Cracks")

	var ok := true
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
		player.aim_override = Vector2.RIGHT.rotated(angle)
		await physics_frame
		await process_frame
		var upright: bool = is_zero_approx(gv.rotation)
		var together: bool = cracks.global_position.is_equal_approx(shield.global_position)
		print("aim %4.0f deg -> visual rotation %.2f (upright %s) | cracks on shield: %s" % [
			rad_to_deg(angle), gv.rotation, upright, together])
		ok = ok and upright and together

	# Turning face_aim on must still work, for art that is a plate held in front.
	gv.face_aim = true
	player.aim_override = Vector2.DOWN
	await physics_frame
	await process_frame
	var turns: bool = is_equal_approx(gv.rotation, PI * 0.5)
	print("face_aim on, aim down -> rotation %.2f (want %.2f): %s" % [gv.rotation, PI * 0.5, turns])
	ok = ok and turns

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
