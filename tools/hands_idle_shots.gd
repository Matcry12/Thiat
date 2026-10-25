extends SceneTree
## Bare-hands idle / walk shots at 4x: xvfb-run -a godot --rendering-driver opengl3 \
##   --resolution 1152x648 --script tools/hands_idle_shots.gd -- <out_dir>
## Saves idle_right / idle_left / idle_front / walk_a / walk_b / punch plus contact.png.
var _out := ""
var _shots: Array[Image] = []
var _player: CharacterBody2D

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	_player = arena.get_node("Player")
	arena.get_node("DebugOverlay").enabled = false
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * 4.0
	_player.add_child(cam)
	for _f in 6:
		await process_frame
	var lo: Loadout = _player.get_node("Loadout")
	lo.select(8)     # empty hotbar slot = bare hands
	await _frames(10)
	_player.aim_override = Vector2.RIGHT
	await _frames(40)
	await _shot("idle_right")
	_player.aim_override = Vector2.LEFT
	await _frames(40)
	await _shot("idle_left")
	_player.aim_override = Vector2.DOWN
	await _frames(40)
	await _shot("idle_front")
	_player.aim_override = Vector2.RIGHT
	Input.action_press("move_up")
	await _frames(30)
	await _shot("walk_a")
	await _frames(9)
	await _shot("walk_b")
	Input.action_release("move_up")
	await _frames(60)
	_player.get_node("WeaponHolder").try_attack()
	await _frames(8)
	await _shot("punch")
	var cols := 3
	var w := _shots[0].get_width()
	var h := _shots[0].get_height()
	var sheet := Image.create(cols * w, ceili(float(_shots.size()) / cols) * h, false, Image.FORMAT_RGBA8)
	for i in _shots.size():
		sheet.blit_rect(_shots[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s/contact.png" % _out)
	quit(0)

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name_: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var c := img.get_size() / 2
	var crop := img.get_region(Rect2i(c.x - 150, c.y - 230, 300, 300))
	crop.save_png("%s/%s.png" % [_out, name_])
	_shots.append(crop)
