"""NIVA charging dock (Rev C.1) enclosure generator (FreeCAD 1.1 python).

  PYTHONPATH=<FreeCAD lib> python build_niva_dock_cad.py

The dock charges the bare cartridge only (the pod never charges on the body). The cartridge sits rear face
down in a keyed well: its retention tab slides under a ledge in the far wall, the near end snaps under a
printed cantilever latch, and three spring pins on the dock PCB reach the cartridge's gold pads through the
well floor and the cup's contact windows. Dock frame = pod frame shifted by L.DOCK['dxy'] (no mirroring).

Parts: 10_DockBase (PETG), 11_DockTop (PETG), 12_DockLightPipe_Clear. The PCBA comes from the KiCad STEP
(electronics/dock/exports/pcb/NIVA-dock-PCBA.step); J2 spring pins in that STEP are a NIVA ENVELOPE.
"""
from pathlib import Path
import json, sys, itertools
import FreeCAD as A, Part, MeshPart
sys.path.insert(0, str(Path(__file__).parent))
import niva_layout as L
from niva_cad_lib import *

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs/NIVA-3D-engineering-prototype'
CAD = OUT / 'mechanical'; PRINT = CAD / 'STL-print-parts'; STEPS = CAD / 'STEP-parts'; MESH = ROOT / 'work/niva-meshes'
D = L.DOCK; DX, DY = D['dxy']
PCB_TOP = D['pcb_z'] + D['pcb_t']                 # 8.0: base/top split plane
FLOOR_Z, TOP = D['floor_z'], D['top_z']           # well floor top 10.8, dock top face 21.2
FLOOR_B = FLOOR_Z - D['floor_t']                  # well floor underside 9.6
C, T, c = L.CART, L.CART_TAB, D['well_clear']
WELL = (C['cup_x0'] + DX - c, C['cup_y0'] + DY - c, C['cup_w'] + 2 * c, C['cup_l'] + 2 * c)   # x0, y0, w, l
SLOT = (T['x0'] + DX - c, WELL[1] + WELL[3] - 3.0, T['w'] + 2 * c, 7.0, T['t'] + 0.2)          # tab slot x0, y0, w, l, h (clears the well corner radius)
CART_TOP = FLOOR_Z + C['lid_z'] + C['lid_t']      # 20.0
HOOK_Z = CART_TOP + 0.1                            # latch hook underside
LATCH_X = C['cup_x0'] + DX + C['cup_w'] / 2       # latch centred on the cartridge
USB = dict(y=50.0, z=D['pcb_z'] + 3.22, w=13.0, h=7.0)   # J1 mating face at x 60.9 (from the KiCad STEP)
HOLES = [v[:2] for k, v in L.DOCK_PLACE.items() if k.startswith('H')]      # M2 screws: base -> PCB -> top boss
ARM_T, HOOK = 1.0, 1.2                            # latch arm thickness, hook reach into the well
FEET = [(15, 15), (49, 15), (15, 47), (49, 47)]
NOTCH_Y = WELL[1] + WELL[3] / 2

def dock_base():
    s = rr(D['w'], D['d'], D['r'], 0, PCB_TOP).cut(rr(D['w'] - 4, D['d'] - 4, 2.5, D['base_t'], PCB_TOP, 2, 2))   # r2.5 clears the square board corners
    for x, y in HOLES:
        s = s.fuse(cyl(x, y, D['base_t'] - 0.1, 2.6, D['pcb_z'] - 0.06 - D['base_t'] + 0.1))   # seat for the 0.05 mm mask/copper
        s = s.cut(cyl(x, y, -0.1, 1.2, PCB_TOP)).cut(cyl(x, y, -0.1, 2.1, 1.9))           # M2 clearance + head counterbore
    s = s.cut(box(D['w'] - 2.5, USB['y'] - USB['w'] / 2, USB['z'] - USB['h'] / 2, 3, USB['w'], PCB_TOP))   # plug overmould relief
    for x, y in FEET: s = s.cut(cyl(x, y, -0.1, 4.2, 0.9))                                  # 8 mm bumper recesses
    for txt, size, y in (('NIVA DOCK REV C.1', 3.6, 36), ('5 V USB-C - CARTRIDGE ONLY', 2.6, 29), ('NOT A MEDICAL DEVICE', 2.2, 24)):
        t = text_solid(txt, size, D['w'] / 2, y, -0.1, 0.5)
        if t: t.mirror(V(D['w'] / 2, 0, 0), V(1, 0, 0)); s = s.cut(t)                     # reads correctly from below
    return clean(s)

def dock_top():
    s = rr(D['w'], D['d'], D['r'], PCB_TOP, TOP - PCB_TOP).cut(rr(D['w'] - 4, D['d'] - 4, D['r'] - 2, PCB_TOP - 0.1, TOP - 1.6 - PCB_TOP + 0.1, 2, 2))
    wx, wy, ww, wl = WELL
    s = s.fuse(rr(ww + 3, wl + 3, 3.5, FLOOR_B, TOP - FLOOR_B, wx - 1.5, wy - 1.5))            # well walls + floor
    s = s.fuse(box(SLOT[0] - 1.5, wy + wl - 2, FLOOR_B, SLOT[2] + 3, SLOT[3] + 3.5, TOP - FLOOR_B))   # far-wall ledge block
    s = s.fuse(box(LATCH_X - 6.8, wy - 5.2, FLOOR_B, 13.6, 5.2, TOP - FLOOR_B))               # latch housing
    for x in (wx, wx + ww): s = s.fuse(cyl(x, NOTCH_Y, 10.5, 8.5, TOP - 10.5))              # finger-notch walls (clear U2/U1)
    for x, y in HOLES: s = s.fuse(cyl(x, y, PCB_TOP, 2.6, TOP - 1.6 - PCB_TOP + 0.1)).cut(cyl(x, y, PCB_TOP - 0.1, 0.85, 7.1))
    lx, ly = L.DOCK_LED
    s = s.fuse(cyl(lx, ly, PCB_TOP + 1.45, 2.0, TOP - PCB_TOP - 1.45))                      # light-pipe tube (LED top 9.1)
    s = s.cut(cyl(lx, ly, PCB_TOP + 1.35, 1.25, TOP)).cut(cyl(lx, ly, TOP - 0.6, 1.8, 1))
    # cuts
    s = s.cut(rr(ww, wl, 2 + c, FLOOR_Z, TOP, wx, wy))                                        # cartridge well
    s = s.cut(box(SLOT[0], SLOT[1], FLOOR_Z, SLOT[2], SLOT[3], SLOT[4]))                     # tab slot under the ledge
    for x in (wx, wx + ww): s = s.cut(cyl(x, NOTCH_Y, 14.0, 7.0, TOP))                       # finger notches
    for x, y in D['pads']: s = s.cut(cyl(x, y, FLOOR_B - 0.1, 1.0, 2))                       # spring-pin holes
    s = s.cut(box(D['w'] - 2.5, USB['y'] - USB['w'] / 2, USB['z'] - USB['h'] / 2, 3, USB['w'], USB['h']))
    # cantilever latch: arm = the well wall between two slots, freed from the housing by a relief gap behind it
    for x in (LATCH_X - 4.8, LATCH_X + 4.0): s = s.cut(box(x, wy - 3.3, FLOOR_Z, 0.8, 4.0, TOP))
    s = s.cut(box(LATCH_X - 4.8, wy - ARM_T - 2.0, FLOOR_Z, 9.6, 2.0, TOP))
    s = s.fuse(prism_yz([(wy, HOOK_Z), (wy + HOOK, HOOK_Z), (wy, TOP)], LATCH_X - 4.0, 8.0))  # hook, ~45 deg lead-in
    lx, ly = L.DOCK_LED
    for txt, size, x, y in (('NIVA', 4.0, 10.5, 50), ('TAB END IN FIRST', 2.2, LATCH_X, 57.0), ('CHG', 2.0, lx, ly + 4.2)):
        t = text_solid(txt, size, x, y, TOP - 0.4, 0.5)
        if t: s = s.cut(t)
    return clean(s)

def light_pipe():
    lx, ly = L.DOCK_LED
    return clean(cyl(lx, ly, PCB_TOP + 1.35, 1.15, TOP - PCB_TOP - 1.35).fuse(cyl(lx, ly, TOP - 0.6, 1.7, 0.6)))

def cartridge_in_dock():
    parts = {'Cup': cartridge_cup(), 'Lid': cartridge_lid(), 'Cell_LP502030_MAXSIZE': cell(), 'StripPCB': strip_pcb(),
             'LidPlates': contact_plates()}
    for s in parts.values(): s.translate(V(DX, DY, FLOOR_Z))
    return parts

if __name__ == '__main__':
    doc = A.newDocument('NIVA_Dock')
    report = {'parts': [], 'interference': {}, 'gaps': {}, 'notes': []}
    PRINTS = {'10_DockBase': (dock_base(), 'PETG, navy', 'bottom on bed; no supports', 'asis'),
              '11_DockTop': (dock_top(), 'PETG, pale grey-blue', 'top face on bed (flipped); well floor is a 29 mm bridge - enable bridging, no supports', 'flip'),
              '12_DockLightPipe_Clear': (light_pipe(), 'clear SLA resin or clear PETG', 'flange on bed (flipped)', 'flip')}
    objs = {}
    for name, (shape, mat, note, orient) in PRINTS.items():
        assert shape.isValid() and len(shape.Solids) == 1, f'{name}: valid={shape.isValid()} solids={len(shape.Solids)}'
        o = doc.addObject('Part::Feature', name); o.Shape = shape; o.Label = name; objs[name] = o
        s = shape.copy()
        if orient == 'flip': s.rotate(V(0, 0, 0), V(1, 0, 0), 180)
        bb = s.BoundBox; s.translate(V(-bb.XMin, -bb.YMin, -bb.ZMin))
        m = MeshPart.meshFromShape(Shape=s, LinearDeflection=0.02, AngularDeflection=0.2, Relative=False)
        m.write(str(PRINT / (name + '.stl'))); Part.export([o], str(STEPS / (name + '.step')))
        bb = s.BoundBox
        report['parts'].append(dict(part=name, material=mat, print_orientation=note, valid=shape.isValid(), solids=len(shape.Solids),
                                    volume_mm3=round(shape.Volume, 1), print_bbox_mm=[round(bb.XLength, 2), round(bb.YLength, 2), round(bb.ZLength, 2)],
                                    closed_mesh=m.isSolid(), mesh_non_manifolds=m.hasNonManifolds()))
    step = OUT / 'electronics/dock/exports/pcb/NIVA-dock-PCBA.step'
    pcba = Part.Shape(); pcba.read(str(step)); pcba.translate(V(0, 0, D['pcb_z']))
    sol = sorted(pcba.Solids, key=lambda x: -x.Volume)
    pins = [x for x in sol if any(abs(x.BoundBox.Center.x - px) < 0.3 and abs(x.BoundBox.Center.y - py) < 0.3 for px, py in D['pads'])]
    rest = [x for x in sol[1:] if x not in pins]
    for name, shp in (('DockPCB_Substrate', Part.makeCompound(sol[:1])), ('DockPCB_Components_KiCad', Part.makeCompound(rest)),
                      ('DockSpringPins_ENVELOPE', Part.makeCompound(pins))):
        o = doc.addObject('Part::Feature', name); o.Shape = shp; o.Label = name; objs[name] = o
    for name, shp in cartridge_in_dock().items():
        o = doc.addObject('Part::Feature', 'Cartridge_' + name); o.Shape = shp; o.Label = 'Cartridge_' + name; objs[o.Label] = o
    doc.recompute(); doc.saveAs(str(CAD / 'NIVA-dock-assembly.FCStd'))
    Part.export(list(objs.values()), str(CAD / 'NIVA-dock-assembly.step'))
    EXPECTED = {frozenset({'DockSpringPins_ENVELOPE', 'Cartridge_StripPCB'}): 'spring pins drawn at free height: design compression on the gold pads',
                frozenset({'DockSpringPins_ENVELOPE', 'DockPCB_Components_KiCad'}): 'pin bases on their own solder pads (KiCad pad copper drawn 0.04 mm into the envelope)'}
    for (a, oa), (b, ob) in itertools.combinations(objs.items(), 2):
        if not oa.Shape.BoundBox.intersect(ob.Shape.BoundBox): continue
        v = oa.Shape.common(ob.Shape).Volume
        if v > 1e-3: report['interference'][f'{a} x {b}'] = dict(volume_mm3=round(v, 3), expected=EXPECTED.get(frozenset({a, b}), ''))
    for a, b in [('DockPCB_Components_KiCad', '11_DockTop'), ('DockPCB_Components_KiCad', '10_DockBase'), ('DockPCB_Substrate', '10_DockBase'),
                 ('Cartridge_Cup', '11_DockTop'), ('Cartridge_Lid', '11_DockTop'), ('DockSpringPins_ENVELOPE', '11_DockTop'),
                 ('12_DockLightPipe_Clear', 'DockPCB_Components_KiCad'), ('12_DockLightPipe_Clear', '11_DockTop')]:
        report['gaps'][f'{a} to {b}'] = round(objs[a].Shape.distToShape(objs[b].Shape)[0], 3)
    pin_top = max(p.BoundBox.ZMax for p in pins); pad_z = FLOOR_Z + C['floor']
    report['notes'] += [f'spring pin free top z {pin_top:.2f}; cartridge pad face z {pad_z:.2f}; compression {pin_top - pad_z:.2f} mm seated, '
                        f'{pin_top - pad_z - 0.1:.2f} mm when lifted onto the latch hook (0.1 mm free play)',
                        f'dock {D["w"]} x {D["d"]} x {TOP:.1f} mm; cartridge top {CART_TOP:.1f} mm, {TOP - CART_TOP:.1f} mm below the top face',
                        f'latch arm 8 x {ARM_T} x {TOP - FLOOR_Z:.1f} mm PETG; hook reach {HOOK} mm, overlap on the lid edge '
                        f'{HOOK - c - 0.2:.1f} mm; peak bending strain at full deflection ~{150 * ARM_T * HOOK / (TOP - FLOOR_Z) ** 2:.1f} % '
                        '(cantilever estimate 1.5*t*y/L^2 - verify on a print)']
    (CAD / 'dock-geometry-validation.json').write_text(json.dumps(report['parts'], indent=2))
    (CAD / 'dock-interference-report.json').write_text(json.dumps({k: report[k] for k in ('interference', 'gaps', 'notes')}, indent=2))
    manifest = []
    for o in objs.values():
        m = MeshPart.meshFromShape(Shape=o.Shape, LinearDeflection=0.03, AngularDeflection=0.25, Relative=False)
        m.write(str(MESH / (o.Label + '.stl'))); manifest.append(dict(name=o.Label, stl=f'work/niva-meshes/{o.Label}.stl'))
    (ROOT / 'work/niva-dock-manifest.json').write_text(json.dumps(manifest, indent=2))
    print('dock CAD complete'); print(json.dumps(report, indent=1))
