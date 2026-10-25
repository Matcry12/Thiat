"""16x16 diagonal icons built from shapes in a rotated frame (a = along handle to top-right, b = across),
then auto-shaded in the held-sprite style. Run: python3 icon_lab.py <out_dir>"""
import math, sys
from PIL import Image
from draw_tools import PAL, TIERS

N = 16
# icons only: paler tan head ramp so a wood head does not blend into the wood handle (held sprites keep TIERS)
WOOD_ICON = [(96,66,36), (124,88,50), (178,132,78), (226,184,124), (250,228,180)]
R2 = math.sqrt(2)


def ab(x, y):
    cx, cy = x + .5, y + .5
    return (cx - cy) / R2, (cx + cy - N) / R2


class Icon:
    def __init__(s):
        s.g = [['.'] * N for _ in range(N)]

    def fill(s, pred, ch):            # ch: char or fn(a, b) -> char
        for y in range(N):
            for x in range(N):
                a, b = ab(x, y)
                if pred(a, b):
                    s.g[y][x] = ch(a, b) if callable(ch) else ch

    def metal(s, pred):               # flat 3, light rim top-left (4 inside, 3 edge), dark 2 bottom-right
        cells = pred if isinstance(pred, set) else {(x, y) for y in range(N) for x in range(N) if pred(*ab(x, y))}
        for (x, y) in cells:
            inn = lambda dx, dy: (x + dx, y + dy) in cells
            if not inn(1, 0) or not inn(0, 1):
                c = '2'
            elif not inn(-1, 0) or not inn(0, -1):
                c = '3'
            elif not inn(-1, -1) or not inn(-2, 0) or not inn(0, -2):
                c = '4'
            else:
                c = '3'
            s.g[y][x] = c
        return cells

    def handle(s, a0, a1, wrap_to=None):
        def ch(a, b):
            if wrap_to is not None and a < wrap_to:
                return ('W' if b < .4 else 'w') if int((a + 20) * 1.4) % 2 else ('w' if b < .4 else 'x')
            return 'c' if b < -.35 else ('b' if b < .45 else 'a')
        s.fill(lambda a, b: a0 <= a <= a1 and -1.05 <= b <= 1.05, ch)

    def outline(s):
        add = [(x, y) for y in range(N) for x in range(N) if s.g[y][x] == '.' and
               ((x > 0 and s.g[y][x - 1] not in '.O') or (y > 0 and s.g[y - 1][x] not in '.O'))]
        for x, y in add:
            s.g[y][x] = 'O'
        return [''.join(r) for r in s.g]


def pickaxe():
    # Measured from Terraria refs (see scratchpad items/d1/structure.md): one band perpendicular to the handle,
    # centred on it; top arm 45 deg (4 rows, 4-5 px wide), bend, down arm vertical + tapering; 1 px handle core
    # with flanks, handle stub poking past the head top; FULL outline (like every ref).
    s = Icon()
    spans = {1: (7, 10), 2: (9, 12), 3: (10, 13), 4: (11, 13), 5: (12, 14), 6: (13, 14), 7: (13, 14), 8: (14, 14)}
    head = {(x, y) for y, (x0, x1) in spans.items() for x in range(x0, x1 + 1)}
    core = [(15 - y, y) for y in range(5, N)] + [(14, 1), (13, 2)]       # handle axis x+y=15
    for (x, y) in core:
        if (x, y) in head:
            continue
        s.g[y][x] = 'x' if y >= 14 else 'w' if y >= 12 else ('c' if y % 2 else 'b')
    s.metal(head)
    # full outline on every side (outline() later adds nothing: it skips existing O)
    add = [(x, y) for y in range(N) for x in range(N) if s.g[y][x] == '.' and any(
        0 <= x + dx < N and 0 <= y + dy < N and s.g[y + dy][x + dx] not in '.O'
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in add:
        s.g[y][x] = 'O'
    s.g[0][10] = '.'                                                    # ref cap is 3 px (x7-9)
    return s


def s_get(s, a, b):
    return True


def _fo(s):
    """full dark outline on all four sides (like the pickaxe and every ref)"""
    add = [(x, y) for y in range(N) for x in range(N) if s.g[y][x] == '.' and any(
        0 <= x + dx < N and 0 <= y + dy < N and s.g[y + dy][x + dx] not in '.O'
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for x, y in add:
        s.g[y][x] = 'O'


def _core(s, y0, skip=()):                      # 1 px handle core on x+y=15, bottom rows wrapped
    for y in range(y0, N):
        if (15 - y, y) not in skip:
            s.g[y][15 - y] = 'x' if y >= 14 else 'w' if y >= 12 else ('c' if y % 2 else 'b')


AXE_ROWS = """
................
................
........O...O34O
.......O3OO3445O
.......O2OO3345O
........O114335O
........Ob14335O
.......OcOO1435O
......ObO..O322O
.....OcO....O22O
....ObO......OO.
...OcO..........
..OwO...........
.OwO............
OxO.............
xO..............
"""


def _set(s, ch, cells):
    for (x, y) in cells:
        s.g[y][x] = ch


def axe():
    # Terraria axe, hand-set grid: narrow base, edge fans out to an ~8 px vertical cutting edge (rows 2-9), small back poll.
    s = Icon()
    s.g = [list(r) for r in AXE_ROWS.strip().split('\n')]
    assert len(s.g) == N and all(len(r) == N for r in s.g)
    _set(s, 'O', ((13, 1), (14, 1), (11, 2)))
    _set(s, '2', ((10, 3),))
    return s


def shovel():
    # Minecraft shovel: ~4 px wide, ~6 long blade ALONG the handle, square shoulders at the collar, rounded tip, light only
    # on the top-left edge, dark dish down the centre line.
    s = Icon()
    def blade(a, b):
        if not 2.0 <= a <= 8.0:
            return False
        return abs(b) <= 2.0 - max(0, a - 6.8) * 1.3
    cells = {(x, y) for y in range(N) for x in range(N) if blade(*ab(x, y))}
    for (x, y) in cells:
        inn = lambda dx, dy: (x + dx, y + dy) in cells
        s.g[y][x] = '2' if (not inn(1, 0) or not inn(0, 1)) else '4' if (not inn(-1, 0) or not inn(0, -1)) else '3'
    for (x, y) in cells:
        a, b = ab(x, y)
        if a < 3.0:
            s.g[y][x] = '1'                                         # collar
    for (x, y) in ((11, 4), (12, 3), (13, 2)):
        if (x, y) in cells:
            s.g[y][x] = '2'                                         # dish
    _core(s, 6, cells)
    s.g[15][0] = '.'                                                # one handle px less
    _fo(s)
    _set(s, '3', ((14, 3), (14, 4), (13, 5), (12, 6)))              # widen to 4 px across
    _set(s, 'O', ((15, 3), (15, 4), (14, 5), (13, 6), (12, 7), (10, 7)))
    _set(s, '.', ((10, 8),))
    _set(s, '2', ((13, 3), (13, 4)))
    return s


def sword():
    # Terraria shortsword: pointed blade ~70% of icon on x+y=15; light left / dark fuller centre / mid right; 6 px brass guard;
    # grip; pommel. Whole sword inside the canvas so tip and pommel get outlines.
    s = Icon()
    s.fill(lambda a, b: -9.4 <= a < -8.0 and abs(b) <= 1.2, lambda a, b: 'r' if b < 0 else 'p')     # pommel
    s.fill(lambda a, b: -8.0 <= a < -5.8 and abs(b) <= .8, lambda a, b: 'L' if b < .1 else 'l')     # grip
    s.fill(lambda a, b: -5.8 <= a < -4.2 and abs(b) <= 3.1, lambda a, b: 'r' if b < -1 else 'q')    # guard, both arms brass
    cells = s.metal(lambda a, b: -4.2 <= a <= 9.4 and abs(b) <= min(1.1, (9.6 - a) * .8))
    for (x, y) in cells:
        a, b = ab(x, y)
        s.g[y][x] = '4' if (b < -.35 or a > 8.0) else ('2' if b < .35 else '3')
    s.fill(lambda a, b: -5.5 <= a <= -4.5 and abs(b) <= .5, 'G')                                    # gem
    _fo(s)
    _set(s, 'O', ((14, 1), (3, 9), (2, 10), (6, 12), (5, 13)))
    _set(s, '.', ((14, 0),))
    return s


ICONS = {'sword': sword, 'pickaxe': pickaxe, 'axe': axe, 'shovel': shovel}


def render(rows, tier):
    pal = dict(PAL)
    for i, c in enumerate(WOOD_ICON if tier == 'wood' else TIERS[tier]): pal[str(i + 1)] = c
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != '.': im.putpixel((x, y), pal[ch] + (255,))
    return im


if __name__ == '__main__':
    import draw_tools as T
    out = sys.argv[1]; k = 8
    names = list(ICONS); tiers = ['iron', 'copper', 'wood', 'stone']
    S = Image.new('RGBA', (len(names) * (16 * k * 2 + 40) + 20, len(tiers) * (30 * k + 20)), (90, 110, 90, 255))
    for ty, t in enumerate(tiers):
        for ix, n in enumerate(names):
            rows = ICONS[n]().outline()
            ic = render(rows, t); ic.save(f'{out}/{t}_{n}.png')
            hd = T.render(T.ITEMS[n], t)
            x = 10 + ix * (16 * k * 2 + 40); y = ty * (30 * k + 20) + 10
            hd = hd.crop(hd.getbbox())
            S.alpha_composite(hd.resize((hd.width * k // 2, hd.height * k // 2), Image.NEAREST), (x, y))
            S.alpha_composite(ic.resize((16 * k, 16 * k), Image.NEAREST), (x + 16 * k // 2 + 30, y + 6 * k))
    S.save(f'{out}/pair.png')
