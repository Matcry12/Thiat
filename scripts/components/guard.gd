extends Node
class_name Guard
## Parry/block on one key (F), slice 3. A component like dodge.gd — never
## reads Input; the owner calls try_guard()/release() and writes aim_direction
## every frame. resolve() is where damage gets decided: parry negates and
## staggers, block soaks damage with a shield tank until it breaks, a miss or
## an unparryable attack goes through full.

signal state_changed(state: String)   # "ready" / "parry" / "block" / "recover" / "broken"
signal parried(source: Node)
signal blocked(amount: float)
signal broke
signal tank_changed(current: float, maximum: float)

@export var parry_window := 0.25
@export var parry_arc_degrees := 180.0
@export var block_move_scale := 0.4
@export var stagger_time := 0.8
@export var miss_recovery := 0.5
@export var tank_max := 60.0
@export var tank_regen_delay := 3.0
@export var tank_regen_rate := 20.0
@export var break_recovery := 1.5
@export var weapon_holder_path: NodePath
@export var body_path: NodePath          # to read global_position for the arc test

enum State { READY, PARRY, BLOCK, RECOVER, BROKEN }
var state: State = State.READY
var aim_direction := Vector2.RIGHT       # written by the owner every frame
var tank: float

var _weapon_holder: WeaponHolder
var _body: Node2D
var _held := false
var _timer := 0.0            # state-transition countdown (PARRY/RECOVER/BROKEN)
var _regen_timer := 0.0      # time since the tank last drained

func _ready() -> void:
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder
	_body = get_node_or_null(body_path) as Node2D
	tank = tank_max

## Owner calls this on F press. Opens the PARRY window; cancels an in-progress
## swing the same way Dodge does. No-op (returns false) during RECOVER/BROKEN.
func try_guard() -> bool:
	if state == State.RECOVER or state == State.BROKEN:
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

## BROKEN is a guard punish, not a movement/attack freeze: full speed, can attack.
func can_attack() -> bool:
	return state == State.READY or state == State.BROKEN

func is_guarding() -> bool:
	return state == State.PARRY or state == State.BLOCK

func tank_fraction() -> float:
	if tank_max <= 0.0:
		return 0.0
	return tank / tank_max

## Returns the FRACTION of raw_damage that gets through to Health.
func resolve(raw_damage: float, source: Node, parryable: bool) -> float:
	match state:
		State.PARRY:
			# Purple breaks the guard in the tap window too, exactly as in BLOCK.
			# Otherwise tapping F at a purple attack was SAFER than holding it,
			# and the rule would stop being "purple = dodge" (judge finding).
			if not parryable:
				_break_tank()
				return 1.0
			if _within_arc(source):
				parried.emit(source)
				if source != null and source.has_method("stagger"):
					source.stagger(stagger_time)
				return 0.0
			return 1.0
		State.BLOCK:
			if not parryable:
				# Unparryable breaks the shield instantly, full damage through.
				_break_tank()
				return 1.0
			if not _within_arc(source):
				return 1.0
			if raw_damage <= tank:
				_drain_tank(raw_damage)
				blocked.emit(raw_damage)
				return 0.0
			var absorbed := tank
			var leftover := raw_damage - absorbed
			_break_tank()
			blocked.emit(absorbed)
			return leftover / raw_damage
		_:
			return 1.0

func _drain_tank(amount: float) -> void:
	tank = maxf(0.0, tank - amount)
	_regen_timer = 0.0
	tank_changed.emit(tank, tank_max)

## Back to a fresh guard: ready, full tank (a respawn clears a broken one).
func reset() -> void:
	state = State.READY
	_timer = 0.0
	_regen_timer = 0.0
	tank = tank_max
	tank_changed.emit(tank, tank_max)
	state_changed.emit("ready")

func _break_tank() -> void:
	tank = 0.0
	_regen_timer = 0.0
	state = State.BROKEN
	_timer = break_recovery
	broke.emit()
	tank_changed.emit(tank, tank_max)
	state_changed.emit("broken")

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
		State.BROKEN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
				state_changed.emit("ready")
	_process_regen(delta)

## Regrows the tank once it has sat undrained for tank_regen_delay. Runs
## whenever the player isn't actively spending it (PARRY costs nothing, BLOCK
## is what drains it) — including BROKEN, which recovers on the same clock.
func _process_regen(delta: float) -> void:
	if state == State.PARRY or state == State.BLOCK:
		return
	if tank >= tank_max:
		return
	_regen_timer += delta
	if _regen_timer < tank_regen_delay:
		return
	var before := tank
	tank = minf(tank_max, tank + tank_regen_rate * delta)
	if tank != before:
		tank_changed.emit(tank, tank_max)
