extends Node2D
class_name DamageNumbers
## Pooled damage numbers: a label pops up at the victim, rises in a small arc, falls and fades.
## Quick hits on the same victim MERGE into one growing number (arrows must not pile up unreadably).
## Runs on game time (frozen by hit-stop). HitFx tells it what to show (CLAUDE.md §5).

class Num:
	var label: Label
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var age := 0.0
	var amount := 0.0
	var victim_id := 0
	var mergeable := false
	var size := 10

@export_range(4, 60) var max_numbers := 24
## Starting upward speed, sideways drift and gravity (px/s, px/s^2): together they make the arc.
@export_range(0.0, 200.0, 1, "or_greater", "or_less") var rise_speed := 70.0
@export_range(0.0, 100.0, 0.5, "or_greater", "or_less") var drift_speed := 22.0
@export_range(0.0, 600.0, 2, "or_greater", "or_less") var gravity := 220.0
@export_range(0.1, 2.0, 0.01, "or_greater", "or_less") var life := 0.7
## Number starts this many px above the victim's feet position.
@export_range(-80.0, 20.0, 0.5, "or_greater", "or_less") var offset_y := -30.0
## Random sideways start offset, px.
@export_range(0.0, 30.0, 0.1, "or_greater", "or_less") var scatter_x := 6.0
## Hits on the same victim within this many seconds merge into one number. 0 = never merge.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var merge_time := 0.3
@export_range(0, 8) var outline_size := 3
## The pop: starts this much bigger and settles in `pop_time` s.
@export_range(1.0, 3.0, 0.01, "or_greater", "or_less") var pop_scale := 1.5
@export_range(0.01, 0.5, 0.002, "or_greater", "or_less") var pop_time := 0.1
## The last part of `life` (0..1) spent fading out.
@export_range(0.01, 1.0) var fade_fraction := 0.35
## Outline opacity (colour stays black).
@export_range(0.0, 1.0) var outline_alpha := 0.9

var spawned_total := 0
var merged_total := 0
var _pool: Array[Num] = []

func _ready() -> void:
	z_index = 12

func pool_size() -> int:
	return _pool.size()

func live_count() -> int:
	var n := 0
	for e in _pool:
		if e.label.visible:
			n += 1
	return n

func _free_slot() -> Num:
	var oldest: Num = null
	for e in _pool:
		if not e.label.visible:
			return e
		if oldest == null or e.age > oldest.age:
			oldest = e
	if _pool.size() < max_numbers or oldest == null:
		var n := Num.new()
		n.label = Label.new()
		n.label.visible = false
		n.label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.label.add_theme_constant_override("outline_size", outline_size)
		n.label.add_theme_color_override("font_outline_color", Color(0, 0, 0, outline_alpha))
		add_child(n.label)
		_pool.append(n)
		return n
	return oldest   # full: reuse the one closest to fading away

## `text` empty = show `amount` (whole number). Returns nothing; sets the label up.
func pop(victim: Node2D, amount: float, text: String, size: int, color: Color) -> void:
	var vid := victim.get_instance_id()
	var anchor := victim.global_position + Vector2(0, offset_y)
	if text == "" and merge_time > 0.0:
		for e in _pool:
			if e.label.visible and e.mergeable and e.victim_id == vid and e.age < merge_time and e.label.modulate.to_html(false) == color.to_html(false):
				e.amount += amount
				e.size = maxi(e.size, size)
				e.age = 0.0
				e.vel = Vector2(e.vel.x, -rise_speed)
				_style(e, str(roundi(e.amount)), e.size, color)
				merged_total += 1
				return
	var n := _free_slot()
	n.pos = anchor + Vector2(randf_range(-scatter_x, scatter_x), 0)
	n.vel = Vector2(randf_range(-drift_speed, drift_speed), -rise_speed)
	n.age = 0.0
	n.amount = amount
	n.victim_id = vid
	n.mergeable = text == ""
	n.size = size
	_style(n, text if text != "" else str(roundi(amount)), size, color)
	n.label.visible = true
	spawned_total += 1

func _style(n: Num, text: String, size: int, color: Color) -> void:
	n.label.text = text
	n.label.add_theme_font_size_override("font_size", size)
	n.label.add_theme_constant_override("outline_size", outline_size)
	n.label.modulate = color
	n.label.reset_size()
	n.label.pivot_offset = n.label.size * 0.5

func _process(delta: float) -> void:
	for e in _pool:
		if not e.label.visible:
			continue
		e.age += delta
		if e.age >= life:
			e.label.visible = false
			continue
		e.vel.y += gravity * delta
		e.pos += e.vel * delta
		e.label.position = (e.pos - e.label.size * 0.5).round()
		var s := lerpf(pop_scale, 1.0, clampf(e.age / maxf(pop_time, 0.001), 0.0, 1.0))
		e.label.scale = Vector2(s, s)
		var a := clampf((life - e.age) / (life * fade_fraction), 0.0, 1.0)
		e.label.modulate.a = a
