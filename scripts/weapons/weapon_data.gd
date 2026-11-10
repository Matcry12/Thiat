extends Resource
class_name WeaponData
## Data-driven weapon numbers. A new weapon is a new .tres file, zero code.

@export_enum("arc", "projectile") var behavior := "arc"
## HUD hotbar look. Both optional: no icon = the model's Art sprite is shown; no name = the file name prettified.
@export var icon: Texture2D
@export var display_name := ""
## How it sounds (data/sounds/*.tres): `hit` filled = this weapon makes the impact sound itself (arrows); else the target does. `swing` = whoosh.
@export var sound_set: SoundSet
@export var damage := 30.0
## Gathering (v1 §4). HP taken from a tree/rock per hit; 0 = this weapon can't gather.
@export var gather_damage := 0.0
## Must be >= the node's required_power, or the hit only clinks.
@export var tool_power := 0
## "axe" / "pickaxe" / empty. A node with a matching `preferred_tool` takes `tool_bonus` times the gather_damage.
@export var tool_kind: StringName = &""
@export var windup := 0.15
@export var active := 0.1
@export var recovery := 0.2
## The weapon's own scene (Step 1, decision-driven model split). Root = the
## grip/hand point. Children, hand-placed by the user, never written by code:
## `Art` (Sprite2D), optional `Hitbox` (melee) / `Muzzle` (ranged spawn point).
@export var model: PackedScene
## Idle hold angle, relative to aim (WeaponVisual used to own this; it is a
## per-weapon number, not a per-player one — a bow rests pointing at the mouse).
@export_range(-180.0, 180.0, 2, "or_greater", "or_less") var rest_angle_degrees := -45.0

## behavior == "projectile" only.
@export var projectile_scene: PackedScene
@export var projectile_speed := 700.0
@export var projectile_range := 520.0
## How far the blade sweeps during the active frame. One number, two jobs:
## it drives the blade's visual swing (WeaponVisual) AND, since the 0011
## How far the swing travels, CENTRED ON THE AIM: the blade pulls back to
## -arc/2 and sweeps to +arc/2, so mid-swing it points at the cursor.
## Reach is not a number here — it is whatever the hitbox shape reaches.
@export_range(10.0, 360.0, 2, "or_greater", "or_less") var arc_degrees := 90.0
## Snap swings (decision 0020): on the first physics frame of ACTIVE the hit
## shape is tried at this many angles across the arc. 12 = about 8 deg apart for 90 deg.
@export var sweep_samples := 12
## How the swing LOOKS and HITS (grip path, wrist, afterimages; the hit area follows the same path, 0050); null = the old fixed-pivot swing with crescent slash. Decision 0049.
@export var swing_motion: SwingMotion
## Only with a swing_motion (0050). false = snap: on the first physics frame of active the hit shape is tried along the WHOLE blade path.
## true = progressive: each physics frame of active tries the poses between last frame and this one, so a far target is hit only when the blade gets there.
@export var hit_follows_blade := false
@export_group("Hit area from picture")
## Live: every setter emits `changed`, WeaponVisual refits the held model at once (F3 edits show up without a swap).
## true = when the model is built, the Hitbox rectangle is measured from the Art picture (0061). false = keep the scene's hand-set shape and Tip.
@export var hit_auto_fit := true: set = _set_fit_auto
## Added past the farthest visible pixel along the blade (px). 8 reproduces the old hand values.
@export var hit_tip_margin := 8.0: set = _set_fit_tip
## Added to the blade's median thickness (px). A crossguard does not widen it.
@export var hit_width_margin := 2.5: set = _set_fit_width
## The hit area is never thinner than this (px).
@export var hit_min_width := 9.0: set = _set_fit_min
## A picture pixel counts as visible when its alpha is above this (0..1). Keeps one stray faint pixel from stretching the reach.
@export_range(0.0, 1.0, 0.01) var hit_alpha_min := 0.5: set = _set_fit_alpha
## When the measured blade centre line is further than this (px) from the shape's line (y), the status says OFF AXIS and a warning is logged once.
## The picture's offset / rotation (grip + angle) are still set per picture; length and width are automatic.
@export var hit_axis_warn_px := 4.0: set = _set_fit_axis
@export_group("")
@export_group("Art fit")
## Live (F3): size / place / turn of the weapon PICTURE only. The grip stays the origin. All 0 = exactly the scene's own Art.
## 0 = keep the scene's scale, 0.05..4 = that scale. Decimals are fine; whole sizes stay sharpest.
@export_range(0.0, 4.0, 0.05) var art_scale := 0.0: set = _set_art_scale
## Moves the picture in the model's px (x along the blade, y across it), on top of the scene's Art position.
@export var art_nudge_x := 0.0: set = _set_art_nx
@export var art_nudge_y := 0.0: set = _set_art_ny
## Added to the scene's Art rotation (degrees).
@export_range(-180.0, 180.0, 0.5, "or_greater", "or_less") var art_turn_deg := 0.0: set = _set_art_turn
@export_group("")
@export_group("Tool target")
## Tools only (tool_kind set). On the first frame of active, the nearest gatherable node this far from the user (px, edge of the node) AND inside the cone around the REAL aim gets the hit,
## even if the picture lands beside it (0050 addendum). 0 = off (the blade alone decides). The node is hit once per swing; the blade skips it.
@export var tool_target_reach := 0.0
## Full width of the cone around the real aim (degrees) a node must be inside.
@export_range(10.0, 360.0, 1.0) var tool_target_cone_deg := 70.0
## When the target hit lands, as a share of the active phase (0 = first frame, 1 = last). Set so the hit number drops on the frame the tool reaches the node.
@export_range(0.0, 1.0, 0.05) var tool_target_hit_t := 0.6
@export_group("")
@export var color := Color.WHITE
## Colours the model's picture (copper tools reuse the stone tool's model, tinted). White = as drawn.
@export var model_tint := Color.WHITE
## Melee only: the swing carries the user this many px forward (aim direction) from windup to the end of active.
## Moves the body with move_and_collide, so it stops at walls and bodies. 0 = no step (the bow).
@export_range(0.0, 60.0, 0.2, "or_greater", "or_less") var step_distance := 0.0
## False = unparryable (purple telegraph) — cannot be parried or blocked.
@export var parryable := true
## The block pose: where the blade is held while F is down, in degrees relative
## to the aim (0 = pointing at the mouse). -90 = raised straight across the
## attack line, edge toward the mouse. Per WEAPON, not per player: a hammer or
## a spear holds a guard differently, and that is one number, not an animation.
@export var guard_angle_degrees := -90.0
## Where the arm moves for the guard, in pixels, relative to the aim:
## forward = toward the mouse (a spear thrusts its guard out), side = across it
## (a hammer pulls in to the body). 0/0 = the guard happens where the hand is.
## Two floats, not a Vector2, so they appear in the F3 panel as sliders.
@export var guard_forward := 0.0
@export var guard_side := 0.0

## The E skill: a SCENE whose root extends Skill (decision 0018). A new skill is
## a new scene, nothing else changes. Cooldown is per weapon, kept by SkillSlot.
@export var skill: PackedScene
@export var skill_cooldown := 6.0

## Name shown in the hotbar: display_name, else "iron_sword.tres" -> "Iron Sword".
func item_name() -> String:
	if display_name != "":
		return display_name
	if resource_path != "":
		return resource_path.get_file().get_basename().replace("_", " ").capitalize()
	return "Weapon"


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
## F3 section name: the file name, capitalised ("Wooden Sword"); "Weapon" for an unsaved one.
func debug_name() -> String:
	return "Weapon" if resource_path == "" else resource_path.get_file().get_basename().capitalize()


func _set_fit_auto(v: bool) -> void:
	hit_auto_fit = v
	emit_changed()
func _set_fit_tip(v: float) -> void:
	hit_tip_margin = v
	emit_changed()
func _set_fit_width(v: float) -> void:
	hit_width_margin = v
	emit_changed()
func _set_fit_min(v: float) -> void:
	hit_min_width = v
	emit_changed()
func _set_fit_alpha(v: float) -> void:
	hit_alpha_min = v
	emit_changed()
func _set_fit_axis(v: float) -> void:
	hit_axis_warn_px = v
	emit_changed()
func _set_art_scale(v: float) -> void:
	art_scale = clampf(v, 0.0, 4.0)
	emit_changed()
func _set_art_nx(v: float) -> void:
	art_nudge_x = v
	emit_changed()
func _set_art_ny(v: float) -> void:
	art_nudge_y = v
	emit_changed()
func _set_art_turn(v: float) -> void:
	art_turn_deg = v
	emit_changed()
