"""Chibi -> pixel sprite sheets. Plain python3:
  python3 tools/blender/render_chibi.py                  full render (default tilt) -> assets/dev/characters/test3d_chibi/
  python3 tools/blender/render_chibi.py --compare 30,40,50   angle comparison PNG
  options: --pitch N (deg from straight down)  --ppu N  --out DIR
Rows: S SE E NE N NW W SW. Columns: frames."""
import os, sys, math, subprocess, json, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CELL = 48
PITCH = 40
PPU = 17.0
ACTIONS = {"idle": 4, "run": 8, "slash": 6}
DIRS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
PALETTE_COLORS = 32
OUTLINE = (14, 10, 20)
OUT = os.path.join(ROOT, "assets", "dev", "characters", "test3d_chibi")

def blender_part(cfg):
    import bpy
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.eevee.taa_render_samples = 1
    sc.render.resolution_x = sc.render.resolution_y = CELL
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.filter_size = 0.0
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0, 0, 0, 1)
    sc.world = w
    # sun from the top-left-front (toward the light: -X, -Y, +Z); fixed in the world, character turns under it
    sun_d = bpy.data.lights.new("sun", "SUN"); sun_d.energy = 1.6; sun_d.use_shadow = False
    sun = bpy.data.objects.new("sun", sun_d); sc.collection.objects.link(sun)
    from mathutils import Vector
    sun.rotation_euler = Vector((-0.6, -0.35, 0.75)).to_track_quat("Z", "Y").to_euler()  # +Z points at the light; sun shines along -Z
    cam_d = bpy.data.cameras.new("cam"); cam_d.type = "ORTHO"; cam_d.ortho_scale = CELL / cfg["ppu"]; cam_d.clip_end = 100
    cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
    p = math.radians(cfg["pitch"]) if "pitch" in cfg else 0
    rig = bpy.data.objects["Chibi"]
    for job in cfg["jobs"]:   # job = [pitch, action, dir, frame, filename]
        pitch, act, d, f, fn = job
        p = math.radians(pitch)
        tz = 0.72
        cam.rotation_euler = (p, 0, 0)
        cam.location = (0, -12 * math.sin(p), tz + 12 * math.cos(p))
        rig.animation_data.action = bpy.data.actions[act]
        rig.rotation_euler = (0, 0, math.radians(45 * d))
        sc.frame_set(f + 1)
        sc.render.filepath = fn
        bpy.ops.render.render(write_still=True)

def run_blender(cfg):
    cj = tempfile.mktemp(suffix=".json"); json.dump(cfg, open(cj, "w"))
    subprocess.run(["blender", "--background", os.path.join(HERE, "test_chibi.blend"),
                    "--python", __file__, "--", cj], check=True, stdout=subprocess.DEVNULL)

def clean(path, enhance=False):
    from PIL import Image
    im = Image.open(path).convert("RGBA"); px = im.load()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            px[x, y] = (r, g, b, 255) if a >= 128 else (0, 0, 0, 0)
    return im

def outline(im):
    from PIL import Image
    out = im.copy(); o = out.load(); px = im.load()
    for y in range(CELL):
        for x in range(CELL):
            if px[x, y][3]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < CELL and 0 <= ny < CELL and px[nx, ny][3]:
                    o[x, y] = OUTLINE + (255,); break
    return out

def compare(pitches):
    from PIL import Image, ImageDraw
    raw = tempfile.mkdtemp(prefix="chibi_cmp_")
    dirs = [(0, "S"), (2, "E"), (4, "N")]
    jobs = [[pt, "idle", d, 0, f"{raw}/{pt}_{d}.png"] for pt in pitches for d, _ in dirs]
    run_blender({"ppu": PPU, "jobs": jobs})
    S = 4; cw = CELL * S
    img = Image.new("RGBA", (cw * 3 + 8, (cw + 24) * len(pitches)), (60, 110, 30, 255))
    dr = ImageDraw.Draw(img)
    for r, pt in enumerate(pitches):
        for c, (d, name) in enumerate(dirs):
            im = outline(clean(f"{raw}/{pt}_{d}.png")).resize((cw, cw), Image.NEAREST)
            img.alpha_composite(im, (c * cw, r * (cw + 24) + 24))
        dr.text((4, r * (cw + 24) + 6), f"{pt} deg from straight down   (S / E / N)", fill=(255, 255, 255, 255))
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, "angle_compare_4x.png"))

def full(pitch):
    from PIL import Image
    raw = tempfile.mkdtemp(prefix="chibi_raw_")
    jobs = [[pitch, a, d, f, f"{raw}/{a}_{d}_{f}.png"] for a, n in ACTIONS.items() for d in range(8) for f in range(n)]
    t = time.time(); run_blender({"ppu": PPU, "jobs": jobs}); print(f"render {time.time() - t:.1f}s")
    frames, allpix = {}, []
    for a, n in ACTIONS.items():
        for d in range(8):
            for f in range(n):
                im = clean(f"{raw}/{a}_{d}_{f}.png"); frames[(a, d, f)] = im
                allpix += [p[:3] for p in im.getdata() if p[3]]
    strip = Image.new("RGB", (len(allpix), 1)); strip.putdata(allpix)
    pal = strip.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palimg = Image.new("P", (1, 1)); palimg.putpalette(pal.getpalette())
    os.makedirs(OUT, exist_ok=True); sheets = {}
    for a, n in ACTIONS.items():
        sheet = Image.new("RGBA", (CELL * n, CELL * 8), (0, 0, 0, 0))
        for d in range(8):
            for f in range(n):
                im = frames[(a, d, f)]
                q = im.convert("RGB").quantize(palette=palimg, dither=Image.Dither.NONE).convert("RGBA")
                q.putalpha(im.getchannel("A"))
                sheet.paste(outline(q), (f * CELL, d * CELL))
        sheet.save(os.path.join(OUT, f"{a}.png")); sheets[a] = sheet
    W = max(s.width for s in sheets.values()); H = sum(s.height for s in sheets.values())
    contact = Image.new("RGBA", (W, H), (60, 110, 30, 255)); y = 0
    for s in sheets.values(): contact.alpha_composite(s, (0, y)); y += s.height
    contact.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(OUT, "contact_sheet_4x.png"))
    json.dump({"cell": CELL, "dirs": DIRS, "actions": ACTIONS, "ppu": PPU, "pitch": pitch},
              open(os.path.join(OUT, "sheet_info.json"), "w"), indent=1)

if __name__ == "__main__":
    try:
        import bpy
        blender_cfg = json.load(open(sys.argv[sys.argv.index("--") + 1]))
        PPU = blender_cfg["ppu"]; blender_part(blender_cfg)
    except ImportError:
        a = sys.argv[1:]
        if "--ppu" in a: PPU = float(a[a.index("--ppu") + 1])
        if "--pitch" in a: PITCH = float(a[a.index("--pitch") + 1])
        if "--compare" in a: compare([float(x) for x in a[a.index("--compare") + 1].split(",")])
        else: full(PITCH)
