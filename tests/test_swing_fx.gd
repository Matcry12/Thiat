extends SceneTree
# The slash shows effect nodes during ACTIVE and leaves none
# behind shortly after RECOVERY; the slash follows the
# swing when aiming left (its fat end sits where the blade FINISHES).
var _holder: WeaponHolder
var _fx: SwingFx

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	for i in 3: await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)          # headless mouse sits at (0,0)
	_holder = player.get_node("WeaponHolder")
	_fx = player.get_node("WeaponVisual/SwingFx")
	var wv = player.get_node("WeaponVisual")
	var ok := true
	wv.weapon.swing_motion.crescent_on = true   # this test is about the crescent (0049: the natural swing turns it off)

	wv.set_aim_angle(0.0)
	_holder.try_attack()
	await _until_phase(WeaponHolder.Phase.ACTIVE)
	await _frames(3)
	var during := _fx.get_child_count()
	await _until_phase(WeaponHolder.Phase.IDLE)
	await _frames(15)                       # 0.25 s of grace after recovery
	var after := _fx.get_child_count()
	var good: bool = during > 0 and after == 0
	print("slash nodes during active: %d, after recovery: %d  %s" % [during, after, good])
	ok = ok and good

	# Aim left: the crescent's fat point must be on the side the blade ends on.
	for angle in [0.0, PI]:
		wv.set_aim_angle(angle)
		await _frames(2)
		_holder.try_attack()
		var tip: Node2D = wv.get_model().get_node("Hitbox/CollisionShape2D")
		await _frames(3)
		var start_tip := tip.global_position      # pulled back, before the snap
		await _until_phase(WeaponHolder.Phase.ACTIVE)
		await _frames(1)
		# The crescent is fattest late in the sweep, so the centre of its blocks sits
		# toward where the blade finishes. Read it now: the slash fades before the swing ends.
		var blocks = _fx.get_node("Slash")
		var centre := Vector2.ZERO
		for c in blocks.cells:
			centre += c + Vector2.ONE * blocks.px * 0.5
		centre /= blocks.cells.size()
		var end_tip := start_tip
		while _holder.phase == WeaponHolder.Phase.ACTIVE:
			end_tip = tip.global_position
			await physics_frame
		# Which way the blade turned (+1/-1) vs. which side of the aim line the bulk sits on.
		var origin: Vector2 = wv.global_position
		var turned := signf((start_tip - origin).cross(end_tip - origin))
		var bulk_side := signf(Vector2.from_angle(angle).cross(centre - origin))
		var follows: bool = turned != 0.0 and turned == bulk_side
		print("aim %.0f deg: bulk nearer the blade's finish: %s" % [rad_to_deg(angle), follows])
		ok = ok and follows
		await _until_phase(WeaponHolder.Phase.IDLE)
		await _frames(15)

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _until_phase(p: int) -> void:
	var guard := 0
	while _holder.phase != p and guard < 300:
		await physics_frame
		guard += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
