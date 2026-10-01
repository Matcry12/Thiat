extends SceneTree
# Soul Knight snap (visual only): one frame or so into ACTIVE the blade is already at
# +arc/2; it HOLDS there for the first follow_through_hold of RECOVERY, then moves back.
var _holder: WeaponHolder

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	_holder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var pivot: Node2D = wv.get_node("SwingPivot")
	var end_deg := wv.weapon.arc_degrees * 0.5
	var ok := true
	wv.set_aim_angle(0.0)
	_holder.try_attack()
	# Frame-by-frame: no wall-clock timers. `t` adds up the game time of the frames seen.
	await _until_phase(WeaponHolder.Phase.ACTIVE)
	var t := 0.0
	var at_end_after := -1.0
	while _holder.phase == WeaponHolder.Phase.ACTIVE:
		await process_frame
		t += wv.get_process_delta_time()
		if at_end_after < 0.0 and absf(rad_to_deg(pivot.rotation) - end_deg) <= 3.0:
			at_end_after = t
	# The snap may take one frame more than snap_time (the state arrives mid-frame).
	var snapped_ok: bool = at_end_after >= 0.0 and at_end_after <= wv.snap_time + 2.0 * wv.get_process_delta_time()
	print("blade at +arc/2 after %.3fs of ACTIVE (snap_time %.3f)  %s" % [at_end_after, wv.snap_time, snapped_ok])
	ok = ok and snapped_ok
	# RECOVERY: the blade stays at the end until (about) follow_through_hold has passed.
	t = 0.0
	var held := true
	var seen := 0
	while _holder.phase == WeaponHolder.Phase.RECOVERY:
		await process_frame
		t += wv.get_process_delta_time()
		if t + 2.0 * wv.get_process_delta_time() < wv.follow_through_hold:
			seen += 1
			held = held and absf(rad_to_deg(pivot.rotation) - end_deg) <= 3.0
	held = held and seen > 0
	print("held at the end for the first %.2fs of RECOVERY (%d frames checked)  %s" % [wv.follow_through_hold, seen, held])
	ok = ok and held
	await _until_phase(WeaponHolder.Phase.IDLE)
	await process_frame
	await process_frame
	var a := rad_to_deg(pivot.rotation)
	var back: bool = absf(a - wv.weapon.rest_angle_degrees) <= 3.0
	print("after recovery: %.1f deg (rest %.1f)  %s" % [a, wv.weapon.rest_angle_degrees, back])
	ok = ok and back
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _until_phase(p: int) -> void:
	var guard := 0
	while _holder.phase != p and guard < 300:
		await process_frame
		guard += 1
