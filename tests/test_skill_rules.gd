extends SceneTree
# E-skill gates and cooldown rules, driven by REAL inputs through player.gd:
#   1. E refused while guarding / dashing / swap-casting
#   2. cooldown is PER WEAPON (sword skill cooling does not block the bow's,
#      and swapping back finds the sword still cooling)
#   3. dodge cancels a bow charge and charges no cooldown
#   4. a swap press is refused while a skill is active
#   5. a guard that fires cancels a bow charge, no cooldown
#   6. dodge/guard presses during a lunge are refused and change nothing
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	player.aim_override = Vector2.LEFT   # open space, away from the dummy
	var loadout: Loadout = player.get_node("Loadout")
	var slot: SkillSlot = player.get_node("SkillSlot")
	var guard: Guard = player.get_node("Guard")
	var dodge: Dodge = player.get_node("Dodge")
	var sword: WeaponData = loadout.weapons[0]
	var bow: WeaponData = loadout.weapons[1]
	sword.skill_cooldown = 30.0   # long enough to outlast the whole test
	(slot.skill_for(bow) as PiercingShot).charge_time = 5.0   # stays charging until cancelled
	loadout.swap_cast = 0.3
	loadout.swap_cooldown = 0.2
	await _frames(5)
	var ok := true

	# 1a. guarding
	_hold("parry", true)
	await _frames(3)
	var g: bool = guard.is_guarding()
	await _tap("skill")
	var r1: bool = not slot.is_active() and slot.cooldown_left(sword) == 0.0
	print("guarding: %s | E refused: %s" % [g, r1])
	ok = ok and g and r1
	_hold("parry", false)
	await _wait_until(func(): return guard.state == Guard.State.READY, 3.0)

	# 1b. dashing
	await _tap("dodge")
	var d: bool = dodge.is_dashing()
	await _tap("skill")
	var r2: bool = not slot.is_active() and slot.cooldown_left(sword) == 0.0
	print("dashing: %s | E refused: %s" % [d, r2])
	ok = ok and d and r2
	await _wait_until(func(): return not dodge.is_dashing(), 2.0)

	# 1c. swap cast (swap to the bow, then back to the sword later)
	await _tap("weapon_2")
	var c: bool = loadout.is_casting()
	await _tap("skill")
	var r3: bool = not slot.is_active() and slot.cooldown_left(bow) == 0.0
	print("swap casting: %s | E refused: %s" % [c, r3])
	ok = ok and c and r3
	await _wait_until(func(): return not loadout.is_casting() and loadout.cooldown_left() <= 0.0, 3.0)
	# bow is now equipped. Go back to the sword for the per-weapon check.
	await _tap("weapon_1")
	await _wait_until(func(): return not loadout.is_casting() and loadout.cooldown_left() <= 0.0, 3.0)

	# 2. sword skill -> cooling; bow's skill is separate.
	await _tap("skill")
	await _wait_until(func(): return not slot.is_active(), 2.0)
	var sword_cd: float = slot.cooldown_left(sword)
	await _tap("weapon_2")
	await _wait_until(func(): return not loadout.is_casting() and loadout.cooldown_left() <= 0.0, 3.0)
	var bow_ready: bool = slot.cooldown_left(bow) == 0.0
	await _tap("skill")
	var bow_started: bool = slot.is_active()
	print("sword cd %.1fs | bow ready: %s | bow skill started: %s" % [sword_cd, bow_ready, bow_started])
	ok = ok and sword_cd > 0.0 and bow_ready and bow_started

	# 3. dodge cancels the bow charge, charges nothing.
	await _wait_until(func(): return dodge.can_dodge(), 3.0)
	await _tap("dodge")
	var cancelled: bool = not slot.is_active() and slot.cooldown_left(bow) == 0.0
	print("dodge cancelled the charge, bow cd 0: %s" % cancelled)
	ok = ok and cancelled
	await _wait_until(func(): return not dodge.is_dashing(), 2.0)

	# 4. A swap press is REFUSED while a skill is active (swaps are vulnerable).
	await _tap("skill")
	var charging: bool = slot.is_active()
	await _tap("weapon_1")
	await _frames(2)
	var swap_refused: bool = charging and not loadout.is_casting() and loadout.active_index() == 1 and slot.is_active()
	print("charging: %s | swap refused during the charge: %s" % [charging, swap_refused])
	ok = ok and swap_refused

	# 5. A guard that fires cancels the charge, no cooldown.
	_hold("parry", true)
	await _frames(2)
	_hold("parry", false)
	var guard_cancel: bool = not slot.is_active() and slot.cooldown_left(bow) == 0.0
	print("guard cancelled the charge, bow cd 0: %s" % guard_cancel)
	ok = ok and guard_cancel
	await _wait_until(func(): return guard.state == Guard.State.READY, 3.0)

	# 6. Back to the sword: still cooling (not reset, not shared). Then, during
	#    a lunge, dodge and guard presses are refused and change nothing.
	await _tap("weapon_1")
	await _wait_until(func(): return not loadout.is_casting(), 3.0)
	var sword_still: bool = slot.cooldown_left(sword) > 0.0 and slot.cooldown_left(sword) <= sword_cd
	print("sword still cooling after swapping back: %s" % sword_still)
	ok = ok and sword_still
	slot.reset_cooldowns()
	await _wait_until(func(): return dodge.can_dodge(), 3.0)
	await _tap("skill")
	var lunging: bool = slot.moves_body()
	await _tap("dodge")
	var dodge_refused: bool = slot.is_active() and not dodge.is_dashing() and dodge.can_dodge()
	_hold("parry", true)
	await physics_frame
	var guard_refused: bool = slot.is_active() and guard.state == Guard.State.READY
	_hold("parry", false)
	print("lunging: %s | dodge refused, changed nothing: %s | guard refused: %s" % [lunging, dodge_refused, guard_refused])
	ok = ok and lunging and dodge_refused and guard_refused
	await _wait_until(func(): return not slot.is_active(), 2.0)

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

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

func _wait_until(cond: Callable, timeout: float) -> void:
	var left := timeout
	while not cond.call() and left > 0.0:
		await physics_frame
		left -= (1.0 / Engine.physics_ticks_per_second)
