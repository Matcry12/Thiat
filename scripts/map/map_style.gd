class_name MapStyle
extends Resource
## All the ART of a generated arena: which texture, which tile coordinates, which prop rectangles.
## MapGen and ArenaMap contain no coordinates. A new look (snow, desert) = a new .tres.
##
## Ground model: a full DIRT layer below, a GRASS layer above. Grass has "holes" (rectangles);
## the hole shows the dirt. The tile set only has pieces for rectangular holes >= 2x2 cells.

@export var tile_size := 16
## On-screen size of one art pixel. 2 = a 16px tile is 32px on screen (same as the swing FX).
@export var pixel_scale := 2

## Opaque dirt tiles, random pick per cell.
@export var dirt_fills: Array[Vector2i] = []
## Full grass tiles, random pick per cell.
@export var grass_fills: Array[Vector2i] = []
## Darker full grass tiles (used only where dark_grass_chance says so).
@export var grass_dark_fills: Array[Vector2i] = []
## Island areas (v1, decision 0026). Empty = use dirt_fills (placeholder look).
@export var rocky_fills: Array[Vector2i] = []
@export var boss_fills: Array[Vector2i] = []
@export var water_fills: Array[Vector2i] = []
## Shows where there is no water art (the Background colour behind everything).
@export var water_color := Color(0.18, 0.42, 0.62, 1)

## Pixel Plains ground (SnowHex pack, data/maps/ground_pixel_plains.tres): the island ground is drawn from the pack's own quarters with no
## tint, and the things that clash (trees, vegetation, dirt stamps) are hidden. null = no island ground (flat map only).
@export var pixel_plains: PixelPlainsGround
## The climate biomes, in the order of MapGen.Biome (decision 0038, data/biomes/*.tres). Empty = no island.
@export var biomes: Array[BiomeData] = []
## Foam on the shore and the shimmer are numbers on ArenaMap (F3 Map).

## Edge pieces of look-variant A. Keys:
##   hole corners  nw ne sw se
##   ring on the grass around the hole  n_l n_m n_r  s_l s_m s_r  w_t w_m w_b  e_t e_m e_b
##   (n/s = ring row above/below, l/m/r = left end / middle / right end;
##    w/e = ring column left/right, t/m/b = top end / middle / bottom end)
@export var edge_tiles: Dictionary = {}
## Look-variant B is variant A shifted down by this many rows. 0 = only one variant.
@export var variant_row_offset := 5

## Bushes around the walls (visual only; the walls already collide).
@export var border: PropSet
## Small stuff scattered on the floor.
@export var deco: Array[PropSet] = []
## Rocks that block movement.
@export var obstacles: PropSet
## Gatherable trees / rocks placed by area on the island (index = the "node" key of an obstacle).
@export var resource_nodes: Array[ResourceNodeData] = []


## Atlas coordinate of an edge role in the given look-variant (0 = A, 1 = B).
func edge(role: String, variant: int) -> Vector2i:
	var c: Vector2i = edge_tiles[role]
	if variant_row_offset > 0:
		c.y += variant_row_offset * variant
	return c


func variant_count() -> int:
	return 2 if variant_row_offset > 0 else 1
