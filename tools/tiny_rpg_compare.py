#!/usr/bin/env python3
"""Tiles the scale_A..D.png frames from tools/tiny_rpg_shots.gd into docs/demo/tiny_rpg_scale_compare.png
(same crop around soldier + orc + tree, shown 2x with nearest-neighbour so it is readable).
Run: python3 -I tools/tiny_rpg_compare.py <shots_dir>"""
import sys
from PIL import Image, ImageDraw
d = sys.argv[1]
labels = {"A": "A: Soldier 2 / Orc 4 (now)", "B": "B: both 3", "C": "C: Soldier 2 / Orc 2 (Orc smaller than its hurtbox)", "D": "D: both 4"}
box = (520, 140, 900, 400)
w, h = (box[2] - box[0]) * 2, (box[3] - box[1]) * 2
out = Image.new("RGB", (w * 2, (h + 24) * 2), (20, 20, 20))
for i, k in enumerate("ABCD"):
    im = Image.open(f"{d}/scale_{k}.png").convert("RGB").crop(box).resize((w, h), Image.NEAREST)
    x, y = (i % 2) * w, (i // 2) * (h + 24)
    out.paste(im, (x, y + 24))
    ImageDraw.Draw(out).text((x + 8, y + 6), labels[k], fill=(255, 255, 255))
out.save("docs/demo/tiny_rpg_scale_compare.png")
