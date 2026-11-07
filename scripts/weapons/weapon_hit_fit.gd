class_name WeaponHitFit
extends RefCounted
## Measures a weapon model's hit area from its own picture (decision 0061).
## Model space: origin = the grip, the blade runs along +x. Art's offset / rotation / scale (and region_rect / AtlasTexture) are honoured.
## The measure is taken at rig scale 1 (BodyRig.visual_scale never reaches the hit area, 0028).
## ponytail: assumes the blade runs along +x and the picture is not flipped / animated (no flip_h, hframes). Upgrade = per-model axis.

const SAMPLE_STEP := 0.5   ## px between samples in model space; measuring resolution only, not a feel number
static var _cache: Dictionary = {}   ## key (texture + Art transform + region) -> {tip, thick, cy}

## Raw measure of a model's Art: {tip: farthest visible x, thick: median blade thickness, cy: median centre line y}. {} = nothing to measure.
static func measure(art: Sprite2D, alpha_min := 0.5) -> Dictionary:
	if art == null or art.texture == null:
		return {}
	var key := [art.texture, art.transform, art.offset, art.region_enabled, art.region_rect, art.centered, alpha_min]
	if _cache.has(key):
		return _cache[key]
	var out := _scan(art, alpha_min)
	_cache[key] = out
	return out

static func _scan(art: Sprite2D, alpha_min: float) -> Dictionary:
	var tex := art.texture
	var src_rect := Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
	var img: Image
	var at := tex as AtlasTexture
	if at != null and at.atlas != null:
		img = at.atlas.get_image()
		src_rect = Rect2i(at.region)
	else:
		img = tex.get_image()
	if img == null or img.is_empty():
		return {}
	if img.is_compressed():
		img.decompress()
	if art.region_enabled:   # a region on top of the texture (or atlas region)
		src_rect = Rect2i(src_rect.position + Vector2i(art.region_rect.position), Vector2i(art.region_rect.size))
	src_rect = src_rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if src_rect.size.x <= 0 or src_rect.size.y <= 0:
		return {}
	var local_origin := art.offset + (-Vector2(src_rect.size) * 0.5 if art.centered else Vector2.ZERO)   # sprite-local position of the region's top-left
	var xf := art.transform
	var inv := xf.affine_inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in [Vector2.ZERO, Vector2(src_rect.size.x, 0), Vector2(0, src_rect.size.y), Vector2(src_rect.size)]:
		var p: Vector2 = xf * (local_origin + c)
		lo = lo.min(p)
		hi = hi.max(p)
	var tip := -INF   # farthest visible pixel CENTRE along +x (pixel centres, not corners)
	for py in src_rect.size.y:
		for px in src_rect.size.x:
			if img.get_pixel(px + src_rect.position.x, py + src_rect.position.y).a > alpha_min:
				tip = maxf(tip, (xf * (local_origin + Vector2(px + 0.5, py + 0.5))).x)
	var thicks: Array[float] = []
	var centres: Array[float] = []
	var x := maxf(0.0, lo.x)
	while x <= hi.x:
		var ymin := INF
		var ymax := -INF
		var y := lo.y
		while y <= hi.y:
			var t: Vector2 = inv * Vector2(x, y) - local_origin
			var px := Vector2i(floori(t.x), floori(t.y))
			if px.x >= 0 and px.y >= 0 and px.x < src_rect.size.x and px.y < src_rect.size.y and img.get_pixelv(px + src_rect.position).a > alpha_min:
				ymin = minf(ymin, y)
				ymax = maxf(ymax, y)
			y += SAMPLE_STEP
		if ymax >= ymin:
			thicks.append(ymax - ymin + SAMPLE_STEP)
			centres.append((ymin + ymax) * 0.5)
		x += SAMPLE_STEP
	if thicks.is_empty():
		return {}
	thicks.sort()
	centres.sort()
	return {"tip": tip, "thick": thicks[thicks.size() / 2], "cy": centres[centres.size() / 2]}

static var _warned: Dictionary = {}   ## pictures already warned about (off axis)

## Applies the fit to a freshly instantiated model (before BodyRig scaling reads the node positions), or again when a tuning number changes.
## Sets Hitbox/CollisionShape2D (a duplicate of the shape, never the shared SubResource) and the Tip marker x. The scene's hand-set shape / Tip
## are remembered on the model (meta `hit_hand`) so `hit_auto_fit` off puts them back. Returns a status string.
static func apply(model: Node2D, w: WeaponData) -> String:
	if model == null or w == null:
		return "hit: -"
	var art := model.get_node_or_null("Art") as Sprite2D
	var cs := model.get_node_or_null("Hitbox/CollisionShape2D") as CollisionShape2D
	var tip := model.get_node_or_null("Tip") as Node2D
	if cs == null or not (cs.shape is RectangleShape2D or model.has_meta("hit_hand")):
		return "hit: manual"
	if not model.has_meta("hit_hand"):
		model.set_meta("hit_hand", [cs.shape, cs.position, tip.position if tip else Vector2.ZERO])
	var hand: Array = model.get_meta("hit_hand")
	cs.shape = hand[0]
	cs.position = hand[1]
	if tip:
		_set_tip(tip, hand[2])
	if not w.hit_auto_fit or art == null:
		return "hit: manual"
	var m := measure(art, w.hit_alpha_min)
	if m.is_empty():
		return "hit: manual"
	var length: float = m["tip"] + w.hit_tip_margin
	var width: float = maxf(m["thick"] + w.hit_width_margin, w.hit_min_width)
	var shape := (hand[0] as RectangleShape2D).duplicate() as RectangleShape2D
	shape.size = Vector2(length, width)
	cs.shape = shape
	# Centre line: the scene's hand-set y is kept, NOT the measured cy (about 1 px off for the swords). The picture mirrors about the grip line y = 0
	# when the swing is reversed, and the mirror tests / Tip line rely on that. A big gap is reported (OFF AXIS) instead of followed.
	var hb_pos := (cs.get_parent() as Node2D).position if cs.get_parent() is Node2D else Vector2.ZERO   # Hitbox is moved when the scene's Grip is (WeaponVisual._apply_grip)
	cs.position = Vector2(length * 0.5 - hb_pos.x, cs.position.y)   # the shape spans grip (model 0) .. tip + margin in MODEL space
	if tip:
		_set_tip(tip, Vector2(m["tip"], tip.position.y))
	var out := "hit: auto %.0fx%.1f tip %.1f" % [length, width, m["tip"]]
	if absf(m["cy"] - (cs.position.y + hb_pos.y)) > w.hit_axis_warn_px:
		out += "  OFF AXIS: fix Art rotation/offset"
		if not _warned.has(art.texture):
			_warned[art.texture] = true
			push_warning("weapon picture is %.1f px off the model's +x line (hit box may miss): fix Art rotation / offset" % (m["cy"] - (cs.position.y + hb_pos.y)))
	return out

## Moves the Tip and the position BodyRig scaling resets it to.
static func _set_tip(tip: Node2D, pos: Vector2) -> void:
	tip.position = pos
	if tip.has_meta("rig_base"):
		tip.set_meta("rig_base", [pos, (tip.get_meta("rig_base") as Array)[1]])
