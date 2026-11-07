"""Preview: docs/wiki/vegetation-rules.md as a picture ($0, no game code). Plains + Forest on a 112x72 map, 16 px/cell,
sprites at native size. Passes in spec order, one random stream per pass. All numbers = constants below.
Writes docs/demo/biome_preview.png (x1), biome_preview_zoom.png (48x27 cells at the border, x2), biome_preview_f.png (f tint).

Run: python3 tools/asset_viewer/biome_preview.py [seed]
"""
import json
import math
import random
import sys

from PIL import Image, ImageDraw

from meadow_preview import ROOT, S, bbox, load_sprites

W, H = 112, 72
BLOCK = 16
GRASS_FILLS = [(1, 10), (2, 10), (3, 10)]
SEED = 3

# --- biome noise
F_PERIOD = 40                      # cells per bump
FOREST_F = 0.55                    # f above = Forest
BAND = (0.45, 0.65)                # border band: chance fades with f
CLEAR_W, CLEAR_H = 6, 5            # home clearing
PATH_W = 3
PATH_WOBBLE, PATH_WAVE = 4.0, 28.0 # amplitude cells, wavelength cells

# --- pass 1 clearings
CLEARING_PER_CELLS = 40 * 40
CLEARING_R = (3, 5)
# --- pass 2 trees
TREE_TRIES_FOREST = 14             # per block
TREE_TRIES_PLAINS = 0.5
PLAINS_RING = 3                    # lone tree: cells around trunk free
FIR_SHARE = 0.10                   # chance a tree try is a fir GROUP seed; groups of 3-5 -> firs ~20% of trees
FIR_GROUP = (3, 5)
FIR_GROUP_R = 3
AGE_CORE = 0.75
AGE_MID = 0.60
CORE_OLD = 0.5
MID_SMALL = 0.2                    # mature small (Size_03)
EDGE_YOUNG, EDGE_SAPLING = 0.5, 0.3  # rest = mature small
PLAINS_OLD = 0.3
# --- pass 3 rocks
ROCK_PLAINS_PER_BLOCK, ROCK_FOREST_PER_BLOCK = 1.0, 0.5
ROCK_PLAINS_SMALL = (3, 5)
ROCK_FOREST_SMALL = (2, 3)
ROCK_SPREAD = 1.5
ROCK_PLAINS_MEDIUM = (1, 2)   # medium rocks per group
ROCK_FOREST_MEDIUM = (0, 1)
# --- pass 4 bushes
BUSH_EDGE_PER_BLOCK, BUSH_EDGE_F = 1.0, (0.45, 0.70)
BUSH_EDGE_TRIES, BUSH_EDGE_R = 6, 2.0
BUSH_PLAINS_PER_BLOCK, BUSH_PAIR_CHANCE, BUSH_PAIR_R = 0.5, 0.5, 1.6
# --- pass 5 flowers
FLOWER_PLAINS_PER_BLOCK, FLOWER_PLAINS_TRIES, FLOWER_PLAINS_R = 0.8, 50, 3.0
FLOWER_FOREST_PER_BLOCK, FLOWER_FOREST_TRIES, FLOWER_FOREST_R = 0.125, 20, 3.0
FLOWER_GAP = 1.0
FOXGLOVE_PATCH_CHANCE, FOXGLOVE_COUNT = 0.1, (2, 3)
# --- pass 6 mushrooms
MUSH_TRIES_PER_BLOCK, MUSH_SHADE, MUSH_GROUP = 5, 2.0, (1, 3)
MUSH_GROUP_R = 1.0
# --- pass 7 tufts
TUFT_P = 1 / 8
TUFT_NEAR_MULT, TUFT_OPEN_MULT = 2.0, 0.5


def make_noise(rng, period):
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
    raws = [[raw(x + .5, y + .5) for x in range(W)] for y in range(H)]
    lo, hi = min(map(min, raws)), max(map(max, raws))
    return [[(v - lo) / (hi - lo) for v in row] for row in raws]


def fval(grid, x, y):
    return grid[min(max(int(y), 0), H - 1)][min(max(int(x), 0), W - 1)]


def smooth(a, b, v):
    return min(1.0, max(0.0, (v - a) / (b - a)))


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def pick_seed(start):
    """First seed whose forest share is 42-48%."""
    for s in range(start, start + 500):
        g = make_noise(random.Random(s), F_PERIOD)
        share = sum(v > FOREST_F for r in g for v in r) / (W * H)
        plains_mid = min(g[y][x] for x in range(W // 2 - 14, W // 2 + 15) for y in range(H // 2 - 8, H // 2 + 9)) < 0.35
        if 0.42 <= share <= 0.48 and plains_mid:
            return s, g, share
    raise SystemExit("no seed")


def peaked(rng, r):
    return rng.uniform(-r / 2, r / 2) + rng.uniform(-r / 2, r / 2)


def blocks():
    for by in range(0, H, BLOCK):
        for bx in range(0, W, BLOCK):
            bw, bh = min(BLOCK, W - bx), min(BLOCK, H - by)
            yield bx, by, bw, bh, bw * bh / (BLOCK * BLOCK)


def n_tries(rng, rate, area):
    v = rate * area
    return int(v) + (rng.random() < v - int(v))


def main(seed0):
    seed, f, share = pick_seed(seed0)
    R, sp = load_sprites()
    veg = Image.open(ROOT / "assets/game/map/Vegetation.png").convert("RGBA")
    mush = [veg.crop(bbox(veg, c, 21, c + 1, 22)) for c in range(8)]
    cat = json.load(open(ROOT / "data/maps/tree_catalog.json"))
    sheets = {}

    def sheet(p):
        if p not in sheets:
            sheets[p] = Image.open(ROOT / p).convert("RGBA")
        return sheets[p]

    P = {(m, k): [e for e in cat if e["model"] == m and e["size"] == s and e["stage"] == st and e["season"] == "green"]
         for m in (1, 2) for k, (s, st) in
         {"old": (5, "old"), "mature": (4, "mature"), "small": (3, "mature"), "young": (2, "young"), "sapling": (2, "sapling")}.items()}

    streams = {n: random.Random(seed * 100 + i) for i, n in enumerate(
        ["clear", "tree", "rock", "bush", "flower", "mush", "tuft", "path", "ground"])}

    # ---- keep-out: home clearing (lowest f near the centre) + winding path into forest
    best = min((f[y][x], x, y) for x in range(W // 2 - 14, W // 2 + 15) for y in range(H // 2 - 8, H // 2 + 9))
    hcx, hcy = best[1], best[2]
    keep = {(x, y) for x in range(hcx - CLEAR_W // 2, hcx - CLEAR_W // 2 + CLEAR_W)
            for y in range(hcy - CLEAR_H // 2, hcy - CLEAR_H // 2 + CLEAR_H)}
    tgt = min(((x, y) for y in range(H) for x in range(W) if f[y][x] > 0.6), key=lambda c: dist(c, (hcx, hcy)))
    path = set()
    L = dist((hcx, hcy), tgt) + 8                       # run a bit into the forest
    ux, uy = (tgt[0] - hcx) / (L - 8), (tgt[1] - hcy) / (L - 8)
    ph = streams["path"].uniform(0, math.tau)
    for i in range(int(L * 2)):
        t = i / 2
        w = PATH_WOBBLE * math.sin(t / PATH_WAVE * math.tau + ph) * min(1, t / 8)
        cx, cy = hcx + ux * t - uy * w, hcy + uy * t + ux * w
        for dx in range(-(PATH_W // 2), PATH_W // 2 + 1):
            for dy in range(-(PATH_W // 2), PATH_W // 2 + 1):
                c = (int(round(cx)) + dx, int(round(cy)) + dy)
                if 0 <= c[0] < W and 0 <= c[1] < H and c not in keep:
                    path.add(c)
    keep |= path

    occ = {}           # cell -> 'trunk' | 'rock' | 'bush'
    trunks, items, counts = [], [], {}

    def add(kind, img, ax, ay, off):
        items.append((ay, img, ax - off[0], ay - off[1]))
        counts[kind] = counts.get(kind, 0) + 1

    def base_off(img):
        return (img.width // 2, img.height)

    def land_ok(c):
        return 0 <= c[0] < W and 0 <= c[1] < H and c not in occ and c not in keep

    # ---- 1 clearings
    clearings, r = [], streams["clear"]
    for _ in range(round(W * H / CLEARING_PER_CELLS)):
        x, y = r.uniform(0, W), r.uniform(0, H)
        if f[int(y)][int(x)] > FOREST_F and (int(x), int(y)) not in keep:
            clearings.append((x, y, r.uniform(*CLEARING_R)))
    counts["clearing"] = len(clearings)
    in_clear = lambda x, y: any(dist((x, y), (cx, cy)) <= cr for cx, cy, cr in clearings)

    # ---- 2 trees
    r = streams["tree"]

    def place_tree(cell, model, kind):
        e = r.choice(P[(model, kind)])
        x0, y0, w, h = e["rect"]
        img = sheet(e["sheet"]).crop((x0, y0, x0 + w, y0 + h))
        add(f"tree_{'oak' if model == 1 else 'fir'}_{kind}", img, (cell[0] + .5) * S, (cell[1] + 1) * S - 2, e["trunk_base"])
        occ[cell] = "trunk"
        trunks.append(cell)

    def trunk_free(c, ring=0):
        if not land_ok(c) or in_clear(c[0] + .5, c[1] + .5):
            return False
        if any((c[0] + dx, c[1] + dy) in occ for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            return False
        return not ring or not any(occ.get((c[0] + dx, c[1] + dy)) == "trunk" and dx * dx + dy * dy <= ring * ring
                                   for dx in range(-ring, ring + 1) for dy in range(-ring, ring + 1))

    def forest_kind(fv):
        u = r.random()
        if fv > AGE_CORE:
            return "old" if u < CORE_OLD else "mature"
        if fv > AGE_MID:
            return "small" if u < MID_SMALL else "mature"
        return "young" if u < EDGE_YOUNG else "sapling" if u < EDGE_YOUNG + EDGE_SAPLING else "small"

    for bx, by, bw, bh, area in blocks():
        for _ in range(n_tries(r, TREE_TRIES_FOREST, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if r.random() >= smooth(BAND[0], BAND[1], fval(f, x, y)):
                continue
            tries, fir = [(x, y)], r.random() < FIR_SHARE
            if fir:
                for _ in range(r.randint(*FIR_GROUP) - 1):
                    a, d = r.uniform(0, math.tau), r.uniform(0, FIR_GROUP_R)
                    tries.append((x + math.cos(a) * d, y + math.sin(a) * d))
            for tx, ty in tries:
                if 0 <= tx < W and 0 <= ty < H and trunk_free((int(tx), int(ty))):
                    place_tree((int(tx), int(ty)), 2 if fir else 1, forest_kind(fval(f, tx, ty)))
        for _ in range(n_tries(r, TREE_TRIES_PLAINS, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if r.random() >= 1 - smooth(BAND[0], BAND[1], fval(f, x, y)):
                continue
            if trunk_free((int(x), int(y)), PLAINS_RING):
                place_tree((int(x), int(y)), 1, "old" if r.random() < PLAINS_OLD else "mature")

    # ---- 3 rocks
    r = streams["rock"]

    def rock_group(x, y, nsmall, medium):
        parts = [("m", x, y)] * (medium > 0)
        for _ in range(medium - 1):   # extra mediums sit next to the first
            parts.append(("m", x + r.uniform(-1, 1), y + r.uniform(-.6, .6)))
        for _ in range(nsmall):
            a, d = r.uniform(0, math.tau), ROCK_SPREAD * math.sqrt(r.random())
            parts.append(("s", x + math.cos(a) * d, y + math.sin(a) * d * .7))
        for k, px, py in parts:
            c = (int(px), int(py))
            if not land_ok(c) or in_clear(px, py):
                continue
            if any(dist((px, py), (t[0] + .5, t[1] + .5)) < 1.5 for t in trunks):   # not under a crown centre
                continue
            img = r.choice(sp["rock_mid"] if k == "m" else sp["stone"])
            occ[c] = "rock"
            add("rock_medium" if k == "m" else "rock_small", img, px * S, py * S, base_off(img))

    for bx, by, bw, bh, area in blocks():
        for forest, rate, ns in ((False, ROCK_PLAINS_PER_BLOCK, ROCK_PLAINS_SMALL), (True, ROCK_FOREST_PER_BLOCK, ROCK_FOREST_SMALL)):
            for _ in range(n_tries(r, rate, area)):
                x, y = bx + r.random() * bw, by + r.random() * bh
                if (fval(f, x, y) > FOREST_F) == forest:
                    rock_group(x, y, r.randint(*ns), r.randint(*(ROCK_FOREST_MEDIUM if forest else ROCK_PLAINS_MEDIUM)))

    # ---- 4 bushes
    r = streams["bush"]

    def put_bush(x, y):
        if land_ok((int(x), int(y))) and not in_clear(x, y):
            img = r.choice(sp["bush"][:2])
            occ[(int(x), int(y))] = "bush"
            add("bush", img, x * S, y * S, base_off(img))
            return True
        return False

    for bx, by, bw, bh, area in blocks():
        for _ in range(n_tries(r, BUSH_EDGE_PER_BLOCK, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if BUSH_EDGE_F[0] <= fval(f, x, y) <= BUSH_EDGE_F[1]:
                for _ in range(BUSH_EDGE_TRIES):
                    put_bush(x + peaked(r, BUSH_EDGE_R * 2), y + peaked(r, BUSH_EDGE_R * 2))
        for _ in range(n_tries(r, BUSH_PLAINS_PER_BLOCK, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if fval(f, x, y) < FOREST_F and put_bush(x, y) and r.random() < BUSH_PAIR_CHANCE:
                a = r.uniform(0, math.tau)
                put_bush(x + math.cos(a) * BUSH_PAIR_R, y + math.sin(a) * BUSH_PAIR_R)

    # ---- 5 flowers
    r = streams["flower"]

    def patch(x, y, tries, spread):
        row, pts = r.randrange(4), []
        for _ in range(tries):
            px, py = x + peaked(r, spread), y + peaked(r, spread)   # peaked: sum of 2 uniforms, +-spread
            if land_ok((int(px), int(py))) and all(dist((px, py), q) >= FLOWER_GAP for q in pts):
                pts.append((px, py))
                img = sp["flower"][row][r.randrange(5)]
                add("flower", img, px * S, py * S, base_off(img))
        if r.random() < FOXGLOVE_PATCH_CHANCE:
            for _ in range(r.randint(*FOXGLOVE_COUNT)):
                a = r.uniform(0, math.tau)
                px, py = x + math.cos(a) * spread, y + math.sin(a) * spread
                if land_ok((int(px), int(py))):
                    img = r.choice(sp["foxglove"])
                    add("foxglove", img, px * S, py * S, base_off(img))

    for bx, by, bw, bh, area in blocks():
        for _ in range(n_tries(r, FLOWER_PLAINS_PER_BLOCK, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if fval(f, x, y) < FOREST_F:
                patch(x, y, FLOWER_PLAINS_TRIES, FLOWER_PLAINS_R)
        for _ in range(n_tries(r, FLOWER_FOREST_PER_BLOCK, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if fval(f, x, y) >= FOREST_F and in_clear(x, y):
                patch(x, y, FLOWER_FOREST_TRIES, FLOWER_FOREST_R)

    # ---- 6 mushrooms
    r = streams["mush"]
    for bx, by, bw, bh, area in blocks():
        for _ in range(n_tries(r, MUSH_TRIES_PER_BLOCK, area)):
            x, y = bx + r.random() * bw, by + r.random() * bh
            if fval(f, x, y) < FOREST_F:
                continue
            for _ in range(r.randint(*MUSH_GROUP)):
                px, py = x + r.uniform(-MUSH_GROUP_R, MUSH_GROUP_R), y + r.uniform(-MUSH_GROUP_R, MUSH_GROUP_R)
                if land_ok((int(px), int(py))) and any(dist((px, py), (t[0] + .5, t[1] + .5)) <= MUSH_SHADE for t in trunks):
                    img = r.choice(mush)
                    add("mushroom", img, px * S, py * S, base_off(img))

    # ---- 7 tufts
    r = streams["tuft"]
    for cy in range(H):
        for cx in range(W):
            if (cx, cy) in occ:
                continue
            fv, p = f[cy][cx], TUFT_P
            nt = any(occ.get((cx + dx, cy + dy)) == "trunk" for dx in range(-2, 3) for dy in range(-2, 3))
            nr = any(occ.get((cx + dx, cy + dy)) == "rock" for dx in range(-1, 2) for dy in range(-1, 2))
            if nt or nr or BAND[0] <= fv <= BAND[1]:
                p *= TUFT_NEAR_MULT
            elif fv < BAND[0]:
                p *= TUFT_OPEN_MULT
            if r.random() < p:
                img = r.choice(sp["tuft"])
                add("tuft", img, (cx + r.random()) * S, (cy + .6 + r.random() * .4) * S, base_off(img))

    # ---- render
    gr = streams["ground"]
    sh = Image.open(ROOT / "assets/game/map/Floors_Tiles.png").convert("RGBA")
    img = Image.new("RGBA", (W * S, H * S))
    for y in range(H):
        for x in range(W):
            c = gr.choice(GRASS_FILLS)
            t = sh.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
            for op in (Image.FLIP_LEFT_RIGHT, Image.FLIP_TOP_BOTTOM, Image.TRANSPOSE):
                if gr.random() < .5:
                    t = t.transpose(op)
            img.alpha_composite(t, (x * S, y * S))
    # path = keep-out only, not drawn (real look comes in game)
    for _, s, x, y in sorted(items, key=lambda i: i[0]):        # y-sort by anchor y
        img.paste(s, (round(x), round(y)), s)
    out = ROOT / "docs/demo"
    img.save(out / "biome_preview.png")
    zx = min(max(int((hcx + tgt[0]) / 2) - 24, 0), W - 48)
    zy = min(max(int((hcy + tgt[1]) / 2) - 13, 0), H - 27)
    img.crop((zx * S, zy * S, (zx + 48) * S, (zy + 27) * S)).resize((48 * S * 2, 27 * S * 2), Image.NEAREST).save(out / "biome_preview_zoom.png")

    tint = Image.new("RGBA", img.size)
    px = tint.load()
    for cy in range(H):
        for cx in range(W):
            v = f[cy][cx]
            col = (60, 120, 255) if v < BAND[0] else (240, 220, 40) if v < FOREST_F else (255, 140, 0) if v < BAND[1] else (210, 20, 20)
            for yy in range(S):
                for xx in range(S):
                    px[cx * S + xx, cy * S + yy] = col + (90,)
    img.alpha_composite(tint)
    dr = ImageDraw.Draw(img)
    dr.rectangle([2, 2, 380, 42], fill=(0, 0, 0, 190))
    dr.text((5, 4), f"seed {seed}  forest share {share:.0%}", fill="white")
    dr.text((5, 16), "blue f<.45 plains | yellow .45-.55 | orange .55-.65 | red >.65 forest", fill="white")
    dr.text((5, 28), "white = home clearing + zoom box, magenta = path, cyan = forest clearings", fill="white")
    hx, hy = hcx - CLEAR_W // 2, hcy - CLEAR_H // 2
    dr.rectangle([hx * S, hy * S, (hx + CLEAR_W) * S, (hy + CLEAR_H) * S], outline="white")
    dr.rectangle([zx * S, zy * S, (zx + 48) * S, (zy + 27) * S], outline="white")
    for c in path:
        dr.rectangle([c[0] * S + 6, c[1] * S + 6, c[0] * S + 9, c[1] * S + 9], fill=(255, 0, 255))
    for cx, cy, cr in clearings:
        dr.ellipse([(cx - cr) * S, (cy - cr) * S, (cx + cr) * S, (cy + cr) * S], outline=(0, 255, 255))
    img.save(out / "biome_preview_f.png")

    print("seed", seed, "forest share", round(share, 3), "home", (hcx, hcy), "path cells", len(path))
    for k in sorted(counts):
        print(f"{k:18s}{counts[k]}")
    print("trees total", sum(v for k, v in counts.items() if k.startswith("tree")))


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else SEED)
