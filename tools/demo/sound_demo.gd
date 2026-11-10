extends Node
## Demo of the sound system: `tools/demo/record_sound.sh`. Runs in the Test yard. Real swings where easy, else the same calls the
## game makes (take_gather_hit, take_damage with the weapon), so HitFx -> SoundBoard is the real path. Prints
## "BEAT n <label> | last sound" so the log shows each beat made the right sound.

var _caption: Label
var _beats := 0
var _arena: Node
var _player: CharacterBody2D
var _holder: WeaponHolder
var _loadout: Loadout
var _inv: Inventory
var _map: ArenaMap
var _board: SoundBoard

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_caption = Label.new()
	# top-centre, below the hotbar row, on a dark backing
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_top = 112
	_caption.offset_left = -450
	_caption.offset_right = 450
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0, 0, 0, 0.7)
	back.set_content_margin_all(8)
	back.set_corner_radius_all(6)
	_caption.add_theme_stylebox_override("normal", back)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _beat(text: String) -> void:
	_beats += 1
	_caption.text = text
	print("BEAT %d %.1fs %s" % [_beats, Time.get_ticks_msec() / 1000.0, text])

func _report(what: String) -> void:
	print("BEAT_SOUND %d %s | last=%s plays=%d silent=%d" % [_beats, what, _board.last_event, _board.play_count, _board.silent_count])

func _slot_of(id: StringName) -> int:
	for i in 9:
		var it := _inv.slot_item(i)
		if it != null and it.id == id:
			return i
	return -1

func _equip(id: StringName) -> void:
	_loadout.select_instant(_slot_of(id))
	await _wait(0.5)

## Stand `dist` px left of `to`, aim at it.
func _stand_at(to: Vector2, dist := 46.0) -> void:
	_map.teleport_player(to + Vector2(-dist, 0))
	_player.aim_override = Vector2.RIGHT
	await _wait(0.6)

## Real swings until `done` is true (or `limit` s). Returns the number of swings.
func _swing_until(done: Callable, limit := 8.0, max_swings := 99) -> int:
	var t := 0.0
	var n := 0
	while not done.call() and t < limit and n < max_swings:
		if _holder.phase == WeaponHolder.Phase.IDLE:
			_holder.try_attack()
			n += 1
		await get_tree().process_frame
		t += get_process_delta_time()
	await _wait(0.5)
	return n

## A broken rock / copper is freed after its pop: gone counts as broken.
func _gone(n: Variant) -> bool:
	return not is_instance_valid(n) or n.is_broken()

func _run() -> void:
	ArenaMap.yard_mode = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	_arena = arena
	await _wait(1.5)
	_map = arena.get_node("ArenaMap")
	_player = arena.get_node("Player")
	_holder = _player.get_node("WeaponHolder")
	_loadout = _player.get_node("Loadout")
	_inv = _player.get_node("Inventory")
	var fx: HitFx = arena.get_node("HitFx")
	_board = fx.sound
	arena.get_node("DebugOverlay").set("enabled", false)
	var boss = arena.get_node("Boss")
	boss.passive = true
	var home := _map.home_point()
	var dummy: Node2D = arena.get_node("Dummy")
	await _wait(1.0)

	# 1. chop a tree
	var tree := _map.nearest_node(&"treepp_oak_green_old", home) as ResourceNode
	_beat("Chop a tree: wood.hit each hit, ONE wood.break on the last")
	await _equip(&"stone_axe")
	await _stand_at(tree.global_position)
	var plays0 := _board.play_count
	var hits := await _swing_until(func(): return _gone(tree), 10.0)
	if not _gone(tree):
		while not _gone(tree):
			tree.take_gather_hit(_loadout.active_weapon(), _player)
			await _wait(0.4)
	_report("tree: %d swings, broken=%s, sounds=%d" % [hits, _gone(tree), _board.play_count - plays0])
	await _wait(1.0)

	# 2. rock with the pickaxe
	var rock := _map.nearest_node(&"rock", home) as ResourceNode
	_beat("Break a rock with the pickaxe: stone.hit, then ONE stone.break")
	await _equip(&"stone_pickaxe")
	await _stand_at(rock.global_position)
	plays0 = _board.play_count
	hits = await _swing_until(func(): return _gone(rock), 12.0)
	if not _gone(rock):
		while not _gone(rock):
			rock.take_gather_hit(_loadout.active_weapon(), _player)
			await _wait(0.4)
	_report("rock: %d swings, broken=%s, sounds=%d" % [hits, _gone(rock), _board.play_count - plays0])
	await _wait(1.0)

	# 3. copper: weak tool clink, then pickaxe
	var ore := _map.nearest_node(&"copper_rock", home) as ResourceNode
	_beat("Copper: axe is too weak = metal_ore.wrong_tool (clink)")
	await _equip(&"stone_axe")
	await _stand_at(ore.global_position)
	await _swing_until(func(): return _board.last_event == &"metal_ore.wrong_tool", 4.0, 2)
	_report("copper with axe")
	_beat("Copper: pickaxe = metal_ore.hit ... then metal_ore.break")
	await _equip(&"stone_pickaxe")
	await _swing_until(func(): return _gone(ore), 12.0)
	while not _gone(ore):
		ore.take_gather_hit(_loadout.active_weapon(), _player)
		await _wait(0.4)
	_report("copper broken")
	await _wait(1.0)

	# 4. station with the wrong tool
	var st: Station = get_tree().get_nodes_in_group("station")[0]
	_beat("Wrong tool on a station (axe on workbench): wood.wrong_tool")
	await _equip(&"stone_axe")
	await _stand_at(st.global_position, 60.0)
	await _swing_until(func(): return _board.last_event == &"wood.wrong_tool", 4.0, 3)
	_report("station knock")
	await _wait(1.0)

	# 5. sword on dummy (real swings) and on the slime
	_beat("Sword on the dummy: the TARGET sounds (flesh.hit)")
	await _equip(&"wooden_sword")
	await _stand_at(dummy.global_position, 50.0)
	dummy.attacker.set_physics_process(false)
	for i in 3:
		_holder.try_attack()
		await _wait(0.7)
	_report("sword on dummy")
	var slime: Enemy = get_tree().get_first_node_in_group("enemy")
	if slime:
		_beat("Sword on the slime: flesh.hit")
		_map.teleport_player(slime.global_position + Vector2(-60, 0))
		await _wait(0.8)
		for i in 2:
			slime.health.take_damage(4.0, _player, true, &"melee", _loadout.active_weapon())
			await _wait(0.8)
		_report("sword on slime")

	# 6. boss killing hit
	_beat("Boss killing hit: ONE sound only (boss_orc.break)")
	boss.global_position = _player.global_position + Vector2(120, 0)
	await _wait(2.0)   # the boss is on screen before the hit
	boss.health.hp = 1.0
	var p := _board.play_count
	boss.health.take_damage(50.0, _player, true, &"melee", _loadout.active_weapon())
	await _wait(2.0)
	_report("boss kill: sounds=%d" % (_board.play_count - p))

	# 7. F3 Sound section
	_beat("F3 > Tune > search 'Sound': every set and cue is tunable")
	var panel := arena.get_node("TuningPanel") as TuningPanel
	panel.cycle()
	await _wait(0.8)
	panel.dock.show_tab("Tune")
	for i in 8:   # keep the search on "Sound" (the dock may redraw) so the Sound / set / cue rows stay visible
		if panel.dock.search_text() != "Sound":
			panel.dock.set_search("Sound")
		await _wait(0.5)
	print("F3 search=%s tab=%s" % [panel.dock.search_text(), panel.dock.current_tab()])
	print("DONE")
	get_tree().quit()
