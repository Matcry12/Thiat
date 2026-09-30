extends Node2D
class_name SwingFx
## ponytail: TEMPORARY DEMO. Four swing-effect styles to compare with F4; once
## the user picks one, the others (and this switch) get deleted.
##
## Child of WeaponVisual, so the slash inherits the aim rotation AND the
## left-aim mirror (scale.y = -1) for free: it turns with the swing, like the
## hitbox does. The trail / afterimages / sparks are `top_level` (world space)
## on purpose: they must stay where the blade WAS while the player keeps
## moving or turning; glued to the player they would drag along with him.
##
## Driven only by on_weapon_state() / set_weapon() / bind_model(), wired in
## player.gd. Reads the weapon's model (Hitbox for reach, Tip, Art), never writes
## into it. A model without a `Tip` Marker2D makes tip-based styles do nothing.

const STYLES := ["none", "slash", "trail", "afterimage", "particles"]

@export_enum("none", "slash", "trail", "afterimage", "particles") var style := "slash": set = _set_style

@export_group("Slash")
@export var slash_time := 0.12            ## seconds to fade out
@export var slash_thickness := 26.0       ## px, at the fattest point of the crescent
@export var slash_peak := 0.65            ## 0..1 along the swing where it is fattest (late = "whip")
@export var slash_color := Color(0.85, 0.95, 1.0, 0.9)

@export_group("Trail")
@export var trail_lifetime := 0.16        ## seconds a point of the ribbon lives
@export var trail_width := 14.0
@export var trail_color := Color(0.7, 0.9, 1.0, 1.0)

@export_group("Afterimage")
@export var afterimage_spacing := 26.0    ## px the tip must travel before the next copy
@export var afterimage_max := 4
@export var afterimage_fade := 0.18
@export var afterimage_color := Color(0.6, 0.85, 1.0, 0.75)

@export_group("Particles")
@export var spark_amount := 120
@export var spark_lifetime := 0.2
@export var spark_speed_min := 40.0
@export var spark_speed_max := 160.0
@export var spark_size := 7.0
@export var spark_color := Color(1.0, 0.9, 0.45, 1.0)

var _weapon: WeaponData
var _model: Node2D
var _active := false
var _trail: Line2D
var _trail_ages: Array[float] = []
var _sparks: CPUParticles2D
var _ghosts := 0
var _last_ghost_tip := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_swing_fx"):
		style = STYLES[(STYLES.find(style) + 1) % STYLES.size()]

func status_text() -> String:
	return "style: %s  (F4 to switch)" % style

func _set_style(v: String) -> void:
	style = v
	_active = false
	_trail = null
	_trail_ages.clear()
	_sparks = null
	for c in get_children():
		c.queue_free()

func set_weapon(w: WeaponData) -> void:
	_weapon = w

func bind_model(model: Node2D) -> void:
	_model = model
	if model and _is_arc() and _tip() == null:
		push_warning("SwingFx: %s has no Tip Marker2D - tip-based swing effects are off" % model.name)

func on_weapon_state(state: String) -> void:
	var now := state == "active" and _is_arc()
	if now == _active:
		return
	_active = now
	if now:
		_begin()
	elif _sparks:
		var s := _sparks
		_sparks = null
		s.emitting = false
		s.create_tween().tween_callback(s.queue_free).set_delay(s.lifetime + 0.05)

func _is_arc() -> bool:
	return _weapon != null and _weapon.behavior == "arc"

func _tip() -> Node2D:
	return _model.get_node_or_null("Tip") as Node2D if is_instance_valid(_model) else null

## Farthest point of the model's Hitbox from the hand: what you see = what you hit.
func _reach() -> float:
	var hb: Node = _model.get_node_or_null("Hitbox") if is_instance_valid(_model) else null
	var best := 0.0
	if hb == null:
		return best
	for c in hb.get_children():
		if c is CollisionShape2D and c.shape is RectangleShape2D:
			var h: Vector2 = c.shape.size * 0.5
			for corner in [Vector2(h.x, h.y), Vector2(h.x, -h.y), Vector2(-h.x, h.y), Vector2(-h.x, -h.y)]:
				best = maxf(best, (c.position + corner.rotated(c.rotation)).length())
		elif c is CollisionPolygon2D:
			for p in c.polygon:
				best = maxf(best, (c.position + p).length())
	return best

func _begin() -> void:
	match style:
		"slash": _spawn_slash()
		"trail": _spawn_trail()
		"afterimage":
			_ghosts = 0
			_last_ghost_tip = Vector2(INF, INF)   # first copy right away
		"particles": _spawn_sparks()

func _process(delta: float) -> void:
	var tip := _tip()
	if _trail:
		for i in _trail_ages.size():
			_trail_ages[i] += delta
		while not _trail_ages.is_empty() and _trail_ages[0] > trail_lifetime:
			_trail_ages.pop_front()
			_trail.remove_point(0)
		if _active and tip:
			_trail.add_point(tip.global_position)
			_trail_ages.append(0.0)
		if not _active and _trail_ages.is_empty():
			_trail.queue_free()
			_trail = null
	if _active and tip:
		if _sparks:
			_sparks.global_position = tip.global_position
		if style == "afterimage" and _ghosts < afterimage_max \
				and tip.global_position.distance_to(_last_ghost_tip) >= afterimage_spacing:
			_spawn_ghost(tip.global_position)

# --- slash: a crescent covering the swing arc, at the hitbox's reach --------
func _spawn_slash() -> void:
	var reach := _reach()
	if reach <= 0.0:
		return
	var half := deg_to_rad(_weapon.arc_degrees) * 0.5
	var k := log(0.5) / log(clampf(slash_peak, 0.05, 0.95))   # puts sin's crest at slash_peak
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var steps := 24
	for i in steps + 1:
		var t := float(i) / steps
		var dir := Vector2.RIGHT.rotated(lerpf(-half, half, t))
		outer.append(dir * reach)
		inner.append(dir * (reach - slash_thickness * sin(PI * pow(t, k))))
	inner.reverse()
	var s := Node2D.new()
	s.name = "Slash"
	add_child(s)
	s.draw.connect(func():
		s.draw_colored_polygon(outer + inner, slash_color)
		s.draw_polyline(outer, Color(1, 1, 1, slash_color.a), 2.0))
	s.queue_redraw()
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, slash_time)
	tw.tween_callback(s.queue_free)

# --- trail: ribbon behind the blade tip ------------------------------------
func _spawn_trail() -> void:
	if _trail:
		return
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = trail_width
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	# Point 0 is the OLDEST: transparent and thin; the newest is opaque and full width.
	var g := Gradient.new()
	g.set_color(0, Color(trail_color, 0.0))
	g.set_color(1, trail_color)
	_trail.gradient = g
	_trail.width_curve = Curve.new()
	_trail.width_curve.add_point(Vector2(0, 0.0))
	_trail.width_curve.add_point(Vector2(1, 1.0))
	add_child(_trail)

# --- afterimage: faded copies of the sword picture -------------------------
func _spawn_ghost(tip_pos: Vector2) -> void:
	var art := _model.get_node_or_null("Art") as Sprite2D
	if art == null:
		return
	_ghosts += 1
	_last_ghost_tip = tip_pos
	var g := Sprite2D.new()
	g.texture = art.texture
	g.centered = art.centered
	g.offset = art.offset
	g.top_level = true
	g.show_behind_parent = true    # behind the real sword
	g.modulate = afterimage_color
	add_child(g)
	g.global_transform = art.global_transform
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, afterimage_fade)
	tw.tween_callback(g.queue_free)

# --- particles: sparks thrown off the tip ----------------------------------
func _spawn_sparks() -> void:
	var p := CPUParticles2D.new()
	p.top_level = true
	p.amount = spark_amount
	p.lifetime = spark_lifetime
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = spark_speed_min
	p.initial_velocity_max = spark_speed_max
	p.scale_amount_min = spark_size * 0.6
	p.scale_amount_max = spark_size
	p.color = spark_color
	var fade := Gradient.new()
	fade.set_color(0, Color.WHITE)
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	add_child(p)
	var tip := _tip()
	if tip:
		p.global_position = tip.global_position
	p.emitting = true
	_sparks = p
