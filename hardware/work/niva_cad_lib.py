"""Geometry helpers and cartridge part builders shared by the pod (build_niva_cad_revC.py) and the
charging dock (build_niva_dock_cad.py). FreeCAD 1.x python; all coordinates in the pod frame (mm)."""
from pathlib import Path
import math, sys
import FreeCAD as A, Part
sys.path.insert(0, str(Path(__file__).parent))
import niva_layout as L

V = A.Vector
FONT = next((f for f in ['/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 'C:/Windows/Fonts/arialbd.ttf',
                         '/Library/Fonts/Arial Bold.ttf'] if Path(f).exists()), None)

# ------------------------------------------------------------------ geometry helpers
def rr(w, h, r, z, t, x=0, y=0):
    """Rounded rectangle prism: w x h at (x, y), corner radius r, from z to z + t."""
    r = min(r, w / 2 - 1e-3, h / 2 - 1e-3)
    p = [V(x + r, y, z), V(x + w - r, y, z), V(x + w, y + r, z), V(x + w, y + h - r, z),
         V(x + w - r, y + h, z), V(x + r, y + h, z), V(x, y + h - r, z), V(x, y + r, z)]
    c = [V(x + w - r, y + r, z), V(x + w - r, y + h - r, z), V(x + r, y + h - r, z), V(x + r, y + r, z)]
    s = math.sqrt(.5)
    mids = [V(c[0].x + r * s, c[0].y - r * s, z), V(c[1].x + r * s, c[1].y + r * s, z),
            V(c[2].x - r * s, c[2].y + r * s, z), V(c[3].x - r * s, c[3].y - r * s, z)]
    e = [Part.LineSegment(p[0], p[1]).toShape(), Part.Arc(p[1], mids[0], p[2]).toShape(),
         Part.LineSegment(p[2], p[3]).toShape(), Part.Arc(p[3], mids[1], p[4]).toShape(),
         Part.LineSegment(p[4], p[5]).toShape(), Part.Arc(p[5], mids[2], p[6]).toShape(),
         Part.LineSegment(p[6], p[7]).toShape(), Part.Arc(p[7], mids[3], p[0]).toShape()]
    return Part.Face(Part.Wire(e)).extrude(V(0, 0, t))
def box(x, y, z, w, h, t): return Part.makeBox(w, h, t, V(x, y, z))
def cyl(x, y, z, r, h): return Part.makeCylinder(r, h, V(x, y, z))
def prism_xz(pts, y0, length):
    """Polygon given as (x, z) pairs in the plane y = y0, extruded along +y."""
    w = Part.makePolygon([V(x, y0, z) for x, z in pts] + [V(pts[0][0], y0, pts[0][1])])
    return Part.Face(w).extrude(V(0, length, 0))
def prism_yz(pts, x0, length):
    w = Part.makePolygon([V(x0, y, z) for y, z in pts] + [V(x0, pts[0][0], pts[0][1])])
    return Part.Face(w).extrude(V(length, 0, 0))
def text_solid(s, size, x, y, z, depth, centre=True):
    if not FONT: return None
    faces = []
    for ch in Part.makeWireString(s, FONT, size, 0):
        if ch: faces.append(Part.makeFace(ch, 'Part::FaceMakerBullseye'))
    if not faces: return None
    sh = Part.makeCompound(faces); bb = sh.BoundBox
    sh.translate(V(x - (bb.XMin + bb.XLength / 2 if centre else bb.XMin), y - (bb.YMin + bb.YLength / 2), z))
    return sh.extrude(V(0, 0, depth))
def clean(s):
    s = s.removeSplitter()
    if s.ShapeType == 'Compound' and len(s.Solids) == 1: s = s.Solids[0]
    return s

# ------------------------------------------------------------------ battery cartridge (shared with the dock)
def cartridge_cup():
    C, T = L.CART, L.CART_TAB; cx, cy, cw, cl = C['cav']
    s = rr(C['cup_w'], C['cup_l'], 2, 0, C['cup_h'], C['cup_x0'], C['cup_y0'])
    s = s.cut(rr(cw, cl, 1, C['floor'], C['cup_h'], cx, cy))
    tab = rr(T['w'], T['l'] + 1.0, 1, 0, T['t'], T['x0'], T['y0'] - 1.0)
    s = s.fuse(tab.cut(cyl(*T['screw'], -0.1, 1.1, 2)))
    s = s.cut(box(12, C['cup_y0'] + 0.5, -0.1, 12, 2.0, 0.6))     # finger pull groove on the rear face
    for name, x, y in L.DOCK_PADS: s = s.cut(cyl(x, y, -0.1, 1.2, C['floor'] + 0.2))   # dock contact windows
    return clean(s)

def contact_xy():
    jx, jy = L.SPRING_CONTACTS_XY
    return [(jx + (i - 1.5) * 2.54, jy) for i in range(4)]

def cartridge_lid():
    C = L.CART; cx, cy, cw, cl = C['cav']
    s = rr(C['cup_w'] - 0.4, C['cup_l'] - 0.4, 1.8, C['lid_z'], C['lid_t'], C['cup_x0'] + 0.2, C['cup_y0'] + 0.2)
    s = s.fuse(rr(cw - 0.4, cl - 0.4, 0.8, C['lid_z'] - C['plug_t'], C['plug_t'], cx + 0.2, cy + 0.2))
    for x, y in contact_xy():
        s = s.cut(box(x - 0.9, y - 1.6, 8.8, 1.8, 3.2, 0.5)); s = s.cut(cyl(x, y, 7.0, 0.4, 2))
    return clean(s)

def contact_plates():
    return Part.makeCompound([box(x - 0.8, y - 1.5, 8.8, 1.6, 3.0, 0.4) for x, y in contact_xy()])

cell = lambda: rr(L.CELL['w'], L.CELL['l'], 1, L.CART['floor'], L.CELL['t'], *L.CELL_XY)     # max published size
def strip_pcb():
    S = L.STRIP; b = box(S['x0'], S['y0'], L.CART['floor'], S['w'], S['l'], S['t'])
    return clean(b.fuse(box(S['x0'] + 0.5, S['y0'] + 3, L.CART['floor'] + S['t'], S['w'] - 1.0, 2.2, 1.0)))   # polyfuse
