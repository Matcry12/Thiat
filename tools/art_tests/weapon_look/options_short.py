"""$0 preview: short sword beside the body, pixels the body's size, with and without a hand. Output: options_short.png. Run from the project root."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
OUT = Path(__file__).parent
BODY = Image.open("assets/game/characters/pixel_plains/idle.png").convert("RGBA").crop((0, 0, 12, 17))
SWORD1 = Image.open("/home/matcry/Developer/BossFight/docs/assets/PNA-art/Sword1.png").convert("RGBA")
PAL = {"a": "#392a4e", "d": "#d2ccd6", "e": "#fefdff", "c": "#150734", "h": "#524179", "x": "#fff372", "i": "#53450c", "k": "#0e0021"}
SHORT = [".......aaa", "......aeea", ".....aedea", "....aedea.", ".c.aedea..", "..hxdea...", "..cixa....", ".ii.ch....", ".i...c....", "k........."]
HAND = [".kk.", "keek", "keek", ".kk."]
N = 48
ANGLES = [(0, "right"), (20, "right, a bit up"), (45, "up-right"), (90, "up"), (-90, "down"), (135, "up-left"), (180, "left")]

def grid(rows, pal=PAL):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                im.paste(pal[ch], (x, y, x + 1, y + 1))
    return im

def pad(im, grip, size=N):
    c = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    c.paste(im, (size // 2 - grip[0], size // 2 - grip[1]))
    return c

def scale2x(im):
    w, h = im.size
    p = im.load()
    out = Image.new("RGBA", (w * 2, h * 2))
    o = out.load()
    for y in range(h):
        for x in range(w):
            b, d, e, f, g = p[x, max(y - 1, 0)], p[max(x - 1, 0), y], p[x, y], p[min(x + 1, w - 1), y], p[x, min(y + 1, h - 1)]
            e0, e1, e2, e3 = e, e, e, e
            if b != g and d != f:
                e0 = d if d == b else e
                e1 = f if b == f else e
                e2 = d if d == g else e
                e3 = f if g == f else e
            o[2 * x, 2 * y], o[2 * x + 1, 2 * y], o[2 * x, 2 * y + 1], o[2 * x + 1, 2 * y + 1] = e0, e1, e2, e3
    return out

SW = pad(grid(SHORT), (2, 7))
def short(a):
    big = scale2x(scale2x(scale2x(SW))).rotate(a - 45, Image.NEAREST)
    return big.resize((N, N), Image.NEAREST, box=(0, 0, N * 8, N * 8))
FIST = grid(HAND, {"k": "#1c2233", "e": "#ffffff"}).resize((12, 12), Image.NEAREST)

CELL, ZOOM, LABEL = 120, 2, 300
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
ROWS = [("TODAY", "long sword, across the belly", "today"), ("1  Short, no hand", "sword beside the body", "short"), ("2  Short, small hand", "sword held in a fist", "hand")]
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, (_, name) in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 50, 10), name, font=small, fill="#dddddd")
for r, (title, sub, kind) in enumerate(ROWS):
    y0 = 44 + r * CELL * ZOOM
    dr.text((12, y0 + 90), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 122), sub, font=small, fill="#bbbbbb")
    for c, (a, _) in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((40, 90, 80, 104), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (42, 45))
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        if kind == "today":
            art = pad(SWORD1, (10, 21), 64).resize((128, 128), Image.NEAREST).rotate(a - 45, Image.NEAREST)
            layer.paste(art, (69 - 64, 81 - 64))
        else:
            left = abs(a) > 90
            art = short(180 - a if left else a)
            if left:
                art = ImageOps.mirror(art)
            art = art.resize((N * 3, N * 3), Image.NEAREST)
            gap = 3 if a == -90 else 0                 # pointing down: blade clears the body
            gx, gy = (42 - gap if left else 78 + gap), 78   # touching the body's side, on its 3 px grid
            layer.paste(art, (gx - N * 3 // 2, gy - N * 3 // 2))
            if kind == "hand":
                layer.alpha_composite(FIST, (gx - 6, gy - 6))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "options_short.png")
