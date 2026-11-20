extends SceneTree
## Full-screen HUD screenshots of the real arena (decision 0030):
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --script tools/hud_shots.gd -- <out_dir>
## Saves hud_layout.png (boss asleep: no boss bar), hud_bag_open.png, hud_tooltip.png,
## hud_starving.png (food 0, potion cooldown running in hud_layout), hud_f3_open.png, hud_boss_phase2.png (boss awake, phase 2, bottom centre), hud_boss_phase2_f3.png.
var _out := ""

func _init() -> void:
	_out = OS.get_cmdline_user_args()[0]
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	var boss: Boss = arena.get_node("Boss")
	boss.passive = true
	arena.get_node("DebugOverlay").enabled = false
	var player = arena.get_node("Player")
	var hp: Health = player.get_node("Health")
	var lo: Loadout = player.get_node("Loadout")
	var inv: Inventory = player.get_node("Inventory")
	var hud: HUD = arena.get_node("HUD")
	hp.immortal = true
	inv._insert(load("res://data/items/wood.tres"), 37, [3])   # hotbar slots 4 / 5, like the mock
	inv._insert(load("res://data/items/healing_potion.tres"), 12, [4])
	inv.add(load("res://data/items/stone.tres"), 12)
	inv.add(load("res://data/items/copper_ore.tres"), 3)
	var hunger: Hunger = player.get_node("Hunger")
	var consumer: Consumer = player.get_node("Consumer")
	await _frames(10)
	hp.hp = hp.max_hp * 0.7
	hunger.set_food(hunger.max_food * 0.55)
	consumer._cooldown_left = consumer.potion_cooldown * 0.4   # potion sweep: 12 s left
	await _frames(40)
	await _shot("hud_layout")
	hunger.set_food(0.0)
	await _frames(20)
	await _shot("hud_starving")
	hunger.set_food(hunger.max_food * 0.55)
	consumer._cooldown_left = 0.0
	hud.bag().toggle()
	await _frames(10)
	await _shot("hud_bag_open")
	var tip := hud.tooltip()
	tip.mouse_override = hud.bag().cells()[0].get_global_rect().get_center()
	await _frames(5)
	await _shot("hud_tooltip")
	tip.mouse_override = Vector2(2000, 2000)
	arena.get_node("TuningPanel").visible = true
	await _frames(10)
	await _shot("hud_f3_open")
	arena.get_node("TuningPanel").visible = false
	hud.bag().toggle()
	boss.set_physics_process(false)
	boss._set_aggro(Boss.Aggro.ENGAGED)
	boss.phase = 2
	boss.phase_changed.emit(2)
	boss.health.hp = boss.health.max_hp * 0.45
	await _frames(45)
	await _shot("hud_boss_phase2")
	arena.get_node("TuningPanel").visible = true
	await _frames(10)
	await _shot("hud_boss_phase2_f3")
	quit()

func _frames(n: int) -> void:
	await create_timer(n / 60.0).timeout

func _shot(name_: String) -> void:
	await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [_out, name_])
