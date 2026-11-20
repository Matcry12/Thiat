@tool
extends Resource
class_name EatingData
## Everything about eating / drinking that is a number or a picture: timings (Consumer) and crumbs (EatCrumbs).
## One .tres (`data/food/eating.tres`): F3 "Write to .tres" keeps the tuning. Sounds live in the SoundSet cues.

@export_group("Timing")
## s the attack button is held to eat / drink one item.
@export var eat_time := 1.6
## s pause between two eats while the button stays held (no bob / crumbs).
@export var eat_gap := 0.5
## s between chew / sip sounds while eating.
@export var eat_sound_every := 0.25
## Walk speed x this while eating.
@export var eat_move_mult := 0.5

@export_group("Crumbs")
## Picture of one crumb. null = small squares in the item's own colours; set = this picture per crumb (sized by crumb_px).
@export var crumb_texture: Texture2D
## Seconds between bursts.
@export var crumb_every := 0.1
## Crumbs per burst.
@export var crumb_count := 2
## Square size AND the grid they snap to (px = one body pixel). A texture is drawn this big.
@export var crumb_px := 3.0
## Start velocity: x is random in +-this (px/s).
@export var vel_x := 25.0
## Start velocity y is random between these (px/s, negative = up).
@export var vel_y_min := -40.0
@export var vel_y_max := -10.0
@export var gravity := 300.0
## Life of a crumb (s).
@export var life := 0.5
## Crumbs start in this fraction (0 = centre, 0.5 = bottom edge) below the item's centre, x within +-1/3 of its width.
@export var start_y_frac := 0.35
## Draw layer (absolute): just above the item (ChestHoldData.z).
@export var z := 4
## Hard cap of live crumbs.
@export var max_crumbs := 40
