extends SceneTree
# Hit-stop must not eat input (decision 0023, Opus review point 2): attack / dodge pressed INSIDE a freeze
# still happen when it ends. And a parry window opened before a freeze is still open after it.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _press(action: String, on: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = on
	Input.parse_input_event(e)

func _arena() -> Node:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("Dummy/Attacker").set_physics_process(false)
	return arena

func _init():
	OS.set_environment("BOSSFIGHT_TEST_MAP_CELLS", "192")   # small island: this test does not need the full map
	for freeze in [false, true, "tap"]:
		var arena = _arena()
		await process_frame
		var player = arena.get_node("Player")
		var fx: HitFx = arena.get_node("HitFx")
		var swings := [0]
		player.weapon_holder.state_changed.connect(func(st: String): if st == "windup": swings[0] += 1)
		for i in 3:
			await physics_frame
		if freeze:
			fx.stop.request(10)
		_press("attack", true)
		_press("dodge", true)
		await process_frame
		check("[freeze=%s] press landed %s the stop" % [freeze, "inside" if freeze else "outside"], fx.stop.is_active() == (str(freeze) != "false"))
		if freeze is String:   # a whole tap (down AND up) inside the freeze
			_press("attack", false)
			_press("dodge", false)
		if freeze:
			while fx.stop.is_active():
				await process_frame
		for i in 6:
			await physics_frame
		_press("attack", false)
		_press("dodge", false)
		check("[freeze=%s] attack happened (swings=%d)" % [freeze, swings[0]], swings[0] == 1)
		check("[freeze=%s] dodge happened (cooldown %.2f)" % [freeze, player.dodge.cooldown_remaining()], player.dodge.cooldown_remaining() > 0.0)
		arena.queue_free()
		await process_frame

	# parry window survives a freeze: it runs on game time, which the freeze stops
	var arena = _arena()
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var fx: HitFx = arena.get_node("HitFx")
	player.set_physics_process(false)
	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	guard.aim_direction = Vector2.RIGHT
	guard.try_guard()
	await physics_frame
	await physics_frame
	var left_before: float = guard._timer
	fx.stop.request(12)
	while fx.stop.is_active():
		await physics_frame     # count exactly the physics ticks lost; process_frame can run extra ticks on a slow headless frame
	var lost: float = left_before - guard._timer
	check("parry window lost %.3fs to a 12-frame freeze (<0.02)" % lost, lost < 0.02 and guard.state == Guard.State.PARRY)
	var hp: float = health.hp + health.shield
	health.take_damage(50.0, dummy, true)
	check("parry after the freeze still negates", health.hp + health.shield == hp)
	check("parry fired the parry fx", fx.last_hit == &"parry")
	Engine.time_scale = 1.0
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
