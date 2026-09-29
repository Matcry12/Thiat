extends SceneTree
# Boss bolts: the training Dummy (a body with a Hurtbox on another layer) is NOT
# a shield; and bolts still in the air vanish when the boss dies.
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	boss.set_brain(StubBrain.new())
	boss.passive = false
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield_max = 0.0
	health.shield = 0.0
	var dummy = arena.get_node("Dummy")
	var dummy_hp: float = dummy.get_node("Health").hp
	boss.global_position = Vector2(900, 321)
	dummy.global_position = Vector2(650, 321)   # right on the firing line
	var spread: BossAttack = boss.get_attack("spread")

	boss.force_next("spread")
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _until(func(): return get_nodes_in_group("projectile").is_empty(), 4.0)
	var lost: float = health.max_hp - health.hp
	var untouched: bool = dummy.get_node("Health").hp == dummy_hp
	print("dummy on the line: player lost %.1f (want >= %.1f), dummy untouched: %s" % [lost, spread.damage, untouched])
	var shield_ok: bool = lost >= spread.damage - 0.01 and untouched
	await _until(func(): return boss.mode == Boss.Mode.IDLE, 3.0)

	# --- boss dies with bolts in the air ---
	dummy.global_position = Vector2(700, 130)
	health.hp = health.max_hp
	boss.force_next("spread")
	await _until(func(): return spread.phase == BossAttack.Phase.ACTIVE, 3.0)
	await _frames(3)
	var in_air: int = get_nodes_in_group("projectile").size()
	boss.health.take_damage(100000.0)
	await _frames(2)
	var left: int = get_nodes_in_group("projectile").size()
	await _frames(120)
	print("boss died with %d bolts flying -> %d left, player hp %.0f/%.0f" % [in_air, left, health.hp, health.max_hp])
	var freed: bool = in_air > 0 and left == 0 and health.hp == health.max_hp

	var ok: bool = shield_ok and freed
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
