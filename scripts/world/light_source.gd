class_name LightSource
extends PointLight2D
## One light in the world (decision 0067). Instance scenes/world/light_source.tscn, then set the few knobs below.
##
## API (all plain properties, safe to set before or after add_child):
##   radius        px, how far the light reaches (setter rescales the soft circle texture)
##   base_energy   brightness at full strength (the node's own `energy` is driven by this, do not set `energy`)
##   color         tint (PointLight2D's own property)
##   flicker_amount 0..1 how much the brightness wobbles, flicker_speed Hz-ish
##   f3_label      "" = no F3 section (torches); a name ("Light campfire") = tunable live in F3
##   night_only    true = fades in over dusk, out over dawn, off (free) at full day; false = always on
## Example (torch): var l := preload("res://scenes/world/light_source.tscn").instantiate() as LightSource
##   l.radius = 160.0; l.color = Color(1, 0.7, 0.4); add_child(l)
## Looks live in the texture / PointLight2D, so a real light sprite or shader can replace them without touching this API.

const TEX_HALF := 128.0   ## half the size of the generated soft circle texture (256 px), for radius -> scale only

@export_range(8.0, 1200.0, 1.0, "or_greater") var radius := 160.0:
	set(v):
		radius = v
		texture_scale = v / TEX_HALF
@export_range(0.0, 4.0, 0.05) var base_energy := 1.0
@export_range(0.0, 1.0, 0.01) var flicker_amount := 0.0
@export_range(0.0, 30.0, 0.1) var flicker_speed := 8.0
@export var night_only := true

var level := 1.0   ## 0..1 how on it is now (F3)
var _clock: DayClock
var _t := 0.0

func _enter_tree() -> void:
	add_to_group("light_source")
	if f3_label != "":
		add_to_group("debug")

func _ready() -> void:
	texture_scale = radius / TEX_HALF
	_clock = get_tree().get_first_node_in_group("day_clock") as DayClock
	_t = randf() * 100.0   # lights do not flicker in step
	_update()

## Optional: a LightData this light mirrors every frame (item lights), so F3 edits on it show at once.
var data: LightData

func _process(delta: float) -> void:
	_t += delta
	if data != null:
		radius = data.radius
		color = data.color
		base_energy = data.energy
		flicker_amount = data.flicker_amount
		flicker_speed = data.flicker_speed
		night_only = data.night_only
	_update()

func _update() -> void:
	level = 1.0
	if night_only and _clock != null:
		level = _clock.light_level()
	enabled = level > 0.001   # a disabled PointLight2D costs nothing; the node (and its F1 circle) stays
	if not enabled:
		return
	var wobble := 1.0 - flicker_amount * 0.5 * (1.0 + sin(_t * flicker_speed * TAU * 0.25 + sin(_t * flicker_speed * 0.7) * 2.0))
	energy = base_energy * level * wobble

# ---- F3 / F1. F1 circles are drawn by the DebugOverlay (undarkened), which reads the "light_source" group.
## Named lights (campfire, player glow) get their own F3 section; unnamed ones (torches) get none.
@export var f3_label := ""   ## non-empty = this light gets an F3 section with that name (set it in the scene, before it enters the tree)

func debug_name() -> String:
	return f3_label

func debug_category() -> String:
	return "World"
