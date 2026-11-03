class_name SlimeBrain
extends Brain
## Slime decisions (decision 0052). Asks one question: what now? Pure: no node access, no numbers of its own.
## state keys: player_distance (-1 = no live player), home_distance, aggro_radius, leash_radius, returning, can_attack.
## Answers: "return" | "attack" | "wander" | "idle".
func choose_action(state: Dictionary) -> String:
	var home_d: float = state["home_distance"]
	var pd: float = state["player_distance"]
	if home_d > state["leash_radius"] or (state["returning"] and home_d > 6.0):
		return "return"
	if pd >= 0.0 and pd <= state["aggro_radius"]:
		return "attack" if state["can_attack"] else "idle"
	return "wander"
