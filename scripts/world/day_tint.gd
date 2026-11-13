class_name DayTint
extends CanvasModulate
## The screen colour of the time of day: the DayClock's gradient at `time`. A CanvasModulate tints the world canvas only;
## the HUD, F3 and menus are CanvasLayers, so they stay undarkened. Replace with a shader / sky later: nothing else reads this.

var _clock: DayClock

func _ready() -> void:
	_clock = get_tree().get_first_node_in_group("day_clock") as DayClock
	_apply()

func _process(_delta: float) -> void:
	_apply()

func _apply() -> void:
	color = _clock.tint_color() if _clock != null else Color.WHITE
