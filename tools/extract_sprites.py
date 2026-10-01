#!/usr/bin/env python3
"""Lists sprite rects of a prop sheet by alpha connected components.
usage: tools/extract_sprites.py <sheet.png> [preview.png] [scale]
Prints "x y w h" lines (sorted by y, x). The preview numbers each rect so a human can pick
which ones go into data/maps/*.tres. Dev tool only; never edits the asset."""
import sys
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

def rects(path, grow=0):
    a = np.array(Image.open(path).convert("RGBA"))[:, :, 3] > 0
    lab, n = ndimage.label((ndimage.binary_dilation(a, iterations=grow) if grow else a), structure=np.ones((3, 3)))
    out = []
    for i, sl in enumerate(ndimage.find_objects(lab)):
        m = a[sl] & (lab[sl] == i + 1)
        ys, xs = np.nonzero(m)
        x, y = sl[1].start + xs.min(), sl[0].start + ys.min()
        out.append((int(x), int(y), int(xs.max() - xs.min() + 1), int(ys.max() - ys.min() + 1)))
    return sorted(out, key=lambda r: (r[1], r[0]))

if __name__ == "__main__":
    rs = rects(sys.argv[1])
    for i, r in enumerate(rs):
        print(i, *r)
    if len(sys.argv) > 2:
        s = int(sys.argv[3]) if len(sys.argv) > 3 else 3
        im = Image.open(sys.argv[1]).convert("RGBA")
        bg = Image.new("RGBA", im.size, (90, 90, 110, 255)); bg.alpha_composite(im)
        bg = bg.resize((im.width * s, im.height * s), Image.NEAREST); d = ImageDraw.Draw(bg)
        for i, (x, y, w, h) in enumerate(rs):
            d.rectangle([x * s, y * s, (x + w) * s, (y + h) * s], outline=(255, 255, 0, 255))
            d.text((x * s + 1, y * s + 1), str(i), fill=(255, 255, 255, 255))
        bg.save(sys.argv[2])
