class_name ItemPicker
extends Node
## Test yard item list (decision 0056): every item in data/items, handed to the crafting book as its Items tab (CraftWindow.set_catalog).
## Left click = a full stack, right click = 1, both into the inventory (what does not fit drops at the player).
## Made only by TestYard, so a normal run never has it. It draws nothing: the book does.

var items: Array[ItemData] = []
var last_taken := "none"
var _inv: Inventory
var _win: CraftWindow

const ORDER := ["weapon", "tool", "placeable", "material"]

## Every ItemData in `dir`, weapon / tool / placeable / material, then by name.
static func list_items(dir := "res://data/items") -> Array[ItemData]:
	var out: Array[ItemData] = []
	for r in RecipeBook.load_dir(dir):
		if r is ItemData:
			out.append(r)
	out.sort_custom(func(a: ItemData, b: ItemData) -> bool:
		var ca := ORDER.find(a.category)
		var cb := ORDER.find(b.category)
		return a.display_name.naturalnocasecmp_to(b.display_name) < 0 if ca == cb else ca < cb)
	return out

func bind(hud: HUD, inv: Inventory) -> void:
	_inv = inv
	_win = hud.craft_window()
	name = "ItemPicker"
	add_to_group("debug")
	items = list_items()
	_win.items_tab_icon = load("res://assets/ui/game/items_tab_icon.png")
	_win.set_catalog(items)
	_win.catalog_clicked.connect(_on_click)

## Left = a full stack, right = 1; the inventory drops what does not fit.
func _on_click(item: ItemData, button: int) -> void:
	var n := 0
	if button == MOUSE_BUTTON_LEFT:
		n = item.stack_limit()
	elif button == MOUSE_BUTTON_RIGHT:
		n = 1
	if n > 0:
		_inv.give_or_drop(item, n)
		last_taken = "%s x%d" % [item.display_name, n]

func debug_name() -> String:
	return "ItemPicker"

func debug_category() -> String:
	return "World"

func status_text() -> String:
	return "items %d  pages %d (shown %d)  tab %s\nlast taken: %s" % [items.size(), _win.catalog_pages(), _win.catalog_page() + 1, _win.current_tab(), last_taken]
