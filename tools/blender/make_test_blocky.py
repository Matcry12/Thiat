"""Round 6 throwaway: a Minecraft-style BLOCKY character (cube head, box torso/arms/legs, all RIGID parts that rotate at
their joints), flat 2-band toon shading, player-palette colours. Run:
  blender --background --python tools/blender/make_test_blocky.py   ->  tools/blender/test_blocky.blend
Faces -Y at rotation 0. Only ROTATIONS are keyed; the renderer sets the 1-pixel body bob (hips.location) per frame so it is a whole
number of output pixels at any size. Objects named arm_* are hidden by the renderer for the 'no arms' variant."""
import bpy, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_blocky.blend")
bpy.ops.wm.read_factory_settings(use_empty=True)
R = math.radians

def lin(c):
    f = lambda v: (v / 255.0) ** 2.2
    return (f(c[0]), f(c[1]), f(c[2]), 1)

def mat(name, light, shadow):
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse"); s2r = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB"); ramp.color_ramp.interpolation = "CONSTANT"
    el = ramp.color_ramp.elements
    el[0].position, el[0].color = 0.0, lin(shadow)
    el[1].position, el[1].color = 0.28, lin(light)
    emit = nt.nodes.new("ShaderNodeEmission"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    L = nt.links.new
    L(diff.outputs["BSDF"], s2r.inputs["Shader"]); L(s2r.outputs["Color"], ramp.inputs["Fac"])
    L(ramp.outputs["Color"], emit.inputs["Color"]); L(emit.outputs["Emission"], out.inputs["Surface"])
    return m

# sRGB bytes (light, shadow). The pink + navy are the drawn player's; shirt/hair/shoes are new. Shared with render_blocky.py.
PAL = {
    "skin": ((233, 148, 141), (205, 104, 112)),
    "hair": ((124, 76, 44), (86, 50, 30)),
    "shirt": ((86, 170, 120), (52, 120, 84)),
    "pants": ((64, 80, 129), (38, 52, 91)),
    "shoe": ((52, 44, 60), (26, 22, 32)),
    "eye": ((8, 8, 10), (8, 8, 10)),
    "mouth": ((190, 86, 98), (190, 86, 98)),
}
M = {k: mat(k, *v) for k, v in PAL.items()}

# ---- dimensions (1 unit = one Minecraft head-width of 8 px; head enlarged to read at tiny sizes) ----
HEAD = 1.3
LEG_H, TORSO_H = 1.0, 1.3
Z_HIPS, Z_NECK = LEG_H, LEG_H + TORSO_H
ARM_X, ARM_W, ARM_H = .72, .42, 1.1
LEG_X, LEG_W = .26, .46

arm = bpy.data.armatures.new("BlockyRig")
rig = bpy.data.objects.new("Blocky", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name); b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm.edit_bones[parent]
bone("hips", (0, 0, Z_HIPS), (0, 0, Z_HIPS + .1))
bone("torso", (0, 0, Z_HIPS), (0, 0, Z_NECK), "hips")
bone("head", (0, 0, Z_NECK), (0, 0, Z_NECK + HEAD), "torso")
bone("arm_R", (-ARM_X, 0, Z_NECK - .08), (-ARM_X, 0, Z_NECK - .08 - ARM_H), "torso")
bone("arm_L", (ARM_X, 0, Z_NECK - .08), (ARM_X, 0, Z_NECK - .08 - ARM_H), "torso")
bone("leg_R", (-LEG_X, 0, Z_HIPS), (-LEG_X, 0, 0), "hips")
bone("leg_L", (LEG_X, 0, Z_HIPS), (LEG_X, 0, 0), "hips")
bpy.ops.object.mode_set(mode="OBJECT")

def box(name, c, size, material, bn):
    bpy.ops.mesh.primitive_cube_add(location=c)
    o = bpy.context.active_object; o.name = name
    o.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(M[material])
    vg = o.vertex_groups.new(name=bn); vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
    o.parent = rig
    o.modifiers.new("Armature", "ARMATURE").object = rig
    return o

# head (cube) + face + hair. Front face at y = -HEAD/2. Everything named head*/eye*/mouth*/hair* is the "head" layer.
zc = Z_NECK + HEAD / 2
box("head", (0, 0, zc), (HEAD, HEAD, HEAD), "skin", "head")
box("hair_top", (0, 0, Z_NECK + HEAD - .17), (HEAD + .06, HEAD + .06, .36), "hair", "head")
box("hair_back", (0, HEAD / 2 - .1, zc - .05), (HEAD + .06, .24, HEAD * .8), "hair", "head")
box("eye_L", (.3, -HEAD / 2 - .02, zc - .08), (.24, .06, .32), "eye", "head")
box("eye_R", (-.3, -HEAD / 2 - .02, zc - .08), (.24, .06, .32), "eye", "head")
box("mouth", (0, -HEAD / 2 - .02, zc - .46), (.34, .06, .1), "mouth", "head")
# torso, legs (+ shoes), arms (+ hands)
box("torso", (0, 0, Z_HIPS + TORSO_H / 2), (1.0, .56, TORSO_H), "shirt", "torso")
for s, x in (("R", -LEG_X), ("L", LEG_X)):
    box(f"leg_{s}", (x, 0, (.32 + LEG_H + .15) / 2), (LEG_W, LEG_W, LEG_H + .15 - .32), "pants", f"leg_{s}")   # top tucked inside the torso so a 1 px lift never shows a gap
    box(f"shoe_{s}", (x, -.03, .16), (LEG_W + .02, LEG_W + .08, .32), "shoe", f"leg_{s}")
for s, x in (("R", -ARM_X), ("L", ARM_X)):
    box(f"arm_{s}", (x, 0, Z_NECK - .08 - (ARM_H - .3) / 2), (ARM_W, ARM_W, ARM_H - .3), "shirt", f"arm_{s}")
    box(f"arm_hand_{s}", (x, 0, Z_NECK - .08 - ARM_H + .15), (ARM_W, ARM_W, .3), "skin", f"arm_{s}")

# ---- poses: rotations only (rigid limbs rotate at their joints) ----
rig.animation_data_create()
for pb in rig.pose.bones: pb.rotation_mode = "XYZ"
def rot(pb, x=0, y=0, z=0): pb.rotation_euler = (R(x), R(y), R(z))
def action(name, n, fn):
    act = bpy.data.actions.new(name); rig.animation_data.action = act
    for i in range(n):
        for pb in rig.pose.bones: pb.rotation_euler = (0, 0, 0)
        fn(i, rig.pose.bones)
        for pb in rig.pose.bones: pb.keyframe_insert("rotation_euler", frame=i + 1)
    act.use_fake_user = True
# bone local X ~ world X: NEGATIVE = swing forward (-Y toward the camera), positive = back.
def idle(i, P):                        # 2 frames: only the 1 px bob (set by the renderer) + arms breathe a hair
    rot(P["arm_R"], [0, 3][i]); rot(P["arm_L"], [0, 3][i])
def run(i, P):                         # classic swing: opposite legs/arms. contact A, pass, contact B, pass
    a = [58, 0, -58, 0][i]
    rot(P["leg_R"], -a); rot(P["leg_L"], a)
    rot(P["arm_R"], a * .9); rot(P["arm_L"], -a * .9)
    rot(P["torso"], -4, 0, [3, 0, -3, 0][i])
def hit(i, P):                         # flinch back: lean, arms flung up, legs apart
    rot(P["torso"], [-16, -9][i], 0, [8, -5][i])
    rot(P["arm_R"], [-50, -25][i]); rot(P["arm_L"], [-50, -25][i])
    rot(P["leg_R"], [14, 7][i]); rot(P["leg_L"], [-14, -7][i])
action("idle", 2, idle); action("run", 4, run); action("hit", 2, hit)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
