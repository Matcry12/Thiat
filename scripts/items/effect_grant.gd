class_name EffectGrant
extends Resource
## What an item gives when used: one effect, a strength level and a time (food-algorithm.md rule 2).

@export var effect: EffectData
@export var level := 1
@export var duration := 10.0   ## s
