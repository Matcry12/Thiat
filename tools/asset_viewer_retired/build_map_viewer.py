# RETIRED with the old map art (Floors_Tiles / Rocks / Water_tiles / Vegetation are in assets/retired/map/ and assets/source/map/). Kept as the reference of the GDScript ports (MapGen, BiomeVeg).
"""Build tools/asset_viewer_retired/map_assets.html: every map-related sprite sheet, with the
regions the game actually uses (read from data/maps + data/resource_nodes .tres) outlined.

Run: python3 tools/asset_viewer_retired/build_map_viewer.py   (re-run after changing any .tres)
"""
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).with_name("map_assets.html")
DATA_DIRS = ["data/maps", "data/resource_nodes"]
# Sheets shown even when nothing uses them (what is available to pick from).
LIBRARY_GLOBS = [
    "assets/game/map/*.png",
    "assets/game/world/*.png",
    "assets/game/stations/*.png",
    "assets/source/third_party/pixel_crawler/Environment/Tilesets/*.png",
    "assets/source/third_party/pixel_crawler/Environment/Props/Static/*.png",
    "assets/source/third_party/pixel_crawler/Environment/Props/Static/Trees/*/*.png",
    "assets/source/third_party/serene_village/*.png",
    "assets/source/third_party/serene_village/Construct 3/*.png",
    "assets/source/third_party/serene_village/Animated stuff/*16x16.png",
]
PACKS = {  # third_party folder -> (creator, pack, license); see assets/source/third_party/README.md
    "pixel_crawler": ("Anokolisa", "Pixel Crawler 2.11", "credit not required, no resale"),
    "serene_village": ("LimeZu", "Serene Village 16x16", "CC BY 4.0, credit required"),
}
OWN = ("Own", "Project placeholder", "ours")
# Edited copies a file hash cannot trace back (docs/wiki/credits.md).
# trees_sv.png = Pixel Crawler tree sheet + Serene Village trees pasted in the bottom row.
MIXED = ("Mixed", "Pixel Crawler + Serene Village", "both licenses apply, LimeZu credit required")
ORIGIN_OVERRIDE = {"assets/game/world/trees_sv.png": MIXED, "assets/game/stations/anvil.png": OWN}
TEX_KEYS = {"texture", "tileset_texture", "water_texture", "edge_texture"}
NUM = r"-?[\d.]+"
RECT = re.compile(rf"Rect2i?\(({NUM}), ({NUM}), ({NUM}), ({NUM})\)")
CELL = re.compile(rf"Vector2i\(({NUM}), ({NUM})\)")


def parse_tres(path):
    """-> list of {set, field, texture, rects:[[x,y,w,h]]}"""
    text = path.read_text()
    ext = dict(re.findall(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="([^"]+)"\]', text))
    ext = {v: k for k, v in ext.items()}  # id -> path
    out = []
    for header, body in re.findall(r"^\[(sub_resource[^\]]*|resource)\]\n(.*?)(?=^\[|\Z)", text, re.M | re.S):
        sid = re.search(r'id="([^"]+)"', header)
        name = f"{path.stem}:{sid.group(1) if sid else 'main'}"
        fields = dict(re.findall(r"^(\w+) = (.*)$", body, re.M))
        tex = {k: ext.get(re.search(r'"([^"]+)"', v).group(1)) for k, v in fields.items()
               if k in TEX_KEYS and "ExtResource" in v}
        tile = int(fields.get("tile_size", 16))
        for key, val in fields.items():
            if key == "edge_tiles":
                continue  # ponytail: edge tiles are relative to an edge window, not drawn
            rects = [[float(n) for n in m] for m in RECT.findall(val)]
            if not rects and key.endswith("fills"):
                rects = [[int(x) * tile, int(y) * tile, tile, tile] for x, y in CELL.findall(val)]
            if not rects:
                continue
            t = tex.get("water_texture") if key.startswith("water") else (
                tex.get("edge_texture") if key == "edge_window" and "edge_texture" in tex else
                tex.get("tileset_texture") or tex.get("texture"))
            if t:
                extra = {k: fields[k] for k in ("weight", "area_weights", "on_dirt", "radii", "id",
                                                 "density_forest", "density_boss")
                         if k in fields}
                out.append({"set": name, "field": key, "texture": t, "rects": rects, "info": extra})
    return out


def md5(p):
    return hashlib.md5((ROOT / p).read_bytes()).hexdigest()


def origin(path, originals):
    """-> (pack folder or None, original third_party path or None)"""
    if path.startswith("assets/source/third_party/"):
        return path.split("/")[2], None
    src = originals.get(md5(path))
    return (src.split("/")[2], src) if src else (None, None)


def main():
    usages = [u for d in DATA_DIRS for p in sorted((ROOT / d).glob("*.tres")) for u in parse_tres(p)]
    paths = {u["texture"] for u in usages}
    for g in LIBRARY_GLOBS:
        paths |= {str(p.relative_to(ROOT)) for p in ROOT.glob(g)}
    originals = {md5(str(p.relative_to(ROOT))): str(p.relative_to(ROOT))
                 for p in (ROOT / "assets/source/third_party").rglob("*.png")}
    sheets = []
    for p in sorted(paths):
        w, h = Image.open(ROOT / p).size
        pack, copy_of = origin(p, originals)
        creator, pack_name, lic = ORIGIN_OVERRIDE.get(p) or PACKS.get(pack, OWN)
        sheets.append({"path": p, "src": "../../" + p, "w": w, "h": h, "copy_of": copy_of,
                       "creator": creator, "pack": pack_name, "license": lic,
                       "used": any(u["texture"] == p for u in usages)})
    html = TEMPLATE.replace("/*DATA*/", json.dumps({"sheets": sheets, "usages": usages}))
    OUT.write_text(html)
    print(f"{OUT.relative_to(ROOT)}: {len(sheets)} sheets, {len(usages)} region sets")


TEMPLATE = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>Map Asset Viewer</title>
<style>
:root{--bg:#16181d;--panel:#1f232a;--fg:#e6e6e6;--mut:#8a919c;--acc:#6cc3ff}
body{margin:0;background:var(--bg);color:var(--fg);font:13px system-ui,sans-serif;display:flex;height:100vh}
#side{width:300px;overflow:auto;background:var(--panel);padding:8px;box-sizing:border-box;flex-shrink:0}
#side h3{margin:12px 4px 4px;color:var(--mut);font-size:11px;text-transform:uppercase}
.sh{padding:4px 6px;border-radius:4px;cursor:pointer;word-break:break-all}
.sh:hover{background:#2a2f38}.sh.on{background:#2d4a63}.sh small{color:var(--mut)}
.cr{font-size:10px;padding:0 4px;border-radius:3px;margin-left:4px;color:#111}
.warn{background:#4a3315;border:1px solid #a8701e;padding:6px 8px;border-radius:4px;margin:6px 0;font-size:12px}
select{background:#2a2f38;color:var(--fg);border:1px solid #3a3f48;padding:3px}
.dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#5c5;margin-right:4px}
#main{flex:1;overflow:auto;padding:12px}
#bar{display:flex;gap:14px;align-items:center;flex-wrap:wrap;margin-bottom:8px}
#wrap{position:relative;display:inline-block;background:repeating-conic-gradient(#2a2a2a 0 25%,#333 0 50%) 0 0/16px 16px}
canvas{image-rendering:pixelated;display:block}
#hover{color:var(--acc);min-height:18px;font-family:monospace}
#legend span{margin-right:10px;cursor:pointer;white-space:nowrap}
#legend span.off{opacity:.35}
.set{margin:14px 0}.set h4{margin:4px 0}.set .meta{color:var(--mut);font-family:monospace;font-size:11px}
.crops{display:flex;flex-wrap:wrap;gap:6px;align-items:flex-end}
.crops canvas{background:#2c3a2c;border:1px solid #3a3f48}
</style></head><body>
<div id="side"><label>Creator <select id="cf"><option value="">All</option></select></label>
<div id="lic" class="meta" style="color:var(--mut);margin:4px 0"></div><div id="mix"></div><div id="list"></div></div>
<div id="main">
 <div id="bar">
  <b id="title"></b>
  <label>Zoom <input id="zoom" type="range" min="1" max="8" value="3"> <span id="zv">3x</span></label>
  <label><input id="grid" type="checkbox" checked> 16px grid</label>
  <label><input id="boxes" type="checkbox" checked> used regions</label>
 </div>
 <div id="legend"></div>
 <div id="hover"></div>
 <div id="wrap"><canvas id="cv"></canvas></div>
 <div id="sets"></div>
</div>
<script>
const D=/*DATA*/;
const COLORS=['#ff5d5d','#ffb347','#ffe35d','#7dff7d','#5dd5ff','#b78cff','#ff7de0','#ffffff','#9cff3d','#3dffd0','#ff9c3d','#8ca8ff'];
const $=id=>document.getElementById(id);
const imgs={};let cur=null,hidden=new Set();
function img(s){return imgs[s.path]||(imgs[s.path]=Object.assign(new Image(),{src:s.src}))}
function usagesOf(p){return D.usages.filter(u=>u.texture===p)}
const CR=[...new Set(D.sheets.map(s=>s.creator))],CC={};CR.forEach((c,k)=>CC[c]=COLORS[(k*3+4)%COLORS.length]);
const by=p=>D.sheets.find(s=>s.path===p);
function mixes(){ // map styles / nodes that pull art from more than one creator = style clash
  const st={};D.usages.forEach(u=>{const f=u.set.split(':')[0];(st[f]=st[f]||new Set).add(by(u.texture).creator)});
  return Object.entries(st).filter(([f,c])=>c.size>1).map(([f,c])=>`<div class=warn>⚠ <b>${f}</b> mixes ${[...c].join(' + ')}</div>`).join('')}
function side(){
  const f=$('cf').value,lic=[...new Set(D.sheets.filter(s=>s.creator===f).map(s=>s.pack+': '+s.license))];
  $('lic').textContent=lic.join(' · ');$('mix').innerHTML=f?'':mixes();
  const g={used:[],lib:[]};D.sheets.filter(s=>!f||s.creator===f).forEach(s=>g[s.used?'used':'lib'].push(s));
  $('list').innerHTML=`<h3>Used by the game</h3>${g.used.map(row).join('')}<h3>Available (not used)</h3>${g.lib.map(row).join('')}`;
  function row(s){return `<div class="sh" data-p="${s.path}">${s.used?'<span class=dot></span>':''}${s.path.split('/').pop()}<span class=cr style="background:${CC[s.creator]}">${s.creator}</span><br><small>${s.path.split('/').slice(0,-1).join('/')} · ${s.w}x${s.h}${s.copy_of?'<br>copy of '+s.copy_of.replace('assets/source/third_party/',''):''}</small></div>`}
  document.querySelectorAll('.sh').forEach(e=>e.onclick=()=>show(e.dataset.p));
}
function show(p){
  cur=D.sheets.find(s=>s.path===p);hidden.clear();
  document.querySelectorAll('.sh').forEach(e=>e.classList.toggle('on',e.dataset.p===p));
  $('title').textContent=`${p} — ${cur.creator} (${cur.pack}, ${cur.license})`;history.replaceState(null,'','#'+encodeURIComponent(p));
  const i=img(cur);i.complete?draw():i.onload=draw;
}
function draw(){
  const z=+$('zoom').value,s=cur,i=img(s),cv=$('cv'),c=cv.getContext('2d');
  $('zv').textContent=z+'x';cv.width=s.w*z;cv.height=s.h*z;c.imageSmoothingEnabled=false;
  c.drawImage(i,0,0,s.w*z,s.h*z);
  if($('grid').checked&&z>=2){c.strokeStyle='rgba(255,255,255,.12)';c.lineWidth=1;c.beginPath();
    for(let x=0;x<=s.w;x+=16){c.moveTo(x*z+.5,0);c.lineTo(x*z+.5,s.h*z)}
    for(let y=0;y<=s.h;y+=16){c.moveTo(0,y*z+.5);c.lineTo(s.w*z,y*z+.5)}c.stroke()}
  const us=usagesOf(s.path);
  $('legend').innerHTML=us.map((u,k)=>`<span data-k="${k}" class="${hidden.has(k)?'off':''}" style="color:${COLORS[k%COLORS.length]}">■ ${u.set} · ${u.field} (${u.rects.length})</span>`).join('');
  document.querySelectorAll('#legend span').forEach(e=>e.onclick=()=>{const k=+e.dataset.k;hidden.has(k)?hidden.delete(k):hidden.add(k);draw()});
  if($('boxes').checked)us.forEach((u,k)=>{if(hidden.has(k))return;c.strokeStyle=COLORS[k%COLORS.length];c.lineWidth=Math.max(1,z/2);
    u.rects.forEach(([x,y,w,h])=>c.strokeRect(x*z,y*z,w*z,h*z))});
  $('sets').innerHTML=us.map((u,k)=>`<div class="set"><h4 style="color:${COLORS[k%COLORS.length]}">${u.set} · ${u.field}</h4>
    <div class="meta">${Object.entries(u.info).map(([a,b])=>a+' = '+b).join(' · ')}</div><div class="crops" id="cr${k}"></div></div>`).join('');
  us.forEach((u,k)=>u.rects.forEach(([x,y,w,h])=>{const e=document.createElement('canvas'),cz=Math.max(2,z);
    e.width=w*cz;e.height=h*cz;e.title=`Rect2(${x}, ${y}, ${w}, ${h})`;const ec=e.getContext('2d');ec.imageSmoothingEnabled=false;
    ec.drawImage(i,x,y,w,h,0,0,w*cz,h*cz);$('cr'+k).appendChild(e)}));
}
$('cv').onmousemove=ev=>{if(!cur)return;const z=+$('zoom').value,r=ev.target.getBoundingClientRect(),
  x=Math.floor((ev.clientX-r.left)/z),y=Math.floor((ev.clientY-r.top)/z);
  const hits=usagesOf(cur.path).flatMap(u=>u.rects.filter(([a,b,w,h])=>x>=a&&y>=b&&x<a+w&&y<b+h).map(q=>`${u.set}.${u.field} Rect2(${q.join(', ')})`));
  $('hover').textContent=`px (${x}, ${y})  cell (${x>>4}, ${y>>4})  ${hits.join(' | ')}`};
['zoom','grid','boxes'].forEach(id=>$(id).oninput=()=>cur&&draw());
CR.forEach(c=>$('cf').add(new Option(c,c)));$('cf').onchange=()=>{side();cur&&show(cur.path)};
side();show(decodeURIComponent(location.hash.slice(1))||D.sheets.find(s=>s.used).path);
</script></body></html>
"""

if __name__ == "__main__":
    main()
