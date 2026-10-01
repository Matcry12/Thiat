extends SceneTree
# Decision 0020: a snapping swing hits everything along its arc on the FIRST
# physics frame of ACTIVE, once. Targets just inside both ends are hit; one
# outside the arc is not. Aim right and aim left (the visual mirrors).
var _holder: WeaponHolder

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var hp: Health = dummy.get_node("Health")
	player.set_physics_process(false)
	_holder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var half := wv.weapon.arc_degrees * 0.5
	var ok := true
	# [name, angle from the aim line in the weapon's own frame (deg), expected hits]
	var cases := [["start side", -half + 5.0, 1], ["end side", half - 5.0, 1],
			["middle", 0.0, 1], ["outside start", -110.0, 0], ["outside end", 110.0, 0],
			# The shape sits a little off the blade's centre line (toward +), so past the END
			# of the arc it still reaches, past the START it does not. A sweep that runs the
			# wrong way or ignores the left-aim mirror gets one of these two wrong.
			["past end, far tip", half + 17.0, 1, 58.0], ["past start, far tip", -half - 17.0, 0, 58.0]]
	for aim in [0.0, PI]:
		wv.set_aim_angle(aim)
		for cs in cases:
			await _frames(3)
			# local -> world through the mirrored aim node, so "start side" is where the blade starts
			dummy.global_position = wv.global_transform * (Vector2.from_angle(deg_to_rad(cs[1])) * (cs[3] if cs.size() > 3 else 40.0))
			hp.hp = hp.max_hp
			await _frames(3)
			_holder.try_attack()
			var guard := 0
			while _holder.phase != WeaponHolder.Phase.ACTIVE and guard < 300:
				await physics_frame
				guard += 1
			var first_frame: int = roundi((hp.max_hp - hp.hp) / 20.0)
			await _until_idle()
			var total: int = roundi((hp.max_hp - hp.hp) / 20.0)
			var good: bool = first_frame == cs[2] and total == cs[2]
			print("aim %3.0f %-14s first frame: %d  whole swing: %d  want %d  %s" % [rad_to_deg(aim), cs[0], first_frame, total, cs[2], good])
			ok = ok and good
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _until_idle() -> void:
	var guard := 0
	while _holder.phase != WeaponHolder.Phase.IDLE and guard < 300:
		await physics_frame
		guard += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
