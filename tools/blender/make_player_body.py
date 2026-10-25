"""Round 4: BODY-ONLY 3D twin of the player sprite (no arms, no weapon: hands/weapon are 2D in the game).
Original doc: 3D TWIN of the player sprite (pink round head + navy pants + black feet), built in code, rigged,
keyframed as hand-drawn-style key poses. Run: blender --background --python tools/blender/make_test_twin.py
-> tools/blender/player_body.blend.   Faces -Y at rotation 0 (toward the camera).
Lighting is 2 flat bands (light + shadow), light from the top-right like the player sprite."""
import bpy, bmesh, math, os
from mathutils import Vector

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "player_body.blend")
bpy.ops.wm.read_factory_settings(use_empty=True)
R = math.radians
PPU = 15.5      # must equal render_body.py PPU: vertical moves are snapped to whole output pixels

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

# sRGB bytes sampled from assets/characters/player/*  -> (light, shadow). Shared with render_twin.py.
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

arm = bpy.data.armatures.new("BodyRig")
rig = bpy.data.objects.new("Body", arm)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
def bone(name, head, tail, parent=None):
    b = arm.edit_bones.new(name); b.head, b.tail = Vector(head), Vector(tail)
    if parent: b.parent = arm.edit_bones[parent]
bone("hips", (0, 0, .2), (0, 0, .3))
bone("torso", (0, 0, .3), (0, 0, .5), "hips")
bone("head", (0, 0, .5), (0, 0, 1.45), "torso")
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
rbox("head", (0, 0, .98), (1.1, .9, .98), "skin", "head", .42, 6)
rbox("eye_L", (.21, -.455, .95), (.07, .04, .13), "black", "head", 0, 1, False)
rbox("eye_R", (-.21, -.455, .95), (.07, .04, .13), "black", "head", 0, 1, False)
rbox("mouth", (0, -.455, .84), (.22, .04, .07), "mouth", "head", 0, 1, False)
# pants + legs + feet
rbox("pants", (0, 0, .34), (.86, .6, .32), "pants", "torso", .1, 3)
for s, x, bn in (("R", -.22, "leg_R"), ("L", .22, "leg_L")):
    rbox(f"leg_{s}", (x, 0, .15), (.2, .2, .14), "skin", bn, .03, 2)
    rbox(f"foot_{s}", (x, -.05, .05), (.3, .42, .12), "black", bn, .03, 2)
# ---- animations: few frames, big key poses, no in-between wobble ----
rig.animation_data_create()
for pb in rig.pose.bones: pb.rotation_mode = "XYZ"
def action(name, n, fn):
    act = bpy.data.actions.new(name); rig.animation_data.action = act
    for i in range(n):
        for pb in rig.pose.bones:
            pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0); pb.scale = (1, 1, 1)
        fn(i, rig.pose.bones)
        for pb in rig.pose.bones:
            for prop in ("rotation_euler", "location", "scale"): pb.keyframe_insert(prop, frame=i + 1)
    act.use_fake_user = True
def up(pb, dz):
    """Raise a bone by dz world units. Bones point along +Z (hips/torso/head) or -Z (legs), so world-up is local +Y / -Y."""
    dz = round(dz * PPU) / PPU     # whole output pixels only
    pb.location = (0, dz if pb.name in ("hips", "torso", "head") else -dz, 0)
def rot(pb, x=0, y=0, z=0): pb.rotation_euler = (R(x), R(y), R(z))

def idle(i, P):                       # 2 frames: breathe = drop ~1 px
    up(P["hips"], [0, -.07][i])

def run(i, P):
    """6 frames = 2 steps x (contact, down, up/passing). Squash on down, stretch on up, head lags the body by a beat,
    lean forward, a little side sway, clear foot lift + plant."""
    s = 1 if i < 3 else -1                 # which leg leads this step
    k = i % 3
    hips = [0.0, -.12, .16][k]
    up(P["hips"], hips)
    P["hips"].scale = [(1, 1, 1), (1.05, .93, 1.05), (.97, 1.05, .97)][k]   # local Y is world up
    lead = [48, 22, -8][k]                                         # leading leg swing
    trail = [-48, -58, 6][k]                                       # trailing leg: push off, lift, pass through
    lift = [0, .12, .18][k]                                        # trailing foot height
    rot(P["leg_R"], s * lead if s > 0 else s * trail * -1)
    rot(P["leg_L"], -s * lead if s < 0 else -s * trail * -1)
    up(P["leg_R"], lift if s < 0 else 0)
    up(P["leg_L"], lift if s > 0 else 0)
    rot(P["torso"], -10, [3, 0, -3][k] * s * 1.0, [4, 0, -4][k] * s)   # forward lean + sway

def hit(i, P):                        # 2 frames: flinch back, then stagger
    up(P["hips"], [-.12, -.06][i])
    rot(P["torso"], [-14, -8][i], 0, [6, -4][i])
    rot(P["leg_R"], [12, 6][i]); rot(P["leg_L"], [-12, -6][i])

def roll(i, P):                       # 3 frames: tuck and tumble forward (rotates about the body centre)
    up(P["hips"], .6)
    P["hips"].rotation_euler = (R([-100, -200, -300][i]), 0, 0)
    rot(P["leg_R"], 40); rot(P["leg_L"], 40)

action("idle", 2, idle); action("run", 6, run); action("hit", 2, hit); action("roll", 3, roll)
rig.animation_data.action = bpy.data.actions["idle"]
bpy.ops.wm.save_as_mainfile(filepath=OUT)
print("saved", OUT)
