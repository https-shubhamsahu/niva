"""NIVA Rev C.2 (Protected Steps) mounting variants for the unchanged Rev C.1 pod body. FreeCAD 1.1 python:

  freecadcmd build_ps_mounts.py        (or: python3 with FreeCAD's lib on PYTHONPATH)

New parts (pod frame, mm; x = width 0..42, y = 0 at the cable end, z = 0 at the pod back):
  13_AnkleCradle_R/L       ankle-hub cradle: the Rev C rail / key / latch interface, parametric strap slots
  14_CollarClip_R/L        shoe-node clip: same interface plus a hook over the shoe collar (pod worn cable end up)
  15_TailBlank_TPU         plug for the tail aperture when no insole tail is connected (ankle hub)
  16_AnkleSaddlePad_TPU    concave leg-side pad for the ankle cradle
  REF_CollarSlab, REF_TailBand   reference geometry for the fit check only (never printed)

The pod parts are NOT redrawn: rear_housing(), front_cover(), tail_boot(), cradle() are executed from the
unchanged Rev C.1 generator hardware/work/build_niva_cad_revC.py (only its definitions, never its export block),
so the new parts mate with exactly the geometry that was audited and exported for Rev C.1. Rev C.1 files are read,
never written.

Every number below is either copied from the Rev C.1 interface, or a DESIGN PARAMETER (a choice, to be tuned on
prints), or a PLACEHOLDER that must be MEASURED on the participant's footwear / leg before printing.
"""
from pathlib import Path
import json, itertools, sys
import FreeCAD as A, Part, MeshPart

HW = Path('/home/shubh/_Active_Projects/niva-pcbway/hardware')
SRC = HW / 'work/build_niva_cad_revC.py'
PKG = HW / 'outputs/NIVA-RevC2-protected-steps'
MECH = PKG / 'mechanical'; STEPS = MECH / 'STEP-parts'; PRINT = MECH / 'STL-print-parts'; MESH = PKG / 'work/meshes'
for p in (STEPS, PRINT, MESH): p.mkdir(parents=True, exist_ok=True)

# ---- execute only the definitions of the Rev C.1 generator (everything above its build/export block)
src = SRC.read_text()
cut = src.index('# ------------------------------------------------------------------ build + export')
NS = {'__file__': str(SRC), '__name__': 'revC_defs'}
exec(compile(src[:cut], str(SRC), 'exec'), NS)
L = NS['L']; V = A.Vector
rr, box, cyl, prism_xz, prism_yz, text_solid, clean = (NS[k] for k in ('rr', 'box', 'cyl', 'prism_xz', 'prism_yz', 'text_solid', 'clean'))
W, H = L.POD_W, L.POD_H
APER = NS['APER']; BOOT_KEY = NS['BOOT_KEY']

# ---------------------------------------------------------------- parameters
P = dict(
    # copied from the Rev C cradle (build_niva_cad_revC.py cradle()): plate x -3..45, y 1..59, back face z = -3.4
    PLATE_BACK_Z=-3.4,
    # DESIGN PARAMETER: strap width. 35 mm = the Rev C cradle's strap (PRINT-AND-ASSEMBLY.md section 2,
    # "35 mm smooth silicone ladder strap"); no strap has been bought. Change to the strap you buy.
    STRAP_W=35.0,
    WING_SPAN=69.0,          # DESIGN PARAMETER: Rev C wing is 63 mm; +6 mm leaves room for the role mark outboard of the slots
    # PLACEHOLDER - MEASURE: radius of the lower shin at the strap line. Only shapes the soft pad.
    SHIN_R=60.0,
    PAD_MIN=2.0,             # DESIGN PARAMETER: pad thickness at its centre (Rev C pad is 2.0 mm)
    # PLACEHOLDER - MEASURE: shoe collar wall thickness (lining + counter + upper) on the prescribed shoe.
    COLLAR_T=5.0,
    # PLACEHOLDER - MEASURE: insole tail band thickness where it crosses the collar (Rev C renders draw it 1.2 mm).
    TAIL_T=1.2,
    TAIL_SLOT_W=9.0,         # DESIGN PARAMETER: slot for the 8 mm tail band (Rev C renders: 8 mm band) + 0.5 per side
    HOOK_W=30.0,             # DESIGN PARAMETER: hook width (x), centred on the pod
    BRIDGE_T=2.4,            # DESIGN PARAMETER: bridge thickness over the collar top edge
    TONGUE_T=1.8,            # DESIGN PARAMETER: inner tongue thickness
    TONGUE_L=14.0,           # DESIGN PARAMETER: inner tongue length below the collar edge (keep short: skin side)
    GRIP=0.8,                # DESIGN PARAMETER: tongue-tip interference with the tail+collar stack (spring preload)
)
G = P['COLLAR_T'] + P['TAIL_T']                     # free gap between the plate back and the tongue at its root
ZB = P['PLATE_BACK_Z']

# ---------------------------------------------------------------- parts
def interface_core(side):
    """The Rev C cradle with its strap wings and tactile dots trimmed off: plate, rails, rail lips, L/R key post,
    cartridge-screw relief and cantilever latch, unchanged."""
    return NS['cradle'](side).common(box(-3.05, 0.9, -3.6, 48.1, 64.0, 7.6))

def ankle_cradle(side):
    s = interface_core(side)
    wh = P['STRAP_W'] + 4.0; yc = 30.5                                  # Rev C wing: 39 mm for a 35 mm strap, centred y 30.5
    span = P['WING_SPAN']; wings = rr(span, wh, 4, ZB, 3.0, 21 - span / 2, yc - wh / 2)
    # keep the core's cuts that the wings overlap (9 Nov 2026 review): the cartridge screw-head relief and slot, and the
    # latch arm's side slots and thinning, so the arm keeps the Rev C length and the head can slide in
    tx, ty = L.CART_TAB['screw']
    for c in (cyl(tx, ty, -2.0, 2.4, 1.7), box(tx - 2.4, ty, -2.0, 4.8, 59.6 - ty, 1.7), box(16.2, 45, -3.6, 0.8, 16, 3.4),
              box(25.0, 45, -3.6, 0.8, 16, 3.4), box(17, 46.5, -1.8, 8, 14, 1.5)):
        wings = wings.cut(c)
    s = s.fuse(wings)
    for x in (-7.8, 45.8):
        s = s.cut(rr(4, P['STRAP_W'] + 0.5, 1, ZB - 0.2, 3.4, x, yc - (P['STRAP_W'] + 0.5) / 2))
    xm = (21 - span / 2 - 7.8) / 2                                     # role mark outboard of each strap slot
    for t in (text_solid('A', 3.6, xm, yc, ZB + 3.0 - 0.5, 0.6), text_solid(side, 3.6, 42 - xm, yc, ZB + 3.0 - 0.5, 0.6)):
        if t: s = s.cut(t)
    return clean(s)

def saddle_pad():
    """TPU pad bonded under the ankle cradle. Leg face is a concave cylinder of radius SHIN_R (axis along y)."""
    r = P['SHIN_R']; half = 25.0
    sag = r - (r * r - half * half) ** 0.5
    z_top = ZB; z_bot = ZB - P['PAD_MIN'] - sag - 0.5
    blk = rr(50, 60, 6, z_bot, z_top - z_bot, -4, 0)
    axis_z = ZB - P['PAD_MIN'] - r
    c = Part.makeCylinder(r, 80, V(21, -10, axis_z), V(0, 1, 0))
    s = blk.cut(c)
    s = s.cut(box(16, 44, z_bot - 0.2, 10, 21, z_top - z_bot + 0.4))     # latch arm free to flex (as Rev C pad)
    return clean(s), round(sag, 2)

def collar_clip(side):
    s = interface_core(side)
    x0 = 21 - P['HOOK_W'] / 2
    y_edge = 1.0                                                         # collar top edge under the bridge (plate end)
    z_in = ZB - G                                                        # tongue root, upper face
    z_bot = z_in - P['TONGUE_T']
    bridge = box(x0, y_edge - P['BRIDGE_T'], z_bot, P['HOOK_W'], P['BRIDGE_T'], -0.4 - z_bot)
    # tongue: root at the bridge, tip moved toward the plate by GRIP (printed spring preload)
    L_ = P['TONGUE_L']; gp = P['GRIP']
    prof = [(y_edge - P['BRIDGE_T'], z_bot), (y_edge + L_, z_bot + gp), (y_edge + L_, z_in + gp), (y_edge - P['BRIDGE_T'], z_in)]
    tongue = prism_yz(prof, x0, P['HOOK_W'])
    # round the tongue tip (skin side) with a half-cylinder
    tip = Part.makeCylinder(P['TONGUE_T'] / 2, P['HOOK_W'], V(x0, y_edge + L_, z_bot + gp + P['TONGUE_T'] / 2), V(1, 0, 0))
    s = s.fuse(bridge).fuse(tongue).fuse(tip)
    # slot through the bridge for the insole tail, at the tail's position between collar and tongue
    sw = P['TAIL_SLOT_W']
    s = s.cut(box(21 - sw / 2, y_edge - P['BRIDGE_T'] - 0.1, z_in - 0.2, sw, P['BRIDGE_T'] + 0.2, P['TAIL_T'] + 0.6))
    for txt, x in (('S', 14.0), (side, 28.0)):                              # debossed on the back (shoe side), reads from behind
        t = text_solid(txt, 6.0, 0, 0, 0, 0.6)
        if t:
            t.rotate(V(0, 0, 0), V(0, 1, 0), 180); t.translate(V(x, 30.0, ZB + 0.5)); s = s.cut(t)
    return clean(s)

def tail_blank(side='R'):
    """Closes the tail aperture of a pod used as the ankle hub (no insole tail). Same outer flange and key as the
    Rev C tail boot, short body (does not reach J1)."""
    a = APER
    body = box(a['x0'] + 0.2, -0.2, a['z0'] + 0.2, a['x1'] - a['x0'] - 0.4, 2.6, a['z1'] - a['z0'] - 0.4)
    flange = box(a['x0'] - 1.0, -1.8, a['z0'] - 1.0, a['x1'] - a['x0'] + 2.0, 1.6, a['z1'] - a['z0'] + 2.0)
    k0, k1 = BOOT_KEY[side]; key = box(k0 + 0.2, -1.8, a['z1'] - 0.2, k1 - k0 - 0.4, 4.2, 0.5)
    return clean(body.fuse(flange).fuse(key))                          # remove by a fingernail under the 1 mm flange lip

def ref_collar():
    return box(-15, 1.0, ZB - P['COLLAR_T'], 72, 70, P['COLLAR_T'])
def ref_tail():
    return box(21 - 4, -1.6, ZB - G, 8, 72, P['TAIL_T'])

# ---------------------------------------------------------------- build, validate, export
doc = A.newDocument('NIVA_RevC2_ProtectedSteps_mounts')
rep = {'parameters': P, 'parts': [], 'interference': {}, 'gaps': {}, 'notes': []}

def export_part(name, shape, orient, material, note):
    assert shape.isValid(), name
    s = shape.copy()
    if orient == 'flip': s.rotate(V(0, 0, 0), V(1, 0, 0), 180)
    if orient == 'side_x': s.rotate(V(0, 0, 0), V(0, 1, 0), -90)           # original -x face down on the bed
    if orient == 'y_up': s.rotate(V(0, 0, 0), V(1, 0, 0), 90)              # original -y face (flange) down on the bed
    bb = s.BoundBox; s.translate(V(-bb.XMin, -bb.YMin, -bb.ZMin))
    m = MeshPart.meshFromShape(Shape=s, LinearDeflection=0.02, AngularDeflection=0.2, Relative=False)
    m.write(str(PRINT / f'{name}.stl'))
    o = doc.addObject('Part::Feature', 'X_' + name); o.Shape = shape
    Part.export([o], str(STEPS / f'{name}.step')); doc.removeObject(o.Name)
    # re-open the exported files as an independent check
    rs = Part.Shape(); rs.read(str(STEPS / f'{name}.step'))
    import Mesh
    rm = Mesh.Mesh(str(PRINT / f'{name}.stl'))
    bb = s.BoundBox
    rep['parts'].append(dict(part=name, material=material, print_orientation=note, valid=shape.isValid(),
                             solids=len(shape.Solids), volume_mm3=round(shape.Volume, 1),
                             print_bbox_mm=[round(bb.XLength, 2), round(bb.YLength, 2), round(bb.ZLength, 2)],
                             step_reread_solids=len(rs.Solids), step_reread_volume_mm3=round(rs.Volume, 1),
                             stl_reread_facets=rm.CountFacets, closed_mesh=rm.isSolid(), mesh_non_manifolds=rm.hasNonManifolds()))

def add(name, shape, group, material, kind):
    o = doc.addObject('Part::Feature', name); o.Shape = shape; o.Label = name
    for prop, val in (('Material', material), ('Kind', kind),
                      ('DesignStatus', 'REV C.2 PROTECTED STEPS - CAD ONLY, NOT PRINTED OR TESTED')):
        o.addProperty('App::PropertyString', prop); setattr(o, prop, val)
    group.addObject(o)
    mm = MeshPart.meshFromShape(Shape=shape, LinearDeflection=0.03, AngularDeflection=0.25, Relative=False)
    mm.write(str(MESH / f'{name}.stl'))
    return o

pad, sag = saddle_pad()
rep['notes'].append(f'Saddle pad sagitta over its 50 mm width at SHIN_R = {P["SHIN_R"]} mm: {sag} mm (calculated).')
new = {
    '13_AnkleCradle_R': (ankle_cradle('R'), 'PETG', 'asis', 'back (leg side) on bed, as Rev C cradle 05; no supports'),
    '13_AnkleCradle_L': (ankle_cradle('L'), 'PETG', 'asis', 'back (leg side) on bed, as Rev C cradle 05; no supports'),
    '14_CollarClip_R': (collar_clip('R'), 'PETG', 'side_x', 'on its -x rail wall (hook profile in the layer plane); brim; no supports expected - check in the slicer'),
    '14_CollarClip_L': (collar_clip('L'), 'PETG', 'side_x', 'on its -x rail wall (hook profile in the layer plane); brim; no supports expected - check in the slicer'),
    '15_TailBlank_TPU_R': (tail_blank('R'), 'TPU 95A', 'y_up', 'flange (outer) face on bed; no supports'),
    '15_TailBlank_TPU_L': (tail_blank('L'), 'TPU 95A', 'y_up', 'flange (outer) face on bed; no supports'),
    '16_AnkleSaddlePad_TPU': (pad, 'TPU 85A-95A', 'flip', 'flat (cradle) face on bed, concave leg face up; no supports'),
}
for name, (shp, mat, orient, note) in new.items():
    export_part(name, shp, orient, mat, note)

# assemblies (right side) with the unchanged Rev C pod parts
pod = {'01_RearHousing_R': NS['rear_housing']('R'), '02_FrontCover_R': NS['front_cover']('R')}
kicad_step = PKG / 'electronics-C2-working/exports/pcb/NIVA-pod-PCBA.step'          # Rev C.2 board (regrouped J2, antenna notch)
pcba = Part.Shape(); pcba.read(str(kicad_step)); pcba.translate(V(0, 0, NS['PCB_Z']))
sol = sorted(pcba.Solids, key=lambda x: -x.Volume)
pod['PCB_Substrate_R'] = Part.makeCompound(sol[:1]); pod['PCB_Components_KiCad_R'] = Part.makeCompound(sol[1:])

ga = doc.addObject('App::DocumentObjectGroup', 'AnkleHub_R'); gs = doc.addObject('App::DocumentObjectGroup', 'ShoeNode_R')
for grp, extra in ((ga, {'13_AnkleCradle_R': new['13_AnkleCradle_R'][0], '16_AnkleSaddlePad_TPU': pad,
                         '15_TailBlank_TPU_R': new['15_TailBlank_TPU_R'][0]}),
                   (gs, {'14_CollarClip_R': new['14_CollarClip_R'][0], 'TailBoot_R': NS['tail_boot']('R'),
                         'REF_CollarSlab': ref_collar(), 'REF_TailBand': ref_tail()})):
    objs = {}
    for k, shp in {**pod, **extra}.items():
        nm = f'{k}__{grp.Name}'
        kind = 'reference (not printed)' if k.startswith('REF_') else ('Rev C.1 unchanged' if k in pod or k == 'TailBoot_R' else 'Rev C.2 new')
        objs[k] = add(nm, shp, grp, new.get(k, (None, 'see Rev C.1'))[1], kind)
    EXPECT = {frozenset({'14_CollarClip_R', 'REF_TailBand'}): 'intended: tongue-tip preload (GRIP) on the tail band',
              frozenset({'14_CollarClip_R', 'REF_CollarSlab'}): 'intended only if GRIP > TAIL_T'}
    for a, b in itertools.combinations(objs, 2):
        sa, sb = objs[a].Shape, objs[b].Shape
        if not sa.BoundBox.intersect(sb.BoundBox): continue
        if {a, b} == {'PCB_Substrate_R', 'PCB_Components_KiCad_R'}: continue
        v = sa.common(sb).Volume
        if v > 1e-3:
            rep['interference'][f'{grp.Name}: {a} x {b}'] = dict(volume_mm3=round(v, 3), expected=EXPECT.get(frozenset({a, b}), 'NOT EXPECTED'))
    def gap(a, b):
        if a in objs and b in objs:
            rep['gaps'][f'{grp.Name}: {a} to {b}'] = round(objs[a].Shape.distToShape(objs[b].Shape)[0], 3)
    for a, b in [('13_AnkleCradle_R', '01_RearHousing_R'), ('13_AnkleCradle_R', '02_FrontCover_R'),
                 ('16_AnkleSaddlePad_TPU', '13_AnkleCradle_R'), ('16_AnkleSaddlePad_TPU', '01_RearHousing_R'),
                 ('15_TailBlank_TPU_R', '01_RearHousing_R'), ('15_TailBlank_TPU_R', '02_FrontCover_R'),
                 ('15_TailBlank_TPU_R', 'PCB_Components_KiCad_R'), ('15_TailBlank_TPU_R', 'PCB_Substrate_R'),
                 ('14_CollarClip_R', '01_RearHousing_R'), ('14_CollarClip_R', '02_FrontCover_R'),
                 ('14_CollarClip_R', 'TailBoot_R'), ('14_CollarClip_R', 'REF_CollarSlab'),
                 ('REF_CollarSlab', '01_RearHousing_R'), ('TailBoot_R', '01_RearHousing_R')]:
        gap(a, b)

# Rev C cradle 05 vs the new interface core: the mating geometry must be identical
c05 = NS['cradle']('R'); core = interface_core('R')
diff = core.cut(c05).Volume
rep['notes'].append(f'interface core minus Rev C cradle 05 = {diff:.4f} mm3 (0 means the mating features are the Rev C ones, unchanged)')
# collar clip: free gap at the tongue root and at the tip (measured on the solid)
clip = new['14_CollarClip_R'][0]
def zspan(x, y):
    line = Part.LineSegment(V(x, y, -20), V(x, y, 5)).toShape()
    pts = sorted(p.z for e in clip.section(line).Vertexes for p in [e.Point])
    return pts
for y in (2.0, 1.0 + P['TONGUE_L'] - 1.0):
    zs = zspan(8.0, y)
    rep['gaps'][f'collar clip: z-intersections at x=8, y={y}'] = [round(z, 3) for z in zs]
doc.recompute()
doc.saveAs(str(MECH / 'NIVA-RevC2-ProtectedSteps-mounts.FCStd'))
Part.export([o for o in doc.Objects if o.TypeId == 'Part::Feature'], str(MECH / 'NIVA-RevC2-ProtectedSteps-mounts.step'))
(MECH / 'mounts-validation.json').write_text(json.dumps(rep, indent=2))
print(json.dumps(rep, indent=1))
