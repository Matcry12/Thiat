extends SceneTree
# Regression guard for the signed-angle bug (godot-gotchas.md): a hit from
# BEHIND the player must NOT be parryable even with the window open, or an
# absf()-less arc check would silently let it through. angle_to() is signed, so
# only one back side would slip through: both sides are tried, plus the front
# so a guard that parries nothing cannot pass.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	health.armor = 0.0
	health.shield = 0.0
	health.shield_max = 0.0

	guard.parry_arc_degrees = 90.0
	guard.aim_direction = Vector2.RIGHT

	for c in [
		[Vector2(-100, 0), "directly behind"],
		[Vector2(-100, 50), "behind, below"],
		[Vector2(-100, -50), "behind, above"],
		[Vector2(50, 100), "side, below (outside the arc)"],
		[Vector2(50, -100), "side, above (outside the arc)"],
	]:
		_check(_hit_from(player, dummy, guard, health, c[0]) >= 49.9, "%s: full damage" % c[1])
	for c in [
		[Vector2(100, 0), "straight ahead"],
		[Vector2(100, 50), "ahead, below"],
		[Vector2(100, -50), "ahead, above"],
	]:
		_check(_hit_from(player, dummy, guard, health, c[0]) <= 0.1, "%s: parried" % c[1])

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)

## Damage taken from a parryable 50 hit with the attacker at this offset from the player.
func _hit_from(player: Node2D, dummy: Node2D, guard: Guard, health: Health, offset: Vector2) -> float:
	dummy.global_position = player.global_position + offset
	guard.try_guard()
	health.hp = 100.0
	health.take_damage(50.0, dummy, true)
	return 100.0 - health.hp
