extends BossAttack
class_name SpreadAttack
## A fan of bolts toward where the player stood when the tell began. Orange
## (parryable). The bolts are the shared Projectile; the tell is the fan
## wedge (bolts fly along its rays — the gaps between them are safe).
## Each bolt is its own damage source: parrying it destroys THAT bolt and does
## not stagger the boss from across the arena (decision 0019).

@export var projectile_scene: PackedScene
@export var count := 5
@export var fan_degrees := 50.0
@export var projectile_speed := 380.0
@export var projectile_range := 520.0
@export var spawn_offset := 32.0

## Player hurtbox (2) + world (1). See projectile.gd `setup(... hit_mask)`.
const HIT_MASK := 1 | 2

@onready var _telegraph: Telegraph = $Telegraph

var _aim := Vector2.RIGHT

func _on_telegraph() -> void:
	_aim = (target.global_position - boss.global_position).normalized()
	if _aim == Vector2.ZERO:
		_aim = Vector2.RIGHT
	global_rotation = _aim.angle()
	var s := ConvexPolygonShape2D.new()
	s.points = SectorShape.build_sector_polygon(fan_degrees, projectile_range, 0.0, 12)
	_telegraph.set_shape(s)
	_telegraph.show_for(telegraph_time, parryable)

func _on_active() -> void:
	if projectile_scene == null:
		return
	var parent: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	for i in count:
		var f := 0.5 if count <= 1 else float(i) / (count - 1)
		var dir := _aim.rotated(deg_to_rad(lerpf(-fan_degrees * 0.5, fan_degrees * 0.5, f)))
		var p: Node2D = projectile_scene.instantiate()
		parent.add_child(p)
		p.global_position = boss.global_position + dir * spawn_offset
		p.setup(dir, projectile_speed, projectile_range, damage, parryable, boss, false, HIT_MASK, p)

func _on_recovery() -> void:
	pass

func _on_cancel() -> void:
	_telegraph.hide_now()

func debug_areas() -> Array:
	if phase != Phase.TELEGRAPH:
		return []
	var s := ConvexPolygonShape2D.new()
	s.points = SectorShape.build_sector_polygon(fan_degrees, projectile_range, 0.0, 12)
	return [{"shape": s, "xform": global_transform, "color": _warn_color()}]
