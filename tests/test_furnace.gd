extends SceneTree
# W4 furnace: N items take N * smelt_time, even with the player far away; the output cap pauses it; the slot
# clicks (cursor, shift) move stacks and respect the boss lock; a pickaxe pickup returns the contents.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = await World.make(self)
	var player: Node2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var pl: Placer = player.get_node("Placer")
	var boss: Boss = arena.get_node("Boss")
	boss.set_physics_process(false)
	var ore := World.item("copper_ore")
	var bar := World.item("copper_bar")
	var st := pl.place_free(World.item("furnace"))
	var f: Furnace = st.furnace()
	await physics_frame
	var t := (load("res://data/smelting/copper_bar.tres") as SmeltRecipeData).smelt_time
	_check(t == 3.0 and f.recipe_for(ore) != null and f.recipe_for(World.item("wood")) == null, "copper ore -> bar is a smelt recipe (3 s); wood is not")
	_check(f.accepts(ore) and not f.accepts(World.item("wood")), "the input takes ore only")

	# --- N items take N * smelt_time, with nobody near ---
	player.global_position += Vector2(3000, 0)   # far away
	_check(f.put_input(ore, 4) == 0 and f.in_count == 4, "4 ore in")
	f.advance(t * 0.5)
	_check(f.out_count == 0 and f.in_count == 4 and absf(f.progress_frac() - 0.5) < 0.01, "half way through the first one: nothing yet (%.2f)" % f.progress_frac())
	f.advance(t * 0.5)
	_check(f.out_count == 1 and f.in_count == 3 and f.out_item == bar, "one smelt_time: first bar out, 3 ore left")
	f.advance(t * 3.0 - 0.01)
	_check(f.out_count == 3 and f.in_count == 1, "just short of the 4th: 3 bars, 1 ore still in")
	f.advance(0.02)
	_check(f.out_count == 4 and f.in_count == 0 and f.in_item == null and not f.is_running(), "after 4 * smelt_time: 4 bars, input empty, idle")
	_check(f.progress_frac() == 0.0, "idle: no progress cue")

	# --- it also runs by itself in physics time ---
	f.take_output()
	f.put_input(ore, 2)
	var smelt_before := f.smelted_total
	f.recipe_for(ore).smelt_time = 0.1   # the number is data: shrink it for the test
	for i in 40:
		await physics_frame
	_check(f.out_count == 2 and f.smelted_total == smelt_before + 2, "the physics tick smelts without the player (%d bars)" % f.out_count)
	f.recipe_for(ore).smelt_time = t
	f.take_output()

	# --- output full: it pauses, then goes on ---
	f.out_item = bar
	f.out_count = bar.stack_limit() - 1
	f.put_input(ore, 3)
	f.advance(t * 10.0)
	_check(f.out_count == bar.stack_limit() and f.in_count == 2, "output full: 1 more bar then it stops (%d ore left)" % f.in_count)
	f.take_output()
	f.advance(t * 10.0)
	_check(f.in_count == 0 and f.out_count == 2, "room again: it finishes")
	f.take_output()

	# --- F3 finish ---
	f.put_input(ore, 5)
	f.finish_all()
	_check(f.out_count == 5 and f.in_count == 0, "Finish smelting: 5 bars at once")
	f.take_output()

	# --- clicks through the cursor ---
	player.global_position -= Vector2(3000, 0)
	inv.clear()
	inv.add(ore, 10)
	var slot := -1
	for i in Inventory.SIZE:
		if inv.slot_item(i) == ore:
			slot = i
	_check(inv.click_slot(slot) and inv.held_item == ore, "pick the ore up with the cursor")
	_check(f.click_input(inv) and f.in_count == 10 and inv.held_item == null, "click the input slot: the stack goes in")
	_check(not f.click_input(inv) or inv.held_item != null, "empty cursor: takes it back")
	_check(inv.held_item == ore and inv.held_count == 10 and f.in_item == null, "...the cursor holds the 10 ore again")
	inv.return_held()
	_check(f.shift_in_from_slot(inv, slot) and f.in_count == 10 and inv.count(&"copper_ore") == 0, "shift click on a bag slot: ore goes straight in")
	var wood_slot := -1
	inv.add(World.item("wood"), 5)
	for i in Inventory.SIZE:
		if inv.slot_item(i) != null and inv.slot_item(i).id == &"wood":
			wood_slot = i
	_check(not f.shift_in_from_slot(inv, wood_slot) and inv.count(&"wood") == 5, "wood is refused and stays")
	f.advance(t * 2)
	_check(f.out_count == 2, "2 bars are ready")
	_check(f.shift_output(inv) and inv.count(&"copper_bar") == 2 and f.out_item == null, "shift click on the output: bars to the inventory")
	_check(f.shift_input(inv) and inv.count(&"copper_ore") == 8 and f.in_item == null, "shift click on the input: the rest of the ore comes back")
	f.put_input(ore, 3)
	f.advance(t)
	_check(f.click_output(inv) and inv.held_item == bar and inv.held_count == 1, "click on the output: the bar is on the cursor")
	inv.return_held()

	# --- locked in the boss fight ---
	boss.aggro = Boss.Aggro.ENGAGED
	_check(not f.click_input(inv) and not f.click_output(inv) and not f.shift_input(inv) and not f.shift_output(inv), "boss engaged: the furnace slots are locked like the bag")
	boss.aggro = Boss.Aggro.IDLE

	# --- picking the furnace up returns what is inside, never loses it ---
	var ore_before := inv.count(&"copper_ore")
	var bars_before := inv.count(&"copper_bar")
	f.put_input(ore, 2)
	f.out_item = bar
	f.out_count = 3
	var pickaxe: WeaponData = load("res://data/weapons/stone_pickaxe.tres")
	st.take_gather_hit(pickaxe, player)
	await physics_frame
	var ore_now := inv.count(&"copper_ore") + _on_ground(&"copper_ore")
	_check(inv.count(&"furnace") == 1 and ore_now >= ore_before + 2 and inv.count(&"copper_bar") + _on_ground(&"copper_bar") >= bars_before + 3, "pickup: furnace + 2 ore + 3 bars all came back")
	quit(0 if _ok else 1)

func _on_ground(id: StringName) -> int:
	var n := 0
	for p in get_nodes_in_group("pickup"):
		if p.item.id == id:
			n += p.amount
	return n
