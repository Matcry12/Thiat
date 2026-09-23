extends Node2D
## Primitive-art visual, 2.5D top-down (Soul Knight style): the world is seen from
## above, but BODIES STAY UPRIGHT and face the camera — they never rotate with aim.
## Only the aim indicator rotates. A ground shadow sells the height.
##
## Everything drawn here is placeholder. This node is the single swap point for a
## sprite later; no combat script may reach inside it (see decision 0005).

@export var radius := 16.0
@export var height := 34.0              ## upright body height (2.5D)
@export var base_color := Color.WHITE
@export var draw_shadow := true
@export var draw_aim_indicator := false
@export var aim_indicator_length := 40.0

var aim_angle := 0.0                     ## set by the owner; only the indicator uses it
var _tint := Color.WHITE

func set_weapon_state(state: String) -> void:
	match state:
		"windup": _tint = Color.YELLOW
		"active": _tint = Color.RED
		"recovery": _tint = Color.GRAY
		_: _tint = Color.WHITE
	queue_redraw()

func set_aim_angle(angle: float) -> void:
	if not is_equal_approx(angle, aim_angle):
		aim_angle = angle
		queue_redraw()

func _draw() -> void:
	# Ground shadow: an ellipse at the feet is what reads as "standing up" in 2.5D.
	if draw_shadow:
		draw_set_transform(Vector2(0, radius * 0.6), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Upright capsule body: never rotated by aim.
	var color := base_color * _tint
	var half := (height - radius * 2.0) * 0.5
	draw_circle(Vector2(0, -half), radius, color)
	draw_circle(Vector2(0, half), radius, color)
	draw_rect(Rect2(-radius, -half, radius * 2.0, half * 2.0), color)

	# Aim indicator: the ONLY thing that follows the cursor.
	if draw_aim_indicator:
		var from := Vector2(0, -half * 0.3)
		draw_line(from, from + Vector2.RIGHT.rotated(aim_angle) * aim_indicator_length, Color.WHITE, 2.0)
