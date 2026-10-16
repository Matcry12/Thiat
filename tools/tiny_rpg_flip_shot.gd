extends SceneTree
## Orc flipped vs not, 4x, to check the shadow sits under the feet: ... --script tools/tiny_rpg_flip_shot.gd -- <out_dir>
func _init() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	arena.get_node("DebugOverlay").enabled = false
	arena.get_node("Player").set_physics_process(false)
	var cam := Camera2D.new()
	cam.zoom = Vector2.ONE * 4.0
	boss.add_child(cam)
	for i in 10:
		await process_frame
	boss.set_process(false)
	for side in [Vector2.RIGHT, Vector2.LEFT]:
		boss.visual.set_facing(side)
		await create_timer(0.3).timeout
		root.get_texture().get_image().save_png("%s/orc_flip_%s.png" % [out, "right" if side.x > 0 else "left"])
	quit()
