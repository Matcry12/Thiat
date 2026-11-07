"""3D TWIN of the player sprite (pink round head + navy pants + black feet), built in code, rigged,
keyframed as hand-drawn-style key poses. Run: blender --background --python tools/blender/make_test_twin.py
-> tools/blender/test_twin.blend.   Faces -Y at rotation 0 (toward the camera).
Lighting is 2 flat bands (light + shadow), light from the top-right like the player sprite."""
import bpy, bmesh, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_twin.blend")
bpy.ops.wm.read_factory_settings(use_empty=True)
R = math.radians

def lin(c):
    f = lambda v: (v / 255.0) ** 2.2
    return (f(c[0]), f(c[1]), f(c[2]), 1)

def mat(name, light, shadow):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB"); ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, lin(shadow)
    el[1].position, el[1].color = 0.28, lin(light)
    emit = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    L = nt.links.new
    L(diff.outputs["BSDF"], s2r.inputs["Shader"]); L(s2r.outputs["Color"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], emit.inputs["Color"]); L(emit.outputs["Emission"], out.inputs["Surface"])
    m.use_backface_culling = False
    return m

# sRGB bytes sampled from assets/game/characters/player/*  -> (light, shadow). Shared with render_twin.py.
PAL = {
    "skin": ((233, 148, 141), (205, 104, 112)),
    "pants": ((64, 80, 129), (38, 52, 91)),
    "black": ((8, 8, 10), (8, 8, 10)),
    "mouth": ((205, 104, 112), (205, 104, 112)),
    "blade": ((214, 222, 236), (150, 162, 190)),
    "gold": ((244, 190, 50), (176, 120, 24)),
    "grip": ((120, 70, 40), (80, 44, 26)),
    "smear": ((255, 246, 200), (255, 246, 200)),
}
M = {k: mat(k, *v) for k, v in PAL.items()}

arm = bpy.data.armatures.new("TwinRig")
rig = bpy.data.objects.new("Twin", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name); b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm.edit_bones[parent]
bone("hips", (0, 0, .2), (0, 0, .3))
bone("torso", (0, 0, .3), (0, 0, .5), "hips")
bone("head", (0, 0, .5), (0, 0, 1.45), "torso")
bone("arm_R", (-.56, 0, .52), (-.56, 0, .3), "torso")       # sword arm (his right = -X)
bone("arm_L", (.56, 0, .52), (.56, 0, .3), "torso")
bone("smear", (-.56, 0, .52), (-.56, 0, .4), "arm_R")
bone("leg_R", (-.22, 0, .22), (-.22, 0, .02), "hips")
bone("leg_L", (.22, 0, .22), (.22, 0, .02), "hips")
bpy.ops.object.mode_set(mode="OBJECT")

def finish(o, material, bn, smooth=True):
    o.data.materials.append(M[material])
    if False:  # flat shading: each bevel facet is one band, like hand-placed pixels
        bpy.ops.object.shade_flat()
    vg = o.vertex_groups.new(name=bn); vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    o.parent = rig
    o.modifiers.new("Armature", "ARMATURE").object = rig
    return o

def rbox(name, c, size, material, bn, bevel=.0, seg=3, smooth=True):
    bpy.ops.mesh.primitive_cube_add(location=c)
    o = bpy.context.active_object; o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bm = o.modifiers.new("b", "BEVEL"); bm.width = bevel; bm.segments = seg; bm.harden_normals = True
        bpy.ops.object.modifier_apply(modifier="b")
    return finish(o, material, bn, smooth)

# head: big rounded block, like the player's blob. Front face at y = -.45
rbox("head", (0, 0, .98), (1.1, .9, .98), "skin", "head", .28, 3)
rbox("eye_L", (.24, -.455, .95), (.07, .04, .13), "black", "head", 0, 1, False)
rbox("eye_R", (-.24, -.455, .95), (.07, .04, .13), "black", "head", 0, 1, False)
rbox("mouth", (0, -.455, .84), (.22, .04, .07), "mouth", "head", 0, 1, False)
# pants + legs + feet
rbox("pants", (0, 0, .34), (.86, .6, .32), "pants", "torso", .1, 3)
for s, x, bn in (("R", -.22, "leg_R"), ("L", .22, "leg_L")):
    rbox(f"leg_{s}", (x, 0, .15), (.2, .2, .14), "skin", bn, .03, 2)
    rbox(f"foot_{s}", (x, -.05, .05), (.3, .42, .12), "black", bn, .03, 2)
# arms: little pink stubs at the sides
for s, x, bn in (("R", -.56, "arm_R"), ("L", .56, "arm_L")):
    rbox(f"arm_{s}", (x, 0, .4), (.2, .2, .26), "skin", bn, .06, 2)
# sword in the right hand: thick bright blade, points -Y at rest
rbox("grip", (-.56, -.08, .34), (.1, .22, .1), "grip", "arm_R", .02, 1, False)
rbox("guard", (-.56, -.2, .34), (.12, .09, .42), "gold", "arm_R", .02, 1, False)
rbox("blade", (-.56, -.72, .34), (.16, .95, .28), "blade", "arm_R", 0, 1, False)
rbox("tip", (-.56, -1.3, .34), (.16, .14, .16), "blade", "arm_R", 0, 1, False)

# smear: flat crescent that trails the blade; only visible on the hit frames (bone scale)
SPAN, R0, R1 = 70, .75, 1.55
bm = bmesh.new(); steps = 10; pivot = Vector((-.56, 0, .34))
for i in range(steps + 1):
    a = R(SPAN) * i / steps
    d = Vector((math.sin(a), -math.cos(a), 0)); taper = 1.0 - .8 * i / steps
    bm.verts.new(pivot + d * R0); bm.verts.new(pivot + d * (R0 + (R1 - R0) * taper))
bm.verts.ensure_lookup_table()
for i in range(steps):
    bm.faces.new((bm.verts[2*i], bm.verts[2*i+1], bm.verts[2*i+3], bm.verts[2*i+2]))
me = bpy.data.meshes.new("smear"); bm.to_mesh(me)
so = bpy.data.objects.new("smear", me); bpy.context.scene.collection.objects.link(so)
bpy.context.view_layer.objects.active = so; so.select_set(True)
finish(so, "smear", "smear", False)

# ---- animations: few frames, big key poses, no in-between wobble ----
rig.animation_data_create()
for pb in rig.pose.bones: pb.rotation_mode = "XYZ"
def action(name, n, fn):
    act = bpy.data.actions.new(name); rig.animation_data.action = act
    for i in range(n):
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        rig.pose.bones["smear"].scale = (.001, .001, .001)
        fn(i, rig.pose.bones)
        for pb in rig.pose.bones:
            for prop in ("rotation_euler", "location", "scale"): pb.keyframe_insert(prop, frame=i + 1)
    act.use_fake_user = True
def rot(pb, x=0, y=0, z=0): pb.rotation_euler = (R(x), R(y), R(z))

READY = -60
def idle(i, P):                       # 2 frames: breathe = drop 1 px
    P["hips"].location = (0, 0, [0, -.07][i])
    rot(P["arm_R"], READY); rot(P["arm_L"], -5)

def run(i, P):                        # 4 frames: contact / pass / contact / pass
    P["hips"].location = (0, 0, [-.06, .06, -.06, .06][i])
    a = [38, 0, -38, 0][i]
    rot(P["leg_R"], a); rot(P["leg_L"], -a)
    rot(P["arm_R"], READY); rot(P["arm_L"], [-30, -5, 30, -5][i])

SW = 1.0                              # flips the sweep direction if needed
def slash(i, P):                      # anticipation / hit(smear) / follow-through(smear) / recover
    phi = [125, 5, -125, -40][i] * SW
    tilt = [-75, -45, -30, -50][i]
    P["hips"].location = (0, 0, [-.1, -.04, -.06, -.02][i])
    rot(P["torso"], [6, -6, -8, 0][i], [30, -10, -35, -10][i] * SW, 0)
    P["arm_R"].rotation_euler = (R(tilt), R(phi), 0)
    rot(P["arm_L"], [-30, -10, 10, -5][i])
    rot(P["leg_R"], [10, -18, -12, 0][i]); rot(P["leg_L"], [-10, 18, 12, 0][i])
    k = 1.0 if i in (1, 2) else .001
    P["smear"].scale = (k, k, k)

action("idle", 2, idle); action("run", 4, run); action("slash", 4, slash)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
