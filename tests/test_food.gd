extends SceneTree
# Food slice v2 (decision 0072): item data, stacking rules, regen total, Sick slows, refusals, potion, respawn, save, hold eats.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _grant(id: String, level: int, secs: float) -> EffectGrant:
	var g := EffectGrant.new()
	g.effect = load("res://data/effects/%s.tres" % id) as EffectData
	g.level = level
	g.duration = secs
	return g

func _find(inv: Inventory, it: ItemData) -> int:
	for i in Inventory.SIZE:
		if inv.slot_item(i) == it:
			return i
	return -1

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var fx: Effects = player.get_node("Effects")
	var consumer: Consumer = player.get_node("Consumer")
	var health: Health = player.get_node("Health")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var bread := World.item("bread")
	var raw := World.item("raw_pork")
	var cooked := World.item("cooked_pork")
	var potion := World.item("healing_potion")

	# item data
	var table := {"raw_pork": [[1, 10.0], [1, 15.0]], "bread": [[1, 20.0]], "sausage": [[1, 30.0]], "cooked_pork": [[2, 20.0]], "soup": [[2, 30.0]]}
	var data_ok := true
	for id in table:
		var it := World.item(id)
		data_ok = data_ok and it.effects.size() == table[id].size()
		for k in it.effects.size():
			data_ok = data_ok and it.effects[k].level == table[id][k][0] and is_equal_approx(it.effects[k].duration, table[id][k][1])
	_check(data_ok and raw.effects[1].effect.id == &"sick" and potion.heal_value == 50.0 and potion.effects.is_empty(), "item data matches the spec table")
	_check(is_equal_approx(raw.effects[1].effect.speed_mult, 0.8) and is_equal_approx(raw.effects[0].effect.hp_per_level_per_s, 0.5), "effect data: sick 0.8, regen 0.5 hp/s/level")

	# stacking
	_check(fx.apply(_grant("regen", 1, 6.0)), "first regen applies")
	_check(fx.apply(_grant("regen", 1, 10.0)) and is_equal_approx(fx.active()[0]["time_left"], 10.0), "same level longer: timer becomes the longer (not added)")
	_check(not fx.apply(_grant("regen", 1, 4.0)) and is_equal_approx(fx.active()[0]["time_left"], 10.0), "same level shorter: refused")
	_check(not fx.apply(_grant("regen", 1, 10.0)), "same level same time: nothing changes, refused")
	_check(fx.apply(_grant("regen", 2, 3.0)) and fx.level_of(&"regen") == 2 and is_equal_approx(fx.active()[0]["time_left"], 3.0), "stronger replaces (even with less time)")
	_check(not fx.apply(_grant("regen", 1, 60.0)) and fx.level_of(&"regen") == 2, "weaker refused while stronger runs")
	_check(fx.apply(_grant("sick", 1, 15.0)) and fx.active().size() == 2, "different kinds run together")
	var d: Dictionary = fx.active()[0]
	_check(d.has_all(["id", "level", "time_left", "duration", "is_debuff", "icon"]), "active() dict keys")
	fx.clear()
	_check(fx.active().is_empty() and is_equal_approx(fx.speed_mult(), 1.0), "clear")

	# regen total and stop at max hp
	health.hp = 10.0
	fx.apply(_grant("regen", 2, 2.0))
	await _frames(150)   # 2.5 s: effect ends at 2 s
	_check(absf(health.hp - 12.0) < 0.3 and fx.active().is_empty(), "regen II 2 s heals ~2 (hp %.2f), then ends" % health.hp)
	health.hp = health.max_hp - 1.0
	fx.apply(_grant("regen", 2, 5.0))
	await _frames(60)
	_check(is_equal_approx(health.hp, health.max_hp), "regen stops at max hp")
	fx.clear()

	# consumer: refusals
	inv.remove_from_slot(0, 99)
	inv._put(0, bread, 5)
	lo.select_instant(0)
	health.hp = health.max_hp
	_check(not consumer.try_use(bread, 0) and inv.slot_count(0) == 5 and fx.active().is_empty(), "regen food at full hp: refused, item kept")
	health.hp = 50.0
	_check(consumer.try_use(bread, 0) and inv.slot_count(0) == 4 and fx.level_of(&"regen") == 1, "bread at low hp: eaten, one item")
	await _frames(60)
	_check(consumer.try_use(bread, 0) and inv.slot_count(0) == 3 and absf(float(fx.active()[0]["time_left"]) - 20.0) < 0.01, "bread again 1 s later: timer back to 20 (not 39), eaten")
	var snack := ItemData.new()   # Regen I for 2 s: shorter than what is left
	snack.id = &"test_snack"
	snack.effects = [_grant("regen", 1, 2.0)] as Array[EffectGrant]
	inv._put(4, snack, 3)
	_check(not consumer.try_use(snack, 4) and inv.slot_count(4) == 3, "same level, shorter: refused, item kept")
	inv.remove_from_slot(4, 99)
	fx.clear()
	_check(consumer.try_use(bread, 0) and inv.slot_count(0) == 2, "bread after clear: eaten")
	inv._put(1, cooked, 2)
	_check(consumer.try_use(cooked, 1) and fx.level_of(&"regen") == 2, "cooked pork (II) replaces bread (I)")
	_check(not consumer.try_use(bread, 0) and inv.slot_count(0) == 2 and consumer.last_refusal == "no change", "weaker bread while II runs: refused, item kept")
	fx.clear()

	# raw pork: both, never refused
	health.hp = health.max_hp
	inv._put(2, raw, 4)
	_check(consumer.try_use(raw, 2) and inv.slot_count(2) == 3, "raw pork at full hp: eaten")
	_check(fx.level_of(&"sick") == 1 and fx.level_of(&"regen") == 0, "full hp: sick applied, regen part skipped")
	health.hp = 50.0
	fx.clear()
	consumer.try_use(raw, 2)
	_check(fx.level_of(&"sick") == 1 and fx.level_of(&"regen") == 1 and inv.slot_count(2) == 2, "raw pork at low hp: Regen I + Sick I")
	_check(consumer.try_use(raw, 2) and inv.slot_count(2) == 1, "raw pork again (no change): still never refused")

	# sick slows movement, then ends
	_check(is_equal_approx(fx.speed_mult(), 0.8), "sick speed_mult 0.8")
	fx.clear()
	fx.apply(_grant("sick", 1, 0.5))
	player.set_physics_process(true)
	player.global_position = Vector2(player.global_position)
	Input.action_press("move_right")
	await _frames(10)
	var v_sick: float = absf(player.velocity.x)
	await _frames(40)
	var v_after: float = absf(player.velocity.x)
	Input.action_release("move_right")
	_check(v_sick > 0.0 and v_after > 0.0 and absf(v_sick / v_after - 0.8) < 0.05 and fx.active().is_empty(), "sick: walk speed x0.8 (%.0f vs %.0f), ends" % [v_sick, v_after])
	await _frames(3)

	# potion unchanged
	health.hp = 20.0
	inv._put(3, potion, 2)
	_check(consumer.try_use(potion, 3) and is_equal_approx(health.hp, 70.0) and inv.slot_count(3) == 1, "potion heals 50, -1 item")
	_check(is_equal_approx(consumer.cooldown_left(), 30.0), "cooldown started")
	health.hp = 20.0
	_check(not consumer.try_use(potion, 3) and consumer.last_refusal == "cooldown" and inv.slot_count(3) == 1, "cooldown: refused")
	consumer._cooldown_left = 0.0
	health.hp = health.max_hp
	_check(not consumer.try_use(potion, 3) and consumer.last_refusal == "full" and inv.slot_count(3) == 1, "full hp: refused")

	# respawn clears
	fx.apply(_grant("regen", 2, 10.0))
	fx.apply(_grant("sick", 1, 10.0))
	player.respawn()
	_check(fx.active().is_empty(), "respawn clears effects")

	# save round-trip
	fx.apply(_grant("regen", 2, 10.0))
	fx.apply(_grant("sick", 1, 15.0))
	var sg: SaveGame = arena.get_node("SaveGame")
	var sd: Dictionary = sg.collect()
	_check(sd["player"]["effects"].size() == 2, "save holds both effects")
	fx.clear()
	sg.apply(sd)
	_check(fx.level_of(&"regen") == 2 and fx.level_of(&"sick") == 1 and absf(float(fx.active()[0]["time_left"]) - 10.0) < 0.5, "load restores effects with time left")
	sd["player"].erase("effects")
	sd["player"]["food"] = 37.0
	sg.apply(sd)
	_check(fx.active().is_empty(), "old save (food field, no effects) loads: no effects")

	# hold with food: eats after eat_time, no swing, no body turn, slower walk
	inv.remove_from_slot(0, 99)
	inv._put(0, bread, 5)
	lo.select_instant(0)
	health.hp = 10.0
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	var before := inv.count(&"bread")
	player.aim_override = Vector2.LEFT
	player._body_facing = Vector2.RIGHT
	player._face_mouse_left = 0.0
	Input.action_press("attack")
	await _frames(6)
	_check(consumer.is_eating() and consumer.eat_progress() > 0.0, "hold: eating starts")
	_check(wh.phase == WeaponHolder.Phase.IDLE and player._face_mouse_left == 0.0 and player._body_facing.x > 0.0, "food hold: no swing, body does not turn to the mouse")
	var board: SoundBoard = arena.get_tree().get_first_node_in_group("sound_board")
	var n0 := board.play_count
	await _frames(40)
	_check(inv.count(&"bread") == before and consumer.is_eating(), "0.7 s: not eaten yet")
	_check(board.play_count >= n0 + 2 and board.last_event == &"player.eat", "chew sounds while eating (%d plays, %s)" % [board.play_count - n0, board.last_event])
	_check(player.get_node("EatCrumbs")._crumbs.size() > 0 and player.get_node("WeaponVisual/HeldItem").bob_y() <= 0.0, "crumbs fly while eating")
	await _frames(70)   # ~1.9 s total
	_check(inv.count(&"bread") == before - 1 and fx.level_of(&"regen") == 1, "hold eat_time: exactly one eaten")
	_check(not consumer.is_eating() and consumer.status_text().contains("gap 0."), "still holding: gap, not eating (no bob / crumbs)")
	_check(board.last_event == &"player.gulp", "finished: gulp (got %s)" % board.last_event)
	await _frames(20)   # ~2.27 s: gap (0.5 s) over
	_check(consumer.is_eating(), "gap over: next one started")
	Input.action_release("attack")
	await _frames(3)
	_check(not consumer.is_eating() and inv.count(&"bread") == before - 1, "release: stops")

	# potion drinks with the drink sound
	inv._put(3, potion, 2)
	lo.select_instant(3)
	health.hp = 10.0
	n0 = board.play_count
	Input.action_press("attack")
	await _frames(30)
	_check(consumer.is_eating() and board.play_count > n0 and board.last_event == &"player.drink", "potion hold: drink sound (got %s)" % board.last_event)
	Input.action_release("attack")
	await _frames(3)
	_check(not consumer.is_eating(), "release resets (potion)")
	lo.select_instant(0)
	await _frames(3)

	# release early eats nothing
	fx.clear()
	health.hp = 10.0
	before = inv.count(&"bread")
	Input.action_press("attack")
	await _frames(60)
	Input.action_release("attack")
	await _frames(60)
	_check(inv.count(&"bread") == before and not consumer.is_eating() and fx.active().is_empty(), "release at 1.0 s: nothing eaten")

	# switch slot cancels
	Input.action_press("attack")
	await _frames(30)
	lo.select_instant(1)
	await _frames(3)
	_check(consumer.eat_progress() < 0.1, "slot switch cancels (progress restarts)")
	Input.action_release("attack")
	lo.select_instant(0)
	await _frames(3)

	# walk speed halved while eating
	health.hp = 10.0
	Input.action_press("move_right")
	await _frames(10)
	var v_walk: float = absf(player.velocity.x)
	Input.action_press("attack")
	await _frames(15)
	var v_eat: float = absf(player.velocity.x)
	Input.action_release("attack")
	Input.action_release("move_right")
	_check(v_walk > 0.0 and absf(v_eat / v_walk - consumer.eating.eat_move_mult) < 0.05, "eating: walk speed x eat_move_mult (%.0f vs %.0f)" % [v_eat, v_walk])
	await _frames(3)

	# refusal at start: no eating, no animation
	health.hp = health.max_hp
	fx.clear()
	Input.action_press("attack")
	await _frames(10)
	_check(not consumer.is_eating() and consumer.last_refusal == "full", "full hp: eating does not start")
	Input.action_release("attack")
	await _frames(3)

	# dying cancels
	health.hp = 10.0
	Input.action_press("attack")
	await _frames(20)
	player._on_died()
	_check(not consumer.is_eating(), "death cancels")
	Input.action_release("attack")
	player.respawn()

	print("RESULT: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
