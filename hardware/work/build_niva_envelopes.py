"""Simplified envelope STEP models for parts that are not yet selected (FreeCAD 1.x python).

These are NOT supplier models: they reserve space and mark contact positions only. Replace with the
supplier STEP once a part number is chosen.
    NIVA_SpringPin_1x03_ENVELOPE.step - three single SMD spring-loaded contacts, 6.0 mm pitch,
        4.5 mm free height (flange 2.0 x 0.4, barrel 1.5, plunger 1.0 with domed tip); working height 3.8 mm.
Run: PYTHONPATH=/opt/freecad/lib /opt/freecad/bin/python build_niva_envelopes.py
"""
from pathlib import Path
import FreeCAD as App, Part
V = App.Vector
OUT = Path(__file__).resolve().parents[1] / 'outputs/NIVA-3D-engineering-prototype/electronics/3dmodels'

def spring_pin(y):
    flange = Part.makeCylinder(1.0, 0.4, V(0, y, 0))
    barrel = Part.makeCylinder(0.75, 2.6, V(0, y, 0.4))
    plunger = Part.makeCylinder(0.5, 1.0, V(0, y, 3.0))
    tip = Part.makeSphere(0.5, V(0, y, 4.0))
    return flange.fuse(barrel).fuse(plunger).fuse(tip).removeSplitter()

pins = spring_pin(-6.0).fuse(spring_pin(0.0)).fuse(spring_pin(6.0))
assert abs(pins.BoundBox.ZMax - 4.5) < 1e-6 and pins.isValid()
pins.exportStep(str(OUT / 'NIVA_SpringPin_1x03_ENVELOPE.step'))
print('wrote NIVA_SpringPin_1x03_ENVELOPE.step', [round(v, 2) for v in (pins.BoundBox.XLength, pins.BoundBox.YLength, pins.BoundBox.ZLength)])
