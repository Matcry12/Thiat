extends Node
class_name Health
## Shield + HP, damage formula, i-frames. One place every damage path calls into.
##
## Damage order: armor first (`max(1, damage - armor*0.5)`), then the
## regenerating shield, then non-regenerating HP (design-pillars §2).
## `invulnerable` (set by Dodge's i-frames) makes take_damage a no-op and
## emits `dodged` instead, so feedback (HUD/overlay) can hook either signal.

signal damaged(amount: float)
signal dodged
signal died

@export var max_hp: float = 100.0
@export var armor: float = 0.0
@export var shield_max: float = 0.0
@export var shield_regen_delay: float = 5.0
@export var shield_regen_rate: float = 1.0  ## points/sec
## Test targets only: never drops below 1 hp, never emits `died`.
@export var immortal := false

var hp: float = 0.0
var shield: float = 0.0
var invulnerable := false

var _time_since_hit := 0.0
var _guard: Guard

func _ready() -> void:
	hp = max_hp
	shield = shield_max
	_guard = get_parent().get_node_or_null("Guard") as Guard

func _physics_process(delta: float) -> void:
	if shield >= shield_max:
		return
	_time_since_hit += delta
	if _time_since_hit >= shield_regen_delay:
		shield = minf(shield_max, shield + shield_regen_rate * delta)

## Single damage entry point (rule: no direct hp -= anywhere else).
## `source`/`parryable` feed an optional sibling Guard (slice 3): a parry
## negates the hit entirely, a block chips it, both duck-type a `stagger()`
## call onto `source` on a successful parry.
func take_damage(raw_damage: float, source: Node = null, parryable := true) -> void:
	if invulnerable:
		dodged.emit()
		return
	if _guard:
		var through: float = _guard.resolve(raw_damage, source, parryable)
		if through <= 0.0:
			return
		raw_damage *= through
	_time_since_hit = 0.0
	var remaining: float = maxf(1.0, raw_damage - armor * 0.5)
	if shield > 0.0:
		var absorbed := minf(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0.0:
		hp = maxf(1.0 if immortal else 0.0, hp - remaining)
	damaged.emit(maxf(1.0, raw_damage - armor * 0.5))
	if hp <= 0.0:
		died.emit()
