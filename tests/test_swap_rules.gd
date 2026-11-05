extends SceneTree
# Weapon <-> weapon switching is instant (no cast, no cooldown), any number of weapons on the hotbar.
# Drives the real player scene and real key input.
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var guard: Guard = player.get_node("Guard")
	player.aim_override = Vector2.RIGHT
	await _frames(5)

	# 1. Every real weapon item, back and forth, same frame, no wait.
	inv.give_dev_kit()
	for id in ["copper_sword", "wooden_sword", "bow"]:
		inv.add(load("res://data/items/%s.tres" % id), 1)
	var slots: Array[int] = []
	for i in lo.weapons.size():
		slots.append(lo.weapon_slot(i))
	_check(lo.weapons.size() == 5, "5 weapons on the hotbar (%d)" % lo.weapons.size())
	var all_ok := true
	for round in 3:
		for s in slots:
			var want: WeaponData = inv.slot_item(s).weapon
			var was_active: bool = lo.active_weapon() == want
			var ok: bool = lo.select(s)
			var good: bool = (ok != was_active) and lo.active_weapon() == want and wh.weapon == want and wv.weapon == want and wv.get_model() != null and lo.selected_slot == s
			if not good:
				print("   bad switch to slot %d (%s)" % [s, want.resource_path])
			all_ok = all_ok and good
	_check(all_ok, "select(weapon slot) changes active_weapon, holder and visual in the same frame, every weapon, repeated")

	# 2. 9 weapons all go to the hotbar through add(); each is selectable.
	inv.give_dev_kit()
	for i in 9:
		inv.add(load("res://data/items/%s.tres" % ["copper_sword", "bow", "wooden_sword"][i % 3]), 1)
	_check(lo.weapons.size() == 7, "kit's 2 + 5 of the 9 new weapons fill the hotbar's free slots (%d weapons)" % lo.weapons.size())
	var sel := true
	for i in lo.weapons.size():
		lo.select(lo.weapon_slot((i + 1) % lo.weapons.size()))
		sel = sel and lo.active_index() == (i + 1) % lo.weapons.size()
	_check(sel, "each hotbar weapon is selectable")

	# 3. A switch during a swing is refused; a key press waits for the swing and applies at IDLE.
	inv.give_dev_kit()
	await _frames(2)
	var bow_slot := lo.weapon_slot(1)
	wh.aim_direction = Vector2.RIGHT
	var sw: WeaponData = lo.active_weapon()
	var swing_frames := 0
	wh.try_attack()
	await _frames(2)
	_check(wh.phase != WeaponHolder.Phase.IDLE and not lo.select(bow_slot) and lo.selected_slot == 0, "Loadout refuses select during a swing")
	Input.action_press("slot_2")
	await _frames(2)
	Input.action_release("slot_2")
	var mid: bool = wh.phase != WeaponHolder.Phase.IDLE
	_check(mid and lo.selected_slot == 0 and player.pending_slot() == bow_slot, "key during the swing is remembered, not applied, not eaten")
	var applied_idle := false
	var elapsed := 4   # frames since try_attack
	for i in 120:
		await physics_frame
		elapsed += 1
		if lo.selected_slot == bow_slot:
			applied_idle = wh.phase == WeaponHolder.Phase.IDLE
			break
	var full := (sw.windup + sw.active + sw.recovery) * Engine.physics_ticks_per_second
	_check(applied_idle and player.pending_slot() == -1 and elapsed >= full - 2.0, "applied only after windup+active+recovery (%d frames >= %.0f)" % [elapsed, full])
	var pivot: Node2D = player.get_node("WeaponVisual/SwingPivot")
	var bw: WeaponData = lo.active_weapon()
	_check(is_equal_approx(pivot.rotation, deg_to_rad(bw.rest_angle_degrees)), "after the swap the pivot is at the new weapon's rest angle")

	# 4. A press while guarding waits for the guard to end.
	await _frames(10)
	Input.action_press("parry")
	await _frames(3)
	var guarding: bool = guard.is_guarding()
	await _tap("slot_1")
	_check(guarding and lo.selected_slot == bow_slot and player.pending_slot() == 0, "press while guarding is pending")
	Input.action_release("parry")
	await _frames(40)
	_check(lo.selected_slot == 0 and player.pending_slot() == -1, "applied after the guard ends")

	# 5. A press while dashing waits for the dash to end.
	await _frames(40)
	lo.select(0)
	player.global_position += Vector2.ZERO
	var dodge: Dodge = player.get_node("Dodge")
	await _tap("dodge")
	var dashing: bool = dodge.is_dashing()
	await _tap("slot_2")
	_check(dashing and lo.selected_slot == 0 and player.pending_slot() == bow_slot, "press while dashing is pending")
	await _frames(60)
	_check(lo.selected_slot == bow_slot and player.pending_slot() == -1, "applied after the dash")

	# 6. Holding attack with a tool must not block a pending switch.
	inv.give_dev_kit()
	await _frames(2)
	lo.select(2)   # axe
	player.get_node("Dodge").set("_cooldown_remaining", 0.0)
	Input.action_press("attack")
	await _frames(3)
	await _tap("slot_1")
	await _frames(90)
	Input.action_release("attack")
	_check(lo.selected_slot == 0 and player.pending_slot() == -1, "slot press while holding attack with a tool applies after the current swing")

	# 7. sync() keeps / follows what is in hand.
	inv.give_dev_kit()
	inv.add(load("res://data/items/wooden_sword.tres"), 1)   # a copy in slot 4
	lo.select(4)
	inv.add(load("res://data/items/wood.tres"), 5)
	_check(lo.selected_slot == 4 and lo.active_weapon() == inv.slot_item(4).weapon, "duplicate weapon: sync keeps the copy's slot")
	lo.select(8)   # empty -> hands
	inv.click_slot(1)
	inv.click_slot(8)   # bow dropped on the selected empty slot
	_check(lo.active_weapon() == inv.slot_item(8).weapon and lo.can_attack() and not lo.is_holstered(), "weapon landing in the selected empty slot is in hand")
	lo.select(2)   # axe
	inv.click_slot(8)
	inv.click_slot(2)   # swap: the bow onto the axe slot, axe on the cursor
	_check(inv.slot_item(2) != null and lo.active_weapon() == inv.slot_item(2).weapon, "a new item swapped into the selected slot is what is in hand")
	inv.click_slot(8)   # put the axe down on the now empty slot 8
	lo.select(2)   # the bow
	var moved := inv.slot_item(2)
	inv._item[6] = moved
	inv._item[2] = null
	inv.changed.emit()
	_check(lo.selected_slot == 6 and lo.active_weapon() == moved.weapon and not lo.is_holstered(), "the held weapon moved to another slot follows it")

	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
