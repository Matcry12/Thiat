extends ActorVisual
class_name BossVisual
## Placeholder boss body: a flat circle. boss.gd never reaches inside — it
## connects its signals to the methods below (the contract), so a sprite
## visual only has to provide the same methods (decision 0005, CLAUDE.md §5).

@export var radius := 28.0
@export var base_color := Color(0.45, 0.07, 0.07)
@export var phase2_color := Color(0.4, 0.0, 0.3)
## Walking home after giving up: pale, so it reads as "can't be hurt right now".
@export var returning_color := Color(0.55, 0.7, 0.85)
@export var staggered_color := Color(0.85, 0.8, 0.3)
@export var defeated_color := Color(0.25, 0.25, 0.25)
@export var flash_time := 0.05

var _phase := 1
var _returning := false
var _staggered := false
var _defeated := false
var _flash := 0.0

func set_phase(p: int) -> void:
	_phase = p
	queue_redraw()

## state = Boss.Aggro (0 idle, 1 engaged, 2 returning). Only "returning" looks different.
func set_aggro(state: int) -> void:
	_returning = state == 2
	queue_redraw()

func set_staggered(on: bool) -> void:
	_staggered = on
	queue_redraw()

func set_defeated() -> void:
	_defeated = true
	queue_redraw()

func on_hit() -> void:
	_flash = flash_time
	queue_redraw()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		if _flash <= 0.0:
			queue_redraw()

func _draw() -> void:
	var c := base_color if _phase < 2 else phase2_color
	if _returning:
		c = returning_color
	if _staggered:
		c = staggered_color
	if _defeated:
		c = defeated_color
	if _flash > 0.0:
		c = Color.WHITE
	draw_circle(Vector2.ZERO, radius, c)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, c.lightened(0.4), 2.0)
