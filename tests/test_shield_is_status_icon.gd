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
	var cover: Node2D = gv.get_node("CoverArc")
	var guard = player.get_node("Guard")

	var ok := true
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
		player.aim_override = Vector2.RIGHT.rotated(angle)
		await physics_frame
		await process_frame
		var upright: bool = is_zero_approx(gv.rotation)
		var together: bool = cracks.global_position.is_equal_approx(shield.global_position)
		# The hint is the ONE thing that turns: it shows the protected side.
		var hint_turns: bool = is_equal_approx(angle_difference(cover.global_rotation, angle), 0.0)
		print("aim %4.0f deg -> shield rotation %.2f (upright %s) | cracks on shield: %s | hint at %4.0f deg: %s" % [
			rad_to_deg(angle), gv.rotation, upright, together, rad_to_deg(cover.global_rotation), hint_turns])
		ok = ok and upright and together and hint_turns

	# The hint must show exactly what blocks: drag the F3 slider, the arc follows.
	guard.parry_arc_degrees = 90.0
	# physics_frame fires BEFORE the nodes' _physics_process that step, so one
	# await alone reads the value before the player has mirrored it.
	await physics_frame
	await process_frame
	var width_follows: bool = is_equal_approx(cover.arc_degrees, 90.0)
	print("guard arc set to 90 -> hint arc %.0f: %s" % [cover.arc_degrees, width_follows])
	ok = ok and width_follows

	# Turning face_aim on must still work, for art that is a plate held in front.
	gv.face_aim = true
	player.aim_override = Vector2.DOWN
	await physics_frame
	await process_frame
	var turns: bool = is_equal_approx(gv.rotation, PI * 0.5)
	# ...and the hint must not turn TWICE when its parent already turned.
	var hint_once: bool = is_equal_approx(angle_difference(cover.global_rotation, PI * 0.5), 0.0)
	print("face_aim on, aim down -> rotation %.2f (want %.2f): %s | hint not doubled: %s" % [
		gv.rotation, PI * 0.5, turns, hint_once])
	ok = ok and turns and hint_once

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
