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
## amendment, how far the blade's hit wedge TRAVELS during the active frame —
## so the drawn sweep and the hit area can't disagree.
@export var arc_degrees := 90.0
## How far the hit sector reaches (bán kính). Feeds SectorShape.radius.
@export var radius := 50.0
## How THICK the blade's hit area is, in degrees (a narrow wedge, not the whole
## sweep). The blade carries this wedge and sweeps it through `arc_degrees`
## during the active frame, so an enemy is hit only when the blade actually
## reaches them — not instantly across the whole cone.
@export var blade_width_degrees := 22.0
@export var color := Color.WHITE
