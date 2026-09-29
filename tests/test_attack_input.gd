extends SceneTree
# Headless: does pressing the `attack` action actually start a swing?
func _init():
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("Boss").passive = true   # quiet arena: these tests are not about the boss
	await process_frame
	var holder = arena.get_node("Player/WeaponHolder")
	print("idle at start: ", holder.phase == 0)
	Input.action_press("attack")
	await physics_frame
	await physics_frame
	Input.action_release("attack")
	var started = holder.phase != 0
	print("after attack press, phase=", holder.phase, " started=", started)
	quit(0 if started else 1)
