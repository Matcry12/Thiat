extends Node
class_name Dodge
## Cooldown-gated burst dodge with i-frames (decision 0004). A component, not
## player-only logic — reusable by enemies later. Never reads Input; the
## owner calls try_dodge(move_dir, aim_dir).

signal used

@export var iframe_duration := 0.3
@export var burst_distance := 160.0
@export var cooldown := 2.0
## How long the dash takes. It is a fast MOVE, not a teleport: the body travels
## the distance over this time, so walls stop it and the eye can follow it.
@export var dash_duration := 0.14
## Speed shape across the dash. Below 1.0 = fast start then slow down, which
## reads as a burst rather than a constant slide.
@export var dash_ease := 0.45

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
var _dash_remaining := 0.0
var _dash_dir := Vector2.RIGHT
var _dash_travelled := 0.0   ## how far along burst_distance we already are

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

	_dash_dir = dir
	_dash_remaining = dash_duration
	_dash_travelled = 0.0
	if _weapon_holder:
		_weapon_holder.cancel()
	if _health:
		_health.invulnerable = true

	_cooldown_remaining = cooldown
	_iframe_remaining = iframe_duration
	used.emit()
	return true

## Stops a dash on the spot (the player died mid-dash: the corpse must not slide).
func cancel() -> void:
	_dash_remaining = 0.0
	_iframe_remaining = 0.0
	if _health:
		_health.invulnerable = false
	if _body is CharacterBody2D:
		(_body as CharacterBody2D).velocity = Vector2.ZERO

## True while the dash is moving the body. The owner must skip its own movement
## for these frames, or the two fight over velocity.
func is_dashing() -> bool:
	return _dash_remaining > 0.0

func iframes_active() -> bool:
	return _iframe_remaining > 0.0

func cooldown_remaining() -> float:
	return _cooldown_remaining

func _physics_process(delta: float) -> void:
	if _dash_remaining > 0.0 and _body is CharacterBody2D:
		var body := _body as CharacterBody2D
		_dash_remaining = maxf(0.0, _dash_remaining - delta)
		# Drive by DISTANCE, not by a guessed speed: walk an eased 0..1 along
		# burst_distance, so the dash always covers exactly that far (minus
		# whatever a wall takes) however the easing is tuned.
		var t: float = 1.0 - (_dash_remaining / dash_duration)
		var target: float = burst_distance * ease(t, dash_ease)
		var step: float = target - _dash_travelled
		_dash_travelled = target
		body.velocity = _dash_dir * (step / maxf(delta, 0.0001))
		body.move_and_slide()
		if _dash_remaining <= 0.0:
			body.velocity = Vector2.ZERO

	if _cooldown_remaining > 0.0:
		_cooldown_remaining = maxf(0.0, _cooldown_remaining - delta)
	if _iframe_remaining > 0.0:
		_iframe_remaining = maxf(0.0, _iframe_remaining - delta)
		if _iframe_remaining <= 0.0 and _health:
			_health.invulnerable = false
