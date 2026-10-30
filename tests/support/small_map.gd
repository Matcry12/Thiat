extends RefCounted
## Map sizes the 200 x 120 vegetation tests were tuned at (before v3 made biomes 2x and water fewer / bigger for the 512 island).
const V2 := {"climate_temp_period": 300.0, "climate_humid_period": 150.0, "climate_rough_period": 100.0, "climate_warp_period": 90.0,
	"biome_min_blob": 90, "biome_smooth_half": 3, "home_calm_cells": 10.0, "home_calm_fade": 16.0,
	"river_period": 110.0, "river_min_cells": 40, "river_w_inland": 1.5, "river_w_sea": 2.5, "river_big_w_inland": 2.5, "river_big_w_sea": 5.5,
	"copper_near_home_cells": 70.0, "lake_min_cells": 6, "lake_big_n": 3, "lake_big_r_min": 9.5, "lake_big_r_max": 12.5, "lake_gap": 4, "lake_pond_n": 30, "lake_shape_period": 11.0}

## Rocks (and copper, below) as they were before v4 / v5 turned them off in the data (these tests check the rock rules): label -> [rock_per_block, rock_nodes_per_100].
const ROCKS := {"plains": [1.0, 0.4], "forest": [0.5, 0.4], "autumn": [0.3, 0.4], "taiga": [0.6, 0.5], "snowy": [0.5, 0.8], "rocky": [2.6, 0.0]}
const ROCK_DENSITY_BOSS := 0.5
const COPPER := {"rocky": 0.6, "snowy": 0.3}   ## copper_per_100 before v5 turned copper off

static func apply(map: Node) -> void:
	for k in V2:
		map.set(k, V2[k])
	for bd in map.style.biomes:
		if ROCKS.has(bd.label):
			bd.rock_per_block = ROCKS[bd.label][0]
			bd.rock_nodes_per_100 = ROCKS[bd.label][1]
		bd.copper_per_100 = COPPER.get(bd.label, 0.0)
	for kind in map.style.resource_nodes:
		if kind.id == &"rock":
			kind.density_boss = ROCK_DENSITY_BOSS
