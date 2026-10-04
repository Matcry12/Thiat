"""Clean a hand-drawn JPG sprite: quantize to a palette, drop the background, add a 1 px outline.
Usage: python3 tools/clean_sprite.py in.jpg out.png [--colors 9] [--thresh 40] [--preview cmp.png]
Assumes the drawing is already 1 art px = 1 image px (check by eye at 16x first).
Background = pixels darker than --thresh (max channel); the original outline is too close to black to
separate, so the outline is REBUILT as 1 px around the silhouette, in the darkest foreground colour."""
import sys, argparse
from PIL import Image
import numpy as np
from scipy import ndimage

ap = argparse.ArgumentParser()
ap.add_argument("src"); ap.add_argument("dst")
ap.add_argument("--palette", default="", help="comma hex list; default = built-in template palette")
ap.add_argument("--thresh", type=int, default=30)
ap.add_argument("--outline", default="3a1020", help="hex outline colour")
ap.add_argument("--preview")
a = ap.parse_args()

src = Image.open(a.src).convert("RGB")
px = np.asarray(src).astype(int)
fg = px.max(axis=2) > a.thresh
fg = ndimage.binary_opening(fg, iterations=0) if False else fg
# keep only the biggest blob (kills JPG speckle), fill holes
lab, n = ndimage.label(fg, structure=np.ones((3, 3)))
if n:
    sizes = ndimage.sum(fg, lab, range(1, n + 1))
    fg = lab == (1 + int(np.argmax(sizes)))
fg = ndimage.binary_fill_holes(fg)
# snap every foreground pixel to the nearest palette colour (removes JPG noise)
PAL = ["e8958f", "d89b96", "c96b6c", "b57375", "db98a1", "a44543", "2a0a10",
       "42507d", "2c3651", "3a2c4d", "bd9da8", "907f8f"]
if a.palette:
    PAL = a.palette.split(",")
pal = np.array([[int(h[i:i+2], 16) for i in (0, 2, 4)] for h in PAL])
d = ((px[:, :, None, :] - pal[None, None]) ** 2).sum(-1)
q = pal[d.argmin(-1)]
out = np.zeros((*fg.shape, 4), "uint8")
out[fg, :3] = q[fg]; out[fg, 3] = 255
# rebuild outline
ring = ndimage.binary_dilation(fg, structure=ndimage.generate_binary_structure(2, 1)) & ~fg
oc = tuple(int(a.outline[i:i+2], 16) for i in (0, 2, 4))
out[ring] = (*oc, 255)
ys, xs = np.where(out[..., 3] > 0)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
res = Image.fromarray(out[y0:y1, x0:x1], "RGBA")
res.save(a.dst)
print("crop box", (x0, y0, x1, y1), "size", res.size, "colors", sorted({tuple(c) for c in out[fg][:, :3]}))
if a.preview:
    S = 12
    b = src.resize((src.width * S, src.height * S), Image.NEAREST)
    full = Image.fromarray(out, "RGBA")
    c = Image.new("RGBA", full.size, (70, 150, 70, 255)); c.alpha_composite(full)
    c = c.resize((full.width * S, full.height * S), Image.NEAREST)
    sheet = Image.new("RGB", (b.width * 2, b.height)); sheet.paste(b, (0, 0)); sheet.paste(c.convert("RGB"), (b.width, 0))
    sheet.save(a.preview)
