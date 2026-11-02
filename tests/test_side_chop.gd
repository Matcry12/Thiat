extends SceneTree
# Side chop (SwingMotion.side_only): picture AND hit path aim only right / left (+ optional tilt); off = unchanged.
var _fail := 0

func _check(ok: bool, what: String) -> void:
	print("%s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fail += 1

func _poses_str(hb: Hitbox) -> String:
	for c in hb.get_children():   # shapes are off while idle; the sweep reads them anyway
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.disabled = false
	var ps := hb.motion_poses(0.0, 1.0, 12)
	assert(ps.size() > 0)
	return str(ps.map(func(p): return p[1]))

func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var player = arena.get_node("Player")
	player.set_physics_process(false)
	var wv: WeaponVisual = player.get_node("WeaponVisual")
	var hb: Hitbox = player.get_node("WeaponHolder").hitbox
	for i in 3:
		await physics_frame
	hb.weapon = wv.weapon   # normally set on attack
	var m: SwingMotion = wv.weapon.swing_motion
	_check(not m.side_only, "side_only defaults to off")
	wv.set_aim_angle(-PI / 2)
	_check(is_equal_approx(wv.rotation, -PI / 2), "off: aim up turns the hand node up")
	var off_up := _poses_str(hb)
	wv.set_aim_angle(-1.0)
	_check(is_equal_approx(wv.rotation, -1.0) and wv.status_text().find("side:") < 0, "off: any aim followed, no side in status")

	m.side_only = true
	m.side_tilt_max_deg = 0.0
	wv.set_aim_angle(0.0)
	var right := _poses_str(hb)
	wv.set_aim_angle(-PI / 2 + 0.3)   # up, slightly right
	_check(is_zero_approx(wv.rotation) and wv.scale.y == 1.0, "flat: aim up-right snaps to right")
	_check(_poses_str(hb) == right, "flat: hit path at aim up == hit path at aim right (picture and hit share the node)")
	_check(_poses_str(hb) != off_up, "side_only changes the hit path vs the old aim-up one")
	wv.set_aim_angle(PI / 2 + 0.3)   # down, slightly left
	_check(absf(absf(wv.rotation) - PI) < 0.001 and wv.scale.y == -1.0, "flat: aim down-left snaps to left (mirrored)")
	wv.set_aim_angle(-PI / 2)   # straight up: keeps the last side (left)
	_check(absf(absf(wv.rotation) - PI) < 0.001, "deadzone: straight up keeps the last side")
	_check(wv.status_text().contains("side: left"), "status shows side (%s)" % wv.status_text())
	# side never flips mid-swing
	wv.on_weapon_state("windup")
	wv.set_aim_angle(0.0)
	_check(absf(absf(wv.rotation) - PI) < 0.001, "locked: side does not flip mid-swing")
	wv.on_weapon_state("idle")
	wv.set_aim_angle(0.0)
	_check(is_zero_approx(wv.rotation), "after the swing the side follows again")

	m.side_tilt_max_deg = 35.0
	wv.set_aim_angle(deg_to_rad(-70.0))
	_check(absf(rad_to_deg(wv.rotation) + 35.0) < 0.01, "tilt: aim 70 up leans 35 (max), got %.1f" % rad_to_deg(wv.rotation))
	wv.set_aim_angle(deg_to_rad(20.0))
	_check(absf(rad_to_deg(wv.rotation) - 20.0) < 0.01, "tilt: aim 20 down is followed fully")
	wv.set_aim_angle(deg_to_rad(180.0 - 50.0))   # down-left 50 below horizontal
	_check(absf(rad_to_deg(wv.rotation) - 145.0) < 0.01, "tilt: left side leans toward the aim (145 deg)")
	_check(wv.status_text().contains("tilt"), "status shows tilt")
	print("side chop: %d failures" % _fail)
	quit(1 if _fail > 0 else 0)
