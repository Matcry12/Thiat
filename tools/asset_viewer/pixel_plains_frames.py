"""Writes assets/characters/pixel_plains/frames.tres from the strips + anims.json (run from repo root, $0).
Timing = real ms from anims.json (speed 10 => duration = ms/100). Only 3 animations: idle, run, death (plain mode, flipped for left)."""
import json
D = "assets/characters/pixel_plains/"
A = json.load(open("assets/third_party/pixel_plains/character/anims.json"))
# anim -> (strip, loop, frame order or None = all in strip order)
# death = roll_move: stands (7), jumps (8, 9), falls + slides (0..5), lies (6); plays once, holds 6
ANIMS = [
    ("idle", "idle", True, None), ("run", "run", True, None),
    ("death", "roll_move", False, [7, 8, 9, 0, 1, 2, 3, 4, 5, 6]),
]
# roll_move cells are 30x16 with the standing pose at x 16..27: pad 12 px right + 1 px top so the
# standing frame is centred like idle (12x17) and the feet sit on the same row
MARGIN = {"roll_move": "Rect2(0, 1, 12, 1)"}
strips = sorted({s for _, s, _, _ in ANIMS})
out = ['[gd_resource type="SpriteFrames" format=3]\n']
for s in strips:
    out.append(f'[ext_resource type="Texture2D" path="res://{D}{s}.png" id="t_{s}"]')
out.append("")
anims = []
for name, s, loop, order in ANIMS:
    w, h = A[s]["cell"]
    ms = A[s]["frame_ms"]
    order = order or range(len(ms))
    fr = []
    for i in order:
        m = ms[i]
        sid = f"{name}_{i}"
        margin = f"margin = {MARGIN[s]}\n" if s in MARGIN else ""
        out.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("t_{s}")\nregion = Rect2({i*w}, 0, {w}, {h})\n{margin}filter_clip = true\n')
        fr.append('{\n"duration": %.2f,\n"texture": SubResource("%s")\n}' % (m / 100, sid))
    anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": 10.0\n}' % (", ".join(fr), str(loop).lower(), name))
out.append("[resource]\nanimations = [" + ", ".join(anims) + "]")
open(D + "frames.tres", "w").write("\n".join(out) + "\n")
