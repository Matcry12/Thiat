extends SceneTree
# Drives REAL inputs through player.gd (never calls Loadout methods directly)
# so a regression in the gating/cancel wiring there — not just in Loadout
# itself — actually fails this test:
#   1. attack input during a cast: WeaponHolder must stay IDLE
#   2. dodge press during a cast cancels it, no cooldown charged
#   3. guard press during a cast cancels it
#   4. swap press refused while guarding
#   5. swap press refused while dashing
#   6. after a swap finishes, the new weapon's rest pose applies right away
#   7. a FAILED dodge/guard press must NOT cancel an in-progress swap
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	player.aim_override = Vector2.RIGHT
	var loadout: Loadout = player.get_node("Loadout")
	var weapon_holder: WeaponHolder = player.get_node("WeaponHolder")
	var guard: Guard = player.get_node("Guard")
	var dodge: Dodge = player.get_node("Dodge")
	var pivot: Node2D = player.get_node("WeaponVisual/SwingPivot")

	loadout.swap_cast = 0.3
	loadout.swap_cooldown = 0.2

	await _frames(5)   # let startup delta spikes settle

	var ok := true

	# 1. Attack input during a cast: WeaponHolder must stay IDLE.
	await _tap_swap_to_other(loadout)
	var casting1: bool = loadout.is_casting()
	_hold("attack", true)
	await _frames(2)
	_hold("attack", false)
	var stayed_idle: bool = weapon_holder.phase == WeaponHolder.Phase.IDLE
	print("cast started: %s | attack during cast stayed idle: %s" % [casting1, stayed_idle])
	ok = ok and casting1 and stayed_idle
	await _wait_until(func(): return not loadout.is_casting(), 2.0)
	await _wait_until(func(): return loadout.cooldown_left() <= 0.0, 2.0)

	# 2. Dodge press during a cast cancels it, no cooldown charged.
	await _tap_swap_to_other(loadout)
	var casting2: bool = loadout.is_casting()
	await _tap("dodge")
	await _frames(1)
	var dodge_cancelled: bool = not loadout.is_casting() and loadout.cooldown_left() <= 0.0
	print("cast started: %s | dodge press cancels it, no cooldown: %s" % [casting2, dodge_cancelled])
	ok = ok and casting2 and dodge_cancelled
	await _wait_until(func(): return dodge.cooldown_remaining() <= 0.0, 3.0)

	# 3. Guard press during a cast cancels it.
	await _tap_swap_to_other(loadout)
	var casting3: bool = loadout.is_casting()
	_hold("parry", true)
	await _frames(2)
	_hold("parry", false)
	var guard_cancelled: bool = not loadout.is_casting() and loadout.cooldown_left() <= 0.0
	print("cast started: %s | guard press cancels it: %s" % [casting3, guard_cancelled])
	ok = ok and casting3 and guard_cancelled
	await _wait_until(func(): return guard.state == Guard.State.READY, 3.0)

	# 4. Swap press refused while guarding.
	_hold("parry", true)
	await _frames(2)
	var was_guarding: bool = guard.is_guarding()
	var index_before4 := loadout.active_index()
	await _tap_swap_to_other(loadout)
	await _frames(1)
	var refused_while_guarding: bool = not loadout.is_casting() and loadout.active_index() == index_before4
	print("guarding: %s | swap refused while guarding: %s" % [was_guarding, refused_while_guarding])
	ok = ok and was_guarding and refused_while_guarding
	_hold("parry", false)
	await _wait_until(func(): return guard.state == Guard.State.READY, 3.0)

	# 5. Swap press refused while dashing.
	await _wait_until(func(): return dodge.can_dodge(), 3.0)
	await _tap("dodge")
	await _frames(1)
	var was_dashing: bool = dodge.is_dashing()
	var index_before5 := loadout.active_index()
	await _tap_swap_to_other(loadout)
	await _frames(1)
	var refused_while_dashing: bool = not loadout.is_casting() and loadout.active_index() == index_before5
	print("dashing: %s | swap refused while dashing: %s" % [was_dashing, refused_while_dashing])
	ok = ok and was_dashing and refused_while_dashing
	await _wait_until(func(): return not dodge.is_dashing(), 2.0)
	await _wait_until(func(): return dodge.cooldown_remaining() <= 0.0, 3.0)

	# 6. After a swap finishes, the new weapon's rest pose applies right away
	#    (covers the "old weapon's rest angle survives the swap" bug), proven
	#    twice so it includes a bow -> sword transition regardless of which
	#    weapon steps 1-5 left active.
	for i in 2:
		var target := 1 - loadout.active_index()
		await _tap_swap_to_other(loadout)
		await _wait_until(func(): return not loadout.is_casting(), 2.0)
		var w: WeaponData = loadout.weapons[target]
		var at_rest: bool = is_equal_approx(pivot.rotation, deg_to_rad(w.rest_angle_degrees))
		print("swapped to %s: pivot at its rest angle (%.0f): %s" % [w.resource_path.get_file(), w.rest_angle_degrees, at_rest])
		ok = ok and at_rest
		await _wait_until(func(): return loadout.cooldown_left() <= 0.0, 2.0)

	# 7. A FAILED dodge/guard press must NOT cancel an in-progress swap.
	await _tap_swap_to_other(loadout)
	await _frames(1)
	var casting7a: bool = loadout.is_casting()
	dodge._cooldown_remaining = 999.0   # ponytail: no setter to force a failed try_dodge(), poke the field
	await _tap("dodge")
	await _frames(1)
	var survived_failed_dodge: bool = loadout.is_casting()
	print("cast started: %s | swap survives a FAILED dodge press: %s" % [casting7a, survived_failed_dodge])
	ok = ok and casting7a and survived_failed_dodge
	dodge._cooldown_remaining = 0.0

	guard.state = Guard.State.RECOVER   # ponytail: same trick, force a failed try_guard()
	guard._timer = 999.0
	_hold("parry", true)
	await _frames(2)
	_hold("parry", false)
	var survived_failed_guard: bool = loadout.is_casting()
	print("swap survives a FAILED guard press too: %s" % survived_failed_guard)
	ok = ok and survived_failed_guard
	guard.state = Guard.State.READY
	guard._timer = 0.0

	await _wait_until(func(): return not loadout.is_casting(), 2.0)

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)


## Physics frames, not idle/process frames: every input check this test cares
## about (player.gd's Input.is_action_just_pressed calls) runs in
## _physics_process, so a wait built on `process_frame` can resolve before or
## after the physics tick that actually reads the press — bit us once already
## (see test_bow_shoots.gd's _wait_seconds comment for the same class of bug).
func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _hold(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _tap(action: String) -> void:
	_hold(action, true)
	await physics_frame
	await physics_frame
	_hold(action, false)


## Taps whichever of weapon_1/weapon_2 targets the weapon NOT currently
## active, so every call actually starts a new cast (or a refused press,
## when already guarding/dashing) regardless of what earlier steps left
## active.
func _tap_swap_to_other(loadout: Loadout) -> void:
	var target := 1 - loadout.active_index()
	await _tap("weapon_1" if target == 0 else "weapon_2")


func _wait_until(cond: Callable, timeout: float) -> void:
	var left := timeout
	while not cond.call() and left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
