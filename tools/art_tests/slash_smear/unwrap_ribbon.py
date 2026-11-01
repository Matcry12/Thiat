# Unwraps slash_f1..f4.png (crescent, centre (24,24), clockwise) into straight strips ribbon_f1..f4.png.
# u (x) = along the arc, NEWEST end at x=0; v (y) = inner -> outer radius. Nearest sampling keeps the pixel look.
# Run from this folder; also writes to ../../../assets/fx/slash/. Used by scripts/visual/swing_ribbon.gd.
import math, os
from PIL import Image
HEAD = [-23.2, 60.3, 60.3, 70.3]   # newest-end angle per frame (= SwingMotion.slash_head_fN_deg)
R0, R1, H, PPD = 10.5, 22.0, 12, 0.5   # radii kept (art px, 22 = blade tip), rows, strip px per degree
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../../assets/fx/slash")
for i in range(4):
    im = Image.open(f"slash_f{i+1}.png").convert("RGBA"); px = im.load()
    rel = []
    for y in range(48):
        for x in range(48):
            if px[x, y][3]:
                a = math.degrees(math.atan2(y + .5 - 24, x + .5 - 24))
                d = (HEAD[i] - a + 30) % 360 - 30
                if d <= 200: rel.append(d)
    span = max(rel)
    r0, r1 = R0, R1
    if i == 0:   # f1 is thin: stretch its own radial extent over all rows so its height matches f2
        rs = [math.hypot(x + .5 - 24, y + .5 - 24) for y in range(48) for x in range(48) if px[x, y][3]]
        r0, r1 = min(rs), max(rs)
    W = math.ceil(span * PPD)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for u in range(W):
        a = math.radians(HEAD[i] - (u + .5) / W * span)
        for v in range(H):
            r = r0 + (v + .5) / H * (r1 - r0)
            x, y = int(24 + r * math.cos(a)), int(24 + r * math.sin(a))
            out.putpixel((u, v), px[x, y])
    out.save(f"ribbon_f{i+1}.png"); out.save(os.path.join(OUT, f"ribbon_f{i+1}.png"))
    print(i + 1, W, H, span)
