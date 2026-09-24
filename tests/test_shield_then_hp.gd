extends SceneTree
# Damage eats shield first, then HP. Shield regenerates after the delay; HP
# never does.
func _init():
	var health := Health.new()
	health.max_hp = 100.0
	health.shield_max = 30.0
	health.shield_regen_delay = 5.0
	health.shield_regen_rate = 1.0
	health.armor = 0.0
	root.add_child(health)
	await physics_frame

	var start_full: bool = health.hp == 100.0 and health.shield == 30.0
	print("starts full: ", start_full, " hp=", health.hp, " shield=", health.shield)

	health.take_damage(10.0)
	await physics_frame
	var shield_absorbed: bool = health.shield == 20.0 and health.hp == 100.0
	print("10 dmg eats shield only: ", shield_absorbed, " hp=", health.hp, " shield=", health.shield)

	health.take_damage(40.0)  # 20 left in shield -> spills 20 to hp
	await physics_frame
	var spilled: bool = health.shield == 0.0 and health.hp == 80.0
	print("overflow spills to hp: ", spilled, " hp=", health.hp, " shield=", health.shield)

	# Well under the regen delay: shield must still be at 0.
	var pre_delay_steps := int((health.shield_regen_delay - 0.5) * 60.0)
	for i in pre_delay_steps:
		await physics_frame
	var no_regen_yet: bool = health.shield == 0.0
	var hp_unchanged_1: bool = health.hp == 80.0
	print("no shield regen before delay: ", no_regen_yet)

	# Past the delay: shield regenerates, HP still doesn't.
	var post_delay_steps := int(3.0 * 60.0)
	for i in post_delay_steps:
		await physics_frame
	var shield_regenerated: bool = health.shield > 0.0
	var hp_still_unchanged: bool = health.hp == 80.0
	print("shield regenerates after delay: ", shield_regenerated, " shield=", health.shield)
	print("hp never regenerates: ", hp_still_unchanged, " hp=", health.hp)

	var ok: bool = start_full and shield_absorbed and spilled and no_regen_yet \
		and hp_unchanged_1 and shield_regenerated and hp_still_unchanged
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
