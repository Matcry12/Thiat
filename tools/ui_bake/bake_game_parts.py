"""Deterministic $0 bake of the game UI parts. Run from repo root:  python3 tools/ui_bake/bake_game_parts.py
Serves the repo on 127.0.0.1 (free port), opens tools/ui_bake/game_parts.html in headless Chromium, writes
assets/ui/game/<part>.png + slices.json and tools/f3_mock/game_shots/game_parts_sheet.png. Same input -> same bytes.
"""
import base64, json, socket, subprocess, sys, time
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/ui/game"
SHEET = ROOT / "tools/f3_mock/game_shots/game_parts_sheet.png"

s = socket.socket(); s.bind(("127.0.0.1", 0)); port = s.getsockname()[1]; s.close()
srv = subprocess.Popen([sys.executable, "-m", "http.server", str(port), "--bind", "127.0.0.1"], cwd=ROOT,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
try:
    time.sleep(0.8)
    with sync_playwright() as p:
        b = p.chromium.launch(channel="chrome")
        pg = b.new_page(viewport={"width": 1500, "height": 900})
        errs = []
        pg.on("pageerror", lambda e: errs.append(str(e)))
        pg.goto(f"http://127.0.0.1:{port}/tools/ui_bake/game_parts.html")
        pg.wait_for_function("window.SHEET_READY||window.BAKE_ERR", timeout=20000)
        err = pg.evaluate("window.BAKE_ERR")
        if err or errs:
            sys.exit(f"bake page error: {err or errs}")
        parts = pg.evaluate("PARTS.map(p=>({name:p.name,w:p.canvas.width,h:p.canvas.height,url:p.canvas.toDataURL('image/png'),slice:p.slice,content:p.content,center:p.center,note:p.note||null,box:p.box||null,rects:p.rects||null,layout:p.layout||null}))")
        pg.locator("#sheet").screenshot(path=str(SHEET))
        b.close()
finally:
    srv.terminate(); srv.wait()

OUT.mkdir(parents=True, exist_ok=True)
SHEET.parent.mkdir(parents=True, exist_ok=True)
js = {"art_scale": 2, "note": "PNGs are art scale 1 (draw at 2x, nearest). slice/content = px of the PNG. center: tile = middle is uniform (stretch or tile ok); stretch = middle has detail, stretch only; none = fixed size.", "parts": {}}
keep = set()
for q in parts:
    (OUT / f"{q['name']}.png").write_bytes(base64.b64decode(q["url"].split(",", 1)[1]))
    keep.add(q["name"] + ".png")
    e = {"file": f"{q['name']}.png", "size": [q["w"], q["h"]]}
    for k in ("slice", "content"):
        if q[k]:
            l, t, r, bt = q[k]
            e[k] = {"left": l, "top": t, "right": r, "bottom": bt}
    e["center"] = q["center"]
    if q["note"]: e["note"] = q["note"]
    if q["box"]: e["box"] = dict(zip(("x", "y", "w", "h"), q["box"]))
    for k in ("rects", "layout"):
        if q[k]: e[k] = q[k]
    js["parts"][q["name"]] = e
for f in OUT.glob("*.png"):
    if f.name not in keep: f.unlink()
(OUT / "slices.json").write_text(json.dumps(js, indent=1) + "\n")
print(f"{len(parts)} parts -> {OUT}  sheet -> {SHEET}")
