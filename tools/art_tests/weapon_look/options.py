"""$0 preview: how the held sword can match the body. Output: options.png next to this file. Run from the project root."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
OUT = Path(__file__).parent
BODY = Image.open("assets/characters/pixel_plains/idle.png").convert("RGBA").crop((0, 0, 12, 17))
SWORD1 = Image.open("/home/matcry/Developer/BossFight/docs/assets/PNA-art/Sword1.png").convert("RGBA")
PAL = {"a": "#392a4e", "d": "#e5e0e8", "e": "#fefdff", "c": "#150734", "h": "#524179", "x": "#fff372",
       "i": "#53450c", "j": "#272003", "k": "#0e0021"}
DIAG = ["..........aa.", ".........adea", "........adea.", ".......adea..", "......adea...", ".c...adea....",
        "..hhcdea.....", "...chxa......", "....cihc.....", "...ji.chc....", "..ji....c....", ".ji..........", "kk..........."]
STRAIGHT = ["....hc.........", "....hc.........", "...chaaaaaaaaa.", "kjiixeeeeeeeeea", "...chaaaaaaaaa.", "....hc.........", "....hc........."]
N = 64
ANGLES = [(0, "aim right"), (20, "right, a bit up"), (45, "up-right"), (-90, "down"), (90, "up"), (135, "up-left"), (180, "left")]

def grid(rows):
    im = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch != ".":
                im.putpixel((x, y), Image.new("RGBA", (1, 1), PAL[ch]).getpixel((0, 0)))
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

def smart_rotate(art, deg):
    big = scale2x(scale2x(scale2x(art))).rotate(deg, Image.NEAREST)
    return big.resize((N, N), Image.NEAREST, box=(0, 0, N * 8, N * 8))

D = pad(grid(DIAG), (3, 9))
S = pad(grid(STRAIGHT), (2, 3))
SW1 = pad(SWORD1, (10, 21))

def today(a):       # one fine picture, turned on the fine grid (what the game does)
    return SW1.resize((N * 2, N * 2), Image.NEAREST).rotate(a - 45, Image.NEAREST), 1
def big(a):         # same picture, just drawn at the body's pixel size
    return SW1.rotate(a - 45, Image.NEAREST), 3
def simple(a):      # small picture, turned in big pixels
    return D.rotate(a - 45, Image.NEAREST), 3
def smart(a):       # small picture, turned with a cleaner method
    return smart_rotate(D, a - 45), 3
def poses(a):       # two drawn pictures, nearest of 8 directions by mirror / quarter turn
    k = round(a / 45) % 8
    return [S, D, S.rotate(90), ImageOps.mirror(D), ImageOps.mirror(S), ImageOps.flip(ImageOps.mirror(D)), S.rotate(-90), ImageOps.flip(D)][k], 3

ROWS = [("TODAY", "fine pixels, rough edges", today),
        ("Bigger pixels only", "same picture: far too big", big),
        ("A  Small sword, simple turn", "1 picture, any angle", simple),
        ("B  Small sword, clean turn", "1 picture, any angle", smart),
        ("C  Small sword, 8 poses", "2 pictures, 8 fixed angles", poses)]
CELL, ZOOM, LABEL = 120, 2, 300
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, (_, name) in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 40, 10), name, font=small, fill="#dddddd")
for r, (title, sub, fn) in enumerate(ROWS):
    y0 = 44 + r * CELL * ZOOM
    dr.text((12, y0 + 110), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 142), sub, font=small, fill="#bbbbbb")
    for c, (a, _) in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((60 - 20, 90, 60 + 20, 104), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (42, 45))
        left = r >= 2 and abs(a) > 90                      # options: aiming left = the right-hand picture mirrored, in the other hand
        art, s = fn(180 - a if left else a)
        if left:
            art = ImageOps.mirror(art)
        art = art.resize((art.width * s, art.height * s), Image.NEAREST)
        gx, gy = (51 if left else 69), 81                                    # the hand spot, on the body's 3 px grid
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        layer.paste(art, (gx - art.width // 2, gy - art.height // 2))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "options.png")
