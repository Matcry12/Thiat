extends Node
class_name Loadout
## Weapon swap (decision 0003): a gated cast, then a cooldown before the next
## swap. A component like dodge.gd — never reads Input; the owner calls
## try_swap()/cancel_swap() and reads is_casting()/cooldown_left() for HUD/F3.

signal swap_started(to_index: int)
signal swap_finished(weapon: WeaponData)
signal swap_cancelled

@export var weapons: Array[WeaponData] = []   ## max 2 (decision 0003)
@export var swap_cast := 0.6
@export var swap_cooldown := 5.0
@export var weapon_holder_path: NodePath

var _weapon_holder: WeaponHolder
var _active_index := 0
var _casting := false
var _cast_left := 0.0
var _cast_to := 0
var _cooldown_left := 0.0

func _ready() -> void:
	_weapon_holder = get_node_or_null(weapon_holder_path) as WeaponHolder

func active_weapon() -> WeaponData:
	return weapons[_active_index] if _active_index < weapons.size() else null

func active_index() -> int:
	return _active_index

func is_casting() -> bool:
	return _casting

func cast_left() -> float:
	return _cast_left

func cooldown_left() -> float:
	return _cooldown_left

## Fails (returns false) if `index` is already active, out of range, a swap
## is already casting, or the cooldown from the last swap hasn't cleared.
func try_swap(index: int) -> bool:
	if index == _active_index or index < 0 or index >= weapons.size():
		return false
	if _casting or _cooldown_left > 0.0:
		return false
	_casting = true
	_cast_left = swap_cast
	_cast_to = index
	if _weapon_holder:
		_weapon_holder.cancel()   # a swap cancels an in-progress swing
	swap_started.emit(index)
	return true

## Cancels an in-progress cast (dodge/guard call this). No cooldown charged.
func cancel_swap() -> void:
	if not _casting:
		return
	_casting = false
	_cast_left = 0.0
	swap_cancelled.emit()

func _physics_process(delta: float) -> void:
	if _casting:
		_cast_left -= delta
		if _cast_left <= 0.0:
			_casting = false
			_active_index = _cast_to
			_cooldown_left = swap_cooldown
			swap_finished.emit(active_weapon())
	elif _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)
