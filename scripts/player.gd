extends CharacterBody2D
## Player: 8-directional movement, mouse aim. Combat lives in WeaponHolder/Hitbox.
## `visual`/`weapon_visual` are reached only through the ActorVisual contract
## (set_move_state/set_facing/set_weapon_state/set_aim_angle) — never touched
## for internals (decision 0005, 0010).

@export var speed := 260.0

@onready var visual: ActorVisual = $Visual
# Sibling of Visual, NOT a child: replacing the Visual node must never
# delete the weapon with it (same trap as the shadow).
@onready var weapon_visual: WeaponVisual = $WeaponVisual
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var health: Health = $Health
@onready var dodge: Dodge = $Dodge
@onready var guard: Guard = $Guard
@onready var guard_visual: GuardVisual = $GuardVisual

var aim_direction := Vector2.RIGHT
var _move_state := "idle"
var _move_dir := Vector2.ZERO

func _ready() -> void:
	weapon_holder.state_changed.connect(_on_weapon_state_changed)
	weapon_visual.weapon = weapon_holder.weapon
	guard.state_changed.connect(guard_visual.on_guard_state)
	guard.parried.connect(func(_source: Node): guard_visual.on_parry_success())

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move_dir = input_dir
	# Dodge drives the body itself while dashing — fighting it over velocity
	# would double-move the player for a frame.
	if not dodge.is_dashing():
		velocity = input_dir * speed * guard.move_scale()
		move_and_slide()

	var new_move_state := "run" if velocity.length() > 1.0 else "idle"
	if new_move_state != _move_state:
		_move_state = new_move_state
		visual.set_move_state(_move_state)

	aim_direction = (get_global_mouse_position() - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	visual.set_facing(aim_direction)
	# 2.5D: the body stays upright, only the aim indicator/weapon turn (decision 0009).
	visual.set_aim_angle(aim_direction.angle())
	weapon_visual.set_aim_angle(aim_direction.angle())
	guard.aim_direction = aim_direction
	guard_visual.set_aim_angle(aim_direction.angle())
	guard_visual.parry_arc_degrees = guard.parry_arc_degrees  ## mirrored, never read from Guard by the visual

	if Input.is_action_just_pressed("attack") and guard.can_attack():
		weapon_holder.try_attack()

	if Input.is_action_just_pressed("dodge"):
		dodge.try_dodge(_move_dir, aim_direction)

	if Input.is_action_just_pressed("parry"):
		guard.try_guard()
	elif Input.is_action_just_released("parry"):
		guard.release()

func _on_weapon_state_changed(state: String) -> void:
	visual.set_weapon_state(state)
	weapon_visual.on_weapon_state(state)
