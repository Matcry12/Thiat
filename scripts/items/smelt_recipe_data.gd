class_name SmeltRecipeData
extends Resource
## One furnace recipe: `input` becomes `output` after `smelt_time` seconds per item (decision 0031).
## A new one is a new .tres in `data/smelting/`.

@export var input: ItemData
@export var output: ItemData
@export var output_count := 1
@export var smelt_time := 3.0
