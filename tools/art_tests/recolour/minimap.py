"""Mini map demo ($0): 48x32 cells, hand-placed zones, recoloured pack ground + trees + v3 water (animated).
Run: python3 tools/art_tests/recolour/minimap.py -> minimap.png (3x still), minimap.gif (8 frames, 8 fps).
Every ground border is the pack's dual-grid light_on_dirt / dark_on_light quarters (dirt recoloured per zone).
Known gap shown on purpose: sand<->water has no art -> one spot with a naive hard seam, labelled."""
import random, math
import numpy as np
from PIL import Image, ImageDraw
import recolour as rc, water as wt
import pixel_plains_tiles as pp

W, H, CELL, ZOOM = 48, 32, 16, 3
FRAMES, FPS = wt.FRAMES, wt.FPS
rng = random.Random(7)

# ---------- layout ----------
grid = [["light"] * W for _ in range(H)]
kind = [[None] * W for _ in range(H)]        # dirt cells only: path | sand | snow | water
def ell(cx, cy, rx, ry, ph, fn):
    for y in range(H):
        for x in range(W):
            a = math.atan2(y - cy, x - cx); k = 1 + 0.14 * math.sin(3 * a + ph)
            if ((x - cx) / (rx * k)) ** 2 + ((y - cy) / (ry * k)) ** 2 < 1: fn(x, y)
def dark(x, y): grid[y][x] = "dark"
def put(k):
    def f(x, y): grid[y][x] = "dirt"; kind[y][x] = k
    return f
for cx, cy, rx, ry, ph in [(26, 25, 4, 2.5, 1), (9, 24, 6, 4, 2), (17, 5, 3.5, 2, 3), (43, 25, 5, 4, 4), (30, 28, 3, 2, 5)]: ell(cx, cy, rx, ry, ph, dark)
ell(5, 4, 7.5, 5.5, 0.5, put("snow"))
ell(36, 8, 6.5, 4, 1.7, put("water"))
ell(33, 18.5, 5, 3, 2.6, put("sand"))
for x in range(34, 36):                       # the ONE sand<->water contact: water down to y13, sand from y14
    for y in (12, 13): put("water")(x, y)
    for y in range(14, 18): put("sand")(x, y)
ell(21.5, 17.5, 3, 2.2, 0.9, put("path"))
def brush(x, y):
    for dx in (0, 1):
        for dy in (0, 1):
            if 0 <= x + dx < W and 0 <= y + dy < H: put("path")(x + dx, y + dy)
pts = [(22, 31), (22, 25), (21, 19), (21, 15), (18, 11), (17, 10)]
for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
    n = max(abs(x1 - x0), abs(y1 - y0))
    for i in range(n + 1): brush(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n))
# map rule: dark grass never touches dirt-like ground (ring of light grass)
for y in range(H):
    for x in range(W):
        if grid[y][x] == "dark" and any(grid[min(max(y + dy, 0), H - 1)][min(max(x + dx, 0), W - 1)] == "dirt" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
            grid[y][x] = "light"

# ---------- ground: dual-grid render, then recolour dirt per zone (tile by tile) ----------
raw, stats = pp.render(grid, random.Random(3))
print("render stats (missing / 3-way):", stats)
plain_dirt = pp.quarter(*pp.PLAIN_Q["dirt"]); plain_light = pp.quarter(*pp.PLAIN_Q["light"])
TBL = {"sand": rc.GROUND["sand"], "snow": rc.GROUND["snow"], "water": rc.GROUND["water"], "path": None}
cg = lambda x, y: (grid[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)], kind[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)])
# Height order: dirt / sand / path / water < light grass < dark grass < SNOW. Snow is a blanket ON the grass: its border uses the
# light_on_dirt quarters with the masks swapped (snow cells = upper), upper light grass -> snow, lower dirt -> plain light grass.
SNOW_ON_TOP = True   # False = old look (snow = recoloured dirt, sits BELOW the grass like a hole)
SNOW_TOP = {rc.C(99, 171, 63): rc.C(240, 246, 252),    # upper fill -> snow fill
            rc.C(164, 196, 67): rc.C(255, 255, 255),   # upper highlight -> white
            rc.C(42, 89, 79): rc.C(150, 170, 204),     # upper outline -> pale blue-grey rim
            rc.C(189, 106, 98): rc.C(59, 125, 79),     # shadow the upper layer casts -> grass shadow green (pack's dark grass)
            rc.C(240, 181, 65): rc.C(99, 171, 63)}     # lower dirt -> plain light grass
def paint(base, on_top):
  for j in range(H + 1):
    for i in range(W + 1):
        cells = [cg(i - 1, j - 1), cg(i, j - 1), cg(i - 1, j), cg(i, j)]
        ks = {k for g, k in cells if g == "dirt"}
        if not ks: continue
        x0, y0 = i * CELL - 8, j * CELL - 8
        if on_top and ks == {"snow"} and {g for g, k in cells} == {"dirt", "light"}:   # snow over light grass
            mask = sum(b for b, (g, k) in zip((1, 2, 4, 8), cells) if g == "dirt")
            base.paste(rc.swap(pp.tile_image("light_on_dirt", mask)[0], SNOW_TOP), (x0, y0)); continue
        if len(ks) == 1:
            t = TBL[next(iter(ks))]
            if t:
                box = (max(x0, 0), max(y0, 0), min(x0 + 16, W * CELL), min(y0 + 16, H * CELL))
                base.paste(rc.swap(base.crop(box), t), box[:2])
        else:                                   # two ground kinds meet: no edge art exists -> naive hard seam per quadrant
            for q, (g, k) in enumerate(cells):
                tile = plain_dirt if g == "dirt" else plain_light
                if g == "dirt" and TBL[k]: tile = rc.swap(tile, TBL[k])
                qx, qy = x0 + (q & 1) * 8, y0 + (q >> 1) * 8
                if 0 <= qx <= W * CELL - 8 and 0 <= qy <= H * CELL - 8: base.paste(tile, (qx, qy))
  return base
base, alt = paint(raw.copy(), SNOW_ON_TOP), paint(raw.copy(), not SNOW_ON_TOP)   # alt = the other snow look, for snow_compare.png

# ---------- objects ----------
def free(cx, cy, r=1, ok=(None,)):
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            x, y = cx + dx, cy + dy
            if not (0 <= x < W and 0 <= y < H): return False
            if kind[y][x] not in ok: return False
    return True
SHADOW_GREEN = {(42, 89, 79), (59, 125, 79)}
PALE_TOP = (214, 228, 242, 255)
def tree(idx, v):
    t = rc.tree_swap(rc.TREE_BOXES[idx], rc.LEAFT[v]) if v else rc.box(rc.TREES, rc.TREE_BOXES[idx])
    if v == "snow":   # tree stands on snow: green ground shadow -> blue-grey shadow; ONE dark outline on every snow tree
        a, snowc = np.array(t), {c[:3] for c in rc.LEAFT["snow"].values()}
        rgb, op = a[..., :3], a[..., 3] > 0
        leaf = op & np.isin(rgb.view([("", rgb.dtype)] * 3).ravel(), np.array(list(snowc), np.uint8).view([("", np.uint8)] * 3).ravel()).reshape(op.shape)
        green = op & np.any([(rgb == g).all(2) for g in SHADOW_GREEN], 0)
        under = np.zeros_like(leaf); under[1:] = leaf[:-1]           # pale variant: its canopy's bottom edge is green -> outline, not shadow
        al = np.pad(op, 1); edge = np.zeros_like(op)
        for dy in range(3):
            for dx in range(3): edge |= ~al[dy:dy + op.shape[0], dx:dx + op.shape[1]]
        pale = (rgb == (238, 246, 252)).all(2).sum() > (rgb == (160, 190, 216)).all(2).sum()
        out = a.copy()
        out[green & ~under] = (168, 192, 218, 255)
        out[(leaf & edge) | (green & under)] = (78, 104, 140, 255)       # leaf touching the outside (8-neighbour) or the canopy's bottom edge
        if pale: out[leaf & ~edge & (rgb == (238, 246, 252)).all(2)] = PALE_TOP   # pale top fill must stand off the snow ground (240,246,252)
        t = Image.fromarray(out)
    return t
TI = [0, 1, 2, 3, 6, 7, 10, 11]
objs, placed, rects, leaves = [], [], [], []   # objs: (base_y, image, x, y); rects = whole picture boxes; leaves = leaf-only boxes (snow trees: inside the dark outline)
def overlaps(x, y, w, h):   # canopies may overlap by at most 3 px
    return any(min(x + w, a + c) - max(x, a) > 3 and min(y + h, b + e) - max(y, b) > 3 for a, b, c, e in rects)
def try_tree(cx, cy, v, spacing, ok=(None,), r=1):
    if not free(cx, cy, r, ok): return False
    px, py = cx * CELL + 8 + rng.randint(-3, 3), cy * CELL + 15
    if any((px - a) ** 2 + (py - b) ** 2 < spacing ** 2 for a, b in placed): return False   # trunks >= spacing px apart
    t = tree(rng.choice(TI), v); x, y = px - t.width // 2, py - t.height + 1
    if overlaps(x, y, t.width, t.height): return False
    objs.append((py, t, x, y)); placed.append((px, py)); rects.append((x, y, t.width, t.height))
    lo = np.argwhere((np.array(t)[..., :3] == (78, 104, 140)).all(2)) if v == "snow" else np.zeros((0, 2), int)
    leaves.append((x + lo[:, 1].min(), y + lo[:, 0].min(), np.ptp(lo[:, 1]) + 1, np.ptp(lo[:, 0]) + 1) if len(lo) else (x, y, t.width, t.height)); return True
def scatter(n, region, pick, spacing, ok=(None,), r=1, tries=4000):
    done = 0
    for _ in range(tries):
        if done >= n: break
        cx, cy = rng.randint(region[0], region[2]), rng.randint(region[1], region[3])
        v = pick(cx, cy)
        if v == "skip": continue
        done += try_tree(cx, cy, v, spacing, ok, r)
    return done
# plains: green oaks, sparse; forest east (blends via x gradient); snow corner; a few green trees by the snow
scatter(16, (14, 12, 36, 31), lambda x, y: None, 48)
def forest_pick(x, y):
    if rng.random() > (x - 36) / 5: return "skip"
    return rng.choices([None, "autumn_orange", "yellow", "red"], [1, 45, 30, 14])[0]
scatter(80, (36, 14, 47, 31), forest_pick, 40)
scatter(7, (0, 0, 13, 9), lambda x, y: "snow", 44, ok=("snow",))
scatter(4, (12, 0, 20, 14), lambda x, y: None, 44)
scatter(3, (0, 12, 12, 31), lambda x, y: None, 44)
# hedges in the forest
def hedge_piece(table, crop, cx, cy):
    im = rc.hedge(table).crop(crop); px, py = cx * CELL, cy * CELL + 15
    cw, chh = -(-im.width // CELL), -(-im.height // CELL)
    if all(free(cx + i, cy, 0) and free(cx + i, cy - 1, 0) for i in range(cw)) and not overlaps(px, py - im.height + 1, im.width, im.height):
        objs.append((py, im, px, py - im.height + 1)); placed.append((px + im.width // 2, py)); rects.append((px, py - im.height + 1, im.width, im.height)); return True
for tbl, crop, (cx, cy) in [("autumn_orange", (1, 16, 64, 48), (40, 20)), ("yellow", (1, 16, 64, 48), (41, 29)), ("yellow", (64, 0, 80, 48), (45, 24))]:
    ok = False
    for dx in range(0, 4):
        for dy in range(0, 3):
            if not ok: ok = hedge_piece(rc.LEAFT[tbl], crop, cx + dx, cy + dy)
# decals: flowers + tufts
def tiles(sheet_y, cols):
    out = []
    for c in cols:
        t = rc.SHEET.crop((c * 16, sheet_y * 16, c * 16 + 16, sheet_y * 16 + 16))
        if np.array(t)[:, :, 3].sum() > 255 * 6: out.append(t)
    return out
pinkT = tiles(2, range(5)) + tiles(3, range(5)); whiteT = tiles(4, range(5)) + tiles(5, range(5))
tuftT = tiles(2, range(5, 12)) + tiles(4, range(5, 12))
deco = []
LEAF_GAP = 4   # snow specks / tufts keep this many px from any leaf (trunk + ground shadow may touch)
def near_canopy(x, y, m=0, sz=CELL, boxes=None):   # sz x sz box at (x, y) overlaps a canopy box grown by m px
    if isinstance(sz, int): sz = (sz, sz)
    return any(min(x + sz[0], a + c + m) - max(x, a - m) > 0 and min(y + sz[1], b + e + m) - max(y, b - m) > 0 for a, b, c, e in (rects if boxes is None else boxes))
def ink_box(t, plain=None):   # tight box of the visible pixels of a decal tile (alpha, or not plain ground)
    a = np.array(t); m = a[..., 3] > 0 if plain is None else ~(a[..., :3] == plain).all(2)
    yx = np.argwhere(m); return (0, 0, 0, 0) if not len(yx) else (yx[:, 1].min(), yx[:, 0].min(), np.ptp(yx[:, 1]) + 1, np.ptp(yx[:, 0]) + 1)
def decal(n, region, pool, tries=3000, ok=(None,), leaf=False):   # leaf: only the tuft's own pixels must keep LEAF_GAP from leaves
    d = 0
    for _ in range(tries):
        if d >= n: break
        cx, cy = rng.randint(region[0], region[2]), rng.randint(region[1], region[3])
        t = rng.choice(pool)
        if leaf:
            bx, by_, bw, bh = ink_box(t)
            if near_canopy(cx * CELL + bx, cy * CELL + by_, LEAF_GAP, (bw, bh), leaves): continue
        elif near_canopy(cx * CELL, cy * CELL): continue   # nothing under a canopy
        if not free(cx, cy, 1, ok) or (cx, cy) in [c[:2] for c in deco]: continue
        deco.append((cx, cy, t)); d += 1
pk = lambda tb: [rc.swap(t, tb) for t in pinkT]
decal(14, (14, 11, 37, 31), pinkT); decal(8, (14, 11, 37, 31), whiteT)
decal(8, (14, 11, 37, 31), pk(rc.FLOWER["blue"])); decal(6, (14, 11, 37, 31), pk(rc.FLOWER["yellow"]))
decal(40, (0, 11, 37, 31), tuftT)
decal(30, (36, 14, 47, 31), [rc.swap(t, rc.TUFT["yellow"]) for t in tuftT]); decal(14, (36, 14, 47, 31), [rc.swap(t, rc.TUFT["brown"]) for t in tuftT])
decal(4, (36, 14, 47, 31), pk(rc.FLOWER["orange"]))
decal(6, (0, 12, 13, 31), pinkT); decal(6, (0, 12, 13, 31), tuftT)
srng = random.Random(11); specks = []
PLAIN_SNOW, SPECK_CHANCE = (240, 246, 252), 0.24   # chance per inner snow tile; tries that would touch leaves are dropped -> ~14% kept
for j in range(1, H):
    for i in range(1, W):
        cells = [cg(i - 1, j - 1), cg(i, j - 1), cg(i - 1, j), cg(i, j)]
        if all(k == "snow" for g, k in cells) and srng.random() < SPECK_CHANCE:
            c, r = srng.choice(pp.VARIANTS["dirt"][:3] + [(9, 0)])
            t = rc.swap(pp.SHEET.crop((c*16, r*16, c*16+16, r*16+16)), TBL["snow"]); bx, by_, bw, bh = ink_box(t, PLAIN_SNOW)
            if near_canopy(i * CELL - 8 + bx, j * CELL - 8 + by_, LEAF_GAP, (bw, bh), leaves): continue   # speck would touch leaves
            specks.append((i * CELL - 8 + bx, j * CELL - 8 + by_, bw, bh))
            for im in (base, alt): im.paste(t, (i * CELL - 8, j * CELL - 8))
# the ground render's own specks: wipe only the ones in the LEAF_GAP ring round each snow canopy (inner snow only, borders untouched)
inner = lambda x, y: all(cg(x // CELL + dx, y // CELL + dy)[1] == "snow" for dx in (-1, 0, 1) for dy in (-1, 0, 1))
def wipe(im):
    ba = np.array(im)
    for lx, ly, lw, lh in leaves:
        for y in range(max(ly - LEAF_GAP, 0), min(ly + lh + LEAF_GAP, H * CELL)):
            for x in range(max(lx - LEAF_GAP, 0), min(lx + lw + LEAF_GAP, W * CELL)):
                if inner(x, y) and tuple(ba[y, x, :3]) in {(214, 228, 242), (150, 170, 204)}: ba[y, x, :3] = PLAIN_SNOW
    return Image.fromarray(ba)
base, alt = wipe(base), wipe(alt)

SNOWTUFT = {rc.C(132,184,65): rc.C(196,212,232), rc.C(63,148,62): rc.C(150,172,204), rc.C(51,107,79): rc.C(120,140,180)}
decal(7, (0, 0, 12, 9), [rc.swap(t, SNOWTUFT) for t in tuftT], ok=("snow",), leaf=True)   # snow: keep LEAF_GAP px from leaves
layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
for cx, cy, t in deco: layer.alpha_composite(t, (cx * CELL, cy * CELL))
for by, im, x, y in sorted(objs, key=lambda o: o[0]): layer.alpha_composite(im, (x, y))

# ---------- water (v3, shadowfix) on the ground, objects on top ----------
LAKE = (28 * CELL, 2 * CELL, 46 * CELL, 17 * CELL)
lake_cells = np.array([[kind[y][x] == "water" for x in range(28, 46)] for y in range(2, 17)])
wf = lambda **k: wt.water_frames(base.convert("RGBA"), True, FRAMES, True, rect=LAKE, **k)[0]
frames = wf()                                  # default style: flat_plain (no deep)
rectf, softf, patf = wf(style="flat_rect"), wf(style="flat_rect_edge"), wf(style="flat_rect_pattern")
for f in frames + [rectf[0], softf[0], patf[0]]: f.alpha_composite(layer)
Z = lambda im: im.resize((im.width * ZOOM, im.height * ZOOM), Image.NEAREST)

cbox = (26 * CELL, 2 * CELL, 46 * CELL, 17 * CELL)
ims = [Z(x.crop(cbox)).convert("RGB") for x in (rectf[0], softf[0], patf[0])]; pad = 20; fc = rc.font(26)
cmp_ = Image.new("RGB", (ims[0].width * 3 + 4 * pad, ims[0].height + 2 * pad + 30), rc.BG); dc = ImageDraw.Draw(cmp_)
for k, (n, im) in enumerate(zip(['1 flat_rect (plain)', '2 flat_rect_edge (dotted line)', '3 flat_rect_pattern (notches only)'], ims)):
    dc.text((pad + k * (im.width + pad), 4), n, fill=(235, 235, 235), font=fc); cmp_.paste(im, (pad + k * (im.width + pad), 40))
cmp_.save("water_flat_compare.png")

# snow corner, old vs new height order
SBOX = (0, 0, 15 * CELL, 11 * CELL)
sc = {}
for on, im in ((SNOW_ON_TOP, base), (not SNOW_ON_TOP, alt)):
    g = im.convert("RGBA"); g.alpha_composite(layer); sc[on] = Z(g.crop(SBOX)).convert("RGB")
sw = sc[True].width; scmp = Image.new("RGB", (2 * sw + 3 * pad, sc[True].height + 2 * pad + 30), rc.BG); ds = ImageDraw.Draw(scmp)
for k, (on, n) in enumerate(((False, "old: snow below grass"), (True, "new: snow on top of grass"))):
    ds.text((pad + k * (sw + pad), 4), n, fill=(235, 235, 235), font=fc); scmp.paste(sc[on], (pad + k * (sw + pad), 40))
scmp.save("snow_compare.png")

# still with the missing-art label
still = Z(frames[0]).convert("RGB"); d = ImageDraw.Draw(still); fnt = rc.font(30)
x0, y0, x1, y1 = 33 * CELL * ZOOM, 12 * CELL * ZOOM, 38 * CELL * ZOOM, 16 * CELL * ZOOM
d.rectangle((x0, y0, x1, y1), outline=(255, 60, 60), width=4)
txt = "missing: sand<->water edge"; tw = d.textlength(txt, font=fnt)
d.rectangle((x0 - 6, y1 + 8, x0 + tw + 10, y1 + 52), fill=(30, 30, 36)); d.text((x0, y1 + 12), txt, fill=(255, 120, 120), font=fnt)
still.save("minimap.png")
g = [Z(f).convert("RGB") for f in frames]
g[0].save("minimap.gif", save_all=True, append_images=g[1:], duration=[130, 120] * (FRAMES // 2), loop=0)   # GIF counts 10 ms: 130/120 = 125 ms avg, loop = 1.000 s
print("ok", still.size, "trees", len(objs), "decals", len(deco))
