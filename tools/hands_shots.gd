extends SceneTree
## Screenshots of the player's hands at 4x: xvfb-run -a godot --rendering-driver opengl3 \
##   --resolution 1152x648 --script tools/hands_shots.gd -- <out_dir>
## Saves one cropped PNG per pose plus contact.png (all poses on one sheet).
var _out := ""
var _shots: Array[Image] = []
var _names: Array[String] = []
var _player: CharacterBody2D

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	_player = arena.get_node("Player")
	arena.get_node("DebugOverlay").enabled = OS.get_cmdline_user_args().has("--f1")   # F1 off unless asked
	var cam := Camera2D.new()     # our own camera: 4x, centred on the player
	cam.zoom = Vector2.ONE * 4.0
	_player.add_child(cam)

	for _f in 6:
		await process_frame
	var wh: WeaponHolder = _player.get_node("WeaponHolder")
	var gd: Guard = _player.get_node("Guard")
	var lo: Loadout = _player.get_node("Loadout")
	var sk: SkillSlot = _player.get_node("SkillSlot")
	_player.aim_override = Vector2.RIGHT
	await _frames(4)
	await _shot("1_sword_idle")
	wh.try_attack()
	await _until(func(): return wh.phase == WeaponHolder.Phase.WINDUP)
	await _frames(8)
	await _shot("2a_sword_windup")
	await _until(func(): return wh.phase == WeaponHolder.Phase.ACTIVE)
	await _frames(3)
	await _shot("2_sword_midswing")
	await _until(func(): return wh.phase == WeaponHolder.Phase.IDLE)
	gd.try_guard()
	await _frames(20)
	await _shot("3_sword_guard")
	gd.release()
	await _frames(20)
	_player.aim_override = Vector2.LEFT
	await _frames(6)
	await _shot("4_sword_left")
	wh.try_attack()
	await _until(func(): return wh.phase == WeaponHolder.Phase.ACTIVE)
	await _frames(3)
	await _shot("4a_sword_left_swing")
	await _until(func(): return wh.phase == WeaponHolder.Phase.IDLE)
	_player.aim_override = Vector2.RIGHT
	_player.get_node("Dodge").try_dodge(Vector2.RIGHT, Vector2.RIGHT)
	await _frames(4)
	await _shot("4b_dodge")
	await _frames(40)
	lo.select(lo.weapon_slot(1))
	await _frames(10)
	await _shot("5_bow_rest")
	wh.try_attack()
	await _until(func(): return wh.phase == WeaponHolder.Phase.WINDUP)
	await _frames(12)
	await _shot("5a_bow_drawing")
	await _until(func(): return wh.phase == WeaponHolder.Phase.IDLE)
	await _frames(10)
	sk.try_use(lo.active_weapon(), Vector2.RIGHT)
	await _frames(25)
	await _shot("6_bow_charging")
	await _frames(40)
	_player.aim_override = Vector2.LEFT
	await _frames(6)
	await _shot("6a_bow_left")
	_player.aim_override = Vector2.RIGHT
	await _frames(240)
	lo.select(lo.weapon_slot(0))
	await _frames(10)
	sk.try_use(lo.active_weapon(), Vector2.RIGHT)
	await _frames(5)
	await _shot("7_lunge")
	await _frames(40)
	# Contact sheet.
	var cols := 4
	var w := _shots[0].get_width()
	var h := _shots[0].get_height()
	var rows := ceili(float(_shots.size()) / cols)
	var sheet := Image.create(cols * w, rows * h, false, Image.FORMAT_RGBA8)
	for i in _shots.size():
		sheet.blit_rect(_shots[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	sheet.save_png("%s/contact.png" % _out)
	quit(0)

func _frames(n: int) -> void:     # n frames at 60 fps, in real seconds
	await create_timer(n / 60.0).timeout

func _until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < 600:
		await physics_frame
		n += 1
	await process_frame

func _shot(name_: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	var c := img.get_size() / 2
	var crop := img.get_region(Rect2i(c.x - 200, c.y - 160, 400, 320))
	crop.save_png("%s/%s.png" % [_out, name_])
	_shots.append(crop)
