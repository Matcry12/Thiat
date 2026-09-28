extends Resource
class_name WeaponData
## Data-driven weapon numbers. A new weapon is a new .tres file, zero code.

@export_enum("arc") var behavior := "arc"
@export var damage := 30.0
@export var windup := 0.15
@export var active := 0.1
@export var recovery := 0.2
## How far the blade sweeps during the active frame. One number, two jobs:
## it drives the blade's visual swing (WeaponVisual) AND, since the 0011
## How far the swing travels, CENTRED ON THE AIM: the blade pulls back to
## -arc/2 and sweeps to +arc/2, so mid-swing it points at the cursor.
## Reach is not a number here — it is whatever the hitbox shape reaches.
@export var arc_degrees := 90.0
@export var color := Color.WHITE
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
