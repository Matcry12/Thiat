extends Node2D
class_name GuardVisual
## Placeholder art ONLY (CLAUDE.md rule 5: every effect gets a slot). Driven
## purely by on_guard_state()/on_parry_success()/set_aim_angle() so a real
## shield sprite can replace this with zero changes to Guard or player.gd.
## Never reaches into Guard — the owner mirrors parry_arc_degrees onto this
## node's own export every frame. Flat 2D: no perspective squashing.

@export var radius := 30.0
@export var thickness := 4.0
@export var parry_arc_degrees := 180.0
@export var parry_color := Color(0.4, 0.9, 1.0, 0.9)
@export var block_color := Color(0.3, 0.5, 0.6, 0.6)
@export var flash_color := Color(1.0, 1.0, 1.0, 0.9)
@export var flash_time := 0.25

var _state := "ready"
var _aim_angle := 0.0
var _flash_remaining := 0.0

func on_guard_state(state: String) -> void:
	_state = state
	queue_redraw()

func on_parry_success() -> void:
	_flash_remaining = flash_time
	queue_redraw()

func set_aim_angle(radians: float) -> void:
	_aim_angle = radians
	queue_redraw()

func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()

func _draw() -> void:
	var half := deg_to_rad(parry_arc_degrees) * 0.5
	var from := _aim_angle - half
	var to := _aim_angle + half

	if _state == "parry":
		draw_arc(Vector2.ZERO, radius, from, to, 32, parry_color, thickness * 0.5)
	elif _state == "block":
		draw_arc(Vector2.ZERO, radius, from, to, 32, block_color, thickness)

	if _flash_remaining > 0.0:
		var c := flash_color
		c.a *= _flash_remaining / flash_time
		draw_arc(Vector2.ZERO, radius, from, to, 32, c, thickness * 1.5)
