"""Slide the assembled pod (housing, cover, cartridge, screw head) along y on the cradle and report overlap volume.
dy > 0: pod above its seated position (mounting slides it from +65 down to 0)."""
import sys
sys.path.insert(0, '/home/shubh/_Active_Projects/niva-pcbway/hardware/work')
import FreeCAD as A, Part, json
import niva_layout as L
V = A.Vector
M = '/home/shubh/_Active_Projects/niva-pcbway/hardware/outputs/NIVA-3D-engineering-prototype/mechanical/STEP-parts/'
def rd(n):
    s = Part.Shape(); s.read(M + n + '.step'); return s
tx, ty = L.CART_TAB['screw']
head = Part.makeCylinder(2.0, 1.6, V(tx, ty, -1.6))                     # M2 pan head, dk 4.0 x k 1.6, on the tab's rear face
pod = Part.makeCompound([rd('01_RearHousing_R'), rd('02_FrontCover_R'), rd('03_BatteryCartridgeCup'), rd('04_BatteryCartridgeLid'), head])
cr = rd('05_Cradle_R')
hook = Part.makeBox(9.0, 6.0, 3.6, V(16.5, 59.5, -1.85))                 # the flexing latch hook and ramp
cr_rigid = cr.cut(hook)
def ov(shape, dy):
    p = pod.copy(); p.translate(V(0, dy, 0)); return round(sum(p.common(shape).Volume for _ in [0]), 3)
res = {'rigid_cradle_vs_pod_while_sliding_down': {dy: ov(cr_rigid, dy) for dy in (65, 50, 40, 30, 20, 10, 5, 2, 1, 0.5, 0.25, 0.1, 0)},
       'pushed_further_down (must overlap: groove-end stop)': {dy: ov(cr_rigid, dy) for dy in (-0.25, -0.5, -1.0)},
       'pulled back up with hook (must overlap: latch retains)': {dy: ov(cr, dy) for dy in (0.25, 0.5, 1.0)},
       'hook vs pod while passing (arm must deflect)': {dy: ov(cr.common(hook), dy) for dy in (60, 30, 5)}}
print(json.dumps(res, indent=1))
