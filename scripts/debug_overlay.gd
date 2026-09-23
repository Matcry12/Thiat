extends CanvasLayer
## F1 toggle (on by default), F2 slow-mo. Draws hurtbox/hitbox outlines, weapon-state
## tint reference, the sword wedge, and top-left timing text.

@export var player_path: NodePath

## How flat a floor circle is drawn. Matches the shadow ellipse so ground shapes
## read as lying on the floor rather than standing up.
const GROUND_SQUASH := 0.45

var enabled := true
var last_damage := 0.0
var weapon_state := "idle"

@onready var _player: CharacterBody2D = get_node(player_path)
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
	var hitbox: Hitbox = _player.get_node("Hitbox")
	var weapon_holder: WeaponHolder = _player.get_node("WeaponHolder")
	var weapon: WeaponData = weapon_holder.weapon

	# Hurtboxes: green outline.
	for hurtbox in get_tree().get_nodes_in_group("hurtbox"):
		_draw_hurtbox_outline(hurtbox)

	# Hitbox: red outline, only while active.
	if weapon_holder.phase == WeaponHolder.Phase.ACTIVE:
		_draw_ground_circle(hitbox.global_position, weapon.reach, Color.RED, 2.0)

	# Sword wedge: whenever not idle.
	if weapon != null and weapon_holder.phase != WeaponHolder.Phase.IDLE:
		var aim: Vector2 = _player.aim_direction
		var half_arc := deg_to_rad(weapon.arc_degrees / 2.0)
		var from_angle := aim.angle() - half_arc
		var to_angle := aim.angle() + half_arc
		_draw_layer.draw_set_transform(_player.global_position, 0.0, Vector2(1.0, GROUND_SQUASH))
		_draw_layer.draw_arc(Vector2.ZERO, weapon.reach, from_angle, to_angle, 24, Color.WHITE, 1.5)
		_draw_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hurtbox_outline(hurtbox: Hurtbox) -> void:
	var cs := hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var shape := cs.shape as CircleShape2D
	if shape:
		_draw_ground_circle(cs.global_position, shape.radius, Color.GREEN, 2.0)

## Hit shapes live on the FLOOR plane in 2.5D, so draw them squashed like a
## shadow. A true circle would look like a hoop standing through the character.
func _draw_ground_circle(at: Vector2, radius: float, color: Color, width: float) -> void:
	_draw_layer.draw_set_transform(at, 0.0, Vector2(1.0, GROUND_SQUASH))
	_draw_layer.draw_arc(Vector2.ZERO, radius, 0, TAU, 28, color, width)
	_draw_layer.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
