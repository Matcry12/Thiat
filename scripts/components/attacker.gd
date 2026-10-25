extends Node
class_name Attacker
## idle -> telegraph -> strike -> cooldown loop, driven purely by distance to
## a target. Never reads Input — reusable by the boss later. Strikes through
## a Hitbox (decision 0011: the hit area is a shape authored in the scene,
## not numbers here) and drives a Telegraph sized from that same shape, so
## the warning always matches what actually lands.

signal state_changed(state: String)

enum Phase { IDLE, TELEGRAPH, STRIKE, COOLDOWN, STAGGER }

@export var attack_range := 90.0
@export var telegraph_time := 0.9
@export var strike_time := 0.15
@export var attack_cooldown := 1.8
@export var attack_damage := 25.0
@export var parryable := true

@export var target_path: NodePath
@export var hitbox_path: NodePath
@export var telegraph_path: NodePath

var phase: Phase = Phase.IDLE

var _target: Node2D
var _hitbox: Hitbox
var _telegraph: Telegraph
var _origin: Node2D
var _weapon: WeaponData
var _phase_time := 0.0
var _stagger_duration := 0.0

func _ready() -> void:
	add_to_group("debug")
	_origin = get_parent() as Node2D
	_target = get_node_or_null(target_path) as Node2D
	_hitbox = get_node_or_null(hitbox_path) as Hitbox
	_telegraph = get_node_or_null(telegraph_path) as Telegraph

	_weapon = WeaponData.new()
	_weapon.damage = attack_damage
	if _hitbox:
		_hitbox.weapon = _weapon
		var cs := _hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs and _telegraph:
			_telegraph.set_shape(cs.shape)

## Lets a test (or a future spawner) assign the target without a scene NodePath.
func set_target(node: Node2D) -> void:
	_target = node

func _physics_process(delta: float) -> void:
	if _weapon:
		_weapon.damage = attack_damage  ## live-tunable from the F3 panel
		_weapon.parryable = parryable
	match phase:
		Phase.IDLE:
			if _in_range():
				_set_phase(Phase.TELEGRAPH)
		Phase.TELEGRAPH, Phase.STRIKE, Phase.COOLDOWN, Phase.STAGGER:
			_phase_time += delta
			var duration := _duration_for(phase)
			if _phase_time >= duration:
				_advance()

func _in_range() -> bool:
	if _target == null or _origin == null:
		return false
	return _origin.global_position.distance_to(_target.global_position) <= attack_range

func _duration_for(p: Phase) -> float:
	match p:
		Phase.TELEGRAPH: return telegraph_time
		Phase.STRIKE: return strike_time
		Phase.COOLDOWN: return attack_cooldown
		Phase.STAGGER: return _stagger_duration
		_: return 0.0

func _advance() -> void:
	match phase:
		Phase.TELEGRAPH: _set_phase(Phase.STRIKE)
		Phase.STRIKE: _set_phase(Phase.COOLDOWN)
		Phase.COOLDOWN: _set_phase(Phase.IDLE)
		Phase.STAGGER: _set_phase(Phase.IDLE)

## Cancels the current strike and holds in STAGGER for `duration` — called by
## Guard.resolve() (duck-typed as `source.stagger()`) on a successful parry.
func stagger(duration: float) -> void:
	if _hitbox:
		_hitbox.end_swing()
	if _telegraph:
		_telegraph.hide_now()
	_stagger_duration = duration
	_set_phase(Phase.STAGGER)

func _set_phase(new_phase: Phase) -> void:
	phase = new_phase
	_phase_time = 0.0
	match new_phase:
		Phase.TELEGRAPH:
			if _telegraph:
				_telegraph.show_for(telegraph_time, parryable)
		Phase.STRIKE:
			if _hitbox:
				_hitbox.start_swing()
		Phase.COOLDOWN:
			if _hitbox:
				_hitbox.end_swing()
	state_changed.emit(Phase.keys()[phase].to_lower())


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Attacker"

func debug_category() -> String:
	return "Combat"

func status_text() -> String:
	return "state: %s" % Phase.keys()[phase].to_lower()
