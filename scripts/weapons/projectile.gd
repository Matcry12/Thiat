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
var _source: Node   ## who Health/Guard see as the damage source (default: the shooter)
var _travelled := 0.0
var _shooter_rid: RID
var _first_step := true   ## see _physics_process: the first ray starts at the shooter, not the spawn point
var _mask := 1 | 4       ## what this bolt hits: world + enemy hurtbox by default (player shots)
var _tag: StringName = &"arrow"   ## what Health/HitFx are told this shot is
var _pierce := false      ## passes through targets instead of stopping (Piercing Shot)
var _hit: Array[Node] = []   ## targets already damaged: a piercing arrow hits each once
var _pierced: Array[RID] = []   ## their hurtbox + body: kept across frames, or the body (a "wall") would stop the arrow next step
var spawn_pos := Vector2.ZERO   ## read by the F1 overlay to draw the travel line

func _ready() -> void:
	# Lets the debug overlay (F1) draw a travel line without this script
	# reaching into it — same pattern as hitbox.gd's "hitbox" group.
	add_to_group("projectile")

func setup(dir: Vector2, speed: float, range: float, damage: float, parryable: bool, shooter: Node, pierce := false, hit_mask := 1 | 4, damage_source: Node = null, hit_tag: StringName = &"arrow") -> void:
	_tag = hit_tag
	_mask = hit_mask
	_source = damage_source if damage_source else shooter
	_dir = dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	_speed = speed
	_range = range
	_damage = damage
	_parryable = parryable
	_shooter = shooter
	_pierce = pierce
	spawn_pos = global_position
	rotation = _dir.angle()
	if shooter is CollisionObject2D:
		_shooter_rid = (shooter as CollisionObject2D).get_rid()

func get_shooter() -> Node:
	return _shooter

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
	# Default: world (1) + enemy hurtbox (4), bit values per hitbox.gd's convention.
	# A boss bolt passes world (1) + player hurtbox (2) instead.
	query.collision_mask = _mask
	var exclude: Array[RID] = _pierced.duplicate()
	if _shooter_rid.is_valid():
		exclude.append(_shooter_rid)

	global_position = to
	_travelled += step

	# A normal arrow stops at the first thing. A piercing one damages a target,
	# excludes it (and its body) and re-casts the rest of the segment, so it
	# still stops on a wall.
	while true:
		query.exclude = exclude
		var hit := get_world_2d().direct_space_state.intersect_ray(query)
		if not hit:
			break
		var hurtbox := hit.collider as Hurtbox
		# A target's BODY (world layer) can be bigger than its hurtbox, so the ray
		# meets the body first. A body that owns a Hurtbox is that target, not a wall.
		if hurtbox == null:
			hurtbox = (hit.collider as Node).get_node_or_null("Hurtbox") as Hurtbox
			# That Hurtbox is on a layer this shot does not target (a boss bolt
			# and the training Dummy): the body is not a target, and not a wall
			# either. Skip it, so the Dummy cannot shield the player.
			if hurtbox and (hurtbox.collision_layer & _mask) == 0:
				exclude.append(hit.rid)
				continue
		if hurtbox and _pierce:
			_damage_hurtbox(hurtbox)
			for rid in [hurtbox.get_rid(), (hurtbox.owner as CollisionObject2D).get_rid() if hurtbox.owner is CollisionObject2D else RID()]:
				if rid.is_valid():
					exclude.append(rid)
					_pierced.append(rid)
			continue
		global_position = hit.position
		if hurtbox:
			_damage_hurtbox(hurtbox)
		queue_free()
		return
	if _travelled >= _range:
		queue_free()

func _damage_hurtbox(hurtbox: Hurtbox) -> void:
	if hurtbox.owner in _hit:
		return
	_hit.append(hurtbox.owner)
	var health := hurtbox.get_health()
	if health:
		health.take_damage(_damage, _source, _parryable, _tag)
