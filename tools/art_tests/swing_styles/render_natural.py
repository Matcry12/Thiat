"""B vs natural swings: the GRIP moves (arm), not only the angle, so the tip path is not a circle.
Cols: B (fixed grip = circle) | B + arm path | B + arm + wrist lag/overshoot. Faint dots = tip path.
Run: python3 tools/art_tests/swing_styles/render_natural.py -> swing_natural.mp4"""
import math, os, subprocess, tempfile
from PIL import Image, ImageDraw, ImageFont
import importlib.util
spec = importlib.util.spec_from_file_location("rs", os.path.join(os.path.dirname(__file__), "render_swings.py"))
HERE = os.path.dirname(os.path.abspath(__file__))
# reuse sprites/helpers without running the old render: exec only its top half
src_code = open(f"{HERE}/render_swings.py").read().split("CW, CH, TOP, LEFT")[0]
g = {"__file__": f"{HERE}/render_swings.py"}; exec(src_code, g)
TOOLS, paste_tool, eo, eio = g["TOOLS"], g["paste_tool"], g["eo"], g["eio"]
SWORD_ONLY = os.environ.get("SWORD_ONLY") == "1"
if SWORD_ONLY: TOOLS = TOOLS[:1]
T_W, T_A, T_R, T_P = .28, .14, .40, .45
TOT = T_W + T_A + T_R + T_P
def lerp(a, b, k): return a + (b - a) * k
def bez(p0, p1, p2, k): return (lerp(lerp(p0[0], p1[0], k), lerp(p1[0], p2[0], k), k), lerp(lerp(p0[1], p1[1], k), lerp(p1[1], p2[1], k), k))
def rot(p, a):
    c, s = math.cos(math.radians(a)), math.sin(math.radians(a)); return (p[0] * c - p[1] * s, p[0] * s + p[1] * c)
# grip points in the aim frame (x = toward aim, y = to the side, + = the side the swing ends on), world px
REST, BACK, FRONT, END = (4, -6), (-8, -18), (22, 0), (6, 16)
def swing(t, a0, a1, arm, wrist):
    """returns grip (aim frame) and tool angle"""
    r = a0 * .6
    if t < T_W:
        k = eo(t / T_W)
        return (bez(REST, (-4, -14), BACK, k) if arm else (0, 0)), lerp(r, a0 - 10, k)
    t -= T_W
    if t < T_A:
        k = eio(t / T_A)
        kw = eio(min(1, (t / T_A) ** 1.6)) if wrist else k          # wrist lags the arm, then whips through
        return (bez(BACK, FRONT, END, k) if arm else (0, 0)), lerp(a0 - 10, a1 + 12, kw)
    t -= T_A
    if t < T_R:
        k = eo(t / T_R)
        a = lerp(a1 + 12, r, k)
        if wrist: a += 14 * math.exp(-t * 14) * math.sin(t * 38)  # overshoot then settle, like a real wrist
        return (bez(END, (10, 8), REST, k) if arm else (0, 0)), a
    return (REST if arm else (0, 0)), r
CW, CH, TOP, LEFT = 320, 250, 40, 90
CH = 300 if SWORD_ONLY else CH
W, H = LEFT + 3 * CW, TOP + len(TOOLS) * CH + 30
font = ImageFont.load_default(size=20); small = ImageFont.load_default(size=16)
FPS, AIM = (60 if SWORD_ONLY else 30), 0.0
tmp = tempfile.mkdtemp(); n = 0
trails = {(i, j): [] for i in range(3) for j in range(3)}
ghosts = {(i, j): [] for i in range(3) for j in range(3)}
for speed, loops in [(1.0, 3), (0.3, 1)]:
    for f in range(int(TOT / speed * FPS) * loops):
        t = (f * speed / FPS) % TOT
        img = Image.new("RGBA", (W, H), (38, 42, 50, 255)); d = ImageDraw.Draw(img)
        for j, name in enumerate(["B. hand fixed (circle)", "B + arm moves", "B + arm + wrist"]):
            d.text((LEFT + j * CW + 20, 10), name, font=font, fill=(255, 230, 140))
        for i, (tname, spr, a0, a1) in enumerate(TOOLS):
            d.text((10, TOP + i * CH + CH // 2 - 10), tname, font=font, fill=(220, 220, 220))
            for j in range(3):
                cx, cy = LEFT + j * CW + CW // 2 - 20, TOP + i * CH + CH // 2 + 10
                grip, a = swing(t, a0, a1, arm=j >= 1, wrist=j == 2)
                gx, gy = rot((grip[0] * 1.6, grip[1] * 1.6), AIM)   # x1.6: same scale as the 3x icons
                gx, gy = cx + gx, cy + gy
                active = T_W <= t < T_W + T_A + 0.1
                tip = (gx + math.cos(math.radians(a)) * 70, gy + math.sin(math.radians(a)) * 70)
                tr = trails[(i, j)]
                if active: tr.append(tip)
                elif t < 0.05: tr.clear()
                for p in tr: d.ellipse((p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2), fill=(255, 210, 120))
                d.rounded_rectangle((cx - 18, cy - 26, cx + 18, cy + 20), 8, fill=(232, 230, 223), outline=(20, 20, 20), width=2)
                gh = ghosts[(i, j)]
                if active: gh.append((gx, gy, a))
                elif gh: gh.pop(0)
                del gh[:-5]
                for k, (hx, hy, ha) in enumerate(gh): paste_tool(img, spr, int(hx), int(hy), ha, .15 + k * .08)
                paste_tool(img, spr, int(gx), int(gy), a)
        d.text((W - 120, H - 26), f"speed {speed:.1f}x", font=small, fill=(200, 200, 200))
        d.text((LEFT, H - 26), "orange dots = path of the tool tip", font=small, fill=(200, 200, 200))
        img.convert("RGB").save(f"{tmp}/f{n:05d}.png"); n += 1
out = f"{HERE}/swing_natural{'_sword' if SWORD_ONLY else ''}.mp4"
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS), "-i", f"{tmp}/f%05d.png",
                "-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-pix_fmt", "yuv420p", out], check=True)
print(out, n)
