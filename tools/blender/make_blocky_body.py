"""Round 7 (the shipped player body): a chunky Minecraft-style BLOCKY body WITHOUT arms (hands/weapon are 2D in the game). Derived from the round-6 test:
the torso is wide + thick so a missing 3D arm does not read as a stick man. Original doc: a Minecraft-style BLOCKY character (cube head, box torso/arms/legs, all RIGID parts that rotate at
their joints), flat 2-band toon shading, player-palette colours. Run:
  blender --background --python tools/blender/make_blocky_body.py   ->  tools/blender/blocky_body.blend
Faces -Y at rotation 0. Only ROTATIONS are keyed; the renderer sets the 1-pixel body bob (hips.location) per frame so it is a whole
number of output pixels at any size. Objects named arm_* are hidden by the renderer for the 'no arms' variant."""
import bpy, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "blocky_body.blend")
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
    "shoe": ((52, 44, 64), (30, 26, 40)),
    "belt": ((214, 166, 64), (150, 106, 40)),
    "neck": ((205, 104, 112), (160, 78, 92)),
    "eye": ((8, 8, 10), (8, 8, 10)),
    "mouth": ((190, 86, 98), (190, 86, 98)),
}
M = {k: mat(k, *v) for k, v in PAL.items()}

# ---- dimensions (1 unit = one Minecraft head-width of 8 px). Silhouette = THREE masses: big head, a stepped/tapered torso that is
# narrower than the head, and two short legs with a gap between them (shoes darker than pants, belt + shirt/pants colour blocking). ----
HEAD = 1.5
NECK = .3                         # a clear dark neck line between head and torso (>= 1 px at 18 px)
SH_W, SH_H = 1.38, .55           # shoulders: clearly narrower than the head (1.5), stepped down...
WA_W, WA_H = 1.2, .5              # ...to a narrower waist: taper
TORSO_D = .9
BELT_H = .28
LEG_H = .95
LEG_X, LEG_W = .45, .6            # legs: a visible gap between them
Z_HIPS = LEG_H
Z_WAIST = Z_HIPS + WA_H           # top of the waist block / bottom of the chest
Z_NECK = Z_WAIST + SH_H           # top of the torso
Z_HEAD = Z_NECK + NECK            # bottom of the head cube

arm = bpy.data.armatures.new("BlockyBodyRig")
rig = bpy.data.objects.new("Blocky", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name); b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm.edit_bones[parent]
bone("hips", (0, 0, Z_HIPS), (0, 0, Z_HIPS + .1))
bone("torso", (0, 0, Z_HIPS), (0, 0, Z_NECK), "hips")
bone("head", (0, 0, Z_NECK), (0, 0, Z_HEAD + HEAD), "torso")
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
zc = Z_HEAD + HEAD / 2
box("head", (0, 0, zc), (HEAD, HEAD, HEAD), "skin", "head")
box("hair_top", (0, 0, Z_HEAD + HEAD - .17), (HEAD + .06, HEAD + .06, .36), "hair", "head")
box("hair_back", (0, HEAD / 2 - .1, zc - .05), (HEAD + .06, .24, HEAD * .8), "hair", "head")
box("eye_L", (.32, -HEAD / 2 - .02, zc - .08), (.26, .06, .34), "eye", "head")
box("eye_R", (-.32, -HEAD / 2 - .02, zc - .08), (.26, .06, .34), "eye", "head")
box("mouth", (0, -HEAD / 2 - .02, zc - .46), (.34, .06, .1), "mouth", "head")
# torso, legs (+ shoes), arms (+ hands)
box("head_neck", (0, 0, Z_NECK + NECK / 2), (.8, .6, NECK + .02), "neck", "head")
box("chest", (0, 0, Z_WAIST + SH_H / 2), (SH_W, TORSO_D, SH_H), "shirt", "torso")
box("shoulder_step", (0, 0, Z_NECK - .08), (SH_W - .24, TORSO_D, .16), "shirt", "torso")   # chamfer: the top corners step in
box("waist", (0, 0, Z_HIPS + WA_H / 2), (WA_W, TORSO_D - .06, WA_H), "shirt", "torso")
box("belt", (0, 0, Z_HIPS + BELT_H / 2 + .02), (WA_W + .04, TORSO_D - .02, BELT_H), "belt", "torso")
for s_, x in (("R", -LEG_X), ("L", LEG_X)):
    box(f"leg_{s_}", (x, 0, (.3 + LEG_H + .12) / 2), (LEG_W, LEG_W + .06, LEG_H + .12 - .3), "pants", f"leg_{s_}")
    box(f"shoe_{s_}", (x, -.04, .15), (LEG_W + .04, LEG_W + .14, .32), "shoe", f"leg_{s_}")

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
A = 8   # A-stance: legs angled outward (rotation about the leg's local Z = world Y tilts it sideways; +z = tail toward -X)
def stance(P, a=A):
    rot(P["leg_R"], 0, 0, a); rot(P["leg_L"], 0, 0, -a)
def idle(i, P):                        # 2 frames: only the 1 px bob (set by the renderer); legs in a small A-stance, not parallel posts
    stance(P)
def run(i, P):                         # big DIAGONAL swing: contact A, pass, contact B, pass. Forward lean + sway.
    sw = [42, 14, -42, -14][i]         # leg_R swing, leg_L is the opposite (forward = negative about X)
    rot(P["leg_R"], -sw, 0, A * .6); rot(P["leg_L"], sw, 0, -A * .6)
    rot(P["torso"], -10, 0, [4, 0, -4, 0][i])     # lean 10 deg into the run + a slight sway/twist
def hit(i, P):                         # knock-back: lean back, legs diagonal backward
    rot(P["torso"], [-16, -9][i], 0, [8, -5][i])
    rot(P["leg_R"], [30, 18][i], 0, [10, A][i]); rot(P["leg_L"], [22, 10][i], 0, -[10, A][i])
action("idle", 2, idle); action("run", 4, run); action("hit", 2, hit)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
