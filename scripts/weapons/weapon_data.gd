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
