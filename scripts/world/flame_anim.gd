class_name FlameAnim
extends Node
## Plays a horizontal strip of equal frames on the parent Station's `Visual/Art` AtlasTexture (the torch flame).
## Looks only: swapping in an AnimatedSprite2D means deleting this node.

@export var frames := 3
@export var fps := 6.0

var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	var a := get_node_or_null("../Visual/Art") as Sprite2D
	if a == null or not a.texture is AtlasTexture:
		return
	var at := a.texture as AtlasTexture
	var w := at.region.size.x
	at.region.position.x = float(int(_t * fps) % maxi(frames, 1)) * w
