extends SceneTree
# Headless: proves SectorShape (scripts/components/sector_shape.gd) generates
# a correct pie-slice polygon from arc_degrees + radius (decision 0011
# amendment), with no weapon attached (weapon == null uses the exported
# numbers directly).
func _init():
	var sector := SectorShape.new()
	sector.weapon = null
	sector.arc_degrees = 90.0
	sector.radius = 50.0
	sector.segments = 16
	sector._rebuild()

	var poly := sector.polygon
	var expected_points := sector.segments + 2  # origin + (segments+1) outer-arc points, no inner hole
	var count_ok: bool = poly.size() == expected_points
	print("point count: ", poly.size(), " expected: ", expected_points, " ok: ", count_ok)

	var ahead_in := Vector2(sector.radius * 0.9, 0.0)
	var ahead_out := Vector2(sector.radius * 1.5, 0.0)
	var behind := Vector2(-sector.radius * 0.9, 0.0)

	var inside_near: bool = Geometry2D.is_point_in_polygon(ahead_in, poly)
	var outside_far: bool = not Geometry2D.is_point_in_polygon(ahead_out, poly)
	var outside_behind: bool = not Geometry2D.is_point_in_polygon(behind, poly)

	print("point at radius*0.9 ahead is inside: ", inside_near)
	print("point at radius*1.5 ahead is outside: ", outside_far)
	print("point behind the weapon is outside: ", outside_behind)

	sector.free()

	var ok: bool = count_ok and inside_near and outside_far and outside_behind
	print("PASS" if ok else "FAIL")
	quit(0 if ok else 1)
