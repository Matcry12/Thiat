"""Preview ($0, no game code): the look of 5 biomes, one 48x27-cell scene each (16 px cells, x2), with a soft border into
the natural neighbour so the blend is visible. Same pass order and peaked-patch / try logic as biome_preview.py
(clearings, trees, rocks, bushes, flowers, mushrooms, tufts; one random stream per pass). Every number is in BIOMES below
(one row per biome: this table is meant to be ported into BiomeData).
Writes docs/demo/biome_look_{taiga,autumn,snowy,rocky,swamp}.png and docs/demo/biome_looks_sheet.png.

Run: python3 tools/asset_viewer/biome_looks.py
"""
import math
import random
import sys

from PIL import Image, ImageDraw

from biome_preview import peaked
from meadow_preview import ROOT, S, bbox
from world_preview import FILLS, GROUND_TINT, WATER_FILLS, font

W, H = 48, 27                      # scene, cells
PAD_L, PAD_R, PAD_T, PAD_B = 6, 6, 16, 6   # simulated margin: big crowns that start above/left of the scene get drawn
SCALE = 2
BLOCK = 16
KINDS = ["sapling", "young", "small", "mature", "old"]       # small = mature size 3
# catalog: kind -> (size, stage)
KIND_SPEC = {"old": (5, "old"), "mature": (4, "mature"), "small": (3, "mature"), "young": (2, "young"), "sapling": (2, "sapling")}
FOREST_AGE = [(.75, {"old": .5, "mature": .5}), (.60, {"small": .2, "mature": .8}),
              (0, {"young": .5, "sapling": .3, "small": .2})]       # same as Forest: age by local density d
FADE = (0.35, 0.55)                # tree chance fades with d between these (forest-like biomes)
FOREST_ROCK = dict(per_block=.5, mid=(0, 1), mid_kinds=[("boulder", 1)], small=(2, 3), spread=1.5, colors=[("grey", 1)])
BLEND = (8, 20)                    # main-biome weight goes 0 -> 1 between these x cells (scene coords) + wobble
BLEND_WOBBLE = 4.0

# ======================================================================================================== THE TABLE
# ground: [(fill, weight)] mixed by noise; tint: (r,g,b) multiplier; dens: local density d range (drives age, fade)
# trees: [(model 1 oak / 2 fir / 3 pine, season, weight)]; tries per 16x16 block; ring: free cells around a trunk (lone trees)
# group: {model: (lo,hi)} a try of that model seeds a group;  age: [(d_min, {kind: weight})]
# rock: per_block groups; mid = boulders per group (kinds boulder 16px / med 28px / big 30x45), small = stones/pebbles
# bush: per_block patches, tries per patch, spread (+-cells, peaked), pair chance, d range, colours (veg sheet), dead shrubs
# flower: per_block patches, tries, spread, rows (0 orange 1 white 2 blue 3 yellow), in_clear only, fox = foxglove chance
# mush: tries per block, shade (cells from a trunk), group;  tuft: p per cell, sets [(kind tuft/fern, colour, weight)]
# stump: per_block snow stumps;  reed: patches per shore cell, tries, spread, colours
BIOMES = {
    "plains": dict(
        ground=[("grass", 1)], tint=None, dens=(0, .45), fade=False,
        trees=[(1, "green", 1)], tries=.5, ring=3, age=[(0, {"mature": .7, "old": .3})],
        rock=dict(per_block=1.0, mid=(1, 2), mid_kinds=[("boulder", 1)], small=(3, 5), spread=1.5, colors=[("grey", 1)]),
        bush=dict(per_block=.5, tries=1, spread=0, pair=.5, colors=["green"]),
        flower=dict(per_block=.8, tries=50, spread=3, rows=[0, 1, 2, 3], fox=.1),
        tuft=dict(p=1 / 16, sets=[("tuft", "green", 1)])),
    "forest": dict(
        ground=[("grass", 1)], tint=None, dens=(.5, 1), fade=True,
        trees=[(1, "green", .9), (2, "green", .1)], tries=14, group={2: (3, 5)}, age=FOREST_AGE,
        rock=FOREST_ROCK,
        bush=dict(per_block=1.0, tries=6, spread=4, d=(.45, .70), colors=["green"]),
        flower=dict(per_block=.125, tries=20, spread=3, rows=[0, 1, 2, 3], in_clear=True, fox=.1),
        mush=dict(tries=5, shade=2.0, group=(1, 3)),
        tuft=dict(p=1 / 8, sets=[("tuft", "green", 1)])),
    "taiga": dict(
        ground=[("grass", 1)], tint=(.8, .95, .95), dens=(.5, 1), fade=True,
        trees=[(2, "green", .65), (3, "green", .35)], tries=12, age=FOREST_AGE,
        rock=dict(per_block=.6, mid=(0, 1), mid_kinds=[("boulder", 1)], small=(2, 4), spread=1.5, colors=[("grey", 1)]),
        bush=dict(per_block=.4, tries=3, spread=3, d=None, colors=["green"]),
        flower=dict(per_block=.25, tries=6, spread=2, rows=[1, 2]),
        mush=dict(tries=10, shade=2.5, group=(1, 3)),
        tuft=dict(p=1 / 9, sets=[("fern", "green", .7), ("tuft", "green", .3)])),
    "autumn": dict(
        ground=[("grass", 1)], tint=(1.7, 1.0, .5), dens=(.5, 1), fade=True,
        trees=[(1, "yellow", .22), (1, "orange", .28), (3, "yellow", .15), (3, "orange", .2), (3, "red", .15)],
        tries=10, age=FOREST_AGE,
        rock=dict(per_block=.3, mid=(0, 1), mid_kinds=[("boulder", 1)], small=(2, 3), spread=1.5, colors=[("grey", 1)]),
        bush=dict(per_block=1.0, tries=6, spread=4, d=(.45, .8), colors=["yellow", "orange", "red"]),
        flower=dict(per_block=.3, tries=7, spread=2, rows=[0, 3]),
        mush=dict(tries=6, shade=2.0, group=(1, 3)),
        tuft=dict(p=1 / 7, sets=[("tuft", "yellow", .35), ("tuft", "brown", .4), ("fern", "brown", .25)])),
    "snowy": dict(
        ground=[("snow", 1)], tint=None, dens=(.45, 1), fade=False,
        trees=[(1, "snow", .4), (2, "teal", .4), (1, "dead", .12), (2, "dead", .08)], tries=6, age=FOREST_AGE,
        rock=dict(per_block=.5, mid=(0, 1), mid_kinds=[("boulder", 1)], small=(2, 3), spread=1.5, colors=[("grey", 1)]),
        tuft=dict(p=1 / 100, sets=[("tuft", "brown", 1)]),
        stump=dict(per_block=.4)),
    "rocky": dict(
        ground=[("stone", .55), ("dirt", .45)], tint=None, dens=(.4, 1), fade=False,
        trees=[(3, "dead", .5), (1, "dead", .5)], tries=.5, age=[(0, {"mature": .6, "old": .4})],
        rock=dict(per_block=2.6, mid=(2, 5), mid_kinds=[("med", .65), ("big", .35)], small=(3, 6), spread=2.6,
                  colors=[("grey", .6), ("brown", .4)]),
        bush=dict(per_block=.5, tries=1, spread=0, pair=0, dead=True, colors=["green"]),
        tuft=dict(p=1 / 10, sets=[("tuft", "brown", .75), ("fern", "brown", .25)])),
    "swamp": dict(
        ground=[("grass", 1)], tint=(.55, .7, .6), dens=(.4, .9), fade=False,
        trees=[(1, "green", .6), (1, "dead", .4)], tries=4, age=FOREST_AGE,
        mush=dict(tries=7, shade=2.0, group=(1, 3)),
        fox=dict(per_block=.5, count=(1, 3)),
        reed=dict(per_shore=.4, tries=16, spread=2.4, colors=[("green", .7), ("brown", .3)]),
        tuft=dict(p=1 / 8, sets=[("tuft", "green", .5), ("fern", "green", .5)])),
}
# scene: main biome in the middle, neighbour on the left (x small), swamp also has water on the right
SCENES = {
    "taiga": dict(main="taiga", neigh="forest", seed=11, title="Taiga (Forest on the left)"),
    "autumn": dict(main="autumn", neigh="forest", seed=21, title="Autumn forest (Forest on the left)"),
    "snowy": dict(main="snowy", neigh="taiga", seed=31, title="Snowy taiga (Taiga on the left)"),
    "rocky": dict(main="rocky", neigh="plains", seed=41, title="Rocky hills (Plains on the left)"),
    "swamp": dict(main="swamp", neigh="forest", seed=53, title="Swamp (Forest on the left, lake on the right)", water=True),
}
SWAMP_WATER_X = 8                  # water starts this many cells from the right edge (wobbles)
SHORE = 1                          # nothing tall within this many cells of water

COLOR_COL = {"green": 0, "yellow": 3, "orange": 6, "red": 9}      # bush colour column (3 wide)
COLOR_ROW = {"green": 0, "yellow": 3, "brown": 6}                 # tuft / fern / reed row offset


# ======================================================================================================== sprites
def load_art():
    A = lambda p: Image.open(ROOT / p).convert("RGBA")
    veg, rocks, tiles, water = A("assets/map/Vegetation.png"), A("assets/map/Rocks.png"), A("assets/map/Floors_Tiles.png"), A("assets/map/Water_tiles.png")
    cut = lambda sh, b: sh.crop(b)
    art = {"tiles": tiles, "water": water}
    art["bush"] = {c: [cut(veg, bbox(veg, col, a, col + 3, b)) for a, b in [(0, 2), (2, 4)]] for c, col in COLOR_COL.items()}
    art["deadbush"] = [cut(veg, bbox(veg, 12, a, 15, b)) for a, b in [(4, 6), (6, 9)]]
    art["flower"] = [[cut(veg, bbox(veg, c, row, c + 1, row + 1)) for c in range(3, 8)] for row in (23, 24, 25, 26)]
    art["foxglove"] = [cut(veg, bbox(veg, c, 10, c + 1, 12)) for c in (12, 13, 14)]
    art["mush"] = [cut(veg, bbox(veg, c, 21, c + 1, 22)) for c in range(4)]
    tuft, fern, reed = {}, {}, {}
    for col, o in COLOR_ROW.items():
        t = []
        for row in (9, 10, 11):
            for c in range(8):
                if row == 9 and 4 <= c <= 6:
                    continue
                if not veg.crop((c * S, (row + o) * S, c * S + S, (row + o) * S + S)).getbbox():
                    continue
                b = bbox(veg, c, row + o, c + 1, row + o + 1)
                if b[2] - b[0] <= 14 and b[3] - b[1] <= 14:
                    t.append(cut(veg, b))
        tuft[col] = t
        fern[col] = [cut(veg, bbox(veg, 5, 11 + o, 6, 12 + o)), cut(veg, bbox(veg, 6, 11 + o, 7, 12 + o)),
                     cut(veg, bbox(veg, 7, 10 + o, 8, 12 + o))]
        reed[col] = [cut(veg, bbox(veg, c, 10 + o, c + 1, 12 + o)) for c in (8, 9, 10)]
    art["tuft"], art["fern"], art["reed"] = tuft, fern, reed
    # rocks: pieces found by hand-listing the connected shapes (x offset 0 brown, 96 grey)
    pieces = {"big": (1, 18, 31, 63), "med": (34, 18, 62, 47), "boulder": [(64, 16, 80, 32), (80, 16, 96, 32)],
              "small": [(83, 36, 93, 44), (47, 50, 64, 62), (34, 52, 46, 61), (68, 53, 77, 61), (84, 53, 94, 61),
                        (80, 67, 93, 78), (67, 68, 77, 77), (51, 69, 60, 76), (36, 70, 44, 76), (35, 84, 45, 92),
                        (52, 85, 61, 93), (68, 85, 78, 93), (64, 99, 77, 110), (51, 100, 61, 109), (35, 101, 44, 108),
                        (20, 102, 28, 108)],
              "pebble": [(68, 37, 75, 42), (20, 70, 27, 75), (4, 71, 11, 75), (20, 85, 27, 90), (4, 87, 11, 91),
                         (4, 102, 11, 107)]}
    rk = {}
    for col, ox in (("brown", 0), ("grey", 96)):
        d = {}
        for k, v in pieces.items():
            boxes = v if isinstance(v, list) else [v]
            d[k] = [rocks.crop((b[0] + ox, b[1], b[2] + ox, b[3])) for b in boxes]
        d["small"] += d["pebble"]
        rk[col] = d
    art["rock"] = rk
    cat = __import__("json").load(open(ROOT / "data/maps/tree_catalog.json"))
    sheets = {}
    trees = {}
    for e in cat:
        for kind, (size, stage) in KIND_SPEC.items():
            if e["size"] == size and e["stage"] == stage:
                trees.setdefault((e["model"], e["season"], kind), []).append(e)
        if e["stage"] == "stump":
            trees.setdefault((e["model"], e["season"], "stump"), []).append(e)
    art["trees"], art["sheets"] = trees, sheets
    return art


def tree_sprite(art, rng, model, season, kind):
    """Catalog entry for (model, season, kind); falls back to the nearest age kind that exists (dead firs have no saplings)."""
    order = ["stump"] if kind == "stump" else sorted(KINDS, key=lambda k: abs(KINDS.index(k) - KINDS.index(kind)))
    for k in order:
        if (model, season, k) in art["trees"]:
            e = rng.choice(art["trees"][(model, season, k)])
            p = e["sheet"]
            if p not in art["sheets"]:
                art["sheets"][p] = Image.open(ROOT / p).convert("RGBA")
            x0, y0, w, h = e["rect"]
            return art["sheets"][p].crop((x0, y0, x0 + w, y0 + h)), e["trunk_base"], k
    raise KeyError((model, season, kind))


# ======================================================================================================== helpers
def smooth(a, b, v):
    t = min(1.0, max(0.0, (v - a) / (b - a)))
    return t * t * (3 - 2 * t)


def make_noise(rng, period, w, h):
    gw, gh = int(w / period) + 3, int(h / period) + 3
    lat = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    sm = lambda t: t * t * (3 - 2 * t)

    def raw(x, y):
        fx, fy = x / period, y / period
        ix, iy = int(fx), int(fy)
        tx, ty = sm(fx - ix), sm(fy - iy)
        a = lat[iy][ix] * (1 - tx) + lat[iy][ix + 1] * tx
        b = lat[iy + 1][ix] * (1 - tx) + lat[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty
    vals = [raw(x + .5, y + .5) for y in range(h) for x in range(w)]
    lo, hi = min(vals), max(vals)
    return lambda x, y: (raw(min(max(x, 0), w - .01), min(max(y, 0), h - .01)) - lo) / (hi - lo)


def wchoice(r, pairs):
    tot = sum(p[-1] for p in pairs)
    u = r.random() * tot
    for p in pairs:
        u -= p[-1]
        if u <= 0:
            return p
    return pairs[-1]


def n_tries(rng, rate, area):
    v = rate * area
    return int(v) + (rng.random() < v - int(v))


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


# ======================================================================================================== one scene
def render_scene(name, art):
    sc = SCENES[name]
    seed = sc["seed"]
    main, neigh = BIOMES[sc["main"]], BIOMES[sc["neigh"]]
    PW, PH = W + PAD_L + PAD_R, H + PAD_T + PAD_B
    streams = {n: random.Random(seed * 100 + i) for i, n in enumerate(
        ["clear", "tree", "rock", "bush", "flower", "mush", "tuft", "ground", "noise", "fox", "reed", "stump", "wob"])}
    nz = make_noise(streams["noise"], 18, PW, PH)       # density d
    wob = make_noise(streams["wob"], 9, PW, PH)         # blend wobble
    gz = make_noise(streams["noise"], 6, PW, PH)        # ground mix (stone / dirt)

    def wmain(x, y):                                     # weight of the main biome at (x,y) in sim cells
        sx = x - PAD_L + BLEND_WOBBLE * (wob(x, y) - .5) * 2
        return smooth(BLEND[0], BLEND[1], sx)

    water, shore = set(), set()
    if sc.get("water"):
        ph1, ph2 = streams["wob"].uniform(0, 6), streams["wob"].uniform(0, 6)
        for y in range(PH):
            xw = PW - PAD_R - SWAMP_WATER_X + 2.5 * math.sin(y * .33 + ph1) + 1.5 * math.sin(y * .9 + ph2)
            for x in range(PW):
                if x >= xw:
                    water.add((x, y))
        for (x, y) in water:
            for dx in range(-SHORE, SHORE + 1):
                for dy in range(-SHORE, SHORE + 1):
                    if (x + dx, y + dy) not in water:
                        shore.add((x + dx, y + dy))
    keep = water | shore

    occ, trunks, items, counts = {}, [], [], {}
    crop = (PAD_L, PAD_T, PAD_L + W, PAD_T + H)

    def add(kind, img, ax, ay, off):
        items.append((ay, img, ax - off[0], ay - off[1]))
        cx, cy = ax / S, ay / S
        if crop[0] <= cx < crop[2] and crop[1] <= cy < crop[3]:
            counts[kind] = counts.get(kind, 0) + 1

    base_off = lambda im: (im.width // 2, im.height)
    land_ok = lambda c: 0 <= c[0] < PW and 0 <= c[1] < PH and c not in occ and c not in keep

    def biomes_at(x, y):
        wm = wmain(x, y)
        return [(main, wm), (neigh, 1 - wm)]

    def blocks():
        for by in range(0, PH, BLOCK):
            for bx in range(0, PW, BLOCK):
                bw, bh = min(BLOCK, PW - bx), min(BLOCK, PH - by)
                yield bx, by, bw, bh, bw * bh / (BLOCK * BLOCK)

    def tries(rng, getrate, accept_pass=True):
        """Spots for each biome: try rate per block, a spot counts when the biome holds it (soft border)."""
        for b in (main, neigh):
            rate = getrate(b)
            if not rate:
                continue
            for bx, by, bw, bh, area in blocks():
                for _ in range(n_tries(rng, rate, area)):
                    x, y = bx + rng.random() * bw, by + rng.random() * bh
                    wb = wmain(x, y) if b is main else 1 - wmain(x, y)
                    if rng.random() < wb:
                        yield b, x, y

    def dens(b, x, y):
        return b["dens"][0] + (b["dens"][1] - b["dens"][0]) * nz(x, y)

    # ---- 1 clearings (biomes with fade = forest-like), 1 per 40x40 cells
    r = streams["clear"]
    clearings = []
    for _ in range(round(PW * PH / 1600)):
        x, y = r.uniform(PAD_L + 8, PAD_L + W - 4), r.uniform(PAD_T + 4, PAD_T + H - 4)
        for b, wb in biomes_at(x, y):
            if b["fade"] and r.random() < wb:
                clearings.append((x, y, r.uniform(3, 5)))
                break
    counts["clearing"] = sum(1 for c in clearings)
    in_clear = lambda x, y: any(dist((x, y), (cx, cy)) <= cr for cx, cy, cr in clearings)

    # ---- 2 trees
    r = streams["tree"]

    def place_tree(cell, model, season, kind):
        im, trunk, k = tree_sprite(art, r, model, season, kind)
        add(f"tree_{['', 'oak', 'fir', 'pine'][model]}_{season}", im, (cell[0] + .5) * S, (cell[1] + 1) * S - 2, trunk)
        occ[cell] = "trunk"
        trunks.append(cell)

    def trunk_free(c, ring=0):
        if not land_ok(c) or in_clear(c[0] + .5, c[1] + .5):
            return False
        if any((c[0] + dx, c[1] + dy) in occ for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            return False
        return not ring or not any(occ.get((c[0] + dx, c[1] + dy)) == "trunk" and dx * dx + dy * dy <= ring * ring
                                   for dx in range(-ring, ring + 1) for dy in range(-ring, ring + 1))

    def age_kind(b, d):
        for dmin, mix in sorted(b["age"], key=lambda a: -a[0]):
            if d >= dmin:
                return wchoice(r, list(mix.items()))[0]

    for b, x, y in tries(r, lambda b: b.get("tries")):
        d = dens(b, x, y)
        if b["fade"] and r.random() >= smooth(FADE[0], FADE[1], d):
            continue
        model, season, _ = wchoice(r, b["trees"])
        spots = [(x, y)]
        if model in b.get("group", {}):
            for _ in range(r.randint(*b["group"][model]) - 1):
                a, dd = r.uniform(0, math.tau), r.uniform(0, 3)
                spots.append((x + math.cos(a) * dd, y + math.sin(a) * dd))
        for tx, ty in spots:
            if trunk_free((int(tx), int(ty)), b.get("ring", 0)):
                place_tree((int(tx), int(ty)), model, season, age_kind(b, d))

    # ---- 3 rocks
    r = streams["rock"]

    def rock_group(b, x, y):
        rk = b["rock"]
        col = wchoice(r, rk["colors"])[0]
        S_ = art["rock"][col]
        parts = []
        for i in range(r.randint(*rk["mid"])):
            parts.append((wchoice(r, rk["mid_kinds"])[0], x + (r.uniform(-1.3, 1.3) if i else 0), y + (r.uniform(-.7, .7) if i else 0)))
        for _ in range(r.randint(*rk["small"])):
            a, dd = r.uniform(0, math.tau), rk["spread"] * math.sqrt(r.random())
            parts.append(("small", x + math.cos(a) * dd, y + math.sin(a) * dd * .7))
        for k, px, py in parts:
            c = (int(px), int(py))
            if not land_ok(c) or in_clear(px, py):
                continue
            if any(dist((px, py), (t[0] + .5, t[1] + .5)) < 1.5 for t in trunks):
                continue
            im = r.choice(S_[k])
            occ[c] = "rock"
            add(f"rock_{col}_{k}", im, px * S, py * S, base_off(im))

    for b, x, y in tries(r, lambda b: b.get("rock", {}).get("per_block")):
        rock_group(b, x, y)

    # ---- 4 bushes
    r = streams["bush"]

    def put_bush(b, x, y):
        bu = b["bush"]
        if land_ok((int(x), int(y))) and not in_clear(x, y):
            if bu.get("dead"):
                im = r.choice(art["deadbush"])
            else:
                im = r.choice(art["bush"][r.choice(bu["colors"])])
            occ[(int(x), int(y))] = "bush"
            add("bush_dead" if bu.get("dead") else "bush", im, x * S, y * S, base_off(im))
            return True
        return False

    for b, x, y in tries(r, lambda b: b.get("bush", {}).get("per_block")):
        bu = b["bush"]
        if bu.get("d") and not (bu["d"][0] <= dens(b, x, y) <= bu["d"][1]):
            continue
        if bu["tries"] > 1:
            for _ in range(bu["tries"]):
                put_bush(b, x + peaked(r, bu["spread"] * 2), y + peaked(r, bu["spread"] * 2))
        elif put_bush(b, x, y) and r.random() < bu.get("pair", 0):
            a = r.uniform(0, math.tau)
            put_bush(b, x + math.cos(a) * 1.6, y + math.sin(a) * 1.6)

    # ---- 5 flowers
    r = streams["flower"]

    def patch(b, x, y):
        fl = b["flower"]
        row, pts = r.choice(fl["rows"]), []
        for _ in range(fl["tries"]):
            px, py = x + peaked(r, fl["spread"]), y + peaked(r, fl["spread"])
            if land_ok((int(px), int(py))) and all(dist((px, py), q) >= 1.0 for q in pts):
                pts.append((px, py))
                im = art["flower"][row][r.randrange(5)]
                add("flower", im, px * S, py * S, base_off(im))
        if r.random() < fl.get("fox", 0):
            for _ in range(r.randint(2, 3)):
                a = r.uniform(0, math.tau)
                px, py = x + math.cos(a) * fl["spread"], y + math.sin(a) * fl["spread"]
                if land_ok((int(px), int(py))):
                    im = r.choice(art["foxglove"])
                    add("foxglove", im, px * S, py * S, base_off(im))

    for b, x, y in tries(r, lambda b: b.get("flower", {}).get("per_block")):
        if b["flower"].get("in_clear") and not in_clear(x, y):
            continue
        patch(b, x, y)
    r = streams["fox"]
    for b, x, y in tries(r, lambda b: b.get("fox", {}).get("per_block")):
        for _ in range(r.randint(*b["fox"]["count"])):
            px, py = x + peaked(r, 3), y + peaked(r, 3)
            if land_ok((int(px), int(py))):
                im = r.choice(art["foxglove"])
                add("foxglove", im, px * S, py * S, base_off(im))

    # ---- 6 mushrooms
    r = streams["mush"]
    for b, x, y in tries(r, lambda b: b.get("mush", {}).get("tries")):
        m = b["mush"]
        for _ in range(r.randint(*m["group"])):
            px, py = x + r.uniform(-1, 1), y + r.uniform(-1, 1)
            if land_ok((int(px), int(py))) and any(dist((px, py), (t[0] + .5, t[1] + .5)) <= m["shade"] for t in trunks):
                im = r.choice(art["mush"])
                add("mushroom", im, px * S, py * S, base_off(im))

    # ---- snow stumps + cattail clusters (new passes, after the agreed ones, so they never move trees)
    r = streams["stump"]
    for b, x, y in tries(r, lambda b: b.get("stump", {}).get("per_block")):
        c = (int(x), int(y))
        if land_ok(c):
            model = r.choice([1, 1, 2, 3])
            im, trunk, _ = tree_sprite(art, r, model, "snow", "stump")
            add("stump_snow", im, (c[0] + .5) * S, (c[1] + 1) * S - 2, trunk)
            occ[c] = "trunk"
    r = streams["reed"]
    for (x, y) in sorted(shore):
        if (x, y) in water or not (0 <= x < PW and 0 <= y < PH):
            continue
        rd = main["reed"]
        if r.random() < rd["per_shore"]:
            col = wchoice(r, rd["colors"])[0]
            for _ in range(rd["tries"]):
                px, py = x + .5 + peaked(r, rd["spread"] * 2), y + .5 + peaked(r, rd["spread"] * 2)
                c = (int(px), int(py))
                if c not in occ and c not in water and 0 <= c[0] < PW and 0 <= c[1] < PH \
                        and any(dist(c, wc) <= 3.2 for wc in ((x + dx, y + dy) for dx in (-3, 0, 3) for dy in (-3, 0, 3)) if wc in water):
                    im = r.choice(art["reed"][col])
                    occ[c] = "reed"
                    add("reed", im, px * S, py * S, base_off(im))

    # ---- 7 tufts
    r = streams["tuft"]
    for cy in range(PH):
        for cx in range(PW):
            if (cx, cy) in occ or (cx, cy) in water:
                continue
            wm = wmain(cx + .5, cy + .5)
            b = main if r.random() < wm else neigh
            tf = b.get("tuft")
            if not tf:
                continue
            p = tf["p"]
            near = any(occ.get((cx + dx, cy + dy)) == "trunk" for dx in range(-2, 3) for dy in range(-2, 3)) or \
                any(occ.get((cx + dx, cy + dy)) == "rock" for dx in range(-1, 2) for dy in range(-1, 2))
            if near:
                p *= 2
            if r.random() < p:
                kind, col, _ = wchoice(r, tf["sets"])
                im = r.choice(art[kind][col])
                add("tuft" if kind == "tuft" else "fern", im, (cx + r.random()) * S, (cy + .6 + r.random() * .4) * S, base_off(im))

    # ---- ground
    gr = streams["ground"]
    bn = make_noise(random.Random(seed + 7), 2.2, PW, PH)   # clumpy threshold for the ground blend

    def ground_tile(b, cx, cy):
        fill = b["ground"][0][0]
        if len(b["ground"]) > 1:       # stone / dirt mixed by noise (clumps)
            share = b["ground"][0][1]
            fill = b["ground"][0][0] if gz(cx, cy) < share else b["ground"][1][0]
        c = gr.choice(FILLS[fill])
        t = art["tiles"].crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
        for op in (Image.FLIP_LEFT_RIGHT, Image.FLIP_TOP_BOTTOM, Image.TRANSPOSE):
            if gr.random() < .5:
                t = t.transpose(op)
        if b["tint"]:
            px = t.load()
            for yy in range(S):
                for xx in range(S):
                    p = px[xx, yy]
                    px[xx, yy] = tuple(min(255, int(p[i] * b["tint"][i])) for i in range(3)) + (p[3],)
        return t

    img = Image.new("RGBA", (PW * S, PH * S))
    for cy in range(PH):
        for cx in range(PW):
            if (cx, cy) in water:
                c = gr.choice(WATER_FILLS)
                t = art["water"].crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
            else:
                wm = wmain(cx + .5, cy + .5)
                ta, tb = ground_tile(main, cx, cy), ground_tile(neigh, cx, cy)
                if wm >= .999:
                    t = ta
                elif wm <= .001:
                    t = tb
                else:       # soft border: 8x8 px patches of either ground; clumpy threshold noise, chance = weight
                    m = Image.new("L", (S, S))
                    mp = m.load()
                    for by in range(0, S, 8):
                        for bx in range(0, S, 8):
                            v = 255 if wm > .15 + .7 * bn(cx + (bx + 4) / S, cy + (by + 4) / S) else 0
                            for yy in range(8):
                                for xx in range(8):
                                    mp[bx + xx, by + yy] = v
                    t = Image.composite(ta, tb, m)
            img.alpha_composite(t, (cx * S, cy * S))
    for _, s, x, y in sorted(items, key=lambda i: i[0]):
        img.paste(s, (round(x), round(y)), s)
    out = img.crop((PAD_L * S, PAD_T * S, (PAD_L + W) * S, (PAD_T + H) * S)).resize((W * S * SCALE, H * S * SCALE), Image.NEAREST).convert("RGB")
    return out, counts


def main_():
    art = load_art()
    out = ROOT / "docs/demo"
    shots = {}
    for name in SCENES:
        im, counts = render_scene(name, art)
        im.save(out / f"biome_look_{name}.png")
        shots[name] = im
        trees = sum(v for k, v in counts.items() if k.startswith("tree"))
        print(f"{name}: trees {trees} | " + ", ".join(f"{k} {v}" for k, v in sorted(counts.items())))
    # sheet: 2 columns, scaled to 0.6, titled
    k = .6
    tw, th = int(W * S * SCALE * k), int(H * S * SCALE * k)
    f, pad, tt = font(18), 12, 30
    cols, rows = 2, 3
    sheet = Image.new("RGB", (cols * (tw + pad) + pad, rows * (th + tt + pad) + pad), (24, 24, 28))
    dr = ImageDraw.Draw(sheet)
    for i, name in enumerate(SCENES):
        x, y = pad + (i % cols) * (tw + pad), pad + (i // cols) * (th + tt + pad)
        dr.text((x, y + 4), SCENES[name]["title"], fill="white", font=f)
        sheet.paste(shots[name].resize((tw, th), Image.LANCZOS), (x, y + tt))
    sheet.save(out / "biome_looks_sheet.png")


if __name__ == "__main__":
    main_()
