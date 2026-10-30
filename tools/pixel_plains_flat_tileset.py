"""Labels the strips of tools/pixel_plains_flat_tileset.gd into one sheet (4x): one row per ground pair, 16 corner masks.
Transparent pixels (water is drawn by the water layer in game) are shown in the game's water_fill colour.
Run: python3 tools/pixel_plains_flat_tileset.py docs/wiki/shots/all-flat/tileset"""
import os, sys
from PIL import Image, ImageDraw
D = sys.argv[1]; Z = 4; T = 16; WATER = (112, 210, 228, 255); LAB = 170
files = sorted(f for f in os.listdir(D) if f.startswith("pair_"))
sheet = Image.new("RGB", (LAB + 16 * (T * Z + 6), 24 + len(files) * (T * Z + 10)), (32, 32, 38))
d = ImageDraw.Draw(sheet)
for m in range(16):
    d.text((LAB + m * (T * Z + 6) + 4, 6), "%d %s" % (m, "".join("#" if m & b else "." for b in (1, 2, 4, 8))), fill=(200, 200, 200))
for r, f in enumerate(files):
    a, b = f[5:-4].split("_")
    y = 24 + r * (T * Z + 10)
    d.text((6, y + T * Z // 2 - 6), "%s (#) on %s" % (a, b), fill=(240, 240, 240))
    strip = Image.open(os.path.join(D, f)).convert("RGBA")
    bg = Image.new("RGBA", strip.size, WATER); bg.alpha_composite(strip)
    for m in range(16):
        t = bg.crop((m * T, 0, m * T + T, T)).resize((T * Z, T * Z), Image.NEAREST)
        sheet.paste(t, (LAB + m * (T * Z + 6), y))
sheet.save(os.path.join(D, "..", "tileset.png"))
