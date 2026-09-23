extends Resource
class_name WeaponData
## Data-driven weapon numbers. A new weapon is a new .tres file, zero code.

@export_enum("arc") var behavior := "arc"
@export var damage := 30.0
@export var windup := 0.15
@export var active := 0.1
@export var recovery := 0.2
## How far the blade sweeps during the active frame — a motion property that
## moves the hit area, not a filter on it. The hit area itself is the Hitbox
## shape parented under WeaponVisual/Blade (decision 0011).
@export var arc_degrees := 90.0
@export var color := Color.WHITE
