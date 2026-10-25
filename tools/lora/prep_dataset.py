"""Tiny RPG strips -> kohya dataset (512x512 RGB + caption). Output goes OUTSIDE the repo: art must not be redistributed."""
import argparse, os, re, sys, tempfile
from pathlib import Path
from PIL import Image

def frames(strip):
    """Non-empty 100x100 frames of a strip."""
    for i in range(strip.width // 100):
        f = strip.crop((i * 100, 0, i * 100 + 100, 100))
        if f.getchannel("A").getbbox():
            yield f

# The sprite is only ~40x30 px of its 100x100 frame. A fixed 64x64 window (same for every frame, so the
# pixel size and the feet line stay the same) x8 = 512 lets the sprite fill the image. clean_gen undoes it.
WIN_X, WIN_Y, WIN = 24, 18, 64

def fits(frame):
    b = frame.getchannel("A").getbbox()
    return b[0] >= WIN_X and b[1] >= WIN_Y and b[2] <= WIN_X + WIN and b[3] <= WIN_Y + WIN

def to_512(frame, bg):
    canvas = Image.new("RGBA", (WIN, WIN), bg + (255,))
    canvas.alpha_composite(frame.convert("RGBA").crop((WIN_X, WIN_Y, WIN_X + WIN, WIN_Y + WIN)))
    return canvas.convert("RGB").resize((512, 512), Image.NEAREST)

def caption(trigger, char, anim, bg):
    anim = re.sub(r"\d+$", "", anim).lower()
    bgname = "white background" if bg == (255, 255, 255) else "plain background"
    return f"{trigger}, pixel art, {char.lower().replace("_", " ")}, {anim}, side view, full body, {bgname}"

def main():
    a = argparse.ArgumentParser()
    a.add_argument("roots", nargs="*", help="pack roots")
    a.add_argument("--out", default="~/lora/tinyrpg_dataset")
    a.add_argument("--chars", type=int)
    a.add_argument("--bg", default="ff00ff")  # key colour the pack never uses; white ate highlights
    a.add_argument("--trigger", default="tnyrpg")
    a.add_argument("--repeats", type=int, default=10)
    a.add_argument("--selftest", action="store_true")
    a = a.parse_args()
    if a.selftest:
        return selftest()
    bg = tuple(int(a.bg[i:i + 2], 16) for i in (0, 2, 4))
    out = Path(a.out).expanduser() / "img" / f"{a.repeats}_{a.trigger}"
    out.mkdir(parents=True, exist_ok=True)
    for root in a.roots:
        base = Path(root) / "Characters(100x100 split)"
        chars = sorted(d for d in base.iterdir() if (d / d.name).is_dir())
        for cd in chars[: a.chars]:
            n = 0
            for p in sorted((cd / cd.name).glob(f"{cd.name}_*.png")):  # skips Char.png and "with shadows"
                anim = p.stem[len(cd.name) + 1:]
                for i, f in enumerate(frames(Image.open(p))):
                    if not fits(f):
                        print(f"  SKIPPED, does not fit the 64x64 window: {p.name} frame {i}")
                        continue  # ponytail: skip, not train on cut bodies; move WIN_X/WIN_Y/WIN if a pack has bigger characters
                    stem = f"{cd.name}_{anim}_{i:02d}".replace(" ", "_")
                    to_512(f, bg).save(out / f"{stem}.png")
                    (out / f"{stem}.txt").write_text(caption(a.trigger, cd.name, anim, bg) + "\n")
                    n += 1
            print(f"{cd.name}: {n} images")
    print("total:", len(list(out.glob("*.png"))), "->", out)

def selftest():
    strip = Image.new("RGBA", (300, 100), (0, 0, 0, 0))
    strip.putpixel((30, 40), (255, 0, 0, 255))      # frame 0
    strip.putpixel((205, 5), (0, 255, 0, 255))      # frame 2, outside the window; frame 1 stays empty
    fs = list(frames(strip))
    assert len(fs) == 2, len(fs)
    im = to_512(fs[0], (255, 255, 255))
    assert im.size == (512, 512) and im.mode == "RGB"
    x, y = (30 - WIN_X) * 8, (40 - WIN_Y) * 8
    assert all(im.getpixel((x + dx, y + dy)) == (255, 0, 0) for dx in range(8) for dy in range(8))
    assert im.getpixel((x + 8, y)) == (255, 255, 255)
    assert fits(fs[0]) and not fits(fs[1])
    assert caption("t", "Armored Orc", "Attack01", (255, 255, 255)).endswith("armored orc, attack, side view, full body, white background")
    print("prep_dataset selftest ok")

if __name__ == "__main__":
    main()
