"""$0 preview: the sword turns, its drawing stays the same. Output: options_same_drawing.png. Run from the project root."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageOps
OUT = Path(__file__).parent
BODY = Image.open("assets/game/characters/pixel_plains/idle.png").convert("RGBA").crop((0, 0, 12, 17))
SWORD1 = Image.open("/home/matcry/Developer/BossFight/docs/assets/PNA-art/Sword1.png").convert("RGBA")
N, SS = 64, 8
ANGLES = [0, 15, 30, 45, 60, 90, 135]

def art():
    c = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    c.paste(SWORD1, (N // 2 - 10, N // 2 - 21))
    return c
A = art()

def today(a):       # what the game does: every screen pixel picks the nearest colour, so the drawing breaks
    return A.resize((N * 2, N * 2), Image.NEAREST).rotate(a - 45, Image.NEAREST)
def sticker(a):     # solid sticker: turned at high detail, edges softened to screen size
    big = A.resize((N * 2 * SS, N * 2 * SS), Image.NEAREST).rotate(a - 45, Image.NEAREST)
    return big.resize((N * 2, N * 2), Image.BOX)
def poses4(a):      # only mirrors of the one drawing: the 4 diagonals, not one pixel changes
    k = round((a - 45) / 90) % 4
    im = [A, ImageOps.mirror(A), ImageOps.flip(ImageOps.mirror(A)), ImageOps.flip(A)][k]
    return im.resize((N * 2, N * 2), Image.NEAREST)

ROWS = [("TODAY", "drawing changes at each angle", today),
        ("1  Solid sticker", "follows aim, soft edges (see close-up)", sticker),
        ("2  4 poses", "exact pixels, jumps to nearest diagonal", poses4)]
CELL, ZOOM, LABEL = 120, 2, 390
font = ImageFont.load_default(size=22)
small = ImageFont.load_default(size=18)
sheet = Image.new("RGBA", (LABEL + CELL * ZOOM * len(ANGLES), 44 + CELL * ZOOM * len(ROWS)), "#22262b")
dr = ImageDraw.Draw(sheet)
for i, a in enumerate(ANGLES):
    dr.text((LABEL + i * CELL * ZOOM + 90, 10), "aim %d°" % a, font=small, fill="#dddddd")
for r, (title, sub, fn) in enumerate(ROWS):
    y0 = 44 + r * CELL * ZOOM
    dr.text((12, y0 + 90), title, font=font, fill="#ffffff")
    dr.text((12, y0 + 122), sub, font=small, fill="#bbbbbb")
    for c, a in enumerate(ANGLES):
        cell = Image.new("RGBA", (CELL, CELL), "#3e8052")
        ImageDraw.Draw(cell).ellipse((40, 90, 80, 104), fill="#1f4a30")
        cell.alpha_composite(BODY.resize((36, 51), Image.NEAREST), (42, 45))
        im = fn(a)
        layer = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
        layer.paste(im, (69 - N, 81 - N))
        cell.alpha_composite(layer)
        sheet.paste(cell.resize((CELL * ZOOM, CELL * ZOOM), Image.NEAREST), (LABEL + c * CELL * ZOOM, y0))
sheet.convert("RGB").save(OUT / "options_same_drawing.png")

# Close-up: the same sword at aim 30°. Differences are hard to see at game size.
Z, W = 5, 3
crops = [("TODAY at aim 30°", today(30)), ("1 Solid sticker at aim 30°", sticker(30)), ("2 4 poses (your exact drawing)", poses4(30))]
close = Image.new("RGB", (W * 64 * Z, 64 * Z + 40), "#3e8052")
d = ImageDraw.Draw(close)
for i, (name, im) in enumerate(crops):
    box = (N - 8, N - 52, N + 56, N + 12)
    close.paste(im.crop(box).resize((64 * Z, 64 * Z), Image.NEAREST), (i * 64 * Z, 40), im.crop(box).resize((64 * Z, 64 * Z), Image.NEAREST))
    d.text((i * 64 * Z + 12, 8), name, font=small, fill="#ffffff")
close.save(OUT / "closeup.png")
