"""Chibi knight (matches the player's big-head blob style), built in code, rigged, keyframed.
Run: blender --background --python tools/blender/make_test_chibi.py   ->  tools/blender/test_chibi.blend
Faces -Y at rotation 0 (toward the camera). Toon shading = Diffuse -> Shader to RGB -> constant ramp."""
import bpy, bmesh, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_chibi.blend")
bpy.ops.wm.read_factory_settings(use_empty=True)
R = math.radians

def mat(name, rgb):
    """Toon material: 3 hard light bands (constant ramp on the diffuse term) times the base colour."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse"); diff.inputs["Color"].default_value = (1, 1, 1, 1)
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, (0.52, 0.52, 0.62, 1)     # shadow band (cool)
    el[1].position, el[1].color = 0.3, (0.82, 0.82, 0.86, 1)    # mid band
    e3 = el.new(0.62); e3.color = (1.05, 1.05, 1.05, 1)             # lit band (warm, slightly over 1)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs["B"].default_value = (*rgb, 1)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    L = nt.links.new
    L(diff.outputs["BSDF"], s2r.inputs["Shader"]); L(s2r.outputs["Color"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], mix.inputs["A"]); L(mix.outputs["Result"], emit.inputs["Color"])
    L(emit.outputs["Emission"], out.inputs["Surface"])
    m.diffuse_color = (*rgb, 1)
    return m

M = {k: mat(k, v) for k, v in {
    "skin": (0.92, 0.55, 0.52),     # player's pink
    "steel": (0.50, 0.60, 0.88),
    "tunic": (0.20, 0.30, 0.78),    # player's blue shorts
    "boot": (0.42, 0.22, 0.10),
    "red": (0.95, 0.12, 0.14),
    "gold": (1.0, 0.72, 0.08),
    "blade": (0.86, 0.92, 1.0),
    "eye": (0.03, 0.02, 0.05),
    "mouth": (0.80, 0.22, 0.25),
    "smear": (0.9, 0.95, 1.0),
}.items()}

arm = bpy.data.armatures.new("ChibiRig")
rig = bpy.data.objects.new("Chibi", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name); b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm.edit_bones[parent]
bone("hips", (0, 0, .3), (0, 0, .4))
bone("torso", (0, 0, .4), (0, 0, .75), "hips")
bone("head", (0, 0, .75), (0, 0, 1.6), "torso")
bone("arm_R", (-.42, 0, .66), (-.42, 0, .38), "torso")      # sword arm (his right = -X)
bone("arm_L", (.34, 0, .66), (.34, 0, .38), "torso")
bone("smear", (-.42, 0, .66), (-.42, 0, .5), "arm_R")
bone("leg_R", (-.13, 0, .3), (-.13, 0, .02), "hips")
bone("leg_L", (.13, 0, .3), (.13, 0, .02), "hips")
bpy.ops.object.mode_set(mode="OBJECT")

def finish(o, material, bone_name, smooth=True):
    o.data.materials.append(M[material])
    if smooth: bpy.ops.object.shade_smooth()
    vg = o.vertex_groups.new(name=bone_name)
    vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    o.parent = rig
    o.modifiers.new("Armature", "ARMATURE").object = rig
    return o

def ball(name, c, size, material, bn, seg=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(location=c, segments=seg, ring_count=rings)
    o = bpy.context.active_object; o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    return finish(o, material, bn)

def rbox(name, c, size, material, bn, bevel=.04, smooth=True):
    bpy.ops.mesh.primitive_cube_add(location=c)
    o = bpy.context.active_object; o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bm = o.modifiers.new("b", "BEVEL"); bm.width = bevel; bm.segments = 2
        bpy.ops.object.modifier_apply(modifier="b")
    return finish(o, material, bn, smooth)

# --- big round head (skin) + steel cap + crest + face ---
ball("head", (0, 0, 1.12), (1.12, 1.0, .96), "skin", "head")
ball("cap", (0, .2, 1.46), (1.14, .86, .5), "steel", "head")
ball("crest", (0, .2, 1.68), (.14, .6, .2), "red", "head")
ball("eye_L", (.22, -.46, 1.14), (.15, .08, .24), "eye", "head", 8, 6)
ball("eye_R", (-.22, -.46, 1.14), (.15, .08, .24), "eye", "head", 8, 6)
ball("mouth", (0, -.47, .93), (.2, .06, .08), "mouth", "head", 8, 6)
# --- stubby body, legs, arms ---
ball("body", (0, 0, .52), (.62, .5, .46), "tunic", "torso")
rbox("belt", (0, 0, .43), (.64, .52, .09), "gold", "hips", .03)
for s, x, bn in (("R", -.13, "leg_R"), ("L", .13, "leg_L")):
    ball(f"leg_{s}", (x, 0, .2), (.2, .22, .3), "skin", bn, 12, 8)
    ball(f"boot_{s}", (x, -.04, .08), (.24, .34, .17), "boot", bn, 12, 8)
for s, x, bn in (("R", -.42, "arm_R"), ("L", .34, "arm_L")):
    ball(f"arm_{s}", (x, 0, .56), (.2, .2, .34), "steel", bn, 12, 8)
    ball(f"hand_{s}", (x, 0, .4), (.17, .17, .17), "skin", bn, 12, 8)
# --- sword in right hand: thick bright blade pointing -Y at rest ---
rbox("grip", (-.42, -.06, .4), (.09, .22, .09), "boot", "arm_R", .02)
rbox("guard", (-.42, -.19, .4), (.1, .08, .38), "gold", "arm_R", .02)
rbox("blade", (-.42, -.72, .4), (.12, 1.0, .26), "blade", "arm_R", .02, False)
rbox("tip", (-.42, -1.26, .4), (.1, .12, .12), "blade", "arm_R", .03, False)

# --- smear: pale crescent that trails the blade (shown on the fast frames only, via bone scale) ---
SMEAR_SPAN, SMEAR_R0, SMEAR_R1 = 62, .7, 1.25
bm = bmesh.new()
steps = 10
pivot = Vector((-.42, 0, .44))
for i in range(steps + 1):
    a = R(SMEAR_SPAN) * i / steps          # 0 = along the blade, grows toward the trailing side (+X side)
    d = Vector((math.sin(a), -math.cos(a), 0))
    taper = 1.0 - .75 * i / steps          # fades to a thin tail
    bm.verts.new(pivot + d * SMEAR_R0); bm.verts.new(pivot + d * (SMEAR_R0 + (SMEAR_R1 - SMEAR_R0) * taper))
bm.verts.ensure_lookup_table()
for i in range(steps):
    bm.faces.new((bm.verts[2*i], bm.verts[2*i+1], bm.verts[2*i+3], bm.verts[2*i+2]))
me = bpy.data.meshes.new("smear"); bm.to_mesh(me)
so = bpy.data.objects.new("smear", me); bpy.context.scene.collection.objects.link(so)
bpy.context.view_layer.objects.active = so; so.select_set(True)
for p in me.polygons: p.use_smooth = False
finish(so, "smear", "smear", False)
# double sided
so.data.materials[0].use_backface_culling = False

# --- animations ---
rig.animation_data_create()
for pb in rig.pose.bones: pb.rotation_mode = "XYZ"
def pose(pb, rot): pb.rotation_euler = tuple(R(a) for a in rot)

def action(name, n, fn):
    act = bpy.data.actions.new(name); rig.animation_data.action = act
    for i in range(n):
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        rig.pose.bones["smear"].scale = (.001, .001, .001)
        fn(i, n, rig.pose.bones)
        for pb in rig.pose.bones:
            for prop in ("rotation_euler", "location", "scale"): pb.keyframe_insert(prop, frame=i + 1)
    act.use_fake_user = True

READY = -65
def idle(i, n, P):
    t = math.sin(2 * math.pi * i / n)
    P["hips"].location = (0, 0, .025 * t)
    pose(P["arm_R"], (READY + 4 * t, 0, 0)); pose(P["arm_L"], (-6 - 4 * t, 0, 0))
    P["head"].location = (0, 0, .01 * t)

def run(i, n, P):
    p = 2 * math.pi * i / n; s = math.sin(p)
    P["hips"].location = (0, 0, .14 * abs(math.cos(p)) - .07)
    pose(P["torso"], (-8, 0, 6 * s)); pose(P["head"], (4, 0, -8 * s)); P["head"].rotation_euler[1] = R(7 * s)
    pose(P["leg_R"], (50 * s, 0, 0)); pose(P["leg_L"], (-50 * s, 0, 0))
    pose(P["arm_R"], (-40 - 15 * s, 0, 0)); pose(P["arm_L"], (-5 + 45 * s, 0, 0))

# slash: arm pitch X lifts the blade, arm Y-rotation (vertical axis) sweeps it flat across the front.
SW = 1.0   # +1/-1 flips sweep direction (checked visually)
def slash(i, n, P):
    phi = [0, 105, 135, -5, -135, -75][i] * SW        # sword azimuth about the shoulder
    tilt = [-65, -70, -75, -45, -35, -50][i]           # blade pitch
    twist = [0, 28, 40, -10, -40, -20][i] * SW
    squat = [0, -.04, -.07, -.05, -.02, 0][i]
    P["hips"].location = (0, 0, squat)
    pose(P["torso"], ([0, 4, 6, -8, -6, 0][i], twist * .0, 0))
    P["torso"].rotation_euler[1] = R(twist)
    P["arm_R"].rotation_euler = (R(tilt), R(phi), 0)
    pose(P["arm_L"], (-6 - [0, 15, 20, 25, 10, 0][i], 0, 0))
    P["head"].rotation_euler = (0, R(-twist * .4), 0)
    pose(P["leg_R"], ([0, 8, 14, -12, -14, 0][i], 0, 0)); pose(P["leg_L"], ([0, -8, -14, 12, 14, 0][i], 0, 0))
    k = 1.0 if i in (3, 4) else .001
    P["smear"].scale = (k, k, k)

action("idle", 4, idle); action("run", 8, run); action("slash", 6, slash)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
