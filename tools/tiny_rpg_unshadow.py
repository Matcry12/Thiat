#!/usr/bin/env python3
"""Derives assets/characters/tiny_rpg/Soldier_*.png from the untouched pack copy in assets/third_party/tiny_rpg/.
The pack's "no shadow" Soldier folder still has a baked ground shadow (colour 83,69,69 under the feet, rows >= 55).
Our game draws its own Shadow node, so that exact colour is made transparent. Nothing else is touched.
Run: python3 -I tools/tiny_rpg_unshadow.py"""
from PIL import Image
SHADOW = (83, 69, 69, 255)
for name in ("Idle", "Walk", "Hurt", "Death"):
    im = Image.open(f"assets/third_party/tiny_rpg/Soldier/Soldier_{name}.png").convert("RGBA")
    for y in range(55, im.height):
        for x in range(im.width):
            if im.getpixel((x, y)) == SHADOW:
                im.putpixel((x, y), (0, 0, 0, 0))
    im.save(f"assets/characters/tiny_rpg/Soldier_{name}.png")
