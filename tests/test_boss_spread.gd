extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
# Spread: 5 bolts in a fan. They hit the PLAYER (boss projectiles use the
# player's hurtbox layer), a block absorbs them into the guard tank, and a timed
# parry negates that bolt WITHOUT staggering the boss (a bolt is its own source).
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = ClassicArena.make()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	boss.set_brain(StubBrain.new())
	boss.passive = false
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	player.get_node("Knockback").enabled = false   # the bolts' shove would move the target mid-test
	boss.global_position = Vector2(900, 321)
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield_max = 0.0
	health.shield = 0.0
	var guard: Guard = player.get_node("Guard")
	guard.aim_direction = Vector2.RIGHT
	var spread: SpreadAttack = boss.get_attack("spread")
	# Body shape off: only the player's HURTBOX (layer 2) can be hit, so the
	# bolt must be aimed at that layer, not at the world/enemy layers.
	player.get_node("CollisionShape2D").disabled = true

	# --- A: no guard. Bolts are fired (count) and reach the player. ---
	boss.force_next("spread")
	var fired := [0]
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await physics_frame
	fired[0] = get_nodes_in_group("projectile").size()
	await _until(func(): return get_nodes_in_group("projectile").is_empty(), 4.0)
	var lost_a: float = health.max_hp - health.hp
	print("fan: %d bolts fired (want %d); unguarded player lost %.1f (bolt dmg %.1f)" % [fired[0], spread.count, lost_a, spread.damage])
	var hit_ok: bool = fired[0] == spread.count and lost_a >= spread.damage - 0.01
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 3.0)

	# --- B: hold the guard: the tank soaks the bolt, hp untouched. ---
	health.hp = health.max_hp
	guard.try_guard()
	await _until(func(): return guard.state == Guard.State.BLOCK, 2.0)
	boss.force_next("spread")
	var tank0: float = guard.tank
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _until(func(): return get_nodes_in_group("projectile").is_empty(), 4.0)
	var block_ok: bool = health.hp == health.max_hp and guard.tank < tank0
	print("blocked: hp lost %.1f, tank %.0f -> %.0f" % [health.max_hp - health.hp, tank0, guard.tank])
	guard.release()
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 3.0)
	await _until(func(): return guard.state == Guard.State.READY, 3.0)

	# --- C: parry the bolt as it arrives: negated, boss staggered. ---
	health.hp = health.max_hp
	boss.force_next("spread")
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _until(func(): return _nearest_bolt_x() < player.global_position.x + 70.0, 4.0)
	guard.try_guard()
	var parried := [false]
	guard.parried.connect(func(_s: Node): parried[0] = true)
	var staggered := false
	while not get_nodes_in_group("projectile").is_empty():
		await physics_frame
		if boss.mode == Boss.Mode.STAGGER:
			staggered = true
	var parry_ok: bool = parried[0] and not staggered and health.hp == health.max_hp
	print("parried bolt: parried %s, boss staggered %s (want false), hp lost %.1f" % [parried[0], staggered, health.max_hp - health.hp])

	var ok: bool = hit_ok and block_ok and parry_ok
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _nearest_bolt_x() -> float:
	var best := 99999.0
	for p in get_nodes_in_group("projectile"):
		best = minf(best, p.global_position.x)
	return best

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
