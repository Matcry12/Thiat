class_name SwingGhosts
extends Node2D
## Afterimages of the blade: the last few poses of the swing, drawn as fading copies (decision 0049).
## Child of WeaponVisual (inherits aim + left mirror). Driven only by bind_art() / record() from WeaponVisual;
## no combat code reaches in. Swap note: any node with the same two calls can replace this.

const SILHOUETTE := "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(1.0);\nuniform float amount = 1.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tCOLOR = vec4(mix(c.rgb, tint.rgb, amount), c.a) * vec4(1.0, 1.0, 1.0, COLOR.a);\n}\n"

var _motion: SwingMotion
var _src: Node2D
var _tip := Vector2.ZERO        ## blade end in the art's frame (model's Tip marker); ZERO = no smear
var _poses: Array[Transform2D] = []
var _live := Transform2D.IDENTITY
var _since := 0.0
var _mat: ShaderMaterial

func bind_art(art: Node2D, motion: SwingMotion, tip := Vector2.ZERO) -> void:
	if is_instance_valid(_src):
		_src.free()   # the template lives outside the tree
	_motion = motion
	_src = art
	_tip = tip
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = Shader.new()
		_mat.shader.code = SILHOUETTE
	if _src:
		for c in [_src] + _src.find_children("*", "CanvasItem"):
			(c as CanvasItem).material = _mat
	clear()

func _exit_tree() -> void:
	if is_instance_valid(_src):
		_src.free()
		_src = null

func clear() -> void:
	_poses.clear()
	for c in get_children():
		c.queue_free()

func count() -> int:
	return _poses.size()

## Called every frame. While `recording` a pose is kept every ghost_interval; afterwards the oldest fades away at the same pace.
func record(pose: Transform2D, recording: bool, dt: float) -> void:
	if _motion == null or _src == null:
		return
	_since += dt
	if _since >= _motion.ghost_interval:
		_since = 0.0
		if recording:
			_poses.append(pose)
		elif not _poses.is_empty():
			_poses.remove_at(0)
		while _poses.size() > _motion.ghost_count:
			_poses.remove_at(0)
	_live = pose
	_mat.set_shader_parameter("tint", _motion.ghost_color)
	_mat.set_shader_parameter("amount", _motion.ghost_white)
	_sync_nodes()
	queue_redraw()

## The smear (reference: a pixel-art slash): the area the blade swept between the kept poses, filled on a SCREEN-aligned
## pixel grid. Newest part = head colour, older = tail colour, outer rim = edge colour; the old end breaks up into
## falling pixel streaks (whole columns survive longer than single pixels). Slow part: one point-in-quad test per cell,
## only while a smear is alive (~1-2k cells).
func _draw() -> void:
	if _motion == null or not _motion.smear_on or _tip == Vector2.ZERO or _poses.is_empty():
		return
	var chain: Array[Transform2D] = _poses.duplicate()
	chain.append(_live)
	var g := global_transform
	var quads: Array[PackedVector2Array] = []
	var grips: Array[Vector2] = []
	var box := Rect2(g * (chain[0] * _tip), Vector2.ZERO)
	var inner := _tip * _motion.smear_inner
	for i in chain.size() - 1:
		var a := chain[i]
		var b := chain[i + 1]
		var q := PackedVector2Array([g * (a * inner), g * (a * _tip), g * (b * _tip), g * (b * inner)])
		quads.append(q)
		grips.append(g * b.origin)
		for p in q:
			box = box.expand(p)
	var px := maxf(1.0, _motion.smear_pixel)
	var reach := (g * (_live * _tip)).distance_to(g * _live.origin)
	var n := quads.size()
	var fall := _motion.smear_drip_px
	draw_set_transform_matrix(g.affine_inverse())   # draw in screen-aligned world px
	var x0 := floorf(box.position.x / px) * px
	var y0 := floorf(box.position.y / px) * px
	var y := y0
	while y <= box.end.y + fall:
		var x := x0
		while x <= box.end.x:
			var c := Vector2(x, y) + Vector2.ONE * px * 0.5
			var col_seed := _hash(x, 0.0)
			var drip := fall * col_seed   # a column's pixels may hang this far below the swept area (old end only)
			for i in range(n - 1, -1, -1):
				var age := 1.0 - float(i + 1) / n   # 0 = newest step
				var hit := Geometry2D.is_point_in_polygon(c, quads[i])
				var dripped := false
				if not hit and age > _motion.smear_dissolve_start and drip > 0.0:
					dripped = Geometry2D.is_point_in_polygon(c - Vector2(0, drip), quads[i])
				if not hit and not dripped:
					continue
				var k := clampf((age - _motion.smear_dissolve_start) / maxf(1.0 - _motion.smear_dissolve_start, 0.001), 0.0, 1.0)
				var keep := lerpf(_hash(x, y), col_seed, 0.6)
				if dripped:
					keep = col_seed * 0.9
				if keep < k:
					break
				var r := c.distance_to(grips[i]) / maxf(reach, 1.0)
				var colr := _motion.smear_color.lerp(_motion.smear_tail_color, age)
				if r > 1.0 - _motion.smear_edge or dripped:
					colr = _motion.smear_edge_color
				draw_rect(Rect2(x, y, px, px), colr)
				break
			x += px
		y += px
	draw_set_transform_matrix(Transform2D.IDENTITY)

static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)

func _sync_nodes() -> void:
	while get_child_count() < _poses.size():
		var holder := Node2D.new()
		holder.name = "Ghost"
		holder.add_child(_src.duplicate())
		add_child(holder)
	var n := _poses.size()
	for i in get_child_count():
		var h := get_child(i) as Node2D
		h.visible = i < n and _motion.ghost_copies_on
		if i < n:
			h.transform = _poses[i]
			h.modulate.a = lerpf(_motion.ghost_alpha_min, _motion.ghost_alpha_max, 1.0 if n < 2 else float(i) / (n - 1))
