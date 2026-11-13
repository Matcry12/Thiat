extends SceneTree
# W4 placing stations: the ghost follows the selected placeable, is refused on water / nodes / stations / the
# boss area / the player, a click places it and takes the item, a pickaxe hit gives it back.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _tap(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	Input.action_release(action)
	await physics_frame

func _init() -> void:
	var arena = await World.make(self)
	var player: CharacterBody2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var pl: Placer = player.get_node("Placer")
	var m: ArenaMap = arena.get_node("ArenaMap")
	var boss: Boss = arena.get_node("Boss")
	boss.set_physics_process(false)
	var wb_item := World.item("workbench")
	var fp := Vector2(56, 28)
	player.aim_override = Vector2.RIGHT
	player.set_physics_process(true)   # the real attack click goes through the player
	await physics_frame

	# --- ghost + click placing ---
	_check(not pl.is_holding() and pl.ghost() == null, "nothing placeable selected: no ghost")
	inv.add(wb_item, 2)
	var slot := -1
	for i in Inventory.HOTBAR:
		if inv.slot_item(i) == wb_item:
			slot = i
	_check(slot >= 0, "the workbench is in the hotbar (slot %d)" % (slot + 1))
	lo.select(slot)
	await physics_frame
	await physics_frame
	_check(pl.is_holding() and pl.ghost() != null and pl.ghost().ghost, "workbench selected: a ghost follows")
	_check(pl.ghost().get_node_or_null("CraftStation") == null and pl.ghost().collision_layer == 0, "the ghost is not a station and does not collide")
	_check(get_nodes_in_group("craft_station").is_empty(), "the ghost does not count as a station in range")
	var target := pl.target_pos()
	_check(is_equal_approx(fmod(target.x, pl.grid_px), pl.grid_px * 0.5) and is_equal_approx(fmod(target.y, pl.grid_px), pl.grid_px * 0.5), "the target snaps to the middle of a grid cell")
	_check(pl.last_refusal == "" and pl.ghost().modulate == pl.ok_color, "free spot: the ghost is white")
	await _tap("attack")
	_check(inv.count(&"workbench") == 1 and get_nodes_in_group("station").size() == 1, "attack click placed it: 1 left in the bag, 1 in the world")
	var wb: Station = get_nodes_in_group("station")[0]
	_check(wb.global_position == target and wb.item == wb_item, "it stands on the target")
	_check(player.weapon_holder.phase == WeaponHolder.Phase.IDLE, "the click placed, it did not swing")

	# --- a second one on the same spot is refused (station) and the ghost turns red ---
	await physics_frame
	await physics_frame
	_check(pl.last_refusal == "station" and pl.ghost().modulate == pl.bad_color, "on another station: refused, ghost red")
	await _tap("attack")
	_check(inv.count(&"workbench") == 1 and get_nodes_in_group("station").size() == 1, "the refused click placed nothing and kept the item")

	# --- refusals by place (check_at is the one rule) ---
	var far := player.global_position + Vector2(0, 220)
	_check(pl.check_at(pl.snap(far), fp) == "", "a free spot is accepted")
	var p := m.make_params()
	var water := Vector2.ZERO
	for y in range(5, 15):
		for x in range(5, 15):
			if m.result.land[y * p.cols + x] == 0:
				water = (Vector2(x, y) + Vector2(0.5, 0.5)) * p.cell
	_check(pl.check_at(water, fp) == "water", "on water: refused")
	_check(pl.check_at(Vector2(-50, -50), fp) == "water", "off the map: refused")
	var coast := Vector2.ZERO   # land cell with a water neighbour: the footprint overhangs the water
	for y in range(p.rows / 3, p.rows * 2 / 3):
		for x in range(p.cols - 2, p.cols / 2, -1):
			if MapGen.is_land(m.result, p, Vector2i(x, y)) and not MapGen.is_land(m.result, p, Vector2i(x + 1, y)):
				coast = (Vector2(x, y) + Vector2(0.9, 0.5)) * p.cell
				break
		if coast != Vector2.ZERO:
			break
	_check(coast != Vector2.ZERO and pl.check_at(coast, fp) == "water", "half over the shore: refused")
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/treepp_oak_green_mature.tres"), 0)
	tree.position = far
	arena.add_child(tree)
	_check(pl.check_at(far + Vector2(10, 0), fp) == "node", "on a tree: refused")
	var fists: WeaponData = load("res://data/weapons/stone_axe.tres")
	while not tree.is_broken():
		tree.take_gather_hit(fists, player)
	_check(pl.check_at(far, fp) == "pickup", "the wood it dropped lies there: refused (pickup)")
	for pk in get_nodes_in_group("pickup"):
		pk.free()
	_check(pl.check_at(far, fp) == "", "the tree is broken (a stump) and the wood is gone: the spot is free")
	_check(pl.check_at(boss.global_position, fp) == "boss", "at the boss: refused")
	_check(pl.check_at(player.global_position, fp) == "player", "on the player: refused")
	_check(m.in_boss_area(boss.global_position) and not m.in_boss_area(m.home_point()), "ArenaMap knows the boss area")

	# --- the corridor to the boss is never walled off ---
	var cpx := m.cell_px()
	var bcell := Vector2i((far / cpx).floor())
	m.result.bridge[bcell] = true
	_check(m.in_corridor(far) and pl.check_at(far, fp) == "corridor", "on the land bridge: refused (corridor)")
	var edge := (Vector2(bcell) + Vector2(1.0, 0.5)) * cpx + Vector2(fp.x * 0.5 - 2.0, 0)   # centre outside the bridge cell, footprint straddles it
	_check(not m.in_corridor(edge) and pl.check_at(edge, fp) == "corridor", "a footprint that only straddles the bridge is refused too")
	m.result.bridge.erase(bcell)
	_check(pl.check_at(far, fp) == "", "no bridge: the same spot is fine")

	# --- locked while a boss is engaged ---
	boss.aggro = Boss.Aggro.ENGAGED
	_check(pl.check_at(far, fp) == "locked", "boss engaged: placing is refused (locked)")
	boss.aggro = Boss.Aggro.IDLE

	# --- the ghost cue: a green / red tint and a 1 px outline ---
	await physics_frame
	await physics_frame
	var g: Station = pl.ghost()
	_check(g.outline != null and g.outline.width == pl.outline_width and g.outline.default_color == (pl.outline_ok if pl.last_refusal == "" else pl.outline_bad), "the ghost has an outline in the ok / bad colour")
	_check(pl.ok_color.g > pl.ok_color.r and pl.bad_color.r > pl.bad_color.g, "ok is green, bad is red")

	# --- one owner for the size: the scene's collision shape ---
	var probe: Station = load("res://scenes/stations/anvil.tscn").instantiate()
	_check(probe.footprint() == (probe.get_node("CollisionShape2D").shape as RectangleShape2D).size, "footprint() reads the body shape")
	var exported := probe.get_property_list().filter(func(pr): return pr.name in ["footprint", "item", "hurtbox_pad"] and pr.usage & PROPERTY_USAGE_EDITOR != 0)
	_check(exported.is_empty(), "footprint, hurtbox_pad and item are not editable fields any more")
	probe.free()

	# --- a tall station may not hide the one behind it ---
	var fur: Station = load("res://scenes/stations/furnace.tscn").instantiate()
	var wb_pos := wb.global_position
	var front := wb_pos + Vector2(0, 40)   # the footprints are apart; the 82 px tall furnace picture covers the workbench
	var fp_f := fur.footprint()
	_check(not Rect2(front - fp_f * 0.5, fp_f).grow(pl.clearance).intersects(Rect2(wb_pos - fp * 0.5, fp)), "(the two ground boxes do not touch)")
	_check(pl.check_at(front, fp_f) == "", "by ground box alone it would be accepted")
	_check(pl.check_at(front, fp_f, fur.art_rect_local()) == "station", "with the picture boxes it is refused: it would hide the workbench")
	_check(pl.check_at(wb_pos + Vector2(0, -120), fp_f, fur.art_rect_local()) == "", "far enough behind / beside it is fine")
	fur.free()

	# --- natural necks: no station may cut the walk from home to the boss ---
	var home_px := m.home_point()
	var wall: Array[Rect2] = [Rect2(home_px.x + 700.0, 0.0, 60.0, m.map_size().y)]
	var small: Array[Rect2] = [Rect2(home_px + Vector2(300, 100), Vector2(56, 28))]
	_check(not m.blocks_boss_path(small), "a small box in the open does not cut the path")
	var t_small := m.last_walk_check_ms
	_check(m.blocks_boss_path(wall), "a wall across the whole island does")
	print("     path flood: %.1f ms (small), %.1f ms (wall)" % [t_small, m.last_walk_check_ms])
	_check(m.last_walk_check_ms < 250.0, "one flood stays cheap (%.1f ms)" % m.last_walk_check_ms)
	var wall_rect: Rect2 = wall[0]
	_check(pl._blocks_path(m, wall_rect.get_center(), wall_rect), "the Placer asks the same question")
	pl.last_neck_ms = -1.0
	await physics_frame
	await physics_frame
	_check(pl.last_neck_ms == -1.0, "the per-frame ghost check never runs the flood")
	_check(pl.check_at(far, fp) == "" and pl.last_neck_ms == -1.0, "check_at without with_neck skips it too")
	m.last_walk_check_ms = -1.0
	pl._neck_key = []
	pl.check_at(far, fp, Rect2(), true)
	_check(m.last_walk_check_ms >= 0.0, "with_neck (the place click) runs it")
	pl._blocks_path(m, wall_rect.get_center(), wall_rect)   # prime the cache
	m.last_walk_check_ms = -1.0
	pl._blocks_path(m, wall_rect.get_center(), wall_rect)
	_check(m.last_walk_check_ms == -1.0, "the same spot is answered from the cache (no second flood)")

	# --- free placing from F3 ---
	var n_before := get_nodes_in_group("station").size()
	var f3 := pl.place_free(World.item("furnace"))
	_check(f3 != null and get_nodes_in_group("station").size() == n_before + 1 and inv.count(&"furnace") == 0, "the F3 button places for free and takes nothing")

	# --- picking up: a pickaxe hit only ---
	var pickaxe: WeaponData = load("res://data/weapons/stone_pickaxe.tres")
	_check(not wb.take_gather_hit(fists, player) and is_instance_valid(wb), "a punch does not pick it up")
	_check(not wb.take_gather_hit(load("res://data/weapons/stone_axe.tres"), player) and is_instance_valid(wb), "an axe does not either")
	var far_one := pl.place_free(World.item("anvil"))
	await physics_frame
	_check(wb.take_gather_hit(pickaxe, player) and far_one.take_gather_hit(pickaxe, player), "a pickaxe hit picks it up (two stations in one swing)")
	await process_frame
	await process_frame
	await create_timer(0.5).timeout   # a picked-up station pops first, then it is freed
	var gone := 0
	for st in [wb, far_one]:
		gone += 0 if is_instance_valid(st) else 1
	_check(gone == 1, "one swing takes ONE station, the nearest (%d taken)" % gone)
	var left: Station = wb if is_instance_valid(wb) else far_one
	_check(not left.take_gather_hit(pickaxe, player), "right after a pickup the lockout refuses the next one")
	await _real(0.65)
	_check(left.take_gather_hit(pickaxe, player), "after the lockout the next one can be taken")
	await process_frame
	await process_frame
	await create_timer(0.4).timeout   # the pop plays before the node is freed
	_check(not is_instance_valid(wb) and not is_instance_valid(far_one) and inv.count(&"workbench") == 2 and inv.count(&"anvil") == 1, "both are back in the inventory (workbench %d, anvil %d)" % [inv.count(&"workbench"), inv.count(&"anvil")])

	# --- pick_up(null) keeps the station and its contents ---
	var keep := pl.place_free(World.item("furnace"))
	keep.furnace().put_input(World.item("copper_ore"), 3)
	keep.pick_up(null)
	await physics_frame
	_check(is_instance_valid(keep) and not keep.is_queued_for_deletion() and keep.furnace().in_count == 3, "pick_up(null) frees nothing and loses nothing")

	# --- a station freed between the hit and the resolve cannot jam later pickups ---
	await _real(0.65)
	var doomed := pl.place_free(World.item("anvil"))
	doomed.take_gather_hit(pickaxe, player)
	doomed.free()
	await process_frame
	await process_frame
	_check(keep.take_gather_hit(pickaxe, player), "after a freed station's hit the next pickaxe hit still registers")
	await process_frame
	await process_frame
	await create_timer(0.4).timeout   # the pop plays before the node is freed
	_check(not is_instance_valid(keep) and inv.count(&"furnace") >= 1, "...and picks it up (the furnace is back)")

	# --- the real swing: the pickaxe in hand, a station in reach (the hit source is the weapon model, not the player) ---
	await _real(0.65)
	inv.give_dev_kit()
	await physics_frame
	var near := pl.place_free(World.item("anvil"))
	near.global_position = player.global_position + Vector2(38, 0)
	lo.select(3)
	await physics_frame
	_check(lo.active_weapon().tool_kind == &"pickaxe", "the stone pickaxe is in hand")
	player.weapon_holder.aim_direction = Vector2.RIGHT
	player.weapon_holder.try_attack()
	for i in 40:
		await physics_frame
	_check(not is_instance_valid(near) and inv.count(&"anvil") == 1, "a real pickaxe swing picked the anvil up into the inventory (%d)" % inv.count(&"anvil"))
	# --- two rebuilds in one frame hand every item over once ---
	await _real(0.65)
	pl.place_free(World.item("workbench"))
	pl.place_free(World.item("anvil"))
	var pre_w := inv.count(&"workbench") + _ground(&"workbench")
	var pre_a := inv.count(&"anvil") + _ground(&"anvil")
	var n_w2 := 0
	var n_a2 := 0
	for st: Station in get_nodes_in_group("station"):
		n_w2 += 1 if st.item.id == &"workbench" else 0
		n_a2 += 1 if st.item.id == &"anvil" else 0
	m.rebuild(true)
	m.rebuild(true)
	await physics_frame
	await physics_frame
	_check(inv.count(&"workbench") + _ground(&"workbench") == pre_w + n_w2 and inv.count(&"anvil") + _ground(&"anvil") == pre_a + n_a2, "two rebuilds in one frame: each station's item came back once, not twice")

	# --- New map clears the stations: item + contents come back to the inventory ---
	await _real(0.65)
	var s1 := pl.place_free(World.item("furnace"))
	s1.furnace().put_input(World.item("copper_ore"), 2)
	var s2 := pl.place_free(World.item("workbench"))
	var fur_before := inv.count(&"furnace") + _ground(&"furnace")
	var wb_before := inv.count(&"workbench") + _ground(&"workbench")
	var ore_before := inv.count(&"copper_ore") + _ground(&"copper_ore")
	var n_f := 0
	var n_w := 0
	for st: Station in get_nodes_in_group("station"):
		n_f += 1 if st.item.id == &"furnace" else 0
		n_w += 1 if st.item.id == &"workbench" else 0
	m.rebuild(true)
	await physics_frame
	await physics_frame
	await create_timer(0.4).timeout   # the pop plays before the node is freed
	_check(not is_instance_valid(s1) and not is_instance_valid(s2) and get_nodes_in_group("station").is_empty(), "New map: no station is left standing")
	_check(inv.count(&"furnace") + _ground(&"furnace") == fur_before + n_f and inv.count(&"workbench") + _ground(&"workbench") == wb_before + n_w and inv.count(&"copper_ore") + _ground(&"copper_ore") == ore_before + 2, "...their items and the furnace's ore came back (inventory or dropped at the player): f %d/%d wb %d/%d ore %d/%d" % [inv.count(&"furnace") + _ground(&"furnace"), fur_before + n_f, inv.count(&"workbench") + _ground(&"workbench"), wb_before + n_w, inv.count(&"copper_ore") + _ground(&"copper_ore"), ore_before + 2])
	quit(0 if _ok else 1)

func _ground(id: StringName) -> int:
	var n := 0
	for p in get_nodes_in_group("pickup"):
		if p.item.id == id:
			n += p.amount
	return n

## Waits real milliseconds: the pickup lockout counts wall-clock time, and a scene timer can run slower (hit-stop).
func _real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
