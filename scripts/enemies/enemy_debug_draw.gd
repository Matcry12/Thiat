class_name EnemyDebugDraw
extends Node2D
## F1 shapes of one Enemy: aggro (thin), leash (faint), home, hop lane during windup. Own node, no combat code.

@onready var _enemy: Enemy = get_parent() as Enemy
var _overlay: Node

func _process(_delta: float) -> void:
	if _overlay == null:
		for n in get_tree().get_nodes_in_group("debug"):
			if n is CanvasLayer and n.get("dummy_path") != null:
				_overlay = n
	visible = _overlay != null and _overlay.enabled
	if visible:
		queue_redraw()

func _draw() -> void:
	var d := _enemy.data
	var home := to_local(_enemy.home)
	draw_arc(home, d.leash_radius, 0.0, TAU, 64, Color(0.9, 0.3, 0.9, 0.2), 1.0)
	draw_arc(Vector2.ZERO, d.aggro_radius, 0.0, TAU, 48, Color(1.0, 0.8, 0.2, 0.7), 1.0)
	draw_arc(home, 5.0, 0.0, TAU, 12, Color(0.55, 0.7, 0.85), 1.5)
	if _enemy.state == Enemy.State.WINDUP:
		var end := _enemy.lane_dir * d.hop_distance
		draw_line(Vector2.ZERO, end, Color(1.0, 0.25, 0.2, 0.9), 2.0)
		draw_arc(end, d.contact_radius, 0.0, TAU, 16, Color(1.0, 0.25, 0.2, 0.9), 1.5)
