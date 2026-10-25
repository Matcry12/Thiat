"""Preview: dirt patches made only from Pixel Crawler tiles (decision 0035). Dirt fill below, grass above with the
pack's own hole frame (the rimmed one, rows 0-4 of Floors_Tiles; rows 5-9 have no rim). Holes are rectangles
(the pack has no other shape), at least 2x2 cells; 3x3+ look best.

Run: python3 tools/asset_viewer/dirt_holes_preview.py [out.png]   (default docs/demo/dirt_holes_preview.png)
"""
import random
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
S = 16
GRASS_FILLS = [(1, 10), (2, 10), (3, 10)]
DIRT_FILLS = [(11, 10), (12, 10), (13, 10)]
# Hole frame, rimmed variant: interior (1..3, 1..3), ring above row 0, below row 4, left col 0, right col 4.


def edge(i, n):
    return 1 if i == 0 else (3 if i == n - 1 else 2)


def hole_tiles(x, y, w, h):
    """cell -> grass frame tile for one w x h hole (None = fully open, dirt shows)."""
    out = {}
    for i in range(w):
        for j in range(h):
            c = (edge(i, w), edge(j, h))
            out[(x + i, y + j)] = None if c == (2, 2) else c
        out[(x + i, y - 1)] = (edge(i, w), 0)
        out[(x + i, y + h)] = (edge(i, w), 4)
    for j in range(h):
        out[(x - 1, y + j)] = (0, edge(j, h))
        out[(x + w, y + j)] = (4, edge(j, h))
    return out


def main(out_path):
    random.seed(4)
    sheet = Image.open(ROOT / "assets/map/Floors_Tiles.png").convert("RGBA")
    tile = lambda c: sheet.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
    W, H = 36, 20
    img = Image.new("RGBA", (W * S, H * S))
    holes = []
    for _ in range(2000):   # ponytail: rejection sampling, fine for a preview
        w, h = random.randint(2, 5), random.randint(2, 4)
        x, y = random.randint(2, W - w - 2), random.randint(2, H - h - 2)
        if all(x > a + c + 2 or a > x + w + 2 or y > b + d + 2 or b > y + h + 2 for a, b, c, d in holes):
            holes.append((x, y, w, h))
        if len(holes) >= 9:
            break
    grid = {}
    for hole in holes:
        grid.update(hole_tiles(*hole))
    for y in range(H):
        for x in range(W):
            img.alpha_composite(tile(random.choice(DIRT_FILLS)), (x * S, y * S))
            c = grid.get((x, y), random.choice(GRASS_FILLS))
            if c:
                img.alpha_composite(tile(c), (x * S, y * S))
    img.resize((W * S * 2, H * S * 2), Image.NEAREST).save(out_path)
    print(out_path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ROOT / "docs/demo/dirt_holes_preview.png")
