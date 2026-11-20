extends Node2D
class_name EatCrumbs
## Crumbs that fly off the food / potion while it is eaten. Own visual node: it only READS Consumer.is_eating() and the
## HeldItem picture (position, size, colours); no combat code reaches in. Tiny squares snapped to the body pixel grid.
## Swap-in note: a particle sprite replaces this node, same "reads Consumer + HeldItem" contract.

## All numbers and the optional crumb picture (data/food/eating.tres).
@export var eating: EatingData = preload("res://data/food/eating.tres")

class Crumb:
	var pos: Vector2
	var vel: Vector2
	var age := 0.0
	var color: Color

var _crumbs: Array[Crumb] = []
var _acc := 0.0
var _colors: Array[Color] = []
var _colors_tex: Texture2D
@onready var _consumer: Consumer = get_parent().get_node("Consumer")
@onready var _held: HeldItemVisual = get_parent().get_node("WeaponVisual/HeldItem")

func _ready() -> void:
	z_as_relative = false
	z_index = eating.z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
	if _consumer.is_eating() and _held.visible and _held.texture != null:
		_acc += delta
		while _acc >= eating.crumb_every:
			_acc -= eating.crumb_every
			for i in eating.crumb_count:
				_spawn()
	else:
		_acc = 0.0
	for c in _crumbs:
		c.age += delta
		c.vel.y += eating.gravity * delta
		c.pos += c.vel * delta
	_crumbs = _crumbs.filter(func(c: Crumb) -> bool: return c.age < eating.life)
	queue_redraw()

func _spawn() -> void:
	if _crumbs.size() >= eating.max_crumbs:
		return
	_refresh_colors()
	if _colors.is_empty():
		return
	var size := _held.texture.get_size() * _held.global_scale.abs()   # local scale.y is -1 when WeaponVisual mirrors (facing left)
	var c := Crumb.new()
	c.pos = _held.global_position + Vector2(randf_range(-size.x / 3.0, size.x / 3.0), size.y * eating.start_y_frac)
	c.vel = Vector2(randf_range(-eating.vel_x, eating.vel_x), randf_range(eating.vel_y_min, eating.vel_y_max))
	c.color = _colors[randi() % _colors.size()]
	_crumbs.append(c)

## Opaque pixel colours of the item's picture (rebuilt when the picture changes).
func _refresh_colors() -> void:
	if _held.texture == _colors_tex:
		return
	_colors_tex = _held.texture
	_colors.clear()
	var img := _colors_tex.get_image()
	if img == null:
		return
	for y in img.get_height():
		for x in img.get_width():
			var px := img.get_pixel(x, y)
			if px.a > 0.5:
				_colors.append(Color(px, 1.0))

func _draw() -> void:
	for c in _crumbs:
		var p := to_local(c.pos.snappedf(eating.crumb_px))
		var r := Rect2(p - Vector2.ONE * eating.crumb_px * 0.5, Vector2.ONE * eating.crumb_px)
		if eating.crumb_texture != null:   # art swap: the picture replaces the coloured square
			draw_texture_rect(eating.crumb_texture, r, false)
		else:
			draw_rect(r, c.color)

func debug_name() -> String:
	return "EatCrumbs"

func debug_category() -> String:
	return "Character"

func status_text() -> String:
	return "crumbs alive: %d  colours: %d" % [_crumbs.size(), _colors.size()]
