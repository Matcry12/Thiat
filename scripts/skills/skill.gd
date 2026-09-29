extends Node2D
class_name Skill
## Base for a weapon's E skill (decision 0018). A skill is a small SCENE whose
## root extends this; WeaponData.skill points at it. A new skill = a new scene,
## zero changes elsewhere. Like the components, a skill never reads Input:
## SkillSlot starts it, and writes `aim_direction` every frame.

signal finished
## "idle" / "charge" / "active": lets charge art or a trail plug in later.
signal state_changed(state: String)

## Shown in the HUD ("E: <skill_name> ready").
@export var skill_name := "Skill"

## Written by SkillSlot every frame (a skill that fires later, like a charged
## shot, aims where the player looks NOW, not where they looked at the press).
var aim_direction := Vector2.RIGHT
## Written once by SkillSlot: lets a skill find the Muzzle of the equipped model.
var weapon_holder: WeaponHolder

func activate(_user: Node2D, _aim: Vector2) -> void:
	pass

## Stops the skill without its effect (dodge/guard/swap call this via SkillSlot).
func cancel() -> void:
	pass

func is_active() -> bool:
	return false

## True while the skill drives the user's velocity (like Dodge): the owner must
## then leave velocity alone.
func moves_body() -> bool:
	return false

## Multiplies the user's walk speed while the skill is active.
func move_scale() -> float:
	return 1.0

## [from, to] of the skill's reach for the F1 overlay; empty = nothing to draw.
func debug_reach(_user: Node2D, _aim: Vector2) -> PackedVector2Array:
	return PackedVector2Array()
