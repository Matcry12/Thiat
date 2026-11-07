"""Swing style demo video: 3 styles (A now / B smooth / C poses) x 3 tools. $0, PIL + ffmpeg.
Run: python3 tools/art_tests/swing_styles/render_swings.py  -> swing_styles.mp4 next to this file."""
import math, os, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
PACK = os.path.expanduser("~/Developer/BossFight/docs/assets/Shikashi's Fantasy Icons Pack v2/#1 - Transparent Icons.png")
src = Image.open(PACK).convert("RGBA")
S = 3                                  # icon pixel scale
def icon_h(img):                       # icon drawn handle bottom-left -> head top-right; make it point right, grip at left-centre
    big = img.resize((32 * S, 32 * S), Image.NEAREST)
    c = Image.new("RGBA", (200 * S // 2, 200 * S // 2))
    cx = c.width // 2
    c.alpha_composite(big, (cx - 5 * S, cx - 27 * S))   # grip pixel (5,27) on the centre
    return c.rotate(-45, resample=Image.NEAREST, center=(cx, cx))
TOOLS = [("sword", icon_h(src.crop((32, 160, 64, 192))), -80, 80),
         ("axe", icon_h(Image.open(f"{HERE}/../../../assets/game/ui/items/stone_axe.png").convert("RGBA")), -135, 55),
         ("pickaxe", icon_h(Image.open(f"{HERE}/../../../assets/game/ui/items/stone_pickaxe.png").convert("RGBA")), -135, 55)]
T_W, T_A, T_R, T_P = .28, .12, .35, .45
TOT = T_W + T_A + T_R + T_P
eo = lambda t: 1 - (1 - t) ** 3
eio = lambda t: 4 * t ** 3 if t < .5 else 1 - (-2 * t + 2) ** 3 / 2
def A(t, a0, a1):
    r = a0 * .6
    if t < T_W: return dict(a=r + (a0 - r) * eo(t / T_W))
    t -= T_W
    if t < T_A: return dict(a=a1, slash=1 - t / T_A * .3)
    t -= T_A
    if t < T_R: return dict(a=a1 if t < .06 else a1 + (r - a1) * eo((t - .06) / (T_R - .06)), slash=max(0, .6 - t * 5))
    return dict(a=r)
def B(t, a0, a1):
    r, w, e = a0 * .6, a0 - 10, a1 + 12
    if t < T_W: return dict(a=r + (w - r) * eo(t / T_W))
    t -= T_W
    if t < T_A + .06: return dict(a=w + (e - w) * eio(t / (T_A + .06)), ghost=True)
    t -= T_A + .06
    if t < T_R - .06: return dict(a=e + (r - e) * eo(t / (T_R - .06)), ghost=t < .08)
    return dict(a=r)
def C(t, a0, a1):
    r = a0 * .6
    keys = [(0, r, 1), (.1, a0 * .85, 1), (T_W, a0 - 12, 1), (T_W + .04, (a0 + a1) / 2, 1.35),
            (T_W + .1, a1 + 22, 1), (T_W + .22, a1 + 10, 1), (T_W + .4, a1 * .4, 1), (T_W + T_A + T_R, r, 1)]
    k = keys[0]
    for q in keys:
        if t >= q[0]: k = q
    return dict(a=k[1], stretch=k[2], smear=k[2] > 1)
def paste_tool(img, spr, cx, cy, a, alpha=1.0, stretch=1.0):
    s = spr
    if stretch != 1.0:
        s = s.resize((int(s.width * stretch), s.height), Image.NEAREST)
        s2 = Image.new("RGBA", (int(spr.width * stretch), spr.height)); s2.alpha_composite(s); s = s2
        # keep grip (left-centre of original) on centre: shift so original centre maps right
        s = s.crop((int(spr.width / 2 * stretch - spr.width / 2), 0, int(spr.width / 2 * stretch + spr.width / 2), spr.height))
    r = s.rotate(-a, resample=Image.NEAREST, center=(s.width // 2, s.height // 2))
    if alpha < 1: r.putalpha(r.getchannel("A").point(lambda v: int(v * alpha)))
    img.alpha_composite(r, (cx - r.width // 2, cy - r.height // 2))
CW, CH, TOP, LEFT = 320, 250, 40, 90
W, H = LEFT + 3 * CW, TOP + 3 * CH + 30
font = ImageFont.load_default(size=20); small = ImageFont.load_default(size=16)
FPS = 30
tmp = tempfile.mkdtemp()
frames = []
ghosts = {i: [] for i in range(3)}
plan = [(1.0, 3), (0.3, 1)]           # (speed, loops)
n = 0
for speed, loops in plan:
    steps = int(TOT / speed * FPS) * loops
    for f in range(steps):
        t = (f * speed / FPS) % TOT
        img = Image.new("RGBA", (W, H), (38, 42, 50, 255)); d = ImageDraw.Draw(img)
        for j, name in enumerate(["A. now: snap + circle", "B. smooth + afterimages", "C. hand-made poses"]):
            d.text((LEFT + j * CW + 20, 10), name, font=font, fill=(255, 230, 140))
        for i, (tname, spr, a0, a1) in enumerate(TOOLS):
            d.text((10, TOP + i * CH + CH // 2 - 10), tname, font=font, fill=(220, 220, 220))
            for j, fn in enumerate((A, B, C)):
                cx, cy = LEFT + j * CW + CW // 2 - 20, TOP + i * CH + CH // 2 + 10
                s = fn(t, a0, a1)
                d.rounded_rectangle((cx - 18, cy - 26, cx + 18, cy + 20), 8, fill=(232, 230, 223), outline=(20, 20, 20), width=2)
                if j == 0 and s.get("slash", 0) > 0:
                    rr = 100
                    d.arc((cx - rr, cy - rr, cx + rr, cy + rr), a0, a1, fill=(140, 200, 255), width=16)
                    d.arc((cx - rr, cy - rr, cx + rr, cy + rr), a0, a1, fill=(255, 255, 255), width=6)
                if j == 1:
                    g = ghosts[i]
                    if s.get("ghost"): g.append(s["a"])
                    elif g: g.pop(0)
                    del g[:-5]
                    for k, ga in enumerate(g): paste_tool(img, spr, cx, cy, ga, .15 + k * .08)
                if j == 2 and s.get("smear"):
                    rr = 115
                    d.pieslice((cx - rr, cy - rr, cx + rr, cy + rr), a0, s["a"], fill=(200, 205, 220, 255))
                paste_tool(img, spr, cx, cy, s["a"], 1.0, s.get("stretch", 1.0))
        d.text((W - 120, H - 26), f"speed {speed:.1f}x", font=small, fill=(200, 200, 200))
        img.convert("RGB").save(f"{tmp}/f{n:05d}.png"); n += 1
out = f"{HERE}/swing_styles.mp4"
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%05d.png",
                "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-pix_fmt", "yuv420p", out], check=True)
print(out, n, "frames")
