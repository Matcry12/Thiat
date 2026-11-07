"""Round 7: the shipped player body (chunky blocky, NO arms) -> 18 px pixel sprite sheets + SpriteFrames. Plain python3:
  python3 tools/blender/render_blocky_body.py               render + pack + SpriteFrames + checks + before/after + GIF
  python3 tools/blender/render_blocky_body.py --yaw-compare yaw comparison (yaw_compare_4x.png)
  options: --yaw N (3/4 side yaw, default YAW)  --size N (target height px)
Rows: S (front) and E (3/4 front 25 deg; the game flips it for W). Columns = frames. No back view.
Variants: 'arms' (arms are in the body, swing when running) / 'noarms' (only the game's 2D hands)."""
import os, sys, math, subprocess, json, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "dev", "characters", "player", "blocky")
TEST = os.path.join(ROOT, "assets", "dev", "characters", "test_blocky")
CELL = 32
PITCH = 80
YAW = int(os.environ.get('BLOCKY_YAW', 30))   # 3/4 side yaw; chosen from yaw_compare_4x.png
TZ = 1.8                      # look-at height (units); character is ~3.6 units tall
SIZES = [18]
PPU_DEFAULT = 4.9            # measured: 18 px body, 20 px with the outline          # target body height in output px (1x). Current player ~25 px.
REC_SIZE = 18
VARIANTS = ["noarms"]
ACTIONS = {"idle": 2, "run": 4, "hit": 2}
HOLD_MS = {"idle": [450, 450], "run": [110, 90, 110, 90], "hit": [90, 150]}
VIEWS = [("S", 0), ("E", YAW)]
BOB_PX = {"idle": [0, -1], "run": [0, 1, 0, 1], "hit": [-1, 0]}          # whole-pixel body bob (+ = up)
HEAD_OFF = {                                                              # whole-pixel head stamp offsets (dx, dy down+)
    "idle": {"S": [(0, 0), (0, 1)], "E": [(0, 0), (0, 1)]},
    "run":  {"S": [(0, 0), (0, -1), (0, 0), (0, -1)], "E": [(0, 0), (0, -1), (0, 0), (0, -1)]},
    "hit":  {"S": [(0, 1), (0, 1)], "E": [(-1, 1), (-1, 0)]},
}
# feet lift in whole px (world up), (leg_R, leg_L): clear foot lift on the passing frames, planted feet stay on the ground
FOOT_LIFT = {"idle": [(0, 0), (0, 0)], "run": [(0, 0), (0, 1), (0, 0), (1, 0)], "hit": [(0, 0), (0, 0)]}
OUTLINE = (0, 0, 0)
GREEN = (60, 110, 30, 255)
SUN = 3.0
LIGHT = (0.5, -0.8, 0.45)
PAL_BYTES = [(233, 148, 141), (205, 104, 112), (124, 76, 44), (86, 50, 30), (86, 170, 120), (52, 120, 84), (64, 80, 129),
             (38, 52, 91), (52, 44, 64), (30, 26, 40), (8, 8, 10), (190, 86, 98), (214, 166, 64), (150, 106, 40), (160, 78, 92)]
HEAD_ONLY_COLOURS = {(124, 76, 44), (86, 50, 30), (8, 8, 10), (190, 86, 98), (205, 104, 112), (160, 78, 92)}   # hair, eyes, mouth never belong to the body layer

def is_head(n): return n.startswith(("head", "hair", "eye", "mouth"))

def blender_part(cfg):
    import bpy
    from mathutils import Vector
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"; sc.eevee.taa_render_samples = 1
    sc.render.resolution_x = sc.render.resolution_y = cfg["cell"]; sc.render.resolution_percentage = 100
    sc.render.film_transparent = True; sc.render.filter_size = 0.0
    sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"; sc.view_settings.look = "None"
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1); sc.world = w
    sun_d = bpy.data.lights.new("sun", "SUN"); sun_d.energy = cfg["sun"]; sun_d.use_shadow = False
    sun = bpy.data.objects.new("sun", sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = Vector(cfg["light"]).to_track_quat("Z", "Y").to_euler()
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = cfg["cell"] / cfg["ppu"]; cam_d.clip_end = 100
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    rig = bpy.data.objects["Blocky"]
    p = math.radians(cfg["pitch"])
    cam.rotation_euler = (p, 0, 0)
    cam.location = (0, -12 * math.sin(p), cfg["tz"] + 12 * math.cos(p))
    for act, yaw, f, fn, layer, arms, bob, lift in cfg["jobs"]:
        for o in rig.children:
            if layer == "head": hide = not is_head(o.name)
            elif layer == "body": hide = is_head(o.name) or (not arms and o.name.startswith("arm_"))
            else: hide = (not arms and o.name.startswith("arm_"))
            o.hide_render = hide
        rig.animation_data.action = bpy.data.actions[act]
        rig.rotation_euler = (0, 0, math.radians(yaw))
        sc.frame_set(f + 1)
        d = bob / cfg["ppu"]
        rig.pose.bones["hips"].location = (0, d, 0)
        for leg, want in (("leg_R", lift[0]), ("leg_L", lift[1])):    # legs hang from the hips: cancel the bob, add the wanted foot lift
            rig.pose.bones[leg].location = (0, (bob - want) / cfg["ppu"], 0)
        bpy.context.view_layer.update()
        sc.render.filepath = fn
        bpy.ops.render.render(write_still=True)

def run_blender(ppu, jobs):
    cj = tempfile.mktemp(suffix=".json")
    json.dump({"ppu": ppu, "cell": CELL, "tz": TZ, "pitch": PITCH, "sun": SUN, "light": LIGHT, "jobs": jobs}, open(cj, "w"))
    subprocess.run(["blender", "--background", os.path.join(HERE, "blocky_body.blend"), "--python", __file__, "--", cj],
                   check=True, stdout=subprocess.DEVNULL)

def snap(path, outline=True):
    from PIL import Image
    im = Image.open(path).convert("RGBA"); px = im.load()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            if a < 128: px[x, y] = (0, 0, 0, 0); continue
            px[x, y] = min(PAL_BYTES, key=lambda q: (q[0]-r)**2 + (q[1]-g)**2 + (q[2]-b)**2) + (255,)
    return add_outline(im) if outline else im

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

def calibrate(target):
    """ppu such that the full idle S frame is `target` px tall (opaque bbox, no outline)."""
    ppu = target / 3.7
    for _ in range(3):
        fn = tempfile.mktemp(suffix=".png")
        run_blender(ppu, [["idle", 0, 0, fn, "all", True, 0, (0, 0)]])
        bb = snap(fn, outline=False).getbbox()
        h = bb[3] - bb[1]
        if h == target: break
        ppu *= target / h
    return round(ppu, 3), h

def check_face(heads, cells, bodies):
    n = 0
    for (act, view, f), (cell, off) in cells.items():
        hp, cp, bp = heads[view].load(), cell.load(), bodies[(act, view, f)].load()
        for y in range(CELL):
            for x in range(CELL):
                if hp[x, y][3]:
                    X, Y = x + off[0], y + off[1]
                    assert 0 <= X < CELL and 0 <= Y < CELL, f"head leaves the cell {act}/{view}/{f}"
                    assert cp[X, Y][:3] == hp[x, y][:3], f"FACE MOVED {act}/{view}/{f} {(x, y)}"
                    n += 1
                if bp[x, y][3] and bp[x, y][:3] in HEAD_ONLY_COLOURS:
                    raise AssertionError(f"head colour leaked into body-only render {act}/{view}/{f} {(x, y)}")
    return n

def full(size, ppu, variant):
    from PIL import Image
    arms = variant == "arms"
    raw = tempfile.mkdtemp(prefix="blocky_raw_")
    jobs = [[a, yaw, f, f"{raw}/{a}_{n}_{f}.png", "body", arms, BOB_PX[a][f], FOOT_LIFT[a][f]] for a, c in ACTIONS.items() for n, yaw in VIEWS for f in range(c)]
    jobs += [["idle", yaw, 0, f"{raw}/head_{n}.png", "head", arms, 0, (0, 0)] for n, yaw in VIEWS]
    t = time.time(); run_blender(ppu, jobs); dt = time.time() - t
    heads = {n: snap(f"{raw}/head_{n}.png", outline=False) for n, _ in VIEWS}
    d = OUT; os.makedirs(d, exist_ok=True)
    sheets, cells, bodies = {}, {}, {}
    for a, c in ACTIONS.items():
        sheet = Image.new("RGBA", (CELL * c, CELL * len(VIEWS)), (0, 0, 0, 0))
        for r, (n, yaw) in enumerate(VIEWS):
            for f in range(c):
                body = snap(f"{raw}/{a}_{n}_{f}.png", outline=False); bodies[(a, n, f)] = body.copy()
                body.alpha_composite(heads[n], HEAD_OFF[a][n][f])
                cells[(a, n, f)] = (body.copy(), HEAD_OFF[a][n][f])
                sheet.paste(add_outline(body), (f * CELL, r * CELL))
        sheet.save(os.path.join(d, f"{a}.png")); sheets[a] = sheet
    px = check_face(heads, cells, bodies)
    json.dump({"cell": CELL, "target_height_px": size, "ppu": ppu, "pitch_from_straight_down": PITCH, "yaw_of_E_row_deg": YAW,
               "feet_below_cell_centre_px": round(TZ * math.sin(math.radians(PITCH)) * ppu, 2), "variant": variant,
               "rows": [v[0] for v in VIEWS], "flip_E_row_for_W": True,
               "actions": {a: {"frames": c, "hold_ms": HOLD_MS[a]} for a, c in ACTIONS.items()},
               "head_offsets_px": HEAD_OFF, "body_bob_px": BOB_PX}, open(os.path.join(d, "sheet_info.json"), "w"), indent=1)
    return sheets, dt, px

def font(sz):
    from PIL import ImageFont
    try: return ImageFont.load_default(size=sz)
    except TypeError: return ImageFont.load_default()

def yaw_compare():
    from PIL import Image, ImageDraw
    raw = tempfile.mkdtemp(prefix="blocky_yaw_")
    ppu, _ = calibrate(SIZES[0])
    cols = [("front 0", 0), ("yaw 25", 25), ("yaw 35", 35), ("yaw 45", 45)]
    run_blender(ppu, [["idle", yaw, 0, f"{raw}/{i}.png", "all", False, 0, (0, 0)] for i, (_, yaw) in enumerate(cols)] +
                [["run", yaw, 0, f"{raw}/r{i}.png", "all", False, 0, (0, 0)] for i, (_, yaw) in enumerate(cols)] +
                [["run", yaw, 2, f"{raw}/q{i}.png", "all", False, 0, (0, 0)] for i, (_, yaw) in enumerate(cols)])
    S = 6; cw = CELL * S
    img = Image.new("RGBA", (cw * 4, (cw + 22) * 3), GREEN); dr = ImageDraw.Draw(img); f = font(16)
    for i, (label, yaw) in enumerate(cols):
        for r, pre in enumerate(("", "r", "q")):
            img.alpha_composite(snap(f"{raw}/{pre}{i}.png").resize((cw, cw), Image.NEAREST), (i * cw, r * (cw + 22) + 22))
        dr.text((i * cw + 6, 2), label + "  (rows: idle / run contact A / contact B)", fill=(255, 255, 255, 255), font=f)
    os.makedirs(OUT, exist_ok=True); img.save(os.path.join(OUT, "yaw_compare_4x.png"))

def before_after():
    from PIL import Image, ImageDraw
    items = []
    for lab, path in (("round 6 + arms", os.path.join(TEST, "s18_arms")), ("round 6 no arms (stick)", os.path.join(TEST, "s18_noarms")), ("NEW chunky no arms", OUT)):
        for v, rowi in (("front", 0), ("side", 1)):
            items.append((f"{lab} {v}", Image.open(os.path.join(path, "idle.png")).crop((0, rowi * CELL, CELL, (rowi + 1) * CELL))))
    items.append(("soft 3D body (before)", Image.open(os.path.join(ROOT, "assets/game/characters/player/3d/idle.png")).crop((0, 0, 48, 48))))
    items.append(("old drawn player", Image.open(os.path.join(ROOT, "assets/dev/characters/player/idle/idle_1.png")).convert("RGBA")))
    S, pad = 4, 14; f = font(14)
    from PIL import ImageDraw as _D
    tw = lambda t: int(_D.Draw(Image.new("RGBA", (1, 1))).textlength(t, font=f))
    boxes = [(l, im.crop(im.getbbox())) for l, im in items]
    ws = [max(b.width * S, tw(l)) for l, b in boxes]
    W = sum(w + pad for w in ws) + pad; H = max(b.height for _, b in boxes) * S + 50
    img = Image.new("RGBA", (W, H), GREEN); dr = ImageDraw.Draw(img); x = pad
    for (label, b), w in zip(boxes, ws):
        big = b.resize((b.width * S, b.height * S), Image.NEAREST)
        img.alpha_composite(big, (x + (w - big.width) // 2, H - 10 - big.height))
        dr.text((x, 6), label, fill=(255, 255, 255, 255), font=f); dr.text((x, 24), f"{b.width}x{b.height}px", fill=(255, 255, 160, 255), font=f)
        x += w + pad
    img.save(os.path.join(OUT, "before_after_4x.png"))

def shape_compare():
    """4x side by side: round-6 arms variant, the 'cube thick' version, the NEW shaped body (idle / run contact / hit, front + side)."""
    from PIL import Image, ImageDraw
    def cell(path, act, row, col):
        return Image.open(path).crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
    A, C, N = os.path.join(TEST, "s18_arms"), os.path.join(TEST, "cube_thick"), OUT
    groups = [("round 6 + arms", A, [("idle", 0), ("run", 2)]), ("cube-thick (rejected)", C, [("idle", 0), ("run", 2)]),
              ("NEW: 3 masses + A-stance + diagonal run", N, [("idle", 0), ("run", 0), ("run", 2), ("hit", 0)])]
    S, pad = 4, 10; f = font(14)
    items = []
    for gl, path, acts in groups:
        for act, col in acts:
            for rowi, vn in ((0, "front"), (1, "side")):
                items.append((gl, f"{act}{col} {vn}", cell(os.path.join(path, act + ".png"), act, rowi, col)))
    boxes = [(g, l, im.crop((0, 0, CELL, CELL))) for g, l, im in items]
    W = len(boxes) * (CELL * S * 0 + 14 * S + pad) + pad
    cw = 18 * S + pad
    img = Image.new("RGBA", (len(boxes) * (CELL // 2 * S + 4) + pad, 36 * S + 60), GREEN); dr = ImageDraw.Draw(img)
    x = pad; last = None
    for g, l, im in boxes:
        bb = im.getbbox()
        sp = im.crop((bb[0] - 2, 0, bb[2] + 2, CELL)) if bb else im
        big = sp.resize((sp.width * S, sp.height * S), Image.NEAREST)
        img.alpha_composite(big, (x, 30 + 0))
        if g != last:
            dr.text((x, 4), g, fill=(255, 255, 160, 255), font=f); last = g
        dr.text((x, 20), l, fill=(255, 255, 255, 255), font=font(11))
        x += big.width + 4
    img = img.crop((0, 0, x + pad, img.height))
    img.save(os.path.join(TEST, "body_shape_compare_4x.png"))

def gif_and_contact():
    from PIL import Image
    S = 4
    sheet = Image.open(os.path.join(OUT, "run.png")); n = ACTIONS["run"]; frames = []
    for f in range(n):
        im = Image.new("RGBA", (CELL * 2 * S, CELL * S), GREEN)
        for r in range(2):
            im.alpha_composite(sheet.crop((f * CELL, r * CELL, (f + 1) * CELL, (r + 1) * CELL)).resize((CELL * S, CELL * S), Image.NEAREST), (r * CELL * S, 0))
        frames.append(im.convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(OUT, "run_preview_4x.gif"), save_all=True, append_images=frames[1:], loop=0, duration=HOLD_MS["run"], disposal=2)
    rows = [Image.open(os.path.join(OUT, f"{a}.png")) for a in ACTIONS]
    W = max(r.width for r in rows); H = sum(r.height for r in rows)
    c = Image.new("RGBA", (W, H), GREEN); y = 0
    for r in rows: c.alpha_composite(r, (0, y)); y += r.height
    c.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(OUT, "contact_sheet_4x.png"))

if __name__ == "__main__":
    try:
        import bpy
        blender_part(json.load(open(sys.argv[sys.argv.index("--") + 1])))
    except ImportError:
        a = sys.argv[1:]
        if "--yaw" in a: YAW = int(a[a.index("--yaw") + 1]); VIEWS = [("S", 0), ("E", YAW)]
        if "--yaw-compare" in a:
            yaw_compare()
        else:
            size = int(a[a.index("--size") + 1]) if "--size" in a else SIZES[0]
            ppu, h = (float(a[a.index('--ppu') + 1]), size) if '--ppu' in a else (PPU_DEFAULT, size)   # calibrate() overshoots by ~1 px; PPU below was tuned by eye
            _, dt, px = full(size, ppu, "noarms")
            print(f"size {size}px (ppu {ppu}, measured {h}px, yaw {YAW}): blender {dt:.1f}s, face + no-second-head checks ok ({px} head px)")
            gif_and_contact()
            sys.path.insert(0, HERE); import build_frames; build_frames.build(OUT, "blocky_frames.tres", "res://assets/dev/characters/player/blocky/")
            before_after()
            shape_compare()
