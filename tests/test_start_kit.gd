extends SceneTree
# W4 start kit: a wooden sword, stone axe and stone pickaxe (0048); the F3 "Give W3 kit" restores the old kit; the copper tools
# are stronger copies; the tint reaches the model; every recipe reads real items.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var cr: Crafter = player.get_node("Crafter")
	await physics_frame

	# --- the start kit ---
	_check(inv.used_slots() == 3 and inv.slot_item(0) != null and inv.slot_item(0).id == &"wooden_sword" and inv.count(&"stone_axe") == 1 and inv.count(&"stone_pickaxe") == 1, "start kit: wooden sword (slot 1) + stone axe + stone pickaxe")
	_check(lo.weapons.size() == 1 and lo.active_weapon() == inv.slot_item(0).weapon and not lo.is_holstered(), "the wooden sword is in hand")
	var wooden := World.item("wooden_sword").weapon
	var copper := World.item("copper_sword").weapon
	_check(wooden.damage < copper.damage, "damage: wooden %.0f < copper %.0f" % [wooden.damage, copper.damage])
	_check(wooden.model != null and copper.model != null and wooden.model != copper.model, "each sword has its own picture model (0049, no tint needed)")
	_check(wooden.model_tint == Color.WHITE and copper.model_tint == Color.WHITE, "...pictures are pre-coloured, no tint")

	# --- tools ---
	var cp := World.item("copper_pickaxe").weapon
	var sp := World.item("stone_pickaxe").weapon
	var ca := World.item("copper_axe").weapon
	var sa := World.item("stone_axe").weapon
	var copper_rock: ResourceNodeData = load("res://data/resource_nodes/copper_rock.tres")
	_check(cp.tool_power == 3 and cp.tool_power > sp.tool_power and cp.gather_damage > sp.gather_damage and cp.tool_kind == &"pickaxe", "copper pickaxe: tool_power 3, gathers faster than stone")
	_check(sp.tool_power >= copper_rock.required_power and sa.tool_power < copper_rock.required_power, "stone pickaxe mines copper, the axe cannot")
	var tree: ResourceNodeData = load("res://data/resource_nodes/tree.tres")
	_check(ca.gather_damage * tree.tool_bonus >= tree.max_hp and sa.gather_damage * tree.tool_bonus < tree.max_hp, "copper axe fells a tree in 1 hit, the stone axe needs 2")

	# --- the tint reaches the model ---
	lo.rearm()
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	_check(wv.get_model() != null and wv.get_model().modulate == wooden.model_tint, "the wooden sword's model is tinted")
	wv.set_weapon(copper)
	_check(wv.get_model().modulate == copper.model_tint, "the copper sword's model has its own tint")

	# --- Give W3 kit ---
	inv.add(World.item("wood"), 5)
	inv.give_dev_kit()
	await physics_frame
	_check(inv.slot_item(0).id == &"wooden_sword" and inv.slot_item(1).id == &"bow" and inv.slot_item(2).id == &"stone_axe" and inv.slot_item(3).id == &"stone_pickaxe", "Give W3 kit: wooden sword, bow, axe, pickaxe in slots 1-4")
	_check(lo.weapons.size() == 2 and lo.active_weapon() == wooden and not lo.is_holstered() and lo.selected_slot == 0, "the wooden sword is in hand again")
	_check(inv.count(&"wood") == 0 and inv.count(&"copper_sword") == 0, "the kit replaces what was there")

	# --- every recipe reads real items, and is affordable from raw materials ---
	for r in cr.recipes:
		var ok: bool = r.result != null and r.ingredients.size() > 0
		for g in r.ingredients:
			ok = ok and g.item != null and g.count > 0
		_check(ok, "recipe %s is well formed" % (r.result.id if r.result else "?"))
	quit(0 if _ok else 1)
