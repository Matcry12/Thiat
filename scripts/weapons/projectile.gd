extends Node2D
class_name Projectile
## A physical bolt (Step 2, decision 0012 behaviour #3). WeaponHolder spawns
## one at the muzzle and calls `setup()` — the values it runs with (speed,
## range, damage, shooter) are plain vars set at spawn, never @exports: they
## describe THIS shot, not a tunable weapon (the bow that fired it is what's
## tunable, in WeaponData).
##
## Moves each physics step and raycasts the travelled SEGMENT (not a point
## check) so a fast arrow never tunnels through a thin target.

var _dir := Vector2.RIGHT
var _speed := 700.0
var _range := 520.0
var _damage := 0.0
var _parryable := true
var _shooter: Node
var _travelled := 0.0
var _shooter_rid: RID
var _first_step := true   ## see _physics_process: the first ray starts at the shooter, not the spawn point
var spawn_pos := Vector2.ZERO   ## read by the F1 overlay to draw the travel line

func _ready() -> void:
	# Lets the debug overlay (F1) draw a travel line without this script
	# reaching into it — same pattern as hitbox.gd's "hitbox" group.
	add_to_group("projectile")

func setup(dir: Vector2, speed: float, range: float, damage: float, parryable: bool, shooter: Node) -> void:
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	_speed = speed
	_range = range
	_damage = damage
	_parryable = parryable
	_shooter = shooter
	spawn_pos = global_position
	rotation = _dir.angle()
	if shooter is CollisionObject2D:
		_shooter_rid = (shooter as CollisionObject2D).get_rid()

func _physics_process(delta: float) -> void:
	var step: float = _speed * delta
	var to: Vector2 = global_position + _dir * step
	# The Muzzle sits ahead of the shooter's own hurtbox radius (bow_model.tscn),
	# so a point-blank shot spawns the arrow ALREADY PAST the target — a ray
	# from the spawn point never crosses the hurtbox and the hit is missed.
	# Checked from the shooter's actual position forward instead, exactly once:
	# that is where the shot logically starts.
	var from: Vector2 = global_position
	if _first_step and _shooter is Node2D:
		from = (_shooter as Node2D).global_position
	_first_step = false

	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	# world (1) + enemy hurtbox (4) — bit values per hitbox.gd's convention.
	query.collision_mask = 1 | 4
	if _shooter_rid.is_valid():
		query.exclude = [_shooter_rid]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	global_position = to
	_travelled += step

	if hit:
		global_position = hit.position
		var hurtbox := hit.collider as Hurtbox
		if hurtbox:
			var health := hurtbox.get_health()
			if health:
				health.take_damage(_damage, _shooter, _parryable)
		queue_free()
		return
	if _travelled >= _range:
		queue_free()
