extends Node2D
class_name ActorVisual
## The contract every character visual implements (decision 0010). Combat and
## movement code call ONLY these five methods and never reach inside a visual
## node (decision 0005) — that is what makes swapping art a file replacement,
## not a code change.
##
## Example: `SpriteActorVisual` (placeholder, today) satisfies this contract.
## A future `AnimatedSprite2D`-based visual subclasses `ActorVisual` too, and
## nothing outside the visual script changes — `player.gd` still just calls
## `visual.set_move_state(...)`.
##
## `flash()` is called by the hit effects (HitFx), never by combat code.
##
## Every method has a working no-op default so a subclass can override only
## the ones it needs.

## "idle" | "run" — lets the visual play the right pose/animation.
func set_move_state(_state: String) -> void:
	pass

## The direction the character is facing (usually the aim direction). The
## visual decides flip/animation from this; combat code never sets rotation
## directly (2.5D bodies never rotate with aim, decision 0009).
func set_facing(_dir: Vector2) -> void:
	pass

## "idle" | "windup" | "active" | "recovery" — weapon swing feedback (tint).
func set_weapon_state(_state: String) -> void:
	pass

## Radians. Only used for things that DO rotate with aim (e.g. an indicator);
## the body itself must not rotate (decision 0009).
func set_aim_angle(_angle: float) -> void:
	pass

## Hit flash: tint the body `color` for `duration` s. The default flashes `flash_target()` with the shared
## HitFlash shader; a sprite visual only overrides `flash_target()` (or this whole method, for an animated one).
func flash(color: Color, duration: float) -> void:
	HitFlash.play(self, flash_target(), color, duration)

## The CanvasItem that should turn white: the body, never the shadow. Default: this node.
func flash_target() -> CanvasItem:
	return self
