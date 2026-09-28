"""NIVA Rev C Blender scenes (Blender 4.x, headless):

  blender -b --factory-startup -P build_niva_scenes.py -- [--preview]

Geometry sources (nothing is modelled by eye where an engineering file exists):
  * pod parts             work/niva-meshes/*.stl + work/niva-scene-manifest.json (FreeCAD Rev C generator)
  * PCB assembly          electronics/exports/pcb/NIVA-pod-PCBA.glb (KiCad 9 export; library + Espressif models)
  * insole outline, toe-post slot, lateral heel tail tab
                          outputs/niva-vector-blueprints/07-full-size-fit-template.svg (1:1 medium template)
  * tail band / strap     parametric: 8 mm x 1.2 mm teal band; 35 mm x 2 mm navy silicone strap
  * dock + cartridge      work/niva-meshes (build_niva_dock_cad.py) + electronics/dock/exports/pcb/NIVA-dock-PCBA.glb
  * insole flex           electronics/insole/exports/pcb/NIVA-insole-R-PCBA.glb (KiCad 9)
Outputs: renders/*.png, blender/NIVA-RevC-scenes.blend, blender/*.glb
"""
import bpy, bmesh, json, math, re, sys
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs/NIVA-3D-engineering-prototype'
RENDERS = OUT / 'renders'; BLEND = OUT / 'blender'
for p in (RENDERS, BLEND): p.mkdir(parents=True, exist_ok=True)
PREVIEW = '--preview' in sys.argv
ONLY = sys.argv[sys.argv.index('--only') + 1].split(',') if '--only' in sys.argv else None   # e.g. --only 03,04
MM = 0.001
PCB_Z = 11.8
L_DOCK_PCB_Z = 6.4                                     # niva_layout.DOCK['pcb_z'] (board underside in the dock frame)
FSR_XY = [(24, 235), (24, 193), (80, 180), (70, 117), (43, 32)]   # build_niva_insole_flex.SENSORS (heel frame)

bpy.ops.wm.read_factory_settings(use_empty=True)

# ------------------------------------------------------------------ materials
def srgb(h):
    h = h.lstrip('#'); c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c) + (1.0,)
def mat(name, color, rough=0.5, metal=0.0, transmission=0.0, alpha=1.0, coat=0.0, ior=1.45, sss=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True; b = m.node_tree.nodes['Principled BSDF']
    def put(key, val):
        for k in (key, key + ' Weight'):
            if k in b.inputs: b.inputs[k].default_value = val; return
    put('Base Color', srgb(color) if isinstance(color, str) else color); put('Roughness', rough); put('Metallic', metal)
    put('Transmission', transmission); put('Coat', coat); put('IOR', ior); put('Subsurface', sss)
    if alpha < 1.0:
        put('Alpha', alpha); m.blend_method = 'BLEND' if hasattr(m, 'blend_method') else None
    return m
NAVY, TEAL, PALE = '#14314B', '#0B6F79', '#EAF0F2'
M = {
    'petg_navy':   mat('PETG navy (printed, satin)', NAVY, 0.42, coat=0.1),
    'petg_pale':   mat('PETG pale grey-blue (printed, satin)', PALE, 0.38, coat=0.1),
    'petg_cart':   mat('PETG cartridge navy', '#0F2638', 0.45),
    'tpu_teal':    mat('TPU teal (soft)', TEAL, 0.62, sss=0.02),
    'silicone':    mat('Silicone navy strap (matte)', '#1B3A56', 0.78, sss=0.03),
    'gasket':      mat('Silicone gasket dark grey', '#2A2F33', 0.8),
    'clear':       mat('Clear light pipe', '#F4FAFF', 0.05, transmission=1.0, ior=1.5),
    'brass':       mat('Brass contact plate', '#C9A34B', 0.3, metal=1.0),
    'envelope':    mat('PLACEHOLDER ENVELOPE (not a selected part)', '#F28C28', 0.5, transmission=0.3, alpha=0.55),
    'insole_top':  mat('Insole TPU-faced skin', PALE, 0.55, sss=0.02),
    'table':       mat('Studio floor', '#B9C4CC', 0.9),
    'steel':       mat('Stainless screw', '#9AA3AA', 0.28, metal=1.0),
    'strip_pcb':   mat('Cartridge strip PCB (green mask)', '#14331F', 0.24),
}
PART_MAT = [('01_RearHousing', 'petg_navy'), ('02_FrontCover', 'petg_pale'), ('03_BatteryCartridgeCup', 'petg_cart'),
            ('04_BatteryCartridgeLid', 'petg_cart'), ('05_Cradle', 'petg_navy'), ('06_SoftCradlePad', 'tpu_teal'),
            ('07_Button', 'tpu_teal'), ('08_LightWindow', 'clear'), ('09_SeamGasket', 'gasket'),
            ('TailBoot', 'tpu_teal'), ('ContactPlates', 'brass'), ('Cell_LP502030_MAXSIZE', 'envelope'),
            ('CartridgeStripPCB', 'strip_pcb')]

# ------------------------------------------------------------------ import helpers
def import_stl(path):
    before = set(bpy.data.objects)
    if hasattr(bpy.ops.wm, 'stl_import'): bpy.ops.wm.stl_import(filepath=str(path), global_scale=MM)
    else: bpy.ops.import_mesh.stl(filepath=str(path), global_scale=MM)
    o = (set(bpy.data.objects) - before).pop()
    for c in o.users_collection: c.objects.unlink(o)
    return o
def link(o, coll):
    if o.name not in coll.objects: coll.objects.link(o)
    return o
def new_coll(name, parent=None):
    c = bpy.data.collections.new(name); (parent or bpy.context.scene.collection).children.link(c); return c
def smooth(o, angle=35):
    """Smooth shading with angle-based sharp edges (Blender 4.1+ mesh API; auto-smooth on 4.0)."""
    me = o.data
    if hasattr(me, 'set_sharp_from_angle'): me.shade_smooth(); me.set_sharp_from_angle(angle=math.radians(angle))
    elif hasattr(me, 'use_auto_smooth'):
        for poly in me.polygons: poly.use_smooth = True
        me.use_auto_smooth = True; me.auto_smooth_angle = math.radians(angle)

base = bpy.context.scene; base.name = 'NIVA_library'
LIB = new_coll('LIB_pod_parts_R'); LIBL = new_coll('LIB_pod_parts_L'); LIBPCB = new_coll('LIB_PCBA_KiCad')
for c in (LIB, LIBL, LIBPCB): c.hide_render = True

manifest = json.loads((ROOT / 'work/niva-scene-manifest.json').read_text())
parts = {'R': {}, 'L': {}}
for e in manifest:
    name = e['name']; side = name[-1]
    if name.startswith(('PCB_Substrate', 'PCB_Components')): continue          # PCB comes from the KiCad GLB
    o = import_stl(ROOT / e['stl']); o.name = name
    key = next((m for p, m in PART_MAT if name.startswith(p)), 'petg_navy')
    o.data.materials.clear(); o.data.materials.append(M[key])
    o['source'] = e['stl']; o['material_spec'] = e['material']; o['kind'] = e['kind']
    smooth(o); link(o, LIB if side == 'R' else LIBL); parts[side][name[:-2]] = o

def import_pcba(rel='electronics/exports/pcb/NIVA-pod-PCBA.glb', lib=None, board='pod'):
    lib = lib or LIBPCB
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(OUT / rel))
    objs = list(set(bpy.data.objects) - before)
    root = bpy.data.objects.new(f'PCBA_KiCad_GLB_{board}', None)
    for o in objs:
        for c in o.users_collection: c.objects.unlink(o)
        link(o, lib)
        if o.parent is None: o.parent = root
    link(root, lib); root['source'] = f'{rel} (KiCad 9)'
    # KiCad 9's GLB writer (a) stores KiCad's sRGB colours directly as glTF baseColorFactor, which glTF defines
    # as linear, so every colour imports too light (mask sRGB 20/51/36 became linear 0.08/0.2/0.14 = sRGB 79/124/104,
    # the pale mint of the first renders); (b) marks almost every STEP colour metallic = 1, roughness = 1;
    # (c) exports the mask as a translucent layer. Colours are linearised here and finishes re-assigned per
    # colour class (appearance only; geometry and colour choices stay KiCad's).
    lin = lambda v: ((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92
    fixed = set()
    for o in objs:
        for m in getattr(o.data, 'materials', []) or []:
            if not m or m.name in fixed or 'Principled BSDF' not in m.node_tree.nodes: continue
            fixed.add(m.name); b = m.node_tree.nodes['Principled BSDF']; c = list(b.inputs['Base Color'].default_value)
            c = [lin(v) for v in c[:3]] + [1.0]; b.inputs['Base Color'].default_value = c
            a = b.inputs['Alpha'].default_value; met = b.inputs['Metallic'].default_value
            def setf(col=None, metal=None, rough=None, coat=None):
                if col: b.inputs['Base Color'].default_value = col
                if metal is not None: b.inputs['Metallic'].default_value = metal
                if rough is not None: b.inputs['Roughness'].default_value = rough
                if coat is not None: b.inputs['Coat Weight'].default_value = coat
                b.inputs['Alpha'].default_value = 1.0
            if a < 0.95 and c[1] > c[0] and c[1] > c[2]:  setf(tuple(c), 0.0, 0.24, 0.0); m.name = 'KiCad solder mask (LPI green, gloss)'
            elif a < 0.95:                                setf((0.85, 0.87, 0.86, 1), 0.0, 0.6);       m.name = 'KiCad silkscreen'
            elif met < 0.5:                               setf((0.33, 0.30, 0.19, 1), 0.0, 0.75);      m.name = 'KiCad FR-4 core'
            elif c[0] > 0.25 and c[0] > c[1] > c[2]:      setf(None, 1.0, 0.28);                       m.name = 'KiCad gold/copper'
            elif min(c[:3]) > 0.15 and max(c[:3]) - min(c[:3]) < 0.06: setf(None, 1.0, 0.32)            # tin, shields (linear)
            else:                                         setf(None, 0.0, 0.45)                        # ceramic / epoxy bodies
    # Component meshes arrive without materials (KiCad GLB/STEP drop library model colours). They are named
    # by reference designator, so finishes are assigned per part class from each part's own geometry.
    classify_components(objs, board)
    return root, objs

FIN = {'tin': mat('Tin-plated terminations', '#C8CDD0', 0.3, metal=1.0), 'epoxy': mat('Black epoxy', '#141516', 0.45),
       'ceramic': mat('MLCC ceramic', '#9C7B55', 0.55), 'nylon': mat('JST natural nylon', '#EDEBE3', 0.5),
       'led': mat('LED package', '#F3F0E6', 0.3, transmission=0.2), 'shield': mat('Module shield', '#BFC5C9', 0.25, metal=1.0),
       'modpcb': mat('Module PCB', '#1C3D2A', 0.4), 'steel': M['steel']}
def classify_components(objs, board='pod'):
    import re as _re
    for o in objs:
        if o.type != 'MESH' or o.data.materials or not _re.match(r'^[A-Z]+\d+', o.name): continue
        ref = o.name.split('.')[0]; me = o.data; mw = o.matrix_world
        pts = [mw @ v.co for v in me.vertices]
        mn = Vector(map(min, *pts)); mx = Vector(map(max, *pts)); c = (mn + mx) / 2; ext = mx - mn
        long_ax = 0 if ext.x >= ext.y else 1; short_ax = 1 - long_ax
        def rule(poly_c):
            d_long = abs(poly_c[long_ax] - c[long_ax]); d_short = abs(poly_c[short_ax] - c[short_ax])
            ends = 'tin' if d_long > ext[long_ax] / 2 - 0.3 * MM else None
            if board == 'dock':
                if ref == 'J2':            return 'envelope'
                if ref == 'J1':            return 'shield'
                if ref[0] in 'RF':         return ends or 'epoxy'
                if ref[0] == 'C':          return ends or 'ceramic'
                if ref == 'D1':            return ends or 'led'
                if ref == 'U2':            return 'tin' if d_short > 1.95 * MM else 'epoxy'
                if ref in ('U1', 'Q1'):    return 'tin' if d_short > 0.7 * MM else 'epoxy'
                return 'epoxy'
            if board == 'insole':          return ends or 'epoxy'
            if ref in ('J2', 'U6'):  return 'envelope'
            if ref.startswith('R'):  return 'tin' if d_long > ext[long_ax] / 2 - 0.3 * MM else 'epoxy'
            if ref.startswith('C'):  return 'tin' if d_long > ext[long_ax] / 2 - 0.3 * MM else 'ceramic'
            if ref in ('D4', 'D5'):  return 'tin' if d_long > ext[long_ax] / 2 - 0.3 * MM else 'led'
            if ref == 'D2':          return 'tin' if d_short > 0.7 * MM else 'epoxy'          # BAV199 SOT-23
            if ref.startswith('D'):  return 'tin' if d_long > 0.85 * MM else 'epoxy'
            if ref == 'U2':          return 'tin' if d_short > 2.0 * MM else 'epoxy'
            if ref in ('U4', 'U5'):  return 'tin' if d_short > 0.82 * MM else 'epoxy'
            if ref == 'U1':          return 'modpcb' if poly_c.z < mn.z + 0.8 * MM else 'shield'
            if ref == 'J1':          return 'tin' if poly_c.z < mn.z + 0.25 * MM else 'nylon'
            if ref == 'SW1':         return 'epoxy' if poly_c.z > mx.z - 0.35 * MM else 'steel'
            return 'epoxy'
        names = []
        for poly in me.polygons:
            k = rule(mw @ poly.center)
            if k not in names: names.append(k)
            poly.material_index = names.index(k)
        for k in names: me.materials.append(M['envelope'] if k == 'envelope' else FIN[k])
pcba_root, pcba_objs = import_pcba()

# charging dock (FreeCAD meshes + KiCad GLB) and the right insole flex (KiCad GLB)
LIBDOCK = new_coll('LIB_dock'); LIBINS = new_coll('LIB_insole_flex')
for c in (LIBDOCK, LIBINS): c.hide_render = True
DOCK_MAT = {'10_DockBase': 'petg_navy', '11_DockTop': 'petg_pale', '12_DockLightPipe': 'clear', 'Cartridge_Cup': 'petg_cart',
            'Cartridge_Lid': 'petg_cart', 'Cartridge_Cell': 'envelope', 'Cartridge_StripPCB': 'strip_pcb', 'Cartridge_LidPlates': 'brass'}
dock_parts = {}
for e in json.loads((ROOT / 'work/niva-dock-manifest.json').read_text()):
    if e['name'].startswith('DockPCB') or e['name'].startswith('DockSpring'): continue      # PCBA comes from the GLB
    o = import_stl(ROOT / e['stl']); o.name = 'Dock_' + e['name']
    o.data.materials.clear(); o.data.materials.append(M[next(v for k, v in DOCK_MAT.items() if e['name'].startswith(k))])
    o['source'] = e['stl']; smooth(o); link(o, LIBDOCK); dock_parts[e['name']] = o
dock_root, dock_objs = import_pcba('electronics/dock/exports/pcb/NIVA-dock-PCBA.glb', LIBDOCK, 'dock')
flex_root, flex_objs = import_pcba('electronics/insole/exports/pcb/NIVA-insole-R-PCBA.glb', LIBINS, 'insole')
POLYIMIDE = mat('Polyimide flex base (amber)', '#B8741A', 0.35, transmission=0.25, sss=0.05)
COVERLAY = mat('Polyimide coverlay (amber, gloss)', '#C98A2E', 0.2, transmission=0.35)
for o in flex_objs:
    for i, m in enumerate(getattr(o.data, 'materials', []) or []):
        if m and m.name.startswith('KiCad solder mask'): o.data.materials[i] = COVERLAY
        elif m and m.name.startswith('KiCad FR-4'):     o.data.materials[i] = POLYIMIDE

# ------------------------------------------------------------------ instancing: a whole pod as a movable group
def pod_instance(coll, side, origin=Vector((0, 0, 0)), rot=Matrix.Identity(4), explode=None, names=None, with_pcb=True):
    """Place linked duplicates of the pod parts (pod frame, mm) into coll under one empty."""
    root = bpy.data.objects.new(f'Pod_{side}_{coll.name}', None); link(root, coll)
    root.matrix_world = Matrix.Translation(origin) @ rot
    for key, src in parts[side].items():
        if names and not any(key.startswith(n) for n in names): continue
        o = src.copy(); o.name = f'{key}_{side}@{coll.name}'; link(o, coll); o.parent = root
        dx = 80.0 if side == 'L' else 0.0                                # L parts were exported at x - 80 mm
        off = Vector((dx, 0, 0)) + Vector((explode or {}).get(next((k for k in (explode or {}) if key.startswith(k)), ''), (0, 0, 0)))
        o.location = off * MM
    if with_pcb:
        pr = bpy.data.objects.new(f'PCBA_{side}@{coll.name}', None); link(pr, coll); pr.parent = root
        pz = PCB_Z + (explode or {}).get('PCB', (0, 0, 0))[2]
        pr.location = Vector((0, 0, pz)) * MM
        for o in pcba_objs:
            if o.type != 'MESH': continue
            d = o.copy(); link(d, coll); d.parent = pr; d.matrix_parent_inverse = Matrix.Identity(4)
            d.matrix_basis = o.matrix_world.copy()
    return root

# ------------------------------------------------------------------ insole from the 1:1 fit template
def svg_paths():
    s = (ROOT / 'outputs/niva-vector-blueprints/07-full-size-fit-template.svg').read_text()
    g = s[s.index('<g transform="translate(31 26) scale(1)">'):]
    return re.findall(r'<path d="([^"]+)"', g)[:3]
def sample_path(d, n=24):
    tok = re.findall(r'[MLCQZ]|-?\d+\.?\d*', d); pts = []; i = 0; cur = None; cmd = None
    while i < len(tok):
        t = tok[i]
        if t in 'MLCQZ': cmd = t; i += 1; continue
        if cmd == 'M': cur = (float(tok[i]), float(tok[i + 1])); pts.append(cur); i += 2; cmd = 'L'
        elif cmd == 'L': cur = (float(tok[i]), float(tok[i + 1])); pts.append(cur); i += 2
        elif cmd == 'C':
            p1, p2, p3 = [(float(tok[i + k]), float(tok[i + k + 1])) for k in (0, 2, 4)]; i += 6
            for k in range(1, n + 1):
                u = k / n; a = (1 - u) ** 3; b = 3 * u * (1 - u) ** 2; c = 3 * u * u * (1 - u); e = u ** 3
                pts.append((a * cur[0] + b * p1[0] + c * p2[0] + e * p3[0], a * cur[1] + b * p1[1] + c * p2[1] + e * p3[1]))
            cur = p3
        elif cmd == 'Q':
            p1, p2 = [(float(tok[i + k]), float(tok[i + k + 1])) for k in (0, 2)]; i += 4
            for k in range(1, n + 1):
                u = k / n; pts.append(((1 - u) ** 2 * cur[0] + 2 * u * (1 - u) * p1[0] + u * u * p2[0],
                                       (1 - u) ** 2 * cur[1] + 2 * u * (1 - u) * p1[1] + u * u * p2[1]))
            cur = p2
        else: i += 1
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) + abs(p[1] - out[-1][1])) > 1e-6: out.append(p)
    return out
def prism(name, pts, z0, t, mirror=False):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    sgn = -1 if mirror else 1
    vs = [bm.verts.new((sgn * x * MM, -y * MM, z0 * MM)) for x, y in pts]
    f = bm.faces.new(vs if not mirror else vs[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=[f])
    if f.normal.z < 0: f.normal_flip()
    ext = bmesh.ops.extrude_face_region(bm, geom=[f]); verts = [v for v in ext['geom'] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=verts, vec=(0, 0, t * MM))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me); bm.free(); return bpy.data.objects.new(name, me)
def boolean(target, tool, op):
    m = target.modifiers.new(op, 'BOOLEAN'); m.operation = op; m.object = tool; m.solver = 'EXACT'
    bpy.context.view_layer.objects.active = target
    with bpy.context.temp_override(object=target, active_object=target):
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.data.objects.remove(tool)
def insole(side, dest):
    """Built in a scratch collection of the active scene (modifier_apply needs the view layer), then moved."""
    coll = new_coll(f'scratch_insole_{side}', base.collection)
    outline_d, slot_d, tab_d = svg_paths(); mirror = side == 'L'
    ins = prism(f'Insole_{side}', sample_path(outline_d), 0, 2.8, mirror); link(ins, coll)
    tab = prism('tab', sample_path(tab_d) + [(72, 226)], 0.4, 1.2, mirror); link(tab, coll)   # tail exit tab, thinner
    boolean(ins, tab, 'UNION')
    sp = sample_path(slot_d); sp = [(sp[0][0] + 0.6, -4.0)] + sp + [(sp[-1][0] + 0.6, -4.0)]   # open through the toe edge
    slot = prism('slot', sp, -1, 5, mirror); link(slot, coll); boolean(ins, slot, 'DIFFERENCE')
    bev = ins.modifiers.new('edge', 'BEVEL'); bev.width = 0.9 * MM; bev.segments = 4; bev.limit_method = 'ANGLE'
    ins.data.materials.append(M['insole_top']); smooth(ins, 40)
    ins['source'] = 'niva-vector-blueprints/07-full-size-fit-template.svg (medium, 1:1)'
    ins['note'] = 'Sealed passive insert; five force regions + PVDF heel film are internal and not shown'
    txt = bpy.data.curves.new(f'mark_{side}', 'FONT'); txt.body = f'{side} / M'; txt.size = 7 * MM; txt.extrude = 0.15 * MM
    txt.align_x = 'CENTER'; t = bpy.data.objects.new(f'Insole_mark_{side}', txt); link(t, coll)
    t.location = ((-43 if mirror else 43) * MM, -205 * MM, 2.8 * MM); t.parent = ins; t.data.materials.append(M['tpu_teal'])
    for o in list(coll.objects):
        coll.objects.unlink(o); link(o, dest)
    bpy.data.collections.remove(coll)
    return ins

# ------------------------------------------------------------------ bands (tail, strap)
def band(name, pts, width, thick, material, coll, tilt=0.0, closed=False):
    cu = bpy.data.curves.new(name, 'CURVE'); cu.dimensions = '3D'; cu.twist_mode = 'Z_UP'
    sp = cu.splines.new('BEZIER'); sp.bezier_points.add(len(pts) - 1); sp.use_cyclic_u = closed
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = Vector(p) * MM; bp.handle_left_type = bp.handle_right_type = 'AUTO'; bp.tilt = tilt
    prof = bpy.data.curves.new(name + '_profile', 'CURVE'); ps = prof.splines.new('POLY'); ps.points.add(3)
    w, t = width * MM / 2, thick * MM / 2
    for q, (x, y) in zip(ps.points, [(-w, -t), (w, -t), (w, t), (-w, t)]): q.co = (x, y, 0, 1)
    ps.use_cyclic_u = True
    po = bpy.data.objects.new(name + '_profile', prof); link(po, coll); po.hide_render = po.hide_viewport = True
    cu.bevel_mode = 'OBJECT'; cu.bevel_object = po; cu.use_fill_caps = True
    o = bpy.data.objects.new(name, cu); o.data.materials.append(M[material]); link(o, coll); return o

# ------------------------------------------------------------------ studio
def studio(scene, target, size=0.6, floor_z=0.0, key=(-0.8, -0.9, 1.1), rim=(0.2, 1.0, 0.9)):
    w = bpy.data.worlds.get('Studio') or bpy.data.worlds.new('Studio'); w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = srgb('#C9D2D9'); bg.inputs[1].default_value = 0.4
    scene.world = w
    coll = new_coll(f'Studio_{scene.name}', scene.collection)
    me = bpy.data.meshes.new('floor'); bm = bmesh.new(); s = size * 12
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=s); bm.to_mesh(me); bm.free()
    fl = bpy.data.objects.new(f'Floor_{scene.name}', me); fl.location = (target.x, target.y, floor_z); fl.data.materials.append(M['table'])
    link(fl, coll)
    for name, loc, energy, sz in (('Key', key, 14, 0.6), ('Fill', (0.9, -0.5, 0.6), 4, 0.8), ('Rim', rim, 7, 0.5)):
        L = bpy.data.lights.new(f'{name}_{scene.name}', 'AREA'); L.energy = energy * (size / 0.25) ** 2; L.size = sz * size
        o = bpy.data.objects.new(L.name, L); o.location = target + Vector(loc) * size
        o.rotation_euler = (target - o.location).to_track_quat('-Z', 'Y').to_euler(); link(o, coll)
    return coll
def camera(scene, loc, target, lens=70, ortho=None):
    c = bpy.data.cameras.new(f'Cam_{scene.name}'); c.lens = lens; c.clip_start = 0.001; c.clip_end = 20
    if ortho: c.type = 'ORTHO'; c.ortho_scale = ortho
    o = bpy.data.objects.new(c.name, c); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    link(o, scene.collection); scene.camera = o; return o
def setup_render(scene, res=(2400, 1600)):
    r = scene.render; r.engine = 'CYCLES'; r.resolution_x, r.resolution_y = res
    r.resolution_percentage = 30 if PREVIEW else 100
    import _cycles
    oidn = getattr(_cycles, 'with_openimagedenoise', False)
    scene.cycles.use_denoising = bool(oidn)
    if oidn: scene.cycles.denoiser = 'OPENIMAGEDENOISE'
    scene.cycles.samples = (24 if PREVIEW else 128) if oidn else (48 if PREVIEW else 1024)
    scene.cycles.device = 'CPU'; r.film_transparent = False
    scene.view_settings.view_transform = 'AgX' if 'AgX' in [i.identifier for i in scene.view_settings.bl_rna.properties['view_transform'].enum_items] else 'Filmic'
    scene.view_settings.look = 'None'; scene.view_settings.exposure = -1.6; r.image_settings.file_format = 'PNG'
    scene.unit_settings.system = 'METRIC'; scene.unit_settings.length_unit = 'MILLIMETERS'
def new_scene(name):
    s = bpy.data.scenes.new(name); setup_render(s); return s

# ------------------------------------------------------------------ shots
shots = []
# 1. assembled pod on its cradle (right side), three-quarter front view
s1 = new_scene('01_Pod_Assembled'); c1 = new_coll('Pod_Assembled', s1.collection)
lift = Vector((0, 0, 5.4 * MM))
pod_instance(c1, 'R', origin=lift)
band('TailStub_R', [(21, -8, 20.3), (21, -30, 17), (21, -52, 6.0), (21, -80, 1.2)], 8, 1.2, 'tpu_teal', c1, 0)
tgt = Vector((21, 24, 12)) * MM
studio(s1, tgt, 0.25); camera(s1, tgt + Vector((-0.150, -0.215, 0.185)), tgt + Vector((0, -0.006, 0)), 85); shots.append(s1)

# 2. exploded pod: parts separated along the assembly axis (z), cartridge withdrawn to the rear
s2 = new_scene('02_Pod_Exploded'); c2 = new_coll('Pod_Exploded', s2.collection)
EXPLODE = {'05_Cradle': (0, 0, -34), '06_SoftCradlePad': (0, 0, -42), '03_BatteryCartridgeCup': (0, 0, -18),
           '04_BatteryCartridgeLid': (0, 0, -12), 'Cell_LP502030_MAXSIZE': (0, 0, -15), 'CartridgeStripPCB': (0, 0, -15),
           'ContactPlates': (0, 0, -12), '01_RearHousing': (0, 0, 0), 'PCB': (0, 0, 16), '09_SeamGasket': (0, 0, 30),
           '02_FrontCover': (0, 0, 40), '07_Button': (0, 0, 52), '08_LightWindow': (0, 0, 52), 'TailBoot': (0, -22, 0)}
pod_instance(c2, 'R', origin=Vector((0, 0, 48)) * MM, explode=EXPLODE)
tgt = Vector((21, 28, 48)) * MM
studio(s2, tgt, 0.35); camera(s2, tgt + Vector((-0.290, -0.255, 0.215)), tgt + Vector((0, 0, 0.002)), 60); shots.append(s2)

# 3. PCB close-up (KiCad GLB, unrouted placement prototype)
s3 = new_scene('03_PCB_Closeup'); c3 = new_coll('PCBA_only', s3.collection)
pr = bpy.data.objects.new('PCBA_closeup', None); link(pr, c3)
for o in pcba_objs:
    if o.type == 'MESH':
        d = o.copy(); link(d, c3); d.parent = pr; d.matrix_basis = o.matrix_world.copy()
tgt = Vector((21, 30, 1)) * MM
# key and rim lights moved to the left so the glossy mask does not mirror them into the lens (that haze read as a pale mask)
studio(s3, tgt, 0.15, floor_z=-3.2 * MM, key=(-0.9, 0.5, 1.1), rim=(-0.7, 1.0, 0.9)); camera(s3, tgt + Vector((-0.045, -0.075, 0.062)), tgt, 100); shots.append(s3)

# 4. complete product, flat lay: right insole, protected tail, pod on cradle, open strap
s4 = new_scene('04_Complete_Product_Flatlay'); c4 = new_coll('Product_R', s4.collection)
ins = insole('R', c4); ins.location = Vector((-150, 150, 0)) * MM
rot90 = Matrix.Rotation(math.radians(-90), 4, 'Z')     # pod bottom (tail exit) faces -x, toward the insole heel
pod_origin = Vector((40, -40, 5.4)) * MM
pod_instance(c4, 'R', origin=pod_origin, rot=rot90)
def pod2w(x, y, z): return (pod_origin + (rot90 @ Vector((x, y, z)) * MM)) / MM
boot_end = pod2w(21, -10, 14.9); tab_end = Vector((-150 + 92, 150 - 240, 1.0))
band('Tail_R', [tuple(boot_end), tuple(pod2w(21, -22, 10)), tuple(pod2w(21, -34, 2.5)), tuple(pod2w(21, -46, 1.2)),
                (-20, -118, 1.2), (-45, -98, 1.2), tuple(tab_end)],
     8, 1.2, 'tpu_teal', c4)
for sx, dirn in ((-5.8, -1), (47.8, 1)):                                          # strap from each cradle slot
    a = pod2w(sx, 30.5, -4.4); b = pod2w(sx + dirn * 18, 30.5, -4.4); c = pod2w(sx + dirn * 105, 30.5, -4.4)
    band(f'Strap_R_{"left" if dirn < 0 else "right"}', [tuple(a), tuple(b), tuple(c)], 35, 2.0, 'silicone', c4)
tgt = Vector((-25, -28, 10)) * MM
studio(s4, tgt, 0.8); camera(s4, tgt + Vector((0.02, -0.44, 0.64)), tgt, 50); shots.append(s4)

# 5. bilateral kit: left and right sets side by side
s5 = new_scene('05_Bilateral_Kit'); c5 = new_coll('Kit_LR', s5.collection)
rot180 = Matrix.Rotation(math.pi, 4, 'Z')
for side, x0 in (('R', 80), ('L', -80)):
    mir = -1 if side == 'L' else 1
    i = insole(side, c5); i.location = Vector((x0 - mir * 47, 345, 0)) * MM       # toe at y = 345, heel tab near y = 105
    pod_instance(c5, side, origin=Vector((x0 + 21, -10, 5.4)) * MM, rot=rot180)    # pod bottom (tail exit) faces the insole
    tab = (x0 - mir * 47 + mir * 92, 345 - 240, 1.0)
    band(f'Tail_{side}', [(x0, 0, 20.3), (x0, 12, 12), (x0, 24, 3.5), (x0, 38, 1.2), ((x0 + tab[0]) / 2 + mir * 8, 72, 1.2),
                          (tab[0], tab[1] - 8, 1.2), tab], 8, 1.2, 'tpu_teal', c5)
    for sx, reach in ((-5.8, 95 if side == 'R' else 40), (47.8, 40 if side == 'R' else 95)):   # short strap end inboard
        dirn = -1 if sx < 0 else 1; y = -10 - 30.5                                   # pod frame y 30.5 after 180 deg turn
        xw = x0 + 21 - sx
        band(f'Strap_{side}_{sx}', [(xw, y, 1.0), (xw - dirn * 16, y, 1.0), (xw - dirn * reach, y, 1.0)], 35, 2.0, 'silicone', c5)
tgt = Vector((0, 140, 10)) * MM
studio(s5, tgt, 1.0); camera(s5, tgt + Vector((0.0, -0.50, 0.82)), tgt, 45); shots.append(s5)

# 6. charging dock with a cartridge seated, and a spare cartridge turned over to show its dock pads
s6 = new_scene('06_Dock_Charging'); c6 = new_coll('Dock', s6.collection)
for name, o in dock_parts.items():
    d = o.copy(); d.name = name + '@dock'; link(d, c6)
pr = bpy.data.objects.new('DockPCBA', None); link(pr, c6); pr.location = Vector((0, 0, L_DOCK_PCB_Z)) * MM
for o in dock_objs:
    if o.type == 'MESH':
        d = o.copy(); link(d, c6); d.parent = pr; d.matrix_parent_inverse = Matrix.Identity(4); d.matrix_basis = o.matrix_world.copy()
spare = pod_instance(c6, 'R', origin=Vector((-38, 4, 9.2)) * MM, rot=Matrix.Rotation(math.pi, 4, 'X'),
                     names=['03_BatteryCartridgeCup', '04_BatteryCartridgeLid', 'Cell_LP502030', 'CartridgeStripPCB', 'ContactPlates'],
                     with_pcb=False)
tgt = Vector((12, 14, 6)) * MM
studio(s6, tgt, 0.35); camera(s6, tgt + Vector((-0.085, -0.165, 0.145)), tgt, 60); shots.append(s6)

# 7. right insole flex (H1) laid on the 1:1 insert outline; in the product it is laminated inside the insert
s7 = new_scene('07_Insole_Flex'); c7 = new_coll('InsoleFlex_R', s7.collection)
ins7 = insole('R', c7); ins7.location = Vector((0, 0, 0))
fr = bpy.data.objects.new('InsoleFlexR', None); link(fr, c7); fr.location = Vector((0, -260, 2.85)) * MM
for o in flex_objs:
    if o.type == 'MESH':
        d = o.copy(); link(d, c7); d.parent = fr; d.matrix_parent_inverse = Matrix.Identity(4); d.matrix_basis = o.matrix_world.copy()
FSRFILM = mat('FSR ink film on spacer (translucent grey)', '#3C4146', 0.5, transmission=0.4, alpha=0.75)
for i, (x, y) in enumerate(FSR_XY):
    bpy.ops.mesh.primitive_cylinder_add(radius=7.2 * MM, depth=0.15 * MM, location=(x * MM, (y - 260) * MM, 3.05 * MM))
    f = bpy.context.active_object; f.name = f'FSR_film_P{i + 1}'
    for cc in f.users_collection: cc.objects.unlink(f)
    link(f, c7); f.data.materials.append(FSRFILM)
tgt = Vector((112, -135, 3)) * MM
studio(s7, tgt, 0.8); camera(s7, tgt + Vector((0.0, -0.20, 0.44)), tgt, 50); shots.append(s7)

def scene_bbox(sc):
    dg = bpy.context.evaluated_depsgraph_get()
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in sc.objects:
        if o.type not in ('MESH', 'CURVE', 'FONT') or o.name.startswith('Floor') or o.hide_render: continue
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c); mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn / MM, mx / MM
for sc in shots:
    for c in sc.collection.children_recursive: pass
    mn, mx = scene_bbox(sc); print('BBOX', sc.name, [round(v) for v in mn], [round(v) for v in mx], flush=True)

# ------------------------------------------------------------------ render + save
for s in shots:
    if ONLY and s.name[:2] not in ONLY: continue
    s.render.filepath = str(RENDERS / ('preview' if PREVIEW else 'raw') / f'{s.name}.png')
    bpy.ops.render.render(write_still=True, scene=s.name)
    print('rendered', s.name, flush=True)
if not PREVIEW:
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND / 'NIVA-RevC-scenes.blend'), compress=True)
    for s in shots:
        with bpy.context.temp_override(scene=s, view_layer=s.view_layers[0]):
            bpy.ops.export_scene.gltf(filepath=str(BLEND / f'{s.name}.glb'), use_active_scene=True,
                                      export_apply=True, use_visible=False)
        print('exported', s.name, flush=True)
print('scenes done')
