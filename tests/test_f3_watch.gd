extends SceneTree
# F3 status view + watch card + toast: providers listed, only open/pinned ones evaluated, pin sorts first,
# card is click-through, toast hides on time and stays clear of the dock and the boss bar zone.
const StatusView := preload("res://scripts/debug/f3/f3_status_view.gd")
const WatchCard := preload("res://scripts/debug/f3/f3_watch_card.gd")
const Toast := preload("res://scripts/debug/f3/f3_toast.gd")
var _ok := true

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _all_ignore(n: Node) -> bool:
	if n is Control and n.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		return false
	for c in n.get_children():
		if not _all_ignore(c):
			return false
	return true

func _init() -> void:
	var screen := SubViewport.new()
	screen.size = Vector2i(1152, 648)
	root.add_child(screen)
	var calls := {"A": 0, "B": 0, "C": 0}
	var mk := func(n: String): return {"name": n, "text": func():
		calls[n] += 1
		return "%s line one\n%s detail two which is long enough to need wrapping when the column is narrow" % [n, n]}
	var view := StatusView.new()
	view.custom_minimum_size = Vector2(360, 300)
	screen.add_child(view)
	view.refresh_rate = 100.0
	view.set_providers([mk.call("A"), mk.call("B"), mk.call("C")])
	var pins := []
	view.pinned_changed.connect(func(n): pins.assign(n))
	await _frames(5)
	_check(view.row_names() == ["A", "B", "C"], "lists the 3 providers")
	_check(calls.A + calls.B + calls.C == 0, "closed + unpinned: no text call")
	view.toggle_open("B")
	var calls_b: int = calls.B
	await _frames(5)
	_check(calls.B > calls_b and calls.A == 0 and calls.C == 0, "only the open block is evaluated")
	var detail: Label = view._rows["B"].detail
	_check(detail.visible and detail.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART and "detail two" in detail.text, "expand shows wrapped detail")
	_check(view._rows["B"].summary.text.contains("B line one") and not view._rows["B"].summary.text.contains("detail"), "summary = first line")
	view.toggle_pin("C")
	await _frames(5)
	_check(view.row_names() == ["C", "A", "B"] and pins == ["C"], "pin sorts first + emits pinned_changed")
	_check(calls.C > 0 and calls.A == 0, "pinned block is evaluated, others not")
	view.toggle_open("B")
	var cb: int = calls.B
	await _frames(5)
	_check(calls.B == cb, "closing stops evaluation")
	_check(view.pinned_blocks().size() == 1 and view.pinned_blocks()[0].name == "C", "pinned_blocks feeds the card")

	var card := WatchCard.new()
	screen.add_child(card)
	card.set_span(1152.0 - 380.0)
	card.set_blocks(view.pinned_blocks())
	card.set_override_count(3)
	await _frames(3)
	_check(card.visible and "C line one" in card.shown_text() and "3 F3 overrides" in card.shown_text(), "card shows pinned text + override line")
	card.set_override_count(0)
	_check(not ("overrides" in card.shown_text()), "no override line at 0")
	card.set_blocks([])
	_check(not card.visible, "empty card hides")
	card.set_blocks(view.pinned_blocks())
	card.set_override_count(2)
	await _frames(3)
	_check(_all_ignore(card), "card is click-through (mouse_filter IGNORE, recursive)")
	_check(card.get_global_rect().end.x <= 1152.0 - 380.0 and card.get_global_rect().position.x >= card.min_left, "card between hotbar and dock")

	var toast := Toast.new()
	screen.add_child(toast)
	await _frames(2)
	_check(not toast.visible, "toast starts hidden")
	toast.show_toast("3 F3 overrides applied - 1 stale skipped", 0.15, 380.0)
	await _frames(3)
	var r: Rect2 = toast.get_global_rect()
	_check(toast.visible, "toast appears")
	_check(r.end.x <= 1152.0 - 380.0 and absf(r.get_center().x - (1152.0 - 380.0) * 0.5) < 2.0, "top-centre of the area left of the dock")
	_check(_all_ignore(toast), "toast passes the mouse")
	var boss_zone := Rect2(1152.0 * 0.2, 648.0 - 12.0 - 20.0, 1152.0 * 0.6, 20.0)
	_check(not r.intersects(boss_zone), "clear of the boss-bar zone")
	_check(not r.intersects(card.get_global_rect()), "clear of the watch card")
	var n := 0
	while toast.visible and n < 200:
		await process_frame
		n += 1
	_check(not toast.visible, "toast hides after its time")
	quit(0 if _ok else 1)
