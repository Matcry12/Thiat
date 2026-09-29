extends Brain
class_name ScriptedBrain
## Hand-written boss brain: picks at random among the attacks that are off
## cooldown, unlocked by phase and in the right range. Stays as the baseline
## opponent even after an RL brain exists.

@export var slam_max_range := 320.0
@export var ring_max_range := 320.0
@export var spread_min_range := 100.0
@export var charge_min_range := 100.0
## Keeps this far from the player: inside every attack's range at once.
@export var chase_stop_range := 250.0

## Seedable, so a test can replay a fight. Not an @export: code owns it.
var rng := RandomNumberGenerator.new()

func choose_action(state: Dictionary) -> String:
	# Enraged (player left the fight zone): keep charging until they return.
	var cd: Dictionary = state["cooldowns"]
	if state["enraged"]:
		return "charge" if _off_cd(cd, "charge") else "chase"   # never stand still
	var dist: float = state["player_distance"]
	var options: Array[String] = []
	if state["phase"] >= 2 and _off_cd(cd, "ring") and dist <= ring_max_range:
		options.append("ring")
	if _off_cd(cd, "slam") and dist <= slam_max_range:
		options.append("slam")
	if _off_cd(cd, "spread") and dist >= spread_min_range:
		options.append("spread")
	if _off_cd(cd, "charge") and dist >= charge_min_range:
		options.append("charge")
	if not options.is_empty():
		return options[rng.randi() % options.size()]
	return "chase" if dist > chase_stop_range else "idle"

func _off_cd(cd: Dictionary, action: String) -> bool:
	return cd.has(action) and cd[action] <= 0.0
