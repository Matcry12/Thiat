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

## Side of this swing (SwingMotion weapons): written by WeaponHolder, the one owner of it. Never read from the picture.
var swing_flip := 1.0

var _active := false
var _sweep_t := -1.0   ## progressive sweep: the last t (0..1 through active) already tried; -1 = none yet
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
	_sweep_t = -1.0
	_active = true

func end_swing() -> void:
	_active = false
	sweep_poses.clear()

## Called by WeaponHolder right after start_swing() for a snapping arc weapon
## (enemy Attackers never call it). Hits everything the shape passes through
## between -arc/2 and +arc/2. See arc_poses() for the geometry.
func sweep_arc() -> void:
	if weapon and weapon.swing_motion:
		sweep_poses = motion_poses(0.0, 1.0, weapon.sweep_samples)   # the whole blade path at once (snap)
		_query(sweep_poses)
		return
	sweep_poses = arc_poses(weapon.sweep_samples if weapon else 0)
	_query(sweep_poses)

## Progressive sweep (WeaponData.hit_follows_blade): tries the poses between the last call's t and `t` (0..1 through active).
## Called by WeaponHolder every physics frame of active, first with 0.0 and last with 1.0, so there are no gaps however fast the blade is.
func advance_sweep(t: float) -> void:
	if not _active or weapon == null or weapon.swing_motion == null:
		return
	var poses := motion_poses(_sweep_t if _sweep_t >= 0.0 else t, t, weapon.sweep_samples)
	_sweep_t = t
	sweep_poses.append_array(poses)
	_query(poses)

func _query(poses: Array) -> void:
	if poses.is_empty():
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var space := get_world_2d().direct_space_state
	for pose in poses:
		query.shape = pose[0]
		query.transform = pose[1]
		for r in space.intersect_shape(query, 32):
			if r.collider is Area2D:
				_try_hit(r.collider)

## SwingMotion weapons (0050): [shape, global transform] with the hit shape placed on the BLADE along the active path from t0 to t1
## (0..1), `samples` per full path (at least 1). Same function the picture uses (SwingMotion.swing_path), so what you see is what hits.
## The shape's pose is read RELATIVE TO THE MODEL ORIGIN (the grip) and put at the sampled grip + blade angle in the aim frame, plus the motion's
## screen_offset converted to that frame. Limit: the hit path uses the grip positions of visual_scale 1; hitboxes are never scaled by the rig.
func motion_poses(t0: float, t1: float, samples: int) -> Array:
	var out := []
	var m := weapon.swing_motion if weapon else null
	if m == null:
		return out
	var pivot := _swing_pivot()
	if pivot == null:
		return out
	var aim_node := pivot.get_parent() as Node2D
	var aim_frame: Transform2D = aim_node.global_transform
	var half := weapon.arc_degrees * 0.5
	var n := maxi(1, ceili(absf(t1 - t0) * samples) + 1) if t1 > t0 else 1
	for sh in _shapes():
		var rel: Transform2D = pivot.global_transform.affine_inverse() * sh[1]
		for i in n:
			var t := t1 if n == 1 else lerpf(t0, t1, float(i) / (n - 1))
			var sp: Array = m.swing_path(t, half, swing_flip)
			var off: Vector2 = aim_frame.affine_inverse().basis_xform(m.screen_shift(aim_frame, sp[1]))
			out.append([sh[0], aim_frame * Transform2D(deg_to_rad(sp[1]), sp[0] + off) * rel])
	return out

## The SwingPivot two levels up (Hitbox -> model -> SwingPivot -> aim node), or null with a warning.
func _swing_pivot() -> Node2D:
	var pivot := get_parent().get_parent() as Node2D if get_parent() and get_parent().get_parent() else null
	if pivot == null or pivot.name != &"SwingPivot" or not pivot.get_parent() is Node2D:
		_warn_once("needs the layout Hitbox -> model -> SwingPivot -> aim node; the arc sweep is off")
		return null
	return pivot

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
	var pivot := _swing_pivot()
	if pivot == null:
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

## Tool target hit (WeaponHolder picks the node): one gather hit, counted in this swing so the blade cannot hit it again.
func hit_gather_target(node: ResourceNode) -> void:
	if not _active or weapon == null or node in _hit_this_swing:
		return
	_hit_this_swing.append(node)
	node.take_gather_hit(weapon, owner)

func _physics_process(_delta: float) -> void:
	if not _active or weapon == null or weapon.swing_motion != null:   # a SwingMotion weapon hits ONLY through the sweep (0050), not the old pivot shape
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
		health.take_damage(weapon.damage, owner, weapon.parryable, &"melee", weapon)
