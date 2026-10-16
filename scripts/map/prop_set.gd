class_name PropSet
extends Resource
## One sprite sheet plus the rectangles (regions) of the sprites on it. Props are NOT on a clean
## grid, so the regions are listed by hand (see tools/extract_sprites.py). Swapping the art =
## a new PropSet in the MapStyle, no code change.

@export var texture: Texture2D
@export var regions: Array[Rect2] = []
## Collision radius per region, in SCREEN pixels (only obstacles read it). Empty = no collision.
@export var radii: PackedFloat32Array = PackedFloat32Array()
## Deco only: may this set sit on dirt patches? (flowers on bare dirt look wrong, pebbles do not)
@export var on_dirt := false
## Deco only: how often this set is picked, relative to the other sets.
@export var weight := 1.0
## Deco only: pick weight per island area (forest, rocky, boss), multiplied with `weight`. 0 = never there.
@export var area_weights := Vector3.ONE
