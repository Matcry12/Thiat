extends SceneTree
# Shadow breathes with the run bounce; dust puffs spawn while running (not idle); both switch off.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _pose(vis: SpriteActorVisual, body: AnimatedSprite2D, ph: float) -> void:
	body.frame = int(ph)
	body.frame_progress = ph - floorf(ph)
	vis._process(0.0)

## The player as shipped (Pixel Plains, 4 run frames): up on 0 and 2, a foot lands on 1 and 3.
func _shipped_run_tests(vis: SpriteActorVisual, body: AnimatedSprite2D) -> void:
	var sh := vis.get_node("Shadow") as Sprite2D
	var rest_scale := sh.scale
	var landings := [0]
	vis.landed.connect(func(): landings[0] += 1)
	vis.set_move_state("run")
	body.pause()
	check("shipped: run has 4 frames", body.sprite_frames.get_frame_count(&"run") == 4)
	for f in 4:
		_pose(vis, body, float(f))
		check("shipped: frame %d shadow %s" % [f, "smaller" if f % 2 == 0 else "full"], (sh.scale.x < rest_scale.x) == (f % 2 == 0))
	_pose(vis, body, 0.0)
	_pose(vis, body, 1.0)
	check("shipped: a foot lands on frames 1 and 3 (cycle + frame 1 again = 3)", landings[0] == 3)
	vis.set_move_state("idle")

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var vis: SpriteActorVisual = player.get_node("Visual")
	var body := vis.get_node("Body") as AnimatedSprite2D
	_shipped_run_tests(vis, body)
	# The rest covers the OLD drawn-art path (plain idle/run + code bounce). The player ships Pixel Plains now;
	# swapping the SpriteFrames resource back is all it takes (tests/test_player_3d_body.gd covers the new set).
	vis.rig = load("res://data/body_rigs/drawn_art.tres")   # the old character is one resource swap (rig = frames + body position + weapon fit)
	vis.bounce_mode = SpriteActorVisual.BounceMode.SMOOTH   # player.tscn tunes the bounce for the 4-frame Pixel Plains run: put the drawn-art values back
	vis.bounce_offsets = PackedFloat32Array([0, 1, 0, 0, 1, 0])
	vis.set_move_state("idle")
	var sh := vis.get_node("Shadow") as Sprite2D
	var dust = vis.get_node("RunDust")
	var rest_scale := sh.scale
	var rest_alpha := sh.modulate.a

	check("idle: shadow at full size", sh.scale == rest_scale and is_equal_approx(sh.modulate.a, rest_alpha))
	vis.set_move_state("run")
	body.pause()
	_pose(vis, body, 1.5)   # top of a bounce
	check("lifted: shadow smaller", sh.scale.x < rest_scale.x and is_equal_approx(sh.scale.x, rest_scale.x * vis.shadow_min_scale))
	check("lifted: shadow fainter", sh.modulate.a < rest_alpha)
	_pose(vis, body, 0.0)   # landing
	check("landed: shadow full size again", sh.scale == rest_scale and is_equal_approx(sh.modulate.a, rest_alpha))
	vis.shadow_on = false
	_pose(vis, body, 1.5)
	check("shadow_on=false: no breathing", sh.scale == rest_scale and is_equal_approx(sh.modulate.a, rest_alpha))
	vis.shadow_on = true

	# dust while running
	dust.clear()
	dust.dust_every_n_landings = 1
	for i in 3:
		_pose(vis, body, 1.5)
		_pose(vis, body, 0.0)
	check("running: landings spawn dust", dust.alive_count() > 0)
	dust._process(dust.dust_life + 0.1)
	check("dust dies after dust_life", dust.alive_count() == 0)

	# dust off
	dust.dust_on = false
	vis.set_move_state("idle")
	vis.set_move_state("run")   # start puff
	_pose(vis, body, 1.5)
	_pose(vis, body, 0.0)
	dust.burst(5)
	check("dust_on=false: nothing spawns", dust.alive_count() == 0)
	dust.dust_on = true

	# idle: none
	dust.clear()
	vis.set_move_state("idle")
	for i in 10:
		_pose(vis, body, 1.5)
		vis._process(0.1)
		dust._process(0.1)
	check("idle: no dust", dust.alive_count() == 0)

	# start puff and dodge puff (Dodge.used signal)
	vis.set_move_state("run")
	check("run start: puff", dust.alive_count() == dust.start_puff_count)
	dust.clear()
	player.get_node("Dodge").used.emit()
	check("dodge: puff", dust.alive_count() == dust.dodge_puff_count)
	dust.clear()
	dust.burst(dust.pool_size + 20)
	check("pool never exceeds pool_size", dust.alive_count() == dust.pool_size)
	quit(0 if _ok else 1)
