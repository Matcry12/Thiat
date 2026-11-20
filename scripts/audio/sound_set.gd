class_name SoundSet
extends Resource
## How ONE material / thing sounds (data/sounds/<id>.tres; sound-algorithm.md). Every node, weapon, enemy, station
## points at one set; SoundBoard plays a slot of it. A slot left empty is silent on purpose.

const DIR := "res://data/sounds"
## Legal slot names (`break` is a GDScript keyword, so that slot is `break_`).
const SLOTS: Array[StringName] = [&"hit", &"break_", &"wrong_tool", &"place", &"swing", &"block", &"parry", &"phase", &"hit_charged", &"eat", &"drink", &"gulp"]

@export var id: StringName = &""
## Something hits this thing (node chopped, slime / boss / player hurt). On a weapon's set: its own impact (arrows).
@export var hit: SoundCue
## This thing breaks / dies / is picked up.
@export var break_: SoundCue
## Hit with a tool that is too weak (stations: the dull knock).
@export var wrong_tool: SoundCue
@export var place: SoundCue
## Weapon / tool swung or shot (empty until there are whoosh files).
@export var swing: SoundCue
@export var block: SoundCue
@export var parry: SoundCue
## Boss enters a new phase.
@export var phase: SoundCue
## A charged arrow lands (bow set).
@export var hit_charged: SoundCue
## Player eating: chew (repeats while holding), sip (potions), swallow (one eat finished).
@export var eat: SoundCue
@export var drink: SoundCue
@export var gulp: SoundCue

## The cue in `slot`, or null when empty / unknown.
func cue(slot: StringName) -> SoundCue:
	if not SLOTS.has(slot):
		return null
	var c := get(slot) as SoundCue
	return c if c != null and c.stream != null else null

## The set a node uses: its own `sound_set`, else its `data.sound_set` (ResourceNode, Enemy). Null = none.
static func of(node: Object) -> SoundSet:
	if node == null or not is_instance_valid(node):
		return null
	var s := node.get("sound_set") as SoundSet
	if s == null:
		var d: Object = node.get("data") as Object
		if d != null:
			s = d.get("sound_set") as SoundSet
	return s

## Every set in data/sounds/ (F3 sections, tests).
static func all() -> Array[SoundSet]:
	var out: Array[SoundSet] = []
	var names := PackedStringArray()
	for f in DirAccess.get_files_at(DIR):
		names.append(f.trim_suffix(".remap"))
	names.sort()
	for f in names:
		if f.ends_with(".tres"):
			var s := load(DIR + "/" + f) as SoundSet
			if s != null:
				out.append(s)
	return out

# ---- F3: one section per cue (the board lists the sets)
func debug_children() -> Array:
	var out: Array = []
	for slot in SLOTS:
		var c := get(slot) as SoundCue
		if c != null:
			out.append({"name": "Sound %s %s" % [id, String(slot).trim_suffix("_")], "object": c})
	return out
