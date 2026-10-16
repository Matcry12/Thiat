extends CanvasLayer
class_name TuningPanel
## F3: Minecraft-F3-style panel. Left = live status readout. Right = live
## tuning sliders. See docs/wiki/prototype-v0.md §1c.
##
## The slider list is NOT hardcoded. `_collect_tunable_properties()` walks
## `get_property_list()` on each registered target and keeps FLOAT/INT/BOOL
## properties with PROPERTY_USAGE_SCRIPT_VARIABLE + PROPERTY_USAGE_EDITOR —
## i.e. every `@export`. Add a new `@export` anywhere on a registered target
## and it appears here with zero changes to this file.
##
## Dev-only: disabled in release exports unless `enabled_in_release` is set.

@export var enabled_in_release := false

@export var player_path: NodePath
@export var dummy_path: NodePath
@export var boss_path: NodePath
@export var debug_overlay_path: NodePath
@export var map_path: NodePath
@export var hit_fx_path: NodePath

## Per-property range override, for the few properties where "derive from the
## current value" (see `_range_for`) gives a bad slider range. Keyed by
## property name only — NOT a hardcoded list of which properties exist.
@export var range_overrides: Dictionary = {
	"arc_degrees": {"min": 10.0, "max": 360.0},
	"radius": {"min": 10.0, "max": 200.0},
	"art_angle_degrees": {"min": -180.0, "max": 180.0},
	"rest_angle_degrees": {"min": -180.0, "max": 180.0},
	"map_seed": {"min": 0.0, "max": 9999.0},
	"map_cols": {"min": 12.0, "max": 300.0},
	"map_rows": {"min": 12.0, "max": 200.0},
	"forest_end": {"min": 0.0, "max": 1.0},
	"rocky_end": {"min": 0.0, "max": 1.0},
	"island_threshold": {"min": 0.0, "max": 1.0},
	"island_noise": {"min": 0.0, "max": 1.0},
	"area_wobble": {"min": 0.0, "max": 1.0},
	"island_falloff": {"min": 0.5, "max": 4.0},
	"island_noise_frequency": {"min": 0.005, "max": 0.2},
	"zone_x": {"min": 0.0, "max": 1.0},
	"zone_y": {"min": 0.0, "max": 1.0},
	"player_spawn_x": {"min": 0.0, "max": 1.0},
	"player_spawn_y": {"min": 0.0, "max": 1.0},
	"dummy_offset_x": {"min": -600.0, "max": 600.0},
	"dummy_offset_y": {"min": -600.0, "max": 600.0},
	"patch_noise_threshold": {"min": 0.0, "max": 1.0},
	"dark_grass_chance": {"min": 0.0, "max": 1.0},
	"noise_frequency": {"min": 0.01, "max": 0.5},
	"border_density": {"min": 0.1, "max": 2.0},
	"shake_strength": {"min": 0.0, "max": 2.0},
	"hitstop_scale": {"min": 0.0, "max": 2.0},
	"max_frames": {"min": 0.0, "max": 30.0},
	"stop_frames": {"min": 0.0, "max": 12.0},
	"max_offset": {"min": 0.0, "max": 30.0},
	"decay": {"min": 0.0, "max": 5.0},
	"noise_speed": {"min": 1.0, "max": 80.0},
	"pitch_variation": {"min": 0.0, "max": 0.3},
	"shake": {"min": 0.0, "max": 1.0},
	"slowmo_scale": {"min": 0.05, "max": 1.0},
	"slowmo_time": {"min": 0.0, "max": 3.0},
	"flash_time": {"min": 0.0, "max": 0.5},
	"volume_db": {"min": -30.0, "max": 12.0},
	"pitch": {"min": 0.3, "max": 2.0},
	"stop_time_scale": {"min": 0.0001, "max": 0.2},
	"knockback": {"min": 0.0, "max": 150.0},
	"decay_rate": {"min": 1.0, "max": 40.0},
	"max_pending": {"min": 0.0, "max": 300.0},
	"knockback_scale": {"min": 0.0, "max": 3.0},
	"step_distance": {"min": 0.0, "max": 60.0},
	"recoil_px": {"min": 0.0, "max": 20.0},
	"recoil_time": {"min": 0.02, "max": 0.5},
	"spark_count": {"min": 0.0, "max": 30.0},
	"spark_speed": {"min": 0.0, "max": 500.0},
	"spark_life": {"min": 0.02, "max": 1.0},
	"spark_size": {"min": 1.0, "max": 6.0},
	"number_size": {"min": 0.0, "max": 32.0},
	"max_sparks": {"min": 16.0, "max": 400.0},
	"max_per_frame": {"min": 0.0, "max": 60.0},
	"spread_degrees": {"min": 0.0, "max": 180.0},
	"speed_jitter": {"min": 0.0, "max": 1.0},
	"drag": {"min": 0.0, "max": 20.0},
	"max_numbers": {"min": 4.0, "max": 60.0},
	"rise_speed": {"min": 0.0, "max": 200.0},
	"drift_speed": {"min": 0.0, "max": 100.0},
	"gravity": {"min": 0.0, "max": 600.0},
	"life": {"min": 0.1, "max": 2.0},
	"offset_y": {"min": -80.0, "max": 20.0},
	"scatter_x": {"min": 0.0, "max": 30.0},
	"merge_time": {"min": 0.0, "max": 1.0},
	"outline_size": {"min": 0.0, "max": 8.0},
	"pop_scale": {"min": 1.0, "max": 3.0},
	"pop_time": {"min": 0.01, "max": 0.5},
	"home_return_delay": {"min": 0.0, "max": 5.0},
	"home_return_speed": {"min": 10.0, "max": 600.0},
	"recoil_ease": {"min": 0.5, "max": 5.0},
	"fallback_hit_radius": {"min": 0.0, "max": 40.0},
	"life_min": {"min": 0.0, "max": 1.0},
	"fade_rate": {"min": 0.5, "max": 6.0},
	"test_amount": {"min": 1.0, "max": 200.0},
}

const SAVE_PATH := "user://tuning.json"

var _player: CharacterBody2D
var _dummy: CharacterBody2D
var _debug_overlay: CanvasLayer
var _weapon_holder: WeaponHolder
var _dummy_health: Health
var _player_health: Health
var _dodge: Dodge
var _attacker: Attacker
var _guard: Guard
var _guard_visual: GuardVisual
var _loadout: Loadout
var _skill_slot: SkillSlot
var _boss: Boss
var _map: ArenaMap
var _hit_fx: HitFx
var _collector: Collector
var _inventory: Inventory
var _crafter: Crafter
## The F3 status text needs at least this much free height (px) between the HUD blocks, else it hides.
@export var status_min_height := 80.0
var _placer: Placer
var _bag: BagPanel

var _targets: Array = []          # [{"name": String, "object": Object}]
var _controls: Dictionary = {}    # "Target.prop" -> {obj, prop, control, value_label, is_bool, is_int}
var _initial_values: Dictionary = {}  # "Target.prop" -> value captured at startup, for Reset

var _status_label: Label
var _status_panel: Control
var _status_scroll: ScrollContainer
var _right_panel: Control
var _seed_edit: LineEdit
var _tuning_list: VBoxContainer

var _total_damage := 0.0
var _last_damage := 0.0
var _hits := 0
var _swings := 0


func _ready() -> void:
	if not enabled_in_release and not OS.is_debug_build():
		queue_free()
		return

	_player = get_node(player_path)
	_dummy = get_node(dummy_path)
	_debug_overlay = get_node(debug_overlay_path)
	_weapon_holder = _player.get_node("WeaponHolder")
	_dummy_health = _dummy.get_node("Health")
	_player_health = _player.get_node("Health")
	_dodge = _player.get_node("Dodge")
	_attacker = _dummy.get_node("Attacker")
	_guard = _player.get_node("Guard")
	_guard_visual = _player.get_node("GuardVisual")
	_loadout = _player.get_node_or_null("Loadout")
	_skill_slot = _player.get_node_or_null("SkillSlot")
	_boss = get_node_or_null(boss_path) as Boss
	_map = get_node_or_null(map_path) as ArenaMap
	_hit_fx = get_node_or_null(hit_fx_path) as HitFx

	_dummy.set_meta("spot", _dummy.global_position)
	_weapon_holder.state_changed.connect(_on_weapon_state_changed)
	_dummy_health.damaged.connect(_on_dummy_damaged)

	_targets = [
		{"name": "Player", "object": _player},
		{"name": "WeaponVisual", "object": _player.get_node("WeaponVisual")},
		{"name": "Visual", "object": _player.visual},
		{"name": "RunDust", "object": _player.get_node("Visual/RunDust")},
	]
	if _player.visual.get("rig") != null:
		_targets.append({"name": "BodyRig", "object": _player.visual.rig})   # per-character body / weapon / hand fit (decision 0028)
	_targets += [
		{"name": "Dodge", "object": _dodge},
		{"name": "Guard", "object": _guard},
		{"name": "GuardVisual", "object": _guard_visual},
		{"name": "SwingFx", "object": _player.get_node("WeaponVisual/SwingFx")},
		{"name": "Hands", "object": _player.get_node("Hands")},
		{"name": "CoverArc", "object": _guard_visual.get_node("CoverArc")},
		{"name": "Player Health", "object": _player_health},
		{"name": "Dummy Health", "object": _dummy_health},
		{"name": "Attacker", "object": _attacker},
		{"name": "Debug", "object": _debug_overlay},
		{"name": "Loadout", "object": _loadout},
	]
	# One target per weapon in the loadout, named from its own file — not a
	# hardcoded index/name, so a third weapon needs zero changes here.
	if _loadout:
		for w in _loadout.weapons:
			if w:
				_targets.append({"name": _weapon_target_name(w), "object": w})
	# The E skill: the slot, and each weapon's own skill scene (its numbers).
	if _skill_slot:
		_targets.append({"name": "SkillSlot", "object": _skill_slot})
		for w in _loadout.weapons:
			var s := _skill_slot.skill_for(w)
			if s:
				_targets.append({"name": _weapon_target_name(w) + " Skill", "object": s})

	# The boss, its health, its brain and each attack (one section per attack,
	# found from the boss itself so a new attack needs no change here).
	if _boss:
		_targets.append({"name": "Boss", "object": _boss})
		_targets.append({"name": "Boss Health", "object": _boss.health})
		_targets.append({"name": "Boss Brain", "object": _boss.get_brain()})
		_targets.append({"name": "Boss Visual", "object": _boss.visual})
		for n in _boss.attack_names():
			_targets.append({"name": "Boss " + String(n).capitalize(), "object": _boss.get_attack(n)})

	if _map:
		_targets.append({"name": "Map", "object": _map})
		if _map.style:
			for gd in _map.style.grounds:   # the island grounds (edge outline, corner cut ...): changing one re-bakes the ground
				if gd:
					_targets.append({"name": "Ground " + String(gd.id), "object": gd})

	# Gathering (W2): the collector, the three node kinds (density applies on the next New map), the fists.
	_collector = _player.get_node_or_null("Collector") as Collector
	if _collector:
		_targets.append({"name": "Collector", "object": _collector})
	for k in ["tree", "rock", "copper_rock"]:
		_targets.append({"name": "Node " + k.replace("_rock", ""), "object": load("res://data/resource_nodes/%s.tres" % k)})
	if _loadout and _loadout.unarmed:
		_targets.append({"name": "Fists", "object": _loadout.unarmed})
	# Inventory (W3): the rules, each material's max stack, and the two starter tools' numbers.
	_inventory = _player.get_node_or_null("Inventory") as Inventory
	if _inventory:
		_targets.append({"name": "Inventory", "object": _inventory})
		for f in DirAccess.get_files_at("res://data/items"):
			var it := load("res://data/items/" + f) as ItemData
			if it == null:
				continue
			if it.category == "material":
				_targets.append({"name": "Item " + String(it.id), "object": it})
			elif it.category == "tool":
				_targets.append({"name": "Tool " + String(it.id), "object": it.weapon})

	# Crafting (W4, decision 0031): the Crafter / Placer numbers, one section per recipe and per smelt recipe.
	_crafter = _player.get_node_or_null("Crafter") as Crafter
	_placer = _player.get_node_or_null("Placer") as Placer
	if _crafter:
		_targets.append({"name": "Crafter", "object": _crafter})
		for r in _crafter.recipes:
			_targets.append({"name": "Recipe " + String(r.result.id), "object": r})
	if _placer:
		_targets.append({"name": "Placer", "object": _placer})
	for r in RecipeBook.load_dir("res://data/smelting"):
		_targets.append({"name": "Smelt " + String((r as SmeltRecipeData).output.id), "object": r})

	# Hit feel: the master switches, the three effect nodes, and one section per hit type (its .tres numbers).
	if _hit_fx:
		_targets.append({"name": "HitFx", "object": _hit_fx})
		_targets.append({"name": "HitStop", "object": _hit_fx.stop})
		_targets.append({"name": "CameraShake", "object": _hit_fx.shake})
		_targets.append({"name": "HitSound", "object": _hit_fx.sound})
		_targets.append({"name": "HitSparks", "object": _hit_fx.sparks})
		_targets.append({"name": "DamageNumbers", "object": _hit_fx.numbers})
		for prof in _hit_fx.profile_list():
			_targets.append({"name": "Hit " + String(prof.hit_type), "object": prof})

	# HUD top-right (decision 0024).
	var hud := get_node_or_null("../HUD") as HUD
	if hud and not hud.is_node_ready():
		await hud.ready          # tree order of HUD vs this panel does not matter
	if hud:
		_targets.append({"name": "HUD", "object": hud})
		_targets.append({"name": "HealthBar", "object": hud.health_bar()})
		if hud.hotbar():
			_targets.append({"name": "Hotbar", "object": hud.hotbar()})
		_bag = hud.bag()
		if _bag:
			_targets.append({"name": "BagPanel", "object": _bag})
			_targets.append({"name": "InventorySkin", "object": _bag.get_skin()})

	_targets.append({"name": "Dummy", "object": _dummy})

	# Real knockback (gameplay): one section per Knockback component (Dummy, Player, ...). The boss has none.
	for kb in get_tree().get_nodes_in_group("knockback"):
		_targets.append({"name": "Knockback " + kb.get_parent().name, "object": kb})

	_build_ui()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_panel"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	_clear_of_hud()
	_update_status_text()


# ---------------------------------------------------------------- status ---

func _update_status_text() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / maxf(fps, 1.0)

	var vel: Vector2 = _player.velocity
	var move_state := "run" if vel.length() > 1.0 else "idle"
	var facing := "left" if _player.aim_direction.x < 0.0 else "right"
	var aim_deg := rad_to_deg(_player.aim_direction.angle())

	var weapon: WeaponData = _weapon_holder.weapon
	var weapon_name := "(none)"
	if weapon != null:
		weapon_name = weapon.resource_path.get_file().get_basename() if weapon.resource_path != "" else "(unsaved)"
	var phase_names := ["idle", "windup", "active", "recovery"]
	var phase_name: String = phase_names[_weapon_holder.phase]
	var phase_duration := 0.0
	if weapon != null:
		match _weapon_holder.phase:
			WeaponHolder.Phase.WINDUP: phase_duration = weapon.windup
			WeaponHolder.Phase.ACTIVE: phase_duration = weapon.active
			WeaponHolder.Phase.RECOVERY: phase_duration = weapon.recovery
	# ponytail: reaches into WeaponHolder._phase_time (no getter exists) because
	# adding one would mean editing combat code, which the brief disallows.
	var time_left := maxf(0.0, phase_duration - _weapon_holder._phase_time)

	var hurtbox_count := get_tree().get_nodes_in_group("hurtbox").size()
	var hit_rate := (float(_hits) / _swings * 100.0) if _swings > 0 else 0.0

	_status_label.text = "\n".join([
		"[Engine]",
		"fps: %d  frame: %.1f ms  time_scale: %.2f" % [fps, frame_ms, Engine.time_scale],
		"",
		"[Player]",
		"pos: (%d, %d)" % [roundi(_player.global_position.x), roundi(_player.global_position.y)],
		"vel: %.0f  state: %s  facing: %s" % [vel.length(), move_state, facing],
		"aim: %.0f deg" % aim_deg,
		_player.visual.status_text() if _player.visual.has_method("status_text") else "",
		"",
		"[Weapon]",
		"%s  phase: %s  left: %.2fs" % [weapon_name, phase_name, time_left],
		"",
		"[Combat]",
		"last dmg: %.1f  total: %.1f" % [_last_damage, _total_damage],
		"hits: %d  swings: %d  rate: %.0f%%" % [_hits, _swings, hit_rate],
		"",
		"[Entities]",
		"hurtboxes: %d  dummy hp: %.0f" % [hurtbox_count, _dummy_health.hp],
		_dummy.status_text(),
		"",
		"[Hands]",
		(_player.get_node("Hands") as HandsVisual).status_text(),
		"",
		"[Dodge]",
		"cooldown left: %.2fs  i-frames active: %s" % [_dodge.cooldown_remaining(), _dodge.iframes_active()],
		"",
		"[Guard]",
		"state: %s  tank: %.0f/%.0f" % [Guard.State.keys()[_guard.state].to_lower(), _guard.tank, _guard.tank_max],
		"",
		"[Player Health]",
		"shield: %.0f/%.0f  hp: %.0f/%.0f" % [_player_health.shield, _player_health.shield_max, _player_health.hp, _player_health.max_hp],
		"",
		"[Enemy Attack]",
		"state: %s" % Attacker.Phase.keys()[_attacker.phase].to_lower(),
		"",
		"[Boss]",
		_boss.status_text() if _boss else "n/a",
		"",
		"[Map]",
		_map.status_text() if _map else "n/a",
		"",
		"[Hit FX]",
		_hit_fx.status_text() if _hit_fx else "n/a",
		"",
		"[Knockback (gameplay)]",
		_knockback_status_text(),
		"",
		"[Loadout]",
		_loadout_status_text(),
		"",
		"[Gather]",
		_gather_status_text(),
		"",
		"[Inventory]",
		_inventory_status_text(),
		"",
		"[Crafting]",
		_crafting_status_text(),
		"",
		"[Skills (E)]",
		_skill_status_text(),
	])

func _knockback_status_text() -> String:
	var lines: Array[String] = []
	for kb in get_tree().get_nodes_in_group("knockback"):
		lines.append((kb as Knockback).status_text())
	lines.append("boss: no Knockback (visual jolt only)")
	return "\n".join(lines)


func _loadout_status_text() -> String:
	if _loadout == null:
		return "n/a"
	var active: WeaponData = _loadout.active_weapon()
	var active_name := "(none)"
	if active != null:
		active_name = active.resource_path.get_file().get_basename() if active.resource_path != "" else "(unsaved)"
	var swap_state := "ready"
	if _loadout.is_casting():
		swap_state = "casting %.2fs" % _loadout.cast_left()
	elif _loadout.cooldown_left() > 0.0:
		swap_state = "cooldown %.2fs" % _loadout.cooldown_left()
	return "active: %s (%d)%s  swap: %s" % [active_name, _loadout.active_index(), " HOLSTERED" if _loadout.is_holstered() else "", swap_state]


func _gather_status_text() -> String:
	if _collector == null or _loadout == null:
		return "n/a"
	var w: WeaponData = _loadout.active_weapon()
	var inv := _collector.inventory()
	var counts := []
	for id in inv.items():
		counts.append("%s %d" % [id, inv.count(id)])
	return "%s  gather_damage %.1f  tool_power %d\nlast hit: %s\nitems: %s  on ground: %d\n(density changes apply on New map)" % [
		"HOLSTERED" if _loadout.is_holstered() else "armed",
		w.gather_damage if w else 0.0, w.tool_power if w else 0,
		_collector.last_gather if _collector.last_gather != "" else "-",
		", ".join(counts) if counts else "none",
		get_tree().get_nodes_in_group("pickup").size()]


func _inventory_status_text() -> String:
	if _inventory == null or _loadout == null:
		return "n/a"
	var it := _inventory.slot_item(_loadout.selected_slot)
	var w := _loadout.active_weapon()
	var bag := "locked (boss engaged)" if _inventory.locked() else ("open" if _bag and _bag.is_open() else "closed")
	var held := "%s x%d" % [_inventory.held_item.display_name, _inventory.held_count] if _inventory.held_item else "-"
	return "slot %d: %s  hands: %s%s\nslots used %d/%d  hotbar weapons %d/%d\nbag: %s  cursor: %s" % [
		_loadout.selected_slot + 1, it.display_name if it else "(empty)",
		w.item_name() if w else "-", " (swap casting)" if _loadout.is_casting() else "",
		_inventory.used_slots(), Inventory.SIZE, _inventory.hotbar_weapon_count(), _inventory.max_hotbar_weapons,
		bag, held]


func _crafting_status_text() -> String:
	if _crafter == null:
		return "n/a"
	var ids := []
	for sid in _crafter.station_ids_in_range():
		ids.append(String(sid))
	var lines: Array[String] = []
	lines.append("stations in range: %s  recipes shown: %d" % [", ".join(ids) if not ids.is_empty() else "none", _crafter.visible_recipes().size()])
	if _placer:
		var held := _placer.held_item()
		lines.append("placing: %s  spot: %s  last: %s" % [held.display_name if held else "-", ("ok" if _placer.last_refusal == "" else "refused (%s)" % _placer.last_refusal) if held else "-", _placer.last_placed if _placer.last_placed != "" else "-"])
		lines.append("path flood (on click only): %.1f ms" % _placer.last_neck_ms)
	var furnaces := get_tree().get_nodes_in_group("furnace")
	if furnaces.is_empty():
		lines.append("furnaces: none placed")
	for f: Furnace in furnaces:
		lines.append("furnace %d: %s" % [furnaces.find(f) + 1, f.status_text()])
	lines.append("last craft: %s" % (_crafter.last_craft if _crafter.last_craft != "" else "-"))
	return "\n".join(lines)


func _place_here(id: String) -> void:
	if _placer:
		_placer.place_free(load("res://data/items/%s.tres" % id))


func _finish_smelting() -> void:
	for f: Furnace in get_tree().get_nodes_in_group("furnace"):
		f.finish_all()


func _give(id: String, amount := 1) -> void:
	_inventory.add(load("res://data/items/%s.tres" % id), amount)


func _fill_bag() -> void:
	_give("wood", 99999)   # fills every free slot with wood stacks; leftover is dropped


func _break_nearest_node() -> void:
	var best: ResourceNode
	for n: ResourceNode in get_tree().get_nodes_in_group("resource_node"):
		if n.is_broken():
			continue
		if best == null or n.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position):
			best = n
	if best:
		var w := WeaponData.new()
		w.gather_damage = 999.0
		w.tool_power = 9
		best.take_gather_hit(w, _player)


func _give_items(amount: int) -> void:
	for f in DirAccess.get_files_at("res://data/items"):
		var it := load("res://data/items/" + f) as ItemData if f.ends_with(".tres") else null
		if it and it.category == "material":
			_collector.inventory().add(it, amount)


func _skill_status_text() -> String:
	if _skill_slot == null or _loadout == null:
		return "n/a"
	var lines: Array[String] = []
	for w in _loadout.weapons:
		var s := _skill_slot.skill_for(w)
		var state := "no skill"
		if s:
			var cd := _skill_slot.cooldown_left(w)
			state = "ready" if cd <= 0.0 else "cooldown %.2fs" % cd
			if s.is_active():
				state = "ACTIVE, " + state
		lines.append("%s: %s" % [_weapon_target_name(w), state])
	return "\n".join(lines)


func _on_weapon_state_changed(state: String) -> void:
	if state == "windup":
		_swings += 1


func _on_dummy_damaged(amount: float) -> void:
	_last_damage = amount
	_total_damage += amount
	_hits += 1


func _weapon_target_name(w: WeaponData) -> String:
	if w.resource_path == "":
		return "Weapon"
	return w.resource_path.get_file().get_basename().capitalize()


# ------------------------------------------------------------- reflection ---

func _collect_tunable_properties(obj: Object) -> Array:
	var result: Array = []
	for prop in obj.get_property_list():
		var usage: int = prop["usage"]
		if usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		if prop["type"] != TYPE_FLOAT and prop["type"] != TYPE_INT and prop["type"] != TYPE_BOOL:
			continue
		result.append({"name": prop["name"], "type": prop["type"]})
	return result


func _range_for(prop_name: String, current: float) -> Vector2:
	if range_overrides.has(prop_name):
		var o: Dictionary = range_overrides[prop_name]
		return Vector2(o["min"], o["max"])
	if current > 0.0:
		return Vector2(0.0, maxf(current * 4.0, 1.0))
	elif current < 0.0:
		var a := maxf(absf(current) * 4.0, 1.0)
		return Vector2(-a, a)
	return Vector2(0.0, 1.0)


# --------------------------------------------------------------------- UI ---

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = Color(0, 0, 0, 0.55)
	panel_bg.content_margin_left = 8
	panel_bg.content_margin_right = 8
	panel_bg.content_margin_top = 6
	panel_bg.content_margin_bottom = 6

	# --- status, top-left. Blocks its own small area only, not the screen. ---
	var status_panel := PanelContainer.new()
	status_panel.position = Vector2(8, 8)
	status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	status_panel.add_theme_stylebox_override("panel", panel_bg)
	root.add_child(status_panel)
	_status_panel = status_panel

	_status_scroll = ScrollContainer.new()
	_status_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_status_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	status_panel.add_child(_status_scroll)
	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 13)
	_status_scroll.add_child(_status_label)

	# --- tuning, top-right, scrollable ---
	var tuning_panel := PanelContainer.new()
	tuning_panel.anchor_left = 1.0
	tuning_panel.anchor_right = 1.0
	tuning_panel.offset_left = -360
	tuning_panel.offset_right = -8
	tuning_panel.offset_top = 8
	tuning_panel.offset_bottom = -8
	tuning_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tuning_panel.add_theme_stylebox_override("panel", panel_bg)
	root.add_child(tuning_panel)
	_right_panel = tuning_panel

	var tuning_vbox := VBoxContainer.new()
	tuning_panel.add_child(tuning_vbox)

	var button_row := HBoxContainer.new()
	tuning_vbox.add_child(button_row)
	_add_button(button_row, "Save", _on_save_pressed)
	_add_button(button_row, "Load", _on_load_pressed)
	_add_button(button_row, "Reset", _on_reset_pressed)

	var action_row := HBoxContainer.new()
	tuning_vbox.add_child(action_row)
	_add_button(action_row, "Heal dummy", _on_heal_dummy)
	_add_button(action_row, "Heal player", _on_heal_player)
	_add_button(action_row, "Hurt player 20", func(): _player_health.take_damage(20.0, null, false))
	_add_button(action_row, "Reset stats", _on_reset_stats)
	_add_button(action_row, "Reset skill cd", func(): _skill_slot.reset_cooldowns())
	if _map:
		_add_button(action_row, "New map", func(): _map.new_map())
		_add_button(action_row, "Go home", func(): _map.teleport_player("home"))
		_add_button(action_row, "Go to boss", func(): _map.teleport_player("boss"))

	if _map:
		var seed_row := HBoxContainer.new()
		tuning_vbox.add_child(seed_row)
		var seed_label := Label.new()
		seed_label.text = "Seed (1-9999)"
		seed_row.add_child(seed_label)
		_seed_edit = LineEdit.new()
		_seed_edit.placeholder_text = "1-9999"
		_seed_edit.max_length = 4
		_seed_edit.custom_minimum_size = Vector2(70, 0)
		_seed_edit.text_changed.connect(_on_seed_text_changed)
		_seed_edit.text_submitted.connect(func(_t: String): _on_generate_pressed())   # Enter
		seed_row.add_child(_seed_edit)
		_add_button(seed_row, "Generate", _on_generate_pressed)

	if _boss:
		var boss_row := HBoxContainer.new()
		tuning_vbox.add_child(boss_row)
		_add_button(boss_row, "Phase 2", func(): _boss.force_phase_2())
		for n in _boss.attack_names():
			_add_button(boss_row, "-> " + String(n), func(): _boss.force_next(n))
		var boss_row2 := HBoxContainer.new()
		tuning_vbox.add_child(boss_row2)
		_add_button(boss_row2, "Boss passive", func(): _boss.passive = not _boss.passive)
		_add_button(boss_row2, "Heal boss", func(): _boss.health.hp = _boss.health.max_hp)
		_add_button(boss_row2, "Restart", func(): get_tree().reload_current_scene())

	if _hit_fx:
		var fx_row := HBoxContainer.new()
		tuning_vbox.add_child(fx_row)
		_add_button(fx_row, "Test sword hit", func(): _hit_fx.test_hit(&"sword"))
		_add_button(fx_row, "Test parry", func(): _hit_fx.test_hit(&"parry"))
		_add_button(fx_row, "Test player hit", func(): _hit_fx.test_hit(&"player_hit"))
		_add_button(fx_row, "Test kill FX", func(): _hit_fx.test_hit(&"kill"))
		var fx_row2 := HBoxContainer.new()
		tuning_vbox.add_child(fx_row2)
		_add_button(fx_row2, "Test boss hit", func(): _hit_fx.test_hit(&"boss_sword"))
		_add_button(fx_row2, "Test lunge", func(): _hit_fx.test_hit(&"lunge"))
		_add_button(fx_row2, "Test charged arrow", func(): _hit_fx.test_hit(&"charged_arrow"))
	if _collector:
		var gather_row := HBoxContainer.new()
		tuning_vbox.add_child(gather_row)
		_add_button(gather_row, "Break nearest node", _break_nearest_node)
		_add_button(gather_row, "Give 10 each", func(): _give_items(10))
		_add_button(gather_row, "Clear items", func(): _collector.inventory().clear())
	if _inventory:
		var inv_row := HBoxContainer.new()
		tuning_vbox.add_child(inv_row)
		_add_button(inv_row, "Give axe", func(): _give("stone_axe"))
		_add_button(inv_row, "Give pickaxe", func(): _give("stone_pickaxe"))
		_add_button(inv_row, "Give sword", func(): _give("sword"))
		_add_button(inv_row, "Fill bag", _fill_bag)
		_add_button(inv_row, "Give W3 kit", func(): _inventory.give_dev_kit())
	if _crafter:
		var craft_row := HBoxContainer.new()
		tuning_vbox.add_child(craft_row)
		_add_button(craft_row, "Give materials (20 each)", func(): _give_items(20))
		_add_button(craft_row, "Finish smelting", _finish_smelting)
		var place_row := HBoxContainer.new()
		tuning_vbox.add_child(place_row)
		_add_button(place_row, "Place workbench here", func(): _place_here("workbench"))
		_add_button(place_row, "Place furnace here", func(): _place_here("furnace"))
		_add_button(place_row, "Place anvil here", func(): _place_here("anvil"))
	var kb_row := HBoxContainer.new()
	tuning_vbox.add_child(kb_row)
	_add_button(kb_row, "Knockback on/off", _toggle_knockback)
	_add_button(kb_row, "Dummy to spot", func(): _reset_dummy_spot())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 480)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tuning_vbox.add_child(scroll)

	_tuning_list = VBoxContainer.new()
	_tuning_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tuning_list)

	for target in _targets:
		_add_target_section(target["name"], target["object"])


## Digits only: anything else typed or pasted is dropped.
func _on_seed_text_changed(t: String) -> void:
	var clean := ""
	for ch in t:
		if ch >= "0" and ch <= "9":
			clean += ch
	if clean != t:
		var caret := _seed_edit.caret_column
		_seed_edit.text = clean
		_seed_edit.caret_column = mini(caret, clean.length())


## Generate button / Enter: build the map for exactly the typed seed, then give the keys back to the game.
func _on_generate_pressed() -> void:
	if _seed_edit.text.is_empty():
		return
	var n := clampi(int(_seed_edit.text), 1, 9999)
	_seed_edit.text = str(n)
	_seed_edit.release_focus()
	_map.generate_seed(n)
	var key := "Map.map_seed"
	if _controls.has(key):
		_controls[key]["control"].set_value_no_signal(n)
		_controls[key]["value_label"].text = _format_value(n)


func _add_button(parent: Control, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)


func _add_target_section(target_name: String, obj: Object) -> void:
	if obj == null:
		return
	var props := _collect_tunable_properties(obj)
	if props.is_empty():
		return

	var heading := Label.new()
	heading.text = "-- %s --" % target_name
	heading.add_theme_font_size_override("font_size", 14)
	_tuning_list.add_child(heading)

	for prop_info in props:
		_add_property_row(target_name, obj, prop_info["name"], prop_info["type"])


func _add_property_row(target_name: String, obj: Object, prop_name: String, type: int) -> void:
	var key := "%s.%s" % [target_name, prop_name]
	var current = obj.get(prop_name)
	_initial_values[key] = current

	var row := HBoxContainer.new()
	_tuning_list.add_child(row)

	var name_label := Label.new()
	name_label.text = prop_name
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)

	if type == TYPE_BOOL:
		var check := CheckBox.new()
		check.button_pressed = current
		check.toggled.connect(func(pressed: bool): _apply_value(key, pressed))
		row.add_child(check)
		_controls[key] = {"obj": obj, "prop": prop_name, "control": check, "value_label": name_label, "is_bool": true, "is_int": false}
	else:
		var is_int := type == TYPE_INT
		var range_v := _range_for(prop_name, float(current))
		var slider := HSlider.new()
		slider.min_value = range_v.x
		slider.max_value = range_v.y
		slider.step = 1.0 if is_int else maxf((range_v.y - range_v.x) / 200.0, 0.001)
		slider.value = float(current)
		slider.custom_minimum_size = Vector2(140, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)

		var value_label := Label.new()
		value_label.text = _format_value(current)
		value_label.custom_minimum_size = Vector2(55, 0)
		row.add_child(value_label)

		slider.value_changed.connect(func(v: float): _apply_value(key, v))
		_controls[key] = {"obj": obj, "prop": prop_name, "control": slider, "value_label": value_label, "is_bool": false, "is_int": is_int}


func _format_value(v) -> String:
	if typeof(v) == TYPE_BOOL:
		return "true" if v else "false"
	elif typeof(v) == TYPE_FLOAT:
		return "%.2f" % v
	return str(v)


# ---------------------------------------------------------- apply / save ---

## Single entry point for every value change: slider drag, checkbox toggle,
## Load, and Reset all go through this — so all of them print the change
## line and keep the widget in sync with the target.
func _apply_value(key: String, value) -> void:
	if not _controls.has(key):
		return
	var entry: Dictionary = _controls[key]
	var obj: Object = entry["obj"]
	var prop: String = entry["prop"]
	var old = obj.get(prop)

	var new_value
	if entry["is_bool"]:
		new_value = bool(value)
		obj.set(prop, new_value)
		entry["control"].set_pressed_no_signal(new_value)
	elif entry["is_int"]:
		new_value = roundi(float(value))
		obj.set(prop, new_value)
		entry["control"].set_value_no_signal(new_value)
	else:
		new_value = float(value)
		obj.set(prop, new_value)
		entry["control"].set_value_no_signal(new_value)
		entry["value_label"].text = _format_value(new_value)

	print("%s: %s -> %s" % [key, old, new_value])


func _on_save_pressed() -> void:
	var data := {}
	for key in _controls.keys():
		var entry: Dictionary = _controls[key]
		var o: Object = entry["obj"]
		data[key] = o.save_value(entry["prop"]) if o.has_method("save_value") else o.get(entry["prop"])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("tuning: saved -> %s" % SAVE_PATH)


func _on_load_pressed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("tuning: no save file at %s" % SAVE_PATH)
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		print("tuning: save file is corrupt")
		return
	for key in data.keys():
		_apply_value(key, data[key])
	print("tuning: loaded <- %s" % SAVE_PATH)


func _on_reset_pressed() -> void:
	for key in _initial_values.keys():
		_apply_value(key, _initial_values[key])
	print("tuning: reset to startup values")


## Knockback switch for every actor that has one (gameplay; independent from the Hit FX switch).
func _toggle_knockback() -> void:
	var kbs := get_tree().get_nodes_in_group("knockback")
	var on := true
	for kb in kbs:
		on = on and not kb.enabled
	for kb in kbs:
		kb.enabled = on
		if _controls.has("Knockback %s.enabled" % kb.get_parent().name):
			_controls["Knockback %s.enabled" % kb.get_parent().name]["control"].set_pressed_no_signal(on)
	print("tuning: knockback -> %s" % ("on" if on else "off"))


func _reset_dummy_spot() -> void:
	if _dummy.has_meta("spot"):
		_dummy.global_position = _dummy.get_meta("spot")
		_dummy.home = _dummy.get_meta("spot")


func _on_heal_dummy() -> void:
	_dummy_health.hp = _dummy_health.max_hp
	print("tuning: dummy healed -> %.0f" % _dummy_health.hp)


func _on_heal_player() -> void:
	_player_health.hp = _player_health.max_hp
	_player_health.shield = _player_health.shield_max
	print("tuning: player healed -> hp %.0f, shield %.0f" % [_player_health.hp, _player_health.shield])


func _on_reset_stats() -> void:
	_total_damage = 0.0
	_last_damage = 0.0
	_hits = 0
	_swings = 0
	print("tuning: stats reset")


## For the HUD: how wide the right panel is (from the screen edge) and where the status panel ends, in px.
## The status panel sits on the left, where the HUD now lives: keep it below the top-left block and above
## the bottom-left one, so nothing overlaps while F3 is open. It clips (scrolls) instead of growing.
func _clear_of_hud() -> void:
	var hud := get_node_or_null("../HUD") as HUD
	if hud == null or _status_scroll == null:
		return
	var ins := hud.f3_insets()
	var vh := get_viewport().get_visible_rect().size.y
	_status_panel.position.y = ins.x
	var room := vh - ins.x - ins.y - 12.0
	# Bag + recipe list + furnace box open can leave no room at all: hide the text rather than cover the icons.
	var win := hud.craft_window().frame_rect() if hud.craft_window() else Rect2()
	var covered := win.has_area() and _status_panel.position.x + _status_panel.size.x > win.position.x - 8.0   # the centred window
	_status_panel.visible = room >= status_min_height and not covered
	_status_scroll.custom_minimum_size.y = maxf(room, status_min_height)


func right_panel_width() -> float:
	return -_right_panel.offset_left if _right_panel else 0.0

func left_panel_right() -> float:
	return _status_panel.position.x + _status_panel.size.x if _status_panel else 0.0
