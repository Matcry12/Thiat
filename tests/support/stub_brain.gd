extends Brain
## Test brain: always returns `answer`, and remembers what it was asked.
## Proves the boss works with ANY Brain (decision 0019).
var answer := "idle"
var calls := 0
var last_state := {}

func choose_action(state: Dictionary) -> String:
	calls += 1
	last_state = state
	return answer
