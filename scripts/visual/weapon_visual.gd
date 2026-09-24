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
@export var windup_angle_degrees := 60.0: set = _set_windup_angle   ## how far back the blade winds up, relative to aim

@onready var blade: Sprite2D = $Blade

var aim_angle := 0.0

var _phase := "idle"
var _t := 0.0
var _blade_angle := 0.0          ## Blade.rotation, relative to this node (i.e. relative to aim)
var _phase_start_angle := 0.0
var _phase_target_angle := 0.0

func _ready() -> void:
	_blade_angle = deg_to_rad(rest_angle_degrees)
	_phase_start_angle = _blade_angle
	_phase_target_angle = _blade_angle
	_apply_all()

## Applies texture, position and resting rotation. Runs in the EDITOR too
## (@tool), so the sword is visible and alignable without pressing play.
func _apply_all() -> void:
	var b := get_node_or_null("Blade") as Sprite2D
	if b == null:
		return
	if blade_texture:
		b.texture = blade_texture
	if Engine.is_editor_hint():
		b.rotation = deg_to_rad(rest_angle_degrees) - deg_to_rad(art_angle_degrees)
	else:
		b.rotation = _blade_angle - deg_to_rad(art_angle_degrees)

func _set_blade_texture(v: Texture2D) -> void:
	blade_texture = v
	_apply_all()

func _set_rest_angle(v: float) -> void:
	rest_angle_degrees = v
	_apply_all()

func _set_art_angle(v: float) -> void:
	art_angle_degrees = v
	_apply_all()

func _set_windup_angle(v: float) -> void:
	windup_angle_degrees = v

func set_aim_angle(angle: float) -> void:
	aim_angle = angle
	rotation = angle
	# Soul Knight style: aiming left MIRRORS the weapon instead of turning it
	# upside down. Scaling the whole node (not flipping the sprite) mirrors the
	# hitbox with the art, so the two can never disagree (decision 0011).
	if mirror_when_facing_left:
		var facing_left: bool = cos(angle) < 0.0
		scale.y = -1.0 if facing_left else 1.0

func on_weapon_state(state: String) -> void:
	_phase = state
	_t = 0.0
	_phase_start_angle = _blade_angle
	match state:
		"windup":
			_phase_target_angle = -deg_to_rad(windup_angle_degrees)
		"active":
			var arc: float = deg_to_rad(weapon.arc_degrees) if weapon else 0.0
			_phase_target_angle = _phase_start_angle + arc
		_:
			_phase_target_angle = deg_to_rad(rest_angle_degrees)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var duration := 0.0
	if weapon != null:
		match _phase:
			"windup": duration = weapon.windup
			"active": duration = weapon.active
			"recovery": duration = weapon.recovery
	_t = 1.0 if duration <= 0.0 else minf(1.0, _t + delta / duration)
	_blade_angle = lerpf(_phase_start_angle, _phase_target_angle, _t)
	blade.rotation = _blade_angle - deg_to_rad(art_angle_degrees)
