@tool
extends Node2D
class_name WeaponVisual
## The weapon sprite on a rotating pivot (decision 0010). The Hitbox now lives
## under `Blade` and inherits this node's transform (decision 0011) — so a
## change to the swing motion here also moves the hit area. There is no
## separate telegraph draw any more: the visible blade IS the telegraph.
##
## The whole node rotates to the aim angle. The `Blade` child is positioned BY
## HAND in the editor — drag it until the grip sits where the hand should be.
## This script never writes `Blade.position`: doing so would silently overwrite
## your dragging when the game starts (the same two-sources-of-truth bug as
## decision 0011). Code owns only the blade's ROTATION, because that animates.
##
## All timing comes from `weapon` (a WeaponData resource), never a hardcoded second.

@export var weapon: WeaponData
@export var blade_texture: Texture2D: set = _set_blade_texture


## Which way the blade points INSIDE the image file, in degrees.
## 0 = the art points right (our own placeholders). -45 = the art is drawn
## diagonally, pointing up-right (most downloaded item icons look like this).
## The code cancels this out, so diagonal art needs no rotating or redrawing.
@export var art_angle_degrees := 0.0: set = _set_art_angle
## Aiming left mirrors the weapon rather than rotating it past vertical, so the
## blade always reads as held upright — how Soul Knight does it.
@export var mirror_when_facing_left := true
## Idle hold angle, relative to aim. -45 reads like a Minecraft item: the blade
## is carried diagonally instead of pointing flat forward. The PNG itself always
## points +X; this only changes how it is DISPLAYED, never the hit maths.
@export var rest_angle_degrees := -45.0: set = _set_rest_angle

## Speed curves. The blade must not travel at a constant speed — Soul Knight
## SNAPS the blade up, holds an instant, then accelerates through the slash.
## Values are fed to Godot's ease(): below 1.0 = fast start then settle
## (a snap), above 1.0 = slow start then accelerate (a whip).
@export var windup_ease := 0.35      ## snap the blade up almost instantly
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

## ONE pivot swings everything: the blade sprite AND the hitbox hang off it, so
## the picture and the hit area turn as a single rigid arm. Two separate
## rotations kept in sync by code is what made the old swing look wrong.
@onready var _swing_pivot: Node2D = get_node_or_null("SwingPivot")
@onready var blade: Sprite2D = get_node_or_null("SwingPivot/Blade")

var aim_angle := 0.0

var _phase := "idle"
var _t := 0.0
var _blade_angle := 0.0          ## Blade.rotation, relative to this node (i.e. relative to aim)
var _phase_start_angle := 0.0
var _phase_target_angle := 0.0
var _guarding := false
var _pivot_pos := Vector2.ZERO   ## SwingPivot.position — code-owned, see _guard_offset()
var _phase_start_pos := Vector2.ZERO
var _phase_target_pos := Vector2.ZERO

func _ready() -> void:
	_blade_angle = deg_to_rad(rest_angle_degrees)
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_apply_all()

## Applies texture, position and resting rotation. Runs in the EDITOR too
## (@tool), so the sword is visible and alignable without pressing play.
func _apply_all() -> void:
	var b := get_node_or_null("SwingPivot/Blade") as Sprite2D
	if b == null:
		return
	if blade_texture:
		b.texture = blade_texture
	# Constant: only cancels the art's drawn direction. The SWING lives on the pivot.
	b.rotation = -deg_to_rad(art_angle_degrees)
	var pivot := get_node_or_null("SwingPivot") as Node2D
	if pivot and Engine.is_editor_hint():
		if preview_guard_pose and weapon:
			pivot.rotation = deg_to_rad(weapon.guard_angle_degrees)
			pivot.position = _guard_offset()
		else:
			pivot.rotation = deg_to_rad(rest_angle_degrees)
			pivot.position = Vector2.ZERO

## The guard's arm offset. SwingPivot.position is CODE-OWNED (like its
## rotation): drag WeaponVisual to move the hand, or Blade to move the grip —
## never SwingPivot, or the game will move it back.
func _guard_offset() -> Vector2:
	return Vector2(weapon.guard_forward, weapon.guard_side) if weapon else Vector2.ZERO

func _set_preview_guard(v: bool) -> void:
	preview_guard_pose = v
	_apply_all()

func _set_blade_texture(v: Texture2D) -> void:
	blade_texture = v
	_apply_all()

func _set_rest_angle(v: float) -> void:
	rest_angle_degrees = v
	_apply_all()

## The swing is centred on the aim: -arc/2 .. +arc/2. There is no separate
## windup angle to keep in sync — one number describes the whole motion.
func _half_arc() -> float:
	return deg_to_rad(weapon.arc_degrees) * 0.5 if weapon else 0.0

func _set_art_angle(v: float) -> void:
	art_angle_degrees = v
	_apply_all()

func set_aim_angle(angle: float) -> void:
	aim_angle = angle
	rotation = angle
	# Soul Knight style: aiming left MIRRORS the weapon instead of turning it
	# upside down. Scaling the whole node (not flipping the sprite) mirrors the
	# hitbox with the art, so the two can never disagree (decision 0011).
	if mirror_when_facing_left:
		var facing_left: bool = cos(angle) < 0.0
		scale.y = -1.0 if facing_left else 1.0

## Hold F -> the blade snaps into the guard pose; release -> back to rest.
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
		_phase_target_angle = deg_to_rad(rest_angle_degrees)
		_phase_target_pos = Vector2.ZERO

func on_weapon_state(state: String) -> void:
	# Starting a guard cancels the swing, which reports "idle" — that must not
	# drop the blade out of the guard pose it is about to take.
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
			# ...then through to half the arc AHEAD of it, so the blade points
			# straight at the cursor in the middle of the swing.
			_phase_target_angle = _half_arc()
		_:
			_phase_target_angle = deg_to_rad(rest_angle_degrees)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
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
	# The arm swings; the blade's own rotation only ever corrects for how the
	# picture happens to be drawn, and never changes during a swing.
	if _swing_pivot:
		_swing_pivot.rotation = _blade_angle
		_swing_pivot.position = _pivot_pos
