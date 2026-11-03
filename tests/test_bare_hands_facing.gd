extends SceneTree
# Decision 0055: bare hands never attack; the body faces the move direction, the mouse for face_mouse_hold s after an action.
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await physics_frame

func _init() -> void:
	var arena = await World.make(self)
	var player = arena.get_node("Player")
	var lo: Loadout = player.get_node("Loadout")
	player.set_physics_process(true)
	player.face_mouse_hold = 0.2
	player.aim_override = Vector2.LEFT   # the "mouse" is on the left
	var tree: ResourceNode = load("res://scenes/world/resource_node.tscn").instantiate()
	tree.setup(load("res://data/resource_nodes/tree.tres"), 0)
	tree.global_position = player.global_position + Vector2(-40, 0)
	arena.add_child(tree)
	await _frames(2)
	# empty slot (7): attack does nothing
	lo.select(7)
	_check(not lo.can_attack(), "empty slot cannot attack")
	Input.action_press("attack")
	await _frames(12)
	Input.action_release("attack")
	_check(player.weapon_holder.phase == WeaponHolder.Phase.IDLE, "empty slot + attack: no swing phase")
	_check(tree.hp == tree.data.max_hp, "empty slot + attack: tree hp unchanged")
	# move right, mouse left, no action -> faces move
	Input.action_press("move_right")
	await _frames(3)
	_check(not player.visual.is_facing_left(), "moving right, mouse left, no action: faces right")
	_check(player.status_text().contains("facing src: move"), "status: facing src move")
	_check(absf(player.weapon_visual.aim_angle) < 0.1, "pose points right (body), not at the mouse")
	# sword attack -> faces mouse
	lo.select(0)
	await _frames(2)
	_check(lo.can_attack(), "sword can attack")
	Input.action_press("attack")
	await _frames(3)
	Input.action_release("attack")
	_check(player.visual.is_facing_left(), "attack: faces the mouse (left)")
	_check(player.status_text().contains("facing src: mouse"), "status: facing src mouse")
	_check(player.weapon_visual.visible, "in use: held weapon shown")
	# hold elapses while still moving right
	await _frames(90)
	_check(not player.visual.is_facing_left(), "after face_mouse_hold: faces move dir again")
	_check(not player.weapon_visual.visible, "after face_mouse_hold: held weapon hidden")
	# walking straight down keeps the last side and a flat pose (left / right only)
	Input.action_release("move_right")
	Input.action_press("move_down")
	await _frames(5)
	Input.action_release("move_down")
	_check(not player.visual.is_facing_left(), "walking down keeps facing right")
	_check(absf(player.weapon_visual.aim_angle) < 0.1, "walking down: pose stays flat right, not down")
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)
