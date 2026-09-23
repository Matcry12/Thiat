extends SceneTree
# Headless: proves the swap promise (decision 0010) — the player's Visual is an
# ActorVisual and implements all four contract methods.
func _init():
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	var visual = player.get_node("Visual")

	var is_actor_visual: bool = visual is ActorVisual
	var methods := ["set_move_state", "set_facing", "set_weapon_state", "set_aim_angle"]
	var missing: Array[String] = []
	for m in methods:
		if not visual.has_method(m):
			missing.append(m)

	print("visual is ActorVisual: ", is_actor_visual)
	print("missing methods: ", missing)
	var ok: bool = is_actor_visual and missing.is_empty()
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
