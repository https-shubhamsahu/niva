"""NIVA pod schematic generator, Revision C.

Builds ONE KiCad 9 project with a root sheet and two hierarchical sub-sheets:
  NIVA-pod.kicad_sch                 root: sheet symbols + interface wiring
  NIVA-controller.kicad_sch          MCU, ADC, IMU, power, insert connector
  NIVA-heel-and-indicator.kicad_sch  PVDF heel buffer + red/green status emitters

Changes from Rev B (build_niva_schematic.py):
  * Rev B never closed each placed "(symbol ...)" form, so neither file could be
    parsed by KiCad. Fixed here.
  * The two separate projects that "merged by matching net names" are now one
    hierarchy. Cross-sheet signals use hierarchical labels + sheet pins; rails use
    global power symbols (+3V3, GND, VBAT) with PWR_FLAGs where only passive
    connector pins source them.
  * Engineering corrections are listed in REVIEW_NOTES and in the README.
All coordinates are snapped to KiCad's 1.27 mm connection grid.
"""
from pathlib import Path
import uuid, json, math, copy, shutil
from sexputils import Atom, parse, dump, find, allof, resolve

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
LIB = Path('/tmp/kicadlib/symbols')          # KiCad 9.0.9 stock symbols (copied from kicad/kicad:9.0)
ESP = ROOT / 'work/espressif/Espressif.kicad_sym'
PROJECT = 'NIVA-pod'
OUT.mkdir(parents=True, exist_ok=True)

uid = lambda: str(uuid.uuid4())
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
              extra=None, unit=1, outward=None):
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
                f'(in_bom {"no" if power else "yes"}) (on_board {"no" if power else "yes"}) (dnp no) (uuid "{u}")'
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
        if unit == 1:
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

# ---------------------------------------------------------------- sheet 2: controller
RFP = 'Resistor_SMD:R_0603_1608Metric'; CFP = 'Capacitor_SMD:C_0603_1608Metric'; C0805 = 'Capacitor_SMD:C_0805_2012Metric'
ctl = Sch('NIVA-controller', 'NIVA pod | Controller, acquisition, power, insert interface | Rev C', 'A2', 2,
          hier=['PVDF_RAW', 'PIEZO_ADC', 'LED_R', 'LED_G'])
ctl.hier_shape = {'PVDF_RAW': 'output', 'PIEZO_ADC': 'input', 'LED_R': 'output', 'LED_G': 'output'}
sch = ctl
def R(ref, value, x, y, n1, n2, fp=RFP): sch.place('Device:R', ref, value, x, y, {'1': n1, '2': n2}, fp)
def C(ref, value, x, y, n1, n2, fp=CFP): sch.place('Device:C', ref, value, x, y, {'1': n1, '2': n2}, fp)

ctl.text(200, 16, 'NIVA POD / CONTROLLER + ACQUISITION / REV C ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 3)
ctl.text(40, 28, '01  ESP32-C3 MODULE, BOOT STRAPS, SERVICE', 2)
u1 = {str(n): 'GND' for n in [1, 2, 11, 14] + list(range(36, 54))}
u1.update({'3': '+3V3', '5': 'I2C_SCL', '6': 'BUTTON', '8': 'CHIP_EN', '12': 'I2C_SDA', '13': 'IMU_INT1',
           '16': 'CS_IMU', '18': 'SPI_SCK', '19': 'SPI_MISO', '20': 'SPI_MOSI', '21': 'CS_ADC', '22': 'BOOT8',
           '23': 'BOOT9', '26': 'USB_DM', '27': 'USB_DP', '30': 'LED_R', '31': 'LED_G'})
ctl.place('Espressif:ESP32-C3-MINI-1', 'U1', 'ESP32-C3-MINI-1-N4', 95, 97, u1, 'NIVA:ESP32-C3-MINI-1',
          extra={'MPN': 'ESP32-C3-MINI-1-N4', 'Datasheet': 'https://documentation.espressif.com/esp32-c3-mini-1_datasheet_en.pdf'})
for ref, val, net, x in [('R1', '10k', 'CHIP_EN', 40), ('R2', '10k', 'BOOT8', 60), ('R3', '10k', 'BOOT9', 80),
                         ('R4', '4.7k', 'I2C_SCL', 100), ('R5', '4.7k', 'I2C_SDA', 120), ('R6', '10k', 'BUTTON', 140)]:
    R(ref, val, x, 172, '+3V3', net)
C('C1', '1u', 40, 200, 'CHIP_EN', 'GND'); C('C2', '22u 6.3V X5R', 60, 200, '+3V3', 'GND', C0805)
C('C3', '100n', 80, 200, '+3V3', 'GND')
ctl.place('Switch:SW_Push', 'SW1', 'KMR221G (C&K KMR2)', 165, 200, {'1': 'BUTTON', '2': 'GND'},
          'Button_Switch_SMD:SW_Push_1P1T_NO_CK_KMR2')
ctl.place('Connector_Generic:Conn_01x06', 'J3', 'SERVICE PADS (TC2030-NL, underside)', 205, 190,
          {'1': '+3V3', '2': 'CHIP_EN', '3': 'USB_DP', '4': 'USB_DM', '5': 'BOOT9', '6': 'GND'},
          'Connector:Tag-Connect_TC2030-IDC-NL_2x03_P1.27mm_Vertical')
ctl.text_block(35, 222, [
    'GPIO map (Rev C review of Rev B): IO0 I2C_SDA, IO2 I2C_SCL (strap: 4.7k pull-up keeps it high at reset), IO3 BUTTON,',
    'IO1 IMU_INT1, IO4/5/6 SPI SCK/MISO/MOSI, IO7 CS_ADC, IO10 CS_IMU, IO20 LED_R, IO21 LED_G, IO18/19 USB (service only).',
    'IO9 = BOOT strap (10k pull-up, pulled low only by the service jig). IO8 = strap pull-up, otherwise a spare pin.',
    'IO21 is U0TXD: the ROM boot log will flicker the green emitter at reset. Accepted for the prototype; firmware logs via USB.',
    'J3 pin 1 is sense-only for the jig. The jig must NOT back-feed +3V3 into the regulator output; power from the cartridge.',
    'J3 sits on the board underside and is reached through the empty cartridge bay. It has no charging function.'], 1.1)

ctl.text(250, 28, '02  12-BIT ADC + INERTIAL SENSOR (SHARED SPI)', 2)
adc = {str(i): f'F{i}_ADC' for i in range(1, 6)}
adc.update({'6': 'PIEZO_ADC', '7': 'VEXC_HALF', '8': 'INSERT_ID', '9': 'GND', '10': 'CS_ADC', '11': 'SPI_MOSI',
            '12': 'SPI_MISO', '13': 'SPI_SCK', '14': 'GND', '15': '+3V3', '16': '+3V3'})
ctl.place('Analog_ADC:MCP3208', 'U2', 'MCP3208-CI/SL', 265, 75, adc, 'Package_SO:SOIC-16_3.9x9.9mm_P1.27mm',
          extra={'MPN': 'MCP3208-CI/SL', 'Datasheet': 'https://ww1.microchip.com/downloads/en/DeviceDoc/21298e.pdf'})
C('C4', '100n', 245, 118, '+3V3', 'GND'); C('C19', '1u', 265, 118, '+3V3', 'GND')
ctl.text_block(235, 132, ['C4 at VDD pin 16, C19 at VREF pin 15. VREF = +3V3, so force and ID readings are',
                          'ratiometric; CH6 (VEXC/2) is read every block to detect excitation faults.'], 1.1)
imu = {'1': 'SPI_MISO', '2': 'GND', '3': 'GND', '4': 'IMU_INT1', '5': '+3V3', '6': 'GND', '7': 'GND', '8': '+3V3',
       '12': 'CS_IMU', '13': 'SPI_SCK', '14': 'SPI_MOSI'}
ctl.place('NIVA:LSM6DSO32', 'U3', 'LSM6DSO32TR', 420, 75, imu, 'Package_LGA:LGA-14_3x2.5mm_P0.5mm_LayoutBorder3x4y',
          extra={'MPN': 'LSM6DSO32TR'})
C('C5', '100n', 400, 118, '+3V3', 'GND'); C('C20', '100n', 420, 118, '+3V3', 'GND')
ctl.text_block(385, 132, ['C5 at VDD pin 8, C20 at VDDIO pin 5. SDx/SCx tied to GND, OCS_Aux/SDO_Aux and INT2 open,',
                          'per ST datasheet pin table (confirm against DS13210 rev before release).',
                          'IMU is placed near a board screw for rigidity; axis orientation recorded on the PCB silk.'], 1.1)

ctl.text(250, 160, '03  POWER FROM REMOVABLE CARTRIDGE (NO CHARGER ON THIS BOARD)', 2)
ctl.place('Regulator_Linear:TLV75533PDBV', 'U5', 'TLV75533PDBVR', 300, 185,
          {'1': 'VBAT', '2': 'GND', '3': 'VBAT', '5': '+3V3'}, 'Package_TO_SOT_SMD:SOT-23-5', extra={'MPN': 'TLV75533PDBVR'})
C('C6', '4.7u 10V X5R', 265, 205, 'VBAT', 'GND'); C('C7', '10u 6.3V X5R', 330, 205, '+3V3', 'GND')
C('C8', '100n', 345, 205, '+3V3', 'GND')
ctl.place('NIVA:MAX17048', 'U6', 'MAX17048G+T10', 420, 190,
          {'1': 'GND', '2': 'VBAT', '3': 'VBAT', '4': 'GND', '6': 'GND', '7': 'I2C_SCL', '8': 'I2C_SDA', '9': 'GND'},
          'Package_DFN_QFN:TDFN-8-1EP_2x2mm_P0.5mm_EP0.8x1.2mm', extra={'MPN': 'MAX17048G+T10'})
C('C9', '100n', 400, 222, 'VBAT', 'GND')
ctl.place('Connector_Generic:Conn_01x04', 'J2', 'CARTRIDGE SPRING CONTACTS (part to select)', 520, 185,
          {'1': 'VBAT', '2': 'VBAT', '3': 'GND', '4': 'GND'}, 'NIVA:SpringContact_1x04_P2.54mm_Vertical_SMD')
ctl.flag(505, 215, 'VBAT'); ctl.flag(520, 215, 'GND')
ctl.text_block(250, 236, [
    'Dropout check: TLV755P max dropout 238 mV at 500 mA (datasheet); scale roughly with load. ESP-NOW/Wi-Fi TX bursts can',
    'reach a few hundred mA, so cell IR + contact resistance + dropout set the usable cut-off. Firmware must stop recording',
    'at a gauge-reported threshold set from measured sag (bench item P1). C6 input, C7/C8 + C2/C3 output bulk.',
    'J2: 2 x VBAT + 2 x GND spring contacts land on pads on the cartridge lid. Cell protection (e.g. BQ2970) lives in',
    'the cartridge; charging, NTC and pack ID belong to the separate dock (not designed here).'], 1.1)

ctl.text(40, 262, '04  PASSIVE INSERT INTERFACE / FIVE DIVIDER CHANNELS (BENCH TOPOLOGY, NOT A201 REFERENCE CIRCUIT)', 2)
j1 = {'1': 'VEXC', '7': 'PVDF_RAW', '8': 'GND', '9': 'INSERT_ID_RAW', '10': 'GND'}
j1.update({str(i + 1): f'F{i}_RAW' for i in range(1, 6)})
ctl.place('Connector_Generic:Conn_01x10', 'J1', 'INSERT TAIL (JST GH 10, keyed overmould)', 40, 305, j1,
          'Connector_JST:JST_GH_SM10B-GHS-TB_1x10-1MP_P1.25mm_Horizontal', extra={'MPN': 'SM10B-GHS-TB'})
for i, x in enumerate([95, 150, 205, 260, 315], 1):
    ctl.text(x - 12, 280, f'F{i} (calibrate as built)', 1.2)
    R(f'R{10 + i}', '10k 0.1%', x, 297, f'F{i}_RAW', 'GND')
    R(f'R{20 + i}', '3.3k', x, 325, f'F{i}_RAW', f'F{i}_ADC')
    C(f'C{10 + i}', '1u X7R', x, 352, f'F{i}_ADC', 'GND')
R('R33', '22', 380, 290, '+3V3', 'VEXC'); C('C18', '1u', 400, 290, 'VEXC', 'GND')
R('R31', '10k 0.1%', 380, 320, 'VEXC', 'VEXC_HALF'); R('R32', '10k 0.1%', 400, 320, 'VEXC_HALF', 'GND')
C('C16', '100n', 420, 320, 'VEXC_HALF', 'GND')
R('R30', '10k 0.1%', 450, 290, '+3V3', 'INSERT_ID_RAW'); R('R34', '3.3k', 470, 290, 'INSERT_ID_RAW', 'INSERT_ID')
C('C17', '1u', 490, 290, 'INSERT_ID', 'GND')
ctl.text_block(40, 400, [
    'Force channel: FSR from VEXC to Fn_RAW, 10k to GND, 3.3k + 1 uF low-pass (fc = 48 Hz) to the ADC. The 1 uF reservoir',
    'is ~50,000x the MCP3208 sample capacitor, so acquisition settling is set by the RC, not the ADC source-impedance limit.',
    'Excitation is continuous (Rev B decision kept): switching it every 5 ms cannot settle a 3.3 ms RC. R33 limits a tail short',
    'to ~150 mA so the 3V3 rail survives; VEXC is sensed after R33 (Rev B sensed +3V3, which could not detect this fault).',
    'ESD at J1: every force/ID line reaches the ADC through 3.3k into a 1 uF reservoir (8 kV HBM = 0.8 uC -> ~0.8 V step).',
    'No TVS is fitted; the RC networks are the protection. System-level IEC 61000-4-2 testing is still required.',
    'Divider output is NOT the Tekscan A201 op-amp reference circuit and does not inherit its linearity or drift figures.'], 1.1)

# ---------------------------------------------------------------- sheet 3: heel + indicator
heel = Sch('NIVA-heel-and-indicator', 'NIVA pod | Heel vibration buffer and status emitters | Rev C', 'A3', 3,
           hier=['PVDF_RAW', 'PIEZO_ADC', 'LED_R', 'LED_G'])
heel.hier_shape = {'PVDF_RAW': 'input', 'PIEZO_ADC': 'output', 'LED_R': 'input', 'LED_G': 'input'}
sch = heel
heel.text(120, 16, 'NIVA POD / HEEL PVDF BUFFER + STATUS / REV C ENGINEERING PROTOTYPE', 2.5)
heel.text(30, 30, '01  MID-RAIL BIAS, INPUT PROTECTION, BUFFER', 1.8)
R('R40', '100k', 40, 60, '+3V3', 'VMID'); R('R41', '100k', 40, 90, 'VMID', 'GND'); C('C40', '1u', 60, 90, 'VMID', 'GND')
R('R42', '100k', 100, 60, 'PVDF_RAW', 'PZ_BIAS'); R('R43', '10M', 100, 95, 'VMID', 'PZ_BIAS')
heel.place('Amplifier_Operational:MCP6001-OT', 'U4', 'MCP6001T-I/OT', 190, 75,
           {'1': 'PZ_BUF', '2': 'GND', '3': 'PZ_BIAS', '4': 'PZ_BUF', '5': '+3V3'}, 'Package_TO_SOT_SMD:SOT-23-5',
           extra={'MPN': 'MCP6001T-I/OT'})
R('R44', '1k', 250, 65, 'PZ_BUF', 'PIEZO_ADC'); C('C41', '470n', 270, 90, 'PIEZO_ADC', 'GND')
C('C42', '100n', 190, 110, '+3V3', 'GND')
heel.place('Device:D_Small', 'D2', 'BAS416', 140, 60, {'1': '+3V3', '2': 'PZ_BIAS'}, 'Diode_SMD:D_SOD-323',
           extra={'MPN': 'BAS416 (low-leakage, SOD-323)'})
heel.place('Device:D_Small', 'D3', 'BAS416', 140, 95, {'1': 'PZ_BIAS', '2': 'GND'}, 'Diode_SMD:D_SOD-323',
           extra={'MPN': 'BAS416 (low-leakage, SOD-323)'})
heel.text_block(160, 128, [
    'PVDF film (~1.4 nF class) with 10M bias: high-pass ~11 Hz. R42 limits clamp current during heel-strike spikes.',
    'D2/D3 clamp the buffer input to the rails. Low-leakage diodes: leakage x 10M sets the offset budget (check datasheet).',
    'R44/C41 = 339 Hz single pole for 2 kHz sampling: only ~10 dB at Nyquist. Treat as exploratory; oversample and',
    'decimate in firmware or add a 2nd-order stage after the E3 cable-motion experiment.'], 1.1)
heel.text(30, 170, '02  STATUS EMITTERS: RED + YELLOW-GREEN UNDER ONE LIGHT WINDOW', 1.8)
R('R45', '1k', 50, 195, 'LED_R', 'LED_R_A'); R('R46', '680', 110, 195, 'LED_G', 'LED_G_A')
heel.place('Device:LED', 'D4', 'RED 0603', 50, 225, {'1': 'GND', '2': 'LED_R_A'}, 'LED_SMD:LED_0603_1608Metric')
heel.place('Device:LED', 'D5', 'YELLOW-GREEN 570nm 0603', 110, 225, {'1': 'GND', '2': 'LED_G_A'}, 'LED_SMD:LED_0603_1608Metric')
heel.text_block(160, 190, ['~1.3-1.7 mA per emitter at 3.3 V. Red + green together is read as amber.',
                           'Light-window brightness and colour separation must be checked in the printed cover.',
                           'Status colours signal recording quality only, never a clinical result.'], 1.1)

# ---------------------------------------------------------------- root sheet
root = Sch(PROJECT, 'NIVA pod | Rev C hierarchy', 'A4', 1)
root.path = '/' + root.uuid
S2, S3 = uid(), uid()
ctl.path = f'/{root.uuid}/{S2}'; heel.path = f'/{root.uuid}/{S3}'
def sheet(u, name, fname, x, y, w, h, pins, page):
    pins = [(n, sh, round(px, 4), round(py, 4), a) for n, sh, px, py, a in pins]
    s = (f'(sheet (at {x} {y}) (size {w} {h}) (exclude_from_sim no) (in_bom yes) (on_board yes) (dnp no)'
         f' (fields_autoplaced yes) (stroke (width 0.1524) (type solid)) (fill (color 0 0 0 0.0000)) (uuid "{u}")'
         f' (property "Sheetname" {q(name)} (at {x} {round(y - 0.7, 4)} 0) (effects (font (size 1.27 1.27)) (justify left bottom)))'
         f' (property "Sheetfile" {q(fname)} (at {x} {round(y + h + 0.6, 4)} 0) (effects (font (size 1.27 1.27)) (justify left top)))')
    for pname, shape, px, py, ang in pins:
        just = 'left' if ang == 180 else 'right'
        s += (f' (pin {q(pname)} {shape} (at {px} {py} {ang}) (uuid "{uid()}")'
              f' (effects (font (size 1.27 1.27)) (justify {just})))')
    s += f' (instances (project {q(PROJECT)} (path "/{root.uuid}" (page "{page}")))))'
    root.items.append(s)
cx, cy, cw, ch = 40.64, 60.96, 60.96, 50.8
hx, hy = 170.18, 60.96
names = [('PVDF_RAW', 'output', 'input'), ('PIEZO_ADC', 'input', 'output'), ('LED_R', 'output', 'input'), ('LED_G', 'output', 'input')]
sheet(S2, 'Controller', 'NIVA-controller.kicad_sch', cx, cy, cw, ch,
      [(n, a, cx + cw, cy + 10.16 + i * 7.62, 0) for i, (n, a, b) in enumerate(names)], 2)
sheet(S3, 'Heel and indicator', 'NIVA-heel-and-indicator.kicad_sch', hx, hy, 50.8, ch,
      [(n, b, hx, cy + 10.16 + i * 7.62, 180) for i, (n, a, b) in enumerate(names)], 3)
for i in range(len(names)):
    yy = round(cy + 10.16 + i * 7.62, 4); root.wire(cx + cw, yy, hx, yy)
root.text(40.64, 30.48, 'NIVA pod Rev C - one electrically connected hierarchy', 2.5)
root.text_block(40.64, 124.46, [
    'Rails +3V3, GND and VBAT are global power symbols shared by both sheets.',
    'Cross-sheet signals travel only through the four sheet pins drawn above.',
    'ENGINEERING PROTOTYPE - NOT FOR FABRICATION. See README for the open review items.'], 1.27)
ROOT_INSTANCES = '(sheet_instances (path "/" (page "1")))'

# ---------------------------------------------------------------- write project
for s in (ctl, heel): s.save()
root.save(ROOT_INSTANCES)
for old in ('NIVA-controller.kicad_pro', 'NIVA-heel-and-indicator.kicad_pro', 'component-net-map.json',
            'analog-component-net-map.json'):
    (OUT / old).unlink(missing_ok=True)
pro = json.loads((ROOT / 'work/kicad_pro_template.json').read_text())
pro['meta']['filename'] = PROJECT + '.kicad_pro'
pro['sheets'] = [[root.uuid, 'Root'], [S2, 'Controller'], [S3, 'Heel and indicator']]
(OUT / (PROJECT + '.kicad_pro')).write_text(json.dumps(pro, indent=2))

# Project symbol library: the same objects embedded in the sheets, so KiCad sees no library mismatch.
libtxt = '(kicad_symbol_lib (version 20241209) (generator "niva_revC") (generator_version "9.0") '
libtxt += ' '.join(dump(a) for a in custom.values()) + ')'
(OUT / 'NIVA.kicad_sym').write_text(libtxt, encoding='utf8')
esp = kicad9(resolve(ESP, 'ESP32-C3-MINI-1'))
(OUT / 'Espressif.kicad_sym').write_text('(kicad_symbol_lib (version 20241209) (generator "niva_revC") '
                                          '(generator_version "9.0") ' + dump(esp) + ')', encoding='utf8')
(OUT / 'sym-lib-table').write_text(
    '(sym_lib_table (version 7)\n'
    '  (lib (name "NIVA")(type "KiCad")(uri "${KIPRJMOD}/NIVA.kicad_sym")(options "")(descr "NIVA custom symbols"))\n'
    '  (lib (name "Espressif")(type "KiCad")(uri "${KIPRJMOD}/Espressif.kicad_sym")(options "")'
    '(descr "Official Espressif KiCad symbols, github.com/espressif/kicad-libraries, CC-BY-SA 4.0"))\n)\n')
(OUT / 'fp-lib-table').write_text(
    '(fp_lib_table (version 7)\n'
    '  (lib (name "NIVA")(type "KiCad")(uri "${KIPRJMOD}/NIVA.pretty")(options "")'
    '(descr "Official Espressif ESP32-C3-MINI-1 footprint + NIVA spring-contact placeholder"))\n)\n')

# NIVA footprint library: official Espressif module footprint (unchanged) + spring-contact placeholder.
FPL = OUT / 'NIVA.pretty'; FPL.mkdir(exist_ok=True)
shutil.copy(ROOT / 'work/espressif/ESP32-C3-MINI-1.kicad_mod', FPL / 'ESP32-C3-MINI-1.kicad_mod')
pads = ''.join(f'(pad "{i + 1}" smd rect (at {(i - 1.5) * 2.54:.2f} 0) (size 1.6 2.4) (layers "F.Cu" "F.Paste" "F.Mask") (uuid "{uid()}"))\n'
               for i in range(4))
fx = lambda sz: f'(effects (font (size {sz} {sz}) (thickness 0.12)))'
(FPL / 'SpringContact_1x04_P2.54mm_Vertical_SMD.kicad_mod').write_text(
    f'(footprint "SpringContact_1x04_P2.54mm_Vertical_SMD" (version 20241229) (generator "niva_revC") (generator_version "9.0")\n'
    f'(layer "F.Cu")\n(descr "PLACEHOLDER land pattern for a 4-position vertical spring-loaded (pogo) contact block, 2.54 mm pitch, '
    f'~3 mm working height. NOT a specific supplier part: select part, then replace pads with the supplier land pattern.")\n'
    f'(tags "spring contact pogo battery cartridge placeholder")\n'
    f'(property "Reference" "REF**" (at 0 -2.6 0) (layer "F.SilkS") (uuid "{uid()}") {fx(0.8)})\n'
    f'(property "Value" "SpringContact_1x04" (at 0 2.6 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.8)})\n'
    f'(property "Footprint" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.27)})\n'
    f'(property "Datasheet" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.27)})\n'
    f'(property "Description" "Placeholder - part to select" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.27)})\n'
    f'(attr smd)\n'
    f'(fp_rect (start -5.6 -1.6) (end 5.6 1.6) (stroke (width 0.1) (type default)) (fill no) (layer "F.Fab") (uuid "{uid()}"))\n'
    f'(fp_text user "PART TO SELECT" (at 0 0 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.5)})\n'
    f'(fp_line (start -5.75 -1.75) (end 5.75 -1.75) (stroke (width 0.12) (type default)) (layer "F.SilkS") (uuid "{uid()}"))\n'
    f'(fp_line (start -5.75 1.75) (end 5.75 1.75) (stroke (width 0.12) (type default)) (layer "F.SilkS") (uuid "{uid()}"))\n'
    f'(fp_circle (center -5.3 -2.2) (end -5.1 -2.2) (stroke (width 0.12) (type default)) (fill yes) (layer "F.SilkS") (uuid "{uid()}"))\n'
    f'(fp_rect (start -6.0 -2.0) (end 6.0 2.0) (stroke (width 0.05) (type default)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n'
    f'{pads}(model "${{KIPRJMOD}}/3dmodels/NIVA_SpringContact_1x04_ENVELOPE.step" (offset (xyz 0 0 0)) (scale (xyz 1 1 1)) (rotate (xyz 0 0 0)))\n)\n')

parts = ctl.parts + heel.parts
(OUT / 'component-net-map.json').write_text(json.dumps(parts, indent=2))
(OUT / 'pin-map.csv').write_text('Sheet,Reference,Value,Footprint,Pin,Net\n' + '\n'.join(
    f'{p["sheet"]},{p["ref"]},"{p["value"]}",{p["footprint"]},{pin},{net}' for p in parts for pin, net in p['nets'].items()) + '\n')
print('Rev C hierarchy written:', len(ctl.parts), 'controller parts +', len(heel.parts), 'heel/indicator parts')
