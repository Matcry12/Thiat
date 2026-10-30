"""Border cases demo ($0): every cell has a LEVEL. Different levels -> STEP border (pack outline + shadow, higher ground on top,
shadow down-right). Same level -> FLAT border (same pack quarter SHAPES, outline / shadow pixels remapped: notch shape only).
All borders come from the pack's light_on_dirt quarters (upper / lower), recoloured per pixel ROLE by border().
Run: python3 tools/art_tests/recolour/borders.py -> borders_demo.png (3x panels), borders_demo.gif (8 frames, 8 fps, foam panels)"""
import numpy as np
from PIL import Image, ImageDraw
import recolour as rc
import pixel_plains_tiles as pp
import water as wt

C, Z, NF, FPS = 16, 3, 8, 8
# pixel roles of the light_on_dirt pieces (upper = light grass, lower = dirt)
ROLE_PX = {"fill": (99, 171, 63), "hl": (164, 196, 67), "outline": (42, 89, 79), "shadow": (189, 106, 98), "lower": (240, 181, 65)}
FOAM = "foam"   # role colour marker: animated foam (blinks along the notch rhythm)
MAT = {   # fill / highlight / outline when this material is the upper one; shade = shadow cast ONTO it
    "grass": dict(fill=(99, 171, 63), hl=(164, 196, 67), outline=(42, 89, 79), shade=(59, 125, 79)),
    "sand":  dict(fill=(236, 214, 150), hl=(248, 232, 182), outline=(150, 112, 84), shade=(170, 134, 100)),
    "water": dict(fill=wt.FLAT_SHALLOW, hl=wt.FLAT_SHALLOW, outline=wt.FLAT_SHALLOW, shade=(52, 140, 188)),
    "snow":  dict(fill=(240, 246, 252), hl=(255, 255, 255), outline=(150, 170, 204), shade=(214, 228, 242)),
}
WET_SAND = (204, 176, 118)
MI = {m: k for k, m in enumerate(MAT)}
dim = lambda c, k=0.92: tuple(int(v * k) for v in c)   # notch colour for the quiet flat variants: ~8% darker than the fill
PRIO = {"snow": 4, "grass": 3, "sand": 2, "water": 1}   # same level: who takes the pack's upper shape

def border(upper, lower, mode, roles=None):
    """role -> colour for a light_on_dirt piece. step: upper's outline + highlight, shadow in the lower's shade.
    flat: quiet edge, no shadow (outline -> upper fill 8% darker, highlight -> upper fill, shadow -> lower fill). roles overrides any role."""
    u, l = MAT[upper], MAT[lower]
    r = dict(fill=u["fill"], hl=u["hl"], outline=u["outline"], shadow=l["shade"], lower=l["fill"]) if mode == "step" else \
        dict(fill=u["fill"], hl=u["fill"], outline=dim(u["fill"]), shadow=l["fill"], lower=l["fill"])   # flat = quiet edge (user pick 2b/5b)
    r.update(roles or {}); return r

ROLE_MASKS = {}
def role_masks(mask):   # {role: 16x16 bool} of the pack tile for this dual-grid mask
    if mask not in ROLE_MASKS:
        t = np.array(pp.tile_image("light_on_dirt", mask)[0])[..., :3]
        ROLE_MASKS[mask] = {k: (t == v).all(2) for k, v in ROLE_PX.items()}
        assert sum(ROLE_MASKS[mask].values()).all(), mask   # every pixel has a role
    return ROLE_MASKS[mask]

def render(cells, roles=None):
    """cells[y][x] = (mat, level). Layered dual grid: per corner paint the lowest layer, then each higher layer with its
    border against the layer right below it (3-way corners: higher pieces go on top, no holes).
    roles: {(upper, lower): {role: colour}} overrides. Returns (rgb, foam mask, fallback rgb under the foam)."""
    H, W = len(cells), len(cells[0])
    g = lambda x, y: cells[min(max(y, 0), H - 1)][min(max(x, 0), W - 1)]
    rank = lambda c: (c[1], PRIO[c[0]])
    out = np.zeros((H * C + C, W * C + C, 3), np.uint8); hole = np.ones(out.shape[:2], bool); foam = np.zeros_like(hole)
    under = np.zeros(out.shape[:2], np.int8)   # material index of the ground at each pixel
    for j in range(H + 1):
        for i in range(W + 1):
            q = [g(i - 1, j - 1), g(i, j - 1), g(i - 1, j), g(i, j)]
            layers = sorted(set(q), key=rank)
            ys, xs = slice(j * C, j * C + C), slice(i * C, i * C + C)
            out[ys, xs] = MAT[layers[0][0]]["fill"]; hole[ys, xs] = False; under[ys, xs] = MI[layers[0][0]]
            for lo, up in zip(layers, layers[1:]):
                mask = sum(b for b, c in zip((1, 2, 4, 8), q) if rank(c) >= rank(up))
                mode = "step" if up[1] != lo[1] else "flat"
                ov = (roles or {}).get((up[0], lo[0]) if mode == "flat" else None) or {}
                rl = border(up[0], lo[0], mode, ov)
                rm = role_masks(mask)
                for role, m in rm.items():
                    if role == "lower": continue          # transparent: the layer below shows
                    o, u, fm = out[ys, xs], under[ys, xs], foam[ys, xs]
                    if role == "shadow" and "shadow" not in ov:   # shadow colour = the material actually under each pixel (3-way corners)
                        if mode == "step":
                            for name, k in MI.items():
                                mk = m & (u == k); o[mk] = MAT[name]["shade"]
                            fm &= ~m
                        continue                          # flat: shadow -> fill of what is under = no change
                    if rl[role] == FOAM: fm |= m; o[m] = rl["fill"]; u[m] = MI[up[0]]; continue
                    o[m] = rl[role]; fm &= ~m
                    if role != "shadow": u[m] = MI[up[0]]
    sl = (slice(C // 2, C // 2 + H * C), slice(C // 2, C // 2 + W * C))   # dual grid is offset by half a cell
    assert not hole[sl].any()
    return out[sl], foam[sl], under[sl]

def frames(rgb, foam):   # foam phase steps 1 px per frame, 6 of every 8 px lit: 8 distinct frames, equal change per step, seamless
    ys, xs = np.mgrid[:rgb.shape[0], :rgb.shape[1]]   # phase runs along x + y: vertical and horizontal shores move alike
    res = []
    for f in range(NF):
        o = rgb.copy(); o[foam & (((xs + ys - f) % 8) < 6)] = wt.FOAM; res.append(o)
    return res

BLOB = [".........."
       ,".###...##."
       ,".###...###"
       ,".########."   # 1-cell neck between the two lobes
       ,".##....##."
       ,"..#....#.."
       ,".........."]
def blob(inside, outside): return [[inside if ch == "#" else outside for ch in row] for row in BLOB]
COAST = ["GGGGGGGGGG", "GGGGGGGGGG", "sssGGGGbbb", "ssssGGbbbb", "wsswwGbwww", "wwwwwwwwww", "wwwwwwwwww"]
CK = {"G": ("grass", 2), "s": ("sand", 0), "b": ("sand", 1), "w": ("water", 0)}
BEACH = {("sand", "water"): {"outline": FOAM, "hl": MAT["sand"]["fill"], "shadow": WET_SAND}}
BEACH_B = {("sand", "water"): {"outline": FOAM, "hl": MAT["sand"]["fill"], "shadow": MAT["water"]["fill"]}}
PANELS = [   # (label, cells, flat-pair role overrides)
    ("1 beach, step: grass(2) over sand(1)", blob(("grass", 2), ("sand", 1)), None),
    ("2 sand biome, flat: grass = sand level", blob(("grass", 1), ("sand", 1)), {("grass", "sand"): {"outline": MAT["grass"]["fill"]}}),
    ("2b sand biome, flat: notch 8% darker", blob(("grass", 1), ("sand", 1)), {("grass", "sand"): {"outline": dim(MAT["grass"]["fill"])}}),
    ("3 flat beach: sand = water, foam + wet sand", blob(("sand", 0), ("water", 0)), BEACH),
    ("3b flat beach: foam, shadow -> water", blob(("sand", 0), ("water", 0)), BEACH_B),
    ("4 sand bank, step: sand(1) over water(0)", blob(("sand", 1), ("water", 0)), None),
    ("5 snowy biome, flat: snow = grass level", blob(("snow", 2), ("grass", 2)), {("snow", "grass"): {"outline": MAT["snow"]["fill"]}}),
    ("5b snowy biome, flat: notch 8% darker", blob(("snow", 2), ("grass", 2)), {("snow", "grass"): {"outline": dim(MAT["snow"]["fill"])}}),
    ("6 snow on top, step: snow(3) over grass(2)", blob(("snow", 3), ("grass", 2)), None),
    ("7 mixed coast: step + flat beach + bank", [[CK[ch] for ch in row] for row in COAST], BEACH_B),
]

def palette(m, roles):   # colours a pixel may have when material m is the ground there
    p = {tuple(v) for v in MAT[m].values()}
    for (up, lo), ov in (roles or {}).items():
        for k, v in ov.items():
            if v == FOAM: continue
            if k == "shadow" and lo == m: p.add(tuple(v))
            if k != "shadow" and up == m: p.add(tuple(v))
    return p

def expected(cells, roles):   # every colour a panel may hold: fills + the roles of each pair that touches
    H, W = len(cells), len(cells[0]); mats = {m for row in cells for m, _ in row}; ok = {MAT[m]["fill"] for m in mats}; foam = False
    pairs = {tuple(sorted({cells[y][x], cells[min(y + dy, H - 1)][min(x + dx, W - 1)]}, key=lambda c: (c[1], PRIO[c[0]])))
             for y in range(H) for x in range(W) for dx in (0, 1) for dy in (0, 1)}
    for p in pairs:
        if len(p) < 2: continue
        lo, up = p; mode = "step" if up[1] != lo[1] else "flat"
        r = border(up[0], lo[0], mode, (roles or {}).get((up[0], lo[0]) if mode == "flat" else None))
        for k in ("fill", "hl", "outline", "shadow"):
            if r[k] == FOAM: foam = True
            else: ok.add(tuple(r[k]))
        if mode == "step": ok |= {MAT[m]["shade"] for m in mats}   # a 3-way shadow takes the shade of whatever lies under it
    if foam: ok.add(wt.FOAM)
    return ok

if __name__ == "__main__":
    fnt = rc.font(17); pad = 20; cols = 4
    renders = [(lab, *render(cells, roles), expected(cells, roles), roles) for lab, cells, roles in PANELS]
    pw, ph = renders[0][1].shape[1] * Z, renders[0][1].shape[0] * Z
    def sheet(idx, f):
        rows = -(-len(idx) // cols); n = min(cols, len(idx))
        s = Image.new("RGB", (n * (pw + pad) + pad, rows * (ph + 40 + pad) + pad), rc.BG); d = ImageDraw.Draw(s)
        for k, p in enumerate(idx):
            lab, rgb, foam = renders[p][:3]; x, y = pad + (k % cols) * (pw + pad), pad + (k // cols) * (ph + 40 + pad)
            d.text((x, y), lab, fill=(235, 235, 235), font=fnt)
            s.paste(Image.fromarray(frames(rgb, foam)[f]).resize((pw, ph), Image.NEAREST), (x, y + 34))
        return s
    sheet(range(len(renders)), 0).save("borders_demo.png")
    fp = [k for k, r in enumerate(renders) if r[2].any()]
    g = [sheet(fp, f) for f in range(NF)]
    g[0].save("borders_demo.gif", save_all=True, append_images=g[1:], duration=[130, 120] * (NF // 2), loop=0)
    names = list(MAT)
    for lab, rgb, foam, under, ok, roles in renders:   # self-check: only expected colours, and each pixel fits the ground under it
        frs = frames(rgb, foam)
        got = set().union(*({tuple(c) for c in fr.reshape(-1, 3)} for fr in frs))
        bad = got - ok; assert not bad, (lab, bad)
        for k, m in enumerate(names):
            px = {tuple(c) for c in rgb[under == k]}; wrong = px - palette(m, roles); assert not wrong, (lab, m, wrong)
        print(f"{lab[:44]:44s} colours {len(got):2d} ok, foam px {int(foam.sum())}")
    gi = Image.open("borders_demo.gif"); n = gi.n_frames; assert n == NF, n
    fr = []
    for i in range(n): gi.seek(i); fr.append(np.array(gi.convert("RGB")))
    print("gif frames", n, "foam panels", fp, "changed px per step", [int((fr[i] != fr[(i + 1) % n]).any(2).sum()) for i in range(n)])
