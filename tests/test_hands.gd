extends SceneTree
# The hands sit on the weapon model's HandMain / HandOff markers (rest + mid-swing),
# follow a weapon swap, rest beside the body with no model, pull the off hand back
# while drawing a bow, and never write into the weapon.
var _ok := true

func _check(label: String, good: bool) -> void:
	print("%s  %s" % [label, "ok" if good else "FAIL"])
	_ok = _ok and good

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.get_node("Inventory").give_dev_kit()   # W4: the start kit is only a wooden sword (decision 0031)
	player.set_physics_process(false)           # headless mouse sits at (0,0)
	var hands: HandsVisual = player.get_node("Hands")
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var holder: WeaponHolder = player.get_node("WeaponHolder")
	var loadout: Loadout = player.get_node("Loadout")
	wv.set_aim_angle(0.0)
	hands.set_aim_angle(0.0)
	await _frames(3)

	# Sword at rest.
	_check("sword rest: hands on markers", _on_markers(hands, wv.get_model()))
	# Sword mid-swing (windup, active, follow-through).
	holder.try_attack()
	var seen := 0
	for i in 60:
		await physics_frame
		await process_frame
		if holder.phase != WeaponHolder.Phase.IDLE:
			seen += 1
			if not _on_markers(hands, wv.get_model()):
				_check("sword swing frame %d" % i, false)
	_check("sword mid-swing: hands stay on markers (%d frames)" % seen, seen > 5)

	# The hands never write into the weapon: snapshot, run, compare.
	var before := _snapshot(wv.get_model())
	hands.set_drawing(true)
	await _frames(20)
	hands.set_drawing(false)
	_check("weapon nodes untouched by the hands", before == _snapshot(wv.get_model()))

	# Swap to the bow.
	await _until(func(): return holder.phase == WeaponHolder.Phase.IDLE)
	loadout.try_swap(1)
	await _until(func(): return not loadout.is_casting())
	await _frames(3)
	var bow := wv.get_model()
	_check("bow model has HandMain + HandOff", bow.get_node_or_null("HandMain") != null and bow.get_node_or_null("HandOff") != null)
	_check("bow rest: hands on bow markers", _on_markers(hands, bow))
	var rest_off := hands.hand_positions()[1]
	hands.set_drawing(true)
	await _frames(30)
	var drawn := hands.hand_positions()
	_check("bow drawing: off hand pulled back along the aim", drawn[1].x < rest_off.x - 4.0 and absf(drawn[1].y - rest_off.y) < 0.5)
	_check("bow drawing: main hand stays on its marker", drawn[0].distance_to(bow.get_node("HandMain").global_position) < 1.0)
	hands.set_drawing(false)

	# Real wiring: bow wind-up, piercing charge, cancel, death, swap, aim left.
	await _frames(20)
	var slot: SkillSlot = player.get_node("SkillSlot")
	holder.try_attack()
	await _frames(2)
	_check("bow wind-up drives drawing true", hands.is_drawing() and holder.phase == WeaponHolder.Phase.WINDUP)
	await _frames(8)
	_check("bow wind-up pulls the off hand", hands.pull_amount() > 0.5)
	holder.cancel()
	await _frames(2)
	_check("cancel drives drawing false", not hands.is_drawing())
	await _until(func(): return holder.phase == WeaponHolder.Phase.IDLE)
	slot.try_use(loadout.active_weapon(), Vector2.RIGHT)
	await _frames(2)
	_check("piercing charge drives drawing true", hands.is_drawing())
	slot.cancel()
	await _frames(2)
	_check("skill cancel drives drawing false", not hands.is_drawing())
	slot.reset_cooldowns()
	slot.try_use(loadout.active_weapon(), Vector2.RIGHT)
	await _frames(2)
	player._on_died()
	await _frames(2)
	_check("death drives drawing false", not hands.is_drawing())
	player.dead = false
	slot.reset_cooldowns()
	slot.try_use(loadout.active_weapon(), Vector2.RIGHT)
	await _frames(25)
	_check("pulled before the swap", hands.pull_amount() > 0.5)
	slot.cancel()
	hands.set_drawing(true)
	await _frames(15)
	loadout.swap_cast = 0.05
	await _until(func(): return loadout.try_swap(0))    # swap has a cooldown
	await _until(func(): return not loadout.is_casting())
	_check("swapped to the sword", loadout.active_weapon().behavior == "arc")
	_check("swap resets drawing and pull", not hands.is_drawing() and hands.pull_amount() == 0.0)
	# Aim left with a model bound: hands on the mirrored markers.
	wv.set_aim_angle(PI)
	hands.set_aim_angle(PI)
	await _frames(3)
	var sword := wv.get_model()
	_check("aim left: hands on mirrored markers", _on_markers(hands, sword))
	_check("aim left: markers really mirrored (grip left of the body)", sword.get_node("HandMain").global_position.x < player.global_position.x)

	# No model: rest offsets (aim right, then left = side mirrored).
	hands.bind_model(null)
	hands.set_aim_angle(0.0)
	await _frames(2)
	var p := hands.hand_positions()
	_check("no model: main at rest offset", p[0].distance_to(hands.to_global(hands.rest_offset_main)) < 1.0)
	_check("no model: off at rest offset", p[1].distance_to(hands.to_global(hands.rest_offset_off)) < 1.0)
	hands.set_aim_angle(PI)
	p = hands.hand_positions()
	_check("no model, aim left: hands in front of the body on the left", p[0].x < hands.global_position.x and p[1].x < hands.global_position.x)

	# Holster toggle (Loadout.toggle_hands; the keys now use select()): instant, free, always back to the same weapon.
	var lo: Loadout = loadout
	var wh: WeaponHolder = holder
	lo._cooldown_left = 0.0   # the swap above charged the cooldown; this block starts fresh
	var first: WeaponData = lo.active_weapon()
	_check("hands: instant holster", lo.toggle_hands() and lo.is_holstered() and wh.weapon == lo.unarmed)
	_check("holster costs no cast and no cooldown", lo.cooldown_left() == 0.0 and not lo.is_casting())
	_check("hands again: same weapon back, instant", lo.toggle_hands() and not lo.is_holstered() and wh.weapon == first)
	lo.toggle_hands()
	var other := 1 - lo.active_index()
	_check("from hands to the OTHER weapon = a normal swap cast", lo.try_swap(other) and lo.is_casting())
	for i in 60:
		await physics_frame
	_check("...and it charges the cooldown", not lo.is_holstered() and wh.weapon == lo.weapons[other] and lo.cooldown_left() > 0.0)
	_check("holster allowed during the swap cooldown", lo.toggle_hands() and lo.is_holstered())
	# Punch the dummy (still holstered): fists deal damage like any weapon.
	var dummy = arena.get_node("Dummy")
	var dh: Health = dummy.get_node("Health")
	player.global_position = dummy.global_position - Vector2(24, 0)
	wv.set_aim_angle(0.0)
	await physics_frame
	var hp_before := dh.hp
	wh.try_attack()
	for i in 30:
		await physics_frame
	_check("a punch hurts the dummy (%.0f -> %.0f)" % [hp_before, dh.hp], dh.hp < hp_before)
	quit(0 if _ok else 1)

func _on_markers(hands: HandsVisual, model: Node2D) -> bool:
	var p := hands.hand_positions()
	return p[0].distance_to(model.get_node("HandMain").global_position) < 1.0 \
		and p[1].distance_to(model.get_node("HandOff").global_position) < 1.0

func _snapshot(model: Node) -> Array:
	var out := []
	for n in [model] + model.find_children("*", "Node2D", true, false):
		out.append([n.name, n.position, n.rotation, n.scale, n.visible, n.modulate])
	return out

func _frames(n: int) -> void:
	for _i in n:
		await physics_frame
		await process_frame

func _until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < 600:
		await physics_frame
		n += 1
	await process_frame
