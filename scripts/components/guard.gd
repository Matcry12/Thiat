extends Node
class_name Guard
## Parry/block on one key (F), slice 3. A component like dodge.gd — never
## reads Input; the owner calls try_guard()/release() and writes aim_direction
## every frame. resolve() is where damage gets decided: parry negates and
## staggers, block chips, a miss or an unparryable attack goes through full.

signal state_changed(state: String)   # "ready" / "parry" / "block" / "recover"
signal parried(source: Node)
signal blocked(amount: float)

@export var parry_window := 0.25
@export var parry_arc_degrees := 180.0
@export var block_chip := 0.3
@export var block_move_scale := 0.4
@export var stagger_time := 0.8
@export var miss_recovery := 0.5
@export var weapon_holder_path: NodePath
@export var body_path: NodePath          # to read global_position for the arc test

enum State { READY, PARRY, BLOCK, RECOVER }
var state: State = State.READY
var aim_direction := Vector2.RIGHT       # written by the owner every frame

var _weapon_holder: WeaponHolder
var _body: Node2D
var _held := false
var _timer := 0.0

func _ready() -> void:
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder
	_body = get_node_or_null(body_path) as Node2D

## Owner calls this on F press. Opens the PARRY window; cancels an in-progress
## swing the same way Dodge does. No-op (returns false) during RECOVER.
func try_guard() -> bool:
	if state == State.RECOVER:
		return false
	_held = true
	if _weapon_holder:
		_weapon_holder.cancel()
	state = State.PARRY
	_timer = parry_window
	state_changed.emit("parry")
	return true

## Owner calls this on F release. Drops BLOCK straight to READY; during PARRY
## the release is only noted, the window still has to run out.
func release() -> void:
	_held = false
	if state == State.BLOCK:
		state = State.READY
		_timer = 0.0
		state_changed.emit("ready")

func move_scale() -> float:
	return block_move_scale if state == State.BLOCK else 1.0

func can_attack() -> bool:
	return state == State.READY

func is_guarding() -> bool:
	return state == State.PARRY or state == State.BLOCK

## Returns the FRACTION of damage that gets through (1.0 / block_chip / 0.0).
func resolve(raw_damage: float, source: Node, parryable: bool) -> float:
	match state:
		State.PARRY:
			if parryable and _within_arc(source):
				parried.emit(source)
				if source != null and source.has_method("stagger"):
					source.stagger(stagger_time)
				return 0.0
			return 1.0
		State.BLOCK:
			if parryable and _within_arc(source):
				blocked.emit(raw_damage * block_chip)
				return block_chip
			return 1.0
		_:
			return 1.0

func _within_arc(source: Node) -> bool:
	if source == null or _body == null or not (source is Node2D):
		return false
	var to_source: Vector2 = (source as Node2D).global_position - _body.global_position
	if to_source == Vector2.ZERO:
		return true
	# A signed angle_to() without absf() lets everything BEHIND the player
	# through — see .claude/memory/godot-gotchas.md.
	return absf(aim_direction.angle_to(to_source.normalized())) <= deg_to_rad(parry_arc_degrees) * 0.5

func _physics_process(delta: float) -> void:
	match state:
		State.PARRY:
			_timer -= delta
			if _timer <= 0.0:
				if _held:
					state = State.BLOCK
					state_changed.emit("block")
				else:
					state = State.RECOVER
					_timer = miss_recovery
					state_changed.emit("recover")
		State.RECOVER:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
				state_changed.emit("ready")
