"""$0 preview: the user's Sword1, not edited, only turned by different methods and scales. Output: methods.png. Run from the project root."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
sys.path.insert(0, str(Path(__file__).parent))
from options_short import BODY, SWORD1, pad, scale2x
OUT = Path(__file__).parent
N = 64
A = pad(SWORD1, (10, 21), N)
BIG = scale2x(scale2x(scale2x(A)))
ANGLES = [0, 20, 35, 60, 90, 135, 180]

def today(a):
    return A.resize((N * 2, N * 2), Image.NEAREST).rotate(a - 45, Image.NEAREST)
def clean(a, s=2.0):     # smart enlarge, turn, back to size: colours stay yours
    w = int(N * s)
    return BIG.rotate(a - 45, Image.NEAREST).resize((w, w), Image.NEAREST)
def soft(a, s=2.0):      # turned as a solid picture, edges softened by one screen pixel
    w = int(N * s)
    return A.resize((w * 8, w * 8), Image.NEAREST).rotate(a - 45, Image.NEAREST).resize((w, w), Image.BOX)

ROWS = [("TODAY", "normal game, size x1", today),
        ("1  Clean turn", "same size", clean),
        ("2  Soft edges", "same size", soft),
        ("3  Clean turn, bigger", "size x1.25", lambda a: clean(a, 2.5)),
        ("4  Clean turn, biggest", "size x1.5", lambda a: clean(a, 3.0))]
CELL, ZOOM, LABEL = 160, 2, 310
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, a in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 130, 10), "aim %d°" % a, font=small, fill="#dddddd")
for r, (title, sub, fn) in enumerate(ROWS):
    y0 = 44 + r * CELL * ZOOM
    dr.text((12, y0 + 140), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 172), sub, font=small, fill="#bbbbbb")
    for c, a in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((55, 112, 95, 126), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (57, 67))
        im = fn(a)
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        layer.paste(im, (84 - im.width // 2, 103 - im.height // 2))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "methods.png")
