"""Preview: a Minecraft-style 2D world from smooth climate noise ($0, no game code).
Method: docs/reference/worldgen-biomes-water-research.md. Vegetation: docs/wiki/vegetation-rules.md (same passes as
biome_preview.py, here driven by a per-biome table). Writes to docs/demo/:
  world_layers.png  5 panels: continentalness, temperature, humidity, rivers+lakes, biomes
  world_map.png     512x512 biome map, 2 px/cell, legend, home/boss, one-screen box
  world_bad.png     same map, biomes random per Voronoi region (the naive way)
  world_zoom_A.png  river crossing Forest -> Taiga, real sprites (16 px cells, x2)
  world_zoom_B.png  lake + swamp edge (or snowy border), real sprites

Run: python3 tools/asset_viewer/world_preview.py [seed]
"""
import json
import math
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi

from meadow_preview import ROOT, S, bbox, load_sprites

OUT = ROOT / "docs/demo"
SEED = 7
N = 512                            # world size, cells
SCREEN = (36, 21)                  # one screen, cells

# --- noise periods (cells per feature) and warp
P_CONT, P_TEMP, P_HUMID, P_ROUGH, P_RIDGE, P_LAKE = 230, 300, 150, 100, 110, 55
WARP_P, WARP_AMP = 90, 28          # domain warp: wavelength, strength (cells)
OCTAVES = 4
# --- continent
CONT_RADIAL = 0.55                 # weight of the "one blob" falloff vs noise
CONT_EDGE_CELLS = 70               # forced ocean this close to the map edge
LAND_SHARE = 0.42                  # target share of land (sea level is a quantile)
MIN_LAND_BLOB = 80                 # smaller land islands are removed
# --- water
RIVER_W = (1.5, 2.5)               # half width in cells (so 3-5 wide): inland .. at the sea
RIVER_BIG_N = 2                    # the longest rivers (by cells) are widened
RIVER_BIG_W = (2.5, 5.5)           # their half width: inland (5-6 wide) .. at the sea (7-12 wide at the mouth)
RIVER_BIG_REACH = 3                # cells around the river's thin version that may be widened
RIVER_GROW_DIST = 110              # distance from sea (cells) over which width goes max -> min
RIVER_ROUGH_MAX = 0.88             # no river on peaks (roughness above this): rivers start there
RIVER_MIN_CELLS = 40               # drop river pieces smaller than this
LAKE_BIG_N = 3                     # landmark lakes per island, radius range (15-25 cells across)
LAKE_BIG_R = (9.5, 12.5)
LAKE_BIG_ON_RIVER = 2              # this many big lakes sit ON a river path (river flows through)
LAKE_POND_N = 30                   # small ponds, radius range (3-8 cells across)
LAKE_POND_R = (1.5, 4.0)
LAKE_POND_ON_RIVER = 0.3           # share of ponds next to a river
LAKE_WARP = 3.5                    # edge irregularity (noise strength, in radii)
LAKE_SHAPE_PERIOD = 11             # cells per wobble of the lake edge
LAKE_POND_WET_MIN = 0.62           # ponds only where the low-frequency wetness noise (rank 0..1) is above this: they cluster
LAKE_POND_WET_PERIOD = 70          # cells per wetness bump
LAKE_POND_STRETCH = (1.0, 2.4)     # a pond blob is stretched this much along a random direction
LAKE_POND_BLOBS = (1, 3)           # blobs merged into one pond
LAKE_GAP = 4                       # cells kept between two lakes
LAKE_HUMID_MIN = 0.35              # lake centres only where humidity is above this
LAKE_INLAND_MIN = 8                # extra cells from the sea beyond the radius
LAKE_ROUGH_MAX = 0.85
LAKE_MIN_CELLS = 6
BEACH_W = (1.5, 3.2)               # beach band width, varies with noise
SAND_SHORE = ("plains", "autumn")   # freshwater shore is sand in these biomes, dirt elsewhere
SHORE_W = 1.5                      # sand/dirt shore around lakes and rivers (cells)
COLD_BEACH_T = 0.30                # temperature below this: gravel instead of sand
SWAMP_WATER_DIST = 10              # swamp can sit this close to fresh water
SWAMP_HUMID_MIN, SWAMP_ROUGH_MAX, SWAMP_T = 0.45, 0.6, (0.40, 0.88)
# --- biome lookup: (temperature, humidity, roughness) points; weights stretch the axes
LOOKUP_W = (3.0, 1.0, 1.1)
BIOME_POINTS = {                   # ordered cold -> warm on temperature, so cold and hot can't touch
    "snowy": [(.05, .20, .40), (.05, .80, .40)],
    "taiga": [(.25, .30, .40), (.25, .70, .40)],
    "rocky": [(.20, .50, 1.3), (.45, .50, 1.3), (.70, .30, 1.3)],
    "forest": [(.52, .60, .30), (.55, .45, .35)],
    "plains": [(.55, .20, .20), (.80, .15, .20), (.55, .35, .15)],
    "autumn": [(.80, .60, .35), (.78, .85, .35)],
}
SMOOTH_PASSES, SMOOTH_SIZE = 2, 7  # majority filter on the land biome map
MIN_BIOME_BLOB = 90                # smaller biome patches are absorbed
TEMP_CLASS = {"snowy": 0, "taiga": 1, "forest": 2, "plains": 2, "swamp": 2, "autumn": 3}  # rocky: exempt
# --- start / boss
HOME_NEIGHBOUR_R, HOME_OPEN_SHARE, HOME_COAST_MIN = 12, 0.9, 10
BOSS_BIOMES = ("rocky", "snowy")
BOSS_COAST_MIN = 8                 # boss spot is not on the beach
BOSS_MIN_PATCH = 4                 # boss spot: this many cells of boss biome around it
# --- bad map
BAD_SITES = 70
# --- zoom renders
ZOOM = (48, 27)
ZOOM_PAD = 6                       # extra cells drawn around so big sprites at the edge are complete
ZOOM_SCALE = 2
ZOOM_STRIDE = 4
# --- vegetation per biome (tries per 16x16 block are scaled by area)
BLOCK = 16
TREE_TRIES = 14
TREE_DENSITY = {"plains": 0.04, "forest": 0.9, "autumn": 0.85, "taiga": 0.8, "snowy": 0.5, "rocky": 0.10, "swamp": 0.22}
PLAINS_RING = 3
# tree mix per biome: (weight, model 1 oak / 2 fir / 3 pine, seasons)
TREE_MIX = {
    "plains": [(1, 1, ["green"])],
    "forest": [(.8, 1, ["green"]), (.2, 2, ["green"])],
    "autumn": [(.5, 1, ["yellow", "orange"]), (.5, 3, ["red", "orange", "yellow"])],
    "taiga": [(.55, 2, ["green"]), (.2, 2, ["teal"]), (.25, 3, ["green"])],
    "snowy": [(.65, 1, ["snow"]), (.35, 2, ["teal"])],
    "rocky": [(.34, 1, ["dead"]), (.33, 2, ["dead"]), (.33, 3, ["dead"])],
    "swamp": [(.34, 1, ["dead"]), (.33, 2, ["dead"]), (.33, 3, ["dead"])],
}
AGE_MIX = [("old", 5, .22), ("mature", 4, .40), ("mature", 3, .16), ("young", 2, .12), ("sapling", 2, .10)]
ROCK_PER_BLOCK = {"plains": 1.0, "forest": .5, "autumn": .5, "taiga": .6, "snowy": .5, "rocky": 4.0, "swamp": .2}
ROCK_SMALL, ROCK_MEDIUM, ROCK_SPREAD = (2, 5), (0, 2), 1.5
BUSH_PER_BLOCK = {"plains": .5, "forest": .9, "autumn": .9, "taiga": .35, "swamp": .6}
BUSH_COLOR = {"plains": 0, "forest": 0, "taiga": 0, "swamp": 0, "autumn": 6}    # veg sheet column of the colour
FLOWER_PER_BLOCK, FLOWER_TRIES, FLOWER_R = 0.8, 50, 3.0
MUSH_PER_BLOCK, MUSH_SHADE = 5, 2.0
CATTAIL_PER_BLOCK, CATTAIL_TRIES, CATTAIL_R, CATTAIL_WATER_DIST = 10, 8, 2.0, 3.0
TUFT_P = {"plains": .06, "forest": .12, "autumn": .10, "taiga": .08, "swamp": .10, "snowy": 0, "rocky": .02}
# --- ground fills in assets/game/map/Floors_Tiles.png (col, row) + Water_tiles.png
FILLS = {
    "grass": [(1, 10), (2, 10), (3, 10)], "dirt": [(11, 10), (12, 10), (13, 10)],
    "stone": [(6, 10), (7, 10), (8, 10)], "sand": [(5, 22), (6, 22), (7, 22), (8, 22)],
    "snow": [(1, 22), (2, 22), (3, 22), (4, 22)],
}
WATER_FILLS = [(2, 7), (2, 8), (3, 7), (1, 7)]
GROUND_TINT = {"swamp": (.62, .78, .62), "autumn": (1.08, .98, .72), "taiga": (.88, 1.0, 1.08), "rocky": (1, 1, 1)}
ROCKY_STONE_SHARE = 0.55           # rocky hills: share of cells with grey stone floor

# --- biome ids + colours
IDS = ["ocean", "beach", "river", "lake", "plains", "forest", "autumn", "taiga", "snowy", "rocky", "swamp", "gravel"]
ID = {n: i for i, n in enumerate(IDS)}
LABEL = {"ocean": "Ocean", "beach": "Beach (sand)", "river": "River", "lake": "Lake", "plains": "Plains", "forest": "Forest",
         "autumn": "Autumn forest", "taiga": "Taiga", "snowy": "Snowy taiga", "rocky": "Rocky hills", "swamp": "Swamp",
         "gravel": "Beach (gravel, cold)"}
COLOR = {"ocean": (28, 62, 130), "beach": (236, 214, 140), "river": (74, 150, 224), "lake": (96, 190, 236),
         "plains": (160, 208, 96), "forest": (40, 116, 52), "autumn": (214, 120, 34), "taiga": (30, 92, 96),
         "snowy": (238, 244, 252), "rocky": (128, 122, 118), "swamp": (78, 92, 48), "gravel": (170, 166, 152)}
LAND = ["plains", "forest", "autumn", "taiga", "snowy", "rocky", "swamp"]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default(sz)


# ---------------------------------------------------------------- noise
def vnoise(x, y, period, tab):
    """Smooth value noise 0..1 at float coordinate arrays x, y."""
    fx, fy = x / period, y / period
    ix, iy = np.floor(fx).astype(int), np.floor(fy).astype(int)
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    m = tab.shape[0]
    a, b = tab[iy % m, ix % m], tab[iy % m, (ix + 1) % m]
    c, d = tab[(iy + 1) % m, ix % m], tab[(iy + 1) % m, (ix + 1) % m]
    return (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty


def fbm(x, y, period, rng, octaves=OCTAVES):
    tot, amp, norm, p = 0, 1.0, 0, period
    for _ in range(octaves):
        tot = tot + amp * vnoise(x, y, p, rng.random((256, 256)))
        norm += amp
        amp, p = amp * .5, p / 2
    return tot / norm


def rank01(a, mask=None):
    """Percentile transform: values -> 0..1 evenly spread (keeps order, so smoothness stays)."""
    v = a if mask is None else a[mask]
    r = np.empty(a.shape)
    srt = np.sort(v.ravel())
    r[...] = np.searchsorted(srt, a) / len(srt)
    return np.clip(r, 0, 1)


def comps(mask):
    return ndi.label(mask)


# ---------------------------------------------------------------- world
def build(seed):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:N, 0:N].astype(float)
    wx = (fbm(xx, yy, WARP_P, rng, 3) - .5) * 2 * WARP_AMP
    wy = (fbm(xx, yy, WARP_P, rng, 3) - .5) * 2 * WARP_AMP
    X, Y = xx + wx, yy + wy                                     # domain-warped sample positions

    # continentalness: noise + one big blob, forced ocean at the edge
    base = rank01(fbm(X, Y, P_CONT, rng))
    r = np.hypot((xx - N / 2) / (N / 2), (yy - N / 2) / (N / 2))
    cont = (1 - CONT_RADIAL) * base + CONT_RADIAL * np.clip(1 - r ** 1.8, 0, 1)
    edge = np.minimum.reduce([xx, yy, N - 1 - xx, N - 1 - yy])
    cont = cont * np.clip(edge / CONT_EDGE_CELLS, 0, 1) ** .7
    sea = np.quantile(cont, 1 - LAND_SHARE)
    land = cont > sea
    lab, n = comps(land)
    sizes = ndi.sum(land, lab, range(1, n + 1))
    keep = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= MIN_LAND_BLOB])
    land = keep
    ocean = ~land
    d_ocean = ndi.distance_transform_edt(land)                  # cells from the sea, inside land

    temp = rank01(fbm(X, Y, P_TEMP, rng), land)
    humid = rank01(fbm(X, Y, P_HUMID, rng), land)
    rough = rank01(fbm(X, Y, P_ROUGH, rng), land)

    # rivers: zero line of a ridge noise; width in cells = |n| / |grad n|
    n_r = rank01(fbm(X, Y, P_RIDGE, rng, 5)) - .5
    gy, gx = np.gradient(n_r)
    dist_est = np.abs(n_r) / np.maximum(np.hypot(gx, gy), 1e-6)
    grow = np.clip(1 - d_ocean / RIVER_GROW_DIST, 0, 1)
    w = RIVER_W[0] + (RIVER_W[1] - RIVER_W[0]) * grow
    river = (dist_est < w) & land & (rough < RIVER_ROUGH_MAX)
    lab, n = comps(river | ~land)                                      # joined with the sea: keep pieces that reach it
    sea_lab = lab[0, 0]
    river = river & (lab == sea_lab)
    lab, n = comps(river)
    sizes = ndi.sum(river, lab, range(1, n + 1))
    river = np.isin(lab, [i + 1 for i, s in enumerate(sizes) if s >= RIVER_MIN_CELLS])
    lab, n = comps(river)                                              # widen the longest rivers
    if n and RIVER_BIG_N:
        sizes = ndi.sum(river, lab, range(1, n + 1))
        wb = RIVER_BIG_W[0] + (RIVER_BIG_W[1] - RIVER_BIG_W[0]) * grow
        for k in np.argsort(sizes)[::-1][:RIVER_BIG_N]:
            near = ndi.binary_dilation(lab == k + 1, iterations=RIVER_BIG_REACH)
            big = (dist_est < wb) & near & land
            river |= big
            w = np.where(big, np.maximum(w, wb), w)
    river_len = float((1 / (2 * w[river])).sum())

    # lakes: big landmarks (some on a river path) + small ponds, edges wobbled by noise (domain-warped coordinates)
    shape = (fbm(X, Y, LAKE_SHAPE_PERIOD, rng, 3) - .5) * 2
    humid_ok = land & (humid > LAKE_HUMID_MIN) & (rough < LAKE_ROUGH_MAX)
    lake = np.zeros((N, N), bool)
    placed = []                                                        # (x, y, r)
    ry, rx = np.nonzero(river & (d_ocean > 14))

    wet = rank01(fbm(X, Y, LAKE_POND_WET_PERIOD, rng, 2), land)
    pond_cells = np.argwhere(humid_ok & (wet > LAKE_POND_WET_MIN) & (d_ocean > 12))

    def try_lake(rad, on_river, pond):
        for _ in range(60):
            if on_river and len(rx):
                i = int(rng.integers(len(rx)))
                cx, cy = rx[i] + rng.uniform(-rad, rad) * (1.2 if pond else .3), ry[i] + rng.uniform(-rad, rad) * (1.2 if pond else .3)
            elif pond:
                if not len(pond_cells):
                    return None
                cy, cx = pond_cells[int(rng.integers(len(pond_cells)))] + rng.random(2)
            else:
                cx, cy = rng.uniform(0, N), rng.uniform(0, N)
            ix, iy = int(min(max(cx, 0), N - 1)), int(min(max(cy, 0), N - 1))
            if not humid_ok[iy, ix] or d_ocean[iy, ix] < rad * 1.4 + LAKE_INLAND_MIN:
                continue
            if any(np.hypot(cx - px, cy - py) < rad + pr + (1 if pond else LAKE_GAP) for px, py, pr in placed):
                continue
            placed.append((cx, cy, rad))
            return cx, cy
        return None

    def stamp(cx, cy, rad, k, ang, stretch):
        x0, x1, y0, y1 = [int(v) for v in (cx - rad * 3, cx + rad * 3, cy - rad * 3, cy + rad * 3)]
        x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, N), min(y1, N)
        gx_, gy_ = np.meshgrid(np.arange(x0, x1) + .5 - cx, np.arange(y0, y1) + .5 - cy)
        u = (gx_ * math.cos(ang) + gy_ * math.sin(ang)) / stretch
        v = -gx_ * math.sin(ang) + gy_ * math.cos(ang)
        d = np.hypot(u, v) / rad + shape[y0:y1, x0:x1] * LAKE_WARP * k
        lake[y0:y1, x0:x1] |= d < 1

    for i in range(LAKE_BIG_N + LAKE_POND_N):
        big = i < LAKE_BIG_N
        rad = rng.uniform(*(LAKE_BIG_R if big else LAKE_POND_R))
        on = (i < LAKE_BIG_ON_RIVER) if big else (rng.random() < LAKE_POND_ON_RIVER)
        c = try_lake(rad, on, not big)
        if c is None:
            continue
        if big:
            stamp(c[0], c[1], rad, .25, 0, 1)
            continue
        ang = rng.uniform(0, math.pi)
        for _ in range(int(rng.integers(LAKE_POND_BLOBS[0], LAKE_POND_BLOBS[1] + 1))):
            off = rng.uniform(.6, 1.4) * rad
            a2 = ang + rng.uniform(-.5, .5)
            stamp(c[0] + math.cos(a2) * off * (len(placed) % 2 * 2 - 1), c[1] + math.sin(a2) * off, rad * rng.uniform(.6, 1.0),
                  .22, ang, rng.uniform(*LAKE_POND_STRETCH))
    lake &= land & (d_ocean > 2)
    lab, n = comps(lake)
    sizes = ndi.sum(lake, lab, range(1, n + 1))
    lake = np.isin(lab, [i + 1 for i, s_ in enumerate(sizes) if s_ >= LAKE_MIN_CELLS])
    river &= ~lake
    n_lakes = int(comps(lake)[1])
    fresh = river | lake
    d_fresh = ndi.distance_transform_edt(~fresh)

    # biomes: nearest point in (t, h, r)
    pts, names = [], []
    for nme, ps in BIOME_POINTS.items():
        for p in ps:
            pts.append(p)
            names.append(ID[nme])
    pts, names = np.array(pts), np.array(names)
    wv = np.array(LOOKUP_W)
    best = np.full((N, N), 1e9)
    biome = np.zeros((N, N), int)
    for p, nm in zip(pts, names):
        dd = (((temp - p[0]) * wv[0]) ** 2 + ((humid - p[1]) * wv[1]) ** 2 + ((rough - p[2]) * wv[2]) ** 2)
        m = dd < best
        best[m], biome[m] = dd[m], nm
    biome[ocean] = ID["plains"]
    biome = _majority(biome, land)
    biome = _absorb_small(biome, land)
    swamp = (d_fresh + (fbm(X, Y, 12, rng, 2) - .5) * 6 < SWAMP_WATER_DIST) & (humid > SWAMP_HUMID_MIN) \
        & (rough < SWAMP_ROUGH_MAX) & (temp > SWAMP_T[0]) & (temp < SWAMP_T[1]) & land
    biome[swamp] = ID["swamp"]

    # beach: thin band at the sea, sand when warm, gravel when cold
    bw = BEACH_W[0] + (BEACH_W[1] - BEACH_W[0]) * fbm(X, Y, 20, rng, 2)
    beach = land & (d_ocean <= bw) & ~fresh
    biome[beach] = np.where(temp[beach] < COLD_BEACH_T, ID["gravel"], ID["beach"])
    biome[fresh] = np.where(river[fresh], ID["river"], ID["lake"])
    biome[ocean] = ID["ocean"]
    shore = land & ~fresh & (d_fresh <= SHORE_W) & ~beach        # sand/dirt ring, drawn in the sprite zoom only

    return dict(seed=seed, cont=cont, sea=sea, temp=temp, humid=humid, rough=rough, land=land, ocean=ocean, d_ocean=d_ocean,
                river=river, lake=lake, fresh=fresh, d_fresh=d_fresh, shore=shore, biome=biome, river_len=river_len,
                n_lakes=n_lakes, noise_r=n_r, patch=fbm(X, Y, 9, rng, 2))


def _majority(biome, land):
    """Mode filter over the land biomes only, SMOOTH_PASSES times (kills speckle)."""
    ids = [ID[n] for n in BIOME_POINTS]
    for _ in range(SMOOTH_PASSES):
        score = np.stack([ndi.uniform_filter(((biome == i) & land).astype(float), SMOOTH_SIZE) for i in ids])
        new = np.array(ids)[score.argmax(0)]
        biome = np.where(land, new, biome)
    return biome


def _absorb_small(biome, land):
    """Patches smaller than MIN_BIOME_BLOB take the nearest big biome."""
    ids = [ID[n] for n in BIOME_POINTS]
    for _ in range(2):
        small = np.zeros(biome.shape, bool)
        for i in ids:
            lab, n = comps((biome == i) & land)
            sizes = ndi.sum(lab > 0, lab, range(1, n + 1))
            for k, s in enumerate(sizes):
                if s < MIN_BIOME_BLOB:
                    small |= lab == k + 1
        if not small.any():
            break
        _, (iy, ix) = ndi.distance_transform_edt(small | ~land, return_indices=True)
        biome = np.where(small, biome[iy, ix], biome)
    return biome


def pick_points(w):
    """Home (open Plains/Forest, inland) and boss (farthest reachable rocky/snowy spot). Rivers can be crossed."""
    b, land = w["biome"], w["land"]
    openb = (b == ID["plains"]) | (b == ID["forest"])
    share = ndi.uniform_filter(openb.astype(float), 2 * HOME_NEIGHBOUR_R + 1)
    ok = (share >= HOME_OPEN_SHARE) & (w["d_ocean"] >= HOME_COAST_MIN) & openb & ~ndi.binary_dilation(w["fresh"], iterations=3)
    ys, xs = np.nonzero(ok)
    if not len(xs):
        return None, None
    cy, cx = ndi.center_of_mass(land)
    i = np.argmin((xs - cx) ** 2 + (ys - cy) ** 2)
    home = (int(xs[i]), int(ys[i]))
    walk = land & ~w["lake"] & (b != ID["ocean"])                # rivers are bridgeable, lakes and sea are not
    dist = np.full((N, N), -1)
    dist[home[1], home[0]] = 0
    fr = [home]
    while fr:
        nf = []
        for x, y in fr:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                a, c = x + dx, y + dy
                if 0 <= a < N and 0 <= c < N and walk[c, a] and dist[c, a] < 0:
                    dist[c, a] = dist[y, x] + 1
                    nf.append((a, c))
        fr = nf
    bossb = np.zeros((N, N), bool)
    for nm in BOSS_BIOMES:
        bossb |= b == ID[nm]
    patch = ndi.minimum_filter(bossb.astype(np.uint8), 2 * BOSS_MIN_PATCH + 1) > 0
    cand = patch & (dist >= 0) & (w["d_ocean"] >= BOSS_COAST_MIN)
    if not cand.any():
        cand = bossb & (dist >= 0)
    ys, xs = np.nonzero(cand)
    j = np.argmax(dist[ys, xs])
    return home, (int(xs[j]), int(ys[j]))


def violations(biome):
    """Count neighbouring cell pairs whose temperature classes differ by 2+ (snow next to autumn/forest...)."""
    cls = np.full(biome.shape, -9)
    for nm, c in TEMP_CLASS.items():
        cls[biome == ID[nm]] = c
    bad = 0
    for a, b in ((cls[:, :-1], cls[:, 1:]), (cls[:-1], cls[1:])):
        ok = (a > -9) & (b > -9)
        bad += int((ok & (np.abs(a - b) >= 2)).sum())
    return bad


def adjacency(biome):
    names = LAND
    M = np.zeros((len(names), len(names)), int)
    idx = {ID[n]: i for i, n in enumerate(names)}
    for a, b in ((biome[:, :-1], biome[:, 1:]), (biome[:-1], biome[1:])):
        for u in idx:
            for v in idx:
                if u < v:
                    M[idx[u], idx[v]] += int(((a == u) & (b == v) | (a == v) & (b == u)).sum())
    return names, M


def good_world(w):
    sh = {n: (w["biome"] == ID[n]).sum() / w["land"].sum() for n in LAND}
    return 0.30 < w["land"].mean() < 0.62 and sum(v > .025 for v in sh.values()) >= 6 and w["n_lakes"] >= 2 \
        and w["river"].sum() > 300 and violations(w["biome"]) == 0 and min(sh["snowy"], sh["rocky"]) > .02


# ---------------------------------------------------------------- pictures
def rgb(b):
    lut = np.array([COLOR[n] for n in IDS], np.uint8)
    return lut[b]


def to_img(arr, size):
    return Image.fromarray(arr).resize((size, size), Image.NEAREST)


def ramp(v, stops):
    """v 0..1 -> rgb through colour stops [(pos, (r,g,b)), ...]."""
    pos = [s[0] for s in stops]
    return np.stack([np.interp(v, pos, [s[1][c] for s in stops]) for c in range(3)], -1).astype(np.uint8)


def panels(w, path):
    P, M, T = 300, 12, 66
    ocean_col = np.array(COLOR["ocean"])
    cont = np.where(w["ocean"][..., None], ocean_col, ramp(np.clip((w["cont"] - w["sea"]) / (w["cont"].max() - w["sea"]), 0, 1),
                    [(0, (214, 200, 140)), (.25, (110, 170, 80)), (.7, (150, 130, 80)), (1, (240, 240, 240))])).astype(np.uint8)
    temp = np.where(w["ocean"][..., None], ocean_col, ramp(w["temp"], [(0, (90, 140, 255)), (.5, (240, 240, 150)), (1, (230, 60, 40))])).astype(np.uint8)
    hum = np.where(w["ocean"][..., None], ocean_col, ramp(w["humid"], [(0, (222, 196, 130)), (.5, (120, 190, 120)), (1, (30, 90, 200))])).astype(np.uint8)
    wat = np.full((N, N, 3), (232, 226, 200), np.uint8)
    wat[w["ocean"]] = COLOR["ocean"]
    wat[w["river"]] = (40, 110, 230)
    wat[w["lake"]] = (40, 200, 240)
    # thicken rivers a bit so 300 px stays readable
    thick = ndi.binary_dilation(w["river"], iterations=1) & w["land"]
    wat[thick & ~w["lake"]] = (40, 110, 230)
    items = [("1 Continentalness", "sea vs land: 1 slow blob", cont), ("2 Temperature", "blue cold -> red warm, slow", temp),
             ("3 Humidity", "dry tan -> wet blue, medium", hum), ("4 Rivers + lakes", "thin ridge lines, wet pockets", wat),
             ("5 Biomes", "maps 2 + 3 + roughness -> table", rgb(w["biome"]))]
    img = Image.new("RGB", (len(items) * (P + M) + M, P + T + M + 40), (24, 24, 28))
    d = ImageDraw.Draw(img)
    for i, (t, sub, a) in enumerate(items):
        x = M + i * (P + M)
        img.paste(to_img(a, P), (x, T))
        d.text((x, 8), t, fill="white", font=font(17))
        d.text((x, 34), sub, fill=(190, 190, 200), font=font(12))
        if i < len(items) - 1:
            d.text((x + P + 1, T + P // 2 - 10), "+", fill="white", font=font(18))
    d.text((M, T + P + 10), "Smooth climate maps (panels 1-4) are mixed by a lookup table into biomes (panel 5). "
           "Neighbours always have similar temperature.", fill=(220, 220, 230), font=font(13))
    img.save(path)


def legend(d, x, y, w, pct):
    d.text((x, y), "Biomes (cold -> warm)", fill="white", font=font(15))
    y += 24
    order = ["snowy", "taiga", "rocky", "forest", "plains", "swamp", "autumn"]
    for n in order + ["beach", "gravel", "river", "lake", "ocean"]:
        d.rectangle([x, y, x + 18, y + 14], fill=COLOR[n], outline=(255, 255, 255))
        d.text((x + 26, y - 1), f"{LABEL[n]}  {pct.get(n, 0):.1f}%", fill="white", font=font(13))
        y += 22
    return y


def markers(d, home, boss, px, ox=0, oy=0):
    for pt, col, ch in ((home, (40, 220, 60), "H"), (boss, (255, 40, 40), "B")):
        if pt:
            cx, cy = ox + pt[0] * px, oy + pt[1] * px
            d.ellipse([cx - 11, cy - 11, cx + 11, cy + 11], fill=col, outline="white", width=2)
            d.text((cx - 5, cy - 9), ch, fill="black", font=font(15))


def pct_of(biome, land_n):
    """% of land for land biomes + beaches, % of the whole map for water."""
    return {n: 100 * (biome == ID[n]).sum() / (N * N if n in ("ocean", "river", "lake") else land_n) for n in IDS}


def map_img(biome, w, home, boss, title, path, extra=()):
    px = 2
    L = 300
    img = Image.new("RGB", (N * px + L + 20, N * px + 56), (24, 24, 28))
    d = ImageDraw.Draw(img)
    d.text((10, 6), title, fill="white", font=font(18))
    img.paste(Image.fromarray(rgb(biome)).resize((N * px, N * px), Image.NEAREST), (10, 40))
    markers(d, home, boss, px, 10, 40)
    y = legend(d, N * px + 24, 44, L, pct_of(biome, w["land"].sum()))
    if home:
        hx, hy = 10 + home[0] * px, 40 + home[1] * px
        d.rectangle([hx - SCREEN[0] * px / 2, hy - SCREEN[1] * px / 2, hx + SCREEN[0] * px / 2, hy + SCREEN[1] * px / 2], outline="white", width=2)
        d.text((hx + 40, hy - 10), "= 1 screen (36 x 21 cells)", fill="white", font=font(12))
    d.text((N * px + 24, y + 6), "H = home start    B = boss site", fill="white", font=font(13))
    y += 30
    for line in extra:
        d.text((N * px + 24, y), line, fill=(255, 210, 120), font=font(13))
        y += 20
    img.save(path)


def bad_map(w):
    rng = np.random.default_rng(w["seed"] + 99)
    ys, xs = np.nonzero(w["land"])
    sites = np.stack([rng.choice(xs, BAD_SITES), rng.choice(ys, BAD_SITES)], 1)
    kinds = np.array([ID[n] for n in LAND])[rng.integers(0, len(LAND), BAD_SITES)]
    yy, xx = np.mgrid[0:N, 0:N]
    dd = (xx[..., None] - sites[:, 0]) ** 2 + (yy[..., None] - sites[:, 1]) ** 2
    bad = kinds[dd.argmin(-1)]
    b = w["biome"].copy()
    land_biome = (b != ID["ocean"]) & (b != ID["river"]) & (b != ID["lake"]) & (b != ID["beach"]) & (b != ID["gravel"])
    b[land_biome] = bad[land_biome]
    return b


# ---------------------------------------------------------------- sprites + vegetation
class Art:
    def __init__(self):
        self.R, self.sp = load_sprites()
        self.floors = Image.open(ROOT / "assets/game/map/Floors_Tiles.png").convert("RGBA")
        self.water = Image.open(ROOT / "assets/game/map/Water_tiles.png").convert("RGBA")
        self.veg = Image.open(ROOT / "assets/game/map/Vegetation.png").convert("RGBA")
        self.cat = json.load(open(ROOT / "data/maps/tree_catalog.json"))
        self.sheets = {}
        self.mush = [self.veg.crop(bbox(self.veg, c, 21, c + 1, 22)) for c in range(8)]
        cat_boxes = [bbox(self.veg, c, r, c + 1, r + 2) for r in (10, 13) for c in (8, 9, 10)]
        self.cattail = [self.veg.crop(b) for b in cat_boxes]
        self.bush = {c: [self.veg.crop(bbox(self.veg, c, a, c + 3, b)) for a, b in ((0, 2), (2, 4))] for c in (0, 3, 6)}

    def sheet(self, p):
        if p not in self.sheets:
            self.sheets[p] = Image.open(ROOT / p).convert("RGBA")
        return self.sheets[p]

    def tree(self, rng, model, seasons, bias_young=False):
        season = rng.choice(seasons)
        mix = AGE_MIX
        if bias_young:
            mix = [(a, s, wt * (2 if a in ("young", "sapling") else 1)) for a, s, wt in mix]
        for _ in range(8):                                       # fall back when a colour lacks that age
            u, acc = rng.random() * sum(m[2] for m in mix), 0
            for stage, size, wt in mix:
                acc += wt
                if u <= acc:
                    break
            pool = [e for e in self.cat if e["model"] == model and e["season"] == season and e["stage"] == stage and e["size"] == size]
            if pool:
                e = rng.choice(pool)
                x0, y0, ww, hh = e["rect"]
                return self.sheet(e["sheet"]).crop((x0, y0, x0 + ww, y0 + hh)), e["trunk_base"]
        pool = [e for e in self.cat if e["model"] == model and e["season"] == season and e["stage"] in ("mature", "old")]
        e = rng.choice(pool)
        x0, y0, ww, hh = e["rect"]
        return self.sheet(e["sheet"]).crop((x0, y0, x0 + ww, y0 + hh)), e["trunk_base"]


def ground_kind(w, x, y, patch_stone):
    """Floor fill name for one cell."""
    b = IDS[w["biome"][y, x]]
    if b in ("ocean", "river", "lake"):
        return "water"
    if b == "beach":
        return "sand"
    if b == "gravel":
        return "stone"
    if w["shore"][y, x]:
        return "sand" if b in SAND_SHORE else "dirt"
    if b == "snowy":
        return "snow"
    if b == "rocky" and patch_stone[y, x] < ROCKY_STONE_SHARE:
        return "stone"
    return "grass"


def tint(t, k):
    a = np.array(t, float)
    a[..., :3] *= np.array(k)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))


def render_zoom(w, art, x0, y0, path, seed):
    """Real-sprite render of ZOOM cells at (x0, y0). Same pass order as vegetation-rules.md."""
    rng = random.Random(seed)
    cw, ch = ZOOM
    ax0, ay0 = max(x0 - ZOOM_PAD, 0), max(y0 - ZOOM_PAD, 0)
    ax1, ay1 = min(x0 + cw + ZOOM_PAD, N), min(y0 + ch + ZOOM_PAD, N)
    W_, H_ = ax1 - ax0, ay1 - ay0
    patch_stone = rank01(w["patch"])
    img = Image.new("RGBA", (W_ * S, H_ * S))
    gcell = {}
    for y in range(ay0, ay1):
        for x in range(ax0, ax1):
            g = ground_kind(w, x, y, patch_stone)
            gcell[(x, y)] = g
            if g == "water":
                c = rng.choice(WATER_FILLS)
                t = art.water.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
            else:
                c = rng.choice(FILLS[g])
                t = art.floors.crop((c[0] * S, c[1] * S, c[0] * S + S, c[1] * S + S))
                for op in (Image.FLIP_LEFT_RIGHT, Image.FLIP_TOP_BOTTOM, Image.TRANSPOSE):
                    if rng.random() < .5:
                        t = t.transpose(op)
                if g == "grass":
                    k = GROUND_TINT.get(IDS[w["biome"][y, x]])
                    if k:
                        t = tint(t, k)
            img.alpha_composite(t, ((x - ax0) * S, (y - ay0) * S))

    def bio(x, y):
        return IDS[w["biome"][min(max(int(y), 0), N - 1), min(max(int(x), 0), N - 1)]]

    occ, trunks, items, counts = {}, [], [], {}

    def land_ok(c):
        return ax0 <= c[0] < ax1 and ay0 <= c[1] < ay1 and c not in occ and gcell[c] in ("grass", "snow", "stone")

    def add(kind, im, px, py, off):
        items.append((py, im, px - off[0], py - off[1]))
        counts[kind] = counts.get(kind, 0) + 1

    def rnd_pts(rate):
        v = rate * W_ * H_ / (BLOCK * BLOCK)
        for _ in range(int(v) + (rng.random() < v - int(v))):
            yield ax0 + rng.random() * W_, ay0 + rng.random() * H_

    def base(im):
        return (im.width // 2, im.height)

    # trees
    for x, y in rnd_pts(TREE_TRIES):
        b = bio(x, y)
        dens = TREE_DENSITY.get(b)
        if not dens or rng.random() >= dens:
            continue
        c = (int(x), int(y))
        if not land_ok(c) or any((c[0] + dx, c[1] + dy) in occ for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            continue
        if b == "plains" and any(occ.get((c[0] + dx, c[1] + dy)) == "trunk" for dx in range(-PLAINS_RING, PLAINS_RING + 1) for dy in range(-PLAINS_RING, PLAINS_RING + 1)):
            continue
        mix = TREE_MIX[b]
        u, acc = rng.random() * sum(m[0] for m in mix), 0
        for wt, model, seasons in mix:
            acc += wt
            if u <= acc:
                break
        im, tb = art.tree(rng, model, seasons, bias_young=(b == "snowy"))
        add(f"tree_{b}", im, (c[0] - ax0 + .5) * S, (c[1] - ay0 + 1) * S - 2, tb)
        occ[c] = "trunk"
        trunks.append(c)
    # rocks
    for x, y in rnd_pts(max(ROCK_PER_BLOCK.values())):
        b = bio(x, y)
        if rng.random() >= ROCK_PER_BLOCK.get(b, 0) / max(ROCK_PER_BLOCK.values()):
            continue
        med = rng.randint(*ROCK_MEDIUM)
        parts = [("m", x, y)] * (med > 0) + [("s", x + math.cos(a) * d, y + math.sin(a) * d * .7)
                                              for a, d in ((rng.uniform(0, math.tau), ROCK_SPREAD * math.sqrt(rng.random())) for _ in range(rng.randint(*ROCK_SMALL)))]
        for k, px, py in parts:
            c = (int(px), int(py))
            if land_ok(c) and not any(math.hypot(px - t[0] - .5, py - t[1] - .5) < 1.5 for t in trunks):
                im = rng.choice(art.sp["rock_mid"] if k == "m" else art.sp["stone"])
                occ[c] = "rock"
                add("rock", im, (px - ax0) * S, (py - ay0) * S, base(im))
    # bushes
    for x, y in rnd_pts(max(BUSH_PER_BLOCK.values())):
        b = bio(x, y)
        if rng.random() < BUSH_PER_BLOCK.get(b, 0) / max(BUSH_PER_BLOCK.values()):
            for _ in range(rng.randint(1, 4)):
                px, py = x + rng.uniform(-2, 2), y + rng.uniform(-2, 2)
                c = (int(px), int(py))
                if land_ok(c) and bio(px, py) == b:
                    im = rng.choice(art.bush[BUSH_COLOR[b]])
                    occ[c] = "bush"
                    add("bush", im, (px - ax0) * S, (py - ay0) * S, base(im))
    # flowers (plains)
    for x, y in rnd_pts(FLOWER_PER_BLOCK):
        if bio(x, y) != "plains":
            continue
        row = rng.randrange(4)
        for _ in range(FLOWER_TRIES):
            px, py = x + rng.uniform(-FLOWER_R / 2, FLOWER_R / 2) + rng.uniform(-FLOWER_R / 2, FLOWER_R / 2), y + rng.uniform(-FLOWER_R / 2, FLOWER_R / 2) + rng.uniform(-FLOWER_R / 2, FLOWER_R / 2)
            c = (int(px), int(py))
            if land_ok(c) and bio(px, py) == "plains" and rng.random() < .5:
                im = art.sp["flower"][row][rng.randrange(5)]
                occ[c] = "flower"
                add("flower", im, (px - ax0) * S, (py - ay0) * S, base(im))
    # mushrooms (forest / taiga, in tree shade)
    for x, y in rnd_pts(MUSH_PER_BLOCK):
        if bio(x, y) in ("forest", "taiga", "autumn") and any(math.hypot(x - t[0] - .5, y - t[1] - .5) <= MUSH_SHADE for t in trunks):
            c = (int(x), int(y))
            if land_ok(c):
                im = rng.choice(art.mush)
                occ[c] = "mush"
                add("mushroom", im, (x - ax0) * S, (y - ay0) * S, base(im))
    # cattails / reeds: swamp, and any land cell touching fresh water
    for x, y in rnd_pts(CATTAIL_PER_BLOCK):
        c = (int(x), int(y))
        near = w["d_fresh"][min(max(c[1], 0), N - 1), min(max(c[0], 0), N - 1)] <= CATTAIL_WATER_DIST
        if bio(x, y) == "swamp" or (near and bio(x, y) != "snowy" and rng.random() < .35):
            if not near:
                continue
            for _ in range(rng.randint(1, CATTAIL_TRIES // 2)):
                px, py = x + rng.uniform(-CATTAIL_R, CATTAIL_R), y + rng.uniform(-CATTAIL_R, CATTAIL_R)
                cc = (int(px), int(py))
                if land_ok(cc) or (cc in gcell and gcell[cc] in ("dirt", "sand") and cc not in occ):
                    im = rng.choice(art.cattail)
                    occ[cc] = "cattail"
                    add("cattail", im, (px - ax0) * S, (py - ay0) * S, base(im))
    # tufts
    for cy in range(ay0, ay1):
        for cx in range(ax0, ax1):
            b = IDS[w["biome"][cy, cx]]
            if (cx, cy) in occ or gcell[(cx, cy)] != "grass" or not TUFT_P.get(b):
                continue
            if rng.random() < TUFT_P[b]:
                im = rng.choice(art.sp["tuft"])
                add("tuft", im, (cx - ax0 + rng.random()) * S, (cy - ay0 + .6 + rng.random() * .4) * S, base(im))
    for _, im, px, py in sorted(items, key=lambda i: i[0]):
        img.alpha_composite(im, (round(px), round(py)))
    crop = img.crop(((x0 - ax0) * S, (y0 - ay0) * S, (x0 - ax0 + cw) * S, (y0 - ay0 + ch) * S))
    crop.resize((cw * S * ZOOM_SCALE, ch * S * ZOOM_SCALE), Image.NEAREST).convert("RGB").save(path)
    return counts


def find_crop(w, score):
    best, bxy = -1, None
    m = ZOOM_PAD + 1
    for y in range(m, N - ZOOM[1] - m, ZOOM_STRIDE):
        for x in range(m, N - ZOOM[0] - m, ZOOM_STRIDE):
            s = score(w["biome"][y:y + ZOOM[1], x:x + ZOOM[0]])
            if s > best:
                best, bxy = s, (x, y)
    return bxy, best


def score_A(b):
    c = lambda n: (b == ID[n]).mean()
    riv = (b == ID["river"]).sum()
    if c("ocean") > 0 or c("lake") > 0 or riv < 40:
        return -1
    return min(c("forest"), .35) + min(c("taiga"), .35) + min(riv / 250, .3) - c("rocky") * .5 - c("swamp") * 2 - c("snowy")


def score_B(b):
    c = lambda n: (b == ID[n]).mean()
    if c("ocean") > 0:
        return -1
    lake = (b == ID["lake"]).sum()
    sw = c("swamp")
    return min(lake / 120, 1) + min(sw / .15, 1) + (.3 if c("forest") + c("plains") > .15 else 0) if lake > 25 and sw > .03 else -1


# ---------------------------------------------------------------- main
def main(seed0):
    w = None
    for s in range(seed0, seed0 + 60):
        w = build(s)
        if good_world(w):
            break
    else:
        print("WARNING no seed passed the quality gate, using last", s)
    home, boss = pick_points(w)
    land_n = w["land"].sum()
    pct = pct_of(w["biome"], land_n)
    OUT.mkdir(exist_ok=True)
    panels(w, OUT / "world_layers.png")
    good_v, bad_b = violations(w["biome"]), bad_map(w)
    bad_v = violations(bad_b)
    map_img(w["biome"], w, home, boss, f"World 512x512 cells (seed {w['seed']}): climate noise -> biomes", OUT / "world_map.png",
            [f"cold/warm clashes: {good_v}"])
    map_img(bad_b, w, home, boss, "The naive way: random biome per Voronoi region", OUT / "world_bad.png",
            [f"cold/warm clashes: {bad_v}", "(snow touching autumn/plains...)"])
    art = Art()
    ca, sa = find_crop(w, score_A)
    cb, sb = find_crop(w, score_B)
    cnt_a = render_zoom(w, art, ca[0], ca[1], OUT / "world_zoom_A.png", w["seed"] * 10 + 1)
    cnt_b = render_zoom(w, art, cb[0], cb[1], OUT / "world_zoom_B.png", w["seed"] * 10 + 2)

    print("seed", w["seed"], "land share", round(float(w["land"].mean()), 3), "home", home, "boss", boss)
    print("cells per biome (% of land; water % of map):")
    for n in IDS:
        cells = int((w["biome"] == ID[n]).sum())
        share = 100 * cells / (N * N) if n in ("ocean", "river", "lake") else 100 * cells / land_n
        print(f"  {n:8s}{cells:8d}  {share:5.1f}%")
    print(f"river cells {int(w['river'].sum())}  approx length {w['river_len']:.0f} cells  lakes {w['n_lakes']}")
    print("cold/warm clashes: climate", good_v, " naive", bad_v)
    names, M = adjacency(w["biome"])
    print("land biome borders (cell edges):")
    for i, a in enumerate(names):
        print("  ", a.ljust(8), " ".join(f"{M[i, j]:6d}" for j in range(len(names))))
    print("  columns:", " ".join(n[:6].rjust(6) for n in names))
    print("zoom A at", ca, round(sa, 2), cnt_a)
    print("zoom B at", cb, round(sb, 2), cnt_b)


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else SEED)
