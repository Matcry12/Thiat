"""Slash art placed ON the blade: head (clockwise end of the crescent) sits on the live blade angle. $0.
Cols: B2 old pos | P1 head on blade | P2 outer band | P3 frozen after active. Reuses render_trails.py.
Run: python3 tools/art_tests/swing_styles/render_trails_b2.py -> trails_b2_demo.mp4, trails_b2_demo_slow.mp4, trails_b2_frames.png"""
import math, shutil, subprocess, tempfile
import numpy as np
from PIL import Image, ImageDraw
import render_trails as R
HERE = R.HERE; TW, Z, OX, OY, CWW, CHH, FPS = R.TW, R.Z, R.OX, R.OY, R.CWW, R.CHH, R.FPS
TA, TRC = .13, .24; R.TR = TRC; E = TW + TA
PER = TW + TA + TRC + .35
HEAD = []                                    # art angle (deg, screen, 0 = right) of the newest/clockwise end per frame
for s in R.SLASH:
    ys, xs = np.nonzero(np.array(s)[..., 3] > 0); HEAD.append(float(np.degrees(np.arctan2(ys - 24, xs - 24)).max()))
def art(i, scale, rmin):                     # scaled art, optionally with the inner part (art radius < rmin) cut off
    s = R.SLASH[i].copy(); px = s.load()
    for y in range(48):
        for x in range(48):
            if math.hypot(x - 24, y - 24) < rmin: px[x, y] = (0, 0, 0, 0)
    n = round(48 * scale); return s.resize((n, n), Image.NEAREST)
# label, scale, rmin, mode ("old" fixed at END | "live" | "frozen")
VARS = [("B2 (old pos)", 2.2, 0, "old"), ("P1 head on blade", 1.7, 0, "live"), ("P2 head on blade, outer", 2.2, 12.2, "live"),
        ("P3 frozen after active", 2.2, 12.2, "frozen")]
def sweep_time(span):                        # first time the blade is `span` deg past its active-start angle
    return next(TW + TA * i / 2000 for i in range(2001) if R.pose(TW + TA * i / 2000, 0, TA)[1] - (R.A0 - R.APAD) >= span)
T1, T2 = sweep_time(HEAD[0] + 90), sweep_time(HEAD[1] + 90)   # f1 / f2 only once the blade has swept their arc span
def frame_idx(t, mode, fade=.05):
    b = [TW + TA / 2, E, E + .02, E + .035, E + .05] if mode == "old" else [T1, T2, E, E + fade / 2, E + fade]
    return next((k for k in range(4) if b[k] <= t < b[k + 1]), None), b
def cell(v, t, sw):
    _, sc, rmin, mode = v
    w = Image.new("RGBA", (CWW, CHH), R.GRASS); R.body(w)
    i, b = frame_idx(t, mode, .08 if mode == 'frozen' else .05)
    if i is not None:
        sp = art(i, sc, rmin); n = sp.width
        if i == 3: al = 1 - (t - b[3]) / (b[4] - b[3]); sp.putalpha(sp.getchannel("A").point(lambda x: int(x * al)))
        tt = min(t, E) if mode == "frozen" else t        # frozen: pose of the end of active
        grip, a = R.pose(tt, sw, TA)
        if mode == "old": grip, rot = R.pose(E, sw, TA)[0], R.A0 + 90
        else: rot = (-a if sw else a) - HEAD[i]          # normal-frame blade angle minus art head angle (clockwise turn)
        sp = sp.rotate(-rot, resample=Image.NEAREST, center=(n // 2, n // 2), expand=False)
        if sw: sp = sp.transpose(Image.FLIP_TOP_BOTTOM)
        big = Image.new("RGBA", (CWW + 300, CHH + 300)); big.alpha_composite(sp, (round(OX + grip[0] - n / 2) + 150, round(OY + grip[1] - n / 2) + 150))
        w.alpha_composite(big.crop((150, 150, 150 + CWW, 150 + CHH)))
    up = Image.new("RGBA", (CWW * Z + 2 * R.PAD, CHH * Z + 2 * R.PAD)); up.alpha_composite(w.resize((CWW * Z, CHH * Z), Image.NEAREST), (R.PAD, R.PAD))
    gr, a = R.pose(t, sw, TA); R.paste_tool(up, R.SPR, R.PAD + round((OX + gr[0]) * Z), R.PAD + round((OY + gr[1]) * Z), a)
    return up.crop((R.PAD, R.PAD, R.PAD + CWW * Z, R.PAD + CHH * Z)).convert("RGB")
CW_, CH_, TOP = CWW * Z, CHH * Z, 34
def frame(T):
    img = Image.new("RGB", (4 * CW_, TOP + CH_), (28, 30, 36)); d = ImageDraw.Draw(img)
    tt = T % (2 * PER); sw, t = int(tt // PER), tt % PER
    for j, v in enumerate(VARS): d.text((j * CW_ + 10, 8), v[0], font=R.font, fill=(255, 230, 140)); img.paste(cell(v, t, sw), (j * CW_, TOP))
    return img
if __name__ == "__main__":
    tmp = tempfile.mkdtemp()
    for i in range(int(4 * 2 * PER * FPS)): frame(i / FPS).save(f"{tmp}/f{i:05d}.png")
    def enc(out, vf):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%05d.png", "-vf", vf, "-pix_fmt", "yuv420p", "-r", str(FPS), f"{HERE}/{out}"], check=True)
    enc("trails_b2_demo.mp4", "scale=trunc(iw/2)*2:trunc(ih/2)*2"); enc("trails_b2_demo_slow.mp4", "setpts=4*PTS,scale=trunc(iw/2)*2:trunc(ih/2)*2")
    shutil.rmtree(tmp)
    sc = .42; cw, ch = round(CW_ * sc), round(CH_ * sc); sheet = Image.new("RGB", (8 * cw, 4 * ch + 26), (28, 30, 36)); d = ImageDraw.Draw(sheet)
    for i in range(8): d.text((i * cw + 6, 2), f"+{i * 25} ms", font=R.font, fill=(220, 220, 220))
    for j, v in enumerate(VARS):
        d.text((6, 26 + j * ch + 4), v[0], font=R.font, fill=(255, 230, 140))
        for i in range(8): sheet.paste(cell(v, TW + i * .025, 0).resize((cw, ch), Image.LANCZOS), (i * cw, 26 + j * ch))
    sheet.save(f"{HERE}/trails_b2_frames.png"); print(HEAD)
