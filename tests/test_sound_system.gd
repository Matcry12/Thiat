extends SceneTree
# Sound system (sound-algorithm.md): every thing has a SoundSet, a breaking hit plays ONE sound (break_), a wrong tool plays
# wrong_tool, the target makes the impact sound, an arrow keeps the bow's own impact.
const ClassicArena = preload("res://tests/support/classic_arena.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _files(dir: String, ext := ".tres") -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(ext):
			out.append(dir + "/" + f)
	return out

func _init() -> void:
	# --- data completeness
	var missing: Array[String] = []
	for f in _files("res://data/resource_nodes"):
		if (load(f) as ResourceNodeData).sound_set == null:
			missing.append(f)
	for f in _files("res://data/weapons"):
		if (load(f) as WeaponData).sound_set == null:
			missing.append(f)
	for f in _files("res://data/enemies"):
		var e := load(f) as EnemyData
		if e != null and e.sound_set == null:
			missing.append(f)
	for f in _files("res://scenes/stations", ".tscn") + ["res://scenes/player.tscn", "res://scenes/boss.tscn", "res://scenes/dummy.tscn"]:
		var inst: Node = load(f).instantiate()
		if SoundSet.of(inst) == null:
			missing.append(f)
		inst.free()
	_check(missing.is_empty(), "every node / weapon / enemy / station / actor has a sound_set (missing: %s)" % [missing])
	_check(SoundSet.all().size() >= 9, "data/sounds has the starting sets")
	for s in SoundSet.all():
		for slot in SoundSet.SLOTS:
			var c := s.get(slot) as SoundCue
			if c != null and c.stream == null:
				_check(false, "%s.%s has a cue without a stream" % [s.id, slot])

	var arena = ClassicArena.make()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var fx: HitFx = arena.get_node("HitFx")
	var board: SoundBoard = fx.sound
	var player = arena.get_node("Player")
	var dummy = arena.get_node("Dummy")
	player.set_physics_process(false)
	dummy.attacker.set_physics_process(false)

	# --- a hit, then the breaking hit: exactly one sound, break_
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	tree.position = player.global_position + Vector2(40, 160)
	arena.add_child(tree)
	await physics_frame
	var axe := WeaponData.new()
	axe.gather_damage = 1.0
	axe.tool_power = 9
	tree.hp = 3.0
	tree.data.max_hp = 3.0
	var n := board.play_count
	tree.take_gather_hit(axe, player)
	_check(board.play_count == n + 1 and board.last_event == &"wood.hit", "non-breaking chop: one sound, wood.hit (got %s)" % board.last_event)
	n = board.play_count
	tree.hp = 1.0
	tree.take_gather_hit(axe, player)
	_check(tree.is_broken() and board.play_count == n + 1 and board.last_event == &"wood.break", "breaking chop: exactly one sound, wood.break (%d plays, %s)" % [board.play_count - n, board.last_event])

	# --- wrong tool
	var ore: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	ore.setup(load("res://data/resource_nodes/copper_rock.tres"), 0)
	ore.position = player.global_position + Vector2(-60, 160)
	arena.add_child(ore)
	await physics_frame
	var weak := WeaponData.new()
	weak.gather_damage = 1.0
	weak.tool_power = 0
	n = board.play_count
	ore.take_gather_hit(weak, player)
	_check(board.play_count == n + 1 and board.last_event == &"metal_ore.wrong_tool", "weak tool on copper: metal_ore.wrong_tool (got %s)" % board.last_event)
	var bench: Station = load("res://scenes/stations/workbench.tscn").instantiate()
	bench.position = player.global_position + Vector2(-120, 220)
	arena.add_child(bench)
	await physics_frame
	n = board.play_count
	bench.take_gather_hit(axe, player)
	_check(board.last_event == &"wood.wrong_tool" and board.play_count == n + 1, "wrong tool on a station: wood.wrong_tool (got %s)" % board.last_event)

	# --- the target makes the impact: sword on slime / dummy = flesh.hit; boss = boss_orc.hit
	var sword: WeaponData = load("res://data/weapons/wooden_sword.tres")
	var slime: Enemy = load("res://scenes/enemies/slime.tscn").instantiate()
	slime.data = load("res://data/enemies/slime.tres")
	arena.add_child(slime)
	slime.global_position = player.global_position + Vector2(300, 100)
	await physics_frame
	n = board.play_count
	slime.health.take_damage(5.0, player, true, &"melee", sword)
	_check(board.last_event == &"flesh.hit" and board.play_count == n + 1, "sword on slime: flesh.hit (got %s)" % board.last_event)
	var boss = arena.get_node("Boss")
	boss.health.take_damage(5.0, player, true, &"melee", sword)
	_check(board.last_event == &"boss_orc.hit", "sword on boss: boss_orc.hit (got %s)" % board.last_event)

	# --- arrows keep the bow's own impact
	var bow: WeaponData = load("res://data/weapons/bow.tres")
	dummy.health.take_damage(5.0, player, true, &"arrow", bow)
	_check(board.last_event == &"bow.hit", "arrow: bow.hit (got %s)" % board.last_event)
	dummy.health.take_damage(5.0, player, true, &"charged_arrow", bow)
	_check(board.last_event == &"bow.hit_charged", "charged arrow: bow.hit_charged (got %s)" % board.last_event)
	# no weapon (lunge): falls back to the target
	dummy.health.take_damage(5.0, player, true, &"lunge")
	_check(board.last_event == &"flesh.hit", "lunge (no weapon): target's flesh.hit (got %s)" % board.last_event)

	# --- player, parry, phase, kill, switch
	player.get_node("Health").take_damage(1.0, dummy, false)
	_check(board.last_event == &"player.hit", "player hurt: player.hit (got %s)" % board.last_event)
	fx.fire(&"parry", player, dummy)
	_check(board.last_event == &"player.parry", "parry: player.parry")
	fx.fire(&"block", player, dummy)
	_check(board.last_event == &"player.block", "block: player.block")
	fx.fire(&"phase_change", boss, null)
	_check(board.last_event == &"boss_orc.phase", "phase change: boss_orc.phase")
	fx.fire(&"kill", boss, null)
	_check(board.last_event == &"boss_orc.break", "boss kill: boss_orc.break")
	# F3 button: charged arrow carries the bow, so it is not silent
	n = board.play_count
	fx.test_hit(&"charged_arrow")
	_check(board.play_count == n + 1 and board.last_event == &"bow.hit_charged", "Test charged arrow plays bow.hit_charged (got %s)" % board.last_event)
	# cues are their own files: F3 can write them back
	var cue_ok := true
	for st in SoundSet.all():
		for slot in SoundSet.SLOTS:
			var c := st.get(slot) as SoundCue
			if c != null and not F3Overrides.can_write_to_tres(c):
				cue_ok = false
	_check(cue_ok, "every cue is a .tres file F3 can write to")
	board.voices = 3
	await process_frame
	_check(board.get_child_count() == 3, "voices setter rebuilds the pool")
	board.voices = 8
	# killing sword hit on the boss: one sound, the break
	boss.health.hp = 1.0
	n = board.play_count
	boss.health.take_damage(50.0, player, true, &"melee", sword)
	_check(board.play_count == n + 1 and board.last_event == &"boss_orc.break", "killing hit on boss: exactly one sound, boss_orc.break (%d plays, %s)" % [board.play_count - n, board.last_event])
	var silent := board.silent_count
	board.play(load("res://data/sounds/blade.tres"), &"swing")
	_check(board.silent_count == silent + 1 and board.last_silent == &"blade.swing", "empty slot counts as silent")
	board.enabled = false
	n = board.play_count
	fx.fire(&"sword", dummy, player)
	_check(board.play_count == n, "SoundBoard.enabled off: silence, effects still run")
	board.enabled = true
	board.test_next()
	_check(board.play_count > n, "Test sound plays something")
	quit(0 if _ok else 1)
