extends SceneTree
# The player's body is the 3D-rendered directional set (assets/retired/characters/player/3d/, retired): front when facing mostly down,
# side (flipped for left) otherwise, UP keeps the side (no back sprite); run/hit have their own animations; the OLD
# drawn art still loads and works by swapping the SpriteFrames resource only.
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
	var f := body.sprite_frames
	check("player ships the Pixel Plains character: plain set with only idle / run / death", not vis.is_directional() and f.has_animation(&"idle") and f.has_animation(&"run") and f.has_animation(&"death") and f.get_animation_names().size() == 3 and vis.rig.display_name.begins_with("pixel plains"))
	vis.set_facing(Vector2.LEFT)
	check("pixel plains: facing left = flip_h", body.flip_h and body.animation == &"idle")
	vis.set_facing(Vector2.RIGHT)
	check("pixel plains: facing right = not flipped", not body.flip_h)
	var hp: Health = player.get_node("Health")
	hp.take_damage(hp.hp + hp.shield + hp.armor + 1.0)
	check("death: Health.died plays the death pose", body.animation == &"death" and vis.status_text().contains("DEAD"))
	vis.set_move_state("run")
	check("death: a move state does not cut the death pose", body.animation == &"death")
	check("death plays 10 frames (stand, jump, fall, lie), not looping", f.get_frame_count(&"death") == 10 and not f.get_animation_loop(&"death"))
	vis.set_move_state("idle")
	player.respawn()
	await process_frame
	await process_frame
	check("respawn: back to idle", body.animation == &"idle" and not vis.status_text().contains("DEAD"))
	var side_rig := BodyRig.new()          # side-only set: idle_side / run_side / hit_side, no front clips
	var side_f := SpriteFrames.new()
	for an in [&"idle_side", &"run_side", &"hit_side"]:
		side_f.add_animation(an)
		side_f.add_frame(an, f.get_frame_texture(&"idle", 0))
	side_rig.sprite_frames = side_f
	vis.rig = side_rig
	vis.set_facing(Vector2.DOWN)
	check("side-only set: facing down plays idle_side", vis.is_directional() and not body.sprite_frames.has_animation(&"idle_front") and body.animation == &"idle_side")
	vis.rig = load("res://data/dev/body_rigs/blocky.tres")           # the rest of this test is about the full directional set
	check("blocky rig: directional with a front view", vis.is_directional() and body.sprite_frames.has_animation(&"run_front"))
	check("body position/scale come from the rig (feet on the origin)", body.scale == vis.rig.body_scale and body.position == vis.rig.body_position)

	vis.set_facing(Vector2.DOWN)
	check("facing down -> idle_front, not flipped", body.animation == &"idle_front" and not body.flip_h)
	vis.set_facing(Vector2.RIGHT)
	check("facing right -> idle_side, not flipped", body.animation == &"idle_side" and not body.flip_h)
	vis.set_facing(Vector2.LEFT)
	check("facing left -> idle_side, flipped", body.animation == &"idle_side" and body.flip_h)
	vis.set_facing(Vector2.UP)
	check("facing up (after left) keeps side + flip", body.animation == &"idle_side" and body.flip_h)
	vis.set_facing(Vector2.RIGHT)
	vis.set_facing(Vector2.UP)
	check("facing up (after right) keeps side, not flipped", body.animation == &"idle_side" and not body.flip_h)
	vis.set_facing(Vector2.DOWN)
	vis.set_facing(Vector2.DOWN.rotated(deg_to_rad(vis.front_half_angle_deg - 2.0)))
	check("just inside the front limit stays front", body.animation == &"idle_front")
	vis.set_facing(Vector2.DOWN.rotated(deg_to_rad(vis.front_half_angle_deg + vis.facing_hysteresis_deg + 2.0)))
	check("past the limit + hysteresis -> side", body.animation == &"idle_side")
	vis.set_facing(Vector2.DOWN.rotated(deg_to_rad(vis.front_half_angle_deg + 2.0)))
	check("border aim (inside hysteresis) does not flicker back", body.animation == &"idle_side")

	vis.set_facing(Vector2.DOWN)
	vis.set_move_state("run")
	check("run facing down -> run_front", body.animation == &"run_front")
	body.frame = 2
	vis.set_facing(Vector2.RIGHT)
	check("front -> side mid-run keeps the run and the frame", body.animation == &"run_side" and body.frame == 2)
	var holds := 0.0
	for i in body.sprite_frames.get_frame_count(&"run_side"):
		holds += body.sprite_frames.get_frame_duration(&"run_side", i) / body.sprite_frames.get_animation_speed(&"run_side")
	check("run hold times baked in (4 frames, ~0.40 s)", body.sprite_frames.get_frame_count(&"run_side") == 4 and absf(holds - 0.40) < 0.02 and is_equal_approx(body.speed_scale, 1.0))

	# jittery aim near straight up must never mirror the body (judge: 19 flips in 20 aims before the dead-zone)
	vis.set_facing(Vector2.RIGHT)
	var flips := 0
	var last: bool = body.flip_h
	for i in 40:
		vis.set_facing(Vector2(0.02 * (1 if i % 2 == 0 else -1) + 0.01 * (i % 3 - 1), -1.0).normalized())
		if body.flip_h != last:
			flips += 1
			last = body.flip_h
	check("jittered up-aims do not flip the body (%d flips)" % flips, flips == 0 and body.animation == &"run_side")
	vis.set_facing(Vector2.RIGHT)

	# RunDust gets its landing event from the baked frames; the shadow shrinks on the baked "up" frames.
	var landings := [0]
	vis.landed.connect(func(): landings[0] += 1)
	body.pause()
	body.frame = 0
	vis._process(0.0)
	body.frame = vis.landing_frames[0]
	vis._process(0.0)
	check("run landing frame emits landed (dust)", landings[0] == 1)
	var sh := vis.get_node("Shadow") as Sprite2D
	var rest := sh.scale
	body.frame = vis.lift_frames[0]
	vis._process(0.0)
	check("up frame shrinks the shadow", sh.scale.x < rest.x)
	body.frame = 0
	vis._process(0.0)
	check("contact frame: shadow back to full", is_equal_approx(sh.scale.x, rest.x))

	# hit pose
	body.play(&"run_side")
	vis.flash(Color.WHITE, 0.1)
	check("a hit plays hit_side", body.animation == &"hit_side")
	vis.set_move_state("run")
	check("move state during the hit does not cut it short", body.animation == &"hit_side")
	vis._process(1.0)
	check("after the hit, back to run_side", body.animation == &"run_side")
	vis.set_move_state("idle")
	vis.set_facing(Vector2.DOWN)
	vis.flash(Color.WHITE, 0.1)
	# stuck-hit guard: even if the timer is gone, a leftover hit anim resolves back
	vis._hit_left = 0.0
	vis._process(0.0)
	check("a leftover hit anim resolves back to idle", body.animation == &"idle_front")
	vis.flash(Color.WHITE, 0.1)
	check("a hit facing down plays hit_front", body.animation == &"hit_front")
	check("F3 status shows facing", vis.status_text().contains("facing: front"))

	# the older characters are ONE resource swap (rig = frames + body position + shadow + weapon/hand fit)
	vis.rig = load("res://data/dev/body_rigs/drawn_art.tres")
	vis.set_move_state("run")
	check("old drawn art rig: not directional, plain run plays", not vis.is_directional() and body.animation == &"run" and body.position == Vector2(0, -19))
	vis.set_facing(Vector2.LEFT)
	check("old art: left = flip_h", body.flip_h)
	vis.set_facing(Vector2.DOWN)
	check("old art: facing down keeps the last flip", body.flip_h)
	vis.rig = load("res://data/dev/body_rigs/blocky.tres")
	check("back to blocky", vis.is_directional() and vis.rig.display_name.begins_with("blocky"))
	quit(0 if _ok else 1)
