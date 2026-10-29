"""Renders docs/demo/pixel_plains_ground_table.png from pixel_plains_tiles.py: per material pair the 16 dual-grid cases
(with source coords), a test shape drawn with them, then the pairs the map needs that the pack lacks.
  python3 tools/asset_viewer/pixel_plains_ground_table.py docs/demo/pixel_plains_ground_table.png
"""
import os, random, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from PIL import Image, ImageDraw, ImageFont
import pixel_plains_tiles as T

FONT = ImageFont.load_default(size=11)
BIG = ImageFont.load_default(size=15)
BG = (34, 34, 38, 255)
SHAPES = """
.........  .........  .........  .........  .........
.#######.  .#######.  .###.....  .#.......  .#######.
.#######.  .###.###.  .###.....  .........  .#######.
.###..##.  .###.###.  .###.###.  ...###...  .##.####.
.####.##.  .###.###.  .....###.  ...###...  .#######.
.#######.  .#######.  .....###.  ...###...  .##..###.
.........  .........  .........  .........  .##..###.
.........  .........  .........  .........  .#######.
.........  .........  .........  .........  .........
"""
# bay | 1-cell channel (splits the blob) | diagonal touch | single cell island + 1-wide strip | holes (1 cell, 2x2)
SHAPE_ROWS = [r.split("  ") for r in SHAPES.strip().split("\n")]
def shape_grid(up, lo):
    rows = []
    for r in SHAPE_ROWS: rows.append("".join(r))
    return [[up if ch == "#" else lo for ch in row] for row in rows]

# extra shape row: 1-wide strips and a lone cell, drawn after the first
SHAPES2 = """
...........  ...........
.#########.  .#.#.#.....
.#.......#.  .#.#.#.###.
.#.#####.#.  .#.#.#.###.
.#.#...#.#.  .#.#.#.###.
.#.#####.#.  .#.#.#.....
.#.......#.  ...........
.#########.  ...........
...........  ...........
"""
def shape2(up, lo):
    rows = ["".join(r.split("  ")) for r in SHAPES2.strip().split("\n")]
    return [[up if ch == "#" else lo for ch in row] for row in rows]

def mask_icon(mask, s=7):
    ic = Image.new("RGBA", (s * 2 + 3, s * 2 + 3), (0, 0, 0, 0)); d = ImageDraw.Draw(ic)
    for b, (x, y) in zip((1, 2, 4, 8), ((0, 0), (1, 0), (0, 1), (1, 1))):
        d.rectangle((x * (s + 1), y * (s + 1), x * (s + 1) + s - 1, y * (s + 1) + s - 1), fill=(240, 240, 240, 255) if mask & b else (70, 70, 80, 255), outline=(120, 120, 130, 255))
    return ic

def cross(d, box):
    d.line((box[0], box[1], box[2], box[3]), fill=(230, 40, 40, 255), width=3); d.line((box[0], box[3], box[2], box[1]), fill=(230, 40, 40, 255), width=3)
    d.rectangle(box, outline=(230, 40, 40, 255), width=2)

NAMES = ("NW", "NE", "SW", "SE")
def label(e):
    if e is None: return "MISSING"
    return "fill " + e[1][:3] if e[0] == "fill" else "%d,%d %s" % (e[1], e[2], ("TL", "TR", "BL", "BR")[e[3]])

def block(pair, rng):
    up, lo = T.PAIRS[pair]
    CW, S = 128, 4
    cases = Image.new("RGBA", (8 * CW, 2 * 150), BG); d = ImageDraw.Draw(cases)
    nmiss = 0
    for m in range(16):
        x0, y0 = (m % 8) * CW, (m // 8) * 150
        t, miss = T.tile_image(pair, m); nmiss += miss
        big = t.resize((16 * S, 16 * S), Image.NEAREST)
        cases.paste(big, (x0 + 4, y0 + 18))
        cases.alpha_composite(mask_icon(m), (x0 + 72, y0 + 18))
        d.text((x0 + 72, y0 + 40), "mask %d" % m, fill=(255, 220, 120, 255), font=FONT)
        for k, e in enumerate(T.case(pair, m)):
            d.text((x0 + 4, y0 + 86 + k * 13), NAMES[k] + " " + label(e), fill=(255, 120, 120, 255) if e is None else (210, 210, 210, 255), font=FONT)
        if miss: cross(d, (x0 + 4, y0 + 18, x0 + 4 + 16 * S, y0 + 18 + 16 * S))
    g1, g2 = shape_grid(up, lo), shape2(up, lo)
    def draw_shape(g):
        im, st = T.render(g, rng)
        # re-draw missing quarters: render() leaves GREY there already
        return im.resize((im.width * 2, im.height * 2), Image.NEAREST), st
    s1, st1 = draw_shape(g1); s2, st2 = draw_shape(g2)
    shapes = Image.new("RGBA", (max(8 * CW, s1.width + s2.width + 20), max(s1.height, s2.height)), BG)
    shapes.paste(s1, (0, 0)); shapes.paste(s2, (s1.width + 20, 0))
    head = "%s   (upper = %s, lower = %s)   cases supported %d/16   - test shapes: bay | 1-cell channel | diagonal touch | lone cell + strip | holes   |   strips / lone cell / hole" % (pair, up, lo, 16 - nmiss)
    out = Image.new("RGBA", (shapes.width, 24 + cases.height + shapes.height + 10), BG)
    ImageDraw.Draw(out).text((6, 3), head, fill=(255, 255, 255, 255), font=BIG)
    out.paste(cases, (0, 24)); out.paste(shapes, (0, 24 + cases.height + 4))
    return out

def needed_block(width):
    h = 30 + 17 * len(T.NEEDED) + 20
    im = Image.new("RGBA", (width, h), BG); d = ImageDraw.Draw(im)
    d.text((6, 3), "Pairs the map needs (MapGen Ground ids + layers: dirt 1, sand 2, cobble 3, snow 4, grass/boss 5; water = layer 0) vs the pack", fill=(255, 255, 255, 255), font=BIG)
    for i, (p, why, st) in enumerate(T.NEEDED):
        c = (120, 220, 120, 255) if st.startswith("HAVE") else (255, 110, 110, 255)
        d.text((8, 30 + i * 17), p, fill=c, font=FONT); d.text((300, 30 + i * 17), st, fill=c, font=FONT); d.text((700, 30 + i * 17), why, fill=(190, 190, 190, 255), font=FONT)
    return im

if __name__ == "__main__":
    rng = random.Random(3)
    blocks = [block(p, rng) for p in T.PAIRS] 
    W = max(b.width for b in blocks) 
    blocks.append(needed_block(W))
    H = sum(b.height + 14 for b in blocks)
    out = Image.new("RGBA", (W, H), (20, 20, 22, 255)); y = 0
    for b in blocks: out.paste(b, (0, y)); y += b.height + 14
    out.convert("RGB").save(sys.argv[1]); print("wrote", sys.argv[1], out.size)
