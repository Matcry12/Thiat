extends SceneTree
## Pixel Plains player at the real game camera (zoom 1): idle, run x2, dead (lying frame held).
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/pixel_plains_shots.gd -- <out_dir>
var _out := ""
var _arena: Node
var _player: CharacterBody2D
var _cam: Camera2D

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	_arena.get_node("DebugOverlay").enabled = false
	_player = _arena.get_node("Player")
	_player.get_node("Health").immortal = true
	_arena.get_node("Boss").passive = true
	for _f in 12:
		await process_frame
	_cam = _player.get_node("Camera")
	_player.aim_override = Vector2.RIGHT
	_cam.reset_smoothing()
	await _wait(0.5)
	await _shot("idle")
	for i in 2:                                   # run: 2 frames apart
		Input.action_press("move_right")
		await _wait(0.35 if i == 0 else 0.15)
		await _shot("run_%d" % i)
	Input.action_release("move_right")
	await _wait(0.3)
	_player.get_node("Health").immortal = false
	(_player.get_node("Respawner") as Respawner).respawn_delay = 99.0
	(_player.get_node("Respawner") as Respawner).kill()
	await _wait(1.2)                               # death plays 6 frames, holds the last
	await _shot("dead")
	quit()

func _wait(s: float) -> void:
	await create_timer(s).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
