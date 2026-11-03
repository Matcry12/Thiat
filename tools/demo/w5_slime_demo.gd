extends Node
## Demo of W5 (slimes): `tools/demo/record_w5.sh`. A bot presses the real input actions; the slime brain is real.
## Spawns its own slimes (data.scene.instantiate), so it works with or without the EnemySpawner. Prints "BEAT n <s>".

const SEED := 11
const SLIME := "res://data/enemies/slime.tres"
var _caption: Label
var _beats := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_caption.offset_top = 14
	_caption.offset_left = -400
	_caption.offset_right = 400
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	get_tree().current_scene = null
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _beat(text: String) -> void:
	_beats += 1
	_caption.text = text
	print("BEAT %d %.2f %s" % [_beats, Engine.get_process_frames() / 60.0, text])

func _action(name: String, pressed := true) -> void:
	var ev := InputEventAction.new()
	ev.action = name
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _arena() -> Node:
	var s := get_tree().current_scene
	return s if s != null and s.has_node("Player") else null

func _await_arena() -> Node:
	while _arena() == null or not _arena().get_node("ArenaMap").result:
		await get_tree().process_frame
	await _wait(0.6)
	var a := _arena()
	a.get_node("DebugOverlay").set("enabled", false)   # F1 comes back in beat 5
	a.get_node("Boss").passive = true
	return a

func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack"]:
		Input.action_release(a)

func _hold_vec(v: Vector2) -> void:
	for pair in [["move_left", v.x < -0.3], ["move_right", v.x > 0.3], ["move_up", v.y < -0.3], ["move_down", v.y > 0.3]]:
		if pair[1]:
			Input.action_press(pair[0])
		else:
			Input.action_release(pair[0])

func _walk_to(player: Node2D, to: Vector2, stop: float, limit := 9.0) -> void:
	var t := 0.0
	while player.global_position.distance_to(to) > stop and t < limit:
		var d: Vector2 = to - player.global_position
		player.aim_override = d.normalized()
		_hold_vec(d.normalized() if d.length() > stop else Vector2.ZERO)
		await get_tree().process_frame
		t += get_process_delta_time()
	_release_moves()
	if player.global_position.distance_to(to) > stop * 3.0:
		(_arena().get_node("ArenaMap") as ArenaMap).teleport_player(to)

func _alive(slimes: Array) -> Array:
	return slimes.filter(func(s): return is_instance_valid(s) and s.state != Enemy.State.DIE)

func _nearest(slimes: Array, p: Vector2) -> Enemy:
	var best: Enemy = null
	for s in _alive(slimes):
		if best == null or s.global_position.distance_to(p) < best.global_position.distance_to(p):
			best = s
	return best

func _heal(player: Node) -> void:
	if player.health.hp < 45.0:
		player.health.hp = player.health.max_hp

## Waits until `slime` is in `st` (or timeout). True = reached.
func _until_state(slime: Enemy, st: int, limit := 8.0) -> bool:
	var t := 0.0
	while is_instance_valid(slime) and slime.state != st and t < limit:
		await get_tree().process_frame
		t += get_process_delta_time()
	return is_instance_valid(slime) and slime.state == st

## F2-style slow motion (0.25x) over one windup + hop. The timers ignore time scale, so `real` is video seconds.
func _slowmo(s: Enemy, real := 3.4) -> void:
	_beat("Slow motion: windup -> hop")
	Engine.time_scale = 0.25
	await _wait(real)
	Engine.time_scale = 1.0

func _run() -> void:
	var title = load("res://scenes/title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	ArenaMap.retry_seed = SEED
	title.play()
	var arena := await _await_arena()
	var player: CharacterBody2D = arena.get_node("Player")
	var map: ArenaMap = arena.get_node("ArenaMap")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var home := map.home_point()
	var data: EnemyData = load(SLIME)

	# a clear land spot ~450 px from home (the pack's own home)
	var spot := home
	var found := false
	for r in [650.0, 550.0, 450.0, 380.0]:
		for i in 16:
			var p: Vector2 = home + Vector2.from_angle(i * TAU / 16.0 + 0.4) * r
			if map.rect_on_land(Rect2(p - Vector2(160, 160), Vector2(320, 320))):
				spot = p
				found = true
				break
		if found:
			break
	print("slime spot ", spot, " from home ", spot.distance_to(home))
	lo.select(0)   # wooden sword
	player.health.hp = player.health.max_hp
	_beat("Walk out into the forest")
	var start := spot + (home - spot).normalized() * 330.0
	await _walk_to(player, start, 14.0, 14.0)

	seed(SEED)
	var slimes: Array = []
	if true:   # always our own pack, in a fixed place
		for off in [Vector2(0, 0), Vector2(60, 25), Vector2(-45, 50)]:
			var e: Enemy = data.scene.instantiate()
			e.data = data
			arena.add_child(e)
			e.global_position = spot + off
			slimes.append(e)
	_beat("A pack of slimes wanders near its spot")
	await _wait(2.5)

	# ---- 2. hit by one hop, dodge another
	_beat("Step closer: a slime squashes (telegraph) and hops")
	var lead := _nearest(slimes, player.global_position)
	await _walk_to(player, lead.global_position + (player.global_position - lead.global_position).normalized() * 200.0, 20.0, 8.0)
	_release_moves()
	var hp0: float = player.health.hp
	var t := 0.0
	var hit := false
	var slowed := false
	while t < 12.0 and not hit:   # stand still: some slime hops, the hit lands
		var pl := _nearest(slimes, player.global_position)
		player.aim_override = (pl.global_position - player.global_position).normalized()
		var winding := _alive(slimes).any(func(x): return x.state == Enemy.State.WINDUP)
		if not slowed and winding:
			slowed = true
			_release_moves()
			await _slowmo(pl)
		if winding:
			_release_moves()   # stand still through the whole telegraph
		elif pl.target_distance() > (120.0 if t < 5.0 else 50.0):   # after 5 s of nothing, close in
			_hold_vec((pl.global_position - player.global_position).normalized())
		else:
			_release_moves()
		await get_tree().process_frame
		t += get_process_delta_time()
		hit = player.health.hp < hp0
	_release_moves()
	_beat("Hit: the hop hurts (%.0f -> %.0f HP)" % [hp0, player.health.hp])
	await _wait(1.8)
	_heal(player)
	player.health.hp = maxf(player.health.hp, 60.0)
	_beat("Next hop: dodge it (watch the windup, then roll)")
	t = 0.0
	var dodged := false
	while t < 14.0 and not dodged:
		var who := _nearest(slimes, player.global_position)
		if who == null:
			break
		if who.state == Enemy.State.IDLE and who.target_distance() > 120.0 and not _alive(slimes).any(func(x): return x.state == Enemy.State.WINDUP):
			_hold_vec((who.global_position - player.global_position).normalized())
		else:
			_release_moves()
		player.aim_override = (who.global_position - player.global_position).normalized()
		for s in _alive(slimes):
			if s.state == Enemy.State.WINDUP and s.target_distance() < 170.0:
				await _wait(maxf(s.data.hop_windup - 0.3, 0.0))   # roll just before the hop leaves the ground
				var side := Vector2(-s.lane_dir.y, s.lane_dir.x)
				_hold_vec(side)
				_action("dodge")
				_action("dodge", false)
				var hp1: float = player.health.hp
				await _wait(s.data.hop_time + 0.5)
				_release_moves()
				dodged = player.health.hp >= hp1
				break
		await get_tree().process_frame
		t += get_process_delta_time()
	print("dodge: avoided=%s" % dodged)
	await _wait(1.2)

	# ---- 3. kill two, leave the last one
	_beat("Wooden sword: hit flash, knockback, numbers; gel pops out")
	player.health.hp = player.health.max_hp
	for i in 2:   # camera close to the hits
		_action("zoom_in")
		_action("zoom_in", false)
		await _wait(0.4)
	t = 0.0
	while _alive(slimes).size() > 1 and t < 40.0:
		var tg := _nearest(slimes, player.global_position)
		var d := tg.global_position - player.global_position
		player.aim_override = d.normalized()
		if d.length() > 38.0:
			_hold_vec(d.normalized())
		else:
			_release_moves()
			_action("attack")
			_action("attack", false)
			await _wait(0.95)   # the swing, then 0.5 s so the numbers can be read
		_heal(player)
		await get_tree().process_frame
		t += get_process_delta_time()
	_release_moves()
	await _wait(2.2)   # gel flies into the bag
	for i in 2:
		_action("zoom_out")
		_action("zoom_out", false)
		await _wait(0.4)

	# ---- 4. bag
	_beat("Tab: the gel stacks in the bag (%d gel)" % inv.count(&"gel"))
	_action("bag")
	_action("bag", false)
	await _wait(4.0)
	_action("bag")
	_action("bag", false)
	await _wait(0.8)

	# ---- 5. F1
	arena.get_node("DebugOverlay").set("enabled", true)
	_beat("F1: aggro circle, leash circle, hop lane")
	var last := _nearest(slimes, player.global_position)
	t = 0.0
	while is_instance_valid(last) and last.target_distance() > 150.0 and t < 8.0:
		_hold_vec((last.global_position - player.global_position).normalized())
		player.aim_override = (last.global_position - player.global_position).normalized()
		await get_tree().process_frame
		t += get_process_delta_time()
	_release_moves()
	player.health.hp = player.health.max_hp
	await _wait(5.0)

	# ---- 6. leash
	_beat("Walk away past the leash: the slime gives up and goes home")
	t = 0.0
	if is_instance_valid(last):
		while t < 12.0 and is_instance_valid(last) and not last.returning:
			var away := (last.global_position - last.home)
			away = away.normalized() if away.length() > 1.0 else (player.global_position - last.home).normalized()
			player.aim_override = away
			_heal(player)
			if last.target_distance() < 135.0 and last.state != Enemy.State.WINDUP:
				_hold_vec(away)    # lead it outward; it follows by hopping
			else:
				_release_moves()   # let it catch up
			await get_tree().process_frame
			t += get_process_delta_time()
		_release_moves()
		if is_instance_valid(last) and not last.returning:   # lure failed (wall / water): shove it past the leash so the video still shows the give-up
			last.global_position = last.home + (player.global_position - last.home).normalized() * (last.data.leash_radius + 15.0)
		print("leash: returning=%s after %.1fs" % [last.returning, t])
		_beat("It turns back and heals on arrival")
		_walk_to(player, player.global_position + (player.global_position - last.home).normalized() * 200.0, 20.0, 3.0)
		await _wait(9.0)
	_release_moves()
	await _wait(1.0)
	arena.get_node("DebugOverlay").set("enabled", false)
	print("DONE gel=%d alive=%d" % [inv.count(&"gel"), _alive(slimes).size()])
	get_tree().quit()
