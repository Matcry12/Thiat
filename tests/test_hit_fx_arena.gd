extends SceneTree
# A REAL sword swing on the dummy fires each hit-feel layer once; a player hit never freezes the game;
# an F3 test button changes no HP. (decision 0023)
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	var fx: HitFx = arena.get_node("HitFx")
	var holder = arena.get_node("Player/WeaponHolder")
	player.set_physics_process(false)
	dummy.attacker.set_physics_process(false)   # the dummy must not hit back during this test
	player.global_position = dummy.global_position - Vector2(45, 0)
	arena.get_node("Player/WeaponVisual").set_aim_angle(0.0)
	await physics_frame

	var fired: Array = []
	fx.hit_fx.connect(func(t: StringName): fired.append(t))
	var sounds_before: int = fx.sound.play_count
	holder.try_attack()
	var guard := 0
	while holder.phase != 0 or guard < 5:
		await physics_frame
		guard += 1
		if guard > 600:
			break
	check("one sword hit fired (got %s)" % [fired], fired == [&"sword"])
	check("flash once", fx.layer_counts["flash"] == 1)
	check("stop once", fx.layer_counts["stop"] == 1)
	check("sound once", fx.layer_counts["sound"] == 1 and fx.sound.play_count == sounds_before + 1)
	check("shake once", fx.layer_counts["shake"] == 1)
	var flash := dummy.get_node("Visual/HitFlash") as HitFlash
	check("dummy body got a HitFlash", flash != null)
	fx.test_hit(&"sword")
	check("flash puts the shader on the dummy body, shake adds trauma", dummy.get_node("Visual/Body").material != null and fx.shake.trauma > 0.0)
	check("hit sound pitch within +/-8%", absf(fx.sound.last_pitch - 1.0) <= 0.0801)
	while fx.stop.is_active():
		await process_frame
	check("time_scale restored", Engine.time_scale == 1.0)

	# the player gets hit: red flash, shake, sound, but NO freeze
	while fx.stop.is_active():
		await process_frame
	var stops: int = fx.layer_counts["stop"]
	player.get_node("Health").take_damage(10.0, dummy, true)
	check("player hit: no hit-stop", fx.layer_counts["stop"] == stops and not fx.stop.is_active() and Engine.time_scale == 1.0)
	check("player hit: flashed red", (player.get_node("Visual/HitFlash") as HitFlash).amount() == 1.0
		and player.get_node("Visual/Body").material.get_shader_parameter("flash_color").g < 0.5)
	check("last hit = player_hit", fx.last_hit == &"player_hit")

	# F3 buttons: effects only, no HP change
	var hp: Array = [player.get_node("Health").hp, dummy.get_node("Health").hp, arena.get_node("Boss").health.hp]
	var shield: float = player.get_node("Health").shield
	for k in [&"sword", &"parry", &"player_hit", &"kill"]:
		fx.test_hit(k)
	var hp2: Array = [player.get_node("Health").hp, dummy.get_node("Health").hp, arena.get_node("Boss").health.hp]
	check("test buttons change no HP", hp == hp2 and shield == player.get_node("Health").shield)
	check("test kill started a freeze", fx.stop.is_active())
	arena.get_node("HitFx").enabled = false
	var n: int = fx.layer_counts["flash"]
	fx.test_hit(&"sword")
	check("master switch off: nothing plays", fx.layer_counts["flash"] == n)
	Engine.time_scale = 1.0
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
