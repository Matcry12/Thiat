class_name LightData
extends Resource
## A light an item gives off, held in the hand or placed in the world (decision 0067). Data only: a lantern
## is a new .tres with a `light` set on its ItemData, no code.

@export var radius := 160.0   ## px
@export var color := Color(1.0, 0.7, 0.4)
@export_range(0.0, 4.0, 0.05) var energy := 1.0
@export_range(0.0, 1.0, 0.01) var flicker_amount := 0.15
@export_range(0.0, 30.0, 0.1) var flicker_speed := 8.0
@export var night_only := true
## Where the light sits relative to the carrier (the flame), px.
@export var offset := Vector2.ZERO

func make() -> LightSource:
	var l := preload("res://scenes/world/light_source.tscn").instantiate() as LightSource
	l.name = "ItemLight"
	l.radius = radius
	l.color = color
	l.base_energy = energy
	l.flicker_amount = flicker_amount
	l.flicker_speed = flicker_speed
	l.night_only = night_only
	l.position = offset
	l.data = self   # live: an F3 edit of this resource moves every torch at once
	return l
