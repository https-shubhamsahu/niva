"""NIVA integrated sensing insole flex (hold H1) - KiCad 9 projects for the right and left medium insert.

  python3 build_niva_insole_flex.py          (host python3 + shapely; writes schematics, footprints, layout JSON)
  kicad-cli sch export netlist ...           (see run_insole_flex.sh)
  python3 build_niva_pcb.py place|finalize insole-R / insole-L   (inside kicad/kicad:9.0)

Why: discrete A201 sensors could not reach the big-toe position from the lateral heel tail (tail lengths too
short). Here the five force regions are printed shunt-mode electrodes on one flex, and the leads are copper
lanes on the same flex, so there is no sensor tail to route.

Construction (proposed, to verify by test):
  * 2-layer polyimide flex, 0.12 mm nominal. UNDERFOOT ONLY F.Cu IS USED: no vias, no components, no stiffener.
  * Each force region: 12 mm interdigitated comb pair (0.3 mm fingers / 0.3 mm gaps) under a coverlay opening,
    closed by a force-sensing-resistive (FSR) ink film on a spacer ring. The FSR film is a bought-in or printed
    layer; its resistance-force curve is NOT characterised here.
  * PVDF: two bond pads for the separately supplied piezo film in the recessed heel zone V1.
  * Leads: each sensor has its own drive + sense pair (drive = VEXC); the five drive leads join only above the
    collar, on B.Cu at the transition, so the whole underfoot layer is planar with no crossings.
  * Transition (above the shoe collar, stiffened): 10 wire pads for the jacketed cable to the pod's JST GH plug,
    and the insert ID resistor R1 (right-medium 4.7k, left-medium 47k; pod R30 10k pull-up to VEXC).
Coordinates: insole frame in mm, x across the foot (right foot: medial = small x), Y from the heel (0) to the
toe (260), taken from the 1:1 medium fit template (outputs/niva-vector-blueprints/07-full-size-fit-template.svg).
The left insert is the mirror image (x -> 96 - x) with each FSR's two pins swapped (the FSR is not polarised).
"""
from pathlib import Path
import json, math, re
from shapely.geometry import Point, Polygon, LineString, box
from shapely.ops import unary_union
import niva_kisch as K
from niva_kisch import *

E = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
IDIR = E / 'insole'; LIB = IDIR / 'NIVA_insole.pretty'
SVG = ROOT / 'outputs/niva-vector-blueprints/07-full-size-fit-template.svg'
R_ACT, RING, FW, PITCH = 6.0, 0.4, 0.3, 0.6          # active radius, spine ring width, finger width, finger pitch
TW, PAIR = 0.25, 0.35                                 # track width, half pair spacing (0.7 mm pitch in a pair)
SENSORS = {'P1': (24, 235, 0, 'Big toe'), 'P2': (24, 193, 0, 'Medial forefoot'), 'P3': (80, 180, 0, 'Lateral forefoot'),
           'P4': (70, 117, 0, 'Lateral midfoot'), 'P5': (43, 32, 90, 'Heel')}
V1 = (55.0, 14.0)                                     # PVDF bond pads (recessed heel zone beside P5)
TAIL_X0, TAIL_X1, TR_X0, TR_X1 = 93.0, 208.0, 206.0, 228.0   # tail from the heel tab to the transition
VIA_X, PAD_X = 211.0, 224.0
# Lane centrelines (right foot). Order across the heel tab, top to bottom: P4, P3, P5, P2, P1, PVDF.
TAB_Y = {'P4': 31.25, 'P3': 29.55, 'P5': 27.85, 'P2': 26.15, 'P1': 24.45, 'PVDF': 22.75}
LANES = {
    'P1': [(24, 229.2), (24, 226), (13, 215), (12, 200), (12, 184), (21, 160), (21, 36), (29, 23.1), (50, 23.1), (60, 24.45)],
    'P2': [(24, 187.2), (24, 182), (22.7, 172), (22.7, 37.4), (30.3, 24.8), (50, 24.8), (60, 26.15)],
    'P3': [(80, 174.2), (80, 169), (62, 141), (62, 29.55)],
    'P4': [(70, 111.2), (70, 107), (68, 103), (68, 31.25)],
    'P5': [(48.8, 32), (51.5, 32), (55.65, 27.85)],
    'PVDF': [(60, 14), (62, 14), (70.5, 22.75)],
}
# Wire pads on the transition, top to bottom (frame Y); number = pod J1 pin (JST GH position)
PADS = [('1', 'VEXC'), ('5', 'F4_RAW'), ('4', 'F3_RAW'), ('6', 'F5_RAW'), ('3', 'F2_RAW'), ('2', 'F1_RAW'),
        ('7', 'PVDF_RAW'), ('8', 'GND'), ('9', 'INSERT_ID_RAW'), ('10', 'GND')]
PAD_Y = {n: 29.0 - 2.0 * k for k, (n, _) in enumerate(PADS)}
ID = {'R': ('4.7k 0.1%', 'right medium'), 'L': ('47k 0.1%', 'left medium')}

# ------------------------------------------------------------------ insole outline
def outline():
    d = re.search(r'<g transform="translate\(31 26\) scale\(1\)">\s*<path d="([^"]+)"', SVG.read_text()).group(1)
    tok = re.findall(r'[MCZ]|-?\d+\.?\d*', d); pts = []; i = 0; cur = None
    while i < len(tok):
        if tok[i] == 'M': cur = (float(tok[i + 1]), float(tok[i + 2])); pts.append(cur); i += 3
        elif tok[i] == 'C':
            i += 1
            while i < len(tok) and tok[i] not in 'MCZ':
                p1, p2, p3 = [(float(tok[i + k]), float(tok[i + k + 1])) for k in (0, 2, 4)]; i += 6
                for k in range(1, 33):
                    u = k / 32; a, b, c, e = (1 - u) ** 3, 3 * u * (1 - u) ** 2, 3 * u * u * (1 - u), u ** 3
                    pts.append((a * cur[0] + b * p1[0] + c * p2[0] + e * p3[0], a * cur[1] + b * p1[1] + c * p2[1] + e * p3[1]))
                cur = p3
        else: i += 1
    return Polygon([(x, 260 - y) for x, y in pts]).buffer(0)
TAB = Polygon([(73, 34), (93, 27), (93, 13), (72, 20)])      # lateral heel tail tab (template, heel frame)

# ------------------------------------------------------------------ footprints
def fmt(v): return f'{v:.4f}'.rstrip('0').rstrip('.')
def comb_polys():
    disk = Point(0, 0).buffer(R_ACT, 256); ring = disk.difference(Point(0, 0).buffer(R_ACT - RING, 256))
    inner = Point(0, 0).buffer(R_ACT - RING - 0.3, 256)
    half = {1: box(-9, -9, -0.2, 9), 2: box(0.2, -9, 9, 9)}
    own = {1: box(-9, -9, 0, 9), 2: box(0, -9, 9, 9)}
    combs = {1: [ring.intersection(half[1])], 2: [ring.intersection(half[2])]}
    n = int((R_ACT - 1.2) / PITCH)
    for k in range(-n, n + 1):
        y = k * PITCH; strip = box(-R_ACT, y - FW / 2, R_ACT, y + FW / 2)
        p = 1 if k % 2 == 0 else 2
        combs[p].append(strip.intersection(inner.union(disk.intersection(own[p]))))
    a, b = unary_union(combs[1]), unary_union(combs[2])
    assert a.geom_type == b.geom_type == 'Polygon' and a.distance(b) > 0.29, (a.geom_type, b.geom_type, a.distance(b))
    return a.simplify(0.005), b.simplify(0.005)

def footprints():
    LIB.mkdir(parents=True, exist_ok=True)
    fx = lambda sz: f'(effects (font (size {sz} {sz}) (thickness {round(sz * 0.15, 3)})))'
    head = lambda name, descr, h, attr='smd': (f'(footprint "{name}" (version 20241229) (generator "niva_insole") (generator_version "9.0")\n(layer "F.Cu")\n'
        f'(descr {q(descr)})\n(attr {attr})\n'
        f'(property "Reference" "REF**" (at 0 {-h} 0) (layer "F.Fab") (uuid "{uid()}") {fx(1.0)})\n'
        f'(property "Value" {q(name)} (at 0 {h + 1.2} 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.8)})\n')
    # interdigitated FSR electrode
    a, b = comb_polys(); anchors = {1: (-PAIR, R_ACT - 0.2), 2: (PAIR, R_ACT - 0.2)}
    txt = head('FSR_Interdigitated_D12mm', 'Shunt-mode FSR electrode, 12 mm active, 0.3/0.3 mm comb; pads 1/2 are the two combs; '
               'close with FSR ink film on a spacer ring; the coverlay window deliberately exposes both combs', R_ACT + 2.0,
               'smd allow_soldermask_bridges')
    for num, poly in ((1, a), (2, b)):
        ax, ay = anchors[num]
        pts = ' '.join(f'(xy {fmt(x - ax)} {fmt(y - ay)})' for x, y in list(poly.exterior.coords)[:-1])
        txt += (f'(pad "{num}" smd custom (at {fmt(ax)} {fmt(ay)}) (size 0.25 0.25) (layers "F.Cu" "F.Mask") '
                f'(options (clearance outline) (anchor circle)) (primitives (gr_poly (pts {pts}) (width 0) (fill yes))) (uuid "{uid()}"))\n')
    txt += (f'(fp_circle (center 0 0) (end {R_ACT + 0.3} 0) (stroke (width 0) (type solid)) (fill yes) (layer "F.Mask") (uuid "{uid()}"))\n'
            f'(fp_circle (center 0 0) (end {R_ACT + 1.0} 0) (stroke (width 0.1) (type dash)) (fill no) (layer "F.Fab") (uuid "{uid()}"))\n'
            f'(fp_circle (center 0 0) (end {R_ACT + 1.2} 0) (stroke (width 0.05) (type solid)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n'
            f'(fp_text user "FSR film" (at 0 {-R_ACT - 0.9} 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.7)})\n)\n')
    (LIB / 'FSR_Interdigitated_D12mm.kicad_mod').write_text(txt)
    # PVDF film bond pads
    txt = head('PVDF_BondPads_2x6x2mm', 'Bond pads for a separately supplied PVDF film (lead tabs, conductive adhesive or crimp - '
               'process to select); pad 1 = signal, pad 2 = return', 5.5)
    for num, y in ((1, -1.4), (2, 1.4)):
        txt += f'(pad "{num}" smd rect (at 0 {y}) (size 6 2) (layers "F.Cu" "F.Mask") (uuid "{uid()}"))\n'
    txt += (f'(fp_rect (start -8 -4) (end 8 4) (stroke (width 0.1) (type dash)) (fill no) (layer "F.Fab") (uuid "{uid()}"))\n'
            f'(fp_rect (start -3.3 -2.7) (end 3.3 2.7) (stroke (width 0.05) (type solid)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n'
            f'(fp_text user "V1 PVDF film 16 x 8" (at 0 -4.8 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.7)})\n)\n')
    (LIB / 'PVDF_BondPads_2x6x2mm.kicad_mod').write_text(txt)
    # transition wire pads, numbered by pod J1 pin, placed in flex lane order
    txt = head('WirePads_1x10_P2.0mm_LaneOrder', 'Solder pads for a 10-core cable to the pod JST GH plug; pad number = GH '
               'position; physical order follows the flex lanes (silk shows the pin numbers)', 11.0)
    for k, (num, net) in enumerate(PADS):
        txt += f'(pad "{num}" smd rect (at 0 {fmt(-9.0 + 2.0 * k)}) (size 2 1.2) (layers "F.Cu" "F.Mask") (uuid "{uid()}"))\n'
        txt += f'(fp_text user "{num}" (at 2.1 {fmt(-9.0 + 2.0 * k)} 0) (layer "F.SilkS") (uuid "{uid()}") {fx(0.8)})\n'
    txt += f'(fp_rect (start -1.25 -10) (end 3.2 10) (stroke (width 0.05) (type solid)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n)\n'
    (LIB / 'WirePads_1x10_P2.0mm_LaneOrder.kicad_mod').write_text(txt)

# ------------------------------------------------------------------ schematic + project
def project(name, sch):
    pro = json.loads((ROOT / 'work/kicad_pro_template.json').read_text())
    pro['meta']['filename'] = name + '.kicad_pro'; pro['sheets'] = [[sch.uuid, 'Root']]
    base = pro['net_settings']['classes'][0]; d = dict(base)
    d.update(name='Default', track_width=TW, clearance=0.2, via_diameter=0.5, via_drill=0.25, priority=2147483647)
    pro['net_settings']['classes'] = [d]; pro['net_settings']['netclass_patterns'] = []
    pro['board']['design_settings']['rules'].update(min_clearance=0.15, min_track_width=0.1, min_via_diameter=0.45,
        min_through_hole_diameter=0.2, min_via_annular_width=0.1, min_copper_edge_clearance=0.3, min_hole_to_hole=0.25,
        min_hole_clearance=0.2)
    (IDIR / (name + '.kicad_pro')).write_text(json.dumps(pro, indent=2))

def schematic(side):
    name = f'NIVA-insole-{side}'; K.PROJECT = name; K.OUT = IDIR
    s = Sch(name, f'NIVA sensing insole flex | {ID[side][1]} | Rev A (H1)', 'A4', 1); s.path = '/' + s.uuid
    s.text(20, 18, f'NIVA SENSING INSOLE FLEX - {ID[side][1].upper()} - ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 2.0)
    for i, (p, (x, y, rot, where)) in enumerate(SENSORS.items()):
        pins = {'1': 'VEXC', '2': f'F{i + 1}_RAW'} if side == 'R' else {'1': f'F{i + 1}_RAW', '2': 'VEXC'}
        s.place('Device:R_Variable', f'FSR{i + 1}', f'{p} {where} (shunt FSR, 12 mm)', 40 + 30 * i, 60, pins,
                'NIVA_insole:FSR_Interdigitated_D12mm')
    s.place('Connector_Generic:Conn_01x02', 'J2', 'V1 PVDF FILM (signal, return)', 40, 110, {'1': 'PVDF_RAW', '2': 'GND'},
            'NIVA_insole:PVDF_BondPads_2x6x2mm')
    s.place('Device:R', 'R1', ID[side][0], 110, 110, {'1': 'GND', '2': 'INSERT_ID_RAW'}, 'Resistor_SMD:R_0603_1608Metric',
            extra={'MPN': f'0603 thin film {ID[side][0]} ({ID[side][1]} code)'})
    s.place('Connector_Generic:Conn_01x10', 'J1', 'CABLE TO POD J1 (JST GH 10)', 170, 100,
            {n: net for n, net in PADS}, 'NIVA_insole:WirePads_1x10_P2.0mm_LaneOrder')
    s.flag(140, 140, 'GND')
    s.text_block(20, 150, [
        'Each FSRn: drive comb to VEXC (pod excitation), sense comb to Fn_RAW (pod load resistor + filter to MCP3208, ratiometric).',
        'Five separate drive leads underfoot, joined to VEXC only at the above-collar transition (B.Cu) - no crossings underfoot.',
        f'R1 insert ID: V(ID) = VEXC x R1 / (10k + R1) with pod R30 = 10k 0.1 %. {ID[side][0]} = {ID[side][1]}.',
        'Right-medium 4.7k -> 0.320; left-medium 47k -> 0.825 of VEXC. The app must refuse a mismatched side.',
        'FSR response depends on the FSR ink film, spacer and lamination: characterise before any use of the numbers.'], 1.2)
    s.save('(sheet_instances (path "/" (page "1")))'); project(name, s)
    return s

# ------------------------------------------------------------------ layout (tracks, vias, outline, placement)
def offset(line, d):
    o = LineString(line).offset_curve(d, join_style='mitre', mitre_limit=4.0)
    c = list(o.coords)
    if math.dist(c[0], line[0]) > math.dist(c[-1], line[0]): c = c[::-1]
    return c

def layout():
    tracks, vias = [], []
    lane_pts = {}
    for key, pts in LANES.items():
        y_tab = TAB_Y[key]; y_tail = y_tab - 7.0
        full = pts + [(72.5, y_tab), (TAIL_X0, y_tail), (VIA_X, y_tail)]
        lane_pts[key] = full
        top, bot = offset(full, PAIR), offset(full, -PAIR)        # left of travel = +PAIR
        # tail runs +x, so the left offset is the upper (+Y) trace: sense (or PVDF signal)
        assert top[-1][1] > bot[-1][1]
        if key == 'PVDF':
            sig, ret = 'PVDF_RAW', 'GND'
            tracks.append((sig, 'F.Cu', [(57.5, V1[1] + 1.4), (59.3, V1[1] + 1.4), top[0]]))
            tracks.append((ret, 'F.Cu', [(57.5, V1[1] - 1.4), (59.3, V1[1] - 1.4), bot[0]]))
            tracks.append((sig, 'F.Cu', top + [(VIA_X + 2, top[-1][1]), (VIA_X + 8, PAD_Y['7']), (PAD_X, PAD_Y['7'])]))
            tracks.append((ret, 'F.Cu', bot + [(VIA_X + 2, bot[-1][1]), (VIA_X + 8, PAD_Y['8']), (PAD_X, PAD_Y['8'])]))
        else:
            n = list(SENSORS).index(key) + 1; pin = {1: '2', 2: '3', 3: '4', 4: '5', 5: '6'}[n]
            tracks.append((f'F{n}_RAW', 'F.Cu', top + [(VIA_X + 2, top[-1][1]), (VIA_X + 8, PAD_Y[pin]), (PAD_X, PAD_Y[pin])]))
            tracks.append(('VEXC', 'F.Cu', bot)); vias.append(('VEXC', VIA_X, bot[-1][1]))
    ys = sorted(v[2] for v in vias)
    tracks.append(('VEXC', 'B.Cu', [(VIA_X, ys[0]), (VIA_X, PAD_Y['1']), (PAD_X - 2.7, PAD_Y['1'])]))
    vias.append(('VEXC', PAD_X - 2.7, PAD_Y['1'])); tracks.append(('VEXC', 'F.Cu', [(PAD_X - 2.7, PAD_Y['1']), (PAD_X, PAD_Y['1'])]))
    r1 = (218.0, 12.0)                                                       # R1 at 90 deg: pin 2 up (+Y), pin 1 down
    tracks.append(('INSERT_ID_RAW', 'F.Cu', [(PAD_X, PAD_Y['9']), (r1[0], r1[1] + 0.8)]))
    tracks.append(('GND', 'F.Cu', [(PAD_X, PAD_Y['10']), (r1[0], r1[1] - 0.8)]))
    for y in (PAD_Y['8'], PAD_Y['10']): vias.append(('GND', PAD_X - 2.7, y))
    tracks.append(('GND', 'B.Cu', [(PAD_X - 2.7, PAD_Y['8']), (PAD_X - 2.7, PAD_Y['10'])]))
    # flex outline: sensor discs + lane corridors + V1 + heel tab + tail + transition, smoothed
    parts = [Point(x, y).buffer(R_ACT + 1.5, 64) for x, y, r, w in SENSORS.values()]
    parts += [LineString(p).buffer(1.5, cap_style='round', join_style='round') for p in lane_pts.values()]
    parts += [box(V1[0] - 4.5, V1[1] - 3.5, V1[0] + 6.0, V1[1] + 3.5), TAB, box(TAIL_X0 - 1, 13, TAIL_X1, 27)]
    tr = box(TR_X0, 8.5, TR_X1, 31.5).buffer(-2).buffer(2, 32)
    flex = unary_union(parts + [tr]).buffer(1.0, 32).buffer(-1.0, 32)
    assert flex.geom_type == 'Polygon', flex.geom_type
    flex = Polygon(flex.exterior, [h for h in flex.interiors if Polygon(h).area > 20]).simplify(0.01)
    ins = outline(); under = flex.intersection(box(-50, -50, 72.0, 300)).difference(box(69.5, 18, 80, 36))   # tab junction excluded
    assert under.difference(ins.buffer(-1.0)).area < 0.5, 'flex leaves the insole outline (1 mm margin)'
    place = {f'FSR{i + 1}': (x, y, r, 'F') for i, (x, y, r, w) in enumerate(SENSORS.values())}
    place.update({'J2': (V1[0], V1[1], 0, 'F'), 'J1': (PAD_X, 20.0, 0, 'F'), 'R1': (r1[0], r1[1], 90, 'F')})
    texts = [('NIVA INSOLE FLEX {side} REV A (H1)', 150.0, 22.0, 'F.SilkS', 1.2), ('ENGINEERING PROTOTYPE', 150.0, 18.0, 'F.SilkS', 1.0),
             ('FOLD UP HERE (LATERAL HEEL EDGE)', 83.0, 9.0, 'F.Fab', 1.0), ('SHOE COLLAR ~ HERE (FIT CHECK)', 170.0, 9.0, 'F.Fab', 1.0),
             ('STIFFENER 0.2 FR4 ON BACK - ABOVE COLLAR ONLY', 217.0, 5.5, 'F.Fab', 0.8)]
    texts += [(f'{p}', x, y + R_ACT + 2.6, 'F.Fab', 1.2) for p, (x, y, r, w) in SENSORS.items()]
    return dict(tracks=tracks, vias=vias, outline=[list(flex.exterior.coords)[:-1]] + [list(h.coords)[:-1] for h in flex.interiors],
                place=place, texts=texts, insole=list(ins.exterior.coords)[:-1],
                stiffener=[(TR_X0 + 0.5, 9.0), (TR_X1 - 0.5, 9.0), (TR_X1 - 0.5, 31.0), (TR_X0 + 0.5, 31.0)],
                area_mm2=round(flex.area, 1), underfoot_mm2=round(under.area, 1))

def mirror(lay):
    mx = lambda p: (96.0 - p[0], p[1])
    m = dict(lay)
    m['tracks'] = [(n, l, [mx(p) for p in pts]) for n, l, pts in lay['tracks']]
    m['vias'] = [(n, 96.0 - x, y) for n, x, y in lay['vias']]
    m['outline'] = [[mx(p) for p in ring] for ring in lay['outline']]
    m['place'] = {r: (96.0 - x, y, (360 - rot) % 360 if r.startswith('FSR') else rot, s) for r, (x, y, rot, s) in lay['place'].items()}
    m['texts'] = [(t, 96.0 - x, y, l, sz) for t, x, y, l, sz in lay['texts']]
    m['insole'] = [mx(p) for p in lay['insole']]; m['stiffener'] = [mx(p) for p in lay['stiffener']]
    return m

if __name__ == '__main__':
    IDIR.mkdir(parents=True, exist_ok=True); footprints()
    (IDIR / 'fp-lib-table').write_text('(fp_lib_table (version 7)\n  (lib (name "NIVA_insole")(type "KiCad")'
                                       '(uri "${KIPRJMOD}/NIVA_insole.pretty")(options "")(descr "NIVA insole flex footprints"))\n)\n')
    (IDIR / 'sym-lib-table').write_text('(sym_lib_table (version 7)\n)\n')
    lay = layout()
    for side, l in (('R', lay), ('L', mirror(lay))):
        s = schematic(side)
        l = dict(l); l['texts'] = [(t.replace('{side}', f'{side}-M'), x, y, ly, sz) for t, x, y, ly, sz in l['texts']]
        (ROOT / f'work/insole-layout-{side}.json').write_text(json.dumps(l))
        print(side, 'parts', len(s.parts), '| tracks', len(l['tracks']), '| vias', len(l['vias']),
              '| flex area', l['area_mm2'], 'mm2, underfoot', l['underfoot_mm2'], 'mm2')
