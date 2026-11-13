# RETIRED with the old map art (Floors_Tiles / Rocks / Water_tiles / Vegetation are in assets/retired/map/ and assets/source/map/). Kept as the reference of the GDScript ports (MapGen, BiomeVeg).
"""Preview: where trees, bushes, flowers, tufts and stones go on the grass (placement rules, $0, before any game code).
One smooth "forest density" field d (0..1) drives everything. Writes two pictures:
  docs/demo/meadow_preview.png          the field
  docs/demo/meadow_preview_density.png  same field, d as a translucent tint (blue meadow ... red dense forest)
All rule numbers are the constants below. Sprites sit at bottom-centre and are drawn sorted by bottom y.

Run: python3 tools/asset_viewer_retired/meadow_preview.py [seed]   (default seed 7)
"""
import math
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
S = 16
W, H = 48, 30                      # field size in cells
SCALE = 2                          # output zoom (nearest)
GRASS_FILLS = [(1, 10), (2, 10), (3, 10)]

# --- density field
NOISE_PERIOD = 15                  # cells per blob (low frequency)
EDGE_NOISE_PERIOD = 4              # second, higher-frequency layer: wobbles the forest edge
EDGE_NOISE_AMP = 0.35              # how far it moves d (0..1 scale)
CLEAR_W, CLEAR_H = 5, 4            # home clearing, cells, centred
CLEAR_MARGIN = 1.0                 # extra cells around the clearing kept free of trees/bushes/stones/flowers

# --- trees: the thick round crowns (Vegetation.png bushes, 2 biggest sizes), packed into one mass
FOREST_D = 0.55                    # d above this = forest
TREE_LARGE_SHARE = 0.7             # rest uses the second-biggest size
TREE_STEP_X = 0.65                 # step as a fraction of the large sprite width
TREE_STEP_Y = 0.5                  #   and of its height
TREE_JITTER = 0.25                 # +- fraction of the step, random offset per tree
TREE_MIN_Y = 2.0                   # anchors above this are skipped (crown would leave the picture)
LONE_TREES = 5                     # single round trees just outside the edge
LONE_D_MIN, LONE_D_MAX = 0.35, FOREST_D
LONE_EDGE_GAP = 1.0                # cells from nearest forest tree: min
LONE_EDGE_GAP_MAX = 2.0            #   and max
LONE_GAP = 3.0                     # between lone trees

# --- bushes: the 2 smaller round bushes; many hug the forest edge, some single/pairs in the meadow
BUSH_EDGE = 16
BUSH_MEADOW = 9
BUSH_EDGE_DIST = (0.9, 1.7)        # cells from the nearest tree anchor (crowns touch)
BUSH_EDGE_D_MAX = FOREST_D         # edge bushes stay outside the forest
BUSH_MEADOW_D_MAX = 0.40
BUSH_MEADOW_TREE_GAP = 3.0
BUSH_GAP = 1.5
BUSH_PAIR_CHANCE = 0.4             # meadow bush gets a neighbour
BUSH_PAIR_DIST = 1.6

# --- flowers: single, loose; sometimes 2-4 together; meadow and forest edge
FLOWER_D_MAX = 0.50
FLOWERS = 70                       # total
FLOWER_GROUP_CHANCE = 0.5          # chance a site is a group of 2-4
FLOWER_GROUP_DIST = (1.0, 2.5)     # cells between flowers of one group
FLOWER_GAP = 0.6
FLOWER_TREE_GAP = 1.0
FOXGLOVES = 8

# --- tufts
TUFT_OPEN = 0.02                   # per cell, open meadow
TUFT_EDGE = 0.16                   # per cell where TUFT_EDGE_D_MIN <= d <= TUFT_EDGE_D_MAX
TUFT_EDGE_D_MIN, TUFT_EDGE_D_MAX = 0.40, 0.60
TUFT_PER_STONE_GROUP = 6
TUFT_MAX_PX = 14                   # only small tufts

# --- rocks: groups of 3-6, 1-2 medium + small ones around
STONE_GROUPS_MEADOW = 4
STONE_GROUPS_EDGE = 2              # touching the forest edge
STONE_GROUP_MIN, STONE_GROUP_MAX = 3, 6
STONE_MEDIUM_MIN, STONE_MEDIUM_MAX = 1, 2
STONE_SPREAD = 1.2                 # cells radius
STONE_D_MAX = 0.35
STONE_EDGE_DIST = (1.2, 2.5)       # edge groups: cells from nearest tree
STONE_GROUP_GAP = 5.0


def bbox(img, c0, r0, c1, r1):
    """Alpha bounding box inside cells [c0,c1) x [r0,r1) in sheet pixels."""
    b = img.crop((c0 * S, r0 * S, c1 * S, r1 * S)).getchannel("A").point(lambda a: 255 if a else 0).getbbox()
    return (b[0] + c0 * S, b[1] + r0 * S, b[2] + c0 * S, b[3] + r0 * S)


def is_green(im):
    """Drop brown pods / reed heads: keep sprites whose opaque pixels are greener than red."""
    px = [p for p in im.getdata() if p[3]]
    return sum(p[1] for p in px) > sum(p[0] for p in px) * 1.15


def sprite(img, rect):
    return img.crop(rect)


def load_sprites():
    A = lambda p: Image.open(ROOT / p).convert("RGBA")
    veg, rocks = A("assets/game/map/Vegetation.png"), A("assets/source/map/Rocks.png")
    R = {}
    R["bush"] = [bbox(veg, 0, a, 3, b) for a, b in [(0, 2), (2, 4), (4, 6), (6, 9)]]
    R["tuft"] = [r for r in (bbox(veg, c, row, c + 1, row + 1) for row in (9, 10, 11) for c in range(12)
                             if not (row == 9 and 4 <= c <= 6) and veg.crop((c * S, row * S, c * S + S, row * S + S)).getbbox())
                 if r[2] - r[0] <= TUFT_MAX_PX and r[3] - r[1] <= TUFT_MAX_PX
                 and is_green(veg.crop(r))]
    R["flower"] = [[bbox(veg, c, row, c + 1, row + 1) for c in range(3, 8)] for row in (23, 24, 25, 26)]
    R["foxglove"] = [bbox(veg, c, 10, c + 1, 12) for c in (12, 13, 14)]
    R["rock_mid"] = [bbox(rocks, c, 1, c + 1, 2) for c in (10, 11)]
    R["stone"] = [bbox(rocks, c, r, c + 1, r + 1) for r in (4, 5, 6) for c in range(6, 12)
                  if rocks.crop((c * S, r * S, c * S + S, r * S + S)).getbbox()]
    S_ = {"bush": [sprite(veg, r) for r in R["bush"]], "tuft": [sprite(veg, r) for r in R["tuft"]],
          "flower": [[sprite(veg, r) for r in row] for row in R["flower"]],
          "foxglove": [sprite(veg, r) for r in R["foxglove"]], "stone": [sprite(rocks, r) for r in R["stone"]],
          "rock_mid": [sprite(rocks, r) for r in R["rock_mid"]]}
    return R, S_


def make_noise(rng, period):
    """Smooth value noise, stretched to 0..1."""
    gw, gh = int(W / period) + 3, int(H / period) + 3
    lat = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    sm = lambda t: t * t * (3 - 2 * t)

    def raw(x, y):
        fx, fy = x / period, y / period
        ix, iy = int(fx), int(fy)
        tx, ty = sm(fx - ix), sm(fy - iy)
        a = lat[iy][ix] * (1 - tx) + lat[iy][ix + 1] * tx
        b = lat[iy + 1][ix] * (1 - tx) + lat[iy + 1][ix + 1] * tx
        return a * (1 - ty) + b * ty

    vals = [raw(x + .5, y + .5) for y in range(H) for x in range(W)]
    lo, hi = min(vals), max(vals)
    return lambda x, y: min(1.0, max(0.0, (raw(min(max(x, 0), W - .01), min(max(y, 0), H - .01)) - lo) / (hi - lo)))


def make_density(rng):
    """Low-frequency blobs plus a small high-frequency wobble."""
    n1, n2 = make_noise(rng, NOISE_PERIOD), make_noise(rng, EDGE_NOISE_PERIOD)
    return lambda x, y: min(1.0, max(0.0, n1(x, y) + EDGE_NOISE_AMP * (n2(x, y) - 0.5)))


def in_clearing(x, y, margin=0.0):
    cx, cy = W / 2, H / 2
    return abs(x - cx) <= CLEAR_W / 2 + margin and abs(y - cy) <= CLEAR_H / 2 + margin


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def place(rng, d, R_TREE):
    """Returns list of (kind, key, x_cell, y_cell); the point = bottom-centre in cells."""
    items, trees = [], []

    def add_tree(x, y):
        trees.append((x, y))
        items.append(("tree", 0 if rng.random() < TREE_LARGE_SHARE else 1, x, y))

    def near_tree(x, y):
        return min((dist((x, y), t) for t in trees), default=99)

    def ok(x, y, margin=CLEAR_MARGIN):
        return 0.5 <= x <= W - 0.5 and 0.5 <= y <= H and not in_clearing(x, y, margin)

    # forest: staggered jittered grid, step < sprite size so crowns overlap
    big = R_TREE
    sx, sy = TREE_STEP_X * big[0] / S, TREE_STEP_Y * big[1] / S
    row, y = 0, TREE_MIN_Y
    while y < H + sy:
        x = -sx / 2 * (row % 2)
        while x < W + sx:
            tx, ty = x + rng.uniform(-1, 1) * TREE_JITTER * sx, y + rng.uniform(-1, 1) * TREE_JITTER * sy
            if d(tx, ty) > FOREST_D and ok(tx, ty) and TREE_MIN_Y <= ty <= H:
                add_tree(min(max(tx, 0.5), W - 0.5), ty)
            x += sx
        y += sy
        row += 1
    forest = list(trees)
    lone = []
    for _ in range(4000):
        if len(lone) >= LONE_TREES:
            break
        x, y = rng.uniform(0, W), rng.uniform(TREE_MIN_Y, H)
        if LONE_D_MIN <= d(x, y) < LONE_D_MAX and ok(x, y) \
                and LONE_EDGE_GAP <= min((dist((x, y), t) for t in forest), default=99) <= LONE_EDGE_GAP_MAX \
                and all(dist((x, y), l) >= LONE_GAP for l in lone):
            lone.append((x, y))
            add_tree(x, y)

    bushes = []                                             # bushes: edge-hugging + meadow
    def bush_ok(x, y):
        return ok(x, y) and 1.0 <= y <= H and all(dist((x, y), q) >= BUSH_GAP for q in bushes)
    def add_bush(x, y):
        bushes.append((x, y))
        items.append(("bush", rng.randrange(2), x, y))
    for _ in range(20000):
        if len(bushes) >= BUSH_EDGE:
            break
        x, y = rng.uniform(0, W), rng.uniform(1, H)
        if d(x, y) < BUSH_EDGE_D_MAX and BUSH_EDGE_DIST[0] <= near_tree(x, y) <= BUSH_EDGE_DIST[1] and bush_ok(x, y):
            add_bush(x, y)
    for _ in range(20000):
        if len(bushes) >= BUSH_EDGE + BUSH_MEADOW:
            break
        x, y = rng.uniform(0, W), rng.uniform(1, H)
        if d(x, y) < BUSH_MEADOW_D_MAX and near_tree(x, y) >= BUSH_MEADOW_TREE_GAP and bush_ok(x, y):
            add_bush(x, y)
            if rng.random() < BUSH_PAIR_CHANCE:
                a = rng.uniform(0, math.tau)
                px, py = x + math.cos(a) * BUSH_PAIR_DIST, y + math.sin(a) * BUSH_PAIR_DIST
                if bush_ok(px, py) and d(px, py) < BUSH_MEADOW_D_MAX:
                    add_bush(px, py)

    flowers = []                                            # loose singles, some 2-4 together
    def meadow_spot(x, y):
        return 0.5 < x < W - 0.5 and 0.5 < y < H - 0.5 and d(x, y) < FLOWER_D_MAX and ok(x, y) \
            and near_tree(x, y) >= FLOWER_TREE_GAP
    for _ in range(40000):
        if len(flowers) >= FLOWERS:
            break
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        if not meadow_spot(x, y):
            continue
        pts = [(x, y)]
        if rng.random() < FLOWER_GROUP_CHANCE:
            for _ in range(rng.randint(1, 3)):
                a, r = rng.uniform(0, math.tau), rng.uniform(*FLOWER_GROUP_DIST)
                pts.append((x + math.cos(a) * r, y + math.sin(a) * r))
        for px, py in pts:
            if meadow_spot(px, py) and all(dist((px, py), f) >= FLOWER_GAP for f in flowers):
                flowers.append((px, py))
                items.append(("flower", (rng.randrange(4), rng.randrange(5)), px, py))
    for _ in range(FOXGLOVES):
        for _ in range(500):
            x, y = rng.uniform(0, W), rng.uniform(0, H)
            if meadow_spot(x, y):
                items.append(("foxglove", rng.randrange(3), x, y))
                break

    groups = []                                             # rock groups: meadow + forest edge
    for edge in [False] * STONE_GROUPS_MEADOW + [True] * STONE_GROUPS_EDGE:
        for _ in range(8000):
            x, y = rng.uniform(1.5, W - 1.5), rng.uniform(1.5, H - 1.5)
            if in_clearing(x, y, CLEAR_MARGIN + STONE_SPREAD) or any(dist((x, y), g) < STONE_GROUP_GAP for g in groups):
                continue
            if edge and STONE_EDGE_DIST[0] <= near_tree(x, y) <= STONE_EDGE_DIST[1] and d(x, y) < FOREST_D \
                    or not edge and d(x, y) < STONE_D_MAX and near_tree(x, y) >= FLOWER_TREE_GAP:
                groups.append((x, y))
                break
    for gx, gy in groups:
        n = rng.randint(STONE_GROUP_MIN, STONE_GROUP_MAX)
        mids = rng.randint(STONE_MEDIUM_MIN, STONE_MEDIUM_MAX)
        for i in range(n):
            a, r = rng.uniform(0, math.tau), STONE_SPREAD * math.sqrt(rng.random())
            items.append(("rock_mid" if i < mids else "stone", rng.randrange(1000), gx + math.cos(a) * r, gy + math.sin(a) * r * 0.6))
        for _ in range(TUFT_PER_STONE_GROUP):
            a, r = rng.uniform(0, math.tau), rng.uniform(0.6, 1.5)
            items.append(("tuft", rng.randrange(1000), gx + math.cos(a) * r, gy + math.sin(a) * r))

    for cy in range(H):                                     # tufts: mostly forest edge
        for cx in range(W):
            x, y = cx + rng.random(), cy + 0.6 + rng.random() * 0.4
            v = d(x, y)
            p = TUFT_EDGE if TUFT_EDGE_D_MIN <= v <= TUFT_EDGE_D_MAX else TUFT_OPEN if v < TUFT_EDGE_D_MIN else 0
            if rng.random() < p and not in_clearing(x, y) and near_tree(x, y) >= 0.5:
                items.append(("tuft", rng.randrange(1000), x, y))
    return items


def render(items, d, sp, tinted):
    img = Image.new("RGBA", (W * S, H * S))
    sheet = Image.open(ROOT / "assets/retired/map/Floors_Tiles.png").convert("RGBA")
    rng = random.Random(1)
    for y in range(H):
        for x in range(W):
            c = rng.choice(GRASS_FILLS)
            t = sheet.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
            if rng.random() < .5:
                t = t.transpose(Image.FLIP_LEFT_RIGHT)
            if rng.random() < .5:
                t = t.transpose(Image.FLIP_TOP_BOTTOM)
            if rng.random() < .5:
                t = t.transpose(Image.TRANSPOSE)
            img.alpha_composite(t, (x * S, y * S))

    def pick(kind, key):
        if kind == "tree":
            return sp["bush"][3 - key]
        if kind == "tuft":
            return sp["tuft"][key % len(sp["tuft"])]
        if kind == "bush":
            return sp["bush"][key]
        if kind == "rock_mid":
            return sp["rock_mid"][key % len(sp["rock_mid"])]
        if kind == "flower":
            return sp["flower"][key[0]][key[1]]
        if kind == "foxglove":
            return sp["foxglove"][key]
        return sp["stone"][key % len(sp["stone"])]

    for kind, key, x, y in sorted(items, key=lambda i: i[3]):   # y-sort by bottom edge
        s = pick(kind, key)
        img.alpha_composite(s, (round(x * S - s.width / 2), round(y * S - s.height)))

    if tinted:
        tint = Image.new("RGBA", img.size)
        px = tint.load()
        for cy in range(H):
            for cx in range(W):
                v = d(cx + .5, cy + .5)
                col = (60, 120, 255) if v < .35 else (240, 220, 40) if v < .45 else (255, 140, 0) if v < .65 else (210, 20, 20)
                for yy in range(S):
                    for xx in range(S):
                        px[cx * S + xx, cy * S + yy] = col + (95,)
        img.alpha_composite(tint)
        dr = ImageDraw.Draw(img)
        x0, y0 = (W - CLEAR_W) / 2 * S, (H - CLEAR_H) / 2 * S
        dr.rectangle([x0, y0, x0 + CLEAR_W * S, y0 + CLEAR_H * S], outline=(255, 255, 255, 255))
        dr.rectangle([2, 2, 250, 30], fill=(0, 0, 0, 180))
        dr.text((5, 4), "blue d<.35 meadow: flowers, stones | yellow .35-.45 edge", fill="white")
        dr.text((5, 16), "orange .45-.65 forest edge | red >.65 forest (from .55) | box=clearing", fill="white")
    return img.resize((W * S * SCALE, H * S * SCALE), Image.NEAREST)


def main(seed):
    rng = random.Random(seed)
    R, sp = load_sprites()
    for k, v in R.items():
        print(k, v)
    d = make_density(rng)
    items = place(rng, d, (R['bush'][3][2] - R['bush'][3][0], R['bush'][3][3] - R['bush'][3][1]))
    out = ROOT / "docs/demo"
    for name, tinted in (("meadow_preview.png", False), ("meadow_preview_density.png", True)):
        render(items, d, sp, tinted).save(out / name)
        print(out / name)
    counts = {}
    for i in items:
        counts[i[0]] = counts.get(i[0], 0) + 1
    print(counts)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 7)
