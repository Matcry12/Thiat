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
@onready var hitbox: Hitbox = $Hitbox

var aim_direction := Vector2.RIGHT
var _move_state := "idle"

func _ready() -> void:
	weapon_holder.state_changed.connect(_on_weapon_state_changed)
	weapon_visual.weapon = weapon_holder.weapon

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()

	var new_move_state := "run" if velocity.length() > 1.0 else "idle"
	if new_move_state != _move_state:
		_move_state = new_move_state
		visual.set_move_state(_move_state)

	aim_direction = (get_global_mouse_position() - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	hitbox.aim_direction = aim_direction
	visual.set_facing(aim_direction)
	# 2.5D: the body stays upright, only the aim indicator/weapon turn (decision 0009).
	visual.set_aim_angle(aim_direction.angle())
	weapon_visual.set_aim_angle(aim_direction.angle())

	if Input.is_action_just_pressed("attack"):
		weapon_holder.try_attack()

func _on_weapon_state_changed(state: String) -> void:
	visual.set_weapon_state(state)
	weapon_visual.on_weapon_state(state)
