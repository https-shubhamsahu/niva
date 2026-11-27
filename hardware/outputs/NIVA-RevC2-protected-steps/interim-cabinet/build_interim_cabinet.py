"""Interim cabinet for the CURRENT Niva working prototype (classic ESP32 dev board + MPU6050 + optional SH1106
OLED on perfboard), printable this week. FreeCAD 1.1 python:

  freecadcmd build_interim_cabinet.py                 # uses cabinet-params.json next to this file

Edit cabinet-params.json after measuring the real boards with calipers, then re-run. Every value in the
"MEASURE" group is a PLACEHOLDER until someone measures it: the defaults are round numbers (or, where noted,
Espressif's ESP32-DevKitC V4 drawing), not measurements of the team's boards. Print only after measuring.

Frame (mm): x = box width, y = box length (the arrow on the lid points +y), z = up from the bed, floor at z = 0.
The perfboard's -x/-y corner is the origin of every board position parameter.

Outputs (this folder): interim-cabinet.FCStd / .step (with labelled DUMMY board blocks), STEP/ and STL/ for the
two printed parts (STLs in print orientation), cabinet-validation.json, meshes/ for the renders.
"""
from pathlib import Path
import json, math
import FreeCAD as A, Part, MeshPart, Mesh

V = A.Vector
HERE = Path('/home/shubh/_Active_Projects/niva-pcbway/hardware/outputs/NIVA-RevC2-protected-steps/interim-cabinet')
PRM = json.loads((HERE / 'cabinet-params.json').read_text())
M = {k: v['value'] for k, v in PRM['MEASURE'].items()}
D = {k: v['value'] for k, v in PRM['DESIGN'].items()}
for p in ('STEP', 'STL', 'meshes'): (HERE / p).mkdir(exist_ok=True)
FONT = next((f for f in ['/usr/share/fonts/TTF/DejaVuSans-Bold.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
                         '/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf'] if Path(f).exists()), None)

def rr(w, h, r, z, t, x=0, y=0):
    r = max(0.01, min(r, w / 2 - 0.01, h / 2 - 0.01))
    b = Part.makeBox(w, h, t, V(x, y, z))
    return b.makeFillet(r, [e for e in b.Edges if abs(e.Vertexes[0].Point.z - e.Vertexes[1].Point.z) > 1e-6])
def box(x, y, z, w, h, t): return Part.makeBox(w, h, t, V(x, y, z))
def cyl(x, y, z, r, h, d=V(0, 0, 1)): return Part.makeCylinder(r, h, V(x, y, z), d)
def text(s, size, x, y, z, depth):
    if not FONT: return None
    fs = [Part.makeFace(w, 'Part::FaceMakerBullseye') for w in Part.makeWireString(s, FONT, size, 0) if w]
    if not fs: return None
    sh = Part.makeCompound(fs); bb = sh.BoundBox
    sh.translate(V(x - bb.XMin - bb.XLength / 2, y - bb.YMin - bb.YLength / 2, z)); return sh.extrude(V(0, 0, depth))
def clean(s):
    s = s.removeSplitter()
    return s.Solids[0] if s.ShapeType == 'Compound' and len(s.Solids) == 1 else s

# ---------------------------------------------------------------- derived layout
W_, F_, C_ = D['WALL'], D['FLOOR'], D['CLEAR']
boss_d = D['BOSS_D']
cav_w = M['PERF_W'] + 2 * C_
cav_l = M['PERF_L'] + 2 * C_ + 2 * (boss_d + 0.5)           # screw bosses sit beyond both perfboard ends
px0, py0 = W_ + C_, W_ + C_ + boss_d + 0.5                  # perfboard -x/-y corner in the box frame
perf_z = F_ + M['UNDER_H']                                  # perfboard underside
perf_top = perf_z + M['PERF_T']
rim = perf_top + M['STACK_H'] + D['TOP_CLEAR']
out_w, out_l = cav_w + 2 * W_, cav_l + 2 * W_
lid_z = rim
bi = W_ + boss_d / 2 - 0.8                                   # bosses overlap the walls by 0.8 mm (no tangent faces)
bosses = [(bi, bi), (out_w - bi, bi), (bi, out_l - bi), (out_w - bi, out_l - bi)]
usb_y = py0 + M['USB_POS_Y']; usb_z = perf_top + M['USB_Z_ABOVE_PERF']
cab_y = py0 + M['CABLE_POS_Y']; cab_r = M['CABLE_D'] / 2
cab_z = perf_top + M['CABLE_Z_ABOVE_PERF']                 # cable centre where it crosses the wall

def corners_in():
    """-x/-y corner of a PAD x PAD square just inside each perfboard corner (pads below, clamp posts above)."""
    a = D['PAD']
    return [(px0, py0), (px0 + M['PERF_W'] - a, py0), (px0, py0 + M['PERF_L'] - a), (px0 + M['PERF_W'] - a, py0 + M['PERF_L'] - a)]

def base():
    s = rr(out_w, out_l, D['CORNER_R'], 0, rim)
    s = s.cut(rr(cav_w, cav_l, max(0.5, D['CORNER_R'] - W_), F_, rim, W_, W_))
    # strap wings (ankle-hub use): a plate under the box with one strap slot each side
    ww = D['STRAP_W'] + 8.0; wy = out_l / 2 - ww / 2
    s = s.fuse(rr(out_w + 2 * D['WING'], ww, 3, 0, D['WING_T'], -D['WING'], wy))
    for x in (-D['WING'] + 3.0, out_w + D['WING'] - 3.0 - D['SLOT_T']):
        s = s.cut(rr(D['SLOT_T'], D['STRAP_W'] + 0.5, 1, -0.1, D['WING_T'] + 0.2, x, out_l / 2 - (D['STRAP_W'] + 0.5) / 2))
    # perfboard corner pads (perfboard rests on them; keep 5 mm of each corner free of parts underneath)
    for cx, cy in corners_in():
        s = s.fuse(box(cx, cy, F_ - 0.01, D['PAD'], D['PAD'], perf_z - F_ + 0.01))
    # screw bosses (M3 thread-forming; pilot is a design value - tune on a test print)
    for x, y in bosses:
        s = s.fuse(cyl(x, y, 0, boss_d / 2, rim).common(rr(out_w, out_l, D['CORNER_R'], 0, rim)))
        s = s.cut(cyl(x, y, F_, D['PILOT_D'] / 2, rim))
    # USB opening in the +x wall
    uw, uh = M['USB_OPEN_W'], M['USB_OPEN_H']
    s = s.cut(box(out_w - W_ - 1, usb_y - uw / 2, usb_z - uh / 2, W_ + 2, uw, uh))
    rw, rh = uw + 2 * D['USB_RECESS'], uh + 2 * D['USB_RECESS']        # outside pocket so the plug overmould can enter
    s = s.cut(box(out_w - D['USB_RECESS_DEPTH'], usb_y - rw / 2, usb_z - rh / 2, D['USB_RECESS_DEPTH'] + 1, rw, rh))
    # insole cable exit in the -x wall: U-notch open at the rim so the cable can be laid in; the lid tongue closes it
    nw = M['CABLE_D'] + D['CABLE_CLEAR']
    s = s.cut(box(-1, cab_y - nw / 2, cab_z, W_ + 2, nw, rim - cab_z + 1))
    s = s.cut(cyl(-1, cab_y, cab_z, nw / 2, W_ + 2, V(1, 0, 0)))
    # zip-tie lug on the outside of the -x wall, under the cable exit (45-degree underside: prints without support)
    z1 = cab_z - cab_r - 0.8; z0 = z1 - 8.0
    if z0 > D['WING_T'] + 0.5:
        pts = [(0.5, z0), (0.5, z1), (-5.0, z1), (-5.0, z0 + 5.5)]
        lug = Part.Face(Part.makePolygon([V(x, cab_y - 5, z) for x, z in pts] + [V(pts[0][0], cab_y - 5, pts[0][1])])).extrude(V(0, 10, 0))
        lug = lug.cut(box(-4.2, cab_y - 6, z1 - 3.4, 3.4, 12, 1.8))          # tie slot, 3.4 x 1.8 mm, along y
        s = s.fuse(lug)
    return clean(s)

def lid():
    s = rr(out_w, out_l, D['CORNER_R'], lid_z, D['LID_T'])
    lip_o = rr(cav_w - 2 * D['LIP_CLEAR'], cav_l - 2 * D['LIP_CLEAR'], max(0.5, D['CORNER_R'] - W_ - D['LIP_CLEAR']),
               lid_z - D['LIP_H'], D['LIP_H'] + 0.01, W_ + D['LIP_CLEAR'], W_ + D['LIP_CLEAR'])
    lip_i = rr(cav_w - 2 * D['LIP_CLEAR'] - 2 * D['LIP_T'], cav_l - 2 * D['LIP_CLEAR'] - 2 * D['LIP_T'], 0.5,
               lid_z - D['LIP_H'] - 0.1, D['LIP_H'] + 0.3, W_ + D['LIP_CLEAR'] + D['LIP_T'], W_ + D['LIP_CLEAR'] + D['LIP_T'])
    lip = lip_o.cut(lip_i)
    for x, y in bosses: lip = lip.cut(cyl(x, y, lid_z - D['LIP_H'] - 0.2, boss_d / 2 + 0.4, D['LIP_H'] + 0.4))
    nw = M['CABLE_D'] + D['CABLE_CLEAR']
    lip = lip.cut(box(W_ - 0.5, cab_y - nw / 2, lid_z - D['LIP_H'] - 1, D['LIP_CLEAR'] + D['LIP_T'] + 1, nw, D['LIP_H'] + 1))
    s = s.fuse(lip)
    # cable-exit tongue: fills the wall notch down to the cable top, minus the squeeze (strain relief)
    nw = M['CABLE_D'] + D['CABLE_CLEAR']
    tz = cab_z + cab_r - D['CABLE_SQUEEZE']
    tongue = box(0.2, cab_y - nw / 2 + 0.2, tz + 0.01, W_ + D['LIP_CLEAR'] + D['LIP_T'] - 0.2, nw - 0.4, lid_z - tz)
    tongue = tongue.cut(cyl(-1, cab_y, cab_z, cab_r - D['CABLE_SQUEEZE'], W_ + 4, V(1, 0, 0)))
    s = s.fuse(tongue)
    # screw clearance + head counterbore
    for x, y in bosses:
        s = s.cut(cyl(x, y, lid_z - 1, D['SCREW_CLEAR_D'] / 2, D['LID_T'] + 2))
        s = s.cut(cyl(x, y, lid_z + D['LID_T'] - D['HEAD_CB_H'], D['HEAD_CB_D'] / 2, D['HEAD_CB_H'] + 1))
    # perfboard clamp posts at the four corners (CLAMP_GAP above the board top)
    ph = lid_z - (perf_top + D['CLAMP_GAP'])
    for cx, cy in corners_in():
        s = s.fuse(box(cx, cy, perf_top + D['CLAMP_GAP'], D['PAD'], D['PAD'], ph + 0.01))
    # OLED window with an inside recess for a clear acrylic pane (glued in)
    if M['OLED_FITTED']:
        ox, oy = px0 + M['OLED_AA_CX'], py0 + M['OLED_AA_CY']
        ww, wh = M['OLED_AA_W'] + 2 * D['WINDOW_MARGIN'], M['OLED_AA_H'] + 2 * D['WINDOW_MARGIN']
        s = s.cut(rr(ww, wh, 1.0, lid_z - 1, D['LID_T'] + 2, ox - ww / 2, oy - wh / 2))
        pw, ph2 = ww + 2 * D['PANE_OVERLAP'], wh + 2 * D['PANE_OVERLAP']
        s = s.cut(rr(pw, ph2, 1.0, lid_z - 0.01, M['PANE_T'] + 0.2, ox - pw / 2, oy - ph2 / 2))
    for hx, hy in M['LID_HOLES']:                               # optional light / button holes (board coordinates)
        s = s.cut(cyl(px0 + hx, py0 + hy, lid_z - 1, D['HOLE_D'] / 2, D['LID_T'] + 2))
    # orientation arrow + label, debossed in the top face
    top = lid_z + D['LID_T']
    ax, ay = (out_w - W_ - 9.0, py0 + M['OLED_AA_CY']) if M['OLED_FITTED'] else (out_w / 2, out_l - W_ - boss_d - 9.0)
    arrow = Part.Face(Part.makePolygon([V(ax - 4, ay - 3, 0), V(ax, ay + 4, 0), V(ax + 4, ay - 3, 0), V(ax + 1.3, ay - 3, 0),
                                        V(ax + 1.3, ay - 9, 0), V(ax - 1.3, ay - 9, 0), V(ax - 1.3, ay - 3, 0), V(ax - 4, ay - 3, 0)]))
    a3 = arrow.extrude(V(0, 0, 0.6)); a3.translate(V(0, 0, top - 0.5))
    s = s.cut(a3)
    for txt, ty in (('NIVA', W_ + boss_d + 6.0), ('UP', ay - 14.0)):
        t = text(txt, 5.0 if txt == 'NIVA' else 3.5, out_w / 2 if txt == 'NIVA' else ax, ty, top - 0.5, 0.6)
        if t: s = s.cut(t)
    return clean(s)

def pane_box(x, y, z, w, h, t): return rr(w, h, 0.8, z, t, x, y)

def dummies():
    """Labelled DUMMY blocks for the fit check and the render. Sizes come from the MEASURE parameters."""
    d = {}
    d['DUMMY_Perfboard'] = box(px0, py0, perf_z, M['PERF_W'], M['PERF_L'], M['PERF_T'])
    ex, ey = px0 + M['ESP_X0'], py0 + M['ESP_Y0']; ez = perf_top + M['ESP_PCB_Z_ABOVE_PERF']
    esp = box(ex, ey, ez, M['ESP_L'], M['ESP_W'], 1.6)
    esp = esp.fuse(box(ex + 6, ey + (M['ESP_W'] - 18) / 2, ez + 1.6, 18, 18, 3.1))          # module can (placeholder)
    esp = esp.fuse(box(ex + M['ESP_L'] - 5.5, usb_y - 4, ez + 1.6, 6.0, 8, 3.0))            # micro-USB receptacle (placeholder)
    for yy in (ey + 1.3 - 1.27, ey + M['ESP_W'] - 1.3 - 1.27):
        esp = esp.fuse(box(ex + 3, yy, perf_top, M['ESP_L'] - 6, 2.54, ez - perf_top))     # header rows (placeholder)
    d['DUMMY_ESP32_DevBoard'] = esp
    if M['OLED_FITTED']:
        ox, oy = px0 + M['OLED_AA_CX'], py0 + M['OLED_AA_CY']; oz = perf_top + M['OLED_PCB_Z_ABOVE_PERF']
        o = box(ox - M['OLED_MOD_W'] / 2, oy - M['OLED_MOD_L'] / 2, oz, M['OLED_MOD_W'], M['OLED_MOD_L'], 1.2)
        o = o.fuse(box(ox - M['OLED_AA_W'] / 2 - 1.5, oy - M['OLED_AA_H'] / 2 - 2.5, oz + 1.2, M['OLED_AA_W'] + 3, M['OLED_AA_H'] + 5, 1.5))
        o = o.fuse(box(ox - 5.1, oy + M['OLED_MOD_L'] / 2 - 2.54, perf_top, 10.16, 2.54, oz - perf_top))   # 4-pin header
        d['DUMMY_OLED_SH1106'] = o
    mx, my = px0 + M['MPU_X0'], py0 + M['MPU_Y0']
    d['DUMMY_MPU6050_GY521'] = box(mx, my, perf_top, M['MPU_W'], M['MPU_L'], M['MPU_H'])
    d['DUMMY_InsoleCable'] = cyl(-20, cab_y, cab_z, cab_r, 20 + px0, V(1, 0, 0))
    d['DUMMY_PaneAcrylic'] = (pane_box(px0 + M['OLED_AA_CX'] - (M['OLED_AA_W'] / 2 + D['WINDOW_MARGIN'] + D['PANE_OVERLAP']) + 0.2,
                                  py0 + M['OLED_AA_CY'] - (M['OLED_AA_H'] / 2 + D['WINDOW_MARGIN'] + D['PANE_OVERLAP']) + 0.2,
                                  lid_z + 0.15,
                                  M['OLED_AA_W'] + 2 * (D['WINDOW_MARGIN'] + D['PANE_OVERLAP']) - 0.4,
                                  M['OLED_AA_H'] + 2 * (D['WINDOW_MARGIN'] + D['PANE_OVERLAP']) - 0.4, M['PANE_T'])
                              if M['OLED_FITTED'] else None)
    return {k: v for k, v in d.items() if v is not None}

doc = A.newDocument('NIVA_interim_cabinet')
rep = {'derived_mm': dict(outer_w=round(out_w, 2), outer_l=round(out_l, 2), outer_h_closed=round(rim + D['LID_T'], 2),
                          width_over_strap_wings=round(out_w + 2 * D['WING'], 2), perfboard_underside_z=round(perf_z, 2),
                          rim_z=round(rim, 2), usb_centre=[round(out_w, 2), round(usb_y, 2), round(usb_z, 2)],
                          cable_centre=[0, round(cab_y, 2), round(cab_z, 2)]),
       'parts': [], 'interference': {}, 'gaps': {}, 'checks': {}}
parts = {'21_InterimCabinet_Base': (base(), 'asis', 'floor on the bed; no supports; USB opening top edge bridges'),
         '22_InterimCabinet_Lid': (lid(), 'flip', 'top face on the bed (flipped); no supports')}
objs = {}
for name, (shp, orient, note) in parts.items():
    assert shp.isValid() and len(shp.Solids) == 1, name
    s = shp.copy()
    if orient == 'flip': s.rotate(V(0, 0, 0), V(1, 0, 0), 180)
    bb = s.BoundBox; s.translate(V(-bb.XMin, -bb.YMin, -bb.ZMin))
    m = MeshPart.meshFromShape(Shape=s, LinearDeflection=0.02, AngularDeflection=0.2, Relative=False)
    m.write(str(HERE / 'STL' / f'{name}.stl'))
    o = doc.addObject('Part::Feature', name); o.Shape = shp; objs[name] = o
    Part.export([o], str(HERE / 'STEP' / f'{name}.step'))
    rs = Part.Shape(); rs.read(str(HERE / 'STEP' / f'{name}.step')); rm = Mesh.Mesh(str(HERE / 'STL' / f'{name}.stl'))
    bb = s.BoundBox
    rep['parts'].append(dict(part=name, print_orientation=note, valid=shp.isValid(), solids=len(shp.Solids),
                             volume_mm3=round(shp.Volume, 1), print_bbox_mm=[round(bb.XLength, 1), round(bb.YLength, 1), round(bb.ZLength, 1)],
                             step_reread_solids=len(rs.Solids), closed_mesh=rm.isSolid(), mesh_non_manifolds=rm.hasNonManifolds()))
for name, shp in dummies().items():
    o = doc.addObject('Part::Feature', name); o.Shape = shp; objs[name] = o
for name, o in objs.items():
    mm = MeshPart.meshFromShape(Shape=o.Shape, LinearDeflection=0.03, AngularDeflection=0.25, Relative=False)
    mm.write(str(HERE / 'meshes' / f'{name}.stl'))
import itertools
EXPECT = {frozenset({'22_InterimCabinet_Lid', 'DUMMY_InsoleCable'}): 'intended: cable squeeze by the lid tongue (strain relief)'}
for a, b in itertools.combinations(objs, 2):
    sa, sb = objs[a].Shape, objs[b].Shape
    if not sa.BoundBox.intersect(sb.BoundBox): continue
    v = sa.common(sb).Volume
    if v > 1e-3:
        rep['interference'][f'{a} x {b}'] = dict(volume_mm3=round(v, 3), expected=EXPECT.get(frozenset({a, b}),
            'dummy-on-dummy contact (boards stacked on the perfboard)' if a.startswith('DUMMY') and b.startswith('DUMMY') else 'NOT EXPECTED'))
def gap(a, b):
    if a in objs and b in objs: rep['gaps'][f'{a} to {b}'] = round(objs[a].Shape.distToShape(objs[b].Shape)[0], 3)
for a in ('DUMMY_Perfboard', 'DUMMY_ESP32_DevBoard', 'DUMMY_OLED_SH1106', 'DUMMY_MPU6050_GY521'):
    gap(a, '21_InterimCabinet_Base'); gap(a, '22_InterimCabinet_Lid')
gap('21_InterimCabinet_Base', '22_InterimCabinet_Lid'); gap('DUMMY_InsoleCable', '21_InterimCabinet_Base')
# USB plug path: a block the size of the opening pushed in from outside must reach the receptacle without hitting the base
plug = box(out_w - W_ - 0.5, usb_y - M['USB_OPEN_W'] / 2 + D['USB_PLUG_CLEAR'], usb_z - M['USB_OPEN_H'] / 2 + D['USB_PLUG_CLEAR'],
           W_ + 10, M['USB_OPEN_W'] - 2 * D['USB_PLUG_CLEAR'], M['USB_OPEN_H'] - 2 * D['USB_PLUG_CLEAR'])
rep['checks']['usb plug block (opening minus clearance) intersects base, mm3'] = round(plug.common(objs['21_InterimCabinet_Base'].Shape).Volume, 4)
esp_usb_end = px0 + M['ESP_X0'] + M['ESP_L']
rep['checks']['esp32 board end to inner +x wall, mm (receptacle must sit near the wall)'] = round(out_w - W_ - esp_usb_end, 2)
if M['OLED_FITTED']:
    rep['checks']['oled window opening (w x h) mm'] = [M['OLED_AA_W'] + 2 * D['WINDOW_MARGIN'], M['OLED_AA_H'] + 2 * D['WINDOW_MARGIN']]
doc.recompute()
doc.saveAs(str(HERE / 'interim-cabinet.FCStd'))
Part.export(list(objs.values()), str(HERE / 'interim-cabinet-assembly-with-dummies.step'))
(HERE / 'cabinet-validation.json').write_text(json.dumps(rep, indent=2))
print(json.dumps(rep, indent=1))
