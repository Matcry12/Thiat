# RETIRED with the old map art (Floors_Tiles / Rocks / Water_tiles / Vegetation are in assets/retired/map/ and assets/source/map/). Kept as the reference of the GDScript ports (MapGen, BiomeVeg).
"""$0 generator (0038 step 4): the floor-prop sets the biome passes draw, as PropSet .tres files in data/maps/.
  prop_veg.tres    one set for assets/game/map/Vegetation.png (bushes, dead shrubs, flowers, foxglove, mushrooms, tufts, ferns, reeds)
  prop_rocks.tres  one set for assets/source/map/Rocks.png (boulders, small stones; grey and brown)
  prop_stump_<model>_s<size>.tres  snow-covered stumps, one per tree sheet in assets/game/world/trees/
Each set names its sprites in `groups` (name -> region indices) so MapGen never holds a coordinate. The crops are the ones of the approved
preview (tools/asset_viewer_retired/biome_looks.py). Re-run after changing the cut-outs; do not hand-edit the .tres.
Run: python3 tools/asset_viewer_retired/make_veg_sets.py"""
import json
from PIL import Image

from meadow_preview import ROOT, S, bbox

COLOR_COL = {"green": 0, "yellow": 3, "orange": 6, "red": 9}      # bush colour column (3 wide)
COLOR_ROW = {"green": 0, "yellow": 3, "brown": 6}                 # tuft / fern / reed row offset
ROCKS = {"big": (1, 18, 31, 63), "med": (34, 18, 62, 47), "boulder": [(64, 16, 80, 32), (80, 16, 96, 32)],
         "small": [(83, 36, 93, 44), (47, 50, 64, 62), (34, 52, 46, 61), (68, 53, 77, 61), (84, 53, 94, 61),
                   (80, 67, 93, 78), (67, 68, 77, 77), (51, 69, 60, 76), (36, 70, 44, 76), (35, 84, 45, 92),
                   (52, 85, 61, 93), (68, 85, 78, 93), (64, 99, 77, 110), (51, 100, 61, 109), (35, 101, 44, 108),
                   (20, 102, 28, 108)],
         "pebble": [(68, 37, 75, 42), (20, 70, 27, 75), (4, 71, 11, 75), (20, 85, 27, 90), (4, 87, 11, 91), (4, 102, 11, 107)]}


def r2(b):
    return "Rect2(%d, %d, %d, %d)" % (b[0], b[1], b[2] - b[0], b[3] - b[1])


def write(name, set_id, texture, regions, groups, any_ground=True):
    g = ", ".join('"%s": PackedInt32Array(%s)' % (k, ", ".join(map(str, v))) for k, v in groups.items())
    (ROOT / "data/maps" / name).write_text(f'''[gd_resource type="Resource" script_class="PropSet" format=3]

[ext_resource type="Script" path="res://scripts/map/prop_set.gd" id="1"]
[ext_resource type="Texture2D" path="res://{texture}" id="2"]

[resource]
script = ExtResource("1")
id = &"{set_id}"
texture = ExtResource("2")
regions = Array[Rect2]([{", ".join(r2(b) for b in regions)}])
groups = {{{g}}}
any_ground = {"true" if any_ground else "false"}
''')


def main():
    veg = Image.open(ROOT / "assets/game/map/Vegetation.png").convert("RGBA")
    regions, groups = [], {}

    def add(name, boxes):
        groups[name] = list(range(len(regions), len(regions) + len(boxes)))
        regions.extend(boxes)

    for c, col in COLOR_COL.items():
        add(f"bush_{c}", [bbox(veg, col, a, col + 3, b) for a, b in [(0, 2), (2, 4)]])
    add("deadbush", [bbox(veg, 12, a, 15, b) for a, b in [(4, 6), (6, 9)]])
    for i, row in enumerate((23, 24, 25, 26)):          # orange, white, blue, yellow
        add(f"flower_{i}", [bbox(veg, c, row, c + 1, row + 1) for c in range(3, 8)])
    add("foxglove", [bbox(veg, c, 10, c + 1, 12) for c in (12, 13, 14)])
    add("mushroom", [bbox(veg, c, 21, c + 1, 22) for c in range(4)])
    for col, o in COLOR_ROW.items():
        t = []
        for row in (9, 10, 11):
            for c in range(8):
                if row == 9 and 4 <= c <= 6:
                    continue
                if not veg.crop((c * S, (row + o) * S, c * S + S, (row + o) * S + S)).getbbox():
                    continue
                b = bbox(veg, c, row + o, c + 1, row + o + 1)
                if b[2] - b[0] <= 14 and b[3] - b[1] <= 14:
                    t.append(b)
        add(f"tuft_{col}", t)
        add(f"fern_{col}", [bbox(veg, 5, 11 + o, 6, 12 + o), bbox(veg, 6, 11 + o, 7, 12 + o), bbox(veg, 7, 10 + o, 8, 12 + o)])
        add(f"reed_{col}", [bbox(veg, c, 10 + o, c + 1, 12 + o) for c in (8, 9, 10)])
    write("prop_veg.tres", "veg", "assets/game/map/Vegetation.png", regions, groups)

    regions, groups = [], {}
    for col, ox in (("brown", 0), ("grey", 96)):
        sh = lambda b: (b[0] + ox, b[1], b[2] + ox, b[3])
        add(f"boulder_{col}", [sh(b) for b in ROCKS["boulder"]])
        add(f"stone_{col}", [sh(b) for b in ROCKS["small"] + ROCKS["pebble"]])
    write("prop_rocks.tres", "rocks", "assets/source/map/Rocks.png", regions, groups)

    cat = json.load(open(ROOT / "data/maps/tree_catalog.json"))
    names = {1: "oak", 2: "fir", 3: "pine"}
    for model, name in names.items():
        for size in (3, 4, 5):
            es = [e for e in cat if e["model"] == model and e["size"] == size and e["stage"] == "stump" and e["season"] == "snow"]
            if es:
                boxes = [(e["rect"][0], e["rect"][1], e["rect"][0] + e["rect"][2], e["rect"][1] + e["rect"][3]) for e in es]
                write(f"prop_stump_{name}_s{size}.tres", f"stump_{name}_s{size}", f"assets/game/world/trees/{name}_s{size}.png", boxes,
                      {"snow_stump": list(range(len(boxes)))})
    print("ok")


main()
