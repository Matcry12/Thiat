"""Island Workshop F3 mock shots, both variants (1152x648). Run from repo root:
  python3 -m http.server <port> --bind 127.0.0.1 &   then   python3 tools/f3_mock/shots_workshop.py <port>
"""
import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

PORT = sys.argv[1] if len(sys.argv) > 1 else "8766"
URL = f"http://127.0.0.1:{PORT}/tools/f3_mock/workshop.html"
BASE = ("F3.setMode('full');F3.q='';F3.st.tab='tune';F3.st.modOnly=false;F3.st.openCat='Character';F3.st.openSec=new Set(['Player']);"
        "F3.st.pinOpen=true;F3.st.openSt=new Set();F3.st.toggles={'Knockback on/off':true};F3.st.rebuild=null;document.querySelector('#banner').style.display='none';document.querySelector('#toast').classList.remove('on');document.querySelector('#pop').style.display='none';F3.render();document.querySelector('#body').scrollTop=0;")
SHOTS = [
    ("tune_bodyrig", "F3.st.openSec=new Set(['BodyRig']);F3.st.pinOpen=false;F3.render();document.querySelector('#body').scrollTop=60;document.querySelector('#toast').classList.add('on')"),
    ("search_hand", "F3.q='hand';"),
    ("actions", "F3.st.tab='act';F3.st.toggles['Boss passive']=true;F3.render();"),
    ("status", "F3.st.tab='status';F3.st.openSt=new Set(['Player']);F3.render();"),
    ("map_heavy", "F3.st.pinOpen=false;F3.st.openCat='World';F3.st.openSec=new Set(['Map']);F3.render();F3.find('Map.land_share').p.v=0.55;F3.startRebuild('Map.land_share');F3.refresh();"
                  "const b=document.querySelector('#body'),g=[...document.querySelectorAll('.grp .pxw')].find(e=>e.dataset.t=='Island');b.scrollTop=g.getBoundingClientRect().top-b.getBoundingClientRect().top+b.scrollTop-66;"),
    ("watch_only", "F3.setMode('watch');"),
    # extra states of the old mock: write popup, widget rows (toggle / colour / pending / typing), danger "Sure?"
    ("write_popup", "F3.st.openSec=new Set(['BodyRig']);F3.render();document.querySelector('#wr').click();"),
    ("widgets", "F3.st.pinOpen=false;F3.st.openSec=new Set(['RunDust','Respawner']);F3.st.openCat='Character';F3.render();document.querySelector('#q').focus();"
                "const ins=[...document.querySelectorAll('input.num')];ins[0].focus();ins[0].value='3.5';ins[0].classList.add('pend');ins[0].blur=()=>{};"),
    ("danger_sure", "F3.st.tab='act';F3.render();[...document.querySelectorAll('.btn.danger')][0].click();"),
]
out = Path(__file__).parent / "shots_workshop"
out.mkdir(exist_ok=True)
for f in out.glob("b_*.png"):
    f.unlink()
with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome")
    pg = b.new_page(viewport={"width": 1152, "height": 648})
    errors = []
    pg.on("pageerror", lambda e: errors.append(str(e)))
    pg.goto(URL)
    pg.wait_for_timeout(600)
    for v in ("b",):
        pg.evaluate(f"F3.setV('{v}')")
        for name, js in SHOTS:
            pg.evaluate(BASE)
            pg.evaluate(js)
            pg.wait_for_timeout(1500 if name == "watch_only" else 300)
            if name == "map_heavy":
                pg.wait_for_timeout(300)
            pg.locator("#stage").screenshot(path=str(out / f"{v}_{name}.png"))
    b.close()
print("errors:", errors or "none")
