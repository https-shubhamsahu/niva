"""Shared KiCad 9 schematic writer for the NIVA generators (pod, cartridge, dock).

Extracted from build_niva_schematic_revC.py so every NIVA project uses the same, ERC-checked
symbol placement, power-symbol, hierarchical-label and deterministic-UUID code.
Callers set niva_kisch.PROJECT and niva_kisch.OUT before creating sheets.
"""
from pathlib import Path
import uuid, json, math, copy, shutil, os
from sexputils import Atom, parse, dump, find, allof, resolve

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
# KiCad 9 stock symbols: $KICAD9_SYMBOL_DIR, else the portable KiCad under work/tools3d, else a local copy.
# Only KiCad 9 libraries (format >= 20241209) are accepted: embedding older copies triggers lib_symbol_mismatch.
def _is_kicad9(d):
    f = Path(d, 'Device.kicad_sym')
    if not (d and f.exists()): return False
    import re as _re; m = _re.search(r'\(version (\d+)\)', f.read_text(encoding='utf8')[:300]); return bool(m and int(m.group(1)) >= 20241209)
LIB = next(Path(p) for p in [os.environ.get('KICAD9_SYMBOL_DIR', ''), ROOT / 'work/tools3d/kicad/share/kicad/symbols',
                               '/usr/share/kicad/symbols', '/tmp/kicadlib/symbols'] if _is_kicad9(p))
ESP = ROOT / 'work/espressif/Espressif.kicad_sym'
PROJECT = 'NIVA-pod'
OUT.mkdir(parents=True, exist_ok=True)

_NS = uuid.UUID('6f1c2a44-9a3e-4d0b-8c1e-4e49564152c3'); _seq = iter(range(10 ** 9))
uid = lambda: str(uuid.uuid5(_NS, str(next(_seq))))     # deterministic: reruns keep symbol/sheet UUIDs stable
q = lambda s: json.dumps(str(s))
FX = lambda size=1.27: f'(effects (font (size {size} {size})))'
G = 1.27
snap = lambda v: round(round(v / G) * G, 4)

# ---------------------------------------------------------------- custom symbols
custom = {}
def chip(name, pins, ref='U', fp='', datasheet='', descr=''):
    left = pins[:(len(pins) + 1) // 2]; right = pins[(len(pins) + 1) // 2:]
    n = max(len(left), len(right)); half = (n + 1) * G
    g = (f'(symbol "{name}" (pin_names (offset 0.508)) (exclude_from_sim no) (in_bom yes) (on_board yes)'
         f' (property "Reference" "{ref}" (at 0 {half + 2.54} 0) {FX()})'
         f' (property "Value" "{name}" (at 0 {-half - 2.54} 0) {FX()})'
         f' (property "Footprint" {q(fp)} (at 0 0 0) (effects (font (size 1.27 1.27)) (hide yes)))'
         f' (property "Datasheet" {q(datasheet)} (at 0 0 0) (effects (font (size 1.27 1.27)) (hide yes)))'
         f' (property "Description" {q(descr)} (at 0 0 0) (effects (font (size 1.27 1.27)) (hide yes)))'
         f' (symbol "{name}_0_1" (rectangle (start -10.16 {half}) (end 10.16 {-half})'
         f' (stroke (width 0.254) (type default)) (fill (type background)))))')
    a = parse(g); body = [Atom('symbol'), name + '_1_1']
    for side, group in [(-1, left), (1, right)]:
        for i, (num, nam, kind) in enumerate(group):
            y = round(half - 2.54 - i * 2.54, 4); x = side * 15.24; ang = 0 if side == -1 else 180
            body.append(parse(f'(pin {kind} line (at {x} {y} {ang}) (length 5.08)'
                              f' (name {q(nam)} {FX()}) (number {q(num)} {FX()}))'))
    a.append(body); custom[name] = a

# LSM6DSO32 is pin-compatible with the LGA-14 LSM6DSx family; pin functions from ST DS13210.
chip('LSM6DSO32', [('1', 'SDO/SA0', 'bidirectional'), ('2', 'SDx', 'bidirectional'), ('3', 'SCx', 'input'),
                   ('4', 'INT1', 'output'), ('5', 'VDDIO', 'power_in'), ('6', 'GND', 'power_in'),
                   ('7', 'GND', 'power_in'), ('8', 'VDD', 'power_in'), ('9', 'INT2', 'output'),
                   ('10', 'OCS_Aux', 'passive'), ('11', 'SDO_Aux', 'bidirectional'), ('12', 'CS', 'input'),
                   ('13', 'SCL/SPC', 'input'), ('14', 'SDA/SDI', 'bidirectional')],
     fp='Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y',
     datasheet='https://www.st.com/resource/en/datasheet/lsm6dso32.pdf',
     descr='6-axis IMU, +/-32 g accelerometer, SPI/I2C, LGA-14 2.5x3 mm')
chip('MAX17048', [('1', 'CTG', 'input'), ('2', 'CELL', 'power_in'), ('3', 'VDD', 'power_in'),
                  ('4', 'GND', 'power_in'), ('5', '~{ALRT}', 'open_collector'), ('6', 'QSTRT', 'input'),
                  ('7', 'SCL', 'input'), ('8', 'SDA', 'bidirectional'), ('9', 'EP', 'passive')],
     fp='Package_DFN_QFN:TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm',
     datasheet='https://www.analog.com/media/en/technical-documentation/data-sheets/max17048-max17049.pdf',
     descr='1-cell ModelGauge fuel gauge, I2C, 2x2 mm TDFN-8')

# The official Espressif library (github.com/espressif/kicad-libraries, 2026-07 snapshot) is saved by
# KiCad 10 (format 20251024). KiCad 9.0.9 rejects these presentation-only tokens, so strip them.
KICAD10_ONLY = {'show_name', 'do_not_autoplace', 'in_pos_files', 'duplicate_pin_numbers_are_jumpers'}
def kicad9(a):
    return [kicad9(v) if isinstance(v, list) else v for v in a
            if not (isinstance(v, list) and v and v[0] in KICAD10_ONLY)]

# ---------------------------------------------------------------- schematic sheet
POWER = {'+3V3': 'power:+3V3', 'GND': 'power:GND', 'VBAT': 'power:+BATT'}

class Sch:
    counters = {'#PWR': 0, '#FLG': 0}
    def __init__(self, name, title, paper, page, hier=()):
        self.name = name; self.title = title; self.paper = paper; self.page = page
        self.uuid = uid(); self.libs = {}; self.items = []; self.parts = []; self.hier = set(hier)
        self.path = None                      # set once the root sheet knows the sheet-symbol uuid
    def text(self, x, y, txt, size=1.6):
        self.items.append(f'(text {q(txt)} (exclude_from_sim no) (at {snap(x)} {round(y, 3)} 0) '
                          f'(effects (font (size {size} {size})) (justify left bottom)) (uuid "{uid()}"))')
    def wire(self, x1, y1, x2, y2):
        self.items.append(f'(wire (pts (xy {x1} {y1}) (xy {x2} {y2})) (stroke (width 0) (type default)) (uuid "{uid()}"))')
    def lib(self, libid):
        if libid in self.libs: return self.libs[libid]
        lib, nam = libid.split(':')
        if lib == 'NIVA': a = copy.deepcopy(custom[nam])
        elif lib == 'Espressif': a = kicad9(resolve(ESP, nam))
        else: a = resolve(LIB / (lib + '.kicad_sym'), nam)
        a[1] = libid; self.libs[libid] = a; return a
    def netlabel(self, x, y, net, ang):
        """Terminate a pin stub with a power symbol, hierarchical label or local label."""
        if net in POWER:
            self.place(POWER[net], None, net, x, y, {'1': net}, stub=False, power=True); return
        just = 'left' if ang in (0,) else 'right'
        if net in self.hier:
            self.items.append(f'(hierarchical_label {q(net)} (shape {self.hier_shape[net]}) (at {x} {y} {ang}) '
                              f'(effects (font (size 1.27 1.27)) (justify {just})) (uuid "{uid()}"))')
        else:
            self.items.append(f'(label {q(net)} (at {x} {y} {ang}) (effects (font (size 1.27 1.27)) '
                              f'(justify {just} bottom)) (uuid "{uid()}"))')
    def flag(self, x, y, net):
        """PWR_FLAG on a rail that is only sourced through passive connector pins."""
        x, y = snap(x), snap(y)
        if net == 'GND':   # flag above, ground symbol hanging below
            self.place('power:PWR_FLAG', None, 'PWR_FLAG', x, y, {'1': net}, stub=False, power=True, flag=True)
            self.place(POWER[net], None, net, x, y + 2.54, {'1': net}, stub=False, power=True)
        else:              # rail symbol above, flag hanging below
            self.place(POWER[net], None, net, x, y, {'1': net}, stub=False, power=True)
            self.place('power:PWR_FLAG', None, 'PWR_FLAG', x, y + 2.54, {'1': net}, stub=False, power=True,
                       flag=True, rotation=180)
        self.wire(x, y, x, y + 2.54)
    def place(self, libid, ref, value, x, y, nets, footprint='', rotation=0, stub=True, power=False, flag=False,
              extra=None, unit=1, outward=None, bom=True):
        a = self.lib(libid); x, y = snap(x), snap(y)
        pins = []
        for sub in allof(a, 'symbol'):
            if int(sub[1].rsplit('_', 2)[1]) not in (0, unit): continue   # NAME_<unit>_<style>
            for p in allof(sub, 'pin'):
                pos = find(p, 'at')
                pins.append((find(p, 'number')[1], float(pos[1]), float(pos[2]), float(pos[3])))
        if power:
            key = '#FLG' if flag else '#PWR'; Sch.counters[key] += 1
            ref = f'{key}{Sch.counters[key]:02d}'
        u = uid(); half = max([abs(p[2]) for p in pins] + [2.54])
        if ref[0] in 'RCDL' and not ref.startswith('#'):
            rx, ry, vy = x + 2.54, y - 0.64, y + 1.91
        elif power:
            d = outward or ('down' if value == 'GND' or flag else 'up')
            ox, oy = {'left': (-6.0, 0), 'right': (6.0, 0), 'up': (0, -5.0), 'down': (0, 5.0)}[d]
            rx, ry, vy = x + ox, y + oy, y + oy
            if flag and rotation == 180: vy = y + 5.0
        else:
            rx, ry, vy = x, y - half - 3.81, y + half + 3.81
        hide = '(hide yes)' if power else ''
        vhide = '(hide yes)' if power and value == 'GND' and outward in ('left', 'right') else ''
        just = '(justify left)' if ref[0] in 'RCDL' and not power else ''
        rx, ry, vy = round(rx, 4), round(ry, 4), round(vy, 4)
        body = (f'(symbol (lib_id {q(libid)}) (at {x} {y} {rotation}) (unit {unit}) (exclude_from_sim no) '
                f'(in_bom {"no" if power or not bom else "yes"}) (on_board {"no" if power else "yes"}) (dnp no) (uuid "{u}")'
                f' (property "Reference" {q(ref)} (at {rx} {ry} 0) (effects (font (size 1.27 1.27)) {just} {hide}))'
                f' (property "Value" {q(value)} (at {rx if not power else x} {vy} 0) (effects (font (size 1.27 1.27)) {just} {vhide}))'
                f' (property "Footprint" {q(footprint)} (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))')
        for k, v in (extra or {}).items():
            body += f' (property {q(k)} {q(v)} (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))'
        for num, *_ in pins: body += f' (pin {q(num)} (uuid "{uid()}"))'
        body += ' (instances (project {} (path "@PATH@" (reference {}) (unit {})))))'.format(q(PROJECT), q(ref), unit)
        self.items.append(body)
        if not stub: return
        done = set()
        for num, px, py, ang in pins:
            th = math.radians(rotation)
            xx = round(x + px * math.cos(th) - py * math.sin(th), 4)
            yy = round(y - px * math.sin(th) - py * math.cos(th), 4)
            if (xx, yy) in done: continue
            done.add((xx, yy)); net = nets.get(str(num))
            if not net:
                self.items.append(f'(no_connect (at {xx} {yy}) (uuid "{uid()}"))'); continue
            a2 = math.radians(ang + rotation)
            ex = round(xx - 5.08 * math.cos(a2), 4); ey = round(yy + 5.08 * math.sin(a2), 4)
            self.wire(xx, yy, ex, ey)
            dirn = 0 if math.cos(a2) < -.5 else 180 if math.cos(a2) > .5 else (90 if math.sin(a2) < 0 else 270)
            if net in POWER:
                # orient the power symbol outward along the stub (KiCad rotations are CCW, screen y down)
                out = {0: 'left', 180: 'right', 90: 'up', 270: 'down'}[dirn]
                rot = ({'left': 270, 'right': 90, 'up': 180, 'down': 0} if net == 'GND' else
                       {'left': 90, 'right': 270, 'up': 0, 'down': 180})[out]
                self.place(POWER[net], None, net, ex, ey, {'1': net}, stub=False, power=True, rotation=rot,
                           outward=out)
            else:
                self.netlabel(ex, ey, net, dirn)
        if power:
            pass
        elif unit == 1:
            self.parts.append(dict(ref=ref, value=value, footprint=footprint, nets=dict(nets), uuid=u,
                                   sheet=self.name, **(extra or {})))
        else:
            next(p for p in self.parts if p['ref'] == ref)['nets'].update(nets)
    def text_block(self, x, y, lines, size=1.27):
        for i, s in enumerate(lines): self.text(x, y + i * 2.0 * size, s, size)
    def save(self, sheet_instances=''):
        txt = (f'(kicad_sch (version 20250114) (generator "eeschema") (generator_version "9.0") (uuid "{self.uuid}")'
               f' (paper "{self.paper}") (title_block (title {q(self.title)}) (date "2026-09-28")'
               f' (rev "C - ENGINEERING PROTOTYPE") (company "NIVA")'
               f' (comment 1 "NOT FOR FABRICATION. Values, protection and layout require bench validation.")'
               f' (comment 2 "Generated by work/build_niva_schematic_revC.py"))')
        txt += '\n(lib_symbols ' + ' '.join(dump(a) for a in self.libs.values()) + ')\n'
        txt += '\n'.join(i.replace('@PATH@', self.path) for i in self.items)
        txt += sheet_instances + ' (embedded_fonts no))'
        (OUT / (self.name + '.kicad_sch')).write_text(txt, encoding='utf8')

