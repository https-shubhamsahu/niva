from pathlib import Path
import json, math
import FreeCAD as A, Part, Mesh, MeshPart
V=A.Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'outputs'/'NIVA-3D-engineering-prototype';CAD=OUT/'mechanical';PRINT=CAD/'STL-print-parts';MESH=ROOT/'work'/'niva-meshes'
for p in [OUT,CAD,PRINT,MESH]:p.mkdir(parents=True,exist_ok=True)
doc=A.newDocument('NIVA_RevB_Prototype')
report=[];manifest=[]
def rr(w,h,r,z,t,x=0,y=0):
 q=Part.makeBox(w-2*r,h,t,V(x+r,y,z)).fuse(Part.makeBox(w,h-2*r,t,V(x,y+r,z)))
 for xx,yy in [(r,r),(w-r,r),(w-r,h-r),(r,h-r)]:q=q.fuse(Part.makeCylinder(r,t,V(x+xx,y+yy,z)))
 return q.removeSplitter()
def box(x,y,z,w,h,t):return Part.makeBox(w,h,t,V(x,y,z))
def cyl(x,y,z,r,h):return Part.makeCylinder(r,h,V(x,y,z))
def add(name,shape,material,printable=False,desc=''):
 shape=shape.removeSplitter();assert shape.isValid(),name+' invalid';assert len(shape.Solids)==1,name+' disconnected'
 obj=doc.addObject('PartDesign::Feature',name);obj.Label=name.replace('_',' ');obj.Shape=shape
 obj.addProperty('App::PropertyString','DesignStatus');obj.DesignStatus='PROTOTYPE / NOT A RELEASED MEDICAL DEVICE'
 obj.addProperty('App::PropertyString','Description');obj.Description=desc
 mesh=MeshPart.meshFromShape(Shape=shape,LinearDeflection=.08,AngularDeflection=.16,Relative=False)
 mesh.write(str(MESH/(name+'.stl')))
 if printable:
  pm=mesh.copy();bb=pm.BoundBox;pm.translate(-bb.XMin,-bb.YMin,-bb.ZMin);pm.write(str(PRINT/(name+'.stl')))
  Part.export([obj],str(CAD/(name+'.step')))
 manifest.append(dict(name=name,material=material,stl=str(MESH/(name+'.stl')),printable=printable))
 report.append(dict(part=name,valid=shape.isValid(),solids=len(shape.Solids),volume_mm3=round(shape.Volume,2),closed_mesh=mesh.isSolid(),bounds_mm=[round(shape.BoundBox.XLength,3),round(shape.BoundBox.YLength,3),round(shape.BoundBox.ZLength,3)]))
 return obj
W,H=42,60
outer=rr(W,H,8,0,14)
inner=rr(38.4,56.4,6.2,1.8,13,1.8,1.8)
rear=outer.cut(inner)
# Battery rails and separated rear battery compartment; open to the rear.
batteryframe=rr(31,37,3,0,10,5.5,3.5).cut(rr(28.8,34.8,2, -.1,9.0,6.6,4.6))
rear=rear.fuse(batteryframe)
rear=rear.cut(rr(28.8,34.8,2,-.5,10.1,6.6,4.6))
for x,y in [(4,4),(38,4),(4,56),(38,56)]:
 rear=rear.fuse(cyl(x,y,1,2.6,13).common(outer))
 rear=rear.cut(cyl(x,y,5,0.85,10))
# cable aperture and rear cartridge retaining screw post.
rear=rear.cut(box(13.6,-1,8.8,14.8,4,4.8))
rear=rear.fuse(box(17,39.4,0,8,5,9))
rear=rear.cut(cyl(21,42,0,0.85,7))
rear=rear.cut(rr(8.8,6.8,1, -.1,2,16.6,37.7))
rear=rear.cut(rr(35,49,4,13.3,1,3.5,5.5)) if False else rear
add('01_RearHousing',rear,'navy',True,'60 x 42 x 14. 1.8 mm nominal walls. M2 pilot holes require tap/fit trial. Battery accessible from rear only.')
# Front cap includes 1.8 mm face and locating rim. Top face z20.
front=rr(42,60,8,14,6).cut(rr(38.4,56.4,6.2,13.8,4.4,1.8,1.8))
front=front.cut(cyl(21,22,17.5,5.15,4))
front=front.cut(rr(8.3,2.5,1.1,17.5,4,16.85,33.75))
for x,y in [(4,4),(38,4),(4,56),(38,56)]:
 front=front.cut(cyl(x,y,13.5,1.15,8)).cut(cyl(x,y,18.8,2,2))
add('02_FrontCover',front,'grey',True,'Print with cosmetic front face on bed. M2 clearance 2.3 mm and screw-head recesses. No waterproof rating.')
# Cartridge rear face, cup and lid, 0.4 mm nominal cavity clearance.
cart=rr(28,34,2,0,8,7,5).cut(rr(25,31,1,1.4,8,8.5,6.5))
tab=rr(8,6,1,0,1.6,17,38).cut(cyl(21,42,-.1,1.1,2))
cart=cart.fuse(tab)
# protected contact apertures at top end
for x in [11,17,23,29]:cart=cart.cut(box(x,37.5,3,2.4,2,2.6))
add('03_BatteryCartridgeCup',cart,'navy',True,'Blank cell cartridge. No live cell supplied. Rear M2 retention tab is concealed by cradle.')
lid=rr(27.6,33.6,1.8,8.0,1.2,7.2,5.2)
add('04_BatteryCartridgeLid',lid,'navy',True,'Prototype lid, tape or supplier-approved fastening for bench dummy only. Live-cell retention remains an engineering hold.')
cell=rr(22,23,1,1.8,5,10,8)
add('Battery_Envelope_NOT_A_SELECTED_CELL',cell,'silver',False,'22 x 23 x 5 placeholder. Capacity and chemistry not selected.')
# cradle: removable, non-snap rails; side fasteners intentionally not hidden.
cradle=rr(47,56,6,-5,3,-2.5,2)
cradle=cradle.fuse(rr(63,39,4,-5,3,-10.5,11))
for x in [-7.8,45]:cradle=cradle.cut(rr(4,35.5,1,-6,5,x,12.75))
for x in [-2.5,42.4]:cradle=cradle.fuse(box(x,13,-2,2.1,35,7))
add('05_Cradle',cradle,'navy',True,'35 mm strap slots, 0.4 mm side clearance. Rear plate blocks cartridge retaining screw. Retention/slide-out security requires fit testing.')
pad=rr(44,52,5,-7,2,-1,4)
add('06_SoftCradlePad_TPU',pad,'teal',True,'Soft TPU fit-study pad only; validate skin contact and cleanability separately.')
# Soft button flange + actuator: one piece.
button=cyl(21,22,17.2,6.5,1).fuse(cyl(21,22,18.2,4.95,2.0)).fuse(cyl(21,22,15.8,1.2,1.5))
add('07_Button_TPU',button,'teal',True,'Soft actuator with retention flange; tune switch clearance after selected switch measurement.')
light=rr(8,2.2,1,17.8,2.6,17,33.9)
add('08_LightWindow_Clear',light,'light',True,'Clear light-pipe fit model. Optical material/process to select.')
# Flat replaceable seam gasket, not claimed pressure sealed.
gasket=rr(40,58,7,13.8,.5,1,1).cut(rr(37,55,5.5,13.7,.8,2.5,2.5))
add('09_SeamGasket_TPU',gasket,'teal',True,'0.5 mm gasket trial. Compression, screw torque and seal path not validated.')
# Board physical outline.
pcb=rr(34,48,3,11.8,1,4,6)
for x,y in [(7,10),(35,10),(7,50),(35,50)]:pcb=pcb.cut(cyl(x,y,11,1.1,3))
add('PCB_Substrate',pcb,'pcb',False,'34 x 48 x 1 mm placement prototype. Electrical layout is not routed.')
parts=[
 ('U1_ESP32C3',12,38,12.8,13.2,16.6,2.4,'module'),
 ('U2_MCP3208',25,21,12.8,6.5,10,1.75,'chip'),
 ('U3_LSM6DSO32',8,29,12.8,2.5,3,0.9,'chip'),
 ('U4_MCP6001',11,15,12.8,3,3,1.1,'chip'),
 ('U5_TLV75533',8,22,12.8,2.9,2.8,1.1,'chip'),
 ('U6_MAX17048',28,14,12.8,3,3,0.8,'chip'),
 ('J1_SENSOR',13,6.5,12.8,16,4,3,'connector'),
 ('J2_BATTERY',27,34,12.8,7,4,2,'connector'),
 ('SW1_BUTTON',17,18,12.8,8,8,2.6,'chip'),
 ('D1_STATUS',18.5,32.5,12.8,5,5,1.5,'light'),
 ]
for name,x,y,z,w,h,d,mat in parts:add(name,box(x,y,z,w,h,d),mat,False,'Simplified component envelope for placement visualization; not supplier MCAD.')
# small passives around analog region, with shared placement manifest for PCB scene.
for i,(x,y) in enumerate([(7,15),(7,18),(7,35),(7,38),(10,10),(10,12),(30,11),(33,15),(33,18),(33,22),(33,26),(33,30),(11,26),(13,26),(15,29),(19,29),(27,31),(30,31)]):
 add(f'Passive_{i+1:02}',box(x,y,12.8,1.6,.8,.6),'ceramic' if i%2 else 'chip',False)
# Reference connector sleeve below pod.
add('Cable_StrainRelief',rr(14,16,2,8.9,4.2,14,-11),'teal',False)
# Store measured assemblies before export.
doc.recompute();doc.saveAs(str(CAD/'NIVA-RevB-assembly.FCStd'))
Part.export(doc.Objects,str(CAD/'NIVA-RevB-assembly.step'))
(OUT/'mechanical'/'geometry-validation.json').write_text(json.dumps(report,indent=2))
(ROOT/'work'/'niva-scene-manifest.json').write_text(json.dumps(manifest,indent=2))
(ROOT/'work'/'niva-component-envelopes.json').write_text(json.dumps(parts,indent=2))
# interference checks for rigid primary solids (intentional gaskets/soft interfaces excluded)
objs={o.Name:o for o in doc.Objects}
pairs=[('01_RearHousing','02_FrontCover')]
checks=[]
primary=[o for o in doc.Objects if any(o.Label.startswith(p) for p in ['01 ','02 ','03 ','04 ','05 ','PCB '])]
for i,a in enumerate(primary):
 for b in primary[i+1:]:
  common=a.Shape.common(b.Shape)
  if common.Volume>.02:checks.append({'a':a.Label,'b':b.Label,'intersection_mm3':round(common.Volume,3)})
(CAD/'interference-report.json').write_text(json.dumps(checks,indent=2))
print('CAD COMPLETE',len(report),'parts; interference findings',checks,flush=True)
