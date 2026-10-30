"""$0: assets/map/pixel_plains/manifest.json -> game data. No coordinates live in GDScript.
  data/resource_nodes/treepp_oak_<season>_<age>.tres   gatherable oaks (MapGen._tree_kinds reads the id in Pixel Plains mode)
  data/maps/prop_pp_{flowers,tufts,hedges}.tres        PropSets for BiomeVeg; groups are "<role>@<biome label>" (from manifest biome lists)
  data/maps/grass.tres                                 gets the new nodes / sets appended (idempotent: old pp_ entries are dropped first)
  data/maps/ground_pixel_plains.tres                   show_* per-biome switches (from by_biome / no_art)
Run: python3 tools/art_tests/recolour_game/export_game_data.py"""
import json, os, re
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
M = json.load(open(os.path.join(ROOT, "assets/map/pixel_plains/manifest.json")))
S = M["sprites"]
BIOMES = ["plains", "forest", "autumn", "taiga", "snowy", "rocky", "swamp", "beach_sand", "beach_gravel"]   # MapStyle.biomes order
LABEL = {b: {"beach_sand": "beach (sand)", "beach_gravel": "beach (gravel)"}.get(b, b) for b in BIOMES}
DARK = {"forest", "taiga", "swamp"}            # PixelPlainsGround.dark_biomes: tufts are drawn for the grass they stand on
PX = 2                                          # screen px per art px (ResourceNodeData.pixel_scale)
AGES = ["sapling", "young", "small", "mature", "old"]   # MapGen.AGES
STATS = {"sapling": (2, 1, 1), "young": (4, 1, 2), "small": (6, 2, 3), "mature": (9, 3, 4), "old": (14, 5, 7)}   # = the old oaks
SEASON = {"green": "green", "yellow": "yellow", "autumn_orange": "orange", "red": "red", "snow": "snow"}   # variant -> BiomeData.SEASONS
rect = lambda r: "Rect2(%d, %d, %d, %d)" % tuple(r)
vec = lambda a: "%g, %g" % tuple(a)

def write(path, text):
    open(os.path.join(ROOT, path), "w").write(text)

new = {"nodes": [], "sets": []}
# ---- oaks (a chopped one leaves the manifest's stump, which lives on another sheet: remains_texture)
STUMP = next(s for s in S if s["kind"] == "stump")
for var, season in SEASON.items():
    for age in ["sapling", "young", "mature", "old"]:   # no "small" in the pack: MapGen._tree_node falls back to the nearest age
        sp = [s for s in S if s["kind"] == "oak" and s["variant"] == var and s["age"] == age]
        hp, dmin, dmax = STATS[age]
        nid = "treepp_oak_%s_%s" % (season, age)
        write("data/resource_nodes/%s.tres" % nid, f'''[gd_resource type="Resource" script_class="ResourceNodeData" format=3]

[ext_resource type="Script" path="res://scripts/world/resource_node_data.gd" id="1"]
[ext_resource type="Resource" path="res://data/items/wood.tres" id="2"]
[ext_resource type="Texture2D" path="res://assets/map/pixel_plains/oaks.png" id="3"]
[ext_resource type="Texture2D" path="res://assets/map/pixel_plains/{STUMP["file"]}" id="4"]

[resource]
script = ExtResource("1")
id = &"{nid}"
display_name = "Tree (Oak)"
max_hp = {hp}.0
preferred_tool = &"axe"
required_power = 0
drop_item = ExtResource("2")
drop_min = {dmin}
drop_max = {dmax}
radius = {sp[0]["collision_radius"] * PX}.0
texture = ExtResource("3")
regions = Array[Rect2]([{", ".join(rect(s["region"]) for s in sp)}])
anchors = PackedVector2Array({", ".join(vec(s["anchor"]) for s in sp)})
remains_region = {rect(STUMP["region"])}
remains_texture = ExtResource("4")
pixel_scale = {PX}
fade_when_behind = true
color = Color(0.25, 0.55, 0.25, 1)
hit_type = &"chop"
''')
        new["nodes"].append(nid)

# ---- PropSets. region = the sprite's ink box (the foot sits on the bottom of the ink, not of the 16 px cell)
def ink(s):
    r = s["region"]
    if "ink" not in s: return r
    i = s["ink"]
    return [r[0] + i[0], r[1] + i[1], i[2], i[3]]

def propset(name, sheet, rows):
    """rows: (sprite, [group names]); groups = group -> indices."""
    regs, groups = [], {}
    for s, names in rows:
        regs.append(ink(s))
        for n in names: groups.setdefault(n, []).append(len(regs) - 1)
    g = ", ".join('"%s": PackedInt32Array(%s)' % (k, ", ".join(map(str, v))) for k, v in sorted(groups.items()))
    write("data/maps/prop_pp_%s.tres" % name, f'''[gd_resource type="Resource" script_class="PropSet" format=3]

[ext_resource type="Script" path="res://scripts/map/prop_set.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/map/pixel_plains/{sheet}" id="2"]

[resource]
script = ExtResource("1")
id = &"pp_{name}"
texture = ExtResource("2")
regions = Array[Rect2]([{", ".join(rect(r) for r in regs)}])
groups = {{{g}}}
any_ground = true
''')
    new["sets"].append("prop_pp_" + name)

FLOWER_ROLE = {"orange": "flower_0", "pink": "flower_1", "mint": "flower_1", "blue": "flower_2", "yellow": "flower_3"}   # BiomeVeg.FLOWER slots
rows = [(s, ["%s@%s" % (FLOWER_ROLE[s["variant"]], LABEL[b]) for b in s["biome"]]) for s in S if s["kind"] == "flower"]
propset("flowers", "flowers.png", rows)
TUFT_ROLE = {"green": "tuft_green", "yellow": "tuft_yellow", "brown": "tuft_brown", "snow": "tuft_green"}   # BiomeVeg.TUFT slots (snow = the green slot of snowy / taiga)
rows = [(s, ["%s@%s" % (TUFT_ROLE[s["variant"]], LABEL[b]) for b in s["biome"] if (s["on"] == "dark") == (b in DARK)]) for s in S if s["kind"] == "tuft"]
propset("tufts", "tufts.png", [r for r in rows if r[1]])
HEDGE_ROLE = {"green": "bush_green", "yellow": "bush_yellow", "autumn_orange": "bush_orange", "red": "bush_red"}   # BiomeVeg.BUSH slots
# only the one-cell pieces (caps) stand in for bushes; long walls / frames / posts need a placing rule of their own (not built)
rows = [(s, ["%s@%s" % (HEDGE_ROLE[s["variant"]], LABEL[b]) for b in s["biome"]]) for s in S if s["kind"] == "hedge" and s.get("piece", "").startswith("cap")]
propset("hedges", "hedges.png", rows)

# ---- per-biome switches (1 = the pack has art for it there)
def shown(kind): return [1 if M["by_biome"][b].get(kind, 0) > 0 else 0 for b in BIOMES]
sw = {"show_trees": shown("oak"), "show_flowers": shown("flower"), "show_tufts": shown("tuft"), "show_hedges": shown("hedge"), "show_other": [0] * len(BIOMES)}
SEASONS = ["green", "yellow", "orange", "red", "teal", "dead", "snow"]   # BiomeData.SEASONS
def fallback(b):   # the first oak colour the manifest made for this biome (-1 = none)
    for s in S:
        if s["kind"] == "oak" and b in s["biome"]: return SEASONS.index(SEASON[s["variant"]])
    return -1
sw["tree_fallback_season"] = [fallback(b) for b in BIOMES]
p = os.path.join(ROOT, "data/maps/ground_pixel_plains.tres")
t = open(p).read()
t = re.sub(r"^(show_\w+|tree_fallback_season) = .*\n", "", t, flags=re.M)
t = re.sub(r"^(hide_trees|hide_veg) = .*\n", "", t, flags=re.M)
t = t.replace("dark_dirt_gap = 1\n", "dark_dirt_gap = 1\n" + "".join("%s = PackedInt32Array(%s)\n" % (k, ", ".join(map(str, v))) for k, v in sw.items()))
open(p, "w").write(t)

# ---- grass.tres
p = os.path.join(ROOT, "data/maps/grass.tres")
t = open(p).read()
t = re.sub(r'^\[ext_resource [^\n]*id="pp_[^\n]*\n', "", t, flags=re.M)
t = re.sub(r', ExtResource\("pp_[^"]*"\)', "", t)
ext = "".join('[ext_resource type="Resource" path="res://data/%s/%s.tres" id="pp_%s"]\n' % ("resource_nodes" if n.startswith("treepp") else "maps", n, n) for n in new["nodes"] + new["sets"])
t = re.sub(r'(\[ext_resource [^\n]*\n)(?!\[ext_resource)', lambda m: m.group(1) + ext, t, count=1)
for key, ids in (("resource_nodes", new["nodes"]), ("deco", new["sets"])):
    t = re.sub(r"^(%s = Array\[[^\n]*\]\(\[.*?)\]\)$" % key, lambda m: m.group(1) + "".join(', ExtResource("pp_%s")' % i for i in ids) + "])", t, flags=re.M)
open(p, "w").write(t)
print("ok", len(new["nodes"]), "nodes", new["sets"], sw)
