extends Node
class_name Dodge
## Cooldown-gated burst dodge with i-frames (decision 0004). A component, not
## player-only logic — reusable by enemies later. Never reads Input; the
## owner calls try_dodge(move_dir, aim_dir).

signal used

@export var iframe_duration := 0.3
@export var burst_distance := 160.0
@export var cooldown := 2.0

## NodePaths, not typed exports: a NodePath written into a .tscn does not
## resolve into a typed-Node export (see weapon_holder.gd). Resolved by hand.
@export var body_path: NodePath
@export var health_path: NodePath
@export var weapon_holder_path: NodePath

var _body: Node2D
var _health: Health
var _weapon_holder: WeaponHolder

var _cooldown_remaining := 0.0
var _iframe_remaining := 0.0

func _ready() -> void:
	_body = get_node_or_null(body_path) as Node2D
	_health = get_node_or_null(health_path) as Health
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder

func can_dodge() -> bool:
	return _cooldown_remaining <= 0.0

## Bursts in move_dir (movement direction); falls back to aim_dir when
## standing still. Cancels an in-progress attack (WeaponHolder.cancel()).
func try_dodge(move_dir: Vector2, aim_dir: Vector2) -> bool:
	if not can_dodge():
		return false
	var dir: Vector2 = move_dir if move_dir.length() > 0.01 else aim_dir
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	dir = dir.normalized()

	# ponytail: a straight position add, no wall collision check. Add
	# move_and_collide if dodging is ever seen clipping through a wall.
	if _body:
		_body.global_position += dir * burst_distance
	if _weapon_holder:
		_weapon_holder.cancel()
	if _health:
		_health.invulnerable = true

	_cooldown_remaining = cooldown
	_iframe_remaining = iframe_duration
	used.emit()
	return true

func iframes_active() -> bool:
	return _iframe_remaining > 0.0

func cooldown_remaining() -> float:
	return _cooldown_remaining

func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _iframe_remaining > 0.0:
		_iframe_remaining = maxf(0.0, _iframe_remaining - delta)
		if _iframe_remaining <= 0.0 and _health:
			_health.invulnerable = false
