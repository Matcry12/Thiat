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
## [shape, global transform] of every try in the last sweep; the F1 overlay draws it.
var sweep_poses: Array = []

var _active := false
var _hit_this_swing: Array[Node] = []

func _ready() -> void:
	# Group membership, not a hardcoded path: the hitbox gets reparented as the
	# design evolves (blade -> hand pivot -> swing pivot) and a path in another
	# script breaks silently every time.
	add_to_group("hitbox")

## True while this hitbox can deal damage — used by the debug overlay so it
## draws only what is genuinely dangerous right now.
func is_active() -> bool:
	return _active

func start_swing() -> void:
	_hit_this_swing.clear()
	_active = true

func end_swing() -> void:
	_active = false
	sweep_poses.clear()

## Called by WeaponHolder right after start_swing() for a snapping arc weapon
## (enemy Attackers never call it). Hits everything the shape passes through
## between -arc/2 and +arc/2. See arc_poses() for the geometry.
func sweep_arc() -> void:
	sweep_poses = arc_poses(weapon.sweep_samples if weapon else 0)
	if sweep_poses.is_empty():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_2d().direct_space_state
	for pose in sweep_poses:
		query.shape = pose[0]
		query.transform = pose[1]
		for r in space.intersect_shape(query, 32):
			if r.collider is Area2D:
				_try_hit(r.collider)

## [shape, global transform] of this hitbox's shape(s) at `samples` angles from
## -arc/2 to +arc/2 around the grip. Layout assumed (decision 0010): Hitbox ->
## model -> SwingPivot -> aim node (WeaponVisual: aim rotation + left mirror).
## Only the pivot's POSITION and each shape's pose RELATIVE to the pivot are
## read, never the pivot's current rotation, so the result does not depend on
## the picture. Pure geometry: the slash effect draws from the same poses.
func arc_poses(samples: int) -> Array:
	var out := []
	if weapon == null or weapon.arc_degrees <= 0.0 or samples < 2:
		return out
	var pivot := get_parent().get_parent() as Node2D if get_parent() and get_parent().get_parent() else null
	if pivot == null or pivot.name != &"SwingPivot" or not pivot.get_parent() is Node2D:
		_warn_once("needs the layout Hitbox -> model -> SwingPivot -> aim node; the arc sweep is off")
		return out
	var aim_frame: Transform2D = (pivot.get_parent() as Node2D).global_transform
	var half := deg_to_rad(weapon.arc_degrees) * 0.5
	for sh in _shapes():
		var rel: Transform2D = pivot.global_transform.affine_inverse() * sh[1]
		for i in samples:
			var a := lerpf(-half, half, float(i) / (samples - 1))
			out.append([sh[0], aim_frame * Transform2D(a, pivot.position) * rel])
	if out.is_empty():
		_warn_once("has no usable CollisionShape2D / convex CollisionPolygon2D to sweep")
	return out

## The hit shapes as [Shape2D, global transform]. A CollisionPolygon2D is swept
## as a convex polygon; a concave one is swept as its convex hull (warned).
func _shapes() -> Array:
	var out := []
	for c in get_children():
		if c is CollisionShape2D and not c.disabled and c.shape != null:
			out.append([c.shape, c.global_transform])
		elif c is CollisionPolygon2D and not c.disabled and c.polygon.size() >= 3:
			var cv := ConvexPolygonShape2D.new()
			cv.set_point_cloud(c.polygon)
			if cv.points.size() < c.polygon.size():
				_warn_once("has a concave CollisionPolygon2D; the sweep uses its convex hull (hits may be larger than drawn)")
			out.append([cv, c.global_transform])
	return out

## Outline of a Rectangle / Circle / Convex shape, for drawing and the slash.
static func shape_outline(shape: Shape2D) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if shape is RectangleShape2D:
		var h: Vector2 = shape.size * 0.5
		pts = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	elif shape is CircleShape2D:
		for i in 16:
			pts.append(Vector2.from_angle(TAU * i / 16.0) * shape.radius)
	elif shape is ConvexPolygonShape2D:
		pts = shape.points
	return pts

var _warned := false
func _warn_once(msg: String) -> void:
	if not _warned:
		_warned = true
		push_warning("Hitbox %s: %s" % [get_path(), msg])

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
	if target.has_method("take_gather_hit"):
		target.take_gather_hit(weapon, owner)
		return
	var health := hurtbox.get_health()
	if health:
		health.take_damage(weapon.damage, owner, weapon.parryable, &"melee")
