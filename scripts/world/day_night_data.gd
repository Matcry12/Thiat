class_name DayNightData
extends Resource
## All the numbers of the day / night cycle (decision 0067, docs/wiki/day-night-algorithm.md). One file: data/day_night/default.tres.
## Times are fractions of a day: 0 = midnight, 0.25 = 6:00, 0.5 = noon.

enum Phase { DAWN, DAY, DUSK, NIGHT }

@export_range(30.0, 7200.0, 1.0, "or_greater") var day_length_s := 720.0   ## real seconds for one full day
@export_range(0.0, 1.0, 0.005) var start_time := 0.30   ## a new game starts here (morning)
@export_group("Phases (fractions of the day)")
@export_range(0.0, 1.0, 0.001) var dawn_start := 0.20
@export_range(0.0, 1.0, 0.001) var day_start := 0.283
@export_range(0.0, 1.0, 0.001) var dusk_start := 0.783
@export_range(0.0, 1.0, 0.001) var night_start := 0.867
@export_group("Screen colour")
@export var tint: Gradient   ## x = time of day 0..1 (both ends = midnight), colour = what the CanvasModulate shows
@export_group("Lights")
@export_range(0.1, 4.0, 0.05) var light_fade_power := 1.0   ## 1 = straight ramp over dusk / dawn; >1 = lights stay low longer, <1 = come on sooner

func wrap_time(t: float) -> float:
	return fposmod(t, 1.0)

func phase_at(t: float) -> Phase:
	t = wrap_time(t)
	if t >= night_start or t < dawn_start:
		return Phase.NIGHT
	if t < day_start:
		return Phase.DAWN
	if t < dusk_start:
		return Phase.DAY
	return Phase.DUSK

## Time a phase begins.
func phase_start(p: Phase) -> float:
	match p:
		Phase.DAWN: return dawn_start
		Phase.DAY: return day_start
		Phase.DUSK: return dusk_start
	return night_start

func tint_at(t: float) -> Color:
	return tint.sample(wrap_time(t)) if tint != null else Color.WHITE

## 0 = full day (lights off), 1 = full night (lights on); ramps over dusk and over dawn.
func light_level(t: float) -> float:
	t = wrap_time(t)
	var f := 0.0
	match phase_at(t):
		Phase.NIGHT: f = 1.0
		Phase.DUSK: f = (t - dusk_start) / maxf(night_start - dusk_start, 0.0001)
		Phase.DAWN: f = 1.0 - (t - dawn_start) / maxf(day_start - dawn_start, 0.0001)
	return pow(clampf(f, 0.0, 1.0), light_fade_power)
