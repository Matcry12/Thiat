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
## PIXEL LOOK: every effect is built from square blocks on a world grid
## (`pixel_size`), flat colours, hard edges (no antialiasing), and fades in
## discrete steps (bright -> dim -> dithered -> gone), never alpha tweens.
##
## Driven only by on_weapon_state() / set_weapon() / bind_model(), wired in
## player.gd. Reads the weapon's model (Hitbox for reach, Tip, Art), never writes
## into it. A model without a `Tip` Marker2D makes tip-based styles do nothing.

const STYLES := ["none", "slash", "trail", "afterimage", "particles"]

@export_enum("none", "slash", "trail", "afterimage", "particles") var style := "slash": set = _set_style

## Size of one effect "pixel" in world px. The sprites are drawn 1 texel = 1 px
## (sword 15x48, player 32x44), but 1 px effects turn into noise; 2 px reads as a
## chunky pixel next to them. Set 1.0 to match the sprites exactly.
@export var pixel_size := 2.0
## How many discrete frames an effect fades through (bright, dim, sparse, gone).
@export var fade_steps := 3

@export_group("Palette")
@export var pixel_core := Color(1.0, 1.0, 1.0)
@export var pixel_edge := Color(0.55, 0.82, 1.0)
@export var pixel_dim := Color(0.25, 0.4, 0.85)

@export_group("Slash")
@export var slash_step_time := 0.04       ## seconds per fade step
@export var slash_thickness := 26.0       ## px, at the fattest point of the crescent
@export var slash_peak := 0.65            ## 0..1 along the swing where it is fattest (late = "whip")

@export_group("Trail")
@export var trail_lifetime := 0.16        ## seconds a point of the ribbon lives (3 colour bands)

@export_group("Afterimage")
@export var afterimage_spacing := 26.0    ## px the tip must travel before the next copy
@export var afterimage_max := 4
@export var afterimage_step_time := 0.06  ## seconds per colour step

@export_group("Particles")
@export var spark_rate := 500.0           ## sparks per second while the blade is live
@export var spark_lifetime := 0.25
@export var spark_speed_min := 40.0
@export var spark_speed_max := 160.0
@export var spark_hot := Color(1.0, 1.0, 1.0)
@export var spark_mid := Color(1.0, 0.9, 0.3)
@export var spark_cool := Color(1.0, 0.5, 0.15)

const _FLAT_SHADER := "shader_type canvas_item;
uniform vec4 flat_color : source_color;
void fragment() { COLOR = vec4(flat_color.rgb, step(0.5, texture(TEXTURE, UV).a)); }"

## A set of square blocks in WORLD space (top_level). Fades by dropping blocks in
## an ordered-dither pattern and switching to one dim colour.
class Blocks extends Node2D:
	var px := 2.0
	var cells := PackedVector2Array()    ## top-left corner of each block
	var colors := PackedColorArray()
	var dim := Color.WHITE
	var step := 0
	var steps := 3
	func set_step(s: int) -> void:
		step = s
		queue_redraw()
	func _draw() -> void:
		for i in cells.size():
			var bayer := (floori(cells[i].x / px) & 1) + 2 * (floori(cells[i].y / px) & 1)
			if step > 0 and float(bayer) / 4.0 >= float(steps - step) / steps:
				continue
			draw_rect(Rect2(cells[i], Vector2.ONE * px), colors[i] if step == 0 else dim)

## Square sparks thrown off a moving tip; whole-pixel size, 3 flat colours by age.
class Sparks extends Node2D:
	var px := 2.0
	var tip: Node2D
	var emitting := true
	var rate := 500.0
	var life := 0.25
	var speed_min := 40.0
	var speed_max := 160.0
	var palette := PackedColorArray()    ## young -> old
	var _sparks: Array = []              ## [pos, vel, age, big]
	var _last := Vector2.INF
	var _owed := 0.0
	func _process(delta: float) -> void:
		if emitting and is_instance_valid(tip):
			var now := tip.global_position
			if _last == Vector2.INF:
				_last = now
			_owed += rate * delta
			while _owed >= 1.0:
				_owed -= 1.0
				_sparks.append([_last.lerp(now, randf()), Vector2.from_angle(randf() * TAU) * randf_range(speed_min, speed_max), 0.0, randf() < 0.5])
			_last = now
		for sp in _sparks:
			sp[0] += sp[1] * delta
			sp[1] *= 0.92
			sp[2] += delta
		_sparks = _sparks.filter(func(sp): return sp[2] < life)
		queue_redraw()
		if not emitting and _sparks.is_empty():
			queue_free()
	func _draw() -> void:
		for sp in _sparks:
			var band := mini(int(sp[2] / life * palette.size()), palette.size() - 1)
			var cell: float = px * (2.0 if (sp[3] and band == 0) else 1.0)   # big sparks shrink as they age
			draw_rect(Rect2((sp[0] / px).floor() * px, Vector2.ONE * cell), palette[band])

var _weapon: WeaponData
var _model: Node2D
var _active := false
var _trail: Blocks
var _trail_pts: Array[Vector2] = []
var _trail_ages: Array[float] = []
var _sparks: Sparks
var _ghosts := 0
var _last_ghost_tip := Vector2.ZERO
var _flat_shader: Shader

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_swing_fx"):
		style = STYLES[(STYLES.find(style) + 1) % STYLES.size()]

func status_text() -> String:
	return "style: %s  (F4 to switch)" % style

func _set_style(v: String) -> void:
	style = v
	_active = false
	_trail = null
	_trail_pts.clear()
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
		_sparks.emitting = false   # it frees itself once its last spark is gone
		_sparks = null

func _is_arc() -> bool:
	return _weapon != null and _weapon.behavior == "arc"

func _tip() -> Node2D:
	return _model.get_node_or_null("Tip") as Node2D if is_instance_valid(_model) else null

func _snap(p: Vector2) -> Vector2:
	return (p / pixel_size).floor() * pixel_size

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

func _new_blocks() -> Blocks:
	var b := Blocks.new()
	b.top_level = true
	b.px = pixel_size
	b.dim = pixel_dim
	b.steps = fade_steps
	add_child(b)
	return b

## Steps a Blocks node through its fade, then frees it.
func _fade_out(b: Node, step_time: float) -> void:
	var tw := b.create_tween()
	for s in range(1, fade_steps):
		tw.tween_interval(step_time)
		tw.tween_callback(b.set_step.bind(s))
	tw.tween_interval(step_time)
	tw.tween_callback(b.queue_free)

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
			_trail_pts.pop_front()
		if _active and tip:
			_trail_pts.append(tip.global_position)
			_trail_ages.append(0.0)
		_rebuild_trail()
		if not _active and _trail_ages.is_empty():
			_trail.queue_free()
			_trail = null
	if _active and tip and style == "afterimage" and _ghosts < afterimage_max \
			and tip.global_position.distance_to(_last_ghost_tip) >= afterimage_spacing:
		_spawn_ghost(tip.global_position)

# --- slash: a crescent rasterised into pixel blocks -------------------------
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
		outer.append(global_transform * (dir * reach))
		inner.append(global_transform * (dir * (reach - slash_thickness * sin(PI * pow(t, k)))))
	inner.reverse()
	var poly := outer + inner
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var inside := {}
	var x0 := floori(box.position.x / pixel_size)
	var y0 := floori(box.position.y / pixel_size)
	for cx in range(x0, ceili(box.end.x / pixel_size) + 1):
		for cy in range(y0, ceili(box.end.y / pixel_size) + 1):
			if Geometry2D.is_point_in_polygon((Vector2(cx, cy) + Vector2(0.5, 0.5)) * pixel_size, poly):
				inside[Vector2i(cx, cy)] = true
	var b := _new_blocks()
	b.name = "Slash"
	for c in inside:
		var rim := false
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			rim = rim or not inside.has(c + d)
		b.cells.append(Vector2(c) * pixel_size)
		b.colors.append(pixel_edge if rim else pixel_core)   # white core, light-blue rim
	b.queue_redraw()
	_fade_out(b, slash_step_time)

# --- trail: a blocky ribbon in 3 colour bands (white -> blue -> dark blue) ---
func _spawn_trail() -> void:
	if _trail == null:
		_trail = _new_blocks()

func _rebuild_trail() -> void:
	var grid := {}
	var bands := [pixel_core, pixel_edge, pixel_dim]
	for i in range(1, _trail_pts.size()):
		var age := _trail_ages[i] / trail_lifetime
		var band := 0 if age < 0.34 else (1 if age < 0.67 else 2)
		var n := 4 - band                     # brush width in blocks: 4, 3, 2
		var a := _trail_pts[i - 1]
		var b := _trail_pts[i]
		var count := maxi(1, ceili(a.distance_to(b) / (pixel_size * 0.5)))
		for j in count + 1:
			var p := a.lerp(b, float(j) / count)
			var c := Vector2i(floori(p.x / pixel_size), floori(p.y / pixel_size)) - Vector2i.ONE * (n / 2)
			for dx in n:
				for dy in n:
					grid[c + Vector2i(dx, dy)] = bands[band]
	_trail.cells.clear()
	_trail.colors.clear()
	for c in grid:
		_trail.cells.append(Vector2(c) * pixel_size)
		_trail.colors.append(grid[c])
	_trail.queue_redraw()

# --- afterimage: flat-colour silhouettes of the sword, changed in steps ------
func _spawn_ghost(tip_pos: Vector2) -> void:
	var art := _model.get_node_or_null("Art") as Sprite2D
	if art == null:
		return
	_ghosts += 1
	_last_ghost_tip = tip_pos
	if _flat_shader == null:
		_flat_shader = Shader.new()
		_flat_shader.code = _FLAT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _flat_shader
	var g := Sprite2D.new()
	g.texture = art.texture
	g.centered = art.centered
	g.offset = art.offset
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.material = mat
	g.top_level = true
	g.show_behind_parent = true    # behind the real sword
	add_child(g)
	g.global_transform = art.global_transform
	g.global_position = _snap(g.global_position)
	var colors := [pixel_edge, pixel_dim, pixel_dim.darkened(0.45)]
	mat.set_shader_parameter("flat_color", colors[0])
	var tw := g.create_tween()
	for s in range(1, fade_steps):
		tw.tween_interval(afterimage_step_time)
		tw.tween_callback(mat.set_shader_parameter.bind("flat_color", colors[mini(s, 2)]))
	tw.tween_interval(afterimage_step_time)
	tw.tween_callback(g.queue_free)

# --- particles: square sparks thrown off the tip -----------------------------
func _spawn_sparks() -> void:
	var p := Sparks.new()
	p.top_level = true
	p.px = pixel_size
	p.tip = _tip()
	p.rate = spark_rate
	p.life = spark_lifetime
	p.speed_min = spark_speed_min
	p.speed_max = spark_speed_max
	p.palette = PackedColorArray([spark_hot, spark_mid, spark_cool])
	add_child(p)
	_sparks = p
