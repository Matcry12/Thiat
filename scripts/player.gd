extends CharacterBody2D
## Player: 8-directional movement, mouse aim. Combat lives in WeaponHolder/Hitbox,
## reached only through the `state_changed` signal — never touches Visual directly.

@export var speed := 260.0

@onready var visual: Node2D = $Visual
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var hitbox: Hitbox = $Hitbox

var aim_direction := Vector2.RIGHT

func _ready() -> void:
	weapon_holder.state_changed.connect(_on_weapon_state_changed)

func _physics_process(_delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_dir * speed
	move_and_slide()

	aim_direction = (get_global_mouse_position() - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	hitbox.aim_direction = aim_direction
	visual.rotation = aim_direction.angle()

	if Input.is_action_just_pressed("attack"):
		weapon_holder.try_attack()

func _on_weapon_state_changed(state: String) -> void:
	if visual.has_method("set_weapon_state"):
		visual.set_weapon_state(state)
