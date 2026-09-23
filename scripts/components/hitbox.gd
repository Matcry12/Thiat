extends Area2D
class_name Hitbox
## Deals damage while active. Circle broad-phase + angle filter for the arc.
##
## Collision layers (project-wide convention, BIT VALUES as used in .tscn):
##   1 = world/walls   2 = player hurtbox   4 = enemy hurtbox
##   8 = player hitbox  16 = enemy hitbox
## A hitbox masks the hurtbox layer it should hit (player hitbox: layer 8, mask 4).
##
## Overlaps are POLLED each active frame rather than driven by `area_entered`:
## an enter event never fires for a target that was already inside the radius when
## the swing began (the common case against a stationary enemy), and toggling
## `monitoring` costs a physics frame before overlaps repopulate.

@export var weapon: WeaponData
@export var aim_direction := Vector2.RIGHT

var _active := false
var _hit_this_swing: Array[Node] = []

func start_swing() -> void:
	_hit_this_swing.clear()
	_active = true

func end_swing() -> void:
	_active = false

func _physics_process(_delta: float) -> void:
	if not _active or weapon == null:
		return
	for area in get_overlapping_areas():
		_try_hit(area)

func _try_hit(area: Area2D) -> void:
	var hurtbox := area as Hurtbox
	if hurtbox == null:
		return
	var target := hurtbox.owner
	if target in _hit_this_swing:
		return
	var to_target: Vector2 = hurtbox.global_position - global_position
	if to_target.length() > weapon.reach:
		return
	# angle_to is signed; without absf() a target BEHIND the player passes the filter.
	if absf(aim_direction.angle_to(to_target)) > deg_to_rad(weapon.arc_degrees / 2.0):
		return
	_hit_this_swing.append(target)
	var health := hurtbox.get_health()
	if health:
		health.take_damage(weapon.damage)
