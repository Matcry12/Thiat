extends SceneTree
# Headless check of the arc filter: the geometry that decides every melee hit.
func _init():
	var half := deg_to_rad(90.0 / 2.0)
	var aim := Vector2.RIGHT
	var cases := {
		"in front (0deg)": [Vector2(50, 0), true],
		"edge (44deg)": [Vector2(50, 0).rotated(deg_to_rad(44)), true],
		"just outside (46deg)": [Vector2(50, 0).rotated(deg_to_rad(46)), false],
		"below (-44deg)": [Vector2(50, 0).rotated(deg_to_rad(-44)), true],
		"just outside below (-46deg)": [Vector2(50, 0).rotated(deg_to_rad(-46)), false],
		"BEHIND (180deg)": [Vector2(-50, 0), false],
		"behind-ish (-170deg)": [Vector2(50, 0).rotated(deg_to_rad(-170)), false],
	}
	var failed := 0
	for name in cases:
		var to_target: Vector2 = cases[name][0]
		var expected: bool = cases[name][1]
		var hit: bool = absf(aim.angle_to(to_target)) <= half and to_target.length() <= 76.0
		var ok := hit == expected
		if not ok: failed += 1
		print("%s %-28s hit=%s expected=%s" % ["PASS" if ok else "FAIL", name, hit, expected])
	print("--- %d failed" % failed)
	quit(1 if failed else 0)
