"""Slime sprites, shape-from-code (dome mask) + shading rules. Run: python3 draw_slime.py <assets_out_dir> <preview_dir>"""
import sys, math
from PIL import Image
O=(29,35,53,255); S=(42,89,79,255); M=(74,190,92,255); H=(164,226,110,255); D=(52,150,80,255); W=(255,255,255,255)
FLASH=dict(S=(186,189,211,255), M=(255,255,255,255), H=(255,255,255,255), D=(222,226,236,255))
FS=32
def mask(w,h,flat=0.35):
    """dome: top half-ellipse, lower part straight with rounded corners. w,h incl. outline."""
    m=set(); cx=(w-1)/2
    for y in range(h):
        t=(y+0.5)/h            # 0 top .. 1 bottom
        if t<flat+0.3: k=math.sqrt(max(0,1-((flat+0.3-t)/(flat+0.3))**2))
        else: k=1.0
        if y==h-1: k=min(k,0.88)   # bottom corners softened
        half=(w/2)*k
        for x in range(w):
            if abs(x-cx)<=half-0.01 or (half>=w/2-0.5): m.add((x,y)) if abs(x-cx)<=half+0.01 else None
    return m
def body(w,h,pal,eyes=True,eyeoff=0,lean=0):
    m=mask(w,h); img={}
    inner={p for p in m if all(((p[0]+dx,p[1]+dy) in m) for dx,dy in((1,0),(-1,0),(0,1),(0,-1)))}
    for (x,y) in m:
        if (x,y) not in inner: continue
        c=pal['M']
        if (x,y+1) not in inner or (x+1,y) not in inner: c=pal['S'] if (x,y+1) not in inner else pal['D']
        elif (x,y+2) not in inner and h>8: c=pal['D']
        img[(x,y)]=c
    # outline: right/bottom full dark, top/left outline too (player has full outline)
    for p in m:
        if p not in inner: img[p]=O
    # highlights top-left
    ys=[y for _,y in inner]
    if h>=10 and inner:
        y0=min(ys); xs=[x for x,y in inner if y==y0+1]
        x0=min(x for x,y in inner if y==y0+2) if any(y==y0+2 for _,y in inner) else None
        if x0 is not None:
            for dx in range(0,3): img[(x0+1+dx,y0+1)]=pal['H']
            img[(x0,y0+2)]=pal['H']; img[(x0,y0+3)]=pal['H'] if h>13 else img.get((x0,y0+3))
    if eyes and h>=9:
        ey=int(h*0.42)+eyeoff; cx=(w-1)/2+lean; dx=max(2,int(w*0.2))
        for sx in(-1,1):
            ex=int(round(cx+sx*dx-0.5))
            tall=3 if h>=12 else 2
            for yy in range(tall):
                img[(ex,ey+yy)]=O; img[(ex+1,ey+yy)]=O
            img[(ex,ey)]=W
    return {k:v for k,v in img.items() if v}
def place(canvas,img,w,bottom=30,dx=0):
    ox=(FS-w)//2+dx; h=max(y for _,y in img)+1; oy=bottom+1-h
    for (x,y),c in img.items():
        if 0<=ox+x<FS and 0<=oy+y<FS: canvas[(ox+x,oy+y)]=c
def frame(w,h,pal=None,lift=0,dx=0,**kw):
    c={}; place(c,body(w,h,pal or dict(S=S,M=M,H=H,D=D),**kw),w,30-lift,dx); return c
HOT=[(190,226,100,255),(214,230,110,255),(240,238,130,255)]
def hot(c,n):
    """telegraph: top rows of body go pale yellow, more each frame"""
    ys=[y for (x,y),v in c.items() if v!=O]; y0=min(ys); rows=n
    for (x,y),v in list(c.items()):
        if v in(M,H,D) and y<y0+rows: c[(x,y)]=(255,246,160,255) if v==H else HOT[n-1]
    return c
def puddle(w,h,lift=0,bubbles=()):
    c=frame(w,h,eyes=False); 
    return c
def to_img(c):
    im=Image.new('RGBA',(FS,FS),(0,0,0,0))
    for p,v in c.items(): im.putpixel(p,v)
    return im
ANIMS={
 'idle':[frame(20,16),frame(20,15),frame(20,14),frame(20,15)],
 'windup':[hot(frame(22,13,dx=-1),1),hot(frame(24,11,dx=1),2),hot(frame(26,9,dx=-1),3)],
 'hop':[frame(16,20,lift=3),frame(15,22,lift=8),frame(17,19,lift=2)],
 'land':[frame(26,9),frame(23,12)],
 'hit':[frame(21,15,pal=FLASH,eyes=False),frame(22,14,eyeoff=1,lean=-1)],
 'die':[frame(22,12,eyeoff=2),frame(26,8,eyes=False),frame(28,6,eyes=False),frame(28,4,eyes=False)],
}
if __name__=='__main__':
    out,prev=sys.argv[1],sys.argv[2]
    for n,fr in ANIMS.items():
        s=Image.new('RGBA',(FS*len(fr),FS),(0,0,0,0))
        for i,f in enumerate(fr): s.paste(to_img(f),(i*FS,0))
        s.save(f'{out}/{n}.png')
    # gel icon 16x16
    I=Image.new('RGBA',(16,16),(0,0,0,0))
    b=body(14,12,dict(S=S,M=M,H=H,D=D),eyes=False)
    for (x,y),v in b.items(): I.putpixel((x+1,y+3),v)
    for x,y in((6,10),(10,8),(4,12)): I.putpixel((x+1,y+3-1),D)
    I.putpixel((9,9),W)
    I.save(f'{out}/gel.png'); sys.exit()

