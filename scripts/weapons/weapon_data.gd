extends Resource
class_name WeaponData
## Data-driven weapon numbers. A new weapon is a new .tres file, zero code.

@export_enum("arc", "projectile") var behavior := "arc"
## HUD hotbar look. Both optional: no icon = the model's Art sprite is shown; no name = the file name prettified.
@export var icon: Texture2D
@export var display_name := ""
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
