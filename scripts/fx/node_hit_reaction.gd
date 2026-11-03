extends Node
class_name NodeHitReaction
## The tree's own reaction (child "Reaction" of its Visual): sways the Body picture from the foot and pops it.
## It only moves the Body's transform; the foot stays planted. HitFx tells it what to do via NodeReactionFx;
## gather code never calls it (CLAUDE.md §5). Swap the Body for an AnimatedSprite2D: replace this node, nothing else.

class Impulse:
	var age := 0.0
	var amp_deg := 0.0   ## signed: + leans right
	var freq := 4.5
	var damping := 5.5
	var attack := 0.03

## The picture node next to this one (a tree's "Body", a station's "Art").
@export var body_name: StringName = &"Body"
var _impulses: Array[Impulse] = []
var _settle := 0.7
var _base_scale := Vector2.ZERO
var _base_pos := Vector2.ZERO
var _skew := 0.0
var _pop_k := 0.0
var _pop_up := 0.1
var _pop_k_max := 0.1
var _pop_age := -1.0   ## < 0 = no pop running
var _pop_hold := 0.12
var _after_pop: Callable
static var _palette_cache := {}

func _ready() -> void:
	set_process(false)

func _body() -> Sprite2D:
	return get_parent().get_node_or_null(NodePath(body_name)) as Sprite2D

## The foot pixel the picture bends / grows around, in Visual coordinates. The owner (tree, rock, station) says where it is.
func _foot() -> Vector2:
	var o := get_parent().get_parent()
	return o.foot_local() if o and o.has_method("foot_local") else Vector2.ZERO

## Scale without the pop (the fade-behind test uses it so the pop cannot flicker the fade).
func rest_scale() -> Vector2:
	var b := _body()
	return _base_scale if _base_scale != Vector2.ZERO else (b.scale if b else Vector2.ONE)

func is_swaying() -> bool:
	return not _impulses.is_empty()

func is_popping() -> bool:
	return _pop_age >= 0.0

func current_skew() -> float:
	return _skew

func sway(amp_deg: float, freq: float, damping: float, attack: float, settle: float) -> void:
	var im := Impulse.new()
	im.amp_deg = amp_deg
	im.freq = freq
	im.damping = damping
	im.attack = attack
	_settle = settle
	_impulses.append(im)
	_start()

## Scale up by `k_max` over `up_time`, hold until `hold`, then hand over to the remains (or just relax if none).
func pop(k_max: float, up_time: float, hold: float) -> void:
	_pop_k_max = k_max
	_pop_up = maxf(up_time, 0.001)
	_pop_hold = hold
	_pop_age = 0.0
	_impulses.clear()   # the stump must never lean
	_skew = 0.0
	_start()

## ResourceNodeVisual.show_remains asks first: true = the pop shows the stump itself when it ends.
func defer_remains(cb: Callable) -> bool:
	if not is_popping():
		return false
	_after_pop = cb
	return true

func _start() -> void:
	var b := _body()
	if b == null:
		return
	if _base_scale == Vector2.ZERO:
		_base_scale = b.scale
		_base_pos = b.position
	set_process(true)

func _process(delta: float) -> void:
	var b := _body()
	if b == null:
		set_process(false)
		return
	var deg := 0.0
	for im in _impulses:
		im.age += delta
		var env := minf(1.0, im.age / maxf(im.attack, 0.001)) * exp(-im.damping * im.age)
		deg += im.amp_deg * env * cos(TAU * im.freq * im.age)
	_impulses = _impulses.filter(func(i: Impulse) -> bool: return i.age < _settle)
	_skew = deg_to_rad(deg)
	if _pop_age >= 0.0:
		_pop_age += delta
		_pop_k = _pop_k_max * (1.0 - pow(1.0 - clampf(_pop_age / _pop_up, 0.0, 1.0), 3.0))
		if _pop_age >= _pop_hold:
			_pop_age = -1.0
			_pop_k = 0.0
			_apply(b)
			if _after_pop.is_valid():
				_after_pop.call()
			_after_pop = Callable()
	if _impulses.is_empty() and _pop_age < 0.0:
		_skew = 0.0
		_apply(b)
		set_process(false)
		return
	_apply(b)

## Skew + scale about the foot: the foot pixel stays where it is, the top moves most.
func _apply(b: Sprite2D) -> void:
	var f := _foot()
	var k := 1.0 + _pop_k
	b.scale = _base_scale * k
	b.skew = _skew
	# new = foot + S * (old - foot), S = k * [[1, -sin s], [0, cos s]] (what Node2D scale + skew do)
	var d := _base_pos - f
	b.position = f + k * Vector2(d.x - sin(_skew) * d.y, cos(_skew) * d.y)

## Visible size of the picture in world px (crown placement).
func picture_size() -> Vector2:
	var b := _body()
	if b == null or b.texture == null:
		return Vector2(32, 48)
	return (b.region_rect.size if b.region_enabled else b.texture.get_size()) * b.scale

## The crown's main colours, sampled from the top of the picture (cached per texture + rect).
func crown_colors(min_brightness := 0.0) -> PackedColorArray:
	var b := _body()
	if b == null or b.texture == null:
		return PackedColorArray([Color(0.39, 0.67, 0.25)])
	var rect := b.region_rect if b.region_enabled else Rect2(Vector2.ZERO, b.texture.get_size())   # an AtlasTexture's image is already cut out
	var key := "%d_%s_%.2f" % [b.texture.get_instance_id(), rect, min_brightness]
	if _palette_cache.has(key):
		return _palette_cache[key]
	var out := PackedColorArray()
	var img := b.texture.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var r := rect
		var counts := {}
		var y := int(r.position.y)
		while y < int(r.position.y + r.size.y * 0.55):
			var x := int(r.position.x)
			while x < int(r.end.x):
				if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
					var c := img.get_pixel(x, y)
					if c.a > 0.9 and maxf(c.r, maxf(c.g, c.b)) >= min_brightness:   # skips the dark outline
						counts[c] = int(counts.get(c, 0)) + 1
				x += 3
			y += 3
		var keys := counts.keys()
		keys.sort_custom(func(a: Color, c: Color) -> bool: return counts[a] > counts[c])
		for i in mini(3, keys.size()):
			out.append(keys[i])
	if out.is_empty():
		out.append(Color(0.39, 0.67, 0.25))
	_palette_cache[key] = out
	return out
