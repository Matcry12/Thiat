extends SceneTree
# Charge is parryable (orange). A timed parry negates it and STAGGERS the boss:
# it drops the attack, stands still and makes no decision for the stagger time.
# Control: an un-parried charge hurts exactly once.
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
	boss.global_position = Vector2(800, 321)
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield_max = 0.0
	health.shield = 0.0
	var guard: Guard = player.get_node("Guard")
	guard.aim_direction = Vector2.RIGHT
	var charge: BossAttack = boss.get_attack("charge")
	var dmg_events := [0]
	health.damaged.connect(func(_a: float): dmg_events[0] += 1)

	# --- A: no guard. Hurts once. ---
	boss.force_next("charge")
	await _until(func(): return boss.current_action == "charge", 3.0)
	var hp0: float = health.hp
	await _until(func(): return boss.mode == Boss.Mode.IDLE and boss.current_action == "", 6.0)
	await _frames(10)
	var lost: float = hp0 - health.hp
	print("un-parried charge: lost %.1f (want %.1f) in %d hit(s)" % [lost, charge.damage, dmg_events[0]])
	var once: bool = absf(lost - charge.damage) < 0.1 and dmg_events[0] == 1

	# --- B: parry it ---
	health.hp = health.max_hp
	dmg_events[0] = 0
	boss.global_position = Vector2(800, 321)
	await _frames(3)
	boss.force_next("charge")
	await _until(func(): return charge.phase == BossAttack.Phase.ACTIVE, 3.0)
	# Press when the boss is ~0.15 s from impact (window is 0.25 s).
	await _until(func(): return boss.global_position.distance_to(player.global_position) < 130.0, 3.0)
	guard.try_guard()
	var hp1: float = health.hp
	var parried := [false]
	guard.parried.connect(func(_s: Node): parried[0] = true)
	var staggered: bool = await _until(func(): return boss.mode == Boss.Mode.STAGGER, 2.0)
	var pos: Vector2 = boss.global_position
	var frames := 0
	while boss.mode == Boss.Mode.STAGGER and frames < 200:
		await physics_frame
		frames += 1
	var still: bool = boss.global_position.distance_to(pos) < 0.5
	var secs: float = frames / float(Engine.physics_ticks_per_second)
	print("parried: %s, staggered: %s, hp lost %.1f, no action during stagger: %s, stagger lasted ~%.2fs (guard.stagger_time %.2f)" % [parried[0], staggered, hp1 - health.hp, boss.current_action == "" and still, secs, guard.stagger_time])
	var ok: bool = once and staggered and parried[0] and health.hp == hp1 and still \
			and absf(secs - guard.stagger_time) < 0.15
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
