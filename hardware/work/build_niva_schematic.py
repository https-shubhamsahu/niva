from pathlib import Path
import uuid,json,math,copy,shutil
from sexputils import *
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs/NIVA-3D-engineering-prototype/electronics';OUT.mkdir(parents=True,exist_ok=True)
LIB=ROOT/'work/tools3d/kicad/share/kicad/symbols';FP=OUT/'NIVA.pretty';FP.mkdir(exist_ok=True)
uid=lambda:str(uuid.uuid4())
q=lambda s:json.dumps(str(s))
FX=lambda size=1.0:f'(effects (font (size {size} {size})))'
custom={}
def chip(name,pins):
 # pins = (number, name, electrical type), explicit pins including no-connects
 left=pins[:(len(pins)+1)//2];right=pins[(len(pins)+1)//2:];h=max(len(left),len(right))*2.54+2.54
 g=f'(symbol "{name}" (pin_names (offset 0.508)) (in_bom yes) (on_board yes) (property "Reference" "U" (at 0 {h/2+3} 0) {FX()}) (property "Value" "{name}" (at 0 {-h/2-3} 0) {FX()}) (symbol "{name}_0_1" (rectangle (start -10 {h/2}) (end 10 {-h/2}) (stroke (width 0.254) (type default)) (fill (type background))))'
 a=parse(g);p=['symbol',name+'_1_1'];p[0]=Atom('symbol')
 for side,group in [(-1,left),(1,right)]:
  for i,(num,nam,kind) in enumerate(group):
   y=h/2-2.54-i*2.54;x=side*15.08;ang=0 if side==-1 else 180
   p.append(parse(f'(pin {kind} line (at {x} {y} {ang}) (length 5.08) (name {q(nam)} {FX()}) (number {q(num)} {FX()}))'))
 a.append(p);custom[name]=a
chip('LSM6DSO32',[('1','SDO','output'),('2','SDx','input'),('3','SCx','input'),('4','INT1','output'),('5','VDDIO','power_in'),('6','GND','power_in'),('7','GND','power_in'),('8','VDD','power_in'),('9','INT2','output'),('10','NC','no_connect'),('11','NC','no_connect'),('12','CS','input'),('13','SCK','input'),('14','SDI','input')])
chip('MAX17048',[('1','CTG','power_in'),('2','CELL','power_in'),('3','VDD','power_in'),('4','GND','power_in'),('5','ALRT','open_collector'),('6','QSTRT','input'),('7','SCL','input'),('8','SDA','bidirectional'),('9','EP','power_in')])
class Sch:
 def __init__(self,name,title,paper='A2'):
  self.name=name;self.title=title;self.paper=paper;self.root=uid();self.libs={};self.items=[];self.parts=[]
 def text(self,x,y,txt,size=1.6):self.items.append(f'(text {q(txt)} (at {x} {y} 0) {FX(size)} (uuid "{uid()}"))')
 def wire(self,x1,y1,x2,y2):self.items.append(f'(wire (pts (xy {x1} {y1}) (xy {x2} {y2})) (stroke (width 0) (type default)) (uuid "{uid()}"))')
 def label(self,x,y,net,angle=0):self.items.append(f'(label {q(net)} (at {x} {y} {angle}) (effects (font (size 1 1)) (justify left bottom)) (uuid "{uid()}"))')
 def part(self,libid,ref,value,x,y,nets,footprint='',rotation=0,board=True):
  lib,nam=libid.split(':')
  if lib=='NIVA':a=copy.deepcopy(custom[nam])
  elif lib=='Espressif':a=resolve(ROOT/'work/espressif/Espressif.kicad_sym',nam)
  else:a=resolve(LIB/(lib+'.kicad_sym'),nam)
  a[1]=libid;self.libs[libid]=a
  pins=[]
  for sub in allof(a,'symbol'):
   for p in allof(sub,'pin'):
    num=find(p,'number')[1];pn=find(p,'name')[1];pos=find(p,'at');px=float(pos[1]);py=float(pos[2]);ang=float(pos[3])
    pins.append((num,pn,px,py,ang))
  # Native instance; fixed property placement avoids inherited text colliding with pin labels.
  u=uid();half=max([abs(p[3]) for p in pins]+[4])
  if ref[0] in ['R','C','D']:
   rx=x+4;ry=y-1;vy=y+1.5
  else:rx=x;ry=y-half-6;vy=y-half-3.3
  body=f'(symbol (lib_id {q(libid)}) (at {x} {y} {rotation}) (unit 1) (in_bom yes) (on_board {"yes" if board else "no"}) (dnp no) (uuid "{u}")'
  body+=f'(property "Reference" {q(ref)} (at {rx} {ry} 0) {FX()}) (property "Value" {q(value)} (at {rx} {vy} 0) {FX()})'
  body+=f'(property "Footprint" {q(footprint)} (at {x} {y} 0) (effects (font (size 1 1)) hide))'
  for num,*_ in pins:body+=f'(pin {q(num)} (uuid "{uid()}"))'
  body+=f'(instances (project {q(self.name)} (path "/{self.root}" (reference {q(ref)}) (unit 1))))'
  self.items.append(body)
  done=set()
  for num,pn,px,py,ang in pins:
   theta=math.radians(rotation);xx=x+px*math.cos(theta)-py*math.sin(theta);yy=y-px*math.sin(theta)-py*math.cos(theta)
   xx=round(xx,4);yy=round(yy,4);key=(xx,yy)
   if key in done:continue
   done.add(key);net=nets.get(str(num))
   if not net:self.items.append(f'(no_connect (at {xx} {yy}) (uuid "{uid()}"))');continue
   a2=math.radians(ang+rotation);ex=round(xx-5.08*math.cos(a2),4);ey=round(yy+5.08*math.sin(a2),4)
   self.wire(xx,yy,ex,ey);self.label(ex,ey,net,0 if math.cos(a2)<.5 else 180)
  self.parts.append(dict(ref=ref,value=value,footprint=footprint,nets=nets,uuid=u,board=board))
 def save(self):
  txt=f'(kicad_sch (version 20250114) (generator "eeschema") (uuid "{self.root}") (paper "{self.paper}") (title_block (title {q(self.title)}) (date "2026-09-28") (rev "B - ENGINEERING DRAFT") (company "NIVA") (comment 1 "NOT FOR FABRICATION / values and protection require bench validation"))'
  txt+='(lib_symbols '+' '.join(dump(a) for a in self.libs.values())+')'+'\n'.join(self.items)+f'(sheet_instances (path "/" (page "1"))) (embedded_fonts no))'
  (OUT/(self.name+'.kicad_sch')).write_text(txt,encoding='utf8')
  (OUT/(self.name+'.kicad_pro')).write_text('{}')
  return self.parts
sch=Sch('NIVA-controller','NIVA | Controller, acquisition and power | Revision B')
sch.text(295,18,'NIVA / CONTROLLER + ACQUISITION / ENGINEERING DRAFT',3)
sch.text(105,31,'01  CONTROLLER / BOOT / SERVICE',2)
sch.text(280,31,'02  ADC + INERTIAL SENSOR',2)
u1={str(n):'GND' for n in [1,2,11,14]+list(range(36,54))}
u1.update({'3':'+3V3','5':'I2C_SCL','6':'BUTTON','8':'CHIP_EN','12':'I2C_SDA','13':'IMU_INT','16':'CS_IMU','18':'SPI_SCK','19':'SPI_MISO','20':'SPI_MOSI','21':'CS_ADC','22':'BOOT8','23':'BOOT9','26':'USB_DM','27':'USB_DP','30':'LED_R','31':'LED_G'})
sch.part('Espressif:ESP32-C3-MINI-1','U1','ESP32-C3-MINI-1',95,97,u1,'NIVA:ESP32-C3-MINI-1')
adc={str(i):f'F{i}_ADC' for i in range(1,6)};adc.update({'6':'PIEZO_ADC','7':'VEXC_HALF','8':'INSERT_ID','9':'GND','10':'CS_ADC','11':'SPI_MOSI','12':'SPI_MISO','13':'SPI_SCK','14':'GND','15':'+3V3','16':'+3V3'})
sch.part('Analog_ADC:MCP3208','U2','MCP3208-BI/SL',263,72,adc,'Package_SO:SOIC-16_3.9x9.9mm_P1.27mm')
sch.part('NIVA:LSM6DSO32','U3','LSM6DSO32TR',428,72,{'1':'SPI_MISO','2':'GND','3':'GND','4':'IMU_INT','5':'+3V3','6':'GND','7':'GND','8':'+3V3','12':'CS_IMU','13':'SPI_SCK','14':'SPI_MOSI'},'Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y')
RFP='Resistor_SMD:R_0603_1608Metric';CFP='Capacitor_SMD:C_0603_1608Metric'
def R(ref,value,x,y,n1,n2):sch.part('Device:R',ref,value,x,y,{'1':n1,'2':n2},RFP)
def C(ref,value,x,y,n1,n2):sch.part('Device:C',ref,value,x,y,{'1':n1,'2':n2},CFP)
for ref,net,x in [('R1','CHIP_EN',40),('R2','BOOT8',72),('R3','BOOT9',104),('R4','I2C_SCL',136),('R5','I2C_SDA',168),('R6','BUTTON',200)]:R(ref,'10k' if ref not in ['R4','R5'] else '4.7k',x,172,'+3V3',net)
C('C1','1u',40,205,'CHIP_EN','GND');C('C2','10u',72,205,'+3V3','GND');C('C3','100n',104,205,'+3V3','GND');C('C4','100n',136,205,'+3V3','GND');C('C5','100n',168,205,'+3V3','GND')
sch.part('Switch:SW_Push','SW1','USER BUTTON',200,206,{'1':'BUTTON','2':'GND'},'Button_Switch_SMD:SW_SPST_TL3342')
sch.text(102,225,'GPIO3 button avoids the original GPIO2 boot-button conflict.',1.25)
sch.text(106,232,'GPIO0/2 = I2C; GPIO8/9 dedicated boot pulls. Validate reset behavior.',1.25)
sch.part('Regulator_Linear:TLV75533PDBV','U5','TLV75533PDBV',292,169,{'1':'VBAT','2':'GND','3':'VBAT','5':'+3V3'},'Package_TO_SOT_SMD:SOT-23-5')
C('C6','1u',253,198,'VBAT','GND');C('C7','10u',292,207,'+3V3','GND');C('C8','100n',326,198,'+3V3','GND')
sch.part('NIVA:MAX17048','U6','MAX17048G+',426,172,{'1':'GND','2':'VBAT','3':'VBAT','4':'GND','6':'GND','7':'I2C_SCL','8':'I2C_SDA','9':'GND'},'Package_DFN_QFN:DFN-8-1EP_2x2mm_P0.5mm_EP0.9x1.3mm')
C('C9','100n',426,208,'VBAT','GND')
sch.part('Connector_Generic:Conn_01x04','J2','REMOVABLE PROTECTED BATTERY',531,164,{'1':'VBAT','2':'GND','3':'PACK_NTC','4':'PACK_ID'},'Connector_JST:JST_GH_SM04B-GHS-TB_1x04-1MP_P1.25mm_Horizontal')
sch.part('Connector_Generic:Conn_01x06','J3','INTERNAL SERVICE PADS',530,216,{'1':'GND','2':'USB_DM','3':'USB_DP','4':'CHIP_EN','5':'BOOT9','6':'+3V3'},'Connector_PinHeader_2.54mm:PinHeader_1x06_P2.54mm_Vertical')
sch.text(510,239,'Service pads have no battery-charge input.',1.25)
sch.text(296,258,'03  PASSIVE INSERT / FIVE DIVIDER CHANNELS (BENCH TOPOLOGY)',2)
j1={'1':'+3V3','7':'PVDF_RAW','8':'GND','9':'INSERT_ID','10':'GND'};j1.update({str(i+1):f'F{i}_RAW' for i in range(1,6)})
sch.part('Connector_Generic:Conn_01x10','J1','KEYED SENSOR TAIL',40,299,j1,'Connector_JST:JST_GH_SM10B-GHS-TB_1x10-1MP_P1.25mm_Horizontal')
for i,x in enumerate([112,181,250,319,388],1):
 sch.text(x,275,f'F{i}: CALIBRATE COMPLETE SOFT STACK',1.2)
 R(f'R{10+i}','10k',x,296,f'F{i}_RAW','GND')
 R(f'R{20+i}','3.3k',x,328,f'F{i}_RAW',f'F{i}_ADC')
 C(f'C{10+i}','1u',x,363,f'F{i}_ADC','GND')
R('R30','10k',475,284,'+3V3','INSERT_ID');R('R31','10k',475,322,'+3V3','VEXC_HALF');R('R32','10k',475,358,'VEXC_HALF','GND')
sch.text(275,386,'Sensor excitation is continuous in Rev B. Divider force transfer function is experimental; A201 op-amp topology is not assumed equivalent.',1.35)
sch.text(275,393,'PACK_NTC / PACK_ID are reserved for dock/service sensing. No charger exists on this wearable board.',1.35)
parts=sch.save()
# Analog subcircuit is a separate project with explicit harness-to-controller interfaces.
main=sch;sch=Sch('NIVA-heel-and-indicator','NIVA | Heel vibration and status light | Companion circuit','A3')
sch.text(210,19,'NIVA / HEEL VIBRATION + STATUS / ENGINEERING DRAFT',2.5)
sch.text(85,35,'01  MID-RAIL AND INPUT BIAS',1.8)
R('R40','100k',45,60,'+3V3','VMID');R('R41','100k',45,92,'VMID','GND');C('C40','1u',83,92,'VMID','GND')
R('R42','100k',123,60,'PVDF_RAW','PZ_BIAS');R('R43','10Meg',123,97,'VMID','PZ_BIAS')
sch.part('Amplifier_Operational:MCP6001-OT','U4','MCP6001-OT',225,77,{'1':'PZ_BUF','2':'GND','3':'PZ_BIAS','4':'PZ_BUF','5':'+3V3'},'Package_TO_SOT_SMD:SOT-23-5')
R('R44','1k',300,64,'PZ_BUF','PIEZO_ADC');C('C41','220n',300,102,'PIEZO_ADC','GND');C('C42','100n',225,117,'+3V3','GND')
sch.part('Device:D_Small','D2','LOW-LEAK CLAMP / SELECT',160,146,{'1':'+3V3','2':'PZ_BIAS'},'Diode_SMD:D_SOD-323')
sch.part('Device:D_Small','D3','LOW-LEAK CLAMP / SELECT',226,146,{'1':'PZ_BIAS','2':'GND'},'Diode_SMD:D_SOD-323')
sch.text(208,166,'Clamps require leakage/capacitance selection. Single-pole output filter is a bench starting point, not a validated anti-alias filter.',1.15)
sch.text(103,184,'02  TWO-CHANNEL STATUS / RED + GREEN = AMBER',1.8)
R('R45','1k',60,213,'LED_R','LED_R_A');R('R46','1k',142,213,'LED_G','LED_G_A')
sch.part('Device:LED','D4','RED',60,247,{'1':'GND','2':'LED_R_A'},'LED_SMD:LED_0603_1608Metric')
sch.part('Device:LED','D5','GREEN',142,247,{'1':'GND','2':'LED_G_A'},'LED_SMD:LED_0603_1608Metric')
sch.text(285,211,'Companion circuit: merge by matching net names.',1.2)
sch.text(285,219,'Two emitters share the single light window.',1.2)
sch.text(285,227,'No medical-result colour semantics.',1.2)
sch.text(285,239,'Protection, saturation and cable-noise tests required.',1.2)
sch.text(285,247,'This sheet is not yet incorporated into the placement PCB.',1.2)
analog=sch.save()
# Native library cache is self contained. Preserve the official Espressif footprint source.
shutil.copy(ROOT/'work/espressif/ESP32-C3-MINI-1.kicad_mod',FP/'ESP32-C3-MINI-1.kicad_mod')
(OUT/'fp-lib-table').write_text('(fp_lib_table (lib (name "NIVA") (type "KiCad") (uri "${KIPRJMOD}/NIVA.pretty") (options "") (descr "Official Espressif module footprint; source in README")))')
(OUT/'component-net-map.json').write_text(json.dumps(parts,indent=2))
(OUT/'analog-component-net-map.json').write_text(json.dumps(analog,indent=2))
(OUT/'pin-map.csv').write_text('Reference,Value,Pin,Net\n'+'\n'.join(f'{p["ref"]},{p["value"]},{pin},{net}' for p in parts+analog for pin,net in p['nets'].items()))
print('Created native KiCad schematics:',len(parts),'main parts +',len(analog),'analog parts')
