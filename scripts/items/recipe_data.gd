class_name RecipeData
extends Resource
## One crafting recipe (decision 0031). Instant, Terraria-style. A new recipe is a new .tres in
## `data/recipes/`: the Crafter finds it by itself, zero code.

@export var result: ItemData
@export var result_count := 1
@export var ingredients: Array[IngredientData] = []
## Where it sits in the list (small = first). Files with the same number keep their file-name order.
@export var order := 0
## "" = by hand (anywhere), otherwise the CraftStation.station_id that must be within its craft_radius.
@export var station: StringName = &""

## Item name over the row (tooltip). The result is what the player sees.
func display_name() -> String:
	return result.display_name if result else ""
