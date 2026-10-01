extends Node
class_name Brain
## The boss's decision-maker (prototype-v0 §4 rule 3). boss.gd builds a plain
## `state` Dictionary and asks ONE question: what do I do next? The answer is
## an action name: an attack ("slam", "spread", "charge", "ring"), "chase" or
## "idle". An RL brain later answers the same question from a trained policy.
## boss.gd never names a concrete brain class, so swapping is a drop-in.
##
## state keys: hp_fraction, phase, player_distance, player_angle,
## player_weapon, cooldowns ({action: seconds left}).
func choose_action(_state: Dictionary) -> String:
	return "idle"
