"""Protected Steps 3D renders (Blender 4.5+/5.x, headless, one scene rendered at a time):

  blender -b --factory-startup -P render_protected_steps.py -- [--only PS01,PS03] [--preview]

Geometry (nothing modelled by eye where an engineering file exists):
  * Rev C.1 pod parts       hardware/work/niva-meshes/*_R.stl (unchanged Rev C.1 FreeCAD generator)
  * Rev C.1 PCBA            .../electronics/exports/pcb/NIVA-pod-PCBA.glb (KiCad), colour fix from build_niva_scenes.py
  * Rev C.2 mounts          NIVA-RevC2-protected-steps/work/meshes/*.stl (build_ps_mounts.py)
  * interim cabinet         NIVA-RevC2-protected-steps/interim-cabinet/meshes/*.stl (build_interim_cabinet.py), with
                            labelled DUMMY board blocks sized from PLACEHOLDER parameters
  * leg and shoe            neutral mannequin stand-ins (no anthropometric or footwear data); the shoe plan outline is
                            the 1:1 medium insole fit template offset outward
Materials, lights, camera helpers and the KiCad GLB colour fix are executed from the Rev C.1 scene script
(hardware/work/build_niva_scenes.py) so these renders match the existing set.
Raw renders go to NIVA-RevC2-protected-steps/renders-work/raw/; caption_ps_renders.py adds the caption band.
"""
import ast, bpy, bmesh, json, math, re, sys
from pathlib import Path
from mathutils import Vector, Matrix

HW = Path('/home/shubh/_Active_Projects/niva-pcbway/hardware')
PKG = HW / 'outputs/NIVA-RevC2-protected-steps'
RAW = PKG / 'renders-work/raw'; RAW.mkdir(parents=True, exist_ok=True)
SRC = HW / 'work/build_niva_scenes.py'
argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
PREVIEW = '--preview' in argv
ONLY = argv[argv.index('--only') + 1].split(',') if '--only' in argv else None

# ---- pull helper definitions out of the Rev C.1 scene script (definitions only; its scenes are not built)
tree = ast.parse(SRC.read_text())
WANT_FN = {'srgb', 'mat', 'import_stl', 'link', 'new_coll', 'smooth', 'import_pcba', 'classify_components', 'band',
           'studio', 'camera', 'svg_paths', 'sample_path'}
WANT_AS = {'NAVY', 'M', 'FIN', 'PART_MAT'}
nodes = []
for n in tree.body:
    if isinstance(n, ast.FunctionDef) and n.name in WANT_FN: nodes.append(n)
    elif isinstance(n, ast.Assign):
        names = {getattr(t, 'id', None) for t in n.targets} | {getattr(e, 'id', None) for t in n.targets for e in getattr(t, 'elts', [])}
        if names & WANT_AS: nodes.append(n)
bpy.ops.wm.read_factory_settings(use_empty=True)
G = globals()
G.update(dict(ROOT=HW, OUT=HW / 'outputs/NIVA-3D-engineering-prototype', MM=0.001, PREVIEW=PREVIEW))
order = sorted(nodes, key=lambda n: (0 if isinstance(n, ast.FunctionDef) else 1, n.lineno))
exec(compile(ast.Module(body=[n for n in order if isinstance(n, ast.FunctionDef)], type_ignores=[]), str(SRC), 'exec'), G)
exec(compile(ast.Module(body=[n for n in order if not isinstance(n, ast.FunctionDef)], type_ignores=[]), str(SRC), 'exec'), G)
MM = 0.001
M.update({
    'skin':    mat('Mannequin form (neutral matte)', '#C9B8A6', 0.65, sss=0.05),
    'stand':   mat('Display stand', '#2B3238', 0.5),
    'shoe':    mat('Shoe form upper (stand-in, dark leather-like)', '#3A3430', 0.55),
    'sole':    mat('Shoe form sole (stand-in)', '#22201E', 0.8),
    'lining':  mat('Shoe form lining', '#8C7E70', 0.8),
    'perf':    mat('DUMMY perfboard (phenolic)', '#B5652B', 0.6),
    'devpcb':  mat('DUMMY dev board (black mask)', '#151719', 0.35),
    'oledpcb': mat('DUMMY OLED module (blue mask)', '#1F4E8C', 0.35),
    'glass':   mat('DUMMY OLED glass', '#050608', 0.08, coat=0.6),
    'mpupcb':  mat('DUMMY GY-521 (blue mask)', '#1C5DA8', 0.35),
    'cable':   mat('Insole cable (black tape)', '#111213', 0.5),
    'acrylic': mat('Clear acrylic pane', '#F4FAFF', 0.04, transmission=1.0, ior=1.49),
    'petg_teal': mat('PETG teal (printed, satin)', '#0B6F79', 0.42, coat=0.1),
})
LIBPCB = new_coll('LIB_PCBA_KiCad'); LIBPCB.hide_render = True
G['LIBPCB'] = LIBPCB

def setup_render(scene, res=(1800, 1200)):
    r = scene.render; r.engine = 'CYCLES'; r.resolution_x, r.resolution_y = res
    r.resolution_percentage = 35 if PREVIEW else 100
    scene.cycles.use_denoising = True; scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    scene.cycles.samples = 16 if PREVIEW else 80; scene.cycles.device = 'CPU'; r.film_transparent = False
    scene.view_settings.view_transform = 'AgX'; scene.view_settings.look = 'None'; scene.view_settings.exposure = -1.6
    r.image_settings.file_format = 'PNG'
    scene.unit_settings.system = 'METRIC'; scene.unit_settings.length_unit = 'MILLIMETERS'

def stl(path, name, material, coll, matrix=Matrix.Identity(4)):
    o = import_stl(path); o.name = name
    o.data.transform(o.matrix_basis); o.matrix_basis = Matrix.Identity(4)   # Blender 5.x keeps the STL scale on the object
    o.data.materials.clear(); o.data.materials.append(M[material]); smooth(o)
    link(o, coll); o.matrix_world = matrix; o['source'] = str(path.relative_to(HW)); return o

POD = HW / 'work/niva-meshes'; NEW = PKG / 'work/meshes'; CAB = PKG / 'interim-cabinet/meshes'
POD_PARTS = [('01_RearHousing_R', 'petg_navy'), ('02_FrontCover_R', 'petg_pale'), ('07_Button_TPU_R', 'tpu_teal'),
             ('08_LightWindow_Clear_R', 'clear')]
INNER_PARTS = [('03_BatteryCartridgeCup_R', 'petg_cart'), ('04_BatteryCartridgeLid_R', 'petg_cart'),
               ('Cell_LP502030_MAXSIZE_R', 'envelope'), ('CartridgeStripPCB_R', 'strip_pcb'),
               ('ContactPlates_R', 'brass'), ('09_SeamGasket_TPU_R', 'gasket')]

def pod_group(coll, M_world, explode=None, inner=False, extra=(), pcba=False):
    """Rev C.1 pod (pod frame, mm) placed by a 4x4 matrix in metres; explode = {name prefix: (dx, dy, dz) mm}."""
    ex = explode or {}
    def off(n): return Vector(next((v for k, v in ex.items() if n.startswith(k)), (0, 0, 0))) * MM
    objs = []
    for n, m in POD_PARTS + (INNER_PARTS if inner else []):
        objs.append(stl(POD / f'{n}.stl', n + '@' + coll.name, m, coll, M_world @ Matrix.Translation(off(n))))
    for path, n, m in extra:
        objs.append(stl(path, n + '@' + coll.name, m, coll, M_world @ Matrix.Translation(off(n))))
    if pcba:
        if not G.get('_pcba'):
            G['_pcba'] = import_pcba()[1]
        base_m = M_world @ Matrix.Translation(Vector((0, 0, 11.8)) * MM + off('PCB'))
        for o in G['_pcba']:
            if o.type != 'MESH': continue
            d = o.copy(); link(d, coll); d.parent = None; d.matrix_world = base_m @ o.matrix_world
            objs.append(d)
    return objs

def lathe(name, profile, coll, material, segs=96, sx=1.0, sy=1.0):
    """Surface of revolution about world Z from (radius, z) pairs in mm; sx/sy squash the section."""
    me = bpy.data.meshes.new(name); bm = bmesh.new(); rings = []
    for r, z in profile:
        rings.append([bm.verts.new((sx * r * math.cos(2 * math.pi * i / segs) * MM, sy * r * math.sin(2 * math.pi * i / segs) * MM, z * MM))
                      for i in range(segs)])
    for a, b in zip(rings, rings[1:]):
        for i in range(segs):
            bm.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); o.data.materials.append(M[material]); link(o, coll)
    for p in me.polygons: p.use_smooth = True
    return o

def pod_to_world(origin_mm, x_axis, y_axis, z_axis):
    R = Matrix(((x_axis[0], y_axis[0], z_axis[0], 0), (x_axis[1], y_axis[1], z_axis[1], 0),
                (x_axis[2], y_axis[2], z_axis[2], 0), (0, 0, 0, 1)))
    return Matrix.Translation(Vector(origin_mm) * MM) @ R @ Matrix.Scale(1.0, 4)
def wpt(Mw, p):            # pod-frame point (mm) -> world (mm), for band paths
    return tuple(((Mw @ (Vector(p) * MM)) / MM))

def catmull(pts, n=10):
    P = [Vector(p) for p in pts]; P = [P[0]] + P + [P[-1]]; out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
    out.append(P[-2]); return out
def ribbon(name, pts_mm, wdir, width, thick, material, coll, closed=False, n=10):
    """Box-section strip along a smoothed path (mm); its width lies along wdir (orthogonalised to the tangent)."""
    C = catmull(pts_mm + ([pts_mm[0]] if closed else []), n)
    me = bpy.data.meshes.new(name); bm = bmesh.new(); rings = []
    for i, p in enumerate(C):
        t = (C[min(i + 1, len(C) - 1)] - C[max(i - 1, 0)]).normalized()
        w = Vector(wdir); w = (w - t * w.dot(t)).normalized(); nn = t.cross(w)
        q = [p + w * (width / 2) + nn * (thick / 2), p - w * (width / 2) + nn * (thick / 2),
             p - w * (width / 2) - nn * (thick / 2), p + w * (width / 2) - nn * (thick / 2)]
        rings.append([bm.verts.new(v * MM) for v in q])
    for a, b in zip(rings, rings[1:]):
        for k in range(4): bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(rings[0][::-1]); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); o.data.materials.append(M[material]); link(o, coll); return o

shots = []
def want(tag): return ONLY is None or tag in ONLY

# ------------------------------------------------------------------ PS01 ankle hub on its strap
if want('PS01'):
    s = bpy.data.scenes.new('PS01_AnkleHub_Strap'); setup_render(s); c = new_coll('AnkleHub', s.collection)
    R_LEG = 45.0; ZS = 120.0                               # mannequin only (not anthropometric data)
    prof = [(31, 0), (32, 20), (34, 50), (38, 80), (43, 110), (46, 140), (50, 175), (54, 215), (56, 250), (56.5, 262)]
    leg = lathe('Mannequin_lower_leg', prof, c, 'skin', sx=1.0, sy=0.9)
    lathe('Stand', [(70, -14), (70, -2), (40, 0)], c, 'stand')
    # pod: pod y -> world +Z (up the leg), pod z (front) -> world -Y (toward camera), pod x -> world +X
    r_here = 0.9 * (46 + (43 - 46) * (140 - (ZS)) / 30 if ZS < 140 else 46)
    org = Vector((-21, -(r_here + 5.4), ZS - 30.5)) + Vector((0, 0, 0))
    Mw = pod_to_world(org, (1, 0, 0), (0, 0, 1), (0, -1, 0))
    pod_group(c, Mw, extra=[(NEW / '13_AnkleCradle_R__AnkleHub_R.stl', '13_AnkleCradle_R', 'petg_navy'),
                            (NEW / '16_AnkleSaddlePad_TPU__AnkleHub_R.stl', '16_AnkleSaddlePad_TPU', 'tpu_teal'),
                            (NEW / '15_TailBlank_TPU_R__AnkleHub_R.stl', '15_TailBlank_TPU_R', 'tpu_teal')])
    # strap: from each wing slot around the back of the leg (35 mm band, as the Rev C renders)
    a_ = 44.0 + 2.2; b_ = 0.9 * 44.0 + 2.2
    path = [wpt(Mw, (47.8, 30.5, -1.9)), wpt(Mw, (53.0, 30.5, -5.5))]
    for k in range(0, 17):
        th = -math.pi / 2 + 0.95 + (2 * math.pi - 1.9) * k / 16
        path.append((a_ * math.cos(th), b_ * math.sin(th), ZS))
    path += [wpt(Mw, (-11.0, 30.5, -5.5)), wpt(Mw, (-5.8, 30.5, -1.9))]
    ribbon('Strap_ankle', path, (0, 0, 1), 35, 2.0, 'silicone', c, n=6)
    tgt = Vector((0, -40, 125)) * MM
    studio(s, tgt, 0.42); camera(s, tgt + Vector((-0.20, -0.30, 0.07)), tgt + Vector((0, 0, -0.004)), 70)
    shots.append(s)

# ------------------------------------------------------------------ PS02 shoe node on the collar
def shoe_form(coll, wall=5.0):
    """Stand-in shoe: insole outline (1:1 medium template) as the inner wall, offset outward by `wall`, wall height
    falling from heel to toe, plus a sole. Returns (outline_pts_mm, height_fn)."""
    outline = sample_path(svg_paths()[0])
    pts = [(x, -y) for x, y in outline]                     # template y down -> world y up (toe at +y... heel at -y)
    if abs(pts[0][0] - pts[-1][0]) + abs(pts[0][1] - pts[-1][1]) < 1e-6: pts = pts[:-1]
    ys = [p[1] for p in pts]; ymin, ymax = min(ys), max(ys)
    def h(y): u = (y - ymin) / (ymax - ymin); return 62.0 - 36.0 * min(1.0, u / 0.65) ** 1.2      # visual only
    cx = sum(p[0] for p in pts) / len(pts); cy = sum(p[1] for p in pts) / len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
    if area < 0: pts = pts[::-1]
    n = len(pts); normals = []
    for i in range(n):
        a, b = Vector(pts[i - 1]), Vector(pts[(i + 1) % n]); t = (b - a).normalized(); normals.append(Vector((t.y, -t.x)))
    me = bpy.data.meshes.new('ShoeForm_upper'); bm = bmesh.new()
    inn_b = [bm.verts.new((p[0] * MM, p[1] * MM, 0)) for p in pts]
    inn_t = [bm.verts.new((p[0] * MM, p[1] * MM, h(p[1]) * MM)) for p in pts]
    out_b = [bm.verts.new(((p[0] + nn.x * wall) * MM, (p[1] + nn.y * wall) * MM, -4 * MM)) for p, nn in zip(pts, normals)]
    out_t = [bm.verts.new(((p[0] + nn.x * wall) * MM, (p[1] + nn.y * wall) * MM, h(p[1]) * MM)) for p, nn in zip(pts, normals)]
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((inn_b[j], inn_b[i], inn_t[i], inn_t[j])); bm.faces.new((out_b[i], out_b[j], out_t[j], out_t[i]))
        bm.faces.new((inn_t[i], out_t[i], out_t[j], inn_t[j])); bm.faces.new((inn_b[i], inn_b[j], out_b[j], out_b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me); bm.free()
    up = bpy.data.objects.new('ShoeForm_upper', me); up.data.materials.append(M['shoe']); link(up, coll)
    for p in me.polygons: p.use_smooth = True
    me2 = bpy.data.meshes.new('ShoeForm_sole'); bm = bmesh.new()
    bot = [bm.verts.new(((p[0] + nn.x * (wall + 2)) * MM, (p[1] + nn.y * (wall + 2)) * MM, -26 * MM)) for p, nn in zip(pts, normals)]
    top = [bm.verts.new(((p[0] + nn.x * (wall + 2)) * MM, (p[1] + nn.y * (wall + 2)) * MM, -3 * MM)) for p, nn in zip(pts, normals)]
    bm.faces.new(bot[::-1]); bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n; bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces); bm.to_mesh(me2); bm.free()
    so = bpy.data.objects.new('ShoeForm_sole', me2); so.data.materials.append(M['sole']); link(so, coll)
    # vamp: an arched cover over the front of the shoe, lofted between the two wall tops (visual stand-in only)
    def x_at(yq):
        xs = []
        for i in range(n):
            (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]
            if (y1 - yq) * (y2 - yq) <= 0 and y1 != y2:
                xs.append(x1 + (yq - y1) * (x2 - x1) / (y2 - y1))
        return (min(xs), max(xs)) if len(xs) >= 2 else None
    y_open = ymin + 0.50 * (ymax - ymin); st = 22; seg = 16; grid = []
    for k in range(st + 1):
        yq = y_open + (ymax - 1.5 - y_open) * (k / st) ** 0.9
        xr = x_at(yq)
        if not xr: continue
        xl, xh = xr[0] - wall * 0.6, xr[1] + wall * 0.6; half = (xh - xl) / 2
        arch = max(6.0, 0.55 * half) * (1 - 0.55 * (k / st) ** 2)
        grid.append([((xl + (xh - xl) * u / seg) * MM, yq * MM, (h(yq) - 1 + arch * math.sin(math.pi * u / seg)) * MM)
                     for u in range(seg + 1)])
    me4 = bpy.data.meshes.new('ShoeForm_vamp'); bm = bmesh.new()
    vg = [[bm.verts.new(v) for v in row] for row in grid]
    for a, b in zip(vg, vg[1:]):
        for u in range(seg): bm.faces.new((a[u], a[u + 1], b[u + 1], b[u]))
    bm.to_mesh(me4); bm.free()
    va = bpy.data.objects.new('ShoeForm_vamp', me4); va.data.materials.append(M['shoe']); link(va, coll)
    for p_ in me4.polygons: p_.use_smooth = True
    sol = va.modifiers.new('thick', 'SOLIDIFY'); sol.thickness = 3.0 * MM; sol.offset = 1.0
    me3 = bpy.data.meshes.new('ShoeForm_insole'); bm = bmesh.new()
    f = [bm.verts.new((p[0] * MM, p[1] * MM, 0.5 * MM)) for p in pts]; bm.faces.new(f); bm.to_mesh(me3); bm.free()
    ins = bpy.data.objects.new('ShoeForm_insole', me3); ins.data.materials.append(M['lining']); link(ins, coll)
    return pts, normals, h

if want('PS02'):
    s = bpy.data.scenes.new('PS02_ShoeNode_Collar'); setup_render(s); c = new_coll('ShoeNode', s.collection)
    COLLAR_T = 5.0; TAIL_T = 1.2; ZB = -3.4; G_ = COLLAR_T + TAIL_T          # = build_ps_mounts.py parameters
    pts, normals, h = shoe_form(c, COLLAR_T)
    # lateral heel-quarter point: the outline point with the largest x in the rear 30 % of the length
    ys = [p[1] for p in pts]; ymin, ymax = min(ys), max(ys)
    cand = [i for i, p in enumerate(pts) if p[1] < ymin + 0.30 * (ymax - ymin) and p[1] > ymin + 0.12 * (ymax - ymin)]
    i0 = max(cand, key=lambda i: pts[i][0])
    nrm = Vector((normals[i0].x, normals[i0].y, 0)).normalized()
    P = Vector((pts[i0][0], pts[i0][1], 0)) + nrm * COLLAR_T; P.z = h(pts[i0][1])
    yax = Vector((0, 0, -1)); zax = nrm; xax = yax.cross(zax)
    # pod point (21, 1.0, ZB) = hook centre on the outer collar face at the collar top edge
    Mw0 = pod_to_world((0, 0, 0), xax, yax, zax)
    org = P - (Mw0 @ (Vector((21, 1.0, ZB)) * MM)) / MM
    Mw = pod_to_world(org, xax, yax, zax)
    pod_group(c, Mw, extra=[(NEW / '14_CollarClip_R__ShoeNode_R.stl', '14_CollarClip_R', 'petg_navy'),
                            (POD / 'TailBoot_R.stl', 'TailBoot_R', 'tpu_teal')])
    zt = ZB - G_ + TAIL_T / 2
    tail = [(21, -10, 14.9), (21, -17, 11), (21, -19, 2), (21, -12, -6), (21, -3, zt), (21, 4, zt), (21, 30, zt),
            (21, 58, zt - 0.5)]
    ribbon('InsoleTail', [wpt(Mw, p) for p in tail], tuple(xax), 8, 1.2, 'tpu_teal', c)
    look = Vector(P) + nrm * 12 - Vector((0, 0, 22)) + Vector((0, 10, 0)); tgt = look * MM
    studio(s, tgt, 0.45)
    back = Vector((0, -1, 0)); camv = (nrm * 0.85 + back * 0.75).normalized()
    camera(s, tgt + Vector((camv.x * 0.24, camv.y * 0.24, 0.20)), tgt, 58)
    shots.append(s)

# ------------------------------------------------------------------ PS03 exploded pod (ankle-hub build)
if want('PS03'):
    s = bpy.data.scenes.new('PS03_Pod_Exploded'); setup_render(s, (1800, 1350)); c = new_coll('PodExploded', s.collection)
    EX = {'16_AnkleSaddlePad': (0, 0, -50), '13_AnkleCradle': (0, 0, -36), '03_BatteryCartridgeCup': (0, 0, -18),
          '04_BatteryCartridgeLid': (0, 0, -12), 'Cell_LP502030_MAXSIZE': (0, 0, -15), 'CartridgeStripPCB': (0, 0, -15),
          'ContactPlates': (0, 0, -12), '01_RearHousing': (0, 0, 0), 'PCB': (0, 0, 16), '09_SeamGasket': (0, 0, 30),
          '02_FrontCover': (0, 0, 40), '07_Button': (0, 0, 52), '08_LightWindow': (0, 0, 52), '15_TailBlank': (0, -22, 0)}
    Mw = Matrix.Translation(Vector((0, 0, 60)) * MM)
    pod_group(c, Mw, explode=EX, inner=True, pcba=True,
              extra=[(NEW / '13_AnkleCradle_R__AnkleHub_R.stl', '13_AnkleCradle_R', 'petg_navy'),
                     (NEW / '16_AnkleSaddlePad_TPU__AnkleHub_R.stl', '16_AnkleSaddlePad_TPU', 'tpu_teal'),
                     (NEW / '15_TailBlank_TPU_R__AnkleHub_R.stl', '15_TailBlank_TPU_R', 'tpu_teal')])
    tgt = Vector((21, 28, 60)) * MM
    studio(s, tgt, 0.38); camera(s, tgt + Vector((-0.300, -0.265, 0.205)), tgt + Vector((0, 0, 0.0)), 66)
    shots.append(s)

# ------------------------------------------------------------------ PS04 interim cabinet, lid lifted
if want('PS04'):
    s = bpy.data.scenes.new('PS04_Interim_Cabinet'); setup_render(s); c = new_coll('Cabinet', s.collection)
    lift = Matrix.Translation(Vector((0, 0, 34)) * MM)
    parts = [('21_InterimCabinet_Base', 'petg_navy', Matrix.Identity(4)), ('22_InterimCabinet_Lid', 'petg_pale', lift),
             ('DUMMY_Perfboard', 'perf', Matrix.Identity(4)), ('DUMMY_ESP32_DevBoard', 'devpcb', Matrix.Identity(4)),
             ('DUMMY_OLED_SH1106', 'oledpcb', Matrix.Identity(4)), ('DUMMY_MPU6050_GY521', 'mpupcb', Matrix.Identity(4)),
             ('DUMMY_PaneAcrylic', 'acrylic', lift)]
    for n, m, mx in parts:
        p = CAB / f'{n}.stl'
        if p.exists(): stl(p, n, m, c, mx)
    import json as _j
    der = _j.loads((PKG / 'interim-cabinet/cabinet-validation.json').read_text())['derived_mm']
    cy, cz = der['cable_centre'][1], der['cable_centre'][2]
    ribbon('InsoleCable', [(-70, cy - 40, 3), (-35, cy - 10, cz - 3), (-8, cy, cz), (4, cy, cz)], (0, 0, 1), 6, 6, 'cable', c)
    W2 = der['outer_w']; L2 = der['outer_l']
    for sx, d_ in ((-12 + 3 + 2, -1), (W2 + 12 - 3 - 2, 1)):
        band(f'Strap_{d_}', [(sx, L2 / 2, 1.5), (sx + d_ * 14, L2 / 2, 1.5), (sx + d_ * 60, L2 / 2, 1.5)], 35, 2.0, 'silicone', c)
    tgt = Vector((W2 / 2, L2 / 2, 22)) * MM
    studio(s, tgt, 0.45); camera(s, tgt + Vector((0.20, -0.30, 0.26)), tgt + Vector((0, 0.004, -0.004)), 60)
    shots.append(s)

for sc in shots:
    sc.render.filepath = str(RAW / f'{sc.name}.png')
    bpy.ops.render.render(write_still=True, scene=sc.name)
    print('RENDERED', sc.name, sc.render.filepath, flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(PKG / 'renders-work/NIVA-RevC2-ProtectedSteps-scenes.blend'))
