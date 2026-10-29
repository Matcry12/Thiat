#!/usr/bin/env python3
"""Bake Island Workshop pixel fonts (Body, Bold, Small) to BMFont .fnt + PNG atlases.
Source of truth: glyph tables in tools/ui_mock/index.html (fallback: tools/f3_mock/workshop.html).
Run: python3 tools/ui_bake/bake_fonts.py   (deterministic, $0)
Out: assets/ui/fonts/<name>.png/.fnt (white glyphs, 1 art px = 1 texel)
     assets/ui/fonts/<name>_ring.png (same layout, 1 px 8-neighbour dilation, for the OUT outline)
"""
import re, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUTDIR = os.path.join(ROOT, "assets/ui/fonts")
SRC = [open(os.path.join(ROOT, p), encoding="utf-8").read()
       for p in ("tools/ui_mock/index.html", "tools/f3_mock/workshop.html")]

PAIR = re.compile(r'''(?:"(.{1,2}?)"|'(.)'|([A-Za-z0-9_]+))\s*:\s*"([^"]*)"''')

def table(src, name):
    """Parse `const NAME={...};` (one level, string values) -> dict."""
    m = re.search(r'const %s=\{(.*?)\};' % name, src, re.S)
    return {a or b or c: d for a, b, c, d in PAIR.findall(m.group(1))} if m else {}

def extras(src, name):
    """Parse Object.assign(NAME,{...}); blocks."""
    d = {}
    for m in re.finditer(r'Object\.assign\(%s,\{(.*?)\}\);' % name, src, re.S):
        d.update({a or b or c: v for a, b, c, v in PAIR.findall(m.group(1))})
    return d

ui, ws = SRC
UP = {**extras(ws, "UP"), **table(ws, "UP"), **table(ui, "UP")}
LO = {**table(ws, "LO"), **table(ui, "LO")}
BOLD = {**table(ws, "BOLD"), **table(ui, "BOLD")}
SM = {**table(ws, "SM"), **table(ui, "SMALL")}        # ui_mock wins
ICO, ICS = table(ws, "ICO"), table(ws, "ICS")
FIX = {"–": "-", "—": "-", "’": "'"}
for t in (ICO, ICS):
    t.pop("✓x", None)
BODY = {**UP, **LO}

def rows(s): return s.split("|")

def glyph(font, ch):
    """-> (rows, advance, bold_double). Mirrors ui_mock text()/workshop G()/adv()."""
    ch = FIX.get(ch, ch)
    if font == "small":
        r = ICS.get(ch) or SM.get(ch) or SM.get(ch.upper()) or SM["?"]
        r = rows(r); return r, len(r[0]) + 1, False
    if ch in ICO:
        r = rows(ICO[ch]); return r, len(r[0]) + 1, False
    bold = font == "bold"
    if bold and ch in BOLD:
        r = rows(BOLD[ch]); return r, len(r[0]) + 1, False
    r = rows(BODY.get(ch) or BODY["?"] if ch != " " else BODY[" "])
    return r, len(r[0]) + 1 + (1 if bold else 0), bold

def bitmap(r, dbl):
    h, w = len(r), len(r[0]) + (1 if dbl else 0)
    px = set()
    for j, row in enumerate(r):
        for i, c in enumerate(row):
            if c == "#":
                px.add((i, j))
                if dbl: px.add((i + 1, j))
    return w, h, px

def chars():
    s = list(range(32, 127)) + sorted(ord(c) for c in set(ICO) | set(ICS) | set(FIX) if len(c) == 1)
    return s

def bake(font, name, rows_h, base):
    cp = chars(); AW = 256; GAP = 4
    items = []
    for c in cp:
        r, adv, dbl = glyph(font, chr(c)); w, h, px = bitmap(r, dbl)
        items.append((c, w, h, px, adv))
    x = y = 1; rowh = 0; place = {}
    for c, w, h, px, adv in items:
        if x + w + GAP > AW: x = 1; y += rowh + GAP; rowh = 0
        place[c] = (x, y); x += w + GAP; rowh = max(rowh, h)
    AH = 1
    while AH < y + rowh + 2: AH *= 2
    img = Image.new("RGBA", (AW, AH), (0, 0, 0, 0)); ring = img.copy()
    for c, w, h, px, adv in items:
        ox, oy = place[c]
        for (i, j) in px:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1): ring.putpixel((ox + i + dx, oy + j + dy), (255, 255, 255, 255))
        for (i, j) in px: img.putpixel((ox + i, oy + j), (255, 255, 255, 255))
    img.save(os.path.join(OUTDIR, name + ".png")); ring.save(os.path.join(OUTDIR, name + "_ring.png"))
    L = [f'info face="{name}" size={rows_h} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
         f"common lineHeight={rows_h} base={base} scaleW={AW} scaleH={AH} pages=1 packed=0",
         f'page id=0 file="{name}.png"', f"chars count={len(items)}"]
    for c, w, h, px, adv in items:
        ox, oy = place[c]
        L.append(f"char id={c} x={ox} y={oy} width={w} height={h} xoffset=0 yoffset=0 xadvance={adv} page=0 chnl=15")
    L.append("kernings count=0")
    open(os.path.join(OUTDIR, name + ".fnt"), "w").write("\n".join(L) + "\n")
    print(name, len(items), "glyphs", AW, "x", AH)

if __name__ == "__main__":
    bake("body", "body", 9, 7)
    bake("bold", "bold", 9, 7)
    bake("small", "small", 5, 5)
