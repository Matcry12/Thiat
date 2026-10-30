"""$0 palette-swap demo: how many 'missing' Pixel Plains pieces are just a recolour of existing pack pixels.
Run: python3 tools/art_tests/recolour/recolour.py   -> out/*.png, demo_sheet.png, demo_patch.png
swap() = exact RGBA -> RGBA, unlisted colours and alpha kept. Not game code."""
import os, sys, random
from PIL import Image, ImageDraw, ImageFont
import numpy as np
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "..", "asset_viewer"))
import pixel_plains_tiles as pp
SHEET = pp.SHEET
TREES = Image.open(os.path.join(pp.PK, "Trees and bushes.png")).convert("RGBA")
OUT = os.path.join(HERE, "out"); os.makedirs(OUT, exist_ok=True)
Z = 4

def C(r, g, b): return (r, g, b, 255)

# ---- source palettes (printed by palettes()) ----
# dirt (3 shades): fill, darker patch, shadow cast by grass onto dirt
DIRT = [C(240,181,65), C(235,150,61), C(189,106,98)]
GROUND = {
 "sand":   dict(zip(DIRT, [C(236,214,150), C(222,192,125), C(170,134,100)])),
 "snow":   dict(zip(DIRT, [C(240,246,252), C(214,228,242), C(150,170,204)])),
 "water":  dict(zip(DIRT, [C(92,190,214),  C(66,160,198),  C(36,104,150)])),
 "cobble": dict(zip(DIRT, [C(150,152,162), C(124,126,138), C(84,84,102)])),
}
# leaves/hedge, light -> dark: highlight, top, mid, shade, deep shade, outline(dark)
LEAF = [C(200,212,93), C(164,196,67), C(99,171,63), C(59,125,79), C(42,89,79), C(35,59,54)]
LEAFV = {
 "autumn_orange": [C(255,200,96), C(244,164,52), C(216,118,38), C(168,78,40), C(120,52,38), C(84,36,38)],
 "yellow":        [C(255,246,160), C(244,218,84), C(224,182,52), C(178,132,44), C(130,92,40), C(88,62,38)],
 "snow":          [C(255,255,255), C(238,246,252), C(206,226,242), C(160,190,216), C(118,148,186), C(78,104,140)],
 "red":           [C(255,150,124), C(232,88,72), C(194,48,56), C(142,32,56), C(102,26,50), C(70,20,40)],
}
LEAFT = {k: dict(zip(LEAF, v)) for k, v in LEAFV.items()}
# flowers: petals pink, centre orange-cream
PINK, CENTRE = C(254,167,167), C(255,206,145)
FLOWER = {
 "blue":   {PINK: C(128,168,255)},
 "yellow": {PINK: C(255,230,96), CENTRE: C(240,150,60)},
 "orange": {PINK: C(255,150,70)},
}
# tufts: light green, mid green (row 2) ; mid green, dark green (row 4)
TUFT = {
 "yellow": {C(132,184,65): C(222,204,84), C(63,148,62): C(160,138,48), C(51,107,79): C(112,92,44)},
 "brown":  {C(132,184,65): C(176,126,68), C(63,148,62): C(120,80,48), C(51,107,79): C(84,56,42)},
}

def swap(img, table):
    a = np.array(img.convert("RGBA")); out = a.copy()
    for src, dst in table.items():
        m = (a == np.array(src, dtype=np.uint8)).all(axis=2)
        out[m, :3] = dst[:3]          # alpha kept
    return Image.fromarray(out)

def palettes():
    def pal(im):
        a = np.array(im.convert("RGBA")).reshape(-1, 4)
        return Counter(map(tuple, a[a[:, 3] > 0].tolist())).most_common()
    for n, im in [("ground block", SHEET.crop((128,96,192,160))), ("pink flowers", SHEET.crop((0,32,80,64))),
                  ("tufts row2", SHEET.crop((80,32,192,48))), ("tufts row4", SHEET.crop((80,64,192,80))),
                  ("trees+hedge", TREES)]:
        p = pal(im); print(f"{n}: {len(p)} colours"); print("   ", [(c[:3], k) for c, k in p])

# ---- pieces ----
TREE_BOXES = [(57,0,30,43),(99,0,42,43),(201,0,30,43),(243,0,42,43),(32,5,16,27),(176,5,16,27),
              (13,53,22,54),(157,53,22,54),(99,64,42,43),(243,64,42,43),(61,65,22,42),(205,65,22,42)]
SHADOW = {(42,89,79), (59,125,79)}   # dark-tree shadow, light-tree shadow (both also leaf shades)
def box(im, b): return im.crop((b[0], b[1], b[0]+b[2], b[1]+b[3]))
def tree_swap(b, table):
    # ground shadow under a tree stays green (it lies on grass): below the trunk top, keep the shadow colour original.
    # Shadow height differs per tree size, so find it by colour, not by a fixed row count.
    src = box(TREES, b); dst = swap(src, table)
    w, h = src.size
    leaf = {c[:3] for c in LEAF}   # trunk top = first row with a non-leaf colour (trunk colours differ per tree)
    top = next((y for y in range(h) if any(src.getpixel((x, y))[3] and src.getpixel((x, y))[:3] not in leaf for x in range(w))), h)
    for y in range(top, h):
        for x in range(w):
            if src.getpixel((x, y))[:3] in SHADOW: dst.putpixel((x, y), src.getpixel((x, y)))
    return dst
def trees_strip(table):
    im = Image.new("RGBA", (288, 108), (0,0,0,0))
    for b in TREE_BOXES:
        t = tree_swap(b, table) if table else box(TREES, b)
        im.alpha_composite(t, (b[0], b[1]))
    return im
HEDGE_BOX = (288, 0, 160, 96)
def hedge(table):
    h = box(TREES, HEDGE_BOX)
    for x in range(14, 50):           # logs + stump sit inside the hedge crop: blank them (not hedge)
        for y in range(60, 96): h.putpixel((x, y), (0, 0, 0, 0))
    return swap(h, table) if table else h
def ground_block(table): s = SHEET.crop((128,96,192,160)); return swap(s, table) if table else s
def flowers(table): s = SHEET.crop((0,32,80,64)); return swap(s, table) if table else s
def tufts(table):
    s = Image.new("RGBA", (112, 32)); s.paste(SHEET.crop((80,32,192,48)), (0,0)); s.paste(SHEET.crop((80,64,192,80)), (0,16))
    return swap(s, table) if table else s

GROUPS = [  # (label, [(variant name, image)])
 ("GROUND dirt->", [("orig dirt", ground_block(None))] + [(k, ground_block(t)) for k, t in GROUND.items()]),
 ("FLOWER pink->", [("orig", flowers(None))] + [(k, flowers(t)) for k, t in FLOWER.items()]),
 ("TUFT green->", [("orig", tufts(None))] + [(k, tufts(t)) for k, t in TUFT.items()]),
 ("HEDGE green->", [("orig", hedge(None))] + [(k, hedge(t)) for k, t in LEAFT.items() if k != "snow"]),
]
TREE_ROWS = [("TREE oak orig", trees_strip(None))] + [(f"TREE {k}", trees_strip(t)) for k, t in LEAFT.items() if k != "red"]

def save_out():
    for lab, vs in GROUPS:
        for n, im in vs: im.save(f"{OUT}/{lab.split()[0].lower()}_{n.replace(' ','_')}.png")
    for lab, im in TREE_ROWS: im.save(f"{OUT}/{lab.replace(' ','_').lower()}.png")

def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
BG = (40, 42, 48)
def z(im): return im.resize((im.width*Z, im.height*Z), Image.NEAREST)

def demo_sheet():
    rows = []  # (label, [(caption, zoomed image)])
    for lab, vs in GROUPS: rows.append((lab, [(n, z(im)) for n, im in vs]))
    for lab, im in TREE_ROWS: rows.append((lab, [("", z(im))]))
    f, fs = font(22), font(16)
    lw, pad = 200, 16
    W = max(lw + sum(i.width + pad for _, i in r[1]) + pad for r in rows)
    H = sum(max(i.height for _, i in r[1]) + 28 + pad for r in rows) + pad
    sheet = Image.new("RGBA", (W, H), BG + (255,)); d = ImageDraw.Draw(sheet); y = pad
    for lab, items in rows:
        rh = max(i.height for _, i in items)
        d.text((pad, y + rh // 2 - 12), lab, fill=(235, 235, 235), font=f)
        x = lw
        for cap, im in items:
            sheet.alpha_composite(im, (x, y + 24)); d.text((x, y + 2), cap, fill=(180, 200, 255), font=fs); x += im.width + pad
        y += rh + 28 + pad
    sheet.convert("RGB").save(os.path.join(HERE, "demo_sheet.png"))

# ---- mock map patch ----
GW, GH = 24, 16
def patch_grid():
    g = [["light"] * GW for _ in range(GH)]
    for y in range(GH):                       # beach: dirt blob bottom-left
        for x in range(GW):
            if (x - 3) ** 2 / 36 + (y - 14) ** 2 / 14 < 1 or (y >= 12 and x < 3): g[y][x] = "dirt"
    for y in range(GH):                       # pond: dirt blob top-right
        for x in range(GW):
            if (x - 17) ** 2 / 20 + (y - 5) ** 2 / 12 < 1: g[y][x] = "dirt"
    return g
def tree_img(i, table): b = TREE_BOXES[i]; return tree_swap(b, table) if table else box(TREES, b)
def patch(recol):
    im, _ = pp.render(patch_grid(), random.Random(3))
    if recol:
        sand = swap(im.crop((0, 8*16, 12*16, GH*16)), GROUND["sand"]); im.paste(sand, (0, 8*16))
        wat = swap(im.crop((11*16, 0, GW*16, 11*16)), GROUND["water"]); im.paste(wat, (11*16, 0))
    # props: (tree box idx, leaf variant, cell x, cell y bottom) ; flowers at cells
    trees = [(1, "autumn_orange", 4, 5), (3, "yellow", 8, 8), (2, "snow", 21, 14), (9, "autumn_orange", 10, 14), (0, "yellow", 1, 5), (11, "red", 14, 14)]
    gr = patch_grid(); ok = lambda cx, cy: gr[cy][cx] != "dirt"   # no props on water / sand
    for i, v, cx, cy in trees:
        t = tree_img(i, LEAFT[v] if recol else None); im.alpha_composite(t, (cx*16 + 8 - t.width // 2, cy*16 + 12 - t.height))
    fl = flowers(None); fl_b = swap(fl, FLOWER["blue"]); fl_y = swap(fl, FLOWER["yellow"]); fl_o = swap(fl, FLOWER["orange"])
    spots = [(6,3,fl_b),(7,11,fl_y),(13,12,fl_o),(2,1,fl_b),(20,10,fl_y),(11,2,fl_o),(22,2,fl_b)]
    for cx, cy, f in spots:
        if not ok(cx, cy): continue
        im.alpha_composite((f if recol else fl).crop((0, 0, 16, 16)), (cx*16, cy*16))
    tf = tufts(None); tf_y = swap(tf, TUFT["yellow"]); tf_b = swap(tf, TUFT["brown"])
    for k, (cx, cy) in enumerate([(3,3),(9,6),(15,9),(5,9),(20,6),(12,13),(23,12),(8,1)]):
        if not ok(cx, cy): continue
        t = (tf, tf_y, tf_b)[k % 3] if recol else tf
        im.alpha_composite(t.crop((16*(k%7), 0, 16*(k%7)+16, 16)), (cx*16, cy*16))
    hd = hedge(LEAFT["red"] if recol else None).crop((0, 64, 48, 96))
    im.alpha_composite(hd, (16*16, 12*16))
    return im
def demo_patch():
    a, b = z(patch(False)), z(patch(True)); f = font(24); pad = 20
    s = Image.new("RGB", (a.width + b.width + 3*pad, a.height + 2*pad + 30), BG); d = ImageDraw.Draw(s)
    d.text((pad, 4), "ORIGINAL PACK (dirt, green)", fill=(235,235,235), font=f); d.text((a.width + 2*pad, 4), "RECOLOURED (sand / water, autumn trees, flowers, red hedge)", fill=(235,235,235), font=f)
    s.paste(a.convert("RGB"), (pad, 30 + pad // 2)); s.paste(b.convert("RGB"), (a.width + 2*pad, 30 + pad // 2)); s.save(os.path.join(HERE, "demo_patch.png"))

if __name__ == "__main__":
    palettes(); save_out(); demo_sheet(); demo_patch(); print("ok")
