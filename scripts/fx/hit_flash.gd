extends Node
class_name HitFlash
## THE one flash mechanism: a shader on one CanvasItem, driven by `ActorVisual.flash()`. Swap the shader or
## this script and every actor changes; no combat code knows it exists (CLAUDE.md §5).
## Lives as a child of the visual, named "HitFlash". Runs on game time, so a hit-stop freezes the flash
## at full strength and it fades out right after.

const SHADER := preload("res://scripts/fx/hit_flash.gdshader")

var _item: CanvasItem
var _mat: ShaderMaterial
var _left := 0.0
var _saved: Material   ## the item's own material, put back when the flash ends

## Flash `item` (owned by `host`) with `color` for `duration` seconds. A new flash replaces the running one.
static func play(host: Node, item: CanvasItem, color: Color, duration: float) -> void:
	if item == null or duration <= 0.0:
		return
	var f := host.get_node_or_null("HitFlash") as HitFlash
	if f == null:
		f = HitFlash.new()
		f.name = "HitFlash"
		host.add_child(f)
	f._start(item, color, duration)

func _start(item: CanvasItem, color: Color, duration: float) -> void:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
	if _item != item or _item.material != _mat:
		_restore()
		_item = item
		_saved = item.material
	_item.material = _mat
	_mat.set_shader_parameter("flash_color", color)
	_mat.set_shader_parameter("amount", 1.0)
	_left = duration

## 0..1, for tests and F3.
func amount() -> float:
	return float(_mat.get_shader_parameter("amount")) if _mat else 0.0

func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_mat.set_shader_parameter("amount", 0.0)
		_restore()

func _restore() -> void:
	if is_instance_valid(_item) and _item.material == _mat:
		_item.material = _saved
