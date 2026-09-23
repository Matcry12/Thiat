extends Node2D
class_name WeaponVisual
## The weapon sprite on a rotating pivot (decision 0010). Replaces the drawn
## wedge that used to live in scripts/fx/swing_arc.gd (deleted).
##
## The whole node rotates to the aim angle; `Blade` sits at `hand_distance`
## along +X (weapon sprites point +X at rotation 0, pivot at the LEFT edge —
## the hand). All timing comes from `weapon` (a WeaponData resource), never
## a hardcoded second.

@export var weapon: WeaponData
@export var blade_texture: Texture2D
@export var blade_offset := Vector2.ZERO
@export var hand_distance := 14.0          ## distance from body centre to the hand
@export var rest_angle_degrees := -20.0    ## idle hold angle, relative to aim
@export var windup_angle_degrees := 60.0   ## how far back the blade winds up, relative to aim
@export var show_reach_telegraph := true   ## faint wedge during windup, reused from the old swing_arc draw code
@export var telegraph_color := Color(1, 1, 1, 0.18)
@export var ground_squash := 0.45          ## flatten floor shapes so they read as lying down (2.5D)

@onready var blade: Sprite2D = $Blade

var aim_angle := 0.0

var _phase := "idle"
var _t := 0.0
var _blade_angle := 0.0          ## Blade.rotation, relative to this node (i.e. relative to aim)
var _phase_start_angle := 0.0
var _phase_target_angle := 0.0

func _ready() -> void:
	if blade_texture:
		blade.texture = blade_texture
	blade.position = Vector2(hand_distance, 0) + blade_offset
	_blade_angle = deg_to_rad(rest_angle_degrees)
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	blade.rotation = _blade_angle

func set_aim_angle(angle: float) -> void:
	aim_angle = angle
	rotation = angle

func on_weapon_state(state: String) -> void:
	_phase = state
	_t = 0.0
	_phase_start_angle = _blade_angle
	match state:
		"windup":
			_phase_target_angle = -deg_to_rad(windup_angle_degrees)
		"active":
			var arc: float = deg_to_rad(weapon.arc_degrees) if weapon else 0.0
			_phase_target_angle = _phase_start_angle + arc
		_:
			_phase_target_angle = deg_to_rad(rest_angle_degrees)
	queue_redraw()

func _process(delta: float) -> void:
	var duration := 0.0
	if weapon != null:
		match _phase:
			"windup": duration = weapon.windup
			"active": duration = weapon.active
			"recovery": duration = weapon.recovery
	_t = 1.0 if duration <= 0.0 else minf(1.0, _t + delta / duration)
	_blade_angle = lerpf(_phase_start_angle, _phase_target_angle, _t)
	blade.rotation = _blade_angle
	if show_reach_telegraph and _phase == "windup":
		queue_redraw()

func _draw() -> void:
	# Faint wedge telling the player where the swing will land. Adapted from
	# the old swing_arc.gd `_draw_wedge` — drawn here in this node's local
	# space, which is already rotated to aim_angle by set_aim_angle().
	if not show_reach_telegraph or weapon == null or _phase != "windup":
		return
	var half := deg_to_rad(weapon.arc_degrees * 0.5)
	var r: float = weapon.reach
	# Squashed: the reach lies on the floor, so it must look flat (decision 0009).
	var points := PackedVector2Array([Vector2.ZERO])
	var steps := 16
	for i in steps + 1:
		var p := Vector2.RIGHT.rotated(lerpf(-half, half, float(i) / steps)) * r
		points.append(Vector2(p.x, p.y * ground_squash))
	draw_colored_polygon(points, telegraph_color)
