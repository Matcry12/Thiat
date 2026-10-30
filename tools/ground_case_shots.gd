extends SceneTree
## One labelled shot per ground case (decision 0046), real GroundBaker / TerrainVisual via tools/ground_case_scene.tscn.
##   CASE_OUT=<out_dir> xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/ground_case_shots.gd
## Writes NN_<case>.png; tools/ground_case_sheet.py stitches contact_sheet.png.
const ORDER := [["step_beach", "1 beach step: grass > sand > water"], ["flat_desert", "2 sand biome, flat: sand = grass"],
	["flat_beach", "3 flat beach with foam: sand = water"], ["sand_bank", "4 sand bank in water"], ["snow_flat", "5 snowy biome, flat: snow = grass"],
	["snow_on_grass", "6 snow on top (biome edge)"], ["mixed_coast", "7 mixed coast / 3-way corner"], ["grass_on_water", "8 water bank band (top / left only)"]]

func _init() -> void:
	var out := OS.get_environment("CASE_OUT")   # not a user arg: GroundCase reads those as the case name
	for i in ORDER.size():
		var c: GroundCase = load("res://tools/ground_case_scene.tscn").instantiate()
		c.case_name = ORDER[i][0]
		c.zoom = 5.0
		root.add_child(c)
		var l := Label.new()
		l.text = ORDER[i][1]
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 6)
		l.position = Vector2(12, 8)
		var layer := CanvasLayer.new()
		layer.add_child(l)
		c.add_child(layer)
		for _f in 8:
			await process_frame
		root.get_texture().get_image().save_png("%s/%02d_%s.png" % [out, i + 1, ORDER[i][0]])
		c.queue_free()
		await process_frame
	quit()
