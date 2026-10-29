extends SceneTree
# Island Workshop judge fixes: the Craft button tells what the Crafter will do (cursor, stack limits), the quantity resets
# on a new recipe, the menu outline follows focus, an empty skin texture never spams script errors, the hotbar hides
# while paused. Run: godot --headless --script tests/test_ui_truth.gd
const World = preload("res://tests/support/craft_world.gd")
var _ok := true

class Catch extends Logger:
	var errs: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		errs.append("%s:%d %s %s" % [file, line, code, rationale])
	func _log_message(_message: String, _error: bool) -> void:
		pass

func _check(cond: bool, msg: String) -> void:
	print(("ok   " if cond else "FAIL ") + msg)
	if not cond:
		_ok = false

func _frames(n := 3) -> void:
	for i in n:
		await process_frame

func _idx(win: CraftWindow, id: StringName) -> int:
	for i in win.shown_recipes().size():
		if win.shown_recipes()[i].result.id == id:
			return i
	return -1

func _init() -> void:
	var arena = await World.make(self, Vector2i(1152, 648))
	var player: Node2D = arena.get_node("Player")
	var inv: Inventory = player.get_node("Inventory")
	var cr: Crafter = player.get_node("Crafter")
	var hud: HUD = arena.get_node("HUD")
	var win := hud.craft_window()
	var sk := win.get_skin()
	World.station(arena, "workbench", player.global_position + Vector2(40, 0))
	inv.add(World.item("wood"), 60)
	inv.add(World.item("stone"), 60)
	hud.bag().toggle()
	await _frames()

	# --- Craft button = the Crafter's answer ---
	var pick := _idx(win, &"stone_pickaxe")
	var axe := _idx(win, &"stone_axe")
	win.select_recipe(pick)
	for i in 4:
		win._plus.pressed.emit()
	await _frames(2)
	var r := win.selected_recipe()
	_check(win.quantity() == 5 and cr.craftable_count(r) == 1 and not win.craft_enabled(), "pickaxe x5: stack 1, the Crafter can do 1 -> Craft dark (it used to light and make 1)")
	_check(not win.craft_selected(false) and inv.held_item == null, "...and pressing it asks for nothing")
	_check(cr.craftable_count(r, false) >= 5, "shift (straight to the bag) has no stack limit: 5 are possible")
	win.select_recipe(axe)
	_check(win.quantity() == 1, "choosing another recipe resets the quantity to 1")
	await _frames(2)
	_check(win.craft_enabled() and win.craft_selected(false) and inv.held_item != null and inv.held_item.id == &"stone_axe", "axe x1: lit, lands on the cursor")
	win.select_recipe(pick)
	await _frames(2)
	_check(not win.craft_enabled() and cr.craftable_count(win.selected_recipe()) == 0, "holding an axe: the pickaxe button is dark (cursor busy)")
	_check(win.craft_selected(true) and inv.count(&"stone_pickaxe") == 1, "shift + Craft still works (straight into the bag)")
	inv.return_held()
	var wb := _idx(win, &"workbench")
	win.select_recipe(wb)
	win._plus.pressed.emit()
	win._plus.pressed.emit()
	await _frames(2)
	var made := win.quantity() * win.selected_recipe().result_count
	_check(win.craft_enabled() and win.craft_selected(false) and inv.held_count == made, "stackable x3: lit, and the cursor holds exactly 'makes N' (%d)" % made)
	inv.return_held()

	# --- menu outline follows focus (A -> B) ---
	var ms := MenuScreen.new()
	ms.style = MenuScreen.Style.PAUSE
	ms.items = [{"text": "One", "cb": func(): pass}, {"text": "Two", "cb": func(): pass}]
	root.add_child(ms)
	await _frames()
	var a := ms.button("One")
	var b := ms.button("Two")
	a.grab_focus()
	await _frames()
	_check(a.get_theme_color("font_outline_color") == sk.pal_line and b.get_theme_color("font_outline_color") == sk.text_outline_color, "A focused: A hot, B plain")
	b.grab_focus()
	await _frames()
	_check(a.get_theme_color("font_outline_color") == sk.text_outline_color and b.get_theme_color("font_outline_color") == sk.pal_line, "focus A -> B: A back to plain, B hot (no frame behind)")
	sk.text_outline_color = Color(1, 0, 0)
	await _frames(3)
	var b2 := ms.button("Two")
	_check(b2 != b and ms.button("One").get_theme_color("font_outline_color") == Color(1, 0, 0), "a skin edit rebuilds the menu")
	sk.text_outline_color = Color8(84, 48, 46)
	ms.queue_free()
	await _frames(3)

	# --- the hotbar hides while paused ---
	hud.bag().close()
	var pm: PauseMenu = arena.get_node("PauseMenu")
	await _frames()
	_check(hud.hotbar().visible, "before the pause menu: hotbar shows")
	pm.pause()
	await _frames()
	_check(not hud.hotbar().visible, "paused: the hotbar hides")
	pm.resume()
	await _frames()
	_check(hud.hotbar().visible, "resumed: it is back")

	# --- an empty texture slot never spams script errors ---
	var catcher := Catch.new()
	OS.add_logger(catcher)
	var saved := {}
	var tex_props: Array[String] = []
	for pr in sk.get_property_list():
		if pr["type"] == TYPE_OBJECT and pr["hint_string"] == "Texture2D" and (pr["usage"] & PROPERTY_USAGE_EDITOR):
			tex_props.append(pr["name"])
			saved[pr["name"]] = sk.get(pr["name"])
	_check(tex_props.size() > 40, "found the skin's texture slots (%d)" % tex_props.size())
	var boss_bar: BossBar
	for n in hud.find_children("*", "BossBar", true, false):
		boss_bar = n
	var fade := sk.boss_fade_time
	sk.boss_fade_time = 0.001
	for pass_no in 2:
		for n in tex_props:
			sk.set(n, null if (pass_no == 1 or n != "slot_idle_tex") else saved[n])
		boss_bar.set_awake(true)
		hud.bag().toggle()
		await _frames(6)
		hud.bag().close()
		var sc2 := MenuScreen.new()
		sc2.items = [{"text": "Play", "cb": func(): pass}, {"text": "Settings", "settings": true}, {"text": "Off", "enabled": false, "cb": func(): pass}]
		root.add_child(sc2)
		await _frames(2)
		sc2.show_settings()
		await _frames(3)
		sc2.queue_free()
		await _frames(2)
		for n in tex_props:
			sk.set(n, saved[n])
		await _frames(2)
	sk.boss_fade_time = fade
	OS.remove_logger(catcher)
	_check(catcher.errs.is_empty(), "every skin texture emptied (art mode and legacy): no script error in HUD, book, menus (%s)" % [catcher.errs.slice(0, 3)])
	quit(0 if _ok else 1)
