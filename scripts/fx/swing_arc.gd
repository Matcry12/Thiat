extends Node2D
class_name SwingArc
## The visible sword swing: a wedge that sweeps through the weapon's arc, then fades.
##
## Placeholder ONLY. This node exists so the swing has a *slot* in the scene tree:
## replace it with an AnimatedSprite2D (or a shader quad, or a trail) and nothing else
## changes — it is driven entirely by `on_weapon_state()` + the WeaponData numbers,
## never by hardcoded timings. See decision 0005.

@export var weapon: WeaponData
@export var color := Color(1, 1, 1, 0.85)
@export var fade_time := 0.12          ## how long the wedge lingers after the active frame
@export var sweep := true              ## sweep the leading edge through the arc, vs pop the whole wedge
@export var thickness := 3.0
@export var telegraph_alpha := 0.18    ## faint wedge shown during windup so the reach is readable

var aim_angle := 0.0

var _phase := "idle"
var _t := 0.0                          ## 0..1 through the current phase
var _fade := 0.0

func set_aim_angle(angle: float) -> void:
	aim_angle = angle

func on_weapon_state(state: String) -> void:
	_phase = state
	_t = 0.0
	if state == "recovery":
		_fade = fade_time
	queue_redraw()

func _process(delta: float) -> void:
	if weapon == null:
		return
	var duration := 0.0
	match _phase:
		"windup": duration = weapon.windup
		"active": duration = weapon.active
		_: duration = 0.0
	if duration > 0.0:
		_t = minf(1.0, _t + delta / duration)
	if _fade > 0.0:
		_fade = maxf(0.0, _fade - delta)
	if _phase != "idle" or _fade > 0.0:
		queue_redraw()

func _draw() -> void:
	if weapon == null:
		return
	var half := deg_to_rad(weapon.arc_degrees * 0.5)
	var r: float = weapon.reach

	match _phase:
		"windup":
			# Faint full wedge: tells the player where the swing will land.
			_draw_wedge(aim_angle - half, aim_angle + half, r, Color(color, telegraph_alpha))
		"active":
			# Leading edge sweeps across the arc so the swing reads as motion, not a flash.
			var to_angle: float = aim_angle - half + (2.0 * half * (_t if sweep else 1.0))
			_draw_wedge(aim_angle - half, to_angle, r, color)
		_:
			if _fade > 0.0:
				var a: float = color.a * (_fade / fade_time)
				_draw_wedge(aim_angle - half, aim_angle + half, r, Color(color, a))

func _draw_wedge(from_angle: float, to_angle: float, r: float, c: Color) -> void:
	if absf(to_angle - from_angle) < 0.001:
		return
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	for i in steps + 1:
		points.append(Vector2.RIGHT.rotated(lerpf(from_angle, to_angle, float(i) / steps)) * r)
	draw_colored_polygon(points, Color(c, c.a * 0.35))
	draw_arc(Vector2.ZERO, r, from_angle, to_angle, 24, c, thickness)
	draw_line(Vector2.ZERO, Vector2.RIGHT.rotated(to_angle) * r, c, thickness)
