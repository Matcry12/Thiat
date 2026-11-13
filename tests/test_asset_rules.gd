extends SceneTree
# Asset folder rules (decision 0063, assets/README.md). Plain text scan: no scenes, no map.
# 1 only game/ dev/ source/ retired/ under assets/, no loose files, .gdignore in source/ + retired/
# 2 code + data point only at game/ or dev/   3 shipped code never points at dev/
# 4 every file in game/ is used by something   5 every named path exists

const TOP: Array[String] = ["game", "dev", "source", "retired"]
const NEEDS_GDIGNORE: Array[String] = ["source", "retired"]
## Code + data that may use assets/dev/ (demos, F3 / test mode, dev-only rigs). Everything else may not.
## They also do NOT count as users in rule 4: a picture only they load is not in the real game.
const DEV_CODE: Array[String] = ["scenes/demo/", "scripts/demo/", "scripts/debug/", "data/dev/", "assets/dev/"]
## A shared file that may touch assets/dev/ anyway: path -> why. Keep empty if you can.
const DEV_SHARED := {}
## Files in game/ that are loaded by name, so no plain path exists: path (file or folder/) -> script that loads it.
## The script must contain the folder path (or the file name), so a rename on one side shows up here.
const BY_NAME := {
	"assets/game/ui/fonts/": "scripts/ui/ui_fonts.gd",                              # load("%s.fnt" % name) + "%s_ring.png"
	"assets/game/ui/skin/slices.json": "scripts/ui/pixel_art.gd",                   # GAME + "slices.json"
	"assets/game/map/pixel_plains/biomes/": "scripts/map/biome_art.gd",             # load("<folder>/<biome>/oaks.png") per biome (BiomeArt)
}
const TEXT_EXT: Array[String] = ["gd", "tscn", "tres", "json", "cfg", "gdshader", "godot"]
const NOT_CODE_EXT: Array[String] = ["import", "uid", "md", "txt"]

var _errors: Array[String] = []
var _text := {}   ## path -> file text (cache)

func _init() -> void:
	_rule1_top_folders()
	var refs := {}   ## "assets/..." path -> Array of files that name it
	var files: Array[String] = ["project.godot"]
	for root in ["scenes", "scripts", "data", "assets/game", "assets/dev"]:
		for f in _all_files("res://" + root):
			var p := f.trim_prefix("res://")
			# inside assets/ only the .tres / .tscn can name other files
			if _is_text(p) and (not p.begins_with("assets/") or p.ends_with(".tres") or p.ends_with(".tscn")):
				files.append(p)
	for p in files:
		for path in _paths_in(p):
			if not refs.has(path):
				refs[path] = []
			(refs[path] as Array).append(p)
	_rule2_3_5(refs)
	_rule4_game_files_used(refs)
	for e in _errors:
		print("FAIL " + e)
	print("PASS" if _errors.is_empty() else "FAIL (%d)" % _errors.size())
	quit(0 if _errors.is_empty() else 1)

# ---------------------------------------------------------------- rules

func _rule1_top_folders() -> void:
	for n in _list("res://assets", true):
		if not (n in TOP or n == "README.md"):
			_errors.append("assets/%s: only game, dev, source, retired and README.md may sit in assets/. Move it into one of them (see assets/README.md)." % n)
	for t in TOP:
		for n in _list("res://assets/" + t, false):
			if n != ".gdignore":
				_errors.append("assets/%s/%s: no loose files at the top of %s/. Put it in a folder that says what it is." % [t, n, t])
		if t in NEEDS_GDIGNORE and not FileAccess.file_exists("res://assets/%s/.gdignore" % t):
			_errors.append("assets/%s/.gdignore is missing. Godot must not import %s/." % [t, t])

func _rule2_3_5(refs: Dictionary) -> void:
	for path: String in refs:
		var by: String = ", ".join(refs[path].slice(0, 2))
		var sub := path.trim_prefix("assets/")
		var top := sub.get_slice("/", 0)
		if top != "game" and top != "dev":
			_errors.append("%s: named in %s. Rule 2: code and data may only use assets/game/ or assets/dev/, never source/ or retired/." % [path, by])
			continue
		if top == "dev":
			for f: String in refs[path]:
				if not _is_dev_code(f) and not DEV_SHARED.has(f):
					_errors.append("%s: named in %s. Rule 3: only demo / debug code may use assets/dev/. Move the picture to assets/game/ or the code to scripts/debug/." % [path, f])
		if path.ends_with("/") or path.contains("%"):
			continue
		if not (FileAccess.file_exists("res://" + path) or DirAccess.open("res://" + path) != null):
			_errors.append("%s: named in %s but the file is not there. Rule 5: fix the path." % [path, by])

func _rule4_game_files_used(refs: Dictionary) -> void:
	for f in _all_files("res://assets/game"):
		var p := f.trim_prefix("res://")
		if p.get_extension() in NOT_CODE_EXT or _used_by_game(refs, p) or _by_name_ok(p):
			continue
		_errors.append("%s: unused. Rule 4: nothing in the real game loads it (demo / debug code does not count). Move it to dev/ (demos) or retired/ (nobody), or add it to BY_NAME in this test." % p)

func _is_dev_code(f: String) -> bool:
	for d in DEV_CODE:
		if f.begins_with(d):
			return true
	return false

func _used_by_game(refs: Dictionary, p: String) -> bool:
	for f: String in refs.get(p, []):
		if not _is_dev_code(f):
			return true
	return false

func _by_name_ok(p: String) -> bool:
	for k: String in BY_NAME:
		if p == k or (k.ends_with("/") and p.begins_with(k)):
			var loader: String = BY_NAME[k]
			var needle := k if k.ends_with("/") else k.get_file()
			return FileAccess.file_exists("res://" + loader) and _read("res://" + loader).contains(needle)
	return false

# ---------------------------------------------------------------- helpers

## Every "res://assets/..." path in one file, as "assets/..." (cut at the first %, so a folder part stays).
func _paths_in(p: String) -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.create_from_string("res://(assets/[^\"'\\s)\\]},`\\\\]*)")
	for line in _read("res://" + p).split("\n"):
		if line.strip_edges().begins_with("#") or line.strip_edges().begins_with(";"):
			continue   # a comment naming a file is not a user
		for m in rx.search_all(line):
			var s := m.get_string(1).rstrip(".:;")
			if s.contains("%"):
				s = s.substr(0, s.find("%"))
			out.append(s)
	return out

func _is_text(p: String) -> bool:
	return p.get_extension() in TEXT_EXT

func _read(path: String) -> String:
	if not _text.has(path):
		_text[path] = FileAccess.get_file_as_string(path)
	return _text[path]

func _list(dir: String, want_dirs_too: bool) -> PackedStringArray:
	var d := DirAccess.open(dir)
	var out := PackedStringArray()
	if d == null:
		return out
	d.include_hidden = true
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if want_dirs_too or not d.current_is_dir():
			out.append(n)
		n = d.get_next()
	return out

func _all_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.include_hidden = true
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var full := dir.path_join(n)
		if d.current_is_dir():
			if n != ".godot":
				out.append_array(_all_files(full))
		else:
			out.append(full)
		n = d.get_next()
	return out
