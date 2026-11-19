extends SceneTree
## Screenshots of the Test yard item picker (decision 0056), bag open, plus F3 open and the new sword in the hand:
##   godot --resolution 1152x648 --script tools/retired/item_picker_shot.gd -- <out_dir>
var _out := ""

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	ArenaMap.yard_mode = true
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var hud: HUD = arena.get_node("HUD")
	var inv: Inventory = arena.get_node("Player/Inventory")
	await _frames(420)   # let the "F3 overrides applied" toast fade
	hud.bag().toggle()
	await _frames(15)
	var win := hud.craft_window()
	win.select_tab("items")
	await _frames(10)
	win.catalog_slots()[-1].gui_input.emit(_click(MOUSE_BUTTON_RIGHT))
	await _frames(10)
	await _shot("picker_bag")
	arena.get_node("TuningPanel").visible = true
	await _frames(15)
	await _shot("picker_f3")
	arena.get_node("TuningPanel").visible = false
	hud.bag().toggle()
	var s1 := load("res://data/items/sword1.tres") as ItemData
	inv.remove_from_slot(0, 1)
	inv.add(s1, 1)
	arena.get_node("Player/Loadout").rearm()
	await _frames(30)
	arena.get_node("ArenaMap").camera_zoom = 2.0
	arena.get_node("Player/WeaponVisual").set_aim_angle(0.0)
	await _frames(40)
	arena.get_node("Player/WeaponHolder").try_attack()
	await _frames(14)
	await _shot("sword_in_hand")
	quit()

func _click(b: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = b
	ev.pressed = true
	return ev

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
