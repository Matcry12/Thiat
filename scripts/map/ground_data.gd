class_name GroundData
extends Resource
## One kind of ground on the island (dirt / cobble / grass ...): which tiles draw it. Ground is drawn in layers;
## a ground with a higher `layer` lies over every ground with a lower one. GroundBaker draws the border between
## two grounds with the DUAL-GRID method: one display tile per cell CORNER reads the 4 cells around it (16 cases).
## All 16 cases are built from ONE straight-edge picture (`edge_window`) of the same pack, so no tile has to be
## guessed per case and the seams always match. A new look = a new .tres, no code change.

@export var id: StringName = &""
## 1 = lowest ground (over water). Same layer = same look family (forest grass and boss grass share one).
@export var layer := 1:
	set(v):
		layer = v
		emit_changed()
@export var texture: Texture2D
@export var tile_size := 16
## Opaque tiles on `texture`, picked per cell (seeded), also mirrored, so the grid does not show.
@export var fills: Array[Vector2i] = []
## The edge picture. A 16x16 pixel window (x, y, 16, 16) on `edge_texture` (null = `texture`) where THIS ground is in the
## top half and the other ground / water below it, the border running through the middle (row 8). Look at
## docs/demo/map_v2_tile_test.png / the mapping pictures in docs/wiki/ground-tiles.md before changing it.
@export var edge_texture: Texture2D
@export var edge_window := Rect2i(0, 0, 16, 16)
## How to read "this ground" in the window: 0 = the picture has real transparency (the other ground is see-through),
## 1 = the picture is opaque and this ground is the GREEN pixels (Serene Village autotiles).
@export_enum("alpha", "green") var edge_key := 0:
	set(v):
		edge_key = v
		emit_changed()
## true = the edge keeps the window's SHAPE but is coloured with this ground's `fills`. Same pack only.
@export var edge_from_fills := false:
	set(v):
		edge_from_fills = v
		emit_changed()
## Only with edge_from_fills: opaque pixels beside the edge are multiplied by this (1 = no outline).
@export var rim_darken := 0.82:
	set(v):
		rim_darken = v
		emit_changed()
## Art px rounded off the outer corner of a one-cell corner piece.
@export var corner_cut := 2:
	set(v):
		corner_cut = v
		emit_changed()
## true = green specks in the fill tiles are painted over with the tile's main colour (Serene Village dirt has grass tufts).
@export var fill_scrub_green := false:
	set(v):
		fill_scrub_green = v
		emit_changed()
## Colour of THIS ground's own pixels (fills and edge pieces), applied when the pieces are built: brightness, warm
## (+ redder, - bluer) and saturation. Used for the boss grass, so its edge pixels over the cobble are tinted too (a screen
## tint by cell would leave a bright green line there). 1 / 0 / 1 = unchanged.
@export var bright := 1.0:
	set(v):
		bright = v
		emit_changed()
@export var warm := 0.0:
	set(v):
		warm = v
		emit_changed()
@export var sat := 1.0:
	set(v):
		sat = v
		emit_changed()
