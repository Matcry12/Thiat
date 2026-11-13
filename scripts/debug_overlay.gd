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
	add_to_group("debug")
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
		var hs := get_tree().get_first_node_in_group("hit_stop") as HitStop
		if hs:
			hs.toggle_slowmo()   # HitStop owns time_scale while a hit-stop / kill slow-mo runs
		else:
			Engine.time_scale = 0.25 if Engine.time_scale == 1.0 else 1.0

func _process(delta: float) -> void:
	_track_projectiles()
	for mark in _hit_marks.duplicate():
		mark["t"] -= delta
		if mark["t"] <= 0.0:
			_hit_marks.erase(mark)
	# This is a CanvasLayer (screen space), but every shape is drawn in world coordinates: carry the
	# camera's transform so the shapes stay on the things they describe.
	_draw_layer.transform = get_viewport().get_canvas_transform()
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
	_label.text = "weapon: %s\nlast damage: %.1f\nguard: %s  tank: %s" % [weapon_state, last_damage, guard_state, tank_text]

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
		_draw_tool_target(weapon_holder)
	# A ranged weapon's reach, drawn all the time it is held (the sword's wedge
	# only shows mid-swing, but a bow's range matters BEFORE you shoot).
	_draw_projectile_range(weapon_holder)
	_draw_skill_reach(weapon_holder)
	_draw_picture_fit()
	_draw_lights()
	for hb in get_tree().get_nodes_in_group("hitbox"):
		if (hb as Hitbox).is_active():
			for pose in (hb as Hitbox).sweep_poses:   # the arc a snapping swing covered
				_draw_shape(pose[0], pose[1], Color(1.0, 0.3, 0.3, 0.3), 1.0)
			var hbx := hb as Hitbox
			if hbx.weapon != null and hbx.weapon.swing_motion != null:
				# 0050: the node's own shape sits on the old pivot and deals no damage; the last swept pose is the live hit area
				if not hbx.sweep_poses.is_empty():
					var lp: Array = hbx.sweep_poses[hbx.sweep_poses.size() - 1]
					_draw_shape(lp[0], lp[1], Color(1.0, 0.2, 0.2, 0.9), 2.0)
			else:
				_draw_hitbox_outline(hb)

	# Knockback: an orange line from where the body stood to where the shove sends it, for 0.6 s after a hit.
	for kb in get_tree().get_nodes_in_group("knockback"):
		if Time.get_ticks_msec() - kb.last_msec < 600:
			var tip: Vector2 = kb.last_origin + kb.last_vector
			_draw_layer.draw_line(kb.last_origin, tip, Color(1.0, 0.6, 0.1), 2.0)
			_draw_layer.draw_circle(tip, 3.0, Color(1.0, 0.6, 0.1))

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
	# dodge; the charge lane included) and the FightZone (red while engaged).
	# Active hitboxes are already red via the "hitbox" group above.
	for atk in get_tree().get_nodes_in_group("boss_attack"):
		for area in (atk as BossAttack).debug_areas():
			_draw_shape(area["shape"], area["xform"], area["color"], 2.0)
	if _boss and _boss.get_fight_zone():
		var zcs := _boss.get_fight_zone().get_node_or_null("CollisionShape2D") as CollisionShape2D
		if zcs:
			var zc := Color(0.3, 0.8, 1.0)   # idle
			if _boss.aggro == Boss.Aggro.ENGAGED:
				zc = Color.RED
			elif _boss.aggro == Boss.Aggro.RETURNING:
				zc = Color(0.55, 0.7, 0.85)
			_draw_shape(zcs.shape, zcs.global_transform, zc, 2.0)
			var top_left: Vector2 = zcs.global_position - (zcs.shape as RectangleShape2D).size * 0.5 if zcs.shape is RectangleShape2D else zcs.global_position
			_draw_layer.draw_string(ThemeDB.fallback_font, top_left + Vector2(8, 20), "AGGRO ZONE (%s)" % Boss.Aggro.keys()[_boss.aggro].to_lower(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, zc)
	if _boss:   # where it waits and walks back to
		_draw_layer.draw_arc(_boss.home, 10.0, 0.0, TAU, 16, Color(0.55, 0.7, 0.85), 2.0)

	# Map chunks (0038 step 2): a thin border round every loaded chunk. The world beyond them is data only.
	var arena_map := get_tree().get_first_node_in_group("arena_map") as ArenaMap
	if arena_map != null and arena_map.streamer() != null:
		for r in arena_map.streamer().loaded_rects():
			_draw_layer.draw_rect(r, Color(0.6, 0.75, 1.0, 0.45), false, 1.0)

	# Map rocks: their collision circles (the only part of the map that blocks).
	for rock in get_tree().get_nodes_in_group("map_obstacle"):
		var rcs := rock.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if rcs and rcs.shape:
			_draw_shape(rcs.shape, rcs.global_transform, Color(1.0, 0.8, 0.2), 2.0)
		var hcs := rock.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D   # gather target (layer 32)
		if hcs and hcs.shape:
			_draw_shape(hcs.shape, hcs.global_transform, Color(0.3, 1.0, 0.4, 0.6), 1.0)

	# Stations (decision 0031): craft radius (magenta; thicker when the player is inside), body and the pickup hurtbox.
	for cst: CraftStation in get_tree().get_nodes_in_group("craft_station"):
		var inside := _player != null and cst.reaches(_player.global_position)
		_draw_ground_circle(cst.world_pos(), cst.craft_radius, Color(1.0, 0.4, 0.9, 0.9 if inside else 0.5), 2.0 if inside else 1.0)
	for st: Station in get_tree().get_nodes_in_group("station"):
		var scs := st.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if scs and scs.shape:
			_draw_shape(scs.shape, scs.global_transform, Color(1.0, 0.8, 0.2), 2.0)
		var shcs := st.get_node_or_null("Hurtbox/CollisionShape2D") as CollisionShape2D
		if shcs and shcs.shape:
			_draw_shape(shcs.shape, shcs.global_transform, Color(0.3, 1.0, 0.4, 0.6), 1.0)

	# Gathering: the magnet (pulls drops in) and pickup (banks them) circles around the player.
	var col := get_tree().get_first_node_in_group("collector") as Collector
	if col and _player:
		_draw_ground_circle(_player.global_position, col.magnet_radius, Color(0.3, 0.9, 1.0, 0.7), 1.0)
		_draw_ground_circle(_player.global_position, col.pickup_radius, Color(0.3, 0.9, 1.0), 2.0)

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
## Weapon picture fit (0049): cross = the grip (model origin = where the hand holds it), dot = the blade tip (`Tip` marker).
## If the cross is not on the handle or the dot not on the blade end, the picture is misplaced in the model scene.
## Every LightSource's reach: orange circle (the light's own canvas is tinted by night, this layer is not).
func _draw_lights() -> void:
	for l: LightSource in get_tree().get_nodes_in_group("light_source"):
		_draw_layer.draw_circle(l.global_position, l.radius, Color(1.0, 0.5, 0.1, 0.9), false, 2.0)

func _draw_picture_fit() -> void:
	var wv := _player.get_node_or_null("WeaponVisual") as WeaponVisual
	if wv:   # the character's Hand point (the player's Hand marker): white X, apart from the cyan + grip cross
		var h := wv.hand_point()
		for dd in [Vector2(1, 1), Vector2(1, -1)]:
			_draw_layer.draw_line(h - dd * 4.5, h + dd * 4.5, Color.BLACK, 3.0)
		for dd in [Vector2(1, 1), Vector2(1, -1)]:
			_draw_layer.draw_line(h - dd * 4.0, h + dd * 4.0, Color.WHITE, 1.5)
	var d: Dictionary = wv.picture_grip_tip() if wv else {}
	if d.is_empty():
		return
	var g: Vector2 = d["grip"]
	var c := Color(0.2, 1.0, 1.0)
	_draw_layer.draw_line(g + Vector2(-5, 0), g + Vector2(5, 0), c, 1.5)
	_draw_layer.draw_line(g + Vector2(0, -5), g + Vector2(0, 5), c, 1.5)
	if d.has("off_grip"):
		var g2: Vector2 = d["off_grip"]
		_draw_layer.draw_line(g2 + Vector2(-5, 0), g2 + Vector2(5, 0), c, 1.5)
		_draw_layer.draw_line(g2 + Vector2(0, -5), g2 + Vector2(0, 5), c, 1.5)
	if d.has("tip"):
		_draw_layer.draw_circle(d["tip"], 3.0, Color(1.0, 0.3, 1.0))

func _draw_projectile_range(weapon_holder: WeaponHolder) -> void:
	var weapon: WeaponData = weapon_holder.weapon
	if weapon == null or weapon.behavior != "projectile":
		return
	var muzzle := weapon_holder.get_muzzle()
	if muzzle == null:
		return
	var from: Vector2 = weapon_holder.shot_start()
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
	var xform := pivot.global_transform
	if weapon.swing_motion != null:
		# 0050: the real swept area of the blade path (not the old wedge). Aim line only; the red hit shapes are drawn from sweep_poses.
		_draw_swept_outline(weapon_holder.hitbox)
		var o: Vector2 = xform.origin
		_draw_layer.draw_line(o, xform * Vector2(reach * 1.15, 0.0), Color(1, 0.9, 0.2, 0.9), 1.5)
		_draw_layer.draw_circle(o, 3.0, Color(1, 0.9, 0.2, 0.9))
		return
	var poly := SectorShape.build_sector_polygon(weapon.arc_degrees, reach, 0.0, 20)
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

## Tool target hit (WeaponData.tool_target_reach): orange reach ring + cone edges around the real aim, and a ring on the node that would get the hit.
func _draw_tool_target(wh: WeaponHolder) -> void:
	if wh.weapon == null or wh.weapon.tool_target_reach <= 0.0:
		return
	var c := Color(1.0, 0.55, 0.1, 0.8)
	var o := _player.global_position
	var half := deg_to_rad(wh.weapon.tool_target_cone_deg) * 0.5
	_draw_layer.draw_arc(o, wh.weapon.tool_target_reach, wh.aim_direction.angle() - half, wh.aim_direction.angle() + half, 20, Color(c, 0.4), 1.0)
	for e in [-half, half]:
		_draw_layer.draw_line(o, o + wh.aim_direction.rotated(e) * wh.weapon.tool_target_reach, Color(c, 0.4), 1.0)
	var t: ResourceNode = wh.tool_target if wh.phase != WeaponHolder.Phase.IDLE else wh.find_tool_target()
	if is_instance_valid(t):
		_draw_ground_circle(t.global_position, t.data.radius + t.data.hurtbox_pad + 3.0, c, 2.5)
		_draw_layer.draw_line(o, t.global_position, c, 1.0)

## White outline of everything the whole blade path can hit (SwingMotion weapons): the hit shape merged over the full active path.
func _draw_swept_outline(hitbox: Hitbox) -> void:
	var area: Array = []
	for pose in hitbox.motion_poses(0.0, 1.0, 48):
		var outline: PackedVector2Array = pose[1] * Hitbox.shape_outline(pose[0])
		if outline.size() < 3:
			continue
		if area.is_empty():
			area = [outline]
			continue
		var res := Geometry2D.merge_polygons(area[0], outline)
		if res.size() > 0:
			area = res
	for poly in area:
		var pts := PackedVector2Array(poly)
		pts.append(pts[0])
		_draw_layer.draw_polyline(pts, Color(1, 1, 1, 0.55), 1.5)

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


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Debug"

func debug_category() -> String:
	return "Misc"
