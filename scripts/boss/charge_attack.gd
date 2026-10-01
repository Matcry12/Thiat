extends BossAttack
class_name ChargeAttack
## Lane tell, then a fast dash along it. Orange (parryable): a parry staggers
## the boss (Guard calls boss.stagger()). Damages once per charge. Stops at
## the first solid thing: a wall OR the player's body, so the two bodies never
## end up overlapped. The Hitbox (r 36) reaches the player's hurtbox before
## the bodies touch, and stays on for a few frames after the dash so the hit
## cannot be missed on the frame the dash stops. The lane is locked when the tell starts, so a moving player
## can sidestep it. The Hitbox rides on the boss; the lane rectangle is derived
## from `distance` and the Hitbox's radius.

const LINGER_FRAMES := 3

@export var speed := 500.0
@export var distance := 400.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _telegraph: Telegraph = $Telegraph

var _dir := Vector2.RIGHT
var _travelled := 0.0
var _ending := 0   # frames since the dash finished; the hitbox lingers
var _lane := RectangleShape2D.new()

func _ready() -> void:
	super._ready()
	_hook(_hitbox)
	_telegraph.top_level = true   # the lane stays put while the boss moves

func _radius() -> float:
	var c := _shape_of(_hitbox) as CircleShape2D
	return c.radius if c else 24.0

func _on_telegraph() -> void:
	_dir = (target.global_position - boss.global_position).normalized()
	if _dir == Vector2.ZERO:
		_dir = Vector2.RIGHT
	var r := _radius()
	_lane = RectangleShape2D.new()
	_lane.size = Vector2(distance + 2.0 * r, 2.0 * r)
	_telegraph.set_shape(_lane)
	_telegraph.global_position = boss.global_position + _dir * distance * 0.5
	_telegraph.global_rotation = _dir.angle()
	_telegraph.show_for(telegraph_time, parryable)

func _on_active() -> void:
	_travelled = 0.0
	_ending = 0
	_hitbox.start_swing()

func _active_tick(delta: float) -> bool:
	var step := minf(speed * delta, distance - _travelled)
	var hit := (boss as CharacterBody2D).move_and_collide(_dir * step)
	_travelled += step
	if hit != null or _travelled >= distance - 0.01:
		_ending += 1
	return _ending >= LINGER_FRAMES

func _on_recovery() -> void:
	_hitbox.end_swing()

func _on_cancel() -> void:
	_hitbox.end_swing()
	_telegraph.hide_now()

func debug_areas() -> Array:
	if phase != Phase.TELEGRAPH and phase != Phase.ACTIVE:
		return []
	# During the dash the lane is still where it was locked.
	var lane_xform := Transform2D(_dir.angle(), _telegraph.global_position)
	return [{"shape": _lane, "xform": lane_xform, "color": _warn_color()}]
