# Pixel Plains — research notes

**Status:** Current

Pack by SnowHex (credit required, no redistribution). Findings from the free tiles and two store GIFs.

## Ground tiles (16 px)

- Autotile blocks are a palette of **8x8 quarters**, not whole tiles. Each quarter depends on 3 neighbours
  (vertical, horizontal, diagonal): both = outer corner, one = edge, only diagonal = inner corner, none = fill.
- Layer order: **dirt < light grass < dark grass**. The upper layer's rim + shadow is drawn inside the lower cell.
  Never mirror or rotate pieces (the shadow falls on one side only).
- Dirt/light grass and light/dark grass are both complete (16/16 dual-grid cases).
- Dark grass never touches dirt: the map needs a 1-cell light-grass ring between them (map rule, not missing art).
- New grounds (water, sand, snow, cobble) need one edge block only against the layer next to them.
- Table: `tools/asset_viewer/pixel_plains_tiles.py`; picture: `docs/demo/pixel_plains_ground_table.png`.

## Character face (store GIF 2, winter scene, 100 ms frames)

The eyes are a **separate layer** on a body drawn with no face, so they animate on their own:

| Effect | How |
|---|---|
| Blink | open (2 px tall) -> half (1 px) -> closed (no eyes) -> half -> open, ~0.1 s each |
| Head bob | eyes move down 1 px with the body |
| Look around | eyes slide 1 px left/right while the body stays still |

Plan if we build it (parked): a script cuts the eyes out of our strips -> faceless body + eye sprites
(open / half / closed / hurt X) + face position per body frame; random blink every 2-5 s; eyes slide toward the
aim; all numbers `@export` in F3; no combat code change.
