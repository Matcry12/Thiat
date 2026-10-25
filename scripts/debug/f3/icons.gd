class_name F3Icons
## Tiny white icons drawn in code once (reset arrow, copy, star, star outline). Font glyphs like the arrow or the star are not in the
## default font: each Button asked the OS for a fallback font, ~3 ms per button, which made a section of 180 rows open in 2.7 s.
## Tint with `modulate` / `self_modulate`.

const SIZE := 13
static var _cache := {}

static func get_icon(kind: String) -> Texture2D:
	if not _cache.has(kind):
		_cache[kind] = ImageTexture.create_from_image(_draw(kind))
	return _cache[kind]

static func _draw(kind: String) -> Image:
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var c := (SIZE - 1) * 0.5
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y)
			var on := false
			match kind:
				"reset":   # ring open at the top right + an arrow head
					var d := p.distance_to(Vector2(c, c))
					var a := rad_to_deg(atan2(y - c, x - c))
					on = absf(d - 4.6) < 0.75 and not (a > -75.0 and a < -15.0)
					on = on or (x >= 8 and x <= 11 and y == 1 and x - 8 <= 3 - (y - 1) * 0) or (x == 8 and y >= 1 and y <= 4)
				"copy":    # two squares
					var back := x >= 4 and x <= 10 and y >= 1 and y <= 7
					var front := x >= 2 and x <= 8 and y >= 4 and y <= 11
					var edge_b := back and (x == 4 or x == 10 or y == 1 or y == 7)
					var edge_f := front and (x == 2 or x == 8 or y == 4 or y == 11)
					on = (edge_b and not (front and x > 2 and x < 8 and y > 4 and y < 11)) or edge_f
				"star", "star_o":
					var inside := _in_star(p, c)
					if kind == "star":
						on = inside
					else:
						on = inside and not (_in_star(p + Vector2(1, 0), c) and _in_star(p - Vector2(1, 0), c) and _in_star(p + Vector2(0, 1), c) and _in_star(p - Vector2(0, 1), c))
			img.set_pixel(x, y, Color(1, 1, 1, 1) if on else Color(1, 1, 1, 0))
	return img

static func _in_star(p: Vector2, c: float) -> bool:
	var pts := PackedVector2Array()
	for i in 10:
		var r := 6.2 if i % 2 == 0 else 2.7
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(Vector2(c, c + 0.4) + Vector2(cos(a), sin(a)) * r)
	return Geometry2D.is_point_in_polygon(p, pts)
