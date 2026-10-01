extends CanvasLayer
## F1 toggle (on by default), F2 slow-mo. Draws hurtbox/hitbox outlines, weapon-state
## tint reference, and top-left timing text.

@export var player_path: NodePath
@export var dummy_path: NodePath
@export var boss_path: NodePath

@export var enabled := true  ## exported so the F3 tuning panel can reflect it
var last_damage := 0.0
var weapon_state := "idle"

## Fading hit markers for freed arrows: {"pos": Vector2, "t": float}. An arrow
## queue_frees the instant it hits, so this is the only way to still show
## where it landed for a moment.
var _hit_marks: Array = []
var _known_projectiles := {}   ## instance_id -> last seen global_position
const HIT_MARK_TIME := 0.25

@onready var _player: CharacterBody2D = get_node(player_path)
@onready var _dummy: Node2D = get_node_or_null(dummy_path)
@onready var _boss: Boss = get_node_or_null(boss_path) as Boss
@onready var _draw_layer: Node2D = $DrawLayer
@onready var _label: Label = $Label

func _ready() -> void:
	_draw_layer.draw.connect(_on_draw)
	(_player.get_node("WeaponHolder") as WeaponHolder).state_changed.connect(_on_weapon_state_changed)
	var guard: Guard = _player.get_node_or_null("Guard")
	if guard:
		guard.state_changed.connect(func(_s: String): _update_label())
	# Every hurtbox in the scene, not one hardcoded dummy.
	for hurtbox in get_tree().get_nodes_in_group("hurtbox"):
		var health := (hurtbox as Hurtbox).get_health()
		if health and not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)
	_update_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_hitboxes"):
		enabled = not enabled
		_update_label()
	elif event.is_action_pressed("debug_slowmo"):
		Engine.time_scale = 0.25 if Engine.time_scale == 1.0 else 1.0

func _process(delta: float) -> void:
	_track_projectiles()
	for mark in _hit_marks.duplicate():
		mark["t"] -= delta
		if mark["t"] <= 0.0:
			_hit_marks.erase(mark)
	_draw_layer.queue_redraw()
	_update_label()   # the swap-cast countdown needs a live tick, not just on-event

## Polls the "projectile" group (see projectile.gd) each frame: records where
## each live arrow currently is, and drops a fading mark wherever one was last
## seen the instant it disappears (it queue_frees itself on the same frame it
## hits, so there is no "on hit" moment to hook otherwise).
func _track_projectiles() -> void:
	var alive := {}
	for p in get_tree().get_nodes_in_group("projectile"):
		alive[p.get_instance_id()] = p.global_position
	for id in _known_projectiles.keys():
		if not alive.has(id):
			_hit_marks.append({"pos": _known_projectiles[id], "t": HIT_MARK_TIME})
	_known_projectiles = alive

func _on_weapon_state_changed(state: String) -> void:
	weapon_state = state
	_update_label()

func _on_damaged(amount: float) -> void:
	last_damage = amount
	_update_label()

func _update_label() -> void:
	if not enabled:
		_label.text = ""
		return
	var guard: Guard = _player.get_node_or_null("Guard")
	var guard_state: String = Guard.State.keys()[guard.state].to_lower() if guard else "n/a"
	var tank_text: String = "%.0f/%.0f" % [guard.tank, guard.tank_max] if guard else "n/a"
	var loadout: Loadout = _player.get_node_or_null("Loadout")
	var swap_text := ""
	if loadout and loadout.is_casting():
		swap_text = "\nswapping: %.2fs" % loadout.cast_left()
	_label.text = "weapon: %s\nlast damage: %.1f\nguard: %s  tank: %s%s" % [weapon_state, last_damage, guard_state, tank_text, swap_text]

func _on_draw() -> void:
	if not enabled:
		return
	var weapon_holder: WeaponHolder = _player.get_node("WeaponHolder")

	# Hurtboxes: green outline.
	for hurtbox in get_tree().get_nodes_in_group("hurtbox"):
		_draw_hurtbox_outline(hurtbox)

	# Hitbox: red outline of its ACTUAL shape at its ACTUAL transform, only
	# while active. The shape IS the hit area (decision 0011) — this is the
	# only honest picture of what can currently hit, no separate reach/arc math.
	# Two different things, both needed to understand a swing:
	#   WHITE  = the whole area the swing can reach (arc_degrees + radius),
	#            shown through windup AND active so it is actually visible.
	#   RED    = the wedge that is dangerous RIGHT NOW, which travels with the
	#            blade. Only alive for `active` (0.1s), far too brief on its own.
	if weapon_holder.phase != WeaponHolder.Phase.IDLE:
		_draw_swing_range(weapon_holder)
	# A ranged weapon's reach, drawn all the time it is held (the sword's wedge
	# only shows mid-swing, but a bow's range matters BEFORE you shoot).
	_draw_projectile_range(weapon_holder)
	_draw_skill_reach(weapon_holder)
	for hb in get_tree().get_nodes_in_group("hitbox"):
		if (hb as Hitbox).is_active():
			for pose in (hb as Hitbox).sweep_poses:   # the arc a snapping swing covered
				_draw_shape(pose[0], pose[1], Color(1.0, 0.3, 0.3, 0.3), 1.0)
			_draw_hitbox_outline(hb)

	# Player i-frames: blue outline for the dodge window's whole duration.
	var dodge: Dodge = _player.get_node_or_null("Dodge")
	if dodge and dodge.iframes_active():
		var body_cs := _player.get_node("CollisionShape2D") as CollisionShape2D
		var body_shape := body_cs.shape as CircleShape2D
		if body_shape:
			_draw_ground_circle(_player.global_position, body_shape.radius, Color.BLUE, 3.0)

	# Arrows: a cyan line from where each live one was fired to where it is
	# now, plus a brief mark wherever one just vanished (hit or out of range).
	for p in get_tree().get_nodes_in_group("projectile"):
		_draw_layer.draw_line(p.spawn_pos, p.global_position, Color(0.3, 0.9, 1.0, 0.7), 1.5)
	for mark in _hit_marks:
		var a: float = mark["t"] / HIT_MARK_TIME
		_draw_layer.draw_circle(mark["pos"], 6.0, Color(1.0, 0.9, 0.2, a))

	# Guard arc: NOT drawn here. The in-game CoverArc already shows the exact
	# protected side (width mirrored from Guard, turns with the aim), so a second
	# arc here only doubled it on screen. Guard state + tank are in the label.

	# Boss: warning areas of the attack in progress (orange = parry, purple =
	# dodge; the charge lane included) and the FightZone (red once enraged).
	# Active hitboxes are already red via the "hitbox" group above.
	for atk in get_tree().get_nodes_in_group("boss_attack"):
		for area in (atk as BossAttack).debug_areas():
			_draw_shape(area["shape"], area["xform"], area["color"], 2.0)
	if _boss and _boss.get_fight_zone():
		var zcs := _boss.get_fight_zone().get_node_or_null("CollisionShape2D") as CollisionShape2D
		if zcs:
			_draw_shape(zcs.shape, zcs.global_transform, Color.RED if _boss.enraged else Color(0.3, 0.8, 1.0), 2.0)

	# Map rocks: their collision circles (the only part of the map that blocks).
	for rock in get_tree().get_nodes_in_group("map_obstacle"):
		var rcs := rock.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if rcs and rcs.shape:
			_draw_shape(rcs.shape, rcs.global_transform, Color(1.0, 0.8, 0.2), 2.0)

	# Enemy strike: hitbox red only while STRIKE, telegraph area outlined
	# while TELEGRAPH (redundant with Telegraph's own border — cheap, and
	# consistent with the debug overlay drawing every other timing state).
	if _dummy:
		var attacker: Attacker = _dummy.get_node_or_null("Attacker")
		var enemy_hitbox: Hitbox = _dummy.get_node_or_null("Hitbox")
		if attacker and enemy_hitbox:
			if attacker.phase == Attacker.Phase.STRIKE:
				_draw_hitbox_outline(enemy_hitbox)
			elif attacker.phase == Attacker.Phase.TELEGRAPH:
				var cs := enemy_hitbox.get_node("CollisionShape2D") as CollisionShape2D
				var shape := cs.shape as CircleShape2D
				if shape:
					var outline_color := Color.ORANGE if attacker.parryable else Color.PURPLE
					_draw_ground_circle(cs.global_position, shape.radius, outline_color, 2.0)

func _draw_hurtbox_outline(hurtbox: Hurtbox) -> void:
	var cs := hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var shape := cs.shape as CircleShape2D
	if shape:
		_draw_ground_circle(cs.global_position, shape.radius, Color.GREEN, 2.0)

## Draws the Hitbox's own shape, rotated and positioned exactly as it sits in
## the world. Supports hand-authored shapes (CollisionShape2D: Rectangle or
## Capsule) AND a generated sector (CollisionPolygon2D, decision 0011
## amendment) — whichever child the Hitbox actually has is the real hit area,
## so this is the only honest picture of what can currently hit.
## The full sweep this swing covers. Both numbers are DERIVED, never typed:
##   span   = weapon.arc_degrees, centred on the aim (-arc/2 .. +arc/2)
##   reach  = how far the hitbox shape actually extends
## So the outline can never promise reach the box does not have.
## Dim line from the Muzzle along the aim, exactly projectile_range long: where
## an arrow can reach if nothing stops it. Nothing drawn for melee weapons.
func _draw_projectile_range(weapon_holder: WeaponHolder) -> void:
	var weapon: WeaponData = weapon_holder.weapon
	if weapon == null or weapon.behavior != "projectile":
		return
	var muzzle := weapon_holder.get_muzzle()
	if muzzle == null:
		return
	var from: Vector2 = muzzle.global_position
	var to: Vector2 = from + weapon_holder.aim_direction.normalized() * weapon.projectile_range
	_draw_layer.draw_line(from, to, Color(1, 1, 1, 0.25), 1.0)
	_draw_layer.draw_circle(to, 3.0, Color(1, 1, 1, 0.5))

## Orange line for the equipped weapon's E skill reach (lunge distance / piercing
## shot range), asked of the skill itself so a new skill needs no change here.
func _draw_skill_reach(weapon_holder: WeaponHolder) -> void:
	var slot: SkillSlot = _player.get_node_or_null("SkillSlot")
	if slot == null:
		return
	var s := slot.skill_for(weapon_holder.weapon)
	if s == null:
		return
	var pts := s.debug_reach(_player, weapon_holder.aim_direction)
	if pts.size() < 2:
		return
	var col := Color(1.0, 0.6, 0.1, 0.9 if slot.is_active() else 0.45)
	_draw_layer.draw_line(pts[0], pts[1], col, 2.0)
	_draw_layer.draw_circle(pts[1], 4.0, col)

func _draw_swing_range(weapon_holder: WeaponHolder) -> void:
	var weapon: WeaponData = weapon_holder.weapon
	if weapon == null:
		return
	var pivot := _player.get_node_or_null("WeaponVisual") as Node2D
	if pivot == null:
		return
	var reach := _hitbox_reach(weapon_holder.hitbox)
	if reach <= 0.0:
		return
	var poly := SectorShape.build_sector_polygon(weapon.arc_degrees, reach, 0.0, 20)
	var xform := pivot.global_transform
	var points := PackedVector2Array()
	for p in poly:
		points.append(xform * p)
	points.append(points[0])
	_draw_layer.draw_polyline(points, Color(1, 1, 1, 0.55), 1.5)

	# The AIM LINE: straight from the hand to the cursor. The swing is centred on
	# it — the blade starts half the arc on one side and finishes half on the
	# other, crossing this line in the middle of the swing.
	var origin: Vector2 = xform.origin
	var tip: Vector2 = xform * Vector2(reach * 1.15, 0.0)
	_draw_layer.draw_line(origin, tip, Color(1, 0.9, 0.2, 0.9), 1.5)
	_draw_layer.draw_circle(origin, 3.0, Color(1, 0.9, 0.2, 0.9))

	# The two edges of the swing: where it starts and where it ends.
	var half := deg_to_rad(weapon.arc_degrees) * 0.5
	for edge in [-half, half]:
		_draw_layer.draw_line(origin, xform * (Vector2.RIGHT.rotated(edge) * reach), Color(1, 1, 1, 0.35), 1.0)

## Furthest point of the hitbox's shape from the swing pivot. This is the
## weapon's reach — increase it by making the BOX bigger, not by typing a number.
func _hitbox_reach(hitbox: Hitbox) -> float:
	if hitbox == null:
		return 0.0
	var best := 0.0
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.shape is RectangleShape2D:
				var half: Vector2 = (cs.shape as RectangleShape2D).size / 2.0
				for corner in [Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
						Vector2(half.x, half.y), Vector2(-half.x, half.y)]:
					best = maxf(best, (cs.position + corner.rotated(cs.rotation)).length())
			elif cs.shape is CircleShape2D:
				best = maxf(best, cs.position.length() + (cs.shape as CircleShape2D).radius)
			elif cs.shape is CapsuleShape2D:
				var cap := cs.shape as CapsuleShape2D
				best = maxf(best, cs.position.length() + cap.height * 0.5)
		elif child is CollisionPolygon2D:
			for p in (child as CollisionPolygon2D).polygon:
				best = maxf(best, ((child as Node2D).position + p).length())
	return best

func _draw_hitbox_outline(hitbox: Hitbox) -> void:
	for child in hitbox.get_children():
		if child is CollisionPolygon2D:
			_draw_collision_polygon_outline(child)
			return
		elif child is CollisionShape2D:
			_draw_collision_shape_outline(child)
			return

func _draw_collision_polygon_outline(cp: CollisionPolygon2D) -> void:
	if cp.polygon.is_empty():
		return
	var xform := cp.global_transform
	var points := PackedVector2Array()
	for p in cp.polygon:
		points.append(xform * p)
	points.append(points[0])
	_draw_layer.draw_polyline(points, Color.RED, 2.0)

func _draw_collision_shape_outline(cs: CollisionShape2D) -> void:
	if cs.shape == null:
		return
	if cs.shape is CircleShape2D:
		_draw_shape(cs.shape, cs.global_transform, Color.RED, 2.0)
		return
	var xform := cs.global_transform
	var points := PackedVector2Array()
	if cs.shape is RectangleShape2D:
		var half: Vector2 = (cs.shape as RectangleShape2D).size / 2.0
		points = PackedVector2Array([
			Vector2(-half.x, -half.y), Vector2(half.x, -half.y),
			Vector2(half.x, half.y), Vector2(-half.x, half.y), Vector2(-half.x, -half.y),
		])
	elif cs.shape is CapsuleShape2D:
		var capsule := cs.shape as CapsuleShape2D
		var r: float = capsule.radius
		var h: float = capsule.height / 2.0 - r
		var steps := 12
		for i in steps + 1:
			points.append(Vector2(0, -h) + Vector2.RIGHT.rotated(lerpf(-PI / 2.0, PI / 2.0, float(i) / steps)) * r)
		for i in steps + 1:
			points.append(Vector2(0, h) + Vector2.RIGHT.rotated(lerpf(PI / 2.0, PI * 1.5, float(i) / steps)) * r)
		points.append(points[0])
	else:
		return
	for i in points.size():
		points[i] = xform * points[i]
	_draw_layer.draw_polyline(points, Color.RED, 2.0)

## Outline of a circle / rectangle / convex polygon at a transform.
func _draw_shape(shape: Shape2D, xform: Transform2D, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	if shape is CircleShape2D:
		var r: float = (shape as CircleShape2D).radius
		for i in 33:
			pts.append(Vector2.RIGHT.rotated(TAU * i / 32.0) * r)
	elif shape is RectangleShape2D:
		var h: Vector2 = (shape as RectangleShape2D).size / 2.0
		pts = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)])
	elif shape is ConvexPolygonShape2D:
		pts = (shape as ConvexPolygonShape2D).points
		pts.append(pts[0])
	else:
		return
	for i in pts.size():
		pts[i] = xform * pts[i]
	_draw_layer.draw_polyline(pts, color, width)

## Flat 2D circle. No perspective squashing — this game fakes depth only through
## draw order and upright sprites (decision 0009), never through projection.
func _draw_ground_circle(at: Vector2, radius: float, color: Color, width: float) -> void:
	_draw_layer.draw_arc(at, radius, 0, TAU, 28, color, width)
