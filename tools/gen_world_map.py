"""Mapa del mundo: de aqui salen DOS cosas a la vez (editar la disposicion cambia las dos):
  - el SVG de diseno (mapa_mundo_plan4.svg, con sprites y leyenda), y
  - assets/data/world_map.json, que lee el juego (src/ui/world_map.gd) en la pestana "Mundo" del mapa.
Uso:  python3 tools/gen_world_map.py                 JSON + SVG (el SVG necesita Pillow y los sprites)
      python3 tools/gen_world_map.py --json-only     solo el JSON (sin Pillow ni sprites)
      python3 tools/gen_world_map.py --svg RUTA.svg  SVG en otra ruta (por defecto tools/preview/mapa_mundo.svg)
El JSON usa coordenadas de CUADRICULA (1 celda = UNIT px del SVG, origen en GRID_X0/GRID_Y0)."""
import argparse, base64, io, json, math
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
_ap=argparse.ArgumentParser(); _ap.add_argument("--json-only",action="store_true"); _ap.add_argument("--svg",default=str(ROOT/"tools/preview/mapa_mundo.svg"))
ARGS=_ap.parse_args(); JSON_ONLY=ARGS.json_only
JSON_OUT=ROOT/"assets/data/world_map.json"
R=str(ROOT/"assets/sprites")+"/"
OUT=ARGS.svg
W,H=3200,2200
UNIT=50; GRID_X0,GRID_Y0=230,130   # px del SVG -> celdas: (px-origen)/UNIT
def gx(v): return round((v-GRID_X0)/UNIT,2)
def gy(v): return round((v-GRID_Y0)/UNIT,2)
def gl(v): return round(v/UNIT,2)
REG=[]; DOORS=[]; TUNNELS=[]
def b64(p,h=None,scale=None,crop=None):
    if JSON_ONLY: return "",1,1
    from PIL import Image
    im=Image.open(R+p).convert("RGBA")
    if crop: im=im.crop(crop)
    im=im.crop(im.getbbox()); sc=scale if scale else h/im.height
    im=im.resize((max(1,int(im.width*sc)),max(1,int(im.height*sc))),Image.NEAREST)
    bio=io.BytesIO(); im.save(bio,"PNG")
    return "data:image/png;base64,"+base64.b64encode(bio.getvalue()).decode(),im.width,im.height
o=[]
def A(s): o.append(s)
def esc(t): return t.replace("&","&amp;").replace("<","&lt;")
def idattr(i): return f' id="{i}"' if i else ""
def rect(cls,x,y,w,h,rx=0,id=None,extra=""):
    A(f'<rect{idattr(id)} class="{cls}" x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}"'+(f' rx="{rx}"' if rx else "")+f'{extra}/>')
def text(cls,x,y,t,anchor="start"):
    A(f'<text class="{cls}" x="{x:.1f}" y="{y:.1f}" text-anchor="{anchor}">{esc(t)}</text>')
def image(href,w,h,cx,cy,id=None):
    A(f'<image{idattr(id)} class="sprite" href="{href}" x="{cx-w/2:.1f}" y="{cy-h/2:.1f}" width="{w}" height="{h}"/>')
def pill(cx,cy,lines,sub=None,cls="",id=None):
    items=[(l,"pill-t") for l in lines]+([(sub,"pill-sub")] if sub else [])
    w=max(len(t)*13.2 for t,_ in items)+28; h=28*len(items)+12
    A(f'<g{idattr(id)} class="pill {cls}">'); rect("pill-fondo",cx-w/2,cy-h/2,w,h,12)
    for i,(t,c) in enumerate(items): text(c,cx,cy-h/2+6+28*i+21,t,"middle")
    A('</g>')
def star(cx,cy,r):
    pts=[]
    for k in range(10):
        a=-math.pi/2+k*math.pi/5; rr=r if k%2==0 else r*.45; pts.append(f"{cx+rr*math.cos(a):.1f},{cy+rr*math.sin(a):.1f}")
    return " ".join(pts)

KC={"selva":"#7fe0a0","penelandia":"#6ec6ff","vulvania":"#ff7ac0","perineo":"#ffc93c","prostata":"#d8b890","palacio":"#b48cff"}
RC={"selva":("#7fe0a0","#7fe0a0","#10301c"),"penelandia":("#6ec6ff","#6ec6ff","#0b2a40"),"vulvania":("#ff7ac0","#ff7ac0","#401030"),"perineo":("#ffc93c","#ffc93c","#3a2a00"),"prostata":("#d8b890","#d8b890","#3a2a10"),"palacio":("#b48cff","#b48cff","#2a1050"),"utero":("#e0485a","#a8264a","#ffe6ea"),"silencio":("#8a8a9c","#16161c","#e6e6ee"),"arcoiria":("#ffffff","url(#arcoiris)","#10142a")}
REINOS="\n".join(f".reino-{k} .reino-fondo{{fill:{c};stroke:{c}}} .reino-{k} .sala{{fill:{sa}}} .reino-{k} .ico{{fill:{ic}}}" for k,(c,sa,ic) in RC.items())
REINOS+="\n.reino-silencio .sala{stroke:#d4d4e0} .reino-utero .sala{stroke:#ffd6dc}"
css=f"""
svg{{font-family:'DejaVu Sans',Verdana,sans-serif}}
.fondo{{fill:#0c1430}} .grilla{{stroke:#1a2850;stroke-width:1}}
.t-titulo{{font-family:'Silkscreen','DejaVu Sans',monospace;font-weight:700;fill:#fff;font-size:70px}}
.t-sub{{font-size:32px;fill:#bed0f5}}
.t-reino{{font-family:'Silkscreen','DejaVu Sans',monospace;font-weight:700;font-size:28px;fill:#fff;stroke:#0a0e22;stroke-width:5;paint-order:stroke}}
.t-piso{{font-size:22px;font-weight:700;fill:#fff;stroke:#0a0e22;stroke-width:4;paint-order:stroke}}
.t-blanco{{font-size:23px;font-weight:700;fill:#fff}} .t-gris{{font-size:22px;fill:#c8d2ee}} .t-leyt{{font-family:'Silkscreen','DejaVu Sans',monospace;font-weight:700;font-size:34px;fill:#fff}}
.t-hoja{{font-size:38px;font-weight:700;fill:#fff}} .t-hoja2{{font-size:28px;font-weight:700;fill:#96f0a0}}
.t-orden{{font-size:22px;fill:#ebf0ff}} .t-anillo{{font-size:22px;font-weight:700;fill:#ffe9a0}}
.pill-fondo{{fill:#0a0e22;stroke:#e8eeff;stroke-width:2}} .pill-t{{font-size:22px;font-weight:700;fill:#fff}} .pill-sub{{font-size:22px;fill:#c0c0cc}}
.pill-inicio .pill-fondo{{fill:#961e28;stroke:#fff}}
.reino-fondo{{fill-opacity:.2;stroke-width:4}}
{REINOS}
.sala{{stroke:#f2f5ff;stroke-width:3}}
.sala-inicio,.sala-jefe{{stroke-width:6}} .sala-guardian{{stroke-dasharray:8 5}} .sala-secreta{{stroke-dasharray:4 4}} .sala-minijefe{{stroke:#ffe146;stroke-width:5}}
.sala-especial{{fill:#ffe9a0;stroke:#fff}}
.sala-jefe-slot{{fill:#0a0e22;fill-opacity:.55;stroke:#fff;stroke-width:4}}
.conexion{{fill:#f2f5ff}}
.ico{{font-size:26px;font-weight:700}}
.escalera{{fill:#ff961e;stroke:#fff;stroke-width:2}}
.pasillo{{fill:#2a3a70;stroke:#e8eeff;stroke-width:3}} .anillo{{fill:#3a2f6a;stroke:#ffe9a0;stroke-width:3}}
.flecha-tunel{{fill:#fff}}
.ascensor{{fill:#0e4659;stroke:#78ebff;stroke-width:4}} .asc-flecha{{fill:#96f0ff}}
.puerta-fija rect{{fill:#ff961e;stroke:#fff;stroke-width:3}} .puerta-fija .pf-simbolo{{fill:#fff;stroke:none}} .puerta-fija path{{fill:none;stroke:#fff;stroke-width:3}}
.puerta-eleccion rect{{fill:#ffe146;stroke:#0a0e22;stroke-width:3}} .puerta-eleccion path{{fill:none;stroke:#0a0e22;stroke-width:5;stroke-linecap:round;stroke-linejoin:round}} .puerta-eleccion polygon{{fill:#0a0e22}}
.pf-texto{{font-size:20px;font-weight:700;fill:#fff}}
.candado rect{{fill:#fff;stroke:#0a0e22;stroke-width:3}} .candado path{{fill:none;stroke:#fff;stroke-width:5}} .candado .cuerpo{{fill:#ff961e}} .candado text{{font-size:22px;font-weight:700;fill:#fff}}
.sello circle{{fill:#c2323c;stroke:#fff;stroke-width:3}} .sello polygon{{fill:#ffe146}}
.sil-fondo{{fill:#464652;stroke:#ebebeb;stroke-width:3;stroke-dasharray:10 7}} .sil-forma{{fill:#969aa4}}
.sprite{{image-rendering:pixelated}}
.ruta{{fill:none;stroke-width:4;stroke-linecap:butt}}
.ruta.pitocles{{stroke:#ff4646}} .ruta.vulvalquiria{{stroke:#ff82d2}} .ruta.ornitorrinco{{stroke:#28d7be}}
.ficha rect,.ficha circle{{stroke:#0a0e22;stroke-width:3}} .ficha text{{font-size:22px;font-weight:700;fill:#0a0e22}}
.ficha.pitocles rect,.ficha.pitocles circle{{fill:#ff4646}} .ficha.vulvalquiria rect,.ficha.vulvalquiria circle{{fill:#ff82d2}} .ficha.ornitorrinco rect,.ficha.ornitorrinco circle{{fill:#28d7be}}
.leyenda-fondo,.panel-fondo{{fill:#080c1e;stroke:#e8eeff;stroke-width:4}}
.h-pitocles{{fill:#ff4646;font-size:28px;font-weight:700}} .h-vulvalquiria{{fill:#ff82d2;font-size:28px;font-weight:700}} .h-ornitorrinco{{fill:#28d7be;font-size:28px;font-weight:700}}
.estrella{{fill:#ffe146;stroke:#0a0e22;stroke-width:2}}
.flag-mastil{{stroke:#fff;stroke-width:4}} .flag{{fill:#eb2828}}
.nota{{font-size:22px;font-weight:700;fill:#ffe9a0}}
"""
A(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}">')
A('<title>Mapa del mundo (Plan 4)</title>')
A('<defs><linearGradient id="arcoiris" x1="0" y1="0" x2="1" y2="0">'+''.join(f'<stop offset="{i/6*100:.1f}%" stop-color="{c}"/><stop offset="{(i+1)/6*100:.1f}%" stop-color="{c}"/>' for i,c in enumerate(["#ff5a5a","#ffaa3c","#ffe646","#64d26e","#50aaff","#a06ef0"]))+'</linearGradient></defs>')
A(f'<style>{css}</style>')
A('<g id="fondo">'); rect("fondo",0,0,W,H); A('<g id="grilla">')
for x in range(0,W,60): A(f'<line class="grilla" x1="{x}" y1="0" x2="{x}" y2="{H}"/>')
for y in range(0,H,60): A(f'<line class="grilla" x1="0" y1="{y}" x2="{W}" y2="{y}"/>')
A('</g></g>')

U=44;P=48;CW=4*P-4;CH=3*P-4
T1={(0,1):"inicio",(1,1):"combate",(2,1):"minijefe",(3,1):"jefe",(1,0):"calma",(2,0):"combate",(1,2):"tienda",(2,2):"antro",(3,2):"trampa"}
T2={(0,1):"inicio",(1,1):"combate",(2,1):"minijefe",(3,1):"jefe",(1,0):"calma",(2,0):"combate",(3,0):"secreta",(1,2):"antro",(2,2):"tienda",(3,2):"acertijo",(0,2):"trampa"}
GL={"inicio":"▶","combate":"⚔","minijefe":"☠","jefe":"★","tienda":"$","acertijo":"?","cofre":"◆","descanso":"♥","trampa":"!","lore":"≡","secreta":"✦","antro":"~"}
def cluster(rid,n,x,y,T,calm,guardian):
    A(f'<g id="{rid}-piso-{n}" class="piso">')
    A(f'<g id="{rid}-p{n}-conexiones">')
    for (c,r) in sorted(T):
        if (c+1,r) in T: rect("conexion",x+(c+1)*P-4,y+r*P+U/2-6,4,12)
        if (c,r+1) in T: rect("conexion",x+c*P+U/2-6,y+(r+1)*P-4,12,4)
    A('</g>')
    for (c,r),t in sorted(T.items()):
        tt=calm if t=="calma" else t
        cls=f"sala sala-{tt}"+(" sala-guardian" if (t=="jefe" and guardian) else "")
        rect(cls,x+c*P,y+r*P,U,U,6,id=f"sala-{rid}-p{n}-{c}-{r}")
        text("ico",x+c*P+U/2,y+r*P+U/2+9,GL[tt],"middle")
    A('</g>')
def stairs(cx,cy,rid):
    A(f'<g id="{rid}-escalera">')
    for i in range(4): rect("escalera",cx-20+i*10,cy+16-i*10,10,10+i*10)
    A('</g>')
def boss_sprite(spec,cx,cy,id,h=96):
    if spec=="pend":
        A(f'<g id="{id}" class="jefe-pendiente">'); rect("sil-fondo",cx-46,cy-58,92,116,16)
        A(f'<circle class="sil-forma" cx="{cx}" cy="{cy-22}" r="16"/><rect class="sil-forma" x="{cx-24}" y="{cy-4}" width="48" height="44" rx="11"/></g>')
    else:
        href,w,hh=b64(spec[0],h=h,crop=spec[1]); image(href,w,hh,cx,cy,id=id)
def sello(cx,cy,id):
    A(f'<g id="{id}" class="sello"><circle cx="{cx}" cy="{cy}" r="17"/><polygon points="{star(cx,cy,11)}"/></g>')
def ficha(hero,cx,cy,t):
    wd=62 if len(t)>1 and not t.isdigit() else 46
    A(f'<g class="ficha {hero}"><rect x="{cx-wd/2:.1f}" y="{cy-19}" width="{wd}" height="38" rx="19"/>'); text("",cx,cy+8,t,"middle"); A('</g>')
HC=["pitocles","vulvalquiria","ornitorrinco"]
def trow(x,y,items):
    for i,(h,t) in enumerate(items): ficha(h,x+31+i*70,y,t)
H_=270
SLOTW=170
def reino(rid,name,x,y,w,order,calms,boss,guard=(True,False),single=False,slotw=SLOTW,bossname=None,bsub=None,seal=False,bossh=96,Hh=H_,p2dy=0,tx=None,pillcy=None,pilldx=0):
    A(f'<g id="reino-{rid}" class="reino reino-{rid}">')
    rect("reino-fondo",x,y,w,Hh,22,id=f"reino-{rid}-fondo"); text("t-reino",tx if tx else x+24,y+38,name)
    cx=x+24; info={}
    pn=0
    for el in order:
        if el=="hero":
            info["hero"]=cx; cx+=175
        elif el=="boss":
            info["boss"]=cx; cx+=slotw+16
        elif el=="hill":
            info["hill"]=cx; cx+=130
        elif el=="P":
            pn+=1
            if pn==2: cx+=0
            dy=p2dy if pn==2 else 0
            text("t-piso",cx,y+72+dy,f"Piso {pn}")
            info[f"P{pn}"]=cx
            cluster(rid,pn,cx,y+80+dy,T2 if (not single and pn==2) else T1,calms[pn-1],guard[pn-1] if not single else False)
            cx+=CW
            if not single and pn==1: stairs(cx+30,y+80+CH/2,rid); cx+=60
            else: cx+=16
        elif isinstance(el,(int,float)): cx+=el
    if "hill" in info:
        hx=info["hill"]
        A('<g id="monte-de-venus" class="sala-especial-grupo">')
        for i in range(3): rect("sala sala-especial",hx+i*38,y+80+CH-(i+1)*42,36,(i+1)*42,6,id=f"sala-selva-monte-{i}")
        A(f'<polygon class="estrella" points="{star(hx+95,y+80+CH-3*42-18,20)}"/></g>')
    bx=info["boss"]; by=y+78+p2dy
    REG.append(dict(id=rid,name=name,x=x,y=y,w=w,h=Hh,boss=(bx,by,slotw,CH+4),pisos=1 if single else 2))
    rect("sala-jefe-slot",bx,by,slotw,CH+4,14,id=f"sala-jefe-{rid}")
    boss_sprite(boss,bx+slotw/2,by+(CH+4)/2+2,f"jefe-{rid}",h=bossh)
    if seal: sello(bx+22,by+22,f"sello-{rid}")
    if bossname:
        ls=bossname if isinstance(bossname,list) else [bossname]
        cy=pillcy if pillcy else (y+Hh-20 if (len(ls)==1 and not bsub) else y+Hh-8)
        pill(bx+slotw/2+pilldx,cy,ls,sub=bsub,id=f"nombre-jefe-{rid}")
    A('</g>')
    return info,(bx,by)

# ================= geometría
RING_L,RING_R,RING_B=250,3000,2105
RT=1335  # y del anillo superior
def pasillo(x,y,w,h,id=None,cls="pasillo"): rect(cls,x,y,w,h,0,id=id)
def tri(cx,cy,d,L=16):  # flecha de entrada (d: u,d,l,r)
    pts={"r":[(cx+L,cy),(cx-4,cy-L),(cx-4,cy+L)],"l":[(cx-L,cy),(cx+4,cy-L),(cx+4,cy+L)],"d":[(cx,cy+L),(cx-L,cy-4),(cx+L,cy-4)],"u":[(cx,cy-L),(cx-L,cy+4),(cx+L,cy+4)]}[d]
    A('<polygon class="flecha-tunel" points="'+" ".join(f"{a:.0f},{b:.0f}" for a,b in pts)+'"/>')
ANG={"r":0,"d":90,"l":180,"u":270}
def reg_door(id,kind,cx,cy,d,sellos=False):
    if id.startswith("leyenda"): return
    p=id.split("-")
    fr,to=(p[1],p[2]) if kind=="fija" else (p[1],"anillo")
    if id in ("puerta-arcoiria-ascensor","puerta-ascensor-utero"): fr,to="arcoiria","utero"  # el ascensor lleva al Utero
    DOORS.append(dict(id=id.replace("puerta-","").replace("eleccion-","eleccion_").replace("-","_"),kind=kind,**{"from":fr,"to":to},x=gx(cx),y=gy(cy),dir=d,seals=2 if (sellos or id=="puerta-arcoiria-ascensor") else 0,via="ascensor" if "ascensor" in id else ""))
def puerta_fija(cx,cy,d,id,sellos=False):
    reg_door(id,"fija",cx,cy,d,sellos)
    A(f'<g id="{id}" class="puerta puerta-fija" transform="translate({cx},{cy}) rotate({ANG[d]})">')
    A('<rect x="-30" y="-19" width="60" height="38" rx="8"/>')
    A('<rect class="pf-simbolo" x="-24" y="-3" width="14" height="11" rx="2"/><path d="M -21 -3 v -5 a 4 4 0 0 1 8 0 v 5"/>')
    A('<polygon class="pf-simbolo" points="4,-11 20,0 4,11"/></g>')
    if sellos: A(f'<g transform="translate({cx},{cy})"><text class="pf-texto" x="0" y="34" text-anchor="middle" style="paint-order:stroke;stroke:#0a0e22;stroke-width:5px">2×</text></g>')
def puerta_eleccion(cx,cy,d,id):
    reg_door(id,"eleccion",cx,cy,d)
    A(f'<g id="{id}" class="puerta puerta-eleccion" transform="translate({cx},{cy}) rotate({ANG[d]})">')
    A('<rect x="-30" y="-19" width="60" height="38" rx="8"/><path d="M -20 0 H -2 M -2 0 L 12 -10 M -2 0 L 12 10"/><polygon points="12,-15 22,-10 14,-3"/><polygon points="12,15 22,10 14,3"/></g>')
def candado(cx,cy,id,txt="2 SELLOS"):
    w=len(txt)*13+58
    A(f'<g id="{id}" class="candado"><rect x="{cx-w/2:.0f}" y="{cy-24}" width="{w}" height="48" rx="10"/>')
    A(f'<rect class="cuerpo" x="{cx-w/2+10:.0f}" y="{cy-6}" width="26" height="22" rx="3"/><path d="M {cx-w/2+16:.0f} {cy-6} v -7 a 7 7 0 0 1 14 0 v 7"/>')
    A(f'<text x="{cx-w/2+44:.0f}" y="{cy+8}" style="fill:#0a0e22">{esc(txt)}</text></g>')
A('<g id="tunel-exterior">')
pasillo(RING_L-14,RT-15,1076-RING_L+14,30,"anillo-sup-izq","anillo"); pasillo(2040,RT-15,RING_R+14-2040,30,"anillo-sup-der","anillo")
pasillo(RING_L-14,RT-15,28,RING_B+15-RT+15,"anillo-izq","anillo"); pasillo(RING_R-14,RT-15,28,RING_B+15-RT+15,"anillo-der","anillo")
pasillo(RING_L-14,RING_B-15,RING_R-RING_L+28,30,"anillo-inf","anillo")
pasillo(1190,1660,34,RING_B-1660,"anillo-carril-arcoiria","anillo")
A('</g>')
A('<g id="tuneles-entrada">')
for (x,y,w,h,i) in [(264,1608,70,34,"entra-pen"),(2930,1608,60,34,"entra-vul"),(1480,2046,34,50,"entra-per")]: pasillo(x,y,w,h,i)
pasillo(1049,RT,34,160,"sale-pen"); pasillo(2182,RT,34,160,"sale-vul"); pasillo(1928,2046,34,50,"sale-per")
A('</g>')
A('<g id="tuneles-centro">')
pasillo(1170,1608,32,34,"pen-arc"); pasillo(2040,1608,52,34,"vul-arc"); pasillo(1995,1466,34,28,"sel-arc"); pasillo(1834,1756,34,28,"per-arc")
A('</g>')
A('<g id="tuneles-eje">')
pasillo(1205,850,36,40,"utero-prostata-a"); pasillo(1205,852,340,36,"utero-prostata-b")
pasillo(1763,850,36,42,"prostata-silencio"); pasillo(1730,408,36,44,"silencio-palacio")
A('</g>')
# ascensor
A('<g id="ascensor">'); rect("ascensor",1340,1000,120,1568-1000,6,id="ascensor-tubo")
for yy in range(1100,1560,110): A(f'<polygon class="asc-flecha" points="1400,{yy-24} 1374,{yy+10} 1426,{yy+10}"/>')
text("t-blanco",1400,1005,"") ; A('</g>')

# ---------- reinos
A('<g id="reinos">')
TSEL=("enemies/boss_cera_sheet.png",(0,0,156,180))
reino("palacio","PALACIO",1025,140,750,["P","P","boss"],["lore","cofre"],("enemies/hoja_de_parra_idle_00.png",None),slotw=250,bossh=215)
reino("silencio","SILENCIO",900,450,998,["P",328,"P","boss"],["descanso","lore"],"pend",Hh=400,p2dy=90,bossname="El Pacto de Silencio",bsub="por diseñar",pillcy=450+400-44)
reino("utero","ÚTERO",910,890,422,["P","boss"],["descanso"],("enemies/regla_idle_00.png",None),single=True,bossname="Doña Regla")
reino("prostata","PRÓSTATA",1468,890,422,["P","boss"],["lore"],("enemies/glandula_idle_00.png",None),single=True,bossname=["La Glándula","Callada"])
reino("selva","SELVA",1076,1200,964,["P",164,"P","hill","boss"],["lore","cofre"],TSEL,tx=1100,bossname=["Doña Cera","Caliente"],seal=True,pilldx=-16)
reino("penelandia","PENELANDIA",330,1490,845,["hero","P","P","boss"],["cofre","lore"],("enemies/testiculo_primordial_idle_00.png",None),bossname=["Testículo","Primordial"],seal=True)
reino("arcoiria","ARCOÍRIA",1197,1490,845,["boss","hero","P","P"],["descanso","cofre"],"pend",tx=1530,bossname="La Censura que destiñe",bsub="por diseñar",pilldx=24)
reino("vulvania","VULVANIA",2090,1490,845,["boss","hero","P","P"],["descanso","lore"],("enemies/reina_ovaria_idle_00.png",None),tx=2310,bossname=["Su Majestad","Ovaria II"],seal=True)
reino("perineo","PERINEO",1290,1780,670,["P","P","boss"],["lore","cofre"],("enemies/aduanero_idle_00.png",None),bossname=["El Aduanero","Hormonal"],seal=True,pilldx=-24)
A('</g>')
# monte de venus etiqueta
pill(1781,1236,["Monte de Venus"],sub="sala especial (idea)",id="nombre-monte-de-venus")
# héroes de inicio
A('<g id="inicios">')
def inicio(hid,sp,x,y,nm):
    href,w,h=b64(sp,scale=2); image(href,w,h,x,y+h/2-4,id=f"sprite-{hid}")
    A(f'<g id="inicio-{hid}"><line class="flag-mastil" x1="{x+w/2+8}" y1="{y-10}" x2="{x+w/2+8}" y2="{y+50}"/><polygon class="flag" points="{x+w/2+10},{y-10} {x+w/2+44},{y+3} {x+w/2+10},{y+16}"/></g>')
    pill(x,y+h+34,["INICIO",nm],cls="pill-inicio",id=f"pill-inicio-{hid}")
inicio("pitocles","player/pitocles/idle_00.png",330+24+87,1490+84,"Pitocles")
inicio("ornitorrinco","player/ornitorrinco/idle_00.png",1197+24+170+16+87,1490+84,"Ornitorrinco")
inicio("vulvalquiria","player/vulvalquiria/idle_00.png",2090+24+170+16+87,1490+84,"Vulvalquiria")
A('</g>')
# fichas
A('<g id="fichas">')
P_,V_,O_="pitocles","vulvalquiria","ornitorrinco"
trow(330+24+175,1490+248,[(P_,"1"),(V_,"2"),(O_,"2/3")])
trow(2090+190+150-150+0,1490+248,[(V_,"1"),(P_,"2"),(O_,"2/3")]) if False else None
trow(2090+24+186+175,1490+248,[(V_,"1"),(P_,"2"),(O_,"2/3")])
trow(1100,1200+248,[(P_,"2"),(V_,"2"),(O_,"2/3")])
trow(1290+10,1780+248,[(P_,"2"),(V_,"2"),(O_,"2/3")])
trow(1197+24+186+175,1490+248,[(O_,"1"),(P_,"3"),(V_,"3")])
for rid,x,y in [("utero",910+10,890+246),("prostata",1468+10,890+246),("silencio",900+24,450+400-30),("palacio",1025+10,140+246)]:
    n={"utero":"4","prostata":"5","silencio":"6","palacio":"7"}[rid]
    trow(x,y,[(P_,n),(V_,n),(O_,n)]) if False else None
    for i,h in enumerate((P_,V_,O_)):
        A(f'<g class="ficha num {h}"><circle cx="{x+i*40+20}" cy="{y}" r="17"/>'); text("",x+i*40+20,y+8,n,"middle"); A('</g>')
A('</g>')
# puertas
A('<g id="puertas">')
puerta_fija(1166,1625,"r","puerta-penelandia-arcoiria",True); puerta_fija(2072,1625,"l","puerta-vulvania-arcoiria",True)
puerta_fija(2014,1472,"d","puerta-selva-arcoiria",True); puerta_fija(1851,1780,"u","puerta-perineo-arcoiria",True)
puerta_fija(1400,1568,"u","puerta-arcoiria-ascensor"); puerta_fija(1328,1040,"l","puerta-ascensor-utero")
puerta_fija(1223,890,"u","puerta-utero-prostata"); puerta_fija(1781,890,"u","puerta-prostata-silencio"); puerta_fija(1748,450,"u","puerta-silencio-palacio")
puerta_eleccion(1066,1498,"u","eleccion-penelandia"); puerta_eleccion(2040,1335,"r","eleccion-selva")
puerta_eleccion(2199,1498,"u","eleccion-vulvania"); puerta_eleccion(1945,2050,"d","eleccion-perineo"); puerta_eleccion(1207,1676,"d","eleccion-arcoiria")
candado(1400,1545,"candado-ascensor-2-sellos")
for cx,cy,d in [(264,1625,"r"),(2990,1625,"l"),(1497,2070,"u"),(1076,RT,"r")]: tri(cx+(0 if d in "ud" else 0),cy,d)
A('</g>')
# rutas (lineas sobre tuneles del eje)
A('<g id="rutas-eje">')
def line(cls,pts):
    A(f'<polyline class="ruta {cls}" points="'+" ".join(f"{a:.0f},{b:.0f}" for a,b in pts)+'"/>')
for h,off in zip(HC,(-16,0,16)):
    line(h,[(1400+off,1560),(1400+off,1040+off*0.6),(1318,1040+off*0.6)])
    line(h,[(1215+off*0.4,890),(1215+off*0.4,870+off*0.5),(1530+off*0.4,870+off*0.5),(1530+off*0.4,896)])
    line(h,[(1781+off*0.6,892),(1781+off*0.6,846)])
    line(h,[(1748+off*0.6,452),(1748+off*0.6,406)])
A('</g>')
text("t-anillo",1625,2160,"TÚNEL EXTERIOR: aquí se abren las puertas de elección","middle")

def wrap(t,cw,maxw):
    out=[];cur=""
    for w_ in t.split():
        c=(cur+" "+w_).strip()
        if len(c)*cw<=maxw: cur=c
        else: out.append(cur);cur=w_
    out.append(cur); return out
A('<g id="titulos">')
text("t-titulo",60,90,"MAPA DEL MUNDO (PLAN 4)")
text("t-sub",64,132,"Útero y Próstata en la ruta · 7 reinos · ~12 pisos · puertas de un solo sentido")
A('</g>')
A('<g id="hoja-de-parra">')
text("t-hoja",1830,215,"SU PUDOROSIDAD,"); text("t-hoja",1830,262,"LA HOJA DE PARRA"); text("t-hoja2",1830,312,"→ revive como LA PARRA ENTERA")
A('</g>')
# leyenda
LX,LY,LW=60,170,760
A('<g id="leyenda">'); rect("leyenda-fondo",LX,LY,LW,950,16,id="leyenda-fondo")
text("t-leyt",LX+24,LY+48,"LEYENDA")
y=LY+100
A(f'<g class="reino-penelandia">'); rect("sala",LX+30,y-20,40,40,6); A("</g>"); text("t-blanco",LX+90,y+8,"sala (un cuadro = una sala)"); y+=52
items=[("inicio","inicio"),("combate","combate"),("minijefe","minijefe"),("jefe","jefe / guardián"),("tienda","tienda"),("acertijo","acertijo"),("cofre","cofre"),("descanso","descanso"),("trampa","trampa"),("calma","lore"),("secreta","sala secreta"),("antro","antro (alcohol)")]
GL["calma"]="≡"
for i,(k,n) in enumerate(items):
    cx=LX+30+(i%2)*360; cy=y+(i//2)*44
    A(f'<g class="reino-penelandia"><rect class="sala sala-{k if k!="calma" else "lore"}" x="{cx}" y="{cy-18}" width="36" height="36" rx="5"/><text class="ico" x="{cx+18}" y="{cy+8}" text-anchor="middle" style="font-size:22px">{GL[k]}</text></g>')
    text("t-blanco",cx+48,cy+8,n)
y+=6*44+14
puerta_fija(LX+60,y,"r","leyenda-puerta-fija"); text("t-blanco",LX+110,y+8,"puerta fija: siempre es esa"); y+=52
puerta_eleccion(LX+60,y,"r","leyenda-puerta-eleccion"); text("t-blanco",LX+110,y+8,"puerta de elección: tú eliges"); y+=52
candado(LX+100,y,"leyenda-candado"); text("t-blanco",LX+190,y+8,"candado: pide 2 sellos"); y+=56
sello(LX+60,y,"leyenda-sello"); text("t-blanco",LX+110,y+8,"sello (lo da el jefe del cuerpo)"); y+=48
rect("ascensor",LX+40,y-18,40,36,4); A(f'<polygon class="asc-flecha" points="{LX+60},{y-14} {LX+48},{y+8} {LX+72},{y+8}"/>'); text("t-blanco",LX+110,y+8,"ascensor (llega solo al Útero)"); y+=50
href,w_,h_=b64("enemies/aduanero_idle_00.png",h=44); image(href,w_,h_,LX+60,y); text("t-blanco",LX+110,y+8,"jefe del reino"); y+=52
A(f'<g><rect class="sil-fondo" x="{LX+36}" y="{y-24}" width="48" height="48" rx="8"/></g>'); text("t-blanco",LX+110,y+8,"jefe por diseñar"); y+=52
A(f'<line class="flag-mastil" x1="{LX+50}" y1="{y-18}" x2="{LX+50}" y2="{y+18}"/><polygon class="flag" points="{LX+52},{y-18} {LX+80},{y-8} {LX+52},{y+2}"/>'); text("t-blanco",LX+110,y+8,"INICIO del héroe"); y+=48
for i,(h,n) in enumerate(zip(HC,["Pitocles","Vulvalquiria","Ornitorrinco"])): pass
text("t-blanco",LX+30,y+8,"ruta:")
xx=LX+110
for h,n in zip(HC,["Pitocles","Vulvalquiria","Ornitorrinco"]):
    A(f'<line class="ruta {h}" x1="{xx}" y1="{y}" x2="{xx+34}" y2="{y}" style="stroke-width:7"/>'); text("t-gris",xx+42,y+8,n); xx+=42+len(n)*12.5+14
y+=50
ficha(O_,LX+50,y,"2/3"); text("t-blanco",LX+110,y+8,"2 = tú eliges cuál de estos reinos"); y+=14
A('</g>')
# panel orden
PX,PY,PW=2230,330,910
A('<g id="orden-de-cada-heroe">'); rect("panel-fondo",PX,PY,PW,730,16,id="orden-fondo")
text("t-leyt",PX+24,PY+48,"ORDEN DE CADA HÉROE")
TXT={"pitocles":("Pitocles","1 Penelandia · 2 a elección (Selva, Vulvania o Perineo) · 3 Arcoíria (con 2 sellos) · 4 Útero · 5 Próstata · 6 Silencio · 7 Palacio"),
"vulvalquiria":("Vulvalquiria","1 Vulvania · 2 a elección (Selva, Penelandia o Perineo) · 3 Arcoíria (con 2 sellos) · 4 Útero · 5 Próstata · 6 Silencio · 7 Palacio"),
"ornitorrinco":("Ornitorrinco","1 Arcoíria · 2 y 3 a elección (Selva, Penelandia, Vulvania o Perineo; con 2 sellos) · 4 Útero · 5 Próstata · 6 Silencio · 7 Palacio")}
y=PY+100
for h,(n,t) in TXT.items():
    text(f"h-{h}",PX+24,y,n); y+=36
    for l in wrap(t,12.3,PW-48): text("t-orden",PX+24,y,l); y+=30
    y+=24
rect("pill-fondo",PX+16,y-6,PW-32,2,0); y+=26
for t in ["Cada reino termina en su jefe. Vencerlo abre la puerta de salida.","Nadie se salta el centro: Arcoíria, Útero, Próstata, Silencio y Palacio son obligatorios.","El centro se abre con 2 sellos de jefes del cuerpo. Por eso hay que pasar por otro reino aunque Arcoíria esté al lado.","Distribución de ejemplo: las salas cambian en cada partida."]:
    for l in wrap(t,12.3,PW-48): text("nota",PX+24,y,l); y+=30
    y+=12
A('</g>')
A('</svg>')

# ================= salida JSON (cuadricula) y SVG
def build_json():
    routes=json.loads((ROOT/"assets/data/routes.json").read_text(encoding="utf8"))
    # clave de locale FLOOR_<n>_SHORT: n = posicion del reino segun el orden de assets/data/floors (como Loc.floor_name)
    order=[]
    for f in sorted((ROOT/"assets/data/floors").glob("*.json")):
        r=json.loads(f.read_text(encoding="utf8")).get("region")
        if r and r not in order: order.append(r)
    regs=[]
    for r in REG:
        rid=r["id"]; c=RC[rid]
        bx,by,bw,bh=r["boss"]
        regs.append({"id":rid,"name":r["name"],
            "name_key":("FLOOR_%d_SHORT"%(order.index(rid)+1)) if rid in order else "MAPA_REINO_"+rid.upper(),
            "role":"body" if rid in routes["body"] else "center",
            "x":gx(r["x"]),"y":gy(r["y"]),"w":gl(r["w"]),"h":gl(r["h"]),
            "color":c[0].lstrip("#") if c[0].startswith("#") else "ffffff","rainbow":rid=="arcoiria",
            "pisos":r["pisos"],"boss":{"x":gx(bx),"y":gy(by),"w":gl(bw),"h":gl(bh)}})
    pl=lambda pts:[[gx(a),gy(b)] for a,b in pts]
    tun=[
      {"id":"anillo","kind":"anillo","lines":[pl([(RING_L,RT),(1066,RT)]),pl([(2040,RT),(RING_R,RT)]),pl([(RING_L,RT),(RING_L,RING_B),(RING_R,RING_B),(RING_R,RT)]),pl([(1207,1676),(1207,RING_B)]),
         pl([(1066,1498),(1066,RT)]),pl([(2199,1498),(2199,RT)]),pl([(1945,2050),(1945,RING_B)]),
         pl([(RING_L,1625),(334,1625)]),pl([(RING_R,1625),(2930,1625)]),pl([(1497,RING_B),(1497,2046)])]},
      {"id":"eje","kind":"eje","lines":[pl([(1223,890),(1223,870),(1530,870),(1530,890)]),pl([(1781,890),(1781,850)]),pl([(1748,450),(1748,410)])]},
    ]
    return {"_nota":"Generado por tools/gen_world_map.py (no editar a mano). Coordenadas en celdas de cuadricula; y crece hacia abajo.",
        "grid":{"w":gl(3030-GRID_X0),"h":gl(2125-GRID_Y0),"unit_px":UNIT},
        "regions":regs,"doors":DOORS,"tunnels":tun,
        "elevator":{"x":gx(1340),"y":gy(1000),"w":gl(120),"h":gl(568)}}
JSON_OUT.write_text(json.dumps(build_json(),ensure_ascii=False,indent=1)+"\n",encoding="utf8"); print("json ->",JSON_OUT)
if not JSON_ONLY:
    Path(OUT).parent.mkdir(parents=True,exist_ok=True)
    open(OUT,"w").write("\n".join(o))
    print("svg ->",OUT,len("\n".join(o))//1024,"KB")
