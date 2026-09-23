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
    box(56, 10, (230, 230, 235, 255), name="sword")
    box(40, 8, (180, 140, 80, 255), name="bow")
    ellipse(40, 16, (0, 0, 0, 90), name="shadow")
    ellipse(12, 12, (120, 220, 255, 255), name="projectile")
    print(f"wrote {len(list(OUT.glob('*.png')))} files to {OUT}")
