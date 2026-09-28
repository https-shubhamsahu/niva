"""NIVA PCB generator (KiCad 9 pcbnew python; run inside kicad/kicad:9.0).

  python3 build_niva_pcb.py place    <board>                 footprints, nets, outline, planes, keepouts + DSN
  (Freerouting, outside this script)  work-routing/<board>.dsn -> work-routing/<board>.ses
  python3 build_niva_pcb.py finalize <board> "<status>" [ses] import the routed session, add pours, stamp status

Boards: pod (4-layer controller board in the shin pod), cartridge (0.8 mm interconnect strip inside the
battery cartridge), dock (charging dock). Footprints, pad nets and symbol links always come from the
schematic netlist, never typed by hand. Placement and outlines come from niva_layout.py, which also
drives the FreeCAD enclosure, cartridge and dock, so boards and mechanics cannot drift apart.
"""
import sys, os, re, math
from pathlib import Path
import pcbnew, subprocess
sys.path.insert(0, str(Path(__file__).parent))
from sexputils import parse, find, allof
import niva_layout as L

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
STOCK = next(Path(p) for p in [os.environ.get('KICAD9_FOOTPRINT_DIR', ''), ROOT / 'work/tools3d/kicad/share/kicad/footprints',
                                '/usr/share/kicad/footprints'] if p and Path(p, 'Resistor_SMD.pretty').exists())
mm = pcbnew.FromMM
V = lambda x, y: pcbnew.VECTOR2I(mm(x), mm(y))
def K(x, y): return V(*L.to_kicad(x, y))

# Library/project 3D models live in electronics/3dmodels. KiCad stock models are downloaded there; the ESP32
# model is Espressif's own; *_ENVELOPE models are simplified stand-ins for unselected or model-less parts.
MODEL = {'ESP32-C3-MINI-1': 'ESP32-C3-MINI-1_Espressif.step',
         'TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm': 'TDFN-8-2x2mm_ENVELOPE.step',
         'SpringContact_1x04_P2.54mm_Vertical_SMD': 'NIVA_SpringContact_1x04_ENVELOPE.step',
         'SpringPins_1x03_P6.0mm_Vertical': 'NIVA_SpringPin_1x03_ENVELOPE.step'}

def rect(x0, y0, w, h): return [(x0, y0), (x0 + w, y0), (x0 + w, y0 + h), (x0, y0 + h)]

def notched_outline(board):
    """Pod board: rectangle whose corners are concave notches around the enclosure screw bosses."""
    b = L.BOARD; x0, y0, x1, y1 = b['x0'], b['y0'], b['x0'] + b['w'], b['y0'] + b['h']; R = L.BOARD_NOTCH_R
    pts = []   # per notch: (point on horizontal edge, arc mid, point on vertical edge)
    for (cx, cy) in L.CASE_SCREWS:
        ey = y0 if cy < (y0 + y1) / 2 else y1; ex = x0 if cx < (x0 + x1) / 2 else x1
        hx = cx + math.copysign(math.sqrt(R * R - (ey - cy) ** 2), (x0 + x1) / 2 - cx)
        vy = cy + math.copysign(math.sqrt(R * R - (ex - cx) ** 2), (y0 + y1) / 2 - cy)
        a0, a1 = math.atan2(ey - cy, hx - cx), math.atan2(vy - cy, ex - cx)
        if abs(a1 - a0) > math.pi: a1 += 2 * math.pi if a1 < a0 else -2 * math.pi
        am = (a0 + a1) / 2
        pts.append(((hx, ey), (cx + R * math.cos(am), cy + R * math.sin(am)), (ex, vy)))
    bl, br, tl, tr = pts
    for n in pts: arc(board, *n)
    seg(board, bl[0], br[0]); seg(board, tl[0], tr[0]); seg(board, bl[2], tl[2]); seg(board, br[2], tr[2])

def seg(board, p, q):
    s = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_SEGMENT); s.SetStart(K(*p)); s.SetEnd(K(*q))
    s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(mm(0.1)); board.Add(s)
def arc(board, p, m, q):
    s = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_ARC); s.SetArcGeometry(K(*p), K(*m), K(*q))
    s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(mm(0.1)); board.Add(s)
def rect_outline(pts):
    def draw(board):
        for i in range(4): seg(board, pts[i], pts[(i + 1) % 4])
    return draw

def zone(board, layers, pts, net=None, keepout=False, priority=0, name=''):
    z = pcbnew.ZONE(board)
    if keepout:
        z.SetIsRuleArea(True); z.SetDoNotAllowCopperPour(True); z.SetDoNotAllowTracks(True)
        z.SetDoNotAllowVias(True); z.SetDoNotAllowPads(False); z.SetDoNotAllowFootprints(False)
    ls = pcbnew.LSET()
    for l in layers: ls.AddLayer(l)
    z.SetLayerSet(ls)
    if net: z.SetNet(net)
    z.SetAssignedPriority(priority); z.SetZoneName(name)
    z.SetMinThickness(mm(0.2)); z.SetLocalClearance(mm(0.2)); z.SetThermalReliefGap(mm(0.25))
    z.SetThermalReliefSpokeWidth(mm(0.3)); z.SetPadConnection(pcbnew.ZONE_CONNECTION_THERMAL)
    o = z.Outline(); o.NewOutline()
    for p in pts: o.Append(K(*p))
    board.Add(z); return z

def text(board, s, x, y, layer, size=0.8, angle=0):
    t = pcbnew.PCB_TEXT(board); t.SetText(s); t.SetPosition(K(x, y)); t.SetLayer(layer)
    t.SetTextSize(V(size, size)); t.SetTextThickness(mm(size * 0.15)); t.SetTextAngleDegrees(angle)
    if layer in (pcbnew.B_SilkS, pcbnew.B_Fab): t.SetMirrored(True)
    board.Add(t)

# ------------------------------------------------------------------ board definitions
D = L.DOCK
BOARDS = {
    'pod': dict(dir=E, name='NIVA-pod', layers=4, t=L.BOARD['t'], place=L.PLACE, outline=notched_outline,
                poly=rect(L.BOARD['x0'], L.BOARD['y0'], L.BOARD['w'], L.BOARD['h']), libs={'NIVA': E / 'NIVA.pretty'},
                sheets={'/Controller/': 'NIVA-controller.kicad_sch', '/Heel and indicator/': 'NIVA-heel-and-indicator.kicad_sch'},
                fab_refs=('H1', 'H2', 'J1', 'J3', 'U5'), gnd='GND', title=(21.0, 56.0)),
    'cartridge': dict(dir=E / 'cartridge', name='NIVA-cartridge', layers=2, t=L.STRIP['t'], place=L.CART_PLACE,
                poly=rect(L.STRIP['x0'], L.STRIP['y0'], L.STRIP['w'], L.STRIP['l']),
                libs={'NIVA_power': E / 'cartridge/NIVA_power.pretty'}, sheets={}, fab_refs=('F1', 'J1', 'J2', 'J3'),
                gnd=None, title=(31.55, 38.6)),
    'dock': dict(dir=E / 'dock', name='NIVA-dock', layers=2, t=1.6, place=L.DOCK_PLACE,
                poly=rect(D['pcb_x0'], D['pcb_y0'], D['pcb_w'], D['pcb_h']), libs={'NIVA_power': E / 'dock/NIVA_power.pretty'},
                sheets={}, fab_refs=('J1', 'J2'), gnd='GND', title=(D['pcb_x0'] + D['pcb_w'] / 2, D['pcb_y0'] + 2.0)),
}
for b in BOARDS.values():
    b.setdefault('outline', rect_outline(b['poly']))
    b['pcb'] = b['dir'] / (b['name'] + '.kicad_pcb'); b['net'] = b['dir'] / 'exports' / (b['name'] + '.net')
    b['dsn'] = E / 'work-routing' / (b['name'] + '.dsn')

def netlist(b):
    a = parse(b['net'].read_text())
    comps = {}
    for c in allof(find(a, 'components'), 'comp'):
        sp = find(c, 'sheetpath')
        comps[find(c, 'ref')[1]] = dict(value=find(c, 'value')[1], footprint=find(c, 'footprint')[1],
                                       sheet=find(sp, 'names')[1], path=find(sp, 'tstamps')[1] + find(c, 'tstamps')[1])
    nets = {find(n, 'name')[1]: [(find(x, 'ref')[1], find(x, 'pin')[1]) for x in allof(n, 'node')]
            for n in allof(find(a, 'nets'), 'net')}
    return comps, nets

def relink_models(b):
    """Point every footprint's 3D model at electronics/3dmodels (on the saved file: pcbnew's Models() returns copies)."""
    rel = '${KIPRJMOD}/3dmodels/' if b['dir'] == E else '${KIPRJMOD}/../3dmodels/'
    def sub(m):
        stem = Path(m.group(1)).stem
        name = MODEL.get(stem) or Path(m.group(1)).name
        if stem.startswith('TDFN-8-1EP_2x2mm'): name = MODEL['TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm']
        if stem.startswith('ESP32-C3-MINI-1'): name = MODEL['ESP32-C3-MINI-1']
        return '(model "' + rel + name + '"'
    b['pcb'].write_text(re.sub(r'\(model "([^"]+)"', sub, b['pcb'].read_text()))

def place(key):
    b = BOARDS[key]; comps, nets = netlist(b)
    board = pcbnew.NewBoard(str(b['pcb']))
    board.SetCopperLayerCount(b['layers'])
    if b['layers'] == 4:
        board.SetLayerType(pcbnew.In1_Cu, pcbnew.LT_POWER); board.SetLayerName(pcbnew.In1_Cu, 'In1.Cu')
        board.SetLayerType(pcbnew.In2_Cu, pcbnew.LT_SIGNAL); board.SetLayerName(pcbnew.In2_Cu, 'In2.Cu')
    board.GetDesignSettings().SetBoardThickness(mm(b['t']))
    netinfo = {}
    for name in nets:
        ni = pcbnew.NETINFO_ITEM(board, name); board.Add(ni); netinfo[name] = ni
    pad_net = {(r, p): n for n, nodes in nets.items() for r, p in nodes}
    missing = [r for r in comps if r not in b['place']]
    assert not missing, f'unplaced components: {missing}'
    for ref, c in comps.items():
        lib, name = c['footprint'].split(':')
        fp = pcbnew.FootprintLoad(str(b['libs'].get(lib, STOCK / (lib + '.pretty'))), name)
        assert fp, c['footprint']
        fp.SetFPIDAsString(c['footprint']); fp.SetReference(ref); fp.SetValue(c['value'])
        fp.SetPath(pcbnew.KIID_PATH(c['path'])); fp.SetSheetname(c['sheet'].strip('/').split('/')[-1] or 'Root')
        fp.SetSheetfile(b['sheets'].get(c['sheet'], b['name'] + '.kicad_sch'))
        x, y, rot, side = b['place'][ref]
        board.Add(fp); fp.SetPosition(K(x, y)); fp.SetOrientationDegrees(rot)
        if side == 'B': fp.Flip(fp.GetPosition(), pcbnew.FLIP_DIRECTION_TOP_BOTTOM)
        for pad in fp.Pads():
            n = pad_net.get((ref, pad.GetNumber()))
            if n: pad.SetNet(netinfo[n])
        if ref[0] in 'RCDFQH' or ref in b['fab_refs']:       # dense passives + holes: designators on the assembly (fab) layer
            fp.Reference().SetLayer(pcbnew.B_Fab if side == 'B' else pcbnew.F_Fab)
            fp.Reference().SetTextSize(V(0.5, 0.5)); fp.Reference().SetTextThickness(mm(0.08))
        fp.Value().SetTextSize(V(0.5, 0.5)); fp.Value().SetTextThickness(mm(0.08))
    b['outline'](board)
    if key == 'pod':
        # In1 = unbroken GND reference plane under everything; In2 routes signals and gets a GND pour later.
        zone(board, [pcbnew.In1_Cu], b['poly'], netinfo['GND'], name='GND_PLANE')
        k = L.ANTENNA_KEEPOUT
        zone(board, [pcbnew.F_Cu, pcbnew.In1_Cu, pcbnew.In2_Cu, pcbnew.B_Cu],
             rect(k['x0'], k['y0'], k['x1'] - k['x0'], k['y1'] + 1 - k['y0']), keepout=True, name='ANTENNA_KEEPOUT_ALL_LAYERS')
        text(board, 'NIVA POD REV C', 21.0, 51.0, pcbnew.F_Fab, 1.0)
        text(board, 'NIVA REV C', 21.0, 40.0, pcbnew.B_SilkS, 0.8)
        text(board, 'CARTRIDGE', 29.0, 24.6, pcbnew.B_SilkS, 0.8)
        text(board, 'SERVICE', 21.0, 31.4, pcbnew.B_SilkS, 0.8)
        # IMU axes (LSM6DSO32 package: +X/+Y per ST pin-1 marking; confirm in placement review)
        text(board, 'X>', 30.6, 45.4, pcbnew.F_SilkS, 0.8); text(board, 'Y^', 36.6, 38.9, pcbnew.F_SilkS, 0.8)
    elif key == 'dock':
        text(board, 'NIVA DOCK REV C.1', D['pcb_x0'] + 14, D['pcb_y0'] + 5, pcbnew.F_SilkS, 1.0)
        text(board, '+', D['pads'][0][0] + 3.0, D['pads'][0][1], pcbnew.F_SilkS, 1.0)
    board.SetFileName(str(b['pcb'])); pcbnew.SaveBoard(str(b['pcb']), board)
    board = pcbnew.LoadBoard(str(b['pcb']))           # reload so net classes and rules come from the .kicad_pro
    pcbnew.ZONE_FILLER(board).Fill(board.Zones()); pcbnew.SaveBoard(str(b['pcb']), board)
    relink_models(b); board = pcbnew.LoadBoard(str(b['pcb']))
    b['dsn'].parent.mkdir(exist_ok=True)
    assert pcbnew.ExportSpecctraDSN(board, str(b['dsn'])), 'DSN export failed'
    print(key, 'placed', len(comps), 'footprints,', len(nets), 'nets; DSN written')

# Hand route for the 3.4 mm cartridge strip (four nets; the autorouter cannot hold the edge clearance there).
# Pod-frame coordinates. Top channel: CELL_P at x 32.6, PACK_P at x 32.0 (0.3 mm tracks, 0.15 mm gaps);
# NTC and PACK_N drop to the underside, where only the dock pads live.
HAND = {'cartridge': dict(
    tracks=[('/CELL_P', 'F.Cu', 0.3, [(30.95, 36.8), (32.6, 36.8), (32.6, 11.16), (30.95, 11.16)]),
            ('/PACK_P', 'F.Cu', 0.3, [(30.95, 13.04), (32.0, 13.04), (32.0, 24.95), (30.95, 24.95), (30.95, 26.65)]),
            ('/PACK_P', 'B.Cu', 0.3, [(32.0, 14.2), (31.55, 12.0)]),
            ('/NTC', 'F.Cu', 0.2, [(30.95, 35.0), (32.0, 35.0), (32.0, 34.1)]),
            ('/NTC', 'B.Cu', 0.2, [(32.0, 34.1), (30.2, 32.3), (30.2, 18.0), (31.55, 18.0)]),
            ('/PACK_N', 'F.Cu', 0.3, [(30.95, 33.2), (30.95, 28.35), (32.0, 28.35)]),
            ('/PACK_N', 'B.Cu', 0.3, [(32.0, 28.35), (32.0, 24.0), (31.55, 24.0)])],
    vias=[('/PACK_P', 32.0, 14.2), ('/NTC', 32.0, 34.1), ('/PACK_N', 32.0, 28.35)])}

def hand_route(board, key):
    for net, layer, w, pts in HAND[key]['tracks']:
        ni = board.FindNet(net); lay = board.GetLayerID(layer)
        for a, c in zip(pts, pts[1:]):
            t = pcbnew.PCB_TRACK(board); t.SetStart(K(*a)); t.SetEnd(K(*c)); t.SetWidth(mm(w)); t.SetLayer(lay)
            t.SetNet(ni); board.Add(t)
    for net, x, y in HAND[key]['vias']:
        v = pcbnew.PCB_VIA(board); v.SetPosition(K(x, y)); v.SetWidth(mm(0.6)); v.SetDrill(mm(0.3))
        v.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu); v.SetNet(board.FindNet(net)); board.Add(v)

def strip_pass(path):
    """One pass: delete track segments with an unconnected end. Returns the number removed."""
    board = pcbnew.LoadBoard(str(path)); board.BuildConnectivity(); conn = board.GetConnectivity()
    dead = [t for t in board.GetTracks() if t.GetClass() == 'PCB_TRACK' and conn.TestTrackEndpointDangling(t, False)]
    for t in dead: board.Remove(t)
    if dead: pcbnew.SaveBoard(str(path), board)
    return len(dead)

def remove_dangling(path):
    """Delete autorouter stubs, repeated until none remain. pcbnew's SWIG proxies go stale after Remove(),
    so each pass runs in a fresh interpreter."""
    removed = 0
    while True:
        out = subprocess.run([sys.executable, __file__, 'strip', str(path)], capture_output=True, text=True, check=True)
        n = int(re.search(r'STRIPPED (\d+)', out.stdout).group(1)); removed += n
        if not n: return removed

def finalize(key, status, ses=None):
    """Import a routed Specctra session (if given), add GND pours on every copper layer, stamp the status."""
    b = BOARDS[key]; board = pcbnew.LoadBoard(str(b['pcb']))
    if ses == 'hand':
        hand_route(board, key)
    elif ses:
        assert pcbnew.ImportSpecctraSES(board, str(ses)), 'SES import failed'
        pcbnew.SaveBoard(str(b['pcb']), board)
        print(key, 'removed dangling segments:', remove_dangling(b['pcb'])); board = pcbnew.LoadBoard(str(b['pcb']))
    if ses and b['gnd']:
        gnd = board.FindNet(b['gnd'])
        layers = [pcbnew.F_Cu, pcbnew.B_Cu] + ([pcbnew.In2_Cu] if b['layers'] == 4 else [])
        for layer in layers: zone(board, [layer], b['poly'], gnd, name='GND_' + board.GetLayerName(layer))
    x, y = b['title']
    for layer in (pcbnew.Cmts_User, pcbnew.F_Fab):
        t = pcbnew.PCB_TEXT(board); t.SetText(status); t.SetPosition(K(x, y)); t.SetLayer(layer)
        t.SetTextSize(V(0.6 if key == 'cartridge' else 0.9, 0.6 if key == 'cartridge' else 0.9)); t.SetTextThickness(mm(0.1))
        if key == 'cartridge': t.SetTextAngleDegrees(90)
        board.Add(t)
    pcbnew.ZONE_FILLER(board).Fill(board.Zones()); pcbnew.SaveBoard(str(b['pcb']), board)
    relink_models(b)
    print(key, 'finalized:', status)

if __name__ == '__main__':
    if sys.argv[1] == 'place': place(sys.argv[2])
    elif sys.argv[1] == 'strip': print('STRIPPED', strip_pass(sys.argv[2]))
    else: finalize(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
