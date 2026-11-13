extends Control
class_name DayDial
## Small time-of-day dial in the HUD: a round face tinted like the sky, with a sun (day) or moon (night) riding round it
## (midnight at the bottom, noon at the top). No words; the hover tooltip gives day + clock (`tip_text`). Reads the DayClock by
## polling; the clock knows nothing of this node, so a sprite dial can replace it (CLAUDE.md 5).

@export_range(16.0, 128.0, 1.0) var dial_size := 40.0
@export_range(2.0, 20.0, 0.5) var body_radius := 5.0   ## sun / moon disc
@export var face_ink := Color(0.24, 0.14, 0.15)         ## OUT: outline, never pure black (DESIGN.md)
@export var sun_color := Color(0.96, 0.78, 0.30)
@export var moon_color := Color(0.88, 0.92, 1.0)

var _clock: DayClock

func bind(c: DayClock) -> void:
	_clock = c

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # a VBox would stretch it wide
	custom_minimum_size = Vector2.ONE * dial_size
	size = custom_minimum_size

func _process(_delta: float) -> void:
	queue_redraw()

## "Day 3  07:12".
func tip_text() -> String:
	return "Day %d  %s" % [_clock.day_count, _clock.clock_text()] if _clock else ""

func _draw() -> void:
	if _clock == null:
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	draw_circle(c, r, face_ink)
	draw_circle(c, r - 2.0, _clock.tint_color().lerp(Color(0.5, 0.55, 0.7), 0.35))
	var a := _clock.time * TAU
	var p := c + Vector2(-sin(a), cos(a)) * (r - body_radius - 3.0)
	var night := _clock.is_night()
	draw_circle(p, body_radius + 1.0, face_ink)
	draw_circle(p, body_radius, moon_color if night else sun_color)
