#!/usr/bin/env python3
"""Add plain items (no weapon) from artist art: icon + data/items/<id>.tres. Weapons: add_weapon.py.
  python3 tools/add_items.py [assets/source/artist_inbox/intake.csv] [--dry-run] [--force] [--no-import]
CSV columns: file,id,name,category,stack,color   (file relative to the csv folder; color "r,g,b" 0..1, empty = average icon colour)"""
import argparse, csv, re, shutil, subprocess, sys
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CATS = ("material", "tool", "weapon", "placeable")

def tres(i, name, cat, stack, col):
    return f'''[gd_resource type="Resource" script_class="ItemData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/items/item_data.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/game/ui/items/{i}.png" id="icon"]

[resource]
script = ExtResource("1")
id = &"{i}"
display_name = "{name}"
icon = ExtResource("icon")
color = Color({col}, 1)
category = "{cat}"
max_stack = {stack}
'''

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("csv", nargs="?", default="assets/source/artist_inbox/intake.csv")
    ap.add_argument("--dry-run", action="store_true"); ap.add_argument("--force", action="store_true"); ap.add_argument("--no-import", action="store_true")
    a = ap.parse_args()
    src = (ROOT / a.csv).resolve()
    added, skipped, errs, seen = 0, 0, [], set()
    for n, r in enumerate(csv.DictReader(src.open(newline="", encoding="utf-8")), 2):
        i = (r.get("id") or "").strip()
        try:
            f = src.parent / r["file"].strip()
            cat = (r.get("category") or "").strip() or "material"
            if not re.fullmatch(r"[a-z][a-z0-9_]*", i): raise ValueError("id not snake_case")
            if i in seen: raise ValueError("duplicate id in csv")
            seen.add(i)
            if not f.is_file(): raise ValueError(f"file not found: {f}")
            if cat not in CATS: raise ValueError(f"category {cat!r} not in {CATS}")
            im = Image.open(f).convert("RGBA"); px = np.array(im)
            if "A" not in Image.open(f).getbands(): raise ValueError("PNG has no alpha")
            col = (r.get("color") or "").strip()
            if col: col = ", ".join(str(float(x)) for x in col.split(","))
            else:
                m = px[:, :, 3] > 0
                if not m.any(): raise ValueError("icon fully transparent")
                col = ", ".join(f"{v:.2f}" for v in px[m][:, :3].mean(0) / 255)
            stack = int((r.get("stack") or "").strip() or 64)
            icon, out = ROOT / f"assets/game/ui/items/{i}.png", ROOT / f"data/items/{i}.tres"
            if out.exists() and not a.force: print(f"skip {i} (exists)"); skipped += 1; continue
            if icon.exists() and not a.force: raise ValueError(f"{icon.name} exists (use --force)")
            print(f"{'would add' if a.dry_run else 'add'} {i}: {cat} stack {stack} color {col}")
            if not a.dry_run:
                shutil.copyfile(f, icon); out.write_text(tres(i, (r.get("name") or "").strip() or i, cat, stack, col))
            added += 1
        except Exception as e:
            errs.append(f"row {n} ({i}): {e}"); print("ERROR", errs[-1])
    if added and not a.dry_run and not a.no_import:
        subprocess.run(["godot", "--headless", "--import"], cwd=ROOT, capture_output=True)
    print(f"added {added}, skipped {skipped}, errors {len(errs)}")
    print("next: tools/run_tests.sh tests/test_item_files_complete.gd tests/test_asset_rules.gd ; check in Test yard, book tab Items")
    sys.exit(1 if errs else 0)

main()
