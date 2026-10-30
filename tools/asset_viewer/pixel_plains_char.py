"""Pixel Plains main character: store-preview GIF -> per-animation strips + preview ($0).

python3 tools/asset_viewer/pixel_plains_char.py <q74igv.gif> <out_dir> [--preview <dir>]
GIF: SnowHex store preview, 406x248, 4x scale, 6 sprites side by side on a grey checkerboard.
Writes <name>.png (horizontal strip, fixed cell) + anims.json (frame ms) per sprite.
"""
import json, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageSequence

SCALE, OX, OY = 4, 1, 3          # native pixel grid inside the GIF
CHECKER = ((192, 192, 192), (128, 128, 128))
# name: (x0, x1, y0, y1) in native px; boxes found by connected components over all frames
BOXES = {
    "run":       (14, 26, 16, 33),
    "roll_spot": (28, 44, 16, 33),   # lies down + bounces in place (unclear: ask user)
    "roll_move": (14, 44, 33, 49),   # stands, rolls left, gets up (bakes its own travel)
    "idle":      (46, 58, 16, 33),
    "hurt":      (62, 74, 16, 33),
    "side":      (78, 90, 16, 33),   # one still frame, side view (unclear: ask user)
}


def load(path):
    fr, ms = [], []
    for f in ImageSequence.Iterator(Image.open(path)):
        a = np.array(f.convert("RGBA"))[OY::SCALE, OX::SCALE].copy()
        bg = np.zeros(a.shape[:2], bool)
        for c in CHECKER:
            bg |= (a[..., :3] == c).all(-1)
        a[bg] = 0
        fr.append(a); ms.append(f.info.get("duration", 66))
    return np.stack(fr), ms


def loop(frames, ms):
    """Collapse held frames into runs, cut the GIF into cycles, keep the most complete cycle.

    The GIF samples the source at ~15 fps, so a short frame is sometimes skipped in one cycle.
    Cycles are cut at the longest-held frame (never skipped); the cycle with the most distinct
    frames wins and is rotated to start where the GIF starts.
    """
    runs = []
    for f, d in zip(frames, ms):
        k = f.tobytes()
        if runs and runs[-1][0] == k: runs[-1][2] += d
        else: runs.append([k, f, d])
    if len({r[0] for r in runs}) == 1:
        return [(runs[0][1], 0)]                    # still pose: one frame, 0 = no change
    inner = runs[1:-1]                              # first + last runs are cut by the GIF ends
    hold = {}
    for k, _, d in inner: hold.setdefault(k, []).append(d)
    K = max(hold, key=lambda k: sum(hold[k]) / len(hold[k]))
    cut = [i for i, r in enumerate(inner) if r[0] == K]
    cycles = [inner[a:b] for a, b in zip(cut, cut[1:])]
    best = max(cycles, key=lambda c: len({r[0] for r in c}))
    keys = [r[0] for r in best]
    i = keys.index(runs[0][0]) if runs[0][0] in keys else 0
    best = best[i:] + best[:i]
    avg = lambda k: round(sum(hold[k]) / len(hold[k]))
    # ponytail: hold of the cut frame is averaged, the rest keep this cycle's jittered (+-1 GIF frame) ms
    return [(f, avg(k) if k == K else d) for k, f, d in best]


def main(src, out, prev=None):
    frames, ms = load(src)
    out = Path(out); out.mkdir(parents=True, exist_ok=True); meta = {}
    for name, (x0, x1, y0, y1) in BOXES.items():
        cyc = loop(frames[:, y0:y1, x0:x1], ms)
        w, h = x1 - x0, y1 - y0
        strip = Image.new("RGBA", (w * len(cyc), h))
        for i, (f, _) in enumerate(cyc): strip.paste(Image.fromarray(f), (i * w, 0))
        strip.save(out / f"{name}.png")
        meta[name] = {"cell": [w, h], "frame_ms": [d for _, d in cyc]}
        print(f"{name:10} {len(cyc)} frames {w}x{h}  ms {meta[name]['frame_ms']}  loop {sum(meta[name]['frame_ms'])} ms")
    (out / "anims.json").write_text(json.dumps(meta, indent=1))
    if prev: preview(out, meta, Path(prev))


def preview(out, meta, prev, z=8, bg=(104, 160, 88, 255)):
    prev.mkdir(parents=True, exist_ok=True)
    strips = {n: Image.open(out / f"{n}.png") for n in meta}
    W = max(s.width + len(meta[n]["frame_ms"]) for n, s in strips.items()) * z + 16
    rows = [(n, s) for n, s in strips.items()]
    H = sum((s.height + 3) * z + 24 for _, s in rows)
    sheet = Image.new("RGBA", (W, H), bg); y = 0; dr = ImageDraw.Draw(sheet)
    for n, s in rows:
        w = meta[n]["cell"][0]; ms = meta[n]["frame_ms"]
        dr.text((8, y + 4), f"{n}  {len(ms)} frames  ms {ms}  loop {sum(ms)} ms", fill=(255, 255, 255), font_size=16)
        y += 24
        for i in range(len(meta[n]["frame_ms"])):
            cell = s.crop((i * w, 0, i * w + w, s.height)).resize((w * z, s.height * z), Image.NEAREST)
            sheet.alpha_composite(cell, (8 + i * (w + 1) * z, y))
        y += (s.height + 3) * z
    sheet.save(prev / "pixel_plains_char_sheet.png")
    # remade GIF: all anims side by side, 20 ms tick, each on its own clock
    tick, total = 20, 3000
    cells = [(n, s, meta[n]) for n, s in rows]
    gw = sum(m["cell"][0] + 2 for _, _, m in cells) * 4; gh = 17 * 4 * 2
    out_frames = []
    for t in range(0, total, tick):
        im = Image.new("RGBA", (gw, gh), bg); x = 0
        for n, s, m in cells:
            ms = m["frame_ms"]; tt = t % max(sum(ms), 1); i = 0
            while i < len(ms) - 1 and tt >= ms[i]: tt -= ms[i]; i += 1
            w, h = m["cell"]
            c = s.crop((i * w, 0, i * w + w, h)).resize((w * 4, h * 4), Image.NEAREST)
            im.alpha_composite(c, (x * 4, 8)); x += w + 2
        out_frames.append(im.convert("RGB"))
    out_frames[0].save(prev / "pixel_plains_char_remade.gif", save_all=True,
                       append_images=out_frames[1:], duration=tick, loop=0)


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], a[1], a[a.index("--preview") + 1] if "--preview" in a else None)
