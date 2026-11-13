class_name GroundCase
extends Node2D
## Forced ground cases for screenshots and tests (decision 0046). A case is a char grid of (material, level): one token per cell, tokens
## separated by spaces, e.g. "l2 l2 s1" = light grass level 2, light grass level 2, sand level 1. Materials:
##   w water   d dirt   l light grass   D dark grass (forest)   s beach sand   n snow (snowy biome)
## The grid becomes a MapGen.Result (the digit after the letter is ignored since 0069: no levels any more) and is baked by the
## real GroundBaker / TerrainVisual. Run the scene: godot --path . tools/ground_case_scene.tscn  (cases below, `case_name`, or F3-less: just look).
##   godot --path . tools/ground_case_scene.tscn -- <case name>      (prints the case names with no argument)

const CASES := {
	"step_beach": ["l2 l2 l2 l2 l2", "l2 l2 l2 l2 l2", "s1 s1 l2 l2 s1", "s1 s1 s1 s1 s1", "s1 s1 s1 s1 s1"],
	"flat_desert": ["l2 l2 l2 l2 l2", "l2 l2 l2 l2 l2", "s2 s2 l2 l2 s2", "s2 s2 s2 s2 s2", "s2 s2 s2 s2 s2"],
	"flat_beach": ["w0 w0 w0 w0 w0", "w0 s0 s0 s0 w0", "w0 s0 s0 s0 w0", "w0 s0 s0 s0 w0", "w0 w0 w0 w0 w0"],
	"sand_bank": ["w0 w0 w0 w0 w0", "w0 s1 s1 s1 w0", "w0 s1 s1 s1 w0", "w0 s1 s1 s1 w0", "w0 w0 w0 w0 w0"],
	"grass_on_water": ["w0 w0 w0 w0 w0", "w0 l2 l2 l2 w0", "w0 l2 l2 l2 w0", "w0 l2 l2 l2 w0", "w0 w0 w0 w0 w0"],
	"snow_on_grass": ["l2 l2 l2 l2 l2", "l2 n3 n3 n3 l2", "l2 n3 n3 n3 l2", "l2 n3 n3 n3 l2", "l2 l2 l2 l2 l2"],
	"snow_flat": ["l2 l2 l2 l2 l2", "l2 n2 n2 n2 l2", "l2 n2 n2 n2 l2", "l2 n2 n2 n2 l2", "l2 l2 l2 l2 l2"],
	"mixed_coast": ["l2 l2 l2 l2 l2 l2", "l2 l2 l2 l2 l2 l2", "s1 s1 l2 l2 s1 s1", "s0 s0 s0 l2 s0 s0", "w0 w0 w0 w0 w0 w0", "w0 w0 w0 w0 w0 w0"],
	"dirt_native": ["l2 l2 l2 l2 l2", "l2 d1 d1 d1 l2", "l2 d1 d1 d1 l2", "D2 D2 l2 l2 l2", "D2 D2 l2 l2 l2"],
}
const GROUND := {"w": MapGen.Ground.WATER, "d": MapGen.Ground.DIRT, "l": MapGen.Ground.GRASS, "D": MapGen.Ground.GRASS, "s": MapGen.Ground.SAND, "n": MapGen.Ground.SNOW}
const BIOME := {"w": MapGen.Biome.PLAINS, "d": MapGen.Biome.ROCKY, "l": MapGen.Biome.PLAINS, "D": MapGen.Biome.FOREST, "s": MapGen.Biome.BEACH_SAND, "n": MapGen.Biome.SNOWY}

@export var case_name := "mixed_coast"
@export var zoom := 4.0


## A MapGen.Result of a case grid.
static func result(rows: Array, seed_value := 1) -> MapGen.Result:
	var res := MapGen.Result.new()
	res.seed = seed_value
	res.rows = rows.size()
	res.cols = String(rows[0]).split(" ", false).size()
	var n := res.cols * res.rows
	res.ground.resize(n)
	res.biome.resize(n)
	for y in res.rows:
		var toks := String(rows[y]).split(" ", false)
		assert(toks.size() == res.cols, "ragged case row %d" % y)
		for x in res.cols:
			var tok: String = toks[x]
			res.ground[y * res.cols + x] = GROUND[tok[0]]
			res.biome[y * res.cols + x] = BIOME[tok[0]]
	return res


## The ground picture + animation mask of a case, baked by the real baker (whole case = one region, one tile larger than the grid).
static func bake(rows: Array, pp: PixelPlainsGround, seed_value := 1) -> Dictionary:
	var res := result(rows, seed_value)
	var style := MapStyle.new()
	style.pixel_plains = pp
	return GroundBaker.bake_region(res, style, 0, 0, res.cols + 1, res.rows + 1)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		case_name = args[0]
	if not CASES.has(case_name):
		print("cases: ", ", ".join(CASES.keys()))
		get_tree().quit(1)
		return
	var pp: PixelPlainsGround = load("res://data/maps/grass.tres").pixel_plains
	var rows: Array = CASES[case_name]
	var res := result(rows)
	var style := MapStyle.new()
	style.pixel_plains = pp
	var terrain := TerrainVisual.new()
	add_child(terrain)
	var scale_px := zoom
	terrain.begin_island(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8), Vector2(res.cols + 1, res.rows + 1) * pp.tile_size, scale_px, null, pp.tile_size, pp.shader_params())
	terrain.set_look({"shimmer_speed": 0.0, "shimmer_strength": 0.0, "shimmer_scale": 0.0, "shimmer_amount": 0.0, "wave_strength": 0.0, "drift_scale": 0.0, "drift_speed": 0.0,
		"shimmer_color": Color.WHITE, "shallow_lighten": 0.0, "shallow_color": Color.WHITE, "foam_alpha": 0.0, "foam_pulse": 0.0, "foam_speed": 0.0, "foam_color": Color.WHITE,
		"ground_brightness": 1.0, "ground_saturation": 1.0, "ground_neutral": true})
	var images := GroundBaker.bake_region(res, style, 0, 0, res.cols + 1, res.rows + 1)
	var look := {"neutral": true}
	images["tint"] = GroundBaker.tint_image_region(res, look, -1, -1, res.cols + 1, res.rows + 1)
	images["shade"] = GroundBaker.shade_image_region(res, look, -1, -1, res.cols + 1, res.rows + 1)
	terrain.set_chunk(0, Vector2i.ZERO, images, scale_px)
	var cam := Camera2D.new()
	cam.position = Vector2(res.cols, res.rows) * pp.tile_size * scale_px * 0.5
	add_child(cam)
