"""Vector PDF export of the same source scenes used for the editable PPTX."""
from pathlib import Path
import json
import argparse
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.colors import HexColor

ROOT = Path(__file__).resolve().parents[2]
BUILD = Path(__file__).parent
OUT = ROOT / 'docs/aavishkar/current'
parser = argparse.ArgumentParser()
parser.add_argument('--scene', default='current.scene.json')
parser.add_argument('--poster-label', default='Niva_Poster_1m')
parser.add_argument('--poster-only', action='store_true')
parser.add_argument('--deck-only', action='store_true')
parser.add_argument('--deck-label', default='Niva_Presentation')
parser.add_argument('--output-dir')
args = parser.parse_args()
if args.output_dir:
    OUT = Path(args.output_dir)
OUT.mkdir(parents=True, exist_ok=True)
SCENES = json.loads((BUILD / args.scene).read_text(encoding='utf-8'))
for family in ('Sans', 'Serif', 'Mono'):
    for weight in ('Regular', 'Bold'):
        pdfmetrics.registerFont(TTFont(f'IBM Plex {family}-{weight}', str(Path(__file__).parent / f'fonts/IBMPlex{family}-{weight}.ttf')))
C = SCENES['colors']

def export(pages, name, scale):
    cv = canvas.Canvas(str(OUT/name), pagesize=(pages[0]['w']*scale,pages[0]['h']*scale),pageCompression=1)
    cv.setTitle('Niva | Aavishkar 2026–27')
    cv.setAuthor('Niva research team')
    for p in pages:
        height = p['h']
        cv.saveState()
        cv.scale(scale, scale)
        def text(t,x,y,size,font='IBM Plex Sans',color=C['ink'],bold=False):
            cv.setFillColor(HexColor(color));cv.setFont(font+('-Bold' if bold else '-Regular'),size)
            # Position text by font ascender rather than an arbitrary point baseline.
            asc = pdfmetrics.getAscent(font+('-Bold' if bold else '-Regular')) / 1000 * size
            cv.drawString(x,height-y-asc,t)
        def box(x,y,w,h,fill,stroke='none',sw=0):
            cv.setLineWidth(sw)
            if fill!='none':cv.setFillColor(HexColor(fill))
            if stroke!='none':cv.setStrokeColor(HexColor(stroke))
            cv.rect(x,height-y-h,w,h,fill=fill!='none',stroke=stroke!='none')
        def ln(x,y,x2,y2,color=C['rule'],sw=1):
            cv.setStrokeColor(HexColor(color));cv.setLineWidth(sw);cv.line(x,height-y,x2,height-y2)
        for o in p['objects']:
            k=o['kind'];x=o['x'];y=o['y'];w=o['w'];h=o['h']
            if k=='vector':
                vp=cv.beginPath()
                for loop in o['loops']:
                    for i,(vx,vy) in enumerate(loop):
                        xx=x+vx/o['vw']*w; yy=height-y-vy/o['vh']*h
                        if i==0:vp.moveTo(xx,yy)
                        else:vp.lineTo(xx,yy)
                    vp.close()
                cv.setFillColor(HexColor(o['fill']));cv.drawPath(vp,stroke=0,fill=1,fillMode=1)
            elif k=='image':cv.drawImage(str(ROOT/o['path']),x,height-y-h,width=w,height=h,preserveAspectRatio=True,mask='auto')
            elif k=='text':text(o['text'],x,y,o['size'],o['font'],o['color'],o['bold'])
            elif k=='rect':box(x,y,w,h,o['fill'],o['stroke'],o['sw'])
            elif k=='line':ln(x,y,x+w,y+h,o['stroke'],o['sw'])
            elif k=='ellipse':
                cv.setLineWidth(o['sw'])
                if o['stroke']!='none':cv.setStrokeColor(HexColor(o['stroke']))
                if o['fill']!='none':cv.setFillColor(HexColor(o['fill']))
                cv.ellipse(x,height-y-h,x+w,height-y,stroke=o['stroke']!='none',fill=o['fill']!='none')
            elif k=='table':
                yy=y
                for r,row in enumerate(o['rows']):
                    xx=x
                    for col,t in enumerate(row):
                        ww=o['widths'][col]*w
                        box(xx,yy,ww,o['rowh'],C['navy'] if r==0 else C['panel'] if r%2 else C['white'],C['white'],1)
                        text(t,xx+14,yy+13,o['size'],'IBM Plex Sans' if col==0 else 'IBM Plex Mono',C['white'] if r==0 else C['ink'],r==0)
                        xx+=ww
                    yy+=o['rowh']
            elif k=='chart':
                sz=o['size'];left=x+sz*2.5;right=x+w-12;top=y+12;bottom=y+h-sz*3.3
                ph=bottom-top;pw=right-left
                for v in (0,5,10,15):
                    yy=bottom-v/15*ph;ln(left,yy,right,yy);text(str(v),x+4,yy-sz*.45,sz,'IBM Plex Mono',C['mute'])
                gw=pw/5;bw=gw*.25
                for i,cat in enumerate(o['categories']):
                    center=left+(i+.5)*gw
                    for j,series in enumerate(o['series']):
                        v=series['values'][i];bh=v/15*ph;box(center+(j-1)*bw,bottom-bh,bw-2,bh,series['fill'])
                    text(cat,center-sz*.4,bottom+11,sz,'IBM Plex Mono')
                for j,series in enumerate(o['series']):
                    xx=left+j*pw*.51
                    box(xx,y+h-sz*1.05,sz*.7,sz*.7,series['fill'])
                    text(series['name'],xx+sz,y+h-sz*1.2,sz,'IBM Plex Sans')
        cv.restoreState();cv.showPage()
    cv.save()
    print(OUT/name)

if not args.poster_only:
    export(SCENES['deck'],args.deck_label+'.pdf',.75)
if not args.deck_only:
    export([SCENES['poster']],args.poster_label+'.pdf',(1000/25.4*72)/1600)


