"""Writes data/maps/ground_pixel_plains.tres from pixel_plains_tiles.py (the case table lives there; the game reads the .tres).
Run: python3 tools/asset_viewer/pixel_plains_export_tres.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixel_plains_tiles as pp

def v3(e):
    return "Vector3i(-1, 0, 0)" if e == "U" else "Vector3i(-2, 0, 0)" if e == "L" else "Vector3i(%d, %d, %d)" % e

def table(name):
    return "Array[Vector3i]([" + ", ".join(v3(e) for m in range(16) for e in pp._CASES[name][m]) + "])"

def v2(lst):
    return "Array[Vector2i]([" + ", ".join("Vector2i(%d, %d)" % c for c in lst) + "])"

q = pp.PLAIN_Q
out = f'''[gd_resource type="Resource" script_class="PixelPlainsGround" format=3]

[ext_resource type="Script" path="res://scripts/map/pixel_plains_ground.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/map/pixel_plains/tiles.png" id="2"]

[resource]
script = ExtResource("1")
texture = ExtResource("2")
ground_material = PackedInt32Array(-1, 0, 0, 1, 0, 3, 4)
dark_biomes = PackedInt32Array(0, 1, 0, 0, 0, 0, 0, 0, 0)
dark_dirt_gap = 0
hide_trees = true
hide_veg = true
layer_dirt = {pp.LAYER["dirt"]}
layer_light = {pp.LAYER["light"]}
layer_dark = {pp.LAYER["dark"]}
plain_dirt = {v2(pp.PLAIN["dirt"])}
plain_light = {v2(pp.PLAIN["light"])}
plain_dark = {v2(pp.PLAIN["dark"])}
variants_dirt = {v2(pp.VARIANTS["dirt"])}
variants_light = {v2(pp.VARIANTS["light"])}
variants_dark = {v2(pp.VARIANTS["dark"])}
plain_weight = 0.96   # v5: variant squares at ~1/4 of the preview share (pp.PLAIN_WEIGHT 0.85)
quarter_dirt = Vector3i{q["dirt"]}
quarter_light = Vector3i{q["light"]}
quarter_dark = Vector3i{q["dark"]}
table_light_on_dirt = {table("light_on_dirt")}
table_dark_on_light = {table("dark_on_light")}
'''
path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "data", "maps", "ground_pixel_plains.tres")
open(path, "w").write(out)
print("wrote", os.path.normpath(path))
