class_name ItemIcon
extends RefCounted
## Centring for item pictures (decision 0060). A PNG's margins are the artist's business: this finds the visible pixels,
## so every UI / ground / hand draw can centre them. Sizes do not change. Source files stay as they are.

static var _cache: Dictionary = {}   ## source texture -> cropped AtlasTexture (or the texture itself when nothing to crop)

## An AtlasTexture of only the visible pixels. Null stays null; no pixels or no image = the texture unchanged.
static func crop(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	if _cache.has(tex):
		return _cache[tex]
	var out: Texture2D = tex
	var base: Texture2D = tex
	var origin := Vector2i.ZERO
	var at := tex as AtlasTexture
	if at != null and at.atlas != null:   # no nesting: crop inside the atlas region
		base = at.atlas
		origin = Vector2i(at.region.position)
	var img: Image = base.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var r := Rect2i(origin, Vector2i(at.region.size)) if at != null and at.atlas != null else Rect2i(Vector2i.ZERO, img.get_size())
		var used := img.get_region(r).get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var res := AtlasTexture.new()
			res.atlas = base
			res.region = Rect2(used.position + r.position, used.size)
			res.filter_clip = true
			out = res
	_cache[tex] = out
	return out
