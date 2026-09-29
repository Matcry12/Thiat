extends Skill
class_name LungeSlash
## Sword skill: a short fast dash toward the aim that cuts everything it
## touches, once per target. No i-frames (that is the dodge's job). Drives the
## body itself like Dodge, so the player must not write velocity meanwhile.

@export var distance := 140.0
@export var duration := 0.15
@export var damage := 45.0
@export var parryable := true
## Radius of the cutting area that rides along with the player.
@export var hit_radius := 26.0:
	set(v):
		hit_radius = v
		if _shape:
			_shape.radius = v

@onready var _hit_area: Area2D = $HitArea
@onready var _shape: CircleShape2D = ($HitArea/CollisionShape2D as CollisionShape2D).shape

var _user: CharacterBody2D
var _dir := Vector2.RIGHT
var _left := 0.0
var _duration := 0.15   ## duration captured at activate, floored so a tuned 0 cannot stall
var _travelled := 0.0
var _hit: Array[Node] = []

func _ready() -> void:
	_shape.radius = hit_radius

func activate(user: Node2D, aim: Vector2) -> void:
	_user = user as CharacterBody2D
	_dir = aim.normalized() if aim != Vector2.ZERO else Vector2.RIGHT
	_duration = maxf(duration, 0.01)
	_left = _duration
	_travelled = 0.0
	_hit.clear()
	global_position = user.global_position
	_hit_area.monitoring = true
	state_changed.emit("active")

func cancel() -> void:
	_stop()

func is_active() -> bool:
	return _left > 0.0

func moves_body() -> bool:
	return is_active()

func debug_reach(user: Node2D, aim: Vector2) -> PackedVector2Array:
	return PackedVector2Array([user.global_position, user.global_position + aim.normalized() * distance])

func _physics_process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left = maxf(0.0, _left - delta)
	# Same trick as Dodge: walk along `distance` by position, so it always
	# covers exactly that far (minus what a wall takes).
	var target: float = distance * (1.0 - _left / _duration)
	_user.velocity = _dir * ((target - _travelled) / maxf(delta, 0.0001))
	_travelled = target
	_user.move_and_slide()
	global_position = _user.global_position
	# Polled, not area_entered: a target already inside never fires an enter.
	for area in _hit_area.get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox.owner in _hit:
			continue
		_hit.append(hurtbox.owner)
		var health := hurtbox.get_health()
		if health:
			health.take_damage(damage, _user, parryable)
	if _left <= 0.0:
		_stop()
		finished.emit()

func _stop() -> void:
	if _left > 0.0 and _user:
		_user.velocity = Vector2.ZERO
	var was_active := _left > 0.0
	_left = 0.0
	_hit_area.monitoring = false
	if was_active:
		state_changed.emit("idle")
