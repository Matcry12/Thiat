extends SceneTree
## Proof for the two hands (0065): row 1 = weapon hidden: idle frames, run frames, facing left. Then every weapon at rest (rows 2-3) and mid swing (rows 4-5). No F1, 2x crop.
## timeout 90 godot --rendering-driver opengl3 --resolution 1152x648 --script tools/hand_proof_shot.gd -- <out.png>
const IDS := ["wooden_sword", "sword1", "copper_sword", "katana", "glide", "bow", "stone_axe", "copper_axe", "axe", "stone_pickaxe", "copper_pickaxe", "hoe"]
const PANEL := Vector2i(150, 130)
const ZOOM := 2
const COLS := 6

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(sheet: Image, player: Node2D, slot: int) -> void:
	var c := Vector2i(player.get_global_transform_with_canvas().origin)
	var crop := root.get_texture().get_image().get_region(Rect2i(c - Vector2i(60, 95), PANEL))
	crop.resize(PANEL.x * ZOOM, PANEL.y * ZOOM, Image.INTERPOLATE_NEAREST)
	var cell := PANEL * ZOOM + Vector2i(4, 4)
	sheet.blit_rect(crop, Rect2i(Vector2i.ZERO, PANEL * ZOOM), Vector2i(slot % COLS, slot / COLS) * cell)

func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await _frames(10)
	for n in arena.find_children("*", "", true, false):
		if n.get_script() == preload("res://scripts/debug_overlay.gd"):
			n.enabled = false
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var cell := PANEL * ZOOM + Vector2i(4, 4)
	var sheet := Image.create(cell.x * COLS, cell.y * 5, false, Image.FORMAT_RGBA8)
	wv.visible = false
	var body: AnimatedSprite2D = player.get_node("Visual/Body")
	await _frames(4)
	for s in 6:
		body.play(&"idle" if s < 2 else &"run")
		body.pause()
		body.frame = s if s < 2 else s - 2
		player.get_node("Visual").set_facing(Vector2.LEFT if s == 5 else Vector2.RIGHT)
		await _frames(3)
		body.pause()
		_shot(sheet, player, s)
	body.play(&"idle")
	player.get_node("Visual").set_facing(Vector2.RIGHT)
	for i in IDS.size():
		var w: WeaponData = load("res://data/weapons/%s.tres" % IDS[i])
		player._on_swap_finished(w)
		wv.visible = true
		wv.set_aim_angle(0.0)
		await _frames(8)
		_shot(sheet, player, COLS + i)
		wv.on_weapon_state("windup")
		await _frames(int(w.windup * 60.0) + 1)
		wv.on_weapon_state("active")
		await _frames(int(w.active * 30.0))
		_shot(sheet, player, COLS + i + IDS.size())
		wv.on_weapon_state("idle")
		await _frames(4)
	sheet.save_png(OS.get_cmdline_user_args()[0])
	quit()
