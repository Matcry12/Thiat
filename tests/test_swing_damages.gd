extends SceneTree
# End-to-end: stand next to the dummy so the swinging blade actually sweeps
# over it, swing -> hp must drop exactly once (decision 0011: the hit area is
# the Hitbox shape on the blade now, not a reach/arc number, so the test has
# to place the dummy where the blade's motion really reaches, not just
# within an old numeric "reach").
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	var dummy = arena.get_node("Dummy")
	var holder = arena.get_node("Player/WeaponHolder")
	var weapon_visual = arena.get_node("Player/WeaponVisual")
	var health = dummy.get_node("Health")

	# Disabling physics_process must happen AFTER _ready() (the node re-enables
	# it on entering the tree), otherwise the player's own _physics_process
	# keeps recomputing aim from the headless (0,0) mouse and overwrites our
	# forced aim below.
	player.set_physics_process(false)

	player.global_position = dummy.global_position - Vector2(45, 0)  # blade tip reaches ~50px
	weapon_visual.set_aim_angle(0.0)                                 # facing the dummy (+X)
	await physics_frame
	var hp_before: float = health.hp

	holder.try_attack()
	var w = player.get_node("Loadout").active_weapon()
	for i in ceili((w.windup + w.active + w.recovery) * 60.0) + 6:     # whole swing + margin, from the weapon's own timings
		await physics_frame

	var dealt: float = hp_before - health.hp
	var expected: float = player.get_node("Loadout").active_weapon().damage - 10.0   # weapon dmg - 20 armor*0.5
	print("hp %.0f -> %.0f  (dealt %.1f, expected %.1f once)" % [hp_before, health.hp, dealt, expected])
	print("phase back to idle: ", holder.phase == 0)
	var ok: bool = is_equal_approx(dealt, expected) and holder.phase == 0
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
