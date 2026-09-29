extends SceneTree
# The glow arc (CoverArc) shows the protected side while guarding: it turns with
# the aim, its width follows Guard.parry_arc_degrees, and a position the user
# dragged in the editor survives play (code writes only its rotation).
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
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

	# Editor preview: the arc must be able to show Guard's width on its own,
	# with no player code copying it (the editor never runs the player).
	cover.arc_degrees = 180.0
	guard.parry_arc_degrees = 70.0
	cover.sync_editor_preview()
	var preview_ok: bool = is_equal_approx(cover.arc_degrees, 70.0)
	print("editor preview reads Guard's width: %.0f (want 70): %s" % [cover.arc_degrees, preview_ok])
	ok = ok and preview_ok

	var kept: bool = cover.position.is_equal_approx(dragged)
	print("dragged hint position kept: %s (%s)" % [kept, cover.position])

	# The width must NOT be editable on the arc: code overwrites it every frame,
	# so an Inspector field there would be a trap (the user fell into it).
	var editable := false
	for prop in cover.get_property_list():
		if prop.name in ["arc_degrees", "value"] and (prop.usage & PROPERTY_USAGE_EDITOR):
			editable = true
	print("code-owned width/fill editable in the Inspector (must be false): %s" % editable)

	ok = ok and width_follows and kept and not editable
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
