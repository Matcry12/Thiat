extends SceneTree
# Parry: a parryable hit from the front while the PARRY window is open does
# zero damage and staggers the attacker (Guard.resolve() duck-types
# stagger() onto the hit's source, forwarded by dummy.gd -> Attacker).
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame

	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)   # headless mouse would re-aim every frame

	var guard: Guard = player.get_node("Guard")
	var health: Health = player.get_node("Health")
	var attacker: Attacker = dummy.get_node("Attacker")

	guard.aim_direction = Vector2.RIGHT   # dummy sits to the right of the player

	var opened: bool = guard.try_guard()
	print("parry window opens: ", opened)

	var hp_before: float = health.hp
	var shield_before: float = health.shield
	health.take_damage(50.0, dummy, true)

	var hp_unchanged: bool = health.hp == hp_before and health.shield == shield_before
	print("hp unchanged after parried hit: ", hp_unchanged)

	var staggered: bool = attacker.phase == Attacker.Phase.STAGGER
	print("attacker staggered: ", staggered)

	var ok: bool = opened and hp_unchanged and staggered
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
