extends Node2D
class_name SwingFx
## The sword's slash: a pixel-art crescent that appears on the SAME frame the
## blade snaps to the end of its arc (see WeaponVisual.snap_time) and covers the
## whole path it "travelled", then fades in discrete steps.
##
## Child of WeaponVisual, so the slash inherits the aim rotation AND the
## left-aim mirror (scale.y = -1) for free: it turns with the swing, like the
## hitbox does. Its blocks are `top_level` (world space) so they stay where the
## swing happened while the player keeps moving.
##
## PIXEL LOOK: square blocks on a world grid (`pixel_size`), flat colours, hard
## edges, fades in steps (bright -> dim -> dithered -> gone), never alpha tweens.
##
## Driven only by on_weapon_state() / set_weapon() / bind_model(), wired in
## player.gd. Reads the weapon's model (Hitbox for reach), never writes into it.

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
@export var slash_samples := 48           ## poses merged into the crescent (smooth edge; the hit uses WeaponData.sweep_samples)

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

var _weapon: WeaponData
## Crescent scale about the grip (from the character's BodyRig). 1 = the real hitbox area; below 1 is smaller than the real reach.
var _slash_scale := 1.0

func set_slash_scale(v: float) -> void:
	_slash_scale = v
var _model: Node2D
var _active := false

func set_weapon(w: WeaponData) -> void:
	_weapon = w

func bind_model(model: Node2D) -> void:
	_model = model

func on_weapon_state(state: String) -> void:
	var now := state == "active" and _is_arc()
	if now == _active:
		return
	_active = now
	if now:
		_spawn_slash()

func _is_arc() -> bool:
	return _weapon != null and _weapon.behavior == "arc"

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

## The crescent IS the hit area: the hitbox's own shape, merged over every
## angle of the arc (Hitbox.arc_poses), so what you see is what can hit.
func _spawn_slash() -> void:
	var hb := _model.get_node_or_null("Hitbox") as Hitbox if is_instance_valid(_model) else null
	if hb == null:
		return
	var solid: Array = []    # outer outlines of the merged area
	var holes: Array = []
	var merged: Array = []
	for pose in hb.arc_poses(slash_samples):
		var outline: PackedVector2Array = pose[1] * Hitbox.shape_outline(pose[0])
		if _slash_scale != 1.0 and is_instance_valid(_model) and _model.get_parent() is Node2D:
			var c: Vector2 = (_model.get_parent() as Node2D).global_position
			for i in outline.size():
				outline[i] = c + (outline[i] - c) * _slash_scale
		if outline.size() < 3:
			continue
		merged.append(outline)
	# Merge pairwise into one area (holes, if any, come back as clockwise polygons).
	var area: Array = []
	for outline in merged:
		if area.is_empty():
			area = [outline]
			continue
		var res := Geometry2D.merge_polygons(area[0], outline)
		if res.size() > 0:
			area = res
	for poly in area:
		(holes if Geometry2D.is_polygon_clockwise(poly) else solid).append(poly)
	if solid.is_empty():
		return
	var box := Rect2(solid[0][0], Vector2.ZERO)
	for poly in solid:
		for p in poly:
			box = box.expand(p)
	var inside := {}
	var x0 := floori(box.position.x / pixel_size)
	var y0 := floori(box.position.y / pixel_size)
	for cx in range(x0, ceili(box.end.x / pixel_size) + 1):
		for cy in range(y0, ceili(box.end.y / pixel_size) + 1):
			var pt := (Vector2(cx, cy) + Vector2(0.5, 0.5)) * pixel_size
			var hit := false
			for poly in solid:
				hit = hit or Geometry2D.is_point_in_polygon(pt, poly)
			for poly in holes:
				hit = hit and not Geometry2D.is_point_in_polygon(pt, poly)
			if hit:
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
