"""Tree catalog for Pixel Crawler trees: finds every sprite per sheet, writes data/maps/tree_catalog.json and a
growth-cycle preview docs/demo/tree_catalog.png (green trees, seedling -> old, then other seasons + stump at size 4).

Sheets are regular grids (cell size per sheet below). Inside a cell we find sprites by alpha connected components;
Size_02 cells hold several growth stages (kept separate), other cells hold one tree (components merged by union box).

Run: python3 tools/asset_viewer/tree_catalog.py
"""
import json
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
TREES = Path("assets/source/third_party/pixel_crawler/Environment/Props/Static/Trees")
# (model, size): cell w, h, dead_x0 (extra dead column, or None), stump spec
#   ("x", x0) = stumps are the components right of x0, top to bottom;  ("row", y0) = stumps in grid row below y0
CELLS = {
    (1, 2): (64, 64, None, None), (1, 3): (48, 96, None, ("x", 193)),
    (1, 4): (82, 128, None, ("x", 325)), (1, 5): (112, 160, None, ("row", 320)),
    (2, 2): (64, 48, None, None), (2, 3): (48, 80, 99, ("x", 117)),
    (2, 4): (64, 112, 141, ("x", 153)), (2, 5): (96, 160, 197, ("x", 229)),
    (3, 2): (64, 80, None, None), (3, 3): (64, 144, 137, ("x", 153)),
    (3, 4): (96, 208, 202, ("x", 230)), (3, 5): (128, 256, 271, ("x", 304)),
}
# (col, row) -> (season, variant); models 2/3 have only 2x2 colour cells
SEASONS = {
    1: {(0, 0): ("green", "a"), (1, 0): ("yellow", "a"), (2, 0): ("dead", "a"), (3, 0): ("snow", "a"),
        (0, 1): ("orange", "a"), (1, 1): ("orange", "b"), (2, 1): ("dead", "b"), (3, 1): ("snow", "b")},
    2: {(0, 0): ("teal", "a"), (1, 0): ("teal", "b"), (0, 1): ("green", "a"), (1, 1): ("green", "b")},
    3: {(0, 0): ("green", "a"), (1, 0): ("yellow", "a"), (0, 1): ("orange", "a"), (1, 1): ("red", "a")},
}
STUMPS = {1: [("brown", "a"), ("brown", "b"), ("snow", "a"), ("moss", "a")],
          2: [("snow", "a"), ("brown", "a")], 3: [("snow", "a"), ("brown", "a")]}
SIZE_STAGE = {3: "mature", 4: "mature", 5: "old"}


def comps(im):
    """8-connected alpha components -> list of [x, y, w, h]."""
    w, h = im.size
    p = im.getchannel("A").load()
    seen, out = set(), []
    for y in range(h):
        for x in range(w):
            if p[x, y] and (x, y) not in seen:
                q, x0, y0, x1, y1 = deque([(x, y)]), x, y, x, y
                seen.add((x, y))
                while q:
                    cx, cy = q.popleft()
                    x0, x1, y0, y1 = min(x0, cx), max(x1, cx), min(y0, cy), max(y1, cy)
                    for dx in (-1, 0, 1):
                        for dy in (-1, 0, 1):
                            n = (cx + dx, cy + dy)
                            if 0 <= n[0] < w and 0 <= n[1] < h and p[n] and n not in seen:
                                seen.add(n)
                                q.append(n)
                out.append([x0, y0, x1 - x0 + 1, y1 - y0 + 1])
    return out


def union(rs):
    x0, y0 = min(r[0] for r in rs), min(r[1] for r in rs)
    x1, y1 = max(r[0] + r[2] for r in rs), max(r[1] + r[3] for r in rs)
    return [x0, y0, x1 - x0, y1 - y0]


def trunk_base(im, r):
    """Bottom centre of the sprite's lowest opaque rows (the trunk / stump foot), px inside the rect."""
    a = im.getchannel("A").crop((r[0], r[1], r[0] + r[2], r[1] + r[3]))
    p, w, h = a.load(), r[2], r[3]
    xs = [x for y in (h - 1, h - 2) for x in range(w) if p[x, y]]
    return [round((min(xs) + max(xs)) / 2), h - 1]


def find_sprites(im, model, size):
    """-> list of (rect, season, variant, stage) for one sheet."""
    cw, ch, dead_x0, stump = CELLS[(model, size)]
    seasons, found = SEASONS[model], []
    stump_x0 = stump[1] if stump and stump[0] == "x" else im.width
    grid_w = dead_x0 if dead_x0 else stump_x0
    cols = min(grid_w // cw, 4)
    for (c, r), (season, var) in seasons.items():
        x0, y0 = c * cw, r * ch
        if x0 >= grid_w or y0 + ch > im.height:
            continue
        crop = im.crop((x0, y0, x0 + cw, y0 + ch))
        cs = [[a + x0, b + y0, w, h] for a, b, w, h in comps(crop)]
        cs = [c_ for c_ in cs if c_[0] < grid_w]
        if stump and stump[0] == "row":
            cs = [c_ for c_ in cs if c_[1] < stump[1]]
        if not cs:
            continue
        if size == 2:
            cs.sort(key=lambda r_: r_[2] * r_[3])
            for i, r_ in enumerate(cs):
                stage = "young" if i == len(cs) - 1 else ("sapling" if i == len(cs) - 2 else "seedling")
                found.append((r_, season, var, stage))
        else:
            found.append((union(cs), season, var, SIZE_STAGE[size]))
    if dead_x0:
        cs = [r_ for r_ in comps(im) if dead_x0 <= r_[0] < stump_x0]
        found.append((union(cs), "dead", "a", SIZE_STAGE.get(size, "young")))
    if stump:
        if stump[0] == "x":
            cs = sorted((r_ for r_ in comps(im) if r_[0] >= stump[1]), key=lambda r_: r_[1])
        else:
            cs = sorted((r_ for r_ in comps(im) if r_[1] >= stump[1]), key=lambda r_: r_[0])
        for r_, (season, var) in zip(cs, STUMPS[model]):
            found.append((r_, season, var, "stump"))
    return found


def build():
    entries = []
    for (model, size) in CELLS:
        path = TREES / f"Model_{model:02d}" / f"Size_{size:02d}.png"
        im = Image.open(ROOT / path).convert("RGBA")
        for r, season, var, stage in find_sprites(im, model, size):
            entries.append({"sheet": str(path), "rect": r, "model": model, "size": size, "stage": stage,
                            "season": season, "variant": var, "trunk_base": trunk_base(im, r)})
    for i, e in enumerate(entries):
        e["id"] = f"m{e['model']}_s{e['size']}_{e['season']}{e['variant']}_{e['stage']}_{i}"
    return entries


def render(entries, out_path):
    Z, GRASS, GAP = 2, (122, 160, 92, 255), 10
    green = {1: "green", 2: "green", 3: "green"}
    order = {"seedling": 0, "sapling": 1, "young": 2, "mature": 3, "old": 4}
    rows = []  # (model, list of entries)
    for m in (1, 2, 3):
        main = sorted((e for e in entries if e["model"] == m and e["season"] == green[m] and e["variant"] == "a"
                       and e["stage"] != "stump"), key=lambda e: (e["size"], e["rect"][2] * e["rect"][3]))
        other = [e for e in entries if e["model"] == m and e["size"] == 4 and e["variant"] == "a"
                 and (e["season"] != green[m] or e["stage"] == "stump")]
        rows += [main, other]
    cache = {}
    def img(e):
        if e["sheet"] not in cache:
            cache[e["sheet"]] = Image.open(ROOT / e["sheet"]).convert("RGBA")
        x, y, w, h = e["rect"]
        return cache[e["sheet"]].crop((x, y, x + w, y + h)).resize((w * Z, h * Z), Image.NEAREST)
    LAB = 26
    heights = [max(e["rect"][3] for e in r) * Z + LAB + 12 for r in rows]
    def label(e):
        if e["stage"] == "stump":
            return f"stump {e['season']}"
        return f"{e['stage']} {e['size']}" if e["season"] == green[e["model"]] else f"{e['season']} {e['size']}"
    meas = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    def step(e):
        return max(e["rect"][2] * Z, int(meas.textlength(label(e)))) + GAP
    width = max(sum(step(e) for e in r) for r in rows) + GAP * 2
    sheet = Image.new("RGBA", (width, sum(heights)), GRASS)
    d, y0 = ImageDraw.Draw(sheet), 0
    for r, hgt in zip(rows, heights):
        ground, x = y0 + hgt - LAB - 6, GAP  # ground line: every trunk base sits here
        d.line((0, ground, width, ground), fill=(100, 138, 74, 255))
        for e in r:
            im = img(e)
            bx, by = e["trunk_base"]
            sheet.alpha_composite(im, (x, ground - by * Z - Z))
            d.text((x, ground + 6), label(e), fill=(20, 30, 15, 255))
            x += step(e)
        y0 += hgt
    sheet.convert("RGB").save(ROOT / out_path)


if __name__ == "__main__":
    es = build()
    (ROOT / "data/maps/tree_catalog.json").write_text(json.dumps(es, indent=1))
    render(es, "docs/demo/tree_catalog.png")
    from collections import Counter
    for k, v in sorted(Counter((e["model"], e["stage"]) for e in es).items()):
        print(k, v)
    print(len(es), "sprites")
