class_name ResourceNodeData
extends Resource
## One kind of gatherable (tree, rock, copper rock). Numbers and art live here; ResourceNode just runs them.

@export var id: StringName = &""
@export var display_name := ""
@export var max_hp := 6.0
## A weapon needs at least this tool_power to damage it; less = clink.
@export var required_power := 0
## The tool_kind that gathers this fast (trees: axe, rocks: pickaxe). Empty = no favourite.
@export var preferred_tool: StringName = &""
## gather_damage multiplier when the held tool_kind matches `preferred_tool`.
@export var tool_bonus := 3.0
@export var drop_item: ItemData
## Seconds without a hit before the node is back to full HP (Minecraft: progress resets). 0 = never.
@export var reset_delay := 1.5
## true = broken without `preferred_tool` drops nothing (rocks). Trees drop by hand.
@export var drop_needs_tool := false
@export var drop_min := 2
@export var drop_max := 3
## Collision circle, screen px.
@export var radius := 14.0
## How much bigger the gather Hurtbox circle is than the body, px.
@export var hurtbox_pad := 6.0
## Drop spread when no Collector exists, px.
@export var drop_scatter := 26.0
## Nodes per 100 land cells. `density_forest` = anywhere outside the boss land (0038 step 4: only read when the aged trees are off, `trees_on`;
## rocks and copper are scattered per biome: BiomeData.rock_nodes_per_100 / copper_per_100). `density_boss` = on the boss land.
@export var density_forest := 0.0
@export var density_boss := 0.0
@export_group("Art")
@export var texture: Texture2D
## Look variants (rects on `texture`).
@export var regions: Array[Rect2] = []
## More looks. Placement never picks these (it keeps using `regions`, so a seed gives the same trees);
## the island areas below do. Look index = position in regions + extra_regions.
@export var extra_regions: Array[Rect2] = []
## Where the feet are, in art pixels of each `regions` entry (same order). Empty = bottom centre of the picture.
## The foot is drawn on the bottom of the collision circle.
@export var anchors: PackedVector2Array = PackedVector2Array()
## Which looks each island area may show (indices as above). Empty = whatever placement picked.
## Forest: green trees. Rocky: autumn and dead ones. Boss: dead ones.
@export var looks_forest: PackedInt32Array = PackedInt32Array()
@export var looks_rocky: PackedInt32Array = PackedInt32Array()
@export var looks_boss: PackedInt32Array = PackedInt32Array()
## What stays after it breaks (a stump). Empty = nothing stays.
@export var remains_region := Rect2()
@export var pixel_scale := 2
## Body alpha while the player stands hidden behind the picture.
@export var fade_when_behind := false
@export_range(0.0, 1.0) var fade_alpha := 0.45
## Placeholder colour when there is no texture.
@export var color := Color.WHITE
@export_group("Hit feel")
@export var hit_type: StringName = &"chop"
@export var clink_type: StringName = &"clink"
@export var break_type: StringName = &"node_break"


## Foot point of look `i` in art pixels of its region (bottom centre when no anchor is set).
func anchor_for(i: int) -> Vector2:
	var r := all_regions()[i % all_regions().size()]
	return anchors[i] if i < anchors.size() and i < regions.size() else Vector2(r.size.x * 0.5, r.size.y)


func all_regions() -> Array[Rect2]:
	var out := regions.duplicate()
	out.append_array(extra_regions)
	return out


## Look index for a node in island `area` (0 forest, 1 rocky, 2 boss); `pick` is any stable int (a hash).
## -1 = this area has no list: keep what placement picked.
func look_for(area: int, pick: int) -> int:
	var list: PackedInt32Array = [looks_forest, looks_rocky, looks_boss][clampi(area, 0, 2)]
	return -1 if list.is_empty() else list[pick % list.size()]
