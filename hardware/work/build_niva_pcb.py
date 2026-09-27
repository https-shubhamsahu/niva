"""NIVA pod Rev C PCB generator (KiCad 9 pcbnew python; run inside kicad/kicad:9.0).

  python3 build_niva_pcb.py place   -> NIVA-pod.kicad_pcb with footprints, nets, outline, planes, keepouts
                                       + NIVA-pod.dsn for the autorouter
  (Freerouting, outside this script)  NIVA-pod.dsn -> NIVA-pod.ses
  python3 build_niva_pcb.py route   -> imports NIVA-pod.ses, adds outer GND pours, refills zones

Footprints, pad nets and symbol links come from the schematic netlist (exports/NIVA-pod.net), never
typed by hand. Placement and outline come from niva_layout.py, shared with the FreeCAD enclosure.
"""
import sys, os
from pathlib import Path
import pcbnew
sys.path.insert(0, str(Path(__file__).parent))
from sexputils import parse, find, allof
import niva_layout as L

ROOT = Path(__file__).resolve().parents[1]
E = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
PCB = E / 'NIVA-pod.kicad_pcb'; DSN = E / 'work-routing/NIVA-pod.dsn'; SES = E / 'work-routing/NIVA-pod.ses'
STOCK = next(Path(p) for p in [os.environ.get('KICAD9_FOOTPRINT_DIR', ''), ROOT / 'work/tools3d/kicad/share/kicad/footprints',
                                '/usr/share/kicad/footprints'] if p and Path(p, 'Resistor_SMD.pretty').exists())
mm = pcbnew.FromMM
V = lambda x, y: pcbnew.VECTOR2I(mm(x), mm(y))
def K(x, y): return V(*L.to_kicad(x, y))

# Library/project 3D models. KiCad stock models are downloaded into electronics/3dmodels;
# the ESP32 model is Espressif's own; *_ENVELOPE models are simplified stand-ins.
MODEL = {'ESP32-C3-MINI-1': 'ESP32-C3-MINI-1_Espressif.step',
         'TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm': 'TDFN-8-2x2mm_ENVELOPE.step',
         'SpringContact_1x04_P2.54mm_Vertical_SMD': 'NIVA_SpringContact_1x04_ENVELOPE.step'}

def netlist():
    a = parse((E / 'exports/NIVA-pod.net').read_text())
    comps = {}
    for c in allof(find(a, 'components'), 'comp'):
        sp = find(c, 'sheetpath')
        comps[find(c, 'ref')[1]] = dict(value=find(c, 'value')[1], footprint=find(c, 'footprint')[1],
                                       sheet=find(sp, 'names')[1], path=find(sp, 'tstamps')[1] + find(c, 'tstamps')[1])
    nets = {}
    for n in allof(find(a, 'nets'), 'net'):
        nets[find(n, 'name')[1]] = [(find(x, 'ref')[1], find(x, 'pin')[1]) for x in allof(n, 'node')]
    return comps, nets

def outline(board):
    """Rectangle whose four corners are replaced by concave notches around the enclosure screw bosses."""
    import math
    b = L.BOARD; x0, y0, x1, y1 = b['x0'], b['y0'], b['x0'] + b['w'], b['y0'] + b['h']; R = L.BOARD_NOTCH_R
    def seg(p, q):
        s = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_SEGMENT); s.SetStart(K(*p)); s.SetEnd(K(*q))
        s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(mm(0.1)); board.Add(s)
    def arc(p, m, q):
        s = pcbnew.PCB_SHAPE(board, pcbnew.SHAPE_T_ARC); s.SetArcGeometry(K(*p), K(*m), K(*q))
        s.SetLayer(pcbnew.Edge_Cuts); s.SetWidth(mm(0.1)); board.Add(s)
    pts = []   # for each notch: (point on horizontal edge, mid, point on vertical edge)
    for (cx, cy) in L.CASE_SCREWS:
        ey = y0 if cy < (y0 + y1) / 2 else y1; ex = x0 if cx < (x0 + x1) / 2 else x1
        hx = cx + math.copysign(math.sqrt(R * R - (ey - cy) ** 2), (x0 + x1) / 2 - cx)
        vy = cy + math.copysign(math.sqrt(R * R - (ex - cx) ** 2), (y0 + y1) / 2 - cy)
        a0, a1 = math.atan2(ey - cy, hx - cx), math.atan2(vy - cy, ex - cx)
        if abs(a1 - a0) > math.pi: a1 += 2 * math.pi if a1 < a0 else -2 * math.pi
        am = (a0 + a1) / 2
        pts.append(((hx, ey), (cx + R * math.cos(am), cy + R * math.sin(am)), (ex, vy)))
    bl, br, tl, tr = pts
    for n in pts: arc(*n)
    seg(bl[0], br[0]); seg(tl[0], tr[0]); seg(bl[2], tl[2]); seg(br[2], tr[2])

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

def board_poly(inset=0.0):
    b = L.BOARD
    return [(b['x0'] + inset, b['y0'] + inset), (b['x0'] + b['w'] - inset, b['y0'] + inset),
            (b['x0'] + b['w'] - inset, b['y0'] + b['h'] - inset), (b['x0'] + inset, b['y0'] + b['h'] - inset)]

def text(board, s, x, y, layer, size=0.8, angle=0):
    t = pcbnew.PCB_TEXT(board); t.SetText(s); t.SetPosition(K(x, y)); t.SetLayer(layer)
    t.SetTextSize(V(size, size)); t.SetTextThickness(mm(size * 0.15)); t.SetTextAngleDegrees(angle)
    if layer in (pcbnew.B_SilkS, pcbnew.B_Fab): t.SetMirrored(True)
    board.Add(t)

def relink_models():
    """Point every footprint's 3D model at electronics/3dmodels. Done on the saved file because pcbnew's
    Models() hands back copies in the python bindings."""
    import re
    txt = PCB.read_text()
    def sub(m):
        stem = Path(m.group(1)).stem
        name = MODEL.get(stem) or MODEL.get({'ESP32-C3-MINI-1': 'ESP32-C3-MINI-1'}.get(stem, ''), '') or Path(m.group(1)).name
        if stem.startswith('TDFN-8-1EP_2x2mm'): name = MODEL['TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm']
        return '(model "${KIPRJMOD}/3dmodels/' + name + '"'
    PCB.write_text(re.sub(r'\(model "([^"]+)"', sub, txt))

def place():
    comps, nets = netlist()
    board = pcbnew.NewBoard(str(PCB))
    board.SetCopperLayerCount(4)
    board.SetLayerType(pcbnew.In1_Cu, pcbnew.LT_POWER); board.SetLayerName(pcbnew.In1_Cu, 'In1.Cu')
    board.SetLayerType(pcbnew.In2_Cu, pcbnew.LT_SIGNAL); board.SetLayerName(pcbnew.In2_Cu, 'In2.Cu')
    board.GetDesignSettings().SetBoardThickness(mm(L.BOARD['t']))
    netinfo = {}
    for name in nets:
        ni = pcbnew.NETINFO_ITEM(board, name); board.Add(ni); netinfo[name] = ni
    pad_net = {(r, p): n for n, nodes in nets.items() for r, p in nodes}
    missing = [r for r in comps if r not in L.PLACE]
    assert not missing, f'unplaced components: {missing}'
    for ref, c in comps.items():
        lib, name = c['footprint'].split(':')
        path = E / 'NIVA.pretty' if lib == 'NIVA' else STOCK / (lib + '.pretty')
        fp = pcbnew.FootprintLoad(str(path), name)
        assert fp, c['footprint']
        fp.SetFPIDAsString(c['footprint']); fp.SetReference(ref); fp.SetValue(c['value'])
        fp.SetPath(pcbnew.KIID_PATH(c['path'])); fp.SetSheetname(c['sheet'].strip('/').split('/')[-1] or 'Root')
        fp.SetSheetfile({'/Controller/': 'NIVA-controller.kicad_sch'}.get(c['sheet'], 'NIVA-heel-and-indicator.kicad_sch'))
        x, y, rot, side = L.PLACE[ref]
        board.Add(fp)
        fp.SetPosition(K(x, y)); fp.SetOrientationDegrees(rot)
        if side == 'B': fp.Flip(fp.GetPosition(), pcbnew.FLIP_DIRECTION_TOP_BOTTOM)
        for pad in fp.Pads():
            n = pad_net.get((ref, pad.GetNumber()))
            if n: pad.SetNet(netinfo[n])
        if ref[0] in 'RCD' or ref in ('H1', 'H2', 'J1', 'J3'):   # dense 0603 rows: designators live on the assembly (fab) layer
            fp.Reference().SetLayer(pcbnew.B_Fab if side == 'B' else pcbnew.F_Fab)
            fp.Reference().SetTextSize(V(0.5, 0.5)); fp.Reference().SetTextThickness(mm(0.08))
        fp.Value().SetTextSize(V(0.5, 0.5)); fp.Value().SetTextThickness(mm(0.08))
        for m in fp.Models():
            fname = MODEL.get(name, Path(m.m_Filename).name)
            m.m_Filename = '${KIPRJMOD}/3dmodels/' + fname
    outline(board)
    gnd = netinfo['GND']
    # In1 = unbroken GND reference plane under everything. In2 is a routing layer (a +3V3 plane left
    # F/B too congested for the 0603 rows); it receives a GND pour after routing.
    zone(board, [pcbnew.In1_Cu], board_poly(), gnd, name='GND_PLANE')
    k = L.ANTENNA_KEEPOUT
    zone(board, [pcbnew.F_Cu, pcbnew.In1_Cu, pcbnew.In2_Cu, pcbnew.B_Cu],
         [(k['x0'], k['y0']), (k['x1'], k['y0']), (k['x1'], k['y1'] + 1), (k['x0'], k['y1'] + 1)],
         keepout=True, name='ANTENNA_KEEPOUT_ALL_LAYERS')
    # Silkscreen / fab annotation. The routing status is stamped by the 'route' stage.
    text(board, 'NIVA POD REV C', 21.0, 51.0, pcbnew.F_Fab, 1.0)
    text(board, 'ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 21.0, 12.2, pcbnew.F_Fab, 0.6)
    text(board, 'NIVA REV C', 21.0, 40.0, pcbnew.B_SilkS, 0.8)
    text(board, 'CARTRIDGE', 29.0, 24.6, pcbnew.B_SilkS, 0.8)
    text(board, 'SERVICE', 21.0, 31.4, pcbnew.B_SilkS, 0.8)
    # IMU axes (LSM6DSO32 package: +X/+Y per ST pin-1 marking; confirm after placement review)
    text(board, 'X>', 30.6, 45.4, pcbnew.F_SilkS, 0.8); text(board, 'Y^', 36.6, 38.9, pcbnew.F_SilkS, 0.8)
    board.SetFileName(str(PCB))
    pcbnew.SaveBoard(str(PCB), board)
    board = pcbnew.LoadBoard(str(PCB))          # reload so net classes and rules come from NIVA-pod.kicad_pro
    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    pcbnew.SaveBoard(str(PCB), board)
    relink_models(); board = pcbnew.LoadBoard(str(PCB))
    DSN.parent.mkdir(exist_ok=True)
    assert pcbnew.ExportSpecctraDSN(board, str(DSN)), 'DSN export failed'
    print('placed', len(comps), 'footprints,', len(nets), 'nets; DSN written')

def finalize(status, ses=None):
    """Stamp the routing status (the outline is drawn from niva_layout by place()). With a Specctra session the
    routed copper is imported and outer GND pours are added; without one the board stays unrouted
    (ratsnest only) and no decorative copper is drawn."""
    board = pcbnew.LoadBoard(str(PCB))
    if ses:
        assert pcbnew.ImportSpecctraSES(board, str(ses)), 'SES import failed'
        gnd = board.FindNet('GND')
        for layer, name in ((pcbnew.F_Cu, 'GND_TOP'), (pcbnew.In2_Cu, 'GND_IN2'), (pcbnew.B_Cu, 'GND_BOTTOM')):
            zone(board, [layer], board_poly(0.0), gnd, name=name)
    for layer, y in ((pcbnew.Cmts_User, 3.5), (pcbnew.F_Fab, 56.0)):
        t = pcbnew.PCB_TEXT(board); t.SetText(status); t.SetPosition(K(21.0, y)); t.SetLayer(layer)
        t.SetTextSize(V(0.9, 0.9)); t.SetTextThickness(mm(0.13)); board.Add(t)
    pcbnew.ZONE_FILLER(board).Fill(board.Zones())
    pcbnew.SaveBoard(str(PCB), board)
    relink_models()
    print('finalized:', status, '| tracks+vias', len(board.GetTracks()))

if __name__ == '__main__':
    if sys.argv[1] == 'place': place()
    else: finalize(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
