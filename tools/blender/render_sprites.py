"""Renders test_knight.blend into pixel-art sprite sheets (8 dirs x frames per action).
Run with plain python3:  python3 tools/blender/render_sprites.py
It calls blender for the raw renders, then post-processes with PIL (alpha threshold, palette, outline).
Rows: S, SE, E, NE, N, NW, W, SW (character turned +45 deg per row). Columns: frames."""
import os, sys, math, subprocess, json, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CELL = 64            # px per frame cell (game draws it at 2x like the player)
PPU = 18             # pixels per blender unit -> knight ~26 px tall on screen
PITCH = 55           # camera tilt from straight-down (deg): ~35 deg above the horizon
ACTIONS = {"idle": 4, "run": 8, "slash": 6}
DIRS = ["S", "SE", "E", "NE", "N", "NW", "W", "SW"]
PALETTE_COLORS = 32
OUTLINE = (24, 18, 34)
OUT = os.path.join(ROOT, "assets", "dev", "characters", "test3d")

def blender_part(raw):
    import bpy
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x = sc.render.resolution_y = CELL
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = True
    sc.render.filter_size = 0.0
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.display.render_aa = "OFF"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light, sh.color_type = "STUDIO", "MATERIAL"
    sh.use_world_space_lighting = True      # light stays fixed while the knight turns
    sh.show_specular_highlight = False
    sh.show_object_outline = False
    sh.show_cavity = False
    sh.show_shadows = False
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = CELL / PPU
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam
    p = math.radians(PITCH)
    target = (0, 0, 0.78 + 0.0)
    cam.rotation_euler = (p, 0, 0)
    cam.location = (target[0], target[1] - 12 * math.sin(p), target[2] + 12 * math.cos(p))
    cam_d.clip_end = 100
    rig = bpy.data.objects["Knight"]
    for act, n in ACTIONS.items():
        rig.animation_data.action = bpy.data.actions[act]
        for d in range(8):
            rig.rotation_euler = (0, 0, math.radians(45 * d))
            for f in range(n):
                sc.frame_set(f + 1)
                sc.render.filepath = os.path.join(raw, f"{act}_{d}_{f}.png")
                bpy.ops.render.render(write_still=True)

def post(raw):
    from PIL import Image, ImageEnhance
    frames = {}
    allpix = []
    for act, n in ACTIONS.items():
        for d in range(8):
            for f in range(n):
                im = Image.open(os.path.join(raw, f"{act}_{d}_{f}.png")).convert("RGBA")
                a_ch = im.getchannel("A")   # Workbench studio light is dim: lift brightness + saturation
                im = ImageEnhance.Color(ImageEnhance.Brightness(im.convert("RGB")).enhance(1.35)).enhance(1.3).convert("RGBA")
                im.putalpha(a_ch)
                px = im.load()
                for y in range(CELL):
                    for x in range(CELL):
                        r, g, b, a = px[x, y]
                        if a < 128: px[x, y] = (0, 0, 0, 0)
                        else:
                            px[x, y] = (r, g, b, 255); allpix.append((r, g, b))
                frames[(act, d, f)] = im
    # one shared palette for every frame, so colours never flicker between frames
    strip = Image.new("RGB", (len(allpix), 1)); strip.putdata(allpix)
    pal = strip.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    palimg = Image.new("P", (1, 1)); palimg.putpalette(pal.getpalette())
    os.makedirs(OUT, exist_ok=True)
    sheets = {}
    for act, n in ACTIONS.items():
        sheet = Image.new("RGBA", (CELL * n, CELL * 8), (0, 0, 0, 0))
        for d in range(8):
            for f in range(n):
                im = frames[(act, d, f)]
                alpha = im.getchannel("A")
                q = im.convert("RGB").quantize(palette=palimg, dither=Image.Dither.NONE).convert("RGBA")
                px, qa = q.load(), alpha.load()
                out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0)); o = out.load()
                for y in range(CELL):
                    for x in range(CELL):
                        if qa[x, y]: o[x, y] = px[x, y]
                for y in range(CELL):             # 1 px outline (4-neighbour) on transparent pixels
                    for x in range(CELL):
                        if qa[x, y]: continue
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < CELL and 0 <= ny < CELL and qa[nx, ny]:
                                o[x, y] = OUTLINE + (255,); break
                sheet.paste(out, (f * CELL, d * CELL))
        sheet.save(os.path.join(OUT, f"{act}.png"))
        sheets[act] = sheet
    # contact sheet: all actions stacked, 4x nearest
    W = max(s.width for s in sheets.values()); H = sum(s.height for s in sheets.values())
    contact = Image.new("RGBA", (W, H), (88, 140, 70, 255)); y = 0
    for s in sheets.values():
        contact.alpha_composite(s, (0, y)); y += s.height
    contact.resize((W * 4, H * 4), Image.NEAREST).save(os.path.join(OUT, "contact_sheet_4x.png"))
    json.dump({"cell": CELL, "dirs": DIRS, "actions": ACTIONS, "ppu": PPU, "pitch": PITCH},
              open(os.path.join(OUT, "sheet_info.json"), "w"), indent=1)

if __name__ == "__main__":
    try:
        import bpy
        raw = sys.argv[sys.argv.index("--") + 1]
        blender_part(raw)
    except ImportError:
        raw = tempfile.mkdtemp(prefix="knight_raw_")
        t = time.time()
        subprocess.run(["blender", "--background", os.path.join(HERE, "test_knight.blend"),
                        "--python", __file__, "--", raw], check=True, stdout=subprocess.DEVNULL)
        print(f"render {time.time() - t:.1f}s")
        post(raw)
        print("wrote", OUT)
