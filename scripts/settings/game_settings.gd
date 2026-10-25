class_name GameSettings
extends RefCounted
## Player settings (W8, decision 0040): master volume, screen shake strength, fullscreen.
## Saved to user://settings.cfg, loaded once on boot (title screen or an arena started directly).
## Shake has ONE live owner: CameraShake.shake_strength. It reads `shake_strength` here when it enters the tree
## and writes it back when it leaves; the settings panel reads and writes the live node, and save_file() stores
## the live value. Nothing here pushes shake into the engine.
## Under a test run (BOSSFIGHT_TEST_SEED set) the file is neither read nor written, unless a test sets `force_io`.

const SECTION := "game"

static var path := "user://settings.cfg"
static var master_volume := 1.0   ## 0..1 (linear)
static var shake_strength := 1.0  ## 0..2, same scale as the F3 CameraShake slider (start value; see above)
static var fullscreen := false
static var force_io := false      ## tests of this very class only
static var _loaded := false
static var _applied_fullscreen := -1   ## -1 = never applied

static func io_enabled() -> bool:
	return force_io or OS.get_environment("BOSSFIGHT_TEST_SEED") == ""

static func ensure_loaded() -> void:
	if not _loaded:
		load_file()

static func load_file() -> void:
	_loaded = true
	if not io_enabled():
		return
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return   # no file yet: the defaults stand
	master_volume = clampf(float(cf.get_value(SECTION, "master_volume", master_volume)), 0.0, 1.0)
	shake_strength = clampf(float(cf.get_value(SECTION, "shake_strength", shake_strength)), 0.0, 2.0)
	fullscreen = bool(cf.get_value(SECTION, "fullscreen", fullscreen))

## Stores the live values. `tree` lets it read the live shake from the CameraShake node.
static func save_file(tree: SceneTree = null) -> void:
	var live := _live_shake(tree)
	if live != null:
		shake_strength = live.shake_strength
	if not io_enabled():
		return
	var cf := ConfigFile.new()
	cf.set_value(SECTION, "master_volume", master_volume)
	cf.set_value(SECTION, "shake_strength", shake_strength)
	cf.set_value(SECTION, "fullscreen", fullscreen)
	cf.save(path)

static func file_exists() -> bool:
	return FileAccess.file_exists(path)

static func _live_shake(tree: SceneTree) -> CameraShake:
	var fx := tree.get_first_node_in_group("hit_fx") if tree else null
	return fx.get("shake") as CameraShake if fx != null else null

## The shake the panel shows: the live node when there is one (arena), else the stored value (title).
static func current_shake(tree: SceneTree) -> float:
	var live := _live_shake(tree)
	return live.shake_strength if live != null else shake_strength

static func set_shake(tree: SceneTree, v: float) -> void:
	shake_strength = v
	var live := _live_shake(tree)
	if live != null:
		live.shake_strength = v

## Volume now; the window mode only when the fullscreen setting itself changed (or at boot), and a
## maximized window is never touched while fullscreen is off.
static func apply() -> void:
	AudioServer.set_bus_mute(0, master_volume <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.001)))
	if int(fullscreen) == _applied_fullscreen:
		return
	_applied_fullscreen = int(fullscreen)
	var mode := DisplayServer.window_get_mode()
	if fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

static func status_text(tree: SceneTree = null) -> String:
	return "volume %d%%  shake %.2f  fullscreen %s\nfile: %s (%s)" % [roundi(master_volume * 100.0), current_shake(tree), "on" if fullscreen else "off", path, "saved" if file_exists() else "not saved yet"]
