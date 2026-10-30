class_name SaveGame
extends Node
## One save slot (W9, decision 0041): user://save.json. Child of the Arena. Collects the run into a Dictionary,
## writes it (autosave, Save & quit, window close, F3), and on a Continue applies a loaded one to the fresh arena.
## The island itself is NOT stored: only its seed + the map exports that differ from the scene, then what changed
## on it (gathered nodes by placement index, stations, loose pickups). Never saves while dead, while the boss is
## engaged, or under a test run (BOSSFIGHT_TEST_SEED set) unless `force_io`.

const VERSION := 3   # 3: map v3 (fewer, bigger lakes + rivers, 2x biomes, no rocks): an old seed would build another island; 2: loose pickups replace death bags (0042)

static var path := "user://save.json"
static var force_io := false      ## tests of this class only (they also point `path` at a temp file)
## A save waiting to be applied by the next arena (set by begin_load, consumed in _ready).
static var pending := {}

## Seconds between autosaves; 0 = off.
@export var autosave_interval := 60.0

var play_time := 0.0              ## seconds of unpaused play this run (carried over a Continue)
var last_result := "-"            ## F3: what the last save / load said
var last_save_unix := 0
var _countdown := 0.0

static func io_enabled() -> bool:
	return force_io or OS.get_environment("BOSSFIGHT_TEST_SEED") == ""

# ------------------------------------------------------------------ file

## The save as a Dictionary, or {} when there is none / it is corrupt / it is from another version (warns, never throws).
static func read_save() -> Dictionary:
	if not io_enabled() or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("save: cannot open %s" % path)
		return {}
	var j := JSON.new()
	var d = j.data if j.parse(f.get_as_text()) == OK else null   # parse() keeps a bad file a warning, not an engine error
	if not d is Dictionary:
		push_warning("save: %s is not a valid save file (corrupt)" % path)
		return {}
	if int(d.get("version", -1)) != VERSION:
		push_warning("save: %s has version %s, this build reads %d" % [path, str(d.get("version")), VERSION])
		return {}
	if not (d.get("world") is Dictionary and d.get("player") is Dictionary and d.get("inventory") is Array) or int(d["world"].get("seed", 0)) <= 0:
		push_warning("save: %s is missing parts (corrupt)" % path)
		return {}
	return d

static func has_valid_save() -> bool:
	return not read_save().is_empty()

static func delete_save() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## Continue: the next arena rebuilds this island and applies the rest.
static func begin_load(d: Dictionary) -> void:
	pending = d
	ArenaMap.retry_seed = int(d["world"]["seed"])
	ArenaMap.pending_settings = d["world"].get("map_settings", {})

static func item_table() -> Dictionary:
	var t := {}
	for f in DirAccess.get_files_at("res://data/items"):
		if f.ends_with(".tres"):
			var it := load("res://data/items/" + f) as ItemData
			if it:
				t[String(it.id)] = it
	return t

# ------------------------------------------------------------------ nodes we talk to

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group("player") as CharacterBody2D

func _map() -> ArenaMap:
	return get_tree().get_first_node_in_group("arena_map") as ArenaMap

func _boss() -> Boss:
	return get_tree().get_first_node_in_group("boss") as Boss

func _enter_tree() -> void:
	add_to_group("save_game")   # before any _ready: the F3 panel looks for it while it builds
	add_to_group("debug")

func _ready() -> void:
	_countdown = autosave_interval
	if not pending.is_empty():
		var d := pending
		pending = {}
		apply.call_deferred(d)   # the arena is still adding its children: stations and pickups join it next frame

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	play_time += delta
	if autosave_interval > 0.0 and io_enabled():
		_countdown -= delta
		if _countdown <= 0.0:
			_countdown = autosave_interval
			save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save()

func autosave_left() -> float:
	return maxf(_countdown, 0.0) if autosave_interval > 0.0 and io_enabled() else -1.0

# ------------------------------------------------------------------ save

## Why a save is refused right now ("" = fine).
func refusal() -> String:
	if not io_enabled():
		return "test run"
	var p := _player()
	var rs := p.get_node_or_null("Respawner") as Respawner if p else null
	if p == null or p.get("dead") == true or (rs and rs.is_waiting()):
		return "dead"
	var b := _boss()
	if b != null and b.mode != Boss.Mode.DEAD and b.aggro == Boss.Aggro.ENGAGED:
		return "boss engaged"
	return ""

## Writes the file. Returns "" or the reason it did not.
func save() -> String:
	var why := refusal()
	if why != "":
		last_result = "not saved: " + why
		return why
	var json := JSON.stringify(collect(), "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_result = "not saved: cannot write"
		push_warning("save: cannot write %s" % tmp)
		return "cannot write"
	f.store_string(json)
	f.close()
	DirAccess.rename_absolute(tmp, path)   # a crash mid-write never leaves half a save
	last_save_unix = int(Time.get_unix_time_from_system())
	last_result = "saved"
	return ""

## The run as plain data. Pure read; the F3 status and the tests use it too.
func collect() -> Dictionary:
	var p := _player()
	var m := _map()
	var inv := p.get_node("Inventory") as Inventory
	var health := p.get_node("Health") as Health
	var lo := p.get_node("Loadout") as Loadout
	var rs := p.get_node("Respawner") as Respawner
	var stations := []
	for st: Station in get_tree().get_nodes_in_group("station"):
		var e := {"item": String(st.item.id), "pos": [st.global_position.x, st.global_position.y]}
		var f := st.furnace()
		if f:
			e["furnace"] = {
				"in": String(f.in_item.id) if f.in_item else "", "in_n": f.in_count,
				"out": String(f.out_item.id) if f.out_item else "", "out_n": f.out_count,
				"progress": f.progress, "smelted": f.smelted_total}
		stations.append(e)
	var drops := []
	for pk: Pickup in get_tree().get_nodes_in_group("pickup"):
		drops.append({"item": String(pk.item.id), "n": pk.amount, "pos": [pk.global_position.x, pk.global_position.y],
				"left": pk.despawn_left, "death": pk.death_drop, "scale": pk.scale.x})
	var held = null
	if inv.held_item != null:
		held = {"id": String(inv.held_item.id), "n": inv.held_count}
	var boss := _boss()
	return {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"play_time": play_time,
		"deaths": rs.deaths if rs else 0,
		"world": {
			"seed": m.current_seed,
			"obstacles": m.result.obstacles.size() if m.result else 0,   # a sanity check for the placement indices
			"map_settings": m.export_changes(),
			"broken": m.streamer_broken(),
			"stations": stations,
			"pickups": drops,
		},
		"player": {"pos": [p.global_position.x, p.global_position.y], "hp": health.hp, "selected_slot": lo.selected_slot},
		"inventory": inv.to_array(),
		"held": held,
		"boss_defeated": boss != null and boss.mode == Boss.Mode.DEAD,
	}

# ------------------------------------------------------------------ load

## Applies a save to THIS (fresh) arena, whose island was already rebuilt from the saved seed + settings.
func apply(d: Dictionary) -> void:
	var by_id := item_table()
	var p := _player()
	var m := _map()
	var w: Dictionary = d["world"]
	if m.current_seed != int(w["seed"]):
		push_warning("save: arena has island %d, the save is from %d" % [m.current_seed, int(w["seed"])])
	if m.result and int(w.get("obstacles", -1)) != m.result.obstacles.size():
		push_warning("save: the island has changed since this save (trees / rocks differ); gathered nodes are not restored")
	else:
		for idx in w.get("broken", []):
			m.mark_broken(int(idx))
	var pos := _vec(d["player"].get("pos"), p.global_position)
	m.teleport_player(pos)
	var health := p.get_node("Health") as Health
	health.hp = clampf(float(d["player"].get("hp", health.max_hp)), 1.0, health.max_hp)
	for pk: Pickup in get_tree().get_nodes_in_group("pickup"):
		pk.free()   # first: the cursor stack below may spill onto the ground and must survive
	var inv := p.get_node("Inventory") as Inventory
	inv.from_array(d["inventory"], by_id)
	var lo := p.get_node("Loadout") as Loadout
	lo.rearm()
	lo.select_instant(clampi(int(d["player"].get("selected_slot", 0)), 0, Inventory.HOTBAR - 1))
	var held = d.get("held")
	if held is Dictionary and by_id.has(str(held.get("id", ""))):
		inv.give_or_drop(by_id[str(held["id"])], int(held.get("n", 0)))
	for st: Station in get_tree().get_nodes_in_group("station"):
		st.free()   # the arena's own (none on a fresh one); the save is the whole truth
	for e in w.get("stations", []):
		_restore_station(e, by_id, p.get_parent())
	for e in w.get("pickups", []):
		if not by_id.has(str(e.get("item", ""))):
			continue
		var at := _vec(e.get("pos"), pos)
		var pk := Pickup.spawn(p.get_parent(), by_id[str(e["item"])], maxi(int(e.get("n", 1)), 1), at, at)
		pk.despawn_left = float(e.get("left", -1.0))
		pk.death_drop = bool(e.get("death", false))
		pk.scale = Vector2.ONE * float(e.get("scale", 1.0))
	var rs := p.get_node("Respawner") as Respawner
	rs.deaths = int(d.get("deaths", 0))
	play_time = float(d.get("play_time", 0.0))
	if bool(d.get("boss_defeated", false)) and _boss() != null:
		var bh := _boss().health
		bh.invulnerable = false
		bh.hp = 0.0
		bh.died.emit()
	last_result = "loaded"
	last_save_unix = 0

func _restore_station(e: Dictionary, by_id: Dictionary, parent: Node) -> void:
	var it: ItemData = by_id.get(str(e.get("item", "")))
	if it == null or it.placeable == null:
		push_warning("save: unknown station '%s' skipped" % str(e.get("item")))
		return
	var st: Station = it.placeable.instantiate()
	st.item = it
	parent.add_child(st)
	st.global_position = _vec(e.get("pos"), Vector2.ZERO)
	var fd = e.get("furnace")
	var f := st.furnace()
	if f and fd is Dictionary:
		f.in_item = by_id.get(str(fd.get("in", "")))
		f.in_count = int(fd.get("in_n", 0)) if f.in_item else 0
		f.out_item = by_id.get(str(fd.get("out", "")))
		f.out_count = int(fd.get("out_n", 0)) if f.out_item else 0
		f.progress = float(fd.get("progress", 0.0))
		f.smelted_total = int(fd.get("smelted", 0))
		f.changed.emit()

static func _vec(a, fallback: Vector2) -> Vector2:
	return Vector2(float(a[0]), float(a[1])) if a is Array and a.size() >= 2 else fallback

# ------------------------------------------------------------------ F3

func status_text() -> String:
	var size := 0
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		size = f.get_length() if f else 0
	var when := Time.get_datetime_string_from_unix_time(last_save_unix) if last_save_unix > 0 else "-"
	var left := autosave_left()
	return "file: %s  %s\nlast save: %s  (%s)\nautosave: %s  play time: %d s" % [
		path, "%d bytes" % size if size > 0 else "none", when, last_result,
		"in %.0f s" % left if left >= 0.0 else "off", int(play_time)]


# ---- F3 debug contract (tools/f3_mock/DESIGN.md "Extension contract")
func debug_name() -> String:
	return "Save"

func debug_category() -> String:
	return "Run"

func debug_actions() -> Array:
	return [
		{"label": "Save now", "run": save},
		{"label": "Load save", "run": func():   # same path as title Continue: the arena rebuilds the island, then applies the save
			var d := SaveGame.read_save()
			if d.is_empty():
				return
			SaveGame.begin_load(d)
			get_tree().reload_current_scene()},
		{"label": "Delete save", "danger": true, "run": SaveGame.delete_save},
	]
