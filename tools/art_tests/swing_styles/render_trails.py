"""Sword-swing TRAIL ideas, 4 columns x 2 rows (active 0.10 s / 0.16 s). $0, PIL + numpy + ffmpeg.
Cols: now (8 chord samples) | A exact tip path | B drawn slash sprite (../slash_smear/slash_f1..4.png) | C A + drawn look.
Run: python3 tools/art_tests/swing_styles/render_trails.py -> trails_demo.mp4, trails_demo_slow.mp4, trails_demo_frames.png"""
import math, os, subprocess, tempfile, shutil
import numpy as np
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
# reuse sprite + helpers from render_swings.py (exec only its top half)
g = {"__file__": f"{HERE}/render_swings.py"}; exec(open(f"{HERE}/render_swings.py").read().split("CW, CH, TOP, LEFT")[0], g)
paste_tool, eo, eio = g["paste_tool"], g["eo"], g["eio"]
def lerp(a, b, k): return a + (b - a) * k
def bez(p0, p1, p2, k): return (lerp(lerp(p0[0], p1[0], k), lerp(p1[0], p2[0], k), k), lerp(lerp(p0[1], p1[1], k), lerp(p1[1], p2[1], k), k))
Z, CWW, CHH, OX, OY, BL, FPS = 3, 140, 144, 44, 72, 48, 60        # px scale, cell (world px), origin in cell, blade, fps
GRASS = (0x3e, 0x7f, 0x50, 255)
# sword sprite: points right, grip at centre; scale so grip->tip = BL world px
_s = g["TOOLS"][0][1]; _tip = max(np.nonzero(np.array(_s)[..., 3])[1]) - _s.width // 2
f = BL * Z / _tip; SPR = _s.resize((round(_s.width * f), round(_s.height * f)), Image.NEAREST)
PAD = SPR.width // 2 + 10
REST, BACK, WC, FRONT, END, RC = (4, -6), (-8, -18), (-4, -14), (34, 0), (14, 18), (10, 8)
A0, A1, APAD, RESTA, TW, TR, TP = -60, 60, 30, -20, .15, .20, .35
def pose(t, sw, ta):
    """grip (aim frame) + blade angle at time t of one swing; sw=1 -> mirrored"""
    if t < TW: k = eo(t / TW); gr, a = bez(REST, WC, BACK, k), lerp(RESTA, A0 - APAD, k)
    elif t < TW + ta:
        u = (t - TW) / ta; gr = bez(BACK, FRONT, END, eio(u)); a = lerp(A0 - APAD, A1 + APAD, eio(min(1, u ** 1.6)))
    elif t < TW + ta + TR:
        s = t - TW - ta; gr = bez(END, RC, REST, eo(s / TR)); a = lerp(A1 + APAD, RESTA, eo(s / TR)) + 14 * math.exp(-s * 14) * math.sin(s * 38)
    else: gr, a = REST, RESTA
    return ((gr[0], -gr[1]), -a) if sw else (gr, a)
# ---- trails: list of (time, age 0 new..1 old) samples -> bands -> int image (0 empty, 1+zone*1000+age*200)
def samples_now(t, ta):                                   # 8 last frames, active only, current frame excluded (gap)
    tq = math.floor(t * FPS + 1e-6) / FPS
    return [(tq - k / FPS, k / 8) for k in range(8, 0, -1) if TW <= tq - k / FPS <= TW + ta]
def samples_exact(t, ta, life=.12):                       # dense sub-steps, always ends AT the blade while active
    t0, t1 = max(TW, t - life), min(t, TW + ta)
    n = int((t1 - t0) * FPS * 12) + 1
    return [] if t1 <= t0 else [(t0 + (t1 - t0) * i / n, (t - (t0 + (t1 - t0) * i / n)) / life) for i in range(n + 1)]
def rasterize(smp, sw, ta, bands):
    im = Image.new("I", (CWW, CHH), 0); d = ImageDraw.Draw(im)
    pts = []
    for ts, age in smp:
        gr, a = pose(ts, sw, ta); c, s = math.cos(math.radians(a)), math.sin(math.radians(a)); pts.append((gr, c, s, age))
    for p, q in zip(pts, pts[1:]):                        # oldest first, newer overwrites
        v = min(200, round(max(0, q[3]) * 200))
        for r0, r1, zone in bands:
            d.polygon([(OX + P[0][0] + P[1] * r * BL, OY + P[0][1] + P[2] * r * BL) for P, r in ((p, r0), (p, r1), (q, r1), (q, r0))], fill=1 + zone * 1000 + v, outline=1 + zone * 1000 + v)  # outline: thin slivers still hit pixels
    return np.array(im)
def hex2(h): return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)
RNG = np.random.RandomState(7); H1, H2, H3 = (RNG.rand(CHH, CWW) for _ in range(3))
def colorize(v, pal, drips):
    m = v > 0; zone = (v - 1) // 1000; age = ((v - 1) % 1000) / 200.0
    rgb = np.zeros((CHH, CWW, 3)); head, tail = hex2(pal[0]), hex2(pal[1])
    rgb[:] = head + (tail - head) * age[..., None]
    rgb[zone == 1] = hex2(pal[2]); rgb[zone == 2] = hex2(pal[3])
    keep = m & ((age < .55) | (H1 > (age - .55) / .45))   # old end dissolves
    out = np.zeros((CHH, CWW, 4), np.uint8); out[keep, :3] = rgb[keep].astype(np.uint8); out[keep, 3] = 255
    if drips:                                             # pixel drips hanging down from the old end
        cand = m & (age > .5) & (H2 < .3); L = 1 + (H3 * 4).astype(int)
        for dd in range(1, 5):
            ys, xs = np.nonzero(cand & (L >= dd) & (np.arange(CHH)[:, None] + dd < CHH))
            out[ys + dd, xs, :3] = (rgb[ys, xs] * .9).astype(np.uint8); out[ys + dd, xs, 3] = 255
    return Image.fromarray(out)

_r0, _r1 = .30, 1.0; _rim = _r1 - .12 * (_r1 - _r0)
BAND_NOW = [(_r0, _rim, 0), (_rim, _r1, 1)]
BAND_C = [(_r0, _rim, 0), (.46, .52, 2), (.62, .68, 2), (.78, .83, 2), (_rim, _r1, 1)]
PAL_BLUE = ("#f4fbff", "#8cd0ee", "#54a8e0", "#54a8e0")
PAL_C = ("#ffffff", "#cfeaf8", "#2f6fc0", "#6cb8e8")
# ---- B: drawn slash frames (stand-in crescent if the real art is missing)
def standin(i):
    im = Image.new("RGBA", (48, 48)); px = im.load(); ext = (60, 120, 130, 120)[i]; a_lo = -90 + (0, 0, 40, 80)[i]
    for y in range(48):
        for x in range(48):
            r = math.hypot(x - 23.5, y - 23.5); an = math.degrees(math.atan2(y - 23.5, x - 23.5))
            w = (an - a_lo) / ext
            if 0 <= w <= 1 and 22 - 8 * math.sin(math.pi * w) ** .6 <= r <= 22: px[x, y] = (255, 255, 255, 255) if w > .6 else (140, 208, 238, 255)
    return im
SLASH, REAL = [], True
for i in range(1, 5):
    p = f"{HERE}/../slash_smear/slash_f{i}.png"
    if os.path.exists(p): SLASH.append(Image.open(p).convert("RGBA"))
    else: REAL = False; SLASH.append(standin(i - 1))
def slash_frame(t, ta):
    e = TW + ta; b = [TW + ta / 2, e, e + .04, e + .08, e + .12]
    for i in range(4):
        if b[i] <= t < b[i + 1]: return i
    return None
def slash_layer(w, t, sw, ta):
    i = slash_frame(t, ta)
    if i is None: return
    sp = SLASH[i].resize((106, 106), Image.NEAREST)        # outer radius 22 -> ~48
    sp = sp.rotate(-(A0 + 90), resample=Image.NEAREST, center=(53, 53))   # art start -90 (up) -> swing start angle
    if sw: sp = sp.transpose(Image.FLIP_TOP_BOTTOM)
    gx, gy = END[0], (-END[1] if sw else END[1])
    w.alpha_composite(sp, (OX + gx - 53, OY + gy - 53)) if OX + gx - 53 >= 0 and OY + gy - 53 >= 0 else None
# ---- cell + layout
def body(w):
    d = ImageDraw.Draw(w)
    for fx in (-6, 2): d.rectangle((OX + fx, OY + 11, OX + fx + 4, OY + 14), fill=(60, 60, 66, 255))
    d.rounded_rectangle((OX - 8, OY - 11, OX + 8, OY + 11), 4, fill=(226, 224, 218, 255), outline=(90, 90, 96, 255))
def cell(style, t, sw, ta):
    w = Image.new("RGBA", (CWW, CHH), GRASS); body(w)
    if style == 0: w.alpha_composite(colorize(rasterize(samples_now(t, ta), sw, ta, BAND_NOW), PAL_BLUE, False))
    elif style == 1: w.alpha_composite(colorize(rasterize(samples_exact(t, ta), sw, ta, BAND_NOW), PAL_BLUE, True))
    elif style == 2: slash_layer(w, t, sw, ta)
    else: w.alpha_composite(colorize(rasterize(samples_exact(t, ta), sw, ta, BAND_C), PAL_C, True))
    up = Image.new("RGBA", (CWW * Z + 2 * PAD, CHH * Z + 2 * PAD)); up.alpha_composite(w.resize((CWW * Z, CHH * Z), Image.NEAREST), (PAD, PAD))
    gr, a = pose(t, sw, ta); paste_tool(up, SPR, PAD + round((OX + gr[0]) * Z), PAD + round((OY + gr[1]) * Z), a)
    return up.crop((PAD, PAD, PAD + CWW * Z, PAD + CHH * Z))
NAMES = ["now (in game)", "A: exact path", "B: drawn slash", "C: A path + drawn look"]
ROWS = [("active 0.10 s", .10), ("active 0.16 s (slower)", .16)]
LEFT, TOP = 60, 34; CW_, CH_ = CWW * Z, CHH * Z
W, H = LEFT + 4 * CW_, TOP + 2 * CH_
font = ImageFont.load_default(size=20)
def frame(T):
    img = Image.new("RGB", (W, H), (28, 30, 36)); d = ImageDraw.Draw(img)
    for j, n in enumerate(NAMES): d.text((LEFT + j * CW_ + 10, 8), n, font=font, fill=(255, 230, 140))
    for r, (rn, ta) in enumerate(ROWS):
        tot = TW + ta + TR + TP; tt = T % (2 * tot); sw, t = int(tt // tot), tt % tot
        lab = Image.new("RGBA", (CH_, 30)); ImageDraw.Draw(lab).text((6, 4), rn, font=font, fill=(220, 220, 220, 255))
        img.paste(lab.rotate(90, expand=True), (14, TOP + r * CH_), lab.rotate(90, expand=True))
        for j in range(4): img.paste(cell(j, t, sw, ta).convert("RGB"), (LEFT + j * CW_, TOP + r * CH_))
    return img
if __name__ == "__main__":
    tmp = tempfile.mkdtemp(); n = int(4 * 2 * (TW + .16 + TR + TP) * FPS)
    for i in range(n): frame(i / FPS).save(f"{tmp}/f{i:05d}.png")
    def enc(out, vf):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%05d.png", "-vf", vf, "-pix_fmt", "yuv420p", "-r", str(FPS), f"{HERE}/{out}"], check=True)
    enc("trails_demo.mp4", "scale=trunc(iw/2)*2:trunc(ih/2)*2"); enc("trails_demo_slow.mp4", "setpts=4*PTS,scale=trunc(iw/2)*2:trunc(ih/2)*2")
    shutil.rmtree(tmp)
    # still sheet: 6 consecutive frames of the active phase (0.10 s row), rows = columns
    sc = .55; cw, ch = round(CW_ * sc), round(CH_ * sc); sheet = Image.new("RGB", (6 * cw, 4 * ch + 26), (28, 30, 36)); d = ImageDraw.Draw(sheet)
    for j in range(4):
        d.text((6, 26 + j * ch + 4), NAMES[j], font=font, fill=(255, 230, 140))
        for i in range(6): sheet.paste(cell(j, TW + (i + 1) / FPS, 0, .10).convert("RGB").resize((cw, ch), Image.LANCZOS), (i * cw, 26 + j * ch))
    for i in range(6): d.text((i * cw + 6, 2), f"active +{(i + 1) / FPS * 1000:.0f} ms", font=font, fill=(220, 220, 220))
    sheet.save(f"{HERE}/trails_demo_frames.png"); print("done, real slash art:", REAL)
