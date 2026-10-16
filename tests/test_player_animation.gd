extends SceneTree
# The player's body is animated: moving plays run, standing plays idle, facing left flips, the hit flash
# and the previous-material restore still work, and the user's frame counts are 2 (idle) and 6 (run).
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
	player.set_physics_process(false)
	var vis: SpriteActorVisual = player.get_node("Visual")
	var body := vis.get_node("Body") as AnimatedSprite2D
	# This test covers the OLD drawn-art path (plain idle/run + code bounce). The player ships the 3D body sheets now;
	# swapping the SpriteFrames resource back is all it takes (tests/test_player_3d_body.gd covers the new set).
	vis.rig = load("res://data/body_rigs/drawn_art.tres")   # the old character is one resource swap (rig = frames + body position + weapon fit)
	vis.set_move_state("idle")
	check("Body is an AnimatedSprite2D", body != null)
	check("frame counts: idle 2, run 6", body.sprite_frames.get_frame_count(&"idle") == 2 and body.sprite_frames.get_frame_count(&"run") == 6)
	check("starts on idle", body.animation == &"idle" and body.is_playing())
	check("scale 2, position (0,-19) kept", body.scale == Vector2(2, 2) and body.position == Vector2(0, -19))

	vis.set_move_state("run")
	check("moving plays run at run_fps", body.animation == &"run" and is_equal_approx(body.sprite_frames.get_animation_speed(&"run") * body.speed_scale, vis.run_fps))
	vis.run_fps = 20.0
	vis.set_move_state("run")
	check("run_fps export changes the speed", is_equal_approx(body.sprite_frames.get_animation_speed(&"run") * body.speed_scale, 20.0))
	await process_frame
	check("no code bob on an animated body", body.position == Vector2(0, -19) or body.frame != 0)
	await _bounce_tests(vis, body)
	vis.set_move_state("idle")
	check("standing plays idle at idle_fps", body.animation == &"idle" and is_equal_approx(body.sprite_frames.get_animation_speed(&"idle") * body.speed_scale, vis.idle_fps))
	check("F3 status shows the animation", vis.status_text().contains("anim: idle"))

	vis.set_facing(Vector2.LEFT)
	check("facing left flips", body.flip_h)
	vis.set_facing(Vector2.RIGHT)
	check("facing right unflips", not body.flip_h)

	vis.set_weapon_state("windup")
	check("windup tint applies", body.modulate == Color.YELLOW)
	vis.set_weapon_state("idle")

	var mine := ShaderMaterial.new()
	body.material = mine
	vis.flash(Color.WHITE, 0.05)
	check("flash puts the shader on the animated body", body.material != mine and body.material != null)
	for i in 10:
		await process_frame
	await create_timer(0.2).timeout
	check("flash restores the previous material", body.material == mine)

	quit(0 if _ok else 1)

func _bounce_tests(vis: SpriteActorVisual, body: AnimatedSprite2D) -> void:
	var rest := Vector2(0, -19)
	vis.set_move_state("run")
	await _smooth_tests(vis, body)
	vis.bounce_mode = SpriteActorVisual.BounceMode.STEPPED
	body.pause()   # we pick the frame ourselves
	var ok_map := true
	var ok_whole := true
	for f in 6:
		body.frame = f
		vis._process(0.0)
		var up := -(body.position.y - rest.y) / 2.0   # art px (scale 2)
		if not is_equal_approx(up, vis.bounce_offsets[f] * vis.bounce_px) and not vis.squash_frames.has(f):
			ok_map = false
		if not is_equal_approx(up, roundf(up)) and not vis.squash_frames.has(f):
			ok_whole = false
	check("run bounce follows the per-frame mapping", ok_map)
	check("bounce is whole art pixels with snap on", ok_whole)
	vis.bounce_px = 1.4
	body.frame = 1
	vis._process(0.0)
	check("snap rounds 1.4 art px to 1", is_equal_approx(rest.y - body.position.y, 2.0))
	vis.bounce_px = 1.0

	# squash keeps the feet row: feet world y = position.y + (feet_row - 16) * scale.y, bounce excluded (frame 0 lift 0)
	vis.squash_on = true
	var feet_base := rest.y + (vis.feet_row - 16.0) * 2.0
	body.frame = 0
	vis._last_frame = -1
	vis._process(0.0)
	check("squash on a landing frame changes scale", body.scale.x > 2.0 and body.scale.y < 2.0)
	check("squash keeps the feet row constant", is_equal_approx(body.position.y + (vis.feet_row - 16.0) * body.scale.y, feet_base))
	vis._process(vis.squash_time + 0.01)
	check("squash fades back to base scale", body.scale.is_equal_approx(Vector2(2, 2)))
	vis.squash_on = false
	vis._last_frame = -1
	vis._process(0.0)
	check("squash_on=false keeps scale", body.scale == Vector2(2, 2))
	vis.squash_on = true

	vis.run_bounce_on = false
	body.frame = 1
	vis._process(0.0)
	check("run_bounce_on=false gives offset 0", body.position == rest and body.scale == Vector2(2, 2))
	vis.run_bounce_on = true

	body.frame = 0
	vis._last_frame = -1
	vis._process(0.0)
	vis.set_move_state("idle")
	check("stopping resets position and scale at once", body.position == rest and body.scale == Vector2(2, 2))
	vis._process(0.1)
	check("idle has no offset", body.position == rest and body.scale == Vector2(2, 2))
	vis.set_move_state("run")
	body.play()

func _smooth_tests(vis: SpriteActorVisual, body: AnimatedSprite2D) -> void:
	var rest_y := -19.0
	body.pause()
	var cycle := 6.0 / vis.run_fps   # seconds
	var prev := 0.0
	var worst := 0.0
	var peak := 0.0
	var whole := true
	var t := 0.0
	while t < cycle * 2.0:
		var ph := fposmod(t * vis.run_fps, 6.0)
		body.frame = int(ph)
		body.frame_progress = ph - floorf(ph)
		vis._process(0.0)
		var lift := rest_y - body.position.y   # world px
		worst = maxf(worst, absf(lift - prev) if t > 0.0 else 0.0)
		prev = lift
		peak = maxf(peak, lift)
		if not is_equal_approx(lift, roundf(lift)):
			whole = false
		t += 1.0 / 60.0
	check("smooth: no jump over 1 world px between physics frames (worst %.1f)" % worst, worst <= 1.0)
	check("smooth: reaches the amplitude (peak %.1f)" % peak, peak >= vis.bounce_amp_px - 1.0 and peak <= vis.bounce_amp_px)
	check("smooth: whole world px with WORLD_PX snap", whole)
	vis.snap_mode = SpriteActorVisual.SnapMode.NONE
	body.frame = 1
	body.frame_progress = 0.37
	vis._process(0.0)
	var raw := rest_y - body.position.y
	check("smooth: snap NONE gives fractional lift", not is_equal_approx(raw, roundf(raw)))
	vis.snap_mode = SpriteActorVisual.SnapMode.WORLD_PX
	vis.set_move_state("idle")
	check("smooth: stopping resets at once", body.position == Vector2(0, rest_y) and body.scale == Vector2(2, 2))
	vis.set_move_state("run")
	body.pause()
