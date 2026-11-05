"""$0 preview: the sword turned normally (no poses), short and thick, pixels the body's size. Output: options_normal_turn.png. Run from the project root."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
sys.path.insert(0, str(Path(__file__).parent))
from options_short import BODY, SWORD1, SW, FIST, N, pad
OUT = Path(__file__).parent
ANGLES = [0, 20, 35, 60, 90, 135, 180]
SS = 8

def sharp(a):       # every screen pixel picks the nearest colour
    return SW.resize((N * 3, N * 3), Image.NEAREST).rotate(a - 45, Image.NEAREST)
def soft(a):        # same, edges softened by one screen pixel
    return SW.resize((N * 3 * SS, N * 3 * SS), Image.NEAREST).rotate(a - 45, Image.NEAREST).resize((N * 3, N * 3), Image.BOX)

ROWS = [("TODAY", "long, thin, bright", None), ("1  Normal turn, sharp", "short, thick, small hand", sharp), ("2  Normal turn, soft edges", "short, thick, small hand", soft)]
CELL, ZOOM, LABEL = 90, 3, 310
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, a in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 90, 10), "aim %d°" % a, font=small, fill="#dddddd")
for r, (title, sub, fn) in enumerate(ROWS):
    y0 = 44 + r * CELL * ZOOM
    dr.text((12, y0 + 110), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 142), sub, font=small, fill="#bbbbbb")
    for c, a in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((25, 74, 65, 88), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (27, 29))
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        if fn is None:
            layer.paste(pad(SWORD1, (10, 21), 64).resize((128, 128), Image.NEAREST).rotate(a - 45, Image.NEAREST), (54 - 64, 65 - 64))
        else:
            left = abs(a) > 90
            art = fn(180 - a if left else a)
            if left:
                art = ImageOps.mirror(art)
            gx, gy = (27 if left else 63), 62
            layer.paste(art, (gx - N * 3 // 2, gy - N * 3 // 2))
            layer.alpha_composite(FIST, (gx - 6, gy - 6))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "options_normal_turn.png")
