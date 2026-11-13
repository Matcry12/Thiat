extends SceneTree
## One oaks + hedges sheet per biome, so each biome can be redrawn on its own (BiomeArt, data/maps/biome_art.tres).
## Writes assets/game/map/pixel_plains/biomes/<biome>/oaks.png (copy of ../oaks_noshadow.png) and hedges.png (copy of ../hedges.png).
## Only writes MISSING files: a sheet you already redrew is never touched. --force overwrites all.
## Run: timeout 120 godot --headless --script tools/bake_biome_art.gd            (add: -- --force)
## Then once: godot --headless --import   (so the game can load the new PNGs)

const SRC := {"oaks": "res://assets/game/map/pixel_plains/oaks_noshadow.png", "hedges": "res://assets/game/map/pixel_plains/hedges.png"}
const OUT := "res://assets/game/map/pixel_plains/biomes"


func _init() -> void:
	var force := OS.get_cmdline_user_args().has("--force")
	var wrote := 0
	var kept := 0
	for b in BiomeArt.NAMES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("%s/%s" % [OUT, b]))
		for kind in SRC:
			var dst := "%s/%s/%s.png" % [OUT, b, kind]
			if FileAccess.file_exists(dst) and not force:
				kept += 1
				continue
			var bytes := FileAccess.get_file_as_bytes(SRC[kind])   # a byte copy: same pixels, same size
			var f := FileAccess.open(dst, FileAccess.WRITE)
			f.store_buffer(bytes)
			f.close()
			wrote += 1
	print("biome art: wrote %d, kept %d (force %s)" % [wrote, kept, force])
	quit()
