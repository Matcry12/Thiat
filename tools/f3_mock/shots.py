"""Screenshots of every F3 mock state (1152x648). Run from repo root:
  python3 -m http.server 8766 --bind 127.0.0.1 &   then   python3 tools/f3_mock/shots.py
"""
from pathlib import Path
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8766/tools/f3_mock/index.html"
SHOTS = [
    ("1_tune_default", "F3.q=''; F3.st.tab='tune'; F3.st.openCat='Character'; F3.st.openSec=new Set(['Player']); F3.render(); document.querySelector('#toast').classList.add('on')"),
    ("2_tune_bodyrig", "F3.st.openSec=new Set(['BodyRig']); F3.st.pinOpen=false; F3.render(); document.querySelector('#body').scrollTop=60;"),
    ("3_pinned_open", "F3.st.pinOpen=true; F3.st.openCat=null; F3.render();"),
    ("4_search_hand", "F3.q='hand'; "),
    ("5_search_heal", "F3.q='heal';"),
    ("6_actions", "F3.q=''; F3.st.tab='act'; F3.st.toggles['Boss passive']=true; F3.render();"),
    ("7_status", "F3.q=''; F3.st.tab='status'; F3.st.openSt=new Set(['Player']); F3.render();"),
    ("8_map_heavy", "F3.st.tab='tune'; F3.st.pinOpen=false; F3.st.openCat='World'; F3.st.openSec=new Set(['Map']); F3.render(); F3.find('Map.land_share').p.v=0.55; F3.startRebuild('Map.land_share'); F3.refresh(); [...document.querySelectorAll('.grp')].find(e=>e.textContent=='Island').scrollIntoView();"),
    ("9_watch_only", "F3.q=''; F3.setMode('watch');"),
]
out = Path(__file__).parent / "shots"
out.mkdir(exist_ok=True)
for f in out.glob("*.png"):
    f.unlink()
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome")
    pg = b.new_page(viewport={"width": 1152, "height": 648})
    errors = []
    pg.on("pageerror", lambda e: errors.append(str(e)))
    pg.goto(URL)
    pg.wait_for_timeout(600)
    for name, js in SHOTS:
        pg.evaluate("F3.setMode('full')")
        pg.evaluate(js)
        pg.wait_for_timeout(1500 if name.startswith("9") else 250)
        if name.startswith("8"):
            pg.wait_for_timeout(900)
        pg.locator("#stage").screenshot(path=str(out / f"{name}.png"))
    b.close()
print("errors:", errors or "none")
