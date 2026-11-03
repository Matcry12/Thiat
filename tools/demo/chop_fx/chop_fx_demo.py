#!/usr/bin/env python3
"""Tree-chopping hit-feedback DEMO VIDEO for BossFight ($0: pure Python + ffmpeg, no Godot, no game code).

Renders the real Pixel Plains oak (data/resource_nodes/treepp_oak_green_mature.tres: oaks_noshadow.png region 0,
foot anchor (21,40), stump from hedges.png) with the variants side by side, so the user can pick:
  0 current | A1-A3 hit reaction | D1-D3 debris | S1-S3 sound | B1-B2 progress | C1-C3 tree fall
Sounds are synthesised here (noise + sine, envelope, low-pass, like tools/make_sfx.py) into a temp dir.

Run (from repo root):   python3 tools/demo/chop_fx/chop_fx_demo.py
Output: tools/demo/chop_fx/chop_fx_demo.mp4 (1280x720, 60 fps, AAC) + tools/demo/chop_fx/stills/*.png
Needs: PIL, numpy, scipy, ffmpeg. Frames are piped to ffmpeg (nothing big is written to the repo).
"""
import math, subprocess, tempfile, wave, pathlib
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy.signal import lfilter

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parent.parent.parent
OUT_MP4 = HERE / "chop_fx_demo.mp4"
STILLS = HERE / "stills"
TMP = pathlib.Path(tempfile.mkdtemp(prefix="chopfx_"))
FPS = 60
VW, VH = 1280, 720
S = 4                       # art px -> screen px
W, H = 100, 120             # panel world size in art px
FX, GY = 42, 84             # foot point of the tree (art px)
PX = FX - 27                # player x
PW, PH, LBL = W * S, H * S, 56
HEAD, FOOT = 76, 108
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
def font(n): return ImageFont.truetype(FONT, n)

# ---------------------------------------------------------------- art
PP = ROOT / "assets/map/pixel_plains"
SPR = np.array(Image.open(PP / "oaks_noshadow.png").convert("RGBA").crop((99, 0, 141, 43)))   # regions[0]
STUMP = np.array(Image.open(PP / "hedges.png").convert("RGBA").crop((15, 93, 33, 104)))     # remains_region
GROUND = np.array((84, 146, 66), np.float32)        # grass colour of tiles.png, a bit darker so the crown reads
LEAF = [(99, 171, 63), (59, 125, 79), (164, 196, 67)]  # sampled from the crown
CHIP_L = [(255, 206, 145), (255, 174, 112)]
CHIP_D = [(189, 106, 98), (82, 51, 63)]

def make_bg():
    rng = np.random.default_rng(5)
    bg = np.tile(GROUND, (H, W, 1))
    m = rng.random((H, W))
    bg[m < 0.03] *= 0.88
    bg[m > 0.985] *= 1.1
    bg[:GY - 30] *= 1.0
    return bg.clip(0, 255)
BG = make_bg()

def canvas_sprite(img, x, y):
    c = np.zeros((H, W, 4), np.uint8)
    h, w = img.shape[:2]
    c[y:y + h, x:x + w] = img
    return c
TREE0 = canvas_sprite(SPR, FX - 21, GY - 40)
STUMP0 = canvas_sprite(STUMP, FX - 9, GY - 7)

def over(cv, rgba, alpha=1.0):
    a = rgba[..., 3:4].astype(np.float32) / 255 * alpha
    cv[:] = cv * (1 - a) + rgba[..., :3] * a

def rect(cv, x, y, w, h, col, a=1.0):
    x0, y0, x1, y1 = max(x, 0), max(y, 0), min(x + w, W), min(y + h, H)
    if x1 > x0 and y1 > y0:
        cv[y0:y1, x0:x1] = cv[y0:y1, x0:x1] * (1 - a) + np.array(col, np.float32) * a

# ---------------------------------------------------------------- tree transforms
def pil_tf(arr, fn):
    return np.array(fn(Image.fromarray(arr)))

def scale_about(arr, sx, sy, cx=FX, cy=GY):
    return pil_tf(arr, lambda im: im.transform((W, H), Image.AFFINE,
                  (1 / sx, 0, cx - cx / sx, 0, 1 / sy, cy - cy / sy), Image.NEAREST))

def bend(arr, d, p=1.5):
    """Foot fixed, top shifted d art px (sub-linear so the trunk bends, crown moves most)."""
    if abs(d) < 0.5: return arr
    out = np.zeros_like(arr)
    for y in range(GY - 42, GY + 4):
        h = max(GY - y, 0) / 40.0
        o = int(round(d * min(h, 1.1) ** p))
        if o == 0: out[y] = arr[y]
        elif o > 0: out[y, o:] = arr[y, :-o]
        else: out[y, :o] = arr[y, -o:]
    return out

def shift_x(arr, dx, dy=0):
    dx, dy = int(round(dx)), int(round(dy))
    out = np.zeros_like(arr)
    xs, xd = (slice(0, W - dx), slice(dx, W)) if dx >= 0 else (slice(-dx, W), slice(0, W + dx))
    ys, yd = (slice(0, H - dy), slice(dy, H)) if dy >= 0 else (slice(-dy, H), slice(0, H + dy))
    out[yd, xd] = arr[ys, xs]
    return out

def rotate(arr, deg):
    return pil_tf(arr, lambda im: im.rotate(-deg, Image.NEAREST, center=(FX, GY)))

def ease_out(u): u = min(max(u, 0), 1); return 1 - (1 - u) ** 3
def clamp01(u): return min(max(u, 0.0), 1.0)

# ---------------------------------------------------------------- audio synth (port of tools/make_sfx.py, numpy)
AR = 44100
def synth(dur, f0=0, f1=0, noise=0.0, attack=0.003, decay=6.0, lp=0.5, partials=(1.0,), seed=1, freqs=None):
    rng = np.random.default_rng(seed)
    n = int(dur * AR)
    t = np.arange(n) / AR
    f = f0 + (f1 - f0) * (np.arange(n) / n)
    phase = np.cumsum(2 * np.pi * f / AR)
    s = sum(a * np.sin(phase * k) for k, a in enumerate(partials, 1)) / sum(partials)
    if freqs:   # inharmonic metal partials: (hz, amp, decay)
        s = sum(a * np.sin(2 * np.pi * h * t) * np.exp(-d * t / dur) for h, a, d in freqs) / sum(a for _, a, _ in freqs)
    s = s * (1 - noise) + rng.uniform(-1, 1, n) * noise
    env = np.minimum(1, t / attack) * np.exp(-decay * t / dur)
    k = 1 - (1 - lp) ** 0.5            # make_sfx lp was tuned at 22050 Hz
    return lfilter([k], [1, -(1 - k)], s * env)

def mixl(*ls):
    n = max(len(l) for l in ls); o = np.zeros(n)
    for l in ls: o[:len(l)] += l
    return o

def norm(x, peak=0.6): return x / (np.abs(x).max() or 1) * peak

SND = {
    "clang": norm(mixl(synth(0.30, freqs=[(1180, 1, 7), (2480, .6, 9), (3410, .4, 11)], lp=.7),
                       synth(0.05, noise=1, decay=8, lp=.7, seed=2))),
    "tok": norm(mixl(synth(0.08, 560, 330, decay=9, lp=.55), synth(0.02, noise=1, decay=8, lp=.3, seed=3)), .55),
    "thunk": norm(mixl(synth(0.17, 150, 68, decay=6, lp=.4), synth(0.045, noise=1, decay=8, lp=.2, seed=4)), .7),
    "chock": norm(mixl(synth(0.035, noise=1, decay=12, lp=.75, seed=5), synth(0.10, 380, 200, decay=8, lp=.5),
                       synth(0.06, noise=1, decay=9, lp=.35, seed=6)), .65),
    "crack": norm(mixl(synth(0.14, 700, 260, noise=.5, decay=6, lp=.45, seed=7), synth(0.05, noise=1, decay=8, lp=.6, seed=8)), .5),
    "thud": norm(mixl(synth(0.6, 80, 28, decay=4, lp=.5), synth(0.32, noise=1, decay=5, lp=.15, seed=9)), .9),
    "rustle": norm(synth(0.35, noise=1, attack=.04, decay=4, lp=.8, seed=10), .3),
    "pop": norm(mixl(synth(0.12, 300, 90, decay=7, lp=.5), synth(0.25, noise=1, decay=5, lp=.65, seed=11)), .7),
}
def pitched(x, p):
    return np.interp(np.arange(0, len(x) - 1, p), np.arange(len(x)), x)

# ---------------------------------------------------------------- panel (one variant)
class Panel:
    def __init__(self, code, name, hits, seed=0, **c):
        self.code, self.name, self.hits = code, name, hits           # hits: [(time, strength)]
        d = dict(motion="sway", amp=7.0, flash=.05, freeze=2, trauma=.05, chips=0, leaves=0, dust=False, sparks=0,
                 squash=False, fall=None, sound="thunk", prog_pitch=0.0, slide=0.0)
        d.update(c); self.c = d
        self.fz = d["freeze"] / 60.0
        # te (animation time) at each impact: earlier freezes already removed
        self.hit_te = [h - self.fz * i for i, (h, _) in enumerate(hits)]
        rng = np.random.default_rng(sum(map(ord, code)) + seed)
        self.parts = []
        self.audio = []          # (ts, sound, pitch)
        for i, ((h, s), te) in enumerate(zip(hits, self.hit_te)):
            last = i == len(hits) - 1
            nch = d["chips"][i] if isinstance(d["chips"], list) else d["chips"]
            nlv = d["leaves"][i] if isinstance(d["leaves"], list) else d["leaves"]
            if d["fall"] in ("tip", "roll", "pop") : nch = 0 if d["fall"] != "pop" else 0
            for _ in range(nch):
                big = rng.random() < .35
                col = CHIP_L[rng.integers(2)] if rng.random() < .5 else CHIP_D[rng.integers(2)]
                self.parts.append(dict(k="chip", t=te, x=FX - 2 + rng.uniform(-2, 2), y=GY + rng.uniform(-2, 2), z=5 + rng.uniform(0, 3),
                                       vx=rng.uniform(16, 46), vz=rng.uniform(48, 84), w=3 if big else 2, h=2, col=col, life=.75))
            for _ in range(nlv):
                self.parts.append(dict(k="leaf", t=te + rng.uniform(0, .12), x=FX + rng.uniform(-16, 16), y=GY - rng.uniform(22, 38),
                                       vx=3, vy=rng.uniform(11, 17), g=0, A=rng.uniform(3, 5), f=rng.uniform(1.2, 1.8),
                                       ph=rng.uniform(0, 6.28), col=LEAF[rng.integers(3)], life=1.25, w=2, h=1))
            if d["dust"]:
                for j in range(3):
                    self.parts.append(dict(k="dust", t=te + j * .03, x=FX + 3 + rng.uniform(-2, 5), y=GY + rng.uniform(-1, 2),
                                           r0=1, r1=3.5, vx=rng.uniform(4, 12), life=.4))
            for _ in range(d["sparks"]):
                ang = rng.uniform(-1.0, 0.3)
                v = rng.uniform(110, 190)
                self.parts.append(dict(k="spark", t=te, x=FX - 3, y=GY - 5, vx=v * math.cos(ang), vy=v * math.sin(ang), life=.18))
            tr = d["trauma"][i] if isinstance(d["trauma"], list) else d["trauma"]
            self.parts.append(dict(k="shake", t=te, tr=tr))
            p = (1 + rng.uniform(-.05, .05)) * (1 + d["prog_pitch"] * i)
            self.audio.append((h, d["sound"], p))
            if last and d["fall"]:
                self._fall(te, rng)
        self.tb = self.hit_te[-1]
        self.has_stump = d["fall"] is not None

    def te_to_ts(self, te):
        return te + self.fz * sum(1 for t in self.hit_te if t <= te)

    def _fall(self, tb, rng):
        f, c = self.c["fall"], self.parts
        if f == "swap":
            return
        if f == "pop":
            tp = tb + .12
            for _ in range(16):
                a = rng.uniform(0, 6.28); v = rng.uniform(30, 75)
                c.append(dict(k="leaf", t=tp, x=FX + rng.uniform(-8, 8), y=GY - 24 + rng.uniform(-8, 8), vx=v * math.cos(a), vy=v * math.sin(a) - 25,
                              g=70, A=1.5, f=1.5, ph=rng.uniform(0, 6), col=LEAF[rng.integers(3)], life=1.2, w=2, h=1))
            for _ in range(10):
                col = CHIP_L[rng.integers(2)] if rng.random() < .5 else CHIP_D[rng.integers(2)]
                c.append(dict(k="chip", t=tp, x=FX, y=GY + rng.uniform(-1, 3), z=14 + rng.uniform(0, 6), vx=rng.uniform(-50, 50),
                              vz=rng.uniform(50, 100), w=3 if rng.random() < .4 else 2, h=2, col=col, life=.9))
            for k in range(3):
                xt = FX + (-1) ** k * rng.uniform(9, 22) + (k - 1) * 3
                c.append(dict(k="log", t=tp + k * .04, x=FX, y=GY - 4, xt=xt, yt=GY + 2 + rng.uniform(-1, 5), hop=16))
            c.append(dict(k="shake", t=tp, tr=.3))
            self.audio += [(self.te_to_ts(tp), "pop", 1.0), (self.te_to_ts(tp), "rustle", 1.0)]
            return
        la = tb + .08 + .6                        # landing (te)
        self.la = la
        self.audio += [(self.te_to_ts(tb), "crack", 1.0), (self.te_to_ts(la), "thud", 1.0)]
        c.append(dict(k="shake", t=la, tr=.45))
        slide = 16 if f == "roll" else 0
        for j in range(5):
            c.append(dict(k="dust", t=la + j * .02, x=FX + 12 + j * 8 + rng.uniform(-3, 3), y=GY + 3 + rng.uniform(-2, 4),
                          r0=2, r1=6.5, vx=rng.uniform(-6, 10), life=.55))
        if f == "roll":
            for j in range(8):
                c.append(dict(k="dust", t=la + .06 * j, x=FX + 22 + slide * ease_out(.06 * j / .55) + rng.uniform(-8, 8), y=GY + 4 + rng.uniform(-2, 5),
                              r0=1.5, r1=5, vx=-8, life=.5))
        for _ in range(10):
            c.append(dict(k="leaf", t=la + rng.uniform(0, .06), x=FX + rng.uniform(28, 46), y=GY - 2 + rng.uniform(-4, 4),
                          vx=rng.uniform(-14, 22), vy=-rng.uniform(25, 55), g=75, A=1.5, f=1.6, ph=rng.uniform(0, 6),
                          col=LEAF[rng.integers(3)], life=1.1, w=2, h=1))
        t0 = la + (.58 if f == "roll" else .08)
        for k in range(3):
            xt = FX + 18 + k * 13 + slide + rng.uniform(-2, 2)
            c.append(dict(k="log", t=t0 + k * .07, x=xt - 10, y=GY, xt=xt, yt=GY + 5 + rng.uniform(-1, 4), hop=14))

    # --- state helpers
    def fall_state(self, te):
        """Returns dict for the tree layer after the breaking hit."""
        f = self.c["fall"]; a = te - self.tb
        st = dict(vis=True, angle=0, sx=1, sy=1, dx=0, dy=0, alpha=1.0, flash=0)
        if f == "swap":
            st["vis"] = a < .10; return st
        if f == "pop":
            st["flash"] = 1 if a < .09 else 0
            st["sx"] = st["sy"] = 1 + .10 * ease_out(a / .1)
            st["vis"] = a < .12; return st
        u = clamp01((a - .08) / .6)
        st["angle"] = 88 * u ** 2.5
        b = a - .68
        if b > 0:
            st["angle"] = 88 - 6 * math.exp(-10 * b) * abs(math.sin(2 * math.pi * 4 * b))
            st["sy"] = 1 - .12 * math.exp(-12 * b) * math.cos(14 * b) ** 2
            st["sx"] = 1 + .05 * math.exp(-12 * b)
            if f == "roll":
                st["dx"] = 16 * ease_out(b / .55)
                st["angle"] += 3 * math.sin(2 * math.pi * 2.5 * b) * math.exp(-3 * b)
                st["dy"] = 4 * clamp01((b - .55) / .5)
                st["alpha"] = 1 - clamp01((b - .6) / .5)
            else:
                st["alpha"] = 1 - clamp01((b - .55) / .4)
        st["flash"] = 1 if a < .05 else 0
        st["vis"] = st["alpha"] > 0.01
        return st

    def tree_layer(self, te):
        c = self.c
        if self.c["fall"] and te >= self.tb:
            fs = self.fall_state(te)
        else:
            fs = dict(vis=True, angle=0, sx=1, sy=1, dx=0, dy=0, alpha=1.0, flash=0)
        if not fs["vis"]: return None
        lay = TREE0
        lean = 0.0; sq = (1.0, 1.0); fl = fs["flash"]; slide = 0.0
        for (h, s), t0 in zip(self.hits, self.hit_te):
            a = te - t0
            if a < 0: continue
            if a < c["flash"]: fl = 1
            if c["motion"] in ("sway", "swaysq"):
                lean += s * c["amp"] * min(1, a / .03) * math.exp(-5.5 * a) * math.cos(2 * math.pi * 4.5 * a)
                if c["motion"] == "swaysq" and a < .22:
                    k = math.exp(-14 * a) * min(1, a / .015)
                    sq = (sq[0] + .06 * k * s, sq[1] - .06 * k * s)
            elif c["motion"] == "shake":
                lean += s * 3.2 * math.exp(-9 * a) * math.cos(2 * math.pi * 22 * a)
            elif c["motion"] == "slide" and a < .1:
                slide += 1.5 * math.sin(math.pi * a / .1)
        if sq != (1.0, 1.0): lay = scale_about(lay, *sq)
        if lean: lay = bend(lay, lean)
        if slide: lay = shift_x(lay, slide)
        if not fs["angle"] and (fs["sx"] != 1 or fs["sy"] != 1):
            lay = scale_about(lay, fs["sx"], fs["sy"])
        if fs["angle"]:
            lay = rotate(lay, fs["angle"])
            if fs["sy"] != 1 or fs["sx"] != 1: lay = scale_about(lay, fs["sx"], fs["sy"], FX, GY + 2)
        if fs["dx"] or fs["dy"]: lay = shift_x(lay, fs["dx"], fs["dy"])
        lay = lay.copy()
        if fl:
            m = lay[..., 3] > 0
            lay[m, :3] = 255
        lay = lay.copy(); lay[..., 3] = (lay[..., 3] * fs["alpha"]).astype(np.uint8)
        return lay

    # --- player
    def player(self, cv, te):
        best = None
        for t0 in self.hit_te:
            d = te - t0
            if -.28 < d < .3: best = d
        if best is None: ang = -100
        elif best < -.1: ang = -100 - 30 * ease_out((best + .28) / .18)
        elif best < 0: ang = -130 + 150 * ((best + .1) / .1) ** 2
        elif best < .1: ang = 20
        else: ang = 20 - 120 * ease_out((best - .1) / .2)
        im = Image.new("RGBA", (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        bx, by = PX, GY + 2
        d.ellipse((bx - 4, by - 1, bx + 5, by + 2), fill=(0, 0, 0, 60))
        d.rectangle((bx - 2, by - 8, bx + 2, by - 1), fill=(70, 100, 210, 255))      # body
        d.rectangle((bx - 2, by - 1, bx - 1, by), fill=(60, 50, 60, 255)); d.rectangle((bx + 1, by - 1, bx + 2, by), fill=(60, 50, 60, 255))
        d.rectangle((bx - 2, by - 13, bx + 2, by - 9), fill=(240, 200, 160, 255))    # head
        d.rectangle((bx - 2, by - 13, bx + 2, by - 12), fill=(90, 55, 40, 255))
        hx, hy = bx + 2, by - 6
        r = math.radians(ang)
        tx, ty = hx + 9 * math.cos(r), hy + 9 * math.sin(r)
        if best is not None and -.1 < best < .04:      # swipe streak
            for k in range(1, 4):
                r2 = math.radians(ang - 22 * k)
                d.line((hx + 5 * math.cos(r2), hy + 5 * math.sin(r2), hx + 11 * math.cos(r2), hy + 11 * math.sin(r2)),
                       fill=(255, 255, 255, 230 - 60 * k))
        d.line((hx, hy, tx, ty), fill=(130, 85, 50, 255))
        d.rectangle((round(tx) - 1, round(ty) - 1, round(tx) + 1, round(ty)), fill=(190, 200, 210, 255))
        over(cv, np.array(im))

    def shake_px(self, te):
        amp = 0.0
        for p in self.parts:
            if p["k"] == "shake" and te >= p["t"]:
                amp += 20 * p["tr"] * max(0, 1 - (te - p["t"]) / .3) ** 2
        r = np.random.default_rng(abs(int(te * 60)) + 7)
        return int(round(amp * r.uniform(-1, 1))), int(round(amp * r.uniform(-1, 1) * .6))

    def render(self, ts):
        """World image (H,W,3 float) at sim time ts, plus screen shake offset."""
        te = ts - sum(min(max(ts - h, 0), self.fz) for h, _ in self.hits)
        cv = BG.copy()
        broken = self.c["fall"] and te >= self.tb + (.0 if self.c["fall"] in ("tip", "roll") else .10)
        # shadow
        sh = 1.0
        if self.c["fall"] in ("tip", "roll") and te >= self.tb: sh = 1 - clamp01((te - self.tb) / .25)
        if self.c["fall"] in ("swap", "pop") and broken: sh = 0
        if sh > 0:
            for yy in range(-3, 4):
                half = int(15 * math.sqrt(1 - (yy / 3.6) ** 2))
                rect(cv, FX - half, GY + 1 + yy, half * 2, 1, (0, 0, 0), .2 * sh)
        if self.c["fall"] and te >= self.tb: over(cv, STUMP0)
        self.player(cv, te)
        lay = self.tree_layer(te)
        if lay is not None: over(cv, lay)
        logs = []
        for p in self.parts:
            a = te - p["t"]
            if a < 0 or p["k"] == "shake": continue
            k = p["k"]
            if k == "chip":
                if a > p["life"]: continue
                g = 300; a1 = 2 * p["vz"] / g
                if a < a1: z = p["z"] * (1 - a / a1) + p["vz"] * a - .5 * g * a * a; x = p["vx"] * a
                else:
                    a2 = a - a1; v2 = .38 * p["vz"]; z = max(0, v2 * a2 - .5 * g * a2 * a2); x = p["vx"] * a1 + .3 * p["vx"] * a2
                al = 1 - clamp01((a - p["life"] + .25) / .25)
                rect(cv, round(p["x"] + x), round(p["y"] - max(z, 0)), p["w"], p["h"], p["col"], al)
            elif k == "leaf":
                if a > p["life"]: continue
                x = p["x"] + p["vx"] * a + p["A"] * math.sin(2 * math.pi * p["f"] * a + p["ph"])
                y = min(p["y"] + p["vy"] * a + .5 * p["g"] * a * a, GY + 10 + p["ph"])
                al = 1 - clamp01((a - p["life"] + .3) / .3)
                rect(cv, round(x), round(y), p["w"], p["h"], p["col"], al)
            elif k == "dust":
                if a > p["life"]: continue
                u = a / p["life"]; r = p["r0"] + (p["r1"] - p["r0"]) * ease_out(u)
                cx, cy = p["x"] + p["vx"] * a, p["y"] - 4 * u
                ri = int(round(r))
                for yy in range(-ri, ri + 1):
                    for xx in range(-ri, ri + 1):
                        if xx * xx + yy * yy <= r * r + .3:
                            rect(cv, round(cx) + xx, round(cy) + yy, 1, 1, (228, 218, 190), .6 * (1 - u))
            elif k == "spark":
                if a > p["life"]: continue
                x, y = p["x"] + p["vx"] * a, p["y"] + p["vy"] * a
                rect(cv, round(x), round(y), 1, 1, (150, 90, 55)); rect(cv, round(x - p["vx"] * .012), round(y - p["vy"] * .012), 1, 1, (150, 90, 55))
            elif k == "log":
                logs.append((p, a))
        for p, a in logs:
            u = clamp01(a / .4)
            x = p["x"] + (p["xt"] - p["x"]) * ease_out(u); y = p["y"] + (p["yt"] - p["y"]) * u
            z = p["hop"] * 4 * u * (1 - u) if a < .4 else 0
            if .4 <= a < .6: z = p["hop"] * .3 * 4 * ((a - .4) / .2) * (1 - (a - .4) / .2)
            lx, ly = round(x) - 3, round(y - z) - 1
            rect(cv, lx, ly, 7, 3, (120, 76, 48)); rect(cv, lx, ly, 7, 1, (160, 104, 66)); rect(cv, lx + 6, ly, 1, 3, (214, 160, 100))
            rect(cv, lx, ly + 2, 7, 1, (84, 50, 34))
        return cv.astype(np.uint8), self.shake_px(te)

# ---------------------------------------------------------------- variants
def hits3(): return [(.4, 1), (1.1, 1), (1.8, 1)]
def mk_cur(): return Panel("0", "CURRENT (what the game does now)", hits3(), motion="slide", flash=.08, freeze=1, trauma=.05, sparks=5, sound="clang")
def mk_A(i):
    n = ["Sway from foot", "Sway + squash", "Shake (Stardew-like)"][i - 1]
    return Panel(f"A{i}", n, hits3(), motion=["sway", "swaysq", "shake"][i - 1], flash=.05, freeze=2, trauma=.05)
def mk_D(i):
    n = ["Wood chips", "Chips + leaves", "Chips + leaves + dust"][i - 1]
    return Panel(f"D{i}", n, hits3(), motion="sway", chips=5, leaves=0 if i == 1 else 3, dust=i == 3)
def mk_S(i):
    n = ['Soft "tok"', 'Deep "thunk"', 'Crisp "chock"'][i - 1]
    return Panel(f"S{i}", n, hits3(), motion="sway", chips=5, leaves=3, sound=["tok", "thunk", "chock"][i - 1])
def mk_B(i):
    hs = [(.4 + .7 * k, 1) for k in range(4)]
    if i == 1:
        return Panel("B1", "Same every hit", hs, chips=5, leaves=3, trauma=.08, fall="swap")
    hs = [(h, s) for (h, _), s in zip(hs, [1, 1.3, 1.6, 2.2])]
    return Panel("B2", "Gets bigger each hit", hs, chips=[5, 7, 9, 12], leaves=[3, 3, 4, 6], trauma=[.05, .1, .16, .3],
                 prog_pitch=.06, fall="swap")
def mk_C(i):
    n = ["Tip over", "Pop", "Fall + roll"][i - 1]
    return Panel(f"C{i}", n, [(.4, 1.6)], trauma=.2, flash=.05, fall=["tip", "pop", "roll"][i - 1])

# ---------------------------------------------------------------- timeline
def seg(t0, t1, speed=1.0, active=None, audio=None, tag=""):
    return dict(t0=t0, t1=t1, speed=speed, active=active, audio=audio, tag=tag)

def loops(end=3.0, slow=(.95, 1.75), audio=None, active=None, slow_too=True):
    s = [seg(0, end, 1, active, audio)]
    if slow_too: s.append(seg(slow[0], slow[1], .25, active, audio, "SLOW 0.25x"))
    return s

SECTIONS = [
    dict(code="0", title="CURRENT (baseline)", sub="what the game does now", panels=[mk_cur()],
         segs=loops(3.0, audio=0), cap="Whole tree slides 3px, white flash 0.08s, 1-frame freeze, shake 0.05, 5 brown sparks. Sound: clang.", still=(0, .46)),
    dict(code="A", title="HIT REACTION", sub="motion only, no particles", panels=[mk_A(1), mk_A(2), mk_A(3)],
         segs=loops(3.0, audio=0), cap="All: flash 0.05s, 2-frame freeze, shake 0.05. Sound is the same on all panels.", still=(0, .5)),
    dict(code="D", title="DEBRIS", sub="all use A1 motion", panels=[mk_D(1), mk_D(2), mk_D(3)],
         segs=loops(3.0, slow=(.95, 1.9), audio=0), cap="Chips hop with fake gravity and bounce once. Leaves drift 1.2s. Dust puff at the trunk.", still=(0, .65)),
    dict(code="S", title="SOUND", sub="one after another, same visual (A1 + D2)", panels=[mk_S(1), mk_S(2), mk_S(3)],
         segs=[seg(0, 2.6, 1, [i], i, f"S{i+1} playing") for i in range(3)], cap="Each hit has random pitch +-5%. Dimmed panels are silent.", still=(1, .55)),
    dict(code="B", title="PROGRESS", sub="4 hits to break (A1 + D2 + S2)", panels=[mk_B(1), mk_B(2)],
         segs=[seg(0, 3.7, 1, None, 0, "audio: B1"), seg(0, 3.7, 1, None, 1, "audio: B2"), seg(2.0, 3.2, .25, None, 1, "SLOW 0.25x")],
         cap="B2: each hit sway +30%, chips +2, pitch +6%, more shake. Last hit is clearly the biggest, then plain stump swap.", still=(1, 1.95)),
    dict(code="C", title="TREE FALL", sub="the breaking hit", panels=[mk_C(1), mk_C(2), mk_C(3)],
         segs=[seg(0, 3.4, 1, None, 0, "audio: C1"), seg(0, 3.4, 1, None, 1, "audio: C2"), seg(0, 3.4, 1, None, 2, "audio: C3"),
               seg(.3, 2.0, .25, None, 0, "SLOW 0.25x")],
         cap="C1 tip over (ease-in, squash bounce, dust, leaves, logs). C2 pop. C3 fall + slide then sink.", still=(0, 1.0)),
]
CAPTION_EXTRA = {"C": ["C1 and C3 use the same sounds: crack + thud"]}

# ---------------------------------------------------------------- frame drawing
def txt(d, xy, s, f, fill=(255, 255, 255), anchor="la", sw=4):
    d.text(xy, s, font=f, fill=fill, anchor=anchor, stroke_width=sw, stroke_fill=(15, 18, 22))

_label_cache = {}
def label_img(code, name, dim, audio):
    key = (code, name, dim, audio)
    if key not in _label_cache:
        im = Image.new("RGB", (PW, LBL), (28, 32, 40)); d = ImageDraw.Draw(im)
        col = (130, 130, 130) if dim else (255, 255, 255)
        txt(d, (12, LBL // 2), code, font(34), (255, 214, 90) if not dim else (120, 110, 80), "lm", 4)
        txt(d, (12 + 20 + len(code) * 24, LBL // 2), name, font(25), col, "lm", 3)
        if audio: txt(d, (PW - 10, LBL // 2), "♪", font(30), (120, 220, 255), "rm", 3)
        _label_cache[key] = im
    return _label_cache[key]

def panel_x(n):
    gap = 24 if n == 3 else 60
    tot = n * PW + (n - 1) * gap
    x0 = (VW - tot) // 2
    return [x0 + i * (PW + gap) for i in range(n)]

def title_card(sec):
    im = Image.new("RGB", (VW, VH), (22, 26, 34)); d = ImageDraw.Draw(im)
    txt(d, (VW // 2, 230), sec["code"] + "   " + sec["title"], font(78), (255, 214, 90), "mm", 6)
    txt(d, (VW // 2, 310), sec["sub"], font(34), (230, 230, 230), "mm", 3)
    y = 400
    for p in sec["panels"]:
        txt(d, (VW // 2, y), f"{p.code}   {p.name}", font(34), (255, 255, 255), "mm", 3); y += 50
    return np.array(im)

def frame(sec, sg, ts, ai):
    im = Image.new("RGB", (VW, VH), (22, 26, 34)); d = ImageDraw.Draw(im)
    txt(d, (24, HEAD // 2), sec["code"] + "  " + sec["title"], font(36), (255, 214, 90), "lm", 4)
    txt(d, (VW - 24, HEAD // 2), sec["sub"], font(22), (200, 200, 200), "rm", 3)
    n = len(sec["panels"])
    for i, (p, x) in enumerate(zip(sec["panels"], panel_x(n))):
        act = sg["active"] is None or i in sg["active"]
        w, (sx, sy) = p.render(ts if act else -1.0)
        up = np.repeat(np.repeat(w, S, 0), S, 1)
        if sx or sy: up = np.roll(up, (sy, sx), (0, 1))
        if not act: up = (up * .45).astype(np.uint8)
        im.paste(label_img(p.code, p.name, not act, sg["audio"] == i and sg["audio"] is not None), (x, HEAD))
        im.paste(Image.fromarray(up), (x, HEAD + LBL))
    txt(d, (24, VH - 78), sec["cap"], font(20), (220, 220, 220), "lm", 3)
    if sg["tag"]:
        slow = "SLOW" in sg["tag"]
        txt(d, (VW - 24, VH - 40), sg["tag"], font(34 if slow else 26), (255, 110, 90) if slow else (120, 220, 255), "rm", 4)
    else:
        txt(d, (VW - 24, VH - 40), "real speed", font(22), (150, 150, 150), "rm", 3)
    return np.array(im)

# ---------------------------------------------------------------- main
def main():
    plan = []   # (kind, sec, seg, t0 video seconds, n frames)
    tv = 0.0
    events = []   # (video time, sound, pitch)
    stills = {}
    for sec in SECTIONS:
        nf = int(1.5 * FPS); plan.append(("title", sec, None, tv, nf)); tv += nf / FPS
        for si, sg in enumerate(sec["segs"]):
            nf = int(round((sg["t1"] - sg["t0"]) / sg["speed"] * FPS)); plan.append(("seg", sec, sg, tv, nf))
            if sg["audio"] is not None:
                for ts, snd, pit in sec["panels"][sg["audio"]].audio:
                    if sg["t0"] <= ts < sg["t1"]: events.append((tv + (ts - sg["t0"]) / sg["speed"], snd, pit))
            if si == sec["still"][0]:
                stills[int(round((tv + (sec["still"][1] - sg["t0"]) / sg["speed"]) * FPS))] = sec["code"]
            tv += nf / FPS
        tv += .25
        plan.append(("gap", sec, None, tv - .25, int(.25 * FPS)))
    total = tv
    # audio
    buf = np.zeros(int((total + 1) * AR))
    for t, snd, pit in events:
        x = pitched(SND[snd], pit); i = int(t * AR); buf[i:i + len(x)] += x
    buf = buf / max(1, np.abs(buf).max() / .9)
    wav = TMP / "audio.wav"
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(AR); w.writeframes((buf * 32767).astype("<i2").tobytes())
    STILLS.mkdir(exist_ok=True)
    ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{VW}x{VH}", "-r", str(FPS),
                           "-i", "-", "-i", str(wav), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "18", "-c:a", "aac", "-b:a", "160k",
                           "-t", f"{total:.3f}", str(OUT_MP4)], stdin=subprocess.PIPE)
    fidx = 0
    last = None
    for kind, sec, sg, t0, nf in plan:
        if kind == "title":
            im = title_card(sec)
            for _ in range(nf): ff.stdin.write(im.tobytes()); fidx += 1
        elif kind == "gap":
            for _ in range(nf): ff.stdin.write(last.tobytes()); fidx += 1
        else:
            for k in range(nf):
                ts = sg["t0"] + k / FPS * sg["speed"]
                im = frame(sec, sg, ts, k)
                if fidx in stills: Image.fromarray(im).save(STILLS / f"{stills[fidx]}_{sec['title'].split()[0].lower()}.png")
                ff.stdin.write(im.tobytes()); fidx += 1; last = im
    ff.stdin.close(); ff.wait()
    print("wrote", OUT_MP4, f"{total:.1f}s", "frames", fidx)

if __name__ == "__main__":
    main()
