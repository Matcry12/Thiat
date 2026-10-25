"""Generated 512x512 sprite PNG -> clean 100x100 RGBA (grid-snap, transparent bg, limited palette).
Inverse of prep_dataset.to_512: 8x8 cells -> 64x64 window, placed back at the same spot in a 100x100 frame."""
import argparse
from collections import Counter
from pathlib import Path
from PIL import Image
WIN_X, WIN_Y, WIN = 24, 18, 64  # must match prep_dataset.py (not imported: python3 -I drops the script dir from sys.path)

def clean(im, bg=(255, 0, 255), tol=24, colors=24):
    im = im.convert("RGB").resize((512, 512), Image.NEAREST) if im.size != (512, 512) else im.convert("RGB")
    k = 512 // WIN
    small = Image.new("RGB", (WIN, WIN))
    for cy in range(WIN):
        for cx in range(WIN):
            cell = im.crop((cx * k, cy * k, cx * k + k, cy * k + k)).getdata()
            small.putpixel((cx, cy), Counter(cell).most_common(1)[0][0])  # mode colour
    alpha = Image.new("L", small.size)
    alpha.putdata([0 if max(abs(p[i] - bg[i]) for i in range(3)) <= tol else 255 for p in small.getdata()])
    q = small.quantize(colors, dither=Image.Dither.NONE).convert("RGB")  # ponytail: bg counts as one colour
    q.putalpha(alpha)
    frame = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    frame.paste(q, (WIN_X, WIN_Y))
    return frame

def main():
    a = argparse.ArgumentParser()
    a.add_argument("src", nargs="?", help="PNG file or folder")
    a.add_argument("out", nargs="?")
    a.add_argument("--bg", default="ff00ff")  # key colour the pack never uses; white ate highlights
    a.add_argument("--tol", type=int, default=24)
    a.add_argument("--colors", type=int, default=24)
    a.add_argument("--preview", action="store_true", help="also write <name>_preview.png (x4 side by side)")
    a.add_argument("--selftest", action="store_true")
    a = a.parse_args()
    if a.selftest:
        return selftest()
    bg = tuple(int(a.bg[i:i + 2], 16) for i in (0, 2, 4))
    src = Path(a.src)
    files = sorted(src.glob("*.png")) if src.is_dir() else [src]
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    for p in files:
        src_im = Image.open(p)
        r = clean(src_im, bg, a.tol, a.colors)
        r.save(out / p.name)
        if a.preview:
            big = r.resize((400, 400), Image.NEAREST)
            sheet = Image.new("RGBA", (800, 400), bg + (255,))
            sheet.paste(src_im.convert("RGB").resize((400, 400), Image.NEAREST), (0, 0))
            sheet.alpha_composite(big, (400, 0))
            sheet.save(out / f"{p.stem}_preview.png")
        print(p.name, "ok")

def selftest():
    im = Image.new("RGB", (512, 512), (255, 0, 255))
    for dx in range(8):
        for dy in range(8):
            im.putpixel((5 * 8 + dx, 7 * 8 + dy), (200, 30, 30))
    im.putpixel((5 * 8, 7 * 8), (0, 0, 0))  # noise inside a cell: mode must win
    r = clean(im)
    assert r.size == (100, 100) and r.mode == "RGBA"
    assert r.getpixel((WIN_X + 5, WIN_Y + 7)) == (200, 30, 30, 255)
    assert r.getpixel((WIN_X + 6, WIN_Y + 7))[3] == 0
    assert r.getpixel((5, 5))[3] == 0  # outside the window stays empty
    print("clean_gen selftest ok")

if __name__ == "__main__":
    main()
