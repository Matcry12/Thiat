@tool
extends Node2D
class_name WeaponVisual
## The weapon's model sits on a rotating pivot (decision 0010). Since Step 1,
## the model (art + optional hitbox/muzzle) is its OWN SCENE (`WeaponData.model`,
## e.g. `scenes/weapons/sword_model.tscn`) instantiated under `SwingPivot` —
## swapping weapons swaps the whole model, never edits nodes in this scene.
## The model's children are hand-placed by its own scene's user and this
## script never writes into them; code owns only the pivot's rotation/position,
## exactly as before (decision 0011).
##
## All timing comes from `weapon` (a WeaponData resource), never a hardcoded second.

signal model_changed(model: Node2D)

## Loadout is the one owner of "current weapon" — set via set_weapon(), called
## by player.gd from loadout.active_weapon(). Not an @export: the editor never
## runs player.gd, so `preview_weapon_from` below drives the EDITOR preview
## instead (same pattern as CoverArc.preview_width_from).
var weapon: WeaponData: set = _set_weapon

## EDITOR PREVIEW ONLY. Resolved to a Loadout node; its weapons[0] is shown
## while editing, since no player.gd runs in the editor to set `weapon` for
## real (see cover_arc.gd's preview_width_from for the same trap/fix).
@export var preview_weapon_from: NodePath = NodePath("../Loadout")

## Aiming left mirrors the weapon rather than rotating it past vertical, so the
## model always reads as held upright — how Soul Knight does it.
@export var mirror_when_facing_left := true

## Speed curves. The model must not travel at a constant speed — Soul Knight
## SNAPS it up, holds an instant, then accelerates through the slash.
## Values are fed to Godot's ease(): below 1.0 = fast start then settle
## (a snap), above 1.0 = slow start then accelerate (a whip).
@export var windup_ease := 0.35      ## snap up almost instantly
@export var active_ease := 2.2       ## accelerate through the slash
@export var recovery_ease := 0.6     ## drift back, unhurried

## Block pose (decision 0015). The ANGLE is per weapon (WeaponData.
## guard_angle_degrees); how fast the arm gets there is a feel number here.
## Raise must beat the 0.25s parry window by a wide margin, or the pose would
## still be travelling when the parry already landed.
@export var guard_raise_time := 0.06
@export var guard_lower_time := 0.12
@export var guard_ease := 0.4        ## below 1 = snap into the guard

## Tick this in the EDITOR to see the weapon's guard pose instead of its rest
## pose, then edit Guard Angle / Forward / Side on the weapon's data and watch it
## move. Editor-only: the running game ignores it.
@export var preview_guard_pose := false: set = _set_preview_guard

## ONE pivot swings everything: the model's art AND its hitbox hang off it, so
## the picture and the hit area turn as a single rigid arm.
@onready var _swing_pivot: Node2D = get_node_or_null("SwingPivot")

var _model: Node2D

var aim_angle := 0.0

var _phase := "idle"
var _t := 0.0
var _blade_angle := 0.0          ## SwingPivot.rotation, relative to this node (i.e. relative to aim)
var _phase_start_angle := 0.0
var _phase_target_angle := 0.0
var _guarding := false
var _pivot_pos := Vector2.ZERO   ## SwingPivot.position — code-owned, see _guard_offset()
var _phase_start_pos := Vector2.ZERO
var _phase_target_pos := Vector2.ZERO

func _ready() -> void:
	_rebuild_model()
	_blade_angle = deg_to_rad(_rest_angle())
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_apply_all()

## Called by the owner (player.gd) on a weapon swap. Frees the previous model
## and instantiates the new one under SwingPivot. Its instance is NOT owned by
## the scene (owner left unset), so the editor never saves it into player.tscn.
func set_weapon(data: WeaponData) -> void:
	weapon = data

func _set_weapon(v: WeaponData) -> void:
	weapon = v
	_rebuild_model()
	_apply_all()
	if not Engine.is_editor_hint():
		_retarget_pose_to_new_weapon()

## Fix: a swap used to leave the pivot at the OLD weapon's rest/guard angle
## until the next swing/guard retriggered it. Snaps the pivot straight to the
## NEW weapon's pose (rest, or guard if F is currently held) the instant the
## model changes, instead of waiting for the next animation.
func _retarget_pose_to_new_weapon() -> void:
	if _guarding:
		_blade_angle = deg_to_rad(weapon.guard_angle_degrees if weapon else -90.0)
		_pivot_pos = _guard_offset()
	else:
		_blade_angle = deg_to_rad(_rest_angle())
		_pivot_pos = Vector2.ZERO
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	_phase_target_pos = _pivot_pos
	if _swing_pivot:
		_swing_pivot.rotation = _blade_angle
		_swing_pivot.position = _pivot_pos

## The current model instance (or null). Used once by the owner right after
## connecting `model_changed`, to pick up the model that was built during
## _ready() before the connection existed — see player.gd.
func get_model() -> Node2D:
	return _model

func _rebuild_model() -> void:
	if _swing_pivot == null:
		_swing_pivot = get_node_or_null("SwingPivot")
	if _model:
		_model.queue_free()
		_model = null
	if _swing_pivot and weapon and weapon.model:
		_model = weapon.model.instantiate()
		_swing_pivot.add_child(_model)
	model_changed.emit(_model)

func _rest_angle() -> float:
	return weapon.rest_angle_degrees if weapon else -45.0

## Applies pivot pose (editor preview only — during play the pivot is driven
## by _process below).
func _apply_all() -> void:
	var pivot := get_node_or_null("SwingPivot") as Node2D
	if pivot and Engine.is_editor_hint():
		if preview_guard_pose and weapon:
			pivot.rotation = deg_to_rad(weapon.guard_angle_degrees)
			pivot.position = _guard_offset()
		else:
			pivot.rotation = deg_to_rad(_rest_angle())
			pivot.position = Vector2.ZERO

## The guard's arm offset. SwingPivot.position is CODE-OWNED (like its
## rotation): drag WeaponVisual to move the hand, or the model's Art to move
## the grip — never SwingPivot, or the game will move it back.
func _guard_offset() -> Vector2:
	return Vector2(weapon.guard_forward, weapon.guard_side) if weapon else Vector2.ZERO

func _set_preview_guard(v: bool) -> void:
	preview_guard_pose = v
	_apply_all()

## EDITOR ONLY (see preview_weapon_from). Mirrors cover_arc.gd's
## sync_editor_preview(): reads the previewed weapon off Loadout every frame
## and pushes it through the normal setter when it changes.
func _sync_editor_preview_weapon() -> void:
	var src := get_node_or_null(preview_weapon_from)
	if src == null:
		return
	var weapons = src.get("weapons")
	var new_weapon: WeaponData = weapons[0] if (weapons is Array and weapons.size() > 0) else null
	if new_weapon != weapon:
		weapon = new_weapon

## The swing is centred on the aim: -arc/2 .. +arc/2. There is no separate
## windup angle to keep in sync — one number describes the whole motion.
func _half_arc() -> float:
	return deg_to_rad(weapon.arc_degrees) * 0.5 if weapon else 0.0

func set_aim_angle(angle: float) -> void:
	aim_angle = angle
	rotation = angle
	# Soul Knight style: aiming left MIRRORS the weapon instead of turning it
	# upside down. Scaling the whole node (not flipping the sprite) mirrors the
	# hitbox with the art, so the two can never disagree (decision 0011).
	if mirror_when_facing_left:
		var facing_left: bool = cos(angle) < 0.0
		scale.y = -1.0 if facing_left else 1.0

## Hold F -> the model snaps into the guard pose; release -> back to rest.
## Driven by Guard's state (parry/block = on), wired by the player — this node
## never reads Guard.
func set_guarding(on: bool) -> void:
	if on == _guarding:
		return
	_guarding = on
	_t = 0.0
	_phase_start_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	if on:
		_phase = "guard"
		_phase_target_angle = deg_to_rad(weapon.guard_angle_degrees if weapon else -90.0)
		_phase_target_pos = _guard_offset()
	else:
		_phase = "guard_release"
		_phase_target_angle = deg_to_rad(_rest_angle())
		_phase_target_pos = Vector2.ZERO

func on_weapon_state(state: String) -> void:
	# Starting a guard cancels the swing, which reports "idle" — that must not
	# drop the model out of the guard pose it is about to take.
	if _guarding and state == "idle":
		return
	_phase = state
	_t = 0.0
	_phase_start_angle = _blade_angle
	_phase_start_pos = _pivot_pos
	_phase_target_pos = Vector2.ZERO   # every swing happens from the hand
	match state:
		"windup":
			# Half the arc BEHIND the aim...
			_phase_target_angle = -_half_arc()
		"active":
			# ...then through to half the arc AHEAD of it, so the model points
			# straight at the cursor in the middle of the swing.
			_phase_target_angle = _half_arc()
		_:
			_phase_target_angle = deg_to_rad(_rest_angle())

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_sync_editor_preview_weapon()
		# Re-apply while previewing, so edits to the weapon's .tres numbers show
		# up immediately (a Resource does not tell this node it changed).
		if preview_guard_pose:
			_apply_all()
		return
	var duration := 0.0
	if weapon != null:
		match _phase:
			"windup": duration = weapon.windup
			"active": duration = weapon.active
			"recovery": duration = weapon.recovery
	match _phase:
		"guard": duration = guard_raise_time
		"guard_release": duration = guard_lower_time
	_t = 1.0 if duration <= 0.0 else minf(1.0, _t + delta / duration)
	var curve := 1.0
	match _phase:
		"windup": curve = windup_ease
		"active": curve = active_ease
		"recovery": curve = recovery_ease
		"guard", "guard_release": curve = guard_ease
	# While F stays held, keep tracking the weapon's guard angle, so the F3
	# slider moves the pose live instead of only on the next press.
	if _phase == "guard" and weapon:
		_phase_target_angle = deg_to_rad(weapon.guard_angle_degrees)
		_phase_target_pos = _guard_offset()
	var k := ease(_t, curve)
	_blade_angle = lerpf(_phase_start_angle, _phase_target_angle, k)
	_pivot_pos = _phase_start_pos.lerp(_phase_target_pos, k)
	# The model's own rotation only ever corrects for how its picture happens
	# to be drawn (baked into the model scene), and never changes during a swing.
	if _swing_pivot:
		_swing_pivot.rotation = _blade_angle
		_swing_pivot.position = _pivot_pos
