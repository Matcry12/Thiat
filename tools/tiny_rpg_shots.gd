extends SceneTree
## Temp Tiny RPG art screenshots at the REAL game camera (zoom 1, decision 0032):
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/tiny_rpg_shots.gd -- <out_dir>
## Saves tiny_rpg_player.png (player idle with sword), tiny_rpg_boss.png (orc mid-slam beside the player),
## tiny_rpg_boss_strike.png, tiny_rpg_trees.png (size check beside a tree) and, for the scale comparison,
## scale_A.png .. scale_D.png (full frames; tools/tiny_rpg_compare.py tiles them into tiny_rpg_scale_compare.png).
## Scale options are set at runtime only (nothing is saved): A soldier 2 / orc 4, B both 3, C soldier 2 / orc 2, D both 4.
var _out := ""
var _arena: Node
var _player: CharacterBody2D
var _boss: Boss
var _cam: Camera2D

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	_arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(_arena)
	_boss = _arena.get_node("Boss")
	_arena.get_node("DebugOverlay").enabled = false
	_player = _arena.get_node("Player")
	_player.get_node("Health").immortal = true
	_player.set_physics_process(false)
	_boss.passive = true
	for _f in 12:
		await process_frame
	_cam = _player.get_node("Camera")        # the game's own camera (zoom 1)
	print("camera zoom: ", _cam.zoom)
	_player.aim_override = Vector2.RIGHT
	_cam.reset_smoothing()
	await _frames(20)
	await _shot("tiny_rpg_player")

	_player.global_position = _boss.global_position + Vector2(-130, 30)
	_cam.reset_smoothing()
	_boss.passive = false
	_boss._set_aggro(Boss.Aggro.ENGAGED)
	await _frames(20)
	_boss.force_next("slam")
	var a := _boss.get_attack("slam")
	while a.phase != BossAttack.Phase.TELEGRAPH:
		await physics_frame
	while a.phase_time() < 0.75:
		await physics_frame
	await _shot("tiny_rpg_boss")
	while a.phase != BossAttack.Phase.ACTIVE:
		await physics_frame
	await _shot("tiny_rpg_boss_strike")
	_boss.passive = true
	_player.get_node("Health").hp = _player.get_node("Health").max_hp

	var tree := _tree_near(_boss.home)
	_player.global_position = tree.global_position + Vector2(-50, 12)
	_boss.global_position = tree.global_position + Vector2(-140, 24)
	_player.aim_override = Vector2.RIGHT
	_cam.reset_smoothing()
	await _frames(30)
	await _shot("tiny_rpg_trees")
	var vis: SpriteActorVisual = _player.get_node("Visual")
	var opts := {"A": [2, 4], "B": [3, 3], "C": [2, 2], "D": [4, 4]}
	for k in opts:
		var ps: int = opts[k][0]
		var os: int = opts[k][1]
		vis.rig.body_scale = Vector2(ps, ps)
		vis.rig.body_position = Vector2(0, 3 - 7 * ps)     # feet stay on the shadow
		_boss.visual.body_scale = Vector2(os, os)
		_boss.visual.body_position = Vector2(0, 22 - 7 * os)
		await _frames(15)
		await _shot("scale_" + k)
	quit()

func _tree_near(p: Vector2) -> Node2D:
	return (_arena.get_node("ArenaMap") as ArenaMap).nearest_node(&"tree", p, true)   # world data: the tree's chunk may not be loaded yet

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
