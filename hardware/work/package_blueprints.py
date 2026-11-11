from pathlib import Path
import zipfile, xml.etree.ElementTree as ET
import pymupdf as fitz
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPDF

root=Path(__file__).resolve().parents[1]
out=root/'outputs'/'niva-vector-blueprints'
names=['Shin pod and exploded assembly','Insole sensors and soft stack','Chappal, sandal and shoe','Battery and left/right keys','Electronics and spatial layout','Camp kit and build gates','Full-size fit template']
svgs=sorted(out.glob('*.svg'))
cards='\n'.join(f'<section id="sheet-{i+1}"><h2>{i+1:02} / {names[i]}</h2><a href="{p.name}" target="_blank">Open editable SVG</a><img src="{p.name}" alt="{names[i]}"></section>' for i,p in enumerate(svgs))
html='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>NIVA | Vector blueprints</title><style>
*{box-sizing:border-box}body{margin:0;background:#eaf0f2;color:#14314b;font:16px/1.5 Arial,sans-serif}header,main{max-width:1300px;margin:auto;padding:32px}header{padding-bottom:0}h1{font-size:40px;margin:0}h2{font-size:21px;margin:0 0 6px}p{max-width:850px}a{color:#0b6f79}nav{display:flex;gap:22px;flex-wrap:wrap}section{margin:0 0 32px;padding:22px;background:#fff;border:1px solid #bdcbd2;border-radius:10px}img{display:block;width:100%;height:auto;margin-top:14px}.tag{color:#0b6f79;letter-spacing:.08em;font-size:12px;font-weight:bold}@media print{header{display:none}section{break-after:page;margin:0;padding:0;border:0}section h2,section a{display:none}main{padding:0}}</style>
<header><div class="tag">REV A / INDUSTRIAL DESIGN DEVELOPMENT</div><h1>NIVA</h1><p>Six dimensioned vector drawing sheets and a full-size fit-study template. Proposed dimensions are marked P. Unresolved interfaces are labelled. These are design-development drawings, not manufacturing files.</p><nav><a href="NIVA-vector-blueprints-Rev-A.pdf">Six-sheet vector PDF</a><a href="READ-ME.md">Design decisions and sources</a></nav></header><main>'''+cards+'</main></html>'
(out/'index.html').write_text(html,encoding='utf8')
doc=fitz.open(out/'NIVA-vector-blueprints-Rev-A.pdf')
assert len(doc)==6
for i,page in enumerate(doc):
 assert not page.get_images(), f'Raster image on PDF page {i+1}'
 assert len(page.get_drawings())>25
 assert f'NV-ID-{i+1:02}' in page.get_text()
 outside=[]
 for block in page.get_text('dict')['blocks']:
  if 'lines' not in block:continue
  for line in block['lines']:
   for span in line['spans']:
    x0,y0,x1,y1=span['bbox']
    if x0<0 or y0<0 or x1>page.rect.width+.1 or y1>page.rect.height+.1:outside.append(span['text'])
 assert not outside, f'Out-of-page text: {outside}'
 print(f'Page {i+1}: vector only, {len(page.get_drawings())} drawing objects, text in page bounds')
for p in svgs:
 tree=ET.parse(p)
 assert not tree.findall('.//{http://www.w3.org/2000/svg}image')
print('7 SVGs parsed, no raster embeds')
d=svg2rlg(str(svgs[-1]));renderPDF.drawToFile(d,str(root/'work'/'fit-template.pdf'))
tp=fitz.open(root/'work'/'fit-template.pdf');tp[0].get_pixmap(matrix=fitz.Matrix(1.2,1.2),alpha=False).save(root/'work'/'fit-template.png')
zpath=root/'outputs'/'NIVA-vector-blueprints-Rev-A.zip'
with zipfile.ZipFile(zpath,'w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.iterdir()):
  if p.is_file():z.write(p,arcname='NIVA-vector-blueprints/'+p.name)
print(f'Packaged {len(list(out.iterdir()))} files in {zpath}')
