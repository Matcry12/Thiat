extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
# The boss is solid: the player cannot walk through an idle boss, and a charge
# ends NEXT to the player (hurting once), never on top of him.
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = ClassicArena.make()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.aim_override = Vector2.RIGHT
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	boss.global_position = Vector2(700, 321)

	# --- A: walk right into the idle boss for a while ---
	Input.action_press("move_right")
	await _frames(120)
	Input.action_release("move_right")
	var gap_a: float = boss.global_position.x - player.global_position.x
	var solid: bool = gap_a > 30.0
	print("walked into boss: gap %.1f px (bodies touch at ~39)" % gap_a)

	# --- B: a charge at the player ends beside him, not on him ---
	boss.set_brain(StubBrain.new())
	boss.passive = false
	player.global_position = Vector2(409, 321)
	boss.global_position = Vector2(800, 321)
	player.set_physics_process(false)
	await _frames(3)
	var events := [0]
	health.damaged.connect(func(_a: float): events[0] += 1)
	boss.force_next("charge")
	await _until(func(): return boss.current_action == "charge", 3.0)
	await _until(func(): return boss.current_action == "", 6.0)
	await _frames(5)
	var gap_b: float = boss.global_position.distance_to(player.global_position)
	var r_boss: float = (boss.get_node("CollisionShape2D").shape as CircleShape2D).radius
	var r_pl: float = (player.get_node("CollisionShape2D").shape as CircleShape2D).radius
	var apart: bool = gap_b >= r_boss + r_pl - 1.0
	print("after charge: centres %.1f px apart (need >= %.1f), hits: %d" % [gap_b, r_boss + r_pl - 1.0, events[0]])

	var ok: bool = solid and apart and events[0] == 1
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
