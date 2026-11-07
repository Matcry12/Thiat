#!/usr/bin/env python3
"""Add a weapon / tool from one PNG: icon + data/items + data/weapons + scenes/weapons model.
  python3 tools/add_weapon.py <picture.png> <id> [--kind sword|axe|pickaxe|hoe] [--scale N] [--flip] [--hands 1|2] [--name "X"] [--dry-run] [--no-import]
--hands 1 = one-handed (no OffHandGrip marker, the free hand stays on the body). Default 2.
The picture must be drawn pointing up (handle low). Handle = the LOWER end of the long axis (--flip swaps)."""
import argparse, math, re, shutil, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
# per kind: item category/colour, hitbox collision_mask, extra WeaponData lines (sword gets the block below)
KINDS = {
    "sword": dict(cat="weapon", col="0.7, 0.5, 0.3", mask=4),
    "axe": dict(cat="tool", col="0.85, 0.52, 0.34", mask=36, extra='gather_damage = 2.0\ntool_power = 1\ntool_kind = &"axe"', reach=64, cone=110),
    "pickaxe": dict(cat="tool", col="0.85, 0.52, 0.34", mask=36, extra='gather_damage = 2.0\ntool_power = 3\ntool_kind = &"pickaxe"', reach=56, cone=70),
    "hoe": dict(cat="tool", col="0.85, 0.52, 0.34", mask=36, extra='gather_damage = 1.0\ntool_power = 0\ntool_kind = &"hoe"', reach=56, cone=70),
}

def detect(png: Path, flip: bool):
    a = np.array(Image.open(png).convert("RGBA"))[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    pts = np.stack([xs, ys], 1).astype(float) + 0.5   # pixel centres
    c = pts.mean(0)
    w, v = np.linalg.eigh(np.cov((pts - c).T))
    ang = math.degrees(math.atan2(v[1, 1], v[0, 1]))   # long axis, picture coords (y down)
    proj = (pts - c) @ v[:, 1]
    lo, hi = pts[proj.argmin()], pts[proj.argmax()]
    handle, tip = (lo, hi) if lo[1] >= hi[1] else (hi, lo)   # handle = lower end
    if flip:
        handle, tip = tip, handle
    d = tip - handle
    snap = round(math.degrees(math.atan2(d[1], d[0])) / 45) * 45   # direction handle -> tip, nearest 45
    rot = -snap
    # handle pixel's corner-grid point goes to origin: offset = -handle (before rotation / scale)
    length = abs(proj.max() - proj.min()) + 1
    return dict(rot=rot, off=(-float(handle[0]), -float(handle[1])), length=float(length), handle=tuple(map(float, handle)), tip=tuple(map(float, tip)), axis=ang)

def tres_item(i, name, k):
    return f'''[gd_resource type="Resource" script_class="ItemData" load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/game/ui/items/{i}.png" id="icon"]
[ext_resource type="Resource" path="res://data/weapons/{i}.tres" id="w"]

[resource]
script = ExtResource("1")
id = &"{i}"
display_name = "{name}"
icon = ExtResource("icon")
color = Color({k["col"]}, 1)
category = "{k["cat"]}"
max_stack = 1
weapon = ExtResource("w")
'''

def tres_weapon(i, name, kind, k):
    if kind == "sword":
        return f'''[gd_resource type="Resource" script_class="WeaponData" format=3]

[ext_resource type="Script" path="res://scripts/weapons/weapon_data.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/weapons/{i}_model.tscn" id="2"]
[ext_resource type="PackedScene" path="res://scenes/skills/lunge_slash.tscn" id="3"]
[ext_resource type="Resource" path="res://data/swing_motions/sword_natural.tres" id="4"]

[resource]
script = ExtResource("1")
display_name = "{name}"
damage = 20.0
model = ExtResource("2")
rest_angle_degrees = -20.0
arc_degrees = 120.0
guard_forward = 6.0
guard_side = 15.0
skill = ExtResource("3")
step_distance = 8.0
swing_motion = ExtResource("4")
sweep_samples = 24
active = 0.2
recovery = 0.32
'''
    return f'''[gd_resource type="Resource" script_class="WeaponData" format=3]

[ext_resource type="Script" path="res://scripts/weapons/weapon_data.gd" id="1"]
[ext_resource type="Resource" path="res://data/swing_motions/tool_chop.tres" id="3"]
[ext_resource type="PackedScene" path="res://scenes/weapons/{i}_model.tscn" id="2"]

[resource]
script = ExtResource("1")
display_name = "{name}"
behavior = "arc"
damage = 10.0
{k["extra"]}
windup = 0.1
active = 0.08
recovery = 0.18
model = ExtResource("2")
swing_motion = ExtResource("3")
hit_follows_blade = true
tool_target_reach = {float(k["reach"])}
tool_target_cone_deg = {float(k["cone"])}
tool_target_hit_t = 0.6
arc_degrees = 60.0
sweep_samples = 12
step_distance = 4.0
parryable = true
'''

def tscn_model(i, k, f, scale, kind, hands=2):
    tip = round(f["length"] * scale, 1)
    hit = round(tip + 8, 1)
    sc = f"scale = Vector2({scale:g}, {scale:g})\n" if scale != 1 else ""
    return f'''[gd_scene format=3]

[ext_resource type="Texture2D" path="res://assets/game/ui/items/{i}.png" id="1"]
[ext_resource type="Script" path="res://scripts/components/hitbox.gd" id="2"]

[sub_resource type="RectangleShape2D" id="HitShape"]
size = Vector2({hit:g}, 9.562761)

[node name="{i.title().replace("_", "")}Model" type="Node2D"]

; RULE: origin (0,0) = the handle. Art's offset puts the handle pixel there; the blade runs along +x.
[node name="Art" type="Sprite2D" parent="."]
texture_filter = 1
rotation = {math.radians(f["rot"]):.7f}
{sc}texture = ExtResource("1")
centered = false
offset = Vector2({f["off"][0]:g}, {f["off"][1]:g})

[node name="Hitbox" type="Area2D" parent="."]
collision_layer = 8
collision_mask = {k["mask"]}
script = ExtResource("2")

[node name="CollisionShape2D" type="CollisionShape2D" parent="Hitbox"]
position = Vector2({hit / 2:g}, 0)
shape = SubResource("HitShape")

[node name="Tip" type="Marker2D" parent="."]
position = Vector2({tip:g}, 0)

; Drag me along the weapon: this is where the hand holds it.
[node name="MainHandGrip" type="Marker2D" parent="."]
gizmo_extents = 14.0
''' + ('' if hands == 1 else f'''
; Drag me along the weapon: this is where the free hand holds it. Delete me = one-handed.
[node name="OffHandGrip" type="Marker2D" parent="."]
position = Vector2({10 if kind == "sword" else 14}, 0)
gizmo_extents = 14.0
''')

def main():
    p = argparse.ArgumentParser()
    p.add_argument("png"); p.add_argument("id")
    p.add_argument("--kind", default="sword", choices=KINDS)
    p.add_argument("--scale", type=float, default=3.0)
    p.add_argument("--flip", action="store_true")
    p.add_argument("--hands", type=int, default=2, choices=[1, 2])
    p.add_argument("--name")
    p.add_argument("--dry-run", action="store_true")
    p.add_argument("--no-import", action="store_true")
    a = p.parse_args()
    i = a.id
    if not re.fullmatch(r"[a-z][a-z0-9]*(_[a-z0-9]+)*", i):
        sys.exit(f"id '{i}' is not snake_case")
    out = {"icon": ROOT / f"assets/game/ui/items/{i}.png", "item": ROOT / f"data/items/{i}.tres",
           "weapon": ROOT / f"data/weapons/{i}.tres", "model": ROOT / f"scenes/weapons/{i}_model.tscn"}
    taken = [str(f.relative_to(ROOT)) for f in out.values() if f.exists()]
    if taken and not a.dry_run:
        sys.exit(f"refusing, already exist: {taken}")
    f = detect(Path(a.png), a.flip)
    name = a.name or i.replace("_", " ").title()
    k = KINDS[a.kind]
    print(f"angle: art rotation {f['rot']} deg (long axis {f['axis']:.1f} deg in picture), offset {f['off']}")
    print(f"handle end pixel {f['handle']}, tip end pixel {f['tip']}  (handle = {'UPPER end, --flip' if a.flip else 'lower end'})")
    print(f"length in game: {f['length'] * a.scale:.0f} px (picture {f['length']:.0f} px x scale {a.scale:g})")
    if a.dry_run:
        return
    shutil.copyfile(a.png, out["icon"])
    out["item"].write_text(tres_item(i, name, k))
    out["weapon"].write_text(tres_weapon(i, name, a.kind, k))
    out["model"].write_text(tscn_model(i, k, f, a.scale, a.kind, a.hands))
    print("made:", *[str(v.relative_to(ROOT)) for v in out.values()], sep="\n  ")
    if not a.no_import:
        subprocess.run(["timeout", "120", "godot", "--headless", "--import"], cwd=ROOT, check=False)

main()
