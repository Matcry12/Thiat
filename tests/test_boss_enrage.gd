extends SceneTree
# Enrage: player outside the FightZone for more than enrage_delay -> the boss
# enrages and keeps charging at 2x speed; back inside -> calm again.
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	var stub = StubBrain.new()
	boss.set_brain(stub)
	boss.passive = false
	boss.enrage_delay = 0.5
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Health").immortal = true
	var charge: BossAttack = boss.get_attack("charge")
	var charges := [0]
	boss.action_started.connect(func(a: String): if a == "charge": charges[0] += 1)

	# Calm baseline: one forced charge, measure dash speed.
	boss.global_position = Vector2(800, 321)
	await _frames(3)
	boss.force_next("charge")
	var calm_v: float = await _dash_speed(boss, charge)
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 3.0)

	# Player steps out of the zone (x < 136). Boss brain: the real one.
	player.global_position = Vector2(80, 321)
	boss.global_position = Vector2(700, 321)
	boss.set_brain(ScriptedBrain.new())
	var t0 := 0
	var got: bool = await _until(func(): return boss.enraged, 2.5)
	print("enraged after %.2fs outside (delay %.2f): %s" % [boss.outside_time, boss.enrage_delay, got])
	var late: bool = boss.outside_time > boss.enrage_delay
	charges[0] = 0
	var rage_v: float = await _dash_speed(boss, charge)
	await _until(func(): return charges[0] >= 2, 6.0)
	print("dash speed calm %.0f px/s, enraged %.0f px/s; charges while enraged: %d" % [calm_v, rage_v, charges[0]])

	# Back inside: calm again, timer reset.
	player.global_position = Vector2(409, 321)
	var calm: bool = await _until(func(): return not boss.enraged, 1.0)
	print("back inside: calm %s, outside_time %.2f" % [calm, boss.outside_time])

	# Enraged with the charge on cooldown: the brain chases, it does not stand still.
	var sb := ScriptedBrain.new()
	var st := {"hp_fraction": 1.0, "phase": 1, "player_distance": 300.0, "player_angle": 0.0, "player_weapon": "arc",
			"cooldowns": {"slam": 0.0, "spread": 0.0, "charge": 2.0, "ring": 0.0}, "enraged": true}
	var chase_ok: bool = sb.choose_action(st) == "chase"
	st["cooldowns"]["charge"] = 0.0
	chase_ok = chase_ok and sb.choose_action(st) == "charge"
	sb.free()
	print("enraged, charge on cooldown -> chase: %s" % chase_ok)

	var ok: bool = chase_ok and got and late and calm_v > 400.0 and calm_v < 600.0 and rage_v > 1.8 * calm_v 			and charges[0] >= 2 and calm and boss.outside_time == 0.0
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

## Average speed of the boss over the next charge's ACTIVE (dash) frames.
func _dash_speed(boss: Boss, charge: BossAttack) -> float:
	await _until(func(): return charge.phase == BossAttack.Phase.ACTIVE, 6.0)
	var start: Vector2 = boss.global_position
	var frames := 0
	while charge.phase == BossAttack.Phase.ACTIVE and frames < 300:
		await physics_frame
		frames += 1
	return start.distance_to(boss.global_position) / (frames / float(Engine.physics_ticks_per_second))

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
