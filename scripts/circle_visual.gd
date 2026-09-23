extends Node2D
## Generic primitive-art visual: a flat circle, optional facing line, optional
## weapon-state tint. Reused by player and dummy so "Visual" stays swappable
## for a sprite later without touching combat code.

@export var radius := 16.0
@export var base_color := Color.WHITE
@export var draw_facing_line := false
@export var facing_line_length := 40.0

var _tint := Color.WHITE

func _ready() -> void:
	queue_redraw()

func set_weapon_state(state: String) -> void:
	match state:
		"windup":
			_tint = Color.YELLOW
		"active":
			_tint = Color.RED
		"recovery":
			_tint = Color.GRAY
		_:
			_tint = Color.WHITE
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, base_color * _tint)
	if draw_facing_line:
		draw_line(Vector2.ZERO, Vector2.RIGHT * facing_line_length, Color.WHITE, 2.0)

func _process(_delta: float) -> void:
	if draw_facing_line:
		queue_redraw()
