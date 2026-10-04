extends SceneTree
## Full-screen HUD screenshots of the real arena:
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/hud_shots.gd -- <out_dir>
## Saves hud_top_right.png (normal), hud_swap.png (cast + cooldown), hud_f3.png (F3 open).
var _out := ""

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	arena.get_node("DebugOverlay").enabled = false
	var player = arena.get_node("Player")
	var hp: Health = player.get_node("Health")
	var lo: Loadout = player.get_node("Loadout")
	hp.immortal = true
	await _frames(10)
	hp.hp = hp.max_hp * 0.8
	await _frames(20)
	await _shot("hud_top_right")
	hp.hp = hp.max_hp * 0.2
	lo.try_swap(1)
	await _frames(20)
	await _shot("hud_swap_cast")
	while lo.is_casting():
		await physics_frame
	await _frames(40)
	await _shot("hud_swap_cooldown")
	arena.get_node("TuningPanel").visible = true
	await _frames(10)
	await _shot("hud_f3")
	quit()

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
