"""$0 preview: the user's Sword1 made small for the normal-turn style: hand redraw vs automatic shrink. Output: your_sword_small.png. Run from the project root."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
sys.path.insert(0, str(Path(__file__).parent))
from options_short import BODY, SWORD1, FIST, grid, pad
OUT = Path(__file__).parent
N = 48
PAL = {"a": "#392a4e", "b": "#5d5078", "c": "#150734", "d": "#e5e0e8", "e": "#fefdff", "f": "#261941", "g": "#2d204b", "h": "#524179",
       "i": "#53450c", "j": "#272003", "k": "#0e0021", "p": "#624f8b", "r": "#332453", "x": "#fff372"}
SMALL = ["........aa.", ".......adeb", "......adeb.", ".....adeb..", ".g..adeb...", ".phcdeb....", "..cfxb.....", "..crfhc....", "..ifchpg...", ".ij...cp...", "k.........."]
HAND_DRAWN = grid(SMALL, PAL)
HAND_DRAWN.save(OUT / "sword1_small.png")
AUTO = SWORD1.crop((8, 5, 27, 24)).resize((11, 11), Image.NEAREST)
ANGLES = [0, 20, 35, 60, 90, 135, 180]

def turned(art, a):
    return pad(art, (2, 8), N).resize((N * 3, N * 3), Image.NEAREST).rotate(a - 45, Image.NEAREST)

font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
CELL, ZOOM, LABEL = 90, 3, 310
ROWS = [("Redrawn by hand", "11 x 11 pixels, your colours", HAND_DRAWN), ("Automatic shrink", "same size, made by the computer", AUTO)]
TOP = 250
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), TOP + 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, (name, im) in enumerate([("Your drawing", SWORD1.crop((8, 5, 27, 24))), ("Redrawn small", HAND_DRAWN), ("Automatic shrink", AUTO)]):
    x = LABEL + i * 340
    dr.text((x, 8), name, font=small, fill="#dddddd")
    z = 200 // max(im.size)
    bg = Image.new("RGBA", (im.width * z, im.height * z), "#3e8052")
    bg.alpha_composite(im.resize((im.width * z, im.height * z), Image.NEAREST))
    sheet.paste(bg, (x, 36))
for i, a in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 90, TOP + 10), "aim %d°" % a, font=small, fill="#dddddd")
for r, (title, sub, art) in enumerate(ROWS):
    y0 = TOP + 44 + r * CELL * ZOOM
    dr.text((12, y0 + 110), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 142), sub, font=small, fill="#bbbbbb")
    for c, a in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((25, 74, 65, 88), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (27, 29))
        left = abs(a) > 90
        im = turned(art, 180 - a if left else a)
        if left:
            im = ImageOps.mirror(im)
        gx, gy = (27 if left else 63), 62
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        layer.paste(im, (gx - N * 3 // 2, gy - N * 3 // 2))
        layer.alpha_composite(FIST, (gx - 6, gy - 6))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "your_sword_small.png")
