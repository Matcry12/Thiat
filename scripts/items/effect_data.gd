class_name EffectData
extends Resource
## One kind of timed effect (food-algorithm.md rule 2). Data only: a new effect = a new .tres. The `Effects` node reads the numbers.

@export var id: StringName
@export var display_name := ""
@export var icon: Texture2D   ## HUD effect icon; null until the art exists
@export var is_debuff := false
## Regen: hp per second, per level (Regen II = 2x).
@export var hp_per_level_per_s := 0.0
## Sick-like debuffs: walk speed multiplier (1 = none).
@export_range(0.05, 1.0, 0.01) var speed_mult := 1.0
