"""Player-twin -> pixel sprite sheets: 3 views (S front, E side, N back), rows = views, columns = frames.
The game flips the E row for W (like the player's flip_h). Plain python3:
  python3 tools/blender/render_twin.py                     full render at the default tilt -> assets/dev/characters/test3d_chibi/
  python3 tools/blender/render_twin.py --compare 70,80,90  angle comparison (angle_compare2_4x.png)
  python3 tools/blender/render_twin.py --twin-compare      real player vs twin front/side/back (twin_compare_4x.png)
  options: --pitch N (deg from straight down; 90 = pure front view)  --ppu N"""
import os, sys, math, subprocess, json, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CELL = 48
PITCH = 80
PPU = 15.5
TZ = 0.74                    # camera look-at height (units); also sets the feet offset used by the demo
ACTIONS = {"idle": 2, "run": 4, "slash": 4}
HOLD_MS = {"idle": [450, 450], "run": [130, 100, 130, 100], "slash": [170, 70, 90, 140]}
VIEWS = [("S", 0), ("E", 90), ("N", 180)]   # name, yaw degrees
OUTLINE = (0, 0, 0)
OUT = os.path.join(ROOT, "assets", "dev", "characters", "test3d_chibi")
SUN = 3.0

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
    sun.rotation_euler = Vector((0.55, -0.45, 0.7)).to_track_quat("Z", "Y").to_euler()   # light from top-right-front
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = cfg["cell"] / cfg["ppu"]; cam_d.clip_end = 100
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    rig = bpy.data.objects["Twin"]
    for pitch, act, yaw, f, fn in cfg["jobs"]:
        p = math.radians(pitch)
        cam.rotation_euler = (p, 0, 0)
        cam.location = (0, -12 * math.sin(p), cfg["tz"] + 12 * math.cos(p))
        rig.animation_data.action = bpy.data.actions[act]
        rig.rotation_euler = (0, 0, math.radians(yaw))
        sc.frame_set(f + 1); sc.render.filepath = fn
        bpy.ops.render.render(write_still=True)

def run_blender(jobs):
    cj = tempfile.mktemp(suffix=".json")
    json.dump({"ppu": PPU, "cell": CELL, "tz": TZ, "sun": SUN, "jobs": jobs}, open(cj, "w"))
    subprocess.run(["blender", "--background", os.path.join(HERE, "test_twin.blend"), "--python", __file__, "--", cj],
                   check=True, stdout=subprocess.DEVNULL)

def snap(path):
    """hard alpha + snap every pixel to the fixed player-style palette + 1 px black outline"""
    from PIL import Image
    im = Image.open(path).convert("RGBA"); px = im.load(); pal = palette()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            if a < 128: px[x, y] = (0, 0, 0, 0); continue
            c = min(pal, key=lambda q: (q[0]-r)**2 + (q[1]-g)**2 + (q[2]-b)**2)
            px[x, y] = c + (255,)
    out = im.copy(); o = out.load()
    for y in range(CELL):
        for x in range(CELL):
            if px[x, y][3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and px[nx, ny][3]:
                    o[x, y] = OUTLINE + (255,); break
    return out

GREEN = (60, 110, 30, 255)

def compare(pitches):
    from PIL import Image, ImageDraw
    raw = tempfile.mkdtemp(prefix="twin_cmp_")
    jobs = [[pt, "idle", yaw, 0, f"{raw}/{pt}_{n}.png"] for pt in pitches for n, yaw in VIEWS]
    run_blender(jobs)
    S = 4; cw = CELL * S
    img = Image.new("RGBA", (cw * 3, (cw + 24) * len(pitches)), GREEN); dr = ImageDraw.Draw(img)
    for r, pt in enumerate(pitches):
        for c, (n, yaw) in enumerate(VIEWS):
            img.alpha_composite(snap(f"{raw}/{pt}_{n}.png").resize((cw, cw), Image.NEAREST), (c * cw, r * (cw + 24) + 24))
        dr.text((4, r * (cw + 24) + 6), f"{pt} deg from straight down (90 = pure front)   S / E / N", fill=(255, 255, 255, 255))
    os.makedirs(OUT, exist_ok=True); img.save(os.path.join(OUT, "angle_compare2_4x.png"))

def twin_compare():
    from PIL import Image, ImageDraw
    raw = tempfile.mkdtemp(prefix="twin_tc_")
    run_blender([[PITCH, "idle", yaw, 0, f"{raw}/{n}.png"] for n, yaw in VIEWS])
    S = 4; cw = 48 * S
    img = Image.new("RGBA", (cw * 4, cw + 24), GREEN); dr = ImageDraw.Draw(img)
    pl = Image.open(os.path.join(ROOT, "assets/dev/characters/player/idle/idle_1.png")).convert("RGBA")
    big = Image.new("RGBA", (48, 48), (0, 0, 0, 0)); big.alpha_composite(pl, (8, 8))
    img.alpha_composite(big.resize((cw, cw), Image.NEAREST), (0, 24)); dr.text((4, 6), "REAL player (front)", fill=(255, 255, 255, 255))
    for i, (n, yaw) in enumerate(VIEWS):
        img.alpha_composite(snap(f"{raw}/{n}.png").resize((cw, cw), Image.NEAREST), ((i + 1) * cw, 24))
        dr.text(((i + 1) * cw + 4, 6), f"3D twin {n}", fill=(255, 255, 255, 255))
    os.makedirs(OUT, exist_ok=True); img.save(os.path.join(OUT, "twin_compare_4x.png"))

def full():
    from PIL import Image
    raw = tempfile.mkdtemp(prefix="twin_raw_")
    jobs = [[PITCH, a, yaw, f, f"{raw}/{a}_{n}_{f}.png"] for a, c in ACTIONS.items() for n, yaw in VIEWS for f in range(c)]
    t = time.time(); run_blender(jobs); print(f"render {time.time() - t:.1f}s, {len(jobs)} frames")
    os.makedirs(OUT, exist_ok=True); sheets = {}
    for a, c in ACTIONS.items():
        sheet = Image.new("RGBA", (CELL * c, CELL * 3), (0, 0, 0, 0))
        for r, (n, yaw) in enumerate(VIEWS):
            for f in range(c): sheet.paste(snap(f"{raw}/{a}_{n}_{f}.png"), (f * CELL, r * CELL))
        sheet.save(os.path.join(OUT, f"{a}.png")); sheets[a] = sheet
    W = max(s.width for s in sheets.values()); H = sum(s.height for s in sheets.values())
    contact = Image.new("RGBA", (W, H), GREEN); y = 0
    for s in sheets.values(): contact.alpha_composite(s, (0, y)); y += s.height
    contact.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(OUT, "contact_sheet_4x.png"))
    json.dump({"cell": CELL, "pitch_from_straight_down": PITCH, "ppu": PPU, "look_at_height": TZ,
               "feet_below_cell_centre_px": round(TZ * math.sin(math.radians(PITCH)) * PPU, 2),
               "rows": [v[0] for v in VIEWS], "flip_E_row_for_W": True,
               "note": "ONE row per view like the player's flip_h: S front, E side (flip for W), N back. Enough for 2- or 4-direction movement; no diagonals.",
               "actions": {a: {"frames": c, "hold_ms": HOLD_MS[a]} for a, c in ACTIONS.items()},
               "slash_smear_frames": [1, 2]}, open(os.path.join(OUT, "sheet_info.json"), "w"), indent=1)

if __name__ == "__main__":
    try:
        import bpy
        blender_part(json.load(open(sys.argv[sys.argv.index("--") + 1])))
    except ImportError:
        a = sys.argv[1:]
        if "--ppu" in a: PPU = float(a[a.index("--ppu") + 1])
        if "--pitch" in a: PITCH = float(a[a.index("--pitch") + 1])
        if "--sun" in a: SUN = float(a[a.index("--sun") + 1])
        if "--compare" in a: compare([float(x) for x in a[a.index("--compare") + 1].split(",")])
        elif "--twin-compare" in a: twin_compare()
        else: full()
