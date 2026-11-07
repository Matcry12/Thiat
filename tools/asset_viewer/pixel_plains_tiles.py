"""Pixel Plains ground mapping: ONE place that says which piece of `New Basic Tiles Free.png` is used for what.
Original pack pixels only (no recolour). Run this file to self-check the table against the pack's pixels.

HOW THE PACK IS DRAWN (found by zooming, verified pixel-for-pixel below)
  The pack is a CELL tileset with 8x8 QUARTERS: a "lower" cell next to an "upper" material gets a 4 px band of the
  upper material drawn into it (outline + a shadow falling to the lower right ONTO the lower material, so the
  shadow tells which one is on top). Every tile of the pack = four quarters, each quarter depends on three neighbours
  of the lower cell only: V (vertical), H (horizontal), D (diagonal):
      V and H upper -> "both" (outer corner)     V only -> "v" (horizontal edge)
      H only -> "h" (vertical edge)              D only -> "d" (inner corner wedge)     nothing -> "none" (plain)
  Blocks on the sheet (col,row, 16 px tiles):
    (8..11, 6..9)  light grass on dirt: 4x4 sample sheet, also holds every wedge. Used here for the quarters.
    (0..3, 6..9)   same pieces assembled as strips / islands (decodes to the same quarters: proof the model is complete)
    (4..7, 6..9)   same pieces, wedge-heavy (grass holes inside dirt): same quarters again
    (6..8, 10..12) dark grass on light grass: corners, edges, plain; wedges in the (9..11,10..12) block
    (9..11, 10..12) dark cell in light grass: carries the 4 inner-corner quarters of dark_on_light
    (5..11, 0)/(5..11,3)/(5..11,5) dirt / light / dark fill variants with square patches;  (8..11,1) grass with dirt squares
    (0..4, 2..5) flowers (pink / white), (5..11, 2) and (5..11, 4) green tufts: decals on transparent
  The game's GroundBaker is DUAL GRID: tile (i,j) sits on the corner of 4 cells; the NW quarter of that tile is the SE
  quarter of the NW cell, etc. So: dual quadrant qd (0 NW,1 NE,2 SW,3 SE) belongs to cell qd and uses source quarter
  slot 3-qd; its V neighbour is cell qd^2, H is qd^1, D is qd^3 (cells of the same 2x2 corner).
  Mask bits (same as GroundBaker): NW 1, NE 2, SW 4, SE 8; a bit set = that cell is the UPPER material.
"""
from PIL import Image
import os

PK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "source", "third_party", "pixel_plains") + "/"
SHEET = Image.open(PK + "New Basic Tiles Free.png").convert("RGBA")
GREY = (150, 150, 150, 255)
NW, NE, SW, SE = 1, 2, 4, 8

def quarter(c, r, s):
    x, y = c * 16 + (s & 1) * 8, r * 16 + (s >> 1) * 8
    return SHEET.crop((x, y, x + 8, y + 8))

# ---- fill variants per material (whole 16 px tiles). PLAIN is picked most of the time; variants are rare (they differ in
# brightness: a checkerboard otherwise). Dirt tiles (8,0) (10,0) (11,0) are left out: their marks touch the tile edge (cut squares).
PLAIN = {"dirt": [(9, 8)], "light": [(10, 7), (7, 11)], "dark": [(10, 11)]}
VARIANTS = {
    "dirt": [(5, 0), (6, 0), (7, 0), (9, 0)],
    "light": [(c, 3) for c in range(5, 12) if c != 10],
    "dark": [(c, 5) for c in range(5, 12)],
}
PLAIN_WEIGHT = 0.85
# plain 8x8 quarter of each material (the upper cell's quarter): (col,row,slot)
PLAIN_Q = {"dirt": (9, 8, 0), "light": (10, 7, 0), "dark": (10, 11, 0)}
LAYER = {"dirt": 1, "light": 5, "dark": 6}   # who is on top where two touch (dark over light over dirt)
# pack is COMPLETE for grass/dirt. Map rule (not art): dark grass never touches dirt, a ring of light grass sits between (see preview).

# ---- the 16 dual-grid cases, copied from the independent review (ground_tags.md). Mask bits NW1 NE2 SW4 SE8, set = UPPER.
# Entry per display quadrant (NW,NE,SW,SE): "U" upper plain, "L" lower plain, or (col,row,slot) slot 0 TL 1 TR 2 BL 3 BR of that tile.
# Some quarters differ by 1-2 shadow px from look-alikes: use exactly these sources, never mix. Never mirror or rotate.
U, L = "U", "L"
_CASES = {
 # dirt (lower) / light grass (upper)
 "light_on_dirt": {
  0: [L, L, L, L], 8: [(2,7,3), (2,8,2), (3,7,1), U], 4: [(2,8,3), (2,7,2), U, (1,7,0)], 12: [(2,8,3), (2,8,2), U, U],
  2: [(3,7,3), U, (2,7,1), (2,6,0)], 10: [(3,7,3), U, (3,7,1), U], 6: [(3,8,3), U, U, (1,6,0)], 14: [(3,8,3), U, U, U],
  1: [U, (1,7,2), (2,6,1), (2,7,0)], 9: [U, (1,8,2), (3,6,1), U], 5: [U, (1,7,2), U, (1,7,0)], 13: [U, (1,8,2), U, U],
  3: [U, U, (2,6,1), (2,6,0)], 11: [U, U, (3,6,1), U], 7: [U, U, U, (1,6,0)], 15: [U, U, U, U]},
 # light grass (lower) / dark grass (upper)
 "dark_on_light": {
  0: [L, L, L, L], 8: [(9,10,3), (7,12,2), (8,11,1), U], 4: [(7,12,3), (11,10,2), U, (6,11,0)], 12: [(7,12,3), (7,12,2), U, U],
  2: [(8,11,3), U, (9,12,1), (7,10,0)], 10: [(8,11,3), U, (8,11,1), U], 6: [(8,12,3), U, U, (6,10,0)], 14: [(8,12,3), U, U, U],
  1: [U, (6,11,2), (7,10,1), (11,12,0)], 9: [U, (6,12,2), (8,10,1), U], 5: [U, (6,11,2), U, (6,11,0)], 13: [U, (6,12,2), U, U],
  3: [U, U, (7,10,1), (7,10,0)], 11: [U, U, (8,10,1), U], 7: [U, U, U, (6,10,0)], 15: [U, U, U, U]},
}
PAIRS = {"light_on_dirt": ("light", "dirt"), "dark_on_light": ("dark", "light")}

def case(pair, mask):
    """4 entries (NW,NE,SW,SE of the dual tile): ('fill', material) | ('src', col, row, slot)."""
    up, lo = PAIRS[pair]
    out = []
    for e in _CASES[pair][mask]:
        out.append(("fill", up) if e == "U" else ("fill", lo) if e == "L" else ("src",) + e)
    return out

def missing(pair, mask): return False

DECALS = {
    "dark_blob_on_light": "(9..11,10..12) free-form dark patch with outline+shadow, ~25 px: usable as a single-cell dark island decal, not a tile",
    "flowers": "(0..4,2..5) pink/white flowers, transparent", "tufts": "(5..11,2) and (5..11,4) green tufts, transparent",
}

def piece(e, rng=None):
    """8x8 image of one case entry, or None when MISSING."""
    if e is None: return None
    if e[0] == "fill": return quarter(*PLAIN_Q[e[1]])
    return quarter(e[1], e[2], e[3])

def tile_image(pair, mask):
    im = Image.new("RGBA", (16, 16), GREY)
    miss = False
    for qd, e in enumerate(case(pair, mask)):
        p = piece(e)
        if p is None: miss = True; continue
        im.paste(p, ((qd & 1) * 8, (qd >> 1) * 8))
    return im, miss

def pair_of(a, b):
    """(pair name, upper, lower) for two different materials"""
    u, l = (a, b) if LAYER[a] > LAYER[b] else (b, a)
    return u + "_on_" + l, u, l

def fill_tile(mat, rng):
    c, r = rng.choice(PLAIN[mat]) if rng.random() < PLAIN_WEIGHT else rng.choice(VARIANTS[mat])
    return SHEET.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))

def render(grid, rng):
    """grid[y][x] = 'dirt' | 'light' | 'dark' | None (None = no art: left transparent/grey by the caller).
    Dual grid. Returns (RGBA image W*16 x H*16, stats dict: missing quarters per pair, 3-way corners)."""
    H, W = len(grid), len(grid[0])
    im = Image.new("RGBA", (W * 16 + 16, H * 16 + 16), (0, 0, 0, 0))   # padded by 8 px each side, cropped at the end
    stats = {}
    g = lambda x, y: grid[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)]
    for j in range(H + 1):
        for i in range(W + 1):
            cells = [g(i - 1, j - 1), g(i, j - 1), g(i - 1, j), g(i, j)]   # NW NE SW SE
            at = (i * 16, j * 16)
            mats = {c for c in cells if c}
            if len(mats) == 1 and None not in cells:
                m0 = next(iter(mats))
                im.paste(fill_tile(m0, rng), at); continue
            if len(mats) == 2 and None not in cells:
                name, up, lo = pair_of(*mats)
                if name not in PAIRS:   # not in the pack: the caller's map rule should have avoided it
                    stats[name] = stats.get(name, 0) + 1
                    for qd, c in enumerate(cells): im.paste(quarter(*PLAIN_Q[c]), (at[0] + (qd & 1) * 8, at[1] + (qd >> 1) * 8))
                    continue
                mask = sum(b for b, c in zip((NW, NE, SW, SE), cells) if c == up)
                t, miss = tile_image(name, mask)
                if miss: stats[name] = stats.get(name, 0) + 1
                im.paste(t, at); continue
            # grey neighbour or 3 materials: each quarter shows its own cell's plain material, grey cells stay empty
            if len(mats) > 2: stats["3-way corner"] = stats.get("3-way corner", 0) + 1
            for qd, c in enumerate(cells):
                if c: im.paste(quarter(*PLAIN_Q[c]), (at[0] + (qd & 1) * 8, at[1] + (qd >> 1) * 8))
    return im.crop((8, 8, 8 + W * 16, 8 + H * 16)), stats

# ground ids the map can put side by side (scripts/map/map_gen.gd Ground + data/maps/ground_*.tres layers) and the pack's answer
NEEDED = [
    # (pair upper_on_lower, why it happens in the map, status)
    ("grass(light) on dirt", "plains/forest/swamp next to paths, camp, boss land, beach dirt", "HAVE - 16/16 cases"),
    ("grass(dark) on grass(light)", "forest/taiga/swamp next to plains/autumn", "HAVE - 16/16 cases"),
    ("MAP RULE: light ring between dark grass and dirt", "any dark-grass cell within 1 cell (8-neighbour) of dirt becomes light grass, then autotile", "RULE - not missing art"),
    ("grass(any) on sand", "plains/autumn shore_ground = sand; beach_sand biome", "MISSING"),
    ("grass(any) on cobble", "beach_gravel / rocky meet grass", "MISSING"),
    ("grass(any) on snow", "snowy biome meets taiga / plains (snow is layer 4 < grass 5)", "MISSING"),
    ("snow on dirt / sand / cobble", "snowy next to rocky, beach", "MISSING"),
    ("cobble on dirt / sand", "paths, camp, rocky stone with dirt clumps", "MISSING"),
    ("sand on dirt", "beach cells are Ground.DIRT next to beach_sand", "MISSING"),
    ("dirt on water", "beach ring = Ground.DIRT touching ocean / shallow", "MISSING - no water art"),
    ("sand on water", "beach_sand, river / lake shore", "MISSING - no water art"),
    ("grass / cobble / snow on water", "river & lake banks, coast without beach", "MISSING - no water art"),
    ("boss ground (layer 5) vs grass / dirt / cobble", "boss land = ground_boss.tres, same layer as grass", "MISSING - needs own fill; border vs grass is a same-layer seam"),
    ("plain fills: water, sand, snow, cobble, boss", "any cell of that ground", "MISSING"),
]

def selfcheck():
    for pair in PAIRS: [case(pair, m) for m in range(16)]
    print("cases supported (of 16):", {p: sum(not missing(p, m) for m in range(16)) for p in PAIRS})

if __name__ == "__main__":
    selfcheck()
