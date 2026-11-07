"""Flat mini map ($0): 48x32 cells, every cell level 0 -> only flat borders, sand/water = foam. Pack sprites pasted unchanged.
Run from this folder: python3 flat_minimap.py -> flat_minimap.png (3x)"""
import json, math, random
import numpy as np
from PIL import Image
import borders as b
# the two pack-native grounds, flat like the rest (decision 0047; colours = PixelPlainsGround dark_fill / dirt_fill)
b.MAT["dark"] = dict(fill=(59, 125, 79), hl=(59, 125, 79), outline=(42, 89, 79), shade=(42, 89, 79))
b.MAT["dirt"] = dict(fill=(240, 181, 65), hl=(240, 181, 65), outline=(189, 106, 98), shade=(189, 106, 98))
b.MI.update({m: k for k, m in enumerate(b.MAT)}); b.PRIO.update(dark=3.5, dirt=2.5)   # dark over light grass, dirt under grass
W, H, C, Z = 48, 32, 16, 3
rng = random.Random(5)
g = [["grass"] * W for _ in range(H)]
def ell(cx, cy, rx, ry, m, ph=0):
    for y in range(H):
        for x in range(W):
            k = 1 + .12 * math.sin(3 * math.atan2(y - cy, x - cx) + ph)
            if ((x - cx) / (rx * k)) ** 2 + ((y - cy) / (ry * k)) ** 2 < 1: g[y][x] = m
ell(6, 5, 7, 5, "snow", .5)
ell(14, 24, 6, 4, "sand", 2)          # desert
ell(5, 18, 6, 5.5, "dark", 1.3)       # forest
ell(25, 13, 3, 2, "dirt", .7)          # dirt camp
ell(36, 12, 5, 3.5, "sand", 1); ell(36, 12, 3.4, 2, "water", 1)   # lake + beach ring
for y in range(H):
    for x in range(W):
        edge = 28 + round(1.5 * math.sin(x / 4)) ; east = 44 + round(math.sin(y / 3))
        if y >= edge: g[y][x] = "water"
        elif y >= edge - 2 or (x >= east - 2 and y > 14): g[y][x] = "sand"
        if x >= east and y > 14: g[y][x] = "water"
cells = [[(m, 0) for m in row] for row in g]
rgb, foam, _ = b.render(cells, b.BEACH_B)
rgb = b.frames(rgb, foam)[0]
img = Image.fromarray(rgb).convert("RGBA")
man = json.load(open("../../../assets/source/map/pixel_plains/manifest.json"))["sprites"]
sheets = {}
def spr(s):
    if s["file"] not in sheets: sheets[s["file"]] = Image.open("../../../assets/game/map/pixel_plains/" + s["file"]).convert("RGBA")
    x, y, w, h = s["region"]; return sheets[s["file"]].crop((x, y, x + w, y + h)), s["anchor"]
def pick(kind, var, **kw): return [s for s in man if s["kind"] == kind and s.get("variant") == var and all(s.get(k) == v for k, v in kw.items())]
def land(x, y, r=1): # all cells around are ok land (not water/sand-beach issues)
    return all(0 <= x + dx < W and 0 <= y + dy < H and g[y + dy][x + dx] != "water" for dx in range(-r, r + 1) for dy in range(-r, r + 1))
def on(x, y, m, r=1): return all(g[min(max(y + dy, 0), H - 1)][min(max(x + dx, 0), W - 1)] == m for dx in range(-r, r + 1) for dy in range(-r, r + 1))
objs, placed, boxes = [], [], []
def put(s, px, py, gap=0):   # foot at (px,py)
    im, a = spr(s); x, y = int(px - a[0]), int(py - a[1])
    if any(min(x + im.width, p) - max(x, q) > 2 and min(y + im.height, r) - max(y, t) > 2 for q, t, p, r in boxes) and gap: return False
    objs.append((py, im, x, y)); boxes.append((x, y, x + im.width, y + im.height)); return True
def scatter(n, reg, kind, var, m, spacing, r=1, tries=3000, **kw):
    pool = pick(kind, var, **kw); d = 0
    for _ in range(tries):
        if d >= n: break
        cx, cy = rng.randint(reg[0], reg[2]), rng.randint(reg[1], reg[3])
        if not on(cx, cy, m, r): continue
        px, py = cx * C + rng.randint(2, 13), cy * C + rng.randint(8, 15)
        if any((px - a) ** 2 + (py - c) ** 2 < spacing ** 2 for a, c in placed): continue
        if put(rng.choice(pool), px, py, gap=(kind in ("oak", "hedge"))): placed.append((px, py)); d += 1
oaks = lambda n, reg, var, m="grass": scatter(n, reg, "oak", var, m, 44, r=1)
oaks(14, (16, 2, 33, 25), "green"); oaks(7, (0, 12, 11, 24), "green", "dark")
oaks(9, (38, 14, 47, 27), "autumn_orange"); oaks(6, (38, 14, 47, 27), "red"); oaks(5, (38, 14, 47, 27), "yellow")
oaks(7, (0, 0, 12, 9), "snow", "snow")
scatter(4, (8, 1, 12, 9), "hedge", "green", "grass", 30, r=0); scatter(3, (20, 18, 30, 25), "hedge", "green", "grass", 30, r=0)
scatter(3, (38, 15, 46, 26), "hedge", "yellow", "grass", 30, r=0)
for k in ("log", "stump"): scatter(2, (9, 21, 19, 27), k, "orig", "sand", 20, r=0)
def decal(n, reg, kind, var, m, r=0):
    pool = pick(kind, var)
    for _ in range(4000):
        if n <= 0: break
        cx, cy = rng.randint(reg[0], reg[2]), rng.randint(reg[1], reg[3])
        if not on(cx, cy, m, r): continue
        px, py = cx * C + rng.randint(3, 12), cy * C + rng.randint(8, 15)
        s = pool[rng.randrange(len(pool))]; im, a = spr(s); x, y = px - a[0], py - a[1]
        if any(min(x + im.width, p) - max(x, q) > 0 and min(y + im.height, rr) - max(y, t) > 0 for q, t, p, rr in boxes): continue
        objs.append((py - 1000, im, int(x), int(y))); n -= 1   # decals under everything
for v, n in (("pink", 8), ("blue", 5), ("yellow", 5), ("mint", 4)): decal(n, (16, 3, 33, 25), "flower", v, "grass")
decal(30, (14, 2, 34, 26), "tuft", "green", "grass"); decal(16, (37, 14, 46, 26), "tuft", "yellow", "grass"); decal(8, (37, 14, 46, 26), "tuft", "brown", "grass")
decal(10, (0, 0, 13, 9), "tuft", "snow", "snow"); decal(6, (8, 21, 20, 27), "tuft", "brown", "sand")
for _, im, x, y in sorted(objs, key=lambda o: o[0]): img.alpha_composite(im, (x, y)) if x >= 0 and y >= 0 and x + im.width <= W * C and y + im.height <= H * C else img.paste(im, (x, y), im)
# no sprite may float on water: report
wet = sum(1 for _, im, x, y in objs if g[min(max((y + im.height - 2) // C, 0), H - 1)][min(max((x + im.width // 2) // C, 0), W - 1)] == "water")
print([(x//C,y//C,im.size) for _,im,x,y in objs if g[min(max((y+im.height-2)//C,0),H-1)][min(max((x+im.width//2)//C,0),W-1)]=="water"]); print("sprites", len(objs), "on water", wet)
img.convert("RGB").resize((W * C * Z, H * C * Z), Image.NEAREST).save("flat_minimap.png")
