extends SceneTree
# The glow arc (CoverArc) shows the protected side while guarding: it turns with
# the aim, its width follows Guard.parry_arc_degrees, and a position the user
# dragged in the editor survives play (code writes only its rotation).
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	var cover: Node2D = player.get_node("GuardVisual/CoverArc")
	var guard = player.get_node("Guard")
	var dragged := Vector2(7, -11)
	cover.position = dragged

	var ok := true
	for angle in [0.0, PI * 0.5, PI, -PI * 0.5]:
		player.aim_override = Vector2.RIGHT.rotated(angle)
		await physics_frame
		await process_frame
		var turns: bool = is_equal_approx(angle_difference(cover.global_rotation, angle), 0.0)
		print("aim %4.0f deg -> hint at %4.0f deg: %s" % [rad_to_deg(angle), rad_to_deg(cover.global_rotation), turns])
		ok = ok and turns

	guard.parry_arc_degrees = 90.0
	# physics_frame fires BEFORE the nodes' _physics_process that step.
	await physics_frame
	await process_frame
	var width_follows: bool = is_equal_approx(cover.arc_degrees, 90.0)
	print("guard arc set to 90 -> hint arc %.0f: %s" % [cover.arc_degrees, width_follows])

	var kept: bool = cover.position.is_equal_approx(dragged)
	print("dragged hint position kept: %s (%s)" % [kept, cover.position])

	ok = ok and width_follows and kept
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
