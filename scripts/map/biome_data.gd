class_name BiomeData
extends Resource
## One climate biome (decision 0038): where it sits in the climate, which ground it gets, everything that grows on it (trees, rocks, bushes, flowers ...), how it looks.
## One .tres per biome in data/biomes/, listed in MapStyle.biomes IN THE ORDER OF MapGen.Biome (the position is the biome id).
## Step 4 (built): the per-biome vegetation lives here, one export per number, so F3 shows and tunes all of it. Port of tools/asset_viewer/biome_looks.py (BIOMES table).
## F3 shows a section per biome. A change to a climate / ground / vegetation field rebuilds the map (F3: on drag end); a change to a look field (tint, map colour)
## only re-tints (signal `look_changed`).

signal look_changed

enum Role { NEUTRAL, OPEN, WOODED }   ## see `forest_role`
const SEASONS := [&"green", &"yellow", &"orange", &"red", &"teal", &"dead", &"snow"]   ## tree colour index (treeN_season) -> catalog season
const MODELS := [&"", &"oak", &"fir", &"pine"]   ## treeN_model -> name in the node ids

@export var label := "":
	set(v):
		label = v
		emit_changed()
## Up to 3 climate points (temperature, humidity, roughness, each 0..1; roughness goes up to ~1.3 for hills). A cell takes the biome of its
## NEAREST point. 0 points = never picked from the climate (beaches).
@export_range(0, 3) var points_used := 1:
	set(v):
		points_used = v
		emit_changed()
@export var a_temp := 0.5:
	set(v):
		a_temp = v
		emit_changed()
@export var a_humid := 0.5:
	set(v):
		a_humid = v
		emit_changed()
@export var a_rough := 0.5:
	set(v):
		a_rough = v
		emit_changed()
@export var b_temp := 0.5:
	set(v):
		b_temp = v
		emit_changed()
@export var b_humid := 0.5:
	set(v):
		b_humid = v
		emit_changed()
@export var b_rough := 0.5:
	set(v):
		b_rough = v
		emit_changed()
@export var c_temp := 0.5:
	set(v):
		c_temp = v
		emit_changed()
@export var c_humid := 0.5:
	set(v):
		c_humid = v
		emit_changed()
@export var c_rough := 0.5:
	set(v):
		c_rough = v
		emit_changed()
## Neighbours may never differ by 2+ (snow next to autumn). -1 = exempt (rocky, beaches).
@export var temp_class := 2:
	set(v):
		temp_class = v
		emit_changed()
## MapGen.Ground index: 2 cobble, 3 grass, 5 sand, 6 snow.
@export var ground := 3:
	set(v):
		ground = v
		emit_changed()
## MapGen.Ground of the 1-2 land cells around a river or lake (0038 step 3): 1 dirt, 5 sand. Beaches and the boss land keep their own.
@export var shore_ground := 1:
	set(v):
		shore_ground = v
		emit_changed()
## Wet-lowland pull (0038 step 3): a land cell within this many cells of a river / lake (a ragged edge) takes THIS biome when the climate
## also fits (humidity above, roughness below, temperature between; all 0..1). 0 = off. Swamp uses it; any biome may.
@export var fresh_pull_cells := 0.0:
	set(v):
		fresh_pull_cells = v
		emit_changed()
@export var fresh_humid_min := 0.45:
	set(v):
		fresh_humid_min = v
		emit_changed()
@export var fresh_rough_max := 0.6:
	set(v):
		fresh_rough_max = v
		emit_changed()
@export var fresh_temp_min := 0.4:
	set(v):
		fresh_temp_min = v
		emit_changed()
@export var fresh_temp_max := 0.88:
	set(v):
		fresh_temp_max = v
		emit_changed()
## Ground colour on top of the ground's own picture: brightness, warm (+ redder, - bluer), colour strength (0..2, 1 = unchanged). Live.
@export var tint_bright := 1.0:
	set(v):
		tint_bright = v
		look_changed.emit()
@export var tint_warm := 0.0:
	set(v):
		tint_warm = v
		look_changed.emit()
@export var tint_sat := 1.0:
	set(v):
		tint_sat = v
		look_changed.emit()
## Colour on the F3 "Biome map" layer. Live.
@export var map_color := Color.WHITE:
	set(v):
		map_color = v
		look_changed.emit()


@export_group("Trees")
## 0 neutral, 1 open (Plains: the f value fades its trees OUT toward Forest), 2 wooded (Forest-like: f fades its trees IN, and f is the Plains | wooded blend). Also tells the climate map which table points are Plains and which are tree biomes.
@export var forest_role := 0:
	set(v):
		forest_role = v
		emit_changed()
## Forest-like: gets round clearings (no trees / rocks / bushes inside, flowers and tufts stay).
@export var has_clearings := false:
	set(v):
		has_clearings = v
		emit_changed()
## Tree tries per 16x16-cell block (scaled by this biome's share of the block). 0 = no trees.
@export var tree_tries := 0.0:
	set(v):
		tree_tries = v
		emit_changed()
## A tree keeps this many cells free of other trunks around it (lone trees). 0 = only the trunk cell and its 4 neighbours.
@export var tree_ring := 0:
	set(v):
		tree_ring = v
		emit_changed()
## Local density d runs between these two values with a smooth noise (period `veg_density_period`). d picks the tree age and fades tries.
@export var dens_lo := 0.0:
	set(v):
		dens_lo = v
		emit_changed()
@export var dens_hi := 1.0:
	set(v):
		dens_hi = v
		emit_changed()
## A try's chance fades with d between `tree_fade_lo` and `tree_fade_hi` (Map section, Vegetation): thin spots get fewer trees.
@export var fade_by_density := false:
	set(v):
		fade_by_density = v
		emit_changed()
## 0 = forest rule (old core, young edge, by d and the Map age numbers), 1 = fixed weights below.
@export var age_rule := 0:
	set(v):
		age_rule = v
		emit_changed()
## Fixed age weights (age_rule 1).
@export var age_w_sapling := 0.0:
	set(v):
		age_w_sapling = v
		emit_changed()
@export var age_w_young := 0.0:
	set(v):
		age_w_young = v
		emit_changed()
@export var age_w_small := 0.0:
	set(v):
		age_w_small = v
		emit_changed()
@export var age_w_mature := 1.0:
	set(v):
		age_w_mature = v
		emit_changed()
@export var age_w_old := 0.0:
	set(v):
		age_w_old = v
		emit_changed()
## Oldest age allowed: 0 sapling, 1 young, 2 small, 3 mature, 4 old. A rolled age above it becomes this one.
@export var max_stage := 4:
	set(v):
		max_stage = v
		emit_changed()
## A try of this model (1 oak, 2 fir, 3 pine) seeds a group of group_min..group_max trees within `fir_group_radius` cells. 0 = none.
@export var group_model := 0:
	set(v):
		group_model = v
		emit_changed()
@export var group_min := 3:
	set(v):
		group_min = v
		emit_changed()
@export var group_max := 5:
	set(v):
		group_max = v
		emit_changed()
## Tree table, up to 6 rows: model (1 oak, 2 fir, 3 pine; 0 = unused), season (0 green, 1 yellow, 2 orange, 3 red, 4 teal, 5 dead, 6 snow), weight.
@export var tree1_model := 0:
	set(v):
		tree1_model = v
		emit_changed()
@export var tree1_season := 0:
	set(v):
		tree1_season = v
		emit_changed()
@export var tree1_weight := 0.0:
	set(v):
		tree1_weight = v
		emit_changed()
@export var tree2_model := 0:
	set(v):
		tree2_model = v
		emit_changed()
@export var tree2_season := 0:
	set(v):
		tree2_season = v
		emit_changed()
@export var tree2_weight := 0.0:
	set(v):
		tree2_weight = v
		emit_changed()
@export var tree3_model := 0:
	set(v):
		tree3_model = v
		emit_changed()
@export var tree3_season := 0:
	set(v):
		tree3_season = v
		emit_changed()
@export var tree3_weight := 0.0:
	set(v):
		tree3_weight = v
		emit_changed()
@export var tree4_model := 0:
	set(v):
		tree4_model = v
		emit_changed()
@export var tree4_season := 0:
	set(v):
		tree4_season = v
		emit_changed()
@export var tree4_weight := 0.0:
	set(v):
		tree4_weight = v
		emit_changed()
@export var tree5_model := 0:
	set(v):
		tree5_model = v
		emit_changed()
@export var tree5_season := 0:
	set(v):
		tree5_season = v
		emit_changed()
@export var tree5_weight := 0.0:
	set(v):
		tree5_weight = v
		emit_changed()
@export var tree6_model := 0:
	set(v):
		tree6_model = v
		emit_changed()
@export var tree6_season := 0:
	set(v):
		tree6_season = v
		emit_changed()
@export var tree6_weight := 0.0:
	set(v):
		tree6_weight = v
		emit_changed()

@export_group("Rocks")
## Rock groups per block. A group = rock_mid_min..max middle pieces + rock_small_min..max small stones around them.
@export var rock_per_block := 0.0:
	set(v):
		rock_per_block = v
		emit_changed()
## Middle pieces: boulder (16 px, decoration), medium or big (a ROCK NODE you can mine). Weights pick the kind.
@export var rock_mid_min := 0:
	set(v):
		rock_mid_min = v
		emit_changed()
@export var rock_mid_max := 1:
	set(v):
		rock_mid_max = v
		emit_changed()
@export var rock_w_boulder := 1.0:
	set(v):
		rock_w_boulder = v
		emit_changed()
@export var rock_w_med := 0.0:
	set(v):
		rock_w_med = v
		emit_changed()
@export var rock_w_big := 0.0:
	set(v):
		rock_w_big = v
		emit_changed()
@export var rock_small_min := 2:
	set(v):
		rock_small_min = v
		emit_changed()
@export var rock_small_max := 3:
	set(v):
		rock_small_max = v
		emit_changed()
## Cells: how far small stones lie from the group centre.
@export var rock_spread := 1.5:
	set(v):
		rock_spread = v
		emit_changed()
## Share of groups in brown stone (the rest grey).
@export var rock_brown_share := 0.0:
	set(v):
		rock_brown_share = v
		emit_changed()
## Lone minable rocks scattered over this biome, per 100 land cells (besides the groups).
@export var rock_nodes_per_100 := 0.0:
	set(v):
		rock_nodes_per_100 = v
		emit_changed()
## Copper rocks per 100 land cells of this biome.
@export var copper_per_100 := 0.0:
	set(v):
		copper_per_100 = v
		emit_changed()

@export_group("Bushes")
## Bush patches per block. bush_tries 1 = a single bush (maybe a pair), more = a patch of that many tries within +-spread cells.
@export var bush_per_block := 0.0:
	set(v):
		bush_per_block = v
		emit_changed()
@export var bush_tries := 1:
	set(v):
		bush_tries = v
		emit_changed()
@export var bush_spread := 0.0:
	set(v):
		bush_spread = v
		emit_changed()
## Chance a single bush gets a second one beside it.
@export var bush_pair := 0.0:
	set(v):
		bush_pair = v
		emit_changed()
## Only where the local density d is between these (forest edge: .45 to .7). 0 and 1 = everywhere.
@export var bush_d_lo := 0.0:
	set(v):
		bush_d_lo = v
		emit_changed()
@export var bush_d_hi := 1.0:
	set(v):
		bush_d_hi = v
		emit_changed()
## Dry shrubs instead of leafy bushes.
@export var bush_dead := false:
	set(v):
		bush_dead = v
		emit_changed()
## Colour weights.
@export var bush_w_green := 1.0:
	set(v):
		bush_w_green = v
		emit_changed()
@export var bush_w_yellow := 0.0:
	set(v):
		bush_w_yellow = v
		emit_changed()
@export var bush_w_orange := 0.0:
	set(v):
		bush_w_orange = v
		emit_changed()
@export var bush_w_red := 0.0:
	set(v):
		bush_w_red = v
		emit_changed()

@export_group("Flowers")
## Flower patches per block; one colour per patch, flower_tries within a peaked +-spread.
@export var flower_per_block := 0.0:
	set(v):
		flower_per_block = v
		emit_changed()
@export var flower_tries := 20:
	set(v):
		flower_tries = v
		emit_changed()
@export var flower_spread := 3.0:
	set(v):
		flower_spread = v
		emit_changed()
## Only inside clearings (forest).
@export var flower_in_clear := false:
	set(v):
		flower_in_clear = v
		emit_changed()
## Chance a patch gets 2-3 foxgloves at its rim.
@export var flower_fox := 0.0:
	set(v):
		flower_fox = v
		emit_changed()
## Colour weights.
@export var flower_w_orange := 1.0:
	set(v):
		flower_w_orange = v
		emit_changed()
@export var flower_w_white := 1.0:
	set(v):
		flower_w_white = v
		emit_changed()
@export var flower_w_blue := 1.0:
	set(v):
		flower_w_blue = v
		emit_changed()
@export var flower_w_yellow := 1.0:
	set(v):
		flower_w_yellow = v
		emit_changed()
## Foxglove clumps per block (swamp), fox_min..max flowers each.
@export var fox_per_block := 0.0:
	set(v):
		fox_per_block = v
		emit_changed()
@export var fox_min := 1:
	set(v):
		fox_min = v
		emit_changed()
@export var fox_max := 3:
	set(v):
		fox_max = v
		emit_changed()

@export_group("Mushrooms and tufts")
## Mushroom tries per block; a mushroom only stands within mush_shade cells of a trunk.
@export var mush_tries := 0.0:
	set(v):
		mush_tries = v
		emit_changed()
@export var mush_shade := 2.0:
	set(v):
		mush_shade = v
		emit_changed()
@export var mush_group_min := 1:
	set(v):
		mush_group_min = v
		emit_changed()
@export var mush_group_max := 3:
	set(v):
		mush_group_max = v
		emit_changed()
## Chance per land cell of a grass tuft / fern (x2 within 2 cells of a trunk or 1 of a rock).
@export var tuft_p := 0.0:
	set(v):
		tuft_p = v
		emit_changed()
## What a tuft is: weights over tuft / fern in green / yellow / brown.
@export var tuft_w_green := 0.0:
	set(v):
		tuft_w_green = v
		emit_changed()
@export var tuft_w_yellow := 0.0:
	set(v):
		tuft_w_yellow = v
		emit_changed()
@export var tuft_w_brown := 0.0:
	set(v):
		tuft_w_brown = v
		emit_changed()
@export var fern_w_green := 0.0:
	set(v):
		fern_w_green = v
		emit_changed()
@export var fern_w_yellow := 0.0:
	set(v):
		fern_w_yellow = v
		emit_changed()
@export var fern_w_brown := 0.0:
	set(v):
		fern_w_brown = v
		emit_changed()

@export_group("Water edge and snow")
## Snow-covered stumps per block.
@export var stump_per_block := 0.0:
	set(v):
		stump_per_block = v
		emit_changed()
## Chance per shore cell (land next to a river / lake) of a reed patch.
@export var reed_per_shore := 0.0:
	set(v):
		reed_per_shore = v
		emit_changed()
@export var reed_tries := 16:
	set(v):
		reed_tries = v
		emit_changed()
@export var reed_spread := 2.4:
	set(v):
		reed_spread = v
		emit_changed()
@export var reed_w_green := 1.0:
	set(v):
		reed_w_green = v
		emit_changed()
@export var reed_w_brown := 0.0:
	set(v):
		reed_w_brown = v
		emit_changed()

@export_group("Ground mix")
## Second ground mixed in by noise (MapGen.Ground index, 0 = none): rocky = stone with dirt.
@export var ground_alt := 0:
	set(v):
		ground_alt = v
		emit_changed()
## Share of the first ground (the rest is the second).
@export var ground_alt_share := 0.55:
	set(v):
		ground_alt_share = v
		emit_changed()
## Cells per clump of the mix.
@export var ground_alt_period := 6.0:
	set(v):
		ground_alt_period = v
		emit_changed()


## The climate points as Vector3(temperature, humidity, roughness).
func points() -> Array[Vector3]:
	var all: Array[Vector3] = [Vector3(a_temp, a_humid, a_rough), Vector3(b_temp, b_humid, b_rough), Vector3(c_temp, c_humid, c_rough)]
	return all.slice(0, clampi(points_used, 0, 3))


## Multiplier for the ground colour (feeds GroundBaker's tint map).
func tint_color() -> Color:
	return Color(tint_bright * (1.0 + tint_warm), tint_bright, tint_bright * (1.0 - tint_warm))


## The tree table rows that are in use: Vector3(model, season, weight).
func tree_rows() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 6:
		var w: float = get("tree%d_weight" % (i + 1))
		var m: int = get("tree%d_model" % (i + 1))
		if m > 0 and w > 0.0:
			out.append(Vector3(m, get("tree%d_season" % (i + 1)), w))
	return out
