extends SceneTree
# Temp Tiny RPG art (decision 0032): the player's rig carries the Soldier frames, the boss visual carries the Orc frames,
# and attack animation timing follows the attack DATA (telegraph / active / recovery), never the other way round.
var _ok := true
func check(name: String, cond: bool) -> void:
	print("%s: %s" % [name, "ok" if cond else "FAIL"])
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var vis: SpriteActorVisual = player.get_node("Visual")
	var body := vis.get_node("Body") as AnimatedSprite2D
	var f := body.sprite_frames
	check("player rig = tiny soldier", vis.rig.resource_path.ends_with("tiny_soldier.tres"))
	check("soldier frames: idle 6, run 8, hit 4, death 4", f.get_frame_count(&"idle_side") == 6 and f.get_frame_count(&"run_side") == 8 and f.get_frame_count(&"hit_side") == 4 and f.get_frame_count(&"death_side") == 4)
	check("soldier frames are 100x100 cells from the tiny_rpg folder", f.get_frame_texture(&"idle_side", 0).get_size() == Vector2(100, 100) and (f.get_frame_texture(&"idle_side", 0) as AtlasTexture).atlas.resource_path.contains("tiny_rpg"))
	check("pixel art stays whole-pixel: body scale is an integer", body.scale == Vector2(3, 3) and body.texture_filter == CanvasItem.TEXTURE_FILTER_PARENT_NODE)
	vis.set_facing(Vector2.LEFT)
	check("left = flipped", body.flip_h)
	vis.set_move_state("run")
	check("run plays run_side", body.animation == &"run_side")
	vis.flash(Color.WHITE, 0.1)
	check("hit plays hit_side", body.animation == &"hit_side")
	check("F3 status names the rig", vis.status_text().contains("tiny soldier"))

	var bv: BossVisual = boss.visual
	var ob := bv.get_node("Body") as AnimatedSprite2D
	check("boss uses the orc frames", bv.has_body() and ob.sprite_frames.has_animation(&"attack1") and ob.sprite_frames.get_frame_count(&"idle") == 6 and ob.sprite_frames.get_frame_count(&"run") == 8)
	check("orc scale is a whole number and from the visual (F3 export)", ob.scale == bv.body_scale and is_equal_approx(bv.body_scale.x, roundf(bv.body_scale.x)))
	check("orc is not drawn as the placeholder circle", bv.has_body())
	bv.set_move_state("run")
	check("moving boss plays run", ob.animation == &"run")
	bv.set_facing(Vector2.LEFT)
	check("boss faces left = flipped", ob.flip_h)
	bv.set_move_state("idle")

	# attack windows: telegraph fills frames [0, strike), active [strike, recover), recovery [recover, end)
	var sl := boss.get_attack("slam")
	bv.set_attack_phase("slam", BossAttack.Phase.TELEGRAPH, sl.telegraph_time)
	check("telegraph starts the attack clip on frame 0", ob.animation == &"attack1" and ob.frame == 0)
	bv._atk_t = sl.telegraph_time * 0.99
	bv._drive_attack()
	check("end of telegraph = last windup frame, not the strike", ob.frame == bv.strike_frame - 1)
	bv.set_attack_phase("slam", BossAttack.Phase.ACTIVE, sl.active_time)
	check("active = the strike frame", ob.frame == bv.strike_frame)
	bv.set_attack_phase("slam", BossAttack.Phase.RECOVERY, sl.recovery_time)
	check("recovery = follow-through frame", ob.frame == bv.recover_frame)
	bv.set_attack_phase("slam", 0, 0.0)
	check("attack over -> back to idle", ob.animation == &"idle")
	sl.telegraph_time = 2.0    # data changed: the window is now longer, the animation just stretches
	bv.set_attack_phase("slam", BossAttack.Phase.TELEGRAPH, sl.telegraph_time)
	bv._atk_t = 1.0
	bv._drive_attack()
	check("longer telegraph (data) stretches the animation (half time = middle frame)", ob.frame == int(0.5 * bv.strike_frame))
	bv.set_attack_phase("slam", 0, 0.0)

	# the real signal chain: BossAttack.phase_changed -> visual
	sl.telegraph_time = 0.2
	boss.passive = false
	boss.force_next("slam")
	boss._set_aggro(Boss.Aggro.ENGAGED)
	for i in 120:
		await physics_frame
		if sl.phase == BossAttack.Phase.TELEGRAPH:
			break
	await process_frame
	check("a real slam telegraph drives the clip", sl.phase == BossAttack.Phase.TELEGRAPH and ob.animation == &"attack1")
	boss.passive = true
	for i in 200:
		await physics_frame
		if sl.phase == BossAttack.Phase.IDLE:
			break
	await process_frame
	check("cancelled / finished attack returns the orc to idle or run", ob.animation == &"idle" or ob.animation == &"run")

	# charge: the dash loops the run clip for the whole (distance / speed) window, ends on the real recovery signal, facing locked
	var ch := boss.get_attack("charge")
	check("charge ACTIVE window = distance / speed (data), not active_time", is_equal_approx(ch._window_time(BossAttack.Phase.ACTIVE), ch.distance / ch.speed))
	bv.set_attack_phase("charge", BossAttack.Phase.TELEGRAPH, ch.telegraph_time)
	bv.set_attack_phase("charge", BossAttack.Phase.ACTIVE, ch._window_time(BossAttack.Phase.ACTIVE))
	check("charge dash loops the run clip", ob.animation == &"run" and ob.is_playing() and ob.sprite_frames.get_animation_loop(&"run"))
	bv._atk_t = 99.0
	bv._process(0.1)
	check("the dash does not freeze when the window time is over", ob.animation == &"run" and ob.is_playing())
	bv.set_attack_phase("charge", BossAttack.Phase.RECOVERY, ch.recovery_time)
	check("recovery after the dash = follow-through frame of the attack clip", ob.animation == &"attack1" and ob.frame == bv.recover_frame)
	bv.set_attack_phase("charge", 0, 0.0)
	check("a charge locks facing to its lane, none when idle", ch.facing_dir() == Vector2.ZERO and boss.get_attack("slam").facing_dir() == Vector2.ZERO)
	ch._dir = Vector2.LEFT
	ch.phase = BossAttack.Phase.ACTIVE
	check("... and returns the lane direction while it runs", ch.facing_dir() == Vector2.LEFT)
	ch.phase = BossAttack.Phase.IDLE

	# ring: the second blast replays the wind-up and the strike (TELEGRAPH and ACTIVE are each signalled twice)
	var ring := boss.get_attack("ring")
	ring.telegraph_time = 0.1
	ring.second_telegraph_time = 0.1
	ring.active_time = 0.05
	ring.recovery_time = 0.05
	var seen: Array = []
	ring.phase_changed.connect(func(_a: String, ph: int, _d: float): seen.append(ph))
	boss.passive = false
	boss._set_aggro(Boss.Aggro.ENGAGED)
	boss.force_next("ring")
	for i in 400:
		await physics_frame
		if seen.size() >= 6:
			break
	boss.passive = true
	check("ring signals telegraph, strike, telegraph, strike, recovery, over (%s)" % [seen], seen.slice(0, 6) == [1, 2, 1, 2, 3, 0])
	for i in 100:
		await physics_frame

	# F3: clearing / setting body_frames mid-attack must not leave the orc frozen in a pose
	var frames := bv.body_frames
	bv.set_attack_phase("slam", BossAttack.Phase.TELEGRAPH, 1.0)
	bv.body_frames = null
	bv.set_attack_phase("slam", 0, 0.0)           # the attack ends while the body is cleared
	bv.body_frames = frames
	check("frames set again after the attack ended -> idle, not the old attack pose", ob.animation == &"idle" and ob.is_playing())
	bv.set_attack_phase("slam", BossAttack.Phase.TELEGRAPH, 1.0)
	bv.body_frames = null
	bv.body_frames = frames
	check("frames set again while an attack still runs -> the attack clip resumes", ob.animation == &"attack1")
	bv.set_attack_phase("slam", 0, 0.0)
	check("run threshold is an export on the boss", "run_anim_speed" in boss)
	bv.set_facing(Vector2.LEFT)
	var off_left := ob.offset.x
	bv.set_facing(Vector2.RIGHT)
	check("feet offset flips sign with the facing (feet stay on the shadow)", off_left > 0.0 and ob.offset.x < 0.0 and is_equal_approx(off_left, -ob.offset.x))

	bv.set_defeated()
	check("defeat plays the death clip", ob.animation == &"death")
	bv.body_frames = null
	check("clearing body_frames falls back to the placeholder circle", not bv.has_body() and not ob.visible)
	quit(0 if _ok else 1)
