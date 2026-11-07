extends SceneTree
# Decision 0020 (the weapon WITHOUT a swing_motion; see the sword with one in test_hit_follows_swing.gd): a snapping swing hits everything along its arc on the FIRST
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
	dummy.set_physics_process(false)   # no home return: the test places the dummy itself
	var hp: Health = dummy.get_node("Health")
	player.set_physics_process(false)
	for b in [player, dummy]:   # no shoves: a hit's knockback would move the aim point / target mid-case
		var kb = b.get_node_or_null("Knockback")
		if kb: kb.enabled = false
	_holder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	wv.weapon.swing_motion = null   # 0050: a SwingMotion sword sweeps its blade path (tests/test_hit_follows_swing.gd); this test keeps the old fixed-pivot arc
	wv.set_weapon(wv.weapon)
	wv.weapon.step_distance = 0.0   # this test measures sweep geometry from a fixed spot
	player.get_node("Visual").rig.hand_follow = 0.0   # the body animates while this runs; the hand must not move under the dummy
	var half := wv.weapon.arc_degrees * 0.5
	var gm := wv.weapon.model.instantiate() as Node2D
	var gx: float = gm.get_node("MainHandGrip").position.x if gm.has_node("MainHandGrip") else 0.0   # the picture (and reach) starts at the scene's Grip
	gm.free()
	var ok := true
	# [name, angle from the aim line in the weapon's own frame (deg), expected hits]
	var cases := [["start side", -half + 5.0, 1], ["end side", half - 5.0, 1],
			["middle", 0.0, 1], ["outside start", -110.0, 0], ["outside end", 110.0, 0],
			# The shape sits ON the blade's centre line now (0050 follow-up; it used to sit 5 px toward +), so past the
			# END and past the START of the arc both still reach by the same amount (a dummy has a radius).
			["past end, far tip", half + 17.0, 1, 58.0], ["past start, far tip", -half - 17.0, 1, 58.0]]
	for aim in [0.0, PI]:
		wv.set_aim_angle(aim)
		for cs in cases:
			await _frames(3)
			# local -> world through the mirrored aim node, so "start side" is where the blade starts
			dummy.global_position = wv.global_transform * (Vector2.from_angle(deg_to_rad(cs[1])) * ((cs[3] if cs.size() > 3 else 40.0) - maxf(gx, 0.0)))   # a Grip further up shortens the reach; a Grip behind the origin only adds to it, the distances still hit
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
