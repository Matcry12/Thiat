extends SceneTree
# Judge fixes for hit feel slice 1: F2 during stops, dead victims, material restore, one jolt per frame,
# guard break = one effect, and the shipped player_hit data gives no freeze.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("Dummy/Attacker").set_physics_process(false)
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var boss: Boss = arena.get_node("Boss")
	var fx: HitFx = arena.get_node("HitFx")
	var hs := fx.stop
	player.set_physics_process(false)

	# F2 mid-stop, through the real debug overlay key handler
	var f2 := InputEventAction.new()
	f2.action = "debug_slowmo"
	f2.pressed = true
	hs.request(10)
	arena.get_node("DebugOverlay")._unhandled_input(f2)
	check("F2 mid-stop: still frozen", Engine.time_scale < 0.01 and hs.base_scale == 0.25)
	while hs.is_active():
		await process_frame
	check("F2 mid-stop: 0.25 after the stop", is_equal_approx(Engine.time_scale, 0.25))
	arena.get_node("DebugOverlay")._unhandled_input(f2)
	check("F2 again (idle): back to 1.0", is_equal_approx(Engine.time_scale, 1.0))
	# F2 mid kill slow-mo
	hs.request(1, 0.3, 0.05)
	while hs.frames_left() > 0:
		await process_frame
	check("slow-mo running at 0.3", is_equal_approx(Engine.time_scale, 0.3))
	hs.toggle_slowmo()
	check("F2 mid-slow-mo applies on top (0.25 x 0.3)", is_equal_approx(Engine.time_scale, 0.075))
	while hs.is_active():
		await process_frame
	check("after slow-mo: 0.25 (not lost)", is_equal_approx(Engine.time_scale, 0.25))
	hs.toggle_slowmo()
	check("back to 1.0", is_equal_approx(Engine.time_scale, 1.0))

	# shipped player_hit data: no freeze
	var pp: HitFxProfile = null
	for p in fx.profile_list():
		if p.hit_type == &"player_hit":
			pp = p
	var stops: int = fx.layer_counts["stop"]
	fx.fire(&"player_hit", player, dummy)
	check("player_hit data: stop_frames 0 and no stop", pp.stop_frames == 0 and pp.slowmo_time == 0.0 and fx.layer_counts["stop"] == stops and not hs.is_active())

	# one jolt per physics frame
	await physics_frame
	fx.shake.trauma = 0.0
	fx.fire(&"sword", dummy, player)
	fx.fire(&"sword", dummy, player)
	fx.fire(&"sword", dummy, player)
	check("3 hits in one frame add trauma once (%.2f)" % fx.shake.trauma, is_equal_approx(fx.shake.trauma, 0.2))
	while hs.is_active():
		await process_frame

	# flash keeps a real material
	var body: Sprite2D = dummy.get_node("Visual/Body")
	var mine := ShaderMaterial.new()
	body.material = mine
	fx.fire(&"sword", dummy, player)
	check("during the flash: flash material", body.material != mine)
	while hs.is_active():
		await process_frame
	await create_timer(0.3).timeout
	check("after the flash: the original material is back", body.material == mine)

	# guard: a plain block = block fx once; a guard break = player_hit only
	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	guard.aim_direction = Vector2.RIGHT
	var fired: Array = []
	fx.hit_fx.connect(func(t: StringName): fired.append(t))
	guard.state = Guard.State.BLOCK
	health.take_damage(10.0, dummy, true)
	await process_frame
	check("plain block: [block] (got %s)" % [fired], fired == [&"block"])
	fired.clear()
	guard.tank = 5.0
	guard.state = Guard.State.BLOCK
	health.take_damage(100.0, dummy, true)
	await process_frame
	check("guard break: one effect, player_hit (got %s)" % [fired], fired == [&"player_hit"])
	while hs.is_active():
		await process_frame

	# corpses get no hit feel
	fired.clear()
	boss.health.take_damage(100000.0, player, true, &"melee")
	await process_frame
	check("killing blow plays (got %s)" % [fired], &"sword_boss" in fired and &"kill" in fired)
	while hs.is_active():
		await process_frame
	fired.clear()
	boss.health.take_damage(50.0, player, true, &"melee")
	await process_frame
	check("hit on the boss corpse: nothing (got %s)" % [fired], fired.is_empty())
	health.immortal = false
	health.take_damage(100000.0, dummy, false)
	await process_frame
	while hs.is_active():
		await process_frame
	fired.clear()
	health.take_damage(30.0, dummy, false)
	await process_frame
	check("bolt on a dead player: nothing (got %s)" % [fired], fired.is_empty())

	Engine.time_scale = 1.0
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
