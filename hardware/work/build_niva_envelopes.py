"""Envelope STEP models for the cartridge spring contacts (FreeCAD 1.x python).

These are NOT supplier models. Since Rev C.2 both boards use Mill-Max 0900-0-15-20-76-14-11-0 SMT spring-loaded
pins, drawn from the datasheet key dimensions (mill-max.com, read 9 Nov 2026): flange 1.829 x 0.406, body 1.499
to 2.083, plunger 1.067 to 3.480 (initial height), max stroke 0.991, rated travel 0.508 -> working height 2.972.
The domed tip radius is not on the datasheet; a full hemisphere is drawn. Replace with Mill-Max's STEP when fetched.
    NIVA_SpringContact_1x04_ENVELOPE.step - Rev C.1 pod J2, four pins along x at 2.54 mm pitch.
    NIVA_SpringContact_2x2pairs_ENVELOPE.step - Rev C.2 pod J2, a P+ pair and a P- pair 8.5 mm apart.
    NIVA_SpringPin_1x03_ENVELOPE.step     - dock J2, three pins along y at 6.0 mm pitch.
Run: freecadcmd build_niva_envelopes.py
"""
from pathlib import Path
import FreeCAD as App, Part
V = App.Vector
OUT = Path(__file__).resolve().parents[1] / 'outputs/NIVA-3D-engineering-prototype/electronics/3dmodels'
FLANGE_D, FLANGE_L, BODY_D, BODY_L, PLUNGER_D, FREE_H = 1.829, 0.406, 1.499, 2.083, 1.067, 3.480

def spring_pin(x, y):
    r = PLUNGER_D / 2
    flange = Part.makeCylinder(FLANGE_D / 2, FLANGE_L, V(x, y, 0))
    body = Part.makeCylinder(BODY_D / 2, BODY_L - FLANGE_L, V(x, y, FLANGE_L))
    plunger = Part.makeCylinder(r, FREE_H - r - BODY_L, V(x, y, BODY_L))
    tip = Part.makeSphere(r, V(x, y, FREE_H - r))
    return flange.fuse(body).fuse(plunger).fuse(tip).removeSplitter()

# Model y is up, footprint y is down: pin (x, y) here sits on pad (x, -y) of NIVA:SpringContact_2x2pairs_MillMax0900_SMD.
for name, xy in (('NIVA_SpringContact_1x04_ENVELOPE.step', [((i - 1.5) * 2.54, 0) for i in range(4)]),
                 ('NIVA_SpringContact_2x2pairs_ENVELOPE.step', [(1.675, 4.25), (-0.865, 4.25), (0.865, -4.25), (-1.675, -4.25)]),
                 ('NIVA_SpringPin_1x03_ENVELOPE.step', [(0, (i - 1) * 6.0) for i in range(3)])):
    pins = Part.makeCompound([spring_pin(x, y) for x, y in xy])
    assert abs(pins.BoundBox.ZMax - FREE_H) < 1e-6 and pins.isValid() and len(pins.Solids) == len(xy)
    pins.exportStep(str(OUT / name))
    print('wrote', name, [round(v, 3) for v in (pins.BoundBox.XLength, pins.BoundBox.YLength, pins.BoundBox.ZLength)])
