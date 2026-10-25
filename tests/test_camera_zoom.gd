extends SceneTree
# + / - zoom: zoom_by steps the target, clamps at zoom_min / zoom_max, and the camera glides to it.
func _init() -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var m: ArenaMap = arena.get_node("ArenaMap")
	var ok := true
	m.zoom_by(20)
	ok = ok and m.camera_zoom == m.zoom_max
	m.zoom_by(-40)
	ok = ok and m.camera_zoom == m.zoom_min
	m.zoom_by(1)
	for i in 120:
		await process_frame
	var cam := arena.get_node("Player/Camera") as Camera2D
	ok = ok and absf(cam.zoom.x - m.camera_zoom) < 0.01
	print("camera zoom: ", "PASS" if ok else "FAIL", " (zoom %.2f target %.2f)" % [cam.zoom.x, m.camera_zoom])
	quit(0 if ok else 1)
