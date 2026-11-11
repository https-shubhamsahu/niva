"""NIVA PCB generator (KiCad 9 pcbnew python; run inside kicad/kicad:9.0).

  python3 build_niva_pcb.py place    <board>                 footprints, nets, outline, planes, keepouts + DSN
  (Freerouting, outside this script)  work-routing/<board>.dsn -> work-routing/<board>.ses
  python3 build_niva_pcb.py finalize <board> "<status>" [ses] import the routed session, add pours, stamp status

Boards: pod (4-layer controller board in the shin pod), cartridge (0.8 mm interconnect strip inside the
battery cartridge), dock (charging dock). Footprints, pad nets and symbol links always come from the
schematic netlist, never typed by hand. Placement and outlines come from niva_layout.py, which also
drives the FreeCAD enclosure, cartridge and dock, so boards and mechanics cannot drift apart.
"""
import sys, os, re, math, json
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

def zone(board, layers, pts, net=None, keepout=False, priority=0, name='', solid=False):
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
    z.SetThermalReliefSpokeWidth(mm(0.3))
    z.SetPadConnection(pcbnew.ZONE_CONNECTION_FULL if solid else pcbnew.ZONE_CONNECTION_THERMAL)
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
                fab_refs=('H1', 'H2', 'J1', 'J3', 'U5'), gnd='GND', title=(21.0, 56.0), pour_nets=('GND',)),
    'cartridge': dict(dir=E / 'cartridge', name='NIVA-cartridge', layers=2, t=L.STRIP['t'], place=L.CART_PLACE,
                poly=rect(L.STRIP['x0'], L.STRIP['y0'], L.STRIP['w'], L.STRIP['l']),
                libs={'NIVA_power': E / 'cartridge/NIVA_power.pretty'}, sheets={}, fab_refs=('F1', 'J1', 'J2', 'J3'),
                gnd=None, title=(31.55, 38.6)),
    'dock': dict(dir=E / 'dock', name='NIVA-dock', layers=2, t=1.6, place=L.DOCK_PLACE,
                poly=rect(D['pcb_x0'], D['pcb_y0'], D['pcb_w'], D['pcb_h']), libs={'NIVA_power': E / 'dock/NIVA_power.pretty'},
                sheets={}, fab_refs=('J1', 'J2'), gnd='GND', title=(D['pcb_x0'] + D['pcb_w'] / 2, D['pcb_y0'] + 2.0)),
}
def poly_outline(rings):
    def draw(board):
        for ring in rings:
            for p, q in zip(ring, ring[1:] + ring[:1]): seg(board, p, q)
    return draw
# Sensing insole flex (right / left medium): geometry from build_niva_insole_flex.py (host python + shapely)
INSOLE = {s: json.loads(f.read_text()) for s in 'RL' if (f := ROOT / f'work/insole-layout-{s}.json').exists()}
for s, lay in INSOLE.items():
    BOARDS[f'insole-{s}'] = dict(dir=E / 'insole', name=f'NIVA-insole-{s}', layers=2, t=0.12,
                                place={r: tuple(v) for r, v in lay['place'].items()}, outline=poly_outline(lay['outline']),
                                poly=lay['outline'][0], libs={'NIVA_insole': E / 'insole/NIVA_insole.pretty'}, sheets={},
                                fab_refs=('J1', 'J2', 'R1'), gnd=None, title=(150.0 if s == 'R' else -54.0, 26.0))
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
    elif key.startswith('insole'):
        lay = INSOLE[key[-1]]; LAY = {'F.SilkS': pcbnew.F_SilkS, 'F.Fab': pcbnew.F_Fab}
        for t, x, y, layer, size in lay['texts']: text(board, t, x, y, LAY[layer], size)
        for ring, name in ((lay['insole'], 'INSOLE OUTLINE (1:1 medium fit template)'), (lay['stiffener'], 'STIFFENER')):
            for p, q in zip(ring, ring[1:] + ring[:1]):
                g = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_SEGMENT); g.SetStart(K(*p)); g.SetEnd(K(*q))
                g.SetLayer(pcbnew.Dwgs_User); g.SetWidth(mm(0.15)); board.Add(g)
    elif key == 'dock':
        text(board, 'NIVA DOCK REV C.1', D['pcb_x0'] + 14, D['pcb_y0'] + 5, pcbnew.F_SilkS, 1.0)
        text(board, '+', D['pads'][0][0] + 3.0, D['pads'][0][1], pcbnew.F_SilkS, 1.0)
    board.SetFileName(str(b['pcb'])); pcbnew.SaveBoard(str(b['pcb']), board)
    board = pcbnew.LoadBoard(str(b['pcb']))           # reload so net classes and rules come from the .kicad_pro
    pcbnew.ZONE_FILLER(board).Fill(board.Zones()); pcbnew.SaveBoard(str(b['pcb']), board)
    relink_models(b); board = pcbnew.LoadBoard(str(b['pcb']))
    if b.get('pour_nets'):
        # fan-out first: every GND pad gets its own via to the In1 plane before any signal is routed, so the
        # autorouter sees GND as complete (through the plane) and routes signals around the vias
        gnd_fanout(board); pcbnew.SaveBoard(str(b['pcb']), board); relink_models(b); board = pcbnew.LoadBoard(str(b['pcb']))
    b['dsn'].parent.mkdir(exist_ok=True)
    assert pcbnew.ExportSpecctraDSN(board, str(b['dsn'])), 'DSN export failed'
    print(key, 'placed', len(comps), 'footprints,', len(nets), 'nets; DSN written')

def dsn_without(path, nets):
    """Hide pour-only nets from Freerouting: drop their network entry, class membership and plane. Their pins stay
    in the DSN as copper obstacles; finalize() connects them with pours on every layer plus fan-out vias."""
    t = path.read_text()
    for n in nets:
        e = re.escape(n)
        t = re.sub(r'\(net ' + e + r'\s*\(pins[^)]*\)\s*\)', '', t)
        t = re.sub(r'\(plane ' + e + r' \(polygon[^)]*\)\)', '', t)
        t = re.sub(r'(\(class [^()]*?)\s' + e + r'(?=[\s)])', r'\1', t)
    path.write_text(t)

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

for s, lay in INSOLE.items():
    HAND[f'insole-{s}'] = dict(tracks=[(n, l, 0.25, [tuple(p) for p in pts]) for n, l, pts in lay['tracks']],
                               vias=[tuple(v) for v in lay['vias']], via=(0.5, 0.25))

def hand_route(board, key):
    nets = board.GetNetsByName()
    net_of = lambda n: board.FindNet(n) if nets.has_key(n) else board.FindNet('/' + n)
    vd, vh = HAND[key].get('via', (0.6, 0.3))
    for net, layer, w, pts in HAND[key]['tracks']:
        ni = net_of(net); lay = board.GetLayerID(layer); assert ni, net
        for a, c in zip(pts, pts[1:]):
            t = pcbnew.PCB_TRACK(board); t.SetStart(K(*a)); t.SetEnd(K(*c)); t.SetWidth(mm(w)); t.SetLayer(lay)
            t.SetNet(ni); board.Add(t)
    for net, x, y in HAND[key]['vias']:
        v = pcbnew.PCB_VIA(board); v.SetPosition(K(x, y)); v.SetWidth(mm(vd)); v.SetDrill(mm(vh))
        v.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu); v.SetNet(net_of(net)); board.Add(v)

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

def gnd_fanout(board, net_name='GND', clear=0.127, margin=0.03, via=(0.5, 0.25)):
    """Give every SMD pad of a pour-only net its own via to the inner plane, at the nearest free spot.
    A spot is free when the via and its stub clear every other-net pad, track and via (KiCad HitTest), all holes by
    the hole-to-hole rule, the board edge and the antenna keep-out. Large pads (thermal pads) get a via in pad."""
    net = board.FindNet(net_name); nc = net.GetNetCode(); b = L.BOARD; k = L.ANTENNA_KEEPOUT
    vr, vh = via[0] / 2, via[1] / 2
    items = [(p, p.GetBoundingBox()) for p in board.GetPads() if p.GetNetCode() != nc]
    items += [(t, t.GetBoundingBox()) for t in board.GetTracks() if t.GetNetCode() != nc]
    holes = [(p.GetPosition(), max(p.GetDrillSize().x, p.GetDrillSize().y) / 2) for p in board.GetPads() if p.GetDrillSize().x > 0]
    holes += [(t.GetPosition(), t.GetDrillValue() / 2) for t in board.GetTracks() if t.GetClass() == 'PCB_VIA']
    def near(pt, r):
        return [it for it, bb in items if bb.GetLeft() - r <= pt.x <= bb.GetRight() + r and bb.GetTop() - r <= pt.y <= bb.GetBottom() + r]
    def inside(x, y):                                            # board frame, mm
        if not (b['x0'] + 0.65 <= x <= b['x0'] + b['w'] - 0.65 and b['y0'] + 0.65 <= y <= b['y0'] + b['h'] - 0.65): return False
        if any(math.hypot(x - cx, y - cy) < L.BOARD_NOTCH_R + 0.7 for cx, cy in L.CASE_SCREWS): return False
        return not (k['x0'] - 0.5 <= x <= k['x1'] + 0.5 and k['y0'] - 0.5 <= y <= k['y1'] + 1.5)
    def free_via(pt):
        acc = mm(vr + clear + margin)
        if any(it.HitTest(pt, acc) for it in near(pt, acc)): return False
        return all((pt - hp).EuclideanNorm() >= hr + mm(vh + 0.3) for hp, hr in holes)
    def free_stub(a, c, layer, w):
        n = max(2, int((c - a).EuclideanNorm() / mm(0.1)))
        for i in range(n + 1):
            q = pcbnew.VECTOR2I(int(a.x + (c.x - a.x) * i / n), int(a.y + (c.y - a.y) * i / n)); acc = mm(w / 2 + clear + margin)
            for it in near(q, acc):
                if it.IsOnLayer(layer) and it.HitTest(q, acc): return False
        return True
    added, failed = 0, []
    ends = [t.GetPosition() for t in board.GetTracks() if t.GetNetCode() == nc and t.GetClass() == 'PCB_VIA']
    ends += [e for t in board.GetTracks() if t.GetNetCode() == nc and t.GetClass() == 'PCB_TRACK' for e in (t.GetStart(), t.GetEnd())]
    pads = [p for p in board.GetPads() if p.GetNetCode() == nc and p.GetAttribute() in (pcbnew.PAD_ATTRIB_SMD, pcbnew.PAD_ATTRIB_CONN)
            and not any(p.HitTest(e) for e in ends)]                 # already wired (e.g. by a second routing pass)
    for pad in pads:
        pos = pad.GetPosition(); fp = pad.GetParentFootprint(); layer = pcbnew.F_Cu if pad.IsOnLayer(pcbnew.F_Cu) else pcbnew.B_Cu
        sz = pad.GetSize(); big = min(sz.x, sz.y) >= mm(0.9) and max(sz.x, sz.y) >= mm(0.9) and fp.GetReference().startswith('U')
        spot = pos if big and free_via(pos) else None       # thermal / large pad: via in pad when nothing runs beneath
        stub = False
        if spot is None:
            c = fp.GetPosition(); d = pos - c
            base = math.atan2(d.y, d.x) if d.EuclideanNorm() > mm(0.05) else 0.0
            ext = max(sz.x, sz.y) / 2 / 1e6
            w = 0.15 if min(sz.x, sz.y) < mm(0.4) else 0.2
            for dist in (ext + vr + 0.2, ext + vr + 0.4, ext + vr + 0.7, ext + vr + 1.0, ext + vr + 1.4, ext + vr + 1.9):
                for da in (0, 15, -15, 30, -30, 45, -45, 60, -60, 75, -75, 90, -90, 120, -120, 150, -150, 180):
                    a = base + math.radians(da)
                    cand = pos + pcbnew.VECTOR2I(mm(dist * math.cos(a)), mm(dist * math.sin(a)))
                    x, y = L.from_kicad(cand.x / 1e6, cand.y / 1e6)
                    if inside(x, y) and free_via(cand) and free_stub(pos, cand, layer, w): spot = cand; break
                if spot is not None: break
            stub = True
        if spot is None:
            # fallback: a straight or L-shaped stub on the pad's layer to an existing via of the net (<= 4 mm)
            gv = sorted((t.GetPosition() for t in board.GetTracks() if t.GetClass() == 'PCB_VIA' and t.GetNetCode() == nc),
                        key=lambda q: (q - pos).EuclideanNorm())
            w = 0.15; path = None
            for q in gv:
                if (q - pos).EuclideanNorm() > mm(4.0): break
                for mid in (None, pcbnew.VECTOR2I(q.x, pos.y), pcbnew.VECTOR2I(pos.x, q.y)):
                    pts = [pos, q] if mid is None else [pos, mid, q]
                    if all(free_stub(a, c, layer, w) for a, c in zip(pts, pts[1:])): path = pts; break
                if path: break
            if path is None: failed.append(fp.GetReference() + '.' + pad.GetNumber()); continue
            for a, c in zip(path, path[1:]):
                t = pcbnew.PCB_TRACK(board); t.SetStart(a); t.SetEnd(c); t.SetWidth(mm(w)); t.SetLayer(layer); t.SetNet(net)
                board.Add(t)
            added += 1; continue
        v = pcbnew.PCB_VIA(board); v.SetPosition(spot); v.SetWidth(mm(via[0])); v.SetDrill(mm(via[1]))
        v.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu); v.SetNet(net); board.Add(v); holes.append((spot, mm(vh)))
        if stub and spot != pos:
            t = pcbnew.PCB_TRACK(board); t.SetStart(pos); t.SetEnd(spot); t.SetWidth(mm(w)); t.SetLayer(layer); t.SetNet(net)
            board.Add(t)
        added += 1
    print(f'GND fan-out: {added} vias for {len(pads)} pads; no free spot for {failed}')
    return failed

def stitch_islands(board, net_name='GND', via=(0.5, 0.25), clear=0.127, margin=0.03):
    """After a fill: put a via into every pour island of the net that has none (islands that touch a pad the
    fan-out could not reach). Candidate points on a 0.1 mm grid inside the island, >= via radius from its edge,
    clear of other-net copper on every layer and of all holes."""
    net = board.FindNet(net_name); nc = net.GetNetCode(); vr, vh = via[0] / 2, via[1] / 2
    others = [t for t in list(board.GetPads()) + list(board.GetTracks()) if t.GetNetCode() != nc]
    holes = [(p.GetPosition(), max(p.GetDrillSize().x, p.GetDrillSize().y) / 2) for p in board.GetPads() if p.GetDrillSize().x > 0]
    holes += [(t.GetPosition(), t.GetDrillValue() / 2) for t in board.GetTracks() if t.GetClass() == 'PCB_VIA']
    vias = [t.GetPosition() for t in board.GetTracks() if t.GetClass() == 'PCB_VIA' and t.GetNetCode() == nc]
    added = 0
    for z in board.Zones():
        if z.GetNetCode() != nc or z.GetIsRuleArea(): continue
        for layer in z.GetLayerSet().CuStack():
            polys = z.GetFilledPolysList(layer)
            for i in range(polys.OutlineCount()):
                ch = polys.Outline(i)
                if any(ch.PointInside(v) for v in vias): continue
                bb = ch.BBox(); spot = None; step = mm(0.1)
                for yy in range(bb.GetY(), bb.GetY() + bb.GetHeight(), step):
                    for xx in range(bb.GetX(), bb.GetX() + bb.GetWidth(), step):
                        pt = pcbnew.VECTOR2I(xx, yy)
                        if not ch.PointInside(pt) or ch.SquaredDistance(pt) < mm(vr + 0.01) ** 2: continue
                        if any((pt - hp).EuclideanNorm() < hr + mm(vh + 0.3) for hp, hr in holes): continue
                        acc = mm(vr + clear + margin)
                        if any(o.HitTest(pt, acc) for o in others): continue
                        spot = pt; break
                    if spot is not None: break
                if spot is None: print('  island without a via spot on', board.GetLayerName(layer), bb.GetX() / 1e6, bb.GetY() / 1e6); continue
                v = pcbnew.PCB_VIA(board); v.SetPosition(spot); v.SetWidth(mm(via[0])); v.SetDrill(mm(via[1]))
                v.SetLayerPair(pcbnew.F_Cu, pcbnew.B_Cu); v.SetNet(net); board.Add(v)
                holes.append((spot, mm(vh))); vias.append(spot); added += 1
    print(f'island stitching: {added} vias')
    return added

def finalize(key, status, ses=None):
    """Import a routed Specctra session (if given), add GND pours on every copper layer, stamp the status."""
    b = BOARDS[key]; board = pcbnew.LoadBoard(str(b['pcb']))
    if ses == 'hand':
        hand_route(board, key)
    elif ses:
        assert pcbnew.ImportSpecctraSES(board, str(ses)), 'SES import failed'
        pcbnew.SaveBoard(str(b['pcb']), board)
        print(key, 'removed dangling segments:', remove_dangling(b['pcb'])); board = pcbnew.LoadBoard(str(b['pcb']))
    if ses and b.get('pour_nets'): gnd_fanout(board)          # re-fans any GND pad the router left without a via
    if ses and b['gnd']:
        gnd = board.FindNet(b['gnd'])
        layers = [pcbnew.F_Cu, pcbnew.B_Cu] + ([pcbnew.In2_Cu] if b['layers'] == 4 else [])
        for layer in layers: zone(board, [layer], b['poly'], gnd, name='GND_' + board.GetLayerName(layer), solid=bool(b.get('pour_nets')))
    x, y = b['title']
    for layer in (pcbnew.Cmts_User, pcbnew.F_Fab):
        t = pcbnew.PCB_TEXT(board); t.SetText(status); t.SetPosition(K(x, y)); t.SetLayer(layer)
        t.SetTextSize(V(0.6 if key == 'cartridge' else 0.9, 0.6 if key == 'cartridge' else 0.9)); t.SetTextThickness(mm(0.1))
        if key == 'cartridge': t.SetTextAngleDegrees(90)
        board.Add(t)
    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    if ses and b.get('pour_nets') and stitch_islands(board): pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    pcbnew.SaveBoard(str(b['pcb']), board)
    relink_models(b)
    print(key, 'finalized:', status)

if __name__ == '__main__':
    if sys.argv[1] == 'place': place(sys.argv[2])
    elif sys.argv[1] == 'strip': print('STRIPPED', strip_pass(sys.argv[2]))
    else: finalize(sys.argv[2], sys.argv[3], sys.argv[4] if len(sys.argv) > 4 else None)
