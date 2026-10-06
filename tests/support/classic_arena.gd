extends RefCounted
## The old screen-sized arena layout (zone in the middle, player inside it, boss to the right), for
## tests and demos whose coordinates were written for it. The shipped layout is the big map
## (decision 0021 / 0022); this is the same scene with the ArenaMap exports set back.
static func make() -> Node:
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	var m = arena.get_node("ArenaMap")
	m.island_on = false
	m.map_cols = 36
	m.map_rows = 21
	m.zone_x = 0.5
	m.zone_y = 324.0 / 672.0   # 21 rows x 32 = 672 px (the old screen was 648)
	m.boss_offset_x = 384.0
	m.player_spawn_x = 409.0 / 1152.0
	m.player_spawn_y = 321.0 / 672.0
	m.dummy_offset_x = 291.0
	m.dummy_offset_y = -191.0
	return arena
