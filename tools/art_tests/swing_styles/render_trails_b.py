"""Option B (drawn slash) variants: fix the sprite floating apart from the sword in recovery. $0.
Cols: B now | B1 follows hand | B2 fast fade | B3 slower sword | B4 mix. Reuses render_trails.py.
Run: python3 tools/art_tests/swing_styles/render_trails_b.py -> trails_b_demo.mp4, trails_b_demo_slow.mp4, trails_b_frames.png"""
import math, os, subprocess, tempfile, shutil
from PIL import Image, ImageDraw
import render_trails as R
HERE = R.HERE; TW, Z, OX, OY, CWW, CHH, FPS = R.TW, R.Z, R.OX, R.OY, R.CWW, R.CHH, R.FPS
def third_time(ta, frac=1 / 3):               # when the blade has passed `frac` of its arc (normal swing)
    a0, a1 = R.A0 - R.APAD, R.A1 + R.APAD
    return next(TW + ta * i / 2000 for i in range(2001) if R.pose(TW + ta * i / 2000, 0, ta)[1] >= a0 + frac * (a1 - a0))
def bounds(ta, kind):                         # 5 boundaries: f1 start, f2 start, f3 start, f4 start, end
    e = TW + ta
    return {"old": [TW + ta / 2, e, e + .04, e + .08, e + .12], "fast": [TW + ta / 2, e, e + .02, e + .035, e + .05],
            "slow": [TW + ta / 3, e, e + .02, e + .04, e + .06], "blade": [third_time(ta), e, e + .02, e + .035, e + .05]}[kind]
# label, active, recovery, timing, follow hand, fade f4
VARS = [("B now", .10, .20, "old", 0, 0), ("B1 follows hand", .10, .20, "old", 1, 0), ("B2 fast fade", .10, .20, "fast", 0, 1),
        ("B3 slower sword", .16, .28, "slow", 0, 0), ("B4 mix", .16, .28, "blade", 1, 1)]
PER = TW + .16 + .28 + .35                    # common period so columns stay in sync
def cell(v, t, sw):
    _, ta, tr, kind, follow, fade = v; R.TR = tr
    w = Image.new("RGBA", (CWW, CHH), R.GRASS); R.body(w)
    b = bounds(ta, kind); e = TW + ta
    i = next((k for k in range(4) if b[k] <= t < b[k + 1]), None)
    if i is not None:
        sp = R.SLASH[i].resize((106, 106), Image.NEAREST)
        if fade and i == 3:
            al = 1 - (t - b[3]) / (b[4] - b[3]); sp.putalpha(sp.getchannel("A").point(lambda x: int(x * al)))
        grip, a = R.pose(t, sw, ta); ge, ae = R.pose(e, sw, ta)
        pos, delta = (grip, (a - ae) * .35 * (-1 if sw else 1)) if follow and t > e else (ge, 0)
        sp = sp.rotate(-(R.A0 + 90 + delta), resample=Image.NEAREST, center=(53, 53))
        if sw: sp = sp.transpose(Image.FLIP_TOP_BOTTOM)
        px, py = round(OX + pos[0] - 53), round(OY + pos[1] - 53)
        big = Image.new("RGBA", (CWW + 200, CHH + 200)); big.alpha_composite(sp, (px + 100, py + 100))
        w.alpha_composite(big.crop((100, 100, 100 + CWW, 100 + CHH)))
    up = Image.new("RGBA", (CWW * Z + 2 * R.PAD, CHH * Z + 2 * R.PAD)); up.alpha_composite(w.resize((CWW * Z, CHH * Z), Image.NEAREST), (R.PAD, R.PAD))
    gr, a = R.pose(t, sw, ta); R.paste_tool(up, R.SPR, R.PAD + round((OX + gr[0]) * Z), R.PAD + round((OY + gr[1]) * Z), a)
    return up.crop((R.PAD, R.PAD, R.PAD + CWW * Z, R.PAD + CHH * Z)).convert("RGB")
CW_, CH_, TOP = CWW * Z, CHH * Z, 34
def frame(T):
    img = Image.new("RGB", (5 * CW_, TOP + CH_), (28, 30, 36)); d = ImageDraw.Draw(img)
    tt = T % (2 * PER); sw, t = int(tt // PER), tt % PER
    for j, v in enumerate(VARS): d.text((j * CW_ + 10, 8), v[0], font=R.font, fill=(255, 230, 140)); img.paste(cell(v, t, sw), (j * CW_, TOP))
    return img
if __name__ == "__main__":
    tmp = tempfile.mkdtemp(); n = int(4 * 2 * PER * FPS)
    for i in range(n): frame(i / FPS).save(f"{tmp}/f{i:05d}.png")
    def enc(out, vf):
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%05d.png", "-vf", vf, "-pix_fmt", "yuv420p", "-r", str(FPS), f"{HERE}/{out}"], check=True)
    enc("trails_b_demo.mp4", "scale=trunc(iw/2)*2:trunc(ih/2)*2"); enc("trails_b_demo_slow.mp4", "setpts=4*PTS,scale=trunc(iw/2)*2:trunc(ih/2)*2")
    shutil.rmtree(tmp)
    sc = .42; cw, ch = round(CW_ * sc), round(CH_ * sc); sheet = Image.new("RGB", (8 * cw, 5 * ch + 26), (28, 30, 36)); d = ImageDraw.Draw(sheet)
    for i in range(8): d.text((i * cw + 6, 2), f"+{(i + 1) * 33} ms", font=R.font, fill=(220, 220, 220))
    for j, v in enumerate(VARS):
        d.text((6, 26 + j * ch + 4), v[0], font=R.font, fill=(255, 230, 140))
        for i in range(8): sheet.paste(cell(v, TW + (i + 1) * 2 / FPS, 0).resize((cw, ch), Image.LANCZOS), (i * cw, 26 + j * ch))
    sheet.save(f"{HERE}/trails_b_frames.png")
