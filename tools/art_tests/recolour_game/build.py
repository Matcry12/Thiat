"""$0: cut the pack's oaks / flowers / tufts / hedges / stump / logs, recolour per biome with the tables of
tools/art_tests/recolour/recolour.py, write sheets + manifest.json to assets/map/pixel_plains/, previews here.
Pack pixels only. Run: python3 tools/art_tests/recolour_game/build.py"""
import os, sys, json
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art_tests", "recolour"))
import recolour as rc          # tables + swap(); importing it also writes its own out/ files (harmless)
OUT = os.path.join(ROOT, "assets", "map", "pixel_plains")
os.makedirs(OUT, exist_ok=True)
TREES, SHEET = rc.TREES, rc.SHEET
LEAFRGB = {c[:3] for c in rc.LEAF}
SNOW_SHADOW, SNOW_OUTLINE, PALE_TOP = (168, 192, 218, 255), (78, 104, 140, 255), (214, 228, 242, 255)

# ---- oak boxes (x,y,w,h in Trees and bushes.png): (index, size class, suggested age, tone)
OAKS = {  # idx: (size, age)
    10: ("s", "sapling"), 11: ("s", "sapling"), 0: ("m", "young"), 2: ("m", "young"),
    1: ("l", "mature"), 3: ("l", "mature"), 8: ("l_patch", "mature"), 9: ("l_patch", "mature"),
    6: ("tall", "old"), 7: ("tall", "old")}
TONE = {0: "dark", 1: "dark", 6: "dark", 8: "dark", 10: "dark", 2: "light", 3: "light", 7: "light", 9: "light", 11: "light"}
# variant -> (leaf table or None, biomes it is meant for)
OAK_V = {"green": (None, ["plains", "forest", "swamp", "rocky"]),
         "autumn_orange": ("autumn_orange", ["autumn"]), "yellow": ("yellow", ["autumn"]),
         "red": ("red", ["autumn"]), "snow": ("snow", ["snowy"])}
HEDGE_V = {"green": (None, ["plains", "forest"]), "autumn_orange": ("autumn_orange", ["autumn"]),
           "yellow": ("yellow", ["autumn"]), "red": ("red", ["autumn"])}
FLOWER_V = {"pink": (None, ["plains", "forest"]), "blue": ("blue", ["plains", "forest", "taiga"]),
            "yellow": ("yellow", ["plains", "autumn"]), "orange": ("orange", ["autumn"]), "mint": ("MINT", ["swamp", "forest"])}
SNOWTUFT = {rc.C(132,184,65): rc.C(196,212,232), rc.C(63,148,62): rc.C(150,172,204), rc.C(51,107,79): rc.C(120,140,180)}
TUFT_V = {"green": (None, ["plains", "forest", "swamp", "rocky"]), "yellow": ("yellow", ["plains", "autumn"]),
          "brown": ("brown", ["autumn", "rocky", "swamp"]), "snow": ("SNOW", ["snowy", "taiga"])}
STUMP_BIOMES = ["plains", "forest", "autumn", "swamp", "taiga", "rocky"]
ALL_BIOMES = ["plains", "forest", "autumn", "taiga", "swamp", "snowy", "rocky", "beach_sand", "beach_gravel"]
ALL_KINDS = ["oak", "fir", "rock", "bush", "hedge", "flower", "tuft", "mushroom", "reed", "stump", "log"]

def box(im, b): return im.crop((b[0], b[1], b[0] + b[2], b[1] + b[3]))
def edge_mask(op):
    al = np.pad(op, 1); e = np.zeros_like(op)
    for dy in range(3):
        for dx in range(3): e |= ~al[dy:dy + op.shape[0], dx:dx + op.shape[1]]
    return e

def tree_parts(src):
    """-> (shadow colour rgb, shadow mask). Shadow = the shadow colour in the rows BELOW the last canopy row
    (last row holding any other leaf colour). Position-based: the same colour inside the canopy is never touched."""
    a = np.array(src); h = a.shape[0]; rgb = a[..., :3]; op = a[..., 3] > 0
    tail = [tuple(p) for p in rgb[h - 8:][op[h - 8:]].tolist() if tuple(p) in LEAFRGB]
    s = max(set(tail), key=tail.count)          # most common leaf colour near the bottom = shadow colour
    other = np.zeros_like(op)
    for c in LEAFRGB - {s}: other |= op & (rgb == c).all(2)
    cut = int(np.where(other.any(1))[0].max())  # last canopy row
    sh = np.zeros_like(op); sh[cut + 1:] = op[cut + 1:] & (rgb[cut + 1:] == s).all(2)
    return s, sh, cut

def oak(idx, variant):
    src = box(TREES, rc.TREE_BOXES[idx]); tbl = OAK_V[variant][0]
    if tbl is None: return src.copy()
    dst = rc.swap(src, rc.LEAFT[tbl]); s, sh, cut = tree_parts(src)
    a, d = np.array(src), np.array(dst); d[sh] = a[sh]           # shadow lies on grass: original colour
    if variant == "snow":                                        # on snow: blue-grey shadow, one dark outline (minimap.py)
        op = d[..., 3] > 0; rgb = d[..., :3]; snowc = {c[:3] for c in rc.LEAFT["snow"].values()}
        leaf = op & ~sh & np.isin(rgb.reshape(-1, 3).view([("", np.uint8)] * 3).ravel(), np.array(list(snowc), np.uint8).view([("", np.uint8)] * 3).ravel()).reshape(op.shape)
        pale = (rgb == (238, 246, 252)).all(2).sum() > (rgb == (160, 190, 216)).all(2).sum()
        e = edge_mask(op); o = d.copy()
        o[sh] = SNOW_SHADOW; o[leaf & e] = SNOW_OUTLINE; o[cut][leaf[cut]] = SNOW_OUTLINE   # canopy bottom row = outline
        if pale: o[leaf & ~e & (rgb == (238, 246, 252)).all(2)] = PALE_TOP
        d = o
    # self-check (the 'line above the shadow' bug): shadow colour in canopy rows must be recoloured, below untouched
    if variant != "snow":
        same = (d == a).all(2) & (a[..., 3] > 0)
        assert not (same[:cut + 1] & (a[:cut + 1, :, :3] == s).all(2)).any(), (idx, variant, "canopy kept shadow colour")
        assert (d[sh] == a[sh]).all()
    return Image.fromarray(d)

def trunk(src, sh_cut):
    a = np.array(src); h = a.shape[0]; rgb = a[..., :3]; op = a[..., 3] > 0
    s, sh, cut = tree_parts(src)
    t = op & ~sh; t[:cut + 1] = False                            # not canopy, not shadow
    for c in LEAFRGB: t &= ~(rgb == c).all(2)
    ys, xs = np.where(t); base = ys.max()
    bx = np.where(t[base])[0]
    return (xs.min() + xs.max() + 1) / 2, int(base) + 1, int(bx.max() - bx.min() + 1)

def stack(src, variants, tbl_of):
    """vertical stack of recoloured copies of src (same layout per row) -> sheet, row height."""
    h = src.height; sheet = Image.new("RGBA", (src.width, h * len(variants)), (0, 0, 0, 0))
    for r, v in enumerate(variants): sheet.alpha_composite(tbl_of(v), (0, r * h))
    return sheet

manifest = {"version": 1, "note": "region = x,y,w,h in `file`. anchor = foot point (x,y) relative to the region top-left; "
            "collision_radius px (trunk estimate, 0 = no collision). Pack pixels only, recolour only.", "sprites": [], "no_art": {}}
def add(file, kind, v, biomes, region, anchor, radius, **kw):
    manifest["sprites"].append(dict(id=f"{kind}_{kw.get('size', kw.get('piece', kw.get('cell', '')))}_{v}".replace("__", "_") + (f"_{kw['tone']}" if 'tone' in kw else ""),
                                    file=file, kind=kind, variant=v, biome=biomes, region=list(region), anchor=list(anchor), collision_radius=radius, **kw))

# ---- oaks (canvas = pack rows y 0..108 x 0..288, same layout in every variant row)
OV = list(OAK_V); H = 108
sheet = Image.new("RGBA", (288, H * len(OV)), (0, 0, 0, 0))
for r, v in enumerate(OV):
    for idx in OAKS:
        b = rc.TREE_BOXES[idx]; sheet.alpha_composite(oak(idx, v), (b[0], r * H + b[1]))
sheet.save(f"{OUT}/oaks.png")
# same sheet without the ground shadow under the trunk (ResourceNodeData.ground_shadow off picks this one)
ns = np.array(sheet)
for r, v in enumerate(OV):
    for idx in OAKS:
        b = rc.TREE_BOXES[idx]; _, sh, _ = tree_parts(box(TREES, b))
        ys, xs = np.where(sh); ns[r * H + b[1] + ys, b[0] + xs, 3] = 0
Image.fromarray(ns).save(f"{OUT}/oaks_noshadow.png")
for r, v in enumerate(OV):
    for idx, (size, age) in OAKS.items():
        b = rc.TREE_BOXES[idx]; ax, ay, tw = trunk(box(TREES, b), 0)
        rad = max(3, round(tw / 2))   # half the root-flare width at the base row
        add("oaks.png", "oak", v, OAK_V[v][1], (b[0], r * H + b[1], b[2], b[3]), (ax, ay), rad, size=size, age=age, tone=TONE[idx], src_box=idx)

# ---- hedges + stump + logs: pack crop (288,0)-(448,112)
HB = (288, 0, 160, 112); hsrc = box(TREES, HB)
HA = np.array(hsrc)[..., 3] > 0
def tight(x0, y0, x1, y1):   # tight alpha bbox inside a window (pieces touch, so windows are read off the pack picture)
    ys, xs = np.where(HA[y0:y1, x0:x1]); return (x0 + xs.min(), y0 + ys.min(), xs.max() - xs.min() + 1, ys.max() - ys.min() + 1)
HWIN = {"long2": (0,16,64,48), "cap_a": (32,0,48,16), "cap_b": (48,0,64,16), "post": (64,0,80,48),
        "frame": (80,0,128,48), "block": (80,48,128,96), "end": (128,16,160,48)}
pieces = [tight(*w) for w in HWIN.values()]
comps, n = ndimage.label(HA, structure=np.ones((3, 3)))
wood = [p for p in [(x.start, y.start, x.stop - x.start, y.stop - y.start) for y, x in ndimage.find_objects(comps)] if p[0] < 60 and p[1] >= 60 and p[2] * p[3] >= 40]
hedge_p = [p for p in pieces if p not in wood]
hsheet = stack(hsrc, list(HEDGE_V), lambda v: rc.swap(hsrc, rc.LEAFT[HEDGE_V[v][0]]) if HEDGE_V[v][0] else hsrc.copy())
# wood must not be recoloured: paste the original over the wood boxes on every row
for r in range(len(HEDGE_V)):
    for (x, y, w, h) in wood: hsheet.paste(hsrc.crop((x, y, x + w, y + h)), (x, r * HB[3] + y))
hsheet.save(f"{OUT}/hedges.png")
for r, v in enumerate(HEDGE_V):
    for k, (x, y, w, h) in enumerate(hedge_p):
        add("hedges.png", "hedge", v, HEDGE_V[v][1], (x, r * HB[3] + y, w, h), (w / 2, h), 0, piece=list(HWIN)[k])
for (x, y, w, h) in wood:    # stump (y>=90) and two logs; the one at x>=32 has a white selection outline in the pack: skipped
    if x >= 32 and y < 90: continue
    kind = "stump" if y >= 90 else "log"
    add("hedges.png", kind, "orig", STUMP_BIOMES, (x, y, w, h), (w / 2, h - 1), 4 if kind == "stump" else 0, piece="")

# ---- flowers (pink + mint rows, 5x2 cells of 16) and tufts (7x2 cells of 16, light-grass row + dark-grass row)
FB = (0, 32, 80, 64); fsrc = box(SHEET, FB)
def ftbl(v): t = FLOWER_V[v][0]; return fsrc.copy() if t in (None, "MINT") else rc.swap(fsrc, rc.FLOWER[t])
# pink block = rows 0..31, mint block = rows 32..63 (original colours; mint is its own sprite set)
fv = [v for v in FLOWER_V if v != "mint"]
fsheet = Image.new("RGBA", (80, 32 * len(FLOWER_V)), (0, 0, 0, 0)); fr = 0
for v in fv: fsheet.alpha_composite(ftbl(v).crop((0, 0, 80, 32)), (0, fr * 32)); fr += 1
fsheet.alpha_composite(fsrc.crop((0, 32, 80, 64)), (0, fr * 32))
fsheet.save(f"{OUT}/flowers.png")
def cells(sheet_, cw, ch, cols, rows, row_off, name, kind, v, biomes, extra=None):
    for ry in range(rows):
        for cx in range(cols):
            c = np.array(sheet_.crop((cx * cw, row_off + ry * ch, (cx + 1) * cw, row_off + (ry + 1) * ch)))
            if (c[..., 3] > 0).sum() < 3: continue
            ys, xs = np.where(c[..., 3] > 0)
            add(name, kind, v, biomes, (cx * cw, row_off + ry * ch, cw, ch), (8, 8), 0, cell=f"r{ry}c{cx}", ink=[int(xs.min()), int(ys.min()), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)], **(extra or {}))
for i, v in enumerate(fv): cells(fsheet, 16, 16, 5, 2, i * 32, "flowers.png", "flower", v, FLOWER_V[v][1])
cells(fsheet, 16, 16, 5, 2, len(fv) * 32, "flowers.png", "flower", "mint", FLOWER_V["mint"][1])

tsrc = Image.new("RGBA", (112, 32)); tsrc.paste(SHEET.crop((80, 32, 192, 48)), (0, 0)); tsrc.paste(SHEET.crop((80, 64, 192, 80)), (0, 16))
def ttbl(v):
    t = TUFT_V[v][0]; return tsrc.copy() if t is None else rc.swap(tsrc, SNOWTUFT if t == "SNOW" else rc.TUFT[t])
tsheet = stack(tsrc, list(TUFT_V), ttbl); tsheet.save(f"{OUT}/tufts.png")
for r, v in enumerate(TUFT_V):
    for ry, ground in enumerate(["light", "dark"]):   # row 0 = for light grass, row 1 = for dark grass
        cells(tsheet, 16, 16, 7, 1, r * 32 + ry * 16, "tufts.png", "tuft", v, TUFT_V[v][1], dict(on=ground))

# ---- biome x kind coverage
have = {}
for s in manifest["sprites"]:
    for b in s["biome"]: have.setdefault((b, s["kind"]), 0); have[(b, s["kind"])] += 1
manifest["by_biome"] = {b: {k: have[(b, k)] for k in ALL_KINDS if (b, k) in have} for b in ALL_BIOMES}
manifest["no_art"] = {b: [k for k in ALL_KINDS if (b, k) not in have] for b in ALL_BIOMES}
json.dump(manifest, open(f"{OUT}/manifest.json", "w"), indent=1, default=int)
print(len(manifest["sprites"]), "sprites;", "hedge pieces", len(hedge_p), "wood", wood)

# ---- previews
from PIL import ImageFont
def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
BG = (44, 46, 52, 255)
def contact(name, sheet_, labels, rowh, zoom=4):
    f = font(16); lw = 150
    z = sheet_.resize((sheet_.width * zoom, sheet_.height * zoom), Image.NEAREST)
    im = Image.new("RGBA", (lw + z.width + 10, z.height + 10), BG); d = ImageDraw.Draw(im)
    for r, l in enumerate(labels): d.text((6, 8 + r * rowh * zoom + 6), l, fill=(235, 235, 235), font=f); d.line([(0, 5 + r * rowh * zoom), (im.width, 5 + r * rowh * zoom)], fill=(90, 90, 100))
    im.alpha_composite(z, (lw, 8)); im.convert("RGB").save(f"{HERE}/contact_{name}.png")
contact("oak", sheet, [f"oak {v}" for v in OV], H)
contact("hedge", hsheet, [f"hedge {v}" for v in HEDGE_V], HB[3])
contact("flower", fsheet, [f"flower {v}" for v in fv] + ["flower mint"], 32)
contact("tuft", tsheet, [f"tuft {v}" for v in TUFT_V], 32)

# 16x shadow edge, original vs autumn vs snow vs yellow, per oak size (rows cut-3 .. cut+5)
Zs = 16; f = font(14); panels = []
for idx in OAKS:
    src = box(TREES, rc.TREE_BOXES[idx]); _, _, cut = tree_parts(src); y0 = cut - 3; hh = 9
    row = []
    for v in ["orig"] + ["autumn_orange", "yellow", "snow"]:
        im = src if v == "orig" else oak(idx, v)
        bg = Image.new("RGBA", im.size, (110, 170, 90, 255) if v != "snow" else (240, 246, 252, 255)); bg.alpha_composite(im)
        row.append((v, bg.crop((0, y0, im.width, y0 + hh)).resize((im.width * Zs, hh * Zs), Image.NEAREST)))
    panels.append((f"oak idx{idx} {OAKS[idx][0]} {TONE[idx]} (canopy ends row {cut})", row))
W = max(sum(p.width for _, p in r) + 12 * len(r) for _, r in panels); Ht = sum(hh * Zs + 34 for _ in panels)
big = Image.new("RGB", (W, Ht), BG[:3]); d = ImageDraw.Draw(big); y = 0
for lab, row in panels:
    d.text((4, y + 2), lab, fill=(235, 235, 235), font=f); x = 0
    for v, p in row: d.text((x + 4, y + 16), v, fill=(180, 200, 255), font=f); big.paste(p.convert("RGB"), (x, y + 32)); x += p.width + 12
    y += hh * Zs + 34
big.save(f"{HERE}/shadow_fix_16x.png"); print("ok")
