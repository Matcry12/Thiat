extends SceneTree
# Every swing-effect style shows effect nodes during ACTIVE and leaves none
# behind shortly after RECOVERY; "none" shows nothing; the slash follows the
# swing when aiming left (its fat end sits where the blade FINISHES).
var _holder: WeaponHolder
var _fx: SwingFx

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)          # headless mouse sits at (0,0)
	_holder = player.get_node("WeaponHolder")
	_fx = player.get_node("WeaponVisual/SwingFx")
	var wv = player.get_node("WeaponVisual")
	var ok := true

	for style in ["none", "slash", "trail", "afterimage", "particles"]:
		_fx.style = style
		wv.set_aim_angle(0.0)
		_holder.try_attack()
		await _until_phase(WeaponHolder.Phase.ACTIVE)
		await _frames(3)
		var during := _fx.get_child_count()
		await _until_phase(WeaponHolder.Phase.IDLE)
		await _frames(15)                       # 0.25 s of grace after recovery
		var after := _fx.get_child_count()
		var good: bool = (during == 0 and after == 0) if style == "none" else (during > 0 and after == 0)
		print("%-10s nodes during active: %d, after recovery: %d  %s" % [style, during, after, good])
		ok = ok and good

	# Aim left: the crescent's fat point must be on the side the blade ends on.
	_fx.style = "slash"
	for angle in [0.0, PI]:
		wv.set_aim_angle(angle)
		await _frames(2)
		_holder.try_attack()
		await _until_phase(WeaponHolder.Phase.ACTIVE)
		await _frames(1)
		var tip: Node2D = wv.get_model().get_node("Tip")
		var start_tip := tip.global_position
		var slash_xf: Transform2D = _fx.get_node("Slash").global_transform   # it fades before the swing ends
		var end_tip := start_tip
		while _holder.phase == WeaponHolder.Phase.ACTIVE:
			end_tip = tip.global_position
			await physics_frame
		var half := deg_to_rad(_holder.weapon.arc_degrees) * 0.5
		var fat: Vector2 = slash_xf * (Vector2.RIGHT.rotated(lerpf(-half, half, _fx.slash_peak)) * 60.0)
		var follows: bool = fat.distance_to(end_tip) < fat.distance_to(start_tip)
		print("aim %.0f deg: fat end nearer the blade's finish: %s" % [rad_to_deg(angle), follows])
		ok = ok and follows
		await _until_phase(WeaponHolder.Phase.IDLE)
		await _frames(15)

	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)

func _until_phase(p: int) -> void:
	var guard := 0
	while _holder.phase != p and guard < 300:
		await physics_frame
		guard += 1

func _frames(n: int) -> void:
	for i in n:
		await physics_frame
