from pathlib import Path
from xml.sax.saxutils import escape
import textwrap, math, zipfile
from svglib.svglib import svg2rlg
from reportlab.pdfgen import canvas
from reportlab.graphics import renderPDF
import fitz
from PIL import Image, ImageOps, ImageDraw

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'outputs'/'niva-vector-blueprints'
OUT.mkdir(parents=True,exist_ok=True)
WORK=ROOT/'work'; WORK.mkdir(exist_ok=True)
NAVY='#14314B'; TEAL='#0B6F79'; PALE='#EAF0F2'; GREY='#637887'; LINE='#BDCBD2'; AMBER='#946322'; WHITE='#FFFFFF'
pages=[]

class Sheet:
 def __init__(self,n,title,sub,scale='AS NOTED'):
  self.n=n; self.title=title; self.a=[]
  self.add('<svg xmlns="http://www.w3.org/2000/svg" width="420mm" height="297mm" viewBox="0 0 420 297">')
  self.rect(0,0,420,297,WHITE,WHITE,0)
  self.text(12,16,'NIVA',7,bold=True)
  self.text(42,16,title,6,bold=True)
  self.text(12,25,sub,3.1,GREY)
  self.text(408,15,f'ID / {n:02}',4,TEAL,anchor='end',bold=True)
  self.line(12,32,408,32,NAVY,.5)
  self.line(12,280,408,280,NAVY,.4)
  self.text(12,286,'DESIGN DEVELOPMENT  /  NOT FOR FABRICATION OR CLINICAL USE',2.7,TEAL,bold=True)
  self.text(12,292,'All dimensions in mm. P = proposed target; V = verified component dimension. No general tolerances assigned.',2.5,GREY)
  self.text(408,286,f'NV-ID-{n:02}  |  REV A  |  28 SEP 2026',2.7,NAVY,anchor='end')
  self.text(408,292,f'A3 LANDSCAPE  |  SCALE {scale}  |  {n:02} / 06',2.5,GREY,anchor='end')
 def add(self,s): self.a.append(s)
 def group(self,t): self.add(f'<g transform="{t}">')
 def end(self): self.add('</g>')
 def rect(self,x,y,w,h,fill='none',stroke=NAVY,sw=.4,r=0,dash=None):
  self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
 def line(self,x1,y1,x2,y2,c=NAVY,w=.4,dash=None):
  self.add(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{c}" stroke-width="{w}"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
 def path(self,d,fill='none',stroke=NAVY,sw=.4,dash=None):
  self.add(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"'+(f' stroke-dasharray="{dash}"' if dash else '')+'/>')
 def circle(self,x,y,r,fill='none',stroke=NAVY,sw=.4): self.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')
 def text(self,x,y,s,size=3.4,c=NAVY,bold=False,anchor='start'):
  self.add(f'<text x="{x}" y="{y}" font-family="Helvetica, Arial, sans-serif" font-size="{size}" fill="{c}" font-weight="'+('bold' if bold else 'normal')+f'" text-anchor="{anchor}">{escape(str(s))}</text>')
 def para(self,x,y,s,width=64,size=3.3,c=NAVY,leading=5):
  for i,l in enumerate(textwrap.wrap(s,width=width)): self.text(x,y+i*leading,l,size,c)
 def label(self,x,y,title,body,width=53):
  self.text(x,y,title,3.5,TEAL,True);self.para(x,y+6,body,width,3.1,leading=4.5)
 def leader(self,pts,label=None):
  self.path('M '+' L '.join(f'{x} {y}' for x,y in pts),stroke=GREY,sw=.3)
  self.circle(*pts[0],.7,TEAL,TEAL,.1)
  if label:self.text(pts[-1][0]+2,pts[-1][1]+1,label,3,GREY)
 def arrow(self,x1,y1,x2,y2,c=TEAL,w=.5):
  self.line(x1,y1,x2,y2,c,w)
  a=math.atan2(y2-y1,x2-x1);v=2
  self.path(f'M {x2-v*math.cos(a-.5)} {y2-v*math.sin(a-.5)} L {x2} {y2} L {x2-v*math.cos(a+.5)} {y2-v*math.sin(a+.5)}',stroke=c,sw=w)
 def dh(self,x1,x2,y,edge,label):
  for x in [x1,x2]:self.line(x,edge,x,y+2,LINE,.25)
  self.line(x1,y,x2,y,TEAL,.25)
  for x in [x1,x2]:self.line(x-1,y+1,x+1,y-1,TEAL,.35)
  self.text((x1+x2)/2,y-2,label,3,TEAL,anchor='middle')
 def dv(self,y1,y2,x,edge,label):
  for y in [y1,y2]:self.line(edge,y,x+2,y,LINE,.25)
  self.line(x,y1,x,y2,TEAL,.25)
  for y in [y1,y2]:self.line(x-1,y+1,x+1,y-1,TEAL,.35)
  self.text(x+3,(y1+y2)/2,label,3,TEAL)
 def panel(self,x,y,w,h,title):
  self.rect(x,y,w,h,'none',LINE,.25,2);self.text(x+5,y+8,title,3.5,TEAL,True)
 def save(self,slug):
  p=OUT/f'{self.n:02}-{slug}.svg';p.write_text('\n'.join(self.a+['</svg>']),encoding='utf8');pages.append(p)

def pod(s,x,y,k=1,rear=False):
 s.group(f'translate({x} {y}) scale({k})')
 s.rect(0,0,42,60,PALE,NAVY,.55,8)
 s.rect(1.8,1.8,38.4,56.4,'none',LINE,.3,6.4)
 if rear:
  s.rect(7,22,28,34,WHITE,TEAL,.5,3)
  s.rect(13,46,16,5,PALE,TEAL,.35,1)
  s.text(21,39,'BATTERY',2.8,anchor='middle')
  s.text(21,43,'RELEASE',2.5,anchor='middle')
  for a,b in [(6,7),(36,7),(5,53),(37,53)]:s.circle(a,b,1.3,WHITE)
 else:
  s.text(21,15,'NIVA',4.3,bold=True,anchor='middle')
  s.rect(17,24,8,2,TEAL,TEAL,.2,1)
  s.circle(21,38,5,TEAL,TEAL)
  s.text(21,52,'R',3.5,anchor='middle',bold=True)
 s.rect(14,60,14,6,PALE,TEAL,.4,2)
 s.end()

FOOT='M 26 0 C 10 0 2 12 1 31 C 0 54 6 84 13 111 C 21 141 15 168 17 196 C 13 225 14 252 33 259 C 52 263  seventy 252 72 235 C 79 215 77 190 74 172 C 76 145 86 119 94 88 C 101 64 89 42 72 26 C 55 10 42 0 26 0 Z'.replace('seventy','70')
SENS=[('P1',24,25),('P2',24,67),('P3',80,80),('P4',70,143),('P5',43,228)]
def insole(s,x,y,k=.65,trace=True,mirror=False):
 s.group(f'translate({x} {y}) scale({k})')
 if mirror:s.group('translate(96 0) scale(-1 1)')
 s.path(FOOT,PALE,NAVY,.65)
 s.path('M 44 5 L 39 35 Q 38 40 42 40 Q 45 40 45 35 L 50 9',WHITE,TEAL,.6)
 if trace:
  routes=['M 24 25 L 14 38 L 15 75 L 25 118 L 28 180 L 30 211 Q 32 240 64 235 L 75 232',
          'M 24 67 L 20 83 L 30 123 L 33 181 L 35 211 Q 37 232 64 230 L 75 232',
          'M 80 80 L 83 93 L 71 137 L 66 181 L 68 218 L 75 232',
          'M 70 143 L 61 177 L 62 214 L 75 232',
          'M 43 228 L 60 224 L 75 232']
  for d in routes:s.path(d,stroke=TEAL,sw=1,dash='3 2')
  for name,a,b in SENS:
   s.circle(a,b,8,'none',GREY,.3);s.circle(a,b,4.765,WHITE,TEAL,.7)
   # text outside mirror group would be better; this view only uses right-hand annotations
   if not mirror:
    if name in ['P1','P2']:s.text(a+10,b+1,name,5,TEAL,True)
    elif name=='P5':
     s.path('M 48 228 L 86 213 L 99 213',stroke=GREY,sw=.45)
     s.text(101,215,name,5,TEAL,True)
    else:
     s.line(a+5,b,99,b,GREY,.45);s.text(101,b+1,name,5,TEAL,True)
  s.rect(47,240,16,8,WHITE,TEAL,.6,1)
  if not mirror:
   s.path('M 63 244 L 89 255 L 99 255',stroke=GREY,sw=.45)
   s.text(101,257,'V1',5,TEAL,True)
 s.path('M 73 226 L 93 233 L 93 247 L 72 240',PALE,TEAL,.5)
 if not mirror:s.text(43,198,'R / M',6,NAVY,True,anchor='middle')
 if mirror:s.end()
 s.end()

# 01: form, dimensions, exploded stack
s=Sheet(1,'Shin pod / physical architecture','A calm, serviceable enclosure with a rear-removable battery and a stable lower-shin cradle.','1:1 VIEWS / NTS EXPLODED')
s.text(17,44,'01  FRONT',3.5,TEAL,True);pod(s,39,61)
s.dh(39,81,52,61,'42 P');s.dv(61,121,27,39,'60 P')
s.leader([(60,86),(94,77),(117,77)],'8 x 2 light window P')
s.leader([(60,99),(94,102),(117,102)],'10 dia. button P')
s.text(39,140,'PC/ABS shell / R8 plan corners P',3,GREY)
s.text(167,44,'02  SIDE',3.5,TEAL,True)
s.rect(168,61,20,60,PALE,NAVY,.5,5);s.line(178,65,178,117,TEAL,.4)
s.path('M 189 63 Q 197 89 189 119',stroke=NAVY,sw=1)
s.path('M 192 65 Q 200 89 192 117',stroke=TEAL,sw=1.5)
s.dh(168,188,52,61,'20 P');s.leader([(195,89),(215,87)],'soft pad')
s.text(164,140,'Cradle + pad add ~5 P',3,GREY)
s.text(267,44,'03  REAR / CRADLE REMOVED',3.5,TEAL,True);pod(s,279,61,rear=True)
s.dh(286,314,134,117,'28 P cartridge');s.leader([(300,110),(339,110),(347,97)])
s.label(345,62,'REAR ACCESS','Release is covered by the cradle. Detach pod before removing battery.',25)
s.text(17,157,'04  EXPLODED SECTION / SPACING EXAGGERATED',3.5,TEAL,True)
for x,y,w,h,lab in [(27,184,15,66,'A'),(60,184,5,66,'B'),(83,184,6,66,'C'),(109,184,14,66,'D'),(143,205,12,38,'E'),(176,184,9,66,'F'),(207,184,5,66,'G')]:
 s.rect(x,y,w,h,PALE,NAVY,.4,2);s.text(x+w/2,179,lab,3.5,TEAL,True,'middle')
for x in [49,73,99,133,165,196]:s.line(x,190,x,245,LINE,.25,'2 2')
s.arrow(223,215,234,215)
s.text(245,161,'ASSEMBLY',3.5,TEAL,True)
# replace paragraph with individually controlled assembly rows
s.rect(243,168,159,53,WHITE,WHITE,0)
for i,t in enumerate(['A  Front shell + one-piece button membrane','B  Replaceable perimeter gasket','C  PCB fixed to rear shell; IMU cannot float','D  Rear shell with cartridge rails','E  Sealed, protected battery cartridge','F  Side-keyed cradle and 35-wide ladder strap','G  Replaceable smooth silicone contact pad']):s.text(245,173+i*6.3,t,3.1)
s.panel(240,225,166,43,'PACKAGING DECISION')
s.para(245,240,'60 x 42 x 20 P is a revised custom-PCB target, not a proven fit. The brief\'s 48 x 34 x 13 envelope is not carried forward. Breakout-board v0 needs a separate larger enclosure after parts are measured.',74,3.05,leading=4.7)
s.text(19,265,'35 P strap width / soft radiused slots / flush rear service screws / no external charging port',3.2,GREY)
s.save('shin-pod')

# 02: sensor map and cross section
s=Sheet(2,'Insole / soft sensing architecture','Right medium insert shown. Left is mirrored. Sensor locations are design seeds, not measured anatomical fit.','0.65:1 PLAN / NTS SECTION')
s.text(16,44,'01  SENSOR MAP',3.5,TEAL,True);insole(s,28,64,.65)
s.dh(28,90.4,53,65,'96 P envelope');s.dv(64,233,17,28,'260 P')
s.text(32,247,'MEDIAL',3,TEAL);s.text(78,247,'LATERAL',3,TEAL)
s.text(17,260,'Dashed paths = routing intent only.',2.9,GREY)
s.text(17,266,'Sensor circles shown beneath top cover.',2.9,GREY)
s.label(111,45,'02  PLACEMENT / RIGHT FOOT','Datum: heel-most point, longitudinal axis parallel to drawing. X measured from medial envelope edge; Y measured forward from heel.',59)
for i,(a,b,c) in enumerate([('POINT','X / Y P','FUNCTION'),('P1','24 / 235','Big toe'),('P2','24 / 193','Medial forefoot'),('P3','80 / 180','Lateral forefoot'),('P4','70 / 117','Lateral midfoot'),('P5','43 / 32','Heel force')]):
 y=76+i*9;s.line(111,y+3,236,y+3,LINE,.2);s.text(113,y,a,3.05,TEAL if i==0 else NAVY,i==0);s.text(140,y,b,3.05);s.text(176,y,c,3.05)
s.label(111,140,'SENSOR GEOMETRY','A201 active diameter 9.53 V; thickness 0.203 V [S1]. Outer footprint, tails and recesses need supplier CAD. Do not substitute the active circle for a cutting outline.',57)
s.label(111,176,'TOE-POST ZONE','Soft slot 6 x 28 P; rounded termination. Keep traces outside a provisional 5-wide border. Validate toe-web fit across sizes. No field trimming in this revision.',57)
s.panel(108,215,134,54,'HOLD H1 / STOCK TAIL REACH')
s.para(113,230,'The toe-to-heel route exceeds the standard A201 length (~190.5 overall). Stock tails cannot simply reach a common heel junction. Use bench sensors first; wearable routing requires supplier-approved long-tail/custom flex parts. No hard extension joints underfoot.',57,3.05,leading=4.7)
s.text(259,44,'03  MATERIAL SECTION / SOFT STACK',3.5,TEAL,True)
layers=[('0.4 P','Sealed TPU-faced cover',5,PALE),('1.0 P','Continuous comfort foam',12,'#D4E8E8'),('0.203 V','Sensor; recessed routing',3,TEAL),('1.0 P','Pocketed EVA / TPU base',12,PALE)]
y=64
for thick,lab,h,col in layers:
 s.rect(260,y,141,h,col,NAVY,.3);s.text(263,y+h/2+1,thick+'  /  '+lab,2.9,WHITE if col==TEAL else NAVY);y+=h
s.path('M 260 65 L 257 65 L 257 96 L 260 96',stroke=TEAL,sw=.8)
s.text(260,109,'Nominal ~2.6 + adhesive; target ~2.8 P.',3.1,TEAL,True)
s.para(260,119,'V1: PVDF occupies a separate recessed heel zone beside P5. Its film, leads and cover must not create a thicker local stack.',63,3.1,leading=4.6)
s.label(260,144,'NO HARD SPOTS','No pucks, pins, crimps, solder or boards in the plantar envelope. Use flexible film and continuous cushioning. Calibration must include the complete assembled stack.',63)
s.label(260,183,'SEAL + REPAIR','3 P perimeter seal allowance; process trials required. Replace the sealed insert and tail as one unit. Electronics, ID resistor and rigid junctions stay above the shoe collar.',63)
s.label(260,225,'BEFORE WEAR','Check full tail geometry, sensor overlap, seal peel, bending, sweat ingress, thickness and local pressure under repeated loading. The supplied 1:1 outline is a fit-study template only.',63)
s.text(111,275,'[S1] Tekscan A201: tekscan.com/products-solutions/force-sensors/a201 (checked 28 Sep 2026)',2.6,GREY)
s.save('insole-sensor-stack')

# 03 footwear technical side views
def footwear(s,x,y,typ):
 s.group(f'translate({x} {y})')
 # leg silhouette, toe left, heel right
 s.path('M 68 0 C 67 24 63 55 62 77 C 62 89 49 92 34 96 L 12 99 Q 5 101 8 106 L 89 106 Q 95 101 91 91 C 87 79 89 35 94 0',PALE,GREY,.5)
 # footbed and sole
 s.path('M 6 108 Q 2 113 10 115 L 94 115 L 95 107 Z',WHITE,NAVY,.6)
 if typ!='shoe':s.path('M 8 106 L 94 105',stroke=TEAL,sw=1.2)
 if typ=='chappal':
  s.path('M 25 107 L 32 96 L 63 103',stroke=NAVY,sw=3)
  s.path('M 82 106 Q 97 92 92 86',stroke=TEAL,sw=1.6)
 elif typ=='sandal':
  s.path('M 25 107 L 28 97 L 39 96 L 37 107 Z',WHITE,NAVY,.6)
  s.path('M 53 106 L 55 89 L 66 88 L 67 106 Z',WHITE,NAVY,.6)
  s.path('M 66 92 L 91 86 L 94 99',stroke=NAVY,sw=2.2)
 else:
  s.path('M 8 105 Q 11 94 27 93 L 49 82 L 63 77 Q 72 87 92 79 L 96 107 Z',WHITE,NAVY,.6)
  for a,b in [(43,87),(49,84),(55,81)]:s.line(a,b,a+8,b+4,GREY,.7)
  s.path('M 12 107 L 91 107',stroke=TEAL,sw=.6,dash='2 1')
 # shin strap, pod reduced for functional drawing
 s.rect(65,32,27,12,WHITE,NAVY,.5,2)
 s.rect(78,23,17,26,PALE,NAVY,.7,3)
 s.text(86.5,31,'NIVA',2.3,bold=True,anchor='middle');s.circle(86.5,40,2,TEAL,TEAL)
 if typ=='shoe':
  s.path('M 86 49 C 86 63 84 73 87 85',stroke=TEAL,sw=2)
  s.path('M 87 85 L 90 103',stroke=TEAL,sw=.6,dash='2 1')
  s.rect(86,78,5,11,PALE,TEAL,.4,1)
 else:s.path('M 86 49 C 86 63 84 73 87 85 L 90 103',stroke=TEAL,sw=2)
 s.line(0,116,110,116,LINE,.3)
 s.end()
s=Sheet(3,'Footwear / one sensing platform','No rigid component sits in the shoe or beneath the foot. Retention changes; pod and sensing architecture remain common.','DIAGRAMMATIC')
for i,(title,typ) in enumerate([('CHAPPAL','chappal'),('SANDAL','sandal'),('SHOE','shoe')]):
 x=12+i*134;s.panel(x,40,128,181,title);footwear(s,x+8,60,typ)
 if i==0:txt='Toe-post slot clears the thong. Soft heel keeper locates the insert on the existing footbed. Validate migration.'
 elif i==1:txt='Use existing straps. Route the soft tail clear of buckle and heel-strap pressure. Add keeper only if needed.'
 else:txt='Replace removable sockliner when possible. Sleeve protects the collar exit. Confirm volume and heel clearance.'
 s.para(x+6,190,txt,52,3.15,leading=4.8)
s.panel(12,228,128,42,'GUMBOOTS + BAREFOOT')
s.para(18,242,'Use the supplied traction oversole if a boot shaft covers the pod or the shoe is too tight. Record the actual test footwear.',53,3.1,leading=4.7)
s.panel(146,228,128,42,'MOUNTING RULE')
s.para(152,242,'Cradle on anterolateral lower shin, clear of ankle bones. No fixed height fits everyone; confirm orientation and movement.',53,3.1,leading=4.7)
s.panel(280,228,128,42,'FIT CHECK')
s.para(286,242,'Seat insert; fasten pod; retain tail; verify anatomical side; check collar pressure; calibrate. Target <60 s, not yet proven.',53,3.1,leading=4.7)
s.save('footwear-integration')

# 04 interlock battery and keys
s=Sheet(4,'Battery / charging exclusion','Power is replenished only in a separate dock. The cartridge release is physically covered while the pod is seated.','1:1 BATTERY / NTS MECHANISM')
s.text(16,45,'01  REMOVE > RELEASE > DOCK',3.5,TEAL,True)
pod(s,26,60,.8,rear=True)
s.rect(22,73,42,34,'none',TEAL,.8,3)
s.text(43,122,'A  SEATED',3.2,TEAL,True,'middle')
s.arrow(68,86,88,86)
pod(s,95,60,.8,rear=True)
s.rect(126,92,22.4,27.2,PALE,TEAL,.6,2)
s.arrow(118,100,128,105)
s.text(118,133,'B  UNCLIP POD',3.2,TEAL,True,'middle')
s.arrow(153,86,174,86)
s.rect(180,77,72,36,PALE,NAVY,.6,5)
for xx in [188,219]:
 s.rect(xx,81,24,28,WHITE,TEAL,.4,2)
 s.rect(xx+4,65,16,20,PALE,TEAL,.5,2)
 s.arrow(xx+12,69,xx+12,80)
s.text(216,133,'C  CARTRIDGES ONLY',3.2,TEAL,True,'middle')
s.label(276,45,'MECHANICAL EXCLUSION','Cradle masks the rear release. Battery cannot exit while seated. Pod body cannot fit the recessed charger wells. No charging path is provided through the sensor connector.',56)
s.label(276,92,'ELECTRICAL EXCLUSION','Protection resides in cartridge; charging resides in dock. Recessed contacts, polarity key and temperature sensing. Charger fault design still requires electrical review.',56)
s.text(16,151,'02  CARTRIDGE ENVELOPE',3.5,TEAL,True)
s.rect(28,173,28,34,PALE,NAVY,.5,3)
s.rect(31,177,22,23,'none',GREY,.3,1)
s.text(42,186,'CELL',3,anchor='middle');s.text(42,191,'ENVELOPE',2.4,anchor='middle')
s.rect(31,201,22,3,WHITE,TEAL,.3)
for x in [34,39,44,49]:s.rect(x,207,2,2,TEAL,TEAL,.1)
s.dh(28,56,163,173,'28 P');s.dv(173,207,18,28,'34 P')
s.rect(75,173,8,34,PALE,NAVY,.4,2);s.dh(75,83,163,173,'8 P')
s.label(98,158,'CONTACTS + CELL','Four protected contacts: B+, B-, NTC, ID. Cell envelope 22 x 23 x 5 P; capacity is unassigned until supplier selection. The brief\'s 300 mAh target is not a fit guarantee.',64)
s.label(98,204,'SERVICE DETAIL','Cartridge shell encloses the protected cell. No patient access to pouch or raw tabs. Rails, latch forces, seals and swelling allowance need supplier and mechanical review.',64)
s.text(276,151,'03  LEFT / RIGHT KEY INTENT',3.5,TEAL,True)
for xx,lab,notch in [(284,'L',0),(346,'R',1)]:
 s.rect(xx,166,40,21,PALE,NAVY,.5,3)
 s.rect(xx+7,171,26,10,WHITE,TEAL,.4,1)
 s.rect(xx+7 if notch==0 else xx+28,171,5,4,TEAL,TEAL,.2)
 s.text(xx+20,196,lab,4,TEAL,True,'middle')
s.para(276,211,'Different physical keys at the pod; readable L/R and tactile markers. Side/size ID resistor is in the above-collar connector assembly, paired to its insert.',56,3.1,leading=4.6)
s.panel(12,247,396,24,'RELEASE GATES')
s.text(18,263,'Confirm: no charge while seated; contact shorts; temperature fault; reversed insertion; latch wear; whole left kit fitted on right leg.',3.05)
s.save('battery-and-side-keys')

# 05 electronic architecture + packaging
s=Sheet(5,'Electronics / interfaces and zoning','Architecture follows Claude\'s brief. This is a spatial and interface drawing, not a released schematic or PCB layout.','NTS / PCB ENVELOPE 1.4:1')
s.text(16,44,'01  SIGNAL ARCHITECTURE',3.5,TEAL,True)
def block(x,y,w,h,a,b=''):
 s.rect(x,y,w,h,PALE,TEAL,.4,2);s.text(x+3,y+7,a,3.3,bold=True)
 if b:s.text(x+3,y+13,b,2.8,GREY)
block(17,56,56,20,'5 force regions','Passive insert')
block(17,90,56,20,'Heel PVDF film','No rigid crimp underfoot')
block(90,56,62,20,'Force analog front end','Range + settling trials')
block(90,90,62,20,'Piezo buffer + filter','Clamp / bias / anti-alias')
block(172,70,60,23,'MCP3208','8-channel ADC / SPI')
s.arrow(73,65,90,65);s.arrow(73,100,90,100)
s.path('M 152 65 L 161 65 L 161 77 L 172 77',stroke=TEAL)
s.path('M 152 100 L 161 100 L 161 86 L 172 86',stroke=TEAL)
block(172,113,60,20,'LSM6DSO32','SPI + data-ready')
block(91,151,83,23,'ESP32-C3-MINI-1','BLE / local flash / timebase')
s.path('M 232 81 L 243 81 L 243 142 L 154 142 L 154 151',stroke=TEAL)
s.path('M 232 123 L 243 123',stroke=TEAL)
s.circle(243,123,.7,TEAL,TEAL,.2)
block(17,200,64,20,'Battery cartridge','Protection / no charger')
block(94,200,71,20,'Regulation + fuel gauge','TLV755 / MAX17048 candidates')
s.arrow(81,210,94,210);s.arrow(130,200,130,174)
s.arrow(91,162,64,162);s.text(18,160,'BLE to phone',3.2);s.text(18,166,'offline capture',2.8,GREY)
s.arrow(174,162,201,162);s.text(205,161,'Peer sync',3.2);s.text(205,167,'bench verify',2.8,GREY)
s.text(261,44,'02  PCB / BATTERY ZONING',3.5,TEAL,True)
s.rect(282,61,50.4,70,PALE,NAVY,.5,3)
s.rect(288,65,18.48,23.24,WHITE,TEAL,.5,1)
s.text(309,71,'ESP32',2.7);s.text(309,76,'module',2.7)
s.rect(284,62,46,16,'none',AMBER,.4,1,'2 1')
s.text(288,84,'13.2 x 16.6 V [S2]',2.6)
s.rect(288,92,15,11,WHITE,NAVY,.3,1);s.text(290,99,'IMU',3)
s.rect(310,93,17,13,WHITE,NAVY,.3,1);s.text(312,101,'ADC',3)
s.rect(287,110,40,10,WHITE,TEAL,.3,1);s.text(289,117,'ANALOG FRONT END',2.6)
s.rect(296,125,21,7,WHITE,TEAL,.3,1)
s.dh(282,332.4,52,61,'36 P PCB');s.dv(61,131,341,332.4,'50 P')
s.leader([(286,64),(270,64),(262,84)])
s.text(258,94,'RF keepout',2.7,AMBER)
s.label(355,62,'ZONE RULES','Antenna at top edge. No cell or metal over antenna region. Exact keepout per module integration guide. IMU rigidly fixed.',22)
s.label(261,148,'10-CONTACT STRIP / FUNCTIONAL MAP','1 VEXC; 2-6 FORCE1-5; 7 PZ+; 8 PZ-; 9 ID; 10 GND / shield drain. Final sensor drive topology may change the pinout. No power-input function.',65)
s.label(261,188,'ROUTING + SEAL','14-wide sleeve P; tail length selected to fit. Shield the piezo pair, retain slack in cradle, and keep every rigid junction above collar. Bend radius awaits cable selection.',65)
s.panel(12,233,396,37,'ELECTRICAL REVIEW HOLDS / DO NOT COPY THE BRIEF INTO A PCB UNCHECKED')
s.para(18,247,'Verify sensor drive circuit, ADC source settling, boot-strapping pins with button held, RF coexistence, battery sag / regulator dropout, dock thermal-fault shutdown and sync accuracy. Manufacturer A201 performance uses an op-amp circuit [S1]; divider performance must be established separately.',164,3.05,leading=4.8)
s.text(16,276,'[S2] Espressif ESP32-C3-MINI-1 datasheet v2.2: documentation.espressif.com/esp32-c3-mini-1_datasheet_en.pdf',2.6,GREY)
s.save('electronics-and-packaging')

# 06 camp kit and gates
s=Sheet(6,'Camp kit / service and development gates','A washable, modular field kit. The drawings define design intent while preserving the brief\'s bench-first development sequence.','1:2 CASE PLAN / NTS DETAILS')
s.text(16,45,'01  CASE + REMOVABLE TRAY',3.5,TEAL,True)
s.rect(22,54,200,165,PALE,NAVY,.65,9)
s.rect(26,58,192,157,WHITE,NAVY,.3,7)
s.dh(22,222,49,54,'400 P');s.dv(54,219,16,22,'330 P')
s.rect(28,62,73,147,PALE,TEAL,.35,5)
s.text(33,69,'S / M / L INSERT SETS',3,TEAL,True)
insole(s,34,73,.5,False);insole(s,50,74,.5,False,True)
s.rect(104,72,97,39,PALE,TEAL,.35,3)
pod(s,111,77,.38);pod(s,135,77,.38)
s.text(161,84,'PODS',3.1,TEAL,True);s.text(161,91,'Straps tucked',2.7);s.text(161,96,'in open recess',2.7)
s.rect(104,117,97,30,PALE,TEAL,.35,3)
for x in [109,128,147,166]:s.rect(x,123,14,17,WHITE,NAVY,.35,2)
s.text(108,145,'FOUR CARTRIDGES / TWO DOCK WELLS',2.5,TEAL)
s.rect(104,153,97,30,PALE,TEAL,.35,3)
s.rect(110,158,52,20,WHITE,NAVY,.3,2)
s.text(114,170,'USB POWER BANK',2.8)
s.path('M 172 159 C 191 156 193 175 176 176 C 164 172 171 163 184 165',stroke=TEAL,sw=1)
s.rect(92,218,59,6,PALE,NAVY,.5,2)
s.text(105,195,'DEPTH 115 P',3.1,TEAL,True)
s.text(105,201,'Insert bay: 294 P usable length.',2.8,GREY)
s.text(105,207,'Fit largest size before tray tooling.',2.8,GREY)
s.label(234,45,'TRAY + HYGIENE','Smooth removable polypropylene tray, open radiused recesses and no absorbent foam. Separate clean and used items during camp turnaround. Gasket and cleaning compatibility require tests.',76)
s.label(234,85,'CONTENTS','Two pods; size-matched insert pairs; two spare cartridges; dock; USB supply cable; power bank; replacement straps; heel keepers. Oversoles travel in a removable wipeable lid pouch.',76)
s.text(234,125,'SERVICE PARTS',3.5,TEAL,True)
s.rect(232,131,174,49,WHITE,WHITE,0)
for i,t in enumerate(['01 Pod assembly    02 Cradle + pad    03 Strap','04 Battery cartridge    05 Insole + protected tail','06 Heel keeper    07 Traction oversole','08 Dock + removable case tray']):s.text(234,139+i*8,t,3.1)
s.label(234,179,'BASE KIT ONLY','Optional knee acoustic module is not included. No disease score or medial contact-force claim is embodied in the hardware drawings.',76)
s.panel(12,227,396,44,'BUILD SEQUENCE / KEEP HIGH-RISK DECISIONS VISIBLE')
for x,title,body in [(18,'01 BENCH','Sensor range, soft stack,\ntail noise and analog drive.'),(117,'02 FIT STUDY','Print outline; measure feet;\ncheck footwear and migration.'),(216,'03 WORKING V0','Measured breakout enclosure;\nlog raw data and test faults.'),(315,'04 ENGINEERED V1','Resolve H1 and component fit;\nthen PCB, seals and tooling.')]:
 s.text(x,243,title,3.2,TEAL,True)
 for j,l in enumerate(body.split('\n')):s.text(x,251+j*5,l,3)
s.save('camp-kit-and-roadmap')

# Supplemental 1:1 vector fit template, separate from six-sheet PDF.
t=Sheet(7,'Medium insert / full-size fit study','RIGHT + LEFT / Proposed geometry only. Not a cutting master, sensor tooling or clinical fitting guide.','1:1 AT 100%')
# clear standard sheet body and custom footer numbering
t.rect(12,33,396,244,WHITE,WHITE,0)
# Fits 260mm only by using entire page height with bespoke header/footer: new SVG
t.a=[t.a[0]];t.rect(0,0,420,297,WHITE,WHITE,0)
t.text(12,12,'NIVA / MEDIUM FIT STUDY / 1:1',5,TEAL,True)
t.text(12,19,'Print A3 at 100%. Measure the 100 mm check bar before use. Proposed outline; do not fabricate sensors from this file.',3,GREY)
insole(t,31,26,1,False);insole(t,174,26,1,False,True)
t.text(78,289,'RIGHT',3.5,TEAL,True,'middle');t.text(223,289,'LEFT',3.5,TEAL,True,'middle')
t.text(302,40,'260 x 96 P',4,TEAL,True)
t.para(302,51,'Foot outline only. Confirm heel, metatarsal heads, toe-web position and soft tissue clearance on measured users. This is not an approved size standard.',43,3.3,leading=5.3)
t.label(302,105,'NO AUTOMATIC GRADING','Small and large outlines need anatomical fitting. Do not uniformly scale the sensor map and assume alignment.',41)
t.line(302,230,402,230,NAVY,.6);t.line(302,226,302,234,NAVY,.6);t.line(402,226,402,234,NAVY,.6)
t.text(352,241,'100 mm PRINT CHECK',3.5,TEAL,True,'middle')
t.text(302,271,'NV-ID-T01 / REV A',3.1,GREY)
(OUT/'07-full-size-fit-template.svg').write_text('\n'.join(t.a+['</svg>']),encoding='utf8')

pdf=OUT/'NIVA-vector-blueprints-Rev-A.pdf'
c=canvas.Canvas(str(pdf),pagesize=(420*72/25.4,297*72/25.4))
c.setTitle('NIVA | Industrial design blueprint set | Rev A');c.setAuthor('NIVA concept design development')
for p in pages:
 d=svg2rlg(str(p));renderPDF.draw(d,c,0,0);c.showPage()
c.save()
doc=fitz.open(pdf)
for i,p in enumerate(doc):
 pix=p.get_pixmap(matrix=fitz.Matrix(1.3,1.3),alpha=False);pix.save(WORK/f'blueprint-{i+1:02}.png')
thumbs=[]
for i in range(6):
 im=Image.open(WORK/f'blueprint-{i+1:02}.png').convert('RGB');im.thumbnail((840,594));thumbs.append(im)
contact=Image.new('RGB',(1680,1782),'#d7dfe2')
for i,im in enumerate(thumbs):contact.paste(im,((i%2)*840,(i//2)*594))
contact.save(WORK/'blueprint-contact.png')
print(f'Created {len(pages)} vector PDF pages and 7 SVG files in {OUT}')
