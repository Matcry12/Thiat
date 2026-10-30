"""Water v2 ($0): take the recoloured pond of the mock patch and turn the flat blue into water.
Clean fill (no dirt squares), bank band + foam line, depth shades by distance to land, 4 animation frames.
Run: python3 tools/art_tests/recolour/water.py -> water_patch.png, water_anim.gif, out/water_*.png"""
import os, random
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
import recolour as rc
import pixel_plains_tiles as pp

W_FILL, W_PATCH, W_SHADOW = rc.GROUND["water"][rc.DIRT[0]], rc.GROUND["water"][rc.DIRT[1]], rc.GROUND["water"][rc.DIRT[2]]
# depth shades, shallow -> deep (px distance to land where each ends), then bank band + foam + mark lift
SHADES = [((12), (112,210,228)), ((28), (88,190,216)), ((48), (66,166,204)), ((999), (48,138,192))]
DEEP_R_PX, DEEP_SOFT = 19, 12   # style "flat": deep = water px >= DEEP_R_PX px from land; corners rounded by a DEEP_SOFT px disk
FOAM_GAP, FOAM_KEEP = 14, 0.55   # flat foam: at most 1 dash per FOAM_GAP px block, kept with this chance
FLAT_SHALLOW, FLAT_DEEP, FLAT_EDGE = (112, 210, 228), (72, 172, 208), (52, 140, 188)
RECT_EDGE, RECT_EDGE_SOFT = (62, 158, 200), (92, 191, 218)   # rect_edge outline/dither: a touch darker than deep | soft: halfway shallow<->deep
BAND, BAND_DARK, FOAM = (40,112,166), (30,88,140), (218,246,252)
POND = (11*16, 0, 24*16, 11*16)   # same rect recolour.patch() swaps
NF = 4
FRAMES, FPS = 8, 8          # smooth loop: frame count + fps of the 8-frame version (4-frame v3 stays NF=4, 4 fps)

def hnoise(x, y, seed=0):  # cheap stable per-pixel hash 0..1
    h = (x * 73856093) ^ (y * 19349663) ^ (seed * 83492791); h = (h ^ (h >> 13)) * 1274126177 & 0xffffffff
    return (h & 0xffff) / 65535

def lighten(c, k=38): return tuple(min(255, int(v) + k) for v in c[:3])

def rect_deep(water, B=8):   # flat_rect deep px: water 8 px blocks more than 2 blocks from land (non-water blocks deep too; masked by water later)
    H, Wd = water.shape; hb, wb = H // B, Wd // B
    blk = water[:hb * B, :wb * B].reshape(hb, B, wb, B).mean((1, 3)) > 0.5
    shal_b = blk & ndimage.binary_dilation(~blk, structure=np.ones((3, 3)), iterations=2)
    sh = np.zeros((H, Wd), bool); sh[:hb * B, :wb * B] = np.kron(shal_b, np.ones((B, B), bool))
    return ~sh

def water_frames(old, v3=False, nf=NF, smooth=False, shadowfix=True, rect=POND, style="flat_plain", cells=None):
    """old = patch(True) RGBA. Returns list of NF full images with the pond redrawn."""
    crop = np.array(old.crop(rect))
    wmask = ((crop[..., :3] == W_FILL[:3]).all(2) | (crop[..., :3] == W_PATCH[:3]).all(2))
    shadow = (crop[..., :3] == W_SHADOW[:3]).all(2)
    water = wmask | shadow                                  # shadow px sit on the water side of the outline
    d = ndimage.distance_transform_edt(water)               # px to nearest land/outline
    H, Wd = water.shape
    def land_above(k):  # land within k px straight up
        m = np.zeros_like(water)
        for i in range(1, k + 1): m[i:] |= ~water[:-i]
        return m
    def land_left(k):
        m = np.zeros_like(water)
        for i in range(1, k + 1): m[:, i:] |= ~water[:, :-i]
        return m
    def land_below(k):
        m = np.zeros_like(water)
        for i in range(1, k + 1): m[:-i] |= ~water[i:]
        return m
    def land_right(k):
        m = np.zeros_like(water)
        for i in range(1, k + 1): m[:, :-i] |= ~water[:, i:]
        return m
    shadow = shadow & (d <= 2.5)                            # shadows of the old dirt squares inside the pond are not bank
    if shadowfix:   # shadow falls down-right: only banks ABOVE / LEFT of the water cast it; south + east banks face the viewer / light
        lit = land_above(3) | land_left(2)
        shadow = shadow & lit
        band = water & ((land_above(3) & (d <= 3.5)) | (land_left(2) & (d <= 2.5)))
        wet = water & ~band & (land_below(1) | land_right(1))      # 1 px light wet edge instead
    else:
        band = water & ((d <= 1.5) | (land_above(3) & (d <= 3.5)) | (land_left(2) & (d <= 2.5)))
        wet = np.zeros_like(water)
    # depth class with a ragged border so bands are not smooth contours
    ys, xs = np.mgrid[0:H, 0:Wd]
    noise = np.vectorize(lambda x, y: hnoise(x // 5, y // 5, 5))(xs, ys)
    dn = d + (noise - .5) * 5
    base = np.zeros((H, Wd, 3), np.uint8)
    cls = np.zeros((H, Wd), int)
    for i, (lim, col) in enumerate(SHADES):
        m = (dn < lim) & (cls == 0) if i == 0 else (dn < lim) & ~np.isin(cls, range(1, i + 1)) & (cls == 0)
    prev = -99
    for i, (lim, col) in enumerate(SHADES):
        m = (dn >= prev) & (dn < lim); base[m] = col; cls[m] = i; prev = lim
    flat = style.startswith("flat")
    if style == "flat":   # deep = pixel inset copy of the lake: EDT to land >= DEEP_R_PX, rounded by a disk open/close, snapped to 2 px
        deep = d >= DEEP_R_PX
        yy, xx = np.mgrid[-DEEP_SOFT:DEEP_SOFT + 1, -DEEP_SOFT:DEEP_SOFT + 1]; disk = xx ** 2 + yy ** 2 <= DEEP_SOFT ** 2
        deep = ndimage.binary_closing(ndimage.binary_opening(deep, disk), disk, border_value=0)
        h2, w2 = H // 2 * 2, Wd // 2 * 2
        snap = np.zeros_like(deep); snap[:h2, :w2] = np.kron(deep[:h2, :w2].reshape(H // 2, 2, Wd // 2, 2).mean((1, 3)) >= 0.5, np.ones((2, 2), bool))
        deepf = snap & water
        base[:] = FLAT_SHALLOW; base[deepf] = FLAT_DEEP
        print("flat deep px:", int(deepf.sum()), "(x9 panel:", int(deepf.sum()) * 9, ")")
    elif style in ("flat_linked_v1", "flat_rect_edge", "flat_rect_edge_soft", "flat_rect_pattern"):   # deep cells + the pack's dark_on_light dual-grid edge (dark grass -> deep, light -> shallow, outline/dither -> edge blue)
        hc, wc = H // 16, Wd // 16
        if style == "flat_linked_v1":   # v1: chessboard cell inset 2 + dotted darker outline
            wcell = cells if cells is not None else water[:hc * 16, :wc * 16].reshape(hc, 16, wc, 16).mean((1, 3)) > 0.4
            deep = ndimage.distance_transform_cdt(wcell, metric="chessboard") >= 2
            cross = ndimage.generate_binary_structure(2, 1)
            deep = ndimage.binary_closing(ndimage.binary_opening(deep, cross), cross) & wcell
            edge_col = FLAT_EDGE
        else:                           # rect_edge: exactly flat_rect's deep (8 px blocks, 2-block shallow band), taken per 16 px cell
            dpx = rect_deep(water) & water; deep = dpx[:hc * 16, :wc * 16].reshape(hc, 16, wc, 16).mean((1, 3)) > 0.5   # cells MORE than half deep in flat_rect: its 8 px half-cell steps drop (closest area to flat_rect)
            edge_col = FLAT_DEEP if style == "flat_rect_pattern" else RECT_EDGE_SOFT if style.endswith("soft") else RECT_EDGE   # pattern: outline px join deep -> only the notch shape, no line
        gd = lambda x, y: deep[min(max(y, 0), hc - 1), min(max(x, 0), wc - 1)]
        base[:] = FLAT_SHALLOW
        for j in range(hc + 1):
            for i in range(wc + 1):
                mask = sum(b for b, (cx, cy) in zip((1, 2, 4, 8), ((i - 1, j - 1), (i, j - 1), (i - 1, j), (i, j))) if gd(cx, cy))
                if not mask: continue
                x0, y0 = i * 16 - 8, j * 16 - 8; xa, ya = max(x0, 0), max(y0, 0); xb, yb = min(x0 + 16, Wd), min(y0 + 16, H)
                t = np.array(pp.tile_image("dark_on_light", mask)[0])[..., :3]
                A, Cc = (t == (59, 125, 79)).all(2), (t == (42, 89, 79)).all(2)
                base[ya:yb, xa:xb] = np.where(A[..., None], FLAT_DEEP, np.where(Cc[..., None], edge_col, FLAT_SHALLOW))[ya - y0:yb - y0, xa - x0:xb - x0]
    elif style == "flat_plain":   # no deep area: one shallow fill (foam, marks, bank band unchanged)
        base[:] = FLAT_SHALLOW
    elif flat:   # flat_rect, pack-like: ONE deep fill + a shallow band 1 cell wide, edge snapped to the 8 px block grid
        base[:] = FLAT_SHALLOW; base[rect_deep(water)] = FLAT_DEEP
    # wave marks: per 16 px tile, 0-2 small "~" dashes, seeded, only on interior water
    marks = []
    if flat:   # ~1 straight 3-5 px dash per 2x2 cells
        for ty in range(H // 32 + 1):
            for tx in range(Wd // 32 + 1):
                r = random.Random(ty * 1000 + tx + 77)
                if r.random() < .85: marks.append((tx * 32 + r.randint(2, 22), ty * 32 + r.randint(2, 28), r.randint(3, 5), r.randint(0, 3)))
    for ty in (range(0) if flat else range(H // 16 + 1)):
        for tx in range(Wd // 16 + 1):
            r = random.Random(ty * 1000 + tx)
            for _ in range(r.choice([0, 1, 1, 2])):
                marks.append((tx*16 + r.randint(1, 10), ty*16 + r.randint(1, 14), r.randint(3, 5), r.randint(0, 3)))
    if v3:
        from scipy.ndimage import uniform_filter
        hv = lambda bx, by, seed: np.vectorize(lambda x, y: hnoise(x // bx, y // by, seed))(xs, ys)
        NOISE_T, H2, H3, H4 = hv(6, 6, 21), hv(2, 2, 11), hv(2, 2, 12), hv(1, 1, 13)
        FRAC = uniform_filter(water.astype(float), 9)
        from scipy.ndimage import gaussian_filter                  # spatially smooth 1 px noise -> pieces grow/shrink 1 px per step
        rr = gaussian_filter(np.vectorize(lambda x, y: hnoise(x, y, 31))(xs, ys), 1.3)
        H2S = (np.argsort(np.argsort(rr.ravel())).reshape(rr.shape) / rr.size)
    dashes = []
    if flat:   # foam: sparse short horizontal dashes 2-4 px off the bank (land or dark band), on every shore
        d2 = ndimage.distance_transform_edt(water & ~band)
        ring = water & ~band & (d2 >= 2) & (d2 <= 4)
        dash_ok = water & ~band & (d2 >= 2) & (d2 <= 8)       # a dash may run out to 8 px where the shore is vertical
        gx = np.gradient(d2, axis=1); r = random.Random(41)
        hsh = np.vectorize(lambda x, y: hnoise(x, y, 17))(xs, ys) * ring
        for by in range(0, H, FOAM_GAP):
            for bx in range(0, Wd, FOAM_GAP):
                blk = hsh[by:by + FOAM_GAP, bx:bx + FOAM_GAP]
                if blk.max() <= 0 or r.random() > FOAM_KEEP: continue
                y, x = np.unravel_index(blk.argmax(), blk.shape); y += by; x += bx
                dash_dir = 1 if gx[y, x] >= 0 else -1      # grow away from the bank
                dashes.append((x, y, dash_dir, r.randint(4, 5), r.randint(0, 3)))
    frames = []
    for f in range(nf):
        t = f / nf
        out = base.copy()
        out[band] = BAND
        out[wet] = np.array([lighten(tuple(b), 34) for b in base[wet]], np.uint8).reshape(-1, 3)
        out[shadow] = BAND_DARK
        # foam: broken 1 px line, distance shifts 1 px on frames 1-2
        fd = 6 + (1 if f in (1, 2) else 0)
        fn = np.vectorize(lambda x, y: hnoise(x, y, 9))(xs, ys)
        foam = water & (np.abs(d - fd) < 0.5) & (fn > .3) & ~band
        if v3:
            # broken pieces 2-6 px, distance from bank varies 4.5..7 along the shore, more foam on land corners
            target = 5 + np.round(2 * NOISE_T)
            piece = (H2S if smooth else H2) + 0.2 * np.cos(2 * np.pi * (t + H3))       # pieces grow/shrink/blink over time
            thr = 0.55 - 0.5 * (FRAC - 0.5)                             # frac>0.5 = land corner poking into water
            foam = water & ~band & (np.abs(d - target) < 0.6) & (piece > thr + 0.15)
            far = water & (d >= 8) & (d <= 12) & (H4 > 0.985) & ((np.cos(2*np.pi*(t + H4*40)) > 0.2) if smooth else ((f + (H4 * 400).astype(int)) % 4 < 2))
            foam |= far
        if flat:   # foam state changes on ODD frames, marks on EVEN frames -> every frame differs, 8 distinct frames loop
            q = ((f + 1) // 2) % 4; foam = np.zeros_like(water)
            for (x, y, dr, ln, p) in dashes:
                sft, cut = [(0, 0), (1, 0), (1, 1), (0, 1)][(q + p) % 4]
                for i in range(ln - cut):
                    px = x + dr * (i + sft)
                    if 0 <= px < Wd and dash_ok[y, px]: foam[y, px] = True
        out[foam] = FOAM
        for (mx, my, ln, ph) in marks:
            if flat:     # 1 px drift + light/dark swap (no fade, no tail)
                ft = f * 8 // nf; sx = mx + [0, 0, 1, 1, 1, 1, 0, 0][(ft + 2 * ph) % 8]; k = 34 if (ft + 2 * ph) % 8 < 4 else 14
                for i in range(ln):
                    px = sx + i
                    if 0 <= my < H and 0 <= px < Wd and water[my, px] and d[my, px] >= 6 and not foam[my, px] and not band[my, px]:
                        out[my, px] = lighten(tuple(base[my, px]), k)
                continue
            if smooth:   # slow back-and-forth drift (1 px / 2 frames) + fade in/out, loops exactly
                a = 0.5 + 0.5 * np.cos(2 * np.pi * (t + ph / 4)); k = int(round(44 * a / 6)) * 6
                if k < 8: continue
                sx = mx + [0, 0, 1, 1, 2, 2, 1, 1][(f * 8 // nf + 2 * ph) % 8]
            else:
                if (ph + f) % 4 == 3: continue                  # blink
                sx = mx + ((ph + f) // 2) % 2; k = 38           # drift 1 px
            for i in range(ln):
                for (px, py) in ((sx + i, my), ) + (((sx + ln, my - 1),) if i == 0 else ()):
                    if 0 <= py < H and 0 <= px < Wd and water[py, px] and d[py, px] >= 8 and not foam[py, px]:
                        out[py, px] = lighten(tuple(base[py, px]), k)
        res = old.copy(); rgba = np.dstack([out, np.where(water, 255, crop[..., 3])]).astype(np.uint8)
        rgba[~water] = crop[~water]
        res.paste(Image.fromarray(rgba), rect[:2]); frames.append(res)
    return frames, Image.fromarray(np.dstack([base, np.full((H, Wd), 255, np.uint8)]).astype(np.uint8))

def compare(old, v2, v3):
    box = (160, 0, 384, 176); f24 = rc.font(24); pad = 20
    ims = [rc.z(im.crop(box)).convert("RGB") for im in (old, v2, v3)]
    names = ["1 old (dirt recolour)", "2 v2 (contour foam)", "3 v3 (broken foam)"]
    s = Image.new("RGB", (sum(i.width for i in ims) + 4*pad, ims[0].height + 2*pad + 30), rc.BG); d = ImageDraw.Draw(s)
    x = pad
    for n, i in zip(names, ims): d.text((x, 4), n, fill=(235,235,235), font=f24); s.paste(i, (x, 40)); x += i.width + pad
    s.save("water_compare.png")

BOX = (160, 0, 384, 176)
def smooth_all():
    f8, _ = water_frames(old_img, True, FRAMES, True, style="v3")
    f4, _ = water_frames(old_img, True, NF, False, style="v3")
    c8 = [rc.z(im.crop(BOX)).convert("RGB") for im in f8]; c4 = [rc.z(im.crop(BOX)).convert("RGB") for im in f4]
    ms = 1000 // FPS
    c8[0].save("water_anim_v3_8f.gif", save_all=True, append_images=c8[1:], duration=ms, loop=0)
    fnt = rc.font(24); pad = 20; w, h = c8[0].size; both = []
    for i in range(FRAMES):
        s = Image.new("RGB", (2*w + 3*pad, h + 2*pad + 30), rc.BG); d = ImageDraw.Draw(s)
        d.text((pad, 4), "4 frames / 4 fps", fill=(235,235,235), font=fnt); d.text((w + 2*pad, 4), f"{FRAMES} frames / {FPS} fps", fill=(235,235,235), font=fnt)
        s.paste(c4[i * NF // FRAMES], (pad, 40)); s.paste(c8[i], (w + 2*pad, 40)); both.append(s)
    both[0].save("water_anim_compare.gif", save_all=True, append_images=both[1:], duration=ms, loop=0)   # both loops last 1000 ms
    # contact sheet + jump check (changed pixels between consecutive frames, incl. last -> first)
    a = [np.array(im.crop(BOX)).astype(int) for im in f8]
    print("changed px per step:", [int((np.abs(a[i] - a[(i+1) % FRAMES]).sum(2) > 0).sum()) for i in range(FRAMES)])
    sh = Image.new("RGB", (4 * (w // 2 + pad) + pad, 2 * (h // 2 + 30 + pad) + pad), rc.BG); d = ImageDraw.Draw(sh)
    for i, im in enumerate(c8):
        x, y = pad + (i % 4) * (w // 2 + pad), pad + (i // 4) * (h // 2 + 30 + pad)
        d.text((x, y), f"frame {i}", fill=(235,235,235), font=fnt); sh.paste(im.resize((w // 2, h // 2), Image.NEAREST), (x, y + 30))
    sh.save("water_v3_8f_frames.png")
    bf, _ = water_frames(old_img, True, FRAMES, True, shadowfix=False, style="v3")
    pair = [rc.z(im.crop(BOX)).convert("RGB") for im in (bf[0], f8[0])]
    st = Image.new("RGB", (2*w + 3*pad, h + 2*pad + 30), rc.BG); d = ImageDraw.Draw(st)
    d.text((pad, 4), "before (band all round)", fill=(235,235,235), font=fnt); d.text((w + 2*pad, 4), "after (no band south / east)", fill=(235,235,235), font=fnt)
    st.paste(pair[0], (pad, 40)); st.paste(pair[1], (w + 2*pad, 40)); st.save("water_v3_8f_shadowfix.png")

if __name__ == "__main__":
    old_img = rc.patch(True)
    old = old_img
    v3f, _ = water_frames(old, True, style="v3")
    g3 = [rc.z(im).convert("RGB") for im in v3f]
    g3[0].save("water_anim_v3.gif", save_all=True, append_images=g3[1:], duration=250, loop=0)
    for f, im in enumerate(v3f): im.crop(POND).save(f"{rc.OUT}/water_v3_pond_f{f}.png")
    frames, _ = water_frames(old, style="v3")
    compare(old, frames[0], v3f[0])
    smooth_all()
    for f, im in enumerate(frames):
        im.crop(POND).save(f"{rc.OUT}/water_pond_f{f}.png")
        im.crop((14*16 + 0, 3*16, 14*16 + 32, 3*16 + 32)).save(f"{rc.OUT}/water_interior_f{f}.png")   # 32x32 open water
    a, b = rc.z(old), rc.z(frames[0]); f24 = rc.font(24); pad = 20
    s = Image.new("RGB", (a.width + b.width + 3*pad, a.height + 2*pad + 30), rc.BG); d = ImageDraw.Draw(s)
    d.text((pad, 4), "OLD water (recoloured dirt)", fill=(235,235,235), font=f24); d.text((a.width + 2*pad, 4), "NEW water (frame 0)", fill=(235,235,235), font=f24)
    s.paste(a.convert("RGB"), (pad, 40)); s.paste(b.convert("RGB"), (a.width + 2*pad, 40)); s.save("water_patch.png")
    gif = [rc.z(im).convert("RGB") for im in frames]
    gif[0].save("water_anim.gif", save_all=True, append_images=gif[1:], duration=250, loop=0)
    print("ok")
