"""Screenshots of every mockup screen (canvas only, 1152x648) for review.
Needs the mock served: python3 -m http.server 8765 --bind 127.0.0.1 (from the repo root).
  python3 tools/ui_mock/shots.py <out_dir>
"""
import sys
from pathlib import Path

from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8765/tools/ui_mock/index.html"
# (file name, JS run before the shot): hover / state set so each shot shows the interactive look too
SHOTS = [
    ("title", "go('title'); hover='play'; draw();"),
    ("hud", "go('hud');"),
    ("pause", "go('pause'); hover='res'; draw();"),
    ("settings", "go('settings'); hover='vol'; state.full=true; draw();"),
    ("book", "go('book'); hover='b0'; state.tip=[300,190,['Wood','Material  x37']]; draw();"),
    ("book_locked", "go('book'); state.rec=4; draw();"),
    ("parts", "go('parts');"),
]

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome")
    pg = b.new_page(viewport={"width": 1300, "height": 900})
    errors = []
    pg.on("pageerror", lambda e: errors.append(str(e)))
    pg.goto(URL)
    pg.wait_for_timeout(500)
    pg.eval_on_selector("canvas", "c => { c.style.width = '1152px'; c.style.maxWidth = 'none'; }")
    for name, js in SHOTS:
        pg.evaluate(js)
        pg.wait_for_timeout(50)
        pg.locator("canvas").screenshot(path=str(out / f"{name}.png"))
    b.close()
print("errors:", errors or "none")
print("\n".join(str(out / f"{n}.png") for n, _ in SHOTS))
