extends Node
class_name Health
## HP + damage entry point. One place every damage path calls into.

signal damaged(amount: float)
signal died

@export var max_hp: float = 100.0
@export var armor: float = 0.0
## Test targets only: never drops below 1 hp, never emits `died`.
@export var immortal := false

var hp: float = 0.0

func _ready() -> void:
	hp = max_hp

## Single damage entry point (rule: no direct hp -= anywhere else).
func take_damage(raw_damage: float) -> void:
	var final_damage: float = maxf(1.0, raw_damage - armor * 0.5)
	hp = maxf(1.0 if immortal else 0.0, hp - final_damage)
	damaged.emit(final_damage)
	if hp <= 0.0:
		died.emit()
