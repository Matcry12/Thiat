extends SceneTree
## Demo clip: the 8 ground cases (labelled, slow pan) then trees / flowers / hedges in the real arena (3 biomes, one chop).
##   BOSSFIGHT_TEST_SEED=11 xvfb-run -a godot --rendering-driver opengl3 --resolution 1152x648 --write-movie <out>.avi --fixed-fps 30 --script tools/ground_case_demo.gd
const FPS := 30
const CASES := [["step_beach", "1 beach step: grass > sand > water"], ["flat_desert", "2 sand biome, flat: sand = grass"],
	["flat_beach", "3 flat beach with foam: sand = water"], ["sand_bank", "4 sand bank in water"], ["snow_flat", "5 snowy biome, flat: snow = grass"],
	["snow_on_grass", "6 snow on top (biome edge)"], ["mixed_coast", "7 mixed coast / 3-way corner"], ["grass_on_water", "8 water bank band"]]
const BIOMES := ["plains", "forest", "autumn"]
var _label: Label

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _init() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 7)
	_label.position = Vector2(480, 10)
	layer.add_child(_label)
	root.add_child(layer)
	for c in CASES:
		var g: GroundCase = load("res://tools/ground_case_scene.tscn").instantiate()
		g.case_name = c[0]
		g.zoom = 5.0
		root.add_child(g)
		_label.text = c[1]
		await process_frame
		var cam: Camera2D = g.find_children("*", "Camera2D", true, false)[0]
		var x0 := cam.position.x
		for f in int(3.6 * FPS):
			cam.position.x = x0 + (f - 54) * 0.5   # slow drift, +-27 px
			await process_frame
		g.queue_free()
		await process_frame
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	arena.get_node("DebugOverlay").enabled = false
	var player: CharacterBody2D = arena.get_node("Player")
	player.get_node("Health").immortal = true
	arena.get_node("Boss").passive = true
	var map: ArenaMap = arena.get_node("ArenaMap")
	map.camera_zoom = 2.0
	await _frames(20)
	var spots := _spots(map)
	for i in BIOMES.size():
		if not spots.has(BIOMES[i]):
			continue
		_label.text = "9 trees / flowers / hedges: " + BIOMES[i]
		var at: Vector2 = spots[BIOMES[i]]
		player.global_position = at - Vector2(160, 0)
		player.get_node("Camera").reset_smoothing()
		await _frames(45)   # chunks load
		for f in int(5.0 * FPS):
			player.global_position = at - Vector2(160, 0) + Vector2(f * 2.0, 0)
			player.get_node("Camera").reset_smoothing()
			if BIOMES[i] == "forest" and f == 100:   # a chop: every loaded oak leaves its stump
				_label.text = "9 chopped oaks leave the pack stump: forest"
				for n in arena.find_children("*", "ResourceNode", true, false):
					if String(n.data.id).begins_with("treepp"):
						n.get_node("Visual").show_remains(n.data)
			await process_frame
	quit()


## Busiest 6x6-cell block of each wanted biome (oaks + plants), px.
func _spots(map: ArenaMap) -> Dictionary:
	var res := map.result
	var cell := map.cell_px()
	var score := {}
	var items: Array[Vector2] = []
	var wts: Array[int] = []
	for o in res.obstacles:
		if o["node"] >= 0 and String(map.style.resource_nodes[o["node"]].id).begins_with("treepp"):
			items.append(o["pos"])
			wts.append(3)
	for d in res.deco:
		items.append(d["pos"])
		wts.append(1)
	for k in items.size():
		var c := Vector2i(items[k] / cell)
		var ci := c.y * res.cols + c.x
		if ci < 0 or ci >= res.biome.size():
			continue
		var s: Dictionary = score.get_or_add(int(res.biome[ci]), {})
		var key := Vector2i(c.x / 6, c.y / 6)
		s[key] = s.get(key, 0) + wts[k]
	var out := {}
	for b in score:
		var top := 0
		for key in score[b]:
			if score[b][key] > top:
				top = score[b][key]
				out[map.style.biomes[b].label] = (Vector2(key) * 6.0 + Vector2(3, 3)) * cell
	return out
