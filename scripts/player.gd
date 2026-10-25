extends CharacterBody2D
## Player: 8-directional movement, mouse aim. Combat lives in WeaponHolder/Hitbox.
## `visual`/`weapon_visual` are reached only through the ActorVisual contract
## (set_move_state/set_facing/set_weapon_state/set_aim_angle) — never touched
## for internals (decision 0005, 0010).

@export var speed := 260.0
## Seconds of no scrolling before the wheel's hotbar slot is selected.
@export var wheel_settle := 0.12
## Holding attack with a tool or bare hands keeps gathering (weapons stay one click per swing, 0036).
@export var hold_to_gather := true

@onready var visual: ActorVisual = $Visual
# Sibling of Visual, NOT a child: replacing the Visual node must never
# delete the weapon with it (same trap as the shadow).
@onready var weapon_visual: WeaponVisual = $WeaponVisual
@onready var swing_fx: SwingFx = $WeaponVisual/SwingFx
@onready var hands: HandsVisual = $Hands
@onready var weapon_holder: WeaponHolder = $WeaponHolder
@onready var health: Health = $Health
@onready var dodge: Dodge = $Dodge
@onready var guard: Guard = $Guard
@onready var guard_visual: GuardVisual = $GuardVisual
@onready var loadout: Loadout = $Loadout
@onready var skill_slot: SkillSlot = $SkillSlot
@onready var placer: Placer = $Placer
@onready var swimmer: Swimmer = $Swimmer   # shallow water slows walking (0038 step 3)

var aim_direction := Vector2.RIGHT
## Automation seam, NOT gameplay: when non-zero, aim comes from here instead of
## the mouse. The demo recorder (tools/demo/) and headless tests have no cursor
## — Godot reports the mouse at (0,0), which aims the player up-left and makes
## the directional guard/parry look broken when it is not. Nothing in the game
## ever writes this, and it is deliberately not an @export so the editor cannot.
var aim_override := Vector2.ZERO
## True from Health.died until Respawner wakes the player: every input is ignored. Code-owned, so not an @export.
var dead := false
var _parry_down := false   # the key went down and has not been seen up yet
var _wheel_slot := -1
var _wheel_left := 0.0
var _move_state := "idle"
var _move_dir := Vector2.ZERO

func _ready() -> void:
	add_to_group("player")   # trees fade when the player stands behind them
	# Loadout is the ONE owner of "current weapon" (decision: three owners —
	# WeaponHolder.weapon, WeaponVisual.weapon, Loadout.weapons[0] — could
	# desync). Both are plain vars now; set them from Loadout here and again
	# in _on_swap_finished.
	weapon_holder.weapon = loadout.active_weapon()
	swing_fx.set_weapon(loadout.active_weapon())
	weapon_visual.set_weapon(loadout.active_weapon())
	weapon_holder.state_changed.connect(_on_weapon_state_changed)
	weapon_visual.model_changed.connect(weapon_holder.bind_model)
	# The model was already built by set_weapon() just above, before this
	# connection existed — bind it now instead of rebuilding (rebuilding here
	# would free+recreate it, renaming the node out from under anything
	# holding its path).
	weapon_holder.bind_model(weapon_visual.get_model())
	weapon_visual.model_changed.connect(swing_fx.bind_model)
	swing_fx.bind_model(weapon_visual.get_model())
	weapon_visual.model_changed.connect(hands.bind_model)
	hands.bind_model(weapon_visual.get_model())
	skill_slot.skill_state_changed.connect(func(st: String): hands.set_drawing(st == "charge"))
	guard.state_changed.connect(guard_visual.on_guard_state)
	guard.tank_changed.connect(func(_c: float, _m: float): guard_visual.set_tank_fill(guard.tank_fraction()))
	# Block pose: the sword rises while guarding (decision 0015).
	guard.state_changed.connect(func(st: String): weapon_visual.set_guarding(st == "parry" or st == "block"))
	guard.parried.connect(func(_source: Node): guard_visual.on_parry_success())
	guard.broke.connect(guard_visual.on_break)
	loadout.swap_finished.connect(_on_swap_finished)
	health.died.connect(_on_died)

func _on_died() -> void:
	if dead:
		return
	dead = true
	weapon_holder.cancel()
	guard.release()
	dodge.cancel()
	skill_slot.cancel()
	velocity = Vector2.ZERO
	visual.set_move_state("idle")

## Wakes up after a death (Respawner): full hp, inputs back. The caller moves the body.
func respawn() -> void:
	dead = false
	health.revive()
	guard.reset()
	velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if dead:
		return
	# A text field (the F3 seed box) has focus: the keys belong to it, not to the game. Polling Input
	# ignores GUI focus, so the player has to check by itself.
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var input_dir := Vector2.ZERO if typing else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_move_dir = input_dir
	# Dodge drives the body itself while dashing — fighting it over velocity
	# would double-move the player for a frame.
	# A body-moving skill (the lunge) drives velocity the same way.
	swimmer.refresh()   # in shallow water? (only the walk speed reads it)
	if not dodge.is_dashing() and not skill_slot.moves_body():
		velocity = input_dir * speed * guard.move_scale() * skill_slot.move_scale() * swimmer.speed_scale()
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
	hands.set_aim_angle(aim_direction.angle())
	weapon_holder.aim_direction = aim_direction
	skill_slot.aim_direction = aim_direction
	guard.aim_direction = aim_direction
	guard_visual.set_aim_angle(aim_direction.angle())
	guard_visual.set_cover_degrees(guard.parry_arc_degrees)  ## mirrored: the hint shows exactly what blocks

	if typing:
		guard.release()
		return

	var attack_in := Input.is_action_just_pressed("attack") \
			or (hold_to_gather and not dodge.is_dashing() and loadout.is_holstered() and not placer.is_holding() and Input.is_action_pressed("attack"))
	if attack_in and guard.can_attack() and not loadout.is_casting() \
			and not skill_slot.is_active() and not mouse_over_ui():
		# A station in the selected slot: the click puts it down instead of swinging (decision 0031).
		if placer.is_holding():
			placer.try_place()
		else:
			weapon_holder.try_attack()

	# E skill. Refused while guarding, dashing, casting a swap, mid-swing; the
	# slot itself refuses a second skill or one on cooldown.
	if Input.is_action_just_pressed("skill") and not guard.is_guarding() and not dodge.is_dashing() \
			and not loadout.is_casting() and weapon_holder.phase == WeaponHolder.Phase.IDLE:
		skill_slot.try_use(loadout.active_weapon(), aim_direction)

	# Dodge and guard are refused while a body-moving skill (the 0.15 s lunge)
	# runs: two things driving the body at once. A bow charge does NOT move the
	# body, so a dodge/guard that fires cancels it (cooldown refunded).
	var body_free := not skill_slot.moves_body()
	if Input.is_action_just_pressed("dodge") and body_free:
		# Only a dodge that actually FIRES cancels the swap — a dodge refused
		# by its own cooldown must not cancel a cast that would otherwise
		# have kept going (decision: a failed press is a no-op, not a cancel).
		if dodge.try_dodge(_move_dir, aim_direction):
			loadout.cancel_swap()
			skill_slot.cancel()

	if Input.is_action_just_pressed("parry"):
		_parry_down = true
		if body_free and guard.try_guard():
			loadout.cancel_swap()
			skill_slot.cancel()
	elif _parry_down and not Input.is_action_pressed("parry"):   # not just_released: a release during a pause must not leave the guard held
		_parry_down = false
		guard.release()

	# Weapon swap is vulnerable, like an attack (decision 0003) — refused
	# while guarding or dashing, same as the attack gate above. Loadout stays
	# input-agnostic; the gate lives here, next to the other input gates.
	# Hotbar select (keys 1-9, wheel). Same gates as before: a swap is vulnerable, so it is refused
	# while guarding, dashing or using a skill. Loadout decides swap (weapon) vs instant (tool / hands).
	var can_select := not guard.is_guarding() and not dodge.is_dashing() and not skill_slot.is_active()
	if can_select:
		for n in Inventory.HOTBAR:
			if Input.is_action_just_pressed("slot_%d" % (n + 1)):
				loadout.select(n)
		if _wheel_slot >= 0:
			_wheel_left -= delta
			if _wheel_left <= 0.0:
				loadout.select(_wheel_slot)
				_wheel_slot = -1

func _unhandled_input(event: InputEvent) -> void:
	# Wheel moves a cursor over the hotbar; the slot is only selected after `wheel_settle` seconds of
	# calm, so scrolling past the bow does not start a swap cast on the way to the axe.
	if dead or not event is InputEventMouseButton or not event.pressed:
		return
	var step := -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else 0)
	if step == 0:
		return
	var from := _wheel_slot if _wheel_slot >= 0 else loadout.selected_slot
	_wheel_slot = posmod(from + step, Inventory.HOTBAR)
	_wheel_left = wheel_settle

## Slot the wheel is moving to (-1 = none); the hotbar highlights it before it is selected.
func pending_slot() -> int:
	return _wheel_slot

## True while the bag panel is open and the mouse is over it (or over the hotbar it makes clickable).
func mouse_over_ui() -> bool:
	var bag := get_tree().get_first_node_in_group("bag_panel")
	return bag != null and bag.is_open() and get_viewport().gui_get_hovered_control() != null

func _on_weapon_state_changed(state: String) -> void:
	visual.set_weapon_state(state)
	weapon_visual.on_weapon_state(state)
	swing_fx.on_weapon_state(state)
	# A bow's wind-up is its draw: the off hand pulls back (the piercing charge does the same via the skill).
	if weapon_holder.weapon and weapon_holder.weapon.behavior == "projectile":
		hands.set_drawing(state == "windup")

func _on_swap_finished(w: WeaponData) -> void:
	skill_slot.cancel()   # defensive: swaps are refused while a skill runs
	weapon_holder.weapon = w
	swing_fx.set_weapon(w)
	weapon_visual.set_weapon(w)   # emits model_changed -> weapon_holder.bind_model
