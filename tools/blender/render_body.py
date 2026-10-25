"""Round 4 BODY-ONLY sheets (hands/weapon are 2D in the game): 3 views (S front, E = 3/4 front, N back), rows = views, columns = frames.
The game flips the E row for W (like the player's flip_h). Plain python3:
  python3 tools/blender/render_body.py                     full render at the default tilt -> assets/characters/test3d_chibi/
  python3 tools/blender/render_body.py --yaw-compare       yaw comparison (yaw_compare_4x.png)
  options: --pitch N (deg from straight down; 90 = pure front view)  --ppu N"""
import os, sys, math, subprocess, json, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CELL = 48
PITCH = 80
PPU = 15.5
TZ = 0.74                    # camera look-at height (units); also sets the feet offset used by the demo
YAW = 25                     # 3/4 front: body turned this many degrees from facing the camera
ACTIONS = {"idle": 2, "run": 6, "hit": 2}
HOLD_MS = {"idle": [450, 450], "run": [90, 90, 90, 90, 90, 90], "hit": [90, 150]}
VIEWS = [("S", 0), ("E", YAW)]   # name, yaw degrees
OUTLINE = (0, 0, 0)
OUT = os.path.join(ROOT, "assets", "characters", "player", "3d")
CMP = os.path.join(ROOT, "assets", "characters", "test3d_chibi")
SUN = 3.0
LIGHT = (0.5, -0.8, 0.45)   # toward the light: right, FRONT, up -> the face sits in the light band

def palette():
    # same colours as make_test_twin.py PAL (sRGB bytes)
    return [(233, 148, 141), (205, 104, 112), (64, 80, 129), (38, 52, 91), (8, 8, 10), (214, 222, 236),
            (150, 162, 190), (244, 190, 50), (176, 120, 24), (120, 70, 40), (80, 44, 26), (255, 246, 200)]

def blender_part(cfg):
    import bpy
    from mathutils import Vector
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 1
    sc.render.resolution_x = sc.render.resolution_y = cfg["cell"]
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.filter_size = 0.0
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1); sc.world = w
    sun_d = bpy.data.lights.new("sun", "SUN"); sun_d.energy = cfg["sun"]; sun_d.use_shadow = False
    sun = bpy.data.objects.new("sun", sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = Vector(cfg['light']).to_track_quat("Z", "Y").to_euler()   # light from top-right-front
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = cfg["cell"] / cfg["ppu"]; cam_d.clip_end = 100
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    rig = bpy.data.objects["Body"]
    HEAD = {"head", "eye_L", "eye_R", "mouth"}
    for pitch, act, yaw, f, fn, mode in cfg["jobs"]:
        for o in rig.children:
            o.hide_render = False if mode == "all" else ((o.name in HEAD) if mode == "body" else (o.name not in HEAD))
        p = math.radians(pitch)
        cam.rotation_euler = (p, 0, 0)
        cam.location = (0, -12 * math.sin(p), cfg["tz"] + 12 * math.cos(p))
        rig.animation_data.action = bpy.data.actions[act]
        rig.rotation_euler = (0, 0, math.radians(yaw))
        sc.frame_set(f + 1); sc.render.filepath = fn
        bpy.ops.render.render(write_still=True)

def run_blender(jobs):
    cj = tempfile.mktemp(suffix=".json")
    json.dump({"ppu": PPU, "cell": CELL, "tz": TZ, "sun": SUN, "light": LIGHT, "jobs": jobs}, open(cj, "w"))
    subprocess.run(["blender", "--background", os.path.join(HERE, "player_body.blend"), "--python", __file__, "--", cj],
                   check=True, stdout=subprocess.DEVNULL)

def snap(path, outline=True):
    """hard alpha + snap every pixel to the fixed player-style palette + 1 px black outline"""
    from PIL import Image
    im = Image.open(path).convert("RGBA"); px = im.load(); pal = palette()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            if a < 128: px[x, y] = (0, 0, 0, 0); continue
            c = min(pal, key=lambda q: (q[0]-r)**2 + (q[1]-g)**2 + (q[2]-b)**2)
            px[x, y] = c + (255,)
    if not outline: return im
    return add_outline(im)

def add_outline(im):
    px = im.load(); out = im.copy(); o = out.load()
    for y in range(CELL):
        for x in range(CELL):
            if px[x, y][3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and px[nx, ny][3]:
                    o[x, y] = OUTLINE + (255,); break
    return out

GREEN = (60, 110, 30, 255)

def yaw_compare():
    """3/4 front at yaw 25/35/45, plus pure back vs 3/4 back, idle frame 0, at 4x."""
    from PIL import Image, ImageDraw
    raw = tempfile.mkdtemp(prefix="body_yaw_")
    cols = [("front 0", 0), ("3/4 front 25", 25), ("3/4 front 35", 35), ("3/4 front 45", 45)]
    run_blender([[PITCH, "idle", yaw, 0, f"{raw}/{i}.png", "all"] for i, (_, yaw) in enumerate(cols)])
    cw = CELL * 4
    img = Image.new("RGBA", (cw * 4, cw + 20), GREEN); dr = ImageDraw.Draw(img)
    for i, (label, yaw) in enumerate(cols):
        x, y = i * cw, 0
        img.alpha_composite(snap(f"{raw}/{i}.png").resize((cw, cw), Image.NEAREST), (x, y + 20))
        dr.text((x + 4, y + 4), label, fill=(255, 255, 255, 255))
    os.makedirs(CMP, exist_ok=True); img.save(os.path.join(CMP, "yaw_compare_4x.png"))

# Head offsets in WHOLE output pixels (dx right-in-sprite, dy down), per action / view row / frame. The head is rendered ONCE per
# view (rigid face, no rotation) and stamped at these offsets; body squash/stretch never touches it.
# Row order = VIEWS (S front, E side facing right). E dx > 0 = forward.
HEAD_OFF = {
    "idle": {"S": [(0, 0), (0, 1)], "E": [(0, 0), (0, 1)]},
    "run":  {"S": [(0, 0), (0, 1), (0, -1), (0, 0), (0, 1), (0, -1)], "E": [(1, 0), (1, 1), (1, -1), (1, 0), (1, 1), (1, -1)]},
    "hit":  {"S": [(0, 2), (0, 1)], "E": [(-2, 2), (-1, 1)]},
}

PANTS = {(64, 80, 129), (38, 52, 91)}
def check_no_second_head(head, body, a, n, f):
    """The body-only render must not contain a head: inside the head's mask it may only hold pants (the part tucked behind the
    head), never skin/eye/mouth colours, and it must have no pixel ABOVE the head's top row (no second/shifted head)."""
    hp, bp = head.load(), body.load()
    top = min(y for y in range(CELL) for x in range(CELL) if hp[x, y][3])
    for y in range(CELL):
        for x in range(CELL):
            if bp[x, y][3] and hp[x, y][3]:
                assert bp[x, y][:3] in PANTS, f"head leaked into body render at {a}/{n}/{f}: {(x, y)} {bp[x, y]}"
            if bp[x, y][3] and y < top:
                raise AssertionError(f"body pixel above the head at {a}/{n}/{f}: {(x, y)}")

def check_face_rigid(head_imgs, cells):
    """Every opaque head pixel (eyes, mouth, skin) must be IDENTICAL in every frame, at the head's integer offset."""
    n = 0
    for (act, view, f), (cell, off) in cells.items():
        himg = head_imgs[view]; hp = himg.load(); cp = cell.load()
        assert all(isinstance(v, int) for v in off), f"non-integer head offset {off}"
        for y in range(CELL):
            for x in range(CELL):
                if hp[x, y][3]:
                    X, Y = x + off[0], y + off[1]
                    assert 0 <= X < CELL and 0 <= Y < CELL, f"head leaves the cell at {act}/{view}/{f}"
                    assert cp[X, Y][:3] == hp[x, y][:3], f"FACE MOVED at {act}/{view}/{f}: pixel {(x, y)} {cp[X, Y]} != {hp[x, y]}"
                    n += 1
    return n

def full():
    from PIL import Image
    raw = tempfile.mkdtemp(prefix="twin_raw_")
    jobs = [[PITCH, a, yaw, f, f"{raw}/{a}_{n}_{f}.png", "body"] for a, c in ACTIONS.items() for n, yaw in VIEWS for f in range(c)]
    jobs += [[PITCH, "idle", yaw, 0, f"{raw}/head_{n}.png", "head"] for n, yaw in VIEWS]
    t = time.time(); run_blender(jobs); print(f"render {time.time() - t:.1f}s, {len(jobs)} frames")
    heads = {n: snap(f"{raw}/head_{n}.png", outline=False) for n, _ in VIEWS}
    os.makedirs(OUT, exist_ok=True); sheets = {}; cells = {}
    for a, c in ACTIONS.items():
        sheet = Image.new("RGBA", (CELL * c, CELL * len(VIEWS)), (0, 0, 0, 0))
        for r, (n, yaw) in enumerate(VIEWS):
            for f in range(c):
                off = HEAD_OFF[a][n][f]
                comp = snap(f"{raw}/{a}_{n}_{f}.png", outline=False)
                check_no_second_head(heads[n], comp, a, n, f)
                comp.alpha_composite(heads[n], off)          # integer offset: the face never reshapes
                cells[(a, n, f)] = (comp.copy(), off)
                sheet.paste(add_outline(comp), (f * CELL, r * CELL))
        sheet.save(os.path.join(OUT, f"{a}.png")); sheets[a] = sheet
    px = check_face_rigid(heads, cells)
    print(f"NO SECOND HEAD CHECK OK (body-only frames hold only pants inside the head mask). ")
    print(f"FACE RIGID CHECK OK: {px} head pixels identical across {len(cells)} frames (idle/run/hit, front+side)")
    W = max(s.width for s in sheets.values()); H = sum(s.height for s in sheets.values())
    contact = Image.new("RGBA", (W, H), GREEN); y = 0
    for s in sheets.values(): contact.alpha_composite(s, (0, y)); y += s.height
    contact.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(OUT, "contact_sheet_4x.png"))
    json.dump({"cell": CELL, "pitch_from_straight_down": PITCH, "ppu": PPU, "look_at_height": TZ,
               "feet_below_cell_centre_px": round(TZ * math.sin(math.radians(PITCH)) * PPU, 2),
               "rows": [v[0] for v in VIEWS], "flip_E_row_for_W": True,
               "note": "BODY ONLY (no arms/weapon). ONE row per view: S front, E = 3/4 front (flip for W); no back view. The head is rendered once per view and stamped at integer offsets (head_offsets_px) so the face never reshapes.",
               "actions": {a: {"frames": c, "hold_ms": HOLD_MS[a]} for a, c in ACTIONS.items()},
               "head_offsets_px": HEAD_OFF, "yaw_of_E_row_deg": YAW}, open(os.path.join(OUT, "sheet_info.json"), "w"), indent=1)

def run_gif():
    """4x looping preview of the run cycle: front row then side row, on grass green."""
    from PIL import Image
    sheet = Image.open(os.path.join(OUT, "run.png")); n = ACTIONS["run"]; S = 4
    frames = []
    for f in range(n):
        im = Image.new("RGBA", (CELL * len(VIEWS) * S, CELL * S), GREEN)
        for r in range(len(VIEWS)):
            cell = sheet.crop((f * CELL, r * CELL, (f + 1) * CELL, (r + 1) * CELL)).resize((CELL * S, CELL * S), Image.NEAREST)
            im.alpha_composite(cell, (r * CELL * S, 0))
        frames.append(im.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(OUT, "run_preview_4x.gif"), save_all=True, append_images=frames[1:], loop=0,
                   duration=HOLD_MS["run"], disposal=2)

if __name__ == "__main__":
    try:
        import bpy
        blender_part(json.load(open(sys.argv[sys.argv.index("--") + 1])))
    except ImportError:
        a = sys.argv[1:]
        if "--ppu" in a: PPU = float(a[a.index("--ppu") + 1])
        if "--pitch" in a: PITCH = float(a[a.index("--pitch") + 1])
        if "--sun" in a: SUN = float(a[a.index("--sun") + 1])
        if "--yaw-compare" in a: yaw_compare()
        elif "--gif" in a: run_gif()
        else:
            full(); run_gif()
            sys.path.insert(0, HERE); import build_frames; build_frames.build()
