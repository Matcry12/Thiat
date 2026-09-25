extends Node2D
class_name Telegraph
## Ground indicator: fills orange -> red over show_for(duration), then
## disappears. Its own node/scene (CLAUDE.md rule 5: every effect gets a
## slot) so it can be swapped for a shader/sprite later without touching
## Attacker. Flat 2D — no perspective squashing (.claude/memory/mistakes.md).
##
## Reads its size from whatever shape it's given via set_shape(), so the
## warning always matches the hitbox that will actually land (never a
## second, hand-tuned set of numbers).

@export var color_start := Color(1.0, 0.55, 0.0, 0.35)
@export var color_end := Color(1.0, 0.0, 0.0, 0.55)
## Purple pair: "you cannot parry this, dodge it" (unparryable attacks).
@export var unparryable_color_start := Color(0.55, 0.0, 0.85, 0.35)
@export var unparryable_color_end := Color(0.35, 0.0, 0.55, 0.55)
@export var border_color := Color(1.0, 1.0, 1.0, 0.85)
@export var border_width := 2.0

var _shape: Shape2D
var _duration := 0.0
var _t := 0.0
var _active := false
var _parryable := true

func _ready() -> void:
	visible = false

func set_shape(shape: Shape2D) -> void:
	_shape = shape
	queue_redraw()

func show_for(duration: float, parryable := true) -> void:
	_duration = maxf(duration, 0.001)
	_t = 0.0
	_active = true
	_parryable = parryable
	visible = true
	queue_redraw()

func hide_now() -> void:
	_active = false
	visible = false

func _process(_delta: float) -> void:
	if not _active:
		return
	_t += get_process_delta_time()
	if _t >= _duration:
		hide_now()
		return
	queue_redraw()

func _draw() -> void:
	if _shape == null:
		return
	var progress := clampf(_t / _duration, 0.0, 1.0)
	var start := color_start if _parryable else unparryable_color_start
	var end := color_end if _parryable else unparryable_color_end
	var fill: Color = start.lerp(end, progress)
	if _shape is CircleShape2D:
		var r: float = (_shape as CircleShape2D).radius
		draw_circle(Vector2.ZERO, r, fill)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, border_color, border_width)
	elif _shape is RectangleShape2D:
		var half: Vector2 = (_shape as RectangleShape2D).size / 2.0
		draw_rect(Rect2(-half, half * 2.0), fill)
		draw_rect(Rect2(-half, half * 2.0), border_color, false, border_width)
