extends SceneTree
# Chest hold: a non-glowing material / placeable is carried with both hands in front of the chest, shown while idle; torch keeps the side carry.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _select(player: CharacterBody2D, inv: Inventory, lo: Loadout, item: ItemData) -> void:
	inv.add(item, 3)
	for i in Inventory.HOTBAR:
		if inv.slot_item(i) == item:
			lo.select(i)
	for i in 3:
		await physics_frame
	await process_frame
	await process_frame

func _init() -> void:
	var arena = await World.make(self)
	var player: CharacterBody2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	player.set_physics_process(true)
	var held := player.get_node("WeaponVisual/HeldItem") as HeldItemVisual
	var main := player.get_node("MainHandArt") as HandVisual
	var off := player.get_node("OffHandArt") as HandVisual
	var body := player.get_node("Visual") as SpriteActorVisual

	await _select(player, inv, lo, World.item("workbench"))
	_check(held.visible and held.chest_held() and player.get_node("WeaponVisual").visible, "workbench idle: shown, chest hold")
	var c := held.global_position
	var o: Vector2 = player.global_position
	var left := body.is_facing_left()
	var cs: float = held.chest.icon_size / held._item.icon.get_size().x
	var sz := held.texture.get_size() * cs
	_check(is_equal_approx(held.scale.x, cs), "chest_icon_size used: icon canvas -> same size as in the bag")
	var dx := maxf(sz.x * 0.5, held.chest.hand_min_spread)
	_check(main.global_position.distance_to(Vector2(o.x + (-1.0 if left else 1.0) * (held.chest.offset_x + dx), o.y + held.chest.hand_y)) < 0.01, "main hand under the item corner")
	_check(off.global_position.distance_to(Vector2(o.x + (-1.0 if left else 1.0) * (held.chest.offset_x - dx), o.y + held.chest.hand_y)) < 0.01, "off hand under the other corner")
	_check(main.global_position.y > c.y and absf(c.y - (o.y + held.chest.hand_y + held.chest.rest_overlap - sz.y * 0.5)) < 0.01 and absf(main.global_position.y - off.global_position.y) < 0.01, "hands at fixed chest height, item rests on them (centre above hands)")
	_check(held.z_index > main.z_index and held.z_index > off.z_index and not held.z_as_relative, "item drawn above both hands")
	_check(not held.flip_h and absf(held.rotation) < 0.001, "upright, not flipped")
	_check(absf((c.x - o.x) - (-held.chest.offset_x if left else held.chest.offset_x)) < 0.01, "item x = chest_offset (mirrors when facing left)")

	player._body_facing = Vector2.LEFT if not left else Vector2.RIGHT
	await physics_frame
	await physics_frame
	await process_frame
	var c2 := held.global_position
	_check(absf((c2.x - o.x) + (c.x - o.x)) < 0.01 and absf(c2.y - c.y) < 0.01, "facing the other way mirrors x")

	player.set_physics_process(false)   # player.gd pushes Consumer state every frame: drive the visual by hand
	held.set_eating(true)
	var ys := {}
	var hand_y := {}
	for i in 30:
		await process_frame
		ys[snappedf(held.bob_y(), 0.01)] = true
		hand_y[snappedf(main.global_position.y - off.global_position.y, 0.01)] = true
	_check(ys.size() == 2 and ys.has(-held.chest.bob_px) and ys.has(0.0), "eating: item bobs whole steps 0 / -eat_bob_px")
	held.set_eating(false)
	await process_frame
	_check(held.bob_y() == 0.0, "bob ends")
	player.set_physics_process(true)

	var torch := World.item("torch")
	await _select(player, inv, lo, torch)
	_check(held.visible and not held.chest_held() and held.z_as_relative, "torch: not chest hold")
	_check(off._at != "chest" and main._at != "chest", "torch: hands not in chest hold")

	var sword: ItemData = null
	for i in Inventory.HOTBAR:
		var it := inv.slot_item(i)
		if it != null and it.category == "weapon":
			sword = it
			lo.select(i)
	for i in 3:
		await physics_frame
	await process_frame
	_check(not held.chest_held(), "weapon / empty: not chest hold")
	await _select(player, inv, lo, World.item("workbench"))
	_check(held.chest_held() and not held.z_as_relative and held.z_index == held.chest.z, "item -> weapon -> item: chest draw layer back")
	print("RESULT ", "PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
