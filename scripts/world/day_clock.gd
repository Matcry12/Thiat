class_name DayClock
extends Node
## The one owner of time of day (decision 0067). Everything else (screen tint, lights, later night monsters / hunger) only reads it.
## `time` 0..1 (0 = midnight, 0.5 = noon), `day_count` starts at 1. Listen to `phase_changed`, ask `is_night()`.
## Frozen by default in test runs (BOSSFIGHT_TEST_SEED set, like SaveGame / EnemySpawner); a test sets `frozen = false`.

signal phase_changed(phase: DayNightData.Phase)

@export var data: DayNightData
@export_range(0.0, 200.0, 0.1, "or_greater") var time_scale := 1.0   ## F3: 60 = a day in 12 s
@export var frozen := OS.get_environment("BOSSFIGHT_TEST_SEED") != ""

var time := 0.0
var day_count := 1
var phase := DayNightData.Phase.DAY

func _enter_tree() -> void:
	add_to_group("day_clock")   # before any _ready: the HUD dial and the tint look for it while they build
	add_to_group("debug")

func _ready() -> void:
	if data == null:
		data = load("res://data/day_night/default.tres")
	time = data.start_time
	phase = data.phase_at(time)

func _process(delta: float) -> void:
	if frozen or time_scale <= 0.0:
		return
	advance(delta * time_scale / maxf(data.day_length_s, 1.0))

## Moves time forward by a fraction of a day (wraps at midnight, counting the day).
func advance(fraction: float) -> void:
	set_time(time + fraction)

## Jump to `t` (any value; forward past 1.0 counts days). Emits phase_changed if the phase differs.
func set_time(t: float) -> void:
	day_count += int(floorf(t))
	time = fposmod(t, 1.0)
	_update_phase()

## Skip forward to the start of a phase (a day is counted if that means passing midnight).
func skip_to(p: DayNightData.Phase) -> void:
	var target := data.phase_start(p)
	if target <= time:
		day_count += 1
	time = target   # exact: 1.2 wrapped back is 0.19999..., which would still be night
	_update_phase()

## Load: absolute time + day, no day counting.
func restore(t: float, days: int) -> void:
	day_count = maxi(days, 1)
	time = fposmod(t, 1.0)
	_update_phase()

func _update_phase() -> void:
	var p := data.phase_at(time)
	if p != phase:
		phase = p
		phase_changed.emit(p)

func is_night() -> bool:
	return phase == DayNightData.Phase.NIGHT

## 0..1: how much night lights should burn now (ramps over dusk / dawn).
func light_level() -> float:
	return data.light_level(time)

func tint_color() -> Color:
	return data.tint_at(time)

func phase_name() -> String:
	return DayNightData.Phase.keys()[phase].capitalize()

## "07:12" (time * 24 h).
func clock_text() -> String:
	var m := int(time * 1440.0)
	return "%02d:%02d" % [m / 60, m % 60]

# ---- F3 debug contract
func debug_name() -> String:
	return "DayClock"

func debug_category() -> String:
	return "World"

func debug_children() -> Array:
	return [{"name": "DayNightData", "object": data}]

func debug_actions() -> Array:
	return [
		{"label": "Skip to dawn", "run": skip_to.bind(DayNightData.Phase.DAWN)},
		{"label": "Skip to day", "run": skip_to.bind(DayNightData.Phase.DAY)},
		{"label": "Skip to dusk", "run": skip_to.bind(DayNightData.Phase.DUSK)},
		{"label": "Skip to night", "run": skip_to.bind(DayNightData.Phase.NIGHT)},
		{"label": "Freeze time", "toggle": func() -> bool: return frozen, "run": func(): frozen = not frozen},
	]

func status_text() -> String:
	var lights := get_tree().get_nodes_in_group("light_source")
	var on := 0
	for l: LightSource in lights:
		if l.enabled:
			on += 1
	return "%s  %s  day %d\nlights on %d / %d  level %.2f\ntime_scale %.1f  %s" % [
		clock_text(), phase_name(), day_count, on, lights.size(), light_level(), time_scale, "FROZEN" if frozen else "running"]
