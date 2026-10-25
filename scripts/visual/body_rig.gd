@tool
extends Resource
class_name BodyRig
## ONE per-character visual setting (decision 0028): everything that makes a body, its hands and its weapon pictures fit
## together. SpriteActorVisual applies it to the body sprite, the shadow and (through their `apply_rig()`) to WeaponVisual,
## Hands and SwingFx. Swapping the character = swapping this one resource (`Visual > rig` in player.tscn).
## VISUAL ONLY: hitboxes, reach, muzzles and timings are never scaled (WeaponVisual keeps their world transform).
## Every number is an @export, so F3 shows and tunes it live (setters emit `changed`, the visuals re-apply).

@export var display_name := "rig"
## The body's animations (idle_front / idle_side / run_* / hit_* for a directional set, idle_side / run_side / hit_side only for a side-view-only set like the Tiny RPG soldier, or plain idle / run for the old drawn art).
@export var sprite_frames: SpriteFrames: set = _set_frames
## Body sprite transform. Position is chosen so the FEET sit on the actor origin (the shadow, hands and weapon stay put).
@export var body_position := Vector2(0, -19): set = _set_body_position
@export var body_scale := Vector2(2, 2): set = _set_body_scale
## Shadow size multiplier (the shadow sprite's own scale is the 1.0 reference).
@export_range(0.2, 3.0, 0.01) var shadow_scale := 1.0: set = _set_shadow_scale

@export_group("Weapon + hands (visual only)")
## Scales the weapon ART and the hand offsets along the weapon (models: sword, bow, fists). The hitbox / muzzle keep their size and place.
@export_range(0.2, 2.0, 0.01) var visual_scale := 1.0: set = _set_visual_scale
## Scales the slash crescent (SwingFx). The crescent is drawn from the real hitbox shape, so values below 1 show LESS than the real reach:
## set 1.0 to see the true hit area, or = visual_scale to match the smaller sword.
@export_range(0.2, 2.0, 0.01) var slash_scale := 1.0: set = _set_slash_scale
## (WeaponVisual / Hands stay at the actor's gameplay pivot: the hitbox and muzzle hang off it, so it is NOT a per-character value.)
@export_range(1.0, 8.0, 0.5) var hand_radius := 5.0: set = _set_hand_radius
## No-weapon rest hands, in AIM space: x = toward the aim, y = to the right of it.
@export var hand_rest_main := Vector2(6, 15): set = _set_hand_rest_main
@export var hand_rest_off := Vector2(6, -15): set = _set_hand_rest_off

@export_group("Relaxed hands (bare hands idle + walk)")
## Screen space relative to the Hands pivot: x = toward facing (mirrored when facing left), y = down.
@export var hand_idle_front := Vector2(-16, -1): set = _set_hand_idle_front
@export var hand_idle_back := Vector2(15, 1): set = _set_hand_idle_back
## Walk swing: opposite hands move +-x, lift y; speed in rad/s.
@export var hand_sway_x := 5.0: set = _set_hand_sway_x
@export var hand_sway_y := 2.0: set = _set_hand_sway_y
@export var hand_sway_speed := 14.0: set = _set_hand_sway_speed

@export_group("Run cycle frames (directional / side-only sets)")
## Frames of the run animation where a foot lands (RunDust puff) and where the body is highest (shadow shrinks).
## Empty = use the values on the SpriteActorVisual (made for the 6-frame blocky run; a longer cycle needs its own).
@export var landing_frames := PackedInt32Array(): set = _set_landing_frames
@export var lift_frames := PackedInt32Array(): set = _set_lift_frames

func _set_landing_frames(v: PackedInt32Array) -> void:
	landing_frames = v
	emit_changed()
func _set_lift_frames(v: PackedInt32Array) -> void:
	lift_frames = v
	emit_changed()
func _set_frames(v: SpriteFrames) -> void:
	sprite_frames = v
	emit_changed()
func _set_body_position(v: Vector2) -> void:
	body_position = v
	emit_changed()
func _set_body_scale(v: Vector2) -> void:
	body_scale = v
	emit_changed()
func _set_shadow_scale(v: float) -> void:
	shadow_scale = v
	emit_changed()
func _set_visual_scale(v: float) -> void:
	visual_scale = v
	emit_changed()
func _set_slash_scale(v: float) -> void:
	slash_scale = v
	emit_changed()
func _set_hand_radius(v: float) -> void:
	hand_radius = v
	emit_changed()
func _set_hand_rest_main(v: Vector2) -> void:
	hand_rest_main = v
	emit_changed()
func _set_hand_rest_off(v: Vector2) -> void:
	hand_rest_off = v
	emit_changed()

func _set_hand_idle_front(v: Vector2) -> void:
	hand_idle_front = v
	emit_changed()
func _set_hand_idle_back(v: Vector2) -> void:
	hand_idle_back = v
	emit_changed()
func _set_hand_sway_x(v: float) -> void:
	hand_sway_x = v
	emit_changed()
func _set_hand_sway_y(v: float) -> void:
	hand_sway_y = v
	emit_changed()
func _set_hand_sway_speed(v: float) -> void:
	hand_sway_speed = v
	emit_changed()

## Last F3 `Save rig` result (not saved into the file).
var save_note := ""

func status_text() -> String:
	return "rig %s: visual_scale %.2f  slash %.2f  hand r %.1f  shadow %.2f%s" % [display_name, visual_scale, slash_scale, hand_radius, shadow_scale, ("  [" + save_note + "]") if save_note else ""]
