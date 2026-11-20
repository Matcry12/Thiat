@tool
extends Resource
class_name ChestHoldData
## Where a non-weapon item (bread, wood, workbench) sits when both hands carry it in front of the chest, plus the
## eating bob. One .tres (`data/held_item/chest_hold.tres`): F3 "Write to .tres" keeps the tuning.
## Swap-in note: new art changes these numbers, no code. World px, facing right; facing left mirrors x.

## Item centre x from the player origin.
@export var offset_x := 3.0
## Height of both hands (px from the player origin, same as the resting hands). Fixed: the item rests on them.
@export var hand_y := -5.5
## How far the item's bottom edge sinks below the hands' centre (px), so the hands peek out under it.
@export var rest_overlap := 3.0
## World px the icon's whole canvas takes (32 px bread and 16 px gel end up the same size, like in the bag).
@export var icon_size := 25.6
## Each hand sits at least this far (px) left / right of the picture centre.
@export var hand_min_spread := 6.0
## Draw layer of the picture (absolute): above the hands (hold_z).
@export var z := 3
## Eating / drinking: the item AND both hands bob up this far (px) and back. Whole steps, never a blurry slide.
@export var bob_px := 3.0
## Bobs per second while eating.
@export var bob_hz := 5.0
