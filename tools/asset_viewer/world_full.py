"""Preview ($0, no game code): the WHOLE 512x512 world (world_preview.py, seed 7: land, biomes, rivers, lakes, beaches, home/boss)
drawn with real sprites at 16 px/cell (8192x8192), using the BIOMES table and passes of biome_looks.py (same order: clearings,
trees, rocks, bushes, flowers, mushrooms, tufts; one random stream per pass). A spot's biome is read from the biome map at a jittered
position (+-2.5 cells), so borders mix as dots, never as a line.
Writes docs/demo/world_full.png (2048 px, LANCZOS, home H / boss B marked) and docs/demo/world_full_crop.png
(128x128 cells around home at full resolution = 2048 px, not marked).

Run: python3 tools/asset_viewer/world_full.py [seed]
"""
import math
import random
import sys
import time

import numpy as np
from PIL import Image, ImageDraw

import world_preview as wp
from biome_looks import BIOMES, FADE, KINDS, KIND_SPEC, load_art, n_tries, smooth, wchoice
from biome_preview import peaked
from meadow_preview import ROOT, S

N = wp.N
OUT = ROOT / "docs/demo"
BLOCK = 16
JITTER = 2.5                       # cells: biome of a spot = map biome at spot + this much noise
HOME_FREE_R, BOSS_FREE_R = 6, 9    # nothing tall this close to home / boss
CLEARINGS_PER_CELLS = 40 * 40
CLEAR_R = (3, 5)
REED_NEAR = {"swamp": .4, "default": .12}   # cattail patch chance per shore cell (water within 3 cells)
NO_REED = ("snowy", "rocky")
BLOCK_PX = 8                       # ground blend patch, px
BLEND_CELLS = 1.3                  # ground blend: how far (cells) a patch may borrow its neighbour's ground
GROUND_TINT = {"plains": None, **{k: BIOMES[k]["tint"] for k in BIOMES}}
GROUND_IDS = ["grass", "grass_taiga", "grass_autumn", "grass_swamp", "snow", "stone", "dirt", "sand", "water"]
GID = {n: i for i, n in enumerate(GROUND_IDS)}
BIO_GROUND = {"plains": "grass", "forest": "grass", "taiga": "grass_taiga", "autumn": "grass_autumn", "swamp": "grass_swamp",
              "snowy": "snow", "rocky": "stone"}   # rocky: stone / dirt mixed by the world patch noise
ROCKY_STONE_SHARE = wp.ROCKY_STONE_SHARE


def build_ground_lib(art):
    """lib[id][variant] = 16x16 RGBA; variants = 3 fills x 8 flips; as uint8 (ids, V, 2, 2, 8, 8, 4) quadrants."""
    fills = {"grass": wp.FILLS["grass"], "snow": wp.FILLS["snow"], "stone": wp.FILLS["stone"], "dirt": wp.FILLS["dirt"],
             "sand": wp.FILLS["sand"]}
    lib = []
    for gid in GROUND_IDS:
        base = gid.split("_")[0] if gid.startswith("grass") else gid
        cells = [(c, art["water"]) for c in wp.WATER_FILLS[:3]] if gid == "water" else [(c, art["tiles"]) for c in fills[base][:3]]
        tint = {"grass_taiga": BIOMES["taiga"]["tint"], "grass_autumn": BIOMES["autumn"]["tint"],
                "grass_swamp": BIOMES["swamp"]["tint"]}.get(gid)
        vs = []
        for c, sh in cells:
            t = sh.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
            for f in range(8):
                u = t
                if f & 1:
                    u = u.transpose(Image.FLIP_LEFT_RIGHT)
                if f & 2:
                    u = u.transpose(Image.FLIP_TOP_BOTTOM)
                if f & 4:
                    u = u.transpose(Image.TRANSPOSE)
                a = np.array(u, float)
                if tint:
                    a[..., :3] *= np.array(tint)
                vs.append(np.clip(a, 0, 255).astype(np.uint8))
        lib.append(np.stack(vs))
    lib = np.stack(lib)                                                  # (ids, V, 16, 16, 4)
    q = lib.reshape(lib.shape[0], lib.shape[1], 2, 8, 2, 8, 4).transpose(0, 1, 2, 4, 3, 5, 6)   # ids,V,qy,qx,8,8,4
    return q


def ground_ids(w):
    """Per cell ground id (0..8)."""
    b, ids = w["biome"], wp.ID
    g = np.zeros((N, N), np.uint8)
    for name, gn in BIO_GROUND.items():
        g[b == ids[name]] = GID[gn]
    rocky = b == ids["rocky"]
    g[rocky & (w["patch"] >= ROCKY_STONE_SHARE)] = GID["dirt"]
    g[b == ids["beach"]] = GID["sand"]
    g[b == ids["gravel"]] = GID["stone"]
    sand_shore = w["shore"] & np.isin(b, [ids["plains"], ids["autumn"]])
    g[sand_shore] = GID["sand"]
    g[w["shore"] & ~sand_shore] = GID["dirt"]
    g[w["shore"] & (b == ids["snowy"])] = GID["snow"]       # snow ponds / rivers: no dirt rim
    g[np.isin(b, [ids["ocean"], ids["river"], ids["lake"]])] = GID["water"]
    return g


def paint_ground(w, art, rng):
    t0 = time.time()
    lib = build_ground_lib(art)
    g = ground_ids(w)
    nb = N * 2                                                           # 8 px blocks per side (2 per cell)
    by, bx = np.mgrid[0:nb, 0:nb]
    cy0, cx0 = by // 2, bx // 2
    cell_noise = wp.vnoise(bx / 2.0, by / 2.0, 3.0, rng.random((256, 256)))
    cell_noise2 = wp.vnoise(bx / 2.0 + 99, by / 2.0 + 37, 3.0, rng.random((256, 256)))
    jx = ((cell_noise - .5) * 2 * BLEND_CELLS + (rng.random((nb, nb)) - .5) * .7)
    jy = ((cell_noise2 - .5) * 2 * BLEND_CELLS + (rng.random((nb, nb)) - .5) * .7)
    cy1 = np.clip(np.floor((by + .5) / 2 + jy).astype(int), 0, N - 1)
    cx1 = np.clip(np.floor((bx + .5) / 2 + jx).astype(int), 0, N - 1)
    own = g[cy0, cx0]
    jg = g[cy1, cx1]
    blk = np.where((own == GID["water"]) | (jg == GID["water"]), own, jg)    # water edges stay crisp
    v = rng.integers(0, lib.shape[1], (nb, nb))
    qy, qx = by % 2, bx % 2
    tiles = lib[blk, v, qy, qx]                                          # (nb, nb, 8, 8, 4)
    img = tiles.transpose(0, 2, 1, 3, 4).reshape(nb * 8, nb * 8, 4)
    print(f"ground {time.time() - t0:.1f}s")
    return Image.fromarray(img[..., :3].copy(), "RGB")


def main(seed0, out=None, size=2048):
    t00 = time.time()
    w = None
    for s in range(seed0, seed0 + 60):
        w = wp.build(s)
        if wp.good_world(w):
            break
    home, boss = wp.pick_points(w)
    ln = int(w["land"].sum())
    print(f"STATS seed {w['seed']} lakes {w['n_lakes']} lake% {100 * w['lake'].sum() / ln:.2f} river% {100 * w['river'].sum() / ln:.2f} "
          f"swamp% {100 * (w['biome'] == wp.ID['swamp']).sum() / ln:.1f}")
    print("world", w["seed"], "home", home, "boss", boss, f"{time.time() - t00:.1f}s")
    art = load_art()
    rng_np = np.random.default_rng(w["seed"])
    canvas = paint_ground(w, art, rng_np)

    ID, IDS = wp.ID, wp.IDS
    bgrid = w["biome"]
    LANDN = list(BIOMES)                                                 # table names
    blocks_n = N // BLOCK
    present = {nm: np.zeros((blocks_n, blocks_n), bool) for nm in LANDN}
    for nm in LANDN:
        m = wp.ndi.binary_dilation(bgrid == ID[nm], iterations=3)
        present[nm] = m.reshape(blocks_n, BLOCK, blocks_n, BLOCK).any(axis=(1, 3))

    streams = {n: random.Random(w["seed"] * 100 + i) for i, n in enumerate(
        ["clear", "tree", "rock", "bush", "flower", "mush", "tuft", "fox", "reed", "stump"])}
    nz = wp.rank01(wp.fbm(*np.mgrid[0:N, 0:N][::-1].astype(float), 40, np.random.default_rng(w["seed"] + 5), 2))   # density d 0..1

    # keep-out: water, beach, shore, home and boss discs
    yy, xx = np.mgrid[0:N, 0:N]
    keep = np.isin(bgrid, [ID[n] for n in ("ocean", "river", "lake", "beach", "gravel")]) | w["shore"]
    for pt, r in ((home, HOME_FREE_R), (boss, BOSS_FREE_R)):
        if pt:
            keep |= (xx - pt[0]) ** 2 + (yy - pt[1]) ** 2 <= r * r
    water = np.isin(bgrid, [ID[n] for n in ("ocean", "river", "lake")])
    occ = {}
    trunks = []
    items, counts = [], {}

    def add(kind, img, ax, ay, off):
        items.append((ay, img, ax - off[0], ay - off[1]))
        counts[kind] = counts.get(kind, 0) + 1

    base_off = lambda im: (im.width // 2, im.height)
    land_ok = lambda c: 0 <= c[0] < N and 0 <= c[1] < N and c not in occ and not keep[c[1], c[0]]
    clearmask = np.zeros((N, N), bool)
    in_clear = lambda x, y: 0 <= x < N and 0 <= y < N and clearmask[int(y), int(x)]

    def biome_at(r, x, y):
        cx = min(max(int(x + r.uniform(-JITTER, JITTER)), 0), N - 1)
        cy = min(max(int(y + r.uniform(-JITTER, JITTER)), 0), N - 1)
        return IDS[bgrid[cy, cx]]

    def tries(r, getrate):
        for nm in LANDN:
            b = BIOMES[nm]
            rate = getrate(b)
            if not rate:
                continue
            pr = present[nm]
            for by in range(blocks_n):
                for bx in range(blocks_n):
                    if not pr[by, bx]:
                        continue
                    for _ in range(n_tries(r, rate, 1.0)):
                        x, y = bx * BLOCK + r.random() * BLOCK, by * BLOCK + r.random() * BLOCK
                        if biome_at(r, x, y) == nm:
                            yield b, x, y

    def dens(b, x, y):
        return b["dens"][0] + (b["dens"][1] - b["dens"][0]) * nz[min(int(y), N - 1), min(int(x), N - 1)]

    def near_kind(c, kind, rad):
        return any(occ.get((c[0] + dx, c[1] + dy)) == kind for dx in range(-rad, rad + 1) for dy in range(-rad, rad + 1))

    def dist_kind(x, y, kind, rad):
        for dx in range(-math.ceil(rad), math.ceil(rad) + 1):
            for dy in range(-math.ceil(rad), math.ceil(rad) + 1):
                if occ.get((int(x) + dx, int(y) + dy)) == kind and math.hypot(x - (int(x) + dx + .5), y - (int(y) + dy + .5)) <= rad:
                    return True
        return False

    cache = {}

    def tree_img(r, model, season, kind):
        order = ["stump"] if kind == "stump" else sorted(KINDS, key=lambda k: abs(KINDS.index(k) - KINDS.index(kind)))
        for k in order:
            if (model, season, k) in art["trees"]:
                e = r.choice(art["trees"][(model, season, k)])
                if e["id"] not in cache:
                    p = e["sheet"]
                    if p not in art["sheets"]:
                        art["sheets"][p] = Image.open(ROOT / p).convert("RGBA")
                    x0, y0, ww, hh = e["rect"]
                    cache[e["id"]] = (art["sheets"][p].crop((x0, y0, x0 + ww, y0 + hh)), e["trunk_base"])
                return cache[e["id"]]
        raise KeyError((model, season, kind))

    # ---- 1 clearings in forest-like biomes
    r = streams["clear"]
    for _ in range(round(N * N / CLEARINGS_PER_CELLS)):
        x, y = r.uniform(0, N), r.uniform(0, N)
        nm = IDS[bgrid[int(y), int(x)]]
        if nm in BIOMES and BIOMES[nm]["fade"] and not keep[int(y), int(x)]:
            cr = r.uniform(*CLEAR_R)
            clearmask |= (xx + .5 - x) ** 2 + (yy + .5 - y) ** 2 <= cr * cr
            counts["clearing"] = counts.get("clearing", 0) + 1

    # ---- 2 trees
    r = streams["tree"]

    def place_tree(cell, model, season, kind):
        im, trunk = tree_img(r, model, season, kind)
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
            if not land_ok(c) or in_clear(px, py) or dist_kind(px, py, "trunk", 1.5):
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
            im = r.choice(art["deadbush"]) if bu.get("dead") else r.choice(art["bush"][r.choice(bu["colors"])])
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

    # ---- 5 flowers (+ foxglove-only patches)
    r = streams["flower"]

    def patch(b, x, y):
        fl = b["flower"]
        row, pts = r.choice(fl["rows"]), []
        for _ in range(fl["tries"]):
            px, py = x + peaked(r, fl["spread"]), y + peaked(r, fl["spread"])
            if land_ok((int(px), int(py))) and all(math.hypot(px - q[0], py - q[1]) >= 1.0 for q in pts):
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
            if land_ok((int(px), int(py))) and dist_kind(px, py, "trunk", m["shade"]):
                add("mushroom", r.choice(art["mush"]), px * S, py * S, base_off(art["mush"][0]))

    # ---- snow stumps, cattails (after the agreed passes, so they never move trees)
    r = streams["stump"]
    for b, x, y in tries(r, lambda b: b.get("stump", {}).get("per_block")):
        c = (int(x), int(y))
        if land_ok(c):
            im, trunk = tree_img(r, r.choice([1, 1, 2, 3]), "snow", "stump")
            add("stump_snow", im, (c[0] + .5) * S, (c[1] + 1) * S - 2, trunk)
            occ[c] = "trunk"
    r = streams["reed"]
    fresh = w["fresh"]
    d_fresh = w["d_fresh"]
    sy, sx = np.nonzero((d_fresh <= 3.2) & ~fresh & w["land"] & ~np.isin(bgrid, [ID["beach"], ID["gravel"]]))
    for x, y in zip(sx.tolist(), sy.tolist()):
        nm = IDS[bgrid[y, x]]
        if nm in NO_REED:
            continue
        if r.random() < REED_NEAR.get(nm, REED_NEAR["default"]):
            col = wchoice(r, BIOMES["swamp"]["reed"]["colors"])[0]
            for _ in range(10):
                px, py = x + .5 + peaked(r, 4.4), y + .5 + peaked(r, 4.4)
                c = (int(px), int(py))
                if 0 <= c[0] < N and 0 <= c[1] < N and c not in occ and not water[c[1], c[0]] and d_fresh[c[1], c[0]] <= 3.2 \
                        and not (HOME_FREE_R and home and math.hypot(c[0] - home[0], c[1] - home[1]) <= HOME_FREE_R):
                    im = r.choice(art["reed"][col])
                    occ[c] = "reed"
                    add("reed", im, px * S, py * S, base_off(im))

    # ---- 7 tufts
    r = streams["tuft"]
    for cy in range(N):
        for cx in range(N):
            c = (cx, cy)
            if c in occ or keep[cy, cx]:
                continue
            nm = biome_at(r, cx + .5, cy + .5)
            if nm not in BIOMES:
                continue
            b = BIOMES[nm]
            tf = b.get("tuft")
            if not tf:
                continue
            u = r.random()
            if u >= tf["p"] * 2:
                continue
            if u >= tf["p"] and not (near_kind(c, "trunk", 2) or near_kind(c, "rock", 1)):
                continue
            kind, col, _ = wchoice(r, tf["sets"])
            im = r.choice(art[kind][col])
            add("tuft" if kind == "tuft" else "fern", im, (cx + r.random()) * S, (cy + .6 + r.random() * .4) * S, base_off(im))

    print(f"placed {len(items)} sprites {time.time() - t00:.0f}s, drawing")
    t1 = time.time()
    items.sort(key=lambda i: i[0])
    for _, s, x, y in items:
        canvas.paste(s, (round(x), round(y)), s)
    print(f"draw {time.time() - t1:.0f}s")

    big = canvas.resize((2048, 2048), Image.LANCZOS)
    d = ImageDraw.Draw(big)
    k = 2048 / N
    for pt, col in ((home, (40, 220, 60)), (boss, (255, 40, 40))):
        if pt:
            cx, cy = (pt[0] + .5) * k, (pt[1] + .5) * k
            d.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=col, outline="white", width=2)
    if out:                                    # test render: only this file, docs/demo untouched
        big.resize((size, size), Image.LANCZOS).save(out)
        print("saved", out, f"{time.time() - t00:.0f}s")
        return
    big.save(OUT / "world_full.png")
    hx, hy = home
    x0, y0 = min(max(hx - 64, 0), N - 128), min(max(hy - 64, 0), N - 128)
    canvas.crop((x0 * S, y0 * S, (x0 + 128) * S, (y0 + 128) * S)).save(OUT / "world_full_crop.png")
    print("crop cells", (x0, y0), "total", f"{time.time() - t00:.0f}s")
    trees = sum(v for k_, v in counts.items() if k_.startswith("tree"))
    print("trees", trees, "total sprites", len(items))
    for k_ in sorted(counts):
        print(f"  {k_:22s}{counts[k_]}")


if __name__ == "__main__":
    # usage: world_full.py [seed [out.png [size]]]
    main(int(sys.argv[1]) if len(sys.argv) > 1 else wp.SEED, sys.argv[2] if len(sys.argv) > 2 else None,
         int(sys.argv[3]) if len(sys.argv) > 3 else 2048)
