extends SceneTree
const ClassicArena = preload("res://tests/support/classic_arena.gd")
# The Brain boundary: the boss runs with ANY Brain (a stub that always says
# "idle"), hands it the documented state Dictionary, survives nonsense answers,
# and boss.gd never names the concrete scripted brain.
const StubBrain = preload("res://tests/support/stub_brain.gd")

func _init():
	var arena = ClassicArena.make()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	await process_frame
	var stub = StubBrain.new()
	boss.set_brain(stub)
	boss.passive = false
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var started: Array = []
	boss.action_started.connect(func(a: String): started.append(a))
	var pos: Vector2 = boss.global_position

	await _frames(150)
	var idle_ok: bool = started.is_empty() and boss.mode == Boss.Mode.IDLE and boss.global_position == pos and stub.calls >= 5
	print("idle stub: %d decisions, actions started %s, boss stayed put: %s" % [stub.calls, started, boss.global_position == pos])

	var s: Dictionary = stub.last_state
	var keys_ok := true
	for k in ["hp_fraction", "phase", "player_distance", "player_angle", "player_weapon", "cooldowns"]:
		if not s.has(k):
			keys_ok = false
			print("MISSING state key: ", k)
	var types_ok: bool = keys_ok and s["hp_fraction"] is float and s["phase"] is int and s["player_distance"] is float 			and s["player_angle"] is float and s["player_weapon"] is String and s["cooldowns"] is Dictionary
	var cds_ok: bool = types_ok and s["cooldowns"].has("slam") and s["cooldowns"].has("spread") 			and s["cooldowns"].has("charge") and s["cooldowns"].has("ring")
	var dist_ok: bool = types_ok and absf(s["player_distance"] - boss.global_position.distance_to(player.global_position)) < 1.0
	print("state: ", s)

	# Nonsense / impossible answers are no-ops, never crashes.
	for answer in ["banana", "ring", ""]:
		stub.answer = answer
		await _frames(40)
	var noop_ok: bool = started.is_empty()

	# A real ask works through the very same door.
	stub.answer = "slam"
	var slam_ok: bool = await _until(func(): return started.has("slam"), 2.0)

	var src := FileAccess.get_file_as_string("res://scripts/boss.gd")
	var decoupled: bool = not src.contains("ScriptedBrain")
	print("boss.gd names ScriptedBrain: %s" % (not decoupled))

	var ok: bool = idle_ok and types_ok and cds_ok and dist_ok and noop_ok and slam_ok and decoupled
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
