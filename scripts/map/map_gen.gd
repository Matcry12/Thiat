class_name MapGen
extends RefCounted
## Pure logic of the procedural arena: no nodes, no textures. Same seed + same Params + same style
## = exactly the same map. ArenaMap turns the Result into tiles and sprites; tests read it directly.
##
## Ground model (see MapStyle): dirt everywhere below, grass above with rectangular HOLES (the dirt
## patches). The tile set has no concave corners and no 1-wide strips, so patches are rectangles of
## at least 2x2 cells with at least MIN_GAP grass cells between any two (diagonals too).

const MIN_GAP := 2
const PATCH_MIN := 2
const FILL := 0   ## cell kinds: full grass, hole (dirt shows), ring (grass with a bumpy edge)
const HOLE := 1
const RING := 2
const FLOW_STEP := 16.0   ## cell size of the walkability grid, in px
const WATER := 3          ## fourth cell kind: no ground tile, water shows
enum Area { FOREST, ROCKY, BOSS }
## What a cell is (0038 step 3): dry land, deep water (ocean: blocks walking, the island edge), shallow water (rivers, lakes, the coast shallows: walkable).
enum WaterKind { NONE, OCEAN, SHALLOW }
## Climate biomes (0038): every land cell has one, picked from temperature / humidity / roughness noise.
enum Biome { PLAINS, FOREST, AUTUMN, TAIGA, SNOWY, ROCKY, SWAMP, BEACH_SAND, BEACH_GRAVEL }
const AGES := [&"sapling", &"young", &"small", &"mature", &"old"]   ## tree ages. Node ids: tree_<model>_<age> (green) or tree_<model>_<season>_<age>, model oak / fir / pine
## Own random streams, so changing one pass never moves another (the ground uses +101). Resource kinds: SEED_KIND + kind index * 3 + area.
const SEED_BIOME := 301
const SEED_TREES := 302
const SEED_CLEARINGS := 303
const SEED_DECO := 304
const SEED_CLIMATE := 310   ## +0 temperature, +1 humidity, +2 roughness, +3 / +4 domain warp x / y, +5 beach edge
const SEED_WATER := 320     ## +0 continent, +1 river ridge, +2 lake edge, +3 swamp wobble, +4 shallow width, +5 lake placing (rng), +6 pond wetness
const SEED_ROCKS := 330     ## + biome id: the rock groups (their middle pieces are rock nodes, the small stones deco)
const SEED_TREE_BIOME := 350 ## + biome id: that biome's tree tries (one stream per biome, so a slider on one never moves another biome's trees)
const SEED_VEG := 1000      ## + pass * 16 + biome id: 0 bushes, 1 flowers, 2 foxglove, 3 mushrooms, 4 stumps, 5 reeds, 6 tufts, 7 rock pieces (one stream per pass AND biome)
const SEED_VEG_NOISE := 1900 ## +0 density noise, +1 ground mix noise
const SEED_KIND := 400
const SEED_KIND_BIOME := 700 ## + kind index * 16 + biome id: lone rocks and copper per biome
const TREE_BLOCK := 16.0
## Island ground kinds (decision 0033); the ids the ground array holds (Pixel Plains maps them to its own materials). WATER has no tiles.
enum Ground { WATER, DIRT, COBBLE, GRASS, BOSS, SAND, SNOW }
const AREA_GROUND := [Ground.GRASS, Ground.COBBLE, Ground.DIRT]   ## Area -> its ground. Only the boss area (= dirt, 0035) still uses it: every other ground comes from BiomeData.ground
## The biomes themselves (climate points, ground, trees, rocks, deco, tints, colours) are data: BiomeData in data/biomes/, listed in MapStyle.biomes.
## Area is just "boss land or not" since 0038 step 4 (every other cell is FOREST); ROCKY is only left for the old flat-map ground.
## Step 1 caveat: the clash repair below names TAIGA / FOREST as the in-between biomes (hardwired, not data).

class Params:
	var cols := 36
	var rows := 21
	var cell := 32.0
	var world := Vector2(1152, 648)   ## the screen; the grid may overhang it by a part cell
	var patch_count := 4
	var patch_min_size := 3
	var patch_max_size := 7
	var noise_frequency := 0.1
	var patch_noise_threshold := 0.5
	var deco_density := 0.1
	var deco_min_spacing := 30.0
	var obstacle_count := 6
	var obstacle_min_spacing := 40.0
	var spawn_clear_radius := 110.0
	var border_density := 0.9
	var dark_grass_chance := 0.0
	var agent_radius := 14.0      ## the widest walker that must still reach all floor
	var zone := Rect2()           ## FightZone: obstacles never touch it
	var spawns := PackedVector2Array()
	var player_spawn := Vector2.ZERO
	var island_on := false            ## false = the old flat map (every cell land, one area)
	# Continent (0038 step 3). Lengths are for the 512 x 512 island and shrink on a smaller map (_world_scale).
	var cont_period := 230.0          ## cells per wave of the continentalness noise: bays and peninsulas
	var cont_octaves := 4
	var cont_gain := 1.6              ## how strongly the noise (vs. the round blob) shapes the coast
	var cont_radial := 0.55           ## weight of the one-big-blob falloff vs the noise (1 = a round island)
	var cont_edge_cells := 70.0       ## the land fades to ocean this far from the map edge
	var land_share := 0.42            ## share of the map that is land before the cut-off pieces are dropped (sea level)
	var neck_cells := 30.0            ## half width of the land ridge along the home -> boss line
	var neck_boost := 0.5             ## how much that ridge lifts the land (0 = none: home and the zone may sit on separate islands)
	var coast_cells := 3              ## this many cells at the map edge are always water
	var home_clear_cells := 6         ## land disc around home, always
	var corridor_half := 2            ## half width of the land bridge carved when home and boss are cut apart
	# Water (0038 step 3)
	var water_on := true              ## false = no rivers, lakes or shallows (the island is dry land and deep ocean)
	var river_period := 260.0         ## cells per wave of the ridge noise
	var river_octaves := 5
	var river_w_inland := 2.5         ## half width in cells far from the sea ...
	var river_w_sea := 3.5            ## ... and at the sea
	var river_grow_dist := 110.0      ## distance from the sea over which the width goes from river_w_sea to river_w_inland
	var river_rough_max := 0.88       ## no river on peaks (roughness above this)
	var river_min_cells := 600         ## river pieces smaller than this are dropped
	var river_inland_min := 22.0      ## a river must get at least this far from the sea somewhere (else it only hugs the coast)
	var lake_humid_min := 0.35        ## lake centres only where humidity is above this ...
	var lake_inland_min := 8.0        ## ... at least this many cells (plus 1.4 radii) from the sea ...
	var lake_rough_max := 0.85        ## ... and not rougher than this
	var lake_min_cells := 400
	var water_min_cells := 40         ## after rivers + lakes: a fresh-water body (4-connected) smaller than this is land again (no 1-3 cell specks)
	var river_big_n := 2
	var river_big_w_inland := 4.5
	var river_big_w_sea := 8.0
	var river_big_reach := 3
	var lake_big_n := 4
	var lake_big_r_min := 16.0
	var lake_big_r_max := 22.0
	var lake_big_on_river := 2
	var lake_pond_n := 0
	var lake_pond_r_min := 1.5
	var lake_pond_r_max := 4.0
	var lake_pond_on_river := 0.3
	var lake_pond_wet_min := 0.62
	var lake_pond_wet_period := 70.0
	var lake_pond_stretch_min := 1.0
	var lake_pond_stretch_max := 2.4
	var lake_pond_blobs_min := 1
	var lake_pond_blobs_max := 3
	var lake_warp := 3.5
	var lake_shape_period := 30.0
	var lake_gap := 8
	var shore_cells := 1.5            ## land shore around a river / lake: 1 = one ring, 2 = two rings, 1.5 = a ragged second ring
	var shallow_min := 1.0            ## ocean shallows along the coast are between these many cells wide (noise)
	var shallow_max := 2.4
	# Climate (decision 0038). Periods are cells per wave: the 512 island of step 2 will want them about 2.5x longer.
	var climate_temp_period := 120.0  ## slowest map: big climate zones
	var climate_humid_period := 60.0
	var climate_rough_period := 40.0
	var climate_warp_period := 36.0   ## domain warp: wavelength and strength (cells); bends borders like coastlines
	var climate_warp_amp := 11.0
	var climate_octaves := 4
	var climate_warp_octaves := 3
	var beach_noise_period := 20.0    ## cells per wave of the noise that makes the beach band ragged
	var beach_noise_octaves := 2
	var biome_smooth_half := 3        ## majority window = 2 * this + 1 cells
	var boss_land_cells := 12         ## boss land (area BOSS: its ground and densities) = the fight zone grown by this many cells
	var climate_w_temp := 3.0         ## biome lookup: how much each axis counts in "nearest point"
	var climate_w_humid := 1.0
	var climate_w_rough := 1.1
	var forest_margin := 0.2          ## "forestness" f goes 0 -> 1 as a tree-biome point gets this much nearer than the Plains points (climate units): how wide the tree band at a Plains border is
	var biome_smooth_passes := 2      ## majority passes over the biome map (kills speckle)
	var biome_min_blob := 90          ## smaller biome patches take the nearest big biome (unless they separate warm from cold)
	var beach_min := 1.5              ## beach band width (cells) varies between these with noise
	var beach_max := 3.2
	var cold_beach_t := 0.30          ## temperature below this: gravel beach, else sand
	var home_calm_cells := 10.0       ## around home the climate is pulled to a mild one (Plains / Forest): full pull inside, fading over `home_calm_fade`
	var home_calm_fade := 16.0
	var calm_temp := 0.55
	var calm_humid := 0.42
	var calm_rough := 0.25
	# Looks only (decision 0033): nothing below changes where anything can walk, stand or be placed.
	var border_jitter := 0.35         ## share of border cells that swap to the neighbour's ground before smoothing: breaks ruler-straight borders
	var min_island_cells := 14        ## ground patches smaller than this are absorbed by their surroundings (visual ground only)
	var smooth_passes := 2            ## majority passes that remove 1-cell spikes / holes / checkerboards before tiling
	var beach_cells := 0              ## dirt strip along the coast, in cells (0 = none: the biome beaches, sand / gravel, are the shore now)
	var legacy_tiles := true          ## false = skip the old tile dictionaries and dirt patches (res.patches / kind / grass / dirt / water): the island ground picture does not read them, and at 512x512 they cost ~0.8 s and tens of MB. Only honoured on an island with grounds and resource nodes (the main random stream is not used after them there)
	var path_on := true
	var path_width := 3               ## main path, cells (branches are one less, never under 2)
	var path_branches := 3
	var path_wobble := 0.6            ## how much the path wanders around trees and bends (0 = straightest)
	var camp_radius := 2              ## dirt clearing around the campfire, cells
	var dirt_patches := 0.0           ## random dirt patches per 100 forest cells. Off: dirt needs a reason (0035)
	var dirt_patch_size := 2.5        ## biggest patch radius, cells
	# Vegetation (0037 + 0038 step 4, rules in docs/wiki/vegetation-rules.md). What each biome grows is BiomeData (F3 "Biome <label>"); these are the shared numbers.
	var trees_on := true              ## false = the old flat density trees everywhere
	var pp: PixelPlainsGround = null  ## Pixel Plains ground: its per-biome show_* switches pick what grows (trees: treepp_* nodes only); null = the old art
	var veg_on := true                ## false = no biome deco passes (flowers, tufts, bushes ... and the rock groups' small stones)
	var band_lo := 0.45               ## border band between an open (Plains) and a wooded biome: below it no forest tries, above band_hi always
	var band_hi := 0.65
	var tree_fade_lo := 0.35          ## BiomeData.fade_by_density: a try's chance goes 0 -> 1 as the local density d goes lo -> hi
	var tree_fade_hi := 0.55
	var veg_density_period := 18.0    ## cells per wave of the local density noise d (drives tree age, bush gating)
	var copper_near_home_cells := 0.0  ## at least one copper rock (with two rocks beside it) stands on dry land within this many cells of home; 0 = no promise
	var rock_group_radius := 2.2      ## cells: middle rock pieces of a group lie within this of its centre (mineable rocks need room)
	var fir_group_radius := 3.0       ## cells: a tree group (BiomeData.group_model) spreads this far
	var age_core := 0.75              ## f above = core (old / mature)
	var age_mid := 0.60               ## f above = mid (mature / small); below = edge (young / sapling / small)
	var core_old := 0.5
	var mid_small := 0.2
	var edge_young := 0.5
	var edge_sapling := 0.3
	var clearing_per_cells := 1600.0  ## one forest clearing per this many forest-biome cells
	var clearing_r_min := 3.0         ## cells
	var clearing_r_max := 5.0
	var yard := false                 ## Test yard (decision 0056): all land, one Plains biome, no water/vegetation, the nodes are exactly `yard_nodes`
	var yard_nodes: Array[Dictionary] = []   ## {id: StringName (ResourceNodeData id), pos: Vector2 (collision circle centre)}
	var tree_home_clear := 4          ## no tree this many cells around home
	var tree_jitter := 0.35           ## trunk wanders this far (cells) from its cell centre, each axis; overlapping trunks are dropped

	func size_px() -> Vector2:
		return world


class Result:
	var seed := 0
	var patches: Array[Rect2i] = []          ## the holes, in cells
	var kind := PackedByteArray()            ## FILL / HOLE / RING per cell (index y * cols + x)
	var grass: Dictionary = {}               ## Vector2i cell -> Vector2i atlas coord (no entry = no grass tile)
	var dirt: Dictionary = {}                ## Vector2i cell -> Vector2i atlas coord (every cell)
	var deco: Array[Dictionary] = []         ## {set, region, pos}  pos = bottom-centre of the sprite
	var obstacles: Array[Dictionary] = []    ## {region, pos (collision circle centre), radius, node}  node = index into style.resource_nodes, -1 = plain cover rock
	var border: Array[Dictionary] = []       ## {region, pos (bottom-centre), flip}
	var water: Dictionary = {}               ## Vector2i cell -> atlas coord of the old water sheet (retired: unused)
	var land := PackedByteArray()            ## 1 land, 0 water, per cell
	var bridge := {}                         ## Vector2i cell -> true for every cell of the carved land bridge (stations may not stand there)
	var area := PackedByteArray()            ## Area per cell (ignore on water)
	var ground := PackedByteArray()          ## Ground per cell (island look, smoothed; WATER on water). Empty = the style has no island grounds
	var dirt_stamps := PackedVector3Array()  ## round dirt stamps (world x, y, radius px): patches, camp, paths. Look only
	var dirt_cells := {}                     ## Vector2i cell -> true under a stamp (deco keeps off them)
	var cell := 32.0                         ## cell size the stamps were made with
	var cols := 0                            ## grid size land/area were built with (Params may change later)
	var rows := 0
	var obstacle_grid := {}                  ## Vector2i bucket -> Array of obstacle dicts (spacing lookups)
	var obstacle_bucket := 1.0               ## bucket size: at least 2 * the largest radius + spacing
	var f := PackedFloat32Array()            ## "forestness" per cell, 0..1: 0 deep in Plains climate, 0.5 on a Plains | tree-biome border, 1 deep in tree-biome climate (island only; empty otherwise)
	var biome := PackedByteArray()           ## Biome per land cell, from the climate (island only; empty otherwise)
	var temp := PackedFloat32Array()         ## climate per cell, 0..1 (after the home calm), for F3
	var humid := PackedFloat32Array()
	var rough := PackedFloat32Array()
	var biomes: Array[BiomeData] = []        ## style.biomes: the data of every biome id (island only)
	var clearings: Array[Vector3] = []       ## forest clearings: (cell x, cell y, radius in cells)
	var walk_base := PackedByteArray()       ## _walk_free of the final land, kept while generate runs so the rock passes do not recompute it (cleared at the end)
	var walk_base_n := 0                     ## number of 1s in walk_base
	var ground_base := PackedByteArray()     ## the ground before dirt stamps and beach, kept so a look slider does not redo it (see _build_ground)
	var ground_dist := PackedByteArray()
	var ground_key := []
	var walk_land := PackedByteArray()       ## dry land + shallow water: 1 where a walker may stand. The walk grid, the water collision and the repair floods read this; `land` is dry land only
	var shallow := PackedByteArray()         ## 1 on shallow water (rivers, lakes, the first ocean cells along the coast): walkable, nothing is placed on it. Empty on a flat map
	var fresh := PackedByteArray()           ## 1 river, 2 lake (a subset of `shallow`)
	var shore := PackedByteArray()           ## 1 on the dry land cells around a river / lake: their ground is BiomeData.shore_ground
	var warp_x := PackedFloat32Array()       ## the domain warp (cells) per cell, shared by the continent, the climate and the water; freed when the water is done
	var warp_y := PackedFloat32Array()
	var coast_dist := PackedByteArray()      ## _water_dist of the dry land at biome time (1 = touches the ocean); freed when the water is done
	var timings := {}                        ## stage name -> ms of the last generate (F3 / profiling)
	# Scratch of the vegetation passes (0038 step 4); freed at the end of generate.
	var veg_bcols := 0                       ## blocks (16 x 16 cells) per row
	var veg_nblocks := 0
	var veg_blocks: Array[PackedInt32Array] = []   ## [biome * veg_nblocks + block] -> indices of that biome's dry, non-boss cells in the block
	var veg_by_biome: Array[PackedInt32Array] = [] ## [biome] -> the same cells, whole map
	var veg_all := PackedInt32Array()        ## every dry non-boss cell
	var veg_occ := PackedByteArray()         ## per cell: 0 free, 1 trunk, 2 rock, 3 bush, 4 reed, 5 tuft
	var veg_clear := PackedByteArray()       ## per cell: 1 inside a clearing
	var rock_pieces := PackedVector3Array()  ## decoration of the rock groups, (cell x, cell y, 0 boulder brown / 1 boulder grey / 2 stone brown / 3 stone grey); BiomeVeg turns them into deco


static func generate(style: MapStyle, p: Params, rng_seed: int) -> Result:
	var res := Result.new()
	res.seed = rng_seed
	res.biomes = style.biomes
	var t := Time.get_ticks_usec()
	MapGenIsland._shape_island(res, p)
	t = _lap(res, "shape", t)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, p.noise_frequency)
	# The old tile dictionaries are not read by the island ground picture; a big map skips them (Params.legacy_tiles).
	if p.legacy_tiles or not (p.island_on and not style.resource_nodes.is_empty() and style.pixel_plains != null):
		MapGenFlat._place_patches(res, p, rng, noise)
		t = _lap(res, "patches", t)
		MapGenFlat._assign_ground(res, style, p, rng)
		t = _lap(res, "assign_ground", t)
	if p.island_on and not style.resource_nodes.is_empty():
		MapGenNodes._place_nodes(res, style, p)   # on the island every rock is a resource node
	else:
		MapGenFlat._place_obstacles(res, style, p, rng)
	t = _lap(res, "nodes", t)
	if p.island_on and style.pixel_plains != null:
		MapGenGround._build_ground(res, style, p)
	t = _lap(res, "ground", t)
	if p.island_on and BiomeVeg.has_sets(style):   # the island's deco = the biome passes; the flat map keeps the old scatter
		if p.veg_on:
			BiomeVeg.place(res, style, p)
	else:
		MapGenDeco._place_deco(res, style, p, _rng(rng_seed + SEED_DECO), _noise(rng_seed + 2, p.noise_frequency))
	t = _lap(res, "deco", t)
	if not p.island_on:
		MapGenDeco._place_border(res, style, p, rng)   # on the island the water is the edge
	# res.walk_base stays: ArenaMap.blocks_boss_path copies it instead of rebuilding the 512 x 512 walk grid at the first placement
	res.veg_blocks = []
	res.veg_by_biome = []
	res.veg_all = PackedInt32Array()
	res.veg_occ = PackedByteArray()
	res.veg_clear = PackedByteArray()
	res.rock_pieces = PackedVector3Array()
	return res


## Records the ms since `t` (usec) under `name`; returns the new "now".
static func _lap(res: Result, name: String, t: int) -> int:
	var now := Time.get_ticks_usec()
	res.timings[name] = res.timings.get(name, 0.0) + (now - t) / 1000.0
	return now


static func _rng(rng_seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = rng_seed
	return r


static func _noise(noise_seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed
	n.frequency = freq
	return n


static func _n01(n: FastNoiseLite, x: float, y: float) -> float:
	return n.get_noise_2d(x, y) * 0.5 + 0.5


# ------------------------------------------------------------------- island ---

static func cell_index(p: Params, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= p.cols or c.y >= p.rows:
		return -1
	return c.y * p.cols + c.x


static func is_land(res: Result, p: Params, c: Vector2i) -> bool:
	var i := cell_index(p, c)
	return i >= 0 and res.land[i] == 1


## Dry land or shallow water: where a walker may stand (the deep ocean is the only wall).
static func is_walkable(res: Result, p: Params, c: Vector2i) -> bool:
	var i := cell_index(p, c)
	return i >= 0 and res.walk_land[i] == 1


## What the cell is: NONE (dry land), OCEAN (deep, blocks walking) or SHALLOW (walkable water). Off the grid = OCEAN.
static func water_kind(res: Result, p: Params, c: Vector2i) -> int:
	var i := cell_index(p, c)
	if i < 0:
		return WaterKind.OCEAN
	if res.land[i] == 1:
		return WaterKind.NONE
	return WaterKind.SHALLOW if not res.shallow.is_empty() and res.shallow[i] == 1 else WaterKind.OCEAN


## True when every cell the circle (centre `pos`, radius `reach`, px) touches is dry land: a 1-cell river between sample points cannot hide.
static func circle_on_land(res: Result, p: Params, pos: Vector2, reach: float) -> bool:
	var c0 := Vector2i(((pos - Vector2(reach, reach)) / p.cell).floor())
	var c1 := Vector2i(((pos + Vector2(reach, reach)) / p.cell).floor())
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			var nearest := Vector2(clampf(pos.x, cx * p.cell, (cx + 1) * p.cell), clampf(pos.y, cy * p.cell, (cy + 1) * p.cell))
			if nearest.distance_to(pos) <= reach and not is_land(res, p, Vector2i(cx, cy)):
				return false
	return true


## Boss land: the zone rect grown by `boss_land_cells` (area BOSS).
static func boss_cells(p: Params) -> Rect2i:
	var a := Vector2i((p.zone.position / p.cell).floor())
	var b := Vector2i((p.zone.end / p.cell).ceil())
	return Rect2i(a, b - a).grow(p.boss_land_cells)


static func zone_cells(p: Params) -> Rect2i:
	var a := Vector2i((p.zone.position / p.cell).floor())
	var b := Vector2i((p.zone.end / p.cell).ceil())
	return Rect2i(a, b - a).grow(3)


## Public / test-facing entry points of the stage files (one owner each, see map_gen_<stage>.gd).

static func climate_clashes(res: Result) -> int:
	return MapGenBiomes.climate_clashes(res)

static func make_veg_lists(res: Result, p: Params) -> void:
	MapGenNodes.make_veg_lists(res, p)

static func veg_noise(res_seed: int, p: Params) -> FastNoiseLite:
	return MapGenNodes.veg_noise(res_seed, p)

static func veg_density(res: Result, bd: BiomeData, noise: FastNoiseLite, x: float, y: float, ci: int) -> float:
	return MapGenNodes.veg_density(res, bd, noise, x, y, ci)

static func veg_count(rng: RandomNumberGenerator, v: float) -> int:
	return MapGenNodes.veg_count(rng, v)

static func rock_clearance(p: Params) -> float:
	return MapGenWalk.rock_clearance(p)

static func _walk_free(p: Params, land := PackedByteArray(), count := PackedInt32Array()) -> PackedByteArray:
	return MapGenWalk._walk_free(p, land, count)

static func _walk_free_patch(p: Params, land: PackedByteArray, free: PackedByteArray, changed: PackedInt32Array) -> int:
	return MapGenWalk._walk_free_patch(p, land, free, changed)

static func _span_fill(open: PackedByteArray, seen: PackedByteArray, w: int, h: int, start: int, want := 1, spans := PackedInt32Array(), stack := PackedInt32Array()) -> int:
	return MapGenWalk._span_fill(open, seen, w, h, start, want, spans, stack)

static func floor_reachable(p: Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool:
	return MapGenWalk.floor_reachable(p, obstacles, land)

static func walk_grid(p: Params, obstacles: Array[Dictionary], land: PackedByteArray, base := PackedByteArray()) -> PackedByteArray:
	return MapGenWalk.walk_grid(p, obstacles, land, base)

static func goal_reachable_with(p: Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2) -> bool:
	return MapGenWalk.goal_reachable_with(p, free, blockers, goal)

static func blockers_keep_local_walk(p: Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2, margin := 12) -> bool:
	return MapGenWalk.blockers_keep_local_walk(p, free, blockers, goal, margin)

static func rebuild_ground(res: Result, style: MapStyle, p: Params) -> void:
	MapGenGround.rebuild_ground(res, style, p)
