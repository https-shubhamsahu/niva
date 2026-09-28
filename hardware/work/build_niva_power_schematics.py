"""NIVA cartridge interconnect board and charging dock: KiCad 9 schematics (Rev C.1).

Two single-sheet projects, written with the shared niva_kisch writer:
  electronics/cartridge/NIVA-cartridge.kicad_sch   strip PCB inside the battery cartridge
  electronics/dock/NIVA-dock.kicad_sch             USB-C charging dock for bare cartridges

Safety architecture (no firmware in the safety path):
  1. Cell: EEMB LP502030 class with integrated protection module (over-charge, over-discharge,
     over-current, short circuit) and NTC lead.
  2. Cartridge: series polyfuse between the cell and every external contact (pod plates and dock pads).
  3. Dock: MCP73831 linear charger, 4.20 V, I_REG = 1000 V / R_PROG = 100 mA (~0.43 C of 230 mAh min).
     PROG is grounded only through Q1; an LM393 window on the pack NTC turns Q1 off outside ~0-45 C,
     with the NTC open (no cartridge) or shorted. A floating PROG disables the MCP73831 (datasheet).
  4. Mechanics: the pod has no charge input; only a bare cartridge fits the dock well; the cartridge
     screw is hidden by the cradle while worn.
"""
from pathlib import Path
import json, shutil
import niva_kisch as K
from niva_kisch import *
import niva_layout as L

BASE = ROOT / 'outputs/NIVA-3D-engineering-prototype/electronics'
K.POWER.update({'VBUS': 'power:VBUS'})
RFP = 'Resistor_SMD:R_0603_1608Metric'; CFP = 'Capacitor_SMD:C_0603_1608Metric'; C0805 = 'Capacitor_SMD:C_0805_2012Metric'

def footprints(folder):
    """Project-local footprints: wire solder pads, gold contact pads and a spring-pin placeholder."""
    folder.mkdir(parents=True, exist_ok=True)
    fx = lambda sz: f'(effects (font (size {sz} {sz}) (thickness {round(sz * 0.15, 3)})))'
    def fp(name, descr, pads, body, model=None, attr='smd'):
        w, h = body
        txt = (f'(footprint "{name}" (version 20241229) (generator "niva_revC") (generator_version "9.0")\n(layer "F.Cu")\n'
               f'(descr {q(descr)})\n'
               f'(property "Reference" "REF**" (at 0 {-h / 2 - 1.0} 0) (layer "F.SilkS") (uuid "{uid()}") {fx(0.6)})\n'
               f'(property "Value" {q(name)} (at 0 {h / 2 + 1.0} 0) (layer "F.Fab") (uuid "{uid()}") {fx(0.5)})\n'
               f'(property "Footprint" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(property "Datasheet" "" (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(property "Description" {q(descr)} (at 0 0 0) (layer "F.Fab") (hide yes) (uuid "{uid()}") {fx(1.0)})\n'
               f'(attr {attr})\n'
               f'(fp_rect (start {-w / 2} {-h / 2}) (end {w / 2} {h / 2}) (stroke (width 0.1) (type default)) (fill no) (layer "F.Fab") (uuid "{uid()}"))\n'
               f'(fp_rect (start {-w / 2 - 0.25} {-h / 2 - 0.25}) (end {w / 2 + 0.25} {h / 2 + 0.25}) (stroke (width 0.05) (type default)) (fill no) (layer "F.CrtYd") (uuid "{uid()}"))\n')
        for num, x, y, shape, sx, sy, layers in pads:
            txt += f'(pad "{num}" smd {shape} (at {x} {y}) (size {sx} {sy}) (layers {layers}) (uuid "{uid()}"))\n'
        if model: txt += f'(model "${{KIPRJMOD}}/3dmodels/{model}" (offset (xyz 0 0 0)) (scale (xyz 1 1 1)) (rotate (xyz 0 0 0)))\n'
        (folder / f'{name}.kicad_mod').write_text(txt + ')\n')
    CU = '"F.Cu" "F.Mask"'; CUP = '"F.Cu" "F.Paste" "F.Mask"'
    fp('WirePads_1x03_P1.8mm', 'Solder pads for three 30 AWG leads (cell +, -, NTC)',
       [(str(i + 1), 0, (i - 1) * 1.8, 'rect', 1.5, 1.1, CU) for i in range(3)], (1.7, 4.9))
    fp('WirePads_1x04_P1.7mm', 'Solder pads for four leads to the lid contact plates',
       [(str(i + 1), 0, (i - 1.5) * 1.7, 'rect', 1.5, 1.0, CU) for i in range(4)], (1.7, 6.1))
    fp('ContactPads_1x03_P6.0mm', 'Gold (ENIG) dock contact pads, reached through the cartridge floor; place on B.Cu',
       [(str(i + 1), 0, (i - 1) * 6.0, 'circle', 2.0, 2.0, CU) for i in range(3)], (2.4, 14.4))
    fp('SpringPins_1x03_P6.0mm_Vertical', 'PLACEHOLDER: three single spring-loaded contacts, ~4.5 mm free height, '
       'part to select; replace pads with the supplier land pattern', [(str(i + 1), 0, (i - 1) * 6.0, 'rect', 1.8, 1.8, CUP) for i in range(3)],
       (2.4, 14.4), 'NIVA_SpringPin_1x03_ENVELOPE.step')

def project(folder, name, sheet, parts_note):
    pro = json.loads((ROOT / 'work/kicad_pro_template.json').read_text())
    pro['meta']['filename'] = name + '.kicad_pro'; pro['sheets'] = [[sheet.uuid, 'Root']]
    base = pro['net_settings']['classes'][0]
    def nc(n, t, c, pr):
        d = dict(base); d.update(name=n, track_width=t, clearance=c, via_diameter=0.6, via_drill=0.3, priority=pr); return d
    pro['net_settings']['classes'] = [nc('Default', 0.2, 0.15, 2147483647), nc('Power', 0.4, 0.2, 0)]
    pro['net_settings']['netclass_patterns'] = [{'netclass': 'Power', 'pattern': n} for n in parts_note]
    pro['net_settings']['netclass_assignments'] = None
    pro['board']['design_settings']['rules'].update(min_clearance=0.15, min_track_width=0.15, min_via_diameter=0.5,
        min_through_hole_diameter=0.25, min_via_annular_width=0.1, min_copper_edge_clearance=0.25, min_hole_to_hole=0.25,
        min_hole_clearance=0.2)
    (folder / (name + '.kicad_pro')).write_text(json.dumps(pro, indent=2))
    (folder / 'fp-lib-table').write_text('(fp_lib_table (version 7)\n  (lib (name "NIVA_power")(type "KiCad")'
                                         '(uri "${KIPRJMOD}/NIVA_power.pretty")(options "")(descr "NIVA contact and pad footprints"))\n)\n')

def single_sheet(folder, name, title, paper='A4'):
    K.PROJECT = name; K.OUT = folder; folder.mkdir(parents=True, exist_ok=True)
    s = Sch(name, title, paper, 1); s.path = '/' + s.uuid; return s

# ================================================================ cartridge interconnect strip
cdir = BASE / 'cartridge'; footprints(cdir / 'NIVA_power.pretty')
cart = single_sheet(cdir, 'NIVA-cartridge', 'NIVA battery cartridge | interconnect strip + polyfuse | Rev C.1')
cart.text(20, 18, 'NIVA CARTRIDGE INTERCONNECT - ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 2.2)
cart.place('Connector_Generic:Conn_01x03', 'J1', 'CELL LEADS (+, NTC, -)', 40, 70,
           {'1': 'CELL_P', '2': 'NTC', '3': 'PACK_N'}, 'NIVA_power:WirePads_1x03_P1.8mm')
cart.place('Device:Polyfuse', 'F1', 'PTC 0805 hold>=0.5 A, >=6 V', 90, 60, {'1': 'CELL_P', '2': 'PACK_P'},
           'Fuse:Fuse_0805_2012Metric', extra={'MPN': 'to select (e.g. 0805 resettable, I_hold 0.5 A, V_max >= 6 V)'})
cart.place('Connector_Generic:Conn_01x04', 'J2', 'TO LID PLATES (P-, P-, P+, P+) -> pod J2', 150, 70,
           {'1': 'PACK_N', '2': 'PACK_N', '3': 'PACK_P', '4': 'PACK_P'}, 'NIVA_power:WirePads_1x04_P1.7mm')
cart.place('Connector_Generic:Conn_01x03', 'J3', 'DOCK PADS (P+, NTC, P-), underside', 150, 110,
           {'1': 'PACK_P', '2': 'NTC', '3': 'PACK_N'}, 'NIVA_power:ContactPads_1x03_P6.0mm')
cart.text_block(20, 135, [
    'Cell: EEMB LP502030 class with integrated protection module (OV/UV/OC/short) and NTC lead - protection layer 1.',
    'F1 polyfuse in series with every external P+ path (pod and dock) - independent protection layer 2.',
    'NTC is passed to the dock only; the pod never sees it. No active parts in the cartridge.',
    'Dock pads are exposed only on the cartridge rear face, which the cradle covers while the pod is worn.'], 1.3)
cart.save('(sheet_instances (path "/" (page "1")))')
project(cdir, 'NIVA-cartridge', cart, ['*PACK_P', '*PACK_N', '*CELL_P'])
_p = json.loads((cdir / 'NIVA-cartridge.kicad_pro').read_text())          # 3.4 mm strip: 0.3 mm tracks, 0.15 mm gaps
_p['net_settings']['classes'][1].update(track_width=0.3, clearance=0.15); (cdir / 'NIVA-cartridge.kicad_pro').write_text(json.dumps(_p, indent=2))

# ================================================================ charging dock
ddir = BASE / 'dock'; footprints(ddir / 'NIVA_power.pretty')
dock = single_sheet(ddir, 'NIVA-dock', 'NIVA cartridge charging dock | USB-C, MCP73831, hardware NTC window | Rev C.1', 'A3')
dock.text(20, 16, 'NIVA CHARGING DOCK - ENGINEERING PROTOTYPE - NOT FOR FABRICATION', 2.5)
sch = dock
def R(ref, v, x, y, a, b): dock.place('Device:R', ref, v, x, y, {'1': a, '2': b}, RFP)
def Cc(ref, v, x, y, a, b, fp=CFP): dock.place('Device:C', ref, v, x, y, {'1': a, '2': b}, fp)
dock.text(20, 30, '01  USB-C SINK (5 V ONLY)', 1.8)
dock.place('Connector:USB_C_Receptacle_PowerOnly_6P', 'J1', 'USB-C 6P power-only', 45, 70,
           {'A5': 'CC1', 'B5': 'CC2', 'A9': 'VBUS_IN', 'B9': 'VBUS_IN', 'A12': 'GND', 'B12': 'GND', 'S1': 'GND'},
           'Connector_USB:USB_C_Receptacle_GCT_USB4125-xx-x_6P_TopMnt_Horizontal', extra={'MPN': 'GCT USB4125 class'})
R('R1', '5.1k', 85, 60, 'CC1', 'GND'); R('R2', '5.1k', 100, 60, 'CC2', 'GND')
dock.place('Device:Polyfuse', 'F1', 'PTC 1206 hold 0.5 A', 85, 95, {'1': 'VBUS_IN', '2': 'VBUS'}, 'Fuse:Fuse_1206_3216Metric')
dock.flag(110, 110, 'VBUS'); dock.flag(125, 110, 'GND')
dock.text(150, 30, '02  LINEAR CHARGER  4.20 V / 100 mA', 1.8)
dock.place('Battery_Management:MCP73831-2-OT', 'U1', 'MCP73831T-2ACI/OT', 190, 70,
           {'1': 'STAT', '2': 'GND', '3': 'BAT', '4': 'VBUS', '5': 'PROG'}, 'Package_TO_SOT_SMD:SOT-23-5',
           extra={'MPN': 'MCP73831T-2ACI/OT'})
Cc('C1', '4.7u 10V', 160, 100, 'VBUS', 'GND'); Cc('C2', '4.7u 10V', 225, 100, 'BAT', 'GND')
R('R3', '10k 1%', 245, 70, 'PROG', 'PROG_SW')
dock.place('Transistor_FET:2N7002', 'Q1', '2N7002', 265, 90, {'1': 'TEMP_OK', '2': 'GND', '3': 'PROG_SW'},
           'Package_TO_SOT_SMD:SOT-23')
R('R4', '1k', 160, 130, 'VBUS', 'LED_A'); dock.place('Device:LED', 'D1', 'AMBER 0805 (charging)', 190, 130,
           {'1': 'STAT', '2': 'LED_A'}, 'LED_SMD:LED_0805_2012Metric')
dock.text_block(150, 150, ['R_PROG 10k -> I_REG = 1000 V / 10 kOhm = 100 mA (MCP73831 datasheet).',
                           'PROG reaches GND only through Q1: Q1 off -> PROG floats -> charger disabled.',
                           'D1 lights while STAT is low (charging). Charge complete or inhibited = off.'], 1.2)
dock.text(20, 170, '03  PACK NTC WINDOW (HARDWARE, NO FIRMWARE)', 1.8)
R('R5', '22k 1%', 40, 200, 'VBUS', 'NTC_S'); Cc('C3', '100n', 60, 230, 'NTC_S', 'GND')
R('R6', '43k 1%', 90, 195, 'VBUS', 'VTH_HI'); R('R7', '39k 1%', 90, 225, 'VTH_HI', 'VTH_LO'); R('R8', '18k 1%', 90, 255, 'VTH_LO', 'GND')
dock.place('Comparator:LM393', 'U2', 'LM393', 150, 205, {'1': 'TEMP_OK', '2': 'NTC_S', '3': 'VTH_HI'},
           'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=1)
dock.place('Comparator:LM393', 'U2', 'LM393', 150, 245, {'5': 'NTC_S', '6': 'VTH_LO', '7': 'TEMP_OK'},
           'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=2)
dock.place('Comparator:LM393', 'U2', 'LM393', 200, 225, {'8': 'VBUS', '4': 'GND'}, 'Package_SO:SOIC-8_3.9x4.9mm_P1.27mm', unit=3)
Cc('C4', '100n', 225, 225, 'VBUS', 'GND'); R('R9', '100k', 245, 200, 'VBUS', 'TEMP_OK')
dock.text_block(20, 275, [
    'NTC_S = VBUS x R_NTC / (22k + R_NTC). Window (ratio of VBUS): cold/open trip 0.57 (VTH_HI), hot/short trip 0.18 (VTH_LO).',
    '10k B3435 NTC: 0 C -> 28.7k -> 0.566; 45 C -> 4.85k -> 0.181.  B3950: trips at ~2.5 C / ~43 C (conservative).',
    'No cartridge: NTC_S = VBUS (5 V) -> unit A pulls TEMP_OK low -> no charge. Only VTH_HI (2.85 V) must be inside the',
    'LM393 common-mode range (VCC - 1.5 V at 25 C, VCC - 2 V over temperature): an input outside it still gives a correct output.',
    'No hysteresis: charge may toggle at a threshold, which is benign (charging is inhibited outside the window).'], 1.2)
dock.place('Connector_Generic:Conn_01x03', 'J2', 'SPRING PINS TO CARTRIDGE (P+, NTC, P-)', 300, 205,
           {'1': 'BAT', '2': 'NTC_S', '3': 'GND'}, 'NIVA_power:SpringPins_1x03_P6.0mm_Vertical')
for ref, x in (('H1', 300), ('H2', 315), ('H3', 330), ('H4', 345)):
    dock.place('Mechanical:MountingHole', ref, 'M2', x, 250, {}, 'MountingHole:MountingHole_2.2mm_M2', bom=False)
dock.save('(sheet_instances (path "/" (page "1")))')
project(ddir, 'NIVA-dock', dock, ['VBUS', 'VBUS_IN', 'GND', 'BAT'])
for d in (cdir, ddir):
    (d / 'sym-lib-table').write_text('(sym_lib_table (version 7)\n)\n')
print('cartridge parts:', len(cart.parts), '| dock parts:', len(dock.parts))
