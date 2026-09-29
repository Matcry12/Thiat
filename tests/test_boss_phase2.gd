extends SceneTree
# Phase 2 (at 60% hp) unlocks ONE new move, "ring". Above 60% the boss refuses
# it even when its brain asks; the scripted brain never picks it in phase 1.
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
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Health").immortal = true
	var started: Array = []
	boss.action_started.connect(func(a: String): started.append(a))
	var phases: Array = []
	boss.phase_changed.connect(func(p: int): phases.append(p))

	# Phase 1: the brain begs for "ring"; the boss must refuse (10 asks).
	stub.answer = "ring"
	await _frames(150)
	var refused: bool = started.is_empty() and stub.calls >= 5 and boss.phase == 1
	print("phase 1: brain asked %d times for ring, started %s" % [stub.calls, started])

	# Exactly 61% is still phase 1; at 60% phase 2 starts.
	boss.health.hp = boss.health.max_hp * 0.61
	await _frames(10)
	var still1: bool = boss.phase == 1
	boss.health.hp = boss.health.max_hp * 0.60
	var got2: bool = await _until(func(): return boss.phase == 2, 1.0)
	var ring_ran: bool = await _until(func(): return started.has("ring"), 3.0)
	var ring: BossAttack = boss.get_attack("ring")
	var tell2: Node2D = ring.get_node("Telegraph2")
	var second_shown: bool = tell2.visible and tell2.modulate.a < 1.0
	print("phase 2: second ring outline shown from the first warning: %s" % second_shown)
	print("phase 2: reached %s, ring started %s, phase signals %s" % [got2, ring_ran, phases])

	# The scripted brain: ring only ever offered in phase 2.
	var sb := ScriptedBrain.new()
	sb.rng.seed = 7
	var st := {"hp_fraction": 1.0, "phase": 1, "player_distance": 200.0, "player_angle": 0.0, "player_weapon": "arc",
			"cooldowns": {"slam": 0.0, "spread": 0.0, "charge": 0.0, "ring": 0.0}, "enraged": false}
	var ring_p1 := 0
	var ring_p2 := 0
	for i in 200:
		st["phase"] = 1
		if sb.choose_action(st) == "ring":
			ring_p1 += 1
		st["phase"] = 2
		if sb.choose_action(st) == "ring":
			ring_p2 += 1
	sb.free()
	print("scripted brain: ring in phase 1 x%d (want 0), in phase 2 x%d (want >0)" % [ring_p1, ring_p2])

	var ok: bool = second_shown and refused and still1 and got2 and ring_ran and phases == [2] and ring_p1 == 0 and ring_p2 > 0
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
