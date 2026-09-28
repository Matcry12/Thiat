#!/usr/bin/env python3
"""Generate placeholder sprite PNGs for BossFight.

Placeholder art is deliberately plain shapes, but it is REAL IMAGE FILES so that
swapping in a real asset pack is a file replacement and never a code change
(decision 0010). Re-run this any time; it overwrites assets/placeholder/.
"""
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "assets" / "placeholder"
OUT.mkdir(parents=True, exist_ok=True)


def capsule(w, h, fill, outline=(0, 0, 0, 200), name=""):
    """An upright body: 2.5D characters stand up and face the camera (decision 0009)."""
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, w - 2, h - 2], radius=w // 2, fill=fill, outline=outline, width=2)
    # a lighter top third reads as a "head" so facing/size is legible at a glance
    d.rounded_rectangle([w // 4, 3, w - w // 4, h // 3], radius=w // 6,
                        fill=tuple(min(255, c + 60) for c in fill[:3]) + (255,))
    img.save(OUT / f"{name}.png")
    return img


def box(w, h, fill, outline=(0, 0, 0, 200), name=""):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, w - 1, h - 1], fill=fill, outline=outline, width=2)
    img.save(OUT / f"{name}.png")
    return img


def pixel_art(grid, palette, scale, name):
    """Draw from a character grid, then upscale with NEAREST so it stays crisp.

    The grid IS the art: edit the characters to change the shape. Scale only
    changes the final size, never the pixel look.
    """
    h = len(grid)
    w = max(len(r) for r in grid)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in palette:
                px[x, y] = palette[ch]
    img = img.resize((w * scale, h * scale), Image.NEAREST)
    img.save(OUT / f"{name}.png")
    return img


def ellipse(w, h, fill, name=""):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([0, 0, w - 1, h - 1], fill=fill)
    img.save(OUT / f"{name}.png")
    return img




if __name__ == "__main__":
    capsule(32, 44, (235, 235, 240, 255), name="player")
    capsule(28, 38, (210, 70, 70, 255), name="enemy")
    capsule(96, 120, (120, 30, 30, 255), name="boss")
    # Weapons point +X (right) at rotation 0, pivot at the LEFT edge = the hand.
    # Sword: points +X (right), handle at the LEFT edge = where the hand holds it.
    # Edit the grid below to change the shape; '.' is transparent.
    # Chunky pixel sword. Drawn POINTING RIGHT so the swing maths stay simple;
    # it is displayed tilted (WeaponVisual.rest_angle_degrees) for the held look.
    sword_grid = [
        ".....KKK..................",
        ".....KGK...........KKKKKK.",
        "..KKKKGKKKKKKKKKKKKKWWWWK.",
        ".KKGGGGGGGGWBWBWBWBWBWWWK.",
        "KRKGGGGGGGGWBWBWBWBWBWWK..",
        ".KKGGGGGGGGKBKBKBKBKBKKK..",
        "..KKKKGKKKKKKKKKKKKKKK....",
        ".....KGK..................",
        ".....KKK..................",
    ]
    sword_palette = {
        "K": (20, 20, 26, 255),      # outline
        "G": (120, 72, 40, 255),     # grip
        "R": (220, 40, 40, 255),     # pommel gem
        "W": (250, 252, 255, 255),   # blade highlight
        "B": (150, 200, 240, 255),   # blade, dithered with W like the reference
    }
    sword_palette["Y"] = (240, 190, 60, 255)   # gold guard
    sword_grid[1] = sword_grid[1].replace("KGK", "KYK", 1)
    sword_grid[2] = sword_grid[2][:5] + "Y" + sword_grid[2][6:]
    sword_grid[3] = sword_grid[3][:2] + "YY" + sword_grid[3][4:]
    sword_grid[4] = sword_grid[4][:3] + "Y" + sword_grid[4][4:]
    sword_grid[5] = sword_grid[5][:2] + "YY" + sword_grid[5][4:]
    sword_grid[6] = sword_grid[6][:5] + "Y" + sword_grid[6][6:]
    sword_grid[7] = sword_grid[7].replace("KGK", "KYK", 1)
    pixel_art(sword_grid, sword_palette, 3, "sword")
    box(40, 8, (180, 140, 80, 255), name="bow")
    ellipse(44, 18, (0, 0, 0, 150), name="shadow")
    ellipse(12, 12, (120, 220, 255, 255), name="projectile")
    print(f"wrote {len(list(OUT.glob('*.png')))} files to {OUT}")
