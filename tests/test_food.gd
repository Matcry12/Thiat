extends SceneTree
# Food slice (decision 0071): drain, eat, starve (stops at the floor, never dies), potion + cooldown, one item per success,
# respawn refill, save round-trip, click with food does not swing.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var hunger: Hunger = player.get_node("Hunger")
	var consumer: Consumer = player.get_node("Consumer")
	var health: Health = player.get_node("Health")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var bread := World.item("bread")
	var potion := World.item("healing_potion")
	_check(bread.food_value == 25.0 and potion.heal_value == 50.0, "item data: bread 25, potion 50")
	_check(hunger.frozen, "hunger starts frozen in tests")
	_check(is_equal_approx(hunger.food, 100.0) and is_equal_approx(hunger.fraction(), 1.0), "starts full")

	# drain: 60 frames = 1 s at 10/min
	hunger.frozen = false
	hunger.drain_per_min = 600.0   # 10 per s
	await _frames(60)
	_check(absf(hunger.food - 90.0) < 0.5, "drains over time (%.2f)" % hunger.food)
	hunger.frozen = true

	# eat caps + refused when full
	hunger.set_food(90.0)
	_check(hunger.eat(25.0) and is_equal_approx(hunger.food, 100.0), "eat caps at max")
	_check(not hunger.eat(25.0), "eat refused when full")

	# consumer: count down by one only on success
	inv.remove_from_slot(0, 99)
	inv.add(bread, 3)
	var slot := 0
	for i in Inventory.SIZE:
		if inv.slot_item(i) == bread:
			slot = i
	lo.select_instant(slot) if slot < Inventory.HOTBAR else null
	_check(consumer.is_holding() == (slot < Inventory.HOTBAR), "food in the selected slot counts as holding")
	_check(not consumer.try_use(bread, slot) and consumer.last_refusal == "full", "full bar: refused, 'full'")
	_check(inv.slot_count(slot) == 3, "refused: nothing used")
	hunger.set_food(10.0)
	_check(consumer.try_use(bread, slot) and inv.slot_count(slot) == 2 and is_equal_approx(hunger.food, 35.0), "eaten: -1 item, +25 food")

	# potion
	health.hp = 20.0
	inv.add(potion, 2)
	var ps := 0
	for i in Inventory.SIZE:
		if inv.slot_item(i) == potion:
			ps = i
	_check(consumer.try_use(potion, ps) and is_equal_approx(health.hp, 70.0) and inv.slot_count(ps) == 1, "potion heals 50, -1 item")
	_check(is_equal_approx(consumer.cooldown_left(), 30.0), "cooldown started")
	health.hp = 20.0
	_check(not consumer.try_use(potion, ps) and consumer.last_refusal == "cooldown" and inv.slot_count(ps) == 1, "cooldown: refused")
	consumer.potion_cooldown = 0.0
	consumer._cooldown_left = 0.0
	health.hp = health.max_hp
	_check(not consumer.try_use(potion, ps) and consumer.last_refusal == "full" and inv.slot_count(ps) == 1, "full hp: refused")
	_check(health.heal(10.0) == 0.0, "heal at full returns 0")

	# starving: ticks, stops at floor, never died, no hit signals
	var died := [0]
	var hits := [0]
	health.died.connect(func(): died[0] += 1)
	health.hit_taken.connect(func(_i): hits[0] += 1)
	health.damaged.connect(func(_a): hits[0] += 1)
	health.hp = 3.0
	hunger.set_food(0.0)
	hunger.starve_interval = 0.5
	hunger._starve_left = 0.5
	hunger.frozen = false
	await _frames(70)   # a bit over 1 s: 2 ticks
	_check(is_equal_approx(health.hp, 1.0), "starve ticks 1 hp each (hp %.1f)" % health.hp)
	await _frames(120)
	_check(is_equal_approx(health.hp, 1.0) and died[0] == 0, "stops at floor, never died")
	_check(hits[0] == 0, "starving emits no hit / damaged")
	hunger.frozen = true

	# floor 0 in F3 still never kills
	health.hp = 2.0
	hunger.starve_floor = 0.0
	hunger.set_food(0.0)
	hunger.frozen = false
	await _frames(300)
	_check(is_equal_approx(health.hp, 1.0) and died[0] == 0, "starve_floor 0 is clamped to 1")
	hunger.frozen = true
	hunger.starve_floor = 1.0

	# food + heal item: a refused heal must not feed, and must not eat the item
	var stew := ItemData.new()
	stew.id = &"test_stew"
	stew.food_value = 20.0
	stew.heal_value = 30.0
	inv.remove_from_slot(0, 99)
	inv._put(0, stew, 3)
	consumer._cooldown_left = 5.0
	health.hp = health.max_hp
	hunger.set_food(50.0)
	consumer.try_use(stew, 0)
	_check(inv.slot_count(0) == 2 and is_equal_approx(hunger.food, 70.0) and is_equal_approx(consumer.cooldown_left(), 5.0), "both, heal refused: food eaten, item used once, cooldown not restarted")
	hunger.refill()
	_check(not consumer.try_use(stew, 0) and inv.slot_count(0) == 2, "both refused: nothing used")
	consumer._cooldown_left = 0.0
	health.hp = 10.0
	hunger.set_food(50.0)
	_check(consumer.try_use(stew, 0) and is_equal_approx(health.hp, 40.0) and is_equal_approx(hunger.food, 70.0) and is_equal_approx(consumer.cooldown_left(), consumer.potion_cooldown), "both apply: heal + food + cooldown")

	# respawn refills
	hunger.set_food(0.0)
	player.respawn()
	_check(is_equal_approx(hunger.food, hunger.max_food), "respawn refills food")

	# save round-trip
	hunger.set_food(37.0)
	var sg: SaveGame = arena.get_node("SaveGame")
	var d: Dictionary = sg.collect()
	_check(is_equal_approx(float(d["player"]["food"]), 37.0), "save holds food")
	hunger.set_food(100.0)
	sg.apply(d)
	_check(is_equal_approx(hunger.food, 37.0), "load restores food")
	d["player"].erase("food")
	sg.apply(d)
	_check(is_equal_approx(hunger.food, hunger.max_food), "old save without food: full bar")

	# raw click with food does not swing
	player.set_physics_process(true)
	inv.remove_from_slot(0, 99)
	inv._put(0, bread, 5)   # a hotbar slot, whatever the pack holds
	lo.select_instant(0)
	var wh: WeaponHolder = player.get_node("WeaponHolder")
	hunger.set_food(10.0)
	var before := inv.count(&"bread")
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	await _frames(3)
	_check(wh.phase == WeaponHolder.Phase.IDLE, "click with food: no swing")
	_check(inv.count(&"bread") == before - 1 and is_equal_approx(hunger.food, 35.0), "click with food eats exactly one (hold does not repeat)")

	print("RESULT: ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
