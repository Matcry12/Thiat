extends SceneTree
# The enemy reaches `telegraph` before `strike`, and the strike hitbox only
# deals damage during the strike phase (not telegraph, not cooldown).
func _init():
	var dummy = load("res://scenes/dummy.tscn").instantiate()
	root.add_child(dummy)
	await process_frame

	var attacker: Attacker = dummy.get_node("Attacker")

	# A minimal, code-built hit target co-located with the dummy so the
	# strike's shape (centered on the dummy) is guaranteed to overlap it.
	var victim := Node2D.new()
	root.add_child(victim)
	victim.global_position = dummy.global_position

	var vhealth := Health.new()
	vhealth.name = "Health"
	vhealth.max_hp = 100.0
	victim.add_child(vhealth)

	var vhurtbox := Hurtbox.new()
	vhurtbox.name = "Hurtbox"
	vhurtbox.collision_layer = 2
	vhurtbox.collision_mask = 0
	victim.add_child(vhurtbox)
	vhurtbox.owner = victim  # Hurtbox.get_health() reads owner, not the parent.
	var vshape := CollisionShape2D.new()
	var vcircle := CircleShape2D.new()
	vcircle.radius = 15.0
	vshape.shape = vcircle
	vhurtbox.add_child(vshape)

	attacker.set_target(victim)

	var reached_telegraph := false
	for i in 3:  # one tick of physics lag between set_target and the next _physics_process
		await physics_frame
		if attacker.phase == Attacker.Phase.TELEGRAPH:
			reached_telegraph = true
			break
	print("reaches telegraph before strike: ", reached_telegraph)

	var hp_before_strike: float = vhealth.hp
	var telegraph_steps := int(ceil(attacker.telegraph_time * 60.0)) + 2
	var reached_strike := false
	for i in telegraph_steps:
		await physics_frame
		if attacker.phase == Attacker.Phase.STRIKE:
			reached_strike = true
			break
	print("reaches strike after telegraph: ", reached_strike)

	var no_damage_before_strike: bool = vhealth.hp == hp_before_strike
	print("no damage dealt during telegraph: ", no_damage_before_strike)

	var strike_steps := int(ceil(attacker.strike_time * 60.0)) + 3
	for i in strike_steps:
		await physics_frame
	var damage_dealt_during_strike: bool = vhealth.hp < hp_before_strike
	print("damage dealt by end of strike: ", damage_dealt_during_strike, " hp=", vhealth.hp)

	var in_cooldown: bool = attacker.phase == Attacker.Phase.COOLDOWN
	print("moves to cooldown after strike: ", in_cooldown)

	var hp_after_strike: float = vhealth.hp
	for i in 30:  # 0.5s into cooldown, well short of attack_cooldown
		await physics_frame
	var no_extra_damage_in_cooldown: bool = vhealth.hp == hp_after_strike
	print("no further damage during cooldown: ", no_extra_damage_in_cooldown)

	var ok: bool = reached_telegraph and reached_strike and no_damage_before_strike \
		and damage_dealt_during_strike and in_cooldown and no_extra_damage_in_cooldown
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
