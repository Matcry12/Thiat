extends StaticBody2D
## Static test target: takes damage, flashes, never dies (hp clamped at 1 in Health).

@onready var visual: Node2D = $Visual
@onready var health: Health = $Health

func _ready() -> void:
	health.damaged.connect(_on_damaged)

func _on_damaged(amount: float) -> void:
	print("dummy took %.1f damage (hp=%.1f)" % [amount, health.hp])
	visual.modulate = Color.WHITE
	var tween := create_tween()
	tween.tween_property(visual, "modulate", Color.RED, 0.05)
