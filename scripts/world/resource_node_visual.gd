class_name ResourceNodeVisual
extends ActorVisual
## The look of a ResourceNode: a Body sprite (or a placeholder drawing when the data has no texture).
## Kinds with fade_when_behind fade when the player stands behind them so a tree never hides the player.

var _d: ResourceNodeData
var _player: Node2D

func flash_target() -> CanvasItem:
	return get_node("Body")

func show_variant(d: ResourceNodeData, v: int) -> void:
	_d = d
	var body: Sprite2D = get_node("Body")
	if d.texture == null or d.regions.is_empty():
		body.texture = null
		queue_redraw()
		return
	var all := d.all_regions()
	_set_region(body, all[v % all.size()], _d.anchor_for(v % all.size()))

func show_remains(d: ResourceNodeData) -> void:
	_set_region(get_node("Body"), d.remains_region, Vector2(d.remains_region.size.x * 0.5, d.remains_region.size.y))
	body_alpha(1.0)

func _set_region(body: Sprite2D, r: Rect2, foot: Vector2) -> void:
	body.texture = _d.texture
	body.region_enabled = true
	body.region_rect = r
	body.scale = Vector2.ONE * _d.pixel_scale
	# The foot point of the picture (bottom centre unless the data has an anchor) sits at the circle's bottom.
	body.offset = r.size * 0.5 - foot + Vector2(0, _d.radius / _d.pixel_scale)

func body_alpha(a: float) -> void:
	var m: Color = get_node("Body").modulate
	m.a = a
	get_node("Body").modulate = m

func _process(_delta: float) -> void:
	var body: Sprite2D = get_node("Body")
	if _d == null or body.texture == null or not _d.fade_when_behind or not body.region_enabled:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
	var rect := Rect2(global_position + body.offset * body.scale.y - body.region_rect.size * body.scale * 0.5 + Vector2(0, 0), body.region_rect.size * body.scale)
	var covers: bool = rect.has_point(_player.global_position) and _player.global_position.y < global_position.y
	body_alpha(_d.fade_alpha if covers else 1.0)

func _draw() -> void:
	if _d == null or (get_node("Body") as Sprite2D).texture != null:
		return
	if _d.fade_when_behind:   # tall kind: trunk + crown
		draw_rect(Rect2(-4, _d.radius - 22, 8, 22), Color(0.4, 0.27, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(-18, _d.radius - 18), Vector2(18, _d.radius - 18), Vector2(0, _d.radius - 60)]), _d.color)
	else:
		draw_circle(Vector2.ZERO, _d.radius, _d.color)
