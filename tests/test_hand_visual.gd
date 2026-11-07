extends SceneTree
# The visible hands (0065): rest on both sides, the free one behind the body; sits on the weapon's grip while the weapon shows and through a swing,
# keeps the body's pixel size, never turns, hides on death and when switched off.
var ok := true

func _check(c: bool, msg: String) -> void:
	if not c:
		print("FAIL: ", msg)
		ok = false

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var hand: HandVisual = player.get_node("MainHandArt")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	_check(player.get_children().find(hand) > player.get_children().find(wv), "hand runs after WeaponVisual")
	wv.visible = false
	await process_frame
	await process_frame
	var rest_at := func(marker: String, sx: float) -> Vector2:
		var o: Vector2 = player.get_node(marker).position + (player.get_node("Visual").hand_frame_offset() / 3.0).round() * 3.0
		return player.global_position + Vector2(o.x * sx, o.y)
	_check(hand.global_position.is_equal_approx(rest_at.call("MainHandRest", 1.0)), "weapon hidden: hand rests on MainHandRest")
	_check(player.get_node("MainHandRest").position.x * player.get_node("OffHandRest").position.x < 0.0, "rest: one hand on each side")
	_check(player.get_children().find(player.get_node("OffHandArt")) < player.get_children().find(player.get_node("Visual")) and player.get_node("OffHandArt").z_index == 0, "rest: free hand drawn behind the body")
	_check(hand.global_scale.is_equal_approx(player.get_node("Visual").rig.body_scale), "hand uses the body's pixel size")
	# run: each hand steps by its own table with the body frame; the arms go opposite ways
	var bd: AnimatedSprite2D = player.get_node("Visual/Body")
	var free: HandVisual = player.get_node("OffHandArt")
	bd.play(&"run")
	bd.pause()
	for f in 4:
		bd.frame = f
		await process_frame
		await process_frame
		_check((hand.global_position - rest_at.call("MainHandRest", 1.0)).is_equal_approx(hand.run_swing[f]) and (free.global_position - rest_at.call("OffHandRest", 1.0)).is_equal_approx(free.run_swing[f]), "run frame %d: hands step by their tables" % f)
	_check(hand.run_swing[0].x * free.run_swing[0].x < 0.0, "arms swing opposite ways")
	bd.play(&"idle")
	await process_frame
	await process_frame
	wv.visible = true
	player._on_swap_finished(load("res://data/weapons/katana.tres"))   # the two-handed sword
	wv.on_weapon_state("windup")
	for i in 4:
		await process_frame
		await process_frame
		_check(hand.global_position.is_equal_approx(wv.picture_grip_tip()["grip"]), "swing: hand stays on the grip")
		_check(is_equal_approx(hand.global_rotation, 0.0), "hand never turns")
	# free hand: on its own marker while the other swings, x mirrors with the body
	var off: HandVisual = player.get_node("OffHandArt")
	var body = player.get_node("Visual")
	var marker: Vector2 = player.get_node("OffHandRest").position
	var want := func(sx: float) -> Vector2:
		var o: Vector2 = marker + body.hand_frame_offset()
		return player.global_position + Vector2(o.x * sx, o.y)
	var pic: Dictionary = wv.picture_grip_tip()
	_check(pic.has("off_grip") and off.global_position.is_equal_approx(pic["off_grip"]) and off.z_index == off.hold_z, "two-handed swing: free hand on OffHandGrip, over the weapon")
	_check(not off.global_position.is_equal_approx(hand.global_position), "two hands, two places")
	off.use_off_grip = false
	await process_frame
	await process_frame
	_check(off.global_position.is_equal_approx(want.call(1.0)) and off.z_index == off.hand_z, "use_off_grip off: free hand on the OffHandRest marker")
	off.use_off_grip = true
	player._on_swap_finished(load("res://data/weapons/wooden_sword.tres"))   # no OffHandGrip = one-handed
	await process_frame
	await process_frame
	_check(off.global_position.is_equal_approx(want.call(1.0)), "weapon without OffHandGrip: free hand stays on the body")
	wv.visible = false
	player._on_swap_finished(load("res://data/weapons/wooden_sword.tres"))
	await process_frame
	await process_frame
	_check(off.global_position.is_equal_approx(want.call(1.0)), "weapon hidden: free hand back on the body")
	wv.visible = true
	body.set_facing(Vector2.LEFT)
	off.use_off_grip = false
	await process_frame
	await process_frame
	_check(off.global_position.is_equal_approx(want.call(-1.0)), "free hand mirrors when facing left")
	off.use_off_grip = true
	body.set_facing(Vector2.RIGHT)
	wv.on_weapon_state("idle")
	hand.hand_on = false
	await process_frame
	_check(not hand.visible, "hand_on off hides it")
	hand.hand_on = true
	await process_frame
	_check(hand.visible, "hand_on on shows it")
	player.get_node("Health").take_damage(99999.0)
	await process_frame
	await process_frame
	_check(not hand.visible and not off.visible, "dead: both hands hidden")
	print("test_hand_visual: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
