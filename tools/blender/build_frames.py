"""Builds assets/game/characters/player/3d/player_3d_frames.tres (a SpriteFrames) from the rendered sheets + sheet_info.json.
Animations: <idle|run|hit>_<front|side>. Hold times (ms) become per-frame durations at speed 10 fps (duration 1.0 = 100 ms),
so SpriteActorVisual plays them as-is. Run by render_body.py; or: python3 tools/blender/build_frames.py"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "assets", "game", "characters", "player", "3d")
RES = "res://assets/game/characters/player/3d/"
LOOPS = {"idle": True, "run": True, "hit": False}

def build(out=OUT, name="player_3d_frames.tres", res=RES):
    info = json.load(open(os.path.join(out, "sheet_info.json")))
    cell, rows = info["cell"], info["rows"]                  # rows: S -> front, E -> side
    names = {"S": "front", "E": "side"}
    ext, sub, anims = [], [], []
    for ai, (act, d) in enumerate(info["actions"].items()):
        ext.append(f'[ext_resource type="Texture2D" path="{res}{act}.png" id="t_{act}"]')
        for r, row in enumerate(rows):
            frames = []
            for f in range(d["frames"]):
                sid = f"{act}_{names[row]}_{f}"
                sub.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("t_{act}")\nregion = Rect2({f * cell}, {r * cell}, {cell}, {cell})\n')
                frames.append('{\n"duration": %.2f,\n"texture": SubResource("%s")\n}' % (d["hold_ms"][f] / 100.0, sid))
            anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s_%s",\n"speed": 10.0\n}' % (", ".join(frames), str(LOOPS[act]).lower(), act, names[row]))
    text = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n[resource]\nanimations = [%s]\n' % (
        len(ext) + len(sub) + 1, "\n".join(ext), "\n".join(sub), ", ".join(anims))
    open(os.path.join(out, name), "w").write(text)
    print("wrote", name, ":", len(anims), "animations")

if __name__ == "__main__":
    build()
