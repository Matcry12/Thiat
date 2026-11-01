# Sword slash smear, 4 frames 48x48, centre (24,24), clockwise (screen angle grows clockwise, -90 = up).
import math, random
from PIL import Image
RAMP=[(244,251,255),(216,240,251),(159,214,240),(111,191,230),(63,143,208),(46,111,176)]  # white..rim
C=24
def frame(a0,a1,shift,scale,erode,drips,seed,rmin=10,rmax=22,w=6.2):
    rnd=random.Random(seed); px={}
    span=a1-a0
    for y in range(48):
        for x in range(48):
            dx,dy=x+.5-C,y+.5-C; r=math.hypot(dx,dy)
            if not rmin<=r<=rmax: continue
            ang=math.degrees(math.atan2(dy,dx))
            if ang<-180+1: ang+=360
            t=(ang-a0)/span
            if not 0<=t<=1: continue
            env=math.sin(math.pi*min(1,t*0.8+0.1))**0.7   # thick middle, tapered ends
            mid=16+1.5*(t-.5)  # centre radius drifts slightly
            if abs(r-mid)>w*env: continue
            s=1-t  # age 0 head .. 1 old
            if rnd.random()<erode*s**2*1.4: continue
            k=s*scale+shift
            k+=1.2*max(0,(r-mid)/ (w*env+.01))  # darker toward outer rim
            if r>mid+4.2*env: k+=1
            px[(x,y)]=RAMP[min(5,max(0,int(k)))]
    # drips: thin streaks continuing past the old end along the arc
    for i in range(drips):
        rr=rmin+3+rnd.random()*(rmax-rmin-6); L=rnd.randint(4,8); aa=a0+rnd.uniform(0,10)
        for j in range(L):
            a=math.radians(aa-j*(360/(2*math.pi*rr)))
            x=int(C+rr*math.cos(a)); y=int(C+rr*math.sin(a))
            px[(x,y)]=RAMP[min(5,3+j//3)]
    return px
def loose(px,a0,a1,n,seed):
    rnd=random.Random(seed)
    for _ in range(n):
        a=math.radians(rnd.uniform(a0,a1)); r=rnd.uniform(9,23)
        px[(int(C+r*math.cos(a)),int(C+r*math.sin(a)))]=RAMP[rnd.choice([2,3,3,4])]
def rr_ok(k): return (k[0]*7+k[1]*3)%11==0
F=[]
F.append(frame(-90,-20,0,1.6,0.0,0,1,w=3.6))
F.append(frame(-90,60,0,3.2,0.0,0,2))
p=frame(-90,60,1.4,3.2,0.12,3,3); loose(p,-120,-70,3,13); F.append(p)
p=frame(-10,70,2.6,2.4,0.0,0,4,w=6.2); loose(p,0,100,10,14)
# f4: keep only thin radial lanes (streaks) on bottom half
F.append({k:v for k,v in p.items() if k[1]>=23 and (round(math.hypot(k[0]+.5-C,k[1]+.5-C)) in (12,16,20) or rr_ok(k))})
imgs=[]
for i,p in enumerate(F):
    im=Image.new('RGBA',(48,48),(0,0,0,0))
    for (x,y),c in p.items():
        if 0<=x<48 and 0<=y<48: im.putpixel((x,y),c+(255,))
    im.save(f'slash_f{i+1}.png'); imgs.append(im)
sh=Image.new('RGBA',(192,48),(0,0,0,0))
for i,im in enumerate(imgs): sh.paste(im,(i*48,0))
sh.save('slash_sheet.png')
bg=Image.new('RGBA',(192,48),(90,110,90,255)); bg.alpha_composite(sh)
bg.resize((192*8,48*8),Image.NEAREST).save('slash_zoom.png')
