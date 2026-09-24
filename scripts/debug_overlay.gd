extends CanvasLayer
## F1 toggle (on by default), F2 slow-mo. Draws hurtbox/hitbox outlines, weapon-state
## tint reference, and top-left timing text.

@export var player_path: NodePath
@export var dummy_path: NodePath

@export var enabled := true  ## exported so the F3 tuning panel can reflect it
var last_damage := 0.0
var weapon_state := "idle"

@onready var _player: CharacterBody2D = get_node(player_path)
@onready var _dummy: Node2D = get_node_or_null(dummy_path)
@onready var _draw_layer: Node2D = $DrawLayer
@onready var _label: Label = $Label

func _ready() -> void:
	_draw_layer.draw.connect(_on_draw)
	(_player.get_node("WeaponHolder") as WeaponHolder).state_changed.connect(_on_weapon_state_changed)
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
		Engine.time_scale = 0.25 if Engine.time_scale == 1.0 else 1.0

func _process(_delta: float) -> void:
	_draw_layer.queue_redraw()

func _on_weapon_state_changed(state: String) -> void:
	weapon_state = state
	_update_label()

func _on_damaged(amount: float) -> void:
	last_damage = amount
	_update_label()

func _update_label() -> void:
	_label.text = "" if not enabled else "weapon: %s\nlast damage: %.1f" % [weapon_state, last_damage]

func _on_draw() -> void:
	if not enabled:
		return
	var hitbox: Hitbox = _player.get_node("WeaponVisual/Hitbox")
	var weapon_holder: WeaponHolder = _player.get_node("WeaponHolder")

	# Hurtboxes: green outline.
	for hurtbox in get_tree().get_nodes_in_group("hurtbox"):
		_draw_hurtbox_outline(hurtbox)

	# Hitbox: red outline of its ACTUAL shape at its ACTUAL transform, only
	# while active. The shape IS the hit area (decision 0011) — this is the
	# only honest picture of what can currently hit, no separate reach/arc math.
	if weapon_holder.phase == WeaponHolder.Phase.ACTIVE:
		_draw_hitbox_outline(hitbox)

	# Player i-frames: blue outline for the dodge window's whole duration.
	var dodge: Dodge = _player.get_node_or_null("Dodge")
	if dodge and dodge.iframes_active():
		var body_cs := _player.get_node("CollisionShape2D") as CollisionShape2D
		var body_shape := body_cs.shape as CircleShape2D
		if body_shape:
			_draw_ground_circle(_player.global_position, body_shape.radius, Color.BLUE, 3.0)

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
					_draw_ground_circle(cs.global_position, shape.radius, Color.ORANGE, 2.0)

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

## Flat 2D circle. No perspective squashing — this game fakes depth only through
## draw order and upright sprites (decision 0009), never through projection.
func _draw_ground_circle(at: Vector2, radius: float, color: Color, width: float) -> void:
	_draw_layer.draw_arc(at, radius, 0, TAU, 28, color, width)
