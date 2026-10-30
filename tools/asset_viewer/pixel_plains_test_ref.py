"""Reference picture for tests/test_pixel_plains_ground.gd: renders a fixed letter grid with pixel_plains_tiles.render()
using plain-only fills (one plain tile per material, weight 1), so the game's baker must match it pixel for pixel.
Letters: . water   d dirt   l light grass   D dark grass (before the map rule: dark within 1 cell of dirt becomes light).
Run: python3 tools/asset_viewer/pixel_plains_test_ref.py   (writes tests/support/pixel_plains/grid.json + ref.png)"""
import json, os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_plains_tiles as pp

GRID = [
    "....................",
    ".dddd..llll..DDDD...",
    ".dddd..llll..DDDD...",
    ".dd.d..ll.l..DD.D...",
    ".d.dd..l.ll..DDDD...",
    ".dddd..llll.........",
    "....................",
    ".llllllll.DDDDDDDD..",
    ".llDDDDll.DDlDDDDD..",
    ".llDDDDll.DDDDDDDD..",
    ".llllllll.D.D.D.D...",
    ".ddddllll..D.D.D.D..",
    ".ddddDDDD...........",
    "....................",
]
NAME = {"d": "dirt", "l": "light", "D": "dark", ".": None}

def resolved(rows):
    """letters -> material names with the map rule applied (dark within 1 cell, 8 neighbours, of dirt -> light)."""
    H, W = len(rows), len(rows[0])
    at = lambda x, y: rows[y][x] if 0 <= x < W and 0 <= y < H else "."
    return [[("light" if c == "D" and any(at(x + dx, y + dy) == "d" for dx in (-1, 0, 1) for dy in (-1, 0, 1)) else NAME[c])
             for x, c in enumerate(r)] for y, r in enumerate(rows)]

if __name__ == "__main__":
    pp.PLAIN = {"dirt": [(9, 8)], "light": [(10, 7)], "dark": [(10, 11)]}
    pp.PLAIN_WEIGHT = 1.0
    g = resolved(GRID)
    padded = [[None] * (len(g[0]) + 2)] + [[None] + r + [None] for r in g] + [[None] * (len(g[0]) + 2)]   # off the map is water
    im, stats = pp.render(padded, random.Random(0))
    # game tile (i, j) = python tile (i + 1, j + 1); the python image starts 8 px before tile 0
    W, H = len(GRID[0]), len(GRID)
    im = im.crop((8, 8, 8 + (W + 1) * 16, 8 + (H + 1) * 16))
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "tests", "support", "pixel_plains")
    im.save(os.path.join(out, "ref.png"))
    json.dump({"rows": GRID}, open(os.path.join(out, "grid.json"), "w"))
    print("wrote", os.path.normpath(out), im.size, stats)
