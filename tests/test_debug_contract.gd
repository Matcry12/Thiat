extends SceneTree
# F3 extension contract (tools/f3_mock/DESIGN.md): every section the panel had before the refactor is still reachable through
# the "debug" group + debug_children(), every old button exists, every debug node has a category, key ranges are @export_range.
# Targets/labels below are the old tuning_panel._ready list, hardcoded.
const OLD_TARGETS := [
	"Player", "WeaponVisual", "Visual", "RunDust", "Swimmer", "WaterFx",
	"BodyRig", "Dodge", "Guard", "GuardVisual", "SwingFx",
	"CoverArc", "Player Health", "Dummy Health", "Attacker", "Debug", "Loadout",
	"Wooden Sword", "SkillSlot", "Wooden Sword Skill", "Boss", "Boss Health", "Boss Brain",
	"Boss Visual", "Boss Slam", "Boss Spread", "Boss Charge", "Boss Ring", "Map",
	"Biome plains", "Biome forest", "Biome autumn", "Biome taiga", "Biome snowy", "Biome rocky",
	"Biome swamp", "Biome beach (sand)", "Biome beach (gravel)", "Collector", "Node rock",
	"Node copper", "Node treepp_oak_green_sapling", "Node treepp_oak_green_young", "Node treepp_oak_green_mature", "Node treepp_oak_green_old",
	"Inventory", "Tool copper_axe", "Item copper_bar", "Item copper_ore", "Tool copper_pickaxe", "Item stone",
	"Tool stone_axe", "Tool stone_pickaxe", "Item wood", "Respawner", "Crafter", "Recipe workbench",
	"Recipe stone_pickaxe", "Recipe stone_axe", "Recipe bow", "Recipe furnace", "Recipe anvil", "Recipe copper_sword",
	"Recipe copper_axe", "Recipe copper_pickaxe", "Recipe torch", "Placer", "Smelt copper_bar", "HitFx", "HitStop",
	"CameraShake", "Sound", "HitSparks", "DamageNumbers", "Hit sword", "Hit sword_boss",
	"Hit lunge", "Hit arrow", "Hit charged_arrow", "Hit parry", "Hit block", "Hit player_hit",
	"Hit phase_change", "Hit kill", "Hit chop", "Hit mine", "Hit clink", "Hit node_break",
	"HUD", "HealthBar", "Hotbar", "BagPanel", "InventorySkin", "Dummy",
	"Knockback Player", "Knockback Dummy",
]
const OLD_ACTIONS := [
	"Heal player", "Hurt player 20", "Reset skill cd", "Kill player", "Go to nearest drop", "New map", "Go home", "Go to boss",
	"Biome map", "Generate", "Phase 2", "-> slam", "-> spread", "-> charge", "-> ring", "Boss passive", "Heal boss",
	"Test sword hit", "Test parry", "Test player hit", "Test kill FX", "Test boss hit", "Test lunge", "Test charged arrow", "Knockback on/off",
	"Break nearest node", "Give 10 each", "Clear items", "Give axe", "Give pickaxe", "Fill bag", "Give W3 kit",
	"Give materials (20 each)", "Finish smelting", "Place workbench here", "Place furnace here", "Place anvil here",
	"Save now", "Load save", "Delete save", "Heal dummy", "Dummy to spot", "Reset stats", "Restart", "Save rig",
]
const CATEGORIES := ["Character", "Combat", "Boss", "World", "Items & Crafting", "FX & Hit", "HUD", "Run", "Misc"]
const DANGER := ["Kill player", "Delete save", "Restart"]

func _walk(node: Dictionary, acc: Array) -> void:
	acc.append(node)
	if node["object"].has_method("debug_children"):
		for c in node["object"].debug_children():
			_walk(c, acc)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var ok := true
	var acc: Array = []
	var actions := {}
	for n in get_nodes_in_group("debug"):
		if not (n.has_method("debug_name") and n.has_method("debug_category")):
			print("FAIL: debug node without debug_name/debug_category: ", n.name)
			ok = false
			continue
		if not CATEGORIES.has(n.debug_category()):
			print("FAIL: bad category ", n.debug_category(), " on ", n.debug_name())
			ok = false
		_walk({"name": n.debug_name(), "object": n}, acc)
		if n.has_method("debug_actions"):
			for a in n.debug_actions():
				actions[a["label"]] = a
	var names := {}
	for e in acc:
		names[e["name"]] = true
		if e.get("cat", "Misc") is String and not CATEGORIES.has(e.get("cat", "Misc")):
			print("FAIL: bad child category ", e)
			ok = false
	for t in OLD_TARGETS:
		if not names.has(t):
			print("FAIL: missing target ", t)
			ok = false
	var extra := []
	for k in names:
		if not OLD_TARGETS.has(k) and not (k as String).begins_with("Tool ") and not (k as String).begins_with("Recipe ") and not (k as String).begins_with("Sound "):   # one "Tool <id>" section per tool: a new tool must not break this list   # one "Sound <set>" (+ cue) section per data/sounds file
			extra.append(k)
	extra.sort()
	print("targets: %d old, %d found; new owners: %s" % [OLD_TARGETS.size(), names.size(), extra])
	if extra != ["ChestHold", "Consumer", "DayClock", "DayNightData", "EatCrumbs", "Eating", "EffectBar", "Effects", "EnemySpawner", "Frame", "HeldItem","Hit station_knock_stone", "Hit station_knock_wood", "Hit station_pickup_stone", "Hit station_pickup_wood", "Hit tree_break", "Item bread", "Item cooked_pork", "Item gel", "Item healing_potion", "Item key", "Item raw_pork", "Item sausage", "Item soup", "Light campfire", "Light player glow", "Light torch", "MainHandArt", "NodeReaction", "OffHandArt", "Pixel Plains", "Run", "Save", "Swing Sword Natural", "Weapon"]:   # status-only owners that had a block but no section
		print("FAIL: unexpected extra names ", extra)
		ok = false
	for l in OLD_ACTIONS:
		if not actions.has(l):
			print("FAIL: missing action ", l)
			ok = false
	for l in DANGER:
		if not actions.get(l, {}).get("danger", false):
			print("FAIL: not danger: ", l)
			ok = false
	for a in actions.values():
		if not (a.has("label") and a.has("run")):
			print("FAIL: malformed action ", a)
			ok = false
	# status blocks the old panel printed
	var status_owners := []
	for n in get_nodes_in_group("debug"):
		if n.has_method("status_text") and str(n.status_text()) != "":
			status_owners.append(n.debug_name())
	for s in ["Player", "Weapon", "Dodge", "Guard", "Boss", "Map", "HitFx", "Loadout", "Collector", "Inventory", "Crafter", "Respawner", "Save", "Frame", "SkillSlot", "Attacker", "Dummy", "Run"]:
		if not status_owners.has(s):
			print("FAIL: no status_text from ", s)
			ok = false
	# ranges moved from the panel's range_overrides dict onto the @export
	var map = get_first_node_in_group("arena_map")
	var hits := 0
	for pair in [[map, "land_share"], [map, "map_seed"], [map, "river_w_inland"], [get_first_node_in_group("hit_fx").shake, "shake_strength"], [get_first_node_in_group("hit_fx").sparks, "max_sparks"], [get_first_node_in_group("player").get_node("Knockback"), "knockback_scale"]]:
		for p in pair[0].get_property_list():
			if p["name"] == pair[1] and int(p["hint"]) == PROPERTY_HINT_RANGE:
				hits += 1
		if not pair[0].get_property_list().any(func(p): return p["name"] == pair[1]):
			print("note: prop not found ", pair[1])
	if hits < 5:
		print("FAIL: @export_range hints missing (%d/6)" % hits)
		ok = false
	# heavy flags = old _is_heavy
	if not (map.debug_heavy("land_share") and not map.debug_heavy("tint_bright") and not map.debug_heavy("load_radius")):
		print("FAIL: ArenaMap.debug_heavy")
		ok = false
	var bd: BiomeData = map.style.biomes[0]
	if not (bd.debug_heavy("ground") and not bd.debug_heavy("tint_bright")):
		print("FAIL: BiomeData.debug_heavy")
		ok = false
	print("test_debug_contract: ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
