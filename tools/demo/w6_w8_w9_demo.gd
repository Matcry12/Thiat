extends Node
## Demo of W6 (death drops), W8 (title, pause, settings) and W9 (save / continue): `tools/demo/record_w6_w8_w9.sh`.
## A scripted bot: it presses the real input actions and the real menu buttons. It is NOT the current scene (it frees
## that role so the game can change scenes under it) and runs even while the tree is paused.
## Prints "BEAT n <seconds>" lines so frames can be cut at each beat. Needs a real save path: the recorder points
## XDG_DATA_HOME at a temp folder, so the player's own save and settings are never touched.

const SEED := 11
var _caption: Label
var _beats := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 200
	add_child(layer)
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.offset_top = -64
	_caption.offset_left = -400
	_caption.offset_right = 400
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 26)
	_caption.add_theme_color_override("font_outline_color", Color.BLACK)
	_caption.add_theme_constant_override("outline_size", 8)
	layer.add_child(_caption)
	get_tree().current_scene = null   # the game may now change scenes without freeing this node
	_run.call_deferred()

func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout

func _beat(text: String) -> void:
	_beats += 1
	_caption.text = text
	print("BEAT %d %.2f %s" % [_beats, Engine.get_frames_drawn() / 60.0, text])

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
	a.get_node("DebugOverlay").set("enabled", false)   # no hitbox drawings in a demo
	a.get_node("Boss").passive = true
	return a

func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack"]:
		Input.action_release(a)

## Walks the player to within `stop` px of `to` (aim stays on it). Gives up after `limit` s and teleports.
func _walk_to(player: Node2D, to: Vector2, stop: float, limit := 9.0) -> void:
	var t := 0.0
	while player.global_position.distance_to(to) > stop and t < limit:
		var d: Vector2 = to - player.global_position
		player.aim_override = d.normalized()
		for pair in [["move_left", d.x < -stop * 0.4], ["move_right", d.x > stop * 0.4], ["move_up", d.y < -stop * 0.4], ["move_down", d.y > stop * 0.4]]:
			if pair[1]:
				Input.action_press(pair[0])
			else:
				Input.action_release(pair[0])
		await get_tree().process_frame
		t += get_process_delta_time()
	_release_moves()
	if player.global_position.distance_to(to) > stop * 3.0:
		(_arena().get_node("ArenaMap") as ArenaMap).teleport_player(to)

func _run() -> void:
	# ---- 1. title -> Play
	var title = load("res://scenes/title.tscn").instantiate()
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	_beat("Title screen: Play, Continue (grey), Settings, Quit")
	await _wait(2.0)
	title.button("Play").grab_focus()
	await _wait(0.8)
	title.play()
	ArenaMap.retry_seed = SEED   # the demo island (the button picks a random one)
	var arena := await _await_arena()
	var player: CharacterBody2D = arena.get_node("Player")
	var map: ArenaMap = arena.get_node("ArenaMap")
	var inv: Inventory = player.get_node("Inventory")
	var lo: Loadout = player.get_node("Loadout")
	var rs: Respawner = player.get_node("Respawner")
	var home := map.home_point()

	# ---- 2. walk + zoom
	_beat("Walk, then zoom in and out (+ / -)")
	await _wait(0.8)
	player.aim_override = Vector2.RIGHT
	Input.action_press("move_right")
	await _wait(1.0)
	_release_moves()
	for z in [1, 1, -1, -1, -1]:
		_action("zoom_in" if z > 0 else "zoom_out")
		_action("zoom_in" if z > 0 else "zoom_out", false)
		await _wait(0.9)
	_action("zoom_in")
	await _wait(0.6)
	_release_moves()

	# ---- 3. chop a tree with bare hands
	# a lone tree about 550 px from the campfire with a clear walk to it: the death is far from home but in the open
	var near_obs: Array = []
	for o in map.result.obstacles:
		if o["pos"].distance_to(home) < 800.0:
			near_obs.append(o)
	var want := home
	var best_score := INF
	for o in near_obs:
		if o["node"] < 0 or not String(map.style.resource_nodes[o["node"]].id).begins_with("tree"):
			continue
		var d: float = o["pos"].distance_to(home)
		if d < 400.0 or d > 800.0 or not map.rect_on_land(Rect2(o["pos"] - Vector2(20, 20), Vector2(40, 40))):
			continue
		var crowd := 0   # other things within 160 px (the canopy hides the player), and on the walk line
		for q in near_obs:
			if q["pos"] == o["pos"]:
				continue
			if q["pos"].distance_to(o["pos"]) < 160.0:
				crowd += 1
			if Geometry2D.get_closest_point_to_segment(q["pos"], home, o["pos"]).distance_to(q["pos"]) < 40.0:
				crowd += 3
		var score := crowd * 100.0 + absf(d - 550.0)
		if score < best_score:
			best_score = score
			want = o["pos"]
	print("tree at ", want, " from home ", want.distance_to(home), " score ", best_score)
	var tree := map.nearest_node(&"tree", want, true)
	var tpos := tree.global_position
	await _walk_to(player, tpos + Vector2(-46, 20), 12.0)
	lo.select(1)   # an empty hotbar slot = bare hands
	await _wait(0.3)
	_beat("Punch a tree: wood pops out and floats")
	player.aim_override = (tpos - player.global_position).normalized()
	Input.action_press("attack")
	var t := 0.0
	while is_instance_valid(tree) and not tree.is_broken() and t < 14.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	Input.action_release("attack")
	await _wait(2.2)   # the wood floats on the ground, then the magnet takes it

	# ---- 4. die: items spray, land, float; respawn
	inv.give_dev_kit()   # sword, bow, axe, pickaxe in the hotbar
	inv.add(load("res://data/items/stone.tres"), 24)
	inv.add(load("res://data/items/copper_ore.tres"), 12)
	lo.rearm()
	await _wait(0.8)
	player.aim_override = Vector2.RIGHT
	var spot: Vector2 = player.global_position
	_beat("Die: everything sprays out as loose items")
	rs.kill()
	await _wait(2.6)
	_beat("Respawn at home with full health; the pile floats where you died")
	await _wait(2.0)

	# ---- 5. walk back, items fly in
	_beat("Walk back: items fly into you, the sword is back in hand")
	await _walk_to(player, spot + Vector2(0, 30), 12.0, 12.0)
	var left := 0.0
	while get_tree().get_nodes_in_group("pickup").any(func(p): return p.death_drop) and left < 6.0:
		for off in [Vector2(55, 0), Vector2(-55, 0), Vector2(0, -55), Vector2.ZERO]:
			await _walk_to(player, spot + off, 12.0, 2.5)
			await _wait(0.5)
			left += 0.5
		break
	await _wait(1.5)

	# ---- 6. pause menu, settings, resume
	_action("pause")
	await _wait(0.2)
	_beat("Esc: pause menu")
	await _wait(1.8)
	var pm: PauseMenu = arena.get_node("PauseMenu")
	pm.screen().button("Settings").grab_focus()
	await _wait(0.5)
	pm.screen().show_settings()
	_beat("Settings: volume, shake, fullscreen (saved to a file)")
	await _wait(2.4)
	_action("pause")   # back to the list
	await _wait(1.2)
	_action("pause")   # resume
	await _wait(1.2)

	# ---- 7. Save & quit -> title -> Continue
	var here: Vector2 = player.global_position
	_action("pause")
	await _wait(1.0)
	pm.screen().button("Save & quit").grab_focus()
	_beat("Save & quit")
	await _wait(1.0)
	pm.screen().button("Save & quit").pressed.emit()
	while get_tree().current_scene == null or not get_tree().current_scene.has_method("continue_run"):
		await get_tree().process_frame
	var t2 = get_tree().current_scene
	await _wait(0.5)
	_beat("Title again: Continue is lit now")
	t2.button("Continue").grab_focus()
	await _wait(2.4)
	t2.continue_run()
	var arena2 := await _await_arena()
	await _wait(2.5)
	_beat("Continue: same island, same spot (%.0f px off)" % arena2.get_node("Player").global_position.distance_to(here))
	await _wait(3.0)
	print("DONE here=%s now=%s" % [here, arena2.get_node("Player").global_position])
	get_tree().quit()
