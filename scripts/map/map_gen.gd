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
## Island ground kinds (decision 0033); the index into MapStyle.grounds. WATER has no tiles.
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
	var river_period := 110.0         ## cells per wave of the ridge noise
	var river_octaves := 5
	var river_w_inland := 1.5         ## half width in cells far from the sea ...
	var river_w_sea := 2.5            ## ... and at the sea
	var river_grow_dist := 110.0      ## distance from the sea over which the width goes from river_w_sea to river_w_inland
	var river_rough_max := 0.88       ## no river on peaks (roughness above this)
	var river_min_cells := 40         ## river pieces smaller than this are dropped
	var river_inland_min := 22.0      ## a river must get at least this far from the sea somewhere (else it only hugs the coast)
	var lake_humid_min := 0.35        ## lake centres only where humidity is above this ...
	var lake_inland_min := 8.0        ## ... at least this many cells (plus 1.4 radii) from the sea ...
	var lake_rough_max := 0.85        ## ... and not rougher than this
	var lake_min_cells := 6
	var river_big_n := 2
	var river_big_w_inland := 2.5
	var river_big_w_sea := 5.5
	var river_big_reach := 3
	var lake_big_n := 3
	var lake_big_r_min := 9.5
	var lake_big_r_max := 12.5
	var lake_big_on_river := 2
	var lake_pond_n := 30
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
	var lake_shape_period := 11.0
	var lake_gap := 4
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
	var copper_near_home_cells := 70.0 ## at least one copper rock (with two rocks beside it) stands on dry land within this many cells of home; 0 = no promise
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
	var water: Dictionary = {}               ## Vector2i cell -> atlas coord on style.water_texture (empty = no water art)
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
	var level_override := PackedByteArray()  ## Pixel Plains: a level per cell that replaces the level rules. Only tools/ground_case_scene.gd and tests set it (forced border cases)
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
	_shape_island(res, p)
	t = _lap(res, "shape", t)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var noise := _noise(rng_seed, p.noise_frequency)
	# The old tile dictionaries are not read by the island ground picture; a big map skips them (Params.legacy_tiles).
	if p.legacy_tiles or not (p.island_on and not style.resource_nodes.is_empty() and not style.grounds.is_empty()):
		_place_patches(res, p, rng, noise)
		t = _lap(res, "patches", t)
		_assign_ground(res, style, p, rng)
		t = _lap(res, "assign_ground", t)
	if p.island_on and not style.resource_nodes.is_empty():
		_place_nodes(res, style, p)   # on the island every rock is a resource node
	else:
		_place_obstacles(res, style, p, rng)
	t = _lap(res, "nodes", t)
	if p.island_on and not style.grounds.is_empty():
		_build_ground(res, style, p)
	t = _lap(res, "ground", t)
	if p.island_on and BiomeVeg.has_sets(style):   # the island's deco = the biome passes; the flat map keeps the old scatter
		if p.veg_on:
			BiomeVeg.place(res, style, p)
	else:
		_place_deco(res, style, p, _rng(rng_seed + SEED_DECO), _noise(rng_seed + 2, p.noise_frequency))
	t = _lap(res, "deco", t)
	if not p.island_on:
		_place_border(res, style, p, rng)   # on the island the water is the edge
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


## Fills res.land and res.area. Shape = the continent (see _make_continent); then only the land connected to home is kept, a bridge
## is carved if the boss zone is cut off, the climate biomes are made, then the water (rivers, lakes, shallows) is cut out of the land
## and what a walker cannot reach is dropped (_make_water, _prune_unwalkable).
static func _shape_island(res: Result, p: Params) -> void:
	var n := p.cols * p.rows
	res.cols = p.cols
	res.rows = p.rows
	res.land.resize(n)
	res.area.resize(n)
	res.area.fill(Area.FOREST)
	if not p.island_on:
		res.land.fill(1)
		res.walk_land = res.land
		return
	res.land.fill(0)
	var home := Vector2i(p.player_spawn / p.cell)
	var zc := zone_cells(p)
	var t := Time.get_ticks_usec()
	_make_continent(res, p, home, zc)
	t = _lap(res, "shape.continent", t)
	_open_land(res, p, home, zc)
	t = _lap(res, "shape.open", t)
	var zi := cell_index(p, zc.get_center())
	var reached := _flood_land(res, p, home)
	if zi < 0 or reached[zi] == 0:
		_carve(res, p, home, zc.get_center())
		reached = PackedByteArray()
	t = _lap(res, "shape.flood+carve", t)
	_drop_cut_off(res, p, home, reached)
	t = _lap(res, "shape.dropcut", t)
	_make_biomes(res, p, home)
	t = _lap(res, "shape.biomes", t)
	_make_water(res, p, home, zc)
	t = _lap(res, "shape.water", t)
	_prune_unwalkable(res, p)
	t = _lap(res, "shape.prune", t)
	_assign_areas(res, boss_cells(p))


## Length scale for a map smaller than the 512 x 512 island: the water numbers are meant for 512 and shrink with the map.
static func _world_scale(p: Params) -> float:
	return minf(1.0, minf(p.cols, p.rows) / 512.0)


## The land mass (0038 step 3): "continentalness" = noise (domain-warped like the climate) mixed with one big round blob, faded to
## ocean towards the map edge, plus a ridge along the home -> boss line so the island always reaches both. Sea level is the quantile that
## gives `land_share` of land. Bays and peninsulas come from the noise; home and the zone stay land.
static func _make_continent(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var ws := _world_scale(p)
	var amp := p.climate_warp_amp
	var wnx := _climate_noise(res.seed + SEED_CLIMATE + 3, p.climate_warp_period, p.climate_warp_octaves)
	var wny := _climate_noise(res.seed + SEED_CLIMATE + 4, p.climate_warp_period, p.climate_warp_octaves)
	var cn := _climate_noise(res.seed + SEED_WATER, p.cont_period * ws, p.cont_octaves)
	var warp_x := PackedFloat32Array()
	var warp_y := PackedFloat32Array()
	warp_x.resize(n)
	warp_y.resize(n)
	var vals := PackedFloat32Array()
	vals.resize(n)
	var edge_cells := maxf(p.cont_edge_cells * ws, 1.0)
	var a := Vector2(home) + Vector2(0.5, 0.5)
	var seg := Vector2(zc.get_center()) - a
	var seg_len2 := maxf(seg.length_squared(), 1.0)
	var neck := maxf(p.neck_cells * ws, 1.0)
	var hx := cols * 0.5
	var hy := rows * 0.5
	for y in rows:
		var ey := mini(y, rows - 1 - y)
		for x in cols:
			var i := y * cols + x
			var wx := wnx.get_noise_2d(x + 0.5, y + 0.5) * amp
			var wy := wny.get_noise_2d(x + 0.5, y + 0.5) * amp
			warp_x[i] = wx
			warp_y[i] = wy
			var e := mini(ey, mini(x, cols - 1 - x))
			var sx := x + 0.5 + wx
			var sy := y + 0.5 + wy
			var v := 0.0
			if e >= 1:
				var b := clampf(0.5 + cn.get_noise_2d(sx, sy) * p.cont_gain, 0.0, 1.0)
				var r := Vector2((x + 0.5 - hx) / hx, (y + 0.5 - hy) / hy).length()
				v = (1.0 - p.cont_radial) * b + p.cont_radial * clampf(1.0 - pow(r, 1.8), 0.0, 1.0)
				if e < edge_cells:
					v *= pow(e / edge_cells, 0.7)
			var q := Vector2(sx, sy) - a
			var d := (q - seg * clampf(q.dot(seg) / seg_len2, 0.0, 1.0)).length()
			vals[i] = v + p.neck_boost * (1.0 - smoothstep(0.0, neck, d))
	res.warp_x = warp_x
	res.warp_y = warp_y
	var sorted := vals.duplicate()
	sorted.sort()
	var sea: float = sorted[clampi(int(n * (1.0 - p.land_share)), 0, n - 1)]
	var land := res.land
	var hr2 := p.home_clear_cells * p.home_clear_cells
	var rim := p.coast_cells
	for y in rows:
		var dy2 := (y - home.y) * (y - home.y)
		var zone_y := y >= zc.position.y and y < zc.end.y
		for x in cols:
			var i := y * cols + x
			var forced := (x - home.x) * (x - home.x) + dy2 <= hr2 or (zone_y and x >= zc.position.x and x < zc.end.x)
			# the home disc and the zone stay land even inside the coast rim (else home in the rim = no island)
			if forced or (vals[i] > sea and x >= rim and y >= rim and x < cols - rim and y < rows - rim):
				land[i] = 1
	res.land = land


static func _drop_cut_off(res: Result, p: Params, home: Vector2i, known := PackedByteArray()) -> PackedInt32Array:
	var keep := known if not known.is_empty() else _flood_land(res, p, home)   # `known`: the flood the caller already made of this very land
	var dropped := PackedInt32Array()
	for i in res.land.size():
		if res.land[i] == 1 and keep[i] == 0:
			res.land[i] = 0      # islands cut off from home: drop them
			dropped.append(i)
	return dropped


## Ground a walker cannot reach from home (a 1-cell neck behind a lobe, a shallow nook) must not exist: drop the cell under every walk-grid
## sample that floor_reachable would call cut off, from the land or the shallow water. Repeats until none is left (each pass only removes
## walkable cells, so it ends). Done once per generate, after the water, on `walk_land`; leaves the final walk grid in walk_base.
static func _prune_unwalkable(res: Result, p: Params) -> void:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	var walk := res.walk_land
	var cnt := PackedInt32Array([0])
	var free := _walk_free(p, walk, cnt)
	var free_n := cnt[0]
	var home_i := cell_index(p, Vector2i(p.player_spawn / p.cell))
	var cell_seen := PackedByteArray()
	var stack := PackedInt32Array()
	while true:
		if free[start.y * nx + start.x] == 0:
			break
		var dropped := PackedInt32Array()
		var seen := _walk_flood(free, nx, ny, start, cnt)
		if cnt[0] != free_n:   # a walker can stand somewhere it cannot reach: drop the cell under it
			for i in free.size():
				if free[i] == 1 and seen[i] == 0:
					var c := Vector2i(Vector2((i % nx + 0.5) * FLOW_STEP, (i / nx + 0.5) * FLOW_STEP) / p.cell)
					dropped.append(c.y * p.cols + c.x)
		else:   # and walkable cells (4-neighbour) that home cannot reach, e.g. two cells that only touch at a corner
			cell_seen.clear()
			cell_seen.resize(walk.size())
			_span_fill(walk, cell_seen, p.cols, p.rows, home_i, 1, PackedInt32Array(), stack)
			for i in walk.size():
				if walk[i] == 1 and cell_seen[i] == 0:
					dropped.append(i)
		if dropped.is_empty():   # everything is reached: this grid is the final one
			break
		for ci in dropped:
			walk[ci] = 0
			res.land[ci] = 0
			if not res.shallow.is_empty():
				res.shallow[ci] = 0
				res.fresh[ci] = 0
		free_n += _walk_free_patch(p, walk, free, dropped)
	res.walk_land = walk
	res.walk_base = free
	res.walk_base_n = free_n


## Morphological opening (erode then dilate, 4-neighbour): removes land strips 1 cell wide. A walker
## cannot stand on them, and they would make "all land is walkable" false. Home disc and zone stay.
static func _open_land(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var land := res.land
	var opened := PackedByteArray()
	opened.resize(cols * rows)
	for y in range(1, rows - 1):   # a core cell has all four neighbours on the grid; opening marks it and them
		for i in range(y * cols + 1, y * cols + cols - 1):
			if land[i] == 1 and land[i - 1] == 1 and land[i + 1] == 1 and land[i - cols] == 1 and land[i + cols] == 1:
				opened[i] = 1
				opened[i - 1] = 1
				opened[i + 1] = 1
				opened[i - cols] = 1
				opened[i + cols] = 1
	# home disc and zone keep their land
	var r := p.home_clear_cells
	for y in range(maxi(home.y - r, 0), mini(home.y + r + 1, rows)):
		for x in range(maxi(home.x - r, 0), mini(home.x + r + 1, cols)):
			if (x - home.x) * (x - home.x) + (y - home.y) * (y - home.y) <= r * r:
				opened[y * cols + x] = land[y * cols + x]
	for y in range(maxi(zc.position.y, 0), mini(zc.end.y, rows)):
		for x in range(maxi(zc.position.x, 0), mini(zc.end.x, cols)):
			opened[y * cols + x] = land[y * cols + x]
	res.land = opened


## Land cells reachable from `from` (4-neighbour) as a mask over the grid (1 = reached). All zero if `from` is not land.
static func _flood_land(res: Result, p: Params, from: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(p.cols * p.rows)
	if is_land(res, p, from):
		_span_fill(res.land, seen, p.cols, p.rows, from.y * p.cols + from.x)
	return seen


## A straight land bridge, (2 * max(corridor_half, 1) + 1) cells wide. Never touches the coast_cells rim.
static func _carve(res: Result, p: Params, a: Vector2i, b: Vector2i) -> void:
	var half := maxi(p.corridor_half, 1)   # 0 would be an 8-connected line: the 4-neighbour flood cuts it
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for s in steps + 1:
		var c := Vector2i(Vector2(a).lerp(Vector2(b), float(s) / maxf(steps, 1)).round())
		for dy in range(-half, half + 1):
			for dx in range(-half, half + 1):
				var q := c + Vector2i(dx, dy)
				if q.x >= p.coast_cells and q.y >= p.coast_cells and q.x < p.cols - p.coast_cells and q.y < p.rows - p.coast_cells:
					res.land[q.y * p.cols + q.x] = 1
					res.bridge[q] = true


## Boss land (the fight zone grown by boss_land_cells) is BOSS; every other land cell is FOREST (its look comes from its biome).
static func _assign_areas(res: Result, zc: Rect2i) -> void:
	var cols := res.cols
	for i in res.land.size():
		if res.land[i] == 0:
			continue
		res.area[i] = Area.BOSS if zc.has_point(Vector2i(i % cols, i / cols)) else Area.FOREST


# ------------------------------------------------------------------ patches ---

static func _place_patches(res: Result, p: Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var lo := maxi(p.patch_min_size, PATCH_MIN)
	var hi := maxi(p.patch_max_size, lo)
	for _attempt in p.patch_count * 40:
		if res.patches.size() >= p.patch_count:
			break
		var w := rng.randi_range(lo, hi)
		var h := rng.randi_range(lo, hi)
		# x0 >= 1 and x1 <= cols-2: the ring around the hole stays on the grid.
		if p.cols - 1 - w < 1 or p.rows - 1 - h < 1:
			continue
		var r := Rect2i(rng.randi_range(1, p.cols - 1 - w), rng.randi_range(1, p.rows - 1 - h), w, h)
		if _n01(noise, r.position.x + w * 0.5, r.position.y + h * 0.5) < p.patch_noise_threshold:
			continue
		if not _all_forest_land(res, p, r.grow(1)):
			continue
		var clear := true
		for other in res.patches:
			if r.grow(MIN_GAP).intersects(other):
				clear = false
				break
		if clear:
			res.patches.append(r)


static func _all_forest_land(res: Result, p: Params, r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := cell_index(p, Vector2i(x, y))
			if i < 0 or res.land[i] == 0 or res.area[i] != Area.FOREST:
				return false
	return true


## Fills res.kind, res.grass and res.dirt (and res.water).
static func _assign_ground(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	res.kind.resize(p.cols * p.rows)
	res.kind.fill(FILL)
	for i in res.land.size():
		if res.land[i] == 0:
			res.kind[i] = WATER
	var special: Dictionary = {}   # cell -> atlas coord, or null for "no grass tile"
	for r in res.patches:
		var v := rng.randi() % style.variant_count()
		var x0 := r.position.x
		var y0 := r.position.y
		var x1 := r.end.x - 1
		var y1 := r.end.y - 1
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				special[Vector2i(x, y)] = null
				res.kind[y * p.cols + x] = HOLE
		special[Vector2i(x0, y0)] = style.edge("nw", v)
		special[Vector2i(x1, y0)] = style.edge("ne", v)
		special[Vector2i(x0, y1)] = style.edge("sw", v)
		special[Vector2i(x1, y1)] = style.edge("se", v)
		for x in range(x0, x1 + 1):
			var col := "l" if x == x0 else ("r" if x == x1 else "m")
			_ring(res, p, special, Vector2i(x, y0 - 1), style.edge("n_" + col, v))
			_ring(res, p, special, Vector2i(x, y1 + 1), style.edge("s_" + col, v))
		for y in range(y0, y1 + 1):
			var row := "t" if y == y0 else ("b" if y == y1 else "m")
			_ring(res, p, special, Vector2i(x0 - 1, y), style.edge("w_" + row, v))
			_ring(res, p, special, Vector2i(x1 + 1, y), style.edge("e_" + row, v))

	# Dark grass follows smooth noise (a dark meadow, not salt and pepper): the darkest
	# `dark_grass_chance` share of the full-grass cells.
	var dark_noise := _noise(res.seed + 1, p.noise_frequency * 1.5)
	var fills: Array[Vector2i] = []
	for y in p.rows:
		for x in p.cols:
			if not special.has(Vector2i(x, y)) and res.kind[y * p.cols + x] == FILL and res.area[y * p.cols + x] == Area.FOREST:
				fills.append(Vector2i(x, y))
	var values: Array[float] = []
	for c in fills:
		values.append(_n01(dark_noise, c.x, c.y))
	var sorted := values.duplicate()
	sorted.sort()
	var cut := 2.0
	if p.dark_grass_chance > 0.0 and not sorted.is_empty():
		cut = sorted[clampi(int((1.0 - p.dark_grass_chance) * sorted.size()), 0, sorted.size() - 1)]

	for i in fills.size():
		var pool: Array[Vector2i] = style.grass_fills
		if values[i] >= cut and not style.grass_dark_fills.is_empty():
			pool = style.grass_dark_fills
		res.grass[fills[i]] = pool[rng.randi() % pool.size()]
	for cell in special:
		if special[cell] != null:
			res.grass[cell] = special[cell]
	for y in p.rows:
		for x in p.cols:
			var i := y * p.cols + x
			if res.land[i] == 0:
				if not style.water_fills.is_empty():
					res.water[Vector2i(x, y)] = style.water_fills[rng.randi() % style.water_fills.size()]
				continue
			var pool: Array[Vector2i] = style.dirt_fills
			if res.area[i] == Area.ROCKY and not style.rocky_fills.is_empty():
				pool = style.rocky_fills
			elif res.area[i] == Area.BOSS and not style.boss_fills.is_empty():
				pool = style.boss_fills
			res.dirt[Vector2i(x, y)] = pool[rng.randi() % pool.size()]


static func _ring(res: Result, p: Params, special: Dictionary, c: Vector2i, coord: Vector2i) -> void:
	special[c] = coord
	res.kind[c.y * p.cols + c.x] = RING


# ---------------------------------------------------------------- obstacles ---

static func _place_obstacles(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var set := style.obstacles
	if set == null or set.regions.is_empty() or set.radii.size() < set.regions.size():
		return
	var size := p.size_px()
	var spacing := maxf(p.obstacle_min_spacing, rock_clearance(p))
	var pad := p.cell + rock_clearance(p)
	res.obstacle_bucket = 2.0 * float(Array(set.radii).max()) + spacing
	for _attempt in p.obstacle_count * 60:
		if res.obstacles.size() >= p.obstacle_count:
			break
		var idx := rng.randi() % set.regions.size()
		var r := set.radii[idx]
		var pos := Vector2(
			rng.randf_range(pad + r, size.x - pad - r),
			rng.randf_range(pad + r, size.y - pad - r))
		var sprite := set.regions[idx].size * float(style.pixel_scale)
		if not _obstacle_legal(res, p, pos, r, sprite, spacing):
			continue
		_add_obstacle(res, {"region": idx, "pos": pos, "radius": r, "node": -1})


# ------------------------------------------------------------------- biomes ---

## Climate -> biome per land cell (decision 0038; port of tools/asset_viewer/world_preview.py). Temperature, humidity and roughness are
## domain-warped noise, stretched to an even 0..1 over the land, pulled to a mild climate around home; each cell then takes the nearest
## point of the biomes (BiomeData). The map is smoothed, small patches absorbed, warm / cold clashes repaired, and land close to water becomes beach.
## Own seeds (SEED_CLIMATE + n): draws nothing from the main stream.
static func _make_biomes(res: Result, p: Params, home: Vector2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	res.biome.resize(n)
	res.biome.fill(Biome.PLAINS)
	res.f.resize(n)
	res.f.fill(0.0)
	var t := Time.get_ticks_usec()
	var warp_x := res.warp_x   # the domain warp, made once for the continent (_make_continent): the climate bends the same way
	var warp_y := res.warp_y
	var noises: Array[FastNoiseLite] = [
		_climate_noise(res.seed + SEED_CLIMATE, p.climate_temp_period, p.climate_octaves),
		_climate_noise(res.seed + SEED_CLIMATE + 1, p.climate_humid_period, p.climate_octaves),
		_climate_noise(res.seed + SEED_CLIMATE + 2, p.climate_rough_period, p.climate_octaves)]
	var raw: Array[PackedFloat32Array] = []
	for _k in 3:
		var a := PackedFloat32Array()
		a.resize(n)
		raw.append(a)
	for y in rows:
		for x in cols:
			var i := y * cols + x
			if res.land[i] == 0:
				continue
			var sx := x + 0.5 + warp_x[i]
			var sy := y + 0.5 + warp_y[i]
			for k in 3:
				raw[k][i] = noises[k].get_noise_2d(sx, sy)
	t = _lap(res, "bio.noise", t)
	var temp := _rank01(raw[0], res.land)
	var humid := _rank01(raw[1], res.land)
	var rough := _rank01(raw[2], res.land)
	t = _lap(res, "bio.rank", t)
	var calm := [p.calm_temp, p.calm_humid, p.calm_rough]
	var calm_far := p.home_calm_cells + maxf(p.home_calm_fade, 0.01) + 1.0
	for i in n:   # home calm: smooth, so no border is created
		if res.land[i] == 1:
			var cdx := i % cols - home.x
			var cdy := i / cols - home.y
			if cdx * cdx + cdy * cdy > calm_far * calm_far:
				continue   # far from home: the pull is exactly 0
			var w := 1.0 - smoothstep(p.home_calm_cells, p.home_calm_cells + maxf(p.home_calm_fade, 0.01), Vector2(i % cols + 0.5, i / cols + 0.5).distance_to(Vector2(home) + Vector2(0.5, 0.5)))
			temp[i] = lerpf(temp[i], calm[0], w)
			humid[i] = lerpf(humid[i], calm[1], w)
			rough[i] = lerpf(rough[i], calm[2], w)
	t = _lap(res, "bio.calm", t)
	res.temp = temp
	res.humid = humid
	res.rough = rough
	# nearest point of the table; f = how much nearer a tree-biome point is than a Plains point (0.5 = equally near, 0 / 1 = `forest_margin` or more apart)
	var rows_n := 0
	var tt := PackedFloat32Array()   # the table flat, one array per axis: array-of-arrays reads are slow in the per-cell loop
	var th := PackedFloat32Array()
	var tr := PackedFloat32Array()
	var tb_biome := PackedInt32Array()
	var tb_mode := PackedInt32Array()   # BiomeData.forest_role of the point's biome: 1 = open (Plains) point, 2 = wooded point, 0 = other
	for bi in res.biomes.size():
		for pt in res.biomes[bi].points():
			tt.append(pt.x)
			th.append(pt.y)
			tr.append(pt.z)
			tb_biome.append(bi)
			tb_mode.append(res.biomes[bi].forest_role)   # BiomeData.Role: 1 OPEN (Plains), 2 WOODED
			rows_n += 1
	var w_t := p.climate_w_temp
	var w_h := p.climate_w_humid
	var w_r := p.climate_w_rough
	var margin := maxf(p.forest_margin, 0.0001)
	var biome := res.biome
	var fmap := res.f
	var land := res.land
	for i in n:
		if land[i] == 0:
			continue
		var ti: float = temp[i]
		var hi: float = humid[i]
		var ri: float = rough[i]
		var best := INF
		var d_plains := INF
		var d_trees := INF
		var best_k := 0
		for k in rows_n:
			var dt: float = (ti - tt[k]) * w_t
			var dh: float = (hi - th[k]) * w_h
			var dr: float = (ri - tr[k]) * w_r
			var dd := dt * dt + dh * dh + dr * dr
			if dd < best:
				best = dd
				best_k = k
			var m := tb_mode[k]
			if m == 1:
				if dd < d_plains:
					d_plains = dd
			elif m == 2:
				if dd < d_trees:
					d_trees = dd
		biome[i] = tb_biome[best_k]
		fmap[i] = clampf(0.5 + 0.5 * (sqrt(d_plains) - sqrt(d_trees)) / margin, 0.0, 1.0)
	res.biome = biome
	res.f = fmap
	t = _lap(res, "bio.nearest", t)
	_biome_majority(res, cols, rows, p.biome_smooth_passes, p.biome_smooth_half)
	t = _lap(res, "bio.majority", t)
	_biome_absorb_small(res, cols, rows, p.biome_min_blob)
	t = _lap(res, "bio.absorb", t)
	_biome_repair_clashes(res, cols, rows)
	t = _lap(res, "bio.clashes", t)
	# beach: land within a ragged band of the water; sand when warm, gravel when cold
	var cap := int(ceilf(maxf(p.beach_min, p.beach_max)))
	var dist := _water_dist(res, p, cap)
	res.coast_dist = dist   # kept for the shallows (_make_water)
	t = _lap(res, "bio.waterdist", t)
	var edge := _climate_noise(res.seed + SEED_CLIMATE + 5, p.beach_noise_period, p.beach_noise_octaves)
	for i in n:
		if res.land[i] == 1 and dist[i] <= cap:
			var width := lerpf(p.beach_min, p.beach_max, _n01(edge, i % cols, i / cols))
			if dist[i] <= width:
				res.biome[i] = Biome.BEACH_SAND if temp[i] >= p.cold_beach_t else Biome.BEACH_GRAVEL


## Water (0038 step 3; port of tools/asset_viewer/world_preview.py). Cut out of the land mass the continent and the biomes made:
##  - rivers: the zero line of a ridge noise (|n| < width), only inland, wider towards the sea; a piece that does not reach the sea is dropped.
##  - lakes: pockets of a separate noise on wet, inland, not-too-rough land.
##  - shallows: the first 1-2 ocean cells along the coast. Rivers, lakes and shallows are SHALLOW water: not land (nothing is placed there)
##    but walkable. The ocean beyond is OCEAN: deep, it blocks walking.
##  - shore: the 1-2 land cells around a river / lake (res.shore; the ground pass gives them BiomeData.shore_ground).
##  - BiomeData.fresh_pull_cells: a biome (swamp) takes wet lowland near fresh water.
## `res.land` ends up as DRY land only; `res.walk_land` = dry + shallow, what walking and the walk grid use.
static func _make_water(res: Result, p: Params, home: Vector2i, zc: Rect2i) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var ws := _world_scale(p)
	var shallow := PackedByteArray()
	var fresh := PackedByteArray()
	var shore := PackedByteArray()
	shallow.resize(n)
	fresh.resize(n)
	shore.resize(n)
	res.shallow = shallow
	res.fresh = fresh
	res.shore = shore
	var wx := res.warp_x
	var wy := res.warp_y
	var t := Time.get_ticks_usec()
	var wet := PackedInt32Array()   # every shallow cell
	var fresh_cells := PackedInt32Array()
	if p.water_on:
		# distance to the sea on a grid 4 times coarser (chamfer, in coarse cells): the river width and the lake inland rule only need it roughly
		var cw := (cols + 3) / 4
		var ch := (rows + 3) / 4
		var dc := PackedFloat32Array()
		dc.resize(cw * ch)
		for cy in ch:
			for cx in cw:
				dc[cy * cw + cx] = 1.0e6 if land[mini(cy * 4 + 2, rows - 1) * cols + mini(cx * 4 + 2, cols - 1)] == 1 else 0.0
		for cy in ch:
			for cx in cw:
				var k := cy * cw + cx
				var d := dc[k]
				if d == 0.0:
					continue
				if cx > 0:
					d = minf(d, dc[k - 1] + 1.0)
				if cy > 0:
					d = minf(d, dc[k - cw] + 1.0)
					if cx > 0:
						d = minf(d, dc[k - cw - 1] + 1.414)
					if cx < cw - 1:
						d = minf(d, dc[k - cw + 1] + 1.414)
				dc[k] = d
		for cy in range(ch - 1, -1, -1):
			for cx in range(cw - 1, -1, -1):
				var k := cy * cw + cx
				var d := dc[k]
				if d == 0.0:
					continue
				if cx < cw - 1:
					d = minf(d, dc[k + 1] + 1.0)
				if cy < ch - 1:
					d = minf(d, dc[k + cw] + 1.0)
					if cx < cw - 1:
						d = minf(d, dc[k + cw + 1] + 1.414)
					if cx > 0:
						d = minf(d, dc[k + cw - 1] + 1.414)
				dc[k] = d
		t = _lap(res, "water.seadist", t)
		# --- rivers
		var rn := _climate_noise(res.seed + SEED_WATER + 1, p.river_period * ws, p.river_octaves)
		var nr := PackedFloat32Array()
		nr.resize(n)
		for y in rows:
			for x in cols:
				var i := y * cols + x
				nr[i] = rn.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i])
		t = _lap(res, "water.ridge", t)
		var rough := res.rough
		var humid := res.humid
		var hp2 := (p.home_clear_cells + 3) * (p.home_clear_cells + 3)
		var grow := maxf(p.river_grow_dist * ws, 1.0)
		var rscale := maxf(ws, 0.4)   # river widths shrink on a small map too, but not below 0.4 x
		var river := PackedByteArray()
		river.resize(n)
		var rdist := PackedFloat32Array()   # |n| / |grad n| = the distance to the zero line in cells; 1e9 = not a candidate cell
		rdist.resize(n)
		rdist.fill(1.0e9)
		var rcells := PackedInt32Array()
		for y in range(1, rows - 1):
			var dy2 := (y - home.y) * (y - home.y)
			var zone_y := y >= zc.position.y and y < zc.end.y
			for x in range(1, cols - 1):
				var i := y * cols + x
				if land[i] == 0:
					continue
				var a := absf(nr[i])
				if a > 0.25 or rough[i] >= p.river_rough_max:
					continue
				if (x - home.x) * (x - home.x) + dy2 <= hp2 or (zone_y and x >= zc.position.x and x < zc.end.x):
					continue   # home and the fight zone stay dry
				var gx := (nr[i + 1] - nr[i - 1]) * 0.5
				var gy := (nr[i + cols] - nr[i - cols]) * 0.5
				var dd := a / maxf(sqrt(gx * gx + gy * gy), 1.0e-6)
				rdist[i] = dd
				var w := lerpf(p.river_w_inland, p.river_w_sea, clampf(1.0 - dc[(y >> 2) * cw + (x >> 2)] * 4.0 / grow, 0.0, 1.0)) * rscale
				if dd < w:
					river[i] = 1
					rcells.append(i)
		var rseen := PackedByteArray()
		rseen.resize(n)
		var stack := PackedInt32Array()
		var spans := PackedInt32Array()
		var pieces: Array[PackedInt32Array] = []   # the kept river pieces
		for i in rcells:
			if rseen[i] == 1:
				continue
			spans.clear()
			if _span_fill(river, rseen, cols, rows, i, 1, spans, stack) < p.river_min_cells:
				continue
			var reaches_sea := false
			var inland_max := 0.0   # how far from the sea the piece gets: a river that only runs along the coast is a ditch, not a river
			for k in range(0, spans.size(), 2):
				for c in range(spans[k], spans[k] + spans[k + 1]):
					if land[c - 1] == 0 or land[c + 1] == 0 or land[c - cols] == 0 or land[c + cols] == 0:
						reaches_sea = true
					inland_max = maxf(inland_max, dc[(c / cols >> 2) * cw + (c % cols >> 2)])
			if reaches_sea and inland_max * 4.0 >= p.river_inland_min * ws:
				var cells := PackedInt32Array()
				for k2 in range(0, spans.size(), 2):
					for c in range(spans[k2], spans[k2] + spans[k2 + 1]):
						fresh[c] = 1
						fresh_cells.append(c)
						cells.append(c)
				pieces.append(cells)
		# the longest rivers (most cells) are widened: cells within `river_big_reach` of the thin river that are closer than the big half width to its zero line
		var order: Array = range(pieces.size())
		order.sort_custom(func(a: int, b: int) -> bool: return pieces[a].size() > pieces[b].size() or (pieces[a].size() == pieces[b].size() and a < b))
		var offs4 := PackedInt32Array([-cols, cols, -1, 1])
		for bk in mini(p.river_big_n, order.size()):
			var front: PackedInt32Array = pieces[order[bk]].duplicate()
			for step in p.river_big_reach:   # grow outwards from the thin river, only through cells inside the big half width (no loose specks)
				var nxt := PackedInt32Array()
				for c in front:
					for o in offs4:
						var j: int = c + o
						if j < 0 or j >= n or land[j] == 0 or fresh[j] != 0 or rdist[j] >= 1.0e8:
							continue
						var gr := clampf(1.0 - dc[(j / cols >> 2) * cw + (j % cols >> 2)] * 4.0 / grow, 0.0, 1.0)
						if rdist[j] < lerpf(p.river_big_w_inland, p.river_big_w_sea, gr) * rscale:
							fresh[j] = 1
							fresh_cells.append(j)
							nxt.append(j)
				front = nxt
		t = _lap(res, "water.rivers", t)
		_make_lakes(res, p, home, zc, dc, cw, fresh, fresh_cells)
		t = _lap(res, "water.lakes", t)
		# --- cut the fresh water out of the land; the land around it is the shore
		for i in fresh_cells:
			land[i] = 0
			shallow[i] = 1
		wet.append_array(fresh_cells)
		var offs8 := PackedInt32Array([-cols - 1, -cols, -cols + 1, -1, 1, cols - 1, cols, cols + 1])
		var ring1 := PackedInt32Array()
		for i in fresh_cells:
			for o in offs8:
				var j := i + o
				if land[j] == 1 and shore[j] == 0:
					shore[j] = 1
					ring1.append(j)
		if p.shore_cells > 1.0:   # a ragged second ring: `shore_cells` 1.5 = half of its cells
			for j in ring1:
				for o in [-cols, cols, -1, 1]:
					var k: int = j + o
					if k >= 0 and k < n and land[k] == 1 and shore[k] == 0 and float(_hash_int(k % cols, k / cols, res.seed + 7) % 100) < (p.shore_cells - 1.0) * 100.0:
						shore[k] = 1
		# --- swamp (any biome with BiomeData.fresh_pull_cells): wet lowland near fresh water, on a 2x coarser distance
		var pulls: Array[int] = []
		var pull_max := 0.0
		for bi in res.biomes.size():
			if res.biomes[bi].fresh_pull_cells > 0.0:
				pulls.append(bi)
				pull_max = maxf(pull_max, res.biomes[bi].fresh_pull_cells)
		if not pulls.is_empty() and not fresh_cells.is_empty():
			var cap2 := int(ceilf(pull_max / 2.0)) + 3
			var w2 := (cols + 1) / 2
			var h2 := (rows + 1) / 2
			var d2 := PackedByteArray()
			d2.resize(w2 * h2)
			d2.fill(255)
			var front := PackedInt32Array()
			for i in fresh_cells:
				var k := (i / cols / 2) * w2 + (i % cols) / 2
				if d2[k] != 0:
					d2[k] = 0
					front.append(k)
			var offs2 := PackedInt32Array([-w2 - 1, -w2, -w2 + 1, -1, 1, w2 - 1, w2, w2 + 1])
			for step in cap2:
				var nxt := PackedInt32Array()
				for k in front:
					var kx := k % w2
					var ky := k / w2
					if kx < 1 or ky < 1 or kx >= w2 - 1 or ky >= h2 - 1:
						continue
					for o in offs2:
						if d2[k + o] > step + 1:
							d2[k + o] = step + 1
							nxt.append(k + o)
				front = nxt
			var wob := _climate_noise(res.seed + SEED_WATER + 3, 12.0, 2)
			var temp := res.temp
			for i in n:
				if land[i] == 0:
					continue
				var dd := d2[((i / cols) / 2) * w2 + (i % cols) / 2]
				if dd > cap2 or res.biome[i] >= Biome.BEACH_SAND:
					continue
				var near_cells := dd * 2.0 + (_n01(wob, i % cols, i / cols) - 0.5) * 6.0
				for bi in pulls:
					var bd := res.biomes[bi]
					if near_cells < bd.fresh_pull_cells and humid[i] > bd.fresh_humid_min and rough[i] < bd.fresh_rough_max and temp[i] > bd.fresh_temp_min and temp[i] < bd.fresh_temp_max:
						res.biome[i] = bi
						break
		t = _lap(res, "water.shore+swamp", t)
		# --- shallows along the ocean coast: ocean cells within 1-2 cells of the land (ragged)
		var ring := PackedByteArray()
		ring.resize(n)
		var frontier := PackedInt32Array()
		var cd := res.coast_dist
		var at := cd.find(1)
		while at >= 0:
			for o in offs8:
				var j := at + o
				if j >= 0 and j < n and land[j] == 0 and ring[j] == 0 and shallow[j] == 0:
					ring[j] = 1
					frontier.append(j)
			at = cd.find(1, at + 1)
		var second := PackedInt32Array()
		for i in frontier:
			for o in offs8:
				var j := i + o
				if j >= 0 and j < n and land[j] == 0 and ring[j] == 0 and shallow[j] == 0:
					ring[j] = 2
					second.append(j)
		var sn := _climate_noise(res.seed + SEED_WATER + 4, 20.0, 2)
		for lst in [frontier, second]:
			for i in lst:
				if float(ring[i]) <= lerpf(p.shallow_min, p.shallow_max, _n01(sn, i % cols, i / cols)):
					shallow[i] = 1
					wet.append(i)
		t = _lap(res, "water.shallows", t)
	res.land = land
	var walk := land.duplicate()
	for i in wet:
		walk[i] = 1
	res.walk_land = walk
	res.warp_x = PackedFloat32Array()
	res.warp_y = PackedFloat32Array()
	res.coast_dist = PackedByteArray()


## Lakes (0038 water v2; port of tools/asset_viewer/world_preview.py): `lake_big_n` landmark lakes (`lake_big_on_river` of them on a river path) and
## `lake_pond_n` small ponds that cluster where a wetness noise is high (or sit next to a river). A lake is one or a few merged blobs, each
## an ellipse whose edge is wobbled by noise. Lake cells become fresh = 2 (a lake over a river cell wins). Home and the fight zone stay dry.
## Radii and counts shrink on a map smaller than 512 x 512 (counts by the area), never below 0.4 x.
static func _make_lakes(res: Result, p: Params, home: Vector2i, zc: Rect2i, dc: PackedFloat32Array, cw: int, fresh: PackedByteArray, fresh_cells: PackedInt32Array) -> void:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var humid := res.humid
	var rough := res.rough
	var wx := res.warp_x
	var wy := res.warp_y
	var ws := _world_scale(p)
	var ls := maxf(ws, 0.4)
	var hp2 := (p.home_clear_cells + 3) * (p.home_clear_cells + 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = res.seed + SEED_WATER + 5
	var shape_n := _climate_noise(res.seed + SEED_WATER + 2, p.lake_shape_period * ls, 3)
	var wet_n := _climate_noise(res.seed + SEED_WATER + 6, p.lake_pond_wet_period * ws, 2)
	# wetness threshold = the `lake_pond_wet_min` quantile over a coarse sample of the land
	var samp := PackedFloat32Array()
	for y in range(0, rows, 4):
		for x in range(0, cols, 4):
			var i := y * cols + x
			if land[i] == 1:
				samp.append(wet_n.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i]))
	samp.sort()
	var wet_thr := -2.0 if samp.is_empty() else samp[clampi(int(samp.size() * p.lake_pond_wet_min), 0, samp.size() - 1)]
	var rpts := PackedInt32Array()   # river cells away from the sea: where "on a river" lakes are centred
	for c in fresh_cells:
		if dc[(c / cols >> 2) * cw + (c % cols >> 2)] * 4.0 > 14.0:
			rpts.append(c)
	var n_big := ceili(p.lake_big_n * ls * ls) if p.lake_big_n > 0 else 0
	var n_pond := ceili(p.lake_pond_n * ls * ls) if p.lake_pond_n > 0 else 0
	var placed: Array[Vector3] = []   # x, y, radius
	var lake := PackedByteArray()
	lake.resize(n)
	var lake_cells := PackedInt32Array()
	var inland := p.lake_inland_min * ws
	for k in n_big + n_pond:
		var big := k < n_big
		var rad := (rng.randf_range(p.lake_big_r_min, p.lake_big_r_max) if big else rng.randf_range(p.lake_pond_r_min, p.lake_pond_r_max)) * ls
		var on_river := (k < p.lake_big_on_river) if big else (rng.randf() < p.lake_pond_on_river)
		var cx := 0.0
		var cy := 0.0
		var found := false
		for _try in 120:
			if on_river and not rpts.is_empty():
				var c := rpts[rng.randi() % rpts.size()]
				var jit := 0.3 if big else 1.2
				cx = c % cols + rng.randf_range(-rad, rad) * jit
				cy = c / cols + rng.randf_range(-rad, rad) * jit
			else:
				cx = rng.randf_range(0.0, cols)
				cy = rng.randf_range(0.0, rows)
			var ix := clampi(int(cx), 1, cols - 2)
			var iy := clampi(int(cy), 1, rows - 2)
			var ci := iy * cols + ix
			if land[ci] == 0 or humid[ci] <= p.lake_humid_min or rough[ci] >= p.lake_rough_max:
				continue
			if dc[(iy >> 2) * cw + (ix >> 2)] * 4.0 < rad * 1.4 + inland:
				continue
			if not big and not on_river and wet_n.get_noise_2d(ix + 0.5 + wx[ci], iy + 0.5 + wy[ci]) <= wet_thr:
				continue   # a free pond only where it is wet: ponds cluster
			var gap := 1.0 if not big else float(p.lake_gap)
			var clash := false
			for q in placed:
				if Vector2(cx - q.x, cy - q.y).length() < rad + q.z + gap:
					clash = true
					break
			if not clash:
				found = true
				break
		if not found:
			continue
		var blobs: Array = []   # [x, y, radius, edge-wobble k, angle, stretch]
		if big:
			blobs.append([cx, cy, rad, 0.25, 0.0, 1.0])
		else:
			var ang := rng.randf_range(0.0, PI)
			var sgn := float((placed.size() % 2) * 2 - 1)
			for _b in rng.randi_range(p.lake_pond_blobs_min, maxi(p.lake_pond_blobs_min, p.lake_pond_blobs_max)):
				var off := rng.randf_range(0.6, 1.4) * rad
				var a2 := ang + rng.randf_range(-0.5, 0.5)
				blobs.append([cx + cos(a2) * off * sgn, cy + sin(a2) * off, rad * rng.randf_range(0.6, 1.0), 0.22, ang, rng.randf_range(p.lake_pond_stretch_min, p.lake_pond_stretch_max)])
		placed.append(Vector3(cx, cy, rad))
		for bl in blobs:
			var bx: float = bl[0]
			var by: float = bl[1]
			var br: float = bl[2]
			var ca := cos(float(bl[4]))
			var sa := sin(float(bl[4]))
			var stretch := maxf(float(bl[5]), 0.1)
			var wob: float = p.lake_warp * float(bl[3])
			for y in range(maxi(int(by - br * 3.0), 1), mini(int(by + br * 3.0) + 1, rows - 1)):
				var dy2 := (y - home.y) * (y - home.y)
				var zone_y := y >= zc.position.y and y < zc.end.y
				for x in range(maxi(int(bx - br * 3.0), 1), mini(int(bx + br * 3.0) + 1, cols - 1)):
					var i := y * cols + x
					if land[i] == 0 or lake[i] == 1 or dc[(y >> 2) * cw + (x >> 2)] * 4.0 <= 2.0:
						continue
					if (x - home.x) * (x - home.x) + dy2 <= hp2 or (zone_y and x >= zc.position.x and x < zc.end.x):
						continue
					var gx := x + 0.5 - bx
					var gy := y + 0.5 - by
					var u := (gx * ca + gy * sa) / stretch
					var v := -gx * sa + gy * ca
					if sqrt(u * u + v * v) / br + shape_n.get_noise_2d(x + 0.5 + wx[i], y + 0.5 + wy[i]) * wob < 1.0:
						lake[i] = 1
						lake_cells.append(i)
	var seen := PackedByteArray()
	seen.resize(n)
	var spans := PackedInt32Array()
	var stack := PackedInt32Array()
	for i in lake_cells:
		if seen[i] == 1:
			continue
		spans.clear()
		if _span_fill(lake, seen, cols, rows, i, 1, spans, stack) < p.lake_min_cells:
			continue
		for k2 in range(0, spans.size(), 2):
			for c in range(spans[k2], spans[k2] + spans[k2 + 1]):
				if fresh[c] == 0:
					fresh_cells.append(c)
				fresh[c] = 2


static func _climate_noise(noise_seed: int, period: float, octaves: int) -> FastNoiseLite:
	var nz := _noise(noise_seed, 1.0 / maxf(period, 1.0))
	nz.fractal_type = FastNoiseLite.FRACTAL_FBM
	nz.fractal_octaves = octaves
	return nz


## Values -> 0..1 evenly spread over the LAND cells (percentile; keeps the order, so the map stays smooth).
static func _rank01(vals: PackedFloat32Array, land: PackedByteArray) -> PackedFloat32Array:
	var sorted := PackedFloat32Array()
	for i in vals.size():
		if land[i] == 1:
			sorted.append(vals[i])
	sorted.sort()
	var out := PackedFloat32Array()
	out.resize(vals.size())
	var count := maxf(sorted.size(), 1.0)
	for i in vals.size():
		if land[i] == 1:
			out[i] = float(sorted.bsearch(vals[i])) / count
	return out


## Each land cell takes the commonest biome of the land cells around it (a window of 2 * half + 1), `passes` times. Ties keep the cell's own
## biome. Sliding histogram: one count per biome per column, moved along the row, so the cost does not grow with the window.
static func _biome_majority(res: Result, cols: int, rows: int, passes: int, half: int) -> void:
	# The whole histogram of a window in ONE int: `bits` per biome (enough for the biggest window count). Falls back to the
	# per-biome version when that does not fit in 63 bits (a bigger window or more biomes).
	var kinds := res.biomes.size()
	var bits := 1
	while (1 << bits) <= (2 * half + 1) * (2 * half + 1):
		bits += 1
	if kinds * bits > 62:
		_biome_majority_wide(res, cols, rows, passes, half)
		return
	var land := res.land
	var mask := (1 << bits) - 1
	var x0s := PackedInt32Array()   # per row: first and last land cell (-1 = none): water-only stretches are skipped
	var x1s := PackedInt32Array()
	x0s.resize(rows)
	x1s.resize(rows)
	for y in rows:
		var lo := -1
		var hi := -1
		for x in cols:
			if land[y * cols + x] == 1:
				if lo < 0:
					lo = x
				hi = x
		x0s[y] = lo
		x1s[y] = hi
	for _pass in passes:
		var src := res.biome.duplicate()
		var colw := PackedInt64Array()   # per column: the biome counts over the window's rows, one packed word
		colw.resize(cols)
		for yy in mini(half, rows):
			_majority_row_packed(land, src, colw, cols, yy, 1, x0s[yy], x1s[yy], bits)
		for y in rows:
			if y + half < rows:
				_majority_row_packed(land, src, colw, cols, y + half, 1, x0s[y + half], x1s[y + half], bits)
			if y - half - 1 >= 0:
				_majority_row_packed(land, src, colw, cols, y - half - 1, -1, x0s[y - half - 1], x1s[y - half - 1], bits)
			var xa := x0s[y]
			if xa < 0:
				continue
			var h := 0
			for xx in range(maxi(xa - half, 0), mini(xa + half, cols - 1) + 1):
				h += colw[xx]
			var row := y * cols
			for x in range(xa, x1s[y] + 1):
				if x > xa:
					if x + half < cols:
						h += colw[x + half]
					if x - half - 1 >= 0:
						h -= colw[x - half - 1]
				var i := row + x
				if land[i] == 0:
					continue
				var own := src[i]
				var sh := bits * own
				if (h & ~(mask << sh)) == 0:   # only its own biome around: nothing can change (the common case)
					continue
				var best := own
				var hb := (h >> sh) & mask
				for k in kinds:
					var v := (h >> (bits * k)) & mask
					if v > hb:
						best = k
						hb = v
				res.biome[i] = best


static func _majority_row_packed(land: PackedByteArray, src: PackedByteArray, colw: PackedInt64Array, cols: int, y: int, sign: int, x0: int, x1: int, bits: int) -> void:
	if x0 < 0:
		return
	for i in range(y * cols + x0, y * cols + x1 + 1):
		if land[i] == 1:
			colw[i - y * cols] += sign << (bits * src[i])


static func _biome_majority_wide(res: Result, cols: int, rows: int, passes: int, half: int) -> void:
	var kinds := res.biomes.size()
	var land := res.land
	var x0s := PackedInt32Array()   # per row: first and last land cell (-1 = none): water-only stretches are skipped
	var x1s := PackedInt32Array()
	x0s.resize(rows)
	x1s.resize(rows)
	for y in rows:
		var lo := -1
		var hi := -1
		for x in cols:
			if land[y * cols + x] == 1:
				if lo < 0:
					lo = x
				hi = x
		x0s[y] = lo
		x1s[y] = hi
	for _pass in passes:
		var src := res.biome.duplicate()
		var colc := PackedInt32Array()   # per column: biome counts over the window's rows
		colc.resize(cols * kinds)
		var hist := PackedInt32Array()
		hist.resize(kinds)
		for yy in mini(half, rows):
			_majority_row(land, src, colc, cols, kinds, yy, 1, x0s[yy], x1s[yy])
		for y in rows:
			if y + half < rows:
				_majority_row(land, src, colc, cols, kinds, y + half, 1, x0s[y + half], x1s[y + half])
			if y - half - 1 >= 0:
				_majority_row(land, src, colc, cols, kinds, y - half - 1, -1, x0s[y - half - 1], x1s[y - half - 1])
			var xa := x0s[y]
			if xa < 0:
				continue
			hist.fill(0)
			for xx in range(maxi(xa - half, 0), mini(xa + half, cols - 1) + 1):
				for k in kinds:
					hist[k] += colc[xx * kinds + k]
			var row := y * cols
			for x in range(xa, x1s[y] + 1):
				if x > xa:
					if x + half < cols:
						for k in kinds:
							hist[k] += colc[(x + half) * kinds + k]
					if x - half - 1 >= 0:
						for k in kinds:
							hist[k] -= colc[(x - half - 1) * kinds + k]
				var i := row + x
				if land[i] == 0:
					continue
				var best := src[i]
				for k in kinds:
					if hist[k] > hist[best]:
						best = k
				res.biome[i] = best


static func _majority_row(land: PackedByteArray, src: PackedByteArray, colc: PackedInt32Array, cols: int, kinds: int, y: int, sign: int, x0: int, x1: int) -> void:
	if x0 < 0:
		return
	for x in range(x0, x1 + 1):
		if land[y * cols + x] == 1:
			colc[x * kinds + src[y * cols + x]] += sign


## Biome patches (4-neighbour) smaller than `min_blob` cells take the nearest big biome. Not a patch that sits BETWEEN a warm and a cold
## biome (a 1-step buffer such as a thin taiga strip): that would let them touch. Two rounds.
static func _biome_absorb_small(res: Result, cols: int, rows: int, min_blob: int) -> void:
	var n := cols * rows
	var land := res.land
	var biome := res.biome
	var tc := _temp_classes(res)
	for _round in 2:
		var lb := biome.duplicate()   # biome per cell, 255 on water: one compare says "land of this biome"
		for i in n:
			if land[i] == 0:
				lb[i] = 255
		var seen := PackedByteArray()
		seen.resize(n)
		var small := PackedByteArray()
		small.resize(n)
		var any := false
		var spans := PackedInt32Array()   # the patch as runs: (first cell, length) pairs
		var stack := PackedInt32Array()   # shared flood stack
		for start in n:
			if lb[start] == 255 or seen[start] == 1:
				continue
			var kind := lb[start]
			spans.clear()
			var size := _span_fill(lb, seen, cols, rows, start, kind, spans, stack)
			if size >= min_blob:
				continue
			var lo := 9
			var hi := -9
			for k in range(0, spans.size(), 2):
				for i in range(spans[k], spans[k] + spans[k + 1]):
					var x := i - (i / cols) * cols
					for j in [i + 1 if x < cols - 1 else -1, i - 1 if x > 0 else -1, i + cols, i - cols]:
						if j < 0 or j >= n or lb[j] == 255 or lb[j] == kind:
							continue
						var t := tc[lb[j]]
						if t >= 0:
							lo = mini(lo, t)
							hi = maxi(hi, t)
			if hi - lo < 2:
				any = true
				for k in range(0, spans.size(), 2):
					for i in range(spans[k], spans[k] + spans[k + 1]):
						small[i] = 1
		if not any:
			break
		# grow the big biomes into the small cells, one ring at a time (nearest wins)
		var frontier := PackedInt32Array()   # land cells that touch a small patch, in cell order (the rest could not claim anything)
		for i in n:
			if land[i] == 1 and small[i] == 0:
				var x := i % cols
				if (x < cols - 1 and small[i + 1] == 1) or (x > 0 and small[i - 1] == 1) or (i + cols < n and small[i + cols] == 1) or (i >= cols and small[i - cols] == 1):
					frontier.append(i)
		while not frontier.is_empty():
			var next := PackedInt32Array()
			for i in frontier:
				var x := i % cols
				for dir in 4:
					var j := i + 1 if dir == 0 else (i - 1 if dir == 1 else (i + cols if dir == 2 else i - cols))
					if (dir == 0 and x == cols - 1) or (dir == 1 and x == 0) or j < 0 or j >= n:
						continue
					if small[j] == 1:
						small[j] = 0
						biome[j] = biome[i]
						next.append(j)
			frontier = next
	res.biome = biome


## BiomeData.temp_class per biome id, as an array (the per-cell loops must not touch Resources).
static func _temp_classes(res: Result) -> PackedInt32Array:
	var tc := PackedInt32Array()
	for b in res.biomes:
		tc.append(b.temp_class)
	return tc


## Last guard: two neighbours whose temperature classes differ by 2+ (snow | forest, taiga | autumn) -> the warmer cell becomes the
## biome in between (taiga / forest). Repeats until none is left (each step shrinks the gap, so it ends).
static func _biome_repair_clashes(res: Result, cols: int, rows: int) -> void:
	var n := cols * rows
	var land := res.land
	var biome := res.biome
	var tc := _temp_classes(res)
	for _guard in 12:
		var fixed := false
		for i in n:
			if land[i] == 0 or tc[biome[i]] < 0:
				continue
			for o in 2:   # right neighbour, then the one below
				var j := i + 1 if o == 0 else i + cols
				if (o == 0 and i % cols == cols - 1) or j >= n or land[j] == 0 or tc[biome[j]] < 0:
					continue
				var a := tc[biome[i]]
				var b := tc[biome[j]]
				if absi(a - b) >= 2:
					biome[i if a > b else j] = Biome.TAIGA if mini(a, b) == 0 else Biome.FOREST
					fixed = true
		if not fixed:
			break
	res.biome = biome


## Neighbouring land cells (4-neighbour) whose temperature classes differ by 2 or more. 0 = the cold / warm guarantee holds. Tests call it.
static func climate_clashes(res: Result) -> int:
	var bad := 0
	for i in res.land.size():
		if res.land[i] == 0 or res.biome.is_empty() or res.biomes[res.biome[i]].temp_class < 0:
			continue
		for o in [1, res.cols]:
			if (i % res.cols == res.cols - 1 and o == 1) or i + o >= res.land.size() or res.land[i + o] == 0 or res.biomes[res.biome[i + o]].temp_class < 0:
				continue
			bad += 1 if absi(res.biomes[res.biome[i]].temp_class - res.biomes[res.biome[i + o]].temp_class) >= 2 else 0
	return bad


static func _smooth(a: float, b: float, v: float) -> float:
	return clampf((v - a) / maxf(b - a, 0.0001), 0.0, 1.0)


## Vegetation scratch (0038 step 4): the dry non-boss land cells grouped by block (16 x 16) and biome, the cell occupancy and the clearing mask.
## Made once per generate (first caller wins); the passes draw their random spots from these lists, so "N tries per block" is spread over
## exactly the cells of that biome in the block (a block that is half Plains gets half the Plains tries).
static func make_veg_lists(res: Result, p: Params) -> void:
	if res.veg_nblocks > 0:
		return
	var bs := int(TREE_BLOCK)
	var cols := p.cols
	res.veg_bcols = (cols + bs - 1) / bs
	var brows := (p.rows + bs - 1) / bs
	res.veg_nblocks = res.veg_bcols * brows
	var nb := res.biomes.size()
	res.veg_blocks.clear()
	res.veg_by_biome.clear()
	for _k in nb * res.veg_nblocks:
		res.veg_blocks.append(PackedInt32Array())
	for _k in nb:
		res.veg_by_biome.append(PackedInt32Array())
	res.veg_all = PackedInt32Array()
	var land := res.land
	var areas := res.area
	var biome := res.biome
	for y in p.rows:
		var brow := (y / bs) * res.veg_bcols
		for x in cols:
			var i := y * cols + x
			if land[i] == 1 and areas[i] != Area.BOSS:
				var b: int = biome[i]
				res.veg_blocks[b * res.veg_nblocks + brow + x / bs].append(i)
				res.veg_by_biome[b].append(i)
				res.veg_all.append(i)
	res.veg_occ.resize(cols * p.rows)
	res.veg_occ.fill(0)
	res.veg_clear.resize(cols * p.rows)
	res.veg_clear.fill(0)


## The smooth noise behind the local density d (0..1 before BiomeData.dens_lo / dens_hi).
static func veg_noise(res_seed: int, p: Params) -> FastNoiseLite:
	return _noise(res_seed + SEED_VEG_NOISE, 1.0 / maxf(p.veg_density_period, 1.0))


## Local density d at a spot of biome `bd`: noise between its dens_lo..dens_hi; a wooded biome is capped by f (young, thin trees where it meets Plains).
static func veg_density(res: Result, bd: BiomeData, noise: FastNoiseLite, x: float, y: float, ci: int) -> float:
	var d := lerpf(bd.dens_lo, bd.dens_hi, _n01(noise, x, y))
	if bd.forest_role == BiomeData.Role.WOODED:
		d = minf(d, res.f[ci])
	return d


## Number of tries for an expected `v`: the whole part plus one more with the chance of the rest.
static func veg_count(rng: RandomNumberGenerator, v: float) -> int:
	return int(v) + (1 if rng.randf() < v - int(v) else 0)


## Aged tree nodes of the style: model * 100 + season * 10 + age index -> index into style.resource_nodes. Empty when the style has none.
static func _tree_kinds(style: MapStyle, pp := false) -> Dictionary:
	var out := {}
	var prefix := "treepp" if pp else "tree"   # Pixel Plains oaks have their own nodes (data/resource_nodes/treepp_*)
	for ki in style.resource_nodes.size():
		var parts := String((style.resource_nodes[ki] as ResourceNodeData).id).split("_")   # tree_oak_old / tree_oak_yellow_old
		if parts.size() < 3 or parts.size() > 4 or parts[0] != prefix:
			continue
		var model := BiomeData.MODELS.find(StringName(parts[1]))
		var age := AGES.find(StringName(parts[parts.size() - 1]))
		var season := 0 if parts.size() == 3 else BiomeData.SEASONS.find(StringName(parts[2]))
		if model > 0 and age >= 0 and season >= 0:
			out[model * 100 + season * 10 + age] = ki
	return out


## The node for (model, season, age); when the tree has no such age (dead firs have no saplings) the nearest age that exists. -1 = none.
static func _tree_node(kinds: Dictionary, model: int, season: int, age: int) -> int:
	for d in 5:
		for a in [age - d, age + d]:
			if a >= 0 and a < 5 and kinds.has(model * 100 + season * 10 + a):
				return kinds[model * 100 + season * 10 + a]
	return -1


## Age index (0 sapling .. 4 old) of a new tree in biome `bd` at local density d, capped by BiomeData.max_stage.
static func _tree_age(p: Params, bd: BiomeData, d: float, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	var age := 3
	if bd.age_rule == 1:   # fixed weights
		var w := [bd.age_w_sapling, bd.age_w_young, bd.age_w_small, bd.age_w_mature, bd.age_w_old]
		var tot := 0.0
		for x in w:
			tot += x
		var acc := 0.0
		u *= tot
		age = 4
		for k in 5:
			acc += w[k]
			if u <= acc:
				age = k
				break
	elif d > p.age_core:
		age = 4 if u < p.core_old else 3
	elif d > p.age_mid:
		age = 2 if u < p.mid_small else 3
	else:
		age = 1 if u < p.edge_young else (0 if u < p.edge_young + p.edge_sapling else 2)
	return mini(age, bd.max_stage)


## One tree on cell `c` (which must belong to `biome`) if every check passes (land, not boss land, not near home, not in a clearing, not on a shore cell, the trunk cell and its
## 4 neighbours free of trunks, `ring` cells free around it, the circle legal). True = placed.
static func _put_tree(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator, c: Vector2i, biome: int, node: int, ring: int, home: Vector2) -> bool:
	# every random number of the try is drawn first: a check that fails (because another biome's tree stands there) must not shift this biome's stream
	var v_draw := rng.randi()
	var jit := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * p.tree_jitter * p.cell
	if node < 0 or c.x < 0 or c.y < 0 or c.x >= p.cols or c.y >= p.rows:
		return false
	var ci := c.y * p.cols + c.x
	if res.land[ci] == 0 or res.area[ci] == Area.BOSS or res.biome[ci] != biome or res.veg_clear[ci] == 1:
		return false   # a group member that would land in another biome is dropped: each biome only grows its own table
	if Vector2(c.x + 0.5, c.y + 0.5).distance_to(home) < p.tree_home_clear:
		return false
	var occ := res.veg_occ
	for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _trunk_at(occ, p, c + d):
			return false
	if ring > 0:
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if dx * dx + dy * dy <= ring * ring and _trunk_at(occ, p, c + Vector2i(dx, dy)):
					return false
	var kind: ResourceNodeData = style.resource_nodes[node]
	var v := v_draw % kind.regions.size()
	# trunk foot near the bottom of its cell (jittered, so no rows); the collision circle sits on the foot
	var pos := Vector2((c.x + 0.5) * p.cell, (c.y + 1.0) * p.cell - 2.0 - kind.radius) + jit
	if not res.shore.is_empty():   # the drawn tree, not its cell: the jitter can move the foot or the circle onto a shore cell
		for q in [pos, pos + Vector2(0.0, kind.radius)]:
			var sc := cell_index(p, Vector2i((q / p.cell).floor()))
			if sc >= 0 and res.shore[sc] == 1:
				return false
	# spacing 0: only trunks that would overlap (or overlap a rock) are dropped
	if not _obstacle_legal(res, p, pos, kind.radius, kind.regions[v].size * float(kind.pixel_scale), 0.0):
		return false
	_add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": node})
	occ[ci] = 1
	return true


static func _trunk_at(occ: PackedByteArray, p: Params, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < p.cols and c.y < p.rows and occ[c.y * p.cols + c.x] == 1


## Trees of every biome (rules: vegetation-rules.md, numbers: BiomeData). Per biome and 16x16-cell block, random tries over that biome's cells;
## a try that fails a check is dropped, never moved. Chance fades with f where an open (Plains) biome meets a wooded one and, for a biome that
## asks for it, with the local density d. Age follows d (forest rule or fixed weights), colour and model come from the biome's tree table.
## One random stream per biome. `kinds` = _tree_kinds().
static func _place_trees(res: Result, style: MapStyle, p: Params, kinds: Dictionary) -> void:
	make_veg_lists(res, p)
	var home := Vector2(p.player_spawn / p.cell)
	var cols := p.cols
	var nb := res.biomes.size()
	# 1. clearings (own stream) in the biomes that have them; the mask makes the per-try test one lookup
	var crng := _rng(res.seed + SEED_CLEARINGS)
	res.clearings.clear()
	var wooded := PackedInt32Array()
	for b in nb:
		if res.biomes[b].has_clearings:
			wooded.append_array(res.veg_by_biome[b])
	if not wooded.is_empty():
		for _i in roundi(wooded.size() / maxf(p.clearing_per_cells, 1.0)):
			var fc := wooded[crng.randi() % wooded.size()]
			res.clearings.append(Vector3(fc % cols + 0.5, fc / cols + 0.5, crng.randf_range(p.clearing_r_min, p.clearing_r_max)))
	for cl in res.clearings:
		for cy in range(maxi(int(cl.y - cl.z) - 1, 0), mini(int(cl.y + cl.z) + 2, p.rows)):
			for cx in range(maxi(int(cl.x - cl.z) - 1, 0), mini(int(cl.x + cl.z) + 2, cols)):
				if Vector2(cx + 0.5, cy + 0.5).distance_to(Vector2(cl.x, cl.y)) <= cl.z:
					res.veg_clear[cy * cols + cx] = 1
	# 2. trees
	var dn := veg_noise(res.seed, p)
	var bcells := TREE_BLOCK * TREE_BLOCK
	for b in nb:
		var bd := res.biomes[b]
		var rows := bd.tree_rows()
		if bd.tree_tries <= 0.0 or rows.is_empty() or (p.pp != null and not p.pp.shows(&"trees", b)):
			continue
		var total := 0.0
		for r in rows:
			total += r.z
		var rng := _rng(res.seed + SEED_TREE_BIOME + b)
		var role := bd.forest_role
		for blk in res.veg_nblocks:
			var cells := res.veg_blocks[b * res.veg_nblocks + blk]
			if cells.is_empty():
				continue
			for _t in veg_count(rng, bd.tree_tries * cells.size() / bcells):
				var ci := cells[rng.randi() % cells.size()]
				var x := ci % cols + rng.randf()
				var y := ci / cols + rng.randf()
				var f: float = res.f[ci]
				if role == BiomeData.Role.WOODED:
					if rng.randf() >= _smooth(p.band_lo, p.band_hi, f):
						continue
				elif role == BiomeData.Role.OPEN:
					if rng.randf() >= 1.0 - _smooth(p.band_lo, p.band_hi, f):
						continue
				var d := veg_density(res, bd, dn, x, y, ci)
				if bd.fade_by_density and rng.randf() >= _smooth(p.tree_fade_lo, p.tree_fade_hi, d):
					continue
				var u := rng.randf() * total
				var row: Vector3 = rows[rows.size() - 1]
				for r in rows:
					u -= r.z
					if u <= 0.0:
						row = r
						break
				var spots: Array[Vector2] = [Vector2(x, y)]
				if bd.group_model > 0 and int(row.x) == bd.group_model:
					for _g in rng.randi_range(mini(bd.group_min, bd.group_max), maxi(bd.group_min, bd.group_max)) - 1:
						spots.append(Vector2(x, y) + Vector2.from_angle(rng.randf() * TAU) * rng.randf() * p.fir_group_radius)
				for sp in spots:
					var sc := Vector2i(sp.floor())
					var sci := sc.y * cols + sc.x if sc.x >= 0 and sc.y >= 0 and sc.x < cols and sc.y < p.rows else -1
					var sd := d if sci < 0 else veg_density(res, bd, dn, sp.x, sp.y, sci)
					var age := _tree_age(p, bd, sd, rng)
					var node := _tree_node(kinds, int(row.x), int(row.y), age)
					if node < 0 and p.pp != null and int(row.x) == 1 and b < p.pp.tree_fallback_season.size() and p.pp.tree_fallback_season[b] >= 0:
						node = _tree_node(kinds, 1, p.pp.tree_fallback_season[b], age)   # Pixel Plains has no dead / teal oak: the biome's own colour stands there
					_put_tree(res, style, p, rng, sc, b, node, bd.tree_ring, home)


## Trees, rocks and copper. Boss land: each kind at its `density_boss`. Elsewhere (0038 step 4) per biome: lone rocks and copper by
## BiomeData.rock_nodes_per_100 / copper_per_100, rock groups (their middle pieces are mineable rocks), then the aged trees.
static func _place_nodes(res: Result, style: MapStyle, p: Params) -> void:
	var t := Time.get_ticks_usec()
	make_veg_lists(res, p)
	var boss_cells := PackedInt32Array()
	for i in res.land.size():
		if res.land[i] == 1 and res.area[i] == Area.BOSS:
			boss_cells.append(i)
	var spacing := maxf(p.obstacle_min_spacing, rock_clearance(p))
	var widest := 0.0
	for k in style.resource_nodes:
		widest = maxf(widest, k.radius)
	res.obstacle_bucket = 2.0 * widest + spacing
	t = _lap(res, "nodes.cells", t)
	var tree_kinds := _tree_kinds(style, p.pp != null) if p.trees_on else {}   # aged trees fill the land (below); the old tree then keeps to the boss land
	var ki_rock := -1
	var ki_copper := -1
	for ki in style.resource_nodes.size():
		var kind: ResourceNodeData = style.resource_nodes[ki]
		if String(kind.id).begins_with("tree") and (String(kind.id).begins_with("treepp") != (p.pp != null)):
			continue   # the old trees in Pixel Plains mode (boss land stays treeless) and the Pixel Plains oaks in the old look: not scattered
		if kind.id == &"rock":
			ki_rock = ki
		elif kind.id == &"copper_rock":
			ki_copper = ki
		_scatter(res, p, kind, ki, boss_cells, roundi(kind.density_boss * boss_cells.size() / 100.0), _rng(res.seed + SEED_KIND + ki * 3 + Area.BOSS), spacing)
		if kind.id == &"tree":
			if tree_kinds.is_empty():
				_scatter(res, p, kind, ki, res.veg_all, roundi(kind.density_forest * res.veg_all.size() / 100.0), _rng(res.seed + SEED_KIND + ki * 3), spacing)
			continue
		if kind.id != &"rock" and kind.id != &"copper_rock":
			continue
		for b in res.biomes.size():
			var per100 := res.biomes[b].rock_nodes_per_100 if kind.id == &"rock" else res.biomes[b].copper_per_100
			if per100 > 0.0:
				var list := res.veg_by_biome[b]
				_scatter(res, p, kind, ki, list, roundi(per100 * list.size() / 100.0), _rng(res.seed + SEED_KIND_BIOME + ki * 16 + b), spacing)
	t = _lap(res, "nodes.rocks", t)
	if ki_rock >= 0:
		_place_rock_groups(res, style, p, ki_rock)
	if ki_copper >= 0 and ki_rock >= 0:
		_ensure_copper(res, style, p, ki_copper, ki_rock, spacing)
	t = _lap(res, "nodes.groups", t)
	_repair_reach(res, p)
	t = _lap(res, "nodes.repair1", t)
	if not tree_kinds.is_empty():   # trees go last and see the rocks, so a tree slider never moves a rock; the second repair may only drop trees
		_place_trees(res, style, p, tree_kinds)
		t = _lap(res, "nodes.trees", t)
		_repair_reach(res, p, tree_kinds.values())
		t = _lap(res, "nodes.repair2", t)
	_assign_looks(res, style, p)


## The first tools need copper: if no copper rock stands within `copper_near_home_cells` of home, put a small outcrop (one copper rock and two rocks
## beside it) on dry non-boss land 40% to 100% of that distance from home. Own stream; nothing else moves. Skipped when no legal spot exists.
static func _ensure_copper(res: Result, style: MapStyle, p: Params, ki_copper: int, ki_rock: int, spacing: float) -> void:
	if p.copper_near_home_cells <= 0.0:
		return
	var home := Vector2(p.player_spawn / p.cell)
	var reach := p.copper_near_home_cells * p.cell
	for o in res.obstacles:
		if o["node"] == ki_copper and (o["pos"] as Vector2).distance_to(p.player_spawn) <= reach:
			return
	var cells := PackedInt32Array()
	for ci in res.veg_all:
		var d := Vector2(ci % p.cols + 0.5, ci / p.cols + 0.5).distance_to(home)
		if d >= p.copper_near_home_cells * 0.4 and d <= p.copper_near_home_cells:
			cells.append(ci)
	if cells.is_empty():
		return
	var rng := _rng(res.seed + SEED_ROCKS + 20)
	var kc: ResourceNodeData = style.resource_nodes[ki_copper]
	var kr: ResourceNodeData = style.resource_nodes[ki_rock]
	for _attempt in 600:
		var ci := cells[rng.randi() % cells.size()]
		var pos := (Vector2(ci % p.cols, ci / p.cols) + Vector2(rng.randf(), rng.randf())) * p.cell
		if not _obstacle_legal(res, p, pos, kc.radius, Vector2(kc.regions[0].size) * float(kc.pixel_scale) if not kc.regions.is_empty() else Vector2.ZERO, spacing):
			continue
		_add_obstacle(res, {"region": 0, "pos": pos, "radius": kc.radius, "node": ki_copper})
		for _k in 2:   # the two rocks beside it, if they fit
			var rpos := pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 3.0) * kr.radius * 1.2
			var v := rng.randi() % maxi(kr.regions.size(), 1)
			var sprite := kr.regions[v].size * float(kr.pixel_scale) if v < kr.regions.size() else Vector2.ZERO
			if _obstacle_legal(res, p, rpos, kr.radius, sprite, 4.0):
				_add_obstacle(res, {"region": v, "pos": rpos, "radius": kr.radius, "node": ki_rock})
		return


## `target` lone nodes of `kind`, each at a random spot of a random cell of `cells` (cell indices), when the spot is legal.
static func _scatter(res: Result, p: Params, kind: ResourceNodeData, ki: int, cells: PackedInt32Array, target: int, rng: RandomNumberGenerator, spacing: float) -> void:
	if cells.is_empty():
		return
	var made := 0
	for _attempt in target * 60:
		if made >= target:
			break
		var ci := cells[rng.randi() % cells.size()]
		var pos := (Vector2(ci % p.cols, ci / p.cols) + Vector2(rng.randf(), rng.randf())) * p.cell
		var v := rng.randi() % maxi(kind.regions.size(), 1)
		var sprite := kind.regions[v].size * float(kind.pixel_scale) if v < kind.regions.size() else Vector2.ZERO
		if _obstacle_legal(res, p, pos, kind.radius, sprite, spacing):
			_add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": ki})
			made += 1


## Rock groups of every biome: per block `rock_per_block` groups, each = rock_mid_min..max middle pieces + rock_small_min..max small stones.
## Boulders and the small stones are decoration (res.rock_pieces, BiomeVeg draws them); medium and big pieces are `rock` nodes you can mine
## (region 0 / 1 brown big / medium, 2 / 3 grey). A piece that fails a check is dropped. Own stream per biome.
static func _place_rock_groups(res: Result, style: MapStyle, p: Params, ki_rock: int) -> void:
	var kind: ResourceNodeData = style.resource_nodes[ki_rock]
	var cols := p.cols
	var bcells := TREE_BLOCK * TREE_BLOCK
	for b in res.biomes.size():
		var bd := res.biomes[b]
		var wsum := bd.rock_w_boulder + bd.rock_w_med + bd.rock_w_big
		if bd.rock_per_block <= 0.0 or wsum <= 0.0:
			continue
		var rng := _rng(res.seed + SEED_ROCKS + b)
		for blk in res.veg_nblocks:
			var cells := res.veg_blocks[b * res.veg_nblocks + blk]
			if cells.is_empty():
				continue
			for _t in veg_count(rng, bd.rock_per_block * cells.size() / bcells):
				var ci := cells[rng.randi() % cells.size()]
				var x := ci % cols + rng.randf()
				var y := ci / cols + rng.randf()
				if res.veg_clear[ci] == 1:
					continue
				var grey := rng.randf() >= bd.rock_brown_share
				for i in rng.randi_range(mini(bd.rock_mid_min, bd.rock_mid_max), maxi(bd.rock_mid_min, bd.rock_mid_max)):
					var at := Vector2(x, y)
					if i > 0:
						at += Vector2.from_angle(rng.randf() * TAU) * p.rock_group_radius * sqrt(rng.randf())
					var u := rng.randf() * wsum
					var pick := 0   # 0 boulder, 1 medium, 2 big
					if u > bd.rock_w_boulder:
						pick = 1 if u <= bd.rock_w_boulder + bd.rock_w_med else 2
					if pick == 0:
						res.rock_pieces.append(Vector3(at.x, at.y, 1.0 if grey else 0.0))
						continue
					var c := Vector2i(at.floor())
					var cj := cell_index(p, c)
					if cj < 0 or res.land[cj] == 0 or res.area[cj] == Area.BOSS:
						continue
					var v := (2 if grey else 0) + (0 if pick == 2 else 1)
					if v >= kind.regions.size():
						continue
					var pos := at * p.cell
					if _obstacle_legal(res, p, pos, kind.radius, kind.regions[v].size * float(kind.pixel_scale), 4.0):
						_add_obstacle(res, {"region": v, "pos": pos, "radius": kind.radius, "node": ki_rock})
						res.veg_occ[cj] = 2
				for _k in rng.randi_range(mini(bd.rock_small_min, bd.rock_small_max), maxi(bd.rock_small_min, bd.rock_small_max)):
					var a := rng.randf() * TAU
					var dd := bd.rock_spread * sqrt(rng.randf())
					res.rock_pieces.append(Vector3(x + cos(a) * dd, y + sin(a) * dd * 0.7, 3.0 if grey else 2.0))


## Which picture each node shows, by the area it stands in (forest: green trees, rocky: autumn / dead, boss: dead).
## Runs AFTER placement and draws no random numbers, so a seed still gives the same nodes in the same places.
static func _assign_looks(res: Result, style: MapStyle, p: Params) -> void:
	for i in res.obstacles.size():
		var o := res.obstacles[i]
		if o["node"] < 0:
			continue
		var c := Vector2i(o["pos"] / p.cell)
		var ci := cell_index(p, c)
		if ci < 0:
			continue
		var look := (style.resource_nodes[o["node"]] as ResourceNodeData).look_for(res.area[ci], c.x * 7 + c.y * 13 + i)
		if look >= 0:
			o["region"] = look


static func _add_obstacle(res: Result, o: Dictionary) -> void:
	res.obstacles.append(o)
	res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)


## True if any obstacle is closer than r + its radius + spacing. Bucket lookup; needs that sum <= obstacle_bucket.
static func _obstacle_near(res: Result, pos: Vector2, r: float, spacing: float) -> bool:
	var b := Vector2i(pos / res.obstacle_bucket)
	for by in range(b.y - 1, b.y + 2):
		for bx in range(b.x - 1, b.x + 2):
			for o: Dictionary in res.obstacle_grid.get(Vector2i(bx, by), []):
				if pos.distance_to(o["pos"]) < r + o["radius"] + spacing:
					return true
	return false


## A walker's width plus one FLOW_STEP: rocks keep this far from water, walls and each other, so every
## gap is wide enough for the 16 px walkability grid of floor_reachable to see a path through it.
static func rock_clearance(p: Params) -> float:
	return p.agent_radius * 2.0 + FLOW_STEP


static func _obstacle_legal(res: Result, p: Params, pos: Vector2, r: float, sprite: Vector2, spacing: float) -> bool:
	if not circle_on_land(res, p, pos, r + rock_clearance(p)):
		return false
	# Never touching the fight zone: the boss has no pathfinding.
	var closest := Vector2(clampf(pos.x, p.zone.position.x, p.zone.end.x), clampf(pos.y, p.zone.position.y, p.zone.end.y))
	if pos.distance_to(closest) < r + 4.0:
		return false
	# The picture too: the sprite stands on the circle, so a tall rock must not lean into the zone
	# (you would walk through what you can see).
	if Rect2(pos.x - sprite.x * 0.5, pos.y + r - sprite.y, sprite.x, sprite.y).intersects(p.zone):
		return false
	for s in p.spawns:
		if pos.distance_to(s) < p.spawn_clear_radius + r:
			return false
	return spacing < 0.0 or not _obstacle_near(res, pos, r, spacing)   # spacing < 0: no min distance (aged trees: only trunk cells exclude)


## Walk grid (FLOW_STEP px): 1 where a walker of agent_radius can stand, ignoring rocks. Inside the walls,
## and (if `land` is given) with all four sides and the centre on land.
static func _walk_free(p: Params, land := PackedByteArray(), count := PackedInt32Array()) -> PackedByteArray:
	var size := p.size_px()
	var nx := int(size.x / FLOW_STEP)
	var ny := int(size.y / FLOW_STEP)
	var free := PackedByteArray()
	free.resize(nx * ny)
	var r := p.agent_radius
	var lo := p.cell + r   # inside the walls: every sample below is >= 1 cell from the grid edge, so no bounds checks
	var ones := 0
	var x_lo := nx
	var x_hi := -1
	var colc := PackedInt32Array()   # per sample column: the cell under it, and under its left / right feeler
	var coll := PackedInt32Array()
	var colr := PackedInt32Array()
	colc.resize(nx)
	coll.resize(nx)
	colr.resize(nx)
	for x in nx:
		var cx := (x + 0.5) * FLOW_STEP
		if cx < lo or cx > size.x - lo:
			continue
		x_lo = mini(x_lo, x)
		x_hi = x
		colc[x] = int(cx / p.cell)
		coll[x] = int((cx - r) / p.cell)
		colr[x] = int((cx + r) / p.cell)
	for y in ny:
		var cy := (y + 0.5) * FLOW_STEP
		if cy < lo or cy > size.y - lo:
			continue
		if land.is_empty():
			for x in range(x_lo, x_hi + 1):
				free[y * nx + x] = 1
			ones += maxi(x_hi - x_lo + 1, 0)
			continue
		var row := int(cy / p.cell) * p.cols
		var row_up := int((cy - r) / p.cell) * p.cols
		var row_dn := int((cy + r) / p.cell) * p.cols
		for x in range(x_lo, x_hi + 1):
			var col := colc[x]
			if land[row + col] == 1 and land[row + coll[x]] == 1 and land[row + colr[x]] == 1 \
					and land[row_up + col] == 1 and land[row_dn + col] == 1:
				free[y * nx + x] = 1
				ones += 1
	if not count.is_empty():
		count[0] = ones
	return free


## After the land under the cells in `changed` (flat cell indices) went to water: redo only the walk-grid samples that look at
## those cells, in place. Returns the change in the number of free samples. Same rule as _walk_free.
static func _walk_free_patch(p: Params, land: PackedByteArray, free: PackedByteArray, changed: PackedInt32Array) -> int:
	var size := p.size_px()
	var nx := int(size.x / FLOW_STEP)
	var ny := int(size.y / FLOW_STEP)
	var r := p.agent_radius
	var lo := p.cell + r
	var delta := 0
	var span := int(ceilf((p.cell + r) / FLOW_STEP)) + 1   # samples around a cell that can look at it
	for ci in changed:
		var cx := ci % p.cols
		var cy := ci / p.cols
		var x0 := maxi(int(cx * p.cell / FLOW_STEP) - span, 0)
		var x1 := mini(int((cx + 1) * p.cell / FLOW_STEP) + span, nx - 1)
		var y0 := maxi(int(cy * p.cell / FLOW_STEP) - span, 0)
		var y1 := mini(int((cy + 1) * p.cell / FLOW_STEP) + span, ny - 1)
		for y in range(y0, y1 + 1):
			var sy := (y + 0.5) * FLOW_STEP
			for x in range(x0, x1 + 1):
				var i := y * nx + x
				if free[i] == 0:
					continue
				var sx := (x + 0.5) * FLOW_STEP
				var row := int(sy / p.cell) * p.cols
				var col := int(sx / p.cell)
				if not (land[row + col] == 1 and land[row + int((sx - r) / p.cell)] == 1 and land[row + int((sx + r) / p.cell)] == 1 \
						and land[int((sy - r) / p.cell) * p.cols + col] == 1 and land[int((sy + r) / p.cell) * p.cols + col] == 1):
					free[i] = 0   # land only ever goes away here, so a sample can only turn from free to blocked
					delta -= 1
	return delta


## 4-neighbour flood over a walk grid; returns the seen mask.
static func _walk_flood(free: PackedByteArray, nx: int, ny: int, start: Vector2i, count := PackedInt32Array()) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(nx * ny)
	if not count.is_empty():
		count[0] = 0
	if free[start.y * nx + start.x] == 0:
		return seen
	var reached := _span_fill(free, seen, nx, ny, start.y * nx + start.x)
	if not count.is_empty():
		count[0] = reached
	return seen


## 4-neighbour flood by spans: fills a whole run of a row, then looks at the rows above and below it. `seen` gets 1 on every
## cell reached from `start` over cells where `open` is 1. Returns how many. A run costs a few operations per cell, not per neighbour.
static func _span_fill(open: PackedByteArray, seen: PackedByteArray, w: int, h: int, start: int, want := 1, spans := PackedInt32Array(), stack := PackedInt32Array()) -> int:
	if stack.size() < 2 * w * h + 4:   # spans never overlap, so at most 2 pushes per cell
		stack.resize(2 * w * h + 4)
	var sp := 1
	stack[0] = start
	var reached := 0
	while sp > 0:
		sp -= 1
		var i := stack[sp]
		if seen[i] == 1:
			continue
		var y := i / w
		var row := y * w
		var xl := i - row
		var xr := xl
		while xl > 0 and open[row + xl - 1] == want and seen[row + xl - 1] == 0:
			xl -= 1
		while xr < w - 1 and open[row + xr + 1] == want and seen[row + xr + 1] == 0:
			xr += 1
		for k in range(row + xl, row + xr + 1):
			seen[k] = 1
		reached += xr - xl + 1
		spans.append(row + xl)
		spans.append(xr - xl + 1)
		for r2 in [row - w, row + w]:
			if r2 < 0 or r2 >= w * h:
				continue
			var run := false
			for k in range(r2 + xl, r2 + xr + 1):
				if open[k] == want and seen[k] == 0:
					if not run:
						stack[sp] = k
						sp += 1
						run = true
				else:
					run = false
	return reached


## Flood fill on a coarse grid from the player's spawn: every cell a walker of agent_radius can stand
## on (inside the walls, clear of every rock) must be reachable. Public: the tests call it too.
static func floor_reachable(p: Params, obstacles: Array[Dictionary], land := PackedByteArray()) -> bool:
	return _unreached(p, obstacles, land).is_empty()


## Centres of the walk-grid samples a walker could stand on but cannot reach from home (see floor_reachable).
## If home itself is blocked, returns [Vector2.INF].
static func _unreached(p: Params, obstacles: Array[Dictionary], land: PackedByteArray, base := PackedByteArray(), base_n := -1) -> PackedVector2Array:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var cnt := PackedInt32Array([0])
	var free := base.duplicate() if not base.is_empty() else _walk_free(p, land, cnt)
	var free_n := base_n if not base.is_empty() and base_n >= 0 else cnt[0]
	free_n -= _clear_rocks(p, free, obstacles, nx, ny)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	if free[start.y * nx + start.x] == 0:
		return PackedVector2Array([Vector2.INF])
	var seen := _walk_flood(free, nx, ny, start, cnt)
	var out := PackedVector2Array()
	if cnt[0] == free_n:   # the flood reached every free sample: nothing is lost (the common case)
		return out
	for i in free.size():
		if free[i] == 1 and seen[i] == 0:
			out.append(Vector2((i % nx + 0.5) * FLOW_STEP, (i / nx + 0.5) * FLOW_STEP))
	return out


## Clears every rock out of a walk grid (each clears only the samples in its own box). Returns how many samples it cleared.
static func _clear_rocks(p: Params, free: PackedByteArray, obstacles: Array[Dictionary], nx: int, ny: int) -> int:
	var cleared := 0
	var agent := p.agent_radius
	for o in obstacles:
		var reach: float = o["radius"] + agent
		var pos: Vector2 = o["pos"]
		for y in range(maxi(int((pos.y - reach) / FLOW_STEP), 0), mini(int((pos.y + reach) / FLOW_STEP) + 1, ny)):
			var cy := (y + 0.5) * FLOW_STEP
			for x in range(maxi(int((pos.x - reach) / FLOW_STEP), 0), mini(int((pos.x + reach) / FLOW_STEP) + 1, nx)):
				if free[y * nx + x] == 1 and Vector2((x + 0.5) * FLOW_STEP, cy).distance_to(pos) <= reach:
					free[y * nx + x] = 0
					cleared += 1
	return cleared


## The walk grid with every rock cleared out of it: 1 where a walker can stand.
## `base` = a ready _walk_free(p, land) to copy instead of computing it again (land does not change between calls).
static func walk_grid(p: Params, obstacles: Array[Dictionary], land: PackedByteArray, base := PackedByteArray()) -> PackedByteArray:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var free := base.duplicate() if not base.is_empty() else _walk_free(p, land)
	_clear_rocks(p, free, obstacles, nx, ny)
	return free


## Can a walker still get from the player's spawn to `goal` (px) on `free` once the rects in `blockers`
## (solid boxes, px) are added? Reuses the same flood as floor_reachable. `free` is not changed.
## One flood; call it with no blockers first to know whether there is a path to protect at all.
static func goal_reachable_with(p: Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2) -> bool:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	var g := Vector2i(clampi(int(goal.x / FLOW_STEP), 0, nx - 1), clampi(int(goal.y / FLOW_STEP), 0, ny - 1))
	var f := free.duplicate()
	for r in blockers:
		var b := r.grow(p.agent_radius)
		for y in range(maxi(int(b.position.y / FLOW_STEP), 0), mini(int(b.end.y / FLOW_STEP) + 1, ny)):
			for x in range(maxi(int(b.position.x / FLOW_STEP), 0), mini(int(b.end.x / FLOW_STEP) + 1, nx)):
				if b.has_point(Vector2((x + 0.5) * FLOW_STEP, (y + 0.5) * FLOW_STEP)):
					f[y * nx + x] = 0
	if f[start.y * nx + start.x] == 0:
		return false
	return _walk_flood(f, nx, ny, start)[g.y * nx + g.x] == 1


## Fast yes for goal_reachable_with: crop a window around the blockers and check that every walkable cell touching them stays connected
## to the others inside the window. If it does, the blockers cannot cut the walk (a path through the blocked spot detours inside the window).
## false = unknown (a ring cell is cut off inside the window, or the spawn / goal is under a blocker): run the full flood.
static func blockers_keep_local_walk(p: Params, free: PackedByteArray, blockers: Array[Rect2], goal: Vector2, margin := 12) -> bool:
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var all := Rect2()
	for i in blockers.size():
		var b := blockers[i].grow(p.agent_radius)
		all = b if i == 0 else all.merge(b)
		for pt in [p.player_spawn, goal]:
			if b.has_point(pt):
				return false
	if blockers.is_empty():
		return true
	var x0 := maxi(int(all.position.x / FLOW_STEP) - margin, 0)
	var y0 := maxi(int(all.position.y / FLOW_STEP) - margin, 0)
	var x1 := mini(int(all.end.x / FLOW_STEP) + margin + 1, nx)
	var y1 := mini(int(all.end.y / FLOW_STEP) + margin + 1, ny)
	var w := x1 - x0
	var h := y1 - y0
	if w <= 0 or h <= 0:
		return false
	var open := PackedByteArray()
	open.resize(w * h)
	for y in h:
		for x in w:
			open[y * w + x] = free[(y0 + y) * nx + x0 + x]
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for r in blockers:
		var b := r.grow(p.agent_radius)
		for y in range(maxi(int(b.position.y / FLOW_STEP) - y0, 0), mini(int(b.end.y / FLOW_STEP) + 1 - y0, h)):
			for x in range(maxi(int(b.position.x / FLOW_STEP) - x0, 0), mini(int(b.end.x / FLOW_STEP) + 1 - x0, w)):
				if b.has_point(Vector2((x0 + x + 0.5) * FLOW_STEP, (y0 + y + 0.5) * FLOW_STEP)):
					blocked[y * w + x] = 1
	var ring := PackedInt32Array()
	for y in h:
		for x in w:
			var i := y * w + x
			if open[i] == 1 and blocked[i] == 0 and (
					(x > 0 and blocked[i - 1] == 1) or (x < w - 1 and blocked[i + 1] == 1) or (y > 0 and blocked[i - w] == 1) or (y < h - 1 and blocked[i + w] == 1)):
				ring.append(i)
	for i in w * h:
		if blocked[i] == 1:
			open[i] = 0
	if ring.is_empty():
		return true
	var seen := PackedByteArray()
	seen.resize(w * h)
	_span_fill(open, seen, w, h, ring[0])
	for i in ring:
		if seen[i] == 0:
			return false
	return true


## Many nodes can close a pocket between them and the coast. Drop the nodes around any walkable spot
## the walker cannot reach, until none is left (each pass only removes, so it ends).
static func _repair_reach(res: Result, p: Params, only_nodes: Array = []) -> void:
	if res.walk_base.is_empty():
		var cnt0 := PackedInt32Array([0])
		res.walk_base = _walk_free(p, res.walk_land, cnt0)
		res.walk_base_n = cnt0[0]
	var nx := int(p.size_px().x / FLOW_STEP)
	var ny := int(p.size_px().y / FLOW_STEP)
	var start := Vector2i(clampi(int(p.player_spawn.x / FLOW_STEP), 0, nx - 1), clampi(int(p.player_spawn.y / FLOW_STEP), 0, ny - 1))
	var free := res.walk_base.duplicate()
	var free_n := res.walk_base_n - _clear_rocks(p, free, res.obstacles, nx, ny)
	if free[start.y * nx + start.x] == 0:
		return   # home itself is blocked: nothing to repair
	var cnt := PackedInt32Array([0])
	var seen := _walk_flood(free, nx, ny, start, cnt)
	var seen_n := cnt[0]
	var stack := PackedInt32Array()   # shared flood stack
	var cand := PackedInt32Array()    # samples that may be unreached (empty = look at all of them, the first round)
	var first := true
	while seen_n < free_n:
		# the samples a walker can stand on but cannot reach
		var lost_mask := PackedByteArray()   # an obstacle looks only at the samples in its own box
		lost_mask.resize(nx * ny)
		var still := PackedInt32Array()
		if first:
			for i in free.size():
				if free[i] == 1 and seen[i] == 0:
					lost_mask[i] = 1
					still.append(i)
		else:
			for i in cand:
				if free[i] == 1 and seen[i] == 0 and lost_mask[i] == 0:
					lost_mask[i] = 1
					still.append(i)
		first = false
		var kept: Array[Dictionary] = []
		var removed: Array[Dictionary] = []
		for o in res.obstacles:
			var reach: float = o["radius"] + p.agent_radius + 2.0 * FLOW_STEP
			var near := false
			if not only_nodes.is_empty() and not only_nodes.has(o["node"]):
				kept.append(o)
				continue
			var pos: Vector2 = o["pos"]
			for y in range(maxi(int((pos.y - reach) / FLOW_STEP), 0), mini(int((pos.y + reach) / FLOW_STEP) + 1, ny)):
				for x in range(maxi(int((pos.x - reach) / FLOW_STEP), 0), mini(int((pos.x + reach) / FLOW_STEP) + 1, nx)):
					if lost_mask[y * nx + x] == 1 and Vector2((x + 0.5) * FLOW_STEP, (y + 0.5) * FLOW_STEP).distance_to(pos) <= reach:
						near = true
						break
				if near:
					break
			if near:
				removed.append(o)
			else:
				kept.append(o)
		if removed.is_empty():
			return   # nothing removable: do not loop forever
		res.obstacles = kept
		res.obstacle_grid.clear()
		for o in kept:
			res.obstacle_grid.get_or_add(Vector2i(o["pos"] / res.obstacle_bucket), []).append(o)
		# the walk grid again with the remaining rocks; the samples that just became free are inside the removed rocks' boxes
		var free_new := res.walk_base.duplicate()
		free_n = res.walk_base_n - _clear_rocks(p, free_new, kept, nx, ny)
		var fresh := PackedInt32Array()
		for o in removed:
			var reach: float = o["radius"] + p.agent_radius
			var pos: Vector2 = o["pos"]
			for y in range(maxi(int((pos.y - reach) / FLOW_STEP), 0), mini(int((pos.y + reach) / FLOW_STEP) + 1, ny)):
				for x in range(maxi(int((pos.x - reach) / FLOW_STEP), 0), mini(int((pos.x + reach) / FLOW_STEP) + 1, nx)):
					var i := y * nx + x
					if free_new[i] == 1 and free[i] == 0:
						free[i] = 1   # marks it handled; `free` ends up equal to free_new
						fresh.append(i)
		free = free_new
		# reachability only grows: flood from every fresh sample that touches a reached one
		for i in fresh:
			if seen[i] == 0:
				var x := i % nx
				if (x > 0 and seen[i - 1] == 1) or (x < nx - 1 and seen[i + 1] == 1) or (i >= nx and seen[i - nx] == 1) or (i + nx < nx * ny and seen[i + nx] == 1):
					seen_n += _span_fill(free, seen, nx, ny, i, 1, PackedInt32Array(), stack)
		still.append_array(fresh)
		cand = still


# --------------------------------------------------------------------- deco ---

static func _place_deco(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var sets := style.deco
	var any := false
	for s in sets:
		any = any or not s.regions.is_empty()
	if not any:
		return
	var size := p.size_px()
	var target := int(p.deco_density * p.cols * p.rows)
	var bucket := maxf(p.deco_min_spacing, 1.0)
	var grid := {}   # bucket key (by * 100000 + bx) -> PackedVector2Array of positions; bucket size = deco_min_spacing
	# obstacles in a flat bucket grid (bucket >= radius + 8): the old code scanned every obstacle per candidate
	var wmax := 8.0
	for o in res.obstacles:
		wmax = maxf(wmax, o["radius"] + 8.0)
	var ogrid := {}   # bucket key -> PackedInt32Array of obstacle indices
	var opos := PackedVector2Array()
	var orad := PackedFloat64Array()
	for k in res.obstacles.size():
		var o := res.obstacles[k]
		opos.append(o["pos"])
		orad.append(o["radius"])
		var ob := Vector2i(o["pos"] / wmax)
		var key := ob.y * 100000 + ob.x
		if not ogrid.has(key):
			ogrid[key] = PackedInt32Array()
		ogrid[key].append(k)
	var wtab: Array[PackedFloat64Array] = []   # [area][set] weight, and its running total
	var wtot := PackedFloat64Array()
	for area in 3:
		var row := PackedFloat64Array()
		var tot := 0.0
		for st in sets:
			var w := _deco_weight(st, area)
			row.append(w)
			tot += w
		wtab.append(row)
		wtot.append(tot)
	var empty_v := PackedVector2Array()
	var empty_i := PackedInt32Array()
	var has_ground := not res.ground.is_empty()
	for _attempt in target * 25:
		if res.deco.size() >= target:
			break
		var pos := Vector2(rng.randf_range(p.cell * 1.5, size.x - p.cell * 1.5), rng.randf_range(p.cell * 1.5, size.y - p.cell))
		var pick_r := rng.randf()
		var cell := Vector2i(pos / p.cell)
		var ci := cell.y * p.cols + cell.x
		if res.land[ci] == 0:
			continue
		# which set: by weight, and by the island area (flowers only in the forest, dry stuff in rocky / boss ...)
		var area: int = res.area[ci]
		var total_w: float = wtot[area]
		if total_w <= 0.0:
			continue
		var pick := pick_r * total_w
		var si := 0
		for i in sets.size():
			var w: float = wtab[area][i]
			if pick < w:
				si = i
				break
			pick -= w
		var set: PropSet = sets[si]
		if has_ground:
			var gd := res.ground[ci]
			if (gd == Ground.DIRT or gd == Ground.COBBLE or gd == Ground.SAND or gd == Ground.SNOW or res.dirt_cells.has(cell)) and not set.on_dirt:
				continue                  # plants only on grass
		elif res.kind[ci] != FILL and not set.on_dirt:
			continue                      # plants only on full grass
		if rng.randf() > _n01(noise, pos.x / p.cell, pos.y / p.cell):
			continue                      # likelier where the noise is high
		var ok := true
		var b := Vector2i(pos / bucket)
		for by in range(maxi(b.y - 1, 0), b.y + 2):
			for bx in range(maxi(b.x - 1, 0), b.x + 2):
				for other: Vector2 in grid.get(by * 100000 + bx, empty_v):
					if pos.distance_to(other) < p.deco_min_spacing:
						ok = false
		if ok:
			var ob := Vector2i(pos / wmax)
			for by in range(maxi(ob.y - 1, 0), ob.y + 2):
				for bx in range(maxi(ob.x - 1, 0), ob.x + 2):
					for k in ogrid.get(by * 100000 + bx, empty_i):
						if pos.distance_to(opos[k]) < orad[k] + 8.0:
							ok = false
		if ok:
			res.deco.append({"set": si, "region": rng.randi() % set.regions.size(), "pos": pos})
			var key := b.y * 100000 + b.x
			if not grid.has(key):
				grid[key] = PackedVector2Array()
			grid[key].append(pos)


static func _deco_weight(set: PropSet, area: int) -> float:
	if set.regions.is_empty():
		return 0.0
	return set.weight * [set.area_weights.x, set.area_weights.y, set.area_weights.z][area]


# ------------------------------------------------------------------- border ---

## Bushes laid along the four walls, each overlapping the one before. Sorted by y so lower ones
## cover upper ones.
static func _place_border(res: Result, style: MapStyle, p: Params, rng: RandomNumberGenerator) -> void:
	var set := style.border
	if set == null or set.regions.is_empty():
		return
	var s := float(style.pixel_scale)
	var size := p.size_px()
	var inner := p.cell - 6.0         # how far a bush reaches in from the screen edge
	var dens := maxf(p.border_density, 0.05)
	for edge in 4:                    # 0 top, 1 bottom, 2 left, 3 right
		var t := -16.0
		var limit := size.x if edge < 2 else size.y
		while t < limit:
			var idx := rng.randi() % set.regions.size()
			var sz: Vector2 = set.regions[idx].size * s
			var pos := Vector2.ZERO
			var along := sz.x if edge < 2 else sz.y
			match edge:
				0: pos = Vector2(t + sz.x * 0.5, inner + rng.randf_range(-4.0, 8.0))
				1: pos = Vector2(t + sz.x * 0.5, size.y - inner + sz.y + rng.randf_range(-8.0, 4.0))
				2: pos = Vector2(inner - sz.x * 0.5 + rng.randf_range(-4.0, 8.0), t + sz.y)
				3: pos = Vector2(size.x - inner + sz.x * 0.5 + rng.randf_range(-8.0, 4.0), t + sz.y)
			res.border.append({"region": idx, "pos": pos, "flip": rng.randf() < 0.5})
			t += along * rng.randf_range(0.5, 0.75) / dens
	res.border.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)


# ------------------------------------------------------------------- ground ---
## The island's ground (looks only). Area -> ground, smoothed so no 1-cell spikes or holes reach the tiles, plus a
## beach. Dirt (patches, the camp, paths) is NOT in the ground array: it is a list of round stamps in pixels
## (`res.dirt_stamps`) that GroundBaker paints smoothly over the tiles, so a path at 45 degrees has no stair teeth.
## All from its own random stream (seed + 101): the gameplay stream is untouched, so seeds keep their trees, rocks and deco.
static func _build_ground(res: Result, style: MapStyle, p: Params) -> void:
	var n := p.cols * p.rows
	var rng := RandomNumberGenerator.new()
	rng.seed = res.seed + 101
	var noise := _noise(res.seed + 5, 0.13)
	var t := Time.get_ticks_usec()
	var g := PackedByteArray()
	var dist: PackedByteArray
	# The expensive base (biome ground, border jitter, smoothing, small patches, water distance) only depends on these numbers: a look
	# slider for paths / camp / patches re-uses it and only redoes the stamps and the beach (0038 step 2).
	var key := [p.border_jitter, p.min_island_cells, p.smooth_passes, p.camp_radius + p.beach_cells + 3, style.grounds.size()]
	if res.ground_key == key and not res.ground_base.is_empty():
		g = res.ground_base.duplicate()
		dist = res.ground_dist
	else:
		g.resize(n)
		var mix: Array = []   # per biome: the noise that mixes its second ground in (BiomeData.ground_alt), null = none
		for bd in res.biomes:
			mix.append(_noise(res.seed + SEED_VEG_NOISE + 1, 1.0 / maxf(bd.ground_alt_period, 1.0)) if bd.ground_alt > 0 else null)
		for i in n:
			if res.land[i] == 1:
				if res.area[i] == Area.BOSS:
					g[i] = AREA_GROUND[Area.BOSS]
					continue
				var bi: int = res.biome[i]
				var bd := res.biomes[bi]
				g[i] = bd.ground
				if mix[bi] != null and _n01(mix[bi], i % p.cols, i / p.cols) >= bd.ground_alt_share:
					g[i] = bd.ground_alt   # rocky: stone with dirt in clumps
		t = _lap(res, "ground.init", t)
		_jitter_borders(g, p, res.seed + 9)   # twice, so a border wanders by up to two cells
		_jitter_borders(g, p, res.seed + 10)
		t = _lap(res, "ground.jitter", t)
		_smooth_ground(g, p.cols, p.rows, p.smooth_passes)
		t = _lap(res, "ground.smooth", t)
		_drop_small(g, p)
		t = _lap(res, "ground.dropsmall", t)
		if not res.shore.is_empty():   # the land around a river / lake: the biome's own shore ground (dirt, sand ...); beaches and the boss land keep theirs
			for i in n:
				if res.shore[i] == 1 and g[i] != 0 and res.area[i] != Area.BOSS and res.biome[i] < Biome.BEACH_SAND:
					g[i] = res.biomes[res.biome[i]].shore_ground
		t = _lap(res, "ground.shore", t)
		dist = _water_dist(res, p, p.camp_radius + p.beach_cells + 3)
		t = _lap(res, "ground.waterdist", t)
		res.ground_base = g.duplicate()
		res.ground_dist = dist
		res.ground_key = key
	res.cell = p.cell
	res.dirt_stamps = PackedVector3Array()
	res.dirt_cells = {}
	_dirt_patches(res, p, g, dist, rng)
	var camp: Vector2 = p.spawns[3] if p.spawns.size() > 3 else p.player_spawn
	var camp_cell := Vector2i(camp / p.cell)
	# the clearing shrinks where home is near the coast (never into the beach), but it is never dropped unless camp_radius is 0
	if p.camp_radius > 0:
		var camp_r := clampf(float(dist[camp_cell.y * p.cols + camp_cell.x]) - p.beach_cells - 1.2, 1.2, p.camp_radius + 0.5)
		_add_blob(res, p, camp, camp_r * p.cell, rng)
	if p.path_on:
		_carve_paths(res, p, g, dist, rng, noise)
	t = _lap(res, "ground.camp+paths", t)
	var wobble := _noise(res.seed + 6, 0.21)
	for i in n:   # the beach is `beach_cells` wide, plus a ragged extra cell where the noise says so
		if g[i] != Ground.WATER and (dist[i] <= p.beach_cells or (dist[i] == p.beach_cells + 1 and p.beach_cells > 0 and _n01(wobble, i % p.cols, i / p.cols) > 0.62)):
			g[i] = Ground.DIRT
	t = _lap(res, "ground.beach", t)
	_smooth_ground(g, p.cols, p.rows, 1)
	res.ground = g
	t = _lap(res, "ground.smooth2", t)


## Ground only, again, after a look setting changed: nodes, rocks and the walk grid are not touched. Deco that now
## stands on dirt or cobble (and is not a pebble-like set) is dropped; a set with `any_ground` (the biome passes) only when a path or the camp covers it.
static func rebuild_ground(res: Result, style: MapStyle, p: Params) -> void:
	_build_ground(res, style, p)
	var kept: Array[Dictionary] = []
	for d in res.deco:
		var set: PropSet = style.deco[d["set"]]
		var c := Vector2i(d["pos"] / p.cell)
		var gd := res.ground[c.y * p.cols + c.x]
		if not set.on_dirt and ((not set.any_ground and (gd == Ground.DIRT or gd == Ground.COBBLE or gd == Ground.SAND or gd == Ground.SNOW)) or res.dirt_cells.has(c)):
			continue
		kept.append(d)
	res.deco = kept


## Border cells (land cells touching a different land ground) swap to that neighbour's ground with chance `border_jitter`,
## so a border is not one cell column for a long run. Smoothing runs after and removes what is too thin.
static func _jitter_borders(g: PackedByteArray, p: Params, jitter_seed: int) -> void:
	if p.border_jitter <= 0.0:
		return
	var src := g.duplicate()
	var cols := p.cols
	var offs := PackedInt32Array([-cols, cols, -1, 1])
	for y in range(1, p.rows - 1):
		for i in range(y * cols + 1, y * cols + cols - 1):
			var c := src[i]
			if c == 0:
				continue
			for o in offs:
				var v := src[i + o]
				if v != 0 and v != c:
					if float(_hash_int(i - y * cols, y, jitter_seed) % 100) / 100.0 < p.border_jitter:
						g[i] = v
					break


static func _hash_int(x: int, y: int, s: int) -> int:
	return ((x * 73856093) ^ (y * 19349663) ^ (s * 83492791)) & 0x7fffffff


## Connected patches of one ground (4-neighbour) smaller than `min_island_cells` take the ground most of their
## border cells have. Water is never touched.
static func _drop_small(g: PackedByteArray, p: Params) -> void:
	if p.min_island_cells <= 1:
		return
	var cols := p.cols
	var rows := p.rows
	var n := g.size()
	var seen := PackedByteArray()
	seen.resize(n)
	var cells := PackedInt32Array()   # flood queue, reused
	cells.resize(n)
	for start in n:
		if g[start] == 0 or seen[start] == 1:
			continue
		var kind := g[start]
		var tail := 1
		var head := 0
		cells[0] = start
		seen[start] = 1
		var votes := {}
		while head < tail:
			var i := cells[head]
			head += 1
			var x := i % cols
			for dir in 4:
				var j := i + 1 if dir == 0 else (i - 1 if dir == 1 else (i + cols if dir == 2 else i - cols))
				if (dir == 0 and x == cols - 1) or (dir == 1 and x == 0) or j < 0 or j >= n:
					continue
				var gj := g[j]
				if gj == kind:
					if seen[j] == 0:
						seen[j] = 1
						cells[tail] = j
						tail += 1
				elif gj != 0:
					votes[gj] = votes.get(gj, 0) + 1
		if tail < p.min_island_cells and not votes.is_empty():
			var best := 0
			var bn := -1
			for v in votes:
				if votes[v] > bn:
					bn = votes[v]
					best = v
			for k in tail:
				g[cells[k]] = best


## Majority passes: a land cell turns into its neighbours' ground when it is a 1-wide strip (same ground on
## both opposite sides), a spike (3 of 4 neighbours agree) or one half of a checkerboard. Water never votes.
## Cells on the map edge are left alone.
static func _smooth_ground(g: PackedByteArray, cols: int, rows: int, passes: int) -> void:
	for _pass in passes:
		var src := g.duplicate()
		for y in range(1, rows - 1):
			var row := y * cols
			for x in range(1, cols - 1):
				var i := row + x
				var c := src[i]
				if c == 0:
					continue
				var n := src[i - cols]
				var s := src[i + cols]
				var w := src[i - 1]
				var e := src[i + 1]
				if n == c and s == c and w == c and e == c and g[i - 1] == c and g[i - cols] == c:
					continue   # nothing around it differs, so none of the rules below can fire
				if n == s and n != c and n != 0:
					g[i] = n
				elif w == e and w != c and w != 0:
					g[i] = w
				else:
					for v in [n, s, w, e]:
						if v != c and v != 0 and int(n == v) + int(s == v) + int(w == v) + int(e == v) >= 3:
							g[i] = v
							break
					if g[i] == c:
						# checkerboard: two touching sides agree and the diagonal between them is our own ground.
						# Reads the live array (not src): two cells of one checkerboard must not both flip at once.
						n = g[i - cols]
						s = g[i + cols]
						w = g[i - 1]
						e = g[i + 1]
						if e == s and e != c and e != 0 and g[i + cols + 1] == c:
							g[i] = e
						elif e == n and e != c and e != 0 and g[i - cols + 1] == c:
							g[i] = e
						elif w == s and w != c and w != 0 and g[i + cols - 1] == c:
							g[i] = w
						elif w == n and w != c and w != 0 and g[i - cols - 1] == c:
							g[i] = w


## Cells to the nearest water (8-neighbour steps): water 0, a coast cell 1 ... `cap`; further land = cap + 1.
static func _water_dist(res: Result, p: Params, cap: int) -> PackedByteArray:
	var cols := p.cols
	var rows := p.rows
	var n := cols * rows
	var land := res.land
	var d := PackedByteArray()
	d.resize(n)
	d.fill(cap + 1)
	var frontier := PackedInt32Array()
	for i in n:
		if land[i] == 0:
			d[i] = 0
			frontier.append(i)
	var offs := PackedInt32Array([-cols - 1, -cols, -cols + 1, -1, 1, cols - 1, cols, cols + 1])
	for step in cap:
		var next := PackedInt32Array()
		var nd := step + 1
		for i in frontier:
			var x := i % cols
			var y := i / cols
			if x < 1 or y < 1 or x >= cols - 1 or y >= rows - 1:
				continue
			for o in offs:
				var j := i + o
				if d[j] > nd:
					d[j] = nd
					next.append(j)
		frontier = next
	return d


## A round dirt stamp (world px) and the cells it covers (deco keeps off them).
static func _add_stamp(res: Result, p: Params, center: Vector2, r: float) -> void:
	res.dirt_stamps.append(Vector3(center.x, center.y, r))
	var c0 := Vector2i(((center - Vector2(r, r)) / p.cell).floor())
	var c1 := Vector2i(((center + Vector2(r, r)) / p.cell).floor())
	for y in range(c0.y, c1.y + 1):
		for x in range(c0.x, c1.x + 1):
			if (Vector2(x + 0.5, y + 0.5) * p.cell).distance_to(center) < r + p.cell * 0.4:
				res.dirt_cells[Vector2i(x, y)] = true


## An organic blob: one big disc plus three smaller ones around it.
static func _add_blob(res: Result, p: Params, center: Vector2, r: float, rng: RandomNumberGenerator) -> void:
	_add_stamp(res, p, center, r)
	var a0 := rng.randf() * TAU
	for k in 3:
		_add_stamp(res, p, center + Vector2.from_angle(a0 + k * TAU / 3.0 + rng.randf_range(-0.4, 0.4)) * r * 0.75, r * rng.randf_range(0.5, 0.7))


## A few small, ragged dirt patches in the forest, away from the coast.
static func _dirt_patches(res: Result, p: Params, g: PackedByteArray, dist: PackedByteArray, rng: RandomNumberGenerator) -> void:
	var spots := PackedInt32Array()
	for i in g.size():
		if g[i] == Ground.GRASS and dist[i] > p.beach_cells + 3:
			spots.append(i)
	if spots.is_empty():
		return
	for _k in roundi(p.dirt_patches * spots.size() / 100.0):
		var i := spots[rng.randi() % spots.size()]
		var c := (Vector2(i % p.cols, i / p.cols) + Vector2(0.5, 0.5)) * p.cell
		_add_blob(res, p, c, rng.randf_range(0.8, maxf(p.dirt_patch_size * 0.7, 0.9)) * p.cell, rng)


## Home -> boss path over the walkable land, and a few branches towards the rocky ground. A* on the cell grid
## (AStarGrid2D, C++): water and the beach are solid, trees and rocks are expensive, noise makes it wander. The cell
## path is smoothed (Chaikin) and turned into stamps spaced along it, only where the ground is forest grass (a path ends
## where the rocky ground begins). The walk grid is not read or changed.
static func _carve_paths(res: Result, p: Params, g: PackedByteArray, dist: PackedByteArray, rng: RandomNumberGenerator, noise: FastNoiseLite) -> void:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, p.cols, p.rows)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar.fill_solid_region(astar.region, true)
	var keep := p.beach_cells + 2
	for i in g.size():
		if g[i] != Ground.WATER and dist[i] > keep:
			var c := Vector2i(i % p.cols, i / p.cols)
			astar.set_point_solid(c, false)
			astar.set_point_weight_scale(c, 1.0 + p.path_wobble * 3.0 * _n01(noise, c.x, c.y))
	for o in res.obstacles:   # go round trees and rocks
		var oc := Vector2i(o["pos"] / p.cell)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var q := oc + Vector2i(dx, dy)
				if astar.is_in_boundsv(q):
					astar.set_point_weight_scale(q, 8.0)
	var start := Vector2i(p.player_spawn / p.cell)
	var goal := Vector2i(p.zone.get_center() / p.cell)
	for e in [start, goal]:
		astar.set_point_solid(e, false)
	var main := astar.get_id_path(start, goal)
	var forest: Array[Vector2i] = []
	for c in main:
		if g[c.y * p.cols + c.x] == Ground.GRASS:
			forest.append(c)
	_stamp_path(res, p, g, main, maxi(p.path_width, 2))
	# branches: from points along the forest part of the main path to rocky cells that touch the forest
	var borders: Array[Vector2i] = []
	for y in range(1, p.rows - 1):
		for x in range(1, p.cols - 1):
			var i := y * p.cols + x
			if g[i] == Ground.COBBLE and (g[i - 1] == Ground.GRASS or g[i + 1] == Ground.GRASS or g[i - p.cols] == Ground.GRASS or g[i + p.cols] == Ground.GRASS) and dist[i] > keep:
				borders.append(Vector2i(x, y))
	if forest.is_empty() or borders.is_empty():
		return
	for b in p.path_branches:
		var origin := forest[int(forest.size() * lerpf(0.15, 0.85, float(b + 1) / (p.path_branches + 1)))]
		var far: Array[Vector2i] = []
		for c in borders:
			if absi(c.y - origin.y) > 10:
				far.append(c)
		if far.is_empty():
			continue
		var target := far[rng.randi() % far.size()]
		astar.set_point_solid(target, false)
		_stamp_path(res, p, g, astar.get_id_path(origin, target), maxi(p.path_width - 1, 2))


## Smooths a cell path (Chaikin, 3 rounds) and drops round stamps of diameter `width` cells along it, spaced a third
## of the radius apart, on forest grass only.
static func _stamp_path(res: Result, p: Params, g: PackedByteArray, cells: Array[Vector2i], width: int) -> void:
	if cells.size() < 2:
		return
	var pts := PackedVector2Array()
	for c in cells:
		pts.append((Vector2(c) + Vector2(0.5, 0.5)) * p.cell)
	for _round in 3:
		var nxt := PackedVector2Array([pts[0]])
		for k in pts.size() - 1:
			nxt.append(pts[k].lerp(pts[k + 1], 0.25))
			nxt.append(pts[k].lerp(pts[k + 1], 0.75))
		nxt.append(pts[pts.size() - 1])
		pts = nxt
	var r := width * p.cell * 0.5
	var step := r / 3.0
	var carry := 0.0
	var taper_len := 5.0 * p.cell     # past the forest the path fades out over this far onto the cobble
	var walked := -1.0                # < 0: not in the forest yet
	for k in pts.size() - 1:
		var seg := pts[k + 1] - pts[k]
		var seg_len := seg.length()
		var t := carry
		while t < seg_len:
			var at := pts[k] + seg * (t / maxf(seg_len, 0.001))
			var c := Vector2i(at / p.cell)
			if c.x >= 1 and c.y >= 1 and c.x < p.cols - 1 and c.y < p.rows - 1:
				var gd := g[c.y * p.cols + c.x]
				if gd == Ground.GRASS:
					walked = 0.0
					_add_stamp(res, p, at, r)
				elif gd == Ground.COBBLE and walked >= 0.0 and walked < taper_len:
					var f := walked / taper_len   # narrow plus dither: a worn trail that thins out
					if float(_hash_int(int(at.x), int(at.y), res.seed) % 100) / 100.0 >= f * 0.7:
						_add_stamp(res, p, at, r * lerpf(1.0, 0.3, f))
					walked += step
			t += step
		carry = t - seg_len
