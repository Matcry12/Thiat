extends SceneTree
# Slam is UNPARRYABLE (purple): a guarding player still takes the full hit and
# the guard breaks; a player whose dodge i-frames cover the impact takes none.
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true   # no scripted decision may sneak in before the stub is set
	await process_frame
	var stub = StubBrain.new()
	boss.set_brain(stub)
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	boss.passive = false
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield_max = 0.0
	health.shield = 0.0
	var guard: Guard = player.get_node("Guard")
	guard.aim_direction = Vector2.RIGHT
	var dodge: Dodge = player.get_node("Dodge")
	dodge.burst_distance = 0.0   # isolate the i-frames: no stepping out of the circle
	var slam: BossAttack = boss.get_attack("slam")
	var dodged := [0]
	health.dodged.connect(func(): dodged[0] += 1)

	# --- A: guarding through the slam ---
	boss.force_next("slam")
	await _until(func(): return slam.phase == BossAttack.Phase.TELEGRAPH, 3.0)
	var tell_unparryable: bool = not slam.parryable
	guard.try_guard()   # held: PARRY window, then BLOCK; both lose to purple
	var hp0: float = health.hp
	# Fairness: NOTHING lands during the whole warning, and the warning lasts
	# as long as telegraph_time says.
	var tell_frames := 0
	var clean := true
	while slam.phase == BossAttack.Phase.TELEGRAPH and tell_frames < 400:
		await physics_frame
		tell_frames += 1
		if slam.phase == BossAttack.Phase.TELEGRAPH and (health.hp != hp0 or guard.tank != guard.tank_max):
			clean = false
	var tell_secs: float = tell_frames / float(Engine.physics_ticks_per_second)
	var tell_full: bool = absf(tell_secs - slam.telegraph_time) < 0.1
	print("warning lasted %.2fs (want %.2f), nothing landed during it: %s" % [tell_secs, slam.telegraph_time, clean])
	await _until(func(): return slam.phase == BossAttack.Phase.RECOVERY, 4.0)
	var lost_guarded: float = hp0 - health.hp
	var broke: bool = guard.state == Guard.State.BROKEN and guard.tank == 0.0
	print("guarded slam: lost %.1f (want %.1f), guard broken: %s, tell unparryable: %s" % [lost_guarded, slam.damage, broke, tell_unparryable])
	guard.release()
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 3.0)
	await _until(func(): return guard.state == Guard.State.READY, guard.break_recovery + 3.0)
	health.hp = health.max_hp

	# --- B: dodge i-frames cover the impact ---
	boss.force_next("slam")
	await _until(func(): return slam.phase == BossAttack.Phase.TELEGRAPH, 3.0)
	await _until(func(): return slam.phase_time() >= slam.telegraph_time - 0.1, 3.0)
	var pressed: bool = dodge.try_dodge(Vector2.ZERO, Vector2.RIGHT)
	var hp1: float = health.hp
	await _until(func(): return slam.phase == BossAttack.Phase.RECOVERY, 3.0)
	await _frames(5)
	var lost_dodged: float = hp1 - health.hp
	print("dodged slam: pressed %s, lost %.1f (want 0), dodged signals: %d" % [pressed, lost_dodged, dodged[0]])

	var ok: bool = clean and tell_full and tell_unparryable and absf(lost_guarded - slam.damage) < 0.1 and broke \
			and pressed and lost_dodged == 0.0 and dodged[0] >= 1
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
		if left <= 0.0:
			return false
	return true
