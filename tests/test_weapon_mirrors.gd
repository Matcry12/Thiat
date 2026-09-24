extends SceneTree
# Aiming left must MIRROR the weapon (Soul Knight style), never show it upside down,
# and the hitbox must mirror with it so art and hit area stay in agreement.
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)          # headless mouse sits at (0,0)
	var wv = arena.get_node("Player/WeaponVisual")
	var hitbox = arena.get_node("Player/WeaponVisual/Blade/Hitbox")

	wv.set_aim_angle(0.0)                      # aiming right
	await physics_frame
	var right_scale: float = wv.scale.y
	var right_hit: Vector2 = hitbox.global_position

	wv.set_aim_angle(PI)                       # aiming left
	await physics_frame
	var left_scale: float = wv.scale.y
	var left_hit: Vector2 = hitbox.global_position

	var mirrored := right_scale > 0.0 and left_scale < 0.0
	var hitbox_followed := not right_hit.is_equal_approx(left_hit)
	print("aim right scale.y=%.0f  aim left scale.y=%.0f  mirrored=%s" % [right_scale, left_scale, mirrored])
	print("hitbox moved with it: %s  (%s -> %s)" % [hitbox_followed, right_hit, left_hit])
	var ok := mirrored and hitbox_followed
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
