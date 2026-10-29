"""$0 preview: one generated map window drawn with the Pixel Plains 16 px pack (ORIGINAL pixels, no recolour).
Anything the pack lacks is a flat grey box labelled "missing: ...".
  godot --headless --script tools/pixel_plains_dump.gd -- win.json 11 75 256
  python3 tools/asset_viewer/pixel_plains_preview.py win.json docs/demo/pixel_plains_preview.png
"""
import json, random, sys, os, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_plains_tiles as PT
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
import numpy as np

PK = "assets/third_party/pixel_plains/"
B = Image.open(PK + "New Basic Tiles Free.png").convert("RGBA")
T = Image.open(PK + "Trees and bushes.png").convert("RGBA")
GREY = (150, 150, 150, 255)
DARK_BIOMES = {1, 3, 6}  # forest, taiga, swamp
WATER, DIRT, COBBLE, GRASS, BOSS, SAND, SNOW = range(7)
NAMES = {WATER: "water (ocean)", COBBLE: "cobble", SAND: "sand", SNOW: "snow"}

def tile(c, r): return B.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16))
def quad_paste(dst, src, q):
    x, y = (q & 1) * 8, (q >> 1) * 8
    dst.paste(src.crop((x, y, x + 8, y + 8)), (x, y))

def material(c):
    g, b, dirt = c[0], c[1], c[5]
    if g in (DIRT, BOSS) or (g == GRASS and dirt): return "dirt"
    if g == GRASS: return "dark" if b in DARK_BIOMES else "light"
    return None

def sprites():
    m = np.array(T)[..., 3] > 0
    lab, n = ndi.label(m, structure=np.ones((3, 3)))
    boxes = {}
    for i, s in enumerate(ndi.find_objects(lab)):
        boxes[i + 1] = (s[1].start, s[0].start, s[1].stop, s[0].stop)
    return boxes
BX = sprites()
def spr(i): return T.crop(BX[i])
# (dark, lime) per age: sapling potted, young small, small medium-narrow, mature tall-narrow, old big-wide
AGE = {"sapling": (6, 7), "young": (1, 3), "small": (13, 14), "mature": (8, 9), "old": (2, 4)}
STUMP, LOG = spr(16), spr(12)
BUSH = T.crop((320, 0, 336, 16))

def main(win, out):
    d = json.load(open(win)); rng = random.Random(5)
    W, H, x0, y0 = d["w"], d["h"], d["x0"], d["y0"]; cells = d["cells"]; cell = d["cell"]
    def gnd(x, y):
        x -= x0; y -= y0
        return cells[y][x][0] if 0 <= x < W and 0 <= y < H else -1
    def bio(x, y): return cells[y - y0][x - x0][1]
    mats = [[material(cells[cy][cx]) for cx in range(W)] for cy in range(H)]
    # map rule: dark grass never touches dirt, a ring of light grass sits between (8-neighbour)
    ring = [row[:] for row in mats]
    for cy in range(H):
        for cx in range(W):
            if mats[cy][cx] == "dark" and any(mats[y][x] == "dirt" for y in range(max(cy - 1, 0), min(cy + 2, H)) for x in range(max(cx - 1, 0), min(cx + 2, W))):
                ring[cy][cx] = "light"
    mats = ring
    im, st = PT.render(mats, rng)
    base = Image.new("RGBA", im.size, GREY); base.alpha_composite(im); im = base
    grey = collections.defaultdict(list)
    for cy in range(H):
        for cx in range(W):
            g = cells[cy][cx][0]
            if mats[cy][cx] is None:
                nm = NAMES.get(g, "?")
                if g == WATER and (cells[cy][cx][3] or cells[cy][cx][4]): nm = "water (shallow/river/lake)"
                grey[nm].append((cx, cy))
    im = im.resize((W * 32, H * 32), Image.NEAREST)
    dr = ImageDraw.Draw(im)
    font = ImageFont.load_default(size=11)
    def label_box(box, txt):
        dr.rectangle(box, fill=GREY, outline=(90, 90, 90))
        dr.text((box[0] + 2, box[1] + 1), txt, fill=(0, 0, 0), font=font)
    # grey ground: label once per connected region
    miss = collections.Counter({'ground quarter ' + k: v for k, v in st.items()})
    for nm, cl in grey.items():
        mk = np.zeros((H, W), bool)
        for cx, cy in cl: mk[cy, cx] = 1
        lab, n = ndi.label(mk)
        for i in range(1, n + 1):
            ys, xs = np.where(lab == i)
            if len(xs) >= 8:
                k = len(xs) // 2
                order = np.lexsort((xs, ys)); j = order[k]
                dr.text((xs[j] * 32 + 3, ys[j] * 32 + 8), "missing: " + nm, fill=(0, 0, 0), font=font)
        miss[nm] = len(cl)
    # y-sorted things: (base_y_px_x2, draw fn)
    things = []
    def wp(p, r=0): return ((p[0] / cell * 32 - x0 * 32), ((p[1] + r) / cell * 32 - y0 * 32))
    for t in d["trees"]:
        x, y = wp(t["pos"], t["radius"]); tid = t["id"]
        parts = tid.split("_"); age = parts[-1]
        ok = parts[1] == "oak" and len(parts) == 3 and age in AGE
        cx, cy = int(x // 32) + x0, int((y - 2) // 32) + y0
        if ok:
            idx = AGE[age][0 if bio(cx, cy) in DARK_BIOMES else 1] if 0 <= cx - x0 < W and 0 <= cy - y0 < H else AGE[age][1]
            sp = spr(idx).resize((spr(idx).width * 2, spr(idx).height * 2), Image.NEAREST)
            things.append((y, lambda sp=sp, x=x, y=y: im.alpha_composite(sp, (int(x - sp.width / 2), int(y + 6 - sp.height))) if False else im.paste(sp, (int(x - sp.width / 2), int(y + 6 - sp.height)), sp)))
        else:
            nm = "tree " + "_".join(parts[1:])
            miss[nm] += 1
            things.append((y, lambda x=x, y=y, nm=nm: label_box((x - 24, y - 70, x + 24, y), "missing: " + nm.replace("tree ", "tree\n"))))
    for t in d["rocks"]:
        x, y = wp(t["pos"], t["radius"]); miss["rock/ore node (" + t["id"] + ")"] += 1
        things.append((y, lambda x=x, y=y: label_box((x - 16, y - 24, x + 16, y), "missing:\nrock")))
    for t in d["deco"]:
        x, y = wp(t["pos"]); g = t["group"]
        cx_, cy_ = int(x // 32), int(y // 32)
        dk = 0 <= cx_ < W and 0 <= cy_ < H and mats[cy_][cx_] == "dark"   # dark decals (rows 4-5) on dark grass, light (rows 2-3) on light
        if g.startswith("tuft"):
            sp = tile(5 + rng.randrange(7), 4 if dk else 2)
        elif g.startswith("flower"):
            sp = tile(rng.randrange(5), 2 + (g in ("flower_1", "flower_2")) * 2 + rng.randrange(2) * (1 if g in ("flower_0", "flower_1") else 0)) if False else tile(rng.randrange(5), 2 + (int(g[-1]) & 1) + 2 * dk)
        elif g == "bush_green":
            sp = BUSH
        elif t["set"].startswith("stump"):
            sp = STUMP
        else:
            miss[g] += 1; things.append((y, lambda x=x, y=y: dr.rectangle((x - 5, y - 8, x + 5, y), fill=GREY, outline=(90, 90, 90)))); continue
        sp = sp.resize((sp.width * 2, sp.height * 2), Image.NEAREST)
        things.append((y if g.startswith(("bush", "stump")) else y - 9999, lambda sp=sp, x=x, y=y: im.paste(sp, (int(x - sp.width / 2), int(y - sp.height + 4)), sp)))
    for _, f in sorted(things, key=lambda t: t[0]): f()
    # legend strip
    leg = "missing (cells / pieces): " + ", ".join("%s %d" % kv for kv in sorted(miss.items()))
    strip = Image.new("RGBA", (im.width, 40), (30, 30, 30, 255))
    sd = ImageDraw.Draw(strip)
    words, line, y = leg.split(", "), "", 2
    for w in words:
        if sd.textlength(line + w, font=font) > im.width - 8:
            sd.text((4, y), line, fill=(230, 230, 230), font=font); y += 13; line = ""
        line += w + ", "
    sd.text((4, y), line, fill=(230, 230, 230), font=font)
    full = Image.new("RGBA", (im.width, im.height + 40)); full.paste(im, (0, 0)); full.paste(strip, (0, im.height))
    full.convert("RGB").save(out); print("wrote", out, full.size, dict(miss))

main(sys.argv[1], sys.argv[2])
