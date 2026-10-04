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
	check("no code bob on an animated body", body.position == Vector2(0, -19))
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
