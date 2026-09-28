"""NIVA pod Rev C enclosure generator (FreeCAD 1.1 python).

  PYTHONPATH=<FreeCAD lib> python build_niva_cad_revC.py

Continues build_niva_cad.py (Rev B). Board outline, mounting, button, emitter, connector and
spring-contact positions are read from niva_layout.py, the same module that places the KiCad PCB.
If the KiCad STEP export (electronics/exports/NIVA-pod-components.step) exists, the real component
bodies are imported and included in the interference audit.

Rev B -> Rev C mechanical changes (details in the package README):
  M1 gasket: continuous flat ring on the rim, 0.5 mm free / 0.35 mm installed; boss hard stops
  M2 front-cover screw bosses under every head; M2x10 pan-head thread-forming screws
  M3 PCB: two M2 screws into bosses outside the bay + side/bottom ledges + front clamp ribs
  M4 cable aperture at connector height, split on the parting line; keyed tail boot (L/R)
  M5 light pipe reaches 0.3 mm above the emitters
  M6 cartridge contacts: board spring contacts -> flush plates in the bonded cartridge lid
  M7 cradle: undercut rails, bottom stop, printable cantilever latch, L/R key post + slot
  M8 bay ceiling with contact/service windows keeps fingers off the board when the bay is empty
"""
from pathlib import Path
import json, math, sys, itertools
import FreeCAD as A, Part, Mesh, MeshPart
sys.path.insert(0, str(Path(__file__).parent))
import niva_layout as L
from niva_cad_lib import *

V = A.Vector
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs/NIVA-3D-engineering-prototype'
CAD = OUT / 'mechanical'; PRINT = CAD / 'STL-print-parts'; STEPS = CAD / 'STEP-parts'; MESH = ROOT / 'work/niva-meshes'
for p in (CAD, PRINT, STEPS, MESH): p.mkdir(parents=True, exist_ok=True)

W, H = L.POD_W, L.POD_H
RIM_Z, STOP_Z, TOP_Z = 14.0, 14.35, 20.0         # rear rim, boss hard stop / front-cover seat, front face
FACE_IN = 18.2                                     # inner surface of the 1.8 mm front face
PCB_Z = L.PCB_Z0; PCB_TOP = PCB_Z + L.BOARD['t']
APER = dict(x0=12.2, x1=29.8, z0=12.2, z1=17.6)    # tail boot aperture, split on the parting plane
KEY_X = {'R': 3.5, 'L': 38.5}                      # rear-face key slot / cradle key post
BOOT_KEY = {'R': (12.2, 15.2), 'L': (26.8, 29.8)}  # aperture key notch (front half), x range

def case_bosses(z0, z1, r=L.CASE_BOSS_R):
    return [cyl(x, y, z0, r, z1 - z0) for x, y in L.CASE_SCREWS]

# ------------------------------------------------------------------ parts
def rear_housing(side):
    outer = rr(W, H, 8, 0, RIM_Z)
    s = outer.cut(rr(38.4, 56.4, 6.2, 1.8, 12.4, 1.8, 1.8))
    # battery bay: frame + 0.8 mm ceiling; the cartridge pocket is open to the rear face only
    C, bc = L.CART, L.BAY_CLEAR
    px0, py0, pw, pl = C['cup_x0'] - bc, C['cup_y0'] - bc, C['cup_w'] + 2 * bc, C['cup_l'] + 2 * bc
    s = s.fuse(rr(pw + 2.2, pl + 2.2, 3, 0, 10.8, px0 - 1.1, py0 - 1.1))          # bay frame, 1.1 mm wall
    s = s.cut(rr(pw, pl, 2, -0.5, 10.5, px0, py0))                               # cartridge pocket
    jx, jy = L.SPRING_CONTACTS_XY; s = s.cut(box(jx - 6.2, jy - 2.2, 9.9, 12.4, 4.4, 1.0))
    sx, sy = L.SERVICE_PADS_XY;    s = s.cut(box(sx - 4.5, sy - 3.0, 9.9, 9.0, 6.0, 1.0))
    # cartridge retention: M2 screw through the cartridge tab into this post (hidden by the cradle)
    T = L.CART_TAB; tx, ty = T['screw']
    s = s.fuse(box(T['x0'], py0 + pl, 0, T['w'], T['y0'] + T['l'] + 0.3 - (py0 + pl), 9))            # retention post
    s = s.cut(rr(T['w'] + 0.8, T['l'] + 0.8, 1, -0.1, T['t'] + 0.1, T['x0'] - 0.4, T['y0'] - 0.4))   # tab recess
    s = s.cut(cyl(tx, ty, -0.2, 0.8, 7.2))                        # M2 pilot 1.6 mm
    # enclosure screw bosses (wall-merged) with a reduced hard-stop ring above the rim
    for b in case_bosses(1.8, RIM_Z): s = s.fuse(b.common(outer))
    for x, y in L.CASE_SCREWS: s = s.fuse(cyl(x, y, RIM_Z, 1.9, STOP_Z - RIM_Z))
    for x, y in L.CASE_SCREWS: s = s.cut(cyl(x, y, 4.0, 0.8, 11))
    # PCB: two M2 bosses outside the bay, chamfered side ledges, bottom ledges
    for ref, x, y in L.MOUNT_HOLES:
        s = s.fuse(cyl(x, y, 1.8, 2.4, PCB_Z - 1.8)); s = s.cut(cyl(x, y, 5.0, 0.8, PCB_Z - 4.9))
    for x0, sgn in ((1.8, 1), (W - 1.8, -1)):
        prof = [(x0, 8.0), (x0, PCB_Z), (x0 + sgn * 2.8, PCB_Z), (x0 + sgn * 2.8, PCB_Z - 1.0)]
        s = s.fuse(prism_xz(prof if sgn > 0 else prof[::-1], 14, 26))   # 45-degree gusset: no support needed
    for x in (7.0, 30.0): s = s.fuse(box(x, 1.8, 10.8, 5.0, 4.8, PCB_Z - 10.8))
    # tail boot aperture (rear half)
    s = s.cut(box(APER['x0'], -1, APER['z0'], APER['x1'] - APER['x0'], 3.6, RIM_Z - APER['z0'] + 0.5))
    # cradle rails: chamfered grooves in both side walls, closed at y = 11.8 (bottom stop)
    s = s.cut(prism_xz([(-0.1, 1.2), (0.8, 1.2), (0.8, 2.0), (-0.1, 2.9)], 11.8, 50))
    s = s.cut(prism_xz([(W + 0.1, 1.2), (W - 0.8, 1.2), (W - 0.8, 2.0), (W + 0.1, 2.9)][::-1], 11.8, 50))
    # L/R key slot in the rear face, open at the top end
    s = s.cut(box(KEY_X[side] - 1.6, 46, -0.1, 3.2, 16, 1.1))
    return clean(s)

def front_cover(side):
    outer = rr(W, H, 8, STOP_Z, TOP_Z - STOP_Z)
    s = outer.cut(rr(38.4, 56.4, 6.2, STOP_Z - 0.1, FACE_IN - STOP_Z + 0.1, 1.8, 1.8))
    # locating lip (enters the rear housing with 0.2 mm side clearance), joined to the wall by a
    # 0.4 mm flange above the parting plane so every lip segment is part of the cover solid
    lip = rr(38.0, 56.0, 6.0, 13.2, STOP_Z - 13.2 + 0.4, 2.0, 2.0).fuse(
          rr(38.6, 56.6, 6.3, STOP_Z, 0.4, 1.7, 1.7)).cut(rr(36.4, 54.4, 5.2, 13.1, 1.8, 2.8, 2.8))
    for x, y in L.CASE_SCREWS: lip = lip.cut(cyl(x, y, 13.0, 2.5, 2))
    lip = lip.cut(box(APER['x0'] - 0.3, -1, 13.0, APER['x1'] - APER['x0'] + 0.6, 5, 2))
    s = s.fuse(lip)
    for b in case_bosses(STOP_Z, FACE_IN + 0.1): s = s.fuse(b.common(outer))
    for x, y in L.CASE_SCREWS:
        s = s.cut(cyl(x, y, STOP_Z - 0.1, 1.15, 6.0))            # M2 clearance 2.3 mm
        s = s.cut(cyl(x, y, 18.3, 2.25, 2.0))                     # pan head (dk 4.0) counterbore 4.5 mm
    bx, by = L.BUTTON_XY; s = s.cut(cyl(bx, by, 17.9, 5.15, 2.5))
    lw = L.LIGHT_WINDOW; s = s.cut(rr(lw['w'], lw['h'], 1.1, 17.9, 2.5, lw['x0'], lw['y0']))
    for x in (8.0, 31.8): s = s.fuse(box(x, 6.3, PCB_TOP, 2.2, 1.0, FACE_IN - PCB_TOP + 0.1))   # PCB clamp ribs
    s = s.cut(box(APER['x0'], -1, STOP_Z - 0.1, APER['x1'] - APER['x0'], 3.6, APER['z1'] - STOP_Z + 0.1))
    k0, k1 = BOOT_KEY[side]; s = s.cut(box(k0, -1, APER['z1'] - 0.1, k1 - k0, 3.6, 0.6))
    for t in (text_solid('NIVA', 4.2, 21, 53.2, TOP_Z - 0.4, 0.5), text_solid(side, 6.0, 21, 10.5, TOP_Z - 0.5, 0.6)):
        if t: s = s.cut(t)
    return clean(s)

def cradle(side):
    s = rr(48, 58, 6, -3.4, 3.0, -3, 1).fuse(rr(63, 39, 4, -3.4, 3.0, -10.5, 11))
    for x in (-7.8, 45.8): s = s.cut(rr(4, 35.5, 1, -3.6, 3.4, x, 12.75))          # 35 mm strap slots
    s = s.fuse(box(-3, 12, -0.4, 2.8, 46, 3.6)).fuse(box(W + 0.2, 12, -0.4, 2.8, 46, 3.6))
    s = s.fuse(prism_xz([(-0.2, 1.4), (0.6, 1.4), (0.6, 1.8), (-0.2, 2.6)], 12.0, 46))
    s = s.fuse(prism_xz([(W + 0.2, 1.4), (W + 0.2, 2.6), (W - 0.6, 1.8), (W - 0.6, 1.4)], 12.0, 46))
    s = s.fuse(box(KEY_X[side] - 1.3, 48, -0.4, 2.6, 4, 1.2))                         # L/R key post
    s = s.cut(cyl(*L.CART_TAB['screw'], -2.0, 2.4, 1.7))                              # cartridge screw head relief
    # cantilever latch: slots either side, arm thinned from the top (prints flat), hook + ramp + tab
    for x in (16.2, 25.0): s = s.cut(box(x, 45, -3.6, 0.8, 16, 3.4))
    s = s.cut(box(17, 46.5, -1.8, 8, 14, 1.5))
    s = s.fuse(box(17, 59, -3.4, 8, 5.0, 1.6))
    s = s.fuse(prism_yz([(60.3, -1.8), (60.3, 1.6), (61.0, 1.6), (62.6, -1.8)], 17, 8))
    for t in (text_solid(side, 7.0, 21, 22, -0.9, 0.6),):
        if t: s = s.cut(t)
    for i in range(1 if side == 'R' else 2):                                          # tactile dots
        s = s.fuse(Part.makeSphere(0.8, V(-9.1, 44 + i * 2.6, -0.4)).common(box(-11, 40, -0.4, 4, 10, 1)))
    return clean(s)

def cradle_pad():
    return clean(rr(50, 60, 6, -5.4, 2.0, -4, 0).cut(box(16, 44, -5.6, 10, 21, 2.4)))

def button():
    bx, by = L.BUTTON_XY; sw_top = PCB_TOP + L.HEIGHT['SW1']
    return clean(cyl(bx, by, 17.2, 6.5, 1.0).fuse(cyl(bx, by, 18.2, 4.95, 2.0)).fuse(cyl(bx, by, sw_top + 0.2, 1.2, 17.2 - sw_top - 0.2 + 0.01)))

def light_pipe():
    lw = L.LIGHT_WINDOW; em_top = PCB_TOP + L.HEIGHT['D4']
    body = rr(lw['w'] - 0.4, lw['h'] - 0.4, 0.9, em_top + 0.3, TOP_Z + 0.2 - em_top - 0.3, lw['x0'] + 0.2, lw['y0'] + 0.2)
    return clean(body.fuse(rr(lw['w'] + 1.6, lw['h'] + 1.4, 1.2, 17.4, 0.8, lw['x0'] - 0.8, lw['y0'] - 0.7)))

def gasket(thick):
    s = rr(41.4, 59.4, 7.7, RIM_Z, thick, 0.3, 0.3).cut(rr(39.0, 57.0, 6.5, RIM_Z - 0.1, thick + 0.2, 1.5, 1.5))
    return clean(s.cut(box(APER['x0'] - 0.2, -1, RIM_Z - 0.1, APER['x1'] - APER['x0'] + 0.4, 3.5, thick + 0.2)))

def pcb():
    b = L.BOARD; s = box(b['x0'], b['y0'], PCB_Z, b['w'], b['h'], b['t'])
    for x, y in L.CASE_SCREWS: s = s.cut(cyl(x, y, PCB_Z - 1, L.BOARD_NOTCH_R, 3))
    for ref, x, y in L.MOUNT_HOLES: s = s.cut(cyl(x, y, PCB_Z - 1, 1.1, 3))
    return clean(s)

def tail_boot(side):
    """Tail overmould around the JST GH plug (part of the insert assembly, not printed)."""
    a = APER; s = box(a['x0'] + 0.2, -10, a['z0'] + 0.2, a['x1'] - a['x0'] - 0.4, 15.9, a['z1'] - a['z0'] - 0.4)
    s = s.fuse(box(a['x0'] - 1.0, -2.5, a['z0'] - 1.0, a['x1'] - a['x0'] + 2.0, 2.3, a['z1'] - a['z0'] + 2.0))
    k0, k1 = BOOT_KEY[side]; s = s.fuse(box(k0 + 0.2, -10, a['z1'] - 0.2, k1 - k0 - 0.4, 11.8, 0.5))
    return clean(s)

# ------------------------------------------------------------------ build + export
PRINTS = {  # name: (builder, material, finish, print orientation note, orientation)
    '01_RearHousing':        ('rear', 'PETG or ASA, navy', 'rigid', 'rear face on bed; no supports (ledge gussets, chamfered grooves); bay ceiling bridges 28.8 mm', 'asis'),
    '02_FrontCover':         ('front', 'PETG or ASA, pale grey-blue', 'rigid', 'cosmetic face on bed (flipped); no supports', 'flip'),
    '03_BatteryCartridgeCup':('cup', 'PETG, navy', 'rigid', 'rear face on bed; no supports', 'asis'),
    '04_BatteryCartridgeLid':('lid', 'PETG, navy', 'rigid', 'contact face on bed (flipped); no supports', 'flip'),
    '05_Cradle':             ('cradle', 'PETG, navy', 'rigid', 'back (leg side) on bed; latch arm prints flat; no supports', 'asis'),
    '06_SoftCradlePad_TPU':  ('pad', 'TPU 85A-95A, teal', 'flexible', 'flat', 'asis'),
    '07_Button_TPU':         ('button', 'TPU 85A-95A, teal', 'flexible', 'crown on bed (flipped); 1.5 mm flange overhang, use support if the profile needs it', 'flip'),
    '08_LightWindow_Clear':  ('pipe', 'clear SLA resin or clear PETG', 'rigid', 'window face on bed (flipped); flange needs support in FDM - SLA preferred', 'flip'),
    '09_SeamGasket_TPU':     ('gasket', 'die-cut 0.5 mm silicone/EPDM sheet (TPU print for fit trial only)', 'flexible', 'flat', 'asis'),
}
SIDED = {'rear': rear_housing, 'front': front_cover, 'cradle': cradle}
COMMON = {'cup': cartridge_cup, 'lid': cartridge_lid, 'pad': cradle_pad, 'button': button, 'pipe': light_pipe,
          'gasket': lambda: gasket(0.5)}

doc = A.newDocument('NIVA_RevC_Pod')
report = {'parts': [], 'interference': {}, 'gaps': {}, 'notes': []}
manifest = []

def add(name, shape, group, material, kind, placement=None, printable=False, orient='asis', note=''):
    assert shape.isValid(), name + ' invalid'
    if kind != 'envelope-compound': assert len(shape.Solids) == 1, f'{name}: {len(shape.Solids)} solids'
    o = doc.addObject('Part::Feature', name); o.Shape = shape; o.Label = name
    for prop, val in (('Material', material), ('Kind', kind), ('DesignStatus', 'REV C PROTOTYPE - NOT A RELEASED MEDICAL DEVICE'), ('Note', note)):
        o.addProperty('App::PropertyString', prop); setattr(o, prop, val)
    if placement: o.Placement = placement
    group.addObject(o)
    return o

def export_print(name, shape, orient, material, finish, note):
    s = shape.copy()
    if orient == 'flip': s.rotate(V(0, 0, 0), V(1, 0, 0), 180)
    bb = s.BoundBox; s.translate(V(-bb.XMin, -bb.YMin, -bb.ZMin))
    m = MeshPart.meshFromShape(Shape=s, LinearDeflection=0.02, AngularDeflection=0.2, Relative=False)
    m.write(str(PRINT / (name + '.stl')))
    o = doc.addObject('Part::Feature', 'X_' + name); o.Shape = shape
    Part.export([o], str(STEPS / (name + '.step'))); doc.removeObject(o.Name)
    bb = s.BoundBox
    report['parts'].append(dict(part=name, material=material, finish=finish, print_orientation=note,
                                valid=shape.isValid(), solids=len(shape.Solids), volume_mm3=round(shape.Volume, 1),
                                print_bbox_mm=[round(bb.XLength, 2), round(bb.YLength, 2), round(bb.ZLength, 2)],
                                closed_mesh=m.isSolid(), mesh_non_manifolds=m.hasNonManifolds()))

# Kicad component bodies (real library/supplier models) placed in the pod frame
kicad_step = OUT / 'electronics/exports/pcb/NIVA-pod-PCBA.step'
components = kicad_board = None
if kicad_step.exists():
    pcba = Part.Shape(); pcba.read(str(kicad_step)); pcba.translate(V(0, 0, PCB_Z))   # KiCad z = 0 at board underside
    solids = sorted(pcba.Solids, key=lambda x: -x.Volume)
    kicad_board = Part.makeCompound(solids[:1]); components = Part.makeCompound(solids[1:])   # compounds bake the z shift
    own = pcb(); d = abs(kicad_board.Volume - own.Volume) / own.Volume
    bb = components.BoundBox
    report['notes'].append(f'KiCad PCBA STEP imported: {len(solids) - 1} component/pad solids, z {bb.ZMin:.2f}..{bb.ZMax:.2f}; '
                           f'KiCad board body {kicad_board.Volume:.0f} mm3 vs enclosure board solid {own.Volume:.0f} mm3 '
                           f'(difference {100 * d:.1f} %, KiCad dielectric body excludes outer copper/mask)')

groups = {}
for side, dx in (('R', 0.0), ('L', -80.0)):
    g = doc.addObject('App::DocumentObjectGroup', f'Pod_{side}'); groups[side] = g
    pl = A.Placement(V(dx, 0, 0), A.Rotation())
    shapes = {'rear': rear_housing(side), 'front': front_cover(side), 'cradle': cradle(side)}
    shapes.update({k: f() for k, f in COMMON.items()})
    for name, (key, mat, finish, note, orient) in PRINTS.items():
        shp = gasket(STOP_Z - RIM_Z) if key == 'gasket' else shapes[key]   # assembly shows the gasket installed
        sided = key in SIDED
        add(f'{name}_{side}' if sided else f'{name}_{side}', shp, g, mat, finish, pl, True, orient, note)
        if sided or side == 'R':
            export_print(f'{name}_{side}' if sided else name, shapes[key], orient, mat, finish, note)
    add(f'PCB_Substrate_{side}', kicad_board.copy() if kicad_board else pcb(), g, 'FR-4 1.0 mm, 4-layer (KiCad board body)', 'rigid', pl)
    add(f'TailBoot_{side}', tail_boot(side), g, 'TPU overmould on insert tail (not printed)', 'flexible', pl)
    add(f'ContactPlates_{side}', contact_plates(), g, 'brass, gold flash (to select)', 'envelope-compound', pl)
    add(f'Cell_LP502030_MAXSIZE_{side}', cell(), g, 'EEMB LP502030 class, published max size (supplier model not available)', 'envelope', pl)
    add(f'CartridgeStripPCB_{side}', strip_pcb(), g, 'FR-4 0.8 mm interconnect + polyfuse (see electronics/cartridge)', 'rigid', pl)
    if components is not None:
        add(f'PCB_Components_KiCad_{side}', components.copy(), g, 'KiCad library + Espressif models', 'envelope-compound', pl)

doc.recompute()
doc.saveAs(str(CAD / 'NIVA-RevC-assembly.FCStd'))
Part.export([o for o in doc.Objects if o.TypeId == 'Part::Feature'], str(CAD / 'NIVA-RevC-assembly.step'))

# ------------------------------------------------------------------ interference + fit audit (right pod)
objs = [o for o in groups['R'].Group]
EXPECTED = {frozenset({'PCB_Components_KiCad_R', 'ContactPlates_R'}): 'J2 spring plungers drawn uncompressed: 0.4 mm design preload on the lid plates',
            frozenset({'PCB_Components_KiCad_R', '04_BatteryCartridgeLid_R'}): 'J2 plunger tips enter the plate pockets (preload)'}
for a, b in itertools.combinations(objs, 2):
    if not a.Shape.BoundBox.intersect(b.Shape.BoundBox): continue
    v = a.Shape.common(b.Shape).Volume
    if v > 1e-3:
        key = f'{a.Label} x {b.Label}'
        report['interference'][key] = dict(volume_mm3=round(v, 3), expected=EXPECTED.get(frozenset({a.Label, b.Label}), ''))
byl = lambda n: (doc.getObjectsByLabel(n) or [None])[0]      # names starting with a digit get a '_' prefix
def gap(a, b):
    d = byl(a).Shape.distToShape(byl(b).Shape)[0]; report['gaps'][f'{a} to {b}'] = round(d, 3)
for a, b in [('PCB_Substrate_R', '01_RearHousing_R'), ('PCB_Substrate_R', '02_FrontCover_R'),
             ('07_Button_TPU_R', 'PCB_Components_KiCad_R'), ('08_LightWindow_Clear_R', 'PCB_Components_KiCad_R'),
             ('PCB_Components_KiCad_R', '02_FrontCover_R'), ('PCB_Components_KiCad_R', '01_RearHousing_R'),
             ('03_BatteryCartridgeCup_R', '01_RearHousing_R'), ('04_BatteryCartridgeLid_R', '01_RearHousing_R'),
             ('05_Cradle_R', '01_RearHousing_R'), ('TailBoot_R', '01_RearHousing_R'), ('TailBoot_R', '02_FrontCover_R'),
             ('TailBoot_R', 'PCB_Components_KiCad_R'), ('TailBoot_R', 'PCB_Substrate_R'),
             ('Cell_LP502030_MAXSIZE_R', '04_BatteryCartridgeLid_R'), ('Cell_LP502030_MAXSIZE_R', '03_BatteryCartridgeCup_R'),
             ('CartridgeStripPCB_R', 'Cell_LP502030_MAXSIZE_R'), ('CartridgeStripPCB_R', '03_BatteryCartridgeCup_R')]:
    if byl(a) and byl(b): gap(a, b)
(CAD / 'geometry-validation.json').write_text(json.dumps(report['parts'], indent=2))
(CAD / 'interference-report.json').write_text(json.dumps({k: report[k] for k in ('interference', 'gaps', 'notes')}, indent=2))
for o in doc.Objects:
    if o.TypeId == 'Part::Feature':
        m = MeshPart.meshFromShape(Shape=o.Shape, LinearDeflection=0.03, AngularDeflection=0.25, Relative=False)
        m.write(str(MESH / (o.Label + '.stl')))
        manifest.append(dict(name=o.Label, material=o.Material, kind=o.Kind, stl=f'work/niva-meshes/{o.Label}.stl',
                             offset_x=o.Placement.Base.x))
(ROOT / 'work/niva-scene-manifest.json').write_text(json.dumps(manifest, indent=2))
print('Rev C CAD complete:', len(report['parts']), 'print files;', len(report['interference']), 'intersections')
for k, v in report['interference'].items(): print('  ', k, v)
for k, v in report['gaps'].items(): print('   gap', k, v)
