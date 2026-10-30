extends SceneTree
# Tall floor props (bushes ...) are Y-sorted sprites under the obstacles root (the player can stand behind them); short ones stay in the MultiMesh.
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.get_node("ArenaMap").style.pixel_plains = null   # these tests count trees and deco: the old ground look keeps them (Pixel Plains hides both)
	root.add_child(arena)
	arena.get_node("Boss").passive = true
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var obs := m.obstacles_root()
	_props_check(m, obs)

func _props_check(m: ArenaMap, obs: Node2D) -> void:
	var tall := 0
	for c in obs.get_children():
		if c is Sprite2D and c.name.begins_with("Prop"):
			tall += 1
			if c.region_rect.size.y <= m.ysort_min_px:
				print("FAIL short prop in the sorted layer")
				quit(1)
				return
	var mm_tall := 0
	var mm_all := 0
	for id in m.streamer().loaded:
		var ch: ChunkStreamer.Chunk = m.streamer().loaded[id]
		if ch.deco != null:
			for mmi in ch.deco.get_children():
				mm_all += (mmi as MultiMeshInstance2D).multimesh.instance_count
	var ok := tall > 0 and mm_all > 0 and obs.y_sort_enabled
	print(("ok   " if ok else "FAIL ") + "%d tall props are Y-sorted sprites, %d short ones in the MultiMesh" % [tall, mm_all])
	# the chunk frees them: unloading everything leaves none
	m.streamer().reset()
	var left := 0
	for c in obs.get_children():
		if c is Sprite2D and c.name.begins_with("Prop") and not c.is_queued_for_deletion():
			left += 1
	ok = ok and left == 0
	print(("ok   " if left == 0 else "FAIL ") + "reset frees the tall props (%d left)" % left)
	quit(0 if ok else 1)
