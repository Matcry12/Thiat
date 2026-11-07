"""$0 generator: data/resource_nodes/tree_{oak,fir,pine}[_season]_{sapling,young,small,mature,old}.tres from data/maps/tree_catalog.json.
One file per (model, season, age) that the catalog has (0038 step 4: seasons green, yellow, orange, red, teal, dead, snow). Green keeps the old
ids (tree_oak_old); other seasons are tree_oak_yellow_old ... Regions = every variant of that season and age; anchors = the catalog trunk_base
of each (trunk foot sits on the collision circle's bottom). Also copies the tree sheets we use into assets/game/world/trees/ (raw pack stays untouched).
Run: python3 tools/asset_viewer/make_tree_nodes.py   (re-run after the catalog changes; do not hand-edit the .tres, tune in F3)."""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parents[2]
AGES = {  # age -> (sheet size, catalog stage, trunk collision radius screen px, display name)
    "sapling": (2, "sapling", 5.0, "Sapling"), "young": (2, "young", 7.0, "Young tree"),
    "small": (3, "mature", 9.0, "Small tree"), "mature": (4, "mature", 12.0, "Tree"), "old": (5, "old", 16.0, "Old tree")}
# age -> (max_hp, drop_min, drop_max): starting values, tune in F3 (0036 / 0037 step 3: an old tree is a real job and a real pile of wood)
YIELD = {"sapling": (2, 1, 1), "young": (4, 1, 2), "small": (6, 2, 3), "mature": (9, 3, 4), "old": (14, 5, 7)}
STUMP_SEASON = {"snow": "snow", "teal": "moss"}   # every other season leaves a brown stump (dead -> brown); moss only exists on some sizes
MODELS = {"oak": 1, "fir": 2, "pine": 3}
SEASONS = ["green", "yellow", "orange", "red", "teal", "dead", "snow"]   # same order as BiomeData.SEASONS
cat = json.load(open(ROOT / "data/maps/tree_catalog.json"))
PACK = ROOT / "assets/source/third_party/pixel_crawler/Environment/Props/Static/Trees"
(ROOT / "assets/game/world/trees").mkdir(parents=True, exist_ok=True)
for name, model in MODELS.items():       # the sheets, copied once (Godot imports them on the next --import)
    for size in (2, 3, 4, 5):
        dst = ROOT / f"assets/game/world/trees/{name}_s{size}.png"
        if not dst.exists():
            shutil.copy(PACK / f"Model_0{model}/Size_0{size}.png", dst)
made = 0
for name, model in MODELS.items():
    for season in SEASONS:
        for age, (size, stage, radius, label) in AGES.items():
            es = [e for e in cat if e["model"] == model and e["size"] == size and e["stage"] == stage and e["season"] == season]
            if not es:
                continue
            regs = ", ".join("Rect2(%d, %d, %d, %d)" % tuple(e["rect"]) for e in es)
            anc = ", ".join("%d, %d" % tuple(e["trunk_base"]) for e in es)
            hp, dmin, dmax = YIELD[age]
            # the stump of this model on THIS sheet size (sapling / young use the size-2 sheet, which has no stump: they leave nothing)
            want = STUMP_SEASON.get(season, "brown")
            st = [e for e in cat if e["model"] == model and e["size"] == size and e["stage"] == "stump" and e["season"] == want and e["variant"] == "a"]
            st = st or [e for e in cat if e["model"] == model and e["size"] == size and e["stage"] == "stump" and e["season"] == "brown" and e["variant"] == "a"]
            remains = "remains_region = Rect2(%d, %d, %d, %d)\n" % tuple(st[0]["rect"]) if st else ""
            kind = name.capitalize()
            nid = f"tree_{name}_{age}" if season == "green" else f"tree_{name}_{season}_{age}"
            col = {"green": (0.25, 0.55, 0.25), "yellow": (0.8, 0.7, 0.2), "orange": (0.85, 0.5, 0.15), "red": (0.75, 0.25, 0.15), "teal": (0.2, 0.5, 0.5),
                   "dead": (0.4, 0.33, 0.25), "snow": (0.85, 0.9, 0.95)}[season]
            (ROOT / f"data/resource_nodes/{nid}.tres").write_text(f'''[gd_resource type="Resource" script_class="ResourceNodeData" format=3]

[ext_resource type="Script" path="res://scripts/world/resource_node_data.gd" id="1"]
[ext_resource type="Resource" path="res://data/items/wood.tres" id="2"]
[ext_resource type="Texture2D" path="res://assets/game/world/trees/{name}_s{size}.png" id="3"]

[resource]
script = ExtResource("1")
id = &"{nid}"
display_name = "{label} ({kind}{'' if season == 'green' else ', ' + season})"
max_hp = {hp}.0
preferred_tool = &"axe"
required_power = 0
drop_item = ExtResource("2")
drop_min = {dmin}
drop_max = {dmax}
radius = {radius}
texture = ExtResource("3")
regions = Array[Rect2]([{regs}])
anchors = PackedVector2Array({anc})
{remains}fade_when_behind = true
color = Color({col[0]}, {col[1]}, {col[2]}, 1)
hit_type = &"chop"
''')
            made += 1
print("tree nodes written:", made)
