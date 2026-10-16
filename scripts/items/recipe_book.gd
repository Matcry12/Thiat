class_name RecipeBook
extends RefCounted
## Loads every .tres in a folder (recipes, smelting). The one place that knows how a recipe is found:
## adding a recipe = adding a file. `.remap` is stripped so it also works in an exported build.

static func load_dir(dir_path: String) -> Array:
	var out := []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	var names := Array(dir.get_files())
	names.sort()
	for f: String in names:
		f = f.trim_suffix(".remap")
		if f.ends_with(".tres"):
			var r := load(dir_path.path_join(f))
			if r != null:
				out.append(r)
	return out
