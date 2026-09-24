extends Area2D
class_name Hitbox
## Deals damage to anything the shape overlaps while active.
##
## The shape (a `CollisionShape2D` or `CollisionPolygon2D` child of this node)
## IS the hit area — there is no reach/arc math here to keep in sync with it.
## It may be hand-authored (dragged in the editor, like the enemy's strike
## circle) OR generated from weapon numbers (`SectorShape`, under the melee
## Hitbox, decision 0011 amendment). Either way there is exactly one shape and
## it is the single source of truth; this script never computes geometry.
##
## Collision layers (project-wide convention, BIT VALUES as used in .tscn):
##   1 = world/walls   2 = player hurtbox   4 = enemy hurtbox
##   8 = player hitbox  16 = enemy hitbox
## A hitbox masks the hurtbox layer it should hit (player hitbox: layer 8, mask 4).
##
## Overlaps are POLLED each active frame rather than driven by `area_entered`:
## an enter event never fires for a target that was already inside the shape
## when the swing began (the common case against a stationary enemy), and
## toggling `monitoring` costs a physics frame before overlaps repopulate.

@export var weapon: WeaponData

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
	_hit_this_swing.append(target)
	var health := hurtbox.get_health()
	if health:
		health.take_damage(weapon.damage)
