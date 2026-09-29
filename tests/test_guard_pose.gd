extends SceneTree
# Holding F raises the sword into the weapon's guard pose; releasing drops it
# back to rest.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.aim_override = Vector2.RIGHT
	var guard = player.get_node("Guard")
	var wv = player.get_node("WeaponVisual")
	var pivot: Node2D = wv.get_node("SwingPivot")
	# A pose is angle + arm offset. Give it a non-zero offset to prove both move.
	wv.weapon.guard_forward = 10.0
	wv.weapon.guard_side = -4.0
	var want_guard := deg_to_rad(wv.weapon.guard_angle_degrees)
	var want_rest := deg_to_rad(wv.weapon.rest_angle_degrees)

	await _frames(10)
	var at_rest: bool = is_equal_approx(pivot.rotation, want_rest)
	print("before F: blade %.0f deg (rest %.0f): %s" % [rad_to_deg(pivot.rotation), wv.weapon.rest_angle_degrees, at_rest])

	guard.try_guard()
	# The pose must be reached well inside the 0.25s parry window, or the
	# player sees the sword still moving when the parry has already landed.
	await _seconds(wv.guard_raise_time + 0.03)
	var raised: bool = absf(angle_difference(pivot.rotation, want_guard)) < 0.02
	var in_window: bool = wv.guard_raise_time < guard.parry_window
	print("after F %.2fs: blade %.0f deg (guard %.0f): %s | pose beats the parry window: %s" % [
		wv.guard_raise_time + 0.03, rad_to_deg(pivot.rotation), wv.weapon.guard_angle_degrees, raised, in_window])

	var moved: bool = pivot.position.is_equal_approx(Vector2(10, -4))
	print("arm offset in guard: %s (want (10, -4)): %s" % [pivot.position, moved])
	raised = raised and moved


	await _seconds(guard.parry_window + 0.05)          # still holding -> BLOCK
	var still_up: bool = absf(angle_difference(pivot.rotation, want_guard)) < 0.02
	print("holding into block: blade still up: %s (state %s)" % [still_up, Guard.State.keys()[guard.state]])

	guard.release()
	await _seconds(wv.guard_lower_time + 0.05)
	var lowered: bool = absf(angle_difference(pivot.rotation, want_rest)) < 0.02 \
		and pivot.position.is_equal_approx(Vector2.ZERO)
	print("after release: blade %.0f deg (rest %.0f), arm %s: %s" % [
		rad_to_deg(pivot.rotation), wv.weapon.rest_angle_degrees, pivot.position, lowered])

	var ok := at_rest and raised and in_window and still_up and lowered
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _seconds(s: float) -> void:
	await create_timer(s).timeout
