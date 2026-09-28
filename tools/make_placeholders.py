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


def shield(scale=4, name="shield"):
    """Heater shield, built as a grid so the SHAPE is data, not a drawing.

    Original art. Pixel art must be authored at its true pixel size and then
    upscaled with NEAREST — resizing a big image down blurs it
    (.claude/memory/godot-gotchas.md). Points UP (the way it is held), and the
    node that draws it rotates it toward the mouse.
    """
    W, H = 16, 18
    K = (18, 18, 24, 255)      # outline
    D = (86, 96, 108, 255)     # dark rim
    M = (132, 144, 156, 255)   # panel, shaded side
    L = (176, 188, 200, 255)   # panel, lit side
    HI = (226, 234, 242, 255)  # centre seam / top highlight
    R = (206, 216, 228, 255)   # rivet (bright, or it vanishes into the rim)
    px = {}
    for y in range(H):
        inset = max(0, y - 9)          # straight sides, then taper to a point
        left, right = inset, W - 1 - inset
        if right - left < 1:
            break
        for x in range(left, right + 1):
            if x in (left, right) or y in (0, H - 1) or right - left < 3:
                c = K
            elif x in (left + 1, right - 1) or y == 1:
                c = R if (x in (left + 1, right - 1) and y in (3, 6, 9, 12)) else D
            elif y == 2:
                c = HI
            elif x == W // 2 - 1:
                c = HI
            else:
                c = L if x < W // 2 else M
            px[(x, y)] = c
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    load = img.load()
    for (x, y), c in px.items():
        load[x, y] = c
    img = img.resize((W * scale, H * scale), Image.NEAREST)
    img.save(OUT / f"{name}.png")
    return img


def crack_overlay(scale=4, name="cracks"):
    """A DAMAGE PATTERN, not a damaged shield.

    Drawn on the SAME 16x18 grid as shield(), fully transparent except the
    cracks, so it can be laid on top of ANY shield sprite. A new shield never
    needs its own cracked version — this one layer covers every shield we will
    ever add. Alpha rises as the shield bar drops.
    """
    W, H = 16, 18
    K = (12, 12, 16, 255)      # crack
    E = (232, 238, 246, 255)   # bright edge, so a crack reads on dark metal too
    # Hand-placed so the cracks branch from the top rim downward, the way a
    # struck shield actually fails. (x, y) pairs.
    # Three thin branching cracks, 1px wide. Sparse on purpose: a dense
    # scribble reads as noise, not damage.
    crack = [
        (7, 2), (7, 3), (6, 4), (6, 5), (5, 6), (5, 7), (4, 8), (4, 9), (4, 10),
        (7, 5), (8, 6), (9, 6), (10, 7),
        (12, 3), (11, 4), (11, 5), (10, 6),
        (8, 10), (8, 11), (7, 12), (7, 13),
    ]
    # No bright edge: at 16px a highlight beside the crack doubles its width and
    # the whole thing turns to mush. One dark pixel reads as a crack.
    edge = []
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    for (x, y) in edge:
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = E
    for (x, y) in crack:
        if 0 <= x < W and 0 <= y < H:
            px[x, y] = K
    img = img.resize((W * scale, H * scale), Image.NEAREST)
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
    shield(name="shield")
    crack_overlay(name="shield_cracks")
    print(f"wrote {len(list(OUT.glob('*.png')))} files to {OUT}")
