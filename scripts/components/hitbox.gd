extends Area2D
class_name Hitbox
## Deals damage while active. Circle broad-phase + angle filter for the arc.
##
## Collision layers (project-wide convention, BIT VALUES as used in .tscn):
##   1 = world/walls   2 = player hurtbox   4 = enemy hurtbox
##   8 = player hitbox  16 = enemy hitbox
## A hitbox masks the hurtbox layer it should hit (player hitbox: layer 8, mask 4).

@export var weapon: WeaponData
@export var aim_direction := Vector2.RIGHT

var _hit_this_swing: Array[Node] = []

func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)

func start_swing() -> void:
	_hit_this_swing.clear()
	set_deferred("monitoring", true)

func end_swing() -> void:
	set_deferred("monitoring", false)

func _on_area_entered(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null or weapon == null:
		return
	var target := hurtbox.owner
	if target in _hit_this_swing:
		return
	var to_target: Vector2 = (hurtbox.global_position - global_position)
	if to_target.length() > weapon.reach:
		return
	var half_arc := deg_to_rad(weapon.arc_degrees / 2.0)
	# angle_to is signed; without abs() a target BEHIND the player passes the filter.
	if absf(aim_direction.angle_to(to_target)) > half_arc:
		return
	_hit_this_swing.append(target)
	var health := hurtbox.get_health()
	if health:
		health.take_damage(weapon.damage)
