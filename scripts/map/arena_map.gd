class_name ArenaMap
extends Node2D
## Builds the arena floor from MapGen's plan: dirt layer, grass layer (with dirt-showing holes),
## deco, rocks (the only part that collides) and bushes along the walls. All of it sits BELOW the
## characters. Every number is an @export, so the F3 panel lists it; changing one rebuilds the map
## with the SAME seed ("New map" in F3 rolls a new one).
##
## Fair fight: rocks never touch the FightZone or the spawns, and never wall off any floor
## (see MapGen). Dirt patches are looks only.
##
## ArenaMap is the ONE owner of: the outer walls (built from map_cols x map_rows), the player's
## Camera2D (child of the player, limits = the map), the Background size, and where the FightZone,
## Boss, Player and Dummy start. Layout is a pure function of the exports below (no seed, no live
## node positions), so the same exports always give the same layout. Moving those nodes in the
## editor has no effect: change the numbers here (a size/layout change in F3 moves them again).

## patch_count and obstacle_count are "per screen-sized area" (36 x 21 cells) and scale with the
## map, so density stays the same on a bigger map.
const RESOURCE_NODE := preload("res://scenes/world/resource_node.tscn")
const REF_CELLS := 36 * 21

## Emitted at the end of every rebuild (new world data): the F3 World map panel redraws on it.
signal rebuilt

@export_group("Layout")
## Map size in cells (1 cell = tile_size * pixel_scale px = 32). 72 x 40 = 2304 x 1280 px = 2x the screen.
@export_range(12, 1024) var map_cols := 512:
	set(v):
		map_cols = v
		_changed(false, true)
@export_range(12, 1024) var map_rows := 512:
	set(v):
		map_rows = v
		_changed(false, true)
## The boss zone (= the aggro zone). Its centre is a fraction of the map, so it follows the size.
@export var zone_width := 880.0:
	set(v):
		zone_width = v
		_changed(false, true)
@export var zone_height := 460.0:
	set(v):
		zone_height = v
		_changed(false, true)
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var zone_x := 0.86:
	set(v):
		zone_x = v
		_changed(false, true)
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var zone_y := 0.5:
	set(v):
		zone_y = v
		_changed(false, true)
## The boss waits this many px to the right of the zone centre.
@export var boss_offset_x := 220.0:
	set(v):
		boss_offset_x = v
		_changed(false, true)
## The player starts here (fraction of the map): far left, outside the zone.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var player_spawn_x := 0.12:
	set(v):
		player_spawn_x = v
		_changed(false, true)
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var player_spawn_y := 0.5:
	set(v):
		player_spawn_y = v
		_changed(false, true)
## The training dummy stands this far from the player's spawn.
@export_range(-600.0, 600.0, 5, "or_greater", "or_less") var dummy_offset_x := 290.0:
	set(v):
		dummy_offset_x = v
		_changed(false, true)
@export_range(-600.0, 600.0, 5, "or_greater", "or_less") var dummy_offset_y := -190.0:
	set(v):
		dummy_offset_y = v
		_changed(false, true)
@export var camera_smoothing := true:
	set(v):
		camera_smoothing = v
		_apply_camera()
## Higher = snappier. 7 is mild.
@export var camera_smoothing_speed := 7.0:
	set(v):
		camera_smoothing_speed = v
		_apply_camera()

## Camera zoom (+ / - keys). 1 = normal, 2 = twice as close.
@export var camera_zoom := 1.0:
	set(v):
		camera_zoom = clampf(v, zoom_min, zoom_max)
@export var zoom_min := 0.75
@export var zoom_max := 2.0
@export var zoom_step := 0.25
## Higher = snappier zoom glide.
@export var zoom_lerp_speed := 10.0

@export_group("Chunks")
## Maps with more cells than this skip the old tile dictionaries and dirt patches (MapGen.Params.legacy_tiles): the island ground
## picture does not need them and they cost ~0.8 s at 512x512. 40000 keeps them for 200x120.
@export_range(0, 100000) var legacy_tiles_max_cells := 40000:
	set(v):
		legacy_tiles_max_cells = v
		_changed()
## Chunks (0038 step 2): the world is data; trees, rocks, props and the ground picture exist only near the player, in squares of this
## many cells. Changing it rebuilds the chunks, not the map.
@export_range(4, 128) var chunk_cells := 32:
	set(v):
		chunk_cells = clampi(v, 4, 256)
		_chunks_changed()
## Chunks within this many chunks of the player (Chebyshev) are loaded: 2 = a 5 x 5 block, enough to cover the screen with margin.
@export_range(0, 6) var load_radius := 2:
	set(v):
		load_radius = maxi(v, 0)
		_chunks_changed(false)
## Floor props taller than this (art px: bushes, foxglove, dead bushes, tall reeds) are Y-sorted sprites that hide a player standing behind them;
## shorter ones stay in the one-draw MultiMesh on the ground layer. Changing it rebuilds the chunks.
@export var ysort_min_px := 14:
	set(v):
		ysort_min_px = maxi(v, 0)
		_chunks_changed(false)
## A loaded chunk is freed only when it is further than load_radius + this (so walking along a border does not load and free the same chunk).
@export_range(0, 4) var unload_margin := 1:
	set(v):
		unload_margin = maxi(v, 0)
		_chunks_changed(false)
## At most this many chunks are built per frame (nearest first). Spawn, teleport and a new map build the 3 x 3 around the player at once.
@export_range(1, 8) var chunks_per_frame := 1:
	set(v):
		chunks_per_frame = maxi(v, 1)
@export_group("Flat map")
@export var style: MapStyle
## 0 = a new random seed every run.
@export_range(0, 9999) var map_seed := 0:
	set(v):
		map_seed = v
		_changed(true)
@export var patch_count := 4:
	set(v):
		patch_count = v
		_changed()
@export var patch_min_size := 3:
	set(v):
		patch_min_size = v
		_changed()
@export var patch_max_size := 7:
	set(v):
		patch_max_size = v
		_changed()
## Patch centres are only accepted where the noise is above this (0..1), so patches cluster.
@export_range(0.01, 0.5, 0.002, "or_greater", "or_less") var noise_frequency := 0.1:
	set(v):
		noise_frequency = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var patch_noise_threshold := 0.5:
	set(v):
		patch_noise_threshold = v
		_changed()
## Deco items per floor cell.
@export var deco_density := 0.1:
	set(v):
		deco_density = v
		_changed()
@export var deco_min_spacing := 30.0:
	set(v):
		deco_min_spacing = v
		_changed()
@export var obstacle_count := 6:
	set(v):
		obstacle_count = v
		_changed()
@export var obstacle_min_spacing := 40.0:
	set(v):
		obstacle_min_spacing = v
		_changed()
@export var spawn_clear_radius := 110.0:
	set(v):
		spawn_clear_radius = v
		_changed()
@export_range(0.1, 2.0, 0.01, "or_greater", "or_less") var border_density := 0.9:
	set(v):
		border_density = v
		_changed()
## Share of the grass that is the darker kind (smooth noise, so it forms meadows).
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var dark_grass_chance := 0.0:
	set(v):
		dark_grass_chance = v
		_changed()
## Widest walker that must still be able to reach all the floor around the rocks.
@export var agent_radius := 14.0:
	set(v):
		agent_radius = v
		_changed()

@export_group("Island")
## Island (W1): shape of the land, the areas along home -> boss. Water is everything else.
@export var island_on := true:
	set(v):
		island_on = v
		_changed(false, true)
## Island shape (0038 step 3): continentalness noise (domain-warped) mixed with one big round blob, faded to ocean at the map edge, plus a
## ridge along the home -> boss line. Sea level = the quantile that gives `land_share`. Lengths are for 512 x 512 and shrink on a smaller map.
@export var cont_period := 230.0:
	set(v):
		cont_period = v
		_changed()
@export var cont_octaves := 4:
	set(v):
		cont_octaves = v
		_changed()
## How strongly the noise (vs the round blob) shapes the coast.
@export_range(0.0, 4.0, 0.02, "or_greater", "or_less") var cont_gain := 1.6:
	set(v):
		cont_gain = v
		_changed()
## 0 = all noise, 1 = a round island.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var cont_radial := 0.55:
	set(v):
		cont_radial = v
		_changed()
@export var cont_edge_cells := 70.0:
	set(v):
		cont_edge_cells = v
		_changed()
@export_range(0.05, 0.9, 0.005, "or_greater", "or_less") var land_share := 0.42:
	set(v):
		land_share = v
		_changed()
## Half width of the land ridge that joins home and the boss zone.
@export var neck_cells := 30.0:
	set(v):
		neck_cells = v
		_changed()
@export_range(0.0, 1.5, 0.01, "or_greater", "or_less") var neck_boost := 0.5:
	set(v):
		neck_boost = v
		_changed()
@export var coast_cells := 3:
	set(v):
		coast_cells = v
		_changed()
@export var home_clear_cells := 6:
	set(v):
		home_clear_cells = v
		_changed()
@export var corridor_half := 2:
	set(v):
		corridor_half = v
		_changed()
@export_group("Water")
## Water (0038 step 3): rivers = a ridge noise (|n| < width, only inland, wider towards the sea, must reach the sea), lakes = wet inland pockets,
## shallows = the first 1-2 ocean cells along the coast. All of it is SHALLOW water: walkable, slow, nothing is placed in it.
@export var water_on := true:
	set(v):
		water_on = v
		_changed()
@export var river_period := 260.0:
	set(v):
		river_period = v
		_changed()
@export var river_octaves := 5:
	set(v):
		river_octaves = v
		_changed()
## Half width of a river in cells, far from the sea ...
@export_range(0.0, 4.0, 0.02, "or_greater", "or_less") var river_w_inland := 2.5:
	set(v):
		river_w_inland = v
		_changed()
## ... and at the sea.
@export_range(0.0, 6.0, 0.02, "or_greater", "or_less") var river_w_sea := 3.5:
	set(v):
		river_w_sea = v
		_changed()
## Distance from the sea over which a river goes from river_w_sea to river_w_inland.
@export var river_grow_dist := 110.0:
	set(v):
		river_grow_dist = v
		_changed()
@export_range(0.0, 1.3, 0.005, "or_greater", "or_less") var river_rough_max := 0.88:
	set(v):
		river_rough_max = v
		_changed()
@export var river_min_cells := 600:
	set(v):
		river_min_cells = v
		_changed()
## A river must get at least this far from the sea somewhere (else it only hugs the coast and is dropped).
@export var river_inland_min := 22.0:
	set(v):
		river_inland_min = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var lake_humid_min := 0.35:
	set(v):
		lake_humid_min = v
		_changed()
@export var lake_inland_min := 8.0:
	set(v):
		lake_inland_min = v
		_changed()
@export_range(0.0, 1.3, 0.005, "or_greater", "or_less") var lake_rough_max := 0.85:
	set(v):
		lake_rough_max = v
		_changed()
@export var lake_min_cells := 400:
	set(v):
		lake_min_cells = v
		_changed()
## After rivers and lakes: any fresh-water body smaller than this (cells) is land again (no 1-3 cell specks, no stub river pieces).
@export var water_min_cells := 40:
	set(v):
		water_min_cells = v
		_changed()
## The longest rivers (by cells) are widened ...
@export var river_big_n := 2:
	set(v):
		river_big_n = v
		_changed()
## ... to this half width far from the sea ...
@export var river_big_w_inland := 4.5:
	set(v):
		river_big_w_inland = v
		_changed()
## ... and at the sea (a 7-12 wide mouth).
@export var river_big_w_sea := 8.0:
	set(v):
		river_big_w_sea = v
		_changed()
## A big river may take cells this far from its thin version.
@export var river_big_reach := 3:
	set(v):
		river_big_reach = v
		_changed()
## Landmark lakes (radius lake_big_r_min..max cells).
@export var lake_big_n := 4:
	set(v):
		lake_big_n = v
		_changed()
@export var lake_big_r_min := 16.0:
	set(v):
		lake_big_r_min = v
		_changed()
@export var lake_big_r_max := 22.0:
	set(v):
		lake_big_r_max = v
		_changed()
## This many big lakes sit ON a river path (the river flows through).
@export var lake_big_on_river := 2:
	set(v):
		lake_big_on_river = v
		_changed()
## Small ponds, clustered where the wetness noise is high and some next to rivers.
@export var lake_pond_n := 0:
	set(v):
		lake_pond_n = v
		_changed()
@export var lake_pond_r_min := 1.5:
	set(v):
		lake_pond_r_min = v
		_changed()
@export var lake_pond_r_max := 4.0:
	set(v):
		lake_pond_r_max = v
		_changed()
## Share of ponds next to a river.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var lake_pond_on_river := 0.3:
	set(v):
		lake_pond_on_river = v
		_changed()
## Ponds only where the wetness noise rank (0..1 over the land) is above this.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var lake_pond_wet_min := 0.62:
	set(v):
		lake_pond_wet_min = v
		_changed()
## Cells per wetness bump.
@export var lake_pond_wet_period := 70.0:
	set(v):
		lake_pond_wet_period = v
		_changed()
## A pond blob is stretched this much along a random direction ...
@export var lake_pond_stretch_min := 1.0:
	set(v):
		lake_pond_stretch_min = v
		_changed()
@export var lake_pond_stretch_max := 2.4:
	set(v):
		lake_pond_stretch_max = v
		_changed()
## ... and 1-3 blobs are merged into one pond.
@export var lake_pond_blobs_min := 1:
	set(v):
		lake_pond_blobs_min = v
		_changed()
@export var lake_pond_blobs_max := 3:
	set(v):
		lake_pond_blobs_max = v
		_changed()
## Lake edge irregularity (noise strength, in radii).
@export var lake_warp := 3.5:
	set(v):
		lake_warp = v
		_changed()
## Cells per wobble of a lake edge.
@export var lake_shape_period := 30.0:
	set(v):
		lake_shape_period = v
		_changed()
## Cells kept between two big lakes.
@export var lake_gap := 8:
	set(v):
		lake_gap = v
		_changed()
## Land shore around a river / lake (BiomeData.shore_ground): 1 ring, 2 rings, 1.5 = a ragged second ring.
@export_range(0.0, 3.0, 0.02, "or_greater", "or_less") var shore_cells := 1.5:
	set(v):
		shore_cells = v
		_changed()
## The ocean shallows along the coast are between these many cells wide.
@export_range(0.0, 4.0, 0.02, "or_greater", "or_less") var shallow_min := 1.0:
	set(v):
		shallow_min = v
		_changed()
@export_range(0.0, 5.0, 0.02, "or_greater", "or_less") var shallow_max := 2.4:
	set(v):
		shallow_max = v
		_changed()
@export_group("Climate")
## Climate biomes (decision 0038): three smooth noise maps (temperature, humidity, roughness) decide the biome of every land cell.
## Periods = cells per wave (bigger = bigger zones), warp = how much the borders wiggle. Every change rebuilds the map.
@export var climate_temp_period: float = 600.0:   # 0038 step 2: ~2.5x the 200x120 values (120 / 60 / 40 / 36 / 11), so a 512 island has the same number of zones
	set(v):
		climate_temp_period = v
		_changed()
@export var climate_humid_period: float = 300.0:
	set(v):
		climate_humid_period = v
		_changed()
@export var climate_rough_period: float = 200.0:
	set(v):
		climate_rough_period = v
		_changed()
@export var climate_warp_period: float = 180.0:
	set(v):
		climate_warp_period = v
		_changed()
@export var climate_warp_amp: float = 28.0:
	set(v):
		climate_warp_amp = v
		_changed()
@export_range(1, 8) var climate_octaves: int = 4:
	set(v):
		climate_octaves = v
		_changed()
@export var climate_w_temp: float = 3.0:
	set(v):
		climate_w_temp = v
		_changed()
@export var climate_w_humid: float = 1.0:
	set(v):
		climate_w_humid = v
		_changed()
@export var climate_w_rough: float = 1.1:
	set(v):
		climate_w_rough = v
		_changed()
@export var climate_warp_octaves: int = 3:
	set(v):
		climate_warp_octaves = v
		_changed()
@export_group("Biomes")
@export var beach_noise_period: float = 20.0:
	set(v):
		beach_noise_period = v
		_changed()
@export var beach_noise_octaves: int = 2:
	set(v):
		beach_noise_octaves = v
		_changed()
@export var biome_smooth_half: int = 6:
	set(v):
		biome_smooth_half = v
		_changed()
@export_range(0, 40) var boss_land_cells: int = 12:
	set(v):
		boss_land_cells = v
		_changed()
@export var forest_margin: float = 0.2:
	set(v):
		forest_margin = v
		_changed()
@export var biome_smooth_passes: int = 2:
	set(v):
		biome_smooth_passes = v
		_changed()
@export var biome_min_blob: int = 400:
	set(v):
		biome_min_blob = v
		_changed()
@export var beach_min: float = 1.5:
	set(v):
		beach_min = v
		_changed()
@export var beach_max: float = 3.2:
	set(v):
		beach_max = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var cold_beach_t: float = 0.3:
	set(v):
		cold_beach_t = v
		_changed()
@export var home_calm_cells: float = 20.0:
	set(v):
		home_calm_cells = v
		_changed()
@export var home_calm_fade: float = 32.0:
	set(v):
		home_calm_fade = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var calm_temp: float = 0.55:
	set(v):
		calm_temp = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var calm_humid: float = 0.42:
	set(v):
		calm_humid = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var calm_rough: float = 0.25:
	set(v):
		calm_rough = v
		_changed()

@export_group("Vegetation")
## Vegetation (decisions 0037 + 0038 step 4). What each biome grows (tree mix, tries, rocks, bushes, flowers ...) is BiomeData: F3 "Biome <label>". These are the shared numbers.
## Trees are tried per 16x16-cell block; where an open (Plains) biome meets a wooded one the chance fades across the band lo..hi of f ("forestness", `forest_margin`).
## Same seed = same trees; any change rebuilds the map.
@export var trees_on: bool = true:
	set(v):
		trees_on = v
		_changed()
@export var band_lo: float = 0.45:
	set(v):
		band_lo = v
		_changed()
@export var band_hi: float = 0.65:
	set(v):
		band_hi = v
		_changed()
@export var fir_group_radius: float = 3.0:
	set(v):
		fir_group_radius = v
		_changed()
@export var veg_on: bool = true:
	set(v):
		veg_on = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var tree_fade_lo: float = 0.35:
	set(v):
		tree_fade_lo = v
		_changed()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var tree_fade_hi: float = 0.55:
	set(v):
		tree_fade_hi = v
		_changed()
@export_range(4.0, 80.0, 0.5, "or_greater", "or_less") var veg_density_period: float = 18.0:
	set(v):
		veg_density_period = v
		_changed()
@export var copper_near_home_cells: float = 0.0:
	set(v):
		copper_near_home_cells = v
		_changed()
@export_range(0.5, 6.0, 0.02, "or_greater", "or_less") var rock_group_radius: float = 2.2:
	set(v):
		rock_group_radius = v
		_changed()
@export var age_core: float = 0.75:
	set(v):
		age_core = v
		_changed()
@export var age_mid: float = 0.60:
	set(v):
		age_mid = v
		_changed()
@export var core_old: float = 0.5:
	set(v):
		core_old = v
		_changed()
@export var mid_small: float = 0.2:
	set(v):
		mid_small = v
		_changed()
@export var edge_young: float = 0.5:
	set(v):
		edge_young = v
		_changed()
@export var edge_sapling: float = 0.3:
	set(v):
		edge_sapling = v
		_changed()
@export var clearing_per_cells: float = 1600.0:
	set(v):
		clearing_per_cells = v
		_changed()
@export var clearing_r_min: float = 3.0:
	set(v):
		clearing_r_min = v
		_changed()
@export var clearing_r_max: float = 5.0:
	set(v):
		clearing_r_max = v
		_changed()
@export var tree_jitter: float = 0.35:
	set(v):
		tree_jitter = v
		_changed()
@export var tree_home_clear: int = 4:
	set(v):
		tree_home_clear = v
		_changed()

@export_group("Looks")
## Island LOOKS (decision 0033). None of these change where anything can walk, stand or be placed.
## Smoothing: majority passes that remove 1-cell spikes, holes and checkerboards from the ground before tiling.
@export var smooth_passes := 2:
	set(v):
		smooth_passes = v
		_changed_ground()
## Share of border cells that swap sides before smoothing (0 = borders stay cell-straight), and the smallest ground patch
## that is kept (smaller ones are absorbed).
@export var border_jitter := 0.35:
	set(v):
		border_jitter = v
		_changed_ground()
@export var min_island_cells := 14:
	set(v):
		min_island_cells = v
		_changed_ground()
## Dirt strip along the coast, in cells. 0 = none: the sand / gravel biome beaches (beach_min / beach_max) are the shore now.
@export var beach_cells := 0:
	set(v):
		beach_cells = v
		_changed_ground()
## Dirt paths from home towards the boss, plus branches to the rocky ground. Look only: no speed bonus, blocks nothing.
@export var path_on := false:   # 0037: no roads for now (user)
	set(v):
		path_on = v
		_changed_ground()
@export var path_width := 3:
	set(v):
		path_width = v
		_changed_ground()
@export var path_branches := 3:
	set(v):
		path_branches = v
		_changed_ground()
## 0 = the straightest path, higher = it wanders more around trees and bends.
@export var path_wobble := 0.6:
	set(v):
		path_wobble = v
		_changed_ground()
## Dirt clearing around the campfire, radius in cells.
@export var camp_radius := 2:
	set(v):
		camp_radius = v
		_changed_ground()
## Random dirt patches in the forest, per 100 forest cells, and the biggest radius in cells. Off (0): dirt needs a reason (0035).
@export var dirt_patches := 0.0:
	set(v):
		dirt_patches = v
		_changed_ground()
@export var dirt_patch_size := 2.5:
	set(v):
		dirt_patch_size = v
		_changed_ground()
## Ground colour per area: brightness, and warm (+ redder, - bluer). Live: only the tint map is redone.
@export var forest_bright := 1.0:
	set(v):
		forest_bright = v
		_retint()
@export var forest_warm := 0.0:
	set(v):
		forest_warm = v
		_retint()
@export var rocky_bright := 0.95:
	set(v):
		rocky_bright = v
		_retint()
@export var rocky_warm := 0.06:
	set(v):
		rocky_warm = v
		_retint()
@export var boss_bright := 0.7:
	set(v):
		boss_bright = v
		_sync_boss_ground()
@export var boss_warm := 0.22:
	set(v):
		boss_warm = v
		_sync_boss_ground()
## Colour strength per area: 1 = the picture's own colours, 0 = grey.
@export var forest_sat := 1.0:
	set(v):
		forest_sat = v
		_retint()
@export var rocky_sat := 0.95:
	set(v):
		rocky_sat = v
		_retint()
@export var boss_sat := 0.3:
	set(v):
		boss_sat = v
		_sync_boss_ground()
## Ground colour per biome (tint_bright / warm / sat) and the biome map colour live in each BiomeData (data/biomes/), F3 section "Biome <label>".
## Biome map (F3 button "Biome map"): a see-through colour per cell over the whole world, colours as in the demo legend. Live.
@export var biome_map_on := false:
	set(v):
		biome_map_on = v
		_apply_biome_map()
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var biome_map_alpha := 0.55:
	set(v):
		biome_map_alpha = v
		_apply_biome_map()

## Light / dark patches on the ground: strength, and size (noise frequency per cell, lower = bigger).
@export var shade_variation := 0.1:
	set(v):
		shade_variation = v
		_retint()
@export var shade_scale := 0.05:
	set(v):
		shade_scale = v
		_retint()
## Master ground colour (every ground, both styles; the PNGs stay as they are): brightness and colour strength.
## Lower = characters, nodes and stations stand out more (0.8 / 0.85 was tried; the user prefers 1 / 1, the pack's own colours). Live.
@export var ground_brightness := 1.0:
	set(v):
		ground_brightness = v
		_apply_terrain_look()
@export var ground_saturation := 1.0:
	set(v):
		ground_saturation = v
		_apply_terrain_look()
## Shallow water (rivers, lakes, the coast shallows) is drawn lighter than the deep ocean: how much (0 = same), and its colour. Live.
@export_range(0.0, 1.0, 0.005, "or_greater", "or_less") var shallow_tint_amount := 0.28:
	set(v):
		shallow_tint_amount = v
		_apply_terrain_look()
@export var shallow_tint_r := 0.55:
	set(v):
		shallow_tint_r = v
		_apply_terrain_look()
@export var shallow_tint_g := 0.85:
	set(v):
		shallow_tint_g = v
		_apply_terrain_look()
@export var shallow_tint_b := 0.88:
	set(v):
		shallow_tint_b = v
		_apply_terrain_look()
## Shore foam and water shimmer. Live (no rebuild).
@export var foam_alpha := 0.85:
	set(v):
		foam_alpha = v
		_apply_terrain_look()
@export var foam_pulse := 0.45:
	set(v):
		foam_pulse = v
		_apply_terrain_look()
@export var foam_speed := 0.8:
	set(v):
		foam_speed = v
		_apply_terrain_look()
@export var shimmer_speed := 0.35:
	set(v):
		shimmer_speed = v
		_apply_terrain_look()
@export var shimmer_strength := 0.18:
	set(v):
		shimmer_strength = v
		_apply_terrain_look()
## Size of the glints: higher = smaller and denser.
@export var shimmer_scale := 0.09:
	set(v):
		shimmer_scale = v
		_apply_terrain_look()
## Share of the water that can glint at a time (0..1).
@export var shimmer_amount := 0.3:
	set(v):
		shimmer_amount = v
		_apply_terrain_look()
@export var wave_strength := 0.05:
	set(v):
		wave_strength = v
		_apply_terrain_look()
## The slow light drift on the water: size of the patches (lower = bigger) and speed.
@export var drift_scale := 0.03:
	set(v):
		drift_scale = v
		_apply_terrain_look()
@export_range(0.0, 100.0, 0.5, "or_greater", "or_less") var drift_speed := 0.05:
	set(v):
		drift_speed = v
		_apply_terrain_look()
## Glint and foam colours (red, green, blue 0..1).
@export var shimmer_r := 0.85:
	set(v):
		shimmer_r = v
		_apply_terrain_look()
@export var shimmer_g := 0.95:
	set(v):
		shimmer_g = v
		_apply_terrain_look()
@export var shimmer_b := 1.0:
	set(v):
		shimmer_b = v
		_apply_terrain_look()
@export var foam_r := 0.96:
	set(v):
		foam_r = v
		_apply_terrain_look()
@export var foam_g := 0.99:
	set(v):
		foam_g = v
		_apply_terrain_look()
@export var foam_b := 1.0:
	set(v):
		foam_b = v
		_apply_terrain_look()

@export_group("Scene wiring")
@export var player_path: NodePath
@export var home_path: NodePath = ^"../HomePoint"
## The campfire sits this far from the player start.
@export var home_offset_x := -70.0:
	set(v):
		home_offset_x = v
		_changed(false, true)
@export var home_offset_y := -50.0:
	set(v):
		home_offset_y = v
		_changed(false, true)
@export var boss_path: NodePath
@export var dummy_path: NodePath
@export var fight_zone_path: NodePath
## A ColorRect behind everything; resized to the map.
@export var background_path: NodePath

var current_seed := 0
var build_count := 0   ## how many full builds this map did (F3 tests: saved edits must not cause a second one at start)
var build_ms := 0   ## last rebuild, in ms
var gen_ms := 0   ## of which MapGen.generate (the world data)
var bake_ms := 0   ## of which the first chunks (ground pictures, nodes, props around the player)
var node_count := 0   ## resource nodes in the current result, cached at build time
var tree_counts := {}   ## age -> aged trees in the current result (0037), cached at build time
var tree_colours := {}  ## season name -> aged trees (0038 step 4), cached at build time
var deco_counts := {}   ## kind of floor prop (flower, tuft, bush ...) -> count (0038 step 4), cached at build time
var biome_pct: Array[int] = []   ## % of land per MapGen.Biome, cached at build time
var land_pct := 0   ## share of land cells in the current result, cached at build time
var water_text := "none"   ## F3: river / lake / shallow cell counts of the current result, cached at build time
var result: MapGen.Result

var _spawns := PackedVector2Array()
var _player_spawn := Vector2.ZERO
var _zone := Rect2()
var _ready_done := false
var last_walk_check_ms := 0.0   ## cost of the last blocks_boss_path flood, for F3 / the report
var _walk_for: MapGen.Result
var _walk_grid := PackedByteArray()
var _walk_base_ok := false
var _rebuild_queued := false
var _want_new_seed := false
var _want_relayout := false
var _want_full := false     ## something besides a look setting changed: the whole map rebuilds
var _want_ground := false   ## only look settings changed: re-bake the ground, keep trees, rocks and stations
var _walls: Node2D
var _camera: Camera2D
var _water: TileMapLayer
var _water_body: StaticBody2D
var _dirt: TileMapLayer
var _grass: TileMapLayer
var _terrain: TerrainVisual
var _biome_overlay: Sprite2D   ## the F3 biome map layer, one pixel per cell
var _biome_overlay_for: MapGen.Result   ## the result its picture shows
var _deco: Node2D
var _obstacles: Node2D
var _border: Node2D
var _streamer: ChunkStreamer


func _ready() -> void:
	add_to_group("arena_map")
	add_to_group("debug")
	# A test that does not need the full island sets BOSSFIGHT_TEST_MAP_CELLS (e.g. "192") before loading the
	# arena: a smaller square map builds ~7x faster. Like BOSSFIGHT_TEST_SEED, never set in a normal game.
	var cells := OS.get_environment("BOSSFIGHT_TEST_MAP_CELLS")
	if yard_mode:
		yard = TestYard.new()
		yard.name = "TestYard"
		yard.map = self
		get_parent().add_child.call_deferred(yard)   # after the arena's own children are ready (player, spawner, inventory)
		map_cols = yard.cells
		map_rows = yard.cells
	elif cells.is_valid_int() and int(cells) >= 12:
		map_cols = int(cells)
		map_rows = int(cells)
	_default_exports = _export_values()
	for k in pending_settings:   # a saved island: same exports as when it was saved (before the first build)
		if _default_exports.has(k):
			set(k, str_to_var(pending_settings[k]))
	pending_settings = {}
	# The layers live in arena.tscn: Ground (z -10: under every character and shadow) holds the flat
	# stuff; Obstacles is Y-sorted with the characters, so a rock hides whoever stands behind it.
	_water = $Ground/Water
	_dirt = $Ground/Dirt
	_grass = $Ground/Grass
	_deco = $Ground/Deco
	_border = $Ground/Border
	_obstacles = $Obstacles
	for layer in [_water, _dirt, _grass]:
		layer.scale = Vector2.ONE * style.pixel_scale
	_terrain = TerrainVisual.new()
	$Ground.add_child(_terrain)
	$Ground.move_child(_terrain, _grass.get_index() + 1)
	_biome_overlay = Sprite2D.new()   # a slot for the F3 biome map: a see-through picture over everything, never part of the ground
	_biome_overlay.name = "BiomeOverlay"
	_biome_overlay.centered = false
	_biome_overlay.z_index = 60
	_biome_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_biome_overlay.visible = false
	var overlay_layer := CanvasLayer.new()   # own canvas that follows the camera: the night tint does not darken the F3 biome picture
	overlay_layer.layer = 1
	overlay_layer.follow_viewport_enabled = true
	add_child(overlay_layer)
	overlay_layer.add_child(_biome_overlay)
	_water_body = StaticBody2D.new()
	_water_body.name = "Water"
	_water_body.collision_mask = 0
	add_child(_water_body)
	_walls = Node2D.new()
	_walls.name = "Walls"
	add_child(_walls)
	_streamer = ChunkStreamer.new()
	_streamer.name = "Chunks"
	_streamer.map = self
	add_child(_streamer)
	_ready_done = true
	_want_new_seed = false
	_want_relayout = false
	_place_actors()
	var player := get_node_or_null(player_path) as Node2D
	if player:
		_camera = Camera2D.new()
		_camera.name = "Camera"
		player.add_child(_camera)
		_apply_camera()
		_camera.reset_smoothing()
	rebuild(true)


var _default_exports := {}

func _export_values() -> Dictionary:
	var d := {}
	for p in get_property_list():
		if p["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and p["usage"] & PROPERTY_USAGE_EDITOR \
				and p["type"] in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_COLOR] \
				and p["name"] != "map_seed":
			d[p["name"]] = get(p["name"])
	return d

## W9: the exports that differ from the scene's own values (F3 tuning), as name -> var_to_str(value).
func export_changes() -> Dictionary:
	var out := {}
	var now := _export_values()
	for k in now:
		if _default_exports.has(k) and now[k] != _default_exports[k]:
			out[k] = var_to_str(now[k])
	return out

func streamer_broken() -> Array:
	return _streamer.broken_list() if _streamer else []

func mark_broken(idx: int) -> void:
	if _streamer:
		_streamer.mark_broken(idx)

func status_text() -> String:
	if result == null:
		return "n/a"
	var player := get_node_or_null(player_path) as Node2D
	var here: Vector2 = player.global_position if player else Vector2.ZERO
	var ai := area_at(here) if player else -1
	var shares: Array[String] = []
	for b in result.biomes.size():
		if not biome_pct.is_empty() and biome_pct[b] > 0:
			shares.append("%s %d" % [result.biomes[b].label, biome_pct[b]])
	return "zoom: %.2f (target %.2f)\nseed: %d  size: %dx%d cells (%dx%d px)\ndirt patches: %d  rocks: %d  deco: %d  bushes: %d\narea %s  land %d%%  nodes %d  dirt cells %d\nbiome %s  temperature %.2f  humidity %.2f  roughness %.2f  f %.2f\nground: %s\nwater: %s\nbiome %% of land: %s\ntrees by age: %s\ntrees by colour: %s\ndeco by kind: %s\nbuild %d ms (world data %d ms, first chunks %d ms)\n%s" % [
		_camera.zoom.x if _camera else 1.0, camera_zoom, current_seed, map_cols, map_rows, map_size().x, map_size().y,
		result.patches.size(), result.obstacles.size(), result.deco.size(), result.border.size(),
		["forest", "rocky", "boss"][ai] if ai >= 0 else "water", land_pct, node_count, result.dirt_cells.size(),
		_biome_name(here), _climate_here(result.temp, here), _climate_here(result.humid, here), _climate_here(result.rough, here), _climate_here(result.f, here),
		_ground_text(here), water_text, ", ".join(shares),
		" ".join(MapGen.AGES.map(func(a): return "%s %d" % [a, tree_counts.get(a, 0)])), _counts_text(tree_colours), _counts_text(deco_counts), build_ms, gen_ms, bake_ms, _streamer.status_text() if _streamer else ""]


var _pp_shares: Array[int] = []
var _pp_shares_of: MapGen.Result

func _ground_text(here_pos: Vector2) -> String:
	if style == null or style.pixel_plains == null:
		return "old tinted tiles"
	if _pp_shares_of != result:   # counted once per map
		_pp_shares = PixelPlainsBaker.shares(result, style.pixel_plains)
		_pp_shares_of = result
	var hi := _cell_i(here_pos)
	var cell_text := "" if hi < 0 else "\n  here: " + PixelPlainsBaker.report(result, style.pixel_plains, hi % result.cols, hi / result.cols)
	var shown := ""
	if hi >= 0:   # which plants the pack art draws in the biome under the player (PixelPlainsGround.show_*)
		var bi: int = result.biome[hi]
		shown = "\n  plants here (biome %d): %s" % [bi, " ".join(["trees", "flowers", "tufts", "hedges", "other"].map(func(k): return "%s %s" % [k, "on" if style.pixel_plains.shows(StringName(k), bi) else "hidden"]))]
	return "pixel plains, no tint (land: dirt %d%% light %d%% dark %d%% sand %d%% snow %d%%, before the dark-near-dirt rule)  all trees hidden %s  all plants hidden %s%s%s" % [_pp_shares[0], _pp_shares[1], _pp_shares[2], _pp_shares[3], _pp_shares[4], style.pixel_plains.hide_trees, style.pixel_plains.hide_veg, shown, cell_text]


func _cell_i(pos: Vector2) -> int:   ## index into result.land / f / biome, -1 off the grid
	var c := Vector2i((pos / cell_px()).floor())
	return -1 if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows else c.y * result.cols + c.x


func _biome_name(pos: Vector2) -> String:
	var i := _cell_i(pos)
	if i >= 0 and not result.shallow.is_empty() and result.shallow[i] == 1:
		return ["", "river", "lake", "coast shallows"][result.fresh[i] if result.fresh[i] != 0 else 3]
	if i < 0 or result.biome.is_empty() or result.land[i] == 0:
		return "n/a"
	return result.biomes[result.biome[i]].label


func _counts_text(counts: Dictionary) -> String:
	var parts: Array[String] = []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	return " ".join(parts) if not parts.is_empty() else "none"


func _climate_here(values: PackedFloat32Array, pos: Vector2) -> float:
	var i := _cell_i(pos)
	return values[i] if i >= 0 and not values.is_empty() else 0.0


## F3 Save asks this instead of reading the export: map_seed 0 means "random", but a saved file
## should bring back the map that is showing.
func save_value(prop: String) -> Variant:
	return current_seed if prop == "map_seed" else get(prop)


## R (retry) and F3 Restart reload the scene; the reloaded map reuses this seed once instead of rolling a new island.
static var retry_seed := 0
## W9: settings of a saved island, applied once in the next ArenaMap._ready (name -> var_to_str value).
static var pending_settings := {}
## Test yard (decision 0056): the title's "Test yard" button sets it; the next arena builds the small flat yard (TestYard) instead of the island.
static var yard_mode := false
var yard: TestYard   ## only in a yard run


static func reload_keeping_seed(tree: SceneTree) -> void:
	var m := tree.get_first_node_in_group("arena_map") as ArenaMap
	if m != null and m.map_seed == 0:
		retry_seed = m.current_seed
	if tree.current_scene != null:   # null in a headless test
		tree.reload_current_scene()


## "Generating world..." over the screen while MapGen runs (3-4 s, nothing else can draw): shown, one frame forced, then hidden.
func _show_generating(on: bool) -> void:
	if _gen_layer == null:
		if not on:
			return
		_gen_layer = CanvasLayer.new()
		_gen_layer.layer = 120
		var l := Label.new()
		l.text = "Generating world..."
		l.set_anchors_preset(Control.PRESET_FULL_RECT)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_font_size_override("font_size", 32)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 8)
		_gen_layer.add_child(l)
		add_child(_gen_layer)
	_gen_layer.visible = on
	if on and DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()


var _gen_layer: CanvasLayer


## "New map" button: same settings, new random seed.
func new_map() -> void:
	current_seed = _fresh_seed()
	rebuild(false)


## F3 "Generate": rebuild with exactly this seed (1..9999, the same range as New map and the slider).
## Goes through map_seed so the F3 slider and a later Save show it too.
func generate_seed(s: int) -> void:
	var v := clampi(s, 1, 9999)
	if v == map_seed:
		rebuild(true)   # the setter would not fire for an unchanged value
	else:
		map_seed = v
		_apply_pending_now()


## new_seed: roll map_seed (or a random one if it is 0); otherwise rebuild the current seed.
## relayout: also move the zone / boss / player / dummy to the layout.
func rebuild(new_seed: bool, relayout := false) -> void:
	if not _ready_done:
		return
	build_count += 1
	var t0 := Time.get_ticks_msec()
	if relayout:
		_place_actors()
		if _camera:
			_camera.reset_smoothing()
	_clear_stations()
	_apply_size()
	if new_seed:
		if map_seed == 0 and retry_seed > 0:
			current_seed = retry_seed
		else:
			current_seed = map_seed if map_seed != 0 else _test_seed()
		retry_seed = 0
	var tg := Time.get_ticks_msec()
	_show_generating(true)
	result = MapGen.generate(style, make_params(), current_seed)
	_show_generating(false)
	gen_ms = Time.get_ticks_msec() - tg
	var counts: Array[int] = []
	counts.resize(MapGen.Biome.size())
	var land := 0
	var land_a := result.land
	var biome_a := result.biome
	var has_biome := not biome_a.is_empty()
	for i in land_a.size():
		if land_a[i] == 1:
			land += 1
			if has_biome:
				counts[biome_a[i]] += 1
	water_text = "none"
	if not result.shallow.is_empty():
		var river := 0
		var lake := 0
		var shallow := 0
		for i in land_a.size():
			shallow += result.shallow[i]
			river += int(result.fresh[i] == 1)
			lake += int(result.fresh[i] == 2)
		water_text = "river %d  lake %d  shallow %d cells (walkable); deep ocean blocks" % [river, lake, shallow]
	land_pct = 100 * land / maxi(land_a.size(), 1)
	node_count = 0
	tree_counts.clear()
	tree_colours.clear()
	deco_counts.clear()
	for age in MapGen.AGES:
		tree_counts[age] = 0
	var is_tree := PackedByteArray()   # per node kind: 1 = an aged tree
	for k in style.resource_nodes:
		is_tree.append(1 if String(k.id).begins_with("tree_") else 0)
	for o in result.obstacles:
		node_count += 1 if o["node"] >= 0 else 0
		if o["node"] >= 0 and is_tree[o["node"]] == 1:
			var parts := String(style.resource_nodes[o["node"]].id).split("_")   # tree_oak_old / tree_oak_yellow_old: the age is the last part
			tree_counts[StringName(parts[parts.size() - 1])] += 1
			var colour: String = parts[2] if parts.size() == 4 else "green"
			tree_colours[colour] = tree_colours.get(colour, 0) + 1
	var family: Array[Dictionary] = []   # per deco set: region index -> kind (flower_0 -> flower, tuft_green -> tuft, snow_stump -> stump)
	for set in style.deco:
		var fam := {}
		for g in set.groups:
			var name := String(g)
			for r in set.groups[g]:
				fam[r] = "stump" if name.ends_with("_stump") else (name if name in ["deadbush", "mushroom", "foxglove"] else name.rsplit("_", true, 1)[0])
		family.append(fam)
	for d in result.deco:
		var kind: String = family[d["set"]].get(d["region"], "other")
		deco_counts[kind] = deco_counts.get(kind, 0) + 1
	biome_pct.clear()
	biome_pct.resize(MapGen.Biome.size())
	var given := 0
	var order: Array[int] = []   # largest remainder: the shares sum to 100
	for b in counts.size():
		biome_pct[b] = 100 * counts[b] / maxi(land, 1)
		given += biome_pct[b]
		order.append(b)
	order.sort_custom(func(x: int, y: int) -> bool: return (100 * counts[x]) % maxi(land, 1) > (100 * counts[y]) % maxi(land, 1))
	for k in range(mini(100 - given, order.size()) if land > 0 else 0):
		biome_pct[order[k]] += 1
	_build()
	_warm_walk_grid(make_params())
	_fit_dummy()
	build_ms = maxi(Time.get_ticks_msec() - t0, 1)
	rebuilt.emit()


## A rebuilt island may have water where a station stood: every placed station goes back to the player
## (item + furnace contents; the inventory, else dropped at the player). Nothing is lost.
func _clear_stations() -> void:
	var player := get_node_or_null(player_path)
	var inv := player.get_node_or_null("Inventory") as Inventory if player else null
	for st: Station in get_tree().get_nodes_in_group("station"):
		if st.has_meta(&"yard"):   # the test yard's own stations are re-made, never refunded (0056)
			st.remove_from_group("station")
			st.queue_free()
			continue
		st.pick_up(inv, true)


## tools/run_tests.sh sets BOSSFIGHT_TEST_SEED so tests get the same island every run.
func _test_seed() -> int:
	var e := OS.get_environment("BOSSFIGHT_TEST_SEED")
	return int(e) if e.is_valid_int() and int(e) > 0 else _fresh_seed()

func _fresh_seed() -> int:
	return randi_range(1, 9999)   # F3's map_seed slider goes to 9999: any shown seed can be typed back


## Setters call this. Several changes in one frame (Load in the F3 panel) rebuild once.
func _changed(new_seed := false, relayout := false) -> void:
	_want_full = true
	_want_new_seed = _want_new_seed or new_seed
	_want_relayout = _want_relayout or relayout
	if not _ready_done or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_deferred.call_deferred()


## Look-only settings (paths, camp, patches, smoothing, beach): re-bake just the ground. Chopped trees stay chopped and
## placed stations stay where they are.
func _changed_ground() -> void:
	_want_ground = true
	if not _ready_done or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_deferred.call_deferred()


## Placed things (stations) must not stand on a tree or rock of a chunk that is not loaded: asks the world data.
func placement_blocked(rect: Rect2) -> bool:
	if result == null:
		return false
	var b0 := Vector2i(rect.position / result.obstacle_bucket) - Vector2i.ONE
	var b1 := Vector2i(rect.end / result.obstacle_bucket) + Vector2i.ONE
	for by in range(b0.y, b1.y + 1):
		for bx in range(b0.x, b1.x + 1):
			for o: Dictionary in result.obstacle_grid.get(Vector2i(bx, by), []):
				var c: Vector2 = o["pos"]
				if _streamer.is_loaded(_streamer.chunk_id_at(c)):
					continue   # a loaded chunk: its live nodes are checked by the caller (and a gathered one no longer counts)
				var q := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
				if q.distance_to(c) <= o["radius"]:
					return true
	return false


func rebuild_ground() -> void:
	if not _ready_done or result == null or result.ground.is_empty():
		rebuild(false)
		return
	var t0 := Time.get_ticks_msec()
	MapGen.rebuild_ground(result, style, make_params())
	_sync_boss_ground()
	_apply_terrain_look()
	_streamer.reload_visuals()   # the loaded chunks' ground and props again; their trees and rocks stay as they are (and as they were gathered)
	build_ms = maxi(Time.get_ticks_msec() - t0, 1)


func _rebuild_deferred() -> void:
	if not _rebuild_queued:
		return
	_rebuild_queued = false
	var new_seed := _want_new_seed
	var relayout := _want_relayout
	var ground_only := _want_ground and not _want_full and not new_seed and not relayout
	_want_new_seed = false
	_want_relayout = false
	_want_full = false
	_want_ground = false
	if ground_only:
		rebuild_ground()
	else:
		rebuild(new_seed, relayout)


## Runs a queued rebuild now (the caller needs the new map in this same frame).
func _apply_pending_now() -> void:
	_rebuild_deferred()


func make_params() -> MapGen.Params:
	var p := MapGen.Params.new()
	var cell := cell_px()
	var scale := float(map_cols * map_rows) / REF_CELLS
	p.cell = cell
	p.world = map_size()
	p.cols = map_cols
	p.rows = map_rows
	p.patch_count = roundi(patch_count * scale)
	p.patch_min_size = patch_min_size
	p.patch_max_size = patch_max_size
	p.noise_frequency = noise_frequency
	p.patch_noise_threshold = patch_noise_threshold
	p.deco_density = deco_density
	p.deco_min_spacing = deco_min_spacing
	p.obstacle_count = roundi(obstacle_count * scale)
	p.obstacle_min_spacing = obstacle_min_spacing
	p.spawn_clear_radius = spawn_clear_radius
	p.border_density = border_density
	p.dark_grass_chance = dark_grass_chance
	p.agent_radius = agent_radius
	p.island_on = island_on
	p.cont_period = cont_period
	p.cont_octaves = cont_octaves
	p.cont_gain = cont_gain
	p.cont_radial = cont_radial
	p.cont_edge_cells = cont_edge_cells
	p.land_share = land_share
	p.neck_cells = neck_cells
	p.neck_boost = neck_boost
	p.water_on = water_on
	p.river_period = river_period
	p.river_octaves = river_octaves
	p.river_w_inland = river_w_inland
	p.river_w_sea = river_w_sea
	p.river_grow_dist = river_grow_dist
	p.river_rough_max = river_rough_max
	p.river_min_cells = river_min_cells
	p.river_inland_min = river_inland_min
	p.lake_humid_min = lake_humid_min
	p.lake_inland_min = lake_inland_min
	p.lake_rough_max = lake_rough_max
	p.lake_min_cells = lake_min_cells
	p.water_min_cells = water_min_cells
	p.river_big_n = river_big_n
	p.river_big_w_inland = river_big_w_inland
	p.river_big_w_sea = river_big_w_sea
	p.river_big_reach = river_big_reach
	p.lake_big_n = lake_big_n
	p.lake_big_r_min = lake_big_r_min
	p.lake_big_r_max = lake_big_r_max
	p.lake_big_on_river = lake_big_on_river
	p.lake_pond_n = lake_pond_n
	p.lake_pond_r_min = lake_pond_r_min
	p.lake_pond_r_max = lake_pond_r_max
	p.lake_pond_on_river = lake_pond_on_river
	p.lake_pond_wet_min = lake_pond_wet_min
	p.lake_pond_wet_period = lake_pond_wet_period
	p.lake_pond_stretch_min = lake_pond_stretch_min
	p.lake_pond_stretch_max = lake_pond_stretch_max
	p.lake_pond_blobs_min = lake_pond_blobs_min
	p.lake_pond_blobs_max = lake_pond_blobs_max
	p.lake_warp = lake_warp
	p.lake_shape_period = lake_shape_period
	p.lake_gap = lake_gap
	p.shore_cells = shore_cells
	p.shallow_min = shallow_min
	p.shallow_max = shallow_max
	p.coast_cells = coast_cells
	p.home_clear_cells = home_clear_cells
	p.corridor_half = corridor_half
	p.climate_temp_period = climate_temp_period
	p.climate_humid_period = climate_humid_period
	p.climate_rough_period = climate_rough_period
	p.climate_warp_period = climate_warp_period
	p.climate_warp_amp = climate_warp_amp
	p.climate_octaves = climate_octaves
	p.climate_w_temp = climate_w_temp
	p.climate_w_humid = climate_w_humid
	p.climate_w_rough = climate_w_rough
	p.forest_margin = forest_margin
	p.climate_warp_octaves = climate_warp_octaves
	p.beach_noise_period = beach_noise_period
	p.beach_noise_octaves = beach_noise_octaves
	p.biome_smooth_half = biome_smooth_half
	p.boss_land_cells = boss_land_cells
	p.biome_smooth_passes = biome_smooth_passes
	p.biome_min_blob = biome_min_blob
	p.beach_min = beach_min
	p.beach_max = beach_max
	p.cold_beach_t = cold_beach_t
	p.home_calm_cells = home_calm_cells
	p.home_calm_fade = home_calm_fade
	p.calm_temp = calm_temp
	p.calm_humid = calm_humid
	p.calm_rough = calm_rough
	p.legacy_tiles = map_cols * map_rows <= legacy_tiles_max_cells
	p.band_lo = band_lo
	p.band_hi = band_hi
	p.fir_group_radius = fir_group_radius
	p.pp = style.pixel_plains
	p.trees_on = trees_on and not (p.pp != null and p.pp.hide_trees)
	p.veg_on = veg_on and not (p.pp != null and p.pp.hide_veg)
	p.tree_fade_lo = tree_fade_lo
	p.tree_fade_hi = tree_fade_hi
	p.veg_density_period = veg_density_period
	p.rock_group_radius = rock_group_radius
	p.copper_near_home_cells = copper_near_home_cells
	p.age_core = age_core
	p.age_mid = age_mid
	p.core_old = core_old
	p.mid_small = mid_small
	p.edge_young = edge_young
	p.edge_sapling = edge_sapling
	p.clearing_per_cells = clearing_per_cells
	p.clearing_r_min = clearing_r_min
	p.clearing_r_max = clearing_r_max
	p.tree_home_clear = tree_home_clear
	p.tree_jitter = tree_jitter
	p.smooth_passes = smooth_passes
	p.border_jitter = border_jitter
	p.min_island_cells = min_island_cells
	p.beach_cells = beach_cells
	p.path_on = path_on
	p.path_width = path_width
	p.path_branches = path_branches
	p.path_wobble = path_wobble
	p.camp_radius = camp_radius
	p.dirt_patches = dirt_patches
	p.dirt_patch_size = dirt_patch_size
	if yard != null:
		p.yard = true
		p.yard_nodes = yard.node_list(_player_spawn)
		p.water_on = false
		p.veg_on = false
		p.legacy_tiles = false
	p.zone = _zone
	p.spawns = _spawns
	p.player_spawn = _player_spawn
	return p


## MapGen.Area at a world position, or -1 on water / off the map.
func area_at(pos: Vector2) -> int:
	if result == null:
		return -1
	var c := Vector2i((pos / cell_px()).floor())
	if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows:   # the size the result was built with
		return -1
	var i := c.y * result.cols + c.x
	return -1 if result.land[i] == 0 else result.area[i]


## True when every cell `rect` (px) overlaps is dry land (a station box over a thin river is refused).
func rect_on_land(rect: Rect2) -> bool:
	if result == null:
		return true
	var c0 := Vector2i((rect.position / cell_px()).floor())
	var c1 := Vector2i((rect.end / cell_px()).floor())
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			if cx < 0 or cy < 0 or cx >= result.cols or cy >= result.rows or result.land[cy * result.cols + cx] == 0:
				return false
	return true


## MapGen.WaterKind at a world position: NONE on dry land, SHALLOW in a river / lake / coast shallows (walkable), OCEAN beyond (blocks).
## Follows the drawn ground: the shore's sand is drawn a few pixels into its water cells, and a point on that sand is dry.
func water_kind_at(pos: Vector2) -> int:
	if result == null or result.shallow.is_empty():
		return MapGen.WaterKind.NONE
	var c := Vector2i((pos / cell_px()).floor())
	if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows:
		return MapGen.WaterKind.OCEAN
	var i := c.y * result.cols + c.x
	if result.land[i] == 1:
		return MapGen.WaterKind.NONE
	if style != null and style.pixel_plains != null and not result.ground.is_empty() \
			and PixelPlainsBaker.drawn_land_at(result, style.pixel_plains, Vector2i((pos / float(style.pixel_scale)).floor())):
		return MapGen.WaterKind.NONE
	return MapGen.WaterKind.SHALLOW if result.shallow[i] == 1 else MapGen.WaterKind.OCEAN


## True in the boss's land (area BOSS) or inside the fight zone: no placing stations there.
func in_boss_area(pos: Vector2) -> bool:
	return _zone.has_point(pos) or area_at(pos) == MapGen.Area.BOSS


## True on a cell of the land bridge carved to reach the boss (only when the island needed one).
func in_corridor(pos: Vector2) -> bool:
	return result != null and result.bridge.has(Vector2i((pos / cell_px()).floor()))


## True if `rect` touches any bridge cell (a rect can straddle a bridge without a corner inside it).
func in_corridor_rect(rect: Rect2) -> bool:
	if result == null or result.bridge.is_empty():
		return false
	var c0 := Vector2i((rect.position / cell_px()).floor())
	var c1 := Vector2i((rect.end / cell_px()).floor())
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if result.bridge.has(Vector2i(x, y)):
				return true
	return false


## Would solid boxes at `rects` (px) cut the walk from home to the boss zone? Reuses MapGen's walk grid and
## flood. The base grid is built once per island (cached); one check is one flood (`last_walk_check_ms`).
## False when there was no walk to protect to begin with.
func blocks_boss_path(rects: Array[Rect2]) -> bool:
	if result == null or yard != null:
		return false
	var p := make_params()
	_warm_walk_grid(p)
	if not _walk_base_ok:
		return false
	var t0 := Time.get_ticks_usec()
	var ok := MapGen.blockers_keep_local_walk(p, _walk_grid, rects, _zone.get_center()) or MapGen.goal_reachable_with(p, _walk_grid, rects, _zone.get_center())
	last_walk_check_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return not ok


## The base walk grid of this island (kept from generate, only the rocks are cleared) and whether home reaches the boss at all. Built right after
## generate, so the first station placement is one flood, not a 0.4 s grid build.
func _warm_walk_grid(p: MapGen.Params) -> void:
	if _walk_for == result or result == null or yard != null:   # the yard has no boss path to protect
		return
	_walk_for = result
	_walk_grid = MapGen.walk_grid(p, result.obstacles, result.walk_land, result.walk_base)
	_walk_base_ok = MapGen.goal_reachable_with(p, _walk_grid, [] as Array[Rect2], _zone.get_center())


func home_point() -> Vector2:
	return _player_spawn


## Boss position in px (the boss node, else the middle of the fight zone). For the F3 World map.
func boss_point() -> Vector2:
	var b := get_node_or_null(boss_path) as Node2D
	return b.global_position if b else _zone.get_center()


# ------------------------------------------------------------------- chunks ---
# The chunk streamer is ours (ChunkStreamer); everything outside this file asks through these.

## Where the loaded part of the world is centred: the player.
func stream_focus() -> Vector2:
	var player := get_node_or_null(player_path) as Node2D
	return player.global_position if player else _player_spawn


func streamer() -> ChunkStreamer:
	return _streamer


func terrain() -> TerrainVisual:
	return _terrain


func boss() -> PhysicsBody2D:
	return get_node_or_null(boss_path) as PhysicsBody2D


func obstacles_root() -> Node2D:
	return _obstacles


func deco_root() -> Node2D:
	return _deco


## Build every chunk now (tools and tests: a whole-island picture, or a check that needs every node). Slow on a big map.
func load_all_chunks() -> void:
	if _streamer:
		_streamer.load_all()


## Build the chunks within `radius` of a world position now (a teleport, a tool that needs the nodes there).
func load_chunks_around(pos: Vector2, radius := 1) -> void:
	if _streamer:
		_streamer.build_around(pos, radius)


## The live ResourceNode of kind `id` (or, with `prefix`, any kind whose id starts with it: "tree" = every tree) nearest to `to` that has
## not been gathered, found in the WORLD DATA (so it works for a node whose chunk is not loaded) and loaded on demand. Null if there is none.
func nearest_node(id: StringName, to: Vector2, prefix := false) -> ResourceNode:
	if result == null:
		return null
	var best := -1
	var best_d := INF
	for i in result.obstacles.size():
		var o := result.obstacles[i]
		if o["node"] < 0 or _streamer.broken[i] == 1:
			continue
		var kind_id := style.resource_nodes[o["node"]].id
		if kind_id != id and not (prefix and String(kind_id).begins_with(String(id))):
			continue
		var d: float = to.distance_squared_to(o["pos"])
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return null
	_streamer.build_around(result.obstacles[best]["pos"], 0)
	_streamer.pin(_streamer.chunk_id_at(result.obstacles[best]["pos"]))
	return _streamer.node_of(best) as ResourceNode


## chunk_cells / load_radius / unload_margin changed: index again (reindex) and let the streamer re-plan.
func _chunks_changed(reindex := true) -> void:
	if not _ready_done or result == null or _streamer == null:
		return
	if reindex:
		_streamer.reset(true)
		_streamer.build_around(stream_focus(), 1)
	else:
		_streamer.refresh()


## "home" or "boss" (zone left edge - 96 px, zone centre y), or a world position (Vector2).
func teleport_player(to: Variant) -> void:
	var player := get_node_or_null(player_path) as CharacterBody2D
	if player == null:
		return
	if to is Vector2:
		player.global_position = to
	else:
		player.global_position = _player_spawn if to == "home" else _free_spot(Vector2(_zone.position.x - 96.0, _zone.get_center().y))
	player.velocity = Vector2.ZERO
	_streamer.build_around(player.global_position, 1)   # the ground and the trees must be there when the camera arrives
	if _camera:
		_camera.reset_smoothing()


## Nearest spot to `target` (rings of 16 px, up to 480 px out) where a walker stands on land, clear of every rock.
func _free_spot(target: Vector2) -> Vector2:
	if result == null:
		return target
	for ring in 31:
		for k in maxi(ring * 8, 1):
			var a := TAU * k / maxi(ring * 8, 1)
			var pos := target + Vector2.from_angle(a) * ring * 16.0
			if _walker_fits(pos):
				return pos
	return target


func _walker_fits(pos: Vector2) -> bool:
	for off in [Vector2.ZERO, Vector2(agent_radius, 0), Vector2(-agent_radius, 0), Vector2(0, agent_radius), Vector2(0, -agent_radius)]:
		var c := Vector2i(((pos + off) / cell_px()).floor())
		if c.x < 0 or c.y < 0 or c.x >= result.cols or c.y >= result.rows or result.land[c.y * result.cols + c.x] == 0:
			return false
	var b := Vector2i(pos / result.obstacle_bucket)   # only the rocks in the buckets around it (bucket >= 2 x the widest rock + spacing)
	for by in range(b.y - 1, b.y + 2):
		for bx in range(b.x - 1, b.x + 2):
			for o: Dictionary in result.obstacle_grid.get(Vector2i(bx, by), []):
				if pos.distance_to(o["pos"]) <= o["radius"] + agent_radius:
					return false
	return true


## The training dummy stays where the layout puts it when a walker fits there; on some seeds that is water or a rock, so it moves to the nearest
## spot where one does (searched in rings around the layout spot).
func _fit_dummy() -> void:
	var dummy := get_node_or_null(dummy_path) as Node2D
	if dummy == null or result == null or _walker_fits(dummy.global_position):
		return
	var from := dummy.global_position
	var step := cell_px() * 0.5
	for ring in range(1, 80):
		for k in ring * 8:
			var a := TAU * k / (ring * 8)
			var q := from + Vector2.from_angle(a) * ring * step
			if _walker_fits(q):
				dummy.global_position = q
				if "home" in dummy:
					dummy.home = q
				if dummy.has_meta("spot"):
					dummy.set_meta("spot", q)
				return


func cell_px() -> float:
	return float(style.tile_size * style.pixel_scale)


func map_size() -> Vector2:
	return Vector2(maxi(map_cols, 12), maxi(map_rows, 12)) * cell_px()


## Where everything starts. Pure function of the exports.
func layout() -> Dictionary:
	var size := map_size()
	var zsize := Vector2(zone_width, zone_height)
	if yard != null:   # the boss zone is far off the map: nothing engages
		var away := Vector2(-20000.0, -20000.0)
		return {"zone": Rect2(away, zsize), "boss": away + zsize * 0.5, "player": size * 0.5, "dummy": size * 0.5 + yard.dummy_offset}
	var c := Vector2(size.x * zone_x, size.y * zone_y)
	var pad := cell_px()   # keep the zone off the walls
	c.x = clampf(c.x, minf(pad + zsize.x * 0.5, size.x * 0.5), maxf(size.x - pad - zsize.x * 0.5, size.x * 0.5))
	c.y = clampf(c.y, minf(pad + zsize.y * 0.5, size.y * 0.5), maxf(size.y - pad - zsize.y * 0.5, size.y * 0.5))
	var player := Vector2(size.x * player_spawn_x, size.y * player_spawn_y)
	return {
		"zone": Rect2(c - zsize * 0.5, zsize),
		"boss": c + Vector2(boss_offset_x, 0.0),
		"player": player,
		"dummy": player + Vector2(dummy_offset_x, dummy_offset_y),
	}


## Moves the FightZone, Boss, Player and Dummy to the layout and remembers the spawns for MapGen.
## Spawns come from the layout, never from live positions: the same exports = the same map.
func _place_actors() -> void:
	var l := layout()
	_zone = l["zone"]
	_player_spawn = l["player"]
	var home_pos: Vector2 = l["player"] + Vector2(home_offset_x, home_offset_y)
	_spawns = PackedVector2Array([l["player"], l["boss"], l["dummy"], home_pos])
	var home := get_node_or_null(home_path) as Node2D
	if home:
		home.global_position = home_pos
	var zone := get_node_or_null(fight_zone_path) as Node2D
	if zone:
		zone.global_position = _zone.get_center()
		var cs := zone.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if cs:
			var shape := RectangleShape2D.new()
			shape.size = _zone.size
			cs.shape = shape
	var boss := get_node_or_null(boss_path) as Node2D
	if boss:
		if boss.has_method("set_home"):
			boss.call("set_home", l["boss"])
		else:
			boss.global_position = l["boss"]
	var player := get_node_or_null(player_path) as Node2D
	if player:
		player.global_position = l["player"]
	var dummy := get_node_or_null(dummy_path) as Node2D
	if dummy:
		dummy.global_position = l["dummy"]


## Walls (4 bodies, one cell thick, inside the map rect), camera limits, background size.
func _apply_size() -> void:
	var size := map_size()
	var t := cell_px()
	for c in _walls.get_children():
		_walls.remove_child(c)
		c.queue_free()
	var specs := {
		"Top": [Vector2(size.x * 0.5, t * 0.5), Vector2(size.x, t)],
		"Bottom": [Vector2(size.x * 0.5, size.y - t * 0.5), Vector2(size.x, t)],
		"Left": [Vector2(t * 0.5, size.y * 0.5), Vector2(t, size.y)],
		"Right": [Vector2(size.x - t * 0.5, size.y * 0.5), Vector2(t, size.y)],
	}
	for n in specs:
		var body := StaticBody2D.new()      # default layer 1, as the hand-placed walls had
		body.name = n
		body.collision_mask = 0
		body.position = specs[n][0]
		var shape := RectangleShape2D.new()
		shape.size = specs[n][1]
		var cs := CollisionShape2D.new()
		cs.name = "CollisionShape2D"
		cs.shape = shape
		body.add_child(cs)
		_walls.add_child(body)
	_apply_camera()
	var bg := get_node_or_null(background_path) as Control
	if bg:
		bg.position = Vector2.ZERO
		bg.size = size
		if bg is ColorRect and style:
			(bg as ColorRect).color = style.water_color


func zoom_by(steps: int) -> void:
	camera_zoom += steps * zoom_step


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("zoom_in"):
		zoom_by(1)
	elif event.is_action_pressed("zoom_out"):
		zoom_by(-1)


func _process(delta: float) -> void:
	if _camera:
		var z := lerpf(_camera.zoom.x, camera_zoom, minf(1.0, zoom_lerp_speed * delta / maxf(Engine.time_scale, 0.0001)))
		_camera.zoom = Vector2(z, z)


func _apply_camera() -> void:
	if _camera == null:
		return
	var size := map_size()
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(size.x)
	_camera.limit_bottom = int(size.y)
	_camera.position_smoothing_enabled = camera_smoothing
	_camera.position_smoothing_speed = camera_smoothing_speed


# ------------------------------------------------------------------- build ---

func _build() -> void:
	_biome_overlay_for = null
	_build_water_body()
	_dirt.clear()
	_grass.clear()
	_water.clear()
	bake_ms = 0
	if not result.ground.is_empty():
		_setup_island_terrain()
	else:
		_terrain.hide_island()
		_build_water_tiles()
		var ts := _make_tileset()
		_dirt.tile_set = ts
		_grass.tile_set = ts
		for cell in result.dirt:
			_dirt.set_cell(cell, 0, result.dirt[cell])
		for cell in result.grass:
			_grass.set_cell(cell, 0, result.grass[cell])
	_apply_biome_map()
	_build_border()
	# World data is ready. The visuals and nodes come per chunk (ChunkStreamer): the 3 x 3 around the player now, the rest as the player walks.
	var t0 := Time.get_ticks_msec()
	ChunkDeco.clear_cache()
	_streamer.reset()
	for c in _obstacles.get_children():   # anything not owned by a chunk (a node a test or a tool put there)
		_obstacles.remove_child(c)
		c.queue_free()
	_streamer.build_around(stream_focus(), 1)
	bake_ms = Time.get_ticks_msec() - t0


## The bushes along the walls (flat maps only: on the island the water is the edge). Not chunked: there are few and they sit on the map border.
func _build_border() -> void:
	for c in _border.get_children():
		_border.remove_child(c)
		c.queue_free()
	var s := float(style.pixel_scale)
	for d in result.border:
		add_prop_sprite(_border, style.border, d["region"], d["pos"], s, d["flip"])


## A plain cover rock (flat maps): a static body with its picture standing on the collision circle. Used by the chunk loader.
func make_cover_rock(o: Dictionary) -> StaticBody2D:
	var body := StaticBody2D.new()      # default layer 1 = the walls' layer
	body.name = "Rock"
	body.collision_mask = 0
	body.position = o["pos"]
	body.add_to_group("map_obstacle")
	var shape := CircleShape2D.new()
	shape.radius = o["radius"]
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"   # F1 looks it up by this name
	cs.shape = shape
	body.add_child(cs)
	# Sprite stands with its feet at the bottom of the collision circle.
	add_prop_sprite(body, style.obstacles, o["region"], Vector2(0, o["radius"]), float(style.pixel_scale), false)
	return body


## The island ground, once per map: the water under everything and the style hooks. The ground pictures themselves are made per
## chunk (ChunkStreamer -> GroundBaker.bake_region -> TerrainVisual.set_chunk).
func _setup_island_terrain() -> void:
	for d in style.grounds:   # an edited GroundData (F3 / editor) clears the piece cache and re-bakes the ground
		if d != null and not d.changed.is_connected(_on_ground_resource_changed):
			d.changed.connect(_on_ground_resource_changed)
	if style.pixel_plains != null and not style.pixel_plains.changed.is_connected(_on_pp_changed):
		style.pixel_plains.changed.connect(_on_pp_changed)
	for b in style.biomes:   # an edited BiomeData (F3): climate / ground / tree fields rebuild the map, look fields only re-tint
		if not b.changed.is_connected(_changed):
			b.changed.connect(_changed)
			b.look_changed.connect(_on_biome_look)
	_sync_boss_ground()
	var t := float(GroundBaker.tile_of(style))
	var shallow_img: Image = null
	if not result.shallow.is_empty():
		var mask := result.shallow.duplicate()   # 255 = shallow: full precision for the linear filter
		var at := mask.find(1)
		while at >= 0:
			mask[at] = 255
			at = mask.find(1, at + 1)
		shallow_img = Image.create_from_data(result.cols, result.rows, false, Image.FORMAT_L8, mask)
	_terrain.begin_island(GroundBaker.water_image(style, 4, result.seed), Vector2(result.cols + 1, result.rows + 1) * t, float(style.pixel_scale), shallow_img, t,
		style.pixel_plains.shader_params() if style.pixel_plains != null else {})
	_apply_terrain_look()


## F3 biome map: shown only on an island with biomes; the picture is made once per map.
func _apply_biome_map() -> void:
	if _biome_overlay == null:
		return
	var show := biome_map_on and result != null and not result.biome.is_empty()
	_biome_overlay.visible = show
	if not show:
		return
	if _biome_overlay_for != result:
		_biome_overlay.texture = ImageTexture.create_from_image(GroundBaker.biome_image(result))
		_biome_overlay_for = result
	_biome_overlay.scale = Vector2.ONE * cell_px()
	_biome_overlay.modulate.a = biome_map_alpha


## The ground colour numbers for GroundBaker: a tint per Area and the patch settings.
func tint_look() -> Dictionary:
	var tints: Array[Color] = []
	for a in [[forest_bright, forest_warm], [rocky_bright, rocky_warm], [1.0, 0.0]]:   # boss: in its pixels, see _sync_boss_ground
		tints.append(Color(a[0] * (1.0 + a[1]), a[0], a[0] * (1.0 - a[1])))
	return {"tint": tints, "sat": [forest_sat, rocky_sat, 1.0], "shade_variation": shade_variation, "shade_scale": shade_scale, "neutral": style != null and style.pixel_plains != null}


## Tint sliders: redo only the one-pixel-per-cell tint maps of the loaded chunks, not the ground pictures.
func _retint() -> void:
	if not _ready_done or result == null or result.ground.is_empty() or _terrain == null:
		return
	_streamer.retint()


func _apply_terrain_look() -> void:
	if _terrain == null:
		return
	_terrain.set_look({"shimmer_speed": shimmer_speed, "shimmer_strength": shimmer_strength, "shimmer_scale": shimmer_scale,
		"shimmer_amount": shimmer_amount, "wave_strength": wave_strength, "ground_brightness": ground_brightness, "ground_saturation": ground_saturation, "ground_neutral": style != null and style.pixel_plains != null, "drift_scale": drift_scale, "drift_speed": drift_speed,
		"shimmer_color": Color(shimmer_r, shimmer_g, shimmer_b), "shallow_lighten": shallow_tint_amount, "shallow_color": Color(shallow_tint_r, shallow_tint_g, shallow_tint_b), "foam_color": Color(foam_r, foam_g, foam_b), "foam_alpha": foam_alpha, "foam_pulse": foam_pulse, "foam_speed": foam_speed})


## The boss grass carries its own colour in its pixels (GroundData bright / warm / sat), so edge pieces drawn over the
## cobble match the fill. The area tint of the boss area stays neutral.
func _sync_boss_ground() -> void:
	if style == null or style.grounds.size() <= MapGen.Ground.BOSS or style.grounds[MapGen.Ground.BOSS] == null:
		return
	var g := style.grounds[MapGen.Ground.BOSS]
	if g.bright != boss_bright or g.warm != boss_warm or g.sat != boss_sat:
		g.set_block_signals(true)   # we are about to (re)make the ground anyway: no queued second rebuild
		g.bright = boss_bright
		g.warm = boss_warm
		g.sat = boss_sat
		g.set_block_signals(false)
		GroundBaker.clear_cache()


func _on_biome_look() -> void:
	_biome_overlay_for = null
	_apply_biome_map()
	_retint()


func _on_pp_changed() -> void:   # Pixel Plains table / hide switch edited (F3): new cache, whole map again (trees and deco depend on it)
	GroundBaker.clear_cache()
	_changed()


func _on_ground_resource_changed() -> void:
	GroundBaker.clear_cache()
	_changed_ground()


func _build_water_tiles() -> void:
	if style.water_texture and not result.water.is_empty():
		_water.tile_set = _make_tileset(style.water_texture, result.water.values())
		for cell in result.water:
			_water.set_cell(cell, 0, result.water[cell])


func _build_water_body() -> void:
	for c in _water_body.get_children():
		_water_body.remove_child(c)
		c.queue_free()
	# One rectangle per run of coast water (water touching land, 8 neighbours) in a row.
	var cols := result.cols
	var rows := result.rows
	var land := result.walk_land   # walkable ground (dry + shallow): only the deep water blocks
	var cell := cell_px()
	# land spread by one cell sideways, then up and down (the 3 x 3 neighbourhood); coast = that, where there is no land
	var wide := PackedByteArray()
	wide.resize(cols * rows)
	for y in rows:
		for i in range(y * cols, y * cols + cols):
			if land[i] == 1:
				wide[i] = 1
				if i % cols > 0:
					wide[i - 1] = 1
				if i % cols < cols - 1:
					wide[i + 1] = 1
	for y in rows:
		var x0 := -1
		for x in cols + 1:
			var i := y * cols + x
			var coast := false
			if x < cols and land[i] == 0:
				coast = wide[i] == 1 or (y > 0 and wide[i - cols] == 1) or (y < rows - 1 and wide[i + cols] == 1)
			if coast and x0 < 0:
				x0 = x
			elif not coast and x0 >= 0:
				var shape := RectangleShape2D.new()
				shape.size = Vector2((x - x0) * cell, cell)
				var cs := CollisionShape2D.new()
				cs.shape = shape
				cs.position = Vector2((x0 + x) * 0.5 * cell, (y + 0.5) * cell)
				_water_body.add_child(cs)
				x0 = -1


func _make_tileset(texture: Texture2D = null, coord_list: Array = []) -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(style.tile_size, style.tile_size)
	var src := TileSetAtlasSource.new()
	src.texture = texture if texture else style.tileset_texture
	src.texture_region_size = ts.tile_size
	var used: Dictionary = {}
	for coords in (coord_list if texture else result.dirt.values() + result.grass.values()):
		used[coords] = true
	for coords in used:
		src.create_tile(coords)
	ts.add_source(src, 0)
	return ts


## `pos` is the bottom-centre of the sprite.
func add_prop_sprite(parent: Node, set: PropSet, region: int, pos: Vector2, s: float, flip: bool) -> void:
	var r: Rect2 = set.regions[region]
	var sp := Sprite2D.new()
	sp.texture = set.texture
	sp.region_enabled = true
	sp.region_rect = r
	sp.centered = false
	sp.flip_h = flip
	sp.scale = Vector2(s, s)
	sp.position = pos - Vector2(r.size.x * 0.5, r.size.y) * s
	parent.add_child(sp)


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Map"

func debug_category() -> String:
	return "World"

func debug_children() -> Array:
	var out: Array = []
	if style:
		for gd in style.grounds:   # the island grounds (edge outline, corner cut ...): changing one re-bakes the ground
			if gd:
				out.append({"name": "Ground " + String(gd.id), "object": gd})
		for bd in style.biomes:   # climate point, ground, trees, rocks, deco, tint of every biome (0038)
			out.append({"name": "Biome " + bd.label, "object": bd})
	if style and style.pixel_plains != null:
		out.append({"name": "Pixel Plains", "object": style.pixel_plains})
	for k in ["tree", "rock", "copper_rock", "tree_oak_sapling", "tree_oak_young", "tree_oak_small", "tree_oak_mature", "tree_oak_old", "tree_fir_sapling", "tree_fir_young", "tree_fir_small", "tree_fir_mature", "tree_fir_old"]:
		out.append({"name": "Node " + k.replace("_rock", ""), "object": load("res://data/resource_nodes/%s.tres" % k), "cat": "Items & Crafting"})
	return out

func debug_actions() -> Array:
	return [
		{"label": "New map", "run": new_map},
		{"label": "Go home", "run": func(): teleport_player("home")},
		{"label": "Go to boss", "run": func(): teleport_player("boss")},
		{"label": "Biome map", "toggle": func(): return biome_map_on, "run": func(): biome_map_on = not biome_map_on},
		{"label": "Generate", "arg": "int", "hint": "seed", "run": func(v): generate_seed(clampi(int(v), 1, 9999))},   # seed 1-9999
	]

## A slider that rebuilds the world (applied when the drag ENDS): every ArenaMap number that is not a look. The look / camera ones are cheap and follow the drag.
func debug_heavy(prop: String) -> bool:
	for pre in ["ground_", "foam_", "shimmer_", "shallow_tint", "wave_", "drift_", "shade_", "biome_map_", "camera_", "path_", "camp_", "dirt_patch", "tint_", "load_radius", "unload_margin", "chunks_per_frame"]:
		if prop.begins_with(pre):
			return false
	return true
