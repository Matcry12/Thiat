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
## amendment, the angle of the GENERATED hit sector (SectorShape) — so the
## drawn sweep and the hit area can't disagree.
@export var arc_degrees := 90.0
## How far the hit sector reaches (bán kính). Feeds SectorShape.radius.
@export var radius := 50.0
@export var color := Color.WHITE
