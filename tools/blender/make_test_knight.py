"""Builds a low-poly blocky knight in code, rigs it with an armature, keyframes idle/run/slash.
Run: blender --background --python tools/blender/make_test_knight.py
Writes tools/blender/test_knight.blend. Character faces -Y (toward the camera at rotation 0)."""
import bpy, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_knight.blend")
bpy.ops.wm.read_factory_settings(use_empty=True)

# ---- materials (flat colours; Workbench shades them) ----
def mat(name, rgb):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.roughness = 1.0
    m.metallic = 0.0
    return m
M = {
    "steel": mat("steel", (0.70, 0.78, 0.95)),
    "dark": mat("dark", (0.38, 0.45, 0.68)),
    "gold": mat("gold", (1.0, 0.72, 0.05)),
    "red": mat("red", (0.95, 0.10, 0.12)),
    "leather": mat("leather", (0.50, 0.26, 0.10)),
    "blade": mat("blade", (0.92, 0.94, 0.98)),
    "blue": mat("blue", (0.10, 0.30, 0.95)),
    "visor": mat("visor", (0.06, 0.05, 0.09)),
}

# ---- armature ----
arm_data = bpy.data.armatures.new("KnightRig")
rig = bpy.data.objects.new("Knight", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm_data.edit_bones[parent]
    return b
bone("hips", (0, 0, .55), (0, 0, .65))
bone("torso", (0, 0, .65), (0, 0, 1.15), "hips")
bone("head", (0, 0, 1.15), (0, 0, 1.7), "torso")
bone("arm_R", (-.42, 0, 1.05), (-.42, 0, .6), "torso")   # sword arm (his right = -X)
bone("arm_L", (.42, 0, 1.05), (.42, 0, .6), "torso")     # shield arm
bone("cape", (0, .22, 1.1), (0, .25, .45), "torso")
bone("leg_R", (-.17, 0, .6), (-.17, 0, .05), "hips")
bone("leg_L", (.17, 0, .6), (.17, 0, .05), "hips")
bpy.ops.object.mode_set(mode="OBJECT")

def box(name, center, size, material, bone_name):
    bpy.ops.mesh.primitive_cube_add(location=center)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(M[material])
    vg = o.vertex_groups.new(name=bone_name)
    vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    o.parent = rig
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return o

# torso + belt + emblem
box("torso", (0, 0, .92), (.64, .4, .5), "steel", "torso")
box("belt", (0, 0, .68), (.64, .42, .1), "leather", "hips")
box("emblem", (0, -.21, .95), (.26, .03, .26), "gold", "torso")
# head / helmet
box("helmet", (0, 0, 1.44), (.66, .6, .56), "steel", "head")
box("visor", (0, -.31, 1.42), (.46, .03, .11), "visor", "head")
box("plume", (0, .02, 1.8), (.14, .5, .22), "red", "head")
# arms
for side, sx, bn in (("R", -.42, "arm_R"), ("L", .42, "arm_L")):
    box(f"pad_{side}", (sx, 0, 1.05), (.3, .3, .12), "dark", bn)
    box(f"arm_{side}", (sx, 0, .83), (.2, .2, .4), "steel", bn)
    box(f"hand_{side}", (sx, 0, .58), (.18, .18, .14), "leather", bn)
# sword in right hand (blade points -Y at rest)
box("grip", (-.42, -.06, .58), (.06, .2, .06), "leather", "arm_R")
box("guard", (-.42, -.18, .58), (.07, .07, .34), "gold", "arm_R")
box("blade", (-.42, -.68, .58), (.06, .95, .12), "blade", "arm_R")
# shield on left arm
box("shield", (.6, -.08, .85), (.09, .42, .56), "blue", "arm_L")
box("shield_boss", (.66, -.08, .85), (.05, .14, .14), "gold", "arm_L")
# cape
box("cape", (0, .27, .8), (.5, .06, .7), "red", "cape")
# legs
for side, sx, bn in (("R", -.17, "leg_R"), ("L", .17, "leg_L")):
    box(f"leg_{side}", (sx, 0, .34), (.24, .26, .5), "dark", bn)
    box(f"boot_{side}", (sx, -.04, .1), (.26, .36, .2), "leather", bn)

# ---- animations ----
rig.animation_data_create()
for pb in rig.pose.bones:
    pb.rotation_mode = "XYZ"
R = math.radians
REST = {"arm_R": -35, "arm_L": -8}   # sword arm held forward at ready, shield arm near the body

def pose(pb, rot=None, loc=None):
    if rot is not None: pb.rotation_euler = tuple(R(a) for a in rot)
    if loc is not None: pb.location = loc

def action(name, n, fn):
    act = bpy.data.actions.new(name)
    rig.animation_data.action = act
    for i in range(n):
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
        fn(i, n, rig.pose.bones)
        for pb in rig.pose.bones:
            pb.keyframe_insert("rotation_euler", frame=i + 1)
            pb.keyframe_insert("location", frame=i + 1)
    act.use_fake_user = True
    return act

def idle(i, n, P):
    t = math.sin(2 * math.pi * i / n)
    P["hips"].location = (0, 0, .03 * t)
    pose(P["arm_R"], (REST["arm_R"] + 3 * t, 0, 0)); pose(P["arm_L"], (REST["arm_L"] - 3 * t, 0, 0))
    pose(P["head"], (2 * t, 0, 0)); pose(P["cape"], (3 * t, 0, 0))

def run(i, n, P):
    p = 2 * math.pi * i / n
    s = math.sin(p)
    P["hips"].location = (0, 0, .07 * abs(math.cos(p)) - .04)
    pose(P["torso"], (-12, 0, 5 * s))              # lean into the run, twist
    pose(P["head"], (6, 0, -5 * s))
    pose(P["leg_R"], (45 * s, 0, 0)); pose(P["leg_L"], (-45 * s, 0, 0))
    pose(P["arm_R"], (-45 - 20 * s, 0, 0))          # sword arm stays forward, pumps a little
    pose(P["arm_L"], (-8 + 40 * s, 0, 0))
    pose(P["cape"], (20 + 12 * math.cos(p), 0, 0))

def slash(i, n, P):
    # keys: 0 ready, 1 wind-up (sword over shoulder), 2 strike, 3 strike end, 4-5 recover
    arm = [-35, -150, -80, 30, 10, -20][i]
    twist = [0, -22, 8, 30, 20, 8][i]
    lean = [0, 6, -10, -16, -8, -3][i]
    P["hips"].location = (0, 0, [0, -.04, -.08, -.1, -.05, 0][i])
    pose(P["torso"], (lean, 0, twist)); pose(P["arm_R"], (arm, 0, 0))
    pose(P["arm_L"], (REST["arm_L"] - [0, 20, 10, 20, 10, 0][i], 0, 0))
    pose(P["head"], (-lean / 2, 0, -twist / 2))
    pose(P["leg_R"], ([0, 10, -20, -28, -18, 0][i], 0, 0)); pose(P["leg_L"], ([0, -10, 20, 28, 18, 0][i], 0, 0))
    pose(P["cape"], ([3, 10, 35, 28, 15, 5][i], 0, 0))

action("idle", 4, idle)
action("run", 8, run)
action("slash", 6, slash)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
