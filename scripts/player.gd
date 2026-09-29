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
@onready var loadout: Loadout = $Loadout

var aim_direction := Vector2.RIGHT
## Automation seam, NOT gameplay: when non-zero, aim comes from here instead of
## the mouse. The demo recorder (tools/demo/) and headless tests have no cursor
## — Godot reports the mouse at (0,0), which aims the player up-left and makes
## the directional guard/parry look broken when it is not. Nothing in the game
## ever writes this, and it is deliberately not an @export so the editor cannot.
var aim_override := Vector2.ZERO
var _move_state := "idle"
var _move_dir := Vector2.ZERO

func _ready() -> void:
	# Loadout is the ONE owner of "current weapon" (decision: three owners —
	# WeaponHolder.weapon, WeaponVisual.weapon, Loadout.weapons[0] — could
	# desync). Both are plain vars now; set them from Loadout here and again
	# in _on_swap_finished.
	weapon_holder.weapon = loadout.active_weapon()
	weapon_visual.set_weapon(loadout.active_weapon())
	weapon_holder.state_changed.connect(_on_weapon_state_changed)
	weapon_visual.model_changed.connect(weapon_holder.bind_model)
	# The model was already built by set_weapon() just above, before this
	# connection existed — bind it now instead of rebuilding (rebuilding here
	# would free+recreate it, renaming the node out from under anything
	# holding its path).
	weapon_holder.bind_model(weapon_visual.get_model())
	guard.state_changed.connect(guard_visual.on_guard_state)
	guard.tank_changed.connect(func(_c: float, _m: float): guard_visual.set_tank_fill(guard.tank_fraction()))
	# Block pose: the sword rises while guarding (decision 0015).
	guard.state_changed.connect(func(st: String): weapon_visual.set_guarding(st == "parry" or st == "block"))
	guard.parried.connect(func(_source: Node): guard_visual.on_parry_success())
	guard.broke.connect(guard_visual.on_break)
	loadout.swap_finished.connect(_on_swap_finished)

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

	aim_direction = aim_override.normalized() if aim_override != Vector2.ZERO \
		else (get_global_mouse_position() - global_position).normalized()
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2.RIGHT
	visual.set_facing(aim_direction)
	# 2.5D: the body stays upright, only the aim indicator/weapon turn (decision 0009).
	visual.set_aim_angle(aim_direction.angle())
	weapon_visual.set_aim_angle(aim_direction.angle())
	weapon_holder.aim_direction = aim_direction
	guard.aim_direction = aim_direction
	guard_visual.set_aim_angle(aim_direction.angle())
	guard_visual.set_cover_degrees(guard.parry_arc_degrees)  ## mirrored: the hint shows exactly what blocks

	if Input.is_action_just_pressed("attack") and guard.can_attack() and not loadout.is_casting():
		weapon_holder.try_attack()

	if Input.is_action_just_pressed("dodge"):
		# Only a dodge that actually FIRES cancels the swap — a dodge refused
		# by its own cooldown must not cancel a cast that would otherwise
		# have kept going (decision: a failed press is a no-op, not a cancel).
		if dodge.try_dodge(_move_dir, aim_direction):
			loadout.cancel_swap()

	if Input.is_action_just_pressed("parry"):
		if guard.try_guard():
			loadout.cancel_swap()
	elif Input.is_action_just_released("parry"):
		guard.release()

	# Weapon swap is vulnerable, like an attack (decision 0003) — refused
	# while guarding or dashing, same as the attack gate above. Loadout stays
	# input-agnostic; the gate lives here, next to the other input gates.
	if Input.is_action_just_pressed("weapon_1") and not guard.is_guarding() and not dodge.is_dashing():
		loadout.try_swap(0)
	if Input.is_action_just_pressed("weapon_2") and not guard.is_guarding() and not dodge.is_dashing():
		loadout.try_swap(1)

func _on_weapon_state_changed(state: String) -> void:
	visual.set_weapon_state(state)
	weapon_visual.on_weapon_state(state)

func _on_swap_finished(w: WeaponData) -> void:
	weapon_holder.weapon = w
	weapon_visual.set_weapon(w)   # emits model_changed -> weapon_holder.bind_model
