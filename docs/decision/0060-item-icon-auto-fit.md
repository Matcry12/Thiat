# 0060 Item icons are centred automatically

## Context
Item PNGs were drawn whole (transparent margins too) into the slot box, so a sword drawn off-centre in its file sat off-centre in the slot. Every new PNG would need hand tuning.

## Decision
`ItemIcon.crop()` (`scripts/items/item_icon.gd`) finds a texture's visible pixels (cached `AtlasTexture`, source file untouched). `ItemSlot` (all UI, cursor included), `Pickup` and `HeldItemVisual` draw that crop centred. The scale is the same as before, from the whole file: 16 px file 2x in a slot, 32 px file 1x. Sizes do not change.

## Why
A dropped-in PNG is centred with no tuning. We also tried a common size: in-between scales looked soft with a smooth filter and broken with sharp pixels, and clean scales only shrank the furnace too far. The user chose to keep the original look and only centre.

## Consequences
- Icons still differ in size by how they are drawn: `sword1` shows 19 px, tools 26. To change one, redraw it (about 22-28 px visible in a 32 px file, 11-14 px in a 16 px file).
- UI symbols (`set_picture`) and the tilted weapon-model fallback keep the full box, no crop.
- Needs the PNG readable as an image at runtime (true for imported textures).
