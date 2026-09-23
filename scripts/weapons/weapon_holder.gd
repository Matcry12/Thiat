extends Node
class_name WeaponHolder
## windup -> active -> recovery state machine. Manual accumulator (not await),
## so a future dodge can cancel mid-swing. See combat-patterns.md §4.

signal state_changed(state: String)

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

@export var weapon: WeaponData
@export var hitbox: Hitbox

var phase: Phase = Phase.IDLE
var _phase_time := 0.0

## Called by whoever owns this holder (player input, or a boss Brain later).
## The holder never reads Input itself — that is what makes it reusable.
func try_attack() -> bool:
	if phase != Phase.IDLE:
		return false
	_start_attack()
	return true

func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	_phase_time += delta
	match phase:
		Phase.WINDUP:
			if _phase_time >= weapon.windup:
				_set_phase(Phase.ACTIVE)
				hitbox.start_swing()
		Phase.ACTIVE:
			if _phase_time >= weapon.active:
				_set_phase(Phase.RECOVERY)
				hitbox.end_swing()
		Phase.RECOVERY:
			if _phase_time >= weapon.recovery:
				_set_phase(Phase.IDLE)

func _start_attack() -> void:
	if weapon == null or hitbox == null:
		return
	hitbox.weapon = weapon
	_set_phase(Phase.WINDUP)

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	state_changed.emit(Phase.keys()[phase].to_lower())
