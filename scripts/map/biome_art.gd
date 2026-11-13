class_name BiomeArt
extends Resource
## One sheet per biome for the oaks and the hedges / stump, so each biome can be redrawn on its own:
## `<folder>/<biome>/oaks.png` and `hedges.png` (same size + layout as the originals, so every region stays valid).
## Files live in assets/game/map/pixel_plains/biomes/ (named so tests/test_asset_rules.gd finds the loader). A missing file falls back to the original sheet. Written (copies of the originals) by tools/bake_biome_art.gd.
## Ground (0069): `<folder>/<biome>/ground/<file>.png` for the 7 ground sheets + foam + water (GROUND_FILES), same layout as ground/ next to the oaks;
## kind = &"ground/<file>". PixelPlainsBaker reads them per corner layer; a missing file falls back to the base ground/ file.
## Replace a sheet by drawing the same file: nothing else changes. Data: data/maps/biome_art.tres.

static var NAMES: Array[StringName] = _names()   ## folder name per MapGen.Biome id: the enum key, lower case (one list, no copy)
const KINDS := {"oaks_noshadow.png": &"oaks", "hedges.png": &"hedges"}   ## original sheet file -> kind

const GROUND_FILES: Array[String] = ["dirt", "grass_light", "grass_dark", "sand", "snow", "cobble", "gravel", "foam", "water"]   ## index < 7 = PixelPlainsGround.Sheet

@export var enabled := true
@export_dir var folder := "res://assets/game/map/pixel_plains/biomes"

static func _names() -> Array[StringName]:
	var out: Array[StringName] = []
	for k in MapGen.Biome.keys():
		out.append(StringName(String(k).to_lower()))
	return out


static var _default: BiomeArt
static var _cache := {}   ## path -> Texture2D or null (missing)


static func get_default() -> BiomeArt:
	if _default == null:
		_default = load("res://data/maps/biome_art.tres")
	return _default


## The sheet to draw `original` from in biome `biome` (MapGen.Biome, -1 = none). Not a biome-art sheet, or missing file: `original`.
static func sheet(original: Texture2D, biome: int) -> Texture2D:
	if original == null or biome < 0 or biome >= NAMES.size():
		return original
	var kind: StringName = KINDS.get(original.resource_path.get_file(), &"")
	var art := get_default()
	if kind == &"" or art == null or not art.enabled:
		return original
	var t := art.texture(kind, biome)
	return t if t != null else original


## The ground file `file` (GROUND_FILES) of biome `biome`; null = use the base ground/ file.
static func ground_texture(file: String, biome: int) -> Texture2D:
	var art := get_default()
	if art == null or not art.enabled or biome < 0 or biome >= NAMES.size():
		return null
	return art.texture(StringName("ground/" + file), biome)


func path_of(kind: StringName, biome: int) -> String:
	return "%s/%s/%s.png" % [folder, NAMES[biome], kind]


func texture(kind: StringName, biome: int) -> Texture2D:
	var p := path_of(kind, biome)
	if not _cache.has(p):
		_cache[p] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _cache[p]


## Tests / live redraw: force the sheet of a biome (null = back to the file).
static func override(kind: StringName, biome: int, tex: Texture2D) -> void:
	var art := get_default()
	_cache[art.path_of(kind, biome)] = tex


static func clear_cache() -> void:
	_cache.clear()


## F3 line: which biome sheets are loaded, which fall back.
func status_text() -> String:
	var out := "biome art %s  folder %s" % ["on" if enabled else "OFF", folder]
	for kind in [&"oaks", &"hedges"]:
		var have: Array[String] = []
		var miss: Array[String] = []
		for b in NAMES.size():
			(have if texture(kind, b) != null else miss).append(String(NAMES[b]))
		out += "\n  %s loaded %d (%s)  missing %d (%s)" % [kind, have.size(), ", ".join(have), miss.size(), ", ".join(miss)]
	var gl: Array[String] = []
	for b in NAMES.size():
		var n := 0
		for g in GROUND_FILES:
			n += 1 if texture(StringName("ground/" + g), b) != null else 0
		gl.append("%s %d" % [NAMES[b], n])
	return out + "\n  ground files loaded (of %d) per biome: %s" % [GROUND_FILES.size(), ", ".join(gl)]
